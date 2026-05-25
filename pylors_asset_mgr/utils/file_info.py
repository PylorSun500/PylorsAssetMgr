"""文件元数据提取 — 纯文件系统操作。"""

import os
from pathlib import Path
from typing import Optional


def get_image_dimensions(path: Path) -> Optional[tuple[int, int]]:
    """用 Pillow 读取图片尺寸（只读头部，不加载像素）。"""
    from PIL import Image
    try:
        with Image.open(path) as img:
            img.load()
            return img.size
    except Exception:
        return None


SUPPORTED_IMAGE_EXTS = frozenset({
    ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".tiff", ".tif",
    ".webp", ".ico", ".psd", ".svg",
})


def add_image_dimensions(item: dict, root: Path):
    """为图片文件补充 width/height/dimensions 字段（原地修改）。"""
    if item["is_dir"]:
        return
    if item["suffix"] not in SUPPORTED_IMAGE_EXTS:
        return
    full_path = root / item["rel_path"]
    dims = get_image_dimensions(full_path)
    if dims:
        item["width"], item["height"] = dims
        item["dimensions"] = f"{dims[0]}x{dims[1]}"
