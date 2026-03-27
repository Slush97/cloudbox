pub mod exif;
pub mod thumbs;

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

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("image processing failed: {0}")]
    Image(#[from] image::ImageError),

    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
}
