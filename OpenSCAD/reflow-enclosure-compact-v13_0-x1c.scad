// ============================================================================
//  DIY Reflow Oven Controller — Compact Bench Enclosure (v13.0, X1C)
//  Parametric OpenSCAD model for Bambu X1C. PRINT IN ASA. No supports.
//
//  v13.0 (2026-11, compact layout): 250 x 155 x 83 -> 184 x 140 x 83 mm.
//  Same parts, same wire list. What changed, and why:
//  - The low-voltage bay was a full-depth 89 mm column holding a display that
//    is 12 mm deep: about a litre of air. It is now a POCKET behind the front
//    panel (17 mm deep at the top, 31 mm at the floor), closed off from the
//    mains bay by a stepped wall. The KP200 sits in the lid above the pocket:
//    its faceplate overhangs its body by 29 mm, and the pocket uses that.
//  - The mains bay keeps its floor area. Heatsink + SSR stay at the front with
//    the same intake slots and lid vents; the junction zone (Wagos, CT) is at
//    the rear between the oven socket and the inlet.
//  - Inlet: rear wall, 12 mm lower. Its wiring runs under the KP200 body.
//  - DROK meter: crosswise in the lid, so it reads from the front.
//  - Lid screws: 8 (was 9), in bosses hung from the walls and in the two front
//    posts. No boss stands on the floor, and none hides under the KP200
//    faceplate.
//  - Lid, inside: an L-shaped rib keeps the heatsink in its fence and screens
//    the meter and the KP200 from the lid slots; two ribs stiffen the lid at
//    the KP200; a bead along the front edge sits in a chamfer on the front
//    panel and holds the panel's top edge.
//  - Floor: a cable-tie saddle takes any common MAX6675 module (the old 4-boss
//    pattern was a guess), and three cable-tie anchors for the wiring.
//  - Front panel: two full-height posts in the intake gap either side of the
//    intake slots, two low posts in the pocket. 6 screws as before. To take
//    the panel off with the lid on: remove the screws, swing the bottom edge
//    out, lower the panel out of the bead.
//  - Unchanged: the display mount (standoffs, window, connectors-down, USB-C
//    through the side wall), the KP200 mount, every snap-in cutout, the SSR
//    orientation (AC terminals toward the oven-socket wall). All v12 coupons
//    stay valid.
//
//  NOTE: enclosure geometry only, not wiring approval. Verify current
//  ratings, fuse value, wire gauge, strain relief, grounding, creepage and
//  the physical part dimensions before using with mains voltage.
//
//  Coordinate system (installed):
//    X = width  (oven-socket wall x=0 -> USB-C / thermocouple wall x=box_w)
//    Y = depth  (rear wall y=0, inlet side -> FRONT panel y=box_d)
//    Z = height (floor -> lid)
//  Seen from the front, +X is on the viewer's LEFT: the display is on the
//  left of the front panel, the heatsink intake slots on the right.
//  To keep left/right out of it, the comments below call the two side walls
//  the SOCKET WALL (x = 0, on your right as you face the front) and the
//  USB WALL (x = box_w, on your left).
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
crow_boss_dia = 8.5;
crow_insert_dia = 4.2;
crow_insert_depth = 4;
// Window = touch active area (QD281801: 58.60 x 44.20, starting 2.40 mm from
// the non-FPC end). In board x it spans -32.2 .. +26.4.
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
usb_slot_along_y = 9;       // opening through the USB wall; fits overmolds up to ~13.5 x 7.5
usb_slot_along_z = 15;
usb_plug_t = 6.5;           // keepout for a typical USB-C overmold (APPROX)
usb_plug_w = 12.4;
crow_edge_gap = 0.5;        // standoff boss to USB wall

/* [Box outer dimensions] */
box_w = 184;                // v13: was 250. 36 mm spare per side on the 256 mm bed
box_d = 140;                // v13: was 155. KP200 faceplate (129) + 2 behind + 9 in front
box_h = floor_t + crow_cable_zone + crow_pcb_h + crow_top_clear + lid_t;   // = 83

/* [Low-voltage pocket behind the front panel] -- v13
   Interior: lv_w wide, against the USB wall. Its rear wall is stepped: at
   the floor the pocket is lv_low_d deep (room for the MAX6675 and the cable
   bends); above lv_step_z0 the wall leans forward at 45 degrees to lv_top_d,
   which keeps it in front of the KP200's front mounting screw. */
lv_w = 89;                  // the board needs 88.7 (PCB 85.7 + bosses)
lv_wall_t = 2;
lv_top_d = 17;              // display stack is 11.25 deep
lv_low_d = 31;
lv_step_z0 = 58;            // mains-side face is vertical up to here
lv_slope_drop = 1.4;        // pocket-side face runs this much lower: the 45-degree part is 2.4 mm thick

/* [DROK AC meter (B0B3WVG2V9), lid mount] -- v13: crosswise, reads from the front
   Measured by Jon 2026-11-21: face 76.5 x 48, body 73.37 x 45, body depth
   21.47 below the face. Snap-in from above. Long axis along X. */
drok_face_l = 76.5;
drok_face_w = 48;
drok_body_l = 73.37;
drok_body_w = 45;
drok_body_d = 21.47;
drok_cut_l = 74.0;          // cutout = body + ~0.6; confirm with drok_meter_coupon
drok_cut_w = 45.6;
drok_panel_t = 3;           // lid thickness at the meter; < lid_t pockets the underside for the clips
drok_wire_zone = 7;         // screw heads + wires leaving sideways below the body
drok_center_x = 46;
drok_center_y = 38;         // behind it: the rear lid screw at the socket wall; in front: the heatsink hold-down and the vents

