// CrowPanel 2.8 bench test — SSR drive + MAX6675, USB serial only (115200 baud).
// Run this with the board on USB power and NO mains connected.
//
// Wiring (see README / docs/BUILD-GUIDE.md):
//   J7 GPIO_D  pin 2 IO32 -> SSR T4 (-)     pin 3 3V3 -> SSR T3 (+)    pins 1, 4: not connected
//   J6 IIC     pin 1 IO21 -> MAX6675 CS     pin 2 IO22 -> MAX6675 SCK
//              pin 3 3V3  -> MAX6675 VCC    pin 4 GND  -> MAX6675 GND
//   J10 UART1  pin 1 IO16 <- MAX6675 SO     pins 2-4: not connected
//
// Serial commands:
//   1  SSR on for 3 s (auto-off)     0  SSR off now
//   t  toggle temperature streaming (every 500 ms)
//   s  status: IO32 level while released, last temperature
//
// The SSR is active-low: off = pin released (INPUT, the board's 1 kOhm pull-up
// holds IO32 at 3.3 V so both SSR inputs sit at 3.3 V); on = OUTPUT LOW.
// In the Arduino-ESP32 core, digitalWrite() on a pin pinMode() has not set up
// is ignored, and pinMode() sets no level, so the pin is never driven HIGH here.

#include <Arduino.h>
#include <math.h>

static const int SSR_PIN = 32;
static const int TC_CS = 21;
static const int TC_SCK = 22;
static const int TC_SO = 16;
static const uint32_t SSR_TEST_MS = 3000;

static bool ssrIsOn = false;
static uint32_t ssrOnAt = 0;
static bool streaming = false;
static uint32_t lastRead = 0;
static float lastTemp = NAN;

void ssrOff() {
  pinMode(SSR_PIN, INPUT);
  ssrIsOn = false;
}

void ssrOn() {
  pinMode(SSR_PIN, OUTPUT);
  digitalWrite(SSR_PIN, LOW);
  ssrIsOn = true;
  ssrOnAt = millis();
}

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

// Returns degrees C, or NAN if the thermocouple input is open (bit D2) or the
// data line is stuck (all ones or all zeros: check the SO, SCK and CS wires).
// The MAX6675 needs up to 0.22 s per conversion: call no faster than every 250 ms.
float tcRead() {
  digitalWrite(TC_CS, LOW);
  delayMicroseconds(10);
  uint16_t v = (uint16_t)tcReadByte() << 8;
  v |= tcReadByte();
  digitalWrite(TC_CS, HIGH);
  digitalWrite(TC_SCK, LOW);
  if (v == 0xFFFF || v == 0x0000) return NAN;   // SO stuck high or low: wiring fault
  if (v & 0x8000) return NAN;                   // dummy sign bit must be 0
  if (v & 0x4) return NAN;                      // open thermocouple
  return (v >> 3) * 0.25f;
}

void printStatus() {
  Serial.printf("SSR %s; IO32 reads %d while released (expect 1)\n",
                ssrIsOn ? "ON" : "off", ssrIsOn ? -1 : digitalRead(SSR_PIN));
  if (isnan(lastTemp)) Serial.println("Temperature: no reading / thermocouple open");
  else Serial.printf("Temperature: %.2f C\n", lastTemp);
}

void setup() {
  ssrOff();                       // first: SSR released = off
  pinMode(TC_CS, OUTPUT);
  digitalWrite(TC_CS, HIGH);
  pinMode(TC_SCK, OUTPUT);
  digitalWrite(TC_SCK, LOW);
  pinMode(TC_SO, INPUT);
  Serial.begin(115200);
  delay(300);
  Serial.println("\nCrowPanel bench test: 1 = SSR 3 s, 0 = off, t = temp stream, s = status");
  lastTemp = tcRead();
  lastRead = millis();
  printStatus();
}

void loop() {
  if (ssrIsOn && millis() - ssrOnAt >= SSR_TEST_MS) {
    ssrOff();
    Serial.println("SSR auto-off");
  }
  while (Serial.available()) {
    char c = (char)Serial.read();
    if (c == '1') { ssrOn(); Serial.println("SSR ON (3 s) - measure T3-T4 now"); }
    else if (c == '0') { ssrOff(); Serial.println("SSR off"); }
    else if (c == 't') { streaming = !streaming; Serial.printf("streaming %s\n", streaming ? "on" : "off"); }
    else if (c == 's') printStatus();
  }
  if (millis() - lastRead >= 500) {
    lastRead = millis();
    lastTemp = tcRead();
    if (streaming) {
      if (isnan(lastTemp)) Serial.println("T: no reading / open");
      else Serial.printf("T: %.2f C\n", lastTemp);
    }
  }
}
