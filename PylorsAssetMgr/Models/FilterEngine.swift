import Foundation

enum FilterEngine {
    // 匹配 key:value 或 key:"quoted value" 或 bare text
    private static var pattern: Regex<(Substring, Substring?, Substring?, Substring?, Substring?)> {
        /(\w+):(?:(?:"(.+?)")|([^\s]+)|)|(\S+)/
    }

    static let anyKey = "__any__"

    struct FilterCondition: Sendable {
        let key: String
        let value: String
    }

    static func parse(_ input: String) -> [FilterCondition] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var result: [FilterCondition] = []
        for match in trimmed.matches(of: pattern) {
            let key = match.1.map(String.init)
            let quoted = match.2.map(String.init)
            let unquoted = match.3.map(String.init)
            let bare = match.4.map(String.init)

            if let k = key {
                let v = quoted ?? unquoted ?? ""
                result.append(FilterCondition(key: k, value: v))
            } else if let b = bare {
                result.append(FilterCondition(key: anyKey, value: b))
            }
        }
        return result
    }

    static func matches(asset: Asset, filters: [FilterCondition]) -> Bool {
        guard !filters.isEmpty else { return true }
        return filters.allSatisfy { matchSingle(asset: asset, filter: $0) }
    }

    private static func matchSingle(asset: Asset, filter: FilterCondition) -> Bool {
        if filter.key == anyKey {
            let query = filter.value.lowercased()
            // 模糊搜索系统标签
            for key in ["name", "suffix", "size_display", "dimensions"] {
                if let tv = asset.getTag(key), tv.lowercased().contains(query) {
                    return true
                }
            }
            // 搜索用户标签值
            for uv in asset.userTags.values {
                if uv.lowercased().contains(query) {
                    return true
                }
            }
            return false
        }

        guard let tagVal = asset.getTag(filter.key) else {
            return filter.value.isEmpty
        }
        return wildcardMatch(text: tagVal, pattern: filter.value)
    }

    private static func wildcardMatch(text: String, pattern: String) -> Bool {
        if pattern.contains("*") || pattern.contains("?") {
            let p = pattern.lowercased()
            let t = text.lowercased()
            // 简单 glob 匹配
            let regexPattern = "^" + NSRegularExpression.escapedPattern(for: p)
                .replacingOccurrences(of: "\\*", with: ".*")
                .replacingOccurrences(of: "\\?", with: ".") + "$"
            return t.range(of: regexPattern, options: .regularExpression) != nil
        }
        return text.lowercased().contains(pattern.lowercased())
    }
}
