#!/usr/bin/env bash
set -euo pipefail

# Copy all data from the current directory to the remote host using rsync.
# Defaults to root@194.164.150.169:/root/network/
#
# Usage:
#   ./scripts/rsync-copy.sh            # real copy
#   DRY_RUN=1 ./scripts/rsync-copy.sh  # preview only
#
# Optional env overrides:
#   REMOTE_HOST=root@194.164.150.169
#   REMOTE_DIR=/root/network
#   SSH_PORT=22
#   SSH_KEY=~/.ssh/id_rsa        # optional; empty to use default agent
#   SRC_DIR=$(pwd)                # override source directory if needed
#   DELETE=0                      # 1 to mirror (delete extras on remote), 0 to keep

REMOTE_HOST=${REMOTE_HOST:-root@194.164.150.169}
REMOTE_DIR=${REMOTE_DIR:-/root/network}
SSH_PORT=${SSH_PORT:-22}
SSH_KEY=${SSH_KEY:-}
SRC_DIR=${SRC_DIR:-$(pwd)}
DRY_RUN=${DRY_RUN:-0}
DELETE=${DELETE:-0}

echo "[i] Copying from: $SRC_DIR"
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

# Ensure remote directory
ssh "${SSH_OPTS[@]}" "$REMOTE_HOST" "mkdir -p '$REMOTE_DIR'"

# Run rsync (trailing slash copies contents of SRC_DIR into REMOTE_DIR)
rsync "${RSYNC_OPTS[@]}" -e "ssh ${SSH_OPTS[*]}" \
  "$SRC_DIR/" "$REMOTE_HOST:$REMOTE_DIR/"

echo "[✓] Copy complete"
