# What this is, and what it is not

Written 5 September 2026, so that the next time something is proposed there is
a decision to argue against rather than a fresh opinion.

## What it is for

Mocking up a real layout before building it.  Rough two things out at a real
scale, pull the measurement you need, and throw the model away.  Duct
transitions and pipe runs, on a laptop, on a job.

Not a model anybody keeps.  Not a deliverable.  A sketch that happens to be
dimensionally honest.

## Why SketchUp is the thing we copy

Because somebody with no CAD background can watch three short videos and
produce a useful 3D mockup faster than in anything else.  That is not an
accident of polish - it comes from two decisions:

* **Push/pull.**  A flat shape becomes a solid by dragging it.  No sketch
  plane, no pad operation, no feature tree.
* **Inference.**  The program guesses what you mean from where the cursor is,
  and shows you the guess before you commit to it.

FreeCAD is more powerful and much worse to use, and the reason is not power.
It is that you have to decide who you are - which workbench, which mode -
before you can draw a line.

## The rule

**If a tool needs a form filled in before you can start, it is the wrong
shape.**

Every dialog moves this towards the thing we are trying not to be.  A tool
should start on the canvas, take its numbers where they are already typed -
the command bar, or onto the drawing itself - and show what it is about to do
before it does it.

Accuracy is not the risk.  Accuracy is free and it is why this could be taken
seriously.  The risk is **tool count and modality**: every tool is one more
thing to learn and one more mode to be in the wrong one of.

## Where we would lose, and should say so

Large models.  Thousands of entities, and a real CAD program will beat this
badly.  The job is tens to hundreds.  A program that is honest about what it
is not stays good at what it is.

## Getting work out

**DXF is the route.**  Every laser, plasma, waterjet and router table is fed
through a CAM package, and every one of those reads DXF.  Between a drawing
and a machine sits the CAM step - lead-ins, kerf compensation, pierce points,
cut order, feeds and power - and that is where the machine-specific knowledge
lives.  Skipping it is not a shortcut, it is doing that work badly.

**G-code is not one language.**  GRBL, Marlin, LinuxCNC, Mach3 and a plasma
height controller all differ.  Writing a G-code exporter means picking a
machine.  Worth doing for a simple GRBL laser, one dialect, *once there is a
machine to test it against* - and not before, because the alternative is
guessing at a dialect for hardware that does not exist yet.

**Embroidery is a different family entirely** - PES, DST, EXP, not G-code -
and the hard part is stitch generation: fill patterns, underlay, density, pull
compensation.  That is a discipline, not an export.

## Decided

* **No protractor** until somebody who actually uses one asks for it.  The
  need underneath it - laying a guide at 45 off an existing edge - is real,
  and is better reached by typing an angle into the tape measure: one code
  path, and testable by the person who wants it.
* **No objects, groups or components.  No booleans, curved surfaces,
  textures, materials or follow-me.  No touch.**  See TODO.md.

## Open

* **The shape of the fitting builders.**  A duct transition is six numbers and
  two choices, and the obvious way to ask for those is a form - which is
  exactly what the rule above forbids.  The alternative is a plan view on the
  canvas that looks like the sketch already drawn on paper, with the numbers
  typed onto it where they are written by hand.  Undecided, and waiting on
  whether drawing the shape by hand and unfolding it turns out to be fast
  enough that a builder is not wanted at all.
