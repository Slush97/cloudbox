pub mod clip;
pub mod faces;
pub mod pipeline;

use std::path::PathBuf;
use std::sync::Arc;

use sqlx::PgPool;
use uuid::Uuid;

use faces::FacePipeline;

#[derive(Debug, thiserror::Error)]
pub enum VisionError {
    #[error("io: {0}")]
    Io(#[from] std::io::Error),

    #[error("model inference failed: {0}")]
    Inference(String),

    #[error("database: {0}")]
    Db(#[from] sqlx::Error),
}

/// Queue a photo for async vision processing.
///
/// In the background this will:
/// 1. Generate a CLIP embedding for semantic search
/// 2. Run face detection + embedding (if pipeline loaded)
/// 3. Store results in the database
///
/// Pass `None` for `face_pipeline` if models are not yet loaded — face
/// detection will be skipped gracefully.
pub fn queue_photo(
    photo_id: Uuid,
    path: PathBuf,
    face_pipeline: Option<Arc<FacePipeline>>,
    db: PgPool,
) {
    tokio::spawn(async move {
        let fp = face_pipeline.as_deref();
        if let Err(e) = pipeline::process_photo(photo_id, &path, fp, &db).await {
            tracing::error!(%photo_id, "vision pipeline failed: {e}");
        }
    });
}
