use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

#[derive(Debug, sqlx::FromRow, serde::Serialize)]
pub struct ShareLink {
    pub id: Uuid,
    pub file_id: Uuid,
    pub token: String,
    pub expires_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
}

pub async fn create(
    pool: &PgPool,
    id: Uuid,
    file_id: Uuid,
    token: &str,
    expires_at: Option<DateTime<Utc>>,
) -> Result<ShareLink, sqlx::Error> {
    sqlx::query_as(
        r#"INSERT INTO share_links (id, file_id, token, expires_at)
           VALUES ($1, $2, $3, $4)
           RETURNING *"#,
    )
    .bind(id)
    .bind(file_id)
    .bind(token)
    .bind(expires_at)
    .fetch_one(pool)
    .await
}

/// Look up a share link by token. Returns None if not found or expired.
pub async fn get_by_token(
    pool: &PgPool,
    token: &str,
) -> Result<Option<ShareLink>, sqlx::Error> {
    sqlx::query_as(
        r#"SELECT * FROM share_links
           WHERE token = $1
           AND (expires_at IS NULL OR expires_at > now())"#,
    )
    .bind(token)
    .fetch_optional(pool)
    .await
}

pub async fn list_for_file(
    pool: &PgPool,
    file_id: Uuid,
) -> Result<Vec<ShareLink>, sqlx::Error> {
    sqlx::query_as(
        "SELECT * FROM share_links WHERE file_id = $1 ORDER BY created_at DESC",
    )
    .bind(file_id)
    .fetch_all(pool)
    .await
}

pub async fn delete(pool: &PgPool, id: Uuid) -> Result<(), sqlx::Error> {
    sqlx::query("DELETE FROM share_links WHERE id = $1")
        .bind(id)
        .execute(pool)
        .await?;
    Ok(())
}
