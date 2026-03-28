use std::sync::Arc;

use sqlx::PgPool;

use crate::config::Config;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub jwt_secret: String,
    pub storage_path: String,
    pub auth_disabled: bool,
    pub face_pipeline: Option<Arc<cloudbox_vision::faces::FacePipeline>>,
}

impl AppState {
    pub async fn new(config: &Config) -> Result<Self, sqlx::Error> {
        let db = PgPool::connect(&config.database_url).await?;
        sqlx::migrate!("../../migrations").run(&db).await?;

        let face_pipeline = try_load_face_pipeline(config.models_path.as_deref());

        Ok(Self {
            db,
            jwt_secret: config.jwt_secret.clone(),
            storage_path: config.storage_path.clone(),
            auth_disabled: config.auth_disabled,
            face_pipeline,
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
