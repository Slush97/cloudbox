use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

#[derive(Debug, sqlx::FromRow, serde::Serialize)]
pub struct Face {
    pub id: Uuid,
    pub photo_id: Uuid,
    pub cluster_id: Option<i32>,
    pub bbox_x: f32,
    pub bbox_y: f32,
    pub bbox_w: f32,
    pub bbox_h: f32,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, serde::Serialize)]
pub struct FaceCluster {
    pub cluster_id: i32,
    pub label: Option<String>,
    pub face_count: i64,
    pub sample_photo_ids: Vec<Uuid>,
}

/// Insert a detected face and its embedding into the database.
///
/// Creates rows in both `faces` and `face_embeddings` tables.
pub async fn insert_face(
    pool: &PgPool,
    photo_id: Uuid,
    bbox: [f32; 4],
    embedding: &[f32],
) -> Result<Face, sqlx::Error> {
    let id = Uuid::now_v7();

    let face: Face = sqlx::query_as(
        r#"INSERT INTO faces (id, photo_id, bbox_x, bbox_y, bbox_w, bbox_h)
           VALUES ($1, $2, $3, $4, $5, $6)
           RETURNING *"#,
    )
    .bind(id)
    .bind(photo_id)
    .bind(bbox[0])
    .bind(bbox[1])
    .bind(bbox[2])
    .bind(bbox[3])
    .fetch_one(pool)
    .await?;

    // Store the 512-dim embedding via pgvector
    let embedding_json = serde_json::to_string(embedding).unwrap();
    sqlx::query("INSERT INTO face_embeddings (face_id, embedding) VALUES ($1, $2::vector)")
        .bind(id)
        .bind(&embedding_json)
        .execute(pool)
        .await?;

    Ok(face)
}

/// Fetch all face embeddings for clustering.
///
/// Returns `(face_id, embedding_as_f32_vec)` pairs.
pub async fn fetch_all_embeddings(pool: &PgPool) -> Result<Vec<(Uuid, Vec<f32>)>, sqlx::Error> {
    let rows: Vec<(Uuid, String)> = sqlx::query_as(
        "SELECT face_id, embedding::text FROM face_embeddings",
    )
    .fetch_all(pool)
    .await?;

    Ok(rows
        .into_iter()
        .map(|(id, text)| {
            // pgvector returns "[0.1,0.2,...]" format
            let trimmed = text.trim_start_matches('[').trim_end_matches(']');
            let embedding: Vec<f32> = trimmed
                .split(',')
                .filter_map(|s| s.trim().parse().ok())
                .collect();
            (id, embedding)
        })
        .collect())
}

/// Update cluster assignments for a batch of faces.
pub async fn update_cluster_ids(
    pool: &PgPool,
    assignments: &[(Uuid, Option<i32>)],
) -> Result<(), sqlx::Error> {
    for (face_id, cluster_id) in assignments {
        sqlx::query("UPDATE faces SET cluster_id = $1 WHERE id = $2")
            .bind(cluster_id)
            .bind(face_id)
            .execute(pool)
            .await?;
    }
    Ok(())
}

pub async fn list_clusters(pool: &PgPool) -> Result<Vec<FaceCluster>, sqlx::Error> {
    let rows = sqlx::query_as::<_, (i32, Option<String>, i64)>(
        r#"SELECT f.cluster_id, fc.label, COUNT(*) as face_count
           FROM faces f
           LEFT JOIN face_cluster_labels fc ON fc.cluster_id = f.cluster_id
           WHERE f.cluster_id IS NOT NULL
           GROUP BY f.cluster_id, fc.label
           ORDER BY face_count DESC"#,
    )
    .fetch_all(pool)
    .await?;

    let mut clusters = Vec::with_capacity(rows.len());
    for (cluster_id, label, face_count) in rows {
        let sample_ids: Vec<(Uuid,)> = sqlx::query_as(
            "SELECT DISTINCT photo_id FROM faces WHERE cluster_id = $1 LIMIT 4",
        )
        .bind(cluster_id)
        .fetch_all(pool)
        .await?;

        clusters.push(FaceCluster {
            cluster_id,
            label,
            face_count,
            sample_photo_ids: sample_ids.into_iter().map(|(id,)| id).collect(),
        });
    }

    Ok(clusters)
}
