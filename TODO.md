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

## Where it stands, 14 September 2026

Drawing: lines, rectangles, circles, arcs, offset, push/pull, revolve, drill,
move, rotate, erase, text with leader lines, dimensions you place yourself -
and can retype to resize what they measure - the tape measure with guides and
the protractor with angled ones.  Snapping and inference, and a snapped point
holds until you mean to leave it.

Faces are derived from the edges that close them, in any plane, including
sloped ones.  Faces that are not flat are cut into triangles before they are
drawn, so their depth is exact rather than fitted.  Loose faces are wound
against their neighbours rather than one at a time.  The program knows whether
a solid is closed, and says so on the way out.

Views: PLAN draws on the ground and can cut a slice through the model at a
height, ISO locks to the three paper axes, 3D is the free camera.

Getting it out: an export room with a live preview - PNG, JPEG, animated GIF
with a camera recorder, SVG, DXF flat or in 3D, STL, and OpenSCAD.  Printing
at scale or full size across many sheets.

Around the edges: portable, single instance, drafts that survive a crash,
self-update, crash and bug reports that go somewhere, Windows on its own TLS.

Two test suites, both green: `./tests/run.sh` (684 checks) and
`./tests/run-region.sh` (84), plus GUI scripts driven through Xephyr.

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

* **Edges that partly overlap - DONE 14 September 2026.**
  `TWorkDoc.AddLineSplit`: a line drawn along one already there cuts both
  where they share, so the overlap is one edge and the tails are their own.
  Only loose lines - a line that belongs to a solid is part of something that
  was built, and cutting it up underneath the solid is a different and worse
  idea.  The line tool uses it; rectangles, circles and arcs still do not.
* **The eraser's modifier keys - half done, 14 September 2026.**  Ctrl
  softens an edge and Ctrl+Shift brings it back, which is SketchUp's Ctrl and
  Ctrl+Shift, and both read the `Soft` flag that already existed.

  SketchUp's plain Shift, which *hides* an edge outright, is not done and is
  not a modifier - it wants a `Hidden` flag on an entity, a place in the
  file, and a "show hidden geometry" switch, because without a way back a
  hidden edge is an edge somebody has lost.  That is a feature, and it should
  be built as one.
* **A leader that follows its edge - DONE 14 September 2026.**  If the whole
  of a line is moving, whatever sits on that line moves with it, so a note
  aimed at the middle of an edge travels with the edge.  Remembering which
  entity a note is tied to would be the thorough answer and wants a field in
  the file; this is the cheap nine-tenths of it.
* **More in the settings lists - DONE 14 September 2026.**  The colour list
  has a row past the twelve swatches that opens the platform's own picker,
  which is the thing a row of swatches could never hold.  The palette stays
  twelve: a wall of swatches is a worse list, not a better one.
* **Custom mouse cursors - looked at 14 September, not done on purpose.**
  The obvious half is already there: the drawing takes a crosshair, orbit and
  the pan take the four-way, the chrome takes a hand.  What the entry means
  is a *glyph per tool* as a real OS cursor, and that is not a small thing
  and could easily be worse than what is there - Windows wants particular
  sizes, and a hotspot out by two pixels is a drawing program that feels
  wrong to use.  The glyph riding beside the crosshair was a deliberate
  choice, not a stopgap.  Leave it until somebody says the crosshair is not
  enough.
* **Light mode is harder to read than dark - DONE 14 September 2026,
  measured.**  The accent was the whole of it: at $1C7CD6 it made 3.7 to one
  against the light panel where the dark theme's accent makes 8.4, and the
  accent is text as often as it is a fill - the update line, a heading, the
  tool in hand.  It is $176BBD now, which is 4.7, and the quiet text went
  from 4.2 to 5.0.

  The other half was that text on an accent fill was written down as "dark,
  because the accents here are bright" in six places.  True of five themes
  and false of the light one, where it put pale grey on mid blue.
  `uSurface.OnPix` answers it from the fill's luminance instead, once.
* **Neon on a light screen** is muted - the cost of going alpha-based so a
  drawing survives a theme change.
* **A ground plane in the orbit view - DONE 14 September 2026.**  The four
  corners of the window are cast back onto Z = 0 and the ground is ruled over
  whatever that covers, at the same pitch the paper grid and the scale bar
  use.  Faint, under everything, and off with the GRID button.  A camera
  looking along the ground casts its corners past the horizon, so the count
  is capped and the lattice dropped when the view is too flat to rule.
* **Print more than one sheet - DONE 14 September 2026.**  `/print all` sends
  every sheet of the drawing, a page each.  `/print` still does the one on
  screen, because printing tabs somebody is not looking at should be asked
  for.  The loop itself has not been through a real printer - only the
  dialog, the command and the tab being put back afterwards.
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

## Where this could go - 12 September 2026

Talked through with Tony after the barn reports.  The question was what this
could do that people are already asking FreeCAD and SketchUp for and not
getting.  Written down so none of it gets re-argued from scratch.

### What the program is for, said plainly - 13 September 2026

Tony: *"my goal is simply for any idiot to get into the program and be like
oh shit wow this is so simple to do a scaled drawing - kind of like I felt
ten years ago when I opened SketchUp and was able to draw a 3D model with no
experience."*

That is the spec, and it has a testable form: **how long to the first thing
somebody is proud of, and how many things must they learn to get there.**
Not features shipped.  Everything below has to answer to it.

Four things did it for SketchUp, and they are mechanisms, not atmosphere:

* **Push/pull** - one gesture that turns a flat shape into a solid, found by
  accident inside a minute, and it teaches the whole mental model at once.
* **Inference** - the program guesses and *shows you the guess*.  You feel
  helped rather than tested, which is the opposite of AutoCAD asking you to
  state your intent in a language you do not speak yet.
* **No setup** - no units dialog, no template chooser, no layer manager, no
  new-drawing wizard.  You are drawing seconds after the window appears.
* **Nothing to get stuck in** - no mode you cannot leave, no error that stops
  you.

We have the first two, which are the hard ones.

**The standing threat is accretion.**  The bottom of the window is already
fourteen tool buttons in two rows and six dropdowns - more than SketchUp's
default - and the roadmap wants pipe spools, duct transitions, flat patterns,
title blocks, PDF markup, STL and textures on top.  So the rule:

> **The first two minutes must never meet the trade machinery.**  SHOP is the
> pattern: one door, everything specialist behind it.  Adding a button to the
> default bar is a cost, and taking one off is a feature.

Two small things that serve the spec directly, neither started:

* **Design the first sixty seconds.**  The empty sheet currently says "pick a
  tool below, or press L for a line" - correct, an instruction rather than an
  invitation, and it leads nowhere in particular.  Better: the status line
  walks the magic path a step at a time, advancing as each is done - draw a
  rectangle, push it up, type a size - and never speaks again once it has
  been done once.  No Next button; everybody closes those.  Push/pull is
  discoverable by fiddling and got lucky; **typing a real size is not
  discoverable by fiddling at all**, and that is our one extra ingredient.
* **The session recorder is a usability lab.**  It was built for bug reports,
  but hand the program to five people who have never seen it, ask for a shed,
  and replay what comes back.  Where they stalled, in their own hands, with
  no telemetry, no video call and nothing to install.  Use it before building
  anything else on this list.

