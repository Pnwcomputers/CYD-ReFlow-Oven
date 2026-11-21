# Reflow controller firmware

Touchscreen reflow controller for the CYD reflow oven: profiles, PID control of the SSR, safety aborts, and a heartbeat to the Shelly 1PM Gen4 so the Shelly cuts the oven if this board hangs.

> ⚠️ Not yet run on hardware. The sketch runs on a PC against a simulated oven, thermocouple chip and Shelly ([`../host_test/`](../host_test/README.md): 27 scenarios for each board). That tests the logic, not the hardware. The first real compile is in the Arduino IDE, and the first runs must be on the bench with a lamp as the load ([BUILD-GUIDE](../../docs/BUILD-GUIDE.md) section 5).

## Files

| File | What it is |
| --- | --- |
| `reflow_controller.ino` | Main sketch: state machine, PID, slow-PWM SSR, safety, UI, Shelly task |
| `config.h` | Board choice, pins, PID gains, safety limits |
| `secrets.example.h` | **Copy to `secrets.h` and edit:** Wi-Fi name, password, Shelly IP. `secrets.h` is git-ignored |
| `profiles.h` | Reflow profiles (Sn63/Pb37, Sn42/Bi58 low-temp, SAC305, 120 °C bake) |
| `types.h` | Structs and enums. Kept out of the `.ino` because the Arduino IDE puts its generated function prototypes above anything defined there |
| `board.h` | Display and touch code for each supported board |
| `User_Setup_CrowPanel28.h` | TFT_eSPI setup for the CrowPanel 2.8 |
| `../shelly/reflow_supervisor.js` | Script that runs on the Shelly itself (independent safety layer) |
| `../host_test/` | Runs this sketch on a PC against a simulated oven and Shelly (`./run.sh`) |

## Supported boards

**Elecrow CrowPanel 2.8" ESP32 HMI (default).** The board the v12 enclosure is designed for. Elecrow also sells it as the "2.8inch ESP32 Solo Miner / NerdMiner" display (Amazon ASIN B0H11B33ZK, a 2-pack): same ESP32-WROOM-32-N4, ILI9341V, resistive touch and connectors. Wiring: [sheet 2 of the wiring diagrams](../../docs/wiring/reflow-wiring-low-voltage.png) (SSR on J7 IO32, active-low; MAX6675 on J6/J10).

**Freenove ESP32-S3 Display 3.5" (FNK0104N), backup option.** Uncomment `BOARD_FREENOVE_S3_35` in `config.h`. It needs a new front panel. Wiring, from Freenove's schematic (only these four lines are free):

| Connector | Pin | To |
| --- | --- | --- |
| P3 Extended IO | 1 3V3 | MAX6675 VCC |
| P3 | 2 GND | MAX6675 GND |
| P3 | 3 IO46 | SSR + (`T3`) |
| P3 | 4 IO45 | MAX6675 CS |
| P2 UART | 1 +5V | **not used, insulate** |
| P2 | 2 GND | SSR − (`T4`) |
| P2 | 3 TXD0 / IO43 | MAX6675 SCK |
| P2 | 4 RXD0 / IO44 | MAX6675 SO |

IO45/IO46 have weak pull-downs at reset, so the SSR stays off through boot. Here the SSR is active-high (pin to GND), the opposite of the CrowPanel. Check the pin order against the silkscreen with a meter before wiring.

## Arduino IDE setup

### CrowPanel 2.8
1. Boards Manager: **esp32 by Espressif, 3.x**. Board: **ESP32 Dev Module**.
2. Library Manager: **TFT_eSPI** (2.5.43 tested by others with this board).
3. Copy `User_Setup_CrowPanel28.h` over `Arduino/libraries/TFT_eSPI/User_Setup.h` (back up the original first).
4. Copy `secrets.example.h` to `secrets.h` (same folder) and put your Wi-Fi name, password and the Shelly's IP address in it. Then upload.
5. On first boot it runs touch calibration (tap the corners). To recalibrate later, hold a finger on the screen while it boots.
6. If the image is upside down, change `TFT_ROTATION` in `config.h` (1 or 3) and recalibrate.

