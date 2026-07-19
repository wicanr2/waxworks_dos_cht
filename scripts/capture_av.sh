#!/bin/bash
# 用法: capture_av.sh <輸出mp4> <秒數> <按鍵腳本檔(容器內路徑,選填)>
set -e
PROJ="/home/anr2/scummvm/waxworks/workplace"
OUT="${1:-promo_raw.mp4}"; SECS="${2:-30}"; KEYS="${3:-}"
mkdir -p "$PROJ/promo"
docker run --rm -v "$PROJ:/work" -w /work waxworks-capture bash -c '
  set -e
  export XDG_RUNTIME_DIR=/tmp/xdg; mkdir -p /tmp/xdg
  # PulseAudio 使用者模式 + null sink
  pulseaudio -D --exit-idle-time=-1 --disallow-exit 2>/dev/null || true
  sleep 1
  pactl load-module module-null-sink sink_name=v sink_properties=device.description=v >/dev/null
  pactl set-default-sink v
  export SDL_AUDIODRIVER=pulseaudio
  export PULSE_SINK=v
  # X 顯示
  Xvfb :99 -screen 0 640x400x16 &>/dev/null & sleep 2
  export DISPLAY=:99
  cd /work/run_game
  /work/build/scummvm-src/scummvm -p /work/run_game --auto-detect -e mt32 \
     --extrapath=/work/run_game --gfx-mode=1x --no-aspect-ratio \
     --music-volume=255 --boot-param=0 &>/work/promo/scummvm.log &
  SPID=$!
  sleep 3
  # ffmpeg 同步錄 X11 影像 + pulse 音訊
  ffmpeg -y -loglevel error \
     -f x11grab -framerate 15 -video_size 640x400 -i :99 \
     -f pulse -i v.monitor \
     -t '"$SECS"' -c:v libx264 -pix_fmt yuv420p -preset veryfast \
     -c:a aac -b:a 192k /work/promo/'"$OUT"' &
  FPID=$!
  # 按鍵腳本(在錄製期間跑)
  KEYS="'"$KEYS"'"
  if [ -n "$KEYS" ] && [ -f "$KEYS" ]; then bash "$KEYS" || true; fi
  wait $FPID
  kill $SPID 2>/dev/null || true
  chown -R '"$(id -u):$(id -g)"' /work/promo 2>/dev/null || true
'
