import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
import UIKit
@testable import DZAnimatedImageKit

struct DZAnimatedImageKitTests {
    @Test("RepeatMode equality semantics")
    func repeatModeEquality() {
        #expect(RepeatMode.once == .finite(1))
        #expect(RepeatMode.once == .once)
        #expect(RepeatMode.infinite == .infinite)
        #expect(RepeatMode.finite(3) == .finite(3))
        #expect(RepeatMode.finite(2) != .finite(3))
        #expect(RepeatMode.once != .finite(2))
        #expect(RepeatMode.infinite != .once)
    }

    @Test("AnimatedImage equality by key")
    func animatedImageEquality() {
        let url = URL(string: "https://example.com/a.gif")!
        let lhs = AnimatedImage(url: url)
        let rhs = AnimatedImage(url: url)
        let other = AnimatedImage(url: URL(string: "https://example.com/b.gif")!)

        #expect(lhs == rhs)
        #expect(lhs != other)
        #expect(lhs.key == url.absoluteString)
    }

    @Test("safe index returns nil when out of bounds")
    func safeIndex() {
        let values = [10, 20, 30]
        #expect(values[safe: 0] == 10)
        #expect(values[safe: 2] == 30)
        #expect(values[safe: 3] == nil)
        #expect(values[safe: -1] == nil)
    }

    @Test("Local image load succeeds for valid PNG")
    func localLoadSuccess() async throws {
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("dz-animated-imagekit-\(UUID().uuidString).png")
        try makePNGData().write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let image = AnimatedImage(path: tmpURL.path)
        let source = try await image.load()

        #expect(CGImageSourceGetCount(source.raw) == 1)
    }

    @Test("Local image load throws when file does not exist")
    func localLoadFailure() async {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("dz-animated-imagekit-missing-\(UUID().uuidString).gif")
            .path

        let image = AnimatedImage(path: path)

        await #expect(throws: URLError.self) {
            _ = try await image.load()
        }
    }

    @Test("GIF frame duration has minimum floor")
    func gifFrameDurationMinimum() throws {
        let source = try makeGIFSource(delays: [0.0])
        let duration = AnimatedImageFrames.getFrameDuration(from: source, at: 0)

        #expect(duration >= (1.0 / 60.0))
    }

    @Test("GIF frame duration reads delay metadata")
    func gifFrameDurationMetadata() throws {
        let source = try makeGIFSource(delays: [0.2])
        let duration = AnimatedImageFrames.getFrameDuration(from: source, at: 0)

        #expect(abs(duration - 0.2) < 0.001)
    }
}

private extension DZAnimatedImageKitTests {
    func makePNGData() throws -> Data {
        guard let cg = make1x1CGImage() else {
            throw TestError.imageCreationFailed
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw TestError.destinationCreationFailed
        }

        CGImageDestinationAddImage(destination, cg, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw TestError.finalizeFailed
        }

        return data as Data
    }

    func makeGIFSource(delays: [Double]) throws -> CGImageSource {
        guard let cg = make1x1CGImage() else {
            throw TestError.imageCreationFailed
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.gif.identifier as CFString,
            delays.count,
            nil
        ) else {
            throw TestError.destinationCreationFailed
        }

        let globalProps: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0
            ]
        ]
        CGImageDestinationSetProperties(destination, globalProps as CFDictionary)

        for delay in delays {
            let frameProps: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFDelayTime as String: delay
                ]
            ]
            CGImageDestinationAddImage(destination, cg, frameProps as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw TestError.finalizeFailed
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw TestError.sourceCreationFailed
        }
        return source
    }

    func make1x1CGImage() -> CGImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let image = renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return image.cgImage
    }
}

private enum TestError: Error {
    case imageCreationFailed
    case destinationCreationFailed
    case sourceCreationFailed
    case finalizeFailed
}
