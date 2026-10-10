// ============================================================================
//  DIY Reflow Oven Controller — Compact Flat Bench Enclosure (v11.0, X1C Fit)
//  Parametric OpenSCAD model for Bambu X1C. PRINT IN ASA (v11 assumes ASA).
//
//  v11.0 CHANGE (2026-10, AC-bay redesign around the real parts):
//  - Box widened 220 -> 230mm (divider 147 -> 157). Lid CYD/KP200 features keep
//    their positions relative to their parts (CYD tracks the divider; KP200 is
//    anchored to the left/front walls), so the validated fits carry over.
//  - SSR + heatsink re-placed from MEASURED data (Jul 2026): heatsink footprint
//    80 x 49.4mm, stack 51mm tall, fins vertical, SSR bolted to the heatsink's
//    vertical face. The 49.4mm footprint does NOT include the SSR's sideways
//    protrusion (~23.5mm, APPROX from a same-style SSR datasheet: 62x45x23.5).
//    In v10.x that protrusion left the SSR terminal face ~3mm from the KP200
//    body. v11 runs the heatsink along X at the front wall with the SSR facing
//    the rear, leaving a wiring zone in front of the terminals.
//  - Oven feed: 13mm cable gland REMOVED; FILSHU 15A 125V NEMA 5-15R snap-in
//    panel socket on the left wall. Cutout and local panel thickness are
//    APPROX (listing gives only the 27x27mm face, 35mm overall) — print
//    oven_socket_coupon first and set os_cut / os_panel_t from it.
//  - Inlet: FILSHU listing shows a snap-in module (no flange screws) about
//    50x30x30mm overall; flange screw holes now OFF by default so no open holes
//    sit beside live inlet terminals. Cutout kept at the coupon-validated
//    48x28.5mm; re-check with iec_test_coupon.
//  - Low intake slots on the front wall behind the heatsink; lid outlet slots
//    re-centred over the fin field. Both verified by ray test to give no
//    straight probe path to live parts (see docs).
//  - Printed heatsink locator fence and Shelly 1PM Gen4 pocket (37x42x16mm,
//    Shelly KB), both vertical-wall features: no supports.
//  - Divider pass-throughs are now open-top U-slots: wires drop in, the lid
//    closes them, and there is no ceiling to bridge.
//
//  2026-10 COMMENT-ONLY UPDATE (geometry unchanged; re-render verified
//  volumetrically identical to the repo STLs): the AC path, inlet and CYD
//  hole notes below were stale. Current AC path: FILSHU 15 A fused C14 inlet
//  -> Shelly 1PM Gen4 (heat path) -> SSR -> oven; KP200 tapped in parallel,
//  feeding only the CYD's USB adapter. (Inlet cutout: superseded by v11,
//  which uses the FILSHU panel spec.)
//  OPEN: the coordinate note says Y=0 is the REAR wall (inlet side), but the
//  v9.8 note calls y=0 the FRONT wall. Confirm on the physical box.
//  See docs/DESIGN-REVIEW-2026-10.md.
//
//  v10.3 CHANGE: KP200 tab recesses per user spec — SOLID 1.2mm pockets kept
//  at full plate strength, now with 45-degree sloped lead-in walls, rounded
//  corners, and widened 21 -> 22mm floor. Replaces (and reverts) the v10.2
//  through-slot construction, which was rejected: it traded plate strength
//  for support-free printing without being asked.
//
//  v10.1 CHANGE: CYD window shift corrected 3 -> 1mm to match the PRINTED,
//  physically validated part (board mounted, full display visible). The 3mm
//  value was derived from clip estimates; the 1mm print is ground truth.
//
//  v10 CHANGE: KP200 flush-mount rework from teardown measurements (faceplate
//  off). Window right-sized 65x73 -> 46x72 (body is 45x71). Added 1.2mm-deep
//  recesses for the yoke ears (19x17, 1mm proud) and 5mm through-clearance for
//  the two captive box screws 6mm outboard of the mounting holes (protrude 6mm).
//  Device now seats flush; Kasa faceplate snaps over it against the lid.
//
//  v9.9 CHANGE: display window cut now passes through the full standoff depth.
//  v9.8's shifted window crossed the two ESP32-end standoff bosses by ~1mm and
//  they protruded into the opening (caught on the printed v9.8 coupon). Bosses
//  are now shaved flush with the window wall; insert wall locally ~1.15mm there.
//
//  v9.8 CHANGE: display window 66 -> 65mm, SHIFTED 3mm toward the ESP32 end.
//  Mounted-board observation: viewable area is offset 3mm toward the ESP32 end
//  relative to the hole pattern (5mm clipped there, 0mm at USB end). Symmetric
//  coverage is impossible (needs 70mm > 69mm glass). BOARD NOW INSTALLS IN ONE
//  ORIENTATION: ESP32/flex end toward the front (y=0) wall.
//
//  v9.7 CHANGE: display window long axis 60 -> 66. With the board finally
//  screwed to the TRUE hole pattern (v9.5), the 60mm window clipped the
//  MEASURED 64mm viewable region (3mm ESP32 end / 1mm USB end). 66mm symmetric
//  is the minimal window covering the viewable area in either board rotation.
//
//  v9.6 CHANGE: 3Dman IEC cutout right-sized to the MEASURED insert body
//  (47 x 27.5 x 21.5mm): cutout 52x38 -> 48x28.5. The old oversize left open
//  gaps past the tapered flange edge. Added iec_trim_plate retrofit part for
//  shells already printed with the old cutout.
//
//  v9.5 CHANGE: CYD mounting hole pattern corrected 82x44 -> 78x42 (measured
//  on printed v9.4 lid + confirmed against DIYmall dimensional drawing: holes
//  4mm from edges of the 86x50 board). Added cyd_test_coupon part.
//
//  v9.1 CHANGE: relocated two AC-side lid bosses that collided with the
//  3Dman inlet body and the SSR heatsink corner (found in pre-print audit).
//
//  v9 CHANGE: Compact X1C-friendly flat layout while keeping BOTH AC modules.
//  - 3Dman fused IEC C14 + rocker + fuse module is the DEVICE POWER INPUT.
//    It mounts on the rear wall of the AC compartment.
//  - Kasa KP200 is still used as the SMART SHUTOFF / controlled receptacle.
//    It mounts face-up through the top lid, on the AC side.
//  - CYD display mounts face-up through the top lid, on the DC side.
//  - CYD is rotated 90 degrees in the top layout to reduce total width.
//  - SSR/heatsink stays inside the AC compartment with top vents above it.
//  - All cable/connector openings are on side/rear/top faces, not the bottom,
//    so the enclosure can sit flat on the bench.
//
//  Intended AC path (v9 era, SUPERSEDED — see 2026-10 note at top):
//    Wall -> external upstream safety/kill option if used -> 3Dman IEC input
//    -> KP200 line input -> KP200 controlled output -> SSR/load path -> oven.
//
//  NOTE: This is enclosure geometry only, not wiring approval. Verify current
//  ratings, fuse value, wire gauge, strain relief, grounding, creepage/clearance,
//  and the physical part dimensions before using with mains voltage.
//
//  Coordinate system:
//    X = width  (left AC side -> right DC side)
//    Y = depth  (rear wall -> front wall)
//    Z = height (floor -> lid)
// ============================================================================

