//
//  DZAnimatedImageProgressView.swift
//  DZAnimatedImageKit
//
//  Created by Yuhua Hu on 2025/09/23.
//

import UIKit

final class DZAnimatedImageProgressView: UIView {
    private var progressLayer: CALayer?
    private var progressLbl: UILabel?
}

extension DZAnimatedImageProgressView {
    internal func updateProgress(_ progress: CGFloat) {
        // TODO
        self.progressLbl?.text = "\(Int(progress * 100))%"
    }
    
    internal func stop() {
        //
    }
    
    init(frame: CGRect) {
        self.frame = frame
        
        /// progress layer
        self.progressLayer = CALayer()
        let origin: CGPoint = CGPoint(x: (self.bounds.width-width)/2,
                                      y: (self.bounds.height-width)/2)
        let width: CGFloat = frame.size.width > frame.size.height ? frame.height : frame.width
        self.progressLayer.frame = CGRect(origin: origin,
                                          size: CGSize(width: width, height: width))
        self.progressLayer.strokeColor = UIColor.label.withAlphaComponent(0.8).cgColor
        self.progressLayer.cornerRadius = 8.0
        self.progressLayer.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.5).cgColor
        self.progressLayer.fillColor = UIColor.clear.cgColor
        self.progressLayer.lineWidth = 8.0
        self.progressLayer.lineCap = .round
        self.progressLayer.strokeEnd = 0.0
        self.layer.addSublayer(self.progressLayer)
        //
        self.progressLbl = UILabel()
    }
}

extension DZAnimatedImageProgressView {
    class func addToView(_ view: UIView) -> DZAnimatedImageProgressView {
        let frame = view.bounds
        let view = DZAnimatedImageProgressView(frame: frame)
        
        return view
    }
    
    internal func removeFromSuperview() {
        self.stop()
        self.removeFromSuperview()
    }
}
