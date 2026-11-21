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
 * Fetches latest version from the Cloudflare Worker API
 */
async function initReleaseVersionFetch() {
  const versionTags = document.querySelectorAll('.dynamic-version-tag');
  if (!versionTags || versionTags.length === 0) return;

  try {
    const res = await fetch('/api/version');
    if (!res.ok) return;
    const data = await res.json();
    if (data && data.latest_version) {
      versionTags.forEach((el) => {
        el.textContent = `v${data.latest_version}`;
      });
    }
  } catch {
    // Graceful offline fallback: keeps hardcoded default version
  }
}
