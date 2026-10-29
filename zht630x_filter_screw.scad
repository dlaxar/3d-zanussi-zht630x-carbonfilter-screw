// -----------------------------------------------------------------------------
// Zanussi ZHT630X carbon filter retaining "screw"
//
// A 43 mm disc with a 12 mm centre hole.  The upper side carries a ring
// around the centre hole with three bayonet lips sticking out of it, which
// slide under the three hooks of the hood's filter mount; the underside
// carries radial grip ribs so you can turn it by hand.
//
// Tightening is CLOCKWISE when you look at it from below (i.e. from where you
// stand under the hood).  Flip `tighten` if your mount turns the other way.
//
// The model is already in print orientation: grip ribs down on the bed, ring
// up.  The lips hang 2 mm out from the ring; enable supports under the three
// lips if your printer droops on that overhang.
//
// Requires BOSL2:  https://github.com/BelfrySCAD/BOSL2
// -----------------------------------------------------------------------------
include <BOSL2/std.scad>

/* [What to build] */
// screw = the real part, hook_test = thin disc with just the ring and lips for fit testing
part = "screw"; // [screw, hook_test]

/* [Base plate] */
plate_d = 43;
// several mm for stiffness: the plate is what clamps the filter
plate_t = 4;
hole_d = 12;
// chamfer on the top edge of the plate
plate_chamfer = 0.8;

/* [Hooks (upper side)] */
hook_count = 3;
// radius of the hook centre line
hook_r = 11;
// how far the lip sticks out of the ring
hook_w = 2;
// vertical thickness of the lip
hook_t = 3;
// plate top -> underside of the lip; the mount's hook slides into this gap
hook_gap = 3;
// length of the lip, measured along the arc at hook_r
hook_len = 3;
// the underside of the lip rises by this much at its tip, so the mount's hook
// finds its way in and gets pulled tight as you turn
lead_in = 0.8;
// arc length over which the lead-in ramp runs
lead_in_len = 2;
// direction of tightening, seen from below (from the grip side)
tighten = "cw_from_below"; // [cw_from_below, ccw_from_below]

/* [Ring (upper side)] */
// ring around the centre hole that carries the lips; at least hook_gap + hook_t
ring_h = 6;

/* [Grip (underside)] */
grip_ribs = 8;
grip_rib_w = 2.4;
// how far the ribs stand proud of the plate
grip_h = 2;
// ring around the centre hole that ties the ribs together
hub_wall = 2.5;
grip_chamfer = 0.6;

/* [Quality] */
$fa = 1;
$fs = 0.35;

eps = 0.01;

// -----------------------------------------------------------------------------
// Derived
// -----------------------------------------------------------------------------
hook_r_in  = hook_r - hook_w / 2;
hook_r_out = hook_r + hook_w / 2;
hook_top   = hook_gap + hook_t;
lip_ang    = hook_len / hook_r * 180 / PI;
lead_ang   = lead_in_len / hook_r * 180 / PI;
hub_od     = hole_d + 2 * hub_wall;

assert(hook_r_in > hole_d / 2, "hooks overlap the centre hole");
assert(hook_r_out < plate_d / 2, "hooks stick out past the plate");
assert(ring_h >= hook_top, "ring_h must reach the top of the lips");
assert(lead_in < hook_t, "lead_in eats the whole lip");
assert(lead_in_len <= hook_len, "lead_in_len is longer than the lip");
assert(hook_count * lip_ang < 360 - hook_count * 10,
       "hooks leave no room for the mount's hooks to drop in between them");

// -----------------------------------------------------------------------------
// Lips
//
// Built for tightening counter-clockwise seen from above (= clockwise seen
// from below): the part turns towards +angle, so the mount's hooks travel
// towards -angle relative to it and enter the lip from its +angle end.
// The lip runs from angle 0 towards +angle, lead-in ramp at the +angle end.
// -----------------------------------------------------------------------------

// Underside height of the lip at arc distance `s` from its start.
function lip_bottom(s) =
    let(t = s - (hook_len - lead_in_len))
    hook_gap + (t > 0 ? lead_in * t / lead_in_len : 0);

function lip_vnf() =
    let(
        a_end  = lip_ang,
        angles = concat(lerpn(0, a_end - lead_ang, 24, endpoint = false),
                        lerpn(a_end - lead_ang, a_end, 12)),
        rows = [for (a = angles)
                    let(zb = lip_bottom(a * PI / 180 * hook_r))
                    [for (p = [[hook_r_in, zb], [hook_r_out, zb],
                               [hook_r_out, hook_top], [hook_r_in, hook_top]])
                        [p[0] * cos(a), p[0] * sin(a), p[1]]]],
        vnf = vnf_vertex_array(rows, caps = true, col_wrap = true)
    )
    vnf_volume(vnf) < 0 ? vnf_reverse_faces(vnf) : vnf;

module hooks() {
    // yflip() mirrors the angles, i.e. reverses the tightening direction
    maybe_flip = tighten == "cw_from_below" ? [1, 1, 1] : [1, -1, 1];
    scale(maybe_flip)
        zrot_copies(n = hook_count)
            vnf_polyhedron(lip_vnf());
}

// -----------------------------------------------------------------------------
// Grip: radial ribs plus a hub ring, trimmed flush with the plate's rim.
// -----------------------------------------------------------------------------
module grip() {
    intersection() {
        cyl(d = plate_d, h = grip_h + eps, chamfer1 = grip_chamfer, anchor = BOTTOM);
        union() {
            tube(od = hub_od, id = hole_d, h = grip_h + eps,
                 ochamfer1 = grip_chamfer, anchor = BOTTOM);
            zrot_copies(n = grip_ribs, r = hub_od / 2 - 0.5)
                cuboid([plate_d / 2 - hub_od / 2 + 0.5, grip_rib_w, grip_h + eps],
                       chamfer = grip_chamfer, edges = [BOTTOM + FRONT, BOTTOM + BACK],
                       anchor = BOTTOM + LEFT);
        }
    }
}

// -----------------------------------------------------------------------------
// Parts
// -----------------------------------------------------------------------------
module screw(with_grip = true, t = plate_t, d = plate_d) {
    z0 = with_grip ? grip_h : 0;
    difference() {
        union() {
            if (with_grip) grip();
            up(z0) {
                cyl(d = d, h = t, chamfer2 = plate_chamfer, anchor = BOTTOM);
                up(t) hooks();
                // overlaps the lips' inner faces by a hair so they fuse
                up(t - eps) tube(od = 2 * hook_r_in + 0.1, id = hole_d,
                                 h = ring_h + eps, anchor = BOTTOM);
            }
        }
        // centre hole, with small chamfers at both mouths
        down(eps) cyl(d = hole_d, h = z0 + t + ring_h + 2 * eps,
                      chamfer = -0.5, anchor = BOTTOM);
    }
}

if (part == "screw")          screw();
else if (part == "hook_test") screw(with_grip = false, t = 1.6, d = 2 * hook_r_out + 6);
