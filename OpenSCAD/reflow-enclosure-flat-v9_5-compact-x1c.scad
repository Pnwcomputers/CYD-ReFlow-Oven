// ============================================================================
//  DIY Reflow Oven Controller — Compact Flat Bench Enclosure (v9.5, X1C Fit)
//  Parametric OpenSCAD model for Bambu X1C (PETG minimum, ASA preferred)
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
//  Intended AC path:
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
part = "assembly"; // ["bottom","lid","bezel","assembly","all_flat","iec_test_coupon","kp200_test_coupon"]

/* [Box outer dimensions]
   220 x 155 is the compact X1C-friendly footprint. It leaves room on a
   256 x 256mm Bambu bed for skirt/brim and avoids pushing the printable edge.
   Compact trick: the CYD is rotated 90 degrees on the DC side, while the
   3Dman IEC inlet moves behind the SSR on the rear wall. */
box_w = 220;
box_d = 155;
box_h = 65;
wall_t = 3;
floor_t = 3;
lid_t = 3;

/* [AC/DC divider] */
divider_x = 147;
divider_t = 2;

/* [AC side: SSR + heatsink]
   Rotated footprint so the 80mm heatsink length runs front/back and the
   50mm side sits next to the KP200 body in X. If your heatsink is different,
   adjust heatsink_w/heatsink_d and ssr_center_x/ssr_center_y. */
heatsink_w = 50;
heatsink_d = 80;
heatsink_h = 50;
ssr_center_x = divider_x - divider_t / 2 - heatsink_w / 2 - 0.5;
ssr_center_y = 105;
heatsink_top_z = floor_t + heatsink_h;

/* [AC side: 3Dman fused IEC C14 inlet + rocker/fuse module]
   Mounted on the REAR wall. This is the device input socket, not the smart
   shutoff. Dimensions are based on common 3Dman/Amazon-style listings:
   approx face/body 58 x 48 x 34mm. Print the coupon and measure your part. */
inlet_face_w = 58;          // visible/flange face width on rear wall, X
inlet_face_h = 48;          // visible/flange face height on rear wall, Z
inlet_body_depth = 34;      // body depth into enclosure, Y; MEASURE YOUR PART
inlet_wire_clearance_depth = 15;
inlet_cutout_w = 52;        // rectangular panel cutout width, X
inlet_cutout_h = 38;        // rectangular panel cutout height, Z
inlet_center_x = 118;
inlet_center_z = 31;
inlet_screw_pattern = "vertical"; // ["vertical","horizontal","none"]
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
kp_window_x = 65;           // access opening for sockets/button/LED
kp_window_y = 73;           // v9.2: was 70; widened toward 74mm hard ceiling (boss gap) for KP200 body insertion           // shorter than screw spacing so screw bosses land on solid lid
kp_lid_boss_h = 7;
kp_lid_boss_dia = 9;
kp_insert_dia = 4.5;
kp_insert_depth = 5;
kp_screw_clear_dia = 3.8;

/* [AC side: cable gland / output to oven]
   Put this on the LEFT side wall, rear-ish, so oven/load wiring exits sideways
   and the bottom remains completely flat. */
ac_out_gland_dia = 13;
ac_out_gland_y = 42;
ac_out_gland_z = 18;

/* [DC side: CYD top-lid mount]
   OPEN QUESTION: mounting hole pattern assumed 82 x 44mm for AITRIP variant.
   Compact v9 rotates the CYD 90 degrees so the 90mm board length runs front/back
   instead of left/right. This saves about 25-30mm of total enclosure width.
   Set cyd_rotate_90_for_compact = false only if you want the earlier landscape
   physical mounting orientation; you will likely need to widen box_w. */
cyd_rotate_90_for_compact = true;
cyd_raw_pcb_w = 90;
cyd_raw_pcb_h = 60;
cyd_raw_hole_w = 77.5;  // v9.5: was 82 (assumed). MEASURED center-to-center on the physical board: 77.5mm. (DIYmall drawing implies 78; measured board wins — clone variants differ)
cyd_raw_hole_h = 42;    // v9.5: was 44 (assumed). MEASURED center-to-center on the physical board: 42mm
cyd_raw_display_w = 60;
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
   Keep AC/DC crossings low and deliberate. */
ctrl_hole_dia = 6;
ctrl_hole_y = 36;
ctrl_hole_z = 15;
pwr_hole_dia = 6;
pwr_hole_y = 54;
pwr_hole_z = 15;

/* [Lid vent slots over SSR heatsink] */
vent_slot_w = 3;
vent_slot_len = 58;
vent_slot_count = 7;
vent_slot_gap = 6;

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
    [88, box_d - 10],   // v9.1: moved from [divider_x-10, box_d-10] — collided with heatsink corner (y up to 145)
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

