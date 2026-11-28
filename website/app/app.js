// MUXIS Installable PWA — Full Android Feature Parity
// Offline IndexedDB + ID3v2 Tags, Playlists/Albums/Artists, Real 10-Band EQ + Bass/Treble/Preamp,
// WebAudio Vocal Cut & Spatial Reverb, LRCLIB Synced Lyrics, Audius/Radio/Search & D1 Cloud Sync

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
    { id: 'cc-2', title: 'Obsidian Reflections', artist: 'Kroma Soundworks', album: 'Atmospheres Vol. 1', badge: '320KBPS', url: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Broke_For_Free/Directionless_EP/Broke_For_Free_-_01_-_Night_Owl.mp3' },
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

  // Dual Audio Elements (Local WebAudio DSP Graph + Remote Stream Element)
  const localAudio = new Audio();
  localAudio.preload = 'metadata';
  const streamAudio = new Audio();
  streamAudio.preload = 'metadata';
  let activeAudio = streamAudio;

  // Web Audio DSP Graph Nodes
  let audioCtx = null;
  let eqFilters = [];
  let bassShelf = null;
  let trebleShelf = null;
  let preampGain = null;
  let dryGain = null;
  let reverbGain = null;
  let reverbConvolver = null;
  let normalMerge = null;
  let normalGain = null;
  let vocalCutGain = null;
  let leftCut = null;
  let rightCut = null;
  let analyser = null;

  // Studio State
  let eqEnabled = true;
  let eqGains = [...EQ_PRESETS['Prismatic Neon']];
  let activePresetName = 'Prismatic Neon';
  let bassBoost = 0; // 0..1
  let trebleBoost = 0; // 0..1
  let preampDb = 0;
  let playbackSpeed = 1.0;
  let isSlowedReverb = false;
  let isKaraoke = false;
  let vocalAttenuation = 0.85;
  let isReverb = false;

  // Player & Library State
  let activeThemeId = localStorage.getItem('muxis_pwa_theme') || 'obsidian_aurora';
  let queue = [...FEATURED_TRACKS];
  let currentTrack = null;
  let activeObjectUrl = null;
  let isShuffle = false;
  let repeatMode = 'all'; // 'off' | 'all' | 'one'

  let trendingTracks = [];
  let localTracks = [];
  let radioStations = [];
  let favorites = loadJson('muxis_pwa_favorites', []);
  let history = loadJson('muxis_pwa_history', []);
  let playlists = loadJson('muxis_pwa_playlists', []); // { title, tracks: [...] }

  let libFilter = 'all';
  let libSearch = '';
  let libSort = 'recent';
  let openPlaylistTitle = null;
  let openGroupFilter = null; // { type: 'album'|'artist', value: string }
  let pendingAddTrack = null;

  const PLATFORM_META = {
    youtube: {
      key: 'youtube', cls: 'yt', shortLabel: 'YT', name: 'YouTube Music', badge: 'YT',
      desc: 'Sync playlists, channels, mixes & stream audio directly',
      liveLabel: 'YT MUSIC LIVE'
    },
    spotify: {
      key: 'spotify', cls: 'sp', shortLabel: 'Spotify', name: 'Spotify', badge: 'S',
      desc: 'Import playlists, catalog & stream via audio bridge',
      liveLabel: 'SPOTIFY BRIDGE LIVE'
    },
    soundcloud: {
      key: 'soundcloud', cls: 'sc', shortLabel: 'SC', name: 'SoundCloud', badge: 'SC',
      desc: 'Stream sets, likes, user uploads & SoundCloud charts',
      liveLabel: 'SOUNDCLOUD LIVE'
    }
  };
  let platformLinks = loadJson('muxis_pwa_platform_links', {
    youtube: { isConnected: false },
    spotify: { isConnected: false },
    soundcloud: { isConnected: false }
  });
  let activePlatformKey = 'youtube';
  let activePlatformSubTab = 'picks';
  let activeConnectPlatform = null;
  let activeConnectMode = 'profile_url';
  let openHubPlaylistId = null;
  let platformSearchResults = null;
  let oauthConfig = { spotifyClientId: '', soundcloudClientId: '' };
  let isHydratingHubPlaylist = false;

  let syncedLyrics = []; // { timeSec, text }
  let activeLyricIdx = -1;
  let sleepInterval = null;
  let sleepDeadline = 0;

  let authToken = localStorage.getItem('muxis_cloud_token') || '';
  let authUser = loadJson('muxis_cloud_user', null);
  let isSignupMode = false;
  let approvalTimer = null;
  let deferredInstallPrompt = null;

  document.addEventListener('DOMContentLoaded', async () => {
    captureOAuthReturns();
    registerServiceWorker();
    initInstallBanner();
    initTheme(activeThemeId);
    initGateHandlers();
    initShellHandlers();
    initLiquidRipples();
    initEqStudio();
    initAudioControls();
    initSpectrumLoop();
    renderStreamingPlatformUI();

    if (authToken) await verifyApprovalAndRoute();
    else showGateAuth();
  });

  function registerServiceWorker() {
    if ('serviceWorker' in navigator) navigator.serviceWorker.register('./sw.js').catch(() => {});
  }

  function initInstallBanner() {
    const installBtn = document.getElementById('install-pwa-btn');
    const banner = document.getElementById('ios-install-banner');
    const instr = document.getElementById('install-instructions');
    const dismiss = document.getElementById('dismiss-install-btn');
    const isStandalone = window.navigator.standalone === true || window.matchMedia('(display-mode: standalone)').matches;
    const isIOS = /iPhone|iPad|iPod/i.test(navigator.userAgent || '') || (/Macintosh/i.test(navigator.userAgent || '') && navigator.maxTouchPoints > 1);
    if (!isStandalone && localStorage.getItem('muxis_hide_install_banner') !== '1' && isIOS) banner.classList.add('visible');
    dismiss.addEventListener('click', () => { banner.classList.remove('visible'); localStorage.setItem('muxis_hide_install_banner', '1'); });
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
  // GATE & OWNER APPROVAL
  // =========================================================================
  function initGateHandlers() {
    const tabIn = document.getElementById('tab-signin');
    const tabUp = document.getElementById('tab-signup');
    const nameField = document.getElementById('gate-name');
    const submitBtn = document.getElementById('gate-submit-btn');

    tabIn.addEventListener('click', () => {
      isSignupMode = false;
      tabIn.classList.add('active'); tabUp.classList.remove('active');
      nameField.style.display = 'none';
      submitBtn.textContent = 'Sign In to MUXIS Cloud';
    });
    tabUp.addEventListener('click', () => {
      isSignupMode = true;
      tabUp.classList.add('active'); tabIn.classList.remove('active');
      nameField.style.display = 'block';
      submitBtn.textContent = 'Create Account & Request Approval';
    });

    submitBtn.addEventListener('click', submitEmailAuth);
    document.getElementById('gate-google-btn').addEventListener('click', startGoogleOAuth);
    document.getElementById('check-approval-btn').addEventListener('click', () => verifyApprovalAndRoute(false));
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
      badge.className = 'status-badge rejected'; badge.textContent = 'ACCESS NOT APPROVED';
      title.textContent = 'Access Revoked / Rejected';
      desc.textContent = note || 'Your account is not approved for PWA access. Contact A Leaf ORG.';
      stopApprovalPolling();
    } else {
      badge.className = 'status-badge pending'; badge.textContent = 'PENDING OWNER APPROVAL';
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
    approvalTimer = setInterval(() => { if (authToken && !document.hidden) verifyApprovalAndRoute(true); }, 6000);
  }
  function stopApprovalPolling() { if (approvalTimer) { clearInterval(approvalTimer); approvalTimer = null; } }

  async function verifyApprovalAndRoute(silent = true) {
    if (!authToken) { showGateAuth(); return; }
    try {
      const res = await fetch(`${WORKER_URL}/api/auth/pwa/status`, { headers: { Authorization: `Bearer ${authToken}` } });
      if (res.status === 401) { signOutAll(); return; }
      if (!res.ok) {
        if (authUser && (authUser.is_admin || authUser.pwa_approval_status === 'approved')) unlockApprovedApp();
        return;
      }
      const data = await res.json();
      if (data.user) { authUser = data.user; saveJson('muxis_cloud_user', authUser); }
      if (data.is_admin || data.approval_status === 'approved') unlockApprovedApp();
      else {
        showGatePending(data.approval_status || 'pending', data.note, data.user?.email || authUser?.email);
        if (!silent) showToast('Still awaiting owner approval');
      }
    } catch (_) {
      if (authUser && (authUser.is_admin || authUser.pwa_approval_status === 'approved')) unlockApprovedApp();
    }
  }

  async function submitEmailAuth() {
    const email = document.getElementById('gate-email').value.trim();
    const password = document.getElementById('gate-pass').value;
    const displayName = document.getElementById('gate-name').value.trim();
    const errEl = document.getElementById('gate-error-box');
    errEl.style.display = 'none';
    try {
      const res = await fetch(`${WORKER_URL}${isSignupMode ? '/api/auth/register' : '/api/auth/login'}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, display_name: displayName })
      });
      const data = await res.json();
      if (!res.ok || !data.access_token) { errEl.textContent = data.error || 'Authentication failed.'; errEl.style.display = 'block'; return; }
      authToken = data.access_token; authUser = data.user;
      localStorage.setItem('muxis_cloud_token', authToken); saveJson('muxis_cloud_user', authUser);
      await verifyApprovalAndRoute();
    } catch (_) { errEl.textContent = 'Network timeout.'; errEl.style.display = 'block'; }
  }

  async function startGoogleOAuth() {
    const errEl = document.getElementById('gate-error-box'); errEl.style.display = 'none';
    const rand = new Uint8Array(24); crypto.getRandomValues(rand);
    const pollSecret = Array.from(rand, (b) => b.toString(16).padStart(2, '0')).join('');
    try {
      const res = await fetch(`${WORKER_URL}/api/auth/google/start?poll_secret=${encodeURIComponent(pollSecret)}&app_redirect=${encodeURIComponent(window.location.href.split('#')[0])}`);
      const start = await res.json();
      if (!res.ok || !start.auth_url) { errEl.textContent = start.error || 'Google Sign-In unavailable.'; errEl.style.display = 'block'; return; }
      const popup = window.open(start.auth_url, '_blank', 'width=480,height=640');
      const deadline = Date.now() + 3 * 60 * 1000;
      const timer = setInterval(async () => {
        if (Date.now() > deadline) { clearInterval(timer); return; }
        try {
          const poll = await fetch(`${WORKER_URL}/api/auth/google/poll`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ state: start.state, poll_secret: pollSecret }) });
          if (!poll.ok) return;
          const pData = await poll.json();
          if (pData.status === 'complete' && pData.access_token) {
            clearInterval(timer);
            try { if (popup && !popup.closed) popup.close(); } catch (_) {}
            authToken = pData.access_token; authUser = pData.user;
            localStorage.setItem('muxis_cloud_token', authToken); saveJson('muxis_cloud_user', authUser);
            await verifyApprovalAndRoute();
          } else if (pData.status === 'error' || pData.status === 'expired') { clearInterval(timer); errEl.textContent = pData.error || 'Sign-in expired.'; errEl.style.display = 'block'; }
        } catch (_) {}
      }, 1300);
    } catch (_) { errEl.textContent = 'Could not reach MUXIS Cloud.'; errEl.style.display = 'block'; }
  }

  function signOutAll() {
    authToken = ''; authUser = null;
    platformLinks = { youtube: { isConnected: false }, spotify: { isConnected: false }, soundcloud: { isConnected: false } };
    localStorage.removeItem('muxis_cloud_token'); localStorage.removeItem('muxis_cloud_user');
    localStorage.removeItem('muxis_pwa_platform_links');
    showGateAuth();
  }

  // =========================================================================
  // SHELL, HYDRATION & ANDROID TABS
  // =========================================================================
  function switchTab(name) {
    document.querySelectorAll('.tab-view').forEach((v) => v.classList.toggle('active', v.id === `tab-${name}`));
    document.querySelectorAll('.bnav-btn').forEach((b) => b.classList.toggle('active', b.dataset.tab === name));
    renderTopPlatformPills();
  }

  function initShellHandlers() {
    document.querySelectorAll('.bnav-btn').forEach((btn) => btn.addEventListener('click', () => switchTab(btn.dataset.tab)));
    document.querySelectorAll('[data-go-tab]').forEach((el) => el.addEventListener('click', () => switchTab(el.dataset.goTab)));
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

    const pickerSheet = document.getElementById('playlist-picker-backdrop');
    document.getElementById('close-picker-btn').addEventListener('click', () => pickerSheet.classList.remove('open'));
    pickerSheet.addEventListener('click', (e) => { if (e.target === pickerSheet) pickerSheet.classList.remove('open'); });
    document.getElementById('picker-create-playlist-btn').addEventListener('click', () => {
      const inp = document.getElementById('new-playlist-name-input');
      const title = inp.value.trim();
      if (!title) return;
      createPlaylist(title, pendingAddTrack);
      inp.value = '';
      pickerSheet.classList.remove('open');
    });

    const npOverlay = document.getElementById('aurora-now-playing');
    const openNp = () => { npOverlay.classList.add('open'); renderNpQueue(); };
    document.getElementById('pb-expand-area').addEventListener('click', openNp);
    document.getElementById('top-queue-btn').addEventListener('click', openNp);
    document.getElementById('np-close-btn').addEventListener('click', () => npOverlay.classList.remove('open'));

    document.querySelectorAll('[data-np-pane]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const p = btn.dataset.npPane;
        document.querySelectorAll('[data-np-pane]').forEach((b) => b.classList.toggle('active', b === btn));
        document.querySelectorAll('.np-pane').forEach((pane) => pane.classList.toggle('active', pane.id === `np-pane-${p}`));
        if (p === 'queue') renderNpQueue();
      });
    });

    document.querySelectorAll('#lib-filter-chips .filter-chip').forEach((chip) => {
      chip.addEventListener('click', () => {
        libFilter = chip.dataset.libFilter;
        openPlaylistTitle = null; openGroupFilter = null;
        document.querySelectorAll('#lib-filter-chips .filter-chip').forEach((c) => c.classList.toggle('active', c === chip));
        renderLibraryArea();
      });
    });

    document.getElementById('lib-filter-input').addEventListener('input', (e) => { libSearch = e.target.value.trim().toLowerCase(); renderLibraryArea(); });
    document.getElementById('lib-sort-select').addEventListener('change', (e) => { libSort = e.target.value; renderLibraryArea(); });

    document.querySelectorAll('#explore-mode-chips .filter-chip').forEach((chip) => {
      chip.addEventListener('click', () => {
        document.querySelectorAll('#explore-mode-chips .filter-chip').forEach((c) => c.classList.toggle('active', c === chip));
        const mode = chip.dataset.exploreMode;
        if (mode === 'audius-trending') renderTrackRows(document.getElementById('explore-list'), trendingTracks);
        else loadRadioStations(mode.replace('radio-', '').replace('top', ''), 'explore-list');
      });
    });

    document.getElementById('global-search-btn').addEventListener('click', runGlobalSearch);
    document.getElementById('global-search-input').addEventListener('keydown', (e) => { if (e.key === 'Enter') runGlobalSearch(); });

    document.querySelectorAll('[data-theme]').forEach((dot) => {
      dot.addEventListener('click', () => {
        initTheme(dot.dataset.theme);
        localStorage.setItem('muxis_pwa_theme', dot.dataset.theme);
        if (authToken) pushCloudSync({ settings: { dark_preset: dot.dataset.theme, eq_preset: activePresetName } });
      });
    });

    document.getElementById('sleep-timer-select').addEventListener('change', (e) => setSleepTimer(Number(e.target.value)));
    document.getElementById('settings-sync-btn').addEventListener('click', async () => { await pullCloudSync(); await pushAllStateToCloud(); await loadPlatformLinks(); showToast('Cloudflare D1 synced!'); });
    document.getElementById('settings-regen-key-btn').addEventListener('click', regenerateRecoveryKey);
    document.getElementById('settings-signout-btn').addEventListener('click', signOutAll);
    document.getElementById('settings-delete-btn').addEventListener('click', deleteCloudAccount);

    const pcSheet = document.getElementById('platform-connect-backdrop');
    document.getElementById('close-pc-btn').addEventListener('click', () => pcSheet.classList.remove('open'));
    pcSheet.addEventListener('click', (e) => { if (e.target === pcSheet) pcSheet.classList.remove('open'); });
    document.getElementById('pc-submit-btn').addEventListener('click', submitPlatformConnect);
    document.getElementById('pc-oauth-btn').addEventListener('click', handlePlatformOAuthAction);
  }

  async function hydrateAppData() {
    document.getElementById('top-cloud-name').textContent = (authUser?.display_name || authUser?.email || 'Cloud').split(' ')[0];
    document.getElementById('settings-user-meta').textContent = `${authUser?.email || ''} • Cloudflare D1 Sync`;
    const isAdm = Boolean(authUser?.is_admin);
    document.getElementById('top-admin-pill').style.display = isAdm ? 'inline-flex' : 'none';
    document.getElementById('settings-admin-link').style.display = isAdm ? 'inline-flex' : 'none';

    renderCarousel('home-featured-carousel', FEATURED_TRACKS);
    await completePendingOAuth();
    await loadLocalTracksFromDb();
    await pullCloudSync();
    await loadPlatformLinks();
    await loadTrendingStreams();
    renderHomeRecent();
    renderLibraryArea();
    loadRadioStations('', 'explore-list');
  }

  function initTheme(id) {
    const t = THEMES[id] || THEMES.obsidian_aurora; activeThemeId = id;
    const s = document.documentElement.style;
    s.setProperty('--accent', t.accent); s.setProperty('--accent-rgb', t.accentRgb);
    s.setProperty('--secondary', t.secondary); s.setProperty('--secondary-rgb', t.secondaryRgb);
    s.setProperty('--tertiary', t.tertiary); s.setProperty('--tertiary-rgb', t.tertiaryRgb);
    s.setProperty('--bg-deep', t.bgDeep); s.setProperty('--bg-deep-space', t.bgSpace);
    document.querySelectorAll('[data-theme]').forEach((d) => d.classList.toggle('active', d.dataset.theme === id));
  }

  function initLiquidRipples() {
    document.addEventListener('pointerdown', (e) => {
      const card = e.target.closest('.liquid-card');
      if (!card) return;
      let canvas = card.querySelector(':scope > canvas.ripple-layer');
      if (!canvas) { canvas = document.createElement('canvas'); canvas.className = 'ripple-layer'; card.insertBefore(canvas, card.firstChild); }
      const rect = card.getBoundingClientRect(); const dpr = Math.min(window.devicePixelRatio || 1, 2);
      canvas.width = Math.round(rect.width * dpr); canvas.height = Math.round(rect.height * dpr);
      const ctx = canvas.getContext('2d'); ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      const ox = e.clientX - rect.left, oy = e.clientY - rect.top, maxR = Math.hypot(rect.width, rect.height) * 0.8, start = performance.now();
      const t = THEMES[activeThemeId] || THEMES.obsidian_aurora;
      function tick(now) {
        const p = Math.min(1, (now - start) / 650); ctx.clearRect(0, 0, rect.width, rect.height);
        for (let r = 0; r < 2; r++) {
          const delay = r * 0.16; if (p <= delay) continue;
          const rp = (p - delay) / (1 - delay), alpha = Math.pow(1 - rp, 1.7);
          ctx.beginPath(); ctx.arc(ox, oy, 6 + maxR * (1 - Math.pow(1 - rp, 3)), 0, Math.PI * 2);
          ctx.strokeStyle = r === 0 ? `rgba(255,255,255,${(0.42 * alpha).toFixed(3)})` : `rgba(${t.secondaryRgb},${(0.42 * alpha).toFixed(3)})`;
          ctx.lineWidth = 2 * (1 - rp * 0.5); ctx.stroke();
        }
        if (p < 1) requestAnimationFrame(tick); else ctx.clearRect(0, 0, rect.width, rect.height);
      }
      requestAnimationFrame(tick);
    }, { passive: true });
  }

  // =========================================================================
  // INDEXEDDB + PURE JS ID3v2 METADATA & ALBUM ART PARSER
  // =========================================================================
  function openDb() {
    return new Promise((resolve, reject) => {
      const req = indexedDB.open('muxis_pwa_db', 1);
      req.onupgradeneeded = () => { if (!req.result.objectStoreNames.contains('tracks')) req.result.createObjectStore('tracks', { keyPath: 'id' }); };
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  }

  async function saveLocalTrackToDb(item) {
    const db = await openDb();
    await new Promise((res, rej) => {
      const tx = db.transaction('tracks', 'readwrite');
      tx.objectStore('tracks').put(item);
      tx.oncomplete = () => res(); tx.onerror = () => rej(tx.error);
    });
  }

  async function loadLocalTracksFromDb() {
    try {
      const db = await openDb();
      const rows = await new Promise((res, rej) => {
        const req = db.transaction('tracks', 'readonly').objectStore('tracks').getAll();
        req.onsuccess = () => res(req.result || []); req.onerror = () => rej(req.error);
      });
      localTracks = rows.sort((a, b) => (b.addedAt || 0) - (a.addedAt || 0));
    } catch (_) { localTracks = []; }
    updateLibrarySummary();
  }

  async function extractId3Metadata(file) {
    const fallbackBase = file.name.replace(/\.[^.]+$/, '').replace(/_/g, ' ').trim();
    const split = fallbackBase.split(/\s+-\s+/);
    const meta = {
      title: split.length >= 2 ? split.slice(1).join(' - ') : fallbackBase,
      artist: split.length >= 2 ? split[0] : 'Local Device File',
      album: 'Imported Music',
      artwork: ''
    };
    try {
      const buf = new Uint8Array(await file.slice(0, 262144).arrayBuffer());
      if (buf[0] !== 0x49 || buf[1] !== 0x44 || buf[2] !== 0x33) return meta; // Not ID3v2
      const tagSize = ((buf[6] & 0x7f) << 21) | ((buf[7] & 0x7f) << 14) | ((buf[8] & 0x7f) << 7) | (buf[9] & 0x7f);
      let pos = 10;
      const limit = Math.min(buf.length - 10, 10 + tagSize);
      const dec = new TextDecoder('utf-8');
      while (pos + 10 < limit) {
        const frameId = String.fromCharCode(buf[pos], buf[pos + 1], buf[pos + 2], buf[pos + 3]);
        const fSize = (buf[pos + 4] << 24) | (buf[pos + 5] << 16) | (buf[pos + 6] << 8) | buf[pos + 7];
        pos += 10;
        if (!frameId.trim() || fSize <= 0 || pos + fSize > limit) break;
        const data = buf.subarray(pos, pos + fSize);
        if (frameId === 'TIT2' || frameId === 'TPE1' || frameId === 'TALB') {
          const encByte = data[0];
          const text = (encByte === 1 || encByte === 2 ? new TextDecoder('utf-16') : dec).decode(data.subarray(1)).replace(/\0/g, '').trim();
          if (text) {
            if (frameId === 'TIT2') meta.title = text;
            else if (frameId === 'TPE1') meta.artist = text;
            else if (frameId === 'TALB') meta.album = text;
          }
        } else if (frameId === 'APIC' && !meta.artwork) {
          let i = 1;
          let mime = '';
          while (i < data.length && data[i] !== 0) mime += String.fromCharCode(data[i++]);
          i += 2; // skip null + pic type
          if (data[0] === 1 || data[0] === 2) { while (i + 1 < data.length && !(data[i] === 0 && data[i + 1] === 0)) i += 2; i += 2; }
          else { while (i < data.length && data[i] !== 0) i++; i++; }
          if (i < data.length) {
            const pic = data.subarray(i);
            let b64 = '';
            for (let k = 0; k < pic.length; k += 8192) b64 += String.fromCharCode(...pic.subarray(k, k + 8192));
            meta.artwork = `data:${mime || 'image/jpeg'};base64,${btoa(b64)}`;
          }
        }
        pos += fSize;
      }
    } catch (_) {}
    return meta;
  }

  async function handleFileImport(fileList) {
    const files = Array.from(fileList || []).filter((f) => /\.(mp3|m4a|aac|flac|wav|ogg|opus)$/i.test(f.name) || f.type.startsWith('audio/'));
    if (!files.length) { showToast('No supported audio files found'); return; }
    showToast(`Importing ${files.length} audio file(s)...`);
    for (const f of files) {
      const meta = await extractId3Metadata(f);
      await saveLocalTrackToDb({
        id: `local-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
        title: meta.title, artist: meta.artist, album: meta.album, artwork: meta.artwork,
        badge: f.name.split('.').pop().toUpperCase(), blob: f, addedAt: Date.now()
      });
    }
    await loadLocalTracksFromDb();
    libFilter = 'all'; openPlaylistTitle = null; openGroupFilter = null;
    renderLibraryArea();
    switchTab('library');
    showToast(`Saved ${files.length} track(s) offline`);
  }

  // =========================================================================
  // REAL WEB AUDIO DSP ENGINE (10-Band EQ + Bass + Treble + Preamp + Vocal Cut + Reverb + Speed)
  // =========================================================================
  function buildImpulseResponse(ctx, seconds = 2.5) {
    const len = Math.floor(ctx.sampleRate * seconds);
    const impulse = ctx.createBuffer(2, len, ctx.sampleRate);
    for (let ch = 0; ch < 2; ch++) {
      const d = impulse.getChannelData(ch);
      for (let i = 0; i < len; i++) {
        d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 2.4);
      }
    }
    return impulse;
  }

  function ensureWebAudioGraphForLocal() {
    if (!audioCtx) {
      const Ctx = window.AudioContext || window.webkitAudioContext;
      if (!Ctx) return;
      audioCtx = new Ctx();

      const src = audioCtx.createMediaElementSource(localAudio);
      preampGain = audioCtx.createGain();
      bassShelf = audioCtx.createBiquadFilter(); bassShelf.type = 'lowshelf'; bassShelf.frequency.value = 80;
      trebleShelf = audioCtx.createBiquadFilter(); trebleShelf.type = 'highshelf'; trebleShelf.frequency.value = 10000;

      eqFilters = EQ_BANDS.map((freq, idx) => {
        const f = audioCtx.createBiquadFilter();
        f.type = idx === 0 ? 'lowshelf' : (idx === EQ_BANDS.length - 1 ? 'highshelf' : 'peaking');
        f.frequency.value = freq; f.Q.value = 1.25;
        return f;
      });

      // Chain: src -> preamp -> bass -> treble -> 10 EQ bands
      let node = src;
      node.connect(preampGain); node = preampGain;
      node.connect(bassShelf); node = bassShelf;
      node.connect(trebleShelf); node = trebleShelf;
      eqFilters.forEach((f) => { node.connect(f); node = f; });

      // Mid-Side Karaoke Matrix: split stereo -> (normalMix OR (L - atten*R))
      const splitter = audioCtx.createChannelSplitter(2);
      const cutMerger = audioCtx.createChannelMerger(2);
      leftCut = audioCtx.createGain(); rightCut = audioCtx.createGain();
      normalGain = audioCtx.createGain();
      vocalCutGain = audioCtx.createGain();
      normalMerge = audioCtx.createGain();

      // Normal direct path
      node.connect(normalGain); normalGain.connect(normalMerge);

      // Side-only L-R path cancels center vocals
      node.connect(splitter);
      splitter.connect(cutMerger, 0, 0);
      splitter.connect(rightCut, 1);
      rightCut.connect(cutMerger, 0, 0);
      splitter.connect(cutMerger, 1, 1);
      splitter.connect(leftCut, 0);
      leftCut.connect(cutMerger, 0, 1);
      cutMerger.connect(vocalCutGain);
      vocalCutGain.connect(normalMerge);

      // Dry vs Spatial Reverb Wet Mix
      dryGain = audioCtx.createGain();
      reverbGain = audioCtx.createGain();
      reverbConvolver = audioCtx.createConvolver();
      reverbConvolver.buffer = buildImpulseResponse(audioCtx, 2.5);
      analyser = audioCtx.createAnalyser(); analyser.fftSize = 128;

      normalMerge.connect(dryGain); dryGain.connect(analyser);
      normalMerge.connect(reverbConvolver); reverbConvolver.connect(reverbGain); reverbGain.connect(analyser);
      analyser.connect(audioCtx.destination);
    }
    if (audioCtx.state === 'suspended') audioCtx.resume().catch(() => {});
    applyDspParameters();
  }

  function applyDspParameters() {
    localAudio.playbackRate = playbackSpeed;
    streamAudio.playbackRate = playbackSpeed;
    const preserve = !isSlowedReverb;
    try { localAudio.preservesPitch = preserve; streamAudio.preservesPitch = preserve; } catch (_) {}

    if (!audioCtx) return;
    eqFilters.forEach((f, idx) => { f.gain.value = eqEnabled ? eqGains[idx] : 0; });
    bassShelf.gain.value = eqEnabled ? bassBoost * 9 : 0;
    trebleShelf.gain.value = eqEnabled ? trebleBoost * 9 : 0;
    preampGain.gain.value = eqEnabled ? Math.pow(10, preampDb / 20) : 1;

    if (isKaraoke) {
      normalGain.gain.value = 1 - vocalAttenuation;
      vocalCutGain.gain.value = vocalAttenuation;
      leftCut.gain.value = -1;
      rightCut.gain.value = -1;
    } else {
      normalGain.gain.value = 1;
      vocalCutGain.gain.value = 0;
    }

    if (isReverb) {
      dryGain.gain.value = 0.72;
      reverbGain.gain.value = isSlowedReverb ? 0.45 : 0.35;
    } else {
      dryGain.gain.value = 1.0;
      reverbGain.gain.value = 0;
    }
  }

  // =========================================================================
  // PLAYBACK ENGINE & SYNCED LYRICS
  // =========================================================================
  async function playTrack(track, trackQueue) {
    if (trackQueue && trackQueue.length) queue = [...trackQueue];
    currentTrack = track;
    localAudio.pause(); streamAudio.pause();
    if (activeObjectUrl) { URL.revokeObjectURL(activeObjectUrl); activeObjectUrl = null; }

    let playUrl = track.url || track.streamUrl || '';
    if (track.blob) {
      ensureWebAudioGraphForLocal();
      activeAudio = localAudio;
      activeObjectUrl = URL.createObjectURL(track.blob);
      playUrl = activeObjectUrl;
    } else {
      activeAudio = streamAudio;
      activeAudio.playbackRate = playbackSpeed;
    }

    if (!playUrl && track.id && track.id.startsWith('yt-')) {
      showToast('Resolving YouTube audio stream...');
      playUrl = `${WORKER_URL}/api/stream/yt/audio?videoId=${encodeURIComponent(track.id.replace(/^yt-/, ''))}`;
    } else if (!playUrl && track.id && track.id.startsWith('sc-')) {
      showToast('Resolving SoundCloud audio...');
      playUrl = `${WORKER_URL}/api/stream/soundcloud/stream?trackId=${encodeURIComponent(track.id)}`;
    } else if (!playUrl && (track.source === 'spotify' || (track.id && track.id.startsWith('sp-')))) {
      showToast('Resolving Spotify Audio Bridge...');
      try {
        const bRes = await fetch(`${WORKER_URL}/api/stream/spotify/bridge?title=${encodeURIComponent(track.title || '')}&artist=${encodeURIComponent(track.artist || '')}`);
        if (bRes.ok) {
          const bData = await bRes.json();
          if (bData.streamUrl) {
            playUrl = bData.streamUrl;
            track.url = playUrl;
          }
        }
      } catch (_) {}
    }

    activeAudio.src = playUrl;
    document.getElementById('pb-title').textContent = track.title;
    document.getElementById('pb-artist').textContent = track.artist || 'MUXIS';
    const pbImg = document.getElementById('pb-art');
    pbImg.onerror = () => { pbImg.src = '../assets/muxis_app_icon.png'; };
    pbImg.src = track.artwork || track.artworkUrl || '../assets/muxis_app_icon.png';
    document.getElementById('np-big-title').textContent = track.title;
    document.getElementById('np-big-artist').textContent = track.artist || 'MUXIS';
    const bigImg = document.getElementById('np-big-art');
    bigImg.onerror = () => { bigImg.src = '../assets/muxis_app_icon.png'; };
    bigImg.src = track.artwork || track.artworkUrl || '../assets/muxis_app_icon.png';
    updateFavButtonState();

    try {
      await activeAudio.play();
      updatePlayButtons(true);
      updateMediaSession(track);
      recordHistory(track);
      highlightCurrentTrack();
      fetchSyncedLyricsForTrack(track);
      renderNpQueue();
    } catch (_) {
      if (!track.blob && track.id?.startsWith('yt-') && !track._bridgedRetry) {
        try {
          const br = await fetch(`${WORKER_URL}/api/stream/spotify/bridge?title=${encodeURIComponent(track.title || '')}&artist=${encodeURIComponent(track.artist || '')}`);
          if (br.ok) {
            const bd = await br.json();
            if (bd.streamUrl) {
              track._bridgedRetry = true;
              track.url = bd.streamUrl;
              activeAudio.src = bd.streamUrl;
              await activeAudio.play();
              updatePlayButtons(true);
              updateMediaSession(track);
              recordHistory(track);
              highlightCurrentTrack();
              fetchSyncedLyricsForTrack(track);
              renderNpQueue();
              showToast('Playing via Open Audio Bridge');
              return;
            }
          }
        } catch (_) {}
      }
      showToast(track.id?.startsWith('yt-') ? 'Stream unavailable on this track — try another song or Search' : 'Tap play again to start audio');
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
      title: track.title, artist: track.artist || 'MUXIS', album: track.album || 'MUXIS Audio',
      artwork: [{ src: track.artwork || track.artworkUrl || 'icons/icon-512.png', sizes: '512x512', type: 'image/png' }]
    });
    navigator.mediaSession.setActionHandler('play', () => activeAudio.play());
    navigator.mediaSession.setActionHandler('pause', () => activeAudio.pause());
    navigator.mediaSession.setActionHandler('nexttrack', playNext);
    navigator.mediaSession.setActionHandler('previoustrack', playPrev);
  }

  function playNext() {
    if (!queue.length) return;
    if (repeatMode === 'one' && currentTrack) { activeAudio.currentTime = 0; activeAudio.play().catch(() => {}); return; }
    if (isShuffle && queue.length > 1) {
      const next = queue[Math.floor(Math.random() * queue.length)];
      playTrack(next);
      return;
    }
    const idx = currentTrack ? queue.findIndex((t) => t.id === currentTrack.id) : -1;
    if (idx + 1 >= queue.length && repeatMode === 'off') return;
    playTrack(queue[(idx + 1) % queue.length]);
  }

  function playPrev() {
    if (!queue.length) return;
    const idx = currentTrack ? queue.findIndex((t) => t.id === currentTrack.id) : 0;
    playTrack(queue[(idx - 1 + queue.length) % queue.length]);
  }

  function fmtTime(sec) {
    if (!sec || !Number.isFinite(sec)) return '0:00';
    const m = Math.floor(sec / 60);
    const s = Math.floor(sec % 60);
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  }

  function initAudioControls() {
    const toggle = () => {
      if (!currentTrack && queue.length) { playTrack(queue[0]); return; }
      if (activeAudio.paused) activeAudio.play().catch(() => {}); else activeAudio.pause();
    };
    document.getElementById('pb-play-btn').addEventListener('click', toggle);
    document.getElementById('np-play-btn').addEventListener('click', toggle);
    document.getElementById('pb-next-btn').addEventListener('click', playNext);
    document.getElementById('np-next-btn').addEventListener('click', playNext);
    document.getElementById('np-prev-btn').addEventListener('click', playPrev);
    document.getElementById('pb-fav-btn').addEventListener('click', () => { if (currentTrack) toggleFavorite(currentTrack); });
    document.getElementById('np-add-pl-btn').addEventListener('click', () => { if (currentTrack) openPlaylistPicker(currentTrack); });

    document.getElementById('np-shuffle-btn').addEventListener('click', (e) => {
      isShuffle = !isShuffle;
      e.currentTarget.classList.toggle('toggle-on', isShuffle);
      showToast(isShuffle ? 'Shuffle On' : 'Shuffle Off');
    });
    document.getElementById('np-repeat-btn').addEventListener('click', (e) => {
      repeatMode = repeatMode === 'all' ? 'one' : (repeatMode === 'one' ? 'off' : 'all');
      e.currentTarget.classList.toggle('toggle-on', repeatMode !== 'off');
      e.currentTarget.innerHTML = repeatMode === 'one' ? '&#128258;' : '&#128257;';
      showToast(`Repeat: ${repeatMode}`);
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
        document.getElementById('np-cur-time').textContent = fmtTime(el.currentTime);
        document.getElementById('np-tot-time').textContent = fmtTime(el.duration);
        syncActiveLyricLine(el.currentTime);
      });
    });

    document.getElementById('np-seek-range').addEventListener('input', (e) => {
      if (activeAudio.duration && Number.isFinite(activeAudio.duration)) {
        activeAudio.currentTime = (Number(e.target.value) / 100) * activeAudio.duration;
      }
    });

    document.getElementById('home-spotlight-play').addEventListener('click', () => {
      const source = trendingTracks.length ? trendingTracks : FEATURED_TRACKS;
      playTrack(source[0], source);
    });
    document.getElementById('home-import-btn').addEventListener('click', () => document.getElementById('local-file-input').click());
    document.getElementById('lib-import-btn').addEventListener('click', () => document.getElementById('local-file-input').click());
    document.getElementById('lib-folder-btn').addEventListener('click', () => document.getElementById('local-folder-input').click());
    document.getElementById('local-file-input').addEventListener('change', (e) => { handleFileImport(e.target.files); e.target.value = ''; });
    document.getElementById('local-folder-input').addEventListener('change', (e) => { handleFileImport(e.target.files); e.target.value = ''; });
  }

  // =========================================================================
  // LYRICS (LRCLIB Synced LRC Parser + Live Scroll)
  // =========================================================================
  async function fetchSyncedLyricsForTrack(track) {
    const box = document.getElementById('np-lyrics-scroll');
    syncedLyrics = []; activeLyricIdx = -1;
    box.innerHTML = '<p class="lyrics-empty">Searching synchronized lyrics...</p>';
    try {
      const qs = new URLSearchParams({ title: track.title || '', artist: track.artist || '' });
      const res = await fetch(`${WORKER_URL}/api/stream/lyrics?${qs.toString()}`);
      if (!res.ok) throw new Error();
      const d = await res.json();
      if (d.syncedLyrics) {
        syncedLyrics = parseLrc(d.syncedLyrics);
        renderLyricsLines(true);
        return;
      }
      if (d.plainLyrics) {
        syncedLyrics = d.plainLyrics.split(/\r?\n/).filter(Boolean).map((text) => ({ timeSec: -1, text }));
        renderLyricsLines(false);
        return;
      }
    } catch {}
    box.innerHTML = '<p class="lyrics-empty">No synced lyrics found for this track.</p>';
  }

  function parseLrc(lrc) {
    const out = [];
    const rx = /^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$/;
    lrc.split(/\r?\n/).forEach((raw) => {
      const m = raw.trim().match(rx);
      if (!m) return;
      const sec = parseInt(m[1], 10) * 60 + parseInt(m[2], 10) + parseInt(m[3].padEnd(3, '0').slice(0, 3), 10) / 1000;
      const text = m[4].replace(/<[^>]*>/g, '').trim() || '♪';
      out.push({ timeSec: sec, text });
    });
    return out.sort((a, b) => a.timeSec - b.timeSec);
  }

  function renderLyricsLines(isSynced) {
    const box = document.getElementById('np-lyrics-scroll');
    box.innerHTML = '';
    syncedLyrics.forEach((line, idx) => {
      const p = document.createElement('p');
      p.className = 'lyric-line';
      p.textContent = line.text;
      p.dataset.idx = String(idx);
      if (isSynced && line.timeSec >= 0) {
        p.addEventListener('click', () => { activeAudio.currentTime = line.timeSec; if (activeAudio.paused) activeAudio.play().catch(() => {}); });
      }
      box.appendChild(p);
    });
  }

  function syncActiveLyricLine(curSec) {
    if (!syncedLyrics.length || syncedLyrics[0].timeSec < 0) return;
    let nextIdx = -1;
    for (let i = 0; i < syncedLyrics.length; i++) {
      if (curSec >= syncedLyrics[i].timeSec) nextIdx = i; else break;
    }
    if (nextIdx === activeLyricIdx) return;
    activeLyricIdx = nextIdx;
    const nodes = document.querySelectorAll('#np-lyrics-scroll .lyric-line');
    nodes.forEach((el, i) => {
      const act = i === nextIdx;
      el.classList.toggle('active', act);
      if (act) el.scrollIntoView({ behavior: 'smooth', block: 'center' });
    });
  }

  // =========================================================================
  // MOBILE AUDIO STUDIO DSP UI & SPECTRUM
  // =========================================================================
  function initEqStudio() {
    const container = document.getElementById('eq-sliders-container');
    container.innerHTML = '';
    EQ_LABELS.forEach((lbl, i) => {
      const col = document.createElement('div'); col.className = 'eq-band-col';
      const val = document.createElement('span'); val.className = 'eq-db'; val.textContent = `${eqGains[i] >= 0 ? '+' : ''}${eqGains[i].toFixed(1)}`;
      const wrap = document.createElement('div'); wrap.className = 'eq-vert-wrap';
      const range = document.createElement('input');
      range.type = 'range'; range.min = '-12'; range.max = '12'; range.step = '0.5'; range.value = String(eqGains[i]); range.className = 'eq-range';
      range.addEventListener('input', () => {
        const g = parseFloat(range.value); eqGains[i] = g;
        val.textContent = `${g >= 0 ? '+' : ''}${g.toFixed(1)}`;
        applyDspParameters();
      });
      wrap.appendChild(range);
      const hz = document.createElement('span'); hz.className = 'eq-hz'; hz.textContent = lbl;
      col.append(val, wrap, hz); container.appendChild(col);
    });

    document.getElementById('eq-bypass-toggle').onchange = (e) => { eqEnabled = e.target.checked; applyDspParameters(); };
    document.getElementById('eq-reset-flat-btn').onclick = () => {
      activePresetName = 'Flat'; eqGains = [...EQ_PRESETS.Flat]; initEqStudio(); applyDspParameters();
    };
    document.querySelectorAll('#studio-preset-chips .filter-chip').forEach((chip) => {
      chip.onclick = () => {
        const name = chip.dataset.preset; if (!EQ_PRESETS[name]) return;
        activePresetName = name; eqGains = [...EQ_PRESETS[name]]; initEqStudio(); applyDspParameters();
        document.querySelectorAll('#studio-preset-chips .filter-chip').forEach((c) => c.classList.toggle('active', c === chip));
        if (authToken) pushCloudSync({ settings: { dark_preset: activeThemeId, eq_preset: name } });
      };
    });

    document.getElementById('dsp-bass-range').oninput = (e) => {
      bassBoost = Number(e.target.value) / 100;
      document.getElementById('val-bass').textContent = `${e.target.value}%`;
      applyDspParameters();
    };
    document.getElementById('dsp-treble-range').oninput = (e) => {
      trebleBoost = Number(e.target.value) / 100;
      document.getElementById('val-treble').textContent = `${e.target.value}%`;
      applyDspParameters();
    };
    document.getElementById('dsp-preamp-range').oninput = (e) => {
      preampDb = Number(e.target.value);
      document.getElementById('val-preamp').textContent = `${preampDb >= 0 ? '+' : ''}${preampDb.toFixed(1)} dB`;
      applyDspParameters();
    };
    document.getElementById('dsp-speed-range').oninput = (e) => {
      playbackSpeed = Number(e.target.value);
      document.getElementById('val-speed').textContent = `${playbackSpeed.toFixed(2)}x`;
      applyDspParameters();
    };
    document.getElementById('dsp-vocal-range').oninput = (e) => {
      vocalAttenuation = Number(e.target.value) / 100;
      document.getElementById('val-vocal').textContent = `${e.target.value}%`;
      applyDspParameters();
    };
    document.getElementById('fx-slowed-btn').onclick = (e) => {
      isSlowedReverb = !isSlowedReverb;
      e.currentTarget.classList.toggle('active', isSlowedReverb);
      if (isSlowedReverb) { playbackSpeed = 0.85; isReverb = true; } else { playbackSpeed = 1.0; isReverb = false; }
      document.getElementById('dsp-speed-range').value = String(playbackSpeed);
      document.getElementById('val-speed').textContent = `${playbackSpeed.toFixed(2)}x`;
      document.getElementById('fx-reverb-btn').classList.toggle('active', isReverb);
      applyDspParameters();
    };
    document.getElementById('fx-karaoke-btn').onclick = (e) => {
      isKaraoke = !isKaraoke;
      e.currentTarget.classList.toggle('active', isKaraoke);
      document.getElementById('vocal-cut-row').style.display = isKaraoke ? 'flex' : 'none';
      applyDspParameters();
    };
    document.getElementById('fx-reverb-btn').onclick = (e) => {
      isReverb = !isReverb;
      e.currentTarget.classList.toggle('active', isReverb);
      applyDspParameters();
    };
    document.getElementById('fx-reset-all-btn').onclick = () => {
      isSlowedReverb = false; isKaraoke = false; isReverb = false; playbackSpeed = 1.0;
      bassBoost = 0; trebleBoost = 0; preampDb = 0;
      ['dsp-bass-range', 'dsp-treble-range', 'dsp-preamp-range'].forEach((id) => { document.getElementById(id).value = '0'; });
      document.getElementById('dsp-speed-range').value = '1.0';
      document.getElementById('val-bass').textContent = '0%'; document.getElementById('val-treble').textContent = '0%';
      document.getElementById('val-preamp').textContent = '+0.0 dB'; document.getElementById('val-speed').textContent = '1.00x';
      ['fx-slowed-btn', 'fx-karaoke-btn', 'fx-reverb-btn'].forEach((id) => document.getElementById(id).classList.remove('active'));
      document.getElementById('vocal-cut-row').style.display = 'none';
      applyDspParameters();
    };
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
        if (canvas.width !== Math.round(rect.width * dpr)) { canvas.width = Math.round(rect.width * dpr); canvas.height = Math.round(rect.height * dpr); }
        const ctx = canvas.getContext('2d'); ctx.setTransform(dpr, 0, 0, dpr, 0, 0); ctx.clearRect(0, 0, rect.width, rect.height);
        const playing = !activeAudio.paused && !!activeAudio.src;
        const useFft = playing && analyser && currentTrack && currentTrack.blob;
        if (useFft) analyser.getByteFrequencyData(freqData);
        const t = THEMES[activeThemeId] || THEMES.obsidian_aurora;
        const grad = ctx.createLinearGradient(0, 0, rect.width, 0);
        grad.addColorStop(0, t.accent); grad.addColorStop(0.5, t.secondary); grad.addColorStop(1, t.tertiary);
        ctx.fillStyle = grad; tick++;
        const gap = rect.width / levels.length, bw = Math.max(3, gap * 0.62);
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
  // PLAYLISTS, ALBUMS, ARTISTS & RENDERERS
  // =========================================================================
  function createPlaylist(title, initialTrack) {
    const existing = playlists.find((p) => p.title.toLowerCase() === title.toLowerCase());
    if (existing) {
      if (initialTrack && !existing.tracks.some((t) => (t.track_uri || t.url || t.id) === (initialTrack.track_uri || initialTrack.url || initialTrack.id))) {
        existing.tracks.push(normalizeTrackDto(initialTrack));
      }
    } else {
      playlists.unshift({ title, tracks: initialTrack ? [normalizeTrackDto(initialTrack)] : [] });
    }
    saveJson('muxis_pwa_playlists', playlists);
    renderLibraryArea();
    if (authToken) pushAllStateToCloud();
    showToast(`Saved to playlist "${title}"`);
  }

  function openPlaylistPicker(track) {
    pendingAddTrack = track;
    const sheet = document.getElementById('playlist-picker-backdrop');
    const list = document.getElementById('picker-playlists-list');
    list.innerHTML = '';
    if (!playlists.length) {
      list.innerHTML = '<div style="font-size:13px;color:var(--text-muted);padding:10px;">Create your first playlist above.</div>';
    } else {
      playlists.forEach((pl) => {
        const row = document.createElement('div'); row.className = 'track-row liquid-card';
        row.innerHTML = `<div class="track-art"><span style="color:var(--accent);">&#9776;</span></div><div class="track-info"><strong></strong><span></span></div>`;
        row.querySelector('strong').textContent = pl.title;
        row.querySelector('span').textContent = `${pl.tracks.length} tracks`;
        row.addEventListener('click', () => { createPlaylist(pl.title, track); sheet.classList.remove('open'); });
        list.appendChild(row);
      });
    }
    sheet.classList.add('open');
  }

  function normalizeTrackDto(t) {
    const uri = t.track_uri || t.url || t.streamUrl || t.id;
    return { id: t.id, track_uri: uri, title: t.title, artist: t.artist || 'MUXIS', album: t.album || '', artwork: t.artwork || t.artworkUrl || '', url: t.url || t.streamUrl || '', badge: t.badge || t.audioFormat || 'TRACK' };
  }

  function renderCarousel(elId, list) {
    const wrap = document.getElementById(elId); wrap.innerHTML = '';
    list.forEach((tr) => {
      const c = document.createElement('div'); c.className = 'muxis-sq-card liquid-card';
      const artDiv = document.createElement('div'); artDiv.className = 'sq-art';
      const artUrl = tr.artwork || tr.artworkUrl;
      if (artUrl) {
        const img = document.createElement('img');
        img.src = artUrl; img.alt = '';
        img.style.cssText = 'width:100%;height:100%;object-fit:cover;';
        img.onerror = () => { artDiv.innerHTML = '<span>&#9835;</span>'; };
        artDiv.appendChild(img);
      } else {
        artDiv.innerHTML = '<span>&#9835;</span>';
      }
      const st = document.createElement('strong'); st.textContent = tr.title;
      const sm = document.createElement('small'); sm.textContent = tr.artist || '';
      c.append(artDiv, st, sm);
      c.addEventListener('click', () => playTrack(tr, list));
      wrap.appendChild(c);
    });
  }

  function renderTrackRows(container, list, playlistContextTitle = null) {
    container.innerHTML = '';
    if (!list.length) {
      const empty = document.createElement('div');
      empty.style.cssText = 'padding:18px;text-align:center;color:var(--text-muted);font-size:13px;border:1px dashed var(--border);border-radius:14px;';
      empty.textContent = 'No tracks yet.'; container.appendChild(empty); return;
    }
    list.forEach((t) => {
      const row = document.createElement('div');
      row.className = 'track-row liquid-card' + (currentTrack && currentTrack.id === t.id ? ' playing' : '');
      row.dataset.trackId = t.id;
      const art = document.createElement('div'); art.className = 'track-art';
      const imgSrc = t.artwork || t.artworkUrl;
      if (imgSrc) {
        const img = document.createElement('img'); img.src = imgSrc; img.alt = '';
        img.onerror = () => { art.innerHTML = '<span style="color:var(--accent);font-weight:900;">&#9835;</span>'; };
        art.appendChild(img);
      } else { art.innerHTML = '<span style="color:var(--accent);font-weight:900;">&#9835;</span>'; }
      const info = document.createElement('div'); info.className = 'track-info';
      const title = document.createElement('strong'); title.textContent = t.title;
      const artLine = document.createElement('span'); artLine.textContent = t.artist || 'MUXIS';
      info.append(title, artLine);
      const pill = document.createElement('span'); pill.className = 'fmt-pill'; pill.textContent = t.badge || t.audioFormat || 'AUDIO';
      const nextBtn = document.createElement('button'); nextBtn.type = 'button'; nextBtn.className = 'pb-icon-btn'; nextBtn.innerHTML = '&#8627;';
      nextBtn.title = 'Play Next in Queue'; nextBtn.addEventListener('click', (e) => { e.stopPropagation(); enqueueTrack(t, true); });
      const addPlBtn = document.createElement('button'); addPlBtn.type = 'button'; addPlBtn.className = 'pb-icon-btn'; addPlBtn.innerHTML = '&#43;';
      addPlBtn.title = 'Add to Playlist'; addPlBtn.addEventListener('click', (e) => { e.stopPropagation(); openPlaylistPicker(t); });
      const fav = document.createElement('button'); fav.type = 'button'; fav.className = 'pb-icon-btn' + (isFavorite(t.id) ? ' fav' : '');
      fav.innerHTML = isFavorite(t.id) ? '&#9829;' : '&#9825;';
      fav.addEventListener('click', (e) => { e.stopPropagation(); toggleFavorite(t); });
      row.append(art, info, pill, nextBtn, addPlBtn, fav);
      if (playlistContextTitle) {
        const rm = document.createElement('button'); rm.type = 'button'; rm.className = 'pb-icon-btn'; rm.textContent = '×';
        rm.addEventListener('click', (e) => {
          e.stopPropagation();
          const pl = playlists.find((p) => p.title === playlistContextTitle);
          if (pl) { pl.tracks = pl.tracks.filter((x) => x.id !== t.id); saveJson('muxis_pwa_playlists', playlists); renderLibraryArea(); if (authToken) pushAllStateToCloud(); }
        });
        row.appendChild(rm);
      }
      row.addEventListener('click', () => playTrack(t, list));
      container.appendChild(row);
    });
  }

  function renderLibraryArea() {
    const subActions = document.getElementById('library-sub-actions');
    const area = document.getElementById('library-content-area');
    subActions.style.display = 'none'; subActions.innerHTML = ''; area.innerHTML = '';
    updateLibrarySummary();

    const applyFilterSort = (tracks) => {
      let arr = tracks.filter((t) => !libSearch || `${t.title} ${t.artist} ${t.album}`.toLowerCase().includes(libSearch));
      if (libSort === 'title') arr.sort((a, b) => (a.title || '').localeCompare(b.title || ''));
      else if (libSort === 'artist') arr.sort((a, b) => (a.artist || '').localeCompare(b.artist || ''));
      return arr;
    };

    if (openPlaylistTitle) {
      const pl = playlists.find((p) => p.title === openPlaylistTitle);
      if (pl) {
        subActions.style.display = 'flex'; subActions.style.gap = '8px'; subActions.style.flexWrap = 'wrap';
        const backBtn = document.createElement('button'); backBtn.type = 'button'; backBtn.className = 'ghost-btn-sm'; backBtn.textContent = '← All Playlists';
        backBtn.onclick = () => { openPlaylistTitle = null; renderLibraryArea(); };
        const playAllBtn = document.createElement('button'); playAllBtn.type = 'button'; playAllBtn.className = 'prism-btn-sm'; playAllBtn.textContent = `▶ Play "${pl.title}"`;
        playAllBtn.onclick = () => { if (pl.tracks.length) playTrack(pl.tracks[0], pl.tracks); };
        const delBtn = document.createElement('button'); delBtn.type = 'button'; delBtn.className = 'ghost-btn-sm'; delBtn.style.color = '#fca5a5'; delBtn.textContent = 'Delete Playlist';
        delBtn.onclick = () => {
          const title = pl.title; playlists = playlists.filter((x) => x.title !== title); saveJson('muxis_pwa_playlists', playlists);
          if (authToken) pushCloudSync({ mutations: [{ entityType: 'playlist', action: 'delete', data: { title } }] });
          openPlaylistTitle = null; renderLibraryArea();
        };
        subActions.append(backBtn, playAllBtn, delBtn);
        renderTrackRows(area, applyFilterSort(pl.tracks), pl.title);
        return;
      }
    }

    if (openGroupFilter) {
      const combined = [...localTracks, ...favorites];
      const matches = combined.filter((t) => openGroupFilter.type === 'album' ? (t.album || 'Singles') === openGroupFilter.value : (t.artist || 'Unknown Artist') === openGroupFilter.value);
      subActions.style.display = 'flex'; subActions.innerHTML = `<button type="button" id="grp-back" class="ghost-btn-sm">&larr; Back to ${openGroupFilter.type}s</button>`;
      document.getElementById('grp-back').onclick = () => { openGroupFilter = null; renderLibraryArea(); };
      renderTrackRows(area, applyFilterSort(matches));
      return;
    }

    if (libFilter === 'playlists') {
      subActions.style.display = 'block';
      subActions.innerHTML = `<button type="button" id="new-pl-inline" class="prism-btn-sm">+ Create New Playlist</button>`;
      document.getElementById('new-pl-inline').onclick = () => openPlaylistPicker(null);
      if (!playlists.length) { area.innerHTML = '<div style="padding:18px;text-align:center;color:var(--text-muted);font-size:13px;">No playlists yet. Tap Create New Playlist!</div>'; return; }
      playlists.forEach((pl) => {
        const row = document.createElement('div'); row.className = 'track-row liquid-card';
        row.innerHTML = `<div class="track-art"><span style="color:var(--accent);">&#9776;</span></div><div class="track-info"><strong></strong><span></span></div><span class="fmt-pill">PLAYLIST</span>`;
        row.querySelector('strong').textContent = pl.title;
        row.querySelector('span').textContent = `${pl.tracks.length} tracks`;
        row.addEventListener('click', () => { openPlaylistTitle = pl.title; renderLibraryArea(); });
        area.appendChild(row);
      });
      return;
    }

    if (libFilter === 'albums' || libFilter === 'artists') {
      const map = new Map();
      [...localTracks, ...favorites].forEach((t) => {
        const k = libFilter === 'albums' ? (t.album || 'Singles & Unknown') : (t.artist || 'Unknown Artist');
        if (!map.has(k)) map.set(k, []);
        map.get(k).push(t);
      });
      if (!map.size) { area.innerHTML = '<div style="padding:18px;text-align:center;color:var(--text-muted);font-size:13px;">Import files or favorite tracks to browse.</div>'; return; }
      Array.from(map.entries()).forEach(([name, items]) => {
        const row = document.createElement('div'); row.className = 'track-row liquid-card';
        row.innerHTML = `<div class="track-art"><span style="color:var(--secondary);">&#9835;</span></div><div class="track-info"><strong></strong><span></span></div>`;
        row.querySelector('strong').textContent = name;
        row.querySelector('span').textContent = `${items.length} track(s)`;
        row.addEventListener('click', () => { openGroupFilter = { type: libFilter.slice(0, -1), value: name }; renderLibraryArea(); });
        area.appendChild(row);
      });
      return;
    }

    const base = libFilter === 'favorites' ? favorites : (libFilter === 'history' ? history : localTracks);
    renderTrackRows(area, applyFilterSort(base));
  }

  function renderNpQueue() {
    renderTrackRows(document.getElementById('np-queue-list'), queue);
  }

  function highlightCurrentTrack() {
    document.querySelectorAll('.track-row').forEach((r) => r.classList.toggle('playing', currentTrack && r.dataset.trackId === currentTrack.id));
  }

  function renderHomeRecent() { renderTrackRows(document.getElementById('home-recent-list'), history.slice(0, 6)); }
  function updateLibrarySummary() { document.getElementById('lib-summary-line').textContent = `${localTracks.length} Local Tracks · ${playlists.length} Playlists · ${favorites.length} Favs`; }
  function isFavorite(id) { return favorites.some((f) => f.id === id || f.track_uri === id); }
  function updateFavButtonState() {
    const btn = document.getElementById('pb-fav-btn'); const fav = currentTrack && isFavorite(currentTrack.id);
    btn.classList.toggle('fav', Boolean(fav)); btn.innerHTML = fav ? '&#9829;' : '&#9825;';
  }

  function toggleFavorite(track) {
    const uri = track.url || track.streamUrl || track.id;
    const idx = favorites.findIndex((f) => f.id === track.id || f.track_uri === uri);
    if (idx >= 0) {
      favorites.splice(idx, 1);
      if (authToken) pushCloudSync({ mutations: [{ entityType: 'favorite', action: 'delete', data: { track_uri: uri } }] });
    } else {
      favorites.unshift(Object.assign(normalizeTrackDto(track), { badge: 'FAV' }));
      if (authToken) pushCloudSync({ favorites: [{ track_uri: uri, title: track.title, artist: track.artist || 'MUXIS', album: track.album || '' }] });
    }
    saveJson('muxis_pwa_favorites', favorites); updateFavButtonState(); renderLibraryArea(); renderHomeRecent();
  }

  function recordHistory(track) {
    const uri = track.url || track.streamUrl || track.id;
    history = [Object.assign(normalizeTrackDto(track), { badge: 'PLAYED' }), ...history.filter((h) => h.id !== track.id)].slice(0, 30);
    saveJson('muxis_pwa_history', history); renderHomeRecent();
    if (authToken) pushCloudSync({ history: [{ track_uri: uri, title: track.title, artist: track.artist || 'MUXIS', played_at: new Date().toISOString() }] });
  }

  // =========================================================================
  // TRENDING STREAMS, RADIO & SEARCH
  // =========================================================================
  async function loadTrendingStreams() {
    try {
      const res = await fetch(`${WORKER_URL}/api/stream/yt/home`);
      if (res.ok) {
        const d = await res.json();
        trendingTracks = (d.tracks || []).filter((t) => t.streamUrl).map((t) => Object.assign(t, { url: t.streamUrl }));
        renderCarousel('home-trending-carousel', trendingTracks.slice(0, 12));
      }
    } catch {}
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
          id: `radio-${s.stationuuid}`, title: (s.name || 'FM Radio').trim(), artist: `${s.country || 'Global'} · ${s.bitrate || 128}kbps`,
          badge: 'FM LIVE', artwork: s.favicon && s.favicon.startsWith('https://') ? s.favicon : '', url: s.url_resolved
        }));
        renderTrackRows(el, radioStations);
        return;
      } catch (_) {}
    }
    el.innerHTML = '<div style="padding:18px;color:var(--text-muted);font-size:13px;">Radio unavailable right now.</div>';
  }

  async function runGlobalSearch() {
    const q = document.getElementById('global-search-input').value.trim();
    const listEl = document.getElementById('search-results-list');
    if (!q) { renderTrackRows(listEl, FEATURED_TRACKS); return; }
    listEl.innerHTML = '<div style="padding:18px;color:var(--text-muted);font-size:13px;">Searching streams, radio &amp; library...</div>';

    const localHits = [...localTracks, ...FEATURED_TRACKS].filter((t) => `${t.title} ${t.artist}`.toLowerCase().includes(q.toLowerCase()));
    let streamHits = [];
    try {
      const sRes = await fetch(`${WORKER_URL}/api/stream/yt/search?q=${encodeURIComponent(q)}`);
      if (sRes.ok) {
        const sData = await sRes.json();
        streamHits = (sData.tracks || []).filter((t) => t.streamUrl).map((t) => Object.assign(t, { url: t.streamUrl }));
      }
    } catch {}
    await loadRadioStations(q, 'search-results-list');
    renderTrackRows(listEl, [...localHits, ...streamHits, ...radioStations]);
  }

  // =========================================================================
  // SLEEP TIMER, ACCOUNT ACTIONS & D1 SYNC
  // =========================================================================
  function setSleepTimer(minutes) {
    if (sleepInterval) { clearInterval(sleepInterval); sleepInterval = null; }
    const badge = document.getElementById('sleep-timer-badge');
    if (!minutes) { badge.textContent = ''; return; }
    sleepDeadline = Date.now() + minutes * 60 * 1000;
    showToast(`Sleep timer set for ${minutes} min`);
    sleepInterval = setInterval(() => {
      const rem = sleepDeadline - Date.now();
      if (rem <= 0) {
        clearInterval(sleepInterval); sleepInterval = null; badge.textContent = '';
        localAudio.pause(); streamAudio.pause(); updatePlayButtons(false);
        showToast('Sleep timer paused playback');
      } else {
        badge.textContent = `Sleep ${Math.ceil(rem / 60000)}m`;
      }
    }, 5000);
  }

  async function regenerateRecoveryKey() {
    if (!authToken) return;
    try {
      const res = await fetch(`${WORKER_URL}/api/auth/regenerate-recovery`, {
        method: 'POST', headers: { Authorization: `Bearer ${authToken}` }
      });
      const d = await res.json();
      if (d.recovery_key) {
        const box = document.getElementById('recovery-key-display');
        box.textContent = `Recovery Key (save safely): ${d.recovery_key}`;
        box.style.display = 'block';
      }
    } catch {}
  }

  async function deleteCloudAccount() {
    if (!authToken || !window.confirm('Permanently delete your MUXIS Cloud account and all D1 synced playlists/favorites?')) return;
    try {
      const res = await fetch(`${WORKER_URL}/api/auth/account`, { method: 'DELETE', headers: { Authorization: `Bearer ${authToken}` } });
      if (res.ok) { showToast('Cloud account deleted'); signOutAll(); }
    } catch {}
  }

  async function pullCloudSync() {
    if (!authToken) return;
    try {
      const res = await fetch(`${WORKER_URL}/api/sync/pull`, { headers: { Authorization: `Bearer ${authToken}`, 'X-Muxis-Client': 'pwa' } });
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
      if (Array.isArray(d.playlists)) {
        d.playlists.forEach((rpl) => {
          if (!playlists.some((p) => p.title === rpl.title)) {
            playlists.push({
              title: rpl.title,
              tracks: (rpl.tracks || []).map((t) => ({
                id: `cloud-${t.track_uri}`, track_uri: t.track_uri, title: t.title, artist: t.artist,
                album: t.album || '', url: t.track_uri.startsWith('http') ? t.track_uri : '', badge: 'SYNCED'
              }))
            });
          }
        });
        saveJson('muxis_pwa_playlists', playlists);
      }
      if (d.settings?.dark_preset && THEMES[d.settings.dark_preset]) initTheme(d.settings.dark_preset);
      if (d.settings?.eq_preset && EQ_PRESETS[d.settings.eq_preset]) {
        activePresetName = d.settings.eq_preset; eqGains = [...EQ_PRESETS[activePresetName]]; initEqStudio();
      }
    } catch (_) {}
  }

  async function pushAllStateToCloud() {
    return pushCloudSync({
      playlists: playlists.map((pl) => ({ title: pl.title, tracks: pl.tracks.map(normalizeTrackDto) })),
      favorites: favorites.map(normalizeTrackDto),
      settings: { dark_preset: activeThemeId, eq_preset: activePresetName }
    });
  }

  async function pushCloudSync(payload) {
    if (!authToken) return;
    try {
      await fetch(`${WORKER_URL}/api/sync/push`, {
        method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${authToken}`, 'X-Muxis-Client': 'pwa' },
        body: JSON.stringify(Object.assign({ device: { name: /iPhone|iPad/i.test(navigator.userAgent) ? 'iPhone PWA' : 'Web PWA', platform: 'pwa', client_version: '1.2.13' } }, payload))
      });
    } catch (_) {}
  }

  // =========================================================================
  // STREAMING PLATFORM CONNECTIONS & PLATFORM STREAM HUBS (YT / SPOTIFY / SC)
  // =========================================================================
  function enqueueTrack(track, playNext = true) {
    if (!track) return;
    if (!queue.length) {
      playTrack(track, [track]);
      return;
    }
    const clean = queue.filter((t) => t.id !== track.id);
    if (playNext && currentTrack) {
      const idx = clean.findIndex((t) => t.id === currentTrack.id);
      clean.splice(idx >= 0 ? idx + 1 : 0, 0, track);
    } else {
      clean.push(track);
    }
    queue = clean;
    renderNpQueue();
    showToast(playNext ? `Up next: ${track.title}` : `Queued: ${track.title}`);
  }

  function captureOAuthReturns() {
    try {
      const qs = new URLSearchParams(window.location.search);
      const code = qs.get('code');
      const state = qs.get('state') || '';
      if (code && (state.startsWith('sp_pkce_') || state.startsWith('sc_pkce_'))) {
        sessionStorage.setItem('muxis_oauth_return_platform', state.startsWith('sp_pkce_') ? 'spotify' : 'soundcloud');
        sessionStorage.setItem('muxis_oauth_return_code', code);
        qs.delete('code'); qs.delete('state');
        const cleanQs = qs.toString();
        window.history.replaceState({}, '', `${window.location.pathname}${cleanQs ? '?' + cleanQs : ''}${window.location.hash}`);
      }
    } catch (_) {}
  }

  async function completePendingOAuth() {
    const plat = sessionStorage.getItem('muxis_oauth_return_platform');
    const code = sessionStorage.getItem('muxis_oauth_return_code');
    const verifier = sessionStorage.getItem('muxis_pkce_verifier');
    const clientId = sessionStorage.getItem('muxis_pkce_cid');
    const redirectUri = sessionStorage.getItem('muxis_pkce_redir');
    if (!plat || !code || !verifier || !clientId || !authToken) return;
    sessionStorage.removeItem('muxis_oauth_return_platform');
    sessionStorage.removeItem('muxis_oauth_return_code');
    sessionStorage.removeItem('muxis_pkce_verifier');
    sessionStorage.removeItem('muxis_pkce_cid');
    sessionStorage.removeItem('muxis_pkce_redir');
    try {
      const res = await fetch(`${WORKER_URL}/api/stream/links/connect`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${authToken}`, 'X-Muxis-Client': 'pwa' },
        body: JSON.stringify({ platform: plat, mode: 'oauth_pkce', clientId, oauthCode: code, codeVerifier: verifier, redirectUri })
      });
      if (res.ok) {
        const d = await res.json();
        if (d.connection) platformLinks[plat] = d.connection;
        showToast(`${PLATFORM_META[plat].name} OAuth connected!`);
      }
    } catch (_) {}
  }

  async function loadPlatformLinks() {
    if (!authToken) { renderStreamingPlatformUI(); return; }
    try {
      const [linksRes, cfgRes] = await Promise.all([
        fetch(`${WORKER_URL}/api/stream/links`, { headers: { Authorization: `Bearer ${authToken}`, 'X-Muxis-Client': 'pwa' } }),
        fetch(`${WORKER_URL}/api/stream/links/oauth-config`, { headers: { Authorization: `Bearer ${authToken}` } }).catch(() => null)
      ]);
      if (linksRes.ok) {
        const d = await linksRes.json();
        if (d.links) {
          platformLinks = d.links;
          saveJson('muxis_pwa_platform_links', platformLinks);
        }
      }
      if (cfgRes?.ok) {
        const c = await cfgRes.json();
        oauthConfig = { spotifyClientId: c.spotifyClientId || '', soundcloudClientId: c.soundcloudClientId || '' };
      }
    } catch (_) {}
    renderStreamingPlatformUI();
  }

  function renderStreamingPlatformUI() {
    renderTopPlatformPills();
    renderHeroPlatformChips();
    renderHomePlatformSections();
    renderSettingsStreamingList();
    if (document.getElementById('tab-platform').classList.contains('active')) renderPlatformHub();
  }

  function renderTopPlatformPills() {
    const wrap = document.getElementById('top-platform-pills');
    if (!wrap) return;
    wrap.innerHTML = '';
    const isHubOpen = document.getElementById('tab-platform')?.classList.contains('active');
    ['youtube', 'spotify', 'soundcloud'].forEach((key) => {
      const meta = PLATFORM_META[key];
      const conn = platformLinks[key] || { isConnected: false };
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = `platform-pill ${meta.cls}${conn.isConnected ? ' linked' : ''}${isHubOpen && activePlatformKey === key ? ' active' : ''}`;
      btn.innerHTML = `<span class="platform-pill-dot"></span><span>${meta.shortLabel}</span>`;
      btn.title = conn.isConnected ? `${meta.name} (${conn.displayName || 'Connected'})` : `Connect ${meta.name}`;
      btn.addEventListener('click', () => openPlatformHub(key));
      wrap.appendChild(btn);
    });
  }

  function renderHeroPlatformChips() {
    const wrap = document.getElementById('hero-platform-chips');
    if (!wrap) return;
    const connected = ['youtube', 'spotify', 'soundcloud'].filter((k) => platformLinks[k]?.isConnected);
    let html = `<span class="hero-chip">${connected.length ? `${connected.length} STREAM PLATFORM${connected.length === 1 ? '' : 'S'} LINKED` : 'CLOUD D1 SYNCED'}</span>`;
    html += `<span class="hero-chip cyan">LYRICS &middot; 10-BAND DSP</span>`;
    connected.forEach((k) => {
      const m = PLATFORM_META[k];
      html += `<span class="hero-chip ${m.cls}">${m.liveLabel}</span>`;
    });
    wrap.innerHTML = html;
  }

  function renderHomePlatformSections() {
    const section = document.getElementById('home-connect-section');
    const heading = document.getElementById('home-connect-heading');
    const grid = document.getElementById('home-connect-grid');
    const hubsWrap = document.getElementById('home-linked-hubs');
    if (!section || !grid || !hubsWrap) return;

    const unlinked = ['youtube', 'spotify', 'soundcloud'].filter((k) => !platformLinks[k]?.isConnected);
    if (!unlinked.length) {
      section.style.display = 'none';
    } else {
      section.style.display = 'block';
      heading.textContent = unlinked.length < 3 ? 'Link Another Platform' : 'Connect Streaming Platforms';
      grid.innerHTML = '';
      unlinked.forEach((k) => {
        const m = PLATFORM_META[k];
        const card = document.createElement('div');
        card.className = `platform-card liquid-card ${m.cls}`;
        card.innerHTML = `<div class="platform-badge-circle ${m.cls}">${m.badge}</div><div class="platform-card-info"><strong>${m.name}</strong><span>${m.desc}</span></div><button type="button" class="prism-btn-sm">Connect</button>`;
        card.querySelector('button').addEventListener('click', (e) => { e.stopPropagation(); openPlatformConnectModal(k); });
        card.addEventListener('click', () => openPlatformConnectModal(k));
        grid.appendChild(card);
      });
    }

    hubsWrap.innerHTML = '';
    ['youtube', 'spotify', 'soundcloud'].forEach((k) => {
      const data = platformLinks[k];
      if (!data?.isConnected) return;
      const m = PLATFORM_META[k];
      const hubTracks = (data.recommendedTracks?.length ? data.recommendedTracks : data.likedTracks) || [];
      const block = document.createElement('div');
      block.className = 'platform-home-block';
      const cid = `home-hub-carousel-${k}`;
      block.innerHTML = `<div class="sec-head"><div><h2>${m.name} &mdash; Stream Hub</h2><span class="sec-sub"></span></div><button type="button" class="link-action">Open Hub &rarr;</button></div><div id="${cid}" class="cards-carousel"></div>`;
      block.querySelector('.sec-sub').textContent = `${data.displayName || 'Connected'} • ${(data.playlists || []).length} Playlists • ${(data.likedTracks || []).length} Tracks`;
      block.querySelector('.link-action').addEventListener('click', () => openPlatformHub(k));
      hubsWrap.appendChild(block);
      renderCarousel(cid, hubTracks.slice(0, 12));
    });
  }

  function renderSettingsStreamingList() {
    const wrap = document.getElementById('settings-streaming-list');
    if (!wrap) return;
    wrap.innerHTML = '';
    ['youtube', 'spotify', 'soundcloud'].forEach((k) => {
      const m = PLATFORM_META[k];
      const conn = platformLinks[k] || { isConnected: false };
      const row = document.createElement('div');
      row.className = `platform-card liquid-card ${m.cls}${conn.isConnected ? ' settings-row-card' : ''}`;
      row.innerHTML = `<div class="platform-badge-circle ${m.cls}">${m.badge}</div><div class="platform-card-info"><strong>${m.name}</strong><span></span></div><div class="platform-hub-actions"></div>`;
      row.querySelector('.platform-card-info span').textContent = conn.isConnected
        ? `${conn.displayName || 'Connected'} · ${(conn.playlists || []).length} sets · ${conn.planBadge || 'Synced'}`
        : 'Not connected yet';
      const acts = row.querySelector('.platform-hub-actions');
      if (conn.isConnected) {
        const openB = document.createElement('button'); openB.type = 'button'; openB.className = 'ghost-btn-sm'; openB.textContent = 'Hub';
        openB.addEventListener('click', () => openPlatformHub(k));
        const syncB = document.createElement('button'); syncB.type = 'button'; syncB.className = 'prism-btn-sm'; syncB.textContent = 'Sync';
        syncB.addEventListener('click', () => syncPlatformHub(k));
        const dcB = document.createElement('button'); dcB.type = 'button'; dcB.className = 'ghost-btn-sm'; dcB.textContent = 'Unlink';
        dcB.addEventListener('click', () => disconnectPlatformHub(k));
        acts.append(openB, syncB, dcB);
      } else {
        const connB = document.createElement('button'); connB.type = 'button'; connB.className = 'prism-btn-sm'; connB.textContent = 'Connect';
        connB.addEventListener('click', () => openPlatformConnectModal(k));
        acts.appendChild(connB);
      }
      wrap.appendChild(row);
    });
  }

  function openPlatformHub(key) {
    activePlatformKey = key;
    openHubPlaylistId = null;
    platformSearchResults = null;
    switchTab('platform');
    renderPlatformHub();
  }

  function renderPlatformHub() {
    const hero = document.getElementById('platform-hub-hero');
    const body = document.getElementById('platform-hub-body');
    if (!hero || !body) return;
    const m = PLATFORM_META[activePlatformKey];
    const data = platformLinks[activePlatformKey] || { isConnected: false };

    hero.className = `platform-hub-hero liquid-card ${m.cls}`;
    if (!data.isConnected) {
      hero.innerHTML = `<div class="platform-hub-top"><button id="hub-back-home" type="button" class="pb-icon-btn">&larr;</button><div class="platform-badge-circle ${m.cls}">${m.badge}</div><div class="platform-card-info"><strong>${m.name} Stream Hub</strong><span>Link your ${m.name} account or public playlists inside MUXIS.</span></div></div>`;
      hero.querySelector('#hub-back-home').addEventListener('click', () => switchTab('home'));
      body.innerHTML = `<div class="settings-card liquid-card" style="text-align:center;padding:28px 18px;"><div class="platform-badge-circle ${m.cls}" style="width:58px;height:58px;font-size:20px;margin:0 auto 14px;">${m.badge}</div><h2 style="font-size:20px;font-weight:900;margin-bottom:8px;">Connect ${m.name}</h2><p class="sec-sub" style="margin-bottom:18px;line-height:1.5;">${m.desc}. Playlists, liked tracks &amp; hub picks sync automatically to Cloudflare D1.</p><button id="hub-connect-cta" type="button" class="prism-cta-btn" style="max-width:280px;">Connect ${m.name}</button></div>`;
      body.querySelector('#hub-connect-cta').addEventListener('click', () => openPlatformConnectModal(activePlatformKey));
      return;
    }

    const avatarHtml = data.avatarUrl ? `<img src="${data.avatarUrl}" alt="">` : m.badge;
    hero.innerHTML = `<div class="platform-hub-top"><button id="hub-back-home" type="button" class="pb-icon-btn">&larr;</button><div class="platform-hub-avatar">${avatarHtml}</div><div class="platform-card-info"><div style="display:flex;align-items:center;gap:6px;flex-wrap:wrap;"><strong></strong><span class="fmt-pill">${data.planBadge || 'CONNECTED'}</span></div><span>${m.name} &bull; ${(data.playlists || []).length} Playlists &bull; ${(data.likedTracks || []).length} Liked</span></div></div><div class="platform-hub-actions"><button id="hub-sync-btn" type="button" class="prism-btn-sm">&#8635; Sync Now</button><button id="hub-relink-btn" type="button" class="ghost-btn-sm">Update Link</button><button id="hub-dc-btn" type="button" class="ghost-btn-sm" style="color:#fca5a5;">Disconnect</button></div>`;
    hero.querySelector('.platform-card-info strong').textContent = data.displayName || m.name;
    hero.querySelector('#hub-back-home').addEventListener('click', () => switchTab('home'));
    hero.querySelector('#hub-sync-btn').addEventListener('click', () => syncPlatformHub(activePlatformKey));
    hero.querySelector('#hub-relink-btn').addEventListener('click', () => openPlatformConnectModal(activePlatformKey));
    hero.querySelector('#hub-dc-btn').addEventListener('click', () => disconnectPlatformHub(activePlatformKey));

    body.innerHTML = `<div class="search-box"><input id="hub-search-input" type="search" class="search-input" placeholder="Search ${m.name}..."><button id="hub-search-btn" type="button" class="prism-btn-sm">Find</button></div><div class="segmented-tabs platform-subtabs"><button type="button" class="seg-btn${activePlatformSubTab === 'picks' ? ' active' : ''}" data-hub-tab="picks">Featured &amp; Picks</button><button type="button" class="seg-btn${activePlatformSubTab === 'playlists' ? ' active' : ''}" data-hub-tab="playlists">Playlists</button><button type="button" class="seg-btn${activePlatformSubTab === 'liked' ? ' active' : ''}" data-hub-tab="liked">Liked Songs</button></div><div id="hub-tab-content" class="track-stack"></div>`;

    const inp = body.querySelector('#hub-search-input');
    body.querySelector('#hub-search-btn').addEventListener('click', () => runPlatformSearch(activePlatformKey, inp.value));
    inp.addEventListener('keydown', (e) => { if (e.key === 'Enter') runPlatformSearch(activePlatformKey, inp.value); });
    body.querySelectorAll('[data-hub-tab]').forEach((b) => {
      b.addEventListener('click', () => {
        activePlatformSubTab = b.dataset.hubTab;
        openHubPlaylistId = null;
        platformSearchResults = null;
        renderPlatformHub();
      });
    });

    const content = body.querySelector('#hub-tab-content');
    if (Array.isArray(platformSearchResults)) {
      const clr = document.createElement('button'); clr.type = 'button'; clr.className = 'ghost-btn-sm'; clr.style.alignSelf = 'flex-start'; clr.textContent = 'Clear Search';
      clr.addEventListener('click', () => { platformSearchResults = null; renderPlatformHub(); });
      content.appendChild(clr);
      const resBox = document.createElement('div'); resBox.className = 'track-stack';
      renderTrackRows(resBox, platformSearchResults);
      content.appendChild(resBox);
      return;
    }

    if (activePlatformSubTab === 'playlists') {
      const pls = data.playlists || [];
      if (openHubPlaylistId) {
        const pl = pls.find((p) => p.id === openHubPlaylistId);
        if (pl) {
          const bar = document.createElement('div'); bar.style.cssText = 'display:flex;justify-content:space-between;align-items:center;gap:8px;margin-bottom:8px;';
          bar.innerHTML = `<button type="button" class="ghost-btn-sm">&larr; Back</button><strong style="flex:1;font-size:14px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;"></strong><button type="button" class="prism-btn-sm">&#9654; Play All</button>`;
          bar.querySelector('strong').textContent = pl.title;
          bar.querySelectorAll('button')[0].addEventListener('click', () => { openHubPlaylistId = null; isHydratingHubPlaylist = false; renderPlatformHub(); });
          bar.querySelectorAll('button')[1].addEventListener('click', () => { if (pl.tracks?.length) playTrack(pl.tracks[0], pl.tracks); });
          content.appendChild(bar);
          const listWrap = document.createElement('div'); listWrap.className = 'track-stack';
          if (isHydratingHubPlaylist && !(pl.tracks && pl.tracks.length)) {
            listWrap.innerHTML = `<div style="padding:24px;text-align:center;color:var(--text-muted);font-size:13px;">Loading tracks from ${m.name}...</div>`;
          } else {
            renderTrackRows(listWrap, pl.tracks || []);
          }
          content.appendChild(listWrap);
          return;
        }
      }
      if (!pls.length) {
        content.innerHTML = '<div style="padding:18px;text-align:center;color:var(--text-muted);font-size:13px;border:1px dashed var(--border);border-radius:14px;">No playlists synced for this account/link yet.</div>';
        return;
      }
      pls.forEach((pl) => {
        const row = document.createElement('div'); row.className = 'track-row liquid-card';
        const art = pl.artworkUrl ? `<img src="${pl.artworkUrl}" alt="">` : `<span>${m.badge}</span>`;
        row.innerHTML = `<div class="track-art">${art}</div><div class="track-info"><strong></strong><span></span></div><span class="fmt-pill">${pl.trackCount || (pl.tracks || []).length} TRACKS</span>`;
        row.querySelector('strong').textContent = pl.title;
        row.querySelector('span').textContent = pl.description || m.name;
        row.addEventListener('click', () => openAndHydrateHubPlaylist(pl));
        content.appendChild(row);
      });
      return;
    }

    const trackList = activePlatformSubTab === 'liked' ? (data.likedTracks || []) : ((data.recommendedTracks?.length ? data.recommendedTracks : data.likedTracks) || []);
    if (trackList.length) {
      const topActionRow = document.createElement('div');
      topActionRow.style.cssText = 'display:flex;justify-content:space-between;align-items:center;margin-bottom:4px;';
      topActionRow.innerHTML = `<span class="sec-sub">${trackList.length} playable tracks</span><button type="button" class="prism-btn-sm">&#9654; Play All</button>`;
      topActionRow.querySelector('button').addEventListener('click', () => playTrack(trackList[0], trackList));
      content.appendChild(topActionRow);
    }
    const stackEl = document.createElement('div'); stackEl.className = 'track-stack';
    renderTrackRows(stackEl, trackList);
    content.appendChild(stackEl);
  }

  async function openAndHydrateHubPlaylist(pl) {
    openHubPlaylistId = pl.id;
    if (pl.tracks && pl.tracks.length) {
      isHydratingHubPlaylist = false;
      renderPlatformHub();
      return;
    }
    isHydratingHubPlaylist = true;
    renderPlatformHub();
    try {
      const res = await fetch(
        `${WORKER_URL}/api/stream/links/playlist-tracks?platform=${encodeURIComponent(activePlatformKey)}&playlistId=${encodeURIComponent(pl.id)}`,
        { headers: { Authorization: `Bearer ${authToken}`, 'X-Muxis-Client': 'pwa' } }
      );
      if (res.ok) {
        const d = await res.json();
        pl.tracks = d.tracks || [];
        if (pl.tracks.length) {
          pl.trackCount = Math.max(pl.trackCount || 0, pl.tracks.length);
          saveJson('muxis_pwa_platform_links', platformLinks);
        } else {
          showToast('This playlist returned 0 public tracks.');
        }
      }
    } catch (_) {
      showToast('Failed to fetch playlist tracks.');
    } finally {
      isHydratingHubPlaylist = false;
      renderPlatformHub();
    }
  }

  async function runPlatformSearch(key, rawQ) {
    const q = (rawQ || '').trim();
    if (!q) { platformSearchResults = null; renderPlatformHub(); return; }
    showToast(`Searching ${PLATFORM_META[key].name}...`);
    try {
      const ep = key === 'soundcloud'
        ? `${WORKER_URL}/api/stream/soundcloud/search?q=${encodeURIComponent(q)}`
        : key === 'spotify'
          ? `${WORKER_URL}/api/stream/spotify/bridge?q=${encodeURIComponent(q)}`
          : `${WORKER_URL}/api/stream/yt/search?q=${encodeURIComponent(q)}`;
      const res = await fetch(ep);
      if (res.ok) {
        const d = await res.json();
        platformSearchResults = d.tracks || [];
        renderPlatformHub();
      }
    } catch (_) { showToast('Platform search failed.'); }
  }

  function openPlatformConnectModal(key) {
    activeConnectPlatform = key;
    activeConnectMode = 'profile_url';
    const sheet = document.getElementById('platform-connect-backdrop');
    const m = PLATFORM_META[key];
    const icon = document.getElementById('pc-badge-icon');
    icon.className = `platform-badge-circle ${m.cls}`;
    icon.textContent = m.badge;
    document.getElementById('pc-modal-title').textContent = `Sign In / Link ${m.name}`;
    document.getElementById('pc-modal-subtitle').textContent = m.desc;
    document.getElementById('pc-error-box').style.display = 'none';
    renderPlatformConnectModeForm();
    sheet.classList.add('open');
  }

  function renderPlatformConnectModeForm() {
    const key = activeConnectPlatform;
    const tabsWrap = document.getElementById('pc-mode-tabs');
    const helper = document.getElementById('pc-helper-text');
    const fields = document.getElementById('pc-form-fields');
    const submitBtn = document.getElementById('pc-submit-btn');
    const oauthBtn = document.getElementById('pc-oauth-btn');
    const errEl = document.getElementById('pc-error-box');
    errEl.style.display = 'none';

    const modes = key === 'soundcloud'
      ? [{ id: 'profile_url', label: 'Profile / Handle' }, { id: 'oauth_token', label: 'Sign In / Token' }]
      : key === 'youtube'
        ? [{ id: 'oauth_google', label: 'Google Sign-In' }, { id: 'profile_url', label: 'Playlist / Channel' }, { id: 'cookie', label: 'Cookie' }]
        : [{ id: 'profile_url', label: 'Spotify Link' }, { id: 'credentials', label: 'Spotify OAuth / Key' }];

    if (!modes.some((x) => x.id === activeConnectMode)) activeConnectMode = modes[0].id;
    tabsWrap.style.gridTemplateColumns = `repeat(${modes.length}, 1fr)`;
    tabsWrap.innerHTML = '';
    modes.forEach((mode) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = `seg-btn${activeConnectMode === mode.id ? ' active' : ''}`;
      b.textContent = mode.label;
      b.addEventListener('click', () => { activeConnectMode = mode.id; renderPlatformConnectModeForm(); });
      tabsWrap.appendChild(b);
    });

    oauthBtn.style.display = 'none';
    submitBtn.style.display = 'block';

    if (key === 'youtube' && activeConnectMode === 'oauth_google') {
      helper.textContent = 'Sign in with your Google / YouTube account to pull your playlists, Liked Music videos, and recommendations directly.';
      fields.innerHTML = `<p class="sec-sub" style="font-size:12px;margin-bottom:6px;">Tip: If you don't want Google sign-in prompts, switch to <strong>Playlist / Channel</strong> to sync any public YouTube Music link instantly.</p>`;
      submitBtn.style.display = 'none';
      oauthBtn.textContent = 'Continue with Google (YouTube Music)';
      oauthBtn.style.display = 'inline-flex';
    } else if (key === 'youtube' && activeConnectMode === 'profile_url') {
      helper.textContent = 'Paste any YouTube Music playlist link (list=...), channel URL, or @artist handle to sync playlists & picks.';
      fields.innerHTML = `<input id="pc-url-input" class="auth-input" type="text" placeholder="https://music.youtube.com/playlist?list=... or @artist">`;
    } else if (key === 'youtube') {
      helper.textContent = 'Advanced: paste your music.youtube.com browser Cookie header (must include SAPISID or __Secure-3PAPISID).';
      fields.innerHTML = `<textarea id="pc-cookie-input" class="auth-input" rows="3" placeholder="Cookie: SAPISID=...; __Secure-3PAPISID=...;" style="resize:vertical;"></textarea>`;
    } else if (key === 'soundcloud' && activeConnectMode === 'profile_url') {
      helper.textContent = 'Enter your SoundCloud @username, profile URL, or playlist/set URL to sync your tracks, likes & charts.';
      fields.innerHTML = `<input id="pc-url-input" class="auth-input" type="text" placeholder="https://soundcloud.com/monstercat or username"><div style="text-align:right;margin-bottom:6px;"><a href="https://soundcloud.com/signin" target="_blank" rel="noopener" class="link-action" style="font-size:11.5px;">Open SoundCloud Sign-In &#8599;</a></div>`;
    } else if (key === 'soundcloud') {
      helper.textContent = 'Connect private SoundCloud likes/sets via OAuth Sign-In (requires Client ID) or paste your oauth_token.';
      fields.innerHTML = `<input id="pc-cid-input" class="auth-input" type="text" placeholder="SoundCloud Client ID (optional PKCE)" value="${oauthConfig.soundcloudClientId || ''}"><input id="pc-token-input" class="auth-input" type="password" placeholder="Or paste SoundCloud oauth_token">`;
      if (oauthConfig.soundcloudClientId || true) {
        oauthBtn.textContent = 'Authorize with SoundCloud OAuth';
        oauthBtn.style.display = 'inline-flex';
      }
    } else if (key === 'spotify' && activeConnectMode === 'profile_url') {
      helper.textContent = 'Zero-key import: paste your Spotify Profile link (open.spotify.com/user/...), Playlist, Album, or Track link.';
      fields.innerHTML = `<input id="pc-url-input" class="auth-input" type="url" placeholder="https://open.spotify.com/playlist/... or /user/..."><div style="text-align:right;margin-bottom:6px;"><a href="https://open.spotify.com/" target="_blank" rel="noopener" class="link-action" style="font-size:11.5px;">Open Spotify Web Player &#8599;</a></div>`;
      if (oauthConfig.spotifyClientId) {
        oauthBtn.textContent = 'Sign In with Spotify OAuth';
        oauthBtn.style.display = 'inline-flex';
      }
    } else {
      helper.textContent = 'Authorize 1-Click Spotify OAuth PKCE (redirect URI: muxis.pages.dev/app/), or connect using Access Token / Client ID + Secret.';
      fields.innerHTML = `<input id="pc-cid-input" class="auth-input" type="text" placeholder="Spotify Client ID" value="${oauthConfig.spotifyClientId || ''}"><input id="pc-csec-input" class="auth-input" type="password" placeholder="Spotify Client Secret (only if not using OAuth)"><input id="pc-token-input" class="auth-input" type="password" placeholder="Or paste Spotify Access Token (optional)">`;
      oauthBtn.textContent = 'Sign In with Spotify OAuth';
      oauthBtn.style.display = 'inline-flex';
    }
  }

  async function submitPlatformConnect() {
    const key = activeConnectPlatform;
    if (!key) return;
    const errEl = document.getElementById('pc-error-box');
    const btn = document.getElementById('pc-submit-btn');
    errEl.style.display = 'none';

    const payload = { platform: key, mode: activeConnectMode };
    const urlInp = document.getElementById('pc-url-input');
    const tokInp = document.getElementById('pc-token-input');
    const ckInp = document.getElementById('pc-cookie-input');
    const cidInp = document.getElementById('pc-cid-input');
    const csecInp = document.getElementById('pc-csec-input');
    if (urlInp) payload.profileUrl = urlInp.value.trim();
    if (tokInp) payload.accessToken = tokInp.value.trim();
    if (ckInp) payload.cookie = ckInp.value.trim();
    if (cidInp) payload.clientId = cidInp.value.trim();
    if (csecInp) payload.clientSecret = csecInp.value.trim();

    btn.disabled = true; btn.textContent = 'Connecting & Syncing...';
    try {
      const res = await fetch(`${WORKER_URL}/api/stream/links/connect`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${authToken}`, 'X-Muxis-Client': 'pwa' },
        body: JSON.stringify(payload)
      });
      const data = await res.json();
      if (!res.ok || !data.connection) {
        errEl.textContent = data.error || `Could not connect ${PLATFORM_META[key].name}.`;
        errEl.style.display = 'block';
        return;
      }
      platformLinks[key] = data.connection;
      saveJson('muxis_pwa_platform_links', platformLinks);
      document.getElementById('platform-connect-backdrop').classList.remove('open');
      renderStreamingPlatformUI();
      openPlatformHub(key);
      showToast(`Connected ${PLATFORM_META[key].name}!`);
    } catch (_) {
      errEl.textContent = 'Network timeout contacting MUXIS Cloud Worker.';
      errEl.style.display = 'block';
    } finally {
      btn.disabled = false; btn.textContent = 'Connect & Sync Hub';
    }
  }

  async function handlePlatformOAuthAction() {
    if (activeConnectPlatform === 'youtube') { await startGoogleYouTubeOAuth(); return; }
    if (activeConnectPlatform === 'soundcloud') { await startSoundCloudPkceFlow(); return; }
    await startSpotifyPkceFlow();
  }

  async function startGoogleYouTubeOAuth() {
    const errEl = document.getElementById('pc-error-box');
    const oauthBtn = document.getElementById('pc-oauth-btn');
    errEl.style.display = 'none';
    const rand = new Uint8Array(24); crypto.getRandomValues(rand);
    const pollSecret = Array.from(rand, (b) => b.toString(16).padStart(2, '0')).join('');
    oauthBtn.disabled = true; oauthBtn.textContent = 'Waiting for Google YouTube Auth...';
    try {
      const res = await fetch(`${WORKER_URL}/api/auth/google/start?scope=youtube&poll_secret=${encodeURIComponent(pollSecret)}&app_redirect=${encodeURIComponent(window.location.href.split('#')[0])}`);
      const start = await res.json();
      if (!res.ok || !start.auth_url) {
        errEl.textContent = start.error || 'Google OAuth unavailable right now.';
        errEl.style.display = 'block';
        oauthBtn.disabled = false; oauthBtn.textContent = 'Continue with Google (YouTube Music)';
        return;
      }
      const popup = window.open(start.auth_url, '_blank', 'width=480,height=660');
      const deadline = Date.now() + 3 * 60 * 1000;
      const timer = setInterval(async () => {
        if (Date.now() > deadline) {
          clearInterval(timer);
          oauthBtn.disabled = false; oauthBtn.textContent = 'Continue with Google (YouTube Music)';
          return;
        }
        try {
          const poll = await fetch(`${WORKER_URL}/api/auth/google/poll`, {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ state: start.state, poll_secret: pollSecret })
          });
          if (!poll.ok) return;
          const pData = await poll.json();
          if (pData.status === 'complete') {
            clearInterval(timer);
            try { if (popup && !popup.closed) popup.close(); } catch (_) {}
            oauthBtn.disabled = false; oauthBtn.textContent = 'Continue with Google (YouTube Music)';
            if (!pData.youtube_access_token) {
              errEl.textContent = 'Google signed in, but YouTube read permission was not granted. Approve YouTube access or paste a Playlist/Channel URL.';
              errEl.style.display = 'block';
              return;
            }
            const cRes = await fetch(`${WORKER_URL}/api/stream/links/connect`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${authToken}`, 'X-Muxis-Client': 'pwa' },
              body: JSON.stringify({ platform: 'youtube', mode: 'oauth_token', accessToken: pData.youtube_access_token })
            });
            const cData = await cRes.json();
            if (!cRes.ok || !cData.connection) {
              errEl.textContent = cData.error || 'Could not sync YouTube library after sign-in.';
              errEl.style.display = 'block';
              return;
            }
            platformLinks.youtube = cData.connection;
            saveJson('muxis_pwa_platform_links', platformLinks);
            document.getElementById('platform-connect-backdrop').classList.remove('open');
            renderStreamingPlatformUI();
            openPlatformHub('youtube');
            showToast('YouTube Music signed in via Google!');
          } else if (pData.status === 'error' || pData.status === 'expired') {
            clearInterval(timer);
            oauthBtn.disabled = false; oauthBtn.textContent = 'Continue with Google (YouTube Music)';
            errEl.textContent = pData.error || 'Google sign-in expired or cancelled.';
            errEl.style.display = 'block';
          }
        } catch (_) {}
      }, 1300);
    } catch (_) {
      oauthBtn.disabled = false; oauthBtn.textContent = 'Continue with Google (YouTube Music)';
      errEl.textContent = 'Could not reach MUXIS Cloud.';
      errEl.style.display = 'block';
    }
  }

  async function launchPkceRedirect(authEndpoint, clientId, statePrefix, scopeStr, missingMsg) {
    const errEl = document.getElementById('pc-error-box');
    const cid = (clientId || '').trim();
    if (!cid) { errEl.textContent = missingMsg; errEl.style.display = 'block'; return; }
    const bytes = new Uint8Array(48); crypto.getRandomValues(bytes);
    const verifier = btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier));
    const challenge = btoa(String.fromCharCode(...new Uint8Array(digest))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    const redirectUri = window.location.href.split('?')[0].split('#')[0];
    const state = `${statePrefix}${Math.random().toString(36).slice(2, 12)}`;
    sessionStorage.setItem('muxis_pkce_verifier', verifier);
    sessionStorage.setItem('muxis_pkce_cid', cid);
    sessionStorage.setItem('muxis_pkce_redir', redirectUri);
    const u = new URL(authEndpoint);
    u.searchParams.set('client_id', cid);
    u.searchParams.set('response_type', 'code');
    u.searchParams.set('redirect_uri', redirectUri);
    u.searchParams.set('code_challenge_method', 'S256');
    u.searchParams.set('code_challenge', challenge);
    u.searchParams.set('state', state);
    if (scopeStr) u.searchParams.set('scope', scopeStr);
    window.location.href = u.toString();
  }

  async function startSpotifyPkceFlow() {
    const cid = document.getElementById('pc-cid-input')?.value || oauthConfig.spotifyClientId;
    await launchPkceRedirect(
      'https://accounts.spotify.com/authorize',
      cid,
      'sp_pkce_',
      'user-read-private user-library-read playlist-read-private playlist-read-collaborative user-top-read',
      'Enter a Spotify Client ID (or ask Owner to add it in Admin Panel), or paste a Spotify link in the previous tab.'
    );
  }

  async function startSoundCloudPkceFlow() {
    const cid = document.getElementById('pc-cid-input')?.value || oauthConfig.soundcloudClientId;
    await launchPkceRedirect(
      'https://secure.soundcloud.com/authorize',
      cid,
      'sc_pkce_',
      'non-expiring',
      'Enter a SoundCloud App Client ID (or switch to Profile / Handle tab for instant zero-key sync).'
    );
  }

  async function syncPlatformHub(key) {
    if (!authToken) return;
    showToast(`Syncing ${PLATFORM_META[key].name}...`);
    try {
      const res = await fetch(`${WORKER_URL}/api/stream/links/sync`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${authToken}`, 'X-Muxis-Client': 'pwa' },
        body: JSON.stringify({ platform: key })
      });
      const d = await res.json();
      if (res.ok && d.connection) {
        platformLinks[key] = d.connection;
        saveJson('muxis_pwa_platform_links', platformLinks);
        renderStreamingPlatformUI();
        showToast(`${PLATFORM_META[key].name} hub synced!`);
      } else {
        showToast(d.error || 'Sync failed.');
      }
    } catch (_) { showToast('Network error during sync.'); }
  }

  async function disconnectPlatformHub(key) {
    if (!authToken || !window.confirm(`Disconnect ${PLATFORM_META[key].name} from MUXIS Cloud?`)) return;
    try {
      const res = await fetch(`${WORKER_URL}/api/stream/links/disconnect`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${authToken}`, 'X-Muxis-Client': 'pwa' },
        body: JSON.stringify({ platform: key })
      });
      if (res.ok) {
        platformLinks[key] = { isConnected: false };
        saveJson('muxis_pwa_platform_links', platformLinks);
        renderStreamingPlatformUI();
        showToast(`${PLATFORM_META[key].name} disconnected`);
      }
    } catch (_) {}
  }

  function loadJson(k, fb) { try { const v = localStorage.getItem(k); return v ? JSON.parse(v) : fb; } catch (_) { return fb; } }
  function saveJson(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (_) {} }
  function showToast(msg) {
    const el = document.getElementById('toast'); el.textContent = msg; el.classList.add('show');
    clearTimeout(el._t); el._t = setTimeout(() => el.classList.remove('show'), 2500);
  }
})();
