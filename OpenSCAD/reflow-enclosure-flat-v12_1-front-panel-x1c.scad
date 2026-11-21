// ============================================================================
//  DIY Reflow Oven Controller — Flat Bench Enclosure (v12.1, X1C Fit)
//  Parametric OpenSCAD model for Bambu X1C. PRINT IN ASA.
//
//  v12.1 CHANGE (2026-11, DROK AC meter in the lid):
//  - Snap-in cutout for the DROK AC multimeter (Amazon B0B3WVG2V9) in the lid
//    over the AC bay, above the inlet. Only the LID changed; the bottom shell
//    and front panel are the v12.0 parts. New part "drok_meter_coupon".
//  - Its split-core CT goes on the oven hot wire (SSR T2 -> socket hot) and
//    lies on the AC floor between the oven socket and the inlet.
//
//  v12.0 CHANGE (2026-10, cable-only display + landscape front panel):
//  - Display is now the Elecrow CrowPanel 2.8" ESP32 HMI (ESP32-WROOM-32-N4,
//    ILI9341V, resistive touch). It is wired with cables only: SSR on the
//    GPIO_D connector (J7), MAX6675 on the I2C (J6) + UART (J10) connectors.
//    No board modifications. Pinout from Elecrow's own Eagle schematic
//    (V1.0, V2.0 and V2.1 all identical for J6/J7/J10): see README.
//  - The display mounts in LANDSCAPE on a separate FRONT PANEL, printed flat
//    (face down: clean face, crisp window, standoffs grow straight up). The
//    long side (box_w) is the front. The shell no longer has a front wall.
//  - Board geometry from Elecrow's outline drawing (PCB 85.7 x 54, holes
//    78.7 x 47, LCM 69.2 x 50 centred), the QD281801 LCM drawing (LCM 3.5 mm
//    thick; LCD active area 57.6 x 43.2 starting 2.90 mm from the end OPPOSITE
//    the FPC; touch active area 58.6 x 44.2 starting 2.40 mm from that end),
//    and Elecrow's STEP model (connector, USB-C and component positions). The
//    board's FPC/USB-C end was located from the Eagle .brd (J1 pads, J3).
//  - Board is mounted CONNECTORS-DOWN (firmware rotates the image 180 deg) so
//    its USB-C faces the RIGHT wall: the USB-C cable plugs in from OUTSIDE
//    through a slot, and firmware can be flashed without opening the box.
//  - Box 230 x 155 x 65 -> 250 x 155 x 83: the board needs 89 mm of DC bay and
//    54 mm + a cable zone below for its downward-facing HY2.0 connectors.
//  - SSR wiring with straight bare wire under the saddle clamps: AC terminals
//    at the SSR's LEFT end, DC terminals at its RIGHT end. The taller box lifts
//    the KP200 body to z 35, so the lower AC wire runs straight under it; the
//    upper AC wire bends down in the channel between the KP200 body and the
//    SSR end. Wire zones are keepouts checked against every printed part.
//  - Divider: only one pass-through left (SSR control, beside the SSR's DC
//    end). The CYD power pass-through is gone (USB enters from outside).
//  - Lid: CYD window/bosses removed. Lid screws moved off the board's corner.
//
//  v11.0 (2026-10): AC bay rebuilt around the real parts — heatsink (MEASURED
//  80 x 49.4 x 51) along the front with the SSR on its rear face; NEMA 5-15R
//  oven socket on the left wall; FILSHU inlet cutout 48 x 27.5 with 1.5 mm clip
//  reliefs; Shelly pocket; intake/outlet slots verified by ray test.
//  v10.x: KP200 flush-mount rework from teardown measurements (window 46 x 72,
//  tab recesses, captive-screw clearance) — unchanged here.
//  v9.3: lid printed pre-mirrored so the physical flip restores plan coords.
//
//  NOTE: enclosure geometry only, not wiring approval. Verify current
//  ratings, fuse value, wire gauge, strain relief, grounding, creepage and
//  the physical part dimensions before using with mains voltage.
//
//  Coordinate system (installed):
//    X = width  (left AC side -> right DC side)
//    Y = depth  (rear wall y=0, inlet side -> FRONT panel y=box_d)
//    Z = height (floor -> lid)
//  Seen from the front, +X is on the viewer's LEFT: the display is on the
//  left of the front panel, the AC bay on the right.
// ============================================================================

/* [Render selector] */
part = "assembly"; // ["bottom","lid","front_panel","assembly","assembly_open","keepouts","crowpanel_test_coupon","iec_test_coupon","kp200_test_coupon","oven_socket_coupon","iec_trim_plate","drok_meter_coupon"]

/* [Wall thicknesses] */
wall_t = 3;
floor_t = 3;
lid_t = 3;
fp_t = 3;                   // front panel thickness

/* [CrowPanel 2.8 — board frame]
   Board frame (from Elecrow's STEP): origin = PCB centre, +x toward the USB-C
   edge, +y toward the HY2.0 connector edge, display on the +z side.
   Installed: board x -> box +X, board y -> box -Z (connectors down). */
