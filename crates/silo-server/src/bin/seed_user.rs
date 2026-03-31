use std::env;

/// Seed the single admin user.
/// Usage: seed-user <username> <password>
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();

    let args: Vec<String> = env::args().collect();
    if args.len() != 3 {
        eprintln!("Usage: seed-user <username> <password>");
        std::process::exit(1);
    }
    let username = &args[1];
    let password = &args[2];

    let db_url = env::var("DATABASE_URL")?;
    let pool = sqlx::PgPool::connect(&db_url).await?;

    sqlx::migrate!("../../migrations").run(&pool).await?;

    let user = silo_db::users::create(&pool, username, password).await?;
    println!("Created user: {} (id: {})", user.username, user.id);

    Ok(())
}
