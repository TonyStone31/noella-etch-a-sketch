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

## 2. ~~Selection and move~~  — done 2 September 2026

Both tools are in, built against our notes in `docs/sketchup/`.

**Select** (`Space` or `Q`): click picks; **Ctrl** adds, **Shift** toggles,
**Ctrl+Shift** takes away, clicking nothing clears. Drag a box — **right to
left** takes anything it touches, **left to right** only what fits wholly
inside, which is SketchUp's rule and the dashed/solid box says which is in
force. **Double-click** a face takes its bounding edges too; an edge takes the
faces it bounds; **triple-click** takes everything joined on. **Delete** removes
the selection, **Esc** clears it.

**Move** (`M`): pick a reference point on the selection, then click where it
goes. With nothing selected it picks up whatever is under the cursor, and
resting on a bare corner grabs that corner alone — which is how you pull a box
out of square. Arrows lock an axis, **Shift** keeps whichever axis the move has
drifted onto, **Ctrl** leaves a copy behind (the ghost turns green to say so).
The command bar takes a plain length, `[x,y,z]` for a point in the drawing, or
`<x,y,z>` for an offset from where you grabbed.

Geometry joined to what moves comes with it, so grabbing one edge of a shape
stretches the rest — SketchUp calls that stretching and documents exactly the
three cases we implement (see `docs/sketchup/02-stretching-geometry.md`).

Not done: no rigid-move mode for a whole solid that happens to touch something
else, no corner inference grips (they are a group/component feature and we have
no groups), and no Autofold.

## 3. Copy and linear array

**Copy is done** — Move with Ctrl held. The copy gets its own solid identity, so
push/pull on one no longer deforms the other.

The array part is not: type `*6` to repeat the step six times, or `/3` to divide
it. Note that SketchUp's own arrays page does **not** document this syntax
(see `docs/sketchup/09-flip-rotate-arrays.md`) — we would be working from the
app's behaviour, not from a spec.

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
* ~~**A dimension tool separate from the tape measure**~~ — done 2 September
  2026. DIM places one: click both ends, drag away to choose the offset,
  click to set it, the same three steps SketchUp uses. A dimension is an
  entity like any other, so the eraser takes it. The tape measure still just
  measures. Automatic dimensions on every line remain a toggle on the deck.
  Still to do: dimension an existing edge by clicking the edge itself rather
  than its two ends.
* **A move tool.** Wanted next. `MoveFaceWith` in uWork already slides a face
  and drags what is attached to it, which is most of the primitive a move
  tool needs.
* **Custom mouse cursors.** The tool's glyph rides beside the crosshair,
  which says which tool is in hand without the platform-specific business of
  building cursor images. A real cursor per tool would be nicer still.
* **Light mode is harder to read than dark.** Reported after a session in
  the dark themes. Worth one deliberate pass over the light palettes rather
  than nudging single colours.
* **Arcs on a solid's face.** An arc whose chord is an existing edge closes
  a region of its own, and rubbing that edge out joins the two. A face
  belonging to a solid is left alone either way, so an arc cannot round off
  the end of a box that has already been pulled up - draw the curve first,
  then pull.
* **Erasing a face** only works near one of its edges. `TWorkDoc.HitTest`
  falls through to the A..B segment test for `ekFace`, so the interior of a
  face is not clickable. Should use the same point-in-polygon test as
  `HitFace`.
* ~~**Dragging the eraser**~~ — done. Hold and sweep; everything the cursor
  crosses turns red, and letting go deletes the lot. Deleting an edge takes
  the faces it bounded, which is SketchUp's behaviour; clicking clear of any
  edge takes the face itself, which is not, but is how you hollow a box out.
* **The eraser's modifier keys.** SketchUp softens and smooths an edge with
  Ctrl held, and hides rather than erases with Shift. We have neither, and
  no notion of a soft edge to hang them on.
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


---

## Fixed 2 September 2026, found while testing Move

**Picking had a 9x tolerance bug.** `TWorkDoc.HitEdge` took `Sqrt` of
`DistToSeg2`, which despite its name already returned a plain distance. A 9
pixel pick radius was really 81, so an edge nowhere near the cursor beat the
face you were clicking the middle of. Renamed to `DistToSeg` so nobody squares
it again. This is why the eraser felt grabby and why a face was hard to select.

