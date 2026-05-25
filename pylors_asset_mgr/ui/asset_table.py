import json
import tkinter as tk
from tkinter import ttk
from typing import Callable, Optional

from pylors_asset_mgr.models.asset import Asset
from pylors_asset_mgr.config import SYSTEM_TAG_LABELS


class AssetTable(ttk.Frame):
    """详情列表视图 — 基于 ttk.Treeview。"""

    def __init__(self, parent,
                 on_sort: Callable[[str], None],
                 on_double_click: Optional[Callable[[Asset, str], None]] = None,
                 on_context: Optional[Callable[[list[Asset], int, int], None]] = None,
                 on_columns_changed: Optional[Callable[[list[str]], None]] = None):
        super().__init__(parent)
        self._on_sort = on_sort
        self._on_double_click = on_double_click
        self._on_context = on_context
        self._on_columns_changed = on_columns_changed
        self._columns: list[str] = []
        self._assets: list[Asset] = []
        self._sort_key: str = "name"
        self._sort_desc: bool = False
        self._col_widths: dict[str, int] = {}

        # Treeview
        self.tree = ttk.Treeview(self, selectmode=tk.EXTENDED,
                                 show="headings", height=25)
        self.tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        # 滚动条
        scrollbar = ttk.Scrollbar(self, orient=tk.VERTICAL,
                                  command=self.tree.yview)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        self.tree.configure(yscrollcommand=scrollbar.set)

        # 事件绑定 — 使用 ButtonRelease-1 避免与列头拖拽冲突
        self.tree.bind("<ButtonRelease-1>", self._on_header_release)
        self.tree.bind("<Double-1>", self._on_cell_double)
        self.tree.bind("<Button-2>" if tk.TkVersion < 8.6 else "<Button-3>",
                       self._on_right_click)

        # 列宽变更回调
        self._header_pressed = False
        self.tree.bind("<Button-1>", self._on_header_press, add=True)

    def set_columns(self, keys: list[str], human_names: dict[str, str] | None = None,
                    widths: dict[str, int] | None = None):
        """设置 Treeview 的列。"""
        self._columns = keys
        self.tree["columns"] = keys

        default_widths = {
            "name": 280, "stem": 180, "suffix": 70, "size_display": 90,
            "mtime_display": 150, "ctime_display": 150, "dimensions": 100,
            "is_dir": 60,
        }
        saved_widths = widths or {}

        for k in keys:
            name = (human_names or {}).get(k, SYSTEM_TAG_LABELS.get(k, k))
            self.tree.heading(k, text=name,
                              command=lambda key=k: self._on_sort(key))
            w = saved_widths.get(k, default_widths.get(k, 120))
            self.tree.column(k, width=w, minwidth=50)

    def populate(self, assets: list[Asset], sort_key: str = "name",
                 sort_desc: bool = False):
        """填充数据到 Treeview。"""
        self._assets = assets
        self._sort_key = sort_key
        self._sort_desc = sort_desc
        self._refresh_rows()

    def _refresh_rows(self):
        self.tree.delete(*self.tree.get_children())
        if not self._assets:
            self.tree.insert("", tk.END, values=[""] * len(self._columns),
                             tags=("empty",))
            self.tree.tag_configure("empty", foreground="#999")
            return
        for asset in self._assets:
            values = [asset.get_tag(k) or "" for k in self._columns]
            tag = "dir" if asset.is_dir else "file"
            self.tree.insert("", tk.END, values=values, tags=(tag,))
        self.tree.tag_configure("dir", foreground="#3b82f6")

    def get_selected_assets(self) -> list[Asset]:
        sel = self.tree.selection()
        if not sel:
            return []
        # 过滤空状态行
        indices = []
        for iid in sel:
            if "empty" not in self.tree.item(iid, "tags"):
                indices.append(self.tree.index(iid))
        return [self._assets[i] for i in indices if 0 <= i < len(self._assets)]

    def get_column_widths(self) -> dict[str, int]:
        """获取当前各列宽度。"""
        widths = {}
        for k in self._columns:
            widths[k] = self.tree.column(k, "width")
        return widths

    def update_cell(self, row_index: int, col_key: str, value: str):
        if 0 <= row_index < len(self._assets):
            col_idx = self._columns.index(col_key) if col_key in self._columns else -1
            if col_idx >= 0:
                children = self.tree.get_children()
                if row_index < len(children):
                    cur_values = list(self.tree.item(children[row_index], "values"))
                    if col_idx < len(cur_values):
                        cur_values[col_idx] = value
                        self.tree.item(children[row_index], values=cur_values)

    # --- 事件处理 ---

    def _on_header_press(self, event):
        region = self.tree.identify("region", event.x, event.y)
        self._header_pressed = (region == "heading")

    def _on_header_release(self, event):
        region = self.tree.identify("region", event.x, event.y)
        if region == "heading" and self._header_pressed:
            col = self.tree.identify_column(event.x)
            col_index = int(col.replace("#", "")) - 1
            if 0 <= col_index < len(self._columns):
                self._on_sort(self._columns[col_index])
        # 列宽可能被拖拽过，通知保存
        if self._on_columns_changed:
            self.root.after(500, self._notify_width_change)
        self._header_pressed = False

    def _notify_width_change(self):
        if self._on_columns_changed:
            self._on_columns_changed(self._columns)

    def _on_cell_double(self, event):
        if not self._on_double_click:
            return
        region = self.tree.identify("region", event.x, event.y)
        if region == "cell":
            col = self.tree.identify_column(event.x)
            row = self.tree.identify_row(event.y)
            if row and col:
                col_idx = int(col.replace("#", "")) - 1
                row_idx = self.tree.index(row)
                if 0 <= col_idx < len(self._columns) and 0 <= row_idx < len(self._assets):
                    self._on_double_click(
                        self._assets[row_idx], self._columns[col_idx]
                    )

    def _on_right_click(self, event):
        region = self.tree.identify("region", event.x, event.y)
        if region == "heading":
            return  # 表头右键由 main_window 处理
        if not self._on_context:
            return
        row = self.tree.identify_row(event.y)
        if row:
            sel = self.tree.selection()
            if row not in sel:
                self.tree.selection_set(row)
            selected = self.get_selected_assets()
            if selected:
                self._on_context(selected, event.x_root, event.y_root)

    # --- 排序指示器 ---

    def show_sort_indicator(self, key: str, desc: bool):
        self._sort_key = key
        self._sort_desc = desc
        for col in self._columns:
            text = SYSTEM_TAG_LABELS.get(col, col)
            if col == key:
                text += " ▼" if desc else " ▲"
            self.tree.heading(col, text=text)
