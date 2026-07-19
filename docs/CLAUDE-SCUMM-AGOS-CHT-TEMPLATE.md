# CLAUDE — SCUMM/AGOS 引擎老遊戲繁體中文化模板（ScummVM · AGOS）

> 放進「一款 AGOS 引擎遊戲中文化專案」當 `CLAUDE.md`。蒸餾自《Simon the Sorcerer》(神通妙巫師)、《Waxworks》(蠟像館之謎) 的 AGOS 繁中化實戰——**含現代玩家友善化、推廣片、三平台打包、macOS CI 的完整踩雷**。
> **這是 SCUMM 模板的姊妹版**。SCUMM 靠丟字型檔零 patch；**AGOS 沒有這條路，必須 patch ScummVM AGOS 引擎原始碼**——先讀「§0 為什麼 AGOS 不能零 patch」。
> 命中即載 rulebook：`84`(AGOS 中文化心臟)、`83`(完整性)、`81`(CJK hires 畫布)、`80`(README)、`62/64`(RE 溯源／截圖 oracle)、`93`(推廣片素材)、`35`(背景 agent/CI 監看)、`60`(先建可驗證訊號)、`41`(打地鼠停手重想)；kb `mac-app-cross-pack`(macOS 打包)。

---

## ★ 踩雷速查（動手前先掃這張，全是這次真的踩過的坑）

| 症狀 / 情境 | 根因 | 正解 |
|---|---|---|
| headless 截圖全黑、`Couldn't find matching render driver` | Xvfb 深度 x8 | **`Xvfb :99 -screen 0 640x400x16`（x16）+ `SDL_AUDIODRIVER=dummy`** |
| `_scaleBuf` 疊層中文殘留到別的畫面 | **疊層像素不會自動清**（合成規則 `v1?v1:v0`，非零覆蓋） | 每幀重繪 or 離開時**主動 `memset` 清該帶狀區**；一次性疊字必配一次性清除 |
| 用 `zone*1000+image` 認畫面 → 認錯（title 中文跑到遊戲畫面） | **每個場景主背景都用 `zone1/image1`(=1001)，不唯一** | 用**閂鎖**（首次出現才處理，離開後永久關閉）or 加尺寸/位置簽名區分 |
| 想用 `_currentRoom==0` 判「開場」 | 開場 logo 時 `_currentRoom` **已非 0** | 別靠它；用「首次某事件」閂鎖 |
| 手寫 Big5 hex 疊字變亂碼 | 人工編碼易錯 | **一律 `python3 -c 's="…".encode("big5")'` 產 hex**，別手算 |
| `debug(0,...)` 看不到 | 預設 debuglevel = -1 | 跑加 **`-d1`** |
| headless 想存檔 → `Quick load or save game isn't supported in this location` | cutscene 期間 `_mouseHideCount` 擋存檔 | 等進到可操作場景再存；**開場 cutscene 極長（Waxworks ~3–5 分鐘自動播）** |
| quicksave 熱鍵存不了、反而載入 | AGOS：**`Alt+數字`=存、`Ctrl+數字`=載** | 存檔用 Alt+digit |
| 想做「戰鬥類作弊」（秒殺/改招式判定）卻找不到 hook | AGOS 即時戰鬥的傷害/死亡判定**在 VGA script bytecode**，引擎無戰鬥函式、傷害 opcode(177/178)在 WW 是 NULL、GAMEPC 子程式無戰鬥字串 | 靜態分析找不到乾淨 hook；需墓園實戰**即時觀察變數**才能定位。先評估再承諾，別硬鑽（`rulebook/41`）|
| macOS CI job 永遠 queued / 30 分不動 | **`macos-13`(Intel)runner 退役中** | **只用 `macos-14`**；x86_64 弧走 **`arch -x86_64`(Rosetta)** 在同一台各編一次 + `lipo -create` |
| macOS 玩家端「Failed loading SDL3」/黑畫面 | **`brew install sdl2`（2026 起是 sdl2-compat shim，runtime dlopen libSDL3）** | 自源碼編 **pinned 真 SDL2 2.30.9**；防呆：dylib **>1MB** 才真、`otool -L` 不得見 SDL3 |
| ScummVM `configure` 報 `unrecognized option: CXXFLAGS=-arch` | **ScummVM configure 非 autoconf**，`CXXFLAGS/LDFLAGS` 不能當引數 | 當**環境變數前綴**：`CXXFLAGS="-arch $A -mmacosx-version-min=$MIN" ./configure ...` |
| macOS universal 打包後另一半 arch 閃退 | per-arch+lipo 時 dylibbundler 只收一弧 dylib | **手動 `lipo` SDL2 dylib 進 `.app/Frameworks` + 兩弧各 `install_name_tool -change` + `codesign --force`** |
| Windows 版起不來「Could not find theme/font」 | 缺 ScummVM 執行期資料檔 | zip 帶 `gui/themes/*.zip`+`*.dat`+`fonts*.dat`，launcher `--themepath`/`--extrapath` |
| AppImage 一啟動就壞 | `cat > AppDir/AppRun` **穿透 linuxdeploy 建的 symlink 覆寫掉 binary** | 寫前先 `rm -f AppDir/AppRun` 斷 symlink |
| 對 GameType 的 gate 沒生效 | patch 沿用 Simon 的 `GType_SIMON1` 條件 | 換成目標 subengine（Waxworks=`GType_WW`）|

