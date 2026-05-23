#!/bin/bash
# ============================================================
# Jalankan ini SETIAP KALI Codespace di-restart
# bash .devcontainer/restart-services.sh
# ============================================================

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✔] $1${NC}"; }
warn() { echo -e "${YELLOW}[!] $1${NC}"; }

log "Start semua service..."
service mysql start
service redis-server start
service php8.3-fpm start
service nginx start
service supervisor start
supervisorctl start pteroq:* > /dev/null 2>&1

# ── UPDATE APP_URL sesuai Codespace domain ────────────────────
# Codespaces memberi URL unik setiap sesi, kita update otomatis
if [ -n "$CODESPACE_NAME" ]; then
  CODESPACE_URL="https://${CODESPACE_NAME}-80.app.github.dev"
  sed -i "s|APP_URL=.*|APP_URL=${CODESPACE_URL}|" /var/www/pterodactyl/.env
  php /var/www/pterodactyl/artisan config:cache > /dev/null 2>&1
  log "APP_URL diupdate ke: ${CODESPACE_URL}"
  echo ""
  echo "  🌐 Buka panel di: ${CODESPACE_URL}"
else
  warn "CODESPACE_NAME tidak ditemukan, APP_URL tidak diupdate."
fi

echo ""
log "Semua service aktif!"
echo ""
echo "  MySQL   : $(service mysql status | grep -o 'running\|stopped')"
echo "  Redis   : $(service redis-server status | grep -o 'running\|stopped')"
echo "  Nginx   : $(service nginx status | grep -o 'running\|stopped')"
echo "  PHP-FPM : $(service php8.3-fpm status | grep -o 'running\|stopped')"
