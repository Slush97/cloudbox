use std::io::Cursor;

use crate::PhotoMeta;

pub fn extract(data: &[u8]) -> Option<PhotoMeta> {
    let reader = exif::Reader::new();
    let exif_data = reader.read_from_container(&mut Cursor::new(data)).ok()?;

    let mut meta = PhotoMeta::default();

    if let Some(field) = exif_data.get_field(exif::Tag::DateTimeOriginal, exif::In::PRIMARY) {
        if let exif::Value::Ascii(ref v) = field.value {
            if let Some(s) = v.first().and_then(|b| std::str::from_utf8(b).ok()) {
                // Parse EXIF date format "2024:03:15 14:30:00"
                meta.taken_at = chrono::NaiveDateTime::parse_from_str(s, "%Y:%m:%d %H:%M:%S")
                    .ok()
                    .map(|dt| dt.and_utc());
            }
        }
    }

    if let (Some(lat), Some(lon)) = (
        get_gps_coord(&exif_data, exif::Tag::GPSLatitude, exif::Tag::GPSLatitudeRef),
        get_gps_coord(&exif_data, exif::Tag::GPSLongitude, exif::Tag::GPSLongitudeRef),
    ) {
        meta.latitude = Some(lat);
        meta.longitude = Some(lon);
    }

    if let Some(field) = exif_data.get_field(exif::Tag::Make, exif::In::PRIMARY) {
        meta.camera_make = Some(field.display_value().to_string());
    }
    if let Some(field) = exif_data.get_field(exif::Tag::Model, exif::In::PRIMARY) {
        meta.camera_model = Some(field.display_value().to_string());
    }
    if let Some(field) = exif_data.get_field(exif::Tag::PixelXDimension, exif::In::PRIMARY) {
        if let Some(w) = field.value.get_uint(0) {
            meta.width = Some(w as i32);
        }
    }
    if let Some(field) = exif_data.get_field(exif::Tag::PixelYDimension, exif::In::PRIMARY) {
        if let Some(h) = field.value.get_uint(0) {
            meta.height = Some(h as i32);
        }
    }

    Some(meta)
}

fn get_gps_coord(exif_data: &exif::Exif, coord_tag: exif::Tag, ref_tag: exif::Tag) -> Option<f64> {
    let field = exif_data.get_field(coord_tag, exif::In::PRIMARY)?;
    let ref_field = exif_data.get_field(ref_tag, exif::In::PRIMARY)?;

    if let exif::Value::Rational(ref v) = field.value {
        if v.len() >= 3 {
            let deg = v[0].to_f64();
            let min = v[1].to_f64();
            let sec = v[2].to_f64();
            let mut coord = deg + min / 60.0 + sec / 3600.0;

            let ref_str = ref_field.display_value().to_string();
            if ref_str.contains('S') || ref_str.contains('W') {
                coord = -coord;
            }
            return Some(coord);
        }
    }
    None
}
