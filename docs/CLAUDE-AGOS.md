# CLAUDE — AGOS 引擎老遊戲繁體中文化（ScummVM）

> 放進「一款 AGOS 引擎遊戲中文化專案」當 `CLAUDE.md`。蒸餾自《Simon the Sorcerer》(神通妙巫師) 與《Waxworks》(蠟像館之謎) 的 AGOS 繁中化實戰。
> **這是 SCUMM 模板的姊妹版**。SCUMM 靠丟字型檔零 patch；**AGOS 沒有這條路，必須 patch ScummVM AGOS 引擎原始碼**——這是兩者最根本的差異，先讀「§0 為什麼 AGOS 不能零 patch」。
> 命中即載對應 rulebook：`84-scummvm-talkie-cht-fusion`（AGOS 中文化心臟）、`83`（完整性）、`81`（CJK hires 畫布）、`80`（README）、`62/64`（RE 溯源／截圖 oracle）、`93`（推廣片素材）；`re-retro-cht-rulebook` 路由。

---

## 身分
- AGOS 引擎老遊戲繁中化工作分身：**抽字 → 翻譯 → 烘字型 → patch 引擎 → 回填注入 → 實機驗證 → 打包**。
- 支援的 AGOS 遊戲：Elvira 1/2、Waxworks、Simon 1/2、Feeble Files、The Feeble Files、Puzzle Pack 等（ScummVM `engines/agos`）。

## interaction
- **動手前先問清楚**：需求不完整時先問「必須釐清的問題」再開工。
- **啟動檢查點**：接到技術任務先查 `re-retro-cht-rulebook` 路由表逐列比對，命中先 `Read` 對應 kb／rulebook 再做。

## 最高優先原則
正確性 / 引擎對齊 ＞ 可玩交付 ＞ 可維護 / 文件 ＞ 效能 / 美觀。
- **注意**：AGOS 的最高原則**不是**「零 patch」（那是 SCUMM 專屬）。AGOS 是「**最小且乾淨的引擎 patch，全部集中在 `#if 非上游` 標記的分支，不破壞上游相容**」。

---

## §0 為什麼 AGOS 不能零 patch（第一性原理，最重要）

SCUMM 能零 patch，是因為引擎**內建 CJK 渲染路徑**：偵測到 `chinese_gb16x12.fnt` 就自動切 Chinese、走雙位元組渲染，且 gameid 在 ZH_CHN 白名單。**AGOS 沒有這套基礎建設**：

1. **沒有 CJK 字型偵測開關**——AGOS 的文字渲染是固定的 8×8 / 6px 英文點陣（`charset.cpp windowPutChar`、`charset-fontdata.cpp renderString`），不認雙位元組，也沒有「放個字型檔就切中文」的分支。
2. **硬編碼 UI 不經字串表**——動詞列（`verb.cpp english_verb_names[]`）、存讀檔訊息（`saveload.cpp fileError/confirmOverWrite`）是寫死在原始碼的 `switch(_language)`，**沒有 `ZH_TWN` 分支就落回英文**，查表攔不到。
3. **文字緩衝照英文小字算**——`res.cpp loadVGAVideoFile` 只給字幕 sprite 額外 6400 bytes（2 行×320×10px），24px 全形中文會溢位。
4. **低解析畫布塞不下 CJK**——320×200 邏輯畫布，中文縮到 8px 糊成一團（見 `rulebook/81`）。

→ 結論：**AGOS 中文化 = 必須改引擎原始碼**。但改法要乾淨：所有改動打成一份 `agos-cht.patch`，集中在 `// 非上游` 註記的分支，用旗標（`_chtActive` / `_chtHires`）gate，OR 上引擎既有的 PC98 條件，**不破壞英文與其他語言的原路徑**。公開 repo 仍 patch-only（推 `.patch`＋字型＋譯文），但玩家跑 **patched／我方提供的 ScummVM**，不能用官方預編 binary。

---

## §1 AGOS 文字模型（抽字的分母，以引擎為 oracle）

