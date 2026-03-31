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
        let defaultDuration: TimeInterval = 1.0 / 60.0
        guard let property = CGImageSourceCopyPropertiesAtIndex(imageSource, idx, nil) as? [CFString: Any] else {
            return defaultDuration
        }

        // GIF: use GIF delay keys.
        if let gifInfo = property[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
            let unclampedDelayTime = gifInfo[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber
            let delayTime = gifInfo[kCGImagePropertyGIFDelayTime] as? NSNumber
            let duration = unclampedDelayTime ?? delayTime
            guard let frameDuration = duration else {
                return defaultDuration
            }
            return max(frameDuration.doubleValue, defaultDuration)
        }

        // APNG: use APNG delay keys under PNG dictionary.
        if let apngInfo = property[kCGImagePropertyPNGDictionary] as? [CFString: Any] {
            let unclampedDelayTime = apngInfo[kCGImagePropertyAPNGUnclampedDelayTime] as? NSNumber
            let delayTime = apngInfo[kCGImagePropertyAPNGDelayTime] as? NSNumber
            let duration = unclampedDelayTime ?? delayTime
            guard let frameDuration = duration else {
                return defaultDuration
            }
            return max(frameDuration.doubleValue, defaultDuration)
        }

        // Unknown animated format: fallback.
        return defaultDuration
    }
}