crow_pcb_w = 85.7;          // Elecrow outline drawing
crow_pcb_h = 54;            // Elecrow outline drawing
crow_pcb_t = 1.6;           // STEP
crow_hole_w = 78.7;         // Elecrow outline drawing, 4 x d3.2
crow_hole_h = 47;
crow_lcm_w = 69.2;          // QD281801 drawing, centred on the PCB (8.25 per side, Elecrow drawing)
crow_lcm_h = 50;
crow_lcm_t = 3.5;           // QD281801: 3.50 +/- 0.10
crow_back_depth = 5.55;     // STEP: deepest back-side part (PH2.0 jacks) below the PCB back
crow_glass_gap = 0.6;       // air gap glass -> panel; keeps the bezel off the resistive touch
crow_standoff_h = crow_lcm_t + crow_glass_gap;
crow_boss_dia = 8.5;        // same boss/insert as the validated CYD lid bosses
crow_insert_dia = 4.2;
crow_insert_depth = 4;
// Window = touch active area (QD281801: 58.60 x 44.20, starting 2.40 mm from
// the non-FPC end). In board x it spans -32.2 .. +26.4 (the LCD active area
// -31.7 .. +25.9 sits inside it, 0.5 mm margin; touch viewing area -32.55 ..
// +26.9 sits outside it, so the edge stays on the black border).
crow_win_x0 = -32.2;
crow_win_x1 = 26.4;
crow_win_h = 44.2;
crow_win_chamfer = 1.5;     // 45 deg, outer face; printable face-down
// HY2.0 connectors (STEP, board x): J7 GPIO_D -32.35..-20.35, J6 I2C
// -14.87..-2.87, J10 UART1 2.62..14.62; openings face the board's +y edge.
crow_conn_x0 = -32.35;
crow_conn_x1 = 14.62;
crow_cable_zone = 15;       // APPROX: plug protrusion (~4) + 26 AWG cable bend, below the board
crow_top_clear = 8;         // above the board: speaker jack (PH2.0) at board x -17.14..-9.14
crow_spk_x0 = -17.14; crow_spk_x1 = -9.14;
// USB-C receptacle (STEP): board y 6.68..15.62, axis 1.13 mm behind the PCB back face
crow_usb_y = 11.15;
crow_usb_axis_behind_back = 1.13;
usb_slot_along_y = 9;       // opening through the right wall; fits overmolds up to ~13.5 x 7.5
usb_slot_along_z = 15;
usb_plug_t = 6.5;           // keepout for a typical USB-C overmold (APPROX)
usb_plug_w = 12.4;
crow_edge_gap = 0.5;        // standoff boss to right wall

/* [Box outer dimensions] */
box_w = 250;                // 3 mm spare per side on the 256 mm bed
box_d = 155;
box_h = floor_t + crow_cable_zone + crow_pcb_h + crow_top_clear + lid_t;   // = 83

/* [DROK AC meter (B0B3WVG2V9), lid mount over the inlet] -- v12.1
   Measured by Jon 2026-11-21: face 76.5 x 48, body 73.37 x 45, body depth
   21.47 below the face. Snap-in from above. Long axis along Y (front to
   back): between the KP200 faceplate (x <= 90) and the divider (x >= 156)
   there are only 66 mm, so the 73.4 mm body cannot sit crosswise. */
drok_face_l = 76.5;
drok_face_w = 48;
drok_body_l = 73.37;
drok_body_w = 45;
drok_body_d = 21.47;
drok_cut_l = 74.0;          // cutout = body + ~0.6; confirm with drok_meter_coupon
drok_cut_w = 45.6;
drok_panel_t = 3;           // lid thickness at the meter; < lid_t pockets the underside for the clips
drok_wire_zone = 7;         // screw heads + wires leaving sideways below the body (SSR top is 7.5 below)
drok_center_x = 130;
drok_center_y = wall_t + 1 + drok_face_l / 2;

/* [AC/DC divider] */
divider_x = 157;
divider_t = 2;

/* [AC side: SSR + heatsink]  (unchanged from v11)
   MEASURED heatsink 80 x 49.4 x 51; SSR APPROX 62 x 45 x 23.5 on the
   heatsink's REAR (-Y) face, terminals facing the rear.
   v12: wire the SSR with AC terminals (1, 2) at its LEFT end and DC
   terminals (3, 4) at its RIGHT end (rotate it 180 deg on the heatsink if
   needed). */
hs_len_x  = 80;
hs_dep_y  = 49.4;
hs_h      = 51;
hs_x0     = 73;
intake_gap = 8;
hs_y0     = box_d - fp_t - intake_gap - hs_dep_y;   // = 94.6
hs_clear  = 0.6;
ssr_len_x = 62;
ssr_h_z   = 45;
ssr_dep_y = 23.5;
ssr_x0    = hs_x0 + (hs_len_x - ssr_len_x) / 2;
ssr_z0    = floor_t + (hs_h - ssr_h_z) / 2;
ssr_y0    = hs_y0 - ssr_dep_y;
heatsink_top_z = floor_t + hs_h;
ssr_wire_band = [ssr_y0 - 12, ssr_y0 + 8];          // y band the straight wires leave the clamps in

/* [AC side: FILSHU fused IEC C14 inlet]  (unchanged from v11, rear wall) */
inlet_face_w = 50;
inlet_face_h = 30;
inlet_body_depth = 28;
inlet_wire_clearance_depth = 20;
inlet_cutout_w = 48.0;
inlet_cutout_h = 27.5;
inlet_clip_panel_t = 1.5;
inlet_clip_relief_w = 3;
inlet_clip_relief_extra_h = 2;
inlet_center_x = 118;
inlet_center_z = 31;
inlet_screw_pattern = "none";
inlet_screw_spacing = 40;
inlet_screw_dia = 3.4;

