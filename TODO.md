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

Two test suites, both green: `./tests/run.sh` (758 checks) and
`./tests/run-region.sh` (84), plus `./tests/run-cmds.sh` reading the command
table against the dispatcher, and GUI scripts driven through Xephyr.

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
  own dark colours, and `shots/NEEDED.md` listing the 25 screenshots wanted
  and what should be in each.  Tony grabs the pictures.

  **The way in is done, 14 September**: Help > The manual, and `/manual`,
  open the copy beside the program, and the release zip now carries
  `help/` - a hundred kilobytes against a fifteen megabyte binary, and a
  portable program whose help is on a website is no help on a machine that
  cannot reach one.  With no copy beside it, it opens the website.

  **On the web, 14 September**: `.github/workflows/pages.yml` publishes
  `docs/help` - and only that, not `docs/sketchup`, which is somebody else's
  documentation - to <https://tonystone31.github.io/noella-etch-a-sketch/>.
  That address is what the program opens when there is no copy beside it.

  That turned up a quiet one.  The privacy rule for the report collector was
  written `tools/` with no leading slash, so git matched a folder of that
  name at any depth, and `docs/help/tools` was one: seventeen of the
  twenty-seven help files had never been committed.  They were on disk the
  whole time, so nothing looked wrong until every tool link on the live site
  came back 404.  The rule is `/tools/` now.  Worth remembering the shape of
  it - an ignore rule meant for one folder, silently eating another.

  Left to do: the pictures, and a pass making sure the words match what the
  tools actually do now rather than what they did when the page was
  written - the eraser page was a version behind and has been corrected.
  Worth keeping honest: it is the only documentation a person who is not
  reading the README will ever see.

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


### The command list, and what is left of it

Done 14 September: typing a slash opens every command with a word about each,
typing more narrows it the way an editor's autocomplete does, and the ones
used lately float to the top.  `CMD_LIST` in uMain is the table; the order is
`BuildCmdOrder`, which sweeps twice - the ones that start with what you typed,
then the ones that merely contain it - and within each sweep puts the recent
ones first.

**Examples on the highlighted row, 14 September.**  `TCmdItem` gained an
`Eg` field: the eight commands that take something after them carry one made-up
line showing it, drawn in the mono face in place of the hint while that row is
highlighted.  The hint says what /scale is for; the example says that what
goes after it is 1/4" rather than 4 or 1:48, which is the thing somebody
opens the manual to find out.  A trailing field may be left off a record
constant in FPC, so the other fifty-nine rows say nothing about it.

The panel is capped at half the window (`PopupMaxHeight`) rather than the
whole of it.  Sixty rows from the prompt to the title bar was a wall in front
of the drawing the command is about to act on.

The wheel scrolls it (`ScrollPopup`).  It did not, and had never scrolled any
list: `pbScreenMouseWheel` was zoom and only zoom, so turning the wheel over
an open menu zoomed the model behind the menu.  Every popup in the program
had it; none of them was tall enough for anybody to notice until this one
arrived with sixty rows in a box that holds fourteen.  An open list now takes
the wheel whether or not it has anywhere to scroll, rather than letting it
through to the drawing.

One thing it still does not do, and one that used to be a risk and is not
any more:

* **Aliases are not in it.**  `/e`, `/mv`, `/tape` and the rest all still
  work and the README lists them, but the list shows one row per action - the
  primary name - because three rows of the same thing would be a worse list.
  The cost is that typing an alias does not count as having used the command,
  so it will not float to the top.  An alias column on the table would fix
  both and is about ten lines.

* **The table is written by hand and RunCommand is the truth - guarded, 14
  September.**  `tests/run-cmds.sh` reads both out of uMain.pas and fails if
  the table offers a name the dispatcher does not answer to, if the declared
  bound does not match the number of entries, or if the list has fallen out
  of alphabetical order.  It reads the source rather than asking the program,
  which avoids having to give RunCommand a "do you know this word" mode for
  the sake of a test; the cost is that it only knows the plain `W = 'x'`
  comparisons, so a command dispatched some cleverer way would have to be
  taught to it.

  It deliberately does not check the other direction.  The chain is full of
  aliases and debugging words that are not offered on purpose.

  It also checks the examples: every row flagged as wanting an argument has
  one, and every example is that command with something after it.  A Pascal
  string doubles its apostrophes, so the test undoes that before reading -
  `4''6"` in the source is `4'6"` on the screen, and the first version of
  `/cut 0 9'` had one apostrophe too many and would not compile.

  **What it still cannot see is a name going stale.**  Follow Me was renamed
  REVOLVE on the sixth of September - on the tool strip, in the tooltip, in
  the manual - and the command list went on offering `/followme` and no
  `/revolve` at all for a week.  Every check above passed the whole time:
  `/followme` was a name the dispatcher answered to, it was in order, it had
  no argument.  Nothing ties a row to the tool it names, and the only reason
  it was caught is that Tony remembered what we called it.  Tying TOOL_NAMES
  to the rows that set a tool would catch exactly this and is worth doing if
  another one slips.

### Snapping has to answer "can I see it?", and half of it did not

Tony, measuring along the straight edges of the etch-a-sketch between the
curves: it kept taking lines behind the toy, or on the wrong plane.  He asked
whether it was the tool or the model.  It was the tool, twice, and the model
made both worse without being wrong itself.

**EdgeSnap never asked whether an edge was visible.**  BestSnap has rejected
hidden points since somebody got pulled onto the corner of a tunnel through
the wall they were drawing on; EdgeSnap took whichever segment came nearest
on screen and nothing else.  Measured on a plain solid box from a corner
view: 633 of 2266 cursor positions - better than a quarter - returned an edge
behind the box.  Now none do.  `HiddenAt` is only asked of a candidate that
would win, so it costs nothing when the view is clear, and a face the point
lies in cannot hide it, so an edge on the face it bounds is safe.

**And there was no rule for a tie.**  Two edges a hair apart in depth land on
the same pixel, and the answer was whichever came first in the entity list -
an answer about drawing order, not about what is under the cursor.  Within a
pixel, the nearer to the eye now wins.

The model is clean - 177 lines, no duplicates, none zero length - but it is
built of exactly the geometry that makes both faults bite: 144 lines at
z=0.1042 and 33 at z=0.0942, a tenth of an inch apart, so the case lip and
the screen recess are on the same pixel at any working zoom.  A good example
drawing turns out to be a good test drawing.

### The view, and two things that were quietly bounded

Tony, comparing against SketchUp: it zooms in and out a great deal further
than us, and its axes go on for ever while ours end.

**Zoom was a twentieth to forty times** - eight hundred to one, which sounds
generous and is not: at forty times a sixteenth of an inch on an inch-to-the-
foot drawing is a couple of dozen pixels, enough to see and not enough to
work on.  `ZOOM_MIN` and `ZOOM_MAX` are 0.002 and 2000 now, a million to one.
Bounded rather than free, because every point on the screen is OX + dot * Ppu
and those numbers have to stay somewhere the rasteriser and the depth mesh
can work.

Widening it broke two readouts that had never had to cope, and both were
worth finding: the percentage printed with no decimals, so anything under a
fiftieth read "view 0%" - a readout that says nothing while looking like an
answer - and the scale bar's table of round lengths began at half a foot, so
past a few hundred percent there was nothing short enough and the bar ran the
width of the window labelled 0'-6".  The table now runs from a sixteenth of
an inch to a thousand feet, and the short end is exact inch fractions rather
than round decimals, because a bar of 0.002 feet is a fine length that reads
0'-0" on its own label.

**The axes were drawn a fixed number of world units from the origin** - a
screenful, more or less.  Fine while the origin is in view, wrong the moment
you pan away from it: they stopped in mid air.  They are infinite lines, so
`ClipToBox` now finds the stretch of each that crosses the paper and draws
that, solid forwards and dashed back, whether or not the origin is anywhere
near the window.

The clipper got its own test, and earned it: the first version had each
edge's entering and leaving ends swapped, which clips every line to nothing
and reads on screen as the axes simply being switched off.

### The surface guard fired again, with a number worth keeping

From Tony's report of 15 September, alongside the dimension fault:

    surface guard hit: 4616275354042910992 (as a double 4.07615),
    stride untouched
    ... repairs=1

That is the canary in TArtSurface catching something that wrote over it.  The
note beside `Verify` in uSurface says a guard or stride carrying a plausible
double "names the culprit", and this one reads as **4.07615** - a number that
looks like a zoom or a coordinate rather than noise.  The drawing's zoom at
the time of the report was 28.625, so it is not the current one; an earlier
one, or something else entirely.

Two details worth having: only the GUARD was hit, the stride was untouched,
so whatever it was landed on one field rather than running through the
record; and it happened at 13:50:25, in the same moment as "opened the
example", which is where a surface is being resized.

Not chased.  It is a known open hunt with its own notes in uSurface, it did
not crash, and the repair put it back.  Recorded because the previous
sighting is the only other data point there is, and two numbers are worth
more than one.

### Every picker needs the same audit, and it is bigger than "is it hidden"

Tony, after the EdgeSnap fix: run these checks over all of the tools and
inspect the code, because snapping a line, snapping a point, and snapping a
point ON a line are three different questions and there is a lot of inference
behind each of them.

He is right, and the EdgeSnap bug is the argument: the rule it was missing
had been written down and tested in BestSnap for weeks, twenty lines away,
and nobody had asked whether the line version needed it too.  These grew one
at a time as tools were built, and nothing has ever gone over them together.

