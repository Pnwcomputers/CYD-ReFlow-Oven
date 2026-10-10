# Usage:
#   for p in bottom lid bezel oven_socket_coupon iec_test_coupon kp200_test_coupon cyd_test_coupon iec_trim_plate; do
#     openscad -o OUT/$p.stl -D "part=\"$p\"" OpenSCAD/reflow-enclosure-flat-v11_0-compact-x1c.scad 2> OUT/$p.log; done
#   grep -h "KO|" OUT/bottom.log | sed "s/ECHO: //" > OUT/keepouts.txt
#   python3 tools/verify_enclosure.py OUT OpenSCAD/reflow-enclosure-flat-v11_0-compact-x1c.scad
# Needs: trimesh, numpy, manifold3d, shapely, rtree, networkx.
"""Verification for the v11 enclosure.

Checks, all on freshly rendered meshes:
  1. Mesh health: weld, watertight, consistent winding, bed fit (X1C 256 x 256).
  2. Supports: every downward surface steeper than 45 degrees above the bed,
     clustered, with its span, per part in print orientation.
  3. Interference: shell and installed lid vs every component keepout box,
     plus keepout-vs-keepout overlaps.
  4. Probe rays: straight rigid probes through every lid outlet slot and
     front intake slot; the first thing each ray hits must not be a live part.
"""
import re, sys, itertools
import numpy as np
import trimesh

D = sys.argv[1]
BOX_W, BOX_D, BOX_H = 230.0, 155.0, 65.0


def load(name):
    m = trimesh.load(f"{D}/{name}.stl")
    m.merge_vertices()
    return m


def box(lo, hi):
    lo, hi = np.array(lo, float), np.array(hi, float)
    b = trimesh.creation.box(extents=hi - lo)
    b.apply_translation((lo + hi) / 2)
    return b


# ---------------------------------------------------------------- 1 + 2
parts = ["bottom", "lid", "bezel", "oven_socket_coupon", "iec_test_coupon",
         "kp200_test_coupon", "cyd_test_coupon", "iec_trim_plate"]
print("== 1. Mesh health and bed fit ==")
ok = True
meshes = {}
for p in parts:
    m = load(p)
    meshes[p] = m
    fit = m.extents[0] <= 256 and m.extents[1] <= 256 and m.extents[2] <= 256
    good = m.is_watertight and m.is_winding_consistent and fit
    ok &= good
    print(f"{p:20s} extents {np.round(m.extents, 2).tolist()} watertight {m.is_watertight} "
          f"winding {m.is_winding_consistent} bed-fit {fit} -> {'PASS' if good else 'FAIL'}")

print("\n== 2. Downward surfaces in print orientation (above z 0.3) ==")
for p in parts:
    m = meshes[p]
    z0 = m.bounds[0][2]
    nz = m.face_normals[:, 2]
    cz = m.triangles_center[:, 2] - z0
    mask = (nz < -0.7071) & (cz > 0.3)
    idx = np.where(mask)[0]
    if len(idx) == 0:
        print(f"{p:20s} none")
        continue
    sub = m.submesh([idx], append=True)
    rows = []
    for c in sub.split(only_watertight=False):
        if c.area < 1.0:
            continue
        b = c.bounds
        ext = b[1] - b[0]
        flat = np.all(c.face_normals[:, 2] < -0.99)
        span = min(ext[0], ext[1])     # a bridge spans its shorter side
        rows.append((p, b, ext, flat, span, c.area))
    worst_bridge = max([r[4] for r in rows if r[3]], default=0)
    steep = [r for r in rows if not r[3]]
    worst_steep = max([min(r[2][0], r[2][1]) for r in steep], default=0)
    print(f"{p:20s} {len(rows)} regions; longest flat-bridge short side {worst_bridge:.1f} mm; "
          f"widest steep (non-flat) overhang {worst_steep:.1f} mm")
    for r in rows:
        b = r[1]
        kind = "bridge" if r[3] else "steep"
        print(f"    {kind:6s} x {b[0][0]-meshes[p].bounds[0][0]:.1f}-{b[1][0]-meshes[p].bounds[0][0]:.1f} "
              f"y {b[0][1]-meshes[p].bounds[0][1]:.1f}-{b[1][1]-meshes[p].bounds[0][1]:.1f} "
              f"z {b[0][2]-meshes[p].bounds[0][2]:.1f}  area {r[5]:.0f} mm2")

# ---------------------------------------------------------------- 3
print("\n== 3. Interference (installed orientation) ==")
ko = {}
for line in open(f"{D}/keepouts.txt"):
    f = line.strip().strip('"').split("|")
    ko[f[1]] = (list(map(float, f[2:5])), list(map(float, f[5:8])))
