#!/bin/sh
set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
project_dir="$(dirname "$script_dir")"
cd "$project_dir"

echo "*** Restore data/backups/config.tar -> CUPS ***"

if [ ! -f data/backups/config.tar ]; then
  echo "No backup is available to restore." >&2
  exit 1
fi

printf "Restore the saved CUPS configuration? [y/N] "
read -r input

case "$input" in
  y|Y|yes|YES)
    docker compose exec -T app tar -C / -xf /backups/config.tar
    docker compose restart app
    echo "Restore success."
    ;;
  *)
    echo "Cancelled."
    exit 1
    ;;
esac
