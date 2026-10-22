# Deployment in EasyPanel

Diese Variante baut das Image beim Deployment und richtet ERPNext/HRMS sowie Suite
beim ersten Start automatisch auf zwei Sites ein. Es sind keine Shell-Befehle auf
dem Server fuer die Erstinstallation erforderlich.

## 1. Compose-Service anlegen

In einem EasyPanel-Projekt einen neuen Service vom Typ **Compose** anlegen.
Als Quelle **Git** verwenden:

| Feld | Wert |
| --- | --- |
| Repository | git@github.com:fatih4159/Frappe-Accounting-Bundle.git |
| Branch | main |
| Build Path | / |
| Docker Compose File | compose.easypanel.yaml |

Das Repository ist privat: den von EasyPanel angezeigten SSH-Schluessel in GitHub
unter Repository Settings → Deploy keys als Read-only-Key hinterlegen.
Falls deine EasyPanel-Version keinen Compose-Service anbietet, ist diese Variante
nicht als normaler App-Service verwendbar; zuerst auf eine Version mit Compose
aktualisieren. Ein einfacher App-Service startet nur einen Container.

## 2. Umgebung setzen

Die Werte aus .env.example in den Environment-Editor uebernehmen und **Create .env
file** aktivieren. Insbesondere diese vier Werte anpassen:

    ERP_SITE=erp.deine-domain.de
    SUITE_SITE=suite.deine-domain.de
    DB_ROOT_PASSWORD='DEIN_EIGENES_LANGES_DB_PASSWORT'
    ADMIN_PASSWORD='DEIN_EIGENES_LANGES_ADMIN_PASSWORT'

Site-Namen sind die oeffentlichen Hostnamen ohne https://, Port oder Pfad. Sie muessen
verschieden sein. Die Beispiel-Passwoerter ersetzen. Weitere Werte aus .env.example
beibehalten; HTTP_BIND, ERP_PORT, SUITE_PORT und FRAPPE_DOCKER_REF werden von dieser
Compose-Variante nicht verwendet. Keine feste COMPOSE_PROJECT_NAME setzen: EasyPanel
soll Projekt-/Volume-Namen verwalten. CUSTOM_IMAGE darf bei mehreren Installationen
auf demselben Server je Installation einen eigenen Namen erhalten.

## 3. Deploy und Domains

**Deploy** starten. EasyPanel baut zuerst das Image; danach folgen Datenbank/Redis,
Konfiguration und der Setup-Dienst. Backend, Worker und Frontends starten erst nach
erfolgreichem Setup. Der erste Build und die Installation koennen laenger dauern.
Im Log nach dem Dienst **setup** filtern. Ein Exit-Code 0 bei setup und configurator
ist normal: beide sind einmalige Einrichtungsdienste.

Unter Domains diese Zuordnungen einrichten:

| Oeffentliche Domain | Interner Compose-Service | Port | Interne Verbindung |
| --- | --- | --- | --- |
| Wert von ERP_SITE | frontend | 8080 | HTTP |
| Wert von SUITE_SITE | suite-frontend | 8080 | HTTP |

DNS beider Domains auf den EasyPanel-Server zeigen lassen und HTTPS in EasyPanel
aktivieren. Keine Host-Ports oder separaten Traefik-Labels erforderlich.

ERP ueber https://ERP_SITE aufrufen, Suite ueber https://SUITE_SITE/suite.
Anmeldung jeweils als **Administrator** mit ADMIN_PASSWORD. ERPNext und Suite haben
getrennte Benutzerkonten. Der jeweilige Einrichtungsassistent erscheint nach Login.

## Persistenz und spaetere Deployments

Datenbank, Sites/Uploads, Logs und Redis-Queue liegen in benannten Docker-Volumes.
Service und Volume-Namen nach der Erstinstallation beibehalten. Backups beider Sites
inklusive Dateien und site_config.json extern sichern; siehe README.
Das Setup ist wiederholbar und installiert vorhandene Apps nicht erneut. Eine Aenderung
von ADMIN_PASSWORD setzt bestehende Benutzerpasswoerter nicht zurueck. Nach dem ersten
Start aendert DB_ROOT_PASSWORD das bestehende MariaDB-Root-Passwort ebenfalls nicht.

