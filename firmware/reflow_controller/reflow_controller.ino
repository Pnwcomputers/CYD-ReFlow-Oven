// Reflow oven controller for the CYD reflow oven (board chosen in config.h).
//
// Heat path:  inlet -> Shelly 1PM Gen4 (master cutoff) -> SSR -> oven socket.
// This firmware: touchscreen UI, reflow profiles, PID + slow-PWM SSR control,
// safety aborts, and a Shelly watchdog (Switch.Set toggle_after) so the Shelly
// opens on its own if this board hangs or reboots.
//
// Two tasks: loop() on core 1 runs the control loop and the screen; shellyTask
// on core 0 talks to the Shelly, so a slow network call never delays the SSR.
// Each watches the other: loop() aborts if the Shelly stops answering, and the
// Shelly task cuts the heat if loop() stops running.
//
// Setup and Arduino IDE settings per board: README.md in this folder.
// Settings: config.h. Profiles: profiles.h. Display/touch per board: board.h.
// Structs and enums: types.h (not in this file, see the note there).

#include <Arduino.h>
#include <SPI.h>
#include <TFT_eSPI.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <math.h>
#include "config.h"
#include "types.h"
#include "profiles.h"
#include "board.h"
#include "driver/gpio.h"

// =====================================================================
// SSR drive. Never drive the pin to the "on" level except in ssrOn().
// =====================================================================
static volatile bool ssrState = false;
static volatile uint32_t ssrOffSinceMs = 0;   // when the SSR was last switched off

static void ssrOff() {
  if (ssrState) ssrOffSinceMs = millis();
#if SSR_ACTIVE_LOW
  pinMode(SSR_PIN, INPUT);              // released: on-board pull-up -> SSR sees 0 V
#else
  pinMode(SSR_PIN, OUTPUT);
  digitalWrite(SSR_PIN, LOW);
#endif
  ssrState = false;
}

