# CYD Reflow Oven — Full Design Re-Review (October 2026)

Reviewed against commit `663b7d9` (2026-07-24), the v10.3 OpenSCAD source, every repo mesh, the project's earlier design discussions, and current manufacturer and datasheet sources. Anything that could not be verified is labeled as such. Sources are listed at the end.

## Bottom line

Nine findings should be closed before the oven load is connected. None requires reprinting the bottom shell (the gland hole can be drilled out); two touch the lid.

| # | Finding | Severity | Fix |
| --- | --- | --- | --- |
| 1 | The C13 power cord feeding the inlet is not specified. Common PC cords are 18 AWG (10 A); 9.6 A is 96 % of that, outside the box | Must fix | Use a 14 AWG SJT cord set rated 15 A |
| 2 | Lid vent slots sit over the SSR, whose mains screw terminals are about 8 mm below the lid; how directly depends on its orientation. A wire or solder scrap through a 3 mm slot can reach live T1/T2 | Must fix | Fit the SSR's clear terminal cover, and move or baffle the vents (a lid change) |
| 3 | No intake vents anywhere. SSR heat at full on is up to 15.4 W (Fotek spec, 1.6 V max drop), and the Shelly's limit is 40 °C ambient | Must measure | Dummy-load run logging the Shelly's own temperature; decide on heatsink-outside or side intakes from the data |
| 4 | The 13 mm oven-lead gland hole fits a PG7 gland (clamps 3–6.5 mm); SJT 16/3 is 8.38 mm and 14/3 is 9.27 mm | Must fix | M16 gland, 5–10 mm clamp range, and resize the hole |
| 5 | The GPIO17 MOSFET gate shares a pad with the active-low blue LED; GPIO17 has no pull at reset, and the AO3400A threshold starts at 0.65 V | Must measure | Measure gate voltage at power-up; removing R16 (1 kΩ, per the schematic) removes the path |
| 6 | Touch on VSPI (per the bring-up firmware) collides with the microSD card on the same bus | Design | Keep profiles in internal flash, or bit-bang the touch |
| 7 | The CYD window is 48 × 65 mm with the long axis front-to-back, so the screen reads portrait (240 × 320) | Decide | Portrait UI, or rotate the board (wider box) |
| 8 | Inlet fuse type and the module's real rating are not recorded; the Shelly in the BOM is the EU model, not Shelly's UL-certified US version | Confirm | Read the module's back label; ceramic time-delay fuse; consider the UL Shelly |
| 9 | README and SCAD header described GPIO1, the 3Dman inlet, capacitive touch and the pre-July topology | Docs | Corrected in the commit that added this file (see Repo inconsistencies) |

On adding a Raspberry Pi Pico or Arduino: it does not add safety, because it has no switch of its own in the heat path. The Shelly can run an independent supervisor script today. A second microcontroller only earns its place if two thermocouples, two aux outputs and an E-KILL input are all wanted together; see Controller board.

## Build and print

All printed parts already print without supports. Measured: nothing overhangs past 45° except slivers under 4 mm, and the longest bridge is 48 mm.

**What was measured.** The v10.3 SCAD was rendered with OpenSCAD 2021.01 and diffed volumetrically (manifold booleans) against the repo meshes. The bottom matches `reflow-v9_6-bottom.stl`, the lid matches `reflow-v10_3-lid.stl` and the 3MF lid, the bezel matches `reflow-v9_9-bezel.stl` and the 3MF bezel, the trim plate matches `reflow-v9_6-iec-trim-plate.stl`, and the KP200 coupon matches the 3MF coupon: 0.00 mm³ difference in both directions for each (0.01 mm³ numeric noise on the 3MF lid). Every downward-facing surface was then scanned in print orientation.

| Part | Downward surfaces found | Span | Support needed? |
| --- | --- | --- | --- |
| Bottom shell | IEC cutout top edge at z 45.2 | 48 mm bridge, 3 mm deep | No: bridge; already printed successfully |
| Bottom shell | USB slot top edge at z 54 | 16 mm bridge | No |
| Bottom shell | Four foot recesses at z 0.8 | 12 mm circles | No: short bridges |
| Bottom shell | Gland, thermocouple and divider holes | Arcs under 2 mm tall | No |
| Lid | Two KP200 tab pockets at z 1.2, 45° lead-ins | 22 × 15.5 mm, supported on four sides | No: bridge |
| Bezel, IEC trim plate | None | — | No |

