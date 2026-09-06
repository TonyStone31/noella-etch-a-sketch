# Arcs
Source: https://help.sketchup.com/en/sketchup/drawing-arcs  (fetched 2 Sep 2026)

An arc is many straight segments acting as one entity.  Default 12 segments.

## The four arc tools
**Arc** — click the center, click the start point, click the end.  A protractor
shows the plane.  The Measurements box takes the Radius, then the Angle.
Produces an open arc.

**Pie** — the same three clicks, but closes into a face.

**2 Point Arc** — click one end, click the other (Measurements box takes the
chord Length), then move perpendicular and click for the bulge (Measurements box
takes the Bulge).  Watch for the half-circle inference.  **Double-clicking**
another pair of corners repeats the same arc and cleans up the excess geometry.

**3 Point Arc** — click the start, click a pivot, click the end.

## Measurements box, after the fact
| Wanted | Type | Example |
|---|---|---|
| Bulge | the value on its own | `5'` |
| Radius | number + `r` | `24r`, `3'6"r`, `5mr` |
| Segments | number + `s` | `20s`, `10s` |
| Segments from a circle | number + `c` | `20c` |

Ctrl **+** / Ctrl **−** step the segment count.

## Locking and tangency
Arrow keys lock: ↑ blue, ← green, → red.  For a tangent arc, hover the edge you
want it tangent to *before* the first click, and **Alt** locks the tangent
inference.

## Editing
Move tool on the arc's midpoint reshapes it; on an endpoint changes its length
and radius.  Entity Info takes a radius or segment count.  An arc scaled
non-uniformly stops being an arc.

*(We have the 2-point-plus-bulge arc only, with the bulge typed as a length.
No radius or segment syntax, no tangency lock, no arc/pie/3-point tools, no
double-click repeat.)*

## Where ours stands, 5 September 2026

The two-point arc is the one we have: two ends, then pull the middle out or
type the bulge.  It draws the way SketchUp's does now - the ends marked, the
chord, the pull from the chord's middle in its axis color, the arc live, the
bulge in the bar - and it is built in the plane the three points are in, so an
arc drawn up the end of a box stands on the end of the box.  A point resting
on a face reads ON FACE.  The centre-point arc, the three-point arc and the
pie are not built, and neither is tangency.

Sides: `24s` (or `s24`) typed on the circle or arc tool sets how many
straight pieces it is made of, as in SketchUp; `+` and `-` step it while the
tool is in hand, and the cursor tip shows the count.  Circles start at 24,
arcs at 12.  The count is kept with the arc and is what every later cut - a
tunnel drilled through it - is made in.
