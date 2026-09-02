# Heckers Sketch - what's next

Written 1 September 2026, at the end of the session that built PRO mode.
Ordered roughly by "how much does this unlock for the money".

---

## 1. Planar region finding  ← the next one

**The problem.** A face is only created when a run of lines closes on
*itself*. Draw a line across an existing rectangle and you have visually made
two smaller rooms, but the program still sees one big face and two loose
lines — so there is nothing to push/pull in the smaller squares.

**What it takes.** The standard planar-graph walk:

1. Split every line at its crossings. *The crossing points and the split
   parameters are already computed* — `TWorkDoc.RebuildSnapCache` in
   `uWork.pas` does exactly this for snapping, so the input is in hand.
2. Merge coincident endpoints into vertices (within a tolerance).
3. Build a half-edge graph of the sub-segments, grouped by plane.
4. Walk minimal cycles, always taking the most-clockwise next edge. Discard
   the outer boundary cycle.
5. Rebuild faces from the cycles whenever the geometry changes, instead of
   the current "chain closed → make a face" rule.

Perhaps 200 lines. It is the last structural piece; almost everything below
gets easier once regions exist.

## 2. Push/pull that removes material

SketchUp lets you push a face *into* a solid to cut it away, not just pull it
out. Needs regions (#1) first, because "which face am I cutting into" only
means something once faces are properly bounded. Probably: push inward, and
where the moved face lands flush with another one, drop both and stitch the
walls.

## 3. A move tool

Drag a point, a line, or a whole selection. Wants a real selection model
first (click to select, shift-click to add, box select), which the POINT tool
is already a placeholder for.

## 4. Drawing in an arbitrary orbit

The orbit itself is done — the 3D view spins with a middle-drag. What is
missing is a good answer to *where does a new point land* when the camera is
at some odd angle. Today the working plane is picked by hand (`K` cycles
XY / XZ / YZ). SketchUp infers it from whatever face you started on. That
inference is the actual work, and it is what makes orbiting genuinely useful
rather than just pretty. Agreed this is a bigger job than it looks.

## 5. Tracing an imported PDF or SVG

Bring in a drawing as a background image, scale it against a known dimension,
then trace over it with snapping. Would make the program immediately useful
on work that already exists. Deliberately parked - it is its own project.

---

## Smaller things, roughly in order

* **Erasing a face** only works near one of its edges. `TWorkDoc.HitTest`
  falls through to the A..B segment test for `ekFace`, so the interior of a
  face is not clickable. Should use the same point-in-polygon test as
  `HitFace`.
* **Dimension labels** can land inside a closed shape. They should be pushed
  to the outside of the run they belong to.
* **Neon on a light screen** is muted. It went alpha-based so that a drawing
  survives a theme change; the trade was a softer glow on pale paper.
* **A grid in the 3D view.** Plan gets a measured grid and ISO gets the 30°
  lattice; the orbit view gets nothing, because a fixed lattice looks wrong
  from an arbitrary angle. A ground plane that follows the camera would fix
  it.
* **Print more than one sheet** at a time.
* **Remote-display performance.** Motion no longer paints - it is serviced
  once per tick - so the pointer tracks properly over VNC. TOY mode still
  reloads the whole art bitmap per frame while drawing; only the dirty
  region needs to move. PRO is mostly static and travels fine.
* **Undo memory.** TOY keeps 16 full-screen bitmaps. PRO keeps whole document
  copies, which is cheap. TOY could be smarter.

---

## Where the line is

No booleans, no curved surfaces, no components or groups, no textures, no
materials. Those are where this stops being a quick tool and starts being a
worse copy of SketchUp. The point of the thing is: rough two items out at a
real scale and get an honest measurement between them.
