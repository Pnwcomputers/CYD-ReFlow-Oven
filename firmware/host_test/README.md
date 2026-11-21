# Host test: the firmware on a PC

`./run.sh` compiles the real `reflow_controller.ino` with g++ and runs it against a simulated world: a clock, the GPIO pins, the MAX6675, an oven, and a Shelly that answers the same HTTP calls. No board, no mains. It runs every scenario once per supported board, then tests the Shelly script under Node.js.

```
./run.sh              # everything (a few seconds)
./run.sh "Wi-Fi"      # only scenarios whose name contains "Wi-Fi"
./run.sh "STOP" log   # ...and print the firmware's serial log
```

Needs `g++` with C++17 (Linux, macOS, or WSL on Windows). Node.js is optional: without it the Shelly script test is skipped.

## What it checks

| Scenario | The firmware must |
| --- | --- |
| A full run of each profile | Finish, peak near the profile's peak, send every heartbeat with `toggle_after`, and leave the SSR and the relay off |
| Thermocouple unplugged (before or during a run), data wire shorted | Abort within about 2 s |
| START with the oven hot, the Shelly unreachable, or Wi-Fi down | Refuse to heat |
| Wi-Fi drops for 8 s, or the Shelly is silent for 6 s | Carry on |
| Shelly lost for good | Abort before the Shelly's own 30 s timeout |
| Heating element dead | Abort ("No temp rise") |
| SSR already failed closed | Refuse to start ("SSR stuck on") |
| SSR fails closed during a run | Notice from the Shelly's power reading and abort |
| Shelly opens its relay by itself, or refuses to close | Never close it again; abort |
| Control loop hangs with the SSR on | SSR released and relay opened by the other task within about 5 s |
| Board resets during a run | (The simulated Shelly opens 30 s after the last heartbeat) |
| STOP, serial `g` / `x`, saved profile choice | Behave as documented |
| Every screen | No text off the screen, under a button, or over the temperature readout (real TFT_eSPI font widths) |

In every scenario the SSR may only be driven during the heating phase of a run.

Before the scenarios, `run.sh` also imitates one thing the Arduino IDE does that plain g++ does not: it writes a prototype for every function in the `.ino` and puts them right under the `#include` lines. A function that takes a struct defined further down the sketch then fails to compile. That is why the sketch's types live in `types.h`.

## What it does not check

* **That the sketch compiles for an ESP32.** The Arduino core, TFT_eSPI, Wi-Fi and HTTP are replaced by the small stand-ins in `stubs/`, which only promise that the calls the sketch makes exist. The first real compile is in the Arduino IDE.
* **The real oven.** The oven in `stubs/sim.h` is a guess (1150 W into a thermal mass with a lagging element). The peak temperatures it prints are there to catch a change in the control loop, not to predict your oven. Tune on real runs.
* **The real Shelly.** The test Shelly answers the way Shelly's Gen2+ API documentation says (`Switch.Set`, `Switch.GetStatus`, `KVS.Set`). The lamp test in the build guide is where that meets the real device.
* **Two cores.** The Shelly task and the control loop run in turns here, not at the same time.

## Files

| File | What it is |
| --- | --- |
| `run.sh` | Builds and runs everything |
| `host_test.cpp` | The scenarios |
| `stubs/sim.h` | The simulated clock, pins, thermocouple chip, oven and Shelly |
| `stubs/*.h` | Stand-ins for the Arduino, TFT_eSPI, Wi-Fi, HTTP and flash-storage headers |
| `shelly_script_test.js` | Runs `../shelly/reflow_supervisor.js` against a stand-in for the Shelly scripting API |
