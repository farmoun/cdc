"""CDC 同步工具 CLI 入口。

子命令：
  introspect         连 MySQL 内省表结构 → 缓存
  generate           生成 CK 三对象 SQL + 连接器 JSON 到 out/
  apply-ck           对 ClickHouse 执行三对象 DDL
  deploy-connector   向 Kafka Connect 发布/更新连接器
  status             连接器状态 + CK kafka_consumers
  reconcile          MySQL vs CK 行数对账

全局参数：--settings / --tables 指定配置文件；--out 指定产物目录。
"""
from __future__ import annotations

import argparse
import logging
import os
import sys
from pathlib import Path

from . import (
    ck_client,
    ck_generator,
    config,
    connect_client,
    connector_generator,
    mysql_introspect,
    reconcile,
    sql_parser,
)
from .config import ROOT, ConfigError

OUT_DIR = ROOT / "out"

log = logging.getLogger("cdc_sync")


def _setup_logging(verbose: bool) -> None:
    logging.basicConfig(
        level=logging.DEBUG if verbose else logging.INFO,
        format="%(levelname)s %(name)s: %(message)s",
    )


def _load(args) -> tuple[config.Settings, config.TablesConfig]:
    settings = config.load_settings(args.settings)
    tables = config.load_tables(args.tables)
    return settings, tables


def _ensure_columns(settings: config.Settings, tables_cfg: config.TablesConfig, *, allow_introspect: bool) -> None:
    """确保每张表都有列定义：优先内联 → 缓存 → （允许则）内省。"""
    cache = mysql_introspect.load_cache()
    mysql_introspect.apply_cache_to_tables(tables_cfg.tables, cache)
    missing = [t for t in tables_cfg.tables if not t.has_columns()]
    if missing and allow_introspect:
        log.info("以下表无列定义，尝试从 MySQL 内省：%s",
                 ", ".join(f"{t.source_database}.{t.source_table}" for t in missing))
        mysql_introspect.introspect_all(settings.mysql, missing)
    still_missing = [t for t in tables_cfg.tables if not t.has_columns()]
    if still_missing:
        names = ", ".join(f"{t.source_database}.{t.source_table}" for t in still_missing)
        raise ConfigError(
            f"以下表缺少列定义：{names}。请先运行 `introspect`，或在 tables.yaml 内联 columns。"
        )


# ----------------------------- 子命令 -----------------------------

def cmd_import_sql(args) -> int:
    """解析 mysqldump/Navicat 导出的 .sql，生成 tables.yaml。"""
    import yaml

    parsed = sql_parser.parse_file(args.file)
    if not parsed:
        log.error("未从 %s 解析到任何 CREATE TABLE", args.file)
        return 1

    only = set(args.only.split(",")) if args.only else None
    skip = set(args.skip.split(",")) if args.skip else None

    doc = sql_parser.build_tables_doc(
        parsed, database=args.database, target_database=args.target_database,
        prefix=args.prefix, only=only, skip=skip,
    )
    out_path = Path(args.out)
    with out_path.open("w", encoding="utf-8") as f:
        yaml.safe_dump(doc, f, allow_unicode=True, sort_keys=False, default_flow_style=False, width=200)

    tables_out = doc["tables"]
    total_cols = sum(len(t["columns"]) for t in tables_out)
    no_pk = [t["source_table"] for t in tables_out if t.get("order_by") == ""]
    log.info("✓ 解析 %d 张表 / %d 列 → %s", len(tables_out), total_cols, out_path)
    if no_pk:
        log.warning("以下表无主键，请在 tables.yaml 手动填写 order_by（唯一键）：%s", ", ".join(no_pk))
    return 0


def cmd_render_config(args) -> int:
    """从 ${ENV} 模板播种 literal 的 config/settings.yaml（容器首启用）。"""
    from . import config_store
    written, msg = config_store.seed_settings_from(args.from_template, force=args.force)
    log.info("%s %s", "✓" if written else "•", msg)
    return 0


def _send_snapshot_signal(settings, tables_cfg, only=None) -> int:
    """向 Kafka 信号 topic 发增量快照信号，回填历史数据（分块、可断点续传）。返回表数。"""
    import json
    from kafka import KafkaProducer

    dcs = [f"{t.source_database}.{t.source_table}" for t in tables_cfg.tables]
    if only:
        want = set(only.split(","))
        dcs = [d for d in dcs if d in want or d.split(".", 1)[1] in want]
    if not dcs:
        raise ValueError("没有匹配的表")

    signal = {"type": "execute-snapshot",
              "data": {"type": "incremental", "data-collections": dcs}}
    brokers = [b.strip() for b in settings.kafka_internal_broker_list.split(",") if b.strip()]
    producer = KafkaProducer(bootstrap_servers=brokers, retries=3, request_timeout_ms=15000)
    try:
        # key 必须等于连接器的 topic.prefix（本项目固定 "mysql"）
        fut = producer.send("cdc-signals", key=b"mysql", value=json.dumps(signal).encode())
        fut.get(timeout=15)
        producer.flush()
    finally:
        producer.close()
    return len(dcs)


