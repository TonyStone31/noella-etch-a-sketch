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

**History lives in the commit messages.**  This file is what is left to do,
down to **Done and settled** - past that are the write-ups worth keeping
because the reasoning in them was the expensive part.  When something is
finished, its note moves down there and anything left over goes into
**Loose ends**.

---

## Where it stands, 17 September 2026

Drawing: lines, rectangles, circles, arcs, offset, push/pull, revolve, drill,
move, rotate, erase, text with leader lines, dimensions you place yourself -
and can retype to resize what they measure - the tape measure with guides and
the protractor with angled ones.  Rounded corners the SketchUp way (a click
keeps the corner, a double-click trims it).  Snapping and inference, and a
snapped point holds until you mean to leave it.  Edges that cross cut each
other as they land.

Faces are derived from the edges that close them, in any plane, including
sloped ones.  Faces that are not flat are cut into triangles before they are
drawn, so their depth is exact rather than fitted.  Loose faces are wound
against their neighbors rather than one at a time.  The program knows whether
a solid is closed, and shows where it is not.

Views: PLAN draws on the ground and can cut a slice through the model at a
height, ISO locks to the three paper axes, 3D is the free camera.  The view
cube, and Ctrl on the orbit to click into the nearest of its twenty-six
views.  An entity panel on the right (`/info`) that edits sides, soften,
note size, face direction and a line's length.

Getting it out: an export room with a live preview - PNG, JPEG, animated GIF
with a camera recorder, SVG, DXF flat or in 3D, STL, and OpenSCAD.  Printing
at scale or full size across many sheets.

Around the edges: portable, single instance, drafts that survive a crash,
self-update, Windows on its own TLS, the manual inside the program (downloaded beside it, kept
current, drawn by LazInk), and reports that carry the frame times, the last
few dozen actions, the drawing, and how the program was started and set up.

Tests, all green: `./tests/run.sh` (1103 checks), `./tests/run-region.sh`
(91), `./tests/run-cmds.sh` reading the command table against the
dispatcher, and `./tests/run-drive.sh` - 47 scripts driven through Xephyr,
six at a time, some of them chained in one program.

---

## Measured: what sub-pixel placement is worth - 17 September

From a note: "i'm just still a little jelous of those crisp looks sketchup gives ...
hard to point at the differences really."  So before changing anything,
measure one of the candidates.  `tools/crisp.pas` is the instrument (ignored
like everything in `tools/`; compile it the way `tests/run.sh` compiles
geomtest).

**The effect is real and it is big.**  One level edge, moved across a pixel,
black on white:

| weight | best offset | there | anywhere else |
|---|---|---|---|
| 1 (an ordinary edge) | 0.5 | 1 row, ink at 0 | 2 rows, ink at 127 |
| 2 (a profile) | 0.0 | 2 rows, solid | 3 rows, solid with a fringe |
| 3 | 0.5 | 3 rows | 4 rows |

A weight-1 edge is either a solid black line or two rows of fifty percent
gray, depending on nothing but where the geometry happened to land.  That is
the whole of it - a line that is half as dark and twice as wide reads as
soft.

**But it cannot be fixed by nudging the view.**  `LineW` gives an ordinary
edge `EdgeW` and a profile `EdgeW + 1`, which at our scale is 1 and 2 - and
odd weights want the half-pixel offset while even weights want the whole
one.  The two want opposites.  Shifting the whole projection half a pixel
was measured on a floor plan and did nothing worth having: -3%, +0%, +1%,
-2% of the half-lit pixels across plan, front, iso and orbit.  Any fix has
to be per line, where the line is drawn, snapping the across-coordinate to
whole or whole-and-a-half by the parity of its weight.

**And it only ever helps flat views.**  Edges that come out level or upright
on screen, which are the only ones with anything to snap to:

| view | edges | level or upright |
|---|---|---|
| plan | 19 | 17 (89%) |
| front, straight on | 10 | 10 (100%) |
| iso | 19 | 0 |
| orbit, off an axis | 19 | 0 |

So: worth doing for plan and elevation drawings, where it would be a visible
sharpening for a contained change in `TArtSurface.Line`.  **Worth nothing at
all for the 3D views**, which is where the jealousy actually comes from - in
iso and orbit not one edge is axis-aligned, and every one of them is
antialiased across two rows no matter what anybody does.  If the 3D look is
the thing to chase, it is one of the other candidates: the grain we put on
paper on purpose, gamma-space blending in `BlendPixel`, or edge weight.

---

## Two reports from the etch-a-sketch toy - 17 September, late

Both came in while the toy itself was being drawn, and they were called
"probably mostly user error".  One of them is not.

### The pick takes the wall under the rim

"trying to erase the black ring on the top of the knobs... but it ends up
selecting some of its walls underneath it sometimes."

Real, and the mechanism is in `HitEdge`.  It keeps the edge with the
smallest **screen** distance within nine pixels, and depth only ever
disqualifies: an edge is skipped when it is hidden at all three of the
points sampled along it, at 0.2, 0.5 and 0.8.  A knob's wall edge is a
silhouette - visible down its whole length - so it is never skipped, and
where it passes within a pixel or two of the rim on screen it simply wins on
2D distance.  Nothing prefers what is in front.

**The rule it should have**: among the edges within reach, prefer the one
that is visible *at the point nearest the cursor* - not merely visible
somewhere along itself.  That is what "in front wins" means when you are
pointing at a spot, it keeps the good half of the three-sample rule (an edge
coming out from behind something is still pickable by the part you can see),
and it needs only the boolean `HiddenAt` already there, so no depth-sign
convention has to be got right.  Cost is one depth-buffer lookup per
candidate inside nine pixels, which is a handful.

**Done**, the same night - From a note: "Do the point nearest cursor suggestion."
`SegParam` says where along a segment its nearest point to the cursor sits,
`ArcNearestAt` does the same walk an arc's distance already did and hands
back the place as well as the distance, and `HitEdge` sorts its candidates
into can-be-seen-here and cannot before the nearest of them wins.  The
three-sample rule stays underneath, unchanged, and is now only asked when
the cheap question has already said the edge is hidden at the cursor - an
edge visible under the cursor is plainly not hidden everywhere.  The test
fails on the old code and passes on the new, which is the only reason to
believe it.

### Groups, and locking

"i think this is why we will need to make things groups and stuff that can be
locked ... i could have made that etchasketch a group and locked it then
moved the letters onto its surface where i want them, then ungrouped and
regrouped ... im struggling to properly set my letters on the face."

He is describing SketchUp's Groups exactly, and the reason people reach for
them is exactly this: **a group is what stops the geometry you are working
against from joining onto the geometry you are working with**.  Letters laid
on a face merge with it; the hollow of an R cuts the face under it; erasing
the R takes a piece of the face with it.  That is not a bug in the region
finder - it is the region finder working, on a drawing that has no way to
say "these two things are separate objects".

It is the largest single gap between us and SketchUp, bigger than any tool.
`Grp` already exists on an entity for solids, so there is a thread to pull,
but the real work is everywhere else: picking, moving, erasing, the region
finder, save and load, the entity panel, and a way in and out of a group.
Not a late-night job.

**Written up in full: [`docs/groupplan.md`](docs/groupplan.md)** - what
would have to be touched, in what order, and what each part of it costs.
Written on 18 September while the reasoning was fresh, and **explicitly not
the next thing to build**.  From a note: "we really want to make sure we have all
the issues with basic drawing functionality in all the tools sorted out
before we pile on yet another feature."  Everything in that document sits on
top of the pick, the move, the eraser, the region finder and the snap - the
very things the reports are still finding faults in - so building it first
would mean fixing each of those twice, and having some of them hidden by the
new layer until somebody drawing a shed found them.  The document also
argues the name: **part** rather than group, one idea instead of SketchUp's
confusing Group-against-Component split, with `/group` kept as another word
for it because that is what people will type.

---

## The ink pass, chased - 17 September

The frame line in the reports had been saying `ink 83` at 507 things and
`ink 61` at 1259, so the ink pass rather than the screen pass was the cost.
`tools/inkprof.pas` loads the drawing a report carries - the real one, not a
made-up model - and times `Render` with TWorkDoc's own `ProfMs` breakdown.

**Where it went**, on the etch-a-sketch toy from the 23:19 report, 1259
things and 409 faces, one orbit frame:

| pass | ms | share |
|---|---|---|
| setup, edge index, edges drawn whole | 2.0 | 8% |
| faces gathered | 1.6 | 7% |
| **faces painted** | **15.2** | **63%** |
| lines put back on visible faces | 4.8 | 20% |

Sorting, the plane table and `EnsureOnFace` all measured under half a
millisecond - so "faces painted" meant the fill itself.  Taking the fill out
altogether dropped the frame from 25 ms to 12 ms: **`FillLoops` was half the
frame**.  Inside it, four samples a row cost about 7 ms and the per-row walk
over the depth triangles about 3 ms.

**What was wrong with it.**  Every sample row walked *every edge of every
loop* to find the two or three it is actually crossed by.  A face with
rounded corners is eighty edges and a hole adds thirty more, four samples a
row, every row of the face's box.  So: the edges are flattened once, sorted
by where they start down the screen, and taken into an active list as the
rows reach them and dropped once the rows have passed - the ordinary active
edge table.  Level edges are left out entirely; the crossing test can never
fire on one.

**Measured, three runs each, on the three drawings the reports carried:**

| drawing | before | after |
|---|---|---|
| 1259 things, 409 faces | 24.0 ms | 20.7 ms |
| 664 things, 210 faces | 26.0 ms | 21.3 ms |
| 507 things, 196 faces | 20.0 ms | 16.3 ms |

**And one thing that was tried and thrown away**: the same treatment for the
depth triangles, which are also walked whole every row.  It made things
*worse* - 15.5 ms to 18.1 ms on the same drawing - because the existing
reject is two integer compares, and a sort plus a per-row compaction costs
more than it saves.  Measured, reverted, written down here so nobody tries
it twice.

**What is left.**  The second drawing has half the faces of the first and
paints slower, so what remains is not face count but the pixels they cover -
real work, plus overdraw, because the painter's algorithm fills a face even
when a nearer one will cover it entirely.  Cutting that means occlusion
before filling, which is a bigger change than this one.  `ProfMs`' comment
was also one out of step with the code, which sends a profiling session
after the wrong pass; fixed.

---

## Colors on a whole selection - 17 September

By report, an hour after the material went in: "would be great if we could
select the colors for multiple selected faces! and line colors too ... would
have to show grouped things in the selection info window to bulk apply ...
does sketchup allow this?"  It does - a material dropped on a selection
paints all of it, and Entity Info edits what a mixed selection has in common.

The panel already counted what was picked and offered Reverse; the rule
against anything else was that **a stepper that acted on nine things at once
is a way to lose nine things**.  That rule is right about steppers and wrong
about color: a color is one decision, the button can say how many it lands
on, and undo puts it back.  So with several picked the panel now offers
`Paint n faces...`, `Back to default`, and `Change n...` for the pens - faces
excluded from that last one, because they are painted rather than inked, and
guides excluded because they never took a color.  Widths and sizes are still
one at a time.

`PaintSelectedFaces` took a `Shown` of -1 to mean the whole selection;
`InkSelectedThings` is the pen half.  `bulk-color` in the drive suite draws
two rectangles, picks all ten things with a box drag, and paints both faces
red in one trip through the picker - the shot shows "2 faces painted."

---

## The GIFs are gone: the manual is WebP - 18 September

Done, the same evening the plan was written, because LazInk's decoder
landed: "the new lazink is now rendering webp. i would say ditch all the
gif files and use the nice crisp webp files."

Twenty-one animations re-recorded, forty references swapped across
eighteen pages, the GIFs deleted.  Checked in the program rather than
assumed - the help window opens the snapping page, shows the WebP, and
*animates* it.

**The plan below said the saving would come from the format.  It did not.**
It came from a bug the plan had not noticed: the recorder was scaling its
1100 pixel grab down to 700, and every one pixel line in the manual had
been a two pixel gray smear since the first recording.  The owner spotted it by
eye - "it is not nearly as crisp as what i see in the xephyr screen when we
record" - and fixing it made the pictures both sharper and smaller.  The
format change on its own was worth little; the pipeline was worth
everything.

What the manual weighs now: 20.1 MB of blurry GIF became 14.2 MB of
lossless WebP at full resolution.

The style went over at the same time, since every page was being touched:
sections have a rule above them so a long page has somewhere for the eye
to stop, the page head is underlined in the accent rather than the same
gray as everything else, captions read as captions, and the title is
bigger.

---

## The plan it replaced, kept for the measurements - 18 September

*(Written before any of it was tried.  Its numbers are honest and its
conclusion about recording rather than converting was right; what it missed
was that the pipeline, not the format, was where the loss was.  `gif-shot.sh`
below is `tools/shot.sh` now and writes WebP only.)*

From a note: "i think we may need to make a plan to replace all our gif files soon
with smaller cleaner crisper animations... maybe there is a converter we can
use or just record some new ones as i think we kept our recorder scripts?"

We did keep them.  **Twenty-one animations, twenty-one scripts, one to one** -
every picture in the manual can be made again from `tools/gif-*.txt` without
anybody driving a window.  That is the fact the whole plan rests on.

### What it is worth

Converted straight across with `ffmpeg -c:v libwebp_anim -q:v 60`:

| | |
|---|---|
| the 21 animations | **20.1 MB -> 9.2 MB (45%)** |
| the whole manual | 23 MB -> about 13 MB |

The worst offender converts best: `tool-orbit-snap` goes 3,340 KB to 735 KB,
which is 22%.  Quality on one file: lossless 559 KB, q75 525 KB, q60 416 KB,
q50 365 KB - so q60 is about the knee and lossless is not worth it even on
flat interface color.

### Convert or record again?

**Record again**, and the reason is not purity.  A GIF has already been
crushed to 256 colors with dithering, so converting one gives a smaller file
**of the damage** - and worse, dither noise is expensive to encode, so we
would be paying WebP bits to preserve an artefact we never wanted.  A fresh
recording never quantizes at all: the grab is true color and goes straight
to WebP.  Expect it to beat the 45% above *and* look better.

Conversion stays the fallback for anything with no script - the
exported robot turntable on the README, say.

### What has to happen first

**LazInk has to read WebP in a shipped build.**  The same HTML serves the
website and the manual inside the program, and there is no `<picture>`
fallback to lean on - so the day the pages say `.webp`, a program that cannot
read it shows holes where the pictures were.  So: one commit, all
twenty-one at once, landing *after* a LazInk release with WebP in it.
Browsers have read animated WebP for years; the program is the whole
constraint.

