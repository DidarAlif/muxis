// MUXIS by A Leaf ORG — App-Native Liquid Surface Pointer Engine,
// Live Spectrum Visualizer, Theme Switcher & Auto-Synced GitHub Releases

(function () {
  'use strict';

  const GITHUB_REPO = 'DidarAlif/muxis';
  const GITHUB_RELEASE_API = `https://api.github.com/repos/${GITHUB_REPO}/releases/latest`;
  const WORKER_VERSION_API = 'https://muxis-api-worker.a-leaf-org.workers.dev/api/version';
  const LOCAL_FALLBACK_JSON = './latest-release.json';
  const RELEASES_PAGE = `https://github.com/${GITHUB_REPO}/releases`;

  // Exact ThemeCatalog Presets from lib/shared/utils/theme_catalog.dart
  const THEMES = {
    obsidian_aurora: {
      name: 'Prismatic Obsidian',
      accent: '#00FF88', accentRgb: '0, 255, 136',
      secondary: '#00E5FF', secondaryRgb: '0, 229, 255',
      tertiary: '#9D6BFF', tertiaryRgb: '157, 107, 255',
      highlight: '#FF4D8D', highlightRgb: '255, 77, 141',
      bgDeep: '#060910', bgSecondary: '#0B111C'
    },
    midnight_sapphire: {
      name: 'Midnight Sapphire',
      accent: '#38BDF8', accentRgb: '56, 189, 248',
      secondary: '#22D3EE', secondaryRgb: '34, 211, 238',
      tertiary: '#818CF8', tertiaryRgb: '129, 140, 248',
      highlight: '#60A5FA', highlightRgb: '96, 165, 250',
      bgDeep: '#050B16', bgSecondary: '#091426'
    },
    botanical_jade: {
      name: 'Botanical Leaf',
      accent: '#10B981', accentRgb: '16, 185, 129',
      secondary: '#2DD4BF', secondaryRgb: '45, 212, 191',
      tertiary: '#6EE7B7', tertiaryRgb: '110, 231, 183',
      highlight: '#A3E635', highlightRgb: '163, 230, 53',
      bgDeep: '#040F0B', bgSecondary: '#081A14'
    },
    ultraviolet_synth: {
      name: 'Ultraviolet Synth',
      accent: '#C084FC', accentRgb: '192, 132, 252',
      secondary: '#22D3EE', secondaryRgb: '34, 211, 238',
      tertiary: '#F472B6', tertiaryRgb: '244, 114, 182',
      highlight: '#E879F9', highlightRgb: '232, 121, 249',
      bgDeep: '#080514', bgSecondary: '#100A24'
    },
    crimson_velvet: {
      name: 'Crimson Velvet',
      accent: '#FF4D8D', accentRgb: '255, 77, 141',
      secondary: '#FB7185', secondaryRgb: '251, 113, 133',
      tertiary: '#C084FC', tertiaryRgb: '192, 132, 252',
      highlight: '#F43F5E', highlightRgb: '244, 63, 94',
      bgDeep: '#0F060A', bgSecondary: '#180A11'
    }
  };

  let activeTheme = THEMES.obsidian_aurora;
  let activeEqProfile = [4.5, 4.0, 2.0, -0.5, 0.5, 1.5, 3.0, 4.5, 5.5, 6.0]; // Prismatic Neon preset

  const EQ_PROFILES = {
    prismatic: [4.5, 4.0, 2.0, -0.5, 0.5, 1.5, 3.0, 4.5, 5.5, 6.0],
    bass: [7.5, 6.5, 4.5, 1.5, 0.0, 0.0, 1.0, 1.5, 2.0, 2.0],
    vocal: [-1.5, -1.0, 0.5, 2.5, 4.5, 5.5, 4.0, 2.0, 1.0, 0.5],
    edm: [6.0, 5.0, 2.5, -1.0, 0.5, 2.0, 3.5, 4.5, 6.0, 6.5],
    flat: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  };

  const FALLBACK_ASSETS = {
    'windows-exe': { name: 'Muxis-Windows-x64-Setup.exe', url: `${RELEASES_PAGE}/latest/download/Muxis-Windows-x64-Setup.exe`, size: 13082490 },
    'windows-zip': { name: 'Muxis-Windows-x64.zip', url: `${RELEASES_PAGE}/latest/download/Muxis-Windows-x64.zip`, size: 15470498 },
    'macos-zip': { name: 'Muxis-macOS-Universal.zip', url: `${RELEASES_PAGE}/latest/download/Muxis-macOS-Universal.zip`, size: 27192084 },
    'linux-tar': { name: 'Muxis-Linux-x64.tar.gz', url: `${RELEASES_PAGE}/latest/download/Muxis-Linux-x64.tar.gz`, size: 12842653 },
    'android-apk': { name: 'Muxis-Android.apk', url: `${RELEASES_PAGE}/latest/download/Muxis-Android.apk`, size: 29807121 },
    'android-aab': { name: 'Muxis-Android.aab', url: `${RELEASES_PAGE}/latest/download/Muxis-Android.aab`, size: 30594777 },
    'ios-ipa': { name: 'Muxis-iOS.ipa', url: `${RELEASES_PAGE}/latest/download/Muxis-iOS.ipa`, size: 13059059 },
    'ios-zip': { name: 'Muxis-iOS-Unsigned.zip', url: `${RELEASES_PAGE}/latest/download/Muxis-iOS-Unsigned.zip`, size: 13055411 },
    'checksums': { name: 'checksums-sha256.txt', url: `${RELEASES_PAGE}/latest/download/checksums-sha256.txt`, size: 1464 }
  };

  let currentRelease = {
    version: '1.2.13',
    tag: 'v1.2.13',
    title: 'MUXIS v1.2.13 — Prismatic Aura',
    publishedAt: '2026-11-28T08:13:47Z',
    htmlUrl: `${RELEASES_PAGE}/tag/v1.2.13`,
    body: '',
    sourceLabel: 'Synced Baseline',
    assets: Object.assign({}, FALLBACK_ASSETS)
  };

  document.addEventListener('DOMContentLoaded', () => {
    initThemeEngine();
    initGlobalPointerCaustic();
    initLiquidSurfaces();
    initSidebarAndMobileDrawer();
    initScrollReveal();
    initShowcaseStage();
    initEqPresetButtons();
    initAudioVisualizers();
    initPlatformDetection();
    initLiveReleaseSync();
    initPublicAdSense();
  });

  // =========================================================================
  // 1. Live App Theme Catalog Switcher (Synced across pages via localStorage)
  // =========================================================================
  function initThemeEngine() {
    const savedId = safeStorageGet('muxis_web_theme') || 'obsidian_aurora';
    applyTheme(savedId);

    document.querySelectorAll('[data-theme-pick]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const id = btn.dataset.themePick;
        applyTheme(id);
        safeStorageSet('muxis_web_theme', id);
      });
    });
  }

  function applyTheme(id) {
    const theme = THEMES[id] || THEMES.obsidian_aurora;
    activeTheme = theme;
    const root = document.documentElement.style;
    root.setProperty('--accent', theme.accent);
    root.setProperty('--accent-rgb', theme.accentRgb);
    root.setProperty('--secondary', theme.secondary);
    root.setProperty('--secondary-rgb', theme.secondaryRgb);
    root.setProperty('--tertiary', theme.tertiary);
    root.setProperty('--tertiary-rgb', theme.tertiaryRgb);
    root.setProperty('--highlight', theme.highlight);
    root.setProperty('--highlight-rgb', theme.highlightRgb);
    root.setProperty('--bg-deep', theme.bgDeep);
    root.setProperty('--bg-secondary', theme.bgSecondary);

    document.querySelectorAll('[data-theme-pick]').forEach((btn) => {
      btn.classList.toggle('active', btn.dataset.themePick === id);
    });
    document.querySelectorAll('[data-active-theme-name]').forEach((label) => {
      label.textContent = theme.name;
    });
  }

  function safeStorageGet(k) {
    try { return window.localStorage.getItem(k); } catch (_) { return null; }
  }
  function safeStorageSet(k, v) {
    try { window.localStorage.setItem(k, v); } catch (_) {}
  }

  // =========================================================================
  // 2. Global Cursor Caustic Light Pool (MuxisAmbientBackdrop pointer sheen)
  // =========================================================================
  function initGlobalPointerCaustic() {
    const halo = document.querySelector('.global-pointer-caustic');
    if (!halo) return;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

    let targetX = window.innerWidth * 0.5;
    let targetY = window.innerHeight * 0.3;
    let curX = targetX;
    let curY = targetY;
    let hasMoved = false;

    window.addEventListener('pointermove', (e) => {
      if (e.pointerType === 'touch') return;
      targetX = e.clientX;
      targetY = e.clientY;
      if (!hasMoved) {
        hasMoved = true;
        document.body.classList.add('has-pointer');
        curX = targetX;
        curY = targetY;
        tickHalo();
      }
    }, { passive: true });

    window.addEventListener('pointerleave', () => {
      document.body.classList.remove('has-pointer');
      hasMoved = false;
    });

    function tickHalo() {
      if (!hasMoved) return;
      curX += (targetX - curX) * 0.14;
      curY += (targetY - curY) * 0.14;
      halo.style.transform = `translate3d(${curX.toFixed(1)}px, ${curY.toFixed(1)}px, 0)`;
      requestAnimationFrame(tickHalo);
    }
  }

  // =========================================================================
  // 3. MuxisLiquidSurface Canvas Engine (Exact port of muxis_liquid_surface.dart)
  //    - Cursor-tracking liquid caustic glow
  //    - Dual translucent undulating water-wave bands + white specular crest
  //    - Concentric expanding water-drop rings + splash flash on click
  // =========================================================================
  function initLiquidSurfaces() {
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduced) return;

    const surfaces = document.querySelectorAll('.liquid-surface');
    surfaces.forEach(mountLiquidSurface);
  }

  function mountLiquidSurface(el) {
    if (el.dataset.liquidMounted === '1') return;
    el.dataset.liquidMounted = '1';

    const canvas = document.createElement('canvas');
    canvas.className = 'liquid-fx-canvas';
    el.insertBefore(canvas, el.firstChild);
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let isHovered = false;
    let hoverBlend = 0;
    let hoverX = 0;
    let hoverY = 0;
    let wavePhase = 0;
    let droplets = []; // { x, y, startMs }
    let rafId = null;
    let w = 0;
    let h = 0;
    const DROP_DURATION = 820;

    function syncSize() {
      const rect = el.getBoundingClientRect();
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      w = rect.width;
      h = rect.height;
      if (w <= 0 || h <= 0) return;
      if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
        canvas.width = Math.round(w * dpr);
        canvas.height = Math.round(h * dpr);
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      }
    }

    function ensureTick() {
      if (rafId === null) {
        rafId = requestAnimationFrame(render);
      }
    }

    el.addEventListener('pointerenter', (e) => {
      syncSize();
      const rect = el.getBoundingClientRect();
      hoverX = e.clientX - rect.left;
      hoverY = e.clientY - rect.top;
      isHovered = true;
      ensureTick();
    }, { passive: true });

    el.addEventListener('pointermove', (e) => {
      const rect = el.getBoundingClientRect();
      hoverX = e.clientX - rect.left;
      hoverY = e.clientY - rect.top;
      if (!isHovered) {
        isHovered = true;
        syncSize();
      }
      if (el.hasAttribute('data-tilt') && w > 0 && h > 0) {
        const nx = (hoverX / w - 0.5) * 2;
        const ny = (hoverY / h - 0.5) * 2;
        el.style.transform = `perspective(900px) rotateX(${(-ny * 2.2).toFixed(2)}deg) rotateY(${(nx * 2.2).toFixed(2)}deg) translateY(-2px)`;
      }
      ensureTick();
    }, { passive: true });

    el.addEventListener('pointerleave', () => {
      isHovered = false;
      if (el.hasAttribute('data-tilt')) {
        el.style.transform = '';
      }
      ensureTick();
    }, { passive: true });

    el.addEventListener('pointerdown', (e) => {
      el.classList.add('is-pressed');
      syncSize();
      const rect = el.getBoundingClientRect();
      droplets.push({
        x: e.clientX - rect.left,
        y: e.clientY - rect.top,
        startMs: performance.now()
      });
      if (droplets.length > 5) droplets.shift();
      ensureTick();
    }, { passive: true });

    window.addEventListener('pointerup', () => {
      el.classList.remove('is-pressed');
    }, { passive: true });

    function render(now) {
      rafId = null;
      syncSize();
      if (w <= 0 || h <= 0) return;

      // Blend hover smoothness matching Flutter _hoverBlendCtrl (240ms)
      hoverBlend += isHovered ? Math.min(1 - hoverBlend, 0.14) : -Math.min(hoverBlend, 0.10);
      if (hoverBlend < 0.005 && !isHovered) hoverBlend = 0;

      droplets = droplets.filter((d) => now - d.startMs < DROP_DURATION);

      ctx.clearRect(0, 0, w, h);

      if (hoverBlend > 0.001) {
        const cx = hoverX || w * 0.5;
        const cy = hoverY || h * 0.5;
        const spotRadius = Math.max(w, h) * 0.65;

        // 1. Cursor Caustic Pool
        const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, spotRadius);
        grad.addColorStop(0, `rgba(${activeTheme.accentRgb}, ${(0.17 * hoverBlend).toFixed(3)})`);
        grad.addColorStop(0.45, `rgba(${activeTheme.secondaryRgb}, ${(0.085 * hoverBlend).toFixed(3)})`);
        grad.addColorStop(1, 'rgba(0,0,0,0)');
        ctx.fillStyle = grad;
        ctx.fillRect(0, 0, w, h);

        // 2. Dual Translucent Water-Wave Bands & White Specular Crest
        const basePhase = wavePhase * Math.PI * 2;
        for (let layer = 0; layer < 2; layer++) {
          const ph = basePhase + layer * 1.45;
          const freq = layer === 0 ? 2.4 : 3.2;
          const amp = (layer === 0 ? 8.5 : 5.5) * hoverBlend;
          const clampedY = Math.max(h * 0.18, Math.min(h * 0.85, cy));
          const yBase = clampedY + (layer === 0 ? -4 : 12);

          ctx.beginPath();
          ctx.moveTo(0, h);
          for (let x = 0; x <= w + 12; x += 12) {
            const normX = x / Math.max(1, w);
            const y = yBase + Math.sin(normX * Math.PI * freq + ph) * amp + Math.cos(normX * Math.PI * 1.5 - ph * 0.7) * (amp * 0.45);
            ctx.lineTo(x, y);
          }
          ctx.lineTo(w, h);
          ctx.closePath();

          const waveRgb = layer === 0 ? activeTheme.secondaryRgb : activeTheme.accentRgb;
          ctx.fillStyle = `rgba(${waveRgb}, ${(0.08 * hoverBlend).toFixed(3)})`;
          ctx.fill();

          // Specular crest highlight
          ctx.beginPath();
          for (let x = 0; x <= w + 12; x += 12) {
            const normX = x / Math.max(1, w);
            const y = yBase + Math.sin(normX * Math.PI * freq + ph) * amp + Math.cos(normX * Math.PI * 1.5 - ph * 0.7) * (amp * 0.45);
            if (x === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
          }
          ctx.strokeStyle = `rgba(255, 255, 255, ${(0.18 * hoverBlend).toFixed(3)})`;
          ctx.lineWidth = 1.15;
          ctx.stroke();
        }
      }

      // 3. Concentric Expanding Water-Drop Ripple Rings
      if (droplets.length > 0) {
        const maxR = Math.hypot(w, h) * 0.82;
        droplets.forEach((d) => {
          const rawT = Math.min(1, Math.max(0, (now - d.startMs) / DROP_DURATION));

          if (rawT < 0.34) {
            const coreT = rawT / 0.34;
            const coreR = 6 + 26 * (1 - Math.pow(1 - coreT, 2));
            const coreGrad = ctx.createRadialGradient(d.x, d.y, 0, d.x, d.y, coreR);
            coreGrad.addColorStop(0, `rgba(255,255,255,${((1 - coreT) * 0.48).toFixed(3)})`);
            coreGrad.addColorStop(0.5, `rgba(${activeTheme.accentRgb},${((1 - coreT) * 0.32).toFixed(3)})`);
            coreGrad.addColorStop(1, 'rgba(0,0,0,0)');
            ctx.fillStyle = coreGrad;
            ctx.beginPath();
            ctx.arc(d.x, d.y, coreR, 0, Math.PI * 2);
            ctx.fill();
          }

          for (let ring = 0; ring < 3; ring++) {
            const delay = ring * 0.14;
            if (rawT <= delay) continue;
            const rt = Math.min(1, (rawT - delay) / (1 - delay));
            const eased = 1 - Math.pow(1 - rt, 3);
            const r = 4 + maxR * (1 - ring * 0.16) * eased;
            const alpha = Math.pow(1 - rt, 1.6);
            const strokeColor = ring === 0
              ? `rgba(255,255,255,${(0.52 * alpha).toFixed(3)})`
              : (ring === 1
                ? `rgba(${activeTheme.secondaryRgb},${(0.55 * alpha).toFixed(3)})`
                : `rgba(${activeTheme.accentRgb},${(0.42 * alpha).toFixed(3)})`);
            ctx.beginPath();
            ctx.arc(d.x, d.y, r, 0, Math.PI * 2);
            ctx.strokeStyle = strokeColor;
            ctx.lineWidth = Math.max(0.6, (2.6 - ring * 0.65) * (1 - rt * 0.55));
            ctx.stroke();
          }
        });
      }

      wavePhase = (wavePhase + 0.007) % 1;
      if (hoverBlend > 0.005 || isHovered || droplets.length > 0) {
        rafId = requestAnimationFrame(render);
      }
    }
  }

  // =========================================================================
  // 4. Sidebar Collapse + Mobile Drawer
  // =========================================================================
  function initSidebarAndMobileDrawer() {
    const sidebar = document.getElementById('app-sidebar');
    const collapseBtn = document.getElementById('sidebar-collapse-btn');
    if (sidebar && collapseBtn) {
      collapseBtn.addEventListener('click', () => {
        const collapsed = sidebar.classList.toggle('collapsed');
        document.body.classList.toggle('sidebar-collapsed', collapsed);
      });
    }

    const mobileBtn = document.getElementById('mobile-nav-toggle');
    const mobileDrawer = document.getElementById('mobile-nav-drawer');
    if (mobileBtn && mobileDrawer) {
      mobileBtn.addEventListener('click', () => {
        const open = mobileDrawer.classList.toggle('open');
        mobileBtn.setAttribute('aria-expanded', String(open));
      });
      mobileDrawer.querySelectorAll('a').forEach((a) => {
        a.addEventListener('click', () => {
          mobileDrawer.classList.remove('open');
          mobileBtn.setAttribute('aria-expanded', 'false');
        });
      });
    }
  }

  function initScrollReveal() {
    const nodes = document.querySelectorAll('.reveal');
    if (!nodes.length) return;
    if (!('IntersectionObserver' in window)) {
      nodes.forEach((n) => n.classList.add('is-visible'));
      return;
    }
    const obs = new IntersectionObserver((entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) {
          e.target.classList.add('is-visible');
          obs.unobserve(e.target);
        }
      });
    }, { threshold: 0.1 });
    nodes.forEach((n) => obs.observe(n));
  }

  // =========================================================================
  // 5. Interactive Showcase Stage + Live AudioVisualizer Playground
  // =========================================================================
  function initShowcaseStage() {
    const tabs = Array.from(document.querySelectorAll('.stage-tab'));
    const slides = Array.from(document.querySelectorAll('.stage-slide'));
    const titleEl = document.getElementById('stage-caption-title');
    const descEl = document.getElementById('stage-caption-desc');
    if (!tabs.length || !slides.length) return;

    const activate = (idx) => {
      const t = tabs[idx];
      const target = t.dataset.target;
      tabs.forEach((b, i) => {
        b.classList.toggle('active', i === idx);
        b.setAttribute('aria-selected', String(i === idx));
      });
      slides.forEach((s) => s.classList.toggle('active', s.dataset.slide === target));
      if (titleEl && t.dataset.title) titleEl.textContent = t.dataset.title;
      if (descEl && t.dataset.desc) descEl.textContent = t.dataset.desc;
    };

    tabs.forEach((tab, idx) => {
      tab.addEventListener('click', () => activate(idx));
    });
  }

  function initEqPresetButtons() {
    const pills = document.querySelectorAll('[data-eq-preset]');
    if (!pills.length) return;
    pills.forEach((p) => {
      p.addEventListener('click', () => {
        const key = p.dataset.eqPreset;
        if (EQ_PROFILES[key]) activeEqProfile = EQ_PROFILES[key];
        pills.forEach((b) => b.classList.toggle('active', b === p));
      });
    });
  }

  // Exact port of lib/features/player/audio_visualizer.dart spectrum math
  function initAudioVisualizers() {
    const studioCanvas = document.getElementById('studio-visualizer-canvas');
    const dockCanvas = document.getElementById('dock-eq-canvas');
    if (!studioCanvas && !dockCanvas) return;

    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const studioCount = 46;
    const dockCount = 24;
    const sLevels = new Float32Array(studioCount).fill(0.15);
    const sPeaks = new Float32Array(studioCount).fill(0.2);
    const dLevels = new Float32Array(dockCount).fill(0.2);
    let tick = 0;

    function drawSpectrum(canvas, count, levels, peaks, showMirror, showPeaks) {
      if (!canvas) return;
      const rect = canvas.getBoundingClientRect();
      if (!rect.width || !rect.height) return;
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      if (canvas.width !== Math.round(rect.width * dpr) || canvas.height !== Math.round(rect.height * dpr)) {
        canvas.width = Math.round(rect.width * dpr);
        canvas.height = Math.round(rect.height * dpr);
      }
      const ctx = canvas.getContext('2d');
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      const w = rect.width;
      const h = rect.height;
      ctx.clearRect(0, 0, w, h);

      const phase = tick * 0.045;
      const kickPulse = 0.55 + 0.45 * Math.pow(Math.max(0, Math.sin(phase * 3.15)), 4);
      const midGroove = 0.55 + 0.45 * Math.sin(phase * 2.25 + 0.7);
      const airPulse = 0.45 + 0.55 * Math.pow(Math.max(0, Math.sin(phase * 5.8 + 1.4)), 2);

      const barGap = w / count;
      const barW = Math.max(3, barGap * 0.62);
      const baseline = showMirror ? h * 0.74 : h * 0.92;
      const maxBarH = showMirror ? h * 0.66 : h * 0.85;

      const grad = ctx.createLinearGradient(0, 0, w, 0);
      grad.addColorStop(0, activeTheme.accent);
      grad.addColorStop(0.42, activeTheme.secondary);
      grad.addColorStop(0.76, activeTheme.tertiary);
      grad.addColorStop(1, activeTheme.highlight);

      ctx.fillStyle = grad;

      for (let i = 0; i < count; i++) {
        const u = i / (count - 1);
        const subW = Math.exp(-Math.pow((u - 0.12) / 0.16, 2));
        const midW = Math.exp(-Math.pow((u - 0.45) / 0.28, 2));
        const highW = Math.exp(-Math.pow((u - 0.80) / 0.22, 2));

        const h1 = 0.5 + 0.5 * Math.sin(phase * (2.6 + u * 4.8) + i * 0.41);
        const h2 = 0.5 + 0.5 * Math.cos(phase * (4.1 - u * 2.3) + i * 0.77);
        const h3 = 0.5 + 0.5 * Math.sin(phase * (6.7 + u * 6.2) - i * 0.29);

        // Apply active 10-band EQ curve shaping
        const eqIdx = Math.min(9, Math.floor(u * 10));
        const eqBoost = 1 + activeEqProfile[eqIdx] * 0.045;

        const target = Math.min(1, Math.max(0.06,
          ((subW * kickPulse * (0.45 + 0.55 * h1) * 0.95) +
           (midW * midGroove * (0.35 + 0.65 * h2) * 0.86) +
           (highW * airPulse * (0.30 + 0.70 * h3) * 0.72)) * eqBoost
        ));

        levels[i] += (target - levels[i]) * 0.26;
        if (levels[i] > peaks[i]) peaks[i] = levels[i];
        else peaks[i] = Math.max(levels[i], peaks[i] - 0.008);

        const barH = levels[i] * maxBarH;
        const x = i * barGap + (barGap - barW) * 0.5;
        const y = baseline - barH;

        ctx.globalAlpha = 0.92;
        ctx.beginPath();
        if (ctx.roundRect) ctx.roundRect(x, y, barW, barH, barW * 0.45);
        else ctx.rect(x, y, barW, barH);
        ctx.fill();

        if (showMirror) {
          ctx.globalAlpha = 0.22;
          ctx.beginPath();
          if (ctx.roundRect) ctx.roundRect(x, baseline + 3, barW, barH * 0.28, barW * 0.4);
          else ctx.rect(x, baseline + 3, barW, barH * 0.28);
          ctx.fill();
        }

        if (showPeaks) {
          ctx.globalAlpha = 0.85;
          const peakY = baseline - peaks[i] * maxBarH - 5;
          ctx.fillRect(x, peakY, barW, 2.2);
        }
      }
      ctx.globalAlpha = 1;
    }

    function loop() {
      if (!document.hidden) {
        tick++;
        drawSpectrum(studioCanvas, studioCount, sLevels, sPeaks, true, true);
        drawSpectrum(dockCanvas, dockCount, dLevels, new Float32Array(dockCount), false, false);
      }
      if (!reduced) requestAnimationFrame(loop);
    }
    loop();
  }

  // =========================================================================
  // 6. OS Auto-Detection & Always-Latest GitHub Release Engine
  // =========================================================================
  function detectOS() {
    const ua = navigator.userAgent || '';
    const platform = navigator.platform || '';
    const isIpadOS = /Macintosh/i.test(ua) && navigator.maxTouchPoints && navigator.maxTouchPoints > 1;
    if (/iPhone|iPad|iPod/i.test(ua) || isIpadOS) return 'ios';
    if (/Android/i.test(ua)) return 'android';
    if (/Win/i.test(platform) || /Windows/i.test(ua)) return 'windows';
    if (/Mac/i.test(platform) || /Mac OS/i.test(ua)) return 'macos';
    if (/Linux|X11/i.test(platform) || /Linux/i.test(ua)) return 'linux';
    return 'windows';
  }

  function formatBytes(bytes) {
    if (!bytes || bytes <= 0) return '';
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }

  function formatReleaseDate(iso) {
    if (!iso) return 'Latest Release';
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return iso;
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  }

  function initPlatformDetection() {
    const os = detectOS();
    applyPrimaryPlatformCTA(os);
    document.querySelectorAll('[data-platform-card]').forEach((card) => {
      card.classList.toggle('recommended', card.dataset.platformCard === os);
    });
  }

  function applyPrimaryPlatformCTA(os) {
    const primaryBtn = document.getElementById('primary-download-btn');
    const dockBtn = document.getElementById('dock-download-btn');
    const osHint = document.getElementById('detected-os-hint');
    const assets = currentRelease.assets;
    const tag = currentRelease.tag;

    const map = {
      windows: { label: `Download for Windows (${tag})`, dock: `Get Windows (${tag})`, href: assets['windows-exe'].url, note: 'Windows 10/11 (x64 Installer • Portable .zip available)' },
      macos: { label: `Download for macOS (${tag})`, dock: `Get macOS (${tag})`, href: assets['macos-zip'].url, note: 'macOS Universal (Apple Silicon + Intel)' },
      linux: { label: `Download for Linux (${tag})`, dock: `Get Linux (${tag})`, href: assets['linux-tar'].url, note: 'Linux x86_64 App Bundle (.tar.gz)' },
      android: { label: `Download Android APK (${tag})`, dock: `Get APK (${tag})`, href: assets['android-apk'].url, note: 'Signed Universal APK • Android 6.0+' },
      ios: { label: 'Install iPhone Web App (1-Tap PWA)', dock: 'Open iOS App', href: 'app/', note: 'Safari -> Add to Home Screen (No PC needed) • .ipa also available on Download page' }
    };

    const sel = map[os] || map.windows;
    if (primaryBtn) {
      const span = primaryBtn.querySelector('[data-cta-label]');
      if (span) span.textContent = sel.label;
      else primaryBtn.textContent = sel.label;
      primaryBtn.href = sel.href;
    }
    if (dockBtn) {
      dockBtn.textContent = sel.dock;
      dockBtn.href = sel.href;
    }
    if (osHint) osHint.textContent = sel.note;
  }

  function resolveAssetMap(assetList) {
    const result = Object.assign({}, FALLBACK_ASSETS);
    if (!Array.isArray(assetList) || !assetList.length) return result;
    const matchers = [
      ['windows-exe', (n) => /^Muxis-Windows-x64-Setup\.exe$/i.test(n), /setup.*\.exe$/i],
      ['windows-zip', (n) => /^Muxis-Windows-x64\.zip$/i.test(n), /^Muxis-Windows.*\.zip$/i],
      ['macos-zip', (n) => /^Muxis-macOS-Universal\.zip$/i.test(n), /^Muxis-macOS.*\.zip$/i],
      ['linux-tar', (n) => /^Muxis-Linux-x64\.tar\.gz$/i.test(n), /^Muxis-Linux.*\.tar\.gz$/i],
      ['android-apk', (n) => /^Muxis-Android\.apk$/i.test(n), /^Muxis-Android.*\.apk$/i],
      ['android-aab', (n) => /^Muxis-Android\.aab$/i.test(n), /^Muxis-Android.*\.aab$/i],
      ['ios-ipa', (n) => /^Muxis-iOS\.ipa$/i.test(n), /^Muxis-iOS.*\.ipa$/i],
      ['ios-zip', (n) => /^Muxis-iOS-Unsigned\.zip$/i.test(n), /^Muxis-iOS-Unsigned.*\.zip$/i],
      ['checksums', (n) => /^checksums-sha256\.txt$/i.test(n), /checksums.*\.txt$/i]
    ];
    matchers.forEach(([key, exactFn, fallbackRegex]) => {
      const found = assetList.find((a) => a && a.name && exactFn(a.name)) ||
        assetList.find((a) => a && a.name && fallbackRegex.test(a.name));
      if (found && found.browser_download_url) {
        result[key] = { name: found.name, url: found.browser_download_url, size: Number(found.size || 0) };
      }
    });
    return result;
  }

  async function initLiveReleaseSync() {
    try {
      const localRes = await fetch(LOCAL_FALLBACK_JSON);
      if (localRes.ok) {
        const localData = await localRes.json();
        if (localData && localData.tag_name) applyGitHubPayload(localData, 'Cached Release Manifest');
      }
    } catch (_) {}

    try {
      const ghRes = await fetch(GITHUB_RELEASE_API);
      if (ghRes.ok) {
        const ghData = await ghRes.json();
        if (ghData && ghData.tag_name) {
          applyGitHubPayload(ghData, 'Live via GitHub Releases');
          return;
        }
      }
    } catch (_) {}

    try {
      const wkRes = await fetch(WORKER_VERSION_API);
      if (wkRes.ok) {
        const wkData = await wkRes.json();
        if (wkData && wkData.latest_version) applyWorkerPayload(wkData);
      }
    } catch (_) {}
  }

  function applyGitHubPayload(data, sourceLabel) {
    const rawTag = String(data.tag_name || 'v1.2.13');
    const cleanVer = rawTag.replace(/^v/i, '');
    const normalizedTag = rawTag.startsWith('v') ? rawTag : `v${cleanVer}`;
    currentRelease = {
      version: cleanVer,
      tag: normalizedTag,
      title: data.name || `MUXIS ${normalizedTag}`,
      publishedAt: data.published_at || '',
      htmlUrl: data.html_url || `${RELEASES_PAGE}/tag/${normalizedTag}`,
      body: data.body || '',
      sourceLabel: sourceLabel || 'Live via GitHub Releases',
      assets: resolveAssetMap(data.assets)
    };
    renderReleaseIntoDOM();
  }

  function applyWorkerPayload(wk) {
    const cleanVer = String(wk.latest_version || '1.2.13').replace(/^v/i, '');
    const tag = `v${cleanVer}`;
    const p = wk.platforms || {};
    const assets = Object.assign({}, FALLBACK_ASSETS);
    if (p.windows && p.windows.download_url) assets['windows-zip'].url = p.windows.download_url;
    if (p.macos && p.macos.download_url) assets['macos-zip'].url = p.macos.download_url;
    if (p.linux && p.linux.download_url) assets['linux-tar'].url = p.linux.download_url;
    if (p.android && p.android.download_url) assets['android-apk'].url = p.android.download_url;
    if (p.ios && p.ios.download_url) assets['ios-ipa'].url = p.ios.download_url;
    if (p.ios && p.ios.unsigned_zip_url) assets['ios-zip'].url = p.ios.unsigned_zip_url;
    currentRelease = {
      version: cleanVer,
      tag,
      title: wk.app_name ? `${wk.app_name} — ${tag}` : `MUXIS ${tag}`,
      publishedAt: wk.release_date || '',
      htmlUrl: `${RELEASES_PAGE}/tag/${tag}`,
      body: Array.isArray(wk.changelog) ? wk.changelog.map((l) => `- ${l}`).join('\n') : '',
      sourceLabel: 'Via Cloudflare Edge Mirror',
      assets
    };
    renderReleaseIntoDOM();
  }

  function renderReleaseIntoDOM() {
    document.querySelectorAll('[data-release-tag]').forEach((el) => { el.textContent = currentRelease.tag; });
    document.querySelectorAll('[data-release-version]').forEach((el) => { el.textContent = currentRelease.version; });
    document.querySelectorAll('[data-release-title]').forEach((el) => { el.textContent = currentRelease.title; });
    document.querySelectorAll('[data-release-date]').forEach((el) => { el.textContent = `Published ${formatReleaseDate(currentRelease.publishedAt)}`; });
    document.querySelectorAll('[data-release-source]').forEach((el) => { el.textContent = currentRelease.sourceLabel; });
    document.querySelectorAll('[data-release-url]').forEach((el) => { el.href = currentRelease.htmlUrl; });

    Object.entries(currentRelease.assets).forEach(([key, asset]) => {
      document.querySelectorAll(`[data-asset-url="${key}"]`).forEach((el) => { el.href = asset.url; });
      document.querySelectorAll(`[data-asset-size="${key}"]`).forEach((el) => {
        const s = formatBytes(asset.size);
        if (s) el.textContent = s;
      });
    });

    const lists = document.querySelectorAll('[data-release-notes]');
    if (lists.length && currentRelease.body) {
      const lines = currentRelease.body.split(/\r?\n/).map((l) => l.trim()).filter((l) => /^[-*]\s+/.test(l)).map((l) => l.replace(/^[-*]\s+/, '')).slice(0, 6);
      if (lines.length) {
        lists.forEach((ul) => {
          ul.innerHTML = '';
          lines.forEach((raw) => {
            const li = document.createElement('li');
            const clean = raw.replace(/\*\*/g, '');
            clean.split(/(`[^`]+`)/g).forEach((part) => {
              if (part.startsWith('`') && part.endsWith('`') && part.length > 2) {
                const c = document.createElement('code');
                c.textContent = part.slice(1, -1);
                li.appendChild(c);
              } else {
                li.appendChild(document.createTextNode(part));
              }
            });
            ul.appendChild(li);
          });
        });
      }
    }

    applyPrimaryPlatformCTA(detectOS());
  }

  // =========================================================================
  // 8. Scoped Google AdSense Loader (Public https://muxis.pages.dev/ ONLY)
  //    Strictly excluded from /app/, /admin/, and /auth-confirmed routes.
  // =========================================================================
  async function initPublicAdSense() {
    const p = (window.location.pathname || '/').toLowerCase();
    if (/^\/(app|admin|auth-confirmed)/.test(p)) return;

    const metaCid = document.querySelector('meta[name="google-adsense-account"]')?.getAttribute('content')?.trim() || '';
    let cfg = { enabled: false, clientId: '', slots: {} };

    try {
      const res = await fetch('https://muxis-api-worker.a-leaf-org.workers.dev/api/public/monetization');
      if (res.ok) {
        const d = await res.json();
        if (d && d.clientId) cfg = d;
      }
    } catch (_) {}

    const clientId = /^ca-pub-\d{10,20}$/.test(cfg.clientId || '')
      ? cfg.clientId
      : (/^ca-pub-\d{10,20}$/.test(metaCid) ? metaCid : '');
    if (!clientId) return;

    if (!document.querySelector('script[data-muxis-adsense="1"]')) {
      const s = document.createElement('script');
      s.async = true;
      s.crossOrigin = 'anonymous';
      s.dataset.muxisAdsense = '1';
      s.src = `https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${encodeURIComponent(clientId)}`;
      document.head.appendChild(s);
    }

    const containers = document.querySelectorAll('[data-ad-placement]');
    containers.forEach((box) => {
      const placement = box.dataset.adPlacement || '';
      const slotId = (cfg.slots && cfg.slots[placement]) || box.dataset.adSlot || '';
      if (!/^\d{6,20}$/.test(slotId)) return;

      box.innerHTML = `<span class="muxis-ad-label">Advertisement &middot; Supports Free Open-Source MUXIS</span><ins class="adsbygoogle" style="display:block" data-ad-client="${clientId}" data-ad-slot="${slotId}" data-ad-format="auto" data-full-width-responsive="true"></ins>`;
      box.style.display = 'block';
      try {
        (window.adsbygoogle = window.adsbygoogle || []).push({});
      } catch (_) {}
    });
  }
})();
