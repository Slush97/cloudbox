#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== Silo Docker Setup ==="

# Generate .env.prod if it doesn't exist
if [ ! -f .env.prod ]; then
    JWT_SECRET=$(head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 32)
    DB_PASSWORD=$(head -c 16 /dev/urandom | base64 | tr -d '/+=' | head -c 16)

    cat > .env.prod <<EOF
JWT_SECRET=$JWT_SECRET
DB_PASSWORD=$DB_PASSWORD
EOF
    chmod 600 .env.prod
    echo "Generated .env.prod with random secrets"
else
    echo "Using existing .env.prod"
fi

# Build and start
echo "Building and starting Silo (this may take a few minutes on first run)..."
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build

echo ""
echo "=== Silo is running ==="
echo "Open https://your-domain or http://localhost (via Caddy)"
echo "Create your account on first visit"
echo ""
echo "Commands:"
echo "  Stop:    docker compose -f docker-compose.prod.yml down"
echo "  Logs:    docker compose -f docker-compose.prod.yml logs -f silo"
echo "  Update:  git pull && ./docker-setup.sh"
