#!/usr/bin/env bash
set -euo pipefail

SILO_DIR="$(cd "$(dirname "$0")" && pwd)"
DB_USER="silo"
DB_PASS="silo"
DB_NAME="silo"

echo "=== Silo Setup ==="
echo ""

# ── 1. Postgres ──────────────────────────────────────────────────

echo "[1/7] Checking Postgres..."

if ! command -v psql &>/dev/null; then
    echo "  Installing postgresql..."
    sudo pacman -S --noconfirm postgresql
fi

# Init data directory if empty
if [ ! -f /var/lib/postgres/data/PG_VERSION ]; then
    echo "  Initializing database cluster..."
    sudo -u postgres initdb -D /var/lib/postgres/data
fi

if ! systemctl is-active --quiet postgresql; then
    echo "  Starting postgresql..."
    sudo systemctl enable --now postgresql
fi

echo "  Postgres is running."

# ── 2. pgvector ──────────────────────────────────────────────────

echo "[2/7] Checking pgvector..."

HAS_VECTOR=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_available_extensions WHERE name = 'vector';" 2>/dev/null || true)

if [ "$HAS_VECTOR" != "1" ]; then
    echo "  Installing pgvector from source..."
    TMPDIR=$(mktemp -d)
    git clone --depth 1 https://github.com/pgvector/pgvector.git "$TMPDIR/pgvector"
    cd "$TMPDIR/pgvector"
    make
    sudo make install
    cd "$SILO_DIR"
    rm -rf "$TMPDIR"
    echo "  pgvector installed."
else
    echo "  pgvector already available."
fi

# ── 3. Database + user ───────────────────────────────────────────

echo "[3/7] Setting up database..."

# Create user if not exists
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER';" | grep -q 1; then
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
    echo "  Created user '$DB_USER'."
else
    echo "  User '$DB_USER' already exists."
fi

# Create database if not exists
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME';" | grep -q 1; then
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
    echo "  Created database '$DB_NAME'."
else
    echo "  Database '$DB_NAME' already exists."
fi

# Enable pgvector extension
sudo -u postgres psql -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null
echo "  pgvector extension enabled."

# ── 4. .env file ─────────────────────────────────────────────────

echo "[4/7] Setting up .env..."

ENV_FILE="$SILO_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
    JWT_SECRET=$(head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 32)
    cat > "$ENV_FILE" <<ENVEOF
DATABASE_URL=postgres://$DB_USER:$DB_PASS@localhost:5432/$DB_NAME
JWT_SECRET=$JWT_SECRET
STORAGE_PATH=$SILO_DIR/data
SILO_HOST=0.0.0.0
SILO_PORT=3000
ENVEOF
    chmod 600 "$ENV_FILE"
    echo "  Created .env with random JWT secret."
else
    echo "  .env already exists, skipping."
fi

# ── 5. Build ─────────────────────────────────────────────────────

echo "[5/7] Building silo..."
cd "$SILO_DIR"
cargo build --release 2>&1 | tail -3
echo "  Build complete."

# ── 6. Seed user ─────────────────────────────────────────────────

echo "[6/7] Creating admin user..."

read -rp "  Username [admin]: " ADMIN_USER
ADMIN_USER="${ADMIN_USER:-admin}"

read -rsp "  Password: " ADMIN_PASS
echo ""

if [ -z "$ADMIN_PASS" ]; then
    echo "  Error: password cannot be empty."
    exit 1
fi

cargo run --release --bin seed-user -- "$ADMIN_USER" "$ADMIN_PASS" 2>&1 | grep -v "^$"
echo ""

# ── 7. Done ──────────────────────────────────────────────────────

echo "[7/7] Setup complete!"
echo ""
echo "  Start the server:"
echo "    cargo run --release --bin silo"
echo ""
echo "  Or run directly:"
echo "    $SILO_DIR/target/release/silo"
echo ""
echo "  Test it:"
echo "    curl -s localhost:3000/health"
echo ""
echo "    curl -s localhost:3000/api/v1/auth/login \\"
echo "      -H 'Content-Type: application/json' \\"
echo "      -d '{\"username\":\"$ADMIN_USER\",\"password\":\"***\"}'"
echo ""
