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
import OSLog

/// Protocol of 'AnimatedImageViewDelegate'
public protocol DZAnimatedImageUIViewDelegate: AnyObject {
    /// Called after the 'AnimatedImageView' has finished each animation loop.
    /// - Parameters
    ///   - imageView: The 'AnimatedImageView' that is being animated
    ///   - count: The looped count
    func animatedImageView(_ imageView: DZAnimatedImageUIView, didPlayAnimationLoops count: UInt)
    
    /// Called after the 'AnimatedImageView' has reached the max repeat count
    /// - Parameter imageView: The 'AnimatedImageView' that is being animated
    func animatedImageViewFinished(_ imageView: DZAnimatedImageUIView)
}

extension DZAnimatedImageUIViewDelegate {
    public func animatedImageView(_ imageView: DZAnimatedImageUIView, didPlayAnimationLoops count: UInt) {}
    public func animatedImageViewFinished(_ imageView: DZAnimatedImageUIView) {}
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
    private var progressView: DZAnimatedImageProgressView?
    //private var progressLayer = CAShapeLayer()
    //
    private let logger: Logger = .init(subsystem: "cn.darkzero.DZAnimatedImageKit", category: "DZAnimatedImageUIView")
    
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
        self.progressView = DZAnimatedImageProgressView.addToView(self)
        self.progressView?.isHidden = true
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
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
        
        //self.addDownloadProgress()
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                await MainActor.run {
                    self.progressView?.isHidden = false
                    self.progressView?.setProgress(0.0)
                }
                
                let box = try await img.load(onProgress: { [weak self] p in
                    Task { @MainActor in
                        self?.showDownloadProgress(precent: p)
                    }
                })
                let scale = UIScreen.main.scale
                let a = Animator(imageSourceBox: box,
                                 screenScale: scale,
                                 contentMode: self.contentMode,
                                 size: self.bounds.isEmpty ? CGSize(width: 1, height: 1) : self.bounds.size,
                                 framePreloadCount: 6,
                                 repeatMode: self.repeatMode)
                self.animator = a
                await a.prepareFramesAsynchronously()

                await a.start(
                    onFrame: { [weak self] cgImage, _ in self?.layer.contents = cgImage },
                    onLoop:  {  [weak self] count in
                        guard let self else { return }
                        switch self.repeatMode {
                        case .once:
                            self.delegate?.animatedImageViewFinished(self)
                        case .finite(let limit):
                            if count < limit {
                                self.delegate?.animatedImageView(self, didPlayAnimationLoops: UInt(count))
                            }
                            else {
                                self.delegate?.animatedImageViewFinished(self)
                            }
                        case .infinite:
                            self.delegate?.animatedImageView(self, didPlayAnimationLoops: UInt(count))
                        }
                    }
                )
                await self.hideProgress()
            } catch {
                logger.error("load failed: \(error.localizedDescription)")
                await self.hideProgress()
            }
        }
    }
    
    private func hideProgress() async {
        await MainActor.run {
            self.progressView?.isHidden = true
            self.progressView?.removeFromSuperview()
            self.progressView = nil
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
                    guard let self else { return }
                    self.layer.contents = cgImage
                },
                onLoop: { [weak self] count in
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
        //self.progressLayer.removeFromSuperlayer()
        self.progressView?.isHidden = true
    }
    
    internal func showDownloadProgress(precent: Float) {
        self.progressView?.setProgress(precent)
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
