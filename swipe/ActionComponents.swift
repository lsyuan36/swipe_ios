//
//  ActionComponents.swift
//  swipe
//
//  Created by 賴聖元 on 2025/7/8.
//

import SwiftUI

#if os(iOS)
import UIKit
#endif

// 現代化動作按鈕
struct ModernActionButton: View {
    let icon: String
    let text: String
    let color: Color
    let isPrimary: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // 觸覺反饋
            #if os(iOS)
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            #endif
            
            action()
        }) {
            VStack(spacing: 12) {
                // 圖標圈 - 縮小尺寸
                ZStack {
                    Circle()
                        .fill(
                            isPrimary ?
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 55, height: 55)
                        .overlay(
                            Circle()
                                .stroke(
                                    isPrimary ? Color.clear : color.opacity(0.3),
                                    lineWidth: 2
                                )
                        )
                        .shadow(
                            color: isPrimary ? color.opacity(0.4) : Color.black.opacity(0.1),
                            radius: isPrimary ? 10 : 6,
                            x: 0,
                            y: isPrimary ? 5 : 3
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(isPrimary ? .white : color)
                }
                
                // 文字標籤
                Text(text)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .buttonStyle(PlainButtonStyle())
    }
}

// 動作按鈕組件
struct ActionButton: View {
    let icon: String
    let text: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            // 极简化动画逻辑，避免AnimatablePair错误
            action()
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 55))
                    .foregroundColor(color)
                
                Text(text)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
} 