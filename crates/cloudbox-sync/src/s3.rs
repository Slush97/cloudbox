use crate::{Storage, StorageError};

pub struct S3Storage {
    client: aws_sdk_s3::Client,
    bucket: String,
}

impl S3Storage {
    pub async fn new(endpoint: &str, bucket: &str) -> Result<Self, StorageError> {
        let config = aws_config::from_env()
            .endpoint_url(endpoint)
            .load()
            .await;

        let client = aws_sdk_s3::Client::new(&config);

        Ok(Self {
            client,
            bucket: bucket.to_string(),
        })
    }
}

#[async_trait::async_trait]
impl Storage for S3Storage {
    async fn put(&self, key: &str, data: &[u8]) -> Result<(), StorageError> {
        self.client
            .put_object()
            .bucket(&self.bucket)
            .key(key)
            .body(data.to_vec().into())
            .send()
            .await
            .map_err(|e| StorageError::S3(e.to_string()))?;
        Ok(())
    }

    async fn get(&self, key: &str) -> Result<Vec<u8>, StorageError> {
        let resp = self
            .client
            .get_object()
            .bucket(&self.bucket)
            .key(key)
            .send()
            .await
            .map_err(|e| StorageError::S3(e.to_string()))?;

        let data = resp
            .body
            .collect()
            .await
            .map_err(|e| StorageError::S3(e.to_string()))?;

        Ok(data.to_vec())
    }

    async fn delete(&self, key: &str) -> Result<(), StorageError> {
        self.client
            .delete_object()
            .bucket(&self.bucket)
            .key(key)
            .send()
            .await
            .map_err(|e| StorageError::S3(e.to_string()))?;
        Ok(())
    }

    async fn exists(&self, key: &str) -> Result<bool, StorageError> {
        match self
            .client
            .head_object()
            .bucket(&self.bucket)
            .key(key)
            .send()
            .await
        {
            Ok(_) => Ok(true),
            Err(_) => Ok(false),
        }
    }
}