/* [Render selector] */
part = "assembly"; // ["bottom","lid","bezel","assembly","all_flat","keepouts","iec_test_coupon","kp200_test_coupon","cyd_test_coupon","oven_socket_coupon","iec_trim_plate"]

/* [Box outer dimensions]
   v11: 230 x 155. Still fits the 256 x 256mm X1C bed with 13mm/side spare.
   The CYD is rotated 90 degrees on the DC side. */
box_w = 230;
box_d = 155;
box_h = 65;
wall_t = 3;
floor_t = 3;
lid_t = 3;

/* [AC/DC divider] */
divider_x = 157;            // v11: was 147
divider_t = 2;

/* [AC side: SSR + heatsink — v11 placement]
   MEASURED (Jul 2026): heatsink footprint 80 x 49.4mm, assembled stack 51mm
   tall, fins vertical, SSR bolted to the heatsink's vertical face.
   APPROX: SSR body 62 x 45 x 23.5mm (same-style SSR datasheet; the Inkbird
   listing gives no body size). The SSR sticks out sideways from the heatsink.
   v11 orientation: heatsink length along X against the front wall (with an
   air gap for the intake slots); SSR on the heatsink's REAR (-Y) face, so its
   terminals face the rear of the box with a wiring zone in front of them. */
hs_len_x  = 80;             // MEASURED
hs_dep_y  = 49.4;           // MEASURED
hs_h      = 51;             // MEASURED stack height (floor contact to top)
hs_x0     = 73;             // left end; clears the KP200 body (x <= 70) by 3mm
intake_gap = 8;             // air gap between heatsink and front wall
hs_y0     = box_d - wall_t - intake_gap - hs_dep_y;   // = 94.6
hs_clear  = 0.6;            // locator fence clearance per side
ssr_len_x = 62;             // APPROX
ssr_h_z   = 45;             // APPROX (SSR width, standing vertical)
ssr_dep_y = 23.5;           // APPROX (SSR thickness, protrudes toward -Y)
ssr_x0    = hs_x0 + (hs_len_x - ssr_len_x) / 2;
ssr_z0    = floor_t + (hs_h - ssr_h_z) / 2;
ssr_y0    = hs_y0 - ssr_dep_y;                         // terminal face plane
heatsink_top_z = floor_t + hs_h;

/* [AC side: FILSHU fused IEC C14 inlet + rocker/fuse module]
   Mounted on the REAR wall. APPROX: listing gives ~50 x 30 x 30mm overall and
   shows a snap-in module. The 48 x 28.5mm cutout is the coupon-validated size
   from v9.6; confirm the FILSHU snaps in with iec_test_coupon. */
inlet_face_w = 50;          // APPROX (listing overall)
inlet_face_h = 30;          // APPROX (listing overall)
inlet_body_depth = 28;      // APPROX (listing overall depth minus flange)
inlet_wire_clearance_depth = 20;   // insulated quick-connects + bend
inlet_cutout_w = 48.0;      // v11: FILSHU panel spec 47.0-48.0mm; 48.0 recommended for panels thicker than 1.5mm
inlet_cutout_h = 27.5;      // v11: FILSHU panel spec 27.0-27.5mm (v9.6-v10.3 used 28.5 for the 3Dman body)
inlet_clip_panel_t = 1.5;   // v11: FILSHU side clips are made for a 1.5mm panel; wall is thinned to this beside each clip edge
inlet_clip_relief_w = 3;    // relief strip width outboard of each side (width) edge
inlet_clip_relief_extra_h = 2;   // relief extends this far above/below the cutout
inlet_center_x = 118;
inlet_center_z = 31;
inlet_screw_pattern = "none";     // ["vertical","horizontal","none"] v11: FILSHU is snap-in; open screw holes would sit beside live terminals
inlet_screw_spacing = 40;
inlet_screw_dia = 3.4;

/* [AC side: KP200 smart outlet / smart shutoff]
   Top-lid mount. The KP200 face/yoke footprint is treated as 85 x 129mm.
   Here it is rotated so:
   - KP200 width runs along X
   - KP200 long mounting axis runs along Y
   - KP200 body depth runs downward from the lid along Z

   OPEN QUESTION: confirm the exact KP200 body/yoke dimensions and screw
   spacing on the physical device before final print. */
kp_wid_x = 85;
kp_len_y = 129;
kp_depth_z = 44;
kp_screw_spacing = 83;      // standard device/yoke screw spacing, along Y here
kp_center_x = wall_t + 2 + kp_wid_x / 2;
kp_center_y = box_d - wall_t - 6 - kp_len_y / 2;
kp_window_x = 46;           // v10: was 65. MEASURED recessed body is 45mm wide; 0.5mm/side. Old opening was 20mm oversize
kp_window_y = 72;           // v10: was 73 (v9.2). MEASURED body length 71mm; 0.5mm/side
// v10 flush-mount features (from KP200 teardown with faceplate removed):
kp_ear_w = 22;              // v10.3: was 21; widened per request. Recess FLOOR width, X (tab measured 19mm wide, 1mm proud)
kp_ear_h = 20;              // recess floor height, Y (tab measured 17mm tall)
kp_ear_recess = 1.2;        // recess depth into lid outer face; tab proud 1mm + tolerance
kp_ear_corner_r = 3;        // v10.3: rounded recess corners
kp_ear_chamfer = 1.2;       // v10.3: 45-degree sloped lead-in walls; opening at the surface is 2*this larger than the floor. SOLID pocket — full plate strength retained.
kp_capscrew_offset = 6;     // KP200's captive box screws sit 6mm OUTBOARD of each mounting hole...
kp_capscrew_protrude = 6;   // ...and protrude 6mm rearward: they need through-clearance to seat flush
kp_capscrew_clear_dia = 5;  // clears the ~3.5mm screw shank; kept small because it nicks the 9mm yoke boss edge (insert wall stays >1.2mm)
kp_lid_boss_h = 7;
kp_lid_boss_dia = 9;
kp_insert_dia = 4.5;
kp_insert_depth = 5;
kp_screw_clear_dia = 3.8;

/* [AC side: oven feed — FILSHU 15A 125V NEMA 5-15R snap-in panel socket]
   v11: replaces the 13mm cable gland (too small for SJT cord). LEFT wall.
   Spec (via owner, Oct 2026): 27 x 27mm face, ~35mm overall depth, square
   panel cutout 24.5-25.0mm depending on panel thickness. The panel thickness
   the snap clips accept is NOT specified — print oven_socket_coupon
   (cuts 24.5 / 24.75 / 25.0 x panels 2.0 / 2.5 / 3.0) and set os_panel_t. */
