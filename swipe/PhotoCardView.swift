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
    
    // 添加长按动画状态
    @State private var longPressAnimationTrigger = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 底层卡片 - 固定位置，根据滑动方向显示内容
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        // 根据滑动方向和长按状态决定颜色
                        LinearGradient(
                            colors: getBottomCardColors(),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .animation(.easeInOut(duration: 0.4), value: isLongPressing)
                    .animation(.easeInOut(duration: 0.2), value: abs(offset.width))
                    .frame(
                        width: getImageDisplayWidth(geometry: geometry) + 20,
                        height: getImageDisplayHeight(geometry: geometry) + 20
                    )
                    .overlay(
                        // 底层卡片内容
                        getBottomCardContent()
                    )
                    .opacity(shouldShowBottomCard() ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.3), value: isLongPressing)
                    .animation(.easeInOut(duration: 0.2), value: offset)
                
                // 上层照片卡片 - 跟随手势移动
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
                            .shadow(color: .black.opacity(0.15), radius: 25, x: 0, y: 10)
                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
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
                            .overlay(
                                // 长按动画覆盖层 - 在照片最上方
                                ZStack {
                                    if isLongPressing {
                                        // 半透明蓝色覆盖层
                                        Rectangle()
                                            .fill(Color.blue.opacity(0.3))
                                            .clipShape(RoundedRectangle(cornerRadius: 20))
                                            .overlay(
                                                // 长按动画内容
                                                getLongPressOverlayContent()
                                            )
                                            .transition(.opacity)
                                            .animation(.easeInOut(duration: 0.3), value: isLongPressing)
                                    }
                                    
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
                                        }
                                        .padding(.top, 12)
                                        .padding(.trailing, 12)
                                        Spacer()
                                    }
                                }
                            )
                    } else {
                        // 載入狀態
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
                            .frame(
                                width: min(geometry.size.width - 10, 500),
                                height: min(geometry.size.height - 50, geometry.size.height * 0.85)
                            )
                        
                        // 加載指示器
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.blue)
                            
                            Text("載入中...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .offset(offset) // 只有上层卡片跟随手势移动
                .rotationEffect(.degrees(rotation))
                .scaleEffect(isAnimatingOut ? 0.6 : 1.0)
                .opacity(isAnimatingOut ? 0.0 : 1.0)
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .gesture(
            DragGesture(minimumDistance: 0) // 设为0，这样可以捕获所有触摸
                .onChanged { value in
                    if isAnimatingOut { return }
                    
                    let dragDistance = sqrt(value.translation.width * value.translation.width + value.translation.height * value.translation.height)
                    
                    // 如果是第一次触摸
                    if pressStartTime == nil {
                        pressStartTime = Date()
                        
                        // 启动长按计时器
                        longPressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
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
                        print("🛑 手势结束：检测到长按结束，停止动画")
                        longPressAnimationTrigger = false
                        print("🛑 手势结束时停止动画: longPressAnimationTrigger = \(longPressAnimationTrigger)")
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
                        // 回到原位 - 确保底层卡片也消失
                        withAnimation(.easeOut(duration: 0.2)) {
                            offset = .zero
                            rotation = 0
                        }
                        
                        // 重置触觉反馈状态
                        hasTriggeredHaptic = false
                    }
                }
        )
        .onChange(of: isLongPressing) { oldValue, newValue in
            print("🔄 长按状态变化: \(oldValue) -> \(newValue)")
            
            // 立即同步动画状态，确保在PhotoCardView重新创建时也能正确显示
            DispatchQueue.main.async {
                if newValue {
                    // 开始长按 - 立即启动动画
                    self.longPressAnimationTrigger = true
                    print("🎬 启动长按动画，longPressAnimationTrigger = \(self.longPressAnimationTrigger)")
                } else {
                    // 结束长按 - 停止动画
                    self.longPressAnimationTrigger = false
                    print("⏹️ 停止长按动画，longPressAnimationTrigger = \(self.longPressAnimationTrigger)")
                }
            }
        }
        .onAppear {
            loadImage()
            checkFavoriteStatus()
            
            // 🔥 重要：当PhotoCardView重新创建时，根据外部状态恢复动画
            if isLongPressing && !longPressAnimationTrigger {
                longPressAnimationTrigger = true
                print("🔄 PhotoCardView重新创建：恢复长按动画状态")
            }
        }
    }
    
    // 優化的照片尺寸計算 - 智能缩放策略，让竖向照片贴边
    private func getOptimalImageSize(geometry: GeometryProxy) -> CGSize {
        // 根据照片方向优化边距设置
        let baseMargin: CGFloat = 7
        let topBottomMargin: CGFloat = 25 // 为按钮和UI元素留出空间
        
        let availableWidth = geometry.size.width - (baseMargin * 2)
        let availableHeight = geometry.size.height - topBottomMargin
        
        guard imageSize.width > 0 && imageSize.height > 0 else {
            return CGSize(width: availableWidth, height: min(availableHeight, 600))
        }
        
        let imageAspectRatio = imageSize.width / imageSize.height
        let availableAspectRatio = availableWidth / availableHeight
        
        var finalWidth: CGFloat
        var finalHeight: CGFloat
        
        // 判断照片类型和优化策略
        if imageAspectRatio > 1.2 {
            // 横向照片 (宽高比 > 1.2) - 按宽度优先
            finalWidth = availableWidth
            finalHeight = finalWidth / imageAspectRatio
            
            // 确保高度不超限
            if finalHeight > availableHeight {
                finalHeight = availableHeight
                finalWidth = finalHeight * imageAspectRatio
            }
        } else if imageAspectRatio < 0.8 {
            // 竖向照片 (宽高比 < 0.8) - 让照片尽可能贴边
            // 先尝试填满高度
            finalHeight = availableHeight
            finalWidth = finalHeight * imageAspectRatio
            
            // 如果宽度超出，则按宽度调整
            if finalWidth > availableWidth {
                finalWidth = availableWidth
                finalHeight = finalWidth / imageAspectRatio
            } else {
                // 竖向照片特殊优化：如果空间充足，增加一些尺寸让它更贴边
                let widthUtilization = finalWidth / availableWidth
                if widthUtilization < 0.85 {
                    // 如果宽度利用率低于85%，适当增大
                    let scaleUp = min(1.15, 0.95 / widthUtilization)
                    finalWidth = min(finalWidth * scaleUp, availableWidth)
                    finalHeight = finalWidth / imageAspectRatio
                }
            }
        } else {
            // 方形或接近方形照片 - 平衡策略
            if imageAspectRatio > availableAspectRatio {
                finalWidth = availableWidth
                finalHeight = finalWidth / imageAspectRatio
            } else {
                finalHeight = availableHeight
                finalWidth = finalHeight * imageAspectRatio
            }
        }
        
        // 最终安全检查
        finalWidth = min(finalWidth, availableWidth)
        finalHeight = min(finalHeight, availableHeight)
        
        let photoType = imageAspectRatio > 1.2 ? "横向" : imageAspectRatio < 0.8 ? "竖向" : "方形"
        print("📐 \(photoType)照片缩放: 原始(\(Int(imageSize.width))x\(Int(imageSize.height))) -> 显示(\(Int(finalWidth))x\(Int(finalHeight)))")
        
        return CGSize(width: finalWidth, height: finalHeight)
    }
    
    // 根據照片比例計算顯示寬度
    private func getImageDisplayWidth(geometry: GeometryProxy) -> CGFloat {
        return getOptimalImageSize(geometry: geometry).width
    }
    
    // 根據照片比例計算顯示高度
    private func getImageDisplayHeight(geometry: GeometryProxy) -> CGFloat {
        return getOptimalImageSize(geometry: geometry).height
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
        print("🔄 重置卡片状态，停止所有动画")
        
        // 立即重置所有状态，避免底层卡片残留
        withAnimation(.easeOut(duration: 0.1)) {
            offset = .zero
            rotation = 0
        }
        
        isAnimatingOut = false
        fadeDirection = 0
        hasTriggeredHaptic = false // 重置觸覺反饋狀態
        
        // 停止长按动画
        longPressAnimationTrigger = false
        print("🛑 resetCard中停止动画: longPressAnimationTrigger = \(longPressAnimationTrigger)")
        
        // 清理手势状态
        cleanupGestureState()
        
        // 如果正在长按，通知外部停止
        if isLongPressing {
            print("🛑 resetCard中结束长按")
            onLongPressEnd()
        }
        
        // 延迟一帧确保所有状态都已重置
        DispatchQueue.main.async {
            // 这里可以做额外的清理工作
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
        print("🔥 长按触发: isLongPressing=\(isLongPressing), 开始启动动画")
        
        // 触觉反馈
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        #endif
        
        // 立即设置动画触发器，不依赖onChange
        longPressAnimationTrigger = true
        print("🎬 直接设置动画触发器: longPressAnimationTrigger = \(longPressAnimationTrigger)")
        
        // 触发长按回调
        onLongPressStart()
        
        print("🎬 长按回调已执行，动画应该已经开始")
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
    
    // 根据滑动方向和长按状态决定底层卡片的背景颜色
    private func getBottomCardColors() -> [Color] {
        // 调试：打印所有相关状态
        print("🎨 颜色判断状态: isLongPressing=\(isLongPressing), offset.width=\(offset.width)")
        
        if isLongPressing {
            print("🎨 ✅ 底层卡片使用长按颜色 (蓝色)")
            return [Color.blue.opacity(0.9), Color.blue.opacity(0.7)]
        } else if offset.width < -20 {
            // 往左滑 - 删除
            print("🎨 ✅ 底层卡片使用删除颜色 (红色)")
            return [Color.red.opacity(0.9), Color.red.opacity(0.7)]
        } else if offset.width > 20 {
            // 往右滑 - 保留
            print("🎨 ✅ 底层卡片使用保留颜色 (绿色)")
            return [Color.green.opacity(0.9), Color.green.opacity(0.7)]
        } else {
            // 默认状态 - 中性颜色
            print("🎨 ✅ 底层卡片使用默认颜色 (灰色)")
            return [Color.gray.opacity(0.6), Color.gray.opacity(0.4)]
        }
    }
    
    // 根据滑动方向和长按状态决定底层卡片的提示内容
    @ViewBuilder
    private func getBottomCardContent() -> some View {
        // 调试信息
        let _ = print("🎬 getBottomCardContent被调用: isLongPressing=\(isLongPressing), longPressAnimationTrigger=\(longPressAnimationTrigger), offset.width=\(offset.width)")
        
        if isLongPressing {
            // 长按连续保留状态 - 增强动画效果
            VStack(spacing: 12) {
                // 主图标 - 更大更明显的动画
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(longPressAnimationTrigger ? 1.5 : 1.0)
                    .rotationEffect(.degrees(longPressAnimationTrigger ? 15 : -15))
                    .shadow(color: .white.opacity(0.8), radius: longPressAnimationTrigger ? 10 : 5)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: longPressAnimationTrigger)
                
                // 脉冲效果圆圈
                Circle()
                    .fill(Color.white.opacity(longPressAnimationTrigger ? 0.2 : 0.6))
                    .frame(width: longPressAnimationTrigger ? 100 : 60, height: longPressAnimationTrigger ? 100 : 60)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: longPressAnimationTrigger)
                    .overlay(
                        // 内部图标
                        Image(systemName: "heart.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(longPressAnimationTrigger ? 1.3 : 0.8)
                            .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: longPressAnimationTrigger)
                    )
                
                // 文本 - 更明显的动画
                Text("連續保留中...")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                    .opacity(longPressAnimationTrigger ? 0.6 : 1.0)
                    .offset(y: longPressAnimationTrigger ? -3 : 3)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: longPressAnimationTrigger)
                
                // 计数器 - 增加背景和更大动画
                Text("(\(continuousSaveCount))")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(longPressAnimationTrigger ? 0.3 : 0.1))
                            .scaleEffect(longPressAnimationTrigger ? 1.1 : 0.9)
                    )
                    .scaleEffect(longPressAnimationTrigger ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: longPressAnimationTrigger)
            }
        } else if offset.width < -20 {
            // 往左滑 - 删除
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("刪除")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.trailing, 40)
            }
        } else {
            // 往右滑 - 保留
            HStack {
                VStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("保留")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.leading, 40)
                Spacer()
            }
        }
    }
    
    // 判断底层卡片是否应该显示
    private func shouldShowBottomCard() -> Bool {
        let shouldShow = abs(offset.width) > 20 // 移除长按条件，因为长按动画现在在上层
        if shouldShow {
            print("📱 底层卡片应该显示: offset.width=\(offset.width), isLongPressing=\(isLongPressing), longPressAnimationTrigger=\(longPressAnimationTrigger)")
        }
        return shouldShow
    }
    
    // 长按覆盖层内容 - 显示在照片上方
    @ViewBuilder
    private func getLongPressOverlayContent() -> some View {
        // 调试信息
        let _ = print("🎬 显示长按覆盖层内容: longPressAnimationTrigger=\(longPressAnimationTrigger), continuousSaveCount=\(continuousSaveCount)")
        
        VStack(spacing: 20) {
            Spacer()
            
            // 长按动画内容 - 居中显示
            VStack(spacing: 16) {
                // 主图标 - 更大更明显的动画
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(longPressAnimationTrigger ? 1.8 : 1.2)
                    .rotationEffect(.degrees(longPressAnimationTrigger ? 20 : -20))
                    .shadow(color: .white.opacity(0.9), radius: longPressAnimationTrigger ? 15 : 8)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: longPressAnimationTrigger)
                
        
                // 文本 - 更明显的动画
                Text("連續保留中...")
                    .font(.title)
                    .fontWeight(.black)
                    .foregroundColor(.white)
                    .opacity(longPressAnimationTrigger ? 0.7 : 1.0)
                    .offset(y: longPressAnimationTrigger ? -5 : 5)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: longPressAnimationTrigger)
                
                // 计数器 - 使用 JetBrains Mono 字体（带回退机制）
                Text("(\(continuousSaveCount))")
                    .font(.custom("JetBrains Mono", size:25))
                    .fontWeight(.black)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.black.opacity(longPressAnimationTrigger ? 0.5 : 0.3))
                            .scaleEffect(longPressAnimationTrigger ? 1.2 : 1.0)
                    )
                    .scaleEffect(longPressAnimationTrigger ? 1.4 : 1.0)
                    .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: longPressAnimationTrigger)
            }
            
            Spacer()
        }
    }
}

// SwipeIndicator组件已被底层卡片替代，移除此组件
// struct SwipeIndicator: View {
//     let text: String
//     let color: Color
//     
//     var body: some View {
//         Text(text)
//             .font(.title2)
//             .fontWeight(.bold)
//             .foregroundColor(color)
//             .padding(.horizontal, 20)
//             .padding(.vertical, 12)
//             .background(Color.white.opacity(0.95))
//             .clipShape(RoundedRectangle(cornerRadius: 15))
//             .shadow(color: color.opacity(0.3), radius: 5, x: 0, y: 2)
//     }
// } 
