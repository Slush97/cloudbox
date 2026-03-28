use axum::{
    extract::{Path, Query, State},
    routing::{delete, get, post, put},
    Json, Router,
};
use serde::Deserialize;
use uuid::Uuid;

use crate::{auth::Claims, error::AppError, state::AppState};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", get(list_albums))
        .route("/", post(create_album))
        .route("/{id}", get(get_album))
        .route("/{id}", put(update_album))
        .route("/{id}", delete(delete_album))
        .route("/{id}/photos", get(list_album_photos))
        .route("/{id}/photos", post(add_photos))
        .route("/{id}/photos/{photo_id}", delete(remove_photo))
        .route("/{id}/cover", put(set_cover))
}

async fn list_albums(
    _claims: Claims,
    State(state): State<AppState>,
) -> Result<Json<Vec<cloudbox_db::albums::AlbumWithCount>>, AppError> {
    let albums = cloudbox_db::albums::list(&state.db).await?;
    Ok(Json(albums))
}

#[derive(Deserialize)]
struct CreateAlbumReq {
    name: String,
}

async fn create_album(
    _claims: Claims,
    State(state): State<AppState>,
    Json(req): Json<CreateAlbumReq>,
) -> Result<Json<cloudbox_db::albums::Album>, AppError> {
    let id = Uuid::now_v7();
    let album = cloudbox_db::albums::create(&state.db, id, &req.name).await?;
    Ok(Json(album))
}

async fn get_album(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<cloudbox_db::albums::Album>, AppError> {
    cloudbox_db::albums::get(&state.db, id)
        .await?
        .ok_or(AppError::NotFound)
        .map(Json)
}

#[derive(Deserialize)]
struct UpdateAlbumReq {
    name: String,
}

async fn update_album(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Json(req): Json<UpdateAlbumReq>,
) -> Result<Json<cloudbox_db::albums::Album>, AppError> {
    let album = cloudbox_db::albums::update(&state.db, id, &req.name).await?;
    Ok(Json(album))
}

async fn delete_album(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<(), AppError> {
    cloudbox_db::albums::delete(&state.db, id).await?;
    Ok(())
}

#[derive(Deserialize)]
struct AlbumPhotosParams {
    cursor: Option<Uuid>,
    limit: Option<i64>,
}

async fn list_album_photos(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Query(params): Query<AlbumPhotosParams>,
) -> Result<Json<Vec<cloudbox_db::photos::Photo>>, AppError> {
    let limit = params.limit.unwrap_or(50).min(500);
    let photos = cloudbox_db::albums::list_photos(&state.db, id, params.cursor, limit).await?;
    Ok(Json(photos))
}

#[derive(Deserialize)]
struct AddPhotosReq {
    photo_ids: Vec<Uuid>,
}

async fn add_photos(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Json(req): Json<AddPhotosReq>,
) -> Result<Json<u64>, AppError> {
    if req.photo_ids.len() > 500 {
        return Err(AppError::BadRequest("max 500 photos per request".into()));
    }
    let added = cloudbox_db::albums::add_photos(&state.db, id, &req.photo_ids).await?;
    Ok(Json(added))
}

async fn remove_photo(
    _claims: Claims,
    State(state): State<AppState>,
    Path((id, photo_id)): Path<(Uuid, Uuid)>,
) -> Result<(), AppError> {
    cloudbox_db::albums::remove_photo(&state.db, id, photo_id).await?;
    Ok(())
}

#[derive(Deserialize)]
struct SetCoverReq {
    photo_id: Uuid,
}

async fn set_cover(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Json(req): Json<SetCoverReq>,
) -> Result<Json<cloudbox_db::albums::Album>, AppError> {
    let album = cloudbox_db::albums::set_cover(&state.db, id, req.photo_id).await?;
    Ok(Json(album))
}
