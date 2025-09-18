//
//  DZAnimatedImageUIView.swift
//  DZAnimatedImageUIView
//
//  Created by Yuhua Hu on 2025/9/1.
//

import ImageIO
#if canImport(UIKit)
import UIKit
//public typealias PlatformView = UIView
//public typealias ImageView = UIImageView
//public typealias UIImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias UIView = NSView
public typealias UIImageView = NSImageView
public typealias UIImage = NSImage
#endif

public enum RepeatMode: Equatable {
    case once
    case finite(_ count: UInt)
    case infinite
    
    /// Equatable '=='
    public static func ==(lhs: RepeatMode, rhs: RepeatMode) -> Bool {
        switch (lhs, rhs) {
        case let (.finite(l), .finite(r)):
            return l == r
        case (.once, .once),
             (.infinite, .infinite):
            return true
        case (.once, .finite(let count)),
             (.finite(let count), .once):
            return count == 1
        case (.once, _),
             (.infinite, _),
             (.finite, _):
            return false
        }
    }
}

/// Protocol of 'AnimatedImageViewDelegate'
public protocol DZAnimatedImageUIViewDelegate: AnyObject {
    /// Called after the 'AnimatedImageView' has finished each animation loop.
    /// - Parameters
    ///   - imageView: The 'AnimatedImageView' that is being animated
    ///   - count: The looped count
    func animatedImageView(_ imageView: DZAnimatedImageUIView, didPlayAnimationLoops count: UInt)
    
    /// Called after the 'AnimatedImageView' has reached the max repeat count
    /// - Parameter imageView: The 'AnimatedImageView' that is being animated
    func animatedImageView(_ imageView: DZAnimatedImageUIView, didFinishAnimating: Void)
}

extension DZAnimatedImageUIViewDelegate {
    public func animatedImageView(_ imageView: DZAnimatedImageUIView, didPlayAnimationLoops count: UInt) {}
    public func animatedImageView(_ imageView: DZAnimatedImageUIView, didFinishAnimating: Void) {}
}

@MainActor
public class DZAnimatedImageUIView: UIImageView {
    /// Auto start playing
    public var autoPlay: Bool = true
    /// Whether the image is displaying or not
    public var play: Bool = false
    /// preload frame count
    public var preloadFrameCount = 10
    /// pre scaling
    public var needsPrescaling = true
    public weak var delegate: DZAnimatedImageUIViewDelegate?
    ///
    public var placeHolder: UIImage?
    ///
    public var willShowProgress: Bool = true
    /// Repeat Mode (default is infinite)
    public var repeatMode: RepeatMode = .infinite {
        didSet {
            if oldValue != repeatMode {
                self.reset()
                self.setNeedsDisplay()
                self.layer.setNeedsDisplay()
            }
        }
    }
    
    /// The run loop mode of animation timer
    /// Default is 'RunLoop.Mode.common'
    /// 'RunLoop.Mode.default' will make the animation pause during UIScrollView scrolling
    public var runLoopMode = RunLoop.Mode.common {
        willSet {
            guard runLoopMode == newValue else { return }
            self.stopAnimating()
            self.displayLink.remove(from: .main, forMode: runLoopMode)
            self.displayLink.add(to: .main, forMode: newValue)
            self.startAnimating()
        }
    }
    
    /// Proxy object for preventing a reference cycle
    /// between the 'CADDisplayLink' and 'AnimatedImageView'
    class TargetProxy {
        private weak var target: DZAnimatedImageUIView?
        init(target: DZAnimatedImageUIView) {
            self.target = target
        }
        @MainActor @objc func onScreenUpdate() {
            target?.updateFrameIfNeeded()
        }
    }
    
