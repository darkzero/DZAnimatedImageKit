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
    internal func downloadImageAsync(from url: String) async throws -> (SessionDataTask.CancelToken, AsyncThrowingStream<DownloadEvent, Error>) {
        var cancelToken: SessionDataTask.CancelToken = -1
        let stream = AsyncThrowingStream<DownloadEvent, Error>(bufferingPolicy: .bufferingNewest(32)) { continuation in
            let token = self.downloadImage(from: url) { result in
                switch result {
                case .successData(let source):              // 这里按你的真实 DownloadResult 改
                    let box = ImageSourceBox(raw: source)
                    _ = continuation.yield(.progress(1.0))
                    _ = continuation.yield(.completed(box))
                    continuation.finish()
                case .successFile(let url):
                    // TODO:
                    break
                case .failure: //(let error):
                    //continuation.finish(throwing: error)
                    continuation.finish()
                }
            } progress: { p in
                _ = continuation.yield(.progress(p))
            }
            cancelToken = token
            continuation.onTermination = { @Sendable _ in
                if token != -1 {
                    Task {
                        await self.cancelDownload(url, token: token)
                    }
                }
            }
        }

        return (cancelToken, stream)
    }
    
    internal func cancelDownload(_ url: String, token: SessionDataTask.CancelToken) {
        if let task = self.sessionTasks[url] {
            task.cancel()
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
