use axum::{
    extract::{Multipart, Path, Query, State},
    routing::{get, post},
    Json, Router,
};
use serde::Deserialize;
use uuid::Uuid;

use crate::{auth::Claims, error::AppError, state::AppState};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", get(list_photos))
        .route("/upload", post(upload))
        .route("/{id}", get(get_photo))
        .route("/{id}/thumb/{size}", get(get_thumbnail))
        .route("/search", get(search))
        .route("/faces", get(list_face_clusters))
}

#[derive(Deserialize)]
struct ListParams {
    cursor: Option<Uuid>,
    limit: Option<i64>,
}

async fn list_photos(
    _claims: Claims,
    State(state): State<AppState>,
    Query(params): Query<ListParams>,
) -> Result<Json<Vec<cloudbox_db::photos::Photo>>, AppError> {
    let photos = cloudbox_db::photos::list(&state.db, params.cursor, params.limit.unwrap_or(50)).await?;
    Ok(Json(photos))
}

async fn upload(
    _claims: Claims,
    State(state): State<AppState>,
    mut multipart: Multipart,
) -> Result<Json<cloudbox_db::photos::Photo>, AppError> {
    let field = multipart
        .next_field()
        .await?
        .ok_or_else(|| AppError::BadRequest("no file".into()))?;

    let filename = field.file_name().unwrap_or("upload").to_string();
    let data = field.bytes().await?;

    // 1. Write original to storage
    let id = Uuid::now_v7();
    let ext = std::path::Path::new(&filename)
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("jpg");
    let storage_key = format!("originals/{id}.{ext}");
    let dest = std::path::Path::new(&state.storage_path).join(&storage_key);
    tokio::fs::create_dir_all(dest.parent().unwrap()).await?;
    tokio::fs::write(&dest, &data).await?;

    // 2. Extract EXIF metadata
    let meta = cloudbox_media::exif::extract(&data);

    // 3. Generate thumbnails
    cloudbox_media::thumbs::generate(&data, &state.storage_path, &id).await?;

    // 4. Insert into db
    let photo = cloudbox_db::photos::insert(&state.db, id, &filename, &storage_key, meta).await?;

    // 5. Queue vision processing (CLIP embedding, face detection) — async background
    cloudbox_vision::queue_photo(id, dest);

    Ok(Json(photo))
}

async fn get_photo(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<cloudbox_db::photos::Photo>, AppError> {
    cloudbox_db::photos::get(&state.db, id)
        .await?
        .ok_or(AppError::NotFound)
        .map(Json)
}

async fn get_thumbnail(
    _claims: Claims,
    State(state): State<AppState>,
    Path((id, size)): Path<(Uuid, String)>,
) -> Result<Vec<u8>, AppError> {
    let path = format!("{}/thumbs/{id}_{size}.webp", state.storage_path);
    tokio::fs::read(&path).await.map_err(|_| AppError::NotFound)
}

#[derive(Deserialize)]
struct SearchParams {
    q: String,
    limit: Option<i64>,
}

async fn search(
    _claims: Claims,
    State(state): State<AppState>,
    Query(params): Query<SearchParams>,
) -> Result<Json<Vec<cloudbox_db::photos::Photo>>, AppError> {
    // Encode query text with CLIP text encoder, then cosine similarity search via pgvector
    let embedding = cloudbox_vision::clip::encode_text(&params.q)?;
    let photos = cloudbox_db::photos::search_by_embedding(&state.db, &embedding, params.limit.unwrap_or(20)).await?;
    Ok(Json(photos))
}

async fn list_face_clusters(
    _claims: Claims,
    State(state): State<AppState>,
) -> Result<Json<Vec<cloudbox_db::faces::FaceCluster>>, AppError> {
    let clusters = cloudbox_db::faces::list_clusters(&state.db).await?;
    Ok(Json(clusters))
}
