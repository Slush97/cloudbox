use std::path::Path;
use uuid::Uuid;

use crate::{clip, faces, VisionError};

/// Full vision processing pipeline for a single photo.
pub async fn process_photo(photo_id: Uuid, path: &Path) -> Result<(), VisionError> {
    let image_data = tokio::fs::read(path).await?;

    // 1. CLIP embedding for semantic search
    let clip_embedding = clip::encode_image(&image_data)?;
    tracing::debug!(%photo_id, "CLIP embedding generated");

    // TODO: store clip_embedding in photo_embeddings table via cloudbox-db

    // 2. Face detection
    let detections = faces::detect_faces(&image_data)?;
    tracing::debug!(%photo_id, face_count = detections.len(), "faces detected");

    if !detections.is_empty() {
        // 3. Face embeddings
        let face_embeddings = faces::extract_embeddings(&image_data, &detections)?;
        tracing::debug!(%photo_id, "face embeddings extracted");

        // TODO: store face bboxes + embeddings in faces / face_embeddings tables

        // 4. Re-cluster periodically (not every photo — batch job)
        // faces::cluster_faces(...) using scry-learn HDBSCAN
    }

    Ok(())
}
