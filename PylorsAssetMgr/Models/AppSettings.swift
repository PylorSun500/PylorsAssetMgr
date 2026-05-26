import Foundation
import Observation

enum DirectoryTreeMode: String, CaseIterable {
    case fullFileTree = "full"
    case directoriesWithHint = "hint"

    var displayName: String {
        switch self {
        case .fullFileTree: return "完整文件树"
        case .directoriesWithHint: return "仅目录 + 文件提示"
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    var directoryTreeMode: DirectoryTreeMode {
        didSet {
            UserDefaults.standard.set(directoryTreeMode.rawValue, forKey: "directoryTreeMode")
        }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "directoryTreeMode"),
           let mode = DirectoryTreeMode(rawValue: raw) {
            directoryTreeMode = mode
        } else {
            directoryTreeMode = .directoriesWithHint
        }
    }
}
