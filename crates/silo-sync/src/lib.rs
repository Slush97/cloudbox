pub mod local;
pub mod s3;

/// Storage backend abstraction.
/// Starts with local filesystem, can swap to MinIO/S3 later.
#[async_trait::async_trait]
pub trait Storage: Send + Sync {
    async fn put(&self, key: &str, data: &[u8]) -> Result<(), StorageError>;
    async fn get(&self, key: &str) -> Result<Vec<u8>, StorageError>;
    async fn delete(&self, key: &str) -> Result<(), StorageError>;
    async fn exists(&self, key: &str) -> Result<bool, StorageError>;
}

#[derive(Debug, thiserror::Error)]
pub enum StorageError {
    #[error("not found: {0}")]
    NotFound(String),

    #[error("io: {0}")]
    Io(#[from] std::io::Error),

    #[error("s3: {0}")]
    S3(String),
}
