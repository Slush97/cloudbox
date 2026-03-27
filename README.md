# Cloudbox

Self-hosted cloud platform — photo management, file storage, and semantic search, built from scratch.

## Stack

- **Backend:** Rust (Axum, sqlx, tokio)
- **Frontend:** Flutter (mobile, web, desktop)
- **Database:** PostgreSQL + pgvector
- **ML Pipeline:** [scry-learn](https://github.com/Slush97/esolearn) (HDBSCAN face clustering) + scry-llm (CLIP/ArcFace inference)
- **Storage:** Local filesystem, optional S3/MinIO

## Features

- **Photo management** — upload, EXIF extraction, thumbnail generation (sm/md/lg WebP)
- **Semantic search** — CLIP embeddings + pgvector cosine similarity ("find photos of dogs at the beach")
- **Face detection & clustering** — SCRFD detection, ArcFace embeddings, HDBSCAN grouping via scry-learn
- **Perceptual dedup** — dHash-based duplicate detection on upload
- **File storage** — generic file upload/download/browse
- **Auth** — Argon2id password hashing, JWT tokens
- **Adaptive UI** — bottom nav on mobile, navigation rail on desktop

## Project Structure

```
cloudbox/
├── crates/
│   ├── cloudbox-server/    # Axum API + auth + routes
│   ├── cloudbox-db/        # sqlx queries + migrations
│   ├── cloudbox-media/     # EXIF, thumbnails, perceptual hashing
│   ├── cloudbox-vision/    # CLIP, face detection, clustering pipeline
│   └── cloudbox-sync/      # Storage abstraction (local + S3)
├── app/                    # Flutter client
├── migrations/             # PostgreSQL schema
├── docker-compose.yml      # Postgres (pgvector), MinIO, Redis
└── setup.sh                # One-command bootstrap for Arch Linux
```

## Quick Start

```bash
# Clone
git clone https://github.com/Slush97/cloudbox.git
cd cloudbox

# Setup (Arch Linux — installs Postgres, pgvector, seeds admin user)
./setup.sh

# Run
cargo run --release --bin cloudbox
```

## Status

Early development. The server compiles and the API surface is defined. Currently working through:

- [ ] End-to-end photo upload → gallery display
- [ ] CLIP ViT integration via scry-llm
- [ ] Face pipeline (detection → embedding → clustering)
- [ ] Flutter app connected to live server
- [ ] Auto-upload from phone camera roll
- [ ] Tailscale networking for remote access

## License

MIT OR Apache-2.0