---

## 身分與原則
- AGOS 引擎老遊戲繁中化工作分身：**抽字 → 翻譯 → 烘字型 → patch 引擎 → 回填注入 → 實機驗證 →（友善化）→ 打包 → 推廣片 → dev-setup**。
- 支援 AGOS 遊戲：Elvira 1/2、Waxworks、Simon 1/2、Feeble Files、Puzzle Pack（ScummVM `engines/agos`）。
- **最高優先**：正確性/引擎對齊 ＞ 可玩交付 ＞ 可維護/文件 ＞ 效能/美觀。AGOS 的原則**不是**「零 patch」（SCUMM 專屬），是「**最小且乾淨的引擎 patch，全部 `// 非上游` gate、用旗標/OR PC98 條件，不破壞上游相容**」。
- **interaction**：需求不完整先問；技術任務先查 rulebook 路由再動手。

---

## §0 為什麼 AGOS 不能零 patch（第一性原理）

SCUMM 內建 CJK 渲染（偵測字型檔就切 Chinese）。**AGOS 沒有這套**：
1. 文字渲染是固定英文小點陣（`charset.cpp windowPutChar`），不認雙位元組、無「放字型檔就切中文」分支。
2. 硬編碼 UI 不經字串表——動詞列、存讀檔訊息寫死 `switch(_language)`，無 ZH 分支就落回英文，查表攔不到。
3. 文字緩衝照英文小字算，24px 全形會溢位。
4. 320×200 畫布塞不下 CJK（縮成 8px 糊掉）。

→ **AGOS 中文化 = 必須改引擎原始碼**，但打成一份集中式 `agos-cht.patch`，`// 非上游` gate、旗標控（`_chtActive`/`_chtHires`）、OR 上引擎既有 PC98 機制，不破壞英文路徑。公開 repo 仍 patch-only（推 `.patch`+字型+譯文），玩家跑 patched ScummVM。

---

## §1 AGOS 文字模型（抽字分母，以引擎為 oracle）

| 類 | 來源 | 覆蓋機制 |
|---|---|---|
| **A. GAMEPC 內建字串表**（物品/房間名、短語）| `GAMEPC`，`stringId<0x8000`→`_stringTabPtr` | `getStringPtrByID`→**查表可換** ✅ |
| **B. 對白/旁白**（TEXTxx 分頁）| `stringId>=0x8000`→`loadTextIntoMem` 分頁；`STRIPPED.TXT` 索引 | `getStringPtrByID`→**查表可換** ✅ |
| **C. 物品欄描述** | A 或 B | ✅（併入計數）|
| **D. 動詞列/動作 UI** | `verb.cpp` 硬編碼 `english_verb_names[]`；或**烘進 VGA 美術**（見下）| ❌ 需原始碼 ZH 分支 or 疊層覆蓋 |
| **E. 存讀檔系統訊息** | `saveload.cpp` 硬編碼各語言 switch | ❌ 需原始碼 ZH_TWN 分支（Big5）|
| **F. 片頭 logo/credits/面板美術上的字** | VGA 預繪點陣圖 | ❌ 改字串無效 → 疊層覆蓋 or 改圖 |

