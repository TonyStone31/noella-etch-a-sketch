# How a transition gets called out

Tony's description, 4 September 2026, written down before anything is built
so the tool matches how his shop already writes a ticket rather than a
dialect nobody uses.  **The questions at the end need answering before this
is built.**

## The sketch

It is a plan view.  You are standing on the square duct run looking down at
the gap where the fitting will go, and what you draw is the missing piece.

* An **arrow for the direction of flow**.
* A **rectangle** for the fitting seen from above - narrower at the top of
  the page where it reduces.
* The **sizes written at the top and bottom of the page**: the big end at the
  bottom, the small end at the top.
* If a side comes in, that side of the rectangle is **slanted in**, with an
  arrow and the number of inches it comes in by.
* The height is not in a plan view at all, so it is **written**: `FB` for flat
  bottom, `FT` for flat top, or `top up` / `bottom down` with an amount.

So the paper carries the width and the length as a picture, the offsets as
arrows on the sides, and everything about height as words.

## What that comes to as numbers

| | |
|---|---|
| Big end | width x height |
| Small end | width x height |
| Length | along the run |
| Left offset | inches the left side comes in |
| Right offset | inches the right side comes in |
| Height treatment | flat bottom, flat top, centred, or an amount up or down |

Width and the two side offsets are the same fact twice over - the small width
plus the two offsets is the big width - so the tool should take any two and
work out the third, the way the sketch does.

## The tool this suggests

Not a form of twelve boxes.  A **plan view of the fitting that looks like the
sketch**, with the numbers typed onto it where they are written on paper: the
two sizes above and below, the offsets against the sides they belong to, the
height treatment as a word.  The flow arrow drawn because it is drawn.

Then it builds the four sides in 3D, and from there it can be unfolded and
cut, which is the whole point of putting it in here rather than on paper.

## The rule that ties it together

**Everything is measured from the entry opening, and only one edge per axis
is ever called out.  The opposite edge falls out of the exit size.**

That is why the arrow matters: it says which edge is being dimensioned and
which way it goes.  The rest is arithmetic and does not need writing down.

* `top up 7`, with 20x20 at both ends, means the top of the duct is seven
  inches higher at the exit than at the entry.  The bottom follows, because
  the exit is 20 high.  Nothing tapers; the whole fitting rises.
* `FB` - flat bottom - means the bottom does not move.  On a reduction the
  top then drops by whatever the change in height is, and nobody writes that
  number because it is not a choice.
* An arrow on a side with a number says that side moves in by that much.  The
  other side follows from the exit width.

So the inputs are: two opening sizes, the length of the gap, and for each
axis one named edge and how far it moves.  Six numbers and two choices, and
that is the whole fitting.

## Where the fitting comes from on a job

Duct gets run through a building, and where the size changes the crews leave
a **gap** and carry on with the next size.  Somebody comes behind and
measures that gap.  So the fitting is defined by the hole it has to fill:

* the size of the opening at each end,
* the distance between them,
* how the two openings sit relative to each other.

Which is exactly the list above.  The tool should read like measuring a gap,
because that is what the person doing it is doing.

## The ends matter as much as the shape

A pattern that is the right shape and the wrong size at the edges is scrap.
Each end - and sometimes each edge of an end - carries a treatment, and each
treatment eats or adds material:

* **TDF** - a rolled flange, needs its stock allowance
* **Flange out**, half an inch and so on
* **Flange in**, with the addition bent down or inward
* **Slip**, and **slip all the way round**
* **Drive** - often drive on the bottom and slip on the sides, so the
  treatment is per edge and not per end
* **Raw** - nothing added
* **Corners notched**

This is the same thing as seam and bend allowance and it is not optional:
it decides the size the sheet gets cut.  It belongs beside the fitting as a
per-edge choice with the shop's own numbers behind each name.

## Fittings wanted, in order

1. **Transition** - the one above.
2. **Offset**, or jog: same size both ends, shifted.  The same six numbers
   with no change of size, so it is the same tool.
3. **Ninety, and forty-five, with offsets.**  Square elbows are the next
   family and they are asked for.
4. **Square to round.**  Tony has never made one, so there is no house style
   to follow: use the standard triangulation development the layout books
   give, and expect to iterate on it.

