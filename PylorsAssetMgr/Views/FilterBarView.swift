import SwiftUI

struct FilterBarView: View {
    @Environment(WorkspaceViewModel.self) private var workspaceVM
    @State private var text: String = ""

    var body: some View {
        HStack(spacing: 8) {
            Text("筛选:")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            TextField("key:value 格式，空格分隔多条件", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .onSubmit {
                    applyFilter()
                }

            Button("应用") {
                applyFilter()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("清除") {
                clearFilter()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text("key:value 格式，空格分隔多条件")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .onReceive(
            NotificationCenter.default.publisher(for: .filterTextUpdate)
        ) { notification in
            if let filterStr = notification.object as? String {
                text = filterStr
            }
        }
    }

    private func applyFilter() {
        workspaceVM.activeViewModel?.applyFilter(text.trimmingCharacters(in: .whitespaces))
    }

    private func clearFilter() {
        text = ""
        workspaceVM.activeViewModel?.clearFilter()
    }
}

extension Notification.Name {
    static let filterTextUpdate = Notification.Name("filterTextUpdate")
}