**Reading is not writing**, and it is worth keeping those apart.  LazInk
reading WebP gives us nothing for making them - that is `ffmpeg`, which is
already what `tools/gif-shot.sh` pipes its X11 grab through, so the change
there is the output codec and a `.webp` extension rather than a new
pipeline.  `tools/turntable.pas` is the exception: it writes through
BGRABitmap's animated-GIF writer, so it keeps making GIFs until BGRABitmap
grows a WebP one, and its output gets converted afterwards if it matters.

### The order, when the day comes

1. `gif-shot.sh` learns a WebP output (codec + extension), keeping GIF.
2. Re-record all twenty-one from the existing scripts, at q60.
3. Swap the twenty-one `<img src>` in the pages, delete the GIFs, in **one**
   commit so the manual is never half one thing and half the other.
4. Check the in-program manual on the drive suite before it ships - that is
   the reader the website cannot tell us about.

---

## Sexier pipe, and the frame cost that came with it - 18 September

From a note: "the iso pipe fitters thing should build some sexier pipe too and we
now need the option to have it as black pipe or stainless... Probably could
make them smoother as well if our circles had more points."

* **Material**: `TPipeFinish`, black carbon steel or stainless, a box in the
  spool dialog, and the color put on in `Regroup` - which is the one pass
  that sees every face, including the ones `TWorkDoc.Sweep` makes for
  itself and never tells anybody about.
* **Rounder**: `PIPE_SIDES` 24 to 36, and `BEND_STEP` from fifteen degrees
  to seven and a half, so a long-radius ninety is twelve steps instead of
  six.  The spool test now counts a ring of facets per step of the
  centerline rather than a hard number, so it stays true next time.

**And then the bill arrived**: a two-leg spool went to **70 ms a frame**.
The profile said 90% of it was painting faces - 1,048 of them taking 64 ms,
about six times what the broom's faces cost each.

The reason is worth writing down because it is general.  `FillLoops` clears
its whole coverage row before every row of a face's **bounding box**.  For a
fat polygon that is fine.  For a long thin one lying on the diagonal - which
is *every facet of a pipe* - the box is enormous beside the polygon, and
nearly all the work was zeroing entries no crossing ever reached.  It now
remembers the stretch it actually wrote and clears only that.

| drawing | before | after |
|---|---|---|
| 2" spool, 1,048 faces | 70 ms | **34 ms** |
| the broom, 1,108 faces | 15 ms | 14 ms |
| the etch-a-sketch toy | 20 ms | 19 ms |

So the pipe pays for its extra facets and the rest of the program gets a
little for nothing.

**One thing chased and found innocent.**  A close look at the pipe shows
fine stripes along it, and the first guess was that all 972 soft facet
joins were being drawn.  Counted properly - building the renderer's own
edge index outside it - **30** of them are drawn, which is the silhouette
and nothing else.  The stripes are the **flat shading**: each facet is one
constant tone, so a curved surface always steps, and more facets makes the
steps finer rather than smoother.  The real answer to "smoother" is
interpolating the shade across a face - a renderer change, not a pipe one -
and it is not written down anywhere else, so it is written down here.

---

## The fitting dialog will not take a coat of paint - 18 September

From a note: the fitting dialog was worth moving over to the BGRA controls
so that it carries more of the program's own look.

**Tried the cheap way first and it does not work.**  The other dialogs are
built in code out of BGRA controls and skinned as they are made; this one is
a designed form, `uTransition.lfm`, with eighty-four controls on it:

| | |
|---|---|
| TLabel | 36 |
| TEdit | 20 |
| TComboBox | 7 |
| TButton | 7 |
| TRadioGroup | 6 |
| TCheckBox | 2 |
| TPageControl, TTabSheet, TPaintBox | 5 |

So rather than convert them, a pass was written that walks the tree and puts
the theme on anything that honors `Color` and `Font`.  The form went dark,
the edits and combos and labels came with it - **and the captions on all six
radio groups and both check boxes vanished.**  On GTK3 those captions are
drawn by the widgetset, which ignores `Font.Color`, so they stayed dark on a
now-dark background.  Leaving those two kinds alone does not help either:
they inherit the form's color, so darkening the form alone is enough to
lose them.

Reverted, and the dialog is native and readable again.  The finding is the
useful part: **this dialog cannot be themed by repainting.  The radio groups
and the check boxes have to be replaced**, and once those go the buttons may
as well go with them.

The job, when it is wanted:

* the six `TRadioGroup`s become panels of BGRA radio buttons - there is no
  drop-in, so this is the real work and it is most of the day;
* the two `TCheckBox`es and the seven `TButton`s swap for their BC
  equivalents, which is a class change in the `.lfm` plus whatever
  properties do not carry across;
* labels, edits and combos are then a two-line `Dress` walk of the kind
  already written and thrown away - it is in this commit's history if it is
  wanted back.

Worth doing when the shop tools get their next pass, and not before: the owner
has already said the shop tools need more work, and reskinning a dialog that
is about to change shape is work done twice.

---

## TDF corners in the fitting builder - 18 September

From a note: "in the duct fitting builder we have tdf flanges... except the picture
isn't complete.  I would like to have a tdf option to have it drawn with the
cornermatic corners installed or like we have it now."

Right - a TDF's four sides each stop their own width short of the corner so
the next one has room to fold, and the builder drew exactly that: a flange
with a square hole at each of the four corners.  True of the flange coming
off the machine and not true of anything that ever went on a job, where a
stamped corner is dropped in and crimped to tie the two flanges together and
give the bolt something to go through.

**A new kind rather than a checkbox**, because the ends are already chosen
from a list and `deTDFCorner` next to `deTDF` reads as the choice it is -
and because the list in `uTransition` is built from the enum, so the wizard
picked it up without being touched.  Added after `deTDF` and not at the end:
nothing writes the ordinals to disk, which was checked before moving them.

The piece itself is the six-sided L that fills the gap - out to the end of
one flange, round the outside of the corner, back to the end of the other,
and in to the corner of the duct - with the same fold back along its two
outer edges that the flanges have.  It is drawn in a pass of its own after
the walls, because a corner belongs to two walls rather than to either and
drawing it from inside the wall loop would put two in every corner.  A
corner whose wall has been left out for the caller - a tee's branch - is
skipped: there is nothing there to tie together.

`TestTDFCornersGoInTheGaps` checks the count (four corners, three faces
each), that each is the six-sided L, and the one that matters on a job:
**the fitting is exactly as big with the corners in as without**, so a
corner cannot stand proud of the flange and foul the next piece of duct.

---

## A broom, and it became the third example - 18 September

From a note: "a very elaborate broom like a kitchen broom for sweeping floors with
a lot of bristles and I want you to color the faces properly" - then, once
it was up: "we are going to want it to be one of the example models if it
comes out good."

It is `examples/make-broom.pas` now, in the same shape as the other two: it
writes `examples/broom.hsk` and the carried unit `uExBroom.pas`, and one
line in `uExamples.pas` lists it.  1,324 things, 1,108 faces, 170 bristles.

**Why it earns its place** - the toy and the glass are both near-white,
because until the 17th that was the only thing a face could be.  This is the
one that shows what a material is for, and it uses nothing else: not a pen
color on it anywhere.

Two things were found by looking at it rather than by reasoning, and both
are written into the generator and the examples README so nobody tidies them
away:

* **the bristles carry no edges.**  A bristle is a tenth of an inch across
  and would carry twelve.  With edges on, all hundred and seventy came out
  as a single black wedge at any usable zoom - the ink swallowed the color
  completely.  Taking them off dropped the model from 3,724 things to 1,324
  and is the only reason the banding can be seen at all.
* **every bristle is a little different**, from a hash of where it sits.
  Identical and straight reads as a comb.  Deterministic, so the drawing is
  the same bytes every run - which the example test insists on.

The example tests took it without complaint, which is the part worth
recording: same bytes inside and out, every face belongs to a solid, it is
closed and will print, and it stands on z = 0.  1,108 faces also makes it
the heaviest thing in the folder and so the honest one to open when
somebody asks how the program copes with a real model - about 15 ms a frame
in orbit.

---

## The cube has no way out of a face - 18 September

From a note, watching the animation: "you click the top of the cube and it rolls
down so you miscalculate how far down you need to click the cube to get it
to change the view again."

He was reporting a bad recording and found a real gap doing it.  **Once you
are square on to a face, the cube draws as a flat square** - no corners, no
edges, nothing on it to click.  The cube took you there and cannot bring you
back; you need Ctrl and an arrow, a drag, or the VIEW button.  Every other
program's cube keeps a way out at that point: Revit and Fusion put little
arrows round the edge of it for stepping to the next face, and most keep a
sliver of the neighboring faces visible so there is still something to aim
at.

**Built the same evening, and it turned out to need no new targets at all.**
From a note: "you need to be able to access the edges still even though you flipped
it flat to the top ... they should highlight easily to show that you can
switch back to those views."

The eight cells round the border of a face were *already* hit - `CubeAt`
classifies anything past `BAND` (0.65 of the half-width) as an edge or a
corner, whatever the view.  They were only never **drawn**: `PaintCube` drew
each face's outline and nothing inside it, because on a three-quarter view
the cube's own edges say where the cells are.  Square on there are no such
edges, so the ring was invisible and the control looked like a dead end.

So: when a face is nearly square on - `Lit > 0.97`, about fourteen degrees -
its two cell divisions each way are drawn faintly.  An ordinary
three-quarter view is unchanged, which was checked on screen rather than
argued.  Hovering already highlighted the cell and names it in the corner;
that now has something visible under it.

`TestCubeKeepsItsEdgesWhenFaceOn` holds the behavior down: looking straight
down, the middle of the square is the face, the four sides are edges, the
corners are corners, and the four sides are four *different* places to go -
a ring that all led to the same view would be decoration.

The animation was re-recorded to show it: click the top face, rest on the
ring, click it, and you are back out at BACK RIGHT TOP.

---

## The cube, the tape, rotate, and the report page - 18 September

Three animations, all of them of things a still picture genuinely cannot
carry:

* **the view cube** - a face, then a corner, then Ctrl and an arrow.  The
  point of the cube is that every click *flies* instead of jumping, so you
  keep your place, and that is exactly the part a photograph loses.
* **the tape** - pulled off an edge into the face, leaving a dashed guide
  line parallel to that edge.  The page had the rule in a table; now you can
  see the difference between pulling along an edge and pulling off one.
* **rotate** - picked, center, reference, then the angle **typed**.  A swung
  angle is a number nobody chose.

**Rotate also needed surgery rather than a picture.**  It had two sections
about which plane it turns in, one called "Which way it turns" and one
called "Which plane it turns in", with the missing-picture box wedged
between them - so the Alt behavior built yesterday was documented in a
section the reader had already passed.  One section now, in the order the
question actually arises, and the copy trick has a heading of its own.

**`reporting` was the TLC pick**, because it is the page that serves the
thing the owner actually wants - real people sending real reports.  It was
already accurate about what goes in a report; what it never said was what
happens afterwards.  It now says: the postbox is anonymous, nothing says who
sent it, **so nobody can write back** - if you want an answer rather than a
fix, this is not the road - and what you get instead is the fix with a line
in What's new.  Plus a "things not to worry about" list, because the reports
that never get sent are the ones where somebody was not sure it was a bug.

Six pages still carry the "this page is a skeleton" footer.

---

## Four more pages, and what is deliberately not documented - 18 September

`solids` got the animation - one edge off a box, then `/holes` drawing every
unmatched edge in red round the opening, which is the difference between
being told a shape is open and being shown where.  Its coordinates came out
of `tools/frame.pas` on its first real job, which is the point of building
it.

`units` was headed "three different settings that people mix up" and then
listed four; it says four now, and gained the sentence the whole page exists
to deliver - **snap is the only one of them that moves anything**.  `sheets`
gained what happens through an update, which was built on the 17th and
written down nowhere a user would find it.  `toy` got a short "worth
knowing" and nothing else, which is what was asked for: the toy explains
itself, and a page that says so at length is a page nobody needs.

**Not documented on purpose**, and worth keeping a list of so it does not
get done by accident:

* **the text tool** - From a note: "I don't think it is quite exactly SketchUp like
  yet."  Documenting it now would fix the wrong behavior in writing.
* **the shop tools** - his own, and due for more work.  When they are
  settled they want **one still picture each and no animation** - they are
  not gestures, they are forms.

Seventeen pages still have no picture.  The ones that would most repay one
when their tools settle: `measure`, `rotate`, `unfold`, `cube`.

---

## The red band that was lying, and a tool so nobody probes again - 18 Sept

**The band.**  By report: "this red line seems to snap on the red axis which
is fine but it seems to be snapping red in multiple positions so something
may not be right."  The bar in his own screenshot said, at that moment, "the
points only - no axis, nothing parallel" - Alt had turned the axis
inferences off.  The rubber band colored itself by asking `AxisAlong`
whether the line happened to lie along an axis, which takes no notice of
what Alt has switched off.  So it went red whenever the line drifted onto
red, with nothing holding it there.

The color **is** the inference: red means "I am holding you on red".
Saying it while holding nothing reads exactly as he described - a snap that
keeps coming and going.  Now the band only takes an axis color when the
cursor is allowed to infer one; a lock put on with the arrows still colors
whatever Alt says, because that one is held.

**The tool.**  `tools/frame.pas`.  Writing an animation used to be: guess a
CAMERA line, drive a throwaway probe script, look at the shot, guess again -
three or four rounds a drawing.  It now loads the drawing, fits it to the
recording window, prints the CAMERA line to paste, and then prints **the
client coordinates of every corner, midpoint and face center**, which is
what the script actually needs.

Two things it knows that cost an hour to find out:

* the last two numbers on a CAMERA line are measured from the top-left of
  the **canvas**, not the window - about (156, 75) in at 1100x650;
* the third number is **not** pixels per unit.  It is a magnifying glass
  over the drawing's SCALE, so the conversion is
  `Ppu = PixelsPerUnit(units, scale, dpi) * zoom` - which is why the first
  version framed a drawing at 2786%.

Checked against the program rather than argued: the line it printed for
`gif-cross.hsk` frames it at 116% and the corner it named is under the
cursor with ENDPOINT showing.

---

## The offset page, and a thing the docs found - 18 September

From a note: "The offset tool probably needs a gif and the old image is showing the
floor grid wrong."  It was - `tool-offset.png` was taken before the grid
became a floor in the positive quadrant, so it showed a grid stretching over
the whole world, negative side and all, and dated the page.  Thrown away and
replaced with two animations.

**The pair is the point.**  The first offsets the top of a box in by 2'-0"
and pushes the middle **down** 8'-0" - a tray.  The second does the same
offset and pushes the **border up** 3'-0" - a rim.  Same tool, same two
clicks, opposite results, which is the thing the page had been saying in
words: the offset decides nothing, it just leaves you two faces where there
was one.  Both sizes are typed rather than dragged for, so the numbers in
the picture are numbers somebody chose.

