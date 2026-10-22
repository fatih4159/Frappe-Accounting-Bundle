#!/usr/bin/env bash
set -euo pipefail
[[ "$ERP_SITE" != "$SUITE_SITE" ]] || { echo 'ERP_SITE und SUITE_SITE muessen verschieden sein.' >&2; exit 1; }
for site in "$ERP_SITE" "$SUITE_SITE"; do
  [[ "$site" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || { echo 'Ungueltiger Site-Name.' >&2; exit 1; }
done

ensure_site() {
  local site="$1"
  if [[ ! -f "sites/$site/site_config.json" ]]; then
    bench new-site "$site" --db-root-username root \
      --db-root-password "$DB_ROOT_PASSWORD" --admin-password "$ADMIN_PASSWORD" \
      --mariadb-user-host-login-scope='%'
  fi
}
ensure_app() {
  local site="$1" app="$2" installed present
  installed="$(bench --site "$site" list-apps --format json)"
  present="$(python -c 'import json,sys; data=json.load(sys.stdin); print("yes" if sys.argv[2] in data[sys.argv[1]] else "no")' "$site" "$app" <<< "$installed")"
  if [[ "$present" != yes ]]; then
    bench --site "$site" install-app "$app"
  fi
}
ensure_site "$ERP_SITE"
ensure_app "$ERP_SITE" erpnext
ensure_app "$ERP_SITE" hrms
bench --site "$ERP_SITE" enable-scheduler
ensure_site "$SUITE_SITE"
ensure_app "$SUITE_SITE" suite
bench --site "$SUITE_SITE" enable-scheduler
echo 'Sites und Apps eingerichtet. Zugang: Administrator und ADMIN_PASSWORD aus .env.'
