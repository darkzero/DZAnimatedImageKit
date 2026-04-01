//
//  AnimatedImage.swift
//  DZAnimatedImageView
//
//  Created by Yuhua Hu on 2025/6/5.
//

import ImageIO
import Foundation

public struct AnimatedImage {
    public enum SourceType: Sendable {
        case remote(URL)
        case local(URL)
    }
    public let sourceType: SourceType
    public let key: String

    // init with remote url
    public init(url: URL) {
        self.sourceType = SourceType.remote(url)
        self.key = url.absoluteString
    }

    /// init with local path
    public init(path: String) {
        let url = URL(fileURLWithPath: path)
        self.sourceType = .local(url)
        self.key = url.path
    }

    public func load(onProgress: (@Sendable (Float) -> Void)? = nil) async throws -> ImageSourceBox {
        switch self.sourceType {
        case .remote(let url):
            return try await AnimatedImagePipeline.shared.fetchRemote1(key: url.absoluteString, url: url, onProgress: onProgress)
        case .local(let fileUrl):
            return try LocalImageLoader.loadFromFile(url: fileUrl)
        }
    }

    public static func ==(l: AnimatedImage, r: AnimatedImage) -> Bool {
        return l.key == r.key
    }
}

enum LocalImageLoader {
    static func loadFromFile(url: URL) throws -> ImageSourceBox {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw URLError(.fileDoesNotExist)
        }
        return ImageSourceBox(raw: src)
    }
}
