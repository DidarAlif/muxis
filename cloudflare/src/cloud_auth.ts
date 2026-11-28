/**
 * MUXIS Cloud Auth & Sync Module for Cloudflare Workers + D1.
 * Handles PBKDF2-SHA256 email/password auth, backup recovery keys,
 * HS256 JWT issuance/verification, Google OAuth PKCE & ID-token login,
 * and cross-device playlist/favorite/settings synchronization.
 */

export interface CloudEnv {
  DB?: D1Database;
  MUXIS_JWT_SECRET?: string;
  GOOGLE_CLIENT_ID?: string;
  GOOGLE_CLIENT_SECRET?: string;
  FIREBASE_PROJECT_ID?: string;
  FIREBASE_WEB_API_KEY?: string;
  FIREBASE_AUTH_BRIDGE_URL?: string;
  ADMIN_EMAILS?: string;
}

export interface UserRow {
  id: string;
  email: string;
  display_name: string;
  avatar_url: string | null;
  auth_provider: string;
  google_sub: string | null;
  password_hash: string | null;
  password_salt: string | null;
  recovery_code_hash: string | null;
  subscription_tier: string;
  pwa_approval_status?: string | null;
  is_admin?: number | null;
  pwa_approved_at?: string | null;
  pwa_approved_by?: string | null;
  pwa_note?: string | null;
  created_at?: string;
  updated_at?: string;
}

function getOwnerAdminSet(env: CloudEnv): Set<string> {
  const raw = env.ADMIN_EMAILS ?? 'fbalif123@gmail.com,a.leaf.organization@gmail.com';
  return new Set(
    raw
      .split(',')
      .map((s) => s.trim().toLowerCase())
      .filter(Boolean)
  );
}

function isOwnerAdmin(email: string, env: CloudEnv): boolean {
  return getOwnerAdminSet(env).has(email.trim().toLowerCase());
}

export async function isApprovalRequired(db: D1Database): Promise<boolean> {
  try {
    const row = await db
      .prepare(`SELECT value FROM app_config_flags WHERE key = 'require_pwa_approval'`)
      .first<{ value: string }>();
    if (!row) return true;
    return row.value !== 'false';
  } catch {
    return true;
  }
}

const enc = new TextEncoder();

function base64UrlEncode(bytes: Uint8Array): string {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) {
    bin += String.fromCharCode(bytes[i]);
  }
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function base64UrlDecode(str: string): Uint8Array {
  const padded = str.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((str.length + 3) % 4);
  const bin = atob(padded);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) {
    out[i] = bin.charCodeAt(i);
  }
  return out;
}

function constantTimeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff === 0;
}

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', enc.encode(input));
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

async function hashPassword(password: string, saltHex?: string): Promise<{ hashHex: string; saltHex: string }> {
  const saltBytes = saltHex
    ? new Uint8Array(saltHex.match(/.{1,2}/g)!.map((h) => parseInt(h, 16)))
    : crypto.getRandomValues(new Uint8Array(16));
  const usedSaltHex =
    saltHex ??
    Array.from(saltBytes)
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('');

  const keyMaterial = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveBits']);
  const derived = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt: saltBytes, iterations: 100000, hash: 'SHA-256' },
    keyMaterial,
    256
  );
  const hashHex = Array.from(new Uint8Array(derived))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
  return { hashHex, saltHex: usedSaltHex };
}

async function verifyPassword(password: string, expectedHashHex: string, saltHex: string): Promise<boolean> {
  const { hashHex } = await hashPassword(password, saltHex);
  return constantTimeEqual(enc.encode(hashHex), enc.encode(expectedHashHex));
}

function generateRecoveryKey(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = crypto.getRandomValues(new Uint8Array(12));
  const chars = Array.from(bytes, (b) => alphabet[b % alphabet.length]);
  return `MUXIS-${chars.slice(0, 4).join('')}-${chars.slice(4, 8).join('')}-${chars.slice(8, 12).join('')}`;
}

function normalizeRecoveryKey(raw: string): string {
  return raw.trim().toUpperCase();
}

