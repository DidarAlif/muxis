-- Post-login cloud activity, listening history & EQ DSP preferences in Cloudflare D1

ALTER TABLE user_settings ADD COLUMN eq_preset TEXT NOT NULL DEFAULT 'Prismatic Neon';

CREATE TABLE IF NOT EXISTS listening_history (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  track_uri TEXT NOT NULL,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  album TEXT DEFAULT '',
  duration_ms INTEGER NOT NULL DEFAULT 0,
  played_at TEXT NOT NULL,
  UNIQUE(user_id, track_uri)
);

CREATE INDEX IF NOT EXISTS idx_history_user_recent ON listening_history(user_id, played_at DESC);
