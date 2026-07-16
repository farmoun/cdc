#!/usr/bin/env bash
# =============================================================
# 重置到原始状态：清空 Kafka + ClickHouse 目标库，恢复到刚部署的样子
#
# 场景：换 MySQL 源 / 读一个新数据库时，旧的 binlog 位点在新服务器上不存在，
# 连接器会报：
#   "The connector is trying to read binlog starting at ... mysql-bin.000172 ...
#    but this is no longer available on the server."
# 本脚本清掉全部旧状态（Kafka 位点/topic/schema历史 + CK 数据），
# 之后重新配置新库并 bootstrap，即从新库全量快照重新开始。
#
# 用法： bash reset.sh          # 交互确认
#        bash reset.sh -y       # 跳过确认
# =============================================================
set -euo pipefail
cd "$(dirname "$0")"
[ -f .env ] || { echo "✗ 缺少 .env"; exit 1; }
set -a; . ./.env; set +a

YES=0
[ "${1:-}" = "-y" ] && YES=1

echo "⚠  将执行以下清理（不可恢复）："
echo "   1) 删除 Debezium 连接器：${DBZ_CONNECTOR_NAME}"
echo "   2) 清空 ClickHouse 库：${CK_DATABASE}（DROP + CREATE）"
echo "   3) 清空 Kafka 全部数据（topic / 消费位点 / 连接器offset / schema历史）"
echo ""
if [ "$YES" != "1" ]; then
  read -r -p "确认重置？输入 yes 继续: " ans
  [ "$ans" = "yes" ] || { echo "已取消"; exit 0; }
fi

# 1) 删除连接器（若存在）
echo "▶ [1/4] 删除连接器 ${DBZ_CONNECTOR_NAME} ..."
docker compose exec -T connect curl -s -o /dev/null -w "  HTTP %{http_code}\n" \
  -X DELETE "http://localhost:8083/connectors/${DBZ_CONNECTOR_NAME}" 2>/dev/null || echo "  (连接器不存在或 Connect 未起，跳过)"

# 2) 清空 ClickHouse 目标库（趁监控容器还在）
echo "▶ [2/4] 清空 ClickHouse ${CK_DATABASE} 库 ..."
docker compose exec -T cdc-monitor python - <<PY || echo "  (CK 清空失败，可稍后手动 DROP DATABASE)"
import clickhouse_connect as c
cli = c.get_client(host="${CK_HOST}", port=${CK_HTTP_PORT}, username="${CK_USER}", password="${CK_PASSWORD}")
cli.command("DROP DATABASE IF EXISTS ${CK_DATABASE}")
cli.command("CREATE DATABASE ${CK_DATABASE}")
print("  CK ${CK_DATABASE} 已重置")
PY

# 3) 停栈并清空 Kafka 数据卷（清掉所有 topic / 位点 / schema历史）
echo "▶ [3/4] 停栈并清空 Kafka 数据卷 ..."
docker compose down -v

# 4) 重新起栈（全新 Kafka / Connect / SchemaRegistry / 监控）
echo "▶ [4/4] 重新起栈 ..."
docker compose up -d

echo ""
echo "✔ 已恢复到原始状态。切换到新库的步骤："
echo "   1) 改配置：监控页「配置」改 MySQL 地址/库名 并保存；或改 .env 后  bash update.sh --reseed"
echo "   2) 导入新库表结构：配置页「导入SQL」上传 .sql，或"
echo "        docker compose exec -T cdc-monitor python main.py import-sql --file config/新库.sql --database 新库名"
echo "   3) 重新初始化（等组件就绪约1分钟）： docker compose exec -T cdc-monitor python main.py bootstrap"
