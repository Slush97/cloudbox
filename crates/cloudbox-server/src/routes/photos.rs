use axum::{
    extract::{Multipart, Path, Query, State},
    http::{header, HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    routing::{delete, get, post, put},
    Json, Router,
};
use serde::Deserialize;
use tokio::io::AsyncReadExt;
use uuid::Uuid;

use crate::{auth::Claims, error::AppError, state::AppState};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", get(list_photos))
        .route("/upload", post(upload))
        .route("/{id}", get(get_photo))
        .route("/{id}/thumb/{size}", get(get_thumbnail))
        .route("/{id}", delete(delete_photo))
        .route("/{id}/stream", get(stream_video))
        .route("/search", get(search))
        .route("/{id}/tags", get(list_tags))
        .route("/{id}/tags", post(add_tag))
        .route("/{id}/tags/{tag_id}", delete(remove_tag))
        .route("/faces", get(list_face_clusters))
        .route("/faces/recluster", post(recluster_faces))
        .route("/faces/{cluster_id}/photos", get(cluster_photos))
        .route("/faces/{cluster_id}/label", put(set_cluster_label))
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
    let limit = params.limit.unwrap_or(50).min(500);
    let photos = cloudbox_db::photos::list(&state.db, params.cursor, limit).await?;
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

    let raw_name = field.file_name().unwrap_or("upload").to_string();
    let filename = std::path::Path::new(&raw_name)
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("upload")
        .to_string();
    let data = field.bytes().await?;
    let file_size = data.len() as i64;
    let is_video = cloudbox_media::is_video(&filename);

    // 1. Write original to storage
    let id = Uuid::now_v7();
    let ext = std::path::Path::new(&filename)
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or(if is_video { "mp4" } else { "jpg" });
    let storage_key = format!("originals/{id}.{ext}");
    let dest = std::path::Path::new(&state.storage_path).join(&storage_key);
    if let Some(parent) = dest.parent() {
        tokio::fs::create_dir_all(parent).await?;
    }
    tokio::fs::write(&dest, &data).await?;

    if is_video {
        // ---- Video upload flow ----

        // 2v. Extract video metadata via ffprobe
        let video_meta = cloudbox_media::video::extract_metadata(&dest).await?;

        // 3v. Generate thumbnails from extracted frame
        let duration = video_meta.duration_secs.unwrap_or(1.0);
        cloudbox_media::video::generate_thumbs(&dest, &state.storage_path, &id, duration).await?;

        // 4v. Build PhotoMeta from video metadata
        let meta = cloudbox_media::PhotoMeta {
            taken_at: video_meta.taken_at,
            width: video_meta.width,
            height: video_meta.height,
            ..Default::default()
        };

        // 5v. Insert as video
        let photo = cloudbox_db::photos::insert(
            &state.db, id, &filename, &storage_key, None, Some(meta), file_size,
            "video", video_meta.duration_secs, video_meta.codec.as_deref(),
        ).await?;

        // 6v. Queue vision on extracted frame for auto-tagging + CLIP
        let frame_data = cloudbox_media::video::extract_frame(&dest, duration * 0.1).await;
        if let Ok(frame_bytes) = frame_data {
            let frame_path = dest.with_extension("_frame.jpg");
            tokio::fs::write(&frame_path, &frame_bytes).await?;
            cloudbox_vision::queue_photo(
                id, frame_path,
                state.face_pipeline.clone(), state.classifier.clone(), state.db.clone(),
            );
        }

        Ok(Json(photo))
    } else {
        // ---- Photo upload flow ----

        // 2p. Compute perceptual hash and check for duplicates
        let phash = cloudbox_media::phash::dhash(&data).ok();
        if let Some(hash) = phash {
            if let Some(existing) = cloudbox_db::photos::find_duplicate(
                &state.db, hash, cloudbox_media::phash::DUPLICATE_THRESHOLD,
            ).await? {
                // Clean up the file we just wrote
                tokio::fs::remove_file(&dest).await.ok();
                return Err(AppError::BadRequest(format!(
                    "duplicate of existing photo {} ({})",
                    existing.id, existing.filename,
                )));
            }
        }

        // 3p. Extract EXIF metadata
        let meta = cloudbox_media::exif::extract(&data);

        // 4p. Generate thumbnails
        cloudbox_media::thumbs::generate(&data, &state.storage_path, &id).await?;

        // 5p. Insert as photo
        let photo = cloudbox_db::photos::insert(
            &state.db, id, &filename, &storage_key, phash, meta, file_size,
            "photo", None, None,
        ).await?;

        // 6p. Queue vision processing
        cloudbox_vision::queue_photo(
            id, dest,
            state.face_pipeline.clone(), state.classifier.clone(), state.db.clone(),
        );

        Ok(Json(photo))
    }
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

async fn stream_video(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Response, AppError> {
    let photo = cloudbox_db::photos::get(&state.db, id)
        .await?
        .ok_or(AppError::NotFound)?;

    let file_path = std::path::Path::new(&state.storage_path).join(&photo.storage_key);
    let file_len = tokio::fs::metadata(&file_path)
        .await
        .map_err(|_| AppError::NotFound)?
        .len();

    let content_type = match file_path.extension().and_then(|e| e.to_str()) {
        Some("mp4" | "m4v") => "video/mp4",
        Some("mov") => "video/quicktime",
        Some("webm") => "video/webm",
        Some("mkv") => "video/x-matroska",
        Some("avi") => "video/x-msvideo",
        _ => "application/octet-stream",
    };

    // Parse Range header
    if let Some(range_header) = headers.get(header::RANGE) {
        let range_str = range_header.to_str().unwrap_or("");
        if let Some(range) = parse_range(range_str, file_len) {
            let (start, end) = range;
            let length = end - start + 1;

            let mut file = tokio::fs::File::open(&file_path).await.map_err(|_| AppError::NotFound)?;
            tokio::io::AsyncSeekExt::seek(&mut file, std::io::SeekFrom::Start(start)).await?;
            let mut buf = vec![0u8; length as usize];
            file.read_exact(&mut buf).await?;

            return Ok((
                StatusCode::PARTIAL_CONTENT,
                [
                    (header::CONTENT_TYPE, content_type.to_string()),
                    (header::CONTENT_LENGTH, length.to_string()),
                    (header::CONTENT_RANGE, format!("bytes {start}-{end}/{file_len}")),
                    (header::ACCEPT_RANGES, "bytes".to_string()),
                ],
                buf,
            ).into_response());
        }
    }

    // No Range header — serve full file
    let bytes = tokio::fs::read(&file_path).await.map_err(|_| AppError::NotFound)?;
    Ok((
        StatusCode::OK,
        [
            (header::CONTENT_TYPE, content_type.to_string()),
            (header::CONTENT_LENGTH, file_len.to_string()),
            (header::ACCEPT_RANGES, "bytes".to_string()),
        ],
        bytes,
    ).into_response())
}

/// Parse "bytes=START-END" or "bytes=START-" from a Range header.
fn parse_range(range: &str, file_len: u64) -> Option<(u64, u64)> {
    let range = range.strip_prefix("bytes=")?;
    let mut parts = range.split('-');
    let start: u64 = parts.next()?.parse().ok()?;
    let end: u64 = parts
        .next()
        .and_then(|s| if s.is_empty() { None } else { s.parse().ok() })
        .unwrap_or(file_len - 1)
        .min(file_len - 1);
    if start > end || start >= file_len {
        return None;
    }
    Some((start, end))
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
    let limit = params.limit.unwrap_or(20).min(500);
    let photos = cloudbox_db::photos::search_by_embedding(&state.db, &embedding, limit).await?;
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

// ---- Tags ----

async fn list_tags(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<Vec<cloudbox_db::tags::PhotoTag>>, AppError> {
    let tags = cloudbox_db::tags::get_tags_for_photo(&state.db, id).await?;
    Ok(Json(tags))
}

#[derive(Deserialize)]
struct AddTagRequest {
    name: String,
}

async fn add_tag(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Json(req): Json<AddTagRequest>,
) -> Result<(), AppError> {
    cloudbox_db::tags::add_tag(&state.db, id, &req.name, 1.0, "manual").await?;
    Ok(())
}

async fn remove_tag(
    _claims: Claims,
    State(state): State<AppState>,
    Path((id, tag_id)): Path<(Uuid, i32)>,
) -> Result<(), AppError> {
    cloudbox_db::tags::remove_tag(&state.db, id, tag_id).await?;
    Ok(())
}

// ---- Face clusters ----

async fn list_face_clusters(
    _claims: Claims,
    State(state): State<AppState>,
) -> Result<Json<Vec<cloudbox_db::faces::FaceCluster>>, AppError> {
    let clusters = cloudbox_db::faces::list_clusters(&state.db).await?;
    Ok(Json(clusters))
}

async fn cluster_photos(
    _claims: Claims,
    State(state): State<AppState>,
    Path(cluster_id): Path<i32>,
) -> Result<Json<Vec<cloudbox_db::photos::Photo>>, AppError> {
    let photos = cloudbox_db::faces::photos_by_cluster(&state.db, cluster_id).await?;
    Ok(Json(photos))
}

#[derive(Deserialize)]
struct LabelRequest {
    label: String,
}

async fn set_cluster_label(
    _claims: Claims,
    State(state): State<AppState>,
    Path(cluster_id): Path<i32>,
    Json(req): Json<LabelRequest>,
) -> Result<(), AppError> {
    cloudbox_db::faces::set_cluster_label(&state.db, cluster_id, &req.label).await?;
    Ok(())
}

async fn recluster_faces(
    _claims: Claims,
    State(state): State<AppState>,
) -> Result<Json<cloudbox_vision::faces::ReclusterResult>, AppError> {
    let result = cloudbox_vision::faces::recluster(&state.db).await?;
    tracing::info!(
        total = result.total_faces,
        clusters = result.clusters,
        noise = result.noise,
        "face re-clustering complete"
    );
    Ok(Json(result))
}
