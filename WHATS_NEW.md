# What's New in Heckers Sketch

<!--
  This is what people see after an update, and under Help > What's new.
  Plain words about what changed for the person drawing; nothing about the
  insides.  Write under "Next release" while working; build.sh renames that
  heading to the tag when it cuts a release.  Sections are shown newest
  first, and an update shows only the ones newer than the version it
  replaced.  Headings: "## v2026.09.05.25" or "## Next release", then
  "### New" and "### Fixed", then "- " bullets.  Keep the bullets short.
-->

## Next release

### Changed

- **The tape readings are a wizard now.**  The builder's form is back to
  the way the shop says a transition - centered, left side in by, bottom
  up by - and a button beside the length, *From the tape...*, opens three
  pictures: the duct against the floor or the ceiling with a figure
  holding the tape, the duct against a wall seen from above, and what it
  comes to.  A box sits on each tape line for the reading and a word
  under it for the edge the tape landed on; the reference flips with one
  button, and the picture follows.  *Use these* puts the offsets into the
  form in shop words, and the readings go on the ticket.  The tick box,
  the readings panel and the Tape tab from the last two releases are gone.

## v2026.09.08.8

### New

- **The tape can land on either edge.**  Each tape reading now says
  which edge it was taken to - the bottom or the top from the floor or
  ceiling, the left or the right side from the wall - so a duct measured
  to its bottom at one end and the equipment measured to its top at the
  other still gives the true offset.  A **Tape** tab in the builder shows
  where the tape went: the duct against the floor or ceiling above, and
  against the wall below, with a dimension line from the reference to the
  edge each reading landed on.  Change the edge and the line jumps.  The
  ticket says which edge each reading was to.

## v2026.09.08.7

### Changed

- **The taped transition's plan shows the result, not the tape.**  The
  wall and the two readings to it are gone from the plan; the wall was only
  where the tape was hooked.  What shows is the offset it comes to - right
  side in by 7, bottom up by 4 - the same as a transition entered the
  usual way.  The readings still print on the ticket.

## v2026.09.08.6

### Fixed

- **The notch is cut the way the snips cut it.**  The point is on the
  seam, the notch depth back from the end; the cut comes into it from
  about three quarters of that out along the opening edge.  The last
  release had the triangle the other way round.

## v2026.09.08.5

### Fixed

- **Notches are cut on the angle.**  A notched or slip-and-drive end used
  to step in square at each corner.  The cut now runs from the notch depth
  along the opening edge back on the angle to an eighth of an inch from
  the corner along the seam, which is how the corner is actually cut, and
  leaves the tab a sharper corner.

## v2026.09.08.4

### New

- **A fitting comes in its crate.**  The builder's 3D tab, and the ghost
  while a built fitting is being placed, draw the box the fitting fits in:
  the floor marked, IN at the entry end, OUT at the exit, TOP on the lid.
  A strange transition orbited or seen from below then still says which
  way is up and which end goes first.  The crate is drawn, not built -
  nothing of it goes into the drawing, so there is nothing to delete.

## v2026.09.08.3

### New

- **Flex connectors on a transition.**  Either end can carry a canvas
  flex connector - the Junior, 1 3/4-3-1 3/4; the 3-3-3; the 3-6-3 - with
  the end's finish on the flex's far strip, since that strip is what gets
  notched for an S-lock, bent for a drive or for a TDF flange.  The
  fabric is drawn squashed to half, the way it goes in, and the
  sheet-metal body is that much shorter: the length typed is the whole
  thing.  The ticket names the flex, what it takes out of the length, and
  the metal left flex to flex.

## v2026.09.08.2

### New

- **A transition taped from the floor and a wall.**  A tick on the
  builder swaps the side and height rules for four tape readings: from the
  floor to the bottom of the opening or from the ceiling to the top, and
  from the left wall to the left side or the right wall to the right side,
  one reading at each end, the entry usually 0.  The rules come out as
  differences - entry tight to the ceiling and the exit 4" down is top
  down by 4 - so nobody does the arithmetic in the field.  The plan shows
  the wall the tape was hooked on with both readings, and the ticket
  prints the readings under the rules.  An exit that runs past the wall
  or ceiling reads negative and prints as "out by".  Untick it and the
  builder is exactly as before.

