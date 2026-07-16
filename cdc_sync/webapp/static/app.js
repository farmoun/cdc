// CDC 监控前端：轮询只读端点，渲染状态卡与表格；操作按钮调用 POST 端点。
'use strict';

const $ = (sel) => document.querySelector(sel);
const esc = (s) => String(s == null ? '' : s)
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

async function getJSON(url) {
  const r = await fetch(url);
  return r.json();
}
async function postJSON(url) {
  const r = await fetch(url, { method: 'POST' });
  return r.json();
}

function statusClass(s) {
  if (s === 'ok') return 'ok';
  if (s === 'warn') return 'warn';
  return 'error';
}

// ---------------- 概览卡片 ----------------
function renderCards(ov) {
  const cfg = ov.config || {};
  setCard('config', cfg.status || 'error',
    cfg.status === 'ok' ? `${cfg.tables} 张表` : '配置错误',
    cfg.status === 'ok' ? `连接器 ${esc(cfg.connector)}` : esc(cfg.error));

  const c = (ov.components || {});
  const conn = c.connect || { status: 'error', error: '无数据' };
  setCard('connect', conn.status,
    conn.state || (conn.status === 'error' ? '不可达' : '—'),
    conn.status === 'error' ? esc(conn.error) : `任务 ${conn.tasks_running}/${conn.tasks_total} RUNNING`);

  const k = c.kafka || { status: 'error', error: '无数据' };
  setCard('kafka', k.status,
    k.status === 'error' ? '不可达' : `堆积 ${k.total_lag}`,
    k.status === 'error' ? esc(k.error) : `${k.topics} 个 topic`);

  const ck = c.clickhouse || { status: 'error', error: '无数据' };
  setCard('clickhouse', ck.status,
    ck.status === 'error' ? '不可达' : `${ck.consumers} 消费者`,
    ck.status === 'error' ? esc(ck.error) : `异常 ${ck.with_exception}`);
}

function setCard(key, status, big, detail) {
  const card = document.querySelector(`.card[data-key="${key}"]`);
  if (!card) return;
  card.className = 'card ' + statusClass(status);
  card.querySelector('.card-body').innerHTML =
    `<span class="dot ${statusClass(status)}"></span>${esc(big)}<div class="detail">${detail}</div>`;
}

// ---------------- 连接器任务 ----------------
async function loadConnector() {
  const box = $('#connectorBox');
  const res = await getJSON('/api/connectors');
  if (!res.ok) { box.innerHTML = `<div class="errline">✗ ${esc(res.error)}</div>`; return; }
  const st = res.data;
  const conn = st.connector || {};
  const tasks = st.tasks || [];
  let html = `<table><tr><th>对象</th><th>状态</th><th>worker</th></tr>`;
  html += `<tr><td>connector</td><td>${badge(conn.state)}</td><td>${esc(conn.worker_id || '')}</td></tr>`;
  for (const t of tasks) {
    html += `<tr><td>task #${t.id}</td><td>${badge(t.state)}</td><td>${esc(t.worker_id || '')}</td></tr>`;
    if (t.trace) html += `<tr><td colspan="3"><div class="errline">${esc(t.trace.split('\n')[0])}</div></td></tr>`;
  }
  html += `</table>`;
  box.innerHTML = html;
}

function badge(state) {
  const s = (state || '').toUpperCase();
  if (s === 'RUNNING') return `<span class="badge ok">${esc(s)}</span>`;
  if (s === 'PAUSED') return `<span class="badge warn">${esc(s)}</span>`;
  return `<span class="badge err">${esc(s || '?')}</span>`;
}

