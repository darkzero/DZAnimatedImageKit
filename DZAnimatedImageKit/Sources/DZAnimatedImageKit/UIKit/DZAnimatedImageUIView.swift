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
public final class DZAnimatedImageUIView: UIView {
    // MARK: - Public surface
    public var aniImage: AnimatedImage? {
        didSet {
            loadAndStart()
        }
    }
    public var placeHolder: UIImage?
    public var willShowProgress: Bool = true
    public var repeatMode: RepeatMode = .infinite
    public weak var delegate: DZAnimatedImageUIViewDelegate?
    
    // MARK: - Private UI state (MainActor only)
    private var currentFrameCGImage: CGImage?
    private var animator: Animator?
    private var isAnimating: Bool = false
    private var loadTask: Task<Void, Never>?
    private let progressView = UIProgressView(progressViewStyle: .default)
    
    // Optional: a very light progress indicator
//    private let progressLayer: CAShapeLayer = {
//        let l = CAShapeLayer()
//        l.strokeColor = UIColor.systemGray.cgColor
//        l.fillColor = UIColor.clear.cgColor
//        l.lineWidth = 2
//        l.isHidden = true
//        return l
//    }()
    private var progressLayer = CAShapeLayer()
    
    public override class var layerClass: AnyClass { CALayer.self }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        layer.contentsGravity = .resizeAspect
        //layer.addSublayer(progressLayer)
        // self.addSubview(self.progressView)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        //progressLayer.frame = bounds
        //progressLayer.path = UIBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 4), cornerRadius: 8).cgPath
    }
    
    //
    /// loadAndStart
    private func loadAndStart() {
        loadTask?.cancel()
        loadTask = nil
        Task {
            await animator?.stop()
            animator = nil
        }

        guard let img = aniImage else { return }
        
        self.addDownloadProgress()
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                await MainActor.run {
                    self.progressView.isHidden = false
                    self.progressView.progress = 0
                }
                
                print("start load")
                let box = try await img.load(onProgress: { [weak self] p in
                    Task { @MainActor in
                        print("DZAnimatedImageUIView progress is \(p)")
                        self?.progressView.progress = p
                        self?.showDownloadProgress(precent: p)
                    }
                })
                print("load returned")
                let count = CGImageSourceGetCount(box.raw)
                assert(count > 0, "Remote CGImageSource has 0 frames")
                if let testFirst = CGImageSourceCreateImageAtIndex(box.raw, 0, nil) {
                    // 临时把第一帧塞给 layer，看得见说明渲染链路没问题
                    await MainActor.run { self.layer.contents = testFirst }
                } else {
                    assertionFailure("Cannot create first frame image from source")
                }

                // Animator 用 ImageSourceBox（避免 CGImageSource Sendable 告警）
                let a = Animator(imageSourceBox: box,
                                 contentMode: self.contentMode,
                                 size: self.bounds.isEmpty ? CGSize(width: 1, height: 1) : self.bounds.size,
                                 framePreloadCount: 6,
                                 repeatMode: self.repeatMode)
                self.animator = a
                print("remove progress")
                self.progressLayer.removeFromSuperlayer()
                await a.prepareFramesAsynchronously()

                await a.start(
                    onFrame: { [weak self] cgImage, _ in self?.layer.contents = cgImage },
                    onLoop:  { _ in /* 可转发 delegate */ }
                )

                await MainActor.run { self.progressView.isHidden = true }
            } catch {
                print("load failed:", error)
                await MainActor.run { self.progressView.isHidden = true }
            }
        }
    }
    
    @inlinable
    func withTimeout<T: Sendable>(
        seconds: Double,
        _ op: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await op() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw URLError(.timedOut)
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    public func startAnimatingq() {
        guard !isAnimating, let animator else { return }
        isAnimating = true
        //progressLayer.isHidden = true
        
        Task { [weak self] in
            guard let self else { return }
            // 跨 actor 调用需要 await：放到子任务里就可以 await 了
            await animator.start(
                onFrame: { [weak self] cgImage, _ in
                    precondition(Thread.isMainThread, "onFrame not on main!")
                    guard let self else { return }
                    // onFrame 被标注了 @MainActor，这里在主线程安全更新 UI
                    self.layer.contents = cgImage
                },
                onLoop: { [weak self] count in
                    precondition(Thread.isMainThread, "onFrame not on main!")
                    guard let self else { return }
                    self.delegate?.animatedImageView(self, didPlayAnimationLoops: UInt(count))
                }
            )
        }
    }
    
    public func stopAnimating() {
        isAnimating = false
        Task { [weak self] in
            await self?.animator?.stop()
        }
    }
    
    public func reset() {
        stopAnimating()
        currentFrameCGImage = nil
        layer.contents = nil
    }
}

extension DZAnimatedImageUIView {
    public func cancelDownloading() {
        //self.aniImage?.cancelLoad(token: self.downloadCancelToken)
        self.progressLayer.removeFromSuperlayer()
    }
    
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
            processPath.lineCapStyle = CGLineCap.round
            let radius: CGFloat = width * 0.75
            let startAngle = -(Float.pi) / 2
            let endAngle = (2 * Float.pi) + startAngle
            
            if self.progressLayer.superlayer == nil, self.progressLayer.frame.width == 0 {
                self.progressLayer.frame = CGRect(origin: CGPoint(x: (self.bounds.width-width)/2, y: (self.bounds.height-width)/2),
                                                  size: CGSize(width: width, height: width))
                self.progressLayer.strokeColor = UIColor.white.withAlphaComponent(0.8).cgColor
                self.progressLayer.cornerRadius = 8.0
                self.progressLayer.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.5).cgColor
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

// MARK: -
/// RepeatMode
public enum RepeatMode: Equatable, Sendable {
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

extension UIView.ContentMode {
    var dz_contentsGravity: CALayerContentsGravity {
        switch self {
        case .scaleAspectFill: return .resizeAspectFill
        case .scaleAspectFit: return .resizeAspect
        case .scaleToFill: return .resize
        default: return .resizeAspect
        }
    }
}