os_face      = 27;          // listing
os_depth     = 35;          // listing, overall incl. face
os_cut       = 24.75;       // spec 24.5-25.0mm square; confirm with coupon
os_panel_t   = 2.5;         // APPROX local wall thickness for the clips, set from coupon
os_pocket_margin = 3;       // thinned-wall pocket extends this far past the face
os_center_y  = 30;
os_center_z  = 22;

/* [AC side: Shelly 1PM Gen4 pocket]
   37 x 42 x 16mm (Shelly KB). Stands on edge against the left wall, far from
   the heatsink (its ambient limit is 40 C). */
shelly_h = 37; shelly_w = 42; shelly_t = 16;
shelly_clear = 0.6;
shelly_y0 = 64;             // clears the lid-screw boss at y 51-59
shelly_rib_t = 2;
shelly_rib_h = 20;
shelly_lip_h = 8;

/* [AC side: KP200 recessed body — MEASURED 70.5 x 45 x 45mm (Jul 2026)]
   Used only for keepouts/interference checks. */
kp_body_x = 45; kp_body_y = 70.5; kp_body_z = 45;

/* [DC side: CYD top-lid mount]
   RESOLVED (v9.5): hole pattern measured on the AITRIP board at 77.5 x 42mm.
   Compact v9 rotates the CYD 90 degrees so the 90mm board length runs front/back
   instead of left/right. This saves about 25-30mm of total enclosure width.
   Set cyd_rotate_90_for_compact = false only if you want the earlier landscape
   physical mounting orientation; you will likely need to widen box_w. */
cyd_rotate_90_for_compact = true;
cyd_raw_pcb_w = 90;
cyd_raw_pcb_h = 60;
cyd_raw_hole_w = 77.5;  // v9.5: was 82 (assumed). MEASURED center-to-center on the physical board: 77.5mm. (DIYmall drawing implies 78; measured board wins — clone variants differ)
cyd_raw_hole_h = 42;    // v9.5: was 44 (assumed). MEASURED center-to-center on the physical board: 42mm
cyd_raw_display_w = 65;    // v9.8: was 66 (v9.7), 60 before. MEASURED: viewable region is 64mm and sits OFFSET
                           // 3mm toward the ESP32 end relative to the hole-pattern center (observed on mounted
                           // board: 5mm clipped ESP32 end, 0mm USB end with the old 60mm centered window).
                           // 65mm + 3mm shift covers it with 0.5mm margin per end. A symmetric window can no
                           // longer work: full coverage would need 70mm > the 69mm glass.
cyd_window_shift = 1;      // v10.1: was 3 (derived from clip observations). 1mm PHYSICALLY VALIDATED on a printed part with the board mounted — full display visible. Bonus: at 1mm the window edge stays 1mm clear of the standoff bosses (no shave engages) and the bezel countersinks keep 2mm clearance.
                           // CONSEQUENCE: the board installs in ONE orientation only — ESP32 end toward the
                           // shifted side of the window (toward the FRONT wall, y=0, in the rotated layout).
                           // The hole pattern is symmetric, so just rotate the board to match at assembly.
cyd_window_shift_x = cyd_rotate_90_for_compact ? 0 : -cyd_window_shift;
cyd_window_shift_y = cyd_rotate_90_for_compact ? -cyd_window_shift : 0;
cyd_raw_display_h = 48;    // v9.4: was 46 (= glass width); +1mm/side because measured glass sits 0.5-1mm off-center between mounting holes. Symmetric widening is rotation-agnostic (hole pattern lets the board install either way).
cyd_pcb_w = cyd_rotate_90_for_compact ? cyd_raw_pcb_h : cyd_raw_pcb_w;
cyd_pcb_h = cyd_rotate_90_for_compact ? cyd_raw_pcb_w : cyd_raw_pcb_h;
cyd_hole_w = cyd_rotate_90_for_compact ? cyd_raw_hole_h : cyd_raw_hole_w;
cyd_hole_h = cyd_rotate_90_for_compact ? cyd_raw_hole_w : cyd_raw_hole_h;
cyd_display_w = cyd_rotate_90_for_compact ? cyd_raw_display_h : cyd_raw_display_w;
cyd_display_h = cyd_rotate_90_for_compact ? cyd_raw_display_w : cyd_raw_display_h;
cyd_center_x = divider_x + (box_w - divider_x) / 2;
cyd_center_y = box_d / 2;
cyd_lid_standoff_h = 6;
cyd_lid_boss_dia = 8.5;     // v9.2: was 7; 1.4mm insert wall too thin, now 2.15mm
cyd_insert_dia = 4.2;
cyd_insert_depth = 4;
cyd_screw_clear_dia = 3.2;

/* [DC side: USB-C access slot]
   Side-wall slot aligned with the CYD area. Exact position depends on your
   CYD variant's USB-C connector location. */
usb_slot_w_y = 16;
usb_slot_h_z = 8;
usb_slot_center_y = cyd_center_y + 24;
usb_slot_center_z = box_h - lid_t - 12;

/* [DC side: MAX6675 on floor] */
max_board_w = 18;
max_board_h = 15;
max_hole_dx = 13;
max_hole_dy = 10;
max_boss_dia = 6;
max_pos_x = divider_x + 20;
max_pos_y = 30;

/* [DC side: thermocouple pass-through gland, right wall] */
tc_gland_dia = 8;
tc_gland_y = 45;
tc_gland_z = 18;

/* [Divider pass-throughs]
   Keep AC/DC crossings low and deliberate. v11: open-top U-slots — wires drop
   in from above and the lid closes the top; no ceiling to bridge. */
ctrl_hole_dia = 6;
ctrl_hole_y = 36;
ctrl_hole_z = 15;           // slot bottom (radius centre)
pwr_hole_dia = 6;
pwr_hole_y = 54;
pwr_hole_z = 15;

/* [Lid outlet slots over the heatsink fin field — v11]
   Slots run along X (along the heatsink length), stepped in Y across the fins. */
vent_slot_w = 3;
vent_slot_len = 66;
vent_slot_count = 7;
vent_slot_gap = 6;
vent_center_x = hs_x0 + hs_len_x / 2;
vent_center_y = hs_y0 + hs_dep_y / 2;

/* [Front-wall intake slots behind the heatsink — v11]
   Vertical slots (3mm bridge at the top only). Behind them is the heatsink's
   outer fin, 8mm in; verified by ray test to give no straight path to live parts. */
intake_slot_w = 3;
intake_slot_count = 11;
intake_slot_gap = 6;
intake_z0 = floor_t + 3;
intake_z1 = 30;

