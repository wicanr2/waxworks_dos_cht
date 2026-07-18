# 動態地圖可行性評估（現代玩家友善化）

> 結論：**動態地圖可行，推薦路線**。Waxworks 迷宮是「房間圖(graph)」，牆壁/出口/道具/怪物全部可從引擎記憶體即時讀出；怪物固定放置（非隨機生成）。逆向證據見下。

## 資料模型（AGOS GType_WW，衍生自 Elvira2）
| 需求 | 來源（檔案:行） |
|---|---|
| 玩家所在房間 | `_currentRoom`（agos.h）/ `me()->parent`（items.cpp me()）|
| 牆/出口(北東南西上下) | 房間 Item 的 `SubRoom.roomExitStates`（16-bit，每方向 2 bits：00=牆，非零=門狀態 1開/2關/3鎖）。讀 `getExitOf`/`getDoorState`（rooms.cpp）|
| 相鄰格連線 | `SubRoom.roomExit[]` 目的房間 ID + 方向位移（0北1東2南3西4下5上，反向對 0↔2/1↔3/4↔5）→ BFS 佈 2D 座標 |
| 道具(寶物) | 走訪房間 child 鏈，篩 `SubObject` 且帶 `kOFIcon`(0x10) |
| 怪物 | 房間 child 中的生物 Item（class bit 待反組譯確認；**固定放置**）|
| 全迷宮牆壁(離線) | `STATELST` 1388 筆 room-state（8 bytes：itemID/state/classFlags/roomExitStates）|

## 怪物：固定 vs 隨機
**固定。** 引擎無「生成怪物」opcode；全部 Item(含怪物)預先烘在 GAMEPC + ROOMS0x，`loadRoomItems` 只是載入。`o_random`/`o_chance` 用於戰鬥擲骰，非生成。唯一保留：不排除「偽隨機遭遇」(o_chance 把固定怪 setItemParent 到你房間)，需 dumpAllSubroutines 確認——但**地圖不需要**。

## 做法（v1）
- **熱鍵開關**：照 `kActionToggleFightMode` 範本加 `_chtMapOn`（event.cpp 的 CUSTOM_ENGINE_ACTION switch）。
- **佈局**：從 `_currentRoom` BFS 走 exits，依方向位移給每房間 2D 座標（上下層分層或標記）。
- **繪製**：每房間畫一格 + `roomExitStates` 的牆線；當前房間高亮；有道具/怪物的房間標記。畫進 hi-res `_scaleBuf` 疊層（本專案 CHT 已證實 WW 可用）或獨立 window。
- **visited 集合**：進房間時記錄（`loadRoomItems`/`oww_goto` 掛鉤），存讀檔整合。

## 難度/風險
- 低-中。牆/出口/道具枚舉都是現成 API。
- 主要工作：房間圖→2D 佈局（處理上下層）、paletted 疊層選色避開 UI、visited 存讀檔。
- 需反組譯才能做的（非必要）：玩家朝向指北針箭頭、「此格必有怪 vs 機率遭遇」——切入 opcode MOVE_DIRN(54)/WHERE_TO(85)/DO_TABLE(143)。
