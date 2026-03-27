use image::GenericImageView;
use uuid::Uuid;

const SIZES: &[(u32, &str)] = &[
    (200, "sm"),
    (600, "md"),
    (1200, "lg"),
];

/// WebP lossy quality (0–100). 80 is a good balance of size vs quality.
const WEBP_QUALITY: f32 = 80.0;

pub async fn generate(data: &[u8], storage_path: &str, id: &Uuid) -> Result<(), crate::Error> {
    let img = image::load_from_memory(data)?;

    let thumbs_dir = format!("{storage_path}/thumbs");
    tokio::fs::create_dir_all(&thumbs_dir).await?;

    for &(max_dim, label) in SIZES {
        let (w, h) = img.dimensions();
        let thumb = if w <= max_dim && h <= max_dim {
            img.clone()
        } else {
            img.resize(max_dim, max_dim, image::imageops::FilterType::Lanczos3)
        };

        let rgba = thumb.to_rgba8();
        let (tw, th) = rgba.dimensions();
        let bytes = {
            let encoder = webp::Encoder::from_rgba(&rgba, tw, th);
            let mem = encoder.encode(WEBP_QUALITY);
            mem.to_vec()
        };

        let path = format!("{thumbs_dir}/{id}_{label}.webp");
        tokio::fs::write(&path, &bytes).await?;
    }

    Ok(())
}
