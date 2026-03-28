CREATE TABLE albums (
    id             UUID PRIMARY KEY,
    name           TEXT NOT NULL,
    cover_photo_id UUID REFERENCES photos(id) ON DELETE SET NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE album_photos (
    album_id UUID NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
    photo_id UUID NOT NULL REFERENCES photos(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (album_id, photo_id)
);

CREATE INDEX idx_album_photos_album ON album_photos (album_id);
CREATE INDEX idx_album_photos_photo ON album_photos (photo_id);
