import SwiftUI
import AppKit

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 启动时将 app 带到前台
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

// MARK: - App

@main
struct PylorsAssetMgrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var workspaceVM = WorkspaceViewModel()

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environment(workspaceVM)
                .frame(minWidth: 800, minHeight: 400)
        }
        .defaultSize(width: 1200, height: 700)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}

            // 文件菜单
            CommandMenu("文件") {
                Button("打开工作区...") {
                    WorkspaceActions.openDialog(workspaceVM: workspaceVM)
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("关闭工作区") {
                    Task { await WorkspaceActions.closeActive(workspaceVM: workspaceVM) }
                }
                .keyboardShortcut("w", modifiers: .command)

                Divider()

                Button("刷新") {
                    Task { await WorkspaceActions.refresh(workspaceVM: workspaceVM) }
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
                    NotificationCenter.default.post(name: .showColumnPicker, object: nil)
                }
                Button("切换侧边栏") {
                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                }
                .keyboardShortcut("b", modifiers: .command)
            }

            // 设置
            CommandGroup(replacing: .appSettings) {
                Button("设置...") {
                    SettingsWindowManager.shared.show(workspaceVM: workspaceVM)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

// MARK: - 菜单操作

@MainActor
enum WorkspaceActions {
    static func openDialog(workspaceVM: WorkspaceViewModel) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "选择工作区目录"
        panel.prompt = "打开"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { @MainActor in
            await workspaceVM.openWorkspace(path: url.path)
        }
    }

    static func closeActive(workspaceVM: WorkspaceViewModel) async {
        guard workspaceVM.activeIndex >= 0 else { return }
        await workspaceVM.closeWorkspace(at: workspaceVM.activeIndex)
    }

    static func refresh(workspaceVM: WorkspaceViewModel) async {
        await workspaceVM.activeViewModel?.refresh()
    }
}

// MARK: - 通知名称

extension Notification.Name {
    static let showColumnPicker = Notification.Name("showColumnPicker")
    static let toggleSidebar = Notification.Name("toggleSidebar")
}
