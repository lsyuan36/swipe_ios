//
//  FullSizePhotoView.swift
//  swipe
//
//  Created by 賴聖元 on 2025/7/8.
//

import SwiftUI
import Photos

// 全尺寸照片視圖 - 增加編輯功能
struct FullSizePhotoView: View {
    @State private var photoItem: PhotoItem
    let onDismiss: () -> Void
    let onStatusChanged: (PhotoItem) -> Void
    
    @State private var image: Image? = nil
    @State private var showingControls = true
    
    init(photoItem: PhotoItem, onDismiss: @escaping () -> Void, onStatusChanged: @escaping (PhotoItem) -> Void) {
        self._photoItem = State(initialValue: photoItem)
        self.onDismiss = onDismiss
        self.onStatusChanged = onStatusChanged
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let image = image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingControls.toggle()
                            }
                        }
                } else {
                    ProgressView()
                        .scaleEffect(2.0)
                        .tint(.white)
                }
                
                // 狀態指示器
                VStack {
                    HStack {
                        Spacer()
                        if photoItem.status == .kept {
                            Image(systemName: "heart.fill")
                                .font(.title)
                                .foregroundColor(.green)
                                .background(Color.white.opacity(0.9))
                                .clipShape(Circle())
                                .padding()
                                .scaleEffect(showingControls ? 1.0 : 0.0)
                                .animation(.spring(), value: showingControls)
                        } else if photoItem.status == .deleted {
                            Image(systemName: "trash.fill")
                                .font(.title)
                                .foregroundColor(.red)
                                .background(Color.white.opacity(0.9))
                                .clipShape(Circle())
                                .padding()
                                .scaleEffect(showingControls ? 1.0 : 0.0)
                                .animation(.spring(), value: showingControls)
                        }
                    }
                    Spacer()
                    
                    // 底部控制按鈕
                    if showingControls {
                        HStack(spacing: 60) {
                            Button(action: {
                                withAnimation(.spring()) {
                                    deletePhoto()
                                }
                            }) {
                                VStack {
                                    Image(systemName: "trash.circle.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.red)
                                    Text("刪除")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            }
                            .disabled(photoItem.status == .deleted)
                            .opacity(photoItem.status == .deleted ? 0.5 : 1.0)
                            
                            Button(action: {
                                withAnimation(.spring()) {
                                    keepPhoto()
                                }
                            }) {
                                VStack {
                                    Image(systemName: "heart.circle.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.green)
                                    Text("保留")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            }
                            .disabled(photoItem.status == .kept)
                            .opacity(photoItem.status == .kept ? 0.5 : 1.0)
                        }
                        .padding(.bottom, 50)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        onDismiss()
                    }
                    .foregroundColor(.white)
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("完成") {
                        onDismiss()
                    }
                    .foregroundColor(.white)
                }
                #endif
            }
        }
        .onAppear {
            loadFullSizeImage()
        }
    }
    
    private func loadFullSizeImage() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        PHCachingImageManager.default().requestImage(
            for: photoItem.asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { result, _ in
            if let result = result {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.3)) {
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
    
    private func deletePhoto() {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([photoItem.asset] as NSArray)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    photoItem.status = .deleted
                    photoItem.processedDate = Date()
                    onStatusChanged(photoItem)
                    print("照片已移至垃圾桶")
                } else {
                    print("刪除照片失敗: \(error?.localizedDescription ?? "未知錯誤")")
                }
            }
        }
    }
    
    private func keepPhoto() {
        photoItem.status = .kept
        photoItem.processedDate = Date()
        onStatusChanged(photoItem)
    }
} 