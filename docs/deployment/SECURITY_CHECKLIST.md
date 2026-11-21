# Security & Privacy Checklist — MUXIS

This document serves as the official security and privacy verification protocol for **MUXIS**. Every release candidate must satisfy these audit items prior to public distribution.

---

## 1. Local Music Privacy & Non-Upload Guarantee

> **CORE PRINCIPLE:**
> Local music tracks stored on the user's hard drive or mobile storage belong exclusively to the user. MUXIS never uploads, streams, or indexes local audio data to any remote server or cloud bucket.

- [x] **File System Isolation:** Local file paths (e.g. `C:\Users\...\Music\track.mp3` or `/storage/emulated/0/Music/track.mp3`) are strictly processed by `LocalLibraryScanner` and stored in the local SQLite database (`muxis_local.db`).
- [x] **Portable Cloud Identifiers:** When synchronizing playlists to Supabase, `SyncEngine` replaces local absolute filesystem paths with portable metadata identifiers (`meta:artist_title_album`, `isrc:...`, or `public:...`).
- [x] **Zero Audio Cloud Ingestion:** Neither Supabase Storage nor Cloudflare R2 has buckets or endpoints accepting audio files.
- [x] **Cloudflare Worker Type Enforcement:** The Cloudflare Worker (`cloudflare/src/index.ts`) rejects any upload payload that does not match strict visual image types (`image/jpeg`, `image/png`, `image/webp`). Requests containing audio MIME types receive an immediate `415 Prohibited Content Type` response.

---

## 2. Supabase Row-Level Security (RLS) Verification

Row-Level Security is strictly enforced on all public schema tables in PostgreSQL:

- [x] `profiles`: Users may only `SELECT` and `UPDATE` their own profile where `id = auth.uid()`.
- [x] `user_devices`: Users may only manage devices where `user_id = auth.uid()`.
- [x] `playlists`: Users may only `SELECT`, `INSERT`, `UPDATE`, and `DELETE` playlists where `user_id = auth.uid()`.
- [x] `playlist_tracks`: Operations are restricted to tracks inside playlists owned by the authenticated user (`playlist_id IN (SELECT id FROM playlists WHERE user_id = auth.uid())`).
- [x] `favorites`: Users may only view and toggle favorites where `user_id = auth.uid()`.
- [x] `listening_history`: Scrobbles and listening statistics are restricted to `user_id = auth.uid()`.
- [x] `user_settings`: Settings rows are restricted to `user_id = auth.uid()`.
- [x] `sync_metadata`: Sync timestamps and version tracking rows are restricted to `user_id = auth.uid()`.

---

## 3. Secret & Credential Management

- [x] **No Secrets in Source Control:** `.gitignore` actively excludes `.env`, `*.key`, `*.keystore`, `*.jks`, `*.p12`, `*.pfx`, `*.pem`, and `credentials.json`.
- [x] **Template Safety:** Only `.env.example` is checked into version control, with empty or dummy placeholder values.
- [x] **Safe Public Anon Key:** The `SUPABASE_ANON_KEY` is designed to be public and works exclusively in tandem with PostgreSQL RLS policies.
- [x] **Service Role Key Seclusion:** The `SUPABASE_SERVICE_ROLE_KEY` bypasses RLS and is **never** embedded in client binaries or checked into Git. It is restricted to server-side environments (Supabase Edge Functions).

---

## 4. Account Deletion & GDPR/CCPA Compliance

- [x] **Self-Service Deletion:** Users can permanently delete their account directly within the application via `AccountDialog` -> **Delete Account**.
- [x] **Cascade Purge:** Foreign keys (`ON DELETE CASCADE`) ensure that deleting a user profile automatically deletes all devices, playlists, playlist tracks, favorites, history, and preferences.
- [x] **Server-Side Admin Purge:** The `delete-account` Supabase Edge Function purges the user from `auth.users`, invalidating all active refresh tokens and sessions.

---

## 5. Transport & Network Security

- [x] **TLS 1.3 Strict:** All network communication with Supabase and Cloudflare uses HTTPS with modern cipher suites.
- [x] **HSTS:** Strict-Transport-Security (`max-age=31536000; includeSubDomains; preload`) is enforced by the Cloudflare Worker.
- [x] **Content-Security-Policy & Anti-Sniffing:** Worker returns `X-Content-Type-Options: nosniff` and `X-Frame-Options: DENY`.
