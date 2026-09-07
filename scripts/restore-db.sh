#!/usr/bin/env bash
set -euo pipefail
if [[ $# != 2 ]]; then echo 'Usage: scripts/restore-db.sh backup.dump NEW_DATABASE_NAME' >&2; exit 2; fi
[[ "$2" =~ ^restore_[a-zA-Z0-9_]+$ ]] || { echo 'Target must start with restore_ and contain only letters, digits and underscores.' >&2; exit 2; }
# Always restore to a new database. Never overwrite the running marketplace.
docker compose exec -T db createdb -U user "$2"
docker compose exec -T db pg_restore -U user --exit-on-error --no-owner -d "$2" < "$1"
