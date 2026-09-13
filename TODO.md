# Heckers Sketch - what's next

The point has not changed: rough two items out at a real scale and get an
honest measurement between them.  Quick duct transitions and pipe layouts -
the mockup you would otherwise open SketchUp to do - given away free.

`docs/sketchup/` is the spec: sixteen of their help pages, read properly and
written up, each saying what we have, what we do not, and where we differ on
purpose.  When we argue about how something should behave, that is what we
argue against.

`docs/isometric-views.md` settles what PLAN, ISO and 3D are each for.
`docs/transition-ticket.md` is how a duct fitting gets called out on a job.
`docs/interchange-and-flat-patterns.md` is DXF and the unfolding.

**History lives in the commit messages.**  This file is what is left to do.
`git log` reads better than a diary kept by hand ever did, and it cannot go
out of date.

---

## Where it stands, 5 September 2026

Drawing: lines, rectangles, circles, arcs, offset, push/pull, move, rotate,
erase, text with leader lines, dimensions you place yourself, the tape
measure with guides and the protractor with angled ones.  Snapping and inference - endpoints, midpoints, the midpoints a
crossing makes, on-edge, axis locks, From Point - and a snapped point now
holds until you mean to leave it.

Faces are derived from the edges that close them, in any plane, including
sloped ones - a circle goes on a roof and pulls out square to it.

Three views that each know what they are for: PLAN draws on the ground, ISO
locks to the three paper axes with Shift to come off them, 3D is the free
camera and the only place anything goes off-axis.

Around the edges: portable, single instance, drafts that survive a crash,
self-update, crash and bug reports that go somewhere, Windows on its own TLS.

Two test suites, both green: `./tests/run.sh` (333 checks) and
`./tests/run-region.sh` (76).

---

## Next up, in order

**Touch (2026-09-08).**  `uTouch.pas` hooks GTK3's touch-event; the gesture
layer is `OnTouch` in uMain: tap, drag, two-finger pan, pinch.  Untested on
real glass here - Xephyr has no fingers - so the first report from the
all-in-one decides the thresholds (8 px, 180 ms).  Next: Windows touch
messages into the same layer, touch-down showing what hover would, the
one-button-and-wheel rules for a remote desktop, then the point-setting
controller.  See docs/touch.md.

