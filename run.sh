#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Start backing services if not already running
docker compose up -d --wait 2>/dev/null || true

# Build release binary if needed, then run
cargo build --features ml --release
exec target/release/cloudbox