Bambu Studio was not available for this review, so its auto-support decision is not verified; the geometry above is.

**Assembly pain points, with support-free fixes** (none applied; each needs owner approval and a coupon):

| Pain point (from the SCAD) | Fix | Why it prints without supports |
| --- | --- | --- |
| Divider pass-throughs are closed 6 mm holes, so wires must be threaded before they are terminated | U-slots open to the divider's top edge; the lid closes them | No ceiling left to bridge |
| SSR drive is a hand-soldered wire on an SMD LED pad | Either remove R16 and solder there, or switch boards (Controller board) | — |
| No SSR retention | A corral of vertical walls on the floor, with raised ribs that double as the thermal break under the heatsink | Vertical walls only |
| No Shelly mount | A snap pocket away from the heatsink, placed after the KP200 depth is measured | Vertical walls only |
| No cable tie points | Zip-tie bridges on the floor beside each wire run | 5 mm bridges |
| 14 heat-set inserts (8 lid-screw bosses in the bottom shell, 4 CYD and 2 KP200 on the lid); KP200 pockets are 4.5 mm vs 4.2 mm elsewhere | Confirm the KP200's screw thread; the insert must match it | — |
| MAX6675 bosses are 3.5 mm holes, 4 mm deep, with no stated screw | Name the screw (self-tap M3 or insert) in the SCAD | — |
| Thermal fixes, if the dummy-load run fails | Vertical intake slots in a side wall, or a heatsink notch open to the wall's top edge | 3 mm bridges, or none |

The lid carries both the KP200 (mains) and the CYD. Leave service loops long enough to hinge the lid open beside the box, and wire the KP200 last.

## Controller board

The current CYD can run one thermocouple and the SSR only by soldering to an LED pad. The Elecrow CrowPanel 2.8 ESP32 HMI exposes six free lines on keyed connectors, enough for two thermocouples, SSR and one aux, with no pad soldering. Switching boards means a new lid window and hole pattern, and its outline drawing could not be retrieved, so fit is unverified.

