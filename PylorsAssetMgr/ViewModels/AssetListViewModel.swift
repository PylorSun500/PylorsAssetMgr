import Foundation
import Observation

@MainActor
@Observable
final class AssetListViewModel {
    private let workspace: Workspace
    private var scanner: FileScanner

    private(set) var allAssets: [Asset] = []
    private(set) var filteredAssets: [Asset] = []
    private(set) var isScanning = false
    private(set) var availableColumns: [TagColumnInfo] = []

    // 排序状态
    var sortKey: String = "name"
    var sortDesc: Bool = false

    // 过滤状态
    private var filters: [FilterEngine.FilterCondition] = []
    var activeFilterStr: String = ""

    // 当前浏览的子目录
    private var currentSubdir: URL? = nil

    // 缓存的可见列键
    private var cachedVisibleKeys: [String] = []
    // 缓存的列宽
    var cachedColumnWidths: [String: CGFloat] = [:]

    init(workspace: Workspace) {
        self.workspace = workspace
        self.scanner = FileScanner(root: workspace.root)
    }

    // MARK: - 核心数据流

    func refresh(subdir: URL? = nil) async {
        isScanning = true
        defer { isScanning = false }

        currentSubdir = subdir

        // 1. 扫描文件系统
        let scanned = await scanner.scan(subdir: subdir)

        // 2. 批量获取用户标签
        let paths = scanned.map(\.relPath)
        let bulkTags: [String: [String: String]]
        do {
            bulkTags = try await workspace.tagStore.getBulkTags(filePaths: paths)
        } catch {
            bulkTags = [:]
        }

        // 3. 合并
        let merged = scanned.map { asset -> Asset in
            var a = asset
            a.userTags = bulkTags[asset.relPath] ?? [:]
            return a
        }
        allAssets = merged

        // 4. 清理过期标签
        try? await workspace.cleanupStaleTags(validPaths: Set(paths))

        // 5. 排序
        sort()

        // 6. 过滤
        applyFilters()

        // 7. 加载列信息
        await loadColumns()
    }

    func activate() async {
        await loadColumns()
    }

    private func loadColumns() async {
        do {
            availableColumns = try await buildAvailableColumns()
            cachedVisibleKeys = try await loadVisibleKeys()
            cachedColumnWidths = try await loadColumnWidths()
        } catch {
            // 使用默认值
            availableColumns = Constants.defaultVisibleColumns.map {
                TagColumnInfo(key: $0, source: .system, defaultVisible: true,
                              humanName: Constants.systemTagLabels[$0] ?? $0)
            }
            cachedVisibleKeys = Constants.defaultVisibleColumns
        }
    }

    // MARK: - 列管理

    private func buildAvailableColumns() async throws -> [TagColumnInfo] {
        var cols: [TagColumnInfo] = []

        for key in Constants.defaultVisibleColumns {
            cols.append(TagColumnInfo(
                key: key, source: .system, defaultVisible: true,
                humanName: Constants.systemTagLabels[key] ?? key
            ))
        }
        for key in ["ctime_display", "dimensions", "is_dir"] {
            if !Constants.defaultVisibleColumns.contains(key) {
                cols.append(TagColumnInfo(
                    key: key, source: .system, defaultVisible: false,
                    humanName: Constants.systemTagLabels[key] ?? key
                ))
            }
        }

        let userKeys = try await workspace.getAllTagKeys()
        let visibleSet = Set(cachedVisibleKeys)

        for k in userKeys {
            cols.append(TagColumnInfo(
                key: k, source: .user, defaultVisible: visibleSet.contains(k),
                humanName: k
            ))
        }

        return cols
    }

    func getVisibleColumnKeys() -> [String] {
        cachedVisibleKeys
    }

    func setVisibleColumns(_ keys: [String]) {
        cachedVisibleKeys = keys
        Task {
            try? await workspace.setConfig("visible_columns", value: keys.joined(separator: ","))
        }
    }

    private func loadVisibleKeys() async throws -> [String] {
        let config = try await workspace.getConfig("visible_columns", default: "")
        if !config.isEmpty {
            var configured = config.components(separatedBy: ",")
            if !configured.contains("name") {
                configured.insert("name", at: 0)
            }
            return configured
        }
        return Constants.defaultVisibleColumns
    }