    /// AImage
    public var aniImage: AnimatedImage? {
        didSet {
            if aniImage != oldValue, !(aniImage?.isLocal ?? true) {
                self.addDownloadProgress()
//                let source = await self.aniImage?.startLoad {  [weak self] progress in
//                    DispatchQueue.main.async {
//                        //
//                    }
//                }
//                self.downloadCancelToken = aniImage?.startLoad(completion: { [weak self] (result, image) in
//                    if result {
//                        self?.aniImage = image
//                        DispatchQueue.main.async {
//                            self?.progressLayer.removeFromSuperlayer()
//                            self?.reset()
//                            self?.setNeedsDisplay()
//                            self?.layer.setNeedsDisplay()
//                        }
//                    }
//                }, progress: { [weak self] (precent) in
//                    self?.showDownloadProgress(precent: precent)
//                }) ?? -1
                self.reset()
                return
            }
            self.reset()
            DispatchQueue.main.async {
                self.setNeedsDisplay()
                self.layer.setNeedsDisplay()
            }
        }
    }
    
    
    // MARK: - Private property
    /// 'Animator' instance that holds the frames of a specific image in memory.
    private var animator: Animator?
    private var progressLayer = CAShapeLayer()
    
    // Dispatch queue used for preloading images.
    private lazy var preloadQueue: DispatchQueue = {
        return DispatchQueue(label: "cn.darkzero.DZAnimatedImageKit.DZAnimatedImageUIView.preloadQueue")
    }()
    
    // A flag to avoid invalidating the displayLink on deinit if it was never created
    // because displayLink is so lazy.
    private var isDisplayLinkInitialized: Bool = false
    // A display link that keeps calling the 'updateFrame' method on every screen refresh.
    @MainActor private lazy var displayLink: CADisplayLink = {
        isDisplayLinkInitialized = true
        let displayLink = CADisplayLink(target: TargetProxy(target: self), selector: #selector(TargetProxy.onScreenUpdate))
        displayLink.add(to: .main, forMode: runLoopMode)
        displayLink.isPaused = true
        return displayLink
    }()
    
    deinit {
        // self.aniImage = nil
        if self.isDisplayLinkInitialized {
            DispatchQueue.main.async {
                self.displayLink.invalidate()
            }
        }
    }
}

extension DZAnimatedImageUIView {
    override open func willMove(toWindow newWindow: UIWindow?) {
        guard let _ = newWindow else {
            //self.clear()
            return
        }
        self.reset()
    }
    
    override open func didMoveToWindow() {
        super.didMoveToWindow()
        didMove()
    }
    
    func onDidAppear() {
        print("DZAnimatedImageUIView onDidAppear")
        Task {
            let srcBox = await try self.aniImage?.startLoad { progress in
                print("\(progress)")
            }
            let source = srcBox?.raw
            self.progressLayer.removeFromSuperlayer()
            self.reset()
            self.setNeedsDisplay()
            self.layer.setNeedsDisplay()
            self.startAnimating()
        }
    }
    /// Clear data when disappear, free the memory
}

extension DZAnimatedImageUIView {
    private func updateFrameIfNeeded() {
        guard let animator = self.animator else {
            return
        }
        Task { @MainActor in
            
        }
        // If finished
        // call finish callback
        guard !animator.isFinished else {
            stopAnimating()
            delegate?.animatedImageView(self, didFinishAnimating: ())
            return
        }
        let duration: CFTimeInterval
        if displayLink.preferredFramesPerSecond == 0 {
            duration = displayLink.duration
        } else {
            // Some devices may have different FPS.
            duration = 1.0 / Double(displayLink.preferredFramesPerSecond)
        }
        
        animator.shouldChangeFrame(with: duration) { [weak self] hasNewFrame in
            if hasNewFrame {
                self?.layer.setNeedsDisplay()
            }
        }
    }
}

extension DZAnimatedImageUIView {
    override open var isAnimating: Bool {
        if isDisplayLinkInitialized {
            return !displayLink.isPaused
        } else {
            return false
        }
    }
    
    /// Start the animation.
    override open func startAnimating() {
        guard !isAnimating else { return }
        if animator?.isReachMaxRepeatCount ?? false {
            return
        }
        displayLink.isPaused = false
    }
    
    /// Stop the animation.
    override open func stopAnimating() {
        super.stopAnimating()
        //self.animator?.resetAnimatedFrames()
        if isDisplayLinkInitialized {
            displayLink.isPaused = true
        }
    }
    
