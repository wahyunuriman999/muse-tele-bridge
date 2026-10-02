#!/usr/bin/env bash
# telegram-monitor.sh — fallback watchdog for muse-tele-bridge.
#
# Why this exists: the bridge's event-hook workers can silently stop
# completing (observed after a runtime restart: 6+ wakes, zero replies,
# zero offset advances). When that happens, messages pile up unanswered
# with no visible error. This script detects that condition so you (or a
# scheduled job) can intervene before messages go stale.
#
# Usage:
#   telegram-monitor.sh            # human-readable report, exit 0/1
#   telegram-monitor.sh --quiet    # prints only pending update_ids
#
# Recommended: run every 2 minutes via your scheduler. If it reports
# pending messages, reply manually (see README "Troubleshooting") and
# advance the offset past them.
#
# Reads ~/.config/muse-tele-bridge/config (TELEGRAM_BOT_TOKEN,
# ALLOWED_USER_ID) and ~/hooks/state/telegram-inbox.json (offset).
# Never prints the token.
set -euo pipefail

CONFIG_FILE="$HOME/.config/muse-tele-bridge/config"
STATE_FILE="$HOME/hooks/state/telegram-inbox.json"
LOCK_FILE="$HOME/hooks/state/telegram-inbox.lock"
QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

# shellcheck disable=SC1090
source "$CONFIG_FILE" 2>/dev/null || {
  echo "monitor: config not found: $CONFIG_FILE" >&2; exit 2; }
: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN not set}"
: "${ALLOWED_USER_ID:?ALLOWED_USER_ID not set}"

OFFSET="$(jq -r '.offset // 0' "$STATE_FILE" 2>/dev/null || echo 0)"
RESP="$(curl -s --fail --max-time 20 \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=10" \
  2>/dev/null)" || {
  [[ $QUIET -eq 0 ]] && echo "monitor: FETCH FAILED — cannot reach Telegram API (network down?)"
  exit 3; }

PENDING="$(printf '%s' "$RESP" | jq -c --argjson uid "$ALLOWED_USER_ID" \
  '[.result[]
    | select(.message != null and (.message.from.id | tostring) == ($uid | tostring))
    | {update_id, type: (.message.text // .message.caption // "[media]" | tostring | .[0:80])}]')"

N="$(printf '%s' "$PENDING" | jq 'length')"

LOCK_INFO="no lock"
if [[ -f "$LOCK_FILE" ]]; then
  AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE") ))
  LOCK_INFO="lock age ${AGE}s"
  if [[ "$AGE" -ge 300 ]]; then
    LOCK_INFO="$LOCK_INFO (STALE — a worker died; next hook poll will redeliver)"
  else
    LOCK_INFO="$LOCK_INFO (fresh — a worker may be processing)"
  fi
fi

if [[ "$N" -eq 0 ]]; then
  [[ $QUIET -eq 0 ]] && echo "monitor: OK — no pending messages (offset $OFFSET, $LOCK_INFO)"
  exit 0
fi

if [[ $QUIET -eq 1 ]]; then
  printf '%s' "$PENDING" | jq -r '.[].update_id'
  exit 1
fi

echo "monitor: ATTENTION — $N unanswered message(s) (offset $OFFSET, $LOCK_INFO):"
printf '%s' "$PENDING" | jq -r '.[] | "  update_id=\(.update_id) :: \(.type)"'
echo "If a worker is not actively processing, reply manually via sendMessage,"
echo "then advance the offset past the newest update_id:"
echo "  echo '{\"offset\":<newest_update_id+1>}' > $STATE_FILE"
exit 1
