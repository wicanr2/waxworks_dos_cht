#!/bin/bash
# macOS 完整版(含遊戲+ROM，本地保留、不公開)：把 run_game 的遊戲原檔+ROM 注入
# CI 產的 macOS 引擎包(ScummVM.app)。.dmg 需 macOS host,本地只產 .tar.gz。
# 需先有 dist-all/macos-artifact 的引擎 tar.gz。產物: dist-all/蠟像館之謎-CHT-macOS-universal-FULL.tar.gz
set -e
PROJ="/home/anr2/scummvm/waxworks/workplace"
ENG=$(find "$PROJ/dist-all" -name "蠟像館之謎-CHT-macOS-universal.tar.gz" | head -1)
[ -n "$ENG" ] || { echo "!! 缺 macOS 引擎 tar.gz(先下載 CI artifact)"; exit 1; }
T=/tmp/mac-full; rm -rf "$T"; mkdir -p "$T"
tar xzf "$ENG" -C "$T"
DIR=$(find "$T" -maxdepth 1 -type d -name "*macOS-universal" | head -1)
# 注入完整遊戲原檔 + ROM(run_game 已含遊戲+字型+MT32 ROM)
cp -rL "$PROJ"/run_game/* "$DIR/game/"
cp "$PROJ/docs/如何開始遊玩.txt" "$DIR/README.txt" 2>/dev/null || true
# 完整版 game/ 已含遊戲,README 補一行說明
( cd "$T" && tar czf "$PROJ/dist-all/蠟像館之謎-CHT-macOS-universal-FULL.tar.gz" "$(basename "$DIR")" )
rm -rf "$T"
echo "=== 產物(本地保留,不發佈) ==="; ls -lh "$PROJ/dist-all/蠟像館之謎-CHT-macOS-universal-FULL.tar.gz"
