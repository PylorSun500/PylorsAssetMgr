import tkinter as tk
from tkinter import ttk
from typing import Callable

from pylors_asset_mgr.models.tag_schema import TagColumnInfo, TagSource
from pylors_asset_mgr.config import SYSTEM_TAG_LABELS


class ColumnPicker:
    """列选择器 — 右键表头弹出菜单，勾选显示哪些列。"""

    def __init__(self, parent: tk.Toplevel, columns: list[TagColumnInfo],
                 on_apply: Callable[[list[str]], None]):
        self.top = parent
        self.top.title("选择可见列")
        self.top.geometry("280x400")
        self.top.transient(parent.master.master if hasattr(parent, 'master') else None)
        self.top.grab_set()

        self._on_apply = on_apply
        self._columns = columns
        self._vars: dict[str, tk.BooleanVar] = {}

        # 标签页：系统列 + 用户列
        notebook = ttk.Notebook(self.top)
        notebook.pack(fill=tk.BOTH, expand=True, padx=8, pady=8)

        sys_frame = ttk.Frame(notebook)
        notebook.add(sys_frame, text="系统列")

        user_frame = ttk.Frame(notebook)
        notebook.add(user_frame, text="用户列")

        self._build_list(sys_frame, TagSource.SYSTEM)
        self._build_list(user_frame, TagSource.USER)

        # 新建用户标签键
        new_frame = ttk.Frame(self.top)
        new_frame.pack(fill=tk.X, padx=8, pady=(0, 4))
        self._new_key_var = tk.StringVar()
        ttk.Entry(new_frame, textvariable=self._new_key_var).pack(
            side=tk.LEFT, fill=tk.X, expand=True
        )
        ttk.Button(new_frame, text="+ 新建列",
                   command=self._add_new_key).pack(side=tk.RIGHT, padx=(4, 0))

        # 按钮
        btn_frame = ttk.Frame(self.top)
        btn_frame.pack(pady=(0, 8))
        ttk.Button(btn_frame, text="确定", command=self._apply).pack(side=tk.LEFT, padx=4)
        ttk.Button(btn_frame, text="取消", command=self.top.destroy).pack(side=tk.LEFT, padx=4)

    def _build_list(self, parent: ttk.Frame, source: TagSource):
        canvas = tk.Canvas(parent, highlightthickness=0)
        scrollbar = ttk.Scrollbar(parent, orient=tk.VERTICAL, command=canvas.yview)
        scroll_frame = ttk.Frame(canvas)

        scroll_frame.bind("<Configure>",
                          lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=scroll_frame, anchor=tk.NW)
        canvas.configure(yscrollcommand=scrollbar.set)

        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        cols = [c for c in self._columns if c.source == source]
        for col in cols:
            var = tk.BooleanVar(value=col.default_visible)
            self._vars[col.key] = var
            label = SYSTEM_TAG_LABELS.get(col.key, col.human_name)
            cb = ttk.Checkbutton(scroll_frame, text=f"{label}  ({col.key})",
                                 variable=var)
            cb.pack(anchor=tk.W, padx=4, pady=1)

    def _add_new_key(self):
        name = self._new_key_var.get().strip()
        if name:
            import re
            from pylors_asset_mgr.config import TAG_KEY_PATTERN
            if not TAG_KEY_PATTERN.match(name):
                return
            var = tk.BooleanVar(value=True)
            self._vars[name] = var
            self._columns.append(TagColumnInfo(
                key=name, source=TagSource.USER,
                default_visible=True, human_name=name,
            ))
            self._new_key_var.set("")

    def _apply(self):
        visible = [k for k, v in self._vars.items() if v.get()]
        if "name" not in visible:
            visible.insert(0, "name")
        self._on_apply(visible)
        self.top.destroy()
