# Heckers Sketch - what's next

The point has not changed: rough two items out at a real scale and get an
honest measurement between them.  Quick duct transitions and pipe layouts -
the mockup you would otherwise open SketchUp to do - given away free.

`docs/sketchup/` is the spec.  Sixteen of their help pages, read properly and
written up, with a note on each saying what we have, what we do not, and where
we differ on purpose.  When we argue about how something should behave, that is
what we argue against.

---

## Where it stands, end of 2 September 2026

Working, and tested: select and move (with stretching, Ctrl-copy and typed
coordinates), push/pull including on circles, solid opaque faces on white
paper, the snapping and inference set - endpoints, midpoints, the midpoints a
crossing or a T-junction makes, on-edge, axis locks and From Point - the
eraser, and dimensions you place yourself.

Two ways to check it: `./tests/run.sh` for 67 headless geometry checks, and the
grid scenario written up in `tests/README.md`, which has found more bugs than
anything else.

## Next up, in order

1. **Soften the edges of a curved surface.**  A pushed circle shows all 24 of
   its facet edges, so a cylinder looks faceted rather than round.  SketchUp
   hides them; their docs call the result a surface entity.  Needs a soft flag
   on an edge and a renderer that skips it.  Small, and very visible.
2. **Planar region finding proper** - #4 below.  Codex put it ahead of offset
   and rotate and that is right: every tool gets easier once a face is derived
   from its edges rather than stored and patched.
3. **Offset** - duct wall thickness and flanges.  #5 below.
4. **Rotate** - 45s are the job.  #5 below.
5. **The rest of the dimension tool**: radius and diameter, dragging an
   extension line, endpoint styles.  Tony is coming back to this.
6. **Back faces in their own color**, the way SketchUp shows them pale blue.
   It is how you spot a solid built inside out, and it would have caught the
   winding bug on sight.
7. **Copy arrays** - `*6` and `/3` after a Ctrl-move.  Note that SketchUp's own
   arrays page does not document the syntax, so we would be working from the
   app rather than a spec.

Not doing, and why: a real not-to-scale field isometric mode.  Our ISO is a
scaled 3D model seen at 30 degrees, which is a view rather than a kind of
drawing - `docs/isometric-views.md` has the reasoning.  If an iso spool sheet
is ever wanted it is an **export** off the scaled model, walking a run and
hanging callouts off it, not a mode that changes how drawing works.

Known rough edges: two solids that interpenetrate sort wrongly, because the
painter's algorithm works on whole faces.  A file saved before tonight loads
its dimensions sitting on the line they measure.

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
app's behavior, not from a spec.

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

## 5. Offset, then rotate  — still to do, and now the top of the list

**Offset** pushes a closed loop in or out by a distance - duct wall
thickness, a flange, a second run parallel to the first. One of SketchUp's
core six tools.

**Rotate** swings a selection about a point and an axis. For a pipefitter
this is not optional; 45s are the job.

Both are much cheaper once #2 exists, which is why they sit here.

## 6. ~~Dimensions you place, not dimensions that appear~~  — done 2 Sep 2026

Automatic dimensions are gone, not switched off - `ShowDims` and the per-line
`Dim` flag no longer drive anything.  A dimension is a thing you place with the
Dim tool: hover an edge and it lights up, click it to take the whole of it,
pull the line out and drop it.  It is an ordinary entity - select it, erase it -
and nothing else snaps to it.  See the second-pass notes at the end.

## 7. Drawing in an arbitrary orbit  — mostly done

The working plane follows the face under the cursor, so a square drawn on
the top of a box lands on the top of it. Alt cycles the three flat planes
and latches for drawing in mid air; the arrows still set one directly; Esc
hands it back to the face.

What is left is planes that are not axis aligned. A face is matched to
whichever of XY, XZ and YZ it is squarest to, so drawing on a sloped face
still lands on the nearest flat plane rather than on the face itself.

### the old note

