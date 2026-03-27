use std::path::{Path, PathBuf};

use crate::{Storage, StorageError};

pub struct LocalStorage {
    root: PathBuf,
}

impl LocalStorage {
    pub fn new(root: impl AsRef<Path>) -> Self {
        Self {
            root: root.as_ref().to_path_buf(),
        }
    }
}

#[async_trait::async_trait]
impl Storage for LocalStorage {
    async fn put(&self, key: &str, data: &[u8]) -> Result<(), StorageError> {
        let path = self.root.join(key);
        if let Some(parent) = path.parent() {
            tokio::fs::create_dir_all(parent).await?;
        }
        tokio::fs::write(path, data).await?;
        Ok(())
    }

    async fn get(&self, key: &str) -> Result<Vec<u8>, StorageError> {
        let path = self.root.join(key);
        tokio::fs::read(&path)
            .await
            .map_err(|_| StorageError::NotFound(key.to_string()))
    }

    async fn delete(&self, key: &str) -> Result<(), StorageError> {
        let path = self.root.join(key);
        tokio::fs::remove_file(path).await?;
        Ok(())
    }

    async fn exists(&self, key: &str) -> Result<bool, StorageError> {
        let path = self.root.join(key);
        Ok(path.exists())
    }
}
