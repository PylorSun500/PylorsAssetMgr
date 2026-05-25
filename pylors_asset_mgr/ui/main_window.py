import json
import subprocess
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from pathlib import Path
from typing import Optional

from pylors_asset_mgr.core.workspace import Workspace
from pylors_asset_mgr.core.asset_view import AssetView
from pylors_asset_mgr.models.asset import Asset
from pylors_asset_mgr.config import SYSTEM_TAG_LABELS, SYSTEM_TAG_KEYS
from .tab_bar import TabBar
from .asset_table import AssetTable
from .status_bar import StatusBar
from .filter_bar import FilterBar
from .dir_tree import DirTree
from .column_picker import ColumnPicker
from .context_menu import build_context_menu
from .dialogs import show_tag_editor, show_batch_tag_editor


def _detect_dark_mode() -> bool:
    """检测 macOS 是否处于暗色模式。"""
    try:
        result = subprocess.run(
            ["defaults", "read", "-g", "AppleInterfaceStyle"],
            capture_output=True, text=True, timeout=2
        )
        return result.stdout.strip() == "Dark"
    except Exception:
        return False


class MainWindow:
    """主应用窗口。"""

    def __init__(self):
        self.root = tk.Tk()
        self.root.title("PylorsAssetMgr")
        self.root.geometry("1200x700")

        # 尝试设定最小窗口尺寸
        self.root.minsize(800, 400)

        self._workspaces: list[Workspace] = []
        self._views: list[AssetView] = []
        self._active_index: int = -1
        self._dir_visible: bool = True
        self._dark_mode: bool = _detect_dark_mode()

        self._apply_theme()
        self._build_menu()
        self._build_ui()
        self._bind_shortcuts()

        self.root.protocol("WM_DELETE_WINDOW", self._on_quit)

    def _apply_theme(self):
        """应用系统主题。macOS ttk 默认跟随 Aqua，此处做额外调整。"""
        if self._dark_mode:
            # macOS Aqua 暗色下 ttk 自动跟随，仅需调整自定样式
            bg = "#1e1e1e"
            fg = "#d4d4d4"
        else:
            bg = "#f5f5f5"
            fg = "#1e1e1e"

        style = ttk.Style()
        style.configure("TFrame", background=bg)
        style.configure("TLabel", background=bg, foreground=fg)
        style.configure("TButton", background=bg)

    def _build_menu(self):
        menubar = tk.Menu(self.root)
        self.root.config(menu=menubar)

        file_menu = tk.Menu(menubar, tearoff=0)
        file_menu.add_command(label="打开工作区...",
                              command=self._open_workspace,
                              accelerator="Cmd+O")
        file_menu.add_command(label="关闭工作区",
                              command=self._close_current_workspace,
                              accelerator="Cmd+W")
        file_menu.add_separator()
        file_menu.add_command(label="刷新",
                              command=self._refresh_current,
                              accelerator="Cmd+R")
        file_menu.add_separator()
        file_menu.add_command(label="退出", command=self._on_quit,
                              accelerator="Cmd+Q")
        menubar.add_cascade(label="文件", menu=file_menu)

        view_menu = tk.Menu(menubar, tearoff=0)
        view_menu.add_command(label="选择可见列...",
                              command=self._show_column_picker)
        view_menu.add_command(label="切换侧边栏",
                              command=self._toggle_sidebar,
                              accelerator="Cmd+B")
        view_menu.add_separator()
        view_menu.add_command(label="刷新", command=self._refresh_current,
                              accelerator="Cmd+R")
        menubar.add_cascade(label="视图", menu=view_menu)

    def _build_ui(self):
        # 标签栏
        self.tab_bar = TabBar(
            self.root,
            on_select=self._on_tab_select,
            on_close=self._on_tab_close,
            on_new=self._open_workspace,
        )
        self.tab_bar.pack(fill=tk.X)

        # 过滤栏
        self.filter_bar = FilterBar(
            self.root,
            on_apply=self._apply_filter,
            on_clear=self._clear_filter,
        )
        self.filter_bar.pack(fill=tk.X, padx=4, pady=(2, 0))

        # 主内容区域：PanedWindow（侧边栏 + 资产表格）
        self._paned = ttk.PanedWindow(self.root, orient=tk.HORIZONTAL)
        self._paned.pack(fill=tk.BOTH, expand=True, padx=4, pady=(2, 2))

        # 左侧目录树
        self.dir_tree = DirTree(
            self._paned,
            on_select=self._on_dir_select,
        )
        self._paned.add(self.dir_tree, weight=0)

        # 右侧资产表格
        self.asset_table = AssetTable(
            self._paned,
            on_sort=self._on_sort,
            on_double_click=self._on_cell_double,
            on_context=self._on_context_menu,
            on_columns_changed=self._on_column_widths_changed,
        )
        self._paned.add(self.asset_table, weight=1)

        # 列头右键 → 列选择器
        self.asset_table.tree.bind(
            "<Button-2>" if tk.TkVersion < 8.6 else "<Button-3>",
            self._on_header_right_click, add=True
        )

        # 状态栏
        self.status_bar = StatusBar(self.root)
        self.status_bar.pack(fill=tk.X, side=tk.BOTTOM)

    def _bind_shortcuts(self):
        root = self.root
        root.bind("<Command-o>", lambda e: self._open_workspace())
        root.bind("<Command-O>", lambda e: self._open_workspace())
        root.bind("<Command-w>", lambda e: self._close_current_workspace())
        root.bind("<Command-r>", lambda e: self._refresh_current())
        root.bind("<Command-b>", lambda e: self._toggle_sidebar())
        root.bind("<Command-q>", lambda e: self._on_quit())

    # --- 工作区管理 ---

    def _open_workspace(self):
        path_str = filedialog.askdirectory(title="选择工作区目录")
        if not path_str:
            return
        root_path = Path(path_str).resolve()
        ws = Workspace(root_path)
        ws.initialize()

        view = AssetView(ws)
        view.refresh()

        self._workspaces.append(ws)
        self._views.append(view)

        index = self.tab_bar.add_tab(ws.display_name, str(ws.root))
        self._activate_workspace(index)

    def _activate_workspace(self, index: int):
        self._active_index = index
        view = self._views[index]
        ws = self._workspaces[index]

        # 目录树
        self.dir_tree.set_workspace(ws.root)

        # 列 + 恢复列宽
        col_keys = view.get_visible_column_keys()
        col_widths = self._load_column_widths(ws)
        self.asset_table.set_columns(col_keys, SYSTEM_TAG_LABELS, col_widths)

        # 数据
        self.asset_table.populate(
            view.get_visible_assets(),
            sort_key=view.sort_key,
            sort_desc=view.sort_desc,
        )
        self.asset_table.show_sort_indicator(view.sort_key, view.sort_desc)

        # 过滤栏
        self.filter_bar.set_text(view.active_filter_str)

        # 状态栏
        self.status_bar.update_counts(
            view.filtered_count, view.total_count, view.active_filter_str
        )
        self.status_bar.update_workspace_path(str(ws.root))

    def _load_column_widths(self, ws: Workspace) -> dict[str, int]:
        raw = ws.get_config("column_widths", "")
        if raw:
            try:
                return json.loads(raw)
            except json.JSONDecodeError:
                pass
        return {}

    def _save_column_widths(self, ws: Workspace, widths: dict[str, int]):
        ws.set_config("column_widths", json.dumps(widths))

    def _on_column_widths_changed(self, _columns: list[str]):
        if self._active_index >= 0:
            ws = self._workspaces[self._active_index]
            widths = self.asset_table.get_column_widths()
            self._save_column_widths(ws, widths)

    def _close_current_workspace(self):
        if self._active_index < 0:
            return
        self._on_tab_close(self._active_index)

    # --- 标签事件 ---

    def _on_tab_select(self, index: int):
        self._activate_workspace(index)

    def _on_tab_close(self, index: int):
        if 0 <= index < len(self._workspaces):
            self._workspaces[index].close()
            del self._workspaces[index]
            del self._views[index]
            self.tab_bar.remove_tab(index)
            if self._workspaces:
                self._activate_workspace(self.tab_bar.active_index)
            else:
                self._active_index = -1
                self.dir_tree.tree.delete(*self.dir_tree.tree.get_children())
                self.asset_table.tree.delete(*self.asset_table.tree.get_children())
                self.status_bar.update_counts(0, 0)

    # --- 排序 ---

    def _on_sort(self, key: str):
        if self._active_index < 0:
            return
        view = self._views[self._active_index]
        view.sort_by(key)
        self.asset_table.populate(
            view.get_visible_assets(),
            sort_key=view.sort_key,
            sort_desc=view.sort_desc,
        )
        self.asset_table.show_sort_indicator(view.sort_key, view.sort_desc)

    # --- 过滤 ---

    def _apply_filter(self, filter_str: str):
        if self._active_index < 0:
            return
        view = self._views[self._active_index]
        view.apply_filter(filter_str)
        self.asset_table.populate(
            view.get_visible_assets(),
            sort_key=view.sort_key,
            sort_desc=view.sort_desc,
        )
        self.status_bar.update_counts(
            view.filtered_count, view.total_count, view.active_filter_str
        )

    def _clear_filter(self):
        self.filter_bar.clear()
        self._apply_filter("")

    # --- 刷新 ---

    def _refresh_current(self):
        if self._active_index < 0:
            return
        view = self._views[self._active_index]
        view.refresh()
        self._activate_workspace(self._active_index)

    # --- 目录树 ---

    def _on_dir_select(self, path: Path):
        if self._active_index < 0:
            return
        view = self._views[self._active_index]
        view.refresh(subdir=path)
        self.asset_table.populate(
            view.get_visible_assets(),
            sort_key=view.sort_key,
            sort_desc=view.sort_desc,
        )
        self.status_bar.update_counts(
            view.filtered_count, view.total_count, view.active_filter_str
        )

    def _toggle_sidebar(self):
        if self._dir_visible:
            self._paned.forget(self.dir_tree)
        else:
            self._paned.insert(0, self.dir_tree, weight=0)
        self._dir_visible = not self._dir_visible

    # --- 列选择器 ---

    def _on_header_right_click(self, event):
        region = self.asset_table.tree.identify("region", event.x, event.y)
        if region != "heading":
            return

        if self._active_index < 0:
            return
        view = self._views[self._active_index]
        columns = view.get_available_columns()

        visible_keys = set(view.get_visible_column_keys())
        for col in columns:
            col.default_visible = col.key in visible_keys

        dialog = tk.Toplevel(self.root)
        ColumnPicker(dialog, columns, on_apply=self._on_columns_changed)

    def _show_column_picker(self):
        if self._active_index < 0:
            return
        view = self._views[self._active_index]
        columns = view.get_available_columns()
        visible_keys = set(view.get_visible_column_keys())
        for col in columns:
            col.default_visible = col.key in visible_keys

        dialog = tk.Toplevel(self.root)
        ColumnPicker(dialog, columns, on_apply=self._on_columns_changed)

    def _on_columns_changed(self, visible_keys: list[str]):
        if self._active_index < 0:
            return
        view = self._views[self._active_index]
        view.set_visible_columns(visible_keys)
        self._activate_workspace(self._active_index)

    # --- 单元格编辑 ---

    def _on_cell_double(self, asset: Asset, col_key: str):
        if col_key in SYSTEM_TAG_KEYS:
            messagebox.showinfo("系统标签",
                                f"「{SYSTEM_TAG_LABELS.get(col_key, col_key)}」是系统标签，不可编辑。")
            return

        suggestions: list[str] = []
        if self._active_index >= 0:
            ws = self._workspaces[self._active_index]
            conn = ws.tag_store._get_conn()
            rows = conn.execute(
                "SELECT DISTINCT value FROM user_tags WHERE key = ? LIMIT 20",
                (col_key,)
            ).fetchall()
            suggestions = [r[0] for r in rows]

        current_val = asset.user_tags.get(col_key, "")

        def on_confirm(value: str):
            if self._active_index < 0:
                return
            view = self._views[self._active_index]
            if value == "":
                view.workspace.delete_user_tag(asset.rel_path, col_key)
                asset.delete_user_tag(col_key)
            else:
                view.update_user_tag(asset, col_key, value)
            self._activate_workspace(self._active_index)

        show_tag_editor(self.root, asset.name, col_key,
                        current_val, suggestions, on_confirm)

    # --- 右键菜单 ---

    def _on_context_menu(self, assets: list[Asset], x: int, y: int):
        user_keys: list[str] = []
        if self._active_index >= 0:
            user_keys = self._views[self._active_index].workspace.get_all_tag_keys()

        menu = build_context_menu(
            self.root, assets,
            on_open=self._open_asset,
            on_copy_path=self._copy_path,
            on_quick_tag=self._quick_tag,
            on_batch_edit=self._batch_edit_tags,
            user_tag_keys=user_keys,
        )
        menu.post(x, y)

    def _open_asset(self, asset: Asset):
        if self._active_index >= 0:
            ws = self._workspaces[self._active_index]
            full = ws.root / asset.rel_path
            subprocess.run(["open", str(full)])

    def _copy_path(self, asset: Asset):
        if self._active_index >= 0:
            ws = self._workspaces[self._active_index]
            full = str(ws.root / asset.rel_path)
            self.root.clipboard_clear()
            self.root.clipboard_append(full)

    def _quick_tag(self, assets: list[Asset], key: str, value: str):
        if self._active_index >= 0:
            if value == "":
                for a in assets:
                    self._views[self._active_index].workspace.delete_user_tag(
                        a.rel_path, key
                    )
                    a.delete_user_tag(key)
            else:
                self._views[self._active_index].batch_update_tags(assets, key, value)
            self._activate_workspace(self._active_index)

    def _batch_edit_tags(self, assets: list[Asset]):
        def on_confirm(key: str, value: str):
            if self._active_index >= 0:
                self._views[self._active_index].batch_update_tags(assets, key, value)
                self._activate_workspace(self._active_index)

        show_batch_tag_editor(self.root, len(assets), on_confirm)

    # --- 生命周期 ---

    def run(self):
        self.root.mainloop()

    def _on_quit(self):
        # 退出前保存列宽
        if self._active_index >= 0:
            ws = self._workspaces[self._active_index]
            widths = self.asset_table.get_column_widths()
            self._save_column_widths(ws, widths)
        for ws in self._workspaces:
            ws.close()
        self.root.destroy()
