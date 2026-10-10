# Build Guide — v12.0

Build one controller from the v12.0 design: what to buy, what to print, what order to do it in, and what to check at each step. Wiring is in [`diy_reflow_controller_wiring_diagram.png`](../diy_reflow_controller_wiring_diagram.png) (source: `tools/make_wiring_diagram.py`). Background and the reasons behind each choice are in the [README](../README.md) and [design review](DESIGN-REVIEW-2026-10.md).

> ⚠️ Mains wiring. Work with the inlet cord unplugged, and meter before every first power-up.

**Directions in this guide** follow the SCAD model: the *left wall* is X = 0 (AC bay: Shelly, oven socket), the *right wall* is X = 250 (DC bay: USB-C, thermocouple), the *rear wall* carries the inlet, and the *front panel* carries the display. Standing at the front panel, the left wall is on **your right**.

## 1. Parts

### Already in hand (per project notes)
FILSHU C14 inlet, FILSHU NEMA 5-15R socket, Shelly 1PM Gen4 (EU `S4SW-001P16EU`; supply range 110–240 V~), KP200, Inkbird SSR-40DA + heatsink, MAX6675 + K probe, Wago 221 lever nuts, USB adapter.

### To buy

| Qty | Part | Notes |
| ---: | --- | --- |
| 1 | Elecrow CrowPanel 2.8" ESP32 HMI | Comes with a USB-A→C cable, one Grove-to-DuPont cable, a stylus and an acrylic case (case not used) |
| 2 | Grove (HY2.0-4P) to female DuPont cable, ≥ 20 cm | Three needed in total |
| 1 | NEMA 5-15P → C13 cord, **14 AWG SJT, 15 A** | Not a PC cord (those are typically 18 AWG / 10 A) |
| 1 | 15 A, 5 × 20 mm, **ceramic, time-delay** fuse | For the inlet's holder |
| 1 m each | 14 AWG stranded hook-up wire, UL 1015 (600 V, 105 °C): black, white, green | Internal AC wiring |
| 1 | WAGO 221-413 (3-conductor) | Hot junction. 24–12 AWG, UL 486C 600 V / 20 A, strip 11 mm |
| 2 | WAGO 221-415 (5-conductor) | Neutral junction and ground junction |
| 1 | 14 AWG ring terminal sized for a heatsink screw | Heatsink ground bond. Measure the screw first |
| ~15 cm | Heat-shrink tubing rated 600 V, to fit over the 4-wire Grove cable | Sleeves the SSR control cable through the AC bay; check the rating printed on the tubing |
| small | Heat-shrink for the unused DuPont ends | 5 ends: J7 pins 1 and 4, J10 pins 2–4 |
| 19 | M3 heat-set inserts for a 4.2 mm pocket, ≤ 4 mm long | Same kind as the CYD bosses. 9 lid, 6 front panel, 4 display |
| 2 | Inserts matching the KP200's own screw thread | 4.5 mm pockets in the lid |
| 9 | M3 × 6 countersunk | Lid: 3 mm lid + 3 mm into the insert |
| 6 | M3 × 8 countersunk | Front panel: 3 mm panel + 5 mm (pocket is 6 mm deep) |
| 4 | M3 × 5 pan head | CrowPanel to standoffs: 1.6 mm PCB + 3.4 mm |
| 4 | Self-adhesive rubber feet, ≤ 12 mm diameter | Recesses are 12 mm, 0.8 mm deep |
| ~1 kg | ASA filament | Bottom shell, front panel, lid, coupons |

If you replace the Shelly, the US version is sold as "Shelly 1PM Gen4 UL-Certified".

## 2. Print

All files are in `STL/` and `3MF/`, already oriented. No supports. ASA, ≥ 3 perimeters, 30–40 % gyroid.

1. **Coupons first:** `3MF/reflow-v12_0-coupons.3mf` (oven-socket, inlet and CrowPanel coupons on one plate).
   * Oven-socket coupon: find the cell the socket snaps into firmly (rows: 24.5 / 24.75 / 25.0 mm cut, dimples on the left edge; columns: 2.0 / 2.5 / 3.0 mm panel, dimples on the top edge). If it isn't the centre cell (24.75 / 2.5), set `os_cut` / `os_panel_t` in the SCAD and re-export the bottom shell.
   * Inlet coupon: the FILSHU inlet snaps in.
   * CrowPanel coupon: see step 3.4.
