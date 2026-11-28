/**
 * MUXIS Streaming Platform Links & Sync Engine (YouTube Music, Spotify, SoundCloud).
 * Persists connected streaming hubs, playlists, liked songs & curated recommendations
 * per MUXIS Cloud user inside Cloudflare D1 and proxies SoundCloud/Spotify streams.
 */

import { CloudEnv, UserRow, isApprovalRequired, serializeUser, verifyJwt } from './cloud_auth';
import { StreamTrackDTO, extractResponsiveItems } from './stream_api';

export type StreamingPlatform = 'youtube' | 'spotify' | 'soundcloud';

export interface PlatformPlaylistDTO {
  id: string;
  title: string;
  description: string;
  artworkUrl: string | null;
  trackCount: number;
  tracks: StreamTrackDTO[];
}

export interface PlatformHubResponse {
  platform: StreamingPlatform;
  isConnected: boolean;
  displayName: string | null;
  avatarUrl: string | null;
  planBadge: string | null;
  authMode: string | null;
  playlists: PlatformPlaylistDTO[];
  likedTracks: StreamTrackDTO[];
  recommendedTracks: StreamTrackDTO[];
  updatedAt: string | null;
}

interface ConnectionRow {
  id: string;
  user_id: string;
  platform: StreamingPlatform;
  is_connected: number;
  display_name: string | null;
  avatar_url: string | null;
  plan_badge: string | null;
  credential_json: string | null;
  playlists_json: string;
  liked_tracks_json: string;
  recommended_tracks_json: string;
  updated_at: string;
}

interface StoredCredential {
  mode: string;
  profileUrl?: string;
  cookie?: string;
  sapisid?: string;
  accessToken?: string;
  clientId?: string;
  clientSecret?: string;
  oauthCode?: string;
  codeVerifier?: string;
  redirectUri?: string;
}

const BROWSER_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
const YT_MUSIC_ORIGIN = 'https://music.youtube.com';
const SC_API_V2 = 'https://api-v2.soundcloud.com';

const WEB_REMIX_CTX = {
  client: {
    clientName: 'WEB_REMIX',
    clientVersion: '1.20260114.03.00',
    hl: 'en',
    gl: 'US',
  },
};

let cachedScClientId: string | null = null;
let cachedScClientIdAt = 0;

function emptyHub(platform: StreamingPlatform): PlatformHubResponse {
  return {
    platform,
    isConnected: false,
    displayName: null,
    avatarUrl: null,
    planBadge: null,
    authMode: null,
    playlists: [],
    likedTracks: [],
    recommendedTracks: [],
    updatedAt: null,
  };
}

