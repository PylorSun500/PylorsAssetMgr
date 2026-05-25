import SwiftUI

struct DirTreeView: View {
    @Environment(WorkspaceViewModel.self) private var workspaceVM
    @State private var rootNode: FileNode?

    var body: some View {
        Group {
            if let node = rootNode {
                List {
                    OutlineGroup(node, children: \.children) { item in
                        Label(
                            title: { Text(item.name)
                                .font(.system(size: 12)) },
                            icon: {
                                Image(systemName: item.children?.isEmpty == false
                                      ? "folder.fill" : "folder")
                                    .foregroundStyle(.secondary)
                            }
                        )
                        .onTapGesture {
                            selectNode(item)
                        }
                    }
                }
                .listStyle(.sidebar)
            } else {
                Text("无工作区")
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: workspaceVM.activeIndex) { _, _ in
            loadRoot()
        }
        .onAppear { loadRoot() }
    }

    private func loadRoot() {
        guard let vm = workspaceVM.activeViewModel else {
            rootNode = nil
            return
        }
        let root = vm.workspacePath
        let url = URL(fileURLWithPath: root)
        rootNode = buildTree(from: url, depth: 0)
    }

    private func buildTree(from url: URL, depth: Int) -> FileNode {
        let name = url.lastPathComponent
        var node = FileNode(name: name, path: url.path, children: nil)

        guard depth < 3 else { return node }  // 初始仅加载 3 层

        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return node }

        let dirs = contents.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        .filter {
            let n = $0.lastPathComponent
            return !n.hasPrefix(".") && n != Constants.thumbCacheDir
        }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent)
                  == .orderedAscending }
        .prefix(100)

        if !dirs.isEmpty {
            node.children = dirs.map { buildTree(from: $0, depth: depth + 1) }
        }

        return node
    }

    private func selectNode(_ node: FileNode) {
        let url = URL(fileURLWithPath: node.path)
        Task {
            await workspaceVM.activeViewModel?.refresh(subdir: url)
        }
    }
}

// MARK: - FileNode 模型

struct FileNode: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    var children: [FileNode]?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: FileNode, rhs: FileNode) -> Bool { lhs.id == rhs.id }
}