2. **Main parts:** `reflow-v12_0-bottom.stl`, `reflow-v12_0-front-panel.stl` (outer face down, as exported), `reflow-v12_0-lid.stl` (pre-mirrored: don't mirror it in the slicer). These are 250 mm wide, 3 mm per side from the plate edge: **brim ≤ 3 mm**, or brim ears on the corners.

## 3. Bench checks before building in (USB power only, no mains)

1. Note the CrowPanel's PCB revision on the silkscreen (Elecrow's V1.0, V2.0 and V2.1 schematics are identical for J6, J7 and J10).
2. Meter J7 pin 3 → pin 4: **3.3 V**.
3. Flash `firmware/bench_test/bench_test.ino` (Arduino IDE, board "ESP32 Dev Module", 115200 baud). With J7 pin 2 and 3 wired to the SSR's `T4` / `T3` and the MAX6675 wired per the table below:
   * `s` → "IO32 reads 1 while released".
   * `1` → SSR LED on for 3 s. Meter `T3`–`T4` while it is on: **≥ 3.0 V** (the SSR's minimum). Optionally the input current in series: expect well under 24 mA.
   * Press RESET and power-cycle a few times: the SSR LED must stay **off**.
   * `t` → temperature stream: room temperature, rising when you hold the probe tip.
4. Fit the bare board to the CrowPanel coupon (4 inserts, 4 × M3 × 5, connectors toward the notched edge). The whole active area shows, the glass doesn't touch the plastic (designed gap 0.6 mm), and touch works at the edges.
5. Hold your USB-C cable's plug body against the right-wall slot size (15 × 9 mm): it must pass.

The sketch was compiled and simulated on a PC against stub Arduino headers (checked: the MAX6675 bit decode, the open-thermocouple flag, the SSR on/auto-off sequence, and no `digitalWrite` before `pinMode`). It has not been built with the ESP32 toolchain; the Arduino IDE build is the first real compile.

## 4. Assemble

1. **Inserts:**
   * Bottom shell: 9 lid inserts (vertical, tops of the bosses and the two front-left posts) and 6 front-panel inserts (horizontal, in the front faces of the 4 posts).
   * Front panel: 4 display inserts in the standoffs.
   * Lid: the 2 KP200 inserts.
2. **Display:**
   * If the acrylic case is fitted, take it off; it isn't used, and the board itself stays unmodified. Screw the board to the front panel, connectors toward the panel's bottom edge.
   * Plug the three Grove cables into J7, J6 and J10 now; the connectors face down and are harder to reach later.
3. **SSR on the bench:**
   * Mount the SSR on the heatsink so that, once installed, **`T1`/`T2` are at the end toward the KP200 and the left wall**, and `T3`/`T4` are at the end toward the divider.
   * Land the two AC wires on `T1` and `T2`: stranded, twisted, **not tinned**, fully under the clamp plates. Leave them long enough to reach the Shelly `O` and the socket.
   * Pre-form the upper AC wire's bend downward: the channel beside the KP200 body is 11.5 mm wide.
   * Fit the ring terminal and green wire under a heatsink screw.
4. **Bottom shell:**
   * Heatsink into its fence (fins front-to-back, SSR facing the rear wall).
   * Shelly into its pocket on the left wall.
   * Inlet into the rear wall and socket into the left wall (both snap in).
   * MAX6675 on the DC floor bosses: the boss pattern (13 × 10 mm, 3.5 mm holes) is not from a measurement of your module, so check it. If it doesn't match, use foam tape, or send me the module's hole pattern.
5. **AC wiring:** follow the diagram and the terminal map below.
6. **Low-voltage wiring:**
   * Slide the 600 V heat-shrink over the J7 cable, drop the cable into the divider's U-slot (it is beside the SSR's DC end), and land IO32 (J7 pin 2) on `T4` and 3V3 (J7 pin 3) on `T3`. Grove wires are thin: fold the stripped end double before clamping, or crimp a ferrule.
   * Insulate the unused ends.
   * Route J6/J10 along the DC floor to the MAX6675. Pass the thermocouple through the right-wall hole.
7. **Close up:**
   * Front panel on (6 × M3 × 8): its rib slides along the AC side of the divider.
   * Lid on (9 × M3 × 6). The lid also clamps the panel's top edge. The KP200 sits in the lid; its faceplate covers the lid screws near it.
   * Plug the USB cable into the KP200's adapter and in through the right-wall slot.

### AC terminal map

| From | To |
| --- | --- |
| Inlet hot (fused, switched) | WAGO 221-413 **HOT** |
| HOT Wago | Shelly `L`; KP200 **Line** |
| Inlet neutral | WAGO 221-415 **NEUTRAL** |
| NEUTRAL Wago | Shelly `N`; KP200 **Neutral**; socket **neutral** (wide slot) |
| Inlet ground | WAGO 221-415 **GROUND** |
| GROUND Wago | KP200 **Ground**; socket **ground** (round); heatsink ring terminal |
| Shelly `O` | SSR `T1` |
| SSR `T2` | Socket **hot** (narrow slot) |
| Shelly `SW` | not connected (set input to detached) |

Shelly: one wire per terminal, strip 6–7 mm, 0.4 N·m max, 0.2–2.5 mm² (14 AWG is 2.08 mm²). Its manual says not to use its `L` terminals to power other devices, which is why the KP200 is fed from the Wago, not from a second Shelly `L` terminal. **If your box is already wired with the KP200 on a Shelly `L` terminal, move it to the Wago.**

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
2. Configure the Shelly before any load is attached: power-on default **off**, input detached, overpower 1400 W, `current_limit` 11 A.
3. Oven **unplugged**, an incandescent lamp in the socket as a load:
   * Rocker on → the controller boots, and the SSR LED stays off.
   * Shelly on → lamp stays off.
   * `1` in the bench sketch → lamp on for 3 s, then off.
   * Shelly off → lamp can't light even with the SSR on.
4. Check socket polarity with a plug-in outlet tester (Shelly on, SSR on).
5. Thermal run with the oven as the load: log the Shelly's own temperature (`temperature.tC`) for 10 min at 100 % and 30 min at 50 %, lid closed. The Shelly is rated to 40 °C ambient.

Leave the oven's own thermostat in circuit (set to maximum): it stays an independent hardware temperature limit outside the controller's firmware.

## 6. Then
The reflow firmware: TFT_eSPI with Elecrow's settings (README), `setRotation(1)` or `(3)`, whichever is upright with the board connectors-down, touch recalibration, slow-PWM SSR control using the `ssrOn()`/`ssrOff()` pattern, and the Shelly watchdog (`toggle_after=30`, refreshed every 15 s).
