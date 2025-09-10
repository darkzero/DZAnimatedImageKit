//
//  AnimatedImage.swift
//  DZAnimatedImageView
//
//  Created by Yuhua Hu on 2025/6/5.
//

import ImageIO
import Foundation
import UIKit

final public class AnimatedImage: NSObject {
    private let key: String
    private var cancelToken: SessionDataTask.CancelToken = -1
    internal var imageSource: CGImageSource?
    let isLocal: Bool
    private var downloadTask: Task<ImageSourceBox?, Error>?
    
    private let srcDownloader: SourceDownloader = .default
    
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
    internal func startLoad(onProgress: ((Float) -> Void)? = nil) async throws -> CGImageSource? {
        // image source already loaded
        guard self.imageSource == nil else {
            return self.imageSource
        }
        // download
        let (cancelToken, stream) = await try self.srcDownloader.downloadImageAsync(from: self.key)
        self.cancelToken = cancelToken
        do {
            for try await progress in stream {
                if progress < 1.0 {
                    print("Progress: \(progress)")
                    onProgress?(progress)
                }
                else {
                    let source = await _imgSrcCache.findSource(from: self.key)
                    guard let validSource = source else {
                        throw URLError(.cannotCreateFile)
                    }
                    self.imageSource = validSource.raw
                    return self.imageSource
                }
            }
            throw URLError(.cancelled)
        }
        catch(let error) {
            await SourceDownloader.default.cancelDownload(self.key, token: self.cancelToken)
            self.cancelToken = -1
            throw error
        }
    }
    
    /// cancel load
    /// - Parameter token: cancel token
    internal func cancelLoad(token: SessionDataTask.CancelToken) async {
        await self.srcDownloader.cancelDownload(self.key, token: token)
    }
}
