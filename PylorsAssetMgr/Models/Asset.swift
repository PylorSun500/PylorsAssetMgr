import Foundation

struct Asset: Identifiable, Sendable {
    // 相对工作区根目录的路径
    let relPath: String
    let name: String
    let stem: String
    let suffix: String
    let size: Int
    let sizeDisplay: String
    let ctime: Date
    let mtime: Date
    let isDir: Bool
    let width: Int?
    let height: Int?
    let dimensions: String?
    let thumbnailPath: String?

    // 用户标签
    var userTags: [String: String]

    var id: String { relPath }

    // 获取标签值：用户标签优先，其次系统标签
    func getTag(_ key: String) -> String? {
        if let val = userTags[key] {
            return val
        }
        return systemTagValue(key)
    }

    private func systemTagValue(_ key: String) -> String? {
        switch key {
        case "name": return name
        case "stem": return stem
        case "suffix": return suffix
        case "size": return String(size)
        case "size_display": return sizeDisplay
        case "ctime": return String(ctime.timeIntervalSince1970)
        case "mtime": return String(mtime.timeIntervalSince1970)
        case "ctime_display": return formatDate(ctime)
        case "mtime_display": return formatDate(mtime)
        case "is_dir": return isDir ? "目录" : "文件"
        case "width": return width.map(String.init)
        case "height": return height.map(String.init)
        case "dimensions": return dimensions
        default: return nil
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }
}