**And the page was wrong about circles.**  It said "offset a circle and you
get a ring".  You get the second circle, at an exact distance all the way
round - but the band between them is **not a face**: the status bar says
"1 face now - nothing new closed", and push/pull on the band answers "pick a
start point first".  A ring is an annulus, an outer loop with a hole in it,
rather than a simple closed loop, and the region finder is not making one.
So you cannot offset a circle and push the wall up to get a pipe.

That is worth a decision rather than just a corrected sentence: either the
region finder learns to close an annulus, or this stays a known limit.  The
page now says what actually happens and points at the drill instead.  Found
by writing the documentation, which is the argument for writing it.

**Noted for the next still picture:** one that shows the paper, the grid or
the axes will go stale when those change.  Prefer an animation of the tool
doing its job, framed on the geometry.  Written into
`docs/help/shots/NEEDED.md`.

---

## Four more help pages - 18 September

`snapping`, `planes`, `drill` and `dim`.  Eighteen pages still have no
picture; these were the four where a still one would not have done the job.

* **snapping** - the cursor walks along a single edge, touching nothing
  else, and the diamond changes color and name at every stop.  That is the
  page's whole argument made visible: read the word, do not trust your aim.
* **planes** - the same rectangle tool twice with nothing changed between,
  landing flat on the top of a box and then upright on its side, with the
  PLANE reading changing to say so.  This is the thing that catches people
  out in 3D and it cannot be photographed, only filmed.
* **drill** - the circle first, then the drill, because the mistake people
  make is expecting the drill to make the shape.  It takes one that is
  already there.
* **dim** - corner, corner, then **out**: the third click is the one nobody
  expects.

**A note for the next time somebody records one.**  The `CAMERA` line in an
`.hsk` measures its last two numbers from the **canvas's** top-left corner,
not the window's - about (156, 75) in at 1100x650.  An hour went on that.
The way to get coordinates is still the same: drive the drawing with a
throwaway `tests/drive/probe.txt`, take a `shot`, and read them off it -
hidctl's shots are in client coordinates, which is exactly what the scripts
take, while the recordings film the whole screen including the title bar and
are a good deal less useful for measuring.

---

## A theme switch on the manual's website - 18 September

From a note, reading the manual on his phone: "I think we will want a toggle
link/button in the html."

`docs/help/theme.js`, and the thing worth remembering about it is where the
button comes from: **it is built by the script rather than written into the
pages.**  The same files are rendered two ways - by a browser on the website
and by LazInk in the program's own help window - and LazInk has no
JavaScript at all.  A button in the markup would sit there in the program
doing nothing when tapped.  Built in JavaScript, it simply never exists
there, which is right: that window already wears whatever theme the program
is wearing, handed over as a stylesheet by `PageWithMode`.

Three states, because two would be a lie about what Auto means.  The choice
lands as `data-theme` on `<html>` rather than a class on the body, because
the palettes are custom properties on `:root` and that is the only place an
override can beat them - `:root[data-theme="light"]` at 0,2,0 against the
media query's 0,1,0, so it wins whatever the order.

The first half of the script runs while the page is still parsing, on
purpose: waiting for the document would flash the wrong theme on every page
turn.

Checked, because none of it is visible from here: node ran the logic against
a stub DOM - starts on Auto with no attribute, builds one button, cycles
auto/light/dark and saves each, restores a remembered choice on reload, and
survives storage that throws the way a private window's does.  And the
in-program help was driven and photographed to make sure LazInk skips a
`<script>` tag rather than printing its contents.

---

## Four more help pages, and a page for something unbuilt - 18 September

`select`, `erase`, `faces` and `protractor` had no pictures.  They have one
animation each now, all recorded against `tools/gif-box.hsk` - a box built
by `tools/mkbox.pas` rather than typed out, so what the recordings open is a
real solid made the way the program makes one.

* **select** - one click, two clicks, three clicks, then a dragged box, with
  the count in the corner going 1, face, 18.  The page gained the thing that
  catches people out: the three clicks are one gesture, not three, so a
  pause in the middle picks twice instead of picking more.
* **erase** - two edges off the lid, and the lid goes with them.  The frame
  that teaches is the one after: pale blue everywhere, because you are
  looking at the backs of the faces from inside the box.
* **faces** - the healing story end to end, and a new opening section
  saying the thing the rest of the page hangs off: a face is not drawn, it
  is what a closed loop of edges encloses.  Also now documents painting one,
  which went in yesterday.
* **protractor** - the three clicks and the guide left behind at 39.7
  degrees, plus what it is actually for: `8:12` and the rafter line.

**`parts.html`** is a page for something that does not exist, which is
unusual enough to say why: the idea now has a name, a place in the contents
and an explanation of why it is waiting, so it reads as coming rather than
missing.  It points at `docs/groupplan.md` for the detail.

---

## A face is painted, not inked - 17 September

From a note, testing: a face set to red was "not looking red at all ...
its still like gray over red", and asking whether the default face was still
being drawn over the chosen color.

Nothing was drawn over it.  The fill was
`MixPix(Col, FACE_MATERIAL, 0.92)` - eight percent of the chosen color over
SketchUp's near-white - so pure red landed on (250, 230, 226), and the
shading then took a side face down to (200, 184, 181).  Red and green came
out the same warm gray, which is exactly what he was seeing.  In plan it was
worse: a second mix toward white left about three and a half percent.

The eight percent was not cowardice.  **One field, `Ink`, was doing two
jobs** - the pen color of edges and the material of faces - so anything
stronger would have turned every face drawn with a red pen red.  The ratio
was a symptom; the conflated field was the fault.

So faces got a material of their own: `MatSet` + `Mat` on the entity, apart
from `Ink`.  A flag rather than a color standing for "none", because an
entity is born by being `FillChar`ed to zero and black had to stay a color
you can paint with.  Unpainted faces render exactly as they always did, so
no drawing anybody owns changes under them.  It saves as a `MATERIAL` line
of its own after the `FACE` - the same trick as `TEXTSIZE` and `HOLE`, so an
older reader skips it, and a drawing with nothing painted is byte for byte
the file it was, which is what keeps the examples' checksums still true.

The entity panel paints, and paints **every picked face** when the one it is
showing is among them - a box is six faces and nobody wants six trips
through a color dialog.  A swept surface takes the profile's material, the
way it already took the profile's pen.  Push/pull's moved cap keeps its
material because the cap is the same entity moved; the new side walls come
out default, which is what SketchUp does.  Backs stay pale blue whatever the
front is painted - also SketchUp.

Not built: named materials, textures, a materials browser, painting a back
separately from its front, and a paint-bucket tool.  The panel is the only
way in.

---

## Loose ends, small

Gathered from the notes further down, so none of them is only findable by
reading a write-up of something finished.  Roughly smallest first.

* **TlsLib4Pascal: not yet, and here is the trigger.**  Floated three times
  now, so the answer is written down rather than argued again from nothing.
  What we do today: Windows talks through WinHTTP, Linux and macOS through
  fphttpclient with `opensslsockets`, which opens the system libssl at run
  time.  **We ship no TLS and spawn no program on either** - the dependency
  is the operating system's own, which is also what patches it and what
  supplies the list of certificate authorities to trust.
  Swapping in TlsLib4Pascal (MIT, TLS 1.3 and a hardened 1.2, one dependency
  in CryptoLib4Pascal, an fcl-net adapter so our call sites do not change)
  would delete **none** of our code - it is a uses clause and a config - and
  would take on two things we do not carry today: the trust anchors (OS
  harvest is opt-in there, otherwise we bundle CA roots that expire, and an
  expired bundle in a shipped build is an update check that stops working
  for everybody), and the patching, because a TLS flaw becomes our release
  rather than their `apt upgrade`.
  **Do it when** a report says libssl is missing or the wrong version -
  musl, a minimal container, a distro that names OpenSSL 3 differently.
  Then it goes in as a *fallback* rather than a replacement: try the system
  first, fall back to pure Pascal.  `uNet.NetBackend` already returns the
  name of the backend as a string, so the seam is there.
* **What's new shows its bullets as solid blocks** - a LazInk fault, not
  ours, and it is written up with a repro and a one-line fix in
  `../LazInk/bugs/2026-09-19-brush-leak-after-hr/`.  Every version heading
  in the notes is followed by `---`, and a rule leaves its color on the
  canvas brush; the next list item's text is then drawn over an opaque
  background in it.  It happens in every theme - it is simply louder on a
  pale one.  Nothing to do here until that lands; then look again.
* **More rows in the entity panel**: **radius on a circle**, **the plane an
  arc was drawn in**, and a **name on a solid** (that last one wants a field
  in the file).  Color and width went in on 17 September.
* **The pull-while-dragging orbit snap**, as an experiment.  The release
  version is built; the questions are kept with its write-up.
* **The cursor square wipes canvas drawing under it** for the rubber bands
  and canvas text of the tools that still paint straight onto the window.
  The face wash and the fillet arc are handled.  The general fix is
  compositing the cursor with alpha.
* **Arcs: SketchUp's Alt tangent lock**, and an arc tangent off the end of a
  single line.
* **Typed resize by a dimension**: an arc only partly past the moving plane
  comes out wrong, nothing between the ends stretches, and there is no
  handle to drag.
* **The manual's words against the tools as they are now** - one pass, page
  by page.  The eraser page was found a version behind once already.
* **The plan view**: poché on a cut wall, 2D mode as a lens, and whether
  `fit` should frame only what is in the slice.
* **A GIF of the plan cut sweeping up the building** instead of the camera
  turning - nearly free now the recorder exists.
* **Loose faces adopted into a solid** when they close one with faces that
  already belong to it.
* **Drive scripts that compare their screenshots** against kept ones, so a
  pass means something.
* **Tie `TOOL_NAMES` to the command rows that set a tool**, if another
  renamed tool goes stale in the list.
* **Unexplained, needs a session that catches it**: the eraser once drew a
  dimension off a guide point (15 September).
* **Open hunt**: the surface guard's canary, last seen reading 4.07615 on 15
  September.  Notes in uSurface.
