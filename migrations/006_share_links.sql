CREATE TABLE share_links (
    id          UUID PRIMARY KEY,
    file_id     UUID NOT NULL REFERENCES files(id) ON DELETE CASCADE,
    token       TEXT UNIQUE NOT NULL,
    expires_at  TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_share_links_token ON share_links (token);
CREATE INDEX idx_share_links_file ON share_links (file_id);
