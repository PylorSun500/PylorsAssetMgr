import os
import time
from pathlib import Path
from typing import Iterator, Callable, Optional

from pylors_asset_mgr.config import SKIP_NAMES, MAX_SCAN_DEPTH


def _format_size(size: int) -> str:
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if size < 1024:
            return f"{size} {unit}" if unit == "B" else f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} PB"


def _format_time(ts: float) -> str:
    return time.strftime("%Y-%m-%d %H:%M", time.localtime(ts))


class FileScanner:
    """递归扫描工作区目录，为每个文件生成系统标签字典。"""

    def __init__(
        self,
        workspace_root: Path,
        on_progress: Optional[Callable[[int, int], None]] = None,
    ):
        self.root = workspace_root
        self.on_progress = on_progress

    def scan(
        self,
        subdir: Optional[Path] = None,
        include_hidden: bool = False,
    ) -> list[dict]:
        """扫描目录，返回原始资产字典列表（仅系统标签）。"""
        return list(self.scan_generator(subdir, include_hidden))

    def scan_generator(
        self,
        subdir: Optional[Path] = None,
        include_hidden: bool = False,
    ) -> Iterator[dict]:
        """生成器版本，支持大目录渐进加载。"""
        base = subdir.resolve() if subdir else self.root
        base = base if isinstance(base, Path) else Path(base)

        for dirpath, dirnames, filenames in os.walk(base, followlinks=False):
            # 深度限制
            rel = os.path.relpath(dirpath, self.root)
            depth = 0 if rel == "." else rel.count(os.sep) + 1
            if depth > MAX_SCAN_DEPTH:
                dirnames.clear()
                continue

            # 过滤隐藏目录
            if not include_hidden:
                dirnames[:] = [
                    d for d in dirnames
                    if not d.startswith(".") and d not in SKIP_NAMES
                ]

            for name in filenames:
                if name in SKIP_NAMES:
                    continue
                if not include_hidden and name.startswith("."):
                    continue

                full_path = os.path.join(dirpath, name)
                try:
                    st = os.stat(full_path)
                except OSError:
                    continue

                is_dir = os.path.isdir(full_path)
                suffix = "" if is_dir else os.path.splitext(name)[1].lower()
                stem = name if is_dir else os.path.splitext(name)[0]

                rel_path = os.path.relpath(full_path, self.root)

                item = {
                    "rel_path": rel_path,
                    "name": name,
                    "stem": stem,
                    "suffix": suffix,
                    "size": st.st_size,
                    "size_display": _format_size(st.st_size),
                    "ctime": st.st_ctime,
                    "mtime": st.st_mtime,
                    "ctime_display": _format_time(st.st_ctime),
                    "mtime_display": _format_time(st.st_mtime),
                    "is_dir": is_dir,
                    "width": None,
                    "height": None,
                    "dimensions": None,
                }
                yield item

    def scan_single(self, file_path: Path) -> Optional[dict]:
        """扫描单个文件（用于刷新某个文件）。"""
        full = self.root / file_path
        try:
            st = os.stat(full)
        except OSError:
            return None
        name = full.name
        return {
            "rel_path": str(file_path),
            "name": name,
            "stem": os.path.splitext(name)[0],
            "suffix": os.path.splitext(name)[1].lower(),
            "size": st.st_size,
            "size_display": _format_size(st.st_size),
            "ctime": st.st_ctime,
            "mtime": st.st_mtime,
            "ctime_display": _format_time(st.st_ctime),
            "mtime_display": _format_time(st.st_mtime),
            "is_dir": full.is_dir(),
            "width": None,
            "height": None,
            "dimensions": None,
        }