* **Then re-measure, and only then ask about OpenGL** - the last step of the
  order agreed on 15 September; the rest of it is done.

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
   wanted (two circles sharing a center on two planes, same radius: offer
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

* **The eraser's modifier keys - half done, 14 September 2026.**  Ctrl
  softens an edge and Ctrl+Shift brings it back, which is SketchUp's Ctrl and
  Ctrl+Shift, and both read the `Soft` flag that already existed.

  SketchUp's plain Shift, which *hides* an edge outright, is not done and is
  not a modifier - it wants a `Hidden` flag on an entity, a place in the
  file, and a "show hidden geometry" switch, because without a way back a
  hidden edge is an edge somebody has lost.  That is a feature, and it should
  be built as one.

* **Custom mouse cursors - looked at 14 September, not done on purpose.**
  The obvious half is already there: the drawing takes a crosshair, orbit and
  the pan take the four-way, the chrome takes a hand.  What the entry means
  is a *glyph per tool* as a real OS cursor, and that is not a small thing
  and could easily be worse than what is there - Windows wants particular
  sizes, and a hotspot out by two pixels is a drawing program that feels
  wrong to use.  The glyph riding beside the crosshair was a deliberate
  choice, not a stopgap.  Leave it until somebody says the crosshair is not
  enough.

* **Neon on a light screen** is muted - the cost of going alpha-based so a
  drawing survives a theme change.

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
sixteen unused locals.  **Twelve days later, 17 September, both have doubled**:
`uMain.pas` is 22,914 lines and `uWork.pas` 11,810.  The case below is
stronger than when it was written, and the split is still mechanical.

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
  screen` 2,037, `pro mode: the tools` 1,315).  Mechanical, and no behavior
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

From a note, 17 September: "we do not want python in my public git ... I despise
python."  None is left in this repository or in LazHIDControl or LazInk:

* `build.sh` turns `WHATS_NEW.md` into `whatsnew.inc` with awk now, byte
  for byte what the Python heredoc wrote.
* `tests/run-cmds.sh` compiles `tests/cmdcheck.pas`, which does what the
  Python did and one thing more - it holds the command list's other words
  to the dispatcher.
* The bug-bin workflow reads its JSON with `jq`.
* LazHIDControl's README example is bash; LazInk's two help checks are
  Pascal programs reading the pages with the FCL's HTML reader.

**Scripts are Pascal now, through `instantfpc`** (17 September).  It ships
with Free Pascal: a `.pas` file with `#!/usr/bin/env instantfpc` on its first
line runs directly, compiled the first time and cached after that.  On this
machine the toolchain's `fpc` is not on PATH, so `~/.local/bin/instantfpc` is
a three-line wrapper that passes `--compiler=`.  A file with a shebang no
longer compiles with plain `fpc`, which is the one thing to remember.

`tests/cmdcheck.pas`, LazInk's `tools/audit_help.pas` and the report
collector all run that way.  **The collector, `tools/fetch-reports.pas`**,
replaces `fetch-reports.py` (both in the ignored `tools/`): the same name
check, done a character at a time instead of with a pattern whose `$` also
matched before a trailing newline; the same caps, enforced while the upload
arrives rather than after; the same banner, flags, drawings and index.  It
finds `reports/` from the folder it is run in, or `--root`.  **Keep the
Python one beside it until the Pascal one has collected a day's reports and
agreed** - then change the cron line and delete the `.py`.

---

## TLS in Pascal, if we want it - TlsLib4Pascal

From a note, 17 September: a pure Pascal TLS would mean no OpenSSL at all -
worth watching, not worth integrating yet.
<https://github.com/Xor-el/TlsLib4Pascal>

**What it is.**  TLS 1.2 and 1.3 written in Object Pascal, MIT, by the
author of CryptoLib4Pascal - which is its one dependency.  Free Pascal
3.2.2 and up, client and server, PKIX path validation with RFC 6125 name
checking, OCSP and CRL, optional use of the machine's own trust store,
key pinning.  AEAD suites only; no CBC-HMAC, no RC4, no 3DES.  Small
project - tens of commits, a couple of dozen stars - which matters for
what follows.

**What it would replace, and what it would not.**  Only the Linux half.
`uNet` already has two floors: Windows goes through WinHTTP, the system's
own, and that stays - it needs no library from us and it follows the
machine's proxy and certificate store.  Linux uses `opensslsockets`, which
is the distribution's OpenSSL, loaded by name at run time.  So the honest
statement of the gain is: **the Linux build would stop needing libssl on
the machine**, and would be one file the way the Windows one is.  That is
a real gain - FPC's OpenSSL loader has broken before on the 1.1/3.x
soname shuffle, and a program that is supposed to copy onto a stick
should not care which OpenSSL the machine has.

**What it would cost, said plainly.**  It is the same trade we turned
down for Windows in the other direction, and it deserves the same
sentence: the moment TLS is ours, its security updates are ours.  The
distribution patches its OpenSSL whether or not anybody here is awake; a
vendored TLS gets patched when we notice.  Against a well-worn OpenSSL,
a young pure-Pascal stack is the newer code in the position where being
wrong is worst.  None of that is an argument that it is bad work - it
reads careful, and the defaults are the modern ones - it is an argument
about who is on the hook.

**What this program actually does over TLS**, which bounds the risk: an
update check against GitHub's API, a help-docs zip, and an outgoing bug
report.  All three are ours talking to a named host, none of them carry a
credential, and a failure is an inconvenience rather than a loss.  That
is about as gentle a place to try a new TLS stack as exists.

**If we do it.**  Behind `uNet` and nowhere else - `NetGet`, `NetGetText`,
`NetPost`, `NetBackend` are the whole surface, and nothing above them
knows what is underneath.  Keep `opensslsockets` as a fallback for the
first release or two, with `NetBackend` saying which one answered so a
bug report tells us, and pin the CA set to the machine's `/etc/ssl/certs`
rather than carrying our own bundle.  Test it against a host that is
behind a proxy, and one with a certificate that has just expired, because
those are the two that a fresh implementation gets wrong.

Not now.  Written down so it is a decision rather than a discovery.

---

## Where this could go - 12 September 2026

Talked through with the owner after the barn reports.  The question was what this
could do that people are already asking FreeCAD and SketchUp for and not
getting.  Written down so none of it gets re-argued from scratch.

### What the program is for, said plainly - 13 September 2026

From a note: *"my goal is simply for any idiot to get into the program"* and
find that a scaled drawing is astonishingly simple - the way opening SketchUp
felt ten years ago, drawing a 3D model with no experience at all.

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
> pattern: one door, everything specializt behind it.  Adding a button to the
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
  of writing a flat color, times the Lambert term already computed there.
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

* **The drawing sheet - border, title block, revisions.**  From a note: "blue prints
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

* **PDF import, as lines.**  the daily problem: almost every drawing
  that arrives at work is a PDF and there is no way to scale it.  Bringing
  one in as our own 2D lines - then setting the scale off a known dimension,
  and adding revision clouds and notes over the top - would be worth a lot to
  anyone in the trades.

  Not started, and not to be started casually.  A PDF is a page description,
  not a drawing: vector PDFs give real paths and would work; a scanned one is
  a picture and needs tracing, which is a different project.  Wants a proper
  discussion first, including which library reads the page content - there is
  no chance of writing that from scratch here.

### Decided in passing

* **The file stays plain text; assets go in a zip.**  A `.hsk` you can read,
  diff and merge in git is a real differentiator and rare in CAD, so it stays
  the default.  A drawing that needs assets - textures, an imported PDF, a
  logo in a title block - saves as `.hskz`: a zip holding `drawing.hsk` plus
  `assets/`, the way ODF does it.  Text unless there is a reason not to be,
  and the reason visible in the extension.

* **The title block ranks higher than first written.**  For a regular Joe the
  moment is not drawing the box - it is **printing something that looks
  professional with his name in the corner**.  That is the artifact he shows
  somebody and the screenshot that gets posted.  Drawing the box is the
  setup; the sheet is the punchline.  It also has a home now: `PrintTileMarks`
  already draws in page coordinates after the model render, which is exactly
  the seam a title block lives in - so paper space is a new idea with a
  precedent rather than a new architecture.

### Why the rubber band is not the color of the plane

Asked for on 13 September, and it has been tried before.  Written down so it
is not tried a third time.

A line's color here is **the direction it runs in**.  A plane is named by
the axis it *faces* - that is the convention the arrows use, right for red,
left for green, up for blue - and that is the one axis a line lying in the
plane can never run along.  Color an outline on XZ green and every side of
it is labeled with the one direction it does not go in.  It reads as
information and it is the opposite of true.

What is real is the thing behind the request: while drawing you want to see
that you are still flat.  A single segment cannot say it - one line is one
direction and a plane takes two, which is exactly why a rectangle already
reads correctly with its red and blue sides.  So the plane says it itself:
`PaintHeldPlane` draws two short lines through the point along the plane's
own two directions, in their own axis colors.  Red and blue is upright, red
and green is flat.

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

**17 September:** the second half half-exists.  `/state` needed somewhere to
put sixty lines, so `ShowLongText` is a scrolling box with a copy button.
`/rendertime` and `/timings` use it too now, the same day.  The wrap is
still not done.

### The rectangle, on a plane that is not the ground

From a note, 13 September, flagged and deliberately left for later:

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

### Still to discuss

* **The other two visual worlds - and the owner has already solved this once.**
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

  That is what "handsome but official" means: a conventional desktop form,
  laid out the way a desktop form is laid out, whose buttons happen to be
  good looking.  It is the right answer for our dialogs and wizards.

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

  License is fine - `LGPL-3.0-linking-exception` permits linking into an MIT
  program.  Worth doing the next time a wizard needs work rather than as a
  project of its own, and `utheme.pas` is most of the way there already.

* **A control base class.**  The cut strip is the second hand-rolled control
  in a fortnight (after the command bar) and the pattern is the same each
  time: hit test, hover, press, paint into a TArtSurface.  One base class
  with subclasses for button, field, spin and slider is maybe 300 lines and
  would make the next ten cheap.  Worth doing the next time a control is
  needed rather than as a project of its own.

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
  outside, and the only thing that really knows is a closed solid.  Orienting away from the model's center
  would fix the barn and break a plan drawn on the ground beside a building.
  Making every face agree with its neighbors across shared edges cannot be
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

---

## Researched, nothing built

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

From a note: the heating and cooling makers publish models of their equipment and it
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

**A DXF importer is wanted.**  From a note, 15 September: it is the first way in.
Not built, and on this list on purpose.

### Somebody else's converter, as a door rather than a dependency

the idea, and it is a good one: rather than teach this program every
format, find the free converter that already reads them all, keep it OUT of
our build, and either hand its output to our importer or simply tell the
person where to get it and what to do.  Nothing bundled - they install it.

**Nobody has to install Python.**  the objection when this was first
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

License-wise all three are clean: running a program is not linking to it, so
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

The owner has a **Cricut Explore 3**.  The question was whether we can cut to it
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
`WriteSVG` writes width and height in inches or millimeters against the
viewBox, so the drawing arrives at its real size wherever it goes.
`TestSvgIsTrueSize` measures the wine glass at two zooms in plan and from the
front, and an independent renderer agrees: 366 px at 96 dpi for the 3.81 in
the file claims.

If a machine ever does open up - a Maker v1 with CutcutGo, or somebody cracks
the Explore - the work on our side is a G-code writer, and it is small: the
cut paths are the same projected polylines WriteSVG already walks.

---

## Waiting on something

### A GIF export that crashed after the fact

From a note, 14 September: exported a GIF on the Windows machine, opened it, and
thinks the program went down.  A report was promised and has not arrived; the
one that came in at 07:41 was about /reface and carries no crash file.

Nothing to go on yet.  What there is: the film is held whole in memory before
a byte is written - a twelve second clip at 900x492 is about two hundred
megabytes of frames - and the packing pass is already skipped past a size for
that reason.  If a crash file turns up, the stage it died in is in the report
now, frame by frame.

### Our own fork of BGRABitmap, for later

From a note, 13 September: he likes the project and wants to keep using and
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

From a note, having used it: "the workflow for recording a gif isn't too intuitive but
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

What is left of the idea below: more of them - the crown, and a few
deliberately wild ones.  **The checksum rule went in on 17 September**
(`PutExample` in uExamples): the settings keep a checksum of what was
written, an untouched file gets the newer version, and one that has been
saved over since is left alone.  `TestExamplesKeepEdits`.



From a note, 13 September.  The program ships as one executable on purpose and that
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

### Alt cycles the inferences, and the magenta pair that needed building

From a note, 17 September: "we do want you to use the alt key to cycle inference
for the line tool and probably others like SketchUp does.  Gotta remember we
need to try to be as compatible with SketchUp as possible... sort of a
SketchUp clone but of course better in some ways.  Our goal is to almost be
able to let a SketchUp developer open heckers sketch and be productive
immediately."

That is the standard to hold this against, and it is the same bargain
Lazarus takes with Delphi: match what is there, be stricter where being
strict is better, and say where you differ.

Their cycle, from `docs/sketchup/05-drawing-basics.md`: after the first
click, Alt goes all inferences, all *linear* inferences off, parallel and
perpendicular only.  Two halves had to be built.

* **The third stop needed a magenta pair we did not have.**  `DirTry` is
  `AxisTry` generalised to any direction - the same screen-space arithmetic
  - and `ParPerpTry` offers along the reference edge and square to it in the
  working plane.  The reference is the edge the line was started on, or the
  piece just drawn, whichever came last.  `FParPerp` says which is showing;
  the band and the dotted line go magenta, and the card says PARALLEL TO
  EDGE or PERPENDICULAR TO EDGE.
* **Alt, and what it used to do.**  Ours held the working plane, which
  SketchUp has no equivalent for.  It still does - *before* the first click,
  where SketchUp puts nothing on the key.  After it, Alt is theirs.  The
  mode resets with the tool, and pressing it works the cursor out again
  where it stands rather than waiting for the next twitch of the mouse.

`inference-alt` in the drive suite walks all five states.

**And then the other three, the same afternoon** - `alt-tools` drives them:

* **The arc's tangent lock.**  Theirs wants the edge hovered before the
  first click; ours already knows which edge the first click landed on, so
  Alt at the bulge stage runs the arc out of that edge and holds it there.
  `TangentSagitta` in uWork: for a circular arc the angle between the chord
  and the tangent at an end is half the arc's own angle, so the sagitta is
  (chord / 2) * tan(half of it).  `TestTangentSagitta` checks the number and
  that the arc really does leave along the edge.
* **The offset's kept overlaps.**  `OffsetLoop` grew a `Tidy` parameter: the
  corner-squaring pass that went in this morning is what SketchUp does
  without Alt, and with Alt the loops stay as they fall.
* **The protractor's freedom.**  Ours takes the turning plane from the face
  under the cursor when the vertex is clicked; Alt stops it, and it lies
  flat unless an arrow picks a plane.

Flip's Alt - the object's own axes against the parent's - has nothing to
hang on: Flip is not built.

### The tape's two guides, and the manual in both modes - 17 September

**The tape.**  From a note, after checking SketchUp: "when i draw a point in from
the corner staying in the line it drops a point only... but if i used the
tape measure from the line and set it up into the face of the rectangle then
it does the guide line".  `TapeGuide` in uWork decides which, and
`TWorkDoc.RunsAlongEdge` asks every edge through where the tape started -
at a corner the click finds one of the two meeting there, and the run is
along the other one as often as not.  From anywhere else it still lays the
line across the run, which is ours and is what marks a distance from a
corner.  `TestTapeGuideKind`.

**Light and dark in the manual.**  "there should be a way to pass the etch
sketches current mode to the help docs so they can render the same way."
Three things had to be true at once: the website follows the reader's
system, the program follows the program, and neither needs the pages
rewritten.  A stylesheet handed in from outside does not work - the page's
own rules win, and its palette is custom properties on `:root`, which cannot
be reached from outside.  So `docs/help/style-light.css` holds the light
palette and nothing else; a browser pulls it in through the media query at
the foot of style.css, and the help window links it into the page as it
loads it (`THelpForm.PageWithMode`, which is why every page now goes through
`GoToPage` rather than `LoadFromFile`).  The window also re-dresses itself
on every open, since the theme may have changed while it was hidden.

**Pictures.**  Three pages that had none: revolve (a ball and a wine glass,
rewritten step by step with a what-went-wrong table), move (a side of a
rectangle stretched six inches), and the plan view (the cut traveling up
through the toy).  The recordings are `tools/gif-revolve-ball.txt`,
`gif-revolve-glass.txt`, `gif-move-stretch.txt` and `gif-plan-cut.txt`, with
two prepared profiles beside them.  Worth knowing for the next one: a
script's coordinates are the window's, the recording films the whole screen
including the title bar, and the two differ by about 26 px - which is how a
click meant for an edge landed on the face twice.

**Not done, and asked for**: Alt to cycle inferences the way SketchUp's line
tool does.  Ours is taken - Alt holds the working plane, which is in the
keys page - so it wants a decision rather than a patch.

### The grid is a floor, and the bar says more - 17 September

**The grid.**  From a note: "i am imagining a grid only being useful as a floor
reference for viewing... a virtual floor.  not really part of your drawing
but there as if it is in the drawing until i toggle it off."  So ISO uses
`PaintGroundGrid` as well as 3D - the isometric lattice was paper, and its
three families climbed the two walls - and the floor is ruled only where
both axes are solid, the positive quarter.  Darker (0.45, and 1.0 every
fifth line, in the theme's own grid color) because at 0.30 on a light
screen he pressed the button and thought nothing had happened.  It starts
off in a fresh copy, which is his call: "it should be off by default".

Worth knowing for next time: what looked like a screen-aligned paper grid
in his 3D view was the floor, seen from az -90 where one family runs up the
glass and the other across it.  The picture is the same either way; the
weight was the real complaint.

**The bar and the card.**  "there is some status helpers that pop up telling
you to use alt or ctrl keys and why... SketchUp does it in the bottom of
their status bar."  `SnapSays` puts what the cursor is holding on to in
front of the prompt, `ModifierTip` puts the keys that would do something
right now after it, dimmed, and `ShortKeys` is the same list short enough
for the card beside the pointer.  Only what is true at that moment: a
modifier named when it does nothing is tried once and never again.

**Guides, again.**  "the select tool shouldnt easily snap to guides...
sketchup makes it so the select tool needs to be right over it and it just
changes the color of the dash line to blue... not a thick blue highlight
like we do."  `HitEdge` takes a guide reach of its own (`GUIDE_PICK_PX`, 4
px, against 9 for an edge), used by the picker and the select hover but not
by the eraser, where rubbing a guide out is the point.  A guide under the
pointer is drawn in blue along its own dashes - `PaintGuideHover`.

**And what the frames cost with something picked.**  The report of 16:52
had frames of 44 to 84 ms with nothing happening but a mouse move: every
paint composited the selection over the whole picture and copied the whole
picture again for the face wash.  Kept between paints now (`FShotOK`),
rebuilt when the drawing, the selection or the face under the pointer
changes.  A full paint with 375 things picked: 24.2 ms to 14.5.

### An update that stood still, and a report about the etch-a-sketch, 17 September

**The update.**  The program was updated on Windows with a drawing open; the old copy
asked whether to save, he did not answer at once, and the new copy - which
waits fifteen seconds for the old one to let go - gave up and said another
copy was running.  Nothing was left running.  Now the old copy writes a
*handoff* (`heckers-sketch-handoff.hsk`: the session plus comment lines for
the file path, the sheet in front and which sheets are unsaved), closes
without asking (`FHandingOver`), and the new copy started with
`--updated-from` loads it (`RestoreHandoff`) - same file behind it, unsaved
still unsaved - and deletes it.  A handoff found on any other start is stale
and goes; the draft beside it is at least as new.  And if the old copy is
still there after fifteen seconds, the new one asks "Keep waiting / Give
up" (`KeepWaitingForOldCopy` in the .lpr) instead of calling it a second
copy.  `/handoff` does the old copy's half without an update, for testing.
Only updates *from* this version on get the first half; the waiting
question helps the one into it.

**The report** (12:58, v2026.09.17.5), three findings:

* *Offset inward flipped rounded corners.*  `OffsetLoop` offset every piece
  of an arc; taken in further than the radius, each piece came out
  backwards and the corner was a little loop the wrong way round.  Those
  loops closed tiny faces of their own - "6 faces now" where there should be
  2 - which is the "push/pull wasn't detecting faces".  Reversed pieces are
  now taken out and their neighbors met again, so the corner comes out
  square, as in SketchUp.  `TestOffsetRoundedCorners`, `offset-rounded`.
* *Lines behind faces while orbiting* was mostly pits lined inside out.
  `PushPull` assumed an opening is stored wound against its outline; a ring
  from the region finder can have it the same way, and then every lining
  wall faced into the material, was taken for a back, and let the edges
  under the ring show through.  The opening is turned round first now.
  `TestRingLining` checks the lining faces the opening, not only that the
  solid is closed - closed was passing either way.  Walls already in a
  drawing stay as they are: Reverse fixes them.
* *Smoothness.*  On his machine the paper was 31-47 ms of each orbiting
  frame with the grid on.  Three things: the paper's fill was made fresh
  every paint (now kept per theme and size, 5.7 ms to 0.7); the general line
  measured distance over a 3.5 px band where 1 px can be lit (`Pad` is
  `HW + 1`, the picture unchanged); and the ground grid now uses a Wu
  hairline, `TArtSurface.HairLine` (grid 18 ms to 6 here).  Quick frames
  were looked at and left alone: on his drawing they save 4 ms of 18.

### Six small ones and a color, 17 September

Picked six off the loose-ends list in one go, plus the logo color.

* **Aliases in the command list.**  `CMD_LIST` gained `Also`; typing one
  finds the row, the row says which word found it, and using one counts as
  using the command.  `tests/cmdcheck.pas` insists every word in `Also` is
  answered by the same branch of `RunCommand` as the name.
* **`/rendertime` and `/timings` in the copyable box** (`ShowLongText`).
  `/timings` keeps what it saw (`TimingLine`), because on Windows there is no
  console to read it from.
* **The cube from the keyboard**: Ctrl and the arrows, `CubeStep` in uCube,
  `TestCubeStepsWalkTheCube`.  **And a cube drag let go within eight degrees
  of a view clicks onto it**; Ctrl makes that from anywhere, the same as the
  orbit tool.  `cube-keys` in the drive suite.
* **Color and width in the entity panel.**  `TWorkDoc.SetInk` and
  `SetWeight`; `entity-style` in the drive suite opens the picker and takes
  a red.
* **The examples' checksum rule** and **no Python** - see above.

### The logo letters come up red when they are raised

From a note, 14 September: "i sort of like how i raised the letters and they have
red lines around the letters however i dont understand why the letters became
red, probably a bug!"

Not a bug in the program - the generator gives the letter faces the toy's own
red, the same ink as the body, on the reasoning that the logo is printed on a
red toy.  Flat, they read as dark lines on the frame because the lines over
them are black and the face is barely visible.  Raised a sixteenth, the sides
and the top are suddenly red on a body that renders pale, and it looks like
something went wrong.

The question is what the logo should be, not where the bug is.  Worth asking
The open question was whether the letters want the color of the frame - so raising one
reads as embossing - or a deliberate contrast color.  Whatever he says is a
one line change in examples/make-etch-a-sketch.pas.

**Done 17 September.**  From a note: "the color needs to be of the frame" - so it
looks embossed.  The letters already were the frame's color; what made them
red was push/pull giving the new edges the *face's* ink, so a raised letter
came out outlined in red on a body outlined in black.  The new edges take the
outline's ink now (`TWorkDoc.OutlineInk`), and a raised letter reads as
embossed.  `TestPushedEdgesKeepTheOutlineInk`.

### Small things done 13 and 14 September

* **Edges that partly overlap - DONE 14 September 2026.**
  `TWorkDoc.AddLineSplit`: a line drawn along one already there cuts both
  where they share, so the overlap is one edge and the tails are their own.
  Only loose lines - a line that belongs to a solid is part of something that
  was built, and cutting it up underneath the solid is a different and worse
  idea.  The line tool uses it; rectangles, circles and arcs still do not.

* **A leader that follows its edge - DONE 14 September 2026.**  If the whole
  of a line is moving, whatever sits on that line moves with it, so a note
  aimed at the middle of an edge travels with the edge.  Remembering which
  entity a note is tied to would be the thorough answer and wants a field in
  the file; this is the cheap nine-tenths of it.

* **More in the settings lists - DONE 14 September 2026.**  The color list
  has a row past the twelve swatches that opens the platform's own picker,
  which is the thing a row of swatches could never hold.  The palette stays
  twelve: a wall of swatches is a worse list, not a better one.

* **Light mode is harder to read than dark - DONE 14 September 2026,
  measured.**  The accent was the whole of it: at $1C7CD6 it made 3.7 to one
  against the light panel where the dark theme's accent makes 8.4, and the
  accent is text as often as it is a fill - the update line, a heading, the
  tool in hand.  It is $176BBD now, which is 4.7, and the quiet text went
  from 4.2 to 5.0.

  The other half was that text on an accent fill was written down as "dark,
  because the accents here are bright" in six places.  True of five themes
  and false of the light one, where it put pale gray on mid blue.
  `uSurface.OnPix` answers it from the fill's luminance instead, once.

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
  own dark colors, and `shots/NEEDED.md` listing the 25 screenshots wanted
  and what should be in each.  The pictures get grabbed by hand.

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
  what the move tool and the stretch behavior already run on.

  The geometry is not the hard part.  The hard part is the rule for *which
  end moves*, and the honest answer is the one the move tool already uses:
  the end you did not anchor, with a way to swap.  It works the same in plan,
  which un-scratches the 2D half for nothing.

### The plan view - one project, two halves

Agreed 13 September, and written out so it is not re-argued once somebody has
half built it.

**The diagnosis first, because it was wrong to begin with.**  the
complaint was that a 3D model looked like rubbish in the flat paper view and
that orthographic was to blame.  It is not.  Loading the barn and switching
to PLAN gives four filled slabs in two grays and nothing else - no walls, no
footprint, the building entirely hidden under its own roof.  Three things
cause it, and the projection is none of them:

1. **The faces are filled and Lambert-shaded in plan.**  The roof slopes come
   out different grays because they are tilted differently to a light source
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

The owner arrived at this from scratch and it is the correct answer.  The trade
name is a **cut plane**; Revit calls the settings **View Range** and gives it
four numbers (cut plane, top, bottom, view depth).  Ours is **two**: a top
and a bottom.  Everything between them draws.  Two is the right
simplification - four numbers is the kind of thing that makes Revit hard.

* **Roll the wheel to move the slice up and down through the building**,
  keeping its thickness.  Revit buries view range in a properties dialog;
  SketchUp makes you place a section-plane object in 3D, which is not a plan
  tool at all.  Nobody lets you travel up through a building by scrolling a
  plan.  This is a real differentiator and it is the part that would make
  somebody sit up.
* **The bottom of the slice is the drawing plane.**  One number does both
  jobs: the floor of what you can see and where the pencil is.  That is what
  a floor plan *means* - you draw on the floor and things go up from it.  Set
  the bottom to 9'-0" and you are drawing on the second story, seeing the
  second story, with everything below out of the way.
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
    recognize.
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

### The lesson of 13 September: it exists and nobody can find it

Twice in one day, and the second time from the person who commissioned the
feature.

* PLAN was not on the VIEW menu.  Everything built into the plan view this
  week - the cut, the drawing style, the dashed hidden lines - was reachable
  only by knowing `/plan`.
* Revolve has existed since 6 September.  It was called FOLLOW ME, which is
  SketchUp's name for sweeping along a path and nobody else's name for
  anything, and it sat behind the MORE door.  The owner went and asked a friend's
  CAD program for a lathe and came back to ask why we did not have one.

Neither was a missing feature.  Both were a name or a door.  So, as a rule
to check anything against before it ships:

> **A feature nobody can reach is a feature nobody has.**  Before it is
> called done: is there a way to it with the mouse alone; is it called what
> the trade calls it rather than what the program we copied calls it; and
> would somebody who had never been told go looking where it is?

`/plan` and `/revolve` both existed the whole time.  A command is not a way
in - it is a shortcut for somebody who already knows.

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
  it was caught is that the owner remembered what we called it.  Tying TOOL_NAMES
  to the rows that set a tool would catch exactly this and is worth doing if
  another one slips.

### Snapping has to answer "can I see it?", and half of it did not

From a note, measuring along the straight edges of the etch-a-sketch between the
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

From a note, comparing against SketchUp: it zooms in and out a great deal further
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
width of the window labeled 0'-6".  The table now runs from a sixteenth of
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

From the report of 15 September, alongside the dimension fault:

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

From a note, after the EdgeSnap fix: run these checks over all of the tools and
inspect the code, because snapping a line, snapping a point, and snapping a
point ON a line are three different questions and there is a lot of inference
behind each of them.

He is right, and the EdgeSnap bug is the argument: the rule it was missing
had been written down and tested in BestSnap for weeks, twenty lines away,
and nobody had asked whether the line version needed it too.  These grew one
at a time as tools were built, and nothing has ever gone over them together.

**A third fault, found the same day and the same way.**  It was possible to dimension
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
written down and tested in one picker and never asked of its neighbor.

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

From a note: "this is how i make rounded corners in a rectangle.  i use the circle
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

**Two things learned doing it, both worth keeping:**

*Arcs are walked as they are drawn, not as circles.*  A crossing is worked
out against the segments the renderer actually walks, so what counts as
crossing is what the eye sees crossing.  A piece keeps its share of the
sides, which puts the pieces' corners back on the whole one's whenever the
cut landed on a corner - and a tangent always does.

*A tolerance in parameter is not a tolerance.*  The first version threw away
cuts within 1e-7 *of the parameter* of an end.  On a hundred foot line that
is ten microns and on a one inch line it is a nanometer, so near-tangents
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

From a note: "yeah we need the frame watchdogs for bug reports for sure."  Step one
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

From a note: the tape measure was "leaving phantom lines after a while",
switching to the select tool and picking something cleared them, and a
dimension appeared that nobody asked for - with the hope that the last
thirty actions in the report would be enough to find it.

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

From a note: "yeah read the docs so we can behave almost identical to sketchup
guides... what we have now is pretty darn good just not perfect and i like
where we are better such as having the yellowish guide point.  in many ways
we are better than sketchup but in the critical ways sketchup is still
ahead."

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
out, which is what was asked for and what the two being one gesture implies.

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

From a note: "oh there is a glitching and freezing issue happening and i hope our
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

### Rounded corners, and the arc-bulge report explained - 16 September 2026

The open report "the arc tool kept the arc outside the rectangle" is this.
From a note, explaining it properly: "i was trying to make a rectangle have rounded
corners using the arc tool in its corners but it seemed like i was always
getting like a bubbled out corner unless i got the dimension just right.
sketchup seems to handle it much better... there arc shows up with a hint
about tangent on edge."

Nothing was broken; nothing helped either.  The bulge was whatever the mouse
said, and a fillet is one exact bulge out of all of them.  Built to
SketchUp's behavior, read from their help and forum and then confirmed by
From a note, in SketchUp itself:

* picks on the two edges of a corner, pull towards it, **magenta** and
  TANGENT TO EDGE when it locks - `TWorkDoc.FilletFromEnds`, and the lock is
  "the pull within a finger's width of that arc's middle";
* a radius typed while magenta, or `2"r` at any time - `FilletAt`;
* a **click leaves the square corner**, cut at the touching points - From a note:
  "maybe you just want an arc inside the pointed corner... so keep it just
  like sketchup!"  I had Enter-with-a-radius trimming too; that was mine, not
  SketchUp's, and it went;
* a **double-click trims** - `TrimFillet` - and a double-click near another
  corner repeats the radius there; a double-click on a corner already
  rounded with a plain click only trims, rather than laying a second arc.

The drive test that took the help pictures found a real bug the unit tests
could not: a plain click left the trim waiting, and the next double-click -
at a different corner, much later - used it up on the old corner.  The
waiting trim now belongs only to the double-click whose first click put the
arc in.

**Entity length**, done the same afternoon with SketchUp's rule rather than a
modifier key: a loose line moves its last end, one joined at one end moves
its free end, one joined at both cannot be typed at all.  DaveR, on their
forum, is the source.  `TWorkDoc.LineLengthEnd`.

**Half-fixed, 16 September evening: the blue face wash is drawn into the
cursor's square now** (`PaintFaceHint` takes a surface, `HintFaceNow` says
which face).  What is left of the note below is the rubber bands and canvas
text of the other tools, which nobody has seen trouble from yet.

