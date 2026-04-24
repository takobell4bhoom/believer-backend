#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIREBASE_DEFINE_FILE="$REPO_ROOT/config/firebase/mobile.local.json"

if [[ ! -f "$FIREBASE_DEFINE_FILE" ]]; then
  echo "Missing Firebase config file: $FIREBASE_DEFINE_FILE" >&2
  echo "Copy config/firebase/mobile.local.example.json to config/firebase/mobile.local.json and fill in your Firebase values." >&2
  exit 1
fi

exec flutter run --dart-define-from-file="$FIREBASE_DEFINE_FILE" "$@"
