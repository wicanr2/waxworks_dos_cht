# WORKLIST — 蠟像館之謎繁中化 進度與待辦

> 真相以 code / repo 為準（rulebook 63）。日期：2026-07-19。

## ✅ 已完成（v1，已 push 到 github.com/wicanr2/waxworks_dos_cht）

| 項目 | 狀態 | 證據 |
|---|---|---|
| 引擎判定：Waxworks = AGOS（非 SCUMM） | ✅ | 檔案指紋 GAMEPC/TEXTxx/TABLES；`agos:waxworks` |
| 抽字（668 字串表 + 919 對白 = 1585） | ✅ | `tools/extract_floppy_text.py`；文字模型同 Simon |
| 全文翻譯 + 統一譯名 + Big5 校對 | ✅ | `translations/zh.tsv`（1585 條，0 非 Big5） |
| Big5 16/24px 點陣字型 | ✅ | `fonts/waxworks_zh16.dcjk`、`_zh24.dcjk` |
| STAB 譯表 | ✅ | `fonts/waxworks_zh.tab` |
| AGOS 引擎 patch（11 檔 ~590 行） | ✅ | `patches/agos-cht.patch` + `cht_fusion.cpp/h` |
| hi-res 640×400 雙層畫布（PC98 機制） | ✅ | 實機截圖 crisp |
| Big5 繪字 + 描邊 + 亮度守門 | ✅ | `docs/img/*.png` |
| getBoxSize 繞過 checkFit 空白斷詞崩潰 | ✅ | 崩潰已修，實機無 crash |
| 防拷 `_copyProtection` 自動 bypass | ✅ | 開場免對密碼轉盤 |
| headless 實機驗證（對白/敘述/物件名全中文、無撞碼） | ✅ | `screenshots/`、`docs/img/` |
| Linux AppImage 完整版打包 + 自足驗證 | ✅ | `dist-all/Waxworks-CHT-FULL-x86_64.AppImage`（67M，含版權資料不入 git） |
| README（雜誌風三層 voice）+ 譯名對照 + 手冊研究 | ✅ | `README.md`、`docs/RESEARCH.md` |
| AGOS 通用中文化模板 | ✅ | `docs/CLAUDE-AGOS.md` |
| 公開 repo patch-only + leak-scan | ✅ | 已 push，無遊戲本體/版權素材 |

## ⏳ 待辦（v2 / 剩餘）

| 項目 | 說明 | 難度/風險 |
|---|---|---|
| **verb 圖示條中文** | 底部 verb 名（EXAMINE 等）不經 `getStringPtrByID`，來源不明（非 MENUS.DAT 字面、非字串表 213；疑在 GAMEPC verb vocab 區）。需先反組譯確認來源再攔截。**不要盲改 menus.cpp（whack-a-mole 風險）**。 | 中高（機制未明） |
| 存讀檔 base 硬字串 ZH | `saveload.cpp` base `fileError`（Save failed/Disk error 等）加 `ZH_TWN` 分支。WW 覆寫確認走 script（已中文）。 | 低 |
| 片頭 credits | 預繪 VGA 美術字（分類 F），保留英文（同 Simon 慣例）。依完整性可評估改圖。 | 高（改圖） |
| Windows 打包 | 交叉編 patched ScummVM + 帶 SDL2 DLL + ScummVM 執行期資料檔（主題/字型），launcher `.bat` 設 `--themepath`/`--extrapath`。參考 Simon `build_windows.sh`。 | 中 |
| macOS 打包 | Universal `.app` 需 CI（GitHub Actions mac runner，`lipo`/`otool`）或 `mac-app-cross-pack` skill。 | 中 |
| 推廣片 | x11grab 錄真實遊玩 + ffmpeg 合成；配樂錄**原版真實 AdLib/MT-32**（rulebook 93，不自產）；公開嵌靜音 GIF + 連 YouTube。 | 中 |
| dev-setup 接續包 | `dev-setup-bundle` skill 打可重建環境 + `claude -r` 接續。 | 低 |

## 重建環境（快速）
```bash
cd workplace
# 遊戲檔放 run_game/ (自備合法 Waxworks Floppy DOS)
docker build -t waxworks-build docker/
bash scripts/build_scummvm.sh          # 編 patched ScummVM(git apply patches/agos-cht.patch 後)
bash scripts/build_font.sh              # 烘 Big5 字型
python3 tools/build_translation.py translations/zh.tsv fonts/waxworks_zh.tab
cp fonts/waxworks_zh* run_game/
bash scripts/build_appimage.sh          # 產 AppImage
```

## 鐵則
- 公開 repo patch-only：遊戲原檔/ROM/版權配樂影片一律 gitignore，push 前 grep 複檢。
- 引擎行為斷言以 descumm/實機當 oracle。
- patch 集中 `// 非上游` 分支、旗標 gate、不破壞上游。
