import Foundation

enum Constants {
    // 系统标签键
    nonisolated static let systemTagKeys: Set<String> = [
        "name", "stem", "suffix", "size", "size_display",
        "ctime", "mtime", "ctime_display", "mtime_display",
        "is_dir", "width", "height", "dimensions",
    ]

    // 系统标签中文列头
    nonisolated static let systemTagLabels: [String: String] = [
        "name": "文件名", "stem": "名称", "suffix": "格式",
        "size": "大小", "size_display": "大小",
        "ctime": "创建时间", "mtime": "修改时间",
        "ctime_display": "创建时间", "mtime_display": "修改时间",
        "is_dir": "类型", "width": "宽度", "height": "高度",
        "dimensions": "尺寸",
    ]

    // 默认可见列
    nonisolated static let defaultVisibleColumns = ["name", "suffix", "size_display", "mtime_display"]

    // 跳过扫描的文件名
    nonisolated static let skipNames: Set<String> = [
        ".DS_Store", ".pylorsmeta.db", "Thumbs.db", ".localized",
    ]

    // 缩略图缓存目录名
    nonisolated static let thumbCacheDir = ".pylorsthumb"

    // 缩略图尺寸
    nonisolated static let thumbSize: CGFloat = 128

    // 最大扫描深度
    nonisolated static let maxScanDepth = 50

    // 用户标签键名校验正则
    nonisolated static let tagKeyPattern: Regex<AnyRegexOutput> =
        try! Regex("^[a-zA-Z\\u4e00-\\u9fff][a-zA-Z0-9\\u4e00-\\u9fff_-]*$")

    // 支持的图片扩展名
    nonisolated static let supportedImageExtensions: Set<String> = [
        ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".tiff", ".tif",
        ".webp", ".ico", ".psd", ".heic", ".heif",
    ]
}