**A third fault, found the same day and the same way.**  Tony could dimension
the robot and the lettering on the toy and not the case they sit on.  The
case is ONE FACE of thirty-two corners, longest edge ten and a half inches,
with no line entities at all; the robot and the letters are drawn with lines.
EdgeSnap walked lines, guides and arcs and never a face outline, and the snap
cache recorded a face's middle but not its corners - so along the whole of
that edge there was nothing to find, and the cursor took whichever line ran
nearest, a fifth of an inch away.  That is the "fighting me" feeling exactly:
not nothing, just never the thing you are pointing at.

Both are fixed, the corners deduplicated against the lines that already cover
them so a face drawn the ordinary way does not double the snap list.  It is
the third instance of the same shape of bug in one day: a rule that was
written down and tested in one picker and never asked of its neighbour.

**The pickers, none of them checked:**

* `DoomAt` - what the eraser gathers.  Can it take an edge behind a solid?
* the face picker - `FHoverFace`, and what push/pull and drill act on.
* the note picker - `FNoteDrag`, and what a click on a note takes.
* `AxisSnap` - the three axes are infinite lines and are never hidden, which
  may be right and has never been said out loud.
* the selection box - does a right-to-left box take things it cannot see?

**The questions to ask of each, which is the part that is bigger than one
bug:**

1. *Can it see it?*  The EdgeSnap fault.  `HiddenAt`, on the candidate that
   would win.
2. *What breaks a tie?*  Two candidates on one pixel: nearer the eye, or
   whichever was drawn first?  EdgeSnap had no rule at all.
3. *What beats what?*  A point beats a line beats an axis beats a guide, and
   the reach of each is different - LOCK_PX, EDGE_PX, SNAP_PX, the shorter
   reach a piece-midpoint gets.  Written in ResolveSnap and nowhere else.
4. *What holds?*  FStick - taken from close in, released from further out.
   Only points stick; should a line?
5. *What does it say it did?*  Every snap sets FSnapKind and the status
   reads it.  A snap that cannot be named cannot be trusted or reported.

Worth doing as one pass with one test file, the way `TestEdgeSnapSeesOnlyWhatIsVisible`
is written: walk a grid of cursor positions over a solid and assert the
invariant, rather than testing one aimed click.  That is what found 633 bad
positions out of 2266 - no aimed test would have.

### Edges that cross have to end there - 15 September 2026

Tony: "this is how i make rounded corners in a rectangle.  i use the circle
tool and temporary lines.  in sketchup i would be able to remove all of those
lines individually because the circle would have broke the lines making the
point."

He is describing the standard way a fillet gets drawn and the standard reason
it works: in SketchUp a new edge and everything it crosses cut each other as
it lands.  We had half of it - `AddLineSplit` cut a line drawn *along* one
already there - and none of the other half, a line drawn *across* one.  So
the rectangle's side stayed one line corner to corner, the circle stayed one
closed loop, and there was nothing to rub out but all of each.

`SplitCrossings(FirstNew)` does it, called by the line, rectangle, arc and
circle tools with the entity count taken before the tool added anything.
Only loose drawing takes part - nothing in a solid, no guides, no dimensions
- and a pair is only looked at when one of the two is newer than FirstNew, so
nothing already drawn is quietly rewritten around somebody.

**Two things learnt doing it, both worth keeping:**

*Arcs are walked as they are drawn, not as circles.*  A crossing is worked
out against the segments the renderer actually walks, so what counts as
crossing is what the eye sees crossing.  A piece keeps its share of the
sides, which puts the pieces' corners back on the whole one's whenever the
cut landed on a corner - and a tangent always does.

*A tolerance in parameter is not a tolerance.*  The first version threw away
cuts within 1e-7 *of the parameter* of an end.  On a hundred foot line that
is ten microns and on a one inch line it is a nanometre, so near-tangents
left slivers, and the slivers were themselves crossed by the next pass: three
passes over the same drawing broke 7, then 2, then 1 edge.  Measured along
the edge instead, and the hit pulled onto the segment corner it is really at,
it is 7, then 0, then 0.  **Idempotence is the test that found this** - run
the pass twice and the second one must do nothing - and it is worth having
for any geometry that rewrites itself.

**Still open, from the same message.**  "i should be able to use the arc tool
but when i did it kept the arc out side the rectangle."  `ArcPicks` takes the
bulge as the third pick's offset from the chord, signed, so it should follow
the cursor to either side; `Bulge := Ln / 8` when the cursor lands exactly on
the chord is the one branch that picks a side on its own.  Not reproduced -
needs the two points he picked and where he moved.

### The frame watchdog is in - 15 September 2026

Tony: "yeah we need the frame watchdogs for bug reports for sure."  Step one
of the order agreed above, and done.

Every frame is timed in four parts, each accumulated where the work actually
happens rather than at the call sites: `RepaintPaper` the paper, `RenderPro`
the ink, `RecomposeAll` one over the other, and `pbScreenPaint` the screen.
Accumulated **since the last paint**, so a frame that rendered three times
before it was shown counts all three - which is the frame the person waited
for, not the one the code thinks it drew.

`NoteFrame` is the whole of it.  Over forty milliseconds - twenty-five a
second, where a drag stops feeling attached to the hand - and it writes one
line into the session log with the breakdown and the context: which tool, what
stage, how much is picked, how many things, what zoom, and whether the camera
was moving.  At most one line every two seconds, because a slow drag is slow
for every frame of it and thirty identical lines would push everything else
out of a log thirty entries long.  The count and the worst are kept whole and
go in the report's state block, so a report that says nothing about speed
still carries the number.

**What to do with it.**  The next few reports should say whether the
suspicion above is right.  If the slow lines come with `PUSH/PULL` or `DRILL`
and a big `things=`, it is `PaintFaceHint` and the scanline fix is the
answer.  If they come with `moving` and a high zoom, it is the paper and the
composite and dirty rectangles are the answer.  If they come with neither,
the guess was wrong and the log will say what to look at instead - which is
the point of building it before the fixes rather than after.

### The tape's third stage, which was two bugs wearing one coat - 15 September 2026

Tony: "yeah look at all the weird shit that keeps happening.... the tape
measure leaving phantom lines after a while... switching to the select tool
and selecting something seems to clear it.  the stupid dimension appearing
with using a tape measure tool  very buggy bull shit.  hopefully you can
track the last 30 things i did in this bug report and find some issues."

The session log did it, and the two complaints were one cause.

The tape had three stages.  The second click laid the guide and moved it to
stage 2, where it **stayed**.  Two things followed:

* The painter drew `Rubber(FP1, FP2)` at stage 2 as well as the live band at
  stage 1, so the run it had just measured stayed on the screen, attached to
  nothing, until something took the tool away.  **That is the phantom line,
  and it is why switching to Select cleared it.**
* `ProCommit` at stage 2 called `AddDim`.  `ProCommit` is reached from Enter
  *and from Space* - and Space everywhere else in this program means "done".
  So finishing a measurement and pressing the key that means finish dropped a
  dimension.  The log's last line is exactly that: `commit MEASURE stage=2`.

The hint line did say "Enter keeps this as a dimension", so it was not
undocumented - it was a waiting stage with a destructive key on it, which is
the same shape as the right-click menu note about a destructive row arriving
under a hand aiming at a harmless one.  A tool that has finished should be
finished.

Now the second point ends the tape, and keeping a run is `/keep`.  A command
cannot arrive by accident, and the list shows it to anybody looking.

**The general lesson, and the test that goes with it:** a tool stage that
nothing forces you to leave will eventually receive a keypress meant for
something else.  The question to ask of a stage is *does it track the
cursor?*  One that does is live - what Enter commits is what you can see, and
that is every drawing tool.  One that does not is waiting, and a waiting
stage with a destructive key on it is a trap.

**Checked the other stage-2s while this was fresh**, and the tape was the
only one: `PaintDimPreview` reads the live mouse through `DimOffset3`,
`PaintRevolvePreview` reads `FCur`, and rotate and the protractor both swing
with the cursor.  All live, all fine.  Nothing else to fix - worth writing
down so the next person does not have to look again.

### The guides, read against their help rather than remembered - 15 September 2026

Tony: "yeah read the docs so we can behave almost identical to sketchup
guides... what we have now is pretty darn good just not perfect and i like
where we are better such as having the yellowish guide point.  in many ways
we are better than sketchup but in the critical ways sketchup kicks our ass."

Fetched https://help.sketchup.com/en/using-guides again, and it answers the
two things he could not make sense of:

* **"i am not sure how and when sketchup decides to have their points make
  the long dashed lines or when it just drops a point."**  It does not
  decide - you do.  Ctrl toggles the tape between Create Guide Line mode and
  Create Guide Point mode, and the cursor icon says which.  A guide point is
  a click anywhere; a guide line needs a distance off an entity.  There is no
  inference in it, which is why watching for one made no sense.
* **"sketchup eraser will not erase its guide points."**  Their help says it
  does: "Click a guide line with the Eraser tool", plus select-and-Delete,
  context-click Erase, and Edit > Delete Guides for the lot.

And a third thing it settles: SketchUp does **not** leave a point behind when
you measure.  Ours does, both every time, and that is ours alone - the thing
he says he likes better.

**Fixed now:** a guide line takes the point laid with it when it is rubbed
out, which is what he asked for and what the two being one gesture implies.

**Still open, and the real question underneath his confusion:** ours lays
both every time, theirs lays one or the other from a mode.  The Ctrl cycle
was in ours once and was taken out - `LayGuide` still has the note saying so.
Worth putting back now that there is a reason: he wants a 1" mark on a line
without a dashed line running the width of the drawing, and that is exactly
what guide-point mode is for.  Default stays both, because he likes both.