Deployments aktualisieren nicht automatisch die Datenbankschemata. Bei App-Updates
Backups und Wartungsmodus verwenden, nach dem Deployment beide Sites ueber die
Backend-Konsole mit bench --site SITE migrate migrieren und anschliessend die
Worker/Backend-Dienste neu starten. Updates zuerst mit einer Kopie testen.
Zum Aktualisieren beweglicher App-Branches BUILD_REVISION erhoehen und neu deployen;
das erzwingt die erneute App-Installation im Image-Build. Eine Aenderung von apps.json
invalidiert den entsprechenden Build-Cache ebenfalls. Keine Tokens in apps.json ablegen.

## Umfang und Pruefung

Suite ist eine WIP-App. Meet-SFU/Recorder/TURN, Sheets-Collaboration und Mail-JMAP/Suite
Cloud sind weiterhin separat einzurichten. Dieses Deployment installiert die Suite-App,
aber nicht diese zusaetzlichen Dienste.

Geprueft: Compose-Struktur, Startreihenfolge, Dockerfile-Dateiverweise, Bash-Syntax
und Wiederholbarkeit/Fehlerverhalten des Setup-Skripts mit einem simulierten Bench.
Ein echter Image-Build und ein Deployment auf einer EasyPanel-Instanz wurden hier
nicht durchgefuehrt.

Quelle: https://easypanel.io/docs/services/compose (Stand 22.10.2026)

## Wenn setup ohne sichtbare Fehlermeldung abbricht

Seit Diagnose-Version 2 gibt das Setup jeden Arbeitsschritt aus und schreibt dieselbe
Ausgabe dauerhaft nach /home/frappe/frappe-bench/logs/bundle-setup.log im logs-Volume.
Auch Fehler, die Bench nur auf stdout statt stderr schreibt, werden sichtbar gemacht.
Es werden keine Shell-Traces mit Passwortargumenten aktiviert.

Nach einem erneuten Deploy muss im setup-Log START Diagnose-Version 2 erscheinen.
Falls die EasyPanel-Ansicht leer bleibt, auf dem Server direkt lesen:

    docker logs --tail 150 dms_frappe-setup-1

Fuer das im Fehlerbild gezeigte Projekt dms / Service frappe kann die persistente
Datei auch aus dem gestoppten Container kopiert werden:

    docker cp dms_frappe-setup-1:/home/frappe/frappe-bench/logs/bundle-setup.log ./bundle-setup.log

Bei anderen Projekt-/Servicenamen den Containernamen anpassen. Ist selbst die
START-Meldung nicht vorhanden und die Datei existiert nicht, den Containerstatus pruefen:

    docker inspect --format '{{json .State}}' dms_frappe-setup-1

Das zeigt auch Startfehler des Containers vor dem Aufruf des Skripts. Eine leere
Logansicht allein identifiziert die Ursache nicht. Bestehende Volumes beibehalten.

## Separater Neustart nach fehlgeschlagener Erstinstallation

Falls MariaDB das im Container gesetzte MARIADB_ROOT_PASSWORD nicht akzeptiert,
ist eine Authentifizierungsabweichung bestaetigt. Fuer eine neue Installation ohne
zu uebernehmende Daten kann ein neuer, leerer Satz Volumes verwendet werden:

    DATA_VOLUME_SUFFIX=_fresh_20261022_01

Diesen Wert zusaetzlich in EasyPanels Environment setzen, Create .env file aktiviert
lassen und deployen. DB_ROOT_PASSWORD und ADMIN_PASSWORD muessen vor dem Start
gefuellt sein; Werte mit Sonderzeichen in einfache Anfuehrungszeichen setzen.
Datenbank, Sites, Queue und Logs wechseln gemeinsam auf neue Volumes. Alte Volumes
werden weder geleert noch geloescht; ihre Daten erscheinen in der neuen Installation
nicht. Nach erfolgreicher Einrichtung den Suffix dauerhaft beibehalten.
Mit leerem Suffix werden wieder die urspruenglichen Volumes ausgewaehlt; zum Wechsel
zuerst den Service stoppen, damit alte und neue Datenbestaende nicht gleichzeitig
verwendet werden. Das ist eine neue Installation, keine Migration oder Reparatur
vorhandener Geschaeftsdaten. Bei bereits produktiven Daten stattdessen den bestehenden
Datenbankzugang wiederherstellen.

Der Standard ohne Suffix entspricht weiterhin den bisherigen, nach Compose-Projekt
benannten Volumes. Docker Compose liefert COMPOSE_PROJECT_NAME aus seinem Projektnamen
(EasyPanel verwendet -p); diese Variable nicht manuell ueberschreiben.
