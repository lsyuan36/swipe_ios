//
//  FontExtensions.swift
//  swipe
//
//  Created by 賴聖元 on 2025/7/8.
//

import SwiftUI

#if os(iOS)
import UIKit
#endif

extension Font {
    // JetBrains Mono 字体扩展（带回退机制）
    
    /// JetBrains Mono Regular - 如果字体不可用，回退到系统等宽字体
    static func jetBrainsMono(_ size: CGFloat) -> Font {
        if FontChecker.isJetBrainsMonoAvailable() {
            return .custom("JetBrains Mono", size: size)
        } else {
            // 回退到系统等宽字体
            return .system(size: size, weight: .regular, design: .monospaced)
        }
    }
    
    /// JetBrains Mono Bold
    static func jetBrainsMonoBold(_ size: CGFloat) -> Font {
        if FontChecker.isJetBrainsMonoAvailable() {
            return .custom("JetBrains Mono", size: size).weight(.bold)
        } else {
            return .system(size: size, weight: .bold, design: .monospaced)
        }
    }
    
    /// JetBrains Mono Medium
    static func jetBrainsMonoMedium(_ size: CGFloat) -> Font {
        if FontChecker.isJetBrainsMonoAvailable() {
            return .custom("JetBrains Mono", size: size).weight(.medium)
        } else {
            return .system(size: size, weight: .medium, design: .monospaced)
        }
    }
    
    /// JetBrains Mono Light
    static func jetBrainsMonoLight(_ size: CGFloat) -> Font {
        if FontChecker.isJetBrainsMonoAvailable() {
            return .custom("JetBrains Mono", size: size).weight(.light)
        } else {
            return .system(size: size, weight: .light, design: .monospaced)
        }
    }
    
    // 预定义尺寸
    
    /// 标题字体 - 32pt
    static var jetBrainsTitle: Font {
        return .jetBrainsMono(32)
    }
    
    /// 副标题字体 - 20pt
    static var jetBrainsSubtitle: Font {
        return .jetBrainsMono(20)
    }
    
    /// 正文字体 - 16pt
    static var jetBrainsBody: Font {
        return .jetBrainsMono(16)
    }
    
    /// 标注字体 - 14pt
    static var jetBrainsCaption: Font {
        return .jetBrainsMono(14)
    }
    
    /// 计数器字体 - 36pt Bold
    static var jetBrainsCounter: Font {
        return .jetBrainsMonoBold(36)
    }
    
    /// 按钮字体 - 14pt Medium
    static var jetBrainsButton: Font {
        return .jetBrainsMonoMedium(14)
    }
}

// 字体可用性检查和管理
struct FontChecker {
    /// JetBrains Mono 字体的所有变体
    private static let jetBrainsMonoVariants = [
        "JetBrainsMono-Regular",
        "JetBrainsMono-Bold", 
        "JetBrainsMono-Light",
        "JetBrainsMono-Medium",
        "JetBrains Mono Regular",
        "JetBrains Mono Bold",
        "JetBrains Mono Light", 
        "JetBrains Mono Medium"
    ]
    
    /// 检查 JetBrains Mono 字体是否已安装
    static func isJetBrainsMonoAvailable() -> Bool {
        #if os(iOS)
        let fontNames = UIFont.familyNames
        for family in fontNames {
            let fonts = UIFont.fontNames(forFamilyName: family)
            for variant in jetBrainsMonoVariants {
                if fonts.contains(variant) {
                    return true
                }
            }
            // 检查family名称是否包含JetBrains
            if family.lowercased().contains("jetbrains") {
                return true
            }
        }
        return false
        #else
        return true // 在非iOS平台假设可用
        #endif
    }
    
