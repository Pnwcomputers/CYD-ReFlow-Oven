// Reflow oven controller for the CYD reflow oven (board chosen in config.h).
//
// Heat path:  inlet -> Shelly 1PM Gen4 (master cutoff) -> SSR -> oven socket.
// This firmware: touchscreen UI, reflow profiles, PID + slow-PWM SSR control,
// safety aborts, and a Shelly watchdog (Switch.Set toggle_after) so the Shelly
// opens on its own if this board hangs or reboots.
//
// Setup and Arduino IDE settings per board: README.md in this folder.
// Settings: config.h. Profiles: profiles.h. Display/touch per board: board.h.

#include <Arduino.h>
#include <SPI.h>
#include <TFT_eSPI.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <math.h>
#include "config.h"
#include "profiles.h"
#include "board.h"
#include "driver/gpio.h"

// =====================================================================
// SSR drive. Never drive the pin to the "on" level except in ssrOn().
// =====================================================================
static volatile bool ssrState = false;

static void ssrOff() {
#if SSR_ACTIVE_LOW
  pinMode(SSR_PIN, INPUT);              // released: on-board pull-up -> SSR sees 0 V
#else
  pinMode(SSR_PIN, OUTPUT);
  digitalWrite(SSR_PIN, LOW);
#endif
  ssrState = false;
}

static void ssrOn() {
  pinMode(SSR_PIN, OUTPUT);
#if SSR_ACTIVE_LOW
  digitalWrite(SSR_PIN, LOW);           // sink -> SSR sees ~3.3 V
#else
  gpio_set_drive_capability((gpio_num_t)SSR_PIN, GPIO_DRIVE_CAP_3);  // strongest source
  digitalWrite(SSR_PIN, HIGH);
#endif
  ssrState = true;
}

// =====================================================================
// MAX6675 (bit-banged)
// =====================================================================
static uint8_t tcReadByte() {
  uint8_t d = 0;
  for (int i = 7; i >= 0; i--) {
    digitalWrite(TC_SCK, LOW);
    delayMicroseconds(10);
    if (digitalRead(TC_SO)) d |= (uint8_t)(1u << i);
    digitalWrite(TC_SCK, HIGH);
    delayMicroseconds(10);
  }
  return d;
}

// Degrees C, or NAN if the thermocouple is open or the frame is invalid.
static float tcRead() {
  digitalWrite(TC_CS, LOW);
  delayMicroseconds(10);
  uint16_t v = (uint16_t)tcReadByte() << 8;
  v |= tcReadByte();
  digitalWrite(TC_CS, HIGH);
  digitalWrite(TC_SCK, LOW);
  if (v == 0xFFFF || v == 0x0000) return NAN;   // SO stuck high/low: wiring fault
  if (v & 0x8000) return NAN;                   // dummy sign bit must be 0
  if (v & 0x0004) return NAN;                   // open thermocouple
  return (v >> 3) * 0.25f;
}

// =====================================================================
// Shared state between the control loop (core 1) and the Shelly task (core 0)
// =====================================================================
enum class Shelly : uint8_t { Unknown, On, Off, Error };
static volatile bool     shellyWantOn = false;     // control loop -> task
static volatile Shelly   shellyState = Shelly::Unknown;
static volatile uint8_t  shellyFailures = 0;
static volatile bool     wifiUp = false;
static volatile bool     runActive = false;        // published to Shelly KVS

static bool shellyGet(const String& path) {
  if (WiFi.status() != WL_CONNECTED) return false;
  HTTPClient http;
  http.setTimeout(SHELLY_HTTP_TIMEOUT_MS);
  http.setConnectTimeout(SHELLY_HTTP_TIMEOUT_MS);
  if (!http.begin(String("http://") + SHELLY_HOST + path)) return false;
  int code = http.GET();
  http.end();
  return code == 200;
}

static bool shellySetOn() {
  return shellyGet(String("/rpc/Switch.Set?id=0&on=true&toggle_after=") + SHELLY_TOGGLE_AFTER_S);
}
static bool shellySetOff() { return shellyGet("/rpc/Switch.Set?id=0&on=false"); }
static bool shellyPublish(bool active) {
  // Read by the Shelly supervisor script (shelly/reflow_supervisor.js).
  return shellyGet(String("/rpc/KVS.Set?key=reflow_active&value=") + (active ? "true" : "false"));
}

