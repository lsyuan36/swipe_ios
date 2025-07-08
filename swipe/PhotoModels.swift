//
//  PhotoModels.swift
//  swipe
//
//  Created by 賴聖元 on 2025/7/8.
//

import Foundation
import Photos
import SwiftUI

#if os(iOS)
import UIKit
#endif

// 照片狀態枚舉
enum PhotoStatus: String, Codable, CaseIterable {
    case unprocessed  // 未處理
    case kept        // 已保留
    case deleted     // 已刪除
    
    var displayName: String {
        switch self {
        case .unprocessed:
            return "未處理"
        case .kept:
            return "已保留"
        case .deleted:
            return "已刪除"
        }
    }
}

// 照片項目模型
struct PhotoItem: Identifiable {
    let id = UUID()
    let asset: PHAsset
    var status: PhotoStatus = .unprocessed
    var processedDate: Date?
    
    // 從持久化數據創建PhotoItem
    init(from persistentData: PersistentPhotoData, asset: PHAsset) {
        self.asset = asset
        self.status = persistentData.status
        self.processedDate = persistentData.processedDate
    }
    
    // 普通初始化
    init(asset: PHAsset, status: PhotoStatus = .unprocessed, processedDate: Date? = nil) {
        self.asset = asset
        self.status = status
        self.processedDate = processedDate
    }
}

// 可持久化的照片數據模型
struct PersistentPhotoData: Codable, Identifiable {
    let id: String  // 使用 PHAsset 的 localIdentifier
    var status: PhotoStatus
    var processedDate: Date?
    var creationDate: Date // 照片創建日期，用於排序和匹配
    
    init(from photoItem: PhotoItem) {
        self.id = photoItem.asset.localIdentifier
        self.status = photoItem.status
        self.processedDate = photoItem.processedDate
        self.creationDate = photoItem.asset.creationDate ?? Date()
    }
}

// 應用程序狀態的持久化模型
struct PersistentAppState: Codable {
    var photoData: [PersistentPhotoData]
    var currentPhotoIndex: Int
    var lastSavedDate: Date
    var version: String
    
    init() {
        self.photoData = []
        self.currentPhotoIndex = 0
        self.lastSavedDate = Date()
        self.version = "1.0"
    }
}

// PhotoItem 擴展，用於持久化相關操作
extension PhotoItem {
    // 轉換為持久化數據
    func toPersistentData() -> PersistentPhotoData {
        return PersistentPhotoData(from: self)
    }
    
    // 檢查是否已處理
    var isProcessed: Bool {
        return status != .unprocessed
    }
    
    // 獲取狀態顏色
    var statusColor: String {
        switch status {
        case .unprocessed:
            return "orange"
        case .kept:
            return "green"
        case .deleted:
            return "red"
        }
    }
}

// 批量操作擴展
extension Array where Element == PhotoItem {
    // 轉換為持久化數據數組
    func toPersistentData() -> [PersistentPhotoData] {
        return self.map { $0.toPersistentData() }
    }
    
    // 獲取各狀態的照片數量
    func countByStatus() -> [PhotoStatus: Int] {
        var counts: [PhotoStatus: Int] = [:]
        for status in PhotoStatus.allCases {
            counts[status] = self.filter { $0.status == status }.count
        }
        return counts
    }
    
    // 獲取已處理的照片數量
    var processedCount: Int {
        return self.filter { $0.isProcessed }.count
    }
}

// MARK: - 数据持久化管理器

// 数据持久化管理器
class PhotoDataManager: ObservableObject {
    static let shared = PhotoDataManager()
    
    @Published var appState = PersistentAppState()
    @Published var isLoading = false
    @Published var lastSaveDate: Date?
    
    private let documentsDirectory: URL
    private let dataFileName = "photoData.json"
    private let backupFileName = "photoData_backup.json"
    
