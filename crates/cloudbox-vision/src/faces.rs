/// Face detection + embedding pipeline — powered by scry-vision + scry-learn.
///
/// Detection:  SCRFD via scry-vision (any VisionModel backend — ONNX or mock).
/// Embedding:  ArcFace 512-dim face embeddings via scry-vision.
/// Clustering: scry-learn HDBSCAN for grouping faces into identities.
///
/// The [`FacePipeline`] struct is the main entry point. Construct it once at
/// server startup (with real ONNX models) or in tests (with mock models), then
/// call [`FacePipeline::detect_and_embed`] for each uploaded photo.

use scry_vision::image::ImageBuffer;
use scry_vision::model::VisionModel;
use scry_vision::models::{ArcFaceEmbedder, ScrfdDetector};
use scry_vision::pipeline::{Detect, Embed};
use scry_vision::transform::{Crop, ImageTransform};

use crate::VisionError;

/// Detected face with normalized bounding box.
pub struct FaceDetection {
    /// Bounding box `[x, y, w, h]` normalized to `0..1` relative to image size.
    pub bbox: [f32; 4],
    pub confidence: f32,
}

/// Detected face with its 512-dim ArcFace embedding.
pub struct FaceEmbedding {
    /// Bounding box `[x, y, w, h]` normalized to `0..1` relative to image size.
    pub bbox: [f32; 4],
    /// 512-dim L2-normalized ArcFace embedding.
    pub embedding: Vec<f32>,
}

/// Face detection + embedding pipeline.
///
/// Wraps SCRFD (detection) and ArcFace (embedding) from scry-vision.
/// Accepts any [`VisionModel`] backend — use ONNX for production, mock for tests.
///
/// # Example (mock)
/// ```ignore
/// let pipeline = FacePipeline::new(mock_scrfd, mock_arcface, 640);
/// let faces = pipeline.detect_and_embed(image_data, width, height)?;
/// ```
pub struct FacePipeline {
    detector: ScrfdDetector,
    embedder: ArcFaceEmbedder,
}

impl FacePipeline {
    /// Create a pipeline from any VisionModel backends.
    ///
    /// - `detector_model` — SCRFD model (input: `detector_input_size × detector_input_size`)
    /// - `embedder_model` — ArcFace model (input: 112×112, output: 512-dim)
    /// - `detector_input_size` — SCRFD input resolution (typically 640)
    pub fn new(
        detector_model: Box<dyn VisionModel>,
        embedder_model: Box<dyn VisionModel>,
        detector_input_size: u32,
    ) -> Self {
        Self {
            detector: ScrfdDetector::new(detector_model, detector_input_size),
            embedder: ArcFaceEmbedder::new(embedder_model, 112, 512),
        }
    }

    /// Load from ONNX model files.
    #[cfg(feature = "ml")]
    pub fn from_onnx(
        scrfd_path: impl AsRef<std::path::Path>,
        arcface_path: impl AsRef<std::path::Path>,
        detector_input_size: u32,
    ) -> Result<Self, VisionError> {
        let detector = ScrfdDetector::from_onnx(scrfd_path, detector_input_size)
            .map_err(|e| VisionError::Inference(e.to_string()))?;
        let embedder = ArcFaceEmbedder::from_onnx(arcface_path)
            .map_err(|e| VisionError::Inference(e.to_string()))?;
        Ok(Self { detector, embedder })
    }

    /// Detect faces in an image.
    ///
    /// Returns bounding boxes with confidence scores, normalized to `0..1`.
    pub fn detect(
        &self,
        image_data: &[u8],
        width: u32,
        height: u32,
        conf_threshold: f32,
    ) -> Result<Vec<FaceDetection>, VisionError> {
        let detections = self
            .detector
            .detect(image_data, width, height, conf_threshold)
            .map_err(|e| VisionError::Inference(e.to_string()))?;

        let w = width as f32;
        let h = height as f32;

        Ok(detections
            .into_iter()
            .map(|d| {
                let bx = d.bbox.x1.max(0.0) / w;
                let by = d.bbox.y1.max(0.0) / h;
                let bw = (d.bbox.x2 - d.bbox.x1).max(0.0) / w;
                let bh = (d.bbox.y2 - d.bbox.y1).max(0.0) / h;
                FaceDetection {
                    bbox: [bx, by, bw, bh],
                    confidence: d.confidence,
                }
            })
            .collect())
    }

