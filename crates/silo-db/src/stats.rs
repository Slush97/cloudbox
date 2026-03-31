use sqlx::PgPool;

#[derive(Debug, serde::Serialize)]
pub struct Stats {
    pub photo_count: i64,
    pub file_count: i64,
    pub storage_bytes: i64,
}

pub async fn get(pool: &PgPool, storage_path: &str) -> Result<Stats, sqlx::Error> {
    let (photo_count,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM photos WHERE deleted_at IS NULL")
        .fetch_one(pool)
        .await?;

    let (file_count,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM files WHERE deleted_at IS NULL")
        .fetch_one(pool)
        .await?;

    let (file_bytes,): (Option<i64>,) =
        sqlx::query_as("SELECT SUM(size_bytes) FROM files WHERE deleted_at IS NULL")
            .fetch_one(pool)
            .await?;

    // Walk the storage directory for total disk usage
    let disk_bytes = dir_size(storage_path).unwrap_or(0);

    Ok(Stats {
        photo_count,
        file_count,
        storage_bytes: disk_bytes.max(file_bytes.unwrap_or(0)),
    })
}

fn dir_size(path: &str) -> std::io::Result<i64> {
    let mut total: u64 = 0;
    for entry in walkdir(std::path::Path::new(path))? {
        total += entry;
    }
    Ok(total as i64)
}

fn walkdir(path: &std::path::Path) -> std::io::Result<Vec<u64>> {
    let mut sizes = Vec::new();
    if path.is_dir() {
        for entry in std::fs::read_dir(path)? {
            let entry = entry?;
            let meta = entry.metadata()?;
            if meta.is_dir() {
                sizes.extend(walkdir(&entry.path())?);
            } else {
                sizes.push(meta.len());
            }
        }
    }
    Ok(sizes)
}
