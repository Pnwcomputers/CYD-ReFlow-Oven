"""Generate the v12.1 illustrated wiring and layout sheets (SVG).

Usage: python3 tools/make_wiring_diagrams.py
Writes into docs/wiring/:
  reflow-wiring-ac-mains.svg      sheet 1: mains wiring, wire by wire
  reflow-wiring-low-voltage.svg   sheet 2: controller, sensor, SSR drive, USB, Wi-Fi
  reflow-layout-clearances.svg    sheet 3: where everything sits, to scale
PNG and PDF copies: node tools/render_diagrams.js (needs Playwright/Chromium).

The devices are drawn as simplified likenesses. Terminal positions on the
drawings are schematic: always go by the labels printed on the part itself.
"""
import os

FONT = "DejaVu Sans, Arial, Helvetica, sans-serif"
HOT, NEU, GND = "#1a1a1a", "#ffffff", "#1a8f3a"
RED, YEL, WHT, BLK, BLUE = "#d62728", "#e8b500", "#ffffff", "#1a1a1a", "#1f5fa8"


class Sheet:
    def __init__(self, w, h, title, sub):
        self.w, self.h, self.o = w, h, []
        self.o.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">')
        self.o.append('<defs><marker id="arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" '
                      'orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#333"/></marker>'
                      '<marker id="arrb" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" '
                      'orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#1f5fa8"/></marker>'
                      '<pattern id="fins" width="14" height="14" patternUnits="userSpaceOnUse">'
                      '<rect width="14" height="14" fill="#c9ced4"/><rect width="6" height="14" fill="#9aa2ab"/></pattern>'
                      '<pattern id="hatch" width="8" height="8" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">'
                      '<rect width="8" height="8" fill="#e9edf1"/><rect width="3" height="8" fill="#c3cad2"/></pattern></defs>')
        self.o.append(f'<rect width="{w}" height="{h}" fill="#ffffff"/>')
        self.text(30, 42, title, 27, "bold")
        self.text(30, 68, sub, 15, fill="#444")

    def raw(self, s):
        self.o.append(s)

    def text(self, x, y, s, size=14, weight="normal", anchor="start", fill="#111", rot=None):
        s = str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        tr = f' transform="rotate({rot} {x} {y})"' if rot is not None else ""
        self.o.append(f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" font-weight="{weight}" '
                      f'text-anchor="{anchor}" fill="{fill}"{tr}>{s}</text>')

    def rect(self, x, y, w, h, fill="#f4f6f8", stroke="#333", sw=2, rx=6, dash=None, op=None):
        self.o.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" '
                      f'stroke-width="{sw}"' + (f' stroke-dasharray="{dash}"' if dash else "")
                      + (f' fill-opacity="{op}"' if op is not None else "") + "/>")

    def circ(self, x, y, r, fill="#fff", stroke="#111", sw=2):
        self.o.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')

    def line(self, x1, y1, x2, y2, stroke="#333", sw=2, dash=None, arrow=None):
        self.o.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{stroke}" stroke-width="{sw}"'
                      + (f' stroke-dasharray="{dash}"' if dash else "")
                      + (f' marker-end="url(#{arrow})"' if arrow else "") + "/>")

    def wire(self, pts, color, width=6, dash=None, tag=None, tagpos=None):
        d = " ".join(f"{x},{y}" for x, y in pts)
        halo = "#111" if color == NEU else "#ffffff"
        hw = width + (3 if color == NEU else 4)
        self.o.append(f'<polyline points="{d}" fill="none" stroke="{halo}" stroke-width="{hw}" stroke-linejoin="round" stroke-linecap="round"/>')
        self.o.append(f'<polyline points="{d}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round"'
                      + (f' stroke-dasharray="{dash}"' if dash else "") + "/>")
        if tag:
            x, y = tagpos
            self.tag(x, y, tag)

    def tag(self, x, y, s, fill="#fff3bf"):
        w = 12 + 9 * len(s)
        self.o.append(f'<rect x="{x - w / 2}" y="{y - 11}" width="{w}" height="22" rx="11" fill="{fill}" stroke="#111" stroke-width="1.5"/>')
        self.text(x, y + 5, s, 13, "bold", "middle")

    def term(self, x, y, label, side="r", size=13, color="#111"):
        """Screw terminal dot with a label on the given side (l, r, t, b)."""
        self.circ(x, y, 7, "#d9d9d9", "#111", 2)
        self.line(x - 4, y - 4, x + 4, y + 4, "#555", 1.5)
        if side == "r":
            self.text(x + 12, y + 5, label, size, "bold", fill=color)
        elif side == "l":
            self.text(x - 12, y + 5, label, size, "bold", "end", color)
        elif side == "t":
            self.text(x, y - 12, label, size, "bold", "middle", color)
        else:
            self.text(x, y + 23, label, size, "bold", "middle", color)

    def note(self, x, y, lines, size=13, fill="#333", lh=18, weight="normal"):
        for i, s in enumerate(lines):
            self.text(x, y + i * lh, s, size, weight, fill=fill)

    def save(self, path):
        open(path, "w").write("\n".join(self.o + ["</svg>"]))


# ------------------------------------------------------------ device likenesses
def wall_plug(s, x, y):
    """NEMA 5-15P plug + cord end with a C13 connector."""
    s.rect(x, y, 70, 56, "#2b2b2b", "#111", 2, 10)
    for dy in (14, 36):
        s.rect(x - 22, y + dy, 24, 6, "#c9a23a", "#7a6220", 1, 1)
    s.rect(x - 24, y + 24, 22, 8, "#c9a23a", "#7a6220", 1, 4)
    s.text(x + 84, y + 14, "Wall outlet, 120 V", 13, "bold")
    s.text(x + 84, y + 32, "14 AWG / 15 A cord,", 12, fill="#444")
    s.text(x + 84, y + 48, "5-15P to C13", 12, fill="#444")


def inlet(s, x, y):
    """FILSHU C14 inlet module: C14 pins, fuse drawer, rocker switch."""
    s.rect(x, y, 240, 150, "#262626", "#111", 2.5, 8)
    s.raw(f'<path d="M{x + 16},{y + 34} h70 l14,14 v54 h-98 v-54 z" fill="#111" stroke="#555" stroke-width="2"/>')
    for px, py in ((x + 34, y + 76), (x + 68, y + 76), (x + 51, y + 56)):
        s.rect(px - 4, py - 9, 8, 18, "#d7d7d7", "#888", 1, 1)
    s.rect(x + 110, y + 40, 34, 62, "#3a3a3a", "#777", 1.5, 3)
    s.text(x + 127, y + 66, "FUSE", 10, "bold", "middle", "#ddd")
    s.text(x + 127, y + 82, "15 A T", 10, "bold", "middle", "#ffd24d")
    s.rect(x + 156, y + 34, 66, 76, "#111", "#666", 2, 5)
    s.rect(x + 162, y + 40, 54, 64, "#c62828", "#7f1010", 1.5, 4)
    s.text(x + 189, y + 62, "I", 16, "bold", "middle", "#fff")
    s.text(x + 189, y + 96, "O", 15, "bold", "middle", "#fff")
    s.text(x + 120, y + 22, "FILSHU C14 inlet", 15, "bold", "middle", "#fff")
    s.text(x + 120, y + 138, "rear wall · snap-in", 12, anchor="middle", fill="#ccc")
    s.text(x + 120, y + 170, "fuse + rocker are in the HOT leg", 12, anchor="middle", fill="#444")
    s.text(x + 120, y + 186, "(find L / N / E with a meter)", 12, anchor="middle", fill="#444")


