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
