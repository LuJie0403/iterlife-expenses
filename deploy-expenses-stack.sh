#!/bin/bash
# Dockerized deployment for iterlife-expenses API + iterlife-expenses-ui.
# Config/code isolation: runtime env files must live outside git repos.

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BACKEND_REPO_DIR="${BACKEND_REPO_DIR:-$ROOT_DIR}"
UI_REPO_DIR="${UI_REPO_DIR:-$(cd "$ROOT_DIR/.." && pwd)/iterlife-expenses-ui}"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT_DIR/deploy/docker-compose.example.yml}"

CONFIG_ROOT="${CONFIG_ROOT:-/apps/config/iterlife-expenses}"
BACKEND_ENV_FILE="${BACKEND_ENV_FILE:-$CONFIG_ROOT/backend.env}"
UI_ENV_FILE="${UI_ENV_FILE:-$CONFIG_ROOT/ui.env}"
UI_RUNTIME_CONFIG_FILE="${UI_RUNTIME_CONFIG_FILE:-$CONFIG_ROOT/ui-runtime-config.js}"

API_BIND_HOST="${API_BIND_HOST:-127.0.0.1}"
API_PORT="${API_PORT:-18180}"
UI_BIND_HOST="${UI_BIND_HOST:-127.0.0.1}"
UI_PORT="${UI_PORT:-13180}"

log() {
  echo "[deploy] $*"
}

die() {
  echo "[deploy][error] $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

check_file() {
  [ -f "$1" ] || die "Required file not found: $1"
}

check_dir() {
  [ -d "$1" ] || die "Required directory not found: $1"
}

wait_for_http_ok() {
  local url="$1"
  local retries="${2:-30}"
  local sleep_seconds="${3:-2}"
  local i
  for i in $(seq 1 "$retries"); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$sleep_seconds"
  done
  return 1
}

require_cmd docker
require_cmd curl

docker compose version >/dev/null 2>&1 || die "docker compose plugin not available"

check_dir "$BACKEND_REPO_DIR"
check_dir "$UI_REPO_DIR"
check_file "$COMPOSE_FILE"
check_file "$BACKEND_ENV_FILE"
check_file "$UI_ENV_FILE"
check_file "$UI_RUNTIME_CONFIG_FILE"

export BACKEND_REPO_DIR
export UI_REPO_DIR
export BACKEND_ENV_FILE
export UI_ENV_FILE
export UI_RUNTIME_CONFIG_FILE
export API_BIND_HOST
export API_PORT
export UI_BIND_HOST
export UI_PORT

log "Deploying with compose file: $COMPOSE_FILE"
log "Backend repo: $BACKEND_REPO_DIR"
log "UI repo: $UI_REPO_DIR"
log "Config root: $CONFIG_ROOT"

docker compose -f "$COMPOSE_FILE" up -d --build

API_HEALTH_URL="http://${API_BIND_HOST}:${API_PORT}/api/health"
UI_HEALTH_URL="http://${UI_BIND_HOST}:${UI_PORT}"

if ! wait_for_http_ok "$API_HEALTH_URL" 30 2; then
  docker compose -f "$COMPOSE_FILE" logs --tail=200 iterlife-expenses-api || true
  die "API health check failed: $API_HEALTH_URL"
fi

if ! wait_for_http_ok "$UI_HEALTH_URL" 30 2; then
  docker compose -f "$COMPOSE_FILE" logs --tail=200 iterlife-expenses-ui || true
  die "UI health check failed: $UI_HEALTH_URL"
fi

log "Docker deployment completed successfully."
echo "API health: $API_HEALTH_URL"
echo "UI health:  $UI_HEALTH_URL"
