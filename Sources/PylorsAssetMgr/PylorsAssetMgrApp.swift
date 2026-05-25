import SwiftUI

@main
struct PylorsAssetMgrApp: App {
    @State private var workspaceVM = WorkspaceViewModel()

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environment(workspaceVM)
                .frame(minWidth: 800, minHeight: 400)
        }
        .defaultSize(width: 1200, height: 700)
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .commands {
            // 移除 New 菜单
            CommandGroup(replacing: .newItem) {}

            // 文件菜单
            CommandMenu("文件") {
                Button("打开工作区...") {
                    openWorkspaceDialog()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("关闭工作区") {
                    Task { await closeActiveWorkspace() }
                }
                .keyboardShortcut("w", modifiers: .command)

                Divider()

                Button("刷新") {
                    Task { await refreshActiveWorkspace() }
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }

            // 视图菜单
            CommandMenu("视图") {
                Button("选择可见列...") {
                    // 通过通知触发
                    NotificationCenter.default.post(name: .showColumnPicker, object: nil)
                }
                Button("切换侧边栏") {
                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                }
                .keyboardShortcut("b", modifiers: .command)

                Divider()

                Button("刷新") {
                    Task { await refreshActiveWorkspace() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }

    private func openWorkspaceDialog() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "选择工作区目录"
        panel.prompt = "打开"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            await workspaceVM.openWorkspace(path: url.path)
        }
    }

    private func closeActiveWorkspace() async {
        guard workspaceVM.activeIndex >= 0 else { return }
        await workspaceVM.closeWorkspace(at: workspaceVM.activeIndex)
    }

    private func refreshActiveWorkspace() async {
        await workspaceVM.activeViewModel?.refresh()
    }
}

// MARK: - 通知名称

extension Notification.Name {
    static let showColumnPicker = Notification.Name("showColumnPicker")
    static let toggleSidebar = Notification.Name("toggleSidebar")
}
