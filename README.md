
# 🔧 Laravel Projekt Setup Script

Dieses Bash-Skript automatisiert die Erstellung eines neuen Laravel-Projekts innerhalb einer Docker-Umgebung mit optionaler Laravel-Installation, automatisiertem Image-Building und vorbereiteter Portainer/NGINX-Konfiguration.

---

## 🧩 Features

- Automatische Projektverzeichnisstruktur
- Optionale Laravel-Installation via Composer
- Automatischer Docker-Image-Build mit Spinner-Animation
- Erstellung von `docker-compose.yml` & `.env`
- NGINX-Konfiguration automatisch erzeugen (für `shared-nginx`)
- Separater Startup-Banner (`banner.sh`)
- Einheitlicher Entrypoint (`entrypoint.sh`) zur Initialisierung des Containers
- Hinweise zur Integration in Portainer & NGINX Proxy Manager


---

## ▶️ Nutzung

```bash
./init.sh <projektname>
```

Beispiel:

```bash
./init.sh avatarvault
```

---

## 🧭 Ablauf des Skripts

1. **Projektnamen abfragen** – automatisch in Kleinbuchstaben umgewandelt
2. **Domain abfragen** – Standard: `<projektname>.local`  
3. **Verzeichnisstruktur erstellen**  
   ```bash
   /projektname/
   ├── docker/php/
   ├── src/
   ```
4. **Optionale Laravel-Installation**  
   - per Composer in das `src`-Verzeichnis  
5. **Erzeugung des Dockerfiles**  
6. **Docker-Image im Hintergrund bauen** (inkl. Spinner)  
7. **Generierung von `docker-compose.yml` und `.env`**  
8. **Erstellung der NGINX-Konfiguration**  
   - im Volume: `/srv/docker/shared-nginx/conf.d`  
9. **Kopieren von `entrypoint.sh` und `banner.sh`**
   - Aus `/templates` in das neue Projekt
   - Automatisch ausführbar gemacht (`chmod +x`)
9. **Hinweise zur Integration in Portainer & NGINX Proxy Manager**

---

## 📂 Ergebnisstruktur

```
avatarvault/
├── docker/
│   └── php/
│       ├── Dockerfile
│       ├── entrypoint.sh
│       └── banner.sh
├── src/
│   └── [Laravel-App-Inhalt]
├── docker-compose.yml
├── .env
```

---

## 🛠️ orgehen bei neuen Projekten

### 1. Projekt erstellen

```bash
./init.sh <neues-projekt>
```

### 2. Banner anpassen

   - Datei: `<projektname>/docker/php/banner.sh`
   - Text, Farben oder Logos ändern

### 3. Optional: Entrypoint erweitern
   - Datei: `<projektname>/docker/php/entrypoint.sh`
   - z.B. eigene Startkommandos hinzufügen

### 4. Docker-Compose Stack in Portainer laden

- Öffne Portainer > Stacks > *Add Stack* oder ergänze bereits vorhandenen Stack
- **Name:** `laravel-apps`  
- **Quelle:** Editor oder Datei  
- **Lade:** `docker-compose.yml` aus dem erzeugten Projektverzeichnis

### 5. Volume im `shared-nginx`-Container ergänzen

In Portainer oder per `docker-compose.override.yml`:

```yaml
volumes:
  - /pfad/zum/projekt/src:/var/www/<projektname>:ro
```

### 3. Domain im NGINX Proxy Manager anlegen

- **Domain:** z. B. `avatarvault.local` oder `avatarvault.example.com`  
- **Ziel:** `shared-nginx:80`  
- **SSL:** Let's Encrypt aktivieren

---

## 📋 Voraussetzungen

- Docker & Docker Compose  
- Portainer (für UI-Verwaltung)  
- NGINX Proxy Manager  
- Freigeschaltete Volumes in `shared-nginx`  
- (Optional) Laravel via Composer (wird per Container installiert)

---

## ❗ Hinweise

- Das Skript erwartet, dass `shared-nginx` ein Docker-Container ist, der bereits läuft und über `/root/docker/shared-nginx/conf.d/` seine NGINX-Konfigurationen bezieht.  
- Bei Bedarf müssen Berechtigungen für das `src`-Verzeichnis angepasst werden:  
  ```bash
  sudo chown -R 1000:1000 ./src
  ```

---

## 🧑‍💻 Lizenz

MIT – frei für persönliche und kommerzielle Nutzung.
Erstellt mit ❤️ für modulare Laravel-Deployments.