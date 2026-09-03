# Line weight is a style, not a property of an edge
Sources:
  https://help.sketchup.com/en/sketchup/edge-styles
  https://forums.sketchup.com/t/adjusting-line-weight-in-sketchup-pro/6163
  (fetched 3 September 2026)

**SketchUp has no per-edge thickness.**  Weight is a setting on the *style*,
applied to the whole model.  Everything you draw comes out the same width.

The style's edge settings, all in pixels:

* **Profiles** - "emphasizes the outlines of major shapes in your model.  You
  can choose a thickness, in pixels, for the profile lines."  This is what
  gives a SketchUp model its look: the silhouette is heavier than the interior
  edges.
* **Depth Cue** - "emphasizes foreground lines over background lines.  Enter a
  foreground line thickness in pixels."
* **Extension** - "extends each line slightly past its endpoint for a
  hand-drawn appearance."
* **Endpoints** - "adds additional line thickness at the endpoints of lines."
* **Jitter** - renders each line several times at a slight offset.

Edge colour is also a style setting: **All Same**, **By Material**, or
**By Axis**.

Per-object line weight is a LayOut feature, not a SketchUp one.

## What we do

We stored a weight on every entity, set from the pen size at the moment it was
drawn.  That is where the "thick lines left behind" came from: a rectangle
drawn with a 4 pixel pen kept four heavy lines round its base, while every edge
push/pull created was hardcoded to 1.

As of 3 September 2026 the renderer takes **one weight for the whole drawing**
and uses it for every edge and every face outline, which is SketchUp's model.
The WIDTH control now changes the whole drawing at once, live, the way a style
setting does.  The per-entity weight is still written to the file so older
drawings load unchanged, but nothing renders from it.

**Not built:** Profiles, Depth Cue, Extension, Endpoints, Jitter, and the
By Material / By Axis edge colouring.  Profiles is the one worth having - it
is most of why a SketchUp model reads as solid.
