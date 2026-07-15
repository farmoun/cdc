#!/usr/bin/env bash
# =============================================================
# 一键部署 + 初始化：构建启动全栈 → 建 CK 表 → 发布连接器
# 在 B 服(ClickHouse 所在机)执行：  bash deploy.sh
# =============================================================
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "✗ 缺少 .env：请先执行  cp .env.example .env  并填好两个密码(MYSQL_PASSWORD/CK_PASSWORD)"
  exit 1
fi

# 加载 .env 以取 MONITOR_PORT（仅用于末尾提示）
set -a; . ./.env; set +a
PORT="${MONITOR_PORT:-8080}"

# 若存在 docker 外手工填过的旧配置，提示（不自动删，避免误伤）
if [ -f ../config/settings.yaml ]; then
  echo "ℹ 检测到 ../config/settings.yaml（可能是 docker 外手工填的）。"
  echo "  若里面的 Kafka/内部地址不对，建议删掉让容器按 .env 重新生成：rm -f ../config/settings.yaml"
fi

echo "▶ [1/3] 构建并启动全栈（Kafka + SchemaRegistry + Connect + 监控）..."
docker compose up -d --build

echo "▶ [2/3] 等待组件就绪（几十秒~几分钟，取决于镜像拉取）..."
# 等 cdc-monitor 容器起来
for i in $(seq 1 30); do
  if docker compose ps --status running 2>/dev/null | grep -q cdc-monitor; then break; fi
  sleep 2
done

echo "▶ [3/3] 初始化：建 CK 表 + 发布连接器..."
docker compose exec -T cdc-monitor python main.py bootstrap --wait 240

echo ""
echo "✔ 全部完成！打开监控面板： http://<B服IP>:${PORT}"
echo "  （面板「配置」页各组件点「测试连接」应全绿；数据已开始同步）"
