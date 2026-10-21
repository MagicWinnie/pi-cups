#!/bin/sh
set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
project_dir="$(dirname "$script_dir")"
cd "$project_dir"

echo "*** Backup CUPS -> data/backups/config.tar ***"

if docker compose exec -T app tar -C / -cf /backups/config.tar etc/cups; then
  echo "Backup success."
else
  echo "Backup failed." >&2
  exit 1
fi
