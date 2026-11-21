# Reflow controller firmware

Touchscreen reflow controller for the CYD reflow oven: profiles, PID control of the SSR, safety aborts, and a heartbeat to the Shelly 1PM Gen4 so the Shelly cuts the oven if this board hangs.

> ⚠️ Not yet run on hardware. It has been syntax-checked on a PC against stub headers for both boards, and the control loop was simulated against a simple oven model. The first real compile is in the Arduino IDE, and the first runs must be on the bench with a lamp as the load ([BUILD-GUIDE](../../docs/BUILD-GUIDE.md) section 5).

## Files

| File | What it is |
| --- | --- |
| `reflow_controller.ino` | Main sketch: state machine, PID, slow-PWM SSR, safety, UI, Shelly task |
| `config.h` | **Edit this:** board choice, Wi-Fi, Shelly IP, pins, PID gains, safety limits |
| `profiles.h` | Reflow profiles (Sn63/Pb37, Sn42/Bi58 low-temp, SAC305, 120 °C bake) |
| `board.h` | Display and touch code for each supported board |
| `User_Setup_CrowPanel28.h` | TFT_eSPI setup for the CrowPanel 2.8 |
| `../shelly/reflow_supervisor.js` | Script that runs on the Shelly itself (independent safety layer) |

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
4. Edit `config.h` (Wi-Fi, `SHELLY_HOST`), then upload.
5. On first boot it runs touch calibration (tap the corners). To recalibrate later, hold a finger on the screen while it boots.
6. If the image is upside down, change `TFT_ROTATION` in `config.h` (1 or 3) and recalibrate.

### Freenove 3.5"
1. Boards Manager: **esp32 3.2.0** (the version Freenove's tutorial specifies). Board: **ESP32S3 Dev Module**.
2. Tools: **USB CDC On Boot: Enabled**, **PSRAM: OPI PSRAM**, Flash Size 16MB.
3. Install Freenove's TFT_eSPI build from their repo (`Libraries/FNK0104N/TFT_eSPI_v2.5.43.zip`, Sketch > Include Library > Add .ZIP), not the stock one. It contains the ST77922 display and touch drivers.
4. In `config.h`, select `BOARD_FREENOVE_S3_35`, set Wi-Fi and Shelly, upload.

## How a run works

1. Pick a profile with `<` `>` and press **START**.
2. **Arming:** the thermocouple must be reading, and the Shelly must confirm its relay is on (`Switch.Set ... toggle_after=30`). Otherwise the run aborts after 10 s.
3. **Running:** the PID chases the profile 15 s ahead (the oven lags), and the SSR is switched with a 2 s slow-PWM window. The board re-arms the Shelly every 15 s; if the board hangs, the Shelly opens its relay 30 s later on its own.
   * If the oven is at full power and still more than 10 °C behind, the profile clock **holds** so the oven can catch up. A weak oven then stretches the profile instead of missing the peak.
4. **Cooling:** heating stops, the Shelly relay is opened, and the screen says to open the door slowly. Done below 50 °C.

The serial port (115200) logs CSV lines `t_s,setpoint_c,temp_c,duty_pct,ssr,mode`. Paste them into a spreadsheet to tune. Serial commands: `g` start, `x` abort.

## Safety aborts (any one ends the run, SSR off, Shelly off)

* Thermocouple open or not reading (4 bad reads in a row)
* Above 260 °C, or more than 30 °C above the profile
* SSR above 80 % for 60 s with less than 5 °C rise (probe fell out, element failed)
* Run longer than 15 min
* Shelly heartbeat failed twice in a row (with `SHELLY_REQUIRED`)
* STOP button or `x` on serial

Plus, independent of this board:
* **Shelly script** (`../shelly/reflow_supervisor.js`): relay on longer than 15 min, Shelly above 70 °C, or oven drawing more than 40 W while the controller says it's idle (a shorted SSR).
* **Shelly settings:** power-on default off, 1400 W power limit, 11 A current limit.
* **Oven thermostat** left in circuit at maximum.

## Bench test order (no oven yet)

1. Flash `firmware/bench_test/bench_test.ino` first and do the build guide's bench checks.
2. Flash this sketch with `SHELLY_REQUIRED false`, the SSR wired, and no mains: press START and watch the SSR LED pulse and the CSV output. Pull the thermocouple plug: it must abort.
3. Install the Shelly script, set `SHELLY_REQUIRED true`, and repeat with the incandescent lamp in the oven socket (BUILD-GUIDE section 5).
4. First oven run: an empty oven with the probe in the middle, using the low-temp or bake profile. Watch the whole time.

## Tuning

The PID starting values are guesses for a 1150 W toaster oven. Do an empty run, look at the CSV:
* Lags behind on the ramps and the clock holds a lot → raise `SETPOINT_LOOKAHEAD_S` (20 to 30) or `PID_KP`.
* Overshoots the peak → lower `PID_KP` or raise `PID_KD`.
* Sits a few degrees under the soak plateau → raise `PID_KI` a little.

The TO1313SBD's own thermostat tops out around 232 °C. SAC305's 245 °C peak may not be reachable, so leaded or low-temp paste is the safer choice.
