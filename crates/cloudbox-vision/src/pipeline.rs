use std::path::Path;

use sqlx::PgPool;
use uuid::Uuid;

use crate::{clip, faces::FacePipeline, VisionError};

/// Full vision processing pipeline for a single photo.
///
/// 1. Generate CLIP embedding (semantic search)
/// 2. Detect faces + extract embeddings (if pipeline available)
/// 3. Store all results in the database
pub async fn process_photo(
    photo_id: Uuid,
    path: &Path,
    face_pipeline: Option<&FacePipeline>,
    db: &PgPool,
) -> Result<(), VisionError> {
    let image_data = tokio::fs::read(path).await?;

    // 1. CLIP embedding for semantic search
    let clip_embedding = clip::encode_image(&image_data)?;
    tracing::debug!(%photo_id, "CLIP embedding generated");

    // Store CLIP embedding
    store_clip_embedding(db, photo_id, &clip_embedding).await?;

    // 2. Face detection + embedding
    if let Some(pipeline) = face_pipeline {
        let rgb = match decode_to_rgb(&image_data) {
            Ok(img) => img,
            Err(e) => {
                tracing::warn!(%photo_id, "skipping face detection: {e}");
                return Ok(());
            }
        };
        let width = rgb.width();
        let height = rgb.height();
        let pixels = rgb.into_raw();

        let faces = pipeline.detect_and_embed(&pixels, width, height, 0.5)?;
        tracing::debug!(%photo_id, face_count = faces.len(), "faces detected and embedded");

        for face in &faces {
            cloudbox_db::faces::insert_face(db, photo_id, face.bbox, &face.embedding).await?;
        }

        if !faces.is_empty() {
            tracing::debug!(%photo_id, stored = faces.len(), "face embeddings stored");
        }
    }

    Ok(())
}

/// Store a CLIP embedding in the photo_embeddings table.
async fn store_clip_embedding(
    db: &PgPool,
    photo_id: Uuid,
    embedding: &[f32],
) -> Result<(), VisionError> {
    let embedding_json = serde_json::to_string(embedding).unwrap();
    sqlx::query(
        "INSERT INTO photo_embeddings (photo_id, clip_embedding) VALUES ($1, $2::vector)
         ON CONFLICT (photo_id) DO UPDATE SET clip_embedding = EXCLUDED.clip_embedding",
    )
    .bind(photo_id)
    .bind(&embedding_json)
    .execute(db)
    .await?;
    Ok(())
}

/// Decode encoded image bytes (JPEG, PNG, etc.) into an RGB8 pixel buffer.
fn decode_to_rgb(data: &[u8]) -> Result<image::RgbImage, VisionError> {
    let img = image::load_from_memory(data)
        .map_err(|e| VisionError::Inference(format!("image decode failed: {e}")))?;
    Ok(img.into_rgb8())
}
