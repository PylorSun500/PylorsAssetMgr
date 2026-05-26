import SwiftUI
import AppKit

// MARK: - DirTreeView (NSViewRepresentable)

struct DirTreeView: NSViewRepresentable {
    @Environment(WorkspaceViewModel.self) private var workspaceVM

    func makeCoordinator() -> Coordinator {
        Coordinator(workspaceVM: workspaceVM)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.indentationPerLevel = 14
        outlineView.style = .sourceList
        outlineView.allowsEmptySelection = true
        outlineView.autosaveExpandedItems = false
        outlineView.floatsGroupRows = false

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        col.resizingMask = .autoresizingMask
        outlineView.addTableColumn(col)
        outlineView.outlineTableColumn = col

        outlineView.dataSource = context.coordinator
        outlineView.delegate = context.coordinator

        context.coordinator.outlineView = outlineView
        context.coordinator.loadRoot()

        let scrollView = NSScrollView()
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.workspaceVM = workspaceVM
        context.coordinator.checkAndReload()
    }
}

// MARK: - DirTreeNode

final class DirTreeNode: NSObject {
    let name: String
    let url: URL
    let isDirectory: Bool
    var children: [DirTreeNode]?
    var childrenLoaded = false

    init(name: String, url: URL, isDirectory: Bool) {
        self.name = name
        self.url = url
        self.isDirectory = isDirectory
    }

    var isLeaf: Bool { !isDirectory }

    func loadChildren() {
        guard isDirectory, !childrenLoaded else { return }
        childrenLoaded = true

        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: [.skipsHiddenFiles]
        ) else {
            children = []
            return
        }

        let dirs = contents.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        .filter {
            let n = $0.lastPathComponent
            return !n.hasPrefix(".") && n != Constants.thumbCacheDir
        }
        .sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }

        children = dirs.map {
            DirTreeNode(name: $0.lastPathComponent, url: $0, isDirectory: true)
        }
    }
}

// MARK: - Coordinator

extension DirTreeView {

    @MainActor
    final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        var workspaceVM: WorkspaceViewModel
        weak var outlineView: NSOutlineView?
        var rootNodes: [DirTreeNode] = []
        private var currentRootPath: String?

        init(workspaceVM: WorkspaceViewModel) {
            self.workspaceVM = workspaceVM
        }

        func checkAndReload() {
            let newPath = workspaceVM.activeViewModel?.workspacePath
            guard newPath != currentRootPath else { return }
            currentRootPath = newPath
            loadRoot()
        }

        func loadRoot() {
            guard let vm = workspaceVM.activeViewModel else {
                rootNodes = []
                outlineView?.reloadData()
                return
            }
            let rootURL = URL(fileURLWithPath: vm.workspacePath)
            let node = DirTreeNode(name: rootURL.lastPathComponent, url: rootURL, isDirectory: true)
            node.loadChildren()
            rootNodes = [node]
            outlineView?.reloadData()
            outlineView?.expandItem(node)
        }

