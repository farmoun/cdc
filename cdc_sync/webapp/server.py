"""CDC 监控 Web 应用（FastAPI）。

只读端点 + 一键操作端点，全部复用 cdc_sync 既有模块。
任一后端不可达时返回结构化 error，不 500 崩溃。

配置来源：环境变量 CDC_SETTINGS / CDC_TABLES 指定 settings/tables 路径；
默认 config/settings.yaml 与 config/tables.yaml。
"""
from __future__ import annotations

import logging
import os
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, Response
from fastapi.staticfiles import StaticFiles

from .. import (
    ck_client,
    ck_generator,
    config,
    config_store,
    connect_client,
    connector_generator,
    query_store,
    reconcile as reconcile_mod,
    sql_parser,
)
from . import conn_test, kafka_lag

log = logging.getLogger("cdc_sync.webapp")

STATIC_DIR = Path(__file__).resolve().parent / "static"

app = FastAPI(title="CDC 同步监控", version="1.0.0")


@app.middleware("http")
async def _no_cache_static(request: Request, call_next):
    """静态资源(html/js/css)禁用缓存，避免改了前端浏览器还用旧版。"""
    resp = await call_next(request)
    path = request.url.path
    if path == "/" or path.endswith((".js", ".css", ".html")):
        resp.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        resp.headers["Pragma"] = "no-cache"
    return resp


def _settings_path() -> str | None:
    return os.environ.get("CDC_SETTINGS") or None


def _tables_path() -> str | None:
    return os.environ.get("CDC_TABLES") or None


def _load():
    settings = config.load_settings(_settings_path())
    tables = config.load_tables(_tables_path())
    return settings, tables


def _ok(data):
    return {"ok": True, "data": data}


def _err(msg: str):
    return {"ok": False, "error": str(msg)}


# ----------------------------- 只读端点 -----------------------------

@app.get("/api/connectors")
def api_connectors():
    try:
        settings, _ = _load()
    except Exception as e:  # noqa: BLE001
        return _err(e)
    name = settings.debezium.connector_name
    try:
        st = connect_client.status(settings.connect_url, name)
        return _ok(st)
    except Exception as e:  # noqa: BLE001
        return _err(e)


@app.get("/api/kafka/lag")
def api_kafka_lag():
    try:
        settings, tables = _load()
    except Exception as e:  # noqa: BLE001
        return _err(e)
    try:
        rows = kafka_lag.topic_lag(settings, tables.tables)
        return _ok(rows)
    except Exception as e:  # noqa: BLE001
        return _err(e)


@app.get("/api/clickhouse/consumers")
def api_ck_consumers():
    try:
        settings, _ = _load()
    except Exception as e:  # noqa: BLE001
        return _err(e)
    try:
        rows = ck_client.kafka_consumers_status(settings.clickhouse)
        return _ok(rows)
    except Exception as e:  # noqa: BLE001
        return _err(e)


@app.get("/api/reconcile")
def api_reconcile():
    try:
        settings, tables = _load()
    except Exception as e:  # noqa: BLE001
        return _err(e)
    try:
        results = reconcile_mod.reconcile_all(settings.mysql, settings.clickhouse, tables.tables)
        data = [
            {"table": r.table, "mysql": r.mysql_count, "clickhouse": r.ck_count,
             "diff": r.diff, "consistent": r.consistent}
            for r in results
        ]
        return _ok(data)
    except Exception as e:  # noqa: BLE001
        return _err(e)


@app.get("/api/overview")
def api_overview():
    """聚合各组件健康：connect / kafka / clickhouse / config。"""
    result = {"components": {}}
    try:
        settings, tables = _load()
        result["config"] = {"status": "ok", "tables": len(tables.tables),
                            "connector": settings.debezium.connector_name}
    except Exception as e:  # noqa: BLE001
        result["config"] = {"status": "error", "error": str(e)}
        return result

    # Connect
    try:
        st = connect_client.status(settings.connect_url, settings.debezium.connector_name)
        cstate = st.get("connector", {}).get("state", "?")
        tasks = st.get("tasks", [])
        running = sum(1 for t in tasks if t.get("state") == "RUNNING")
        result["components"]["connect"] = {
            "status": "ok" if cstate == "RUNNING" else "warn",
            "state": cstate, "tasks_total": len(tasks), "tasks_running": running,
        }
    except Exception as e:  # noqa: BLE001
        result["components"]["connect"] = {"status": "error", "error": str(e)}

    # Kafka（总堆积）
    try:
        rows = kafka_lag.topic_lag(settings, tables.tables)
        if rows and rows[0].get("error") and len(rows) == 1:
            result["components"]["kafka"] = {"status": "error", "error": rows[0]["error"]}
        else:
            total_lag = sum(r.get("lag", 0) for r in rows if isinstance(r.get("lag"), int))
            result["components"]["kafka"] = {"status": "ok", "topics": len(rows), "total_lag": total_lag}
    except Exception as e:  # noqa: BLE001
        result["components"]["kafka"] = {"status": "error", "error": str(e)}

    # ClickHouse
    try:
        rows = ck_client.kafka_consumers_status(settings.clickhouse)
        exc = sum(1 for r in rows if r.get("last_exception"))
        result["components"]["clickhouse"] = {
            "status": "ok" if exc == 0 else "warn",
            "consumers": len(rows), "with_exception": exc,
        }
    except Exception as e:  # noqa: BLE001
        result["components"]["clickhouse"] = {"status": "error", "error": str(e)}

    return result


