/**
 * MUXIS Cloudflare Worker Streaming, InnerTube Search & Lyrics Relay Module.
 * Bridges YouTube Music search/charts, Piped/Invidious/InnerTube audio URL resolution,
 * byte-range streaming proxy for iOS Safari, and LRCLIB synced lyrics lookup.
 */

export interface StreamTrackDTO {
  id: string;
  title: string;
  artist: string;
  album: string;
  durationSec: number;
  artworkUrl: string | null;
  source: 'youtube' | 'audius' | 'publicDomain';
  audioFormat: string;
  streamUrl?: string;
}

const YT_MUSIC_ORIGIN = 'https://music.youtube.com';
const YT_SEARCH_URL = 'https://music.youtube.com/youtubei/v1/search';
const YT_BROWSE_URL = 'https://music.youtube.com/youtubei/v1/browse';
const YT_PLAYER_URL = 'https://www.youtube.com/youtubei/v1/player';

const WEB_REMIX_CTX = {
  client: {
    clientName: 'WEB_REMIX',
    clientVersion: '1.20260114.03.00',
    hl: 'en',
    gl: 'US',
  },
};

function parseDurSec(raw?: string): number {
  if (!raw) return 210;
  const parts = raw.split(':').map((n) => parseInt(n, 10));
  if (parts.some(Number.isNaN)) return 210;
  if (parts.length === 2) return parts[0] * 60 + parts[1];
  if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  return 210;
}

function extractThumb(thumbObj: unknown): string | null {
  if (!thumbObj || typeof thumbObj !== 'object') return null;
  const t = thumbObj as Record<string, unknown>;
  const list =
    ((t.musicThumbnailRenderer as Record<string, unknown>)?.thumbnail as Record<string, unknown>)?.thumbnails ??
    ((t.croppedSquareThumbnailRenderer as Record<string, unknown>)?.thumbnail as Record<string, unknown>)?.thumbnails ??
    t.thumbnails;
  if (!Array.isArray(list) || list.length === 0) return null;
  const last = list[list.length - 1] as Record<string, unknown> | undefined;
  return typeof last?.url === 'string' ? last.url : null;
}

function extractResponsiveItems(data: unknown): StreamTrackDTO[] {
  const results: StreamTrackDTO[] = [];
  const seen = new Set<string>();

  function walk(node: unknown) {
    if (Array.isArray(node)) {
      node.forEach(walk);
      return;
    }
    if (!node || typeof node !== 'object') return;
    const obj = node as Record<string, unknown>;
    const r = obj.musicResponsiveListItemRenderer as Record<string, unknown> | undefined;
    if (r && Array.isArray(r.flexColumns)) {
      try {
        const col0 = ((r.flexColumns[0] as Record<string, unknown>)
          ?.musicResponsiveListItemFlexColumnRenderer as Record<string, unknown>)
          ?.text as Record<string, unknown>;
        const runs0 = Array.isArray(col0?.runs) ? (col0.runs as Array<Record<string, unknown>>) : [];
        const title = typeof runs0[0]?.text === 'string' ? runs0[0].text : '';
        const nav0 = runs0[0]?.navigationEndpoint as Record<string, unknown> | undefined;
        const vid =
          ((nav0?.watchEndpoint as Record<string, unknown>)?.videoId as string) ||
          ((r.playlistItemData as Record<string, unknown>)?.videoId as string) ||
          ((((((r.overlay as Record<string, unknown>)?.musicItemThumbnailOverlayRenderer as Record<string, unknown>)
            ?.content as Record<string, unknown>)?.musicPlayButtonRenderer as Record<string, unknown>)
            ?.playNavigationEndpoint as Record<string, unknown>)?.watchEndpoint as Record<string, unknown>)?.videoId as string;

        if (vid && title && !seen.has(vid)) {
          seen.add(vid);
          let artist = 'YouTube Music';
          let album = 'Single';
          let durSec = 210;
          if (r.flexColumns.length > 1) {
            const col1 = ((r.flexColumns[1] as Record<string, unknown>)
              ?.musicResponsiveListItemFlexColumnRenderer as Record<string, unknown>)
              ?.text as Record<string, unknown>;
            const runs1 = Array.isArray(col1?.runs) ? (col1.runs as Array<Record<string, unknown>>) : [];
            const tokens = runs1
              .map((x) => (typeof x.text === 'string' ? x.text.trim() : ''))
              .filter((t) => t && !['•', '·', 'song', 'video', 'ep', 'single', 'album'].includes(t.toLowerCase()));
            if (tokens.length > 0 && /^\d+:\d{2}(:\d{2})?$/.test(tokens[tokens.length - 1])) {
              durSec = parseDurSec(tokens.pop());
            }
            if (tokens.length > 0) artist = tokens[0];
            if (tokens.length > 1) album = tokens[1];
          }
          results.push({
            id: `yt-${vid}`,
            title,
            artist,
            album,
            durationSec: durSec,
            artworkUrl: extractThumb(r.thumbnail),
            source: 'youtube',
            audioFormat: 'AAC Audio',
          });
        }
      } catch {}
    }

    for (const val of Object.values(obj)) {
      if (val && typeof val === 'object') walk(val);
    }
  }

  walk(data);
  return results;
}

