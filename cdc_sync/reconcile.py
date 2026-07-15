"""数据对账：MySQL 源表行数 vs ClickHouse 正式表有效行数。

- 行数级：MySQL COUNT(*) vs CK count() FINAL WHERE is_deleted=0。
- 说明：源表若含物理删除，CK 为软删除，二者按「存活行」口径对齐。
"""
from __future__ import annotations

import logging
from dataclasses import dataclass

from .config import MySQLConf, ClickHouseConf, TableDef
from .mysql_introspect import _connect as _mysql_connect
from . import ck_client

log = logging.getLogger("cdc_sync.reconcile")


@dataclass
class ReconcileResult:
    table: str
    mysql_count: int
    ck_count: int

    @property
    def diff(self) -> int:
        return self.ck_count - self.mysql_count

    @property
    def consistent(self) -> bool:
        return self.diff == 0


def _mysql_count(conf: MySQLConf, database: str, table: str) -> int:
    conn = _mysql_connect(conf)
    try:
        with conn.cursor() as cur:
            cur.execute(f"SELECT COUNT(*) AS c FROM `{database}`.`{table}`")
            row = cur.fetchone()
            return int(row["c"])
    finally:
        conn.close()


def reconcile_table(my: MySQLConf, ck: ClickHouseConf, table: TableDef) -> ReconcileResult:
    from . import ck_generator
    _, del_col = ck_generator.meta_column_names(table)
    m = _mysql_count(my, table.source_database, table.source_table)
    c = ck_client.count_alive(ck, table.target_database, table.target_table, del_col=del_col)
    return ReconcileResult(
        table=f"{table.source_database}.{table.source_table} → {table.target_table}",
        mysql_count=m,
        ck_count=c,
    )


def reconcile_all(my: MySQLConf, ck: ClickHouseConf, tables: list[TableDef]) -> list[ReconcileResult]:
    results = []
    for t in tables:
        try:
            results.append(reconcile_table(my, ck, t))
        except Exception as e:  # noqa: BLE001
            log.error("对账 %s 失败: %s", t.target_table, e)
    return results
