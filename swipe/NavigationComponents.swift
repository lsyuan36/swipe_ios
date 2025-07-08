//
//  NavigationComponents.swift
//  swipe
//
//  Created by 賴聖元 on 2025/7/8.
//

import SwiftUI

// 現代化導航按鈕
struct ModernNavButton: View {
    let icon: String
    let color: Color
    let badgeCount: Int
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // 按鈕背景
                Circle()
                    .fill(isActive ? color.opacity(0.2) : Color.white.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: isActive ? [color.opacity(0.3), color.opacity(0.1)] : [Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: isActive ? color.opacity(0.3) : Color.black.opacity(0.1),
                        radius: isActive ? 8 : 4,
                        x: 0,
                        y: isActive ? 4 : 2
                    )
                
                // 圖標
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isActive ? color : color.opacity(0.8))
            }
            // 徽章 - 使用overlay實現穩定定位
            .overlay(
                Group {
                    if badgeCount > 0 {
                        ZStack {
                            Circle()
                                .fill(color)
                                .frame(width: 18, height: 18)
                                .shadow(color: color.opacity(0.4), radius: 2, x: 0, y: 1)
                            
                            Text("\(badgeCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 8, y: -8)
                    }
                },
                alignment: .topTrailing
            )
        }
        .scaleEffect(isActive ? 1.05 : 1.0)
        .buttonStyle(PlainButtonStyle())
    }
} 