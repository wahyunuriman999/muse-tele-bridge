#!/usr/bin/env bash
# Download a Telegram file by file_id.
# Usage: tg-download.sh <file_id> <dest_path>
# Reads the bot token from the bridge config (never printed).
set -euo pipefail
FILE_ID="${1:?file_id required}"
DEST="${2:?dest path required}"
# shellcheck disable=SC1090
source "$HOME/.config/muse-tele-bridge/config"
if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
  echo "tg-download: TELEGRAM_BOT_TOKEN not configured" >&2
  exit 1
fi
API="https://api.telegram.org"
FILE_PATH="$(curl -s --fail --max-time 20 "${API}/bot${TELEGRAM_BOT_TOKEN}/getFile" \
  -d "file_id=${FILE_ID}" | jq -r '.result.file_path')"
if [[ -z "$FILE_PATH" || "$FILE_PATH" == "null" ]]; then
  echo "tg-download: getFile failed for file_id" >&2
  exit 1
fi
curl -s --fail --max-time 120 "${API}/file/bot${TELEGRAM_BOT_TOKEN}/${FILE_PATH}" -o "$DEST"
