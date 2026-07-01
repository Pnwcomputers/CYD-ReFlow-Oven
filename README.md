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

## ✨ Features & Current State

* **CYD Display/Touch/LED:** Validated
* **MAX6675 Thermocouple Reading:** Validated with live graph on CYD
* **SSR DC-Side Testing:** In progress / next validation step
* **Slow-PWM SSR Control:** Scaffolded using a 2-second control window
* **Enclosure:** Parametric OpenSCAD flat bench enclosure
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
| **SSR Cooling**            | SSR Heatsink                               | Mounted inside enclosure with top ventilation slots |
| **AC Input**               | 3Dman IEC C14 Inlet + Rocker Switch + Fuse | Main AC input to the controller box                 |
| **Smart Shutoff**          | KP200 Smart Outlet Module                  | Smart/remote shutoff layer upstream of SSR          |
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

The MAX6675 is wired using bit-banged SPI instead of the CYD’s shared hardware SPI bus.

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

Neutral should be wired according to the KP200’s actual terminal labeling and requirements.

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

The current compact layout is designed to fit comfortably on a Bambu X1C when printed as separate parts.

### Current Compact Layout

Approximate enclosure size:

```text
220mm W × 155mm D × 65mm H
```

This replaces the older `190 × 90 × 65mm` concept, which was too tight once the KP200, CYD, 3Dman inlet, SSR/heatsink, wiring clearance, and side openings were all included.

### Enclosure Layout

| Area                    | Component                        |
| :---------------------- | :------------------------------- |
| **Top / AC Side**       | KP200 smart shutoff access       |
| **Top / DC Side**       | CYD touchscreen cutout           |
| **Rear Wall / AC Side** | 3Dman IEC C14 fused rocker input |
| **Inside AC Bay**       | SSR-40DA and heatsink            |
| **Side Wall**           | Oven output cable/receptacle     |
| **Side Wall / DC Side** | Thermocouple and USB-C access    |
| **Internal Divider**    | Separates AC and DC wiring       |

### Material

Recommended:

* **ASA preferred**
* **PETG minimum**

Avoid:

* **PLA**, because it may soften or warp from heat near the oven or from prolonged warm bench conditions.

### Suggested Print Settings

* 3 perimeters minimum
* 30–40% gyroid infill
* ASA or PETG
* Heat-set inserts or machine screws preferred where serviceability matters
* Print test coupons before printing the full enclosure

### Test Coupons

The OpenSCAD model includes test coupons for checking real-world fit before printing the full case.

Recommended test prints:

```scad
part = "iec_test_coupon";
```

```scad
part = "kp200_test_coupon";
```

Use these to verify:

* 3Dman IEC/rocker cutout size
* 3Dman screw hole spacing
* KP200 opening size
* KP200 screw/mounting fit
* Clearance for real wires and terminals

---

## 🧱 OpenSCAD Compilation

The enclosure is parametric and can be rendered/exported from OpenSCAD.

Example CLI export:

```bash
xvfb-run -a openscad -D 'part="bottom"' -o reflow-enclosure-bottom.stl reflow-enclosure.scad
```

Other useful exports:

```bash
xvfb-run -a openscad -D 'part="lid"' -o reflow-enclosure-lid.stl reflow-enclosure.scad
```

```bash
xvfb-run -a openscad -D 'part="bezel"' -o reflow-enclosure-bezel.stl reflow-enclosure.scad
```

For PNG previews, append OpenSCAD preview options such as:

```bash
--imgsize=1600,1200 --camera=ex,ey,ez,lx,ly,lz,dist
```

---

## 🚧 Known Issues & To-Do

* [ ] Complete SSR DC-side testing
* [ ] Confirm SSR turns on/off reliably from CYD GPIO 1
* [ ] Remove all `Serial.print()` calls from firmware before connecting SSR control to GPIO 1
* [ ] Verify KP200 current rating against the Black & Decker TO1755SB nameplate
* [ ] Verify 3Dman fuse value and rocker switch rating against the oven load
* [ ] Confirm exact 3Dman IEC/rocker module cutout dimensions
* [ ] Confirm KP200 physical cutout and mounting clearances
* [ ] Confirm CYD mounting hole pattern
* [ ] Confirm CYD USB-C port location for the exact board variant
* [ ] Verify SSR heatsink dimensions and lid vent alignment
* [ ] Decide final CYD power method: external USB-C wall adapter vs. internal isolated AC-to-5V module
* [ ] Finalize oven output method: female receptacle, output cord, or other safe connector
* [ ] Finalize thermocouple probe routing into the oven chamber
* [ ] Complete AC wiring only after all test fits and DC-side tests are complete
* [ ] Develop full reflow profile firmware logic
* [ ] Add final wiring diagram image to repository
* [ ] Add final enclosure STL exports to repository

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