The orbit itself is done, the colored axes say which way is which, and
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

The orbit itself is done, and the colored axes now say which way is which.
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
  than nudging single colors.
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
  the faces it bounded, which is SketchUp's behavior; clicking clear of any
  edge takes the face itself, which is not, but is how you hollow a box out.
* **The eraser's modifier keys.** SketchUp softens and smooths an edge with
  Ctrl held, and hides rather than erases with Shift. We have neither, and
  no notion of a soft edge to hang them on.
* **Dimension labels** can land inside a closed shape. They should be pushed
  to the outside of the run they belong to.
* **Neon on a light screen** is muted. It went alpha-based so that a drawing
  survives a theme change; the trade was a softer glow on pale paper.
* **A ground plane in the orbit view.** The three colored axes are drawn
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

---

# Session log — 2 September 2026

Everything below is history: what was found, why, and what it cost.  The
current state and the next steps are at the top of this file.

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
  color and the two would read the same, so this stays deliberate.
* No Alt cycling of linear inferencing on the Line tool — our Alt holds the
  working plane instead.

## On Edge, and the cursor — 2 September 2026

Tony showed a screenshot: running the Line tool along the front edge of a slab,
the point would not stay on the edge.  The axis guide from a distant corner won
and dragged it off into open space.

**Cause:** we had no On Edge inference at all.  The snap cache holds only
discrete points — endpoints, crossings, centers, midpoints, sub-midpoints —
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
inference mark painted *after* the blit as one small solid diamond, colored
the way SketchUp colors it.  Which is what SketchUp itself draws — Tony's own
window, open beside this, shows a blue diamond and an "On Face" label and
nothing else.

TOY mode keeps its ring; it is a pen, not a pointer.

## Solid faces, a white sheet, two themes — 2 September 2026

**Faces are opaque now, everywhere.** Three things had been making a box look
like glass:

* In plan the fill was a 16 percent tint, on the grounds that there was
  nothing to hide.  There was: a face laid over another one, and every line
  underneath.  It is a full fill in every view now.
* The face color was the pen color lightened 62 percent, so a cyan pen gave
  a pale cyan wash that read as translucent.  Faces are a material now, not
  ink: they start from SketchUp's near-white default and take only 8 percent
  of the pen color, so a red-inked part still reads as red without the
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
color is half the point; each mode remembers its own and gets it back on the
way in.  `H` cycles it now (`T` is the tape measure).

**On Edge reaches further** — 7 pixels to 11, and it follows `FUIScale` now,
which it did not before.  On a high-DPI screen the old 7 was 7 device pixels
however big everything else was drawn, which is most of why it felt like
nothing.

**The push/pull face hint** was a dense stipple in the theme accent.  On white
paper that read as though the face had been painted rather than pointed at.
Sparser, and a fixed soft blue.

### Still to do here
* Back faces have no separate color.  SketchUp shows them pale blue, which is
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
* text placed centerd, outside the start, or outside the end
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

Fixed twice over: the basis is normalized before the solve, and the comparison
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

## The dimension tool, second pass — 2 September 2026

**Hover an edge and it lights up.**  One click then takes the whole of it.  The
highlight is the half that makes the tool readable: without it there is no
telling whether a click is about to take the edge or start a point-to-point.

**The dimension is previewed as it will be.**  Witness lines, end slashes and
the reading, moving with the cursor — not a rubber band between two points.
Preview and drawing come out of one routine, `DimGeometry`, so they cannot
drift apart.

**The offset is a vector in the model now, not a signed screen distance.**  Two
things were wrong with the old one.  The sign disagreed with the one the
renderer worked out — it applied a canonical "one consistent side" flip and the
offset calculation did not — so pulling the line *down* put it *above* the edge,
inside the shape it was measuring.  And being in pixels meant zooming in walked
the dimension back towards the geometry, and orbiting swung it round.  It is
now simply the displacement from the measured edge to where the line sits, and
the dimension line is that edge shifted by it.  That is SketchUp's rule: "after
you place a dimension in a plane, you can move the dimension only within that
plane."

