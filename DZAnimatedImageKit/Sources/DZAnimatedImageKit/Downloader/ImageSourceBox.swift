//
//  ImageSourceBox.swift
//  DZAnimatedImageKit
//
//  Created by Yuhua Hu on 2025/9/15.
//

import ImageIO

public class ImageSourceBox: @unchecked Sendable {
    public let raw: CGImageSource
    public init(raw: CGImageSource) {
        self.raw = raw
    }
}