### Ruled out, with reasons

* **G-code.**  A post-processor is not one feature, it is a family of them -
  Grbl, Marlin, Mach3, LinuxCNC, Fanuc, plasma height controllers - and none
  can be verified without the machine in the room.  Worse, the numbers that
  decide whether a cut is any good (kerf, lead-in and lead-out, pierce delay,
  feed, power, tabs, torch height) belong to the machine and the material,
  not to the drawing; put them in the drawing and we own them forever.  Every
  shop already has CAM, and all of it eats DXF or SVG, which we already
  write.  The work is in making what we hand over *cuttable*, not in emitting
  machine code.
* **Wiring schematics and circuit simulation.**  Done to death, and the wrong
  shape for this engine.

### Worth doing

* **Show people WHERE a shape is not closed - DONE 14 September 2026.**
  `/holes` (also `/openedges`, `/notclosed`) checks whatever is selected, or
  every solid in the drawing when nothing is, and draws every unshared edge
  over the model in red.  `TWorkDoc.OpenEdges` does the finding, with the
  same T-junction resolution `GroupClosed` uses so a seam merely divided
  unevenly is not reported as a hole.  The STL export's message points at it.

  The marks are dropped the moment the drawing changes, because an answer
  about geometry that has been edited since is worse than none.

  **And the way in is done too, 14 September.**  There is no "show me" button
  because there is nowhere to put one: the dialog has closed by the time the
  message is read.  So an STL or an OpenSCAD script that comes out open marks
  the edges on the drawing behind it as it goes, and says so.  OpenSCAD did
  not answer the closed question at all until now - it does, the same way the
  STL does, because it goes to the same printer.

  This is the thing that makes a SketchUp user look twice.  SketchUp has the
  same class of problem and the answer there is a third-party extension
  (Solid Inspector), which is a fair sign of how much is being left on the
  table.

* **A proper help system, as web pages.**  The drawing in every picture is
  `examples/etch-a-sketch.hsk` - see `examples/README.md` for why one model
  across all of them beats a good model in each.
  `docs/help/` is the skeleton: one
  page per tool, one per thing-you-do, a shared stylesheet in the program's
  own dark colours, and `shots/NEEDED.md` listing the 24 screenshots wanted
  and what should be in each.  Tony grabs the pictures.

  **The way in is done, 14 September**: Help > The manual, and `/manual`,
  open the copy beside the program, and the release zip now carries
  `help/` - a hundred kilobytes against a fifteen megabyte binary, and a
  portable program whose help is on a website is no help on a machine that
  cannot reach one.  With no copy beside it, it opens the website.

  Left to do: the pictures, and a pass making sure the words match what the
  tools actually do now rather than what they did when the page was
  written.  Worth keeping honest - it is the only documentation
  a person who is not reading the README will ever see.

* **Changing a size by typing it - DONE 13 September 2026, notes kept.**  Pick a
  dimension, type what it should read, press Enter.  `TWorkDoc.ResizeDim`
  and `VertsBeyond` in uWork; the command is `/resize`, and a bare length
  with a dimension picked does the same because typing a length and pressing
  Enter is already how every size in this program is given.

  Left on it: an arc with only some of its points past the moving plane
  comes out wrong (the same limit the move tool has always had); nothing
  between the two ends moves, which is right for a window in a wall and
  wrong if you meant to stretch the middle; and there is no handle to drag -
  it is typed only.  The notes below are why it is shaped the way it is,
  and are worth keeping.

  It is the most asked-for thing on the SketchUp forums that will never
  arrive - you measure after you draw over there, and a wrong number means
  drawing it again.  FreeCAD has it through a constraint solver, which is the
  main reason people bounce off FreeCAD, and it drags the topological naming
  problem behind it.

  What makes it reachable here is building it as **a typed edit, not a
  constraint**.  No solver, nothing stored, no over-constrained state, no
  naming problem - because nothing is remembered.  An `ekDim` already knows
  the two points it spans; typing a length works out the delta along `A` to
  `B` and performs a move.  The primitive exists: `TWorkDoc.MoveVerts`
  (uWork.pas) shifts a set of vertices and drags what is attached, which is
  what the move tool and the stretch behaviour already run on.

  The geometry is not the hard part.  The hard part is the rule for *which
  end moves*, and the honest answer is the one the move tool already uses:
  the end you did not anchor, with a way to swap.  It works the same in plan,
  which un-scratches the 2D half for nothing.

* **Textures on a face.**  Pick a face, pick a picture off the disk, stretch
  or tile it.  Asked for 13 September.

  The reason it is cheap here and expensive elsewhere: **our 3D view is
  orthographic on purpose**, so the map from a screen pixel back to a point
  on the face is affine - `u = ax + by + c`, `v = dx + ey + f`, worked out
  once per face from three known points, then two multiply-adds and a lookup
  per pixel.  No perspective divide, no per-scanline correction.  A
  perspective camera, which `docs/isometric-views.md` turned down for other
  reasons, would have made this the hard version of the problem.

  The pieces: read the picture with the LCL into a BGRA buffer; keep an
  origin, a U vector and a V vector per face in model space, which is the
  same thing SketchUp's texture pins are; sample inside `FillLoops` instead
  of writing a flat colour, times the Lambert term already computed there.
  Holes, clipping and the four-times supersampling all come free - they are
  already in that routine.  Call it a day or two.

  Where the picture lives is settled - see **Decided in passing** below.  The
  drawing stays plain text and a drawing with assets saves as a `.hskz` zip
  with the pictures beside it, so nothing has to be base64'd into a file that
  is meant to be readable.

  **And the argument for doing it is not pretty pictures.**  It is reference
  imagery at true scale: photograph a panel or a wall, drop it on a face,
  scale it against one known dimension, and trace over it.  That is the same
  want as PDF import below, reached from a different direction, and it is
  worth far more on a job than a render is.

  The guard rail: this is a picture on a face, not materials.  No library,
  no shading model, no reflectance, no UV editing beyond an origin, a size
  and a rotation.  "No textures, no materials" is in **Where the line is**
  below and this is a deliberate step over one half of it - so the other
  half has to stay put.

* **The drawing sheet - border, title block, revisions.**  Tony: "blue prints
  layout designer".  A printed sheet wants a border, the program name, who
  drew it, a description, dates, a revision block and a sheet number.  Most
  useful on a 2D drawing.

  This is also the thing SketchUp charges for and everybody complains about:
  LayOut is paid, slow and widely disliked, and FreeCAD's TechDraw is not
  loved either.  A model to a dimensioned, to-scale, printable sheet with a
  title block is genuinely underserved.  We already have most of the parts -
  sheets and tabs, a real scale, dimensions with text you can override, and
  now printing that comes out at true size.

  Second, though, not first: it is documentation, and documentation does not
  bring anybody new through the door.

