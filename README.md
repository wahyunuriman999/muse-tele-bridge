# muse-tele-bridge

Chat with **Muse** (your personal AI assistant) directly from **Telegram**. Send text, photos, voice notes, documents, videos — answered directly by your assistant, not a rigid bot.

```
You ──Telegram──▶ @YourBot ──▶ hook (30s polling) ──▶ Muse
                                                          │
You ◀──Telegram──◀ reply ─────────────────────────────────┘
```

Only you can use it — messages from anyone else are fully ignored.

---

## 🤖 For Muse: how to install this

> If someone pastes this repo link to you, they want this bridge installed.
> **Don't over-explain — just ask for these 2 things:**
>
> 1. Their **Telegram bot token** (from @BotFather)
> 2. Their **Telegram user ID** (from @userinfobot)
>
> If they don't have them yet, give steps 1–2 below. If they do, help run
> `install.sh`, register the hook (30-second polling, script
> `~/hooks/scripts/telegram-inbox.sh`, prompt from
> `bridge/worker-prompt.template.md` filled in), then send a test message to
> their bot to verify end-to-end. **Never** display, log, or write the token
> to chat.

---

## How it works

- The **`telegram-inbox` hook** long-polls Telegram `getUpdates` every 30 seconds.
- Only messages from the **single allowed user ID** wake a worker.
  Everyone else is ignored — zero resource spent.
- The worker (Muse) reads the message → does the work (including file
  downloads & voice-note transcription) → replies via the Bot API to the
  same chat.
- Delivery is **at-least-once**: the worker advances the update offset past
  each message only after its reply is confirmed sent (`"ok":true`, with up
  to 3 retries on transient network failure). A processing lock prevents
  double-wakes; a stale lock is cleared so a crashed worker's messages are
  redelivered instead of silently lost. A duplicate reply after a crash is
  possible but a lost reply is not.

Supported: text, photos + captions, voice notes/audio (+auto transcription),
documents (PDF/Word/Excel/etc.), video, stickers, locations.

## Requirements

- A Telegram account
- `curl`, `jq`, `ffmpeg`
- Access to the Telegram Bot API (default, no special setup)
- Optional (voice-note transcription): Python 3 + `faster-whisper`

## Setup (5 minutes)

**1. Create a bot.** Chat [@BotFather](https://t.me/BotFather) → `/newbot` →
follow the steps → copy the **token**.

**2. Find your user ID.** Chat [@userinfobot](https://t.me/userinfobot) →
copy your numeric **Id**.

**3. Install.**

```bash
git clone https://github.com/wahyunuriman999/muse-tele-bridge
cd muse-tele-bridge
bash install.sh
```

The installer asks for: bot token, Telegram user ID, bot username, and your
name. Everything is stored in `~/.config/muse-tele-bridge/config` (mode 600,
never committed). The token is validated immediately via `getMe`.

**4. Register the hook.** Ask your Muse in chat (just copy-paste):

> Please set up my Telegram bridge from the muse-tele-bridge repo: I already
> ran install.sh, config is at ~/.config/muse-tele-bridge/config, scripts are
> in ~/hooks/scripts/ and ~/workspace/telegram-muse-bridge/. Register the
> hook (30-second polling) using the worker prompt from
> bridge/worker-prompt.template.md (filled in). Then send a test message to
> my bot to verify.

**5. Try it.** Send any message to your bot on Telegram. You should get a
reply within ~1 minute (30s polling + worker startup).

## Security

- The bot token lives only in `~/.config/muse-tele-bridge/config` (mode 600).
  **Never** paste it into chat, logs, or the repo.
- Only one user ID is served — the bot never responds to anyone else.
- Replies are only ever sent to the `chat_id` from the message that woke
  the worker.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Bot doesn't reply | Hook not registered / wrong token — verify with `getMe` manually |
| `getUpdates` 401 error | Token wrong or revoked — recreate via @BotFather |
| Voice notes not transcribed | `faster-whisper` / model not installed — see `bridge/tg-transcribe.sh` |
| Slow replies | Normal: 30s polling + worker startup time |

## Layout

```
muse-tele-bridge/
├── install.sh                        # interactive installer
├── bridge/
│   ├── telegram-inbox.sh             # hook poller (getUpdates → wake)
│   ├── tg-download.sh                # Telegram file downloader
│   ├── tg-transcribe.sh              # voice-note transcription (faster-whisper)
│   └── worker-prompt.template.md     # worker instructions (fill placeholders)
└── examples/
    └── hook-definition.example.json  # example hook definition
```

## License

AGPL-3.0 — see [LICENSE](LICENSE).