def wago(s, x, y, n, name, fill):
    """WAGO 221 lever nut, drawn as a column of n ports."""
    h = 28 * n + 22
    s.rect(x, y, 90, h, "#e8f0f7", "#555", 2, 8, op=0.9)
    for i in range(n):
        cy = y + 25 + 28 * i
        s.rect(x + 30, cy - 9, 30, 18, "#f08a1c", "#a85a05", 1.5, 3)
        s.rect(x + 6, cy - 5, 20, 10, "#b9c4cf", "#7c8791", 1, 2)
        s.rect(x + 64, cy - 5, 20, 10, "#b9c4cf", "#7c8791", 1, 2)
    s.rect(x - 4, y - 30, 98, 24, fill, "#333", 1.5, 5)
    s.text(x + 45, y - 13, name, 13, "bold", "middle", "#fff" if fill != "#ffffff" else "#111")
    s.text(x + 45, y + h + 16, f"WAGO 221-41{n}", 12, anchor="middle", fill="#444")
    return [y + 25 + 28 * i for i in range(n)]


def shelly(s, x, y):
    """Shelly 1PM Gen4: small rounded module with a screw-terminal strip."""
    s.rect(x, y, 200, 150, "#1c3f6e", "#0d2240", 2.5, 22)
    s.rect(x + 14, y + 14, 172, 122, "#24508a", "#0d2240", 1, 16)
    s.text(x + 100, y + 52, "Shelly", 22, "bold", "middle", "#fff")
    s.text(x + 100, y + 76, "1PM Gen4", 15, "bold", "middle", "#cfe0f5")
    s.text(x + 100, y + 100, "relay + power meter", 12, anchor="middle", fill="#cfe0f5")
    s.text(x + 100, y + 118, "Wi-Fi watchdog", 12, anchor="middle", fill="#cfe0f5")
    s.text(x + 100, y + 170, "pocket on the left wall", 12, anchor="middle", fill="#444")
    s.text(x + 100, y + 186, "SW terminal: leave empty", 12, anchor="middle", fill="#444")


def ssr(s, x, y, heatsink=True):
    """SSR-40DA on its finned heatsink. Returns terminal centres."""
    if heatsink:
        s.rect(x - 50, y - 20, 260, 230, "url(#fins)", "#6f7780", 2, 4)
        s.text(x + 80, y + 228, "aluminium heatsink (grounded)", 12, anchor="middle", fill="#444")
    s.rect(x, y, 160, 190, "#f2f2f2", "#222", 2.5, 6)
    s.rect(x + 8, y + 48, 144, 94, "#fafafa", "#999", 1, 3)
    s.text(x + 80, y + 76, "SSR-40DA", 17, "bold", "middle")
    s.text(x + 80, y + 96, "Inkbird · 40 A", 12, anchor="middle", fill="#444")
    s.text(x + 80, y + 114, "in 3-32 V DC", 12, anchor="middle", fill="#444")
    s.text(x + 80, y + 131, "out 24-480 V AC", 12, anchor="middle", fill="#444")
    s.circ(x + 80, y + 160, 6, "#ff3b30", "#7f1010", 1.5)
    s.text(x + 80, y + 182, "LED", 10, anchor="middle", fill="#555")
    return {"T1": (x + 36, y + 24), "T2": (x + 124, y + 24), "T4": (x + 36, y + 166), "T3": (x + 124, y + 166)}


def kp200(s, x, y, w=190, h=220):
    """Kasa KP200 in-wall smart outlet: two sockets, each with a button."""
    s.rect(x, y, w, h, "#fbfbfb", "#555", 2.5, 12)
    c = x + w / 2 + 14
    for i, cy in enumerate((y + h * 0.27, y + h * 0.73)):
        s.rect(c - 40, cy - 38, 80, 76, "#f1f1f1", "#888", 1.5, 14)
        s.rect(c - 16, cy - 22, 5, 18, "#222", "#222", 0, 1)
        s.rect(c + 11, cy - 22, 5, 14, "#222", "#222", 0, 1)
        s.raw(f'<path d="M{c - 6},{cy + 22} a6,6 0 1 1 12,0 z" fill="#222"/>')
        s.circ(x + w - 18, cy, 7, "#e6e6e6", "#888", 1.5)


def socket(s, x, y):
    """FILSHU snap-in NEMA 5-15R panel socket."""
    s.rect(x, y, 170, 170, "#2a2a2a", "#111", 2.5, 12)
    s.rect(x + 28, y + 28, 114, 114, "#1b1b1b", "#555", 1.5, 16)
    s.rect(x + 60, y + 52, 7, 34, "#000", "#777", 1, 1)
    s.rect(x + 104, y + 56, 7, 26, "#000", "#777", 1, 1)
    s.raw(f'<path d="M{x + 74},{y + 122} a11,11 0 1 1 22,0 z" fill="#000" stroke="#777" stroke-width="1"/>')
    s.text(x + 85, y + 160, "NEMA 5-15R", 12, "bold", "middle", "#fff")


def oven(s, x, y):
    """Toaster oven."""
    s.rect(x, y, 250, 170, "#d5d8dc", "#555", 2.5, 10)
    s.rect(x + 14, y + 16, 160, 126, "#3a2a1a", "#222", 2, 6)
    s.rect(x + 22, y + 24, 144, 110, "#5a3a18", "#222", 1, 4)
    for i in range(4):
        s.line(x + 30, y + 44 + i * 24, x + 158, y + 44 + i * 24, "#ff8a3c", 2.5)
    s.rect(x + 30, y + 144, 128, 8, "#888", "#555", 1, 4)
    for cy in (y + 40, y + 86, y + 132):
        s.circ(x + 212, cy, 16, "#f4f4f4", "#555", 2)
        s.line(x + 212, cy, x + 212, cy - 13, "#333", 2.5)
    s.rect(x + 20, y + 170, 16, 10, "#555", "#333", 1, 2)
    s.rect(x + 214, y + 170, 16, 10, "#555", "#333", 1, 2)
    s.text(x + 125, y - 12, "Toaster oven (~1150 W)", 14, "bold", "middle")


def drok(s, x, y, w=300, h=150):
    """DROK AC multimeter face."""
    s.rect(x, y, w, h, "#1d1d1d", "#000", 2.5, 8)
    s.rect(x + 16, y + 16, w - 32, h - 46, "#0b2a5c", "#3b6fc4", 2, 4)
    s.text(x + 30, y + 50, "120.4", 26, "bold", fill="#e9f3ff"); s.text(x + 118, y + 50, "V", 14, "bold", fill="#9cc4ff")
    s.text(x + 160, y + 50, "9.58", 26, "bold", fill="#e9f3ff"); s.text(x + 232, y + 50, "A", 14, "bold", fill="#9cc4ff")
    s.text(x + 30, y + 90, "1153", 26, "bold", fill="#e9f3ff"); s.text(x + 104, y + 90, "W", 14, "bold", fill="#9cc4ff")
    s.text(x + 160, y + 90, "0.12", 26, "bold", fill="#e9f3ff"); s.text(x + 232, y + 90, "kWh", 13, "bold", fill="#9cc4ff")
    s.text(x + w / 2, y + h - 10, "DROK AC 50-300 V · 100 A", 12, "bold", "middle", "#ddd")


def ct(s, x, y, vertical=True):
    """Split-core current transformer around a wire at (x, y)."""
    s.rect(x - 34, y - 30, 68, 60, "#20262e", "#000", 2.5, 10)
    s.rect(x - 14, y - 14, 28, 28, "#ffffff", "#000", 2, 6)
    s.line(x - 34, y, x - 14, y, "#8b96a3", 2)
    s.line(x + 14, y, x + 34, y, "#8b96a3", 2)
    s.rect(x + 22, y - 36, 14, 10, "#4a90d9", "#1d4f8a", 1.5, 2)


def usb_adapter(s, x, y):
    s.rect(x, y, 70, 60, "#fafafa", "#666", 2, 8)
    s.rect(x + 22, y + 40, 26, 12, "#333", "#111", 1, 2)
    s.text(x + 35, y + 22, "5 V", 13, "bold", "middle")
    s.text(x + 35, y + 36, "USB", 11, anchor="middle", fill="#444")


