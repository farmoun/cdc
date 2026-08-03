"""MySQL → ClickHouse 类型映射。

输入是 MySQL information_schema 的 COLUMN_TYPE 文本，如：
  'bigint unsigned', 'int(11)', 'decimal(18,2)', 'varchar(64)', 'datetime(3)'
输出是 ClickHouse 类型，如：
  'UInt64', 'Int32', 'Decimal(18,2)', 'String', 'DateTime64(3)'

设计要点（对齐设计方案 §7）：
- unsigned → 无符号 CK 类型；有符号 → 有符号。
- 可空列在正式表包一层 Nullable(T)；但 ORDER BY / 主键列不允许 Nullable。
- datetime/timestamp 带小数秒精度 → DateTime64(n)。
"""
from __future__ import annotations

import re

# 基础类型映射（有符号, 无符号）
_INT_MAP = {
    "tinyint": ("Int8", "UInt8"),
    "smallint": ("Int16", "UInt16"),
    "mediumint": ("Int32", "UInt32"),
    "int": ("Int32", "UInt32"),
    "integer": ("Int32", "UInt32"),
    "bigint": ("Int64", "UInt64"),
}

# 直接映射为 String 的类型
_STRING_TYPES = {
    "char", "varchar", "tinytext", "text", "mediumtext", "longtext",
    "json", "enum", "set", "binary", "varbinary",
    "tinyblob", "blob", "mediumblob", "longblob",
    "time", "year",  # 简化为字符串/数值，避免 CK 不兼容
}

_TYPE_RE = re.compile(r"^\s*(?P<base>[a-z_]+)\s*(?:\((?P<args>[^)]*)\))?\s*(?P<rest>.*)$", re.I)


class TypeMapError(Exception):
    pass


def map_type(mysql_type: str, nullable: bool = False, *, allow_nullable: bool = True) -> str:
    """把 MySQL COLUMN_TYPE 映射为 ClickHouse 类型。

    :param nullable: 源列是否可空。
    :param allow_nullable: 是否允许输出 Nullable(...)。ORDER BY/主键列应传 False。
    """
    ck = _map_base(mysql_type)
    if nullable and allow_nullable:
        return f"Nullable({ck})"
    return ck


def _map_base(mysql_type: str) -> str:
    m = _TYPE_RE.match(mysql_type.strip())
    if not m:
        raise TypeMapError(f"无法解析 MySQL 类型: {mysql_type!r}")
    base = m.group("base").lower()
    args = (m.group("args") or "").strip()
    rest = (m.group("rest") or "").lower()
    unsigned = "unsigned" in rest or "unsigned" in mysql_type.lower()

    # 整数
    if base in _INT_MAP:
        signed_t, unsigned_t = _INT_MAP[base]
        # tinyint(1) 常表示布尔，但为通用性仍映射为 Int8/UInt8
        return unsigned_t if unsigned else signed_t

    # bool / boolean
    if base in ("bool", "boolean"):
        return "UInt8"

    # 定点
    if base in ("decimal", "numeric", "dec", "fixed"):
        if args:
            parts = [p.strip() for p in args.split(",")]
            precision = parts[0] if parts else "18"
            scale = parts[1] if len(parts) > 1 else "0"
            return f"Decimal({precision},{scale})"
        return "Decimal(18,4)"

    # 浮点
    if base in ("float",):
        return "Float32"
    if base in ("double", "real"):
        return "Float64"

    # 日期时间
    if base == "date":
        return "Date"
    if base in ("datetime", "timestamp"):
        # 带精度 datetime(3) → DateTime64(3)
        if args and args.isdigit() and int(args) > 0:
            return f"DateTime64({args})"
        return "DateTime"

    # 字符串族
    if base in _STRING_TYPES:
        return "String"

    if base == "bit":
        return "UInt64"

    # 兜底：转 String，保证不中断（宁可宽松）
    return "String"


def is_time_type(mysql_type: str) -> bool:
    """判断是否为可用于 PARTITION BY toYYYYMM 的时间列（date/datetime/timestamp）。"""
    base = _TYPE_RE.match(mysql_type.strip())
    if not base:
        return False
    return base.group("base").lower() in ("date", "datetime", "timestamp")


def is_int_type(mysql_type: str) -> bool:
    """判断是否为整数类型（bigint/int/...）。

    本项目大量表用 bigint 存 Unix 时间戳（如 logs.created_at），
    这类列同样可以分区，但需要先 toDateTime 转换 —— 见 ck_generator._resolve_partition。
    """
    m = _TYPE_RE.match(mysql_type.strip())
    if not m:
        return False
    return m.group("base").lower() in _INT_MAP
