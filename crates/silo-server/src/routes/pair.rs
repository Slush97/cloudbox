use axum::{
    http::{HeaderMap, StatusCode},
    response::Html,
};
use qrcode::{QrCode, render::svg};

/// Public pairing page — shows a QR code containing this server's URL.
/// No auth required. The phone app scans it to get the URL, then handles
/// login or account creation via the normal auth flow.
pub async fn pair_page(
    headers: HeaderMap,
) -> Result<Html<String>, StatusCode> {
    let scheme = if headers.get("x-forwarded-proto")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("http") == "https"
    {
        "https"
    } else {
        "http"
    };
    let host = headers.get("host")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("localhost:3000");
    let origin = format!("{scheme}://{host}");

    let qr = QrCode::new(origin.as_bytes())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let svg_str = qr.render::<svg::Color>()
        .min_dimensions(250, 250)
        .max_dimensions(400, 400)
        .build();

    let html = format!(
        r##"<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Silo — Connect Device</title>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: #0f0f0f;
    color: #e0e0e0;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
  }}
  .card {{
    background: #1a1a1a;
    border-radius: 16px;
    padding: 40px;
    text-align: center;
    max-width: 440px;
    width: 90%;
  }}
  h1 {{ font-size: 24px; margin-bottom: 8px; }}
  .subtitle {{ color: #888; font-size: 14px; margin-bottom: 32px; }}
  .qr-container {{
    background: white;
    border-radius: 12px;
    padding: 20px;
    display: inline-block;
    margin-bottom: 24px;
  }}
  .qr-container svg {{ display: block; }}
  .url {{
    font-family: monospace;
    font-size: 13px;
    color: #aaa;
    margin-bottom: 24px;
    word-break: break-all;
  }}
  .steps {{
    text-align: left;
    font-size: 13px;
    color: #888;
    line-height: 1.8;
  }}
</style>
</head>
<body>
<div class="card">
  <h1>Connect Device</h1>
  <p class="subtitle">Scan this QR code with the Silo app</p>
  <div class="qr-container">{svg}</div>
  <div class="url">{origin}</div>
  <div class="steps">
    <strong>How to connect:</strong><br>
    1. Open Silo on your phone<br>
    2. Tap "Scan QR Code" on the login screen<br>
    3. Point your camera at this code<br>
    4. Log in or create your account
  </div>
</div>
</body>
</html>"##,
        svg = svg_str,
        origin = origin,
    );

    Ok(Html(html))
}
