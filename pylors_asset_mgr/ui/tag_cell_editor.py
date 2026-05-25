"""标签单元格内联编辑器。"""

import tkinter as tk
from tkinter import ttk
from typing import Callable, Optional


class TagCellEditor:
    """在 Treeview 单元格位置弹出编辑覆盖层。"""

    def __init__(self, tree: ttk.Treeview,
                 on_save: Callable[[int, str, str], None]):
        self.tree = tree
        self._on_save = on_save
        self._editor: Optional[ttk.Combobox] = None
        self._editing_row: int = -1
        self._editing_col: str = ""

    def show(self, row_index: int, col_key: str, current_value: str,
             suggestions: list[str] = None, x: int = 0, y: int = 0):
        self.hide()

        self._editing_row = row_index
        self._editing_col = col_key

        self._editor = ttk.Combobox(self.tree) if suggestions else ttk.Entry(self.tree)
        if suggestions:
            self._editor["values"] = suggestions

        self._editor.insert(0, current_value)
        self._editor.place(x=x, y=y, width=180, height=24)
        self._editor.focus_set()
        self._editor.bind("<Return>", lambda e: self._commit())
        self._editor.bind("<Escape>", lambda e: self.hide())
        self._editor.bind("<FocusOut>", lambda e: self._commit())

    def hide(self):
        if self._editor:
            self._editor.destroy()
            self._editor = None
        self._editing_row = -1
        self._editing_col = ""

    def _commit(self):
        if self._editor and self._editing_row >= 0:
            value = self._editor.get().strip()
            self._on_save(self._editing_row, self._editing_col, value)
        self.hide()
