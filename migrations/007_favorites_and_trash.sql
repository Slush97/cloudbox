-- Favorites
ALTER TABLE photos ADD COLUMN is_favorited BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE files  ADD COLUMN is_favorited BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX idx_photos_favorited  ON photos (is_favorited) WHERE is_favorited = true;
CREATE INDEX idx_files_favorited   ON files  (is_favorited) WHERE is_favorited = true;

-- Soft delete (trash)
ALTER TABLE photos ADD COLUMN deleted_at TIMESTAMPTZ;
ALTER TABLE files  ADD COLUMN deleted_at TIMESTAMPTZ;

CREATE INDEX idx_photos_deleted_at ON photos (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_files_deleted_at  ON files  (deleted_at) WHERE deleted_at IS NOT NULL;