static void ssrOn() {
  if (ssrState) return;                 // already on: don't reconfigure the pin every loop
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
static volatile bool     shellyWantOn = false;     // control loop -> task
static volatile Shelly   shellyState = Shelly::Unknown;
static volatile uint32_t shellyLastOkMs = 0;       // last "stay on" call the Shelly answered
static volatile bool     shellyOpened = false;     // task -> loop: the Shelly opened its relay itself
static volatile bool     wifiUp = false;
static volatile bool     runActive = false;        // published to Shelly KVS
static volatile uint32_t loopAliveMs = 0;          // loop -> task: stamped on every pass of loop()
static volatile bool     loopStalled = false;      // task -> loop: loop() stopped, heat was cut
static volatile uint32_t armStartMs = 0;           // loop -> task: when START was pressed
static volatile bool     ssrCheckDone = false;     // task -> loop: idle power was measured for this run
static volatile float    ssrCheckPowerW = NAN;     // ...and this is it (NAN = the Shelly didn't say)
static volatile bool     ssrStuck = false;         // task -> loop: power flowed with the SSR off

// Milliseconds since a time stamp that the other task writes. Signed, so a stamp
// written just after `now` was read gives a small negative number, not 49 days.
static inline int32_t msSince(uint32_t now, uint32_t stamp) { return (int32_t)(now - stamp); }

// One HTTP GET to the Shelly. body, if not null, receives the answer.
static bool shellyGet(const String& path, String* body) {
  if (WiFi.status() != WL_CONNECTED) return false;
  HTTPClient http;
  http.setTimeout(SHELLY_HTTP_TIMEOUT_MS);
  http.setConnectTimeout(SHELLY_HTTP_TIMEOUT_MS);
  if (!http.begin(String("http://") + SHELLY_HOST + path)) return false;
  int code = http.GET();
  if (code == 200 && body) *body = http.getString();
  http.end();
  return code == 200;
}

// Reads the Shelly's relay state and power. Returns false if it didn't answer.
static bool shellyStatus(ShellyStatus& st) {
  String body;
  if (!shellyGet("/rpc/Switch.GetStatus?id=0", &body)) return false;
  body.replace(" ", "");
  st.output = body.indexOf("\"output\":true") >= 0 ? 1 : body.indexOf("\"output\":false") >= 0 ? 0 : -1;
  int i = body.indexOf("\"apower\":");
  st.watts = i >= 0 ? body.substring(i + 9).toFloat() : NAN;
  // An answer this code can't read: carry on without that check (the Shelly's
  // timeout, its script and the control loop's own limits still apply).
  static bool warned = false;
  if ((st.output < 0 || i < 0) && !warned) {
    warned = true;
    Serial.println("# Shelly status not understood: relay and stuck-SSR checks are off");
  }
  return true;
}

static bool shellySetOn() {
  return shellyGet(String("/rpc/Switch.Set?id=0&on=true&toggle_after=") + SHELLY_TOGGLE_AFTER_S, nullptr);
}
static bool shellySetOff() { return shellyGet("/rpc/Switch.Set?id=0&on=false", nullptr); }
static bool shellyPublish(bool active) {
  // Read by the Shelly supervisor script (shelly/reflow_supervisor.js).
  return shellyGet(String("/rpc/KVS.Set?key=reflow_active&value=") + (active ? "true" : "false"), nullptr);
}

// One pass of the Shelly task. While the relay should be on: one "stay on" call
// per SHELLY_HEARTBEAT_MS, or one per SHELLY_RETRY_MS while calls are failing.
// The control loop aborts the run if none gets through for SHELLY_LOST_ABORT_MS;
// the Shelly itself opens the relay SHELLY_TOGGLE_AFTER_S after the last one.
static void shellyStep() {
  static uint32_t lastTry = 0, lastWifiTry = 0, lastPublishTry = 0, armedAtMs = 0, lastCheckTry = 0;
  static bool triedOn = false, armed = false, published = false, publishedValue = false;
  uint32_t now = millis();

  // Control loop stuck (it stamps loopAliveMs on every pass): cut the heat from
  // this task and stop re-arming the Shelly. loop() reports it if it comes back.
  if (msSince(now, loopAliveMs) > (int32_t)LOOP_STALL_MS) {
    ssrOff();
    shellyWantOn = false;
    loopStalled = true;
  }

  wifiUp = WiFi.status() == WL_CONNECTED;
  if (!wifiUp && now - lastWifiTry > 10000) {
    lastWifiTry = now;
    WiFi.reconnect();
  }

  if (shellyWantOn) {
    ShellyStatus st = {1, NAN};
    uint32_t interval = shellyState == Shelly::On ? SHELLY_HEARTBEAT_MS : SHELLY_RETRY_MS;
    if (!shellyOpened && (!triedOn || now - lastTry >= interval)) {
      triedOn = true;
      lastTry = now;
      // Close the relay once per run, then only keep a closed relay closed. If
      // the Shelly has opened it (its power, current or temperature limit, the
      // supervisor script, its timeout, or someone in the app), leave it open
      // and tell the control loop.
      uint32_t offSince = ssrOffSinceMs;
      bool wasOff = !ssrState;
      bool answered = !armed || shellyStatus(st);
      // Power although the SSR was off from well before the question until after
      // the answer: the SSR has failed closed.
      if (answered && armed && wasOff && !ssrState && ssrOffSinceMs == offSince
          && msSince(now, offSince) >= (int32_t)SSR_CHECK_SETTLE_MS && st.watts > SSR_STUCK_POWER_W) {
        ssrStuck = true;
      }
      if (answered && st.output == 0) {
        shellyOpened = true;
        shellyState = Shelly::Off;
      } else if (answered && shellyWantOn && shellySetOn()) {   // (not if the run just ended)
        shellyLastOkMs = millis();
        shellyState = Shelly::On;
        if (!armed) { armed = true; armedAtMs = shellyLastOkMs; }
      } else {
        shellyState = Shelly::Error;
      }
    }
    // Stuck-SSR check, once per run: the relay is closed and the control loop is
    // holding the SSR off until this is done, so the oven should draw nothing.
    if (armed && !ssrCheckDone && !shellyOpened
        && msSince(now, armedAtMs) >= (int32_t)SSR_CHECK_SETTLE_MS
        && msSince(now, armStartMs) >= (int32_t)SSR_CHECK_SETTLE_MS
        && now - lastCheckTry >= SHELLY_RETRY_MS) {
      lastCheckTry = now;
      if (shellyStatus(st)) {
        if (st.output == 0) { shellyOpened = true; shellyState = Shelly::Off; }
        else { ssrCheckPowerW = st.watts; ssrCheckDone = true; }
      }
    }
  } else {
    // Keep trying to open the relay until the Shelly confirms.
    if (shellyState != Shelly::Off && (triedOn || now - lastTry >= SHELLY_RETRY_MS)) {
      lastTry = now;
      shellyState = shellySetOff() ? Shelly::Off : Shelly::Error;
    }
    triedOn = false;
    armed = false;
  }

  bool a = runActive;
  if (wifiUp && (!published || a != publishedValue) && now - lastPublishTry >= 500) {
    lastPublishTry = now;
    if (shellyPublish(a)) { published = true; publishedValue = a; }
  }
}

static void shellyTask(void*) {
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  for (;;) {
    shellyStep();
    vTaskDelay(pdMS_TO_TICKS(200));
  }
}

// =====================================================================
// Controller state
// =====================================================================
static Mode mode = Mode::Idle;
static uint8_t profileIdx = 0;
static uint32_t runStartMs = 0;
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
// Profile clock. It stops while the oven is more than PROFILE_HOLD_LAG_C behind
// the profile, so a slow oven still reaches each stage (the profile stretches
// instead of being cut short). MAX_RUN_MS and the no-temperature-rise check
// still bound the run in wall-clock time.
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
  shellyOpened = false;
  ssrCheckDone = false;
  ssrCheckPowerW = NAN;
  ssrStuck = false;
  armStartMs = millis();
  shellyWantOn = true;
  runActive = true;
  mode = Mode::Arming;
  Serial.printf("# arming: %s\n", prof().name);
}

