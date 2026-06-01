import Foundation
import SwiftUI

@MainActor
final class SampleAnimatedImageStore: ObservableObject {
    @Published private(set) var gifPath: String?
    @Published private(set) var apngPath: String?
    @Published private(set) var errorMessage: String?

    func prepareSamplesIfNeeded() async {
        guard gifPath == nil || apngPath == nil else { return }

        do {
            if gifPath == nil {
                gifPath = try resolveLocalPath(name: "littledog", ext: "gif")
            }
            if apngPath == nil {
                apngPath = try resolveLocalPath(name: "elephant", ext: "png")
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolveLocalPath(name: String, ext: String) throws -> String {
        // Preview may run with a different main bundle, so probe multiple bundles.
        let bundles = [Bundle.main, Bundle(for: BundleProbeToken.self)] + Bundle.allBundles + Bundle.allFrameworks
        for bundle in bundles {
            if let url = bundle.url(forResource: name, withExtension: ext) {
                return url.path
            }
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Resource") {
                return url.path
            }
        }
        // In SwiftUI Preview, resources may not be copied into preview host bundle.
        // Fallback to workspace resource path resolved from this source file location.
        if isRunningForPreviews, let previewURL = resolvePreviewWorkspacePath(name: name, ext: ext) {
            return previewURL.path
        }
        throw SampleBuildError.missingResource("\(name).\(ext)")
    }

    private var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private func resolvePreviewWorkspacePath(name: String, ext: String) -> URL? {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL.deletingLastPathComponent().deletingLastPathComponent()
        let candidate = projectRoot.appendingPathComponent("Resource/\(name).\(ext)")
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            return nil
        }
        return candidate
    }
}

private final class BundleProbeToken {}

private enum SampleBuildError: LocalizedError {
    case missingResource(String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let file):
            return "Required sample resource '\(file)' was not found in app bundle."
        }
    }
}
