from dataclasses import dataclass, field
from typing import Optional


@dataclass
class Asset:
    """代表详情列表中的一行：系统标签 + 用户标签的合并结果。"""

    # === 系统标签（每次扫描实时填充） ===
    rel_path: str       # 相对工作区根目录的路径
    name: str           # 文件名（含扩展名）
    stem: str           # 文件名（不含扩展名）
    suffix: str         # 扩展名，如 ".jpg"（目录为空字符串）
    size: int           # 字节数
    size_display: str   # 人类可读，如 "2.3 MB"
    ctime: float        # 创建时间戳
    mtime: float        # 修改时间戳
    ctime_display: str  # 格式化创建时间
    mtime_display: str  # 格式化修改时间
    is_dir: bool = False
    width: Optional[int] = None
    height: Optional[int] = None
    dimensions: Optional[str] = None

    # === 用户标签（从 DB 填充） ===
    user_tags: dict[str, str] = field(default_factory=dict)

    # === 缩略图 ===
    thumbnail_path: Optional[str] = None

    def get_tag(self, key: str) -> Optional[str]:
        """获取标签值：优先用户标签，其次系统标签。"""
        if key in self.user_tags:
            return self.user_tags[key]
        return self._system_tag_value(key)

    def set_user_tag(self, key: str, value: str):
        self.user_tags[key] = value

    def delete_user_tag(self, key: str):
        self.user_tags.pop(key, None)

    def _system_tag_value(self, key: str) -> Optional[str]:
        """从系统标签字段中读取值，转为字符串。"""
        if key == "is_dir":
            return "目录" if self.is_dir else "文件"
        attr = getattr(self, key, None)
        if attr is None:
            return None
        return str(attr)
