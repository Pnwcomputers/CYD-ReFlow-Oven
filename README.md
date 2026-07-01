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

## ⚡ Improved Wiring Guide & Schematic

This section details the wiring for the CYD Reflow Oven Controller. The design is split into two distinct sections: the **Low Voltage (DC) Control Side** and the **High Voltage (AC) Power Side**.

> **⚠️ SEPARATION WARNING:** Maintain strict physical separation between the AC and DC wiring within your enclosure, using the integrated divider. Do not route AC wires near the microcontroller.

### 🔵 Part 1: Low Voltage (DC) Control Side

This side connects the CYD (ESP32) to the sensors and the control side of the SSR.

#### 1. Thermocouple Amplifier (MAX6675)
We use a software bit-banged SPI configuration for the MAX6675 to avoid conflicts with the CYD’s onboard hardware.

| MAX6675 Pin | Connection to CYD (ESP32) |
| :--- | :--- |
| **VCC** | Connect to **3.3V** (Available on P1 Connector) |
| **GND** | Connect to **GND** (Available on P1 Connector) |
| **SCK** (Clock) | Connect to **GPIO 22** |
| **CS** (Chip Select) | Connect to **GPIO 27** |
| **SO** (Slave Out) | Connect to **GPIO 35** (This is an input-only pin on the ESP32, which is correct here) |

> **⛔ DO NOT USE GPIO 21:** Avoid using GPIO 21 for the SPI clock. This pin controls the CYD backlight and will cause communication failures.

#### 2. Solid State Relay (SSR) Control
This connects the CYD trigger signal to the input side of the Inkbird SSR.

| Connection | Description |
| :--- | :--- |
| **CYD GPIO 1 (TX)** | Connect to **SSR Terminal 3 (+)** (Input) |
| **CYD GND** | Connect to **SSR Terminal 4 (-)** (Input) |

> **⚠️ CRITICAL GPIO 1 CONFLICT WARNING:** GPIO 1 on the CYD is also the hardware Serial TX pin used for programming and debugging.
> 
> 1. **DISABLE ALL `Serial.print()`** calls in your final code. Any serial output during operation will cause the SSR to rapidly toggle, unexpectedly firing the oven.
> 2. **FOLLOW UPLOAD PROCEDURE:** You must disconnect the wire from GPIO 1 to the SSR before uploading code, or the upload will fail. Reconnect and reset the board after flashing.

### 🔴 Part 2: High Voltage (AC) Mains Power Side

This section details the AC wiring that powers the oven heating elements.

#### 1. Fused IEC Inlet & Switch
Wiring the integrated fused IEC C14 inlet and rocker switch.

* **AC Inlet → Smart Plug:** This whole system should be plugged into the Home Assistant-controlled smart plug.
* **Earth/Ground (Green/Yellow):** Connect the Earth pin of the IEC inlet directly to the metal chassis of the toaster oven and the ground terminal of the IEC inlet itself. This is critical for safety.
* **Neutral (Blue):** Connect the Neutral pin of the IEC inlet directly to one side of the oven’s heating elements.
* **Hot/Line (Brown/Red):** Connect the Hot pin of the IEC inlet to the **Fuse Holder** input.
* **Fuse Holder Output:** Connect to one terminal of the **Rocker Switch**.

#### 2. SSR Load Wiring
The SSR acts as a switch in the Hot/Line wire path.

* **Rocker Switch (Output Terminal):** Connect this to **SSR Terminal 1** (Load Output).
* **SSR Terminal 2 (Load Output):** Connect this to the remaining terminal of the oven’s heating elements.

> **⚠️ SAFETY CONFIRMATION:** Ensure the SSR is switching the **Hot (Live)** wire, **NOT** the Neutral wire. Switching Neutral is extremely dangerous, as the heating elements would remain live even when the oven is "off."

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
