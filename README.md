# 🌡️ DIY CYD Reflow Oven Controller

> **⚠️ SAFETY WARNING:** This project involves mains AC voltage, appliance modification, and high heat. Incorrect wiring can cause electric shock, fire, equipment damage, or severe injury. Do not attempt this unless you are experienced and comfortable working with mains AC wiring. Always verify wiring with a meter, confirm current ratings, use proper strain relief, bond ground correctly, and never leave the oven unattended while operating.

## 📖 Overview

This is a custom-built, cost-conscious reflow toaster oven controller for soldering Surface Mount Technology (SMT) printed circuit boards.

The project is intentionally designed as a lower-cost alternative to the Adafruit EZ Make Oven reference design, using a Cheap Yellow Display (CYD) ESP32 touchscreen as the main controller and UI.

The controller sits in a standalone 3D-printed bench enclosure next to the toaster oven. It controls oven heating through a Solid State Relay (SSR), reads chamber temperature from a K-type thermocouple through a MAX6675 module, and displays live profile/temperature data on the CYD touchscreen.

The current enclosure design uses:

* A **3Dman fused IEC C14 inlet with rocker switch** as the controller box AC power input
* A **KP200 smart outlet module** as the smart/remote shutoff layer
* An **Inkbird SSR-40DA** to switch the oven hot/load line
* A **CYD ESP32 touchscreen** mounted on the top lid
* A **MAX6675 thermocouple module** for temperature sensing
* A compact flat enclosure sized to print on a **Bambu X1C**

---

## 📁 Repository Structure

```text
CYD-ReFlow-Oven/
├── 3MF/                                            # Slicer-ready, pre-arranged plates
│   ├── reflow-enclosure-v9_4.3mf                   # Bottom shell + lid + bezel
│   └── reflow-coupons-v9_4.3mf                     # IEC + KP200 test coupons
├── OpenSCAD/                                       # Parametric source
│   ├── reflow-enclosure-flat-v9_4-compact-x1c.scad # ✅ CURRENT source of record
│   └── reflow-enclosure-flat-v9-compact-x1c.scad   # Historical v9 (superseded)
├── STL/                                            # Individual validated meshes
│   ├── reflow-v9_4-bottom.stl
│   ├── reflow-v9_4-lid.stl
│   ├── reflow-v9_4-bezel.stl
│   ├── reflow-v9_4-coupon-iec.stl
│   └── reflow-v9_4-coupon-kp200.stl
├── diy_reflow_controller_wiring_diagram.png
├── reflow-wiring-diagram.svg
└── README.md
```

> **Print only from `v9_4` files.** Earlier v9 exports had two lid bosses that collide with the IEC inlet body and SSR heatsink, and a display window 2mm too narrow for the measured glass position. If any `reflow-v9-*.stl` files remain in the repo, they are superseded and should not be printed.

---

## ✨ Features & Current State

* **CYD Display/Touch/LED:** Validated
* **MAX6675 Thermocouple Reading:** Validated with live graph on CYD
* **SSR DC-Side Testing:** In progress / next validation step
* **Slow-PWM SSR Control:** Scaffolded using a 2-second control window
* **Enclosure:** Parametric OpenSCAD flat bench enclosure — **v9.4**, fully verified; bottom shell printed and confirmed sound; lid and bezel queued
* **Smart Shutoff:** KP200 module integrated into the AC path as a smart shutoff layer
* **Physical Power Control:** 3Dman fused IEC C14 inlet with integrated rocker switch
* **AC/DC Separation:** Internal divider separates mains wiring from low-voltage control wiring
* **Cost-Conscious Design:** Uses common off-the-shelf parts and an inexpensive CYD ESP32 board

---

## 🛠️ Parts List / Bill of Materials

