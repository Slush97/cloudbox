# ---- Stage 1: Build ----
FROM rust:1.83-bookworm AS builder

RUN apt-get update && apt-get install -y cmake pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . .

RUN cargo build --features ml --release

# ---- Stage 2: Download ML models ----
FROM debian:bookworm-slim AS models

RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

WORKDIR /models

# MobileNet v2 — auto-tagging (14 MB)
RUN curl -fSL -o mobilenet_v2.onnx \
    "https://github.com/onnx/models/raw/main/validated/vision/classification/mobilenet/model/mobilenetv2-12.onnx"

# SCRFD — face detection (17 MB)
RUN curl -fSL -o scrfd.onnx \
    "https://github.com/deepinsight/insightface/raw/master/python-package/insightface/models/buffalo_l/det_10g.onnx" \
    || echo "SCRFD download failed — face detection will be disabled"

# ArcFace — face recognition (174 MB)
RUN curl -fSL -o arcface.onnx \
    "https://github.com/deepinsight/insightface/raw/master/python-package/insightface/models/buffalo_l/w600k_r50.onnx" \
    || echo "ArcFace download failed — face recognition will be disabled"

# ---- Stage 3: Runtime ----
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
COPY --from=models /models/ /app/models/

ENV CLOUDBOX_HOST=0.0.0.0
ENV CLOUDBOX_PORT=3000
ENV STORAGE_PATH=/app/data
ENV MODELS_PATH=/app/models

EXPOSE 3000
VOLUME ["/app/data"]

CMD ["cloudbox"]
