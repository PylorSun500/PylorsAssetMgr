from dataclasses import dataclass
from enum import Enum, auto


class TagSource(Enum):
    SYSTEM = auto()   # 系统标签，实时从文件系统读取
    USER = auto()     # 用户标签，SQLite 存储


@dataclass
class TagColumnInfo:
    key: str
    source: TagSource
    default_visible: bool = False
    default_width: int = 120
    human_name: str = ""

    def __post_init__(self):
        if not self.human_name:
            self.human_name = self.key
