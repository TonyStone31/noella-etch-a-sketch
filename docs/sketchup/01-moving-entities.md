# Move — how SketchUp does it
Source: https://help.sketchup.com/en/sketchup/moving-entities-around  (fetched 2 Sep 2026)

## The sequence
1. Select what is to move, with the Select or Lasso tool.
2. Activate Move, or press **M**.
3. Click a **reference point** — a point on the selection that will line up with
   something else.
4. Move the pointer.  Inferences show, and the Measurements box counts.
5. Click the destination.
6. A distance or coordinate may be typed during the move or immediately after it.

## Axis locking
* **Shift** held while the move line is already showing an axis colour locks the
  inference to that axis.
* **Arrow keys** lock an axis outright, without waiting for the inference.

## Measurements box
* **Distance** — positive or negative, e.g. `20'`, `-35mm`.  A typed unit beats
  the template's; mixed units are allowed (`3' 6"` works in a metric template).
* **Global coordinates** — `[3', 4', 5']`, square brackets, measured from the
  model origin.
* **Relative coordinates** — `<3', 4', 5'>`, angle brackets, measured from the
  point the move started at.

## Corner inference grips
Hovering or selecting a component/group puts inference icons on its bounding-box
corners.  With the selection made and the cursor away from a grip, **Alt**
(Windows) cycles the visible grips: corners, midpoints, side centres, centre.

*(Grips are a group/component feature.  We have no groups yet, so this is not
implemented.)*
