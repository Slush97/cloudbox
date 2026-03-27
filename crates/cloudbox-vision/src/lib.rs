pub mod clip;
pub mod faces;
pub mod pipeline;

use std::path::PathBuf;
use uuid::Uuid;

#[derive(Debug, thiserror::Error)]
pub enum VisionError {
    #[error("io: {0}")]
    Io(#[from] std::io::Error),

    #[error("model inference failed: {0}")]
    Inference(String),
}

/// Queue a photo for async vision processing.
///
/// In the background this will:
/// 1. Generate a CLIP embedding for semantic search
/// 2. Run face detection (SCRFD/RetinaFace via scry-llm tensor infra)
/// 3. Extract face embeddings (ArcFace)
/// 4. Periodically re-cluster all face embeddings (scry-learn HDBSCAN)
pub fn queue_photo(photo_id: Uuid, path: PathBuf) {
    tokio::spawn(async move {
        if let Err(e) = pipeline::process_photo(photo_id, &path).await {
            tracing::error!(%photo_id, "vision pipeline failed: {e}");
        }
    });
}
