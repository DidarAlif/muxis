# Google 1-Click OAuth Setup Architecture — MUXIS Cloud (Firebase Client + Cloudflare D1)

MUXIS Cloud authentication now supports **1-Click Google Sign-In / Sign-Up out-of-the-box** using:

1. **Firebase Auth Client (`muxis-cloud` / `https://muxis-cloud.web.app`)** — handles interactive Google Sign-In via official Firebase Auth (`googleSignIn` provider) cleanly across Desktop & Mobile browsers without manual Google Cloud OAuth console steps.
2. **Cloudflare Worker (`muxis-api-worker`) + Cloudflare D1 (`muxis-cloud-db`)** — cryptographically verifies the Firebase ID token via `identitytoolkit.googleapis.com/v1/accounts:lookup`, and stores **all** user data in Cloudflare D1:
   - User accounts & Google profile metadata (`users`)
   - Cross-device sessions (`user_devices`)
   - Saved favorites (`favorites`)
   - Cloud playlists & track lists (`playlists`, `playlist_tracks`)
   - Recently played listening history (`listening_history`)
   - Theme presets, accent taste, audio quality, and EQ preset (`user_settings`)

---

## Live Architecture

```text
MUXIS App (Win/Mac/Linux/Android/iOS)
  └─> GET /api/auth/google/start           (Cloudflare Worker creates D1 state ticket)
  └─> https://muxis-cloud.web.app          (Firebase Auth Google Sign-In -> ID Token)
  └─> POST /api/auth/firebase/complete     (Cloudflare Worker verifies token + upserts D1 user)
  └─> POST /api/auth/google/poll           (MUXIS receives HS256 JWT + syncs via Cloudflare D1)
```

---

## Optional Direct Google Cloud OAuth Override

If you ever prefer direct Google Cloud OAuth without the Firebase Auth bridge:
1. Create a **Web application** OAuth Client in [Google Cloud Console](https://console.cloud.google.com/apis/credentials) with Authorized Redirect URI `https://muxis-api-worker.a-leaf-org.workers.dev/api/auth/google/callback`.
2. Set Worker secrets inside `cloudflare/`:
   ```powershell
   npx wrangler secret put GOOGLE_CLIENT_ID
   npx wrangler secret put GOOGLE_CLIENT_SECRET
   ```
When both secrets are present, `muxis-api-worker` automatically switches `google_auth_mode` to `google_direct`. Otherwise it uses `firebase_client` (`https://muxis-cloud.web.app`) automatically.