def crowpanel(s, x, y):
    """CrowPanel 2.8 / NerdMiner 2.8, seen from the back, connectors down."""
    w, h = 520, 330
    s.rect(x, y, w, h, "#12233a", "#0a1322", 3, 10)
    for cx, cy in ((x + 22, y + 22), (x + w - 22, y + 22), (x + 22, y + h - 22), (x + w - 22, y + h - 22)):
        s.circ(cx, cy, 9, "#ffffff", "#c9a23a", 3)
    s.rect(x + 60, y + 36, 400, 200, "none", "#3f5f8a", 1.5, 4, dash="6,5")
    s.text(x + 260, y + 58, '2.8" display on the other side (320 x 240, touch)', 12, anchor="middle", fill="#8fb0dd")
    s.rect(x + 300, y + 86, 130, 110, "#c0c5cb", "#555", 2, 4)
    s.rect(x + 310, y + 96, 110, 68, "#8d949c", "#555", 1, 2)
    s.text(x + 365, y + 128, "ESP32", 14, "bold", "middle")
    s.text(x + 365, y + 146, "WROOM-32", 11, anchor="middle")
    s.raw(f'<path d="M{x + 312},{y + 186} h14 v-12 h12 v12 h12 v-12 h12 v12 h12 v-12 h12 v12 h14" fill="none" stroke="#333" stroke-width="2"/>')
    s.text(x + 150, y + 120, "Elecrow CrowPanel 2.8", 17, "bold", "middle", "#fff")
    s.text(x + 150, y + 142, '(sold as "NerdMiner 2.8")', 13, anchor="middle", fill="#cfe0f5")
    s.text(x + 150, y + 166, "back view, as mounted:", 12, anchor="middle", fill="#cfe0f5")
    s.text(x + 150, y + 183, "connectors point DOWN", 12, "bold", "middle", "#ffd24d")
    # USB-C on the right edge
    s.rect(x + w - 30, y + 150, 34, 44, "#c9ced4", "#555", 2, 6)
    s.text(x + w - 40, y + 177, "USB-C", 12, "bold", "end", "#fff")
    return w, h


def hy_conn(s, x, y, name, silk, pins):
    """HY2.0-4P socket on the board's bottom edge. Returns pin x positions."""
    s.rect(x, y - 42, 116, 44, "#f5f0df", "#555", 2, 4)
    s.text(x + 58, y - 52, f"{name}  {silk}", 13, "bold", "middle", "#fff")
    xs = []
    for i, p in enumerate(pins):
        px = x + 16 + 28 * i
        xs.append(px)
        s.rect(px - 5, y - 20, 10, 20, "#c9a23a", "#7a6220", 1, 1)
        s.text(px, y - 26, str(i + 1), 11, "bold", "middle", "#333")
    return xs


def max6675(s, x, y):
    """MAX6675 breakout: 5-pin header on top, thermocouple screw block below."""
    s.rect(x, y, 240, 130, "#1b4fa0", "#0d2a59", 2.5, 6)
    s.rect(x + 86, y + 44, 60, 40, "#222", "#000", 1.5, 2)
    s.text(x + 116, y + 69, "MAX6675", 11, "bold", "middle", "#eee")
    s.text(x + 200, y + 70, "K-type", 11, anchor="middle", fill="#cfe0f5")
    s.rect(x + 20, y + 96, 80, 40, "#2e9e4f", "#14592a", 2, 3)
    names = ["SO", "CS", "SCK", "VCC", "GND"]
    xs = {}
    for i, n in enumerate(names):
        px = x + 40 + 40 * i
        xs[n] = px
        s.rect(px - 6, y - 8, 12, 22, "#c9a23a", "#7a6220", 1, 1)
        s.text(px, y + 30, n, 12, "bold", "middle", "#fff")
    return xs


def wifi(s, x, y, color="#1f5fa8"):
    for r in (10, 19, 28):
        s.raw(f'<path d="M{x - r * 0.7:.1f},{y - r * 0.7:.1f} A{r},{r} 0 0 1 {x + r * 0.7:.1f},{y - r * 0.7:.1f}" fill="none" stroke="{color}" stroke-width="3" stroke-linecap="round"/>')
    s.circ(x, y, 3.5, color, color, 0)


def flow(s, x, y, steps, color="#333", fill="#eef2f6", w=None):
    """Left-to-right flow strip: list of (title, subtitle)."""
    cx = x
    for i, (a, b) in enumerate(steps):
        bw = w or max(120, 9 * max(len(a), len(b)) + 26)
        s.rect(cx, y, bw, 46, fill, color, 1.8, 8)
        s.text(cx + bw / 2, y + 19, a, 13, "bold", "middle")
        s.text(cx + bw / 2, y + 36, b, 11.5, anchor="middle", fill="#444")
        cx += bw
        if i < len(steps) - 1:
            s.line(cx + 3, y + 23, cx + 27, y + 23, color, 2.5, arrow="arr")
            cx += 32


def table(s, x, y, cols, rows, widths, size=13, rh=22, swatch=None):
    s.rect(x, y, sum(widths), rh, "#dfe6ee", "#333", 1.2, 0)
    cx = x
    for c, w in zip(cols, widths):
        s.text(cx + 6, y + 16, c, size, "bold")
        cx += w
    for r, row in enumerate(rows):
        yy = y + rh * (r + 1)
        s.rect(x, yy, sum(widths), rh, "#ffffff" if r % 2 else "#f7f9fb", "#b8c2cc", 0.8, 0)
        cx = x
        for i, (c, w) in enumerate(zip(row, widths)):
            if swatch is not None and i == swatch:
                col, thin = c
                if col == NEU:
                    s.line(cx + 6, yy + 11, cx + 46, yy + 11, "#111", 8 if not thin else 6)
                s.line(cx + 6, yy + 11, cx + 46, yy + 11, col, 5 if not thin else 3)
            else:
                s.text(cx + 6, yy + 16, c, size)
            cx += w