def cmd_snapshot(args) -> int:
    """触发增量快照：回填历史数据（分块、可断点续传，重启从上次块继续）。"""
    settings, tables_cfg = _load(args)
    _ensure_columns(settings, tables_cfg, allow_introspect=False)
    try:
        n = _send_snapshot_signal(settings, tables_cfg, only=args.only)
        log.info("✓ 已发送增量快照信号，回填 %d 张表（分块进行，可断点续传）", n)
        log.info("  进度可在监控面板/日志观察；中途重启会从上次的块继续，不会从头。")
        return 0
    except Exception as e:  # noqa: BLE001
        log.error("发送增量快照信号失败：%s", e)
        return 1


def cmd_reset_ck(args) -> int:
    """用 App 自己的配置(settings.yaml，密码正确)清空并重建 CK 目标库。"""
    settings, _ = _load(args)
    db = settings.clickhouse.database
    try:
        client = ck_client._client(settings.clickhouse)
        try:
            client.command(f"DROP DATABASE IF EXISTS {db}")
            client.command(f"CREATE DATABASE {db}")
        finally:
            client.close()
        log.info("✓ ClickHouse 库 %s 已清空重建", db)
        return 0
    except Exception as e:  # noqa: BLE001
        log.error("清空 CK 库失败：%s", e)
        return 1


def cmd_bootstrap(args) -> int:
    """一键初始化：等 Connect 就绪 → 建 CK 三对象 → 发布连接器（幂等，可重复跑）。"""
    import time

    settings, tables_cfg = _load(args)
    _ensure_columns(settings, tables_cfg, allow_introspect=args.introspect)

    # 1) 等待 Kafka Connect REST 就绪
    log.info("① 等待 Kafka Connect 就绪（%s，最多 %ds）...", settings.connect_url, args.wait)
    deadline = args.wait
    waited = 0
    while waited < deadline:
        if connect_client.ping(settings.connect_url):
            log.info("  ✓ Connect 就绪")
            break
        time.sleep(3)
        waited += 3
    else:
        log.error("Connect 在 %ds 内未就绪，放弃。可稍后重跑 bootstrap。", deadline)
        return 1

    # 2) 建 CK 三对象（IF NOT EXISTS，幂等）
    log.info("② 建 ClickHouse 三对象（%d 张表）...", len(tables_cfg.tables))
    ck_major = _detect_ck_major(settings)
    made = 0
    for t in tables_cfg.tables:
        tsql = ck_generator.build_table_sql(t, settings, ck_major=ck_major)
        ck_client.execute_statements(settings.clickhouse, tsql.ordered(), dry_run=False)
        made += 1
    log.info("  ✓ 已处理 %d 张表", made)

    # 3) 发布连接器（无则建、有则更新，幂等）
    log.info("③ 发布 Debezium 连接器 %s ...", settings.debezium.connector_name)
    connector = connector_generator.build_connector(tables_cfg.tables, settings)
    resp = connect_client.deploy(settings.connect_url, connector)
    log.info("  ✓ 连接器已发布：%s", resp.get("name", connector["name"]))

    # 4) schema_only 模式：连接器只从当前位点增量，需触发增量快照回填历史数据
    if settings.debezium.snapshot_mode == "schema_only" and not args.no_snapshot:
        log.info("④ 等连接器 RUNNING 后触发增量快照（回填历史，分块可续传）...")
        time.sleep(12)  # 等连接器 task + 信号消费者就绪，避免信号被漏读
        try:
            n = _send_snapshot_signal(settings, tables_cfg)
            log.info("  ✓ 已触发 %d 张表的增量快照", n)
        except Exception as e:  # noqa: BLE001
            log.warning("  触发增量快照失败（可稍后手动 snapshot）：%s", e)

    log.info("✔ 初始化完成，数据开始同步。打开监控面板查看状态。")
    return 0


def cmd_introspect(args) -> int:
    settings, tables_cfg = _load(args)
    schema = mysql_introspect.introspect_all(settings.mysql, tables_cfg.tables)
    path = mysql_introspect.save_cache(schema)
    total_cols = sum(len(v) for v in schema.values())
    log.info("✓ 内省完成：%d 张表 / %d 列 → %s", len(schema), total_cols, path)
    return 0


