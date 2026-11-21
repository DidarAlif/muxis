/**
 * MUXIS Website — Client Interactivity & Platform Detect
 */

document.addEventListener('DOMContentLoaded', () => {
  initPlatformDetection();
  initAudioVisualizerAnimation();
  initReleaseVersionFetch();
});

/**
 * Detect client OS and highlight the best download button
 */
function initPlatformDetection() {
  const userAgent = window.navigator.userAgent.toLowerCase();
  let detectedPlatform = 'windows';

  if (userAgent.includes('mac') || userAgent.includes('darwin')) {
    detectedPlatform = 'macos';
  } else if (userAgent.includes('linux')) {
    detectedPlatform = 'linux';
  } else if (userAgent.includes('android')) {
    detectedPlatform = 'android';
  } else if (userAgent.includes('iphone') || userAgent.includes('ipad')) {
    detectedPlatform = 'ios';
  }

  const primaryBtn = document.getElementById('primary-download-btn');
  if (primaryBtn) {
    const platformNames = {
      windows: 'Download for Windows x64',
      macos: 'Download for macOS',
      linux: 'Download for Linux',
      android: 'Download APK / Google Play',
      ios: 'Get on the App Store',
    };
    primaryBtn.textContent = platformNames[detectedPlatform] || 'Download MUXIS';
  }
}

/**
 * Animated Prismatic Wave visualizer on the player mockup
 */
function initAudioVisualizerAnimation() {
  const bars = document.querySelectorAll('.mini-bar');
  if (!bars || bars.length === 0) return;

  setInterval(() => {
    bars.forEach((bar) => {
      const randomHeight = Math.floor(Math.random() * 24) + 6;
      bar.style.height = `${randomHeight}px`;
    });
  }, 120);
}

/**
 * Fetches latest release version and assets directly from GitHub API
 */
async function initReleaseVersionFetch() {
  const heroBadge = document.getElementById('hero-version-badge');
  const releaseTitle = document.getElementById('release-version-title');
  const versionTags = document.querySelectorAll('.dynamic-version-tag');

  try {
    const res = await fetch('https://api.github.com/repos/DidarAlif/muxis/releases/latest');
    if (!res.ok) return;
    const data = await res.json();
    
    if (data && data.tag_name) {
      const versionTag = data.tag_name;
      
      if (heroBadge) {
        heroBadge.textContent = `PRISMATIC AURA AUDIO ${versionTag}`;
      }
      if (releaseTitle) {
        releaseTitle.textContent = `MUXIS ${versionTag} — Ad-Free YouTube Music & Spotify Streaming`;
      }
      versionTags.forEach((el) => {
        el.textContent = versionTag;
      });

      // Map dynamic asset download URLs if assets exist
      if (data.assets && Array.isArray(data.assets)) {
        data.assets.forEach((asset) => {
          const name = asset.name.toLowerCase();
          const downloadUrl = asset.browser_download_url;

          if (name.includes('windows') && name.endsWith('.zip')) {
            const btn = document.querySelector('a[href*="Windows-x64"]');
            if (btn) btn.href = downloadUrl;
          } else if (name.includes('macos') && name.endsWith('.zip')) {
            const btn = document.querySelector('a[href*="macOS-Universal"]');
            if (btn) btn.href = downloadUrl;
          } else if (name.includes('linux') && (name.endsWith('.tar.gz') || name.endsWith('.zip'))) {
            const btn = document.querySelector('a[href*="Linux-x64"]');
            if (btn) btn.href = downloadUrl;
          } else if (name.includes('android') && name.endsWith('.apk')) {
            const btn = document.querySelector('a[href*="Android.apk"]');
            if (btn) btn.href = downloadUrl;
          }
        });
      }
    }
  } catch {
    // Graceful offline fallback: keeps hardcoded default version
  }
}
