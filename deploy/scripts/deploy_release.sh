#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/var/www/believer}"
APP_USER="${APP_USER:-${SUDO_USER:-$USER}}"
APP_GROUP="${APP_GROUP:-$APP_USER}"
BRANCH="${BRANCH:-main}"
REMOTE="${REMOTE:-origin}"
WEB_SOURCE_DIR="${WEB_SOURCE_DIR:-/tmp/believer-web}"
SKIP_GIT_PULL="${SKIP_GIT_PULL:-false}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1"
    exit 1
  }
}

require_cmd sudo
require_cmd git
require_cmd npm
require_cmd docker
require_cmd nginx

if ! sudo -n true >/dev/null 2>&1; then
  echo "This deploy script requires passwordless sudo for the current user."
  echo "Grant NOPASSWD access for the deployment user before running CI/CD deploys."
  exit 1
fi

if [[ ! -d "$APP_DIR/.git" ]]; then
  echo "Git repo not found at $APP_DIR"
  exit 1
fi

if [[ ! -d "$WEB_SOURCE_DIR" ]]; then
  echo "WEB_SOURCE_DIR does not exist: $WEB_SOURCE_DIR"
  echo "Upload your prebuilt Flutter web folder to the server first."
  exit 1
fi

if [[ ! -f "$APP_DIR/backend/.env" ]]; then
  echo "Missing $APP_DIR/backend/.env"
  exit 1
fi

cd "$APP_DIR"

if [[ "$SKIP_GIT_PULL" != "true" ]]; then
  echo "Updating code from $REMOTE/$BRANCH ..."
  sudo -u "$APP_USER" git fetch "$REMOTE"
  sudo -u "$APP_USER" git checkout "$BRANCH"
  sudo -u "$APP_USER" git pull --ff-only "$REMOTE" "$BRANCH"
fi

echo "Installing backend dependencies..."
sudo -u "$APP_USER" npm ci

echo "Refreshing frontend bundle from $WEB_SOURCE_DIR ..."
sudo -u "$APP_USER" mkdir -p "$APP_DIR/build"
sudo rm -rf "$APP_DIR/build/web"
sudo mv "$WEB_SOURCE_DIR" "$APP_DIR/build/web"
sudo chown -R "$APP_USER:$APP_GROUP" "$APP_DIR/build"

echo "Ensuring PostgreSQL container is running..."
cd "$APP_DIR/backend"
sudo -u "$APP_USER" docker compose up -d postgres

cd "$APP_DIR"

echo "Running migrations..."
cd "$APP_DIR/backend"
sudo -u "$APP_USER" npm run migrate
cd "$APP_DIR"

echo "Restarting services..."
sudo systemctl restart believer-backend
sudo nginx -t
sudo systemctl reload nginx

echo
echo "Deploy complete."
echo "Verify with:"
echo "  cd $APP_DIR/backend && docker compose ps"
echo "  sudo systemctl status believer-backend --no-pager"
echo "  curl http://127.0.0.1:4000/health"
