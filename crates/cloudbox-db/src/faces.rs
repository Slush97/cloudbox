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

pub async fn insert_face(
    pool: &PgPool,
    id: Uuid,
    photo_id: Uuid,
    bbox: [f32; 4],
    embedding: &[f32],
) -> Result<Face, sqlx::Error> {
    sqlx::query_as(
        r#"WITH ins AS (
               INSERT INTO faces (id, photo_id, bbox_x, bbox_y, bbox_w, bbox_h)
               VALUES ($1, $2, $3, $4, $5, $6)
               RETURNING *
           )
           INSERT INTO face_embeddings (face_id, embedding)
           VALUES ($1, $7::vector)
           RETURNING (SELECT ins.* FROM ins)"#,
    )
    .bind(id)
    .bind(photo_id)
    .bind(bbox[0])
    .bind(bbox[1])
    .bind(bbox[2])
    .bind(bbox[3])
    .bind(serde_json::to_string(embedding).unwrap())
    .fetch_one(pool)
    .await
}

pub async fn list_clusters(pool: &PgPool) -> Result<Vec<FaceCluster>, sqlx::Error> {
    // Raw query — aggregate clusters with counts and sample photos
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
