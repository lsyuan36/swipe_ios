//
//  TrashBinView.swift
//  swipe
//
//  Created by 賴聖元 on 2025/7/8.
//

import SwiftUI
import Photos

// 垃圾桶視圖
struct TrashBinView: View {
    @State private var photos: [PhotoItem]
    let onDismiss: () -> Void
    let onPhotosUpdated: ([PhotoItem]) -> Void
    
    @State private var showingDeleteConfirmation = false
    
    init(photos: [PhotoItem], onDismiss: @escaping () -> Void, onPhotosUpdated: @escaping ([PhotoItem]) -> Void) {
        self._photos = State(initialValue: photos)
        self.onDismiss = onDismiss
        self.onPhotosUpdated = onPhotosUpdated
    }
    
    // 只顯示已刪除的照片
    var deletedPhotos: [PhotoItem] {
        photos.filter { $0.status == .deleted }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if deletedPhotos.isEmpty {
                    // 空狀態
                    VStack(spacing: 20) {
                        Image(systemName: "trash")
                            .font(.system(size: 80))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("垃圾桶是空的")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("已刪除的照片會出現在這裡")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else {
                    VStack(spacing: 15) {
                        // 頂部資訊與操作
                        HStack {
                            Text("\(deletedPhotos.count) 張照片")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button("一鍵清空") {
                                showingDeleteConfirmation = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                        .padding(.horizontal)
                        
                        // 照片網格
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 4), spacing: 3) {
                                ForEach(deletedPhotos) { photoItem in
                                    TrashPhotoThumbnailView(
                                        photoItem: photoItem,
                                        onRestore: {
                                            restorePhoto(photoItem)
                                        }
                                    )
                                }
                            }
                            .animation(.easeInOut(duration: 0.3), value: deletedPhotos.count)
                        }
                    }
                }
            }
            .navigationTitle("垃圾桶")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        onDismiss()
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("完成") {
                        onDismiss()
                    }
                }
                #endif
            }
        }
        .alert("永久刪除照片", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("刪除", role: .destructive) {
                permanentlyDeleteAllPhotos()
            }
        } message: {
            Text("此操作會將 \(deletedPhotos.count) 張照片永久移至系統垃圾桶，無法復原。")
        }
    }
    
    // 恢復照片
    private func restorePhoto(_ photoItem: PhotoItem) {
        if let index = photos.firstIndex(where: { $0.id == photoItem.id }) {
            withAnimation(.easeInOut) {
                photos[index].status = .unprocessed
                photos[index].processedDate = nil
            }
            onPhotosUpdated(photos)
        }
    }
    
    // 永久刪除所有照片
    private func permanentlyDeleteAllPhotos() {
        let assetsToDelete = deletedPhotos.map { $0.asset }
        
        // 先更新UI，移除所有已刪除狀態的照片
        for index in photos.indices.reversed() {
            if photos[index].status == .deleted {
                photos.remove(at: index)
            }
        }
        onPhotosUpdated(photos)
        
        // 實際執行刪除操作
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    print("已永久刪除 \(assetsToDelete.count) 張照片")
                } else {
                    print("刪除失敗: \(error?.localizedDescription ?? "未知錯誤")")
                }
            }
        })
    }
} 