**Every face was lost on save and reload.** The `LINE` branch of
`TWorkDoc.LoadFrom` had no `begin`/`end`, so the group-id line ran as a
statement of its own and took the whole `else if` chain with it. Any record
with eleven or more tokens — which is every `FACE` — never reached its branch,
and the first one written wrote to `FEnts[-1]`. Caught by the new headless test:
before the fix it reported `faces survive = 0, wanted 6`. Reported by Codex in
`SUGGESTIONS_TO_CLAUDE.md`.

**A copied solid shared the original's group id**, so push/pull on the copy
deformed the original. `Duplicate` now remaps each source group to a fresh one.
Also from Codex's review.

**Arc hit testing treated a projected arc as a screen circle**, which is only
true when the arc's plane faces the camera square on. Both `HitEdge` and
`HitTest` now walk the drawn segments over the real sweep, through one shared
`ArcScreenDist`. Also from Codex's review.

## Headless tests — new, `tests/run.sh`

44 checks over parsing, save/reload, copying, moving and splitting, with no
window involved. Codex was right that screenshots will not catch this class of
bug: two of the four fixes above are things you would only notice days later.

Still to add, from Codex's list: metric parsing, undo/redo round trips,
hit-testing arcs in oblique views, and counts after every operation rather than
after some of them.

## Still outstanding from Codex's review

* **Planar region finding proper** — the half-edge rebuild in #4. Codex puts it
  ahead of offset and rotate, and that is the right call.
* **`HitTest`'s `ekFace` fallback** treats a face as the segment `A`..`B`.
  `PickAt` tries `HitFace` before falling back, so selection is fine, but the
  fallback itself should use the polygon interior.
* **Move connectivity rules** need writing down and testing: two solids touching
  at one corner currently drag each other.

---

## Second alignment pass, 2 September 2026

Everything here came straight out of `docs/sketchup/` — reading the pages
properly turned up a dozen things we had guessed at.

**Arrow keys now mean what SketchUp's mean.** → red X, ← green Y, ↑ blue Z, in
every view; ↓ lets go. They used to be screen-relative, which was our own
invention. A lock is on the axis, not on a direction along it, so a locked line
can be drawn backwards — it used to clamp at zero. The same three keys pick the
working plane for the shape tools, naming it by the axis it is normal to.

**The Line tool takes coordinates.** `[x,y,z]` for a point in the drawing,
`<x,y,z>` for an offset from the start. It was on Move only; the docs give the
same box to Line.

**The command bar hands a measurement to the tool.** Anything starting with a
digit, sign, bracket, comma or `x` goes to whatever tool is mid-shape rather
than being read as a command. `6',` used to come back "I do not know 6'x".

**Rectangle takes one side on its own** — `6',` sets the width and leaves the
height under the cursor, `,6'` the other way about — and a negative value runs
that side the opposite way whatever the cursor is doing.

**Push/pull works on a preselected face**, which the docs recommend for a face
too small or crowded to click, and **double-clicking another face repeats the
last pull**. Not done: Ctrl+double-click to stack.

**One click on an edge dimensions the whole edge** — "To take a dimension of a
single line, simply click the line and move the cursor."

**Double-clicking a face with the Text tool drops its area in as a note.**
Straight out of the docs, and it is half of why you draw a panel.

**The deck grew a row.** Twelve tools across one row was clipping the longer
names. They are in three groups of four now — pick and change, draw, measure and
look — two rows deep, with a rule down each gap. Row height went 20 to 24.

### Still not aligned
* No Square or Golden Section inference on the rectangle.
* No parallel inference on push/pull, no "offset is limited" message.
* No arc radius (`24r`), segment (`20s`) or circle-basis (`20c`) entry, and only
  the 2-point arc of SketchUp's four.
* Our eraser sweep highlights red; SketchUp's is blue. Blue is our selection
  colour and the two would read the same, so this stays deliberate.
* No Alt cycling of linear inferencing on the Line tool — our Alt holds the
  working plane instead.

## On Edge, and the cursor — 2 September 2026

Tony showed a screenshot: running the Line tool along the front edge of a slab,
the point would not stay on the edge.  The axis guide from a distant corner won
and dragged it off into open space.

**Cause:** we had no On Edge inference at all.  The snap cache holds only
discrete points — endpoints, crossings, centres, midpoints, sub-midpoints —
so hovering an edge offered nothing to hold on to and the guide took over.
SketchUp lists On Edge and On Face among its point inferences; we had neither.

