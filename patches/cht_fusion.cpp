/* Simon 繁中融合 — 載入器 (非上游) */
#include "agos/cht_fusion.h"
#include "common/file.h"
#include "common/debug.h"

namespace AGOS {

// 載入 DCJK 字型檔到 fus.font
bool chtLoadFont(ChtFusion &fus, const char *filename) {
	Common::File f;
	if (!f.open(filename))
		return false;
	byte hdr[15];
	if (f.read(hdr, 15) != 15)
		return false;
	if (memcmp(hdr, "DCJK", 4) != 0)
		return false;
	fus.fontW = hdr[5];
	fus.fontH = hdr[6];
	fus.fontBpr = hdr[7];
	fus.numGlyphs = READ_LE_UINT32(hdr + 11);
	uint32 dataSize = fus.numGlyphs * fus.fontBpr * fus.fontH;
	fus.font = (byte *)malloc(dataSize);
	if (!fus.font)
		return false;
	if (f.read(fus.font, dataSize) != dataSize) {
		free(fus.font);
		fus.font = nullptr;
		return false;
	}
	debug(0, "CHT: font %s loaded (%dx%d, %u glyphs)", filename, fus.fontW, fus.fontH, fus.numGlyphs);
	return true;
}

// 載入 16x16 DCJK 小字型到 fus.font16 (指令面板用)
bool chtLoadFont16(ChtFusion &fus, const char *filename) {
	Common::File f;
	if (!f.open(filename))
		return false;
	byte hdr[15];
	if (f.read(hdr, 15) != 15)
		return false;
	if (memcmp(hdr, "DCJK", 4) != 0)
		return false;
	fus.fontW16 = hdr[5];
	fus.fontH16 = hdr[6];
	fus.fontBpr16 = hdr[7];
	fus.numGlyphs16 = READ_LE_UINT32(hdr + 11);
	uint32 dataSize = fus.numGlyphs16 * fus.fontBpr16 * fus.fontH16;
	fus.font16 = (byte *)malloc(dataSize);
	if (!fus.font16)
		return false;
	if (f.read(fus.font16, dataSize) != dataSize) {
		free(fus.font16);
		fus.font16 = nullptr;
		return false;
	}
	debug(0, "CHT: panel font %s loaded (%dx%d, %u glyphs)", filename, fus.fontW16, fus.fontH16, fus.numGlyphs16);
	return true;
}

// 載入譯表 simon_zh.tab (STAB: magic, count, [id:4][len:2][big5..])
bool chtLoadTable(ChtFusion &fus, const char *filename) {
	Common::File f;
	if (!f.open(filename))
		return false;
	byte magic[4];
	if (f.read(magic, 4) != 4 || memcmp(magic, "STAB", 4) != 0)
		return false;
	uint32 count = f.readUint32LE();
	for (uint32 i = 0; i < count; i++) {
		uint32 id = f.readUint32LE();
		uint16 len = f.readUint16LE();
		Common::String s;
		for (uint16 k = 0; k < len; k++)
			s += (char)f.readByte();
		fus.table[id] = s;
	}
	debug(0, "CHT: translation table %s loaded (%u entries)", filename, count);
	return true;
}

// 載入語音對映 simon_voice.map (VMAP: magic, count, [id:4][speech:2])
bool chtLoadVoiceMap(ChtFusion &fus, const char *filename) {
	Common::File f;
	if (!f.open(filename))
		return false;
	byte magic[4];
	if (f.read(magic, 4) != 4 || memcmp(magic, "VMAP", 4) != 0)
		return false;
	uint32 count = f.readUint32LE();
	for (uint32 i = 0; i < count; i++) {
		uint32 id = f.readUint32LE();
		uint16 sp = f.readUint16LE();
		fus.voice[id] = sp;
	}
	debug(0, "CHT: voice map %s loaded (%u entries)", filename, count);
	return true;
}

} // namespace AGOS
