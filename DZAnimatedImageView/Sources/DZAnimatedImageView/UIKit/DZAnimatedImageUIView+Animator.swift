//
//  DZAnimatedImageUIView+Animator.swift
//  DZAnimatedImageView
//
//  Created by Yuhua Hu on 2025/9/2.
//

import UIKit

protocol AnimatorDelegate: AnyObject {
    func animator(_ animator: DZAnimatedImageUIView.Animator, didPlayAnimationLoops count: UInt)
}

extension DZAnimatedImageUIView: AnimatorDelegate {
    func animator(_ animator: Animator, didPlayAnimationLoops count: UInt) {
        delegate?.animatedImageView(self, didPlayAnimationLoops: count)
    }
}

extension DZAnimatedImageUIView {
    
    // Represents a single frame in a GIF.
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
        //
        // - parameter image: An optional `UIImage` instance to be assigned to the new frame.
        // - returns: An `AnimatedFrame` instance.
        func makeAnimatedFrame(image: UIImage?) -> AnimatedFrame {
            return AnimatedFrame(image: image, duration: duration)
        }
    }
}

extension DZAnimatedImageUIView {
    // MARK: - Animator
    class Animator {
        private let size: CGSize
        private let maxFrameCount: Int
        private let imageSource: CGImageSource
        private var repeatMode: RepeatMode
        private let maxTimeStep: TimeInterval = 1.0
        private var animatedFrames = [AnimatedFrame]()
        private var frameCount = 0
        private var timeSinceLastFrameChange: TimeInterval = 0.0
        private var currentRepeatCount: UInt = 0
        
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
        
        // The index of the current GIF frame.
        var currentFrameIndex = 0 {
            didSet {
                previousFrameIndex = oldValue
            }
        }
        
        var previousFrameIndex = 0 {
            didSet {
                preloadQueue.async {
                    self.updatePreloadedFrames()
                }
            }
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
        
        var contentMode = UIView.ContentMode.scaleToFill
        
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
        init(imageSource source: CGImageSource,
             contentMode mode: UIView.ContentMode,
             size: CGSize,
             framePreloadCount count: Int,
             repeatMode: RepeatMode,
             preloadQueue: DispatchQueue) {
            self.imageSource = source
            self.contentMode = mode
            self.size = size
            self.maxFrameCount = count
            self.repeatMode = repeatMode
            self.preloadQueue = preloadQueue
        }
        
        func frame(at index: Int) -> UIImage? {
            return animatedFrames[safe: index]?.image
        }
        
        func duration(at index: Int) -> TimeInterval {
            return animatedFrames[safe: index]?.duration  ?? .infinity
        }
        
        func prepareFramesAsynchronously() {
            frameCount = Int(CGImageSourceGetCount(imageSource))
            animatedFrames.reserveCapacity(frameCount)
            // if only 1 frame, set repeat mode to .once
            if frameCount <= 1 {
                self.repeatMode = .once
            }
            // load frames
            if self.repeatMode == .infinite {
                preloadQueue.async { [weak self] in
                    self?.setupAnimatedFrames()
                }
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
            (0..<frameCount).forEach { index in
                let frameDuration = AnimatedImage.getFrameDuration(from: imageSource, at: index)
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
            guard let image = CGImageSourceCreateImageAtIndex(imageSource, index, nil) else {
                return nil
            }
            let scaledImage: UIImage
            if needsPrescaling, size != .zero {
                let img = UIImage(cgImage: image)
                let viewMaxWidth = max(size.width, size.height)
                var imgWidth = img.size.width
                var imgHeight = img.size.height
                let scope = imgWidth/imgHeight
                if imgWidth > imgHeight {
                    imgHeight = min(viewMaxWidth, imgHeight)
                    imgWidth = scope * imgHeight
                }
                else {
                    imgWidth = min(viewMaxWidth, imgWidth)
                    imgHeight = imgWidth/scope
                }
                let scaleSize = CGSize(width: imgWidth*UIScreen.main.scale, height: imgHeight*UIScreen.main.scale)
                UIGraphicsBeginImageContext(scaleSize)
                img.draw(in: CGRect(origin: .zero, size: scaleSize))
                scaledImage = UIGraphicsGetImageFromCurrentImageContext()!
                UIGraphicsEndImageContext()
            } else {
                scaledImage = UIImage(cgImage: image)
            }

            return scaledImage
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
                delegate?.animator(self, didPlayAnimationLoops: currentRepeatCount)
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
