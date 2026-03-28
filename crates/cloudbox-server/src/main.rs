use axum::{
    Router,
    routing::get,
};
use tower_http::{cors::CorsLayer, trace::TraceLayer};
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

    let app = Router::new()
        .route("/health", get(|| async { "ok" }))
        .nest("/api/v1/auth", routes::auth::router())
        .nest("/api/v1/photos", routes::photos::router())
        .nest("/api/v1/files", routes::files::router())
        .nest("/api/v1/stats", routes::stats::router())
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let addr = format!("{}:{}", config.host, config.port);
    tracing::info!("listening on {addr}");
    let listener = tokio::net::TcpListener::bind(&addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}