**Fixed:** `TWorkDoc.EdgeSnap` projects each line and arc, finds the nearest
point along it on screen, and reads the same fraction back off the model
segment — the projection is affine, so the two fractions are the same number.
It sits above the axis guides in `ResolveSnapAt`, because a real piece of
geometry under the pointer is a more definite answer than an alignment to
something far away.  7 pixels.

**Not done:** SketchUp's compound inference, where an axis guide crossing an
edge snaps to the intersection of the two.  On Face while a shape is under way
is also still missing — we only infer a face at stage 0, to pick the plane.

## The cursor

The fat ring is gone.  Two things were wrong with it: it was nine pixels of
solid line sitting on top of the very corner you were aiming at, and — worse —
the cursor overlay copies a square of artwork and blits it back over the
canvas, so **every marker painted before it was being wiped out**.  All those
endpoint squares and midpoint triangles had never once been visible in PRO.
That is why the ring was the only thing anyone ever saw.

Now: a fine four-arm target with a gap in the middle and a single dot, and the
inference mark painted *after* the blit as one small solid diamond, coloured
the way SketchUp colours it.  Which is what SketchUp itself draws — Tony's own
window, open beside this, shows a blue diamond and an "On Face" label and
nothing else.

TOY mode keeps its ring; it is a pen, not a pointer.

## Solid faces, a white sheet, two themes — 2 September 2026

**Faces are opaque now, everywhere.** Three things had been making a box look
like glass:

* In plan the fill was a 16 percent tint, on the grounds that there was
  nothing to hide.  There was: a face laid over another one, and every line
  underneath.  It is a full fill in every view now.
* The face colour was the pen colour lightened 62 percent, so a cyan pen gave
  a pale cyan wash that read as translucent.  Faces are a material now, not
  ink: they start from SketchUp's near-white default and take only 8 percent
  of the pen colour, so a red-inked part still reads as red without the
  drawing turning into a paint chart.  Shading comes from how the face is
  turned against a fixed lamp, which is what makes a box look like a box.
* **Dimensions and notes were drawn last, on purpose, "so solids never hide a
  label".**  That was the worst of it — every base dimension floated over the
  top of the box it belonged under.  They are drawn before the faces now and
  a solid in front covers them, which is what SketchUp does.  Anything lying
  in the plane of a face that is still facing us gets put back afterwards.

**PRO is a white sheet.**  Two looks, Light and Dark, and they differ only in
the chrome — the paper stays white in both, because that is what a drawing is
and what prints.  The four playful themes stay for TOY, where the screen
colour is half the point; each mode remembers its own and gets it back on the
way in.  `H` cycles it now (`T` is the tape measure).

**On Edge reaches further** — 7 pixels to 11, and it follows `FUIScale` now,
which it did not before.  On a high-DPI screen the old 7 was 7 device pixels
however big everything else was drawn, which is most of why it felt like
nothing.

**The push/pull face hint** was a dense stipple in the theme accent.  On white
paper that read as though the face had been painted rather than pointed at.
Sparser, and a fixed soft blue.

### Still to do here
* Back faces have no separate colour.  SketchUp shows them pale blue, which is
  how you spot a solid built inside out.
* No materials, no styles, no sky or ground.
* Hidden-line removal is still painter's algorithm on whole faces, so two
  solids that interpenetrate will sort wrongly.

## From Point, and midpoints again — 2 September 2026

Tony, drawing a rectangle out of four lines: bottom, right side, then across
the top going left, wanting the last corner square with the first.  Resting on
the bottom-left corner gave the dashed guide, but the moment the line snapped
onto the red axis from the top-right corner the guide was thrown away — which
is exactly when it is needed.

SketchUp calls it **From Point**, and the point of it is that it *combines*
with whatever else is in force: the axis pins two coordinates, the held point
pins the third, and the answer is where the two guides cross.

`ResolveSnapAt` used to `Exit` the instant an axis relationship was found.  It
now calls `AlignFree`, which takes the one coordinate the axis left free and
looks for a point we are level with.  A point rested on wins outright and holds
from **18 pixels**; one the engine merely noticed holds from 7.  Verified: the
cursor 16 px off still lands exactly on the intersection, with both guides
drawn.

**And a regression of my own.**  On Edge was sitting above every named point,
so outside the four and a half pixels where a midpoint is taken outright, "a
point somewhere along this line" won.  Midpoints on an outer line became almost
impossible to hit, which read as the cursor snapping to the dimension line
running alongside.  A named point within reach now beats On Edge, which is
SketchUp's own order.  Verified: MIDPOINT from 9 px with the dimension line
right beside it.

