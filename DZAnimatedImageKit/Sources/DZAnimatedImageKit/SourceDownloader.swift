//
//  SourceDownloader.swift
//  DZAnimatedImageView
//
//  Created by Yuhua Hu on 2025/6/5.
//

import Foundation

let _imgSrcCache = DefaultImageSourceCache()

actor SourceDownloader {
    /*nonisolated(unsafe)*/ internal static let `default` = SourceDownloader(name: "default")
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
    internal func downloadImage(from url: String,
                                completion: @escaping ((DownloadResult) -> Void),
                                progress: ((Float) -> Void)? = nil) -> SessionDataTask.CancelToken {
        let taskCallback = SessionDataTask.TaskCallback(onCompleted: completion, onProgress: progress)
        
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
    internal func downloadImageAsync(from url: String) async throws -> (SessionDataTask.CancelToken, AsyncThrowingStream<Float, Error>) {
        var cancelToken: SessionDataTask.CancelToken = -1
        let stream = AsyncThrowingStream { continuation in
            cancelToken = self.downloadImage(from: url) { result in
                switch result {
                case .success(let source):
                    // 成功时，发送 1.0 的进度，然后将 CGImageSource 封装并结束数据流
                    continuation.yield(1.0)
                    let imageBox = ImageSourceBox(raw: source)
                    continuation.finish(throwing: nil)
                case .failure:
                    // 失败时，抛出错误并结束数据流
                    continuation.finish(throwing: URLError(.cannotFindHost))
                }
            } progress: { p in
                // 收到进度更新时，发送进度值
                continuation.yield(p)
            }
        }
        
        return (cancelToken, stream)
    }
    
    internal func cancelDownload(_ url: String, token: SessionDataTask.CancelToken) {
        if let task = self.sessionTasks[url] {
            task.cancel(token: token)
//            if !task.containsCallbacks {
//                let sessionTask = self.sessionTasks.data
//            }
        }
    }
    
    /// Release task of url
    /// - Parameter url: url
    internal func releaseTask(url: String) {
        self.sessionTasks[url]?.sessionDataTask?.cancel()
        self.sessionTasks[url]?.sessionDataTask = nil
        self.sessionTasks[url] = nil
    }
}
