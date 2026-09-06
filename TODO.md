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

Drawing: lines, rectangles, circles, arcs, offset, push/pull, move, erase,
text with leader lines, dimensions you place yourself, the tape measure with
guides.  Snapping and inference - endpoints, midpoints, the midpoints a
crossing makes, on-edge, axis locks, From Point - and a snapped point now
holds until you mean to leave it.

Faces are derived from the edges that close them, in any plane, including
sloped ones - a circle goes on a roof and pulls out square to it.

Three views that each know what they are for: PLAN draws on the ground, ISO
locks to the three paper axes with Shift to come off them, 3D is the free
camera and the only place anything goes off-axis.

Around the edges: portable, single instance, drafts that survive a crash,
self-update, crash and bug reports that go somewhere, Windows on its own TLS.

Two test suites, both green: `./tests/run.sh` (255 checks) and
`./tests/run-region.sh` (76).

---

## Next up, in order

1. **The transition builder.**  Two opening sizes, the length of the gap, and
   for each axis one named edge and how far it moves.  Six numbers and two
   choices - `docs/transition-ticket.md` has the notation it has to match.
2. **Seam and bend allowance, and end treatments.**  TDF, flange out, flange
   in, slip, drive, raw, corners notched - per edge, not per end, each worth
   a different amount of material.  The shop's numbers, not guessed ones.
3. **Note text size.**  Asked for as "resize the caption box"; SketchUp
   changes the text size, which is the thing worth having.  Wants a size on
   the note and a renderer that honours it.
4. **Rotate.**  Never built.  45s are the job.
5. **A protractor, and angled guides.**  The largest thing missing from
   guides, and the same 45s are why.  `docs/sketchup/13-guides.md`.
6. **The rest of the dimension tool**: radius and diameter, dragging an
   extension line out of the way, endpoint styles.
7. **Copy arrays** - `*6` and `/3` after a Ctrl-move.  SketchUp's own docs do
   not give the syntax, so this is worked out from the app.
8. **Elbows and 45s with offsets**, then square-to-round.  There is no house
    style for square-to-round to follow, so it takes a standard from the
    layout books and expects to be argued with.

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
