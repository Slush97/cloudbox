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
    phash         BIGINT,
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
CREATE INDEX idx_photos_phash ON photos (phash) WHERE phash IS NOT NULL;

CREATE TABLE files (
    id          UUID PRIMARY KEY,
    filename    TEXT NOT NULL,
    storage_key TEXT NOT NULL,
    size_bytes  BIGINT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_files_created_at ON files (created_at DESC);
