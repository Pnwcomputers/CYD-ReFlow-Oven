"""List every solid in a STEP file with its bounding box (mm); optionally export STL per solid."""
import sys, os
from OCP.STEPControl import STEPControl_Reader
from OCP.TopExp import TopExp_Explorer
from OCP.TopAbs import TopAbs_SOLID
from OCP.Bnd import Bnd_Box
from OCP.BRepBndLib import BRepBndLib
from OCP.BRepMesh import BRepMesh_IncrementalMesh
from OCP.StlAPI import StlAPI_Writer
from OCP.GProp import GProp_GProps
from OCP.BRepGProp import BRepGProp

r = STEPControl_Reader()
assert r.ReadFile(sys.argv[1]) == 1
r.TransferRoots()
shape = r.OneShape()
out = sys.argv[2] if len(sys.argv) > 2 else None
if out:
    os.makedirs(out, exist_ok=True)
ex = TopExp_Explorer(shape, TopAbs_SOLID)
i = 0
while ex.More():
    s = ex.Current()
    b = Bnd_Box(); b.SetGap(0.0)
    BRepBndLib.AddOptimal_s(s, b, False, False)
    mn, mx = b.CornerMin(), b.CornerMax(); x0, y0, z0, x1, y1, z1 = mn.X(), mn.Y(), mn.Z(), mx.X(), mx.Y(), mx.Z()
    p = GProp_GProps(); BRepGProp.VolumeProperties_s(s, p)
    print(f"{i:3d} x {x0:8.2f} {x1:8.2f}  y {y0:8.2f} {y1:8.2f}  z {z0:8.2f} {z1:8.2f}  "
          f"size {x1-x0:6.2f} x {y1-y0:6.2f} x {z1-z0:6.2f}  vol {p.Mass():9.1f}")
    if out:
        BRepMesh_IncrementalMesh(s, 0.05)
        StlAPI_Writer().Write(s, f"{out}/s{i:03d}.stl")
    i += 1
    ex.Next()
