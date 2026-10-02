#!/usr/bin/env bash
# Telegram inbox poller — wakes your Muse agent when YOU send a new message.
#
# Long-polls getUpdates and wakes an agent ONLY when the allowed Telegram
# user sent a new message: text, photo, voice/audio, document, video,
# video note, sticker, or location. Everything else stays silent, so no
# agent turn is spent while idle.
#
# Protocol: ends with exactly one silent/wake. State (update offset) lives in
# the hook state dir; hook_state_set skips writes on dry runs, so testing
# never consumes a detection.
#
# Configuration is read from ~/.config/muse-tele-bridge/config :
#   TELEGRAM_BOT_TOKEN="123456:ABC..."
#   ALLOWED_USER_ID="123456789"
set -euo pipefail
source "$HATCH_HOOK_RUNTIME"

CONFIG_FILE="$HOME/.config/muse-tele-bridge/config"
if [[ ! -f "$CONFIG_FILE" ]]; then
  log "telegram-inbox: config file missing ($CONFIG_FILE)" '{}'
  silent "config file missing" '{}'
fi
# shellcheck disable=SC1090
source "$CONFIG_FILE"

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
  log "telegram-inbox: TELEGRAM_BOT_TOKEN empty" '{}'
  silent "token empty" '{}'
fi
if [[ -z "${ALLOWED_USER_ID:-}" ]]; then
  log "telegram-inbox: ALLOWED_USER_ID empty" '{}'
  silent "allowed user id empty" '{}'
fi

API="https://api.telegram.org"
OFFSET="$(hook_state_get | jq -r '.offset // 0')"

RESP="$(curl -s --fail --max-time 45 \
  "${API}/bot${TELEGRAM_BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=25" 2>/dev/null)" || {
  log "telegram-inbox: getUpdates fetch failed" '{}'
  silent "fetch failed" '{}'
}

if [[ "$(printf '%s' "$RESP" | jq -r '.ok // false')" != "true" ]]; then
  ERR_CODE="$(printf '%s' "$RESP" | jq -r '.error_code // 0')"
  DESC="$(printf '%s' "$RESP" | jq -r '.description // "unknown"')"
  log "telegram-inbox: API error" "$(jq -cn --argjson c "$ERR_CODE" --arg d "$DESC" '{code:$c,desc:$d}')"
  silent "api error" "{\"code\":${ERR_CODE}}"
fi

COUNT="$(printf '%s' "$RESP" | jq '.result | length')"
if [[ "$COUNT" -eq 0 ]]; then
  silent "no updates" '{}'
fi

# Advance past everything seen (dry-run safe: write skipped when dry).
MAX_ID="$(printf '%s' "$RESP" | jq '[.result[].update_id] | max')"
hook_state_set "$(jq -cn --argjson off "$((MAX_ID + 1))" '{offset:$off}')"

# New text, photo, voice, document, video, sticker, or location messages
# from the allowed user only.
NEW_MSGS="$(printf '%s' "$RESP" | jq -c --argjson uid "$ALLOWED_USER_ID" \
  '[.result[]
    | select(.message != null and .message.from.id == $uid
             and (.message.text != null or .message.photo != null
                  or .message.voice != null or .message.audio != null
                  or .message.document != null or .message.video != null
                  or .message.video_note != null or .message.sticker != null
                  or .message.location != null))
    | {message_id: .message.message_id, chat_id: .message.chat.id,
       text: .message.text, caption: .message.caption,
       photo_file_id: (if .message.photo != null
                       then (.message.photo | last | .file_id)
                       else null end),
       voice_file_id: (.message.voice // .message.audio | .file_id // null),
       voice_duration: (.message.voice // .message.audio | .duration // null),
       document_file_id: .message.document.file_id,
       document_name: .message.document.file_name,
       document_mime: .message.document.mime_type,
       video_file_id: (.message.video // .message.video_note | .file_id // null),
       sticker_emoji: .message.sticker.emoji,
       location_lat: .message.location.latitude,
       location_lon: .message.location.longitude,
       date: .message.date}]')"

N="$(printf '%s' "$NEW_MSGS" | jq 'length')"
if [[ "$N" -eq 0 ]]; then
  silent "no new messages from allowed user" "{\"seen\":${COUNT}}"
fi

CHAT_ID="$(printf '%s' "$NEW_MSGS" | jq -r '.[0].chat_id')"
log "telegram-inbox: new message(s) from allowed user" "{\"count\":${N}}"
wake "new Telegram message" \
  "$(jq -cn --argjson cid "$CHAT_ID" --argjson msgs "$NEW_MSGS" \
    '{chat_id:$cid, messages:$msgs}')"
