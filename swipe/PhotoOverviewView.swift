//
//  PhotoOverviewView.swift
//  swipe
//
//  Created by 賴聖元 on 2025/7/8.
//

import SwiftUI

// 照片總覽視圖
struct PhotoOverviewView: View {
    let photos: [PhotoItem]
    let onDismiss: () -> Void
    
    @State private var selectedFilter: PhotoStatus? = nil
    
    var filteredPhotos: [PhotoItem] {
        if let filter = selectedFilter {
            return photos.filter { $0.status == filter }
        }
        return photos
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 篩選按鈕
                HStack(spacing: 15) {
                    FilterButton(
                        title: "全部",
                        count: photos.count,
                        isSelected: selectedFilter == nil,
                        color: .blue
                    ) {
                        withAnimation(.easeInOut) {
                            selectedFilter = nil
                        }
                    }
                    
                    FilterButton(
                        title: "未處理",
                        count: photos.filter { $0.status == .unprocessed }.count,
                        isSelected: selectedFilter == .unprocessed,
                        color: .gray
                    ) {
                        withAnimation(.easeInOut) {
                            selectedFilter = .unprocessed
                        }
                    }
                    
                    FilterButton(
                        title: "已保留",
                        count: photos.filter { $0.status == .kept }.count,
                        isSelected: selectedFilter == .kept,
                        color: .green
                    ) {
                        withAnimation(.easeInOut) {
                            selectedFilter = .kept
                        }
                    }
                    
                    FilterButton(
                        title: "已刪除",
                        count: photos.filter { $0.status == .deleted }.count,
                        isSelected: selectedFilter == .deleted,
                        color: .red
                    ) {
                        withAnimation(.easeInOut) {
                            selectedFilter = .deleted
                        }
                    }
                }
                .padding()
                
                // 照片網格
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                        ForEach(filteredPhotos) { photoItem in
                            PhotoThumbnailView(photoItem: photoItem)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: filteredPhotos.count)
                }
            }
            .navigationTitle("照片總覽")
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
    }
} 