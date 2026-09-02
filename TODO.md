# Heckers Sketch - what's next

Started 1 September 2026 at the end of the session that built PRO mode, and
rewritten the same night after the inference, axis and push/pull work.

Ordered roughly by "how much does this unlock for the money". The point of
the thing has not changed: rough two items out at a real scale and get an
honest measurement between them. It is aimed at quick duct transitions and
pipe layouts - the mockup you would otherwise open SketchUp to do - and the
plan is to give it away.

---

## 1. ~~A rectangle tool~~  — done 2 September 2026

Click a corner, click the opposite one, or type `12'x8'`. `R`, or `/rect`.
Makes its face by construction rather than waiting for four separate lines
to happen to meet, so push/pull always has something to grab. The size and
area read out while you drag it.

Still to do here: no rotated rectangles, and it only lies in the working
plane (`K` cycles XY / XZ / YZ) - see #7.

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

## 4. Planar region finding  — working for what it is asked to do

**Working, 2 September 2026:** a closed shape drawn on top of another gives
you something you can push on its own, because it makes its own face and the
hit test takes the most recent one first. A circle on a box pulls up into a
pipe; a rectangle inside a rectangle pulls up on its own. Circles make faces
now - they used to draw a curve and nothing else, which is why pulling one
into a pipe did nothing at all.

**Also working, 2 September 2026:** a line drawn *across* a face cuts it in
two. Draw a rectangle, split it down the middle, split a half again, and
push one of the three - each region is its own face. `TWorkDoc.SplitFace`
flattens the face into its own plane, intersects the cut with each edge, and
walks the boundary both ways from one crossing to the other.

**What it will not do**, because a clean pair of halves is the only case it
takes: a cut that stops inside the face, one that only clips a corner, one
that runs along an edge, or one that crosses a boundary more than twice. Any
of those leaves the face alone rather than half-cutting it. The general
answer is still the graph walk below, which would also handle a cut made of
several lines drawn separately, and arcs as boundaries.

One known rough edge in what does work: the outer face is not cut, so the
pipe's bottom cap and the box top sit in the same plane. It draws correctly
from outside, but the outer face should really carry a hole. Nothing depends
on it while the inner face is the one hit testing picks, but a hole is what
would make the outer face's area read correctly.

A face is only created when a run of lines closes on *itself*. Draw a line
across an existing rectangle and you have visually made two smaller rooms,
but the program still sees one big face and two loose lines - so there is
nothing to push/pull in the smaller squares.

This is exactly the duct transition case: rectangle, subdivide it, pull one
region.

The standard planar-graph walk, still to do:

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

## 7. Drawing in an arbitrary orbit  — mostly done

The working plane follows the face under the cursor, so a square drawn on
the top of a box lands on the top of it. Alt cycles the three flat planes
and latches for drawing in mid air; the arrows still set one directly; Esc
hands it back to the face.

What is left is planes that are not axis aligned. A face is matched to
whichever of XY, XZ and YZ it is squarest to, so drawing on a sloped face
still lands on the nearest flat plane rather than on the face itself.

### the old note

The orbit itself is done, the coloured axes say which way is which, and
there is an ORBIT tool (`O`, or the button) so a laptop with no middle
button can still spin the view - drag to orbit, Shift-drag to pan.

Where a new point lands is now chosen rather than inferred: with nothing
under way, the arrow keys set the working plane - up or down for upright,
left or right for the side, Page Up or Down back to flat - and the plane is
shown in the status bar. Once a line has started the arrows go back to
locking its direction.

SketchUp infers the plane from the face you started on. That inference is
still the real answer and would beat choosing by hand, but choosing by hand
beats always landing flat, which is what happened before.

The orbit itself is done, and the coloured axes now say which way is which.
What is missing is a good answer to *where does a new point land* when the
camera is at some odd angle. Today the working plane is picked by hand (`K`
cycles XY / XZ / YZ). SketchUp infers it from whatever face you started on.
That inference is the actual work, and it is what makes orbiting genuinely
useful rather than just pretty.

## 8. Push/pull that removes material  — a solid resizes now

Pushing a face that belongs to a solid slides it and drags everything joined
to it, so a box gets shorter or shallower instead of growing a second box
inside itself. That was the case that mattered.

What is left is cutting: pushing a face *into* a different solid so the two
meet and the material between them goes. That still needs regions, and the
note below is the original one.

### the original note