### Fixed

- The builder's plan said "bottom down" for a top-down or bottom-up rule.

## v2026.09.08.1

### Changed

- **The fitting builder remembers the last fitting.**  It opens the way
  it was when the last one was built - sizes, rules, ends, angle, branch,
  all of it - since one fitting is usually much like the one before.  Only
  the tag starts blank.

## v2026.09.08

### New

- **Touch on Linux.**  The drawing now takes fingers from a touchscreen:
  a tap is a click, a finger dragged is the mouse, two fingers pan, and a
  pinch zooms about the point between them.  The toolkit was being given
  the touch events and throwing them away, which is why the drawing got
  nothing while the buttons and the window frame worked.  `/touch` says
  whether the hook is in.  Windows is unchanged for now: it turns a finger
  into a mouse by itself.  What comes next for touch, tablets and the
  remote desktop is written down in `docs/touch.md`.

## v2026.09.07.22

### Changed

- **The report form takes the picture first.**  No question before the
  form: it opens with a picture of the window as it was, in view while
  you write.  On the form, `Snap now` takes it again with the form out of
  the way, `Snap in 10 s` gives time to set something up to show and
  brings the form straight back, and `Discard picture` sends the report
  without one.  Enter while writing no longer sends the report - one
  arrived cut off in the middle of a word that way.  `/report` opens the
  form from the command bar.
- **`/sysinfo` shows its facts in a box** in the program's own style,
  instead of squeezing them into the command bar.

## v2026.09.07.21

### Changed

- **Everything stays with the program.**  The fitting and spool tickets
  used to be written under the user's home folder; they go beside the
  program now, in a `fittings` folder next to the settings and the draft,
  so a copy on a USB stick leaves nothing behind.  And every bug report
  sent is kept there too, text and picture under the name it was sent as,
  in `reports-sent`.

## v2026.09.07.20

### Fixed

- **Dimensions showing through a duct.**  A dimension lying in the plane
  of a face was put back whole once its middle was in the clear, so the
  parts of it behind the walls showed through them.  A dimension is drawn
  like a line now: only the stretches of its three lines that nothing
  stands in front of, and its ticks and figure only where their place is
  clear.

## v2026.09.07.19

### Fixed

- **A crash after switching sheets.**  The selection was kept across a
  tab switch, still pointing at the things on the sheet just left, and a
  move on the new sheet then read past its end.  Switching, adding or
  closing a sheet now lets go of the selection and the hover, and a move
  drops anything selected that is not on the sheet.

## v2026.09.07.18

### Faster

- **Moving, selecting and deleting on a big drawing.**  Measured on fifty
  thousand things - 2,500 boxes with a line across two faces of each -
  everything selected: a move took 65 seconds to work the faces out
  afterwards; it takes 1.5 now.  Deleting the selection took a minute; it
  is instant.  Hovering with everything selected redrew fifty thousand
  outlines through the canvas on every mouse move, 117 ms a frame; the
  outlines are drawn once into a layer now, 23 ms.  Select-all and box
  select no longer walk the whole selection for every thing they add.
  The things fixed underneath: old faces were deleted one at a time, each
  shifting everything after it; every region asked every old face and
  every seen area instead of the ones in its own plane; the pass that
  divides a solid's face asked every region on the plane instead of the
  ones inside the face; and the busy bar was repainting the whole window
  every few dozen regions, which was thirty of those seconds by itself.

## v2026.09.07.17

### New

- **Reports say what machine they came from.**  A bug report, and the
  crash file, now carry the operating system, the processor and how many
  cores, the RAM and how much of it is free, the graphics driver and
  whether an OpenGL library is there, the display size, the toolkit the
  program was built with, and how much memory the program itself is
  using.  Nothing about the person: no name, no path, no serial number,
  nothing that needs asking for, and no other program is run to find it
  out.  `/sysinfo` shows exactly what would be sent.

## v2026.09.07.16

### New

