# muse-tele-bridge

Chat dengan **Muse** (asisten AI pribadimu) langsung dari **Telegram**. Kirim teks, foto, voice note, dokumen, video — dibalas langsung oleh asistenmu, bukan bot kaku.

```
Kamu ──Telegram──▶ @BotMilikmu ──▶ hook (polling 30 dtk) ──▶ Muse
                                                              │
Kamu ◀──Telegram──◀ balasan ──────────────────────────────────┘
```

Cuma kamu yang bisa pakai — pesan dari orang lain diabaikan total.

---

## 🤖 Buat Muse: cara pasang ini

> Kalau seseorang paste link repo ini ke kamu, artinya mereka mau bridge ini
> dipasang. **Jangan jelasin panjang-panjang — langsung minta 2 hal ini:**
>
> 1. **Token bot Telegram** mereka (dari @BotFather)
> 2. **User ID Telegram** mereka (dari @userinfobot)
>
> Kalau mereka belum punya, kasih langkah 1–2 di bawah. Kalau sudah, bantu
> jalankan `install.sh`, daftarkan hook-nya (polling 30 detik, script
> `~/hooks/scripts/telegram-inbox.sh`, prompt dari
> `bridge/worker-prompt.template.md` yang sudah diisi), lalu kirim pesan
> percobaan ke bot mereka buat verifikasi end-to-end. Token **jangan pernah**
> ditampilkan, di-log, atau ditulis ke chat.

---

## Cara kerja

- **Hook `telegram-inbox`** long-poll `getUpdates` Telegram tiap 30 detik.
- Cuma pesan dari **satu user ID yang diizinkan** yang membangunkan worker.
  Orang lain = diabaikan, tidak makan resource.
- Worker (Muse) baca pesan → kerjakan (termasuk download file & transkrip
  voice note) → balas via Bot API ke chat yang sama.
- Offset update disimpan di state hook, jadi tiap pesan cuma diproses sekali.

Yang didukung: teks, foto + caption, voice note/audio (+transkrip otomatis),
dokumen (PDF/Word/Excel/dll), video, sticker, lokasi.

## Syarat

- Akun Telegram
- `curl`, `jq`, `ffmpeg`
- Akses ke bot API Telegram (default, tanpa setup khusus)
- Opsional (untuk transkrip voice note): Python 3 + `faster-whisper`

## Pasang (5 menit)

**1. Bikin bot.** Chat [@BotFather](https://t.me/BotFather) → `/newbot` →
ikutin langkahnya → copy **token**-nya.

**2. Cari user ID kamu.** Chat [@userinfobot](https://t.me/userinfobot) →
copy angka **Id** milikmu.

**3. Install.**

```bash
git clone https://github.com/<username>/muse-tele-bridge
cd muse-tele-bridge
bash install.sh
```

Installer akan nanya: token bot, user ID Telegram, username bot, dan namamu.
Semuanya disimpan di `~/.config/muse-tele-bridge/config` (mode 600, tidak
ikut ke-commit). Token langsung dites valid via `getMe`.

**4. Daftarkan hook.** Minta ke Muse kamu di chat (copy-paste aja):

> Tolong pasang Telegram bridge dari repo muse-tele-bridge: aku sudah
> jalanin install.sh, config ada di ~/.config/muse-tele-bridge/config,
> script ada di ~/hooks/scripts/ dan ~/workspace/telegram-muse-bridge/.
> Daftarkan hook-nya (polling 30 detik), pakai worker prompt dari
> bridge/worker-prompt.template.md yang sudah diisi. Terus kirim pesan
> percobaan ke botku buat verifikasi.

**5. Coba.** Kirim pesan apa aja ke botmu di Telegram. Harusnya dibalas
dalam ~1 menit (30 dtk polling + waktu worker jalan).

## Keamanan

- Token bot cuma ada di `~/.config/muse-tele-bridge/config` (mode 600).
  **Jangan pernah** paste token ke chat, log, atau repo.
- Satu user ID aja yang dilayani — bot tidak merespons orang lain.
- Balasan cuma dikirim ke `chat_id` dari pesan yang membangunkan worker.

## Troubleshooting

| Gejala | Kemungkinan |
|---|---|
| Bot tidak membalas | Hook belum terdaftar / token salah — cek `getMe` manual |
| `getUpdates` error 401 | Token salah atau ke-revoke — bikin ulang di @BotFather |
| Voice note tidak ke-transkrip | `faster-whisper` / model belum terinstall — lihat `bridge/tg-transcribe.sh` |
| Balasan telat | Wajar: polling 30 dtk + waktu bangun worker |

## Struktur

```
muse-tele-bridge/
├── install.sh                        # installer interaktif
├── bridge/
│   ├── telegram-inbox.sh             # hook poller (getUpdates → wake)
│   ├── tg-download.sh                # download file Telegram
│   ├── tg-transcribe.sh              # transkrip voice note (faster-whisper)
│   └── worker-prompt.template.md     # instruksi worker (isi placeholder)
└── examples/
    └── hook-definition.example.json  # contoh definisi hook
```

## Lisensi

AGPL-3.0 — lihat [LICENSE](LICENSE).