- **關鍵注入 chokepoint**：`string.cpp:getStringPtrByID(stringId)` — CHT 注入、也是**語音/其他 id-keyed 功能的共用掛勾**。
- **Waxworks 實例**：verb 條是**烘進 VGA 的美術字**（zone1 sprite 106–113），0 次 `windowDrawChar` → 不能查表換，要用疊層覆蓋（`chtDrawVerbName` 取樣底色蓋掉英文、畫中文）。**每款 subengine 的 verb 形式不同，先反組譯確認**。
- **動態 oracle**：`dumpAllSubroutines()`（`debug.cpp`）反組譯 GAMEPC 子程式；`getStringPtrByID` 出口 log `CHTMISS`。驗收以「dump 請求過的每條 id 命中譯表」為準，**不以譯表自稱條數**。

---

## §2 編碼與字型（Big5）

- **[HARD] 用 Big5**（AGOS 走原始碼 patch，`getStringPtrByID` 直接回 Big5、`windowPutChar` 自處理雙位元組，不受 SCUMM scummtr ASCII 限制）。
- **DCJK 字型**（`build_cjk_font.py` 從 TTF 烘）：header 15B（magic `DCJK`/ver/w/h/bpr/enc/numGlyphs LE）；Big5 線性索引 `(lead-0x81)*157+trailOffset`（trail `0x40–0x7E`→0..62、`0xA1–0xFE`→63..156），numGlyphs=19782。**烘 24×24（字幕）+ 16×16（面板小格）**，來源 Noto Sans/Serif CJK。
- **STAB 譯表**（`build_translation.py`）：magic `STAB`、count、`[id:4LE][len:2LE][big5]`；引擎 `chtLoadTable`→`HashMap<id,Big5>`。
- **[HARD] Big5 標點一致**：全形 vs 半形、`·`(U+00B7=Big5 0xA150) 取代不可編 `‧`(U+2027)；譯名漂移（莫莉/茉莉）統一。**產任何 Big5 hex 一律用 Python `.encode("big5")`，別手寫**。

---

## §3 引擎 patch 骨架（`agos-cht.patch`，全 `// 非上游` gate）

### 通用可延用（跨 subengine）
- **字串注入**（`string.cpp getStringPtrByID` 出口）：`_chtActive` 時查 `_cht.table[id]`，命中回 Big5（雙 buffer 輪替）。A/B/C 全靠它。
- **hi-res 雙層畫布**：沿用引擎給 PC98 的 `_backBuf`(320×200)+`_scaleBuf`(640×400 疊層)，把 `GType_ELVIRA1&&kPlatformPC98` 條件 **OR 上 `_chtHires`**（字模在場時開）。中文畫進 `_scaleBuf` → 原生點陣、相對變小、清晰。游標 2x、`_mouse>>=1` 還原 hitarea 一起 OR。**合成規則 `v1?v1:v0`（非零疊層覆蓋 backdrop）**。
- **Big5 繪字**：`chtDrawBig5OnSurface`/`chtDrawMapLabel` 畫進 `_scaleBuf`，含**亮度守門 `chtReadableColor`**（只救暗到讀不到的字色）+**1px 描邊 `chtOutlineColor`**（花紋上也有輪廓）。
- **文字緩衝放大**（`res.cpp`）：`extraBuffer += 6400`→`+= 40000`。
- **視窗雙位元組**（`charset.cpp windowPutChar`）：Big5 lead→存 `_chtLead`→下 byte 湊雙位元組；欄寬前進正確格數。**`getBoxSize/checkFit` 對中文（無空格）會 deref null→segfault**：CHT 分支從 CJK 格數算 box（`bw[6]={20,24,28,32,36,38}`）繞過 checkFit。
- **存讀檔 ZH 分支**（`saveload.cpp fileError/confirmOverWrite`）：Big5 訊息。
- **`cht_fusion.cpp/h`**（`ChtFusion` struct：font24=`font`/glyph()、font16、table、voice）、**module.mk 加 `cht_fusion.o`**、**agos.h 宣告成員**。