**CYD facts read from the manufacturer schematic** (ESP32-2432S028 V0.1, 2022, in the witnessmenow repository's `OriginalDocumentation/5-Schematic`). The AITRIP board in this build is a clone; it has not been confirmed to match this revision.

- RGB LED: R16, R17 and R20 are 1 kΩ from 3.3 V to the LED anodes; the cathodes go to IO17, IO4 and IO16. With a 10 kΩ pulldown the floating GPIO17 pad sits at (3.3 V − LED Vf) × 10/11. The LED's forward voltage at about 80 µA is not published; for 2.3–2.6 V the gate sees 0.64–0.91 V, against the AO3400A's 0.65 V minimum threshold. Removing R16 removes the path.
- CN1: pin 1 is 3.3 V; pin 2 is IO27 with R18, a 10 kΩ pull-up to 3.3 V, so the MAX6675 CS already idles deselected. Pin 3 has no net label in V0.1; PINS.md says IO22. Pin 4 is GND.
- P3: pin 1 IO21 (backlight MOSFET gate, 10 kΩ pulldown), pin 2 IO22, pin 3 IO35, pin 4 GND.
- P1: pin 1 VIN reaches the 5 V rail through an AO3401 P-MOSFET with its gate grounded, so on USB power VIN should sit at the 5 V rail (schematic analysis; meter it before using it to feed the SSR). Pins 2 and 3 are U0TXD and U0RXD through 100 Ω each, and U0RXD is the same net the CH340's TXD drives. An external transmitter on P1 would fight the CH340, so P1 is not a usable serial input.
- Speaker P4 is drawn as a JST PH 2.0 mm 2-pin; PINS.md calls it 1.25 mm. Measure before buying a plug.

| | CYD, as built | Elecrow CrowPanel 2.8 ESP32 HMI | CYD plus Pico |
| --- | --- | --- | --- |
| MCU and touch | ESP32-WROOM-32, resistive XPT2046 | ESP32-WROOM-32-N4, resistive | Same CYD + RP2040 |
| Free lines on connectors | IO22, IO27, IO35 (all taken by thermocouple 1) | GPIO_D IO25, IO32; UART1 IO16, IO17; I2C IO21, IO22 | Pico pins, but the link must use CN1 (P1 RX is shared, above), so thermocouples move to the Pico |
| Connector type | 1.25 mm PicoBlade | HY2.0-4P keyed connectors | Mixed |
| Pad soldering | Yes, for the SSR | None | None |
| Touch and SD bus clash | Yes (touch on VSPI in the bring-up code) | No: Elecrow's TFT_eSPI setup puts touch CS 33 on the display bus | Yes |
| Two TCs + SSR + one aux | No | Yes, exactly six lines | Yes |
| E-KILL input too | No | No | Yes |
| Price checked | Not re-checked | $24.02 (RobotShop) | Not checked |
| Fits the current lid | Yes | No: new window and holes; outline drawing not retrieved; Elecrow's two pages give different active areas (43.2 × 57.6 vs 85.8 × 54 mm) | Yes |

Boot behavior of the CrowPanel's six lines: none has an internal pull at reset per Espressif's IO_MUX table, so a 10 kΩ pulldown alone holds an SSR gate low. That only holds if the board adds no pull-ups of its own on those connectors, and its schematic was not found. Two checks before buying: the outline drawing, and a schematic or a meter on the connector lines.

Recommendation: the CrowPanel if both checks pass, because it removes the hardest build step and the bus clash. Otherwise keep the CYD, remove R16, keep profiles in flash, and stop at one aux output.

Design inspiration for menus and features: the Unexpected Maker [Reflow Master Pro](https://lectronz.com/products/210) (two MAX31855 thermocouples, two aux outputs, four-button UI, web interface). Its photos are not reproduced here.

## AC power path

The FILSHU inlet with a 15 A fuse fixes the in-box problem the 3Dman module had: 9.6 A is 64 % of the fuse, and the 14 AWG leads are protected by it. The weak links have moved to the parts on either side of the box.

| Part (wall to oven) | Rating, as verified | Load vs rating | Action |
| --- | --- | --- | --- |
| Branch circuit | Unknown: 15 A or 20 A | — | Record it. On 20 A, the inlet fuse is the only protection for the box wiring |
| C13 cord set into the inlet | 14 AWG = 15 A, 16 AWG = 13 A (UL catalog); 18 AWG = 10 A (NEC 400.5) | 96 % if it is a typical 18 AWG PC cord | Buy a 14 AWG SJT NEMA 5-15P to C13 cord |
| FILSHU C14 inlet + rocker | Listing says 15 A, 14 AWG leads, single-pole. The listing could not be retrieved (Amazon blocks automated reads) | 64 % if 15 A is real | Read the rating molded on the back of the module and record it in the BOM |
| Inlet fuse | 15 A, type not recorded | 64 % | Confirm ceramic, time-delay 5 × 20 mm. A glass body has low breaking capacity on a 20 A circuit. 12 A (125 % of load) also works |
| Shelly 1PM Gen4 (S4SW-001P16EU) | 16 A max switching at 240 V; 110–240 V supply; ambient −20 to 40 °C; needs external protection of 16 A max (Shelly KB) | 60 % | The 15 A fuse meets the 16 A protection requirement. The KB lists EU/UK conformity only. Shelly's US store sells a separate UL-certified 1PM Gen4; the EU model in the BOM is not that one. Add `current_limit` (about 11 A) beside the 1400 W `power_limit` |
| Inkbird SSR-40DA | 40 A, 3–32 VDC input, zero-cross. Inkbird publishes no drop or leakage; the Fotek SSR-40DA spec it follows gives 1.6 V max drop and 3.0 mA off-state leakage | 24 % | Fine electrically; heat is the issue (Thermal) |
| Oven trailing lead | Gauge unknown | — | Needs 16 AWG minimum, 14 AWG preferred. Label the socket oven-only |
| Cable gland for that lead | SCAD hole is 13 mm; the June wiring diagram called it M16 | — | Too small, verified. A 13 mm hole fits a PG7 gland (12.5–12.7 mm hole, clamps 3–6.5 mm). SJT 14/3 is 9.27 mm OD and 16/3 is 8.38 mm. An M16 gland with a 5–10 mm clamp range fits both |

The split topology still holds up. The Shelly is the only contact that can stop a shorted SSR, the KP200 branch carries only the USB adapter, and the fuse is confirmed in the hot leg. The Shelly's API supports everything the README plans: `toggle_after` on `Switch.Set` for the watchdog, plus status fields for `temperature`, `apower`, `current` and `overtemp`/`overpower` errors.

## Thermal

The Shelly's 40 °C ambient limit, not the plastic, is the tightest thermal constraint in the box, and the estimate below says a long bake can exceed it. These are estimates, not measurements; the measurement plan settles them.

| Quantity | Value | Basis |
| --- | --- | --- |
| SSR heat at 100 % duty | 11.5–15.4 W | 9.6 A × up to 1.6 V, the maximum drop in the Fotek SSR-40DA spec this part follows; Inkbird publishes no figure |
| Other heat (Shelly, KP200, USB adapter, CYD) | about 2–4 W | Shelly is under 1 W per its KB; the rest estimated |
| Box outer surface | 0.117 m² | 220 × 155 × 65 mm |
| Vent area | 1,218 mm², all in the lid, none low | 7 slots × 3 × 58 mm from the SCAD |
| Sealed-box air rise at full heat | roughly 13–19 K over the bench | Assumes about 8–9 W/m²·K combined convection and radiation, so about 1 W/K for that area |
| Air inside, bench at 30 °C beside the oven | about 43–49 °C | Shelly limit 40 °C |

A single reflow run is short, about 5–8 minutes, so the box will not reach that steady state. Bake mode and back-to-back runs will. The lid slots help, but with no low intake there is little chimney flow.

The heatsink also stands on the printed floor. PETG's glass transition is about 81 °C and ASA's about 100 °C, and printed parts creep under sustained load below that. The shell material is still unconfirmed.

Measurement plan, using hardware already installed:

1. Close the box and run the oven empty at 100 % for 10 minutes, then 50 % for 30 minutes.
2. Log the Shelly's own temperature (`temperature.tC` in `Switch.GetStatus`) through Home Assistant every 10 s.
3. Tape a spare K-type to the heatsink base where it meets the floor.
4. Pass, using proposed margins: Shelly reading under 35 °C (5 K below its 40 °C limit) and floor contact under 60 °C (about 20 K below PETG's transition).

If it fails, the options in order of effect: heatsink fins outside through a wall cutout; low intake slots on a side wall; or a small 5 V fan on an aux output. In every case, a Shelly script that opens the relay on its own temperature reading is a free extra guard.

## Enclosure (v10.3 SCAD and repo meshes)

The printed geometry is sound as a mesh, but the source still models the July parts list: no Shelly, no SSR retention, and an inlet cutout sized to the 3Dman body. No geometry was changed in this review.

All four STLs and all three 3MF parts are watertight with consistent winding after vertex welding.

| Area | What the SCAD does | Problem | Proposed fix |
| --- | --- | --- | --- |
| Lid vents | 7 slots, 3 × 58 mm, centered over the SSR | The slot field spans x 101–140, y 76–134. If the SSR's long axis runs front-to-back, its live terminals sit under the slots; if it runs across, they sit at the slot edges. Either way they are about 8 mm below the lid (measured heatsink stack). SSR orientation not yet recorded | Terminal cover on the SSR, then move the slots off the terminal ends or add an internal baffle |
| Airflow | Lid outlet only; feet recesses 0.8 mm, no protruding feet | No low intake | Low side-wall intake slots, or heatsink fins outside |
| Shelly | Not modeled | The README fallback pocket (x 95–145, y 34–65) sits between the inlet's wire keepout (to y 39.5 at the 3Dman's 21.5 mm depth; to about y 52 if the FILSHU is 34 mm deep) and the heatsink face (y 65). That puts a 40 °C-rated part against the hottest surface | Measure the KP200 body depth; if under 40 mm, lay the Shelly flat under it, away from the sink |
| SSR retention | Not modeled (open since July) | Heatsink can slide; its base sits on bare printed floor | A corral bracket with a raised standoff doubles as a thermal break |
| Inlet cutout | 48 × 28.5 mm, from the 3Dman body (47 × 27.5 × 21.5) | FILSHU body not recorded; a past listing for a similar module gave 34 mm depth | Record the FILSHU's measured body and depth in the SCAD |
| Oven lead gland | 13 mm hole, left wall | Too small to clamp SJT cord, verified (see AC path) | Size the hole to the gland purchased |
| Display window | 48 mm (x) by 65 mm (y): board rotated 90° to save width | The screen reads portrait to the user | Design the UI at 240 × 320, or widen the box to mount it landscape |
| Comments | Y = rear to front, inlet on the rear wall at y = 0 | The v9.8 note calls y = 0 the front wall | Confirm on the physical box; it decides which way the UI is rotated |

## Control side and firmware

The CYD has room for a second thermocouple, the beeper, profiles in flash and one aux output, but not for a second aux output or an E-KILL input as well.

| Reflow Master Pro feature | CYD resource | Fits? |
| --- | --- | --- |
| Thermocouple 1 | GPIO22 SCK, GPIO27 CS, GPIO35 SO (working) | Yes |
| Thermocouple 2 | Second MAX6675 sharing SCK and SO, CS on GPIO4 or GPIO16 (RGB LED pins, so another pad solder). The MAX6675 releases SO within 100 ns of CS going high (datasheet tTR) | Yes |
| UI beep | GPIO26 drives the onboard speaker amp; needs a small speaker on its connector | Yes |
| Profiles on storage | Internal flash (LittleFS) recommended; microSD only if touch moves off VSPI (see bus table) | Yes |
| Web UI, MQTT to Home Assistant | Built in; Wi-Fi is already required for the Shelly heartbeat | Yes |
| Aux output 1 (fan) | The other RGB LED pin, through a MOSFET | Yes |
| Aux output 2 | No pin left | No |
| E-KILL input | GPIO0 is a boot strap pin; GPIO34 is input-only with no pull-up and carries the light sensor | No, and a kill should open a contact anyway; the rocker does that |

**Shared buses and connectors on the CYD, as wired today:**

| Bus or connector | Pins | Shared with | Consequence |
| --- | --- | --- | --- |
| HSPI (hardware) | 2, 12, 13, 14, 15; backlight 21 | Display only | No conflict |
| VSPI (hardware) | 5, 18, 19, 23 | microSD | The bring-up firmware put XPT2046 touch on VSPI too. Display, touch and SD together then fail (Random Nerd Tutorials; Arduino forum) |
| Touch | 25 CLK, 32 MOSI, 39 MISO, 33 CS, 36 IRQ | VSPI peripheral in the bring-up code | Either bit-bang touch, or keep profiles in internal flash (LittleFS) and skip the SD card. Flash is the simpler choice |
| MAX6675 (bit-banged) | 22 SCK, 27 CS, 35 SO | GPIO22 is the same net on P3 and CN1 | Anything plugged into the other connector shares that clock line |
| P1 | VIN, GPIO1 TX, GPIO3 RX, GND | UART0, boot log | TX is fine for logging. RX shares its net with the CH340's TXD (schematic), so P1 is not a usable link input, and neither pin is safe for a switching output |
| CN1 | GND, 22, 27, 3.3 V | MAX6675 | Power the MAX6675 from this 3.3 V pin. Its SO pin drives GPIO35, and Espressif's datasheet gives 3.6 V as the supply ceiling with no 5 V tolerance stated |

**Reset states, from Espressif's IO_MUX table:** all pins are output-disabled during reset. GPIO1 has its pull-up on, and the ROM prints its boot log on U0TXD by default, which confirms the original GPIO1 fault. GPIO17 and GPIO16 have no pull at all, so a 10 kΩ gate pulldown is the only thing holding the gate low. GPIO4 has an internal pull-down, which makes it the better choice of the two remaining LED pins for any future output.

**The GPIO17 gate drive needs a check.** Per the CYD schematic, the blue LED's anode connects to 3.3 V through R16 (1 kΩ) and its cathode to GPIO17. GPIO17 has no internal pull at reset, so while the pin floats, that path and the 10 kΩ pulldown form a divider: gate = (3.3 V − LED Vf) × 10/11. The LED's forward voltage at about 80 µA is not published; for 2.3–2.6 V the gate sits at 0.64–0.91 V. The AO3400A named in the README has a gate threshold of 0.65 V min, 1.05 V typical, so the two can overlap. The fitted MOSFET part is not recorded. Removing R16 eliminates the path; otherwise measure gate-to-source voltage through a power-up with the SSR input connected. Side effect: with the LED fitted, blue lights when the SSR is off.

**Firmware safety rules to build in from the start:**

- Shelly script, independent of the CYD: heartbeat via `toggle_after`; a maximum run time; trip on the Shelly's own temperature; trip on power draw while the CYD reports idle.
- CYD: abort on the MAX6675 open-thermocouple bit (D2); abort if the SSR runs above 80 % for 60 s without a temperature rise (probe fell out); a hard temperature ceiling; with two thermocouples, abort when they disagree.
- Read the MAX6675 no faster than its 0.17–0.22 s conversion time.
- The oven's own thermostat at maximum is a crude hardware ceiling. Home Depot Canada lists the TO1313SBD at up to 450 degrees, which for this oven means 450 °F (232 °C). Its wattage is not on any page that could be retrieved; the rating plate is the source. That ceiling clears a low-temperature paste like TS391LT but may cap a SAC305 peak.

## Pico or Arduino?

Not for v1. A second microcontroller only makes the oven safer if it controls a contact in series with the heating element, and the only two such contacts are the SSR (which fails shorted) and the Shelly. The Shelly already has an independent processor, its own temperature sensor and power metering, so it is the right place for the supervisor.

| Option | What it adds | What it costs | Verdict |
| --- | --- | --- | --- |
| CYD only | Two thermocouples, beeper, profiles in flash, one aux output, web UI and MQTT | Nothing new | Recommended if the CYD is kept |
| Shelly supervisor script | Heartbeat, max run time, own-temperature trip, power-while-idle trip | Script only; hardware already installed | Do it regardless |
| Raspberry Pi Pico as I/O coprocessor, linked by UART2 on CN1 (P1's RX is shared with the CH340) | Runs thermocouples, SSR and aux outputs; enough pins for two aux outputs and an E-KILL input; CYD becomes UI only; 3.3 V logic matches the ESP32 | A second firmware and a framed, checksummed link with its own heartbeat. CN1 then carries the link, so the thermocouples must move to the Pico. The SSR command then lives on the Pico, which needs its own boot-state check | Superseded by the CrowPanel option, which gets the same I/O with one board |
| 5 V Arduino (Uno, Nano) | Same as the Pico | Everything above plus level shifting, since the ESP32 is a 3.6 V-max part | No |

## Repo inconsistencies

The repo contradicted itself in twelve places, and it contains no firmware; every sketch so far lives outside the repo. Each row was read directly from commit `663b7d9`.

| Where | It said | Status |
| --- | --- | --- |
| README, Features | Capacitive touch | Fixed: resistive (XPT2046) |
| README, Power Flow Topology | 3Dman fused inlet | Fixed: FILSHU 15 A inlet |
| README, pin table, divider note, flashing rules, startup order | SSR on GPIO1 | Known-issue warning added; tables keep GPIO1 until the GPIO17 MOSFET driver is confirmed fitted |
| README, "Why the split" | Cutting CYD power de-energizes GPIO 1 | Fixed: "the SSR drive pin" |
| README, Repository Structure | 3MF v9_9 and STL v9_9 lid | Fixed: lists the files actually in the repo |
| README, Print Advisory | STL exports lag v10.3 | Fixed: meshes verified identical to a fresh v10.3 render |
| README, Roadmap | Export v10.3 STLs | Closed: not needed |
| README, Completed: C14 upgrade | C13/C14 is rated 10 A | Annotated: 10 A is the IEC rating; North American cord sets reach 15 A with 14 AWG |
| README, Completed: inlet leads | 18 gauge, marginal | Annotated: applied to the retired 3Dman module |
| SCAD header | AC path runs through the KP200 to the SSR | Annotated as superseded (comment-only; geometry re-verified identical) |
| SCAD comments and echo line | 3Dman inlet; CYD holes assumed 82 × 44 | Fixed (comment-only); inlet cutout still sized from the 3Dman body |
| Wiring PNG and SVG | Pre-split topology | Open: redraw |

## Open questions

Twelve facts that only the builder can supply decide the remaining items:

- [ ] Is the bench outlet on a 15 A or a 20 A breaker?
- [ ] What gauge is the C13 cord feeding the inlet?
- [ ] What rating is molded on the back of the FILSHU module, what fuse type is fitted, and what are its body size and depth?
- [ ] Is the GPIO17 MOSFET driver fitted now? Which MOSFET, and is the SSR + terminal on 5 V from P1 VIN?
- [ ] Is the MAX6675 powered from CN1's 3.3 V or from 5 V?
- [ ] Which Shelly is installed: the EU S4SW-001P16EU in the BOM, or the US UL-certified version?
- [ ] Is the printed shell PETG or ASA?
- [ ] Is the SSR's clear terminal cover fitted, and which way does the SSR's long axis run?
- [ ] What gauge is the oven trailing lead, and which gland was bought?
- [ ] What is the KP200's real body depth (decides whether the Shelly lies flat under it)?
- [ ] Portrait UI at 240 × 320 with the current box, or a wider box for landscape? Which wall faces the user?
- [ ] Which thermocouple probe: a bare bead, or the screw-in probe that ships with most MAX6675 kits?

**Not verified, stated plainly:** the FILSHU listing (Amazon refuses automated reads, and no other source carries it); the oven's wattage; whether the AITRIP clone matches the V0.1 schematic; the LED's forward voltage at microamp currents; the CrowPanel's outline drawing and schematic; the Inkbird's own voltage drop (Fotek's 1.6 V max used as a proxy); all thermal figures, which are estimates until the dummy-load run; Bambu Studio's auto-support decision.

## Sources

- [CYD-ReFlow-Oven repo](https://github.com/Pnwcomputers/CYD-ReFlow-Oven) at `663b7d9`
- [CYD PINS.md](https://github.com/witnessmenow/ESP32-Cheap-Yellow-Display/blob/main/PINS.md) and the ESP32-2432S028 V0.1 schematic in that repository's `OriginalDocumentation/5-Schematic`
- [ESP32 datasheet](https://documentation.espressif.com/esp32_datasheet_en.pdf) and [ESP32 chip pin list](https://www.waveshare.com/w/upload/8/86/Esp32_chip_pin_list_en.pdf) (IO_MUX reset states)
- [ESP-IDF UART driver](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-reference/peripherals/uart.html) (GPIO matrix routing, 3 UARTs)
- [MAX6675 datasheet](https://www.digikey.at/en/htmldatasheets/production/2998/0/0/1/max6675)
- [AO3400A datasheet](https://www.aosmd.com/res/datasheets/AO3400A.pdf)
- [Shelly 1PM Gen4 KB](https://kb.shelly.cloud/knowledge-base/shelly-1pm-gen4), [Shelly Switch API](https://shelly-api-docs.shelly.cloud/gen2/ComponentsAndServices/Switch), [Shelly US relays](https://us.shelly.com/collections/smart-relays)
- [Fotek SSR-40DA spec](https://baoanjsc.com.vn/products/solid-state-relays-fotek-SSR-40DA_489160_en.aspx)
- [C13 cord set ratings](https://internationalconfigurations.com/docs/Catalog_CS09/CS09_33.pdf), [SJT 14/3](https://www.awcwire.com/product/sjt-14_3), [SJT 16/3](https://www.awcwire.com/product/sjt-16_3), [cable gland size chart](https://viox.com/my/cable-gland-size-chart/)
- [PETG vs ASA](https://www.makeitfrom.com/compare/Glycol-Modified-Polyethylene-Terephthalate-PETG-PET-G/Acrylonitrile-Styrene-Acrylate-ASA)
- [Black+Decker TO1313SBD](https://homedepot.ca/product/blackdecker-silver-and-black-toaster-oven/1001352752)
- [CYD display, touch and microSD together](https://randomnerdtutorials.com/esp32-cyd-display-touchscreen-microsd-card/), [Arduino forum thread](https://forum.arduino.cc/t/question-about-spi-bus-assignment-for-tft-espi-touch-screen-and-sd-card-for-cyd/1352613/2)
- [Elecrow CrowPanel 2.8 wiki](https://www.elecrow.com/wiki/esp32-display-282727-intelligent-touch-screen-wi-fi26ble-240320-hmi-display.html), [RobotShop listing](https://www.robotshop.com/products/elecrow-crowpanel-28-esp32-hmi-320x240-display-spi-tft-lcd-touchscreen-wo-case)
- [Reflow Master Pro](https://lectronz.com/products/210)