echo("=== Compact flat bench enclosure v9 / X1C fit / KP200 + 3Dman IEC ===");
echo(str("Box: ", box_w, " x ", box_d, " x ", box_h, " mm"));
echo("Target printer: Bambu X1C 256 x 256mm bed; v9 footprint leaves ~36mm X and ~101mm Y spare before slicer limits.");
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
        }

        // ---- Wall cutouts / openings ----

        // 3Dman IEC inlet + rocker/fuse cutout, rear wall
        translate([inlet_center_x - inlet_cutout_w / 2, -eps, inlet_center_z - inlet_cutout_h / 2])
            cube([inlet_cutout_w, wall_t + 2 * eps, inlet_cutout_h]);

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

        // AC output cable gland, left side wall
        translate([-eps, ac_out_gland_y, ac_out_gland_z])
            rotate([0, 90, 0]) cylinder(d = ac_out_gland_dia, h = wall_t + 2 * eps);

        // Thermocouple gland, right side wall
        translate([box_w - wall_t - eps, tc_gland_y, tc_gland_z])
            rotate([0, 90, 0]) cylinder(d = tc_gland_dia, h = wall_t + 2 * eps);

        // USB-C side access slot, right side wall
        translate([box_w - wall_t - eps,
                   usb_slot_center_y - usb_slot_w_y / 2,
                   usb_slot_center_z - usb_slot_h_z / 2])
            cube([wall_t + 2 * eps, usb_slot_w_y, usb_slot_h_z]);

        // SSR control-wire pass-through in divider
        translate([divider_x - divider_t / 2 - eps, ctrl_hole_y, ctrl_hole_z])
            rotate([0, 90, 0]) cylinder(d = ctrl_hole_dia, h = divider_t + 2 * eps);

        // CYD 5V/GND power pass-through in divider
        translate([divider_x - divider_t / 2 - eps, pwr_hole_y, pwr_hole_z])
            rotate([0, 90, 0]) cylinder(d = pwr_hole_dia, h = divider_t + 2 * eps);

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

        // CYD display/touch opening through top lid
        translate([cyd_center_x - cyd_display_w / 2,
                   cyd_center_y - cyd_display_h / 2,
                   -eps])
            cube([cyd_display_w, cyd_display_h, lid_t + 2 * eps]);

        // CYD screw clearance holes through top lid / boss centers
        for (p = cyd_hole_positions)
            translate([p[0], p[1], -eps])
                cylinder(d = cyd_screw_clear_dia, h = lid_t + cyd_lid_standoff_h + 2 * eps);

        // Vent slots above SSR heatsink, through lid
        vent_span = (vent_slot_count - 1) * vent_slot_gap;
        for (i = [0 : vent_slot_count - 1])
            translate([ssr_center_x - vent_span / 2 + i * vent_slot_gap - vent_slot_w / 2,
                       ssr_center_y - vent_slot_len / 2,
                       -eps])
                cube([vent_slot_w, vent_slot_len, lid_t + 2 * eps]);
    }
}

module top_bezel() {
    difference() {
        translate([cyd_center_x - bezel_w / 2, cyd_center_y - bezel_h / 2, 0])
            cube([bezel_w, bezel_h, bezel_thickness]);

        // Visible display/touch window
        translate([cyd_center_x - cyd_display_w / 2, cyd_center_y - cyd_display_h / 2, -eps])
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

module iec_test_coupon() {
    coupon_w = inlet_face_w + 16;
    coupon_h = inlet_face_h + 16;
    coupon_t = wall_t;
    cx = coupon_w / 2;
    cy = coupon_h / 2;

    difference() {
        cube([coupon_w, coupon_h, coupon_t]);

        translate([cx - inlet_cutout_w / 2,
                   cy - inlet_cutout_h / 2,
                   -eps])
            cube([inlet_cutout_w, inlet_cutout_h, coupon_t + 2 * eps]);

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
    }
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
        translate([cx - cyd_display_w / 2, cy - cyd_display_h / 2, -eps])
            cube([cyd_display_w, cyd_display_h, lid_t + 2 * eps]);
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
        // SSR/heatsink envelope
        color("DimGray", component_alpha)
            translate([ssr_center_x - heatsink_w / 2,
                       ssr_center_y - heatsink_d / 2,
                       floor_t])
                cube([heatsink_w, heatsink_d, heatsink_h]);

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

        // 3Dman fused IEC/rocker/fuse module face preview
        color("Crimson", component_alpha)
            translate([inlet_center_x - inlet_face_w / 2,
                       -1.5,
                       inlet_center_z - inlet_face_h / 2])
                cube([inlet_face_w, 1.5, inlet_face_h]);

        // 3Dman module body preview / keepout inside the AC bay
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
