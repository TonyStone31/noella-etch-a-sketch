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
* **Orbit performance with fittings.**  /rendertime now prints where a frame
  goes: index and edges, faces, visible runs.  On a 528-face spool at
  1920x1000, release build, 2026-09-07: 29 ms before, 21 after packing the
  edge-index keys and caching face planes for the line-on-face pass.  The
  checked build is 3-4x slower on the same work, and is meant for finding
  faults, not for drawing.  Next cheap wins, in order: the insertion sort of
  faces is O(n^2) (fine at 500, not at 5000); the edge index is a sorted
  string list with O(n) inserts; the face fill scans four sub-samples a
  row.  Threads after that: the face paint is per face into a depth buffer
  and splits by screen band; the visible-runs pass splits by line.
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

## Open questions

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
