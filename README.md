# Frappe Accounting Bundle

Docker Compose fuer Frappe 16, ERPNext 16, HRMS 16 und Frappe Suite.

| Site | Apps | Lokaler Zugang |
| --- | --- | --- |
| erp.localhost | Frappe, ERPNext, HRMS | http://localhost:8080 |
| suite.localhost | Frappe, Suite develop | http://localhost:8081/suite |

Suite ist upstream WIP. Suite ersetzt Dateiberechtigungen und den Setup-Wizard.
Deshalb liegen ERPNext/HRMS und Suite auf getrennten Sites im selben Stack.
Die Sites teilen Image, Datenbankserver und Worker, haben aber getrennte Datenbanken
und Benutzerkonten. Ein gemeinsamer Login wird hier nicht eingerichtet.

## Installation

Voraussetzungen: Linux, Git, Bash, sha256sum, Docker mit BuildKit/Buildx und Compose v2.
Der Server braucht Zugriff auf GitHub und Paket-/Containerregistries.

    git clone https://github.com/fatih4159/Frappe-Accounting-Bundle.git
    cd Frappe-Accounting-Bundle
    cp .env.example .env

In .env unterschiedliche starke Werte fuer DB_ROOT_PASSWORD und ADMIN_PASSWORD
eintragen. Werte mit Dollarzeichen oder Raute in einfache Anfuehrungszeichen setzen.
Optional Site-Namen, Ports und Zeitzone anpassen. Keine echten Passwoerter committen.

    bash scripts/build.sh
    docker compose up -d db redis-cache redis-queue configurator
    docker compose --profile setup run --rm setup
    docker compose up -d
    docker compose ps

Login: Administrator mit ADMIN_PASSWORD auf beiden Sites. ERPNext auf Port 8080
einrichten, Suite auf Port 8081. Der Build kann einige Zeit und viel RAM beanspruchen.
Das Setup ueberspringt vorhandene Sites und installierte Apps. Nach einem Fehler die
Ursache beheben und erneut ausfuehren. Vorhandene Passwoerter werden nicht zurueckgesetzt.

## Dateien und Versionen

- compose.yaml: MariaDB, Redis, Backend, Worker, Scheduler, Websocket, Nginx und Setup.
- .env.example: Konfiguration ohne echte Zugangsdaten; lokal als .env verwenden.
- apps.json: ERPNext/HRMS auf version-16 und Suite auf develop. Frappe selbst wird
  ueber FRAPPE_BRANCH durch bench init installiert.
- scripts/build.sh: Baut mit dem offiziellen frappe_docker-Containerfile auf fixiertem
  Upstream-Commit und uebergibt apps.json als BuildKit-Secret. Verwendet Python 3.14,
  Node 24 und ergaenzt FFmpeg fuer Suite.
- scripts/setup-sites.sh: Erstellt die zwei Sites und installiert die Apps.

App-Branches bewegen sich. Fuer reproduzierbare Deployments nach Integrationstests
passende Release-Tags in apps.json und FRAPPE_BRANCH verwenden.
Bei einem beabsichtigten App-Update --no-cache zum Docker-Build im Buildskript
hinzufuegen, da die unveraenderte App-Liste sonst aus dem Cache gebaut werden kann.

## Suite: zusaetzliche Dienste

Die App wird eingebaut und installiert. Folgende Infrastruktur ist nicht enthalten:

- Meet braucht einen separaten mediasoup SFU, je nach Netz TURN und fuer Aufnahmen Recorder.
- Sheets braucht fuer gemeinsame Echtzeitbearbeitung einen Collaboration-Server.
- Mail/Calendar brauchen einen JMAP-Server; Suite Cloud ermoeglicht zentrale Kontenverwaltung.
- Fuer Systemmails einen Email Account in Frappe konfigurieren.

Diese Funktionen sind durch die App-Installation allein noch nicht vollstaendig nutzbar.

## Domains und HTTPS

Ports sind standardmaessig an 127.0.0.1 gebunden. Ein Reverse Proxy auf dem Host kann
ERP auf Port 8080 und Suite auf Port 8081 mit HTTPS bereitstellen; Websocket-Upgrades
aktivieren. Site-Namen in .env koennen die jeweiligen Domains sein.
Bei einem Proxy in Docker diesen ins Compose-Netz aufnehmen und frontend:8080 bzw.
suite-frontend:8080 verwenden. 127.0.0.1 im Proxy-Container bezeichnet ihn selbst.
Fuer LAN-Tests HTTP_BIND auf eine geeignete Host-Adresse setzen.

## Sicherung und Updates

Bei geaenderten Site-Namen die folgenden Befehle anpassen:

    docker compose exec backend bench --site erp.localhost backup --with-files
    docker compose exec backend bench --site suite.localhost backup --with-files
    mkdir -p backups
    docker compose cp backend:/home/frappe/frappe-bench/sites/erp.localhost/private/backups ./backups/erp
    docker compose cp backend:/home/frappe/frappe-bench/sites/suite.localhost/private/backups ./backups/suite

Backups und site_config.json beider Sites mit den Verschluesselungsschluesseln
ausserhalb des Servers sichern. Updates zuerst mit einer Kopie testen. Nach Backup
und geplantem Build die Container austauschen und beide Sites migrieren:

    docker compose up -d --force-recreate
    docker compose exec backend bench --site erp.localhost migrate
    docker compose exec backend bench --site suite.localhost migrate

docker compose down stoppt den Stack. down -v loescht die Datenvolumes und ist kein
normaler Update-Schritt.

## Validierungsstand

YAML, JSON, Bash-Syntax und Service-Abhaengigkeiten wurden geprueft. Docker war in
der Erstellungsumgebung nicht installiert. Image-Build, App-Installation und Laufzeit
sind daher noch nicht praktisch getestet. Keine Zusage fuer Produktionsreife oder
vollstaendige Kompatibilitaet des beweglichen Suite-Entwicklungsstands.

## Offizielle Quellen (22.10.2026)

- https://github.com/frappe/frappe_docker/blob/fcc73cf55d202e68ab58885cdcc61a8616d08b51/compose.yaml
- https://github.com/frappe/frappe_docker/blob/fcc73cf55d202e68ab58885cdcc61a8616d08b51/docs/02-setup/02-build-setup.md
- https://github.com/frappe/suite/blob/develop/README.md
- https://github.com/frappe/suite/blob/develop/pyproject.toml
- https://github.com/frappe/suite/blob/develop/suite/hooks.py
- https://github.com/frappe/suite/blob/develop/suite/meet/sfu-server/README.md
