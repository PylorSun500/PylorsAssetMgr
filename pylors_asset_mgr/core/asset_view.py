from pathlib import Path
from typing import Optional

from pylors_asset_mgr.models.asset import Asset
from pylors_asset_mgr.models.tag_schema import TagColumnInfo, TagSource
from pylors_asset_mgr.config import SYSTEM_TAG_KEYS, SYSTEM_TAG_LABELS, DEFAULT_VISIBLE_COLUMNS
from .workspace import Workspace
from .scanner import FileScanner
from .filter_engine import FilterEngine


class AssetView:
    """核心 ViewModel：扫描结果 + DB 用户标签 → 合并、排序、过滤。"""

    def __init__(self, workspace: Workspace):
        self.workspace = workspace
        self.scanner = FileScanner(workspace.root)
        self._merged: list[Asset] = []
        self._filtered: list[Asset] = []
        self._sort_key: str = "name"
        self._sort_desc: bool = False
        self._filters: list[tuple[str, str]] = []
        self._current_subdir: Optional[Path] = None

    def refresh(self, subdir: Optional[Path] = None) -> list[Asset]:
        """核心入口：扫描 → 查 DB → 合并 → 排序 → 过滤。"""
        self._current_subdir = subdir

        # 1. 扫描文件系统
        raw_list = self.scanner.scan(subdir)

        # 2. 批量查用户标签
        paths = [item["rel_path"] for item in raw_list]
        bulk_tags = self.workspace.tag_store.get_bulk_tags(paths)

        # 3. 合并为 Asset 对象
        self._merged = []
        for item in raw_list:
            asset = Asset(
                rel_path=item["rel_path"],
                name=item["name"],
                stem=item["stem"],
                suffix=item["suffix"],
                size=item["size"],
                size_display=item["size_display"],
                ctime=item["ctime"],
                mtime=item["mtime"],
                ctime_display=item["ctime_display"],
                mtime_display=item["mtime_display"],
                is_dir=item["is_dir"],
                width=item["width"],
                height=item["height"],
                dimensions=item["dimensions"],
                user_tags=bulk_tags.get(item["rel_path"], {}),
            )
            self._merged.append(asset)

        # 4. 清理过期标签
        self.workspace.cleanup_stale_tags(set(paths))

        # 5. 排序
        self._sort()

        # 6. 过滤
        self._apply_filters()

        return self._filtered

    def get_visible_assets(self) -> list[Asset]:
        return self._filtered

    def all_assets(self) -> list[Asset]:
        return self._merged

    # --- 排序 ---

    def sort_by(self, key: str, descending: Optional[bool] = None):
        if descending is not None:
            self._sort_desc = descending
        else:
            if self._sort_key == key:
                self._sort_desc = not self._sort_desc
            else:
                self._sort_desc = False
        self._sort_key = key
        self._sort()
        self._apply_filters()

    def _sort(self):
        key = self._sort_key
        desc = self._sort_desc

        def sort_fn(asset: Asset):
            val = asset.get_tag(key)
            if val is None:
                # None 值排到最后
                return (1, "")
            try:
                # 数值尝试数字排序
                if key == "size":
                    return (0, asset.size)
                if key in ("ctime", "mtime"):
                    return (0, getattr(asset, key, 0))
                return (0, val.lower())
            except (ValueError, AttributeError):
                return (0, val.lower())

        self._merged.sort(key=sort_fn, reverse=desc)

    @property
    def sort_key(self) -> str:
        return self._sort_key

    @property
    def sort_desc(self) -> bool:
        return self._sort_desc

    # --- 过滤 ---

    def apply_filter(self, filter_str: str):
        self._filters = FilterEngine.parse(filter_str)
        self._apply_filters()

    def clear_filter(self):
        self._filters = []
        self._apply_filters()

    def _apply_filters(self):
        if not self._filters:
            self._filtered = list(self._merged)
        else:
            self._filtered = [
                a for a in self._merged
                if FilterEngine.matches(a, self._filters)
            ]

    @property
    def active_filter_str(self) -> str:
        if not self._filters:
            return ""
        parts = []
        for k, v in self._filters:
            if " " in v:
                parts.append(f'{k}:"{v}"')
            else:
                parts.append(f"{k}:{v}")
        return " ".join(parts)

    # --- 标签编辑 ---

    def update_user_tag(self, asset: Asset, key: str, value: str):
        self.workspace.set_user_tag(asset.rel_path, key, value)
        asset.set_user_tag(key, value)

    def batch_update_tags(self, assets: list[Asset], key: str, value: str):
        paths = [a.rel_path for a in assets]
        self.workspace.batch_set_tags(paths, key, value)
        for a in assets:
            a.set_user_tag(key, value)

    # --- 列信息 ---

    def get_available_columns(self) -> list[TagColumnInfo]:
        """返回所有可用列：系统列 + 已注册的用户标签列。"""
        columns: list[TagColumnInfo] = []

        # 系统列
        for key in DEFAULT_VISIBLE_COLUMNS:
            columns.append(TagColumnInfo(
                key=key,
                source=TagSource.SYSTEM,
                default_visible=True,
                human_name=SYSTEM_TAG_LABELS.get(key, key),
            ))
        # 追加未默认显示的系统列
        for key in ["ctime_display", "dimensions", "is_dir"]:
            if key not in DEFAULT_VISIBLE_COLUMNS:
                columns.append(TagColumnInfo(
                    key=key,
                    source=TagSource.SYSTEM,
                    default_visible=False,
                    human_name=SYSTEM_TAG_LABELS.get(key, key),
                ))

        # 用户标签列
        user_keys = self.workspace.get_all_tag_keys()
        visible_str = self.workspace.get_config("visible_columns", "")
        visible_set = set(visible_str.split(",")) if visible_str else set()

        for k in user_keys:
            columns.append(TagColumnInfo(
                key=k,
                source=TagSource.USER,
                default_visible=k in visible_set,
                human_name=k,
            ))

        return columns

    def get_visible_column_keys(self) -> list[str]:
        config = self.workspace.get_config("visible_columns", "")
        if config:
            configured = config.split(",")
            # 始终包含 name
            if "name" not in configured:
                configured.insert(0, "name")
            return configured
        return list(DEFAULT_VISIBLE_COLUMNS)

    def set_visible_columns(self, keys: list[str]):
        self.workspace.set_config("visible_columns", ",".join(keys))

    # --- 资产数量 ---

    @property
    def filtered_count(self) -> int:
        return len(self._filtered)

    @property
    def total_count(self) -> int:
        return len(self._merged)
