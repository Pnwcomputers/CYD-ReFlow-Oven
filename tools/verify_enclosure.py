# Usage:
#   S=OpenSCAD/reflow-enclosure-compact-v13_0-x1c.scad
#   for p in bottom lid front_panel crowpanel_test_coupon oven_socket_coupon iec_test_coupon kp200_test_coupon iec_trim_plate drok_meter_coupon; do
#     openscad -o OUT/$p.stl -D "part=\"$p\"" $S > OUT/$p.log 2>&1; done
#   grep -h "KO|" OUT/bottom.log | sed "s/ECHO: //" > OUT/keepouts.txt
#   python3 tools/verify_enclosure.py OUT $S [CROW_STEP_PARTS_DIR]
# CROW_STEP_PARTS_DIR (optional): one STL per solid of Elecrow's
# "3D_File_CrowPanel_2.8-ESP32_HMI-2.1.stp", named sNNN.stl in STEP order
# (see tools/step_parts.py). Enables check 5 (real board vs printed parts).
# Needs: trimesh, numpy, scipy, manifold3d, shapely, rtree, networkx.
"""Verification for the v12 enclosure.

Checks, all on freshly rendered meshes:
  1. Mesh health: weld, watertight, consistent winding, bed fit (X1C 256 x 256).
  2. Supports: every downward surface steeper than 45 degrees above the bed,
     per part in print orientation. Flat ceilings (bridges) and sloped faces
     are clustered separately, so a flat roof that joins a chamfer is still
     reported as a bridge with its span.
  2b. Slicer warning: Bambu Studio's "floating cantilever" rule, re-implemented
     from its source (TreeSupport::detect_overhangs), run on 0.2 mm slices.
  3. Interference: shell, installed lid and installed front panel vs every
     component keepout box and vs each other; keepout-vs-keepout overlaps.
  4. Probe rays: straight rigid probes through every lid outlet slot, front
     intake slot, the USB-C slot and the thermocouple hole; the first thing
     each ray hits must not be a live part.
  5. (optional) Elecrow's STEP board, placed by the SCAD transform, vs the
     printed parts.
"""
import re, sys, glob, itertools, math, warnings
import numpy as np
import trimesh
from shapely.geometry import Polygon, MultiPolygon, Point
from shapely.ops import unary_union

D = sys.argv[1]
SRC = open(sys.argv[2]).read()
STEP_DIR = sys.argv[3] if len(sys.argv) > 3 else None

log = open(f"{D}/bottom.log").read()
m = re.search(r"Box: ([\d.]+) x ([\d.]+) x ([\d.]+) mm; shell ([\d.]+)", log)
BOX_W, BOX_D, BOX_H, SHELL_H = map(float, m.groups())
m = re.search(r"CrowPanel centre X/Z ([\d.]+)/([\d.]+);.*PCB front Y ([\d.]+)", log)
CROW_CX, CROW_CZ, PCB_FRONT_Y = map(float, m.groups())


def param(name):
    return float(re.search(rf"^{name}\s*=\s*([-0-9.]+)", SRC, re.M).group(1))


WALL, FLOOR, LID_T, FP_T = param("wall_t"), param("floor_t"), param("lid_t"), param("fp_t")
FP_IN = BOX_D - FP_T


def load(name):
    m = trimesh.load(f"{D}/{name}.stl")
    m.merge_vertices()
    return m


def box(lo, hi):
    lo, hi = np.array(lo, float), np.array(hi, float)
    b = trimesh.creation.box(extents=hi - lo)
    b.apply_translation((lo + hi) / 2)
    return b


def inter_vol(a, b):
    r = trimesh.boolean.intersection([a, b])
    return 0.0 if r is None or r.is_empty else float(r.volume)


# ---------------------------------------------------------------- 1 + 2
parts = ["bottom", "lid", "front_panel", "crowpanel_test_coupon", "oven_socket_coupon",
         "iec_test_coupon", "kp200_test_coupon", "iec_trim_plate", "drok_meter_coupon"]
