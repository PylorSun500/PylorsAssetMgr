from pathlib import Path
from .tag_store import TagStore


class Workspace:
    """管理一个工作区 — 真实文件系统目录 + 其 .pylorsmeta.db。"""

    def __init__(self, root_path: Path | str):
        self.root = Path(root_path).resolve()
        self.db_path = self.root / ".pylorsmeta.db"
        self.tag_store = TagStore(self.db_path)
        self.display_name = self.root.name

    def initialize(self):
        """确保 DB 文件存在并初始化 schema。"""
        self.root.mkdir(parents=True, exist_ok=True)
        self.tag_store.initialize_database()

    def close(self):
        self.tag_store.close()

    def is_valid(self) -> bool:
        return self.root.exists() and self.root.is_dir()

    # --- 标签操作委托 ---

    def get_user_tags(self, rel_path: str) -> dict[str, str]:
        return self.tag_store.get_all_tags(rel_path)

    def set_user_tag(self, rel_path: str, key: str, value: str):
        self.tag_store.set_tag(rel_path, key, value)

    def delete_user_tag(self, rel_path: str, key: str):
        self.tag_store.delete_tag(rel_path, key)

    def get_all_tag_keys(self) -> list[str]:
        return self.tag_store.get_all_keys()

    def batch_set_tags(self, rel_paths: list[str], key: str, value: str):
        self.tag_store.batch_set_tags(rel_paths, key, value)

    def get_config(self, key: str, default: str = "") -> str:
        return self.tag_store.get_config(key, default)

    def set_config(self, key: str, value: str):
        self.tag_store.set_config(key, value)

    def cleanup_stale_tags(self, valid_paths: set[str]):
        self.tag_store.delete_tags_for_missing_files(valid_paths)