    // 自动保存定时器
    private var autoSaveTimer: Timer?
    private let autoSaveInterval: TimeInterval = 30 // 30秒自动保存一次
    
    private init() {
        // 获取Documents目录
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, 
                                                     in: .userDomainMask)[0]
        
        // 启动自动保存
        startAutoSave()
        
        // 监听应用进入后台和前台
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        #endif
    }
    
    deinit {
        autoSaveTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 公共接口
    
    /// 保存照片数据（优化版本，避免大数据量阻塞）
    func savePhotoData(_ photos: [PhotoItem], currentIndex: Int = 0) {
        // 对于大数据量，只保存进度，不重新保存整个数组
        if photos.count > 10000 {
            saveProgressOnly(currentIndex: currentIndex)
        } else {
            DispatchQueue.global(qos: .background).async {
                self.performSave(photos: photos, currentIndex: currentIndex)
            }
        }
    }
    
    /// 快速保存进度（不保存整个照片数组）
    func saveProgressOnly(currentIndex: Int) {
        DispatchQueue.main.async {
            self.appState.currentPhotoIndex = currentIndex
            self.appState.lastSavedDate = Date()
        }
        
        // 异步保存到文件，但不更新整个照片数组
        DispatchQueue.global(qos: .utility).async {
            self.saveDataToFile()
        }
    }
    
    /// 加载照片数据
    func loadPhotoData(for assets: [PHAsset]) -> (photos: [PhotoItem], currentIndex: Int) {
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        let loadedState = performLoad()
        let restoredPhotos = restorePhotoItems(from: loadedState.photoData, assets: assets)
        
        DispatchQueue.main.async {
            self.isLoading = false
        }
        
        return (photos: restoredPhotos, currentIndex: min(loadedState.currentPhotoIndex, max(0, restoredPhotos.count - 1)))
    }
    
    /// 获取特定照片的状态
    func getPhotoStatus(for assetIdentifier: String) -> PhotoStatus? {
        return appState.photoData.first { $0.id == assetIdentifier }?.status
    }
    
    /// 更新单个照片状态
    func updatePhotoStatus(_ photoItem: PhotoItem) {
        let persistentData = photoItem.toPersistentData()
        
        DispatchQueue.main.async {
            if let index = self.appState.photoData.firstIndex(where: { $0.id == persistentData.id }) {
                self.appState.photoData[index] = persistentData
            } else {
                self.appState.photoData.append(persistentData)
            }
            
            self.appState.lastSavedDate = Date()
        }
    }
    
    /// 批量更新照片状态（优化版本）
    func updatePhotosStatus(_ photos: [PhotoItem]) {
        // 对于大数据量，使用分批处理避免阻塞主线程
        if photos.count > 10000 {
            updatePhotosStatusBatched(photos)
        } else {
            updatePhotosStatusDirectly(photos)
        }
    }
    
    /// 直接更新照片状态（小数据量）
    private func updatePhotosStatusDirectly(_ photos: [PhotoItem]) {
        let newPersistentData = photos.toPersistentData()
        let newDataDict = Dictionary(uniqueKeysWithValues: newPersistentData.map { ($0.id, $0) })
        
        DispatchQueue.main.async {
            for (id, data) in newDataDict {
                if let index = self.appState.photoData.firstIndex(where: { $0.id == id }) {
                    self.appState.photoData[index] = data
                } else {
                    self.appState.photoData.append(data)
                }
            }
            self.appState.lastSavedDate = Date()
        }
    }
    
    /// 分批更新照片状态（大数据量）
    private func updatePhotosStatusBatched(_ photos: [PhotoItem]) {
        let batchSize = 1000
        let newPersistentData = photos.toPersistentData()
        let newDataDict = Dictionary(uniqueKeysWithValues: newPersistentData.map { ($0.id, $0) })
        
        // 分批处理，避免主线程阻塞
        let dataArray = Array(newDataDict)
        let batches = dataArray.chunked(into: batchSize)
        
        for (batchIndex, batch) in batches.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(batchIndex) * 0.01) {
                for (id, data) in batch {
                    if let index = self.appState.photoData.firstIndex(where: { $0.id == id }) {
                        self.appState.photoData[index] = data
                    } else {
                        self.appState.photoData.append(data)
                    }
                }
                
                // 只在最后一批时更新保存时间
                if batchIndex == batches.count - 1 {
                    self.appState.lastSavedDate = Date()
                }
            }
        }
    }
    
    /// 清理不存在的照片数据
    func cleanupDeletedPhotos(validAssetIdentifiers: Set<String>) {
        DispatchQueue.main.async {
            self.appState.photoData.removeAll { photoData in
                !validAssetIdentifiers.contains(photoData.id)
            }
        }
    }
    
    /// 获取统计信息
    func getStatistics() -> [PhotoStatus: Int] {
        var stats: [PhotoStatus: Int] = [:]
        for status in PhotoStatus.allCases {
            stats[status] = appState.photoData.filter { $0.status == status }.count
        }
        return stats
    }
    
    /// 导出数据（用于备份或分享）
    func exportData() -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(appState)
        } catch {
            print("导出数据失败: \(error)")
            return nil
        }
    }
    
    /// 导入数据（从备份恢复）
    func importData(_ data: Data) -> Bool {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let importedState = try decoder.decode(PersistentAppState.self, from: data)
            
            // 验证数据版本兼容性
            if isVersionCompatible(importedState.version) {
                var updatedState = importedState
                updatedState.lastSavedDate = Date()
                
                DispatchQueue.main.async {
                    self.appState = updatedState
                }
                
                // 立即保存导入的数据
                saveDataToFile()
                return true
            }
        } catch {
            print("导入数据失败: \(error)")
        }
        return false
    }
    
    // MARK: - 私有方法
    
    private func performSave(photos: [PhotoItem], currentIndex: Int) {
        updatePhotosStatus(photos)
        
        DispatchQueue.main.async {
            self.appState.currentPhotoIndex = currentIndex
            self.appState.lastSavedDate = Date()
        }
        
        saveDataToFile()
    }
    
    private func performLoad() -> PersistentAppState {
        return loadDataFromFile() ?? PersistentAppState()
    }
    
    private func saveDataToFile() {
        do {
            let fileURL = documentsDirectory.appendingPathComponent(dataFileName)
            let backupURL = documentsDirectory.appendingPathComponent(backupFileName)
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(appState)
            
            // 先创建备份
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.copyItem(at: fileURL, to: backupURL)
            }
            
            // 保存新数据
            try data.write(to: fileURL)
            
            DispatchQueue.main.async {
                self.lastSaveDate = Date()
            }
            
            print("数据保存成功: \(data.count) bytes")
        } catch {
            print("保存数据失败: \(error)")
            
            // 尝试从备份恢复
            tryRestoreFromBackup()
        }
    }
    
    private func loadDataFromFile() -> PersistentAppState? {
        let fileURL = documentsDirectory.appendingPathComponent(dataFileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("数据文件不存在，使用默认状态")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let loadedState = try decoder.decode(PersistentAppState.self, from: data)
            
            // 验证数据完整性
            if validateDataIntegrity(loadedState) {
                print("数据加载成功: \(loadedState.photoData.count) 张照片")
                return loadedState
            } else {
                print("数据完整性检查失败，尝试从备份恢复")
                return tryLoadFromBackup()
            }
        } catch {
            print("加载数据失败: \(error)")
            return tryLoadFromBackup()
        }
    }
    
    private func tryLoadFromBackup() -> PersistentAppState? {
        let backupURL = documentsDirectory.appendingPathComponent(backupFileName)
        
        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            print("备份文件不存在")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: backupURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let loadedState = try decoder.decode(PersistentAppState.self, from: data)
            print("从备份恢复数据成功")
            return loadedState
        } catch {
            print("从备份恢复数据失败: \(error)")
            return nil
        }
    }
    
    private func tryRestoreFromBackup() {
        let fileURL = documentsDirectory.appendingPathComponent(dataFileName)
        let backupURL = documentsDirectory.appendingPathComponent(backupFileName)
        
        if FileManager.default.fileExists(atPath: backupURL.path) {
            do {
                try FileManager.default.copyItem(at: backupURL, to: fileURL)
                print("从备份恢复文件成功")
            } catch {
                print("从备份恢复文件失败: \(error)")
            }
        }
    }
    
    private func restorePhotoItems(from persistentData: [PersistentPhotoData], assets: [PHAsset]) -> [PhotoItem] {
        // 创建 asset 字典以便快速查找
        let assetDict = Dictionary(uniqueKeysWithValues: assets.map { ($0.localIdentifier, $0) })
        
        // 创建 persistent data 字典
        let persistentDataDict = Dictionary(uniqueKeysWithValues: persistentData.map { ($0.id, $0) })
        
        // 恢复 PhotoItem 数组，保持原有顺序
        return assets.compactMap { asset in
            let photoItem: PhotoItem
            if let persistentData = persistentDataDict[asset.localIdentifier] {
                photoItem = PhotoItem(from: persistentData, asset: asset)
            } else {
                photoItem = PhotoItem(asset: asset)
            }
            return photoItem
        }
    }
    
    private func validateDataIntegrity(_ state: PersistentAppState) -> Bool {
        // 检查基本字段
        guard !state.version.isEmpty else { return false }
        
        // 检查照片数据
        for photoData in state.photoData {
            guard !photoData.id.isEmpty else { return false }
        }
        
        return true
    }
    
    private func isVersionCompatible(_ version: String) -> Bool {
        // 简单的版本兼容性检查
        let supportedVersions = ["1.0"]
        return supportedVersions.contains(version)
    }
    
    // MARK: - 自动保存
    
    private func startAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { _ in
            // 对于大数据量，减少自动保存频率，避免性能问题
            if self.appState.photoData.count > 10000 {
                // 大数据量时，只在需要时保存
                DispatchQueue.global(qos: .utility).async {
                    self.saveDataToFile()
                }
            } else {
                self.saveDataToFile()
            }
        }
    }
    
    #if os(iOS)
    @objc private func appWillResignActive() {
        // 应用进入后台时立即保存
        saveDataToFile()
    }
    
    @objc private func appDidBecomeActive() {
        // 应用重新激活时可以进行数据同步检查
        // 这里可以添加云同步逻辑
    }
    #endif
    
    // MARK: - 调试和维护
    
    func getDataFileSize() -> Int64 {
        let fileURL = documentsDirectory.appendingPathComponent(dataFileName)
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    func clearAllData() {
        DispatchQueue.main.async {
            self.appState = PersistentAppState()
            self.lastSaveDate = nil
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(dataFileName)
        let backupURL = documentsDirectory.appendingPathComponent(backupFileName)
        
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: backupURL)
    }
    
    // MARK: - 数据迁移和版本兼容性
    
    /// 获取应用版本信息
    func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    /// 检查是否需要数据迁移
    func needsMigration() -> Bool {
        let currentVersion = getAppVersion()
        let savedVersion = appState.version
        return currentVersion != savedVersion
    }
    
    /// 执行数据迁移
    func performMigration() -> Bool {
        let currentVersion = getAppVersion()
        let savedVersion = appState.version
        
        print("执行数据迁移: \(savedVersion) -> \(currentVersion)")
        
        // 这里可以添加具体的迁移逻辑
        switch savedVersion {
        case "1.0":
            // 已经是最新版本，无需迁移
            break
        default:
            // 处理未知版本，使用默认迁移策略
            print("未知版本 \(savedVersion)，使用默认迁移策略")
        }
        
        // 更新版本号
        DispatchQueue.main.async {
            self.appState.version = currentVersion
            self.appState.lastSavedDate = Date()
        }
        
        // 保存迁移后的数据
        saveDataToFile()
        
        return true
    }
    
    /// 创建数据备份
    func createManualBackup() -> Bool {
        let timestamp = DateFormatter().string(from: Date())
        let backupFileName = "photoData_manual_backup_\(timestamp).json"
        let backupURL = documentsDirectory.appendingPathComponent(backupFileName)
        
        do {
            if let data = exportData() {
                try data.write(to: backupURL)
                print("手动备份创建成功: \(backupFileName)")
                return true
            }
        } catch {
            print("创建手动备份失败: \(error)")
        }
        
        return false
    }
    
    /// 获取所有备份文件
    func getAvailableBackups() -> [URL] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            return contents.filter { $0.lastPathComponent.contains("backup") && $0.pathExtension == "json" }
        } catch {
            print("获取备份文件列表失败: \(error)")
            return []
        }
    }
    
    /// 从指定备份文件恢复
    func restoreFromBackup(url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            return importData(data)
        } catch {
            print("从备份恢复失败: \(error)")
            return false
        }
    }
    
    /// 获取数据统计信息（用于调试和监控）
    func getDataStatistics() -> [String: Any] {
        let stats: [String: Any] = [
            "totalPhotos": appState.photoData.count,
            "unprocessedCount": appState.photoData.filter { $0.status == .unprocessed }.count,
            "keptCount": appState.photoData.filter { $0.status == .kept }.count,
            "deletedCount": appState.photoData.filter { $0.status == .deleted }.count,
            "currentIndex": appState.currentPhotoIndex,
            "lastSavedDate": appState.lastSavedDate,
            "version": appState.version,
            "dataFileSize": getDataFileSize(),
            "availableBackups": getAvailableBackups().count
        ]
        return stats
    }
    
    /// 验证数据完整性并修复
    func validateAndRepairData() -> Bool {
        var hasChanges = false
        var newCurrentIndex = appState.currentPhotoIndex
        var newPhotoData = appState.photoData
        
        // 检查和修复索引越界
        if appState.currentPhotoIndex >= appState.photoData.count {
            newCurrentIndex = max(0, appState.photoData.count - 1)
            hasChanges = true
        }
        
        // 检查和修复重复的照片数据
        var uniquePhotos: [String: PersistentPhotoData] = [:]
        var duplicateCount = 0
        
        for photoData in appState.photoData {
            if uniquePhotos[photoData.id] == nil {
                uniquePhotos[photoData.id] = photoData
            } else {
                duplicateCount += 1
                hasChanges = true
            }
        }
        
        if hasChanges {
            newPhotoData = Array(uniquePhotos.values)
            
            DispatchQueue.main.async {
                self.appState.photoData = newPhotoData
                self.appState.currentPhotoIndex = newCurrentIndex
                self.appState.lastSavedDate = Date()
            }
            
            saveDataToFile()
            
            print("数据修复完成，移除了 \(duplicateCount) 个重复项")
        }
        
        return hasChanges
    }
}

// MARK: - 数据同步和云存储扩展（为未来功能预留）

extension PhotoDataManager {
    
    /// 检查iCloud可用性
    func isiCloudAvailable() -> Bool {
        if let _ = FileManager.default.ubiquityIdentityToken {
            return true
        }
        return false
    }
    
    /// 准备iCloud同步（预留接口）
    func prepareiCloudSync() {
        // 未来可以实现iCloud Document同步
        print("iCloud同步功能准备中...")
    }
    
    /// 导出数据用于分享
    func exportDataForSharing() -> URL? {
        guard let data = exportData() else { return nil }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("swipe_photo_data_export.json")
        
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("导出数据用于分享失败: \(error)")
            return nil
        }
    }
}

// MARK: - 数组分批处理扩展

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
} 