    override open func display(_ layer: CALayer) {
        if let currentFrame = animator?.currentFrameImage {
            layer.contents = currentFrame.cgImage
        } else {
            //layer.contents = self.placeHolder?.cgImage
        }
    }
    
    private func didMove() {
        if self.autoPlay && animator != nil {
            if let _ = superview, let _ = window {
                startAnimating()
            } else {
                stopAnimating()
            }
        }
    }
    
    /// Reset the animator.
    private func reset() {
        animator = nil
        if let aImg = self.aniImage, let imageSource = aImg.imgSrcBox?.raw {
            DispatchQueue.main.async {
                let targetSize = self.bounds.size //bounds.scaled(UIScreen.main.scale).size
                let animator = Animator(
                    imageSource: imageSource,
                    contentMode: self.contentMode,
                    size: targetSize,
                    framePreloadCount: self.preloadFrameCount,
                    repeatMode: self.repeatMode,
                    preloadQueue: self.preloadQueue)
                animator.delegate = self
                animator.needsPrescaling = self.needsPrescaling
                animator.prepareFramesAsynchronously()
                self.animator = animator
                
                if self.image == nil {
                    let img = animator.loadFrame(at: 0)
                    self.image = img
                }
            }
        }
        didMove()
    }
    
    public func clear() {
        self.aniImage = nil
        self.animator?.resetAnimatedFrames()
        self.animator = nil
        self.reset()
    }
}

extension DZAnimatedImageUIView {
    public func cancelDownloading() {
        //self.aniImage?.cancelLoad(token: self.downloadCancelToken)
        self.progressLayer.removeFromSuperlayer()
    }
}

extension DZAnimatedImageUIView {
    internal func addDownloadProgress() {
        // show placeholder image
        DispatchQueue.main.async {
            self.layer.contents = self.placeHolder?.cgImage
        }
        // return when willShowProgress if false
        guard self.willShowProgress else {
            return
        }
        // show progress
        DispatchQueue.main.async {
            let width:CGFloat = max(min(self.bounds.width, self.bounds.height)/2.0, 64.0)
            let processPath = UIBezierPath()
            processPath.lineCapStyle    = CGLineCap.round
            let radius: CGFloat = width*0.75
            let startAngle = -(Float.pi) / 2
            let endAngle = (2 * Float.pi) + startAngle
            
            if self.progressLayer.superlayer == nil, self.progressLayer.frame.width == 0 {
                self.progressLayer.frame = CGRect(origin: CGPoint(x: (self.bounds.width-width)/2, y: (self.bounds.height-width)/2),
                                                  size: CGSize(width: width, height: width))
                self.progressLayer.strokeColor = UIColor.white.withAlphaComponent(0.8).cgColor
                self.progressLayer.cornerRadius = 8.0
                self.progressLayer.backgroundColor = UIColor.gray.withAlphaComponent(0.3).cgColor
                self.progressLayer.fillColor = UIColor.clear.cgColor
                self.progressLayer.lineWidth = 8.0
                self.progressLayer.lineCap = .round
                self.progressLayer.strokeEnd = 0.0
                self.layer.addSublayer(self.progressLayer)
            }
            
            let center = CGPoint(x: self.progressLayer.bounds.midX, y: self.progressLayer.bounds.midY)
            processPath.addArc(withCenter: center,
                               radius: radius/2, startAngle: CGFloat(startAngle), endAngle: CGFloat(endAngle), clockwise: true);
            self.progressLayer.path = processPath.cgPath
        }
    }
    
    internal func showDownloadProgress(precent: Float) {
        let arcAnimation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.strokeEnd))
        //arcAnimation.beginTime = 0.0
        arcAnimation.fromValue = self.progressLayer.presentation()?.strokeEnd
        arcAnimation.toValue  = precent
        arcAnimation.duration = 0.1
        arcAnimation.isRemovedOnCompletion = false
        arcAnimation.fillMode = CAMediaTimingFillMode.both
        self.progressLayer.add(arcAnimation, forKey: "DarwPathAnimation")
        CATransaction.commit()
    }
}

// MARK: - Class function for test
//extension DZAnimatedImageUIView {
//    public class func clearCache() {
//        SourceCache.default.clear()
//    }
//}
