# 中文恐怖語音方案（規劃）

> 狀態：**規劃，尚未實作**。目標——為《蠟像館之謎》繁中版加入中文配音，音色偏恐怖，混用多種 TTS 來源讓不同角色有不同聲線。原版 Floppy/DOS 沒有任何語音軌，這是全新加上去的一層。

## 結論先行

- **可行**。注入點與播放基礎設施都現成：對白以 `getStringPtrByID(stringId)` 取字（CHT 已攔此處），AGOS `Sound` 類已內建 `playVoice()`/`playVoiceData()`/`_mixer`——talkie 版就是這樣發聲的。我們只要「字串 id → 預先合成好的音檔 → 丟進 mixer 播」。
- **最大工不在技術，在內容**：要決定「哪句、誰說、用什麼聲線」。這需要把對白按角色標記，並為每個角色配一組 TTS 引擎＋音色＋後製 profile。
- **建議走「多引擎分工」**：具名角色用可複製聲線的本地模型（GPT-SoVITS / Fish-Speech）求一致與可控恐怖感；雜魚 NPC 用 edge-tts(Azure zh-TW 神經音)求量產；怪物吼叫用 Bark 這類能發非語言恐怖聲的模型；少數高光時刻(叔叔亡靈遺言)可用 ElevenLabs 拉滿。全部再過 SoX/ffmpeg 混響＋變調，貼合墓穴/礦坑/古墓的空間感。
- **語音包獨立散佈**：數百句 × 壓縮後仍達數十 MB，作為選配 add-on，不進 patch、不進 git（同 ROM/遊戲原檔政策）。

---

## 一、注入與播放（技術落點）

| 環節 | 落點 | 說明 |
|---|---|---|
| 對白取字 | `engines/agos/string.cpp:115` `getStringPtrByID(uint16 stringId)` | 已是 CHT 注入 chokepoint；同一處即可在「開始顯示某句對白」時以 `stringId` 為 key 觸發語音 |
| 該不該配音 | id 範圍過濾 | 對白 TEXTxx 屬 type B（`id >= 0x8000`）；UI/verb/系統字（type A/D）不配音。實際再以「語音對應表有無此 id」為準 |
| 播放 | `Sound::playVoiceData()` / 直接用 `_mixer` | AGOS `Sound` 已有 `_mixer`、`playVoice`、`_hasVoiceFile`。新增一支 CHT 語音播放器：查 `voice/<id>.ogg`，用 `Audio::Mixer::kSpeechSoundType` 播；新句開始先停上一句 |
| 字幕同步 | 對白框停留 | AGOS 對白靠點擊/計時推進。配音時讓文字停留到音檔播完或玩家點擊（沿用現有 delay/等待機制，加一個「等語音結束」條件）|
| 開關 | 設定項 | `voice on/off`、語音音量；預設可關（尊重想聽原 MT-32 純樂的人）|

實作時新增類似 CHT 的旗標與一支 `chtPlayVoice(uint16 id)`，掛在對白顯示起點；音檔以 id 命名放進遊戲目錄的 `voice/` 子夾（同繁中字型的隨遊戲部署方式）。

### 待釐清

- **動態拼接句**：部分文字是變數/片段拼出來的，只配「完整靜態句」，拼接句略過或另設模板。
- **句子邊界**：一個對話可能分多頁（多次 `getStringPtrByID`）。需確認「一句語音 ↔ 一個 id」還是「一段對話 ↔ 多 id」，決定切音粒度。
- **角色歸屬**：`getStringPtrByID` 只給 id，不給「誰在講」。需另建 id→角色對應表（見第三節），這是最大人工。

---

## 二、TTS 來源選型（恐怖音色，多來源）

分工原則：**一致性/可控恐怖 → 本地聲線複製**；**量產 → 雲端神經音**；**非語言恐怖 → 生成式**；**高光 → 頂規商用**。

| 來源 | 類型 | 中文 | 恐怖適用性 | 成本/授權 | 定位 |
|---|---|---|---|---|---|
| **GPT-SoVITS** | 本地聲線複製 | 佳(中文原生) | 高：可用陰森參考音複製聲線，情緒穩定 | 免費/開源，本地 | **具名角色主力**（叔叔、管家、Molly、傑克）|
| **Fish-Speech** | 本地聲線複製 | 佳 | 高：中文表現好，可複製 | 免費/開源 | 具名角色備選/補位 |
| **Bark** | 生成式 | 可(zh) | 極高：能發喘息、低吼、非語言恐怖聲 | 免費/開源，本地 | **怪物/亡靈/氣氛人聲** |
| **edge-tts（Azure 神經音）** | 雲端(免費封裝) | 佳(zh-TW HsiaoChen/YunJhe 等) | 中：SSML 可調 pitch/rate、部分風格 | 免費(edge-tts)，本地跑 | **雜魚 NPC 量產基準線** |
| **Azure Speech（付費 SSML）** | 雲端 | 佳 | 中高：`style=whispering/fearful/angry/terrified` + pitch/rate | 付費，有商用條款 | 需要「情緒風格」時的雲端選項 |
| **ElevenLabs** | 雲端 | 佳(multilingual v2) | 極高：最自然、最具表現力 | 付費，量大較貴 | **少數高光**（開場水晶球遺言）|
| **Amazon Polly / Google TTS** | 雲端 | 有 zh 音 | 中 | 付費 | 備援/比稿 |
| **Piper** | 本地 | 有 zh 音 | 低-中：快但平 | 免費/開源 | 大量低優先句的快速填充 |