以 ScummVM `engines/agos/` 原始碼為 oracle，AGOS 遊戲的文字分五類（代號 A–F，驗收時逐類確認）：

| 類 | 來源 | 覆蓋機制 | 備註 |
|---|---|---|---|
| **A. GAMEPC 內建字串表**（物品名、房間名、短語） | `GAMEPC` 檔，`stringId < 0x8000` → `_stringTabPtr[stringId]` | 走 `getStringPtrByID` → **查表可換** ✅ | 條數＝GAMEPC 檔頭第 4 個 `UInt32BE`（`res.cpp` 讀序：itemArraySize→version(0x80)→itemArrayInited→**stringTableNum**→textSize） |
| **B. 對白／旁白**（TEXTxx 分頁） | `stringId >= 0x8000` → `getLocalStringByID` → `loadTextIntoMem` 分頁載入 `TEXTxx`；`STRIPPED.TXT` 為檔名/範圍索引 | 走 `getStringPtrByID` → **查表可換** ✅ | 對白 id 從 0x8000 起，每個 `TEXTxx` 覆蓋 `[base_min, base_max)`，base_max 存在 STRIPPED.TXT |
| **C. 物品欄描述**（examine） | A 或 B | 走 `getStringPtrByID` ✅ | 併入 A/B 計數 |
| **D. 動詞列 / 動作 UI** | `verb.cpp` 硬編碼 `english_verb_names[]` | **不經查表** ❌ → **原始碼加 `cht_verb_names[]` + ZH 分支** | 每款 subengine 的 verb 集不同（Simon 12 格點按；Elvira2/Waxworks 是另一套介面） |
| **E. 存讀檔系統訊息** | `saveload.cpp` 硬編碼各語言 switch | **不經查表** ❌ → **原始碼加 ZH_TWN 分支**（Big5） | 存/讀失敗、覆寫確認、Yes/No |
| **F. 片頭 logo / credits / 面板美術上的字** | VGA 預繪點陣圖 | **不經文字函式** ❌（改字串無效）→ 改圖 | 依 `83` 完整性不預砍，做不到誠實標「未完成＋方法」 |

- **抽字工具**：`extract_floppy_text.py`（讀 GAMEPC 字串表 + STRIPPED.TXT + TEXTxx 對白）。AGOS 各 floppy 遊戲文字模型一致，此工具跨遊戲沿用，只有條數變。
- **動態 oracle**：引擎內建反組譯器 `dumpAllSubroutines()`（`debug.cpp`）+ `getStringPtrByID` 出口 log `CHTMISS`。build 後開 dump 模式跑一輪，收集引擎「實際請求過的每一條 id」＝真實 runtime 宇宙，驗收以「dump 未翻歸零」為準，**不以譯表自稱條數**。

---

## §2 編碼與字型（Big5，非 GB2312）

- **[HARD] 用 Big5**：AGOS 走原始碼 patch，`getStringPtrByID` 出口直接回 Big5 位元組、`windowPutChar` 自己處理雙位元組，**不受 SCUMM scummtr 的 ASCII 特殊字元限制**，故用 Big5（繁中原生）即可，不必像 SCUMM 那樣挑 `0xA1–0xFD` GB2312 碼空間。
- **DCJK 字型格式**（`build_cjk_font.py` 從 TTF 烘 Big5 點陣 atlas）：
  - header 15 bytes：magic `"DCJK"`、version、width、height、bytesPerRow、encoding、numGlyphs(LE)。
  - Big5 線性索引：`(lead-0x81)*157 + trailOffset`，trail `0x40–0x7E`→`0..62`、`0xA1–0xFE`→`63..156`。numGlyphs = 126×157 = 19782。
  - 烘兩套：**24×24**（字幕/視窗文字）＋ **16×16**（底部指令面板小格）。字型來源用 `NotoSansCJK`（開源）。
- **STAB 譯表格式**（`build_translation.py` 把 `id<TAB>繁中` UTF-8 編成 Big5 二進位表）：magic `"STAB"`、count、`[id:4 LE][len:2 LE][big5 bytes]`。引擎 `chtLoadTable` 載入成 `HashMap<id, Big5String>`。

