CREATE TABLE tags (
    id   SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL
);

CREATE TABLE photo_tags (
    photo_id   UUID NOT NULL REFERENCES photos(id) ON DELETE CASCADE,
    tag_id     INT  NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    confidence REAL NOT NULL DEFAULT 1.0,
    source     TEXT NOT NULL DEFAULT 'manual',
    PRIMARY KEY (photo_id, tag_id)
);

CREATE INDEX idx_photo_tags_photo ON photo_tags (photo_id);
CREATE INDEX idx_photo_tags_tag   ON photo_tags (tag_id);
