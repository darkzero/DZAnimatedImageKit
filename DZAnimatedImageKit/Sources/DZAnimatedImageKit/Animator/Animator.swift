//
//  Animator.swift
//  DZAnimatedImageKit
//
//  Created by darkzero on 2025/9/28.
//

import CoreGraphics
import Foundation
import ImageIO

@MainActor
protocol AnimatorDelegate: AnyObject {
    func animator(_ animator: Animator, didPlayAnimationLoops count: UInt)
}

// MARK: - Animator(actor)
actor Animator {
    // config
    private let size: CGSize
    private var repeatMode: RepeatMode
    private let screenScale: CGFloat // screen scale 2x or 3x

    // Image source and meta
    private let imageSourceBox: ImageSourceBox
    private var animatedFrames = [AnimatedFrame]()
    private var frameCount = 0
    private let maxTimeStep: TimeInterval = 1.0
    private let loopCountFromMeta: Int
    // Total duration of one animation loop
    private(set) var loopDuration: TimeInterval = 0
    private let maxPreloadCap: Int
    private var timeSinceLastFrameChange: TimeInterval = 0.0

    // playback states (actor-isolated)
    private var currentFrameIndex: Int = 0 {
        didSet { previousFrameIndex = oldValue }
    }
    private var previousFrameIndex = 0 {
        didSet { updatePreloadedFrames() }
    }
    private var currentRepeatCount: Int = 0
    private var isStopped: Bool = false
    private var playingTask: Task<Void, Never>?

    // Preload & cache (very light)
    private let preloadCount: Int
    private var isFinished: Bool = false
    private var frameCache: [Int: CGImage] = [:]

    var needsPrescaling = true

    weak var delegate: AnimatorDelegate?

    // Computed
    var isReachMaxRepeatCount: Bool {
        switch repeatMode {
        case .once:
            return currentRepeatCount >= 1
        case .finite(let n):
            return currentRepeatCount >= n
        case .infinite:
            return false
        }
    }

    var isLastFrame: Bool {
        return currentFrameIndex == frameCount - 1
    }

    var preloadingIsNeeded: Bool {
        return effectivePreloadCount > 0
    }

    /// Effective preload window.
    /// Uses `preloadCount` as the desired value and `maxPreloadCap` as a hard safety cap.
    private var effectivePreloadCount: Int {
        guard frameCount > 1 else { return 0 }
        return min(preloadCount, maxPreloadCap, frameCount - 1)
    }

    // Current active frame image
    var currentFrameImage: CGImage? {
        return frame(at: currentFrameIndex)
    }

    // Current active frame duration
    var currentFrameDuration: TimeInterval {
        return duration(at: currentFrameIndex)
    }

    /// Creates an animator with image source reference.
    ///
    /// - Parameters:
    ///   - source: The reference of animated image.
    ///   - size: Size of the `AnimatedImageView`.
    ///   - count: Count of frames needed to be preloaded.
    ///   - repeatCount: The repeat count should this animator uses.
    init(imageSourceBox sourceBox: ImageSourceBox,
         screenScale: CGFloat = 2.0,
         size: CGSize,
         framePreloadCount count: Int,
         repeatMode: RepeatMode) {
        self.imageSourceBox = sourceBox
        self.size = size
        self.preloadCount = max(0, count)
        self.repeatMode = repeatMode
        self.frameCount = CGImageSourceGetCount(sourceBox.raw)
        self.loopCountFromMeta = Animator.readLoopCount(from: sourceBox.raw) ?? 0
        self.maxPreloadCap = 10
        self.screenScale = screenScale
    }

    // MARK: - public API
    func start(onFrame: @escaping @MainActor @Sendable (_ image: CGImage, _ duration: TimeInterval) -> Void,
               onLoop: @escaping @MainActor @Sendable (_ count: Int) -> Void,
               onBuffer: @escaping @MainActor @Sendable (_ bytes: Int) -> Void = { _ in }) {
        guard playingTask == nil, frameCount > 0 else {
            return
        }
        isStopped = false
        playingTask = Task { [weak self] in
            guard let self = self else {
                return
            }
            while !(await self.isStopped) {
                let idx = await self.currentFrameIndex
                guard let (cg, dur) = await self.decodeFrame(at: idx) else {
                    await self.advanceFrameIndex()
                    continue
                }
                await onFrame(cg, dur)
                let decodedBytes = await self.decodedFrameBufferBytes()
                await onBuffer(decodedBytes)
                try? await Task.sleep(nanoseconds: UInt64(max(dur, 0.01) * 1_000_000_000))
                await self.advanceFrameIndexAndLoopIfNeeded(onLoop: onLoop)
            }
        }
    }

    func prepareFramesAsynchronously() {
        setupAnimatedFrames()
    }

    /// Setup animation frames
    /// Only fill duration at first
    /// Not decode frame image
    private func setupAnimatedFrames() {
        self.resetAnimatedFrames()
        let imageSource = self.imageSourceBox.raw
        frameCount = Int(CGImageSourceGetCount(imageSource))
        if frameCount <= 1 {
            self.repeatMode = .once
        }
        var totalDuration: TimeInterval = 0
        animatedFrames.reserveCapacity(frameCount)
        (0 ..< frameCount).forEach { index in
            let frameDuration = AnimatedImageFrames.getFrameDuration(from: imageSource, at: index)
            totalDuration += min(frameDuration, maxTimeStep)
            animatedFrames.append(AnimatedFrame(image: nil, duration: frameDuration))
        }
        self.loopDuration = totalDuration
        primeInitialWindow()
    }

    // reset all frames and properties
    private func resetAnimatedFrames() {
        animatedFrames.removeAll(keepingCapacity: false)
        frameCount = 0
        currentFrameIndex = 0
        previousFrameIndex = 0
        currentRepeatCount = 0
        isFinished = false
    }

    func stop() {
        isStopped = true
        playingTask?.cancel()
        playingTask = nil
        frameCache.removeAll()
    }

    // MARK: - Frame decode & timing
    private func decodeFrame(at index: Int) -> (CGImage, TimeInterval)? {
        if let cached = animatedFrames[safe: index]?.image {
            return (cached, duration(at: index))
        }
        guard let cg = loadFrame(at: index) else {
            return nil
        }
        animatedFrames[index] = animatedFrames[index].makeAnimatedFrame(image: cg)
        return (cg, duration(at: index))
    }

    /// Downsample according to display size + screen scale
    /// fall back to original size if it fails
    internal func loadFrame(at index: Int) -> CGImage? {
        let imageSource = self.imageSourceBox.raw
        let targetMaxPixel = max(1, Int(ceil(max(size.width, size.height) * screenScale)))
        var frameMaxPixel = targetMaxPixel
        if let props = CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil) as? [CFString: Any] {
            let w = (props[kCGImagePropertyPixelWidth]  as? NSNumber)?.intValue ?? 0
            let h = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
            if w > 0, h > 0 {
                frameMaxPixel = min(targetMaxPixel, max(w, h)) // 只下采样，不上采样
            }
        }

        if needsPrescaling, size != .zero {
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                kCGImageSourceThumbnailMaxPixelSize: frameMaxPixel,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
            ]
            if let thumb = CGImageSourceCreateThumbnailAtIndex(imageSource, index, opts as CFDictionary) {
                return thumb
            }
        }

        // if can not scale to small, return original image
        guard let cg = CGImageSourceCreateImageAtIndex(imageSource, index, nil) else {
            return nil
        }
        return cg
    }

    private func decodedFrameBufferBytes() -> Int {
        var total = 0
        for frame in animatedFrames {
            guard let image = frame.image else { continue }
            total += image.bytesPerRow * image.height
        }
        return total
    }

    private func advanceFrameIndex() {
        currentFrameIndex = increment(frameIndex: currentFrameIndex)
    }

    private func increment(frameIndex: Int, by value: Int = 1) -> Int {
        return (frameIndex + value) % frameCount
    }

    // Scale/Thumbnail
    private func imageCreateOptions() -> CFDictionary {
        let dict = [
            kCGImageSourceShouldCache as String: true,
            kCGImageSourceCreateThumbnailFromImageIfAbsent as String: false
        ] as CFDictionary
        return dict
    }

    private func frameDurationAt(index: Int) -> TimeInterval {
        let imageSource = self.imageSourceBox.raw
        guard let props = CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil) as? [CFString: Any],
              let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] ??
                        props[kCGImagePropertyPNGDictionary] as? [CFString: Any] else {
            return 0.1
        }
        // GIF/APNG frame durations
        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber
        let clamped   = gif[kCGImagePropertyGIFDelayTime] as? NSNumber
        let raw = (unclamped?.doubleValue ?? 0) > 0 ? unclamped!.doubleValue : (clamped?.doubleValue ?? 0.1)
        let minFrame = 0.02 // Safari-like floor
        return max(raw, minFrame)
    }

    private func advanceFrameIndexAndLoopIfNeeded(onLoop: @MainActor @Sendable (_ count: Int) -> Void) async {
        let wasLast = (currentFrameIndex == frameCount - 1)
        advanceFrameIndex()
        if wasLast {
            currentRepeatCount += 1
            let loopCount = currentRepeatCount // 先在 actor 内捕获
            await onLoop(loopCount)            // 再跳到主线程
            if shouldStopAfterCurrentLoop() {
                isStopped = true
            }
        }
    }

    private func shouldStopAfterCurrentLoop() -> Bool {
        switch repeatMode {
        case .infinite:
            return false
        case .finite(let want):
            if loopCountFromMeta > 0 {
                return currentRepeatCount >= min(Int(want), loopCountFromMeta)
            } else {
                return currentRepeatCount >= want
            }
        case .once:
            return currentRepeatCount >= 1
        }
    }

    // MARK: - Preload window
    private func primeInitialWindow() {
        // current frame
        if animatedFrames[currentFrameIndex].isPlaceholder,
           let cg = loadFrame(at: currentFrameIndex) {
            animatedFrames[currentFrameIndex] = animatedFrames[currentFrameIndex].makeAnimatedFrame(image: cg)
        }
        // preload frames
        for idx in preloadIndexes(start: currentFrameIndex) {
            if animatedFrames[idx].isPlaceholder,
               let cg = loadFrame(at: idx) {
                animatedFrames[idx] = animatedFrames[idx].makeAnimatedFrame(image: cg)
            }
        }
    }

    private func trimCacheIfNeeded(keepingAround index: Int) {
        let effective = effectivePreloadCount
        guard effective > 0 else { return }
        // Keep a small sliding window around current frame
        let keep = Set(([index] +
                        (1...effective).map { (index + $0) % frameCount } +
                        (1...effective).map { (index - $0 + frameCount) % frameCount }))
        frameCache.keys.filter { !keep.contains($0) }.forEach { frameCache.removeValue(forKey: $0) }
    }

    // MARK: - Metadata
    private static func readLoopCount(from src: CGImageSource) -> Int? {
        guard let props = CGImageSourceCopyProperties(src, nil) as? [CFString: Any] else { return nil }
        if let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any],
           let loop = gif[kCGImagePropertyGIFLoopCount] as? NSNumber {
            return loop.intValue
        }
        if let apng = props[kCGImagePropertyPNGDictionary] as? [CFString: Any],
           let loop = apng[kCGImagePropertyAPNGLoopCount] as? NSNumber {
            return loop.intValue
        }
        return nil
    }

    // MARK: - Frame accessors
    func frame(at index: Int) -> CGImage? {
        return animatedFrames[safe: index]?.image
    }

    func duration(at index: Int) -> TimeInterval {
        return animatedFrames[safe: index]?.duration  ?? .infinity
    }

    private func updatePreloadedFrames() {
        guard preloadingIsNeeded else {
            return
        }
        let window = Set(preloadIndexes(start: currentFrameIndex) + [currentFrameIndex])
        // remove framse out of window
        for i in 0..<frameCount where !window.contains(i) {
            if !animatedFrames[i].isPlaceholder {
                animatedFrames[i] = animatedFrames[i].placeholderFrame
            }
        }
        // fill frames in window
        for i in window {
            if animatedFrames[i].isPlaceholder,
               let cg = loadFrame(at: i) {
                animatedFrames[i] = animatedFrames[i].makeAnimatedFrame(image: cg)
            }
        }
    }

    private func preloadIndexes(start index: Int) -> [Int] {
        let effective = effectivePreloadCount
        guard effective > 0 else { return [] }

        let nextIndex = increment(frameIndex: index)
        let lastIndex = increment(frameIndex: index, by: effective)

        if lastIndex >= nextIndex {
            return [Int](nextIndex...lastIndex)
        } else {
            return [Int](nextIndex..<frameCount) + [Int](0...lastIndex)
        }
    }
}