* **PDF import, as lines.**  Tony's own daily problem: almost every drawing
  that arrives at work is a PDF and there is no way to scale it.  Bringing
  one in as our own 2D lines - then setting the scale off a known dimension,
  and adding revision clouds and notes over the top - would be worth a lot to
  anyone in the trades.

  Not started, and not to be started casually.  A PDF is a page description,
  not a drawing: vector PDFs give real paths and would work; a scanned one is
  a picture and needs tracing, which is a different project.  Wants a proper
  discussion first, including which library reads the page content - there is
  no chance of writing that from scratch here.

### The plan view - one project, two halves

Agreed 13 September, and written out so it is not re-argued once somebody has
half built it.

**The diagnosis first, because it was wrong to begin with.**  Tony's
complaint was that a 3D model looked like rubbish in the flat paper view and
that orthographic was to blame.  It is not.  Loading the barn and switching
to PLAN gives four filled slabs in two greys and nothing else - no walls, no
footprint, the building entirely hidden under its own roof.  Three things
cause it, and the projection is none of them:

1. **The faces are filled and Lambert-shaded in plan.**  The roof slopes come
   out different greys because they are tilted differently to a light source
   that has no business being in a drawing.
2. **Nothing is hidden or dashed.**  Everything paints in depth order, so the
   roof simply covers the building.  A drawing shows what is beneath; a
   camera does not.
3. **It is a top view, not a plan.**  A floor plan is a horizontal *section*,
   cut about four feet up, with the cut walls heavy and everything below
   drawn as visible lines.

Orthographic is right - it is what makes a plan measurable.  **PLAN renders
like a photograph from above instead of like a drawing.**

#### Half one: the slice, which decides what is in the drawing

Tony arrived at this from scratch and it is the correct answer.  The trade
name is a **cut plane**; Revit calls the settings **View Range** and gives it
four numbers (cut plane, top, bottom, view depth).  Ours is **two**: a top
and a bottom.  Everything between them draws.  Two is the right
simplification - four numbers is the kind of thing that makes Revit hard.

* **Roll the wheel to move the slice up and down through the building**,
  keeping its thickness.  Revit buries view range in a properties dialog;
  SketchUp makes you place a section-plane object in 3D, which is not a plan
  tool at all.  Nobody lets you travel up through a building by scrolling a
  plan.  This is a real differentiator and it is the part that would make
  somebody say *oh shit*.
* **The bottom of the slice is the drawing plane.**  One number does both
  jobs: the floor of what you can see and where the pencil is.  That is what
  a floor plan *means* - you draw on the floor and things go up from it.  Set
  the bottom to 9'-0" and you are drawing on the second storey, seeing the
  second storey, with everything below out of the way.
* **The slice filters snapping, not only drawing.**  Non-negotiable.  Hidden
  geometry that still grabs the cursor is the worst failure mode this program
  has ever had - it is the eave report of 12 September and the axis-lock one
  before it.  Same range, same rule, for what is drawn and what can be
  touched.  Get that right and drafting in plan becomes *safe*.
* **The front door is one gesture, not two spin edits.**  Click a face,
  "Plan from here", on the right-click menu that now exists: bottom goes to
  that face, top goes a sensible way above it.  Discoverable by accident,
  which is the only kind that counts.  The spin edits are for people who want
  numbers.
* **The two numbers are always on screen, and the program says when it is
  hiding something** - "3 things above the slice" in the status line.
  Otherwise the first experience of this feature is "where did my drawing
  go", and that person does not come back.
* **Default to the whole model**, so it cannot surprise anybody who does not
  know it exists.

Filtering is easy: skip entities outside the range, and include a face if any
part of it overlaps.  Proper clipping at the cut plane - so a cut wall can be
pochéd - is a later refinement, not the first version.

#### Half two: the render style, which decides how it is drawn

No shading.  No solid face fills, or a light hatch instead.  Hidden edges
dashed or dropped.  Line weights by role - heavy where the cut plane passes
through, normal for what is below it, faint for what is deeper.  This is the
half that makes a printed sheet look like a sheet, and it is most of the
work.

Neither half is much use alone: you cannot draw a proper plan without first
deciding what is cut.

#### And then 2D mode, which is a thin layer on both

**A lens, not a property of the document.**  Freely switchable, both
directions, always.  A one-way door forces a decision before anybody knows
enough to make it, and it would throw away the best workflow in the idea -
draw the plan, flip to 3D and push it up to check, flip back and the plan is
still your plan.  That is what SketchUp is bad at.

It costs nothing to keep reversible because there is nothing to fork: all the
geometry is `TP3` already, and a 2D drawing is one where everything sits at
Z = 0.

The mode itself hides push/pull, drill, follow-me and orbit, locks the view
to PLAN, locks the working plane to XY, and pins new geometry to the bottom
of the slice.  TOY and PRO already prove people accept a mode that takes
tools away - half of PRO's value is that it turned the dials off.  It is a UI
simplification and nothing else: it does not change the document, the file or
the renderer, which is why it is small **once the two halves above are done**.

### Decided in passing

* **The file stays plain text; assets go in a zip.**  A `.hsk` you can read,
  diff and merge in git is a real differentiator and rare in CAD, so it stays
  the default.  A drawing that needs assets - textures, an imported PDF, a
  logo in a title block - saves as `.hskz`: a zip holding `drawing.hsk` plus
  `assets/`, the way ODF does it.  Text unless there is a reason not to be,
  and the reason visible in the extension.

* **The title block ranks higher than first written.**  For a regular Joe the
  *oh shit* is not drawing the box - it is **printing something that looks
  professional with his name in the corner**.  That is the artifact he shows
  somebody and the screenshot that gets posted.  Drawing the box is the
  setup; the sheet is the punchline.  It also has a home now: `PrintTileMarks`
  already draws in page coordinates after the model render, which is exactly
  the seam a title block lives in - so paper space is a new idea with a
  precedent rather than a new architecture.

### Settled

* **The plan view, both halves, and the tool strip - built 13 September
  2026.**  The slice (`TWorkDoc.SetSlice` / `InSlice`, the CUT strip beside
  the view button, Ctrl+wheel to travel, Plan From Here on the right button),
  the render style (no light in plan, pale flat fills), and the tools stood
  up on the left with MORE and SHOP behind doors.

  Left on it, in rough order of worth:

  * ~~**Hidden lines.**~~  Built 13 September: in PLAN, a line the depth test
    rejects is drawn dashed and faint rather than dropped, which is what a
    drawing does with something it cannot see.  `TArtSurface.DepthBehind`
    turns the test round; the pass costs 2.5 ms of a 37 ms plan on the barn,
    where the face fills are 17 of it.  3D is untouched on purpose - there a
    hidden line is round the back of something solid, and dashing them all
    would put the far side of every box over the near side.
  * **Poché on a cut wall.**  Faces are included whole when any part of
    them overlaps the slice; clipping them at the cut plane, so a wall the
    plane passes through fills solid, is the version an architect would
    recognise.
  * **2D mode** as the thin lens on top - hide push/pull, drill, follow me
    and orbit, lock the view and the plane.  Cheap now that the two halves
    below it exist, and worth doing after somebody has used the slice for a
    while and said what it still needs.
  * `fit` frames the whole model rather than what is in the slice.  Arguable
    either way; leave it until it annoys somebody.

