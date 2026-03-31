use axum::{
    extract::{Path, Query, State},
    routing::{delete, get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{auth::Claims, error::AppError, state::AppState};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", get(list_trash))
        .route("/empty", delete(empty_trash))
        .route("/photo/{id}/restore", post(restore_photo))
        .route("/photo/{id}", delete(permanent_delete_photo))
        .route("/file/{id}/restore", post(restore_file))
        .route("/file/{id}", delete(permanent_delete_file))
}

#[derive(Serialize)]
struct TrashResponse {
    photos: Vec<silo_db::photos::Photo>,
    files: Vec<silo_db::files::File>,
}

#[derive(Deserialize)]
struct TrashParams {
    cursor: Option<Uuid>,
    limit: Option<i64>,
}

async fn list_trash(
    _claims: Claims,
    State(state): State<AppState>,
    Query(params): Query<TrashParams>,
) -> Result<Json<TrashResponse>, AppError> {
    let limit = params.limit.unwrap_or(50).min(500);
    let photos = silo_db::photos::list_trash(&state.db, params.cursor, limit).await?;
    let files = silo_db::files::list_trash(&state.db).await?;
    Ok(Json(TrashResponse { photos, files }))
}

async fn restore_photo(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<silo_db::photos::Photo>, AppError> {
    let photo = silo_db::photos::restore(&state.db, id).await?;
    Ok(Json(photo))
}

async fn restore_file(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<silo_db::files::File>, AppError> {
    let file = silo_db::files::restore(&state.db, id).await?;
    Ok(Json(file))
}

async fn permanent_delete_photo(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<(), AppError> {
    let photo = silo_db::photos::get(&state.db, id)
        .await?
        .ok_or(AppError::NotFound)?;

    // Remove original file
    let orig_path = std::path::Path::new(&state.storage_path).join(&photo.storage_key);
    tokio::fs::remove_file(&orig_path).await.ok();

    // Remove thumbnails
    for size in ["sm", "md", "lg"] {
        let thumb = format!("{}/thumbs/{id}_{size}.webp", state.storage_path);
        tokio::fs::remove_file(&thumb).await.ok();
    }

    silo_db::photos::permanent_delete(&state.db, id).await?;
    Ok(())
}

async fn permanent_delete_file(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<(), AppError> {
    let keys = silo_db::files::descendant_storage_keys(&state.db, id).await?;
    silo_db::files::delete(&state.db, id).await?;

    for key in keys {
        let path = std::path::Path::new(&state.storage_path).join(&key);
        tokio::fs::remove_file(path).await.ok();
    }

    Ok(())
}

async fn empty_trash(
    _claims: Claims,
    State(state): State<AppState>,
) -> Result<(), AppError> {
    cleanup_expired_trash(&state, 0).await;
    Ok(())
}

/// Delete items that have been in trash for longer than `days` days.
/// Called with days=0 for "empty trash" and days=30 for scheduled cleanup.
pub async fn cleanup_expired_trash(state: &AppState, days: i64) {
    // Clean up photos
    match silo_db::photos::expired_trash(&state.db, days).await {
        Ok(photos) => {
            for photo in photos {
                let orig = std::path::Path::new(&state.storage_path).join(&photo.storage_key);
                tokio::fs::remove_file(&orig).await.ok();
                for size in ["sm", "md", "lg"] {
                    let thumb = format!("{}/thumbs/{}_{size}.webp", state.storage_path, photo.id);
                    tokio::fs::remove_file(&thumb).await.ok();
                }
                silo_db::photos::permanent_delete(&state.db, photo.id).await.ok();
            }
        }
        Err(e) => tracing::error!(error = %e, "trash cleanup: failed to query expired photos"),
    }

    // Clean up files
    match silo_db::files::expired_trash(&state.db, days).await {
        Ok(files) => {
            for file in files {
                let keys = silo_db::files::descendant_storage_keys(&state.db, file.id)
                    .await
                    .unwrap_or_default();
                for key in keys {
                    let path = std::path::Path::new(&state.storage_path).join(&key);
                    tokio::fs::remove_file(path).await.ok();
                }
                silo_db::files::delete(&state.db, file.id).await.ok();
            }
        }
        Err(e) => tracing::error!(error = %e, "trash cleanup: failed to query expired files"),
    }
}
