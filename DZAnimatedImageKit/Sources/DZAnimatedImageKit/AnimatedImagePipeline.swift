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

    public func fetchRemote1(key: String,
                            url: URL,
                            onProgress: (@Sendable (Float) -> Void)? = nil) async throws -> ImageSourceBox {
        // 命中缓存（按你现有缓存接口替换）
        if let cached = await _imgSrcCache.findSource(from: key) {
            onProgress?(1.0)
            return cached
        }
        
        print("fetchRemote 🌐 start download")
        // 直接复用你现有的异步下载 API
        let (cancelToken, stream) = try await SourceDownloader.shared.downloadImageAsync(from: key)
        print("fetchRemote 🌐 got headers contentLength =", stream)

        // 任务被取消时，确保取消底层下载
        return try await withTaskCancellationHandler(operation: {
            for try await progress in stream {
                print("111")
                try Task.checkCancellation()
                if progress < 1.0 {
                    onProgress?(progress)
                } else {
                    // 下载结束：从你的缓存里取增量/完整 CGImageSource
                    if let box = await _imgSrcCache.findSource(from: key) {
                        onProgress?(1.0)
                        return box
                    }
                    throw URLError(.cannotCreateFile)
                }
            }
            throw URLError(.cancelled)
        }, onCancel: {
            Task { await SourceDownloader.shared.cancelDownload(key, token: cancelToken) }
        })
    }
}

extension AnimatedImagePipeline {
    public func fetchRemote(
        key: String,
        url: URL,
        onProgress: (@Sendable (Float) -> Void)?
    ) async throws -> ImageSourceBox {
        print("fetchRemote ⏩ url =", url.absoluteString)
        // check cache
        if let cached = await _imgSrcCache.findSource(from: key) {
            onProgress?(1.0)
            return cached
        }

        // download data
        print("fetchRemote 🌐 start download")
        let (bytes, resp) = try await URLSession.shared.bytes(from: url)
        print("fetchRemote 🌐 got headers contentLength =", resp.expectedContentLength)
        
        let expected: Double? = resp.expectedContentLength > 0 ? Double(resp.expectedContentLength) : nil

        var data = Data()
        var count = 0
        for try await byte in bytes {
            try Task.checkCancellation()
            data.append(byte)
            count &+= 1
            if count % 8192 == 0 {
                print("fetchRemote 📦 bytes =", data.count)
                if let expected {
                    onProgress?(Float(Double(data.count) / expected))
                }
            }
        }

        // 3) 构建 CGImageSource
        let options: CFDictionary? = nil
        guard let src = CGImageSourceCreateWithData(data as CFData, options) else {
            print("fetchRemote ❌ cannotCreateFile")
            throw URLError(.cannotCreateFile)
        }
        print("fetchRemote ✅ success frames =", CGImageSourceGetCount(src))
        let box = ImageSourceBox(raw: src)

        // write to cache
        await _imgSrcCache.add(url: key, source: box)

        onProgress?(1.0)
        return box
    }
}