* **BGRAControls: no, and the measurement is on record.**  Their virtual
  screen keeps a persistent bitmap, tracks a discarded rect and blits - which
  is what `TArtSurface` already does, with three layers and a Z buffer on
  top.  `TBCButton` is windowless, so no window handles either.  And it is
  not a widget set: no edit, no combo, no spin, which are exactly the
  controls we keep needing.

  `/rendertime` now splits the paint, and on the barn in Xephyr the whole
  paint handler is 11.3 ms of which the blit is 0.3 and the guides 0.1.  Our
  own drawing is under half a millisecond of it; the rest is the widgetset
  delivering the expose, which any paint surface goes through.  A real screen
  figure is still wanted, and the breakdown makes it a five second check.

  Where a faster rasteriser would pay is `FillLoops` - 10.7 of a 17.4 ms
  frame - and not as a swap, because ours writes the Z buffer per pixel and
  BGRABitmap has no depth at all.

  The hand-skinning stays.  One consistent look on Windows and Linux, and
  GTK3 cannot get at it.

### The command bar, next time somebody is in there

Raised 13 September, not started.  With the deck down to one row there is
room to make the command bar taller, and a reason to: `/rendertime` and
`/timings` write a paragraph into a strip built for a sentence, so the end of
what they say is simply not there.  Two halves, and they are separable:

* **Wrap the bar to two or three lines** when the message is long, and back
  to one when it is not.  Cheap, and it fixes the common case.
* **A long answer belongs somewhere you can copy it from.**  A report you
  cannot select is a report you have to retype into a bug report by hand.
  Either a small panel with the text selectable, or - probably better and
  certainly smaller - `/copy`, which puts the last message on the clipboard
  and says so.  Then nothing has to become a dialog.

Do the wrap first and see whether the second half is still wanted.

### The lesson of 13 September: it exists and nobody can find it

Twice in one day, and the second time from the person who commissioned the
feature.

* PLAN was not on the VIEW menu.  Everything built into the plan view this
  week - the cut, the drawing style, the dashed hidden lines - was reachable
  only by knowing `/plan`.
* Revolve has existed since 6 September.  It was called FOLLOW ME, which is
  SketchUp's name for sweeping along a path and nobody else's name for
  anything, and it sat behind the MORE door.  Tony went and asked a friend's
  CAD program for a lathe and came back to ask why we did not have one.

Neither was a missing feature.  Both were a name or a door.  So, as a rule
to check anything against before it ships:

> **A feature nobody can reach is a feature nobody has.**  Before it is
> called done: is there a way to it with the mouse alone; is it called what
> the trade calls it rather than what the program we copied calls it; and
> would somebody who had never been told go looking where it is?

`/plan` and `/revolve` both existed the whole time.  A command is not a way
in - it is a shortcut for somebody who already knows.

### The rectangle, on a plane that is not the ground

Tony, 13 September, flagged and deliberately left for later:

> "There is a bug in there when I am try to draw it on a different plane I
> can only get each plane in one flat direction sort of.  It's hard to
> explain."

Not reproduced yet, and worth a report with a session in it rather than a
guess.  What to look at first: `RectCorners` lays the four corners out along
the working plane's own two directions - `PlaneAxes` for XY, XZ and YZ, and
`GetFreePlane` for a face - so a rectangle is always square to those two
directions and cannot be drawn turned.  If that is what he is describing then
it is a limit rather than a fault, and the answer is either a rectangle that
can be rotated as it is drawn, or Rotate afterwards.  If it is something
else - a plane that will not take a rectangle at all, or one that takes it in
the wrong plane - that is a fault.  Ask for the report first.

### Why the rubber band is not the colour of the plane

Asked for on 13 September, and it has been tried before.  Written down so it
is not tried a third time.

A line's colour here is **the direction it runs in**.  A plane is named by
the axis it *faces* - that is the convention the arrows use, right for red,
left for green, up for blue - and that is the one axis a line lying in the
plane can never run along.  Colour an outline on XZ green and every side of
it is labelled with the one direction it does not go in.  It reads as
information and it is the opposite of true.

What is real is the thing behind the request: while drawing you want to see
that you are still flat.  A single segment cannot say it - one line is one
direction and a plane takes two, which is exactly why a rectangle already
reads correctly with its red and blue sides.  So the plane says it itself:
`PaintHeldPlane` draws two short lines through the point along the plane's
own two directions, in their own axis colours.  Red and blue is upright, red
and green is flat.


### Still to discuss

* **The other two visual worlds - and Tony has already solved this once.**
  The main window is eight paint boxes and nothing else; `uSpool`,
  `uTransition` and `uUpdateForm` are 48 TLabels, 22 TEdits, 15 TButtons and
  13 TComboBoxes of plain LCL.  A wizard that looks like a system dialog next
  to a hand-drawn dark chassis is the real "looks unprofessional".

  **Look at `../lazrandr`.**  That is the pattern, and it is his own:

  * The LFM files carry plain, designer-friendly components with ordinary
    anchors, *"so the forms stay openable in the Lazarus designer"* - his
    words, in `utheme.pas`, and that discipline is the whole reason it stays
    maintainable.
  * `utheme.pas` applies the look at **runtime**: a palette (`clWindowBg`,
    `clSurface`, `clRaised`, `clAccent`, `clDanger`...) and *kinds* rather
    than per-control settings - `bkPrimary`, `bkNeutral`, `bkDanger`,
    `bkGhost` for buttons, `pkWindow`, `pkSurface`, `pkRaised`, `pkHeader`
    for panels.
  * BCButton, BCLabel and BCPanel for the parts worth styling; **TComboBox,
    TCheckBox and TMemo left native**, which is exactly the gap in
    BGRAControls and evidently not a problem in practice.

  That is what "sexy but official" means: a conventional desktop form, laid
  out the way a desktop form is laid out, whose buttons happen to be
  handsome.  It is the right answer for our dialogs and wizards.

  **It is not the answer for the drawing chrome**, and the measurement above
  says why: the hand-drawn window costs 0.4 ms a paint, looks identical on
  both platforms, and GTK3 cannot get at it.  The line to hold is that the
  main window is a canvas and the dialogs are forms, and they are allowed to
  be built differently as long as they share a palette.

  What it costs, said properly: BGRABitmap becomes a dependency **of the
  build**, not of the program.  It links in statically, so what somebody
  downloads is still one executable with no installer and nothing to go and
  find - which is the thing that line in the README is actually promising,
  and it stays true.  What changes is that a person building from source
  needs the package installed, which is already true of Lazarus itself.
  When the day comes, say it that way in the README rather than deleting the
  claim.

  Licence is fine - `LGPL-3.0-linking-exception` permits linking into an MIT
  program.  Worth doing the next time a wizard needs work rather than as a
  project of its own, and `utheme.pas` is most of the way there already.

* **A control base class.**  The cut strip is the second hand-rolled control
  in a fortnight (after the command bar) and the pattern is the same each
  time: hit test, hover, press, paint into a TArtSurface.  One base class
  with subclasses for button, field, spin and slider is maybe 300 lines and
  would make the next ten cheap.  Worth doing the next time a control is
  needed rather than as a project of its own.


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
materials - no library, no shading model, no reflectance.  A picture
stretched on a face is a different thing and is discussed above; materials
are what turns a sketch pad into something that needs a render farm.

