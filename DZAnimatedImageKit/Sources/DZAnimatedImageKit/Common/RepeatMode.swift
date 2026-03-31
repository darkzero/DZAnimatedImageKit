//
//  RepeatMode.swift
//  DZAnimatedImageKit
//
//  Created by Codex on 2026/3/3.
//

import Foundation

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
