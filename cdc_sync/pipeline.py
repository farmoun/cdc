"""同步管道的开启/停止/部署逻辑（CLI 与 Web 共用）。

严格由「开启/停止」控制执行：
- deploy: 建 CK 表 + 注册连接器，但连接器暂停、CK 消费摘除 → 全程不执行同步
- start : 挂上 CK 消费(ATTACH MV) + 恢复连接器 + (schema_only 触发增量快照)
- stop  : 暂停连接器 + 摘除 CK 消费(DETACH MV)
"""
from __future__ import annotations

import logging
import time

from . import ck_client, ck_generator, connect_client, connector_generator, ui_state

log = logging.getLogger("cdc_sync.pipeline")


def _mv_names(tables_cfg) -> tuple[str, list[str]]:
    db = tables_cfg.tables[0].target_database if tables_cfg.tables else "default"
    return db, [t.mv_name for t in tables_cfg.tables]


def deploy_idle(settings, tables_cfg, *, ck_major=None) -> None:
    """完整部署但保持停止态：建表 → 摘除消费 → 注册连接器 → 暂停。"""
    db, mvs = _mv_names(tables_cfg)
    # 0) 先 attach 可能已 detach 的 MV，避免重复部署时 CREATE IF NOT EXISTS 与 detached 冲突
    ck_client.set_consumption(settings.clickhouse, db, mvs, enabled=True)
    # 1) 建 CK 三对象
    for t in tables_cfg.tables:
        tsql = ck_generator.build_table_sql(t, settings, ck_major=ck_major)
        ck_client.execute_statements(settings.clickhouse, tsql.ordered(), dry_run=False)
    # 2) 摘除 CK 消费（DETACH MV），避免消费已有 Kafka 数据
    ck_client.set_consumption(settings.clickhouse, db, mvs, enabled=False)
    # 3) 注册连接器并立即暂停
    connector = connector_generator.build_connector(tables_cfg.tables, settings)
    connect_client.deploy(settings.connect_url, connector)
    time.sleep(2)
    try:
        connect_client.pause(settings.connect_url, settings.debezium.connector_name)
    except Exception as e:  # noqa: BLE001
        log.warning("暂停连接器失败（部署阶段可忽略）：%s", e)
    ui_state.save_state({"pipeline": "stopped"})


def start(settings, tables_cfg, *, do_snapshot: bool = True) -> dict:
    """开启同步：挂消费 + 恢复连接器 + (schema_only 触发增量快照)。"""
    db, mvs = _mv_names(tables_cfg)
    # 1) 挂上 CK 消费（ATTACH MV）
    ck_client.set_consumption(settings.clickhouse, db, mvs, enabled=True)
    # 2) 连接器：不存在则发布，存在则恢复
    name = settings.debezium.connector_name
    if not connect_client.connector_exists(settings.connect_url, name):
        connector = connector_generator.build_connector(tables_cfg.tables, settings)
        connect_client.deploy(settings.connect_url, connector)
    else:
        connect_client.resume(settings.connect_url, name)
    # 3) schema_only：触发增量快照回填历史
    snap = None
    if do_snapshot and settings.debezium.snapshot_mode == "schema_only":
        time.sleep(8)
        try:
            snap = send_snapshot(settings, tables_cfg)
        except Exception as e:  # noqa: BLE001
            log.warning("触发增量快照失败（可稍后手动 snapshot）：%s", e)
    ui_state.save_state({"pipeline": "running"})
    return {"connector": name, "snapshot_tables": snap}


def stop(settings, tables_cfg) -> dict:
    """停止同步：暂停连接器 + 摘除 CK 消费。"""
    name = settings.debezium.connector_name
    paused = False
    try:
        if connect_client.connector_exists(settings.connect_url, name):
            connect_client.pause(settings.connect_url, name)
            paused = True
    except Exception as e:  # noqa: BLE001
        log.warning("暂停连接器失败：%s", e)
    db, mvs = _mv_names(tables_cfg)
    res = ck_client.set_consumption(settings.clickhouse, db, mvs, enabled=False)
    ui_state.save_state({"pipeline": "stopped"})
    return {"connector_paused": paused, "detached": len(res["ok"])}


def send_snapshot(settings, tables_cfg, only=None) -> int:
    """向 Kafka 信号 topic 发增量快照信号，回填历史（分块可续传）。返回表数。"""
    import json
    from kafka import KafkaProducer

    dcs = [f"{t.source_database}.{t.source_table}" for t in tables_cfg.tables]
    if only:
        want = set(only.split(","))
        dcs = [d for d in dcs if d in want or d.split(".", 1)[1] in want]
    if not dcs:
        raise ValueError("没有匹配的表")
    signal = {"type": "execute-snapshot", "data": {"type": "incremental", "data-collections": dcs}}
    brokers = [b.strip() for b in settings.kafka_internal_broker_list.split(",") if b.strip()]
    producer = KafkaProducer(bootstrap_servers=brokers, retries=3, request_timeout_ms=15000)
    try:
        fut = producer.send("cdc-signals", key=b"mysql", value=json.dumps(signal).encode())
        fut.get(timeout=15)
        producer.flush()
    finally:
        producer.close()
    return len(dcs)
