import SwiftUI

struct TabBar: View {
    @Environment(WorkspaceViewModel.self) private var workspaceVM

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(workspaceVM.workspaces.enumerated()), id: \.element.id) { index, ws in
                    TabButton(
                        name: ws.name,
                        isActive: workspaceVM.activeIndex == index,
                        onSelect: {
                            workspaceVM.selectWorkspace(at: index)
                        },
                        onClose: {
                            Task {
                                await workspaceVM.closeWorkspace(at: index)
                            }
                        }
                    )
                }

                // 添加按钮
                Button {
                    openWorkspaceDialog()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 36)
        .background(Color(nsColor: .controlBackgroundColor))
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
}

private struct TabButton: View {
    let name: String
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(displayName)
                .font(.system(size: 12))
                .lineLimit(1)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive
                    ? Color(nsColor: .selectedControlColor)
                    : Color.clear)
        )
        .onTapGesture { onSelect() }
        .help(name)
    }

    private var displayName: String {
        name.count <= 20 ? name : String(name.prefix(17)) + "..."
    }
}
