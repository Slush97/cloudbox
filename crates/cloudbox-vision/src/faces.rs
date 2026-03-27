/// Face detection + embedding pipeline — powered by scry-llm + scry-learn.
///
/// Detection: SCRFD or RetinaFace model loaded as safetensors, run through scry-llm.
/// Embeddings: ArcFace model for 512-dim face embeddings.
/// Clustering: scry-learn's HDBSCAN for grouping faces into identities.

pub struct FaceDetection {
    pub bbox: [f32; 4],      // x, y, w, h (normalized 0..1)
    pub confidence: f32,
    pub landmarks: [[f32; 2]; 5], // eyes, nose, mouth corners
}

pub struct FaceEmbedding {
    pub bbox: [f32; 4],
    pub embedding: Vec<f32>,  // 512-dim ArcFace embedding
}

pub fn detect_faces(image_data: &[u8]) -> Result<Vec<FaceDetection>, crate::VisionError> {
    // TODO: SCRFD model via scry-llm
    // 1. Preprocess: resize to 640x640, normalize
    // 2. Forward pass — SCRFD is a simple CNN, all ops exist in scry-llm
    // 3. Decode outputs: stride-8/16/32 feature maps → bboxes + landmarks
    // 4. NMS (non-maximum suppression) — straightforward to implement
    let _ = image_data;
    Ok(vec![])
}

pub fn extract_embeddings(
    image_data: &[u8],
    faces: &[FaceDetection],
) -> Result<Vec<FaceEmbedding>, crate::VisionError> {
    // TODO: ArcFace model via scry-llm
    // 1. For each detected face, crop + align using landmarks (affine transform)
    // 2. Resize aligned face to 112x112
    // 3. Forward pass through ArcFace ResNet backbone
    // 4. L2-normalize embedding
    let _ = (image_data, faces);
    Ok(vec![])
}

pub fn cluster_faces(embeddings: &[[f32; 512]]) -> Vec<Option<i32>> {
    // Use scry-learn's HDBSCAN directly
    // This is the part that would be ~500 lines to implement from scratch,
    // but you already built it in scry-learn::cluster::hdbscan
    //
    // let clusterer = scry_learn::cluster::Hdbscan::new()
    //     .min_cluster_size(5)
    //     .min_samples(3);
    // let labels = clusterer.fit_predict(&dataset);

    let _ = embeddings;
    vec![]
}
