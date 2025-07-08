//
//  PhotoBrowserView.swift
//  swipe
//
//  Created by 賴聖元 on 2025/7/8.
//

import SwiftUI
import Photos

// 照片瀏覽器視圖 - 改為表格形式
struct PhotoBrowserView: View {
    @State private var photos: [PhotoItem]
    let onDismiss: () -> Void
    let onPhotoUpdated: ([PhotoItem]) -> Void
    
    @State private var selectedFilter: PhotoStatus? = nil
    @State private var selectedPhoto: PhotoItem? = nil
    @State private var showingFullSize = false
    
    init(photos: [PhotoItem], onDismiss: @escaping () -> Void, onPhotoUpdated: @escaping ([PhotoItem]) -> Void) {
        self._photos = State(initialValue: photos)
        self.onDismiss = onDismiss
        self.onPhotoUpdated = onPhotoUpdated
    }
    
    var filteredPhotos: [PhotoItem] {
        if let filter = selectedFilter {
            return photos.filter { $0.status == filter }
        }
        return photos
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 美化背景漸變
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 美化的篩選按鈕區域
                    VStack(spacing: 16) {
                        // 標題區域
                        HStack {
                            Text("照片分類")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(filteredPhotos.count) 張")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        
                        // 篩選按鈕
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ModernFilterButton(
                                    title: "全部",
                                    count: photos.count,
                                    isSelected: selectedFilter == nil,
                                    color: .blue,
                                    icon: "photo.stack"
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedFilter = nil
                                    }
                                }
                                
                                ModernFilterButton(
                                    title: "未處理",
                                    count: photos.filter { $0.status == .unprocessed }.count,
                                    isSelected: selectedFilter == .unprocessed,
                                    color: .orange,
                                    icon: "clock"
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedFilter = .unprocessed
                                    }
                                }
                                
                                ModernFilterButton(
                                    title: "已保留",
                                    count: photos.filter { $0.status == .kept }.count,
                                    isSelected: selectedFilter == .kept,
                                    color: .green,
                                    icon: "heart.fill"
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedFilter = .kept
                                    }
                                }
                                
                                ModernFilterButton(
                                    title: "已刪除",
                                    count: photos.filter { $0.status == .deleted }.count,
                                    isSelected: selectedFilter == .deleted,
                                    color: .red,
                                    icon: "trash"
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedFilter = .deleted
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 0)
                            .fill(Color.white.opacity(0.8))
                            .background(.ultraThinMaterial)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    
                    // 美化的照片網格
                    if filteredPhotos.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: selectedFilter == nil ? "photo" : getFilterIcon())
                                .font(.system(size: 80))
                                .foregroundColor(.gray.opacity(0.3))
                            
                            Text(getEmptyStateText())
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Text("試試其他分類")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.clear)
                        
                    } else {
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                                ForEach(filteredPhotos) { photoItem in
                                    ModernPhotoThumbnailView(photoItem: photoItem)
                                        .onTapGesture {
                                            selectedPhoto = photoItem
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                showingFullSize = true
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        }
                    }
                }
            }
            .navigationTitle("照片瀏覽器")
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
        .sheet(isPresented: $showingFullSize) {
            if let photo = selectedPhoto {
                FullSizePhotoView(
                    photoItem: photo,
                    onDismiss: {
                        withAnimation(.easeOut) {
                            showingFullSize = false
                        }
                    },
                    onStatusChanged: { updatedPhoto in
                        updatePhotoStatus(updatedPhoto)
                    }
                )
            }
        }
    }
    
    private func updatePhotoStatus(_ updatedPhoto: PhotoItem) {
        if let index = photos.firstIndex(where: { $0.id == updatedPhoto.id }) {
            photos[index] = updatedPhoto
            onPhotoUpdated(photos)
        }
    }
    
    // 輔助函數
    private func getFilterIcon() -> String {
        switch selectedFilter {
        case .unprocessed: return "clock"
        case .kept: return "heart.fill"
        case .deleted: return "trash"
        case nil: return "photo"
        }
    }
    
    private func getEmptyStateText() -> String {
        switch selectedFilter {
        case .unprocessed: return "沒有未處理的照片"
        case .kept: return "沒有保留的照片"
        case .deleted: return "沒有刪除的照片"
        case nil: return "沒有照片"
        }
    }
} 