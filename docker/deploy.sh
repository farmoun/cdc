#!/usr/bin/env bash
# =============================================================
# 完整部署（不自动开始同步）：起全栈 → 建CK表 → 注册连接器(停止态)
# 同步的开启/停止由监控面板右上角「开启同步」按钮严格控制。
# 在 B 服(ClickHouse 所在机)执行：  bash deploy.sh
# =============================================================
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "✗ 缺少 .env：请先执行  cp .env.example .env  并填好两个密码(MYSQL_PASSWORD/CK_PASSWORD)"
  exit 1
fi

set -a; . ./.env; set +a
PORT="${MONITOR_PORT:-8080}"

if [ -f ../config/settings.yaml ]; then
  echo "ℹ 检测到 ../config/settings.yaml（可能是旧配置）。"
  echo "  若 Kafka/内部地址不对，建议删掉让容器按 .env 重新生成：rm -f ../config/settings.yaml"
fi

echo "▶ [1/3] 构建并启动全栈（Kafka + SchemaRegistry + Connect + 监控）..."
docker compose up -d --build

echo "▶ [2/3] 等待组件就绪（几十秒~几分钟，取决于镜像拉取）..."
for i in $(seq 1 30); do
  if docker compose ps --status running 2>/dev/null | grep -q cdc-monitor; then break; fi
  sleep 2
done

echo "▶ [3/3] 完整部署（建CK表 + 注册连接器，停止态，不自动同步）..."
docker compose exec -T cdc-monitor python main.py bootstrap --wait 240

echo ""
echo "✔ 部署完成！打开监控面板： http://<B服IP>:${PORT}"
echo "  一切就绪但**未开始同步**。点右上角「开启同步」按钮才开始抓取数据。"
echo "  （先到「配置」页各组件点「测试连接」确认全绿）"