**Not explained:** "a couple times while trying to erase the yellow guide
points with the eraser tool it actually ended up drawing a dimension off it."
Nothing in the session log shows the dimension tool being picked at all
between the erases, and there is no path from the eraser to it.  Needs the
gesture, or a session that catches it.

### The watchdog earned itself back on its first day - 16 September 2026

Tony: "oh there is a glitching and freezing issue happening and i hope our
logs capture it.  look this over please."

They did, and the report answered it without a single question back:

    frames: 189 over 40ms, worst 1984ms, last was
    1890ms (paper 0, ink 0, over 0, screen 1890)
    RECT stage=1 sel=1291 things=1291 zoom=115%

Paper nought, ink nought, composite nought.  **All 1890 ms in the canvas
paint**, on a drawing of 1291 things with all 1291 of them picked, every
frame, for six minutes of log.

**It was not the arithmetic.**  The first guess was `HiddenAt` falling back
to its slow path - it walks every face when there is no depth buffer to ask -
and that guess was wrong: loading his drawing headlessly, rendering it, and
making the same 32,275 `HiddenAt` calls takes **10 ms**.

It was the **LCL canvas calls**.  The selection overlay traced each picked
entity against the depth buffer and drew each visible run with `C.MoveTo` and
`C.LineTo`, plus a pen change per entity.  1845 runs.  **1890 ms / 1845 runs
is a millisecond each** - that is what a short line costs through gtk3 and
cairo.

The same overlay drawn into one of our own `TArtSurface`s: **20 ms**.  About
ninety-five times, and then cached on the selection, the camera, the edit and
the size - so a still selection costs nothing at all after the first build.
`EnsureSelLayer` already existed and did exactly this for selections over
three thousand; it now does it for every selection, with the depth tracing
moved into it so nothing is given up.  The 3000 threshold stays, but only to
decide whether to *trace*: past it the edges are outlined plainly, because an
orbit with thirty thousand picked rebuilds the layer every frame.

**The lesson, and it is a general one.**  A millisecond per canvas line is
the number to remember.  Anything that draws hundreds of short strokes or
single pixels straight onto a `TCanvas`, every frame, is a freeze waiting for
a big enough drawing.  Ours are all in the overlay: it is the one place that
paints on the canvas rather than into a surface, and it was written that way
because a canvas is the easy thing to reach for.

**The one to look at next, unmeasured but the same shape.**
`PaintFaceHint` - the stipple under push/pull, the drill and the offset -
writes `C.Pixels[X, Y]` per dot, every other pixel of the face's bounding
box.  On a face covering a big window that is a hundred thousand or more
single-pixel canvas writes a frame.  The scanline change earlier today cut
the *deciding* by five hundred times but left every one of those writes where
it was.  It did not show up in this report because he was drawing a
rectangle, not hovering a face.  Draw it into a surface like the selection
and the question goes away.

### The drive suite, which had got too slow to run - 16 September 2026

Tony: "These tests take forever.  Anyway we can run like 10 of these tests at
once or merge some of them so we aren't restarting the entire thing all the
time?"

He is right, and it matters more than it sounds: a suite that takes ten
minutes stops being run, and the drive suite is the only thing that catches a
crash on the way through a real tool.

**Where the time actually was.**  Worth measuring before changing anything -
the headless suites were never the problem:

| | before |
|---|---|
| `run.sh`, 927 checks | 1.6 s |
| `run-region.sh`, 91 checks | 0.8 s |
| `run-drive.sh`, 28 scripts | nine and a half minutes |

So all of it is the drive suite, and it is two separate costs.

**One: every launch paid for the start-up screen.**  `SPLASH_MIN_MS` is four
seconds, and it is four seconds *on purpose* - a window that flashes and is
gone looks like something went wrong.  That is right for a person and wrong
for a script, and we were paying it twenty-eight times a run.  There is now a
`--no-splash` switch, documented under `--help` like the rest.

The six-second sleep that followed it went too.  It was a guess covering the
splash plus slack; now the runner watches for the window title, which does
not appear until the drawing named on the line has been read.  **20.4 s to
16.2 s on a single script**, and no guess left in it.

**Two: they ran one at a time.**  Nothing is shared between two scripts -
each already gets a copy of the program and a folder of its own, because of
the draft and the lock - so the only thing stopping them was the display
number.  Each run now claims a free one with a `mkdir`, which either succeeds
or does not, so two starting together cannot both take `:9`.  Sockets and
lock files are checked first, so a lane can never land on the display the
person at the machine is sitting in front of.

**Measured, all 28 scripts, all green both ways:**

| | |
|---|---|
| one at a time, as it was | about 9 m 30 s |
| one at a time, with the start-up fix | **7 m 28 s** |
| four lanes, with the start-up fix | **1 m 57 s** |
| six lanes, with the chains | **2 m 02 s** |

The first of those three is the only one not measured directly: the old
`tools/xephyr.sh` is not in git - `tools/` is ignored - so it is the
measured 7 m 28 s plus the 4.2 s a script demonstrably stopped paying,
twenty-eight times.  The other two are stopwatch numbers.  **Call it five
times faster.**

**The first version of the claim burned every display on the machine**, and
it is worth writing down because it looks so reasonable.  It treated
`/tmp/.X<n>-lock` and the socket in `/tmp/.X11-unix/` as proof that a display
was in use.  They are not.  Any X server that goes down hard leaves both
behind, nothing ever tidies them up, and `kill -9` - which this script used
on Xephyr - guarantees it.  One interrupted run left `:9` through `:49`
littered, and after that nothing could start a nested display at all, this
suite included.

Two changes, and both were needed.  **In use now means a server answers**
`xdpyinfo`; a stale lock is reclaimed by the next Xephyr that wants it, which
is behaviour X has had all along and I had not checked.  And the server is
now asked to go with a TERM and only shot if it will not - a server that
exits properly takes its own lock and socket with it.  Checked both ways: a
stale lock *is* reclaimable, and TERM *does* clean up.

The mkdir claim stays.  Answering and then taking is still two steps.

**What it cost.**  The scripts wait in wall-clock milliseconds, so a lane
starved of processor can miss a wait that would otherwise have been long
enough.  Rather than pretend that away, a failure is now retried once on its
own - which is exactly what a person does with this suite by hand, and what
the note in CLAUDE.md told them to do.  The retry says `second try` rather
than hiding it, and a script that fails twice prints what the program itself
said.

**Chained after all, for a better reason than speed.**  I argued against
merging scripts into one launch on the grounds that state would leak from
one into the next and turn a clear failure into "something earlier did
this".  Tony: "some of the tests we could conduct together in a single test
instance rather than always starting a new instance as that will also
sometimes reveal additional bugs."

He is right and the objection was backwards.  **The leak is the test.**
Every script in this suite has only ever run against a program that just
started: no tool used before it, nothing on the clipboard, no other sheet
open, no undo behind it, every setting as it came.  Nothing in the suite has
ever asked whether the *fourth* thing you do still works - which is the only
way the program is ever actually used.

Three chains, grouped so that a failure says something: `commands`, `views`,
`tools`, five scripts each.  Between members: escape twice to drop whatever
tool or dialog the last one left, then `/new`.  A new sheet, not a new
program - settings, clipboard, the other sheets and their undo all stay.  By
the fifth member there are five sheets open, which no single script reaches.

**When a chain fails its members are run again one at a time**, and a member
that passes alone is reported as a finding rather than a flake: something
before it left state it could not cope with.  That is the sentence the whole
arrangement exists to be able to print.  `SOLO=1` takes the chains apart.

**All three passed first time**, which is worth saying plainly: the chains
have not caught anything yet.  Verified they are not quietly doing nothing -
every member's screenshots were freshly written, 34 of them in the `tools`
chain alone.

**They cost wall clock.**  Sixteen units balance worse across the lanes than
twenty-eight did, and a chain is a long pole that cannot be split: 1 m 57 s
without chains, 2 m 23 s with them at four lanes.  Six lanes gets it back to
2 m 02 s, and six is safe here - the whole suite uses about a minute of
processor across two minutes of clock on a thirty-two core machine, so the
lanes are asleep nearly the whole time.  Six is the default now.

**Where the floor is now.**  The scripts contain **295 s of deliberate
`wait`** between them - a third of it in six scripts, `gif-loop` alone
holding 22 s because it really is recording for that long.  Four lanes puts
that at about 74 s, and the measured run is 117 s, so the suite is close to
what its own waits allow.  The next lever is the waits themselves: a good
number of them are round and generous rather than measured.  That is a
careful job, one script at a time, since each one is there because something
needed settling - and it is the only lever left that is worth much.

### The borrowed depth buffer, and the crash after an export - 16 September 2026

The freeze fix went out and the very next report came back with the numbers
proving it worked and an `EAccessViolation` sitting on top of them:

    frames: 119 over 40ms, worst 360ms, last was
    125ms (paper 30, ink 63, over 0, screen 32)

**Screen 1890 down to 32.**  That part is settled.  The exception was
something else, and Tony gave the steps: "the exception happened after i
exported the gif then click in the canvas".

`TWorkDoc.LastSurf` is the last surface the document rendered into.  It is
kept **borrowed, not owned**, because that surface's depth buffer answers "is
this point hidden" in one lookup instead of a walk over every face - the
difference between a hover being free and being the cube of the drawing.
Borrowing is the right call here.  A borrowed pointer outliving the thing it
points at is not.

