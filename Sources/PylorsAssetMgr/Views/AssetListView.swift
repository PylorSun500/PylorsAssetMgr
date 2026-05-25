import SwiftUI
import AppKit

struct AssetListView: NSViewRepresentable {
    let viewModel: AssetListViewModel

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let tableView = NSTableView()
        tableView.style = .fullWidth
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.allowsColumnReordering = true
        tableView.allowsColumnResizing = true
        tableView.columnAutoresizingStyle = .noColumnAutoresizing

        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.target = context.coordinator
        tableView.doubleAction = #selector(Coordinator.tableViewDoubleClick(_:))
        tableView.menu = context.coordinator.buildMenu()

        scrollView.documentView = tableView
        context.coordinator.tableView = tableView
        context.coordinator.viewModel = viewModel

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tableView = scrollView.documentView as? NSTableView else { return }
        context.coordinator.viewModel = viewModel

        // 仅当列配置变化时重建列
        let currentKeys = tableView.tableColumns.map { $0.identifier.rawValue }
        let newKeys = viewModel.getVisibleColumnKeys()
        if currentKeys != newKeys {
            rebuildColumns(tableView: tableView, keys: newKeys, coordinator: context.coordinator)
        }

        // 更新列宽
        updateColumnWidths(tableView: tableView, context: context)

        // 更新排序指示器
        updateSortIndicator(tableView: tableView)

        tableView.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - 列管理

    private func rebuildColumns(tableView: NSTableView, keys: [String],
                                 coordinator: Coordinator) {
        // 移除旧列
        tableView.tableColumns.forEach { tableView.removeTableColumn($0) }

        let defaultWidths: [String: CGFloat] = [
            "name": 280, "stem": 180, "suffix": 70, "size_display": 90,
            "mtime_display": 150, "ctime_display": 150, "dimensions": 100, "is_dir": 60,
        ]

        let savedWidths = viewModel.cachedColumnWidths

        for key in keys {
            let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(key))
            col.title = Constants.systemTagLabels[key] ?? key
            col.width = savedWidths[key] ?? defaultWidths[key] ?? 120
            col.minWidth = 50
            col.sortDescriptorPrototype = NSSortDescriptor(key: key, ascending: true)
            tableView.addTableColumn(col)
        }
    }

    private func updateColumnWidths(tableView: NSTableView, context: Context) {
        var widths: [String: CGFloat] = [:]
        for col in tableView.tableColumns {
            let key = col.identifier.rawValue
            widths[key] = col.width
        }
        context.coordinator.savedColumnWidths = widths
        // 持久化通知
        context.coordinator.invokeWidthChange()
    }

    private func updateSortIndicator(tableView: NSTableView) {
        for col in tableView.tableColumns {
            let key = col.identifier.rawValue
            var title = Constants.systemTagLabels[key] ?? key
            if key == viewModel.sortKey {
                title += viewModel.sortDesc ? " ▼" : " ▲"
            }
            col.title = title
        }
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        weak var tableView: NSTableView?
        var viewModel: AssetListViewModel?
        var savedColumnWidths: [String: CGFloat] = [:]

        var assets: [Asset] {
            viewModel?.filteredAssets ?? []
        }

        var visibleKeys: [String] {
            viewModel?.getVisibleColumnKeys() ?? []
        }

        // MARK: - NSTableViewDataSource

        func numberOfRows(in tableView: NSTableView) -> Int {
            assets.count
        }

        func tableView(_ tableView: NSTableView,
                       objectValueFor tableColumn: NSTableColumn?,
                       row: Int) -> Any? {
            guard row >= 0, row < assets.count,
                  let key = tableColumn?.identifier.rawValue else { return nil }
            return assets[row].getTag(key) ?? ""
        }

        // MARK: - NSTableViewDelegate

        func tableView(_ tableView: NSTableView,
                       viewFor tableColumn: NSTableColumn?,
                       row: Int) -> NSView? {
            guard let key = tableColumn?.identifier.rawValue,
                  row >= 0, row < assets.count else { return nil }

            let id = NSUserInterfaceItemIdentifier("AssetCell")
            let textField: NSTextField

            if let existing = tableView.makeView(withIdentifier: id, owner: nil) as? NSTextField {
                textField = existing
            } else {
                textField = NSTextField()
                textField.identifier = id
                textField.isBezeled = false
                textField.drawsBackground = false
                textField.isEditable = false
                textField.lineBreakMode = .byTruncatingTail
                textField.font = .systemFont(ofSize: 12)
            }

            let value = assets[row].getTag(key) ?? ""
            textField.stringValue = value

            // 目录着色
            if assets[row].isDir && key == "name" {
                textField.textColor = .systemBlue
            } else {
                textField.textColor = .labelColor
            }

            return textField
        }

        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange
                       oldDescriptors: [NSSortDescriptor]) {
            guard let sortDesc = tableView.sortDescriptors.first,
                  let key = sortDesc.key else { return }
            viewModel?.sortBy(key: key, descending: !sortDesc.ascending)
            tableView.reloadData()
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            // 选择变化由右键菜单处理
        }

        // MARK: - 双击编辑

        @objc func tableViewDoubleClick(_ sender: NSTableView) {
            let row = sender.clickedRow
            let col = sender.clickedColumn
            guard row >= 0, col >= 0,
                  row < assets.count, col < visibleKeys.count,
                  let vm = viewModel else { return }

            let key = visibleKeys[col]
            let asset = assets[row]

            if Constants.systemTagKeys.contains(key) {
                // 系统标签不可编辑
                let alert = NSAlert()
                alert.messageText = "系统标签"
                alert.informativeText = "「\(Constants.systemTagLabels[key] ?? key)」是系统标签，不可编辑。"
                alert.alertStyle = .informational
                alert.runModal()
                return
            }

            // 弹出标签编辑器
            let suggestions = vm.getSuggestions(for: key)
            let current = asset.userTags[key] ?? ""

            guard let window = sender.window else { return }

            let popover = NSPopover()
            popover.behavior = .transient
            popover.contentViewController = NSHostingController(
                rootView: TagEditorPopover(
                    assetName: asset.name,
                    tagKey: key,
                    currentValue: current,
                    suggestions: suggestions,
                    onConfirm: { value in
                        if value.isEmpty {
                            vm.deleteTag(asset: asset, key: key)
                        } else {
                            vm.updateTag(asset: asset, key: key, value: value)
                        }
                        sender.reloadData()
                        popover.close()
                    },
                    onCancel: { popover.close() }
                )
            )

            // 定位 popover 到点击的单元格
            if let cellView = sender.view(atColumn: col, row: row, makeIfNecessary: false) {
                popover.show(relativeTo: cellView.bounds, of: cellView, preferredEdge: .maxY)
            }
        }

        // MARK: - 右键菜单

        func buildMenu() -> NSMenu {
            let menu = NSMenu()
            menu.delegate = self
            return menu
        }

        override func responds(to aSelector: Selector!) -> Bool {
            if aSelector == #selector(openSelectedAssets) ||
               aSelector == #selector(copySelectedPaths) ||
               aSelector == #selector(quickTag(_:)) ||
               aSelector == #selector(batchEditTags) ||
               aSelector == #selector(deleteTag(_:)) {
                return true
            }
            return super.responds(to: aSelector)
        }

        @objc func openSelectedAssets() {
            guard let vm = viewModel else { return }
            for idx in selectedRowIndices() {
                let url = vm.resolvePath(for: assets[idx])
                NSWorkspace.shared.open(url)
            }
        }

        @objc func copySelectedPaths() {
            guard let vm = viewModel else { return }
            let paths = selectedRowIndices().map {
                vm.resolvePath(for: assets[$0]).path
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(paths.joined(separator: "\n"),
                                           forType: .string)
        }

        @objc func quickTag(_ sender: NSMenuItem) {
            guard let vm = viewModel,
                  let tagInfo = sender.representedObject as? (String, String) else { return }
            let indices = selectedRowIndices()
            let selected = indices.map { assets[$0] }
            vm.batchUpdateTags(assets: selected, key: tagInfo.0, value: tagInfo.1)
            tableView?.reloadData()
        }

        @objc func batchEditTags() {
            guard let vm = viewModel, let window = tableView?.window else { return }
            let indices = selectedRowIndices()
            let selected = indices.map { assets[$0] }

            let popover = NSPopover()
            popover.behavior = .transient
            popover.contentViewController = NSHostingController(
                rootView: BatchEditSheet(
                    assetCount: selected.count,
                    onConfirm: { key, value in
                        vm.batchUpdateTags(assets: selected, key: key, value: value)
                        self.tableView?.reloadData()
                        popover.close()
                    },
                    onCancel: { popover.close() }
                )
            )
            popover.show(relativeTo: tableView!.bounds, of: tableView!, preferredEdge: .maxY)
        }

        @objc func deleteTag(_ sender: NSMenuItem) {
            guard let vm = viewModel,
                  let key = sender.representedObject as? String else { return }
            let indices = selectedRowIndices()
            let selected = indices.map { assets[$0] }
            for asset in selected {
                vm.deleteTag(asset: asset, key: key)
            }
            tableView?.reloadData()
        }

        private func selectedRowIndices() -> IndexSet {
            tableView?.selectedRowIndexes ?? IndexSet()
        }

        // MARK: - 列宽变更

        func invokeWidthChange() {
            guard let vm = viewModel else { return }
            var dict: [String: Int] = [:]
            for (key, width) in savedColumnWidths {
                dict[key] = Int(width)
            }
            if let data = try? JSONEncoder().encode(dict),
               let json = String(data: data, encoding: .utf8) {
                vm.saveColumnWidths(json)
            }
        }
    }
}

