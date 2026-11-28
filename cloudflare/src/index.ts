/**
 * MUXIS Cloudflare Worker — API Gateway & R2 Object Storage Service
 *
 * Responsibilities:
 * 1. Application version checks & update manifest (/api/version)
 * 2. Pre-signed/authorized R2 image uploads for user avatars & playlist covers (/api/storage/*)
 *    STRICT RULE: Local or copyrighted audio files are NEVER stored or accepted.
 * 3. Streaming cached delivery of public assets with high-performance edge headers
 * 4. Health checks & CORS preflight handling
 */

import { CloudEnv, handleCloudRoute } from './cloud_auth';
import { handlePlatformLinksRoute } from './platform_links';
import { handleStreamRoute } from './stream_api';

export interface Env extends CloudEnv {
  MUXIS_STORAGE?: R2Bucket;
  ENVIRONMENT?: string;
  LATEST_VERSION?: string;
  MIN_SUPPORTED_VERSION?: string;
  SUPABASE_JWT_SECRET?: string;
}

// Allowed MIME types for uploaded artwork (strictly visual artwork only)
const ALLOWED_IMAGE_TYPES = new Set([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
]);

const MAX_IMAGE_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB max for artwork

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With, X-Muxis-Client',
  'Access-Control-Max-Age': '86400',
};

const SECURITY_HEADERS: Record<string, string> = {
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Strict-Transport-Security': 'max-age=31536000; includeSubDomains; preload',
};

function jsonResponse(data: unknown, status = 200, extraHeaders: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      ...CORS_HEADERS,
      ...SECURITY_HEADERS,
      ...extraHeaders,
    },
  });
}

function errorResponse(message: string, status = 400): Response {
  return jsonResponse({ error: message, status }, status);
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: {
          ...CORS_HEADERS,
          ...SECURITY_HEADERS,
        },
      });
    }

    try {
      // 1. Health check
      if (path === '/' || path === '/health' || path === '/api/health') {
        return jsonResponse({
          status: 'healthy',
          app: 'Muxis API Gateway',
          environment: env.ENVIRONMENT ?? 'production',
          timestamp: new Date().toISOString(),
        });
      }

      // 2. Application version & update manifest
      if (path === '/api/version') {
        return handleVersionCheck(env);
      }

      // 2a. Public AdSense monetization config (for public https://muxis.pages.dev/ pages only)
      if (path === '/api/public/monetization' && request.method === 'GET') {
        if (!env.DB) return jsonResponse({ enabled: false, clientId: '', slots: {} });
        const flags = await env.DB
          .prepare(
            `SELECT key, value FROM app_config_flags
             WHERE key IN ('adsense_enabled', 'adsense_client_id', 'adsense_slot_home', 'adsense_slot_download', 'adsense_slot_docs')`
          )
          .all<{ key: string; value: string }>();
        const map: Record<string, string> = {};
        for (const row of flags.results ?? []) map[row.key] = row.value;
        const clientId = (map.adsense_client_id || '').trim();
        const enabled = map.adsense_enabled === 'true' && /^ca-pub-\d{10,20}$/.test(clientId);
        return jsonResponse({
          enabled,
          clientId: enabled ? clientId : '',
          slots: {
            home: map.adsense_slot_home || '',
            download: map.adsense_slot_download || '',
            docs: map.adsense_slot_docs || '',
          },
        });
      }

      // 2b. MUXIS Cloud Auth & D1 Sync routes
      const cloudResp = await handleCloudRoute(request, env, jsonResponse, errorResponse);
      if (cloudResp) {
        return cloudResp;
      }

      // 2b2. Streaming Platform Connections & D1 Sync (YT Music, Spotify, SoundCloud)
      const linksResp = await handlePlatformLinksRoute(request, env, jsonResponse, errorResponse);
      if (linksResp) {
        return linksResp;
      }

      // 2c. Streaming Search, Audio Relay & Synced Lyrics routes
      const streamResp = await handleStreamRoute(request, CORS_HEADERS, jsonResponse, errorResponse);
      if (streamResp) {
        return streamResp;
      }

      // 3. Storage: Request upload authorization / metadata
      if (path === '/api/storage/upload-ticket' && request.method === 'POST') {
        return await handleCreateUploadTicket(request, env);
      }

      // 4. Storage: Upload avatar or playlist cover
      if (path.startsWith('/api/storage/upload/') && request.method === 'PUT') {
        return await handleDirectUpload(path, request, env);
      }

      // 5. Storage: Get public avatar or playlist cover
      if (path.startsWith('/api/storage/file/') && request.method === 'GET') {
        return await handleGetFile(path, request, env);
      }

      return errorResponse('Endpoint not found', 404);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Internal Server Error';
      console.error('[Worker Error]', message);
      return errorResponse('Internal server error', 500);
    }
  },
};