### Freenove 3.5"
1. Boards Manager: **esp32 3.2.0** (the version Freenove's tutorial specifies). Board: **ESP32S3 Dev Module**.
2. Tools: **USB CDC On Boot: Enabled**, **PSRAM: OPI PSRAM**, Flash Size 16MB.
3. Install Freenove's TFT_eSPI build from their repo (`Libraries/FNK0104N/TFT_eSPI_v2.5.43.zip`, Sketch > Include Library > Add .ZIP), not the stock one. It contains the ST77922 display and touch drivers.
4. In `config.h`, select `BOARD_FREENOVE_S3_35`. Copy `secrets.example.h` to `secrets.h` and set Wi-Fi and Shelly there. Upload.

## How a run works

1. Pick a profile with `<` `>` and press **START**.
2. **Arming (about 5 s, SSR off):** the thermocouple must be reading and the oven must be below 60 °C. The Shelly must close its relay (`Switch.Set ... toggle_after=30`). Then the stuck-SSR check: with the relay closed and the SSR off for 5 s, the Shelly must read less than 40 W. If the Shelly doesn't answer within 15 s, the run aborts.
3. **Running:** the PID chases the profile 15 s ahead (the oven lags), and the SSR is switched with a 2 s slow-PWM window. The board re-arms the Shelly every 15 s; if the board hangs or resets, the Shelly opens its relay 30 s later on its own.
   * Whenever the oven is more than 10 °C behind the profile, the profile clock **holds** so the oven can catch up. A weak oven then stretches the profile instead of missing the peak.
4. **Cooling:** heating stops, the Shelly relay is opened, and the screen says to open the door slowly. Done below 50 °C.

The serial port (115200) logs CSV lines `t_s,setpoint_c,temp_c,duty_pct,ssr,mode`. Paste them into a spreadsheet to tune. Serial commands: `g` start, `x` abort.

## The Shelly link

The Shelly calls run in their own task on the other CPU core, so a slow network call never delays the SSR.

* **Heartbeat.** Every 15 s: `Switch.GetStatus`, then `Switch.Set on=true toggle_after=30`. A failed call is retried every 2 s. A Wi-Fi dropout of a few seconds does not end the run; 25 s without a successful call does ("Lost contact with Shelly"), which is before the Shelly's own 30 s timeout.
* **The relay is closed once per run.** After that the board only keeps a closed relay closed. If the status call shows the relay open (the Shelly's power, current or temperature limit, the supervisor script, the timeout, or someone in the app), the board leaves it open and aborts with "Shelly opened its relay".
* **Stuck-SSR check.** SSRs fail shorted, and then only the Shelly relay switches the oven. The board checks before every run, and again at any heartbeat that finds the SSR off for 5 s or more: power above `SSR_STUCK_POWER_W` (40 W) with the SSR off aborts with "SSR stuck on: replace it". If a healthy SSR is ever flagged, look at the Shelly's power reading in its web page with the oven idle, and raise `SSR_CHECK_SETTLE_MS` or `SSR_STUCK_POWER_W` in `config.h`.
* **Each task watches the other.** If the control loop stops running for 5 s, the Shelly task releases the SSR pin, opens the relay and stops the heartbeat ("Controller stalled").
* **Run state.** The board writes `reflow_active` to the Shelly's KVS store for the supervisor script.
* If the Shelly's answer can't be read (a firmware change on its side, say), the serial log prints `# Shelly status not understood` once, and the relay and stuck-SSR checks are skipped. The run still works; the heartbeat, the script and the other aborts still apply.

`SHELLY_REQUIRED false` in `config.h` lets a run start without the Shelly. Use it only for the no-mains bench test below.

## Safety aborts (any one ends the run, SSR off, Shelly off)

| On screen | Cause |
| --- | --- |
| Thermocouple not reading | Probe open, unplugged, or a data wire fault (4 bad reads in a row, about 1 s) |
| Oven too hot to start | Above 60 °C at START (`START_MAX_C`) |
| Over max temperature | Above 260 °C |
| Too far above profile | More than 30 °C above the profile |
| No temp rise: check probe | SSR above 80 % for 60 s with less than 5 °C rise: probe fell out, element failed, or the oven's own thermostat is limiting |
| Max run time exceeded | Run longer than 15 min |
| Shelly not reachable | No answer within 15 s of START |
| Lost contact with Shelly | No heartbeat got through for 25 s |
| Shelly opened its relay | See "The Shelly link" |
| SSR stuck on: replace it | See "The Shelly link" |
| Controller stalled | The control loop stopped for 5 s |
| Stopped by user / Stopped from serial | STOP button, or `x` on serial |

Plus, independent of this board:
* **Shelly script** (`../shelly/reflow_supervisor.js`): relay on longer than 15 min, Shelly above 70 °C, or oven drawing more than 40 W while the controller says it's idle. After a trip it holds the relay open for 5 minutes.
* **Shelly settings:** power-on default off, 1400 W power limit, 11 A current limit.
* **Oven thermostat** left in circuit at maximum.

## Test order

0. On a PC, any time the firmware changes: `../host_test/run.sh` (needs g++; a few seconds).
1. Flash `firmware/bench_test/bench_test.ino` first and do the build guide's bench checks.
2. Flash this sketch with `SHELLY_REQUIRED false`, the SSR wired, and no mains: press START and watch the SSR LED pulse and the CSV output. Pull the thermocouple plug: it must abort.
3. Install the Shelly script, set `SHELLY_REQUIRED true`, and repeat with the incandescent lamp in the oven socket (BUILD-GUIDE section 5). This is the first time the sketch talks to the real Shelly. In the serial log, look for `# SSR off, Shelly reads 0.0 W` (or a watt or two) before `# running`, and no `Shelly status not understood` line.
4. First oven run: an empty oven with the probe in the middle, using the low-temp or bake profile. Watch the whole time.

## Tuning

The PID starting values are guesses for a 1150 W toaster oven. Do an empty run, look at the CSV:
* Lags behind on the ramps and the clock holds a lot → raise `SETPOINT_LOOKAHEAD_S` (20 to 30) or `PID_KP`.
* Overshoots the peak or the bake temperature → lower `PID_KP` or raise `PID_KD`.
* Sits a few degrees under a plateau → raise `PID_KI` a little.

The P and D terms work on the setpoint 15 s ahead; the I term works on the real error, so it settles the plateaus without winding up during the ramps. On the model oven in the PC test the bake profile overshoots by about 7 °C and the reflow profiles peak 0 to 5 °C under. A real oven will differ.

The TO1313SBD's own thermostat tops out around 232 °C. SAC305's 245 °C peak may not be reachable, so leaded or low-temp paste is the safer choice.
