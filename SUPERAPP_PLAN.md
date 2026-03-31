# Super-App Evolution Plan

> Evolving silo from a Google Photos + Drive replacement into an open-source, self-hosted super-app — one app, one account, everything integrated.

## Vision

Google's moat isn't individual apps — it's the integration between them. No open-source project offers a unified, self-hosted alternative where all personal data connects through a knowledge graph. This project is the American open-source WeChat: messaging, email, calendar, notes, photos, files, contacts, and an AI assistant — all connected by a knowledge graph that understands the relationships between your data.

**Core principle:** The value isn't that any single module is better than the standalone alternative. The value is in the connections between modules. An email mentions Tuesday → linked to a calendar event → linked to attendee contacts → linked to shared photos from the same location. No standalone app can do this. Google does it within their walled garden. We do it self-hosted and open source.

---

## What Exists Today (silo)

### Backend (Rust)
- **silo-server** — Axum 0.8 HTTP API, JWT auth (Argon2), rate limiting, CORS, QR device pairing
- **silo-db** — PostgreSQL 17 + pgvector, sqlx compile-time checked queries, 10 migrations
- **silo-media** — EXIF extraction, WebP thumbnail generation (3 sizes), perceptual hashing (dHash), video metadata via FFmpeg
- **silo-sync** — Storage trait abstraction (local filesystem + S3/MinIO backends)

### Frontend (Flutter)
- **Photos** — Gallery grid, full-screen viewer, EXIF detail, device camera roll upload, favorites, semantic search (CLIP)
- **Files** — Folder hierarchy, upload/download, rename, move, share links with expiry
- **Albums** — Create, manage, add/remove photos, cover photo
- **Map** — Geotagged photo locations on flutter_map
- **Trash** — Soft delete, restore, permanent delete, auto-expiry
- **Settings** — Auth setup, QR device pairing, storage stats
- **Core** — Dio API client, Riverpod state management, go_router with StatefulShellRoute, responsive layout (bottom nav < 800px, navigation rail >= 800px)

### Infrastructure
- Docker multi-stage build (Rust builder → model download → Debian slim runtime)
- docker-compose for dev (PostgreSQL + MinIO + Redis) and prod
- GitHub Actions CI/CD → ghcr.io
- ML models: MobileNet v2 auto-tagging, CLIP embeddings, face detection (SCRFD) + clustering (HDBSCAN)

### Database (10 migrations)
- `users` — Accounts with Argon2 password hashes
- `photos` — Full EXIF metadata, GPS, dimensions, perceptual hash, media type, soft delete
- `photo_embeddings` — CLIP vector(512) with ivfflat index
- `faces` / `face_embeddings` — Face bounding boxes + ArcFace vector(512)
- `face_cluster_labels` — Named face groups
- `files` — Hierarchical file tree (parent_id, is_folder), soft delete
- `tags` / `photo_tags` — Tags with confidence scores (manual + auto)
- `albums` / `album_photos` — Album collections
- `share_links` — Token-based public downloads with expiry
- `pairing_codes` — Time-limited QR auth codes

---

## Tech Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Backend language | Rust | Already built, performant, memory safe |
| HTTP framework | Axum 0.8 | Already in use, async/tower-based, composable |
| Database | PostgreSQL 17 | Already in use, robust, extensible |
| Vector search | pgvector | Already in use for CLIP/face embeddings |
| DB queries | sqlx | Already in use, compile-time checked |
| Frontend framework | Flutter (Dart) | Already built, one codebase → Android + Web + Linux desktop |
| State management | Riverpod | Already in use |
| Routing | go_router | Already in use, StatefulShellRoute for tab persistence |
| UI design system | Material 3 / Material You | Native Android feel, Flutter first-class support |
| Messaging protocol | Matrix (matrix-rust-sdk) | E2E encrypted, federated, DMA bridges to WhatsApp, active ecosystem |
| Email | IMAP (async-imap) + SMTP (lettre) | Standard protocols, connect to any provider |
| Calendar sync | CalDAV | Standard protocol, interop with Proton/Nextcloud/etc. |
| Contacts sync | CardDAV | Standard protocol |
| AI / LLM | Ollama (local) + MCP server | Self-hosted, privacy-first, standard protocol |
| Knowledge graph | PostgreSQL (JSON-LD + pgvector) | Reuses existing DB, semantic search built-in |
| Push notifications | UnifiedPush + ntfy | Self-hosted, no Google dependency |
| SMS (Android) | Kotlin foreground service | Platform channel to Flutter |
| Full-text search | PostgreSQL tsvector + pg_trgm | Good enough to start, no extra infrastructure |
| Deployment | Docker | Already configured |
| CI/CD | GitHub Actions | Already configured |