function safeJsonParse<T>(raw: string | null | undefined, fallback: T): T {
  if (!raw) return fallback;
  try {
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

function upgradeScArt(url?: string | null, fallback?: string | null): string | null {
  const chosen = (url && url.trim()) || (fallback && fallback.trim()) || '';
  if (!chosen) return null;
  return chosen.replace('-large.', '-t500x500.');
}

/**
 * Dynamically extracts a live SoundCloud web `client_id` from SoundCloud's public bundle scripts.
 */
export async function getSoundCloudClientId(forceRefresh = false): Promise<string | null> {
  if (!forceRefresh && cachedScClientId && Date.now() - cachedScClientIdAt < 1000 * 60 * 60 * 4) {
    return cachedScClientId;
  }
  try {
    const pageRes = await fetch('https://soundcloud.com', {
      headers: { 'User-Agent': BROWSER_UA },
      signal: AbortSignal.timeout(7000),
    });
    if (!pageRes.ok) return cachedScClientId;
    const html = await pageRes.text();
    const assetMatches = [...html.matchAll(/https:\/\/a-v2\.sndcdn\.com\/assets\/[^"'\s]+\.js/g)].map((m) => m[0]);
    for (const scriptUrl of assetMatches.reverse().slice(0, 8)) {
      try {
        const jsRes = await fetch(scriptUrl, {
          headers: { 'User-Agent': BROWSER_UA },
          signal: AbortSignal.timeout(6000),
        });
        if (!jsRes.ok) continue;
        const jsText = await jsRes.text();
        const match = jsText.match(/client_id\s*:\s*["']([a-zA-Z0-9]{20,40})["']/);
        if (match && match[1]) {
          cachedScClientId = match[1];
          cachedScClientIdAt = Date.now();
          return cachedScClientId;
        }
      } catch {}
    }
  } catch {}
  return cachedScClientId;
}

function normalizeScTrack(raw: unknown): StreamTrackDTO | null {
  if (!raw || typeof raw !== 'object') return null;
  const outer = raw as Record<string, unknown>;
  const m = (outer.track && typeof outer.track === 'object' ? outer.track : outer) as Record<string, unknown>;
  const id = m.id;
  const title = typeof m.title === 'string' ? m.title.trim() : '';
  if (!id || !title) return null;
  const user = (m.user && typeof m.user === 'object' ? m.user : {}) as Record<string, unknown>;
  const artist = typeof user.username === 'string' && user.username.trim() ? user.username.trim() : 'SoundCloud Artist';
  const art = upgradeScArt(m.artwork_url as string | undefined, user.avatar_url as string | undefined);
  const durMs = typeof m.duration === 'number' ? m.duration : 180000;
  const policy = typeof m.policy === 'string' ? m.policy.toUpperCase() : '';
  return {
    id: `sc-${id}`,
    title,
    artist,
    album: (typeof m.genre === 'string' && m.genre.trim()) || 'SoundCloud',
    durationSec: Math.max(15, Math.round(durMs / 1000)),
    artworkUrl: art,
    source: 'soundcloud',
    audioFormat: policy === 'SNIP' ? 'SoundCloud Preview' : 'SoundCloud Stream',
  };
}

function normalizeScPlaylist(raw: unknown): PlatformPlaylistDTO | null {
  if (!raw || typeof raw !== 'object') return null;
  const outer = raw as Record<string, unknown>;
  const m = (outer.playlist && typeof outer.playlist === 'object' ? outer.playlist : outer) as Record<string, unknown>;
  const id = m.id ? String(m.id) : '';
  const title = typeof m.title === 'string' ? m.title.trim() : '';
  if (!id || !title) return null;
  const rawTracks = Array.isArray(m.tracks) ? m.tracks : [];
  const tracks = rawTracks.map(normalizeScTrack).filter((t): t is StreamTrackDTO => Boolean(t));
  const user = (m.user && typeof m.user === 'object' ? m.user : {}) as Record<string, unknown>;
  const art = upgradeScArt(
    m.artwork_url as string | undefined,
    (tracks[0]?.artworkUrl ?? (user.avatar_url as string | undefined)) || null
  );
  return {
    id,
    title,
    description:
      (typeof m.description === 'string' && m.description.trim()) ||
      (typeof user.username === 'string' && user.username) ||
      'SoundCloud Set',
    artworkUrl: art,
    trackCount: typeof m.track_count === 'number' ? m.track_count : tracks.length,
    tracks,
  };
}

export async function searchSoundCloudTracks(query: string): Promise<StreamTrackDTO[]> {
  const cid = await getSoundCloudClientId();
  if (!cid || !query.trim()) return [];
  try {
    const res = await fetch(
      `${SC_API_V2}/search/tracks?q=${encodeURIComponent(query.trim())}&limit=20&client_id=${encodeURIComponent(cid)}`,
      {
        headers: {
          'User-Agent': BROWSER_UA,
          Origin: 'https://soundcloud.com',
          Referer: 'https://soundcloud.com/',
        },
        signal: AbortSignal.timeout(7000),
      }
    );
    if (!res.ok) return [];
    const data = (await res.json()) as { collection?: unknown[] };
    return (data.collection ?? []).map(normalizeScTrack).filter((t): t is StreamTrackDTO => Boolean(t));
  } catch {
    return [];
  }
}

export async function resolveSoundCloudStreamUrl(numericOrScId: string, oauthToken?: string): Promise<string | null> {
  const cleanId = numericOrScId.replace(/^sc-/, '').trim();
  if (!/^\d+$/.test(cleanId)) return null;
  const cid = await getSoundCloudClientId();
  if (!cid) return null;

  const scHeaders: Record<string, string> = {
    'User-Agent': BROWSER_UA,
    Origin: 'https://soundcloud.com',
    Referer: 'https://soundcloud.com/',
  };
  if (oauthToken) scHeaders.Authorization = `OAuth ${oauthToken}`;

  try {
    const trackRes = await fetch(`${SC_API_V2}/tracks/${cleanId}?client_id=${encodeURIComponent(cid)}`, {
      headers: scHeaders,
      signal: AbortSignal.timeout(7000),
    });
    if (!trackRes.ok) return null;
    const trackObj = (await trackRes.json()) as {
      policy?: string;
      media?: { transcodings?: Array<{ url?: string; format?: { protocol?: string } }> };
    };
    const trans = trackObj.media?.transcodings ?? [];
    const ordered = [
      ...trans.filter((t) => t.format?.protocol === 'progressive'),
      ...trans.filter((t) => t.format?.protocol !== 'progressive'),
    ];
    for (const item of ordered) {
      if (!item.url) continue;
      const sep = item.url.includes('?') ? '&' : '?';
      const urlRes = await fetch(`${item.url}${sep}client_id=${encodeURIComponent(cid)}`, {
        headers: scHeaders,
        signal: AbortSignal.timeout(6000),
      });
      if (!urlRes.ok) continue;
      const d = (await urlRes.json()) as { url?: string };
      if (d.url) return d.url;
    }
  } catch {}
  return null;
}

async function fetchScCharts(cid: string): Promise<StreamTrackDTO[]> {
  try {
    const res = await fetch(
      `${SC_API_V2}/charts?kind=top&genre=soundcloud%3Agenres%3Aall-music&limit=18&client_id=${encodeURIComponent(cid)}`,
      {
        headers: { 'User-Agent': BROWSER_UA, Origin: 'https://soundcloud.com', Referer: 'https://soundcloud.com/' },
        signal: AbortSignal.timeout(7000),
      }
    );
    if (!res.ok) return [];
    const data = (await res.json()) as { collection?: unknown[] };
    return (data.collection ?? []).map(normalizeScTrack).filter((t): t is StreamTrackDTO => Boolean(t));
  } catch {
    return [];
  }
}

async function connectSoundCloud(cred: StoredCredential): Promise<{
  displayName: string;
  avatarUrl: string | null;
  planBadge: string;
  playlists: PlatformPlaylistDTO[];
  likedTracks: StreamTrackDTO[];
  recommendedTracks: StreamTrackDTO[];
}> {
  const cid = await getSoundCloudClientId();
  if (!cid) throw new Error('Unable to initialize SoundCloud API gateway right now.');

  const headers: Record<string, string> = {
    'User-Agent': BROWSER_UA,
    Origin: 'https://soundcloud.com',
    Referer: 'https://soundcloud.com/',
  };

  if (cred.mode === 'oauth_token' && cred.accessToken) {
    const tok = cred.accessToken.trim().replace(/^OAuth\s+/i, '').replace(/^Bearer\s+/i, '');
    headers.Authorization = `OAuth ${tok}`;
    const meRes = await fetch(`${SC_API_V2}/me?client_id=${encodeURIComponent(cid)}`, {
      headers,
      signal: AbortSignal.timeout(7000),
    });
    if (!meRes.ok) throw new Error('SoundCloud OAuth token rejected (expired or invalid).');
    const me = (await meRes.json()) as { full_name?: string; username?: string; avatar_url?: string };
    const displayName = (me.full_name || me.username || '').trim();
    if (!displayName) throw new Error('Could not read SoundCloud profile.');

    const [plRes, likesRes, charts] = await Promise.all([
      fetch(`${SC_API_V2}/me/library/all?limit=30&client_id=${encodeURIComponent(cid)}`, { headers }).catch(() => null),
      fetch(`${SC_API_V2}/me/track_likes?limit=30&client_id=${encodeURIComponent(cid)}`, { headers }).catch(() => null),
      fetchScCharts(cid),
    ]);
    const playlists: PlatformPlaylistDTO[] = [];
    if (plRes?.ok) {
      const pd = (await plRes.json()) as { collection?: unknown[] };
      for (const item of pd.collection ?? []) {
        const pl = normalizeScPlaylist(item);
        if (pl) playlists.push(pl);
      }
    }
    const likedTracks: StreamTrackDTO[] = [];
    if (likesRes?.ok) {
      const ld = (await likesRes.json()) as { collection?: unknown[] };
      for (const item of ld.collection ?? []) {
        const tr = normalizeScTrack(item);
        if (tr) likedTracks.push(tr);
      }
    }
    return {
      displayName,
      avatarUrl: upgradeScArt(me.avatar_url),
      planBadge: 'OAuth Linked',
      playlists,
      likedTracks,
      recommendedTracks: charts.length ? charts : likedTracks.slice(0, 12),
    };
  }

  let rawUrl = (cred.profileUrl || '').trim();
  if (!rawUrl) throw new Error('Enter your SoundCloud profile URL, @handle, or playlist link.');
  if (!rawUrl.startsWith('http')) {
    rawUrl = `https://soundcloud.com/${rawUrl.replace(/^@/, '')}`;
  }
  const resolveRes = await fetch(
    `${SC_API_V2}/resolve?url=${encodeURIComponent(rawUrl)}&client_id=${encodeURIComponent(cid)}`,
    { headers, signal: AbortSignal.timeout(8000) }
  );
  if (!resolveRes.ok) {
    throw new Error('Could not find that SoundCloud profile or playlist URL. Check that it is public.');
  }
  const resolved = (await resolveRes.json()) as Record<string, unknown>;
  const kind = String(resolved.kind || '').toLowerCase();

  if (kind === 'user') {
    const uid = resolved.id;
    const displayName = String(resolved.full_name || resolved.username || 'SoundCloud Creator').trim();
    const avatarUrl = upgradeScArt(resolved.avatar_url as string | undefined);
    const [plRes, likesRes, tracksRes, charts] = await Promise.all([
      fetch(`${SC_API_V2}/users/${uid}/playlists?limit=24&client_id=${encodeURIComponent(cid)}`, { headers }).catch(() => null),
      fetch(`${SC_API_V2}/users/${uid}/likes?limit=24&client_id=${encodeURIComponent(cid)}`, { headers }).catch(() => null),
      fetch(`${SC_API_V2}/users/${uid}/tracks?limit=20&client_id=${encodeURIComponent(cid)}`, { headers }).catch(() => null),
      fetchScCharts(cid),
    ]);
    const playlists: PlatformPlaylistDTO[] = [];
    if (plRes?.ok) {
      const pd = (await plRes.json()) as { collection?: unknown[] };
      for (const item of pd.collection ?? []) {
        const pl = normalizeScPlaylist(item);
        if (pl) playlists.push(pl);
      }
    }
    const likedTracks: StreamTrackDTO[] = [];
    if (likesRes?.ok) {
      const ld = (await likesRes.json()) as { collection?: unknown[] };
      for (const item of ld.collection ?? []) {
        const tr = normalizeScTrack(item);
        if (tr) likedTracks.push(tr);
      }
    }
    let userTracks: StreamTrackDTO[] = [];
    if (tracksRes?.ok) {
      const td = (await tracksRes.json()) as { collection?: unknown[] };
      userTracks = (td.collection ?? []).map(normalizeScTrack).filter((t): t is StreamTrackDTO => Boolean(t));
    }
    if (!likedTracks.length && userTracks.length) likedTracks.push(...userTracks);
    return {
      displayName,
      avatarUrl,
      planBadge: 'Public Hub Sync',
      playlists,
      likedTracks,
      recommendedTracks: userTracks.length ? userTracks : charts,
    };
  }

  if (kind === 'playlist') {
    const pl = normalizeScPlaylist(resolved);
    if (!pl) throw new Error('SoundCloud playlist had no readable tracks.');
    const charts = await fetchScCharts(cid);
    return {
      displayName: pl.title,
      avatarUrl: pl.artworkUrl,
      planBadge: `${pl.trackCount} Tracks Set`,
      playlists: [pl],
      likedTracks: pl.tracks.slice(0, 25),
      recommendedTracks: charts,
    };
  }

  const single = normalizeScTrack(resolved);
  if (!single) throw new Error('Unsupported SoundCloud link type. Try a profile or set URL.');
  const charts = await fetchScCharts(cid);
  return {
    displayName: single.artist,
    avatarUrl: single.artworkUrl,
    planBadge: 'Track Linked',
    playlists: [],
    likedTracks: [single],
    recommendedTracks: [single, ...charts.slice(0, 12)],
  };
}

async function computeSapisidAuthHeader(cookieStr: string, explicitSapisid?: string): Promise<string | null> {
  let sap = (explicitSapisid || '').trim();
  if (!sap) {
    const match = cookieStr.match(/(?:__Secure-3PAPISID|SAPISID)=([^;\s]+)/i);
    if (match) sap = match[1];
  }
  if (!sap) return null;
  const ts = Math.floor(Date.now() / 1000);
  const digest = await crypto.subtle.digest('SHA-1', new TextEncoder().encode(`${ts} ${sap} ${YT_MUSIC_ORIGIN}`));
  const hex = Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
  return `SAPISIDHASH ${ts}_${hex}`;
}

function extractYtPlaylistsFromBrowse(data: unknown): PlatformPlaylistDTO[] {
  const out: PlatformPlaylistDTO[] = [];
  const seen = new Set<string>();
  function walk(node: unknown) {
    if (Array.isArray(node)) {
      node.forEach(walk);
      return;
    }
    if (!node || typeof node !== 'object') return;
    const obj = node as Record<string, unknown>;
    const twoRow = obj.musicTwoRowItemRenderer as Record<string, unknown> | undefined;
    if (twoRow) {
      const browseId =
        (((twoRow.navigationEndpoint as Record<string, unknown>)?.browseEndpoint as Record<string, unknown>)
          ?.browseId as string) || '';
      const runs = (((twoRow.title as Record<string, unknown>)?.runs as Array<{ text?: string }>) ?? []);
      const title = runs[0]?.text?.trim() || '';
      if (browseId && title && (browseId.startsWith('VL') || browseId.startsWith('PL') || browseId.startsWith('RD')) && !seen.has(browseId)) {
        seen.add(browseId);
        const subRuns = (((twoRow.subtitle as Record<string, unknown>)?.runs as Array<{ text?: string }>) ?? []);
        const sub = subRuns.map((r) => r.text ?? '').join('');
        const thumbs =
          (((twoRow.thumbnailRenderer as Record<string, unknown>)?.musicThumbnailRenderer as Record<string, unknown>)
            ?.thumbnail as Record<string, unknown>)?.thumbnails as Array<{ url?: string }> | undefined;
        out.push({
          id: browseId,
          title,
          description: sub || 'YouTube Music Playlist',
          artworkUrl: thumbs?.length ? thumbs[thumbs.length - 1].url ?? null : null,
          trackCount: 0,
          tracks: [],
        });
      }
    }
    for (const v of Object.values(obj)) {
      if (v && typeof v === 'object') walk(v);
    }
  }
  walk(data);
  return out;
}

async function connectYouTubeMusic(cred: StoredCredential): Promise<{
  displayName: string;
  avatarUrl: string | null;
  planBadge: string;
  playlists: PlatformPlaylistDTO[];
  likedTracks: StreamTrackDTO[];
  recommendedTracks: StreamTrackDTO[];
}> {
  const baseHeaders: Record<string, string> = {
    'Content-Type': 'application/json',
    Origin: YT_MUSIC_ORIGIN,
    Referer: `${YT_MUSIC_ORIGIN}/`,
    'User-Agent': BROWSER_UA,
  };

  if (cred.mode === 'cookie' && cred.cookie) {
    const cookieHeader = cred.cookie.trim();
    const auth = await computeSapisidAuthHeader(cookieHeader, cred.sapisid);
    if (!auth) throw new Error('Missing SAPISID / __Secure-3PAPISID value in pasted YouTube cookie.');
    const headers = { ...baseHeaders, Cookie: cookieHeader, Authorization: auth };

    const [acctRes, plRes, likedRes, chartsRes] = await Promise.all([
      fetch(`${YT_MUSIC_ORIGIN}/youtubei/v1/account/account_menu`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ context: WEB_REMIX_CTX }),
      }).catch(() => null),
      fetch(`${YT_MUSIC_ORIGIN}/youtubei/v1/browse`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ context: WEB_REMIX_CTX, browseId: 'FEmusic_liked_playlists' }),
      }).catch(() => null),
      fetch(`${YT_MUSIC_ORIGIN}/youtubei/v1/browse`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ context: WEB_REMIX_CTX, browseId: 'FEmusic_liked_videos' }),
      }).catch(() => null),
      fetch(`${YT_MUSIC_ORIGIN}/youtubei/v1/browse`, {
        method: 'POST',
        headers: baseHeaders,
        body: JSON.stringify({ context: WEB_REMIX_CTX, browseId: 'FEmusic_charts' }),
      }).catch(() => null),
    ]);

    let displayName = '';
    let avatarUrl: string | null = null;
    if (acctRes?.ok) {
      const aJson = JSON.stringify(await acctRes.json());
      const nameMatch = aJson.match(/"accountName":\{"runs":\[\{"text":"([^"]+)"/);
      const imgMatch = aJson.match(/"accountPhoto":\{"thumbnails":\[\{"url":"([^"]+)"/);
      if (nameMatch) displayName = nameMatch[1];
      if (imgMatch) avatarUrl = imgMatch[1];
    }
    const playlists = plRes?.ok ? extractYtPlaylistsFromBrowse(await plRes.json()) : [];
    const likedTracks = likedRes?.ok ? extractResponsiveItems(await likedRes.json()).slice(0, 30) : [];
    const recommendedTracks = chartsRes?.ok ? extractResponsiveItems(await chartsRes.json()).slice(0, 20) : [];
    if (!displayName && !playlists.length && !likedTracks.length) {
      throw new Error('Could not verify YouTube session cookies (cookies may be expired or logged out).');
    }
    return {
      displayName: displayName || 'YouTube Music Account',
      avatarUrl,
      planBadge: 'Session Linked',
      playlists,
      likedTracks,
      recommendedTracks,
    };
  }

  const raw = (cred.profileUrl || '').trim();
  if (!raw) throw new Error('Paste a YouTube Music playlist URL (list=...) or channel URL / @handle.');
  let browseId = '';
  let listId = '';
  try {
    const u = new URL(raw.startsWith('http') ? raw : `https://music.youtube.com/${raw}`);
    listId = u.searchParams.get('list') || '';
    const chMatch = u.pathname.match(/\/channel\/(UC[a-zA-Z0-9_-]+)/);
    const plMatch = u.pathname.match(/\/browse\/([a-zA-Z0-9_-]+)/);
    if (listId) browseId = listId.startsWith('VL') ? listId : `VL${listId}`;
    else if (chMatch) browseId = chMatch[1];
    else if (plMatch) browseId = plMatch[1];
  } catch {
    if (/^(PL|VL|RD|OLAK|UU)[a-zA-Z0-9_-]+$/.test(raw)) {
      listId = raw;
      browseId = raw.startsWith('VL') ? raw : `VL${raw}`;
    } else if (/^UC[a-zA-Z0-9_-]+$/.test(raw)) {
      browseId = raw;
    }
  }

  if (!browseId) {
    // Attempt @handle lookup via YT search
    const cleanQ = raw.replace(/^https?:\/\/[^/]+\//, '').replace(/^@/, '').trim();
    if (!cleanQ) throw new Error('Enter a valid YouTube Music playlist URL, channel ID, or search handle.');
    const [searchRes, chartsRes] = await Promise.all([
      fetch(`${YT_MUSIC_ORIGIN}/youtubei/v1/search`, {
        method: 'POST',
        headers: baseHeaders,
        body: JSON.stringify({ context: WEB_REMIX_CTX, query: cleanQ }),
      }).catch(() => null),
      fetch(`${YT_MUSIC_ORIGIN}/youtubei/v1/browse`, {
        method: 'POST',
        headers: baseHeaders,
        body: JSON.stringify({ context: WEB_REMIX_CTX, browseId: 'FEmusic_charts' }),
      }).catch(() => null),
    ]);
    const searchTracks = searchRes?.ok ? extractResponsiveItems(await searchRes.json()).slice(0, 20) : [];
    const chartTracks = chartsRes?.ok ? extractResponsiveItems(await chartsRes.json()).slice(0, 20) : [];
    if (!searchTracks.length) throw new Error('No YouTube Music tracks matched that link or query.');
    return {
      displayName: cleanQ,
      avatarUrl: searchTracks[0]?.artworkUrl ?? null,
      planBadge: 'YT Hub Linked',
      playlists: [
        {
          id: `yt-custom-${cleanQ.toLowerCase().replace(/[^a-z0-9]/g, '-')}`,
          title: `${cleanQ} Mix`,
          description: 'YouTube Music Curated Link',
          artworkUrl: searchTracks[0]?.artworkUrl ?? null,
          trackCount: searchTracks.length,
          tracks: searchTracks,
        },
      ],
      likedTracks: searchTracks,
      recommendedTracks: chartTracks,
    };
  }

  const [browseRes, chartsRes] = await Promise.all([
    fetch(`${YT_MUSIC_ORIGIN}/youtubei/v1/browse`, {
      method: 'POST',
      headers: baseHeaders,
      body: JSON.stringify({ context: WEB_REMIX_CTX, browseId }),
      signal: AbortSignal.timeout(8000),
    }).catch(() => null),
    fetch(`${YT_MUSIC_ORIGIN}/youtubei/v1/browse`, {
      method: 'POST',
      headers: baseHeaders,
      body: JSON.stringify({ context: WEB_REMIX_CTX, browseId: 'FEmusic_charts' }),
      signal: AbortSignal.timeout(7000),
    }).catch(() => null),
  ]);

  if (!browseRes?.ok) throw new Error('Could not load that YouTube Music playlist/channel (ensure it is public or unlisted).');
  const bData = (await browseRes.json()) as Record<string, unknown>;
  const tracks = extractResponsiveItems(bData).slice(0, 35);
  const subPlaylists = extractYtPlaylistsFromBrowse(bData);
  const charts = chartsRes?.ok ? extractResponsiveItems(await chartsRes.json()).slice(0, 20) : [];
  const rawStr = JSON.stringify(bData);
  const titleMatch = rawStr.match(/"header":\{[^{}]*"title":\{"runs":\[\{"text":"([^"]+)"/);
  const hubTitle = titleMatch ? titleMatch[1] : listId ? 'YouTube Music Playlist' : 'YouTube Music Channel';
  const cover = tracks[0]?.artworkUrl ?? subPlaylists[0]?.artworkUrl ?? null;

  const playlists: PlatformPlaylistDTO[] = tracks.length
    ? [
        {
          id: browseId,
          title: hubTitle,
          description: 'Synced from YouTube Music',
          artworkUrl: cover,
          trackCount: tracks.length,
          tracks,
        },
        ...subPlaylists,
      ]
    : subPlaylists;

  if (!tracks.length && !playlists.length) {
    throw new Error('YouTube playlist/channel contains no playable music tracks.');
  }

  return {
    displayName: hubTitle,
    avatarUrl: cover,
    planBadge: `${tracks.length} Tracks Linked`,
    playlists,
    likedTracks: tracks,
    recommendedTracks: charts.length ? charts : tracks.slice(0, 15),
  };
}

async function fetchSpotifyTokenFromClientCreds(clientId: string, clientSecret: string): Promise<string> {
  const basic = btoa(`${clientId.trim()}:${clientSecret.trim()}`);
  const res = await fetch('https://accounts.spotify.com/api/token', {
    method: 'POST',
    headers: {
      Authorization: `Basic ${basic}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'grant_type=client_credentials',
    signal: AbortSignal.timeout(7000),
  });
  if (!res.ok) throw new Error('Spotify Client ID or Client Secret rejected by Spotify Accounts.');
  const d = (await res.json()) as { access_token?: string };
  if (!d.access_token) throw new Error('Spotify did not issue an access token.');
  return d.access_token;
}

function mapSpotifyTrackObj(raw: unknown): StreamTrackDTO | null {
  if (!raw || typeof raw !== 'object') return null;
  const r = raw as Record<string, unknown>;
  const tr = (r.track && typeof r.track === 'object' ? r.track : r) as Record<string, unknown>;
  const id = typeof tr.id === 'string' ? tr.id : '';
  const name = typeof tr.name === 'string' ? tr.name.trim() : '';
  if (!name) return null;
  const artistsArr = Array.isArray(tr.artists) ? (tr.artists as Array<{ name?: string }>) : [];
  const artist = artistsArr.map((a) => a.name).filter(Boolean).join(', ') || 'Spotify Artist';
  const albumObj = (tr.album && typeof tr.album === 'object' ? tr.album : {}) as {
    name?: string;
    images?: Array<{ url?: string }>;
  };
  const artwork = albumObj.images?.[0]?.url ?? null;
  const durMs = typeof tr.duration_ms === 'number' ? tr.duration_ms : 200000;
  const preview = typeof tr.preview_url === 'string' ? tr.preview_url : undefined;
  return {
    id: id ? `sp-${id}` : `sp-${btoa(encodeURIComponent(`${name}-${artist}`)).slice(0, 14)}`,
    title: name,
    artist,
    album: albumObj.name || 'Spotify',
    durationSec: Math.max(15, Math.round(durMs / 1000)),
    artworkUrl: artwork,
    source: 'spotify',
    audioFormat: preview ? 'Spotify Preview / Bridge' : 'Spotify Audio Bridge',
    streamUrl: preview,
  };
}

async function scrapeSpotifyPublicUrl(rawUrl: string): Promise<{
  displayName: string;
  avatarUrl: string | null;
  playlists: PlatformPlaylistDTO[];
  tracks: StreamTrackDTO[];
}> {
  const match = rawUrl.match(/open\.spotify\.com\/(playlist|album|artist|track)\/([a-zA-Z0-9]+)/i);
  if (!match) {
    throw new Error('Paste a valid Spotify Playlist, Album, Artist, or Track link (open.spotify.com/...).');
  }
  const kind = match[1].toLowerCase();
  const id = match[2];
  const embedRes = await fetch(`https://open.spotify.com/embed/${kind}/${id}`, {
    headers: { 'User-Agent': BROWSER_UA },
    signal: AbortSignal.timeout(8000),
  });
  if (!embedRes.ok) {
    throw new Error('Could not reach Spotify for that link (make sure the playlist is Public).');
  }
  const html = await embedRes.text();
  const nextDataMatch = html.match(/<script id="__NEXT_DATA__" type="application\/json">([\s\S]*?)<\/script>/);
  if (!nextDataMatch) {
    throw new Error('Unable to read public Spotify metadata (try linking via Spotify Access Token or Client ID).');
  }
  const nextJson = JSON.parse(nextDataMatch[1]) as {
    props?: {
      pageProps?: {
        state?: {
          data?: {
            entity?: {
              name?: string;
              title?: string;
              subtitle?: string;
              coverArt?: { sources?: Array<{ url?: string }> };
              trackList?: Array<{
                uri?: string;
                title?: string;
                subtitle?: string;
                duration?: number;
                audioPreview?: { url?: string };
              }>;
            };
          };
        };
      };
    };
  };
  const entity = nextJson.props?.pageProps?.state?.data?.entity;
  if (!entity) throw new Error('Spotify link did not contain public track metadata.');
  const title = (entity.title || entity.name || `Spotify ${kind}`).trim();
  const cover = entity.coverArt?.sources?.[0]?.url ?? null;
  const trackList = entity.trackList ?? [];
  const tracks: StreamTrackDTO[] = trackList
    .filter((t) => t.title)
    .map((t, idx) => ({
      id: `sp-${(t.uri || `${id}-${idx}`).split(':').pop()}`,
      title: t.title!,
      artist: t.subtitle || entity.subtitle || 'Spotify Artist',
      album: title,
      durationSec: t.duration ? Math.max(15, Math.round(t.duration / 1000)) : 200,
      artworkUrl: cover,
      source: 'spotify',
      audioFormat: t.audioPreview?.url ? 'Spotify Preview / Bridge' : 'Spotify Audio Bridge',
      streamUrl: t.audioPreview?.url || undefined,
    }));

  if (!tracks.length) throw new Error('No readable tracks found in that public Spotify link.');

  return {
    displayName: title,
    avatarUrl: cover,
    playlists: [
      {
        id,
        title,
        description: entity.subtitle || 'Imported from Spotify',
        artworkUrl: cover,
        trackCount: tracks.length,
        tracks,
      },
    ],
    tracks,
  };
}

async function connectSpotify(cred: StoredCredential): Promise<{
  displayName: string;
  avatarUrl: string | null;
  planBadge: string;
  playlists: PlatformPlaylistDTO[];
  likedTracks: StreamTrackDTO[];
  recommendedTracks: StreamTrackDTO[];
}> {
  if (cred.mode === 'profile_url' && cred.profileUrl) {
    const pub = await scrapeSpotifyPublicUrl(cred.profileUrl);
    return {
      displayName: pub.displayName,
      avatarUrl: pub.avatarUrl,
      planBadge: 'Public Playlist Bridge',
      playlists: pub.playlists,
      likedTracks: pub.tracks,
      recommendedTracks: pub.tracks.slice(0, 16),
    };
  }

  let token = (cred.accessToken || '').trim().replace(/^Bearer\s+/i, '');
  let planBadge = 'Spotify Linked';
  let displayName = 'Spotify Account';
  let avatarUrl: string | null = null;
  const playlists: PlatformPlaylistDTO[] = [];
  let likedTracks: StreamTrackDTO[] = [];

  if (!token && cred.clientId && cred.oauthCode && cred.codeVerifier && cred.redirectUri) {
    const pkceRes = await fetch('https://accounts.spotify.com/api/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: cred.clientId.trim(),
        grant_type: 'authorization_code',
        code: cred.oauthCode.trim(),
        redirect_uri: cred.redirectUri.trim(),
        code_verifier: cred.codeVerifier.trim(),
      }).toString(),
      signal: AbortSignal.timeout(7000),
    });
    if (!pkceRes.ok) throw new Error('Spotify OAuth PKCE code exchange failed.');
    const pd = (await pkceRes.json()) as { access_token?: string };
    if (!pd.access_token) throw new Error('Spotify did not return an access token.');
    token = pd.access_token;
    cred.accessToken = token;
    delete cred.oauthCode;
    delete cred.codeVerifier;
    planBadge = 'Spotify OAuth';
  } else if (!token && cred.clientId && cred.clientSecret) {
    token = await fetchSpotifyTokenFromClientCreds(cred.clientId, cred.clientSecret);
    planBadge = 'Spotify App Bridge';
  }
  if (!token) {
    throw new Error('Provide a public Spotify Playlist URL, Spotify Access Token, or Client ID + Client Secret.');
  }

  const spHeaders = { Authorization: `Bearer ${token}` };
  const meRes = await fetch('https://api.spotify.com/v1/me', { headers: spHeaders, signal: AbortSignal.timeout(7000) }).catch(() => null);
  if (meRes?.ok) {
    const me = (await meRes.json()) as {
      display_name?: string;
      product?: string;
      images?: Array<{ url?: string }>;
    };
    displayName = me.display_name || 'Spotify User';
    avatarUrl = me.images?.[0]?.url ?? null;
    if (me.product) planBadge = `Spotify ${me.product.toUpperCase()}`;

    const [plRes, likesRes] = await Promise.all([
      fetch('https://api.spotify.com/v1/me/playlists?limit=25', { headers: spHeaders }).catch(() => null),
      fetch('https://api.spotify.com/v1/me/tracks?limit=30', { headers: spHeaders }).catch(() => null),
    ]);
    if (plRes?.ok) {
      const pd = (await plRes.json()) as {
        items?: Array<{
          id?: string;
          name?: string;
          description?: string;
          images?: Array<{ url?: string }>;
          tracks?: { total?: number };
        }>;
      };
      for (const item of pd.items ?? []) {
        if (!item.id || !item.name) continue;
        playlists.push({
          id: item.id,
          title: item.name,
          description: item.description || 'Spotify Playlist',
          artworkUrl: item.images?.[0]?.url ?? null,
          trackCount: item.tracks?.total ?? 0,
          tracks: [],
        });
      }
      // Hydrate tracks for first 2 playlists so immediate playback works smoothly
      for (const pl of playlists.slice(0, 2)) {
        const ptRes = await fetch(`https://api.spotify.com/v1/playlists/${encodeURIComponent(pl.id)}/tracks?limit=30`, {
          headers: spHeaders,
        }).catch(() => null);
        if (ptRes?.ok) {
          const pt = (await ptRes.json()) as { items?: unknown[] };
          pl.tracks = (pt.items ?? []).map(mapSpotifyTrackObj).filter((t): t is StreamTrackDTO => Boolean(t));
        }
      }
    }
    if (likesRes?.ok) {
      const ld = (await likesRes.json()) as { items?: unknown[] };
      likedTracks = (ld.items ?? []).map(mapSpotifyTrackObj).filter((t): t is StreamTrackDTO => Boolean(t));
    }
  } else {
    // Client-credentials token: verify via public Spotify browse/search API
    const searchRes = await fetch('https://api.spotify.com/v1/search?q=electronic%20chill&type=track&limit=18', {
      headers: spHeaders,
      signal: AbortSignal.timeout(7000),
    });
    if (!searchRes.ok) throw new Error('Spotify token rejected or expired. Generate a fresh token or use a Public Playlist link.');
    const sd = (await searchRes.json()) as { tracks?: { items?: unknown[] } };
    likedTracks = (sd.tracks?.items ?? []).map(mapSpotifyTrackObj).filter((t): t is StreamTrackDTO => Boolean(t));
    displayName = 'Spotify Catalog Bridge';
    if (cred.profileUrl) {
      try {
        const pub = await scrapeSpotifyPublicUrl(cred.profileUrl);
        playlists.push(...pub.playlists);
      } catch {}
    }
  }

  return {
    displayName,
    avatarUrl: avatarUrl || likedTracks[0]?.artworkUrl || playlists[0]?.artworkUrl || null,
    planBadge,
    playlists,
    likedTracks,
    recommendedTracks: playlists[0]?.tracks?.length ? playlists[0].tracks.slice(0, 16) : likedTracks.slice(0, 16),
  };
}

function rowToHub(row: ConnectionRow): PlatformHubResponse {
  const cred = safeJsonParse<StoredCredential | null>(row.credential_json, null);
  return {
    platform: row.platform,
    isConnected: Number(row.is_connected) === 1,
    displayName: row.display_name,
    avatarUrl: row.avatar_url,
    planBadge: row.plan_badge,
    authMode: cred?.mode ?? null,
    playlists: safeJsonParse<PlatformPlaylistDTO[]>(row.playlists_json, []),
    likedTracks: safeJsonParse<StreamTrackDTO[]>(row.liked_tracks_json, []),
    recommendedTracks: safeJsonParse<StreamTrackDTO[]>(row.recommended_tracks_json, []),
    updatedAt: row.updated_at,
  };
}

export async function handlePlatformLinksRoute(
  request: Request,
  env: CloudEnv,
  json: (data: unknown, status?: number) => Response,
  err: (msg: string, status?: number) => Response
): Promise<Response | null> {
  const url = new URL(request.url);
  const path = url.pathname;

  if (!path.startsWith('/api/stream/links')) {
    return null;
  }

  const db = env.DB;
  const jwtSecret = env.MUXIS_JWT_SECRET;
  if (!db || !jwtSecret) {
    return err('Cloudflare D1 database or JWT secret not configured.', 503);
  }

  const authHeader = request.headers.get('Authorization') ?? '';
  const bearer = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '';
  const payload = bearer ? await verifyJwt(bearer, jwtSecret) : null;
  const userId = typeof payload?.sub === 'string' ? payload.sub : null;
  if (!userId) {
    return err('Sign in to MUXIS Cloud before linking streaming platforms.', 401);
  }

  if ((request.headers.get('X-Muxis-Client') ?? '').toLowerCase() === 'pwa') {
    const needApproval = await isApprovalRequired(db);
    if (needApproval) {
      const userRow = await db.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first<UserRow>();
      if (!userRow) return err('User account not found.', 404);
      const s = serializeUser(userRow, env);
      if (!s.is_admin && s.pwa_approval_status !== 'approved') {
        return json({ error: 'Your PWA account is awaiting admin approval.', code: 'PWA_APPROVAL_REQUIRED' }, 403);
      }
    }
  }

  // 1. GET all connected streaming platforms for the signed-in user
  if (path === '/api/stream/links' && request.method === 'GET') {
    const rows = await db
      .prepare('SELECT * FROM streaming_connections WHERE user_id = ? AND is_connected = 1')
      .bind(userId)
      .all<ConnectionRow>();

    const out: Record<StreamingPlatform, PlatformHubResponse> = {
      youtube: emptyHub('youtube'),
      spotify: emptyHub('spotify'),
      soundcloud: emptyHub('soundcloud'),
    };
    for (const r of rows.results ?? []) {
      out[r.platform] = rowToHub(r);
    }
    return json({ links: out }, 200);
  }

  // 2. POST connect or update a streaming platform & persist synced data into D1
  if (path === '/api/stream/links/connect' && request.method === 'POST') {
    let body: {
      platform?: StreamingPlatform;
      mode?: string;
      profileUrl?: string;
      cookie?: string;
      sapisid?: string;
      accessToken?: string;
      clientId?: string;
      clientSecret?: string;
      oauthCode?: string;
      codeVerifier?: string;
      redirectUri?: string;
    };
    try {
      body = await request.json();
    } catch {
      return err('Invalid JSON connection payload.', 400);
    }

    const platform = body.platform;
    if (platform !== 'youtube' && platform !== 'spotify' && platform !== 'soundcloud') {
      return err('Unsupported platform. Expected youtube, spotify, or soundcloud.', 400);
    }

    const cred: StoredCredential = {
      mode: body.mode || 'profile_url',
      profileUrl: body.profileUrl?.trim(),
      cookie: body.cookie?.trim(),
      sapisid: body.sapisid?.trim(),
      accessToken: body.accessToken?.trim(),
      clientId: body.clientId?.trim(),
      clientSecret: body.clientSecret?.trim(),
      oauthCode: body.oauthCode?.trim(),
      codeVerifier: body.codeVerifier?.trim(),
      redirectUri: body.redirectUri?.trim(),
    };

    try {
      const result =
        platform === 'soundcloud'
          ? await connectSoundCloud(cred)
          : platform === 'youtube'
            ? await connectYouTubeMusic(cred)
            : await connectSpotify(cred);

      const now = new Date().toISOString();
      await db
        .prepare(
          `INSERT INTO streaming_connections
             (id, user_id, platform, is_connected, display_name, avatar_url, plan_badge, credential_json, playlists_json, liked_tracks_json, recommended_tracks_json, updated_at)
           VALUES (?, ?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?)
           ON CONFLICT(user_id, platform) DO UPDATE SET
             is_connected = 1,
             display_name = excluded.display_name,
             avatar_url = excluded.avatar_url,
             plan_badge = excluded.plan_badge,
             credential_json = excluded.credential_json,
             playlists_json = excluded.playlists_json,
             liked_tracks_json = excluded.liked_tracks_json,
             recommended_tracks_json = excluded.recommended_tracks_json,
             updated_at = excluded.updated_at`
        )
        .bind(
          crypto.randomUUID(),
          userId,
          platform,
          result.displayName,
          result.avatarUrl,
          result.planBadge,
          JSON.stringify(cred),
          JSON.stringify(result.playlists),
          JSON.stringify(result.likedTracks),
          JSON.stringify(result.recommendedTracks),
          now
        )
        .run();

      const saved = await db
        .prepare('SELECT * FROM streaming_connections WHERE user_id = ? AND platform = ?')
        .bind(userId, platform)
        .first<ConnectionRow>();

      return json({ ok: true, connection: saved ? rowToHub(saved) : emptyHub(platform) }, 200);
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : `Failed to connect ${platform}.`;
      return err(msg, 400);
    }
  }

  // 3. POST re-sync an already-connected platform using its stored D1 credentials
  if (path === '/api/stream/links/sync' && request.method === 'POST') {
    let body: { platform?: StreamingPlatform };
    try {
      body = await request.json();
    } catch {
      return err('Invalid JSON payload.', 400);
    }
    const platform = body.platform;
    if (platform !== 'youtube' && platform !== 'spotify' && platform !== 'soundcloud') {
      return err('Invalid platform.', 400);
    }
    const row = await db
      .prepare('SELECT * FROM streaming_connections WHERE user_id = ? AND platform = ? AND is_connected = 1')
      .bind(userId, platform)
      .first<ConnectionRow>();
    if (!row) return err(`${platform} is not connected yet.`, 404);
    const cred = safeJsonParse<StoredCredential | null>(row.credential_json, null);
    if (!cred) return err(`Missing stored credentials for ${platform}. Please reconnect.`, 400);

    try {
      const result =
        platform === 'soundcloud'
          ? await connectSoundCloud(cred)
          : platform === 'youtube'
            ? await connectYouTubeMusic(cred)
            : await connectSpotify(cred);
      const now = new Date().toISOString();
      await db
        .prepare(
          `UPDATE streaming_connections
           SET display_name = ?, avatar_url = ?, plan_badge = ?, playlists_json = ?, liked_tracks_json = ?, recommended_tracks_json = ?, updated_at = ?
           WHERE user_id = ? AND platform = ?`
        )
        .bind(
          result.displayName,
          result.avatarUrl,
          result.planBadge,
          JSON.stringify(result.playlists),
          JSON.stringify(result.likedTracks),
          JSON.stringify(result.recommendedTracks),
          now,
          userId,
          platform
        )
        .run();
      const fresh = await db
        .prepare('SELECT * FROM streaming_connections WHERE user_id = ? AND platform = ?')
        .bind(userId, platform)
        .first<ConnectionRow>();
      return json({ ok: true, connection: fresh ? rowToHub(fresh) : emptyHub(platform) }, 200);
    } catch (e: unknown) {
      return err(e instanceof Error ? e.message : `Sync failed for ${platform}.`, 400);
    }
  }

  // 4. POST disconnect a streaming platform cleanly
  if (path === '/api/stream/links/disconnect' && request.method === 'POST') {
    let body: { platform?: StreamingPlatform };
    try {
      body = await request.json();
    } catch {
      return err('Invalid JSON payload.', 400);
    }
    if (body.platform !== 'youtube' && body.platform !== 'spotify' && body.platform !== 'soundcloud') {
      return err('Invalid platform.', 400);
    }
    await db
      .prepare('DELETE FROM streaming_connections WHERE user_id = ? AND platform = ?')
      .bind(userId, body.platform)
      .run();
    return json({ ok: true, platform: body.platform }, 200);
  }

  return err('Unsupported streaming link route.', 404);
}
