"""从 MySQL information_schema 内省表结构。

产出每张表的 ColumnDef 列表（列名/COLUMN_TYPE/是否可空/是否主键），
供生成器构建 CK 三对象与连接器。结果可缓存到 config/schema_cache.json。
"""
from __future__ import annotations

import json
from pathlib import Path

from .config import ColumnDef, MySQLConf, TableDef, ROOT

SCHEMA_CACHE = ROOT / "config" / "schema_cache.json"


class IntrospectError(Exception):
    pass


def _connect(conf: MySQLConf):
    try:
        import pymysql
    except ImportError as e:  # pragma: no cover
        raise IntrospectError("缺少依赖 PyMySQL，请先 pip install -r requirements.txt") from e
    try:
        return pymysql.connect(
            host=conf.host,
            port=conf.port,
            user=conf.user,
            password=conf.password,
            charset=conf.charset,
            cursorclass=pymysql.cursors.DictCursor,
            connect_timeout=10,
        )
    except Exception as e:  # noqa: BLE001
        raise IntrospectError(f"连接 MySQL 失败 {conf.host}:{conf.port} — {e}") from e


def introspect_table(conf: MySQLConf, database: str, table: str) -> list[ColumnDef]:
    """读取单表的列定义（按序），标注可空与主键。"""
    sql = (
        "SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY, ORDINAL_POSITION "
        "FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA=%s AND TABLE_NAME=%s "
        "ORDER BY ORDINAL_POSITION"
    )
    conn = _connect(conf)
    try:
        with conn.cursor() as cur:
            cur.execute(sql, (database, table))
            rows = cur.fetchall()
    finally:
        conn.close()

    if not rows:
        raise IntrospectError(f"表不存在或无列: {database}.{table}")

    cols: list[ColumnDef] = []
    for r in rows:
        cols.append(
            ColumnDef(
                name=r["COLUMN_NAME"],
                mysql_type=r["COLUMN_TYPE"],
                nullable=(r["IS_NULLABLE"].upper() == "YES"),
                is_pk=(r["COLUMN_KEY"].upper() == "PRI"),
            )
        )
    return cols


def introspect_all(conf: MySQLConf, tables: list[TableDef]) -> dict[str, list[ColumnDef]]:
    """内省全部表，返回 {"db.table": [ColumnDef,...]}，并就地填充 TableDef.columns。"""
    result: dict[str, list[ColumnDef]] = {}
    for t in tables:
        cols = introspect_table(conf, t.source_database, t.source_table)
        t.columns = cols
        result[f"{t.source_database}.{t.source_table}"] = cols
    return result


def save_cache(schema: dict[str, list[ColumnDef]], path: Path | None = None) -> Path:
    path = path or SCHEMA_CACHE
    serializable = {
        key: [
            {"name": c.name, "mysql_type": c.mysql_type, "nullable": c.nullable, "is_pk": c.is_pk}
            for c in cols
        ]
        for key, cols in schema.items()
    }
    path.write_text(json.dumps(serializable, ensure_ascii=False, indent=2), encoding="utf-8")
    return path


def load_cache(path: Path | None = None) -> dict[str, list[ColumnDef]]:
    path = path or SCHEMA_CACHE
    if not path.exists():
        return {}
    raw = json.loads(path.read_text(encoding="utf-8"))
    return {
        key: [ColumnDef(**c) for c in cols]
        for key, cols in raw.items()
    }


def apply_cache_to_tables(tables: list[TableDef], cache: dict[str, list[ColumnDef]]) -> None:
    """把缓存里的列填充到未内联 columns 的表上。"""
    for t in tables:
        if t.has_columns():
            continue
        key = f"{t.source_database}.{t.source_table}"
        if key in cache:
            t.columns = cache[key]
