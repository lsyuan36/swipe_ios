//
//  PhotoCardView.swift
//  swipe
//
//  Created by 賴聖元 on 2025/7/8.
//

import SwiftUI
import Photos
import Foundation

#if os(iOS)
import UIKit
#endif

// 滑动方向枚举
enum SwipeDirection {
    case left, right
}

// Note: PhotoItem and PhotoCacheManager are defined in other files in the same target

// 照片卡片視圖 - 增大尺寸並支援完整顯示和预加载
struct PhotoCardView: View {
    let photoItem: PhotoItem
    let cacheManager: PhotoCacheManager
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void
    
    // 长按状态从外部管理
    @Binding var isLongPressing: Bool
    @Binding var continuousSaveCount: Int
    let onLongPressStart: () -> Void
    let onLongPressEnd: () -> Void
    
    @State private var offset = CGSize.zero
    @State private var rotation: Double = 0
    @State private var image: Image? = nil
    @State private var imageSize: CGSize = .zero
    @State private var isAnimatingOut = false
    @State private var fadeDirection: CGFloat = 0 // -1 = left, 1 = right
    @State private var hasTriggeredHaptic = false // 追蹤是否已觸發觸覺反饋
    @State private var isFavorite = false // 追蹤照片在iOS Photos中的喜好狀態
    @State private var isTogglingFavorite = false // 追蹤是否正在切換喜好狀態
    @State private var longPressTimer: Timer? // 长按计时器
    @State private var pressStartTime: Date? // 按下开始时间
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = image {
                    // 美化的背景卡片
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0.98)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.8), Color.gray.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
                        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                        .frame(
                            width: getImageDisplayWidth(geometry: geometry) + 20,
                            height: getImageDisplayHeight(geometry: geometry) + 20
                        )
                    
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: getImageDisplayWidth(geometry: geometry),
                            height: getImageDisplayHeight(geometry: geometry)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .scaleEffect(1.0)
                        .overlay(
                            // 喜好按钮 - 放在右上角
                            VStack {
                                HStack {
                                    Spacer()
                                    Button(action: toggleFavoriteStatus) {
                                        ZStack {
                                            // 背景圓形
                                            Circle()
                                                .fill(Color.black.opacity(0.3))
                                                .frame(width: 44, height: 44)
                                            
                                            // 心形圖標
                                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                                .font(.title2)
                                                .foregroundColor(isFavorite ? .red : .white)
                                                .scaleEffect(isTogglingFavorite ? 1.2 : 1.0)
                                        }
                                    }
                                    .disabled(isTogglingFavorite)
                                    .animation(.easeInOut(duration: 0.2), value: isFavorite)
                                    .animation(.easeInOut(duration: 0.1), value: isTogglingFavorite)
                                }
                                .padding(.top, 12)
                                .padding(.trailing, 12)
                                Spacer()
                            }
                        )
                } else {
                    // 美化的載入狀態背景卡片
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0.98)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.8), Color.gray.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
                        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                        .frame(
                            width: min(geometry.size.width - 10, 500),
                            height: min(geometry.size.height - 50, geometry.size.height * 0.85)
                        )
                    
                    // 美化的加載指示器
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.blue)
                        
                        Text("載入中...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 增強的滑動指示器 - 明確顯示滑動方向
                VStack {
                    HStack {
                        // 左側刪除指示器 - 極簡化顯示
                        if offset.width < -50 || (isAnimatingOut && fadeDirection < 0) {
                            SwipeIndicator(text: "← 刪除", color: .red)
                                .scaleEffect(isAnimatingOut && fadeDirection < 0 ? 1.2 : 1.0)
                                .opacity(isAnimatingOut && fadeDirection < 0 ? 1.0 : 0.8)
                        }
                        
                        Spacer()
                        
                        // 右側保留指示器 - 極簡化顯示
                        if offset.width > 50 || (isAnimatingOut && fadeDirection > 0) || isLongPressing {
                            if isLongPressing {
                                SwipeIndicator(
                                    text: "連續保留中... (\(continuousSaveCount))", 
                                    color: .blue
                                )
                                .scaleEffect(1.1)
                                .opacity(1.0)
                            } else {
                                SwipeIndicator(text: "保留 →", color: .green)
                                    .scaleEffect(isAnimatingOut && fadeDirection > 0 ? 1.2 : 1.0)
                                    .opacity(isAnimatingOut && fadeDirection > 0 ? 1.0 : 0.8)
                            }
                        }
                    }
                    .padding(.top, 30)
                    
                    Spacer()
                }
                .frame(
                    width: image != nil ? getImageDisplayWidth(geometry: geometry) + 20 : min(geometry.size.width - 10, 500),
                    height: image != nil ? getImageDisplayHeight(geometry: geometry) + 20 : min(geometry.size.height , geometry.size.height * 1.5)
                )
                .opacity(isAnimatingOut ? 0.0 : 1.0)
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .offset(offset)
        .rotationEffect(.degrees(rotation))
        .scaleEffect(isAnimatingOut ? 0.6 : 1.0)
        .opacity(isAnimatingOut ? 0.0 : 1.0)
        .gesture(
            DragGesture(minimumDistance: 0) // 设为0，这样可以捕获所有触摸
                .onChanged { value in
                    if isAnimatingOut { return }
                    
                    let dragDistance = sqrt(value.translation.width * value.translation.width + value.translation.height * value.translation.height)
                    
                    // 如果是第一次触摸
                    if pressStartTime == nil {
                        pressStartTime = Date()
                        
                        // 启动长按计时器
                        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { _ in
                            // 长按触发：距离不能太大
                            if dragDistance < 30 && !self.isLongPressing && !self.isAnimatingOut {
                                self.triggerLongPress()
                            }
                        }
                    }
                    
                    // 如果移动距离太大，取消长按
                    if dragDistance > 30 {
                        cancelLongPress()
                    }
                    
                    // 正常拖拽处理（只有在非长按状态下）
                    if !isLongPressing && dragDistance > 10 {
                        offset = value.translation
                        rotation = Double(value.translation.width / 12.0)
                        
                        // 觸覺反饋
                        #if os(iOS)
                        let threshold: CGFloat = 80
                        if !hasTriggeredHaptic && abs(value.translation.width) > threshold {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            hasTriggeredHaptic = true
                        }
                        #endif
                    }
                }
                .onEnded { value in
                    if isAnimatingOut { return }
                    
                    // 清理长按相关状态
                    let wasLongPressing = isLongPressing
                    cleanupGestureState()
                    
                    // 如果是长按结束
                    if wasLongPressing {
                        onLongPressEnd()
                        return
                    }
                    
                    // 正常滑动处理
                    let swipeThreshold: CGFloat = 80
                    
                    if value.translation.width > swipeThreshold {
                        // 向右滑動 - 保留
                        performSwipeAnimation(direction: .right)
                    } else if value.translation.width < -swipeThreshold {
                        // 向左滑動 - 刪除
                        performSwipeAnimation(direction: .left)
                    } else {
                        // 回到原位
                        withAnimation(.easeOut(duration: 0.2)) {
                            offset = .zero
                            rotation = 0
                        }
                    }
                }
        )
        .onAppear {
            loadImage()
            checkFavoriteStatus()
        }
    }
    
    // 根據照片比例計算顯示寬度 - 極大化垂直照片顯示
    private func getImageDisplayWidth(geometry: GeometryProxy) -> CGFloat {
        let maxWidth = min(geometry.size.width - 10, 500) // 極大寬度，幾乎滿屏
        let maxHeight = min(geometry.size.height - 50, geometry.size.height * 0.85) // 極大高度，幾乎滿屏
        
        guard imageSize.width > 0 && imageSize.height > 0 else {
            return maxWidth
        }
        
        let imageAspectRatio = imageSize.width / imageSize.height
        
        // 如果是橫向照片 (寬度 > 高度)
        if imageAspectRatio > 1.0 {
            // 按照螢幕寬度縮放
            return maxWidth
        } else {
            // 垂直照片：極大化利用高度空間，讓照片盡可能接近滿屏
            let widthForHeight = maxHeight * imageAspectRatio
            return min(widthForHeight, maxWidth)
        }
    }
    
    // 根據照片比例計算顯示高度 - 極大化垂直照片顯示
    private func getImageDisplayHeight(geometry: GeometryProxy) -> CGFloat {
        let maxWidth = min(geometry.size.width - 10, 500) // 極大寬度
        let maxHeight = min(geometry.size.height - 50, geometry.size.height * 0.95) // 極大高度，85%屏幕高度
        
        guard imageSize.width > 0 && imageSize.height > 0 else {
            return min(maxHeight, 600)
        }
        
        let imageAspectRatio = imageSize.width / imageSize.height
        
        // 如果是橫向照片 (寬度 > 高度)
        if imageAspectRatio > 1.0 {
            // 按照螢幕寬度縮放
            let heightForWidth = maxWidth / imageAspectRatio
            return min(heightForWidth, maxHeight)
        } else {
            // 垂直照片：極大化利用垂直空間，接近滿屏顯示
            return maxHeight
        }
    }
    
    private func loadImage() {
        image = nil // 先清除舊圖片
        
        // 使用缓存管理器加载图片，大大提高加载速度
        let targetSize = CGSize(width: 1800, height: 1800)
        
        #if os(iOS)
        cacheManager.loadImage(for: photoItem.asset, targetSize: targetSize) { result in
            if let result = result {
                self.image = Image(uiImage: result)
                self.imageSize = result.size
                print("🚀 快速加载图片: \(String(photoItem.asset.localIdentifier).prefix(8))")
            }
        }
        #else
        cacheManager.loadImage(for: photoItem.asset, targetSize: targetSize) { result in
            if let result = result {
                self.image = Image(nsImage: result)
                self.imageSize = result.size
                print("🚀 快速加载图片: \(String(photoItem.asset.localIdentifier).prefix(8))")
            }
        }
        #endif
    }
    
    private func resetCard() {
        offset = .zero
        rotation = 0
        isAnimatingOut = false
        fadeDirection = 0
        hasTriggeredHaptic = false // 重置觸覺反饋狀態
        
        // 清理手势状态
        cleanupGestureState()
        
        // 如果正在长按，通知外部停止
        if isLongPressing {
            onLongPressEnd()
        }
    }
    
    // 檢查照片在iOS Photos中的喜好狀態
    private func checkFavoriteStatus() {
        isFavorite = photoItem.asset.isFavorite
    }
    
    // 切換照片在iOS Photos中的喜好狀態
    private func toggleFavoriteStatus() {
        guard !isTogglingFavorite else { return }
        
        isTogglingFavorite = true
        
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    self.isTogglingFavorite = false
                    return
                }
                
                PHPhotoLibrary.shared().performChanges({
                    let request = PHAssetChangeRequest(for: self.photoItem.asset)
                    request.isFavorite = !self.isFavorite
                }) { success, error in
                    DispatchQueue.main.async {
                        self.isTogglingFavorite = false
                        if success {
                            self.isFavorite.toggle()
                            
                            // 觸覺反饋
                            #if os(iOS)
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            #endif
                        } else if let error = error {
                            print("切換喜好狀態失敗: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    private func triggerLongPress() {
        // 触发长按
        onLongPressStart()
        
        // 触觉反馈
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        #endif
    }
    
    private func cancelLongPress() {
        // 取消长按计时器
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
    
    private func cleanupGestureState() {
        // 清理手势状态
        longPressTimer?.invalidate()
        longPressTimer = nil
        pressStartTime = nil
        hasTriggeredHaptic = false
    }
    
    private func performSwipeAnimation(direction: SwipeDirection) {
        // 执行滑动动画
        isAnimatingOut = true
        
        switch direction {
        case .right:
            fadeDirection = 1
            withAnimation(.easeOut(duration: 0.25)) {
                offset = CGSize(width: 800, height: 0)
                rotation = 25
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                onSwipeRight()
                resetCard()
            }
        case .left:
            fadeDirection = -1
            withAnimation(.easeOut(duration: 0.25)) {
                offset = CGSize(width: -800, height: 0)
                rotation = -25
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                onSwipeLeft()
                resetCard()
            }
        }
    }
}

// 滑動指示器組件
struct SwipeIndicator: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(color)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: color.opacity(0.3), radius: 5, x: 0, y: 2)
    }
} 