- **A start-up screen.**  The program now puts up a card the moment it
  starts, with the version on it, and says what it is doing while a
  drawing comes in - reading it, sorting the lines by plane, finding the
  flat areas, working out the faces - with a progress bar.  A drawing that
  is taking too long can be skipped with the button on the card; the file
  is left untouched, and a skipped draft is kept beside the settings as
  `heckers-sketch-draft-skipped.hsk`.  The card stays up four seconds even
  when there was nothing to wait for, so it never just flashes.
- **A progress bar on the command bar.**  Long work on a big drawing -
  the faces being worked out after a move, say - now shows what it is
  doing and how far along it is, in place of the prompt, instead of the
  program looking hung.  Clicks and keys wait until it is done.

### Faster

- **Opening a big drawing.**  Sorting the lines by plane looked every end
  up against every other end, and every plane against every plane.  On a
  drawing of two hundred thousand things that was sixteen of the twenty
  seconds it took to open; it is well under a second now.

## v2026.09.07.15

### Under the hood

- **The worker's result is taken as soon as it is done.**  A result
  queued back to the main thread was only delivered when the program was
  idle, and a program painting frame after frame never was: on a drawing
  of fifty thousand things a cache that took a second to build waited
  nearly three more before it was used.  The renderer now looks at the
  queue itself.  `/rendertime` also says how long the last cache build
  took and where it ran, how long its result waited, and what a frame
  without the cache spent on lines-on-faces.

## v2026.09.07.14

### Under the hood

- **The first worker thread.**  Working out which lines lie on which
  faces - a cache the renderer keeps - is now done off the main thread on
  a big drawing, from a copy of the drawing.  While it is being built the
  renderer searches every face as it did before, so nothing waits on it
  and nothing is wrong if it is late.  `/threads` turns the workers off,
  and `/rendertime` says how long the worker took and how many frames went
  without the cache.

## v2026.09.07.13

### Fixed

- **A crash while moving on a big drawing.**  Working the faces out after
  a move could read the wrong entity once a face had been divided, and on
  a drawing of thousands of things that was an access violation.

## v2026.09.07.12

### Fixed

- **Selecting everything on a huge drawing no longer stalls every mouse
  move.**  Past a few thousand selected things the highlight is drawn
  plainly, edges only.  On a drawing of thirty thousand things with all of
  it selected, each repaint went from over half a second to a twenty-fifth.
- **What is off the screen is not drawn.**  Zoomed in on a corner of a big
  drawing, the faces and edges outside the window are skipped before any
  work is done on them.

## v2026.09.07.11

### New

- **Quicker frames while you orbit, pan or zoom.**  While the camera is
  moving the drawing is redrawn a cheaper way - the hidden-line work is
  sampled coarser and the faces are filled without anti-aliasing - and the
  full-quality frame is drawn the moment you let go, or a fifth of a second
  after the wheel stops.  The picture stays complete while it moves, just
  a touch rougher at the ends of hidden lines.  A big drawing orbits in
  about half the time.  If you would rather every frame were the full one,
  `/quick` turns it off and on.

## v2026.09.07.10

### Fixed

- **Big drawings orbit faster again.**  Which faces each edge lies on is
  now worked out once when the drawing changes rather than for every frame,
  and a copy of every face the renderer made each frame and never used is
  gone.  On ten spools - five thousand faces - the edge pass halved.

## v2026.09.07.9

### Fixed

- **Placing a built fitting or spool ends there.**  After the placing click
  the part was left selected under the move tool, so the next click picked
  it up again, which read as the click not having placed it.  It is let go
  of now and the select tool comes back.

## v2026.09.07.8

### New

- **Scratchpad: click, type, click.**  Type a leg's length and the click
  that starts the next leg takes it - no Enter between legs, so a hand can
  stay on the number pad and work down the run.

## v2026.09.07.7

### Fixed

- **No more black ring on a ball or a donut.**  The circle a Follow Me was
  made from - the profile, or the circle followed round - stayed drawn as
  a hard line across the surface.  It becomes a seam of the surface now,
  soft and hidden like the seams between gores.

## v2026.09.07.6

