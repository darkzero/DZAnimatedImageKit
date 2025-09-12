//
//  Array+SafeIndex.swift
//  DZAnimatedImageView
//
//  Created by Yuhua Hu on 2025/9/11.
//

import Foundation

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices ~= index ? self[index] : nil
    }
}
