//
//  AnimatedImage.swift
//  DZAnimatedImageView
//
//  Created by Yuhua Hu on 2025/6/5.
//

import ImageIO
import Foundation

public class AnimatedImage: NSObject {
    private let key: String
    internal var imageSource: CGImageSource?
    let isLocal: Bool
    
    /// override ==
    /// - Parameters:
    ///   - l: left instance
    ///   - r: right instance
    /// - Returns: if the keyString is same
    public static func ==(l: AnimatedImage, r: AnimatedImage) -> Bool {
        return l.key == r.key
    }
    
    /// init with image on web (url
    /// - Parameter url: image url
    public convenience init?(url: String) async {
        let cache: ImageSourceCache = DefaultImageSourceCache()
        // if already in cache
        if let src = await cache.findSource(from: url) {
            self.init(source: src.raw, key: url, isLocal: false)
        } else {
            self.init(key: url, isLocal: false)
        }
    }
    
    /// init with image in local resource
    /// - Parameter path: image path
    public convenience init(path: String) async {
        let cache: ImageSourceCache = DefaultImageSourceCache()
        if let src = await cache.findSource(from: path) {
            self.init(source: src.raw, key: path, isLocal: true)
        } else {
            let url = URL(fileURLWithPath: path)
            let src = CGImageSourceCreateWithURL(url as CFURL, nil)
            self.init(source: src, key: path, isLocal: true)
        }
    }
    
    /// init
    /// - Parameters:
    ///   - source: image source
    ///   - key: image string key
    ///   - isLocal: is local image
    private init(source: CGImageSource? = nil, key: String, isLocal: Bool = false) {
        self.imageSource = source
        self.key = key
        self.isLocal = isLocal
        super.init()
    }
    
    /// deinit
    deinit {
        self.imageSource = nil
    }
}

// MARK: - Load task
extension AnimatedImage {
    /// start load web image
    /// - Parameters:
    ///   - completion: completion handle
    ///   - progress: progress %
    /// - Returns: cancel token for cancel
    internal func startLoad(completion: ((Bool, AnimatedImage)->Void)?, progress: ((Float)->Void)? = nil) -> SessionDataTask.CancelToken {
        // image source already loaded
        guard self.imageSource == nil else {
            completion?(true, self)
            return -1
        }
        
        // completion handle
        let onCompleted = { (result: DownloadResult) -> Void in
            switch result {
            case .success(let src):
                self.imageSource = src
                //SourceCache.default.add(url: self.key, source: src)
                SourceDownloader.default.releaseTask(url: self.keyString)
                completion?(true, self)
                break
            case .failure:
                completion?(false, self)
                break
            }
        }
        
        // progress handle
        let onProgress = { (precent: Float) -> Void in
            progress?(precent)
        }
        
        // start download task
        let cancelToken = SourceDownloader.default.downloadImage(from: self.keyString, completion: onCompleted, progress: onProgress)
        
        return cancelToken
    }
    
    /// cancel load
    /// - Parameter token: cancel token
    internal func cancelLoad(token: SessionDataTask.CancelToken) {
        SourceDownloader.default.cancelDownload(self.keyString, token: token)
    }
}