static void shellyTask(void*) {
  uint32_t lastBeat = 0, lastWifiTry = 0;
  bool published = false, publishedValue = false;
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  for (;;) {
    uint32_t now = millis();
    wifiUp = WiFi.status() == WL_CONNECTED;
    if (!wifiUp && now - lastWifiTry > 10000) {
      lastWifiTry = now;
      WiFi.reconnect();
    }

    if (shellyWantOn) {
      bool due = shellyState != Shelly::On || now - lastBeat >= SHELLY_HEARTBEAT_MS;
      if (due) {
        lastBeat = now;
        if (shellySetOn()) { shellyState = Shelly::On; shellyFailures = 0; }
        else { shellyState = Shelly::Error; if (shellyFailures < 255) shellyFailures++; }
      }
    } else if (shellyState != Shelly::Off) {
      // Keep trying to open the relay until the Shelly confirms.
      if (shellySetOff()) { shellyState = Shelly::Off; shellyFailures = 0; }
      else { shellyState = Shelly::Error; vTaskDelay(pdMS_TO_TICKS(1000)); }
    }

    bool a = runActive;
    if (wifiUp && (!published || a != publishedValue)) {
      if (shellyPublish(a)) { published = true; publishedValue = a; }
    }
    vTaskDelay(pdMS_TO_TICKS(200));
  }
}

// =====================================================================
// Controller state
// =====================================================================
enum class Mode : uint8_t { Idle, Arming, Running, Cooling, Done, Aborted };
static Mode mode = Mode::Idle;
static uint8_t profileIdx = 0;
static uint32_t runStartMs = 0, armStartMs = 0;
static float tempC = NAN;
static uint8_t badReads = 0;
static float duty = 0;
static float integ = 0, lastErr = 0;
static bool havePrevErr = false;
static uint32_t pwmWindowStart = 0;
static uint32_t lastTcMs = 0, lastControlMs = 0;
static uint32_t runawayStartMs = 0;
static float runawayStartTemp = 0;
static bool runawayTracking = false;
static char abortReason[64] = "";

static const Profile& prof() { return PROFILES[profileIdx]; }
// Profile clock. It stops while the oven is at full power and still more than
// PROFILE_HOLD_LAG_C behind the profile, so a slow oven still reaches each
// stage (the profile stretches instead of being cut short). MAX_RUN_MS and the
// runaway check still bound the run in wall-clock time.
static float profT = 0;
static float runSeconds() { return profT; }

static void abortRun(const char* why) {
  ssrOff();
  duty = 0;
  shellyWantOn = false;
  runActive = false;
  strncpy(abortReason, why, sizeof(abortReason) - 1);
  abortReason[sizeof(abortReason) - 1] = 0;
  mode = Mode::Aborted;
  Serial.printf("# ABORT: %s\n", why);
}

static void finishHeating() {
  ssrOff();
  duty = 0;
  shellyWantOn = false;      // heating is over: open the master relay too
  mode = Mode::Cooling;
  Serial.println("# heating done, cooling");
}

static void startRun() {
  integ = 0; lastErr = 0; havePrevErr = false; duty = 0;
  runawayTracking = false;
  abortReason[0] = 0;
  shellyWantOn = true;
  runActive = true;
  armStartMs = millis();
  mode = Mode::Arming;
  Serial.printf("# arming: %s\n", prof().name);
}

static void pidStep(float sp, float dt) {
  float err = sp - tempC;
  float deriv = havePrevErr ? (err - lastErr) / dt : 0;
  lastErr = err; havePrevErr = true;
  float p = PID_KP * err, d = PID_KD * deriv;
  float out = p + PID_KI * integ + d;
  // Anti-windup: integrate only when not pushing further into saturation.
  if (!((out >= 1 && err > 0) || (out <= 0 && err < 0))) integ += err * dt;
  integ = constrain(integ, -0.5f / PID_KI, 1.0f / PID_KI);
  out = p + PID_KI * integ + d;
  duty = constrain(out, 0.0f, 1.0f);
}