def cmd_generate(args) -> int:
    settings, tables_cfg = _load(args)
    _ensure_columns(settings, tables_cfg, allow_introspect=args.introspect)
    out = Path(args.out)

    # CK 三对象
    for t in tables_cfg.tables:
        tsql = ck_generator.build_table_sql(t, settings)
        written = ck_generator.write_sql_files(tsql, out / "clickhouse")
        for p in written:
            log.info("✓ CK SQL → %s", p)

    # 连接器 JSON（所有表汇总到一个连接器）
    connector = connector_generator.build_connector(tables_cfg.tables, settings)
    cpath = connector_generator.write_connector_file(connector, out / "connector")
    log.info("✓ 连接器 JSON → %s", cpath)
    log.info("产物目录：%s", out)
    return 0


def _detect_ck_major(settings) -> int | None:
    """检测 ClickHouse 版本用于建表自适应；失败则返回 None（用现代默认）。"""
    try:
        ver, major = ck_client.server_version(settings.clickhouse)
        log.info("ClickHouse 版本：%s（主版本 %d）", ver, major)
        return major
    except Exception as e:  # noqa: BLE001
        log.warning("无法检测 ClickHouse 版本（用默认设置继续）：%s", e)
        return None


def cmd_apply_ck(args) -> int:
    settings, tables_cfg = _load(args)
    _ensure_columns(settings, tables_cfg, allow_introspect=args.introspect)
    ck_major = None if args.dry_run else _detect_ck_major(settings)
    for t in tables_cfg.tables:
        tsql = ck_generator.build_table_sql(t, settings, ck_major=ck_major)
        log.info("→ 应用 CK 三对象：%s", t.target_table)
        ck_client.execute_statements(settings.clickhouse, tsql.ordered(), dry_run=args.dry_run)
    log.info("✓ 全部 CK DDL 处理完成%s", "（dry-run）" if args.dry_run else "")
    return 0


def cmd_deploy_connector(args) -> int:
    settings, tables_cfg = _load(args)
    connector = connector_generator.build_connector(tables_cfg.tables, settings)
    if args.dry_run:
        import json
        log.info("[dry-run] 将发布连接器：\n%s", json.dumps(connector, ensure_ascii=False, indent=2))
        return 0
    resp = connect_client.deploy(settings.connect_url, connector)
    log.info("✓ 连接器已发布：%s", resp.get("name", connector["name"]))
    return 0


def cmd_status(args) -> int:
    settings, tables_cfg = _load(args)
    # 连接器状态
    name = settings.debezium.connector_name
    try:
        st = connect_client.status(settings.connect_url, name)
        conn_state = st.get("connector", {}).get("state", "?")
        tasks = st.get("tasks", [])
        log.info("连接器 %s: %s（tasks: %s）", name, conn_state,
                 ", ".join(f"#{t.get('id')}={t.get('state')}" for t in tasks) or "无")
    except connect_client.ConnectError as e:
        log.error("连接器状态查询失败：%s", e)

    # CK 消费状态
    try:
        rows = ck_client.kafka_consumers_status(settings.clickhouse)
        if not rows:
            log.info("system.kafka_consumers 无记录（可能尚未开始消费）")
        for r in rows:
            exc = r.get("last_exception") or ""
            flag = "⚠ " if exc else "✓ "
            log.info("%s%s.%s messages=%s%s", flag, r.get("database"), r.get("table"),
                     r.get("num_messages_read"), f" last_exception={exc}" if exc else "")
    except ck_client.CKClientError as e:
        log.error("CK 消费状态查询失败：%s", e)
    return 0


def cmd_reconcile(args) -> int:
    settings, tables_cfg = _load(args)
    results = reconcile.reconcile_all(settings.mysql, settings.clickhouse, tables_cfg.tables)
    log.info("%-45s %12s %12s %8s %s", "表", "MySQL", "ClickHouse", "差异", "状态")
    all_ok = True
    for r in results:
        status_txt = "一致" if r.consistent else "不一致"
        if not r.consistent:
            all_ok = False
        log.info("%-45s %12d %12d %+8d %s", r.table, r.mysql_count, r.ck_count, r.diff, status_txt)
    return 0 if all_ok else 2


def cmd_serve(args) -> int:
    """启动监控 Web 服务（FastAPI + uvicorn）。"""
    import uvicorn

    # 把 --settings/--tables 通过环境变量传给 webapp
    if args.settings:
        os.environ["CDC_SETTINGS"] = str(args.settings)
    if args.tables:
        os.environ["CDC_TABLES"] = str(args.tables)
    log.info("监控服务启动：http://%s:%d", args.host, args.port)
    uvicorn.run("cdc_sync.webapp.server:app", host=args.host, port=args.port, log_level="info")
    return 0


