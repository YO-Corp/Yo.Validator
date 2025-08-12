#!/usr/bin/env bash
set -euo pipefail

# Sync this repository to a remote host using rsync.
# Defaults target the provided server; override via env vars.
#
# Usage:
#   ./scripts/rsync-deploy.sh            # real deploy
#   DRY_RUN=1 ./scripts/rsync-deploy.sh  # preview only
#
# Env vars you can override:
#   REMOTE_HOST=root@194.164.150.169
#   REMOTE_DIR=/root/network
#   SSH_PORT=22
#   SSH_KEY=~/.ssh/id_rsa                # optional; empty to use default agent
#   DELETE=1                              # 1 to mirror (delete extras on remote), 0 to keep

REMOTE_HOST=${REMOTE_HOST:-root@194.164.150.169}
REMOTE_DIR=${REMOTE_DIR:-/root/network}
SSH_PORT=${SSH_PORT:-22}
SSH_KEY=${SSH_KEY:-}
DRY_RUN=${DRY_RUN:-0}
DELETE=${DELETE:-1}

# Resolve repo root (prefer git; fallback to script dir parent)
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  REPO_ROOT=$(git rev-parse --show-toplevel)
else
  SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
  REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
fi

SRC_DIR="$REPO_ROOT"   # trailing slash added in rsync call to copy contents

echo "[i] Deploying from: $SRC_DIR"
echo "[i] To: $REMOTE_HOST:$REMOTE_DIR (port $SSH_PORT)"

# Build SSH options
SSH_OPTS=("-p" "$SSH_PORT" "-o" "StrictHostKeyChecking=accept-new")
if [[ -n "$SSH_KEY" ]]; then
  SSH_OPTS+=("-i" "$SSH_KEY")
fi

# Build rsync options
RSYNC_OPTS=(
  -az --human-readable --progress
  --chmod=Fu=rw,Fg=r,Fa=r,Du=rwx,Dg=rx,Da=rx
  --exclude .git
  --exclude .gitignore
  --exclude .DS_Store
  --exclude .vscode
  --exclude .idea
  --exclude node_modules
)

if [[ "$DELETE" == "1" ]]; then
  RSYNC_OPTS+=(--delete)
fi

if [[ "$DRY_RUN" == "1" ]]; then
  RSYNC_OPTS+=(--dry-run)
  echo "[i] DRY RUN enabled — no changes will be made"
fi

echo "[i] Ensuring remote directory exists..."
ssh "${SSH_OPTS[@]}" "$REMOTE_HOST" "mkdir -p '$REMOTE_DIR'"

echo "[i] Running rsync..."
rsync "${RSYNC_OPTS[@]}" -e "ssh ${SSH_OPTS[*]}" \
  "$SRC_DIR/" "$REMOTE_HOST:$REMOTE_DIR/"

echo "[✓] Deploy complete"