    /// Detect faces and extract embeddings in one pass.
    ///
    /// For each detected face: crop → resize to 112×112 → ArcFace embed.
    pub fn detect_and_embed(
        &self,
        image_data: &[u8],
        width: u32,
        height: u32,
        conf_threshold: f32,
    ) -> Result<Vec<FaceEmbedding>, VisionError> {
        let detections = self
            .detector
            .detect(image_data, width, height, conf_threshold)
            .map_err(|e| VisionError::Inference(e.to_string()))?;

        if detections.is_empty() {
            return Ok(vec![]);
        }

        let img = ImageBuffer::from_raw(image_data.to_vec(), width, height, 3)
            .map_err(|e| VisionError::Inference(e.to_string()))?;

        let w = width as f32;
        let h = height as f32;
        let mut results = Vec::with_capacity(detections.len());

        for det in &detections {
            // Clamp bbox to image bounds
            let x = (det.bbox.x1.max(0.0) as u32).min(width - 1);
            let y = (det.bbox.y1.max(0.0) as u32).min(height - 1);
            let x2 = (det.bbox.x2.max(0.0) as u32).min(width);
            let y2 = (det.bbox.y2.max(0.0) as u32).min(height);
            let cw = x2.saturating_sub(x).max(1);
            let ch = y2.saturating_sub(y).max(1);

            let crop = Crop::new(x, y, cw, ch)
                .apply(&img)
                .map_err(|e| VisionError::Inference(e.to_string()))?;

            let embedding = self
                .embedder
                .embed(&crop.data, crop.width, crop.height)
                .map_err(|e| VisionError::Inference(e.to_string()))?;

            let bx = det.bbox.x1.max(0.0) / w;
            let by = det.bbox.y1.max(0.0) / h;
            let bw = (det.bbox.x2 - det.bbox.x1).max(0.0) / w;
            let bh = (det.bbox.y2 - det.bbox.y1).max(0.0) / h;

            results.push(FaceEmbedding {
                bbox: [bx, by, bw, bh],
                embedding,
            });
        }

        Ok(results)
    }
}

/// Cluster face embeddings into identity groups using HDBSCAN.
///
/// Returns one label per embedding: `Some(cluster_id)` or `None` for noise.
/// Requires the `ml` feature.
#[cfg(feature = "ml")]
pub fn cluster_faces(embeddings: &[Vec<f32>]) -> Vec<Option<i32>> {
    use scry_learn::cluster::Hdbscan;
    use scry_learn::dataset::Dataset;

    if embeddings.is_empty() {
        return vec![];
    }

    let n = embeddings.len();
    let dim = embeddings[0].len();

    // Convert to column-major f64 for Dataset
    let mut features = vec![vec![0.0f64; n]; dim];
    for (i, emb) in embeddings.iter().enumerate() {
        for (j, &val) in emb.iter().enumerate() {
            features[j][i] = val as f64;
        }
    }
    let names: Vec<String> = (0..dim).map(|i| format!("d{i}")).collect();
    let target = vec![0.0f64; n];
    let data = Dataset::new(features, target, names, "cluster");

    let mut hdb = Hdbscan::new().min_cluster_size(3).min_samples(5);

    match hdb.fit(&data) {
        Ok(()) => hdb
            .labels()
            .iter()
            .map(|&l| if l < 0 { None } else { Some(l) })
            .collect(),
        Err(e) => {
            tracing::warn!("HDBSCAN clustering failed: {e}");
            vec![None; n]
        }
    }
}

/// Stub when `ml` feature is disabled.
#[cfg(not(feature = "ml"))]
pub fn cluster_faces(embeddings: &[Vec<f32>]) -> Vec<Option<i32>> {
    vec![None; embeddings.len()]
}

/// Re-cluster all face embeddings in the database.
///
/// Fetches every embedding, runs HDBSCAN, and updates `faces.cluster_id`.
/// Returns the number of clusters found.
pub async fn recluster(db: &sqlx::PgPool) -> Result<ReclusterResult, crate::VisionError> {
    let rows = cloudbox_db::faces::fetch_all_embeddings(db).await?;

    if rows.is_empty() {
        return Ok(ReclusterResult {
            total_faces: 0,
            clusters: 0,
            noise: 0,
        });
    }

    let (face_ids, embeddings): (Vec<_>, Vec<_>) = rows.into_iter().unzip();
    let labels = cluster_faces(&embeddings);

    let assignments: Vec<_> = face_ids
        .into_iter()
        .zip(labels.iter().copied())
        .collect();

    cloudbox_db::faces::update_cluster_ids(db, &assignments).await?;

    let clusters = labels.iter().filter_map(|l| *l).collect::<std::collections::HashSet<_>>().len();
    let noise = labels.iter().filter(|l| l.is_none()).count();

    Ok(ReclusterResult {
        total_faces: labels.len(),
        clusters,
        noise,
    })
}

#[derive(Debug, serde::Serialize)]
pub struct ReclusterResult {
    pub total_faces: usize,
    pub clusters: usize,
    pub noise: usize,
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Mock model returning a fixed output — same pattern as scry-vision tests.
    struct MockModel {
        output: Vec<f32>,
    }

