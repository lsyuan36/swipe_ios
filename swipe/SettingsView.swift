//
//  SettingsView.swift
//  swipe
//
//  Created by 賴聖元 on 2025/7/8.
//

import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#endif

struct SettingsView: View {
    let onDismiss: () -> Void
    let onReset: () -> Void
    let onExport: () -> Data?
    let onImport: (Data) -> Bool
    let photosCount: Int
    let processedCount: Int
    let keptCount: Int
    let deletedCount: Int
    
    @State private var showingResetConfirmation = false
    @State private var showingExportSheet = false
    @State private var showingImportPicker = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var backupData: Data?
    @State private var backupFileName: String = ""
    @State private var isExporting = false
    @State private var isImporting = false
    
    var body: some View {
        NavigationView {
            List {
                // 統計信息區域
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Text("統計信息")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                            StatCard(title: "總數", count: photosCount, color: .blue, icon: "photo.stack")
                            StatCard(title: "已處理", count: processedCount, color: .green, icon: "checkmark.circle")
                            StatCard(title: "已保留", count: keptCount, color: .mint, icon: "heart.fill")
                            StatCard(title: "已刪除", count: deletedCount, color: .red, icon: "trash.fill")
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("")
                }
                
                // 應用設置區域
                Section("應用設置") {
                    SettingRow(
                        icon: "gearshape.fill",
                        title: "版本信息",
                        subtitle: "Swipe v1.0",
                        color: .gray
                    ) { }
                    
                    SettingRow(
                        icon: "info.circle.fill",
                        title: "使用說明",
                        subtitle: "查看應用使用指南",
                        color: .blue
                    ) { }
                }
                
                // 數據管理區域
                Section("數據管理") {
                    // 導出數據按鈕
                    SettingRow(
                        icon: "icloud.and.arrow.up.fill",
                        title: "導出數據",
                        subtitle: isExporting ? "正在導出..." : "備份您的整理進度",
                        color: .green,
                        isLoading: isExporting
                    ) {
                        exportData()
                    }
                    .disabled(isExporting)
                    
                    // 導入數據按鈕
                    SettingRow(
                        icon: "icloud.and.arrow.down.fill",
                        title: "導入數據",
                        subtitle: isImporting ? "正在導入..." : "從備份恢復進度",
                        color: .orange,
                        isLoading: isImporting
                    ) {
                        showingImportPicker = true
                    }
                    .disabled(isImporting)
                }
                
                // 危險操作區域
                Section("危險操作") {
                    SettingRow(
                        icon: "arrow.clockwise",
                        title: "重置所有數據",
                        subtitle: "清空所有照片的處理狀態",
                        color: .red,
                        isDestructive: true
                    ) {
                        showingResetConfirmation = true
                    }
                }
                .listRowBackground(Color.red.opacity(0.05))
            }
            .navigationTitle("設置")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("完成") {
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
                #endif
            }
        }
        .alert("重置所有照片數據", isPresented: $showingResetConfirmation) {
            Button("取消", role: .cancel) { }
            Button("重置", role: .destructive) {
                onReset()
                onDismiss()
            }
        } message: {
            Text("這將清空所有照片的處理狀態，讓您從頭開始整理。此操作無法復原。")
        }
                 #if os(iOS)
         .sheet(isPresented: $showingExportSheet) {
             if let data = backupData {
                 DataShareSheet(data: data, fileName: backupFileName)
             }
         }
         #endif
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            importData(from: result)
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("確定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - 數據導出功能
    
    private func exportData() {
        isExporting = true
        
        // 提供觸覺回饋（開始）
        #if os(iOS)
        let impactGenerator = UIImpactFeedbackGenerator(style: .light)
        impactGenerator.impactOccurred()
        #endif
        
        DispatchQueue.global(qos: .userInitiated).async {
            // 最小延迟以确保用户看到加载动画
            Thread.sleep(forTimeInterval: 0.5)
            
            guard let data = self.onExport() else {
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.showAlert(title: "導出失敗", message: "無法創建備份數據。請稍後再試。")
                }
                return
            }
            
            // 使用英文文件名避免编码问题
            let fileName = "Swipe_Backup_\(self.getCurrentDateString()).json"
            
            // 不创建文件，直接使用Data分享
            DispatchQueue.main.async {
                self.isExporting = false
                self.backupData = data
                self.backupFileName = fileName
                self.showingExportSheet = true
                
                // 提供觸覺回饋（成功）
                #if os(iOS)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
            }
        }
    }
    
    // MARK: - 數據導入功能
    
