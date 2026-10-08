#!/usr/bin/env bash
# Download every bucket in every Vultr Object Storage subscription on the account.
# Copy only: nothing on Vultr is changed or deleted.
#
# Usage: VULTR_API_KEY=... ./vultr-download.sh [destination-dir]
# Needs: curl, jq, rclone

set -euo pipefail

: "${VULTR_API_KEY:?Set VULTR_API_KEY}"
DEST="${1:-./vultr-files}"

for cmd in curl jq rclone; do
  command -v "$cmd" >/dev/null || { echo "Missing: $cmd" >&2; exit 1; }
done

subs=$(curl -fsS -H "Authorization: Bearer $VULTR_API_KEY" \
  "https://api.vultr.com/v2/object-storage?per_page=500")

count=$(jq '.object_storages | length' <<<"$subs")
echo "Found $count Object Storage subscription(s)"

jq -c '.object_storages[]' <<<"$subs" | while read -r sub; do
  id=$(jq -r '.id' <<<"$sub")
  label=$(jq -r '.label // empty' <<<"$sub")

  # Read by rclone for the on-the-fly :s3: remote; kept out of argv.
  export RCLONE_S3_PROVIDER=Other
  export RCLONE_S3_ENDPOINT=$(jq -r '.s3_hostname' <<<"$sub")
  export RCLONE_S3_ACCESS_KEY_ID=$(jq -r '.s3_access_key' <<<"$sub")
  export RCLONE_S3_SECRET_ACCESS_KEY=$(jq -r '.s3_secret_key' <<<"$sub")

  target="$DEST/${label:-$id}"
  echo "== ${label:-$id} ($RCLONE_S3_ENDPOINT) -> $target"

  rclone lsf --dirs-only :s3: | while read -r bucket; do
    bucket=${bucket%/}
    echo "-- $bucket"
    rclone copy ":s3:$bucket" "$target/$bucket" --progress </dev/null
  done
done

echo "Done: $DEST"
