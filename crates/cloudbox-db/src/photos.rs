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
    pub file_size: Option<i64>,
    pub media_type: String,
    pub duration_secs: Option<f32>,
    pub video_codec: Option<String>,
    pub created_at: DateTime<Utc>,
    pub is_favorited: bool,
    pub deleted_at: Option<DateTime<Utc>>,
    pub iso: Option<i32>,
    pub aperture: Option<String>,
    pub shutter_speed: Option<String>,
    pub focal_length: Option<String>,
    pub lens_model: Option<String>,
}

#[derive(Debug, sqlx::FromRow, serde::Serialize)]
pub struct PhotoLocation {
    pub id: Uuid,
    pub latitude: f64,
    pub longitude: f64,
}

/// Check if a visually similar photo already exists (hamming distance <= threshold).
/// Postgres doesn't have bit_count on bigint natively, so we pull candidate hashes
/// and check in Rust. With typical photo libraries (<100k), this is fast enough.
pub async fn find_duplicate(pool: &PgPool, phash: u64, threshold: u32) -> Result<Option<Photo>, sqlx::Error> {
    let rows: Vec<Photo> = sqlx::query_as("SELECT * FROM photos WHERE phash IS NOT NULL AND deleted_at IS NULL")
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
    file_size: i64,
    media_type: &str,
    duration_secs: Option<f32>,
    video_codec: Option<&str>,
) -> Result<Photo, sqlx::Error> {
    let m = meta.unwrap_or_default();
    sqlx::query_as(
        r#"INSERT INTO photos (id, filename, storage_key, phash, taken_at, latitude, longitude,
           camera_make, camera_model, width, height, file_size, media_type, duration_secs, video_codec,
           iso, aperture, shutter_speed, focal_length, lens_model)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15,
                   $16, $17, $18, $19, $20)
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
    .bind(file_size)
    .bind(media_type)
    .bind(duration_secs)
    .bind(video_codec)
    .bind(m.iso)
    .bind(&m.aperture)
    .bind(&m.shutter_speed)
    .bind(&m.focal_length)
    .bind(&m.lens_model)
    .fetch_one(pool)
    .await
}

pub async fn get(pool: &PgPool, id: Uuid) -> Result<Option<Photo>, sqlx::Error> {
    sqlx::query_as("SELECT * FROM photos WHERE id = $1")
        .bind(id)
        .fetch_optional(pool)
        .await
}

#[derive(Debug, Default)]
pub struct PhotoFilter {
    pub cursor: Option<Uuid>,
    pub limit: i64,
    pub favorites_only: bool,
    pub media_type: Option<String>,
    pub date_from: Option<DateTime<Utc>>,
    pub date_to: Option<DateTime<Utc>>,
    pub has_location: bool,
}

pub async fn list(pool: &PgPool, filter: &PhotoFilter) -> Result<Vec<Photo>, sqlx::Error> {
    // Build query dynamically since we have variable WHERE clauses.
    // We use a fixed parameter layout: $1=cursor, $2=limit, $3=media_type,
    // $4=date_from, $5=date_to to keep things simple.
    let mut where_clauses = vec!["deleted_at IS NULL".to_string()];

    if filter.favorites_only {
        where_clauses.push("is_favorited = true".to_string());
    }
    if let Some(ref cursor) = filter.cursor {
        where_clauses.push(format!("id < '{cursor}'"));
    }
    if let Some(ref mt) = filter.media_type {
        where_clauses.push(format!("media_type = '{mt}'"));
    }
    if let Some(ref from) = filter.date_from {
        where_clauses.push(format!("COALESCE(taken_at, created_at) >= '{from}'"));
    }
    if let Some(ref to) = filter.date_to {
        where_clauses.push(format!("COALESCE(taken_at, created_at) <= '{to}'"));
    }
    if filter.has_location {
        where_clauses.push("latitude IS NOT NULL AND longitude IS NOT NULL".to_string());
    }

    let sql = format!(
        "SELECT * FROM photos WHERE {} ORDER BY id DESC LIMIT $1",
        where_clauses.join(" AND ")
    );

    sqlx::query_as(&sql)
        .bind(filter.limit)
        .fetch_all(pool)
        .await
}

pub async fn toggle_favorite(pool: &PgPool, id: Uuid) -> Result<Photo, sqlx::Error> {
    sqlx::query_as(
        "UPDATE photos SET is_favorited = NOT is_favorited WHERE id = $1 AND deleted_at IS NULL RETURNING *",
    )
    .bind(id)
    .fetch_one(pool)
    .await
}

pub async fn batch_set_favorite(pool: &PgPool, ids: &[Uuid], value: bool) -> Result<u64, sqlx::Error> {
    let result = sqlx::query(
        "UPDATE photos SET is_favorited = $2 WHERE id = ANY($1) AND deleted_at IS NULL",
    )
    .bind(ids)
    .bind(value)
    .execute(pool)
    .await?;
    Ok(result.rows_affected())
}

pub async fn soft_delete(pool: &PgPool, id: Uuid) -> Result<(), sqlx::Error> {
    sqlx::query("UPDATE photos SET deleted_at = now() WHERE id = $1")
        .bind(id)
        .execute(pool)
        .await?;
    Ok(())
}

pub async fn batch_soft_delete(pool: &PgPool, ids: &[Uuid]) -> Result<u64, sqlx::Error> {
    let result = sqlx::query(
        "UPDATE photos SET deleted_at = now() WHERE id = ANY($1) AND deleted_at IS NULL",
    )
    .bind(ids)
    .execute(pool)
    .await?;
    Ok(result.rows_affected())
}

pub async fn list_trash(pool: &PgPool, cursor: Option<Uuid>, limit: i64) -> Result<Vec<Photo>, sqlx::Error> {
    match cursor {
        Some(c) => {
            sqlx::query_as(
                "SELECT * FROM photos WHERE deleted_at IS NOT NULL AND id < $1 ORDER BY deleted_at DESC LIMIT $2",
            )
            .bind(c)
            .bind(limit)
            .fetch_all(pool)
            .await
        }
        None => {
            sqlx::query_as("SELECT * FROM photos WHERE deleted_at IS NOT NULL ORDER BY deleted_at DESC LIMIT $1")
                .bind(limit)
                .fetch_all(pool)
                .await
        }
    }
}

pub async fn restore(pool: &PgPool, id: Uuid) -> Result<Photo, sqlx::Error> {
    sqlx::query_as(
        "UPDATE photos SET deleted_at = NULL WHERE id = $1 RETURNING *",
    )
    .bind(id)
    .fetch_one(pool)
    .await
}

pub async fn permanent_delete(pool: &PgPool, id: Uuid) -> Result<(), sqlx::Error> {
    sqlx::query("DELETE FROM photos WHERE id = $1")
        .bind(id)
        .execute(pool)
        .await?;
    Ok(())
}

pub async fn expired_trash(pool: &PgPool, days: i64) -> Result<Vec<Photo>, sqlx::Error> {
    sqlx::query_as(
        "SELECT * FROM photos WHERE deleted_at IS NOT NULL AND deleted_at < now() - make_interval(days => $1)",
    )
    .bind(days)
    .fetch_all(pool)
    .await
}

pub async fn list_locations(pool: &PgPool) -> Result<Vec<PhotoLocation>, sqlx::Error> {
    sqlx::query_as(
        "SELECT id, latitude, longitude FROM photos WHERE latitude IS NOT NULL AND longitude IS NOT NULL AND deleted_at IS NULL",
    )
    .fetch_all(pool)
    .await
}

