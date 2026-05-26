import SwiftUI

struct TagKeyRowData: Identifiable {
    var id: String { key }
    var key: String
    var isVisible: Bool
    var distinctValues: [String]
}

struct TagManagementPane: View {
    @Environment(WorkspaceViewModel.self) private var workspaceVM
    @State private var tagRows: [TagKeyRowData] = []
    @State private var newKeyName: String = ""
    @State private var isLoading = true
    @State private var selectedKey: String? = nil
    @State private var editingKey: String? = nil
    @State private var editingValues: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("标签管理")
                    .font(.title2).fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 4)

            Text("管理工作区中的用户标签键。切换可见性控制在表格中的显示。")
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .padding(.horizontal, 24).padding(.bottom, 16)

            if isLoading {
                Spacer()
                ProgressView("加载中...").frame(maxWidth: .infinity)
                Spacer()
            } else if tagRows.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "tag.slash").font(.system(size: 28)).foregroundStyle(.tertiary)
                    Text("暂无用户标签").font(.system(size: 13)).foregroundStyle(.secondary)
                    Text("在文件上添加标签后，这里将显示可管理的键。")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                // 表头
                HStack(spacing: 0) {
                    Spacer().frame(width: 24)
                    Text("可见").frame(width: 36, alignment: .center)
                    Text("键名").frame(width: 140, alignment: .leading)
                    Text("值").frame(maxWidth: .infinity, alignment: .leading)
                    Text("").frame(width: 48)
                }
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                .padding(.horizontal, 24).padding(.bottom, 4)

                Divider().padding(.horizontal, 24)

                List(selection: $selectedKey) {
                    ForEach($tagRows) { $row in
                        HStack(spacing: 0) {
                            Toggle("", isOn: Binding(
                                get: { row.isVisible },
                                set: { _ in toggleVisible(row) }
                            ))
                            .toggleStyle(.checkbox)
                            .frame(width: 36, alignment: .center)

                            Text(row.key)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                                .frame(width: 140, alignment: .leading)
                                .onTapGesture(count: 2) { startRename(row) }

                            Button(action: { openValues(row) }) {
                                HStack(spacing: 4) {
                                    if row.distinctValues.isEmpty {
                                        Text("(空)")
                                            .font(.system(size: 11)).foregroundStyle(.tertiary)
                                    } else {
                                        Text(row.distinctValues.prefix(4).joined(separator: ", "))
                                            .font(.system(size: 11)).foregroundStyle(.secondary)
                                            .lineLimit(1)
                                        if row.distinctValues.count > 4 {
                                            Text("…+\(row.distinctValues.count - 4)")
                                                .font(.system(size: 10)).foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            HStack(spacing: 4) {
                                Button { startRename(row) } label: {
                                    Image(systemName: "pencil").font(.system(size: 10))
                                }.buttonStyle(.borderless)
                                Button(role: .destructive) { deleteRow(row) } label: {
                                    Image(systemName: "trash").font(.system(size: 10))
                                }.buttonStyle(.borderless)
                            }
                            .frame(width: 48)
                        }
                        .padding(.vertical, 3)
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                    }
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
            }

            Divider().padding(.horizontal, 24)

            HStack {
                HStack(spacing: 6) {
                    Text("添加新键:").font(.system(size: 12)).foregroundStyle(.secondary)
                    TextField("键名...", text: $newKeyName)
                        .textFieldStyle(.roundedBorder).font(.system(size: 12)).frame(width: 150)
                        .onSubmit { addKey() }
                    Button("添加") { addKey() }
                        .buttonStyle(.bordered).controlSize(.small)
                        .disabled(newKeyName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Spacer()
                Button(role: .destructive) {
                    if let k = selectedKey { deleteRowByKey(k) }
                } label: {
                    Label("删除选中键", systemImage: "trash")
                }
                .buttonStyle(.bordered).controlSize(.small)
                .disabled(selectedKey == nil)
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { load() }
        .onChange(of: workspaceVM.activeIndex) { _, _ in load() }
        .sheet(isPresented: Binding(
            get: { editingKey != nil },
            set: { if !$0 { editingKey = nil } }
        )) {
            if let key = editingKey {
                ValueEditorView(
                    keyName: key,
                    values: editingValues,
                    onSave: { saveValues(for: key, values: $0) },
                    onCancel: { editingKey = nil }
                )
            }
        }
        .alert("重命名标签键", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("新键名", text: $renameText)
            Button("确定") { commitRename() }
            Button("取消", role: .cancel) { renameTarget = nil }
        }
    }

    // MARK: - 重命名状态

    @State private var renameTarget: String? = nil
    @State private var renameText: String = ""

    private func startRename(_ row: TagKeyRowData) {
        renameTarget = row.key
        renameText = row.key
    }

    private func commitRename() {
        guard let old = renameTarget else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != old,
              !tagRows.contains(where: { $0.key == trimmed }) else {
            renameTarget = nil
            return
        }
        renameKey(old: old, new: trimmed)
        renameTarget = nil
    }

    // MARK: - 数据

    private func load() {
        guard let vm = workspaceVM.activeViewModel else {
            tagRows = []; isLoading = false; return
        }
        isLoading = true
        Task {
            let visibleSet = Set(vm.getVisibleColumnKeys())
            let userCols = vm.availableColumns.filter { $0.source == .user }
            var rows: [TagKeyRowData] = []
            for col in userCols {
                let vals = (try? await vm.workspaceRef.getDistinctValues(for: col.key)) ?? []
                rows.append(TagKeyRowData(key: col.key, isVisible: visibleSet.contains(col.key), distinctValues: vals))
            }
            await MainActor.run {
                tagRows = rows; isLoading = false
            }
        }
    }

    // MARK: - 操作

    private func toggleVisible(_ row: TagKeyRowData) {
        guard let vm = workspaceVM.activeViewModel else { return }
        var visible = vm.getVisibleColumnKeys()
        if row.isVisible { visible.removeAll { $0 == row.key } }
        else { visible.append(row.key) }
        vm.setVisibleColumns(visible)
        if let idx = tagRows.firstIndex(where: { $0.key == row.key }) {
            tagRows[idx].isVisible.toggle()
        }
    }

    private func addKey() {
        let name = newKeyName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty,
              (try? Constants.tagKeyPattern.wholeMatch(in: name)) != nil,
              !tagRows.contains(where: { $0.key == name }),
              let vm = workspaceVM.activeViewModel else { return }
        var visible = vm.getVisibleColumnKeys()
        visible.append(name)
        vm.setVisibleColumns(visible)
        tagRows.append(TagKeyRowData(key: name, isVisible: true, distinctValues: []))
        newKeyName = ""
    }

    private func renameKey(old: String, new: String) {
        guard let vm = workspaceVM.activeViewModel else { return }
        Task {
            try? await vm.workspaceRef.renameKey(old: old, new: new)
            await MainActor.run {
                var visible = vm.getVisibleColumnKeys()
                if let idx = visible.firstIndex(of: old) { visible[idx] = new; vm.setVisibleColumns(visible) }
                if let idx = tagRows.firstIndex(where: { $0.key == old }) { tagRows[idx].key = new }
                if selectedKey == old { selectedKey = new }
            }
        }
    }

    private func deleteRow(_ row: TagKeyRowData) { deleteRowByKey(row.key) }

    private func deleteRowByKey(_ key: String) {
        guard let vm = workspaceVM.activeViewModel else { return }
        Task {
            try? await vm.workspaceRef.deleteKey(key)
            await MainActor.run {
                var visible = vm.getVisibleColumnKeys()
                visible.removeAll { $0 == key }; vm.setVisibleColumns(visible)
                tagRows.removeAll { $0.key == key }
                if selectedKey == key { selectedKey = nil }
            }
        }
    }

    private func openValues(_ row: TagKeyRowData) {
        editingValues = row.distinctValues
        editingKey = row.key
    }

    private func saveValues(for key: String, values: [String]) {
        guard let vm = workspaceVM.activeViewModel else { return }
        let oldSet = Set(tagRows.first(where: { $0.key == key })?.distinctValues ?? [])
        let newSet = Set(values)
        let removed = oldSet.subtracting(newSet)
        Task {
            for v in removed { try? await vm.workspaceRef.deleteValue(key: key, value: v) }
            await MainActor.run {
                if let idx = tagRows.firstIndex(where: { $0.key == key }) {
                    tagRows[idx].distinctValues = Array(newSet).sorted()
                }
                editingKey = nil
            }
        }
    }
}

// MARK: - 值编辑弹窗

struct ValueEditorView: View {
    let keyName: String
    let values: [String]
    let onSave: ([String]) -> Void
    let onCancel: () -> Void

    @State private var items: [String] = []
    @State private var newValue: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("编辑「\(keyName)」的值").font(.headline)
            Text("删除值将从所有文件中移除该标签值；新增值需要在文件上设置。")
                .font(.system(size: 11)).foregroundStyle(.secondary)

            List {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, val in
                    HStack {
                        Text(val).font(.system(size: 12))
                        Spacer()
                        Button(role: .destructive) {
                            items.remove(at: idx)
                        } label: {
                            Image(systemName: "trash").font(.system(size: 10))
                        }.buttonStyle(.borderless)
                    }
                    .padding(.vertical, 1)
                }
            }
            .listStyle(.plain).frame(minHeight: 100, maxHeight: 200)

            HStack {
                TextField("新值...", text: $newValue)
                    .textFieldStyle(.roundedBorder).font(.system(size: 12)).frame(width: 160)
                Button("添加") {
                    let t = newValue.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty, !items.contains(t) { items.append(t); newValue = "" }
                }
                .buttonStyle(.bordered).controlSize(.small)
                .disabled(newValue.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            HStack {
                Spacer()
                Button("取消") { onCancel() }.buttonStyle(.bordered).controlSize(.small)
                Button("保存") { onSave(items) }.buttonStyle(.borderedProminent).controlSize(.small)
            }
        }
        .padding().frame(width: 400, height: 380)
        .onAppear { items = values }
    }
}