### 恐怖化手法（合成後統一過一層）

- **變調＋放慢**：SSML `pitch -3st ~ -6st`、`rate slow`；或 SoX `pitch`/`tempo` 後製，壓出低沉、遲緩、非人感。
- **空間殘響**：SoX `reverb`／ffmpeg `aecho`＋`aphaser`，依場景給不同 profile：古墓(長殘響)、礦坑(金屬回聲)、教堂(挑高冷響)、街巷(乾、近)。
- **共振峰位移(formant shift)**：讓亡靈/怪物聲脫離正常人聲，配 Bark 的低吼更佳。
- **輕失真/氣聲層**：疊一層 whisper 或 breath，塑造「貼耳低語」壓迫感（傑克、亡靈）。
- **音量/動態**：語音走 `kSpeechSoundType`，與 MT-32 樂軌分軌，避免蓋掉配樂。

### 角色 → 聲線初步對應（示意）

| 角色 | 聲線方向 | 引擎/後製 |
|---|---|---|
| 叔叔鮑里斯（水晶球亡靈）| 蒼老、空洞、長殘響、緩慢 | ElevenLabs 或 GPT-SoVITS + 長 reverb + pitch↓ |
| 管家（綠皮）| 正式中帶陰森、壓抑 | GPT-SoVITS + 輕 reverb |
| 弗拉迪米爾（死靈法師）| 低沉、威嚇、共振峰下移 | GPT-SoVITS/Bark + formant↓ + 失真 |
| 開膛手傑克 | 貼耳低語、氣聲、乾近 | GPT-SoVITS whisper 參考 + breath 層 |
| Molly | 女聲、驚惶 | Fish-SoVITS + Azure `fearful` 比稿擇優 |
| 殭屍/變種怪/怪物 | 非語言吼喘 | Bark + pitch↓ + 失真 |
| 旁白/系統敘述 | 低沉不祥、克制 | edge-tts zh-TW 男聲 + 輕 reverb |

---

## 三、內容流程（管線）

1. **抽對白**：從 `translations/zh.tsv` 篩出要配音的對白 id（TEXTxx / type B 的完整句），排除 UI、拼接句。
2. **角色標記**：建 `voice/lines.csv`（id, 中文, 角色, 場景, 引擎, 音色, 後製profile）。角色從腳本上下文/攻略推定，人工校。**這是主要工時。**
3. **合成**：`tools/build_voice.py`（規劃新增）依 lines.csv 逐句呼對應引擎合成 wav。
4. **後製**：SoX/ffmpeg 套該行的 profile（reverb/pitch/formant/breath）。
5. **編碼**：轉 Ogg Vorbis（ScummVM mixer 可解），命名 `voice/<id>.ogg`。
6. **索引與部署**：以 id 為檔名即天然索引；語音包解壓進遊戲目錄 `voice/`（同繁中字型部署）。
7. **引擎掛勾**：對白顯示起點查 `voice/<id>.ogg` 即播（第一節）。

---

## 四、分期

| 期 | 內容 | 產出 |
|---|---|---|
| **P0 概念驗證** | 挑 5–10 句關鍵台詞（開場水晶球遺言最優先），用 2–3 引擎各合一版比稿，定出各角色聲線與後製 profile | 比稿樣本 + 決策 |
| **P1 抽句＋標角色** | 篩對白 id、建 lines.csv、標角色/場景 | `voice/lines.csv` |
| **P2 合成管線** | `tools/build_voice.py` + 後製 profile 腳本 | 可批次產 ogg |
| **P3 引擎掛勾** | 語音播放器 + 字幕停留同步 + 設定開關 | patch 增量 |
| **P4 全量＋QA＋打包** | 全句合成、校聽、混音平衡、包成選配語音包 | `voice-pack.zip`（隨 Release）|

---

## 五、風險與注意

- **授權**：雲端 TTS(Azure/ElevenLabs/Polly)輸出多允許使用，但**商用/再散佈條款需逐家確認**；本地模型(GPT-SoVITS/Bark/Fish-Speech)無按次費用，但**須留意模型授權與聲線複製的倫理**（勿複製真實他人聲音；用合成/授權參考音）。
- **一致性**：同角色跨數十句要維持聲線，本地複製模型優於逐句雲端 API。
- **體積**：數百句壓縮後數十 MB，**獨立語音包**，不進 patch/git。
- **相容**：語音為**選配層**，預設可關；關閉時完全回到現有 MT-32 純樂體驗，不影響既有三平台包。
- **同步細節**：`getStringPtrByID` 的呼叫頻率與對白分頁行為需先實測，確定切音粒度後再全量合成，避免重工。

---

## 六、與現況的接點

- 注入點 `getStringPtrByID`、hi-res/CHT 疊層、隨遊戲部署資產的機制**都已就位**，語音只是再加一層資料＋一支播放器。
- 對白文字↔id 的對應已由 `translations/zh.tsv` 完成，語音直接複用同一組 id，不需重抽。
- 部署方式沿用繁中字型（放進遊戲目錄），三平台打包腳本只需多帶一個 `voice/` 夾。
