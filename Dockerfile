# ---- Stage 1: Build ----
FROM rust:1.83-bookworm AS builder

RUN apt-get update && apt-get install -y cmake pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy source (esolearn is a submodule inside the repo)
COPY . .

RUN cargo build --features ml --release

# ---- Stage 2: Runtime ----
FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ffmpeg \
        ca-certificates \
        libssl3 \
        libpq5 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /build/target/release/cloudbox /usr/local/bin/cloudbox
COPY --from=builder /build/migrations/ /app/migrations/
COPY --from=builder /build/models/ /app/models/

ENV CLOUDBOX_HOST=0.0.0.0
ENV CLOUDBOX_PORT=3000
ENV STORAGE_PATH=/app/data
ENV MODELS_PATH=/app/models

EXPOSE 3000
VOLUME ["/app/data"]

CMD ["cloudbox"]