// ---------------- Kafka 堆积 ----------------
async function loadLag() {
  const box = $('#lagBox');
  const res = await getJSON('/api/kafka/lag');
  if (!res.ok) { box.innerHTML = `<div class="errline">✗ ${esc(res.error)}</div>`; return; }
  const rows = res.data;
  if (rows.length === 1 && rows[0].error) { box.innerHTML = `<div class="errline">✗ ${esc(rows[0].error)}</div>`; return; }
  let html = `<table><tr><th>表</th><th>topic</th><th class="num">分区</th><th class="num">末端</th><th class="num">已消费</th><th class="num">堆积</th></tr>`;
  for (const r of rows) {
    if (r.error) { html += `<tr><td>${esc(r.table)}</td><td colspan="5"><span class="errline">${esc(r.error)}</span></td></tr>`; continue; }
    const lagCls = (r.lag > 0) ? 'warn' : 'ok';
    html += `<tr><td>${esc(r.table)}</td><td>${esc(r.topic)}</td>`
      + `<td class="num">${r.partitions}</td><td class="num">${r.end_offset}</td>`
      + `<td class="num">${r.committed}</td><td class="num"><span class="badge ${lagCls}">${r.lag}</span></td></tr>`;
  }
  html += `</table>`;
  box.innerHTML = html;
}

// ---------------- CK 消费状态 ----------------
async function loadCK() {
  const box = $('#ckBox');
  const res = await getJSON('/api/clickhouse/consumers');
  if (!res.ok) { box.innerHTML = `<div class="errline">✗ ${esc(res.error)}</div>`; return; }
  const rows = res.data;
  if (!rows.length) { box.innerHTML = `<div class="muted">system.kafka_consumers 无记录（尚未消费）</div>`; return; }
  let html = `<table><tr><th>表</th><th class="num">已读</th><th>最近异常</th></tr>`;
  for (const r of rows) {
    const exc = r.last_exception || '';
    html += `<tr><td>${esc(r.database)}.${esc(r.table)}</td>`
      + `<td class="num">${esc(r.num_messages_read)}</td>`
      + `<td>${exc ? `<span class="errline">${esc(exc)}</span>` : '<span class="badge ok">正常</span>'}</td></tr>`;
  }
  html += `</table>`;
  box.innerHTML = html;
}

// ---------------- 对账 ----------------
async function loadReconcile(run) {
  const box = $('#reconcileBox');
  box.innerHTML = '<span class="muted">对账中…</span>';
  const res = await getJSON(run ? '/api/reconcile/run' : '/api/reconcile');
  if (!res.ok) { box.innerHTML = `<div class="errline">✗ ${esc(res.error)}</div>`; return; }
  const rows = res.data;
  let html = `<table><tr><th>表</th><th class="num">MySQL</th><th class="num">ClickHouse</th><th class="num">差异</th><th>状态</th></tr>`;
  for (const r of rows) {
    const cls = r.consistent ? 'ok' : 'warn';
    html += `<tr><td>${esc(r.table)}</td><td class="num">${r.mysql}</td>`
      + `<td class="num">${r.clickhouse}</td><td class="num">${r.diff}</td>`
      + `<td><span class="badge ${cls}">${r.consistent ? '一致' : '不一致'}</span></td></tr>`;
  }
  html += `</table>`;
  box.innerHTML = html;
}

// ---------------- 操作按钮 ----------------
async function doAction(action, btn) {
  const msg = $('#actionMsg');
  msg.textContent = '执行中…'; msg.className = 'action-msg';
  btn.disabled = true;
  try {
    let res;
    if (action === 'deploy') res = await postJSON('/api/connectors/deploy');
    else if (action === 'restart') res = await postJSON('/api/connectors/restart');
    else if (action === 'apply') res = await postJSON('/api/clickhouse/apply');
    else if (action === 'reconcile') { await loadReconcile(true); msg.textContent = '对账完成'; msg.className = 'action-msg ok'; btn.disabled = false; return; }
    if (res.ok) { msg.textContent = '✓ 成功：' + JSON.stringify(res.data); msg.className = 'action-msg ok'; }
    else { msg.textContent = '✗ ' + res.error; msg.className = 'action-msg err'; }
  } catch (e) {
    msg.textContent = '✗ ' + e; msg.className = 'action-msg err';
  }
  btn.disabled = false;
  refreshAll();
}

// ---------------- 刷新调度 ----------------
async function refreshAll() {
  try {
    const ov = await getJSON('/api/overview');
    renderCards(ov);
  } catch (e) { /* ignore */ }
  loadConnector();
  loadLag();
  loadCK();
  $('#lastUpdate').textContent = '更新于 ' + new Date().toLocaleTimeString();
}

