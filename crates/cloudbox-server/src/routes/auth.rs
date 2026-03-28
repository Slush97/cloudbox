use std::sync::{LazyLock, Mutex};
use std::time::{Duration, Instant};

use axum::{
    extract::State,
    routing::{get, post},
    Json, Router,
};
use rand::Rng;
use serde::{Deserialize, Serialize};

use crate::{auth, auth::Claims, error::AppError, state::AppState};

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
        .route("/pair", post(generate_pair_code))
        .route("/pair/claim", post(claim_pair_code))
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

// ---- QR Pairing ----

#[derive(Serialize)]
struct PairResponse {
    code: String,
    expires_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Deserialize)]
struct ClaimRequest {
    code: String,
}

/// Generate a pairing code (authenticated). Returns a short-lived code for QR display.
async fn generate_pair_code(
    State(state): State<AppState>,
    claims: Claims,
) -> Result<Json<PairResponse>, AppError> {
    let user = cloudbox_db::users::get_by_username(&state.db, &claims.sub)
        .await?
        .ok_or(AppError::Unauthorized)?;

    let code: String = rand::thread_rng()
        .sample_iter(&rand::distributions::Alphanumeric)
        .take(32)
        .map(char::from)
        .collect();

    let expires_at = chrono::Utc::now() + chrono::Duration::minutes(5);

    cloudbox_db::pairing::create(&state.db, user.id, &code, expires_at).await?;

    tracing::info!(username = claims.sub, "pairing code generated");
    Ok(Json(PairResponse { code, expires_at }))
}

/// Claim a pairing code (unauthenticated). Returns a JWT if the code is valid.
async fn claim_pair_code(
    State(state): State<AppState>,
    Json(req): Json<ClaimRequest>,
) -> Result<Json<LoginResponse>, AppError> {
    check_login_rate_limit()?;

    let pairing = cloudbox_db::pairing::claim(&state.db, &req.code)
        .await?
        .ok_or(AppError::Unauthorized)?;

    let user = cloudbox_db::users::get_by_id(&state.db, pairing.user_id)
        .await?
        .ok_or(AppError::Unauthorized)?;

    tracing::info!(username = user.username, "pairing code claimed");
    let token = auth::create_token(&state.jwt_secret, &user.username)?;
    Ok(Json(LoginResponse { token }))
}
