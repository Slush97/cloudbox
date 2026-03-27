use sqlx::PgPool;

#[derive(Debug, sqlx::FromRow, serde::Serialize)]
pub struct User {
    pub id: uuid::Uuid,
    pub username: String,
    pub password_hash: String,
}

pub async fn verify(pool: &PgPool, username: &str, password: &str) -> Result<Option<User>, sqlx::Error> {
    let user = sqlx::query_as::<_, User>("SELECT * FROM users WHERE username = $1")
        .bind(username)
        .fetch_optional(pool)
        .await?;

    // TODO: bcrypt/argon2 verify against password_hash
    let _ = password;
    Ok(user)
}