/* [Mains side: SSR + heatsink]
   MEASURED heatsink 80 x 49.4 x 51; SSR APPROX 62 x 45 x 23.5 on the
   heatsink's REAR (-Y) face, terminals facing the rear. AC terminals (1, 2)
   at the SSR's end toward the socket wall, DC terminals (3, 4) at its end
   toward the display pocket. */
hs_len_x  = 80;
hs_dep_y  = 49.4;
hs_h      = 51;
hs_x0     = 7;
intake_gap = 10;            // v13: was 8. Plenum in front of the fins, and room for the two front posts
hs_y0     = box_d - fp_t - intake_gap - hs_dep_y;   // = 77.6
hs_clear  = 0.6;
ssr_len_x = 62;
ssr_h_z   = 45;
ssr_dep_y = 23.5;
ssr_x0    = hs_x0 + (hs_len_x - ssr_len_x) / 2;
ssr_z0    = floor_t + (hs_h - ssr_h_z) / 2;
ssr_y0    = hs_y0 - ssr_dep_y;
heatsink_top_z = floor_t + hs_h;
ssr_wire_band = [ssr_y0 - 12, ssr_y0 + 8];          // y band the straight wires leave the clamps in
ssr_wire_zone = 14;         // kept free behind the terminal face (screw heads, clamps, cover); the wires leave sideways
hs_hold_gap = 0.5;          // lid rib stops this far above the heatsink
hs_hold_t = 2.4;
hs_hold_y = 4;              // rib centre, measured from the heatsink's rear (SSR) face
lid_rib_h = 8;              // two stiffening ribs under the lid, behind and in front of the KP200
lid_rib_t = 2.4;

/* [Mains side: FILSHU fused IEC C14 inlet, rear wall] */
inlet_face_w = 50;
inlet_face_h = 30;
inlet_body_depth = 28;
inlet_wire_clearance_depth = 20;
inlet_cutout_w = 48.0;
inlet_cutout_h = 27.5;
inlet_clip_panel_t = 1.5;
inlet_clip_relief_w = 3;
inlet_clip_relief_extra_h = 2;
inlet_center_x = 120;
inlet_center_z = 19;        // v13: was 31. Lowest position the clip reliefs allow; the KP200 body is above its wiring
inlet_screw_pattern = "none";
inlet_screw_spacing = 40;
inlet_screw_dia = 3.4;

/* [Mains side: KP200 lid mount]  (mount unchanged from v10.3) */
kp_wid_x = 85;
kp_len_y = 129;
kp_depth_z = 44;
kp_screw_spacing = 83;
kp_center_x = 129.5;        // faceplate x 87..172: a 12 mm strip stays free along the USB wall for lid screws
kp_center_y = box_d - fp_t - 6 - kp_len_y / 2;
kp_window_x = 46;
kp_window_y = 72;
kp_ear_w = 22;
kp_ear_h = 20;
kp_ear_recess = 1.2;
kp_ear_corner_r = 3;
kp_ear_chamfer = 1.2;
kp_hole_skin = 0.2;         // one-layer skin over the KP200 holes at the recess roof (0 = open holes); pierce at assembly
kp_capscrew_offset = 6;
kp_capscrew_protrude = 6;
kp_capscrew_clear_dia = 5;
kp_lid_boss_h = 7;
kp_lid_boss_dia = 9;
kp_insert_dia = 4.5;
kp_insert_depth = 5;
kp_screw_clear_dia = 3.8;
kp_body_x = 45; kp_body_y = 70.5; kp_body_z = 45;   // MEASURED

/* [Mains side: NEMA 5-15R oven socket, socket wall] */
os_face      = 27;
os_depth     = 35;
os_cut       = 24.75;
os_panel_t   = 2.5;
os_pocket_margin = 3;
os_center_y  = 21;
os_center_z  = 22;

/* [Mains side: Shelly 1PM Gen4 pocket, USB wall] */
shelly_h = 37; shelly_w = 42; shelly_t = 16;
shelly_clear = 0.6;
shelly_y0 = 58;
shelly_rib_t = 2;
shelly_rib_h = 20;
shelly_lip_h = 8;

/* [Mains side: junction zone (3 x WAGO 221-415 and the meter's CT), floor]
   WAGO 221-415 is 30 x 18.6 x 8.4 mm. They stay loose, as designed for a
   junction box; the zone is kept free of printed parts and has two cable-tie
   anchors. The CT is tied to its wire at one of them. */
jz_x0 = 36;                 // past the oven socket body
jz_y1 = ssr_y0 - ssr_wire_zone;   // = 40.1; the SSR's terminal zone starts here
jz_h  = 37;
tie_h = 5;                  // cable-tie anchors: a 5 x 3 mm tunnel under a 2 mm bar

/* [Low-voltage pocket: MAX6675 saddle on the floor] -- v13
   Common modules are 25..32.5 mm long and 15..16 mm wide with one hole or
   none, so the board is held by a cable tie around the centre bar instead of
   screws. Two end pads with side lips locate it. */
max_len = 32.5;             // longest common module (keepout)
max_wid = 16;
max_pad_w = 16.4;           // clear width between the lips
max_pad_len = 8;
max_pad_gap = 18;           // open span between the pads (cable tie goes here)
max_pad_h = 4;              // board sits this far above the floor (solder tails)
max_lip_t = 1.2;
max_lip_h = 2;
max_bar_w = 4;
max_bar_t = 1.6;
max_x0 = 133;               // the saddle starts here; terminal block toward the USB wall

/* [Low-voltage pocket: thermocouple hole, USB wall] */
tc_gland_dia = 8;
tc_gland_y = 116;
tc_gland_z = 14;

/* [SSR control pass-through: slot through the pocket's rear wall]
   Closed slot (the wall above it leans over the pocket). Thread the cable's
   bare end through from the pocket side. */
