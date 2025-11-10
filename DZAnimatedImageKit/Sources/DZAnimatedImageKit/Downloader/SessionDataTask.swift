////
////  SessionDataTask.swift
////  DZAnimatedImageView
////
////  Created by darkzero on 2025/6/6.
////

import ImageIO
import Foundation
import ObjectiveC

enum DownloadResult {
    case successData(_ source: CGImageSource)
    case successFile(_ url: URL)
    case failure(Error)
}

public final class SessionDataTask: NSObject {
    public typealias CancelToken = Int
    public struct TaskCallback {
        let onCompleted: ((DownloadResult) -> Void)?
        let onProgress: ((Float) -> Void)?
    }
    
    // MARK: - private state
    private let urlString: String
    private let urlSession: URLSession
    private var downloadTask: URLSessionDataTask?
    private var resumeData: Data?
    private var isRunning: Bool = false
    private let q = DispatchQueue(label: "com.yourco.sessiondatatask.state")
    private let delegateQueue: OperationQueue
    private var observation: NSKeyValueObservation?
    
    // callback map
    private var nextToken: CancelToken = 1
    private var callbacks: [CancelToken: TaskCallback] = [:]
    
    
    
    // for async
    private var incrementalImgSrc: CGImageSource = CGImageSourceCreateIncremental(nil)
    var recievedData = Data()
    var expectedLeght: Int64 = 0
    
    internal var sessionDataTask: URLSessionDataTask?
    private var started: Bool = false
    
    private let lock = NSLock()
    private var currentToken = 0
    
    init(url: String, session: URLSession? = nil) {
        self.urlString = url
        if let s = session {
            self.urlSession = s
        }
        else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 15
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.urlSession = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        }
        self.delegateQueue = OperationQueue()
        self.delegateQueue.qualityOfService = .userInitiated
        self.delegateQueue.maxConcurrentOperationCount = 1
        super.init()
    }
    
    deinit {
    }
}

extension SessionDataTask {
    // MARK: - Add/Remove callbacks
    @discardableResult
    func addCallback(_ cb: TaskCallback) -> CancelToken {
        q.sync {
            let tok = nextToken
            nextToken += 1
            callbacks[tok] = cb
            return tok
        }
    }
    
    func removeCallback(_ token: CancelToken) {
        q.sync {
            callbacks[token] = nil
        }
    }
    
    /// start or no resume data
    func start() {
        q.sync {
            guard !isRunning else {
                return
            }
            guard let url = URL(string: urlString) else {
                notifyComplete(.failure(URLError(.badURL)))
                return
            }
            
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            let session = URLSession(configuration: .default)
            
            let task = session.dataTask(with: request) { [weak self] data, _, error in
                guard let self else { return }
                if let error = error {
                    notifyComplete(.failure(error))
                    return
                }
                guard let data = data, let src = CGImageSourceCreateWithData(data as CFData, nil) else {
                    notifyComplete(.failure(URLError(.cannotDecodeContentData)))
                    return
                }
                notifyComplete(.successData(src))
            }
            
            // 👇 这里用 task.progress 来监听进度
            observation = task.progress.observe(\.fractionCompleted) { [weak self] prog, _ in
                self?.notifyProgress(Float(prog.fractionCompleted))
            }
//            let task = urlSession.downloadTask(with: url) { [weak self] tmpURL, resp, error in
//                self?.handleCompletion(tmpURL: tmpURL, error: error)
//            }
            downloadTask = task
            isRunning = true
            task.resume()
        }
    }
    
    /// if resumeData not nil, resume
    func resumeIfPossible() {
        q.sync {
            guard !isRunning else { return }
            guard let blob = resumeData else {
                start()
                return
            }
            let task = urlSession.downloadTask(withResumeData: blob) { [weak self] tmpURL, resp, error in
                self?.handleCompletion(tmpURL: tmpURL, error: error)
            }
            downloadTask = task
            isRunning = true
            task.resume()
        }
    }
    
    func pauseForBackground() {
        q.sync {
            guard let task = downloadTask, isRunning else { return }
            isRunning = false
            // 生成 resumeData：完成后即可回前台恢复
            task.cancel(byProducingResumeData: { [weak self] data in
                self?.q.async {
                    self?.resumeData = data
                    self?.downloadTask = nil
                }
            })
        }
    }
    
