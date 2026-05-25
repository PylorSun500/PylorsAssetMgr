"""缩略图生成 — 调用 macOS qlmanage (Quick Look)。"""

import os
import subprocess
from pathlib import Path
from typing import Optional

from pylors_asset_mgr.config import THUMB_SIZE


def generate_thumbnail(file_path: Path, cache_dir: Path) -> Optional[Path]:
    """用 qlmanage 为单个文件生成缩略图，返回缩略图路径。

    qlmanage 输出格式固定为 <filename>.png，我们通过 -o 指定输出目录。
    """
    if not file_path.exists():
        return None

    thumb_name = str(file_path.resolve()).replace("/", "_").replace(" ", "_") + ".png"
    thumb_path = cache_dir / thumb_name

    if thumb_path.exists():
        return thumb_path

    cache_dir.mkdir(parents=True, exist_ok=True)
    try:
        subprocess.run(
            [
                "qlmanage", "-t",
                "-s", str(THUMB_SIZE),
                "-o", str(cache_dir),
                str(file_path.resolve()),
            ],
            capture_output=True,
            timeout=10,
            check=True,
        )
        # qlmanage 生成的缩略图名字是 "QuickLook_<filename>.png"
        # 实际上 qlmanage 的输出命名规律是 <basename_no_ext>.png
        generated = cache_dir / f"{file_path.stem}.png"
        if generated.exists():
            generated.rename(thumb_path)
            return thumb_path

        # fallback: 扫描缓存目录找最新文件
        newest = max(cache_dir.glob("*.png"), key=lambda p: p.stat().st_mtime, default=None)
        if newest and newest != thumb_path:
            newest.rename(thumb_path)
            return thumb_path
        return None
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError):
        return None


def clear_thumb_cache(cache_dir: Path):
    """清除缩略图缓存。"""
    if cache_dir.exists():
        for f in cache_dir.glob("*.png"):
            f.unlink()
