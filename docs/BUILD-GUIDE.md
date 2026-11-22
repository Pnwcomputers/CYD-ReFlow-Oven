# Build Guide — v12.1

Build one controller from the v12.1 design: what to buy, what to print, what order to do it in, and what to check at each step.

**Wiring sheets** (in [`docs/wiring/`](wiring/), also as one [printable PDF](wiring/reflow-wiring-all-sheets.pdf)):

1. [AC mains](wiring/reflow-wiring-ac-mains.png): every mains wire, tagged A1–A15.
2. [Low-voltage and signals](wiring/reflow-wiring-low-voltage.png): display, MAX6675, SSR drive, USB, Wi-Fi link, tagged D1–D7.
3. [Layout and clearances](wiring/reflow-layout-clearances.png): where each part sits, to scale, and how to get at it.

Background and the reasons behind each choice are in the [README](../README.md) and [design review](DESIGN-REVIEW-2026-10.md).

> ⚠️ Mains wiring. Work with the inlet cord unplugged, and meter before every first power-up.

**Directions in this guide** follow the SCAD model: the *left wall* is X = 0 (AC bay: Shelly, oven socket), the *right wall* is X = 250 (DC bay: USB-C, thermocouple), the *rear wall* carries the inlet, and the *front panel* carries the display. Standing at the front panel, the left wall is on **your right**.

## 1. Parts

