"""Generate the v12 wiring diagram (SVG + PNG).

Usage: python3 tools/make_wiring_diagram.py   (writes reflow-wiring-diagram.svg
and diy_reflow_controller_wiring_diagram.png in the repo root; PNG needs cairosvg)
"""
import os

W, H = 1700, 1180
out = []
A = out.append

HOT, NEU, GND = "#111111", "#ffffff", "#1a8f3a"
C3V3, CGND, C32, C21, C22, C16 = "#d62728", "#444444", "#ff7f0e", "#b8860b", "#7b3fb5", "#13808a"
FONT = "DejaVu Sans, Arial, sans-serif"


def text(x, y, s, size=15, weight="normal", anchor="start", fill="#111"):
    s = s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    A(f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" font-weight="{weight}" '
      f'text-anchor="{anchor}" fill="{fill}">{s}</text>')


def box(x, y, w, h, title, lines=(), fill="#f4f6f8", stroke="#333"):
    A(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" fill="{fill}" stroke="{stroke}" stroke-width="2"/>')
    text(x + w / 2, y + 22, title, 16, "bold", "middle")
    for i, s in enumerate(lines):
        text(x + w / 2, y + 42 + 18 * i, s, 13, anchor="middle", fill="#333")


def wire(pts, color, width=4, dash=None):
    d = " ".join(f"{x},{y}" for x, y in pts)
    if color == NEU:   # white wire: dark outline
        A(f'<polyline points="{d}" fill="none" stroke="#111" stroke-width="{width + 3}" stroke-linejoin="round"/>')
    A(f'<polyline points="{d}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round"'
      + (f' stroke-dasharray="{dash}"' if dash else "") + "/>")


def pin(x, y, label, side="left", color="#111"):
    A(f'<circle cx="{x}" cy="{y}" r="4.5" fill="#fff" stroke="#111" stroke-width="2"/>')
    if side == "left":
        text(x + 9, y + 5, label, 13, fill=color)
    else:
        text(x - 9, y + 5, label, 13, anchor="end", fill=color)


A(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">')
A(f'<rect width="{W}" height="{H}" fill="#ffffff"/>')
text(30, 40, "Reflow oven controller v12 — wiring", 26, "bold")
text(30, 66, "Schematic, not to scale. AC bay left, DC bay right of the divider. Enclosure: OpenSCAD v12.0.", 15, fill="#444")

# enclosure + divider
A('<rect x="20" y="90" width="1660" height="900" rx="10" fill="none" stroke="#9aa5b1" stroke-width="2" stroke-dasharray="10,6"/>')
text(40, 115, "AC BAY (mains)", 15, "bold", fill="#b22222")
text(1050, 115, "DC BAY (3.3 V / 5 V)", 15, "bold", fill="#1f5fa8")
A('<line x1="1030" y1="92" x2="1030" y2="180" stroke="#555" stroke-width="6"/>')
A('<line x1="1030" y1="280" x2="1030" y2="988" stroke="#555" stroke-width="6"/>')
text(1036, 172, "divider", 12, fill="#555")
text(1036, 298, "U-slot (only crossing)", 12, fill="#555")

# --- AC devices
box(40, 140, 230, 220, "FILSHU C14 inlet", ["15 A fuse (5x20, ceramic T)", "rocker switches HOT", "rear wall"])
pin(270, 260, "HOT (fused, switched)", "right"); pin(270, 300, "NEUTRAL", "right"); pin(270, 340, "GROUND", "right")

box(360, 150, 100, 70, "221-413", ["HOT"], fill="#fff7e6")
box(360, 420, 100, 100, "221-415", ["NEUTRAL"], fill="#fff7e6")
box(360, 780, 100, 100, "221-415", ["GROUND"], fill="#fff7e6")

box(600, 130, 210, 150, "Shelly 1PM Gen4", ["EU or UL model", "pocket on left wall", "SW: not connected"])
pin(600, 175, "L"); pin(600, 235, "N"); pin(810, 190, "O", "right")

box(600, 380, 210, 170, "KP200 (lid)", ["always live", "top socket blanked"])
pin(600, 430, "Line"); pin(600, 475, "Neutral"); pin(600, 520, "Ground")
pin(810, 465, "bottom socket", "right")
box(860, 430, 125, 75, "USB adapter", ["5 V, in KP200"], fill="#eef5ff")

box(600, 700, 210, 180, "NEMA 5-15R socket", ["oven plugs in here", "left wall"])
pin(810, 830, "HOT (narrow)", "right"); pin(600, 795, "NEUTRAL (wide)"); pin(600, 850, "GROUND (round)")

box(860, 150, 140, 200, "SSR-40DA", [], fill="#fdeeee")
text(930, 322, "AC end: KP200 side", 12, anchor="middle", fill="#333")
text(930, 338, "DC end: divider side", 12, anchor="middle", fill="#333")
pin(860, 190, "T1"); pin(860, 290, "T2"); pin(1000, 200, "T4 −", "right"); pin(1000, 260, "T3 +", "right")

# --- AC wiring
wire([(270, 260), (330, 260), (330, 185), (360, 185)], HOT)
wire([(460, 175), (600, 175)], HOT)
wire([(460, 200), (520, 200), (520, 430), (600, 430)], HOT)
wire([(270, 300), (310, 300), (310, 470), (360, 470)], NEU)
wire([(460, 440), (545, 440), (545, 235), (600, 235)], NEU)
wire([(460, 470), (570, 470), (570, 475), (600, 475)], NEU)
wire([(460, 500), (500, 500), (500, 795), (600, 795)], NEU)
wire([(270, 340), (290, 340), (290, 830), (360, 830)], GND)
wire([(460, 800), (480, 800), (480, 560), (580, 560), (580, 520), (600, 520)], GND)
wire([(460, 830), (530, 830), (530, 850), (600, 850)], GND)
wire([(460, 860), (500, 860), (500, 950), (1012, 950), (1012, 365), (980, 365), (980, 350)], GND)
text(1005, 940, "heatsink bond: ring terminal under a heatsink screw", 12, anchor="end", fill=GND)
wire([(810, 190), (860, 190)], HOT)
text(835, 182, "", 11)
wire([(860, 290), (840, 290), (840, 830), (810, 830)], HOT)
wire([(810, 465), (860, 465)], "#555", 3)
text(500, 1010, "", 12)

# --- DC devices
box(1300, 130, 360, 400, "Elecrow CrowPanel 2.8", ["front panel, landscape,", "connectors DOWN", "(firmware rotates 180°)"], fill="#eef5ff")
text(1310, 222, "J7 GPIO_D", 13, "bold"); text(1310, 342, "J6 IIC", 13, "bold"); text(1310, 452, "J10 UART1", 13, "bold")
for y, lab in [(240, "1 IO25"), (262, "2 IO32"), (284, "3 3V3"), (306, "4 GND")]:
    pin(1300, y, lab)
for y, lab in [(360, "1 IO21"), (382, "2 IO22"), (404, "3 3V3"), (426, "4 GND")]:
    pin(1300, y, lab)
for y, lab in [(470, "1 IO16"), (492, "2 IO17"), (514, "3 3V3")]:
    pin(1300, y, lab)
pin(1660, 200, "USB-C", "right")

box(1060, 620, 170, 200, "MAX6675", ["module on DC floor"], fill="#f0f8f0")
pins_max = [(650, "CS"), (680, "SCK"), (710, "VCC"), (740, "GND"), (770, "SO")]
for y, lab in pins_max:
    pin(1230, y, lab, "right")
pin(1060, 700, "T+"); pin(1060, 750, "T−")
wire([(1060, 700), (1045, 700), (1045, 900)], "#e0b000", 3)
wire([(1060, 750), (1052, 750), (1052, 900)], "#d62728", 3)
box(1060, 900, 300, 70, "K-type probe", ["through the right-wall hole", "ANSI colours: + yellow, − red"], fill="#fafafa")

# --- DC wiring
wire([(1300, 262), (1140, 262), (1140, 200), (1000, 200)], C32, 3)
wire([(1300, 284), (1120, 284), (1120, 260), (1000, 260)], C3V3, 3)
text(1045, 330, "SSR pair: sleeve with 600 V", 12, fill="#333")
text(1045, 345, "heat-shrink through the AC bay", 12, fill="#333")
wire([(1300, 240), (1270, 240)], "#999", 2); text(1265, 245, "insulate", 11, anchor="end", fill="#777")
wire([(1300, 306), (1270, 306)], "#999", 2); text(1265, 311, "NC — never to SSR", 11, anchor="end", fill="#b22222")
wire([(1300, 360), (1240, 360), (1240, 650), (1230, 650)], C21, 3)
wire([(1300, 382), (1250, 382), (1250, 680), (1230, 680)], C22, 3)
wire([(1300, 404), (1260, 404), (1260, 710), (1230, 710)], C3V3, 3)
wire([(1300, 426), (1270, 426), (1270, 740), (1230, 740)], CGND, 3)
wire([(1300, 470), (1280, 470), (1280, 770), (1230, 770)], C16, 3)
for y in (492, 514):
    wire([(1300, y), (1292, y)], "#999", 2)
text(1310, 545, "J10 pins 2–4 and J7 pins 1, 4: insulate, leave unconnected", 12, fill="#777")

# USB off-page link
for (x, y) in [(985, 467), (1660, 200)]:
    pass
A('<circle cx="1003" cy="467" r="13" fill="#fff" stroke="#1f5fa8" stroke-width="2"/>'); text(1003, 472, "U", 13, "bold", "middle", "#1f5fa8")
wire([(985, 467), (990, 467)], "#1f5fa8", 3)
A('<circle cx="1680" cy="200" r="13" fill="#fff" stroke="#1f5fa8" stroke-width="2"/>'); text(1680, 205, "U", 13, "bold", "middle", "#1f5fa8")
text(1575, 600, "U = USB-A to USB-C cable,", 13, anchor="middle", fill="#1f5fa8")
text(1575, 618, "runs OUTSIDE the box, enters", 13, anchor="middle", fill="#1f5fa8")
text(1575, 636, "the right-wall slot", 13, anchor="middle", fill="#1f5fa8")

# legend
ly = 1015
text(30, ly, "Wires", 16, "bold")
items = [(HOT, "Hot, 14 AWG UL 1015 (600 V, 105 °C)"), (NEU, "Neutral, 14 AWG"), (GND, "Ground, 14 AWG"),
         (C32, "IO32 → SSR T4 (active-low drive)"), (C3V3, "3V3"), (CGND, "GND"),
         (C21, "IO21 → CS"), (C22, "IO22 → SCK"), (C16, "IO16 ← SO")]
for i, (c, s) in enumerate(items):
    x = 30 + (i % 3) * 400
    y = ly + 25 + (i // 3) * 26
    wire([(x, y - 5), (x + 40, y - 5)], c, 4 if i < 3 else 3)
    text(x + 50, y, s, 13)
notes = ["SSR: bare wire under the clamp plates, strands twisted, NOT tinned. T1/T2 at the SSR end toward the KP200, T3/T4 toward the divider.",
         "Wagos are the junctions: the Shelly's manual says not to power other devices from its L terminals",
         "and not to put several wires under one terminal. Shelly: strip 6–7 mm, 0.4 N·m. WAGO 221: strip 11 mm."]
for i, s in enumerate(notes):
    text(1230, ly + 25 + 22 * i, "", 12)
for i, s in enumerate(notes):
    text(30, ly + 112 + 20 * i, s, 13, fill="#333")
A("</svg>")

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
svg = "\n".join(out)
open(os.path.join(root, "reflow-wiring-diagram.svg"), "w").write(svg)
try:
    import cairosvg
    cairosvg.svg2png(bytestring=svg.encode(), write_to=os.path.join(root, "diy_reflow_controller_wiring_diagram.png"))
    print("wrote SVG + PNG")
except ImportError:
    print("wrote SVG (install cairosvg for the PNG)")
