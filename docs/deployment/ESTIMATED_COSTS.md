# Infrastructure Cost Estimates & Free-Tier Boundaries — MUXIS

Because **MUXIS** is architected as an **offline-first local player** with metadata-only cloud sync, infrastructure costs remain extraordinarily low compared to centralized streaming services.

---

## 1. Provider Free-Tier Allowances

| Service | Free Tier Allowance | MUXIS Monthly Consumption (Per 10k Users) | Status |
|---|---|---|---|
| **Supabase** | 500 MB Database, 50,000 Monthly Active Users, 50 MB file storage | ~45 MB database, sync events well within limit | **$0 / month** |
| **Cloudflare Pages** | Unlimited bandwidth, 500 builds/month, unlimited requests | Static website + documentation | **$0 / month** |
| **Cloudflare Workers** | 100,000 requests / day (3M / month) | Version check + avatar pre-signed uploads (~300k/mo) | **$0 / month** |
| **Cloudflare R2** | 10 GB storage / month, 1M Class A (writes), 10M Class B (reads) | ~2 GB avatars/artwork, 0 egress charges | **$0 / month** |
| **GitHub Actions** | 2,000 runner minutes / month for private repos (Unlimited for public) | ~150 mins for tagged releases and PR checks | **$0 / month** |

**Total Operating Cost at Launch: $0.00 / month.**

---

## 2. Scaling Projections

| Resource / Metric | 1,000 Active Users | 10,000 Active Users | 100,000 Active Users |
|---|---|---|---|
| **Supabase Tier** | Free ($0) | Free ($0) | Pro Tier ($25/mo) |
| **Database Size** | ~5 MB | ~50 MB | ~500 MB |
| **R2 Storage** | ~200 MB | ~2 GB | ~20 GB ($0.30/mo) |
| **Cloudflare Workers** | Free ($0) | Free ($0) | Paid ($5/mo for 10M requests) |
| **Cloudflare Egress** | $0 (R2 has $0 egress) | $0 | $0 |
| **Total Estimated Cost**| **$0.00 / month** | **$0.00 / month** | **~$30.30 / month** |

---

## 3. Why MUXIS Costs a Fraction of Traditional Music Apps

1. **Zero Audio Bandwidth on Server:** Audio files are either read directly from the user's local disk or streamed directly from authorized public/third-party endpoints client-side. The MUXIS servers never route, proxy, or transcode audio gigabytes.
2. **Offline-First SQLite Storage:** 95% of database queries (library navigation, song sorting, search, album art cache, queue playback) execute locally on the device inside SQLite (`muxis_local.db`). The cloud database is only queried for differential sync deltas.
3. **Immutable Edge Caching:** Public artwork and version manifests are cached at Cloudflare edge locations worldwide with `Cache-Control: public, max-age=31536000, immutable`, eliminating repetitive origin round-trips.
