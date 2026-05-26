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

        // 自定义表头
        let headerView = CustomHeaderView()
        headerView.onAddTag = { [weak tableView] in
            guard let tv = tableView, let coord = tv.delegate as? Coordinator else { return }
            coord.showAddTagPopover(relativeTo: headerView.addButton)
        }
        headerView.onHeaderMenu = { [weak tableView] col, key in
            guard let tv = tableView, let coord = tv.delegate as? Coordinator else { return nil }
            return coord.headerMenu(for: col, key: key)
        }
        tableView.headerView = headerView

        scrollView.documentView = tableView
        context.coordinator.tableView = tableView
        context.coordinator.viewModel = viewModel

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tableView = scrollView.documentView as? NSTableView else { return }
        context.coordinator.viewModel = viewModel

        let currentKeys = tableView.tableColumns.map { $0.identifier.rawValue }
        let newKeys = viewModel.getVisibleColumnKeys()
        if currentKeys != newKeys {
            rebuildColumns(tableView: tableView, keys: newKeys, coordinator: context.coordinator)
        }

        updateColumnWidths(tableView: tableView, context: context)
        updateSortIndicator(tableView: tableView)

        tableView.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - 列管理

    private func rebuildColumns(tableView: NSTableView, keys: [String],
                                 coordinator: Coordinator) {
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

        func tableViewSelectionDidChange(_ notification: Notification) {}

        // MARK: - 双击

        @objc func tableViewDoubleClick(_ sender: NSTableView) {
            let row = sender.clickedRow
            let col = sender.clickedColumn
            guard row >= 0, col >= 0,
                  row < assets.count, col < visibleKeys.count,
                  let vm = viewModel else { return }

            let key = visibleKeys[col]
            let asset = assets[row]

            // 系统标签 → 打开文件
            if Constants.systemTagKeys.contains(key) {
                let url = vm.resolvePath(for: asset)
                NSWorkspace.shared.open(url)
                return
            }

            // 用户标签 → 弹出标签编辑器
            let suggestions = vm.getSuggestions(for: key)
            let current = asset.userTags[key] ?? ""

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

            if let cellView = sender.view(atColumn: col, row: row, makeIfNecessary: false) {
                popover.show(relativeTo: cellView.bounds, of: cellView, preferredEdge: .maxY)
            }
        }

        // MARK: - 列标题右键菜单

        func headerMenu(for column: Int, key: String) -> NSMenu? {
            let menu = NSMenu()

            let hideItem = NSMenuItem(
                title: "隐藏「\(Constants.systemTagLabels[key] ?? key)」",
                action: #selector(hideColumn(_:)), keyEquivalent: "")
            hideItem.target = self
            hideItem.representedObject = key
            menu.addItem(hideItem)

            menu.addItem(.separator())

            let addTagItem = NSMenuItem(
                title: "添加用户标签列...",
                action: #selector(showAddTagSheet(_:)), keyEquivalent: "")
            addTagItem.target = self
            menu.addItem(addTagItem)

            menu.addItem(.separator())

            let pickerItem = NSMenuItem(
                title: "选择可见列...", action: #selector(showColumnPicker(_:)), keyEquivalent: "")
            pickerItem.target = self
            menu.addItem(pickerItem)

            return menu
        }

        @objc private func hideColumn(_ sender: NSMenuItem) {
            guard let key = sender.representedObject as? String,
                  let vm = viewModel else { return }
            var current = vm.getVisibleColumnKeys()
            current.removeAll { $0 == key }
            vm.setVisibleColumns(current)
        }

        @objc private func showAddTagSheet(_ sender: NSMenuItem) {
            guard let vm = viewModel, let tv = tableView,
                  let window = tv.window else { return }

            let sheetWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 180),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false)
            sheetWindow.title = "添加用户标签"

            let hostingView = NSHostingView(
                rootView: QuickAddTagView(
                    existingKeys: vm.availableColumns.map(\.key),
                    onAdd: { key in
                        var current = vm.getVisibleColumnKeys()
                        if !current.contains(key) {
                            current.append(key)
                            vm.setVisibleColumns(current)
                        }
                        window.endSheet(sheetWindow)
                    },
                    onCancel: {
                        window.endSheet(sheetWindow)
                    }
                )
            )
            hostingView.frame.size = NSSize(width: 320, height: 180)
            sheetWindow.contentView = hostingView

            window.beginSheet(sheetWindow)
        }

        @objc private func showColumnPicker(_ sender: NSMenuItem) {
            NotificationCenter.default.post(name: .showColumnPicker, object: nil)
        }

        func showAddTagPopover(relativeTo view: NSView?) {
            guard let tv = tableView, let vm = viewModel,
                  let anchor = view ?? tv.headerView else { return }

            let popover = NSPopover()
            popover.behavior = .transient
            popover.contentViewController = NSHostingController(
                rootView: QuickAddTagView(
                    existingKeys: vm.availableColumns.map(\.key),
                    onAdd: { key in
                        var current = vm.getVisibleColumnKeys()
                        if !current.contains(key) {
                            current.append(key)
                            vm.setVisibleColumns(current)
                        }
                        popover.close()
                    },
                    onCancel: { popover.close() }
                )
            )
            popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxY)
        }

        // MARK: - 右键菜单

        func buildMenu() -> NSMenu {
            let menu = NSMenu()
            menu.delegate = self
            return menu
        }

        // MARK: - 文件操作

        @objc func openSelectedAssets() {
            guard let vm = viewModel else { return }
            for idx in selectedRowIndices() {
                let url = vm.resolvePath(for: assets[idx])
                NSWorkspace.shared.open(url)
            }
        }

        @objc func showSelectedInFinder() {
            guard let vm = viewModel else { return }
            let urls = selectedRowIndices().map { vm.resolvePath(for: assets[$0]) }
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        }

        @objc func copySelectedFiles() {
            guard let vm = viewModel else { return }
            let urls = selectedRowIndices().map { vm.resolvePath(for: assets[$0]) }
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.writeObjects(urls as [NSURL])
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

        @objc func deleteSelectedAssets() {
            guard let vm = viewModel else { return }
            let indices = selectedRowIndices()
            let selected = indices.map { assets[$0] }
            guard !selected.isEmpty else { return }

            let alert = NSAlert()
            if selected.count == 1 {
                alert.messageText = "删除文件"
                alert.informativeText = "确定要将「\(selected[0].name)」移到废纸篓吗？"
            } else {
                alert.messageText = "删除文件"
                alert.informativeText = "确定要将 \(selected.count) 个文件移到废纸篓吗？"
            }
            alert.alertStyle = .warning
            alert.addButton(withTitle: "移到废纸篓")
            alert.addButton(withTitle: "取消")

            guard alert.runModal() == .alertFirstButtonReturn else { return }

            let urls = selected.map { vm.resolvePath(for: $0) }
            for url in urls {
                do {
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                } catch {
                    NSWorkspace.shared.recycle([url])
                }
            }
            Task {
                await vm.refresh()
            }
        }

        @objc func renameSelectedAsset() {
            guard let vm = viewModel, let tv = tableView else { return }
            let row = tv.clickedRow
            guard row >= 0, row < assets.count else { return }
            let asset = assets[row]
            let url = vm.resolvePath(for: asset)

            let alert = NSAlert()
            alert.messageText = "重命名"
            alert.informativeText = "输入新名称："
            alert.alertStyle = .informational
            alert.addButton(withTitle: "确定")
            alert.addButton(withTitle: "取消")

            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            input.stringValue = asset.name
            alert.accessoryView = input

            guard alert.runModal() == .alertFirstButtonReturn,
                  !input.stringValue.isEmpty,
                  input.stringValue != asset.name else { return }

            let newURL = url.deletingLastPathComponent()
                .appendingPathComponent(input.stringValue)
            do {
                try FileManager.default.moveItem(at: url, to: newURL)
                Task { await vm.refresh() }
            } catch {
                let errAlert = NSAlert(error: error)
                errAlert.runModal()
            }
        }

        @objc func openWithApp(_ sender: NSMenuItem) {
            guard let vm = viewModel,
                  let appURL = sender.representedObject as? URL else { return }
            let indices = selectedRowIndices()
            if indices.count == 1 {
                let url = vm.resolvePath(for: assets[indices.first!])
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config)
            }
        }

        // MARK: - 标签操作

        @objc func addTagToSelected(_ sender: NSMenuItem) {
            guard let vm = viewModel,
                  let key = sender.representedObject as? String else { return }
            let indices = selectedRowIndices()
            let selected = indices.map { assets[$0] }
            showBatchTagPopover(key: key, assets: selected)
        }

        private func showBatchTagPopover(key: String, assets: [Asset]) {
            guard let tv = tableView, let vm = viewModel else { return }
            let popover = NSPopover()
            popover.behavior = .transient
            popover.contentViewController = NSHostingController(
                rootView: BatchEditSheet(
                    assetCount: assets.count,
                    onConfirm: { k, value in
                        vm.batchUpdateTags(assets: assets, key: k, value: value)
                        self.tableView?.reloadData()
                        popover.close()
                    },
                    onCancel: { popover.close() }
                )
            )
            popover.show(relativeTo: tv.bounds, of: tv, preferredEdge: .maxY)
        }

        @objc func batchEditTags() {
            guard let vm = viewModel, let tv = tableView else { return }
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
            popover.show(relativeTo: tv.bounds, of: tv, preferredEdge: .maxY)
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

        // MARK: - 列宽

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

// MARK: - NSMenuDelegate (右键菜单构建)

extension AssetListView.Coordinator: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let indices = selectedRowIndices()
        guard !indices.isEmpty, let vm = viewModel else { return }

        // ---- 文件操作 ----
        if indices.count == 1 {
            let asset = assets[indices.first!]
            menu.addItem(NSMenuItem(title: "打开「\(asset.name)」",
                                    action: #selector(openSelectedAssets),
                                    keyEquivalent: ""))

            // "打开方式" 子菜单
            let openWithItem = NSMenuItem(title: "打开方式", action: nil, keyEquivalent: "")
            let openWithMenu = NSMenu()
            let url = vm.resolvePath(for: asset)
            let apps = NSWorkspace.shared.urlsForApplications(toOpen: url)
            if apps.isEmpty {
                openWithMenu.addItem(
                    NSMenuItem(title: "（无可用应用）", action: nil, keyEquivalent: ""))
            } else {
                for appURL in apps.prefix(15) {
                    let appName = appURL.deletingPathExtension().lastPathComponent
                    let item = NSMenuItem(
                        title: appName, action: #selector(openWithApp(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = appURL
                    item.image = NSWorkspace.shared.icon(forFile: appURL.path)
                    openWithMenu.addItem(item)
                }
                openWithMenu.addItem(.separator())
                let browseItem = NSMenuItem(
                    title: "其他...", action: #selector(openSelectedAssets), keyEquivalent: "")
                browseItem.target = self
                openWithMenu.addItem(browseItem)
            }
            openWithItem.submenu = openWithMenu
            menu.addItem(openWithItem)

            menu.addItem(NSMenuItem(title: "在访达中显示",
                                    action: #selector(showSelectedInFinder),
                                    keyEquivalent: ""))

            menu.addItem(.separator())

            menu.addItem(NSMenuItem(title: "复制",
                                    action: #selector(copySelectedFiles),
                                    keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "复制路径",
                                    action: #selector(copySelectedPaths),
                                    keyEquivalent: ""))

            menu.addItem(.separator())

            menu.addItem(NSMenuItem(title: "重命名...",
                                    action: #selector(renameSelectedAsset),
                                    keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "移到废纸篓",
                                    action: #selector(deleteSelectedAssets),
                                    keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "已选 \(indices.count) 个文件",
                                    action: nil, keyEquivalent: ""))
            menu.addItem(.separator())

            menu.addItem(NSMenuItem(title: "在访达中显示",
                                    action: #selector(showSelectedInFinder),
                                    keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "复制",
                                    action: #selector(copySelectedFiles),
                                    keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "复制路径",
                                    action: #selector(copySelectedPaths),
                                    keyEquivalent: ""))

            menu.addItem(.separator())

            let deleteItem = NSMenuItem(title: "移到废纸篓 (\(indices.count) 个文件)",
                                        action: #selector(deleteSelectedAssets),
                                        keyEquivalent: "")
            deleteItem.target = self
            menu.addItem(deleteItem)
        }

        // ---- 标签操作 ----
        menu.addItem(.separator())

        // "添加标签" 子菜单
        let userKeys = vm.availableColumns.filter { $0.source == .user }.map(\.key)
        let currentUserTags = indices.count == 1
            ? Set(assets[indices.first!].userTags.keys)
            : Set<String>()

        let addTagItem = NSMenuItem(title: "添加标签...", action: nil, keyEquivalent: "")
        let addTagSub = NSMenu()

        // 已有用户标签键
        let availableUserKeys = userKeys.filter { !currentUserTags.contains($0) }
        if !availableUserKeys.isEmpty {
            for k in availableUserKeys.prefix(15) {
                let item = NSMenuItem(title: k,
                                      action: #selector(addTagToSelected(_:)),
                                      keyEquivalent: "")
                item.target = self
                item.representedObject = k
                addTagSub.addItem(item)
            }
        } else if indices.count == 1 {
            addTagSub.addItem(
                NSMenuItem(title: "（全部已设置）", action: nil, keyEquivalent: ""))
        }
        addTagItem.submenu = addTagSub
        menu.addItem(addTagItem)

        // "移除标签" 子菜单
        if indices.count == 1 && !currentUserTags.isEmpty {
            let removeTagItem = NSMenuItem(title: "移除标签", action: nil, keyEquivalent: "")
            let removeTagSub = NSMenu()
            for k in currentUserTags.sorted().prefix(15) {
                let item = NSMenuItem(title: k,
                                      action: #selector(deleteTag(_:)),
                                      keyEquivalent: "")
                item.target = self
                item.representedObject = k
                removeTagSub.addItem(item)
            }
            removeTagItem.submenu = removeTagSub
            menu.addItem(removeTagItem)
        }

        let batchItem = NSMenuItem(title: "批量编辑标签...",
                                    action: #selector(batchEditTags),
                                    keyEquivalent: "")
        batchItem.target = self
        menu.addItem(batchItem)
    }
}

// MARK: - 共享视图

struct QuickAddTagView: View {
    @State private var tagKey = ""
    let existingKeys: [String]
    let onAdd: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("添加用户标签列")
                .font(.headline)
            TextField("输入标签名称", text: $tagKey)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .onSubmit { commit() }
            if !tagKey.isEmpty && existingKeys.contains(tagKey) {
                Text("该标签已存在，添加后将设为可见")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("取消", action: onCancel)
                Button("添加") { commit() }
                    .keyboardShortcut(.return)
                    .disabled(tagKey.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
    }

    func commit() {
        let trimmed = tagKey.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed)
    }
}

// MARK: - CustomHeaderView

final class CustomHeaderView: NSTableHeaderView {
    var onAddTag: (() -> Void)?
    var onHeaderMenu: ((Int, String) -> NSMenu?)?

    let addButton: NSButton = {
        let btn = NSButton()
        btn.title = ""
        btn.image = NSImage(
            systemSymbolName: "plus",
            accessibilityDescription: "添加列")
        btn.bezelStyle = .smallSquare
        btn.isBordered = false
        btn.toolTip = "添加用户标签列"
        return btn
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(addButton)
        addButton.target = self
        addButton.action = #selector(addTagAction)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func layout() {
        super.layout()
        let btnSize: CGFloat = 22
        addButton.frame = NSRect(
            x: bounds.width - btnSize - 4,
            y: (bounds.height - btnSize) / 2,
            width: btnSize,
            height: btnSize
        )
    }

    @objc private func addTagAction() {
        onAddTag?()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let tableView = tableView else { return nil }
        let point = convert(event.locationInWindow, from: nil)
        let column = self.column(at: point)
        guard column >= 0, column < tableView.tableColumns.count else { return nil }
        let key = tableView.tableColumns[column].identifier.rawValue
        return onHeaderMenu?(column, key)
    }
}
