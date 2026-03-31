use axum::{extract::State, routing::get, Json, Router};

use crate::{auth::Claims, error::AppError, state::AppState};

pub fn router() -> Router<AppState> {
    Router::new().route("/", get(get_stats))
}

async fn get_stats(
    _claims: Claims,
    State(state): State<AppState>,
) -> Result<Json<silo_db::stats::Stats>, AppError> {
    let stats = silo_db::stats::get(&state.db, &state.storage_path).await?;
    Ok(Json(stats))
}
