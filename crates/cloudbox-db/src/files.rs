use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

#[derive(Debug, sqlx::FromRow, serde::Serialize)]
pub struct File {
    pub id: Uuid,
    pub filename: String,
    pub storage_key: String,
    pub size_bytes: i64,
    pub parent_id: Option<Uuid>,
    pub mime_type: Option<String>,
    pub is_folder: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

pub async fn insert(
    pool: &PgPool,
    id: Uuid,
    filename: &str,
    storage_key: &str,
    size_bytes: i64,
    parent_id: Option<Uuid>,
    mime_type: Option<&str>,
) -> Result<File, sqlx::Error> {
    sqlx::query_as(
        r#"INSERT INTO files (id, filename, storage_key, size_bytes, parent_id, mime_type)
           VALUES ($1, $2, $3, $4, $5, $6)
           RETURNING *"#,
    )
    .bind(id)
    .bind(filename)
    .bind(storage_key)
    .bind(size_bytes)
    .bind(parent_id)
    .bind(mime_type)
    .fetch_one(pool)
    .await
}

pub async fn create_folder(
    pool: &PgPool,
    id: Uuid,
    name: &str,
    parent_id: Option<Uuid>,
) -> Result<File, sqlx::Error> {
    sqlx::query_as(
        r#"INSERT INTO files (id, filename, storage_key, size_bytes, parent_id, is_folder)
           VALUES ($1, $2, '', 0, $3, true)
           RETURNING *"#,
    )
    .bind(id)
    .bind(name)
    .bind(parent_id)
    .fetch_one(pool)
    .await
}

pub async fn get(pool: &PgPool, id: Uuid) -> Result<Option<File>, sqlx::Error> {
    sqlx::query_as("SELECT * FROM files WHERE id = $1")
        .bind(id)
        .fetch_optional(pool)
        .await
}

/// List children of a folder. `parent_id = None` means root level.
/// Folders sort before files, then alphabetically.
pub async fn list_children(
    pool: &PgPool,
    parent_id: Option<Uuid>,
) -> Result<Vec<File>, sqlx::Error> {
    sqlx::query_as(
        r#"SELECT * FROM files
           WHERE parent_id IS NOT DISTINCT FROM $1
           ORDER BY is_folder DESC, filename ASC"#,
    )
    .bind(parent_id)
    .fetch_all(pool)
    .await
}

pub async fn rename(
    pool: &PgPool,
    id: Uuid,
    new_name: &str,
) -> Result<File, sqlx::Error> {
    sqlx::query_as(
        "UPDATE files SET filename = $1, updated_at = now() WHERE id = $2 RETURNING *",
    )
    .bind(new_name)
    .bind(id)
    .fetch_one(pool)
    .await
}

pub async fn move_file(
    pool: &PgPool,
    id: Uuid,
    new_parent_id: Option<Uuid>,
) -> Result<File, sqlx::Error> {
    // Prevent moving a folder into its own subtree
    if let Some(target) = new_parent_id {
        let is_cycle: Option<(i32,)> = sqlx::query_as(
            r#"WITH RECURSIVE ancestors AS (
                SELECT id, parent_id FROM files WHERE id = $1
                UNION ALL
                SELECT f.id, f.parent_id FROM files f JOIN ancestors a ON f.id = a.parent_id
            ) SELECT 1 FROM ancestors WHERE id = $2"#,
        )
        .bind(target)
        .bind(id)
        .fetch_optional(pool)
        .await?;

        if is_cycle.is_some() {
            return Err(sqlx::Error::Protocol(
                "cannot move a folder into its own subtree".into(),
            ));
        }
    }

    sqlx::query_as(
        "UPDATE files SET parent_id = $1, updated_at = now() WHERE id = $2 RETURNING *",
    )
    .bind(new_parent_id)
    .bind(id)
    .fetch_one(pool)
    .await
}

pub async fn search_by_name(
    pool: &PgPool,
    query: &str,
    limit: i64,
) -> Result<Vec<File>, sqlx::Error> {
    sqlx::query_as(
        r#"SELECT * FROM files
           WHERE filename ILIKE '%' || $1 || '%'
           ORDER BY updated_at DESC
           LIMIT $2"#,
    )
    .bind(query)
    .bind(limit)
    .fetch_all(pool)
    .await
}

/// Walk up the parent chain to build breadcrumbs (root first).
pub async fn get_ancestors(
    pool: &PgPool,
    id: Uuid,
) -> Result<Vec<File>, sqlx::Error> {
    let mut ancestors: Vec<File> = sqlx::query_as(
        r#"WITH RECURSIVE chain AS (
            SELECT * FROM files WHERE id = $1
            UNION ALL
            SELECT f.* FROM files f JOIN chain c ON f.id = c.parent_id
        ) SELECT * FROM chain"#,
    )
    .bind(id)
    .fetch_all(pool)
    .await?;

    // Reverse so root comes first
    ancestors.reverse();
    Ok(ancestors)
}

/// Collect all descendant storage keys (for recursive file deletion).
pub async fn descendant_storage_keys(
    pool: &PgPool,
    id: Uuid,
) -> Result<Vec<String>, sqlx::Error> {
    let rows: Vec<(String,)> = sqlx::query_as(
        r#"WITH RECURSIVE tree AS (
            SELECT id, storage_key FROM files WHERE id = $1
            UNION ALL
            SELECT f.id, f.storage_key FROM files f JOIN tree t ON f.parent_id = t.id
        ) SELECT storage_key FROM tree WHERE storage_key != ''"#,
    )
    .bind(id)
    .fetch_all(pool)
    .await?;

    Ok(rows.into_iter().map(|(k,)| k).collect())
}

pub async fn delete(pool: &PgPool, id: Uuid) -> Result<(), sqlx::Error> {
    sqlx::query("DELETE FROM files WHERE id = $1")
        .bind(id)
        .execute(pool)
        .await?;
    Ok(())
}