| Component                  | Part / Model                               | Notes                                               |
| :------------------------- | :----------------------------------------- | :-------------------------------------------------- |
| **Microcontroller/UI**     | AITRIP CYD ESP32-2432S028R                 | 2.8" resistive touchscreen                          |
| **Toaster Oven**           | Black & Decker TO1755SB                    | Base toaster oven being converted                   |
| **Thermocouple Amplifier** | MAX6675 Module                             | For K-type thermocouple temperature sensing         |
| **Thermocouple**           | K-Type Thermocouple Probe                  | Probe mounted inside oven chamber near tray height  |
| **Solid State Relay**      | Inkbird SSR-40DA                           | Switches AC hot/load to the oven                    |
| **SSR Cooling**            | SSR Heatsink                               | Measured 80 × 49.4 × 51mm; mounted inside enclosure with top ventilation slots |
| **AC Input**               | 3Dman IEC C14 Inlet + Rocker Switch + Fuse | Main AC input to the controller box                 |
| **Smart Shutoff**          | KP200 Smart Outlet Module                  | Smart/remote shutoff layer upstream of SSR; recessed body measured 70.5 × 45 × 45mm |
| **Enclosure**              | 3D Printed OpenSCAD Case                   | Compact flat bench enclosure                        |
| **Printer**                | Bambu X1C                                  | Used to print the controller enclosure              |
| **Material**               | ASA preferred / PETG minimum               | Do not use PLA                                      |

---

## ⚡ System Power Flow

The intended AC power path is:

```text
Wall Power
   ↓
3Dman Fused IEC C14 Inlet + Rocker Switch
   ↓
KP200 Smart Shutoff Module
   ↓
SSR Hot-Side Switching
   ↓
Controller Box Oven Output
   ↓
Black & Decker TO1755SB Toaster Oven
```

The 3Dman IEC/rocker module is the **device input**.

The KP200 is the **smart shutoff layer**.

The SSR is the **temperature-control switching device**.

The toaster oven receives power from the controller box output.

> **Important:** A C14 inlet is an input connector, not an output connector. Do not use a male IEC inlet as an energized output port. The oven output should use a properly rated female receptacle, a properly strain-relieved output cord, or another safe output method.

---

## 🧩 Wiring Diagram

![DIY Reflow Controller Wiring Diagram](./diy_reflow_controller_wiring_diagram.png)

---

## 🔵 Low Voltage / DC Control Wiring

The low-voltage side connects the CYD ESP32 to the MAX6675 thermocouple module and the DC input side of the SSR.

This wiring must remain physically separated from the mains AC wiring.

### MAX6675 Thermocouple Module

The MAX6675 is wired using bit-banged SPI instead of the CYD's shared hardware SPI bus.

| MAX6675 Pin | CYD / ESP32 Connection |
| :---------- | :--------------------- |
| **VCC**     | **3.3V**               |
| **GND**     | **GND**                |
| **SCK**     | **GPIO 22**            |
| **CS**      | **GPIO 27**            |
| **SO**      | **GPIO 35**            |

GPIO 35 is input-only on the ESP32, which is correct for the MAX6675 SO/data output line.

> **Do not use GPIO 21 for MAX6675 SCK.** GPIO 21 controls the CYD backlight on this board and caused intermittent thermocouple read failures / `OPEN_THERMOCOUPLE` behavior during testing.

### SSR DC Control Wiring

| CYD / ESP32 Connection | SSR Connection        |
| :--------------------- | :-------------------- |
| **GPIO 1 / TX**        | **SSR DC+ / Input +** |
| **GND**                | **SSR DC- / Input -** |

> **Critical GPIO 1 warning:** GPIO 1 is also the ESP32 hardware serial TX pin. Any `Serial.print()` or serial debug output can toggle the SSR unexpectedly if GPIO 1 is connected to the relay input.

Before using GPIO 1 for SSR control:

* Remove all `Serial.print()` / serial debug output from production firmware
* Disconnect the SSR control wire before uploading firmware
* Reconnect the SSR control wire after flashing
* Press the CYD reset button for a clean boot

---

## 🔴 High Voltage / AC Power Wiring