async function signJwt(
  payload: Record<string, unknown>,
  secret: string,
  expiresInSeconds = 60 * 60 * 24 * 30
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const fullPayload = { ...payload, iat: now, exp: now + expiresInSeconds };
  const headerB64 = base64UrlEncode(enc.encode(JSON.stringify({ alg: 'HS256', typ: 'JWT' })));
  const payloadB64 = base64UrlEncode(enc.encode(JSON.stringify(fullPayload)));
  const signingInput = `${headerB64}.${payloadB64}`;

  const key = await crypto.subtle.importKey(
    'raw',
    enc.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const sig = new Uint8Array(await crypto.subtle.sign('HMAC', key, enc.encode(signingInput)));
  return `${signingInput}.${base64UrlEncode(sig)}`;
}

export async function verifyJwt(token: string, secret: string): Promise<Record<string, unknown> | null> {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  try {
    const key = await crypto.subtle.importKey(
      'raw',
      enc.encode(secret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['verify']
    );
    const sigBytes = base64UrlDecode(parts[2]);
    const ok = await crypto.subtle.verify('HMAC', key, sigBytes, enc.encode(`${parts[0]}.${parts[1]}`));
    if (!ok) return null;
    const payloadJson = new TextDecoder().decode(base64UrlDecode(parts[1]));
    const payload = JSON.parse(payloadJson) as Record<string, unknown>;
    const exp = typeof payload.exp === 'number' ? payload.exp : 0;
    if (exp < Math.floor(Date.now() / 1000)) return null;
    return payload;
  } catch {
    return null;
  }
}

export function serializeUser(u: UserRow, env?: CloudEnv) {
  const owner = env ? isOwnerAdmin(u.email, env) : false;
  const isAdmin = owner || Number(u.is_admin ?? 0) === 1;
  const approval = isAdmin ? 'approved' : (u.pwa_approval_status || 'pending');
  return {
    id: u.id,
    email: u.email,
    display_name: u.display_name,
    avatar_url: u.avatar_url,
    subscription_tier: u.subscription_tier || 'free',
    auth_provider: u.auth_provider || 'email',
    is_admin: isAdmin,
    pwa_approval_status: approval,
    pwa_note: u.pwa_note ?? null,
  };
}

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function htmlPage(title: string, heading: string, body: string, color = '#00FF88', redirectScript = ''): Response {
  const html = `<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title></head>
<body style="margin:0;background:#060910;color:#f8fafc;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;padding:24px;">
  <div style="max-width:440px;width:100%;background:#0b111c;border:1px solid #233046;border-radius:20px;padding:34px 28px;text-align:center;box-shadow:0 24px 64px rgba(0,0,0,0.55);">
    <div style="display:inline-flex;align-items:center;justify-content:center;width:44px;height:44px;border-radius:12px;background:${color}18;border:1px solid ${color}45;margin-bottom:14px;color:${color};font-weight:800;font-size:18px;">M</div>
    <div style="font-size:11.5px;letter-spacing:2.2px;font-weight:700;color:${color};margin-bottom:8px;">MUXIS CLOUD</div>
    <h1 style="margin:0 0 12px;font-size:23px;font-weight:800;letter-spacing:-0.4px;">${heading}</h1>
    <p style="margin:0;color:#cbd5e1;line-height:1.6;font-size:14px;">${body}</p>
  </div>
  ${redirectScript}
</body></html>`;
  return new Response(html, { status: 200, headers: { 'Content-Type': 'text/html; charset=utf-8' } });
}

export async function handleCloudRoute(
  request: Request,
  env: CloudEnv,
  json: (data: unknown, status?: number) => Response,
  err: (msg: string, status?: number) => Response
): Promise<Response | null> {
  const url = new URL(request.url);
  const path = url.pathname;

  if (!path.startsWith('/api/auth/') && !path.startsWith('/api/sync/') && !path.startsWith('/api/admin/')) {
    return null;
  }

  if (!env.DB || !env.MUXIS_JWT_SECRET) {
    return err('MUXIS Cloud database or signing secret is not configured on Worker.', 503);
  }
  const db = env.DB;
  const jwtSecret = env.MUXIS_JWT_SECRET;

  // 1. Public capability metadata
  if (path === '/api/auth/config' && request.method === 'GET') {
    const directGoogle = Boolean(env.GOOGLE_CLIENT_ID && env.GOOGLE_CLIENT_SECRET);
    const firebaseGoogle = Boolean(
      env.FIREBASE_PROJECT_ID && env.FIREBASE_WEB_API_KEY && env.FIREBASE_AUTH_BRIDGE_URL
    );
    return json({
      provider: 'muxis-cloud-d1',
      email_autoconfirm: true,
      instant_signup: true,
      recovery_key_reset: true,
      google_oauth_enabled: directGoogle || firebaseGoogle,
      google_auth_mode: directGoogle ? 'google_direct' : firebaseGoogle ? 'firebase_client' : 'disabled',
      firebase_bridge_url: firebaseGoogle ? env.FIREBASE_AUTH_BRIDGE_URL : null,
      google_callback_url: `${url.origin}/api/auth/google/callback`,
      worker_version: '1.2.13',
    });
  }

  // 2. Instant Email / Gmail Registration (zero broken confirmation email bottleneck)
  if (path === '/api/auth/register' && request.method === 'POST') {
    let body: { email?: string; password?: string; display_name?: string };
    try {
      body = await request.json();
    } catch {
      return err('Invalid JSON request body.', 400);
    }

    const email = (body.email ?? '').trim().toLowerCase();
    const password = body.password ?? '';
    const rawName = (body.display_name ?? '').trim();

    if (!isValidEmail(email)) {
      return err('Please enter a valid Gmail or email address.', 400);
    }
    if (password.length < 6) {
      return err('Password must be at least 6 characters long.', 400);
    }

    const existing = await db.prepare('SELECT id FROM users WHERE email = ?').bind(email).first();
    if (existing) {
      return err(`An account for ${email} already exists. Switch to Sign In (or reset with your Recovery Key).`, 409);
    }

    const userId = crypto.randomUUID();
    const displayName = rawName.length > 0 ? rawName : email.split('@')[0] || 'Muxis Listener';
    const { hashHex, saltHex } = await hashPassword(password);
    const recoveryKey = generateRecoveryKey();
    const recoveryHash = await sha256Hex(normalizeRecoveryKey(recoveryKey));
    const now = new Date().toISOString();
    const ownerAdmin = isOwnerAdmin(email, env);
    const needApproval = ownerAdmin ? false : await isApprovalRequired(db);
    const approvalStatus = ownerAdmin || !needApproval ? 'approved' : 'pending';
    const adminFlag = ownerAdmin ? 1 : 0;

    await db.batch([
      db
        .prepare(
          `INSERT INTO users (id, email, display_name, auth_provider, password_hash, password_salt, recovery_code_hash, email_verified, subscription_tier, pwa_approval_status, is_admin, created_at, updated_at)
           VALUES (?, ?, ?, 'email', ?, ?, ?, 1, 'free', ?, ?, ?, ?)`
        )
        .bind(userId, email, displayName, hashHex, saltHex, recoveryHash, approvalStatus, adminFlag, now, now),
      db.prepare('INSERT OR IGNORE INTO user_settings (user_id, updated_at) VALUES (?, ?)').bind(userId, now),
    ]);

    const userObj = {
      id: userId,
      email,
      display_name: displayName,
      avatar_url: null,
      subscription_tier: 'free',
      auth_provider: 'email',
      is_admin: ownerAdmin,
      pwa_approval_status: approvalStatus,
      pwa_note: null,
    };
    const token = await signJwt({ sub: userId, email }, jwtSecret);
    return json({ access_token: token, user: userObj, recovery_key: recoveryKey }, 201);
  }

  // 3. Email / Gmail Login
  if (path === '/api/auth/login' && request.method === 'POST') {
    let body: { email?: string; password?: string };
    try {
      body = await request.json();
    } catch {
      return err('Invalid JSON request body.', 400);
    }

    const email = (body.email ?? '').trim().toLowerCase();
    const password = body.password ?? '';
    if (!isValidEmail(email) || password.length === 0) {
      return err('Enter both your Gmail / email address and password.', 400);
    }

    const row = await db.prepare('SELECT * FROM users WHERE email = ?').bind(email).first<UserRow>();
    if (!row) {
      return err('No MUXIS Cloud account found for this email. Switch to Create Account first.', 401);
    }
    if (!row.password_hash || !row.password_salt) {
      return err('This account uses Google Sign-In. Sign in with Google or reset your password with a Recovery Key.', 401);
    }

    const valid = await verifyPassword(password, row.password_hash, row.password_salt);
    if (!valid) {
      return err('Incorrect password. Check your password or reset it using your Backup Recovery Key.', 401);
    }

    const token = await signJwt({ sub: row.id, email: row.email }, jwtSecret);
    return json({ access_token: token, user: serializeUser(row, env) }, 200);
  }

  // 4. Instant Recovery-Key Password Reset (works offline-from-SMTP cleanly on any OS)
  if (path === '/api/auth/reset-password' && request.method === 'POST') {
    let body: { email?: string; recovery_key?: string; new_password?: string };
    try {
      body = await request.json();
    } catch {
      return err('Invalid JSON request body.', 400);
    }

    const email = (body.email ?? '').trim().toLowerCase();
    const recoveryKey = normalizeRecoveryKey(body.recovery_key ?? '');
    const newPassword = body.new_password ?? '';
    if (!isValidEmail(email) || recoveryKey.length < 10) {
      return err('Enter your account email and Backup Recovery Key (MUXIS-XXXX-XXXX-XXXX).', 400);
    }
    if (newPassword.length < 6) {
      return err('New password must be at least 6 characters long.', 400);
    }

    const row = await db.prepare('SELECT * FROM users WHERE email = ?').bind(email).first<UserRow>();
    if (!row || !row.recovery_code_hash) {
      return err('Invalid email or Backup Recovery Key.', 401);
    }

    const incomingHash = await sha256Hex(recoveryKey);
    if (!constantTimeEqual(enc.encode(incomingHash), enc.encode(row.recovery_code_hash))) {
      return err('Incorrect Backup Recovery Key for this account.', 401);
    }

    const { hashHex, saltHex } = await hashPassword(newPassword);
    const nextRecovery = generateRecoveryKey();
    const nextRecoveryHash = await sha256Hex(normalizeRecoveryKey(nextRecovery));
    const now = new Date().toISOString();

    await db
      .prepare('UPDATE users SET password_hash = ?, password_salt = ?, recovery_code_hash = ?, updated_at = ? WHERE id = ?')
      .bind(hashHex, saltHex, nextRecoveryHash, now, row.id)
      .run();

    const token = await signJwt({ sub: row.id, email: row.email }, jwtSecret);
    return json({ access_token: token, user: serializeUser(row, env), recovery_key: nextRecovery }, 200);
  }

  // 5. Google OAuth Browser Start (Direct Google OR Firebase Auth Client + Cloudflare D1 State Ticket)
  if (path === '/api/auth/google/start' && request.method === 'GET') {
    const hasDirectGoogle = Boolean(env.GOOGLE_CLIENT_ID && env.GOOGLE_CLIENT_SECRET);
    const hasFirebaseBridge = Boolean(
      env.FIREBASE_PROJECT_ID && env.FIREBASE_WEB_API_KEY && env.FIREBASE_AUTH_BRIDGE_URL
    );
    if (!hasDirectGoogle && !hasFirebaseBridge) {
      return err('Google 1-Click OAuth is not configured on Worker secrets yet.', 503);
    }
    const pollSecret = url.searchParams.get('poll_secret') ?? '';
    if (pollSecret.length < 16) {
      return err('Missing poll_secret parameter.', 400);
    }
    const appRedirect = url.searchParams.get('app_redirect');
    const reqScope = (url.searchParams.get('scope') ?? '').trim().toLowerCase();
    const isYoutube = reqScope === 'youtube';

    const stateBytes = crypto.getRandomValues(new Uint8Array(24));
    const state = base64UrlEncode(stateBytes);
    const verifierBytes = crypto.getRandomValues(new Uint8Array(48));
    const codeVerifier = base64UrlEncode(verifierBytes);
    const challengeDigest = await crypto.subtle.digest('SHA-256', enc.encode(codeVerifier));
    const codeChallenge = base64UrlEncode(new Uint8Array(challengeDigest));
    const pollSecretHash = await sha256Hex(pollSecret);

    const now = new Date();
    const expires = new Date(now.getTime() + 10 * 60 * 1000).toISOString();

    await db
      .prepare(
        `INSERT INTO oauth_states (state, poll_secret_hash, code_verifier, app_redirect, status, expires_at, created_at)
         VALUES (?, ?, ?, ?, 'pending', ?, ?)`
      )
      .bind(state, pollSecretHash, codeVerifier, appRedirect, expires, now.toISOString())
      .run();

    if (hasDirectGoogle && env.GOOGLE_CLIENT_ID) {
      const callbackUrl = `${url.origin}/api/auth/google/callback`;
      const authUrl = new URL('https://accounts.google.com/o/oauth2/v2/auth');
      authUrl.searchParams.set('client_id', env.GOOGLE_CLIENT_ID);
      authUrl.searchParams.set('redirect_uri', callbackUrl);
      authUrl.searchParams.set('response_type', 'code');
      authUrl.searchParams.set(
        'scope',
        isYoutube ? 'openid email profile https://www.googleapis.com/auth/youtube.readonly' : 'openid email profile'
      );
      authUrl.searchParams.set('state', state);
      authUrl.searchParams.set('code_challenge', codeChallenge);
      authUrl.searchParams.set('code_challenge_method', 'S256');
      authUrl.searchParams.set('prompt', 'select_account');

      return json({ auth_url: authUrl.toString(), state, callback_url: callbackUrl, mode: 'google_direct' });
    }

    const bridgeBase = (env.FIREBASE_AUTH_BRIDGE_URL ?? 'https://muxis-cloud.firebaseapp.com').replace(/\/+$/, '');
    const firebaseAuthUrl = `${bridgeBase}/?state=${encodeURIComponent(state)}&worker=${encodeURIComponent(url.origin)}${isYoutube ? '&yt=1' : ''}`;
    return json({ auth_url: firebaseAuthUrl, state, mode: 'firebase_client' });
  }

  // 5b. Firebase Auth Google Handoff -> Verify Firebase ID Token & Store Account strictly in Cloudflare D1
  if (path === '/api/auth/firebase/complete' && request.method === 'POST') {
    if (!env.FIREBASE_PROJECT_ID || !env.FIREBASE_WEB_API_KEY) {
      return err('Firebase client bridge is not configured on Worker.', 503);
    }
    let body: { state?: string; id_token?: string; yt_access_token?: string };
    try {
      body = await request.json();
    } catch {
      return err('Invalid JSON request body.', 400);
    }

    const state = (body.state ?? '').trim();
    const idToken = (body.id_token ?? '').trim();
    if (!state || idToken.split('.').length !== 3) {
      return err('Missing OAuth state or valid Firebase ID token.', 400);
    }

    const row = await db
      .prepare('SELECT * FROM oauth_states WHERE state = ?')
      .bind(state)
      .first<{ state: string; app_redirect: string | null; status: string; expires_at: string }>();

    if (!row || row.status !== 'pending' || new Date(row.expires_at).getTime() < Date.now()) {
      return err('Sign-in state expired or already used. Retry from MUXIS app.', 410);
    }

    // Verify JWT audience/issuer locally first before contacting Google Identity Toolkit
    try {
      const claimJson = new TextDecoder().decode(base64UrlDecode(idToken.split('.')[1]));
      const claims = JSON.parse(claimJson) as { aud?: string; iss?: string; exp?: number };
      if (
        claims.aud !== env.FIREBASE_PROJECT_ID ||
        claims.iss !== `https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}` ||
        (typeof claims.exp === 'number' && claims.exp < Math.floor(Date.now() / 1000))
      ) {
        return err('Invalid Firebase token audience or expired token.', 401);
      }
    } catch {
      return err('Malformed Firebase token claims.', 401);
    }

    // Cryptographically verify Firebase ID Token via Google Identity Toolkit lookup
    const lookupResp = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(env.FIREBASE_WEB_API_KEY)}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ idToken }),
      }
    );
    if (!lookupResp.ok) {
      return err('Failed to verify Firebase ID token with Google Identity Toolkit.', 401);
    }

    const lookupData = (await lookupResp.json()) as {
      users?: Array<{
        localId?: string;
        email?: string;
        emailVerified?: boolean;
        displayName?: string;
        photoUrl?: string;
        providerUserInfo?: Array<{
          providerId?: string;
          rawId?: string;
          displayName?: string;
          photoUrl?: string;
          email?: string;
        }>;
      }>;
    };
    const fbUser = lookupData.users?.[0];
    if (!fbUser || !fbUser.email || !fbUser.emailVerified) {
      return err('Google account must have a verified email address.', 401);
    }

    const googleInfo = fbUser.providerUserInfo?.find((p) => p.providerId === 'google.com');
    const googleSub = googleInfo?.rawId || fbUser.localId;
    if (!googleSub) {
      return err('Verified Google identity identifier missing.', 401);
    }

    const userObj = await upsertGoogleUser(db, env, {
      googleSub,
      email: fbUser.email.toLowerCase(),
      displayName: googleInfo?.displayName || fbUser.displayName || fbUser.email.split('@')[0],
      avatarUrl: googleInfo?.photoUrl || fbUser.photoUrl || null,
    });
    const jwt = await signJwt({ sub: userObj.id, email: userObj.email }, jwtSecret);
    const storedUserPayload = body.yt_access_token
      ? { ...userObj, _yt_access_token: body.yt_access_token }
      : userObj;

    await db
      .prepare(`UPDATE oauth_states SET status = 'complete', result_token = ?, result_user_json = ? WHERE state = ?`)
      .bind(jwt, JSON.stringify(storedUserPayload), state)
      .run();

    return json({ ok: true, email: userObj.email, redirect_url: row.app_redirect }, 200);
  }

  // 6. Google OAuth HTTPS Callback
  if (path === '/api/auth/google/callback' && request.method === 'GET') {
    const state = url.searchParams.get('state') ?? '';
    const code = url.searchParams.get('code') ?? '';
    const oauthErr = url.searchParams.get('error');

    if (!state) {
      return htmlPage('MUXIS Sign-In Error', 'Missing State', 'Return to MUXIS and try signing in again.', '#EF4444');
    }

    const row = await db
      .prepare('SELECT * FROM oauth_states WHERE state = ?')
      .bind(state)
      .first<{
        state: string;
        code_verifier: string;
        app_redirect: string | null;
        status: string;
        expires_at: string;
      }>();

    if (!row || row.status !== 'pending' || new Date(row.expires_at).getTime() < Date.now()) {
      return htmlPage('MUXIS Sign-In Expired', 'Session Timed Out', 'This Google login attempt expired. Return to MUXIS and click Continue with Google again.', '#EF4444');
    }

    if (oauthErr || !code) {
      await db
        .prepare(`UPDATE oauth_states SET status = 'error', error_message = ? WHERE state = ?`)
        .bind(oauthErr ?? 'Google login cancelled.', state)
        .run();
      return htmlPage('MUXIS Sign-In Cancelled', 'Sign-In Cancelled', 'You can close this tab and return to MUXIS.', '#EF4444');
    }

    if (!env.GOOGLE_CLIENT_ID || !env.GOOGLE_CLIENT_SECRET) {
      return htmlPage('Configuration Error', 'Unavailable', 'Server Google OAuth credentials missing.', '#EF4444');
    }

    const tokenResp = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: env.GOOGLE_CLIENT_ID,
        client_secret: env.GOOGLE_CLIENT_SECRET,
        code,
        code_verifier: row.code_verifier,
        grant_type: 'authorization_code',
        redirect_uri: `${url.origin}/api/auth/google/callback`,
      }),
    });

    if (!tokenResp.ok) {
      await db.prepare(`UPDATE oauth_states SET status = 'error', error_message = 'Google code exchange failed.' WHERE state = ?`).bind(state).run();
      return htmlPage('MUXIS Sign-In Failed', 'Token Exchange Failed', 'Google authorization failed. Return to MUXIS and try again.', '#EF4444');
    }

    const tokenData = (await tokenResp.json()) as { access_token?: string };
    const profileResp = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
      headers: { Authorization: `Bearer ${tokenData.access_token}` },
    });
    if (!profileResp.ok) {
      await db.prepare(`UPDATE oauth_states SET status = 'error', error_message = 'Failed to load Google profile.' WHERE state = ?`).bind(state).run();
      return htmlPage('MUXIS Sign-In Failed', 'Profile Load Failed', 'Could not read verified Google profile. Return to MUXIS.', '#EF4444');
    }

    const profile = (await profileResp.json()) as {
      sub?: string;
      email?: string;
      email_verified?: boolean;
      name?: string;
      picture?: string;
    };

    if (!profile.sub || !profile.email || profile.email_verified !== true) {
      return htmlPage('Unverified Google Email', 'Verification Needed', 'Your Google account must have a verified email address.', '#EF4444');
    }

    const userObj = await upsertGoogleUser(db, env, {
      googleSub: profile.sub,
      email: profile.email.toLowerCase(),
      displayName: profile.name || profile.email.split('@')[0],
      avatarUrl: profile.picture ?? null,
    });
    const jwt = await signJwt({ sub: userObj.id, email: userObj.email }, jwtSecret);

    await db
      .prepare(`UPDATE oauth_states SET status = 'complete', result_token = ?, result_user_json = ? WHERE state = ?`)
      .bind(jwt, JSON.stringify(userObj), state)
      .run();

    const safeRedirect =
      row.app_redirect && (row.app_redirect.startsWith('http://localhost:') || row.app_redirect.startsWith('muxis://'))
        ? `<script>setTimeout(function(){ window.location.href = ${JSON.stringify(row.app_redirect)}; }, 250);</script>`
        : '';

    return htmlPage(
      'MUXIS Cloud Connected',
      'Signed In with Google!',
      `Connected as <strong>${userObj.email}</strong>. You can close this browser tab and return to MUXIS.`,
      '#00FF88',
      safeRedirect
    );
  }

  // 7. Google OAuth State Poll (secure single-use session handoff for Desktop & Mobile)
  if (path === '/api/auth/google/poll' && request.method === 'POST') {
    let body: { state?: string; poll_secret?: string };
    try {
      body = await request.json();
    } catch {
      return err('Invalid JSON request body.', 400);
    }
    const state = (body.state ?? '').trim();
    const pollSecret = body.poll_secret ?? '';
    if (!state || pollSecret.length < 16) return err('Missing state or poll_secret.', 400);

    const row = await db
      .prepare('SELECT * FROM oauth_states WHERE state = ?')
      .bind(state)
      .first<{
        poll_secret_hash: string;
        status: string;
        result_token: string | null;
        result_user_json: string | null;
        error_message: string | null;
        expires_at: string;
      }>();

    if (!row) return err('Invalid or already claimed OAuth state.', 404);
    const providedHash = await sha256Hex(pollSecret);
    if (!constantTimeEqual(enc.encode(providedHash), enc.encode(row.poll_secret_hash))) {
      return err('Unauthorized OAuth poll secret.', 403);
    }

    if (row.status === 'pending') {
      if (new Date(row.expires_at).getTime() < Date.now()) {
        await db.prepare('DELETE FROM oauth_states WHERE state = ?').bind(state).run();
        return json({ status: 'expired' }, 200);
      }
      return json({ status: 'pending' }, 200);
    }

    await db.prepare('DELETE FROM oauth_states WHERE state = ?').bind(state).run();
    if (row.status === 'error') {
      return json({ status: 'error', error: row.error_message ?? 'Google login failed.' }, 200);
    }

    const parsedResult = row.result_user_json ? (JSON.parse(row.result_user_json) as Record<string, unknown>) : null;
    const ytToken = typeof parsedResult?._yt_access_token === 'string' ? parsedResult._yt_access_token : null;
    if (parsedResult) delete parsedResult._yt_access_token;

    return json({
      status: 'complete',
      access_token: row.result_token,
      user: parsedResult,
      ...(ytToken ? { youtube_access_token: ytToken } : {}),
    });
  }

  // 8. Google Direct Token Exchange (for client-owned Google OAuth Client ID via Custom Keys)
  if (path === '/api/auth/google/token' && request.method === 'POST') {
    let body: { id_token?: string; access_token?: string };
    try {
      body = await request.json();
    } catch {
      return err('Invalid JSON request body.', 400);
    }

    let googleSub = '';
    let email = '';
    let name = '';
    let avatar: string | null = null;

    if (body.id_token) {
      const verifyResp = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(body.id_token)}`);
      if (!verifyResp.ok) return err('Invalid or expired Google ID token.', 401);
      const info = (await verifyResp.json()) as {
        sub?: string;
        email?: string;
        email_verified?: string;
        name?: string;
        picture?: string;
      };
      if (!info.sub || !info.email || info.email_verified !== 'true') {
        return err('Google account email is not verified.', 401);
      }
      googleSub = info.sub;
      email = info.email.toLowerCase();
      name = info.name || email.split('@')[0];
      avatar = info.picture ?? null;
    } else if (body.access_token) {
      const profileResp = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
        headers: { Authorization: `Bearer ${body.access_token}` },
      });
      if (!profileResp.ok) return err('Invalid Google access token.', 401);
      const info = (await profileResp.json()) as {
        sub?: string;
        email?: string;
        email_verified?: boolean;
        name?: string;
        picture?: string;
      };
      if (!info.sub || !info.email || info.email_verified !== true) {
        return err('Google account email is not verified.', 401);
      }
      googleSub = info.sub;
      email = info.email.toLowerCase();
      name = info.name || email.split('@')[0];
      avatar = info.picture ?? null;
    } else {
      return err('Provide Google id_token or access_token.', 400);
    }

    const userObj = await upsertGoogleUser(db, env, {
      googleSub,
      email,
      displayName: name,
      avatarUrl: avatar,
    });
    const jwt = await signJwt({ sub: userObj.id, email: userObj.email }, jwtSecret);
    return json({ access_token: jwt, user: userObj }, 200);
  }

  // --- AUTHENTICATED USER & CLOUD SYNC ENDPOINTS ---
  const authHeader = request.headers.get('Authorization') ?? '';
  const bearer = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '';
  const payload = bearer ? await verifyJwt(bearer, jwtSecret) : null;
  const userId = typeof payload?.sub === 'string' ? payload.sub : null;

  if (!userId) {
    return err('Unauthorized or expired session. Please sign in again.', 401);
  }

  if (path === '/api/auth/me' && request.method === 'GET') {
    const row = await db.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first<UserRow>();
    if (!row) return err('User account not found.', 404);
    return json({ user: serializeUser(row, env) }, 200);
  }

  if (path === '/api/auth/pwa/status' && request.method === 'GET') {
    const row = await db.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first<UserRow>();
    if (!row) return err('User account not found.', 404);
    const user = serializeUser(row, env);
    const requireApproval = await isApprovalRequired(db);
    return json(
      {
        ok: true,
        approval_status: requireApproval ? user.pwa_approval_status : 'approved',
        raw_approval_status: user.pwa_approval_status,
        is_admin: user.is_admin,
        require_approval: requireApproval,
        note: user.pwa_note,
        user,
      },
      200
    );
  }

  if (path === '/api/auth/refresh' && request.method === 'POST') {
    const row = await db.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first<UserRow>();
    if (!row) return err('User account not found.', 404);
    const token = await signJwt({ sub: row.id, email: row.email }, jwtSecret);
    return json({ access_token: token, user: serializeUser(row, env) }, 200);
  }

  // --- ADMIN PANEL API (Owner / Co-Admin Only) ---
  if (path.startsWith('/api/admin/')) {
    const adminRow = await db.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first<UserRow>();
    if (!adminRow) return err('Admin user not found.', 404);
    const serializedAdmin = serializeUser(adminRow, env);
    if (!serializedAdmin.is_admin) {
      return err('Administrator approval privileges required.', 403);
    }

    if (path === '/api/admin/overview' && request.method === 'GET') {
      const usersRes = await db
        .prepare(
          `SELECT id, email, display_name, avatar_url, auth_provider, subscription_tier,
                  pwa_approval_status, is_admin, pwa_approved_at, pwa_approved_by, pwa_note,
                  created_at, updated_at
           FROM users
           ORDER BY CASE pwa_approval_status WHEN 'pending' THEN 0 WHEN 'rejected' THEN 1 ELSE 2 END, created_at DESC
           LIMIT 250`
        )
        .all<UserRow>();
      const users = (usersRes.results ?? []).map((u) => ({
        ...serializeUser(u, env),
        pwa_approved_at: u.pwa_approved_at ?? null,
        pwa_approved_by: u.pwa_approved_by ?? null,
        created_at: u.created_at ?? null,
        updated_at: u.updated_at ?? null,
      }));
      const requireApproval = await isApprovalRequired(db);
      const stats = {
        total: users.length,
        pending: users.filter((u) => u.pwa_approval_status === 'pending').length,
        approved: users.filter((u) => u.pwa_approval_status === 'approved').length,
        rejected: users.filter((u) => u.pwa_approval_status === 'rejected').length,
        admins: users.filter((u) => u.is_admin).length,
      };
      const flagsRes = await db
        .prepare(
          `SELECT key, value FROM app_config_flags
           WHERE key IN ('spotify_client_id', 'soundcloud_client_id', 'adsense_enabled', 'adsense_client_id', 'adsense_slot_home', 'adsense_slot_download', 'adsense_slot_docs')`
        )
        .all<{ key: string; value: string }>();
      const flagsMap: Record<string, string> = {};
      for (const f of flagsRes.results ?? []) flagsMap[f.key] = f.value;
      return json(
        {
          ok: true,
          require_pwa_approval: requireApproval,
          spotify_client_id: flagsMap.spotify_client_id || '',
          soundcloud_client_id: flagsMap.soundcloud_client_id || '',
          adsense_enabled: flagsMap.adsense_enabled === 'true',
          adsense_client_id: flagsMap.adsense_client_id || '',
          adsense_slot_home: flagsMap.adsense_slot_home || '',
          adsense_slot_download: flagsMap.adsense_slot_download || '',
          adsense_slot_docs: flagsMap.adsense_slot_docs || '',
          stats,
          users,
          admin: serializedAdmin,
        },
        200
      );
    }

    if (path === '/api/admin/settings' && request.method === 'POST') {
      let body: {
        require_pwa_approval?: boolean;
        spotify_client_id?: string;
        soundcloud_client_id?: string;
        adsense_enabled?: boolean;
        adsense_client_id?: string;
        adsense_slot_home?: string;
        adsense_slot_download?: string;
        adsense_slot_docs?: string;
      };
      try {
        body = await request.json();
      } catch {
        return err('Invalid JSON request body.', 400);
      }
      const now = new Date().toISOString();
      const upserts: D1PreparedStatement[] = [];
      let nextRequire = true;
      const pushFlag = (key: string, val: string) => {
        upserts.push(
          db
            .prepare(
              `INSERT INTO app_config_flags (key, value, updated_at) VALUES (?, ?, ?)
               ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`
            )
            .bind(key, val, now)
        );
      };
      if (typeof body.require_pwa_approval === 'boolean') {
        nextRequire = body.require_pwa_approval;
        pushFlag('require_pwa_approval', body.require_pwa_approval ? 'true' : 'false');
      }
      if (typeof body.spotify_client_id === 'string') pushFlag('spotify_client_id', body.spotify_client_id.trim());
      if (typeof body.soundcloud_client_id === 'string') pushFlag('soundcloud_client_id', body.soundcloud_client_id.trim());
      if (typeof body.adsense_enabled === 'boolean') pushFlag('adsense_enabled', body.adsense_enabled ? 'true' : 'false');
      if (typeof body.adsense_client_id === 'string') {
        const cid = body.adsense_client_id.trim();
        if (cid && !/^ca-pub-\d{10,20}$/.test(cid)) {
          return err('AdSense Publisher ID must look like ca-pub-1234567890123456.', 400);
        }
        pushFlag('adsense_client_id', cid);
      }
      if (typeof body.adsense_slot_home === 'string') pushFlag('adsense_slot_home', body.adsense_slot_home.trim().replace(/\D+/g, ''));
      if (typeof body.adsense_slot_download === 'string') pushFlag('adsense_slot_download', body.adsense_slot_download.trim().replace(/\D+/g, ''));
      if (typeof body.adsense_slot_docs === 'string') pushFlag('adsense_slot_docs', body.adsense_slot_docs.trim().replace(/\D+/g, ''));

      if (upserts.length) await db.batch(upserts);
      return json(
        {
          ok: true,
          require_pwa_approval: nextRequire,
          spotify_client_id: body.spotify_client_id?.trim(),
          soundcloud_client_id: body.soundcloud_client_id?.trim(),
          adsense_enabled: body.adsense_enabled,
          adsense_client_id: body.adsense_client_id?.trim(),
          updated_at: now,
        },
        200
      );
    }

    const statusMatch = path.match(/^\/api\/admin\/users\/([^/]+)\/status$/);
    if (statusMatch && request.method === 'POST') {
      const targetId = decodeURIComponent(statusMatch[1]);
      let body: { status?: string; note?: string };
      try {
        body = await request.json();
      } catch {
        return err('Invalid JSON request body.', 400);
      }
      const nextStatus = (body.status ?? '').trim().toLowerCase();
      if (!['pending', 'approved', 'rejected'].includes(nextStatus)) {
        return err('Status must be pending, approved, or rejected.', 400);
      }
      const target = await db.prepare('SELECT * FROM users WHERE id = ?').bind(targetId).first<UserRow>();
      if (!target) return err('Target user not found.', 404);
      if (isOwnerAdmin(target.email, env) && nextStatus !== 'approved') {
        return err('Owner admin accounts cannot be unapproved.', 400);
      }
      const now = new Date().toISOString();
      const note = typeof body.note === 'string' ? body.note.trim().slice(0, 240) : (target.pwa_note ?? null);
      await db
        .prepare(
          `UPDATE users
           SET pwa_approval_status = ?, pwa_approved_at = ?, pwa_approved_by = ?, pwa_note = ?, updated_at = ?
           WHERE id = ?`
        )
        .bind(nextStatus, nextStatus === 'approved' ? now : null, serializedAdmin.email, note, now, targetId)
        .run();
      const updated = await db.prepare('SELECT * FROM users WHERE id = ?').bind(targetId).first<UserRow>();
      return json({ ok: true, user: updated ? serializeUser(updated, env) : null }, 200);
    }

    const adminToggleMatch = path.match(/^\/api\/admin\/users\/([^/]+)\/admin$/);
    if (adminToggleMatch && request.method === 'POST') {
      const targetId = decodeURIComponent(adminToggleMatch[1]);
      let body: { is_admin?: boolean };
      try {
        body = await request.json();
      } catch {
        return err('Invalid JSON request body.', 400);
      }
      const target = await db.prepare('SELECT * FROM users WHERE id = ?').bind(targetId).first<UserRow>();
      if (!target) return err('Target user not found.', 404);
      const nextAdmin = Boolean(body.is_admin);
      if (!nextAdmin && (targetId === userId || isOwnerAdmin(target.email, env))) {
        return err('Cannot remove admin privileges from yourself or system owner.', 400);
      }
      const now = new Date().toISOString();
      await db
        .prepare(
          `UPDATE users
           SET is_admin = ?, pwa_approval_status = CASE WHEN ? = 1 THEN 'approved' ELSE pwa_approval_status END, updated_at = ?
           WHERE id = ?`
        )
        .bind(nextAdmin ? 1 : 0, nextAdmin ? 1 : 0, now, targetId)
        .run();
      const updated = await db.prepare('SELECT * FROM users WHERE id = ?').bind(targetId).first<UserRow>();
      return json({ ok: true, user: updated ? serializeUser(updated, env) : null }, 200);
    }

    const deleteMatch = path.match(/^\/api\/admin\/users\/([^/]+)$/);
    if (deleteMatch && request.method === 'DELETE') {
      const targetId = decodeURIComponent(deleteMatch[1]);
      if (targetId === userId) return err('Cannot delete your own active admin account here.', 400);
      const target = await db.prepare('SELECT email FROM users WHERE id = ?').bind(targetId).first<{ email: string }>();
      if (!target) return err('Target user not found.', 404);
      if (isOwnerAdmin(target.email, env)) return err('System owner accounts cannot be deleted.', 400);
      await db.prepare('DELETE FROM users WHERE id = ?').bind(targetId).run();
      return json({ ok: true, deleted: true, id: targetId }, 200);
    }

    return err('Unsupported admin route.', 404);
  }

  // Enforce server-side PWA approval on D1 sync calls from web/iOS PWA client
  if (path.startsWith('/api/sync/') && (request.headers.get('X-Muxis-Client') ?? '').toLowerCase() === 'pwa') {
    const needApproval = await isApprovalRequired(db);
    if (needApproval) {
      const syncRow = await db.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first<UserRow>();
      if (!syncRow) return err('User account not found.', 404);
      const serialized = serializeUser(syncRow, env);
      if (!serialized.is_admin && serialized.pwa_approval_status !== 'approved') {
        return json(
          {
            error: 'Your PWA account is awaiting admin approval.',
            code: 'PWA_APPROVAL_REQUIRED',
            approval_status: serialized.pwa_approval_status,
          },
          403
        );
      }
    }
  }

  if (path === '/api/auth/regenerate-recovery' && request.method === 'POST') {
    const nextRecovery = generateRecoveryKey();
    const nextRecoveryHash = await sha256Hex(normalizeRecoveryKey(nextRecovery));
    await db
      .prepare('UPDATE users SET recovery_code_hash = ?, updated_at = ? WHERE id = ?')
      .bind(nextRecoveryHash, new Date().toISOString(), userId)
      .run();
    return json({ recovery_key: nextRecovery }, 200);
  }

  if (path === '/api/auth/account' && request.method === 'DELETE') {
    await db.prepare('DELETE FROM users WHERE id = ?').bind(userId).run();
    return json({ deleted: true }, 200);
  }

  // Cloud Sync Pull
  if (path === '/api/sync/pull' && request.method === 'GET') {
    const favRes = await db
      .prepare('SELECT track_uri, title, artist, album, duration_ms, updated_at FROM favorites WHERE user_id = ? AND is_deleted = 0')
      .bind(userId)
      .all();
    const plRes = await db
      .prepare('SELECT id, title, updated_at FROM playlists WHERE user_id = ? AND is_deleted = 0')
      .bind(userId)
      .all<{ id: string; title: string; updated_at: string }>();

    const playlistsWithTracks = [];
    for (const pl of plRes.results ?? []) {
      const trRes = await db
        .prepare('SELECT track_uri, title, artist, album, duration_ms, position_index FROM playlist_tracks WHERE playlist_id = ? ORDER BY position_index ASC')
        .bind(pl.id)
        .all();
      playlistsWithTracks.push({
        id: pl.id,
        title: pl.title,
        updated_at: pl.updated_at,
        tracks: trRes.results ?? [],
      });
    }

    const histRes = await db
      .prepare('SELECT track_uri, title, artist, album, duration_ms, played_at FROM listening_history WHERE user_id = ? ORDER BY played_at DESC LIMIT 50')
      .bind(userId)
      .all();

    const devicesRes = await db
      .prepare('SELECT device_name, platform, client_version, last_active_at FROM user_devices WHERE user_id = ? ORDER BY last_active_at DESC LIMIT 12')
      .bind(userId)
      .all();

    const settings = await db.prepare('SELECT * FROM user_settings WHERE user_id = ?').bind(userId).first();
    return json({
      favorites: favRes.results ?? [],
      playlists: playlistsWithTracks,
      history: histRes.results ?? [],
      devices: devicesRes.results ?? [],
      settings: settings ?? null,
    });
  }

  // Cloud Sync Push
  if (path === '/api/sync/push' && request.method === 'POST') {
    let body: {
      device?: { name?: string; platform?: string; client_version?: string };
      mutations?: Array<{ entityType?: string; action?: string; data?: Record<string, unknown> }>;
      favorites?: Array<{ track_uri: string; title: string; artist: string; album?: string; duration_ms?: number }>;
      history?: Array<{ track_uri: string; title: string; artist: string; album?: string; duration_ms?: number; played_at?: string }>;
      playlists?: Array<{
        title: string;
        tracks: Array<{ track_uri: string; title: string; artist: string; album?: string; duration_ms?: number }>;
      }>;
      settings?: {
        theme_mode?: string;
        dark_preset?: string;
        light_preset?: string;
        accent_taste?: string;
        audio_quality?: string;
        eq_preset?: string;
      };
    };
    try {
      body = await request.json();
    } catch {
      return err('Invalid JSON sync payload.', 400);
    }

    const now = new Date().toISOString();
    const stmts: D1PreparedStatement[] = [];

    if (body.device?.name && body.device?.platform) {
      stmts.push(
        db
          .prepare(
            `INSERT INTO user_devices (id, user_id, device_name, platform, client_version, last_active_at)
             VALUES (?, ?, ?, ?, ?, ?)
             ON CONFLICT(user_id, device_name, platform) DO UPDATE SET
               client_version = excluded.client_version,
               last_active_at = excluded.last_active_at`
          )
          .bind(
            crypto.randomUUID(),
            userId,
            body.device.name,
            body.device.platform,
            body.device.client_version ?? '1.2.8',
            now
          )
      );
    }

    for (const mut of body.mutations ?? []) {
      if (mut.entityType === 'favorite' && mut.action === 'delete' && typeof mut.data?.track_uri === 'string') {
        stmts.push(
          db
            .prepare('UPDATE favorites SET is_deleted = 1, updated_at = ? WHERE user_id = ? AND track_uri = ?')
            .bind(now, userId, mut.data.track_uri)
        );
      } else if (mut.entityType === 'playlist' && mut.action === 'delete' && typeof mut.data?.title === 'string') {
        stmts.push(
          db
            .prepare('UPDATE playlists SET is_deleted = 1, updated_at = ? WHERE user_id = ? AND title = ?')
            .bind(now, userId, mut.data.title)
        );
      }
    }

    for (const fav of body.favorites ?? []) {
      if (!fav.track_uri) continue;
      stmts.push(
        db
          .prepare(
            `INSERT INTO favorites (id, user_id, track_uri, title, artist, album, duration_ms, is_deleted, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)
             ON CONFLICT(user_id, track_uri) DO UPDATE SET
               title = excluded.title,
               artist = excluded.artist,
               album = excluded.album,
               duration_ms = excluded.duration_ms,
               is_deleted = 0,
               updated_at = excluded.updated_at`
          )
          .bind(
            crypto.randomUUID(),
            userId,
            fav.track_uri,
            fav.title || 'Unknown Track',
            fav.artist || 'Unknown Artist',
            fav.album ?? '',
            fav.duration_ms ?? 0,
            now
          )
      );
    }

    for (const h of (body.history ?? []).slice(0, 50)) {
      if (!h.track_uri) continue;
      stmts.push(
        db
          .prepare(
            `INSERT INTO listening_history (id, user_id, track_uri, title, artist, album, duration_ms, played_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)
             ON CONFLICT(user_id, track_uri) DO UPDATE SET
               title = excluded.title,
               artist = excluded.artist,
               album = excluded.album,
               duration_ms = excluded.duration_ms,
               played_at = CASE WHEN excluded.played_at > listening_history.played_at THEN excluded.played_at ELSE listening_history.played_at END`
          )
          .bind(
            crypto.randomUUID(),
            userId,
            h.track_uri,
            h.title || 'Unknown Track',
            h.artist || 'Unknown Artist',
            h.album ?? '',
            h.duration_ms ?? 0,
            h.played_at ?? now
          )
      );
    }

    if (body.settings) {
      stmts.push(
        db
          .prepare(
            `INSERT INTO user_settings (user_id, theme_mode, dark_preset, light_preset, accent_taste, audio_quality, eq_preset, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)
             ON CONFLICT(user_id) DO UPDATE SET
               theme_mode = excluded.theme_mode,
               dark_preset = excluded.dark_preset,
               light_preset = excluded.light_preset,
               accent_taste = excluded.accent_taste,
               audio_quality = excluded.audio_quality,
               eq_preset = excluded.eq_preset,
               updated_at = excluded.updated_at`
          )
          .bind(
            userId,
            body.settings.theme_mode ?? 'dark',
            body.settings.dark_preset ?? 'obsidian_aurora',
            body.settings.light_preset ?? 'luminous_aurora',
            body.settings.accent_taste ?? 'preset_default',
            body.settings.audio_quality ?? 'FLAC 24-bit Lossless',
            body.settings.eq_preset ?? 'Prismatic Neon',
            now
          )
      );
    }

    if (stmts.length > 0) {
      await db.batch(stmts);
    }

    // Playlists + child tracks cleanly upserted sequentially
    for (const pl of body.playlists ?? []) {
      if (!pl.title) continue;
      await db
        .prepare(
          `INSERT INTO playlists (id, user_id, title, is_deleted, updated_at)
           VALUES (?, ?, ?, 0, ?)
           ON CONFLICT(user_id, title) DO UPDATE SET is_deleted = 0, updated_at = excluded.updated_at`
        )
        .bind(crypto.randomUUID(), userId, pl.title, now)
        .run();

      const plRow = await db
        .prepare('SELECT id FROM playlists WHERE user_id = ? AND title = ?')
        .bind(userId, pl.title)
        .first<{ id: string }>();

      if (plRow) {
        const trackStmts: D1PreparedStatement[] = [
          db.prepare('DELETE FROM playlist_tracks WHERE playlist_id = ?').bind(plRow.id),
        ];
        for (let i = 0; i < (pl.tracks ?? []).length; i++) {
          const t = pl.tracks[i];
          trackStmts.push(
            db
              .prepare(
                `INSERT OR REPLACE INTO playlist_tracks (id, playlist_id, track_uri, title, artist, album, duration_ms, position_index)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
              )
              .bind(
                crypto.randomUUID(),
                plRow.id,
                t.track_uri,
                t.title || 'Unknown Track',
                t.artist || 'Unknown Artist',
                t.album ?? '',
                t.duration_ms ?? 0,
                i
              )
          );
        }
        await db.batch(trackStmts);
      }
    }

    return json({ synced: true, updated_at: now }, 200);
  }

  return err('Unsupported auth/sync route.', 404);
}

