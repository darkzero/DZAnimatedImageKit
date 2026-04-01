import SwiftUI

@main
struct ManualTestApp: App {
    @StateObject private var sampleStore = SampleAnimatedImageStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sampleStore)
                .task {
                    await sampleStore.prepareSamplesIfNeeded()
                }
        }
    }
}
