use axum::{
    body::Body,
    extract::{Multipart, Path, Query, State},
    routing::{delete, get, post, put},
    Json, Router,
};
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
        .route("/{id}/rename", put(rename_file))
        .route("/{id}/move", put(move_file))
        .route("/{id}/ancestors", get(get_ancestors))
        .route("/{id}/share", post(create_share))
        .route("/{id}/shares", get(list_shares))
        .route("/{id}/share/{share_id}", delete(delete_share))
}

#[derive(Deserialize)]
struct ListParams {
    parent_id: Option<Uuid>,
}

async fn list_files(
    _claims: Claims,
    State(state): State<AppState>,
    Query(params): Query<ListParams>,
) -> Result<Json<Vec<cloudbox_db::files::File>>, AppError> {
    let files = cloudbox_db::files::list_children(&state.db, params.parent_id).await?;
    Ok(Json(files))
}

async fn upload(
    _claims: Claims,
    State(state): State<AppState>,
    mut multipart: Multipart,
) -> Result<Json<cloudbox_db::files::File>, AppError> {
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

    let id = Uuid::now_v7();
    let storage_key = format!("files/{id}/{filename}");
    let dest = std::path::Path::new(&state.storage_path).join(&storage_key);
    tokio::fs::create_dir_all(dest.parent().unwrap()).await?;
    tokio::fs::write(&dest, &data).await?;

    let mime_type = mime_guess::from_path(&filename)
        .first()
        .map(|m| m.to_string());

    let file = cloudbox_db::files::insert(
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
) -> Result<Json<cloudbox_db::files::File>, AppError> {
    let id = Uuid::now_v7();
    let folder =
        cloudbox_db::files::create_folder(&state.db, id, &req.name, req.parent_id).await?;
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
) -> Result<Json<Vec<cloudbox_db::files::File>>, AppError> {
    let files = cloudbox_db::files::search_by_name(
        &state.db,
        &params.q,
        params.limit.unwrap_or(50),
    )
    .await?;
    Ok(Json(files))
}

async fn download(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Body, AppError> {
    let file = cloudbox_db::files::get(&state.db, id)
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
) -> Result<Json<cloudbox_db::files::File>, AppError> {
    let file = cloudbox_db::files::rename(&state.db, id, &req.name).await?;
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
) -> Result<Json<cloudbox_db::files::File>, AppError> {
    let file = cloudbox_db::files::move_file(&state.db, id, req.parent_id).await?;
    Ok(Json(file))
}

async fn get_ancestors(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<Vec<cloudbox_db::files::File>>, AppError> {
    let ancestors = cloudbox_db::files::get_ancestors(&state.db, id).await?;
    Ok(Json(ancestors))
}

async fn delete_file(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<(), AppError> {
    // Collect all descendant storage keys before deletion
    let keys = cloudbox_db::files::descendant_storage_keys(&state.db, id).await?;

    // Delete from DB (cascades to children)
    cloudbox_db::files::delete(&state.db, id).await?;

    // Clean up physical files
    for key in keys {
        let path = std::path::Path::new(&state.storage_path).join(&key);
        tokio::fs::remove_file(path).await.ok();
    }

    Ok(())
}

// ---- Share links ----

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
) -> Result<Json<cloudbox_db::shares::ShareLink>, AppError> {
    let share_id = Uuid::now_v7();
    let token = share_id.to_string().replace('-', "")[..12].to_string();
    let expires_at = req.expires_hours.map(|h| {
        chrono::Utc::now() + chrono::Duration::hours(h)
    });

    let link = cloudbox_db::shares::create(
        &state.db, share_id, id, &token, expires_at,
    ).await?;

    Ok(Json(link))
}

async fn list_shares(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<Vec<cloudbox_db::shares::ShareLink>>, AppError> {
    let links = cloudbox_db::shares::list_for_file(&state.db, id).await?;
    Ok(Json(links))
}

async fn delete_share(
    _claims: Claims,
    State(state): State<AppState>,
    Path((_id, share_id)): Path<(Uuid, Uuid)>,
) -> Result<(), AppError> {
    cloudbox_db::shares::delete(&state.db, share_id).await?;
    Ok(())
}

/// Public (no auth) download via share token.
pub async fn download_shared(
    State(state): State<AppState>,
    Path(token): Path<String>,
) -> Result<Body, AppError> {
    let link = cloudbox_db::shares::get_by_token(&state.db, &token)
        .await?
        .ok_or(AppError::NotFound)?;

    let file = cloudbox_db::files::get(&state.db, link.file_id)
        .await?
        .ok_or(AppError::NotFound)?;

    let path = std::path::Path::new(&state.storage_path).join(&file.storage_key);
    let bytes = tokio::fs::read(path).await?;
    Ok(Body::from(bytes))
}