print(f"Box {BOX_W} x {BOX_D} x {BOX_H}, shell {SHELL_H}")
print("== 1. Mesh health and bed fit ==")
ok1 = True
meshes = {}
for p in parts:
    mm = load(p)
    meshes[p] = mm
    fit = mm.extents[0] <= 256 and mm.extents[1] <= 256 and mm.extents[2] <= 256
    good = mm.is_watertight and mm.is_winding_consistent and fit
    ok1 &= good
    print(f"{p:22s} extents {np.round(mm.extents, 2).tolist()} watertight {mm.is_watertight} "
          f"winding {mm.is_winding_consistent} bed-fit {fit} -> {'PASS' if good else 'FAIL'}")
print(f"-> {'PASS' if ok1 else 'FAIL'}")

print("\n== 2. Downward surfaces in print orientation (above z 0.3) ==")
for p in parts:
    mm = meshes[p]
    z0 = mm.bounds[0][2]
    nz = mm.face_normals[:, 2]
    cz = mm.triangles_center[:, 2] - z0
    idx = np.where((nz < -0.7072) & (cz > 0.3))[0]
    idx45 = np.where((nz <= -0.7070) & (nz >= -0.7072) & (cz > 0.3))[0]
    if len(idx) == 0:
        print(f"{p:22s} none steeper than 45 deg ({len(idx45)} faces at exactly 45 deg)")
        continue
    rows = []
    for flat, sel in ((True, idx[nz[idx] < -0.99]), (False, idx[nz[idx] >= -0.99])):
        if len(sel) == 0:
            continue
        for c in mm.submesh([sel], append=True).split(only_watertight=False):
            if c.area < 1.0:
                continue
            b = c.bounds
            ext = b[1] - b[0]
            rows.append((b, ext, flat, min(ext[0], ext[1]), c.area))
    worst_bridge = max([max(r[1][0], r[1][1]) for r in rows if r[2]], default=0)
    steep = [r for r in rows if not r[2]]
    print(f"{p:22s} {len(rows)} regions; largest flat-bridge region dimension {worst_bridge:.1f} mm; "
          f"{len(steep)} non-flat regions steeper than 45 deg; {len(idx45)} faces at exactly 45 deg")
    for b, ext, flat, span, area in rows:
        o = mm.bounds[0]
        print(f"    {'bridge' if flat else 'STEEP':6s} x {b[0][0]-o[0]:.1f}-{b[1][0]-o[0]:.1f} "
              f"y {b[0][1]-o[1]:.1f}-{b[1][1]-o[1]:.1f} z {b[0][2]-o[2]:.1f}  size {ext[0]:.1f} x {ext[1]:.1f}  area {area:.0f} mm2")

# ---------------------------------------------------------------- 2b
# Bambu Studio warns "floating cantilever" when supports are off and
# TreeSupport::detect_overhangs finds, on some layer, an overhang area
# (layer minus the layer below grown by layer_height / tan(30 deg)) that has
#   (a) an outline or a hole edge with no vertex over the layer below (grown by
#       one extrusion width): e.g. a screw hole through a bridged ceiling, or
#   (b) an outline vertex more than 3 mm from the supported rim,
# and the largest such distance is over 6 mm (PrintObject::is_support_necessary).
# Only the polygon VERTICES are tested, so a plain straight bridge edge passes.
def _slice(m, z):
    sec = m.section(plane_origin=[0, 0, z], plane_normal=[0, 0, 1])
    if sec is None:
        return MultiPolygon()
    p2d, T = sec.to_2D()
    out = []
    for poly in p2d.polygons_full:
        def tr(coords):
            a = np.asarray(coords)
            return (T @ np.c_[a, np.zeros(len(a)), np.ones(len(a))].T).T[:, :2]
        out.append(Polygon(tr(poly.exterior.coords), [tr(h.coords) for h in poly.interiors]))
    return unary_union(out)


def cantilever_scan(m, lh=0.2, thr_deg=30.0, ext_w=0.45):
    off = lh / math.tan(math.radians(thr_deg))
    z0 = m.bounds[0][2]
    found, lower = [], None
    for i in range(int(round(m.extents[2] / lh))):
        cur = _slice(m, z0 + (i + 0.5) * lh)
        if lower is not None and not cur.is_empty and not lower.is_empty:
            over = cur.difference(lower.buffer(off, join_style=2))
            thresh = lower.buffer(ext_w, join_style=2)
            rim = lower.buffer(max(ext_w, off) + 0.1, join_style=2)
            for g in (over.geoms if hasattr(over, "geoms") else [over]):
                if g.geom_type != "Polygon" or g.area < 1e-3:
                    continue
                g = g.simplify(0.001)          # Clipper drops collinear vertices
                hit = None
                for k, ring in enumerate([g.exterior] + list(g.interiors)):
                    pts = [Point(c) for c in ring.coords]
                    if not any(thresh.contains(q) for q in pts):
                        hit = ("outline" if k == 0 else "hole edge") + " in mid-air", max(thresh.distance(q) for q in pts)
                        break
                if hit is None:
                    base = g.intersection(rim)
                    if base.is_empty:
                        continue
                    d = max(base.distance(Point(c)) for c in g.exterior.coords)
                    if d > 3:
                        hit = "edge far from support", d
                if hit:
                    found.append((i * lh, g.bounds, hit[0], hit[1]))
        lower = cur
    return found


