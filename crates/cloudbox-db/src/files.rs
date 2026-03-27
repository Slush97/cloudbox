use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

#[derive(Debug, sqlx::FromRow, serde::Serialize)]
pub struct File {
    pub id: Uuid,
    pub filename: String,
    pub storage_key: String,
    pub size_bytes: i64,
    pub created_at: DateTime<Utc>,
}

pub async fn insert(
    pool: &PgPool,
    id: Uuid,
    filename: &str,
    storage_key: &str,
    size_bytes: i64,
) -> Result<File, sqlx::Error> {
    sqlx::query_as(
        r#"INSERT INTO files (id, filename, storage_key, size_bytes)
           VALUES ($1, $2, $3, $4)
           RETURNING *"#,
    )
    .bind(id)
    .bind(filename)
    .bind(storage_key)
    .bind(size_bytes)
    .fetch_one(pool)
    .await
}

pub async fn get(pool: &PgPool, id: Uuid) -> Result<Option<File>, sqlx::Error> {
    sqlx::query_as("SELECT * FROM files WHERE id = $1")
        .bind(id)
        .fetch_optional(pool)
        .await
}

pub async fn list(pool: &PgPool) -> Result<Vec<File>, sqlx::Error> {
    sqlx::query_as("SELECT * FROM files ORDER BY created_at DESC")
        .fetch_all(pool)
        .await
}

pub async fn delete(pool: &PgPool, id: Uuid) -> Result<(), sqlx::Error> {
    sqlx::query("DELETE FROM files WHERE id = $1")
        .bind(id)
        .execute(pool)
        .await?;
    Ok(())
}
