# 🌡️ DIY CYD Reflow Oven Controller

> **⚠️ SAFETY WARNING:** This project involves modifying an appliance that uses **mains voltage (120V/240V)** and generates **extreme heat**. Improper wiring can result in electric shock, fire, or severe injury. Do not attempt this unless you are comfortable and experienced working with mains AC power. A smart plug is utilized as a Home Assistant-integrated kill switch for added safety, but never leave the oven unattended while in use.

## 📖 Overview

A custom-built, cost-optimized, microcontroller-driven reflow oven for soldering Surface Mount Technology (SMT) printed circuit boards. This project is a budget-friendly alternative designed to undercut the Adafruit EZ Make Oven (~$110), using a Cheap Yellow Display (CYD) as the brains and UI. 

The controller sits in a standalone 3D-printed enclosure next to the oven, handling custom reflow profiles using a slow-PWM Solid State Relay (SSR) control loop.

## ✨ Features & Current State

* **Hardware/Firmware:** Live graph rendering on CYD touchscreen, bit-banged MAX6675 SPI communication, and slow-PWM SSR control on a 2-second window.
* **Enclosure:** Parametric OpenSCAD standalone enclosure (190×90×65mm) with internal AC/DC divider.
* **Cost-Conscious:** Minimizes BOM spend by utilizing the highly integrated CYD ESP32 board and off-the-shelf components.
* **Safety First:** Fused IEC mains inlet and a smart plug acting as a remote kill switch.

---

## 🛠️ Parts List (Bill of Materials)

| Component | Part / Model | Notes |
| :--- | :--- | :--- |
| **Microcontroller/UI** | AITRIP CYD (ESP32-2432S028R) | 2.8" resistive touchscreen. |
| **Toaster Oven** | Black & Decker TO1755SB | The base unit to be modified. |
| **Thermocouple & Amp** | MAX6675 Module | K-Type Thermocouple. |
| **Solid State Relay** | Inkbird SSR-40DA + Heatsink | Controls the AC heating elements. |
| **AC Inlet** | 3Dman IEC C14 Inlet | Fused, integrated rocker switch, pre-crimped. |
| **Kill Switch** | HA-Compatible Smart Plug | Integrated with Home Assistant for emergency shutoff. |

---

## ⚡ Pinout & Wiring Configurations

Through iterative hardware bring-up, specific pin mappings were chosen to avoid conflicts on the CYD board. 

### CYD to MAX6675 (Thermocouple)

We use bit-banged SPI (with a retry-on-failure pattern) to communicate with the MAX6675.
* **SCK:** GPIO 22
* **CS:** GPIO 27
* **SO:** GPIO 35

> **⚠️ GPIO 21 Warning:** Do not use GPIO 21 for the SPI clock. On the CYD, GPIO 21 controls the backlight. Clocking SPI on this pin causes intermittent `OPEN_THERMOCOUPLE` errors.

### CYD to SSR (Heat Control)

* **Control Pin:** GPIO 1 (TX line of P1 serial connector)

> **⚠️ GPIO 1 / UART TX Conflict:** Because GPIO 1 is used for the SSR, **all `Serial.print()` calls must be removed** from the firmware. Leaving serial prints in the code will inadvertently toggle the SSR and fire the oven during serial output. 

---

## 💻 Firmware & Upload Procedure

### Libraries Required

* `TFT_eSPI` (For the display)
* `XPT2046_Touchscreen` (For the touch interface, utilizing VSPI)
* *Note: The MAX6675 utilizes custom bit-banged SPI; no external library is required.*

### Uploading Code to the CYD

Because we are utilizing GPIO 1 (TX) for the SSR, you must follow this exact procedure to flash the ESP32:
1. **Disconnect** the SSR control wire from GPIO 1.
2. Compile and upload your sketch via the Arduino IDE/PlatformIO.
3. **Reconnect** the SSR control wire.
4. Press the **RST** button on the CYD for a clean boot.

---

## 🖨️ Enclosure & 3D Printing

The enclosure is a standalone unit that sits next to the oven. It features a physical divider separating the high-voltage AC side from the low-voltage DC side. The SSR heatsink sits inside the case, with ventilation slots on the lid handling the ~12.5W dissipation load.

* **Dimensions:** 190mm (W) × 90mm (D) × 65mm (H)
* **AC/DC Divider:** Located at X=90.
* **Recommended Material:** ASA (Preferred) or PETG. *Do not use PLA, as it will warp from ambient oven heat.*
* **Print Settings:** 3 perimeters, 30–40% gyroid infill.

### OpenSCAD Compilation

The enclosure is fully parametric. If you need to generate the `.stl` files from the CLI, use the following pattern:

```bash
xvfb-run -a openscad -D 'part="bottom"' -o output.stl reflow-enclosure.scad
```

### *Note: For PNG previews, append --imgsize=WxH --camera=ex,ey,ez,lx,ly,lz,dist to the command above.*

## 🚧 Known Issues & To-Do
- [ ] Complete DC-side SSR testing and finalize AC mains wiring.
- [ ] Measure and lock in the exact CYD mounting hole pattern (currently assuming 82×44mm for AITRIP variant).
- [ ] Verify precise SSR heatsink dimensions to finalize vent clearances.
- [ ] Map the exact USB-C connector position for this specific CYD variant.
- [ ] Decide on final CYD power routing (external wall wart vs. internal AC-to-5V module).
- [ ] Finalize full reflow profile firmware logic.
- [ ] Update Markdown specification document to reflect final 190×90×65mm dimensions.
