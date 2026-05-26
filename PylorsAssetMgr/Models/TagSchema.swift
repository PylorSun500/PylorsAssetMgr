import Foundation

enum TagSource: String, CaseIterable, Codable, Sendable {
    case system
    case user
}

struct TagColumnInfo: Identifiable, Sendable {
    let key: String
    let source: TagSource
    var defaultVisible: Bool = false
    var defaultWidth: Int = 120
    var humanName: String

    var id: String { key }

    init(key: String, source: TagSource, defaultVisible: Bool = false,
         defaultWidth: Int = 120, humanName: String = "") {
        self.key = key
        self.source = source
        self.defaultVisible = defaultVisible
        self.defaultWidth = defaultWidth
        self.humanName = humanName.isEmpty ? key : humanName
    }
}
