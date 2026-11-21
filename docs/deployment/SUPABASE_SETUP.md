# Supabase Backend Configuration Guide — MUXIS

This guide outlines the production deployment, schema migration, authentication configuration, and disaster recovery procedures for the **MUXIS** cloud backend on Supabase.

---

## 1. Prerequisites

- A Supabase account ([supabase.com](https://supabase.com)).
- Supabase CLI installed locally (optional, or use the Supabase Web Dashboard):
  ```bash
  npm install -g supabase
  ```
- Project repository root: `E:\Desktop\muxis_player`.

---

## 2. Project Provisioning

1. Log in to the [Supabase Dashboard](https://app.supabase.com).
2. Click **New project**.
3. Set:
   - **Name:** `Muxis-Production`
   - **Database Password:** Generate a high-entropy 24+ character password and store in a secure password manager.
   - **Region:** Select a low-latency region closest to your target audience (e.g. `us-east-1` or `eu-west-1`).
   - **Pricing Plan:** Free tier (upgrades automatically supported).
4. Wait 1–2 minutes for the database to provision.

---

## 3. Database Schema Migration

### Option A: Using the Supabase CLI (Recommended)

Link your local project and execute migrations:

```bash
cd E:\Desktop\muxis_player

# 1. Authenticate Supabase CLI
supabase login

# 2. Link your remote project (replace <project-ref> with your Supabase Project ID)
supabase link --project-ref <project-ref>

# 3. Apply the initial migration
supabase db push
```

### Option B: Using the Supabase Web Dashboard SQL Editor

1. Open your project on the Supabase Dashboard.
2. In the left navigation, click **SQL Editor**.
3. Click **New query**.
4. Open `supabase/migrations/20261121000001_initial_schema.sql` on your machine, copy all contents, and paste into the SQL Editor.
5. Click **Run**.
6. Verify output confirms: `Success. No rows returned`.

---

## 4. Tables Created & Schema Verification

| Table Name | Purpose | RLS Status |
|---|---|---|
| `profiles` | User profile, display name, avatar URL, tier | Enabled (own row read/update) |
| `user_devices` | Registered desktop & mobile client devices | Enabled (own device management) |
| `playlists` | Cloud synchronized playlists | Enabled (own playlists read/write) |
| `playlist_tracks`| Portable track references in playlists | Enabled (own track management) |
| `favorites` | Favorited tracks, albums, and artists | Enabled (own favorites read/write) |
| `listening_history` | Playback statistics and scrobbles | Enabled (own history read/write) |
| `user_settings` | Cross-device synced preferences | Enabled (own settings read/write) |
| `sync_metadata` | Monotonic version numbers for LWW sync | Enabled (system/trigger maintained) |

---

## 5. Authentication Configuration

### 5.1 Email & Password Auth

1. Go to **Authentication** -> **Providers** -> **Email**.
2. **Enable Email provider:** Toggle `ON`.
3. **Confirm email:**
   - For initial testing/staging: Can be toggled `OFF` for instant sign-ins.
   - For production: Toggle `ON`.
4. **Secure password requirements:**
   - Minimum length: 8 characters.
   - Require uppercase, lowercase, numbers, and symbols.

### 5.2 Google OAuth Configuration

1. In Google Cloud Console, create an OAuth 2.0 Client ID for Web / Desktop.
2. Add Authorized Redirect URI:
   `https://<project-ref>.supabase.co/auth/v1/callback`
3. In Supabase Dashboard -> **Authentication** -> **Providers** -> **Google**:
   - Toggle `ON`.
   - Enter **Client ID** and **Client Secret**.
   - Click **Save**.

### 5.3 Apple OAuth Configuration

1. In Apple Developer Portal, configure "Sign in with Apple" Service ID.
2. Add Return URL:
   `https://<project-ref>.supabase.co/auth/v1/callback`
3. In Supabase Dashboard -> **Authentication** -> **Providers** -> **Apple**:
   - Toggle `ON`.
   - Enter **Service ID**, **Team ID**, **Key ID**, and private key (`.p8`).
   - Click **Save**.

### 5.4 URL Configuration & Deep Linking

1. Go to **Authentication** -> **URL Configuration**.
2. **Site URL:** `https://muxis.app`
3. **Redirect URLs:** Add the following list:
   - `muxis://auth-callback` (Muxis Desktop & Mobile deep-link scheme)
   - `https://muxis.app/auth/callback`
   - `http://localhost:3000/auth/callback` (Local testing)
   - `http://localhost:8080/auth/callback`

---

## 6. Client Configuration

Obtain your API credentials from **Project Settings** -> **API**:
- **Project URL:** `https://<project-ref>.supabase.co`
- **anon / public key:** `eyJhbGciOi...` (Safe to distribute in application bundles)
- **service_role key:** `eyJhbGciOi...` (**NEVER** expose to the client; server/CI only)

Add them to `E:\Desktop\muxis_player\.env` or pass via `--dart-define`:
```bash
SUPABASE_URL=https://<your-project-ref>.supabase.co
SUPABASE_ANON_KEY=eyJh...
```

---

## 7. Disaster Recovery & Rollback

If a migration needs to be reverted or reset:
1. Execute `supabase/migrations/20261121000001_rollback.sql` in the SQL Editor or via CLI:
   ```bash
   supabase db reset
   ```
2. The rollback script cleanly drops all created tables, triggers, helper functions, and RLS policies in topological dependency order without corrupting Supabase system schemas (`auth.*`).
