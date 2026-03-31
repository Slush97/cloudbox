use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

const COLS: &str =
    "id, user_id, title, content, is_pinned, is_favorited, deleted_at, created_at, updated_at";

#[derive(Debug, sqlx::FromRow, serde::Serialize)]
pub struct Note {
    pub id: Uuid,
    pub user_id: Uuid,
    pub title: String,
    pub content: String,
    pub is_pinned: bool,
    pub is_favorited: bool,
    pub deleted_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, sqlx::FromRow, serde::Serialize)]
pub struct NoteTag {
    pub tag_id: i32,
    pub tag_name: String,
}

pub async fn list(
    pool: &PgPool,
    user_id: Uuid,
    cursor: Option<Uuid>,
    limit: i64,
    search: Option<&str>,
) -> Result<Vec<Note>, sqlx::Error> {
    match (cursor, search) {
        (Some(cursor), Some(search)) => {
            sqlx::query_as(&format!(
                "SELECT {COLS} FROM notes
                 WHERE user_id = $1 AND deleted_at IS NULL
                   AND id < $2
                   AND search_tsv @@ plainto_tsquery('english', $3)
                 ORDER BY is_pinned DESC, updated_at DESC
                 LIMIT $4"
            ))
            .bind(user_id)
            .bind(cursor)
            .bind(search)
            .bind(limit)
            .fetch_all(pool)
            .await
        }
        (Some(cursor), None) => {
            sqlx::query_as(&format!(
                "SELECT {COLS} FROM notes
                 WHERE user_id = $1 AND deleted_at IS NULL
                   AND id < $2
                 ORDER BY is_pinned DESC, updated_at DESC
                 LIMIT $3"
            ))
            .bind(user_id)
            .bind(cursor)
            .bind(limit)
            .fetch_all(pool)
            .await
        }
        (None, Some(search)) => {
            sqlx::query_as(&format!(
                "SELECT {COLS} FROM notes
                 WHERE user_id = $1 AND deleted_at IS NULL
                   AND search_tsv @@ plainto_tsquery('english', $2)
                 ORDER BY is_pinned DESC, updated_at DESC
                 LIMIT $3"
            ))
            .bind(user_id)
            .bind(search)
            .bind(limit)
            .fetch_all(pool)
            .await
        }
        (None, None) => {
            sqlx::query_as(&format!(
                "SELECT {COLS} FROM notes
                 WHERE user_id = $1 AND deleted_at IS NULL
                 ORDER BY is_pinned DESC, updated_at DESC
                 LIMIT $2"
            ))
            .bind(user_id)
            .bind(limit)
            .fetch_all(pool)
            .await
        }
    }
}

pub async fn get(pool: &PgPool, id: Uuid, user_id: Uuid) -> Result<Option<Note>, sqlx::Error> {
    sqlx::query_as(&format!(
        "SELECT {COLS} FROM notes WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL"
    ))
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
}

pub async fn create(
    pool: &PgPool,
    id: Uuid,
    user_id: Uuid,
    title: &str,
    content: &str,
) -> Result<Note, sqlx::Error> {
    sqlx::query_as(&format!(
        "INSERT INTO notes (id, user_id, title, content) VALUES ($1, $2, $3, $4) RETURNING {COLS}"
    ))
    .bind(id)
    .bind(user_id)
    .bind(title)
    .bind(content)
    .fetch_one(pool)
    .await
}

pub async fn update(
    pool: &PgPool,
    id: Uuid,
    user_id: Uuid,
    title: &str,
    content: &str,
) -> Result<Option<Note>, sqlx::Error> {
    sqlx::query_as(&format!(
        "UPDATE notes SET title = $1, content = $2, updated_at = now()
         WHERE id = $3 AND user_id = $4 AND deleted_at IS NULL
         RETURNING {COLS}"
    ))
    .bind(title)
    .bind(content)
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
}

pub async fn soft_delete(pool: &PgPool, id: Uuid, user_id: Uuid) -> Result<(), sqlx::Error> {
    sqlx::query(
        "UPDATE notes SET deleted_at = now() WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL",
    )
    .bind(id)
    .bind(user_id)
    .execute(pool)
    .await?;
    Ok(())
}

pub async fn toggle_pin(
    pool: &PgPool,
    id: Uuid,
    user_id: Uuid,
) -> Result<Option<Note>, sqlx::Error> {
    sqlx::query_as(&format!(
        "UPDATE notes SET is_pinned = NOT is_pinned, updated_at = now()
         WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
         RETURNING {COLS}"
    ))
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
}

pub async fn toggle_favorite(
    pool: &PgPool,
    id: Uuid,
    user_id: Uuid,
) -> Result<Option<Note>, sqlx::Error> {
    sqlx::query_as(&format!(
        "UPDATE notes SET is_favorited = NOT is_favorited, updated_at = now()
         WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
         RETURNING {COLS}"
    ))
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
}

pub async fn get_tags(pool: &PgPool, note_id: Uuid) -> Result<Vec<NoteTag>, sqlx::Error> {
    sqlx::query_as(
        "SELECT nt.tag_id, t.name AS tag_name
         FROM note_tags nt
         JOIN tags t ON t.id = nt.tag_id
         WHERE nt.note_id = $1
         ORDER BY t.name",
    )
    .bind(note_id)
    .fetch_all(pool)
    .await
}

pub async fn add_tag(pool: &PgPool, note_id: Uuid, tag_name: &str) -> Result<(), sqlx::Error> {
    let tag_id = crate::tags::get_or_create_tag(pool, tag_name).await?;
    sqlx::query(
        "INSERT INTO note_tags (note_id, tag_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
    )
    .bind(note_id)
    .bind(tag_id)
    .execute(pool)
    .await?;
    Ok(())
}

pub async fn remove_tag(pool: &PgPool, note_id: Uuid, tag_id: i32) -> Result<(), sqlx::Error> {
    sqlx::query("DELETE FROM note_tags WHERE note_id = $1 AND tag_id = $2")
        .bind(note_id)
        .bind(tag_id)
        .execute(pool)
        .await?;
    Ok(())
}
