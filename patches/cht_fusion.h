/* Simon the Sorcerer 繁體中文化 (CD 語音 + floppy 完整字幕 融合) — 非上游模組。
 * 資料: simon_zh24.dcjk (Big5 24x24 點陣), simon_zh.tab (id→Big5 譯表),
 *       simon_voice.map (floppy stringId→CD speechId 語音對映)。
 */
#ifndef AGOS_CHT_FUSION_H
#define AGOS_CHT_FUSION_H

#include "common/scummsys.h"
#include "common/hashmap.h"
#include "common/str.h"

namespace AGOS {

// Big5 線性索引 (與 build_cjk_font.py 對齊): (lead-0x81)*157 + trailOffset
inline bool chtIsBig5Lead(byte c) { return c >= 0x81 && c <= 0xFE; }

inline int chtBig5Index(byte lead, byte trail) {
	if (lead < 0x81 || lead > 0xFE)
		return -1;
	int to;
	if (trail >= 0x40 && trail <= 0x7E)
		to = trail - 0x40;
	else if (trail >= 0xA1 && trail <= 0xFE)
		to = 63 + (trail - 0xA1);
	else
		return -1;
	return (lead - 0x81) * 157 + to;
}

struct ChtFusion {
	// 字型 (24x24, 字幕/視窗文字用)
	byte *font = nullptr;      // DCJK glyph 區起點 (跳過 15-byte header)
	int fontW = 0, fontH = 0, fontBpr = 0;
	uint32 numGlyphs = 0;
	// 小字型 (16x16, 底部指令面板小格用)
	byte *font16 = nullptr;
	int fontW16 = 0, fontH16 = 0, fontBpr16 = 0;
	uint32 numGlyphs16 = 0;
	// 譯表: floppy stringId -> Big5 字串
	Common::HashMap<uint32, Common::String> table;
	// 語音: floppy stringId -> CD speechId
	Common::HashMap<uint32, uint16> voice;

	bool fontLoaded() const { return font != nullptr; }
	bool hasTable() const { return !table.empty(); }

	// 取得某 Big5 字的 glyph bitmap (fontBpr*fontH bytes), 找不到回 nullptr
	const byte *glyph(byte lead, byte trail) const {
		if (!font) return nullptr;
		int idx = chtBig5Index(lead, trail);
		if (idx < 0 || (uint32)idx >= numGlyphs) return nullptr;
		return font + (uint32)idx * fontBpr * fontH;
	}

	// 16x16 小字模版本 (指令面板用)
	const byte *glyph16(byte lead, byte trail) const {
		if (!font16) return nullptr;
		int idx = chtBig5Index(lead, trail);
		if (idx < 0 || (uint32)idx >= numGlyphs16) return nullptr;
		return font16 + (uint32)idx * fontBpr16 * fontH16;
	}
};

bool chtLoadFont(ChtFusion &fus, const char *filename);
bool chtLoadFont16(ChtFusion &fus, const char *filename);
bool chtLoadTable(ChtFusion &fus, const char *filename);
bool chtLoadVoiceMap(ChtFusion &fus, const char *filename);

} // namespace AGOS

#endif
