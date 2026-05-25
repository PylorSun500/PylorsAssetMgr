import Foundation
import ImageIO

actor FileScanner {
    let root: URL

    init(root: URL) {
        self.root = root
    }

    // MARK: - 扫描

    func scan(subdir: URL? = nil, includeHidden: Bool = false) -> [Asset] {
        let base = (subdir ?? root).standardizedFileURL

        guard let enumerator = FileManager.default.enumerator(
            at: base,
            includingPropertiesForKeys: [
                .isDirectoryKey, .fileSizeKey,
                .contentModificationDateKey, .creationDateKey,
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var results: [Asset] = []

        for case let fileURL as URL in enumerator {
            // 跳过特定文件名
            let fileName = fileURL.lastPathComponent
            if Constants.skipNames.contains(fileName) { continue }

            // 深度限制
            let rel = fileURL.path.replacingOccurrences(of: root.path + "/", with: "")
            let depth = rel.components(separatedBy: "/").count - 1
            if depth > Constants.maxScanDepth {
                enumerator.skipDescendants()
                continue
            }

            // 跳过缩略图缓存目录
            if rel.contains(Constants.thumbCacheDir) { continue }

            guard let attrs = try? fileURL.resourceValues(forKeys: [
                .isDirectoryKey, .fileSizeKey,
                .contentModificationDateKey, .creationDateKey,
            ]) else { continue }

            guard let asset = makeSystemAsset(fileURL: fileURL, attrs: attrs) else {
                continue
            }
            results.append(asset)
        }

        return results
    }

    // MARK: - 单文件扫描

    func scanSingle(filePath: String) -> Asset? {
        let fullURL = root.appendingPathComponent(filePath)
        guard let attrs = try? fullURL.resourceValues(forKeys: [
            .isDirectoryKey, .fileSizeKey,
            .contentModificationDateKey, .creationDateKey,
        ]) else { return nil }

        return makeSystemAsset(fileURL: fullURL, attrs: attrs)
    }

    // MARK: - 构建系统标签 Asset

    private func makeSystemAsset(fileURL: URL, attrs: URLResourceValues) -> Asset? {
        let name = fileURL.lastPathComponent
        let isDir = attrs.isDirectory ?? false
        let suffix = isDir ? "" : fileURL.pathExtension.lowercased()
        let stem: String = {
            if isDir { return name }
            let nsName = name as NSString
            let ext = nsName.pathExtension
            return ext.isEmpty ? name : nsName.deletingPathExtension
        }()
        let size = attrs.fileSize ?? 0
        let mtime = attrs.contentModificationDate ?? Date()
        let ctime = attrs.creationDate ?? mtime

        let relPath: String = {
            let abs = fileURL.path
            let rootAbs = root.path
            var rel = abs.replacingOccurrences(of: rootAbs + "/", with: "")
            if rel == rootAbs { rel = "" }
            return rel
        }()

        // 图片尺寸
        var width: Int? = nil
        var height: Int? = nil
        var dimensions: String? = nil
        if !isDir && Constants.supportedImageExtensions.contains("." + suffix) {
            if let dims = imageDimensions(url: fileURL) {
                width = dims.0
                height = dims.1
                dimensions = "\(dims.0)x\(dims.1)"
            }
        }

        return Asset(
            relPath: relPath,
            name: name,
            stem: stem,
            suffix: suffix.isEmpty ? "" : "." + suffix,
            size: size,
            sizeDisplay: formatSize(size),
            ctime: ctime,
            mtime: mtime,
            isDir: isDir,
            width: width,
            height: height,
            dimensions: dimensions,
            thumbnailPath: nil,
            userTags: [:]
        )
    }

    // MARK: - 工具方法

    private func formatSize(_ size: Int) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(size)
        var unitIndex = 0
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        if unitIndex == 0 {
            return "\(Int(value)) B"
        }
        return String(format: "%.1f %@", value, units[unitIndex])
    }

    private func imageDimensions(url: URL) -> (Int, Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        guard let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        return (w, h)
    }
}
