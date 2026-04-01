//
//  DZAnimatedImageUIView.swift
//  DZAnimatedImageUIView
//
//  Created by Yuhua Hu on 2025/9/1.
//

import Combine
import ImageIO
#if canImport(UIKit)
import UIKit
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
    private let controller = AnimatedImageController()
    private var progressView: DZCircularProgressUIView?
    private var subscriptions = Set<AnyCancellable>()

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
        self.progressView = DZCircularProgressUIView.addToView(self)
        self.progressView?.isHidden = true
        bindController()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        progressView?.frame = bounds
    }

    private func bindController() {
        controller.$currentCg
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cg in
                self?.layer.contents = cg
            }
            .store(in: &subscriptions)

        controller.$progress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] p in
                guard let self else { return }
                guard self.willShowProgress else { return }
                self.showDownloadProgress(precent: p)
            }
            .store(in: &subscriptions)

        controller.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                guard let self else { return }
                self.progressView?.isHidden = !self.willShowProgress || !loading
            }
            .store(in: &subscriptions)
    }

    /// loadAndStart
    private func loadAndStart() {
        guard let img = aniImage else {
            controller.stop()
            layer.contents = nil
            progressView?.isHidden = true
            return
        }

        let imageSize = self.bounds.isEmpty ? CGSize(width: 1, height: 1) : self.bounds.size
        controller.start(animatedImage: img,
                         size: imageSize,
                         repeatMode: self.repeatMode,
                         preloadCount: 6,
                         screenScale: UIScreen.main.scale,
                         onLoop: { [weak self] count in
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
        })
    }

    public func startAnimatingq() {
        loadAndStart()
    }

    public func stopAnimating() {
        controller.stop()
    }

    public func reset() {
        stopAnimating()
        layer.contents = nil
    }
}

extension DZAnimatedImageUIView {
    public func cancelDownloading() {
        controller.stop()
        self.progressView?.isHidden = true
    }

    internal func showDownloadProgress(precent: Float) {
        self.progressView?.setProgress(precent)
    }
}
