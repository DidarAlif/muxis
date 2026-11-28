// MUXIS iPhone Installable PWA — Android Mobile UI + Owner Approval Gate + D1 Sync

(function () {
  'use strict';

  const WORKER_URL = 'https://muxis-api-worker.a-leaf-org.workers.dev';
  const RADIO_MIRRORS = [
    'https://de1.api.radio-browser.info',
    'https://fr1.api.radio-browser.info',
    'https://at1.api.radio-browser.info'
  ];

  const FEATURED_TRACKS = [
    { id: 'cc-1', title: 'Neon Odyssey', artist: 'Aura Synthesis', album: 'Prismatic Dreams', badge: 'OPEN HI-FI', url: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/no_curator/Tours/Enthusiast/Tours_-_01_-_Enthusiast.mp3' },
    { id: 'cc-2', title: 'Obsidian Reflections', artist: 'Kroma Soundworks', album: 'Atmospheres', badge: '320KBPS', url: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Broke_For_Free/Directionless_EP/Broke_For_Free_-_01_-_Night_Owl.mp3' },
    { id: 'cc-3', title: 'Velvet Aurora', artist: 'Lunar Pulse', album: 'Celestial Echoes', badge: 'HI-FI', url: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/WFMU/Lame_Drivers/Frozen_Air/Lame_Drivers_-_01_-_Frozen_Air.mp3' },
    { id: 'cc-4', title: 'Midnight Frequency', artist: 'Subtle Wave', album: 'Deep Space', badge: 'HI-FI', url: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/Music_for_Video/Doctor_Turtle/The_Double-Down_Two-Step/Doctor_Turtle_-_01_-_The_Double-Down_Two-Step.mp3' }
  ];

  const EQ_BANDS = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
  const EQ_LABELS = ['32Hz', '64Hz', '125', '250', '500', '1kHz', '2kHz', '4kHz', '8kHz', '16k'];
  const EQ_PRESETS = {
    'Prismatic Neon': [4.5, 4.0, 2.0, -0.5, 0.5, 1.5, 3.0, 4.5, 5.5, 6.0],
    'Sub-Bass Thump': [7.5, 6.5, 4.5, 1.5, 0.0, 0.0, 1.0, 1.5, 2.0, 2.0],
    'Vocal Clarity': [-1.5, -1.0, 0.5, 2.5, 4.5, 5.5, 4.0, 2.0, 1.0, 0.5],
    'Electronic & EDM': [6.0, 5.0, 2.5, -1.0, 0.5, 2.0, 3.5, 4.5, 6.0, 6.5],
    'Rock & Metal': [5.0, 3.5, 1.0, -1.5, 0.0, 2.5, 4.5, 5.0, 4.0, 3.0],
    'Jazz & Acoustic': [2.0, 1.5, 1.0, 2.0, 1.5, 1.0, 2.5, 3.0, 2.5, 1.5],
    'Lo-Fi Warmth': [4.0, 4.5, 3.0, 1.5, -0.5, -1.5, -2.0, -3.0, -4.0, -5.0],
    'Flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  };

  const THEMES = {
    obsidian_aurora: { accent: '#00FF88', accentRgb: '0, 255, 136', secondary: '#00E5FF', secondaryRgb: '0, 229, 255', tertiary: '#9D6BFF', tertiaryRgb: '157, 107, 255', bgDeep: '#060910', bgSpace: '#0B111C' },
    midnight_sapphire: { accent: '#38BDF8', accentRgb: '56, 189, 248', secondary: '#22D3EE', secondaryRgb: '34, 211, 238', tertiary: '#818CF8', tertiaryRgb: '129, 140, 248', bgDeep: '#050B16', bgSpace: '#091426' },
    botanical_jade: { accent: '#10B981', accentRgb: '16, 185, 129', secondary: '#2DD4BF', secondaryRgb: '45, 212, 191', tertiary: '#6EE7B7', tertiaryRgb: '110, 231, 183', bgDeep: '#040F0B', bgSpace: '#081A14' },
    crimson_velvet: { accent: '#FF4D8D', accentRgb: '255, 77, 141', secondary: '#FB7185', secondaryRgb: '251, 113, 133', tertiary: '#C084FC', tertiaryRgb: '192, 132, 252', bgDeep: '#0F060A', bgSpace: '#180A11' },
    ultraviolet_synth: { accent: '#C084FC', accentRgb: '192, 132, 252', secondary: '#22D3EE', secondaryRgb: '34, 211, 238', tertiary: '#F472B6', tertiaryRgb: '244, 114, 182', bgDeep: '#080514', bgSpace: '#100A24' }
  };

  // Separate local vs remote audio elements so WebAudio CORS never mutes FM streams
  const localAudio = new Audio();
  localAudio.preload = 'metadata';
  const streamAudio = new Audio();
  streamAudio.preload = 'metadata';
  let activeAudio = streamAudio;

  let audioCtx = null;
  let eqFilters = [];
  let analyser = null;
  let eqEnabled = true;
  let eqGains = [...EQ_PRESETS['Prismatic Neon']];
  let activePresetName = 'Prismatic Neon';
  let activeThemeId = localStorage.getItem('muxis_pwa_theme') || 'obsidian_aurora';

  let queue = [...FEATURED_TRACKS];
  let currentTrack = null;
  let activeObjectUrl = null;
  let localTracks = [];
  let radioStations = [];
  let favorites = loadJson('muxis_pwa_favorites', []);
  let history = loadJson('muxis_pwa_history', []);
  let libFilter = 'all';

  let authToken = localStorage.getItem('muxis_cloud_token') || '';
  let authUser = loadJson('muxis_cloud_user', null);
  let isSignupMode = false;
  let approvalTimer = null;
  let deferredInstallPrompt = null;

  document.addEventListener('DOMContentLoaded', async () => {
    registerServiceWorker();
    initInstallBanner();
    initTheme(activeThemeId);
    initGateHandlers();
    initShellHandlers();
    initLiquidRipples();
    initEqStudio();
    initAudioControls();
    initSpectrumLoop();

    if (authToken) {
      await verifyApprovalAndRoute();
    } else {
      showGateAuth();
    }
  });

  function registerServiceWorker() {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('./sw.js').catch(() => {});
    }
  }

  function initInstallBanner() {
    const installBtn = document.getElementById('install-pwa-btn');
    const banner = document.getElementById('ios-install-banner');
    const instr = document.getElementById('install-instructions');
    const dismiss = document.getElementById('dismiss-install-btn');
    const isStandalone = window.navigator.standalone === true || window.matchMedia('(display-mode: standalone)').matches;
    const isIOS = /iPhone|iPad|iPod/i.test(navigator.userAgent || '') ||
      (/Macintosh/i.test(navigator.userAgent || '') && navigator.maxTouchPoints > 1);

    if (!isStandalone && localStorage.getItem('muxis_hide_install_banner') !== '1' && isIOS) {
      banner.classList.add('visible');
    }
    dismiss.addEventListener('click', () => {
      banner.classList.remove('visible');
      localStorage.setItem('muxis_hide_install_banner', '1');
    });

    window.addEventListener('beforeinstallprompt', (e) => {
      e.preventDefault();
      deferredInstallPrompt = e;
      installBtn.style.display = 'inline-flex';
      installBtn.addEventListener('click', async () => {
        if (!deferredInstallPrompt) return;
        deferredInstallPrompt.prompt();
        await deferredInstallPrompt.userChoice;
        deferredInstallPrompt = null;
        banner.classList.remove('visible');
      });
      if (!isStandalone && !isIOS) {
        instr.textContent = 'Install MUXIS straight onto your device Home Screen in 1 tap.';
        banner.classList.add('visible');
      }
    });
  }

  // =========================================================================
  // GATE & APPROVAL WORKFLOW (Server-Verified Cloudflare D1)
  // =========================================================================
  function initGateHandlers() {
    const tabIn = document.getElementById('tab-signin');
    const tabUp = document.getElementById('tab-signup');
    const nameField = document.getElementById('gate-name');
    const submitBtn = document.getElementById('gate-submit-btn');

    tabIn.addEventListener('click', () => {
      isSignupMode = false;
      tabIn.classList.add('active');
      tabUp.classList.remove('active');
      nameField.style.display = 'none';
      submitBtn.textContent = 'Sign In to MUXIS Cloud';
    });
    tabUp.addEventListener('click', () => {
      isSignupMode = true;
      tabUp.classList.add('active');
      tabIn.classList.remove('active');
      nameField.style.display = 'block';
      submitBtn.textContent = 'Create Account & Request Approval';
    });

    submitBtn.addEventListener('click', submitEmailAuth);
    document.getElementById('gate-google-btn').addEventListener('click', startGoogleOAuth);
    document.getElementById('check-approval-btn').addEventListener('click', verifyApprovalAndRoute);
    document.getElementById('gate-signout-btn').addEventListener('click', signOutAll);
  }

  function showGateAuth() {
    stopApprovalPolling();
    document.getElementById('gate-shell').style.display = 'flex';
    document.getElementById('gate-auth-card').style.display = 'block';
    document.getElementById('gate-approval-card').style.display = 'none';
    document.getElementById('app-shell').style.display = 'none';
  }

  function showGatePending(status, note, email) {
    document.getElementById('gate-shell').style.display = 'flex';
    document.getElementById('gate-auth-card').style.display = 'none';
    document.getElementById('gate-approval-card').style.display = 'block';
    document.getElementById('app-shell').style.display = 'none';

    const badge = document.getElementById('approval-badge');
    const title = document.getElementById('approval-title');
    const desc = document.getElementById('approval-desc');
    document.getElementById('approval-email-line').textContent = email || '';

    if (status === 'rejected') {
      badge.className = 'status-badge rejected';
      badge.textContent = 'ACCESS NOT APPROVED';
      title.textContent = 'Access Revoked / Rejected';
      desc.textContent = note || 'Your account is currently not approved for PWA access. Contact A Leaf ORG administrator.';
      stopApprovalPolling();
    } else {
      badge.className = 'status-badge pending';
      badge.textContent = 'PENDING OWNER APPROVAL';
      title.textContent = 'Waiting for Admin Approval';
      desc.textContent = 'Your MUXIS Cloud request is queued in Cloudflare D1. Once approved by the owner in the Admin Panel, this app unlocks automatically.';
      startApprovalPolling();
    }
  }

  function unlockApprovedApp() {
    stopApprovalPolling();
    document.getElementById('gate-shell').style.display = 'none';
    document.getElementById('app-shell').style.display = 'flex';
    hydrateAppData();
  }

  function startApprovalPolling() {
    if (approvalTimer) return;
    approvalTimer = setInterval(() => {
      if (authToken && !document.hidden) verifyApprovalAndRoute(true);
    }, 6000);
  }
  function stopApprovalPolling() {
    if (approvalTimer) { clearInterval(approvalTimer); approvalTimer = null; }
  }

  async function verifyApprovalAndRoute(silent = false) {
    if (!authToken) { showGateAuth(); return; }
    try {
      const res = await fetch(`${WORKER_URL}/api/auth/pwa/status`, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      if (res.status === 401) {
        signOutAll();
        return;
      }
      if (!res.ok) {
        if (authUser && (authUser.is_admin || authUser.pwa_approval_status === 'approved')) {
          unlockApprovedApp();
        }
        return;
      }
      const data = await res.json();
      if (data.user) {
        authUser = data.user;
        saveJson('muxis_cloud_user', authUser);
      }
      if (data.is_admin || data.approval_status === 'approved') {
        unlockApprovedApp();
      } else {
        showGatePending(data.approval_status || 'pending', data.note, data.user?.email || authUser?.email);
        if (!silent) showToast('Still awaiting owner approval');
      }
    } catch (_) {
      if (authUser && (authUser.is_admin || authUser.pwa_approval_status === 'approved')) {
        unlockApprovedApp();
      }
    }
  }

  async function submitEmailAuth() {
    const email = document.getElementById('gate-email').value.trim();
    const password = document.getElementById('gate-pass').value;
    const displayName = document.getElementById('gate-name').value.trim();
    const errEl = document.getElementById('gate-error-box');
    errEl.style.display = 'none';

    const path = isSignupMode ? '/api/auth/register' : '/api/auth/login';
    try {
      const res = await fetch(`${WORKER_URL}${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, display_name: displayName })
      });
      const data = await res.json();
      if (!res.ok || !data.access_token) {
        errEl.textContent = data.error || 'Authentication failed.';
        errEl.style.display = 'block';
        return;
      }
      authToken = data.access_token;
      authUser = data.user;
      localStorage.setItem('muxis_cloud_token', authToken);
      saveJson('muxis_cloud_user', authUser);
      await verifyApprovalAndRoute();
    } catch (_) {
      errEl.textContent = 'Network timeout contacting MUXIS Cloud.';
      errEl.style.display = 'block';
    }
  }

  async function startGoogleOAuth() {
    const errEl = document.getElementById('gate-error-box');
    errEl.style.display = 'none';
    const rand = new Uint8Array(24);
    crypto.getRandomValues(rand);
    const pollSecret = Array.from(rand, (b) => b.toString(16).padStart(2, '0')).join('');
    const appRedirect = window.location.href.split('#')[0];

    try {
      const res = await fetch(
        `${WORKER_URL}/api/auth/google/start?poll_secret=${encodeURIComponent(pollSecret)}&app_redirect=${encodeURIComponent(appRedirect)}`
      );
      const start = await res.json();
      if (!res.ok || !start.auth_url) {
        errEl.textContent = start.error || 'Google Sign-In unavailable.';
        errEl.style.display = 'block';
        return;
      }

      const popup = window.open(start.auth_url, '_blank', 'width=480,height=640');
      const deadline = Date.now() + 3 * 60 * 1000;
      const timer = setInterval(async () => {
        if (Date.now() > deadline) { clearInterval(timer); return; }
        try {
          const poll = await fetch(`${WORKER_URL}/api/auth/google/poll`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ state: start.state, poll_secret: pollSecret })
          });
          if (!poll.ok) return;
          const pData = await poll.json();
          if (pData.status === 'complete' && pData.access_token) {
            clearInterval(timer);
            try { if (popup && !popup.closed) popup.close(); } catch (_) {}
            authToken = pData.access_token;
            authUser = pData.user;
            localStorage.setItem('muxis_cloud_token', authToken);
            saveJson('muxis_cloud_user', authUser);
            await verifyApprovalAndRoute();
          } else if (pData.status === 'error' || pData.status === 'expired') {
            clearInterval(timer);
            errEl.textContent = pData.error || 'Google Sign-In expired.';
            errEl.style.display = 'block';
          }
        } catch (_) {}
      }, 1300);
    } catch (_) {
      errEl.textContent = 'Could not reach MUXIS Cloud OAuth.';
      errEl.style.display = 'block';
    }
  }

  function signOutAll() {
    authToken = '';
    authUser = null;
    localStorage.removeItem('muxis_cloud_token');
    localStorage.removeItem('muxis_cloud_user');
    showGateAuth();
  }

  // =========================================================================
  // ANDROID MOBILE SHELL & NAVIGATION
  // =========================================================================
  function switchTab(name) {
    document.querySelectorAll('.tab-view').forEach((v) => v.classList.toggle('active', v.id === `tab-${name}`));
    document.querySelectorAll('.bnav-btn').forEach((b) => b.classList.toggle('active', b.dataset.tab === name));
  }

  function initShellHandlers() {
    document.querySelectorAll('.bnav-btn').forEach((btn) => {
      btn.addEventListener('click', () => switchTab(btn.dataset.tab));
    });
    document.querySelectorAll('[data-go-tab]').forEach((el) => {
      el.addEventListener('click', () => switchTab(el.dataset.goTab));
    });
    document.getElementById('brand-home-btn').addEventListener('click', () => switchTab('home'));
    document.getElementById('top-radio-btn').addEventListener('click', () => switchTab('explore'));
    document.getElementById('top-cloud-pill').addEventListener('click', () => switchTab('settings'));

    const studioSheet = document.getElementById('studio-sheet-backdrop');
    const openDsp = () => studioSheet.classList.add('open');
    document.getElementById('top-dsp-btn').addEventListener('click', openDsp);
    document.getElementById('settings-open-dsp').addEventListener('click', openDsp);
    document.getElementById('np-open-dsp').addEventListener('click', openDsp);
    document.getElementById('close-studio-btn').addEventListener('click', () => studioSheet.classList.remove('open'));
    studioSheet.addEventListener('click', (e) => { if (e.target === studioSheet) studioSheet.classList.remove('open'); });

    const npOverlay = document.getElementById('aurora-now-playing');
    const openNp = () => npOverlay.classList.add('open');
    document.getElementById('pb-expand-area').addEventListener('click', openNp);
    document.getElementById('top-queue-btn').addEventListener('click', openNp);
    document.getElementById('np-close-btn').addEventListener('click', () => npOverlay.classList.remove('open'));

    document.querySelectorAll('#lib-filter-chips .filter-chip').forEach((chip) => {
      chip.addEventListener('click', () => {
        libFilter = chip.dataset.libFilter;
        document.querySelectorAll('#lib-filter-chips .filter-chip').forEach((c) => c.classList.toggle('active', c === chip));
        renderLibraryList();
      });
    });

    document.querySelectorAll('#radio-genre-chips .filter-chip').forEach((chip) => {
      chip.addEventListener('click', () => {
        document.querySelectorAll('#radio-genre-chips .filter-chip').forEach((c) => c.classList.toggle('active', c === chip));
        loadRadioStations(chip.dataset.genre || '', 'explore-radio-list');
      });
    });

    document.getElementById('global-search-btn').addEventListener('click', runSearch);
    document.getElementById('global-search-input').addEventListener('keydown', (e) => { if (e.key === 'Enter') runSearch(); });

    document.querySelectorAll('[data-theme]').forEach((dot) => {
      dot.addEventListener('click', () => {
        initTheme(dot.dataset.theme);
        localStorage.setItem('muxis_pwa_theme', dot.dataset.theme);
        if (authToken) pushCloudSync({ settings: { dark_preset: dot.dataset.theme, eq_preset: activePresetName } });
      });
    });

    document.getElementById('settings-sync-btn').addEventListener('click', async () => {
      await pullCloudSync();
      showToast('Cloudflare D1 synced!');
    });
    document.getElementById('settings-signout-btn').addEventListener('click', signOutAll);
  }

  async function hydrateAppData() {
    const first = (authUser?.display_name || authUser?.email || 'Cloud').split(' ')[0];
    document.getElementById('top-cloud-name').textContent = first;
    document.getElementById('settings-user-meta').textContent = `${authUser?.email || ''} • Cloudflare D1 Sync`;

    const isAdm = Boolean(authUser?.is_admin);
    document.getElementById('top-admin-pill').style.display = isAdm ? 'inline-flex' : 'none';
    document.getElementById('settings-admin-link').style.display = isAdm ? 'inline-flex' : 'none';

    renderHomeCards();
    await loadLocalTracksFromDb();
    await pullCloudSync();
    renderHomeRecent();
    renderLibraryList();
    loadRadioStations('', 'explore-radio-list');
  }

  function initTheme(id) {
    const t = THEMES[id] || THEMES.obsidian_aurora;
    activeThemeId = id;
    const s = document.documentElement.style;
    s.setProperty('--accent', t.accent);
    s.setProperty('--accent-rgb', t.accentRgb);
    s.setProperty('--secondary', t.secondary);
    s.setProperty('--secondary-rgb', t.secondaryRgb);
    s.setProperty('--tertiary', t.tertiary);
    s.setProperty('--tertiary-rgb', t.tertiaryRgb);
    s.setProperty('--bg-deep', t.bgDeep);
    s.setProperty('--bg-deep-space', t.bgSpace);
    document.querySelectorAll('[data-theme]').forEach((d) => d.classList.toggle('active', d.dataset.theme === id));
  }

  function initLiquidRipples() {
    document.addEventListener('pointerdown', (e) => {
      const card = e.target.closest('.liquid-card');
      if (!card) return;
      let canvas = card.querySelector(':scope > canvas.ripple-layer');
      if (!canvas) {
        canvas = document.createElement('canvas');
        canvas.className = 'ripple-layer';
        card.insertBefore(canvas, card.firstChild);
      }
      const rect = card.getBoundingClientRect();
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      canvas.width = Math.round(rect.width * dpr);
      canvas.height = Math.round(rect.height * dpr);
      const ctx = canvas.getContext('2d');
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      const ox = e.clientX - rect.left;
      const oy = e.clientY - rect.top;
      const maxR = Math.hypot(rect.width, rect.height) * 0.8;
      const start = performance.now();
      const t = THEMES[activeThemeId] || THEMES.obsidian_aurora;

      function tick(now) {
        const p = Math.min(1, (now - start) / 680);
        ctx.clearRect(0, 0, rect.width, rect.height);
        for (let r = 0; r < 2; r++) {
          const delay = r * 0.16;
          if (p <= delay) continue;
          const rp = (p - delay) / (1 - delay);
          const radius = 6 + maxR * (1 - Math.pow(1 - rp, 3));
          const alpha = Math.pow(1 - rp, 1.7);
          ctx.beginPath();
          ctx.arc(ox, oy, radius, 0, Math.PI * 2);
          ctx.strokeStyle = r === 0 ? `rgba(255,255,255,${(0.45 * alpha).toFixed(3)})` : `rgba(${t.secondaryRgb},${(0.45 * alpha).toFixed(3)})`;
          ctx.lineWidth = 2 * (1 - rp * 0.5);
          ctx.stroke();
        }
        if (p < 1) requestAnimationFrame(tick);
        else ctx.clearRect(0, 0, rect.width, rect.height);
      }
      requestAnimationFrame(tick);
    }, { passive: true });
  }

  // =========================================================================
  // INDEXEDDB LOCAL FILES + AUDIO ENGINE + EQ DSP
  // =========================================================================
  function openDb() {
    return new Promise((resolve, reject) => {
      const req = indexedDB.open('muxis_pwa_db', 1);
      req.onupgradeneeded = () => {
        const db = req.result;
        if (!db.objectStoreNames.contains('tracks')) db.createObjectStore('tracks', { keyPath: 'id' });
      };
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  }

  async function saveLocalTrackToDb(item) {
    const db = await openDb();
    await new Promise((res, rej) => {
      const tx = db.transaction('tracks', 'readwrite');
      tx.objectStore('tracks').put(item);
      tx.oncomplete = () => res();
      tx.onerror = () => rej(tx.error);
    });
  }

  async function loadLocalTracksFromDb() {
    try {
      const db = await openDb();
      const rows = await new Promise((res, rej) => {
        const tx = db.transaction('tracks', 'readonly');
        const req = tx.objectStore('tracks').getAll();
        req.onsuccess = () => res(req.result || []);
        req.onerror = () => rej(req.error);
      });
      localTracks = rows.sort((a, b) => (b.addedAt || 0) - (a.addedAt || 0));
    } catch (_) { localTracks = []; }
    updateLibrarySummary();
  }

  function ensureWebAudioGraphForLocal() {
    if (!audioCtx) {
      const Ctx = window.AudioContext || window.webkitAudioContext;
      if (!Ctx) return;
      audioCtx = new Ctx();
      analyser = audioCtx.createAnalyser();
      analyser.fftSize = 128;
      eqFilters = EQ_BANDS.map((freq, idx) => {
        const f = audioCtx.createBiquadFilter();
        f.type = idx === 0 ? 'lowshelf' : (idx === EQ_BANDS.length - 1 ? 'highshelf' : 'peaking');
        f.frequency.value = freq;
        f.Q.value = 1.25;
        f.gain.value = eqEnabled ? eqGains[idx] : 0;
        return f;
      });
      const src = audioCtx.createMediaElementSource(localAudio);
      let node = src;
      eqFilters.forEach((f) => { node.connect(f); node = f; });
      node.connect(analyser);
      analyser.connect(audioCtx.destination);
    }
    if (audioCtx.state === 'suspended') audioCtx.resume().catch(() => {});
  }

  async function playTrack(track, trackQueue) {
    if (trackQueue && trackQueue.length) queue = trackQueue;
    currentTrack = track;
    localAudio.pause();
    streamAudio.pause();
    if (activeObjectUrl) { URL.revokeObjectURL(activeObjectUrl); activeObjectUrl = null; }

    let playUrl = track.url;
    if (track.blob) {
      ensureWebAudioGraphForLocal();
      activeAudio = localAudio;
      activeObjectUrl = URL.createObjectURL(track.blob);
      playUrl = activeObjectUrl;
    } else {
      activeAudio = streamAudio;
    }

    activeAudio.src = playUrl;
    document.getElementById('pb-title').textContent = track.title;
    document.getElementById('pb-artist').textContent = track.artist || 'MUXIS';
    document.getElementById('pb-art').src = track.artwork || '../assets/muxis_app_icon.png';
    document.getElementById('np-big-title').textContent = track.title;
    document.getElementById('np-big-artist').textContent = track.artist || 'MUXIS';
    document.getElementById('np-big-art').src = track.artwork || '../assets/muxis_app_icon.png';
    updateFavButtonState();

    try {
      await activeAudio.play();
      updatePlayButtons(true);
      updateMediaSession(track);
      recordHistory(track);
      highlightCurrentTrack();
    } catch (_) {
      showToast('Tap play to start audio');
    }
  }

  function updatePlayButtons(isPlaying) {
    const sym = isPlaying ? '&#10074;&#10074;' : '&#9654;';
    document.getElementById('pb-play-btn').innerHTML = sym;
    document.getElementById('np-play-btn').innerHTML = sym;
  }

  function updateMediaSession(track) {
    if (!('mediaSession' in navigator)) return;
    navigator.mediaSession.metadata = new MediaMetadata({
      title: track.title,
      artist: track.artist || 'MUXIS',
      album: track.album || 'MUXIS Audio',
      artwork: [{ src: track.artwork || 'icons/icon-512.png', sizes: '512x512', type: 'image/png' }]
    });
    navigator.mediaSession.setActionHandler('play', () => activeAudio.play());
    navigator.mediaSession.setActionHandler('pause', () => activeAudio.pause());
    navigator.mediaSession.setActionHandler('nexttrack', playNext);
    navigator.mediaSession.setActionHandler('previoustrack', playPrev);
  }

  function playNext() {
    if (!queue.length) return;
    const idx = currentTrack ? queue.findIndex((t) => t.id === currentTrack.id) : -1;
    const next = queue[(idx + 1) % queue.length];
    if (next) playTrack(next);
  }

  function playPrev() {
    if (!queue.length) return;
    const idx = currentTrack ? queue.findIndex((t) => t.id === currentTrack.id) : 0;
    const prev = queue[(idx - 1 + queue.length) % queue.length];
    if (prev) playTrack(prev);
  }

  function initAudioControls() {
    const toggle = () => {
      if (!currentTrack && queue.length) { playTrack(queue[0]); return; }
      if (activeAudio.paused) activeAudio.play().catch(() => {});
      else activeAudio.pause();
    };
    document.getElementById('pb-play-btn').addEventListener('click', toggle);
    document.getElementById('np-play-btn').addEventListener('click', toggle);
    document.getElementById('pb-next-btn').addEventListener('click', playNext);
    document.getElementById('np-next-btn').addEventListener('click', playNext);
    document.getElementById('np-prev-btn').addEventListener('click', playPrev);
    document.getElementById('pb-fav-btn').addEventListener('click', () => {
      if (currentTrack) toggleFavorite(currentTrack);
    });

    [localAudio, streamAudio].forEach((el) => {
      el.addEventListener('play', () => { if (el === activeAudio) updatePlayButtons(true); });
      el.addEventListener('pause', () => { if (el === activeAudio) updatePlayButtons(false); });
      el.addEventListener('ended', () => { if (el === activeAudio) playNext(); });
      el.addEventListener('timeupdate', () => {
        if (el !== activeAudio) return;
        const pct = el.duration && Number.isFinite(el.duration) ? (el.currentTime / el.duration) * 100 : 0;
        document.getElementById('mini-progress-fill').style.width = `${pct.toFixed(1)}%`;
        document.getElementById('np-seek-range').value = String(Math.round(pct));
      });
    });

    document.getElementById('np-seek-range').addEventListener('input', (e) => {
      if (!activeAudio.duration || !Number.isFinite(activeAudio.duration)) return;
      activeAudio.currentTime = (Number(e.target.value) / 100) * activeAudio.duration;
    });

    document.getElementById('home-spotlight-play').addEventListener('click', () => playTrack(FEATURED_TRACKS[0], FEATURED_TRACKS));
    document.getElementById('home-import-btn').addEventListener('click', () => document.getElementById('local-file-input').click());
    document.getElementById('lib-import-btn').addEventListener('click', () => document.getElementById('local-file-input').click());

    document.getElementById('local-file-input').addEventListener('change', async (e) => {
      const files = Array.from(e.target.files || []);
      if (!files.length) return;
      for (const file of files) {
        const base = file.name.replace(/\.[^.]+$/, '').replace(/_/g, ' ').trim();
        const parts = base.split(/\s+-\s+/);
        await saveLocalTrackToDb({
          id: `local-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
          title: parts.length >= 2 ? parts.slice(1).join(' - ') : base,
          artist: parts.length >= 2 ? parts[0] : 'Local Device File',
          album: 'Imported Files',
          badge: file.name.split('.').pop().toUpperCase(),
          blob: file,
          addedAt: Date.now()
        });
      }
      e.target.value = '';
      await loadLocalTracksFromDb();
      libFilter = 'all';
      renderLibraryList();
      switchTab('library');
      showToast(`Imported ${files.length} audio file(s)`);
    });
  }

  function initEqStudio() {
    const container = document.getElementById('eq-sliders-container');
    container.innerHTML = '';
    EQ_LABELS.forEach((lbl, i) => {
      const col = document.createElement('div');
      col.className = 'eq-band-col';
      const val = document.createElement('span');
      val.className = 'eq-db';
      val.textContent = `${eqGains[i] >= 0 ? '+' : ''}${eqGains[i].toFixed(1)}`;
      const range = document.createElement('input');
      range.type = 'range'; range.min = '-12'; range.max = '12'; range.step = '0.5';
      range.value = String(eqGains[i]);
      range.className = 'eq-range';
      range.addEventListener('input', () => {
        const g = parseFloat(range.value);
        eqGains[i] = g;
        val.textContent = `${g >= 0 ? '+' : ''}${g.toFixed(1)}`;
        if (eqFilters[i]) eqFilters[i].gain.value = eqEnabled ? g : 0;
      });
      const hz = document.createElement('span');
      hz.className = 'eq-hz';
      hz.textContent = lbl;
      col.append(val, range, hz);
      container.appendChild(col);
    });

    document.getElementById('eq-bypass-toggle').addEventListener('change', (e) => {
      eqEnabled = e.target.checked;
      eqFilters.forEach((f, idx) => { f.gain.value = eqEnabled ? eqGains[idx] : 0; });
    });

    document.querySelectorAll('#studio-preset-chips .filter-chip').forEach((chip) => {
      chip.addEventListener('click', () => {
        const name = chip.dataset.preset;
        if (!EQ_PRESETS[name]) return;
        activePresetName = name;
        eqGains = [...EQ_PRESETS[name]];
        initEqStudio();
        eqFilters.forEach((f, idx) => { f.gain.value = eqEnabled ? eqGains[idx] : 0; });
        document.querySelectorAll('#studio-preset-chips .filter-chip').forEach((c) => c.classList.toggle('active', c === chip));
        if (authToken) pushCloudSync({ settings: { dark_preset: activeThemeId, eq_preset: name } });
      });
    });
  }

  function initSpectrumLoop() {
    const canvas = document.getElementById('np-spectrum-canvas');
    if (!canvas) return;
    const freqData = new Uint8Array(64);
    const levels = new Float32Array(32).fill(0.1);
    let tick = 0;

    function frame() {
      const rect = canvas.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0 && !document.hidden) {
        const dpr = Math.min(window.devicePixelRatio || 1, 2);
        if (canvas.width !== Math.round(rect.width * dpr)) {
          canvas.width = Math.round(rect.width * dpr);
          canvas.height = Math.round(rect.height * dpr);
        }
        const ctx = canvas.getContext('2d');
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        ctx.clearRect(0, 0, rect.width, rect.height);
        const playing = !activeAudio.paused && !!activeAudio.src;
        const useFft = playing && analyser && currentTrack && currentTrack.blob;
        if (useFft) analyser.getByteFrequencyData(freqData);
        const t = THEMES[activeThemeId] || THEMES.obsidian_aurora;
        const grad = ctx.createLinearGradient(0, 0, rect.width, 0);
        grad.addColorStop(0, t.accent); grad.addColorStop(0.5, t.secondary); grad.addColorStop(1, t.tertiary);
        ctx.fillStyle = grad;
        tick++;
        const gap = rect.width / levels.length;
        const bw = Math.max(3, gap * 0.62);
        for (let i = 0; i < levels.length; i++) {
          const target = useFft ? Math.max(0.08, freqData[i] / 255) : (playing ? 0.3 + 0.55 * Math.abs(Math.sin(tick * 0.08 + i * 0.45)) : 0.1);
          levels[i] += (target - levels[i]) * 0.28;
          const h = levels[i] * (rect.height - 8);
          ctx.fillRect(i * gap + (gap - bw) * 0.5, rect.height - h, bw, h);
        }
      }
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  }

  // =========================================================================
  // RENDERERS & CLOUD SYNC
  // =========================================================================
  function renderHomeCards() {
    const wrap = document.getElementById('home-cards-carousel');
    wrap.innerHTML = '';
    FEATURED_TRACKS.forEach((tr) => {
      const c = document.createElement('div');
      c.className = 'muxis-sq-card liquid-card';
      c.innerHTML = `<div class="sq-art"><span>&#9835;</span></div><strong></strong><small></small>`;
      c.querySelector('strong').textContent = tr.title;
      c.querySelector('small').textContent = tr.artist;
      c.addEventListener('click', () => playTrack(tr, FEATURED_TRACKS));
      wrap.appendChild(c);
    });
  }

  function renderTrackRows(container, list) {
    container.innerHTML = '';
    if (!list.length) {
      const empty = document.createElement('div');
      empty.style.cssText = 'padding:18px;text-align:center;color:var(--text-muted);font-size:13px;border:1px dashed var(--border);border-radius:14px;';
      empty.textContent = 'No tracks yet.';
      container.appendChild(empty);
      return;
    }
    list.forEach((t) => {
      const row = document.createElement('div');
      row.className = 'track-row liquid-card' + (currentTrack && currentTrack.id === t.id ? ' playing' : '');
      row.dataset.trackId = t.id;
      const art = document.createElement('div');
      art.className = 'track-art';
      if (t.artwork) {
        const img = document.createElement('img');
        img.src = t.artwork;
        img.alt = '';
        img.onerror = () => { art.innerHTML = '<span style="color:var(--accent);font-weight:900;">&#9835;</span>'; };
        art.appendChild(img);
      } else {
        art.innerHTML = '<span style="color:var(--accent);font-weight:900;">&#9835;</span>';
      }
      const info = document.createElement('div');
      info.className = 'track-info';
      const title = document.createElement('strong'); title.textContent = t.title;
      const artLine = document.createElement('span'); artLine.textContent = t.artist || 'MUXIS';
      info.append(title, artLine);
      const pill = document.createElement('span');
      pill.className = 'fmt-pill'; pill.textContent = t.badge || 'AUDIO';
      const fav = document.createElement('button');
      fav.type = 'button';
      fav.className = 'pb-icon-btn' + (isFavorite(t.id) ? ' fav' : '');
      fav.innerHTML = isFavorite(t.id) ? '&#9829;' : '&#9825;';
      fav.addEventListener('click', (e) => { e.stopPropagation(); toggleFavorite(t); });
      row.append(art, info, pill, fav);
      row.addEventListener('click', () => playTrack(t, list));
      container.appendChild(row);
    });
  }

  function highlightCurrentTrack() {
    document.querySelectorAll('.track-row').forEach((r) => {
      r.classList.toggle('playing', currentTrack && r.dataset.trackId === currentTrack.id);
    });
  }

  function renderHomeRecent() {
    renderTrackRows(document.getElementById('home-recent-list'), history.slice(0, 6));
  }

  function renderLibraryList() {
    const el = document.getElementById('library-track-list');
    if (libFilter === 'favorites') renderTrackRows(el, favorites);
    else if (libFilter === 'history') renderTrackRows(el, history);
    else renderTrackRows(el, localTracks);
    updateLibrarySummary();
  }

  function updateLibrarySummary() {
    document.getElementById('lib-summary-line').textContent = `${localTracks.length} Local Tracks · ${favorites.length} Favorites`;
  }

  function isFavorite(id) { return favorites.some((f) => f.id === id || f.track_uri === id); }
  function updateFavButtonState() {
    const btn = document.getElementById('pb-fav-btn');
    const fav = currentTrack && isFavorite(currentTrack.id);
    btn.classList.toggle('fav', Boolean(fav));
    btn.innerHTML = fav ? '&#9829;' : '&#9825;';
  }

  function toggleFavorite(track) {
    const uri = track.url || track.id;
    const idx = favorites.findIndex((f) => f.id === track.id || f.track_uri === uri);
    if (idx >= 0) {
      favorites.splice(idx, 1);
      if (authToken) pushCloudSync({ mutations: [{ entityType: 'favorite', action: 'delete', data: { track_uri: uri } }] });
    } else {
      favorites.unshift({ id: track.id, track_uri: uri, title: track.title, artist: track.artist || 'MUXIS', url: track.url, badge: 'FAV' });
      if (authToken) pushCloudSync({ favorites: [{ track_uri: uri, title: track.title, artist: track.artist || 'MUXIS', album: track.album || '' }] });
    }
    saveJson('muxis_pwa_favorites', favorites);
    updateFavButtonState();
    renderLibraryList();
    renderHomeRecent();
  }

  function recordHistory(track) {
    const uri = track.url || track.id;
    history = [{ id: track.id, track_uri: uri, title: track.title, artist: track.artist || 'MUXIS', url: track.url, badge: 'PLAYED' }, ...history.filter((h) => h.id !== track.id)].slice(0, 25);
    saveJson('muxis_pwa_history', history);
    renderHomeRecent();
    if (authToken) pushCloudSync({ history: [{ track_uri: uri, title: track.title, artist: track.artist || 'MUXIS', played_at: new Date().toISOString() }] });
  }

  async function loadRadioStations(query, targetId) {
    const el = document.getElementById(targetId);
    el.innerHTML = '<div style="padding:18px;color:var(--text-muted);font-size:13px;">Loading live FM stations...</div>';
    const path = query
      ? `/json/stations/search?name=${encodeURIComponent(query)}&limit=24&hidebroken=true&order=votes&reverse=true`
      : `/json/stations/topvote/24`;
    for (const mirror of RADIO_MIRRORS) {
      try {
        const res = await fetch(`${mirror}${path}`);
        if (!res.ok) continue;
        const rows = await res.json();
        radioStations = rows.filter((s) => s.url_resolved && s.url_resolved.startsWith('https://')).map((s) => ({
          id: `radio-${s.stationuuid}`,
          title: (s.name || 'FM Radio').trim(),
          artist: `${s.country || 'Global'} · ${s.bitrate || 128}kbps`,
          badge: 'FM LIVE',
          artwork: s.favicon && s.favicon.startsWith('https://') ? s.favicon : '',
          url: s.url_resolved
        }));
        renderTrackRows(el, radioStations);
        return;
      } catch (_) {}
    }
    el.innerHTML = '<div style="padding:18px;color:var(--text-muted);font-size:13px;">Radio unavailable right now.</div>';
  }

  async function runSearch() {
    const q = document.getElementById('global-search-input').value.trim().toLowerCase();
    const listEl = document.getElementById('search-results-list');
    if (!q) { renderTrackRows(listEl, FEATURED_TRACKS); return; }
    const localHits = [...localTracks, ...FEATURED_TRACKS].filter((t) => `${t.title} ${t.artist}`.toLowerCase().includes(q));
    await loadRadioStations(q, 'search-results-list');
    renderTrackRows(listEl, [...localHits, ...radioStations]);
  }

  async function pullCloudSync() {
    if (!authToken) return;
    try {
      const res = await fetch(`${WORKER_URL}/api/sync/pull`, {
        headers: { Authorization: `Bearer ${authToken}`, 'X-Muxis-Client': 'pwa' }
      });
      if (res.status === 403) {
        const err = await res.json().catch(() => ({}));
        if (err.code === 'PWA_APPROVAL_REQUIRED') showGatePending(err.approval_status || 'pending', null, authUser?.email);
        return;
      }
      if (!res.ok) return;
      const d = await res.json();
      if (Array.isArray(d.favorites)) {
        d.favorites.forEach((rf) => {
          if (!favorites.some((f) => f.track_uri === rf.track_uri)) {
            favorites.push({ id: `cloud-${rf.track_uri}`, track_uri: rf.track_uri, title: rf.title, artist: rf.artist, url: rf.track_uri.startsWith('http') ? rf.track_uri : '', badge: 'SYNCED' });
          }
        });
        saveJson('muxis_pwa_favorites', favorites);
      }
      if (d.settings?.dark_preset && THEMES[d.settings.dark_preset]) initTheme(d.settings.dark_preset);
      if (d.settings?.eq_preset && EQ_PRESETS[d.settings.eq_preset]) {
        activePresetName = d.settings.eq_preset;
        eqGains = [...EQ_PRESETS[activePresetName]];
        initEqStudio();
      }
    } catch (_) {}
  }

  async function pushCloudSync(payload) {
    if (!authToken) return;
    try {
      await fetch(`${WORKER_URL}/api/sync/push`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${authToken}`, 'X-Muxis-Client': 'pwa' },
        body: JSON.stringify(Object.assign({
          device: { name: /iPhone|iPad/i.test(navigator.userAgent) ? 'iPhone PWA' : 'Web PWA', platform: 'pwa', client_version: '1.2.13' }
        }, payload))
      });
    } catch (_) {}
  }

  function loadJson(k, fb) { try { const v = localStorage.getItem(k); return v ? JSON.parse(v) : fb; } catch (_) { return fb; } }
  function saveJson(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (_) {} }
  function showToast(msg) {
    const el = document.getElementById('toast');
    el.textContent = msg;
    el.classList.add('show');
    clearTimeout(el._t);
    el._t = setTimeout(() => el.classList.remove('show'), 2500);
  }
})();
