#!/usr/bin/env python3
# 抽取 Simon1 floppy 完整文字(以引擎的 id 模型:stringId<0x8000 字串表 + >=0x8000 對白)
# 用法: python3 tools/extract_floppy_text.py <floppy_dir> <out.tsv>
import sys, struct, os

def read_string_table(gamepc):
    d = open(gamepc, 'rb').read()
    string_tab_num = struct.unpack('>I', d[12:16])[0]
    text_size = struct.unpack('>I', d[16:20])[0]
    text_mem = d[20:20+text_size]
    parts = text_mem.split(b'\x00')
    # setupStringTable 依序切;最後可能有空尾
    strings = parts[:string_tab_num]
    return string_tab_num, strings

def read_stripped(stripped):
    d = open(stripped, 'rb').read()
    entries = []  # (name, baseMax)
    i = 0
    while i < len(d):
        j = d.find(b'\x00', i)
        if j < 0: break
        name = d[i:j].decode('latin1')
        base_max = struct.unpack('>H', d[j+1:j+3])[0]
        entries.append((name, base_max))
        i = j + 3
    return entries

def read_dialogue(floppy_dir, stripped_entries):
    # 對白 id 從 0x8000 起;每個 TEXTxx 覆蓋 [base_min, base_max)
    out = {}
    base_min = 0x8000
    for name, base_max in stripped_entries:
        path = os.path.join(floppy_dir, name)
        if not os.path.exists(path):
            base_min = base_max; continue
        d = open(path, 'rb').read()
        parts = d.split(b'\x00')
        n = base_max - base_min
        for k in range(n):
            txt = parts[k].decode('latin1') if k < len(parts) else ''
            out[base_min + k] = txt
        base_min = base_max
    return out

def main():
    floppy_dir, out_tsv = sys.argv[1], sys.argv[2]
    gamepc = os.path.join(floppy_dir, 'GAMEPC')
    stripped = os.path.join(floppy_dir, 'STRIPPED.TXT')
    n, strings = read_string_table(gamepc)
    entries = read_stripped(stripped)
    dial = read_dialogue(floppy_dir, entries)
    with open(out_tsv, 'w', encoding='utf-8') as f:
        f.write(f"# floppy 完整文字 id→text  (字串表 {n} 條, 對白 {len(dial)} 條)\n")
        for i, s in enumerate(strings):
            f.write(f"{i}\t{s.decode('latin1') if isinstance(s,bytes) else s}\n")
        for i in sorted(dial):
            f.write(f"{i}\t{dial[i]}\n")
    print(f"字串表: {n} 條, 對白: {len(dial)} 條, 合計 {n+len(dial)} 寫入 {out_tsv}")
    # 統計非空
    nonempty_tab = sum(1 for s in strings if s)
    nonempty_dial = sum(1 for v in dial.values() if v)
    print(f"非空: 字串表 {nonempty_tab}, 對白 {nonempty_dial}")

if __name__ == '__main__':
    main()