// Returns true if a safety check aborted the run.
static bool safetyChecks(float t, float spNow) {
  if (badReads >= TC_MAX_BAD_READS) { abortRun("Thermocouple open / not reading"); return true; }
  if (isnan(tempC)) return false;
  if (tempC > HARD_MAX_C) { abortRun("Over max temperature"); return true; }
  if (tempC > spNow + OVERSHOOT_ABORT_C && t > 30) { abortRun("Too far above profile"); return true; }
  if (millis() - runStartMs > MAX_RUN_MS) { abortRun("Max run time exceeded"); return true; }
  if (SHELLY_REQUIRED && shellyFailures >= 2) { abortRun("Lost contact with Shelly"); return true; }
  // Runaway / probe-out: heating hard for a minute with no temperature rise.
  if (duty >= RUNAWAY_DUTY) {
    if (!runawayTracking) { runawayTracking = true; runawayStartMs = millis(); runawayStartTemp = tempC; }
    else if (millis() - runawayStartMs >= RUNAWAY_WINDOW_MS) {
      if (tempC - runawayStartTemp < RUNAWAY_MIN_RISE_C) { abortRun("No temp rise: check probe"); return true; }
      runawayStartMs = millis(); runawayStartTemp = tempC;
    }
  } else {
    runawayTracking = false;
  }
  return false;
}

// =====================================================================
// UI (landscape; layout scales with the screen: 320x240 or 480x320)
// =====================================================================
Preferences prefs;

static const uint16_t C_BG = TFT_BLACK, C_FG = TFT_WHITE, C_DIM = 0x7BEF;
static const uint16_t C_PROFILE = 0x4A69, C_ACTUAL = TFT_RED, C_BTN = 0x2124;

struct Btn { int16_t x, y, w, h; const char* label; uint16_t color; };
static Btn BTN_PREV, BTN_NEXT, BTN_START, BTN_STOP, BTN_OK;
static int GX, GY, GW, GH;          // graph area
static int BAR_Y;                   // top of the bottom button bar

static void layout() {
  const int bh = H >= 300 ? 52 : 40, bw = W >= 480 ? 160 : 120, sw = W >= 480 ? 70 : 50;
  BAR_Y = H - bh - 4;
  BTN_PREV  = {4, (int16_t)BAR_Y, (int16_t)sw, (int16_t)bh, "<", C_BTN};
  BTN_NEXT  = {(int16_t)(8 + sw), (int16_t)BAR_Y, (int16_t)sw, (int16_t)bh, ">", C_BTN};
  BTN_START = {(int16_t)(W - bw - 4), (int16_t)BAR_Y, (int16_t)bw, (int16_t)bh, "START", 0x0400};
  BTN_STOP  = {(int16_t)(W - bw - 4), (int16_t)BAR_Y, (int16_t)bw, (int16_t)bh, "STOP", 0xA000};
  BTN_OK    = {(int16_t)(W - bw - 4), (int16_t)BAR_Y, (int16_t)bw, (int16_t)bh, "OK", C_BTN};
  GX = 30; GY = 34; GW = W - GX - 6; GH = BAR_Y - GY - 8;
}

static bool screenDirty = true;
static Mode drawnMode = Mode::Idle;
static int lastPlotX = -1;

static void drawBtn(const Btn& b) {
  gfx.fillRoundRect(b.x, b.y, b.w, b.h, 6, b.color);
  gfx.drawRoundRect(b.x, b.y, b.w, b.h, 6, C_DIM);
  gfx.setTextColor(C_FG, b.color);
  gfx.setTextDatum(MC_DATUM);
  gfx.drawString(b.label, b.x + b.w / 2, b.y + b.h / 2, 4);
  markDirty();
}
static bool hit(const Btn& b, uint16_t x, uint16_t y) {
  return x >= b.x && x < b.x + b.w && y >= b.y && y < b.y + b.h;
}

