use image::GenericImageView;

/// 64-bit perceptual difference hash (dHash).
///
/// Resilient to resizing, recompression, minor crops, and color adjustments.
/// Two images with hamming distance <= 10 are likely visual duplicates.
pub fn dhash(data: &[u8]) -> Result<u64, crate::Error> {
    let img = image::load_from_memory(data)?;
    let gray = img.grayscale().resize_exact(9, 8, image::imageops::FilterType::Lanczos3);

    let mut hash: u64 = 0;
    for y in 0..8 {
        for x in 0..8 {
            let left = gray.get_pixel(x, y)[0];
            let right = gray.get_pixel(x + 1, y)[0];
            if left > right {
                hash |= 1 << (y * 8 + x);
            }
        }
    }
    Ok(hash)
}

/// Hamming distance between two hashes — number of differing bits.
pub fn hamming(a: u64, b: u64) -> u32 {
    (a ^ b).count_ones()
}

/// Threshold for considering two images duplicates.
pub const DUPLICATE_THRESHOLD: u32 = 10;
