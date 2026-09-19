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
   color says which.
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

*Have:* a guide entity that feeds the snap cache and prints as nothing.
**Ctrl cycles the tape through all three** - guide line, guide point, measure
only - and the prompt says which, where SketchUp puts an icon on the cursor.
A guide can be **selected and erased** individually like anything else, and
`/guides` clears them all, which is `Edit > Delete Guides`.

*Differ, on purpose or not yet decided:*

* **The tape lays both by default**, a dashed line and a point, and **Ctrl
  cycles** through both, the point alone, the line alone, and neither.  Same
  key as theirs for the same choice; ours has the both-at-once mode theirs
  does not, and that is the default because it is the one the owner wants most of
  the time.  Re-added 15 September after being taken out - the reason it was
  taken out was that choosing did not seem the useful part, and the reason it
  came back is a 1" mark in from the end of a line, which does not want a
  dashed line across the whole drawing with it.

* **Guides can be picked**, by the select tool, and erased from the right
  button or with Delete.  A guide point is asked for **before** anything else
  under the cursor, because it is nearly always sitting on the line it
  measured along and that line would otherwise win on distance from a pixel
  away.  The reach matches what is drawn, so the target is the size it looks.

  The owner checked theirs: a guide point can be selected and deleted in SketchUp
  after all - "you absolutely can't click the plus point... it turns blue and
  you can delete it with the delete key" - but "trying to click it and select
  it to delete was very difficult and it took me 20 times to get it so that
  is a SketchUp problem... Don't let it be our problem."  Hence asking for it
  first rather than merely widening a tolerance.

* **A guide that has been put away cannot be picked or erased.**  It is not on
  the screen, so it is not under the cursor - the same rule the snapping
  already followed, and one the pickers did not.

* ~~**The tape lays both, every time**~~ - a dashed line and a point.  SketchUp
  lays one or the other from a mode that **Ctrl** toggles, and the cursor icon
  says which; there is no inference in it.  **Checked against the live page
  15 September 2026**, because it came up: "I am not sure how and when
  sketchup decides to have their points make the long dashed lines or when it
  just drops a point."  It does not decide - the person does.  Ours had that
  Ctrl cycle once and it was taken out; worth putting back, with both as the
  default, since a 1" mark on a line does not want a dashed line running the
  width of the drawing.

* **Their eraser does delete guides**, lines and points both - "Click a guide
  line with the Eraser tool".  Also checked 15 September, because it came up
  the other way round.

* **A guide line is taken across the measurement** - perpendicular to the
  drag, in the working plane.  For SketchUp's own gesture, clicking an edge
  and dragging away from it, that is the same answer as their rule of
  parallel-to-the-edge, since dragging away from an edge means dragging
  across it.  It also gives a sensible answer from a corner, where there is
  no single edge to be parallel to.
* **A guide point is drawn to be found** - amber, filled, and on top of the
  geometry rather than under it.  SketchUp's are nearly invisible, which is
  not a thing to copy.
* **Hide and clear are on the right button**, with the count on the hide row,
  grayed when there are no guides rather than missing - a menu whose shape
  changes puts a destructive row under a hand aiming at a harmless one.  They
  were two more buttons along the bottom of the window until 15 September,
  and making room for them squeezed the settings until their words ran into
  each other.  SketchUp uses Edit > Hide and Edit > Delete Guides, and a
  docked tray; the right button is nearer to hand than any of those.

* **A guide line takes the point laid with it** when it is rubbed out.  The
  two are one gesture here, so they are one thing to erase.  SketchUp has no
  equivalent because it never lays both at once.
* **The protractor** lays an angled guide: the vertex, a point to measure
  from, then swing to the angle or type it - `45`, or `8:12` for a slope.
  The arrows pick the plane; there is no Shift lock or Alt, because the
  arrows already say it outright.
* **A guide cannot be moved** once laid.  Erasing and laying another is the
  way round it.

*Not planned:* tags, and the context menu they hang off.
