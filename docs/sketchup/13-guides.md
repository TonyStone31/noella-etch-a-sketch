# Guides
Source: https://help.sketchup.com/en/using-guides  (fetched 5 Sep 2026)

Two kinds, and neither is geometry:

* **Guide lines** — "temporary dashed lines you can use as guides to help as
  you draw."  Infinite, and they cannot be resized.
* **Guide points** — "standalone points you can use as inferences."

Neither interferes with regular geometry.  They exist to be snapped to and
then thrown away.

## Making them with the Tape Measure

**A guide line**

1. Take the Tape Measure.
2. Press **Ctrl** to make sure Create Guide Line mode is on - the cursor icon
   says which mode it is in.
3. Click a point on an entity **parallel to** where the guide should go.
4. Move the cursor **perpendicular** to that point.
5. Type a distance in the Measurements box for an exact one.
6. Click to set it.

**A guide point**

1. Take the Tape Measure.
2. Press **Ctrl** to confirm Create Guide Point mode - a different icon again.
3. Click anywhere in the model.

So Ctrl is a three-way toggle over the tape's modes rather than an on/off:
measure only, guide line, guide point.

## Making them with the Protractor

The Protractor lays a guide at an angle:

1. Hover over the model, or use the arrow keys, to choose the plane - its
   colour says which.
2. Hold **Shift** to lock that plane.
3. Click to set the vertex of the angle.
4. **Alt** (Windows) or **Command** (macOS) frees the protractor from the
   plane it inferred.
5. Move to the angle and click.

## Living with them

* They can be **moved or rotated** with the ordinary tools, like anything else.
* **Hide**: select them, then `Edit > Hide`; or context-click and `Hide`.
* **Unhide**: `Edit > Unhide`, from the menu or the context menu.
* **Delete one**: select and `Edit > Delete`, or context-click and `Erase`, or
  click it with the Eraser.
* **Delete them all**: `Edit > Delete Guides`.

SketchUp warns that "keeping too many guides in your model can affect
SketchUp's performance", and suggests hiding or deleting them as you go.

The page says nothing about whether guides print, how they export, or how they
sit with tags - so neither does this note.

---

## Where we stand

*Have:* a guide entity that feeds the snap cache and prints as nothing.  The
tape leaves a **guide line parallel to an edge** when the measurement starts on
one, and a **guide point** when it does not.  `/guides` clears them all, which
is `Edit > Delete Guides`.

*Differ, on purpose or not yet decided:*

* **Ctrl is two-way here, not three.**  Ours defaults to leaving a guide and
  Ctrl suppresses it; SketchUp starts from measuring and Ctrl cycles on to
  guide line and guide point.  Ours cannot be asked for a guide point on an
  edge, or a guide line off one.
* **A guide line is drawn from the edge it copies**, so it is parallel to that
  edge.  SketchUp's is perpendicular to the direction you drag from the point
  you clicked, which is a different gesture reaching a similar place.
* **No protractor**, so no angled guides.  This is the one that matters for
  45s.
* **No hide and unhide** - only clear the lot.
* **A guide cannot be selected or moved** once laid.  The eraser does not take
  one either.

*Not planned:* tags, and the context menu they hang off.
