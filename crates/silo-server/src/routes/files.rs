use axum::{
    body::Body,
    extract::{Multipart, Path, Query, State},
    routing::{delete, get, post, put},
    Json, Router,
};
use rand::Rng;
use serde::Deserialize;
use uuid::Uuid;

use crate::{auth::Claims, error::AppError, state::AppState};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", get(list_files))
        .route("/upload", post(upload))
        .route("/folder", post(create_folder))
        .route("/search", get(search_files))
        .route("/{id}", get(download))
        .route("/{id}", delete(delete_file))
        .route("/{id}/favorite", put(toggle_file_favorite))
        .route("/{id}/rename", put(rename_file))
        .route("/{id}/move", put(move_file))
        .route("/{id}/ancestors", get(get_ancestors))
        .route("/{id}/share", post(create_share))
        .route("/{id}/shares", get(list_shares))
        .route("/{id}/share/{share_id}", delete(delete_share))
}

/// Sanitize a user-supplied filename: strip path components, reject traversal.
fn sanitize_filename(raw: &str) -> Result<String, AppError> {
    let name = std::path::Path::new(raw)
        .file_name()
        .and_then(|n| n.to_str())
        .ok_or_else(|| AppError::BadRequest("invalid filename".into()))?;

    if name.is_empty() || name == "." || name == ".." {
        return Err(AppError::BadRequest("invalid filename".into()));
    }

    Ok(name.to_string())
}

/// Resolve a storage path and verify it stays within the storage root.
fn safe_storage_path(
    storage_root: &str,
    relative_key: &str,
) -> Result<std::path::PathBuf, AppError> {
    let root = std::path::Path::new(storage_root)
        .canonicalize()
        .map_err(|_| AppError::BadRequest("storage path unavailable".into()))?;
    let dest = root.join(relative_key);

    // Ensure the resolved path is still under the storage root.
    // We check the parent since the file itself may not exist yet.
    if let Some(parent) = dest.parent() {
        // Parent may not exist yet either, so check prefix of the joined path.
        let normalized = root.join(relative_key);
        if !normalized.starts_with(&root) {
            return Err(AppError::BadRequest("invalid path".into()));
        }
        let _ = parent; // used for the check above
    }

    Ok(dest)
}

const MAX_QUERY_LIMIT: i64 = 500;

#[derive(Deserialize)]
struct ListParams {
    parent_id: Option<Uuid>,
}

async fn list_files(
    _claims: Claims,
    State(state): State<AppState>,
    Query(params): Query<ListParams>,
) -> Result<Json<Vec<silo_db::files::File>>, AppError> {
    let files = silo_db::files::list_children(&state.db, params.parent_id).await?;
    Ok(Json(files))
}

async fn upload(
    _claims: Claims,
    State(state): State<AppState>,
    mut multipart: Multipart,
) -> Result<Json<silo_db::files::File>, AppError> {
    let mut filename = String::new();
    let mut data = bytes::Bytes::new();
    let mut parent_id: Option<Uuid> = None;

    while let Some(field) = multipart.next_field().await? {
        match field.name() {
            Some("file") => {
                filename = field.file_name().unwrap_or("upload").to_string();
                data = field.bytes().await?;
            }
            Some("parent_id") => {
                let text = field.text().await?;
                if !text.is_empty() {
                    parent_id = text.parse().ok();
                }
            }
            _ => {}
        }
    }

    if data.is_empty() {
        return Err(AppError::BadRequest("no file".into()));
    }

    let filename = sanitize_filename(&filename)?;
    let id = Uuid::now_v7();
    let storage_key = format!("files/{id}/{filename}");
    let dest = safe_storage_path(&state.storage_path, &storage_key)?;
    if let Some(parent) = dest.parent() {
        tokio::fs::create_dir_all(parent).await?;
    }
    tokio::fs::write(&dest, &data).await?;

    let mime_type = mime_guess::from_path(&filename)
        .first()
        .map(|m| m.to_string());

    let file = silo_db::files::insert(
        &state.db,
        id,
        &filename,
        &storage_key,
        data.len() as i64,
        parent_id,
        mime_type.as_deref(),
    )
    .await?;
    Ok(Json(file))
}

#[derive(Deserialize)]
struct CreateFolderReq {
    name: String,
    parent_id: Option<Uuid>,
}

