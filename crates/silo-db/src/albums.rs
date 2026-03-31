use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

use crate::photos::Photo;

#[derive(Debug, sqlx::FromRow, serde::Serialize)]
pub struct Album {
    pub id: Uuid,
    pub name: String,
    pub cover_photo_id: Option<Uuid>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, serde::Serialize)]
pub struct AlbumWithCount {
    #[serde(flatten)]
    pub album: Album,
    pub photo_count: i64,
}

pub async fn create(pool: &PgPool, id: Uuid, name: &str) -> Result<Album, sqlx::Error> {
    sqlx::query_as(
        "INSERT INTO albums (id, name) VALUES ($1, $2) RETURNING *",
    )
    .bind(id)
    .bind(name)
    .fetch_one(pool)
    .await
}

pub async fn get(pool: &PgPool, id: Uuid) -> Result<Option<Album>, sqlx::Error> {
    sqlx::query_as("SELECT * FROM albums WHERE id = $1")
        .bind(id)
        .fetch_optional(pool)
        .await
}

pub async fn list(pool: &PgPool) -> Result<Vec<AlbumWithCount>, sqlx::Error> {
    let albums: Vec<Album> = sqlx::query_as(
        "SELECT * FROM albums ORDER BY updated_at DESC",
    )
    .fetch_all(pool)
    .await?;

    let mut result = Vec::with_capacity(albums.len());
    for album in albums {
        let (count,): (i64,) = sqlx::query_as(
            r#"SELECT COUNT(*) FROM album_photos ap
               JOIN photos p ON p.id = ap.photo_id
               WHERE ap.album_id = $1 AND p.deleted_at IS NULL"#,
        )
        .bind(album.id)
        .fetch_one(pool)
        .await?;
        result.push(AlbumWithCount { album, photo_count: count });
    }
    Ok(result)
}

pub async fn update(pool: &PgPool, id: Uuid, name: &str) -> Result<Album, sqlx::Error> {
    sqlx::query_as(
        "UPDATE albums SET name = $1, updated_at = now() WHERE id = $2 RETURNING *",
    )
    .bind(name)
    .bind(id)
    .fetch_one(pool)
    .await
}

pub async fn delete(pool: &PgPool, id: Uuid) -> Result<(), sqlx::Error> {
    sqlx::query("DELETE FROM albums WHERE id = $1")
        .bind(id)
        .execute(pool)
        .await?;
    Ok(())
}

pub async fn set_cover(pool: &PgPool, album_id: Uuid, photo_id: Uuid) -> Result<Album, sqlx::Error> {
    sqlx::query_as(
        "UPDATE albums SET cover_photo_id = $1, updated_at = now() WHERE id = $2 RETURNING *",
    )
    .bind(photo_id)
    .bind(album_id)
    .fetch_one(pool)
    .await
}

pub async fn add_photos(pool: &PgPool, album_id: Uuid, photo_ids: &[Uuid]) -> Result<u64, sqlx::Error> {
    let mut count = 0u64;
    for photo_id in photo_ids {
        let result = sqlx::query(
            "INSERT INTO album_photos (album_id, photo_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
        )
        .bind(album_id)
        .bind(photo_id)
        .execute(pool)
        .await?;
        count += result.rows_affected();
    }
    // Update album timestamp
    sqlx::query("UPDATE albums SET updated_at = now() WHERE id = $1")
        .bind(album_id)
        .execute(pool)
        .await?;
    Ok(count)
}

pub async fn remove_photo(pool: &PgPool, album_id: Uuid, photo_id: Uuid) -> Result<(), sqlx::Error> {
    sqlx::query("DELETE FROM album_photos WHERE album_id = $1 AND photo_id = $2")
        .bind(album_id)
        .bind(photo_id)
        .execute(pool)
        .await?;
    Ok(())
}

pub async fn list_photos(
    pool: &PgPool,
    album_id: Uuid,
    cursor: Option<Uuid>,
    limit: i64,
) -> Result<Vec<Photo>, sqlx::Error> {
    match cursor {
        Some(c) => {
            sqlx::query_as(
                r#"SELECT p.* FROM photos p
                   JOIN album_photos ap ON ap.photo_id = p.id
                   WHERE ap.album_id = $1 AND p.id < $2 AND p.deleted_at IS NULL
                   ORDER BY ap.added_at DESC LIMIT $3"#,
            )
            .bind(album_id)
            .bind(c)
            .bind(limit)
            .fetch_all(pool)
            .await
        }
        None => {
            sqlx::query_as(
                r#"SELECT p.* FROM photos p
                   JOIN album_photos ap ON ap.photo_id = p.id
                   WHERE ap.album_id = $1 AND p.deleted_at IS NULL
                   ORDER BY ap.added_at DESC LIMIT $2"#,
            )
            .bind(album_id)
            .bind(limit)
            .fetch_all(pool)
            .await
        }
    }
}
