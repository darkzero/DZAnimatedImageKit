import DZAnimatedImageKit
import ImageIO
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

private enum ManualSampleSelection: String, CaseIterable, Identifiable {
    case localGIF
    case localAPNG
    case remoteURL

    var id: String { rawValue }

    var title: String {
        switch self {
        case .localGIF:
            return "GIF"
        case .localAPNG:
            return "APNG"
        case .remoteURL:
            return "Remote"
        }
    }
}

private enum SampleMetadataSource {
    case localPath(String)
    case remoteURL(URL)
}

private struct SampleDescriptor {
    let title: String
    let image: AnimatedImage
    let id: String
    let metadataSource: SampleMetadataSource
}

private struct SampleMetrics {
    let frameCount: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let estimatedMemoryBytes: Int
}

private enum RemoteQuickURL: String, CaseIterable, Identifiable {
    case validGIF
    case invalidJSON
    case invalid404

    var id: String { rawValue }

    var title: String {
        switch self {
        case .validGIF:
            return "Valid GIF"
        case .invalidJSON:
            return "Invalid JSON"
        case .invalid404:
            return "Invalid 404"
        }
    }

    var urlString: String {
        switch self {
        case .validGIF:
            return "https://media3.giphy.com/media/v1.Y2lkPTc5MGI3NjExdHhtOHVqMWptNHU0Z3l5NXQ2ajNub2VlNHJ4cG5xa2UydnZmbTEwZyZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/PMcyzEALWVUS2IAcjC/giphy.gif"
        case .invalidJSON:
            return "https://httpbin.org/json"
        case .invalid404:
            return "https://httpbin.org/status/404"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var sampleStore: SampleAnimatedImageStore

    @State private var selection: ManualRepeatSelection = .infinite
    @State private var sampleSelection: ManualSampleSelection = .localGIF
    @State private var finiteCount: UInt = 3
    @State private var preloadCount = 6
    @State private var remoteURLString = "https://media3.giphy.com/media/v1.Y2lkPTc5MGI3NjExdHhtOHVqMWptNHU0Z3l5NXQ2ajNub2VlNHJ4cG5xa2UydnZmbTEwZyZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/PMcyzEALWVUS2IAcjC/giphy.gif"
    @State private var remoteReloadToken = UUID()
    @State private var swiftUILoopCount = 0
    @State private var swiftUIFinished = false

    @State private var metrics: SampleMetrics?
    @State private var isLoadingMetrics = false
    @State private var metricsError: String?
    @State private var decodedBufferBytes = 0
    @State private var enableMultiInstanceRemoteTest = false
    @State private var showRemoteInstanceA = true
    @State private var showRemoteInstanceB = true
    @State private var remoteLoopCountA = 0
    @State private var remoteLoopCountB = 0
    @State private var remoteFinishedA = false
    @State private var remoteFinishedB = false
    @State private var remoteDecodedBytesA = 0
    @State private var remoteDecodedBytesB = 0

    private var repeatMode: RepeatMode {
        selection.makeRepeatMode(finiteCount: finiteCount)
    }

    var body: some View {
        TabView {
            NavigationView {
                List {
                    configurationSection
                    remoteSection
                    sampleDisplaySection
                    swiftUIEventsSection
                    remoteSemanticsSection
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
        .onChange(of: sampleSelection) { _ in
            resetSwiftUIEvents()
            metrics = nil
            metricsError = nil
            decodedBufferBytes = 0
            resetRemoteSemanticsState()
        }
    }

    private var configurationSection: some View {
        Section("Playback") {
            Picker("Sample", selection: $sampleSelection) {
                ForEach(ManualSampleSelection.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

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

    @ViewBuilder
    private var remoteSection: some View {
        if sampleSelection == .remoteURL {
            Section("Remote URL") {
                TextField("https://…", text: $remoteURLString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.footnote.monospaced())

                Text("Quick Cases")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(RemoteQuickURL.allCases) { preset in
                            Button(preset.title) {
                                applyRemotePreset(preset)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Button("Reload / Cancel Current") {
                    reloadCurrentRemoteSample()
                }
            }
        }
    }

    private var sampleDisplaySection: some View {
        Section("Sample") {
            if let descriptor = currentSampleDescriptor {
                animatedCard(sample: descriptor)
                    .task(id: descriptor.id) {
                        await refreshMetrics(for: descriptor)
                    }
            } else if sampleSelection == .remoteURL {
                Text("Enter a valid GIF/APNG URL to preview and analyze frame stats.")
                    .foregroundStyle(.secondary)
            } else {
                ProgressView("Loading sample…")
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

    @ViewBuilder
    private var remoteSemanticsSection: some View {
        if sampleSelection == .remoteURL, let url = validRemoteURL {
            Section("Downloader Semantics Test") {
                Toggle("Enable Same-URL Multi-Instance Test", isOn: $enableMultiInstanceRemoteTest)
                    .onChange(of: enableMultiInstanceRemoteTest) { enabled in
                        if !enabled {
                            showRemoteInstanceA = true
                            showRemoteInstanceB = true
                            resetRemoteInstanceCounters()
                        }
                    }

                if enableMultiInstanceRemoteTest {
                    Text("Use the two toggles below to remove one instance while keeping the other alive. Expected behavior: hiding A should not interrupt B.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Toggle("Show Instance A", isOn: $showRemoteInstanceA)
                    Toggle("Show Instance B", isOn: $showRemoteInstanceB)

                    if showRemoteInstanceA {
                        remoteInstanceCard(
                            title: "Remote Instance A",
                            url: url,
                            instanceID: "a",
                            onLoop: { count in
                                remoteLoopCountA = count
                                remoteFinishedA = false
                            },
                            onFinished: {
                                remoteFinishedA = true
                            },
                            onDecodedBufferChanged: { bytes in
                                remoteDecodedBytesA = bytes
                            }
                        )
                    }

                    if showRemoteInstanceB {
                        remoteInstanceCard(
                            title: "Remote Instance B",
                            url: url,
                            instanceID: "b",
                            onLoop: { count in
                                remoteLoopCountB = count
                                remoteFinishedB = false
                            },
                            onFinished: {
                                remoteFinishedB = true
                            },
                            onDecodedBufferChanged: { bytes in
                                remoteDecodedBytesB = bytes
                            }
                        )
                    }

                    metricRow(title: "A Loop / Finished", value: "\(remoteLoopCountA) / \(remoteFinishedA ? "Yes" : "No")")
                    metricRow(title: "B Loop / Finished", value: "\(remoteLoopCountB) / \(remoteFinishedB ? "Yes" : "No")")
                    metricRow(title: "A Decoded Buffer", value: formatBytes(remoteDecodedBytesA))
                    metricRow(title: "B Decoded Buffer", value: formatBytes(remoteDecodedBytesB))
                }
            }
        }
    }

    private func animatedCard(sample: SampleDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(sample.title)
                .font(.headline)

            DZAnimatedImageView(
                animatedImage: sample.image,
                placeHolder: .systemImage("photo", .gray),
                repeatMode: repeatMode,
                preloadCount: preloadCount,
                onLoop: { count in
                    swiftUILoopCount = count
                    swiftUIFinished = false
                },
                onFinished: {
                    swiftUIFinished = true
                },
                onDecodedBufferChanged: { bytes in
                    decodedBufferBytes = bytes
                }
            )
            .id([sample.id, String(describing: repeatMode), "\(preloadCount)"].joined(separator: "-"))
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .background(Color.black.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            if isLoadingMetrics {
                ProgressView("Analyzing frames and memory…")
                    .font(.footnote)
            }

            metricRow(title: "Frame Count", value: metrics.map { "\($0.frameCount)" } ?? "--")
            metricRow(title: "Pixel Size", value: metrics.map { "\($0.pixelWidth)x\($0.pixelHeight)" } ?? "--")
            metricRow(title: "Estimated Memory", value: metrics.map { formatBytes($0.estimatedMemoryBytes) } ?? "--")
            metricRow(title: "Decoded Buffer Memory", value: formatBytes(decodedBufferBytes))

            if let metricsError {
                Text(metricsError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
    }

    private var currentSampleDescriptor: SampleDescriptor? {
        switch sampleSelection {
        case .localGIF:
            guard let path = sampleStore.gifPath else { return nil }
            return SampleDescriptor(
                title: "Local GIF · littledog.gif",
                image: AnimatedImage(path: path),
                id: "local-gif-\(path)",
                metadataSource: .localPath(path)
            )

        case .localAPNG:
            guard let path = sampleStore.apngPath else { return nil }
            return SampleDescriptor(
                title: "Local APNG · elephant.png",
                image: AnimatedImage(path: path),
                id: "local-apng-\(path)",
                metadataSource: .localPath(path)
            )

        case .remoteURL:
            guard let url = validRemoteURL else { return nil }
            return SampleDescriptor(
                title: "Remote Animated Image",
                image: AnimatedImage(url: url),
                id: "remote-\(remoteReloadToken.uuidString)-\(url.absoluteString)",
                metadataSource: .remoteURL(url)
            )
        }
    }

    private var validRemoteURL: URL? {
        guard let url = URL(string: remoteURLString), let scheme = url.scheme else { return nil }
        guard scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    @MainActor
    private func refreshMetrics(for descriptor: SampleDescriptor) async {
        isLoadingMetrics = true
        metrics = nil
        metricsError = nil

        defer {
            isLoadingMetrics = false
        }

        do {
            let source: CGImageSource
            switch descriptor.metadataSource {
            case .localPath(let path):
                let fileURL = URL(fileURLWithPath: path)
                guard let localSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
                    throw MetricsError.unableToOpenSource
                }
                source = localSource

            case .remoteURL(let url):
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let remoteSource = CGImageSourceCreateWithData(data as CFData, nil) else {
                    throw MetricsError.unableToDecodeData
                }
                source = remoteSource
            }

            metrics = try buildMetrics(from: source)
        } catch is CancellationError {
            // Ignore cancellation from task refresh.
        } catch {
            metrics = nil
            metricsError = error.localizedDescription
        }
    }

    private func buildMetrics(from source: CGImageSource) throws -> SampleMetrics {
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else {
            throw MetricsError.emptySource
        }

        guard
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
            let height = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
            width > 0,
            height > 0
        else {
            throw MetricsError.missingDimensions
        }

        // Full decode estimate: all frames decoded to RGBA at once.
        let estimatedMemoryBytes = frameCount * width * height * 4
        return SampleMetrics(
            frameCount: frameCount,
            pixelWidth: width,
            pixelHeight: height,
            estimatedMemoryBytes: estimatedMemoryBytes
        )
    }

    private func remoteInstanceCard(
        title: String,
        url: URL,
        instanceID: String,
        onLoop: @escaping (Int) -> Void,
        onFinished: @escaping () -> Void,
        onDecodedBufferChanged: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            DZAnimatedImageView(
                animatedImage: AnimatedImage(url: url),
                placeHolder: .systemImage("photo", .gray),
                repeatMode: repeatMode,
                preloadCount: preloadCount,
                onLoop: onLoop,
                onFinished: onFinished,
                onDecodedBufferChanged: onDecodedBufferChanged
            )
            .id([
                "remote-instance",
                instanceID,
                remoteReloadToken.uuidString,
                url.absoluteString,
                String(describing: repeatMode),
                "\(preloadCount)"
            ].joined(separator: "-"))
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .background(Color.black.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.vertical, 4)
    }

    private func applyRemotePreset(_ preset: RemoteQuickURL) {
        remoteURLString = preset.urlString
        reloadCurrentRemoteSample()
    }

    private func reloadCurrentRemoteSample() {
        remoteReloadToken = UUID()
        resetSwiftUIEvents()
        metrics = nil
        metricsError = nil
        decodedBufferBytes = 0
        resetRemoteInstanceCounters()
    }

    private func resetRemoteInstanceCounters() {
        remoteLoopCountA = 0
        remoteLoopCountB = 0
        remoteFinishedA = false
        remoteFinishedB = false
        remoteDecodedBytesA = 0
        remoteDecodedBytesB = 0
    }

    private func resetRemoteSemanticsState() {
        enableMultiInstanceRemoteTest = false
        showRemoteInstanceA = true
        showRemoteInstanceB = true
        resetRemoteInstanceCounters()
    }

    private func resetSwiftUIEvents() {
        swiftUILoopCount = 0
        swiftUIFinished = false
    }

    private func formatBytes(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
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

private enum MetricsError: LocalizedError {
    case unableToOpenSource
    case unableToDecodeData
    case emptySource
    case missingDimensions

    var errorDescription: String? {
        switch self {
        case .unableToOpenSource:
            return "Unable to open image source from local file."
        case .unableToDecodeData:
            return "Unable to decode image source from remote data."
        case .emptySource:
            return "Image source contains no frames."
        case .missingDimensions:
            return "Unable to read frame pixel size."
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .environmentObject(makeSampleStore())
                .previewDisplayName("Light")

            ContentView()
                .environmentObject(makeSampleStore())
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark")
        }
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
#endif
