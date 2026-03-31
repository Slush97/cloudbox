# ---- Stage 1: Build ----
FROM rust:latest AS builder

RUN apt-get update && apt-get install -y cmake pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . .

RUN cargo build --release

# ---- Stage 2: Runtime ----
FROM debian:trixie-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ffmpeg \
        ca-certificates \
        libssl3 \
        libpq5 \
        curl && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd -r silo && useradd -r -g silo -m silo

WORKDIR /app

COPY --from=builder /build/target/release/silo /usr/local/bin/silo
COPY --from=builder /build/migrations/ /app/migrations/

RUN mkdir -p /app/data && chown -R silo:silo /app

USER silo

ENV SILO_HOST=0.0.0.0
ENV SILO_PORT=3000
ENV STORAGE_PATH=/app/data

EXPOSE 3000
VOLUME ["/app/data"]

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

CMD ["silo"]
