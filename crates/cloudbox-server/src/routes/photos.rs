use axum::{
    extract::{Multipart, Path, Query, State},
    routing::{delete, get, post},
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
        .route("/{id}", delete(delete_photo))
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

#[axum::debug_handler]
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

    // 1. Compute perceptual hash and check for duplicates
    let phash = cloudbox_media::phash::dhash(&data).ok();
    if let Some(hash) = phash {
        if let Some(existing) = cloudbox_db::photos::find_duplicate(
            &state.db,
            hash,
            cloudbox_media::phash::DUPLICATE_THRESHOLD,
        )
        .await?
        {
            return Err(AppError::BadRequest(format!(
                "duplicate of existing photo {} ({})",
                existing.id, existing.filename,
            )));
        }
    }

    // 2. Write original to storage
    let id = Uuid::now_v7();
    let ext = std::path::Path::new(&filename)
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("jpg");
    let storage_key = format!("originals/{id}.{ext}");
    let dest = std::path::Path::new(&state.storage_path).join(&storage_key);
    tokio::fs::create_dir_all(dest.parent().unwrap()).await?;
    tokio::fs::write(&dest, &data).await?;

    // 3. Extract EXIF metadata
    let meta = cloudbox_media::exif::extract(&data);

    // 4. Generate thumbnails
    cloudbox_media::thumbs::generate(&data, &state.storage_path, &id).await?;

    // 5. Insert into db
    let photo = cloudbox_db::photos::insert(&state.db, id, &filename, &storage_key, phash, meta).await?;

    // 6. Queue vision processing (CLIP embedding, face detection) — async background
    cloudbox_vision::queue_photo(id, dest, None);

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
) -> Result<([(axum::http::header::HeaderName, &'static str); 1], Vec<u8>), AppError> {
    if !matches!(size.as_str(), "sm" | "md" | "lg") {
        return Err(AppError::BadRequest("invalid size; must be sm, md, or lg".into()));
    }
    let path = format!("{}/thumbs/{id}_{size}.webp", state.storage_path);
    let bytes = tokio::fs::read(&path).await.map_err(|_| AppError::NotFound)?;
    Ok(([(axum::http::header::CONTENT_TYPE, "image/webp")], bytes))
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

async fn delete_photo(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<(), AppError> {
    let photo = cloudbox_db::photos::get(&state.db, id)
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

    // Delete DB row (cascades to photo_embeddings and faces)
    cloudbox_db::photos::delete(&state.db, id).await?;
    Ok(())
}

async fn list_face_clusters(
    _claims: Claims,
    State(state): State<AppState>,
) -> Result<Json<Vec<cloudbox_db::faces::FaceCluster>>, AppError> {
    let clusters = cloudbox_db::faces::list_clusters(&state.db).await?;
    Ok(Json(clusters))
}
