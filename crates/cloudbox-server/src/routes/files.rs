use axum::{
    body::Body,
    extract::{Multipart, Path, State},
    routing::{delete, get, post},
    Json, Router,
};
use uuid::Uuid;

use crate::{auth::Claims, error::AppError, state::AppState};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", get(list_files))
        .route("/upload", post(upload))
        .route("/{id}", get(download))
        .route("/{id}", delete(delete_file))
}

async fn list_files(
    _claims: Claims,
    State(state): State<AppState>,
) -> Result<Json<Vec<cloudbox_db::files::File>>, AppError> {
    let files = cloudbox_db::files::list(&state.db).await?;
    Ok(Json(files))
}

async fn upload(
    _claims: Claims,
    State(state): State<AppState>,
    mut multipart: Multipart,
) -> Result<Json<cloudbox_db::files::File>, AppError> {
    let field = multipart
        .next_field()
        .await?
        .ok_or_else(|| AppError::BadRequest("no file".into()))?;

    let filename = field.file_name().unwrap_or("upload").to_string();
    let data = field.bytes().await?;

    let id = Uuid::now_v7();
    let storage_key = format!("files/{id}/{filename}");
    let dest = std::path::Path::new(&state.storage_path).join(&storage_key);
    tokio::fs::create_dir_all(dest.parent().unwrap()).await?;
    tokio::fs::write(&dest, &data).await?;

    let file = cloudbox_db::files::insert(&state.db, id, &filename, &storage_key, data.len() as i64).await?;
    Ok(Json(file))
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

async fn delete_file(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<(), AppError> {
    let file = cloudbox_db::files::get(&state.db, id)
        .await?
        .ok_or(AppError::NotFound)?;

    let path = std::path::Path::new(&state.storage_path).join(&file.storage_key);
    tokio::fs::remove_file(path).await.ok();
    cloudbox_db::files::delete(&state.db, id).await?;
    Ok(())
}
