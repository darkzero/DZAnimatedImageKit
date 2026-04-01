//
//  AnimatedImagePipeline.swift
//  DZAnimatedImageKit
//
//  Created by Yuhua Hu on 2025/9/20.
//

import Foundation
import ImageIO

public actor AnimatedImagePipeline {
    public static let shared = AnimatedImagePipeline()
    private init() {}
}

extension AnimatedImagePipeline {
    public func fetchRemote(
        key: String,
        url: URL,
        onProgress: (@Sendable (Float) -> Void)?
    ) async throws -> ImageSourceBox {
        // check cache
        if let cached = await _imgSrcCache.findSource(from: key) {
            onProgress?(1.0)
            return cached
        }

        // download data
        let (bytes, resp) = try await URLSession.shared.bytes(from: url)
        
        let expected: Double? = resp.expectedContentLength > 0 ? Double(resp.expectedContentLength) : nil

        var data = Data()
        var count = 0
        for try await byte in bytes {
            try Task.checkCancellation()
            data.append(byte)
            count &+= 1
            if count % 8192 == 0 {
                if let expected {
                    onProgress?(Float(Double(data.count) / expected))
                }
            }
        }

        // make CGImageSource
        let options: CFDictionary? = nil
        guard let src = CGImageSourceCreateWithData(data as CFData, options) else {
            throw URLError(.cannotCreateFile)
        }
        let box = ImageSourceBox(raw: src)

        // write to cache
        await _imgSrcCache.add(url: key, source: box)

        onProgress?(1.0)
        return box
    }
    
    public func fetchRemote1(key: String, url: URL, onProgress: (@Sendable (Float) -> Void)? = nil) async throws -> ImageSourceBox {
        let (token, stream) = try await SourceDownloader.shared.downloadImageAsync(from: url.absoluteString)
        do {
            for try await ev in stream {
                switch ev {
                case .progress(let p):
                    onProgress?(p)
                case .completed(let box):
                    // 可缓存：await _imgSrcCache.storeSource(box, for: key)
                    return box
                }
            }
            throw URLError(.cancelled)
        } catch {
            // 双保险：如果 stream 是因错误/取消结束，确保底层任务被取消
            await SourceDownloader.shared.cancelDownload(url.absoluteString, token: token)
            throw error
        }

    }
}