Those are where this stops being a quick tool and starts being a worse copy of
SketchUp.

Two things that were on this list have since been built, on purpose and with
the reasons written down elsewhere: Follow Me (uWork.Revolve and Sweep), and
touch (uTouch.pas and docs/touch.md - the all-in-one made it worth having).

**And there is already a CAD program written in Lazarus: zcad.**  We are not
competing with it and we should not try.  It is a CAD program; this is a
sketch pad that happens to be to scale.  The moment a feature here only makes
sense to somebody who would otherwise be using a CAD program, it belongs in
zcad and not in this.  Simple is the product.


### The drive scripts now have a runner, and it is only a smoke test

tests/run-drive.sh runs the scripts in tests/drive and says whether each one
got through without the program falling over.  That is all it says: the
scripts leave screenshots for a person to look at and nothing compares them.

Two things worth knowing about it.  Several scripts expect a particular
drawing - "a single upright panel, seen from behind" is not whatever happened
to be open - and the runner carries that mapping, because naming alone does
not cover it.  And it is flaky at the edges: a script occasionally reports
failure and passes three times out of three on its own, which is the nested X
server and not the program.  Do not read a single failure as a regression -
run that script by itself before believing it.

Worth doing some day: have the scripts compare their screenshots against
kept ones, so a pass means something.

### The logo letters come up red when they are raised

Tony, 14 September: "i sort of like how i raised the letters and they have
red lines around the letters however i dont understand why the letters became
red, probably a bug!"

Not a bug in the program - the generator gives the letter faces the toy's own
red, the same ink as the body, on the reasoning that the logo is printed on a
red toy.  Flat, they read as dark lines on the frame because the lines over
them are black and the face is barely visible.  Raised a sixteenth, the sides
and the top are suddenly red on a body that renders pale, and it looks like
something went wrong.

The question is what the logo should be, not where the bug is.  Worth asking
Tony whether he wants the letters the colour of the frame - so raising one
reads as embossing - or a deliberate contrast colour.  Whatever he says is a
one line change in examples/make-etch-a-sketch.pas.

### A GIF export that crashed after the fact

Tony, 14 September: exported a GIF on the Windows machine, opened it, and
thinks the program went down.  A report was promised and has not arrived; the
one that came in at 07:41 was about /reface and carries no crash file.

Nothing to go on yet.  What there is: the film is held whole in memory before
a byte is written - a twelve second clip at 900x492 is about two hundred
megabytes of frames - and the packing pass is already skipped past a size for
that reason.  If a crash file turns up, the stage it died in is in the report
now, frame by frame.

### Closing without saving: half done

Tony, 14 September: closed the drawings, chose not to save, opened the program
again and the drawing he had declined to save came back.

Closing the last sheet now drops the draft, which covers the case he hit -
putting a drawing down and having it follow you to the next launch is not
putting it down.  What is still not covered is quitting the program outright
with unsaved work: that writes a draft on the way out by design, and it should,
because pulling the plug must lose nothing.  The open question is whether
answering "close without saving" to the quit prompt - if there ever is one -
ought to mean the same thing.  Nobody has asked for that yet.

### Our own fork of BGRABitmap, for later

Tony, 13 September: he likes the project and wants to keep using and
supporting it, and to send improvements back when we have any.  So the plan is
a fork we build against, not a vendored copy we quietly diverge with - the
point is to be able to contribute, which means staying close enough to upstream
that a patch still applies.

Not a priority.  Nothing is blocked on it: BGRABitmap does everything asked of
it so far, and the one fault we hit was ours - `BGRAColorQuantizerFactory` was
never assigned.  Worth revisiting the first time we want a change in it rather
than around it.

The one we already know we would want: **a streaming GIF writer**.
TBGRAAnimatedGif assembles the whole film in memory before writing a byte,
which is the only reason there is a frame budget at all.  A writer that took
one frame at a time and emitted it would remove the ceiling entirely and let a
recording run as long as somebody likes at any size.  That is a real
contribution rather than a private patch, so it belongs upstream.

### The recording workflow needs another pass

Tony, having used it: "the workflow for recording a gif isn't too intuitive but
it did work."  He is going to send specific notes.  Known already, and fixed on
14 September: the popup did not pan or zoom the way the drawing area does -
left-drag turned it, the wheel zoomed to the middle rather than the cursor, and
the buttons did not match.  Now middle turns, right slides, left does nothing,
and the wheel zooms 1.15 anchored on the pointer, the same as `ZoomAt` in the
drawing area.

Still open, and worth thinking about before he writes: getting to it takes
Export, then GIF, then a button - three steps before you find out it exists.
It may want to be reachable straight from the toolbar, or from the right button
on the drawing itself.

### Examples written out beside the portable exe

**Part of this is done.**  The toy etch-a-sketch is carried inside the program
as `uExample.pas` - generated by `examples/make-etch-a-sketch.pas`, same source
as `examples/etch-a-sketch.hsk` - and it opens on a run that has nothing else
to show: no drawing named on the command line and no draft to pick up.  So the
first thing anybody ever sees is a toy with a robot on it rather than an empty
sheet, and the portable build is still one file.

**And the folder is done too.**  `uPaths.ExamplesDir` is `examples` beside the
program, and it is written out on every run over the top of whatever was
there.  The file the program writes is byte for byte the file the generator
makes - the same three-line comment at the top of each - so the copy in the
repository does not churn every time somebody runs the program from the source
folder.

What is left is the rest of Tony's idea below: a folder of SEVERAL examples,
written out beside the executable so they can be opened, re-read and shown
off.  The etch-a-sketch is the first of them; the wine glass and a few
deliberately wild ones are still to make.



Tony, 13 September.  The program ships as one executable on purpose and that
should not change, so the examples have to come out of it rather than beside
it: on first run it makes an `examples` folder next to itself and writes them
out, and it does it again for any that have gone missing or been altered.
The very first run ever opens a couple of them, so somebody who has just
downloaded it sees the thing working instead of an empty sheet.

Content: the wine glass, the crown, and a handful of deliberately wild ones -
the point is demonstration, not tuition.  Worth accumulating over time, so
the list wants to be easy to add to: drawings as resources compiled in, a
table of name and bytes, and one pass that writes any that are absent or do
not match.

Two things to get right.  Altered means altered by us as well as by them - a
checksum per file, so an example improved in a later version replaces the old
one instead of being left because a file of that name exists.  And it must
never overwrite something the person has been working on: an example they
have edited and saved under its own name is theirs now, so the check should
be against what we wrote last, not against what the example currently says.

---

# Done and settled, and why it is worth remembering

These stay because the reasoning in them is the expensive part - the
measurement that settled an argument, the trap that cost a day, the thing
that looked obvious and was wrong.

### Done 13 September: faces are cut into triangles before rasterising

**Why it was needed.**  A face is a polygon and the depth of it was worked
out as a flat function of screen position - exact for a flat face, a fiction
for one that is not.  Spinning a sloped piece of an outline sweeps a warped
quad; 48 of Tony's crown's 336 faces were out of flat, the worst by five
feet.  Fitting through three corners was out by 542 feet in depth; least
squares over every corner brought it to 12; the closed-solid cull hid the
rest of the symptom.  None of that was a *fix* - it was three layers of
mitigation over an assumption that is simply false.

