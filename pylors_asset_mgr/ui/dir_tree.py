"""目录树侧边栏。"""

import os
import tkinter as tk
from tkinter import ttk
from pathlib import Path
from typing import Callable, Optional


class DirTree(ttk.Frame):
    """左侧目录树导航。"""

    def __init__(self, parent,
                 on_select: Callable[[Path], None],
                 on_double: Optional[Callable[[Path], None]] = None):
        super().__init__(parent)
        self._on_select = on_select
        self._on_double = on_double
        self._workspace_root: Optional[Path] = None

        self.tree = ttk.Treeview(self, show="tree", height=25)
        self.tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        scrollbar = ttk.Scrollbar(self, orient=tk.VERTICAL,
                                  command=self.tree.yview)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        self.tree.configure(yscrollcommand=scrollbar.set)

        # 事件
        self.tree.bind("<<TreeviewSelect>>", self._on_tree_select)
        self.tree.bind("<Double-1>", self._on_tree_double)

    def set_workspace(self, root_path: Path):
        """设置工作区根目录并加载目录树。"""
        self._workspace_root = root_path
        self.tree.delete(*self.tree.get_children())
        self._populate_node("", root_path)

    def _populate_node(self, parent: str, path: Path):
        """递归填充一个节点下的子目录。"""
        try:
            entries = sorted(
                [p for p in path.iterdir()
                 if p.is_dir() and not p.name.startswith(".")
                  and p.name not in (".pylorsthumb",)],
                key=lambda p: p.name.lower()
            )
        except PermissionError:
            return

        for entry in entries[:100]:  # 限制单层数量
            node_id = self.tree.insert(
                parent, tk.END, text=entry.name, values=[str(entry)]
            )
            # 检查是否有子目录（懒加载标记）
            try:
                has_sub = any(
                    p.is_dir() and not p.name.startswith(".")
                    for p in entry.iterdir()
                )
            except PermissionError:
                has_sub = False
            if has_sub:
                self.tree.insert(node_id, tk.END, text="...", tags=("placeholder",))
            self.tree.tag_configure("placeholder", foreground="#ccc")

        # 展开占位符
        self.tree.bind("<<TreeviewOpen>>", self._on_open)

    def _on_open(self, event):
        node = self.tree.focus()
        if not node:
            return
        children = self.tree.get_children(node)
        if len(children) == 1:
            child_text = self.tree.item(children[0], "text")
            if child_text == "...":
                # 删除占位符，填充真实子目录
                self.tree.delete(children[0])
                values = self.tree.item(node, "values")
                if values:
                    path = Path(values[0])
                    self._populate_node(node, path)

    def _on_tree_select(self, event):
        sel = self.tree.selection()
        if not sel:
            return
        values = self.tree.item(sel[0], "values")
        if values:
            self._on_select(Path(values[0]))

    def _on_tree_double(self, event):
        if not self._on_double:
            return
        sel = self.tree.selection()
        if not sel:
            return
        values = self.tree.item(sel[0], "values")
        if values:
            self._on_double(Path(values[0]))
