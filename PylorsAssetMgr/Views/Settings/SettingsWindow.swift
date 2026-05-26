import SwiftUI
import AppKit

enum SettingsTab: String, CaseIterable, Identifiable {
    case view = "视图"
    case tags = "标签"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .view: return "eye"
        case .tags: return "tag"
        }
    }
}

struct SettingsView: View {
    @Environment(WorkspaceViewModel.self) private var workspaceVM
    @State private var selectedTab: SettingsTab = .view

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.iconName)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(140)
        } detail: {
            switch selectedTab {
            case .view:
                ViewSettingsPane()
            case .tags:
                TagManagementPane()
                    .environment(workspaceVM)
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
        .frame(minWidth: 600, minHeight: 420)
    }
}

@MainActor
final class SettingsWindowManager: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowManager()
    private var window: NSWindow?

    private override init() { super.init() }

    func show(workspaceVM: WorkspaceViewModel) {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            return
        }

        let hostingView = NSHostingView(
            rootView: SettingsView().environment(workspaceVM)
        )
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 450),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false)
        w.title = "设置"
        w.contentView = hostingView
        w.center()
        w.isReleasedWhenClosed = false
        w.delegate = self
        window = w
        w.makeKeyAndOrderFront(nil)
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            SettingsWindowManager.shared.window = nil
        }
    }
}