**The auto-dimension switch is a labelled button now**, on the right of the SET
row, saying AUTO DIM ON or OFF.  It was only ever an unlabelled icon, and the
hint claimed `D` toggled it — `D` has been the dimension *tool* since that tool
arrived.  `Shift+D` is the switch.

## T-junctions, a firmer pull, and dimensions off by default — 2 Sep 2026

**Dividing a shape gave nothing new to snap to.**  Draw a rectangle, run lines
from the middle of one side to the middle of the other to make a tic-tac-toe
board, and the pieces of the outer edges had no midpoints.

`SegCross` turns down a meeting at an endpoint - rightly, because that point is
already an endpoint snap.  But it was the *only* thing feeding the cut list, so
a line drawn **from** the middle of another one made a T that never cut the
line it met.  Every interior line got its pieces; the outer edges never did,
which is precisely the case you hit first.  `PointOnSeg` now records those
T-junctions as cuts.  Caught and confirmed by a headless test that asked for
the middle of the bottom edge's left piece and did not get it.

**A firmer pull.**  A definite point takes the cursor from 7.5 pixels rather
than 4.5, and the general reach went from 12 to 16.  The middle of a *piece* of
a line gets 5 pixels of its own - they turn up at every quarter point of a
divided shape so they should not grab from as far as a corner, but before this
they could only be had by beating the axis guides, which is why they felt like
they were not there.

**Auto dimensions are off by default now.**  A dimension on every line is a lot
of ink for something you want on the few measurements you care about, and the
Dim tool puts those on afterwards.  A saved preference still wins, so anyone
who had them on keeps them until they press the switch.

## The dimension tool needs another look

Tony: "not behaving like sketchup at all... i mean its close... but".  Deferred
until he can say what specifically.  Things `docs/sketchup/11-text-and-dimensions.md`
lists that we do not do:

* radius and diameter dimensions, and the right-click Type > Radius / Diameter
* endpoint styles - slash is SketchUp's default, then dot, closed arrow, open
  arrow, none
* text placed centred, outside the start, or outside the end
* aligning the text to the screen rather than to the dimension
* typing over a dimension's text, which in SketchUp breaks its link to the
  geometry and stops it updating

## The grid test, and what it found — 2 September 2026

Tony's scenario, now written down in `tests/README.md`: a square, filled in at
the midpoints to a 6 x 6 grid, into 3D, push a couple of cells up, then circles
in the cells pushed as well.  It has found more than anything else.

**Solids were transparent because the lines were painted back on top of them.**
The renderer draws edges, then faces over them, then puts back "lines that live
on a visible face" - and that last pass put the *whole* line back.  So every
grid line on the base plane was redrawn over the towers standing in front of
it.  A line lying on a face is now chopped into 32 pieces and only the stretches
that nothing nearer covers are drawn.

**Auto dimensions are gone.**  Not a switch - removed.  "Stop making dimension
lines... i think that is my job."  The Dim tool is untouched; dimensions you
place are ordinary entities you can select and erase.  Files written before
this still load; the DIMS line in them is read and ignored.

**A circle drawn on a slab could not be pushed.**  This was a good one.  Both
faces are coplanar, so `FaceUnder` should have broken the tie by area and
preferred the smaller.  It could not: the cursor's depth on each face comes
from a 2x2 solve against that face's own first edge, and a 24-sided circle of
radius 5 has sides about 1.3 feet long against the slab's 20.8, so the circle's
answer was less accurate by 5.6e-6 - about two thousand times the 1e-8 nudge
meant to prefer it.  The slab won every time and pulling "the circle" raised
the whole slab as a box.

Fixed twice over: the basis is normalised before the solve, and the comparison
is now tolerance-based - within 1e-4 relative, the smaller face wins.  The
renderer's sort got the same rule, or the circle would draw underneath.  Both
are covered by a test using the app's real numbers.

### Still to do here
* **Soften the edges of a curved surface.**  A pushed circle shows every one of
  its 24 facet edges.  SketchUp hides them, which is what makes a cylinder look
  round rather than faceted - their docs call the result a "surface entity".
  Needs a soft flag on an edge and a renderer that skips it.
* Two solids that interpenetrate still sort wrongly; the painter's algorithm
  works on whole faces.
