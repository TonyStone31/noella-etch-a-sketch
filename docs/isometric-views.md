# Our ISO view is not a field isometric

Decided 3 September 2026, after Tony asked whether iso drawings in the field
are scaled at all.  Written down so neither of us re-argues it later.

## They are not

A pipe spool isometric is a **schematic, drawn deliberately not to scale**.
The 30 degree axes carry real meaning - direction, orientation, north, up
against down - but the lengths do not.  A forty foot run and an eighteen inch
nipple can come out much the same length on the sheet.

The reason is practical.  A run that goes two hundred feet across and drops
three feet would, drawn to scale, render the drop invisible.  Not-to-scale
keeps every fitting, weld and valve legible on one sheet.  All the information
lives in the annotations instead: cut lengths, elevations, offsets, weld
numbers, fitting takeoffs.  The fabricator reads the numbers and never the
geometry, which is why a real ISO is covered in text.  What is preserved is
direction, topology - the order things come in - and any angle that is not 90
degrees, which gets called out explicitly.

Plumbing riser diagrams and HVAC riser isos work the same way.

Duct and plan coordination drawings are the opposite: those *are* scaled,
1/4" = 1'-0" and so on, because their job is to show whether the duct fits the
ceiling cavity against the other trades.  That is the work this program is
for.

## So what is our ISO view?

A **scaled 3D model seen at 30 degrees**.  It is a camera angle on the same
document that PLAN and 3D show, not a separate kind of drawing.  Lengths are
true, dimensions are labelled at true length, and what you measure is what you
built.

That is worth keeping.  It is what lets you rough something out in 3D and then
flip to ISO to show a pipe fitter, because ISO is how they read a drawing.

## Why we are not building a real ISO mode

**It would fork the document.**  A scaled model and a not-to-scale schematic
cannot be the same data.  We would end up with two file types that know
nothing about each other, which is the opposite of the one-model-three-views
arrangement that makes the ISO view useful in the first place.

**It is an output, not a drawing mode.**  Nobody sketches in not-to-scale
isometric.  In the tools that do this for real the ISO sheet is *generated*
from a 3D route: the software walks the pipe, lays it out schematically, and
hangs the dimensions off it.  So if we ever want it, the right shape is an
export - take a run from the scaled model and emit an iso sheet with callouts
- and not a mode that changes how drawing works.

**It is not the daily job.**  Tony's coworkers do the isos; he does duct
transitions and pulls measurements.  The handful of features that have to be
excellent are the ones he touches every day.

## The part that actually matters for a pipe fitter

Tony's refinement, and it is the useful one: if a welder does use the ISO
view to lay a pipe line out, **he will not care what scale it is**.  He will
snap the run to the paper grid, annotate every leg, and read the numbers.
The scale being true underneath is harmless - it is simply ignored, exactly
the way it is ignored on a real ISO sheet.

So we do not need a not-to-scale mode at all.  What that person needs from
the ISO view is only two things:

1. **Snapping to the paper grid that is easy and predictable.**  The grid has
   to be a grid you can actually land on - see the pitch/snap fix, where the
   ruling used to be finer than the snap could reach - and the plane has to
   stay where it was put rather than being guessed at.
2. **Annotation that is good enough to carry the drawing.**  This is where
   the information lives on a real ISO.  Text notes and point-to-point
   dimensions are in; what is missing is the rest of the dimension tool -
   radius and diameter, dragging an extension line out of the way, typing
   over the text to write a called-out length - and leaders.

That reframes the priority.  Annotation is not a nicety for the ISO view, it
is the whole content of an ISO drawing.  Anything in TODO.md under the
dimension tool is really ISO work.

## What follows from this

* The ISO view stays a view.  All the tools stay available in it - it is one
  document, and taking tools away per view is a rule that has to be
  maintained for every tool times every view forever.
* The plane in ISO stays something you choose (`K`, or the arrow keys) and
  keep.  Guessing it from the mouse belongs in the 3D view, where a free
  camera makes the guess meaningful.  See `PlaneByDrag` in `uWork.pas`.
* If an iso spool sheet is ever wanted, it is an export off the model.  There
  is a line for it in TODO.md.
* Finishing the dimension tool counts as ISO work, not as polish.


---

# Open question, 3 September 2026: what should ISO mode actually be?

Tony, after pushing and pulling a rectangle in the ISO view: *"for an iso it
doesn't seem quite proper... maybe the iso mode is just dumb as fuck but I
think pipe fitters would want it... this deserves further discussion."*