ctrl_slot_w = 6;
ctrl_slot_x = 97;
ctrl_slot_z0 = 12;
ctrl_slot_z1 = 30;

/* [Lid outlet slots over the heatsink fin field]
   The rearmost slot edge must stay forward of (SSR terminal face y) +
   (shell_h - SSR top), so a 45-degree probe cannot reach the terminals. */
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
   Mains side: two full-height posts standing in the intake gap, one on
   each side of the intake slots (they also carry lid screws). Pocket: two low
   posts under the board's cable zone. The lid holds the panel's top edge. */
post_d = 10;                 // low pocket posts, depth (Y)
fp_insert_dia = 4.2;
fp_insert_depth = 6;           // M3x8 countersunk through the 3 mm panel leaves ~1 mm below the screw tip
fp_screw_clear = 3.4;
fp_screw_csk = 6.4;
fp_screw_csk_depth = 1.7;
fp_post_dc_h = 12;
fp_top_chamfer = 1.5;        // 45-degree chamfer on the panel's top outer edge; a bead under the lid's front edge sits in it
fp_bead_gap = 0.3;

/* [Lid screws / M3 heat-set inserts] */
boss_outer_dia = 8;
boss_insert_dia = 4.2;
boss_insert_depth = 5;
lid_screw_clear_dia = 3.4;
lid_screw_csk_dia = 6.4;
lid_screw_csk_depth = 2.0;
corbel_h = 18;               // length of a wall-hung boss below the lid seat
corbel_off = boss_outer_dia / 2 + 0.5;   // boss centre to the wall's inner face

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

dc_x_max = box_w - wall_t;
lv_x0    = dc_x_max - lv_w;          // pocket interior starts here (= 92)
dc_x_min = lv_x0;
dc_w     = lv_w;
lv_y_top = fp_in - lv_top_d;         // pocket-side face of the upper wall (= 120)
lv_y_low = fp_in - lv_low_d;         // pocket-side face of the lower wall (= 106)
lv_ac_y_top = lv_y_top - lv_wall_t;  // mains-side faces (= 118, 104)
lv_ac_y_low = lv_y_low - lv_wall_t;
lv_step_z1  = lv_step_z0 + (lv_ac_y_top - lv_ac_y_low);      // top of the 45-degree part, mains side (= 72)
// rear wall of the pocket, profile in (Y, Z)
lv_wall_profile = [
    [lv_ac_y_low, 0], [lv_ac_y_low, lv_step_z0], [lv_ac_y_top, lv_step_z1], [lv_ac_y_top, shell_h],
    [lv_y_top, shell_h], [lv_y_top, lv_step_z1 - lv_slope_drop],
    [lv_y_low, lv_step_z0 - lv_slope_drop], [lv_y_low, 0]
];
// the pocket's air space, profile in (Y, Z)
lv_void_profile = [
    [lv_y_low, floor_t], [lv_y_low, lv_step_z0 - lv_slope_drop], [lv_y_top, lv_step_z1 - lv_slope_drop],
    [lv_y_top, shell_h + 1], [fp_in + 1, shell_h + 1], [fp_in + 1, floor_t]
];

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

// Front posts on the mains side: [x0, width]. They stand in the intake gap,
// hs_clear in front of the heatsink, outside the span of the intake slots.
post_ac_y0 = hs_y0 + hs_dep_y + hs_clear;                    // = 129.6
post_ac_d  = fp_in - post_ac_y0;                             // = 7.4
intake_span = (intake_slot_count - 1) * intake_slot_gap + intake_slot_w;
fp_post_ac = [[wall_t, 9], [vent_center_x + intake_span / 2 + 0.5, lv_x0 - (vent_center_x + intake_span / 2 + 0.5)]];
fp_post_ac_sx = [wall_t + 4.5, (fp_post_ac[1][0] + lv_x0) / 2];    // panel-screw x in each post
lid_post_sx   = [wall_t + 4.5, fp_post_ac[1][0] + 4.5];            // lid-screw x in each post (clear of the KP200 faceplate corner)
fp_post_dc = [[lv_x0, 9], [dc_x_max - 9, 9]];                // low posts in the pocket
lid_post_y = fp_in - post_ac_d / 2;

// Lid screws. Posts: the two mains-side front posts.
lid_screws_post = [[lid_post_sx[0], lid_post_y], [lid_post_sx[1], lid_post_y]];
// Wall-hung bosses [x, y, wall dx, wall dy]: nothing stands on the floor.
cx_l = wall_t + corbel_off;  cx_r = dc_x_max - corbel_off;  cy_r = wall_t + corbel_off;
lid_corbels = [
    [cx_l, cy_r, -1, -1],                    // rear corner at the socket wall
    [cx_l, ssr_wire_band[1] + 6.4, -1, 0],   // socket wall, just in front of the SSR's AC wire band
    [82, cy_r, 0, -1],                       // rear wall, over the junction zone
    [cx_r, cy_r, 1, -1],                     // rear corner at the USB wall
    [cx_r, shelly_y0 - shelly_rib_t - boss_outer_dia / 2 - 2, 1, 0]   // USB wall, just behind the Shelly (it drops in past this boss)
];
// One boss in the corner of the USB wall and the pocket's upper wall; it
// grows out of the sloped part of that wall.
lid_slope_boss = [cx_r, lv_ac_y_top - boss_outer_dia / 2 + 1];
boss_positions = concat(lid_screws_post, [for (c = lid_corbels) [c[0], c[1]]], [lid_slope_boss]);

// Front-panel screws, [x, z] in box coordinates
fp_screws = [
    [fp_post_ac_sx[0], 12], [fp_post_ac_sx[0], shell_h - 15],
    [fp_post_ac_sx[1], 12], [fp_post_ac_sx[1], shell_h - 15],
    [fp_post_dc[0][0] + fp_post_dc[0][1] / 2, floor_t + fp_post_dc_h / 2],
    [fp_post_dc[1][0] + fp_post_dc[1][1] / 2, floor_t + fp_post_dc_h / 2]
];

