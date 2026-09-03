# Offset
Source: https://help.sketchup.com/en/sketchup/offsetting-line-existing-geometry  (fetched 2 Sep 2026)

Shortcut **F**.  Makes an equidistant copy of a shape — inside and outside wall
lines, an overhang, the wall of a vessel.

1. Select two or more connected, coplanar lines (or work straight on a face).
2. Press F.
3. Click a selected segment, or the face.
4. Move to set the distance — it shows in the Measurements box.
5. Click.

A number typed afterwards resets the distance, and can be changed again until
some other drawing change happens.

* **Alt** keeps overlaps, which are otherwise cleaned up automatically.
* **Double-clicking another face** right after an offset applies the same offset
  to it.
* Offsetting an arc gives a curve that can no longer be edited as an arc —
  except that circular arcs of three or more segments keep their arc entity.

*(Built.  **F**, or `/offset`.  Click a face, then move in or out and click,
or type a thickness.  The readout says how far and which way.  Outward and
inward both work, and taking it in further than the shape will go is refused
rather than drawn - a 10 x 6 taken in by 3 would come back as a line and by 4
as a box wound inside out, and neither is an offset of anything.

Not built: working on a run of selected lines rather than a whole face, Alt
to keep the overlaps, and double-clicking another face to repeat.  Offsetting
an arc gives straight segments, because that is how arcs are stored.)*
