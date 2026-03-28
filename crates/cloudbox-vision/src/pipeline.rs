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
        let (width, height) = match image_dimensions(&image_data) {
            Ok(dims) => dims,
            Err(e) => {
                tracing::warn!(%photo_id, "skipping face detection: {e}");
                return Ok(());
            }
        };

        let faces = pipeline.detect_and_embed(&image_data, width, height, 0.5)?;
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

/// Extract image dimensions from raw bytes without fully decoding.
fn image_dimensions(data: &[u8]) -> Result<(u32, u32), VisionError> {
    // PNG: bytes 16-23 contain width (4 bytes BE) and height (4 bytes BE)
    if data.len() >= 24 && &data[0..8] == b"\x89PNG\r\n\x1a\n" {
        let w = u32::from_be_bytes([data[16], data[17], data[18], data[19]]);
        let h = u32::from_be_bytes([data[20], data[21], data[22], data[23]]);
        return Ok((w, h));
    }

    // JPEG: scan for SOF0/SOF1/SOF2 marker
    if data.len() >= 2 && data[0] == 0xFF && data[1] == 0xD8 {
        let mut i = 2;
        while i + 9 < data.len() {
            if data[i] != 0xFF {
                i += 1;
                continue;
            }
            let marker = data[i + 1];
            if matches!(marker, 0xC0 | 0xC1 | 0xC2) {
                let h = u16::from_be_bytes([data[i + 5], data[i + 6]]) as u32;
                let w = u16::from_be_bytes([data[i + 7], data[i + 8]]) as u32;
                return Ok((w, h));
            }
            if i + 3 >= data.len() {
                break;
            }
            let seg_len = u16::from_be_bytes([data[i + 2], data[i + 3]]) as usize;
            i += 2 + seg_len;
        }
    }

    Err(VisionError::Inference(
        "could not determine image dimensions from header".into(),
    ))
}
