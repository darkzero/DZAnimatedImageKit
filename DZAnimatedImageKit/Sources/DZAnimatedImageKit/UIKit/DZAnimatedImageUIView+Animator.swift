//
//  DZAnimatedImageUIView+Animator.swift
//  DZAnimatedImageView
//
//  Created by Yuhua Hu on 2025/9/2.
//

import UIKit

@MainActor
protocol AnimatorDelegate: AnyObject {
    func animator(_ animator: DZAnimatedImageUIView.Animator, didPlayAnimationLoops count: UInt)
}

extension DZAnimatedImageUIView: AnimatorDelegate {
    @MainActor
    func animator(_ animator: Animator, didPlayAnimationLoops count: UInt) {
        delegate?.animatedImageView(self, didPlayAnimationLoops: count)
    }
}

extension DZAnimatedImageUIView {
    // Represents a single frame in a GIF/APNG
    struct AnimatedFrame {
        
        // The image to display for this frame. Its value is nil when the frame is removed from the buffer.
        let image: UIImage?
        
        // The duration that this frame should remain active.
        let duration: TimeInterval
        
        // A placeholder frame with no image assigned.
        // Used to replace frames that are no longer needed in the animation.
        var placeholderFrame: AnimatedFrame {
            return AnimatedFrame(image: nil, duration: duration)
        }
        
        // Whether this frame instance contains an image or not.
        var isPlaceholder: Bool {
            return image == nil
        }
        
        // Returns a new instance from an optional image.
        // - parameter image: An optional `UIImage` instance to be assigned to the new frame.
        // - returns: An `AnimatedFrame` instance.
        func makeAnimatedFrame(image: UIImage?) -> AnimatedFrame {
            return AnimatedFrame(image: image, duration: duration)
        }
    }
}

