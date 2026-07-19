#!/bin/bash
# dev-setup 接續包：從零把《蠟像館之謎》繁中化開發環境架起來。
# 只需 docker + git。遊戲原檔（版權）不含在本 repo，需自備放進 run_game/。
#
#   bash scripts/dev_setup.sh          # 全流程：建 image → 取 ScummVM → 套 patch → 編譯
#   bash scripts/dev_setup.sh --rebuild-only   # 只重編（已有 scummvm-src）
set -euo pipefail

PROJ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJ"
SV_TAG="v2.9.1"
SRC="build/scummvm-src"

step(){ printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }

if [ "${1:-}" != "--rebuild-only" ]; then
  step "1/5 建置 docker 映像 waxworks-build"
  docker build -t waxworks-build -f docker/Dockerfile docker/

  step "2/5 取 ScummVM $SV_TAG 原始碼 → $SRC"
  if [ ! -d "$SRC/.git" ]; then
    mkdir -p build
    git clone --depth 1 --branch "$SV_TAG" https://github.com/scummvm/scummvm.git "$SRC"
  else
    echo "  已存在，跳過 clone"
  fi

  step "3/5 套用 patches/agos-cht.patch"
  ( cd "$SRC"
    if git apply --check --reverse --whitespace=nowarn "$PROJ/patches/agos-cht.patch" 2>/dev/null; then
      echo "  patch 已套用，跳過"
    else
      git checkout -- engines/agos 2>/dev/null || true
      git apply --whitespace=nowarn "$PROJ/patches/agos-cht.patch"
      echo "  ✓ patch 套用完成"
    fi )
fi

step "4/5 編譯 patched ScummVM(AGOS + CHT)"
bash scripts/build_scummvm.sh

step "5/5 檢查繁中資產與遊戲原檔"
mkdir -p run_game
for f in waxworks_zh16.dcjk waxworks_zh24.dcjk waxworks_zh.tab; do
  [ -f "run_game/$f" ] || cp "fonts/$f" "run_game/$f"
done
if [ ! -f run_game/GAMEPC ]; then
  cat <<'MSG'

  ⚠ run_game/ 尚無遊戲原檔（GAMEPC、TABLES01…、TEXT01…、ROOMS0x、STATELST 等）。
    請把你合法擁有的 Waxworks(Floppy/DOS) 全部檔案複製進 run_game/ 後即可執行：

      bash scripts/capture.sh 0 8 shot      # headless 截圖驗證
      # 或本機 GUI：
      build/scummvm-src/scummvm -p run_game --auto-detect --music-driver=mt32

    想要原版 MT-32 配樂：把 MT32_CONTROL.ROM / MT32_PCM.ROM 也放進 run_game/。
MSG
else
  echo "  ✓ 遊戲原檔就緒。執行：build/scummvm-src/scummvm -p run_game --auto-detect --music-driver=mt32"
fi
echo
echo "完成。開發指南見 docs/DEV_SETUP.md、引擎對位見 docs/CLAUDE-AGOS.md。"