print("\n== 2b. Bambu Studio 'floating cantilever' rule (0.2 mm layers, supports off) ==")
ok2b = True
with warnings.catch_warnings():
    warnings.simplefilter("ignore")
    for p in parts:
        mm = meshes[p]
        found = cantilever_scan(mm)
        worst = max([f[3] for f in found], default=0.0)
        warn = worst > 6.0
        ok2b &= not warn
        print(f"{p:22s} {len(found)} flagged area(s); largest distance {worst:.1f} mm -> "
              f"{'slicer WARNS' if warn else 'no slicer warning'}")
        o = mm.bounds[0]
        for z, b, why, d in found:
            if d > 3:
                print(f"    z {z:.1f}  x {b[0]-o[0]:.1f}-{b[2]-o[0]:.1f} y {b[1]-o[1]:.1f}-{b[3]-o[1]:.1f}  {why}, {d:.1f} mm")
print(f"-> {'PASS' if ok2b else 'FAIL'}")

# ---------------------------------------------------------------- 3
print("\n== 3. Interference (installed orientation) ==")
ko = {}
for line in open(f"{D}/keepouts.txt"):
    f = line.strip().strip('"').split("|")
    ko[f[1]] = (list(map(float, f[2:5])), list(map(float, f[5:8])))
shell = meshes["bottom"]
lid = meshes["lid"].copy()
T = trimesh.transformations.rotation_matrix(np.pi, [1, 0, 0])
T[:3, 3] = [0, BOX_D, BOX_H]
lid.apply_transform(T)                 # translate([0, box_d, box_h]) rotate([180, 0, 0])
panel = meshes["front_panel"].copy()
T = trimesh.transformations.rotation_matrix(np.pi / 2, [1, 0, 0])
T[:3, 3] = [0, BOX_D, 0]
panel.apply_transform(T)               # translate([0, box_d, 0]) rotate([90, 0, 0])
print(f"installed lid   bounds {np.round(lid.bounds, 2).tolist()}")
print(f"installed panel bounds {np.round(panel.bounds, 2).tolist()}")
solids = {"shell": shell, "lid": lid, "panel": panel}
fail3 = 0
for (an, a), (bn, b) in itertools.combinations(solids.items(), 2):
    v = inter_vol(a, b)
    flag = v > 0.05
    fail3 += flag
    print(f"{an:5s} vs {bn:5s}: {v:9.3f} mm3 {'FAIL' if flag else 'ok'}")
for k, (lo, hi) in ko.items():
    b = box(lo, hi)
    vols = {sn: inter_vol(b, s) for sn, s in solids.items()}
    bad = [sn for sn, v in vols.items() if v > 0.05]
    fail3 += len(bad)
    print(f"{k:22s} " + "  ".join(f"{sn} {v:8.3f}" for sn, v in vols.items()) + f"  {'FAIL ' + ','.join(bad) if bad else 'ok'}")
print("keepout vs keepout (positive-volume overlaps only):")
for (a, (la, ha)), (b_, (lb, hb)) in itertools.combinations(ko.items(), 2):
    ov = np.minimum(ha, hb) - np.maximum(la, lb)
    if np.all(ov > 1e-6):
        fail3 += 1
        print(f"   FAIL {a} x {b_}: overlap {float(np.prod(ov)):.1f} mm3")
print(f"-> {'PASS' if fail3 == 0 else 'FAIL'} ({fail3} problems)")

