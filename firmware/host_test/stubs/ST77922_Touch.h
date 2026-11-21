#pragma once
#include "sim.h"
struct ST77922_TOUCH {
  int max_points = 5;
  struct { uint16_t x[5], y[5]; } touch = {};
  void init() {}
  void Set_Rotation(int) {}
  bool Get_Touch() {
    if (!sim::touchDown) return false;
    touch.x[0] = sim::touchX; touch.y[0] = sim::touchY;
    return true;
  }
};
