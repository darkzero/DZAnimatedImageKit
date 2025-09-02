//
//  SourceCache.swift
//  DZAnimatedImageView
//
//  Created by darkzero on 2019/03/27.
//

//import UIKit
import OSLog
import ImageIO
import Foundation

public class ImageSourceBox: @unchecked Sendable {
    public let raw: CGImageSource
    public init(raw: CGImageSource) {
        self.raw = raw
    }
}

protocol ImageSourceCache {
    func findSource(from url: String) async -> ImageSourceBox?
    func add(url: String, source: ImageSourceBox) async
    func remove(url: String) async
    func clear() async
}

actor DefaultImageSourceCache: ImageSourceCache {
    private let cache = NSCache<NSString, ImageSourceBox>()
    public init(countLimit: Int = 50) {
        cache.countLimit = countLimit
    }
    
    public func findSource(from url: String) async -> ImageSourceBox? {
        return cache.object(forKey: url as NSString)
    }
    
    public func add(url: String, source: ImageSourceBox) async {
        // NSCache
        cache.setObject(source, forKey: url as NSString)
    }
    
    public func remove(url: String) async {
        cache.removeObject(forKey: url as NSString)
    }
    
    public func clear() async {
        cache.removeAllObjects()
    }
}

extension DefaultImageSourceCache {
    #if canImport(UIKit)
    private func onReceiveMemoryWarning(_ notification: Notification) {
        
    }
    #endif
    private func moveCacheToStorage() {
        
    }
}

//#if canImport(UIKit)
//import UIKit
//final class _MemoryWarningBridge: NSObject {
//    static let shared = _MemoryWarningBridge()
//    private override init() {
//        super.init()
//        NotificationCenter.default.addObserver(
//            self, selector: #selector(onWarning),
//            name: UIApplication.didReceiveMemoryWarningNotification, object: nil
//        )
//    }
//    @objc private func onWarning() {
//        Task { await _imageSourceCache.clear() }
//    }
//}
//// 在库初始化时触发监听（例如放在任意公共入口的静态初始化里）
//private let _ = _MemoryWarningBridge.shared
//#endif

//internal class SourceCache: NSObject  {
//    internal static let shared: SourceCache = {SourceCache()}()
//    private var cache: NSCache<NSObject, CGImageSource> = NSCache()
//    
//    //private let logger: Logger = Logger(subsystem: "SourceCache", category: "DZAnimatedImage")
//    
//    override init() {
//        self.cache.countLimit = 10
//        super.init()
//        //NotificationCenter.default.addObserver(self, selector: #selector(onReceiveMemoryWarning(_:)), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
//    }
//    
//    internal func findSource(from url: String) -> CGImageSource? {
//        //Logger.debug("find source in cache")
//        let key = NSString(string: url)
//        // check cache
//        if let src = cache.object(forKey: key) {
//            //Logger.debug("end load from cache")
//            return src
//        }
//        // TODO: check storage
//        return nil
//    }
//    
//    internal func add(url: String, source: CGImageSource) {
//        let key = NSString(string: url)
//        guard let _ = cache.object(forKey: key) else {
//            self.cache.setObject(source, forKey: key)
//            return
//        }
//    }
//    
//    internal func remove(url: String) {
//        let key = NSString(string: url)
//        cache.removeObject(forKey: key)
//    }
//    
//    internal func clear() {
//        self.cache.removeAllObjects()
//    }
//}
//
//// MARK: - On memory warning
//extension SourceCache {
//    @objc private func onReceiveMemoryWarning(_ notification: Notification) {
//        // TODO:
//        print("Receive memory warning.")
//        //self.moveFromCacheToStorage()
//    }
//}
//
//// MARK: - File cache
//extension SourceCache {
//    private func moveFromCacheToStorage() {
//        fatalError("TODO: ")
//    }
//    
//    private func saveToFile(url: String, src: CGImageSource) {
//        fatalError("TODO: ")
//    }
//    
//    private func loadFromFile(url: String) -> CGImageSource? {
//        fatalError("TODO: ")
//    }
//}
