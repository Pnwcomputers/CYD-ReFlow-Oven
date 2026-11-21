// Display and touch for each supported board. The rest of the firmware draws on
// `gfx` (a TFT_eSPI or a full-screen TFT_eSprite), calls displayFlush() after
// drawing, and reads touch through touchRead().
#pragma once
#include <Arduino.h>
#include <TFT_eSPI.h>
#include <Preferences.h>
#include "config.h"

static int W = 320, H = 240;

#if defined(BOARD_FREENOVE_S3_35)
// Freenove's own TFT_eSPI build (Libraries/FNK0104N in their repo) provides the
// ST77922 QSPI driver and its integrated touch. Draw into a full-screen sprite in
// PSRAM and push it to the panel, as Freenove's examples do.
#include "ST77922.h"
#include "ST77922_Touch.h"
static TFT_eSPI tftBase;
static TFT_eSprite canvas(&tftBase);
static ST77922 panel;
static ST77922_TOUCH panelTouch;
static TFT_eSPI& gfx = canvas;
static bool canvasDirty = false;

static void displayInit(Preferences&, bool) {
  panel.Init();
  panel.Set_Rotation(TFT_ROTATION);
  W = panel.Get_Width();
  H = panel.Get_Height();
  canvas.setColorDepth(16);
  if (!canvas.createSprite(W, H)) {
    Serial.println("# FATAL: no PSRAM for the frame buffer. Tools > PSRAM: OPI PSRAM");
  }
  canvas.setSwapBytes(true);
  panelTouch.init();
  panelTouch.Set_Rotation(TFT_ROTATION);
}
static void markDirty() { canvasDirty = true; }
static void displayFlush() {
  if (!canvasDirty) return;
  canvasDirty = false;
  panel.Fill_Colors(0, 0, W, H, (uint16_t*)canvas.getPointer());
}
static bool touchRead(uint16_t& x, uint16_t& y) {
  if (!panelTouch.Get_Touch()) return false;
  bool got = false;
  for (int i = 0; i < panelTouch.max_points; i++) {
    if (!got && (panelTouch.touch.x[i] > 0 || panelTouch.touch.y[i] > 0)) {
      x = panelTouch.touch.x[i]; y = panelTouch.touch.y[i]; got = true;
    }
    panelTouch.touch.x[i] = 0; panelTouch.touch.y[i] = 0;
  }
  return got;
}

#elif defined(BOARD_CROWPANEL_28)
// Stock TFT_eSPI with Elecrow's User_Setup (see README). Resistive touch via
// TFT_eSPI, calibrated once and stored in flash.
static TFT_eSPI tftBase;
static TFT_eSPI& gfx = tftBase;

static void displayInit(Preferences& prefs, bool) {
  tftBase.init();
  tftBase.setRotation(TFT_ROTATION);
  pinMode(TFT_BL, OUTPUT);
  digitalWrite(TFT_BL, HIGH);
  W = tftBase.width();
  H = tftBase.height();
  // Hold a finger on the screen during boot to recalibrate touch.
  uint16_t tx, ty, cal[5];
  bool force = tftBase.getTouch(&tx, &ty);
  prefs.begin("reflow", false);
  bool have = prefs.getBytes("tcal", cal, sizeof(cal)) == sizeof(cal);
  if (have && !force) {
    tftBase.setTouch(cal);
  } else {
    tftBase.fillScreen(TFT_BLACK);
    tftBase.setTextDatum(MC_DATUM);
    tftBase.setTextColor(TFT_WHITE, TFT_BLACK);
    tftBase.drawString("Touch the corners as indicated", W / 2, H / 2, 2);
    tftBase.calibrateTouch(cal, TFT_MAGENTA, TFT_BLACK, 15);
    prefs.putBytes("tcal", cal, sizeof(cal));
  }
  prefs.end();
}
static void markDirty() {}
static void displayFlush() {}
static bool touchRead(uint16_t& x, uint16_t& y) { return tftBase.getTouch(&x, &y); }
#endif