static float graphTMax() { return profileEnd(prof()) * 1.05f; }
static float graphCMax() { return max(250.0f, profilePeak(prof()) + 20.0f); }
static int gx(float t) { return GX + (int)(t / graphTMax() * GW); }
static int gy(float c) { return GY + GH - (int)(constrain(c, 0.0f, graphCMax()) / graphCMax() * GH); }

static void drawGraphFrame() {
  gfx.fillRect(GX, GY, GW + 1, GH + 1, C_BG);
  gfx.setTextDatum(MR_DATUM);
  gfx.setTextColor(C_DIM, C_BG);
  for (int c = 50; c < graphCMax(); c += 50) {
    gfx.drawFastHLine(GX, gy(c), GW, 0x18E3);
    gfx.drawNumber(c, GX - 3, gy(c), 1);
  }
  gfx.drawRect(GX, GY, GW + 1, GH + 1, C_DIM);
  const Profile& p = prof();
  for (int x = 0; x < GW; x++) {
    float t = (float)x / GW * graphTMax();
    float t2 = (float)(x + 1) / GW * graphTMax();
    gfx.drawLine(GX + x, gy(profileSetpoint(p, t)), GX + x + 1, gy(profileSetpoint(p, t2)), C_PROFILE);
  }
  markDirty();
}

static void drawHeader(const char* title) {
  gfx.fillRect(0, 0, W, 30, C_BG);
  gfx.setTextDatum(TL_DATUM);
  gfx.setTextColor(C_FG, C_BG);
  gfx.drawString(title, 4, 4, 2);
  markDirty();
}

static void drawIdle() {
  gfx.fillScreen(C_BG);
  drawHeader(prof().name);
  drawGraphFrame();
  drawBtn(BTN_PREV); drawBtn(BTN_NEXT); drawBtn(BTN_START);
}

static void drawRunFrame() {
  gfx.fillScreen(C_BG);
  drawHeader(prof().name);
  drawGraphFrame();
  drawBtn(BTN_STOP);
  lastPlotX = -1;
}

static void drawResult() {
  gfx.fillRect(0, BAR_Y - 2, W, H - BAR_Y + 2, C_BG);
  gfx.setTextDatum(TL_DATUM);
  if (mode == Mode::Aborted) {
    gfx.setTextColor(TFT_RED, C_BG);
    gfx.drawString("ABORTED", 4, BAR_Y, 2);
    gfx.setTextColor(C_FG, C_BG);
    gfx.drawString(abortReason, 4, BAR_Y + 20, 2);
  } else {
    gfx.setTextColor(TFT_GREEN, C_BG);
    gfx.drawString("Done", 4, BAR_Y + 6, 4);
  }
  drawBtn(BTN_OK);
}

static void drawCoolingNote() {
  gfx.fillRect(0, BAR_Y - 2, BTN_STOP.x - 4, H - BAR_Y + 2, C_BG);
  gfx.setTextDatum(TL_DATUM);
  gfx.setTextColor(TFT_CYAN, C_BG);
  gfx.drawString("Cooling: open the door slowly", 4, BAR_Y + 10, 2);
  markDirty();
}

static void drawStatus() {
  // Top-right: live temperature and status, refreshed in place.
  char buf[64];
  gfx.setTextDatum(TR_DATUM);
  gfx.setTextColor(isnan(tempC) ? TFT_RED : TFT_YELLOW, C_BG);
  if (isnan(tempC)) snprintf(buf, sizeof(buf), "  --- C");
  else snprintf(buf, sizeof(buf), "  %5.1f C", tempC);
  gfx.drawString(buf, W - 4, 2, 4);

  gfx.setTextDatum(TL_DATUM);
  gfx.setTextColor(C_DIM, C_BG);
  const char* sh = shellyState == Shelly::On ? "on" : shellyState == Shelly::Off ? "off"
                 : shellyState == Shelly::Error ? "ERR" : "?";
  if (mode == Mode::Running || mode == Mode::Cooling || mode == Mode::Arming) {
    float t = mode == Mode::Arming ? 0 : runSeconds();
    const char* phase = mode == Mode::Arming ? "arming" : mode == Mode::Cooling ? "COOLING"
                      : t < prof().reflow_start_s ? "preheat/soak" : "REFLOW";
    snprintf(buf, sizeof(buf), "%3ds SP%4.0f %3d%% %s Shelly:%s     ", (int)t,
             profileSetpoint(prof(), t), (int)(duty * 100), phase, sh);
    gfx.drawString(buf, 4, 22, 1);
  } else if (mode == Mode::Idle) {
    snprintf(buf, sizeof(buf), "WiFi:%s Shelly:%s     ", wifiUp ? "ok" : "--", sh);
    gfx.drawString(buf, 4, 22, 1);
  }
  markDirty();
}

