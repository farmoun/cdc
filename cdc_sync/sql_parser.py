"""解析 MySQL DDL 导出文件（mysqldump / Navicat）为表结构。

仅需读 CREATE TABLE 语句，离线提取每张表的列（名/类型/可空/主键），
无需连接真实 MySQL。产出可直接写入 tables.yaml 或 schema_cache。
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

from .config import ColumnDef

# 拆分每个 CREATE TABLE `name` ( ... ) ; 块
_CREATE_RE = re.compile(
    r"CREATE\s+TABLE\s+`(?P<name>[^`]+)`\s*\((?P<body>.*?)\)\s*ENGINE",
    re.I | re.S,
)

# 主键行：PRIMARY KEY (`a`, `b`, ...)
_PK_RE = re.compile(r"PRIMARY\s+KEY\s*\((?P<cols>[^)]*)\)", re.I)

# 列定义行：`col` <type>(...) [unsigned] ... [NOT NULL]
_COL_RE = re.compile(
    r"^\s*`(?P<name>[^`]+)`\s+"
    r"(?P<base>[a-zA-Z]+)"
    r"(?:\s*\((?P<args>[^)]*)\))?"
    r"(?P<mods>(?:\s+(?:unsigned|zerofill))*)",
    re.I,
)

# 约束/索引行前缀，需跳过
_SKIP_PREFIXES = (
    "PRIMARY KEY", "UNIQUE", "KEY", "INDEX", "CONSTRAINT", "FOREIGN",
    "FULLTEXT", "SPATIAL", "CHECK",
)


@dataclass
class ParsedTable:
    name: str
    columns: list[ColumnDef]
    primary_key: list[str]


def _clean_key_cols(raw: str) -> list[str]:
    """把 '`a` ASC, `b` ASC' 清洗为 ['a', 'b']。"""
    cols = []
    for part in raw.split(","):
        m = re.search(r"`([^`]+)`", part)
        if m:
            cols.append(m.group(1))
    return cols


def _parse_body(body: str) -> tuple[list[ColumnDef], list[str]]:
    columns: list[ColumnDef] = []
    pk_cols: list[str] = []

    for raw_line in body.splitlines():
        line = raw_line.strip()
        if not line:
            continue

        upper = line.upper()
        if any(upper.startswith(p) for p in _SKIP_PREFIXES):
            pk = _PK_RE.search(line)
            if pk:
                pk_cols = _clean_key_cols(pk.group("cols"))
            continue

        if not line.startswith("`"):
            continue

        m = _COL_RE.match(line)
        if not m:
            continue

        base = m.group("base")
        args = m.group("args")
        mods = m.group("mods") or ""
        mysql_type = base
        if args is not None:
            mysql_type += f"({args})"
        mysql_type += mods  # 含前导空格，如 ' unsigned'
        mysql_type = mysql_type.strip()

        # NOT NULL → 不可空；否则可空（含 DEFAULT NULL）
        rest = line[m.end():]
        nullable = re.search(r"\bNOT\s+NULL\b", rest, re.I) is None

        columns.append(
            ColumnDef(name=m.group("name"), mysql_type=mysql_type, nullable=nullable, is_pk=False)
        )

    # 标注主键列
    pk_set = set(pk_cols)
    for c in columns:
        if c.name in pk_set:
            c.is_pk = True

    return columns, pk_cols


def parse_text(text: str) -> list[ParsedTable]:
    """从 SQL DDL 文本解析所有 CREATE TABLE。"""
    tables: list[ParsedTable] = []
    for m in _CREATE_RE.finditer(text):
        name = m.group("name")
        cols, pk = _parse_body(m.group("body"))
        if cols:
            tables.append(ParsedTable(name=name, columns=cols, primary_key=pk))
    return tables


def parse_file(path: Path | str) -> list[ParsedTable]:
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    return parse_text(text)


def build_tables_doc(parsed: list[ParsedTable], *, database: str, target_database: str | None = None,
                     prefix: str = "", only: set[str] | None = None, skip: set[str] | None = None) -> dict:
    """把解析结果转成 tables.yaml 的 dict 结构（供 CLI 与 Web 复用）。"""
    skip = skip or set()
    tables_out = []
    for pt in parsed:
        if only and pt.name not in only:
            continue
        if pt.name in skip:
            continue
        target = f"{prefix}{pt.name}" if prefix else pt.name
        entry = {
            "source_database": database,
            "source_table": pt.name,
            "target_table": target,
            "columns": [
                {"name": c.name, "mysql_type": c.mysql_type, "nullable": c.nullable, "is_pk": c.is_pk}
                for c in pt.columns
            ],
        }
        if not pt.primary_key:
            entry["order_by"] = ""  # 无主键，需人工指定唯一键
        tables_out.append(entry)
    return {"target_database": target_database or database, "tables": tables_out}
