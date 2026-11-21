#pragma once
#include "sim.h"
struct ST77922 {
  void Init() {}
  void Set_Rotation(int) {}
  int Get_Width() { return sim::screenW; }
  int Get_Height() { return sim::screenH; }
  void Fill_Colors(int, int, int, int, uint16_t*) {}
};
