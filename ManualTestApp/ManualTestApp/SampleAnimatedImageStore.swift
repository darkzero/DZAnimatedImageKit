import DZAnimatedImageKit
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

@MainActor
final class SampleAnimatedImageStore: ObservableObject {
    @Published private(set) var gifPath: String?
    @Published private(set) var apngPath: String?
    @Published private(set) var errorMessage: String?

    func prepareSamplesIfNeeded() async {
        guard gifPath == nil || apngPath == nil else { return }

        do {
            let directory = try makeSamplesDirectory()
            let gifURL = directory.appendingPathComponent("sample.gif")
            let apngURL = directory.appendingPathComponent("sample.png")

            try writeGIF(to: gifURL)
            try writeAPNG(to: apngURL)

            gifPath = gifURL.path
            apngPath = apngURL.path
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeSamplesDirectory() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("ManualTestAppSamples", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true, attributes: nil)
        return base
    }

    private func writeGIF(to url: URL) throws {
        let frameCount = 10
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frameCount, nil) else {
            throw SampleBuildError.destinationCreationFailed("GIF")
        }

        let fileProperties = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0
            ]
        ] as CFDictionary
        CGImageDestinationSetProperties(destination, fileProperties)

        for index in 0 ..< frameCount {
            let frameProperties = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: 0.11
                ]
            ] as CFDictionary
            CGImageDestinationAddImage(destination, makeFrame(index: index, total: frameCount), frameProperties)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw SampleBuildError.finalizeFailed("GIF")
        }
    }

    private func writeAPNG(to url: URL) throws {
        let frameCount = 10
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, frameCount, nil) else {
            throw SampleBuildError.destinationCreationFailed("APNG")
        }

        let fileProperties = [
            kCGImagePropertyPNGDictionary: [
                kCGImagePropertyAPNGLoopCount: 0
            ]
        ] as CFDictionary
        CGImageDestinationSetProperties(destination, fileProperties)

        for index in 0 ..< frameCount {
            let frameProperties = [
                kCGImagePropertyPNGDictionary: [
                    kCGImagePropertyAPNGDelayTime: 0.09,
                    kCGImagePropertyAPNGUnclampedDelayTime: 0.09
                ]
            ] as CFDictionary
            CGImageDestinationAddImage(destination, makeFrame(index: index, total: frameCount), frameProperties)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw SampleBuildError.finalizeFailed("APNG")
        }
    }

    private func makeFrame(index: Int, total: Int) -> CGImage {
        let size = CGSize(width: 240, height: 240)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cg = context.cgContext
            let bounds = CGRect(origin: .zero, size: size)

            let colors = [
                UIColor(red: 0.15, green: 0.19, blue: 0.32, alpha: 1).cgColor,
                UIColor(red: 0.98, green: 0.69, blue: 0.33, alpha: 1).cgColor
            ] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            let locations: [CGFloat] = [0, 1]
            let gradient = CGGradient(colorsSpace: space, colors: colors, locations: locations)
            cg.drawLinearGradient(gradient!, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])

            let progress = CGFloat(index) / CGFloat(max(total - 1, 1))
            let circleX = 40 + progress * 160
            let circleY = 52 + sin(progress * .pi * 2) * 36
            let circleRect = CGRect(x: circleX, y: circleY, width: 56, height: 56)
            cg.setFillColor(UIColor.white.withAlphaComponent(0.92).cgColor)
            cg.fillEllipse(in: circleRect)

            let barRect = CGRect(x: 28, y: 176, width: 184, height: 18)
            let fillRect = CGRect(x: 28, y: 176, width: 184 * progress, height: 18)
            let barPath = UIBezierPath(roundedRect: barRect, cornerRadius: 9)
            UIColor.white.withAlphaComponent(0.22).setFill()
            barPath.fill()

            let fillPath = UIBezierPath(roundedRect: fillRect, cornerRadius: 9)
            UIColor.white.withAlphaComponent(0.85).setFill()
            fillPath.fill()

            let title = NSString(string: "Frame \(index + 1)")
            title.draw(
                at: CGPoint(x: 28, y: 24),
                withAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 24, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
            )

            let subtitle = NSString(string: "DZAnimatedImageKit")
            subtitle.draw(
                at: CGPoint(x: 28, y: 206),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.9)
                ]
            )
        }

        guard let cgImage = image.cgImage else {
            fatalError("Failed to create sample frame.")
        }
        return cgImage
    }
}

private enum SampleBuildError: LocalizedError {
    case destinationCreationFailed(String)
    case finalizeFailed(String)

    var errorDescription: String? {
        switch self {
        case .destinationCreationFailed(let kind):
            return "\(kind) sample destination creation failed."
        case .finalizeFailed(let kind):
            return "\(kind) sample generation failed."
        }
    }
}
