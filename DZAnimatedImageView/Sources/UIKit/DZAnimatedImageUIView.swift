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

class DZAnimatedImageUIView: UIImageView {
    /// Auto start playing
    public var autoPlay: Bool = true
    /// Whether the image is displaying or not
    public var play: Bool = false
    /// preload frame count
    public var preloadFrameCount = 10
    /// pre scaling
    public var needsPrescaling = true
    ///
    public var placeHolder: UIImage? = UIImage(named: placeHolderName, in: Bundle(for: AnimatedImageView.self), compatibleWith: nil)
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
    public var runLoopMode = kFRunLoopModeCommon {
        willSet {
            guard runLoopMode == newValue else { return }
            self.stopAnimating()
            self.displayLink.remove(from: .main, forMode: runLoopMode)
            self.displayLink.add(to: .main, forMode: newValue)
            self.startAnimating()
        }
    }
    
    /// AImage
    public var aniImage: AnimatiedImage? {
        didSet {
            if aniImage != oldValue, !(aniImage?.isLocalImage ?? true) {
                self.addDownloadProgress()
                self.downloadCancelToken = aImage?.startLoad(completion: { [weak self] (result, image) in
                    if result {
                        self?.aniImage = image
                        DispatchQueue.main.async {
                            self?.progressLayer.removeFromSuperlayer()
                            self?.reset()
                            self?.setNeedsDisplay()
                            self?.layer.setNeedsDisplay()
                        }
                    }
                }, progress: { [weak self] (precent) in
                    self?.showDownloadProgress(precent: precent)
                }) ?? -1
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
        return DispatchQueue(label: "cn.dark-egg.DarkEggKit.AnimatedImageView.preloadQueue")
    }()
    
    // A flag to avoid invalidating the displayLink on deinit if it was never created
    // because displayLink is so lazy.
    private var isDisplayLinkInitialized: Bool = false
    // A display link that keeps calling the 'updateFrame' method on every screen refresh.
    private lazy var displayLink: CADisplayLink = {
        isDisplayLinkInitialized = true
        let displayLink = CADisplayLink(target: TargetProxy(target: self), selector: #selector(TargetProxy.onScreenUpdate))
        displayLink.add(to: .main, forMode: runLoopMode)
        displayLink.isPaused = true
        return displayLink
    }()
    
    deinit {
        self.aImage = nil
        if self.isDisplayLinkInitialized {
            self.displayLink.invalidate()
        }
    }
}

extension DZAnimatedImageUIView {
    /// Clear data when disappear, free the memory
    override open func willMove(toWindow newWindow: UIWindow?) {
        guard let _ = newWindow else {
            //self.clear()
            return
        }
        self.reset()
        self.startAnimating()
    }
    
    override open func didMoveToWindow() {
        super.didMoveToWindow()
        didMove()
    }
}

extension DZAnimatedImageUIView {
    private func updateFrameIfNeeded() {
        guard let animator = animator else {
            return
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
        if let aImg = self.aImage, let imageSource = aImg.imageSource {
            DispatchQueue.main.async {
                let targetSize = self.bounds.size //bounds.scaled(UIScreen.main.scale).size
                let animator = Animator(
                    imageSource: imageSource,
                    contentMode: self.contentMode,
                    size: targetSize,
                    framePreloadCount: self.framePreloadCount,
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
        self.aImage = nil
        self.animator?.resetAnimatedFrames()
        self.animator = nil
        self.reset()
    }
}

extension DZAnimatedImageUIView {
    public func cancelDownloading() {
        self.aImage?.cancelLoad(token: self.downloadCancelToken)
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