The GIF export makes its **own** surface, at the size it is saving rather
than the size of the window, renders every frame into it, and frees it.
`LastSurf` was left pointing into freed memory, and the next question the
canvas asked - a hover, a snap, the selection outline - read it.

**The fix is not in the export.**  The export could clear `LastSurf` on its
way out, and that would hold until somebody writes the next exporter and does
not.  There are already **six** places that make a surface, render into it
and free it: the animation, the single shot, the print preview, the recorder
and two contact-sheet paths.  So the surface announces its own death -
`WatchSurfaceGone` in `uSurface.pas` - and `uWork` registers a watcher that
nils `LastSurf` on any document that was borrowing it.  Six sites fixed by
one, and the seventh is fixed before it is written.

The document falls back to walking the faces until the next render, which is
slow and correct, and the next render borrows again.  A flag, `LastSurfDied`,
rides along in the report's surfaces line, so if this ever shapes up
differently the report says it happened.

**The shape of it, which is the one that keeps coming back** (this is the
seventh): *a rule learnt in one place and never asked of its neighbour*.
Here the neighbour had not been written yet.  The answer each time has been
to move the rule to where it cannot be forgotten rather than to remember it
harder.

### Four done on 16 September, in the order agreed

**Closing a modified sheet did not ask to save - DONE.**  The guard was
there; it asked the wrong question.  `FEditSeq` against `FSavedSeq` is one
pair for the whole window, and `LoadExample` - which is what a new sheet
calls - ends by setting them equal so the example's three hundred things do
not count as your work.  So a new sheet marked every OTHER sheet saved, and
closing a sheet you had drawn on went without a word.

Now `TDrawing.Dirty`, set where every edit already funnels through, cleared
by a save (all sheets - a save writes the whole file), by a load, and by
`LoadExample` on the sheet it filled and no other.  The window gained an
`OnCloseQuery`, which it never had: closing the program with work on a sheet
asked nothing at all, survivable only because the draft brings it back, and a
safety net nobody can see is not the same as being asked.  `close-asks` in
the drive suite covers both halves - a sheet with work asks, a sheet nobody
touched does not.

**Copy and paste - DONE.**  Ctrl+C, Ctrl+X, Ctrl+V.  `CopyOut` takes a deep
copy detached from the document, which is the whole design constraint: by the
time it is pasted, the sheet it came from may not be in front and may not
still exist.  `PasteIn` puts it back with the group ids remapped, so a pasted
solid is its own solid - otherwise push/pull could not tell the two apart and
pulling a face on one would deform the other.  Bores are dropped; an ekBore
is the record of a tunnel through a particular solid and means nothing beside
a copy of it.  A paste hands straight to the move tool the way a built
fitting does, so it arrives on the cursor and a click puts it down.

Found on the way: `Duplicate` - the Ctrl-copy in the move tool - shared each
face's openings with the original and never offset them, so a copy of a face
with a window had the window in the wrong place and in the original's array.
The same crack `CopyEnt` had yesterday, twenty lines away.

**PaintFaceHint, a row at a time - DONE.**  The suspicion below was right
about the shape of the work if not yet proven to be the cause: it asked "is
this dot inside" for every other pixel of the face's bounding box, with a
divide per outline edge.  A face covering most of the screen with the toy's
thirty-two-corner case outline is four million divides **per mouse move**,
and only while a tool that hovers faces is in hand.

A scanline asks once per row instead - where does this row cross the
outline - sorts the crossings and fills between them in pairs.  Two hundred
and fifty rows times thirty-eight edges: about five hundred times less.  The
windows come free, because their edges go in the same crossing list and the
even-odd rule leaves a hole wherever a window brackets the row.

**One walk instead of three - DONE.**  Item (d) of the performance list.
`PickAt` worked out the edge, the face and the general hit test and then
chose between them, so every mouse move over a drawing cast a ray at every
face whether or not the cursor was on an edge; it stops at the first answer
now.  And `FaceUnder` remembers its last answer, keyed on the pixel, the
camera, the slice and the edit sequence - because one mouse move asks it for
the stipple, then again for the snap, then a third time on the click.  The
memo has its own test: the part worth proving is that it is forgotten by an
edit, by the camera moving, and by the slice changing.

**Still to measure.**  Whether any of this shows up in the frame watchdog.
The next report with slow lines in it is the answer - and if they still come
with PUSH/PULL and a big things= count, the stipple was not the cause after
all and the log will say what is.

### Two asked for on 15 September, both now done

**Closing a modified sheet did not ask to save.**  Tony: "I recently had
another modified drawing and I closed its tab sheet and was not asked to save
it.  This was several versions ago so we will want to test that all again in
the next future."

Losing work without being asked is the worst class of bug this program can
have, and the drive suite has nothing that covers it.  Wanted:

* a check that closing a sheet with unsaved changes asks;
* the same for closing the window with several sheets open, one of them
  dirty;
* and the same for /clear, which throws a sheet away.

Worth writing the drive script first and seeing whether it still reproduces -
it may already be fixed, and a test that proves it is worth having either
way.  Note that the draft written beside the program means the work is
usually recoverable, which is exactly why this could go unnoticed for
versions.

**Copy and paste.**  Tony: "we need to be able to copy and paste a selection
and copy and paste from one sheet to another etc."

Ctrl+C and Ctrl+V are not bound to anything.  What exists already and does
most of the work: `Duplicate(Idx, D)` copies entities with their groups
remapped, and the move tool's Ctrl-copy uses it.  What is missing is a
clipboard the copy can sit in between the two gestures, and the
sheet-to-sheet case needs it to survive a `TDrawing` change.

Shape it as: Ctrl+C takes a deep copy of the selection into a form that does
not reference the document it came from; Ctrl+V drops it, picked, with the
move tool live so it can be placed - which is SketchUp's Paste In Place
behaviour and saves inventing a rule for where it lands.  Across sheets it is
the same code, because the copy does not point at the old sheet.

## Where this is going, agreed 15 September 2026

Tony, after an evening of comparing: "SketchUp is way smoother and crisper
moving than us when orbiting and the snapping behavior is so much more
refined than us.... We are sort of close but not good enough.  I'm thinking
we spend the next week or so working out the details and bugs in tools and
then we will end up doing some performance evaluations."

And, worth keeping because it is the actual brief: "I open SketchUp to
compare and honestly I mess with theirs after using heckers sketch and I get
the feeling of wow ours is a piece of shit!  I actually love what we are
building.  We just need to keep after making little improvements."

### The order, and why

1. **A frame watchdog, first.**  `Took()` and `/timings` already exist; log
   any frame over about 40 ms with its phase breakdown into the session log.
   Then every bug report for the next week carries its own diagnosis instead
   of "it felt glitchy".  Tony on the symptom: "we some times have clumsy
   things when moving around with tools selected at times where it seems the
   program is struggling or stuck in some loop for some reason and then you
   try to orbit and it glitches.... Hard to pinpoint when and why."
2. **The tools: details and bugs.**  The week's work.  The picker audit
   below is most of it.
3. **`PaintFaceHint`, scanline instead of per-dot.**  See the suspicion
   below.
4. **Dirty-rectangle compositing.**  The measured 19 ms.
5. **The entity window.**
6. **Re-measure, and only then ask about OpenGL.**

### What the frame actually costs, measured

Same drawing, same view, v2026.09.14.10 against HEAD:

* **25.7 ms a frame, both.** No regression, whatever it felt like.
* Of that, **about 6 ms is the model**.  The other 19 is the full-screen
  paper repaint and the composite.
* Quick frames (23.7 ms) only accelerate the model part, which is why they
  barely help.
* Cost climbs about 5x with zoom - 3.4 ms at 100% to 16.5 ms at 4000%,
  saturating there.  His report had him at 2863%.
* The snap path, measured properly with a depth buffer: **0.033 ms**.  Not
  the problem, and the 22x regression an early run of that benchmark reported
  was the benchmark's fault.

Three quarters of a frame is paper and composite and neither depends on the
model at all.  That is a CPU fix - do not repaint paper that has not changed
- and it is worth more than a renderer swap, which would move that work
rather than remove it.

### The suspicion about "clumsy with a tool selected"

`PaintFaceHint` - the stipple under push/pull and drill - tests every other
pixel of the face's bounding box with a point-in-polygon loop over the whole
outline.  On a 1137x606 screen with a face covering most of it that is about
125,000 dots times the number of points in the outline, each with a divide.
Four points: half a million divides.  The toy's case face has thirty-two:
four million, **per mouse move**, and only when a tool that hovers faces is
in hand.

Not proven to be the cause and worth measuring rather than assuming - but it
fits the symptom exactly, and the fix is standard and bounded: scanline the
polygon once per row rather than asking per dot, which is roughly five
hundred times less work.  Note that the holes and depth checks added on 15
September made it slightly heavier, not lighter.

### OpenGL: the path is intact, and it is not next

Tony: "I really wanted to avoid opengl... I hope we aren't too far off and
still have a path to using opengl some day.  It seems like it would be a big
rewrite but also it seems a lot of our code will be reused... But still I
don't think that is truly our issue anyway."

Right on both halves.

*Reused unchanged:* `TWorkDoc`, `uRegion`, the whole snap and pick system,
`TProjector`, every tool state machine, every exporter.  All view-independent
CPU geometry that does not care how pixels are made.

*Replaced:* `TArtSurface` - the BGRA rasteriser, the SDF anti-aliasing, the
per-pixel z-buffer - and the composite.  One unit behind a narrow interface,
which is what makes an incremental backend genuinely possible rather than
wishful.

