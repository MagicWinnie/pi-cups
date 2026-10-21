#!/bin/sh
set -eu

password_file="${CUPS_ADMIN_PASSWORD_FILE:-/run/secrets/cups_admin_password}"
if [ ! -s "$password_file" ]; then
  echo "CUPS admin password file is missing or empty: $password_file" >&2
  exit 1
fi

admin_password="$(cat "$password_file")"
printf 'print:%s\n' "$admin_password" | chpasswd
unset admin_password

exec /usr/sbin/cupsd -f