### Fixed

- **Moving a big fitting is quick again.**  The move itself asked every
  corner in the drawing whether it was one of the moving ones, one at a
  time, and working the faces out afterwards compared every area against
  every face twice over.  Both now look things up instead of walking for
  them.  Moving a whole spool went from a third of a second to a sixteenth.

## v2026.09.07.5

### Fixed

- **Selecting and moving a big fitting no longer freezes the program.**
  Two things were wrong.  Taking everything joined to a click grew the
  selection a pass at a time, testing everything against everything, which
  on a spool of sixteen hundred pieces took the program away for a minute.
  And painting the selection asked "is this point hidden" by walking every
  face, a hundred times per selected piece per frame.  The first is a
  proper flood now; the second reads the depth the renderer already worked
  out.  A whole spool selects in a blink and its highlight paints in a
  fortieth of a second.
- `/all` selects everything on the sheet.

## v2026.09.07.4

### Fixed

- **Built fittings stay hollow whatever you do to them.**  Moving, turning
  or copying a fitting after placing it capped its open ends - the program
  worked the flat areas out again and took the ends for newly closed
  areas.  An opening edged entirely by a solid's own edges is now never
  given a face: a duct end, a pipe end, a hole rubbed out of a box.  Ends
  already capped in a drawing are ordinary faces; the eraser takes them.

## v2026.09.07.3

### Fixed

- **Orbiting is three times faster on big drawings.**  The faces were
  being sorted by a method whose cost grows with the square of their
  number, and the edge index was kept in a sorted list that shuffled
  memory on every insert.  Both replaced.  A four-leg spool of 528 faces
  now draws in 8 milliseconds a frame in the ordinary build, from 29 at
  the start of the day.

## v2026.09.07.2

### New

- **Reducers and flanged joints** in the fitter's scratchpad.  Under the
  measurement, say what sits at the far end of a leg: nothing, a reducer to
  another size, or a flanged joint.  The legs after a reducer are the new
  size, the cut lengths lose the fitting, the 3D shows the step down or the
  pair of flanges, and the ticket lists them with the reducer's length.
- The scratchpad's paper is dots again, with lined paper as the other
  choice, and the leg the cursor is about to make shows plainly on both.

### Fixed

- The deck's tool buttons ran over the icons on the right once Follow Me
  joined them.  They share the width properly now.
- Orbiting a drawing full of pipe: two passes of the renderer did far more
  work than they needed - building the edge index, and testing every line
  against every face with a fresh normal each time.  A four-leg spool went
  from 29 to 21 milliseconds a frame in the ordinary build.  The checked
  build is slower by nature; see the notes on it below.
- The report picture taken "now" waited for nothing and caught the
  question box still on screen.  It gives the box a moment to go.

## v2026.09.07.1

### New

- **The fitter's scratchpad** is what the pipe spool wizard is called now,
  and it works the way a tape does.  Each leg says what its length was
  measured between: center to center, end to center, center to end, or
  end to end - an end being the pipe end, the flange face, or the weld at
  an elbow.  The ticket turns that into center-to-center and cut lengths
  with the elbows' take-outs already off.  A leg can be drawn without a
  length and given one later by clicking it, and a sketch with lengths
  still to come can be emailed as it stands; the 3D view and Build it wait
  until every leg has its number.  The paper is ruled like iso paper, with
  dots as the other choice.
- Center, not centre: the wizards' words are American now.

## v2026.09.07

### New

- **Pipe spool.**  SHOP > Pipe spool..., or /spool: the pipe fitter's iso
  as a form.  Iso paper you click the run onto, one leg at a time - each
  leg snaps to the three axes, or with Shift to a 45 - and type the
  centre-to-centre length on.  Pick the pipe size, long or short radius
  elbows, and what each end is: bevelled, a weld-neck flange, a cap, or
  threaded.  The ticket writes itself underneath with every leg's cut
  length, the elbows' take-outs already off, and the 3D tab shows the
  spool built from the same numbers.  Email it to the shop, or Build it
  into the drawing with the lengths on it.

## v2026.09.06.30

### New

