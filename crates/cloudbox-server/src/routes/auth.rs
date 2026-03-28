use std::sync::{LazyLock, Mutex};
use std::time::{Duration, Instant};

use axum::{
    extract::State,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};

use crate::{auth, error::AppError, state::AppState};

/// Sliding-window rate limiter: max 10 attempts per 60 seconds.
static LOGIN_ATTEMPTS: LazyLock<Mutex<Vec<Instant>>> = LazyLock::new(|| Mutex::new(Vec::new()));

const MAX_LOGIN_ATTEMPTS: usize = 10;
const LOGIN_WINDOW: Duration = Duration::from_secs(60);

fn check_login_rate_limit() -> Result<(), AppError> {
    let mut attempts = LOGIN_ATTEMPTS.lock().unwrap();
    let cutoff = Instant::now() - LOGIN_WINDOW;
    attempts.retain(|t| *t > cutoff);
    if attempts.len() >= MAX_LOGIN_ATTEMPTS {
        tracing::warn!("login rate limit exceeded");
        return Err(AppError::TooManyRequests);
    }
    attempts.push(Instant::now());
    Ok(())
}

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
}

async fn status(State(state): State<AppState>) -> Result<Json<AuthStatus>, AppError> {
    let user_count = cloudbox_db::users::count(&state.db).await?;
    Ok(Json(AuthStatus {
        needs_setup: user_count == 0,
    }))
}

async fn setup(
    State(state): State<AppState>,
    Json(req): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, AppError> {
    check_login_rate_limit()?;

    let user_count = cloudbox_db::users::count(&state.db).await?;
    if user_count > 0 {
        return Err(AppError::BadRequest("setup already completed".into()));
    }

    cloudbox_db::users::create(&state.db, &req.username, &req.password)
        .await
        .map_err(|e| AppError::BadRequest(e.to_string()))?;

    tracing::info!(username = req.username, "initial user created");

    let token = auth::create_token(&state.jwt_secret, &req.username)?;
    Ok(Json(LoginResponse { token }))
}

async fn login(
    State(state): State<AppState>,
    Json(req): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, AppError> {
    check_login_rate_limit()?;

    let user = cloudbox_db::users::verify(&state.db, &req.username, &req.password).await?;

    if user.is_none() {
        tracing::warn!(username = req.username, "failed login attempt");
        return Err(AppError::Unauthorized);
    }

    tracing::info!(username = req.username, "login successful");
    let token = auth::create_token(&state.jwt_secret, &req.username)?;
    Ok(Json(LoginResponse { token }))
}
