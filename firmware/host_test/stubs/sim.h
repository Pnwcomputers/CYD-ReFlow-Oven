// The simulated world for the host test: clock, GPIO, MAX6675, oven, Shelly.
#pragma once
#include <stdint.h>
#include <string>
#include <deque>
#include <vector>
#include <map>

namespace sim {

// ---- clock ----
inline uint64_t us = 1000000;            // simulated time since "boot", microseconds
inline double seconds() { return us / 1e6; }

// ---- GPIO ----
struct Pin { int mode = 0; int level = 0; };
inline Pin pins[64];
inline int ssrPin = -1, tcCs = -1, tcSck = -1, tcSo = -1;   // set by the test from config.h
inline bool ssrActiveLow = true;

// SSR input sees current: pin sinking (active-low) or sourcing (active-high).
inline bool ssrConducting() {
  const Pin& p = pins[ssrPin];
  return p.mode == 1 && p.level == (ssrActiveLow ? 0 : 1);
}

// ---- oven: heating element (lagged) into a thermal mass that leaks to the room ----
struct Oven {
  double tempC = 25, elementW = 0;
  double powerW = 1150, massJperC = 770, lossWperC = 4.2, elementTauS = 25, roomC = 25;
  bool heaterDead = false;      // element open: no heat even when powered
  bool ssrShorted = false;      // SSR failed closed: heats whenever the Shelly relay is closed
  double peakC = 25;
};
inline Oven oven;

// ---- thermocouple + MAX6675 ----
inline bool tcOpen = false;          // probe unplugged / broken
inline bool tcStuckHigh = false;     // SO wire shorted high
inline uint16_t tcWord = 0;
inline int tcBit = 15;

// ---- Shelly 1PM (just the calls the firmware makes) ----
struct ShellySim {
  bool reachable = true;       // false: the HTTP connection times out
  bool relay = false;
  uint64_t toggleAtUs = 0;     // toggle_after deadline, 0 = none
  bool kvsActive = false;
  int onCalls = 0, offCalls = 0, statusCalls = 0, kvsCalls = 0;
  int lastToggleAfter = -1;
  bool everOnWithoutTimer = false;
  uint64_t lastOnCallUs = 0;
  double maxOnGapS = 0;        // longest time between two "stay on" calls while the relay was closed
  bool lockout = false;        // supervisor lockout: a closed relay is opened again at once
  std::string statusFormat = "{\"id\":0, \"source\":\"HTTP_in\", \"output\":%s, \"apower\":%.1f, "
                             "\"voltage\":120.1, \"current\":%.2f, \"temperature\":{\"tC\":41.3, \"tF\":106.3}}";
};
inline ShellySim shelly;

inline bool wifiUp = true;
inline int wifiReconnects = 0;
inline uint64_t taskBusyUntilUs = 0;     // the Shelly task is blocked in an HTTP call until then
inline bool taskCreated = false;

// ---- serial and touch ----
inline std::string serialOut;
inline std::deque<char> serialIn;
inline bool touchDown = false;
inline uint16_t touchX = 0, touchY = 0;

// ---- screen: every string drawn, for the layout checks ----
struct Text { std::string s; int x0, y0, x1, y1, font, datum; };   // x1/y1 exclusive
inline std::vector<Text> texts;
inline int screenW = 320, screenH = 240;

// ---- flash (Preferences) ----
inline std::map<std::string, std::string> flash;

// ---- world ----
inline uint64_t worldUs = us;
inline uint64_t heatOnUs = 0;            // total time the element was powered
inline bool heating() {
  return shelly.relay && (ssrConducting() || oven.ssrShorted) && !oven.heaterDead;
}
inline void world() {
  while (worldUs < us) {
    uint64_t step = us - worldUs > 5000 ? 5000 : us - worldUs;
    double dt = step / 1e6;
    worldUs += step;
    if (shelly.toggleAtUs && worldUs >= shelly.toggleAtUs) { shelly.relay = false; shelly.toggleAtUs = 0; }
    bool on = heating();
    if (on) heatOnUs += step;
    oven.elementW += ((on ? oven.powerW : 0) - oven.elementW) / oven.elementTauS * dt;
    oven.tempC += (oven.elementW - oven.lossWperC * (oven.tempC - oven.roomC)) / oven.massJperC * dt;
    if (oven.tempC > oven.peakC) oven.peakC = oven.tempC;
  }
}

inline void pinMode(int pin, int mode) { world(); pins[pin].mode = mode; }
inline void digitalWrite(int pin, int level) {
  world();
  int was = pins[pin].level;
  pins[pin].level = level;
  if (pin == tcCs && was == 1 && level == 0) {        // CS falling: output the latest conversion
    if (tcStuckHigh) tcWord = 0xFFFF;
    else {
      double c = oven.tempC < 0 ? 0 : oven.tempC > 1023.75 ? 1023.75 : oven.tempC;
      tcWord = (uint16_t)((uint16_t)(c / 0.25) << 3);
      if (tcOpen) tcWord |= 0x0004;
    }
    tcBit = 15;
  }
  if (pin == tcSck && was == 1 && level == 0 && pins[tcCs].level == 0 && tcBit > 0) tcBit--;
}
inline int digitalRead(int pin) {
  if (pin == tcSo) return (tcWord >> tcBit) & 1;
  return pins[pin].level;
}

// One HTTP GET to the Shelly. Returns the status code (-1 = connection failed).
inline int httpGet(const std::string& url, std::string& body, uint32_t timeoutMs) {
  world();
  if (!wifiUp) return -1;
  if (!shelly.reachable) { taskBusyUntilUs = us + (uint64_t)timeoutMs * 1000; return -1; }
  taskBusyUntilUs = us + 30000;                        // a LAN round trip
  char buf[400];
  if (url.find("/rpc/Switch.Set") != std::string::npos) {
    bool was = shelly.relay;
    if (url.find("on=true") != std::string::npos) {
      shelly.onCalls++;
      size_t p = url.find("toggle_after=");
      shelly.lastToggleAfter = p == std::string::npos ? -1 : atoi(url.c_str() + p + 13);
      if (shelly.lastToggleAfter <= 0) shelly.everOnWithoutTimer = true;
      if (was && shelly.lastOnCallUs) {
        double gap = (us - shelly.lastOnCallUs) / 1e6;
        if (gap > shelly.maxOnGapS) shelly.maxOnGapS = gap;
      }
      shelly.lastOnCallUs = us;
      if (!shelly.lockout) {
        shelly.relay = true;
        shelly.toggleAtUs = shelly.lastToggleAfter > 0 ? us + (uint64_t)shelly.lastToggleAfter * 1000000 : 0;
      }
    } else {
      shelly.offCalls++;
      shelly.relay = false;
      shelly.toggleAtUs = 0;
    }
    snprintf(buf, sizeof(buf), "{\"was_on\":%s}", was ? "true" : "false");
    body = buf;
    return 200;
  }
  if (url.find("/rpc/Switch.GetStatus") != std::string::npos) {
    shelly.statusCalls++;
    double w = heating() ? oven.powerW : 0.0;
    snprintf(buf, sizeof(buf), shelly.statusFormat.c_str(), shelly.relay ? "true" : "false", w, w / 120.0);
    body = buf;
    return 200;
  }
  if (url.find("/rpc/KVS.Set") != std::string::npos && url.find("key=reflow_active") != std::string::npos) {
    shelly.kvsCalls++;
    shelly.kvsActive = url.find("value=true") != std::string::npos;
    body = "{\"etag\":\"0DWty8HwCB\",\"rev\":7}";
    return 200;
  }
  body = "{\"code\":404,\"message\":\"No handler\"}";
  return 404;
}

}  // namespace sim