**What was built.**  `uTri.pas`: ear clipping with hole bridging, working in
indices into the caller's own vertex list so nothing is copied and the caller
keeps whatever the third dimension means to it.  `TArtSurface.DepthMesh` puts
a face's triangles in front of the next `FillLoops`, which clips each one to
the band of the row it is drawing and writes that triangle's own exact plane
across the pixels it owns.  The fill itself is untouched and still one call -
filling triangle by triangle would leave a pale seam along every internal
edge, each side contributing half a pixel of coverage.

Only faces that are genuinely out of flat are cut.  A flat face keeps the
single-plane path, which is exactly right and free; on the crown that is 288
faces of the 336, and every drawing made only of flat faces renders bit for
bit as it did before.

**What it measured, and a correction.**  The first harness worked out
independently which surface is nearest at every fourth pixel and compared
that with the depth buffer, and said 40.12 percent of pixels wrong before,
0.25 percent after.  That number was wrong, or rather it was measuring the
wrong thing: the harness built its reference with **the same screen-space cut
the renderer had just started using**, so of course they agreed.  Circular.
It was quoted in the v2026.09.13.13 release notes before anyone noticed.

A reference that takes no side: every warped face here is a quad, and a quad
can be cut along either diagonal - both honest, and each bends the surface
the opposite way in the middle.  What both approximate is the bilinear patch
through the four corners, so subdividing that finely gives something neither
cut can claim.  Against it, on the smooth insides of faces:

| | out by >0.05 ft | >0.5 ft | >2 ft | worst |
|---|---|---|---|---|
| one fitted plane | 12.95% | 29 | 1 | 2.04 ft |
| triangles | 27.55% | 165 | 6 | 3.66 ft |

So on that measure the fitted plane is *closer*, and it makes sense that it
would be: least squares sits between the two diagonals, and either diagonal
commits to one of them.  And counting instead how far behind the true surface
the renderer ever falls - which is the actual reported fault, a face showing
through another - the three come out level, 205 to 233 pixels more than ten
feet out whichever is used.

**So what is triangulation actually worth here?**  Not what was claimed.  What
stands up to checking is narrower and still worth having:

* a face's depth is now *exact at its own corners* rather than fitted - the
  fitted plane on the crown is out by 14.7 feet at a corner, the triangles by
  0.000000000.  That is measured directly and needs no reference.
* every pixel's depth is bounded by the corner depths of the triangle it sits
  in, so no pixel can be given a depth the face does not reach.  The fitted
  plane had no such bound, which is how it produced the 542-foot error that
  started this.
* flat faces - most of them - are bit-for-bit unchanged, so none of this can
  cost anything on ordinary drawings.
* and it is the cut STL needs, which is now built on it.

What it is NOT is a demonstrated reduction in wrong pixels on screen.  If the
blue comes back, the thing to suspect is not the depth of a face but the
ordering *between* faces, which is where the remaining large errors live and
which none of these three approaches touches.

**Still to do off the back of it.**

*Cache the cut - built, measured, and kept only where it pays.*
`TWorkDoc.FaceCut` cuts a face in its own plane and keeps the answer on
`FEditSeq` the way `GroupClosed` does.  STL uses it.  **The renderer does
not**, and that is the measured answer to what looked like the obvious saving.

It saves nothing there.  Every face in this program that is out of flat is a
quad - a revolve sweeps its outline into gores and a push does the same - and
cutting a quad is two triangles.  On the crown, the worst drawing there is for
this, keeping the cut came to 0.99 seconds over 96 views against 1.00 for
cutting every frame, where doing none of it at all is 0.92.  One part in a
hundred of a frame.

And it carries a hazard.  A cut made in the face's own plane need not still be
a cut once the camera has had its way with it: a flat face is safe, its plane
and the screen being two views of one plane, but a face that is not flat has
no plane and the two views are of points lying in none.  Over 96 views of the
crown the kept cut still held 77 percent of the time and folded over the
other 23 - triangles landing on top of each other, near ones under far.

Folding is at least cheap to catch, and the check is worth writing down in
case this comes back for a drawing full of many-cornered warped faces, where
the sums would come out differently: the signed areas of any triangulation of
a ring add up to the signed area of the ring under any linear map, so if every
triangle turns the same way then the sum of their sizes IS the size of the
face, which leaves no room for two to overlap.  One pass, and the only
question is the sign.

*STL export - done, 13 September.*  Binary, in millimetres, built straight on
`FaceCut` - which is what that cache is for, model space being what an STL is
in.  Export > "STL - for a 3D printer".  It reports how many triangles went
out and whether every solid was closed, because a slicer will happily guess at
the inside of an open shell and an hour of printing is a long time to find
that out.

Checked in the geom suite the way an STL has to be checked - not that it
parses, but that the triangles come to the surface area of the shape and to
its volume, positive, which is only true if they cover all of it and every one
of them faces outwards.  A 10x4x3 box: 12 triangles, 164 square feet, 120
cubic feet, and every stated normal agreeing with the corners written beside
it.  That last one caught a real bug - the normal was going through the
millimetre scaling with the vertices, and a normal 304.8 long is not a normal.

*Screen-space cutting and self-intersection.*  A warped face can in principle
project to an outline that crosses itself, which ear clipping has no answer
for; it would come up short and the rest of the face would fall back to the
fitted plane.  Measured on the crown: 4,608 cuts over 96 views, never short,
worst area error 1.1e-14 relative.  Not a problem in practice.

### Done 13 September: the blue faces, and they were never about depth

Tony resent the robot-and-house drawing from v2026.09.13.13 saying the blue
survived a `/rebuild`.  It did.  **That drawing has 115 faces of four or more
corners and not one of them is warped**, so the fitted plane was already exact
on it and two days of triangulation could not have touched it.  Two entirely
separate causes, both found by measuring rather than by looking.

**One: a seam divided unevenly.**  A face's back is only hidden when it
belongs to a closed solid, and closed meant every edge shared by exactly two
faces run opposite ways.  Group 6 failed that on 14 edges - and every one of
them was a T-junction.  The top of the shape had been divided into three
faces; the side walls still had the single long edge they were made with.  So
one edge on the wall met three shorter ones on the top, and matching whole
edge against whole edge saw four strangers instead of a seam.  The solid was
watertight and always had been.

`GroupClosed` now gives a failing group a second look: cut its edges at any
corner of the same group lying along them, and count again.  Groups that pass
the plain count never enter it, which is what keeps it off the cost of an
ordinary drawing, and there is a ceiling on the work so a big genuinely-broken
shape cannot turn a frame into a minute proving what the first count said.

**Two, and the bigger one: a sheet that disagreed with itself.**  Every face
the region builder makes is wound by `OrientFace`, which looks at one face and
points it along whichever axis it faces most.  That is the best a single face
can do and in company it is wrong about half the time.  On this drawing the
house's two roof slopes both came out pointing the same way in y, when out for
one of them is the opposite of out for the other, and both gable ends pointed
`+x`.  Two of the four faces pointed **into the house**, so what you saw from
outside - where people stand - was the back-face colour.

