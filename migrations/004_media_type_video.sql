ALTER TABLE photos ADD COLUMN media_type TEXT NOT NULL DEFAULT 'photo';
ALTER TABLE photos ADD COLUMN duration_secs REAL;
ALTER TABLE photos ADD COLUMN video_codec TEXT;

CREATE INDEX idx_photos_media_type ON photos (media_type);