static void plotPoint() {
  if (isnan(tempC)) return;
  float t = runSeconds();
  int x = gx(t), y = gy(tempC);
  if (x > GX + GW) return;
  static int lastY = 0;
  if (lastPlotX >= 0) gfx.drawLine(lastPlotX, lastY, x, y, C_ACTUAL);
  else gfx.drawPixel(x, y, C_ACTUAL);
  lastPlotX = x; lastY = y;
  markDirty();
}

// Returns true once per press (edge), with coordinates.
static bool touchPressed(uint16_t& x, uint16_t& y) {
  static bool wasDown = false;
  static uint32_t lastPoll = 0;
  if (millis() - lastPoll < 30) return false;
  lastPoll = millis();
  uint16_t tx = 0, ty = 0;
  bool down = touchRead(tx, ty);
  bool edge = down && !wasDown;
  wasDown = down;
  if (edge) { x = tx; y = ty; }
  return edge;
}

static void beep(int ms) {
  if (BUZZER_PIN < 0) return;
  // Optional: needs a speaker on the board's speaker connector.
  ledcAttach(BUZZER_PIN, 2000, 8);
  ledcWrite(BUZZER_PIN, 128);
  delay(ms);
  ledcWrite(BUZZER_PIN, 0);
  ledcDetach(BUZZER_PIN);
  pinMode(BUZZER_PIN, INPUT);
}

// =====================================================================
// Setup / loop
// =====================================================================
void setup() {
  ssrOff();                                // first thing: SSR off
  pinMode(TC_CS, OUTPUT);  digitalWrite(TC_CS, HIGH);
  pinMode(TC_SCK, OUTPUT); digitalWrite(TC_SCK, LOW);
  pinMode(TC_SO, INPUT);
  Serial.begin(115200);
  Serial.println("\n# Reflow controller. CSV: t_s,setpoint_c,temp_c,duty_pct,ssr,mode");

  displayInit(prefs, false);
  layout();

  prefs.begin("reflow", true);
  profileIdx = prefs.getUChar("prof", 0) % NUM_PROFILES;
  prefs.end();

  xTaskCreatePinnedToCore(shellyTask, "shelly", 8192, nullptr, 1, nullptr, 0);
  shellyWantOn = false;                     // make sure the Shelly is off at boot
  screenDirty = true;
}

