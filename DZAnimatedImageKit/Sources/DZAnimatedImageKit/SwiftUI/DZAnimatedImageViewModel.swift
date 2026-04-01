//
//  DZAnimatedImageViewModel.swift
//  DZAnimatedImageKit
//
//  Created by Yuhua Hu on 2025/9/25.
//

import SwiftUI

@MainActor
@available(*, deprecated, message: "Use AnimatedImageController directly")
final class DZAnimatedImageViewModel: ObservableObject {
    private let controller = AnimatedImageController()

    var currentCg: CGImage? { controller.currentCg }
    var isLoading: Bool { controller.isLoading }
    var progress: Float { controller.progress }
}

extension DZAnimatedImageViewModel {
    func start(animatedImage: AnimatedImage,
               size: CGSize,
               repeatMode: RepeatMode = .infinite,
               preloadCount: Int = 6) {
        controller.start(animatedImage: animatedImage,
                         size: size,
                         repeatMode: repeatMode,
                         preloadCount: preloadCount,
                         screenScale: UIScreen.main.scale)
    }

    func stop() {
        controller.stop()
    }
}
