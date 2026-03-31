use sqlx::PgPool;
use uuid::Uuid;

#[derive(Debug, sqlx::FromRow, serde::Serialize)]
pub struct PhotoTag {
    pub tag_id: i32,
    pub tag_name: String,
    pub confidence: f32,
    pub source: String,
}

pub async fn get_or_create_tag(pool: &PgPool, name: &str) -> Result<i32, sqlx::Error> {
    let row: (i32,) = sqlx::query_as(
        "INSERT INTO tags (name) VALUES ($1) ON CONFLICT (name) DO UPDATE SET name = $1 RETURNING id",
    )
    .bind(name)
    .fetch_one(pool)
    .await?;
    Ok(row.0)
}

pub async fn get_tags_for_photo(
    pool: &PgPool,
    photo_id: Uuid,
) -> Result<Vec<PhotoTag>, sqlx::Error> {
    sqlx::query_as(
        r#"SELECT pt.tag_id, t.name AS tag_name, pt.confidence, pt.source
           FROM photo_tags pt
           JOIN tags t ON t.id = pt.tag_id
           WHERE pt.photo_id = $1
           ORDER BY pt.confidence DESC"#,
    )
    .bind(photo_id)
    .fetch_all(pool)
    .await
}

pub async fn add_tag(
    pool: &PgPool,
    photo_id: Uuid,
    tag_name: &str,
    confidence: f32,
    source: &str,
) -> Result<(), sqlx::Error> {
    let tag_id = get_or_create_tag(pool, tag_name).await?;
    sqlx::query(
        r#"INSERT INTO photo_tags (photo_id, tag_id, confidence, source)
           VALUES ($1, $2, $3, $4)
           ON CONFLICT (photo_id, tag_id) DO UPDATE
           SET confidence = EXCLUDED.confidence, source = EXCLUDED.source"#,
    )
    .bind(photo_id)
    .bind(tag_id)
    .bind(confidence)
    .bind(source)
    .execute(pool)
    .await?;
    Ok(())
}

pub async fn remove_tag(
    pool: &PgPool,
    photo_id: Uuid,
    tag_id: i32,
) -> Result<(), sqlx::Error> {
    sqlx::query("DELETE FROM photo_tags WHERE photo_id = $1 AND tag_id = $2")
        .bind(photo_id)
        .bind(tag_id)
        .execute(pool)
        .await?;
    Ok(())
}