**The eraser can take a dimension**, and highlights the right thing.  `HitEdge`,
`HitTest` and `Outline` all used to measure a dimension against the invisible
chord between the two measured points, which is not where anyone aims — it is
the drawn line and its witness lines now.

**Nothing snaps to a dimension or a note.**  They were feeding endpoints into
the snap cache, so drawing a line near one pulled the cursor onto it.
Annotation is not geometry.

### Left for later
* Radius and diameter dimensions on arcs and circles.
* Dragging an extension line's end, which SketchUp allows once the dimension
  is placed.
* Endpoint styles - slash is the default, then dot, closed arrow, open arrow,
  none.
* Typing over the reading, which in SketchUp breaks the link to the geometry.
* A file written before the offset became a vector loads its dimensions sitting
  on the line they measure; drag them off again.

## Command line switches — 2 September 2026

For LazPort, which launches the program itself and wants the window a
particular way rather than however a person last left it.

    etchasketch [switches] [drawing.hsk]

      --maximized        open filling the screen
      --fullscreen       open with no window frame at all
      --size=1600x1000   open at a particular size, centerd
      --help             print this and leave

A switch beats the remembered size and position - that is the point of it.
`--help` is answered in the program file before any of the LCL starts, so it
prints and exits rather than printing and then opening a window; on a Windows
GUI build there is no console and it fails quietly.  Anything unrecognized is
ignored rather than fatal, and the drawing to open is looked for among all the
arguments rather than taken from the first, so a switch in front of a filename
does not hide it.

`--fullscreen` sets the bounds to the monitor explicitly instead of asking for
`wsFullScreen` and hoping: whether that lands depends on the window manager,
and a bare remote display may not have one.  Measured on a 1600x1000 nested
server: `--maximized` gives 1600x983 under openbox, `--fullscreen` 1600x1000,
`--size=1100x700` exactly that.

## The fullscreen window would not resize with the display — 3 September 2026

Found by Codex within minutes of the switches landing, from the X11 side:
Heckers Sketch's window had `WM_NORMAL_HINTS` with **minimum, maximum and base
all pinned to 1600x1000**, so when KasmVNC resized the virtual screen to follow
the browser the window could not follow it.  Reproduced exactly on a nested
server.

**Cause, and it was mine.**  `--fullscreen` set `BorderStyle := bsNone`.  A
borderless form is one the LCL marks as not resizable, and GTK says so by
pinning the size hints to whatever size the window opened at.  Nothing to do
with the transport.

