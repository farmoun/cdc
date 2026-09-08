# CDC 同步栈 · Docker 部署与跨服务器运维手册

本栈部署在 **ClickHouse 所在服务器（B 服）**。MySQL 在 **A 服**，ClickHouse 是 B 服**宿主机原生**安装，二者均作为**外部服务**由 `.env` 配置。

```
A 服 (MySQL) ──binlog──▶ [B 服 docker]  kafka + schema-registry + connect(Debezium) + cdc-monitor
                                              │
                                              ▼ (宿主机 localhost:9094)
                                       B 服宿主机原生 ClickHouse (Kafka 引擎消费)
```

组件与端口（B 服宿主机）：

| 组件 | 端口 | 说明 |
|------|------|------|
| cdc-monitor（监控面板） | `8080` | 浏览器打开 `http://B服IP:8080`，需登录（默认 `root` / `cdc@123`） |
| Kafka（供宿主 CK） | `9094` | 原生 CK 用 `localhost:9094` |
| Schema Registry | `8081` | |
| Kafka Connect REST | `8083` | |

> **面板登录**：监控面板所有 `/api` 请求都要求先登录。用户名/密码读取 `config/settings.yaml`
> 的 `panel` 段（由 `.env` 的 `CDC_PANEL_USER`/`CDC_PANEL_PASSWORD` 播种），也可在面板「配置」页直接改。
> 默认（未配置时）为 `root` / `cdc@123`，生产必改。登录后会话（HttpOnly Cookie）默认 12h 生效。

> **默认单节点 Kafka**（约 3~4G 内存，一键即起）。需要高可用（3 节点 RF=3、容忍单节点故障）时改用
> `docker compose -f docker-compose.ha.yml up -d --build`，并按 `.env` 注释调整两个 broker 地址。
>
> **重要**：Kafka / Schema Registry / Kafka Connect 都是本栈**自己启动的容器**，不是外部服务。
> 监控面板也在这套 docker 里，因此配置里的 `kafka:9092`、`http://schema-registry:8081`、
> `http://connect:8083` 是 docker 内部名——部署后自动解析，之前在 docker 外测失败属正常。

---

## 一、A 服（MySQL）准备

1. 开启 binlog（`my.cnf`，见《01-设计方案.md》§4.1）：`binlog_format=ROW`、`binlog_row_image=FULL`、`gtid_mode=ON` 等，重启生效。
2. 建同步账号：
   ```sql
   CREATE USER 'debezium'@'%' IDENTIFIED BY 'StrongPass@123';
   GRANT SELECT, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'debezium'@'%';
   FLUSH PRIVILEGES;
   ```
3. **放行网络**：允许 B 服 IP 访问 A 服 `3306`（安全组/防火墙/`bind-address`）。

## 二、B 服（ClickHouse + 本栈）准备

1. 确认原生 ClickHouse 可用，并**允许容器访问**：CK 监听 `0.0.0.0`（`listen_host`），HTTP `8123` 对本机开放。
2. 建目标库：`CREATE DATABASE IF NOT EXISTS yibuapi;`
3. 安装 Docker + Docker Compose 插件。

---

## 三、一键启动本栈（在 B 服执行）

```bash
cd docker
cp .env.example .env
vim .env                      # 只需改两个密码：MYSQL_PASSWORD、CK_PASSWORD（IP 已按你的环境预填）

# 若之前在 docker 外手工填过网页配置，删掉旧的 settings.yaml 让容器按 .env 重新播种一份正确的
rm -f ../config/settings.yaml
```

**方式 A · 全自动一键（推荐）**：起栈 + 建 CK 表 + 发布连接器，一条命令搞定：

```bash
bash deploy.sh
```

**方式 B · 手动分步**：

```bash
docker compose up -d --build                                  # 起栈
docker compose ps                                             # 待 healthy
docker compose exec -T cdc-monitor python main.py bootstrap   # 建表+发布连接器
```

启动后浏览器打开 **`http://B服IP:8080`**（B 服 IP + 8080）。这次是**容器里的监控**，
之前失败的 Kafka / Schema Registry / Kafka Connect 三个「测试连接」现在都会变绿。

> `.env` 里请按实际环境填写：`MYSQL_HOST`（A 服务器 IP）、`CK_HOST`（默认 `host.docker.internal`，与本栈同机时有效）。
> 若 CK 测试不通，把 `.env` 的 `CK_HOST` 改成 B 服的实际 IP 再 `docker compose up -d`。
>
> `bootstrap` / `deploy.sh` 都是**幂等**的，可反复执行（建表用 IF NOT EXISTS，连接器用更新）。

## 四、接入表 → 建 CK 表 → 发布连接器

> 用了 `deploy.sh` / `bootstrap` 的话，这一步**已自动完成**，下面仅作手动/重跑参考。

表清单 `config/tables.yaml` 已由 `yibuapi.sql` 生成（35 表）。**直接在监控面板「配置」页**可查看/编辑，
或用「导入 SQL」重新上传 `.sql` 生成。

建 CK 三对象 + 发布连接器，**在监控面板点按钮即可**（配置页/操作区）：
- 「建 CK 表(三对象)」→ 在 ClickHouse 建好 35 张表的 Kafka 表/正式表/物化视图
- 「发布/更新连接器」→ 把 Debezium 连接器发到 Connect，开始抓 binlog

命令行等价（可选）：
```bash
docker compose exec cdc-monitor python main.py apply-ck
docker compose exec cdc-monitor python main.py deploy-connector
```

## 五、监控

浏览器打开 `http://B服IP:8080`：
- 组件健康卡：配置 / 连接器 / Kafka / ClickHouse
- 连接器任务状态、Kafka 各 topic 堆积(lag)、CK 消费状态、数据对账
- 操作按钮：发布/重启连接器、建 CK 表、运行对账
- **配置页**：所有连接配置可视化编辑 + 逐组件「测试连接」

命令行等价：
```bash
docker compose exec cdc-monitor python main.py status
docker compose exec cdc-monitor python main.py reconcile
```

---

## 六、跨服务器排障

| 现象 | 排查 |
|------|------|
| 三个测试仍 `getaddrinfo failed` | 监控没跑在 docker 里。必须用容器版监控（`http://B服IP:8080`），别在 docker 外单独跑 |
| 连接器 FAILED，连不上 MySQL | A 服 3306 是否放行 B 服 IP；账号权限；`.env` 的 `MYSQL_HOST` |
| CK 消费不到数据 | CK 的 Kafka 引擎表 broker 是否 `localhost:9094`（= `KAFKA_BROKER_FOR_CK`）；`docker compose logs kafka` 广播地址 |
| 监控连不上 CK | `.env` 的 `CK_HOST`（默认 `host.docker.internal`，不通则改成 B 服实际 IP）；CK 是否监听 0.0.0.0 |
| Kafka lag 一直涨 | CK 消费是否异常（面板/`system.kafka_consumers`）；`docker compose logs connect` |
| 位点丢失需重做 | A 服 binlog 保留期 `expire_logs_days` 是否覆盖快照+追赶窗口 |

## 七、常用运维

```bash
docker compose logs -f connect          # 连接器日志
docker compose logs -f kafka            # Kafka 日志
docker compose restart connect          # 重启 Connect
docker compose down                     # 停栈（保留数据卷）
docker compose down -v                  # 停栈并清 Kafka 数据（谨慎）
```

> 默认单节点 Kafka。需要高可用（3 节点 RF=3、容忍单 broker 故障）时：
> `docker compose -f docker-compose.ha.yml up -d --build`，并按 `.env` 注释把两个 broker 地址改成三节点形式。
