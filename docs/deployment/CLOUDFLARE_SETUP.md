# Cloudflare Infrastructure Configuration Guide — MUXIS

This document details the configuration for **Cloudflare Pages** (marketing & documentation site), **Cloudflare R2** (avatar & playlist cover storage), and the **Cloudflare Worker** (API gateway & update service).

---

## 1. Cloudflare Pages (Official Website & Docs)

The official Muxis website is located in `website/` and features the complete **PRISMATIC AURA** design system, download page, architecture documentation, privacy policy, and terms of service.

### Option A: Deployment via GitHub Integration (Recommended)

1. Log in to the [Cloudflare Dashboard](https://dash.cloudflare.com).
2. Navigate to **Workers & Pages** -> **Create application** -> **Pages** -> **Connect to Git**.
3. Select your GitHub repository (`muxis/muxis`).
4. Configure build settings:
   - **Project name:** `muxis`
   - **Production branch:** `main`
   - **Framework preset:** `None`
   - **Build command:** *(Leave empty, plain static site)*
   - **Build output directory:** `website`
5. Click **Save and Deploy**.
6. Cloudflare automatically generates a `*.pages.dev` URL (e.g. `https://muxis.pages.dev`).

### Option B: Deployment via GitHub Actions Workflow

The repository includes `.github/workflows/deploy_website.yml` which deploys automatically on every push to `main` modifying `website/**`.

Ensure GitHub repository secrets `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` are configured.

### Custom Domain

1. In Pages project -> **Custom domains** -> **Set up a custom domain**.
2. Enter `muxis.app` and `www.muxis.app`.
3. Cloudflare automatically generates and provisions an edge SSL/TLS certificate.

---

## 2. Cloudflare R2 (Object Storage)

Cloudflare R2 stores permitted visual assets:
- User profile avatars
- Custom playlist cover artwork

> **IMPORTANT ARCHITECTURAL RULE:**
> Under no circumstances may copyrighted or local audio files (`.mp3`, `.flac`, `.wav`, `.m4a`) be uploaded to Cloudflare R2 or any cloud server. The R2 bucket and Cloudflare Worker explicitly enforce visual MIME type filters (`image/jpeg`, `image/png`, `image/webp`).

### Provisioning the Bucket

1. In Cloudflare Dashboard, go to **R2 Storage** -> **Create bucket**.
2. Name the production bucket: `muxis-storage`.
3. Set location hint: `Automatic` (or closest region).
4. Create preview/staging bucket: `muxis-storage-preview`.

### CORS Configuration

In the bucket settings -> **CORS Policy**, add:
```json
[
  {
    "AllowedOrigins": [
      "https://muxis.app",
      "https://*.pages.dev",
      "http://localhost:*"
    ],
    "AllowedMethods": ["GET", "PUT", "HEAD"],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 86400
  }
]
```

---

## 3. Cloudflare Worker (API Gateway & Asset Delivery)

The worker is located in `cloudflare/` and handles:
- Application version metadata and platform download URLs (`/api/version`)
- Secure pre-authorization of avatar/artwork uploads (`/api/storage/upload-ticket`)
- Direct streaming R2 file storage (`/api/storage/upload/*`)
- Edge-cached delivery with immutable headers (`/api/storage/file/*`)
- Health checks (`/api/health`)

### Local Development & Testing

```bash
cd E:\Desktop\muxis_player\cloudflare

# Install dependencies
npm install

# Test locally with Wrangler
npx wrangler dev
```

### Production Deployment

```bash
cd E:\Desktop\muxis_player\cloudflare

# Authenticate wrangler
npx wrangler login

# Deploy to production
npx wrangler deploy
```

### Custom Subdomain Routing

1. In Cloudflare Dashboard -> **Workers & Pages** -> `muxis-api-worker` -> **Settings** -> **Domains & Routes**.
2. Add Custom Domain: `api.muxis.app`.
3. This maps `https://api.muxis.app/api/version` directly to the Worker.
