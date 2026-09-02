# Heckers Sketch - what's next

Started 1 September 2026 at the end of the session that built PRO mode, and
rewritten the same night after the inference, axis and push/pull work.

Ordered roughly by "how much does this unlock for the money". The point of
the thing has not changed: rough two items out at a real scale and get an
honest measurement between them. It is aimed at quick duct transitions and
pipe layouts - the mockup you would otherwise open SketchUp to do - and the
plan is to give it away.

---

## 1. A rectangle tool  ← smallest thing, biggest payoff

Click a corner, click the opposite one, or type `12'x8'`. An hour of work.

It matters more than convenience: it makes a **face** reliably. Today a face
only appears when four separate lines happen to close on each other, which
is also why push/pull sometimes has nothing to grab. Almost everything below
is easier to test once a face is one click away.

## 2. Selection and move

The biggest hole in the program. There is no way to adjust anything - erase
and redraw is the only edit. `ptSelect` is a stub that reads out coordinates
and draws nothing.

Wants a real selection model first: click to select, shift-click to add, drag
a box. Then move: grab a point, a line, or a selection, with the same
snapping and axis locks the line tool already has.

In SketchUp this is the second most used tool after the line. Worth learning
even if you have got by without it - most of what follows depends on it.

## 3. Copy and linear array

Move with Ctrl held leaves the original behind; then type `*6` to repeat the
step six times, or `/3` to divide it. Cheap once move exists, and it is the
thing that makes a layout tool fast - hangers, repeated fittings, joist
spacing.

## 4. Planar region finding

A face is only created when a run of lines closes on *itself*. Draw a line
across an existing rectangle and you have visually made two smaller rooms,
but the program still sees one big face and two loose lines - so there is
nothing to push/pull in the smaller squares.

This is exactly the duct transition case: rectangle, subdivide it, pull one
region.

The standard planar-graph walk:

1. Split every line at its crossings. *The crossing points and the split
   parameters are already computed* - `TWorkDoc.RebuildSnapCache` in
   `uWork.pas` does exactly this for snapping, so the input is in hand.
2. Merge coincident endpoints into vertices (within a tolerance).
3. Build a half-edge graph of the sub-segments, grouped by plane.
4. Walk minimal cycles, always taking the most-clockwise next edge. Discard
   the outer boundary cycle.
5. Rebuild faces from the cycles whenever the geometry changes, instead of
   the current "chain closed → make a face" rule.

Perhaps 200 lines. It is the last structural piece.

## 5. Offset, then rotate

**Offset** pushes a closed loop in or out by a distance - duct wall
thickness, a flange, a second run parallel to the first. One of SketchUp's
core six tools.

**Rotate** swings a selection about a point and an axis. For a pipefitter
this is not optional; 45s are the job.

Both are much cheaper once #2 exists, which is why they sit here.

## 6. Dimensions you place, not dimensions that appear

Today `uMain.pas` calls `AddLine(FP1, T, FInkColor, FPenSize, FD.ShowDims)`,
so every line is stamped with a `Dim` flag *when it is drawn*, and then
`uWork.pas` gates drawing on a **global** `ShowDims`. The per-line flag
exists but the global switch overrides it, so you cannot dimension one line
and leave another plain.

SketchUp's model is better and is mostly deletion: hovering a line tells you
its length in the status bar, and a dimension is a separate thing you place
with a tool when you want it on the drawing. Nothing is dimensioned by
default.

## 7. Drawing in an arbitrary orbit

The orbit itself is done, and the coloured axes now say which way is which.
What is missing is a good answer to *where does a new point land* when the
camera is at some odd angle. Today the working plane is picked by hand (`K`
cycles XY / XZ / YZ). SketchUp infers it from whatever face you started on.
That inference is the actual work, and it is what makes orbiting genuinely
useful rather than just pretty.

## 8. Push/pull that removes material

Push a face *into* a solid to cut it away, not just pull it out. Needs
regions (#4) first, because "which face am I cutting into" only means
something once faces are properly bounded. Probably: push inward, and where
the moved face lands flush with another one, drop both and stitch the walls.

## 9. Tracing an imported PDF or SVG

Bring in a drawing as a background image, scale it against a known dimension,
then trace over it with snapping. Would make the program immediately useful
on work that already exists. Deliberately parked - it is its own project.

---

## Smaller things, roughly in order

* **Hover feedback.** Light up the face under the cursor when push/pull can
  act on it, the way SketchUp stipples a pullable face, and show a line's
  length when you hover it. `FHoverEnt` already exists but is only computed
  for the eraser.
* **Push/pull should not be offered in plan.** The face normal points at the
  camera there, so it can only work by typing and the preview can show
  nothing moving. It currently prints a "press V for a 3D view" nudge, which
  is a sign the tool should not be live in that view at all.
* **An angle on the tape measure.** It reads distance and dX/dY/dZ already.
  The angle from the last segment, and from horizontal, costs almost nothing
  and 45s and 22.5s are what pipe work is actually measured in.
* **Tape measure guides.** SketchUp's tape drops construction lines you can
  snap to and then wipe in one go. Wants a `ekGuide` entity that feeds the
  snap cache, prints as nothing, and clears with one command.
* **Light mode is harder to read than dark.** Reported after a session in
  the dark themes. Worth one deliberate pass over the light palettes rather
  than nudging single colours.
* **Erasing a face** only works near one of its edges. `TWorkDoc.HitTest`
  falls through to the A..B segment test for `ekFace`, so the interior of a
  face is not clickable. Should use the same point-in-polygon test as
  `HitFace`.
* **Dragging the eraser** over several edges, instead of one click each.
* **Dimension labels** can land inside a closed shape. They should be pushed
  to the outside of the run they belong to.
* **Neon on a light screen** is muted. It went alpha-based so that a drawing
  survives a theme change; the trade was a softer glow on pale paper.
* **A ground plane in the orbit view.** The three coloured axes are drawn
  from the origin now, which is enough to know which way is up, but a ground
  plane that follows the camera would read better than nothing.
* **Print more than one sheet** at a time.
* **Remote-display performance.** Motion no longer paints - it is serviced
  once per tick - so the pointer tracks properly over VNC. TOY mode still
  reloads the whole art bitmap per frame while drawing; only the dirty
  region needs to move. PRO is mostly static and travels fine.
* **Undo memory.** TOY keeps 16 full-screen bitmaps. PRO keeps whole document
  copies, which is cheap. TOY could be smarter.

---

## Where the line is

No objects, no groups, no components. No booleans, no curved surfaces, no
textures, no materials, no follow-me. No touch support - it is a laptop
tool, and every one of the inference cues depends on a cursor hovering
somewhere without being pressed.

Those are where this stops being a quick tool and starts being a worse copy
of SketchUp.
