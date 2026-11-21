// Reflow controller configuration: board choice, pins, control gains, limits.
// Wi-Fi and Shelly address go in secrets.h (see below).
#pragma once
#include <stdint.h>

// ---------------- Board ----------------
// Uncomment exactly one.
#define BOARD_CROWPANEL_28        // Elecrow CrowPanel 2.8" ESP32 HMI (ILI9341, 320x240); also sold
                                  // as Elecrow's "2.8inch ESP32 Solo Miner / NerdMiner" display
// #define BOARD_FREENOVE_S3_35   // Freenove ESP32-S3 Display 3.5" (FNK0104N, ST77922, 480x320)

// ---------------- Wi-Fi and Shelly ----------------
// Put your real values in secrets.h: copy secrets.example.h to secrets.h in this
// folder and edit it. secrets.h is git-ignored, so your Wi-Fi password does not
// end up in the repository. The values below are only placeholders.
#if defined(__has_include)
#if __has_include("secrets.h")
#include "secrets.h"
#endif
#endif
#ifndef WIFI_SSID
#define WIFI_SSID      "your-ssid"
#endif
#ifndef WIFI_PASSWORD
#define WIFI_PASSWORD  "your-password"
#endif
#ifndef SHELLY_HOST
#define SHELLY_HOST    "192.168.1.50"   // Shelly 1PM Gen4 IP (give it a DHCP reservation)
#endif

// true: a run will not start unless the Shelly answers, and the run aborts if no
// heartbeat gets through for SHELLY_LOST_ABORT_MS. Set false only for bench tests
// without the Shelly.
#define SHELLY_REQUIRED true

static const uint32_t SHELLY_HEARTBEAT_MS    = 15000;  // re-arm interval
static const uint32_t SHELLY_RETRY_MS        = 2000;   // retry interval while calls fail
static const uint32_t SHELLY_TOGGLE_AFTER_S  = 30;     // Shelly auto-off if heartbeats stop
static const uint32_t SHELLY_LOST_ABORT_MS   = 25000;  // abort the run after this long without one
static const uint32_t SHELLY_HTTP_TIMEOUT_MS = 3000;
static const uint32_t ARM_TIMEOUT_MS         = 15000;  // START to heating: relay closed and SSR checked by then
// Stuck-SSR check, before every run and at each heartbeat: with the Shelly relay
// closed and the SSR off for SSR_CHECK_SETTLE_MS (long enough for the Shelly's
// power reading to settle), the Shelly must read less than SSR_STUCK_POWER_W.
static const uint32_t SSR_CHECK_SETTLE_MS    = 5000;
static const float    SSR_STUCK_POWER_W      = 40.0f;
static_assert(SSR_CHECK_SETTLE_MS + 2 * SHELLY_HTTP_TIMEOUT_MS < ARM_TIMEOUT_MS, "arming must outlast the SSR check");
// The run must stop cleanly before the Shelly opens the relay by itself, and a
// single missed heartbeat must leave time for retries.
static_assert(SHELLY_LOST_ABORT_MS < SHELLY_TOGGLE_AFTER_S * 1000UL, "abort before the Shelly times out");
static_assert(SHELLY_HEARTBEAT_MS + 2 * SHELLY_RETRY_MS < SHELLY_LOST_ABORT_MS, "leave room for retries");

// ---------------- Pins ----------------
#if defined(BOARD_FREENOVE_S3_35)
// Freenove FNK0104N, from Freenove's 3.5" schematic. Only these four lines are free:
//   P3 "Extended IO": 1 3V3 -> MAX6675 VCC   2 GND -> MAX6675 GND
//                     3 IO46 -> SSR + (T3)   4 IO45 -> MAX6675 CS
//   P2 "UART":        1 +5V (NOT USED, insulate)   2 GND -> SSR - (T4)
//                     3 TXD0/IO43 -> MAX6675 SCK   4 RXD0/IO44 <- MAX6675 SO
// IO45 and IO46 have weak pull-downs at reset (ESP32-S3 datasheet), and the SSR
// input loads IO46 toward GND, so the SSR is OFF through reset, boot and flashing.
// Do not put anything on IO45/IO46 that pulls them HIGH at boot (strapping pins).
// The P4 "I2C" connector is shared with the touch controller and audio codec: don't use it.
static const int SSR_PIN = 46;
#define SSR_ACTIVE_LOW false          // SSR from pin to GND: on = HIGH, off = LOW
static const int TC_CS   = 45;
static const int TC_SCK  = 43;        // also carries the ROM boot log (harmless: CS idles)
static const int TC_SO   = 44;
static const int BUZZER_PIN = -1;     // on-board audio is an I2S codec; not used
static const uint8_t TFT_ROTATION = 1; // landscape; use 3 if upside down

#elif defined(BOARD_CROWPANEL_28)
// CrowPanel J7 / J6 / J10, see the repo README. SSR between 3V3 (J7 pin 3) and
// IO32 (J7 pin 2), 1 kOhm on-board pull-up: active-low, off = pin released.
static const int SSR_PIN = 32;
#define SSR_ACTIVE_LOW true
static const int TC_CS   = 21;        // J6 pin 1
static const int TC_SCK  = 22;        // J6 pin 2
static const int TC_SO   = 16;        // J10 pin 1
static const int BUZZER_PIN = 26;     // on-board speaker amplifier (optional speaker)
static const uint8_t TFT_ROTATION = 3; // 1 per Elecrow; 3 with the board mounted connectors-down

#else
#error "Select a board in config.h"
#endif

// ---------------- Control ----------------
static const uint32_t PWM_WINDOW_MS     = 2000;  // slow-PWM window for the SSR
static const uint32_t TC_PERIOD_MS      = 250;   // MAX6675 conversion is up to 220 ms
static const uint32_t CONTROL_PERIOD_MS = 1000;

// PID gains (output is duty 0..1 per degree C of error). Starting values for a
// ~1150 W toaster oven; tune with real runs (see README in this folder).
static const float PID_KP = 0.030f;
static const float PID_KI = 0.0006f;
static const float PID_KD = 0.20f;
// The oven lags badly, so the PID chases the setpoint this many seconds ahead.
static const float SETPOINT_LOOKAHEAD_S = 15.0f;
// Hold the profile clock while the oven is this far below the setpoint.
static const float PROFILE_HOLD_LAG_C = 10.0f;

// ---------------- Safety limits ----------------
static const float    HARD_MAX_C         = 260.0f;  // abort above this, always
static const float    OVERSHOOT_ABORT_C  = 30.0f;   // abort if this far above setpoint
static const uint32_t MAX_RUN_MS         = 15UL * 60UL * 1000UL;
static const float    RUNAWAY_DUTY       = 0.80f;   // "heating hard"...
static const uint32_t RUNAWAY_WINDOW_MS  = 60000;   // ...for this long...
static const float    RUNAWAY_MIN_RISE_C = 5.0f;    // ...must raise temp by this much
static const uint8_t  TC_MAX_BAD_READS   = 4;       // consecutive open/invalid reads
static const float    START_MAX_C        = 60.0f;   // a run will not start above this (profiles start cold)
static const uint32_t LOOP_STALL_MS      = 5000;    // control loop silent this long: the Shelly task cuts the heat