# ----------------------------- 操作端点 -----------------------------

@app.post("/api/connectors/deploy")
def api_deploy():
    try:
        settings, tables = _load()
    except Exception as e:  # noqa: BLE001
        return _err(e)
    try:
        connector = connector_generator.build_connector(tables.tables, settings)
        resp = connect_client.deploy(settings.connect_url, connector)
        return _ok({"name": resp.get("name", connector["name"])})
    except Exception as e:  # noqa: BLE001
        return _err(e)


@app.post("/api/connectors/restart")
def api_restart():
    try:
        settings, _ = _load()
    except Exception as e:  # noqa: BLE001
        return _err(e)
    try:
        connect_client.restart(settings.connect_url, settings.debezium.connector_name)
        return _ok({"restarted": settings.debezium.connector_name})
    except Exception as e:  # noqa: BLE001
        return _err(e)


@app.post("/api/clickhouse/apply")
def api_apply_ck():
    """对所有表执行 CK 三对象 DDL（IF NOT EXISTS，可重复）。"""
    try:
        settings, tables = _load()
    except Exception as e:  # noqa: BLE001
        return _err(e)
    applied = []
    try:
        try:
            _, ck_major = ck_client.server_version(settings.clickhouse)
        except Exception:  # noqa: BLE001
            ck_major = None
        for t in tables.tables:
            if not t.has_columns():
                return _err(f"表 {t.source_table} 无列定义，请先 import-sql/introspect")
            tsql = ck_generator.build_table_sql(t, settings, ck_major=ck_major)
            ck_client.execute_statements(settings.clickhouse, tsql.ordered(), dry_run=False)
            applied.append(t.target_table)
        return _ok({"applied": applied, "ck_major": ck_major})
    except Exception as e:  # noqa: BLE001
        return _err(f"已建 {len(applied)} 张，失败于下一张：{e}")


@app.post("/api/reconcile/run")
def api_reconcile_run():
    return api_reconcile()


# ----------------------------- 配置读写端点 -----------------------------

@app.get("/api/config/settings")
def api_get_settings():
    try:
        return _ok(config_store.read_settings_dict())
    except Exception as e:  # noqa: BLE001
        return _err(e)


@app.post("/api/config/settings")
async def api_save_settings(request: Request):
    try:
        data = await request.json()
    except Exception as e:  # noqa: BLE001
        return _err(f"请求体非法 JSON：{e}")
    try:
        config_store.save_settings_dict(data)
        return _ok({"saved": True, "path": str(config_store.active_settings_path())})
    except Exception as e:  # noqa: BLE001
        return _err(e)


@app.get("/api/config/tables")
def api_get_tables():
    try:
        text, count = config_store.read_tables_text()
        return _ok({"text": text, "count": count})
    except Exception as e:  # noqa: BLE001
        return _err(e)


@app.post("/api/config/tables")
async def api_save_tables(request: Request):
    try:
        body = await request.json()
        text = body.get("text", "")
    except Exception as e:  # noqa: BLE001
        return _err(f"请求体非法 JSON：{e}")
    try:
        count = config_store.save_tables_text(text)
        return _ok({"saved": True, "count": count})
    except Exception as e:  # noqa: BLE001
        return _err(e)


@app.post("/api/config/import-sql")
async def api_import_sql(request: Request):
    """上传 SQL DDL 文本，解析生成 tables.yaml。

    body: {sql: "<内容>", database: "yibuapi", target_database?: "", prefix?: ""}
    """
    try:
        body = await request.json()
    except Exception as e:  # noqa: BLE001
        return _err(f"请求体非法 JSON：{e}")
    sql = body.get("sql", "")
    database = (body.get("database") or "").strip()
    if not sql.strip():
        return _err("SQL 内容为空")
    if not database:
        return _err("请填写源库名 database")
    try:
        parsed = sql_parser.parse_text(sql)
        if not parsed:
            return _err("未解析到任何 CREATE TABLE")
        doc = sql_parser.build_tables_doc(
            parsed, database=database,
            target_database=(body.get("target_database") or "").strip() or None,
            prefix=(body.get("prefix") or "").strip(),
        )
        count = config_store.write_tables_from_parsed(doc)
        no_pk = [t["source_table"] for t in doc["tables"] if t.get("order_by") == ""]
        return _ok({"tables": count, "no_pk": no_pk})
    except Exception as e:  # noqa: BLE001
        return _err(e)