crow_holes_xz = [for (sx = [-1, 1]) for (sy = [-1, 1]) [bx(sx * crow_hole_w / 2), bz(sy * crow_hole_h / 2)]];

kp_screw_positions = [
    [kp_center_x, kp_center_y - kp_screw_spacing / 2],
    [kp_center_x, kp_center_y + kp_screw_spacing / 2]
];
kp_front_reach = kp_center_y + kp_screw_spacing / 2 + kp_capscrew_offset + kp_capscrew_clear_dia / 2;   // front captive screw

max_y0 = lv_y_low + 0.5 + max_lip_t;         // board edge nearest the pocket's rear wall
max_saddle_len = 2 * max_pad_len + max_pad_gap;

// Cable-tie anchors on the mains floor: [x, y, rotation]
tie_anchors = [[jz_x0 + 12, 20, 0], [jz_x0 + 44, 20, 0], [lv_x0 + 8, 84, 90]];

vent_rear_edge = vent_center_y - (vent_slot_count - 1) * vent_slot_gap / 2 - vent_slot_w / 2;

echo("=== Compact bench enclosure v13.0 / X1C / CrowPanel 2.8 front panel + KP200 and DROK meter in the lid + FILSHU inlet + 5-15R socket ===");
echo(str("Box: ", box_w, " x ", box_d, " x ", box_h, " mm; shell ", shell_h, "; DC bay interior ", dc_w, " mm"));
echo(str("CrowPanel centre X/Z ", crow_cx, "/", crow_cz, "; PCB X ", bx(-crow_pcb_w / 2), "-", bx(crow_pcb_w / 2),
         " Z ", bz(crow_pcb_h / 2), "-", bz(-crow_pcb_h / 2), "; PCB front Y ", crow_pcb_front_y));
echo(str("Window X ", bx(crow_win_x0), "-", bx(crow_win_x1), " Z ", crow_cz - crow_win_h / 2, "-", crow_cz + crow_win_h / 2));
echo(str("USB-C slot centre Y/Z ", crow_usb_cy, "/", crow_usb_cz));
echo(str("Vent centre X/Y ", vent_center_x, "/", vent_center_y, "; rearmost slot edge Y ", vent_rear_edge));
echo(str("KP200 body bottom Z ", kp_bottom_z, "; heatsink top Z ", heatsink_top_z, "; SSR Z ", ssr_z0, "-", ssr_z0 + ssr_h_z));
echo(str("Pocket X ", lv_x0, "-", dc_x_max, "; depth ", lv_low_d, " at the floor, ", lv_top_d, " at the top; KP200 centre X/Y ", kp_center_x, "/", kp_center_y));
echo(str("DROK meter centre X/Y ", drok_center_x, "/", drok_center_y, "; cutout ", drok_cut_l, " x ", drok_cut_w,
         "; body bottom Z ", shell_h - drok_body_d));
echo(str("Lid screws: ", boss_positions));
echo(str("Mains posts X: ", fp_post_ac, "; depth ", post_ac_d));

assert(box_w <= 256 && box_d <= 256, "box exceeds X1C bed");
// --- pocket and display
assert(bx(-crow_hole_w / 2) - crow_boss_dia / 2 >= dc_x_min + 1, "CrowPanel boss hits the pocket side wall");
assert(bx(crow_pcb_w / 2) <= dc_x_max, "CrowPanel PCB hits USB wall");
assert(lv_top_d >= crow_standoff_h + crow_pcb_t + crow_back_depth + 4, "pocket too shallow for the display stack");
assert(floor_t + fp_post_dc_h <= bz(crow_pcb_h / 2) - 2, "pocket post hits board");
assert(fp_post_dc[0][0] + fp_post_dc[0][1] <= bx(crow_conn_x0) - 2, "pocket post blocks J7 cable");
assert(max_y0 + max_pad_w + max_lip_t <= crow_pcb_back_y - crow_back_depth, "MAX6675 saddle reaches under the display's cable zone");
assert(max_x0 + max_saddle_len + 10 <= dc_x_max, "no room to dress the thermocouple into the MAX6675 terminals");
assert(ctrl_slot_z1 + ctrl_slot_w / 2 <= lv_step_z0 - lv_slope_drop - 3, "control slot runs into the sloped wall");
// --- KP200 against the pocket walls and the lid edge
assert(kp_front_reach + 1 <= lv_ac_y_top, "KP200 front captive screw hits the pocket's upper wall");
assert(kp_center_y + kp_body_y / 2 + 2 <= lv_ac_y_low, "KP200 body hits the pocket's lower wall");
assert(kp_center_x - kp_body_x / 2 >= lv_x0 + 12, "no wiring channel left between the heatsink column and the KP200 body");
assert(kp_center_x + kp_wid_x / 2 <= cx_r - lid_screw_csk_dia / 2 - 1,
       "a USB-wall lid screw would be under the KP200 faceplate");
assert(norm([max(0, kp_center_x - kp_wid_x / 2 - lid_post_sx[1]), max(0, lid_post_y - (kp_center_y + kp_len_y / 2))]) >= lid_screw_csk_dia / 2 + 0.4,
       "the middle-post lid screw would be under the KP200 faceplate corner");
