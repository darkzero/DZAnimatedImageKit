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
                                completion: @escaping ((DownloadResult) async -> Void),
                                progress: ((Float) async -> Void)? = nil) -> SessionDataTask.CancelToken {
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
    
    internal func cancelDownload(_ url: String, token: SessionDataTask.CancelToken) {
        if let task = self.sessionTasks[url] {
            task.cancel(token: token)
//            if !task.containsCallbacks {
//                let sessionTask = self.sessionTasks.data
//            }
        }
    }
    
    internal func releaseTask(url: String) {
        //Logger.debug()
        self.sessionTasks[url]?.sessionDataTask?.cancel()
        self.sessionTasks[url]?.sessionDataTask = nil
        //let t = self.sessionTasks[url]
        self.sessionTasks[url] = nil
    }
}
