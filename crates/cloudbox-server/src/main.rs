use axum::{
    http::{header, HeaderValue, Method},
    routing::get,
    Router,
};
use tower_http::{
    cors::CorsLayer,
    limit::RequestBodyLimitLayer,
    trace::TraceLayer,
};
use tracing_subscriber::{EnvFilter, layer::SubscriberExt, util::SubscriberInitExt};

mod auth;
mod config;
mod error;
mod routes;
mod state;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenvy::dotenv().ok();

    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| "cloudbox=debug,info".into()))
        .with(tracing_subscriber::fmt::layer())
        .init();

    let config = config::Config::from_env()?;
    let state = state::AppState::new(&config).await?;

    let cors = build_cors_layer(config.cors_origin.as_deref());

    let app = Router::new()
        .route("/health", get(|| async { "ok" }))
        .nest("/api/v1/auth", routes::auth::router())
        .nest("/api/v1/photos", routes::photos::router())
        .nest("/api/v1/files", routes::files::router())
        .nest("/api/v1/albums", routes::albums::router())
        .nest("/api/v1/notes", routes::notes::router())
        .nest("/api/v1/trash", routes::trash::router())
        .nest("/api/v1/stats", routes::stats::router())
        .route("/pair", get(routes::pair::pair_page))
        .route("/s/{token}", get(routes::files::download_shared))
        .layer(RequestBodyLimitLayer::new(config.max_upload_bytes))
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(state.clone());

    // Background task: clean up expired trash every hour
    {
        let trash_state = state.clone();
        tokio::spawn(async move {
            loop {
                tokio::time::sleep(std::time::Duration::from_secs(3600)).await;
                tracing::info!("running scheduled cleanup");
                routes::trash::cleanup_expired_trash(&trash_state, 30).await;
                cloudbox_db::pairing::cleanup_expired(&trash_state.db).await;
            }
        });
    }

    let addr = format!("{}:{}", config.host, config.port);
    tracing::info!("listening on {addr}");
    let listener = tokio::net::TcpListener::bind(&addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

fn build_cors_layer(origin: Option<&str>) -> CorsLayer {
    let methods = [Method::GET, Method::POST, Method::PUT, Method::DELETE];
    let headers = [header::AUTHORIZATION, header::CONTENT_TYPE];

    match origin {
        Some("*") => CorsLayer::permissive(),
        Some(origin) => CorsLayer::new()
            .allow_origin(
                origin
                    .parse::<HeaderValue>()
                    .expect("CORS_ORIGIN must be a valid header value"),
            )
            .allow_methods(methods)
            .allow_headers(headers),
        // No CORS_ORIGIN set: same-origin only (browser default)
        None => CorsLayer::new()
            .allow_methods(methods)
            .allow_headers(headers),
    }
}
