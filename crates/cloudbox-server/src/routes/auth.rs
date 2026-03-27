use axum::{extract::State, routing::post, Json, Router};
use serde::{Deserialize, Serialize};

use crate::{auth, error::AppError, state::AppState};

pub fn router() -> Router<AppState> {
    Router::new().route("/login", post(login))
}

#[derive(Deserialize)]
struct LoginRequest {
    username: String,
    password: String,
}

#[derive(Serialize)]
struct LoginResponse {
    token: String,
}

async fn login(
    State(state): State<AppState>,
    Json(req): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, AppError> {
    // TODO: verify credentials against db (single-user, so this can be simple)
    let _user = cloudbox_db::users::verify(&state.db, &req.username, &req.password)
        .await?
        .ok_or(AppError::Unauthorized)?;

    let token = auth::create_token(&state.jwt_secret, &req.username)?;
    Ok(Json(LoginResponse { token }))
}
