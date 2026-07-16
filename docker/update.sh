#!/usr/bin/env bash
# =============================================================
# 更新脚本：在 B 服拉取最新代码并让监控容器加载
#   bash update.sh            # git pull + 重建监控（加载新代码/模板）
#   bash update.sh --build    # 顺便重建镜像（加了 requirements 新依赖时用，如导出的 openpyxl/xlwt）
#   bash update.sh --reseed   # 顺便按最新 .env 重新生成 settings.yaml（覆盖网页里改过的配置）
#   bash update.sh --boot     # 重建后再跑一次 bootstrap（建CK表+发连接器）
# =============================================================
set -euo pipefail
cd "$(dirname "$0")"

BUILD=0
RESEED=0
BOOT=0
for a in "$@"; do
  case "$a" in
    --build)  BUILD=1 ;;
    --reseed) RESEED=1 ;;
    --boot)   BOOT=1 ;;
  esac
done

# 1) 拉取最新代码（若是 git 仓库）
if git -C .. rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "▶ git pull 拉取最新代码..."
  git -C .. pull --ff-only
else
  echo "ℹ 非 git 仓库，跳过 pull（用上传解压的方式更新代码即可）"
fi

# 2) 可选：按最新 .env 重新播种配置
if [ "$RESEED" = "1" ]; then
  echo "▶ 删除 settings.yaml，容器将按最新 .env 重新播种..."
  rm -f ../config/settings.yaml
fi

# 3) 用最新代码/模板/.env 重建监控容器（挂载卷让宿主机代码生效）
if [ "$BUILD" = "1" ]; then
  echo "▶ 重建监控镜像(装新依赖)并启动..."
  docker compose up -d --build --force-recreate cdc-monitor
else
  echo "▶ 重建监控容器..."
  docker compose up -d --force-recreate cdc-monitor
fi

echo "▶ 等待监控就绪..."
sleep 3

# 4) 可选：重新初始化
if [ "$BOOT" = "1" ]; then
  echo "▶ 重新初始化（建 CK 表 + 发布连接器）..."
  docker compose exec -T cdc-monitor python main.py bootstrap
fi

echo "✔ 完成。刷新浏览器页面即可。"
