-- MUXIS Installable PWA Approval System & Admin Role Control

ALTER TABLE users ADD COLUMN pwa_approval_status TEXT NOT NULL DEFAULT 'pending';
ALTER TABLE users ADD COLUMN is_admin INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN pwa_approved_at TEXT;
ALTER TABLE users ADD COLUMN pwa_approved_by TEXT;
ALTER TABLE users ADD COLUMN pwa_note TEXT;

CREATE INDEX IF NOT EXISTS idx_users_pwa_status ON users(pwa_approval_status, created_at DESC);

UPDATE users
SET is_admin = 1, pwa_approval_status = 'approved', pwa_approved_by = 'system-owner-seed'
WHERE lower(email) IN ('fbalif123@gmail.com', 'a.leaf.organization@gmail.com');

CREATE TABLE IF NOT EXISTS app_config_flags (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

INSERT OR IGNORE INTO app_config_flags (key, value, updated_at)
VALUES ('require_pwa_approval', 'true', '2026-11-28T00:00:00Z');