# ====================================================================== sheet 1
def sheet_ac(path):
    s = Sheet(1800, 1500, "Sheet 1 of 3 — AC mains wiring (120 V)",
              "Reflow oven controller v12.1. Schematic, not to scale. Every wire has a tag (A1…A15) that matches the table. "
              "UNPLUG the cord before touching anything on this sheet.")
    flow(s, 30, 84, [("Wall outlet", "120 V AC"), ("Inlet", "15 A fuse + rocker"), ("HOT Wago", "splits the feed"),
                     ("Shelly relay", "safety cut-off"), ("SSR", "pulsed by the ESP32"), ("CT clamp", "meter reads amps"),
                     ("Oven socket", "NEMA 5-15R"), ("Oven", "heating elements")], color="#b22222", fill="#fdeeee")

    # enclosure outline (AC bay)
    s.rect(20, 150, 1480, 960, "none", "#9aa5b1", 2, 12, dash="10,6")
    s.text(36, 1100, "AC BAY of the enclosure (mains). The DROK meter and the KP200 sit in the lid above this bay.", 13, "bold", fill="#b22222")

    # devices
    wall_plug(s, 60, 200)
    inlet(s, 40, 360)
    s.wire([(95, 256), (95, 300), (72, 300), (72, 360)], "#333", 9)   # cord into the inlet
    for (ty, lab) in ((420, "L"), (460, "N"), (500, "E")):
        s.term(280, ty, "", "r")
        s.text(294, ty - 12, lab, 13, "bold")
    wh = wago(s, 380, 215, 5, "HOT", "#1a1a1a")
    wn = wago(s, 380, 500, 5, "NEUTRAL", "#8a8a8a")
    wg = wago(s, 380, 800, 5, "GROUND", GND)
    shelly(s, 640, 165)
    s.term(640, 215, "L", "r", color="#fff"); s.term(640, 290, "N", "r", color="#fff"); s.term(840, 215, "O", "l", color="#fff")
    t = ssr(s, 1030, 180)
    s.term(*t["T1"], "1  T1", "b"); s.term(*t["T2"], "2  T2", "b")
    s.term(*t["T3"], "3 +", "t", color="#888"); s.term(*t["T4"], "4 −", "t", color="#888")
    s.text(1110, 426, "1 / 2 = AC end, toward the KP200", 12, "bold", "middle")
    s.text(1110, 443, "3 / 4 = control input: see sheet 2", 12, anchor="middle", fill="#666")
    s.circ(985, 380, 9, "#d9d9d9", "#111", 2); s.circ(985, 380, 3.5, "#555", "#111", 1)
    s.text(985, 404, "ring", 11, "bold", "middle"); s.text(985, 417, "lug", 11, "bold", "middle")
    kp200(s, 640, 480)
    for ty, lab in ((530, "Line"), (590, "Neutral"), (650, "Ground")):
        s.term(640, ty, lab, "r", 11)
    usb_adapter(s, 836, 608)
    s.text(872, 684, "USB adapter in the", 11.5, anchor="middle", fill="#444")
    s.text(872, 698, "bottom socket", 11.5, anchor="middle", fill="#444")
    s.text(735, 456, "Kasa KP200 smart outlet", 13, "bold", "middle")
    s.text(735, 473, "in the lid · always live · top socket blanked", 11.5, anchor="middle", fill="#444")
    socket(s, 1290, 640)
    s.term(1345, 640, "", "t"); s.text(1362, 662, "HOT", 11, "bold", fill="#fff")
    s.term(1290, 710, "", "l"); s.text(1302, 714, "N", 12, "bold", fill="#fff")
    s.term(1290, 770, "", "l"); s.text(1302, 774, "G", 12, "bold", fill="#fff")
    s.text(1375, 830, "Oven socket · left wall", 12.5, "bold", "middle")
    s.note(1292, 848, ["HOT = narrow slot, brass screw", "N = wide slot, silver screw", "G = round hole, green screw"], 11.5, "#444", 15)
    oven(s, 1540, 640)
    s.wire([(1540, 760), (1505, 760), (1505, 725), (1462, 725)], "#333", 9)
    s.rect(1454, 706, 26, 38, "#2b2b2b", "#111", 2, 4)
    s.text(1665, 850, "Leave the oven's own thermostat", 12, anchor="middle", fill="#444")
    s.text(1665, 866, "at MAX and its timer on stay-on.", 12, anchor="middle", fill="#444")
    drok(s, 880, 830)
    s.rect(900, 984, 250, 46, "#2e9e4f", "#14592a", 2, 3)
    for tx, lab in ((930, "L"), (980, "N"), (1070, "CT"), (1120, "CT")):
        s.term(tx, 1014, "", "b")
        s.text(tx, 1000, lab, 11, "bold", "middle", "#fff")
    s.text(888, 1004, "rear terminal block", 12, "bold", "end")
    s.text(888, 1020, "(use the labels on the meter)", 12, anchor="end", fill="#444")
    s.text(1030, 822, "DROK meter · snaps into the lid", 12.5, "bold", "middle")

    # wires
    s.wire([(280, 420), (322, 420), (322, wh[2]), (380, wh[2])], HOT, tag="A1", tagpos=(322, 350))
    s.wire([(470, wh[0]), (580, wh[0]), (580, 215), (640, 215)], HOT, tag="A2", tagpos=(525, wh[0]))
    s.wire([(470, wh[1]), (600, wh[1]), (600, 530), (640, 530)], HOT, tag="A3", tagpos=(600, 400))
    s.wire([(280, 460), (342, 460), (342, wn[2]), (380, wn[2])], NEU, tag="A5", tagpos=(342, 520))
    s.wire([(470, wn[0]), (555, wn[0]), (555, 290), (640, 290)], NEU, tag="A6", tagpos=(555, 400))
    s.wire([(470, wn[1]), (575, wn[1]), (575, 590), (640, 590)], NEU, tag="A7", tagpos=(520, wn[1]))
    s.wire([(470, wn[2]), (505, wn[2]), (505, 760), (1210, 760), (1210, 710), (1290, 710)], NEU, tag="A8", tagpos=(760, 760))
    s.wire([(280, 500), (305, 500), (305, wg[2]), (380, wg[2])], GND, tag="A10", tagpos=(305, 700))
    s.wire([(470, wg[0]), (612, wg[0]), (612, 650), (640, 650)], GND, tag="A11", tagpos=(500, wg[0]))
    s.wire([(470, wg[1]), (530, wg[1]), (530, 795), (1230, 795), (1230, 770), (1290, 770)], GND, tag="A12", tagpos=(1000, 795))
    s.wire([(470, wg[2]), (550, wg[2]), (550, 725), (950, 725), (950, 380), (976, 380)], GND, tag="A13", tagpos=(950, 560))
    s.wire([(840, 215), (905, 215), (905, 146), (t["T1"][0], 146), t["T1"]], HOT, tag="A14", tagpos=(985, 146))
    s.wire([t["T2"], (t["T2"][0], 146), (1345, 146), (1345, 640)], HOT, tag="A15", tagpos=(1345, 560))
    # meter sense leads (thin) and CT
    s.wire([(380, wh[4]), (362, wh[4]), (362, 1050), (930, 1050), (930, 1014)], HOT, 3.5, tag="A4", tagpos=(640, 1050))
    s.wire([(380, wn[4]), (350, wn[4]), (350, 1072), (980, 1072), (980, 1014)], NEU, 3.5, tag="A9", tagpos=(760, 1072))
    ct(s, 1345, 440)
    s.wire([(1311, 448), (1262, 448), (1262, 1052), (1070, 1052), (1070, 1014)], RED, 2.5)
    s.wire([(1311, 436), (1250, 436), (1250, 1068), (1120, 1068), (1120, 1014)], BLK, 2.5, tag="CT", tagpos=(1256, 930))
    s.text(1392, 420, "Split-core CT", 13, "bold")
    s.note(1392, 438, ["clip around A15 ONLY", "(oven hot wire), never", "around hot + neutral", "together (reads 0 A)"], 11.5, lh=16)

    # wire table
    S, T = False, True
    rows = [
        ["A1", (HOT, S), "Inlet L (fused, switched)", "HOT Wago", "14 AWG black"],
        ["A2", (HOT, S), "HOT Wago", "Shelly L", "14 AWG black"],
        ["A3", (HOT, S), "HOT Wago", "KP200 Line", "14 AWG black"],
        ["A4", (HOT, T), "HOT Wago", "DROK meter L (voltage sense)", "18 AWG black, 600 V"],
        ["A5", (NEU, S), "Inlet N", "NEUTRAL Wago", "14 AWG white"],
        ["A6", (NEU, S), "NEUTRAL Wago", "Shelly N", "14 AWG white"],
        ["A7", (NEU, S), "NEUTRAL Wago", "KP200 Neutral", "14 AWG white"],
        ["A8", (NEU, S), "NEUTRAL Wago", "Oven socket neutral (wide slot)", "14 AWG white"],
    ]
    rows2 = [
        ["A9", (NEU, T), "NEUTRAL Wago", "DROK meter N", "18 AWG white, 600 V"],
        ["A10", (GND, S), "Inlet E", "GROUND Wago", "14 AWG green"],
        ["A11", (GND, S), "GROUND Wago", "KP200 Ground", "14 AWG green"],
        ["A12", (GND, S), "GROUND Wago", "Oven socket ground", "14 AWG green"],
        ["A13", (GND, S), "GROUND Wago", "Heatsink ring lug", "14 AWG green"],
        ["A14", (HOT, S), "Shelly O", "SSR terminal 1 (T1)", "14 AWG black"],
        ["A15", (HOT, S), "SSR terminal 2 (T2)", "Oven socket hot — THROUGH THE CT", "14 AWG black"],
        ["CT", (RED, T), "CT leads (as supplied)", "DROK meter CT terminals", "meter's own leads"],
    ]
    cols = ["Tag", "Wire", "From", "To", "Wire type"]
    wd = [48, 58, 230, 300, 210]
    s.text(30, 1150, "Wire list", 18, "bold")
    table(s, 30, 1162, cols, rows, wd, swatch=1)
    table(s, 30 + sum(wd) + 28, 1162, cols, rows2, wd, swatch=1)
    s.note(30, 1382, [
        "• Wagos: strip 11 mm, push the wire fully in, close the lever, tug-test. The HOT junction now carries 4 wires, so it needs a 5-port 221-415 like the other two (one port spare).",
        "• SSR: stranded wire twisted, NOT tinned, fully under the clamp plate. Shelly: one wire per terminal, strip 6-7 mm, 0.4 N·m. KP200 is fed from the Wago, never from the Shelly.",
        "• Meter leads A4 / A9 carry almost no current, but they sit behind the 15 A fuse: use 600 V rated wire, keep them short and clear of the heatsink. If the amps read 0 or the watts look wrong, turn the CT around.",
        "• A15 is the only wire the CT goes on: the meter then shows what the OVEN draws (about 9.6 A / 1150 W while the SSR is on, pulsing during a run). Volts show whenever the rocker is on.",
        "• Before first power: cord unplugged, check continuity from the inlet ground pin to the socket ground, KP200 ground and heatsink, and no continuity between L, N and E.",
    ], 13, lh=21)
    s.save(path)