---

## §3 引擎 patch 的骨架（`agos-cht.patch`，沿用 Simon 那套）

一份集中式 patch，全部 `// 非上游` gate。核心組件（依可延用度排序）：

### 通用可延用（跨 AGOS subengine）
- **字串注入**（`string.cpp getStringPtrByID` 出口）：`if (_chtActive && _chtSubLang==1)` 查 `_cht.table[stringId]`，命中回 Big5（雙 buffer 輪替避免覆寫）。**這是最乾淨的注入點，A/B/C 全靠它**，不分 subengine。
- **hi-res 雙層畫布**（`agos.cpp init/go`、`gfx.cpp getBackendSurface/updateBackendSurface`、`cursor.cpp`）：**沿用引擎給 PC98 的 `_backBuf`(邏輯 320×200) + `_scaleBuf`(640×400 高解析疊層) 機制**。把 `getGameType()==GType_ELVIRA1 && kPlatformPC98` 條件 OR 上自己的 `_chtHires` 旗標（`_chtHires` 在「CHT 字模在場」時開）。中文字畫進 `_scaleBuf` → 原生點陣、相對變小、清晰不擠（直接解掉 `rulebook/81` 的縮字兩難）。游標 2x upscale、`_mouse >>= 1` 還原 hitarea 都已為 PC98 寫好，一起 OR。
- **Big5 繪字**（`charset-fontdata.cpp chtRenderStringCJK`、`string.cpp chtPrintScreenText/chtDrawBig5OnSurface`）：把折行後的 Big5 畫進 `_scaleBuf`。含**亮度守門 `chtReadableColor`**（只救暗到讀不到的字色，其餘保留說話者配色）＋**1px 描邊 `chtOutlineColor`**（壓在花紋美術上也有輪廓）。
- **文字緩衝放大**（`res.cpp`）：`extraBuffer += 6400` → `+= 40000`（24px 中文字幕需更大文字區）。
- **視窗雙位元組**（`charset.cpp windowPutChar`）：偵測 Big5 lead → 存 `_chtLead` → 下一 byte 湊成雙位元組畫；欄寬前進正確格數（hires 16px＝1 邏輯欄）。
- **存讀檔 ZH 分支**（`saveload.cpp confirmOverWrite/fileError`）：加 `if (_chtActive && _chtSubLang==1)` 提供 Big5 訊息。
- **F8 切中/英字幕**（`event.cpp`）、**module.mk 加 `cht_fusion.o`**、**agos.h 宣告成員與方法**。
- **`cht_fusion.cpp/h`**：`ChtFusion` struct（font/font16/table/voice loaders）。

### 每款 subengine 要重對位（不同遊戲不同）
- **動詞列 / 動作 UI**（`verb.cpp`）：`cht_verb_names[]` 的內容與格數依 subengine 而異。Simon 是 12 格點按 verb 面板（`chtDrawVerbPanel` 對 101..112 hitarea 取樣底色＋英文字色、抹掉英文、畫中文覆蓋層）。**Elvira2/Waxworks 的介面不同**，要先反組譯確認動作元件形式與文字來源，再決定是查表換字還是覆蓋層畫圖。
- **`printScreenText` / talk sprite**：Simon 有 talk head 字幕 sprite（`script_s1.cpp os1_screenTextMsg`、`chtPrintScreenText` 走 animate 199+vgaSpriteId）。其他 subengine 的對白視窗可能是純 `windowPutChar` 文字視窗，注入點與繪製路徑不同——**先確認該遊戲對白走哪條路**。
- **`getGameType()==GType_SIMON1` 條件**：patch 裡凡 gate 在 Simon 的，換成目標 subengine 的 `GType_*`（Waxworks＝`GType_WW`）。
- **防拷**：引擎多有 `_copyProtection` 旗標，`_chtActive` 時設 `false` 自動 bypass（免查手冊）。確認目標遊戲的防拷 script 吃這旗標。

