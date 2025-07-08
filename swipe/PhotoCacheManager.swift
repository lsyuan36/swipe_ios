//
//  PhotoCacheManager.swift
//  swipe
//
//  Created by 賴聖元 on 2025/7/8.
//

import SwiftUI
import Photos

#if os(iOS)
import UIKit
#endif

// 照片缓存管理器
class PhotoCacheManager: ObservableObject {
    static let shared = PhotoCacheManager()
    private let imageManager = PHCachingImageManager()
    #if os(iOS)
    private var imageCache: [String: UIImage] = [:]
    #else
    private var imageCache: [String: NSImage] = [:]
    #endif
    private let cacheQueue = DispatchQueue(label: "photo.cache", qos: .userInitiated)
    
    private init() {
        // 配置缓存参数，提高性能
        imageManager.allowsCachingHighQualityImages = true
    }
    
    // 获取缓存的图片 - 增加安全检查
    #if os(iOS)
    func getCachedImage(for asset: PHAsset) -> UIImage? {
        guard !asset.localIdentifier.isEmpty else {
            print("⚠️ Asset localIdentifier is empty")
            return nil
        }
        let key = String(asset.localIdentifier)
        return imageCache[key]
    }
    #else
    func getCachedImage(for asset: PHAsset) -> NSImage? {
        guard !asset.localIdentifier.isEmpty else {
            print("⚠️ Asset localIdentifier is empty")
            return nil
        }
        let key = String(asset.localIdentifier)
        return imageCache[key]
    }
    #endif
    
    // 预加载照片
    func preloadPhotos(_ assets: [PHAsset], targetSize: CGSize = CGSize(width: 1800, height: 1800)) {
        cacheQueue.async {
            // 开始缓存图片
            self.imageManager.startCachingImages(
                for: assets,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: self.getHighQualityOptions()
            )
            
            // 同时加载到内存缓存
            for asset in assets {
                self.loadToMemoryCache(asset: asset, targetSize: targetSize)
            }
        }
    }
    
    // 停止缓存指定照片
    func stopCaching(_ assets: [PHAsset], targetSize: CGSize = CGSize(width: 1800, height: 1800)) {
        imageManager.stopCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: getHighQualityOptions()
        )
        
        // 从内存缓存中移除 - 增加安全检查
        for asset in assets {
            guard !asset.localIdentifier.isEmpty else {
                print("⚠️ Asset localIdentifier is empty in stopCaching")
                continue
            }
            let key = String(asset.localIdentifier)
            imageCache.removeValue(forKey: key)
        }
    }
    
    // 清理所有缓存
    func clearAllCache() {
        imageManager.stopCachingImagesForAllAssets()
        imageCache.removeAll()
    }
    
    // 加载单张照片 - 增加安全检查
    #if os(iOS)
    func loadImage(for asset: PHAsset, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        // 安全检查
        guard !asset.localIdentifier.isEmpty else {
            print("⚠️ Asset localIdentifier is empty in loadImage")
            completion(nil)
            return
        }
        
        // 先检查内存缓存
        if let cachedImage = getCachedImage(for: asset) {
            completion(cachedImage)
            return
        }
        
        // 从PHImageManager加载
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: getHighQualityOptions()
        ) { [weak self] result, _ in
            if let result = result {
                // 保存到内存缓存
                let key = String(asset.localIdentifier)
                self?.imageCache[key] = result
                DispatchQueue.main.async {
                    completion(result)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    #else
    func loadImage(for asset: PHAsset, targetSize: CGSize, completion: @escaping (NSImage?) -> Void) {
        // 安全检查
        guard !asset.localIdentifier.isEmpty else {
            print("⚠️ Asset localIdentifier is empty in loadImage")
            completion(nil)
            return
        }
        
        // 先检查内存缓存
        if let cachedImage = getCachedImage(for: asset) {
            completion(cachedImage)
            return
        }
        
        // 从PHImageManager加载
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: getHighQualityOptions()
        ) { [weak self] result, _ in
            if let result = result {
                // 保存到内存缓存
                let key = String(asset.localIdentifier)
                self?.imageCache[key] = result
                DispatchQueue.main.async {
                    completion(result)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    #endif
    
    private func loadToMemoryCache(asset: PHAsset, targetSize: CGSize) {
        // 安全检查和缓存检查
        guard !asset.localIdentifier.isEmpty else {
            print("⚠️ Asset localIdentifier is empty in loadToMemoryCache")
            return
        }
        let key = String(asset.localIdentifier)
        guard imageCache[key] == nil else { return }
        
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: getHighQualityOptions()
        ) { [weak self] result, _ in
            if let result = result {
                self?.imageCache[key] = result
            }
        }
    }
    
    private func getHighQualityOptions() -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        return options
    }
} 