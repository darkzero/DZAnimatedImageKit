import DZAnimatedImageKit
import SwiftUI

private enum ManualRepeatSelection: String, CaseIterable, Identifiable {
    case once
    case finite
    case infinite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .once:
            return "Once"
        case .finite:
            return "Finite"
        case .infinite:
            return "Infinite"
        }
    }

    func makeRepeatMode(finiteCount: UInt) -> RepeatMode {
        switch self {
        case .once:
            return .once
        case .finite:
            return .finite(finiteCount)
        case .infinite:
            return .infinite
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var sampleStore: SampleAnimatedImageStore

    @State private var selection: ManualRepeatSelection = .infinite
    @State private var finiteCount: UInt = 3
    @State private var preloadCount = 6
    @State private var remoteURLString = "https://media.giphy.com/media/ICOgUNjpvO0PC/giphy.gif"
    @State private var remoteReloadToken = UUID()
    @State private var swiftUILoopCount = 0
    @State private var swiftUIFinished = false

    private var repeatMode: RepeatMode {
        selection.makeRepeatMode(finiteCount: finiteCount)
    }

    var body: some View {
        TabView {
            NavigationView {
                List {
                    configurationSection
                    sampleSection(title: "Local GIF", path: sampleStore.gifPath)
                    sampleSection(title: "Local APNG", path: sampleStore.apngPath)
                    remoteSection
                    swiftUIEventsSection
                }
                .navigationTitle("SwiftUI Manual Test")
            }
            .tabItem {
                Label("SwiftUI", systemImage: "sparkles.tv")
            }

            NavigationView {
                UIKitDemoScreen(
                    repeatMode: repeatMode,
                    localPath: sampleStore.gifPath,
                    preloadCount: preloadCount,
                    remoteURLString: remoteURLString
                )
                .navigationTitle("UIKit Manual Test")
            }
            .tabItem {
                Label("UIKit", systemImage: "rectangle.3.group")
            }
        }
    }

    private var configurationSection: some View {
        Section("Playback") {
            Picker("Repeat Mode", selection: $selection) {
                ForEach(ManualRepeatSelection.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            if selection == .finite {
                Stepper("Finite Count: \(finiteCount)", value: $finiteCount, in: 1 ... 10)
            }

            Stepper("Preload Count: \(preloadCount)", value: $preloadCount, in: 1 ... 12)

            if let errorMessage = sampleStore.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
    }

    private func sampleSection(title: String, path: String?) -> some View {
        Section(title) {
            if let path {
                animatedCard(animatedImage: AnimatedImage(path: path), id: path)
                Text(path)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } else {
                ProgressView("Generating sample…")
            }
        }
    }

    private var remoteSection: some View {
        Section("Remote URL") {
            TextField("https://…", text: $remoteURLString)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.footnote.monospaced())

            Button("Reload Remote Sample") {
                remoteReloadToken = UUID()
                resetSwiftUIEvents()
            }

            if let remoteImage = remoteAnimatedImage {
                animatedCard(animatedImage: remoteImage, id: remoteReloadToken.uuidString)
            } else {
                Text("Enter a valid GIF/APNG URL to test network loading and progress UI.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var swiftUIEventsSection: some View {
        Section("SwiftUI Callbacks") {
            metricRow(title: "Loop Count", value: "\(swiftUILoopCount)")
            metricRow(title: "Finished", value: swiftUIFinished ? "Yes" : "No")
            Button("Reset Counters") {
                resetSwiftUIEvents()
            }
        }
    }

    private func animatedCard(animatedImage: AnimatedImage, id: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            DZAnimatedImageView(
                animatedImage: animatedImage,
                placeHolder: .systemImage("photo", .gray),
                repeatMode: repeatMode,
                preloadCount: preloadCount,
                onLoop: { count in
                    swiftUILoopCount = count
                    swiftUIFinished = false
                },
                onFinished: {
                    swiftUIFinished = true
                }
            )
            .id([id, String(describing: repeatMode), "\(preloadCount)"].joined(separator: "-"))
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .background(Color.black.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text(summaryText(for: animatedImage))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
    }

    private var remoteAnimatedImage: AnimatedImage? {
        guard let url = URL(string: remoteURLString), let scheme = url.scheme else { return nil }
        guard scheme == "http" || scheme == "https" else { return nil }
        return AnimatedImage(url: url)
    }

    private func summaryText(for image: AnimatedImage) -> String {
        switch image.sourceType {
        case .local:
            return "Local sample generated at runtime. Suitable for repeat mode and frame decoding checks."
        case .remote:
            return "Remote sample verifies downloading, progress overlay, and cache behavior."
        }
    }

    private func resetSwiftUIEvents() {
        swiftUILoopCount = 0
        swiftUIFinished = false
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(makeSampleStore())
    }

    @MainActor
    private static func makeSampleStore() -> SampleAnimatedImageStore {
        let store = SampleAnimatedImageStore()
        Task { @MainActor in
            await store.prepareSamplesIfNeeded()
        }
        return store
    }
}
