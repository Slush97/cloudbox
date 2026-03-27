use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

use crate::PhotoMeta;

#[derive(Debug, sqlx::FromRow, serde::Serialize)]
pub struct Photo {
    pub id: Uuid,
    pub filename: String,
    pub storage_key: String,
    pub phash: Option<i64>,
    pub taken_at: Option<DateTime<Utc>>,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
    pub camera_make: Option<String>,
    pub camera_model: Option<String>,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub created_at: DateTime<Utc>,
}

/// Check if a visually similar photo already exists (hamming distance <= threshold).
/// Postgres doesn't have bit_count on bigint natively, so we pull candidate hashes
/// and check in Rust. With typical photo libraries (<100k), this is fast enough.
pub async fn find_duplicate(pool: &PgPool, phash: u64, threshold: u32) -> Result<Option<Photo>, sqlx::Error> {
    let rows: Vec<Photo> = sqlx::query_as("SELECT * FROM photos WHERE phash IS NOT NULL")
        .fetch_all(pool)
        .await?;

    Ok(rows.into_iter().find(|p| {
        let existing = p.phash.unwrap_or(0) as u64;
        (existing ^ phash).count_ones() <= threshold
    }))
}

pub async fn insert(
    pool: &PgPool,
    id: Uuid,
    filename: &str,
    storage_key: &str,
    phash: Option<u64>,
    meta: Option<PhotoMeta>,
) -> Result<Photo, sqlx::Error> {
    let m = meta.unwrap_or_default();
    sqlx::query_as(
        r#"INSERT INTO photos (id, filename, storage_key, phash, taken_at, latitude, longitude, camera_make, camera_model, width, height)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
           RETURNING *"#,
    )
    .bind(id)
    .bind(filename)
    .bind(storage_key)
    .bind(phash.map(|h| h as i64))
    .bind(m.taken_at)
    .bind(m.latitude)
    .bind(m.longitude)
    .bind(m.camera_make)
    .bind(m.camera_model)
    .bind(m.width)
    .bind(m.height)
    .fetch_one(pool)
    .await
}

pub async fn get(pool: &PgPool, id: Uuid) -> Result<Option<Photo>, sqlx::Error> {
    sqlx::query_as("SELECT * FROM photos WHERE id = $1")
        .bind(id)
        .fetch_optional(pool)
        .await
}

pub async fn list(pool: &PgPool, cursor: Option<Uuid>, limit: i64) -> Result<Vec<Photo>, sqlx::Error> {
    match cursor {
        Some(c) => {
            sqlx::query_as(
                "SELECT * FROM photos WHERE id < $1 ORDER BY id DESC LIMIT $2",
            )
            .bind(c)
            .bind(limit)
            .fetch_all(pool)
            .await
        }
        None => {
            sqlx::query_as("SELECT * FROM photos ORDER BY id DESC LIMIT $1")
                .bind(limit)
                .fetch_all(pool)
                .await
        }
    }
}

pub async fn delete(pool: &PgPool, id: Uuid) -> Result<(), sqlx::Error> {
    sqlx::query("DELETE FROM photos WHERE id = $1")
        .bind(id)
        .execute(pool)
        .await?;
    Ok(())
}

pub async fn search_by_embedding(
    pool: &PgPool,
    embedding: &[f32],
    limit: i64,
) -> Result<Vec<Photo>, sqlx::Error> {
    // pgvector cosine distance search
    sqlx::query_as(
        r#"SELECT p.* FROM photos p
           JOIN photo_embeddings e ON e.photo_id = p.id
           ORDER BY e.clip_embedding <=> $1::vector
           LIMIT $2"#,
    )
    .bind(serde_json::to_string(embedding).unwrap())
    .bind(limit)
    .fetch_all(pool)
    .await
}