# ====================================================================== sheet 2
def sheet_lv(path):
    s = Sheet(1800, 1400, "Sheet 2 of 3 — Low-voltage and signal wiring (3.3 V / 5 V)",
              "Controller, temperature sensor, SSR drive, USB power and the Wi-Fi safety link. Tags D1…D7 match the table. "
              "Grove cable colours shown are the usual ones: confirm each wire against the pin with a meter.")
    flow(s, 30, 84, [("K thermocouple", "in the oven"), ("MAX6675", "reads °C every 250 ms"), ("ESP32", "profile + PID"),
                     ("IO32 pulls low", "2 s slow-PWM"), ("SSR input", "LED on = heating")],
         color="#1f5fa8", fill="#eef5ff")
    flow(s, 1040, 84, [("ESP32 Wi-Fi", "every 15 s: stay on 30 s"), ("Shelly relay", "opens if the pings stop")],
         color="#1f5fa8", fill="#eef5ff")

    # enclosure
    s.rect(40, 170, 1330, 880, "none", "#9aa5b1", 2, 12, dash="10,6")
    s.rect(446, 172, 12, 338, "#6b7480", "#444", 1, 0)
    s.rect(446, 600, 12, 448, "#6b7480", "#444", 1, 0)
    s.text(60, 196, "AC BAY (mains: sheet 1)", 14, "bold", fill="#b22222")
    s.text(480, 196, "DC BAY (3.3 V / 5 V only)", 14, "bold", fill=BLUE)
    s.text(372, 531, "U-slot in the divider (the only crossing)", 12, "bold", fill="#333")
    s.text(1372, 1040, "right wall", 12, "bold", "end", "#555")

    # CrowPanel
    X, Y = 720, 230
    w, h = crowpanel(s, X, Y)
    by = Y + h
    j7 = hy_conn(s, X + 30, by, "J7", "GPIO_D", [1, 2, 3, 4])
    j10 = hy_conn(s, X + 200, by, "J10", "UART1", [1, 2, 3, 4])
    j6 = hy_conn(s, X + 370, by, "J6", "IIC", [1, 2, 3, 4])
    s.note(X, Y - 32, ["Find J7 / J10 / J6 by the names printed on the board (GPIO_D, UART1, IIC).", "Their order along the edge may differ from this drawing."], 12, "#444", 16)

    # SSR in the AC bay (DC end toward the divider)
    t = ssr(s, 150, 470, heatsink=False)
    s.rect(100, 450, 260, 230, "url(#fins)", "#6f7780", 2, 4)
    t = ssr(s, 150, 470, heatsink=False)
    s.term(*t["T3"], "3 +", "t"); s.term(*t["T4"], "4 −", "t")
    s.term(*t["T1"], "1", "b", color="#999"); s.term(*t["T2"], "2", "b", color="#999")
    s.text(230, 702, "SSR control end (3 / 4) faces the divider", 12, "bold", "middle")
    s.text(230, 720, "terminals 1 / 2 are mains: sheet 1", 12, anchor="middle", fill="#666")

    # MAX6675
    mx = max6675(s, 1026, 760)
    s.text(1282, 800, "MAX6675 module", 14, "bold")
    s.text(1282, 818, "DC floor", 12, fill="#444")
    s.term(1066, 880, "", "b"); s.term(1106, 880, "", "b")
    s.text(1046, 912, "+", 16, "bold", "middle"); s.text(1126, 912, "−", 16, "bold", "middle")

    # Oven with probe
    oven(s, 1500, 760)
    s.wire([(1066, 880), (1066, 970), (1420, 970), (1420, 846), (1560, 846)], YEL, 3.5)
    s.wire([(1106, 880), (1106, 958), (1408, 958), (1408, 834), (1560, 834)], RED, 3.5)
    s.rect(1560, 828, 60, 24, "#b9c0c8", "#555", 1.5, 10)
    s.circ(1624, 840, 7, "#e9e9e9", "#555", 2)
    s.text(1240, 946, "K thermocouple: yellow +, red −", 12.5, "bold", "middle")
    s.text(1240, 992, "passes through the round hole in the right wall", 12, anchor="middle", fill="#444")
    s.text(1640, 960, "Probe tip in the middle of the", 12, anchor="middle", fill="#444")
    s.text(1640, 976, "oven, next to the board, in air.", 12, anchor="middle", fill="#444")

    # SSR drive wires through the U-slot
    s.wire([(j7[1], by), (j7[1], 680), (520, 680), (520, 574), (400, 574), (400, t["T4"][1] + 40), (t["T4"][0], t["T4"][1] + 40), t["T4"]],
           WHT, 4, tag="D1", tagpos=(640, 680))
    s.wire([(j7[2], by), (j7[2], 656), (540, 656), (540, 556), (380, 556), (380, t["T3"][1]), t["T3"]],
           RED, 4, tag="D2", tagpos=(690, 656))
    s.rect(392, 540, 140, 48, "none", "#e67e22", 3, 10, dash="7,4")
    s.text(462, 606, "", 11)
    s.note(470, 712, ["Sleeve D1 + D2 in 600 V", "heat-shrink from the slot", "to the SSR."], 12, "#b85c00", weight="bold")
    for px, lab in ((j7[0], "IO25"), (j7[3], "GND")):
        s.line(px, by, px, by + 26, "#999", 3)
        s.rect(px - 7, by + 22, 14, 22, "#555", "#222", 1, 3)
    s.text(j7[0] - 20, by + 50, "J7: cap pins 1 and 4.", 12, "bold", "end", "#b22222")
    s.text(j7[0] - 20, by + 66, "Pin 4 (GND) never on the SSR.", 12, "bold", "end", "#b22222")
    s.text(j7[1] - 8, by + 74, "IO32", 11, "bold", "end", "#333")
    s.text(j7[2] + 9, by + 74, "3V3", 11, "bold", fill="#333")

    # MAX6675 wires
    s.wire([(j10[0], by), (j10[0], 705), (mx["SO"], 705), (mx["SO"], 752)], YEL, 4, tag="D7", tagpos=(1000, 705))
    for px in j10[1:]:
        s.line(px, by, px, by + 26, "#999", 3)
        s.rect(px - 7, by + 22, 14, 22, "#555", "#222", 1, 3)
    s.text(j10[2], by + 62, "pins 2-4: cap", 12, "bold", "middle", "#b22222")
    lv = [(j6[0], "CS", YEL, "D3", 690), (j6[1], "SCK", WHT, "D4", 670), (j6[2], "VCC", RED, "D5", 645), (j6[3], "GND", BLK, "D6", 620)]
    for px, n, col, tag, lvl in lv:
        s.wire([(px, by), (px, lvl), (mx[n] + 0, lvl), (mx[n], 752)] if abs(px - mx[n]) > 2 else [(px, by), (px, 752)],
               col, 4, tag=tag, tagpos=(mx[n], 726))
    s.text(j6[3] + 26, by + 24, "1 IO21 · 2 IO22", 12, "bold", fill="#333")
    s.text(j6[3] + 26, by + 40, "3 3V3 · 4 GND", 12, "bold", fill="#333")
    s.text(j10[0] - 10, by + 74, "IO16", 11, "bold", "end", "#333")

    # USB power from the KP200 (outside the box)
    kp200(s, 150, 228, 150, 170)
    s.text(225, 222, "KP200 in the lid (mains: sheet 1)", 12, "bold", "middle")
    usb_adapter(s, 318, 318)
    s.wire([(353, 318), (353, 156), (1420, 156), (1420, Y + 172), (X + w + 4, Y + 172)], "#555", 5, tag="USB", tagpos=(600, 156))
    s.text(640, 148, "USB-A to USB-C cable, 5 V. Runs OUTSIDE the box and enters through the slot in the right wall.", 12.5, fill="#333")
    s.rect(1364, Y + 152, 14, 40, "#fff", "#555", 2, 3)

    # Wi-Fi link to the Shelly
    s.rect(110, 800, 200, 150, "#1c3f6e", "#0d2240", 2.5, 22)
    s.text(210, 862, "Shelly", 22, "bold", "middle", "#fff")
    s.text(210, 886, "1PM Gen4", 15, "bold", "middle", "#cfe0f5")
    s.text(210, 912, "runs reflow_supervisor.js", 11.5, anchor="middle", fill="#cfe0f5")
    wifi(s, 330, 800); wifi(s, X - 34, Y + 60)
    s.raw(f'<path d="M352,780 C470,700 560,420 {X - 50},{Y + 62}" fill="none" stroke="{BLUE}" stroke-width="3" stroke-dasharray="3,9" stroke-linecap="round"/>')
    s.note(470, 850, ["Wi-Fi (no wire):", "ESP32 → Shelly, every 15 s:", "Switch.Set on, toggle_after=30", "Board hangs → relay opens", "by itself 30 s later."], 12.5, BLUE, weight="bold")

    # table
    cols = ["Tag", "Wire", "CrowPanel pin", "Signal", "Goes to", "Typical Grove colour"]
    wd = [50, 58, 190, 200, 280, 200]
    rows = [
        ["D1", (WHT, True), "J7 pin 2", "IO32 (pulls LOW = heat)", "SSR terminal 4 (−)", "white"],
        ["D2", (RED, True), "J7 pin 3", "3V3", "SSR terminal 3 (+)", "red"],
        ["D3", (YEL, True), "J6 pin 1", "IO21 → CS", "MAX6675 CS", "yellow"],
        ["D4", (WHT, True), "J6 pin 2", "IO22 → SCK", "MAX6675 SCK", "white"],
        ["D5", (RED, True), "J6 pin 3", "3V3", "MAX6675 VCC", "red"],
        ["D6", (BLK, True), "J6 pin 4", "GND", "MAX6675 GND", "black"],
        ["D7", (YEL, True), "J10 pin 1", "IO16 ← SO", "MAX6675 SO", "yellow"],
        ["USB", ("#555", True), "USB-C", "5 V power + programming", "USB adapter in the KP200", "USB-A to C cable"],
    ]
    s.text(40, 1100, "Wire list", 18, "bold")
    table(s, 40, 1112, cols, rows, wd, swatch=1)
    s.note(1050, 1128, [
        "• Three Grove (HY2.0-4P) to DuPont cables: one each for J7, J6, J10.",
        "• The SSR is switched on its − side: 3V3 goes to terminal 3 (+) and IO32",
        "  sinks terminal 4 (−). A 1 kΩ pull-up on the board keeps it OFF at reset.",
        "• Grove wires are thin: fold the stripped end double or crimp a ferrule",
        "  before clamping it under an SSR screw.",
        "• Unused ends (J7 pins 1, 4 and J10 pins 2-4): heat-shrink each one.",
        "• Bench test with USB power only, no mains: the SSR LED must stay off",
        "  through reset, and light when the firmware calls for heat.",
        "• MAX6675 header order differs between modules: go by its printed labels.",
    ], 13, lh=21)
    s.save(path)


