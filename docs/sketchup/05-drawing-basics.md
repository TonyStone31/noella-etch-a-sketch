# Drawing basics, inferences and locking
Source: https://help.sketchup.com/en/sketchup/introducing-drawing-basics-and-concepts  (fetched 2 Sep 2026)

## The Line tool
**L**.  Click the start, watch the length in the Measurements box and the color
of the line, click the end.  A typed value then Enter sets it exactly.  Esc
restarts.  It keeps going until another tool is picked.

Coordinates work here too: `[3', 5', 7']` absolute, `<1.5m, 4m, 2.75m>` relative
to the start point.

*(Built on Line and on Move.)*

## Faces
A closed loop of lines makes a face.  Drawing a line or curve across a face
splits it in two, and push/pull can then lift one half.

## Erasing edges vs faces
Eraser + click an edge removes the edge and any face it bounded.  Right-click a
face > Erase removes only the face.  **Shift** + Eraser hides an edge instead of
erasing it.

## Healing
Undo, or redraw the line that was removed — the face comes back on its own.

## Inference types
**Point:** origin, component origin, endpoint, midpoint, arc midpoint,
intersection, on face, on edge, center, guide point, on line, on section.

*(We have endpoint, midpoint, arc center, intersection and **on edge**.  Not
on face while a shape is under way, no guide points, no sections.  Each shows
as one small solid diamond colored the way SketchUp colors it: green a
corner, cyan a middle, red a point lying on an edge, violet a crossing.)*

### From Point — the one that matters most

> **From Point** — "Linear alignment from a point; dotted line color matches
> axis direction."

This is the feature with no obvious name: rest the cursor on a corner for a
moment to *encourage* the inference, move away, and a dotted guide keeps you
lined up with it.  The important half is that it **combines** with whatever
else is in force.  Running left along the red axis from the top corner of a
rectangle, with the bottom-left corner encouraged, the answer is where the two
guides cross — and that is how you close the rectangle square without a corner
to snap to.

*(Built.  Resting on a point for 450 ms holds it; the guide is magenta, and it
survives an axis lock rather than being thrown away by it.  A held point holds
from 18 pixels either side, where one the engine merely noticed holds from 7 —
you asked for the held one, so it should be harder to shake off.)*

**Linear:** on red / green / blue axis, from point, through point, parallel,
extend edge, perpendicular, perpendicular to face, tangent at vertex.

**Shape:** square, golden section, half / quarter / three-quarter circle, arc
side and center, circle or polygon center.

Everything is color coded, with a ScreenTip naming it.  Pausing the cursor on a
point makes the engine prefer alignments to it.

## Locking with the keyboard — SketchUp's arrows
| Key | Locks to |
|---|---|
| **↑** | Blue axis (Z) |
| **←** | Green axis (Y) |
| **→** | Red axis (X) |
| **↓** | parallel/perpendicular to the inferenced edge or plane (magenta) |
| **Shift** | whatever direction or plane is currently showing |

**Ours matches**, in every view: → red X, ← green Y, ↑ blue Z.  ↓ lets go
again, our stand-in for the magenta parallel/perpendicular lock we do not have.
A lock is on the axis and not on one direction along it, so you can draw back
the other way without unlocking.  The same three keys pick the *plane* for the
shape tools, naming it by the axis it is normal to: → the YZ plane, ← the XZ
plane, ↑ the flat XY plane.

## Toggling linear inferencing (Line tool)
After the first click, **Alt** cycles: all inferences on → all linear inferences
off → parallel and perpendicular only.  *(Not implemented; our Alt holds the
working plane instead.)*
