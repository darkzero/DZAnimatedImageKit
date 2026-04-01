//
//  DZAnimatedImageProgressView.swift
//  DZAnimatedImageKit
//
//  Created by Yuhua Hu on 2025/09/23.
//

import UIKit

final class DZCircularProgressUIView: UIView {
    private var progressLayer: CAShapeLayer = CAShapeLayer()
    private let trackLayer: CAShapeLayer = CAShapeLayer()
    private var progressLbl: UILabel = UILabel()
    
    public var lineWidth: CGFloat = 8 { didSet { setNeedsLayout() } }
    
    public var progress: CGFloat = 0.0 {
        didSet {
            self.updateProgress(progress)
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    /// common init
    private func commonInit() {
        isOpaque = false
        // track
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = UIColor.secondarySystemFill.cgColor
        trackLayer.lineWidth = lineWidth
        layer.addSublayer(trackLayer)
        
        // progress
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = UIColor.label.withAlphaComponent(0.85).cgColor
        progressLayer.lineWidth = lineWidth
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        self.layer.addSublayer(self.progressLayer)
        
        self.progressLbl.font = .monospacedSystemFont(ofSize: 15, weight: .bold)
        self.progressLbl.textAlignment = .center
        self.progressLbl.text = "0%"
        self.progressLbl.textColor = UIColor.label
        self.addSubview(self.progressLbl)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let maxSize = min(bounds.width, bounds.height)
        let width = min(max(maxSize - 10, 0), 128)
        let rect = CGRect(x: (bounds.width - width)/2,
                          y: (bounds.height - width)/2,
                          width: width, height: width)
        // label
        progressLbl.frame = rect
        
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = width/2 - lineWidth/2
        let path = UIBezierPath(arcCenter: center, radius: max(radius, 0), startAngle: -(.pi/2), endAngle: 1.5 * .pi, clockwise: true).cgPath
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackLayer.frame = bounds
        progressLayer.frame = bounds
        trackLayer.lineWidth = lineWidth
        progressLayer.lineWidth = lineWidth
        trackLayer.path = path
        progressLayer.path = path
        CATransaction.commit()
    }
}

extension DZCircularProgressUIView {
    /// setProgress
    /// - Parameters:
    ///   - value: progress value (Float/CGFloat/Double)
    ///   - animated: animated or not
    public func setProgress<T: BinaryFloatingPoint>(_ value: T, animated: Bool = false) {
        self.updateProgress(CGFloat(value), animated: animated)
    }
    
    /// updateProgress
    /// - Parameters:
    ///   - value: progress value (CGFloat, easy for UIKit)
    ///   - animated: animated or not
    @MainActor
    private func updateProgress(_ value: CGFloat, animated: Bool = false) {
        let clamped: CGFloat = max(0, min(1.0, value))
        guard abs(clamped - progressLayer.strokeEnd) > 0.0001 else { return }
        // progress
        let prefersReduced = UIAccessibility.isReduceMotionEnabled
        let shouldAnimate = animated && !prefersReduced
        if shouldAnimate {
            let arcAnimation = CABasicAnimation(keyPath: "strokeEnd")
            arcAnimation.fromValue = (self.progressLayer.presentation()?.strokeEnd ?? self.progressLayer.strokeEnd)
            arcAnimation.toValue = clamped
            arcAnimation.duration = 0.25
            arcAnimation.timingFunction = .init(name: .easeInEaseOut)
            //arcAnimation.isRemovedOnCompletion = false
            //arcAnimation.fillMode = CAMediaTimingFillMode.both
            self.progressLayer.add(arcAnimation, forKey: "DarwPathAnimation")
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.progressLbl.text = "\(Int(clamped * 100))%"
        progressLbl.accessibilityValue = progressLbl.text
        progressLayer.strokeEnd = clamped
        CATransaction.commit()
    }
}

extension DZCircularProgressUIView {
    class func addToView(_ view: UIView) -> DZCircularProgressUIView {
        let frame = view.bounds
        let progressView = DZCircularProgressUIView(frame: frame)
        progressView.backgroundColor = .clear
        view.addSubview(progressView)
        return progressView
    }
}