**Start-up screen and the busy bar (2026-09-07).**  `uSplash.pas`; the
`Progress` hook in uWork is the one channel long work reports through
(uRegion and uMain call it; the tests leave it nil).  Two GTK3 lessons paid
for: an `fsSplash` form is hidden by the LCL the moment the main window
shows, so the card is `fsSystemStayOnTop`; and a busy main thread's repaint
only reaches a maximized window if the messages are let through *before*
the Repaint (a pending configure keeps the window's updates frozen).
`PlanesOf` in uRegion now uses hash grids for ends and planes.

**Fifty thousand things (2026-09-07, release build, 1920x1000).**  2500
cubes with a diagonal on two faces each: 15000 faces, 35000 lines.  A frame
with everything on screen is 160-200 ms.  Everything selected and moved:
working the faces out went from 65 s to 1.5 s (bulk delete of the old faces,
old faces and seen areas indexed by plane, box and middle rejects in the
tiling pass and the duplicate check, the busy bar throttled to a paint every
quarter second).  Delete of the selection: a minute to nothing.  Hover with
everything selected: 117 ms to 23 ms (the outlines cached in a layer).
What is left on a move of everything: `regions` 0.5-3 s (BuildRegions per
plane, all planes touched) and the duplicate check 0.5-0.9 s.  `/timings`
prints the phases (`loop phases ms`).

**Threads - the first one is in.**  The lines-on-faces cache (`EnsureOnFace`)
is built by `TOnFaceWorker` from a deep copy of the entities and queued back
with `TThread.Queue`; the main thread takes it only if `FEditSeq` has not
moved.  That is the pattern for the rest: copy in, compute, queue out, check
the sequence, fall back meanwhile.  `DefaultThreads` is off for the tests and
the tools, on in the program; `/threads` toggles, `/rendertime` reports.
The snap-cache rebuild itself is only ~3 ms even at 120k points, so it is
not worth a worker; the hover that walked it every mouse move was the cost,
now fixed by keeping the projected positions per camera (SameProjector).
Remaining thread candidates: the face fill by bands, then lines-on-faces by
line.
then the face fill by bands, then lines-on-faces by line.

**Threads - a weekend job, soon.**  The rules and the OpenGL discussion are
in docs/render-acceleration.md.  Agreed 2026-09-07: no threads until the
single-thread wins are taken, and they nearly are.  Left before threading:
the region engine on a big drawing (uRegion: PlanesOf and SegsInPlane are
planes times segments; 34 ms of a 60 ms move on a 528-face spool), and
nothing else measured over 10 ms.  Then, in this order, each one behind a
"threads" toggle so it can be switched off if it misbehaves: (1) the face
paint in Render, split by screen band - every face is projected and filled
into the depth buffer, and bands do not overlap; (2) the visible-runs pass,
split by line - it only reads the depth buffer; (3) RebuildSnapCache off
the main thread after an edit, swapped in when done.  Everything these
touch is built per call from the document with no globals, which is why
it can be split.  What must stay on the main thread: anything LCL, the
document itself while a tool is mid-edit, and the undo stack.


0. **Follow Me is in, both halves** (2026-09-06: TWorkDoc.Revolve and
   TWorkDoc.Sweep).  Left over: the two-circles-make-a-ball offer if still
   wanted (two circles sharing a centre on two planes, same radius: offer
   to spin one about the other's axis); a profile that is not square to
   the path's first leg is carried as drawn rather than squared up; the
   winding heuristic (away from the ring's middle) is right for circles
   and rectangles and could misfire on a concave profile.


The direction, settled 6 September: one drawing, one camera; the things that
build a model from numbers are wizards under Create that drop the result
into the drawing; hammer the general tools before the generators.

1. **The field-sketch wizard is the pipe spool wizard** (built 2026-09-07,
   uPipe / uSpool, docs/pipe-spool.md).  Reducers and flanged joints went
   in 2026-09-07.  Left on it: branches (a tee off the run), rolled 45s
   off the twelve diagonals, valves and other fittings, the pipe wall.
2. **The transition wizard's ends**: TDF, flange out, flange in, slip, drive,
   raw, corners notched - per edge, each worth the shop's own number of
   material.  Then the offset (same size both ends) and the elbows as more
   wizards.
   From the first report on it (2026-09-06): the ends need a type each -
   raw, TDF flange, flanged in and down, flanged out - drawn in 3D; the
   important dimensions put on the 3D part by default; a corner 3D preview
   in the wizard beside the plan sketch; and the same wizard, with fitting
   type radio buttons at the top, building a tee and a 90 / 45 / any-angle
   elbow.  Done so far: hollow ends, the report button, the end types (raw,
   notch, flange out / in, TDF, slip and drive both ways), all four height
   moves, the dimensions on the part, the corner view on a tab, the tag
   written on the part, Email it... to the office, and the elbow and the
   tee behind radio buttons at the top, reducing elbows, and the elbow
   from field measurements.  Left: TDF corner pieces if wanted; the flat
   pattern of a fitting with its ends on (parked on purpose).

3. **The rest of the dimension tool**: radius and diameter, dragging an
   extension line out of the way, endpoint styles.
4. **Drill, the hard cases.**  A tunnel crossing a tunnel that was itself
   already crossed; two tunnels that share a wall plane (coplanar floors -
   left overlapping today); a tunnel that grazes another.
5. **Sliding a wall of a block with a tunnel through it** tears the block:
   the tunnel's lining is not attached to the wall that moves.
6. **Rotate's Shift and Alt.**

---

## Smaller things, roughly in order

* **Edges that partly overlap.**  An edge landing exactly on one already there
  is skipped.  SketchUp goes further and splits both where they overlap in
  part, so a new line borrows the piece it shares.
* **The eraser's modifier keys.**  SketchUp softens with Ctrl and hides with
  Shift.  There is a soft flag on an edge now, so the hook exists.
* **A leader that follows its edge.**  A note points at a point; move the edge
  and the note keeps pointing at where it was.
* **More in the settings lists.**  They can hold more than a row ever could
  and nothing has been added to them.
* **Custom mouse cursors.**  The tool's glyph rides beside the crosshair,
  which says which tool is in hand without per-platform cursor images.  A real
  cursor per tool would read better.
* **Light mode is harder to read than dark.**  One deliberate pass over the
  light palettes rather than nudging single colours.
* **Neon on a light screen** is muted - the cost of going alpha-based so a
  drawing survives a theme change.
* **A ground plane in the orbit view.**  The three coloured axes are enough to
  know which way is up; a plane that follows the camera would read better.
* **Print more than one sheet** at a time.
* **Undo memory.**  TOY keeps sixteen full-screen bitmaps.  PRO keeps document
  copies, which is cheap.  TOY could be smarter.
* **Performance with fittings.**  /rendertime times a whole frame (paper,
  drawing, composite) and the overlay with the current selection; /timings
  prints the steps of each edit.  Through 2026-09-07, release build at
  1920x1000: a 528-face spool from 29 ms a render to about 8; ten spools
  (5280 faces, 10800 lines) at 41 ms a whole frame, of which the face fill
  is 20 and the lines-on-faces pass 10 (was 18 before FOnFace cached the
  edge-to-face relation).  An outside review (Codex, 2026-09-07) agreed
  with the direction and listed, in its order: a dead per-frame face copy
  (removed), the lines-times-faces search (cached), the whole-frame timer
  (done), and four still open, which are the list before threads:
  (a) done 2026-09-07: quick frames while the camera moves - lines on faces
  sampled at 8 not 32 with no bisection, one coverage sample a row - full
  frame on release or 220 ms after the wheel; ten spools zoomed in 36 ->
  23 ms, one spool 23 -> 11; /quick toggles;
  (b) FillLoops allocates two scratch arrays per face and scans four
  sub-samples a row - keep scratch on the surface; when zoomed in the fill
  is the whole frame (24 of 46 ms on the 31k drawing), so this is the next
  one; screen culling and a plain highlight past 3000 selected went in
  2026-09-07 (overlay 558 -> 38 ms with 31k selected); (c) face normal, area and centroid are model properties
  recomputed per frame - cache on the entity, drop with FSnapDirty;
  (d) the hover does FaceUnder, the snap, then HitFace again on some tools,
  and the select hover runs three hit tests - one walk should do.  Then
  the region engine (PlanesOf / SegsInPlane are planes times segments).
  Threads after that; see the note at the top of Next up.
* **Remote-display performance.**  Motion is serviced once a tick so the
  pointer tracks over VNC.  What is left is the whole-bitmap reload.

---

## Two things that are getting big

Neither is broken and neither is urgent.  Written down because the moment to
deal with size is before it is a problem, and because both wanted a run of
their own rather than being folded into a fix for something else.

Measured 5 September 2026, after a dead-code pass took out eleven routines and
sixteen unused locals.

* **`TWorkDoc.Render` is 591 lines** - the longest routine in the program by a
  wide margin.  It draws faces, then lines, arcs, notes, dimensions, guides and
  guide points, and works out depth and profiles along the way.  Those are
  separate passes that happen to share a set of locals, so it splits along
  seams that are already there.  It is also the code that has changed most
  lately - holes, back faces, the edge index - which is the argument for doing
  it first.

* **`uMain.pas` is 11,621 lines**, against 4,714 for `uWork.pas` and under
  1,500 for everything else.  The routines in it are not the problem: 240 of
  them, median 24 lines.  It is the file that is unwieldy, not the code.
  Pascal has no partial classes, so the honest split is include files - the
  class declaration stays where it is and the bodies move out by the section
  banners the file already carries (`the screen` is 1,996 lines, `mouse on the
  screen` 2,037, `pro mode: the tools` 1,315).  Mechanical, and no behaviour
  changes.

Worth knowing before either is attempted: there is almost no duplication to
find.  A scan for repeated eight-line blocks across the six largest units
turned up two in twenty-one thousand lines, and the larger of the two - four
copies of tracing an outline - has been folded into one routine.  So this is a
tidying job, not an untangling one.

An audit is worth pairing with the split: routines are easy to count, but
nothing so far has looked for branches that can no longer be reached, or for
rules that are still enforced somewhere after the reason for them has gone.
That needs reading, and reading is easier in a file that fits on a screen.

---

## Python, on the way out

Two bits of it are left, and neither needs to be.

* **`tools/fetch-reports.py`** should be a small Pascal program.  It is a
  fetch, a name check, a size cap and a file write - nothing that wants a
  language runtime.  It also has to keep working, so this is a port with the
  old one kept alongside until the new one has collected a day's reports and
  agreed with it.

* **`build.sh` turns `WHATS_NEW.md` into `whatsnew.inc`** with an inline
  python3 heredoc.  That one is worth killing first: it puts Python on the
  critical path of a release, on any machine that cuts one.  It is a read, a
  split on headings and a write.

The GUI driver was the third and is gone - `tools/drive/hsdrive` does that
job in Pascal now, through LazHIDControl.

---

## Open questions

* **A perspective camera, for looking only.**  A report on 11 September asked
  whether the far end of a hundred foot barn should not look narrower than the
  near end.  It should, to the eye - and it does not, because the 3D view is a
  parallel projection and `docs/isometric-views.md` turned perspective off on
  purpose so that lengths stay to scale.  SketchUp has both and defaults to
  perspective, which is where the expectation comes from; its Parallel
  Projection behaves exactly as ours does.

  The shape of it, if we do it: perspective is a *viewing* mode, never a
  working one.  Turn it on to show somebody the model, turn it off to draw,
  and never let a dimension be read off a perspective view.  `Project` would
  gain a divide by depth and `Unproject` a matching one, both behind the same
  `TProjector`, so the tools would not need to know.  What has to be decided
  first is what the tools do while it is on: refuse to draw, or quietly snap
  back to parallel for the duration.  Until that is answered this is not
  ready to build.

* **Which way a loose face is meant to point.**  A face the region finder
  works out is now wound to face along whichever axis it is squarest to,
  positively - the same rule a face you draw has always followed.  That gets
  a roof right, because both slopes are squarest to blue.  It cannot get the
  two ends of a barn right: they are back to back, they both come out facing
  the same way, and one of them therefore shows its back.  Nor can it help a
  roof steeper than 45 degrees, where the slopes are squarest to the ground
  axes and go one each way again.

  Reverse Face on the right button is the answer for now, and it is the
  answer SketchUp gives too: when the rule guesses wrong, the person looking
  at it says so.  Doing better without being told means knowing which side is
  outside, and the only thing that really knows is a closed solid.  Orienting away from the model's centre
  would fix the barn and break a plan drawn on the ground beside a building.
  Making every face agree with its neighbours across shared edges cannot be
  done at all where three faces meet on one edge - the top of a wall, the
  wall under it, the gable standing on it - which is every house.  Worth
  coming back to when there is a real notion of a solid to hang it on.

* **Making a solid out of what you drew.**  A face already carries `Solid`
  and `Grp` - which solid it belongs to, or 0 for loose drawing - and
  push/pull sets both, the file keeps them, back-face culling and push/pull's
  drag-along both read them.  What is missing is anything that promotes loose
  faces into one: a roof built on top of a box is loose faces sitting on a
  solid, and nothing ever looks at that closed shell and says so.

  The test is not vague - within a candidate set, every edge is used by
  exactly two faces - and once it passes, orienting the whole shell outwards
  once settles winding, culling and every later question about which side is
  out.  Inference gets it too: the snap could prefer the skin facing the
  camera over a point on the far side.  What has to be decided first is
  **when** it happens.  Every region rebuild would be expensive and would
  change what geometry *is* while somebody is drawing on it.  SketchUp only
  does it inside a group, on demand.  Until that trigger is chosen this is
  not ready to build.

* **Making a solid out of what you drew.**  A face already carries `Solid`
  and `Grp` - which solid it belongs to, or 0 for loose drawing - and
  push/pull sets both, the file keeps them, back-face culling and push/pull's
  drag-along both read them.  What is missing is anything that promotes loose
  faces into one: a roof built on top of a box is loose faces sitting on a
  solid, and nothing ever looks at that closed shell and says so.

  The test is not vague - within a candidate set, every edge is used by
  exactly two faces - and once it passes, orienting the whole shell outwards
  once settles winding, culling and every later question about which side is
  out.  Inference gets it too: the snap could prefer the skin facing the
  camera over a point on the far side.  What has to be decided first is
  **when** it happens.  Every region rebuild would be expensive and would
  change what geometry *is* while somebody is drawing on it.  SketchUp only
  does it inside a group, on demand.  Until that trigger is chosen this is
  not ready to build.

* **Five things about the transition ticket** are listed at the end of
  `docs/transition-ticket.md` and want checking against a real one - the first
  being which side an arrow names.
* **DXF import** is deliberately last.  Writing is bounded work; reading is
  not, and a file that opens looking right at a twelfth of its size is worse
  than one that refuses.  Only when there is a particular file that has to
  come in.

---

## Where the line is

No objects, no groups, no components.  No booleans, no curved surfaces, no
textures, no materials, no follow-me.  No touch support - it is a laptop tool,
and every one of the inference cues depends on a cursor hovering somewhere
without being pressed.

Those are where this stops being a quick tool and starts being a worse copy of
SketchUp.
