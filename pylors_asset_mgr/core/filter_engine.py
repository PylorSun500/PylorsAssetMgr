import re
import fnmatch

from pylors_asset_mgr.models.asset import Asset

# 解析 key:value 或 key:"quoted value" 或 自由文本
FILTER_PATTERN = re.compile(
    r'(\w+):(?:(["\'])(.+?)\2|([^\s]+)|)'
    r'|(\S+)'
)


class FilterEngine:
    """解析 key:value 过滤器字符串并匹配资产。"""

    @classmethod
    def parse(cls, filter_str: str) -> list[tuple[str, str]]:
        """解析过滤字符串。

        "importance:high status:\"in review\""
        -> [("importance", "high"), ("status", "in review")]
        """
        if not filter_str or not filter_str.strip():
            return []
        result: list[tuple[str, str]] = []
        for m in FILTER_PATTERN.finditer(filter_str):
            key, _, quoted, unquoted, bare = m.groups()
            if key:
                value = quoted if quoted is not None else unquoted or ""
                result.append((key, value))
            elif bare:
                # 自由文本：所有用户标签值中模糊匹配
                result.append(("__any__", bare))
        return result

    @classmethod
    def matches(cls, asset: Asset, filters: list[tuple[str, str]]) -> bool:
        """判断资产是否匹配所有过滤条件（AND 逻辑）。"""
        if not filters:
            return True
        return all(
            cls._match_single(asset, key, value)
            for key, value in filters
        )

    @classmethod
    def _match_single(cls, asset: Asset, key: str, value: str) -> bool:
        if key == "__any__":
            # 在所有标签值中模糊搜索
            query = value.lower()
            for tag_key in ("name", "suffix", "size_display", "dimensions"):
                tv = asset.get_tag(tag_key)
                if tv and query in tv.lower():
                    return True
            for uv in asset.user_tags.values():
                if query in uv.lower():
                    return True
            return False

        tag_val = asset.get_tag(key)
        if tag_val is None:
            # 仅键匹配 "importance:" → 有该键即可
            return value == ""
        return cls._wildcard_match(tag_val, value)

    @classmethod
    def _wildcard_match(cls, text: str, pattern: str) -> bool:
        """支持 * 通配符的匹配。"""
        if "*" in pattern or "?" in pattern:
            return fnmatch.fnmatch(text.lower(), pattern.lower())
        return pattern.lower() in text.lower()
