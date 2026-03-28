use std::path::Path;

use sqlx::PgPool;
use uuid::Uuid;

use crate::{classify::ImageClassifier, clip, faces::FacePipeline, VisionError};

/// Full vision processing pipeline for a single photo.
///
/// 1. Generate CLIP embedding (semantic search)
/// 2. Detect faces + extract embeddings (if pipeline available)
/// 3. Auto-tag with image classifier (if loaded)
/// 4. Store all results in the database
pub async fn process_photo(
    photo_id: Uuid,
    path: &Path,
    face_pipeline: Option<&FacePipeline>,
    classifier: Option<&ImageClassifier>,
    db: &PgPool,
) -> Result<(), VisionError> {
    let image_data = tokio::fs::read(path).await?;

    // 1. CLIP embedding for semantic search
    let clip_embedding = clip::encode_image(&image_data)?;
    tracing::debug!(%photo_id, "CLIP embedding generated");

    // Store CLIP embedding
    store_clip_embedding(db, photo_id, &clip_embedding).await?;

    // Decode image once for face detection + classification
    let rgb = match decode_to_rgb(&image_data) {
        Ok(img) => Some(img),
        Err(e) => {
            tracing::warn!(%photo_id, "image decode failed, skipping faces + classification: {e}");
            None
        }
    };

    // 2. Face detection + embedding
    if let (Some(pipeline), Some(ref img)) = (face_pipeline, &rgb) {
        let width = img.width();
        let height = img.height();

        let faces = pipeline.detect_and_embed(img.as_raw(), width, height, 0.5)?;
        tracing::debug!(%photo_id, face_count = faces.len(), "faces detected and embedded");

        for face in &faces {
            cloudbox_db::faces::insert_face(db, photo_id, face.bbox, &face.embedding).await?;
        }

        if !faces.is_empty() {
            tracing::debug!(%photo_id, stored = faces.len(), "face embeddings stored");

            // Auto-recluster so new faces appear in the UI immediately
            match crate::faces::recluster(db).await {
                Ok(result) => tracing::debug!(
                    clusters = result.clusters,
                    noise = result.noise,
                    total = result.total_faces,
                    "auto-recluster complete"
                ),
                Err(e) => tracing::warn!("auto-recluster failed: {e}"),
            }
        }
    }

    // 3. Auto-tagging via image classifier
    if let (Some(clf), Some(ref img)) = (classifier, &rgb) {
        match clf.auto_tag(img.as_raw(), img.width(), img.height(), 5, 0.15) {
            Ok(tags) => {
                for (tag_name, confidence) in &tags {
                    cloudbox_db::tags::add_tag(db, photo_id, tag_name, *confidence, "auto").await?;
                }
                tracing::debug!(%photo_id, tag_count = tags.len(), "auto-tags generated");
            }
            Err(e) => tracing::warn!(%photo_id, "auto-tagging failed: {e}"),
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
