# Push/Pull
Source: https://help.sketchup.com/en/sketchup/pushing-and-pulling-shapes-3d  (fetched 2 Sep 2026)

Shortcut **P**.  Works on any face — circular, rectangular or abstract.

## Pulling
1. Press P.
2. Click the face.  It shades to say it is taken.
3. Move the cursor; the Measurements box shows the depth.
4. Click to set it, or type a number and press Enter.

Tips from the page:
* A face that is hard to click can be **preselected with the Select tool** first,
  then push/pulled.
* To pull a face parallel with another face, hover the Push/Pull cursor over the
  other face first — the inference engine then reports when the two are parallel.
* **Esc** starts over.
* Extrusions thinner than about an inch can show edges through the entity; that
  is a rendering limit, not a modelling one.

## Repeating an extrusion
* **Double-click another face** — repeats the same extrusion there.
* **Ctrl then double-click a face** — stacks an identical extrusion on it.

## Cutting
1. Press P, click the face, move inward.
2. Push partway, or right through.  Dragging all the way shows a message saying
   the offset is limited.
3. Click, or type the distance.

To cut a hole clean through, the pushed face must be **parallel** with the face
on the far side, and no lines may divide that far face — erase them first.

*(Built: preselect a face with the arrow then push it, and double-click
another face to repeat the last pull.  Not built: the parallel inference,
Ctrl double-click to stack, the "offset is limited" message.)*

## Where ours stands, 5 September 2026

Push/pull infers to what the cursor rests on: a parallel face, and now any
point or edge - hover the far edge of a box and the push stops flush with the
far side.  A shape pushed clean through to the far face of its own solid is a
hole: the far face gets the opening, the tunnel is walled, the pushed face is
gone, the same as SketchUp.  Double-click repeats the last push.