extension DZAnimatedImageUIView {
    // MARK: - Animator(actor)
    actor Animator {
        // config
        private let contentMode: UIView.ContentMode
        private let size: CGSize
        private var repeatMode: RepeatMode
        
        // Image source and meta
        private let imageSourceBox: ImageSourceBox
        private let maxFrameCount: Int
        private let maxTimeStep: TimeInterval = 1.0
        private var animatedFrames = [AnimatedFrame]()
        private var frameCount = 0
        private let loopCountFromMeta: Int
        private var timeSinceLastFrameChange: TimeInterval = 0.0
        
        // playback states (actor-isolated)
        private var currentFrameIndex: Int = 0 {
            didSet {
                previousFrameIndex = oldValue
            }
        }
        var previousFrameIndex = 0 {
            didSet {
                self.updatePreloadedFrames()
            }
        }
        
        private var currentRepeatCount: Int = 0
        private var playingTask: Task<Void, Never>?
        private var isStopped: Bool = false
        
        // Preload & cache (very light)
        private let preloadCount: Int
        private var frameCache: [Int: CGImage] = [:]
        
        
        var isFinished: Bool = false
        
        var needsPrescaling = true
        weak var delegate: AnimatorDelegate?
        
        // Total duration of one animation loop
        var loopDuration: TimeInterval = 0
        
        // Current active frame image
        var currentFrameImage: UIImage? {
            return frame(at: currentFrameIndex)
        }
        
        // Current active frame duration
        var currentFrameDuration: TimeInterval {
            return duration(at: currentFrameIndex)
        }
        
        var isReachMaxRepeatCount: Bool {
            switch repeatMode {
            case .once:
                return currentRepeatCount >= 1
            case .finite(let maxCount):
                return currentRepeatCount >= maxCount
            case .infinite:
                return false
            }
        }
        
        var isLastFrame: Bool {
            return currentFrameIndex == frameCount - 1
        }
        
        var preloadingIsNeeded: Bool {
            return maxFrameCount < frameCount - 1
        }
        
        private lazy var preloadQueue: DispatchQueue = {
            return DispatchQueue(label: "cn.darkzero.DarkEggKit.AImageView.preloadQueue")
        }()
        
        /// Creates an animator with image source reference.
        ///
        /// - Parameters:
        ///   - source: The reference of animated image.
        ///   - mode: Content mode of the `AnimatedImageView`.
        ///   - size: Size of the `AnimatedImageView`.
        ///   - count: Count of frames needed to be preloaded.
        ///   - repeatCount: The repeat count should this animator uses.
        init(imageSourceBox sourceBox: ImageSourceBox, contentMode mode: UIView.ContentMode = .scaleToFill,
             size: CGSize,
             framePreloadCount count: Int,
             repeatMode: RepeatMode) {
            self.imageSourceBox = sourceBox
            self.contentMode = mode
            self.size = size
            self.preloadCount = max(0, count)
            self.repeatMode = repeatMode
            self.frameCount = CGImageSourceGetCount(sourceBox.raw)
            self.loopCountFromMeta = Animator.readLoopCount(from: sourceBox.raw) ?? 0
            self.maxFrameCount = 10
        }
        
        func start(onFrame: @escaping @MainActor @Sendable (_ image: CGImage, _ duration: TimeInterval) -> Void,
                   onLoop: @escaping @MainActor @Sendable (_ count: Int) -> Void) {
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
                    try? await Task.sleep(nanoseconds: UInt64(max(dur, 0.01) * 1_000_000_000))
                    await self.advanceFrameIndexAndLoopIfNeeded(onLoop: onLoop) 
                }
            }
        }
        
        func stop() {
            isStopped = true
            playingTask?.cancel()
            playingTask = nil
            frameCache.removeAll()
        }
        
        func frame(at index: Int) -> UIImage? {
            return animatedFrames[safe: index]?.image
        }
        
        // MARK: - Frame decode & timing
        private func decodeFrame(at index: Int) -> (CGImage, TimeInterval)? {
            if let cached = frameCache[index] {
                return (cached, frameDurationAt(index: index))
            }
            let imageSource = self.imageSourceBox.raw
            guard let cg = CGImageSourceCreateImageAtIndex(imageSource, index, imageCreateOptions()) else {
                return nil
            }
            frameCache[index] = cg
            trimCacheIfNeeded(keepingAround: index)
            return (cg, frameDurationAt(index: index))
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
        
        private func advanceFrameIndex() {
            currentFrameIndex = (currentFrameIndex + 1) % frameCount
        }
        
        private func advanceFrameIndexAndLoopIfNeeded(onLoop: @MainActor @Sendable (_ count: Int) -> Void) async {
            let wasLast = (currentFrameIndex == frameCount - 1)
            advanceFrameIndex()
            if wasLast {
                currentRepeatCount += 1
                let loopCount = currentRepeatCount
                await onLoop(loopCount)
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
                // 如果文件内含 loop 元数据（如 APNG/GIF 的 LoopCount），按更严格者限制
                if loopCountFromMeta > 0 {
                    return currentRepeatCount >= min(Int(want), loopCountFromMeta)
                } else {
                    return currentRepeatCount >= want
                }
            case .once:
                return currentRepeatCount >= 1
            }
        }
        
        private func trimCacheIfNeeded(keepingAround index: Int) {
            guard preloadCount > 0 else { return }
            // Keep a small sliding window around current frame
            let keep = Set(([index] +
                            (1...preloadCount).map { (index + $0) % frameCount } +
                            (1...preloadCount).map { (index - $0 + frameCount) % frameCount }))
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
        
        
        
        func duration(at index: Int) -> TimeInterval {
            return animatedFrames[safe: index]?.duration  ?? .infinity
        }
        
        func prepareFramesAsynchronously() {
            let imageSource = self.imageSourceBox.raw
            frameCount = Int(CGImageSourceGetCount(imageSource))
            animatedFrames.reserveCapacity(frameCount)
            // if only 1 frame, set repeat mode to .once
            if frameCount <= 1 {
                self.repeatMode = .once
            }
            // load frames
            if self.repeatMode == .infinite {
                self.setupAnimatedFrames()
//                preloadQueue.async { [weak self] in
//                    self?.setupAnimatedFrames()
//                }
            }
            else {
                self.setupAnimatedFrames()
            }
        }
        
        func shouldChangeFrame(with duration: CFTimeInterval, handler: (Bool) -> Void) {
            incrementTimeSinceLastFrameChange(with: duration)
            if currentFrameDuration > timeSinceLastFrameChange {
                handler(false)
            } else {
                resetTimeSinceLastFrameChange()
                incrementCurrentFrameIndex()
                handler(true)
            }
        }
        
        private func setupAnimatedFrames() {
            self.resetAnimatedFrames()
            var duration: TimeInterval = 0
            let imageSource = self.imageSourceBox.raw
            (0..<frameCount).forEach { index in
                let frameDuration = AnimatedImageFrames.getFrameDuration(from: imageSource, at: index)
                duration += min(frameDuration, maxTimeStep)
                animatedFrames += [AnimatedFrame(image: nil, duration: frameDuration)]
                if index > maxFrameCount { return }
                animatedFrames[index] = animatedFrames[index].makeAnimatedFrame(image: loadFrame(at: index))
            }
            self.loopDuration = duration
        }
        
        internal func resetAnimatedFrames() {
            animatedFrames.removeAll()
            animatedFrames = []
        }
        
        internal func loadFrame(at index: Int) -> UIImage? {
            let imageSource = self.imageSourceBox.raw
            let maxPoint = max(size.width, size.height)
            let maxPixel = max(1, Int(maxPoint * 2.0)) // 粗略用 2.0 当作 scale；更精确可从外部传入屏幕 scale
            let scaledImage: UIImage
            if needsPrescaling, size != .zero {
                let opts: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true
                ]
                if let thumb = CGImageSourceCreateThumbnailAtIndex(imageSource, index, opts as CFDictionary) {
                    return UIImage(cgImage: thumb)
                }
            }
            guard let cg = CGImageSourceCreateImageAtIndex(imageSource, index, nil) else {
                return nil
            }
            return UIImage(cgImage: cg)
        }
        
        private func updatePreloadedFrames() {
            guard preloadingIsNeeded else {
                return
            }
            animatedFrames[previousFrameIndex] = animatedFrames[previousFrameIndex].placeholderFrame
            preloadIndexes(start: currentFrameIndex).forEach { index in
                let currentAnimatedFrame = animatedFrames[index]
                if !currentAnimatedFrame.isPlaceholder { return }
                animatedFrames[index] = currentAnimatedFrame.makeAnimatedFrame(image: loadFrame(at: index))
            }
        }
        
        private func incrementCurrentFrameIndex() {
            if isReachMaxRepeatCount && isLastFrame {
                isFinished = true
            } else if currentFrameIndex == 0 {
                currentRepeatCount += 1
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    //await self.delegate?.animator(self, didPlayAnimationLoops: self.currentRepeatCount)
                }
//                DispatchQueue.main.async { [weak self] _ in
//                    self?.delegate?.animator(self!, didPlayAnimationLoops: self?.currentRepeatCount!)
//                }
            }
            currentFrameIndex = increment(frameIndex: currentFrameIndex)
        }
        
        private func incrementTimeSinceLastFrameChange(with duration: TimeInterval) {
            timeSinceLastFrameChange += min(maxTimeStep, duration)
        }
        
        private func resetTimeSinceLastFrameChange() {
            timeSinceLastFrameChange -= currentFrameDuration
        }
        
        private func increment(frameIndex: Int, by value: Int = 1) -> Int {
            return (frameIndex + value) % frameCount
        }
        
        private func preloadIndexes(start index: Int) -> [Int] {
            let nextIndex = increment(frameIndex: index)
            let lastIndex = increment(frameIndex: index, by: maxFrameCount)
            
            if lastIndex >= nextIndex {
                return [Int](nextIndex...lastIndex)
            } else {
                return [Int](nextIndex..<frameCount) + [Int](0...lastIndex)
            }
        }
    }
}

