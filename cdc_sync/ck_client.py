"""ClickHouse 执行客户端：执行三对象 DDL、查询消费状态。"""
from __future__ import annotations

import logging

from .config import ClickHouseConf

log = logging.getLogger("cdc_sync.ck_client")


class CKClientError(Exception):
    pass


def _client(conf: ClickHouseConf):
    try:
        import clickhouse_connect
    except ImportError as e:  # pragma: no cover
        raise CKClientError("缺少依赖 clickhouse-connect，请先 pip install -r requirements.txt") from e
    try:
        return clickhouse_connect.get_client(
            host=conf.host,
            port=conf.port,
            username=conf.user,
            password=conf.password,
            database=conf.database,
            secure=conf.secure,
            connect_timeout=10,
        )
    except Exception as e:  # noqa: BLE001
        raise CKClientError(f"连接 ClickHouse 失败 {conf.host}:{conf.port} — {e}") from e


def execute_statements(conf: ClickHouseConf, statements: list[tuple[str, str]], *, dry_run: bool = False) -> None:
    """按顺序执行 (label, sql) 列表。dry_run 只打印不执行。"""
    if dry_run:
        for label, sql in statements:
            log.info("[dry-run] 将执行 %s:\n%s", label, sql)
        return

    client = _client(conf)
    try:
        for label, sql in statements:
            log.info("执行 %s ...", label)
            for stmt in _split_sql(sql):
                client.command(stmt)
            log.info("✓ %s 完成", label)
    finally:
        client.close()


def set_consumption(conf: ClickHouseConf, database: str, mv_names: list[str], *, enabled: bool) -> dict:
    """启/停 CK 对 Kafka 的消费：DETACH/ATTACH 物化视图（MV 是消费驱动，摘掉即停消费）。

    每张表 best-effort，单张失败不影响其它。返回 {ok:[...], skipped:[...]}。
    """
    client = _client(conf)
    ok, skipped = [], []
    try:
        for mv in mv_names:
            try:
                if enabled:
                    client.command(f"ATTACH TABLE {database}.{mv}")
                else:
                    client.command(f"DETACH TABLE IF EXISTS {database}.{mv}")
                ok.append(mv)
            except Exception as e:  # noqa: BLE001
                # ATTACH 一个未 detach 的表会报错→视为已就绪；DETACH 不存在→忽略
                skipped.append(mv)
                log.debug("%s %s 跳过：%s", "ATTACH" if enabled else "DETACH", mv, e)
    finally:
        client.close()
    return {"ok": ok, "skipped": skipped}


def _split_sql(sql: str) -> list[str]:
    """按分号切分多语句，过滤纯注释/空行。"""
    parts = []
    for chunk in sql.split(";"):
        # 去掉整行注释
        lines = [ln for ln in chunk.splitlines() if not ln.strip().startswith("--")]
        cleaned = "\n".join(lines).strip()
        if cleaned:
            parts.append(cleaned)
    return parts


def server_version(conf: ClickHouseConf) -> tuple[str, int]:
    """返回 (版本字符串, 主版本号)。查询失败抛 CKClientError。"""
    client = _client(conf)
    try:
        ver = str(client.query("SELECT version()").result_rows[0][0])
        try:
            major = int(ver.split(".")[0])
        except (ValueError, IndexError):
            major = 0
        return ver, major
    except Exception as e:  # noqa: BLE001
        raise CKClientError(f"查询 version() 失败 — {e}") from e
    finally:
        client.close()


def kafka_consumers_status(conf: ClickHouseConf) -> list[dict]:
    """查询 system.kafka_consumers，返回消费状态。

    不同 CK 版本该系统表列名有差异（如 26.x 无 last_exception，改为 exceptions 数组），
    故 SELECT * 后在 Python 侧兼容取字段。
    """
    client = _client(conf)
    try:
        result = client.query("SELECT * FROM system.kafka_consumers")
        cols = result.column_names
        raw = [dict(zip(cols, row)) for row in result.result_rows]
    except Exception as e:  # noqa: BLE001
        raise CKClientError(f"查询 kafka_consumers 失败 — {e}") from e
    finally:
        client.close()

    out = []
    for r in raw:
        # 异常字段：老版本 last_exception(String)，新版本 exceptions(数组/嵌套)
        exc = r.get("last_exception")
        if not exc:
            ex = r.get("exceptions")
            if isinstance(ex, dict):  # 可能是 {text:[...], time:[...]}
                texts = ex.get("text") or []
                exc = "; ".join(str(x) for x in texts if x) if isinstance(texts, (list, tuple)) else str(texts)
            elif isinstance(ex, (list, tuple)):
                exc = "; ".join(str(x) for x in ex if x)
            elif ex:
                exc = str(ex)
        out.append({
            "database": r.get("database"),
            "table": r.get("table"),
            "num_messages_read": r.get("num_messages_read"),
            "last_exception": exc or "",
        })
    return out


def _jsonsafe(v):
    """把不可 JSON 序列化的值（datetime/Decimal/bytes 等）转成字符串。"""
    if v is None or isinstance(v, (bool, int, float, str)):
        return v
    try:
        return str(v)
    except Exception:  # noqa: BLE001
        return repr(v)


def run_query(conf: ClickHouseConf, sql: str, max_rows: int = 1000) -> dict:
    """执行任意 SQL，返回 {columns, rows, row_count, truncated}。

    主要面向 SELECT/SHOW/DESCRIBE；写/DDL 语句若无结果集会返回空表。
    结果行数超过 max_rows 时截断，标记 truncated=True。
    """
    client = _client(conf)
    try:
        result = client.query(sql)
        cols = list(result.column_names or [])
        rows = result.result_rows or []
        truncated = len(rows) > max_rows
        rows = rows[:max_rows]
        out_rows = [[_jsonsafe(v) for v in row] for row in rows]
        return {"columns": cols, "rows": out_rows, "row_count": len(out_rows), "truncated": truncated}
    finally:
        client.close()


def count_alive(conf: ClickHouseConf, database: str, table: str, del_col: str = "is_deleted") -> int:
    """统计正式表有效行数（FINAL + 过滤软删除）。"""
    client = _client(conf)
    try:
        result = client.query(
            f"SELECT count() FROM {database}.{table} FINAL WHERE {del_col} = 0"
        )
        return int(result.result_rows[0][0])
    finally:
        client.close()