> **⚠️ Mains AC Warning:** This section is a conceptual wiring guide only. Verify the actual terminals, wire colors, fuse rating, load rating, earth bonding, and toaster oven wiring before applying power.

The AC side contains:

* 3Dman fused IEC C14 inlet with rocker switch
* KP200 smart shutoff module
* Inkbird SSR-40DA load terminals
* Oven output wiring
* Ground bond / earth continuity path

### AC Input: 3Dman IEC C14 + Fuse + Rocker

The 3Dman module is the main AC input for the controller box.

Conceptual wiring:

| AC Input Function  | Destination                                          |
| :----------------- | :--------------------------------------------------- |
| **Hot / Line**     | Through fuse/rocker switch, then to KP200 line input |
| **Neutral**        | To KP200 neutral and oven neutral pass-through       |
| **Ground / Earth** | To chassis/ground bond and oven ground pass-through  |

The rocker switch provides local physical power control.

The fuse provides local protection, but it must be correctly sized for the actual load and wiring.

### KP200 Smart Shutoff Module

The KP200 acts as the smart shutoff layer upstream of the SSR.

Conceptual flow:

```text
3Dman Switched Hot Output
   ↓
KP200 Line Input
   ↓
KP200 Controlled/Load Output
   ↓
SSR AC Load Terminal
```

Neutral should be wired according to the KP200's actual terminal labeling and requirements.

The KP200 must be rated for the actual toaster oven load. Confirm the oven nameplate wattage/current and the KP200 rating before using it in the load path.

### SSR Load Wiring

The SSR switches the oven **hot/load** conductor only.

Conceptual flow:

```text
KP200 Load Hot Output
   ↓
SSR AC Terminal 1
   ↓
SSR AC Terminal 2
   ↓
Oven Output Hot
```

Neutral and ground should pass through to the oven output unchanged.

```text
AC Neutral → Oven Output Neutral
AC Ground  → Ground Bond → Oven Output Ground
```

> **The SSR must switch hot, not neutral.** Switching neutral can leave the oven heating circuit energized even when the controller appears to be off.

---

## 🔌 Toaster Oven Connection

The Black & Decker TO1755SB connects to the controller box output.

Recommended output approaches:

* Properly rated panel-mount female receptacle
* Properly strain-relieved output cord ending in a female receptacle
* Another safe, enclosed, properly rated output method

Do not use a male C14 inlet as an energized output.

The oven connection should preserve:

| Conductor          | Behavior                |
| :----------------- | :---------------------- |
| **Hot / Line**     | SSR-controlled          |
| **Neutral**        | Pass-through            |
| **Ground / Earth** | Pass-through and bonded |

The thermocouple probe should be routed into the oven chamber and positioned near tray height where the PCB will sit.

---

## 💻 Firmware Notes

### Libraries

Required libraries:

* `TFT_eSPI`
* `XPT2046_Touchscreen`

The MAX6675 code uses custom bit-banged SPI, so no external MAX6675 library is required.

### Known Working Pin Assignment

| Function                 | GPIO    |
| :----------------------- | :------ |
| **MAX6675 SCK**          | GPIO 22 |
| **MAX6675 CS**           | GPIO 27 |
| **MAX6675 SO**           | GPIO 35 |
| **SSR Control**          | GPIO 1  |
| **SSR Ground Reference** | GND     |

### Upload Procedure

Because GPIO 1 is used for SSR control, use this upload process:

1. Disconnect the SSR control wire from GPIO 1.
2. Compile and upload firmware.
3. Reconnect the SSR control wire.
4. Press the CYD `RST` button.
5. Confirm clean boot before enabling AC power.

---

## 🖨️ Enclosure & 3D Printing

The enclosure is a standalone flat bench unit designed to sit next to the toaster oven.

The compact layout fits comfortably on a Bambu X1C (256 × 256mm bed) when printed as separate parts.

### Current Version: v9.4

```text
220mm W × 155mm D × 65mm H  ·  AC/DC divider at X = 147mm  ·  lay-flat, no bottom openings
```

