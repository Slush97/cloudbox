use std::path::Path;
use uuid::Uuid;

use crate::{clip, faces::FacePipeline, VisionError};

/// Full vision processing pipeline for a single photo.
///
/// If a [`FacePipeline`] is provided, runs face detection + embedding.
/// Otherwise, only CLIP embedding is generated.
pub async fn process_photo(
    photo_id: Uuid,
    path: &Path,
    face_pipeline: Option<&FacePipeline>,
) -> Result<ProcessResult, VisionError> {
    let image_data = tokio::fs::read(path).await?;

    // 1. CLIP embedding for semantic search
    let clip_embedding = clip::encode_image(&image_data)?;
    tracing::debug!(%photo_id, "CLIP embedding generated");

    // TODO: store clip_embedding in photo_embeddings table via cloudbox-db

    // 2. Face detection + embedding (if pipeline available)
    let face_embeddings = if let Some(pipeline) = face_pipeline {
        // Decode image dimensions (cheap — just reads header)
        let (width, height) = image_dimensions(&image_data)?;

        let faces = pipeline.detect_and_embed(&image_data, width, height, 0.5)?;
        tracing::debug!(%photo_id, face_count = faces.len(), "faces detected and embedded");

        // TODO: store face bboxes + embeddings in faces / face_embeddings tables
        // via cloudbox-db::faces::insert_face()

        faces
    } else {
        vec![]
    };

    // 3. Re-cluster periodically (not every photo — batch job)
    // faces::cluster_faces(...) using scry-learn HDBSCAN

    Ok(ProcessResult {
        clip_embedding,
        face_embeddings,
    })
}

/// Result of processing a single photo through the vision pipeline.
pub struct ProcessResult {
    pub clip_embedding: Vec<f32>,
    pub face_embeddings: Vec<crate::faces::FaceEmbedding>,
}

/// Extract image dimensions from raw bytes without fully decoding.
fn image_dimensions(data: &[u8]) -> Result<(u32, u32), VisionError> {
    // PNG: bytes 16-23 contain width (4 bytes BE) and height (4 bytes BE)
    if data.len() >= 24 && &data[0..8] == b"\x89PNG\r\n\x1a\n" {
        let w = u32::from_be_bytes([data[16], data[17], data[18], data[19]]);
        let h = u32::from_be_bytes([data[20], data[21], data[22], data[23]]);
        return Ok((w, h));
    }

    // JPEG: scan for SOF0 marker (0xFF 0xC0)
    if data.len() >= 2 && data[0] == 0xFF && data[1] == 0xD8 {
        let mut i = 2;
        while i + 9 < data.len() {
            if data[i] != 0xFF {
                i += 1;
                continue;
            }
            let marker = data[i + 1];
            // SOF0, SOF1, SOF2 markers
            if matches!(marker, 0xC0 | 0xC1 | 0xC2) {
                let h = u16::from_be_bytes([data[i + 5], data[i + 6]]) as u32;
                let w = u16::from_be_bytes([data[i + 7], data[i + 8]]) as u32;
                return Ok((w, h));
            }
            let seg_len = u16::from_be_bytes([data[i + 2], data[i + 3]]) as usize;
            i += 2 + seg_len;
        }
    }

    // Fallback: treat as raw RGB (caller should provide dimensions)
    Err(VisionError::Inference(
        "could not determine image dimensions from header".into(),
    ))
}
