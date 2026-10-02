#!/usr/bin/env bash
# muse-tele-bridge installer — interactive setup.
# Asks for the secrets only YOU can provide (bot token, your Telegram
# user ID), writes them to a 600 config file, and installs the bridge
# scripts. It never prints your token.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/muse-tele-bridge"
CONFIG_FILE="$CONFIG_DIR/config"
BRIDGE_DIR="$HOME/workspace/telegram-muse-bridge"
HOOK_SCRIPT_DIR="$HOME/hooks/scripts"

echo "=== muse-tele-bridge installer ==="
echo
echo "You need two things from Telegram (takes 2 minutes):"
echo "  1. Bot token  — chat @BotFather, /newbot, copy the token."
echo "  2. Your user ID — chat @userinfobot, copy the 'Id' number."
echo

read -rsp "Bot token (input hidden): " BOT_TOKEN
echo
[[ -z "$BOT_TOKEN" ]] && { echo "Token cannot be empty." >&2; exit 1; }

read -rp "Your Telegram user ID: " USER_ID
[[ -z "$USER_ID" ]] && { echo "User ID cannot be empty." >&2; exit 1; }

read -rp "Bot @username (for the /start greeting, e.g. @MyMuse_bot): " BOT_USERNAME
read -rp "Your name (how the worker should address you): " OWNER_NAME
BOT_USERNAME="${BOT_USERNAME:-@MyMuse_bot}"
OWNER_NAME="${OWNER_NAME:-there}"

mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_FILE" << EOF
# muse-tele-bridge config — mode 600. Never commit this file.
TELEGRAM_BOT_TOKEN="$BOT_TOKEN"
ALLOWED_USER_ID="$USER_ID"
BOT_USERNAME="$BOT_USERNAME"
OWNER_NAME="$OWNER_NAME"
# Optional: voice-note transcription (defaults shown)
# STT_PYTHON="\$HOME/.venvs/stt/bin/python"
# STT_MODEL_DIR="\$HOME/.venvs/stt-models/faster-whisper-base"
EOF
chmod 600 "$CONFIG_FILE"
echo "Wrote $CONFIG_FILE (mode 600)."

mkdir -p "$BRIDGE_DIR" "$HOOK_SCRIPT_DIR"
cp "$REPO_DIR/bridge/tg-download.sh" "$REPO_DIR/bridge/tg-transcribe.sh" \
   "$REPO_DIR/bridge/telegram-monitor.sh" "$BRIDGE_DIR/"
cp "$REPO_DIR/bridge/telegram-inbox.sh" "$HOOK_SCRIPT_DIR/"
chmod +x "$BRIDGE_DIR"/tg-*.sh "$BRIDGE_DIR"/telegram-monitor.sh \
         "$HOOK_SCRIPT_DIR/telegram-inbox.sh"
echo "Installed helpers to $BRIDGE_DIR"
echo "Installed hook script to $HOOK_SCRIPT_DIR/telegram-inbox.sh"
echo

# Sanity-check the token (without printing it).
if curl -s --fail --max-time 15 "https://api.telegram.org/bot${BOT_TOKEN}/getMe" \
    | grep -q '"ok":true'; then
  echo "Token OK — bot is reachable."
else
  echo "WARNING: the token did not validate (getMe failed)." >&2
  echo "Double-check it with @BotFather; you can re-run this installer." >&2
fi

echo
echo "=== Next step: register the hook ==="
echo "Paste this to your Muse in chat:"
echo
cat << 'MSG'
Please set up my Telegram bridge from https://github.com/wahyunuriman999/muse-tele-bridge :
1. I already ran install.sh — config is at ~/.config/muse-tele-bridge/config
   and scripts are in ~/hooks/scripts/ + ~/workspace/telegram-muse-bridge/.
2. Register an event hook from ~/hooks/scripts/telegram-inbox.sh that polls
   every 30 seconds and wakes a worker on my messages.
3. Use bridge/worker-prompt.template.md for the worker prompt, filling in
   BOT_USERNAME, OWNER_NAME, BRIDGE_DIR and CONFIG_FILE from my config.
4. Send me a Telegram message to verify end-to-end.
MSG
