//
//  AnimatedImageController.swift
//  DZAnimatedImageKit
//
//  Created by Codex on 2026/3/3.
//

import CoreGraphics
import Combine
import Foundation

@MainActor
final class AnimatedImageController: ObservableObject {
    @Published private(set) var currentCg: CGImage?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var progress: Float = 0.0

    private var animator: Animator?
    private var loadTask: Task<Void, Never>?
}

extension AnimatedImageController {
    func start(animatedImage: AnimatedImage,
               size: CGSize,
               repeatMode: RepeatMode = .infinite,
               preloadCount: Int = 6,
               screenScale: CGFloat,
               onLoop: (@MainActor @Sendable (_ count: Int) -> Void)? = nil) {
        guard size.width > 0, size.height > 0 else { return }

        stop()
        currentCg = nil
        isLoading = true
        progress = 0.0

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let box = try await animatedImage.load(onProgress: { [weak self] p in
                    Task { @MainActor in
                        self?.progress = p
                    }
                })

                let a = Animator(
                    imageSourceBox: box,
                    screenScale: screenScale,
                    size: size,
                    framePreloadCount: preloadCount,
                    repeatMode: repeatMode
                )
                self.animator = a

                await a.prepareFramesAsynchronously()
                await a.start(
                    onFrame: { [weak self] cg, _ in
                        self?.currentCg = cg
                        self?.isLoading = false
                    },
                    onLoop: { count in
                        onLoop?(count)
                    }
                )
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    func stop() {
        loadTask?.cancel()
        loadTask = nil

        Task { [weak self] in
            guard let self else { return }
            await self.animator?.stop()
            self.animator = nil
        }
    }
}