assert(kp_center_x - kp_wid_x / 2 >= lid_corbels[2][0] + lid_screw_csk_dia / 2 + 0.5, "the rear-middle lid screw would be under the KP200 faceplate");
assert(lid_corbels[4][1] + boss_outer_dia / 2 <= shelly_y0 - shelly_rib_t, "a lid-screw boss blocks the Shelly's drop-in path");
assert(lid_post_sx[1] - boss_insert_dia / 2 - fp_post_ac[1][0] >= 2.2, "middle post: lid insert too close to the post's edge");
assert(kp_center_y - kp_len_y / 2 >= 2 && kp_center_y + kp_len_y / 2 <= fp_in, "KP200 faceplate overhangs the lid");
assert(kp_bottom_z >= inlet_center_z + inlet_cutout_h / 2 + 2, "KP200 body sits on the inlet's wiring");
// --- inlet, socket, Shelly
assert(inlet_center_z - inlet_cutout_h / 2 - inlet_clip_relief_extra_h >= floor_t + 0.2, "inlet clip relief cuts into the floor");
assert(inlet_center_x - inlet_face_w / 2 >= jz_x0 + 55, "junction zone narrower than 55 mm");
assert(inlet_center_x + inlet_face_w / 2 + 2 <= dc_x_max - shelly_t - 2 * shelly_clear - shelly_rib_t || wall_t + inlet_body_depth + inlet_wire_clearance_depth <= shelly_y0 - shelly_rib_t,
       "inlet wiring runs into the Shelly pocket");
assert(os_center_y + os_face / 2 + os_pocket_margin <= ssr_wire_band[0] - 2, "oven socket pocket runs into the SSR's AC wire band");
assert(shelly_y0 + shelly_w + 2 * shelly_clear + shelly_rib_t <= lv_ac_y_low - 0.5, "Shelly pocket hits the pocket's rear wall");
// --- heatsink, vents, posts
assert(hs_x0 - hs_clear >= wall_t + 3, "no room for the socket-side fence strip");
assert(hs_x0 + hs_len_x + hs_clear + fence_t <= lv_x0 - lv_wall_t + 0.5, "heatsink fence hits the pocket side wall");
assert(ssr_x0 - wall_t >= 11.5, "SSR AC end: less than 11.5 mm to the wall for the wires");
assert(shell_h - heatsink_top_z >= 5, "heatsink stack too tall for lid");
assert(post_ac_d >= fp_insert_depth + 1.2 && post_ac_d >= boss_insert_dia + 2 * 2.4, "front posts too shallow for the inserts");
assert(fp_post_ac[0][0] + fp_post_ac[0][1] <= vent_center_x - intake_span / 2 - 0.5, "socket-side post covers an intake slot");
assert(fp_post_ac[1][1] >= 9, "middle post too narrow for an insert");
assert(vent_rear_edge >= ssr_y0 + 3 + (shell_h - (ssr_z0 + ssr_h_z)) + 1,
       "rearmost lid slot gives a 45-degree probe line to the SSR terminal face");
assert(hs_y0 + hs_hold_y + hs_hold_t / 2 + 3 <= vent_rear_edge, "heatsink hold-down rib blocks a vent slot");
// --- DROK meter
assert(drok_center_x - drok_face_l / 2 >= cx_l + lid_screw_csk_dia / 2 - 3.2 && drok_center_y - drok_face_w / 2 >= cy_r + lid_screw_csk_dia / 2 + 1,
       "DROK meter face covers the rear lid screw at the socket wall");
assert(drok_center_y + drok_face_w / 2 + lid_screw_csk_dia / 2 + 1 <= lid_corbels[1][1], "DROK meter face covers the socket-wall lid screw");
assert(drok_center_x + drok_face_l / 2 + 2 <= kp_center_x - kp_wid_x / 2, "DROK meter face touches the KP200 faceplate");
assert(drok_center_y + drok_body_w / 2 + 1 <= hs_y0, "DROK meter body is over the heatsink");
assert(drok_center_y + drok_face_w / 2 + 3 <= hs_y0 + hs_hold_y - 10 - hs_hold_t, "DROK meter runs into the hold-down rib's buttresses");
assert(shell_h - drok_body_d - drok_wire_zone >= max(jz_h + floor_t, ssr_z0 + ssr_h_z) + 0.5,
       "DROK meter terminal zone hits the junction zone or the SSR wiring zone");
assert(drok_center_y - drok_cut_w / 2 >= 12, "less than 12 mm of lid behind the meter cutout");
// --- lid ribs
assert(kp_center_y - kp_screw_spacing / 2 - kp_capscrew_offset - kp_capscrew_clear_dia / 2 >= lid_rib_rear_y + lid_rib_t + 1,
       "rear lid rib is in the way of the KP200's rear captive screw");
assert(lid_rib_front_y >= lv_y_top + 1 && lid_rib_front_y + lid_rib_t + 1 <= crow_pcb_back_y - crow_back_depth,
       "front lid rib does not fit between the pocket's rear wall and the back of the board");