/* [AC side: KP200 lid mount]  (unchanged from v10.3/v11) */
kp_wid_x = 85;
kp_len_y = 129;
kp_depth_z = 44;
kp_screw_spacing = 83;
kp_center_x = wall_t + 2 + kp_wid_x / 2;
kp_center_y = box_d - fp_t - 6 - kp_len_y / 2;
kp_window_x = 46;
kp_window_y = 72;
kp_ear_w = 22;
kp_ear_h = 20;
kp_ear_recess = 1.2;
kp_ear_corner_r = 3;
kp_ear_chamfer = 1.2;
kp_capscrew_offset = 6;
kp_capscrew_protrude = 6;
kp_capscrew_clear_dia = 5;
kp_lid_boss_h = 7;
kp_lid_boss_dia = 9;
kp_insert_dia = 4.5;
kp_insert_depth = 5;
kp_screw_clear_dia = 3.8;
kp_body_x = 45; kp_body_y = 70.5; kp_body_z = 45;   // MEASURED

/* [AC side: NEMA 5-15R oven socket, left wall]  (unchanged from v11) */
os_face      = 27;
os_depth     = 35;
os_cut       = 24.75;
os_panel_t   = 2.5;
os_pocket_margin = 3;
os_center_y  = 30;
os_center_z  = 22;

/* [AC side: Shelly 1PM Gen4 pocket]  (unchanged from v11) */
shelly_h = 37; shelly_w = 42; shelly_t = 16;
shelly_clear = 0.6;
shelly_y0 = 64;
shelly_rib_t = 2;
shelly_rib_h = 20;
shelly_lip_h = 8;

/* [DC side: MAX6675 on floor] */
max_board_w = 18;
max_board_h = 15;
max_hole_dx = 13;
max_hole_dy = 10;
max_boss_dia = 6;
max_pos_x = divider_x + 20;
max_pos_y = 30;

/* [DC side: thermocouple pass-through, right wall] */
tc_gland_dia = 8;
tc_gland_y = 45;
tc_gland_z = 18;

/* [Divider pass-through — SSR control only]
   Open-top U-slot beside the SSR's DC end; wires drop in, the lid closes it. */
ctrl_hole_dia = 6;
ctrl_hole_y = 76;
ctrl_hole_z = 15;

/* [Lid outlet slots over the heatsink fin field]
   v12: 6 slots (was 7), pattern moved 3 mm toward the front. In the taller
   box a 45-degree probe through the old rearmost slot could reach the top
   edge of the SSR terminal face; the rearmost slot edge must stay forward of
   (terminal face y) + (shell_h - SSR top) — asserted below. */
vent_slot_w = 3;
vent_slot_len = 66;
vent_slot_count = 6;
vent_slot_gap = 6;
vent_center_x = hs_x0 + hs_len_x / 2;
vent_center_y = hs_y0 + hs_dep_y / 2 + 3;

/* [Front-panel intake slots in front of the heatsink] */
intake_slot_w = 3;
intake_slot_count = 11;
intake_slot_gap = 6;
intake_z0 = floor_t + 3;
intake_z1 = 30;

/* [Heatsink locator fence] */
fence_t = 2;
fence_h = 5;
fence_stub = 8;

/* [Front panel fixing]
   Panel screws: M3 countersunk from the front into heat-set inserts in posts.
   AC side: two full-height posts (also carry lid screws). DC side: two low
   posts under the board's cable zone. The lid clamps the panel's top edge. */
post_d = 10;                 // post depth (Y)
fp_post_ac = [[wall_t, 10], [58, 10]];                    // [x0, width], full height
fp_post_dc = [[divider_x + divider_t / 2, 9], [box_w - wall_t - 9, 9]];   // [x0, width], low
fp_post_dc_h = 12;
fp_insert_dia = 4.2;
fp_insert_depth = 6;           // M3x8 countersunk through the 3 mm panel leaves ~1 mm below the screw tip
fp_screw_clear = 3.4;
fp_screw_csk = 6.4;
fp_screw_csk_depth = 1.7;
fp_rib_t = 2;                // panel rib on the AC face of the divider
fp_rib_d = 4.5;
fp_rib_gap = 0.2;

/* [Lid screws / M3 heat-set inserts] */
boss_outer_dia = 8;
boss_insert_dia = 4.2;
boss_insert_depth = 5;
lid_screw_clear_dia = 3.4;
lid_screw_csk_dia = 6.4;
lid_screw_csk_depth = 2.0;

/* [Rubber feet] */
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
fp_in    = box_d - fp_t;             // panel inner face (shell walls/floor end here)

ac_x_min = wall_t;
ac_x_max = divider_x - divider_t / 2;
dc_x_min = divider_x + divider_t / 2;
dc_x_max = box_w - wall_t;
dc_w     = dc_x_max - dc_x_min;

// Board placement (box coordinates)
crow_cx = dc_x_max - crow_edge_gap - (crow_hole_w / 2 + crow_boss_dia / 2);
crow_cz = floor_t + crow_cable_zone + crow_pcb_h / 2;
crow_pcb_front_y = fp_in - crow_standoff_h;
crow_pcb_back_y  = crow_pcb_front_y - crow_pcb_t;
crow_usb_cy = crow_pcb_back_y - crow_usb_axis_behind_back;
crow_usb_cz = crow_cz - crow_usb_y;
function bx(x) = crow_cx + x;        // board x -> box X
function bz(y) = crow_cz - y;        // board y -> box Z (connectors down)

kp_bottom_z = shell_h - kp_body_z;

