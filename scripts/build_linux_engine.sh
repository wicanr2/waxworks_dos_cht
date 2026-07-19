#!/bin/bash
# Linux 引擎包(無遊戲，可公開散佈)：patched ScummVM(AGOS+CHT) + 收 .so + 繁中字型 + 啟動器。
# 使用者自備 Waxworks 原檔放進 game/ 即可玩。產物: dist-all/蠟像館之謎-CHT-linux-x86_64.tar.gz
set -e
PROJ="/home/anr2/scummvm/waxworks/workplace"
[ -f "$PROJ/build/scummvm-src/scummvm" ] || { echo "!! 先 build scummvm"; exit 1; }
docker run --rm -v "$PROJ:/w" -w /w waxworks-build bash -c '
  set -e
  OUT=/tmp/蠟像館之謎-CHT-linux-x86_64; rm -rf "$OUT"
  mkdir -p "$OUT/bin" "$OUT/lib" "$OUT/data" "$OUT/game" "$OUT/saves"
  cp build/scummvm-src/scummvm "$OUT/bin/scummvm"
  # 收非系統 .so
  ldd "$OUT/bin/scummvm" | awk "{print \$3}" | grep -E "^/" | while read lib; do
    case "$lib" in
      *ld-linux*|*libc.so*|*libm.so*|*libpthread*|*libdl.so*|*librt.so*|*libstdc++*|*libgcc_s*) ;;
      *) cp -L "$lib" "$OUT/lib/" 2>/dev/null || true ;;
    esac
  done
  # ScummVM 執行期資料
  cp build/scummvm-src/gui/themes/scummmodern.zip build/scummvm-src/gui/themes/scummclassic.zip \
     build/scummvm-src/gui/themes/scummremastered.zip build/scummvm-src/gui/themes/gui-icons.dat \
     build/scummvm-src/gui/themes/shaders.dat build/scummvm-src/gui/themes/translations.dat \
     build/scummvm-src/dists/engine-data/fonts.dat build/scummvm-src/dists/engine-data/fonts-cjk.dat \
     "$OUT/data/" 2>/dev/null || true
  # 繁中字型(GPL 衍生，可散佈)
  cp run_game/waxworks_zh16.dcjk run_game/waxworks_zh24.dcjk run_game/waxworks_zh.tab "$OUT/game/"
  # 啟動器
  cat > "$OUT/play-waxworks.sh" <<"EOF"
#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
export LD_LIBRARY_PATH="$HERE/lib:$LD_LIBRARY_PATH"
"$HERE/bin/scummvm" -p "$HERE/game" --themepath="$HERE/data" --extrapath="$HERE/game" \
  --savepath="$HERE/saves" --music-driver=mt32 --auto-detect "$@"
EOF
  chmod +x "$OUT/play-waxworks.sh"
  cp docs/如何開始遊玩.txt "$OUT/README.txt" 2>/dev/null || true
  ( cd /tmp && tar czf /w/dist-all/蠟像館之謎-CHT-linux-x86_64.tar.gz "蠟像館之謎-CHT-linux-x86_64" )
  chown -R '"$(id -u):$(id -g)"' /w/dist-all 2>/dev/null || true
  echo "=== 產物 ==="; ls -lh /w/dist-all/蠟像館之謎-CHT-linux-x86_64.tar.gz
'