Every mesh in `3MF/` and `STL/` is validated: watertight, winding-consistent, zero open edges, and regression-tested in **installed orientation** (the lid mesh is physically flipped 180° and probed against the shell — all 8 screw holes, both windows, standoffs, vents, and volumetric non-interference).

#### Version history

| Version | Change |
| :------ | :----- |
| v9      | Initial compact flat X1C layout (both AC modules, CYD rotated 90°) |
| v9.1    | Relocated two AC-side lid bosses that collided with the 3Dman inlet body and the SSR heatsink corner |
| v9.2    | KP200 lid window widened 70 → 73mm (measured body is 70.5mm); CYD insert bosses thickened 7 → 8.5mm OD |
| v9.3    | **Critical:** lid is now emitted mirrored for printing. The old assembly preview used a physically impossible Z-mirror, so the printed lid installed mirror-imaged — the symmetric DC screw pattern masked it while all four asymmetric AC-side holes missed their bosses |
| v9.4    | CYD display window widened 46 → 48mm — the glass sits 0.5–1mm off-center between the mounting holes; symmetric widening keeps the lid rotation-agnostic |

#### ⚠️ The lid looks mirror-imaged on the print plate — this is correct

As of v9.3 the lid STL is intentionally exported mirrored. When you physically flip the printed part over to install it (flip toward you, about the X axis), all features land in true plan coordinates. Do not "fix" the mirroring in the slicer.

#### Verified physical dimensions (measured against real parts)

| Item | Measured | Enclosure margin |
| :--- | :------- | :--------------- |
| SSR + heatsink stack height | 51mm | 8mm clearance to lid inner face (limit 56mm) |
| Heatsink footprint | 80 × 49.4mm | Clears KP200 body by ~6.1mm, front boss by ~3.8mm |
| KP200 recessed body | 70.5 × 45 × 45mm | Clears 73mm lid window by 1.25mm per side |
| Display glass position | 0.5–1mm off-center between mounting holes | Absorbed by 48mm window (≥1.4mm per side either rotation) |

### Print Order

1. **Test coupons** (`3MF/reflow-coupons-v9_4.3mf`) — verify the IEC cutout/screw spacing and KP200 window against your physical parts before committing to multi-hour prints
2. **Bottom shell**
3. **Lid + bezel** (can share a plate)

### Material

Recommended:

* **ASA preferred**
* **PETG minimum**

Avoid:

* **PLA**, because it may soften or warp from heat near the oven or from prolonged warm bench conditions.

### Suggested Print Settings

* 3 perimeters minimum
* 30–40% gyroid infill
* No supports required for any part as oriented
* Heat-set inserts (M3) or machine screws preferred where serviceability matters

---

## 🧱 OpenSCAD Compilation

The enclosure is parametric; `OpenSCAD/reflow-enclosure-flat-v9_4-compact-x1c.scad` is the source of record. The `part` variable selects what to render:

```text
part = "bottom" | "lid" | "bezel" | "assembly" | "all_flat" | "iec_test_coupon" | "kp200_test_coupon"
```

Example CLI exports:

```bash
xvfb-run -a openscad -D 'part="bottom"' -o reflow-v9_4-bottom.stl OpenSCAD/reflow-enclosure-flat-v9_4-compact-x1c.scad
xvfb-run -a openscad -D 'part="lid"'    -o reflow-v9_4-lid.stl    OpenSCAD/reflow-enclosure-flat-v9_4-compact-x1c.scad
xvfb-run -a openscad -D 'part="bezel"'  -o reflow-v9_4-bezel.stl  OpenSCAD/reflow-enclosure-flat-v9_4-compact-x1c.scad
```

For PNG previews, append OpenSCAD preview options such as:

```bash
--imgsize=1600,1200 --camera=ex,ey,ez,lx,ly,lz,dist
```

> **Note on raw OpenSCAD STLs:** OpenSCAD output can contain coincident-but-unwelded vertices. The STLs in this repo have been vertex-welded (0.02mm tolerance) and validated with trimesh. If you export your own, expect to weld/repair before relying on watertightness checks.

