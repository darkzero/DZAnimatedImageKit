//
//  DZAnimatedImageView.swift
//  DZAnimatedImageView
//
//  Created by Yuhua Hu on 2025/9/1.
//

import SwiftUI

// DZAnimatedImageView
public struct DZAnimatedImageSView: View {
    enum PlaceholderStyle {
        case clear
        case color(Color)
        case image(UIImage)
    }
    
    private let animatedImage: AnimatedImage
    private let placeholder: UIImage?
    private let repeatMode: RepeatMode
    private let preloadCount: Int

    @StateObject private var vm = DZAnimatedImageViewModel()
    @State private var didStart = false // flag

    public init(animatedImage: AnimatedImage,
                placeHolder: UIImage? = nil,
                repeatMode: RepeatMode = .infinite,
                preloadCount: Int = 6) {
        self.animatedImage = animatedImage
        self.repeatMode = repeatMode
        self.preloadCount = preloadCount
        self.placeholder = placeHolder
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // 当前帧
                if let cg = vm.currentCg {
                    Image(decorative: cg, scale: UIScreen.main.scale, orientation: .up)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipShape(Rectangle())
                        .transition(.opacity)
                } else {
                    if let p = self.placeholder {
                        Image(uiImage: p)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipShape(Rectangle())
                            .transition(.opacity)
                    }
                    else {
                        Color.clear
                    }
                }
                
                // progress
                if vm.isLoading {
                    let progressState: DZCircularProgressView.ProgressState = (vm.progress > 0 && vm.progress < 1) ? .determinate(CGFloat(vm.progress)) : .indeterminate
                    VStack(alignment: .center) {
                        DZCircularProgressView(
                            state: progressState,
                            size: 64,
                            lineWidth: 7
                        )
                    }
                    .transition(.opacity)
                }
            }
            .task(id: startKey(animatedImage: animatedImage, size: geo.size, mode: repeatMode)) {
                guard geo.size.width > 0, geo.size.height > 0 else { return }
                await MainActor.run {
                    guard !didStart else { return }
                    didStart = true
                    print("vm instance =", Unmanaged.passUnretained(vm).toOpaque())
                    vm.start(animatedImage: animatedImage,
                             size: geo.size,
                             repeatMode: repeatMode,
                             preloadCount: preloadCount)
                }
            }
            .onDisappear {
                vm.stop()
                didStart = false
            }
        }
    }
    
    private func startKey(animatedImage: AnimatedImage, size: CGSize, mode: RepeatMode) -> String {
        let scale = UIScreen.main.scale
        // 转为像素并取整，避免 200.0 → 199.6667 这类微抖
        let pxW = Int(size.width * scale)
        let pxH = Int(size.height * scale)
        print("key: \(animatedImage.key)")
        return "\(animatedImage.key)"
    }
}