---

## §4 環境（docker-first）

```dockerfile
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq && apt-get install -y -qq \
    build-essential libsdl2-dev libsdl2-net-dev libfreetype6-dev \
    libpng-dev libjpeg-turbo8-dev pkg-config zlib1g-dev nasm \
    python3 python3-freetype fonts-noto-cjk \
    xvfb imagemagick xdotool dosbox libsndio7.0 \
    && rm -rf /var/lib/apt/lists/*
```

- **編譯**：`configure --disable-all-engines --enable-engine=agos --enable-release`（AGOS only，快）。對 ScummVM **v2.9.1**（patch 的基準版；換版要重對 patch）。
- **抽字/字型/回填**：Python 工具在 docker 內跑（`build_cjk_font.py` 需 `python3-freetype`）。
- **實機驗證**：headless `Xvfb :99` + `scummvm -p /game --auto-detect` + `import -window root` 截圖（用 Read 看，**不開 GUI viewer、禁 sentinel 輪詢**，見 `rulebook/35`）。
- **資料解壓**（安裝檔是自訂壓縮如 Adventure Soft `.RED`）：docker 內 DOSBox 跑原版 `INSTALL.EXE` 自己解，多磁片用「目錄熱抽換」（見 `rulebook/84 §4`）。

---

## §5 抽字 / 回填 / 驗證流程

1. **抽字**：`extract_floppy_text.py <floppy_dir> out.tsv` → id→英文（A 字串表 + B 對白）。
2. **翻譯**：fan-out subagent 翻 id→繁中，**先建統一譯名表**（人物/地名/怪物）防漂移，第二輪校對一致性 + **非 Big5 字掃描**（`build_translation.py` 會警告不可編碼字）。保留原作插科打諢、年代感；譯名沿用既有官方/在地版。
3. **烘字型**：`build_cjk_font.py --size 24` + `--size 16` → `<game>_zh24.dcjk`、`<game>_zh16.dcjk`。
4. **編譯 patched ScummVM** + 把字型/譯表放遊戲夾。
5. **注入**：引擎啟動時 `chtLoadFont/chtLoadTable`，`_chtActive=true`。**不改遊戲原檔**——注入在 runtime 依 id 查表（這是 AGOS 版的「回填」，比 SCUMM 改 GME 更乾淨可逆）。
6. **驗證（headless）**：
   - **dump oracle**：開 `CHTMISS` log 跑一輪，確認引擎請求的每條 id 都命中譯表（未翻歸零）。
   - **實機截圖**：對白逐字正確、動詞/動作 UI 全中文、存讀檔中文、**無字元級亂碼**（有＝Big5 索引或折行錯）、hi-res 中文 crisp、防拷自動過。

- **[HARD] round-trip 概念**：AGOS 用「id→譯表 runtime 注入」而非改檔，天生可逆（拿掉字型/譯表就回英文）。驗收核心＝**dump oracle 命中率**，不是自稱條數。

---

## §6 打包（`dist-all/`）

- **不能用官方 binary**（AGOS 需 patched 引擎）→ 三平台都要帶 **patched ScummVM**：
  - Linux **AppImage**（AppDir + `ldd` 收非系統 `.so` + `appimagetool --comp zstd`；docker 內 `APPIMAGE_EXTRACT_AND_RUN=1`、`--runtime-file` 帶本機 runtime）。
  - Windows：MinGW 交叉編或帶 SDL2 DLL 的 zip；**務必補 ScummVM 執行期資料檔**（GUI 主題 `.dat`/字型/翻譯），否則「Could not find theme/font」起不來，launcher 設 `--themepath`/`--extrapath`（Simon issue #1 的雷）。
  - macOS Universal `.app`（CI `lipo`/`otool` 或 `mac-app-cross-pack` skill）。