void loop() {
  uint32_t now = millis();

  // --- Temperature ---
  if (now - lastTcMs >= TC_PERIOD_MS) {
    lastTcMs = now;
    float t = tcRead();
    if (isnan(t)) { if (badReads < 255) badReads++; if (badReads >= TC_MAX_BAD_READS) tempC = NAN; }
    else { badReads = 0; tempC = isnan(tempC) ? t : tempC * 0.6f + t * 0.4f; }
  }

  // --- Hard ceiling in every mode ---
  if (!isnan(tempC) && tempC > HARD_MAX_C && ssrState) abortRun("Over max temperature");

  // --- State machine ---
  switch (mode) {
    case Mode::Idle: case Mode::Done: case Mode::Aborted:
      ssrOff();
      break;

    case Mode::Arming:
      ssrOff();
      if (badReads >= TC_MAX_BAD_READS || isnan(tempC)) { abortRun("Thermocouple open / not reading"); break; }
      if (!SHELLY_REQUIRED || shellyState == Shelly::On) {
        runStartMs = millis();
        profT = 0;
        pwmWindowStart = runStartMs;
        lastControlMs = 0;
        mode = Mode::Running;
        screenDirty = true;
        beep(100);
        Serial.println("# running");
      } else if (now - armStartMs > 10000) {
        abortRun("Shelly not reachable");
      }
      break;

    case Mode::Running: {
      float t = runSeconds();
      float spNow = profileSetpoint(prof(), t);
      if (now - lastControlMs >= CONTROL_PERIOD_MS) {
        float dt = lastControlMs ? (now - lastControlMs) / 1000.0f : 0;
        lastControlMs = now;
        if (safetyChecks(t, spNow)) break;
        bool lagging = duty >= 0.99f && !isnan(tempC) && tempC < spNow - PROFILE_HOLD_LAG_C;
        if (!lagging) profT += dt;
        if (dt <= 0) dt = CONTROL_PERIOD_MS / 1000.0f;
        if (!isnan(tempC)) pidStep(profileSetpoint(prof(), t + SETPOINT_LOOKAHEAD_S), dt);
        Serial.printf("%.1f,%.1f,%.2f,%d,%d,run\n", t, spNow, tempC, (int)(duty * 100), ssrState ? 1 : 0);
        plotPoint();
      }
      if (t >= prof().cool_start_s) { finishHeating(); beep(300); break; }
      // Slow PWM
      if (now - pwmWindowStart >= PWM_WINDOW_MS) pwmWindowStart += PWM_WINDOW_MS;
      if ((now - pwmWindowStart) < duty * PWM_WINDOW_MS && duty > 0.01f) ssrOn(); else ssrOff();
      break;
    }

    case Mode::Cooling: {
      ssrOff();
      float t = runSeconds();
      if (now - lastControlMs >= CONTROL_PERIOD_MS) {
        profT += (now - lastControlMs) / 1000.0f;
        lastControlMs = now;
        Serial.printf("%.1f,%.1f,%.2f,0,0,cool\n", t, profileSetpoint(prof(), t), tempC);
        plotPoint();
      }
      if ((!isnan(tempC) && tempC < 50) || t > profileEnd(prof()) + 300) {
        runActive = false;
        mode = Mode::Done;
        beep(150); delay(100); beep(150);
        Serial.println("# done");
      }
      break;
    }
  }

  // --- UI ---
  if (mode != drawnMode) { screenDirty = true; }
  if (screenDirty) {
    screenDirty = false;
    if (mode == Mode::Idle) drawIdle();
    else if (mode == Mode::Arming || (mode == Mode::Running && drawnMode != Mode::Arming))
      drawRunFrame();
    else if (mode == Mode::Done || mode == Mode::Aborted) {
      if (drawnMode == Mode::Idle) drawRunFrame();
      drawResult();
    } else if (mode == Mode::Cooling) {
      drawCoolingNote();
    }
    drawnMode = mode;
  }
  static uint32_t lastStatus = 0, lastFlush = 0;
  if (now - lastStatus >= 500) { lastStatus = now; drawStatus(); }
  if (now - lastFlush >= 200) { lastFlush = now; displayFlush(); }

  uint16_t x, y;
  if (touchPressed(x, y)) {
    if (mode == Mode::Idle) {
      if (hit(BTN_PREV, x, y) || hit(BTN_NEXT, x, y)) {
        profileIdx = (profileIdx + (hit(BTN_NEXT, x, y) ? 1 : NUM_PROFILES - 1)) % NUM_PROFILES;
        prefs.begin("reflow", false); prefs.putUChar("prof", profileIdx); prefs.end();
        screenDirty = true;
      } else if (hit(BTN_START, x, y)) {
        startRun();
      }
    } else if (mode == Mode::Arming || mode == Mode::Running || mode == Mode::Cooling) {
      if (hit(BTN_STOP, x, y)) abortRun("Stopped by user");
    } else if (hit(BTN_OK, x, y)) {
      mode = Mode::Idle;
    }
  }

  // Serial commands for bench work: 'x' = abort, 'g' = start current profile.
  while (Serial.available()) {
    char c = (char)Serial.read();
    if (c == 'x') abortRun("Stopped from serial");
    else if (c == 'g' && mode == Mode::Idle) startRun();
  }
}
