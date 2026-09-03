# Rectangle, Circle, Polygon
Source: https://help.sketchup.com/en/sketchup/drawing-basic-shapes  (fetched 2 Sep 2026)

## Rectangle — **R**
Click one corner, move diagonally, click the other.  Esc starts over.

Measurements box:
* `8',20'` — length then width, comma separated.
* `3',` — sets the first dimension only.  `,3'` — the second only.
* Negative values run the other way: `-24,-24`.
* Units may be typed per value and override the template.

Inferences: blue dots and **Square** when the sides match; **Golden Section**
when the ratio hits the golden ratio.  **Shift** locks the inference while
dragging.

Once you move on you cannot edit a rectangle's size — erase it, or scale it.

*(Built: `12'x8'`, `12',8'`, one side on its own as `6',` or `,6'`, and
negative values running the other way.  Not built: the Square and Golden
Section inferences.)*

## Circle — **C**
The Measurements box shows the segment count before you start; typing a number
changes it.  Click the centre, move out for the radius, click.  Esc restarts.

Immediately afterwards: type a length to change the radius (`6"`, `8'`, `34cm`).
Segment count is changed from Entity Info.

A circle is one entity: picking one segment picks the whole circle, but the
inference engine still sees the individual segments' endpoints and midpoints.

An ellipse is a circle scaled with the Scale tool by a middle grip.

*(We draw circles as polygons with a face.  Selecting one selects the whole
thing already.  No segment-count entry yet.)*

## Polygon
Same as Circle but with visible sides.  Type a number for the side count, click
the centre, move out for the radius, click.  Push/pulling a circle gives smooth
edges; a polygon shows its facets.

*(Not implemented.)*
