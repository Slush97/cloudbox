# ---- Stage 1: Build ----
FROM rust:latest AS builder

RUN apt-get update && apt-get install -y cmake pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . .

RUN cargo build --features ml --release

# ---- Stage 2: Download ML models ----
FROM debian:trixie-slim AS models

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /models

# MobileNet v2 — auto-tagging (14 MB)
RUN curl -fSL -o mobilenet_v2.onnx \
    "https://github.com/onnx/models/raw/main/validated/vision/classification/mobilenet/model/mobilenetv2-12.onnx"

# Face detection + recognition models are optional.
# Place scrfd.onnx and arcface.onnx in /app/models/ to enable.
# Without them, face detection is silently disabled.

# ---- Stage 3: Runtime ----
FROM debian:trixie-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ffmpeg \
        ca-certificates \
        libssl3 \
        libpq5 \
        curl && \
    rm -rf /var/lib/apt/lists/*

# Run as non-root user
RUN groupadd -r cloudbox && useradd -r -g cloudbox -m cloudbox

WORKDIR /app

COPY --from=builder /build/target/release/cloudbox /usr/local/bin/cloudbox
COPY --from=builder /build/migrations/ /app/migrations/
COPY --from=models /models/ /app/models/

RUN mkdir -p /app/data && chown -R cloudbox:cloudbox /app

USER cloudbox

ENV CLOUDBOX_HOST=0.0.0.0
ENV CLOUDBOX_PORT=3000
ENV STORAGE_PATH=/app/data
ENV MODELS_PATH=/app/models

EXPOSE 3000
VOLUME ["/app/data"]

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

CMD ["cloudbox"]
