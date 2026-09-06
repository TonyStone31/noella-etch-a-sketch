# Flip, Rotate, and arrays
Source: https://help.sketchup.com/en/sketchup/flipping-mirroring-rotating-and-arrays  (fetched 2 Sep 2026)

> **Read this first:** despite the page title, this page does **not** document
> arrays.  It covers Flip and Rotate only.  So the `x3` / `/5` array syntax I
> mentioned earlier has no source behind it that we can point at — the feature
> is real in SketchUp, the documented syntax is not on this page.  If arrays
> matter later, we will need a better source or we work it out from the app.

## Flip
Select the geometry (or hover it after activating Flip and click once).  Three
semi-transparent planes appear on the red / green / blue axes; click one to flip
about it.  Planes can be click-dragged along the axes first.

Arrow keys pick a plane: **←** green, **→** red, **↑** blue.

* **Ctrl** — click-drag a plane and release to leave a flipped *copy*.
* **Alt** — switch between the object's own axes and the parent axes.
* Hovering a face gives a **magenta custom flip plane**; click it to flip about
  that face.

## Rotate
1. Select the geometry.
2. Pick Rotate.  A protractor cursor appears.
3. Move until the protractor sits on the plane you want — it turns red, green or
   blue when perpendicular to that axis.  **Shift** locks that plane.
4. Click to set the vertex of the angle.
5. Click the first point of the angle.
6. Move and click to finish, or type the angle.

With Shift holding the plane, **Alt** frees the protractor to move elsewhere
while keeping the plane.

| Wanted | Type | Example |
|---|---|---|
| Exact angle | a decimal | `34.1` |
| A slope | two values, colon separated | `8:12` |

Negative values rotate anticlockwise.

## Folding
Rotate, but click-**drag** from one endpoint of the fold line to the other, then
click the start of the rotation and move.  Angle snaps apply near the protractor
and free rotation further out.

*(Rotate is implemented: the center, a point to measure from, then swing to
the angle or type it - `34.1`, or `8:12` for a slope, negative the other way.
The arrows pick the plane by axis color, Ctrl leaves a copy, and the angle
snaps to the fifteens near them.  Shift to hold an inferred plane, Alt to
move the protractor off it, Flip and Folding are not built.)*