**Found on the way, not fixed: the cursor wipes what is under it.**  The
pointer is drawn by copying a square of the finished drawing from under it
and pasting it back with the crosshair on - and the finished drawing does not
include anything painted on the canvas afterwards.  So every tool preview,
the face-hover stipple and any canvas text lose whatever is within about
seventeen pixels of the pointer.  Visible as a clean square of paper in the
middle of a stippled face with push/pull in hand, and it hid all but the ends
of the fillet arc until the arc was drawn into the cursor's square as well
(`PaintUnderCursor`).  The general fix is to composite the cursor with alpha
rather than pasting an opaque square - which wants a look at how
`TArtSurface.DrawTo` reaches the canvas on gtk3 before anybody promises it.

Not done: SketchUp's Alt tangent lock, and an arc tangent off the end of a
single line.

### The dirty rectangle, which turned out to be the ground grid - 16 September 2026

Item 4 of the agreed order, and the measurement moved the target before any
of it was written.  Worth recording in that order, because the old number
was not wrong - it was just not split up.

**What the old measurement said.**  "25.7 ms a frame, of which about 6 ms is
the model.  The other 19 is the full-screen paper repaint and the composite."
Three quarters of a frame, neither half depending on the model.  The
conclusion drawn from it was: cache the paper, composite only what changed.

