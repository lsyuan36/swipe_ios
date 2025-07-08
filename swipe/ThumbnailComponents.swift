//
//  ThumbnailComponents.swift
//  swipe
//
//  Created by 賴聖元 on 2025/7/8.
//

import SwiftUI
import Photos

// 現代化篩選按鈕
struct ModernFilterButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : color)
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color : Color.white)
                    .shadow(
                        color: isSelected ? color.opacity(0.3) : .black.opacity(0.08),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : Color.gray.opacity(0.2), lineWidth: isSelected ? 0 : 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 現代化照片縮圖視圖
struct ModernPhotoThumbnailView: View {
    let photoItem: PhotoItem
    @State private var image: Image? = nil
    
    var body: some View {
        ZStack {
            if let image = image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            }
            
            // 現代化狀態指示器
            VStack {
                HStack {
                    Spacer()
                    if photoItem.status == .kept {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .padding(8)
                    } else if photoItem.status == .deleted {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: "trash.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.red)
                        }
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .padding(8)
                    }
                }
                Spacer()
            }
            
            // 選擇覆蓋層
            RoundedRectangle(cornerRadius: 12)
                .stroke(photoItem.status == .kept ? Color.green : (photoItem.status == .deleted ? Color.red : Color.clear), lineWidth: 3)
        }
        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let targetSize = CGSize(width: 120, height: 120)
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        
        PHCachingImageManager.default().requestImage(
            for: photoItem.asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            if let result = result {
                DispatchQueue.main.async {
                    #if os(iOS)
                    self.image = Image(uiImage: result)
                    #elseif os(macOS)
                    self.image = Image(nsImage: result)
                    #endif
                }
            }
        }
    }
}

// 篩選按鈕
struct FilterButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("\(count)")
                    .font(.caption2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.2) : Color.clear)
            .foregroundColor(isSelected ? color : .secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? color : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 照片縮圖視圖
struct PhotoThumbnailView: View {
    let photoItem: PhotoItem
    @State private var image: Image? = nil
    
    var body: some View {
        ZStack {
            if let image = image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 90, height: 90)
                    .clipShape(Rectangle())
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 90, height: 90)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.7)
                    )
            }
            
            // 狀態指示器
            VStack {
                HStack {
                    Spacer()
                    if photoItem.status == .kept {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                            .padding(2)
                    } else if photoItem.status == .deleted {
                        Image(systemName: "trash.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                            .padding(2)
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let targetSize = CGSize(width: 90, height: 90)
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        
        PHCachingImageManager.default().requestImage(
            for: photoItem.asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            if let result = result {
                DispatchQueue.main.async {
                    #if os(iOS)
                    self.image = Image(uiImage: result)
                    #elseif os(macOS)
                    self.image = Image(nsImage: result)
                    #endif
                }
            }
        }
    }
}

// 垃圾桶照片縮圖視圖（帶恢復功能）
struct TrashPhotoThumbnailView: View {
    let photoItem: PhotoItem
    let onRestore: () -> Void
    @State private var image: Image? = nil
    
    var body: some View {
        ZStack {
            if let image = image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 90, height: 90)
                    .clipShape(Rectangle())
                    .overlay(
                        // 半透明遮罩表示已刪除狀態
                        Rectangle()
                            .fill(Color.black.opacity(0.3))
                    )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 90, height: 90)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.7)
                    )
            }
            
            // 恢復按鈕
            Button(action: onRestore) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .background(Color.blue.opacity(0.8))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let targetSize = CGSize(width: 90, height: 90)
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        
        PHCachingImageManager.default().requestImage(
            for: photoItem.asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            if let result = result {
                DispatchQueue.main.async {
                    #if os(iOS)
                    self.image = Image(uiImage: result)
                    #elseif os(macOS)
                    self.image = Image(nsImage: result)
                    #endif
                }
            }
        }
    }
} 