let timer = null;
function scheduleRefresh() {
  if (timer) clearInterval(timer);
  if ($('#autorefresh').checked) timer = setInterval(refreshAll, 5000);
}

// ================= 配置页 =================

// 表单结构：分组 → 字段 [key, 标签, 类型]
const SETTINGS_SCHEMA = [
  ['mysql', 'MySQL (源库 / A 服)', [
    ['host', '主机', 'text'], ['port', '端口', 'number'], ['user', '用户', 'text'],
    ['password', '密码', 'password'], ['charset', '字符集', 'text'],
  ]],
  ['clickhouse', 'ClickHouse (目标 / B 服宿主)', [
    ['host', '主机', 'text'], ['port', 'HTTP端口', 'number'], ['user', '用户', 'text'],
    ['password', '密码', 'password'], ['database', '库', 'text'], ['secure', 'HTTPS', 'bool'],
  ]],
  ['kafka', 'Kafka', [
    ['broker_list', 'CK消费用 broker(宿主机地址)', 'text'],
    ['internal_broker_list', '容器内 broker(kafka:9092)', 'text'],
  ]],
  ['schema_registry', 'Schema Registry', [['url', 'URL(容器内)', 'text'], ['url_for_ck', 'URL(CK宿主机用)', 'text']]],
  ['connect', 'Kafka Connect', [['url', 'REST URL', 'text']]],
  ['debezium', 'Debezium 连接器', [
    ['connector_name', '连接器名', 'text'], ['server_name', 'server.name', 'text'],
    ['server_id', 'server.id', 'number'], ['tasks_max', 'tasks.max', 'number'],
    ['snapshot_mode', 'snapshot.mode', 'text'], ['history_topic', 'history topic', 'text'],
  ]],
];

// 可测试连通性的分组 → 测试端点组件名
const TESTABLE = new Set(['mysql', 'clickhouse', 'kafka', 'schema_registry', 'connect']);

async function loadSettings() {
  const box = $('#settingsForm');
  const res = await getJSON('/api/config/settings');
  if (!res.ok) { box.innerHTML = `<div class="errline">✗ ${esc(res.error)}</div>`; return; }
  const d = res.data;
  let html = '';
  for (const [group, title, fields] of SETTINGS_SCHEMA) {
    const testBtn = TESTABLE.has(group)
      ? `<button class="btn small" data-test="${group}">测试连接</button><span class="test-result" id="test-${group}"></span>`
      : '';
    html += `<fieldset><legend>${esc(title)} ${testBtn}</legend><div class="cfgrow">`;
    for (const [key, label, type] of fields) {
      const val = (d[group] || {})[key];
      const id = `cfg-${group}-${key}`;
      if (type === 'bool') {
        html += `<label>${esc(label)} <input type="checkbox" id="${id}" ${val ? 'checked' : ''}></label>`;
      } else {
        html += `<label>${esc(label)} <input type="${type}" id="${id}" value="${esc(val == null ? '' : val)}"></label>`;
      }
    }
    html += `</div></fieldset>`;
  }
  box.innerHTML = html;
  // 绑定测试按钮（用当前表单值测试，无需先保存）
  box.querySelectorAll('[data-test]').forEach((b) =>
    b.addEventListener('click', () => testConn(b.dataset.test, b)));
}

