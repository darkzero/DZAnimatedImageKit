//
//  DZAnimatedImageView.swift
//  DZAnimatedImageView
//
//  Created by Yuhua Hu on 2025/9/1.
//

import SwiftUI

public enum PlaceholderStyle {
    case clear
    case color(Color)
    case image(Image)
    case systemImage(String, Color)
}

// DZAnimatedImageView
public struct DZAnimatedImageView: View {
    private let animatedImage: AnimatedImage
    private let placeholder: PlaceholderStyle
    private let repeatMode: RepeatMode
    private let preloadCount: Int
    private let onLoop: (@MainActor (Int) -> Void)?
    private let onFinished: (@MainActor () -> Void)?

    private let progressBuilder: @MainActor (DZProgressState, CGSize) -> AnyView

    @StateObject private var controller = AnimatedImageController()
    @State private var didStart = false // flag

    public init(animatedImage: AnimatedImage,
                placeHolder: PlaceholderStyle = .clear,
                repeatMode: RepeatMode = .infinite,
                preloadCount: Int = 6,
                onLoop: (@MainActor (Int) -> Void)? = nil,
                onFinished: (@MainActor () -> Void)? = nil,
                @ViewBuilder progressOverlay: @escaping @MainActor (_ state: DZProgressState, _ size: CGSize) -> some View = DZAnimatedImageView.circularProgressOverlay) {
        self.animatedImage = animatedImage
        self.repeatMode = repeatMode
        self.preloadCount = preloadCount
        self.placeholder = placeHolder
        self.onLoop = onLoop
        self.onFinished = onFinished
        self.progressBuilder = { state, size in
            AnyView(progressOverlay(state, size))
        }
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .center) {
                // 当前帧
                if let cg = controller.currentCg {
                    Image(decorative: cg, scale: UIScreen.main.scale, orientation: .up)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipShape(Rectangle())
                        .transition(.opacity)
                } else {
                    PlaceholderView(placeholder: self.placeholder)
                        .frame(width: geo.size.width, height: geo.size.height)
                }

                // progress
                if controller.isLoading {
                    let progressState: DZProgressState = (controller.progress > 0 && controller.progress < 1) ? .determinate(CGFloat(controller.progress)) : .indeterminate
                    VStack(alignment: .center) {
                        progressBuilder(progressState, CGSize(width: 64, height: 64))
                    }
                    .transition(.opacity)
                }
            }
            .task(id: startKey(animatedImage: animatedImage, size: geo.size, mode: repeatMode)) {
                guard geo.size.width > 0, geo.size.height > 0 else { return }
                await MainActor.run {
                    guard !didStart else { return }
                    didStart = true
                    controller.start(animatedImage: animatedImage,
                                     size: geo.size,
                                     repeatMode: repeatMode,
                                     preloadCount: preloadCount,
                                     screenScale: UIScreen.main.scale,
                                     onLoop: { count in
                        onLoop?(count)
                        switch repeatMode {
                        case .infinite:
                            break
                        case .once:
                            if count >= 1 {
                                onFinished?()
                            }
                        case .finite(let n):
                            if count >= n {
                                onFinished?()
                            }
                        }
                    })
                }
            }
            .onDisappear {
                controller.stop()
                didStart = false
            }
        }
    }

    private func startKey(animatedImage: AnimatedImage, size: CGSize, mode: RepeatMode) -> String {
        let scale = UIScreen.main.scale
        // 转为像素并取整
        let pxW = Int(size.width * scale)
        let pxH = Int(size.height * scale)
        return "\(animatedImage.key)-\(pxW)x\(pxH)-\(mode)"
    }

    private struct PlaceholderView: View {
        let placeholder: PlaceholderStyle
        @ViewBuilder
        public var body: some View {
            switch placeholder {
            case .clear:
                Color.clear
            case .color(let color):
                color
            case .image(let image):
                image
                    .resizable()
                    .scaledToFit()
            case .systemImage(let sysName, let tint):
                Image(systemName: sysName)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(tint)
                    .padding()
            }
        }
    }
}

extension DZAnimatedImageView {
    @MainActor @ViewBuilder
    public static func circularProgressOverlay(_ state: DZProgressState, _ size: CGSize) -> some View {
        let s: CGFloat = min(size.width, size.height) * 0.4
        VStack(alignment: .center) {
            DZCircularProgressView(
                state: state,
                size: max(s, 64.0),
                lineWidth: 7
            )
        }
        .transition(.opacity)
    }
}
