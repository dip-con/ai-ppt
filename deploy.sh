#!/usr/bin/env bash
set -euo pipefail

REMOTE="${REMOTE:-ubuntu-nas}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

cleanup_macos_metadata() {
  find . -name '._*' -not -path './.git/*' -print -delete 2>/dev/null || true
  find . -name '.DS_Store' -not -path './.git/*' -print -delete 2>/dev/null || true
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }
}

require_command ssh
require_command rsync
cleanup_macos_metadata

APP_DIR="/srv/apps/ai-ppt"
SMOKE_URL="http://127.0.0.1:18080/"

echo "== deploy ai-ppt to ${REMOTE}:${APP_DIR} =="
ssh "$REMOTE" "mkdir -p '$APP_DIR'"
rsync -az --delete \
  --exclude '.git/' \
  --exclude 'node_modules/' \
  --exclude 'dist/' \
  --exclude '.astro/' \
  --exclude 'playwright-report/' \
  --exclude 'test-results/' \
  --exclude '.env*' \
  --exclude '._*' \
  --exclude '.DS_Store' \
  --exclude '.omc/' \
  --exclude '.omx/' \
  ./ "$REMOTE:$APP_DIR/"

ssh "$REMOTE" "set -euo pipefail
cd '$APP_DIR'
docker compose -f docker-compose.yml config >/dev/null
docker compose -f docker-compose.yml build app
docker compose -f docker-compose.yml up -d --no-deps app
docker compose -f docker-compose.yml ps
curl --noproxy '*' -fsS -o /tmp/ai_ppt_deploy_smoke.html --connect-timeout 3 --max-time 10 '$SMOKE_URL' >/dev/null
"

echo "ai-ppt deployed. NPM upstream: http://192.168.0.40:18080"