## What is not yet settled


1. **Which side does the arrow name?**  Tony: "the left side with an arrow
   pointing right with the number 3 means that the right side would be set in
   3 inches to the right."  Read strictly that names one side and moves the
   other; read by the rule above it names the side it sits against.  Taken as
   the second, since the rule is stated plainly everywhere else - but this is
   the one to check first on a real ticket.
2. **Which way round is the page?**  Big end at the bottom.  Tony's view is
   that it should not matter once the two opening sizes are typed in, and he
   is right - the page is how it gets written, not what it means.
3. **What each end treatment is worth in material.**  TDF, flange out half an
   inch, flange in, slip, drive, raw.  Every one of them is a number this
   program does not have, and they are the shop's numbers rather than
   anybody's guess.


## Built, 6 September 2026

SHOP > Build a transition... (or /transition) is the wizard: the two openings,
the length, and for each axis the one edge called out - the ticket's numbers,
with the plan-view sketch drawn beside them as they are typed.  Sizes are
inches unless marked.  Build puts the four sides in the drawing as one solid,
open at the ends, with its entry corner on the cursor, and the next click
places it - the move tool, so it snaps to whatever it is being put against.

The arrow question is taken the second way: a side named with an amount is
the side that comes in by that amount, and the other side follows from the
exit width.  End treatments and their allowances are not built; the fitting
is the shape, not yet the cut size.

### Hollow, and reporting from inside

A placed transition is four walls and twelve edges, nothing across the ends.
Placing it used to cap both openings: the four edges of an end are a closed
loop on a plane, and the pass that works flat areas out after a move gave
each a face.  A part placed whole now has its regions taken as seen where it
lands instead of worked out again.

The wizard has its own **Report a problem** button, because a report from the
main window cannot photograph a dialog that is in front of it.  The picture
from there is the whole screen and the report carries the wizard's fields.

### Ends

Each end of the fitting is finished one of these ways, picked in the wizard
with a size in inches:

| End | What is built |
|---|---|
| Raw | The sheet cut square. |
| Notched all round | Each corner cut back by the notch, 1" unless told otherwise, so a slip goes on all four sides in the field.  The walls step round the cut-outs and the seams stop short of the end. |
| Flange out / in | The end bent out (or in) by the flange width, 1" unless told otherwise, on all four sides.  Each flange stops its own width short of the corners - the corner cut that lets the next side fold. |
| TDF flange | A flange out of 1 3/8" with a 1/2" fold back along the duct, the pocket the corner piece and the cleat take hold of. |
| Slip and drive | Slips top and bottom, drives on the sides.  The corners are notched (the slip is the notch); the drive sides get a 1/2" drive edge bent out between the notches. |
| Drive and slip | The same the other way round: drives top and bottom, slips on the sides. |

The drive edge and the TDF fold back are fixed sizes in `uFittings.pas`
(`DRIVE_FLANGE_IN`, `TDF_RETURN_IN`); the notch and flange sizes are typed.
The order of the words in slip-and-drive is taken as top-and-bottom first.
If the shop says it the other way, the two names swap in one place.

### Height

Flat bottom, flat top, centred, and the named edge moved by an amount:
top up, top down, bottom up, bottom down - whichever one could be measured
in the space, with the other edge following from the exit height.

### The sizes on the part

A built fitting carries five dimensions: both openings' width and height,
and the run, measured entry plane to exit plane (the seam is longer whenever
a side comes in).  A tick box in the wizard leaves them off.

### The corner view

Beside the plan sketch the wizard draws the fitting as it will stand, built
by the same code that builds it for real and projected from in front of the
entry, to the right and above.  What is shown is what is made.

### The tag, and the email

A tag typed in the wizard is the fitting's name on the job.  It is written
on the part above the entry, on both pictures, and in the subject of the
email.  Email it... writes the plan and the corner view as pictures and the
ticket as words to `Heckers Sketch/fittings` under the home folder, then
hands them to the mail program as a new message with the files attached -
xdg-email on Linux, Simple MAPI on Windows.  The program sends nothing
itself; the person addresses it and presses send.  When no mail program
answers, the files are still there to attach by hand.
