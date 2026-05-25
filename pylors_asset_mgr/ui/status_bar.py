import tkinter as tk
from tkinter import ttk


class StatusBar(ttk.Frame):
    """底部状态栏。"""

    def __init__(self, parent):
        super().__init__(parent)
        self.columnconfigure(0, weight=1)

        self._count_label = ttk.Label(self, text="", anchor=tk.W)
        self._count_label.grid(row=0, column=0, sticky=tk.W, padx=(8, 0))

        self._filter_label = ttk.Label(self, text="", anchor=tk.E)
        self._filter_label.grid(row=0, column=1, sticky=tk.E, padx=(0, 8))

        self._path_label = ttk.Label(self, text="", anchor=tk.E)
        self._path_label.grid(row=0, column=2, sticky=tk.E, padx=(0, 8))

    def update_counts(self, shown: int, total: int, filter_str: str = ""):
        if filter_str:
            self._count_label.config(text=f"{shown} 项（共 {total} 项）")
            self._filter_label.config(text=f"筛选: {filter_str}")
        else:
            self._count_label.config(text=f"{total} 个资产")
            self._filter_label.config(text="")

    def update_workspace_path(self, path: str):
        self._path_label.config(text=path)