**What splitting it up says.**  `RepaintPaper` now reports its own parts
under `/timings`.  Orbiting the example model, every frame:

    paper: painted 48, skipped 0 - base 2, grid 22, axes 1
    slow frame: 40ms (paper 27, ink 7, over 0, screen 6) ORBIT ... moving

* **The composite is 0-1 ms.**  Not 19.  Dirty-rectangle compositing would
  have bought nothing, and the item as written should not be done.
* **The paper base is 2 ms**, and the grain inside it - two hundred thousand
  random pixels - is 2.9 ms but only on a light theme; the dark themes skip
  it entirely.  Caching the base would buy nothing on the theme anybody is
  using.
* **The ground grid is 22-27 ms of the 30.**  All of it.

**And the paper cache, built first, was not the win either.**  Thirty-three
places call `RepaintPaper`, so the obvious guess was that it was being called
for nothing all the time.  Measured: in a session of drawing and orbiting it
painted 7 times and skipped 3.  It was never being called redundantly.  The
guard is kept - it is cheap, it is correct, and it stops the paper being
re-ruled by a future call that does not need it - but it is not why anything
got faster, and saying otherwise would be inventing a result.

**The actual fault: the floor was ruled finer than anyone can see it.**  The
camera is orthographic, so parallel ground lines stay parallel and evenly
spaced on the glass - but a tilted view squashes one family by the cosine of
the tilt.  The pitch is picked in world units for the *paper* grid, which is
square to the screen, and nobody had ever asked what it came to on the
ground.  At a working angle it came to about six pixels: **260 faint lines,
six pixels apart** - not a lattice, a gray wash, and 27 ms a frame to lay it
down.

Each family is now coarsened on its own - by two, five, ten, never by three
or seven, so every crossing left is still a round number the cursor can land
on - until its lines are at least twelve pixels apart.

| orbiting the example model | before | after |
|---|---|---|
| lines ruled | ~260 | **~88** |
| grid | 22-27 ms | **6 ms** |
| paper, all of it | 30 ms | **8 ms** |
| frames over 40 ms in the orbit | 4 | **1** |

**It looks better, which is the part that matters more.**  Screenshots both
ways: the old floor is a crosshatch texture, the new one reads as a floor,
and it is the near ground that keeps the detail.

**A low camera gets a floor now.**  The lattice is ruled over the box round
the four window corners cast onto Z = 0, and tipping towards the ground grows
that box without limit - so there has always been a cap, and the cap meant a
flat view got *no* floor at all.  With the pitch coarsening doing the density
work the cap could be loosened: measured at a nearly flat camera, at most 172
lines and 13 ms, no slow frames.  `orbit-grid` in the drive suite walks that
whole range, because it is where both guards have to behave.

**What is left in the frame**, orbiting: paper 8, ink 5-12, composite 1,
canvas blit 4.  The blit is a full-window `DrawTo` and is the only thing left
that a dirty rectangle could touch - and during an orbit every pixel really
has changed, so it would not help there either.  The next honest performance
question is the ink, not the paper.

### Orbit that clicks into a squared-up view - DONE 16 September 2026

From a note, the same day he raised it: "since half of the work is there and it
already sort of does the orbit snapping with the cube give me your best shot
at something that uses a modifier key with the orbit tool so when you release
it snaps the closest prefixed destinations that we have already... let it do
the animation like the cube does because it looks nice and you don't lose
track of what you're looking at when it animates."

Built as described, and the guesses below turned out mostly right - what they
got wrong is worth keeping.

* **The set is the cube's twenty-six.**  `CubeNearest` in uCube walks them
  and takes the largest dot product.  The naming came free: `DirName` was
  already there, so the status line says FRONT RIGHT TOP rather than an
  angle.
* **Ctrl, not Alt.**  The note guessed Alt was free.  It is free in this
  program and not free on the desktop: every window manager worth the name
  takes Alt and a drag to move the window, so an Alt-orbit is somebody
  else's gesture half the time.  Ctrl does nothing during an orbit.
* **On release, not while dragging.**  As described, and read at the release
  rather than at the press so it can be grabbed part way through the turn.
* **All twenty-six, no limit on how far it will throw the camera.**  The
  note worried a limit would be needed.  Measured instead: swept over the
  whole sphere, the furthest any camera can be from all twenty-six is **27.4
  degrees**.  That is a modest throw, and it glides, so you watch it happen.
  A limit would only mean the key sometimes silently did nothing.  The sweep
  is a test, so the number stays honest if the set ever changes.
* **It shows.**  The note called this the part that would make it feel
  considered rather than magic, and it was right for a reason it did not
  give: the cube is **off until somebody turns it on**, so lighting the cube
  alone would have left most people with a modifier whose effect they could
  not see until after committing to it.  The status line carries it instead -
  "let go to click into BACK LEFT TOP" - and the cube lights up as well when
  it is showing.

Nothing new was invented: `CubeAzEl` already turned a direction into a
camera and `GlideTo` already animated the way there, which is what a click on
the cube has always done.  `orbit-snap` in the drive suite drives an ordinary
orbit, a held one with the preview up, and the landing.

**Still worth trying some day**: the pull-while-dragging version, which is
the one that would be "better than SketchUp" if it works and worse if it
does not.  Now that the arithmetic and the preview exist it is a small
experiment rather than a project.


From a note, brainstorming and explicitly not committing: "I think I want to have a
modifier key for the orbit tool that makes it snap to one 16 (or whatever
number of views the view cube has) when it is closest while orbiting.  So if
I'm orbiting around to a view I like I could release the mouse with a
modifier key and it clicks to the closest preprogrammed views we have....
It would be better than SketchUp maybe.  I'm not certain I want it but I
think it will be nice to do an orbit around and get it to snap itself at
least so one of its planes are squared to the view."

**Twenty-six, not sixteen.**  The view cube offers six faces, twelve edges
and eight corners - a straight-on view, a half turn between two, and the
three-quarter view from a corner.  That is the set to snap to, and it is
already the set somebody learns by clicking the cube.

**Most of it is already built**, which is the reason to write this down now
rather than treat it as a project.  `CubeAzEl(Dir, Az, El)` in uCube turns
one of those twenty-six directions into a camera, and `GlideTo(Az, El)` in
uMain already animates the camera to one - that is what a click on the cube
does today.  The experiment is: on mouse-up with the modifier held, walk the
twenty-six, take the one whose direction is closest to the current view
direction (a dot product against `ViewDir`), and `GlideTo` it.  A first cut
is a couple of dozen lines.

**What to decide by trying it, not by arguing about it:**

* **Which modifier.**  Shift is taken in orbit by the axis constraint, Ctrl
  is taken by the eraser and the move tool's copy.  Alt is probably free
  here.  Whatever it is, it has to be one that can be pressed *during* the
  drag and released at the end, because that is how the owner described it.
* **All twenty-six, or only the six faces?**  His second sentence is the
  more modest and possibly the better idea - "at least so one of its planes
  is squared to the view" - which is the six faces, or the six faces plus
  the twelve edges.  Corners may just make it feel sticky.
* **Snap on release, or pull while dragging?**  Release is what he
  described and is the safer one: a view that tugs towards a preset while
  you are still turning it is the kind of help that fights you.  Worth
  trying both once it exists, because the pull version is what would make
  it "better than SketchUp" if it works, and worse if it does not.
* **How close is close enough?**  Snapping from anywhere means you can
  never hold an in-between view with the key down; a limit means the key
  sometimes does nothing, which needs saying in the status line.
* **Does it show?**  The cube could light the face it would go to while
  the key is held - which answers the previous question for free and is
  the part that would make it feel considered rather than magic.

Worth a session, on its own, with the drive suite recording before and after
so the feel can be compared rather than remembered.

### The picker audit, done - 16 September 2026

From a note: "improve the picker substantially please and try not to hurt
performance or break existing functionality."

The five questions were asked of every picker.  What they turned up:

**1. Putting the guides away told two pickers out of six.**  `FGuidesHidden`
appeared in four places in the whole program and two of those were the
renderer.  So with the guides hidden the snap still jumped to a guide point,
still found guide *crossings*, the cursor still ran along a guide line, and
the select tool and the eraser both still took guides that were not on the
screen.  The seventh instance of the same shape: a rule written down in one
picker and never asked of its neighbor.

A sweep - a grid of cursor positions, every picker asked at each - found
guides answering at **477 positions**.  Hidden, it must be none, and it is.

The snap cache is why `GuidesHidden` is now a setter rather than a bare
field: it is built once and kept until an edit, so a guide point put into it
stays there however the switch moves afterwards.

**2. `HitTest` had no idea of "nearest".**  It walked the list newest first
and took the first thing within reach, so with two things in range it
answered "whichever I drew last" - a fact about the order somebody worked in
and not about where they are pointing.  It now takes the nearest and settles
a tie within a pixel by depth, the way `EdgeUnder` does.  It costs a full
walk where it could stop early; that is affordable because `PickAt` only asks
it after `HitEdge` and `HitFace` have both come back empty, and `HitEdge`
already walked the whole list.

**3. The reach was a pixel short, for the first candidate only.**  `Best`
started at the tolerance and the first candidate had to beat it by a whole
pixel, so a lone edge at eight and a half pixels with nine asked for was not
found at all.  Present in `EdgeUnder`, which had already been through an
audit, and in the new `HitTest` until the test caught it.  The gate ("is it
within reach") is now separate from the contest ("is it the best so far"),
which is the arrangement that cannot have this bug.

**4. The selection box tested the box around a thing, not the thing.**  The
extent of a line from one corner of the screen to the other is the whole
screen, so a small crossing box dragged in a clear patch took the diagonal
running past it, and every arc and face whose outline went *round* the area
rather than through it.  `BoxTakes` now asks the geometry: the segments a
thing is really drawn with, a face's inside as well as its outline, a
dimension's drawn lines rather than the chord through what it measures.  A
containing box still uses the bounds, because for "wholly inside" the bounds
are the same question.

Two more found there: a **bore** - the record of a tunnel, never drawn - was
selectable by a box, and a **guide line** was nearly never selectable by one,
because an infinite line has no extent to be inside anything.  What was asked for was
the opposite in so many words, so a guide answers the crossing question
whichever way the box was dragged.

**5. Two questions answered out loud rather than changed.**  `AxisSnap` never
asks whether an axis is hidden - the axes are inference lines, not geometry,
and they are not occluded.  And a selection box deliberately does not ask
whether it can see what it takes: a box is a sweep over an area, not an aim
at a point, and dragging one round a model and getting only the front faces
would be the surprise.  Both were open questions in the audit; both are
choices, and they are now written where the code is.

**Performance: thirty times faster, not slower.**  `Project` rebuilds the
view basis on every call - `ViewRight` and `ViewUp`, four trig calls in the
orbit view - and `HitEdge`, `HitTest` and `FaceUnder` were all calling it
once per point, several thousand times a mouse move.  `BeginProject` and
`ProjectAt` have existed for exactly this since the snap cache was written,
and `EdgeUnder` already used them.  Measured on 6400 things:

| | before | after |
|---|---|---|
| `HitTest` x1000 | 1996 ms | **58 ms** |
| `HitEdge` x1000 | 2016 ms | **57 ms** |

Arcs got the other half: `ArcScreenDist` walks twenty-five chords for one
circle, and a sheet of circles is an ordinary drawing.  It now takes the
camera ready-made and rejects on the bounding circle first - an orthographic
projection never moves a point further from the center than its own distance
times Ppu - so adding **625 circles cost 3 ms per thousand picks** instead of
fifteen thousand extra projections.

`BoxTakes` over a whole 7000-thing drawing: 4 ms crossing, 2 ms containing.

**What is still not audited.**  The note picker (`HitNote`) is a plain box
test with "last drawn wins", which is right for text drawn over the top, and
`DoomAt` is the eraser reading `HitNote`, `HitEdge` and `HitTest` in turn -
so it inherited all of the above and needed nothing of its own.

### The drive suite, which had got too slow to run - 16 September 2026

From a note: "These tests take forever.  Anyway we can run like 10 of these tests at
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
is behavior X has had all along and I had not checked.  And the server is
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
this".  From a note: "some of the tests we could conduct together in a single test
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
something else, and the owner gave the steps: "the exception happened after i
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
seventh): *a rule learned in one place and never asked of its neighbor*.
Here the neighbor had not been written yet.  The answer each time has been
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

**Closing a modified sheet did not ask to save.**  From a note: "I recently had
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

**Copy and paste.**  From a note: "we need to be able to copy and paste a selection
and copy and paste from one sheet to another etc."

Ctrl+C and Ctrl+V are not bound to anything.  What exists already and does
most of the work: `Duplicate(Idx, D)` copies entities with their groups
remapped, and the move tool's Ctrl-copy uses it.  What is missing is a
clipboard the copy can sit in between the two gestures, and the
sheet-to-sheet case needs it to survive a `TDrawing` change.

Shape it as: Ctrl+C takes a deep copy of the selection into a form that does
not reference the document it came from; Ctrl+V drops it, picked, with the
move tool live so it can be placed - which is SketchUp's Paste In Place
behavior and saves inventing a rule for where it lands.  Across sheets it is
the same code, because the copy does not point at the old sheet.

### Where this is going, agreed 15 September 2026

From a note, after an evening of comparing: "SketchUp is way smoother and crisper
moving than us when orbiting and the snapping behavior is so much more
refined than us.... We are sort of close but not good enough.  I'm thinking
we spend the next week or so working out the details and bugs in tools and
then we will end up doing some performance evaluations."

And, worth keeping because it is the actual brief: "I open SketchUp to
compare - and going back to theirs after using this one is not the
comfortable feeling it ought to be.  What is being built here is worth
liking; it wants a run of small improvements."

### The order, and why

1. **A frame watchdog, first.**  `Took()` and `/timings` already exist; log
   any frame over about 40 ms with its phase breakdown into the session log.
   Then every bug report for the next week carries its own diagnosis instead
   of "it felt glitchy".  From a note on the symptom: "we some times have clumsy
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

From a note: "I really wanted to avoid opengl... I hope we aren't too far off and
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
What was asked for was outright and which was previously a before-you-draw-only
setting; **soften** on a line or an arc; **size** on a note; **reverse** on a
face or on several.  Deliberately not editable with more than one thing
picked - a stepper that acted on nine things at once is a way to lose nine
things.

**What SketchUp's own Entity Info does, checked 16 September**, because the owner
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
* **Color: yes**, as a *material* - the panel shows and sets the material on
  an edge or a face.
