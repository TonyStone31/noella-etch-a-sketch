# Text, labels and dimensions
Source: https://help.sketchup.com/en/sketchup/adding-text-labels-and-dimensions-model  (fetched 2 Sep 2026)

Four kinds of text: **screen text** (pinned to the screen), **leader text** (a
line or arrow pointing at something), **3D text** (real edges and faces), and
**dimensions**.

## Dimensions
"Dimension entities move and update automatically as you create your model."

They can start and end on endpoints, midpoints, on-edge points, intersections,
arc centres and circle centres, and can be pulled into the red-green, red-blue
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
can sit centred, outside the start, or outside the end.  Endpoint style: slash
(the default), dot, closed arrow, open arrow, or none.  Colour and font are per
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

*(We have: a dimension entity you can erase, auto dimensions on lines with a
toggle, and plain notes.  We do not have: dimensioning by clicking one edge,
radius/diameter dimensions, leaders, 3D text, endpoint styles.)*
