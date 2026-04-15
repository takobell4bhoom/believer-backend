#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${DOMAIN:-app.believerslens.com}"
APP_DIR="${APP_DIR:-/var/www/believer}"
APP_USER="${APP_USER:-${SUDO_USER:-$USER}}"
APP_GROUP="${APP_GROUP:-$APP_USER}"
REPO_URL="${REPO_URL:-}"
BRANCH="${BRANCH:-main}"
WEB_SOURCE_DIR="${WEB_SOURCE_DIR:-/tmp/believer-web}"
ENABLE_TLS="${ENABLE_TLS:-false}"

if [[ -z "$REPO_URL" ]]; then
  echo "REPO_URL is required."
  echo "Example:"
  echo "  REPO_URL=https://github.com/you/repo.git DOMAIN=$DOMAIN bash deploy/scripts/setup_hosting.sh"
  exit 1
fi

if [[ ! -d "$WEB_SOURCE_DIR" ]]; then
  echo "WEB_SOURCE_DIR does not exist: $WEB_SOURCE_DIR"
  echo "Upload your prebuilt Flutter web folder to the server first."
  exit 1
fi

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1"
    exit 1
  }
}

require_cmd sudo
require_cmd curl
require_cmd git

echo "Installing Ubuntu hosting dependencies..."
sudo apt update
sudo apt install -y nginx git curl ca-certificates gnupg certbot python3-certbot-nginx unzip zip

if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt install -y nodejs
fi

if ! command -v docker >/dev/null 2>&1; then
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

sudo usermod -aG docker "$APP_USER" || true
sudo mkdir -p "$(dirname "$APP_DIR")"
sudo chown -R "$APP_USER:$APP_GROUP" "$(dirname "$APP_DIR")"

if [[ ! -d "$APP_DIR/.git" ]]; then
  sudo -u "$APP_USER" git clone --branch "$BRANCH" "$REPO_URL" "$APP_DIR"
else
  echo "Repo already exists at $APP_DIR, skipping clone."
fi

cd "$APP_DIR"

echo "Installing Node dependencies..."
sudo -u "$APP_USER" npm ci

echo "Placing prebuilt frontend from $WEB_SOURCE_DIR ..."
sudo -u "$APP_USER" mkdir -p "$APP_DIR/build"
sudo rm -rf "$APP_DIR/build/web"
sudo mv "$WEB_SOURCE_DIR" "$APP_DIR/build/web"
sudo chown -R "$APP_USER:$APP_GROUP" "$APP_DIR/build"

echo "Starting PostgreSQL container..."
cd "$APP_DIR/backend"
sudo -u "$APP_USER" docker compose up -d postgres

cd "$APP_DIR"

if [[ ! -f "$APP_DIR/backend/.env" ]]; then
  echo "backend/.env is missing."
  echo "Create it from backend/.env.production.example before continuing."
  exit 1
fi

echo "Running backend migrations..."
cd "$APP_DIR/backend"
sudo -u "$APP_USER" npm run migrate
cd "$APP_DIR"

echo "Installing systemd service..."
sudo tee /etc/systemd/system/believer-backend.service >/dev/null <<EOF
[Unit]
Description=BelieversLens Backend API
After=network.target docker.service

[Service]
Type=simple
User=$APP_USER
Group=$APP_GROUP
WorkingDirectory=$APP_DIR/backend
Environment=PATH=/usr/bin:/usr/local/bin
ExecStart=/usr/bin/node src/index.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "Installing Nginx site..."
sudo tee /etc/nginx/sites-available/believer >/dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root $APP_DIR/build/web;
    index index.html;

    client_max_body_size 10M;

    location /api/ {
        proxy_pass http://127.0.0.1:4000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /uploads/ {
        proxy_pass http://127.0.0.1:4000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location = /health {
        proxy_pass http://127.0.0.1:4000/health;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/believer /etc/nginx/sites-enabled/believer
sudo nginx -t

sudo systemctl daemon-reload
sudo systemctl enable believer-backend
sudo systemctl restart believer-backend
sudo systemctl reload nginx

if [[ "$ENABLE_TLS" == "true" ]]; then
  sudo certbot --nginx -d "$DOMAIN"
fi

echo
echo "Setup complete."
echo "Check services with:"
echo "  cd $APP_DIR/backend && docker compose ps"
echo "  sudo systemctl status believer-backend --no-pager"
echo "  sudo systemctl status nginx --no-pager"
echo "  curl http://127.0.0.1:4000/health"
echo "  curl http://$DOMAIN/health"
