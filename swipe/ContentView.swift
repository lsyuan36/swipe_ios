//
//  ContentView.swift
//  swipe
//
//  Created by 賴聖元 on 2025/7/8.
//

import SwiftUI
import Photos

#if os(iOS)
import UIKit
#endif

struct ContentView: View {
    @State private var allPhotos: [PhotoItem] = []
    @State private var currentPhotoIndex = 0
    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @State private var isLoading = true
    @State private var showingOverview = false // 控制總覽畫面顯示
    @State private var showingBrowser = false // 控制照片瀏覽器顯示
    @State private var showingTrashBin = false // 控制垃圾桶畫面顯示
    @State private var showingSettings = false // 控制設置畫面顯示
    @State private var cardKey = UUID() // 強制更新卡片的key
    
    @StateObject private var cacheManager = PhotoCacheManager.shared
    @StateObject private var dataManager = PhotoDataManager.shared
    private let preloadRange = 10 // 预加载前后5张照片
    
    // 长按连续保存状态
    @State private var isLongPressing = false
    @State private var continuousSaveTimer: Timer?
    @State private var continuousSaveCount = 0
    
    // 重置相关状态
    @State private var isResetting = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 美化的多層背景設計
                ZStack {
                    // 主背景漸變
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.95, green: 0.97, blue: 1.0),
                            Color(red: 0.92, green: 0.95, blue: 1.0),
                            Color(red: 0.88, green: 0.93, blue: 0.98)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // 動態光暈效果
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.08),
                            Color.clear
                        ]),
                        center: .topTrailing,
                        startRadius: 100,
                        endRadius: 400
                    )
                    
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.purple.opacity(0.06),
                            Color.clear
                        ]),
                        center: .bottomLeading,
                        startRadius: 150,
                        endRadius: 500
                    )
                }
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 美化的頂部導航欄
                    VStack(spacing: 16) {
                        HStack {
                            // 品牌標題區域
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Swipe")
                                    .font(.jetBrainsMonoBold(32))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.blue, Color.purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                Text("照片整理助手")
                                    .font(.jetBrainsMono(12))
                                    .foregroundColor(.secondary)
                                    .opacity(0.8)
                            }
                            
                            Spacer()
                            
                            // 現代化按鈕組
                            HStack(spacing: 12) {
                                // 設置按鈕 - 讓用戶訪問設置和重置功能
                                ModernNavButton(
                                    icon: "gearshape.fill",
                                    color: .gray,
                                    badgeCount: 0,
                                    isActive: showingSettings,
                                    action: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            showingSettings = true
                                        }
                                    }
                                )
                                
                                // 垃圾桶按鈕 - 重新設計
                                ModernNavButton(
                                    icon: "trash",
                                    color: .red,
                                    badgeCount: deletedPhotosCount,
                                    isActive: showingTrashBin,
                                    action: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            showingTrashBin = true
                                        }
                                    }
                                )
                                
                                // 照片瀏覽器按鈕 - 重新設計  
                                ModernNavButton(
                                    icon: "photo.stack",
                                    color: .blue,
                                    badgeCount: 0,
                                    isActive: showingBrowser,
                                    action: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            showingBrowser = true
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        
                        // 分隔線效果
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.clear, Color.gray.opacity(0.2), Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 1)
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 20)
                    
                    // 美化的統計面板
                    if !allPhotos.isEmpty {
                        VStack(spacing: 12) {
                            // 進度指示器 - 只顯示未處理的照片數量
                            VStack(spacing: 8) {
                                HStack {
                                    Text("整理進度")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("還剩 \(unprocessedPhotosCount) 張")
                                        .font(.jetBrainsMonoMedium(15))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                                
                                // 進度條 - 基於已處理照片的比例
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 6)
                                            .cornerRadius(3)
                                        
                                        Rectangle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.blue, Color.purple],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(
                                                width: geometry.size.width * min(1.0, Double(processedPhotosCount) / Double(allPhotos.count)),
                                                height: 6
                                            )
                                            .cornerRadius(3)
                                            .animation(.easeInOut(duration: 0.3), value: processedPhotosCount)
                                    }
                                }
                                .frame(height: 6)
                            }
                        }
                        .padding(.all, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                    
                    // 主要內容區域
                    if authorizationStatus == .denied || authorizationStatus == .restricted {
                        // 美化的權限狀態
                        VStack(spacing: 24) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.orange.opacity(0.2), Color.orange.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 60))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.orange, Color.orange.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            
                            VStack(spacing: 8) {
                                Text("需要照片權限")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("請到設定中允許此App訪問您的照片")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                            
                            Button("開啟設定") {
                                // 用戶需要手動到設定中開啟權限
                                print("請到設定 > 隱私權與安全性 > 照片 中開啟權限")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                        .padding(.all, 32)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.05), radius: 15, x: 0, y: 8)
                        )
                        .padding(.horizontal, 24)
                        
                    } else if isLoading {
                        // 美化的載入狀態
                        VStack(spacing: 24) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                
                                ProgressView()
                                    .scaleEffect(1.8)
                                    .tint(.blue)
                            }
                            
                            VStack(spacing: 8) {
                                Text("載入照片中...")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("正在準備您的照片")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.all, 32)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.05), radius: 15, x: 0, y: 8)
                        )
                        .padding(.horizontal, 24)
                        
                    } else if allPhotos.isEmpty {
                        // 美化的空狀態
                        VStack(spacing: 24) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 60))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.gray, Color.gray.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            
                            VStack(spacing: 8) {
                                Text("沒有照片")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("您的相簿中沒有照片")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.all, 32)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.05), radius: 15, x: 0, y: 8)
                        )
                        .padding(.horizontal, 24)
                        
                    } else if currentPhotoIndex >= allPhotos.count {
                        // 美化的完成狀態
                        VStack(spacing: 24) {
                            // 成功圖標與動畫
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.green.opacity(0.2), Color.green.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.green, Color.green.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .scaleEffect(1.0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentPhotoIndex)
                            }
                            
                            VStack(spacing: 8) {
                                Text("整理完成！")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("您已經處理完所有照片")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            // 美化的按鈕組
                            VStack(spacing: 12) {
                                HStack(spacing: 15) {
                                    Button("查看總覽") {
                                        withAnimation(.spring()) {
                                            showingOverview = true
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.blue)
                                    
                                    Button("瀏覽照片") {
                                        withAnimation(.spring()) {
                                            showingBrowser = true
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.blue)
                                }
                                
                                Button("設置") {
                                    withAnimation(.spring()) {
                                        showingSettings = true
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(.gray)
                            }
                        }
                        .padding(.all, 32)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.05), radius: 15, x: 0, y: 8)
                        )
                        .padding(.horizontal, 24)
                        
                    } else {
                        // 顯示當前照片 - 添加安全檢查
                        if !allPhotos.isEmpty && currentPhotoIndex >= 0 && currentPhotoIndex < allPhotos.count {
                            PhotoCardView(
                                photoItem: allPhotos[currentPhotoIndex],
                                cacheManager: cacheManager,
                                onSwipeLeft: {
                                    deleteCurrentPhoto()
                                },
                                onSwipeRight: {
                                    keepCurrentPhoto()
                                },
                                isLongPressing: $isLongPressing,
                                continuousSaveCount: $continuousSaveCount,
                                onLongPressStart: startContinuousSave,
                                onLongPressEnd: stopContinuousSave
                            )
                            .id(cardKey) // 使用id強制重新創建view
                            .padding(.horizontal, 20)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                                removal: .opacity.combined(with: .scale(scale: 0.9))
                            ))
                        } else {
                            // 索引異常時的顯示
                            VStack(spacing: 20) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 60))
                                    .foregroundColor(.orange)
                                
                                VStack(spacing: 8) {
                                    Text("索引異常")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("當前索引: \(currentPhotoIndex)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("照片總數: \(allPhotos.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Button("重置到第一張") {
                                        if !allPhotos.isEmpty {
                                            currentPhotoIndex = 0
                                            cardKey = UUID()
                                            updatePreloadCache()
                                        }
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.top, 10)
                                }
                            }
                            .padding(40)
                        }
                    }
                    
                    Spacer()
                    
                        // 美化的底部操作按鈕
    if !allPhotos.isEmpty {
        HStack(spacing: 20) {       
            // 刪除按鈕
            ModernActionButton(
                icon: "trash.fill",
                text: "刪除",
                color: .red,
                isPrimary: false,
                action: {
                    print("🗑️ 刪除按鈕被點擊，當前索引: \(currentPhotoIndex)")
                    deleteCurrentPhoto()
                }
            )

            // 上一張按鈕 - 改善邏輯
            ModernActionButton(
                icon: "chevron.left",
                text: "上一張",
                color: .blue,
                isPrimary: false,
                action: {
                    print("⬅️ 上一張按鈕被點擊，當前索引: \(currentPhotoIndex)")
                    moveToPreviousPhoto()
                }
            )
            .disabled(currentPhotoIndex <= 0) // 改善禁用條件
            .opacity(currentPhotoIndex <= 0 ? 0.5 : 1.0)
            
            // 保留按鈕 - 支援長按連續保留
            ModernActionButton(
                icon: "heart.fill",
                text: "保留",
                color: .green,
                isPrimary: true,
                action: {
                    print("💚 保留按鈕被點擊，當前索引: \(currentPhotoIndex)")
                    keepCurrentPhoto()
                },
                onLongPressStart: startContinuousSave,
                onLongPressEnd: stopContinuousSave
            )
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 10)
    } else {
        // 調試信息：當沒有照片時顯示
        Text("📸 沒有照片可顯示")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            #if os(iOS)
            // 锁定为竖屏模式 - 使用新的iOS API避免警告
            if #available(iOS 16.0, *) {
                // iOS 16+ 使用UIWindowScene.requestGeometryUpdate
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
                    windowScene.requestGeometryUpdate(geometryPreferences) { error in
                        print("设置屏幕方向失败: \(error.localizedDescription)")
                    }
                }
            } else {
                // iOS 15及以下版本使用旧方法
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            }
            #endif
            
            // 检查 JetBrains Mono 字体是否可用
            #if os(iOS)
            // 显示详细的字体状态报告
            print(FontChecker.getFontStatusReport())
            
            // 验证项目字体配置
            let fontValidation = FontChecker.validateProjectFonts()
            if !fontValidation.missing.isEmpty {
                print("⚠️ 项目中缺失的字体文件:")
                for missing in fontValidation.missing {
                    print("   ❌ \(missing)")
                }
            }
            if !fontValidation.valid.isEmpty {
                print("✅ 项目中可用的字体文件:")
                for valid in fontValidation.valid {
                    print("   ✅ \(valid)")
                }
            }
            
            // 显示配置指导
            print(FontChecker.getConfigurationInstructions())
            #endif
            
            checkPhotoPermission()
        }
        .onDisappear {
            // 应用退到后台时清理部分缓存，节省内存
            cacheManager.clearAllCache()
            
            // 停止长按操作，避免内存泄漏
            if isLongPressing {
                stopContinuousSave()
            }
        }
        .sheet(isPresented: $showingOverview) {
            PhotoOverviewView(photos: allPhotos, onDismiss: {
                withAnimation(.easeOut) {
                    showingOverview = false
                }
            })
        }
        .sheet(isPresented: $showingBrowser) {
            PhotoBrowserView(
                photos: allPhotos, 
                onDismiss: {
                    withAnimation(.easeOut) {
                        showingBrowser = false
                    }
                },
                onPhotoUpdated: { updatedPhotos in
                    self.allPhotos = updatedPhotos
                }
            )
        }
        .sheet(isPresented: $showingTrashBin) {
            TrashBinView(
                photos: allPhotos,
                onDismiss: {
                    withAnimation(.easeOut) {
                        showingTrashBin = false
                    }
                },
                onPhotosUpdated: { updatedPhotos in
                    self.allPhotos = updatedPhotos
                }
            )
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                onDismiss: {
                    withAnimation(.easeOut) {
                        showingSettings = false
                    }
                },
                onReset: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        performReset()
                    }
                },
                onExport: {
                    return dataManager.exportData()
                },
                onImport: { data in
                    let success = dataManager.importData(data)
                    if success {
                        // 導入成功後重新載入照片
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            checkPhotoPermission()
                        }
                    }
                    return success
                },
                photosCount: allPhotos.count,
                processedCount: processedPhotosCount,
                keptCount: keptPhotosCount,
                deletedCount: deletedPhotosCount
            )
        }

        .overlay(
            // 重置过程中的加载动画
            Group {
                if isResetting {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.blue)
                            
                            Text("正在重置照片狀態...")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        .padding(40)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .shadow(radius: 10)
                        )
                    }
                    .transition(.opacity)
                }
            }
        )
    }
    
    // 計算統計數據
    private var processedPhotosCount: Int {
        allPhotos.filter { $0.status != .unprocessed }.count
    }
    
    private var keptPhotosCount: Int {
        allPhotos.filter { $0.status == .kept }.count
    }
    
    private var deletedPhotosCount: Int {
        allPhotos.filter { $0.status == .deleted }.count
    }
    
    private var unprocessedPhotosCount: Int {
        allPhotos.filter { $0.status == .unprocessed }.count
    }
    
    // 檢查照片權限
    private func checkPhotoPermission() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch authorizationStatus {
        case .notDetermined:
            // 直接請求權限而不顯示自定義警告
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    self.authorizationStatus = status
                    if status == .authorized || status == .limited {
                        fetchPhotos()
                    } else {
                        self.isLoading = false
                    }
                }
            }
        case .authorized, .limited:
            fetchPhotos()
        case .denied, .restricted:
            isLoading = false
        @unknown default:
            isLoading = false
        }
    }
    
    // 獲取所有照片并启动预加载（集成持久化）
    private func fetchPhotos() {
        isLoading = true
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        // 从持久化存储恢复照片状态
        let (restoredPhotos, savedIndex) = dataManager.loadPhotoData(for: assets)
        
        // 清理不存在的照片数据
        let validIdentifiers = Set(assets.map { $0.localIdentifier })
        dataManager.cleanupDeletedPhotos(validAssetIdentifiers: validIdentifiers)
        
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.5)) {
                self.allPhotos = restoredPhotos
                self.currentPhotoIndex = savedIndex // 恢复用户上次的位置
                self.cardKey = UUID() // 更新key
                self.isLoading = false
                
                // 开始预加载前几张照片，提高用户体验
                self.updatePreloadCache()
                
                print("📸 恢复了 \(restoredPhotos.count) 张照片，当前位置: \(savedIndex)")
            }
        }
    }
    
    // 智能预加载缓存策略
    private func updatePreloadCache() {
        guard !allPhotos.isEmpty else { return }
        
        // 优先加载当前照片（确保瞬时显示）
        let currentAsset = allPhotos[currentPhotoIndex].asset
        
        // 计算预加载范围：当前+前1张+后5张
        let startIndex = max(0, currentPhotoIndex - 1)
        let endIndex = min(allPhotos.count - 1, currentPhotoIndex + preloadRange)
        
        // 获取需要预加载的照片资源
        let assetsToPreload = Array(allPhotos[startIndex...endIndex].map { $0.asset })
        
        // 高优先级预加载当前和下一张
        let highPriorityAssets = [currentAsset] + (currentPhotoIndex + 1 < allPhotos.count ? [allPhotos[currentPhotoIndex + 1].asset] : [])
        
        // 立即开始高优先级预加载
        DispatchQueue.global(qos: .userInteractive).async {
            self.cacheManager.preloadPhotos(highPriorityAssets)
        }
        
        // 稍后预加载其他照片
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) {
            self.cacheManager.preloadPhotos(assetsToPreload)
        }
        
        // 智能清理过远的缓存（避免内存过大）
        if currentPhotoIndex > 15 {
            let assetsToRemove = Array(allPhotos[0..<(currentPhotoIndex - 15)].map { $0.asset })
            cacheManager.stopCaching(assetsToRemove)
        }
        
        print("📸 预加载照片: \(startIndex) 到 \(endIndex) (当前: \(currentPhotoIndex), 高优先级: \(highPriorityAssets.count))")
    }
    
    // 刪除當前照片（移至App內垃圾桶）
    private func deleteCurrentPhoto() {
        guard !allPhotos.isEmpty, currentPhotoIndex >= 0, currentPhotoIndex < allPhotos.count else { 
            print("❌ 刪除失敗：索引無效 currentPhotoIndex=\(currentPhotoIndex), allPhotos.count=\(allPhotos.count)")
            return 
        }
        
        print("🗑️ 開始刪除照片，索引: \(currentPhotoIndex)")
        
        // 標記為已刪除並更新UI（僅在App內標記，不實際刪除）
        allPhotos[currentPhotoIndex].status = .deleted
        allPhotos[currentPhotoIndex].processedDate = Date()
        
        // 立即保存照片状态变更
        dataManager.updatePhotoStatus(allPhotos[currentPhotoIndex])
        
        // 快速移動到下一張照片，與滑動動畫同步
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            moveToNextPhoto()
        }
        
        print("照片已移至App內垃圾桶并已保存")
    }
    
    // 保留當前照片
    private func keepCurrentPhoto() {
        guard !allPhotos.isEmpty, currentPhotoIndex >= 0, currentPhotoIndex < allPhotos.count else { 
            print("❌ 保留失敗：索引無效 currentPhotoIndex=\(currentPhotoIndex), allPhotos.count=\(allPhotos.count)")
            return 
        }
        
        print("💚 開始保留照片，索引: \(currentPhotoIndex)")
        
        // 標記為已保留
        allPhotos[currentPhotoIndex].status = .kept
        allPhotos[currentPhotoIndex].processedDate = Date()
        
        // 立即保存照片状态变更
        dataManager.updatePhotoStatus(allPhotos[currentPhotoIndex])
        
        // 快速移動到下一張照片，與滑動動畫同步
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            moveToNextPhoto()
        }
    }
    
    // 移動到下一張照片
    private func moveToNextPhoto() {
        guard !allPhotos.isEmpty else { 
            print("❌ 無照片可移動")
            return 
        }
        
        // 確保不超出範圍
        if currentPhotoIndex < allPhotos.count - 1 {
            currentPhotoIndex += 1
            print("➡️ 移動到下一張照片，新索引: \(currentPhotoIndex)")
        } else {
            print("📋 已到達最後一張照片，索引: \(currentPhotoIndex)")
        }
        
        cardKey = UUID() // 更新key以強制重新載入
        
        // 只保存进度，不保存整个照片数组（性能优化）
        dataManager.saveProgressOnly(currentIndex: currentPhotoIndex)
        
        // 更新预加载缓存，确保下一张照片已经准备好
        updatePreloadCache()
    }
    
    // 移動到上一張照片
    private func moveToPreviousPhoto() {
        guard !allPhotos.isEmpty, currentPhotoIndex > 0 else { 
            print("❌ 無法返回上一張：currentPhotoIndex=\(currentPhotoIndex), allPhotos.count=\(allPhotos.count)")
            return 
        }
        
        print("⬅️ 開始返回上一張照片，當前索引: \(currentPhotoIndex)")
        
        currentPhotoIndex -= 1
        
        // 確保索引在有效範圍內
        currentPhotoIndex = max(0, currentPhotoIndex)
        
        // 清空返回照片的處理狀態，讓用戶可以重新決定
        allPhotos[currentPhotoIndex].status = .unprocessed
        allPhotos[currentPhotoIndex].processedDate = nil
        
        // 保存状态变更和当前进度（性能优化）
        dataManager.updatePhotoStatus(allPhotos[currentPhotoIndex])
        dataManager.saveProgressOnly(currentIndex: currentPhotoIndex)
        
        cardKey = UUID() // 更新key以強制重新載入
        
        // 更新预加载缓存，确保上一张照片已经准备好
        updatePreloadCache()
        
        // 添加觸覺反饋（iOS）
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
        
        print("📸 返回上一張照片成功，新索引: \(currentPhotoIndex)，狀態已清空")
    }
    
    // 执行重置操作（带加载状态管理）
    private func performReset() {
        // 设置加载状态
        isResetting = true
        
        // 立即停止任何正在进行的长按操作
        if isLongPressing {
            stopContinuousSave()
        }
        
        // 提供触觉反馈，让用户知道操作已开始
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        #endif
        
        // 立即清理所有缓存，释放内存
        cacheManager.clearAllCache()
        
        print("🔄 开始重置所有照片状态...")
        
        // 使用异步处理，避免阻塞主线程，无论数据量大小
        DispatchQueue.global(qos: .userInitiated).async {
            self.resetAllPhotosAsync()
        }
    }
    
    // 快速重置操作（简化优化版本）
    private func resetAllPhotosAsync() {
        // 在后台线程快速重置所有照片状态
        let startTime = Date()
        
        // 直接在内存中重置所有照片状态
        for index in 0..<allPhotos.count {
            allPhotos[index].status = .unprocessed
            allPhotos[index].processedDate = nil
        }
        
        // 立即更新UI状态
        DispatchQueue.main.async {
            self.currentPhotoIndex = 0
            self.cardKey = UUID()
            
            // 重新开始预加载缓存
            self.updatePreloadCache()
            
            // 重置完成，隐藏加载动画
            withAnimation(.easeOut) {
                self.isResetting = false
            }
            
            let duration = Date().timeIntervalSince(startTime)
            print("✅ 快速重置完成，共处理 \(self.allPhotos.count) 张照片，耗时 \(String(format: "%.2f", duration))秒")
            
            // 提供完成反馈
            self.provideFeedbackForReset()
        }
        
        // 异步保存到磁盘，不阻塞UI
        DispatchQueue.global(qos: .utility).async {
            self.dataManager.resetAllPhotosStatus(self.allPhotos)
        }
    }
    

    
    // 为重置操作提供用户反馈
    private func provideFeedbackForReset() {
        #if os(iOS)
        // 立即提供成功完成的触觉反馈
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)
        #endif
    }
    
    // 开始长按连续保存
    private func startContinuousSave() {
        print("🔥 开始长按连续保存 - 函数被调用")
        
        // 确保在主线程中更新状态
        DispatchQueue.main.async {
            // 立即更新状态，让UI响应
            withAnimation(.easeInOut(duration: 0.3)) {
                self.isLongPressing = true
                self.continuousSaveCount = 0
            }
            
            print("🔥 长按状态已更新: isLongPressing = \(self.isLongPressing)")
            
            // 触觉反馈
            #if os(iOS)
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
            #endif
            
            // 稍微延迟执行保存操作，让动画先开始
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.performFirstSave()
                self.startContinuousTimer()
            }
        }
    }
    
    // 停止长按连续保存
    private func stopContinuousSave() {
        print("🛑 停止长按连续保存 - 函数被调用，当前保存数: \(continuousSaveCount)")
        
        // 立即停止定时器和重置状态，无需结束动画
        continuousSaveTimer?.invalidate()
        continuousSaveTimer = nil
        
        // 触觉反馈
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
        
        print("🛑 停止长按连续保存，共保存了 \(continuousSaveCount) 张照片")
        
        // 立即重置状态，无延迟
        isLongPressing = false
        let savedCount = continuousSaveCount
        continuousSaveCount = 0
        
        // 立即刷新视图，显示当前照片
        cardKey = UUID()
        
        // 异步保存当前进度，不阻塞UI
        DispatchQueue.global(qos: .utility).async {
            self.dataManager.saveProgressOnly(currentIndex: self.currentPhotoIndex)
        }
        
        print("🛑 长按状态已重置: isLongPressing = \(isLongPressing)，保存了 \(savedCount) 张照片")
    }
    
    // 启动连续保存定时器
    private func startContinuousTimer() {
        continuousSaveTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            self.performContinuousSave()
        }
    }
    
    // 执行第一次保存
    private func performFirstSave() {
        guard currentPhotoIndex < allPhotos.count else {
            stopContinuousSave()
            return
        }
        
        continuousSaveCount += 1
        keepCurrentPhoto()
    }
    
    // 执行连续保存的单次操作
    private func performContinuousSave() {
        guard currentPhotoIndex < allPhotos.count else {
            // 没有更多照片时停止长按
            stopContinuousSave()
            return
        }
        
        continuousSaveCount += 1
        
        // 轻量级保存：只更新状态，不重新创建视图
        keepCurrentPhotoLightweight()
        
        // 轻微的触觉反馈
        #if os(iOS)
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
        #endif
    }
    
    // 轻量级保留照片（连续保存专用）
    private func keepCurrentPhotoLightweight() {
        guard currentPhotoIndex < allPhotos.count else { return }
        
        // 标记为已保留
        allPhotos[currentPhotoIndex].status = .kept
        allPhotos[currentPhotoIndex].processedDate = Date()
        
        // 异步保存，避免阻塞UI
        DispatchQueue.global(qos: .utility).async {
            self.dataManager.updatePhotoStatus(self.allPhotos[self.currentPhotoIndex])
        }
        
        // 移动到下一张照片
        currentPhotoIndex += 1
        
        // 🔥 长按过程中也要更新cardKey，让用户看到照片切换
        // 动画状态通过绑定变量 isLongPressing 和 continuousSaveCount 来维持
        cardKey = UUID()
        print("🔄 长按进行中：更新cardKey显示新照片，动画状态通过绑定变量维持")
        
        // 异步更新预加载，不阻塞主线程
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.async {
                self.updatePreloadCache()
            }
        }
    }
}
