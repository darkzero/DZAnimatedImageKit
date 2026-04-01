import DZAnimatedImageKit
import SwiftUI
import UIKit

struct UIKitDemoScreen: View {
    let repeatMode: RepeatMode
    let localPath: String?
    let preloadCount: Int
    let remoteURLString: String

    @State private var useRemote = false
    @State private var loopCount = 0
    @State private var finished = false

    var body: some View {
        List {
            Section("Source") {
                Toggle("Use Remote URL", isOn: $useRemote)
                Text(useRemote ? remoteURLString : (localPath ?? "Generating local sample…"))
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text("Repeat mode follows the SwiftUI tab settings.")
                    .foregroundStyle(.secondary)
            }

            Section("UIKit Preview") {
                UIKitAnimatedImagePreview(
                    source: makeSource(),
                    repeatMode: repeatMode,
                    onLoop: { count in
                        loopCount = count
                        finished = false
                    },
                    onFinished: {
                        finished = true
                    }
                )
                .frame(height: 280)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            Section("UIKit Callbacks") {
                metricRow(title: "Loop Count", value: "\(loopCount)")
                metricRow(title: "Finished", value: finished ? "Yes" : "No")
                metricRow(title: "Preload Count", value: "\(preloadCount)")
                Text("UIKit view always uses the built-in progress UI.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func makeSource() -> AnimatedImage? {
        if useRemote, let url = URL(string: remoteURLString), let scheme = url.scheme, scheme == "http" || scheme == "https" {
            return AnimatedImage(url: url)
        }
        if let localPath {
            return AnimatedImage(path: localPath)
        }
        return nil
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

private struct UIKitAnimatedImagePreview: UIViewRepresentable {
    let source: AnimatedImage?
    let repeatMode: RepeatMode
    let onLoop: (Int) -> Void
    let onFinished: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoop: onLoop, onFinished: onFinished)
    }

    func makeUIView(context: Context) -> DZAnimatedImageUIView {
        let view = DZAnimatedImageUIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 20
        view.layer.masksToBounds = true
        view.willShowProgress = true
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: DZAnimatedImageUIView, context: Context) {
        uiView.repeatMode = repeatMode
        uiView.aniImage = source
    }

    final class Coordinator: NSObject, DZAnimatedImageUIViewDelegate {
        private let onLoop: (Int) -> Void
        private let onFinished: () -> Void

        init(onLoop: @escaping (Int) -> Void, onFinished: @escaping () -> Void) {
            self.onLoop = onLoop
            self.onFinished = onFinished
        }

        func animatedImageView(_ imageView: DZAnimatedImageUIView, didPlayAnimationLoops count: UInt) {
            onLoop(Int(count))
        }

        func animatedImageViewFinished(_ imageView: DZAnimatedImageUIView) {
            onFinished()
        }
    }
}
