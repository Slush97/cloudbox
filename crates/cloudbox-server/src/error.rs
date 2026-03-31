use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
};

pub type Result<T> = std::result::Result<T, AppError>;

#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("not found")]
    NotFound,

    #[error("unauthorized")]
    Unauthorized,

    #[error("bad request: {0}")]
    BadRequest(String),

    #[error("too many requests")]
    TooManyRequests,

    #[error(transparent)]
    Db(#[from] sqlx::Error),

    #[error(transparent)]
    Io(#[from] std::io::Error),

    #[error(transparent)]
    Media(#[from] cloudbox_media::Error),

    #[error("multipart error: {0}")]
    Multipart(#[from] axum::extract::multipart::MultipartError),

    #[error(transparent)]
    Other(#[from] anyhow::Error),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match &self {
            Self::NotFound => (StatusCode::NOT_FOUND, "not found"),
            Self::Unauthorized => (StatusCode::UNAUTHORIZED, "unauthorized"),
            Self::BadRequest(msg) => return (StatusCode::BAD_REQUEST, msg.clone()).into_response(),
            Self::TooManyRequests => (StatusCode::TOO_MANY_REQUESTS, "too many requests"),
            other => {
                tracing::error!(error = %other, "internal server error");
                (StatusCode::INTERNAL_SERVER_ERROR, "internal server error")
            }
        };
        (status, message).into_response()
    }
}