boss_positions = [
    [10, 10],
    [80, 10],
    [10, 55],
    [fp_post_ac[0][0] + fp_post_ac[0][1] / 2, fp_in - 4.5],   // in the left-front post
    [fp_post_ac[1][0] + fp_post_ac[1][1] / 2, fp_in - 4.5],   // in the middle-front post
    [dc_x_min + 10, 10],
    [dc_x_max - 10, 10],
    [dc_x_min + 10, crow_pcb_back_y - crow_back_depth - 7],     // behind the board
    [dc_x_max - 10, crow_pcb_back_y - crow_back_depth - 7]
];

// Front-panel screws, [x, z] in box coordinates
fp_screws = [
    [fp_post_ac[0][0] + fp_post_ac[0][1] / 2, 12],
    [fp_post_ac[0][0] + fp_post_ac[0][1] / 2, shell_h - 15],
    [fp_post_ac[1][0] + fp_post_ac[1][1] / 2, 12],
    [fp_post_ac[1][0] + fp_post_ac[1][1] / 2, shell_h - 15],
    [fp_post_dc[0][0] + fp_post_dc[0][1] / 2, floor_t + fp_post_dc_h / 2],
    [fp_post_dc[1][0] + fp_post_dc[1][1] / 2, floor_t + fp_post_dc_h / 2]
];

crow_holes_xz = [for (sx = [-1, 1]) for (sy = [-1, 1]) [bx(sx * crow_hole_w / 2), bz(sy * crow_hole_h / 2)]];

kp_screw_positions = [
    [kp_center_x, kp_center_y - kp_screw_spacing / 2],
    [kp_center_x, kp_center_y + kp_screw_spacing / 2]
];

echo("=== Flat bench enclosure v12.1 (DROK meter in lid) / X1C fit / CrowPanel 2.8 front panel + KP200 lid + FILSHU inlet + 5-15R socket ===");
echo(str("Box: ", box_w, " x ", box_d, " x ", box_h, " mm; shell ", shell_h, "; DC bay interior ", dc_w, " mm"));
echo(str("CrowPanel centre X/Z ", crow_cx, "/", crow_cz, "; PCB X ", bx(-crow_pcb_w / 2), "-", bx(crow_pcb_w / 2),
         " Z ", bz(crow_pcb_h / 2), "-", bz(-crow_pcb_h / 2), "; PCB front Y ", crow_pcb_front_y));
echo(str("Window X ", bx(crow_win_x0), "-", bx(crow_win_x1), " Z ", crow_cz - crow_win_h / 2, "-", crow_cz + crow_win_h / 2));
echo(str("USB-C slot centre Y/Z ", crow_usb_cy, "/", crow_usb_cz));
echo(str("Vent centre X/Y ", vent_center_x, "/", vent_center_y, "; rearmost slot edge Y ", vent_center_y - (vent_slot_count - 1) * vent_slot_gap / 2 - vent_slot_w / 2));
echo(str("KP200 body bottom Z ", kp_bottom_z, "; heatsink top Z ", heatsink_top_z, "; SSR Z ", ssr_z0, "-", ssr_z0 + ssr_h_z));
assert(box_w <= 256 && box_d <= 256, "box exceeds X1C bed");
assert(drok_center_x + drok_face_w / 2 <= divider_x - divider_t / 2 - 1 && drok_center_x - drok_body_w / 2 >= 80 + 6,
       "DROK meter hits the divider or the [80,10] lid screw");
assert(drok_center_y + drok_face_l / 2 <= vent_center_y - (vent_slot_count - 1) * vent_slot_gap / 2 - vent_slot_w / 2 - 3,
       "DROK meter face runs into the lid vent slots");
assert(shell_h - drok_body_d - drok_wire_zone >= max(inlet_center_z + inlet_cutout_h / 2, ssr_z0 + ssr_h_z) + 0.5,
       "DROK meter terminal zone hits the inlet or the SSR wiring zone");
echo(str("DROK meter centre X/Y ", drok_center_x, "/", drok_center_y, "; cutout ", drok_cut_w, " x ", drok_cut_l,
         "; body bottom Z ", shell_h - drok_body_d));
assert(vent_center_y - (vent_slot_count - 1) * vent_slot_gap / 2 - vent_slot_w / 2 >= ssr_y0 + 3 + (shell_h - (ssr_z0 + ssr_h_z)) + 1,
       "rearmost lid slot gives a 45-degree probe line to the SSR terminal face");
assert(hs_x0 + hs_len_x + hs_clear + fence_t <= divider_x - divider_t / 2, "heatsink fence hits divider");
assert(shell_h - heatsink_top_z >= 5, "heatsink stack too tall for lid");
assert(bx(-crow_hole_w / 2) - crow_boss_dia / 2 >= dc_x_min + 1, "CrowPanel boss hits divider");
assert(bx(crow_pcb_w / 2) <= dc_x_max, "CrowPanel PCB hits right wall");
assert(fp_post_ac[1][0] + fp_post_ac[1][1] <= hs_x0 - hs_clear - fence_t - 2, "middle post hits heatsink fence");
assert(floor_t + fp_post_dc_h <= bz(crow_pcb_h / 2) - 2, "DC post hits board");
assert(fp_post_dc[0][0] + fp_post_dc[0][1] <= bx(crow_conn_x0) - 2, "DC post blocks J7 cable");

