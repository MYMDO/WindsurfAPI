#!/usr/bin/env bash
# =============================================================================
# 🚀 WindsurfAPI — Швидкий старт для українських користувачів
#
# One-command deployment з усіма перевірками та виправленням підводних каменів.
#
# Використання:
#   curl -fsSL https://raw.githubusercontent.com/MYMDO/WindsurfAPI/master/quickstart-ua.sh | bash
#   або
#   bash quickstart-ua.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log()  { echo -e "${CYAN}==>${NC} $*"; }
ok()   { echo -e "${GREEN}  ✓${NC} $*"; }
warn() { echo -e "${YELLOW}  ⚠${NC} $*"; }
err()  { echo -e "${RED}  ✗${NC} $*" >&2; }

# ─── Preflight checks ─────────────────────────────────────
log "Перевірка системи..."

HAS_DOCKER=false
HAS_NODE=false
HAS_GIT=false

command -v docker &>/dev/null && HAS_DOCKER=true && ok "Docker встановлено" || warn "Docker не знайдено (буде використано Node.js)"
command -v node   &>/dev/null && HAS_NODE=true   && ok "Node.js встановлено ($(node -v))" || err "Node.js не знайдено! Встановіть Node.js >= 20"
command -v git    &>/dev/null && HAS_GIT=true    && ok "Git встановлено" || warn "Git не знайдено"

# Check Node version
if $HAS_NODE; then
  NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
  if [ "$NODE_VER" -lt 20 ]; then
    err "Node.js >= 20 потрібен, поточна версія: $(node -v)"
    exit 1
  fi
fi

# ─── Clone repo ────────────────────────────────────────────
REPO_DIR="$HOME/WindsurfAPI"
if [ -d "$REPO_DIR" ]; then
  warn "Директорія $REPO_DIR вже існує. Оновлюю..."
  cd "$REPO_DIR"
  git pull 2>/dev/null || warn "Не вдалося виконати git pull (продовжую)"
else
  log "Клонування репозиторію..."
  git clone https://github.com/MYMDO/WindsurfAPI.git "$REPO_DIR"
  cd "$REPO_DIR"
  ok "Репозиторій склоновано"
fi

cd "$REPO_DIR"

# ─── .env ──────────────────────────────────────────────────
if [ ! -f .env ]; then
  log "Створення .env..."
  cat > .env << 'EOF'
PORT=3003
API_KEY=local-dev-key
DEFAULT_MODEL=claude-sonnet-4.6
MAX_TOKENS=8192
LOG_LEVEL=info
LS_BINARY_PATH=/opt/windsurf/language_server_linux_x64
LS_DATA_DIR=/opt/windsurf/data
LS_PORT=42100
DASHBOARD_PASSWORD=admin
ALLOW_PRIVATE_PROXY_HOSTS=1
EOF
  ok ".env створено (API_KEY=local-dev-key, DASHBOARD_PASSWORD=admin)"
else
  ok ".env вже існує"
fi

# ─── Docker deployment ─────────────────────────────────────
if $HAS_DOCKER; then
  log "Запуск через Docker Compose..."

  # Check if model-access.json exists and fix it
  if [ -f ".docker-data/data/model-access.json" ]; then
    MODE=$(python3 -c "import json; print(json.load(open('.docker-data/data/model-access.json'))['mode'])" 2>/dev/null || echo "unknown")
    if [ "$MODE" != "all" ]; then
      warn "model-access.json у режимі '$MODE'! Всі моделі будуть заблоковані!"
      log "Автоматичне виправлення..."
      python3 -c "
import json
with open('.docker-data/data/model-access.json', 'w') as f:
    json.dump({'mode':'all','list':[]}, f)
"
      chmod 444 .docker-data/data/model-access.json
      ok "model-access.json виправлено на mode=all та захищено (chmod 444)"
    fi
  fi

  docker compose up -d --build 2>&1 | tail -5
  ok "Контейнери запущено"

  # Wait for startup
  sleep 3

  # Ensure model-access is correct (in case Docker overwrote it)
  sleep 2

  log "Перевірка health-endpoint..."
  if curl -sfS http://localhost:3003/health > /dev/null 2>&1; then
    ok "WindsurfAPI працює на http://localhost:3003"
    ok "Dashboard: http://localhost:3003/dashboard"
  else
    warn "Сервер ще не готовий. Зачекайте 10-15 секунд та перевірте:"
    warn "  curl http://localhost:3003/health"
    warn "  docker compose logs -f"
  fi

else
  # ─── Node.js deployment ──────────────────────────────────
  log "Запуск через Node.js..."

  # Install LS binary
  if [ ! -f "$LS_BINARY_PATH" ]; then
    log "Завантаження Language Server..."
    bash install-ls.sh 2>&1 | tail -3 || warn "Не вдалося завантажити LS. Встановіть вручну: bash install-ls.sh"
  else
    ok "Language Server знайдено: $LS_BINARY_PATH"
  fi

  # Create data dir
  mkdir -p "$LS_DATA_DIR/db" /tmp/windsurf-workspace 2>/dev/null || true

  log "Запуск сервера..."
  echo ""
  echo "  ${GREEN}WindsurfAPI запускається...${NC}"
  echo "  ${CYAN}Dashboard:${NC} http://localhost:3003/dashboard"
  echo "  ${CYAN}API:${NC}       http://localhost:3003/v1"
  echo "  ${CYAN}Key:${NC}       local-dev-key"
  echo ""
  echo "  ${YELLOW}ВАЖЛИВО:${NC} Після запуску додайте акаунт!"
  echo "  ${YELLOW}  1.${NC} Відкрийте Dashboard та авторизуйтесь (пароль: admin)"
  echo "  ${YELLOW}  2.${NC} Перейдіть на https://windsurf.com/show-auth-token"
  echo "  ${YELLOW}  3.${NC} Скопіюйте токен (ott$...) та вставте в Dashboard"
  echo "  ${YELLOW}  4.${NC} Натисніть 'Додати' та зачекайте 15-20 секунд"
  echo ""

  node src/index.js
fi

# ─── Post-deploy: Fix model-access ─────────────────────────
log "Фінальна перевірка model-access..."
if curl -sfS http://localhost:3003/health > /dev/null 2>&1; then
  curl -s -X PUT http://localhost:3003/dashboard/api/model-access \
    -H "X-Dashboard-Password: admin" \
    -H "Content-Type: application/json" \
    -d '{"mode":"all","list":[]}' > /dev/null 2>&1 && \
    ok "model-access.json перевірено та встановлено в mode=all"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✅  WindsurfAPI успішно запущено!                      ║"
echo "║                                                          ║"
echo "║  📊 Dashboard:  http://localhost:3003/dashboard          ║"
echo "║  🔑 Пароль:     admin                                   ║"
echo "║  🔌 API:        http://localhost:3003/v1                 ║"
echo "║  🔐 API Key:    local-dev-key                            ║"
echo "║                                                          ║"
echo "║  📖 Документація (укр): README.ua.md                     ║"
echo "║  🆘 Підводні камені:    TROUBLESHOOTING.md               ║"
echo "║  ⚙️ OpenCode приклад:   opencode.json                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
