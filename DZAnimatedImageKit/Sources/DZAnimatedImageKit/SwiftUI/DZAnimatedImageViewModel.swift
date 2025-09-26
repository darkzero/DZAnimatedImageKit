//
//  DZAnimatedImageViewModel.swift
//  DZAnimatedImageKit
//
//  Created by Yuhua Hu on 2025/9/25.
//

import SwiftUI
import ImageIO

@MainActor
final class DZAnimatedImageViewModel: ObservableObject {
    @Published var currentCg: CGImage?
    @Published var isLoading: Bool = false
    @Published var progress: Float = 0.0
    
    private var animator: DZAnimatedImageUIView.Animator?
    private var loadTask: Task<Void, Never>?
}

extension DZAnimatedImageViewModel {
    func start(animatedImage: AnimatedImage, size: CGSize, repeatMode: RepeatMode = .infinite, preloadCount: Int = 6) {
        print("AnimatedImageVM start: \(size)")
        guard size.width > 0, size.height > 0 else { return } // is size is 0, not start
        stop()
        isLoading = true
        progress = 0.0
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let box = try await animatedImage.load(onProgress: { [weak self] p in
                    Task { @MainActor in
                        print("-- loading \(self?.isLoading), progress: \(p)")
                        self?.progress = p
                    }
                })

                // 构建 Animator（注意传 UIScreen.main.scale）
                let a = DZAnimatedImageUIView.Animator(
                    imageSourceBox: box,
                    screenScale: UIScreen.main.scale,
                    contentMode: .scaleAspectFit,
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
                    onLoop: { _ in }
                )
            } catch(let error) {
                await MainActor.run {
                    self.isLoading = false
                }
                // 这里可以做错误 UI 上报
                print("AnimatedImageVM load/start failed:", error)
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
