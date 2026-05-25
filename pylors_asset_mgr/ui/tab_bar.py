import tkinter as tk
from tkinter import ttk
from typing import Callable, Optional


class TabBar(ttk.Frame):
    """工作区标签栏 — 类似浏览器标签页。"""

    def __init__(self, parent, on_select: Callable[[int], None],
                 on_close: Callable[[int], None],
                 on_new: Callable[[], None]):
        super().__init__(parent)
        self._on_select = on_select
        self._on_close = on_close
        self._on_new = on_new
        self._tabs: list[dict] = []
        self._active_index: int = -1

        # 使用 Frame 承载按钮行
        self._tabs_frame = ttk.Frame(self)
        self._tabs_frame.pack(side=tk.LEFT, fill=tk.X, expand=True)

        self._add_btn = ttk.Button(self, text="+", width=3, command=self._on_new)
        self._add_btn.pack(side=tk.RIGHT, padx=(2, 4))

    def add_tab(self, name: str, tooltip: str = "") -> int:
        index = len(self._tabs)
        frame = ttk.Frame(self._tabs_frame)
        frame.pack(side=tk.LEFT, padx=0)

        label_text = name if len(name) <= 20 else name[:17] + "..."
        btn = ttk.Label(frame, text=label_text, padding=(8, 4),
                        relief=tk.RAISED)
        btn.pack(side=tk.LEFT)
        btn.bind("<Button-1>", lambda e, i=index: self.select_tab(i))
        btn.bind("<Button-3>", lambda e, i=index: self._on_close(i))

        close_btn = ttk.Label(frame, text=" ×", padding=(2, 4),
                              foreground="#888")
        close_btn.pack(side=tk.LEFT)
        close_btn.bind("<Button-1>", lambda e, i=index: self._on_close(i))

        self._tabs.append({
            "frame": frame,
            "label": btn,
            "close": close_btn,
            "name": name,
            "tooltip": tooltip,
        })
        self.select_tab(index)
        return index

    def remove_tab(self, index: int):
        if 0 <= index < len(self._tabs):
            self._tabs[index]["frame"].destroy()
            del self._tabs[index]
            if index == self._active_index:
                if self._tabs:
                    self.select_tab(min(index, len(self._tabs) - 1))
                else:
                    self._active_index = -1

    def select_tab(self, index: int):
        if 0 <= index < len(self._tabs):
            self._active_index = index
            for i, tab in enumerate(self._tabs):
                tab["label"].configure(
                    relief=tk.SUNKEN if i == index else tk.RAISED
                )
            self._on_select(index)

    def update_tab_name(self, index: int, name: str):
        if 0 <= index < len(self._tabs):
            self._tabs[index]["name"] = name
            label_text = name if len(name) <= 20 else name[:17] + "..."
            self._tabs[index]["label"].configure(text=label_text)

    def rename_current(self, name: str):
        if self._active_index >= 0:
            self.update_tab_name(self._active_index, name)

    @property
    def active_index(self) -> int:
        return self._active_index

    @property
    def tab_count(self) -> int:
        return len(self._tabs)
