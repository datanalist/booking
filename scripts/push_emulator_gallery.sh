#!/usr/bin/env bash
# Puts the profile sample photo into the emulator gallery (not into app assets).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/images/profile/avatar.png"
DEST="/sdcard/Pictures/globalstay_profile.png"
DEVICE="${1:-}"

if [[ ! -f "$SRC" ]]; then
  echo "missing $SRC" >&2
  exit 1
fi

ADB=(adb)
if [[ -n "$DEVICE" ]]; then
  ADB=(adb -s "$DEVICE")
fi

"${ADB[@]}" wait-for-device
"${ADB[@]}" push "$SRC" "$DEST"
"${ADB[@]}" shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://$DEST" >/dev/null || true
echo "gallery: $DEST"
