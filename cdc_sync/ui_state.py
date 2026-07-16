"""前端 UI 状态的后端持久化：如监控开关。存 config/ui_state.json（挂卷不丢）。"""
from __future__ import annotations

import json
import os
from pathlib import Path

from . import config

_DEFAULT = {"monitoring": False}


def _path() -> Path:
    return Path(os.environ.get("CDC_UI_STATE") or (config.CONFIG_DIR / "ui_state.json"))


def load_state() -> dict:
    p = _path()
    if not p.exists():
        return dict(_DEFAULT)
    try:
        d = json.loads(p.read_text(encoding="utf-8"))
        return {**_DEFAULT, **d} if isinstance(d, dict) else dict(_DEFAULT)
    except Exception:  # noqa: BLE001
        return dict(_DEFAULT)


def save_state(patch: dict) -> dict:
    st = load_state()
    if isinstance(patch, dict):
        for k in _DEFAULT:
            if k in patch:
                st[k] = patch[k]
    p = _path()
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(st, ensure_ascii=False, indent=2), encoding="utf-8")
    return st
