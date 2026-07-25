//
//  SourceDownloader.swift
//  DZAnimatedImageView
//
//  Created by Yuhua Hu on 2025/6/5.
//

import Foundation
import ImageIO

let _imgSrcCache = DefaultImageSourceCache()

public enum DownloadEvent: Sendable {
    case progress(Float)              // 0...1
    case completed(ImageSourceBox)    // download success
}

actor SourceDownloader {
    public static let shared = SourceDownloader(name: "default")
    internal var sessionTasks: [String: SessionDataTask] = [:]
    private let name: String
    init(name: String) {
        if name.isEmpty {
            fatalError("You should specify a name for the downloader. A downloader with empty name is not permitted.")
        }
        self.name = name
    }
}

extension SourceDownloader {
    /// Validate source can actually decode at least one frame.
    /// Some invalid data can still create a non-nil `CGImageSource`, so we verify first-frame decode.
    private static func validatedImageSourceBox(_ source: CGImageSource) throws -> ImageSourceBox {
        guard CGImageSourceGetCount(source) > 0,
              CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else {
            throw URLError(.cannotDecodeContentData)
        }
        return ImageSourceBox(raw: source)
    }

    /// Normalize all download outputs into `ImageSourceBox`.
    /// This keeps `downloadImageAsync` semantics consistent for `.successData` and `.successFile`.
    internal static func makeImageSourceBox(from result: DownloadResult) throws -> ImageSourceBox {
        switch result {
        case .successData(let source):
            return try validatedImageSourceBox(source)
        case .successFile(let fileURL):
            let data = try Data(contentsOf: fileURL)
            guard let src = CGImageSourceCreateWithData(data as CFData, nil) else {
                throw URLError(.cannotDecodeContentData)
            }
            return try validatedImageSourceBox(src)
        case .failure(let error):
            throw error
        }
    }

    internal func downloadImage(from url: String,
                                completion: @escaping ((DownloadResult) -> Void),
                                progress: ((Float) -> Void)? = nil) -> SessionDataTask.CancelToken {
        // Wrap completion so task lifecycle is released once download finishes.
        let wrappedCompletion: (DownloadResult) -> Void = { [weak self] result in
            completion(result)
            Task { [weak self, url] in
                await self?.releaseTask(url: url)
            }
        }
        let taskCallback = SessionDataTask.TaskCallback(onCompleted: wrappedCompletion, onProgress: progress)
        
        if let task = self.sessionTasks[url] {
            let cancelToken = task.addCallback(taskCallback)
            return cancelToken
        }
        // make new task
        let task = SessionDataTask(url: url)
        self.sessionTasks[url] = task
        let cancelToken = task.addCallback(taskCallback)
        task.start()
        return cancelToken
    }
    
    /// downloadImageAsync
    /// 异步版本
    /// - Parameter url: 图片Url
    /// - Returns: 包含进度和结果的数据流
    internal func downloadImageAsync(from url: String) async throws -> (SessionDataTask.CancelToken, AsyncThrowingStream<DownloadEvent, Error>) {
        var cancelToken: SessionDataTask.CancelToken = -1
        let stream = AsyncThrowingStream<DownloadEvent, Error>(bufferingPolicy: .bufferingNewest(32)) { continuation in
            let token = self.downloadImage(from: url) { result in
                do {
                    let box = try Self.makeImageSourceBox(from: result)
                    _ = continuation.yield(.progress(1.0))
                    _ = continuation.yield(.completed(box))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            } progress: { p in
                _ = continuation.yield(.progress(p))
            }
            cancelToken = token
            continuation.onTermination = { @Sendable _ in
                if token != -1 {
                    Task { [self, url, token] in
                        await self.cancelDownload(url, token: token)
                    }
                }
            }
        }

        return (cancelToken, stream)
    }
    
    internal func cancelDownload(_ url: String, token: SessionDataTask.CancelToken) {
        if let task = self.sessionTasks[url] {
            task.removeCallback(token)
            if task.callbackCount() == 0 {
                task.cancel()
                self.sessionTasks[url] = nil
            }
        }
    }
    
    /// Release task of url
    /// - Parameter url: url
    internal func releaseTask(url: String) {
        self.sessionTasks[url] = nil
    }
}
