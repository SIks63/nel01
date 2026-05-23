# 🦕 Pterodactyl Panel di GitHub Codespaces

> ⚠️ **Untuk development/testing saja.** Panel akan mati saat Codespace tidur (30 menit idle).

---

## 📋 Langkah-Langkah Lengkap

---

### LANGKAH 1 — Buat Repository di GitHub

1. Buka [github.com](https://github.com) → login
2. Klik tombol **"New"** (buat repo baru)
3. Isi:
   - **Repository name**: `pterodactyl-codespaces`
   - Visibility: **Public** atau **Private** (bebas)
4. Centang **"Add a README file"**
5. Klik **"Create repository"**

---

### LANGKAH 2 — Upload File ke Repository

1. Di halaman repo, klik **"Add file"** → **"Upload files"**
2. Upload semua file dari ZIP ini:
   ```
   .devcontainer/
   ├── devcontainer.json
   ├── setup.sh
   └── restart-services.sh
   ```
3. Klik **"Commit changes"**

> 💡 **Alternatif**: Bisa juga klik "Create new file" lalu copy-paste isi tiap file satu per satu.

---

### LANGKAH 3 — Buka Codespace

1. Di halaman repo, klik tombol hijau **"Code"**
2. Pilih tab **"Codespaces"**
3. Klik **"Create codespace on main"**
4. Tunggu Codespace loading (biasanya 1–2 menit)

---

### LANGKAH 4 — Tunggu Setup Otomatis

Setelah Codespace terbuka, di bagian bawah (terminal) akan muncul proses instalasi otomatis. Ini berjalan dari `postCreateCommand` di `devcontainer.json`.

Proses ini memakan waktu **5–10 menit** karena menginstall:
- PHP 8.3
- MySQL
- Redis
- Nginx
- Pterodactyl Panel
- Migrasi database

Tunggu sampai muncul pesan:
```
╔══════════════════════════════════════════════╗
║         SETUP SELESAI! ✅                    ║
╚══════════════════════════════════════════════╝
```

---

### LANGKAH 5 — Buka Panel di Browser

1. Di Codespace, klik tab **"PORTS"** (di bawah, sebelah tab Terminal)
2. Cari port **80**
3. Klik icon 🌐 (globe) atau klik kanan → **"Open in Browser"**
4. Panel Pterodactyl akan terbuka di tab baru

---

### LANGKAH 6 — Login ke Panel

```
Username : admin
Password : Admin1234!
Email    : admin@panel.local
```

Setelah login, ganti password di **Account Settings**.

---

### LANGKAH 7 — Konfigurasi Panel (Setelah Login)

#### A. Buat Location
1. **Admin Area** (ikon 🔧) → **Locations** → **Create New**
2. Isi:
   - Short Code: `local`
   - Description: `Codespaces Local`
3. Klik **Create**

#### B. Buat Node
1. **Admin Area** → **Nodes** → **Create New**
2. Isi:
   - Name: `Node-Codespaces`
   - Location: pilih `local`
   - FQDN: `localhost`
   - Communicate Over SSL: **No** (karena lokal)
   - Behind Proxy: **Yes**
   - Total Memory: `1024` (MB)
   - Memory Overallocate: `0`
   - Total Disk: `5000` (MB)
3. Klik **Create Node**
4. Masuk ke tab **"Configuration"** → salin isi YAML

#### C. Paste Config Wings
Di terminal Codespace:
```bash
mkdir -p /etc/pterodactyl
nano /etc/pterodactyl/config.yml
# Paste isi YAML dari panel, lalu Ctrl+X → Y → Enter
```

#### D. Install & Jalankan Wings
```bash
# Download Wings
curl -L -o /usr/local/bin/wings \
  https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
chmod +x /usr/local/bin/wings

# Jalankan Wings (di background)
wings --debug &

# Cek apakah Wings jalan
ps aux | grep wings
```

---

### LANGKAH 8 — Import Egg WhatsApp Bot

1. **Admin Area** → **Nests** → **Create New Nest**
   - Name: `Bots`
   - Klik **Save**
2. Klik Nest **Bots** → **Import Egg**
3. Upload file `egg-whatsapp-bot.json`
4. Klik **Import**

---

### LANGKAH 9 — Buat Server WA Bot

1. **Admin Area** → **Servers** → **Create New**
2. Isi bagian **Core Details**:
   - Name: `wa-bot`
   - Owner: `admin`
3. Bagian **Allocation Management**:
   - Node: pilih `Node-Codespaces`
   - Default Allocation: pilih allocation yang tersedia
4. Bagian **Resource Management**:
   - Memory: `512`
   - Disk: `1024`
5. Bagian **Nest Configuration**:
   - Nest: `Bots`
   - Egg: `WhatsApp Bot (Node.js)`
6. Bagian **Egg Variables**:
   - `MAIN_FILE`: `src/index.js`
   - `GIT_ADDRESS`: URL repo bot WA kamu (dari ZIP kemarin)
7. Klik **Create Server**

---

### LANGKAH 10 — Jalankan Bot WA

1. Di panel, buka server `wa-bot`
2. Tab **Files** → upload file bot WA (dari `wa-bot.zip` yang kemarin)
3. Tab **Console** → klik **Start**
4. QR Code akan muncul di console → scan dengan WhatsApp

---

## 🔄 Setiap Kali Codespace Restart

Jalankan perintah ini di terminal:

```bash
bash .devcontainer/restart-services.sh
```

Script ini akan:
- Start ulang MySQL, Redis, Nginx, PHP-FPM
- Update APP_URL otomatis sesuai domain Codespace yang baru

---

## 🛠️ Perintah Berguna

```bash
# Cek semua service
service mysql status
service redis-server status
service nginx status
service php8.3-fpm status

# Lihat log Nginx
tail -f /var/log/nginx/pterodactyl.error.log

# Lihat log queue worker
tail -f /var/log/pteroq.log

# Restart Nginx
service nginx restart

# Artisan commands
cd /var/www/pterodactyl
php artisan config:cache
php artisan cache:clear
```

---

## ⚠️ Batasan Codespaces

| Batasan | Detail |
|---|---|
| Auto-sleep | 30 menit tidak aktif → mati |
| Port forwarding | URL berubah setiap restart |
| Tidak ada SSL | HTTP saja (bukan HTTPS) |
| Wings terbatas | Docker-in-Docker mode terbatas |
| Gratis | 60 jam/bulan (akun personal) |

---

## 📌 Kredensial Default

| Item | Value |
|---|---|
| Panel URL | Port 80 di tab PORTS |
| Admin user | `admin` |
| Admin pass | `Admin1234!` |
| DB name | `panel` |
| DB user | `pterodactyl` |
| DB pass | `pterodactyl_secret` |
