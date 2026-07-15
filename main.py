"""CDC 同步工具入口。

用法示例：
    python main.py --help
    python main.py generate                 # 用 tables.yaml 内联列离线生成产物
    python main.py introspect               # 连 MySQL 内省表结构
    python main.py apply-ck --dry-run       # 预览 CK DDL
    python main.py deploy-connector         # 发布 Debezium 连接器
    python main.py status                   # 查看链路状态
    python main.py reconcile                # 行数对账
"""
import sys

from cdc_sync.cli import main

if __name__ == "__main__":
    sys.exit(main())
