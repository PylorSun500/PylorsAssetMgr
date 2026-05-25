import GRDB
import Foundation

actor TagStore {
    private let dbQueue: DatabaseQueue

    init(dbPath: String) throws {
        self.dbQueue = try DatabaseQueue(path: dbPath)
        try configureDatabase()
    }

    private nonisolated func configureDatabase() throws {
        try dbQueue.write { db in
            try db.execute(sql: "PRAGMA journal_mode=WAL")
            try db.execute(sql: "PRAGMA foreign_keys=ON")
        }
        try migrate()
    }

    // MARK: - Schema 迁移

    private nonisolated func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS user_tags (
                    id         INTEGER PRIMARY KEY AUTOINCREMENT,
                    file_path  TEXT NOT NULL,
                    key        TEXT NOT NULL,
                    value      TEXT NOT NULL,
                    updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
                    UNIQUE(file_path, key)
                )
            """)
            try db.execute(sql: """
                CREATE INDEX IF NOT EXISTS idx_user_tags_path ON user_tags(file_path)
            """)
            try db.execute(sql: """
                CREATE INDEX IF NOT EXISTS idx_user_tags_key ON user_tags(key)
            """)
            try db.execute(sql: """
                CREATE INDEX IF NOT EXISTS idx_user_tags_kv ON user_tags(key, value)
            """)
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS workspace_config (
                    key   TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                )
            """)
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS tag_key_registry (
                    key        TEXT PRIMARY KEY,
                    created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
                )
            """)
            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS tr_register_tag_key
                AFTER INSERT ON user_tags
                BEGIN
                    INSERT OR IGNORE INTO tag_key_registry (key) VALUES (NEW.key);
                END
            """)
        }
        try migrator.migrate(dbQueue)
    }

    // MARK: - 标签 CRUD

    func getTag(filePath: String, key: String) throws -> String? {
        try dbQueue.read { db in
            try String.fetchOne(db,
                sql: "SELECT value FROM user_tags WHERE file_path = ? AND key = ?",
                arguments: [filePath, key])
        }
    }

    func getAllTags(filePath: String) throws -> [String: String] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db,
                sql: "SELECT key, value FROM user_tags WHERE file_path = ?",
                arguments: [filePath])
            var result: [String: String] = [:]
            for row in rows {
                result[row["key"]] = row["value"]
            }
            return result
        }
    }

    func getBulkTags(filePaths: [String]) throws -> [String: [String: String]] {
        guard !filePaths.isEmpty else { return [:] }
        return try dbQueue.read { db in
            let placeholders = filePaths.map { _ in "?" }.joined(separator: ",")
            let rows = try Row.fetchAll(db,
                sql: "SELECT file_path, key, value FROM user_tags WHERE file_path IN (\(placeholders))",
                arguments: StatementArguments(filePaths))
            var result: [String: [String: String]] = [:]
            for fp in filePaths {
                result[fp] = [:]
            }
            for row in rows {
                let fp: String = row["file_path"]
                let k: String = row["key"]
                let v: String = row["value"]
                result[fp, default: [:]][k] = v
            }
            return result
        }
    }

    func setTag(filePath: String, key: String, value: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO user_tags (file_path, key, value, updated_at)
                VALUES (?, ?, ?, datetime('now','localtime'))
            """, arguments: [filePath, key, value])
        }
    }

    func deleteTag(filePath: String, key: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: """
                DELETE FROM user_tags WHERE file_path = ? AND key = ?
            """, arguments: [filePath, key])
        }
    }

    func batchSetTags(filePaths: [String], key: String, value: String) throws {
        try dbQueue.write { db in
            for fp in filePaths {
                try db.execute(sql: """
                    INSERT OR REPLACE INTO user_tags (file_path, key, value, updated_at)
                    VALUES (?, ?, ?, datetime('now','localtime'))
                """, arguments: [fp, key, value])
            }
        }
    }

    func cleanupStaleTags(validPaths: Set<String>) throws {
        try dbQueue.write { db in
            let rows = try String.fetchAll(db,
                sql: "SELECT DISTINCT file_path FROM user_tags")
            let stale = rows.filter { !validPaths.contains($0) }
            guard !stale.isEmpty else { return }
            let placeholders = stale.map { _ in "?" }.joined(separator: ",")
            try db.execute(sql: """
                DELETE FROM user_tags WHERE file_path IN (\(placeholders))
            """, arguments: StatementArguments(stale))
        }
    }

    // MARK: - 标签键管理

    func getAllKeys() throws -> [String] {
        try dbQueue.read { db in
            try String.fetchAll(db,
                sql: "SELECT key FROM tag_key_registry ORDER BY created_at")
        }
    }

    // MARK: - 工作区配置

    func getConfig(_ key: String, default: String = "") throws -> String {
        try dbQueue.read { db in
            try String.fetchOne(db,
                sql: "SELECT value FROM workspace_config WHERE key = ?",
                arguments: [key]) ?? `default`
        }
    }

    func setConfig(_ key: String, value: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO workspace_config (key, value) VALUES (?, ?)
            """, arguments: [key, value])
        }
    }
}