shell = meshes["bottom"]
lid = meshes["lid"].copy()
# lid_assembly_orientation(): translate([0, box_d, box_h]) rotate([180, 0, 0]) lid_printable()
T = trimesh.transformations.rotation_matrix(np.pi, [1, 0, 0])
T[:3, 3] = [0, BOX_D, BOX_H]
lid.apply_transform(T)
print(f"installed lid z range {lid.bounds[0][2]:.2f}-{lid.bounds[1][2]:.2f} (expect 62-72 incl. bosses below 62)")
solids = {"shell": shell, "lid": lid}
fail3 = 0
for k, (lo, hi) in ko.items():
    if k == "ssr_wiring_zone":
        pass
    b = box(lo, hi)
    for sn, s in solids.items():
        v = trimesh.boolean.intersection([b, s]).volume
        flag = v > 0.05
        fail3 += flag
        if flag or sn == "shell":
            pass
        print(f"{k:16s} vs {sn:5s}: {v:9.3f} mm3 {'FAIL' if flag else 'ok'}")
print("keepout vs keepout:")
for (a, (la, ha)), (b_, (lb, hb)) in itertools.combinations(ko.items(), 2):
    ov = np.minimum(ha, hb) - np.maximum(la, lb)
    if np.all(ov > 1e-6):
        vol = float(np.prod(ov))
        expected = {("heatsink", "ssr"), ("ssr", "ssr_wiring_zone")}
        tag = "expected contact" if (a, b_) in expected else "FAIL"
        if tag == "FAIL":
            fail3 += 1
        print(f"   {a} x {b_}: overlap {vol:.1f} mm3 {tag}")
print(f"-> {'PASS' if fail3 == 0 else 'FAIL'} ({fail3} problems)")

# ---------------------------------------------------------------- 4
print("\n== 4. Probe rays through outlet and intake slots ==")
src = open(sys.argv[2]).read()
def param(name):
    return float(re.search(rf"^{name}\s*=\s*([-0-9.]+)", src, re.M).group(1))
vent_w, vent_len, vent_n, vent_gap = param("vent_slot_w"), param("vent_slot_len"), int(param("vent_slot_count")), param("vent_slot_gap")
in_w, in_n, in_gap, in_z1 = param("intake_slot_w"), int(param("intake_slot_count")), param("intake_slot_gap"), param("intake_z1")
hs = ko["heatsink"]
vcx = (hs[0][0] + hs[1][0]) / 2
vcy = (hs[0][1] + hs[1][1]) / 2
wall, floor_t, lid_t = 3.0, 3.0, 3.0
shell_top = BOX_H - lid_t

# live zones (bare conductors): SSR terminal face, inlet rear terminals,
# oven socket rear terminals, Shelly (whole body: screw terminals)
ssr = ko["ssr"]; inl = ko["inlet"]; osk = ko["oven_socket"]; sh = ko["shelly"]
live = {
    "SSR terminal face": ([ssr[0][0], ssr[0][1] - 0.5, ssr[0][2]], [ssr[1][0], ssr[0][1] + 3, ssr[1][2]]),
    "inlet terminals": ([inl[0][0], wall + 20, inl[0][2]], inl[1]),
    "oven socket terminals": ([20, osk[0][1], osk[0][2]], osk[1]),
    "Shelly terminals": sh,
}
# grounded / insulating blockers
block = {
    "heatsink (grounded)": ko["heatsink"],
    "SSR body (insulating)": ([ssr[0][0], ssr[0][1] + 3, ssr[0][2]], ssr[1]),
    "KP200 body": ko["kp200_body"],
}
scene, labels = [], []
for name, mesh in [("shell", shell), ("lid", lid)]:
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
    pi = lambda u, v, y0=y0, x0=x0: [x0 + v * vent_len, y0 + u * vent_w, shell_top]
    o, d = slot_rays(po, pi, 4, 12); origins.append(o); dirs.append(d); tags += [f"lid slot {i+1}"] * len(o)
span = (in_n - 1) * in_gap
for i in range(in_n):
    x0 = vcx - span / 2 + i * in_gap - in_w / 2
    po = lambda u, v, x0=x0: [x0 + u * in_w, BOX_D, floor_t + 3 + v * (in_z1 - floor_t - 3)]
    pi = lambda u, v, x0=x0: [x0 + u * in_w, BOX_D - wall, floor_t + 3 + v * (in_z1 - floor_t - 3)]
    o, d = slot_rays(po, pi, 4, 12); origins.append(o); dirs.append(d); tags += [f"intake slot {i+1}"] * len(o)
origins = np.vstack(origins); dirs = np.vstack(dirs); tags = np.array(tags)
first = np.concatenate([ray.intersects_first(origins[i:i + 1500], dirs[i:i + 1500])
                        for i in range(0, len(origins), 1500)])
hit = np.where(first >= 0, labels[np.clip(first, 0, None)], "escaped")
live_hits = np.char.startswith(hit.astype(str), "LIVE:")
print(f"{len(origins)} rays")
for name in sorted(set(hit)):
    print(f"   first hit {name:28s} {np.sum(hit == name):7d}")
print(f"-> {'PASS: no straight probe reaches a live part' if live_hits.sum() == 0 else 'FAIL'} "
      f"({live_hits.sum()} rays reach live parts)")
if live_hits.sum():
    for t in sorted(set(tags[live_hits])):
        print("     from", t)