He is right that something is off, and the reason is that **there are three
different things called an isometric drawing in this trade**, and we have
built the first one while his coworkers expect the second.

## 1. A camera on a 3D model - what we have, and what SketchUp has

SketchUp's "Iso" is `Camera > Standard Views > Iso`, together with
`Camera > Parallel Projection`.  That is all it is: a camera angle on a real
3D model, with perspective turned off so lengths stay to scale.  Every tool
keeps working, push/pull included, because there is a real solid underneath.

Ours is the same thing, and by that standard pushing a rectangle in the ISO
view is not a bug - it is the model working as designed.

## 2. A 2D drafting mode on a flat sheet - AutoCAD's ISODRAFT

AutoCAD has a genuine isometric *drafting* mode.  `ISODRAFT` on, and you draw
on a flat sheet using three isoplanes - left, top and right - cycled with F5
or Ctrl+E.  The left isoplane gives you the 90 and 150 degree axes, right
gives 30 and 90, top gives 30 and 150.  Circles are drawn with the ELLIPSE
command's Isocircle option, because a circle on iso paper is an ellipse.

There is **no 3D underneath any of it**.  It is a flat drawing that looks
three-dimensional by convention.  Push/pull is meaningless there because
there is nothing to push - which is exactly the friction Tony felt.

This is the one pipe fitters know.  Our `K` and arrow-key plane switching is
already a close cousin of ISODRAFT's isoplanes; the difference is that ours
moves a plane through real 3D space and theirs just changes which two paper
axes the cursor follows.

## 3. A sheet generated from a model - Plant 3D, Isogen

In the big piping packages nobody draws the iso at all.  The 3D route is
modelled, and the isometric sheet is *generated* from it, with the dimensions
and callouts hung on automatically.  Designers then touch the result up using
ISODRAFT, which is why they are fluent in it.

## So which should we be?

Genuinely undecided, and worth deciding deliberately rather than drifting.

**Staying as we are (1)** costs nothing and keeps one document: build it in
3D, look at it in ISO, hand it to a fitter.  The complaint is that it does not
behave the way a fitter expects when they try to *draw* in it.

**Adding a real drafting mode (2)** would mean a second kind of sheet - flat,
not to scale, isoplanes rather than working planes, isocircles, and no
push/pull.  It is the thing pipe fitters would actually reach for.  It is
also a second document type with its own tools, which is a large commitment
and cuts against one-model-three-views.

**Generating sheets (3)** is the professional answer and the most work by
far, and only makes sense once there is something worth generating from.

A fourth possibility worth weighing: keep one model, and make the ISO view
*behave* more like ISODRAFT for drawing purposes - lock the cursor to the two
paper axes of the current isoplane, draw circles as isocircles - while still
being a view of real 3D geometry.  That might get most of what a fitter wants
without forking the document.  Whether that is clever or a muddle is exactly
what needs discussing.

Nothing to be done until that conversation happens.  Sources:
AutoCAD ISODRAFT - https://help.autodesk.com/cloudhelp/2020/ENU/AutoCAD-Core/files/GUID-061FA171-5425-481C-B24C-887C4E195A7B.htm
SketchUp viewing a model - https://help.sketchup.com/en/sketchup/viewing-model


---

# Resolved, 4 September 2026: three views, one model, and what each view is for

Tony, on the workflow: *"the user should not be required to start in plan view
then be able to use iso.  that's not a quick work flow."*  And on the friction
he kept hitting: *"I can draw on the iso paper grid sort of now as it stands
but then I can also push and pull shit that to me doesn't appear to be drawn
on the grid."*

This settles the open question above.

## What the earlier note got wrong

It assumed a flat iso drafting mode and a real 3D model must be separate
documents, because an isometric projection is ambiguous: a line going up and
to the right could sit anywhere along the third axis.

That is true of geometry floating on its own.  It is false for pipe, and pipe
is the case that prompted all of this.  **A run is a chain.**  Every leg
starts where the last one ended.  Constrain each stroke to one of the three
paper axes - which is all that drawing on iso paper means - and a connected
run has exactly one reading in three dimensions.  There is no ambiguity left
to resolve.

So sketching the way a fitter sketches can build a true 3D route underneath,
and the fork the earlier note feared is not needed.  It only comes back for a
second, disconnected run, and then the answer is to ask where that one starts.

Option 4 in the open question above - keep one model, make ISO behave like
ISODRAFT for drawing - was the right instinct.  This is why it works.

## The rule that decides what a view can do

