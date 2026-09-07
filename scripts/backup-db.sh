#!/usr/bin/env bash
set -euo pipefail
if [[ $# != 1 ]]; then echo 'Usage: scripts/backup-db.sh /secure/path/backup.dump' >&2; exit 2; fi
umask 077
# noclobber prevents an accidental overwrite of an existing backup.
set -o noclobber
docker compose exec -T db pg_dump -U user -d marketplace -Fc > "$1"
