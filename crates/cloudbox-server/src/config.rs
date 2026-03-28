use std::env;

pub struct Config {
    pub host: String,
    pub port: u16,
    pub database_url: String,
    pub jwt_secret: String,
    pub storage_path: String,
    pub auth_disabled: bool,
    pub s3_endpoint: Option<String>,
    pub s3_bucket: Option<String>,
    /// Directory containing ONNX models (scrfd.onnx, arcface.onnx).
    /// If unset or models not found, face detection is disabled.
    pub models_path: Option<String>,
}

impl Config {
    pub fn from_env() -> Result<Self, env::VarError> {
        Ok(Self {
            host: env::var("CLOUDBOX_HOST").unwrap_or_else(|_| "0.0.0.0".into()),
            port: env::var("CLOUDBOX_PORT")
                .unwrap_or_else(|_| "3000".into())
                .parse()
                .unwrap_or(3000),
            database_url: env::var("DATABASE_URL")?,
            jwt_secret: env::var("JWT_SECRET").unwrap_or_else(|_| "cloudbox-dev-secret".into()),
            storage_path: env::var("STORAGE_PATH").unwrap_or_else(|_| "./data".into()),
            auth_disabled: env::var("AUTH_DISABLED").map(|v| v == "true" || v == "1").unwrap_or(false),
            s3_endpoint: env::var("S3_ENDPOINT").ok(),
            s3_bucket: env::var("S3_BUCKET").ok(),
            models_path: env::var("MODELS_PATH").ok(),
        })
    }
}
