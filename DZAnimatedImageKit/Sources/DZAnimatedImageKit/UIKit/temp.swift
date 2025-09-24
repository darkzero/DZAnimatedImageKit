//
//  temp.swift
//  DZAnimatedImageKit
//
//  Created by Yuhua Hu on 2025/9/24.
//

//
//  DZAnimatedImageUIView+Animator.swift
//  DZAnimatedImageView
//
//  整理版：按需解码 + 预加载窗口 + 并发/主线程隔离修复
//

import UIKit
@preconcurrency import ImageIO

// MARK: - Delegate

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

// MARK: - AnimatedFrame

extension DZAnimatedImageUIView {
    /// 表示一帧（像素可能为占位 nil，只保存时长）
    struct AnimatedFrame {
        let image: UIImage?
        let duration: TimeInterval

        var placeholderFrame: AnimatedFrame { AnimatedFrame(image: nil, duration: duration) }
        var isPlaceholder: Bool { image == nil }

        func makeAnimatedFrame(image: UIImage?) -> AnimatedFrame {
            AnimatedFrame(image: image, duration: duration)
        }
    }
}

// MARK: - Animator

extension DZAnimatedImageUIView {
    actor Animator {
        // Config
        private let contentMode: UIView.ContentMode
        private let size: CGSize
        private var repeatMode: RepeatMode
        private let screenScale: CGFloat

        // Image source & meta
        private let imageSourceBox: ImageSourceBox
        private var animatedFrames: [AnimatedFrame] = []
        private var frameCount: Int = 0
        private let maxTimeStep: TimeInterval = 1.0
        private let loopCountFromMeta: Int
        private(set) var loopDuration: TimeInterval = 0

        // Playback state
        private var currentFrameIndex: Int = 0 {
            didSet { previousFrameIndex = oldValue }
        }
        private var previousFrameIndex: Int = 0 {
            didSet { updatePreloadedFrames() }
        }
        private var currentRepeatCount: Int = 0
        private var isStopped: Bool = false
        private var playingTask: Task<Void, Never>?

        // Preload window
        private let preloadCount: Int
        private var isFinished: Bool = false
        var needsPrescaling: Bool = true
        weak var delegate: AnimatorDelegate?

        // Computed
        var isReachMaxRepeatCount: Bool {
            switch repeatMode {
            case .once: return currentRepeatCount >= 1
            case .finite(let n):
                return currentRepeatCount >= n
            case .infinite: return false
            }
        }
        var isLastFrame: Bool { currentFrameIndex == frameCount - 1 }
        var preloadingIsNeeded: Bool { preloadCount > 0 && frameCount > 1 }

        // MARK: - Init

        init(
            imageSourceBox: ImageSourceBox,
            contentMode: UIView.ContentMode = .scaleToFill,
            size: CGSize,
            framePreloadCount: Int,
            repeatMode: RepeatMode,
            screenScale: CGFloat
        ) {
            self.imageSourceBox = imageSourceBox
            self.contentMode = contentMode
            self.size = size
            self.preloadCount = max(0, framePreloadCount)
            self.repeatMode = repeatMode
            self.screenScale = screenScale

            // 元数据：loop count
            self.loopCountFromMeta = Animator.readLoopCount(from: imageSourceBox.raw) ?? 0
        }

        // MARK: - Public API

        /// 仅收集时长与帧数，不解码像素；最后预热当前窗口
        func prepareFramesAsynchronously() {
            setupAnimatedFrames()
        }

        func start(
            onFrame: @escaping @MainActor @Sendable (_ image: CGImage, _ duration: TimeInterval) -> Void,
            onLoop:  @escaping @MainActor @Sendable (_ count: Int) -> Void
        ) {
            guard playingTask == nil, frameCount > 0 else { return }
            isStopped = false

            playingTask = Task { [weak self] in
                guard let self else { return }
                while !(await self.isStopped) {
                    let idx = await self.currentFrameIndex
                    if let (cg, dur) = await self.decodeFrame(at: idx) {
                        await onFrame(cg, dur)
                        try? await Task.sleep(nanoseconds: UInt64(max(dur, 0.01) * 1_000_000_000))
                        await self.advanceFrameIndexAndLoopIfNeeded(onLoop: onLoop)
                    } else {
                        await self.advanceFrameIndex() // 解码失败：前进继续
                    }
                }
            }
        }

        func stop() {
            isStopped = true
            playingTask?.cancel()
            playingTask = nil
        }

        // MARK: - Frame accessors

        func frame(at index: Int) -> UIImage? {
            animatedFrames[safe: index]?.image
        }
        func duration(at index: Int) -> TimeInterval {
            animatedFrames[safe: index]?.duration ?? .infinity
        }

        // MARK: - Setup

        private func setupAnimatedFrames() {
            resetAnimatedFrames()
            let src = imageSourceBox.raw
            frameCount = Int(CGImageSourceGetCount(src))

            if frameCount <= 1 {
                repeatMode = .once
            }

            var total: TimeInterval = 0
            animatedFrames.reserveCapacity(frameCount)
            for i in 0..<frameCount {
                let d = Animator.getFrameDuration(from: src, at: i)
                total += min(d, maxTimeStep)
                animatedFrames.append(AnimatedFrame(image: nil, duration: d)) // 不解码像素
            }
            loopDuration = total

            primeInitialWindow()
        }

        private func resetAnimatedFrames() {
            animatedFrames.removeAll(keepingCapacity: false)
            frameCount = 0
            currentFrameIndex = 0
            previousFrameIndex = 0
            currentRepeatCount = 0
            isFinished = false
        }

        // MARK: - Decode & timing

        /// 返回当前索引的 CGImage 与该帧时长（按需解码）
        private func decodeFrame(at index: Int) -> (CGImage, TimeInterval)? {
            if let ready = animatedFrames[safe: index]?.image?.cgImage {
                return (ready, duration(at: index))
            }
            guard let ui = loadFrame(at: index), let cg = ui.cgImage else {
                return nil
            }
            animatedFrames[index] = animatedFrames[index].makeAnimatedFrame(image: ui)
            return (cg, duration(at: index))
        }

        /// 根据显示尺寸 + 屏幕 scale 下采样；失败回退原尺寸
        internal func loadFrame(at index: Int) -> UIImage? {
            let src = imageSourceBox.raw

            let targetMaxPixel = max(1, Int(ceil(max(size.width, size.height) * screenScale)))

            var frameMaxPixel = targetMaxPixel
            if let props = CGImageSourceCopyPropertiesAtIndex(src, index, nil) as? [CFString: Any] {
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
                if let thumb = CGImageSourceCreateThumbnailAtIndex(src, index, opts as CFDictionary) {
                    return UIImage(cgImage: thumb, scale: screenScale, orientation: .up)
                }
            }

            guard let cg = CGImageSourceCreateImageAtIndex(src, index, nil) else { return nil }
            return UIImage(cgImage: cg, scale: screenScale, orientation: .up)
        }

        // MARK: - Playback index & loop

        private func advanceFrameIndex() {
            currentFrameIndex = increment(frameIndex: currentFrameIndex)
        }

        private func advanceFrameIndexAndLoopIfNeeded(
            onLoop: @MainActor @Sendable (_ count: Int) -> Void
        ) async {
            let wasLast = (currentFrameIndex == frameCount - 1)
            advanceFrameIndex()
            if wasLast {
                currentRepeatCount += 1
                let loopCount = currentRepeatCount // 先在 actor 内捕获
                await onLoop(loopCount)            // 再跳到主线程
                if shouldStopAfterCurrentLoop() { isStopped = true }
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
            // 当前帧
            if animatedFrames[currentFrameIndex].isPlaceholder,
               let ui = loadFrame(at: currentFrameIndex) {
                animatedFrames[currentFrameIndex] = animatedFrames[currentFrameIndex].makeAnimatedFrame(image: ui)
            }
            // 预加载窗口
            for idx in preloadIndexes(start: currentFrameIndex) {
                if animatedFrames[idx].isPlaceholder,
                   let ui = loadFrame(at: idx) {
                    animatedFrames[idx] = animatedFrames[idx].makeAnimatedFrame(image: ui)
                }
            }
        }

        private func updatePreloadedFrames() {
            guard preloadingIsNeeded, frameCount > 0 else { return }

            let window = Set(preloadIndexes(start: currentFrameIndex) + [currentFrameIndex])

            // 回收窗口外
            for i in 0..<frameCount where !window.contains(i) {
                if !animatedFrames[i].isPlaceholder {
                    animatedFrames[i] = animatedFrames[i].placeholderFrame
                }
            }
            // 填充窗口内缺帧
            for i in window {
                if animatedFrames[i].isPlaceholder,
                   let ui = loadFrame(at: i) {
                    animatedFrames[i] = animatedFrames[i].makeAnimatedFrame(image: ui)
                }
            }
        }

        private func increment(frameIndex: Int, by value: Int = 1) -> Int {
            guard frameCount > 0 else { return 0 }
            return (frameIndex + value) % frameCount
        }

        private func preloadIndexes(start index: Int) -> [Int] {
            guard preloadCount > 0, frameCount > 1 else { return [] }
            let nextIndex = increment(frameIndex: index)
            let lastIndex = increment(frameIndex: index, by: preloadCount)
            if lastIndex >= nextIndex {
                return Array(nextIndex...lastIndex)
            } else {
                return Array(nextIndex..<frameCount) + Array(0...lastIndex)
            }
        }

        // MARK: - Metadata helpers

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

        /// 独立帧时长读取（若你项目里已有 AnimatedImageFrames.getFrameDuration，可换掉这里）
        private static func getFrameDuration(from src: CGImageSource, at index: Int) -> TimeInterval {
            guard let props = CGImageSourceCopyPropertiesAtIndex(src, index, nil) as? [CFString: Any] else {
                return 0.1
            }
            let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let png = props[kCGImagePropertyPNGDictionary] as? [CFString: Any]

            let unclamped = (gif?[kCGImagePropertyGIFUnclampedDelayTime] ??
                             png?[kCGImagePropertyAPNGUnclampedDelayTime]) as? NSNumber
            let clamped   = (gif?[kCGImagePropertyGIFDelayTime] ??
                             png?[kCGImagePropertyAPNGDelayTime]) as? NSNumber
            let raw = (unclamped?.doubleValue ?? 0) > 0
                ? unclamped!.doubleValue
                : (clamped?.doubleValue ?? 0.1)

            let minFrame = 0.02 // Safari floor，避免过快
            return max(raw, minFrame)
        }
    }
}

// MARK: - Safe index helper

private extension Array {
    subscript(safe i: Int) -> Element? {
        (i >= 0 && i < count) ? self[i] : nil
    }
}