- **Follow Me follows a path.**  Click the face, then click a line or an
  arc: the face is pushed along every edge joined to it, end to end, and
  mitred at each corner - a square along an L is an L of square tube, a
  circle along a line with a 90 arc in it is a round elbow with straight
  legs, a circle round a rectangle of lines is a rectangular ring of pipe.
  Or select the path first and then click the face, SketchUp's own way.  A
  closed path has no caps; an open one keeps the profile as one cap and
  adds the other.  A whole circle clicked as the path still spins the face
  round its centre.

## v2026.09.06.29

### New

- **Follow Me.**  A new tool with the drawing tools: spin a face round an
  axis into a solid.  Click the face, then two points on the axis - or
  click a circle to follow round, the way SketchUp does it.  Type an angle
  first, 90 or 180, for a part turn; a plain click goes all the way round.
  A half circle spun on its diameter is a ball; a rectangle spun beside an
  axis is a tube; a profile spun on its edge is a cone, a cap, a round
  reducer.  The gores follow the circle side count, so `24s` gives a
  24-gore turn.  Following a path of lines and arcs - round elbows and
  spools - is the next half of this tool.

## v2026.09.06.28

### New

- **Circles have points to aim at.**  The four quadrant points of a circle
  - where it crosses its own plane's axes - snap, marked QUADRANT.  Where
  two arcs cross, in one plane or on two different planes, the crossing
  snaps, and the pieces either side of it get middles, as cut lines do.  An
  arc nothing crosses has a middle.  Building a ball or a pipe crossing out
  of circles now has something to land on.

## v2026.09.06.27

### Fixed

- **Footings: nested rings are their own faces.**  Offset a rectangle
  twice and the outer ring was cut out all the way to the middle and the
  eraser took two faces for one.  A loop inside a loop is now a hole in the
  nearest ring only, so each ring is its own face and erases on its own.
  Drawings made before this need `/rebuild` (or any edit) to be worked out
  again.
- The eraser's tip now says it sweeps: hold the button and drag across
  several things to take them all at once, the way SketchUp's does.

## v2026.09.06.26

### New

- `/select` and `/move` in the command bar, alongside the other tools.

### Fixed

- **Offset lands on the guide.**  With the cursor snapped to a guide, a
  guide point, a corner or an edge, the offset is now measured to that
  point exactly.  It used to take where the mouse was and round it to the
  snap step, so a guide 8" in could give an offset of 9".  Put a guide where
  the footing edge goes and the offset goes there.

## v2026.09.06.25

### Fixed

- The outside of an elbow, a tee's walls, and some transition sides were
  painted in the inside colour.  The builder wound those faces the wrong
  way round; every face a fitting is built from now faces out.  Fittings
  already in a drawing keep the winding they were built with - build them
  again to get the new one.
- A flange or a drive edge on a slanted side now lies in the plane of the
  end, the way the cleat goes on, rather than square to the wall.

### New

- `/rendertime` in the command bar times ten frames and says how long one
  takes, for chasing a slow orbit.

## v2026.09.06.24

### New

- **Reducing elbows.**  An elbow can be given an exit opening of a
  different size.  The size across the turn changes through the turn, the
  heel spiralling in; the other size changes in the exit leg, which is
  straight metal, so the exit leg needs a length when it does.  Blank exit
  sizes keep the entry size.
- **An elbow from field measurements.**  On the elbow page, "From field
  measurements..." takes what can be measured on the job: from the inside
  corner of the open end, straight ahead and across to the near inside
  corner of the duct it has to meet, and either the angle that duct runs
  at or a second point along its inside edge.  With the throat radius
  chosen it works out the angle and both legs so the elbow lands there,
  shows it, and puts the numbers into the elbow's fields.
- **A tee's branch centres itself.**  Leave "starts, from the entry" blank
  and the branch sits in the middle of the run, the way a blank height
  already centres it on the wall.

### Fixed

- A drawing that was nothing but built fittings came back from a save or
  a restart with every open end capped on the next edit.  The program took
  a drawing whose faces all belong to solids for an old file with no faces
  and worked its areas out again.  It now knows a solid's faces are faces.