assert(shell_h - lid_rib_h >= lv_step_z1 - lv_slope_drop + 1, "front lid rib reaches the sloped part of the pocket wall");
assert(lid_corbels[2][0] + boss_outer_dia / 2 + 0.5 >= drok_center_x + drok_cut_l / 2 + 3, "rear lid rib runs into the meter cutout");

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
//  Bottom shell — floor, rear and side walls, pocket walls, posts. Open front.
//  Prints floor down. Every overhang is 45 degrees or steeper, or a bridge.
// ============================================================================
module bottom_shell() {
    difference() {
        union() {
            difference() {
                cube([box_w, fp_in, shell_h]);
                translate([wall_t, wall_t, floor_t])
                    cube([box_w - 2 * wall_t, fp_in, shell_h]);
            }

            lv_walls();

            // Front posts: full height on the mains side, low in the pocket
            for (p = fp_post_ac)
                translate([p[0], post_ac_y0, floor_t - eps]) cube([p[1], post_ac_d, inner_h - 0.2 + eps]);
            for (p = fp_post_dc)
                translate([p[0], fp_in - post_d, floor_t - eps]) cube([p[1], post_d, fp_post_dc_h + eps]);

            // Lid-screw bosses: hung from the walls, and one on the sloped wall
            for (c = lid_corbels) lid_corbel(c[0], c[1], c[2], c[3]);
            lid_slope_boss_solid(lid_slope_boss[0], lid_slope_boss[1]);

            heatsink_fence();
            shelly_pocket();
            max_saddle();
            for (a = tie_anchors) translate([a[0], a[1], floor_t - eps]) rotate([0, 0, a[2]]) tie_anchor();
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

        // NEMA 5-15R socket, socket wall
        oven_socket_cut();

        // Thermocouple hole, USB wall, into the pocket beside the MAX6675
        translate([box_w - wall_t - eps, tc_gland_y, tc_gland_z])
            rotate([0, 90, 0]) cylinder(d = tc_gland_dia, h = wall_t + 2 * eps);

        // USB-C cable slot, USB wall, on the CrowPanel's USB-C axis
        translate([box_w - wall_t - eps, crow_usb_cy - usb_slot_along_y / 2, crow_usb_cz - usb_slot_along_z / 2])
            cube([wall_t + 2 * eps, usb_slot_along_y, usb_slot_along_z]);

        // SSR control pass-through
        ctrl_slot();

        // Rubber-foot recesses
        for (x = [foot_inset, box_w - foot_inset])
            for (y = [foot_inset, fp_in - foot_inset])
                translate([x, y, -eps]) cylinder(d = foot_dia, h = foot_recess_depth + eps);
    }
}

// Extrude a (Y, Z) profile along X from x0 to x1.
module yz_extrude(x0, x1) {
    translate([x0, 0, 0]) rotate([90, 0, 90]) linear_extrude(x1 - x0) children();
}

// Pocket walls: the stepped rear wall and the side wall next to the heatsink.
module lv_walls() {
    yz_extrude(lv_x0 - lv_wall_t, dc_x_max + eps) polygon(lv_wall_profile);
    translate([lv_x0 - lv_wall_t, lv_ac_y_low, 0]) cube([lv_wall_t, fp_in - lv_ac_y_low, shell_h]);
}

// Slot for the SSR control cable through the pocket's lower rear wall.
module ctrl_slot() {
    hull()
        for (z = [ctrl_slot_z0 + ctrl_slot_w / 2, ctrl_slot_z1 - ctrl_slot_w / 2])
            translate([ctrl_slot_x, lv_ac_y_low - eps, z])
                rotate([-90, 0, 0]) cylinder(d = ctrl_slot_w, h = lv_wall_t + 2 * eps);
}

// Lid-screw boss hung from one or two walls (wx, wy: -1/0/1 = direction of the
// wall). Its underside rises from the wall at more than 45 degrees.
module lid_corbel(x, y, wx, wy) {
    top = shell_h - 0.2;
    r = boss_outer_dia / 2;
    drop = corbel_off + r + 1;           // how far below the boss the root starts
    hull() {
        translate([x, y, top - corbel_h]) cylinder(d = boss_outer_dia, h = corbel_h);
        if (wx != 0)
            translate([x + wx * corbel_off - (wx > 0 ? 0 : eps), y - r, top - corbel_h - drop])
                cube([eps, 2 * r, corbel_h + drop]);
        if (wy != 0)
            translate([x - r, y + wy * corbel_off - (wy > 0 ? 0 : eps), top - corbel_h - drop])
                cube([2 * r, eps, corbel_h + drop]);
        // in a corner the root runs further down the corner itself, so the
        // underside between the two walls is a slope, not a flat ceiling
        if (wx != 0 && wy != 0)
            translate([x + wx * corbel_off - (wx > 0 ? 0 : eps), y + wy * corbel_off - (wy > 0 ? 0 : eps), top - corbel_h - 2 * drop])
                cube([eps, eps, corbel_h + 2 * drop]);
    }
}

// Lid-screw boss in the corner of the USB wall and the pocket's upper wall.
// A D-shaped column from which everything on the pocket side of the stepped
// wall's mid-plane is removed: what is left grows out of the 45-degree part.
module lid_slope_boss_solid(x, y) {
    r = boss_outer_dia / 2;
    cut = [for (p = lv_void_profile) [p[0] - lv_wall_t / 2, p[1]]];
    difference() {
        translate([0, 0, lv_step_z0])
            linear_extrude(shell_h - 0.2 - lv_step_z0)
                hull() {
                    translate([x, y]) circle(r);
                    translate([x - r, y]) square([dc_x_max + eps - (x - r), lv_ac_y_top + lv_wall_t / 2 - y]);
                }
        yz_extrude(lv_x0 - lv_wall_t - 1, box_w + 1) polygon(cut);
    }
}

// Cable-tie anchor: a 5 x 3 mm tunnel under a 2 mm bar.
module tie_anchor() {
    translate([-4.5, -2.5, 0]) difference() {
        cube([9, 5, tie_h + eps]);
        translate([2, -eps, -eps]) cube([5, 5 + 2 * eps, tie_h - 2 + 2 * eps]);
    }
}

// MAX6675 saddle: two end pads with side lips, joined by a bar the cable tie
// goes around. Fits modules 25..32.5 mm long and up to 16 mm wide.
module max_saddle() {
    yo = max_y0 - max_lip_t;                     // outer edge
    wo = max_pad_w + 2 * max_lip_t;
    for (x = [max_x0, max_x0 + max_pad_len + max_pad_gap]) {
        translate([x, yo, floor_t - eps]) cube([max_pad_len, wo, max_pad_h + eps]);
        for (y = [yo, yo + wo - max_lip_t])
            translate([x, y, floor_t]) cube([max_pad_len, max_lip_t, max_pad_h + max_lip_h]);
    }
    translate([max_x0 + max_pad_len - eps, max_y0 + max_pad_w / 2 - max_bar_w / 2, floor_t + max_pad_h - max_bar_t])
        cube([max_pad_gap + 2 * eps, max_bar_w, max_bar_t]);
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
        }