# ----------------------------- 连通性测试端点 -----------------------------

@app.post("/api/test/{component}")
async def api_test(component: str, request: Request):
    """测试某组件连通性。body 可选传 settings 表单值（未保存也能测）；否则用已保存配置。"""
    try:
        body = await request.json()
    except Exception:  # noqa: BLE001
        body = None
    try:
        if isinstance(body, dict) and body:
            settings = config.build_settings(body)
        else:
            settings = config.load_settings(_settings_path())
    except Exception as e:  # noqa: BLE001
        return _err(f"配置解析失败：{e}")
    try:
        return _ok(conn_test.run_test(component, settings))
    except Exception as e:  # noqa: BLE001
        return _err(e)


# ----------------------------- 便捷查询端点 -----------------------------

@app.post("/api/query")
async def api_query(request: Request):
    """对 ClickHouse 执行任意 SQL，返回列/行（截断 1000 行）。"""
    try:
        body = await request.json()
    except Exception as e:  # noqa: BLE001
        return _err(f"请求体非法 JSON：{e}")
    sql = (body.get("sql") or "").strip()
    if not sql:
        return _err("查询语句为空")
    try:
        settings = config.load_settings(_settings_path())
    except Exception as e:  # noqa: BLE001
        return _err(f"配置加载失败：{e}")
    try:
        return _ok(ck_client.run_query(settings.clickhouse, sql))
    except Exception as e:  # noqa: BLE001
        return _err(e)


def _export_bytes(columns: list, rows: list, fmt: str):
    """把查询结果导出为 csv/xlsx/xls 字节流。返回 (data, media_type, ext)。"""
    import io
    fmt = (fmt or "csv").lower()
    if fmt == "csv":
        import csv
        buf = io.StringIO()
        w = csv.writer(buf)
        w.writerow(columns)
        w.writerows(rows)
        return buf.getvalue().encode("utf-8-sig"), "text/csv; charset=utf-8", "csv"  # BOM 让 Excel 正确显示中文
    if fmt == "xlsx":
        from openpyxl import Workbook
        wb = Workbook()
        ws = wb.active
        ws.append(list(columns))
        for r in rows:
            ws.append([v for v in r])
        bio = io.BytesIO()
        wb.save(bio)
        return bio.getvalue(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "xlsx"
    if fmt == "xls":
        import xlwt
        wb = xlwt.Workbook(encoding="utf-8")
        ws = wb.add_sheet("result")
        for c, col in enumerate(columns):
            ws.write(0, c, str(col))
        for ri, r in enumerate(rows, start=1):
            for c, v in enumerate(r):
                ws.write(ri, c, v if isinstance(v, (int, float, str)) else ("" if v is None else str(v)))
        bio = io.BytesIO()
        wb.save(bio)
        return bio.getvalue(), "application/vnd.ms-excel", "xls"
    raise ValueError(f"不支持的导出格式：{fmt}（支持 csv/xlsx/xls）")


@app.post("/api/query/export")
async def api_query_export(request: Request):
    """执行 SQL 并导出结果为 csv/xlsx/xls 文件。"""
    try:
        body = await request.json()
    except Exception as e:  # noqa: BLE001
        return JSONResponse({"ok": False, "error": f"请求体非法 JSON：{e}"}, status_code=400)
    sql = (body.get("sql") or "").strip()
    fmt = (body.get("format") or "csv").lower()
    if not sql:
        return JSONResponse({"ok": False, "error": "查询语句为空"}, status_code=400)
    try:
        settings = config.load_settings(_settings_path())
        res = ck_client.run_query(settings.clickhouse, sql, max_rows=100000)  # 导出放宽行数上限
        data, media, ext = _export_bytes(res["columns"], res["rows"], fmt)
    except Exception as e:  # noqa: BLE001
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)
    return Response(
        content=data, media_type=media,
        headers={"Content-Disposition": f'attachment; filename="query_export.{ext}"'},
    )


@app.get("/api/queries")
def api_list_queries():
    try:
        return _ok(query_store.load_queries())
    except Exception as e:  # noqa: BLE001
        return _err(e)


@app.post("/api/queries")
async def api_save_query(request: Request):
    try:
        body = await request.json()
    except Exception as e:  # noqa: BLE001
        return _err(f"请求体非法 JSON：{e}")
    try:
        items = query_store.save_query(body.get("name", ""), body.get("sql", ""))
        return _ok(items)
    except Exception as e:  # noqa: BLE001
        return _err(e)


@app.delete("/api/queries/{name}")
def api_delete_query(name: str):
    try:
        return _ok(query_store.delete_query(name))
    except Exception as e:  # noqa: BLE001
        return _err(e)


# ----------------------------- 静态前端 -----------------------------

if STATIC_DIR.exists():
    app.mount("/", StaticFiles(directory=str(STATIC_DIR), html=True), name="static")
else:  # pragma: no cover
    @app.get("/")
    def _root():
        return JSONResponse({"msg": "static dir missing"}, status_code=500)
