(function () {
  'use strict';

  const WORKER_URL = 'https://muxis-api-worker.a-leaf-org.workers.dev';
  let token = localStorage.getItem('muxis_cloud_token') || '';
  let allUsers = [];
  let activeFilter = 'pending';
  let searchQuery = '';

  const loginView = document.getElementById('login-view');
  const forbiddenView = document.getElementById('forbidden-view');
  const dashView = document.getElementById('dashboard-view');
  const refreshBtn = document.getElementById('refresh-btn');
  const signoutBtn = document.getElementById('signout-btn');

  document.addEventListener('DOMContentLoaded', async () => {
    document.getElementById('google-admin-btn').addEventListener('click', startGoogleAdminLogin);
    document.getElementById('email-login-btn').addEventListener('click', emailLogin);
    document.getElementById('switch-account-btn').addEventListener('click', signOut);
    signoutBtn.addEventListener('click', signOut);
    refreshBtn.addEventListener('click', loadAdminOverview);

    document.querySelectorAll('.filter-tab').forEach((btn) => {
      btn.addEventListener('click', () => {
        activeFilter = btn.dataset.filter;
        document.querySelectorAll('.filter-tab').forEach((b) => b.classList.toggle('active', b === btn));
        renderUsers();
      });
    });

    document.getElementById('user-search').addEventListener('input', (e) => {
      searchQuery = e.target.value.trim().toLowerCase();
      renderUsers();
    });

    document.getElementById('require-approval-toggle').addEventListener('change', async (e) => {
      const enabled = e.target.checked;
      const res = await apiFetch('/api/admin/settings', {
        method: 'POST',
        body: JSON.stringify({ require_pwa_approval: enabled })
      });
      if (res.ok) showToast(enabled ? 'Approval Gate Enabled' : 'Open Auto-Approve Enabled');
      else e.target.checked = !enabled;
    });

    if (token) await loadAdminOverview();
    else showLogin();
  });

  async function apiFetch(path, opts = {}) {
    const headers = Object.assign({ 'Content-Type': 'application/json' }, opts.headers || {});
    if (token) headers.Authorization = `Bearer ${token}`;
    return fetch(`${WORKER_URL}${path}`, Object.assign({}, opts, { headers }));
  }

  function showLogin() {
    loginView.style.display = 'block';
    forbiddenView.style.display = 'none';
    dashView.style.display = 'none';
    refreshBtn.style.display = 'none';
    signoutBtn.style.display = 'none';
  }

  function showForbidden(email) {
    loginView.style.display = 'none';
    forbiddenView.style.display = 'block';
    dashView.style.display = 'none';
    refreshBtn.style.display = 'none';
    signoutBtn.style.display = 'inline-flex';
    document.getElementById('forbidden-email-msg').textContent = email
      ? `${email} is not an administrator. Sign in with your owner account (fbalif123@gmail.com).`
      : 'Administrator privileges required.';
  }

  function showDashboard() {
    loginView.style.display = 'none';
    forbiddenView.style.display = 'none';
    dashView.style.display = 'block';
    refreshBtn.style.display = 'inline-flex';
    signoutBtn.style.display = 'inline-flex';
  }

  async function emailLogin() {
    const email = document.getElementById('email-input').value.trim();
    const password = document.getElementById('pass-input').value;
    const errEl = document.getElementById('login-error');
    errEl.style.display = 'none';
    try {
      const res = await fetch(`${WORKER_URL}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });
      const data = await res.json();
      if (!res.ok || !data.access_token) {
        errEl.textContent = data.error || 'Login failed.';
        errEl.style.display = 'block';
        return;
      }
      token = data.access_token;
      localStorage.setItem('muxis_cloud_token', token);
      if (data.user) localStorage.setItem('muxis_cloud_user', JSON.stringify(data.user));
      await loadAdminOverview();
    } catch (_) {
      errEl.textContent = 'Connection error reaching Cloudflare Worker.';
      errEl.style.display = 'block';
    }
  }

  async function startGoogleAdminLogin() {
    const errEl = document.getElementById('login-error');
    errEl.style.display = 'none';
    const rand = new Uint8Array(24);
    crypto.getRandomValues(rand);
    const pollSecret = Array.from(rand, (b) => b.toString(16).padStart(2, '0')).join('');
    const appRedirect = window.location.href.split('#')[0];

    try {
      const startRes = await fetch(
        `${WORKER_URL}/api/auth/google/start?poll_secret=${encodeURIComponent(pollSecret)}&app_redirect=${encodeURIComponent(appRedirect)}`
      );
      const startData = await startRes.json();
      if (!startRes.ok || !startData.auth_url) {
        errEl.textContent = startData.error || 'Google Sign-In unavailable.';
        errEl.style.display = 'block';
        return;
      }

      const popup = window.open(startData.auth_url, '_blank', 'width=480,height=640');
      const deadline = Date.now() + 3 * 60 * 1000;
      const timer = setInterval(async () => {
        if (Date.now() > deadline) { clearInterval(timer); return; }
        try {
          const pollRes = await fetch(`${WORKER_URL}/api/auth/google/poll`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ state: startData.state, poll_secret: pollSecret })
          });
          if (!pollRes.ok) return;
          const pData = await pollRes.json();
          if (pData.status === 'complete' && pData.access_token) {
            clearInterval(timer);
            try { if (popup && !popup.closed) popup.close(); } catch (_) {}
            token = pData.access_token;
            localStorage.setItem('muxis_cloud_token', token);
            if (pData.user) localStorage.setItem('muxis_cloud_user', JSON.stringify(pData.user));
            await loadAdminOverview();
          } else if (pData.status === 'error' || pData.status === 'expired') {
            clearInterval(timer);
            errEl.textContent = pData.error || 'Google authentication cancelled or expired.';
            errEl.style.display = 'block';
          }
        } catch (_) {}
      }, 1300);
    } catch (_) {
      errEl.textContent = 'Network timeout starting Google Sign-In.';
      errEl.style.display = 'block';
    }
  }

  async function loadAdminOverview() {
    try {
      const res = await apiFetch('/api/admin/overview');
      if (res.status === 401) {
        signOut();
        return;
      }
      if (res.status === 403) {
        const me = JSON.parse(localStorage.getItem('muxis_cloud_user') || '{}');
        showForbidden(me.email);
        return;
      }
      if (!res.ok) return;
      const data = await res.json();
      allUsers = data.users || [];
      document.getElementById('stat-pending').textContent = String(data.stats?.pending ?? 0);
      document.getElementById('stat-approved').textContent = String(data.stats?.approved ?? 0);
      document.getElementById('stat-rejected').textContent = String(data.stats?.rejected ?? 0);
      document.getElementById('stat-total').textContent = String(data.stats?.total ?? 0);
      document.getElementById('require-approval-toggle').checked = data.require_pwa_approval !== false;
      showDashboard();
      renderUsers();
    } catch (_) {
      showToast('Failed to fetch admin data');
    }
  }

  function renderUsers() {
    const stack = document.getElementById('users-list');
    stack.innerHTML = '';

    const filtered = allUsers.filter((u) => {
      if (activeFilter !== 'all' && u.pwa_approval_status !== activeFilter) return false;
      if (searchQuery) {
        const hay = `${u.email} ${u.display_name || ''}`.toLowerCase();
        if (!hay.includes(searchQuery)) return false;
      }
      return true;
    });

    if (!filtered.length) {
      const empty = document.createElement('div');
      empty.className = 'glass-panel';
      empty.style.cssText = 'padding: 28px; text-align: center; color: var(--muted); font-size: 14px;';
      empty.textContent = `No ${activeFilter === 'all' ? '' : activeFilter + ' '}users found.`;
      stack.appendChild(empty);
      return;
    }

    filtered.forEach((u) => {
      const row = document.createElement('article');
      row.className = 'user-row glass-panel';

      const meta = document.createElement('div');
      meta.className = 'user-meta';
      const av = document.createElement('div');
      av.className = 'user-avatar';
      if (u.avatar_url) {
        const img = document.createElement('img');
        img.src = u.avatar_url;
        img.alt = '';
        av.appendChild(img);
      } else {
        av.textContent = (u.display_name || u.email || 'M').slice(0, 1).toUpperCase();
      }

      const txt = document.createElement('div');
      txt.className = 'user-text';
      const title = document.createElement('strong');
      title.appendChild(document.createTextNode(u.display_name || 'MUXIS User'));
      const statusBadge = document.createElement('span');
      statusBadge.className = `status-pill ${u.pwa_approval_status}`;
      statusBadge.textContent = u.pwa_approval_status;
      title.appendChild(statusBadge);
      if (u.is_admin) {
        const admBadge = document.createElement('span');
        admBadge.className = 'status-pill admin';
        admBadge.textContent = 'ADMIN';
        title.appendChild(admBadge);
      }

      const sub = document.createElement('span');
      const dt = u.created_at ? new Date(u.created_at).toLocaleDateString() : '';
      sub.textContent = `${u.email} • ${(u.auth_provider || 'email').toUpperCase()}${dt ? ' • Joined ' + dt : ''}`;
      txt.append(title, sub);
      meta.append(av, txt);

      const actions = document.createElement('div');
      actions.className = 'row-actions';

      if (u.pwa_approval_status !== 'approved') {
        const appBtn = document.createElement('button');
        appBtn.type = 'button';
        appBtn.className = 'btn-sm approve';
        appBtn.textContent = 'Approve Access';
        appBtn.addEventListener('click', () => setUserStatus(u.id, 'approved'));
        actions.appendChild(appBtn);
      }

      if (!u.is_admin && u.pwa_approval_status !== 'rejected') {
        const rejBtn = document.createElement('button');
        rejBtn.type = 'button';
        rejBtn.className = 'btn-sm reject';
        rejBtn.textContent = u.pwa_approval_status === 'approved' ? 'Revoke' : 'Reject';
        rejBtn.addEventListener('click', () => setUserStatus(u.id, 'rejected'));
        actions.appendChild(rejBtn);
      }

      if (!u.is_admin) {
        const delBtn = document.createElement('button');
        delBtn.type = 'button';
        delBtn.className = 'btn-sm';
        delBtn.textContent = 'Delete';
        delBtn.addEventListener('click', () => deleteUser(u));
        actions.appendChild(delBtn);
      }

      row.append(meta, actions);
      stack.appendChild(row);
    });
  }

  async function setUserStatus(userId, status) {
    const res = await apiFetch(`/api/admin/users/${encodeURIComponent(userId)}/status`, {
      method: 'POST',
      body: JSON.stringify({ status })
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      showToast(data.error || 'Action failed');
      return;
    }
    showToast(`User marked as ${status}`);
    await loadAdminOverview();
  }

  async function deleteUser(u) {
    if (!window.confirm(`Permanently delete cloud account for ${u.email}?`)) return;
    const res = await apiFetch(`/api/admin/users/${encodeURIComponent(u.id)}`, { method: 'DELETE' });
    if (res.ok) {
      showToast('User removed');
      await loadAdminOverview();
    }
  }

  function signOut() {
    token = '';
    localStorage.removeItem('muxis_cloud_token');
    localStorage.removeItem('muxis_cloud_user');
    showLogin();
  }

  function showToast(msg) {
    const el = document.getElementById('toast');
    el.textContent = msg;
    el.classList.add('show');
    clearTimeout(el._t);
    el._t = setTimeout(() => el.classList.remove('show'), 2500);
  }
})();