/* [Heatsink locator fence — v11] */
fence_t = 2;
fence_h = 5;
fence_stub = 8;

/* [Lid mounting bosses / M3 heat-set inserts]
   Bosses are placed around the top-mounted KP200 and CYD keepouts. */
boss_outer_dia = 8;
boss_insert_dia = 4.2;
boss_insert_depth = 5;
lid_screw_clear_dia = 3.4;
lid_screw_csk_dia = 6.4;
lid_screw_csk_depth = 2.0;

/* [Top bezel ring around CYD window] */
bezel_thickness = 3.0;
bezel_overhang = 5;
bezel_screw_dia = 3.2;
bezel_screw_csk = 6.4;

/* [Rubber feet]
   Recesses are cut into the bottom so nothing protrudes below the base. */
foot_inset = 12;
foot_dia = 12;
foot_recess_depth = 0.8;

/* [Preview helpers] */
show_components = true;
component_alpha = 0.20;

/* [Print/render] */
$fn = 48;
eps = 0.02;

// ============================================================================
//  Derived values
// ============================================================================
shell_h  = box_h - lid_t;
inner_h  = shell_h - floor_t;
inner_d  = box_d - 2 * wall_t;

ac_x_min = wall_t;
ac_x_max = divider_x - divider_t / 2;
ac_w     = ac_x_max - ac_x_min;

dc_x_min = divider_x + divider_t / 2;
dc_x_max = box_w - wall_t;
dc_w     = dc_x_max - dc_x_min;

bezel_w = cyd_pcb_w + 2 * bezel_overhang;
bezel_h = cyd_pcb_h + 2 * bezel_overhang;

boss_positions = [
    [10, 10],
    [80, 10],           // v9.1: moved from [divider_x-10, 10] — collided with 3Dman inlet body (x92-144, y3-37)
    [10, 55],
    [64, box_d - 5],    // v11: was [88, box_d-10] (v9.1), which now sits inside the heatsink; merges into the front wall, clear of the KP200 faceplate (y <= 146)
    [dc_x_min + 10, 10],
    [dc_x_max - 10, 10],
    [dc_x_min + 10, box_d - 10],
    [dc_x_max - 10, box_d - 10]
];

cyd_hole_positions = [
    [cyd_center_x - cyd_hole_w / 2, cyd_center_y - cyd_hole_h / 2],
    [cyd_center_x + cyd_hole_w / 2, cyd_center_y - cyd_hole_h / 2],
    [cyd_center_x - cyd_hole_w / 2, cyd_center_y + cyd_hole_h / 2],
    [cyd_center_x + cyd_hole_w / 2, cyd_center_y + cyd_hole_h / 2]
];

kp_screw_positions = [
    [kp_center_x, kp_center_y - kp_screw_spacing / 2],
    [kp_center_x, kp_center_y + kp_screw_spacing / 2]
];

echo("=== Compact flat bench enclosure v11.0 / X1C fit / KP200 lid mount + FILSHU inlet + 5-15R oven socket ===");
echo(str("Box: ", box_w, " x ", box_d, " x ", box_h, " mm"));
echo(str("Heatsink x ", hs_x0, "-", hs_x0 + hs_len_x, " y ", hs_y0, "-", hs_y0 + hs_dep_y, "; SSR terminal face y ", ssr_y0, "; lid clearance ", shell_h - heatsink_top_z, " mm"));
echo(str("Wiring zone in front of SSR terminals: ", ssr_y0 - (wall_t + inlet_body_depth + inlet_wire_clearance_depth), " mm (to inlet keepout)"));
assert(hs_x0 + hs_len_x + hs_clear + fence_t <= divider_x - divider_t / 2, "heatsink fence hits divider");
assert(shell_h - heatsink_top_z >= 5, "heatsink stack too tall for lid");
echo(str("CYD rotated for compact mount: ", cyd_rotate_90_for_compact));
echo(str("Bottom shell height: ", shell_h, " mm; internal usable height: ", inner_h, " mm"));
echo(str("AC compartment interior: ", ac_w, " x ", inner_d, " mm"));
echo(str("DC compartment interior: ", dc_w, " x ", inner_d, " mm"));
echo(str("3Dman IEC rear cutout center X/Z: ", inlet_center_x, "/", inlet_center_z));
echo(str("KP200 top opening center X/Y: ", kp_center_x, "/", kp_center_y));
echo(str("Heatsink top Z: ", heatsink_top_z, " mm; shell inner top Z: ", shell_h, " mm"));

// ============================================================================
//  Top-level render
// ============================================================================
if (part == "bottom") bottom_shell();
else if (part == "lid") lid_printable();
else if (part == "bezel") top_bezel();
else if (part == "assembly") assembly_view();
else if (part == "all_flat") print_layout();
else if (part == "iec_test_coupon") iec_test_coupon();
else if (part == "kp200_test_coupon") kp200_test_coupon();
else if (part == "cyd_test_coupon") cyd_test_coupon();
else if (part == "iec_trim_plate") iec_trim_plate();
else if (part == "oven_socket_coupon") oven_socket_coupon();
else if (part == "keepouts") component_keepouts();

// ============================================================================
//  Modules — main parts
// ============================================================================

module bottom_shell() {
    difference() {
        union() {
            // Open-top shell
            difference() {
                cube([box_w, box_d, shell_h]);
                translate([wall_t, wall_t, floor_t])
                    cube([box_w - 2 * wall_t, box_d - 2 * wall_t, shell_h - floor_t + eps]);
            }

            // Internal AC/DC divider
            translate([divider_x - divider_t / 2, 0, 0])
                cube([divider_t, box_d, shell_h]);

            // Lid-screw bosses
            for (p = boss_positions)
                translate([p[0], p[1], floor_t]) lid_boss();

            // MAX6675 standoff bosses on DC floor
            for (dx = [-max_hole_dx / 2, max_hole_dx / 2])
                for (dy = [-max_hole_dy / 2, max_hole_dy / 2])
                    translate([max_pos_x + dx, max_pos_y + dy, floor_t]) max_boss();

            // v11: heatsink locator fence (vertical walls only: no supports)
            heatsink_fence();

            // v11: Shelly 1PM Gen4 pocket on the left wall
            shelly_pocket();
        }

        // ---- Wall cutouts / openings ----

        // v11: FILSHU IEC inlet cutout + clip reliefs, rear wall
        translate([inlet_center_x, 0, inlet_center_z]) inlet_cut(wall_t);

        // Mounting screw holes for the 3Dman inlet face/flange.
        if (inlet_screw_pattern == "vertical") {
            for (dz = [-inlet_screw_spacing / 2, inlet_screw_spacing / 2])
                translate([inlet_center_x, -eps, inlet_center_z + dz])
                    rotate([-90, 0, 0]) cylinder(d = inlet_screw_dia, h = wall_t + 2 * eps);
        }
        if (inlet_screw_pattern == "horizontal") {
            for (dx = [-inlet_screw_spacing / 2, inlet_screw_spacing / 2])
                translate([inlet_center_x + dx, -eps, inlet_center_z])
                    rotate([-90, 0, 0]) cylinder(d = inlet_screw_dia, h = wall_t + 2 * eps);
        }

        // v11: oven feed — NEMA 5-15R snap-in socket, left wall (replaces gland)
        oven_socket_cut();

        // v11: front-wall intake slots behind the heatsink
        intake_slots();

        // Thermocouple gland, right side wall
        translate([box_w - wall_t - eps, tc_gland_y, tc_gland_z])
            rotate([0, 90, 0]) cylinder(d = tc_gland_dia, h = wall_t + 2 * eps);

        // USB-C side access slot, right side wall
        translate([box_w - wall_t - eps,
                   usb_slot_center_y - usb_slot_w_y / 2,
                   usb_slot_center_z - usb_slot_h_z / 2])
            cube([wall_t + 2 * eps, usb_slot_w_y, usb_slot_h_z]);

        // v11: SSR control and CYD power pass-throughs as open-top U-slots
        divider_u_slot(ctrl_hole_y, ctrl_hole_z, ctrl_hole_dia);
        divider_u_slot(pwr_hole_y, pwr_hole_z, pwr_hole_dia);

        // Rubber-foot recesses; shallow cuts only, no protruding feet in model
        for (x = [foot_inset, box_w - foot_inset])
            for (y = [foot_inset, box_d - foot_inset])
                translate([x, y, -eps]) cylinder(d = foot_dia, h = foot_recess_depth + eps);
    }
}

