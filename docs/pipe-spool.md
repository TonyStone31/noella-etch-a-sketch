# The pipe spool wizard

Written 7 September 2026, when it was built.  SHOP > Pipe spool..., or
`/spool`, `/pipe`.

## What it is

The fitter's iso, as a form.  A pipe fitter in the field draws a spool on
iso paper: a run of legs along the three axes, each with its center-to-center
length written on, not to scale.  The welder makes it from that.  This form
is that piece of paper, with the arithmetic done and a 3D picture of the
result beside it.

## Drawing

Each leg's length is what the fitter measured, and the form asks what it
was measured between: center to center, end to center, center to end, end
to end.  An "end" is the pipe end, the flange face at the start or finish,
or the weld at an elbow.  `CCLength` adds the elbows' take-outs back on to
give center to center, and the cut lengths follow from that.  A leg may be
drawn without a length and given one later by clicking it; the sketch can
be emailed unfinished, the 3D view and Build wait for every length.

The sketch is a sheet of iso paper.  The run starts at a fixed point.  Move
the cursor and the next leg snaps to whichever of the six axis directions
the cursor is most along, and to a whole number of paper steps; hold
**Shift** and it snaps instead to the twelve 45s between axes.  Click to end
the leg, type its center-to-center length in inches, press Enter.  The next
leg starts where that one ended.  Right-click a leg to take it out (the ones
after it close up); the button takes the last one off.  Only lines can be
drawn, on purpose: a spool is lines and elbows.

The paper is not to scale.  Each leg is drawn as long as it was drawn, and
labelled with the length that was typed.  That is how the paper version
works too.

## What is worked out

* **Elbows** at every corner: long radius (1.5 x nominal) or short (1 x
  nominal), the turn being whatever angle the two legs make - 90 on the
  axes, 45 where a leg is on a diagonal.
* **Take-outs**: an elbow takes `R tan(turn / 2)` off each leg it joins.
* **Cut lengths**: center to center less the take-outs at each end.  That is
  the number the welder cuts to, and it is the whole point of the ticket.
* **Ends**: plain bevel, weld-neck flange (drawn as a class 150 disc), cap,
  threaded.

The centerline is the straight legs with the bends drawn in as arcs, and
the 3D spool is a circle of the pipe's outside diameter pushed along it by
Follow Me (`TWorkDoc.Sweep`, open at both ends).  Gores every 15 degrees.

## The ticket

Size and OD, elbow radius, both ends, then every leg: its direction in the
fitter's words (up, right, away, towards you, with "(45)" on a diagonal),
its center-to-center length, its cut length, and the elbow after it.  Then
the count of 90s and 45s, the flanges, and the center-to-center total.

Email it... and Show the files write the iso, the corner view and the
ticket, as the fitting wizard does.  Build it drops the spool into the
drawing on the cursor, with the lengths on it as dimensions.

## Not done

* Branches - a tee off the run - are not drawn.  A spool is one run.
* Rolled 45s that are not on one of the twelve diagonals.
* Reducers within the run, and fittings other than elbows.
* Pipe schedule: the OD is right, the wall is not modelled.
