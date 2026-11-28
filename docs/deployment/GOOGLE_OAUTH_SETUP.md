# Google 1-Click OAuth Setup Guide — MUXIS Cloud (Cloudflare Worker + D1)

MUXIS Cloud authentication is powered by your deployed Cloudflare Worker (`muxis-api-worker`) and D1 SQLite database (`muxis-cloud-db`), which already implement Google OAuth 2.0 + PKCE + single-use session handoff across **Windows, macOS, Linux, Android, and iPhone (iOS)**.

Right now, `GET https://muxis-api-worker.a-leaf-org.workers.dev/api/auth/config` returns `"google_oauth_enabled": false` solely because `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` have not been stored on the Worker yet.

---

## Step 1: Create Google OAuth 2.0 Credentials

1. Open [Google Cloud Console -> APIs & Services -> Credentials](https://console.cloud.google.com/apis/credentials).
2. Create or select your Google Cloud project (for example, `MUXIS Cloud`).
3. If prompted, configure **OAuth consent screen** (Google Auth Platform -> Audience):
   - User Type / Audience: **External**
   - App name: `MUXIS`
   - User support email & developer contact email: your Gmail address
   - Scopes: keep `openid`, `email`, and `profile`
   - **Publishing status:** Click **Publish App** (or add test Gmail addresses under *Test users* while testing).
4. Go to **Clients -> Create OAuth client ID**:
   - **Application type:** `Web application`
   - **Name:** `MUXIS Cloud Worker`
   - **Authorized JavaScript origins:**
     ```text
     https://muxis-api-worker.a-leaf-org.workers.dev
     ```
   - **Authorized redirect URIs:**
     ```text
     https://muxis-api-worker.a-leaf-org.workers.dev/api/auth/google/callback
     ```
     *(Optional: also add `http://localhost:8888/callback` if you want direct Desktop loopback fallback to work with the same Client ID.)*
5. Click **Create** and copy your **Client ID** and **Client Secret**.

---

## Step 2: Upload Secrets to Cloudflare Worker (`muxis-api-worker`)

### Option A: Terminal (`wrangler`) — Fastest
Run inside `E:\Desktop\muxis_player\cloudflare`:

```powershell
npx wrangler secret put GOOGLE_CLIENT_ID
npx wrangler secret put GOOGLE_CLIENT_SECRET
```

Paste each value when prompted. Secrets take effect immediately across all global edge locations.

### Option B: Cloudflare Dashboard UI
1. Open [Cloudflare Dashboard](https://dash.cloudflare.com) -> **Workers & Pages** -> **`muxis-api-worker`**.
2. Go to **Settings -> Variables and Secrets -> + Add**:
   - Type: **Secret** | Name: `GOOGLE_CLIENT_ID` | Value: your Google Client ID
   - Type: **Secret** | Name: `GOOGLE_CLIENT_SECRET` | Value: your Google Client Secret
3. Click **Save and Deploy**.

---

## Step 3: Verify Activation

Open or curl:

```text
https://muxis-api-worker.a-leaf-org.workers.dev/api/auth/config
```

Once both secrets are set, `google_oauth_enabled` turns `true`, and **Continue with Google / Sign up with Google (1-Click)** becomes active automatically inside MUXIS on Windows, macOS, Linux, Android, and iPhone without requiring an app rebuild.