## v2026.09.06.22

### New

- **Elbows and tees.**  The fitting wizard - Build a fitting... under SHOP,
  or /elbow, /tee, /transition - has radio buttons at the top for a
  transition, an elbow or a tee.  An elbow takes its opening, the angle
  (22.5, 45, 90, or any other), which way it turns seen from the entry,
  the throat radius (0 for a square throat), a square or rolled heel, and
  the straight legs at each end; it is built gore by gore.  A tee takes the
  run, the branch opening, which wall it comes off, where it starts, and
  the branch length, and cuts the opening out of the wall.  Ends, the tag,
  the dimensions, the plan and 3D views, the email and the files all work
  the same for every kind.
- **Show the files.**  The same pictures and ticket, written and shown in
  the file manager with the plan picked out, for when they go somewhere
  other than an email.

## v2026.09.06.19

### New

- **Email the ticket from the builder.**  An "Email it..." button in the
  transition wizard opens a new message in your mail program with the plan,
  the corner view and every input as words, attached and ready to send to
  the office.  The files are also kept under Heckers Sketch/fittings in your
  home folder.  Nothing is sent by the program itself.
- **A tag on the fitting.**  Name it on the ticket - T-3, kitchen supply -
  and the name is written on the part when it drops into the drawing, on
  both pictures, and in the email subject.
- **Plan and 3D on tabs.**  The wizard's two views sit on tabs, so the form
  takes less room and either can be watched while the numbers go in.

## v2026.09.06.18

### New

- **The transition wizard finishes the ends.**  Each end can be raw, notched
  all round for a field slip, flange out, flange in, TDF flange, slip and
  drive, or drive and slip, each with its size, and the fitting is built
  with them - notches cut, flanges and drives bent out, the TDF fold back -
  so the 3D part shows the connection.
- **Height has all four moves.**  Top up by, top down by, bottom up by and
  bottom down by, for whichever edge could be measured in the space.
- **The sizes go on.**  A built fitting carries its dimensions: both
  openings and the run.  A tick box in the wizard turns that off.
- **A corner view in the wizard.**  Beside the plan sketch, the fitting as
  it will be built, ends and all, from in front of the entry.

### Fixed

- Moving or turning a dimension along with other things sent its line off
  by the whole distance moved.  The dimension's offset now travels as a
  direction, and the line stays put against what it measures.

## v2026.09.06.17

### New

- A **Report a problem** button inside the transition wizard.  The picture
  is the whole screen with the wizard in it, and what was typed into the
  wizard goes into the report.

### Fixed

- A built transition is hollow again.  Placing it was capping both ends.

## v2026.09.06.16

### New

- The move tool taken to a dimension's line repositions the line - further
  out, the other side, or standing up on another plane - while the two points
  it measures stay put.  The eraser takes a dimension by its line or its
  witness lines.

### Fixed

- With nothing selected, rotate now takes everything joined to what you
  click, so turning a box turns the box instead of twisting it.  To turn a
  part on its own, select it first: one click for one thing, a double click
  for a face and its edges, a triple click for all that is joined.

## v2026.09.06.14

### New

- Copy arrays, SketchUp's way.  Ctrl-move something to leave a copy, then
  type 3x (or x3, *3) for three copies that far apart, or /3 to divide the
  run into three.  The same after a Ctrl-rotate: 6x for six round the
  circle, /6 to divide the turn.  Typing another count replaces the last.

## v2026.09.06.13

### New

- The view button has a drop-down arrow: click the name to step through the
  views, click the arrow to pick one from the list.

## v2026.09.06.12

### New

- Build a transition.  SHOP > Build a transition... (or /transition) takes
  the ticket - the two openings, the length, which side comes in and by how
  much, flat bottom or flat top or top up - draws the sketch beside the
  numbers as you type, and builds the four sides as one piece with its
  entry corner on the cursor; click to put it where it goes.  Sizes are
  inches unless you write a foot mark.
- One view button in place of PLAN / ISO / 3D.  It parks the camera on a
  named view - the four corners, the top, the four sides - left click steps
  forward, right click back, and it reads 3D as soon as you orbit off.  The
  paper modes are under SHOP as the field sketch, for the wizard that will
  be built on them.