enum AnimatedImageFrames {
    internal static func getFrameDuration(from imageSource: CGImageSource, at idx: Int) -> TimeInterval {
        guard let property = CGImageSourceCopyPropertiesAtIndex(imageSource, idx, nil) as? [String: Any] else {
            return 0.0
        }
        let defaultDuration: TimeInterval = 1.0/60.0
        var aniInfo: [String: Any]?
        
        if property[kCGImagePropertyGIFDictionary as String] as? [String: Any] != nil {         // gif
            aniInfo = property[kCGImagePropertyGIFDictionary as String] as? [String: Any]
        }
        else if property[kCGImagePropertyPNGDictionary as String] as? [String: Any] != nil {    // png
            aniInfo = property[kCGImagePropertyPNGDictionary as String] as? [String: Any]
        }
        else {
            return defaultDuration
        }
        
        guard let gifInfo = aniInfo else {
            return defaultDuration
        }
        
        let unclampedDelayTime = gifInfo[kCGImagePropertyGIFUnclampedDelayTime as String] as? NSNumber
        let delayTime = gifInfo[kCGImagePropertyGIFDelayTime as String] as? NSNumber
        let duration = unclampedDelayTime ?? delayTime
        
        guard let frameDuration = duration else {
            return defaultDuration
        }
        return max(frameDuration.doubleValue, defaultDuration)
    }
}
