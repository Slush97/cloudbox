use std::sync::Arc;

use sqlx::PgPool;

use crate::config::Config;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub jwt_secret: String,
    pub storage_path: String,
    pub face_pipeline: Option<Arc<cloudbox_vision::faces::FacePipeline>>,
    pub classifier: Option<Arc<cloudbox_vision::classify::ImageClassifier>>,
}

impl AppState {
    pub async fn new(config: &Config) -> Result<Self, sqlx::Error> {
        let db = PgPool::connect(&config.database_url).await?;
        sqlx::migrate!("../../migrations").run(&db).await?;

        let face_pipeline = try_load_face_pipeline(config.models_path.as_deref());
        let classifier = try_load_classifier(config.models_path.as_deref());

        Ok(Self {
            db,
            jwt_secret: config.jwt_secret.clone(),
            storage_path: config.storage_path.clone(),
            face_pipeline,
            classifier,
        })
    }
}

/// Attempt to load SCRFD + ArcFace ONNX models from the models directory.
///
/// Expects `{models_path}/scrfd.onnx` and `{models_path}/arcface.onnx`.
/// Returns `None` if the path is unset or models are missing — face detection
/// will be silently disabled.
fn try_load_face_pipeline(
    models_path: Option<&str>,
) -> Option<Arc<cloudbox_vision::faces::FacePipeline>> {
    let dir = models_path?;
    let scrfd = std::path::Path::new(dir).join("scrfd.onnx");
    let arcface = std::path::Path::new(dir).join("arcface.onnx");

    if !scrfd.exists() || !arcface.exists() {
        tracing::info!(
            "face models not found at {dir}/{{scrfd,arcface}}.onnx — face detection disabled"
        );
        return None;
    }

    #[cfg(feature = "ml")]
    {
        match cloudbox_vision::faces::FacePipeline::from_onnx(&scrfd, &arcface, 640) {
            Ok(pipeline) => {
                tracing::info!("face pipeline loaded from {dir}");
                Some(Arc::new(pipeline))
            }
            Err(e) => {
                tracing::warn!("failed to load face pipeline: {e} — face detection disabled");
                None
            }
        }
    }

    #[cfg(not(feature = "ml"))]
    {
        tracing::info!("face pipeline not available (ml feature disabled)");
        None
    }
}

/// Attempt to load MobileNet v2 ONNX model for auto-tagging.
///
/// Expects `{models_path}/mobilenet_v2.onnx`. Returns `None` if the path is
/// unset or model is missing — auto-tagging will be silently disabled.
fn try_load_classifier(
    models_path: Option<&str>,
) -> Option<Arc<cloudbox_vision::classify::ImageClassifier>> {
    let dir = models_path?;
    let model_path = std::path::Path::new(dir).join("mobilenet_v2.onnx");

    if !model_path.exists() {
        tracing::info!(
            "classifier model not found at {dir}/mobilenet_v2.onnx — auto-tagging disabled"
        );
        return None;
    }

    #[cfg(feature = "ml")]
    {
        match cloudbox_vision::classify::ImageClassifier::from_onnx(&model_path) {
            Ok(clf) => {
                tracing::info!("image classifier loaded from {dir}");
                Some(Arc::new(clf))
            }
            Err(e) => {
                tracing::warn!("failed to load classifier: {e} — auto-tagging disabled");
                None
            }
        }
    }

    #[cfg(not(feature = "ml"))]
    {
        tracing::info!("classifier not available (ml feature disabled)");
        None
    }
}