# ---------------------------------------------------------------- 4
print("\n== 4. Probe rays through every opening ==")
vent_w, vent_len, vent_n, vent_gap = param("vent_slot_w"), param("vent_slot_len"), int(param("vent_slot_count")), param("vent_slot_gap")
in_w, in_n, in_gap, in_z1 = param("intake_slot_w"), int(param("intake_slot_count")), param("intake_slot_gap"), param("intake_z1")
in_z0 = FLOOR + 3
m = re.search(r"Vent centre X/Y ([\d.]+)/([\d.]+)", log)
vcx, vcy = map(float, m.groups())   # lid slots and front intakes share vent_center_x
ssr = ko["ssr"]; inl = ko["inlet"]; osk = ko["oven_socket"]; sh = ko["shelly"]
live = {
    "SSR terminal face": ([ssr[0][0], ssr[0][1] - 0.5, ssr[0][2]], [ssr[1][0], ssr[0][1] + 3, ssr[1][2]]),
    "inlet terminals": ([inl[0][0], WALL + 20, inl[0][2]], inl[1]),
    "oven socket terminals": ([20, osk[0][1], osk[0][2]], osk[1]),
    "Shelly terminals": sh,
}
# v13 additions: the meter's terminals, the loose Wagos and CT, and the KP200's
# side screw terminals (3 mm slabs on its two long sides) count as live too.
for _name, _key in [("meter terminals", "drok_terminals"), ("Wago / CT zone", "junction_zone")]:
    if _key in ko:
        live[_name] = ko[_key]
kp = ko["kp200_body"]
live["KP200 side terminals (-X)"] = ([kp[0][0] - 3, kp[0][1], kp[0][2]], [kp[0][0], kp[1][1], kp[1][2]])
live["KP200 side terminals (+X)"] = ([kp[1][0], kp[0][1], kp[0][2]], [kp[1][0] + 3, kp[1][1], kp[1][2]])
block = {
    "heatsink (grounded)": ko["heatsink"],
    "SSR body (insulating)": ([ssr[0][0], ssr[0][1] + 3, ssr[0][2]], ssr[1]),
    "KP200 body": ko["kp200_body"],
    "CrowPanel PCB": ko["crow_pcb"],
}
scene, labels = [], []
for name, mesh in solids.items():
    scene.append(mesh); labels += [name] * len(mesh.faces)
for name, (lo, hi) in {**{f"LIVE:{k}": v for k, v in live.items()}, **block}.items():
    b = box(lo, hi); scene.append(b); labels += [name] * len(b.faces)
S = trimesh.util.concatenate(scene)
labels = np.array(labels)
ray = trimesh.ray.ray_triangle.RayMeshIntersector(S)


def slot_rays(p_out_fn, p_in_fn, n_u, n_v):
    us = np.linspace(0.05, 0.95, n_u); vs = np.linspace(0.02, 0.98, n_v)
    A = np.array([p_out_fn(u, v) for u in us for v in vs])
    B = np.array([p_in_fn(u, v) for u in us for v in vs])
    o = np.repeat(A, len(B), axis=0); t = np.tile(B, (len(A), 1))
    d = t - o; d /= np.linalg.norm(d, axis=1)[:, None]
    return o - d * 0.05, d


origins, dirs, tags = [], [], []
span = (vent_n - 1) * vent_gap
for i in range(vent_n):
    y0 = vcy - span / 2 + i * vent_gap - vent_w / 2
    x0 = vcx - vent_len / 2
    po = lambda u, v, y0=y0, x0=x0: [x0 + v * vent_len, y0 + u * vent_w, BOX_H]
    pi = lambda u, v, y0=y0, x0=x0: [x0 + v * vent_len, y0 + u * vent_w, SHELL_H]
    o, d = slot_rays(po, pi, 4, 12); origins.append(o); dirs.append(d); tags += [f"lid slot {i+1}"] * len(o)
span = (in_n - 1) * in_gap
for i in range(in_n):
    x0 = vcx - span / 2 + i * in_gap - in_w / 2
    po = lambda u, v, x0=x0: [x0 + u * in_w, BOX_D, in_z0 + v * (in_z1 - in_z0)]
    pi = lambda u, v, x0=x0: [x0 + u * in_w, FP_IN, in_z0 + v * (in_z1 - in_z0)]
    o, d = slot_rays(po, pi, 4, 12); origins.append(o); dirs.append(d); tags += [f"intake slot {i+1}"] * len(o)