### 每款 subengine 重對位
- **動詞/動作 UI**：Simon=12 格 verb 面板覆蓋層；Waxworks=烘進 VGA 的 8 動詞條（查看/拿取/開/關/用/給/移動/交談，id 98/108/109/115/116/117/118/119），需疊層覆蓋。先反組譯確認。
- **對白路徑**：Simon 有 talk head sprite；他款可能純 `windowPutChar` 文字視窗。先確認走哪條。
- **`GType_*` 條件**、**防拷**（`_chtActive` 時 `_copyProtection=false` 自動 bypass；確認防拷 script 吃這旗標，Waxworks 是 `o_process` id==71）。

---

## §4 現代玩家友善化（疊層作弊/地圖/標題，選配層）

沿用 hi-res `_scaleBuf` 疊層，把功能畫在上面。**這層全是這次新增的踩雷重災區**。

### 4.1 資料模型（RE 出來的可用鉤子）
- **狀態變數** `_variableArray[]`：`[0]`=面向(0北1東2南3西)、`[20]`=Level、`[21]`=EXP、`[22]`=心靈力/PSY、`[23]`=HP。（來源：`script_e2.cpp printStats`；面向靠 F9 dump 轉右循環確認。）
- **item 結構**：`Item{parent,child,next,classFlags,...}`；`SubObject{objectName,objectFlags,objectFlagValue[]}`。`objectFlags` 位元：`kOFText=0x01`、`kOFIcon=0x10`、`kOFNumber=0x100`、`kOFMenu=0x80`…
- **`objectFlagValue` 是壓縮存的**：某 flag 的 offset = `getOffsetOfChild2Param(child, flag)` = 「該 flag 以下已設位元數」，**不是固定 offset**。
- **怪物偵測**：`objectFlags==kOFText(0x01)`；**寶物**：`objectFlags & kOFIcon`（對 339-item dump 驗過）。
- **消耗品計數**（如噴火槍次數）：在該 item 帶 `kOFNumber` 的 `objectFlagValue` 槽。

### 4.2 已實作的友善功能（Waxworks）
- **動態地圖**（TAB）：從 `_currentRoom` BFS 走 N/E/S/W(`getExitOf`/`getDoorState`)鋪 2D，畫格/牆/面向箭頭/寶物(黃)/怪物(紅)；探索迷霧靠 `_chtVisited` HashMap。
- **無敵**（F7）：`delay()` 頂端每幀把 `[23]/[22]=99`；擴充呼 `chtRefillConsumables()`（掃玩家(item 1)背包，帶 `kOFNumber` 的頂回 99 → 噴火槍無限）。
- **除霧**（F8）：`_chtFogOff` 旗標，chtDrawMap 略過 `_chtVisited` 過濾。
- **給物品**（F6）：`chtGiveRoomItems()` 把當前房間 `kOFIcon` 物品 `setItemParent` 給玩家。
- **標題中文**（title logo 下疊「蠟像館之謎」24px）。

### 4.3 疊層踩雷（務必記住）
- **[HARD] `_scaleBuf` 像素不會自動清**：一次性疊字（如標題）畫完會**殘留到後續畫面**。必須「離開時主動 `memset` 清該帶狀區」（用一次性旗標 `_chtXxxCleared`）。每幀重繪型（地圖/verb）則自然覆蓋，但仍要處理「關閉時清乾淨」。
- **[HARD] 別用 `zone*1000+image` 當唯一畫面 ID**：每個場景主背景都載成 `zone1/image1`(=1001)，**title logo 與遊戲入口撞號**。用**閂鎖**（`drawImage_init` 追 `_chtLastBigImg`；首次 1001=title，疊過且離開後 `_chtTitleDone=true` 永久關）。`_currentRoom` 開場也非 0，別靠它區分。
- **transient 提示疊字**：不同熱鍵的提示畫同位置會疊成亂碼 → 統一 `chtStatusMessage()` 先清帶狀區再繪，並與常駐指示器（如右上「無敵模式」）**分位**。
- **verb 覆蓋殘影**：2nd-line 英文殘留→填整個 window2 區取樣底色；verb overlay 漏進存讀檔畫面→在 `showMessageFormat`/`clearMenuStrip` reset `_chtVerbId=0`。

