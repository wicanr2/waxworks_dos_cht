#!/usr/bin/env python3
# 把 UTF-8 譯表 (floppy_id <tab> 繁中) 編成引擎讀的 Big5 二進位表。
# 用法: python3 build_translation.py zh.tsv simon_zh.tab
#
# 輸出格式 (little-endian):
#   0  4  magic "STAB"
#   4  4  count
#   接著 count 筆: [id:4 LE][len:2 LE][big5 bytes]   (不含結尾 0)
import sys, struct

def main():
    src, out = sys.argv[1], sys.argv[2]
    entries = []
    warn = 0
    for ln, line in enumerate(open(src, encoding='utf-8'), 1):
        line = line.rstrip('\n')
        if not line or line.startswith('#'): continue
        if '\t' not in line: continue
        sid, zh = line.split('\t', 1)
        try:
            sid = int(sid)
        except ValueError:
            continue
        try:
            big5 = zh.encode('big5')
        except UnicodeEncodeError as e:
            warn += 1
            # 逐字元編碼, 不可編者以 '?' 代
            b = bytearray()
            for ch in zh:
                try: b += ch.encode('big5')
                except UnicodeEncodeError: b += b'?'
            big5 = bytes(b)
            print(f"  警告 line {ln} id={sid}: 有非 Big5 字元 → {e}", file=sys.stderr)
        entries.append((sid, big5))
    with open(out, 'wb') as f:
        f.write(b'STAB')
        f.write(struct.pack('<I', len(entries)))
        for sid, big5 in entries:
            f.write(struct.pack('<IH', sid, len(big5)))
            f.write(big5)
    print(f"寫入 {out}: {len(entries)} 條 (非Big5警告 {warn})")

if __name__ == '__main__':
    main()