    func cancel() {
        q.sync {
            isRunning = false
            downloadTask?.cancel()
            downloadTask = nil
            resumeData = nil
        }
    }
    
    // MARK: - Callback broadcast
    private func notifyProgress(_ p: Float) {
        let arr = callbacks.values
        arr.forEach { $0.onProgress?(p) }
    }
    
    private func notifyComplete(_ result: DownloadResult) {
        let arr = callbacks.values
        // 完成后将所有 callback 移除，避免重复调用
        callbacks.removeAll(keepingCapacity: false)
        arr.forEach { $0.onCompleted?(result) }
    }
    
    
    // MARK: Completion handler (内部)
    private func handleCompletion(tmpURL: URL?, error: Error?) {
        // 这个闭包默认在后台 queue 回来；我们在内部串行队列上整理状态，再统一回调
        q.sync {
            self.isRunning = false
            self.downloadTask = nil

            if let err = error as NSError? {
                if err.domain == NSURLErrorDomain && err.code == NSURLErrorCancelled {
                    // 如果是我们调用 pause 触发的取消：resumeData 会在 pause 回调里保存
                    // 此处不当做失败，不触发 completion；交由 UI 进入 .paused 状态
                    return
                } else {
                    notifyComplete(.failure(err))
                    return
                }
            }

            guard let tmp = tmpURL else {
                notifyComplete(.failure(URLError(.unknown)))
                return
            }

            do {
                let data = try Data(contentsOf: tmp)
                CGImageSourceUpdateData(incrementalImgSrc, data as CFData, true)
                notifyComplete(.successData(incrementalImgSrc))
            } catch {
                notifyComplete(.failure(error))
            }
        }
    }
}

//extension SessionDataTask: URLSessionDownloadDelegate {
//    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
//        //
//    }
//    
//    public func urlSession(_ session: URLSession,
//                           downloadTask: URLSessionDownloadTask,
//                           didWriteData bytesWritten: Int64,
//                           totalBytesWritten: Int64,
//                           totalBytesExpectedToWrite: Int64) {
//        guard totalBytesExpectedToWrite > 0 else { return }
//        let p = Float(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
//        notifyProgress(p)
//    }
//}


//// MARK: - URLSessionDataDelegate
//extension SessionDataTask: URLSessionDataDelegate {
//    internal func loadImageAsync(from url: String) -> URLSessionDataTask? {
//        if let url = URL(string: url) {
//            let session = URLSession(configuration: URLSessionConfiguration.ephemeral, delegate: self, delegateQueue: OperationQueue())
//            session.configuration.timeoutIntervalForRequest = 15
//            let urlRequest = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
//            let sessionTask = session.dataTask(with: urlRequest)
//            return sessionTask
//        }
//        return nil
//    }
//    
//    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
//                           didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
//        completionHandler(.allow)
//        self.expectedLeght = response.expectedContentLength
//        //Logger.debug("_expectedLeght: ", expectedLeght);
//    }
//    
//    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
//        recievedData.append(data)
//        let isloadFinish = (self.expectedLeght == self.recievedData.count)
//        if isloadFinish {
//            CGImageSourceUpdateData(incrementalImgSrc, self.recievedData as CFData, isloadFinish)
//            self.onUrlSessionLoadEnd(source: incrementalImgSrc)
//            self.recievedData = Data()
//            session.invalidateAndCancel()
//            dataTask.cancel()
//        }
//        else {
//            let per = Float(self.recievedData.count)/Float(self.expectedLeght)
//            self.onUrlSessionLoaded(percent: per)
//        }
//    }
//}
//
//// MARK: -
////extension SessionDataTask {
////    private func onUrlSessionLoadEnd(source: CGImageSource?) {
////        for tcb in self.callbacks {
////            if let src = source {
////                tcb.value.onCompleted?(.success(src))
////            }
////            else {
////                tcb.value.onCompleted?(.failure)
////            }
////        }
////        self.cancelAll()
////    }
////    
////    private func onUrlSessionLoaded(percent: Float = 0) {
////        for tcb in self.callbacks {
////            tcb.value.onProgress?(percent)
////        }
////    }
////}