// Print-ready lid orientation:
//   - exterior/top face is at Z=0, so print it face-down for a clean top
//   - interior CYD and KP200 bosses grow upward from the inside of the lid
module lid_print_orientation() {
    difference() {
        union() {
            cube([box_w, box_d, lid_t]);

            // CYD mounting bosses on inside of lid
            for (p = cyd_hole_positions)
                translate([p[0], p[1], lid_t]) cyd_lid_boss(cyd_lid_standoff_h);

            // KP200 yoke screw bosses on inside of lid
            for (p = kp_screw_positions)
                translate([p[0], p[1], lid_t]) kp_lid_boss(kp_lid_boss_h);
        }

        // Lid screw clearance holes + exterior countersinks
        for (p = boss_positions) {
            translate([p[0], p[1], -eps])
                cylinder(d = lid_screw_clear_dia, h = lid_t + max(cyd_lid_standoff_h, kp_lid_boss_h) + 2 * eps);
            translate([p[0], p[1], -eps])
                cylinder(d1 = lid_screw_csk_dia, d2 = lid_screw_clear_dia, h = lid_screw_csk_depth + eps);
        }

        // KP200 access opening through top lid
        translate([kp_center_x - kp_window_x / 2,
                   kp_center_y - kp_window_y / 2,
                   -eps])
            cube([kp_window_x, kp_window_y, lid_t + kp_lid_boss_h + 2 * eps]);

        // KP200 mounting screw clearance holes through lid / boss centers
        for (p = kp_screw_positions)
            translate([p[0], p[1], -eps])
                cylinder(d = kp_screw_clear_dia, h = lid_t + kp_lid_boss_h + 2 * eps);

        // v10.3: yoke tab recesses — solid pockets with rounded corners and
        // 45-degree sloped lead-in walls (outer face at Z=0 in model frame)
        for (p = kp_screw_positions)
            translate([p[0], p[1], 0]) kp_tab_recess();

        // v10: through-clearance for the KP200's captive box screws (outboard of each mounting hole)
        for (dy = [-(kp_screw_spacing / 2 + kp_capscrew_offset), kp_screw_spacing / 2 + kp_capscrew_offset])
            translate([kp_center_x, kp_center_y + dy, -eps])
                cylinder(d = kp_capscrew_clear_dia, h = lid_t + kp_lid_boss_h + 2 * eps);

        // CYD display/touch opening through top lid
        // v9.9: cut extends through the FULL standoff depth, not just the plate.
        // With the v9.8 window shift, the two ESP32-end standoffs crossed the
        // window edge by ~1mm; this shaves them flush with the window wall.
        // Their insert wall thins to ~1.15mm over a small arc on that side.
        translate([cyd_center_x - cyd_display_w / 2 + cyd_window_shift_x,
                   cyd_center_y - cyd_display_h / 2 + cyd_window_shift_y,
                   -eps])
            cube([cyd_display_w, cyd_display_h, lid_t + cyd_lid_standoff_h + 2 * eps]);

        // CYD screw clearance holes through top lid / boss centers
        for (p = cyd_hole_positions)
            translate([p[0], p[1], -eps])
                cylinder(d = cyd_screw_clear_dia, h = lid_t + cyd_lid_standoff_h + 2 * eps);

        // v11: outlet slots over the heatsink fin field, running along X
        vent_span = (vent_slot_count - 1) * vent_slot_gap;
        for (i = [0 : vent_slot_count - 1])
            translate([vent_center_x - vent_slot_len / 2,
                       vent_center_y - vent_span / 2 + i * vent_slot_gap - vent_slot_w / 2,
                       -eps])
                cube([vent_slot_len, vent_slot_w, lid_t + 2 * eps]);
    }
}

module top_bezel() {
    difference() {
        translate([cyd_center_x - bezel_w / 2, cyd_center_y - bezel_h / 2, 0])
            cube([bezel_w, bezel_h, bezel_thickness]);

        // Visible display/touch window
        translate([cyd_center_x - cyd_display_w / 2 + cyd_window_shift_x, cyd_center_y - cyd_display_h / 2 + cyd_window_shift_y, -eps])
            cube([cyd_display_w, cyd_display_h, bezel_thickness + 2 * eps]);

        // CYD screw clearance/countersink holes
        for (p = cyd_hole_positions) {
            translate([p[0], p[1], -eps])
                cylinder(d = bezel_screw_dia, h = bezel_thickness + 2 * eps);
            translate([p[0], p[1], bezel_thickness - lid_screw_csk_depth])
                cylinder(d1 = bezel_screw_dia, d2 = bezel_screw_csk, h = lid_screw_csk_depth + eps);
        }
    }
}

// ============================================================================
//  Test coupons — print these first before committing the full shell/lid
// ============================================================================

// v9.6: retrofit trim plate / escutcheon for shells printed with the old
// oversized 52x38 IEC cutout. Sits between the module flange and the wall's
// exterior face; the module's own screws clamp it. Outer rectangle covers the
// old hole with margin; inner opening passes the MEASURED 47x27.5 body.
// Shells printed from v9.6 onward have the right-sized cutout and don't need it.
// NOTE: adds 1.5mm to the screw stack — confirm screw engagement.
trim_plate_w = 58;      // covers old 52 cutout with 3mm/side
trim_plate_h = 48;      // covers old 38 cutout with 5mm/side; screw holes keep 2.3mm edge margin
trim_plate_t = 1.5;