---

## 🚧 Known Issues & To-Do

### Enclosure — resolved ✅

* [x] Confirm exact 3Dman IEC/rocker module cutout dimensions (coupon-verified)
* [x] Confirm KP200 physical cutout and mounting clearances (body measured 70.5 × 45 × 45mm; window widened to 73mm)
* [x] Verify SSR heatsink dimensions and lid vent alignment (measured 80 × 49.4 × 51mm; 8mm lid clearance)
* [x] Verify display glass position vs. window (measured 0.5–1mm offset; window widened to 48mm)
* [x] Add final wiring diagram image to repository
* [x] Add final enclosure STL/3MF exports to repository
* [x] Print and verify bottom shell

### Open items

* [ ] Print lid and bezel from v9.4; validate fit against printed bottom shell
* [ ] Confirm CYD mounting hole pattern against v9.4 lid (82 × 44mm assumed from datasheet; first physical check is the lid print)
* [ ] Confirm CYD USB-C port location for the exact board variant (side slot is optional; goes unused if the connector is on the short edge)
* [ ] Decide SSR/heatsink retention method: RTV silicone, drill-through, or printed corral bracket
* [ ] Complete SSR DC-side testing; confirm SSR turns on/off reliably from CYD GPIO 1
* [ ] Remove all `Serial.print()` calls from firmware before connecting SSR control to GPIO 1
* [ ] Verify KP200 current rating against the Black & Decker TO1755SB nameplate
* [ ] Verify 3Dman fuse value and rocker switch rating against the oven load
* [ ] Decide final CYD power method: external USB-C wall adapter vs. internal isolated AC-to-5V module
* [ ] Finalize oven output method: female receptacle, output cord, or other safe connector
* [ ] Finalize thermocouple probe routing into the oven chamber
* [ ] Complete AC wiring only after all test fits and DC-side tests are complete
* [ ] Develop full reflow profile firmware logic

---

## 🧪 Current Development Notes

Important findings so far:

* GPIO 21 should not be used for MAX6675 SCK because it conflicts with CYD backlight control.
* MAX6675 works with:

  * SCK → GPIO 22
  * CS → GPIO 27
  * SO → GPIO 35
* SSR control is currently assigned to GPIO 1.
* GPIO 1 requires special care because it is also Serial TX.
* Disconnect SSR control before firmware upload.
* Reconnect SSR control after upload and reset the CYD.
* SSR heatsink fins do not need to protrude through the lid.
* Vent slots above the SSR/heatsink are the preferred enclosure cooling approach.
* The compact enclosure must include both the KP200 smart shutoff and the 3Dman IEC/rocker input.
* Printed-part alignment must be verified in **installed orientation**, not plan coordinates — a symmetric screw pattern can mask a mirror-imaged part (see v9.3).
* The bezel screws and CYD mounting are coaxial: one M3×16 per corner from the top (bezel → lid → boss insert) with a nylock behind the PCB clamps the whole stack.

---

## ⚠️ Final Safety Checklist Before Mains Power

Before connecting the oven to mains power:

* [ ] Verify all AC wiring with a meter
* [ ] Confirm hot, neutral, and ground are correctly identified
* [ ] Confirm the SSR switches hot only
* [ ] Confirm neutral is not being switched in place of hot
* [ ] Confirm ground continuity from AC input to oven chassis/ground
* [ ] Confirm enclosure strain relief on all mains wiring
* [ ] Confirm no exposed AC terminals can be touched
* [ ] Confirm AC and DC wiring are physically separated
* [ ] Confirm fuse value is appropriate
* [ ] Confirm KP200 rating is appropriate for the oven load
* [ ] Confirm SSR rating and heatsink are appropriate
* [ ] Confirm SSR control works from low voltage before applying AC load
* [ ] Test with a meter before connecting the toaster oven
* [ ] Never leave the oven unattended during operation
