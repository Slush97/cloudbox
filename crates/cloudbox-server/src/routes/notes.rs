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
        .route("/", get(list_notes))
        .route("/", post(create_note))
        .route("/{id}", get(get_note))
        .route("/{id}", put(update_note))
        .route("/{id}", delete(delete_note))
        .route("/{id}/pin", put(toggle_pin))
        .route("/{id}/favorite", put(toggle_favorite))
        .route("/{id}/tags", get(list_tags))
        .route("/{id}/tags", post(add_tag))
        .route("/{id}/tags/{tag_id}", delete(remove_tag))
}

async fn resolve_user_id(state: &AppState, claims: &Claims) -> Result<Uuid, AppError> {
    let user = cloudbox_db::users::get_by_username(&state.db, &claims.sub)
        .await?
        .ok_or(AppError::Unauthorized)?;
    Ok(user.id)
}

#[derive(Deserialize)]
struct ListParams {
    cursor: Option<Uuid>,
    limit: Option<i64>,
    search: Option<String>,
}

async fn list_notes(
    claims: Claims,
    State(state): State<AppState>,
    Query(params): Query<ListParams>,
) -> Result<Json<Vec<cloudbox_db::notes::Note>>, AppError> {
    let user_id = resolve_user_id(&state, &claims).await?;
    let limit = params.limit.unwrap_or(50).min(200);
    let notes = cloudbox_db::notes::list(
        &state.db,
        user_id,
        params.cursor,
        limit,
        params.search.as_deref(),
    )
    .await?;
    Ok(Json(notes))
}

#[derive(Deserialize)]
struct CreateNoteReq {
    title: String,
    content: Option<String>,
}

async fn create_note(
    claims: Claims,
    State(state): State<AppState>,
    Json(req): Json<CreateNoteReq>,
) -> Result<Json<cloudbox_db::notes::Note>, AppError> {
    let user_id = resolve_user_id(&state, &claims).await?;
    let id = Uuid::now_v7();
    let note = cloudbox_db::notes::create(
        &state.db,
        id,
        user_id,
        &req.title,
        req.content.as_deref().unwrap_or(""),
    )
    .await?;
    Ok(Json(note))
}

async fn get_note(
    claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<cloudbox_db::notes::Note>, AppError> {
    let user_id = resolve_user_id(&state, &claims).await?;
    cloudbox_db::notes::get(&state.db, id, user_id)
        .await?
        .ok_or(AppError::NotFound)
        .map(Json)
}

#[derive(Deserialize)]
struct UpdateNoteReq {
    title: String,
    content: String,
}

async fn update_note(
    claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Json(req): Json<UpdateNoteReq>,
) -> Result<Json<cloudbox_db::notes::Note>, AppError> {
    let user_id = resolve_user_id(&state, &claims).await?;
    cloudbox_db::notes::update(&state.db, id, user_id, &req.title, &req.content)
        .await?
        .ok_or(AppError::NotFound)
        .map(Json)
}

async fn delete_note(
    claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<(), AppError> {
    let user_id = resolve_user_id(&state, &claims).await?;
    cloudbox_db::notes::soft_delete(&state.db, id, user_id).await?;
    Ok(())
}

async fn toggle_pin(
    claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<cloudbox_db::notes::Note>, AppError> {
    let user_id = resolve_user_id(&state, &claims).await?;
    cloudbox_db::notes::toggle_pin(&state.db, id, user_id)
        .await?
        .ok_or(AppError::NotFound)
        .map(Json)
}

async fn toggle_favorite(
    claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<cloudbox_db::notes::Note>, AppError> {
    let user_id = resolve_user_id(&state, &claims).await?;
    cloudbox_db::notes::toggle_favorite(&state.db, id, user_id)
        .await?
        .ok_or(AppError::NotFound)
        .map(Json)
}

async fn list_tags(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<Vec<cloudbox_db::notes::NoteTag>>, AppError> {
    let tags = cloudbox_db::notes::get_tags(&state.db, id).await?;
    Ok(Json(tags))
}

#[derive(Deserialize)]
struct AddTagReq {
    name: String,
}

async fn add_tag(
    _claims: Claims,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Json(req): Json<AddTagReq>,
) -> Result<(), AppError> {
    cloudbox_db::notes::add_tag(&state.db, id, &req.name).await?;
    Ok(())
}

async fn remove_tag(
    _claims: Claims,
    State(state): State<AppState>,
    Path((id, tag_id)): Path<(Uuid, i32)>,
) -> Result<(), AppError> {
    cloudbox_db::notes::remove_tag(&state.db, id, tag_id).await?;
    Ok(())
}
