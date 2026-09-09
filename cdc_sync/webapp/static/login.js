/* 登录页逻辑：已登录 → 跳主界面；提交 → 尝试登录，成功跳主界面 */
const $ = (sel) => document.querySelector(sel);

// 进入登录页时，若已持有有效会话则直接回主界面
fetch('/api/me', { credentials: 'same-origin' })
  .then((r) => r.json())
  .then((j) => {
    if (j.ok && j.data && j.data.username) {
      window.location.replace('/');
    }
  })
  .catch(() => {}); // 网络异常留在登录页

$('#loginForm').addEventListener('submit', async (ev) => {
  ev.preventDefault();
  const btn = $('#loginBtn'); btn.disabled = true;
  const msg = $('#loginMsg'); msg.textContent = ''; msg.className = 'action-msg';
  const body = {
    username: $('#loginUser').value.trim(),
    password: $('#loginPass').value,
  };
  try {
    const r = await fetch('/api/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    const j = await r.json();
    if (j.ok) {
      window.location.replace('/');
    } else {
      msg.textContent = '✗ ' + (j.error || '登录失败');
      msg.className = 'action-msg err';
    }
  } catch (e) {
    msg.textContent = '✗ ' + e;
    msg.className = 'action-msg err';
  } finally {
    btn.disabled = false;
  }
});
