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

## What follows from this

* The ISO view stays a view.  All the tools stay available in it - it is one
  document, and taking tools away per view is a rule that has to be
  maintained for every tool times every view forever.
* The plane in ISO stays something you choose (`K`, or the arrow keys) and
  keep.  Guessing it from the mouse belongs in the 3D view, where a free
  camera makes the guess meaningful.  See `PlaneByDrag` in `uWork.pas`.
* If an iso spool sheet is ever wanted, it is an export off the model.  There
  is a line for it in TODO.md.