# ====================================================================== sheet 3
def sheet_layout(path, ko):
    s = Sheet(1800, 1560, "Sheet 3 of 3 — Where everything sits (to scale) and how to get at it",
              "Enclosure v12.1, 250 x 155 x 83 mm. Dimensions in mm, from the OpenSCAD model and its verified keep-out boxes. "
              "View A is from above, standing at the front panel.")
    K = 5.0
    ox, oy = 60, 150

    def px(x):   # plan: +X is on the viewer's left when standing at the front
        return ox + (250 - x) * K

    def py(y):   # rear wall at the top, front panel at the bottom
        return oy + y * K

    def prect(x0, y0, x1, y1, fill, stroke="#333", sw=1.5, dash=None, op=None, rx=3):
        s.rect(px(x1), py(y0), (x1 - x0) * K, (y1 - y0) * K, fill, stroke, sw, rx, dash, op)

    def plabel(x0, y0, x1, y1, lines, size=12.5, fill="#111", weight="bold"):
        cx, cy = px((x0 + x1) / 2), py((y0 + y1) / 2) - (len(lines) - 1) * 8 + 4
        for i, t in enumerate(lines):
            s.text(cx, cy + i * 16, t, size, weight if i == 0 else "normal", "middle", fill)

    s.text(ox, oy - 14, "A. Top view, lid removed (lid-mounted parts shown as dashed outlines)", 16, "bold")
    prect(0, 0, 250, 155, "#f3f5f7", "#333", 3, rx=6)
    prect(3, 3, 247, 152, "#ffffff", "#999", 1)
    prect(156, 0, 158, 152, "#6b7480", "#444", 1)
    prect(0, 152, 250, 155, "#44505c", "#222", 1)
    s.text(px(125), py(155) + 20, "FRONT PANEL (display side)  —  you stand here", 13, "bold", "middle")
    s.text(px(60), py(0) + 12, "REAR WALL", 11, "bold", "middle", "#555")
    s.text(px(250) - 8, py(77), "RIGHT WALL: USB-C slot + thermocouple hole", 12, "bold", "middle", "#555", rot=-90)
    s.text(px(0) + 16, py(77), "LEFT WALL: oven socket", 12, "bold", "middle", "#555", rot=90)
    s.text(px(45), py(10) + 5, "AC BAY", 14, "bold", "middle", "#b22222")
    s.text(px(203), py(10) + 5, "DC BAY", 14, "bold", "middle", BLUE)

    def k(n):
        return ko[n]
    (x0, y0, z0), (x1, y1, z1) = k("heatsink"); prect(x0, y0, x1, y1, "url(#fins)", "#6f7780"); plabel(x0, y0, x1, y1, ["Heatsink", "fins front-to-back, top at z 54"])
    (x0, y0, z0), (x1, y1, z1) = k("ssr"); prect(x0, y0, x1, y1, "#f2f2f2", "#222", 2); plabel(x0, y0, x1, y1, ["SSR-40DA"])
    s.text(px(140), py(86), "1 2", 11, "bold", "middle", "#b22222"); s.text(px(88), py(86), "3 4", 11, "bold", "middle", BLUE)
    (x0, y0, z0), (x1, y1, z1) = k("ssr_wiring_zone"); prect(x0, y0, x1, y1, "#fff4d6", "#c79a1e", 1, "5,4"); s.text(px(92), py(69.5), "SSR wire bends", 10.5, anchor="middle", fill="#7a5c00")
    (x0, y0, z0), (x1, y1, z1) = k("inlet"); prect(x0, y0, x1, y1, "#262626", "#111", 2); plabel(x0, y0, x1, y1 - 14, ["FILSHU inlet", "body + wire space", "z 17-45 (under the meter)"], 12, "#fff")
    (x0, y0, z0), (x1, y1, z1) = k("oven_socket"); prect(x0, y0, x1, y1, "#2a2a2a", "#111", 2); plabel(x0, y0, x1, y1, ["Oven", "socket"], 12, "#fff")
    (x0, y0, z0), (x1, y1, z1) = k("shelly"); prect(x0, y0, x1, y1, "#1c3f6e", "#0d2240", 2); s.text(px(11.6), py(86), "Shelly 1PM", 12, "bold", "middle", "#fff", rot=90)
    (x0, y0, z0), (x1, y1, z1) = k("max6675"); prect(x0, y0, x1, y1, "#1b4fa0", "#0d2a59", 2); plabel(x0, y0 - 12, x1, y0, ["MAX6675"], 12)
    (x0, y0, z0), (x1, y1, z1) = k("crow_pcb"); prect(x0, y0, x1, y1, "#12233a", "#0a1322", 2); plabel(x0, y0 - 16, x1 - 40, y0 - 8, ["CrowPanel"], 12)
    prect(36, 13, 78, 45, "#e9f7ee", "#1a8f3a", 2, "6,4"); plabel(36, 13, 78, 45, ["CT clamp + Wagos", "lie here on the floor", "(42 x 32, free to z 35)"], 11.5, "#14592a")
    prect(64, 6, 96, 14, "none", "none", 0)
    for bx_, by_ in ((10, 10), (80, 10), (10, 55), (168, 10), (237, 10)):
        s.circ(px(bx_), py(by_), 4.25 * K, "#dfe4ea", "#555", 1.5); s.circ(px(bx_), py(by_), 1.6 * K, "#fff", "#555", 1)
    # lid-mounted parts (dashed)
    (x0, y0, z0), (x1, y1, z1) = k("kp200_body"); prect(x0, y0, x1, y1, "#f1f1f1", "#555", 2, "7,4", 0.75); plabel(x0, y0 + 36, x1, y1, ["KP200 body", "hangs from the lid", "z 35-80"], 12)
    prect(5, 17, 90, 146, "none", "#555", 1.5, "3,5")
    s.text(px(47.5), py(140), "KP200 faceplate on top of the lid (85 x 129)", 11, anchor="middle", fill="#555")
    (x0, y0, z0), (x1, y1, z1) = k("drok_meter")
    mcx, mcy = (x0 + x1) / 2, (y0 + y1) / 2
    prect(mcx - 24, mcy - 38.25, mcx + 24, mcy + 38.25, "none", "#b22222", 2, "3,5")
    prect(x0, y0, x1, y1, "#4a90d9", "#b22222", 3.5, "8,4", 0.22)
    s.rect(px(x1) + 6, py(52.5), (x1 - x0) * K - 12, 17 * K, "#ffffff", "#b22222", 1.5, 5, op=0.92)
    plabel(x0, 52.5, x1, 69.5, ["DROK meter (in the lid)", "body 45 x 73.4, z 58.5-80", "face 48 x 76.5 on top"], 12, "#8a1010")
    # vents
    for i in range(6):
        vy = 122.3 - 15 + i * 6 - 1.5
        prect(80, vy, 146, vy + 3, "none", "#888", 1, "2,3", rx=1)
    s.text(px(113), py(101.5), "lid vent slots above the heatsink", 10.5, anchor="middle", fill="#555")

    # dimensions on plan
    def hdim(xa, xb, y, lab, above=True):
        s.line(px(xa), py(y), px(xb), py(y), "#b22222", 1.5, arrow="arr")
        s.line(px(xb), py(y), px(xa), py(y), "#b22222", 1.5, arrow="arr")
        s.text((px(xa) + px(xb)) / 2, py(y) + (-5 if above else 15), lab, 11.5, "bold", "middle", "#b22222")

    hdim(90, 106, 76, "16", True)
    s.line(px(149), py(80.5), px(149), py(105.8), "#b22222", 1.5, arrow="arr"); s.line(px(149), py(105.8), px(149), py(80.5), "#b22222", 1.5, arrow="arr")
    s.text(px(149) + 7, py(100), "25 to vents", 11, "bold", fill="#b22222")

    # wire run arrows (plan)
    def run(pts, col, lab=None, lpos=None):
        d = " ".join(f"{px(x):.0f},{py(y):.0f}" for x, y in pts)
        s.raw(f'<polyline points="{d}" fill="none" stroke="{col}" stroke-width="3.5" stroke-dasharray="2,7" stroke-linecap="round"/>')
        s.circ(px(pts[-1][0]), py(pts[-1][1]), 5, col, col, 0)
        if lab:
            s.text(px(lpos[0]), py(lpos[1]), lab, 11, "bold", "middle", col)

    run([(96, 49), (86, 49), (76, 40)], "#111")
    s.text(px(86), py(47), "inlet → Wagos", 10.5, "bold", "middle")
    run([(19.6, 74), (30, 71), (82, 71)], "#111", "Shelly O → SSR 1", (50, 75))
    run([(82, 63), (58, 63), (55, 45), (35, 36)], "#111", "SSR 2 → CT → socket hot", (52, 61))
    run([(144, 84), (158, 84), (166, 110), (170, 138)], BLUE)
    s.text(px(186), py(106), "SSR 3/4 → J7", 11, "bold", "middle", BLUE)
    s.text(px(186), py(110), "through the U-slot", 10.5, anchor="middle", fill=BLUE)
    run([(186, 38), (212, 60), (212, 138)], BLUE)
    s.text(px(228), py(84), "MAX6675", 11, "bold", "middle", BLUE)
    s.text(px(228), py(88), "→ J6 / J10", 11, "bold", "middle", BLUE)

    # ---------------------------------------------------------------- section
    sx, sy = 60, 1010
    Ks = 5.2

    def qy(y):
        return sx + y * Ks

    def qz(z):
        return sy + (95 - z) * Ks

    def qrect(y0, z0, y1, z1, fill, stroke="#333", sw=1.5, dash=None, op=None):
        s.rect(qy(y0), qz(z1), (y1 - y0) * Ks, (z1 - z0) * Ks, fill, stroke, sw, 2, dash, op)

    s.text(sx, sy - 14, "B. Side section through the meter (cut at X = 130, looking from the divider toward the left wall)", 16, "bold")
    qrect(0, 0, 152, 3, "#c9d1d9"); qrect(0, 0, 3, 80, "#c9d1d9"); qrect(152, 0, 155, 80, "#44505c")
    qrect(0, 80, 155, 83, "#c9d1d9", "#333", 2)
    (x0, y0, z0), (x1, y1, z1) = k("drok_meter")
    s.rect(qy(y0 - 0.3), qz(83.2), (y1 - y0 + 0.6) * Ks, 3.4 * Ks, "#ffffff", "#ffffff", 0, 0)   # cutout through the lid
    for i in range(6):
        vy = 122.3 - 15 + i * 6 - 1.5
        s.rect(qy(vy), qz(83.2), 3 * Ks, 3.4 * Ks, "#ffffff", "#ffffff", 0, 0)
    (a0, b0, c0), (a1, b1, c1) = k("inlet"); qrect(0, c0, b0 + 28, c1, "#262626", "#111", 2); qrect(b0 + 28, c0, b1, c1, "#555", "#111", 1, "4,3", 0.5)
    s.text(qy(17), qz(29), "Inlet body", 12, "bold", "middle", "#fff"); s.text(qy(41), qz(29), "its wires", 11, anchor="middle", fill="#fff")
    (a0, b0, c0), (a1, b1, c1) = k("ssr_wiring_zone"); qrect(b0, c0, b1, c1, "#fff4d6", "#c79a1e", 1, "5,4"); s.text(qy((b0 + b1) / 2), qz(28), "SSR wire", 11.5, "bold", "middle", "#7a5c00"); s.text(qy((b0 + b1) / 2), qz(24), "bends", 11.5, "bold", "middle", "#7a5c00")
    (a0, b0, c0), (a1, b1, c1) = k("ssr"); qrect(b0, c0, b1, c1, "#f2f2f2", "#222", 2); s.text(qy((b0 + b1) / 2), qz(28), "SSR", 13, "bold", "middle")
    (a0, b0, c0), (a1, b1, c1) = k("heatsink"); qrect(b0, c0, b1, c1, "url(#fins)", "#6f7780", 2); s.text(qy((b0 + b1) / 2), qz(28), "Heatsink", 13, "bold", "middle")
    qrect(y0, z0, y1, z1, "#0b2a5c", "#b22222", 2.5)
    qrect(y0 - 1.57, 83, y1 + 1.57, 85.5, "#1d1d1d", "#000", 2)
    (a0, b0, c0), (a1, b1, c1) = k("drok_terminals"); qrect(b0, c0, b1, c1, "#e9f7ee", "#1a8f3a", 1.5, "5,4")
    s.text(qy((y0 + y1) / 2), qz(70.5), "DROK meter body 21.5 deep", 12.5, "bold", "middle", "#fff")
    s.text(qy((y0 + y1) / 2), qz(66), "snaps in from above, clips grip the lid", 11.5, anchor="middle", fill="#cfe0f5")
    s.text(qy(36), qz(53.5), "7 mm: screw heads + wires", 11, "bold", "middle", "#14592a")
    s.text(qy((y0 + y1) / 2), qz(88), "face 76.5 long, sits on top of the lid", 11.5, "bold", "middle")
    s.text(qy(122), qz(88), "vent slots", 11.5, anchor="middle", fill="#555")
    s.text(qy(77), qz(-5.5), "floor", 11, anchor="middle", fill="#555")
    s.text(qy(-2), qz(40), "rear wall", 11, "bold", "middle", "#555", rot=-90)
    s.text(qy(158.5), qz(40), "front panel", 11, "bold", "middle", "#555", rot=90)

    def vdim(y, za, zb, lab, side=1):
        s.line(qy(y), qz(za), qy(y), qz(zb), "#b22222", 1.5, arrow="arr"); s.line(qy(y), qz(zb), qy(y), qz(za), "#b22222", 1.5, arrow="arr")
        s.text(qy(y) + 7 * side, qz((za + zb) / 2) + 4, lab, 11.5, "bold", "start" if side > 0 else "end", "#b22222")

    vdim(30, 44.75, 51.5, "6.8 clear above the inlet")
    vdim(75, 51, 58.5, "7.5 SSR top to meter", 1)
    vdim(118, 54, 80, "26 heatsink to lid")
    vdim(83.5, 58.5, 80, "21.5", 1)

    # ---------------------------------------------------------------- notes
    nx = 1375
    s.text(nx - 20, 150, "Mounting and orientation", 17, "bold")
    s.note(nx - 20, 176, [
        "DROK meter",
        "• Snaps into a 45.6 x 74.0 mm hole in the lid, from above.",
        "  No screws. Print the cutout coupon first and pick",
        "  the cell it clicks into without rattling.",
        "• Long axis runs front-to-back. Crosswise does not",
        "  fit: only 66 mm between the KP200 faceplate and",
        "  the divider, and the body is 73.4 mm.",
        "• The hole is symmetric, so choose which way it",
        "  reads at assembly: turn it so the digits are",
        "  upright from the side you stand at (left-wall end",
        "  or display end).",
        "• It stays in the AC bay: its L / N terminals are",
        "  mains and must not enter the DC bay.",
        "",
        "CT clamp",
        "• Clips around the SSR 2 → socket hot wire and",
        "  lies on the AC floor between the oven socket and",
        "  the inlet, with the Wagos. Zip-tie it to the wire",
        "  so it cannot wander toward the heatsink.",
        "",
        "Service access",
        "• Everything is reached by lifting the lid",
        "  (9 screws). The meter and KP200 come up with it.",
        "• Leave about 150 mm of slack in the meter's L / N",
        "  and CT leads and the KP200 wires, so the lid can",
        "  be laid on its back beside the box, still wired.",
        "• To remove the meter: lid off, squeeze the two",
        "  side clips, push it out upward.",
        "• Route the meter leads along the rear wall, away",
        "  from the heatsink and clear of the vent slots.",
        "• Display, Grove cables: front panel (6 screws).",
        "",
        "Printing (Bambu X1C, ASA, no supports)",
        "• Lid: outer face down, already mirrored.",
        "  The meter hole is a plain through-cut.",
        "• Only the lid changed from v12.0. The bottom",
        "  shell and front panel are the same parts.",
        "• Checked on the model: no overhang past 45°,",
        "  no part-to-part or part-to-component overlap,",
        "  no straight probe path to a live terminal.",
    ], 12.5, lh=19.5)
    for yy in (176, 176 + 14 * 19.5, 176 + 20 * 19.5, 176 + 32 * 19.5):
        s.rect(nx - 28, yy - 15, 6, 20, "#b22222", "#b22222", 0, 1)

    s.rect(nx - 30, 1010, 400, 300, "#f7f9fb", "#b8c2cc", 1.2, 8)
    s.text(nx - 14, 1036, "Clearances (mm)", 15, "bold")
    table(s, nx - 14, 1048, ["Between", "Gap"], [
        ["Meter body ↔ divider", "3.5"],
        ["Meter body ↔ rear wall", "2.6"],
        ["Meter face ↔ KP200 faceplate", "16"],
        ["Meter face ↔ lid vent slots", "25"],
        ["Meter body ↔ SSR top", "7.5"],
        ["Meter body ↔ inlet top", "13.8"],
        ["Meter body ↔ KP200 body", "37"],
        ["Heatsink top ↔ lid", "26"],
        ["Meter ↔ Shelly", "88"],
    ], [290, 78], 12.5, 24)
    s.save(path)


