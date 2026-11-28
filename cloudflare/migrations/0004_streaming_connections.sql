-- MUXIS Streaming Platform Connections (YouTube Music, Spotify, SoundCloud) synced per user in D1

CREATE TABLE IF NOT EXISTS streaming_connections (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform TEXT NOT NULL CHECK(platform IN ('youtube', 'spotify', 'soundcloud')),
  is_connected INTEGER NOT NULL DEFAULT 1,
  display_name TEXT,
  avatar_url TEXT,
  plan_badge TEXT,
  credential_json TEXT,
  playlists_json TEXT NOT NULL DEFAULT '[]',
  liked_tracks_json TEXT NOT NULL DEFAULT '[]',
  recommended_tracks_json TEXT NOT NULL DEFAULT '[]',
  updated_at TEXT NOT NULL,
  UNIQUE(user_id, platform)
);

CREATE INDEX IF NOT EXISTS idx_streaming_connections_user ON streaming_connections(user_id, platform);
