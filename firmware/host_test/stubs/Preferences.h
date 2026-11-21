#pragma once
#include "sim.h"
#include <string.h>
struct Preferences {
  std::string ns;
  bool open = false, readOnly = false;
  bool begin(const char* name, bool ro) {
    // Like the real NVS: a read-only open of a namespace that doesn't exist yet fails.
    if (ro && sim::flash.find(std::string(name) + "/") == sim::flash.end()) return false;
    ns = name; open = true; readOnly = ro;
    if (!ro) sim::flash[ns + "/"] = "";
    return true;
  }
  void end() { open = false; }
  size_t getBytes(const char* k, void* buf, size_t n) {
    auto it = sim::flash.find(ns + "/" + k);
    if (!open || it == sim::flash.end() || it->second.size() > n) return 0;
    memcpy(buf, it->second.data(), it->second.size());
    return it->second.size();
  }
  size_t putBytes(const char* k, const void* buf, size_t n) {
    if (!open || readOnly) return 0;
    sim::flash[ns + "/" + k] = std::string((const char*)buf, n);
    return n;
  }
  uint8_t getUChar(const char* k, uint8_t d) { uint8_t v; return getBytes(k, &v, 1) == 1 ? v : d; }
  size_t putUChar(const char* k, uint8_t v) { return putBytes(k, &v, 1); }
};
