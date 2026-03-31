use sqlx::PgPool;

use crate::config::Config;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub jwt_secret: String,
    pub storage_path: String,
}

impl AppState {
    pub async fn new(config: &Config) -> Result<Self, sqlx::Error> {
        let db = PgPool::connect(&config.database_url).await?;
        sqlx::migrate!("../../migrations").run(&db).await?;

        Ok(Self {
            db,
            jwt_secret: config.jwt_secret.clone(),
            storage_path: config.storage_path.clone(),
        })
    }
}
