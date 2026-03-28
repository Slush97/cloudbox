use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2,
};
use sqlx::PgPool;

#[derive(Debug, sqlx::FromRow, serde::Serialize)]
pub struct User {
    pub id: uuid::Uuid,
    pub username: String,
    #[serde(skip)]
    pub password_hash: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

pub fn hash_password(password: &str) -> Result<String, argon2::password_hash::Error> {
    let salt = SaltString::generate(&mut OsRng);
    let hash = Argon2::default().hash_password(password.as_bytes(), &salt)?;
    Ok(hash.to_string())
}

pub async fn verify(pool: &PgPool, username: &str, password: &str) -> Result<Option<User>, sqlx::Error> {
    let user: Option<User> = sqlx::query_as("SELECT * FROM users WHERE username = $1")
        .bind(username)
        .fetch_optional(pool)
        .await?;

    let Some(user) = user else { return Ok(None) };

    let parsed = match PasswordHash::new(&user.password_hash) {
        Ok(h) => h,
        Err(_) => return Ok(None),
    };

    if Argon2::default()
        .verify_password(password.as_bytes(), &parsed)
        .is_ok()
    {
        Ok(Some(user))
    } else {
        Ok(None)
    }
}

pub async fn get_by_id(pool: &PgPool, id: uuid::Uuid) -> Result<Option<User>, sqlx::Error> {
    sqlx::query_as("SELECT * FROM users WHERE id = $1")
        .bind(id)
        .fetch_optional(pool)
        .await
}

pub async fn get_by_username(pool: &PgPool, username: &str) -> Result<Option<User>, sqlx::Error> {
    sqlx::query_as("SELECT * FROM users WHERE username = $1")
        .bind(username)
        .fetch_optional(pool)
        .await
}

pub async fn count(pool: &PgPool) -> Result<i64, sqlx::Error> {
    let row: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users")
        .fetch_one(pool)
        .await?;
    Ok(row.0)
}

pub async fn create(pool: &PgPool, username: &str, password: &str) -> Result<User, Box<dyn std::error::Error>> {
    let hash = hash_password(password).map_err(|e| e.to_string())?;
    let user = sqlx::query_as::<_, User>(
        "INSERT INTO users (username, password_hash) VALUES ($1, $2) RETURNING *",
    )
    .bind(username)
    .bind(hash)
    .fetch_one(pool)
    .await?;
    Ok(user)
}