// ============================================================================
//  Top-level render
// ============================================================================
if (part == "bottom") bottom_shell();
else if (part == "lid") lid_printable();
else if (part == "front_panel") front_panel_print();
else if (part == "assembly") assembly_view();
else if (part == "assembly_open") { color("SteelBlue") bottom_shell(); color("DarkSlateGray") front_panel_installed(); component_previews(); }
else if (part == "keepouts") component_keepouts();
else if (part == "crowpanel_test_coupon") crowpanel_test_coupon();
else if (part == "iec_test_coupon") iec_test_coupon();
else if (part == "kp200_test_coupon") kp200_test_coupon();
else if (part == "oven_socket_coupon") oven_socket_coupon();
else if (part == "iec_trim_plate") iec_trim_plate();
else if (part == "drok_meter_coupon") drok_meter_coupon();

// ============================================================================
//  Bottom shell — floor, rear/left/right walls, divider, posts. Open front.
// ============================================================================
module bottom_shell() {
    difference() {
        union() {
            difference() {
                cube([box_w, fp_in, shell_h]);
                translate([wall_t, wall_t, floor_t])
                    cube([box_w - 2 * wall_t, fp_in, shell_h]);
            }

            // AC/DC divider (stops at the panel's inner face)
            translate([divider_x - divider_t / 2, 0, 0])
                cube([divider_t, fp_in, shell_h]);

            // Lid-screw bosses (the two front-AC ones sit inside the posts)
            for (p = boss_positions)
                translate([p[0], p[1], floor_t]) cylinder(d = boss_outer_dia, h = inner_h - 0.2);

            // Front-panel posts
            for (p = fp_post_ac)
                translate([p[0], fp_in - post_d, floor_t - eps]) cube([p[1], post_d, inner_h - 0.2 + eps]);
            for (p = fp_post_dc)
                translate([p[0], fp_in - post_d, floor_t - eps]) cube([p[1], post_d, fp_post_dc_h + eps]);

            // MAX6675 standoff bosses on DC floor
            for (dx = [-max_hole_dx / 2, max_hole_dx / 2])
                for (dy = [-max_hole_dy / 2, max_hole_dy / 2])
                    translate([max_pos_x + dx, max_pos_y + dy, floor_t]) max_boss();

            heatsink_fence();
            shelly_pocket();
        }

        // Lid insert pockets
        for (p = boss_positions)
            translate([p[0], p[1], shell_h - 0.2 - boss_insert_depth])
                cylinder(d = boss_insert_dia, h = boss_insert_depth + eps);

        // Front-panel insert pockets (horizontal, from the post front face)
        for (s = fp_screws)
            translate([s[0], fp_in + eps, s[1]])
                rotate([90, 0, 0]) cylinder(d = fp_insert_dia, h = fp_insert_depth + eps);

        // FILSHU inlet cutout + clip reliefs, rear wall
        translate([inlet_center_x, 0, inlet_center_z]) inlet_cut(wall_t);

        // NEMA 5-15R socket, left wall
        oven_socket_cut();

        // Thermocouple gland, right wall
        translate([box_w - wall_t - eps, tc_gland_y, tc_gland_z])
            rotate([0, 90, 0]) cylinder(d = tc_gland_dia, h = wall_t + 2 * eps);

        // USB-C cable slot, right wall, on the CrowPanel's USB-C axis
        translate([box_w - wall_t - eps, crow_usb_cy - usb_slot_along_y / 2, crow_usb_cz - usb_slot_along_z / 2])
            cube([wall_t + 2 * eps, usb_slot_along_y, usb_slot_along_z]);

        // SSR control pass-through, open-top U-slot
        divider_u_slot(ctrl_hole_y, ctrl_hole_z, ctrl_hole_dia);

        // Rubber-foot recesses
        for (x = [foot_inset, box_w - foot_inset])
            for (y = [foot_inset, fp_in - foot_inset])
                translate([x, y, -eps]) cylinder(d = foot_dia, h = foot_recess_depth + eps);
    }
}

// ============================================================================
//  Front panel — modelled in PRINT coordinates: u = box X, v = box Z,
//  w = depth from the OUTER face (outer face on the bed at w = 0).
//  Installed: translate([0, box_d, 0]) rotate([90, 0, 0]) front_panel_print()
//  (a proper rotation, not a mirror: (u, v, w) -> (u, box_d - w, v)).
// ============================================================================
module front_panel_print() {
    difference() {
        union() {
            cube([box_w, shell_h, fp_t]);
            // CrowPanel standoffs
            for (p = crow_holes_xz)
                translate([p[0], p[1], fp_t - eps]) crow_boss(crow_standoff_h + eps);
            // Rib on the AC face of the divider (labyrinth at the joint)
            translate([divider_x - divider_t / 2 - fp_rib_gap - fp_rib_t, floor_t + 0.3, fp_t - eps])
                cube([fp_rib_t, shell_h - floor_t - 0.6, fp_rib_d + eps]);
        }

        // Display window (touch active area) with a 45-degree outer chamfer
        crow_window_cut(fp_t);

        // Panel screws, countersunk on the outer face
        for (s = fp_screws) {
            translate([s[0], s[1], -eps]) cylinder(d = fp_screw_clear, h = fp_t + 2 * eps);
            translate([s[0], s[1], -eps])
                cylinder(d1 = fp_screw_csk, d2 = fp_screw_clear, h = (fp_screw_csk - fp_screw_clear) / 2 + eps);
        }

        // Intake slots in front of the heatsink
        span = (intake_slot_count - 1) * intake_slot_gap;
        for (i = [0 : intake_slot_count - 1])
            translate([vent_center_x - span / 2 + i * intake_slot_gap - intake_slot_w / 2, intake_z0, -eps])
                cube([intake_slot_w, intake_z1 - intake_z0, fp_t + 2 * eps]);
    }
}

