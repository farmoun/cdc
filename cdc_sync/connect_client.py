"""Kafka Connect REST 客户端：发布/更新 Debezium 连接器、查状态、重启。"""
from __future__ import annotations

import logging

import requests

log = logging.getLogger("cdc_sync.connect")

_TIMEOUT = 15


class ConnectError(Exception):
    pass


def _base(url: str) -> str:
    return url.rstrip("/")


def ping(connect_url: str) -> bool:
    """探测 Connect REST 是否就绪（GET /connectors 返回 200）。"""
    try:
        r = requests.get(f"{_base(connect_url)}/connectors", timeout=5)
        return r.status_code == 200
    except requests.RequestException:
        return False


def connector_exists(connect_url: str, name: str) -> bool:
    try:
        r = requests.get(f"{_base(connect_url)}/connectors/{name}", timeout=_TIMEOUT)
    except requests.RequestException as e:
        raise ConnectError(f"连接 Kafka Connect 失败 {connect_url} — {e}") from e
    if r.status_code == 200:
        return True
    if r.status_code == 404:
        return False
    raise ConnectError(f"查询连接器失败 HTTP {r.status_code}: {r.text}")


def deploy(connect_url: str, connector: dict) -> dict:
    """不存在则 POST 创建，存在则 PUT 更新 config（幂等）。"""
    name = connector["name"]
    config = connector["config"]
    base = _base(connect_url)
    try:
        if connector_exists(connect_url, name):
            log.info("连接器 %s 已存在 → 更新 config", name)
            r = requests.put(
                f"{base}/connectors/{name}/config",
                json=config,
                timeout=_TIMEOUT,
            )
        else:
            log.info("连接器 %s 不存在 → 创建", name)
            r = requests.post(
                f"{base}/connectors",
                json=connector,
                timeout=_TIMEOUT,
            )
    except requests.RequestException as e:
        raise ConnectError(f"发布连接器失败 — {e}") from e

    if r.status_code not in (200, 201):
        raise ConnectError(f"发布连接器失败 HTTP {r.status_code}: {r.text}")
    return r.json()


def status(connect_url: str, name: str) -> dict:
    try:
        r = requests.get(f"{_base(connect_url)}/connectors/{name}/status", timeout=_TIMEOUT)
    except requests.RequestException as e:
        raise ConnectError(f"查询连接器状态失败 — {e}") from e
    if r.status_code == 404:
        raise ConnectError(f"连接器不存在: {name}")
    if r.status_code != 200:
        raise ConnectError(f"查询状态失败 HTTP {r.status_code}: {r.text}")
    return r.json()


def restart(connect_url: str, name: str) -> None:
    base = _base(connect_url)
    try:
        r = requests.post(
            f"{base}/connectors/{name}/restart",
            params={"includeTasks": "true", "onlyFailed": "false"},
            timeout=_TIMEOUT,
        )
    except requests.RequestException as e:
        raise ConnectError(f"重启连接器失败 — {e}") from e
    if r.status_code not in (200, 202, 204):
        raise ConnectError(f"重启失败 HTTP {r.status_code}: {r.text}")
