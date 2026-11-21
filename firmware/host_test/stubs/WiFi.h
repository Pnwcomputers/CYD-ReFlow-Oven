#pragma once
#include "sim.h"
#define WL_CONNECTED 3
#define WL_DISCONNECTED 6
#define WIFI_STA 1
struct WiFiT {
  int status() { return sim::wifiUp ? WL_CONNECTED : WL_DISCONNECTED; }
  void mode(int) {}
  void setAutoReconnect(bool) {}
  void begin(const char*, const char*) {}
  void reconnect() { sim::wifiReconnects++; }
};
inline WiFiT WiFi;