## v2026.09.06.11

### Fixed

- The dimension tool takes a corner as a point.  A corner is always on an
  edge, and a click near an edge took the whole edge, so a dimension from
  one corner to another - across the drawing, between things that are not
  connected - could not be started.  A point the cursor has snapped to is
  the point meant; the body of an edge still takes all of it.

## v2026.09.06.10

### New

- The cursor tip says it now: a dimension can run between any two points -
  a corner of the footing and the roof next door - with the dimension tool
  or by pressing Enter after a tape measurement.  Both already worked; the
  tip did not say so.

## v2026.09.06.9

### Fixed

- The middle of a footing ring can be erased.  A rectangle offset out and
  in, with the middle lines removed, makes a ring with a hole; erasing the
  face in the hole gave it straight back, because the check for "was there
  a face here" looked only at the ring's outline and not at its hole.
- The rear edges of a pulled circle and the top of a column drew dashed in
  the last build; the hidden-line test had been made too strict for the
  depth buffer's precision on a model far from the origin.

## v2026.09.06.8

### Fixed

- The last of the line bleed: the corners of a tunnel's mouth and the
  creases of a cylinder no longer poke a pixel or two into the face beside
  them.  Heavier profile lines end exactly on their corners too.
- Hovering or selecting an edge lights only the part of it you can see, the
  way SketchUp does, instead of the whole line through every face.

## v2026.09.06.7

### Fixed

- Drawing on the face of a box is steadier.  The "line up with that
  corner" nudges used to grab the cursor every few pixels as it swept
  across a face; they wait for the hand to slow down now, and one taken
  holds a little longer than it took to get, so it does not flicker.
  Snapping to points and edges is unchanged.

## v2026.09.06.6

### Fixed

- A line hidden behind something no longer runs a little way into the face
  that hides it: the visible part ends exactly at the edge.  Same for arcs
  and circles.

## v2026.09.06.5

### Fixed

- A circle drawn with few sides was still outlined smooth in some views
  while its face and anything pulled from it were faceted.  Every drawing
  pass uses the side count now.

## v2026.09.06.4

### New

- Sending a report shows what is going, stage by stage, in a window like
  the update's - the text and its size, the report's name, the picture -
  with a moment on each so it can be read.  If it does not go, the window
  says why and waits.
- When something goes wrong inside the program and it keeps running, it
  offers to send the report right then, not at the next start.

### Fixed

- Drilling a tunnel through another one could bring the program down after
  the cut, while it was trimming the edges: a bookkeeping slip after the
  walls were removed.

## v2026.09.06.3

### Fixed

- A tunnel whose floor met a round tunnel exactly at one of its creases
  left that floor uncut; the crossing is found along the crease now.

## v2026.09.06.2

### New

- Round tunnels drill through square ones and square through round: the
  crossing is cut on every segment.  Twelve sides makes a clean job of it.
- How many sides a circle or an arc gets is yours: + and - while the tool is
  in hand, or type 24s (or s24), the way SketchUp takes it.  The cursor tip
  says the count and how to change it.  Circles start at 24, arcs at 12.
- The cursor tip gives an example of what to type for every tool - 12'6,
  6-8-15, 8x10, 45 or 8:12, [x,y,z] - not just "type a length".

### Fixed

- Snapping no longer grabs points hidden behind a face.  Drawing on a wall
  used to catch the corner of a tunnel behind it and put the click inside
  the block.
- The update window pauses on each step long enough to be read.

## v2026.09.06.1

### Fixed

- Where two tunnels cross, the edges drawn along each tunnel no longer run
  on through the other one's bore.

## v2026.09.06

### New

- DRILL (B): push a shape through a block that already has a tunnel in it
  and the two tunnels cut into each other - both walls opened where they
  cross, nothing left inside either bore.  SketchUp stops at the first
  tunnel and leaves you to Intersect Faces and erase by hand; this makes the
  manifold in one push.  Square openings for now; round ones next.
