#!/bin/bash
# Windows 引擎包(無遊戲，可公開散佈)：從完整版 zip 剝除遊戲原檔與 ROM，只留
# scummvm.exe + DLL + 資料 + 繁中字型 + 啟動器 + README。免重編。
# 需先有 dist-all/Waxworks-CHT-FULL-win64.zip(build_windows.sh 產)。
# 產物: dist-all/蠟像館之謎-CHT-windows-x64.zip
set -e
PROJ="/home/anr2/scummvm/waxworks/workplace"
FULL="$PROJ/dist-all/Waxworks-CHT-FULL-win64.zip"
[ -f "$FULL" ] || { echo "!! 先跑 build_windows.sh 產完整版"; exit 1; }
docker run --rm -v "$PROJ:/w" -w /w waxworks-build bash -c '
  set -e
  T=/tmp/win-engine; rm -rf "$T"; mkdir -p "$T"
  cd "$T"; unzip -q /w/dist-all/Waxworks-CHT-FULL-win64.zip
  SRC=Waxworks-CHT-win64
  OUT=蠟像館之謎-CHT-windows-x64; rm -rf "$OUT"; mkdir -p "$OUT/data" "$OUT/game" "$OUT/saves"
  # 引擎 + DLL + 資料(排除 ROM)
  cp "$SRC"/*.exe "$SRC"/*.dll "$OUT/"
  for f in "$SRC"/data/*; do case "$(basename "$f")" in *.ROM) ;; *) cp "$f" "$OUT/data/";; esac; done
  # game/ 只留繁中字型(不含遊戲/ROM)
  cp "$SRC"/game/waxworks_zh16.dcjk "$SRC"/game/waxworks_zh24.dcjk "$SRC"/game/waxworks_zh.tab "$OUT/game/"
  # 啟動器 + README
  printf "@echo off\r\ncd /d \"%%~dp0\"\r\nif not exist saves mkdir saves\r\nscummvm.exe -p game --themepath=data --extrapath=game --music-driver=mt32 --auto-detect --savepath=saves\r\npause\r\n" > "$OUT/play-waxworks.bat"
  cp /w/docs/如何開始遊玩.txt "$OUT/README.txt" 2>/dev/null || true
  zip -rq /w/dist-all/蠟像館之謎-CHT-windows-x64.zip "$OUT"
  chown -R '"$(id -u):$(id -g)"' /w/dist-all 2>/dev/null || true
  echo "=== 產物 ==="; ls -lh /w/dist-all/蠟像館之謎-CHT-windows-x64.zip
  echo "=== game/ 內容(應只字型) ==="; ls "$OUT/game"
  echo "=== 確認無 ROM/遊戲 ==="; find "$OUT" -iname "*.ROM" -o -iname "GAMEPC" -o -iname "TABLES*" | head
'
