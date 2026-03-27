CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username    TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE photos (
    id            UUID PRIMARY KEY,
    filename      TEXT NOT NULL,
    storage_key   TEXT NOT NULL,
    taken_at      TIMESTAMPTZ,
    latitude      DOUBLE PRECISION,
    longitude     DOUBLE PRECISION,
    camera_make   TEXT,
    camera_model  TEXT,
    width         INT,
    height        INT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_photos_taken_at ON photos (taken_at DESC NULLS LAST);
CREATE INDEX idx_photos_created_at ON photos (created_at DESC);

CREATE TABLE photo_embeddings (
    photo_id       UUID PRIMARY KEY REFERENCES photos(id) ON DELETE CASCADE,
    clip_embedding vector(512) NOT NULL
);

CREATE INDEX idx_photo_embeddings_clip ON photo_embeddings
    USING ivfflat (clip_embedding vector_cosine_ops) WITH (lists = 100);

CREATE TABLE faces (
    id          UUID PRIMARY KEY,
    photo_id    UUID NOT NULL REFERENCES photos(id) ON DELETE CASCADE,
    cluster_id  INT,
    bbox_x      REAL NOT NULL,
    bbox_y      REAL NOT NULL,
    bbox_w      REAL NOT NULL,
    bbox_h      REAL NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_faces_photo ON faces (photo_id);
CREATE INDEX idx_faces_cluster ON faces (cluster_id) WHERE cluster_id IS NOT NULL;

CREATE TABLE face_embeddings (
    face_id   UUID PRIMARY KEY REFERENCES faces(id) ON DELETE CASCADE,
    embedding vector(512) NOT NULL
);

CREATE TABLE face_cluster_labels (
    cluster_id INT PRIMARY KEY,
    label      TEXT NOT NULL
);

CREATE TABLE files (
    id          UUID PRIMARY KEY,
    filename    TEXT NOT NULL,
    storage_key TEXT NOT NULL,
    size_bytes  BIGINT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_files_created_at ON files (created_at DESC);
