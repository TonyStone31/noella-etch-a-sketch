# Text, labels and dimensions
Source: https://help.sketchup.com/en/sketchup/adding-text-labels-and-dimensions-model  (fetched 2 Sep 2026)

Four kinds of text: **screen text** (pinned to the screen), **leader text** (a
line or arrow pointing at something), **3D text** (real edges and faces), and
**dimensions**.

## Dimensions
"Dimension entities move and update automatically as you create your model."

They can start and end on endpoints, midpoints, on-edge points, intersections,
arc centers and circle centers, and can be pulled into the red-green, red-blue
or blue-green plane.  A dimension can measure a length, a circle's diameter or
an arc's radius.

### Steps
1. Pick the Dimension tool.
2. Click the start point.
3. Move along the entity until the inference engine lights the end you want.
4. Click the end point.
5. Move perpendicular to pull the dimension line out.  Orbit if it needs to sit
   in a different plane.
6. Click to place it.

> **Tip: to dimension a single line, just click the line and move the cursor.**
> *(This is the "dimension an existing edge by clicking it" item on our list.)*

Typing over a dimension's text breaks its link to the geometry and it stops
updating.

### Editing
Right-click a radius or diameter dimension > **Type > Radius / Diameter**.  Text
can sit centerd, outside the start, or outside the end.  Endpoint style: slash
(the default), dot, closed arrow, open arrow, or none.  Color and font are per
entity in Entity Info, or model-wide in Model Info > Dimensions.

## Leader text
Click the entity, move to place the text, click, type.  Enter twice or a click
outside finishes it.  **Double-click a face with the Text tool to drop its area
in as text.**

Leader styles: Pushpin (default, rotates with the model), View Based, Hidden.
Arrow styles: none, dot, closed, open.

## 3D text
Tools > 3D Text.  Font, alignment, height, Filled, Extruded.  A negative
extrusion engraves.

### What hovering does

The docs say only that "as you hover your mouse, the SketchUp inference engine
helps you identify these points", but in the app the edge under the cursor
lights up before you click it, and that is the half that makes the rest make
sense — it tells you whether the click is about to take the whole edge or start
a point-to-point.

> "After you place a dimension in a plane, you can move the dimension only
> within that plane."

### Editing the extension lines
Hovering the end of an extension line turns the cursor into the Move tool;
dragging moves that one extension line.  Dragging its offset point parallel to
the line changes that one line's length.
*(Not built.)*

*(Built: hovering an edge lights it up; one click takes the whole edge; the
dimension is previewed with its witness lines, end slashes and reading as you
pull it out; the offset is a vector in the model, so it holds its distance as
you zoom and stays in its plane as you orbit.  A dimension is an ordinary
entity — select it, erase it, and nothing else snaps to it.  Double-clicking a
face with the Text tool drops its area in.

Not built: radius and diameter dimensions, leaders, 3D text, endpoint styles,
dragging the extension lines, typing over the reading.)*


## Writing over a dimension's figure

Added 3 September 2026.  Right-click a dimension and type what it should say;
leave the box empty to hand it back to the measured length.  The measurement
underneath is untouched, so the drawing still knows what it really is even
when the label says something else.

This is not polish.  A fabrication drawing routinely has to say something the
geometry does not - a nominal size, a cut length that allows for a fitting,
FIELD VERIFY - and on an isometric, which is not to scale to begin with, the
written figure *is* the drawing.  See `docs/isometric-views.md`.