module crow_window_cut(t) {
    x0 = bx(crow_win_x0); x1 = bx(crow_win_x1);
    z0 = crow_cz - crow_win_h / 2; z1 = crow_cz + crow_win_h / 2;
    c = crow_win_chamfer;
    hull() {
        translate([x0 - c, z0 - c, -eps]) cube([x1 - x0 + 2 * c, z1 - z0 + 2 * c, eps]);
        translate([x0, z0, c]) cube([x1 - x0, z1 - z0, eps]);
    }
    translate([x0, z0, c - eps]) cube([x1 - x0, z1 - z0, t - c + 3 * eps]);
}

module crow_boss(h) {
    difference() {
        cylinder(d = crow_boss_dia, h = h);
        translate([0, 0, h - crow_insert_depth + eps]) cylinder(d = crow_insert_dia, h = crow_insert_depth + eps);
    }
}

module front_panel_installed() {
    translate([0, box_d, 0]) rotate([90, 0, 0]) front_panel_print();
}

// CrowPanel fit coupon: the panel's display region 1:1 (same plate, window,
// chamfer, standoffs, insert pockets), printed the same way. Mount the board
// on it before printing the full front panel.
module crowpanel_test_coupon() {
    m = 6;
    u0 = bx(-crow_hole_w / 2) - crow_boss_dia / 2 - m;
    u1 = bx(crow_hole_w / 2) + crow_boss_dia / 2 + m;
    v0 = crow_cz - crow_hole_h / 2 - crow_boss_dia / 2 - m;
    v1 = crow_cz + crow_hole_h / 2 + crow_boss_dia / 2 + m;
    translate([-u0, -v0, 0]) difference() {
        union() {
            translate([u0, v0, 0]) cube([u1 - u0, v1 - v0, fp_t]);
            for (p = crow_holes_xz)
                translate([p[0], p[1], fp_t - eps]) crow_boss(crow_standoff_h + eps);
        }
        crow_window_cut(fp_t);
        // orientation mark: notch on the edge that faces the floor (connector edge)
        translate([(u0 + u1) / 2 - 3, v0 - eps, -eps]) cube([6, 2, fp_t + 2 * eps]);
    }
}

// ============================================================================
//  Lid (unchanged features: KP200 flush mount, outlet slots, lid screws)
// ============================================================================
module lid_print_orientation() {
    difference() {
        union() {
            cube([box_w, box_d, lid_t]);
            for (p = kp_screw_positions)
                translate([p[0], p[1], lid_t]) kp_lid_boss(kp_lid_boss_h);
        }

        for (p = boss_positions) {
            translate([p[0], p[1], -eps])
                cylinder(d = lid_screw_clear_dia, h = lid_t + 2 * eps);
            translate([p[0], p[1], -eps])
                cylinder(d1 = lid_screw_csk_dia, d2 = lid_screw_clear_dia, h = lid_screw_csk_depth + eps);
        }

        translate([kp_center_x - kp_window_x / 2, kp_center_y - kp_window_y / 2, -eps])
            cube([kp_window_x, kp_window_y, lid_t + kp_lid_boss_h + 2 * eps]);
        for (p = kp_screw_positions)
            translate([p[0], p[1], -eps])
                cylinder(d = kp_screw_clear_dia, h = lid_t + kp_lid_boss_h + 2 * eps);
        for (p = kp_screw_positions)
            translate([p[0], p[1], 0]) kp_tab_recess();
        for (dy = [-(kp_screw_spacing / 2 + kp_capscrew_offset), kp_screw_spacing / 2 + kp_capscrew_offset])
            translate([kp_center_x, kp_center_y + dy, -eps])
                cylinder(d = kp_capscrew_clear_dia, h = lid_t + kp_lid_boss_h + 2 * eps);

        // v12.1: DROK AC meter
        translate([drok_center_x - drok_cut_w / 2, drok_center_y - drok_cut_l / 2, -eps])
            cube([drok_cut_w, drok_cut_l, lid_t + 2 * eps]);
        if (drok_panel_t < lid_t)
            translate([drok_center_x - drok_cut_w / 2 - 6, drok_center_y - drok_cut_l / 2 - 3, drok_panel_t])
                cube([drok_cut_w + 12, drok_cut_l + 6, lid_t - drok_panel_t + eps]);

        vent_span = (vent_slot_count - 1) * vent_slot_gap;
        for (i = [0 : vent_slot_count - 1])
            translate([vent_center_x - vent_slot_len / 2,
                       vent_center_y - vent_span / 2 + i * vent_slot_gap - vent_slot_w / 2,
                       -eps])
                cube([vent_slot_len, vent_slot_w, lid_t + 2 * eps]);
    }
}

// ============================================================================
//  Test coupons and retrofit parts (unchanged from v11)
// ============================================================================
trim_plate_w = 58;
trim_plate_h = 48;
trim_plate_t = 1.5;

module iec_trim_plate() {
    cx = trim_plate_w / 2;
    cy = trim_plate_h / 2;
    difference() {
        cube([trim_plate_w, trim_plate_h, trim_plate_t]);
        translate([cx - inlet_cutout_w / 2, cy - inlet_cutout_h / 2, -eps])
            cube([inlet_cutout_w, inlet_cutout_h, trim_plate_t + 2 * eps]);
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
        translate([cx, cy, 0]) rotate([90, 0, 0]) inlet_cut(coupon_t);
    }
}

