#!/usr/bin/env bash
# Standard deployment updater for iterlife-expenses + iterlife-expenses-ui.
# Policy: deploy only from GitHub merged branch via git pull --ff-only.

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_REPO_DIR="${BACKEND_REPO_DIR:-$ROOT_DIR}"
UI_REPO_DIR="${UI_REPO_DIR:-$(cd "$ROOT_DIR/.." && pwd)/iterlife-expenses-ui}"

DEPLOY_BRANCH="${DEPLOY_BRANCH:-main}"
ALLOW_DIRTY="${ALLOW_DIRTY:-false}"

BACKUP_ROOT="${BACKUP_ROOT:-/home/openclaw-expenses/backups}"
BACKUP_PREFIX="${BACKUP_PREFIX:-openclaw-expenses}"
SKIP_CODE_BACKUP="${SKIP_CODE_BACKUP:-false}"
BACKUP_TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/${BACKUP_PREFIX}_${BACKUP_TIMESTAMP}"

log() {
  echo "[update] $*"
}

die() {
  echo "[update][error] $*" >&2
  exit 1
}

check_git_repo() {
  local repo_dir="$1"
  [ -d "$repo_dir/.git" ] || die "Not a git repository: $repo_dir"
}

ensure_clean_repo() {
  local repo_dir="$1"
  if [ "$ALLOW_DIRTY" = "true" ]; then
    log "ALLOW_DIRTY=true, skip clean working tree check for $repo_dir"
    return 0
  fi
  if [ -n "$(git -C "$repo_dir" status --porcelain)" ]; then
    die "Working tree is not clean: $repo_dir (commit/stash/discard changes first, or set ALLOW_DIRTY=true)"
  fi
}

backup_repo() {
  local repo_dir="$1"
  local output_dir="$2"

  mkdir -p "$output_dir" || die "Failed to create backup target: $output_dir"

  if command -v rsync >/dev/null 2>&1; then
    rsync -a \
      --exclude ".git" \
      --exclude "node_modules" \
      --exclude "dist" \
      --exclude "backend/venv" \
      --exclude "*.log" \
      "$repo_dir/" "$output_dir/" || die "Backup failed via rsync for $repo_dir"
  else
    tar -C "$repo_dir" \
      --exclude ".git" \
      --exclude "node_modules" \
      --exclude "dist" \
      --exclude "backend/venv" \
      --exclude "*.log" \
      -cf - . | tar -C "$output_dir" -xf - || die "Backup failed via tar for $repo_dir"
  fi
}

update_repo_branch() {
  local repo_dir="$1"
  log "Updating repo to origin/${DEPLOY_BRANCH} via fast-forward pull: $repo_dir"

  git -C "$repo_dir" fetch --prune origin
  git -C "$repo_dir" show-ref --verify --quiet "refs/remotes/origin/${DEPLOY_BRANCH}" \
    || die "Remote branch not found: origin/${DEPLOY_BRANCH} ($repo_dir)"

  if git -C "$repo_dir" show-ref --verify --quiet "refs/heads/${DEPLOY_BRANCH}"; then
    git -C "$repo_dir" switch "${DEPLOY_BRANCH}"
  else
    git -C "$repo_dir" switch -c "${DEPLOY_BRANCH}" "origin/${DEPLOY_BRANCH}"
  fi

  git -C "$repo_dir" pull --ff-only origin "${DEPLOY_BRANCH}"
}

check_git_repo "$BACKEND_REPO_DIR"
check_git_repo "$UI_REPO_DIR"
ensure_clean_repo "$BACKEND_REPO_DIR"
ensure_clean_repo "$UI_REPO_DIR"

if [ "$SKIP_CODE_BACKUP" != "true" ]; then
  mkdir -p "$BACKUP_ROOT" || die "Failed to create backup root: $BACKUP_ROOT"
  [ -w "$BACKUP_ROOT" ] || die "Backup root is not writable: $BACKUP_ROOT"
  [ ! -e "$BACKUP_DIR" ] || die "Backup path already exists: $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR" || die "Failed to create backup path: $BACKUP_DIR"

  log "Creating code backups under: $BACKUP_DIR"
  backup_repo "$BACKEND_REPO_DIR" "$BACKUP_DIR/iterlife-expenses"
  backup_repo "$UI_REPO_DIR" "$BACKUP_DIR/iterlife-expenses-ui"
  log "Backup completed: $BACKUP_DIR"
else
  log "Skipping code backup (SKIP_CODE_BACKUP=true)."
fi

update_repo_branch "$BACKEND_REPO_DIR"
update_repo_branch "$UI_REPO_DIR"

log "Triggering dockerized full deployment..."
BACKEND_REPO_DIR="$BACKEND_REPO_DIR" \
UI_REPO_DIR="$UI_REPO_DIR" \
bash "$ROOT_DIR/deploy-expenses-stack.sh"

log "Update deployment process finished."
