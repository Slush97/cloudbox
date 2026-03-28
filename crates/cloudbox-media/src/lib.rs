pub mod exif;
pub mod phash;
pub mod thumbs;
pub mod video;

#[derive(Debug, Default)]
pub struct PhotoMeta {
    pub taken_at: Option<chrono::DateTime<chrono::Utc>>,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
    pub camera_make: Option<String>,
    pub camera_model: Option<String>,
    pub width: Option<i32>,
    pub height: Option<i32>,
}

#[derive(Debug, Default)]
pub struct VideoMeta {
    pub duration_secs: Option<f32>,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub codec: Option<String>,
    pub taken_at: Option<chrono::DateTime<chrono::Utc>>,
}

/// Check if a filename looks like a video based on extension.
pub fn is_video(filename: &str) -> bool {
    let ext = filename.rsplit('.').next().unwrap_or("").to_lowercase();
    matches!(
        ext.as_str(),
        "mp4" | "mov" | "avi" | "mkv" | "webm" | "m4v" | "3gp"
    )
}

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("image processing failed: {0}")]
    Image(#[from] image::ImageError),

    #[error("io error: {0}")]
    Io(#[from] std::io::Error),

    #[error("video processing failed: {0}")]
    Video(String),
}
