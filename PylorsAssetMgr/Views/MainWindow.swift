import SwiftUI

struct MainWindow: View {
    @Environment(WorkspaceViewModel.self) private var workspaceVM

    var body: some View {
        VStack(spacing: 0) {
            // 标签栏
            TabBar()

            if let _ = workspaceVM.activeViewModel {
                NavigationSplitView {
                    // 侧边栏 — 目录树
                    DirTreeView()
                        .frame(minWidth: 160, idealWidth: 200, maxWidth: 320)
                        .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 320)
                } detail: {
                    // 右侧内容区
                    VStack(spacing: 0) {
                        AssetListView(viewModel: workspaceVM.activeViewModel!)
                            .layoutPriority(1)

                        // 筛选栏 — 在文件列表底部
                        FilterBarView()
                    }
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                emptyStateView
            }

            // 状态栏
            StatusBarView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            // NavigationSplitView 自动处理 sidebar toggle
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("打开一个工作区开始")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Cmd+O 或 文件 → 打开工作区")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
