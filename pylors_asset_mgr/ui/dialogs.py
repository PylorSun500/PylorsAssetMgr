"""通用对话框。"""

import tkinter as tk
from tkinter import ttk
from typing import Callable, Optional


def show_tag_editor(
    parent: tk.Tk,
    asset_name: str,
    tag_key: str,
    current_value: str,
    suggestions: list[str],
    on_confirm: Callable[[str], None],
):
    """弹出单标签编辑对话框。"""
    dialog = tk.Toplevel(parent)
    dialog.title(f"编辑标签 — {tag_key}")
    dialog.geometry("340x180")
    dialog.transient(parent)
    dialog.grab_set()

    ttk.Label(dialog, text=f"资产: {asset_name}").pack(padx=12, pady=(12, 4), anchor=tk.W)
    ttk.Label(dialog, text=f"标签键: {tag_key}").pack(padx=12, anchor=tk.W)

    ttk.Label(dialog, text="值:").pack(padx=12, pady=(8, 0), anchor=tk.W)
    val_var = tk.StringVar(value=current_value)

    if suggestions:
        combo = ttk.Combobox(dialog, textvariable=val_var, values=suggestions)
        combo.pack(padx=12, fill=tk.X)
        combo.focus_set()
    else:
        entry = ttk.Entry(dialog, textvariable=val_var)
        entry.pack(padx=12, fill=tk.X)
        entry.focus_set()

    btn_frame = ttk.Frame(dialog)
    btn_frame.pack(pady=12)

    def ok():
        on_confirm(val_var.get().strip())
        dialog.destroy()

    ttk.Button(btn_frame, text="确定", command=ok).pack(side=tk.LEFT, padx=4)
    ttk.Button(btn_frame, text="取消", command=dialog.destroy).pack(side=tk.LEFT, padx=4)


def show_batch_tag_editor(
    parent: tk.Tk,
    asset_count: int,
    on_confirm: Callable[[str, str], None],
):
    """弹出批量标签编辑对话框。"""
    dialog = tk.Toplevel(parent)
    dialog.title(f"批量编辑标签 — {asset_count} 个资产")
    dialog.geometry("360x200")
    dialog.transient(parent)
    dialog.grab_set()

    ttk.Label(dialog, text=f"为 {asset_count} 个资产设置标签:").pack(
        padx=12, pady=(12, 8))

    ttk.Label(dialog, text="标签键:").pack(padx=12, anchor=tk.W)
    key_var = tk.StringVar()
    key_entry = ttk.Entry(dialog, textvariable=key_var)
    key_entry.pack(padx=12, fill=tk.X)

    ttk.Label(dialog, text="标签值:").pack(padx=12, pady=(8, 0), anchor=tk.W)
    val_var = tk.StringVar()
    val_entry = ttk.Entry(dialog, textvariable=val_var)
    val_entry.pack(padx=12, fill=tk.X)

    btn_frame = ttk.Frame(dialog)
    btn_frame.pack(pady=12)

    def ok():
        k = key_var.get().strip()
        v = val_var.get().strip()
        if k:
            on_confirm(k, v)
        dialog.destroy()

    ttk.Button(btn_frame, text="确定", command=ok).pack(side=tk.LEFT, padx=4)
    ttk.Button(btn_frame, text="取消", command=dialog.destroy).pack(side=tk.LEFT, padx=4)
    key_entry.focus_set()
