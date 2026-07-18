#!/bin/bash
set -e
PROJ="/home/anr2/scummvm/waxworks/workplace"
docker run --rm -v "$PROJ:/work" -w /work waxworks-build bash -c '
  FONT=$(find /usr/share/fonts -iname "*NotoSansCJK*Regular*" -o -iname "*NotoSansCJKtc*" 2>/dev/null | head -1)
  [ -z "$FONT" ] && FONT=$(find /usr/share/fonts -iname "*NotoSans*CJK*" | head -1)
  echo "font: $FONT"
  python3 tools/build_cjk_font.py --size 16 --font "$FONT" --out fonts/waxworks_zh16.dcjk
  python3 tools/build_cjk_font.py --size 24 --font "$FONT" --out fonts/waxworks_zh24.dcjk
  chown '"$(id -u):$(id -g)"' fonts/waxworks_zh16.dcjk fonts/waxworks_zh24.dcjk 2>/dev/null || true
'
