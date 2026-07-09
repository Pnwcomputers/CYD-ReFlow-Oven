# 🌡️ DIY CYD Reflow Oven Controller

> **⚠️ SAFETY WARNING:** This project involves mains AC voltage, appliance modification, and high heat. Incorrect wiring can cause electric shock, fire, equipment damage, or severe injury. Do not attempt this unless you are experienced and comfortable working with mains AC wiring. Always verify wiring with a meter, confirm current ratings, use proper strain relief, bond ground correctly, and never leave the oven unattended while operating.

## 📖 Overview

This is a custom-built, cost-conscious reflow toaster oven controller designed for soldering Surface Mount Technology (SMT) printed circuit boards. It serves as a lower-cost alternative to reference designs like the Adafruit EZ Make Oven, leveraging the popular **Cheap Yellow Display (CYD)** ESP32 touchscreen module.

The controller is housed in a standalone, 3D-printed bench enclosure sitting safely adjacent to the toaster oven.

### How It Works
* **Control:** Switches oven heating elements via a Solid State Relay (SSR) using slow-PWM control (2-second window).
* **Sensing:** Reads internal chamber temperatures using a K-type thermocouple paired with a MAX6675 digitizer module.
* **UI/UX:** Displays live reflow profiles, temperature graphs, and touch targets directly on the CYD screen.

---

## ✨ Features & Project Status

* **Core UI:** CYD Display, capacitive touch, and status LED are fully validated.
* **Sensing:** MAX6675 reading verified with a live rendering graph on the screen.
* **Control:** Slow-PWM SSR control logic scaffolded. DC-side switching validation is up next.
* **Enclosure:** OpenSCAD parametric design optimized to print flat on a Bambu X1C without supports. 
* **Safety Isolation:** Internal structural barrier physically separates high-voltage AC mains from low-voltage DC control logic.
* **Redundant Fail-safes:** Dual-layer protection utilizing a physical fused rocker switch alongside an upstream smart-home remote shutoff layer (KP200).

---

## 🛠️ Bill of Materials (BOM)

| Component | Part / Model | Notes |
| :--- | :--- | :--- |
| **Microcontroller / UI** | AITRIP CYD ESP32-2432S028R | 2.8" resistive touchscreen unit |
| **Toaster Oven** | Black & Decker TO1755SB | Base appliance being modified |
| **Thermocouple Amp** | MAX6675 Module | Cold-junction compensated K-type digitizer |
| **Thermocouple** | K-Type Thermocouple Probe | Mounted inside oven chamber at PCB tray height |
| **Solid State Relay** | Inkbird SSR-40DA | Switches AC hot/load line to the oven |
| **SSR Cooling** | Dedicated Aluminum Heatsink | 80 × 49.4 × 51mm; clears enclosure lid by 8mm |
| **AC Power Inlet** | 3Dman Fused IEC C14 + Rocker | Main power input module with physical toggle |
| **Smart Shutoff** | KP200 Smart Outlet Module | Upstream remote emergency isolation layer |
| **Enclosure Material** | ASA *(Preferred)* / PETG *(Min)* | **Do not use PLA** (susceptible to oven-ambient warp) |

---

## 📁 Repository Structure

```text
CYD-ReFlow-Oven/
├── 3MF/                                        # Slicer-ready, pre-arranged plates
│   └── reflow-enclosure-v9_9-compact-x1.3mf    # Combined slicer assembly setup
├── OpenSCAD/                                   # Parametric physical source CAD
│   └── reflow-enclosure-v9_9-compact-x1.scad   # ✅ CURRENT master source of record
├── STL/                                        # Individual production-ready meshes
│   ├── reflow-v9_6-bottom.stl                  # Validated structural shell
│   ├── reflow-v9_6-iec-trim-plate.stl          # Dedicated trim alignment plate
│   ├── reflow-v9_9-bezel.stl                   # Top screen bezel mesh
│   └── reflow-v9_9-lid.stl                     # Pre-mirrored mating lid mesh
├── LICENSE                                     # BSD-2-Clause license file
├── README.md                                   # This file
├── diy_reflow_controller_wiring_diagram.png    # Rendered wiring schematic
└── reflow-wiring-diagram.svg                   # Vector wiring asset
```

> ⚠️ **Print Advisory:** Ensure you deploy the correct mixture of versions currently in the repository branch. Print the **v9.6** variant for your bottom shell/trim plate and the **v9.9** files for the lid and bezel integration.

---

## ⚡ System Architecture & Wiring

### Power Flow Topology
```text
[Mains Wall Power] 
       ↓
[3Dman Fused IEC C14 Input + Rocker] 
       ↓
[KP200 Smart Shutoff Module] 
       ↓
[SSR Hot-Side Switching] 
       ↓
[Controller Receptacle Output] ---> [Black & Decker Toaster Oven]
```

> 🛑 **Design Rule:** An IEC C14 inlet is an *input* connector. Never use a male inlet as an energized power output. The power feed out to the oven must utilize a properly rated panel-mount female receptacle or a strain-relieved female trailing lead.

