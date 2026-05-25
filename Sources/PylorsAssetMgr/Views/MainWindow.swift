import SwiftUI

struct MainWindow: View {
    @Environment(WorkspaceViewModel.self) private var workspaceVM
    @State private var sidebarVisible = true

    var body: some View {
        VStack(spacing: 0) {
            // 标签栏
            TabBar()

            // 过滤栏
            if workspaceVM.activeViewModel != nil {
                FilterBarView()
            }

            // 主内容区
            if sidebarVisible {
                HSplitView {
                    DirTreeView()
                        .frame(minWidth: 160, idealWidth: 200, maxWidth: 320)

                    assetTableArea
                }
            } else {
                assetTableArea
            }

            // 状态栏
            if workspaceVM.activeViewModel != nil {
                StatusBarView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            sidebarVisible.toggle()
        }
    }

    @ViewBuilder
    private var assetTableArea: some View {
        if let vm = workspaceVM.activeViewModel {
            AssetListView(viewModel: vm)
        } else {
            emptyStateView
        }
    }

    private var emptyStateView: some View {
        VStack {
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
