use axum::{
    extract::State,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};

use crate::{auth, error::AppError, state::AppState};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/login", post(login))
        .route("/setup", post(setup))
        .route("/status", get(status))
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

#[derive(Serialize)]
struct AuthStatus {
    needs_setup: bool,
    auth_disabled: bool,
}

async fn status(State(state): State<AppState>) -> Result<Json<AuthStatus>, AppError> {
    let user_count = cloudbox_db::users::count(&state.db).await?;
    Ok(Json(AuthStatus {
        needs_setup: user_count == 0,
        auth_disabled: state.auth_disabled,
    }))
}

async fn setup(
    State(state): State<AppState>,
    Json(req): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, AppError> {
    // Only allow registration when no users exist
    let user_count = cloudbox_db::users::count(&state.db).await?;
    if user_count > 0 {
        return Err(AppError::BadRequest("setup already completed".into()));
    }

    cloudbox_db::users::create(&state.db, &req.username, &req.password)
        .await
        .map_err(|e| AppError::BadRequest(e.to_string()))?;

    let token = auth::create_token(&state.jwt_secret, &req.username)?;
    Ok(Json(LoginResponse { token }))
}

async fn login(
    State(state): State<AppState>,
    Json(req): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, AppError> {
    let _user = cloudbox_db::users::verify(&state.db, &req.username, &req.password)
        .await?
        .ok_or(AppError::Unauthorized)?;

    let token = auth::create_token(&state.jwt_secret, &req.username)?;
    Ok(Json(LoginResponse { token }))
}