* **Per-edge thickness: no.**  SketchUp has no such thing.  Line weight there
  is a **style** applied to the whole model (and a LayOut setting for
  drawings).  Our `Weight` is per entity, so on this one we are already doing
  more than they are, not less.
* It also carries the tag/layer, hidden, locked, and cast/receive shadows -
  none of which we have, and only "hidden" is one we have talked about
  wanting (see the eraser's Shift, in Smaller things).

**On the LINE COLOR button along the bottom.**  From a note: "that may be one more
button we could get rid of... But maybe not.  Those are sort of the default
settings and I like it for the most part."

Keep it.  The two controls do different jobs: the bottom row sets **what the
next thing you draw will be**, and the entity panel changes **what is already
there**.  That is the same split as SNAP TO and ROUNDED TO, which nobody
would want to reach into an entity to set.  Losing the button would mean
drawing something in the wrong color and then editing it, every time.

**Worth adding to the panel next, in about this order.**  Each is a row and a
setter, and the setters mostly exist:

* **Length on a line.**  The one that turns the panel from a readout into a
  modeling tool, and the one that needs a decision rather than typing: which
  end moves, and does what is joined to it come along?  It should - MoveVerts
  already does exactly that for a drag, and a length typed into a box ought
  to behave like a drag that landed exactly. Suggest: the end furthest from
  the last point you clicked moves, and the panel says which as you hover the
  box.
* **Color and pen width** on whatever is picked.  `SetInk` does not exist
  yet; it is two lines.  Color brings us level with their material field;
  width is ours alone.
* **Radius on a circle**, same shape of problem as length.
* **The plane an arc was drawn in**, which would let a circle be stood up
  after the fact.
* **A name on a solid.**  There is no field for it and it wants one in the
  file; that is a feature, not a row.

### The entity window - what it was going to take

From a note: "SketchUp has entities... And I think like for an arch you can get into
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

From a note: "so once again we closed in the a rectangle... i am unable to pull it
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
edge put in as 5-2 was never recognized when it came back as 2-5.  The
duplicate went in.

Two parallel edges between one pair of corners are two more darts than the
face walk expects, so it goes out along one and back along the other: a slit.
His wall came out as a single eleven-point loop of 797 sq ft with the divider
traced up one side and down the other, instead of a band of 750 and a strip
of 47.5.  Nothing to push, and no way to see why.

**Worth remembering as a shape of bug**: a hash whose *bucket* is computed
from a normalized key and whose *comparison* is against the raw one.  The
bucket makes it look right - the two do collide, so the code path is
exercised - and the answer is wrong only for the half of the cases where the
raw form differs.  Grep for others: anywhere a key is sorted or canonicalised
on the way into a hash, check what the equality test uses.

Reduced into `tests/regiontest.pas` as TestDividerAlongAnEdge, which also
asserts that no loop doubles back on itself - the slit's signature, and a
cheaper thing to check than the areas.

### The eraser and faces, checked against the live page

From a note: "yes the eraser does allow you to erase faces in SketchUp and we do
want that just to be clear... you need to always be verifying how SketchUp
does something when we are uncertain."

Fetched it rather than relying on the note.  SketchUp's help says "The Eraser
tool doesn't allow you to erase faces", and puts erasing one on the Erase
context command.  Reported that back with the quote, and the owner went and looked
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

From a note: "in SketchUp I don't think you can even have a filled face unless it is
enclosed by lines.  So when I am erasing lines on a cube it will leave behind
faces and I think that is wrong... I think also when I delete a face in
SketchUp let's say in a cube there is a way to put it back if I remember
correctly but it was awkward... Verify my explanations here and
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
the example the first time anybody rubbed anything out.  It is also why the owner
is rebuilding the toy by hand and finding fault after fault in it - the model
the help pages all use is not geometry that the program itself could have
produced.  **Take his model when he offers it.**

### Two reports, 16 and 17 September - both fixed

**Guides taken with the drawing, and no crossing on the far side.**  Two
faults in one report.  The triple-click flood walks shared corners, and a
guide laid from a corner shares it - so it went through the guide and took
every guide it touched; the double-click had the same hole for a guide stub
lying on a face.  A box took any guide running through it.  Now the flood
and the double-click never take a guide (a click on one is just the guide),
and `TWorkDoc.BoxPick` takes guides only when the box caught nothing else.
Select All already left them out.

The second half: a guide is stored as a foot-long stub, and the crossing
cache tested the stub, so crossings were found only within a foot of where
the tape laid it.  The test that "covered" it used a ten-foot guide.  Now
each guide is run past the drawing's bounds both ways, and `ArcSnaps` offers
where a guide meets an arc.  The new test lays guides the way the tape does.

**Sluggish on Windows** (1694x769 at 125%).  Paper frames of 400+ ms while
moving, and 60-90 ms screen frames sitting still, zoomed in with the arc
tool.  Two causes: every wheel step and mouse move redrew the paper and
invalidated the whole form, so a burst of events meant a burst of full
redraws - now `ViewMoved` marks it and `FlushView` draws once per tick (100
wheel steps: 10 paper paints, was 100).  And the blue wash over the face
under the pointer was painted straight onto the window canvas every paint,
25 ms at that size; it is now drawn into a surface kept for the purpose
(slow frames on the zoomed hover test: 14 to 0).  Worth trying on the
same machine - the numbers above are from this Linux box.

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
half of what was asked for.

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

From a note: "our documentation really needs some help.  we probably need a document
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

The rule that a picker learns and its neighbor never does, twice more, and
this time neither was in a picker: both were in what the picture said.

**Push/pull's stipple did not know about holes, or about what is in front.**
From a note: "using the push/pull tool and when i am hovering over the outer ring
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

**The move ghost lied about what was coming with it.**  From a note, straight
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

**The move now has two ways, which What was asked for was.**  The stretching one is
SketchUp's and is what happens by default; `/detach on` takes what is picked
away on its own.  It is a command and not a held key because a move has no
key left: Ctrl leaves a copy, Shift holds the axis, Alt holds the working
plane, and every letter is a tool shortcut.  Worth revisiting if a modifier
ever frees up - a held key is the better shape for it.

### The frame, measured rather than guessed - 15 September 2026

From a note: "the display and moving has gotten really poor performing... in the
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

The consequence is that it has no behavior it was not given.  The wheel
works because a wheel handler was written.  The keyboard works because a key
handler was written.  A finger did nothing at all, because nothing had been
written for it - which on the Windows touch laptop meant a window you
could read and not move.  Dragging the page scrolls it now, which costs a
mouse the same gesture for free.

Anything else drawn this way - the command list, the popup menus - has the
same shape, and the same question is worth asking of each: what happens when
somebody touches it rather than clicks it.

**And a second consequence, found the hard way on 16 September.**  It paints
words, not markup - so `<kbd>Ctrl</kbd>` written into WHATS_NEW.md out of
habit from editing the help pages reached a user with the tags showing.
The owner saw it in the release.  The notes now go through a `Plain` that strips
the handful of inline tags that could plausibly turn up, **by name** - not
"anything in angle brackets", because the notes already contain
`/tiles <folder>` where the brackets are how a placeholder is written and
eating those would be the worse bug.

### LazInk, and what it could take over - 16 September 2026

From a note: "is this what's new decorated text panel a ton of work because I think
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
TInkMemo does all of that and more - `<b> <i> <u>`, colors, `<hr>`, `<p>`,
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

### The manual inside the program - 17 September 2026

From a note: "i want them stored on github like it is... i dont want you to make a
browser... we will going forward need to have a zip archive of the help
docs in the releases and then we can have heckers sketch fetch it and unzip
it and keep a copy locally next to the executable.  that way if you run off
a usb drive and bring it to a place where you have no internet you might
still have the files."  And: "build the help form with a real lfm!", and
"it should detect you dont have the docs updated and it should retreive
them and maybe the auto updates should retreive them automatically."

**How it fits together.**
* `build.sh github` packs `docs/help` into `heckers-sketch-help.zip` with a
  `VERSION` file holding the tag, attaches it to the release, and puts it in
  `SHA256SUMS`.  The all-builds zip's `help/` gets the same `VERSION`.
* `uHelpDocs` fetches the zip for the running version (the latest for a
  developer's build, or when a release has none), checks it against the
  sums, unpacks it into `help.new` beside the program - refusing any name
  that climbs out or starts from a root, anything over the size and count
  limits, and any zip without an `index.html` - then swaps it in, moving the
  old folder aside first so a failure leaves one or the other.  Links are
  removed as links when clearing, never followed.
* `THelpFetch` does it on a thread.  `KeepHelpCurrent`, a few seconds after
  start alongside the update check, fetches when the pages are missing or
  from another release - so after an update they follow on their own.  The
  update-check switch governs it, `--offline` stops it, and a failure waits
  six hours before trying again.
* `uHelpView` (with `uHelpView.lfm`) is the window: LazInk's `TInkPage`,
  Back / Forward / Contents / Find, "Get latest pages", "Open on the web".
  Links to the manual's own website are turned back into the local files;
  anything else goes to the browser.  With no pages it says so and fetches
  them with a progress bar; with stale ones it shows those and fetches the
  new ones in the background.
* One fetch at a time; if the program's own is running when the window
  opens, the program passes its progress and result on.

**Tested.**  The unpacking: a good zip, a newer one replacing it whole, a
`../` name and an absolute path refused with nothing written, a zip with no
index and a file that is not a zip both refused with the old pages intact.
The staleness rule.  `help-window` in the drive suite: contents, a link,
Back, Find.  **End to end, checked against v2026.09.17**, the first release carrying
the zip: the released Linux binary (sum verified), started in an empty
folder with the network on, fetched and unpacked the pages on its own a few
seconds after start - `help/VERSION` read `v2026.09.17` - and `/manual`
showed them with "pages from v2026.09.17" in the title.  `tools/xephyr.sh`
grew `NETWORK=1` and `APP=path` for exactly this check; the drive suite
stays offline.

**Two things found on the way.**  `ShowHelp` was already a method of every
control, so the entry point is `OpenHelpWindow`.  And the same stale-build
trap LazInk's demo hit: an `.lfm` edited in the same second as a build is
not picked up, and the old form - with a property BGRA's button does not
have - kept crashing the window after the file was fixed.  Deleting
`lib/x86_64-linux/uHelpView.*` fixed it.

**What's New reads Markdown now.**  `uWhatsNew` keeps the part only this
program knows - which release sections are newer than the version updated
from - and hands those to `TInkPage` as Markdown with a theme style sheet.
The line-by-line parser and the HTML builder are gone: 599 lines to 363.
Checked with `--updated-from=v2026.09.16.7`: .9 and .8 shown, nothing older.
`ARGS=` passes arguments like that through `tools/xephyr.sh`.

### Pictures you can open larger - 17 September 2026

From a note: "for the gif files... be able to click them and see a larger
image... I prefer not to get that package any bulkier."  LazInk's P7 made
a picture inside a link clickable, told the host it was a picture
(`ClickedLink.Image`), and added `ImageFit`.

* Every `<img>` in `docs/help` is wrapped in
  `<a class="zoom" href="same picture" target="_blank">` - fourteen of them.
  A browser opens the picture in a new tab.
* `uHelpImage` (with its `.lfm`): one reusable window, 85% of the screen, a
  `TInkPage` with `ImageFit := iifWindow` and nothing on it but the picture;
  Esc closes it.  `THelpForm.PageLinkClick` sends a clicked picture, or a
  link straight to a `.png`/`.gif`/`.jpg`, there instead of replacing the
  page.
* The three animations are re-recorded at 1100 wide instead of 700, so the
  big view needs no enlarging: push/pull 0.77 -> 1.49 MB, rounding corners
  1.08 -> 1.67 MB, orbit snap 1.71 -> 3.42 MB (at 6 frames a second and 48
  colors - at 8 and 64 it was 5.0 MB).  The help zip grows by about 3 MB.
  `tools/gif-push.txt` needed the Push/Pull button's new position.
* `help-picture` in the drive suite: open the manual, go to Push/Pull, click
  the animation, see it in its own window, Esc back to the page.

The index's cards now look the same in the program as in a browser -
LazInk's P7 table work (equal columns, padding, spacing, cell colors,
rounded cells, `<small>`).

### Our tests used up the house's GitHub allowance - 16 September 2026

From a note: "my v2026.09.15.7 is not updating on my wife's computer it gets a 403
unexpected response error... That means it probably happens on all my
machines."  Linux Mint, same network as this machine; a few minutes later
it "just worked after trying again".

**What it was.**  GitHub's API answers sixty requests an hour per network
address without an account.  Every drive-suite start of the program ran the
update check - each in a fresh folder that had never checked, so the
six-hourly throttle never applied - and an evening of full runs at twenty
units apiece used the allowance up for everything behind the router.  Her
check was refused; an hour later the window rolled over.  "Unexpected
response status code: 403" is fphttpclient's wording, which is the Linux
backend - the Windows one says "the server answered".

Measured, not assumed: GitHub's own count had reset to 2 used by the time I
looked, and after the fix a whole drive-suite run used **zero**.

**Three changes.**
* `--offline` - `uNet.NetOffline` - and nothing goes out: no update check, no
  report.  `tools/xephyr.sh` passes it always.  Guarded at all four entry
  points, both backends, so nothing added later can leak.
* `FetchLatest` falls back to the release feed (`/releases.atom`) when the
  API refuses.  The feed is served like a web page, carries every tag newest
  first, and the files of a release are always at
  `/releases/download/<tag>/<name>`.  Checked against the API: same tag,
  same asset address, and the checksum file downloads from the feed's
  address.  The size is unknown that way; the progress bar already copes.
* `NetFriendlyError` - a 403 or 429 says GitHub is limiting this network for
  the moment, rather than a number.

Copies already out there (v2026.09.15.7 and the rest) still use the API
alone, and they are fine once the tests stop spending the allowance - which
they have.

**The release notes window is LazInk's now - DONE 16 September.**  LazInk
grew a page viewer, tables, lists, code and key labels, Markdown and a test
suite in a session of its own, and is published at
https://github.com/TonyStone31/LazInk.  Checked against this program's own
help folder there: 38 pages, 12 images, 2,205 text fragments, all present.

`uWhatsNew.pas` keeps the part only this program knows - which releases to
show - and hands the notes to a `TInkPage` as a small HTML page in the
dialog's colors.  The hand-written layout, wrapping, drawn scrollbar and
page dragging went: 599 lines to 510, and the 89 is net of the hundred lines
that turn the notes into HTML.  The larger saving is that the renderer is
now tested and maintained in one place.

**Touch came with it, on purpose.**  The drag-to-scroll this window had to
learn for Windows touch screens - a finger arrives as a mouse press, moves
and a release, and there is no wheel - was added to `TInkPage` before the
swap rather than kept here, with a dead zone wide enough for a fingertip
that rolls as it taps, and a drag that ends on a link not counting as a
click.  Tested in LazInk; `whatsnew-drag` still drags it here.

**What got worse:** the scrollbar is LazInk's stock one, light gray, where
the old window drew its own in the theme's colors.  Noted in LazInk's
roadmap as a themed scrollbar; not worth a workaround here.

The project finds LazInk at `../LazInk/lazink.lpk`, and the Windows cross
build compiles it.

**The help pages inside the program** are the next use, and LazInk can
already render them.  What is left is this program's end: a copy of
`docs/help` beside the executable (the release zip already ships one), a
window with Back, and `/manual` opening that instead of the browser - with
the browser kept for anybody who prefers it.

**The full list now lives in LazInk itself** (16 September): 
`/media/tony/storpart/synced/GIT/LazInk/ROADMAP.md`.  The owner wants LazInk kept
as its own project, built over there, with this program as one of its users -
so what it needs to grow belongs in its tree, not here.  In short: headings,
lists, `<code>` and `<kbd>` are all the What's New window needs, and once
they exist `uWhatsNew.pas` loses its hand-written painter.  The manual would
need tables, images by file name and a page viewer as well, and until then it
stays in the browser - a second, simpler copy of the manual is not the
answer.  LazInk has no GitHub repository yet and has a large piece of
uncommitted work staged in it.

### The view cube

Built 14 September, at a friend's asking - he uses Revit and thinks a
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
  animation took a second and a half.  The recorder learned this first.
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

the uncle prints from this program on a three hundred dollar machine and
the workflow works - but he opens every part in OpenSCAD on the way, to
"modify some properties and center it".  What was wanted was that step gone, which
meant working out what it was for.

At least part of it was ours.  **"Center it on the origin" centerd all three
axes**, so the bottom half of every part sat under the build plate.  Slicers
lift it back out without comment, which is why nothing ever looked wrong -
but centring a thing for printing means centring it ON the bed, and a model
half underground is exactly what somebody opens another program to put right.
Fixed in the STL, the OpenSCAD and /center: across X and Y, standing on Z.
Measured on the wine glass, 0.00 to 215.90 mm.

Two tests asserted "centerd in z" and had to change with it.  They were
asserting the bug - written when the convention was assumed rather than
checked.

**Still unknown: what else he does in there.**  Worth asking him, because it
decides whether anything more is wanted:

* **laying a face on the bed** - rotating a part so the right face is down
  for strength or to avoid supports.  We have nothing for this and it is the
  most likely remaining answer.
* **scale** - if a part ever arrives the wrong size that is a units fault and
  worth knowing about; the STL is always written in millimeters.
* **which file he opens** - if it is the .scad rather than the .stl he may be
  editing the polyhedron or wrapping it in a transform, which is a different
  workflow and would explain "properties" better than an STL can.

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

### Closing without saving - DONE 16 September 2026

From a note, 14 September: closed the drawings, chose not to save, opened the program
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

### Done 13 September: faces are cut into triangles before rasterising

**Why it was needed.**  A face is a polygon and the depth of it was worked
out as a flat function of screen position - exact for a flat face, a fiction
for one that is not.  Spinning a sloped piece of an outline sweeps a warped
quad; 48 of the crown's 336 faces were out of flat, the worst by five
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

*STL export - done, 13 September.*  Binary, in millimeters, built straight on
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
millimeter scaling with the vertices, and a normal 304.8 long is not a normal.

*Screen-space cutting and self-intersection.*  A warped face can in principle
project to an outline that crosses itself, which ear clipping has no answer
for; it would come up short and the rest of the face would fall back to the
fitted plane.  Measured on the crown: 4,608 cuts over 96 views, never short,
worst area error 1.1e-14 relative.  Not a problem in practice.

### Done 13 September: the blue faces, and they were never about depth

The owner resent the robot-and-house drawing from v2026.09.13.13 saying the blue
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
outside - where people stand - was the back-face color.

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
views the total back-face color on that drawing is the same as before, and
that is right.  A loose face has two sides and one of them is its back; you
can always walk round and look at it, and it is drawn blue on purpose, because
that is the only way to see that a face is there at all rather than a hole.
What was wrong was never that blue existed - it was that it faced the wrong
way.

**Still worth doing.**  Seven faces on that drawing are single loose faces
with no neighbor to agree with, and nothing here can help them: with no sheet
to belong to there is no "out".  If they turn out to matter, the answer is
probably to notice that they close a solid together with faces that already
exist and adopt them into it, which is a bigger idea than this one.

### Settled: a 3D engine, and whether the renderer should be one

The owner asked whether all this is wasted effort next to Castle Game Engine or
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
admires went into the inference engine and the modeling, which is precisely
the part nobody can be bought out of.

**So: no engine.**  Castle in particular is the wrong shape - a scene graph,
X3D, materials, physics, none of which a drafting program wants - though its
license would not stop us (GPL-2+/LGPL-2+ with static linking permission and
proprietary use explicitly allowed).  If the day comes that fifteen thousand
faces has to be interactive, the door is **raw OpenGL behind the existing
TArtSurface interface**, keeping the software path for printing and for
machines without a usable one.  Triangulation is the prerequisite for that
door as well as the fix on its own merits, which is why it goes first either
way.

### Done 13 September: an export dialog, and a GIF that turns

The owner pressed Export expecting to be asked something and got a save dialog
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
machinery exists.  A note said camera only for this round.

### Done 14 September: the GIF export crash - a missing color quantizer

Reported 13 September from Windows on v2026.09.13.16: pressing Export gives an
access violation and writes nothing.  **Not reproduced here** - Linux exports
every format cleanly, there is no wine on this machine to try the win64 build,
and no report came with it because there was no way to send one from that
dialog.

So the release after it does three things rather than guess.  The export
carries a `FStage` string through every step and a failure now reads
"EAccessViolation while drawing the picture at 2101x979" instead of nothing.
There is a **Tell us about it** button in the dialog itself, which hands the
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
holds 256 colors and something has to choose which; BGRABitmap keeps that
chooser pluggable and **naming the unit in `uses` is not enough** - the
library's own error text spells it out, `BGRAColorQuantizerFactory :=
TBGRAColorQuantizer`.  It was never assigned, so any frame over 256 colors
reached a nil quantizer and faulted.

That is why it looked like nonsense: white paper, gray faces and black lines
fit inside 256 easily, so a plain drawing exported; three anti-aliased
colored axes over the top do not, so every export with axes on - the default
- died, whatever the length.  One line in an initialization section.

The frame budget stays, but for the honest reason rather than the panicked
one: measured, a four second spin of the crown is 410 KB at 320x240 and
1.35 MB at 800x600, and the 15.9 second recording is 0.70 MB at 104 frames
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
  down, back to center, round, and maybe up and down again at the back.  How
  far it gets through that is set by how long the clip is meant to be.
* orbiting **around the middle of the selection**, with a **starting zoom**
  you can set - and possibly the wheel setting the zoom of a canned walk
  rather than driving it live.
* center on the selection **from the moment Export is pressed**.

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
(the sketch that came with it - over the top, under, level, round), and push in.  Length
chooses the frame rate rather than the other way round, as asked.

Left as is, on purpose: no trimming on the filmstrip.  For a clip of five
seconds the only two useful things are keeping it and doing it again, and
handles to drag would be a worse answer than a Clear button.

### Done 13 September: OpenSCAD export

the uncle asked for it, having printed the crown off the STL.

`TWorkDoc.WriteSCAD`, on the same `FaceCut` / `FaceCorners` pair the STL uses.
One `polyhedron` per group, each in its own module, so a drawing in ten pieces
arrives as ten modules and a union rather than one undifferentiated lump -
which is the difference between a file somebody can work with and a file
somebody has to re-cut.  Loose faces go out too, in `hs_loose`, labeled as
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

## A report is sealed before it leaves the machine - 19 September

Followed straight on from the TlsLib4Pascal note above.  Looking at what
`docs/bug-report-endpoint.json` actually is turned up the real finding: the
Filebin bin a report goes to has no login, its address is necessarily
public (the program has no server of its own to ask first), and that
address - every one it has ever had, seven rotations of it - sits in git
history forever.  For as long as any one of those bins lived, anyone who
found it could read what a stranger had written about their drawing, or
the screenshot that came with it.  "We do not collect info or track users"
was true and beside the point: nothing was being collected on purpose, but
it was sitting somewhere public regardless.

Encryption was the right answer once it was named, and CryptoLib4Pascal
already had the whole thing built: ECIES, tested against known vectors, the
sealed-box pattern this needed - a fresh ephemeral key per message agreed
with one long-lived public key, AES-256 and HMAC-SHA-256 for the body.
Nothing to design, only to wire up.

Two things worth remembering if this is ever touched again:

* **This is confidentiality, not authentication.**  The public key ships in
  every binary and is trivial to read out of one, so a deliberate abuser
  can seal garbage exactly as easily as a real report - it decrypts fine
  and meets the collector's existing content checks exactly as it always
  did.  What this buys is narrower and still worth having: nobody but the
  collector can read a *legitimate* report while it sits in a bin whose
  address is, and always will be, public.
* **CryptoLib4Pascal is really three libraries** - it pulls in
  HashLib4Pascal and SimpleBaseLib4Pascal - and building any of them on
  Linux hits one real upstream bug: `ClpECC.pas` asks for a unit called
  `ClpIPreCompCallback` and the file answering to that name is spelled
  `ClpIPreCompCallBack.pas`.  Same unit to the compiler, two different
  files to a case-sensitive filesystem.  Fixed with one corrected-case copy
  in `crypto/vendor-fixes/`, listed ahead of the real one in
  `etchasketch.lpi`'s search path - see `crypto/README.md`.  Worth
  reporting upstream; not done yet.

Verified three ways before any of it was trusted: `crypto/selftest.pas`
round-trips a corrupted-tamper check and byte-exact payloads up to 300 KB
with the real production key; the exact `TryOpenSeal` function now living
in the (unpublished) collector was proven, offline, to open exactly what
the real shipped `EncryptReportBytes` produces, and to correctly leave
plain, never-encrypted text alone; and the collector was run for real
against the real live bin and correctly filed ten legacy plaintext reports
with nothing falsely flagged as sealed.  The full test suite - geomtest
1206, region 91, commands, drive 31 - stayed green throughout, since none
of it touches `uReport.pas`.

Two things live outside this repository entirely, on purpose: the private
key (`~/.config/heckers-sketch/report-key.hex`, never in a working tree
`git add -A` can reach) and `tools/fetch-reports.pas`'s own `--key` value,
which only that gitignored script ever sees.

## Four reports from one long session, 19-20 September

All from the same person, one sitting, the day this repository's own
history became readable to me for the first time - the encryption above
shipped between the first two reports and the last two, so this was also
the first real proof the collector still works once it does.

**Fixed - the cursor's square was cutting the tool's own corner off.**
"the white square behind the cursor is cutting off the drawing behind it."
Right: the crosshair rides in a small square of its own so it can be drawn
anti-aliased against whatever is under it, and the square is a patch of the
*finished* drawing, with no tool preview in it - see the standing comment on
`PaintUnderCursor`.  Pasting it back over the cursor therefore erases
whatever preview the tool had just drawn there, and for the rectangle and
line tools that is always their near corner, because that corner is by
definition wherever the cursor is.  The face wash and the fillet arc were
already special-cased into the square for the same reason; the rectangle
and line rubber bands were not.  Fixed the same way - drawn into the square
now, not wiped by it - checked by screenshot: the two edges meet cleanly at
the crosshair with nothing missing.  Not the full axis-color inference
`PaintProOverlay`'s `Rubber` does when it draws these normally - a flat
accent color, since the patch is a handful of pixels and nobody will see
the seam where the real, correctly-colored line takes over a few pixels
further out.  Other tools that paint a live preview straight onto the
window - offset, the protractor's arm, dimension - share the same
mechanism and were not touched; if one of them turns up with the same
symptom, this is where to look.

**Investigated, not a new bug - the shake while zoomed.**  Clarified: not
the toy's dissolve animation, and not toy mode at all - the rendering
itself stuttering while zooming, noticed around a delete.  Traced what
Erase actually does: gathering what is under the cursor while dragging is
cheap (one hit test, one flag), and the expensive part - deleting, working
the flat areas out again, a full render - happens once, on commit, not
every frame.  The stutter in the session log is continuous through
ordinary SELECT and MOVE too, always at high zoom, which is the fill-rate
finding from three days ago: cost scales with pixels covered, not with
face count, and at 700%+ zoom on a several-hundred-face drawing a handful
of faces can fill the whole window.  That is the same problem the
drag-time-resolution idea was for, discussed and deliberately not built
then because it touches how `FArt`, `FPaper`, `FInkToy` and `FInkPro` stay
in sync - four surfaces that have come apart before and have their own
scar tissue in `ResizeSurfaces`'s comments.  Not attempted here either, for
the same reason and because a release was wanted today: rushing a change
to that pipeline right before cutting one is how the four surfaces come
apart a second time.  Next real step, when there is room for it properly:
half resolution while `FCameraMoving`, upscaled to the window, full
resolution again the moment it settles.

**Not chased further - the surface guard, the move tool, and the healed
face.**  Three things looked at and set aside on purpose rather than
guessed at:

* The **surface guard** (`uSurface.Verify`, open since 15 September) fired
  twice more in this same session, both times the identical value
  (4618423807647057041, reading as the double 5.98436), both times right
  after "opened the example."  That is new and worth having - the previous
  sighting was a different value and only loosely tied to a resize - but a
  heap-corruption hunt is not a same-pass fix, and chasing it properly
  wants a dedicated session with `heaptrc` and a real repro attempt, not
  the tail end of one already covering four other things.
* The **move tool** staying selected and "loaded" after a commit, so the
  next click moves it again rather than releasing it.  There is already a
  comment in `ProCommit` describing exactly this failure and fixing it for
  one case - a just-built rigid part - and never extending the fix to an
  ordinary move.  Genuinely unclear whether that is an oversight or the
  ordinary case is supposed to stay loaded on purpose, the way SketchUp's
  own Move keeps a selection live for a follow-up move; the reporter
  themselves was not sure it disagreed with SketchUp.  A product call, not
  a bug fixed by reading the code harder.
* The **healed face** - erasing two lines removed a face the report says
  was still closed off by others.  Erasing a face's own boundary removing
  it is correct in every tool including this one; the question is whether
  a *different*, still-intact loop should have kept it alive, which needs
  the actual drawing at that exact moment, not the session log.  The
  report carries both the `.hsk` and a full `/replay` script that
  reconstructs the whole session step by step - a real reproduction is
  possible from it, just not attempted in this pass.

geomtest 1206, region 91, commands, drive 31 - green before this shipped.