/**
 * Version Manifest Endpoint
 */
function handleVersionCheck(env: Env): Response {
  const latestVersion = env.LATEST_VERSION ?? '1.0.0';
  const minVersion = env.MIN_SUPPORTED_VERSION ?? '1.0.0';

  const manifest = {
    app_name: 'MUXIS — PRISMATIC AURA',
    latest_version: latestVersion,
    min_supported_version: minVersion,
    release_date: '2026-11-21',
    platforms: {
      windows: {
        version: latestVersion,
        architecture: 'x64',
        download_url: 'https://github.com/DidarAlif/muxis/releases/latest/download/Muxis-Windows-x64.zip',
        portable_url: 'https://github.com/DidarAlif/muxis/releases/latest/download/Muxis-Windows-x64.zip',
      },
      macos: {
        version: latestVersion,
        architecture: 'universal (arm64 + x64)',
        download_url: 'https://github.com/DidarAlif/muxis/releases/latest/download/Muxis-macOS-Universal.zip',
      },
      linux: {
        version: latestVersion,
        architecture: 'x86_64',
        download_url: 'https://github.com/DidarAlif/muxis/releases/latest/download/Muxis-Linux-x64.tar.gz',
        tarball_url: 'https://github.com/DidarAlif/muxis/releases/latest/download/Muxis-Linux-x64.tar.gz',
      },
      android: {
        version: latestVersion,
        download_url: 'https://github.com/DidarAlif/muxis/releases/latest/download/Muxis-Android.apk',
        play_store_url: 'https://play.google.com/store/apps/details?id=app.muxis.player',
      },
      ios: {
        version: latestVersion,
        download_url: 'https://github.com/DidarAlif/muxis/releases/latest/download/Muxis-iOS.ipa',
        unsigned_zip_url: 'https://github.com/DidarAlif/muxis/releases/latest/download/Muxis-iOS-Unsigned.zip',
        app_store_url: 'https://apps.apple.com/app/muxis-player/id0000000000',
      },
    },
    changelog: [
      'Official iOS / iPhone IPA build (`Muxis-iOS.ipa`) with Lock Screen & Files integration',
      'Whole-device storage music scan across Android internal/SD cards and iPhone Files',
      'Instant MUXIS Cloud authentication & D1 sync across Windows, macOS, Linux, Android, and iOS',
      '10-theme Studio with customizable accent tastes and per-track 10-band EQ',
      'Unified responsive shell for desktop and mobile form factors',
    ],
  };

  return jsonResponse(manifest, 200, {
    'Cache-Control': 'public, max-age=300, s-maxage=300', // 5 minutes cache
  });
}

/**
 * Pre-authorizes an upload ticket for user avatars or playlist covers.
 * Verifies that the client is NOT attempting to upload audio files.
 */
