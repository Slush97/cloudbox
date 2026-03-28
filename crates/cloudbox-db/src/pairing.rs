use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

#[derive(Debug, sqlx::FromRow, serde::Serialize)]
pub struct PairingCode {
    pub id: Uuid,
    pub code: String,
    pub user_id: Uuid,
    pub claimed: bool,
    pub expires_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
}

pub async fn create(
    pool: &PgPool,
    user_id: Uuid,
    code: &str,
    expires_at: DateTime<Utc>,
) -> Result<PairingCode, sqlx::Error> {
    sqlx::query_as(
        r#"INSERT INTO pairing_codes (user_id, code, expires_at)
           VALUES ($1, $2, $3)
           RETURNING *"#,
    )
    .bind(user_id)
    .bind(code)
    .bind(expires_at)
    .fetch_one(pool)
    .await
}

/// Atomically claim a pairing code. Returns None if invalid, expired, or already claimed.
pub async fn claim(pool: &PgPool, code: &str) -> Result<Option<PairingCode>, sqlx::Error> {
    sqlx::query_as(
        r#"UPDATE pairing_codes
           SET claimed = TRUE
           WHERE code = $1 AND claimed = FALSE AND expires_at > now()
           RETURNING *"#,
    )
    .bind(code)
    .fetch_optional(pool)
    .await
}

pub async fn cleanup_expired(pool: &PgPool) {
    let result = sqlx::query("DELETE FROM pairing_codes WHERE expires_at < now()")
        .execute(pool)
        .await;
    if let Ok(r) = result {
        let count = r.rows_affected();
        if count > 0 {
            tracing::info!(count, "cleaned up expired pairing codes");
        }
    }
}
