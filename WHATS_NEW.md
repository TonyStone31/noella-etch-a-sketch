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
