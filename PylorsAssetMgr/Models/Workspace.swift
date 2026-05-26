import Foundation

actor Workspace {
    let root: URL
    let dbPath: URL
    let tagStore: TagStore
    let displayName: String

    init(rootPath: String) throws {
        self.root = URL(fileURLWithPath: rootPath).standardizedFileURL
        self.dbPath = root.appendingPathComponent(".pylorsmeta.db")
        self.tagStore = try TagStore(dbPath: dbPath.path)
        self.displayName = root.lastPathComponent
    }

    var isValid: Bool {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: root.path, isDirectory: &isDir) && isDir.boolValue
    }

    // MARK: - 标签操作

    func getUserTags(relPath: String) async throws -> [String: String] {
        try await tagStore.getAllTags(filePath: relPath)
    }

    func setUserTag(relPath: String, key: String, value: String) async throws {
        try await tagStore.setTag(filePath: relPath, key: key, value: value)
    }

    func deleteUserTag(relPath: String, key: String) async throws {
        try await tagStore.deleteTag(filePath: relPath, key: key)
    }

    func getAllTagKeys() async throws -> [String] {
        try await tagStore.getAllKeys()
    }

    func batchSetTags(relPaths: [String], key: String, value: String) async throws {
        try await tagStore.batchSetTags(filePaths: relPaths, key: key, value: value)
    }

    func cleanupStaleTags(validPaths: Set<String>) async throws {
        try await tagStore.cleanupStaleTags(validPaths: validPaths)
    }

    // MARK: - 配置

    func getConfig(_ key: String, default: String = "") async throws -> String {
        try await tagStore.getConfig(key, default: `default`)
    }

    func setConfig(_ key: String, value: String) async throws {
        try await tagStore.setConfig(key, value: value)
    }

    // MARK: - 键管理

    func registerKey(_ key: String) async throws {
        try await tagStore.registerKey(key)
    }

    func deleteKey(_ key: String) async throws {
        try await tagStore.deleteKey(key)
    }

    func renameKey(old: String, new: String) async throws {
        try await tagStore.renameKey(old: old, new: new)
    }

    func getDistinctValues(for key: String) async throws -> [String] {
        try await tagStore.getDistinctValues(for: key)
    }

    func deleteValue(key: String, value: String) async throws {
        try await tagStore.deleteValue(key: key, value: value)
    }
}
