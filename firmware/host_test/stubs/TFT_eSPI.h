// Screen stub: draws nothing, but remembers every string so the test can check
// that text does not run into other text or under a button.
#pragma once
#include <stdint.h>
#include "sim.h"
#define TFT_BLACK 0
#define TFT_WHITE 0xFFFF
#define TFT_RED 0xF800
#define TFT_GREEN 0x07E0
#define TFT_YELLOW 0xFFE0
#define TFT_CYAN 0x07FF
#define TFT_MAGENTA 0xF81F
#ifndef TFT_BL
#define TFT_BL 27
#endif
enum { TL_DATUM, TC_DATUM, TR_DATUM, ML_DATUM, MC_DATUM, MR_DATUM };

// Character widths of TFT_eSPI's built-in fonts 2 and 4 (chars 32..127), from
// Fonts/Font16.c and Fonts/Font32rle.c in Bodmer/TFT_eSPI. Font 1 is 6 px wide.
static const unsigned char STUB_W_F2[96] = {
  6, 3, 4, 9, 8, 9, 9, 3,   7, 7, 8, 6, 3, 6, 5, 7,   8, 8, 8, 8, 8, 8, 8, 8,   8, 8, 3, 3, 6, 6, 6, 8,
  9, 8, 8, 8, 8, 8, 8, 8,   8, 4, 8, 8, 7, 10, 8, 8,  8, 8, 8, 8, 8, 8, 8, 10,  8, 8, 8, 4, 7, 4, 7, 9,
  4, 7, 7, 7, 7, 7, 6, 7,   7, 4, 5, 6, 4, 8, 7, 8,   7, 8, 6, 6, 5, 7, 8, 8,   6, 7, 7, 5, 3, 5, 8, 6};
static const unsigned char STUB_W_F4[96] = {
  5, 8, 8, 19, 14, 21, 17, 6,       8, 8, 12, 10, 7, 8, 7, 8,
  14, 14, 14, 14, 14, 14, 14, 14,   14, 14, 7, 7, 14, 9, 14, 13,
  25, 16, 17, 18, 18, 16, 15, 19,   18, 6, 13, 17, 13, 21, 18, 19,
  16, 19, 17, 16, 14, 18, 15, 23,   15, 16, 16, 9, 13, 9, 12, 13,
  9, 14, 15, 13, 15, 14, 8, 15,     15, 6, 6, 12, 6, 22, 15, 15,
  15, 15, 8, 12, 7, 14, 12, 18,     13, 13, 12, 13, 13, 13, 15, 1};

struct TFT_eSPI {
  int datum = TL_DATUM, padX = 0;
  void init() {}
  void setRotation(int) {}
  int width() { return sim::screenW; }
  int height() { return sim::screenH; }
  void fillScreen(uint16_t) { sim::texts.clear(); }
  void fillRect(int, int, int, int, uint16_t) {}
  void drawRect(int, int, int, int, uint16_t) {}
  void fillRoundRect(int, int, int, int, int, uint16_t) {}
  void drawRoundRect(int, int, int, int, int, uint16_t) {}
  void setTextColor(uint16_t, uint16_t) {}
  void setTextColor(uint16_t) {}
  void setTextDatum(int d) { datum = d; }
  void setTextPadding(int w) { padX = w; }
  static int fontHeight(int font) { return font == 4 ? 26 : font == 2 ? 16 : 8; }
  int textWidth(const char* s, int font) {
    int w = 0;
    for (; *s; s++) {
      unsigned c = (unsigned char)*s;
      if (font == 1 || c < 32 || c > 127) w += 6;
      else w += font == 4 ? STUB_W_F4[c - 32] : STUB_W_F2[c - 32];
    }
    return w;
  }
  // Records the pixel box the text (and its padding) covers.
  void drawString(const char* s, int x, int y, int font) {
    int w = textWidth(s, font), h = fontHeight(font);
    int box = padX > w ? padX : w;
    int x0 = x, y0 = y;
    if (datum == TC_DATUM || datum == MC_DATUM) x0 = x - w / 2 - (box - w) / 2;
    if (datum == TR_DATUM || datum == MR_DATUM) x0 = x - box;
    if (datum == ML_DATUM || datum == MC_DATUM || datum == MR_DATUM) y0 = y - h / 2;
    sim::texts.push_back({s, x0, y0, x0 + box, y0 + h, font, datum});
  }
  void drawNumber(long, int, int, int) {}
  void drawFastHLine(int, int, int, uint16_t) {}
  void drawLine(int, int, int, int, uint16_t) {}
  void drawPixel(int, int, uint16_t) {}
  bool getTouch(uint16_t* x, uint16_t* y) { if (sim::touchDown) { *x = sim::touchX; *y = sim::touchY; } return sim::touchDown; }
  void setTouch(uint16_t*) {}
  void calibrateTouch(uint16_t* cal, uint16_t, uint16_t, int) { for (int i = 0; i < 5; i++) cal[i] = (uint16_t)(300 + i); }
};
struct TFT_eSprite : TFT_eSPI {
  TFT_eSprite(TFT_eSPI*) {}
  void setColorDepth(int) {}
  void* createSprite(int, int) { return this; }
  void setSwapBytes(bool) {}
  void* getPointer() { return nullptr; }
};
