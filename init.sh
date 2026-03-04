#!/bin/bash

# -----------------------------
# 🔧 Laravel-Projekt Setup Tool
# -----------------------------
REPO_URL="https://github.com/mapo-89/laravel-docker-init.git"

if [ ! -d "./templates" ]; then
  echo "📦 Lade Vorlagen aus Git-Repo..."
  git clone --depth=1 "$REPO_URL" ./_initrepo >/dev/null 2>&1
  mv ./_initrepo/templates ./templates
  rm -rf ./_initrepo
fi

if [ -z "$1" ]; then
  echo "❌ Bitte gib einen Projektnamen an: ./init.sh <projektname>"
  exit 1
fi

PROJECT="$(echo "$1" | tr '[:upper:]' '[:lower:]')" # lower-case
ROOT_PATH="$(pwd)"
PROJECT_PATH="$ROOT_PATH/$PROJECT"
SRC_PATH="$PROJECT_PATH/src"
CONTAINER_NAME="${PROJECT}_app"
IMAGE_NAME="${PROJECT}-app"

# --------------------------------------
# 🌐 Domain-Abfrage
# --------------------------------------
read -p "🌐 Externe Domain für das Projekt (z.B. avatarvault.example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
  DOMAIN="${PROJECT}.local"
fi

# --------------------------------------
# 📂 Verzeichnisstruktur erstellen
# --------------------------------------
echo "🚀 Erstelle Verzeichnisstruktur für $PROJECT …"
mkdir -p "$PROJECT_PATH/docker/php"
mkdir -p "$SRC_PATH"

# --------------------------------------
# 📦 Optional: Laravel automatisch installieren
# --------------------------------------
read -p "📦 Laravel installieren? (y/n): " INSTALL_LARAVEL
if [[ "$INSTALL_LARAVEL" == "y" ]]; then
    docker run --rm -v "$SRC_PATH":/app composer create-project laravel/laravel /app
fi

# --------------------------------------
# 🧩 Dockerfile erzeugen
# --------------------------------------
cat > "$PROJECT_PATH/docker/php/Dockerfile" <<EOF
FROM php:8.4-fpm

WORKDIR /var/www/${PROJECT}

RUN apt-get update && apt-get install -y \\
    git unzip zip curl libpng-dev libonig-dev libxml2-dev mariadb-client \
    && docker-php-ext-install pdo pdo_mysql mbstring exif pcntl bcmath gd \
    && php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php \
    && php -r "unlink('composer-setup.php');" \
    && mv composer.phar /usr/local/bin/composer \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
EOF

# --------------------------------------
# 🧱 Kopiere entrypoint.sh & banner.sh
# --------------------------------------
ENTRYPOINT_SRC="$ROOT_PATH/templates/entrypoint.sh"
BANNER_SRC="$ROOT_PATH/templates/banner.sh"

if [[ -f "$ENTRYPOINT_SRC" && -f "$BANNER_SRC" ]]; then
  echo "📂 Kopiere entrypoint.sh und banner.sh ..."
  cp "$ENTRYPOINT_SRC" "$PROJECT_PATH/docker/php/entrypoint.sh"
  cp "$BANNER_SRC" "$PROJECT_PATH/docker/php/banner.sh"
  chmod +x "$PROJECT_PATH/docker/php/entrypoint.sh" "$PROJECT_PATH/docker/php/banner.sh"
  echo "✅ Dateien kopiert & ausführbar gemacht!"
else
  echo "⚠️  entrypoint.sh oder banner.sh nicht gefunden unter $ROOT_PATH/templates/"
  echo "Bitte prüfe, ob beide Vorlagendateien vorhanden sind."
  exit 1
fi