`TWorkDoc.OrientLooseShells` settles it: faces sharing an edge and disagreeing
about which way along it they run agree about which way is out, and that
settles a whole connected sheet from any one face.  Which way round the
settled sheet goes is a separate question, answered by its own volume if it
encloses one and otherwise by pointing its faces away from the middle of it -
a roof has no underside and no volume, so it takes the second answer.  Only
loose faces, and nothing is carried across an edge where three faces meet,
because there is no consistent answer there; that was the trap that sank the
first attempt at this in the morning.

It runs at the end of every `RebuildFlatFaces`, which is the answer to why
`/rebuild` never helped: **rebuild is what made them, and it wound them one at
a time.**  The house: 2 of 4 faces pointing inward, now 0 of 4.  Group 6: 13
faces now culled.  Faces with nothing protecting their backs: 20, now 7.

**What did NOT change, and should not.**  Counted over a full sweep of 96
views the total back-face colour on that drawing is the same as before, and
that is right.  A loose face has two sides and one of them is its back; you
can always walk round and look at it, and it is drawn blue on purpose, because
that is the only way to see that a face is there at all rather than a hole.
What was wrong was never that blue existed - it was that it faced the wrong
way.

**Still worth doing.**  Seven faces on that drawing are single loose faces
with no neighbour to agree with, and nothing here can help them: with no sheet
to belong to there is no "out".  If they turn out to matter, the answer is
probably to notice that they close a solid together with faces that already
exist and adopt them into it, which is a bigger idea than this one.

### Settled: a 3D engine, and whether the renderer should be one

Tony asked whether all this is wasted effort next to Castle Game Engine or
raw OpenGL, and it is a fair question.  Written down so it is answered once.

**What a GPU would genuinely give.**  Both of 13 September's faults, free:
everything is triangulated before rasterising so warped quads cannot arise,
and back-face culling is one state flag rather than a manifold test.  And
speed, on the drawings where speed is the problem: fifteen thousand faces is
160-200 ms a frame today and would be about one.

**Where it would give nothing.**  On an ordinary drawing the rasteriser is
not the cost.  A frame on the barn is 17 ms, and of the 11 ms paint handler
**0.4 ms is our own drawing** - the rest is the widgetset delivering the
expose, which OpenGL does not help with.  And what is slow on a big drawing
when it is slow is `BuildRegions` and the duplicate check, both of which are
model work and would not move an inch.

**What it would cost.**  Nothing about it is automatic.  The drafting look -
hairlines at a controlled weight, dashed hidden lines, poché, the face
material - is exactly what GPUs are worst at; lines end up as screen-space
quads and you write the shaders yourself.  The 1:1 print path renders through
the same surface at printer DPI and would need a software path anyway, which
is also the fallback for a machine over RDP or with no usable driver.

**And the proportion.**  The rasteriser is 1,578 lines against 30,269 for the
model, the tools and the window.  An engine renders geometry it is handed; it
does not decide that a closed loop of lines is a face, how push/pull cuts a
tunnel through another tunnel, what the cursor should snap to, or where a
plan is cut.  SketchUp's own renderer is plain OpenGL - the decade everybody
admires went into the inference engine and the modelling, which is precisely
the part nobody can be bought out of.

**So: no engine.**  Castle in particular is the wrong shape - a scene graph,
X3D, materials, physics, none of which a drafting program wants - though its
licence would not stop us (GPL-2+/LGPL-2+ with static linking permission and
proprietary use explicitly allowed).  If the day comes that fifteen thousand
faces has to be interactive, the door is **raw OpenGL behind the existing
TArtSurface interface**, keeping the software path for printing and for
machines without a usable one.  Triangulation is the prerequisite for that
door as well as the fix on its own merits, which is why it goes first either
way.

### Done 13 September: an export dialog, and a GIF that turns

Tony pressed Export expecting to be asked something and got a save dialog
with a list of file types in it.  Fair.  That is not an export dialog, it is
a file picker with the settings hidden inside a combo box, and it has nowhere
to ask how big, how good, or which way round.

**What it is now.**  `uExport.pas` - a room of its own: the formats down one
side, a live view of the model in the middle that you drag to turn and wheel
to zoom, and whatever that format needs to be asked on the right.  What is in
the middle is the shot; it is the same renderer at a different size.

* PNG - any size, and a see-through background for dropping onto a slide
* JPEG - the same, plus quality
* GIF - the little film, below
* SVG, DXF this-view, DXF model, STL - as before, but reachable in one press
  instead of a dropdown

Dressed with BGRAControls the way lazrandr is, through `uDlgSkin.pas`, which
reads the program's own `TTheme` rather than keeping a second palette in
step: the dialog wears whatever the drawing is wearing.  It draws its own
title bar too, because a window manager's frame in the middle of it would be
the one piece of it belonging to somebody else, which is the whole complaint
that started this.

**The GIF.**  Set the start, set the end, and it eases between the two - a
turntable spin, a slow push in, a tilt down onto a roof, or all three at
once, with no timeline to learn.  `Full spin from here` fills both in for the
common case, and `Play it` runs it in the preview before you commit.  Two
details that are not obvious: the zoom is interpolated by multiplying rather
than adding, because a push-in that goes 1, 2, 3, 4 appears to slow down as
it closes and one that goes 1, 2, 4, 8 looks even; and a loop is written one
frame short of the whole way round, because the last frame of a loop IS the
first one and sending both makes the spin catch once every time round.

**Where the code went.**  The writing is in `uShoot.pas` and the window is in
`uExport.pas`, on purpose: BGRAControls drags in half the IDE, so nothing
that only wants to save a picture should have to link all that, and the
checks in the geom suite need no screen at all.  They write real files into a
temporary folder and read the header bytes back - a PNG says its size and
whether it has an alpha channel, a GIF says its version - because the only
thing worth checking about an export is what another program will make of it.

That caught the one real bug in it: a surface is opaque unless told
otherwise, and `Clear` paints alpha 255 whatever it is handed, so asking for
a transparent background quietly did nothing until the flag went on before
anything was drawn.

**Still to do.**  Sweeping the plan-view cut height instead of the camera -
the building filling up floor by floor - which is nearly free now the frame
machinery exists.  Tony said camera only for this round.

### Done 14 September: the GIF export crash - a missing colour quantizer

Reported 13 September from Windows on v2026.09.13.16: pressing Export gives an
access violation and writes nothing.  **Not reproduced here** - Linux exports
every format cleanly, there is no wine on this machine to try the win64 build,
and no report came with it because there was no way to send one from that
dialog.

So the release after it does three things rather than guess.  The export
carries a `FStage` string through every step and a failure now reads
"EAccessViolation while drawing the picture at 2101x979" instead of nothing.
There is a **Tell Tony about it** button in the dialog itself, which hands the
whole state - format, size asked for, screen size, gif settings, the message -
to the existing `ReportFromDialog`.  And the things that were genuinely risky
were hardened: one surface for a whole film instead of one per frame (eighty
allocations and, on Windows, eighty device contexts on a long GIF), and a
check that a surface came back the size it was asked for before anything
writes into it.

