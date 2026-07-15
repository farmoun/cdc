# CDC 监控 Web 应用 + cdc_sync CLI
FROM python:3.12-slim

WORKDIR /app

# 系统依赖（clickhouse-connect/kafka-python 纯 Python，基本无需编译）
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 拷贝项目（config/out 在 compose 中以 volume 挂载覆盖，便于运维改动持久化）
COPY cdc_sync ./cdc_sync
COPY templates ./templates
COPY config ./config
COPY main.py ./

EXPOSE 8000

# 让 webapp/CLI 统一读可写的 config/settings.yaml（卷持久化，可被网页保存）
ENV CDC_SETTINGS=config/settings.yaml
ENV CDC_TABLES=config/tables.yaml

HEALTHCHECK --interval=20s --timeout=5s --retries=5 \
  CMD curl -f http://localhost:8000/api/overview || exit 1

# 首启：若 settings.yaml 不存在，从 env 模板播种一次；随后启动监控服务
CMD ["sh", "-c", "python main.py render-config --from config/settings.docker.yaml && python main.py --settings config/settings.yaml serve --host 0.0.0.0 --port 8000"]
