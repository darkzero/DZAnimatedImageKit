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
    //internal var imageSource: CGImageSource?
    var imgSrcBox: ImageSourceBox?
    let isLocal: Bool
    private var downloadTask: Task<ImageSourceBox?, Error>?
    
    private let srcDownloader: SourceDownloader = .shared
    
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
            if let src = CGImageSourceCreateWithURL(url as CFURL, nil) {
                self.init(source: src, key: path, isLocal: true)
            }
            else {
                fatalError("init(path:) can not read resourc file.")
            }
        }
    }
    
    /// init
    /// - Parameters:
    ///   - source: image source
    ///   - key: image string key
    ///   - isLocal: is local image
    private init(source: CGImageSource? = nil, key: String, isLocal: Bool = false) {
        if let source = source {
            self.imgSrcBox = ImageSourceBox(raw: source)
        }
        self.key = key
        self.isLocal = isLocal
        super.init()
    }
    
    /// deinit
    deinit {
        self.imgSrcBox = nil
    }
}

// MARK: - Load task
extension AnimatedImage {
    /// start load web image
    /// - Parameters:
    ///   - completion: completion handle
    ///   - progress: progress %
    /// - Returns: cancel token for cancel
    internal func startLoad(onProgress: ((Float) -> Void)? = nil) async throws -> ImageSourceBox? {
        // image source already loaded
        guard self.imgSrcBox == nil else {
            return self.imgSrcBox
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
                    self.imgSrcBox = validSource
                    return validSource
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

// MARK: - Get frame duration for animator
extension AnimatedImage {
    internal class func getFrameDuration(from imageSource: CGImageSource, at idx: Int) -> TimeInterval {
        guard let property = CGImageSourceCopyPropertiesAtIndex(imageSource, idx, nil) as? [String: Any] else {
            return 0.0
        }
        let defaultDuration: TimeInterval = 1.0/60.0
        var aniInfo: [String: Any]?
        
        if property[kCGImagePropertyGIFDictionary as String] as? [String: Any] != nil {         // gif
            aniInfo = property[kCGImagePropertyGIFDictionary as String] as? [String: Any]
        }
        else if property[kCGImagePropertyPNGDictionary as String] as? [String: Any] != nil {    // png
            aniInfo = property[kCGImagePropertyPNGDictionary as String] as? [String: Any]
        }
        else {
            return defaultDuration
        }
        
        guard let gifInfo = aniInfo else {
            return defaultDuration
        }
        
        let unclampedDelayTime = gifInfo[kCGImagePropertyGIFUnclampedDelayTime as String] as? NSNumber
        let delayTime = gifInfo[kCGImagePropertyGIFDelayTime as String] as? NSNumber
        let duration = unclampedDelayTime ?? delayTime
        
        guard let frameDuration = duration else {
            return defaultDuration
        }
        return max(frameDuration.doubleValue, defaultDuration)
    }
}
