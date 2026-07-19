#!/bin/bash
set -e
PROJ="/home/anr2/scummvm/waxworks/workplace"
mkdir -p "$PROJ/screenshots/cheat"
docker run --rm -v "$PROJ:/work" -w /work waxworks-build bash -c '
  export XDG_RUNTIME_DIR=/tmp/xdg; mkdir -p /tmp/xdg; export SDL_AUDIODRIVER=dummy
  Xvfb :99 -screen 0 640x400x16 &>/dev/null & sleep 2; export DISPLAY=:99
  cd /work/run_game
  /work/build/scummvm-src/scummvm -p /work/run_game --auto-detect --gfx-mode=1x --no-aspect-ratio -e null --boot-param=0 &>/work/screenshots/cheat.log &
  SPID=$!
  sleep 5
  # 過 credits + 前廳整段腳本對白: 狂點對白框推進
  for i in $(seq 1 34); do xdotool mousemove 320 380 click 1 2>/dev/null; sleep 2; done
  import -window root /work/screenshots/cheat/A_control.png 2>/dev/null || true
  # 走一步(前進箭頭)換到有出口的房間, 讓地圖有東西
  xdotool mousemove 40 255 click 1; sleep 2
  import -window root /work/screenshots/cheat/A2_moved.png 2>/dev/null || true
  xdotool key --clearmodifiers Tab; sleep 1
  import -window root /work/screenshots/cheat/B_map.png 2>/dev/null || true
  xdotool key --clearmodifiers F8; sleep 1
  import -window root /work/screenshots/cheat/C_fogoff.png 2>/dev/null || true
  xdotool key --clearmodifiers F6; sleep 1
  import -window root /work/screenshots/cheat/D_give.png 2>/dev/null || true
  xdotool key --clearmodifiers F7; sleep 1
  import -window root /work/screenshots/cheat/E_god.png 2>/dev/null || true
  kill $SPID 2>/dev/null || true
  chown -R '"$(id -u):$(id -g)"' /work/screenshots 2>/dev/null || true
'
