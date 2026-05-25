"""全局常量与默认配置。"""

# 系统标签键 — 从文件系统实时读取
SYSTEM_TAG_KEYS = frozenset({
    "name", "stem", "suffix", "size", "size_display",
    "ctime", "mtime", "ctime_display", "mtime_display",
    "is_dir", "width", "height", "dimensions",
})

# 系统标签键的中文列头显示名
SYSTEM_TAG_LABELS: dict[str, str] = {
    "name": "文件名",
    "stem": "名称",
    "suffix": "格式",
    "size": "大小",
    "size_display": "大小",
    "ctime": "创建时间",
    "mtime": "修改时间",
    "ctime_display": "创建时间",
    "mtime_display": "修改时间",
    "is_dir": "类型",
    "width": "宽度",
    "height": "高度",
    "dimensions": "尺寸",
}

# 详情列表默认可见列（按顺序）
DEFAULT_VISIBLE_COLUMNS = ["name", "suffix", "size_display", "mtime_display"]

# 跳过不扫描的文件名
SKIP_NAMES = {".DS_Store", ".pylorsmeta.db", "Thumbs.db", ".localized"}

# 默认不扫描隐藏文件（以 . 开头）
SKIP_PREFIXES = {".", "~"}

# 用户标签键名规则
import re
TAG_KEY_PATTERN = re.compile(r"^[a-zA-Z一-鿿][a-zA-Z0-9一-鿿_-]*$")

# 缩略图缓存目录（在 workspace 根目录下）
THUMB_CACHE_DIR = ".pylorsthumb"

# 缩略图默认尺寸
THUMB_SIZE = 128

# 最大扫描深度
MAX_SCAN_DEPTH = 50
