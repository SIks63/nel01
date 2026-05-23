#!/bin/bash
# ============================================================
# Auto-setup Pterodactyl di GitHub Codespaces
# Dijalankan otomatis via postCreateCommand
# ============================================================

set -e
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✔] $1${NC}"; }
warn() { echo -e "${YELLOW}[!] $1${NC}"; }
err()  { echo -e "${RED}[✘] $1${NC}"; }

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   Pterodactyl Panel — GitHub Codespaces      ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── SYSTEM UPDATE ────────────────────────────────────────────
log "Update sistem..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y -q
apt-get install -y -q curl wget git unzip software-properties-common \
  apt-transport-https ca-certificates gnupg lsb-release supervisor

# ── PHP 8.3 ──────────────────────────────────────────────────
log "Install PHP 8.3..."
add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
apt-get update -y -q
apt-get install -y -q php8.3 php8.3-{cli,fpm,mysql,gd,mbstring,bcmath,xml,curl,zip,intl}

# ── MYSQL ────────────────────────────────────────────────────
log "Install MySQL..."
apt-get install -y -q mysql-server
service mysql start

# Buat database & user
mysql -u root << 'SQL'
CREATE DATABASE IF NOT EXISTS panel CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY 'pterodactyl_secret';
GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
log "Database MySQL siap. Password: pterodactyl_secret"

# ── REDIS ────────────────────────────────────────────────────
log "Install Redis..."
apt-get install -y -q redis-server
service redis-server start

# ── NGINX ────────────────────────────────────────────────────
log "Install Nginx..."
apt-get install -y -q nginx
service nginx start

# ── COMPOSER ────────────────────────────────────────────────
log "Install Composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer > /dev/null 2>&1

# ── DOWNLOAD PANEL ───────────────────────────────────────────
log "Download Pterodactyl Panel..."
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzf panel.tar.gz --strip-components=1
rm panel.tar.gz
chmod -R 755 storage bootstrap/cache

# ── ENV SETUP ────────────────────────────────────────────────
log "Konfigurasi .env..."
cp .env.example .env
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction -q

php artisan key:generate --force

# Set .env values langsung (tanpa interactive prompt karena Codespace)
sed -i "s|APP_URL=.*|APP_URL=http://localhost|" .env
sed -i "s|DB_HOST=.*|DB_HOST=127.0.0.1|" .env
sed -i "s|DB_DATABASE=.*|DB_DATABASE=panel|" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=pterodactyl|" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=pterodactyl_secret|" .env
sed -i "s|CACHE_DRIVER=.*|CACHE_DRIVER=redis|" .env
sed -i "s|SESSION_DRIVER=.*|SESSION_DRIVER=redis|" .env
sed -i "s|QUEUE_CONNECTION=.*|QUEUE_CONNECTION=redis|" .env
sed -i "s|REDIS_HOST=.*|REDIS_HOST=127.0.0.1|" .env
sed -i "s|APP_TIMEZONE=.*|APP_TIMEZONE=Asia/Jakarta|" .env

# ── MIGRATE ──────────────────────────────────────────────────
log "Migrasi database..."
php artisan migrate --seed --force

# ── BUAT ADMIN USER ──────────────────────────────────────────
log "Membuat user admin default..."
php artisan p:user:make \
  --email="admin@panel.local" \
  --username="admin" \
  --name-first="Admin" \
  --name-last="Panel" \
  --password="Admin1234!" \
  --admin=1 2>/dev/null || warn "User admin sudah ada, skip."

# ── FILE PERMISSION ──────────────────────────────────────────
chown -R www-data:www-data /var/www/pterodactyl

# ── NGINX CONFIG ─────────────────────────────────────────────
log "Konfigurasi Nginx..."
cat > /etc/nginx/sites-available/pterodactyl.conf << 'EOF'
server {
    listen 80 default_server;
    server_name _;
    root /var/www/pterodactyl/public;
    index index.php;

    access_log /var/log/nginx/pterodactyl.access.log;
    error_log  /var/log/nginx/pterodactyl.error.log error;

    client_max_body_size 100m;
    client_body_timeout 120s;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
nginx -t && service nginx reload

# ── PHP-FPM ──────────────────────────────────────────────────
service php8.3-fpm start

# ── SUPERVISOR (Queue Worker) ─────────────────────────────────
log "Setup queue worker dengan Supervisor..."
cat > /etc/supervisor/conf.d/pteroq.conf << 'EOF'
[program:pteroq]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
autostart=true
autorestart=true
user=www-data
numprocs=1
redirect_stderr=true
stdout_logfile=/var/log/pteroq.log
EOF

service supervisor start
supervisorctl reread > /dev/null 2>&1
supervisorctl update > /dev/null 2>&1
supervisorctl start pteroq:* > /dev/null 2>&1

# ── CRON ─────────────────────────────────────────────────────
(crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -

# ── SELESAI ──────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║         SETUP SELESAI! ✅                    ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  URL    : Port 80 (lihat tab PORTS)          ║"
echo "║  User   : admin                              ║"
echo "║  Pass   : Admin1234!                         ║"
echo "║  Email  : admin@panel.local                  ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
warn "Buka tab PORTS di Codespaces → klik link port 80"
