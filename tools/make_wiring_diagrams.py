"""Generate the v13.0 illustrated wiring and layout sheets (SVG).

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
    s.text(x + 100, y + 170, "pocket on the left side wall", 12, anchor="middle", fill="#444")
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
              "Reflow oven controller v13.0. Schematic, not to scale. Every wire has a tag (A1…A15) that matches the table. "
              "UNPLUG the cord before touching anything on this sheet.")
    flow(s, 30, 84, [("Wall outlet", "120 V AC"), ("Inlet", "15 A fuse + rocker"), ("HOT Wago", "splits the feed"),
                     ("Shelly relay", "safety cut-off"), ("SSR", "pulsed by the ESP32"), ("CT clamp", "meter reads amps"),
                     ("Oven socket", "NEMA 5-15R"), ("Oven", "heating elements")], color="#b22222", fill="#fdeeee")

    # enclosure outline (AC bay)
    s.rect(20, 150, 1480, 960, "none", "#9aa5b1", 2, 12, dash="10,6")
    s.text(36, 1100, "MAINS BAY of the enclosure. The DROK meter and the KP200 sit in the lid above it.", 13, "bold", fill="#b22222")

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
    s.text(1110, 426, "1 / 2 = AC end, toward the socket", 12, "bold", "middle")
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
    s.text(1375, 830, "Oven socket · right side wall", 12.5, "bold", "middle")
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
    s.text(60, 196, "MAINS BAY (sheet 1)", 14, "bold", fill="#b22222")
    s.text(480, 196, "DISPLAY POCKET (3.3 / 5 V)", 14, "bold", fill=BLUE)
    s.text(372, 531, "Slot in the pocket wall (the only crossing)", 12, "bold", fill="#333")
    s.text(1372, 1040, "left side wall (seen from the front)", 12, "bold", "end", "#555")

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
    s.text(230, 702, "SSR control end (3 / 4) faces the display pocket", 12, "bold", "middle")
    s.text(230, 720, "terminals 1 / 2 are mains: sheet 1", 12, anchor="middle", fill="#666")

    # MAX6675
    mx = max6675(s, 1026, 760)
    s.text(1282, 800, "MAX6675 module", 14, "bold")
    s.text(1282, 818, "pocket floor, cable-tied", 12, fill="#444")
    s.term(1066, 880, "", "b"); s.term(1106, 880, "", "b")
    s.text(1046, 912, "+", 16, "bold", "middle"); s.text(1126, 912, "−", 16, "bold", "middle")

    # Oven with probe
    oven(s, 1500, 760)
    s.wire([(1066, 880), (1066, 970), (1420, 970), (1420, 846), (1560, 846)], YEL, 3.5)
    s.wire([(1106, 880), (1106, 958), (1408, 958), (1408, 834), (1560, 834)], RED, 3.5)
    s.rect(1560, 828, 60, 24, "#b9c0c8", "#555", 1.5, 10)
    s.circ(1624, 840, 7, "#e9e9e9", "#555", 2)
    s.text(1240, 946, "K thermocouple: yellow +, red −", 12.5, "bold", "middle")
    s.text(1240, 992, "passes through the round hole in the left side wall", 12, anchor="middle", fill="#444")
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
    s.text(640, 148, "USB-A to USB-C cable, 5 V. Runs OUTSIDE the box and enters through the slot in the left side wall.", 12.5, fill="#333")
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
# Model facts used below that are not keep-out boxes (all from the v13.0 SCAD)
BOX_W, BOX_D, BOX_H, SHELL_H, WALL = 184, 140, 83, 80, 3
FP_IN = BOX_D - 3
LV_X0, LV_SIDE = 92, 90                 # pocket interior starts / its side wall starts
LV_LOW, LV_TOP = (104, 106), (118, 120)  # pocket rear wall, lower and upper part (Y)
LV_STEP = (58, 72)                      # the wall leans forward between these heights
POSTS = [(3, 12, 127.6), (79, 92, 127.6), (92, 101, 127), (172, 181, 127)]
LID_SCREWS = [(7.5, 132.3), (83.5, 132.3), (7.5, 7.5), (7.5, 68.5), (82, 7.5), (176.5, 7.5), (176.5, 50), (176.5, 115)]
TIE_ANCHORS = [(48, 20), (80, 20), (100, 84)]
VENT = dict(x0=14, x1=80, yc=105.3, n=6, gap=6, w=3)
INTAKE = dict(x0=15.5, x1=78.5, z0=6, z1=30)
HOLD = dict(x0=10, x1=86.4, y0=80.4, y1=82.8, yend=124, z=54.5)
LID_RIBS = [(86.5, 180.5, 12.6, 15.0), (93, 180, 121.7, 124.1)]   # x0, x1, y0, y1; both 8 mm tall
KP_FACE = (87, 2, 172, 131)
DROK_FACE = (7.75, 14, 84.25, 62)
SADDLE = (133, 106.5, 167, 125.3)


def sheet_layout(path, ko):
    s = Sheet(1800, 2075, "Sheet 3 of 3 — Where everything sits (to scale) and how to get at it",
              "Enclosure v13.0, 184 x 140 x 83 mm. Dimensions in mm, from the OpenSCAD model and its verified keep-out boxes. "
              "Left and right are as you stand at the front panel, facing the display.")
    K = 6.6
    ox, oy = 70, 150

    def px(x):   # plan: model +X is on your left when you stand at the front
        return ox + (BOX_W - x) * K

    def py(y):   # rear wall at the top, front panel at the bottom
        return oy + y * K

    def prect(x0, y0, x1, y1, fill, stroke="#333", sw=1.5, dash=None, op=None, rx=3):
        s.rect(px(x1), py(y0), (x1 - x0) * K, (y1 - y0) * K, fill, stroke, sw, rx, dash, op)

    def plabel(x0, y0, x1, y1, lines, size=12.5, fill="#111", weight="bold"):
        cx, cy = px((x0 + x1) / 2), py((y0 + y1) / 2) - (len(lines) - 1) * 8 + 4
        for i, t in enumerate(lines):
            s.text(cx, cy + i * 16, t, size, weight if i == 0 else "normal", "middle", fill)

    def k(n):
        return ko[n]

    s.text(ox, oy - 14, "A. Top view, lid removed (parts that hang from the lid are dashed)", 16, "bold")
    prect(0, 0, BOX_W, BOX_D, "#f3f5f7", "#333", 3, rx=6)
    prect(3, 3, BOX_W - 3, FP_IN, "#ffffff", "#999", 1)
    # display pocket
    prect(LV_X0, LV_LOW[1], BOX_W - 3, FP_IN, "#eef5ff", "none", 0, rx=0)
    prect(LV_SIDE, LV_LOW[0], BOX_W - 3, LV_LOW[1], "#6b7480", "#444", 1, rx=0)
    prect(LV_SIDE, LV_LOW[0], LV_X0, FP_IN, "#6b7480", "#444", 1, rx=0)
    prect(LV_X0, LV_TOP[0], BOX_W - 3, LV_TOP[1], "none", "#6b7480", 1.2, "5,4", rx=0)
    prect(0, FP_IN, BOX_W, BOX_D, "#44505c", "#222", 1)
    for x0, x1, y0 in POSTS:
        prect(x0, y0, x1, FP_IN, "#aeb7c1", "#555", 1, rx=1)
    s.text(px(BOX_W / 2), py(BOX_D) + 22, "FRONT PANEL  —  you stand here", 13.5, "bold", "middle")
    s.text(px(60), py(0) - 6, "REAR WALL", 11.5, "bold", "middle", "#555")
    s.text(px(BOX_W) - 10, py(62), "LEFT SIDE WALL: USB-C slot + thermocouple hole", 12, "bold", "middle", "#555", rot=-90)
    s.text(px(0) + 18, py(84), "RIGHT SIDE WALL: oven socket", 12, "bold", "middle", "#555", rot=90)

    (x0, y0, z0), (x1, y1, z1) = k("heatsink"); prect(x0, y0, x1, y1, "url(#fins)", "#6f7780"); plabel(x0, y0 + 26, x1, y1, ["Heatsink", "drops into its fence, top at z 54"])
    (x0, y0, z0), (x1, y1, z1) = k("ssr"); prect(x0, y0, x1, y1, "#f2f2f2", "#222", 2); plabel(x0, y0, x1, y1, ["SSR-40DA"])
    s.text(px(x0) - 6, py((y0 + y1) / 2) + 4, "1 2", 11, "bold", "end", "#b22222"); s.text(px(x1) + 6, py((y0 + y1) / 2) + 4, "3 4", 11, "bold", "start", BLUE)
    (x0, y0, z0), (x1, y1, z1) = k("ssr_wiring_zone"); prect(x0, y0, x1, y1, "#fff4d6", "#c79a1e", 1, "5,4")
    (a0, b0, c0), (a1, b1, c1) = k("ssr_ac_wire_channel"); prect(a0, b0, a1, b1, "#ffe9e9", "#b22222", 1, "4,3")
    (a0, b0, c0), (a1, b1, c1) = k("ssr_dc_wire_zone"); prect(a0, b0, a1, b1, "#e8f1ff", BLUE, 1, "4,3")
    (x0, y0, z0), (x1, y1, z1) = k("junction_zone"); prect(x0, y0, x1, y1, "#e9f7ee", "#1a8f3a", 2, "6,4")
    (x0, y0, z0), (x1, y1, z1) = k("inlet"); prect(x0, y0, x1, y0 + 28, "#262626", "#111", 2); prect(x0, y0 + 28, x1, y1, "#777", "#111", 1, "4,3", 0.45)
    plabel(x0, y0, x1, y0 + 28, ["FILSHU inlet", "z 5-33"], 12, "#fff")
    (x0, y0, z0), (x1, y1, z1) = k("oven_socket"); prect(x0, y0, x1, y1, "#2a2a2a", "#111", 2); plabel(x0, y0, x1, y1, ["Oven", "socket"], 12, "#fff")
    (x0, y0, z0), (x1, y1, z1) = k("shelly"); prect(x0, y0, x1, y1, "#1c3f6e", "#0d2240", 2); s.text(px((x0 + x1) / 2) + 4, py((y0 + y1) / 2), "Shelly 1PM", 12, "bold", "middle", "#fff", rot=-90)
    prect(*SADDLE, "#cfd8e3", "#555", 1)
    (x0, y0, z0), (x1, y1, z1) = k("max6675"); prect(x0, y0, x1, y1, "#1b4fa0", "#0d2a59", 2); plabel(x0, y0, x1, y1, ["MAX6675"], 12, "#fff")
    (x0, y0, z0), (x1, y1, z1) = k("crow_pcb"); prect(x0, y0, x1, y1, "#12233a", "#0a1322", 2); plabel(x0, y0, x1, y1, ["CrowPanel on the front panel"], 11.5, "#fff")
    for ax, ay in TIE_ANCHORS:
        prect(ax - 4.5, ay - 2.5, ax + 4.5, ay + 2.5, "#ffffff", "#1a8f3a", 1.5, rx=1)
    for bx_, by_ in LID_SCREWS:
        s.circ(px(bx_), py(by_), 4.0 * K, "#dfe4ea", "#555", 1.5); s.circ(px(bx_), py(by_), 1.6 * K, "#fff", "#555", 1)

    # lid-mounted parts (dashed)
    (x0, y0, z0), (x1, y1, z1) = k("kp200_body"); prect(x0, y0, x1, y1, "#f1f1f1", "#555", 2, "7,4", 0.72); plabel(x0, y0 + 30, x1, y1, ["KP200 body", "hangs from the lid, z 35-80", "inlet wires run underneath"], 12)
    prect(*KP_FACE, "none", "#555", 1.5, "3,5")
    s.text(px(158.5), py(24), "KP200 faceplate", 10.5, "bold", "middle", "#555")
    s.text(px(158.5), py(26.6), "on top of the lid, 85 x 129", 10.5, anchor="middle", fill="#555")
    (x0, y0, z0), (x1, y1, z1) = k("drok_meter")
    prect(*DROK_FACE, "none", "#b22222", 2, "3,5")
    prect(x0, y0, x1, y1, "#4a90d9", "#b22222", 3, "8,4", 0.2)
    s.rect(px(x1) + 14, py(33.6), (x1 - x0) * K - 28, 9.6 * K, "#ffffff", "#b22222", 1.5, 5, op=0.95)
    plabel(x0, 33.6, x1, 43.2, ["DROK meter (in the lid)", "body 73.4 x 45, z 58.5-80", "face 76.5 x 48 on top, reads from the front"], 12, "#8a1010")
    s.text(px(65), py(27.6), "Wagos + CT on the floor", 11.5, "bold", "middle", "#14592a")
    s.text(px(65), py(30.3), "58 x 37, free to z 40", 10.5, anchor="middle", fill="#14592a")
    for i in range(VENT["n"]):
        vy = VENT["yc"] - (VENT["n"] - 1) * VENT["gap"] / 2 + i * VENT["gap"] - VENT["w"] / 2
        prect(VENT["x0"], vy, VENT["x1"], vy + VENT["w"], "none", "#888", 1, "2,3", rx=1)
    s.text(px(47), py(86.8), "lid vent slots", 10.5, anchor="middle", fill="#555")
    # lid ribs
    prect(HOLD["x0"], HOLD["y0"], HOLD["x1"], HOLD["y1"], "#f5c16c", "#a86a00", 1, rx=0, op=0.85)
    prect(HOLD["x1"] - 2.4, HOLD["y0"], HOLD["x1"], HOLD["yend"], "#f5c16c", "#a86a00", 1, rx=0, op=0.85)
    for rx0, rx1, ry0, ry1 in LID_RIBS:
        prect(rx0, ry0, rx1, ry1, "#f5c16c", "#a86a00", 1, rx=0, op=0.85)

    # callouts
    def call(x, y, tx, ty, lines, anchor="start", col="#333"):
        s.line(px(x), py(y), tx, ty, col, 1.2)
        s.circ(px(x), py(y), 3, col, col, 0)
        for i, t in enumerate(lines):
            s.text(tx + (5 if anchor == "start" else -5), ty + 4 + i * 15, t, 11, "bold" if i == 0 else "normal", anchor, col)

    def run(pts, col):
        d = " ".join(f"{px(x):.0f},{py(y):.0f}" for x, y in pts)
        s.raw(f'<polyline points="{d}" fill="none" stroke="{col}" stroke-width="3.5" stroke-dasharray="2,7" stroke-linecap="round"/>')
        s.circ(px(pts[-1][0]), py(pts[-1][1]), 5, col, col, 0)

    run([(100, 40), (92, 30)], "#111")
    run([(166, 62), (158, 54), (100, 54), (88, 49), (12, 49)], "#111")
    run([(8, 45), (14, 39), (22, 33)], "#111")
    run([(80, 66), (86, 80), (97, 100), (97, 108), (112, 126)], BLUE)
    run([(181, 116), (170, 116), (166, 116)], BLUE)

    # ---------------------------------------------------------------- notes column
    nx = 1330
    s.text(nx, 150, "What the dotted wire runs are", 15, "bold")
    s.note(nx, 172, [
        "Black: inlet → Wagos · Shelly O → SSR 1 (along the floor,",
        "  behind the SSR) · SSR 2 → CT → oven socket hot.",
        "Blue: SSR 3 / 4 → slot in the pocket wall → J7 ·",
        "  thermocouple → hole in the left side wall → MAX6675.",
        "Orange bars: ribs on the underside of the lid.",
        "Green outlines on the floor: cable-tie anchors.",
    ], 12, lh=18)
    s.text(nx, 304, "Mounting, part by part", 16, "bold")
    s.note(nx, 328, [
        "Heatsink + SSR",
        "• Wire the SSR on the bench, then lower the pair into",
        "  the 5 mm fence. Terminals 1 / 2 end up toward the",
        "  oven socket, 3 / 4 toward the display pocket.",
        "• An L-shaped rib under the lid stops 0.5 mm above",
        "  the heatsink, so it cannot lift out of the fence.",
        "",
        "DROK meter",
        "• Snaps into a 74.0 x 45.6 mm hole in the lid from",
        "  above, long side left-to-right. Turn it so the digits",
        "  are upright from the front. Fit the coupon first.",
        "",
        "KP200",
        "• Two screws into the lid bosses, as before. Its body",
        "  hangs over the inlet wiring; its faceplate reaches",
        "  over the display pocket.",
        "",
        "Wagos and CT",
        "• Loose on the floor between the oven socket and the",
        "  inlet, held by cable ties through the two anchors.",
        "  Clip the CT around the SSR 2 → socket hot wire only.",
        "",
        "Shelly",
        "• Drops into its pocket on the left side wall. The lid",
        "  boss behind it is clear of its way in.",
        "",
        "MAX6675",
        "• Lay a cable tie under the saddle's bar first, set the",
        "  board on the two pads, then close the tie over it.",
        "  Fits boards 25 to 32.5 mm long, up to 16 mm wide.",
        "",
        "Display",
        "• Four standoffs on the back of the front panel,",
        "  connectors down, USB-C toward the left side wall.",
    ], 12.5, lh=19)
    for row in (0, 7, 12, 17, 22, 26, 31):
        s.rect(nx - 10, 328 + row * 19 - 14, 5, 19, "#b22222", "#b22222", 0, 1)

    # ---------------------------------------------------------------- sections
    Ks = 5.3

    def make_section(sx, sy):
        def qy(y):
            return sx + y * Ks

        def qz(z):
            return sy + (BOX_H + 8 - z) * Ks

        def qrect(y0, z0, y1, z1, fill, stroke="#333", sw=1.5, dash=None, op=None):
            s.rect(qy(y0), qz(z1), (y1 - y0) * Ks, (z1 - z0) * Ks, fill, stroke, sw, 2, dash, op)

        def qpoly(pts, fill, stroke="#333", sw=1.5):
            d = " ".join(f"{qy(y):.1f},{qz(z):.1f}" for y, z in pts)
            s.raw(f'<polygon points="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')

        def vdim(y, za, zb, lab, side=1):
            s.line(qy(y), qz(za), qy(y), qz(zb), "#b22222", 1.5, arrow="arr"); s.line(qy(y), qz(zb), qy(y), qz(za), "#b22222", 1.5, arrow="arr")
            s.text(qy(y) + 7 * side, qz((za + zb) / 2) + 4, lab, 11.5, "bold", "start" if side > 0 else "end", "#b22222")

        def hdim(ya, yb, z, lab, above=True):
            s.line(qy(ya), qz(z), qy(yb), qz(z), "#b22222", 1.5, arrow="arr"); s.line(qy(yb), qz(z), qy(ya), qz(z), "#b22222", 1.5, arrow="arr")
            s.text(qy((ya + yb) / 2), qz(z) + (-5 if above else 15), lab, 11.5, "bold", "middle", "#b22222")

        def shell():
            qrect(0, 0, FP_IN, 3, "#c9d1d9"); qrect(0, 0, 3, SHELL_H, "#c9d1d9")
            qrect(0, SHELL_H, BOX_D, BOX_H, "#c9d1d9", "#333", 2)
            s.text(qy(70), qz(-5.5), "floor", 11, anchor="middle", fill="#555")
            s.text(qy(-2), qz(40), "rear wall", 11, "bold", "middle", "#555", rot=-90)
            s.text(qy(BOX_D + 3.5), qz(40), "front panel", 11, "bold", "middle", "#555", rot=90)
        return qy, qz, qrect, qpoly, vdim, hdim, shell

    # --- B: through the heatsink column
    sx, sy = 70, 1215
    qy, qz, qrect, qpoly, vdim, hdim, shell = make_section(sx, sy)
    s.text(sx, sy - 16, "B. Section through the heatsink, seen from the left side", 16, "bold")
    shell()
    qrect(FP_IN, 0, BOX_D, SHELL_H, "#44505c")
    s.rect(qy(FP_IN) - 1, qz(INTAKE["z1"]), 3 * Ks + 2, (INTAKE["z1"] - INTAKE["z0"]) * Ks, "#ffffff", "#ffffff", 0, 0)
    (x0, y0, z0), (x1, y1, z1) = k("drok_meter")
    s.rect(qy(y0 - 0.3), qz(BOX_H + 0.2), (y1 - y0 + 0.6) * Ks, 3.4 * Ks, "#ffffff", "#ffffff", 0, 0)
    for i in range(VENT["n"]):
        vy = VENT["yc"] - (VENT["n"] - 1) * VENT["gap"] / 2 + i * VENT["gap"] - VENT["w"] / 2
        s.rect(qy(vy), qz(BOX_H + 0.2), VENT["w"] * Ks, 3.4 * Ks, "#ffffff", "#ffffff", 0, 0)
    (a0, b0, c0), (a1, b1, c1) = k("junction_zone"); qrect(b0, c0, b1, c1, "#e9f7ee", "#1a8f3a", 1.5, "6,4")
    s.text(qy((b0 + b1) / 2), qz(27), "Wagos + CT", 12, "bold", "middle", "#14592a"); s.text(qy((b0 + b1) / 2), qz(22.5), "loose, cable-tied", 11, anchor="middle", fill="#14592a")
    qrect(17.5, 3, 22.5, 8, "#ffffff", "#1a8f3a", 1.5)
    (a0, b0, c0), (a1, b1, c1) = k("ssr_wiring_zone"); qrect(b0, c0, b1, c1, "#fff4d6", "#c79a1e", 1, "5,4"); s.text(qy((b0 + b1) / 2), qz(30), "SSR", 11, "bold", "middle", "#7a5c00"); s.text(qy((b0 + b1) / 2), qz(26), "screws", 11, "bold", "middle", "#7a5c00")
    (a0, b0, c0), (a1, b1, c1) = k("ssr"); qrect(b0, c0, b1, c1, "#f2f2f2", "#222", 2); s.text(qy((b0 + b1) / 2), qz(28), "SSR", 13, "bold", "middle")
    (a0, b0, c0), (a1, b1, c1) = k("heatsink"); qrect(b0, c0, b1, c1, "url(#fins)", "#6f7780", 2); s.text(qy((b0 + b1) / 2), qz(28), "Heatsink", 13, "bold", "middle")
    qrect(y0, z0, y1, z1, "#0b2a5c", "#b22222", 2.5)
    qrect(DROK_FACE[1], BOX_H, DROK_FACE[3], BOX_H + 2.5, "#1d1d1d", "#000", 2)
    (a0, b0, c0), (a1, b1, c1) = k("drok_terminals"); qrect(b0, c0, b1, c1, "#e9f7ee", "#1a8f3a", 1.5, "5,4")
    s.text(qy((y0 + y1) / 2), qz(70.5), "DROK meter body", 12.5, "bold", "middle", "#fff")
    s.text(qy((y0 + y1) / 2), qz(66), "21.5 deep, clips grip the lid", 11, anchor="middle", fill="#cfe0f5")
    s.text(qy((y0 + y1) / 2), qz(53.6), "7 mm: its screws + wires", 10.5, "bold", "middle", "#14592a")
    qrect(HOLD["y0"], HOLD["z"], HOLD["y1"], SHELL_H, "#f5c16c", "#a86a00", 1.5)
    s.text(qy(86), qz(66), "hold-down rib", 11, "bold", fill="#7a4d00"); s.text(qy(86), qz(62), "0.5 above the heatsink", 10.5, fill="#7a4d00")
    s.text(qy(105), qz(BOX_H + 3.2), "vent slots", 11, anchor="middle", fill="#555")
    s.text(qy(132), qz(42), "intake", 10.5, "bold", "middle", "#555", rot=-90)
    hdim(127, FP_IN, 58, "10", True)
    vdim(70, 51, 58.53, "7.5", -1)
    vdim(118, 54, 80, "26 to the lid")

    # --- C: through the display pocket
    sx2 = 70 + (BOX_D + 22) * Ks
    qy, qz, qrect, qpoly, vdim, hdim, shell = make_section(sx2, sy)
    s.text(sx2, sy - 16, "C. Section through the KP200 and the display pocket, seen from the left side", 16, "bold")
    shell()
    # pocket wall (stepped), drawn as two faces 2 mm apart
    qpoly([(104, 3), (104, 58), (118, 72), (118, 80), (120, 80), (120, 70.6), (106, 56.6), (106, 3)], "#6b7480", "#444", 1)
    # front panel with window, and the lid bead in its top chamfer
    (a0, b0, c0), (a1, b1, c1) = k("crow_lcm")
    qpoly([(FP_IN, 0), (BOX_D, 0), (BOX_D, 78.5), (138.5, SHELL_H), (FP_IN, SHELL_H)], "#44505c", "#222", 1.2)
    s.rect(qy(FP_IN) - 1, qz(67.1), 3 * Ks + 2, 44.2 * Ks, "#bfe3ff", "#ffffff", 0, 0)
    qpoly([(138.8, SHELL_H), (BOX_D, SHELL_H), (BOX_D, 78.8)], "#c9d1d9", "#333", 1)
    (a0, b0, c0), (a1, b1, c1) = k("inlet"); qrect(0, c0, b0 + 28, c1, "#262626", "#111", 2); qrect(b0 + 28, c0, b1, c1, "#777", "#111", 1, "4,3", 0.5)
    s.text(qy(17), qz(17), "Inlet body", 12, "bold", "middle", "#fff"); s.text(qy(41), qz(17), "its wires", 11, anchor="middle", fill="#fff")
    (a0, b0, c0), (a1, b1, c1) = k("kp200_body")
    s.rect(qy(b0 + 2), qz(BOX_H + 0.2), (b1 - b0 - 4) * Ks, 3.4 * Ks, "#ffffff", "#ffffff", 0, 0)
    qrect(b0, c0, b1, c1 + 3, "#f1f1f1", "#555", 2)
    qrect(KP_FACE[1], BOX_H, KP_FACE[3], BOX_H + 2.5, "#fafafa", "#555", 1.5)
    s.text(qy((b0 + b1) / 2), qz(62), "KP200 body", 13, "bold", "middle"); s.text(qy((b0 + b1) / 2), qz(57), "hangs from the lid", 11.5, anchor="middle", fill="#444")
    s.text(qy(45), qz(BOX_H + 4.2), "KP200 faceplate, 129 long", 11, "bold", "middle", "#444")
    for rx0, rx1, ry0, ry1 in LID_RIBS:
        qrect(ry0, 72, ry1, SHELL_H, "#f5c16c", "#a86a00", 1.2)
    (a0, b0, c0), (a1, b1, c1) = k("max6675"); qrect(SADDLE[1], 3, SADDLE[3], 7, "#cfd8e3", "#555", 1); qrect(b0, c0, b1, c1, "#1b4fa0", "#0d2a59", 1.5)
    s.text(qy((b0 + b1) / 2), qz(12.5), "MAX", 10.5, "bold", "middle", "#fff")
    (a0, b0, c0), (a1, b1, c1) = k("crow_pcb"); qrect(b0, c0, b1 - 1.6, c1, "#31486b", "#0a1322", 1, "3,3", 0.45); qrect(b1 - 1.6, c0, b1, c1, "#12233a", "#0a1322", 1.5)
    (a0, b0, c0), (a1, b1, c1) = k("crow_lcm"); qrect(b0, c0, b1, c1, "#8fb8e8", "#0a1322", 1)
    s.text(qy(113), qz(44), "display", 11, "bold", "middle", BLUE); s.text(qy(113), qz(40), "pocket", 11, "bold", "middle", BLUE); s.text(qy(113), qz(36), "3.3 / 5 V", 10.5, anchor="middle", fill=BLUE)
    s.text(qy(80), qz(20), "mains bay: wiring space", 11.5, "bold", "middle", "#b22222"); s.text(qy(80), qz(15.5), "under the KP200", 11, anchor="middle", fill="#b22222")
    vdim(55, 3, 35, "32", 1)
    hdim(106, FP_IN, 9.5 + 15, "31", True)
    hdim(120, FP_IN, 75.2, "17", True)
    s.line(qy(139.4), qz(79.4), qy(133), qz(88.5), "#333", 1.2); s.text(qy(133) - 4, qz(88.5) + 4, "lid bead holds the panel's top edge", 11, "bold", "end")

    # ---------------------------------------------------------------- bottom band
    by0 = 1790
    s.rect(56, by0 - 26, 500, 232, "#f7f9fb", "#b8c2cc", 1.2, 8)
    s.text(70, by0, "Clearances (mm)", 15, "bold")
    table(s, 70, by0 + 10, ["Between", "Gap"], [
        ["Heatsink ↔ front panel (intake plenum)", "10"],
        ["Heatsink top ↔ lid rib / lid", "0.5 / 26"],
        ["SSR top ↔ meter body", "7.5"],
        ["KP200 body ↔ inlet top / floor", "2.3 / 32"],
        ["KP200 body ↔ pocket wall / Shelly", "2.3 / 12.4"],
        ["KP200 body ↔ heatsink fence (wire channel)", "17"],
        ["Meter face ↔ lid vent slots", "26.8"],
    ], [390, 82], 12.5, 24)

    cx1 = 620
    s.text(cx1, by0, "Service access", 16, "bold")
    s.note(cx1, by0 + 26, [
        "• Lid: 8 screws, all outside the KP200 faceplate. The meter and the",
        "  KP200 come up with it. Leave 150 mm of slack in their wires so the",
        "  lid can lie on its back beside the box, still connected.",
        "• Front panel: 6 screws. With the lid on, swing the bottom edge out,",
        "  then lower the panel out of the lid's bead. Refit top edge first.",
        "• Display and Grove cables: on the front panel, in the pocket.",
        "• Nothing stands on the floor between the parts: the lid bosses hang",
        "  from the walls, so a wire can be laid in from above anywhere.",
        "• Shelly, Wagos, inlet and socket terminals: lid off, all from above.",
    ], 12.5, lh=19.5)
    cx2 = 1210
    s.text(cx2, by0, "Printing (Bambu X1C, ASA, no supports)", 16, "bold")
    s.note(cx2, by0 + 26, [
        "• Bottom: floor down. Lid: outer face down (already mirrored).",
        "  Front panel: face down.",
        "• Pierce the four thin skins in the KP200 holes with a 3.5 mm",
        "  drill or the screw itself.",
        "• Checked on the model: nothing overhangs past 45°, no Bambu",
        "  'floating cantilever' warning, no overlap between parts or",
        "  with a component, no straight probe path through any slot",
        "  to a live terminal.",
        "• The CrowPanel, inlet, socket, KP200 and meter coupons from",
        "  v12 are unchanged and still valid.",
    ], 12.5, lh=19.5)
    for xx in (cx1, cx2):
        s.rect(xx - 10, by0 - 15, 5, 20, "#b22222", "#b22222", 0, 1)
    s.save(path)


def read_keepouts(scad_log_lines):
    ko = {}
    for line in scad_log_lines:
        f = line.strip().strip('"').split("|")
        if len(f) == 8 and f[0].endswith("KO"):
            ko[f[1]] = (tuple(map(float, f[2:5])), tuple(map(float, f[5:8])))
    return ko


# Keep-out boxes echoed by the SCAD model (openscad ... 2>&1 | grep "KO|"), v13.0
KEEPOUTS = """KO|heatsink|7|77.6|3|87|127|54
KO|ssr|16|54.1|6|78|77.6|51
KO|ssr_wiring_zone|16|40.1|6|78|54.1|51
KO|ssr_ac_wire_channel|3|42.1|6|16|62.1|51
KO|ssr_dc_wire_zone|78|42.1|6|90|74.5|51
KO|inlet|96|3|5.25|144|51|32.75
KO|oven_socket|2.5|7.5|8.5|35|34.5|35.5
KO|shelly|164.4|58.6|3|180.4|100.6|40
KO|kp200_body|107|31.25|35|152|101.75|80
KO|junction_zone|36|3|8.1|94|40.1|40
KO|crow_lcm|102.3|132.9|20|171.5|136.4|70
KO|crow_pcb|94.05|125.75|18|179.75|132.9|72
KO|crow_cable_zone|103.55|125.75|3|152.52|132.9|18
KO|crow_spk_plug|118.76|125.75|72|128.76|131.3|79
KO|usb_plug|179.75|126.92|27.65|209|133.42|40.05
KO|max6675|133|107.9|7.05|165.5|123.9|21
KO|drok_meter|9.315|15.5|58.53|82.685|60.5|80
KO|drok_terminals|9.315|15.5|51.53|82.685|60.5|58.53""".splitlines()

if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "docs", "wiring")
    os.makedirs(out, exist_ok=True)
    sheet_ac(os.path.join(out, "reflow-wiring-ac-mains.svg"))
    sheet_lv(os.path.join(out, "reflow-wiring-low-voltage.svg"))
    sheet_layout(os.path.join(out, "reflow-layout-clearances.svg"), read_keepouts(KEEPOUTS))
    print("wrote 3 SVG sheets to", out)
