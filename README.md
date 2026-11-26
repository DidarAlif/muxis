# MUXIS — PRISMATIC AURA
### Advanced Cross-Platform Music Streaming & Local Player Application

[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)
[![Framework: Flutter](https://img.shields.io/badge/framework-Flutter%203.x-02569B?logo=flutter)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android%20%7C%20iOS-4FACFE)](#cross-platform-support)
[![Design System](https://img.shields.io/badge/design-Prismatic%20Aura-00F2FE)](#visual-identity--prismatic-aura)

---

## 1. Overview

**Muxis** is a modern, high-fidelity cross-platform music streaming and local audio player application. Built with an original visual identity named **PRISMATIC AURA**, Muxis combines atmospheric depth, electric cyan and violet illumination, desktop-first ergonomics, and advanced audio DSP capabilities.

### Key Capabilities:
- **Unified Audio Core:** Seamless playback of local audio files (FLAC, MP3, WAV, AAC, M4A, OGG) and authorized online streams.
- **Prismatic Aura Visuals:** Original geometric monogram logo, obsidian base surfaces, dynamic ambient lighting derived from album artwork, and real-time audio visualizers.
- **Desktop Ergonomics:** Collapsible 240px navigation sidebar, persistent 92px bottom playback bar, expandable right drawer (Up-Next Queue & Synced Lyrics), and full-screen **Aurora Now Playing** mode.
- **Audio Studio & DSP Engine:** 5-band master equalizer with custom presets, real-time vocal reduction (karaoke center-channel extractor), and pitch/tempo stretching (slowed + reverb presets).
- **Synchronized Lyrics Engine:** Multi-source cascade (LRCLIB, LyricsOVH, local `.lrc`) with line-by-line and word-by-word synced scrolling.
- **Power User Controls:** Quick command palette (`Ctrl + K`), full media keys support, and precision scrub timeline.

---

## 2. Visual Identity & Brand System

### Official Color Tokens:
- **Electric Cyan:** `#00F2FE` (Primary active audio indicator and scrub thumb)
- **Prismatic Blue:** `#4FACFE` (Mid-tone frequency accent)
- **Velvet Violet:** `#7F00FF` (Harmonic secondary gradient accent)
- **Neon Magenta:** `#E100FF` (Dynamic highlights and favorite indicators)
- **Obsidian Dark Surfaces:** `#090B10` (Base background), `#111520` (Deep space), `#191F2D` (Elevated surface), `#252D40` (Hover), `#2B3448` (Border)
- **Porcelain Light Surfaces:** `#F7F8FC` (Base background), `#FFFFFF` (Card surfaces), `#EEF1F8` (Secondary), `#DCE2EF` (Border)

### Brand & Icon Assets:
- `assets/brand/muxis_mark.png` & `assets/brand/muxis_mark_square.png`: Backgroundless 3D ribbon "M" wave mark for frosted glass UI surfaces, headers, and favicons.
- `assets/brand/app_icon_1024.png` & `assets/brand/app_icon.ico`: Backgrounded squircle app icon for desktop/mobile launchers, badges, and Windows executables.
- `assets/brand/icons/`: Pre-sized Android mipmap, macOS AppIcon, and Linux PNG launcher assets used in CI builds.

---

## 3. Project Architecture

```
muxis_player/
├── assets/
│   └── brand/               <-- Muxis SVG vector branding and icons
├── lib/
│   ├── main.dart            <-- Application entry point with ProviderScope
│   ├── app/
│   │   ├── app.dart         <-- MaterialApp, theme switcher, root router
│   │   └── theme/           <-- Prismatic Aura colors, gradients, typography, shadows
│   ├── core/
│   │   ├── audio/           <-- Audio playback service, state notifier, queue manager
│   │   │   └── dsp/         <-- 5-band EQ, karaoke vocal remover, pitch/tempo controller
│   │   ├── lyrics/          <-- LRCLIB client and synchronized LRC parser
│   │   └── local_scanner/   <-- Desktop folder & audio metadata scanner
│   ├── features/
│   │   ├── shell/           <-- Responsive layout, desktop sidebar, command palette
│   │   ├── home/            <-- Spotlight hero, recently played, recommended shelves
│   │   ├── explore/         <-- Mood stations & open stream catalogs
│   │   ├── search/          <-- Instant search with filters and chips
│   │   ├── library/         <-- Track, album, and artist collections with folder import
│   │   ├── player/          <-- Bottom bar, Aurora Now Playing, audio visualizer
│   │   ├── studio/          <-- Audio Studio DSP sheet
│   │   └── settings/        <-- Appearance, audio fidelity, storage & cache
│   ├── providers/           <-- MusicProvider abstraction (Local, InnerTube, Public Domain)
│   └── shared/
│       ├── models/          <-- Track, Album, Artist, Playlist, LyricsLine
│       └── widgets/         <-- Reusable Muxis buttons, sliders, cards, badges, track rows
└── pubspec.yaml
```

---

## 4. Desktop Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `Space` | Play / Pause |
| `Ctrl + Right` | Skip to Next Track |
| `Ctrl + Left` | Return to Previous Track / Beginning |
| `Ctrl + Up` | Increase Volume (+5%) |
| `Ctrl + Down` | Decrease Volume (-5%) |
| `Ctrl + K` / `Ctrl + F` | Open Command Palette & Search |
| `Ctrl + L` | Jump to Your Music Library |

---

## 5. Building and Running

### Prerequisites:
- Flutter SDK (3.16.0 or later)
- Visual Studio 2022 with C++ Desktop Workload (for Windows native desktop runner)

### Commands:
```bash
# 1. Install dependencies
flutter pub get

# 2. Run Windows Desktop application
flutter run -d windows

# 3. Build release executable installer for Windows
flutter build windows --release

# 4. Build for mobile (Android / iOS)
flutter build apk --release
flutter build ipa --release
```

---

## 6. Cloud Infrastructure & Backend

Muxis is engineered as an **offline-first local player** with optional cloud synchronization:

- **Supabase Cloud Backend (`supabase/`):**
  - PostgreSQL schema with version-controlled SQL migrations.
  - Granular Row-Level Security (RLS) on all user data (`profiles`, `playlists`, `playlist_tracks`, `favorites`, `listening_history`, `user_settings`).
  - Secure authentication (Email/Password, Google OAuth, Apple OAuth, Account Deletion).
  - Last-Write-Wins (LWW) conflict resolution and soft-deletion tombstone sync.
  - Serverless Edge Function for authenticated account deletion and data cascade.
- **Cloudflare Pages (`website/`):**
  - High-performance marketing and documentation site built with the Prismatic Aura visual identity.
  - Automated deployment on push via GitHub Actions.
- **Cloudflare R2 & Worker Gateway (`cloudflare/`):**
  - R2 object storage for custom user avatars and approved playlist artwork.
  - Cloudflare Worker (`cloudflare/src/index.ts`) providing `/api/version` updates, pre-authorized image uploads, and edge-cached asset distribution.
  - **Zero Audio Upload Rule:** Strictly rejects all audio file uploads at the gateway level.

---

## 7. Cross-Platform CI/CD Pipelines

Automated GitHub Actions workflows in `.github/workflows/`:
1. `validate_pr.yml`: Code formatting, static analysis (`flutter analyze --fatal-infos`), unit tests, SQL migration linting, and TypeScript compilation for Cloudflare Workers.
2. `build_all_platforms.yml`: Cross-platform build matrix producing Windows x64, macOS Universal, Linux x64, Android APK/AAB, and iOS bundles.
3. `release.yml`: Triggered on version tags (`v*`), compiles optimized release binaries across platforms, generates SHA-256 checksums, and publishes GitHub Releases.
4. `deploy_website.yml`: Continuous delivery of `website/` to Cloudflare Pages.

Deployment documentation is available in `docs/deployment/`:
- `SUPABASE_SETUP.md`: Database setup, migrations, auth providers, and rollback instructions.
- `CLOUDFLARE_SETUP.md`: Pages, R2 storage bucket, and Worker API setup.
- `GITHUB_SECRETS.md`: Required secrets catalog for GitHub Actions.
- `SECURITY_CHECKLIST.md`: RLS verification, privacy guarantees, and token safety.
- `ESTIMATED_COSTS.md`: Free-tier bounds and scaling cost projections.

---

## 8. Licensing & Compliance

- Muxis is released under the **GNU General Public License v3.0 (GPL-3.0)** in compliance with referenced open-source libraries.
- REA (`E:\Desktop\rea`) is licensed under the **MIT License**.
- The Square Android reference application (`E:\Desktop\Muxis`) remains intact and unmodified.
- No private API credentials or proprietary keys are bundled. All configuration is loaded from `.env` or `--dart-define`.
