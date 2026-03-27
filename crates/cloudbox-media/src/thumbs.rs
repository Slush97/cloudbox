use image::GenericImageView;
use uuid::Uuid;

const SIZES: &[(u32, &str)] = &[
    (200, "sm"),
    (600, "md"),
    (1200, "lg"),
];

pub async fn generate(data: &[u8], storage_path: &str, id: &Uuid) -> Result<(), crate::Error> {
    let img = image::load_from_memory(data)?;

    let thumbs_dir = format!("{storage_path}/thumbs");
    tokio::fs::create_dir_all(&thumbs_dir).await?;

    for &(max_dim, label) in SIZES {
        let (w, h) = img.dimensions();
        if w <= max_dim && h <= max_dim {
            // Original is smaller than this thumb size — use original dimensions
            let thumb = img.clone();
            let path = format!("{thumbs_dir}/{id}_{label}.webp");
            thumb.save(&path)?;
        } else {
            let thumb = img.resize(max_dim, max_dim, image::imageops::FilterType::Lanczos3);
            let path = format!("{thumbs_dir}/{id}_{label}.webp");
            thumb.save(&path)?;
        }
    }

    Ok(())
}
