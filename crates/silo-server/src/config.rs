use std::env;

pub struct Config {
    pub host: String,
    pub port: u16,
    pub database_url: String,
    pub jwt_secret: String,
    pub storage_path: String,
    pub cors_origin: Option<String>,
    pub max_upload_bytes: usize,
}

impl Config {
    pub fn from_env() -> anyhow::Result<Self> {
        let database_url = env::var("DATABASE_URL")
            .map_err(|_| anyhow::anyhow!("DATABASE_URL is required"))?;

        let jwt_secret = env::var("JWT_SECRET").map_err(|_| {
            anyhow::anyhow!(
                "JWT_SECRET is required — generate one with: openssl rand -hex 32"
            )
        })?;

        let max_upload_bytes = env::var("MAX_UPLOAD_BYTES")
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or(10 * 1024 * 1024 * 1024); // 10 GB

        Ok(Self {
            host: env::var("SILO_HOST").unwrap_or_else(|_| "0.0.0.0".into()),
            port: env::var("SILO_PORT")
                .unwrap_or_else(|_| "3000".into())
                .parse()
                .unwrap_or(3000),
            database_url,
            jwt_secret,
            storage_path: env::var("STORAGE_PATH").unwrap_or_else(|_| "./data".into()),
            cors_origin: env::var("CORS_ORIGIN").ok(),
            max_upload_bytes,
        })
    }
}