### Target Platforms
- **Android** — Primary. Full feature set including SMS handling.
- **Web** — Secondary. Browser access, admin panel, share link previews.
- **Linux Desktop** — Tertiary. GTK-based via Flutter. Daily driver for Linux users.
- **iOS** — Future. Everything except SMS handling (Apple restriction).
- **Windows/macOS** — Future. Flutter supports both, low effort once Linux desktop works.

---

## Architecture

### Module Overview

```
Existing ✅              New 🆕
─────────────           ──────────────────
Photos                  Home Feed
Files                   Chat (Matrix + SMS)
Albums                  Email Client
Map                     Calendar
Trash                   Notes
Auth/Settings           Contacts (unified)
                        AI Assistant
                        Knowledge Graph
                        Universal Search
```

### Backend Crate Structure

```
crates/
├── silo-server/        ✅  HTTP API, routing, middleware, auth
├── silo-db/            ✅  Database layer, models, queries
├── silo-media/         ✅  Image/video processing, EXIF, thumbnails
├── silo-sync/          ✅  Storage abstraction (local + S3)
├── silo-graph/         🆕  Knowledge graph engine, entity extraction, MCP server
├── silo-notes/         🆕  Note storage, markdown processing, full-text search
├── silo-calendar/      🆕  CalDAV server/client, event management, recurrence
├── silo-contacts/      🆕  CardDAV, contact resolution, deduplication
├── silo-mail/          🆕  IMAP/JMAP client, email parsing, SMTP sending
└── silo-messaging/     🆕  Matrix SDK wrapper, SMS bridge adapter
```

### Flutter Module Structure

```
app/lib/
├── core/                   ✅  API client, auth, router, theme, responsive shell
│   └── graph/              🆕  Knowledge graph client
├── home/                   🆕  Unified AI-powered feed
├── chat/                   🆕  Messaging (Matrix + SMS)
├── mail/                   🆕  Email client
├── calendar/               🆕  Calendar views + event management
├── notes/                  🆕  Note editor + list
├── contacts/               🆕  Unified people view
├── assistant/              🆕  AI chat overlay
├── search/                 🆕  Universal cross-module search
├── photos/                 ✅  Gallery, viewer, upload
├── files/                  ✅  File browser, sharing
├── albums/                 ✅  Album management
├── map/                    ✅  Geotagged photo map
├── trash/                  ✅  Soft delete management
├── settings/               ✅  Auth, pairing, stats (extend for new modules)
└── shared/                 ✅  Reusable widgets, layouts
```

### Knowledge Graph Architecture

The knowledge graph is the core differentiator. It connects all modules through a unified entity-relationship model stored in PostgreSQL.

```
┌──────────────────────────────────────┐
│           App Shell (UI)             │
│  ┌────┐┌────┐┌────┐┌────┐┌────┐     │
│  │Home││Chat││Mail││ Cal ││Note│ ... │
│  └──┬─┘└──┬─┘└──┬─┘└──┬─┘└──┬─┘     │
│     │     │     │     │     │        │
│  ┌──▼─────▼─────▼─────▼─────▼──┐    │
│  │   Personal Knowledge Graph   │    │
│  │   (PostgreSQL + pgvector)    │    │
│  │                              │    │
│  │  People ←→ Events ←→ Notes   │    │
│  │  Messages ←→ Emails ←→ Files │    │
│  │  Photos ←→ Places ←→ Topics  │    │
│  └──────────────┬───────────────┘    │
│                 │                    │
│  ┌──────────────▼───────────────┐    │
│  │   LLM Structuring Engine     │    │
│  │   (entity extraction,        │    │
│  │    relationship inference)   │    │
│  └──────────────┬───────────────┘    │
│                 │                    │
│  ┌──────────────▼───────────────┐    │
│  │   MCP Query Layer            │    │
│  │   (AI assistant interface)   │    │
│  └──────────────────────────────┘    │
└──────────────────────────────────────┘
```

**How data flows:**
1. Raw data enters any module (new email, new message, new photo, new note)
2. The LLM structuring engine extracts entities (people, places, dates, topics, action items)
3. Entities become graph nodes with JSON-LD data + pgvector embeddings
4. Relationships between entities become graph edges with confidence scores
5. The AI assistant queries the graph via MCP tools to answer natural language questions
6. The home feed uses graph queries to surface relevant items