### 4.4 戰鬥類作弊——先評估可行性再承諾（重要教訓）
AGOS 即時戰鬥（肢解/招式判定）**不在**可讀 bytecode：GAMEPC 子程式無戰鬥字串、無 `SUB[23]`；傷害 opcode 177/178 在 WW 是 NULL；引擎無戰鬥函式；VGA 腳本也無「每擊扣 HP」算術（153 zone 全 dump 驗過）。**唯一寫 `[23]` 的是我方作弊碼**。→「秒殺/砍頭即殺」這類**靜態分析找不到乾淨 hook**，需實戰即時觀察變數（headless 難自動化）。**先 dump 評估、誠實回報不可行，別硬鑽**（`rulebook/41`）；「無敵」已覆蓋致命性。

---

## §5 環境與 headless 驗證（docker-first）

- **build image**：`ubuntu:24.04` + `build-essential libsdl2-dev libsdl2-net-dev libfreetype6-dev libpng-dev pkg-config zlib1g-dev nasm python3 python3-freetype fonts-noto-cjk xvfb x11-utils imagemagick xdotool dosbox` + mingw（Windows 交叉編）。
- **capture image**（推廣片）：上者 + `ffmpeg pulseaudio pulseaudio-utils`。
- **編譯**：`configure --disable-all-engines --enable-engine=agos --enable-release`（+ 音訊/媒體 `--disable-*`；**保留 `mt32emu`**）。基準 ScummVM **v2.9.1**（換版重對 patch）。
- **[HARD] headless**：`Xvfb :99 -screen 0 640x400x16`（**x16，x8 會炸 render driver**）+ `SDL_AUDIODRIVER=dummy`；`import -window root` 截圖用 Read 看，**禁 GUI viewer、禁 sentinel 輪詢**（`rulebook/35`）。
- **開場很長**：Waxworks credits(ACCOLADE→HORRORSOFT→WAXWORKS)~50s 自動播、之後管家+水晶球 cutscene 到可操作**共 ~3–5 分鐘**、全程存檔被擋。要 gameplay 存檔得耐心等完 cutscene，**Alt+1** 存（Ctrl+1 是載）。
- **RE dump 技巧**（暫時 init hook，旗標檔 gate）：
  - 全子程式：遍歷 `_tblList` 逐 TABLES `loadTablesIntoMem`+`dumpSubroutines`。
  - 全 VGA 腳本：`dumpAllVgaScriptFiles()`（遍歷 153 zone）。
  - item dump：`getOffsetOfChild2Param` 算 `kOFNumber` 值。
  - 影像 id：在 `drawImage_init` 記 `_vgaCurZoneNum*1000+image`（寬度單位是 16px 欄，w=17→272px）。
  - RE 想看英文字串就**暫時移開 `.tab`**（`_chtActive=false`）再 dump。
  - `debug(0,...)` 要 `-d1` 才印。

---

## §6 抽字/回填/驗證流程
1. `extract_floppy_text.py` 抽 A/B → id→英文（對 GAMEPC 檔頭 stringTableNum；round-trip diff=0）。
2. 翻譯：fan-out subagent，**先建統一譯名表**防漂移，二輪校對 + 非 Big5 掃描。保留插科打諢/年代感、沿用既有官方在地譯名。
3. 烘 24/16 DCJK。
4. 編 patched ScummVM + 字型/譯表放遊戲夾（**不改遊戲原檔**，runtime 依 id 查表＝AGOS 的可逆「回填」）。
5. 驗證：**dump oracle 未翻歸零** + headless 截圖（對白逐字、UI 全中文、存讀檔中文、無字元亂碼、hi-res crisp、防拷自動過）。

---

## §7 打包（`dist-all/`，三平台都帶 patched ScummVM）

### Linux AppImage
AppDir + `ldd` 收非系統 `.so` + `appimagetool`；docker 內 `APPIMAGE_EXTRACT_AND_RUN=1`。**[HARD] `cat > AppDir/AppRun` 前先 `rm -f` 斷 linuxdeploy symlink**。AppRun 設 `--themepath`/`--extrapath`/`--savepath` + `--music-driver=mt32`。

