#!/bin/bash
# 在錄製期間跑: 前段讓開場自動播(素材), 後段觸發作弊疊層
sleep 56
xdotool key --clearmodifiers Tab; sleep 5      # 動態地圖
xdotool key --clearmodifiers F8;  sleep 5      # 除霧全圖
xdotool key --clearmodifiers F6;  sleep 4      # 給予物品
xdotool key --clearmodifiers F7;  sleep 5      # 無敵模式
xdotool key --clearmodifiers Tab; sleep 2      # 關地圖
# 再等一段抓後續場景(水晶球/埃及)
sleep 20
xdotool key --clearmodifiers Tab; sleep 6
xdotool key --clearmodifiers F8;  sleep 6
