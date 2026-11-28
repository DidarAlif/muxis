// MUXIS Installable PWA Engine — Offline IndexedDB Audio, Web Audio 10-Band EQ,
// Global FM Radio, Cloudflare D1 Cloud Sync & 1-Click Firebase Google Auth

(function () {
  'use strict';

  const WORKER_URL = 'https://muxis-api-worker.a-leaf-org.workers.dev';
  const RADIO_MIRRORS = [
    'https://de1.api.radio-browser.info',
    'https://fr1.api.radio-browser.info',
    'https://at1.api.radio-browser.info'
  ];

  const FEATURED_TRACKS = [
    {
      id: 'cc-1',
      title: 'Neon Odyssey',
      artist: 'Aura Synthesis',
      album: 'Prismatic Dreams (CC-BY 4.0)',
      badge: 'OPEN HI-FI',
      url: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/no_curator/Tours/Enthusiast/Tours_-_01_-_Enthusiast.mp3'
    },
    {
      id: 'cc-2',
      title: 'Obsidian Reflections',
      artist: 'Kroma Soundworks',
      album: 'Atmospheres Vol. 1',
      badge: '320KBPS',
      url: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Broke_For_Free/Directionless_EP/Broke_For_Free_-_01_-_Night_Owl.mp3'
    },
    {
      id: 'cc-3',
      title: 'Velvet Aurora',
      artist: 'Lunar Pulse',
      album: 'Celestial Echoes',
      badge: 'OPEN STREAM',
      url: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/WFMU/Lame_Drivers/Frozen_Air/Lame_Drivers_-_01_-_Frozen_Air.mp3'
    },
    {
      id: 'cc-4',
      title: 'Midnight Frequency',
      artist: 'Subtle Wave',
      album: 'Deep Space Oscillations',
      badge: 'OPEN STREAM',
      url: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/Music_for_Video/Doctor_Turtle/The_Double-Down_Two-Step/Doctor_Turtle_-_01_-_The_Double-Down_Two-Step.mp3'
    }
  ];

  const EQ_BANDS = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
  const EQ_LABELS = ['32Hz', '64Hz', '125', '250', '500', '1kHz', '2kHz', '4kHz', '8kHz', '16k'];
  const EQ_PRESETS = {
    'Prismatic Neon': [4.5, 4.0, 2.0, -0.5, 0.5, 1.5, 3.0, 4.5, 5.5, 6.0],
    'Sub Bass Thump': [7.5, 6.5, 4.5, 1.5, 0.0, 0.0, 1.0, 1.5, 2.0, 2.0],
    'Vocal Clarity': [-1.5, -1.0, 0.5, 2.5, 4.5, 5.5, 4.0, 2.0, 1.0, 0.5],
    'Electronic & EDM': [6.0, 5.0, 2.5, -1.0, 0.5, 2.0, 3.5, 4.5, 6.0, 6.5],
    'Flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  };

  const THEMES = {
    obsidian_aurora: { accent: '#00FF88', accentRgb: '0, 255, 136', secondary: '#00E5FF', secondaryRgb: '0, 229, 255', tertiary: '#9D6BFF', tertiaryRgb: '157, 107, 255', bgDeep: '#060910', bgSecondary: '#0B111C' },
    midnight_sapphire: { accent: '#38BDF8', accentRgb: '56, 189, 248', secondary: '#22D3EE', secondaryRgb: '34, 211, 238', tertiary: '#818CF8', tertiaryRgb: '129, 140, 248', bgDeep: '#050B16', bgSecondary: '#091426' },
    botanical_jade: { accent: '#10B981', accentRgb: '16, 185, 129', secondary: '#2DD4BF', secondaryRgb: '45, 212, 191', tertiary: '#6EE7B7', tertiaryRgb: '110, 231, 183', bgDeep: '#040F0B', bgSecondary: '#081A14' },
    ultraviolet_synth: { accent: '#C084FC', accentRgb: '192, 132, 252', secondary: '#22D3EE', secondaryRgb: '34, 211, 238', tertiary: '#F472B6', tertiaryRgb: '244, 114, 182', bgDeep: '#080514', bgSecondary: '#100A24' },
    crimson_velvet: { accent: '#FF4D8D', accentRgb: '255, 77, 141', secondary: '#FB7185', secondaryRgb: '251, 113, 133', tertiary: '#C084FC', tertiaryRgb: '192, 132, 252', bgDeep: '#0F060A', bgSecondary: '#180A11' }
  };

  // Playback & App State (Separate elements so WebAudio CORS never mutes remote FM streams)
  const localAudio = new Audio();
  localAudio.preload = 'metadata';
  const streamAudio = new Audio();
  streamAudio.preload = 'metadata';
  let activeAudio = streamAudio;

  let audioCtx = null;
  let eqFilters = [];
  let analyser = null;
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
  let authToken = localStorage.getItem('muxis_cloud_token') || '';
  let authUser = loadJson('muxis_cloud_user', null);
  let isCreateMode = false;
  let deferredInstallPrompt = null;

  document.addEventListener('DOMContentLoaded', async () => {
    registerServiceWorker();
    initInstallUI();
    initTheme(activeThemeId);
    initNavigation();
    initEqStudio();
    initSpectrumLoop();
    initLiquidRipples();
    initAudioControls();
    initAuthUI();

    renderFeatured();
    renderHistory();
    renderFavorites();
    await loadLocalTracksFromDb();
    loadRadioStations('');

    if (authToken) {
      await verifySessionAndSync();
    }
    renderCloudView();
  });

  // -------------------------------------------------------------------------
  // Service Worker & Native/iOS Install Banner
  // -------------------------------------------------------------------------
  function registerServiceWorker() {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('./sw.js').catch(() => {});
    }
  }

  function initInstallUI() {
    const installBtn = document.getElementById('install-pwa-btn');
    const banner = document.getElementById('ios-install-banner');
    const instr = document.getElementById('install-instructions');
    const dismiss = document.getElementById('dismiss-install-btn');

    const isStandalone = window.navigator.standalone === true ||
      window.matchMedia('(display-mode: standalone)').matches;
    const isIOS = /iPhone|iPad|iPod/i.test(navigator.userAgent || '') ||
      (/Macintosh/i.test(navigator.userAgent || '') && navigator.maxTouchPoints > 1);

    if (!isStandalone && localStorage.getItem('muxis_hide_install_banner') !== '1') {
      if (isIOS) {
        banner.classList.add('visible');
      }
    }

    if (dismiss) {
      dismiss.addEventListener('click', () => {
        banner.classList.remove('visible');
        localStorage.setItem('muxis_hide_install_banner', '1');
      });
    }

    window.addEventListener('beforeinstallprompt', (e) => {
      e.preventDefault();
      deferredInstallPrompt = e;
      if (installBtn) {
        installBtn.style.display = 'inline-flex';
        installBtn.addEventListener('click', async () => {
          if (!deferredInstallPrompt) return;
          deferredInstallPrompt.prompt();
          await deferredInstallPrompt.userChoice;
          deferredInstallPrompt = null;
          installBtn.style.display = 'none';
          banner.classList.remove('visible');
        });
      }
      if (!isStandalone && !isIOS) {
        instr.textContent = 'Install MUXIS as a standalone offline-ready app directly onto your device in one click.';
        banner.classList.add('visible');
      }
    });
  }

  // -------------------------------------------------------------------------
  // Navigation, Themes & Liquid Ripples
  // -------------------------------------------------------------------------
  function initNavigation() {
    document.querySelectorAll('[data-nav]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const target = btn.dataset.nav;
        document.querySelectorAll('.pwa-view').forEach((v) => v.classList.toggle('active', v.id === `view-${target}`));
        document.querySelectorAll('.tab-btn[data-nav]').forEach((t) => t.classList.toggle('active', t.dataset.nav === target));
      });
    });

    document.querySelectorAll('[data-theme]').forEach((dot) => {
      dot.addEventListener('click', () => {
        initTheme(dot.dataset.theme);
        localStorage.setItem('muxis_pwa_theme', dot.dataset.theme);
        if (authToken) pushCloudSync({ settings: { dark_preset: dot.dataset.theme, eq_preset: activePresetName } });
      });
    });
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
    s.setProperty('--bg-secondary', t.bgSecondary);
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

  // -------------------------------------------------------------------------
  // IndexedDB Local Offline Audio Store (iPhone Files / Android / Desktop)
  // -------------------------------------------------------------------------
  function openDb() {
    return new Promise((resolve, reject) => {
      const req = indexedDB.open('muxis_pwa_db', 1);
      req.onupgradeneeded = () => {
        const db = req.result;
        if (!db.objectStoreNames.contains('tracks')) {
          db.createObjectStore('tracks', { keyPath: 'id' });
        }
      };
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  }

  async function saveLocalTrackToDb(item) {
    const db = await openDb();
    return new Promise((resolve, reject) => {
      const tx = db.transaction('tracks', 'readwrite');
      tx.objectStore('tracks').put(item);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  }

  async function loadLocalTracksFromDb() {
    try {
      const db = await openDb();
      const rows = await new Promise((resolve, reject) => {
        const tx = db.transaction('tracks', 'readonly');
        const req = tx.objectStore('tracks').getAll();
        req.onsuccess = () => resolve(req.result || []);
        req.onerror = () => reject(req.error);
      });
      localTracks = rows.sort((a, b) => (b.addedAt || 0) - (a.addedAt || 0));
      renderLocalTracks();
    } catch (_) {
      localTracks = [];
      renderLocalTracks();
    }
  }

  async function deleteLocalTrackFromDb(id) {
    const db = await openDb();
    await new Promise((resolve, reject) => {
      const tx = db.transaction('tracks', 'readwrite');
      tx.objectStore('tracks').delete(id);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
    localTracks = localTracks.filter((t) => t.id !== id);
    renderLocalTracks();
  }

  function parseFileTitle(filename) {
    const base = filename.replace(/\.[^.]+$/, '').replace(/_/g, ' ').trim();
    const parts = base.split(/\s+-\s+/);
    if (parts.length >= 2) {
      return { artist: parts[0].trim(), title: parts.slice(1).join(' - ').trim() };
    }
    return { artist: 'Local File', title: base || 'Untitled Track' };
  }

  function triggerImportPicker() {
    document.getElementById('local-file-input').click();
  }

  // -------------------------------------------------------------------------
  // Audio Engine + Real 10-Band Web Audio BiquadFilter EQ + MediaSession
  // -------------------------------------------------------------------------
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
        f.gain.value = eqGains[idx];
        return f;
      });

      const src = audioCtx.createMediaElementSource(localAudio);
      let node = src;
      eqFilters.forEach((f) => {
        node.connect(f);
        node = f;
      });
      node.connect(analyser);
      analyser.connect(audioCtx.destination);
    }
    if (audioCtx.state === 'suspended') {
      audioCtx.resume().catch(() => {});
    }
  }

  async function playTrack(track, trackQueue) {
    if (trackQueue && trackQueue.length) queue = trackQueue;
    currentTrack = track;

    localAudio.pause();
    streamAudio.pause();

    if (activeObjectUrl) {
      URL.revokeObjectURL(activeObjectUrl);
      activeObjectUrl = null;
    }

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
    document.getElementById('np-title').textContent = track.title;
    document.getElementById('np-artist').textContent = track.artist || 'MUXIS';
    document.getElementById('np-art').src = track.artwork || 'icons/icon-192.png';

    try {
      await activeAudio.play();
      updatePlayButton(true);
      updateMediaSession(track);
      recordHistory(track);
      highlightCurrentTrack();
    } catch (_) {
      showToast('Tap play again or check audio stream permissions');
    }
  }

  function updatePlayButton(isPlaying) {
    document.getElementById('play-pause-btn').innerHTML = isPlaying ? '&#10074;&#10074;' : '&#9654;';
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
    document.getElementById('play-pause-btn').addEventListener('click', () => {
      if (!currentTrack && queue.length) {
        playTrack(queue[0]);
        return;
      }
      if (activeAudio.paused) activeAudio.play().catch(() => {});
      else activeAudio.pause();
    });

    document.getElementById('next-btn').addEventListener('click', playNext);
    document.getElementById('prev-btn').addEventListener('click', playPrev);

    [localAudio, streamAudio].forEach((el) => {
      el.addEventListener('play', () => { if (el === activeAudio) updatePlayButton(true); });
      el.addEventListener('pause', () => { if (el === activeAudio) updatePlayButton(false); });
      el.addEventListener('ended', () => { if (el === activeAudio) playNext(); });
      el.addEventListener('timeupdate', () => {
        if (el !== activeAudio) return;
        const pct = el.duration && Number.isFinite(el.duration) ? (el.currentTime / el.duration) * 100 : 0;
        document.getElementById('seek-fill').style.width = `${pct.toFixed(1)}%`;
      });
    });

    document.getElementById('seek-bar').addEventListener('click', (e) => {
      if (!activeAudio.duration || !Number.isFinite(activeAudio.duration)) return;
      const rect = e.currentTarget.getBoundingClientRect();
      const ratio = Math.min(1, Math.max(0, (e.clientX - rect.left) / rect.width));
      activeAudio.currentTime = ratio * activeAudio.duration;
    });

    document.getElementById('import-files-btn').addEventListener('click', triggerImportPicker);
    document.getElementById('import-files-cta').addEventListener('click', triggerImportPicker);

    document.getElementById('local-file-input').addEventListener('change', async (e) => {
      const files = Array.from(e.target.files || []);
      if (!files.length) return;
      for (const file of files) {
        const meta = parseFileTitle(file.name);
        await saveLocalTrackToDb({
          id: `local-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
          title: meta.title,
          artist: meta.artist,
          album: 'Imported Files',
          badge: file.name.split('.').pop().toUpperCase(),
          blob: file,
          addedAt: Date.now()
        });
      }
      e.target.value = '';
      await loadLocalTracksFromDb();
      showToast(`Saved ${files.length} audio file(s) offline`);
      document.querySelector('[data-nav="library"]').click();
    });

    document.getElementById('radio-search-btn').addEventListener('click', () => {
      loadRadioStations(document.getElementById('radio-search-input').value.trim());
    });
    document.getElementById('radio-search-input').addEventListener('keydown', (e) => {
      if (e.key === 'Enter') loadRadioStations(e.target.value.trim());
    });
  }

  // -------------------------------------------------------------------------
  // 10-Band EQ UI + Live FFT / Reactive Canvas
  // -------------------------------------------------------------------------
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
      range.type = 'range';
      range.min = '-12';
      range.max = '12';
      range.step = '0.5';
      range.value = String(eqGains[i]);
      range.className = 'eq-range';
      range.addEventListener('input', () => {
        const g = parseFloat(range.value);
        eqGains[i] = g;
        val.textContent = `${g >= 0 ? '+' : ''}${g.toFixed(1)}`;
        if (eqFilters[i]) eqFilters[i].gain.value = g;
      });
      const hz = document.createElement('span');
      hz.className = 'eq-hz';
      hz.textContent = lbl;
      col.append(val, range, hz);
      container.appendChild(col);
    });

    document.querySelectorAll('#eq-presets-row .preset-chip').forEach((chip) => {
      chip.addEventListener('click', () => {
        const name = chip.dataset.preset;
        const vals = EQ_PRESETS[name];
        if (!vals) return;
        activePresetName = name;
        eqGains = [...vals];
        initEqStudio();
        eqFilters.forEach((f, idx) => { f.gain.value = eqGains[idx]; });
        document.querySelectorAll('#eq-presets-row .preset-chip').forEach((c) => c.classList.toggle('active', c === chip));
        if (authToken) pushCloudSync({ settings: { dark_preset: activeThemeId, eq_preset: name } });
      });
    });
  }

  function initSpectrumLoop() {
    const canvas = document.getElementById('pwa-spectrum-canvas');
    if (!canvas) return;
    const freqData = new Uint8Array(64);
    const levels = new Float32Array(36).fill(0.08);
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
        const useRealFft = playing && analyser && currentTrack && currentTrack.blob;
        if (useRealFft) analyser.getByteFrequencyData(freqData);

        const t = THEMES[activeThemeId] || THEMES.obsidian_aurora;
        const grad = ctx.createLinearGradient(0, 0, rect.width, 0);
        grad.addColorStop(0, t.accent);
        grad.addColorStop(0.5, t.secondary);
        grad.addColorStop(1, t.tertiary);
        ctx.fillStyle = grad;

        tick++;
        const phase = tick * 0.05;
        const count = levels.length;
        const gap = rect.width / count;
        const bw = Math.max(3, gap * 0.62);
        const base = rect.height * 0.78;
        const maxH = rect.height * 0.7;

        for (let i = 0; i < count; i++) {
          let target;
          if (useRealFft) {
            target = Math.max(0.08, freqData[Math.min(60, i)] / 255);
          } else if (playing) {
            const u = i / (count - 1);
            const eqIdx = Math.min(9, Math.floor(u * 10));
            const boost = 1 + eqGains[eqIdx] * 0.04;
            target = Math.min(1, Math.max(0.1, (0.45 + 0.45 * Math.sin(phase * 2.2 + i * 0.4)) * boost));
          } else {
            target = 0.08 + 0.05 * Math.sin(phase * 0.8 + i * 0.35);
          }
          levels[i] += (target - levels[i]) * 0.28;
          const h = levels[i] * maxH;
          const x = i * gap + (gap - bw) * 0.5;
          ctx.globalAlpha = 0.92;
          if (ctx.roundRect) { ctx.beginPath(); ctx.roundRect(x, base - h, bw, h, bw * 0.4); ctx.fill(); }
          else ctx.fillRect(x, base - h, bw, h);
          ctx.globalAlpha = 0.22;
          ctx.fillRect(x, base + 3, bw, h * 0.25);
        }
        ctx.globalAlpha = 1;
      }
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  }

  // -------------------------------------------------------------------------
  // Render Lists, Favorites, History & Radio Browser API
  // -------------------------------------------------------------------------
  function renderTrackRows(container, list, allowDeleteLocal = false) {
    container.innerHTML = '';
    if (!list.length) {
      const empty = document.createElement('div');
      empty.style.cssText = 'padding: 18px; text-align: center; color: var(--text-muted); font-size: 13px; border: 1px dashed var(--border); border-radius: 14px;';
      empty.textContent = 'No tracks yet.';
      container.appendChild(empty);
      return;
    }

    list.forEach((track) => {
      const row = document.createElement('div');
      row.className = 'track-row liquid-card' + (currentTrack && currentTrack.id === track.id ? ' playing' : '');
      row.dataset.trackId = track.id;

      const art = document.createElement('div');
      art.className = 'track-art';
      if (track.artwork) {
        const img = document.createElement('img');
        img.src = track.artwork;
        img.alt = '';
        img.onerror = () => {
          art.innerHTML = '<span style="color:var(--accent);font-weight:900;">&#9835;</span>';
        };
        art.appendChild(img);
      } else {
        art.innerHTML = '<span style="color:var(--accent);font-weight:900;">&#9835;</span>';
      }

      const info = document.createElement('div');
      info.className = 'track-info';
      const title = document.createElement('strong');
      title.textContent = track.title;
      const artist = document.createElement('span');
      artist.textContent = track.artist || 'Unknown Artist';
      info.append(title, artist);

      const meta = document.createElement('div');
      meta.className = 'track-meta';
      if (track.badge) {
        const b = document.createElement('span');
        b.className = 'badge-tag';
        b.textContent = track.badge;
        meta.appendChild(b);
      }

      const favBtn = document.createElement('button');
      favBtn.type = 'button';
      favBtn.className = 'icon-btn' + (isFavorite(track.id) ? ' fav-active' : '');
      favBtn.innerHTML = '&#10084;';
      favBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        toggleFavorite(track);
      });
      meta.appendChild(favBtn);

      if (allowDeleteLocal) {
        const del = document.createElement('button');
        del.type = 'button';
        del.className = 'icon-btn';
        del.textContent = '×';
        del.addEventListener('click', (e) => {
          e.stopPropagation();
          deleteLocalTrackFromDb(track.id);
        });
        meta.appendChild(del);
      }

      row.append(art, info, meta);
      row.addEventListener('click', () => playTrack(track, list));
      container.appendChild(row);
    });
  }

  function highlightCurrentTrack() {
    document.querySelectorAll('.track-row').forEach((r) => {
      r.classList.toggle('playing', currentTrack && r.dataset.trackId === currentTrack.id);
    });
  }

  function renderFeatured() {
    renderTrackRows(document.getElementById('featured-list'), FEATURED_TRACKS);
  }

  function renderLocalTracks() {
    document.getElementById('local-count').textContent = String(localTracks.length);
    renderTrackRows(document.getElementById('local-list'), localTracks, true);
  }

  function isFavorite(id) {
    return favorites.some((f) => f.id === id || f.track_uri === id);
  }

  function toggleFavorite(track) {
    const uri = track.url || track.id;
    const exists = favorites.findIndex((f) => f.id === track.id || f.track_uri === uri);
    if (exists >= 0) {
      const removed = favorites.splice(exists, 1)[0];
      if (authToken) pushCloudSync({ mutations: [{ entityType: 'favorite', action: 'delete', data: { track_uri: removed.track_uri || uri } }] });
    } else {
      favorites.unshift({ id: track.id, track_uri: uri, title: track.title, artist: track.artist || 'MUXIS', album: track.album || '', badge: 'FAV', url: track.url });
      if (authToken) pushCloudSync({ favorites: [{ track_uri: uri, title: track.title, artist: track.artist || 'MUXIS', album: track.album || '' }] });
    }
    saveJson('muxis_pwa_favorites', favorites);
    renderFavorites();
    renderFeatured();
    renderLocalTracks();
    renderRadio();
  }

  function renderFavorites() {
    document.getElementById('fav-count').textContent = String(favorites.length);
    renderTrackRows(document.getElementById('fav-list'), favorites);
  }

  function recordHistory(track) {
    const uri = track.url || track.id;
    history = [{ id: track.id, track_uri: uri, title: track.title, artist: track.artist || 'MUXIS', url: track.url, badge: 'PLAYED' }, ...history.filter((h) => h.id !== track.id)].slice(0, 20);
    saveJson('muxis_pwa_history', history);
    renderHistory();
    if (authToken) {
      pushCloudSync({ history: [{ track_uri: uri, title: track.title, artist: track.artist || 'MUXIS', album: track.album || '', played_at: new Date().toISOString() }] });
    }
  }

  function renderHistory() {
    renderTrackRows(document.getElementById('history-list'), history);
  }

  async function loadRadioStations(query) {
    const listEl = document.getElementById('radio-list');
    listEl.innerHTML = '<div style="padding:18px;color:var(--text-muted);font-size:13px;">Loading live FM stations...</div>';
    const path = query
      ? `/json/stations/search?name=${encodeURIComponent(query)}&limit=25&hidebroken=true&order=votes&reverse=true`
      : `/json/stations/topvote/24`;

    for (const mirror of RADIO_MIRRORS) {
      try {
        const res = await fetch(`${mirror}${path}`);
        if (!res.ok) continue;
        const rows = await res.json();
        radioStations = rows
          .filter((s) => s.url_resolved && s.url_resolved.startsWith('https://'))
          .map((s) => ({
            id: `radio-${s.stationuuid}`,
            title: (s.name || 'Live FM').trim(),
            artist: `${s.country || 'Global'} · ${s.bitrate ? s.bitrate + 'kbps' : 'Live'}`,
            album: s.tags || 'Radio',
            badge: 'LIVE FM',
            artwork: s.favicon && s.favicon.startsWith('https://') ? s.favicon : '',
            url: s.url_resolved
          }));
        renderRadio();
        return;
      } catch (_) {}
    }
    listEl.innerHTML = '<div style="padding:18px;color:var(--text-muted);font-size:13px;">Could not load radio mirrors right now.</div>';
  }

  function renderRadio() {
    renderTrackRows(document.getElementById('radio-list'), radioStations);
  }

  // -------------------------------------------------------------------------
  // MUXIS Cloud Auth + Cloudflare D1 Sync + Firebase Google OAuth
  // -------------------------------------------------------------------------
  function initAuthUI() {
    const modal = document.getElementById('auth-modal');
    const openBtn = document.getElementById('open-cloud-btn');
    const viewSignInBtn = document.getElementById('cloud-view-signin-btn');
    const closeBtn = document.getElementById('close-auth-btn');
    const toggleBtn = document.getElementById('auth-mode-toggle');
    const submitBtn = document.getElementById('auth-submit-btn');
    const googleBtn = document.getElementById('google-oauth-btn');
    const nameField = document.getElementById('auth-name');

    const openModal = () => {
      if (authToken) {
        document.querySelector('[data-nav="cloud"]').click();
        return;
      }
      modal.classList.add('open');
    };
    openBtn.addEventListener('click', openModal);
    if (viewSignInBtn) viewSignInBtn.addEventListener('click', () => modal.classList.add('open'));
    closeBtn.addEventListener('click', () => modal.classList.remove('open'));

    toggleBtn.addEventListener('click', () => {
      isCreateMode = !isCreateMode;
      nameField.style.display = isCreateMode ? 'block' : 'none';
      submitBtn.textContent = isCreateMode ? 'Create Account' : 'Sign In';
      toggleBtn.textContent = isCreateMode ? 'Have an Account?' : 'Create Account';
    });

    submitBtn.addEventListener('click', async () => {
      const email = document.getElementById('auth-email').value.trim();
      const password = document.getElementById('auth-password').value;
      const displayName = nameField.value.trim();
      const errBox = document.getElementById('auth-error-msg');
      errBox.style.display = 'none';

      const endpoint = isCreateMode ? '/api/auth/register' : '/api/auth/login';
      try {
        const res = await fetch(`${WORKER_URL}${endpoint}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email, password, display_name: displayName })
        });
        const data = await res.json();
        if (!res.ok || !data.access_token) {
          errBox.textContent = data.error || 'Authentication failed.';
          errBox.style.display = 'block';
          return;
        }
        await completeCloudSession(data.access_token, data.user);
        modal.classList.remove('open');
      } catch (_) {
        errBox.textContent = 'Network timeout contacting MUXIS Cloud.';
        errBox.style.display = 'block';
      }
    });

    googleBtn.addEventListener('click', startGoogleOAuth);
  }

  async function startGoogleOAuth() {
    const errBox = document.getElementById('auth-error-msg');
    errBox.style.display = 'none';
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
        errBox.textContent = startData.error || 'Google Sign-In unavailable right now.';
        errBox.style.display = 'block';
        return;
      }

      const popup = window.open(startData.auth_url, '_blank', 'width=480,height=640');
      const deadline = Date.now() + 3 * 60 * 1000;

      const timer = setInterval(async () => {
        if (Date.now() > deadline) {
          clearInterval(timer);
          return;
        }
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
            await completeCloudSession(pData.access_token, pData.user);
            document.getElementById('auth-modal').classList.remove('open');
          } else if (pData.status === 'error' || pData.status === 'expired') {
            clearInterval(timer);
            errBox.textContent = pData.error || 'Google Sign-In expired.';
            errBox.style.display = 'block';
          }
        } catch (_) {}
      }, 1400);
    } catch (_) {
      errBox.textContent = 'Could not reach MUXIS Cloud OAuth.';
      errBox.style.display = 'block';
    }
  }

  async function completeCloudSession(token, user) {
    authToken = token;
    authUser = user;
    localStorage.setItem('muxis_cloud_token', token);
    saveJson('muxis_cloud_user', user);
    await pullCloudSync();
    renderCloudView();
    showToast(`Signed in as ${user?.display_name || user?.email || 'MUXIS Cloud'}`);
  }

  async function verifySessionAndSync() {
    try {
      const res = await fetch(`${WORKER_URL}/api/auth/me`, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      if (res.status === 401) {
        signOutCloud();
        return;
      }
      if (res.ok) {
        const d = await res.json();
        if (d.user) {
          authUser = d.user;
          saveJson('muxis_cloud_user', authUser);
          await pullCloudSync();
        }
      }
    } catch (_) {}
  }

  async function pullCloudSync() {
    if (!authToken) return;
    try {
      const res = await fetch(`${WORKER_URL}/api/sync/pull`, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      if (!res.ok) return;
      const d = await res.json();
      if (Array.isArray(d.favorites)) {
        const merged = [...favorites];
        d.favorites.forEach((rf) => {
          if (!merged.some((lf) => lf.track_uri === rf.track_uri)) {
            merged.push({ id: `cloud-${rf.track_uri}`, track_uri: rf.track_uri, title: rf.title, artist: rf.artist, album: rf.album || '', url: rf.track_uri.startsWith('http') ? rf.track_uri : '', badge: 'SYNCED' });
          }
        });
        favorites = merged;
        saveJson('muxis_pwa_favorites', favorites);
        renderFavorites();
      }
      if (d.settings && d.settings.dark_preset && THEMES[d.settings.dark_preset]) {
        initTheme(d.settings.dark_preset);
      }
      renderCloudView();
    } catch (_) {}
  }

  async function pushCloudSync(payload) {
    if (!authToken) return;
    try {
      await fetch(`${WORKER_URL}/api/sync/push`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${authToken}` },
        body: JSON.stringify(Object.assign({
          device: { name: /iPhone|iPad/i.test(navigator.userAgent) ? 'iPhone PWA' : 'Web PWA', platform: 'pwa', client_version: '1.2.13' }
        }, payload))
      });
    } catch (_) {}
  }

  function signOutCloud() {
    authToken = '';
    authUser = null;
    localStorage.removeItem('muxis_cloud_token');
    localStorage.removeItem('muxis_cloud_user');
    renderCloudView();
    showToast('Signed out of MUXIS Cloud');
  }

  function renderCloudView() {
    const topBtn = document.getElementById('open-cloud-btn');
    const box = document.getElementById('cloud-account-box');
    if (authToken && authUser) {
      topBtn.textContent = authUser.display_name || 'Cloud';
      box.innerHTML = '';
      const h = document.createElement('h3');
      h.style.cssText = 'font-size:18px;font-weight:800;margin-bottom:4px;';
      h.textContent = authUser.display_name || 'MUXIS Listener';
      const p = document.createElement('p');
      p.style.cssText = 'font-size:12.5px;color:var(--text-muted);margin-bottom:14px;';
      p.textContent = `${authUser.email} • Synced via Cloudflare D1`;
      const row = document.createElement('div');
      row.style.cssText = 'display:flex;gap:10px;flex-wrap:wrap;';
      const syncBtn = document.createElement('button');
      syncBtn.type = 'button';
      syncBtn.className = 'pill-btn accent';
      syncBtn.textContent = 'Sync Now';
      syncBtn.addEventListener('click', async () => { await pullCloudSync(); showToast('Cloudflare D1 synced!'); });
      const outBtn = document.createElement('button');
      outBtn.type = 'button';
      outBtn.className = 'pill-btn';
      outBtn.textContent = 'Sign Out';
      outBtn.addEventListener('click', signOutCloud);
      row.append(syncBtn, outBtn);
      box.append(h, p, row);
    } else {
      topBtn.textContent = 'Cloud Sign In';
    }
  }

  function loadJson(key, fallback) {
    try {
      const v = localStorage.getItem(key);
      return v ? JSON.parse(v) : fallback;
    } catch (_) { return fallback; }
  }

  function saveJson(key, val) {
    try { localStorage.setItem(key, JSON.stringify(val)); } catch (_) {}
  }

  function showToast(msg) {
    const el = document.getElementById('toast');
    el.textContent = msg;
    el.classList.add('show');
    clearTimeout(el._t);
    el._t = setTimeout(() => el.classList.remove('show'), 2600);
  }
})();