# --------------------------------------
# 🛠️  Docker Image bauen (mit Spinner)
# --------------------------------------
spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  echo -n "🐳 Baue Docker-Image... "
  while kill -0 $pid 2>/dev/null; do
    for (( i=0; i<${#spinstr}; i++ )); do
      printf "\b${spinstr:i:1}"
      sleep $delay
    done
  done
  echo -e "\b Done!"
}

# Docker build im Hintergrund starten
docker build -t "$IMAGE_NAME" "$PROJECT_PATH/docker/php" > /dev/null 2>&1 &
BUILD_PID=$!

# Spinner starten und Build überwachen
spinner $BUILD_PID

# Warten bis docker build komplett ist
wait $BUILD_PID
BUILD_STATUS=$?

if [ $BUILD_STATUS -eq 0 ]; then
  echo "✅ Image $IMAGE_NAME wurde erfolgreich gebaut."
else
  echo "❌ Fehler beim Bauen des Images. $?"
  exit 1
fi

# --------------------------------------
# 🐙 docker-compose.yml erzeugen
# --------------------------------------
cat > "$PROJECT_PATH/docker-compose.yml" <<EOF
services:
  ${CONTAINER_NAME}:
    image: ${IMAGE_NAME}:latest
    container_name: ${CONTAINER_NAME}
    volumes:
      - ${SRC_PATH}:/var/www/${PROJECT}
      - ${PROJECT_PATH}/docker/php/entrypoint.sh:/usr/local/bin/entrypoint.sh
      - ${PROJECT_PATH}/docker/php/banner.sh:/usr/local/bin/banner.sh
    environment:
      PROJECT: ${PROJECT}
    networks:
      - proxy-network
      - databases

networks:
  proxy-network:
    external: true
  databases:
    external: true
EOF

# --------------------------------------
# 🧾 .env Datei erzeugen
# --------------------------------------
cat > "$PROJECT_PATH/.env" <<EOF
PROJECT_NAME=$PROJECT
PROJECT_DOMAIN=$DOMAIN
PROJECT_SRC=$SRC_PATH
PROJECT_CONTAINER=$CONTAINER_NAME
EOF

# --------------------------------------
# 📝 NGINX Config für shared-nginx
# --------------------------------------
CONF_PATH="$ROOT_PATH/shared-nginx/conf.d/$PROJECT.conf"
mkdir -p "$(dirname "$CONF_PATH")"

cat > "$CONF_PATH" <<EOF
upstream ${PROJECT}_backend {
    server ${CONTAINER_NAME}:9000 max_fails=0 fail_timeout=5s;
}

server {
    listen 80;
    server_name $DOMAIN;

    root /var/www/$PROJECT/public;
    index index.php index.html;

    access_log /var/log/nginx/${PROJECT}_access.log;
    error_log  /var/log/nginx/${PROJECT}_error.log;


    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_pass ${PROJECT}_backend;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# --------------------------------------
# 🎯 Abschlussmeldung
# --------------------------------------
echo ""
echo "✅ Projekt '$PROJECT' erfolgreich vorbereitet!"
echo "📁 Pfad:      $PROJECT_PATH"
echo "📄 Nginx:     $CONF_PATH"
echo "🌍 Domain:    $DOMAIN"
echo ""
echo "🛠️  Weitere Schritte:"
echo ""
echo "1️⃣  Lade den Docker-Compose-Stack in Portainer:"
echo "    → Gehe zu Portainer → Stacks → 'Add Stack' (Wenn noch nicht vorhanden)"
echo "    → Name:           laravel-apps"
echo "    → Quelle:         Editor"
echo "    → docker-compose.yml aus folgendem Pfad laden:"
echo "       $PROJECT_PATH/docker-compose.yml"
echo ""
echo "2️⃣  Ergänze im Container 'shared-nginx' (über Portainer oder Compose)"
echo "    ein neues ReadOnly-Volume:"
echo "    → Volume:"
echo "       $SRC_PATH:/var/www/$PROJECT:ro"
echo ""
echo "3️⃣  Lege die Domain als Proxy-Host im Nginx Proxy Manager an:"
echo "    → Domain:        $DOMAIN"
echo "    → Ziel:          shared-nginx:80"
echo "    → SSL:           aktivieren (Let's Encrypt)"