async function handleCreateUploadTicket(request: Request, env: Env): Promise<Response> {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return errorResponse('Missing or invalid Authorization header', 401);
  }

  let body: {
    category?: string;
    userId?: string;
    contentType?: string;
    fileSizeBytes?: number;
  };

  try {
    body = await request.json();
  } catch {
    return errorResponse('Invalid JSON payload in request body', 400);
  }

  const { category, userId, contentType, fileSizeBytes } = body;

  if (!category || !['avatar', 'playlist_cover'].includes(category)) {
    return errorResponse('Invalid category. Must be "avatar" or "playlist_cover"', 400);
  }

  if (!userId || typeof userId !== 'string' || userId.length < 5) {
    return errorResponse('Invalid userId supplied', 400);
  }

  if (!contentType || !ALLOWED_IMAGE_TYPES.has(contentType.toLowerCase())) {
    return errorResponse(
      `Unsupported or prohibited content type: ${contentType}. Only visual images (JPEG, PNG, WebP) are allowed. Local audio files must never be uploaded.`,
      415
    );
  }

  if (fileSizeBytes && fileSizeBytes > MAX_IMAGE_SIZE_BYTES) {
    return errorResponse(`File size exceeds 5 MB limit (${fileSizeBytes} bytes)`, 413);
  }

  // Generate unique file path
  const fileExt = contentType.split('/')[1] === 'jpeg' ? 'jpg' : contentType.split('/')[1];
  const fileId = crypto.randomUUID();
  const storageKey = `${category}s/${userId}/${fileId}.${fileExt}`;

  const origin = new URL(request.url).origin;
  const uploadPath = `/api/storage/upload/${storageKey}`;
  const publicPath = `/api/storage/file/${storageKey}`;

  return jsonResponse({
    authorized: true,
    storageKey,
    uploadUrl: `${origin}${uploadPath}`,
    publicUrl: `${origin}${publicPath}`,
    maxSizeBytes: MAX_IMAGE_SIZE_BYTES,
    expiresInSeconds: 900, // 15 minutes
  });
}

/**
 * Handles direct streaming upload into the Cloudflare R2 bucket binding.
 */
async function handleDirectUpload(path: string, request: Request, env: Env): Promise<Response> {
  if (!env.MUXIS_STORAGE) {
    return errorResponse('R2 object storage pending activation in Cloudflare dashboard', 503);
  }
  // Path format: /api/storage/upload/(avatars|playlist_covers)/userId/filename.ext
  const storageKey = path.replace('/api/storage/upload/', '');
  if (!storageKey || storageKey.includes('..')) {
    return errorResponse('Invalid storage key path', 400);
  }

  const contentType = request.headers.get('Content-Type') || '';
  if (!ALLOWED_IMAGE_TYPES.has(contentType.toLowerCase())) {
    return errorResponse(
      'Prohibited upload. Only image artwork (JPEG, PNG, WebP) is accepted. Audio uploads are forbidden.',
      415
    );
  }

  const contentLength = request.headers.get('Content-Length');
  if (contentLength && parseInt(contentLength, 10) > MAX_IMAGE_SIZE_BYTES) {
    return errorResponse('Uploaded image exceeds 5 MB limit', 413);
  }

  if (!request.body) {
    return errorResponse('Request body is empty', 400);
  }

  // Put stream into R2
  const r2Object = await env.MUXIS_STORAGE.put(storageKey, request.body, {
    httpMetadata: {
      contentType,
      cacheControl: 'public, max-age=31536000, immutable',
    },
    customMetadata: {
      uploadedAt: new Date().toISOString(),
      source: 'muxis-flutter-client',
    },
  });

  const origin = new URL(request.url).origin;
  return jsonResponse(
    {
      success: true,
      storageKey,
      etag: r2Object.etag,
      publicUrl: `${origin}/api/storage/file/${storageKey}`,
    },
    201
  );
}

/**
 * Streams public avatars or playlist covers from R2 with edge caching.
 */
async function handleGetFile(path: string, request: Request, env: Env): Promise<Response> {
  if (!env.MUXIS_STORAGE) {
    return errorResponse('R2 object storage pending activation in Cloudflare dashboard', 503);
  }
  const storageKey = path.replace('/api/storage/file/', '');
  if (!storageKey || storageKey.includes('..')) {
    return errorResponse('Invalid storage key path', 400);
  }

  // Conditional request check (ETag)
  const clientEtag = request.headers.get('If-None-Match');

  const object = await env.MUXIS_STORAGE.get(storageKey);
  if (!object) {
    return errorResponse('Image not found in storage', 404);
  }

  if (clientEtag && clientEtag === object.etag) {
    return new Response(null, {
      status: 304,
      headers: {
        ...CORS_HEADERS,
        ...SECURITY_HEADERS,
        ETag: object.etag,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });
  }

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set('ETag', object.etag);
  headers.set('Cache-Control', 'public, max-age=31536000, immutable');
  for (const [k, v] of Object.entries(CORS_HEADERS)) {
    headers.set(k, v);
  }
  for (const [k, v] of Object.entries(SECURITY_HEADERS)) {
    headers.set(k, v);
  }

  return new Response(object.body, {
    status: 200,
    headers,
  });
}