### Wiring Architecture
![DIY Reflow Controller Wiring Diagram](./diy_reflow_controller_wiring_diagram.png)

### Pin Configuration Mapping

The low-voltage control side links the CYD ESP32 to the MAX6675 sensor and the input side of the SSR. Due to hardware resource sharing on the CYD board, specific pins must be used:

| Function | ESP32 GPIO | Connection Target | Design Context / Gotchas |
| :--- | :--- | :--- | :--- |
| **MAX6675 SCK** | **GPIO 22** | Module Clock | Bit-banged SPI. *Do not use GPIO 21* (conflicts with CYD backlight). |
| **MAX6675 CS** | **GPIO 27** | Module Chip Select| Bit-banged SPI |
| **MAX6675 SO** | **GPIO 35** | Module Data Out | Input-only on ESP32 (perfect match for SO) |
| **SSR Control** | **GPIO 1** | SSR Input DC+ | Shared with Hardware Serial TX pin. See warning below. |
| **DC Ground** | **GND** | SSR Input DC- | Common low-voltage ground reference |

---

## 💻 Firmware & Flashing Rules

### Required Core Libraries
* `TFT_eSPI` (Configured for the respective CYD display controller)
* `XPT2046_Touchscreen`

### 🚨 Critical GPIO 1 / SSR Warning
Because **GPIO 1** is shared with the hardware serial transmit line (`TX`), any active `Serial.print()` statements or bootloader debugging data will rapidly toggle the SSR during boot or runtime.

#### Strict Upload Procedure:
1. **Isolate:** Disconnect the SSR DC+ control wire from GPIO 1 entirely.
2. **Flash:** Confirm all active `Serial.print()` calls are stripped out of production builds, then flash firmware over USB.
3. **Reconnect & Boot:** Reattach the SSR control line, then press the physical `RST` button on the CYD to initiate a clean, deterministic system boot before introducing AC power.

---

## 🖨️ Enclosure & 3D Printing Production

The parametric enclosure splits the interior into isolated functional chambers with an internal physical divider wall. 

### Enclosure Revision Milestones

* **v9.6 Platform:** Stabilized the bottom shell architecture and added the dedicated `reflow-v9_6-iec-trim-plate.stl` alignment spacer.
* **v9.9 Platform (Current):** Refined top tolerances. The physical lid file (`reflow-v9_9-lid.stl`) is intentionally pre-mirrored for printing so that features properly map to the bottom shell when flipped upside down into its installed state. Do not mirror it again in the slicer.

### Slicer Configurations
* **Orientation:** All STL assets are pre-oriented for direct printing. No supports are required.
* **Infill & Perimeters:** Run a minimum of 3 perimeters paired with 30–40% Gyroid infill to handle internal heat-sink structural load.
* **Hardware:** M3 heat-set brass inserts are required for the internal mounting pillars.

---

## 🚧 Roadmap & Known Issues

### Completed Milestones ✅
* [x] Enclosure dimensions coupon-validated against physical AC components.
* [x] Confirmed SSR heatsink lid-clearance margins (8mm vertical buffer).
* [x] Split production prints to v9.6 bottom configurations and v9.9 top closures.
* [x] Successfully printed and verified structural bottom shell.

### Open Action Items 🛠️
* [ ] Print production v9.9 lid and bezel; check fitment against bottom shell.
* [ ] Verify physical CYD screw pattern matching (82 × 44mm) against the printed lid.
* [ ] Choose SSR-to-heatsink retention method (RTV high-temp silicone vs. a printed corral bracket).
* [ ] Run low-voltage logic validations to ensure clean SSR switching over GPIO 1.
* [ ] Audit codebase to completely strip out active `Serial` debugging logs.
* [ ] Cross-reference Black & Decker TO1755SB peak current requirements with KP200 internal relay specs.
* [ ] Finalize oven chassis entry point for the K-type thermocouple probe.
* [ ] Design and implement target reflow curve PID logic loops in firmware.

---

## 🛑 Final Safety Checklist Before Mains Power Authorization

Do not connect the device to wall power until every item below is explicitly checked:

- [ ] **Wiring Verification:** Trace out all connections using a digital multimeter on continuity mode.
- [ ] **Mains Orientation:** Explicitly confirm that the SSR switches the **Hot / Line** conductor, *never* the Neutral conductor.
- [ ] **Ground Path Bonding:** Confirm solid metal-to-metal earth ground continuity from the primary AC wall inlet pin straight to both the controller chassis elements and the external metal oven frame.
- [ ] **Isolation Separation:** Visually verify that no low-voltage control lines path through or touch the AC high-voltage chamber.
- [ ] **Touch Protection:** Ensure there are zero exposed live AC terminals or raw wire conductor strands capable of being touched inside the box.
- [ ] **Thermal Clearance:** Ensure the SSR heatsink cooling vents are unblocked and clear.
- [ ] **Logic Verification:** Test the complete firmware logic path with the AC lines fully disconnected to ensure the CYD triggers the relay pin appropriately under mock profiles.
- [ ] **Constant Supervision:** Never leave the modified oven system unmonitored during live operations.

---