async function upsertGoogleUser(
  db: D1Database,
  env: CloudEnv,
  input: { googleSub: string; email: string; displayName: string; avatarUrl: string | null }
) {
  const now = new Date().toISOString();
  const ownerAdmin = isOwnerAdmin(input.email, env);
  const bySub = await db.prepare('SELECT * FROM users WHERE google_sub = ?').bind(input.googleSub).first<UserRow>();
  if (bySub) {
    await db
      .prepare(
        `UPDATE users
         SET display_name = ?, avatar_url = ?,
             is_admin = CASE WHEN ? = 1 THEN 1 ELSE is_admin END,
             pwa_approval_status = CASE WHEN ? = 1 THEN 'approved' ELSE pwa_approval_status END,
             updated_at = ?
         WHERE id = ?`
      )
      .bind(input.displayName, input.avatarUrl ?? bySub.avatar_url, ownerAdmin ? 1 : 0, ownerAdmin ? 1 : 0, now, bySub.id)
      .run();
    const fresh = await db.prepare('SELECT * FROM users WHERE id = ?').bind(bySub.id).first<UserRow>();
    return serializeUser(fresh ?? { ...bySub, display_name: input.displayName, avatar_url: input.avatarUrl ?? bySub.avatar_url }, env);
  }

  const byEmail = await db.prepare('SELECT * FROM users WHERE email = ?').bind(input.email).first<UserRow>();
  if (byEmail) {
    await db
      .prepare(
        `UPDATE users
         SET google_sub = ?, avatar_url = COALESCE(?, avatar_url), auth_provider = 'google', email_verified = 1,
             is_admin = CASE WHEN ? = 1 THEN 1 ELSE is_admin END,
             pwa_approval_status = CASE WHEN ? = 1 THEN 'approved' ELSE pwa_approval_status END,
             updated_at = ?
         WHERE id = ?`
      )
      .bind(input.googleSub, input.avatarUrl, ownerAdmin ? 1 : 0, ownerAdmin ? 1 : 0, now, byEmail.id)
      .run();
    const fresh = await db.prepare('SELECT * FROM users WHERE id = ?').bind(byEmail.id).first<UserRow>();
    return serializeUser(
      fresh ?? {
        ...byEmail,
        google_sub: input.googleSub,
        avatar_url: input.avatarUrl ?? byEmail.avatar_url,
        auth_provider: 'google',
      },
      env
    );
  }

  const needApproval = ownerAdmin ? false : await isApprovalRequired(db);
  const approvalStatus = ownerAdmin || !needApproval ? 'approved' : 'pending';
  const newId = crypto.randomUUID();
  await db.batch([
    db
      .prepare(
        `INSERT INTO users (id, email, display_name, avatar_url, auth_provider, google_sub, email_verified, subscription_tier, pwa_approval_status, is_admin, created_at, updated_at)
         VALUES (?, ?, ?, ?, 'google', ?, 1, 'free', ?, ?, ?, ?)`
      )
      .bind(newId, input.email, input.displayName, input.avatarUrl, input.googleSub, approvalStatus, ownerAdmin ? 1 : 0, now, now),
    db.prepare('INSERT OR IGNORE INTO user_settings (user_id, updated_at) VALUES (?, ?)').bind(newId, now),
  ]);

  return {
    id: newId,
    email: input.email,
    display_name: input.displayName,
    avatar_url: input.avatarUrl,
    subscription_tier: 'free',
    auth_provider: 'google',
    is_admin: ownerAdmin,
    pwa_approval_status: approvalStatus,
    pwa_note: null,
  };
}