Candidates ruled out by reading: the row copy in `ToBGRA` is safe against a
padded stride, since it copies the visible part of each row and both sides are
at least that wide; `FScratch` is one shared bitmap rather than one per
surface, so text is not leaking device contexts; nothing in the path touches
the widgetset from a thread.  The one that is still open and cannot be
dismissed from here is a large allocation failing quietly - which is why the
size check went in.

One more thing came out of looking: uMain carries a long comment about this
compiler generating `Field := Field + (delta) * K` wrongly at -O3 - the store
going out through the register holding the delta, so the value lands near
address zero and it faults - and a release is built at -O3.  Every new camera
line was written in exactly that shape.  They now all work the sum out into a
local first, and the three of them live in one place (`OrbitBy`, `PanBy`,
`ZoomBy` in uShoot) so there is one copy of the workaround rather than six.
Whether that is the Windows fault is unproven; it is a real hazard either way.

**The button worked, and the report had it.**  `stage=drawing the frames at
800x600`, `recorded=15.9s`, `gif=4 seconds, 20 a second`.  Two things at once:
the recording was overriding the seconds box, so 15.9s at 20/s asked for 318
frames (clamped to the 300 cap); and a GIF is assembled whole in memory, every
frame held until the last is in, with `OptimizeFrames` then duplicating each
one as it walks.  300 frames of 800x600 is 576 MB of frames before packing, on
a machine with 6 GB free and a process already peaked at 654 MB.

Three fixes.  `FilmPlan` works the frame count out from the area as well as
the length - `GIF_MAX_PIXELS`, whatever fits - and keeps the full duration by
dropping the rate instead of the ending.  Packing is skipped past
`GIF_PACK_PIXELS`, because on a turning model every pixel changes between
frames and it buys almost nothing for the largest allocation the export makes.
And a recording now writes its length into the seconds box rather than
silently overriding it.

The stage was also too coarse to be useful - "drawing the frames" covered the
drawing, the packing AND the writing.  It now names the frame and the step.

**And all of that was the wrong diagnosis.**  Reproduced on Linux in the end,
with a stack trace: `bgragifformat.pas`, inside `GIFSaveToStream`.  A GIF
holds 256 colours and something has to choose which; BGRABitmap keeps that
chooser pluggable and **naming the unit in `uses` is not enough** - the
library's own error text spells it out, `BGRAColorQuantizerFactory :=
TBGRAColorQuantizer`.  It was never assigned, so any frame over 256 colours
reached a nil quantizer and faulted.

That is why it looked like nonsense: white paper, grey faces and black lines
fit inside 256 easily, so a plain drawing exported; three anti-aliased
coloured axes over the top do not, so every export with axes on - the default
- died, whatever the length.  One line in an initialization section.

The frame budget stays, but for the honest reason rather than the panicked
one: measured, a four second spin of the crown is 410 KB at 320x240 and
1.35 MB at 800x600, and Tony's 15.9 second recording is 0.70 MB at 104 frames
with a 217 MB peak.  Fifty million pixel-frames is about 2.5 MB of file and
200 MB held while it builds.  Both livable; neither was ever the crash.

**The lesson worth keeping**: the GIF test passed the whole time because it
exported with the axes OFF, and the dialog defaults them ON.  A test that does
not exercise the default is not testing the thing people run.  The test now
does both.

Left standing: the -O3 local-first workaround, which was a real hazard whether
or not it was this one.

### Done 13 September: the GIF recorder, one room

The complaint is not that it is buried in the export tool; that is fine.  It is
that there are **two places to record**: the export dialog has Set start / Set
end / Full spin, and there is also a recording window.  And the dialog gives no
sign that the two states were ever set - a play button is not enough to tell
you there is something to play.

So the start/end business moves INTO the recording window and leaves the export
dialog entirely.  The export dialog then has a clip or it does not.

What the window wants, in his words and order:

* a **filmstrip along the bottom**, like a video editor, filling with
  snapshots as it records, so you can see there is something there.  No
  editing on it - clear and retry, nothing else.
* **Play** and **Retry**, and an **Accept** that drops back to the export
  dialog with the clip in hand.
* a **start view** with the usual choices - top, front, back, left, iso
  corners - rather than only wherever the camera happens to be.
* **canned walks** as an alternative to following the mouse.  His sketch: up,
  down, back to centre, round, and maybe up and down again at the back.  How
  far it gets through that is set by how long the clip is meant to be.
* orbiting **around the middle of the selection**, with a **starting zoom**
  you can set - and possibly the wheel setting the zoom of a canned walk
  rather than driving it live.
* centre on the selection **from the moment Export is pressed**.

Two decisions taken rather than asked, and both stood up: a canned walk orbits
the middle of the SELECTION, falling back to the whole drawing when nothing is
selected; and Accept keeps the camera path rather than encoding a GIF there and
then, so changing the size or the rate afterwards still re-renders properly.

**The piece that made it possible** is `HoldAt`.  A TProjector turns about the
world origin - there is no pivot in it - so spinning a building drawn half a
mile from zero swings it clean out of frame.  Every camera move now ends by
putting the point of interest back where it belongs, which costs one
projection and makes the whole thing behave as though it had a pivot.  The
canned walks are written against that, so they all orbit what you are looking
at.

**The four walks** are in `uShoot`, as `TWalk`: turntable, rise, the full look
(Tony's sketch - over the top, under, level, round), and push in.  Length
chooses the frame rate rather than the other way round, as asked.

Left as is, on purpose: no trimming on the filmstrip.  For a clip of five
seconds the only two useful things are keeping it and doing it again, and
handles to drag would be a worse answer than a Clear button.

### Done 13 September: OpenSCAD export

Tony's uncle asked for it, having printed the crown off the STL.

`TWorkDoc.WriteSCAD`, on the same `FaceCut` / `FaceCorners` pair the STL uses.
One `polyhedron` per group, each in its own module, so a drawing in ten pieces
arrives as ten modules and a union rather than one undifferentiated lump -
which is the difference between a file somebody can work with and a file
somebody has to re-cut.  Loose faces go out too, in `hs_loose`, labelled as
not closed, because dropping geometry silently is worse than shipping
something OpenSCAD may grumble at.

Two things that had to be right and are easy to get wrong.

**The winding is the opposite of the STL's.**  `polyhedron()` wants each
face's points listed CLOCKWISE seen from outside; STL wants anticlockwise.
Backwards, the shape previews perfectly and is inside out the moment anybody
subtracts it from anything.  There is no OpenSCAD on this machine to catch
that, so the geom suite pins it instead: it reads the emitted script back and
adds up the signed volumes the way the faces are actually written, and insists
the total comes out **negative** and the size of the box.

**Corners have to be welded.**  An STL repeats a corner for every triangle
touching it and nobody minds; a polyhedron is points AND faces, so two copies
of one corner leave a seam CGAL will not close.  A box comes out with exactly
8 points, the crown with 336, and both read back as closed manifolds.

Not done, and deliberately: reconstructing primitives.  A drawing made of
push/pull and revolves is not a stack of `cube()` and `cylinder()` calls and
guessing at which ones would be a lie in a file somebody then has to trust.
