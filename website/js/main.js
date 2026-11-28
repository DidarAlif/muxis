// MUXIS Official Website Controller — by A Leaf
// Live GitHub Releases sync, Worker fallback, interactive stage, OS detection & harmonic canvas

(function () {
  'use strict';

  const GITHUB_REPO = 'DidarAlif/muxis';
  const GITHUB_RELEASE_API = `https://api.github.com/repos/${GITHUB_REPO}/releases/latest`;
  const WORKER_VERSION_API = 'https://muxis-api-worker.a-leaf-org.workers.dev/api/version';
  const LOCAL_FALLBACK_JSON = './latest-release.json';
  const RELEASES_PAGE = `https://github.com/${GITHUB_REPO}/releases`;

  const FALLBACK_ASSETS = {
    'windows-exe': {
      name: 'Muxis-Windows-x64-Setup.exe',
      url: `${RELEASES_PAGE}/latest/download/Muxis-Windows-x64-Setup.exe`,
      size: 13082490
    },
    'windows-zip': {
      name: 'Muxis-Windows-x64.zip',
      url: `${RELEASES_PAGE}/latest/download/Muxis-Windows-x64.zip`,
      size: 15470498
    },
    'macos-zip': {
      name: 'Muxis-macOS-Universal.zip',
      url: `${RELEASES_PAGE}/latest/download/Muxis-macOS-Universal.zip`,
      size: 27192084
    },
    'linux-tar': {
      name: 'Muxis-Linux-x64.tar.gz',
      url: `${RELEASES_PAGE}/latest/download/Muxis-Linux-x64.tar.gz`,
      size: 12842653
    },
    'android-apk': {
      name: 'Muxis-Android.apk',
      url: `${RELEASES_PAGE}/latest/download/Muxis-Android.apk`,
      size: 29807121
    },
    'android-aab': {
      name: 'Muxis-Android.aab',
      url: `${RELEASES_PAGE}/latest/download/Muxis-Android.aab`,
      size: 30594777
    },
    'ios-ipa': {
      name: 'Muxis-iOS.ipa',
      url: `${RELEASES_PAGE}/latest/download/Muxis-iOS.ipa`,
      size: 13059059
    },
    'ios-zip': {
      name: 'Muxis-iOS-Unsigned.zip',
      url: `${RELEASES_PAGE}/latest/download/Muxis-iOS-Unsigned.zip`,
      size: 13055411
    },
    'checksums': {
      name: 'checksums-sha256.txt',
      url: `${RELEASES_PAGE}/latest/download/checksums-sha256.txt`,
      size: 1464
    }
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
    initMobileNav();
    initScrollReveal();
    initPlatformDetection();
    initShowcaseStage();
    initSpectrumCanvas();
    initMeterAnimation();
    initLiveReleaseSync();
  });

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

  function initMobileNav() {
    const btn = document.getElementById('mobile-nav-toggle');
    const drawer = document.getElementById('mobile-nav-drawer');
    if (!btn || !drawer) return;

    btn.addEventListener('click', () => {
      const isOpen = drawer.classList.toggle('open');
      btn.setAttribute('aria-expanded', String(isOpen));
    });

    drawer.querySelectorAll('a').forEach((link) => {
      link.addEventListener('click', () => {
        drawer.classList.remove('open');
        btn.setAttribute('aria-expanded', 'false');
      });
    });
  }

  function initScrollReveal() {
    const nodes = document.querySelectorAll('.reveal');
    if (!nodes.length) return;

    if (!('IntersectionObserver' in window)) {
      nodes.forEach((n) => n.classList.add('is-visible'));
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('is-visible');
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.12, rootMargin: '0px 0px -30px 0px' }
    );

    nodes.forEach((node) => observer.observe(node));
  }

  function initPlatformDetection() {
    const os = detectOS();
    applyPrimaryPlatformCTA(os);

    const cards = document.querySelectorAll('[data-platform-card]');
    cards.forEach((card) => {
      card.classList.toggle('recommended', card.dataset.platformCard === os);
    });
  }

  function applyPrimaryPlatformCTA(os) {
    const primaryBtn = document.getElementById('primary-download-btn');
    const osHint = document.getElementById('detected-os-hint');
    const assets = currentRelease.assets;
    const tag = currentRelease.tag;

    const map = {
      windows: {
        label: `Download for Windows (${tag})`,
        href: assets['windows-exe'].url,
        note: 'Windows 10/11 (x64 Installer • Portable .zip available)'
      },
      macos: {
        label: `Download for macOS (${tag})`,
        href: assets['macos-zip'].url,
        note: 'macOS Universal (Apple Silicon + Intel)'
      },
      linux: {
        label: `Download for Linux (${tag})`,
        href: assets['linux-tar'].url,
        note: 'Linux x86_64 App Bundle (.tar.gz)'
      },
      android: {
        label: `Download Android APK (${tag})`,
        href: assets['android-apk'].url,
        note: 'Signed Universal APK • Android 6.0+'
      },
      ios: {
        label: `Download iPhone IPA (${tag})`,
        href: assets['ios-ipa'].url,
        note: 'iPhone / iPad IPA for AltStore, SideStore & Sideloadly'
      }
    };

    const selected = map[os] || map.windows;
    if (primaryBtn) {
      const labelSpan = primaryBtn.querySelector('[data-cta-label]');
      if (labelSpan) {
        labelSpan.textContent = selected.label;
      } else {
        primaryBtn.textContent = selected.label;
      }
      primaryBtn.href = selected.href;
    }
    if (osHint) {
      osHint.textContent = selected.note;
    }
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
      const found =
        assetList.find((a) => a && a.name && exactFn(a.name)) ||
        assetList.find((a) => a && a.name && fallbackRegex.test(a.name));
      if (found && found.browser_download_url) {
        result[key] = {
          name: found.name,
          url: found.browser_download_url,
          size: Number(found.size || 0)
        };
      }
    });

    return result;
  }

  async function initLiveReleaseSync() {
    // 1) Local same-origin manifest first so first state reflects latest built JSON immediately
    try {
      const localRes = await fetch(LOCAL_FALLBACK_JSON);
      if (localRes.ok) {
        const localData = await localRes.json();
        if (localData && localData.tag_name) {
          applyGitHubPayload(localData, 'Cached Release Manifest');
        }
      }
    } catch (_) {
      // Ignore if running directly from file://
    }

    // 2) Live GitHub Releases API (always reflects brand-new published releases immediately)
    try {
      const ghRes = await fetch(GITHUB_RELEASE_API);
      if (ghRes.ok) {
        const ghData = await ghRes.json();
        if (ghData && ghData.tag_name) {
          applyGitHubPayload(ghData, 'Live via GitHub Releases');
          return;
        }
      }
    } catch (_) {
      // Fallback below on network/rate-limit error
    }

    // 3) Edge fallback via MUXIS Cloudflare Worker
    try {
      const wkRes = await fetch(WORKER_VERSION_API);
      if (wkRes.ok) {
        const wkData = await wkRes.json();
        if (wkData && wkData.latest_version) {
          applyWorkerPayload(wkData);
        }
      }
    } catch (_) {
      // Retain manifest/default release metadata gracefully
    }
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

    const changelogLines = Array.isArray(wk.changelog)
      ? wk.changelog.map((line) => `- ${line}`).join('\n')
      : '';

    currentRelease = {
      version: cleanVer,
      tag,
      title: wk.app_name ? `${wk.app_name} — ${tag}` : `MUXIS ${tag}`,
      publishedAt: wk.release_date || '',
      htmlUrl: `${RELEASES_PAGE}/tag/${tag}`,
      body: changelogLines,
      sourceLabel: 'Via Cloudflare Edge Mirror',
      assets
    };

    renderReleaseIntoDOM();
  }

  function renderReleaseIntoDOM() {
    document.querySelectorAll('[data-release-tag]').forEach((el) => {
      el.textContent = currentRelease.tag;
    });
    document.querySelectorAll('[data-release-version]').forEach((el) => {
      el.textContent = currentRelease.version;
    });
    document.querySelectorAll('[data-release-title]').forEach((el) => {
      el.textContent = currentRelease.title;
    });
    document.querySelectorAll('[data-release-date]').forEach((el) => {
      el.textContent = `Published ${formatReleaseDate(currentRelease.publishedAt)}`;
    });
    document.querySelectorAll('[data-release-source]').forEach((el) => {
      el.textContent = currentRelease.sourceLabel;
    });
    document.querySelectorAll('[data-release-url]').forEach((el) => {
      el.href = currentRelease.htmlUrl;
    });

    Object.entries(currentRelease.assets).forEach(([key, asset]) => {
      document.querySelectorAll(`[data-asset-url="${key}"]`).forEach((el) => {
        el.href = asset.url;
      });
      document.querySelectorAll(`[data-asset-size="${key}"]`).forEach((el) => {
        const formatted = formatBytes(asset.size);
        if (formatted) el.textContent = formatted;
      });
      document.querySelectorAll(`[data-asset-name="${key}"]`).forEach((el) => {
        el.textContent = asset.name;
      });
    });

    renderChangelogNotes(currentRelease.body);
    applyPrimaryPlatformCTA(detectOS());
  }

  function renderChangelogNotes(markdownBody) {
    const lists = document.querySelectorAll('[data-release-notes]');
    if (!lists.length || !markdownBody) return;

    const lines = markdownBody
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => /^[-*]\s+/.test(line))
      .map((line) => line.replace(/^[-*]\s+/, ''))
      .slice(0, 6);

    if (!lines.length) return;

    lists.forEach((ul) => {
      ul.innerHTML = '';
      lines.forEach((rawText) => {
        const li = document.createElement('li');
        appendInlineCodeFragments(li, rawText);
        ul.appendChild(li);
      });
    });
  }

  function appendInlineCodeFragments(container, text) {
    const clean = text.replace(/\*\*/g, '');
    const parts = clean.split(/(`[^`]+`)/g);
    parts.forEach((part) => {
      if (part.startsWith('`') && part.endsWith('`') && part.length > 2) {
        const code = document.createElement('code');
        code.textContent = part.slice(1, -1);
        container.appendChild(code);
      } else {
        container.appendChild(document.createTextNode(part));
      }
    });
  }

  // Interactive 5-view App Showcase Stage
  function initShowcaseStage() {
    const tabs = Array.from(document.querySelectorAll('.stage-tab'));
    const slides = Array.from(document.querySelectorAll('.stage-slide'));
    const titleEl = document.getElementById('stage-caption-title');
    const descEl = document.getElementById('stage-caption-desc');
    const stageShell = document.querySelector('.showcase-shell');
    if (!tabs.length || !slides.length) return;

    let activeIndex = 0;
    let paused = false;

    const activate = (index) => {
      activeIndex = index;
      const selectedTab = tabs[index];
      const targetId = selectedTab.dataset.target;

      tabs.forEach((tab, idx) => {
        const isCurrent = idx === index;
        tab.classList.toggle('active', isCurrent);
        tab.setAttribute('aria-selected', String(isCurrent));
      });

      slides.forEach((slide) => {
        slide.classList.toggle('active', slide.dataset.slide === targetId);
      });

      if (titleEl && selectedTab.dataset.title) {
        titleEl.textContent = selectedTab.dataset.title;
      }
      if (descEl && selectedTab.dataset.desc) {
        descEl.textContent = selectedTab.dataset.desc;
      }
    };

    tabs.forEach((tab, idx) => {
      tab.addEventListener('click', () => {
        paused = true;
        activate(idx);
      });
    });

    if (stageShell) {
      stageShell.addEventListener('mouseenter', () => { paused = true; });
      stageShell.addEventListener('mouseleave', () => { paused = false; });
    }

    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (!reducedMotion) {
      setInterval(() => {
        if (!paused && !document.hidden) {
          activate((activeIndex + 1) % tabs.length);
        }
      }, 5200);
    }
  }

  // Smooth Prismatic Acoustic Harmonic Canvas in Hero
  function initSpectrumCanvas() {
    const canvas = document.getElementById('hero-spectrum-canvas');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    let width = 0;
    let height = 0;
    let phase = 0;
    let rafId = null;

    const resize = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const rect = canvas.getBoundingClientRect();
      width = rect.width || 900;
      height = rect.height || 54;
      canvas.width = width * dpr;
      canvas.height = height * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };

    resize();
    window.addEventListener('resize', resize, { passive: true });

    const draw = () => {
      ctx.clearRect(0, 0, width, height);
      const bars = Math.max(44, Math.floor(width / 15));
      const barWidth = Math.max(3, (width / bars) * 0.45);
      const gap = width / bars;

      const grad = ctx.createLinearGradient(0, 0, width, 0);
      grad.addColorStop(0, 'rgba(0, 255, 136, 0.85)');
      grad.addColorStop(0.42, 'rgba(0, 229, 255, 0.88)');
      grad.addColorStop(0.75, 'rgba(139, 92, 246, 0.85)');
      grad.addColorStop(1, 'rgba(236, 72, 153, 0.8)');

      ctx.fillStyle = grad;

      for (let i = 0; i < bars; i++) {
        const norm = i / bars;
        const envelope = Math.sin(norm * Math.PI);
        const wave =
          0.5 +
          0.32 * Math.sin(phase * 1.4 + i * 0.34) +
          0.18 * Math.cos(phase * 2.1 - i * 0.62);
        const barH = Math.max(4, Math.min(height - 6, wave * envelope * (height - 4)));
        const x = i * gap + (gap - barWidth) * 0.5;
        const y = (height - barH) * 0.5;

        ctx.beginPath();
        if (ctx.roundRect) {
          ctx.roundRect(x, y, barWidth, barH, barWidth / 2);
        } else {
          ctx.rect(x, y, barWidth, barH);
        }
        ctx.fill();
      }

      phase += 0.032;
      if (!reducedMotion && !document.hidden) {
        rafId = requestAnimationFrame(draw);
      }
    };

    draw();

    document.addEventListener('visibilitychange', () => {
      if (!document.hidden && !reducedMotion && rafId === null) {
        draw();
      } else if (document.hidden && rafId !== null) {
        cancelAnimationFrame(rafId);
        rafId = null;
      }
    });
  }

  function initMeterAnimation() {
    const bars = document.querySelectorAll('.meter-bar');
    if (!bars.length) return;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

    setInterval(() => {
      if (document.hidden) return;
      bars.forEach((bar) => {
        const h = Math.floor(Math.random() * 14) + 5;
        bar.style.height = `${h}px`;
      });
    }, 220);
  }
})();