*The catch nobody should discover late:* the look is hand-built.  The
anti-aliased line quality and the paper-and-ink aesthetic would have to be
redone in shaders and "close enough" there will be a fight.  The toy's
surface is its own problem again.

### The entity window - DONE 16 September 2026

Built, docked right, `/info`.  It was as cheap as the note below said: the
properties were all there and so were the setters, and what took the time was
the panel itself - a paint box down the right, a list of rows the painter
reads and the mouse searches, and a rebuild on the tick rather than at every
place the selection is touched (two of those are bulk loops over fifty
thousand things, and a rebuild inside them would cost more than the panel is
worth; a sixteenth of a second behind is not behind).

Editable in this first cut: **sides** on a circle or an arc, which is the one
Tony asked for outright and which was previously a before-you-draw-only
setting; **soften** on a line or an arc; **size** on a note; **reverse** on a
face or on several.  Deliberately not editable with more than one thing
picked - a stepper that acted on nine things at once is a way to lose nine
things.

**What SketchUp's own Entity Info does, checked 16 September**, because Tony
asked and because guessing at this has cost us twice this week:

* **Length on an edge: yes, editable.**  "You can adjust the length of a line
  in the Entity Info dialog box by context-clicking the line and choosing
  Entity Info from the menu, then typing a new line length in the Length
  box."
* **Which end moves: not documented anywhere I can find**, on their help or
  in the panel description.  So there is no convention to copy and we get to
  choose - and having chosen, we have to say so in the panel, because a
  length box that moves an end without telling you which is worse than no
  length box.
* **Colour: yes**, as a *material* - the panel shows and sets the material on
  an edge or a face.
* **Per-edge thickness: no.**  SketchUp has no such thing.  Line weight there
  is a **style** applied to the whole model (and a LayOut setting for
  drawings).  Our `Weight` is per entity, so on this one we are already doing
  more than they are, not less.