module iec_trim_plate() {
    cx = trim_plate_w / 2;
    cy = trim_plate_h / 2;
    difference() {
        cube([trim_plate_w, trim_plate_h, trim_plate_t]);
        // body opening (same as v9.6 wall cutout)
        translate([cx - inlet_cutout_w / 2, cy - inlet_cutout_h / 2, -eps])
            cube([inlet_cutout_w, inlet_cutout_h, trim_plate_t + 2 * eps]);
        // flange screw pass-throughs (vertical pattern in the shell)
        for (dy = [-inlet_screw_spacing / 2, inlet_screw_spacing / 2])
            translate([cx, cy + dy, -eps])
                cylinder(d = inlet_screw_dia, h = trim_plate_t + 2 * eps);
    }
}

module iec_test_coupon() {
    coupon_w = inlet_face_w + 16;
    coupon_h = inlet_face_h + 16;
    coupon_t = wall_t;
    cx = coupon_w / 2;
    cy = coupon_h / 2;

    difference() {
        cube([coupon_w, coupon_h, coupon_t]);

        // v11: same cutout + clip reliefs as the shell (reliefs on the top face)
        translate([cx, cy, 0]) rotate([90, 0, 0]) inlet_cut(coupon_t);

        if (inlet_screw_pattern == "vertical") {
            for (dy = [-inlet_screw_spacing / 2, inlet_screw_spacing / 2])
                translate([cx, cy + dy, -eps])
                    cylinder(d = inlet_screw_dia, h = coupon_t + 2 * eps);
        }
        if (inlet_screw_pattern == "horizontal") {
            for (dx = [-inlet_screw_spacing / 2, inlet_screw_spacing / 2])
                translate([cx + dx, cy, -eps])
                    cylinder(d = inlet_screw_dia, h = coupon_t + 2 * eps);
        }
    }
}

// v10.3: one KP200 tab recess, centered at origin, outer face at Z=0.
// A SOLID 1.2mm pocket (full plate strength) whose walls slope outward at 45
// degrees toward the surface, with rounded corners throughout.
module rounded_rect_2d(w, h, r) {
    offset(r = r) offset(delta = -r) square([w, h], center = true);
}
module kp_tab_recess() {
    hull() {
        // wide opening at the outer surface
        translate([0, 0, -eps])
            linear_extrude(0.01)
                rounded_rect_2d(kp_ear_w + 2 * kp_ear_chamfer, kp_ear_h + 2 * kp_ear_chamfer, kp_ear_corner_r);
        // recess floor outline
        translate([0, 0, kp_ear_recess - 0.01])
            linear_extrude(0.01)
                rounded_rect_2d(kp_ear_w, kp_ear_h, kp_ear_corner_r);
    }
}

module kp200_test_coupon() {
    coupon_w = kp_wid_x + 20;
    coupon_h = kp_len_y + 20;
    coupon_t = lid_t;
    cx = coupon_w / 2;
    cy = coupon_h / 2;

    difference() {
        union() {
            cube([coupon_w, coupon_h, coupon_t]);
            for (dy = [-kp_screw_spacing / 2, kp_screw_spacing / 2])
                translate([cx, cy + dy, coupon_t]) kp_lid_boss(kp_lid_boss_h);
        }

        translate([cx - kp_window_x / 2,
                   cy - kp_window_y / 2,
                   -eps])
            cube([kp_window_x, kp_window_y, coupon_t + kp_lid_boss_h + 2 * eps]);

        for (dy = [-kp_screw_spacing / 2, kp_screw_spacing / 2])
            translate([cx, cy + dy, -eps])
                cylinder(d = kp_screw_clear_dia, h = coupon_t + kp_lid_boss_h + 2 * eps);

        // v10.3: yoke tab recesses (same sloped construction as lid)
        for (dy = [-kp_screw_spacing / 2, kp_screw_spacing / 2])
            translate([cx, cy + dy, 0]) kp_tab_recess();

        // v10: captive box screw through-clearance
        for (dy = [-(kp_screw_spacing / 2 + kp_capscrew_offset), kp_screw_spacing / 2 + kp_capscrew_offset])
            translate([cx, cy + dy, -eps])
                cylinder(d = kp_capscrew_clear_dia, h = coupon_t + kp_lid_boss_h + 2 * eps);
    }
}

// ============================================================================
//  v11 helper modules — all support-free in print orientation
// ============================================================================

// NEMA 5-15R snap-in socket: square body cutout through the left wall, plus a
// pocket from the INSIDE that thins the wall to os_panel_t around the cutout so
// the snap clips can seat. The pocket's top edge is a 45-degree slope, so there
// is no ceiling to bridge.
module oven_socket_cut() {
    translate([-eps, os_center_y - os_cut / 2, os_center_z - os_cut / 2])
        cube([wall_t + 2 * eps, os_cut, os_cut]);
    if (os_panel_t < wall_t) {
        d  = wall_t - os_panel_t;
        ps = os_face + 2 * os_pocket_margin;
        zb = os_center_z - ps / 2;
        zt = os_center_z + ps / 2;
        hull() {
            translate([os_panel_t, os_center_y - ps / 2, zb])
                cube([d + eps, ps, zt - zb - d]);
            translate([wall_t, os_center_y - ps / 2, zb])
                cube([eps, ps, zt - zb]);
        }
    }
}

// FILSHU inlet: cutout per the panel spec, plus a relief strip beside each
// side (width) edge, cut from the INSIDE (local +Y), thinning the wall to
// inlet_clip_panel_t so the side clips can snap. Origin = cutout centre on the
// OUTER face; the wall runs from y=0 (outside) to y=t (inside). Each relief
// has a 45-degree top so no ceiling needs bridging when the wall prints upright.
module inlet_cut(t) {
    translate([-inlet_cutout_w / 2, -eps, -inlet_cutout_h / 2])
        cube([inlet_cutout_w, t + 2 * eps, inlet_cutout_h]);
    if (inlet_clip_panel_t < t) {
        d  = t - inlet_clip_panel_t;
        hz = inlet_cutout_h / 2 + inlet_clip_relief_extra_h;
        for (s = [-1, 1])
            hull() {
                translate([s > 0 ? inlet_cutout_w / 2 - eps : -inlet_cutout_w / 2 - inlet_clip_relief_w,
                           inlet_clip_panel_t, -hz])
                    cube([inlet_clip_relief_w + eps, d + eps, 2 * hz - d]);
                translate([s > 0 ? inlet_cutout_w / 2 - eps : -inlet_cutout_w / 2 - inlet_clip_relief_w,
                           t, -hz])
                    cube([inlet_clip_relief_w + eps, eps, 2 * hz]);
            }
    }
}

