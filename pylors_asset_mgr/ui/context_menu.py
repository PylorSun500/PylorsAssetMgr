"""右键上下文菜单构建。"""

import tkinter as tk
from typing import Callable

from pylors_asset_mgr.models.asset import Asset


def build_context_menu(
    parent: tk.Widget,
    assets: list[Asset],
    on_open: Callable[[Asset], None],
    on_copy_path: Callable[[Asset], None],
    on_quick_tag: Callable[[list[Asset], str, str], None],
    on_batch_edit: Callable[[list[Asset]], None],
    user_tag_keys: list[str],
) -> tk.Menu:
    """构建资产的右键上下文菜单。"""
    menu = tk.Menu(parent, tearoff=0)

    if len(assets) == 1:
        a = assets[0]
        menu.add_command(label="打开文件", command=lambda: on_open(a))
        menu.add_command(label="复制路径", command=lambda: on_copy_path(a))
    else:
        menu.add_command(label=f"已选 {len(assets)} 个资产", state=tk.DISABLED)

    menu.add_separator()
    menu.add_command(label="批量编辑标签...",
                     command=lambda: on_batch_edit(assets))

    # 重要性快捷标签
    menu.add_separator()
    menu.add_command(label="设 importance:high",
                     command=lambda: on_quick_tag(assets, "importance", "high"))
    menu.add_command(label="设 importance:medium",
                     command=lambda: on_quick_tag(assets, "importance", "medium"))
    menu.add_command(label="设 importance:low",
                     command=lambda: on_quick_tag(assets, "importance", "low"))

    # 其他已注册的用户标签键
    other_keys = [k for k in user_tag_keys if k != "importance"]
    if other_keys:
        menu.add_separator()
        for k in other_keys[:10]:
            menu.add_command(label=f"删除标签: {k}",
                             command=lambda key=k: on_quick_tag(assets, key, ""))

    return menu