async function resolveYtAudioUrl(videoId: string): Promise<string | null> {
  const cleanId = videoId.replace(/^yt-/, '').trim();
  if (!/^[a-zA-Z0-9_-]{8,16}$/.test(cleanId)) return null;

  const clients = [
    {
      clientName: 'IOS',
      clientVersion: '21.03.1',
      ua: 'com.google.ios.youtube/21.03.1 (iPhone16,2; U; CPU iOS 18_2 like Mac OS X;)',
    },
    {
      clientName: 'ANDROID',
      clientVersion: '20.10.38',
      androidSdkVersion: 34,
      ua: 'com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip',
    },
    {
      clientName: 'ANDROID_VR',
      clientVersion: '1.56.21',
      ua: 'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12; Quest 3) gzip',
    },
  ];

  for (const c of clients) {
    try {
      const res = await fetch(YT_PLAYER_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': c.ua,
        },
        body: JSON.stringify({
          context: {
            client: {
              clientName: c.clientName,
              clientVersion: c.clientVersion,
              hl: 'en',
              gl: 'US',
              ...(c.androidSdkVersion ? { androidSdkVersion: c.androidSdkVersion } : {}),
            },
          },
          videoId: cleanId,
        }),
        signal: AbortSignal.timeout(7000),
      });
      if (!res.ok) continue;
      const json = (await res.json()) as {
        streamingData?: {
          formats?: Array<{ url?: string; mimeType?: string; itag?: number }>;
          adaptiveFormats?: Array<{ url?: string; mimeType?: string; audioQuality?: string }>;
        };
      };
      const sd = json.streamingData;
      if (!sd) continue;

      const audioFmt =
        sd.adaptiveFormats?.find((f) => f.url && f.mimeType?.includes('audio/mp4')) ??
        sd.adaptiveFormats?.find((f) => f.url && f.mimeType?.startsWith('audio/')) ??
        sd.formats?.find((f) => f.url);
      if (audioFmt?.url) return audioFmt.url;
    } catch {}
  }

  // Open Piped mirror fallback if Google blocks datacenter Player endpoint
  for (const piped of ['https://pipedapi.kavin.rocks', 'https://pipedapi.adminforge.de']) {
    try {
      const r = await fetch(`${piped}/streams/${encodeURIComponent(cleanId)}`, {
        signal: AbortSignal.timeout(6000),
      });
      if (!r.ok) continue;
      const d = (await r.json()) as { audioStreams?: Array<{ url?: string; mimeType?: string; bitrate?: number }> };
      const best =
        d.audioStreams?.find((a) => a.url && a.mimeType?.includes('mp4')) ??
        d.audioStreams?.find((a) => a.url);
      if (best?.url) return best.url;
    } catch {}
  }

  return null;
}