**Fixed** by not touching `BorderStyle` at all.  `WindowState := wsFullScreen`
asks the window manager for a frameless full screen and leaves the window
resizable; the bounds are set explicitly as well, for a bare display with no
window manager.  Hints now read minimum 940x600 (the form's own constraint) and
**no maximum**.

**And it now follows the display.**  There is no reliable notification when a
remote display changes size, so `FollowScreenSize` watches for it on the 16 ms
tick - two integer comparisons a frame - and refits when it changes.  Measured
on a resizeable nested server, growing as well as shrinking, which is the case
that was broken:

    screen 1024x768   -> window 1024x768
    screen 1400x1050  -> window 1400x1050
    screen 1600x1200  -> window 1600x1200

`--maximized` follows too (1400x1033 and 1600x1183 under openbox, less its
panel).

## Line weight, snapping and the white sheet — 3 September 2026

**"Thick lines left behind" was per-edge line weight.**  Tony's instinct was
right, and a search settled it: SketchUp has **no per-edge thickness** - weight
is a style setting for the whole model, with Profiles thickening the
silhouette.  See `docs/sketchup/edge-weight.md`.

We stored a weight on every entity, taken from the pen size when it was drawn,
and push/pull hardcoded its new edges to 1.  So a box pulled from a rectangle
drawn with a 4 pixel pen had four heavy lines round its base and hairlines
everywhere else, which reads as something left behind.  The renderer now takes
one weight for the whole drawing and uses it for every edge and face outline;
WIDTH changes the lot at once, live, the way a style setting does.  The
per-entity weight is still written to the file so older drawings load, but
nothing renders from it.

**The grid was invisible on white paper.**  `Grid` in both PRO themes was a
shade off the paper itself.  Darkened to `$BEC6D0`.  The isometric lattice is
back, which matters - the pipefitters read iso drawings even if Tony does not.

**Fractional snaps.**  The menu went 1/16" straight to 1", which is why
everything ended up on foot increments.  Now: OFF, 1/16, 1/8, 1/4, 1/2, 1", 2",
3", 6", 1'-0".  Metric to match.

**A face has a center to snap to.**  Drawing a circle from the middle of a
square is something Tony does constantly, and getting there otherwise means
resting on two edge midpoints and crossing the guides.  One point per face.

**The face under the cursor is unmistakable now.**  The hover stipple was
sparse enough to be a hint; it is every other pixel in a light blue, which
reads as a wash.

### Checked and already right
Snapping to what push/pull leaves behind - corners, edge midpoints and upright
midpoints, on the first push and on the resize path - has a headless test now
and passes.  What Tony saw was the weight mismatch, not missing points.

### Push to zero
He asked whether push/pull should delete a face when pushed to nothing, the way
SketchUp's does.  Their docs describe cutting a *hole through*: the pushed face
must be parallel with the face on the far side and no lines may divide that far
face.  That is a boolean operation on real topology.  Our faces are stored and
patched rather than derived from their edges, so doing it honestly waits on the
planar region work - it is the same dependency as offset and rotate.

### Also noticed
Drawing on a plane the camera is looking nearly along makes `WorldAt` blow up,
so a rectangle drawn on the ground from a horizon-level 3D view comes out a
sliver.  SketchUp has the same problem; a guard that refuses a point when the
working plane is within a few degrees of edge-on would be kinder.

## The isometric paper, and American spelling — 3 September 2026

**The grid was there but invisible.**  Two things, not one.  The color was a
shade off the paper, which the last pass fixed - but the minor lines were also
drawn at a quarter strength chosen for a dark screen, where a bright grid would
shout.  On white it made them a shade off a shade.  Alpha is picked from
`DarkScreen` now: 0.5 and 0.95 on paper, the old 0.26 and 0.7 on a dark toy
screen.

**And the pitch adapts.**  It was stuck at one world unit however far you had
zoomed, so it was either a wall of lines or nothing.  It now steps through the
same round numbers the scale bar picks from - an inch, three, six, a foot, five
feet - keeping the spacing between 14 and 60 pixels.  At a working zoom that
lands on a foot, which is what isometric paper is ruled at, and it is always a
number you would snap to.  Tony asked whether it should follow the snap setting
instead: no - at a 1/8" snap that would be ninety-six lines to the foot.  A
fixed readable pitch is what paper does.

**American spelling throughout.**  `snCentre` is `snCenter`, the snap label
reads CENTER, and colour/grey/behaviour/neighbour/normalise and the rest are
gone from the code, the comments and the notes.  Second time he has had to say
it.

## Profiles, and three bugs behind them — 3 September 2026

**Profiles.**  SketchUp's one edge effect worth having: the outline of a shape
is drawn heavier than the edges inside it, and that difference is most of why
a model reads as solid rather than as a wireframe with fill.  An edge is on
the outline when only one of the faces you can *see* runs along it, so it is
view-dependent - turn the model and the silhouette moves.  A profile is one
pixel heavier than the pen, not twice it; doubling a four pixel pen gave an
eight pixel border.

**Face outlines are no longer stroked at all.**  Every boundary of a face is a
real edge and gets drawn as one, so stroking the polygon as well laid a second
line over the first.  That was most of why a solid's edges looked heavier than
the lines they were made of even after the weight became one setting.

**A face the point lies in cannot be in front of it.**  Without that the
hidden-line chopping cut every edge of a solid into a dotted line: an edge lies
in the plane of the faces either side of it, those are drawn later, and the
point-in-polygon test on their shared boundary went either way from sample to
sample.

**And the chopping itself made notches.**  A line lying on a face was drawn as
thirty-two abutting pieces, each with its own ends, which showed at a heavy
weight.  Consecutive visible pieces are one line now.

## A push carries what is drawn on it — 3 September 2026

Draw a box, pull it up, draw a line across its top to the middle of an edge,
push the side under that edge: the line stayed where it was.  `MoveFaceWith`
asked "is this point one of the face's corners", and the line's end was on the
moving face but not at a corner of it.  It now asks whether the point lies on
the face at all, edges included.  Loose geometry comes along too - the group
filter still keeps a neighbouring *solid* out of it, but a line drawn on this
one belongs to no group.

## A circle drawn on a face was hidden by it — 3 September 2026

Not "put on the back": it was on the right face all along and the box was
painting over it.  The pass that puts back the lines lying on a visible face
knew about lines, dimensions and notes but not arcs.  Arcs are walked round the
same way now.

### The gap this turned up
`SplitFace` turns down any face belonging to a solid - `if FEnts[Index].Solid
then Exit` - so **a line drawn across the top of a box does not divide it**.
You cannot cut a box's face in half and push one half, which is a core
SketchUp move.  Allowing it means both halves must stay Solid and keep the
group, and pushing half a top should extrude a new block rather than slide the
half - which is the planar-region work again.  Worth doing properly, not
patching.

### Still untested
The tape measure should leave guides the way SketchUp's does, and show the
reading at the cursor offset far enough to read.  The Move tool has had almost
no real use.  Both after the above.

## Cutting a solid, and one rule instead of a flag — 3 September 2026

You can draw a line across a box top and push one half of it up.

`SplitFace` turned down any face belonging to a solid, so a box could not be
divided at all.  It takes them now, and both halves keep what the whole was -
still solid, same group, added raw so the winding is not canonicalized and
turned inside out.

The interesting half is what push does next.  It used to ask **"does this face
belong to a solid"** and slide if so.  That was right until a solid's face
could be cut: half a box top still belongs to the solid, but sliding it shears
the box instead of lifting the half.

So it asks about the shape instead.  A face is a **patch** when another face in
the same plane runs along one of its edges - one piece of a larger flat area
rather than the whole flat side of something.  A whole side slides and resizes;
a patch has a block extruded out of it.  One question, both cases: an uncut top
has no coplanar neighbor and still resizes, each half of a cut top shares the
cut edge and lifts.

*This is the shape the rest of the geometry should take* - see the note below.

## The look: hairlines and shading — 3 September 2026

PRO shared the toy's pen size, so every edge in a drawing was four pixels -
four times SketchUp's.  PRO has its own edge weight now, default 1, under its
own settings key.  Profiles put the silhouette one pixel above that, which is
exactly SketchUp's 1 and 2.

Face shading was spread over a few percent, so the edges had to do all the work
of separating one side of a box from the next.  Top, front and side now land
near 1.0, 0.90 and 0.80 of the material.

**Soft edges.**  The creases down a pulled circle are not edges - they are how
a curved surface is stored - so they are hidden, and drawn only where the
surface turns away and the crease *is* the outline.  A pulled circle now reads
as a pipe.  Nine sides or more and an extrusion's walls are softened.  Circles
take a side every five pixels of rim, 24 to 96.

Still to do here: SketchUp's other edge effects - Depth Cue, Extension,
Endpoints, Jitter - and smooth shading across the facets of a curved surface
rather than flat-shading each one.

## Codex was right about the architecture

Faces are still stored polygons kept correct by a set of repair rules, and the
work above added another (`IsPatch`).  The difference is that `IsPatch`
*replaced* a flag test rather than adding a case beside it, and the same
question now answers push, split and profile.  That is the direction: fewer,
more general questions about the shape.

The real fix is still the planar-region rebuild in the suggestions file -
derive faces from their edges instead of storing and patching them.  Everything
outstanding leans on it:

* push to zero deleting a face, and cutting a hole through
* offset, which needs a reliable boundary
* rotate
* a cut made of several lines, or one that stops inside a face
* holes and nested loops

That is the next structural piece, and it should come before offset and rotate.

## Asked for, not done yet
* **The tape measure** should leave guides the way SketchUp's does, and show
  the reading at the cursor, offset far enough to read while dragging.
* **The Move tool** has had almost no real use and is likely to have the same
  class of bug push/pull did.

## The tape measure leaves guides — 3 September 2026

SketchUp's tape does two jobs; ours only did one.  Sources:
`https://help.sketchup.com/en/using-guides`, and the community writeups on the
Ctrl toggle.

**Guides are their own kind of thing.**  Infinite, dashed, snappable,
erasable, saved, never part of a face - their docs are blunt: *"these lines do
not interfere with regular geometry."*

**What the tape leaves depends on where it started**, which is their rule:
from an edge you get a **guide line parallel to that edge** at the distance you
pulled - a wall thickness, a row of hangers - and from anywhere else you get a
**guide point** at the far end.  **Ctrl** toggles it off so the tape only
measures, and the prompt says which mode it is in.  `/guides` clears them all,
their Edit > Delete Guides.

**And the reading follows the cursor** while you drag, offset far enough to
read - a tape you have to look away from is no use for a quick check.

The eraser finds a guide anywhere along it.  One routine says where a guide
lands on screen - the whole infinite line, not the one-unit stub that records
its direction - and both hit tests and the highlight use it.

Not done: the protractor, and typing a length to resize the whole model.

## The Move tool, checked — 3 September 2026

Tested rather than assumed, and it holds up.  Headless: a whole solid selected
and moved goes rigidly, adds nothing, and keeps its six faces and its height;
one top edge moved stretches the top from sixty square feet to a hundred.  In
the app: box selected, `M`, grab a corner, type `<0,-25',0` - **Moved 25'-0"**,
geometry intact.

Left alone: selecting a solid highlights its back edges too, so a selected box
reads as see-through.  SketchUp shows selected hidden edges as well, so this
may be right; worth a look when someone finds it annoying.

## Next: the planar region rebuild

Agreed, and it should be next.  Every remaining feature leans on it, and each
repair rule added meanwhile makes the migration harder.  `IsPatch` was written
to *replace* a flag test rather than sit beside one, and it now answers push,
split and profile with the same question - that is the direction, but it is not
the destination.

The order from `SUGGESTIONS_TO_CLAUDE.md` still stands:

1. Split edges at intersections.
2. Merge coincident vertices within one documented tolerance.
3. Group edges by coplanar plane.
4. Build directed half-edges and walk minimal bounded cycles.
5. Nested cycles become holes, not overlapping faces.
6. Rebuild affected regions after line, arc, erase and move.
7. Keep solid faces separate from derived planar regions.

The 109 headless checks are the safety net for it - they cover push, split,
move, snapping, save and reload, and they should all still pass afterwards.

## The planar region engine — 3 September 2026

`uRegion.pas`.  Segments in, flat regions out, and it knows nothing about the
document, the screen or any tool - which is what makes it testable on its own
and what stops the special cases creeping back in.

The pipeline is Codex's list, in order:

1. cut every segment where another crosses or touches it
2. weld ends that are within one tolerance of each other
3. gather the edges into the planes they lie in
4. in each plane, walk the smallest cycles of a directed half-edge graph
5. a cycle inside another is a hole in it, as well as a region in its own right

Step 4 is the only clever part: every undirected edge becomes two darts, the
darts leaving each vertex are sorted by angle, and walking a face means
"having arrived along a dart, leave by the one immediately clockwise of the
way you came".  The cycle that comes out wound the wrong way is the infinite
space around the drawing and is thrown away.

**One tolerance.**  `REGION_TOL`, a distance in model units.  Welding, "is this
point on that line" and "is this the same plane" all use it, so there is one
number to argue about rather than a dozen scattered epsilons.

**70 checks in `tests/run-region.sh`**, each one a drawing somebody would
actually make: a plain square; three sides of one enclosing nothing; a cut down
the middle; a cut that stops inside dividing nothing; a tic-tac-toe nine; lines
drawn midpoint to midpoint so every meeting is a T; a square inside a square
with the hole classified; an upright square; one on a 3-4-5 slope; a wall and a
floor sharing an edge; two lines crossing in mid air enclosing nothing; a
diagonal cut; a cut assembled from two strokes; the same edge drawn twice; one
lying along part of another; a 24-sided ring; corners a nanometre apart welding
shut; a concave L; two squares sharing a whole edge; an inner square sharing an
edge with the outer; three cuts crossing to make six pieces; the standing 6 x 6
grid; and 144 cells out of 26 segments in 3 ms.

**Checked against a real drawing.**  `/regions` runs the engine over the
document's edges and reports what it finds beside the faces actually stored.
It changes nothing.  On a grid drawn through the GUI: *13 edges -> 30 regions
(468.7 sq ft, 0 holes) in 1 ms.  Stored flat faces: 30 (468.7 sq ft).*  The two
agree exactly.

### What is left to wire it in

The engine is done and proven; making the document use it is the next piece,
and it is separate work:

* **Derive non-solid faces from it** after any edit that changes edges - line,
  arc, erase, move.  Keep the ink and any per-face state by matching a new
  region to the old face whose centre falls inside it.
* **Leave solid faces alone.**  They are 3D boundary topology, not planar
  regions - Codex's step 7.  `IsPatch` already tells a whole side from a piece
  of one, and that stays.
* **Retire what it replaces**: `SplitFace`/`SplitFacesWith`, `MergeFacesAcross`,
  `DropOpenFaces`, `ClosedChain`, and the special face-making in the rectangle,
  circle and arc tools all become one call.
* **Watch the cost.**  Splitting is O(n squared) in segments and welding is
  O(n) per lookup; 26 segments is 3 ms, but a real duct drawing with a few
  hundred wants a grid or a sort before this is called on every edit.  Cheap
  fix when it matters: only rebuild the planes an edit touched.

The 120 document checks plus these 70 are the safety net for that work.  They
should all still pass when it lands.

## The document is wired onto the region engine — 3 September 2026

Drawn faces are worked out from the edges now.  One call, `RebuildFlatFaces`,
runs after anything that changes an edge, and it replaced four rules:

* `SplitFacesWith` - a line cutting a face in two
* `ClosedChain` - a run of lines closing on itself
* `MergeFacesAcross` - two faces joining when the line between them goes
* `DropOpenFaces` - a face whose outline stopped being backed by real edges

All four are deleted.  **127 net lines out of `uWork.pas`**, and the tools no
longer make faces themselves: the rectangle, circle and arc tools add their
edges and ask what the edges enclose.

**The line Codex drew is the one that holds it together.**  A solid's faces are
the boundary of something in three dimensions, not an area on a flat sheet, so
they are left alone - and a solid's *edges* are kept out of the calculation for
the same reason.  Without that second half, every box would grow a phantom flat
face inside itself the next time anything was rebuilt.  `PushPull` now hands the
edges round its base to the solid's group (`ClaimOutline`), and a test watches
for it: four loose edges before the push, none after.

Colors survive: a new region takes the color of whichever old face its middle
fell inside.

### Checked, end to end
* rectangle drawn -> face appears, with no `AddFace` anywhere
* a line across it -> two faces; another -> more, all the right areas
* a circle inside one -> *53 edges -> 3 regions (512.8 sq ft, 1 hole) in 0 ms*,
  the hole classified, stored faces matching exactly
* rubbing out the cut line -> *"Deleted.  1 face gone with them."* - the merge
  falls out of the rebuild rather than from a rule
* push a box, then draw a line elsewhere to force a rebuild -> *1 edge -> 0
  regions*, box intact, no phantom face
* the standing grid: 9 edges -> 12 regions, pushed into towers, with a circle
  pushed into a smooth cylinder beside them

135 document checks and 70 region checks, all passing.

### What is still stored, on purpose
`SplitFace` on a **solid** face stays - that is how a box top is cut, and it is
3D topology rather than a planar region.  `IsPatch` still decides whether a
push slides a whole side or lifts a piece out.

### Left to do
* **Only rebuild the planes an edit touched.**  Splitting is O(n squared) in
  segments; 53 edges is under a millisecond, but a real duct drawing with a few
  hundred will want it.  The engine already groups by plane, so the hook is
  there.
* Arcs are chopped at a fixed 48 for the calculation.  A very large circle
  deserves more, a tiny one fewer.
* The vector types live in `uWork`, so `uRegion` has to use it.  They would sit
  better in a small unit of their own with both depending on that.

## Making the region engine fast — 3 September 2026

Measured first, which is just as well: the cost was not where "touched planes"
would have helped.  A grid of forty lines - 82 segments, 1600 regions - took
**365 ms**.  Three loops were doing it:

* **welding** walked every vertex found so far, so three thousand ends were
  compared against sixteen hundred vertices - five million distance sums.  The
  points go into a grid of cells one tolerance across now, so anything close
  enough to weld is in this cell or one of the twenty-six around it.
* **plane discovery** tried every pair of edges to find the ones sharing a
  vertex.  It asks through the vertices instead - only edges meeting at one can
  define a plane together.
* **the duplicate-edge check** looked back over every edge so far, on its own
  ten million comparisons.  Hashed.
* **hole classification** measured every loop against every other.  Two loops
  can only nest if they are *not joined up to each other* - if they are, the
  cycle walk has already put the boundary between them - so the vertices are
  union-found and only loops in different pieces are compared.  On a grid,
  where everything is one piece, nothing is compared at all.

That took 365 ms to **11 ms**, thirty times faster, and it is the case that
matters: a plan drawing is all one plane.

Then the ones that do help a drawing spread over planes:

* **splitting is bucketed in space.**  Only segments whose boxes share a cell
  are tried against each other.  A grid gains nothing - its lines cross the
  whole drawing - but a model with work in several places halves.
* **and then split per plane**, which is what the cache needed anyway: a
  crossing between two edges that are not coplanar cannot change the cycles in
  either plane, so there is no reason to look for it.

**The cache.**  `BuildRegionsCached` works out which planes the segments lie in
- cheaply, from the input segments, before any splitting - hashes the segments
in each, and keeps the regions for any plane whose hash has not moved.

    one plane      82 segments   1600 regions    365 ms  ->   11 ms
    one plane     162 segments   6400 regions       -    ->  131 ms
    24 planes     433 segments   1536 regions     19 ms  ->    5 ms cold
                                                          ->    1 ms editing
                                                                one plane
    40 planes     720 segments   2560 regions     95 ms  ->   46 ms

The cache is checked three ways: cold it finds what a full rebuild finds, warm
it still does, and after an edit it agrees with a full rebuild - and editing
one plane costs less than building the lot.

## One zip, four builds — 3 September 2026

`./build.sh ship` builds Windows and Linux twice each and puts all four in one
zip: the fast pair at the top to run, and `checked/` beside them with the range
and overflow tests compiled in.  The checked build prints a heap report when it
closes, which is noise unless you are hunting something - the release build has
no heap tracing in it at all.

Two things that had gone wrong: the Windows step packed a zip of its own part
way through, before the other three builds existed, which is why one came out
short; and the upload failed silently on a bigger file.  Every build now packs
once at the end, after checking all four are there, and the upload is retried
three times before it gives up.
