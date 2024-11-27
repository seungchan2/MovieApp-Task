//
//  ImageCache.swift
//  TaskSampleApp
//
//  Created by MEGA_Mac on 11/27/24.
//

import UIKit

actor ImageCache {
    static let shared = ImageCache()
    private var cache: [String: UIImage] = [:]
    
    private init() {}
    
    func image(for url: String) -> UIImage? {
        return cache[url]
    }
    
    func insertImage(_ image: UIImage, for url: String) {
        cache[url] = image
    }
    
    func removeImage(for url: String) {
        cache.removeValue(forKey: url)
    }
    
    func clearCache() {
        cache.removeAll()
    }
}