async function testConn(component, btn) {
  const out = $(`#test-${component}`);
  out.textContent = ' 测试中…'; out.className = 'test-result';
  if (btn) btn.disabled = true;
  try {
    const r = await fetch(`/api/test/${component}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(collectSettings()),
    }).then((x) => x.json());
    if (!r.ok) { out.textContent = ' ✗ ' + r.error; out.className = 'test-result err'; }
    else {
      const d = r.data;
      out.textContent = (d.ok ? ' ✓ ' : ' ✗ ') + d.message;
      out.className = 'test-result ' + (d.ok ? 'ok' : 'err');
    }
  } catch (e) {
    out.textContent = ' ✗ ' + e; out.className = 'test-result err';
  }
  if (btn) btn.disabled = false;
}

async function testAll() {
  for (const group of TESTABLE) {
    const btn = document.querySelector(`[data-test="${group}"]`);
    await testConn(group, btn);
  }
}

function collectSettings() {
  const out = {};
  for (const [group, , fields] of SETTINGS_SCHEMA) {
    out[group] = {};
    for (const [key, , type] of fields) {
      const el = document.getElementById(`cfg-${group}-${key}`);
      if (!el) continue;
      if (type === 'bool') out[group][key] = el.checked;
      else if (type === 'number') out[group][key] = el.value === '' ? null : Number(el.value);
      else out[group][key] = el.value;
    }
  }
  return out;
}

async function saveSettings() {
  const msg = $('#settingsMsg'); msg.textContent = '保存中…'; msg.className = 'action-msg';
  const r = await fetch('/api/config/settings', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(collectSettings()),
  }).then((x) => x.json());
  if (r.ok) { msg.textContent = '✓ 已保存'; msg.className = 'action-msg ok'; refreshAll(); }
  else { msg.textContent = '✗ ' + r.error; msg.className = 'action-msg err'; }
}

async function loadTables() {
  const res = await getJSON('/api/config/tables');
  if (!res.ok) { $('#tablesMsg').textContent = '✗ ' + res.error; $('#tablesMsg').className = 'action-msg err'; return; }
  $('#tablesEditor').value = res.data.text;
  $('#tablesCount').textContent = res.data.count >= 0 ? `${res.data.count} 张表` : '（当前不合法）';
}

async function saveTables() {
  const msg = $('#tablesMsg'); msg.textContent = '保存中…'; msg.className = 'action-msg';
  const r = await fetch('/api/config/tables', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text: $('#tablesEditor').value }),
  }).then((x) => x.json());
  if (r.ok) { msg.textContent = `✓ 已保存 ${r.data.count} 张表`; msg.className = 'action-msg ok'; $('#tablesCount').textContent = `${r.data.count} 张表`; }
  else { msg.textContent = '✗ ' + r.error; msg.className = 'action-msg err'; }
}

async function importSql() {
  const msg = $('#importMsg'); const file = $('#sqlFile').files[0];
  if (!file) { msg.textContent = '请先选择 .sql 文件'; msg.className = 'action-msg err'; return; }
  const database = $('#impDatabase').value.trim();
  if (!database) { msg.textContent = '请填写源库名'; msg.className = 'action-msg err'; return; }
  msg.textContent = '解析中…'; msg.className = 'action-msg';
  const sql = await file.text();
  const r = await fetch('/api/config/import-sql', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ sql, database, target_database: $('#impTargetDb').value.trim(), prefix: $('#impPrefix').value.trim() }),
  }).then((x) => x.json());
  if (r.ok) {
    msg.textContent = `✓ 生成 ${r.data.tables} 张表` + (r.data.no_pk.length ? `（无主键需补 order_by: ${r.data.no_pk.join(', ')}）` : '');
    msg.className = 'action-msg ok';
    loadTables();
  } else { msg.textContent = '✗ ' + r.error; msg.className = 'action-msg err'; }
}

function switchTab(name) {
  document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t.dataset.tab === name));
  $('#tab-monitor').style.display = name === 'monitor' ? '' : 'none';
  $('#tab-config').style.display = name === 'config' ? '' : 'none';
  if (name === 'config') { loadSettings(); loadTables(); }
}

document.addEventListener('DOMContentLoaded', () => {
  $('#refreshBtn').addEventListener('click', refreshAll);
  $('#autorefresh').addEventListener('change', scheduleRefresh);
  document.querySelectorAll('[data-action]').forEach((b) =>
    b.addEventListener('click', () => doAction(b.dataset.action, b)));
  document.querySelectorAll('.tab').forEach((t) =>
    t.addEventListener('click', () => switchTab(t.dataset.tab)));
  $('#saveSettings').addEventListener('click', saveSettings);
  $('#reloadSettings').addEventListener('click', loadSettings);
  $('#testAll').addEventListener('click', testAll);
  $('#saveTables').addEventListener('click', saveTables);
  $('#reloadTables').addEventListener('click', loadTables);
  $('#importSql').addEventListener('click', importSql);
  refreshAll();
  scheduleRefresh();
});