        // MARK: - NSOutlineViewDataSource

        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            if item == nil { return rootNodes.count }
            guard let node = item as? DirTreeNode else { return 0 }
            if !node.childrenLoaded { node.loadChildren() }
            return node.children?.count ?? 0
        }

        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            if item == nil { return rootNodes[index] }
            guard let node = item as? DirTreeNode else { return rootNodes[index] }
            return node.children![index]
        }

        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            guard let node = item as? DirTreeNode else { return false }
            return !node.isLeaf
        }

        // MARK: - NSOutlineViewDelegate

        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let node = item as? DirTreeNode else { return nil }
            let id = NSUserInterfaceItemIdentifier("DirCell")

            let cell: NSTableCellView
            if let reused = outlineView.makeView(withIdentifier: id, owner: self) as? NSTableCellView {
                cell = reused
            } else {
                cell = NSTableCellView()
                cell.identifier = id

                let textField = NSTextField(labelWithString: "")
                textField.font = .systemFont(ofSize: 12)
                cell.textField = textField
                cell.addSubview(textField)

                let imageView = NSImageView()
                imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
                cell.imageView = imageView
                cell.addSubview(imageView)

                imageView.translatesAutoresizingMaskIntoConstraints = false
                textField.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                    imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    imageView.widthAnchor.constraint(equalToConstant: 16),
                    imageView.heightAnchor.constraint(equalToConstant: 16),
                    textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 4),
                    textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                ])
            }

            cell.textField?.stringValue = node.name

            let expanded = outlineView.isItemExpanded(item)
            let iconName = node.isDirectory
                ? (expanded ? "folder.fill" : "folder")
                : "doc"
            cell.imageView?.image = NSImage(
                systemSymbolName: iconName,
                accessibilityDescription: nil
            )
            cell.imageView?.contentTintColor = .secondaryLabelColor

            return cell
        }

        func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
            let id = NSUserInterfaceItemIdentifier("DirRow")
            if let reused = outlineView.makeView(withIdentifier: id, owner: self) as? DirTableRowView {
                return reused
            }
            let rowView = DirTableRowView()
            rowView.identifier = id
            return rowView
        }

        func outlineView(_ outlineView: NSOutlineView, heightOfRow item: Any) -> CGFloat {
            22
        }

        func outlineViewSelectionDidChange(_ notification: Notification) {
            guard let outlineView = outlineView,
                  outlineView.selectedRow >= 0,
                  let node = outlineView.item(atRow: outlineView.selectedRow) as? DirTreeNode else { return }
            Task {
                await workspaceVM.activeViewModel?.refresh(subdir: node.url)
            }
        }

        // MARK: - 右键菜单

        func buildContextMenu() -> NSMenu? {
            guard let outlineView = outlineView,
                  outlineView.clickedRow >= 0,
                  let _ = outlineView.item(atRow: outlineView.clickedRow) as? DirTreeNode else { return nil }

            let menu = NSMenu()

            let openItem = NSMenuItem(
                title: "打开", action: #selector(ctxOpen), keyEquivalent: "")
            openItem.target = self
            menu.addItem(openItem)

            let showItem = NSMenuItem(
                title: "在访达中显示", action: #selector(ctxShowInFinder), keyEquivalent: "")
            showItem.target = self
            menu.addItem(showItem)

            menu.addItem(.separator())

            let copyItem = NSMenuItem(
                title: "复制路径", action: #selector(ctxCopyPath), keyEquivalent: "")
            copyItem.target = self
            menu.addItem(copyItem)

            return menu
        }

        private var clickedItem: DirTreeNode? {
            guard let outlineView = outlineView, outlineView.clickedRow >= 0 else { return nil }
            return outlineView.item(atRow: outlineView.clickedRow) as? DirTreeNode
        }

        @objc private func ctxOpen() {
            guard let node = clickedItem else { return }
            NSWorkspace.shared.open(node.url)
        }

        @objc private func ctxShowInFinder() {
            guard let node = clickedItem else { return }
            NSWorkspace.shared.activateFileViewerSelecting([node.url])
        }

        @objc private func ctxCopyPath() {
            guard let node = clickedItem else { return }
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(node.url.path, forType: .string)
        }
    }
}

// MARK: - DirTableRowView

private final class DirTableRowView: NSTableRowView {
    override func menu(for event: NSEvent) -> NSMenu? {
        guard let outlineView = superview as? NSOutlineView else { return nil }
        let point = outlineView.convert(event.locationInWindow, from: nil)
        let row = outlineView.row(at: point)
        guard row >= 0 else { return nil }

        // 右键时先选中该行
        if outlineView.selectedRow != row {
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }

        guard let coordinator = outlineView.delegate as? DirTreeView.Coordinator else { return nil }
        return coordinator.buildContextMenu()
    }
}
