# 開發接續指南（dev-setup）

這份文件讓任何人（或未來的你）從零接手《蠟像館之謎》繁體中文化的開發。整個專案是 **patch-only**：
repo 只放補丁、字型、譯文、工具、文件；ScummVM 原始碼與遊戲原檔都不入庫，由本指南重建。

## 需要什麼

- `docker`、`git`（就這樣，編譯與執行都在 docker 裡，不污染系統）
- 你**合法擁有**的 Waxworks (Floppy/DOS/English) 遊戲原檔
- （選配）Roland MT-32 ROM：`MT32_CONTROL.ROM`、`MT32_PCM.ROM` — 想要原版真實配樂

## 一鍵起手

```bash
bash scripts/dev_setup.sh
```

會依序：建 docker 映像 → 取 ScummVM v2.9.1 → 套 `patches/agos-cht.patch` → 編譯 → 檢查資產。
編完把遊戲原檔複製進 `run_game/`（連同可選的 MT-32 ROM）即可執行。

只想重編（已有 `build/scummvm-src`）：`bash scripts/dev_setup.sh --rebuild-only`。

## Repo 佈局

| 路徑 | 內容 |
|---|---|
| `patches/agos-cht.patch` | **核心**：對 ScummVM `engines/agos` 的全部繁中改動（字串注入、Big5 視窗描繪、hi-res 疊層、verb overlay、動態地圖、友善作弊）。`git diff` 格式，套在乾淨 v2.9.1 上 |
| `fonts/waxworks_zh16.dcjk` `_zh24.dcjk` `_zh.tab` | 烘好的 Big5 CJK 點陣字型與 STAB 譯表（執行期放進 `run_game/`）|
| `translations/zh.tsv` | 譯文主表（英文原文 → 繁中）；`glossary.md` 統一譯名 |
| `tools/*.py` | `extract_floppy_text`（抽原文）、`build_translation`（zh.tsv → STAB `.tab`）、`build_cjk_font`（烘 `.dcjk`）|
| `scripts/*.sh` | 建置與打包：`build_scummvm` / `build_font` / `build_appimage` / `build_windows` / `capture`（headless 截圖）/ `capture_av`（錄影＋MT-32 錄音）/ `build_promo`（推廣片）|
| `docker/Dockerfile` | 建置環境（ubuntu 24.04 + SDL2 + mingw 交叉編 + Xvfb + imagemagick）|
| `docker/Dockerfile.capture` | 上者 + ffmpeg/pulseaudio，供錄推廣片 |
| `.github/workflows/macos.yml` | GitHub Action：macOS universal（arm64+x86_64 lipo）打包 |
| `docs/CLAUDE-AGOS.md` | **AGOS 引擎對位聖經**：字串模型、item 結構、hi-res 機制、每個修改點的原理 |
| `docs/RESEARCH.md` `WALKTHROUGH.md` `BESTIARY.md` `DYNAMIC_MAP_FEASIBILITY.md` | 逆向筆記、攻略、怪物圖鑑、動態地圖可行性 |
| `build/scummvm-src/` `run_game/` `dist-all/` | **不入庫**（gitignore）：原始碼、遊戲、產物 |

## 改譯文 → 重生效

```bash
# 1. 編輯 translations/zh.tsv
# 2. 重烘譯表(.tab)並更新 run_game
docker run --rm -v "$PWD:/w" -w /w waxworks-build \
  python3 tools/build_translation.py translations/zh.tsv run_game/waxworks_zh.tab
# 3. 重跑遊戲即生效(字型不變就不必重烘 .dcjk)
```

譯名對照與 AGOS 文字四類模型（A=GAMEPC 字表、B=對白 TEXTxx、D=硬碼 UI、F=烘進 VGA 的美術字）
見 `docs/CLAUDE-AGOS.md`。

## 改引擎（patch）→ 重生成 patch

```bash
# 直接改 build/scummvm-src/engines/agos/*.cpp，編譯測試：
bash scripts/build_scummvm.sh
# 滿意後重生成 patch(維持 patch-only 唯一真相)：
( cd build/scummvm-src && git diff HEAD -- engines/agos ) > patches/agos-cht.patch
```

## Headless 驗證

無頭環境務必 **Xvfb 深度 x16 + `SDL_AUDIODRIVER=dummy`**（x8 會 "Couldn't find matching render driver"）：

```bash
bash scripts/capture.sh 0 8 shot          # 開機 8 秒抓 6 張截圖 → screenshots/
bash scripts/cheat_smoke.sh               # 作弊功能回歸(TAB/F5/F6/F7/F8)
```

## 打包

```bash
bash scripts/build_appimage.sh   # Linux AppImage(內含遊戲+ROM，本機完整版)
bash scripts/build_windows.sh    # Windows zip(mingw 交叉編 + 全 DLL + 遊戲)
# macOS universal 由 GitHub Action(.github/workflows/macos.yml)在雲端 runner 產出
```

AppImage / Windows 版是「完整版」（含版權遊戲與 ROM），僅供自用、不入 git；
公開散佈請走 patch-only：使用者自備遊戲，套 patch 後自行編譯或用 macOS Action 產物。

## 推廣片

```bash
bash scripts/capture_av.sh master.mp4 120 /work/promo/keys_demo.sh  # 錄實機+MT-32
bash scripts/build_promo.sh                                          # 剪接成推廣片
```

## 延伸方向（未竟）

- **中文語音**：見 task 規劃（多 TTS 來源、恐怖音色）— 對白 TEXTxx 逐句合成後注入。
- **墓園殭屍砍頭即殺作弊**：已評估，戰鬥死亡判定在即時 VGA 層、無乾淨靜態 hook，
  需墓園實戰即時觀察變數才能定位（見 task #17 結論）。F7 無敵已覆蓋致命性。
