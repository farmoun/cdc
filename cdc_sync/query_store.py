"""保存查询的持久化：读写 config/saved_queries.json（挂在卷上，重建容器不丢）。"""
from __future__ import annotations

import json
import os
from pathlib import Path

from . import config


def _path() -> Path:
    return Path(os.environ.get("CDC_QUERIES") or (config.CONFIG_DIR / "saved_queries.json"))


def load_queries() -> list[dict]:
    p = _path()
    if not p.exists():
        return []
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
        return data if isinstance(data, list) else []
    except Exception:  # noqa: BLE001
        return []


def _write(items: list[dict]) -> None:
    p = _path()
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(items, ensure_ascii=False, indent=2), encoding="utf-8")


def save_query(name: str, sql: str) -> list[dict]:
    """按名 upsert 保存一条查询。返回最新列表。"""
    name = (name or "").strip()
    if not name:
        raise ValueError("查询名不能为空")
    if not (sql or "").strip():
        raise ValueError("查询语句不能为空")
    items = [q for q in load_queries() if q.get("name") != name]
    items.append({"name": name, "sql": sql})
    items.sort(key=lambda q: q.get("name", ""))
    _write(items)
    return items


def delete_query(name: str) -> list[dict]:
    items = [q for q in load_queries() if q.get("name") != name]
    _write(items)
    return items
