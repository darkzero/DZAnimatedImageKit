//
//  SourceCache.swift
//  DZAnimatedImageView
//
//  Created by darkzero on 2019/03/27.
//

import ImageIO
import Foundation
import OSLog

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
