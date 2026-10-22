#!/usr/bin/env bash
set -Eeuo pipefail
export PYTHONUNBUFFERED=1
phase='Protokollierung starten'
trap 'result=$?; if (( result != 0 )); then printf "[setup] ABBRUCH: Schritt=%s Exit-Code=%s\n" "$phase" "$result" >&2; fi' EXIT
mkdir -p logs
exec > >(tee -a logs/bundle-setup.log) 2>&1
printf '\n[setup] START Diagnose-Version 2 (%s UTC)\n' "$(date -u +%FT%TZ)"
phase='Umgebungsvariablen pruefen'
for variable in ERP_SITE SUITE_SITE DB_ROOT_PASSWORD ADMIN_PASSWORD; do
  [[ -n "${!variable:-}" ]] || { printf '[setup] Variable %s fehlt oder ist leer.\n' "$variable" >&2; exit 1; }
done
[[ "$ERP_SITE" != "$SUITE_SITE" ]] || { echo '[setup] ERP_SITE und SUITE_SITE muessen verschieden sein.' >&2; exit 1; }
for site in "$ERP_SITE" "$SUITE_SITE"; do
  [[ "$site" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || { echo '[setup] Ungueltiger Site-Name: nur Hostname, ohne https://, Port oder Pfad.' >&2; exit 1; }
done
printf '[setup] Konfiguration geprueft; Zugangsdaten werden nicht ausgegeben.\n'

ensure_site() {
  local site="$1"
  phase="Site pruefen/anlegen: $site"
  printf '[setup] %s\n' "$phase"
  if [[ ! -f "sites/$site/site_config.json" ]]; then
    bench new-site "$site" --db-root-username root \
      --db-root-password "$DB_ROOT_PASSWORD" --admin-password "$ADMIN_PASSWORD" \
      --mariadb-user-host-login-scope='%'
  else
    printf '[setup] Site-Konfiguration vorhanden; pruefe im naechsten Schritt den Datenbankzugriff.\n'
  fi
}
ensure_app() {
  local site="$1" app="$2" installed present result
  phase="Installierte Apps abfragen: $site ($app)"
  printf '[setup] %s\n' "$phase"
  # stdout is JSON on success, but Bench may put an exception on stdout on failure.
  # Keep stderr live and explicitly restore captured stdout when the command fails.
  if installed="$(bench --site "$site" list-apps --format json)"; then
    :
  else
    result=$?
    printf '[setup] list-apps fehlgeschlagen (Exit-Code %s):\n%s\n' "$result" "$installed" >&2
    return "$result"
  fi
  if present="$(python -c 'import json,sys; data=json.load(sys.stdin); print("yes" if sys.argv[2] in data[sys.argv[1]] else "no")' "$site" "$app" <<< "$installed")"; then
    :
  else
    result=$?
    printf '[setup] list-apps lieferte kein erwartetes JSON:\n%s\n' "$installed" >&2
    return "$result"
  fi
  phase="App installieren/pruefen: $site ($app)"
  if [[ "$present" != yes ]]; then
    printf '[setup] Installiere %s auf %s.\n' "$app" "$site"
    bench --site "$site" install-app "$app"
  else
    printf '[setup] %s ist bereits auf %s installiert.\n' "$app" "$site"
  fi
}
ensure_site "$ERP_SITE"
ensure_app "$ERP_SITE" erpnext
ensure_app "$ERP_SITE" hrms
phase="Scheduler aktivieren: $ERP_SITE"
printf '[setup] %s\n' "$phase"
bench --site "$ERP_SITE" enable-scheduler
ensure_site "$SUITE_SITE"
ensure_app "$SUITE_SITE" suite
phase="Scheduler aktivieren: $SUITE_SITE"
printf '[setup] %s\n' "$phase"
bench --site "$SUITE_SITE" enable-scheduler
phase='Fertig'
printf '[setup] ERFOLG: Sites und Apps eingerichtet. Zugang: Administrator mit ADMIN_PASSWORD.\n'
