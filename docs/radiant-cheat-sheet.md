# Radiant floor heating - concrete slab cheat sheet

The owner's own working notes, 23 September 2026, kept here as the rules
the radiant layout tool should come to apply on its own from the face it
is given - see TODO.md, *Radiant heat layout*.  Trade practice, not a
spec; a real design still wants a heat loss calculation per room.

## Tube size / typical use

| Size | Use |
|---|---|
| 3/8" PEX | small areas, specialty |
| 1/2" PEX | most residential radiant floors |
| 5/8" PEX | larger slabs, longer circuits |
| 3/4" PEX | large slabs, shops, garages, commercial floors |
| 1" PEX | uncommon for loops - distribution and mains |

## Typical tube spacing

| On center | Where |
|---|---|
| 6" | very high heat load, snow melt, perimeter boost |
| 9" | high heat loss areas |
| 12" | **standard** comfort heating in concrete slabs |
| 15" | lower heat loads, large commercial slabs |
| 18" | light heating, storage buildings - floor striping more likely |

Good default: 12" on center throughout a slab.  Consider 6"-9" for the
first few feet along large overhead doors, large glass, high-loss
exterior walls.  Avoid excessively wide spacing where comfort matters.

## Tubing per square foot

| Spacing | ft of tube per sq ft |
|---|---|
| 6" | 2.0 |
| 9" | 1.33 |
| 12" | 1.0 |
| 15" | 0.8 |
| 18" | 0.67 |

Add roughly 5-10% for bends, manifold runs and routing.

## Common practical loop lengths

| Tube | Typical | Common max |
|---|---|---|
| 1/2" | 200-300 ft | ~300 ft |
| 5/8" | 250-400 ft | ~400 ft |
| 3/4" | 300-500 ft | ~500 ft |

Not absolute hydraulic limits: pressure drop, required flow, pump
selection and balancing decide the real allowable length.  Keep the loops
on one manifold reasonably similar - not one at 150 ft and another at 500
unless the system is designed and balanced for it.

## 3/4" PEX - a good large-slab starting point

12" on center; target loop 400-450 ft, upper design range ~500 ft.  A 400
ft loop at 12" covers roughly 400 sq ft; 500 ft, roughly 500 sq ft.

## Flow

Typical circuit flow: 1/2" ~0.5-1.0 GPM, 5/8" ~0.75-1.5 GPM, 3/4" ~1-2+
GPM.  Actual flow comes from the heat load and the design delta-T,
commonly 10-20 F.  BTU/hr = 500 x GPM x delta-T; 1.5 GPM at 20 F is
15,000 BTU/hr.

## Water temperature

Typical slab supply 80-120 F; a common design area is 90-110 F.  Use
outdoor reset when practical.  Do not run boiler-temperature water
through a slab by default - the design temperature comes from the heat
loss and the floor's output.

## Concrete slabs

Typically 4"-6".  In a 6" slab keep the tube near the middle when
practical.  Do not leave it against the insulation unless the engineered
system calls for that.  Keep adequate concrete cover.  Keep tube away from
where anchors, saw cuts or fasteners will land.

## Insulation

Under a heated slab it matters a great deal: R-10 minimum is a common
target, more in cold climates or where code says so.  Insulate the
perimeter and edges.  Heat going down is wasted.

## Control joints / saw cuts

Know the joint locations before laying tube.  Avoid crossing joints where
practical.  Where a crossing is unavoidable: cross about perpendicular,
sleeve the tube, allow movement, photograph and document it.  The concrete
crew must know exactly where the tube is before any cut.

## Tubing layout

Smooth bends, never a kink, the maker's minimum bend radius observed.
Counter-flow / spiral layouts give the evenest floor; serpentine is
simpler but grades from the supply side to the return side.  Put the
hotter supply tube toward the highest-loss areas first - exterior walls,
doors, glass.

## Manifolds

Locate them to keep the leaders short.  Individual circuit isolation,
flow meters or balancing, purge and drain, actuators if zoned.  Label
every loop before the pour.

## Pressure testing

Test before the pour and keep the system pressurized during it, to the
maker's test pressure and procedure, never over its rating.  Watch the
gauge during placement: a sudden loss is the warning of damage.

## Before the pour

Pressure test every loop; verify loop lengths and manifold connections;
check for kinks and damage; photograph everything; measure and reference
tube positions from walls and columns; mark future walls, lifts, machines,
anchors; protect manifold stub-ups; make sure the concrete crew knows the
tube is there.

## After the pour

Do not heat a fresh slab at once.  Let the concrete cure to the concrete
and system requirements.  First heat gradual, not full-temperature water.

## Large shop / garage

Plan for future vehicle lifts, machinery anchors, wall anchors, floor
drains, plumbing, conduit, saw cuts.  Make no-tube zones wherever a deep
anchor may one day go.  Photograph extensively, with measurements, before
placement.

## Quick design default

A well-insulated 6" comfort-heated slab: 3/4" oxygen-barrier PEX, 12" on
center, 400-450 ft circuits kept reasonably equal, R-10+ under the slab,
insulated perimeter, manifolds with flow meters, pressure held through
the pour, tube locations documented.