// spAhead is the profile SETPOINT_LOOKAHEAD_S from now, spNow the profile now.
// P and D chase the look-ahead (the oven lags); the integral works on the real
// error, so it settles the holds without winding up during the ramps.
static void pidStep(float spAhead, float spNow, float dt) {
  float err = spAhead - tempC;
  float deriv = havePrevErr ? (err - lastErr) / dt : 0;
  lastErr = err; havePrevErr = true;
  float p = PID_KP * err, d = PID_KD * deriv;
  float out = p + PID_KI * integ + d;
  float errNow = spNow - tempC;
  // Anti-windup: integrate only when not pushing further into saturation.
  if (!((out >= 1 && errNow > 0) || (out <= 0 && errNow < 0))) integ += errNow * dt;
  integ = constrain(integ, -0.2f / PID_KI, 0.8f / PID_KI);
  out = p + PID_KI * integ + d;
  duty = constrain(out, 0.0f, 1.0f);
}

// Returns true if a safety check aborted the run.
static bool safetyChecks(float t, float spNow) {
  if (badReads >= TC_MAX_BAD_READS) { abortRun("Thermocouple not reading"); return true; }
  if (isnan(tempC)) return false;
  if (tempC > HARD_MAX_C) { abortRun("Over max temperature"); return true; }
  if (tempC > spNow + OVERSHOOT_ABORT_C && t > 30) { abortRun("Too far above profile"); return true; }
  if (millis() - runStartMs > MAX_RUN_MS) { abortRun("Max run time exceeded"); return true; }
  if (shellyOpened) { abortRun("Shelly opened its relay"); return true; }
  if (ssrStuck) { abortRun("SSR stuck on: replace it"); return true; }
  if (SHELLY_REQUIRED && msSince(millis(), shellyLastOkMs) > (int32_t)SHELLY_LOST_ABORT_MS) {
    abortRun("Lost contact with Shelly");
    return true;
  }
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

static Btn BTN_PREV, BTN_NEXT, BTN_START, BTN_STOP, BTN_OK;
static int GX, GY, GW, GH;          // graph area
static int BAR_Y;                   // top of the bottom button bar
static int TEMP_W;                  // pixel width of the widest temperature readout
static const int STATUS_CHARS = 29; // status line length: must end left of the temperature

static void layout() {
  const int bh = H >= 300 ? 52 : 40, bw = W >= 480 ? 160 : 120, sw = W >= 480 ? 70 : 50;
  BAR_Y = H - bh - 4;
  BTN_PREV  = {4, (int16_t)BAR_Y, (int16_t)sw, (int16_t)bh, "<", C_BTN};
  BTN_NEXT  = {(int16_t)(8 + sw), (int16_t)BAR_Y, (int16_t)sw, (int16_t)bh, ">", C_BTN};
  BTN_START = {(int16_t)(W - bw - 4), (int16_t)BAR_Y, (int16_t)bw, (int16_t)bh, "START", 0x0400};
  BTN_STOP  = {(int16_t)(W - bw - 4), (int16_t)BAR_Y, (int16_t)bw, (int16_t)bh, "STOP", 0xA000};
  // The abort reason is drawn to the left of OK. Keep reasons short: the host
  // test checks that every one of them fits on the 320 px screen.
  BTN_OK    = {(int16_t)(W - bw - 4), (int16_t)BAR_Y, (int16_t)bw, (int16_t)bh, "OK", C_BTN};
  GX = 30; GY = 34; GW = W - GX - 6; GH = BAR_Y - GY - 8;
  TEMP_W = gfx.textWidth("888.8 C", 4);
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
  // Top-right: live temperature, refreshed in place. Font 4 is proportional, so
  // pad to the widest reading or a shorter one leaves part of the old one behind.
  char buf[64], line[64];
  gfx.setTextDatum(TR_DATUM);
  gfx.setTextColor(isnan(tempC) ? TFT_RED : TFT_YELLOW, C_BG);
  if (isnan(tempC)) snprintf(buf, sizeof(buf), "--- C");
  else snprintf(buf, sizeof(buf), "%.1f C", tempC);
  gfx.setTextPadding(TEMP_W);
  gfx.drawString(buf, W - 4, 2, 4);
  gfx.setTextPadding(0);

  // Under the title: one status line, always STATUS_CHARS long so it overwrites
  // itself and stays left of the temperature on the 320 px screen.
  const char* sh = shellyState == Shelly::On ? "on" : shellyState == Shelly::Off ? "off"
                 : shellyState == Shelly::Error ? "ERR" : "?";
  if (mode == Mode::Running || mode == Mode::Cooling || mode == Mode::Arming) {
    float t = mode == Mode::Arming ? 0 : runSeconds();
    const char* phase = mode == Mode::Arming ? "arming" : mode == Mode::Cooling ? "COOL"
                      : t < prof().reflow_start_s ? "heat" : "REFLOW";
    snprintf(line, sizeof(line), "%3ds SP%3.0f %3d%% %-6s Sh:%s", (int)t,
             profileSetpoint(prof(), t), (int)(duty * 100), phase, sh);
  } else {
    snprintf(line, sizeof(line), "WiFi:%s Shelly:%s", wifiUp ? "ok" : "--", sh);
  }
  snprintf(buf, sizeof(buf), "%-*.*s", STATUS_CHARS, STATUS_CHARS, line);
  gfx.setTextDatum(TL_DATUM);
  gfx.setTextColor(C_DIM, C_BG);
  gfx.drawString(buf, 4, 22, 1);
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

  prefs.begin("reflow", false);             // read-write: creates the namespace on first boot
  profileIdx = prefs.getUChar("prof", 0) % NUM_PROFILES;
  prefs.end();

  shellyWantOn = false;                     // the task opens the Shelly relay at boot
  loopAliveMs = millis();
  xTaskCreatePinnedToCore(shellyTask, "shelly", 8192, nullptr, 1, nullptr, 0);
  screenDirty = true;
}

void loop() {
  uint32_t now = millis();
  loopAliveMs = now;
  if (loopStalled) {                        // the Shelly task cut the heat while loop() was stuck
    loopStalled = false;
    if (mode == Mode::Arming || mode == Mode::Running || mode == Mode::Cooling)
      abortRun("Controller stalled");
  }

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
      // SSR stays off here. With the Shelly: wait for its relay to close, then
      // for the stuck-SSR check (power through the Shelly with the SSR off).
      ssrOff();
      if (badReads >= TC_MAX_BAD_READS || isnan(tempC)) { abortRun("Thermocouple not reading"); break; }
      if (tempC > START_MAX_C) { abortRun("Oven too hot to start"); break; }
      if (SHELLY_REQUIRED) {
        if (shellyOpened) { abortRun("Shelly opened its relay"); break; }
        if (now - armStartMs > ARM_TIMEOUT_MS) { abortRun("Shelly not reachable"); break; }
        if (shellyState != Shelly::On || !ssrCheckDone) break;
        if (ssrCheckPowerW > SSR_STUCK_POWER_W) { abortRun("SSR stuck on: replace it"); break; }
        Serial.printf("# SSR off, Shelly reads %.1f W\n", (float)ssrCheckPowerW);
      }
      runStartMs = millis();
      profT = 0;
      pwmWindowStart = runStartMs;
      lastControlMs = 0;
      mode = Mode::Running;
      screenDirty = true;
      beep(100);
      Serial.println("# running");
      break;

    case Mode::Running: {
      float t = runSeconds();
      float spNow = profileSetpoint(prof(), t);
      if (now - lastControlMs >= CONTROL_PERIOD_MS) {
        float dt = lastControlMs ? (now - lastControlMs) / 1000.0f : 0;
        lastControlMs = now;
        if (safetyChecks(t, spNow)) break;
        bool lagging = !isnan(tempC) && tempC < spNow - PROFILE_HOLD_LAG_C;
        if (!lagging) profT += dt;
        if (dt <= 0) dt = CONTROL_PERIOD_MS / 1000.0f;
        if (!isnan(tempC)) pidStep(profileSetpoint(prof(), t + SETPOINT_LOOKAHEAD_S), spNow, dt);
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
    if (c == 'x' && (mode == Mode::Arming || mode == Mode::Running || mode == Mode::Cooling))
      abortRun("Stopped from serial");
    else if (c == 'g' && mode == Mode::Idle) startRun();
  }
}