**A view offers only the operations whose result is visible in it.**

One rule, and it generates the whole table on its own, so there is no
per-tool-per-view list for anyone to maintain or to get out of step.

It is not a matter of taste.  Push and pull in a top-down view extrudes along
Z, dead perpendicular to the screen: nothing moves, and all you get back is a
number.  That is an operation you cannot check at the moment you perform it,
which is the same reason a vertical line in PLAN is a dot.  Withholding it is
not taking a tool away, it is declining to offer one that cannot report what
it did.

## The three views

**PLAN** - straight down, the working plane locked to the ground and kept
there.  For laying out a footprint: duct runs, equipment, a room.  No push and
pull, no drawing out of the ground plane.  A view mode with drawing in it, not
a modelling mode.

**ISO** - the fixed 30 degree camera, and the cursor locked to the two paper
axes of the current isoplane.  No plane guessing from mouse direction; the
isoplane is chosen and kept, the way `K` and the arrow keys already work.
Circles drawn as isocircles.  For sketching a run the way it would be sketched
on paper - and because the strokes are axis-locked and chained, what comes out
is a real route.

**3D** - the free camera, and the only place where anything can be drawn off
the three axes.  Everything is available here.  This is the modelling mode.

Switching views is switching cameras.  It is not a workflow gate: any of the
three is a place to start, and the model is the same model from all of them.

## What is a view and what is a sheet

The reason ISO felt wrong is that a camera was being asked to do an entry
mode's job, and behind that sat a second confusion worth naming:

* **The model** is one thing.  3D, true, scaled.  PLAN, ISO and 3D are
  cameras on it.
* **A sheet** is derived from the model.  Not to scale, annotated, laid out
  to be legible.  A pipe spool isometric is a sheet.  "A forty foot run and a
  two inch nipple are the same length on the paper" can only be true somewhere
  that is not the model, and a sheet is that somewhere.
* **An entry mode** is how geometry gets in.  Iso-grid sketching is an entry
  mode.  It is not a document type.

This is the split every CAD system has, and it is not the SketchUp and LayOut
arrangement that people disliked.  That one made the 2D side a separate
document that was awkward to feed back into the model.  Here the 2D-ish views
are views: they edit the one model directly, with less of the toolset, and
nothing has to be imported anywhere.

## How the trade actually does it

Three tiers, and the striking part is that hardly anybody draws an isometric:

1. **AutoCAD ISODRAFT** - the one fitters know.  A flat sheet, three
   isoplanes (left 90/150, top 30/150, right 30/90), F5 or Ctrl+E to cycle,
   circles as isocircles.  No 3D underneath any of it.
2. **Plant 3D with Isogen, CADWorx, AVEVA E3D, SmartPlant** - model the route
   in 3D and *generate* the sheet, dimensioned, with a bill of material and a
   weld list.  Designers tidy the result in ISODRAFT, which is why they are
   fluent in it.  The sheet is an output and never an input.
3. **The shop and field tools** - and this is the pattern worth taking.  The
   good ones do not have you draw at all.  **You build a run**: pick a start,
   then twelve feet north, ninety ell turning down, four feet down, forty-five,
   six feet.  Direction, length, fitting, repeat.  The drawing is a
   consequence of the route.

That last one matches how the work is described out loud, produces a true
route, gives a clean isometric for nothing, and sidesteps the whole question
of which plane the cursor is on - because a direction is stated rather than
guessed.  It is the largest idea here and probably the one that would matter
most to the people receiving the drawings.

## Still open

**Push and pull in ISO.**  The visibility rule permits it: an extrusion at 30
degrees is plainly visible, and once everything drawn there is grid-locked, an
extrusion along one of the three axes is on the grid too.  Tony's original
complaint may have been about the rectangle not being on the grid rather than
about the push.  Ban it in ISO for coherence, or allow it as honest - not yet
decided.

**Off-grid lines in ISO.**  Fitters do draw them: a forty-five in a principal
plane, and rolling offsets especially, come out off-axis on iso paper and get
called out with an angle or with box dimensions.  So "any deviation means go
to 3D" would block something that happens daily.  Likely answer: grid-locked
by default with a deliberate escape - a held key, or a typed angle - so that
going off-grid is a decision rather than an accident.

## Nothing is being built yet

This is the workflow being agreed, not a plan of work.  The smallest first
step, when there is one, is locking the ISO cursor to the two paper axes of
the current isoplane and drawing circles as isocircles.  That is small, and it
is what makes ISO stop feeling wrong.