- 完整版把 patched scummvm + `<game>_zh24.dcjk` + `<game>_zh16.dcjk` + `<game>_zh.tab` + 遊戲夾 打成一包，launcher 自動指到遊戲夾。
- **MT-32**：`--enable-mt32emu` + **附 ROM 才設 `--music-driver=mt32`**（缺一彈阻擋框退回 AdLib）；公開版不附 ROM、保 `-e adlib`。
- **[HARD] leak-scan**：遊戲原檔（`GAMEPC`/`TABLES`/`TEXTxx`/`*.VGA`/floppy 影像）、ROM、含版權配樂影片一律 gitignore，push 前精準 grep 複檢。本機完整版含版權資料只留 `dist-all/`。

---

## §7 硬規則清單（速查）
- [HARD] **AGOS 必 patch 引擎**（非零 patch）；改動集中 `// 非上游` gate、OR 上 PC98 條件、不破壞上游。
- [HARD] **用 Big5**；DCJK 索引 `(lead-0x81)*157+trailOffset`。
- [HARD] **公開 repo patch-only**：遊戲本體/ROM/版權配樂不入公開 repo，只留本機 `dist-all/`。
- [HARD] 抽字以引擎文字模型（A–F）為分母，**dump oracle 未翻歸零**才算完成，不自稱條數。
- [HARD] 硬編碼 UI（動詞列/存讀檔）要在原始碼加 ZH 分支，查表攔不到。
- [HARD] talkie/CD 版常缺字幕 → 先比對 floppy vs CD 字串數，缺就以 floppy 為字幕源做融合（見 `rulebook/84 §1`）；floppy-only 遊戲（如 Waxworks）不需融合。
- [HARD] 引擎行為斷言以 **descumm/dumpAllSubroutines/實機當 oracle**，不憑記憶；譯名沿用既有官方/在地版。
- [HARD] 推廣片配樂用**原版真實素材**、不自產（`rulebook/93`）；背景 build 前景有界、禁 sentinel 輪詢（`rulebook/35`）。

---

## §8 換一款 AGOS 遊戲：檢查清單
1. [ ] `scummvm --list-games` 確認 gameid 與 subengine（`GType_*`）；ScummVM 有支援（AGOS 引擎）。
2. [ ] 檔案指紋確認 AGOS：`GAMEPC`/`STRIPPED.TXT`/`TEXTxx`/`TABLESxx`/`ROOMSxx`/`START`。
3. [ ] **反組譯確認該 subengine 的文字/UI 路徑**（字串是否走 `getStringPtrByID`；對白走 talk sprite 還是文字視窗；動作 UI 形式與文字來源；防拷 script）——這決定 patch 對位。
4. [ ] 比對 floppy vs CD 字幕完整度（talkie 版可能缺字幕）；floppy-only 免融合。
5. [ ] `extract_floppy_text.py` 抽 A/B → 統計條數（對 GAMEPC 檔頭 stringTableNum）。
6. [ ] 建統一譯名表 → fan-out 翻譯 → 校對 + 非 Big5 掃描。
7. [ ] 烘 24/16 DCJK 字型。
8. [ ] 對位 `agos-cht.patch`：通用組件直接套，subengine 專屬（verb/talk/GType 條件/防拷）重對位。
9. [ ] 編 patched ScummVM → 注入 → dump oracle 歸零 + headless 截圖驗證。
10. [ ] 三平台打包（帶 patched 引擎 + 資料檔）+ leak-scan。
11. [ ] README（雜誌風 `rulebook/80`）、手冊/攻略整理、推廣片（原版配樂）、dev-setup 接續包。
12. [ ] 公開 repo 只推 patch-only（patch + 譯文 + 字型 + 工具 + 文件）。

---

## 參考案例
- **Simon the Sorcerer**（神通妙巫師，GType_SIMON1）：github.com/wicanr2/simon-the-sorcerer-cht — CD 語音 + floppy 字幕融合、12 格 verb 面板覆蓋層、hi-res 雙層。
- **Waxworks**（蠟像館之謎，GType_WW）：github.com/wicanr2/waxworks_dos_cht — floppy-only（免融合）、Elvira2 系介面。
