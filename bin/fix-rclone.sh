#!/usr/bin/env bash
# icloudpd --auth-only -u zack@bartel.com

set -euo pipefail

SOURCE_FILE="${HOME}/.pyicloud/zackbartelcom"
RCLONE_CONF="${HOME}/.config/rclone/rclone.conf"
BACKUP="/tmp/rclone.conf.$(date +%Y%m%d-%H%M%S).bak"

err() {
  echo "ERROR: $*" >&2
  exit 1
}

# Check existence
[ -f "$SOURCE_FILE" ] || err "Source ${SOURCE_FILE} not found."
[ -f "$RCLONE_CONF" ] || err "rclone-config ${RCLONE_CONF} not found."

cookies_value="$(
  grep 'X-APPLE' "$SOURCE_FILE" \
    | cut -d: -f2- \
    | cut -d';' -f1 \
    | sed 's/\\//g ; s/"//g' \
    | tr '\n' ';' \
    | tr -d ' ' \
    || true
)"

[ -n "$cookies_value" ] || err "cookies-Wert could not be fetched."

trust_token_value="$(
  grep 'X-APPLE-WEBAUTH-HSA-TRUST' "$SOURCE_FILE" \
    | cut -d= -f2- \
    | cut -d';' -f1 \
    | sed 's/\\//g ; s/"//g' \
    | cut -d_ -f2 \
    || true
)"

[ -n "$trust_token_value" ] || err "trust_token-Wert could not be fetched."

# Backup rclone.conf
cp "$RCLONE_CONF" "$BACKUP" || err "Backup could not be created."

# tmp-file for new rclone.conf
tmpfile="$(mktemp)"

# replace lines in rclone.conf
awk -v cookie="$cookies_value" -v trust="$trust_token_value" '
/^[[:space:]]*cookies[[:space:]]*=/ {
  print "cookies = " cookie
  next
}
/^[[:space:]]*trust_token[[:space:]]*=/ {
  print "trust_token = " trust
  next
}
{ print }
' "$RCLONE_CONF" > "$tmpfile"

mv "$tmpfile" "$RCLONE_CONF"

echo "Ready."
echo "Backup created in: $BACKUP"
echo "New values inserted in ${RCLONE_CONF}."
