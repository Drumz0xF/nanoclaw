#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEPLOY_DIR="$(cd "$PROJECT_ROOT/../deploy" && pwd 2>/dev/null)" || DEPLOY_DIR=""
CONFIG_DIR="$HOME/.config/nanoclaw"

FORCE=false
if [[ "${1:-}" == "--force" ]]; then
  FORCE=true
fi

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }

echo "========================================="
echo " NanoClaw Reset"
echo "========================================="
echo ""
echo "This will delete ALL user data and reset NanoClaw to a clean state."
echo ""
echo "Will be DELETED:"
echo "  - WhatsApp auth session    (store/auth/)"
echo "  - Auth status files        (store/auth-status.txt, store/qr-auth.html)"
echo "  - Message database + WAL   (store/messages.db, -shm, -wal)"
echo "  - Agent sessions           (data/sessions/)"
echo "  - IPC state                (data/ipc/)"
echo "  - Remote control state     (data/remote-control.*)"
echo "  - Group memory & logs      (groups/*/ except global)"
echo "  - Application logs         (logs/)"
echo "  - Agent containers         (docker rm nanoclaw-*)"
echo "  - User config              (~/.config/nanoclaw/)"
echo ""
echo "Will be RESET to placeholders:"
echo "  - .env"
echo "  - data/env/env"
echo ""
echo "Will be PRESERVED:"
echo "  - Source code, build output, node_modules"
echo "  - groups/global/CLAUDE.md"
echo "  - .mcp.json, Docker/build files"
echo ""

if [[ "$FORCE" != true ]]; then
  read -rp "Are you sure you want to proceed? (y/N) " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
  fi
  echo ""
fi

# --- Stop services ---
info "Stopping services..."

if [[ -n "$DEPLOY_DIR" && -f "$DEPLOY_DIR/docker-compose.yml" ]]; then
  (cd "$DEPLOY_DIR" && docker compose down 2>/dev/null) || warn "docker compose down failed (may not be running)"
fi

AGENT_CONTAINERS=$(docker ps -q --filter "name=nanoclaw-" 2>/dev/null || true)
if [[ -n "$AGENT_CONTAINERS" ]]; then
  info "Stopping agent containers..."
  echo "$AGENT_CONTAINERS" | xargs docker stop 2>/dev/null || warn "Some agent containers failed to stop"
else
  info "No running agent containers found"
fi

STALE_CONTAINERS=$(docker ps -aq --filter "name=nanoclaw-" 2>/dev/null || true)
if [[ -n "$STALE_CONTAINERS" ]]; then
  info "Removing agent containers..."
  echo "$STALE_CONTAINERS" | xargs docker rm -f 2>/dev/null || warn "Some agent containers failed to remove"
fi

# --- Delete runtime state ---
info "Removing WhatsApp auth store..."
rm -rf "$PROJECT_ROOT/store/auth"

info "Removing auth status files..."
rm -f "$PROJECT_ROOT/store/auth-status.txt"
rm -f "$PROJECT_ROOT/store/qr-auth.html"

info "Removing message database..."
rm -f "$PROJECT_ROOT/store/messages.db" "$PROJECT_ROOT/store/messages.db-shm" "$PROJECT_ROOT/store/messages.db-wal"

info "Removing agent sessions..."
rm -rf "$PROJECT_ROOT/data/sessions"

info "Removing IPC state..."
rm -rf "$PROJECT_ROOT/data/ipc"

info "Removing remote control state..."
rm -f "$PROJECT_ROOT/data/remote-control.json"
rm -f "$PROJECT_ROOT/data/remote-control.stdout"
rm -f "$PROJECT_ROOT/data/remote-control.stderr"

info "Removing group data (preserving groups/global/)..."
find "$PROJECT_ROOT/groups" -mindepth 1 -maxdepth 1 -type d ! -name global -exec rm -rf {} +

info "Removing application logs..."
rm -rf "$PROJECT_ROOT/logs"

info "Removing user config..."
rm -rf "$CONFIG_DIR"

# --- Reset config files ---
info "Resetting .env files..."

cat > "$PROJECT_ROOT/.env" << 'EOF'
CLAUDE_CODE_OAUTH_TOKEN=
ASSISTANT_NAME="Assistant"
EOF

mkdir -p "$PROJECT_ROOT/data/env"
cat > "$PROJECT_ROOT/data/env/env" << 'EOF'
CLAUDE_CODE_OAUTH_TOKEN=
ASSISTANT_NAME="Assistant"
EOF

# --- Recreate empty directories ---
info "Recreating directory structure..."
mkdir -p "$PROJECT_ROOT/store/auth"
mkdir -p "$PROJECT_ROOT/data/sessions"
mkdir -p "$PROJECT_ROOT/data/ipc"
mkdir -p "$PROJECT_ROOT/logs"

# --- Done ---
echo ""
echo "========================================="
info "NanoClaw has been reset to a clean state."
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Edit nanoclaw/.env and data/env/env with your OAuth token and assistant name"
echo "  2. Build:                 cd nanoclaw && npm run build"
echo "  3. Start:                 cd deploy && docker compose up nanoclaw"
echo "  4. Authenticate WhatsApp: cd nanoclaw && node dist/whatsapp-auth.js"
