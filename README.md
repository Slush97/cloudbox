# Silo

Self-hosted personal cloud — photo management, file storage, and notes.

## Stack

- **Backend:** Rust (Axum, sqlx, tokio)
- **Database:** PostgreSQL
- **Reverse Proxy:** Caddy (auto-TLS)
- **Storage:** Local filesystem, optional S3

## Features

- **Photo management** — upload, EXIF extraction, thumbnail generation (sm/md/lg WebP)
- **Perceptual dedup** — dHash-based duplicate detection on upload
- **Video support** — metadata extraction, frame thumbnails, HTTP range streaming
- **File storage** — upload/download/browse with folder hierarchy and share links
- **Albums** — organize photos, cover photos, batch operations
- **Notes** — full-text search, pinning, tagging
- **Trash** — soft delete with auto-cleanup after 30 days
- **Auth** — Argon2id password hashing, JWT tokens, QR device pairing

## Project Structure

```
silo/
├── crates/
│   ├── silo-server/     # Axum API + auth + routes
│   ├── silo-db/         # sqlx queries + migrations
│   ├── silo-media/      # EXIF, thumbnails, perceptual hashing
│   └── silo-sync/       # Storage abstraction (local + S3)
├── migrations/          # PostgreSQL schema
├── Dockerfile           # Multi-stage build
├── docker-compose.yml   # Dev: Postgres
├── docker-compose.prod.yml  # Prod: Postgres + Silo + Caddy
├── Caddyfile            # Reverse proxy config
└── setup.sh             # One-command bootstrap for Arch Linux
```

## Quick Start

### Docker (recommended)

```bash
./docker-setup.sh
```

### Bare metal (Arch Linux)

```bash
./setup.sh
cargo run --release --bin silo
```

### Manual

```bash
cp .env.example .env
# Edit .env — set JWT_SECRET (openssl rand -hex 32)
docker compose up -d   # start postgres
cargo run --release --bin silo
```

## License

MIT OR Apache-2.0
