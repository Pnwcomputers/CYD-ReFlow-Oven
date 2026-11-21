#pragma once
#include "Arduino.h"
struct HTTPClient {
  std::string url, body;
  uint32_t timeoutMs = 5000;
  void setTimeout(uint32_t ms) { timeoutMs = ms; }
  void setConnectTimeout(uint32_t) {}
  bool begin(const String& u) { url = u; return true; }
  int GET() { return sim::httpGet(url, body, timeoutMs); }
  String getString() { return String(body); }
  void end() {}
};
