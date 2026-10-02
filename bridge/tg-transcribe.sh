#!/usr/bin/env bash
# Transcribe a Telegram voice note (.ogg opus) to text (stdout).
# Usage: tg-transcribe.sh <input.ogg> [language]
# Default language: Indonesian ("id").
#
# Requirements (installed once, see README):
#   - ffmpeg
#   - Python 3 with faster-whisper + numpy
#   - A faster-whisper model directory
#
# Configure via ~/.config/muse-tele-bridge/config :
#   STT_PYTHON="$HOME/.venvs/stt/bin/python"   # python with faster-whisper
#   STT_MODEL_DIR="$HOME/.venvs/stt-models/faster-whisper-base"
set -euo pipefail
IN="${1:?input file required}"
LANG="${2:-id}"
# shellcheck disable=SC1090
source "$HOME/.config/muse-tele-bridge/config" 2>/dev/null || true
STT_PYTHON="${STT_PYTHON:-$HOME/.venvs/stt/bin/python}"
STT_MODEL_DIR="${STT_MODEL_DIR:-$HOME/.venvs/stt-models/faster-whisper-base}"
if [[ ! -x "$STT_PYTHON" ]]; then
  echo "tg-transcribe: STT_PYTHON not found: $STT_PYTHON" >&2
  exit 1
fi
if [[ ! -d "$STT_MODEL_DIR" ]]; then
  echo "tg-transcribe: STT_MODEL_DIR not found: $STT_MODEL_DIR" >&2
  exit 1
fi
WAV="/tmp/tg_stt_$$.wav"
ffmpeg -y -loglevel error -i "$IN" -ar 16000 -ac 1 "$WAV"
"$STT_PYTHON" - "$WAV" "$LANG" << 'EOF'
import os, sys, wave
import numpy as np
from faster_whisper import WhisperModel
# Read the 16kHz mono wav directly (avoids faster-whisper/PyAV version clash)
with wave.open(sys.argv[1], 'rb') as w:
    audio = (np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
             .astype(np.float32) / 32768.0)
model = WhisperModel(os.environ["STT_MODEL_DIR"],
                     device="cpu", compute_type="int8")
segments, _info = model.transcribe(audio, language=sys.argv[2], beam_size=5)
print(" ".join(s.text.strip() for s in segments))
EOF
rm -f "$WAV"
