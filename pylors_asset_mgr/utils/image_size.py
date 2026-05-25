"""图片尺寸读取 — Pillow 封装。"""

from pathlib import Path
from typing import Optional


def read_image_dims(path: Path) -> Optional[tuple[int, int]]:
    """返回 (width, height)，失败返回 None。"""
    from PIL import Image
    try:
        with Image.open(path) as img:
            return img.size
    except Exception:
        return None
