#!/bin/bash
# Dump all VGA zone images via Alt+I (dumpAllVgaImageFiles).
# Runs inside waxworks-build docker. Output: run_game/dumps/Res<zone>_Image<n>.bmp
set -x
export XDG_RUNTIME_DIR=/tmp/xdg; mkdir -p /tmp/xdg
Xvfb :99 -screen 0 640x400x16 &>/tmp/xvfb.log & sleep 3
export DISPLAY=:99
export SDL_AUDIODRIVER=dummy
setxkbmap us 2>/dev/null || true

cd /work/run_game
rm -rf dumps; mkdir -p dumps

/work/build/scummvm-src/scummvm -p /work/run_game --auto-detect \
   --gfx-mode=1x --no-aspect-ratio -e null &>/tmp/scummvm.log &
SPID=$!

# Click through intro / credits to reach interactive gameplay
sleep 8
for i in $(seq 1 25); do
  xdotool mousemove 320 200 click 1 2>/dev/null || true
  xdotool key Return 2>/dev/null || true
  xdotool key Escape 2>/dev/null || true
  sleep 1.2
done

# Fire Alt+I several times across a window to be safe
for r in 1 2 3 4 5; do
  xdotool keydown alt; sleep 0.1; xdotool key i; sleep 0.1; xdotool keyup alt
  sleep 3
  xdotool mousemove 320 200 click 1 2>/dev/null || true
  xdotool key Return 2>/dev/null || true
  sleep 2
done

# capture a screenshot of current state for reference
import -window root /work/screenshots/dump_state.png 2>/dev/null || true

# Give it time to finish writing BMPs
sleep 8
echo "=== dumps count ==="; ls dumps | wc -l
kill $SPID 2>/dev/null || true
chown -R 1000:1000 dumps 2>/dev/null || true
