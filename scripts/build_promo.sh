#!/bin/bash
set -e
PROJ="/home/anr2/scummvm/waxworks/workplace"
docker run --rm -v "$PROJ:/work" -w /work/promo waxworks-capture bash -c '
set -e
FONT=/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc
mk(){ # mk <out> <大字> <小字>
  convert -size 640x400 xc:black \
    -fill "#b0000f" -font "$FONT" -pointsize 46 -gravity north -annotate +0+90 "$2" \
    -fill "#d8d0c0" -font "$FONT" -pointsize 22 -gravity center -annotate +0+40 "$3" out_$1.png
}
convert -size 640x400 xc:black \
  -fill "#c01018" -font "$FONT" -pointsize 60 -gravity center -annotate +0-60 "蠟像館之謎" \
  -fill "#e8e0d0" -font "$FONT" -pointsize 26 -gravity center -annotate +0+20 "WAXWORKS · 繁體中文版" \
  -fill "#9a9488" -font "$FONT" -pointsize 18 -gravity center -annotate +0+70 "1992 Horrorsoft · ScummVM 引擎補丁 · MT-32 原音" out_title.png
mk cap1 "全中文對白" "原生點陣中文 · 逐字浮現 · 原版 MT-32 配樂"
mk cap2 "現代玩家友善化" "動態地圖 · 除霧全圖 · 無敵模式 · 噴火槍無限 · 一鍵給物"
convert -size 640x400 xc:black \
  -fill "#d8d0c0" -font "$FONT" -pointsize 30 -gravity center -annotate +0-40 "只散佈補丁 · 尊重原作版權" \
  -fill "#b0000f" -font "$FONT" -pointsize 24 -gravity center -annotate +0+20 "致敬 1992 · 華語圈的一封情書" \
  -fill "#8a8478" -font "$FONT" -pointsize 18 -gravity center -annotate +0+70 "github.com/wicanr2/waxworks_dos_cht" out_end.png

# 剪接: title(4) 片1credits(7) cap1(3) 片2前廳(12) 片3水晶球(12) cap2(4) 片4作弊(22) end(4) = 68s
ffmpeg -y -loglevel error \
 -loop 1 -t 4 -i out_title.png \
 -ss 6  -t 7  -i dialogue_clip.mp4 \
 -loop 1 -t 3 -i out_cap1.png \
 -ss 66 -t 12 -i dialogue_clip.mp4 \
 -ss 95 -t 12 -i dialogue_clip.mp4 \
 -loop 1 -t 4 -i out_cap2.png \
 -ss 57 -t 22 -i master_demo.mp4 \
 -loop 1 -t 4 -i out_end.png \
 -ss 0 -t 68 -i dialogue_clip.mp4 \
 -filter_complex "
  [0:v]scale=640:400,fps=15,format=yuv420p,setsar=1[v0];
  [1:v]scale=640:400,fps=15,format=yuv420p,setsar=1[v1];
  [2:v]scale=640:400,fps=15,format=yuv420p,setsar=1[v2];
  [3:v]scale=640:400,fps=15,format=yuv420p,setsar=1[v3];
  [4:v]scale=640:400,fps=15,format=yuv420p,setsar=1[v4];
  [5:v]scale=640:400,fps=15,format=yuv420p,setsar=1[v5];
  [6:v]scale=640:400,fps=15,format=yuv420p,setsar=1[v6];
  [7:v]scale=640:400,fps=15,format=yuv420p,setsar=1[v7];
  [v0][v1][v2][v3][v4][v5][v6][v7]concat=n=8:v=1:a=0[vout]
 " \
 -map "[vout]" -map 8:a \
 -c:v libx264 -pix_fmt yuv420p -preset medium -crf 20 \
 -c:a aac -b:a 192k -shortest \
 蠟像館之謎_繁中版_推廣片.mp4
chown -R '"$(id -u):$(id -g)"' /work/promo
'
