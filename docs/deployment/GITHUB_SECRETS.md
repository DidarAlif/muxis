# GitHub Secrets Configuration Catalog — MUXIS

This catalog defines all secrets and environment variables required for automated CI/CD builds, releases, and deployments via GitHub Actions.

---

## 1. How to Add Secrets to GitHub

1. Navigate to your repository on GitHub (`https://github.com/muxis/muxis`).
2. Click **Settings** -> **Secrets and variables** -> **Actions**.
3. Under **Repository secrets**, click **New repository secret**.
4. Enter the Secret Name and Value from the tables below.
5. Click **Add secret**.

---

## 2. Core Cloud & Backend Secrets (Required)

| Secret Name | Description | Example / Format | Used In |
|---|---|---|---|
| `SUPABASE_URL` | The REST API endpoint of your Supabase instance. | `https://abcdefghijklm.supabase.co` | `release.yml`, `build_all_platforms.yml` |
| `SUPABASE_ANON_KEY` | Public anonymous key for client authentication and RLS queries. Safe to embed in binaries. | `eyJhbGciOiJIUzI1NiIsInR5cCI6...` | `release.yml`, `build_all_platforms.yml` |
| `CLOUDFLARE_API_TOKEN` | API token with Pages edit & Worker edit permissions. | 40-character alphanumeric token | `deploy_website.yml` |
| `CLOUDFLARE_ACCOUNT_ID`| 32-character hexadecimal Cloudflare account identifier. | `a1b2c3d4e5f67890123456789abcdef0` | `deploy_website.yml` |

---

## 3. Code-Signing Secrets (Platform Distribution)

### Windows Authenticode (Optional for signed MSIX / EXE)

| Secret Name | Description |
|---|---|
| `WINDOWS_CERTIFICATE_BASE64` | Base64-encoded `.pfx` code-signing certificate. |
| `WINDOWS_CERTIFICATE_PASSWORD`| Password for decrypting the `.pfx` certificate. |

### macOS & iOS Code Signing (Apple Developer Program)

| Secret Name | Description |
|---|---|
| `APPLE_CERTIFICATE_BASE64` | Base64-encoded Apple Distribution `.p12` certificate. |
| `APPLE_CERTIFICATE_PASSWORD` | Password for the `.p12` certificate. |
| `APPLE_PROVISIONING_PROFILE` | Base64-encoded `.mobileprovision` file. |
| `APPLE_TEAM_ID` | 10-character Apple Developer Team ID. |
| `APP_STORE_CONNECT_API_KEY` | Private `.p8` key for automated TestFlight upload. |

### Android Keystore (Google Play Store Release)

| Secret Name | Description |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded release `.jks` or `.keystore` file. |
| `ANDROID_KEYSTORE_PASSWORD` | Master password for the keystore. |
| `ANDROID_KEY_ALIAS` | Alias name for the upload key. |
| `ANDROID_KEY_PASSWORD` | Password for the individual key alias. |

---

## 4. Default GitHub Token Permissions

The workflow files make use of `secrets.GITHUB_TOKEN` provided automatically by GitHub Actions:
- `validate_pr.yml`: `contents: read`
- `build_all_platforms.yml`: `contents: read`
- `release.yml`: `contents: write` (Required to publish releases and upload binary assets)
- `deploy_website.yml`: `contents: read`, `deployments: write`

Ensure repository workflow permissions are set to:
**Settings** -> **Actions** -> **General** -> **Workflow permissions** -> **Read and write permissions**.