// Front-wall intake slots, vertical, centred on the heatsink length.
module intake_slots() {
    span = (intake_slot_count - 1) * intake_slot_gap;
    for (i = [0 : intake_slot_count - 1])
        translate([vent_center_x - span / 2 + i * intake_slot_gap - intake_slot_w / 2,
                   box_d - wall_t - eps,
                   intake_z0])
            cube([intake_slot_w, wall_t + 2 * eps, intake_z1 - intake_z0]);
}

// Open-top U-slot through the divider: round bottom at z, open to the top edge.
module divider_u_slot(y, z, d) {
    translate([divider_x - divider_t / 2 - eps, y, z])
        rotate([0, 90, 0]) cylinder(d = d, h = divider_t + 2 * eps);
    translate([divider_x - divider_t / 2 - eps, y - d / 2, z])
        cube([divider_t + 2 * eps, d, shell_h - z + eps]);
}

// Locator fence: full-depth walls at both heatsink ends plus short corner
// stubs. Stubs stay outside the SSR (x) and intake slot (x) ranges.
module heatsink_fence() {
    xl = hs_x0 - hs_clear - fence_t;
    xr = hs_x0 + hs_len_x + hs_clear;
    yl = hs_y0 - hs_clear - fence_t;
    yh = hs_y0 + hs_dep_y + hs_clear;
    for (x = [xl, xr])
        translate([x, yl, floor_t - eps]) cube([fence_t, yh + fence_t - yl, fence_h + eps]);
    for (y = [yl, yh]) {
        translate([xl, y, floor_t - eps]) cube([fence_t + fence_stub, fence_t, fence_h + eps]);
        translate([xr - fence_stub, y, floor_t - eps]) cube([fence_t + fence_stub, fence_t, fence_h + eps]);
    }
}

// Shelly 1PM Gen4 stands on edge against the left wall between two ribs,
// held by a low front lip. Top is open for its terminals.
module shelly_pocket() {
    iw = shelly_w + 2 * shelly_clear;
    it = shelly_t + 2 * shelly_clear;
    for (y = [shelly_y0 - shelly_rib_t, shelly_y0 + iw])
        translate([wall_t - eps, y, floor_t - eps])
            cube([it + shelly_rib_t + eps, shelly_rib_t, shelly_rib_h + eps]);
    translate([wall_t + it, shelly_y0 - shelly_rib_t, floor_t - eps])
        cube([shelly_rib_t, iw + 2 * shelly_rib_t, shelly_lip_h + eps]);
}

// Coupon: 3 body-cutout sizes (rows, Y) x 3 panel thicknesses (columns, X).
// Printed flat; the outer face is the bed side, the thinned pocket is on top.
// Dimples mark each cell: dots along the left edge = row (cut size),
// dots along the top edge = column (panel thickness).
os_coupon_cuts   = [24.5, 24.75, 25.0];   // spec range
os_coupon_panels = [os_panel_t - 0.5, os_panel_t, os_panel_t + 0.5];
module oven_socket_coupon() {
    cell = os_face + 2 * os_pocket_margin + 5;
    ps   = os_face + 2 * os_pocket_margin;
    difference() {
        cube([3 * cell, 3 * cell, wall_t]);
        for (r = [0 : 2]) for (c = [0 : 2]) {
            cx = c * cell + cell / 2;
            cy = r * cell + cell / 2;
            cut = os_coupon_cuts[r];
            pt  = min(os_coupon_panels[c], wall_t);
            translate([cx - cut / 2, cy - cut / 2, -eps]) cube([cut, cut, wall_t + 2 * eps]);
            if (pt < wall_t)
                translate([cx - ps / 2, cy - ps / 2, pt]) cube([ps, ps, wall_t - pt + eps]);
            for (k = [0 : r]) translate([c * cell + 1.2, cy - 4 + k * 3, wall_t - 0.8]) cylinder(d = 1.6, h = 1, $fn = 16);
            for (k = [0 : c]) translate([cx - 4 + k * 3, r * cell + cell - 1.2, wall_t - 0.8]) cylinder(d = 1.6, h = 1, $fn = 16);
        }
    }
}

// Component keepouts as boxes [name, [x0,y0,z0], [x1,y1,z1]] — echoed for the
// verification scripts and drawn by component_previews().
keepouts = [
    ["heatsink", [hs_x0, hs_y0, floor_t], [hs_x0 + hs_len_x, hs_y0 + hs_dep_y, floor_t + hs_h]],
    ["ssr", [ssr_x0, ssr_y0, ssr_z0], [ssr_x0 + ssr_len_x, hs_y0, ssr_z0 + ssr_h_z]],
    ["ssr_wiring_zone", [ssr_x0, ssr_y0 - 20, ssr_z0], [ssr_x0 + ssr_len_x, ssr_y0, ssr_z0 + ssr_h_z]],
    ["inlet", [inlet_center_x - inlet_cutout_w / 2, wall_t, inlet_center_z - inlet_cutout_h / 2],
              [inlet_center_x + inlet_cutout_w / 2, wall_t + inlet_body_depth + inlet_wire_clearance_depth, inlet_center_z + inlet_cutout_h / 2]],
    ["oven_socket", [os_panel_t, os_center_y - os_face / 2, os_center_z - os_face / 2],
                    [os_depth, os_center_y + os_face / 2, os_center_z + os_face / 2]],
    ["shelly", [wall_t + shelly_clear, shelly_y0 + shelly_clear, floor_t],
               [wall_t + shelly_clear + shelly_t, shelly_y0 + shelly_clear + shelly_w, floor_t + shelly_h]],
    ["kp200_body", [kp_center_x - kp_body_x / 2, kp_center_y - kp_body_y / 2, shell_h - kp_body_z],
                   [kp_center_x + kp_body_x / 2, kp_center_y + kp_body_y / 2, shell_h]],
    ["cyd_pcb", [cyd_center_x - cyd_pcb_w / 2, cyd_center_y - cyd_pcb_h / 2, shell_h - cyd_lid_standoff_h - 1.6],
                [cyd_center_x + cyd_pcb_w / 2, cyd_center_y + cyd_pcb_h / 2, shell_h - cyd_lid_standoff_h]],
    ["max6675", [max_pos_x - max_board_w / 2, max_pos_y - max_board_h / 2, floor_t + 5],
                [max_pos_x + max_board_w / 2, max_pos_y + max_board_h / 2, floor_t + 6.6]]
];
for (k = keepouts) echo(str("KO|", k[0], "|", k[1][0], "|", k[1][1], "|", k[1][2], "|", k[2][0], "|", k[2][1], "|", k[2][2]));

module component_keepouts() {
    for (k = keepouts) translate(k[1]) cube(k[2] - k[1]);
}

// ============================================================================
//  Helper modules — bosses
// ============================================================================

