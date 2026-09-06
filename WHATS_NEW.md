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