### Windows zip
mingw-w64 交叉編（`--disable-fluidsynth` 等，`mt32emu` 保留）；**帶全 DLL**（SDL2、libgcc_s_seh、libstdc++-6、libwinpthread、zlib1）+ **ScummVM 資料檔**（themes/*.zip、*.dat、fonts*.dat）；`.bat` 設 `--themepath=data --extrapath=data --music-driver=mt32`。

### macOS universal（GitHub Action，**踩雷最多**）
**照 kb `mac-app-cross-pack` / 已驗證的 qfg2 workflow**：
- **[HARD] 只用 `macos-14`**（macos-13 Intel 退役、永久 queued）；x86_64 弧走 **`arch -x86_64`(Rosetta)** native 各編一次 + **`lipo -create`**（單次雙 `-arch` 會炸 configure 版本解析）。
- **[HARD] 自源碼編 pinned SDL2 2.30.9**（**別 brew**：2026 起是 sdl2-compat→dlopen SDL3→黑畫面）。防呆：dylib **>1MB**、`otool` 不見 SDL3。
- **[HARD] `CXXFLAGS/LDFLAGS` 當環境變數前綴**（ScummVM configure 非 autoconf）：`CXXFLAGS="-arch $A -mmacosx-version-min=11.0" ./configure --enable-engine=agos $LEAN_FLAGS --with-sdl-prefix=$P`。**Linux 端先驗一次精簡旗標**（AGOS 在 `--disable-zlib` 等 LEAN 下中文正常）省一輪 runner。
- **[HARD] MT-32 保持 enable**：斷言 `config.h` 有 `USE_MT32EMU`。
- `make scummvm-static` 兩弧 → `lipo` → `make bundle` 出 `ScummVM.app` → 換上 universal binary。
- **[HARD] SDL2 dylib 也要 `lipo` 進 `.app/Contents/Frameworks` + 兩弧各 `install_name_tool -change ...@executable_path/../Frameworks... + `codesign --force`**（否則另一半 arch 閃退；別用 dylibbundler——per-arch+lipo 會退化單弧，且自編 dylib 的 @rpath 會讓它互動 hang）。
- 驗證：`lipo -info` 主程式與 SDL2 都雙弧；`otool -L` 無 `$RUNNER_TEMP`/`/Users/runner` 殘留。產 `.tar.gz`(繞 APFS)+`.dmg`。

### MT-32 真實配樂
`--enable-mt32emu` + ROM(`MT32_CONTROL.ROM`/`MT32_PCM.ROM`)放 extrapath/遊戲夾 + `--music-driver=mt32`。ScummVM 找不到 CM32L 會 "Falling back to MT32"（正常）。**[HARD] ROM 與遊戲原檔一律 gitignore**、只留本機 `dist-all/`。

### [HARD] leak-scan
遊戲原檔（`GAMEPC`/`TABLES*`/`TEXT*`/`*.VGA`/floppy 影像）、`*.ROM`、含版權配樂的影片一律 gitignore；push 前 grep 複檢。`*.mp4`/`*.gif` 也 gitignore（推廣片作 Release 素材，不入 git）。

---

## §8 推廣片（原版真實配樂 + 實機畫面）

- **[HARD] 用原版真實素材**（MT-32），不自產配樂（`rulebook/93`）；**要有實際遊玩畫面**（動的水晶球/逐字浮現對白/即時地圖疊層），證明非靜態改圖。
- **A/V 同步錄**：docker(capture image) + `Xvfb x16` + PulseAudio `module-null-sink` + `SDL_AUDIODRIVER=pulseaudio`；`ffmpeg -f x11grab -i :99 -f pulse -i v.monitor ... mp4`。音量偵測 `volumedetect` 確認有聲。
- **剪接**：Noto CJK 標題/字幕卡（ImageMagick）+ `ffmpeg concat filter`（各段 `scale=640:400,fps=15,format=yuv420p,setsar=1`）；**MT-32 連續配樂床**（取一段對白 clip 音軌鋪底，避免逐段跳音）。
- **就地換卡**（不重錄）：`ffmpeg` trim 前段 + loop 新卡 4s + concat，音軌 `-c:a copy` 沿用。

---

## §9 dev-setup 接續包
- `scripts/dev_setup.sh`：一鍵 建 image→取 ScummVM v2.9.1→套 `agos-cht.patch`→編→檢查資產（`git apply --check --reverse` 判是否已套）。
- `docs/DEV_SETUP.md`：佈局/改譯文重烘 `.tab`/改引擎重生 patch(`git diff HEAD -- engines/agos`)/headless 驗證/打包/延伸。

---

## §10 硬規則速查
- [HARD] AGOS 必 patch 引擎（非零 patch）；`// 非上游` gate、OR PC98、不破壞上游。
- [HARD] Big5；DCJK 索引 `(lead-0x81)*157+trailOffset`；hex 用 Python 產。
- [HARD] 公開 repo patch-only；遊戲/ROM/版權配樂/影片不入庫。
- [HARD] dump oracle 未翻歸零才算完成，不自稱條數。
- [HARD] 硬編碼 UI（動詞/存讀檔）加 ZH 分支；VGA 美術字用疊層覆蓋。
- [HARD] `_scaleBuf` 疊層要主動清（一次性疊字配一次性清）；別用 zone*1000+image 當唯一 ID（用閂鎖）。
- [HARD] headless：Xvfb x16 + SDL_AUDIODRIVER=dummy。
- [HARD] macOS：只 macos-14 + Rosetta x86_64；自編 pinned SDL2（別 brew）；configure flags 當環境變數；SDL2 lipo 進 Frameworks + install_name_tool + codesign。
- [HARD] MT-32 用 mt32emu + ROM + music-driver=mt32；ROM 不入庫。
- [HARD] 戰鬥類作弊先評估（VGA 層無乾淨 hook）再承諾；引擎行為以 dump/實機當 oracle，不憑記憶。
- [HARD] 背景 agent/CI 監看有界、禁 sentinel 輪詢；派便宜 agent 監 CI（`rulebook/35`）。

---

## §11 換一款 AGOS 遊戲：檢查清單
1. [ ] `--list-games` 確認 gameid+subengine(`GType_*`)；檔案指紋（`GAMEPC`/`STRIPPED.TXT`/`TEXT*`/`TABLES*`/`START`）確認 AGOS。
2. [ ] **反組譯確認該 subengine 文字/UI 路徑**（字串走 `getStringPtrByID`？對白 talk sprite 還是文字視窗？動詞是硬編碼還是烘進 VGA？防拷 script）。
3. [ ] floppy vs CD 字幕完整度（talkie 可能缺字幕，缺就 floppy 融合；floppy-only 免）。
4. [ ] `extract_floppy_text.py` 抽 A/B、對 GAMEPC stringTableNum。
5. [ ] 統一譯名表→fan-out 翻→校對+非 Big5 掃描。
6. [ ] 烘 24/16 DCJK。
7. [ ] 對位 `agos-cht.patch`：通用組件直接套，subengine 專屬（verb/talk/GType/防拷）重對位。
8. [ ] 編 patched ScummVM→注入→dump oracle 歸零+headless 截圖。
9. [ ] （選）現代友善化：先 RE 資料模型（變數/item flag/房間圖），疊層作弊；戰鬥類先評估可行性。
10. [ ] 三平台打包（帶 patched 引擎+資料檔+MT-32）+ leak-scan。
11. [ ] README（雜誌風 `80`）、手冊/攻略、推廣片（原版配樂+實機）、dev-setup。
12. [ ] 公開 repo 只推 patch-only。

---

## 參考案例
- **Simon the Sorcerer**（GType_SIMON1）：CD 語音+floppy 字幕融合、12 格 verb 面板覆蓋、hi-res 雙層。
- **Waxworks / 蠟像館之謎**（GType_WW）：github.com/wicanr2/waxworks_dos_cht — floppy-only、Elvira2 系介面、烘進 VGA 的 verb 條、現代友善化（動態地圖/除霧/無敵/噴火槍無限/給物/標題中文）、三平台+MT-32、推廣片、macOS CI（單 macos-14+Rosetta+自編 SDL2）。