Everything needed to build one from scratch. Product links for the main parts are in the [README's bill of materials](../README.md). (For the reference build all of it is on hand as of 2026-11.)

| Qty | Part | Notes |
| ---: | --- | --- |
| 1 | Elecrow CrowPanel 2.8" ESP32 HMI | On Amazon as Elecrow's "ESP32 Display 2.8 Inch (NerdMiner)" 2-pack, B0H11B33ZK. **Not** the CrowPanel *Advance*. Elecrow's retail kit comes with a USB-A→C cable, one Grove-to-DuPont cable, a stylus and an acrylic case (case not used); check what your pack includes |
| 1 | Black & Decker TO1313SBD toaster oven | 1150 W, 9.6 A |
| 1 | FILSHU C14 inlet module, 15 A, fused rocker, 14 AWG leads | Snaps into the rear wall |
| 1 | FILSHU NEMA 5-15R panel socket, 15 A, 14 AWG leads | Snaps into the left wall |
| 1 | Shelly 1PM Gen4 | EU `S4SW-001P16EU` in the reference build (supply range 110–240 V~). The US version is sold as "Shelly 1PM Gen4 UL-Certified" |
| 1 | Inkbird SSR-40DA + aluminium heatsink | Input 3–32 VDC |
| 1 | MAX6675 module + K-type thermocouple probe | |
| 1 | KP200 smart outlet + a 5 V USB adapter | Always live; powers the display |
| 3 | Grove (HY2.0-4P) to female DuPont cable, ≥ 20 cm | One each for J7, J6 and J10 (one may come with the display) |
| 1 | NEMA 5-15P → C13 cord, **14 AWG SJT, 15 A** | Not a PC cord (those are typically 18 AWG / 10 A) |
| 1 | 15 A, 5 × 20 mm, **ceramic, time-delay** fuse | For the inlet's holder |
| 1 m each | 14 AWG stranded hook-up wire, UL 1015 (600 V, 105 °C): black, white, green | Internal AC wiring |
| 3 | WAGO 221-415 (5-conductor) | Hot, neutral and ground junctions. 24–12 AWG, UL 486C 600 V / 20 A, strip 11 mm. The hot junction carries 4 wires since the meter was added, so a 3-port 221-413 is no longer enough |
| 1 | DROK AC multimeter 50–300 V / 100 A with split-core CT | Amazon B0B3WVG2V9. Snaps into the lid |
| ~0.5 m each | 18 AWG hook-up wire, 600 V: black, white | Meter voltage leads (14 AWG also works if the meter's terminals take it) |
| 1 | 14 AWG ring terminal sized for a heatsink screw | Heatsink ground bond. Measure the screw first |
| ~15 cm | Heat-shrink tubing rated 600 V, to fit over the 4-wire Grove cable | Sleeves the SSR control cable through the AC bay; check the rating printed on the tubing |
| small | Heat-shrink for the unused DuPont ends | 5 ends: J7 pins 1 and 4, J10 pins 2–4 |
| 19 | M3 heat-set inserts for a 4.2 mm pocket, ≤ 4 mm long | Same kind as the CYD bosses. 9 lid, 6 front panel, 4 display |
| 2 | Inserts matching the KP200's own screw thread | 4.5 mm pockets in the lid |
| 9 | M3 × 6 countersunk | Lid: 3 mm lid + 3 mm into the insert |
| 6 | M3 × 8 countersunk | Front panel: 3 mm panel + 5 mm (pocket is 6 mm deep) |
| 4 | M3 × 5 pan head | CrowPanel to standoffs: 1.6 mm PCB + 3.4 mm |
| 4 | Self-adhesive rubber feet, ≤ 12 mm diameter | Recesses are 12 mm, 0.8 mm deep |
| 2 | Small zip ties | CT clamp to its wire; meter leads |
| 1 | Incandescent lamp in a plug-in holder | Test load for section 5, in place of the oven |
| ~1 kg | ASA filament | Bottom shell, front panel, lid, coupons |

## 2. Print

All files are in `STL/` and `3MF/`, already oriented. No supports. ASA, ≥ 3 perimeters, 30–40 % gyroid.

1. **Coupons first:** `3MF/reflow-v12_0-coupons.3mf` (oven-socket, inlet and CrowPanel coupons on one plate).
   * Oven-socket coupon: find the cell the socket snaps into firmly (rows: 24.5 / 24.75 / 25.0 mm cut, dimples on the left edge; columns: 2.0 / 2.5 / 3.0 mm panel, dimples on the top edge). If it isn't the centre cell (24.75 / 2.5), set `os_cut` / `os_panel_t` in the SCAD and re-export the bottom shell.
   * Inlet coupon: the FILSHU inlet snaps in.
   * CrowPanel coupon: see section 3, step 4.
   * **DROK meter coupon** (`3MF/reflow-v12_1-drok-meter-coupon.3mf`, dimpled side up as exported): six cutouts. Columns are the cutout size (1, 2, 3 dimples on the bottom edge: 45.2 × 73.6, 45.6 × 74.0, 46.0 × 74.4 mm). The row with 1 dimple on its left edge is thinned to 2.0 mm around the hole; the row with 2 dimples is the full 3.0 mm lid thickness. Push the meter in from the smooth side. The lid is modelled on the middle cell of the 3.0 mm row. If another cell holds it better, set `drok_cut_w`, `drok_cut_l` and `drok_panel_t` near the top of the SCAD file to that cell's values and re-export the lid (`part = "lid"`).
2. **Main parts:** `reflow-v12_0-bottom.stl`, `reflow-v12_0-front-panel.stl` (outer face down, as exported), `reflow-v12_1-lid.stl` (pre-mirrored: don't mirror it in the slicer). The bottom shell and front panel did not change in v12.1. These are 250 mm wide, 3 mm per side from the plate edge: **brim ≤ 3 mm**, or brim ears on the corners.

## 3. Bench checks before building in (USB power only, no mains)

1. Note the CrowPanel's PCB revision on the silkscreen (Elecrow's V1.0, V2.0 and V2.1 schematics are identical for J6, J7 and J10), and check that the three 4-pin connectors are labelled as this guide expects: J7 `GPIO_D`, J6 `IIC`, J10 `UART1`. If your board is labelled differently, stop and compare it with the low-voltage map in section 4 before wiring anything.
2. Meter J7 pin 3 → pin 4: **3.3 V**.
3. Flash `firmware/bench_test/bench_test.ino` (Arduino IDE, board "ESP32 Dev Module", 115200 baud). With J7 pin 2 and 3 wired to the SSR's `T4` / `T3` and the MAX6675 wired per the table below:
   * `s` → "IO32 reads 1 while released".
   * `1` → SSR LED on for 3 s. Meter `T3`–`T4` while it is on: **≥ 3.0 V** (the SSR's minimum). Optionally the input current in series: expect well under 24 mA.
   * Press RESET and power-cycle a few times: the SSR LED must stay **off**.
   * `t` → temperature stream: room temperature, rising when you hold the probe tip.
4. Fit the bare board to the CrowPanel coupon (4 inserts, 4 × M3 × 5, connectors toward the notched edge). The whole active area shows, the glass doesn't touch the plastic (designed gap 0.6 mm), and touch works at the edges.
5. Hold your USB-C cable's plug body against the right-wall slot size (15 × 9 mm): it must pass.

The bench sketch was compiled and simulated on a PC against stub Arduino headers (checked: the MAX6675 bit decode, the open-thermocouple flag, the SSR on/auto-off sequence, and no `digitalWrite` before `pinMode`). It has not been built with the ESP32 toolchain; the Arduino IDE build is the first real compile.

## 4. Assemble

1. **Inserts:**
   * Bottom shell: 9 lid inserts (vertical, tops of the bosses and the two front-left posts) and 6 front-panel inserts (horizontal, in the front faces of the 4 posts).
   * Front panel: 4 display inserts in the standoffs.
   * Lid: the 2 KP200 inserts.
2. **Lid:**
   * On the outer face, inside the two shallow recesses beside the KP200 window, the four holes are closed by a paper-thin printed skin (it lets the recess roof print cleanly without supports). Push a small screwdriver through each one.
   * Fit the KP200 into its window and screw it to its two inserts.
   * Snap the DROK meter in from above (the outside face). Its long side runs front-to-back; turn it so the digits are upright from the side you'll stand at.
3. **Display:**
   * If the acrylic case is fitted, take it off; it isn't used, and the board itself stays unmodified. Screw the board to the front panel, connectors toward the panel's bottom edge.
   * Plug the three Grove cables into J7, J6 and J10 now; the connectors face down and are harder to reach later.
4. **SSR on the bench:**
   * Mount the SSR on the heatsink so that, once installed, **`T1`/`T2` are at the end toward the KP200 and the left wall**, and `T3`/`T4` are at the end toward the divider.
   * Land the two AC wires on `T1` and `T2`: stranded, twisted, **not tinned**, fully under the clamp plates. Leave them long enough to reach the Shelly `O` and the socket.
   * Pre-form the upper AC wire's bend downward: the channel beside the KP200 body is 11.5 mm wide.
   * Fit the ring terminal and green wire under a heatsink screw.
5. **Bottom shell:**
   * Heatsink into its fence (fins front-to-back, SSR facing the rear wall).
   * Shelly into its pocket on the left wall.
   * Inlet into the rear wall and socket into the left wall (both snap in).
   * MAX6675 on the DC floor bosses: the boss pattern (13 × 10 mm, 3.5 mm holes) is not from a measurement of your module, so check it. If it doesn't match, use foam tape, or set `max_hole_dx` / `max_hole_dy` in the SCAD to your module's hole spacing and re-export the bottom shell before printing it.
6. **AC wiring:** follow [sheet 1](wiring/reflow-wiring-ac-mains.png) and the terminal map below.
   * **CT clamp:** open it, close it around the SSR `T2` → socket-hot wire only (A15), and let it lie on the AC floor between the oven socket and the inlet, next to the Wagos (a 42 × 32 mm area, free up to 35 mm high). Zip-tie it to the wire.
   * **Meter leads:** land the two voltage leads and the CT pair on the meter's rear terminals as labelled on the meter. Leave about 150 mm of slack on these and on the KP200 wires, so the lid can be laid on its back beside the box while still wired. Route them along the rear wall, away from the heatsink and the vent slots.
7. **Low-voltage wiring** ([sheet 2](wiring/reflow-wiring-low-voltage.png)):
   * Slide the 600 V heat-shrink over the J7 cable, drop the cable into the divider's U-slot (it is beside the SSR's DC end), and land IO32 (J7 pin 2) on `T4` and 3V3 (J7 pin 3) on `T3`. Grove wires are thin: fold the stripped end double before clamping, or crimp a ferrule.
   * Insulate the unused ends.
   * Route J6/J10 along the DC floor to the MAX6675. Pass the thermocouple through the right-wall hole.
8. **Close up:**
   * Front panel on (6 × M3 × 8): its rib slides along the AC side of the divider.
   * Lid on (9 × M3 × 6). The lid also clamps the panel's top edge. The KP200 sits in the lid; its faceplate covers the lid screws near it. Check that the meter's leads fold down beside the inlet and nothing is pinched: the meter body ends 7.5 mm above the SSR and 13.8 mm above the inlet.
   * Plug the USB cable into the KP200's adapter and in through the right-wall slot.

### AC terminal map

| From | To |
| --- | --- |
| Inlet hot (fused, switched) | WAGO 221-415 **HOT** |
| HOT Wago | Shelly `L`; KP200 **Line**; DROK meter **L** (18 AWG) |
| Inlet neutral | WAGO 221-415 **NEUTRAL** |
| NEUTRAL Wago | Shelly `N`; KP200 **Neutral**; socket **neutral** (wide slot); DROK meter **N** (18 AWG) |
| Inlet ground | WAGO 221-415 **GROUND** |
| GROUND Wago | KP200 **Ground**; socket **ground** (round); heatsink ring terminal |
| Shelly `O` | SSR `T1` |
| SSR `T2` | Socket **hot** (narrow slot), **through the DROK CT clamp** |
| CT leads | DROK meter CT terminals |
| Shelly `SW` | not connected (set input to detached) |

Shelly: one wire per terminal, strip 6–7 mm, 0.4 N·m max, 0.2–2.5 mm² (14 AWG is 2.08 mm²). Its manual says not to use its `L` terminals to power other devices, which is why the KP200 is fed from the Wago, not from a second Shelly `L` terminal. **If your box is already wired with the KP200 on a Shelly `L` terminal, move it to the Wago.**

**DROK meter:** the terminal names above are generic. Use the labels printed on the back of your meter for which two screws are the 50–300 V input and which two take the CT. The CT goes around the oven hot wire alone; around hot and neutral together it reads zero. With it there, the meter shows the oven's draw (about 9.6 A / 1150 W while the SSR is on) and the line voltage whenever the rocker is on. If the watts read wrong or negative, turn the clamp around.

Identify hot / neutral / ground on the inlet with a meter (the fuse must be in the hot leg), not by lead colour.

### Low-voltage map

| CrowPanel | Pin | To |
| --- | --- | --- |
| J7 GPIO_D | 2 IO32 | SSR `T4` (−) |
| J7 GPIO_D | 3 3V3 | SSR `T3` (+) |
| J7 GPIO_D | 1, 4 | not connected — **never put J7 pin 4 (GND) on the SSR** |
| J6 IIC | 1 IO21 | MAX6675 CS |
| J6 IIC | 2 IO22 | MAX6675 SCK |
| J6 IIC | 3 3V3 | MAX6675 VCC |
| J6 IIC | 4 GND | MAX6675 GND |
| J10 UART1 | 1 IO16 | MAX6675 SO |
| J10 UART1 | 2–4 | not connected |

Pin numbers are from Elecrow's schematic. Grove cable colours vary, so check each wire against the pin with a meter before landing it.

## 5. First power

1. Cord unplugged:
   * Continuity: inlet ground pin → socket ground, KP200 ground, heatsink.
   * No continuity between hot, neutral and ground with the rocker off.
   * No loose strands anywhere.
2. Set up the Shelly before any load is attached:
   * Settings: power-on default **off**, input detached, overpower 1400 W, `current_limit` 11 A, and a DHCP reservation in your router so its IP address stays the same.
   * Script: in the Shelly's web page, Scripts → Create script, paste [`firmware/shelly/reflow_supervisor.js`](../firmware/shelly/reflow_supervisor.js), Save, Start, and enable "Run on startup".
3. Oven **unplugged**, an incandescent lamp in the socket as a load, the bench sketch still on the board:
   * Rocker on → the controller boots, the DROK meter lights and shows about 120 V, and the SSR LED stays off.
   * Shelly on (from its web page or app) → lamp stays off.
   * `1` in the bench sketch → lamp on for 3 s, then off. The DROK meter shows the lamp's current while it is lit (a 60 W lamp is 0.5 A).
   * Shelly off → lamp can't light even with the SSR on.
4. Check socket polarity with a plug-in outlet tester (Shelly on, SSR on).

Leave the oven's own thermostat in circuit (set to maximum): it stays an independent hardware temperature limit outside the controller's firmware.

## 6. Reflow firmware

The firmware is in [`firmware/reflow_controller/`](../firmware/reflow_controller/). [Its README](../firmware/reflow_controller/README.md) has the Arduino IDE setup, every abort message and the tuning notes. It has been tested on a PC against a simulated oven and Shelly ([`firmware/host_test/`](../firmware/host_test/README.md)), not on hardware, so the first compile and the first runs are bench work, in this order:

1. **Flash it.** Copy `secrets.example.h` to `secrets.h`, put in your Wi-Fi name, password and the Shelly's IP address, and upload. Calibrate touch when it asks.
2. **No mains, `SHELLY_REQUIRED false`:** press START. The SSR LED pulses and the serial monitor (115200) prints CSV lines. Pull the thermocouple plug: the run must abort with "Thermocouple not reading". (Left alone, the run aborts after a minute or two with "No temp rise: check probe", because nothing is heating the probe.) Set `SHELLY_REQUIRED true` again and re-flash.
3. **Lamp as the load, oven unplugged:** press START on the low-temp profile.
   * For about 5 s the screen says "arming" and the lamp stays off. That is the stuck-SSR check; the serial log then prints `# SSR off, Shelly reads 0.0 W` (a watt or two is fine) and `# running`.
   * The lamp pulses. The probe is not being heated, so after a minute or two the run aborts with "No temp rise: check probe". That is the correct result for this test.
   * Start again, and this time switch the Shelly off from its web page or app while the lamp is pulsing: within 15 s the run must abort with "Shelly opened its relay", and the lamp must stay off.
   * Start again and unplug the controller's USB cable while the lamp is pulsing: the lamp goes out at once (SSR released), and the Shelly opens its relay by itself within 30 s.
   * If the log ever prints `# Shelly status not understood`, note it: the relay and stuck-SSR checks are being skipped.
4. **Thermal run with the oven as the load** (empty oven, probe in the middle, bake profile, watch the whole time): log the Shelly's own temperature (`temperature.tC` in its status page) with the lid closed. The Shelly is rated to 40 °C ambient. The firmware limits a run to 15 minutes.
5. **First reflow run** on the low-temp profile, empty oven. Then tune from the CSV log.

## 7. Service

* Everything inside is reached by taking the lid off (9 screws). The meter and KP200 lift with it; with the slack from step 4.6 the lid lies on its back beside the box.
* DROK meter out: lid off, squeeze the clips on the two long sides, push it up and out.
* Display and Grove cables: front panel (6 screws).
* Fuse: in the inlet's drawer, from outside, cord unplugged.
