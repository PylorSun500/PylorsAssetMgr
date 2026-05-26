import SwiftUI

struct StatusBarView: View {
    @Environment(WorkspaceViewModel.self) private var workspaceVM

    var body: some View {
        HStack {
            // 资产计数
            if let vm = workspaceVM.activeViewModel {
                Text(statusText(vm: vm))
                    .font(.system(size: 11))
            }

            Spacer()

            // 过滤条件
            if let vm = workspaceVM.activeViewModel, !vm.activeFilterStr.isEmpty {
                Text("筛选: \(vm.activeFilterStr)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // 工作区路径
            if let ws = workspaceVM.activeViewModel?.workspaceName {
                Text(ws)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func statusText(vm: AssetListViewModel) -> String {
        if vm.activeFilterStr.isEmpty {
            return "\(vm.totalCount) 个资产"
        } else {
            return "\(vm.filteredCount) 项（共 \(vm.totalCount) 项）"
        }
    }
}