# ----------------------------- 解析器 -----------------------------

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="cdc_sync",
        description="MySQL→Debezium→Kafka→ClickHouse CDC 同步工具",
    )
    p.add_argument("--settings", default=None, help="settings.yaml 路径（默认 config/settings.yaml）")
    p.add_argument("--tables", default=None, help="tables.yaml 路径（默认 config/tables.yaml）")
    p.add_argument("-v", "--verbose", action="store_true", help="调试日志")
    sub = p.add_subparsers(dest="command", required=True)

    sp = sub.add_parser("import-sql", help="解析 mysqldump/Navicat 导出的 .sql 生成 tables.yaml")
    sp.add_argument("--file", required=True, help="MySQL DDL 导出文件路径")
    sp.add_argument("--database", required=True, help="源库名（写入 source_database）")
    sp.add_argument("--target-database", default=None, help="CK 目标库（默认同源库名）")
    sp.add_argument("--prefix", default="", help="CK 目标表名前缀，如 ods_")
    sp.add_argument("--only", default=None, help="仅导入这些表（逗号分隔）")
    sp.add_argument("--skip", default=None, help="排除这些表（逗号分隔）")
    sp.add_argument("--out", default=str(config.DEFAULT_TABLES), help="输出 tables.yaml 路径")
    sp.set_defaults(func=cmd_import_sql)

    sp = sub.add_parser("introspect", help="连 MySQL 内省表结构并缓存")
    sp.set_defaults(func=cmd_introspect)

    sp = sub.add_parser("generate", help="生成 CK 三对象 SQL + 连接器 JSON")
    sp.add_argument("--out", default=str(OUT_DIR), help="产物输出目录（默认 out/）")
    sp.add_argument("--introspect", action="store_true", help="缺列时自动连 MySQL 内省")
    sp.set_defaults(func=cmd_generate)

    sp = sub.add_parser("apply-ck", help="对 ClickHouse 执行三对象 DDL")
    sp.add_argument("--introspect", action="store_true", help="缺列时自动连 MySQL 内省")
    sp.add_argument("--dry-run", action="store_true", help="只打印不执行")
    sp.set_defaults(func=cmd_apply_ck)

    sp = sub.add_parser("deploy-connector", help="向 Kafka Connect 发布/更新连接器")
    sp.add_argument("--dry-run", action="store_true", help="只打印不发布")
    sp.set_defaults(func=cmd_deploy_connector)

    sp = sub.add_parser("status", help="连接器状态 + CK kafka_consumers")
    sp.set_defaults(func=cmd_status)

    sp = sub.add_parser("reconcile", help="MySQL vs CK 行数对账")
    sp.set_defaults(func=cmd_reconcile)

    sp = sub.add_parser("serve", help="启动监控 Web 服务")
    sp.add_argument("--host", default="0.0.0.0", help="监听地址（默认 0.0.0.0）")
    sp.add_argument("--port", type=int, default=8000, help="监听端口（默认 8000）")
    sp.set_defaults(func=cmd_serve)

    sp = sub.add_parser("render-config", help="从 env 模板播种 literal 的 config/settings.yaml")
    sp.add_argument("--from", dest="from_template", default="config/settings.docker.yaml",
                    help="env 模板路径（默认 config/settings.docker.yaml）")
    sp.add_argument("--force", action="store_true", help="已存在也覆盖")
    sp.set_defaults(func=cmd_render_config)

    sp = sub.add_parser("bootstrap", help="一键初始化：等Connect→建CK表→发布连接器")
    sp.add_argument("--wait", type=int, default=180, help="等待 Connect 就绪的秒数（默认 180）")
    sp.add_argument("--introspect", action="store_true", help="缺列时自动连 MySQL 内省")
    sp.add_argument("--no-snapshot", action="store_true", help="不自动触发增量快照（schema_only 模式下）")
    sp.set_defaults(func=cmd_bootstrap)

    sp = sub.add_parser("reset-ck", help="清空并重建 CK 目标库（用 App 配置的正确密码）")
    sp.set_defaults(func=cmd_reset_ck)

    sp = sub.add_parser("snapshot", help="触发增量快照回填历史数据（分块、可断点续传）")
    sp.add_argument("--only", default=None, help="仅快照这些表（逗号分隔，表名或 db.表名）")
    sp.set_defaults(func=cmd_snapshot)

    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    _setup_logging(args.verbose)
    try:
        return args.func(args)
    except ConfigError as e:
        log.error("配置错误：%s", e)
        return 1
    except Exception as e:  # noqa: BLE001
        log.error("执行失败：%s", e)
        if args.verbose:
            raise
        return 1


if __name__ == "__main__":
    sys.exit(main())