export async function handleStreamRoute(
  request: Request,
  corsHeaders: Record<string, string>,
  json: (data: unknown, status?: number) => Response,
  err: (msg: string, status?: number) => Response
): Promise<Response | null> {
  const url = new URL(request.url);
  const path = url.pathname;

  if (!path.startsWith('/api/stream/')) {
    return null;
  }

  // 1. YouTube Music / Audius Trending Discovery
  if (path === '/api/stream/yt/home' && request.method === 'GET') {
    const tracks: StreamTrackDTO[] = [];
    try {
      const ytRes = await fetch(YT_BROWSE_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Origin: YT_MUSIC_ORIGIN,
          Referer: `${YT_MUSIC_ORIGIN}/`,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
        body: JSON.stringify({ context: WEB_REMIX_CTX, browseId: 'FEmusic_charts' }),
        signal: AbortSignal.timeout(7000),
      });
      if (ytRes.ok) {
        const ytData = await ytRes.json();
        tracks.push(...extractResponsiveItems(ytData).slice(0, 18));
      }
    } catch {}

    // Always supplement / fallback cleanly with direct-streaming Audius trending Hi-Fi tracks
    try {
      const audRes = await fetch('https://discoveryprovider.audius.co/v1/tracks/trending?app_name=MUXIS&limit=16', {
        signal: AbortSignal.timeout(6000),
      });
      if (audRes.ok) {
        const audData = (await audRes.json()) as {
          data?: Array<{
            id?: string;
            title?: string;
            duration?: number;
            user?: { name?: string };
            artwork?: { '480x480'?: string; '150x150'?: string };
          }>;
        };
        for (const item of audData.data ?? []) {
          if (!item.id || !item.title) continue;
          tracks.push({
            id: `aud-${item.id}`,
            title: item.title,
            artist: item.user?.name || 'Audius Artist',
            album: 'Trending Open Stream',
            durationSec: Number(item.duration || 180),
            artworkUrl: item.artwork?.['480x480'] || item.artwork?.['150x150'] || null,
            source: 'audius',
            audioFormat: 'MP3 320kbps',
            streamUrl: `https://discoveryprovider.audius.co/v1/tracks/${encodeURIComponent(item.id)}/stream?app_name=MUXIS`,
          });
        }
      }
    } catch {}

    return json({ tracks }, 200);
  }

  // 2. Unified YouTube Music + Audius Streaming Search
  if (path === '/api/stream/yt/search' && request.method === 'GET') {
    const q = (url.searchParams.get('q') ?? '').trim();
    if (!q) return json({ tracks: [] }, 200);

    const tracks: StreamTrackDTO[] = [];
    const ytPromise = fetch(YT_SEARCH_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Origin: YT_MUSIC_ORIGIN,
        Referer: `${YT_MUSIC_ORIGIN}/`,
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
      body: JSON.stringify({
        context: WEB_REMIX_CTX,
        query: q,
        params: 'EgWKAQIIAWoKEAMQBBAJEAoQBQ%3D%3D',
      }),
      signal: AbortSignal.timeout(7000),
    })
      .then(async (r) => (r.ok ? extractResponsiveItems(await r.json()).slice(0, 15) : []))
      .catch(() => [] as StreamTrackDTO[]);

    const audPromise = fetch(
      `https://discoveryprovider.audius.co/v1/tracks/search?query=${encodeURIComponent(q)}&app_name=MUXIS&limit=12`,
      { signal: AbortSignal.timeout(6000) }
    )
      .then(async (r) => {
        if (!r.ok) return [] as StreamTrackDTO[];
        const d = (await r.json()) as {
          data?: Array<{
            id?: string;
            title?: string;
            duration?: number;
            user?: { name?: string };
            artwork?: { '480x480'?: string; '150x150'?: string };
          }>;
        };
        return (d.data ?? [])
          .filter((x) => x.id && x.title)
          .map(
            (x): StreamTrackDTO => ({
              id: `aud-${x.id}`,
              title: x.title!,
              artist: x.user?.name || 'Audius',
              album: 'Open Stream',
              durationSec: Number(x.duration || 180),
              artworkUrl: x.artwork?.['480x480'] || x.artwork?.['150x150'] || null,
              source: 'audius',
              audioFormat: 'MP3 320kbps',
              streamUrl: `https://discoveryprovider.audius.co/v1/tracks/${encodeURIComponent(x.id!)}/stream?app_name=MUXIS`,
            })
          );
      })
      .catch(() => [] as StreamTrackDTO[]);

    const [ytTracks, audTracks] = await Promise.all([ytPromise, audPromise]);
    tracks.push(...ytTracks, ...audTracks);
    return json({ tracks }, 200);
  }

  // 3. YouTube Stream Proxy (Resolves fresh direct stream + relays bytes/Range for iOS Safari)
  if (path === '/api/stream/yt/audio' && request.method === 'GET') {
    const videoId = (url.searchParams.get('videoId') ?? '').trim();
    if (!videoId) return err('Missing videoId parameter.', 400);

    const directUrl = await resolveYtAudioUrl(videoId);
    if (!directUrl) {
      return err('Could not resolve playable YouTube audio stream from upstream.', 502);
    }

    const reqHeaders = new Headers();
    const range = request.headers.get('Range');
    if (range) reqHeaders.set('Range', range);

    const upstream = await fetch(directUrl, {
      headers: reqHeaders,
      signal: AbortSignal.timeout(15000),
    });
    if (!upstream.ok && upstream.status !== 206) {
      return err(`Upstream media fetch failed (${upstream.status}).`, 502);
    }

    const resHeaders = new Headers(corsHeaders);
    resHeaders.set('Content-Type', upstream.headers.get('Content-Type') || 'audio/mp4');
    resHeaders.set('Accept-Ranges', 'bytes');
    const cl = upstream.headers.get('Content-Length');
    if (cl) resHeaders.set('Content-Length', cl);
    const cr = upstream.headers.get('Content-Range');
    if (cr) resHeaders.set('Content-Range', cr);

    return new Response(upstream.body, {
      status: upstream.status,
      headers: resHeaders,
    });
  }

  // 4. Synced Lyrics Lookup via LRCLIB
  if (path === '/api/stream/lyrics' && request.method === 'GET') {
    const rawTitle = (url.searchParams.get('title') ?? '').trim();
    const rawArtist = (url.searchParams.get('artist') ?? '').trim();
    const duration = (url.searchParams.get('duration') ?? '').trim();
    if (!rawTitle) return json({ syncedLyrics: null, plainLyrics: null }, 200);

    const cleanTitle = rawTitle
      .replace(/\s*[(\[](?:official|lyrics?|audio|hd|4k|hq|remaster(?:ed)?|live|feat\.?[^)\]]*)[)\]]/gi, '')
      .trim();
    const cleanArtist = rawArtist.replace(/\s*-\s*Topic$/i, '').split(/\s*(?:feat\.|ft\.|&|,)\s*/i)[0].trim();

    try {
      const qs = new URLSearchParams({ track_name: cleanTitle });
      if (cleanArtist && cleanArtist.toLowerCase() !== 'unknown artist') qs.set('artist_name', cleanArtist);
      if (duration && Number(duration) > 0) qs.set('duration', duration);

      const getRes = await fetch(`https://lrclib.net/api/get?${qs.toString()}`, {
        headers: { 'User-Agent': 'MUXIS/1.2.13 (Web Audio Player)' },
        signal: AbortSignal.timeout(5000),
      });
      if (getRes.ok) {
        const d = (await getRes.json()) as { syncedLyrics?: string; plainLyrics?: string; instrumental?: boolean };
        if (d.syncedLyrics || d.plainLyrics) {
          return json({
            syncedLyrics: d.syncedLyrics ?? null,
            plainLyrics: d.plainLyrics ?? null,
            instrumental: Boolean(d.instrumental),
          });
        }
      }

      const srRes = await fetch(
        `https://lrclib.net/api/search?q=${encodeURIComponent(`${cleanArtist} ${cleanTitle}`.trim())}`,
        { headers: { 'User-Agent': 'MUXIS/1.2.13 (Web Audio Player)' }, signal: AbortSignal.timeout(5000) }
      );
      if (srRes.ok) {
        const list = (await srRes.json()) as Array<{ syncedLyrics?: string; plainLyrics?: string; instrumental?: boolean }>;
        const match = list.find((x) => x.syncedLyrics) ?? list[0];
        if (match) {
          return json({
            syncedLyrics: match.syncedLyrics ?? null,
            plainLyrics: match.plainLyrics ?? null,
            instrumental: Boolean(match.instrumental),
          });
        }
      }
    } catch {}

    return json({ syncedLyrics: null, plainLyrics: null }, 200);
  }

  return err('Unsupported stream route.', 404);
}