    func saveColumnWidths(_ json: String) {
        Task {
            try? await workspace.setConfig("column_widths", value: json)
        }
    }

    func loadColumnWidths() async throws -> [String: CGFloat] {
        let json = try await workspace.getConfig("column_widths", default: "")
        guard !json.isEmpty,
              let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        return dict.mapValues { CGFloat($0) }
    }

    // MARK: - 排序

    func sortBy(key: String, descending: Bool? = nil) {
        if let desc = descending {
            sortDesc = desc
        } else if sortKey == key {
            sortDesc.toggle()
        } else {
            sortDesc = false
        }
        sortKey = key
        sort()
        applyFilters()
    }

    private func sort() {
        let key = sortKey
        let desc = sortDesc

        allAssets.sort { a, b in
            let va = a.getTag(key)
            let vb = b.getTag(key)

            switch (va, vb) {
            case (nil, nil): return false
            case (nil, _): return true
            case (_, nil): return false
            case let (va?, vb?):
                if key == "size" {
                    return desc ? a.size > b.size : a.size < b.size
                }
                if key == "ctime" || key == "mtime" {
                    let ta = key == "ctime"
                        ? a.ctime.timeIntervalSince1970 : a.mtime.timeIntervalSince1970
                    let tb = key == "ctime"
                        ? b.ctime.timeIntervalSince1970 : b.mtime.timeIntervalSince1970
                    return desc ? ta > tb : ta < tb
                }
                return desc
                    ? va.localizedStandardCompare(vb) == .orderedDescending
                    : va.localizedStandardCompare(vb) == .orderedAscending
            }
        }
    }

    // MARK: - 过滤

    func applyFilter(_ text: String) {
        activeFilterStr = text
        filters = FilterEngine.parse(text)
        applyFilters()
    }

    func clearFilter() {
        activeFilterStr = ""
        filters = []
        applyFilters()
    }

    private func applyFilters() {
        if filters.isEmpty {
            filteredAssets = allAssets
        } else {
            filteredAssets = allAssets.filter { FilterEngine.matches(asset: $0, filters: filters) }
        }
    }

    var filteredCount: Int { filteredAssets.count }
    var totalCount: Int { allAssets.count }

    // MARK: - 标签编辑

    func updateTag(asset: Asset, key: String, value: String) {
        let path = asset.relPath
        if let idx = allAssets.firstIndex(where: { $0.relPath == path }) {
            allAssets[idx].userTags[key] = value
        }
        if let idx = filteredAssets.firstIndex(where: { $0.relPath == path }) {
            filteredAssets[idx].userTags[key] = value
        }
        Task {
            try? await workspace.setUserTag(relPath: path, key: key, value: value)
        }
    }

    func deleteTag(asset: Asset, key: String) {
        let path = asset.relPath
        if let idx = allAssets.firstIndex(where: { $0.relPath == path }) {
            allAssets[idx].userTags.removeValue(forKey: key)
        }
        if let idx = filteredAssets.firstIndex(where: { $0.relPath == path }) {
            filteredAssets[idx].userTags.removeValue(forKey: key)
        }
        Task {
            try? await workspace.deleteUserTag(relPath: path, key: key)
        }
    }

    func batchUpdateTags(assets: [Asset], key: String, value: String) {
        let paths = assets.map(\.relPath)
        for path in paths {
            if let idx = allAssets.firstIndex(where: { $0.relPath == path }) {
                allAssets[idx].userTags[key] = value
            }
            if let idx = filteredAssets.firstIndex(where: { $0.relPath == path }) {
                filteredAssets[idx].userTags[key] = value
            }
        }
        Task {
            try? await workspace.batchSetTags(relPaths: paths, key: key, value: value)
        }
    }

    // MARK: - 帮助方法

    func getSuggestions(for key: String) -> [String] {
        let values = allAssets.compactMap { $0.userTags[key] }
        let unique = Array(Set(values)).sorted().prefix(20)
        return Array(unique)
    }

    func resolvePath(for asset: Asset) -> URL {
        workspace.root.appendingPathComponent(asset.relPath)
    }

    var workspaceName: String {
        workspace.displayName
    }

    var workspacePath: String {
        workspace.root.path
    }

    /// 暴露 Workspace actor 引用，供设置面板等使用
    var workspaceRef: Workspace {
        workspace
    }
}