m = re.search(r"USB-C slot centre Y/Z ([\d.]+)/([\d.]+)", log)
ucy, ucz = map(float, m.groups())
uy, uz = param("usb_slot_along_y"), param("usb_slot_along_z")
po = lambda u, v: [BOX_W, ucy - uy / 2 + u * uy, ucz - uz / 2 + v * uz]
pi = lambda u, v: [BOX_W - WALL, ucy - uy / 2 + u * uy, ucz - uz / 2 + v * uz]
o, d = slot_rays(po, pi, 6, 10); origins.append(o); dirs.append(d); tags += ["USB-C slot"] * len(o)
tcd, tcy, tcz = param("tc_gland_dia"), param("tc_gland_y"), param("tc_gland_z")
po = lambda u, v: [BOX_W, tcy + (u - 0.5) * tcd * 0.7, tcz + (v - 0.5) * tcd * 0.7]
pi = lambda u, v: [BOX_W - WALL, tcy + (u - 0.5) * tcd * 0.7, tcz + (v - 0.5) * tcd * 0.7]
o, d = slot_rays(po, pi, 5, 5); origins.append(o); dirs.append(d); tags += ["thermocouple hole"] * len(o)
origins = np.vstack(origins); dirs = np.vstack(dirs); tags = np.array(tags)
first = np.concatenate([ray.intersects_first(origins[i:i + 1500], dirs[i:i + 1500])
                        for i in range(0, len(origins), 1500)])
hit = np.where(first >= 0, labels[np.clip(first, 0, None)], "escaped")
live_hits = np.char.startswith(hit.astype(str), "LIVE:")
print(f"{len(origins)} rays")
for group in ["lid slot", "intake slot", "USB-C slot", "thermocouple hole"]:
    sel = np.char.startswith(tags.astype(str), group)
    names, counts = np.unique(hit[sel], return_counts=True)
    print(f"   {group:18s} " + ", ".join(f"{n} {c}" for n, c in zip(names, counts)))
print(f"-> {'PASS: no straight probe reaches a live part' if live_hits.sum() == 0 else 'FAIL'} "
      f"({live_hits.sum()} rays reach live parts)")
if live_hits.sum():
    for t in sorted(set(tags[live_hits])):
        print("     from", t)

# ---------------------------------------------------------------- 5
if STEP_DIR:
    print("\n== 5. Elecrow STEP board (convex hull per solid) vs printed parts ==")
    # STEP solids 0, 6, 7 = optional acrylic case; 8-11 = its screws. Not used.
    skip = {0, 6, 7, 8, 9, 10, 11}
    # board frame -> box: x = cx + xs, y = (PCB front Y) + (zs - zs_pcb_front), z = cz - ys
    ZS_PCB_FRONT = -2.35
    M = np.eye(4)
    M[:3, :3] = [[1, 0, 0], [0, 0, 1], [0, -1, 0]]
    M[:3, 3] = [CROW_CX, PCB_FRONT_Y - ZS_PCB_FRONT, CROW_CZ]
    assert abs(np.linalg.det(M[:3, :3]) - 1) < 1e-9
    board = []
    for f in sorted(glob.glob(f"{STEP_DIR}/s*.stl")):
        i = int(f[-7:-4])
        if i in skip:
            continue
        s = trimesh.load(f)
        s.apply_transform(M)
        board.append((i, s.convex_hull))
    lcm = box(*ko["crow_lcm"])
    board.append(("LCM (drawing)", lcm))
    fail5 = 0
    pcb = [b for i, b in board if i == 1][0]
    print(f"PCB placed at x {pcb.bounds[0][0]:.2f}-{pcb.bounds[1][0]:.2f} y {pcb.bounds[0][1]:.2f}-{pcb.bounds[1][1]:.2f} "
          f"z {pcb.bounds[0][2]:.2f}-{pcb.bounds[1][2]:.2f}")
    for i, b in board:
        for sn, s in solids.items():
            v = inter_vol(b, s)
            if v > 0.05:
                fail5 += 1
                print(f"   FAIL solid {i} vs {sn}: {v:.3f} mm3  bounds {np.round(b.bounds, 2).tolist()}")
    # the hulls of hole-bearing solids (PCB) cover the holes, so the standoff
    # tops must only TOUCH the PCB: report the gap between standoff tops and PCB
    print(f"   {len(board)} board solids checked")
    print(f"-> {'PASS' if fail5 == 0 else 'FAIL'} ({fail5} intersections)")
