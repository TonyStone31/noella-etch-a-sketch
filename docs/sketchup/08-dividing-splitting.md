# Dividing, splitting, welding, exploding
Source: https://help.sketchup.com/en/sketchup/dividing-splitting-and-exploding-lines-and-faces  (fetched 2 Sep 2026)

## Lines split each other
"SketchUp splits a line segment when a new line is drawn perpendicular to that
line."  They need not be perpendicular — any line crossing another line or arc
**on a face** splits it.  What looked like one continuous line becomes separate
selectable segments.

## Divide
Right-click a line or arc > **Divide**.  Points appear; moving the cursor toward
the middle gives fewer segments, toward the ends more.  A length may be typed
for each segment.  Click to accept.

*(Needs a context menu, which we do not have.)*

## Welding
Select the edges, right-click > **Weld Edges** — they become one Curve, the
SketchUp equivalent of a polyline.  Welded curves push/pull into smoothed faces
and make good Follow Me paths.

## Splitting a face
Draw a line with both ends on the face's edges.

## Healing a face
Erase the dividing line or arc and the face becomes whole again.

*(We do this: `MergeFacesAcross` on erase.)*

## Exploding
Right-click a circle, arc, polygon or curve > **Explode Curve** to get individual
segments, since selecting any one segment otherwise selects the whole entity.