module rounded_rect_2d(w, h, r) {
    offset(r = r) offset(delta = -r) square([w, h], center = true);
}
module kp_tab_recess() {
    hull() {
        translate([0, 0, -eps])
            linear_extrude(0.01)
                rounded_rect_2d(kp_ear_w + 2 * kp_ear_chamfer, kp_ear_h + 2 * kp_ear_chamfer, kp_ear_corner_r);
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
        translate([cx - kp_window_x / 2, cy - kp_window_y / 2, -eps])
            cube([kp_window_x, kp_window_y, coupon_t + kp_lid_boss_h + 2 * eps]);
        for (dy = [-kp_screw_spacing / 2, kp_screw_spacing / 2])
            translate([cx, cy + dy, -eps])
                cylinder(d = kp_screw_clear_dia, h = coupon_t + kp_lid_boss_h + 2 * eps);
        for (dy = [-kp_screw_spacing / 2, kp_screw_spacing / 2])
            translate([cx, cy + dy, 0]) kp_tab_recess();
        for (dy = [-(kp_screw_spacing / 2 + kp_capscrew_offset), kp_screw_spacing / 2 + kp_capscrew_offset])
            translate([cx, cy + dy, -eps])
                cylinder(d = kp_capscrew_clear_dia, h = coupon_t + kp_lid_boss_h + 2 * eps);
    }
}

// NEMA 5-15R snap-in socket cutout + inside pocket thinning the wall to
// os_panel_t (45-degree top, no ceiling to bridge).
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

// FILSHU inlet cutout + side clip reliefs cut from the inside (45-degree tops).
// Origin = cutout centre on the OUTER face; wall from y=0 (outside) to y=t.
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

module divider_u_slot(y, z, d) {
    translate([divider_x - divider_t / 2 - eps, y, z])
        rotate([0, 90, 0]) cylinder(d = d, h = divider_t + 2 * eps);
    translate([divider_x - divider_t / 2 - eps, y - d / 2, z])
        cube([divider_t + 2 * eps, d, shell_h - z + eps]);
}

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

module shelly_pocket() {
    iw = shelly_w + 2 * shelly_clear;
    it = shelly_t + 2 * shelly_clear;
    for (y = [shelly_y0 - shelly_rib_t, shelly_y0 + iw])
        translate([wall_t - eps, y, floor_t - eps])
            cube([it + shelly_rib_t + eps, shelly_rib_t, shelly_rib_h + eps]);
    translate([wall_t + it, shelly_y0 - shelly_rib_t, floor_t - eps])
        cube([shelly_rib_t, iw + 2 * shelly_rib_t, shelly_lip_h + eps]);
}

os_coupon_cuts   = [24.5, 24.75, 25.0];
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

// v12.1: DROK meter cutout coupon. Columns: cutout size (small, nominal,
// large; dimples along the bottom edge count 1-3). Rows: panel thickness 2.0
// (front row, 1 dimple on the left edge) and 3.0 (back row, 2 dimples).
drok_coupon_cuts   = [[45.2, 73.6], [45.6, 74.0], [46.0, 74.4]];
drok_coupon_panels = [2.0, 3.0];
module drok_meter_coupon() {
    cw = drok_face_w + 8;
    cl = drok_face_l + 8;
    difference() {
        cube([3 * cw, 2 * cl, 3]);
        for (r = [0 : 1]) for (c = [0 : 2]) {
            cx = c * cw + cw / 2;
            cy = r * cl + cl / 2;
            cut = drok_coupon_cuts[c];
            pt = drok_coupon_panels[r];
            translate([cx - cut[0] / 2, cy - cut[1] / 2, -eps]) cube([cut[0], cut[1], 3 + 2 * eps]);
            if (pt < 3)   // z 0 = meter face side (print face-down, like the lid); clip side thinned
                translate([cx - cut[0] / 2 - 2.5, cy - cut[1] / 2 - 2, pt]) cube([cut[0] + 5, cut[1] + 4, 3 - pt + eps]);
            for (k = [0 : c]) translate([cx - 4 + k * 4, r * cl + 1.6, 3 - 0.8]) cylinder(d = 1.6, h = 1, $fn = 16);
            for (k = [0 : r]) translate([c * cw + 1.6, cy - 2 + k * 4, 3 - 0.8]) cylinder(d = 1.6, h = 1, $fn = 16);
        }
    }
}