**Entity extraction examples:**
- Email from Alice about "Tuesday's meeting at Tony's" → Person(Alice) + Event(Tuesday meeting) + Place(Tony's) + edges linking them
- Photo with face detection → Person(face cluster) + Place(GPS location) + Event(date-based)
- Calendar event with attendees → Event node + Person edges for each attendee
- Note mentioning "@alice" and "sprint 42" → links to Person(Alice) + Topic(sprint 42)

---

## Navigation Design

### Mobile (Android) — 4 Bottom Tabs

```
┌──────────────────────────────────┐
│  ┌─ Search / AI ──────────────┐  │
│  │ Ask anything...            │  │
│  └────────────────────────────┘  │
│                                  │
│  ┌─ Current Space ────────────┐  │
│  │                            │  │
│  │  (full screen content)     │  │
│  │                            │  │
│  │  ↕ Pull down: AI assistant │  │
│  │                            │  │
│  └────────────────────────────┘  │
│                                  │
│   [🏠]    [💬]    [⊞]    [👤]   │
│   Home    Chat   Spaces   Me    │
└──────────────────────────────────┘
```

**Home** — AI-powered daily briefing. Upcoming events, unread messages, unread emails, recent notes, AI-surfaced items. The screen you open the app to every morning.

**Chat** — Conversation list (Matrix + SMS interleaved). Tap into any conversation for full chat screen with media, reactions, replies.

**Spaces** — Grid of module icons. One tap into any full module:
```
  ✉️ Mail       📅 Calendar    📝 Notes
  📷 Photos     📁 Files       👤 Contacts
  🗺️ Map        🗑️ Trash
```

**Me** — Profile, connected accounts (email, Matrix), storage stats, settings, theme, notifications, AI preferences.

### Desktop / Web (>= 800px) — Persistent Sidebar

```
┌────────────┬──────────────────────────────────┐
│ 🏠 Home    │                                  │
│ 💬 Chat    │                                  │
│ ────────── │     Content Area                 │
│ ✉️ Mail    │                                  │
│ 📅 Calendar│     (split-pane for mail/chat)   │
│ 📝 Notes   │                                  │
│ 📷 Photos  │                                  │
│ 📁 Files   │                                  │
│ 👤 Contacts│                                  │
│ 🗺️ Map     │                                  │
│ ────────── │                                  │
│ ⚙️ Settings│                                  │
└────────────┴──────────────────────────────────┘
```

Desktop shows all modules in the sidebar directly — no "Spaces" intermediary needed when screen real estate allows it.

### Key Interaction Patterns

- **Pull down from any screen** → AI assistant overlay slides in
- **"+" FAB on home screen** → Quick actions: New Note, New Event, Take Photo, Scan QR
- **Long-press any item** → Contextual AI actions ("summarize", "find related", "create event from this")
- **Universal search** → Top of home screen, searches across all modules via knowledge graph
- **Person tap** → Unified person page showing all activity across all modules

---

## Database Schema — New Migrations

### 011_notes.sql

```sql
CREATE TABLE notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    title TEXT,
    content TEXT NOT NULL,
    is_pinned BOOLEAN DEFAULT false,
    is_favorited BOOLEAN DEFAULT false,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE note_tags (
    note_id UUID REFERENCES notes(id) ON DELETE CASCADE,
    tag_id INT REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (note_id, tag_id)
);

CREATE INDEX idx_notes_user_created ON notes(user_id, created_at DESC);
CREATE INDEX idx_notes_fts ON notes USING GIN (to_tsvector('english', coalesce(title, '') || ' ' || content));
```

### 012_calendar.sql

```sql
CREATE TABLE calendar_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    uid TEXT,
    summary TEXT NOT NULL,
    description TEXT,
    location TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ,
    all_day BOOLEAN DEFAULT false,
    recurrence_rule TEXT,
    color TEXT,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE event_attendees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES calendar_events(id) ON DELETE CASCADE,
    contact_id UUID,
    name TEXT,
    email TEXT,
    status TEXT DEFAULT 'pending'
);

CREATE INDEX idx_events_user_start ON calendar_events(user_id, start_at);
CREATE INDEX idx_events_range ON calendar_events(start_at, end_at);
```

### 013_contacts.sql

```sql
CREATE TABLE contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    display_name TEXT NOT NULL,
    first_name TEXT,
    last_name TEXT,
    email TEXT,
    phone TEXT,
    avatar_storage_key TEXT,
    birthday DATE,
    notes TEXT,
    source TEXT NOT NULL,
    face_cluster_id INT,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE contact_aliases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID REFERENCES contacts(id) ON DELETE CASCADE,
    alias_type TEXT NOT NULL,
    alias_value TEXT NOT NULL,
    UNIQUE (alias_type, alias_value)
);

CREATE INDEX idx_contacts_user ON contacts(user_id);
CREATE INDEX idx_contacts_name ON contacts(display_name);
CREATE INDEX idx_contact_aliases_value ON contact_aliases(alias_type, alias_value);
```

### 014_graph.sql

```sql
CREATE TABLE graph_nodes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    node_type TEXT NOT NULL,
    data JSONB NOT NULL,
    embedding vector(512),
    source_type TEXT,
    source_id UUID,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE graph_edges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_node UUID REFERENCES graph_nodes(id) ON DELETE CASCADE,
    to_node UUID REFERENCES graph_nodes(id) ON DELETE CASCADE,
    relation TEXT NOT NULL,
    confidence REAL DEFAULT 1.0,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (from_node, to_node, relation)
);

CREATE INDEX idx_graph_nodes_type ON graph_nodes(node_type);
CREATE INDEX idx_graph_nodes_source ON graph_nodes(source_type, source_id);
CREATE INDEX idx_graph_edges_from ON graph_edges(from_node);
CREATE INDEX idx_graph_edges_to ON graph_edges(to_node);
CREATE INDEX idx_graph_nodes_embedding ON graph_nodes
    USING ivfflat (embedding vector_cosine_ops);
```

### 015_messages.sql

```sql
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    protocol TEXT NOT NULL,
    remote_id TEXT,
    title TEXT,
    is_group BOOLEAN DEFAULT false,
    last_message_at TIMESTAMPTZ,
    unread_count INT DEFAULT 0,
    is_muted BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
    sender_contact_id UUID REFERENCES contacts(id),
    sender_name TEXT,
    content TEXT,
    content_type TEXT DEFAULT 'text',
    media_storage_key TEXT,
    remote_id TEXT,
    sent_at TIMESTAMPTZ NOT NULL,
    is_outgoing BOOLEAN DEFAULT false,
    is_read BOOLEAN DEFAULT false
);

CREATE INDEX idx_conversations_user ON conversations(user_id, last_message_at DESC);
CREATE INDEX idx_messages_conversation ON messages(conversation_id, sent_at DESC);
```

### 016_mail_cache.sql

```sql
CREATE TABLE mail_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    email_address TEXT NOT NULL,
    display_name TEXT,
    imap_host TEXT NOT NULL,
    imap_port INT DEFAULT 993,
    smtp_host TEXT NOT NULL,
    smtp_port INT DEFAULT 587,
    encrypted_password BYTEA NOT NULL,
    last_sync_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE mail_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID REFERENCES mail_accounts(id) ON DELETE CASCADE,
    message_id TEXT,
    folder TEXT NOT NULL,
    subject TEXT,
    from_address TEXT,
    from_name TEXT,
    to_addresses JSONB,
    cc_addresses JSONB,
    date TIMESTAMPTZ,
    body_text TEXT,
    body_html TEXT,
    has_attachments BOOLEAN DEFAULT false,
    is_read BOOLEAN DEFAULT false,
    is_starred BOOLEAN DEFAULT false,
    is_deleted BOOLEAN DEFAULT false,
    raw_headers JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE mail_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mail_message_id UUID REFERENCES mail_messages(id) ON DELETE CASCADE,
    filename TEXT NOT NULL,
    mime_type TEXT,
    size_bytes BIGINT,
    storage_key TEXT
);

CREATE INDEX idx_mail_messages_account_folder ON mail_messages(account_id, folder, date DESC);
CREATE INDEX idx_mail_messages_fts ON mail_messages
    USING GIN (to_tsvector('english', coalesce(subject, '') || ' ' || coalesce(body_text, '')));
```

---

## API Routes

### Existing (unchanged)
```
/health                           GET     Health check
/api/v1/auth/login                POST    Login
/api/v1/auth/setup                POST    Initial user creation
/api/v1/auth/status               GET     Check setup status
/api/v1/auth/pair                 POST    Generate pairing code
/api/v1/auth/pair/claim           POST    Claim pairing code
/api/v1/photos                    GET     List photos (filtered, paginated)
/api/v1/photos/upload             POST    Upload photo
/api/v1/photos/locations          GET     Get geotagged locations
/api/v1/photos/:id                GET     Get photo original
/api/v1/photos/:id/thumb/:size    GET     Get thumbnail (sm/md/lg)
/api/v1/photos/:id/stream         GET     Stream video
/api/v1/photos/:id/favorite       PUT     Toggle favorite
/api/v1/photos/:id                DELETE  Soft delete
/api/v1/photos/:id/tags           GET     Get tags
/api/v1/photos/:id/tags           POST    Add tag
/api/v1/photos/:id/tags/:tag_id   DELETE  Remove tag
/api/v1/photos/batch/favorite     POST    Batch favorite
/api/v1/photos/batch/delete       POST    Batch delete
/api/v1/photos/batch/album        POST    Batch add to album
/api/v1/files                     GET     List files in folder
/api/v1/files/upload              POST    Upload file
/api/v1/files/folder              POST    Create folder
/api/v1/files/search              GET     Search files
/api/v1/files/:id                 GET     Download file
/api/v1/files/:id                 DELETE  Soft delete
/api/v1/files/:id/favorite        PUT     Toggle favorite
/api/v1/files/:id/rename          PUT     Rename
/api/v1/files/:id/move            PUT     Move to folder
/api/v1/files/:id/ancestors       GET     Get folder breadcrumbs
/api/v1/files/:id/share           POST    Create share link
/api/v1/files/:id/shares          GET     List shares
/api/v1/files/:id/share/:sid      DELETE  Delete share
/api/v1/albums                    GET     List albums
/api/v1/albums                    POST    Create album
/api/v1/albums/:id                GET/PUT/DELETE  Album CRUD
/api/v1/albums/:id/photos         GET     List album photos
/api/v1/albums/:id/photos         POST    Add photos
/api/v1/albums/:id/photos/:pid    DELETE  Remove photo
/api/v1/albums/:id/cover          PUT     Set cover
/api/v1/trash                     GET     List trash
/api/v1/trash                     DELETE  Empty trash
/api/v1/trash/photo/:id/restore   POST    Restore photo
/api/v1/trash/photo/:id           DELETE  Permanent delete photo
/api/v1/trash/file/:id/restore    POST    Restore file
/api/v1/trash/file/:id            DELETE  Permanent delete file
/api/v1/stats                     GET     Storage stats
/s/:token                         GET     Public share download
```

### New Routes

```
/api/v1/notes                     GET     List notes (search, paginated)
/api/v1/notes                     POST    Create note
/api/v1/notes/:id                 GET     Get note
/api/v1/notes/:id                 PUT     Update note
/api/v1/notes/:id                 DELETE  Soft delete
/api/v1/notes/:id/tags            POST    Add tag
/api/v1/notes/:id/tags/:tag_id    DELETE  Remove tag

/api/v1/calendar/events           GET     List events (date range filter)
/api/v1/calendar/events           POST    Create event
/api/v1/calendar/events/:id       GET     Get event with attendees
/api/v1/calendar/events/:id       PUT     Update event
/api/v1/calendar/events/:id       DELETE  Delete event

/api/v1/contacts                  GET     List contacts (search, paginated)
/api/v1/contacts                  POST    Create contact
/api/v1/contacts/:id              GET     Get contact
/api/v1/contacts/:id              PUT     Update contact
/api/v1/contacts/:id              DELETE  Soft delete
/api/v1/contacts/:id/activity     GET     Cross-module activity for person
/api/v1/contacts/merge            POST    Merge duplicate contacts

/api/v1/mail/accounts             GET     List connected email accounts
/api/v1/mail/accounts             POST    Add email account
/api/v1/mail/accounts/:id         DELETE  Remove account
/api/v1/mail/accounts/:id/sync    POST    Trigger sync
/api/v1/mail/messages             GET     List messages (folder, search)
/api/v1/mail/messages/:id         GET     Get full message
/api/v1/mail/messages/send        POST    Send email
/api/v1/mail/messages/:id/read    PUT     Mark read/unread
/api/v1/mail/messages/:id/star    PUT     Star/unstar

/api/v1/messages/conversations              GET     List conversations
/api/v1/messages/conversations              POST    Create conversation
/api/v1/messages/conversations/:id          GET     Get messages
/api/v1/messages/conversations/:id          POST    Send message
/api/v1/messages/conversations/:id/read     PUT     Mark read

/api/v1/graph/search              GET     Semantic search across all entities
/api/v1/graph/node/:id            GET     Get node with edges
/api/v1/graph/node/:id/related    GET     Get related nodes
/api/v1/graph/feed                GET     AI-ranked home feed items

/api/v1/assistant/chat             POST    Send query to AI
/api/v1/assistant/chat/stream      WS      WebSocket streaming AI responses
```

---

## Rust Dependencies — New Crates

### silo-graph
```toml
[dependencies]
sqlx = { version = "0.8", features = ["runtime-tokio", "postgres", "uuid", "json"] }
pgvector = "0.4"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
uuid = { version = "1", features = ["v4"] }
tokio = { version = "1", features = ["full"] }
```

### silo-notes
```toml
[dependencies]
sqlx = { version = "0.8", features = ["runtime-tokio", "postgres", "uuid"] }
serde = { version = "1", features = ["derive"] }
uuid = { version = "1", features = ["v4"] }
pulldown-cmark = "0.12"
```

### silo-calendar
```toml
[dependencies]
sqlx = { version = "0.8", features = ["runtime-tokio", "postgres", "uuid"] }
ical = "0.11"
serde = { version = "1", features = ["derive"] }
uuid = { version = "1", features = ["v4"] }
chrono = "0.4"
reqwest = { version = "0.12", features = ["rustls-tls"] }
```

### silo-contacts
```toml
[dependencies]
sqlx = { version = "0.8", features = ["runtime-tokio", "postgres", "uuid"] }
serde = { version = "1", features = ["derive"] }
uuid = { version = "1", features = ["v4"] }
vcard_parser = "0.2"
```

### silo-mail
```toml
[dependencies]
async-imap = "0.10"
async-native-tls = "0.5"
mail-parser = "0.9"
lettre = "0.11"
sqlx = { version = "0.8", features = ["runtime-tokio", "postgres", "uuid"] }
serde = { version = "1", features = ["derive"] }
tokio = { version = "1", features = ["full"] }
```

### silo-messaging
```toml
[dependencies]
matrix-sdk = { version = "0.9", features = ["e2e-encryption", "sqlite"] }
sqlx = { version = "0.8", features = ["runtime-tokio", "postgres", "uuid"] }
serde = { version = "1", features = ["derive"] }
tokio = { version = "1", features = ["full"] }
```

## Flutter Dependencies — New

```yaml
# Add to existing pubspec.yaml
dependencies:
  table_calendar: ^3.1.0           # Calendar UI
  flutter_quill: ^10.0.0           # Rich text / notes editor
  matrix: ^0.32.0                  # Matrix messaging SDK
  drift: ^2.20.0                   # Local SQLite (offline cache)
  sqlite3_flutter_libs: ^0.5.0     # SQLite native libs
  flutter_local_notifications: ^18.0.0
  flutter_background_service: ^5.0.0
  flutter_markdown: ^0.7.0         # Markdown rendering
```

---

## Build Phases

### Phase 1: Notes + Contacts + Nav Restructure (Weeks 1-6)

**Goal:** Restructure app navigation to super-app layout. Add first two new modules. Prove the extension pattern.

**Backend:**
- [ ] Create `silo-notes` crate (CRUD, markdown processing, full-text search)
- [ ] Create `silo-contacts` crate (CRUD, alias resolution, dedup)
- [ ] Add migrations: `011_notes.sql`, `013_contacts.sql`
- [ ] Add route files: `routes/notes.rs`, `routes/contacts.rs`
- [ ] Add new routes to main.rs via `.nest()`
- [ ] Extend AppState as needed

**Frontend:**
- [ ] Restructure router: 4 shell branches → Home / Chat / Spaces / Me
- [ ] Move Photos, Files, Albums, Map, Trash under `/spaces/` routes
- [ ] Build `notes/` module: note list, markdown editor, search, tags
- [ ] Build `contacts/` module: contact list, person detail page (basic)
- [ ] Build `home/` module: placeholder feed with recent notes
- [ ] Build Spaces grid screen (module launcher)
- [ ] Update responsive shell for new nav structure
- [ ] Add note/contact API methods to ApiClient

**Result:** App navigation restructured. Photos/files still work at new paths. Notes and contacts functional. Pattern established for adding more modules.

### Phase 2: Calendar + Knowledge Graph + Search (Weeks 7-12)

**Goal:** Add calendar. Stand up the knowledge graph. Enable cross-module search. Home feed becomes real.

**Backend:**
- [ ] Create `silo-calendar` crate (event CRUD, basic CalDAV)
- [ ] Create `silo-graph` crate (node/edge CRUD, entity extraction)
- [ ] Add migrations: `012_calendar.sql`, `014_graph.sql`
- [ ] Add route files: `routes/calendar.rs`, `routes/graph.rs`
- [ ] Background job: create graph nodes for existing photos (EXIF, faces, tags)
- [ ] Background job: create graph nodes for notes (extract entities)
- [ ] Background job: create graph nodes for calendar events + attendees
- [ ] Graph search endpoint: semantic search via pgvector + full-text

**Frontend:**
- [ ] Build `calendar/` module: month/week/day views, event editor
- [ ] Build `search/` module: universal search bar, cross-module results
- [ ] Upgrade home feed: upcoming events, recent notes, recent photos, graph-surfaced items
- [ ] Contacts: show calendar events per person
- [ ] Contacts: link face clusters to contact records

**Result:** Core PIM is functional. Knowledge graph connects photos, notes, calendar, contacts. Universal search works across everything. Home feed shows real personalized content.

### Phase 3: Email Client + AI Assistant (Weeks 13-20)

**Goal:** Add email. Add AI assistant. This is where cross-module intelligence becomes tangible.

**Backend:**
- [ ] Create `silo-mail` crate (IMAP sync, email parsing, SMTP sending)
- [ ] Add migration: `016_mail_cache.sql`
- [ ] Add route file: `routes/mail.rs`
- [ ] Background job: IMAP sync (polling or IDLE)
- [ ] Graph integration: extract entities from emails (people, dates, places, action items)
- [ ] Create MCP server: expose graph nodes/edges/search as MCP tools
- [ ] AI assistant endpoint: `/api/v1/assistant/chat` + WebSocket streaming
- [ ] Add route file: `routes/assistant.rs`

**Frontend:**
- [ ] Build `mail/` module: inbox, thread view, compose, folder navigation
- [ ] Build `assistant/` module: pull-down overlay, chat interface, streaming responses
- [ ] Home feed: add unread important emails, AI-surfaced connections
- [ ] Contacts: show email history per person
- [ ] Contextual AI: long-press any item → AI action menu

**Result:** The "holy shit" moment. Email + calendar + notes + photos + contacts all connected through the graph. AI can answer "what did Alice say about the deadline?" by searching across email, notes, and calendar simultaneously. Super-app value proposition is tangible.

### Phase 4: Messaging (Weeks 21-28)

**Goal:** Add Matrix messaging + SMS fallback. Complete the communication stack.

**Backend:**
- [ ] Create `silo-messaging` crate (Matrix SDK integration)
- [ ] Add migration: `015_messages.sql`
- [ ] Add route file: `routes/messages.rs`
- [ ] Matrix homeserver connection (or embed Conduit for self-contained setup)
- [ ] Message cache: sync Matrix messages to local PostgreSQL
- [ ] Graph integration: extract entities from messages
- [ ] Android: Kotlin foreground service for persistent Matrix connection (platform channel)
- [ ] Android: SMS/MMS handler (register as default SMS app, platform channel)

**Frontend:**
- [ ] Build `chat/` module: conversation list, chat screen
- [ ] Message types: text, image, video, file, voice message
- [ ] Group chats, reactions, typing indicators, read receipts
- [ ] SMS conversations interleaved with Matrix (labeled by protocol)
- [ ] Home feed: add unread messages
- [ ] Contacts: show chat history per person
- [ ] Share extension: receive shares from other Android apps into chat

**Result:** Full super-app. All modules live, all feeding the knowledge graph. Unified person view shows activity across every module. AI queries across everything.

### Phase 5: Polish + Beta (Weeks 29-36)

**Goal:** Production-ready for daily driver use and self-hoster adoption.

- [ ] Offline-first: Drift local SQLite cache, sync when connected
- [ ] Performance: lazy loading, pagination, image caching, query optimization
- [ ] Notification system: per-module Android notification channels
- [ ] Linux desktop build + testing
- [ ] Web build optimization (code splitting, lazy routes)
- [ ] Onboarding wizard: connect email, import contacts, configure Matrix
- [ ] Data export: full data portability (JSON-LD graph dump, standard formats)
- [ ] Self-hoster docs: installation guide, configuration reference
- [ ] Edge cases: empty states, error recovery, network failure handling
- [ ] Beta release

---

## Integration Map

Every module connects to every other module through the knowledge graph:

```
                    HOME FEED
                       │
            ┌──────────┼──────────┐
            │          │          │
         CALENDAR ── NOTES ── CONTACTS
            │╲        │╱        ╱│
            │  ╲      │╱      ╱  │
            │    ╲    │╱    ╱    │
          EMAIL ──── AI ──── CHAT
            │╱        │╲       ╲│
            │╱        │  ╲      │
         PHOTOS ── FILES ── SEARCH
```

8 modules × 28 pairwise connections. The knowledge graph and AI make every connection queryable.

**Key integration examples:**
- Email mentions "Tuesday at 2pm" → suggest creating calendar event → link to attendee contacts
- Photo face detection → link to contact → show all photos of that person across all albums
- Calendar event attendees → show related emails from those people → show notes from previous meetings
- Chat message "check out Tony's" → graph extracts restaurant → links to location → shows on map
- AI query "what do I need to prep for Tuesday's meeting?" → searches notes, emails, previous meeting notes, related files

---

## Design Principles

1. **Knowledge graph is the center of gravity** — not chat (WeChat model) or email (Google model). Every module feeds the graph; the graph connects everything.

2. **Person-centric views** — tap any contact to see all interactions across all modules. This is the feature that demonstrates the super-app advantage most clearly.

3. **Progressive disclosure** — new users see a clean, simple app. Features reveal themselves through use. Power user capabilities (AI, graph queries, bridges) are there but not in your face.

4. **Offline-first** — the app works without internet. Local SQLite caches everything. Sync when connected. Messages queue, notes save, calendar works offline.

5. **Self-hosted but not self-hosted-only** — ship a Docker image for self-hosters, offer hosted option later for wider adoption. The Bitwarden/Nextcloud model.

6. **Build on standards** — CalDAV, CardDAV, IMAP/JMAP, Matrix, JSON-LD, MCP. Don't invent protocols. Interoperate with everything.

7. **AI as glue, not gimmick** — the AI isn't a chatbot bolted on. It's the query engine for the knowledge graph. It extracts entities, infers relationships, and answers questions across all your data.

---

## Messaging Strategy

RCS is locked down by Google — no third-party app can access it (confirmed: Textra, Pulse, Samsung Messages all lost or never had RCS access). The strategy:

- **Matrix protocol** — primary messaging. E2E encrypted, federated, full features (groups, reactions, typing indicators, voice/video, file sharing). Better than RCS on features.
- **SMS/MMS** — fallback for contacts not on Matrix. Default SMS handler on Android. Basic but reliable.
- **DMA bridges** — EU Digital Markets Act requires WhatsApp interoperability with third-party protocols. Matrix is actively building this bridge. Your app potentially reaches WhatsApp's 2B users through federation.
- **Notification bridge** — optional hack to mirror RCS messages from Google Messages via NotificationListenerService. Best-effort, clearly labeled, not a core feature.

## Future Roadmap (Post-v1)

- **Payments** — IOU ledger + bill splitting in chat (v1.5), stablecoin wallet or Stripe Connect (v2.0)
- **Mini-app platform** — sandboxed WASM/WebView mini-apps with access to identity, payments, messaging (v2.5)
- **iOS build** — Flutter covers this, everything except SMS handling works (v2.0)
- **Federation** — multiple instances talking to each other, portable identity (v3.0)
- **Subscriptions/feeds** — RSS reader, newsletter aggregation (v1.5)
- **Tasks/todos** — could be part of notes or a standalone module (v1.5)

---

## Open Questions

- [ ] **Name** — silo needs a new name that reflects the super-app vision. Current candidates: Hearth, Commons, Plaza, Agora, Vela, Sola. Needs to feel warm and personal, not corporate or techy.
- [ ] **Matrix homeserver** — embed Conduit (lightweight Rust homeserver) for fully self-contained setup, or require external homeserver (Synapse/Conduit/Dendrite)?
- [ ] **CalDAV scope** — full CalDAV server (so external clients can sync) or just CalDAV client (sync from external server)? Probably start with server so the app is self-contained.
- [ ] **Email credential storage** — how to securely store IMAP/SMTP passwords. Encrypted at rest with user's master password? Separate key derivation?
- [ ] **LLM hosting** — require user to run Ollama, or embed a small model, or offer optional cloud API? Probably all three as options.
- [ ] **CRDT sync** — when to introduce Automerge for offline-first conflict resolution. Phase 5 or later?