def read_keepouts(scad_log_lines):
    ko = {}
    for line in scad_log_lines:
        f = line.strip().strip('"').split("|")
        if len(f) == 8 and f[0].endswith("KO"):
            ko[f[1]] = (tuple(map(float, f[2:5])), tuple(map(float, f[5:8])))
    return ko


# Keep-out boxes echoed by the SCAD model (openscad ... 2>&1 | grep "KO|"), v12.1
KEEPOUTS = """KO|heatsink|73|94.6|3|153|144|54
KO|ssr|82|71.1|6|144|94.6|51
KO|ssr_wiring_zone|82|51.1|6|144|71.1|51
KO|inlet|94|3|17.25|142|51|44.75
KO|oven_socket|2.5|16.5|8.5|35|43.5|35.5
KO|shelly|3.6|64.6|3|19.6|106.6|40
KO|kp200_body|25|46.25|35|70|116.75|80
KO|crow_pcb|160.05|140.75|18|245.75|147.9|72
KO|max6675|168|22.5|8|186|37.5|9.6
KO|drok_meter|107.5|5.565|58.53|152.5|78.935|80
KO|drok_terminals|107.5|5.565|51.53|152.5|78.935|58.53""".splitlines()

if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "docs", "wiring")
    os.makedirs(out, exist_ok=True)
    sheet_ac(os.path.join(out, "reflow-wiring-ac-mains.svg"))
    sheet_lv(os.path.join(out, "reflow-wiring-low-voltage.svg"))
    sheet_layout(os.path.join(out, "reflow-layout-clearances.svg"), read_keepouts(KEEPOUTS))
    print("wrote 3 SVG sheets to", out)