        // Display window (touch active area) with a 45-degree outer chamfer
        crow_window_cut(fp_t);

        // Panel screws, countersunk on the outer face
        for (s = fp_screws) {
            translate([s[0], s[1], -eps]) cylinder(d = fp_screw_clear, h = fp_t + 2 * eps);
            translate([s[0], s[1], -eps])
                cylinder(d1 = fp_screw_csk, d2 = fp_screw_clear, h = (fp_screw_csk - fp_screw_clear) / 2 + eps);
        }

        // Top outer edge: 45-degree chamfer for the lid's retaining bead
        translate([-eps, shell_h, 0]) rotate([0, 90, 0])
            linear_extrude(box_w + 2 * eps) polygon([[eps, eps], [eps, -fp_top_chamfer], [-fp_top_chamfer, eps]]);

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
//  Lid — KP200 flush mount, DROK meter, outlet slots, heatsink hold-down.
//  Modelled outer face down (z = 0), plan coordinates as installed.
// ============================================================================
module lid_print_orientation() {
    kp_hole_skins(kp_center_x, kp_center_y);
    hs_holddown();
    lid_stiffeners();
    difference() {
        union() {
            cube([box_w, box_d, lid_t]);
            for (p = kp_screw_positions)
                translate([p[0], p[1], lid_t]) kp_lid_boss(kp_lid_boss_h);
            // Retaining bead along the front edge: sits in the front panel's top
            // chamfer and keeps the panel's top edge from bowing outward.
            b = fp_top_chamfer - fp_bead_gap;
            translate([0, box_d, lid_t - eps]) rotate([90, 0, 90])
                linear_extrude(box_w) polygon([[0, 0], [-b, 0], [0, b + eps]]);
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

        // DROK AC meter, long side along X
        translate([drok_center_x - drok_cut_l / 2, drok_center_y - drok_cut_w / 2, -eps])
            cube([drok_cut_l, drok_cut_w, lid_t + 2 * eps]);
        if (drok_panel_t < lid_t)
            translate([drok_center_x - drok_cut_l / 2 - 3, drok_center_y - drok_cut_w / 2 - 6, drok_panel_t])
                cube([drok_cut_l + 6, drok_cut_w + 12, lid_t - drok_panel_t + eps]);

        vent_span = (vent_slot_count - 1) * vent_slot_gap;
        for (i = [0 : vent_slot_count - 1])
            translate([vent_center_x - vent_slot_len / 2,
                       vent_center_y - vent_span / 2 + i * vent_slot_gap - vent_slot_w / 2,
                       -eps])
                cube([vent_slot_len, vent_slot_w, lid_t + 2 * eps]);
    }
}

// Two ribs across the KP200's end of the lid, so pushing a plug in or pulling
// it out does not flex the lid between its screws. The rear one runs just in
// front of the two rear screw bosses; the front one drops into the top of the
// display pocket, between its rear wall and the back of the board.
lid_rib_rear_y  = cy_r + boss_outer_dia / 2 + 1.1;
lid_rib_front_y = (lv_y_top + crow_pcb_back_y - crow_back_depth) / 2 - lid_rib_t / 2;
module lid_stiffeners() {
    x0 = lid_corbels[2][0] + boss_outer_dia / 2 + 0.5;
    translate([x0, lid_rib_rear_y, lid_t - eps]) cube([dc_x_max - 0.5 - x0, lid_rib_t, lid_rib_h + eps]);
    translate([lv_x0 + 1, lid_rib_front_y, lid_t - eps]) cube([lv_w - 2, lid_rib_t, lid_rib_h + eps]);
}

// Heatsink hold-down: an L-shaped rib on the lid's inner face that stops
// hs_hold_gap above the heatsink, along its rear edge (over the SSR side) and
// its end beside the display pocket. The heatsink cannot climb out of its 5 mm fence if the
// box is tipped or carried. The same rib screens the meter terminals and the
// KP200 from anything pushed through the lid slots. Prints straight up.
module hs_holddown() {
    h = shell_h - heatsink_top_z - hs_hold_gap;
    t = hs_hold_t;
    y = hs_y0 + hs_hold_y;
    x0 = hs_x0 + 3;
    x1 = hs_x0 + hs_len_x - 0.6;
    translate([x0, y - t / 2, lid_t - eps]) cube([x1 - x0, t, h + eps]);
    translate([x1 - t, y - t / 2, lid_t - eps]) cube([t, hs_dep_y - hs_hold_y - 3 + t / 2, h + eps]);
    for (x = [x0 + 4, (x0 + x1) / 2 - 1])
        translate([x, y, lid_t - eps]) rotate([90, 0, 90]) linear_extrude(2) polygon([[0, 0], [-10, 0], [0, 16]]);
}

// ============================================================================
//  Test coupons and shared cut-outs (unchanged from v12.1: the printed coupons stay valid)
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

// The lid prints outer face down, so the roof of each ear recess is a bridge
// kp_ear_recess above the bed. A one-layer skin closes the screw hole and the
// captive-screw hole at that roof: the first roof layer is then a plain bridge
// (no hole edges drawn in mid-air), and the skins are pierced at assembly.
// Print coordinates; (cx, cy) = KP200 centre.
module kp_hole_skins(cx, cy) {
    if (kp_hole_skin > 0)
        for (s = [-1, 1]) {
            translate([cx, cy + s * kp_screw_spacing / 2, kp_ear_recess])
                cylinder(d = kp_screw_clear_dia + 0.4, h = kp_hole_skin);
            translate([cx, cy + s * (kp_screw_spacing / 2 + kp_capscrew_offset), kp_ear_recess])
                cylinder(d = kp_capscrew_clear_dia + 0.4, h = kp_hole_skin);
        }
}

module kp200_test_coupon() {
    coupon_w = kp_wid_x + 20;
    coupon_h = kp_len_y + 20;
    coupon_t = lid_t;
    cx = coupon_w / 2;
    cy = coupon_h / 2;
    kp_hole_skins(cx, cy);
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

// Heatsink locator fence. The socket-side strip is solid to the wall; the other strip
// is solid to the pocket's side wall.
module heatsink_fence() {
    xl0 = wall_t - eps;
    xl1 = hs_x0 - hs_clear;
    xr0 = hs_x0 + hs_len_x + hs_clear;
    xr1 = lv_x0 - lv_wall_t + eps;
    yl = hs_y0 - hs_clear - fence_t;
    yh = hs_y0 + hs_dep_y + hs_clear;
    translate([xl0, yl, floor_t - eps]) cube([xl1 - xl0, yh + fence_t - yl, fence_h + eps]);
    translate([xr0, yl, floor_t - eps]) cube([xr1 - xr0, yh + fence_t - yl, fence_h + eps]);
    for (y = [yl, yh]) {
        translate([xl0, y, floor_t - eps]) cube([xl1 - xl0 + fence_stub, fence_t, fence_h + eps]);
        translate([xr0 - fence_stub, y, floor_t - eps]) cube([xr1 - xr0 + fence_stub, fence_t, fence_h + eps]);
    }
}

// Shelly pocket against the USB wall: two ribs and a low lip.
module shelly_pocket() {
    iw = shelly_w + 2 * shelly_clear;
    it = shelly_t + 2 * shelly_clear;
    for (y = [shelly_y0 - shelly_rib_t, shelly_y0 + iw])
        translate([dc_x_max - it - shelly_rib_t, y, floor_t - eps])
            cube([it + shelly_rib_t + eps, shelly_rib_t, shelly_rib_h + eps]);
    translate([dc_x_max - it - shelly_rib_t, shelly_y0 - shelly_rib_t, floor_t - eps])
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
    ["ssr_wiring_zone", [ssr_x0, ssr_y0 - ssr_wire_zone, ssr_z0], [ssr_x0 + ssr_len_x, ssr_y0, ssr_z0 + ssr_h_z]],
    // straight wires out of the SSR ends (bare wire under saddle clamps)
    ["ssr_ac_wire_channel", [wall_t, ssr_wire_band[0], ssr_z0], [ssr_x0, ssr_wire_band[1], ssr_z0 + ssr_h_z]],
    ["ssr_dc_wire_zone", [ssr_x0 + ssr_len_x, ssr_wire_band[0], ssr_z0],
                         [lv_x0 - lv_wall_t, hs_y0 - hs_clear - fence_t - 0.5, ssr_z0 + ssr_h_z]],
    ["inlet", [inlet_center_x - inlet_cutout_w / 2, wall_t, inlet_center_z - inlet_cutout_h / 2],
              [inlet_center_x + inlet_cutout_w / 2, wall_t + inlet_body_depth + inlet_wire_clearance_depth, inlet_center_z + inlet_cutout_h / 2]],
    ["oven_socket", [os_panel_t, os_center_y - os_face / 2, os_center_z - os_face / 2],
                    [os_depth, os_center_y + os_face / 2, os_center_z + os_face / 2]],
    ["shelly", [dc_x_max - shelly_clear - shelly_t, shelly_y0 + shelly_clear, floor_t],
               [dc_x_max - shelly_clear, shelly_y0 + shelly_clear + shelly_w, floor_t + shelly_h]],
    ["kp200_body", [kp_center_x - kp_body_x / 2, kp_center_y - kp_body_y / 2, kp_bottom_z],
                   [kp_center_x + kp_body_x / 2, kp_center_y + kp_body_y / 2, shell_h]],
    // Wagos and the meter's CT (free volume above the two cable-tie anchors)
    ["junction_zone", [jz_x0, wall_t, floor_t + tie_h + 0.1], [inlet_center_x - inlet_face_w / 2 - 1, jz_y1, floor_t + jz_h]],
    // CrowPanel — LCM, PCB + back-side parts, cable plugs below, speaker plug above, USB-C plug
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
    // MAX6675 module on its saddle (longest common module, parts up to 14 mm tall)
    ["max6675", [max_x0, max_y0 + (max_pad_w - max_wid) / 2, floor_t + max_pad_h + 0.05],
                [max_x0 + max_len, max_y0 + (max_pad_w + max_wid) / 2, floor_t + max_pad_h + 14]],
    // DROK meter body under the lid, and its terminal/wire zone below it
    ["drok_meter", [drok_center_x - drok_body_l / 2, drok_center_y - drok_body_w / 2, shell_h - drok_body_d],
                   [drok_center_x + drok_body_l / 2, drok_center_y + drok_body_w / 2, shell_h]],
    ["drok_terminals", [drok_center_x - drok_body_l / 2, drok_center_y - drok_body_w / 2, shell_h - drok_body_d - drok_wire_zone],
                       [drok_center_x + drok_body_l / 2, drok_center_y + drok_body_w / 2, shell_h - drok_body_d]]
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
        color("Firebrick", component_alpha)
            translate([drok_center_x - drok_face_l / 2, drok_center_y - drok_face_w / 2, box_h + 0.2])
                cube([drok_face_l, drok_face_w, 1.5]);
    }
}

module assembly_view() {
    color("SteelBlue") bottom_shell();
    color("LightGray", 0.85) lid_assembly_orientation();
    color("DarkSlateGray") front_panel_installed();
    component_previews();
}
