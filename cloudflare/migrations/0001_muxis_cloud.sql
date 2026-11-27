-- MUXIS Cloud Auth & Cross-Device Sync Schema for Cloudflare D1

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  avatar_url TEXT,
  auth_provider TEXT NOT NULL DEFAULT 'email',
  google_sub TEXT UNIQUE,
  password_hash TEXT,
  password_salt TEXT,
  recovery_code_hash TEXT,
  email_verified INTEGER NOT NULL DEFAULT 1,
  subscription_tier TEXT NOT NULL DEFAULT 'free',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_google_sub ON users(google_sub);

CREATE TABLE IF NOT EXISTS user_devices (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_name TEXT NOT NULL,
  platform TEXT NOT NULL,
  client_version TEXT NOT NULL,
  last_active_at TEXT NOT NULL,
  UNIQUE(user_id, device_name, platform)
);

CREATE INDEX IF NOT EXISTS idx_user_devices_user ON user_devices(user_id);

CREATE TABLE IF NOT EXISTS playlists (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  UNIQUE(user_id, title)
);

CREATE INDEX IF NOT EXISTS idx_playlists_user ON playlists(user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS playlist_tracks (
  id TEXT PRIMARY KEY,
  playlist_id TEXT NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
  track_uri TEXT NOT NULL,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  album TEXT DEFAULT '',
  duration_ms INTEGER NOT NULL DEFAULT 0,
  position_index INTEGER NOT NULL DEFAULT 0,
  UNIQUE(playlist_id, track_uri)
);

CREATE INDEX IF NOT EXISTS idx_playlist_tracks_order ON playlist_tracks(playlist_id, position_index ASC);

CREATE TABLE IF NOT EXISTS favorites (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  track_uri TEXT NOT NULL,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  album TEXT DEFAULT '',
  duration_ms INTEGER NOT NULL DEFAULT 0,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  UNIQUE(user_id, track_uri)
);

CREATE INDEX IF NOT EXISTS idx_favorites_user ON favorites(user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS user_settings (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  theme_mode TEXT NOT NULL DEFAULT 'dark',
  dark_preset TEXT NOT NULL DEFAULT 'obsidian_aurora',
  light_preset TEXT NOT NULL DEFAULT 'luminous_aurora',
  accent_taste TEXT NOT NULL DEFAULT 'preset_default',
  audio_quality TEXT NOT NULL DEFAULT 'FLAC 24-bit Lossless',
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS oauth_states (
  state TEXT PRIMARY KEY,
  poll_secret_hash TEXT NOT NULL,
  code_verifier TEXT NOT NULL,
  app_redirect TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  result_token TEXT,
  result_user_json TEXT,
  error_message TEXT,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL
);
