#!/bin/bash
# 用法: capture.sh <boot_param> <秒數> <輸出前綴> [按鍵腳本]
set -e
PROJ="/home/anr2/scummvm/waxworks/workplace"
GAMEDIR="$PROJ/run_game"
BOOT="${1:-0}"; SECS="${2:-8}"; OUT="${3:-shot}"
mkdir -p "$PROJ/screenshots"
docker run --rm -v "$PROJ:/work" -w /work waxworks-build bash -c "
  export XDG_RUNTIME_DIR=/tmp/xdg; mkdir -p /tmp/xdg
  Xvfb :99 -screen 0 640x400x8 &>/dev/null & sleep 2
  export DISPLAY=:99
  cd /work/run_game
  /work/build/scummvm-src/scummvm -p /work/run_game --auto-detect \
     --gfx-mode=1x --no-aspect-ratio -e null --boot-param=$BOOT &>/work/screenshots/${OUT}.log &
  SPID=\$!
  sleep $SECS
  for i in 1 2 3 4 5 6; do
    import -window root /work/screenshots/${OUT}_\$i.png 2>/dev/null || xwd -root -silent | convert xwd:- /work/screenshots/${OUT}_\$i.png 2>/dev/null || true
    ${4:-true}
    sleep 2
  done
  kill \$SPID 2>/dev/null || true
  chown -R $(id -u):$(id -g) /work/screenshots 2>/dev/null || true
"
