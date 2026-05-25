import sqlite3
import threading
from pathlib import Path
from typing import Optional

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS user_tags (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path  TEXT NOT NULL,
    key        TEXT NOT NULL,
    value      TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    UNIQUE(file_path, key)
);

CREATE INDEX IF NOT EXISTS idx_user_tags_path ON user_tags(file_path);
CREATE INDEX IF NOT EXISTS idx_user_tags_key  ON user_tags(key);
CREATE INDEX IF NOT EXISTS idx_user_tags_kv   ON user_tags(key, value);

CREATE TABLE IF NOT EXISTS workspace_config (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS tag_key_registry (
    key        TEXT PRIMARY KEY,
    created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);

CREATE TRIGGER IF NOT EXISTS tr_register_tag_key
AFTER INSERT ON user_tags
BEGIN
    INSERT OR IGNORE INTO tag_key_registry (key) VALUES (NEW.key);
END;
"""


class TagStore:
    """管理单个工作区 .pylorsmeta.db 的读写操作。"""

    def __init__(self, db_path: Path):
        self.db_path = db_path
        self._local = threading.local()

    def _get_conn(self) -> sqlite3.Connection:
        """线程本地连接。"""
        if not hasattr(self._local, "conn") or self._local.conn is None:
            self._local.conn = sqlite3.connect(str(self.db_path))
            self._local.conn.execute("PRAGMA journal_mode=WAL")
            self._local.conn.execute("PRAGMA foreign_keys=ON")
        return self._local.conn

    def initialize_database(self):
        """创建数据库和表。"""
        conn = self._get_conn()
        conn.executescript(SCHEMA_SQL)
        conn.commit()

    def close(self):
        if hasattr(self._local, "conn") and self._local.conn:
            self._local.conn.close()
            self._local.conn = None

    # --- 标签 CRUD ---

    def get_tag(self, file_path: str, key: str) -> Optional[str]:
        conn = self._get_conn()
        row = conn.execute(
            "SELECT value FROM user_tags WHERE file_path = ? AND key = ?",
            (file_path, key)
        ).fetchone()
        return row[0] if row else None

    def get_all_tags(self, file_path: str) -> dict[str, str]:
        conn = self._get_conn()
        rows = conn.execute(
            "SELECT key, value FROM user_tags WHERE file_path = ?",
            (file_path,)
        ).fetchall()
        return {k: v for k, v in rows}

    def get_bulk_tags(self, file_paths: list[str]) -> dict[str, dict[str, str]]:
        """批量获取标签 — 一次查询取回所有文件的用户标签。"""
        if not file_paths:
            return {}
        conn = self._get_conn()
        placeholders = ",".join("?" for _ in file_paths)
        rows = conn.execute(
            f"SELECT file_path, key, value FROM user_tags WHERE file_path IN ({placeholders})",
            file_paths
        ).fetchall()
        result: dict[str, dict[str, str]] = {p: {} for p in file_paths}
        for fp, k, v in rows:
            result.setdefault(fp, {})[k] = v
        return result

    def set_tag(self, file_path: str, key: str, value: str):
        conn = self._get_conn()
        conn.execute(
            "INSERT OR REPLACE INTO user_tags (file_path, key, value, updated_at) "
            "VALUES (?, ?, ?, datetime('now','localtime'))",
            (file_path, key, value)
        )
        conn.commit()

    def delete_tag(self, file_path: str, key: str):
        conn = self._get_conn()
        conn.execute(
            "DELETE FROM user_tags WHERE file_path = ? AND key = ?",
            (file_path, key)
        )
        conn.commit()

    def batch_set_tags(self, file_paths: list[str], key: str, value: str):
        conn = self._get_conn()
        conn.execute("BEGIN")
        conn.executemany(
            "INSERT OR REPLACE INTO user_tags (file_path, key, value, updated_at) "
            "VALUES (?, ?, ?, datetime('now','localtime'))",
            [(fp, key, value) for fp in file_paths]
        )
        conn.commit()

    def delete_tags_for_missing_files(self, valid_paths: set[str]):
        """清除数据库中引用不存在文件的标签。"""
        conn = self._get_conn()
        rows = conn.execute("SELECT DISTINCT file_path FROM user_tags").fetchall()
        stale = [r[0] for r in rows if r[0] not in valid_paths]
        if stale:
            placeholders = ",".join("?" for _ in stale)
            conn.execute(
                f"DELETE FROM user_tags WHERE file_path IN ({placeholders})",
                stale
            )
            conn.commit()

    # --- 标签键管理 ---

    def get_all_keys(self) -> list[str]:
        conn = self._get_conn()
        rows = conn.execute(
            "SELECT key FROM tag_key_registry ORDER BY created_at"
        ).fetchall()
        return [r[0] for r in rows]

    # --- 工作区配置 ---

    def get_config(self, key: str, default: str = "") -> str:
        conn = self._get_conn()
        row = conn.execute(
            "SELECT value FROM workspace_config WHERE key = ?", (key,)
        ).fetchone()
        return row[0] if row else default

    def set_config(self, key: str, value: str):
        conn = self._get_conn()
        conn.execute(
            "INSERT OR REPLACE INTO workspace_config (key, value) VALUES (?, ?)",
            (key, value)
        )
        conn.commit()

    # --- 搜索 ---

    def search_by_tag(self, filters: list[tuple[str, str]]) -> list[str]:
        """按标签搜索，AND 逻辑。返回 file_path 列表。"""
        if not filters:
            return []
        conn = self._get_conn()
        conditions = []
        params = []
        for k, v in filters:
            conditions.append("(key = ? AND value = ?)")
            params.extend([k, v])
        where = " AND ".join(conditions)
        rows = conn.execute(
            f"SELECT file_path FROM user_tags WHERE {where} "
            "GROUP BY file_path HAVING COUNT(DISTINCT key) = ?",
            params + [len(filters)]
        ).fetchall()
        return [r[0] for r in rows]