    impl VisionModel for MockModel {
        fn forward(
            &self,
            _input: &[f32],
            _input_shape: &[usize],
        ) -> scry_vision::error::Result<Vec<f32>> {
            Ok(self.output.clone())
        }

        fn output_shape(&self, _input_shape: &[usize]) -> Vec<usize> {
            vec![self.output.len()]
        }
    }

    fn mock_pipeline(scrfd_output: Vec<f32>, arcface_output: Vec<f32>) -> FacePipeline {
        FacePipeline::new(
            Box::new(MockModel {
                output: scrfd_output,
            }),
            Box::new(MockModel {
                output: arcface_output,
            }),
            640,
        )
    }

    fn test_image(w: u32, h: u32) -> Vec<u8> {
        vec![128u8; (w * h * 3) as usize]
    }

    #[test]
    fn detect_returns_normalized_bbox() {
        // 1 face at cx=320, cy=320, w=80, h=80 in a 640×640 image
        #[rustfmt::skip]
        let scrfd = vec![
            320.0, // cx
            320.0, // cy
             80.0, // w
             80.0, // h
              0.9, // confidence
        ];

        let pipeline = mock_pipeline(scrfd, vec![0.0; 512]);
        let dets = pipeline.detect(&test_image(640, 640), 640, 640, 0.5).unwrap();

        assert_eq!(dets.len(), 1);
        let d = &dets[0];
        // bbox x1=280, y1=280 → normalized: 280/640 = 0.4375
        assert!((d.bbox[0] - 0.4375).abs() < 0.01);
        assert!((d.bbox[1] - 0.4375).abs() < 0.01);
        // bbox w=80, h=80 → normalized: 80/640 = 0.125
        assert!((d.bbox[2] - 0.125).abs() < 0.01);
        assert!((d.bbox[3] - 0.125).abs() < 0.01);
    }

    #[test]
    fn detect_and_embed_end_to_end() {
        // SCRFD: 1 face centered at (320, 320)
        #[rustfmt::skip]
        let scrfd = vec![
            320.0, // cx
            320.0, // cy
            100.0, // w
            100.0, // h
              0.9, // confidence
        ];

        // ArcFace: known 512-dim output
        let mut arcface = vec![0.0f32; 512];
        arcface[0] = 3.0;
        arcface[1] = 4.0;

        let pipeline = mock_pipeline(scrfd, arcface);
        let faces = pipeline
            .detect_and_embed(&test_image(640, 640), 640, 640, 0.5)
            .unwrap();

        assert_eq!(faces.len(), 1);
        assert_eq!(faces[0].embedding.len(), 512);

        // Embedding should be L2-normalized
        let norm: f32 = faces[0].embedding.iter().map(|x| x * x).sum::<f32>().sqrt();
        assert!((norm - 1.0).abs() < 1e-4);

        // Direction preserved: [0.6, 0.8, 0, ...]
        assert!((faces[0].embedding[0] - 0.6).abs() < 1e-4);
        assert!((faces[0].embedding[1] - 0.8).abs() < 1e-4);
    }

    #[test]
    fn no_faces_returns_empty() {
        #[rustfmt::skip]
        let scrfd = vec![
            320.0, 320.0, 100.0, 100.0, 0.1, // below threshold
        ];

        let pipeline = mock_pipeline(scrfd, vec![0.0; 512]);
        let faces = pipeline
            .detect_and_embed(&test_image(640, 640), 640, 640, 0.5)
            .unwrap();

        assert!(faces.is_empty());
    }

    #[test]
    fn detect_with_non_square_image() {
        // 1280×720 image, face at model coords (320, 320)
        // Letterbox: scale=0.5, pad_y=140 → original cx=640, cy=360
        #[rustfmt::skip]
        let scrfd = vec![
            320.0, // cx
            320.0, // cy
            100.0, // w
            100.0, // h
              0.9, // confidence
        ];

        let pipeline = mock_pipeline(scrfd, vec![0.0; 512]);
        let dets = pipeline
            .detect(&test_image(1280, 720), 1280, 720, 0.5)
            .unwrap();

        assert_eq!(dets.len(), 1);
        let d = &dets[0];
        // cx=640 in 1280-wide → bbox_x normalized around 0.42
        // cy=360 in 720-high → bbox_y normalized around 0.36
        assert!(d.bbox[0] > 0.3 && d.bbox[0] < 0.55, "bbox_x={}", d.bbox[0]);
        assert!(d.bbox[1] > 0.2 && d.bbox[1] < 0.5, "bbox_y={}", d.bbox[1]);
    }
}
