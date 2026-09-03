# Drawing basics, inferences and locking
Source: https://help.sketchup.com/en/sketchup/introducing-drawing-basics-and-concepts  (fetched 2 Sep 2026)

## The Line tool
**L**.  Click the start, watch the length in the Measurements box and the colour
of the line, click the end.  A typed value then Enter sets it exactly.  Esc
restarts.  It keeps going until another tool is picked.

Coordinates work here too: `[3', 5', 7']` absolute, `<1.5m, 4m, 2.75m>` relative
to the start point.

*(We have this on Move but not yet on Line — worth adding.)*

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
intersection, on face, on edge, centre, guide point, on line, on section.

**Linear:** on red / green / blue axis, from point, through point, parallel,
extend edge, perpendicular, perpendicular to face, tangent at vertex.

**Shape:** square, golden section, half / quarter / three-quarter circle, arc
side and centre, circle or polygon centre.

Everything is colour coded, with a ScreenTip naming it.  Pausing the cursor on a
point makes the engine prefer alignments to it.

## Locking with the keyboard — SketchUp's arrows
| Key | Locks to |
|---|---|
| **↑** | Blue axis (Z) |
| **←** | Green axis (Y) |
| **→** | Red axis (X) |
| **↓** | parallel/perpendicular to the inferenced edge or plane (magenta) |
| **Shift** | whatever direction or plane is currently showing |

> **We differ here.**  Our arrows are screen-relative: → +X, ← -X, ↑ +Y, ↓ -Y in
> plan; in ISO, → +X, ← -X, PgUp +Y, PgDn -Y, ↑ +Z, ↓ -Z.  That reads better in
> plan view, where SketchUp's ↑ would mean an axis pointing at your eye.  Say the
> word and it changes to SketchUp's mapping.

## Toggling linear inferencing (Line tool)
After the first click, **Alt** cycles: all inferences on → all linear inferences
off → parallel and perpendicular only.  *(Not implemented; our Alt holds the
working plane instead.)*
