// Structs and enums used by reflow_controller.ino.
//
// They are in a header on purpose. The Arduino IDE writes a prototype for every
// function in a .ino file and inserts those prototypes near the top of the
// sketch, above anything defined further down. A function that takes one of
// these types would then fail to compile ("'Btn' does not name a type") if the
// type were defined in the .ino itself. Add new types here, not there.
#pragma once
#include <stdint.h>

// Controller state machine.
enum class Mode : uint8_t { Idle, Arming, Running, Cooling, Done, Aborted };

// What the controller last heard from the Shelly about its relay.
enum class Shelly : uint8_t { Unknown, On, Off, Error };

// One answer to Switch.GetStatus.
struct ShellyStatus {
  int output;     // 1 = relay closed, 0 = open, -1 = not in the answer
  float watts;    // power through the relay, NAN = not in the answer
};

// An on-screen button.
struct Btn { int16_t x, y, w, h; const char* label; uint16_t color; };
