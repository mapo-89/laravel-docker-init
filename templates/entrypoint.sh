#!/bin/sh
set -e

# -----------------------------
# 🔧 Logging function
# -----------------------------
log() {
    local level=$1
    local message=$2
    echo "[`date '+%d-%b-%Y %H:%M:%S'`] $level $message"
}

# Lade Banner, falls vorhanden
if [ -f /usr/local/bin/banner.sh ]; then
    chmod +x /usr/local/bin/banner.sh
    /usr/local/bin/banner.sh
else
    echo "${PROJECT} startup..."
fi
                                                                                                                     
USER_NAME=${SUDO_USER:-${USER:-$(whoami)}}
GROUP_NAME=$(id -gn "$USER_NAME")
PHP_VERSION=$(php -v | head -n1)                                                                                                                                                                                                   

echo
echo "👤 User:      $USER_NAME  PUID:$(id -u "$USER_NAME")"
echo
echo "👥 Group:     $GROUP_NAME  PGID:$(id -g "$USER_NAME")"
echo
echo "🐘 PHP:       $PHP_VERSION"
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo


# -----------------------------
# 📂 Load Laravel .env
# -----------------------------
ENV_FILE="/var/www/${PROJECT}/.env"

if [ -f "$ENV_FILE" ]; then
    log "📥 info    " "Loading Laravel .env from $ENV_FILE"
    export $(grep -v '^#' "$ENV_FILE" | grep -E 'DB_|APP_' | xargs)
    log "✅ success " ".env variables loaded."
else
    log "⚠️ WARNING " ".env file not found at $ENV_FILE, make sure DB_ variables are set"
fi

# -----------------------------
# 🌐 Wait for shared-nginx
# -----------------------------
NGINX_HOST=${NGINX_HOST:-shared-nginx}
NGINX_PORT=${NGINX_PORT:-80}
MAX_RETRIES=${MAX_RETRIES:-10}
RETRY_COUNT=0

log "🔍 info    " "Checking shared-nginx connection ($NGINX_HOST:$NGINX_PORT)..."

until curl -s "http://$NGINX_HOST:$NGINX_PORT" >/dev/null 2>&1; do
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        log "🚫 ERROR   " "shared-nginx unreachable after $MAX_RETRIES attempts!"
        exit 1
    fi
    log "⏱ WARNING  " "Attempt $RETRY_COUNT/$MAX_RETRIES – waiting 5 seconds..."
    sleep 5
done

log "✅ success " "shared-nginx is reachable!"

# -----------------------------
# 🔍 Prüfen, ob mysqladmin verfügbar ist
# -----------------------------
if ! command -v mysqladmin >/dev/null 2>&1; then
    log "⚠️ WARNING " "'mysqladmin' not found — attempting to install..."
    if [ -f /etc/alpine-release ]; then
        apk add --no-cache mariadb-client >/dev/null 2>&1
        log "✅ success " "Installed mariadb-client (Alpine)"
    elif command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq && apt-get install -y -qq mariadb-client >/dev/null 2>&1
        log "✅ success " "Installed mariadb-client (Debian/Ubuntu)"
    else
        log "🚫 ERROR   " "Could not install mysqladmin — unknown base image."
        exit 1
    fi
fi

# -----------------------------
# 🐬 Wait for MariaDB (if configured)
# -----------------------------
if [ "${DB_CONNECTION:-}" = "mysql" ]; then
    DB_HOST=${DB_HOST:-mariadb}
    DB_PORT=${DB_PORT:-3306}
    DB_USER=${DB_USERNAME:-root}
    DB_PASS=${DB_PASSWORD:-}
    
    log "🔍 info    " "Checking database connection (${DB_HOST}:${DB_PORT})..."
    RETRY_COUNT=0

    until mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --ssl=0 -e "SELECT 1;" >/dev/null 2>&1; do
        RETRY_COUNT=$((RETRY_COUNT+1))
        if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
            log "🚫 ERROR   " "Database not reachable after $MAX_RETRIES attempts!"
            exit 1
        fi
        log "⏱ WARNING  " "Attempt $RETRY_COUNT/$MAX_RETRIES – waiting 5 seconds..."
        sleep 5
    done

    log "✅ success " "Database connection successful!"
else
    log "ℹ️ info " "Skipping database check – DB_CONNECTION=$DB_CONNECTION"
fi

# -----------------------------
# 🚀 Start PHP-FPM in background
# -----------------------------
log "▶️ start    " "Starting PHP-FPM..."
php-fpm
