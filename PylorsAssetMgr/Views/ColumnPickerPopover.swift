import SwiftUI

struct ColumnPickerPopover: View {
    @Environment(WorkspaceViewModel.self) private var workspaceVM

    let onDismiss: () -> Void

    @State private var systemColumns: [ColumnCheck] = []
    @State private var userColumns: [ColumnCheck] = []
    @State private var newKeyName: String = ""

    struct ColumnCheck: Identifiable {
        let key: String
        let humanName: String
        let source: TagSource
        var isVisible: Bool
        var id: String { key }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("选择可见列")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            TabView {
                // 系统列
                VStack {
                    List($systemColumns) { $col in
                        Toggle(isOn: $col.isVisible) {
                            Text("\(col.humanName)  (\(col.key))")
                                .font(.system(size: 12))
                        }
                    }
                }
                .tabItem { Text("系统列") }

                // 用户列
                VStack {
                    List($userColumns) { $col in
                        Toggle(isOn: $col.isVisible) {
                            Text(col.humanName)
                                .font(.system(size: 12))
                        }
                    }
                }
                .tabItem { Text("用户列") }
            }
            .frame(height: 200)

            // 新建用户标签键
            HStack {
                TextField("新键名", text: $newKeyName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))

                Button("+ 新建") {
                    addNewKey()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(newKeyName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            // 按钮
            HStack {
                Spacer()
                Button("取消") { onDismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Button("确定") {
                    apply()
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 300, height: 400)
        .onAppear { loadColumns() }
    }

    private func loadColumns() {
        guard let vm = workspaceVM.activeViewModel else { return }
        let cols = vm.availableColumns
        systemColumns = cols
            .filter { $0.source == .system }
            .map { ColumnCheck(key: $0.key, humanName: $0.humanName,
                              source: $0.source, isVisible: $0.defaultVisible) }
        userColumns = cols
            .filter { $0.source == .user }
            .map { ColumnCheck(key: $0.key, humanName: $0.humanName,
                              source: $0.source, isVisible: $0.defaultVisible) }
    }

    private func addNewKey() {
        let name = newKeyName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        guard (try? Constants.tagKeyPattern.wholeMatch(in: name)) != nil else { return }

        userColumns.append(ColumnCheck(key: name, humanName: name,
                                        source: .user, isVisible: true))
        newKeyName = ""
    }

    private func apply() {
        var visible = systemColumns.filter(\.isVisible).map(\.key)
        visible += userColumns.filter(\.isVisible).map(\.key)
        if !visible.contains("name") {
            visible.insert("name", at: 0)
        }
        workspaceVM.activeViewModel?.setVisibleColumns(visible)
    }
}