// ============================================================================
//  Component keepouts [name, [x0,y0,z0], [x1,y1,z1]] — echoed for the
//  verification script, drawn by component_previews().
// ============================================================================
crow_y_back = crow_pcb_back_y - crow_back_depth;
keepouts = [
    ["heatsink", [hs_x0, hs_y0, floor_t], [hs_x0 + hs_len_x, hs_y0 + hs_dep_y, floor_t + hs_h]],
    ["ssr", [ssr_x0, ssr_y0, ssr_z0], [ssr_x0 + ssr_len_x, hs_y0, ssr_z0 + ssr_h_z]],
    ["ssr_wiring_zone", [ssr_x0, ssr_y0 - 20, ssr_z0], [ssr_x0 + ssr_len_x, ssr_y0, ssr_z0 + ssr_h_z]],
    // v12: straight wires out of the SSR ends (bare wire under saddle clamps)
    ["ssr_ac_wire_channel", [kp_center_x + kp_body_x / 2 + 0.5, ssr_wire_band[0], ssr_z0],
                            [ssr_x0, ssr_wire_band[1], ssr_z0 + ssr_h_z]],
    ["ssr_ac_wire_under_kp", [ssr_x0 - 40, ssr_wire_band[0], ssr_z0],
                             [kp_center_x + kp_body_x / 2 + 0.5, ssr_wire_band[1], kp_bottom_z - 1]],
    ["ssr_dc_wire_zone", [ssr_x0 + ssr_len_x, ssr_wire_band[0], ssr_z0],
                         [divider_x - divider_t / 2, hs_y0 - hs_clear - fence_t - 0.5, ssr_z0 + ssr_h_z]],
    ["inlet", [inlet_center_x - inlet_cutout_w / 2, wall_t, inlet_center_z - inlet_cutout_h / 2],
              [inlet_center_x + inlet_cutout_w / 2, wall_t + inlet_body_depth + inlet_wire_clearance_depth, inlet_center_z + inlet_cutout_h / 2]],
    ["oven_socket", [os_panel_t, os_center_y - os_face / 2, os_center_z - os_face / 2],
                    [os_depth, os_center_y + os_face / 2, os_center_z + os_face / 2]],
    ["shelly", [wall_t + shelly_clear, shelly_y0 + shelly_clear, floor_t],
               [wall_t + shelly_clear + shelly_t, shelly_y0 + shelly_clear + shelly_w, floor_t + shelly_h]],
    ["kp200_body", [kp_center_x - kp_body_x / 2, kp_center_y - kp_body_y / 2, kp_bottom_z],
                   [kp_center_x + kp_body_x / 2, kp_center_y + kp_body_y / 2, shell_h]],
    // v12: CrowPanel — LCM, PCB + back-side parts, cable plugs below, speaker plug above, USB-C plug
    ["crow_lcm", [bx(-crow_lcm_w / 2), crow_pcb_front_y, crow_cz - crow_lcm_h / 2],
                 [bx(crow_lcm_w / 2), crow_pcb_front_y + crow_lcm_t, crow_cz + crow_lcm_h / 2]],
    ["crow_pcb", [bx(-crow_pcb_w / 2), crow_y_back, bz(crow_pcb_h / 2)],
                 [bx(crow_pcb_w / 2), crow_pcb_front_y, bz(-crow_pcb_h / 2)]],
    ["crow_cable_zone", [bx(crow_conn_x0) - 1, crow_y_back, floor_t],
                        [bx(crow_conn_x1) + 1, crow_pcb_front_y, bz(crow_pcb_h / 2)]],
    ["crow_spk_plug", [bx(crow_spk_x0) - 1, crow_y_back, bz(-crow_pcb_h / 2)],
                      [bx(crow_spk_x1) + 1, crow_pcb_back_y, bz(-crow_pcb_h / 2) + crow_top_clear - 1]],
    ["usb_plug", [bx(crow_pcb_w / 2), crow_usb_cy - usb_plug_t / 2, crow_usb_cz - usb_plug_w / 2],
                 [box_w + 25, crow_usb_cy + usb_plug_t / 2, crow_usb_cz + usb_plug_w / 2]],
    ["max6675", [max_pos_x - max_board_w / 2, max_pos_y - max_board_h / 2, floor_t + 5],
                [max_pos_x + max_board_w / 2, max_pos_y + max_board_h / 2, floor_t + 6.6]],
    // v12.1: DROK meter body under the lid, and its terminal/wire zone below it
    ["drok_meter", [drok_center_x - drok_body_w / 2, drok_center_y - drok_body_l / 2, shell_h - drok_body_d],
                   [drok_center_x + drok_body_w / 2, drok_center_y + drok_body_l / 2, shell_h]],
    ["drok_terminals", [drok_center_x - drok_body_w / 2, drok_center_y - drok_body_l / 2, shell_h - drok_body_d - drok_wire_zone],
                       [drok_center_x + drok_body_w / 2, drok_center_y + drok_body_l / 2, shell_h - drok_body_d]]
];
for (k = keepouts) echo(str("KO|", k[0], "|", k[1][0], "|", k[1][1], "|", k[1][2], "|", k[2][0], "|", k[2][1], "|", k[2][2]));

module component_keepouts() {
    for (k = keepouts) translate(k[1]) cube(k[2] - k[1]);
}

// ============================================================================
//  Small helpers
// ============================================================================
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
//  Composite views
// ============================================================================
module lid_printable() {
    // v9.3: emitted MIRRORED for printing; flipping the printed part toward
    // you (about X) at assembly restores true plan coordinates.
    translate([0, box_d, 0]) mirror([0, 1, 0]) lid_print_orientation();
}

module lid_assembly_orientation() {
    translate([0, box_d, box_h]) rotate([180, 0, 0]) lid_printable();
}

module component_previews() {
    if (show_components) {
        color("DimGray", component_alpha) component_keepouts();
        color("Purple", component_alpha)
            translate([kp_center_x - kp_wid_x / 2, kp_center_y - kp_len_y / 2, box_h + 0.2])
                cube([kp_wid_x, kp_len_y, 1.5]);
    }
}

module assembly_view() {
    color("SteelBlue") bottom_shell();
    color("LightGray", 0.85) lid_assembly_orientation();
    color("DarkSlateGray") front_panel_installed();
    component_previews();
}