// MARK: - NSMenuDelegate

extension AssetListView.Coordinator: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let indices = selectedRowIndices()
        if indices.isEmpty { return }

        if indices.count == 1 {
            menu.addItem(NSMenuItem(title: "打开文件",
                                    action: #selector(openSelectedAssets),
                                    keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "复制路径",
                                    action: #selector(copySelectedPaths),
                                    keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "已选 \(indices.count) 个资产",
                                    action: nil, keyEquivalent: ""))
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "批量编辑标签...",
                                action: #selector(batchEditTags),
                                keyEquivalent: ""))

        // importance 快捷标签
        menu.addItem(.separator())
        for (level, label) in [("high", "设为 importance:high"),
                                ("medium", "设为 importance:medium"),
                                ("low", "设为 importance:low")] {
            let item = NSMenuItem(title: label,
                                  action: #selector(quickTag(_:)),
                                  keyEquivalent: "")
            item.representedObject = ("importance", level)
            menu.addItem(item)
        }

        // 已注册的用户标签键
        if let vm = viewModel {
            let keys = vm.availableColumns
                .filter { $0.source == .user && $0.key != "importance" }
                .map(\.key)
            if !keys.isEmpty {
                menu.addItem(.separator())
                for k in keys.prefix(10) {
                    let item = NSMenuItem(title: "删除标签: \(k)",
                                          action: #selector(deleteTag(_:)),
                                          keyEquivalent: "")
                    item.representedObject = k
                    menu.addItem(item)
                }
            }
        }
    }
}
