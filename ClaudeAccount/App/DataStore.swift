import Foundation
import SwiftData
import SQLite3

/// 应用专属的 SwiftData 存储配置。
///
/// 不能依赖 SwiftData 的默认存储位置：macOS 上非沙盒 app 的默认位置是
/// Application Support 根目录下的 default.store，所有使用默认位置的
/// app（包括系统进程 icloudmailagent）会共享同一个文件，后打开的一方
/// 会迁移 schema 并抹掉先打开一方的数据。这里固定使用专属子目录。
enum DataStore {
    static let storeURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("ClaudeAccountFee/default.store", isDirectory: false)
    }()

    /// 旧版本使用的共享默认位置（与 icloudmailagent 等冲突的位置）
    private static let legacySharedStoreURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("default.store", isDirectory: false)
    }()

    static func makeContainer() -> ModelContainer {
        let schema = Schema([ClaudeAccount.self, SubscriptionRecord.self])
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // 存储损坏等极端情况：备份后重建空库，保证应用可以启动
            let backup = storeURL.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).bak")
            try? FileManager.default.moveItem(at: storeURL, to: backup)
            return try! ModelContainer(for: schema, configurations: [configuration])
        }
    }

    /// 旧版本升级时，把共享位置的库搬到专属目录（仅当旧库确实是本应用的 schema）
    static func migrateLegacyStoreIfNeeded() {
        let fileManager = FileManager.default
        let folder = storeURL.deletingLastPathComponent()
        guard !fileManager.fileExists(atPath: storeURL.path),
              fileManager.fileExists(atPath: legacySharedStoreURL.path),
              isOwnStore(at: legacySharedStoreURL)
        else { return }

        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: legacySharedStoreURL.path + suffix)
            let target = URL(fileURLWithPath: storeURL.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            try? fileManager.moveItem(at: source, to: target)
        }
    }

    private static func isOwnStore(at url: URL) -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { return false }
        defer { sqlite3_close(db) }
        let sql = "SELECT 1 FROM sqlite_master WHERE type='table' AND name='ZCLAUDEACCOUNT' LIMIT 1"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(statement) }
        return sqlite3_step(statement) == SQLITE_ROW
    }
}
