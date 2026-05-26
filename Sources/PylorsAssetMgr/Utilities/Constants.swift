import Foundation

enum Constants {
    // 系统标签键
    static let systemTagKeys: Set<String> = [
        "name", "stem", "suffix", "size", "size_display",
        "ctime", "mtime", "ctime_display", "mtime_display",
        "is_dir", "width", "height", "dimensions",
    ]

    // 系统标签中文列头
    static let systemTagLabels: [String: String] = [
        "name": "文件名", "stem": "名称", "suffix": "格式",
        "size": "大小", "size_display": "大小",
        "ctime": "创建时间", "mtime": "修改时间",
        "ctime_display": "创建时间", "mtime_display": "修改时间",
        "is_dir": "类型", "width": "宽度", "height": "高度",
        "dimensions": "尺寸",
    ]

    // 默认可见列
    static let defaultVisibleColumns = ["name", "suffix", "size_display", "mtime_display"]

    // 跳过扫描的文件名
    static let skipNames: Set<String> = [
        ".DS_Store", ".pylorsmeta.db", "Thumbs.db", ".localized",
    ]

    // 缩略图缓存目录名
    static let thumbCacheDir = ".pylorsthumb"

    // 缩略图尺寸
    static let thumbSize: CGFloat = 128

    // 最大扫描深度
    static let maxScanDepth = 50

    // 用户标签键名校验正则
    static var tagKeyPattern: Regex<AnyRegexOutput> {
        try! Regex("^[a-zA-Z\\u4e00-\\u9fff][a-zA-Z0-9\\u4e00-\\u9fff_-]*$")
    }

    // 常用标签快速添加
    static let commonTagQuickAdd = ["importance", "rating", "category", "author", "project"]

    // 标签预设值快捷项 (key, value, label)
    static let tagQuickValues: [(String, String, String)] = [
        ("importance", "high", "🔴 high"),
        ("importance", "medium", "🟡 medium"),
        ("importance", "low", "🟢 low"),
        ("status", "待审核", "待审核"),
        ("status", "已通过", "已通过"),
    ]

    // 支持的图片扩展名
    static let supportedImageExtensions: Set<String> = [
        ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".tiff", ".tif",
        ".webp", ".ico", ".psd", ".heic", ".heif",
    ]
}