* It also carries the tag/layer, hidden, locked, and cast/receive shadows -
  none of which we have, and only "hidden" is one we have talked about
  wanting (see the eraser's Shift, in Smaller things).

**On the LINE COLOR button along the bottom.**  Tony: "that may be one more
button we could get rid of... But maybe not.  Those are sort of the default
settings and I like it for the most part."

Keep it.  The two controls do different jobs: the bottom row sets **what the
next thing you draw will be**, and the entity panel changes **what is already
there**.  That is the same split as SNAP TO and ROUNDED TO, which nobody
would want to reach into an entity to set.  Losing the button would mean
drawing something in the wrong colour and then editing it, every time.

**Worth adding to the panel next, in about this order.**  Each is a row and a
setter, and the setters mostly exist:

* **Length on a line.**  The one that turns the panel from a readout into a
  modelling tool, and the one that needs a decision rather than typing: which
  end moves, and does what is joined to it come along?  It should - MoveVerts
  already does exactly that for a drag, and a length typed into a box ought
  to behave like a drag that landed exactly. Suggest: the end furthest from
  the last point you clicked moves, and the panel says which as you hover the
  box.
* **Colour and pen width** on whatever is picked.  `SetInk` does not exist
  yet; it is two lines.  Colour brings us level with their material field;
  width is ours alone.
* **Radius on a circle**, same shape of problem as length.
* **The plane an arc was drawn in**, which would let a circle be stood up
  after the fact.
* **A name on a solid.**  There is no field for it and it wants one in the
  file; that is a feature, not a row.

### The entity window - what it was going to take

Tony: "SketchUp has entities... And I think like for an arch you can get into
it and edit the number of segments.  I think we were trying to avoid having
all these various properties but I think it's a direction we may need to
head... I also think the entity window should be docked to the right."

The properties are already there.  `TWorkEnt` carries `Sides`, `Soft`, `Ink`,
`Weight`, `Size`, `Plane`, `Grp`, `Solid`, and the file round-trips all of
them.  `SetArcSides`, `SetSoft`, `SetNoteSize`, `SetGroup` all exist and are
already called when a shape is drawn.  What is missing is only the way in.

So this is a docked panel on the right plus a rebuild call, not an
architectural turn.  Docked rather than a dialog because the point of it is
watching the properties change as you pick different things.

### One edge written backwards, and a wall that would not divide - 15 September 2026

Tony: "so once again we closed in the a rectangle... i am unable to pull it
out as a floor because it didnt cut it into its own face in that long narrow
rectangle!"

A one-line logic fault in `uRegion`, and the best kind: found by reducing his
drawing to nine segments and running them headlessly.

The strip he closed off was bounded by four edges - two of the wall's own,
one line drawn across, and one drawn **along** the wall's existing edge,
because that is where the strip's bottom is.  Split at the crossings, that
last one becomes a piece identical to a piece of the edge it was drawn along,
and identical edges have to be welded into one.

`EdgeSeen` found its hash bucket from the pair **in order** - so both ways
round landed in the same bucket, which is right - and then compared against
`EA`/`EB` as **stored**, which keep the direction the edge arrived in.  An
edge put in as 5-2 was never recognised when it came back as 2-5.  The
duplicate went in.

Two parallel edges between one pair of corners are two more darts than the
face walk expects, so it goes out along one and back along the other: a slit.
His wall came out as a single eleven-point loop of 797 sq ft with the divider
traced up one side and down the other, instead of a band of 750 and a strip
of 47.5.  Nothing to push, and no way to see why.

**Worth remembering as a shape of bug**: a hash whose *bucket* is computed
from a normalised key and whose *comparison* is against the raw one.  The
bucket makes it look right - the two do collide, so the code path is
exercised - and the answer is wrong only for the half of the cases where the
raw form differs.  Grep for others: anywhere a key is sorted or canonicalised
on the way into a hash, check what the equality test uses.

Reduced into `tests/regiontest.pas` as TestDividerAlongAnEdge, which also
asserts that no loop doubles back on itself - the slit's signature, and a
cheaper thing to check than the areas.

### The eraser and faces, checked against the live page

Tony: "yes the eraser does allow you to erase faces in SketchUp and we do
want that just to be clear... you need to always be verifying how SketchUp
does something when we are uncertain."

Fetched it rather than relying on the note.  SketchUp's help says "The Eraser
tool doesn't allow you to erase faces", and puts erasing one on the Erase
context command.  Reported that back with the quote, and Tony went and looked
himself: "Ok I just checked and you are right the eraser will not erase a
face in SketchUp so let's follow SketchUp convention here."

So the difference is gone.  The eraser takes edges only; a click on a bare
face says what the eraser is for and names the two ways in that work -
right-click > Erase, and pick-and-Delete - both of which are SketchUp's and
both of which we have.  The hover wash went with it: a red wash over a face
the click will not take is the same fault in the other direction, and it was
still there for one build after the click stopped taking faces.

**The lesson is the cheap one and worth writing down anyway.**  Two people
half-remembering the same program disagreed, the disagreement went round once
more than it needed to, and one fetch of the live page settled it in a
minute.  `docs/sketchup/` exists for exactly this and is only as good as the
last time somebody checked it - so entries now carry the date they were last
checked against the real thing.

### A face is not a thing, it is what edges enclose - 15 September 2026

Tony: "in SketchUp I don't think you can even have a filled face unless it is
enclosed by lines.  So when I am erasing lines on a cube it will leave behind
faces and I think that is wrong... I think also when I delete a face in
SketchUp let's say in a cube there is a way to put it back if I remember
correctly but it was a pain in the ass... Verify my explanations here and
make sure I am not wrong then fix our program."

**He is right on both counts**, and `docs/sketchup/` - our own spec, fetched
from SketchUp's help in September - says so in as many words:

* 04-erasing-and-undoing: "Click an edge - erases that edge *and any faces it
  bounds*."  And the quote: "The Eraser tool doesn't allow you to erase
  faces.  Technically, faces are erased when you erase their bounding edges,
  opening and reshaping your geometry."
* 05-drawing-basics, under *Healing*: "Undo, or redraw the line that was
  removed - the face comes back on its own."

Both are fixed.  `FacesOnEdges` gathers the faces standing on the edges about
to go, and the eraser and the Delete key take them together; `FHealOn` tells
the region loop that the line just drawn was traced along an edge, which
beats both the memory of a face somebody deleted and the rule that a built
solid's opening is not a place for a face.  A side traced back into a box
rejoins the box rather than sitting loose on it, so the next rebuild does not
throw it away again and `/holes` agrees the box is closed.

**Why it only bit solids.**  Loose faces are thrown away and worked out again
from the edges on every edit, so they got the rule for free.  A solid's faces
are kept as they were made - which is right, they carry their group and their
winding - and nothing ever asked whether their edges were still there.

**The audit that is worth keeping.**  Before touching anything, a throwaway
program checked every face in every drawing in the repo against the edges
under it.  `wine-glass.hsk`: 576 faces, none unbacked.  The drive-test
drawings: none.  **`examples/etch-a-sketch.hsk`: 111 of its 133 faces have no
edges under them at all** - not a missing side, no edges whatever.  They are
the lettering and the robot, written straight in as faces.

That is why the fix is asked of the edges being erased and not of every face
in the drawing: an audit-everything rule would have deleted five sixths of
the example the first time anybody rubbed anything out.  It is also why Tony
is rebuilding the toy by hand and finding fault after fault in it - the model
the help pages all use is not geometry that the program itself could have
produced.  **Take his model when he offers it.**

### Two reports, read the same afternoon

**Truss notation had not stopped working.**  "wtf happened to being able to
enter dimensions like the truss guys do!?  that should have worked for my
rectangle!"  `6-8-15x4-0-0` makes a rectangle six foot eight and fifteen
sixteenths by four foot, and every length field in the program goes through
the one `ParseLen`, so it is accepted everywhere already.  What went wrong is
worse than a refusal: `6-8-15` on its own **parses**, so nothing objected,
and then RectTarget found no separator, gave up quietly, and took the corner
from the cursor.  A rectangle of the wrong size and not a word said.  It now
says what it wanted.  And the notation is in the manual, which was the other
half of what he asked for.

**Guides made no crossings.**  "THIS SHOULD BE SNAPPING TO THAT GUIDE I SET
AT THE OTHER END OF THE RECTANGLE AT 1"!!!"  The snap cache's crossing pass
walked `ekLine` and nothing else, so a guide laid an inch in from an edge
produced no point where it met that edge - the one point the guide was laid
to create.  Fixed, guide against line and guide against guide.  No cuts,
though: a guide is construction and does not divide the edge it lies across
the way a drawn line does.

**That is the sixth of these this week** and the list in the picker audit
below should have a line added to it: *what does this pass walk, and is a
guide one of them?*

### The manual, and taking its pictures without taking them - 15 September 2026

Tony: "our documentation really needs some help.  we probably need a document
just for the slash commands and keyboard shortcut cheat sheet would be great.
what's the key word shortcut for the select tool?  I tried s.  didn't work."

Space, which is SketchUp's key for the arrow, and `/s` as a command.  That he
had to ask is the whole argument: the program has sixty-nine commands and
thirty-odd keys and neither was written down anywhere but in the source.
`docs/help/commands.html` now lists every command grouped by what you are
trying to do, with its aliases and its key, and `docs/help/keys.html` is the
keyboard and the mouse on one sheet, both modes.

**Both were generated from the source and then written around, not typed out
from memory.**  The command table comes out of `CMD_LIST` and the alias
column out of the `RunCommand` chain, so the page cannot quietly drift from
the program.  Worth doing again the next time either grows - the script is
five lines of regex and it is in the commit.

**It found a real bug on the way.**  `/new` is offered in the list as "a new
sheet" and opened the release notes: the `whatsnew` branch also answered
`new` and sits above the branch that makes a sheet, so the second was
unreachable.  `tests/run-cmds.sh` now
catches it: a word compared twice in the chain is a word answered once, and
the second comparison is dead code.  Same idea as the check it already had
for a name offered that nothing answers.

**And the screenshots take themselves.**  `tools/help-shots.txt` drives the
program in the drive tests' nested X server and writes straight into
`docs/help/shots`.  Five are done and they are the pattern: put the tool in
hand, put the pointer where the picture wants it, `shot`.  `/update never`
at the top keeps the update nag out of the corner of every picture, and the
rig's own copy of the program means that setting never reaches anybody's.

The one thing it cannot do yet is the GIF itself - writing it goes through
the system's save dialog, which the rig has not been taught to drive.  That
is the next thing worth teaching it, because it would also let the export
path be tested end to end rather than up to the dialog.

### Two more of the same fault, both found in one hour - 15 September 2026

The rule that a picker learns and its neighbour never does, twice more, and
this time neither was in a picker: both were in what the picture said.

**Push/pull's stipple did not know about holes, or about what is in front.**
Tony: "using the push/pull tool and when i am hovering over the outer ring
face it highlights the face including the smaller rectangle face inside!  it
should only be highlighting as much of the face as it can see!"

He is right twice over.  A rectangle drawn inside another leaves a ring - an
outline with a window in it - and the window belongs to the face inside.
Everything else already knew: `PushPull` lines the opening, `FaceArea`
subtracts it, and `WashFace`, the eraser's wash, clips its hatch to the
outline *and* the holes *and* the depth buffer.  `PaintFaceHint`, twenty
lines away, did none of the three.  It now does all of them, the depth taken
affinely across the face - the view is orthographic and the face is flat, so
two multiplies a dot instead of a ray cast.

**The move ghost lied about what was coming with it.**  Tony, straight
after: "trying to move this line up the face more... the issue is that line
of the smaller inner rectangle is not staying snapped".

It *was* staying snapped.  `MoveVerts` moves every corner that sits where a
moving corner sits, so the two sides shrink to follow, and the committed
geometry was right the whole time - a headless check of the exact case
proves it.  What was wrong was the ghost: it drew the selection translated
and nothing else, so the side appeared to sail off alone and the rectangle
appeared to be tearing open.  `StretchPreview` works the leaning edges out
the same way the move does, and they are drawn thin behind the ghost.

**Worth noticing**: both reports were of a fault in the *picture*, and in
both cases the geometry underneath was already correct.  A drawing program
is what it shows.  The audit below asks five questions of each picker; there
is a sixth for anything that paints a hint, and it is the same list -
can it see it, what does it stop at, what does it say it will do - asked of
the paint rather than the pick.

**The move now has two ways, which Tony asked for.**  The stretching one is
SketchUp's and is what happens by default; `/detach on` takes what is picked
away on its own.  It is a command and not a held key because a move has no
key left: Ctrl leaves a copy, Shift holds the axis, Alt holds the working
plane, and every letter is a tool shortcut.  Worth revisiting if a modifier
ever frees up - a held key is the better shape for it.

### The frame, measured rather than guessed - 15 September 2026

Tony: "the display and moving has gotten really poor performing... in the
past dozen revisions we introduced something that is hurting the
performance."

Measured v2026.09.14.10 against HEAD, same drawing, same view: 25.7 ms a
frame both, quick frames 23.7, overlay 8.9, blit 0.6.  No regression in the
frame path.  The snap path measured 0.033 ms - the 22x regression the first
run of that benchmark reported was the benchmark's fault, not the program's:
it had no rendered depth buffer, so `HiddenAt` walked every face.

What is true: the cost climbs with zoom, 3.4 ms at 100% to 16.5 ms at 4000%,
and saturates there.  His report had him at 2863%.  And of a 25.7 ms frame
only about 6 ms is the model - the rest is the full-screen paper repaint and
the composite, which a quick frame does not skip.  **That is where the work
is if this is picked up**, not in the snapping.

### What's new is a paint box, and that has consequences

Worth writing down because it explains a class of bug rather than one bug.

The release notes window draws every line itself onto a `TPaintBox`: no rich
text control, no HTML, no markdown renderer.  `ReleaseNotes` reads
WHATS_NEW.md and sorts each line into one of three kinds - a version heading,
a section heading, a bullet - and `Run` measures or draws them, including the
one bold span a bullet may start with.  That is the whole of the markdown it
understands, and it is why the thing themes perfectly.

The consequence is that it has no behaviour it was not given.  The wheel
works because a wheel handler was written.  The keyboard works because a key
handler was written.  A finger did nothing at all, because nothing had been
written for it - which on Tony's Windows touch laptop meant a window you
could read and not move.  Dragging the page scrolls it now, which costs a
mouse the same gesture for free.

Anything else drawn this way - the command list, the popup menus - has the
same shape, and the same question is worth asking of each: what happens when
somebody touches it rather than clicks it.

**And a second consequence, found the hard way on 16 September.**  It paints
words, not markup - so `<kbd>Ctrl</kbd>` written into WHATS_NEW.md out of
habit from editing the help pages reached a user with the tags showing.
Tony saw it in the release.  The notes now go through a `Plain` that strips
the handful of inline tags that could plausibly turn up, **by name** - not
"anything in angle brackets", because the notes already contain
`/tiles <folder>` where the brackets are how a placeholder is written and
eating those would be the worse bug.

### LazInk, and what it could take over - 16 September 2026

Tony: "is this what's new decorated text panel a ton of work because I think
we actually have already built an html component... I'm not saying to use our
html render as it needs a lot of work yet but we should consider using it in
the future as it could also be used for the help documentation!  And it would
be a native Lazarus package and not require external dependencies."

**It is further along than he remembered.**  The prototype on the desktop has
a note in it saying it moved: `/media/tony/storpart/synced/GIT/LazInk`, six
thousand lines, package `lazink.lpk` - TInkLabel, TInkEdit, TInkMemo,
TInkListBox, TInkRichEdit.  All canvas-drawn, so identical on every
widgetset, gtk3 included, and no external dependency.  `TInkMemo` describes
itself as "a scrollable multi-line viewer - a log, a transcript, **formatted
help**", which is this job exactly.

*What it would take over, easily.*  The release notes window is 599 lines of
hand-rolled parse-and-paint for three kinds of line and one bold span.
TInkMemo does all of that and more - `<b> <i> <u>`, colours, `<hr>`, `<p>`,
links with `OnLinkClick`, images - and the tags bug above could not have
happened, because the tags would have rendered.  That swap is a small job and
it deletes more than it adds.

*What it would NOT take over, yet, and this is the part worth knowing before
anybody starts.*  The help pages use `<table class="sheet">` on six pages,
the `.grid`/`.card` layout on the index, and a stylesheet for the whole look.
LazInk's markup is an HTML **subset**: inline styling, alignment, indent,
links, images - no tables, no CSS, no nested block layout.  So "render
docs/help in the program" is not a swap, it is either

  * a simpler in-program variant of the pages written in LazInk's markup -
    which then has to be kept in step with the web ones, and two copies of a
    manual is how one of them goes stale; or
  * table support in LazInk, which is the real answer and a real piece of
    work in its own right.

*The order that makes sense:* the release notes first, because it is a small
swap with an immediate payoff and it puts LazInk in the build where it can be
lived with.  Then decide about the help, with the table question settled one
way or the other.  Nothing here is urgent.

### The view cube

Built 14 September, at Tony's friend's asking - he uses Revit and thinks a
drop-down is a poor way to change a view.  The argument both of them were
having was about space; the answer is that it is not the same instrument.
The VIEW button can put you in a named view and cannot tell you where you are
once you have orbited away from one, and nothing else on screen can either.
That is what the cube is for, and it does it without being touched.

`uCube.pas` is the whole of it: twenty-six targets - six faces, twelve edges,
eight corners - hit by casting a ray through the orthographic camera into a
box and classifying where it goes in.  The band is the middle 65% of a face.
`CubeTargetAt` runs it the other way, giving the point on screen where a
target is drawn, which is what the test aims at.

Ours, not theirs.  The interaction is Revit's and that is ordinary; the look
is the program's own, and "ViewCube" is Autodesk's name for Autodesk's
widget.  Two attempts at dressing it up were thrown away - a rounded tray
behind it and a cast shadow - because between them they gave the thing three
outlines that were not the cube's, and it stopped reading as a cube at all.
It is drawn with the shading and the rim light the rest of the chrome uses
and nothing else.

**The widget owns its corner, not just its pixels.**  The cube is a hexagon
inside a square, so aiming at its left-hand edge puts the pointer over the
square and off the shape - and the crosshair, the snap mark and the chip that
says what the tool will do were all being drawn on top of it at exactly the
moment somebody was trying to click it.  `CubeZone` is the square plus a
margin, and inside it the drawing stands down: no chip, no crosshair, no
wheel, and presses are swallowed rather than landing on the model behind.

**What it turns about.**  The origin, at first, which is wrong for the same
reason it is wrong everywhere else: a TProjector has no pivot in it, so a
building drawn half a mile from zero swings clean out of the window.  Revit's
rule is the middle of what is selected and the middle of what you are looking
at when nothing is, and `TWorkDoc.MiddleOf` already does exactly that - the
export turns about the same point for the same reason.  `HoldTurn` puts it
back where it was on the screen after every step, the way the orbit drag has
always held the point you grabbed.  Checked by logging the pivot's screen
position through a roll: held to a tenth of a pixel.

**Three bugs in the glide, and the last one is the lesson.**

* It counted ticks instead of reading the clock, so a third of a second of
  animation took a second and a half.  The recorder learnt this first.
* It never repainted the paper, so the axes and the ground grid stayed
  exactly where they were while the model turned under them.  A middle-drag
  orbit has always called RepaintPaper every move; this did not.
* **And nothing ever reached the screen.**  Invalidate marks the canvas
  dirty and leaves the painting to the message loop - but the move runs off
  the sixteen millisecond tick, and every step of it repaints the paper and
  re-renders the model, so the loop never got a turn between one tick and the
  next.  No frame was drawn at all; the first paint anybody saw was the one
  after the move had finished, which looks exactly like a teleport.
  pbScreen.Update paints it there and then.

  Worth remembering how this was missed: logging said the camera was easing
  round perfectly, and it was.  The instrument was watching the angles and
  the complaint was about the screen, so the log agreed with the code and
  disagreed with the person looking at it - and the person was right.  The
  measurement that found it compares screenshots taken during the move
  against the start and the finish: before the fix they were pixel-identical
  to the start and then jumped, after it they are genuinely in between.

**The glide was the real work.**  Every view change in this program snapped,
which is fine for a button and wrong for a cube - the tumble is how you keep
track of which way the model went.  `GlideTo` and `StepGlide` roll the camera
from one place to another over a third of a second, and the VIEW button and
the presets get it too.

It rolls rather than winding the two angles.  Turn and tilt are convenient to
store and a poor thing to interpolate: wound together they swing the camera
along a path neither angle describes, and corner to far corner it wallows
sideways before coming back.  So both ends are turned into the direction the
camera stands in and the path is the great circle joining them - the shortest
way round the sphere, at one rate.  Checked by logging the samples and
confirming every one lies in the single plane through the origin that
contains both ends, to five decimal places.  It runs on the clock and not on the tick
count, for the reason the recorder found out the hard way: every step redraws
the model, so the ticks come slower than the sixteen milliseconds they are
asked for and a third of a second of animation takes a second and a half.
Measured at about 34 frames a second on the wine glass.

Not done, and worth it if it gets used: dragging the cube could snap to the
nearest target when let go near one, and a keyboard walk through the
twenty-six would make it reachable without a mouse.

### The little film, and how it joins back onto itself

Done 14 September.  Three things that all showed as "the GIF looks wrong".

* **The axes were painted over the finished picture.**  `PaintAxesOn` ran
  after `Doc.Render`, so every axis was drawn through whatever solid stood in
  front of it.  The drawing area never did this - it rules them onto the
  paper layer and composites the model over the top - so a film did not look
  like the screen.  `ShootInto` takes an `Axes` flag now and paints them
  before the model.  Measured on the wine glass at 520 px/ft: 1102 solid
  model pixels intruded on, worst 168, down to 124 and worst 49.  The 124
  that remain are the background showing through translucent faces, which the
  screen does too.

* **A film that closed stuttered; one that did not, jumped.**  The sampler
  ran `I / (Count - 1)` - both ends inclusive - so a turntable rendered its
  first pose twice and froze for a frame every loop, and a rise teleported
  home.  `CamPathCloses` asks the *clip* whether it ends where it began
  (azimuth compared the whole way round, since a turntable ends at Az + 2*Pi),
  and `TFilmLoop` picks: seamless (drop the last frame) when it closes,
  bounce (out and back inside the same budget) when it does not and the tick
  is on, as-is otherwise.  Measured by writing real GIFs and comparing the
  wrap-around step against an ordinary one: turntable 56 against 58,
  rise as-is 104 against 66, rise bounced 67 against 76.

* **The recording room could not be moved at all.**  Borderless, and nothing
  ever wired to drag it.  It uses the same `uDlgSkin.DragBegin/DragTo` as the
  other windows now, and not while it is rolling.

Also: how long the film runs is now a choice at export time rather than
whatever the clip happened to take, which is the same thing as its speed.

### Getting a part to a printer, and the step that was being done by hand

Tony's uncle prints from this program on a three hundred dollar machine and
the workflow works - but he opens every part in OpenSCAD on the way, to
"modify some properties and centre it".  Tony wanted that step gone, which
meant working out what it was for.

At least part of it was ours.  **"Centre it on the origin" centred all three
axes**, so the bottom half of every part sat under the build plate.  Slicers
lift it back out without comment, which is why nothing ever looked wrong -
but centring a thing for printing means centring it ON the bed, and a model
half underground is exactly what somebody opens another program to put right.
Fixed in the STL, the OpenSCAD and /center: across X and Y, standing on Z.
Measured on the wine glass, 0.00 to 215.90 mm.

Two tests asserted "centred in z" and had to change with it.  They were
asserting the bug - written when the convention was assumed rather than
checked.

**Still unknown: what else he does in there.**  Worth asking him, because it
decides whether anything more is wanted:

* **laying a face on the bed** - rotating a part so the right face is down
  for strength or to avoid supports.  We have nothing for this and it is the
  most likely remaining answer.
* **scale** - if a part ever arrives the wrong size that is a units fault and
  worth knowing about; the STL is always written in millimetres.
* **which file he opens** - if it is the .scad rather than the .stl he may be
  editing the polyhedron or wrapping it in a transform, which is a different
  workflow and would explain "properties" better than an STL can.

### Sending it to the printer, if that is ever wanted

Researched 15 September, nothing built.  A printer takes G-code, not a model,
and slicing is a whole program with years in it - supports, infill,
perimeters, temperatures, retraction.  We should never write one.  So:

    Heckers Sketch -> STL -> a slicer -> .gcode -> the printer

PrusaSlicer has a proper headless command line for the middle of that, the
same shape as the FreeCAD note above.  The far end is solved on two stacks:
**Klipper + Moonraker**, a documented HTTP/JSON-RPC API that Mainsail and
Fluidd are themselves only front ends onto; and **PrusaLink**, a local REST
API embedded in MK4S firmware, with Prusa Connect as an optional cloud layer
nobody has to touch.

Resin is the wrong branch for this: it slices to per-vendor proprietary
binaries - .ctb, .pwmx, .goo - with no standard and essentially no documented
network API.

The line to hold, if it is ever built: **we never own a slicing setting.**
Hand the file to the slicer they already configured.  The moment this program
has an infill percentage in it, it has stopped being a simple drawing
program.

### Importing manufacturers' equipment models

Tony: the heating and cooling makers publish models of their equipment and it
would be good to bring those in - an air handler, a fan, a rooftop unit -
rather than drawing a box the right size and hoping.

**What they actually publish**, checked rather than guessed (Greenheck,
Daikin, and the aggregators - BIMobject, CADdetails, ARCAT):

* **RFA** - Revit families, the main event for MEP.  Proprietary, no spec,
  cannot be read.  Same wall as writing one; see the Cricut note for the
  same conclusion reached from the other side.
* **IPT** and **F3D** - Inventor and Fusion.  Also proprietary.
* **DWG** - everywhere, and AutoCAD's own binary.  Reverse-engineered by
  others (LibreDWG) but a large job to do ourselves.
* **DXF** - AutoCAD's documented interchange format, and text.  Often offered
  beside the DWG; anything DWG converts to it with the ODA free converter or
  by the person sending it.
* **STEP** - some makers offer it.  The honest neutral 3D format and a real
  parser is a big piece of work: an EXPRESS schema, B-rep topology and NURBS
  surfaces, none of which this program has a representation for.

**So DXF is the way in, and it is the one we are already halfway to.**  We
write it - uDxf.pas - so the group codes, the units and the layer handling
are already understood at this end.  Reading needs: 3DFACE, POLYLINE/VERTEX
meshes, LINE, LWPOLYLINE, CIRCLE, ARC, and INSERT/BLOCK for anything
assembled out of parts.  $INSUNITS decides the scale, which is the thing that
has to be right or the unit arrives eight feet tall or eight inches.
STL and OBJ are nearly free if anyone ships them - both are a few dozen lines
and we already write STL.

**The design question is what an imported unit BECOMES**, and it matters more
than the parsing.  This document is faces and lines with a region engine over
it, and a manufacturer's air handler is thousands of triangles.  Dropped in
as loose geometry it would be slow, would confuse the region finder, and
would be senseless to push or pull.  What somebody actually wants from it is
coordination: does this thing fit the ceiling, does the duct clear it, what
is the clearance to the filter door.

So the likely right shape is a **block**: one group that moves, turns, snaps
and measures as a unit, draws as itself, and is not editable geometry.  That
also sidesteps the region engine entirely.  A second, cheaper option worth
weighing first: many equipment DXFs are 2D plan and elevation outlines, which
are lighter, more useful for a coordination drawing, and import as ordinary
lines with no new concepts at all.

**A DXF importer is wanted.**  Tony, 15 September: it is the first way in.
Not built, and on this list on purpose.

### Somebody else's converter, as a door rather than a dependency

Tony's idea, and it is a good one: rather than teach this program every
format, find the free converter that already reads them all, keep it OUT of
our build, and either hand its output to our importer or simply tell the
person where to get it and what to do.  Nothing bundled - they install it.

**Nobody has to install Python.**  Tony's objection when this was first
written up, and it was a fair reading of how it was put: "runs a Python
script" sounds exactly like a dependency.  It is not one.  FreeCAD embeds its
own interpreter - the Linux AppImage carries the Python binary inside it, the
Windows installer bundles it with its libraries - so `freecadcmd` IS the
interpreter, the script runs inside FreeCAD, and no system Python is touched
or wanted.  One application, installed the way applications are.

The ODA converter has no Python at all: a plain executable and seven
positional arguments,

    ODAFileConverter.exe "C:\in" "C:\out" ACAD2018 DXF 0 1

in-folder, out-folder, version, format, recurse, audit.  One thing to know:
it is a Qt program driven by a command line, so on a HEADLESS Linux box it
still wants an X display.  On a desktop, which is the case here, that never
comes up.

**And for the job actually in front of us, neither is needed.**  The
manufacturers ship DXF and DWG - Greenheck offers 2D AutoCAD drawings and 3D
AutoCAD models outright.  So the common path is:

    DXF  ->  us                                   nothing installed at all
    DWG  ->  ODA (one exe)  ->  DXF  ->  us       nothing scripted

FreeCAD earns its place for STEP and IGES, which is the mechanical-CAD corner
rather than the heating-and-cooling one.  It is the third door, not the
front one, and it should be described that way to anybody.

**FreeCAD is the answer to "is there an amazing free one".**  LGPL, genuinely
open source, on all three platforms, and built on Open CASCADE - so it reads
STEP and IGES properly, as B-rep, which is the hard part nobody else gives
away.  It also reads DXF, OBJ, STL and BREP, and writes DXF, STL and OBJ.  It
has a headless mode - `freecadcmd` on Linux and macOS, `FreeCADCmd.exe` on
Windows - that runs a Python script with no window, so a conversion is one
command and no clicking.

**DWG needs a step before that**, even for FreeCAD, which cannot read it
alone.  It names three helpers: **LibreDWG** (GPL-3, genuinely open, and its
own documentation says it is a work in progress that lacks some entities),
the **ODA File Converter** (free to use but proprietary - the de-facto
standard, and what FreeCAD and LibreCAD both point people at), and QCAD Pro,
which is paid.  So the open path is LibreDWG and the reliable one is ODA, and
neither can be shipped with us - which is fine, because neither should be.

**The pipeline that falls out of this:**

    anything  ->  FreeCAD (installed by them)  ->  DXF or STL  ->  us
    DWG       ->  ODA or LibreDWG  ->  DXF  ->  FreeCAD or straight to us

**And it changes what our first importer should be.**  STL is the better
first target, not DXF:

* it is triangles and nothing else, so reading it is a few dozen lines, and
  we already WRITE it so the units and the winding are understood here;
* FreeCAD will turn anything it can read into one;
* and equipment is exactly the case where triangles are enough - an air
  handler is a thing you place and measure against, not a thing you edit.

DXF stays worth doing and stays the better answer for the other half of the
job: 2D plan and elevation outlines, which arrive as real lines and arcs
rather than a mesh, and which are what a coordination drawing actually wants.
So: two importers, smallest first, and STL is the smaller.

**If we ever want to read DXF ourselves rather than convert into it**, the
reference to read is `ezdxf` - MIT, Python, full read and write of R12
through R2018 in both ASCII and binary, and the best documentation of the
format outside Autodesk's own.  Not to depend on; to learn from.

**What "quickly accessible from our program" could mean**, in rising order of
work and none of it decided:

1. Say so.  The open dialog, offered a .step or a .dwg, explains what it is
   and where FreeCAD is, and offers to open that page.  No detection, no
   processes, and it is most of the value.
2. Find it.  Look for freecadcmd in the usual places, and if it is there
   offer "convert this with FreeCAD" - one process, one temporary file, and
   our own importer on the far end.
3. Drive it.  Ship the little Python script the conversion needs and run it
   headless.  Still no bundling - the script is ours and it is twenty lines.

Licence-wise all three are clean: running a program is not linking to it, so
FreeCAD being LGPL and the ODA converter being proprietary freeware are both
fine as long as we ship neither.

Nothing decided.  The smallest first step, if this is wanted, is an STL
reader and option 1 above - a sentence in a dialog - and neither needs the
other.

And the order to offer them in, which follows from the Python point: DXF
first because it needs nothing installed, DWG second because it needs one
executable and no scripting, STEP last because it needs a whole application -
a good one, freely given, and still a whole application.

### Cutting machines, and the Cricut in particular

Tony has a **Cricut Explore 3**.  The question was whether we can cut to it
directly.  Today, no, and it is worth writing down why so nobody spends a
weekend finding out again.

* **CutcutGo** (github.com/virtualabs/cutcutgo) is the real work: open GRBL
  firmware that turns a Cricut into a G-code machine, no account and no
  Design Space.  It is for the **original Cricut Maker** and means opening
  the machine and flashing the board.  The Maker 3 needs its electronics
  reverse-engineered from scratch, and the Explore line is not covered at
  all.
* **Inkcut issue #426** asks for stock-firmware Maker support and reaches no
  conclusion - the people asking say themselves they do not know how
  tractable it is, and the thread carries no findings about the protocol.
* Over USB on an unmodified machine the protocol is encrypted and there is
  essentially nothing public beyond the cartridge-era machines.  That is not
  for want of trying: Provo Craft sued Make-the-Cut and Sure Cuts A Lot in
  2010-11 and both dropped Cricut support.

So the way out is the file, not the wire, and the file had a defect worth
fixing on its own account: **the SVG carried no units**.  Fixed 14 September -
`WriteSVG` writes width and height in inches or millimetres against the
viewBox, so the drawing arrives at its real size wherever it goes.
`TestSvgIsTrueSize` measures the wine glass at two zooms in plan and from the
front, and an independent renderer agrees: 366 px at 96 dpi for the 3.81 in
the file claims.

If a machine ever does open up - a Maker v1 with CutcutGo, or somebody cracks
the Explore - the work on our side is a G-code writer, and it is small: the
cut paths are the same projected polylines WriteSVG already walks.

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

### Closing without saving - DONE 16 September 2026

Tony, 14 September: closed the drawings, chose not to save, opened the program
again and the drawing he had declined to save came back.  And 15 September:
"I closed its tab sheet and was not asked to save it."

Both are done.  Closing the last sheet drops the draft; closing a sheet with
work on it asks about **that sheet** (TDrawing.Dirty - see 16 September
above); and the window has an OnCloseQuery now, so quitting with work on a
sheet asks the same three ways as closing one.  `close-asks` in the drive
suite covers a sheet with work and a sheet nobody touched.

Still true and still right: the draft is written on the way out by design,
because pulling the plug must lose nothing.  Answering "close without saving"
to the quit prompt does not drop it, and nobody has asked for that.

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

**And there are two of them now, 14 September.**  The wine glass joins the
toy: `examples/make-glass.pas` draws the outline of half a glass and calls
`TWorkDoc.Revolve`, which is the same code the tool calls - so the model
follows the tool rather than being traced once and slowly going stale.
`uExamples.pas` is the list, and adding another is a generator and one line.

The tests insist on four things for every example, all of them found the hard
way: the file and the copy inside the program are the same bytes, every face
belongs to a solid so `/reface` cannot eat it, the whole thing is a closed
solid, and it stands on the ground.

What is left of Tony's idea below: more of them - the crown, and a few
deliberately wild ones - and the checksum rule, so an example improved in a
later version replaces the old one while something somebody has edited and
saved under its own name is left alone.  Today's version simply writes them
out over the top every run, which is right for a file nobody has touched and
wrong the moment they have.



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
