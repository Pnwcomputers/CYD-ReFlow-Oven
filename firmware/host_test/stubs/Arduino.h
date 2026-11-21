// Minimal Arduino core for running the reflow firmware on a PC (host test).
// Time, pins, the thermocouple chip, the oven and the Shelly are all simulated
// in sim.h. Nothing here is used on the real board.
#pragma once
#include <stdint.h>
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <string>
#include <deque>
#include <algorithm>
#include "sim.h"

#define INPUT 0
#define OUTPUT 1
#define LOW 0
#define HIGH 1

inline uint32_t millis() { return (uint32_t)(sim::us / 1000); }
inline void delayMicroseconds(unsigned n) { sim::us += n; }
inline void delay(unsigned ms) { sim::us += (uint64_t)ms * 1000; sim::world(); }
inline void pinMode(int pin, int mode) { sim::pinMode(pin, mode); }
inline void digitalWrite(int pin, int level) { sim::digitalWrite(pin, level); }
inline int digitalRead(int pin) { return sim::digitalRead(pin); }

template <class T> T constrain(T v, T lo, T hi) { return v < lo ? lo : v > hi ? hi : v; }
using std::max;
using std::min;

// Just enough of Arduino's String for the firmware.
struct String : std::string {
  String(const char* s = "") : std::string(s) {}
  String(const std::string& s) : std::string(s) {}
  String operator+(const String& o) const { return String(std::string(*this) + std::string(o)); }
  String operator+(const char* o) const { return String(std::string(*this) + o); }
  String operator+(unsigned long v) const { return String(std::string(*this) + std::to_string(v)); }
  String operator+(unsigned int v) const { return String(std::string(*this) + std::to_string(v)); }
  int indexOf(const char* s) const { size_t p = find(s); return p == npos ? -1 : (int)p; }
  String substring(unsigned from) const { return String(from < size() ? substr(from) : std::string()); }
  float toFloat() const { return (float)atof(c_str()); }
  void replace(const char* a, const char* b) {
    size_t n = strlen(a), p = 0;
    while (n && (p = find(a, p)) != npos) { std::string::replace(p, n, b); p += strlen(b); }
  }
};
inline String operator+(const char* a, const String& b) { return String(std::string(a) + std::string(b)); }

struct SerialT {
  void begin(int) {}
  void println(const char* s) { sim::serialOut += s; sim::serialOut += '\n'; }
  int printf(const char* fmt, ...) {
    char buf[256];
    va_list ap; va_start(ap, fmt);
    int n = vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    sim::serialOut += buf;
    return n;
  }
  int available() { return (int)sim::serialIn.size(); }
  int read() { if (sim::serialIn.empty()) return -1; int c = sim::serialIn.front(); sim::serialIn.pop_front(); return c; }
};
inline SerialT Serial;

inline void ledcAttach(int, int, int) {}
inline void ledcWrite(int, int) {}
inline void ledcDetach(int) {}

// FreeRTOS: the test calls shellyStep() itself instead of starting the task.
typedef void* TaskHandle_t;
inline int pdMS_TO_TICKS(int ms) { return ms; }
inline void vTaskDelay(int) {}
inline void xTaskCreatePinnedToCore(void (*)(void*), const char*, int, void*, int, TaskHandle_t*, int) {
  sim::taskCreated = true;
}
