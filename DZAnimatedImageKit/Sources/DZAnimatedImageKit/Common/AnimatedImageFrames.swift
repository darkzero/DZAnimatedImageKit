//
//  AnimatedImageFrames.swift
//  DZAnimatedImageKit
//
//  Created by Yuhua Hu on 2025/9/28.
//

import Foundation
import ImageIO

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