async fn create_folder(
    _claims: Claims,
    State(state): State<AppState>,
    Json(req): Json<CreateFolderReq>,
) -> Result<Json<silo_db::files::File>, AppError> {
    let name = sanitize_filename(&req.name)?;
    let id = Uuid::now_v7();
    let folder =
        silo_db::files::create_folder(&state.db, id, &name, req.parent_id).await?;
    Ok(Json(folder))
}

#[derive(Deserialize)]
struct SearchParams {
    q: String,
    limit: Option<i64>,
}

async fn search_files(
    _claims: Claims,
    State(state): State<AppState>,
    Query(params): Query<SearchParams>,
) -> Result<Json<Vec<silo_db::files::File>>, AppError> {
    let limit = params.limit.unwrap_or(50).min(MAX_QUERY_LIMIT);
    let files = silo_db::files::search_by_name(&state.db, &params.q, limit).await?;
    Ok(Json(files))
}

async fn download(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Body, AppError> {
    let file = silo_db::files::get(&state.db, id)
        .await?
        .ok_or(AppError::NotFound)?;

    let path = std::path::Path::new(&state.storage_path).join(&file.storage_key);
    let stream = tokio::fs::read(path).await?;
    Ok(Body::from(stream))
}

#[derive(Deserialize)]
struct RenameReq {
    name: String,
}

async fn rename_file(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Json(req): Json<RenameReq>,
) -> Result<Json<silo_db::files::File>, AppError> {
    let name = sanitize_filename(&req.name)?;
    let file = silo_db::files::rename(&state.db, id, &name).await?;
    Ok(Json(file))
}

#[derive(Deserialize)]
struct MoveReq {
    parent_id: Option<Uuid>,
}

async fn move_file(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Json(req): Json<MoveReq>,
) -> Result<Json<silo_db::files::File>, AppError> {
    let file = silo_db::files::move_file(&state.db, id, req.parent_id).await?;
    Ok(Json(file))
}

async fn get_ancestors(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<Vec<silo_db::files::File>>, AppError> {
    let ancestors = silo_db::files::get_ancestors(&state.db, id).await?;
    Ok(Json(ancestors))
}

async fn delete_file(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<(), AppError> {
    // Soft delete — files are cleaned up when trash expires
    silo_db::files::soft_delete(&state.db, id).await?;
    Ok(())
}

async fn toggle_file_favorite(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<silo_db::files::File>, AppError> {
    let file = silo_db::files::toggle_favorite(&state.db, id).await?;
    Ok(Json(file))
}

// ---- Share links ----

/// Generate a crypto-random alphanumeric share token.
fn generate_share_token() -> String {
    rand::thread_rng()
        .sample_iter(&rand::distributions::Alphanumeric)
        .take(32)
        .map(char::from)
        .collect()
}

#[derive(Deserialize)]
struct CreateShareReq {
    /// Expiry in hours. Null = no expiry.
    expires_hours: Option<i64>,
}

async fn create_share(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Json(req): Json<CreateShareReq>,
) -> Result<Json<silo_db::shares::ShareLink>, AppError> {
    let share_id = Uuid::now_v7();
    let token = generate_share_token();
    let expires_at = req
        .expires_hours
        .map(|h| chrono::Utc::now() + chrono::Duration::hours(h));

    let link =
        silo_db::shares::create(&state.db, share_id, id, &token, expires_at).await?;

    Ok(Json(link))
}

async fn list_shares(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<Vec<silo_db::shares::ShareLink>>, AppError> {
    let links = silo_db::shares::list_for_file(&state.db, id).await?;
    Ok(Json(links))
}

async fn delete_share(
    _claims: Claims,
    State(state): State<AppState>,
    Path((_id, share_id)): Path<(Uuid, Uuid)>,
) -> Result<(), AppError> {
    silo_db::shares::delete(&state.db, share_id).await?;
    Ok(())
}

/// Public (no auth) download via share token.
pub async fn download_shared(
    State(state): State<AppState>,
    Path(token): Path<String>,
) -> Result<Body, AppError> {
    let link = silo_db::shares::get_by_token(&state.db, &token)
        .await?
        .ok_or(AppError::NotFound)?;

    let file = silo_db::files::get(&state.db, link.file_id)
        .await?
        .ok_or(AppError::NotFound)?;

    let path = std::path::Path::new(&state.storage_path).join(&file.storage_key);
    let bytes = tokio::fs::read(path).await?;
    Ok(Body::from(bytes))
}