- Push/pull stops where it would run into a tunnel, the way SketchUp's does,
  and says how far it got and that Drill goes on through.

### Fixed

- A plane held with an arrow key passes through the face under the cursor,
  instead of floating wherever the cursor last was.

## v2026.09.05.31

### Fixed

- A tunnel pushed through a box opens both ends, whichever wall it starts
  from.  In one direction the wall it started from stayed filled, because
  the rule that divides a wall for a shape drawn on it gave up once anything
  else had split that wall's edges.
- The far end of a tunnel no longer gets filled back in by the next thing
  you draw.
- A wall divided by a shape drawn on it no longer turns blue - a piece could
  come out facing into the box.
- The walls lining a tunnel face inward whichever way the push went.

## v2026.09.05.30

### Fixed

- An arc's pull only takes the arc onto a face that holds all three of its
  points.  A pull that snapped to some stray point behind the wall used to
  tilt the arc off the wall.

## v2026.09.05.29

### New

- Pushing or pulling a face stops at whatever point or edge the cursor is
  resting on - hover the far edge of a box and the push goes exactly that
  deep.  Faces already did this; points and edges do now.
- Push a shape on the side of a solid straight through to the far side and
  it makes a hole: both faces open, the tunnel walled, nothing to erase.

## v2026.09.05.28

### New

- The arc tool shows what it is doing: the two ends marked, the chord, the
  pull from the chord's middle in the color of the axis it runs along - blue
  when it goes straight up a wall - and the arc itself where it will land.
  The bulge reads live in the bar.
- ON FACE: a point resting on a face says so, with a blue mark, the way
  SketchUp's does.

### Fixed

- An arc drawn up the end of a box stands on the end of the box.  It used
  to drop onto the ground when the first click landed on an edge, because
  the arc was built in the working plane whatever the three points said.
  Three points make a plane, and the arc is built in theirs.

## v2026.09.05.27

### Fixed

- Erasing an arc's face on the end of a box works.  The face came straight
  back, because the check for "was there a face here" was matching a face on
  the far end of the box - same direction, different wall.
- A wall with a rounded bite out of it no longer grows a second, loose copy
  of itself over the top.

## v2026.09.05.26

### New

- Updating shows a proper progress window: download size and percentage,
  the checksum check, the install, and the restart.
- After an update, this window shows what changed.  It is also under the
  help button as "What's new", any time.
- A typed distance on the tape measure lays the guide.  Click the first
  point, aim along an edge or an axis, type how far, and Enter puts down
  the guide line and its point exactly as a click would.
- The program opens in PRO now, not the toy, and a new sheet starts on the
  3D corner view instead of the flat plan.

### Fixed

- On Linux, the program restarts properly after an update.  It used to
  install the new version and then fail to come back up.

## v2026.09.05.25

### New

- Rotate: click the center, a point to measure from, then swing to the
  angle and click, or type it - 45, 22.5, or 8:12 for a slope.  The arrows
  pick the plane by axis color, Ctrl leaves a turned copy, and the angle
  snaps to the fifteens near them.  Q, or the ROTATE button.
- A protractor that lays guides at an angle, the same three clicks.

### Fixed

- Openings in a face now travel with it when it is moved.
- A move locked to blue drew its travel line grey instead of blue.

## v2026.09.05.24

### New

- Notes can be made bigger or smaller: pick one, then + or -.
- Clicking the words of a note picks it.  It used to grab the note for a
  drag and then let go without selecting it.

## v2026.09.05.23

### New

- DXF export: the flat pattern for a cutting table, and the whole drawing
  either flat or as a 3D model, with layers for cuts, bends and notches.

## v2026.09.05.22

### New

- The shop pattern marks brake notches at the ends of every bend line.
- A dimension can be placed outside a closed shape, not only inside it.
- Arcs drawn on a solid's face split that face, the way lines do.

### Fixed

- Offset put its copy a long way from the face.  It stays on the face's
  plane now.

## v2026.09.05.21

### New

- The flat pattern carries the openings cut through a piece.

### Fixed

- The eraser's blue wash stopped at what was in front of the face being
  erased, instead of painting over it.