    /// 获取详细的字体状态报告
    static func getFontStatusReport() -> String {
        #if os(iOS)
        var report = "📊 JetBrains Mono 字体状态报告\n"
        report += "===============================\n"
        
        let fontNames = UIFont.familyNames
        var foundFonts: [String] = []
        
        for family in fontNames {
            let fonts = UIFont.fontNames(forFamilyName: family)
            
            // 检查JetBrains相关字体
            if family.lowercased().contains("jetbrains") {
                report += "✅ 找到字体家族: \(family)\n"
                for font in fonts {
                    report += "   - \(font)\n"
                    foundFonts.append(font)
                }
            }
            
            // 检查具体的字体名称
            for variant in jetBrainsMonoVariants {
                if fonts.contains(variant) && !foundFonts.contains(variant) {
                    report += "✅ 找到字体: \(variant)\n"
                    foundFonts.append(variant)
                }
            }
        }
        
        if foundFonts.isEmpty {
            report += "❌ 未找到任何 JetBrains Mono 字体\n"
            report += "💡 请检查字体文件是否正确添加到项目中\n"
        } else {
            report += "✅ 总共找到 \(foundFonts.count) 个 JetBrains Mono 字体变体\n"
        }
        
        report += "===============================\n"
        
        // 测试字体是否可以正常创建UIFont实例
        if let testFont = UIFont(name: "JetBrains Mono", size: 16) {
            report += "✅ 可以创建 JetBrains Mono UIFont 实例\n"
            report += "   实际字体名称: \(testFont.fontName)\n"
            report += "   字体家族: \(testFont.familyName)\n"
        } else {
            report += "❌ 无法创建 JetBrains Mono UIFont 实例\n"
        }
        
        return report
        #else
        return "📊 非iOS平台，跳过字体检查"
        #endif
    }
    
    /// 列出所有可用的字体（仅用于调试）
    static func listAllFonts() {
        #if os(iOS)
        print("📝 所有可用字体列表：")
        print("====================")
        let fontFamilyNames = UIFont.familyNames.sorted()
        for familyName in fontFamilyNames {
            print("📁 Family: \(familyName)")
            let names = UIFont.fontNames(forFamilyName: familyName).sorted()
            for name in names {
                print("   📄 \(name)")
            }
            print("")
        }
        print("====================")
        #endif
    }
    
    /// 验证项目中声明的字体是否都存在
    static func validateProjectFonts() -> (valid: [String], missing: [String]) {
        let expectedFonts = [
            "JetBrainsMono-Regular.ttf",
            "JetBrainsMono-Bold.ttf", 
            "JetBrainsMono-Light.ttf",
            "JetBrainsMono-Medium.ttf"
        ]
        
        var validFonts: [String] = []
        var missingFonts: [String] = []
        
        #if os(iOS)
        for fontFile in expectedFonts {
            let fontName = fontFile.replacingOccurrences(of: ".ttf", with: "")
            if UIFont(name: fontName, size: 16) != nil {
                validFonts.append(fontFile)
            } else {
                missingFonts.append(fontFile)
            }
        }
        #else
        validFonts = expectedFonts // 非iOS平台假设都可用
        #endif
        
        return (valid: validFonts, missing: missingFonts)
    }
    
    /// 验证Target Info配置提示
    static func getConfigurationInstructions() -> String {
        let isAvailable = isJetBrainsMonoAvailable()
        
        if isAvailable {
            return """
            ✅ JetBrains Mono 字体配置正确！
            
            字体已通过以下方式之一正确配置：
            • Xcode Target → Info → Custom iOS Target Properties → UIAppFonts
            • Xcode Target → Build Settings → Fonts provided by application
            
            您现在可以在代码中使用字体了！
            """
        } else {
            return """
            ❌ JetBrains Mono 字体需要配置
            
            请按照以下步骤配置：
            
            1️⃣ 在 Xcode 中选择项目 → swipe Target → Info 标签页
            2️⃣ 在 Custom iOS Target Properties 中添加：
               键名：Fonts provided by application (或 UIAppFonts)
               类型：Array
               值：添加4个字体文件名
            
            3️⃣ 或者在 Build Settings 中搜索 "font" 并配置
            """
        }
    }
} 