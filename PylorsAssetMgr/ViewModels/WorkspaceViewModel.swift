import Foundation
import Observation

@MainActor
@Observable
final class WorkspaceViewModel {
    private(set) var workspaces: [WorkspaceData] = []
    var activeIndex: Int = -1

    struct WorkspaceData: Identifiable {
        let id: UUID = UUID()
        let workspace: Workspace
        let viewModel: AssetListViewModel
        var name: String
        var path: String
    }

    var activeViewModel: AssetListViewModel? {
        guard activeIndex >= 0, activeIndex < workspaces.count else { return nil }
        return workspaces[activeIndex].viewModel
    }

    var tabNames: [String] {
        workspaces.map { $0.name }
    }

    var tabTooltips: [String] {
        workspaces.map { $0.path }
    }

    func openWorkspace(path: String) async {
        // 避免重复打开
        if let existing = workspaces.firstIndex(where: {
            $0.path == path
        }) {
            activeIndex = existing
            return
        }

        do {
            let ws = try Workspace(rootPath: path)
            let vm = AssetListViewModel(workspace: ws)
            await vm.refresh()

            let data = WorkspaceData(
                workspace: ws,
                viewModel: vm,
                name: ws.displayName,
                path: path
            )
            workspaces.append(data)
            activeIndex = workspaces.count - 1
        } catch {
            print("Failed to open workspace: \(error)")
        }
    }

    func selectWorkspace(at index: Int) {
        guard index >= 0, index < workspaces.count else { return }
        activeIndex = index
    }

    func closeWorkspace(at index: Int) async {
        guard index >= 0, index < workspaces.count else { return }
        workspaces.remove(at: index)
        if workspaces.isEmpty {
            activeIndex = -1
        } else if activeIndex >= workspaces.count {
            activeIndex = workspaces.count - 1
        }
    }

    func closeAll() async {
        workspaces.removeAll()
        activeIndex = -1
    }
}