Push a face *into* a solid to cut it away, not just pull it out. Needs
regions (#4) first, because "which face am I cutting into" only means
something once faces are properly bounded. Probably: push inward, and where
the moved face lands flush with another one, drop both and stitch the walls.

## 9. Update from inside the program

Check a version, say "update available", download, swap the binary, restart.
Windows cannot overwrite a running exe, but rename-self, drop the new one in,
relaunch and exit is the standard way round it.

The blocker is not the mechanism, it is **where it checks**. Catbox gives
every upload a random URL, so nothing there can mean "latest". It needs one
stable address that always describes the current build.

**Decided: GitHub Releases, but not yet.** The repository has to go up first,
which is wanted anyway to give the thing away. Until then builds are hand
carried.

One detail worth settling before writing it: HTTPS from Free Pascal normally
wants OpenSSL DLLs on Windows, which would end the single-file property. Use
WinINet on Windows - a system DLL, nothing to ship - and shell out to curl on
Linux.

## 10. Export DXF

`.skp` is a closed binary format with a C++ SDK and no Pascal binding, so
exporting to SketchUp directly is not realistic - and DXF is the better
target anyway. Plain text, perhaps 150 lines to emit `LINE`, `CIRCLE` and
`ARC` in the R12 flavour. SketchUp Pro reads it, and so do AutoCAD,
LibreCAD, QCAD, Fusion and essentially every fabrication and CNC shop.

`DoExport` in `uMain.pas` already does PNG and SVG through a file dialog, so
this is a third branch in an existing function rather than new plumbing.

One catch worth knowing before promising anything: **SketchUp Free (the web
one) does not import DXF - that is a Pro feature.** The free path is STL,
which is easy to write but is triangles only, so it would carry the pulled
solids and lose the linework. Covering both means DXF for the drawing and
STL or OBJ for the solids.

## 11. Tracing an imported PDF or SVG

Bring in a drawing as a background image, scale it against a known dimension,
then trace over it with snapping. Would make the program immediately useful
on work that already exists. Deliberately parked - it is its own project.

---

## Performance - where the walls actually are

Measured 1 September 2026 on the KasmVNC display, driving synthetic grids
where every line crosses every other one - the worst case, and nothing like
a real drawing.

**Snapping scales with crossings, not with lines.**

| lines | snap points | per mouse move |
|-------|-------------|----------------|
| 100   | 7,503       | 0.16 ms        |
| 500   | 187,503     | 3.4 ms         |
| 502   | 1,506       | 0.03 ms        |
| 2000  | 6,000       | 0.11 ms        |

The jump at 502 is `MAX_LINES = 500` in `RebuildSnapCache`: above it the
crossing loop is skipped entirely, so the program silently gets a hundred
times faster **and loses every crossing snap and every sub-midpoint**. That
is a correctness cliff wearing a performance guard's coat. It should be a
spatial grid for crossing detection - O(n log n) - with no cap at all.

Note that 2000 non-crossing lines cost nothing. Real ductwork will not get
near this.

**Orbiting is the real wall, and it arrives far earlier.**

| lines | full re-render | frames/s |
|-------|----------------|----------|
| 100   | 9.4 ms         | 26       |
| 502   | 57 ms          | 12       |
| 2000  | 112 ms         | 8        |

`RenderPro` re-rasterises the whole document every orbit frame, in software,
anti-aliased. It gets choppy somewhere around 100 to 150 lines. Hovering and
drawing never trigger it, and painting is a flat 0.4 ms however big the
drawing is.

**No GPU and no threading.** Both would paper over an algorithm choice. In
order:

1. While an orbit drag is in progress, draw plain unantialiased lines
   straight to the canvas and do the real render only when the button comes
   up. That one change probably makes 2000 lines interactive.
2. `TArtSurface.AsBitmap` reloads the entire bitmap through
   `LoadFromIntfImage` whenever the surface changes - 4.6 ms per orbit frame,
   and the same cost per frame in TOY while drawing. Only the dirty region
   needs to move.
3. Cull geometry that projects entirely off the surface before rasterising
   it. The bounds are clamped safely now, but the lines are still walked.

---

## Smaller things, roughly in order

* ~~**Hover feedback** for push/pull~~ — done 2 September 2026. The face
  under the cursor is stippled and outlined before you click, its area shown
  in the status bar, and the face picked is the one you can see rather than
  the one drawn last. Still to do: a line's length in a tooltip when you
  hover it.
* ~~**Push/pull in plan**~~ — done. Choosing it in plan now goes and gets the
  corner view rather than leaving a tool that appears to do nothing.
* **An angle on the tape measure.** It reads distance and dX/dY/dZ already.
  The angle from the last segment, and from horizontal, costs almost nothing
  and 45s and 22.5s are what pipe work is actually measured in.
* **Edges that lie on each other.** An edge landing exactly on one already
  there is now skipped rather than added twice, which was leaving two lines
  and two dimension labels in the same place. SketchUp goes further and
  splits both where they *partly* overlap, so a new line borrows the part of
  an existing edge it shares. Worth doing eventually; exact duplicates were
  the case that actually showed.
* **Tape measure guides.** SketchUp's tape drops construction lines you can
  snap to and then wipe in one go. Wants a `ekGuide` entity that feeds the
  snap cache, prints as nothing, and clears with one command.
* **More settings in the lists.** Scale, snap and the pen open a list now
  rather than filling a row, so a list can hold more than a row ever could -
  more scales, finer snaps. Nothing has been added to them yet.
* **A dimension tool separate from the tape measure.** SketchUp has both:
  the tape measures and leaves guides, the dimension tool puts a permanent
  labelled dimension on the drawing. Ours has one tool doing the measuring,
  and dimensions arrive automatically with every line - toggled by the button
  on the deck, `D`, or `/dim`. Two tools would be better than a toggle.
* **A move tool.** Wanted next. `MoveFaceWith` in uWork already slides a face
  and drags what is attached to it, which is most of the primitive a move
  tool needs.
* **Custom mouse cursors.** The tool's glyph rides beside the crosshair,
  which says which tool is in hand without the platform-specific business of
  building cursor images. A real cursor per tool would be nicer still.
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
  once per tick - so the pointer tracks properly over VNC. What is left is
  the whole-bitmap reload above. PRO is mostly static and travels fine.
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
