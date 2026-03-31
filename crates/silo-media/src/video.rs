use std::path::Path;

use uuid::Uuid;

use crate::{Error, VideoMeta};

/// Extract metadata from a video file using ffprobe.
pub async fn extract_metadata(video_path: &Path) -> Result<VideoMeta, Error> {
    let output = tokio::process::Command::new("ffprobe")
        .args([
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
        ])
        .arg(video_path)
        .output()
        .await
        .map_err(|e| Error::Video(format!("ffprobe failed to start: {e}")))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(Error::Video(format!("ffprobe failed: {stderr}")));
    }

    let json: serde_json::Value = serde_json::from_slice(&output.stdout)
        .map_err(|e| Error::Video(format!("ffprobe output parse failed: {e}")))?;

    let mut meta = VideoMeta::default();

    // Duration from format
    if let Some(dur) = json["format"]["duration"].as_str() {
        meta.duration_secs = dur.parse::<f32>().ok();
    }

    // Creation time from format tags
    if let Some(ct) = json["format"]["tags"]["creation_time"].as_str() {
        meta.taken_at = chrono::DateTime::parse_from_rfc3339(ct)
            .ok()
            .map(|d| d.with_timezone(&chrono::Utc));
    }

    // Find the first video stream for dimensions + codec
    if let Some(streams) = json["streams"].as_array() {
        for stream in streams {
            if stream["codec_type"].as_str() == Some("video") {
                meta.width = stream["width"].as_i64().map(|v| v as i32);
                meta.height = stream["height"].as_i64().map(|v| v as i32);
                meta.codec = stream["codec_name"].as_str().map(String::from);
                break;
            }
        }
    }

    Ok(meta)
}

/// Extract a single JPEG frame from a video at the given timestamp.
///
/// Returns raw JPEG bytes. Uses ffmpeg pipe output to avoid temp files.
pub async fn extract_frame(video_path: &Path, timestamp_secs: f32) -> Result<Vec<u8>, Error> {
    let output = tokio::process::Command::new("ffmpeg")
        .args([
            "-ss",
            &format!("{timestamp_secs:.2}"),
            "-i",
        ])
        .arg(video_path)
        .args([
            "-vframes", "1",
            "-f", "image2",
            "-c:v", "mjpeg",
            "-q:v", "2",
            "pipe:1",
        ])
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::null())
        .output()
        .await
        .map_err(|e| Error::Video(format!("ffmpeg frame extraction failed: {e}")))?;

    if output.stdout.is_empty() {
        return Err(Error::Video("ffmpeg produced no output frame".into()));
    }

    Ok(output.stdout)
}

/// Generate thumbnails for a video by extracting a frame and using the image pipeline.
pub async fn generate_thumbs(
    video_path: &Path,
    storage_path: &str,
    id: &Uuid,
    duration_secs: f32,
) -> Result<(), Error> {
    // Extract frame at 10% into the video, or 1s, whichever is less
    let timestamp = (duration_secs * 0.1).min(1.0).max(0.0);
    let frame_data = extract_frame(video_path, timestamp).await?;

    // Reuse existing image thumbnail pipeline
    crate::thumbs::generate(&frame_data, storage_path, id).await?;

    Ok(())
}
