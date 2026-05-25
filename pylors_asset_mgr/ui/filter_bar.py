"""搜索过滤栏组件。"""

import tkinter as tk
from tkinter import ttk
from typing import Callable


class FilterBar(ttk.Frame):
    """顶部搜索/过滤栏。"""

    def __init__(self, parent, on_apply: Callable[[str], None],
                 on_clear: Callable[[], None]):
        super().__init__(parent)

        ttk.Label(self, text="筛选:").pack(side=tk.LEFT, padx=(4, 0))

        self._var = tk.StringVar()
        self._entry = ttk.Entry(self, textvariable=self._var)
        self._entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(4, 4))
        self._entry.bind("<Return>", lambda e: on_apply(self._var.get().strip()))
        self._entry.bind("<Escape>", lambda e: on_clear())

        ttk.Button(self, text="应用",
                   command=lambda: on_apply(self._var.get().strip())).pack(side=tk.LEFT)
        ttk.Button(self, text="清除", command=on_clear).pack(side=tk.LEFT)

        # 快捷键提示
        hint = ttk.Label(self, text="key:value 格式，空格分隔多条件",
                         foreground="#999")
        hint.pack(side=tk.LEFT, padx=(8, 4))

    def set_text(self, text: str):
        self._var.set(text)

    def clear(self):
        self._var.set("")