    private func importData(from result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            isImporting = true
            
            // 提供觸覺回饋（開始）
            #if os(iOS)
            let impactGenerator = UIImpactFeedbackGenerator(style: .light)
            impactGenerator.impactOccurred()
            #endif
            
            DispatchQueue.global(qos: .userInitiated).async {
                // 最小延迟以确保用户看到加载动画
                Thread.sleep(forTimeInterval: 0.5)
                
                do {
                    let data = try Data(contentsOf: url)
                    
                    // 驗證JSON格式
                    guard self.validateJSONFormat(data) else {
                        DispatchQueue.main.async {
                            self.isImporting = false
                            self.showAlert(title: "導入失敗", message: "文件格式不正確。請選擇有效的Swipe備份文件。")
                        }
                        return
                    }
                    
                    // 執行導入
                    let success = self.onImport(data)
                    
                    DispatchQueue.main.async {
                        self.isImporting = false
                        
                        if success {
                            // 提供觸覺回饋（成功）
                            #if os(iOS)
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            #endif
                            
                            self.showAlert(title: "導入成功", message: "數據已成功恢復。應用將重新載入照片。")
                        } else {
                            // 提供觸覺回饋（失敗）
                            #if os(iOS)
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.error)
                            #endif
                            
                            self.showAlert(title: "導入失敗", message: "無法恢復數據。文件可能已損壞或版本不兼容。")
                        }
                    }
                    
                } catch {
                    DispatchQueue.main.async {
                        self.isImporting = false
                        
                        // 提供觸覺回饋（錯誤）
                        #if os(iOS)
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.error)
                        #endif
                        
                        self.showAlert(title: "導入失敗", message: "無法讀取文件：\(error.localizedDescription)")
                    }
                }
            }
            
        case .failure(let error):
            showAlert(title: "選取文件失敗", message: error.localizedDescription)
        }
    }
    
    // MARK: - 輔助功能
    
         private func validateJSONFormat(_ data: Data) -> Bool {
         do {
             // 嘗試解析JSON結構
             let json = try JSONSerialization.jsonObject(with: data, options: [])
             guard let dict = json as? [String: Any] else { return false }
             
             // 檢查必要的鍵值
             return dict["photoData"] != nil && 
                    dict["currentPhotoIndex"] != nil && 
                    dict["version"] != nil
         } catch {
             print("JSON驗證失敗: \(error)")
             return false
         }
     }
    
    private func getCurrentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

// 統計卡片組件
struct StatCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                
                Spacer()
                
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// 設置行組件
struct SettingRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var isDestructive: Bool = false
    var isLoading: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isDestructive ? .red : color)
                    .frame(width: 24, height: 24)
                    .opacity(isLoading ? 0.6 : 1.0)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(isDestructive ? .red : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(isLoading ? 0.6 : 1.0)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: color))
                } else if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
            .animation(.easeInOut(duration: 0.2), value: isLoading)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            onDismiss: { },
            onReset: { },
            onExport: { nil },
            onImport: { _ in false },
            photosCount: 1250,
            processedCount: 800,
            keptCount: 600,
            deletedCount: 200
        )
    }
} 

#if os(iOS)
// 数据分享组件
struct DataShareSheet: UIViewControllerRepresentable {
    let data: Data
    let fileName: String
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        // 创建一个自定义的活动项提供者
        let activityItem = BackupDataProvider(data: data, fileName: fileName)
        
        let controller = UIActivityViewController(
            activityItems: [activityItem],
            applicationActivities: nil
        )
        
        // 设置分享选项
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .postToVimeo,
            .postToFlickr,
            .postToTencentWeibo
        ]
        
        // iPad适配
        if let popover = controller.popoverPresentationController {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.width / 2, 
                                          y: window.bounds.height / 2, 
                                          width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// 备份数据提供者
class BackupDataProvider: UIActivityItemProvider {
    private let backupData: Data
    private let backupFileName: String
    
    init(data: Data, fileName: String) {
        self.backupData = data
        self.backupFileName = fileName
        super.init(placeholderItem: fileName)
    }
    
    override var item: Any {
        // 创建临时文件用于分享
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(backupFileName)
        
        do {
            try backupData.write(to: tempURL)
            return tempURL
        } catch {
            print("Failed to create temp file for sharing: \(error)")
            return backupData
        }
    }
    
    override func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "Swipe 照片整理數據備份"
    }
    
    override func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "public.json"
    }
}

// iOS Share Sheet 包装器 (保留以备其他用途)
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        
        // 设置分享选项，确保更好的兼容性
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .postToVimeo,
            .postToFlickr,
            .postToTencentWeibo
        ]
        
        // iPad适配
        if let popover = controller.popoverPresentationController {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.width / 2, 
                                          y: window.bounds.height / 2, 
                                          width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif 