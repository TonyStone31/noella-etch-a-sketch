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