module lid_boss() {
    boss_h = inner_h - 0.2;
    difference() {
        cylinder(d = boss_outer_dia, h = boss_h);
        translate([0, 0, boss_h - boss_insert_depth + eps])
            cylinder(d = boss_insert_dia, h = boss_insert_depth + eps);
    }
}

// v9.5: CYD hole-pattern test coupon. Replicates the lid's CYD region 1:1 —
// same plate thickness, display window, standoff bosses, insert pockets, and
// screw clearance bores — so the physical board can be test-mounted before
// committing to the full lid print. Pattern is symmetric; no mirroring needed.
module cyd_test_coupon() {
    cw = cyd_display_w + 2 * (cyd_lid_boss_dia + 4);   // plate width
    ch = cyd_hole_h + cyd_lid_boss_dia + 10;           // plate height
    cx = cw / 2; cy = ch / 2;
    holes = [
        [cx - cyd_hole_w / 2, cy - cyd_hole_h / 2],
        [cx + cyd_hole_w / 2, cy - cyd_hole_h / 2],
        [cx - cyd_hole_w / 2, cy + cyd_hole_h / 2],
        [cx + cyd_hole_w / 2, cy + cyd_hole_h / 2]
    ];
    difference() {
        union() {
            cube([cw, ch, lid_t]);
            for (p = holes)
                translate([p[0], p[1], lid_t]) cyd_lid_boss(cyd_lid_standoff_h);
        }
        translate([cx - cyd_display_w / 2 + cyd_window_shift_x, cy - cyd_display_h / 2 + cyd_window_shift_y, -eps])
            cube([cyd_display_w, cyd_display_h, lid_t + cyd_lid_standoff_h + 2 * eps]);  // v9.9: full-depth, shaves boss intrusion
        for (p = holes)
            translate([p[0], p[1], -eps])
                cylinder(d = cyd_screw_clear_dia, h = lid_t + cyd_lid_standoff_h + 2 * eps);
    }
}

module cyd_lid_boss(h = 6) {
    difference() {
        cylinder(d = cyd_lid_boss_dia, h = h);
        translate([0, 0, h - cyd_insert_depth + eps])
            cylinder(d = cyd_insert_dia, h = cyd_insert_depth + eps);
    }
}

module kp_lid_boss(h = 7) {
    difference() {
        cylinder(d = kp_lid_boss_dia, h = h);
        translate([0, 0, h - kp_insert_depth + eps])
            cylinder(d = kp_insert_dia, h = kp_insert_depth + eps);
    }
}

module max_boss() {
    h = 5;
    difference() {
        cylinder(d = max_boss_dia, h = h);
        translate([0, 0, h - 4 + eps]) cylinder(d = 3.5, h = 4 + eps);
    }
}

// ============================================================================
//  Component ghost previews — visual fit only, not printed
// ============================================================================

module component_previews() {
    if (show_components) {
        // v11: all component keepouts (heatsink, SSR, wiring zone, inlet,
        // oven socket, Shelly, KP200 body, CYD PCB, MAX6675)
        color("DimGray", component_alpha) component_keepouts();

        // KP200 face/yoke footprint on top lid
        color("Purple", component_alpha)
            translate([kp_center_x - kp_wid_x / 2,
                       kp_center_y - kp_len_y / 2,
                       box_h + 0.2])
                cube([kp_wid_x, kp_len_y, 1.5]);

        // Conservative KP200 body keepout below lid
        color("MediumPurple", component_alpha)
            translate([kp_center_x - kp_wid_x / 2,
                       kp_center_y - kp_len_y / 2,
                       box_h - lid_t - kp_depth_z])
                cube([kp_wid_x, kp_len_y, kp_depth_z]);

        // CYD PCB envelope, shown under the top lid
        color("ForestGreen", component_alpha)
            translate([cyd_center_x - cyd_pcb_w / 2,
                       cyd_center_y - cyd_pcb_h / 2,
                       box_h - lid_t - cyd_lid_standoff_h - 1.6])
                cube([cyd_pcb_w, cyd_pcb_h, 1.6]);

        // MAX6675 board envelope
        color("DarkGreen", component_alpha)
            translate([max_pos_x - max_board_w / 2,
                       max_pos_y - max_board_h / 2,
                       floor_t + 5])
                cube([max_board_w, max_board_h, 1.6]);

        // IEC inlet face preview (FILSHU, APPROX listing size)
        color("Crimson", component_alpha)
            translate([inlet_center_x - inlet_face_w / 2,
                       -1.5,
                       inlet_center_z - inlet_face_h / 2])
                cube([inlet_face_w, 1.5, inlet_face_h]);

        // Inlet body preview inside the AC bay
        color("DarkRed", component_alpha)
            translate([inlet_center_x - inlet_cutout_w / 2,
                       wall_t,
                       inlet_center_z - inlet_cutout_h / 2])
                cube([inlet_cutout_w, inlet_body_depth, inlet_cutout_h]);

        // Extra no-go zone for rear terminals and pre-crimped AC wires
        color("OrangeRed", component_alpha)
            translate([inlet_center_x - inlet_cutout_w / 2,
                       wall_t + inlet_body_depth,
                       inlet_center_z - inlet_cutout_h / 2])
                cube([inlet_cutout_w, inlet_wire_clearance_depth, inlet_cutout_h]);
    }
}

// ============================================================================
//  Composite views
// ============================================================================

module lid_printable() {
    // v9.3 CRITICAL FIX: lid_print_orientation() models features in shell plan
    // coordinates with the OUTER face at Z=0. A printed part must be physically
    // FLIPPED to install, and a real flip is a 180 rotation about a horizontal
    // axis — which mirrors one plan axis. The old output therefore installed
    // mirror-imaged: the symmetric DC screw pattern still aligned (masking the
    // bug) but all four asymmetric AC-side holes missed their bosses.
    // Fix: emit the MIRRORED geometry for printing, so flipping the part
    // front-to-back at assembly restores true plan coordinates.
    // INSTALL: flip the printed lid toward you (about the X axis).
    translate([0, box_d, 0]) mirror([0, 1, 0]) lid_print_orientation();
}

module lid_assembly_orientation() {
    // v9.3: physically honest install transform — a true 180 rotation of the
    // printable part (the old mirror([0,0,1]) was a Z-mirror, which no
    // physical object can undergo; it made misaligned parts preview as aligned).
    translate([0, box_d, box_h]) rotate([180, 0, 0]) lid_printable();
}

module assembly_view() {
    color("SteelBlue") bottom_shell();
    color("LightGray", 0.85) lid_assembly_orientation();
    color("Orange") translate([0, 0, box_h + 0.3]) top_bezel();
    component_previews();
}

module print_layout() {
    bottom_shell();
    translate([box_w + 15, 0, 0]) lid_printable();
    translate([box_w + 15, box_d + 15, 0]) top_bezel();
}
