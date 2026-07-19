#!/bin/bash
# Windows 版: mingw-w64 交叉編 patched ScummVM(AGOS+CHT) + 收齊 DLL + 內含遊戲
# 產出: dist-all/Waxworks-CHT-FULL-win64.zip
set -e
PROJ="/home/anr2/scummvm/waxworks/workplace"
docker run --rm -v "$PROJ:/w" -w /w debian:bookworm-slim bash -c '
  set -e
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq >/dev/null 2>&1
  apt-get install -y -qq g++-mingw-w64-x86-64 mingw-w64-tools g++ make wget tar xz-utils zip \
      libz-mingw-w64-dev ca-certificates file >/dev/null 2>&1
  HOST=x86_64-w64-mingw32
  cd /opt
  wget -q https://github.com/libsdl-org/SDL/releases/download/release-2.30.9/SDL2-devel-2.30.9-mingw.tar.gz
  tar xzf SDL2-devel-2.30.9-mingw.tar.gz
  SDLP=/opt/SDL2-2.30.9/$HOST
  export PATH="$SDLP/bin:$PATH"
  rm -rf /win && cp -r /w/build/scummvm-src /win
  cd /win
  find . -name "*.o" -delete; find . -name "*.a" -delete; rm -f scummvm scummvm.exe config.mk config.log 2>/dev/null || true
  echo "=== configure (mingw, AGOS only) ==="
  ./configure --host=$HOST --disable-all-engines --enable-engine=agos --enable-release \
    --with-sdl-prefix="$SDLP" \
    --disable-mad --disable-vorbis --disable-flac --disable-fluidsynth \
    --disable-mpeg2 --disable-theoradec --disable-faad --disable-libcurl --disable-timidity 2>&1 | tail -8
  grep -q "^ENABLE_AGOS" config.mk || { echo "!! FATAL: agos 未啟用"; exit 1; }
  echo "  ✓ $(grep "^ENABLE_AGOS" config.mk)"
  echo "=== make ==="; make -j$(nproc) 2>&1 | tail -5
  ls -lh scummvm.exe
  STAGE=/w/dist-all/Waxworks-CHT-win64; rm -rf $STAGE; OUT=$STAGE; mkdir -p $OUT/data $OUT/game $OUT/saves
  cp scummvm.exe $OUT/; cp "$SDLP/bin/SDL2.dll" $OUT/
  for d in libgcc_s_seh-1.dll libstdc++-6.dll libwinpthread-1.dll; do
    f=$(find /usr/lib/gcc/$HOST /usr/$HOST -name $d 2>/dev/null | head -1); [ -n "$f" ] && cp "$f" $OUT/
  done
  zdll=$(find /usr/$HOST -iname "zlib1.dll" -o -iname "libz-1.dll" 2>/dev/null | head -1); [ -n "$zdll" ] && cp "$zdll" $OUT/ || true
  cp gui/themes/scummmodern.zip gui/themes/scummclassic.zip gui/themes/scummremastered.zip \
     gui/themes/gui-icons.dat gui/themes/shaders.dat gui/themes/translations.dat \
     dists/engine-data/fonts.dat dists/engine-data/fonts-cjk.dat $OUT/data/
  # MT-32 ROM 也放進 extrapath(data), 供 Munt 模擬器找到 → 原版真實配樂
  cp -L /w/run_game/MT32_CONTROL.ROM /w/run_game/MT32_PCM.ROM $OUT/data/ 2>/dev/null || true
  printf "@echo off\r\ncd /d \"%%~dp0\"\r\nif not exist saves mkdir saves\r\nscummvm.exe -p game --themepath=data --extrapath=data --music-driver=mt32 --auto-detect --savepath=saves\r\npause\r\n" > "$OUT/play-waxworks.bat"
  cp -rL /w/run_game/* $OUT/game/
  echo "=== 相依 DLL ==="; x86_64-w64-mingw32-objdump -p scummvm.exe | grep "DLL Name" | sort -u
  cd /w/dist-all; rm -f Waxworks-CHT-FULL-win64.zip
  ( cd /w/dist-all && zip -rq Waxworks-CHT-FULL-win64.zip Waxworks-CHT-win64 )
  rm -rf $STAGE
  echo "=== 產出 ==="; ls -lh /w/dist-all/Waxworks-CHT-FULL-win64.zip
  chown -R '"$(id -u):$(id -g)"' /w/dist-all 2>/dev/null || true
'
