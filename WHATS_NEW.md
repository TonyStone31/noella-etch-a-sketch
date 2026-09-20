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

### New

- **Drill stops where you say.**  Type a depth and the drill makes a hole
  exactly that deep and no deeper - through any passage already in the
  block on the way, which push/pull will not do, since push/pull stops at
  the first passage it meets.  Say nothing and it goes through, as before.

## v2026.09.20.6

### Fixed

- **The report window's summary is a page of its own** - drawn by LazInk
  from a line of Markdown for each thing that went, the label and the
  verdict in bold, so a long file name wraps instead of running off.

## v2026.09.20.5

### New

- **The report window stays until you close it, and says what went.**  A
  line for the report and its size, whether the drawing was in it, how big
  it became once sealed, the picture, and whether each of them arrived - or
  why not - a small page of its own, drawn by LazInk, so the words that
  matter are bold.  It used to close itself the moment the report had gone.  The
  sealing stage also holds long enough to read: the report is encrypted to
  a key only we hold before it leaves your machine, and that is worth a
  moment on the screen.

## v2026.09.20.4

### New

- **A group's crate snaps.**  The box round a group - its corners, the
  middles of its edges, the centers of its sides and its center - are snap
  points from outside, the same points SketchUp puts grips on, so a guide
  or a line can be set to a locked group's crate.  A locked group shows its
  crate faintly all the time.

### Fixed

- **The move tool grabbed a guide point instead of the corner it marked.**
  It takes the drawing first now, and a guide only when it is on its own.
  A guide on its own still moves, as in SketchUp.

## v2026.09.20.3

### Fixed

- **A drawing that opened showing nothing.**  A sheet handed over from the
  last version came back with its camera zoomed out to the smallest the
  program allows, so there was nothing on the paper until the view was
  changed.  A saved view that shows none of the drawing is framed instead
  now, and says so in a report.
- **Erasing a guide point took the points beside it.**  The eraser asked
  the guide line first, the point sits on its line, and rubbing out the
  line takes every point on it.  It asks the point first now, the way the
  select tool does.
- **The report window says the report is being sealed** - the pause was
  there, the words were not.

## v2026.09.20.2

### Fixed

- **A rectangle traced round an opening heals it.**  Rub the top off a box
  and draw a rectangle over where it was, and the top is back - the way
  redrawing an edge with the line tool has put a face back since
  September 15.  Only the line tool knew the trick; the rectangle drew four
  lines onto edges that were already there and no face came.  From the
  report of 19 September.
- **A face healed back onto a box faced into it**, and showed blue.  It
  faces out now.

## v2026.09.20.1

### New

- **Groups.**  Pick something and press Ctrl+G (or `/group`, or the right
  button's Make Group) and it becomes a thing of its own: nothing outside
  it joins onto it, cuts it, or stretches it when it moves, and a click on
  any part of it takes all of it.  Double-click to work inside one - the
  rest of the drawing fades and stays out of reach until Escape or a click
  on nothing brings you back out.  Groups nest, `/name` names them, `/lock`
  keeps one from being changed at all while still letting you snap to it,
  and `/explode` takes one apart.  It is SketchUp's group, and behaves the
  way theirs does, from their own help pages.  There is a page in the
  manual.

## v2026.09.20

### Fixed

- **Faces were quietly piling up in stacks, and Reverse looked broken
  because of it.**  Around a rounded corner - a fillet, or a notch with
  arcs in it - the program could find the same flat area twice, and then
  lay a fresh face over it on every edit.  One sheet reported on 19
  September had ninety-nine surplus faces, some five deep, and a face that
  "would not reverse" was the top of a stack: it turned over, and the copy
  underneath still showed its back.  It also made every edit on that sheet
  a little slower than the last.  Both causes are fixed; a drawing that
  already has stacks in it is cleaned up by its next edit, or by
  `/reface`.
- **A report now names the sheet it was sent from**, not just its number -
  a drawing with tabs called "Broom" and "Sheet 1" in that order was read
  on the wrong sheet for an hour.

## v2026.09.19.2

### Fixed

- **The rectangle and line tools no longer blink out their own corner.**  A
  small square rides with the cursor so it can be drawn crisp against the
  drawing under it; pasting it back used to erase whatever the tool itself
  was drawing right there, which for a rectangle or a line is exactly its
  near corner - so it flickered out every time the pointer crossed it.
  Fixed at the source: the corner is drawn into the square now, not wiped
  by it.
- **A bug report is encrypted before it leaves your machine.**  Reports go
  to a public postbox with no lock on it - that was always true, it had to
  be, since the program has no server of its own to ask first.  What was
  not true is that a report sitting in it was readable by anyone who found
  the address.  Now it is sealed to a key only we hold before it is sent;
  what a screenshot or a drawing says is between you and us, whatever
  happens to the box it travels in.

## v2026.09.19.1

### New

- **Export a film as WebP.**  Beside GIF in the export, and lossless: every
  shade the drawing has, where a GIF keeps 256 of them.  Nothing extra is
  shipped or installed to make one - the encoder is Pascal, in the program.
- **The about box says who built what.**  It is a proper page now, with the
  people whose work is inside this program named and linked - including
  Xelitan, whose WebP encoder is why the export above needs nothing beside
  it.
- **A page about the other programs.**  What this is for, what the likes of
  SketchUp, FreeCAD and LibreCAD do better, and when you should go and use
  one of them instead.  In the manual, under the contents.
- **Light or dark in the manual, whichever you are in.**  The switch the
  website has is in the program's manual now: a tap at the top of any page
  cycles Auto, Light and Dark, and it stays that way next time you open it.
  Auto is the program's own theme, as before.

### Fixed

- **The help menu opens above its button again.**  With the entity panel
  open, the menu from the HELP button was pushed back to the edge of the
  drawing, a panel's width away from the button it belongs to.  It stands
  over the panel now, where it was pointed.

## v2026.09.19

### New

- **A way back from the bottom of a page.**  Every manual page now ends with
  a link to the contents, and the pages themselves are laid out the way the
  website lays them out - the same spacing, and a proper heading band on the
  key and command sheets.
- **What is on this page, at the top of it.**  The longest manual pages -
  commands, the keyboard, sheets, units, faces, plan, select and revolve -
  open with a list of their own sections, and every heading is a place you
  can link to.

### Fixed

- **Clicking a picture in the manual shows the picture.**  Every animation
  in the manual is a link to itself, and since they became WebP, clicking
  one filled the window with the file read as text.  It opens large, and
  keeps playing, the way it always should have.
- **The manual stays in your colors.**  In a light theme the contents came
  up light and every page you clicked through to came up dark.  Now the
  whole manual follows the program's theme, wherever you got to it from.

## v2026.09.18.8

### Fixed

- **No more "not taken yet" boxes.**  Five pages were showing a dashed
  placeholder where a picture had been planned; those pages simply have no
  picture now, which is tidier than a note meant for whoever writes the
  manual.

## v2026.09.18.7

### New

- **The manual's pictures are sharp.**  Every animation has been recorded
  again at the size it is shown, in lossless WebP - the old ones were
  scaled down on the way out, which turned every one-pixel line into a
  two-pixel gray smear.  They are bigger pictures and a smaller manual:
  20.1 MB of GIF became 14.2 MB of WebP.
- **The manual reads better too.**  Sections have a rule above them so a
  long page has somewhere for the eye to stop, the page head is underlined
  in the accent color, and captions read as captions.

## v2026.09.18.6

### Fixed

- **The manual is drawn by a new engine.**  LazInk, which draws the help
  window inside the program, has replaced the renderer it grew up with -
  so this build carries a manual that lays out through a proper box tree
  and hangs its text on baselines.  It should read the same and draw
  faster, and there is one fewer license riding along with the download:
  LazInk is MIT throughout now, where the old renderer was MPL and owed
  its source to anybody who was given a copy of this.

## v2026.09.18.5

### New

- **A fifth example: a soccer ball.**  Twelve pentagons and twenty hexagons,
  cut off the corners of an icosahedron the way the real one is - and the
  panels stand off a dark inner ball so the seams read as seams.

## v2026.09.18.4

### New

- **A fourth example: the robot.**  Six foot two, standing, with the
  etch-a-sketch set in his chest at the height your hands are - ball
  joints at the shoulders and two-fingered hands.  The toy in his chest
  is the toy example itself, stood on end, not a copy of it.
- **The logo on the etch-a-sketch is raised**, a sixteenth proud of the
  body, the way it is moulded into the real one.

## v2026.09.18.3

### New

- **Pipe is black or stainless, and rounder.**  The spool builder has a
  Material box: black carbon steel or stainless.  Pipe is drawn with 36
  facets round it instead of 24, and a bend is walked in seven and a half
  degree steps instead of fifteen, so an elbow reads as an elbow.
- **Big drawings of pipe draw twice as fast.**  Filling a long thin face
  on the diagonal - which is every facet of a pipe - was costing what its
  bounding box costs rather than what the face costs.  A two-inch spool
  went from 70 milliseconds a frame to 34.

## v2026.09.18.2

### New

- **Duct looks like duct.**  Everything the fitting builder makes is
  galvanised sheet now instead of paper-white, and the fabric of a flex
  connector is black canvas rather than metal.
- **Rolled beads are round and cross breaks are bent.**  A bead was three
  flat facets with a crease down each join - a box, not a bead; it is a
  half round now with only its outer two edges drawn.  A cross break was
  two narrow creases laid on the panel; the panel itself is now bent on
  both diagonals, so it dishes and shows the X, which is what a cross
  break is.
- **TDF corners have their bolt hole** - square, because the bolt through
  it is a carriage bolt and the square shoulder under its head is what
  stops the bolt turning while the nut goes on.
- **TDF flanges can be drawn with the corners in.**  The duct fitting
  builder offers *TDF flange with the corners in* beside the plain one.
  A TDF's sides each stop short of the corner so the next can fold, which
  leaves a square gap at each of the four; pick the new one and those gaps
  are filled with the corner pieces that go in them in the shop, instead
  of being left open the way the flange comes off the machine.

## v2026.09.18.1

### Fixed

- **A third example drawing: a kitchen broom.**  A hundred and seventy
  bristles banded in four colors, a blue moulded head and a wooden
  handle - every face of it painted.  The other two examples are
  near-white, so this is the one that shows what materials are for.  It is
  written out beside the program with the others.
- **The view cube still works when you are square on to a face.**  Looked
  at straight on it is a flat square, and the ring of eight targets round
  its border is now drawn - the four sides are the views either way off
  this face, the corners are corner views.  They light up as you pass
  over them, so the cube can bring you back out as well as take you in.
- **The view cube, the tape measure and rotate have animations** - the
  cube flying between views, a tape pulled off an edge leaving a guide
  line, and a rectangle turned by a typed angle.  Rotate's two sections
  about which plane it turns in are now one, and the page about sending a
  report says what happens to it after you press send.
- **Solids and 3D printing** shows what `/holes` is for: an edge rubbed
  off a box, and every unmatched edge drawn in red round the opening.
  Units, sheets and the etch-a-sketch pages read better too.
- **The rubber band stops claiming an axis it is not holding.**  With the
  axis inferences switched off by Alt, a line that happened to drift onto
  red still turned red, which read as a snap coming and going.  It now
  takes an axis color only when it is really on one.

## v2026.09.18

### Fixed

- **A light/dark switch on the manual's website.**  Top right of every
  page: Auto follows your phone or desktop, Light and Dark override it,
  and the choice is remembered in that browser.  The manual opened inside
  the program has no button and still follows the program's own theme.
- **The offset page has two animations** - offset the top of a box and
  push the middle down for a tray, or the border up for a rim - and the
  old picture, which showed the floor grid the way it used to be drawn,
  is gone.
- **Four more again**: snapping (the cursor walking one edge while the
  diamond keeps changing its name), the working plane, the drill, and
  dimensions.
- **Four more pages of the manual have pictures**: the select tool (one
  click, two, three, then a dragged box), the eraser, faces front and back
  - which now shows an edge rubbed out and drawn back in, faces going and
  coming with it - and the protractor.
- **A page about Parts**, which is not built yet: keeping one piece of a
  drawing to itself so it does not join onto everything it touches.  The
  page says plainly that it is planned, and why it waits.
- **Clicking takes what you can see.**  Where an edge on top of something
  ran close on screen to an edge buried under it, the buried one could win
  and be picked or erased instead - the rim of a knob against the wall
  below it.  What is in front at the spot you are pointing at now wins.
- **Big drawings draw faster.**  Filling the faces was half of every
  frame; it now looks only at the edges that reach each row instead of
  all of them.  Measured on three drawings sent in with reports: about a
  sixth off the time a frame takes, and more the more detailed the shapes.
- **Set a color on everything picked at once.**  With several things
  picked the entity panel now paints every picked face, or recolors every
  picked line, arc, note and dimension, in one trip through the color
  picker - and the buttons say how many they will land on.
- **Paint a face and it is that color.**  Faces have a material of their
  own now, separate from the pen that drew their edges - so red is red
  instead of the gray-pink it used to come out.  Paint it from the entity
  panel; with several faces picked, all of them are painted at once, and
  **Back to default** returns one to the near-white it started as.

## v2026.09.17.10

### New

- **Alt does what it does in SketchUp, on three more tools.**  Pulling an
  arc's bulge, it runs the arc out of the edge it started on smoothly and
  holds it there.  With the offset tool it keeps the overlaps a tight
  corner makes, instead of squaring them off.  With rotate or the
  protractor it frees them from the face under the cursor, so they turn
  flat unless an arrow picks a plane.

## v2026.09.17.9

### New

- **Parallel and square to an edge, in magenta.**  While a line is under
  way the cursor offers directions along the edge it started on, or the
  piece just drawn, and square to it - SketchUp's magenta pair, which we
  did not have.
- **Alt steps through what the cursor may infer**, part way along a line:
  all of them, then the directions off, then parallel and square only.
  That is SketchUp's key and SketchUp's cycle.  Corners, midpoints and
  crossings keep snapping on every stop.  Before a line is started, Alt
  still holds the working plane.

## v2026.09.17.8

### New

- **The manual follows the program's theme.**  Open it while the program is
  in a light theme and the pages are light; in a dark one they stay dark.
  On the website the pages follow whatever your system asks for.
- **The manual has pictures where it was thin**: the revolve tool has a ball
  and a wine glass being spun, the move tool shows a side of a rectangle
  being stretched, and the plan view shows the cut traveling up through a
  model.  The revolve page is rewritten step by step, with a table of what
  to do when it will not spin.

### Changed

- **The tape leaves what SketchUp leaves.**  Measured along an edge - a
  point in from a corner, say - it drops a guide point and no line.  Pulled
  off an edge into the face, it drops a guide line parallel to that edge.
  From anywhere else it still lays the line across the run.

## v2026.09.17.7

### Changed

- **The grid in ISO and 3D is a floor.**  Squares lying in the red and
  green plane, turning with the camera, only in the quarter where both axes
  are drawn solid - a floor to judge a model against, not paper behind it.
  Darker than it was, and heavier every fifth line.  It starts off now;
  <kbd>G</kbd> or the GRID button turns it on.
- **The bottom bar says more while you work** - what the cursor is holding
  on to, then what to do, then the keys that would do something right now.
  The card beside the pointer carries the keys as well.
- **The select tool leaves guides alone** unless you are right on one, and a
  guide under the pointer says so by turning its own dashes blue rather
  than being outlined in a thick band.

### Fixed

- **Drawing with something selected is quicker.**  The picture, the
  selection over it and the wash on the face under the pointer are kept
  between frames instead of being rebuilt on every one.

## v2026.09.17.6

### Changed

- **Updating keeps your drawings exactly as they are.**  No save question
  on the way out: every sheet, the file it came from, and anything not saved
  yet all come straight back in the new version, still marked unsaved.  If
  an older copy is ever slow to close, the new one asks you to keep waiting
  instead of giving up.
- **Orbiting and zooming with the grid on are quicker** - the paper and the
  ground grid behind the drawing now cost a fraction of what they did.

### Fixed

- **Offsetting a rounded shape inward** no longer flips its rounded corners
  inside out.  Taken in further than the corners are round, the corners
  come out square, and the ring and the middle are two clean faces
  push/pull can find.
- **Lines no longer show through the walls of a pit.**  Pushing up a ring
  sometimes lined its opening inside out, so the pit's walls were not drawn
  and the edges behind them showed through.  New pushes are right; for one
  already in a drawing, pick the pit's walls and use Reverse.

## v2026.09.17.5

### New

- **Color and width in the entity panel.**  Pick a line or an arc and step
  its width with - and +, or press Change... beside Color to recolor
  whatever is picked.  The LINE COLOR and LINE WIDTH buttons still set what
  you draw next.
- **Ctrl and the arrow keys walk round the view cube** in the 3D view -
  left and right go round the sides, up and down tip over the top or under
  the bottom.
- **A cube drag let go near a view clicks onto it**, and with Ctrl held it
  clicks onto the nearest view from anywhere.
- **Short command names show up in the list.**  Typing `/tape` finds
  `/measure`, and the row says which name found it.

### Changed

- **`/rendertime` and `/timings` show their numbers in a box you can copy
  from**, instead of a line in the command bar that ran off the end.
  `/timings` on, do the slow thing, `/timings` again.
- **Examples you have changed are left alone.**  The example drawings
  beside the program used to be written over every time it started; one
  you have edited and saved now stays yours, and an untouched one still
  gets the newer version.

### Fixed

- **A raised letter or shape keeps its outline color.**  Push/pull gave the
  new edges the face's color, so raising a letter of the toy's logo
  outlined it in red.  The new edges now match the outline they came from,
  and a raised letter looks embossed.

## v2026.09.17.4

### Changed

- **Problem reports say much more about how the program was set up** - how
  it was started, the window and screen, the theme and grid, the view
  cube, each tool's settings, and every open sheet.  Nothing about you;
  type `/state` to see exactly what would go.

## v2026.09.17.3

### Fixed

- **Guides are no longer picked up with your drawing.**  A double or triple
  click, or a box dragged round a shape, takes the shape and leaves the
  guides alone.  A box round nothing but guides still takes them, and a
  click on a guide still picks it.
- **A guide gives a point to snap to wherever it crosses something**, all
  the way along it - not only near where the tape laid it.  That includes
  where it crosses an arc or a rounded corner.
- **Smoother zooming, panning and orbiting on Windows.**  The drawing is
  redrawn once per frame however many wheel steps or mouse moves arrive,
  and the blue wash over the face under the pointer no longer slows every
  frame when you are zoomed in close.

## v2026.09.17.2

### New

- **Click a picture in the manual to see it larger.**  Every screenshot and
  animation opens in a window of its own, as big as the window you make
  it - drag the window bigger and the picture grows.  Esc closes it.  On
  the website, a click opens the picture full size in a new tab.
- **The animations are recorded at full size** now, so they are sharp when
  you open them larger.

### Changed

- **The manual's contents page looks like cards**, three to a row, the same
  in the program as on the website.

## v2026.09.17.1

### Changed

- **The manual's contents page is laid out in rows of three**, grouped by
  what you are doing - drawing, shaping, picking and moving, measuring,
  looking around, your drawing, and the shop - with a "Start here" row at
  the top.  It reads as a grid in the program's help window as well as on
  the website.

## v2026.09.17

### New

- **The manual opens inside Heckers Sketch.**  Help > The manual, or
  `/manual`, now shows the help pages in their own window - with Back and
  Forward, a Contents button, Find (Ctrl+F), and text you can select and
  copy.  Drag the page with a finger to scroll it.  Links to other websites
  still open in your browser, and "Open on the web" shows the same page
  online.
- **The manual is kept beside the program.**  The first time it's needed,
  Heckers Sketch downloads the help pages for its own version from GitHub
  and keeps them in a `help` folder next to itself - so a copy on a USB
  stick still has its manual somewhere with no internet.  After an update,
  the matching pages are fetched on their own in the background.  `/update
  never` turns that off along with the update check, and `--offline` stops
  it entirely.

### Changed

- **The release notes window reads the notes file directly** now, so what
  you see is exactly what was written.  It still shows only what's new
  since the version you had.

## v2026.09.16.9

### Fixed

- **Updates no longer fail with a bare "403".**  GitHub only answers so many
  update checks an hour from one home or office network, and when that runs
  out the check was simply refused.  It now falls back to GitHub's release
  page, which doesn't have that limit, and if that fails too it says so in
  plain words instead of a number.  (Our own testing was what used it up on
  16 September - that is fixed as well.)

### New

- **`--offline`** starts the program with the network switched off entirely:
  no update check and no reports.  `--help` lists it.

## v2026.09.16.8

### New

- **`--blank`** starts the program on an empty sheet - no example, no
  draft.  Whatever draft was there is kept beside it as
  `heckers-sketch-draft-before-blank.hsk`, so nothing is lost.

### Fixed

- **The buttons along the bottom fit a smaller window.**  On a narrower
  screen their words ran out of the buttons and over each other.  The
  buttons on the right now shrink first, then turn into icons, and a label
  that still doesn't fit is shortened instead of spilling.
- **The tool list on the left fits a shorter window.**  MORE TOOLS and SHOP
  no longer end up drawn on top of each other.
- **The blue highlight on a face no longer has a hole under the pointer.**
- **The release notes window has a scroll bar in the theme's colors.**

## v2026.09.16.7

### Changed

- **This window is drawn by LazInk now**, our own text package, rather than
  by code of its own.  It looks much the same.  You can still drag the page
  with a finger to scroll it, and the arrow keys, Page Up and Page Down and
  the mouse wheel all work.  The scroll bar is a plain one for now.

## v2026.09.16.6

### New

- **Round the corners of a shape with the arc tool, like SketchUp.**  Click a
  point on each edge near a corner and pull the middle in towards the
  corner.  When the arc curves smoothly into both edges it turns magenta and
  says TANGENT TO EDGE.  Click to put it in and keep the square corner, or
  double-click to trim the corner away.  Type a radius while it's magenta to
  set the size.  After that, double-click near any other corner for the same
  again.
- **Type a line's length.**  Pick a line, type a new length, press Enter.
  A loose line moves the end it was drawn to, a line joined at one end moves
  its free end, and a line joined at both ends can't be changed that way -
  the same rule as SketchUp's Entity Info.

## v2026.09.16.5

### New

- **Hold Ctrl while orbiting and let go, and the view clicks into the
  nearest standard direction** - one of the twenty-six the view cube offers:
  six faces square on, twelve edges, eight corners.  It glides there the way
  clicking the cube does, so you keep track of what you are looking at.
  While Ctrl is held the status line names where you will land, and the cube
  lights the face it is about to go to.  Let go of Ctrl first and nothing
  happens.
- **`--no-splash`** starts the program without the start-up screen, for
  anything driving it from a script.  `--help` lists it with the rest.

### Fixed

- **Hiding the guides now hides them from the cursor too.**  Put away, they
  were still snapped to, still ran under the cursor, and could still be
  picked and rubbed out - all of it invisible, so the cursor jumped to
  places with nothing on the screen to explain why.
- **What you click is the nearest thing, not the last thing you drew.**
  With two things in reach the pick used to go to whichever was drawn more
  recently, even when the other was dead under the cursor.
- **A crossing selection box takes what it actually crosses.**  Dragged
  right to left in a clear patch of paper it used to take any line, arc or
  face whose *corner-to-corner extent* happened to cover the area - a long
  diagonal running past would come along with the selection.
- **Guide lines can be caught by a selection box** from either direction.
- **An edge just inside the snapping distance is found.**  The reach was
  quietly a pixel shorter than the one being asked for.
- **Picking is much faster on a big drawing** - about thirty times - so
  hovering over a crowded sheet no longer lags behind the mouse.
- **Orbiting is smoother, and the ground reads as a floor.**  The lattice on
  the ground was being ruled far finer than it could be seen - about two
  hundred and sixty lines a few pixels apart, which came out as a gray
  crosshatch and cost most of every frame to draw.  It is now spaced so you
  can read it, and tipping the view down near the ground gives you a coarse
  floor instead of none at all.

## v2026.09.16.4

### Fixed

- **Exporting an animation and then clicking back in the drawing no longer
  throws an exception.**  An export makes a picture the size it is saving,
  which is not the size of the window, and the drawing kept using that one to
  work out what was in front of what long after the export had put it away.
  The first click afterwards landed on nothing.  Exports of every kind -
  animations, pictures, print previews, contact sheets - now hand the drawing
  back to the window as they finish.

## v2026.09.16.3

### Fixed

- **Picking a lot of things no longer brings the program to a halt.**  With
  everything in a drawing selected, every frame was spending nearly two
  seconds drawing the blue outlines - one call to the system's canvas per
  visible piece of every edge, and about a millisecond each.  The same
  outlines are drawn into a picture of our own instead and kept until
  something changes them: twenty milliseconds the first time, nothing after
  that.  Nothing about how it looks has changed.

## v2026.09.16.2

### New

- **The entity panel.**  `/info` puts it down the right-hand side: what is
  picked, and the few things you can change about it.  A line's length and
  both ends; a circle's radius, center and **how many sides** - with a minus
  and a plus beside the figure, so a circle drawn at 24 can be turned into 48
  after the fact, which was never possible before.  A face's area and corner
  count with a Reverse button.  A note's size.  With nothing picked it says
  what the sheet adds up to.

## v2026.09.16.1

### New

- **Copy and paste, including from one sheet to another.**
  Ctrl+C, Ctrl+X, Ctrl+V.  A paste arrives on the cursor and a click
  puts it down, the way a built fitting does.  A pasted solid is its own
  solid, so pushing a face on one does not deform the other.

### Fixed

- **Closing a sheet with work on it asks about it.**  It asked about the
  window rather than the sheet - and making a new sheet marked every other
  sheet saved, so drawing something, opening a second sheet and closing the
  first went without a word.  Closing the whole window now asks too, which it
  never did.

- **The face under the cursor is worked out once.**  Push/pull, the drill and
  the offset asked for it, then the snapping asked for it again, and on some
  tools the click asked a third time - each one a ray cast at every face in
  the drawing, on every mouse move.

- **The stipple under push/pull is drawn a row at a time.**  It used to ask
  "is this dot inside the face" for every other pixel of the face's box -
  four million divides a mouse move on the toy's case.  Same picture, about
  five hundred times less work.

- **A copy of a face with a window in it gets its own window.**  Ctrl-copy
  with the move tool shared the opening with the original and left it at the
  original's position, so moving either moved both.

## v2026.09.16

### New

- **The push/pull page has a moving picture.**  Nine seconds: pick the tool,
  click the circle, pull it up.  Recorded by driving the program rather than
  by anybody filming it, so the next one is a script away.

## v2026.09.15.8

### New

- **Ten more pages in the manual, and a way in from the command list.**
  Snapping, the working plane, units against scale against precision, faces
  front and back, sheets and files, the view cube, the fitting wizard, the
  pipe spool, laying a piece out flat, and the toy.  In the command list, a
  command with a page of its own is now a link to it.

- **A bug report says how the frames have been going.**  Every frame is
  timed - the paper, the ink, the composite and the screen - and one that
  takes longer than a fortieth of a second writes a line into the log a
  report carries, saying which part of it was slow and what you were doing.
  The report also carries how many went over and what the worst one was.
  "It felt glitchy" now arrives with the numbers.

### Fixed

- **A picked guide is drawn where the guide is.**  A guide is kept as a point
  and one foot of direction, and drawn to the edges of the paper - and
  picking one highlighted the foot, so two blue lines appeared to stick out
  of a drawing with nothing at either end of them.

## v2026.09.15.7

### New

- **A guide point is easy to pick.**  It marks a distance along a line, so it
  sits on that line - and the line used to win the click from a pixel away.
  It is asked for before anything else now, with a reach the size it is
  drawn, so one attempt gets it.  Select it and press Delete, or right-click
  and Erase.  A guide that has been put away cannot be picked or erased at
  all, which it could before.

- **Ctrl says what the tape leaves behind.**  Both the dashed guide and the
  amber point, the point on its own, the guide on its own, or nothing.  Both
  is still what you get unless you say otherwise, and the bar says which mode
  you are in each time you press it.  A 1" mark in from the end of a line
  rarely wants a dashed line across the whole drawing with it.

### Fixed

- **The tape measure finishes when it has measured.**  It used to sit waiting
  afterwards, drawing the run it had just taken until something else took the
  tool away - and a press of Enter, or of Space which everywhere else means
  "done", would land on that waiting tool and turn the run into a dimension
  minutes later.  Both were the same thing.  To keep a run, `/keep` writes
  the last one on the drawing as a dimension.

- **Undo puts a face's openings back.**  Move something with windows in it -
  the block letters of the title, say - and undo put the outlines back and
  left the windows where they had been dragged to.  The undo snapshot was
  sharing those loops with the drawing, so a move wrote through it into the
  past.

- **A guide line takes its point with it.**  The tape lays both in one
  gesture; rubbing out the dashed line left the amber point behind, marking a
  spot nothing could explain.

### Changed

- **Hide Guides and Clear Guides are on the right button now.**  They were
  two more buttons along the bottom that appeared the moment a drawing had a
  guide in it, and making room for them squeezed the settings until their
  words ran into each other.  Right-click anywhere on the drawing.

## v2026.09.15.6

### Changed

- **The eraser takes edges, not faces.**  That is SketchUp's rule - a face
  goes when the edges holding it up go - and ours used to take a bare face as
  well.  Click one now and nothing goes; the bar along the bottom says so and
  names the two ways that do work: right-click it, or pick it and press
  Delete.  Both leave every edge standing.

### Fixed

- **A line drawn along an edge already there now divides the face.**  Close a
  strip off along the bottom of a wall and the strip is its own area, which
  you can push out as a floor.  It used to come out as one loop with the
  divider traced up one side and down the other - no area cut off, and
  nothing to push.  Two identical edges written the opposite way round were
  not being welded into one.

- **A face needs the edges that enclose it.**  Rub out an edge of a box and
  the sides that were standing on it go with it, the way SketchUp has always
  done it - "faces are erased when you erase their bounding edges".  Loose
  faces already worked this way; a built solid's did not, so a box could end
  up with six sides and one of them held up by nothing.

- **And you can put one back.**  Draw the line again, along where it was, and
  the faces come back with it - SketchUp's healing.  A side traced back into
  a box rejoins the box, so the shape is closed again and `/holes` agrees.

- **A guide makes a point where it crosses an edge.**  That is what a guide
  is for: set one an inch in from the end and the place you are aiming at is
  where it meets the edge.  Nothing was offering it - the pass that works out
  crossings only ever looked at drawn lines.  Two guides crossing each other
  count too.

- **A rectangle says when you have given it one side.**  Type a length with
  no second side and it read it, ignored it, and took the corner from the
  cursor without a word.  It now says so, and what to type instead.

### New

- **Truss notation is in the manual.**  `6-8-15` is six foot eight and
  fifteen sixteenths, and it has always worked in every field that takes a
  length - it was just never written down anywhere.

## v2026.09.15.5

### New

- **A manual worth opening.**  Two new pages: every one of the sixty-nine
  slash commands, grouped by what you are trying to do and with the short
  names each answers to; and every key and every drag on one sheet, in both
  the drawing program and the toy.  `/manual` opens them.  The first real
  screenshots are in too - and they are taken by driving the program itself,
  so the rest can follow without anybody posing for them.

- **Edges break where they cross.**  Draw a line, a rectangle, an arc or a
  circle over something already there and both are cut at the crossing, so
  every piece is its own edge.  That is what makes a rounded corner: drop a
  circle on the corner of a rectangle so it just touches both sides, then rub
  out three quarters of the circle and the short piece of each side, and the
  corner is rounded.  Before this the side was still one line from corner to
  corner and there was nothing to rub out but the whole of it.  Solids,
  guides and dimensions take no part - only loose drawing is cut.

- **A move shows what is coming with it.**  Move one side of a rectangle and
  the two sides it joins stretch to follow - which has always happened, and
  which the ghost never showed, so it looked like the side was tearing away
  on its own.  Those edges are now drawn leaning over to where they are
  going while the mouse is still down.

- **`/detach on` moves a line away on its own.**  The other way round:
  nothing stretches to follow and everything else stays where it is.  The
  ghost turns amber to say so.  `/detach off` puts it back.

### Fixed

- **Push/pull stipples only the part of the face that is there.**  A
  rectangle drawn inside another leaves a ring, and pointing at the ring lit
  up the whole rectangle, window and all.  It now stops at the window, and at
  anything standing in front of the face.

- **The tape measure takes the middle of an edge it is on.**  Hovering the
  middle of a side of a face offers the midpoint, the way it does on a drawn
  line.

- **The help pages say how to change the number of sides.**  With the circle
  or arc tool live, + and - step it, or type 24s.  It was in the program and
  nowhere in the manual.

- **`/new` makes a new sheet.**  It opened the release notes instead: the
  branch that answers `/whatsnew` also answered `/new`, and it came first.

- **US spellings throughout.**  Color, center, millimeters.

## v2026.09.15.4

### Fixed

- **A dimension has to measure something.**  You could lay one across blank
  paper and drag it around - a number measuring nothing, which the drawing
  can never drive and which will never update when the drawing changes.  It
  now wants a corner, a midpoint, a center, or a point on an edge, and the
  cursor says so before you click rather than after.

## v2026.09.15.3

### Fixed

- **The dimension tool takes the edges of the toy's case.**  Hovering one
  said ON EDGE and lit nothing, and the click fell through to a
  point-to-point: the hover and the click looked at lines, arcs, dimensions
  and guides, never at the outline of a face, and then asked the edge for its
  two ends - which a face has not got.  They use the same search the snap
  does now, so the one edge under the cursor lights up and a click takes all
  of it.

## v2026.09.15.2

### Fixed

- **A part for printing now arrives standing on the bed.**  "Center it on
  the origin" centerd all three directions, which buries the bottom half of
  the thing in the build plate; slicers quietly lift it back out, so nothing
  ever looked wrong, but it is the sort of thing you open another program to
  put right before printing.  It is centerd across the bed and standing on it
  now - the STL, the OpenSCAD, and `/center` itself.  `/tozero` is unchanged:
  the near bottom corner on the origin rather than the middle.

## v2026.09.15.1

### New

- **The view winds in and out a great deal further.**  It was a twentieth to
  forty times - which sounds generous until you try to work on a sixteenth of
  an inch.  It is a million to one now, so a site plan and a weld bead are
  both reachable, and the scale bar goes down to a sixteenth of an inch and
  up to a thousand feet to keep up.

- **The axes go on for ever**, the way they should.  They were drawn a
  screenful out from the origin, so panning away from it left them stopping
  in mid air.  In a program where the red line IS the X axis, an axis with an
  end is a lie about the model.

### Fixed

- **The tape and the dimension tool now take the edges of a face.**  They
  only ever looked at lines, so on the etch-a-sketch you could measure the
  robot and the lettering - which are drawn with lines - and could not
  measure the case they sit on, which is one face of thirty-two corners with
  no lines in it at all.  Its corners are somewhere to land now too.
  Anything that arrives as faces rather than drawn lines was in the same
  position: a revolve, an imported model, a generated example.

## v2026.09.15

### New

### Fixed

- **The tape and the dimension tool stop grabbing edges behind the model.**
  They took whichever line came nearest on screen and asked nothing else, so
  measuring along the front of a box jumped to the back edge wherever that
  happened to project a pixel closer.  On a solid box, better than a quarter
  of the places you could put the cursor gave you an edge you could not see.

- **And when two lines land on the same pixel, the nearer one wins.**  The
  etch-a-sketch is made of this: the lip of the case and the screen recess
  run parallel an eighth of an inch apart, so measuring along the top of the
  toy flipped between them depending on which had been drawn first.

### New

- **What's new scrolls under your finger.**  Drag the page and it follows -
  on a touch screen, or with the mouse button held down.  It could only be
  scrolled with the wheel or the keyboard before, which is no help on a
  laptop you are poking at.

## v2026.09.14.18

### New

- **Pick something, click the cube, and it comes to the middle sized to
  fit** - turning, sliding and zooming in one movement rather than a turn
  followed by a jump.  With nothing picked it goes to the view you asked for
  and leaves your framing alone.  `/cube fitselection off` if you would
  rather it never re-framed.

- **The cube goes in whichever corner suits**: `/cube tl`, `tr`, `bl` or
  `br`, and `/cube on` or `off` to say so outright.  It remembers.

- **FIT travels too.**  The FIT button and `/fit` ease the drawing into
  frame instead of snapping it there - as does the VIEW button and every
  named view.  Loading a drawing or changing sheet still arrives instantly,
  because there is no sense of place to keep hold of when the thing you were
  looking at has been replaced.

### Fixed

- **"Send the drawing too" stayed unticked.**  Taking another picture, or
  discarding it, rebuilt the report dialog - and the tick came back on, so a
  report sent after that carried the drawing anyway.  What you typed always
  survived that rebuild; now your answer to this does too.  It is your work
  and the box exists so you get to say.

## v2026.09.14.17

### New

- **A view cube.**  `/cube` puts one in the top right of a 3D view.  Click a
  face to look square on, an edge for a half turn between two, a corner for
  the three-quarter view most drawings are read from; drag it to turn the
  model the way dragging the model does.  It also answers the question the
  VIEW button never could - which way am I facing - without being touched.

  Off until you ask for it, and remembered after that.

- **A turn turns about what you are looking at**, not about the origin.  The
  middle of what is selected, or the middle of the drawing when nothing is -
  which is the rule Revit uses, and the reason a building drawn half a mile
  from zero no longer swings out of the window when you change the view.

- **The view rolls instead of jumping.**  Every change of view used to snap:
  the model was one way round and then it was another, and you worked out
  which way it had gone.  Now it rolls there, the short way round, in about a
  third of a second - and that goes for the VIEW button and `/front` and the
  rest as much as for the cube.

## v2026.09.14.16

### New

- **A film comes back to where it started.**  A move that ends somewhere
  else - a rise, a push in, or one you pointed by hand - used to jump every
  time the GIF came round.  It can now walk back to the start instead, inside
  the same running time, so it joins up.  The tick only appears when the move
  needs it: a turntable already ends where it began and is left alone.

- **How long the film runs is yours to choose.**  A clip pointed by hand over
  eleven seconds plays perfectly well in five, and the length is the speed.

### Fixed

- **The axes no longer draw through the model in a picture or a film.**  They
  went on top of the finished picture, so a red line ran across the middle of
  a solid in every frame of a GIF - which happens nowhere on screen, because
  the drawing area rules them onto the paper and puts the model over them.
  Now they go underneath there too.

- **A film that ends where it began no longer stutters once a loop.**  It was
  rendering the first pose twice - last frame and first frame, the same
  picture - so a turntable froze for a frame every time round.

- **The recording room can be moved.**  It draws its own frame and nothing
  had ever been wired to drag it, so it sat in the middle of the screen over
  the thing you were about to film.  Nothing about a recording minds: what is
  written down is where the camera is pointing, not what is on the screen.

- **An exported SVG now says how big it is.**  It used to carry a bare
  number - screen pixels at whatever zoom the view happened to be at - so a
  part three and a half inches across arrived in Inkscape, or a print shop,
  or a cutting machine, at some other size entirely, and at a different size
  again if you had zoomed in first.  The file now says `3.430in` (or
  millimeters, in a metric drawing) and opens at the size of the thing.
  Export from a plan and what comes out is the real thing, full size.

- **Dragging a dialog no longer skips about.**  The windows that draw their
  own title bar - Export, What's new - were moved by measuring the pointer
  against the window being moved, which on Linux feeds back on itself and
  makes the window fight the hand.  They now measure against the screen, and
  move once per twitch instead of twice.

- **The program stops working while a dialog is up.**  It kept a sixty-a-
  second heartbeat running underneath every dialog, including the system
  print and color ones, servicing a pointer that was somewhere else.  On a
  machine with a compositor that is enough to make the dialog you are
  dragging stutter.  Measured with a drawing of twenty-four wine glasses: the
  window behind the export dialog went from 2.2% of a core to 0.2%.

## v2026.09.14.15

### Fixed

- **The wheel scrolls the command list.**  It used to zoom the drawing
  behind it instead, which was true of every list in the program - the
  command list is just the first one long enough to make it obvious.  A list
  in front of the drawing now gets the wheel before the drawing does.

## v2026.09.14.14

### Fixed

- **The command list called Revolve "/followme".**  The tool was renamed on
  the eighth and the command list never heard: it offered `/followme` as the
  name and no `/revolve` at all.  It is `/revolve` now, and `/followme`,
  `/follow` and `/lathe` still work for anybody coming from SketchUp.

- **MORE TOOLS said what was not behind it.**  It promised "rotate, offset,
  follow me and drill" and held three tools, Revolve having moved out to the
  strip beside Push/Pull a week ago.

## v2026.09.14.13

### New

- **The command list shows you how to use a command, not just what it is.**
  Highlight a row - with the arrow keys or the pointer - and if that command
  takes something after it, the line beside it turns into a real example.
  `/scale` reads `/scale 1/4"`, `/cut` reads `/cut 0 9'`, `/plane` reads
  `/plane xz`.  The rest go on saying what they do.

### Changed

- **The command list is half the height of the window** instead of all of
  it.  Sixty rows from the prompt to the title bar was a wall in front of
  the drawing you were about to do something to; the rest is a scroll away.

- **The reading along the top goes to the corner now.**  X, Y, Z, the plane,
  the length and the area used to stop two hundred pixels short to clear the
  TOY/PRO switch.  The switch is gone, so the room is the reading's.

## v2026.09.14.12

### New

- **The manual is on the web.**  Help > The manual opens the copy that came with
  the program if there is one and the website if not, and the website is now
  a real set of pages you can read in a browser rather than a folder of files
  on GitHub.

- **The toy is a command.**  `/toy` takes you to the etch-a-sketch this
  program started as, and the one button in the corner there brings you back.

- **A help page about the commands**, since there was one about typing
  measurements and nothing about typing a slash.

### Changed

- **The TOY and PRO buttons are gone from the top right.**  They took up the
  corner of a drawing program to offer you a choice you had already made.
  Nothing is hidden - `/toy` is in the command list with everything else.

### Fixed

- **Seventeen pages of the manual were missing from the website.**  Every
  page about a tool - Line, Push/Pull, Offset, all of them - was in the copy
  that ships beside the program but had never been published.  They are
  there now.

- **The eraser's help page was a version behind.**  It now mentions dragging
  to gather several, and Ctrl to soften an edge rather than rub it out.

## v2026.09.14.11

### New

- **You do not have to remember the commands any more.**  Type `/` and the
  whole list comes up with a word about what each one does.  Keep typing and
  it narrows, the way an editor's autocomplete does - `/re` leaves you
  /rebuild, /rect, /redo, /reface and the rest.  Up and down walk it, Enter
  takes what is highlighted, Tab completes without running it, Escape puts it
  away, and clicking a row does the same as Enter on it.

  The ones you have used lately sit at the top and the rest are alphabetical,
  so it works whether or not you know what the thing is called.  It remembers
  them between sessions.

  There is a `/` button at the left of the command bar for anybody who has
  not found the keyboard yet.

## v2026.09.14.10

### New

- **/tozero puts a selection in the corner at 0,0,0.**  /center puts the
  middle of a thing on the origin, which is what a slicer wants.  This puts
  its near bottom corner there instead, so it stands on the floor with its
  two near edges against zero - which is what you want when you are
  measuring, because every number read off it is then a distance from
  nothing rather than from half of itself.  It tells you how big the thing
  is from there.  Also **Into the Corner at 0,0,0** on the right button,
  beside Center on the Origin.

## v2026.09.14.9

### New

- **A wine glass, beside the toy.**  The examples folder has two drawings in
  it now, both written out beside the program every run.  The glass is eight
  and a half inches tall with a hollow bowl and a solid stem, and it is a
  closed solid - a slicer will take it.

  It is built the way you would build it: the outline of half a glass, spun
  about the blue axis with Revolve.  So it is also the picture for that tool.

## v2026.09.14.8

### New

- **An export that is not a closed solid marks itself.**  Send out an STL or
  an OpenSCAD script and the edges where it is open are already drawn in red
  on the drawing when the dialog closes.  Being told a slicer will have to
  guess is the half you knew; where is the half that helps.  OpenSCAD did not
  check at all before - it does now, because it goes to the same printer.

- **/print all sends every sheet**, a page each.  /print still does the one on
  screen.

- **Another color...** at the bottom of the line-color list, for a pen that
  is not one of the twelve.

### Fixed

- **Light mode is easier to read.**  The accent blue was too pale against
  light chrome - it makes 3.7 to one where the dark theme's makes 8.4, and it
  is text as often as it is a fill.  It is a shade deeper now, and whatever
  goes on top of it when it is a fill is chosen to be readable rather than
  assumed to be dark, which is what put pale gray on mid blue.

## v2026.09.14.7

### New

- **The eraser softens as well as deletes.**  Hold Ctrl and it hides the edge
  instead of rubbing it out; Ctrl+Shift brings it back.  The creases down the
  side of a pulled circle are not edges anybody drew, and hiding them is what
  makes a cylinder look like a pipe rather than a barrel of staves.

- **A line drawn along one already there splits both** where they share, so
  the overlap is one edge and the two tails are their own.  Before, an edge
  landing exactly on one was skipped and one landing halfway along it was
  laid on top - two lines covering the same run, which you cannot see and the
  program has to think about twice.

- **A note follows the edge it points at.**  Move the edge and the leader goes
  with it, rather than staying aimed at where the edge used to be.

- **The free camera has a floor.**  A faint grid on the ground, ruled at the
  same pitch as the paper and the scale bar, so a model stands on something
  and you can read how far across it a thing sits.  The GRID button turns it
  off with the rest.

## v2026.09.14.6

### New

- **/holes shows you where a solid is not closed.**  Type it and every edge
  that nothing meets is drawn over the model in red.  It checks what you have
  selected, or every solid in the drawing if nothing is.  That is the answer
  a slicer will not give you when it refuses your model - the export could
  already say a shape was open, but not where.  The marks go the moment you
  change the drawing.

- **The manual travels with the program.**  Help > The manual, or /manual,
  opens the copy in the `help` folder beside the executable; the release zip
  carries it now.  With no copy there it opens the website, as before.

## v2026.09.14.5

### Fixed

- **/reface no longer throws away a solid's faces.**  It rebuilds faces from
  the lines, and a face pulled out of another face has no lines under it to
  be rebuilt from - so running it on a drawing of duct fittings took all 606
  faces off and brought none back, and on the example toy it stripped the
  body bare.  What cannot be remade is now left alone, and it says how many.

- **An export cannot be closed while it is writing.**  The bar that was added
  last release works by letting the window paint between frames, which also
  let Cancel and the close cross be pressed - and closing the window out from
  under the code writing the file is a crash, not a cancel.

- **The example opens with its faces already settled.**  Opening a file tells
  the program which areas are filled, including the ones somebody emptied on
  purpose; the example was skipping that step, so it did not quite look like
  itself until you asked for a rebuild by hand.

## v2026.09.14.4

### New

- **The What's new screen is dressed like the rest of the program.**  It was
  a stock white box with one weight of one color and the bold markers of the
  file showing as asterisks.  Now the version, the headings and the lead-in
  of each note are told apart, and it scrolls with the wheel.

- **An export says how far along it is.**  A twelve second film is three
  hundred drawings of the model, and the window used to stop answering for
  the whole of it.  There is a bar now, frame by frame, and an hourglass.

### Fixed

- **The splash screen fits its own window.**  On a Windows machine at a
  scaled display it was drawing the panel and the writing at one size inside
  a window at another, leaving them stranded in the corner.

## v2026.09.14.3

### New

- **The last tab can be closed.**  Its cross was hidden when only one sheet
  was left, which left you with a drawing you could not put down and nothing
  saying why.  Closing it closes the drawing and puts the example back up -
  which is what the program starts with anyway.

- **A new tab starts with the example on it.**  Rubbing a drawing out is one
  gesture; drawing one from nothing is not.  Ctrl+N still gives a blank sheet,
  and now really does - it had been mentioned in the hints for a while without
  being wired to anything.

- **Closing the last sheet puts the drawing down for good.**  It used to come
  back on the next launch, because the draft is written continuously and
  nothing ever told it the drawing had been closed on purpose.

### Fixed

- **Closing an untouched sheet asks nothing.**  The example arrives with 310
  things on it, so putting it down brought up "save the drawing first?" - a
  question about somebody else's work.  It asks only when something has
  actually changed.

## v2026.09.14.2

### New

- **A portable program keeps its files with it.**  Drawings are offered a
  `drawings` folder beside the program and exports an `exports` folder, both
  made the first time they are needed.  Nothing is put in your home folder
  any more - carry the program on a stick and the work goes with it.

- **It remembers where you put things.**  The last folder you saved a drawing
  to, the last one you opened from, and the last one you sent each kind of
  export to - so STLs go where the printer looks and pictures go where the
  forum post is being written, without being asked twice.  Open starts in the
  program's own folder until you have opened something.

### Fixed

- **The GIF settings are the ones that matter now.**  The seconds box, the
  frame rate box and the spin they described are gone: record a move and that
  is the film.  Play plays back what you recorded rather than a turn of its
  own, and the line saying there was no clip yet is no longer printed across
  the button underneath it.

- **A three second count-in takes three seconds.**  The recorder was counting
  timer ticks instead of looking at the clock, and every tick redraws the
  model - so on a drawing of any size the count-in stretched to eight.  Worse,
  it then wrote down three seconds of timestamps over eight seconds of
  movement, which is what made the film jumpy.

- **The recorder no longer makes the whole program sticky.**  It was building
  and throwing away a picture the size of the preview thirty times a second.
  It keeps one and draws into it, and redraws only as often as the eye needs
  rather than as often as the camera is written down.  The export preview did
  the same thing and now does not.

- **Notes that are whole sentences wrap instead of running off both ends.**
  The STL note was losing its first letter and its last.

## v2026.09.14.1

### Fixed

- **Pushing a letter, or a piece of the robot, raises it with walls.**  It
  used to slide the whole toy instead.  A shape drawn inside another shape -
  a letter in a panel, a plaque on a wall, a window pane - only ever touches
  what it sits in along the opening cut to hold it, and push/pull was only
  looking at outlines, so it read the letter as the whole flat side of the
  toy and moved the toy.

- **Push a whole side of a solid and whatever is cut out of it comes too.**
  The top of the toy has fourteen letter-shaped openings in it; sliding the
  top left all fourteen behind at the old height and tore the solid open
  along every letter.  Of the 133 faces on the example, 56 used to leave it
  open when pushed.  None do now.

- **An opening pushed up is lined the right way out.**  A ring pushed into a
  foundation wall had the inside of the hole wound inside out, which is a
  solid no slicer can read.

- **The robot's eyes are drawn inside its head.**  They were cut out of the
  screen instead, so the head lay straight over the top of them - two faces
  fighting over the same pixels, and a solid that came apart as soon as
  either was pushed.

- **The Report a problem box no longer cuts off the paragraph at the top.**
  It had room for four lines of text at the font it was written at, and not
  at a larger one.

## v2026.09.14

### Fixed

- **The letters of the logo, and the robot, can be pushed now.**  They were
  lines with no faces under them, and a drawing read from a file never has its
  faces worked out - everything in a saved file is taken as settled, so a
  region with no face is one whose face was rubbed out on purpose.  Quite
  right for a file the program saved, and it meant the example, which was
  written by hand, could never grow them.  The faces are in the file now.

- **The example opens framed, near the origin.**  It was written with no pan
  at all, which put the origin in the corner of the view and the toy away off
  to one side.

## v2026.09.13.27

### Fixed

- **Each letter of the logo is one shape now.**  It was built out of separate
  bars, which left a line across every join and meant pushing an H up took
  three goes and came out with seams down it.  Click a letter once and push it
  once, and the whole letter stands up.

- **The toy sits in the positive corner.**  Its near bottom left is on the
  origin, so the whole thing is inside the solid halves of the axes instead of
  straddling the dashed ones - nine inches along is nine inches, not minus
  four and a half.

## v2026.09.13.26

### New

- **The toy says HECKERS SKETCH on it**, in block capitals drawn the way the
  toy itself would draw them.  Each letter is one closed shape, so clicking it
  once and pushing lifts the whole letter - no seams, no doing it three times
  for an H.

- **The toy sits in the positive corner** now, with its near bottom left on the
  origin, so the whole thing is inside the solid halves of the axes rather
  than straddling the dashed ones.

- **A new program icon**, which is the toy.

- **An `examples` folder beside the program.**  The toy is written out there
  every time it starts, over the top of whatever was there.  That is on
  purpose: an example is a thing to take apart, and having taken it apart you
  should find it whole again next time rather than meet your own
  half-dismantled version.  Keep your own by saving it under a name of your
  own.

### Fixed

- **The toy's corners are rounded** - on the body and around the screen - the
  way a thing you would hand a child is.

## v2026.09.13.25

### New

- **It opens with something on it now.**  A run with nothing to show - no
  drawing named, no draft to pick up - used to be an empty sheet, which tells
  you nothing about what this is for.  It opens a toy etch-a-sketch instead:
  a solid to orbit, a screen to look at, and a robot drawn on it in lines
  that is asking to be pushed.  **Ctrl+N** for an empty sheet, and once you
  have drawn anything you will never see it again.

  It is carried inside the program, so a portable build is still one file.

### Fixed

- **A shape with a hole in it can be closed.**  A picture frame, or the
  surround of a recessed screen, is a face with a hole cut out of it - and
  the hole's edge is as much the boundary of the solid as the outside is.
  It was only counting the outside, so anything shaped that way read as not
  closed however well it was built, and the STL said a slicer would have to
  guess.

## v2026.09.13.24

### Fixed

- **The button on a failed export said "Tell us about it".**  It sends a
  bug report, so now it says so.

### New

- **Help pages.**  `docs/help/index.html` - one page for every tool and one
  for each of the things you do with a drawing.  They have no pictures in
  them yet; the words are there.

## v2026.09.13.23

### New

- **The GIF recorder is one room now.**  Setting a start and an end used to be
  in the export dialog while the recording was in a window of its own - two
  ways to do one thing, and no sign in the dialog which of them you had used.
  It is all in the one window, and the export dialog either has a clip or it
  does not.

  In it: where to **start from** - front, back, left, right, top, or any of the
  four corners - **what move** to make, and **how long** it should last.  Then
  Record.

  **A filmstrip along the bottom fills up as it records**, so you can see there
  is something there rather than take it on trust.  Play it, Clear it and go
  again, or Use this clip - which drops you back to the export dialog with it
  in hand.  There is deliberately nothing else you can do to the strip: for a
  clip this short, keeping it or doing it again are the only two things worth
  offering.

- **Eight canned moves, so you need not fly it by hand.**

  *Turntable* is one turn on the spot.  *Rise* turns while climbing, so a
  thing shows you its sides and then its lid.  *Underneath to over the top*
  starts below it looking up and finishes looking down.  *Nod* goes down to up
  and back without turning at all, for something with a front that turning
  would only hide.  *Half a turn and back* reads like somebody picking a thing
  up rather than a machine spinning it.  *Corner to corner* sweeps from one
  low corner to the opposite high one.  *The full look* goes over, under, back
  to level and round, so every face comes past the camera.  And *push in*
  closes slowly with a little drift, for a detail.

  **The ones you use come to the top of the list**, and stay there between
  sessions - eight is a comfortable number to offer and a tiresome number to
  read every time, and most people settle on two or three.

  All of them turn about **the middle of whatever you had selected** when you
  pressed Export, not about the drawing's origin - so a building drawn half a
  mile from zero does not swing out of frame.  Set the zoom you want with the
  wheel first and the move starts from there.

- **Center on the Origin is on the right button.**  Select something, right
  click, and it moves onto 0,0,0.  Same thing as `/center`.

## v2026.09.13.22

### New

- **STL and OpenSCAD come out centerd on the origin.**  A part used to open in
  the slicer wherever the drawing happened to put it, which for something drawn
  at building coordinates is a long way off the plate - and then you re-center
  it by hand in another program.  It arrives centerd now.  There is a tick in
  the export options if you want it left where it is.

- **`/center` moves things onto the origin.**  Type `/center` and whatever is
  selected moves so the middle of it sits at 0,0,0 - or the whole drawing, if
  nothing is selected.  Worth doing to the drawing itself and not only on the
  way out: a drawing that is centerd is one where the exports, the dimensions
  from the origin and the axis readings all agree.

## v2026.09.13.21

### New

- **Export to OpenSCAD.**  Export, then "OpenSCAD".  You get a `.scad` script
  with one `polyhedron` per solid in your drawing, each in its own named
  module, a module that unions them all, and a call to it - so a model in
  several pieces stays in several pieces and you can get at them separately.
  Millimeters, like the STL.

  Be clear about what it is: the surface of your drawing, written out as
  points and faces.  It is not built from cubes and cylinders and cannot be
  taken apart into them, so the numbers in it are not parameters to tweak -
  to change the shape, change it here and export it again.  What it is good
  for is everything *around* it: cut holes in it, union it onto something,
  fit it to a part you are describing in OpenSCAD.

## v2026.09.13.20

### Fixed

- **The preview and the recording window now handle like the drawing.**
  Middle-drag turns it, right-drag slides it, the left button does nothing,
  and the wheel zooms on the pointer rather than the middle of the picture -
  all the same as the drawing area, at the same speed.  They were all
  different before, which is why moving around in there felt odd.

## v2026.09.13.19

### Fixed

- **The preview and the recording window now handle like the drawing.**
  Middle-drag turns it, right-drag slides it, the left button does nothing,
  and the wheel zooms on the pointer rather than the middle of the picture -
  all the same as the drawing area, at the same speed.  They were all
  different before, which is why moving around in there felt odd.

- **The GIF export crash, properly this time - and a correction.**  The last
  release blamed memory and rationed the frames accordingly.  That was wrong.

  It was one missing line.  A GIF holds 256 colors and something has to
  choose which 256; in BGRABitmap that chooser is pluggable, and naming its
  unit is not enough - the factory has to be handed over explicitly.  It never
  was.  So any frame with more than 256 colors in it reached nothing at all
  and the program fell over.

  Which is exactly why it looked so strange: a plain line drawing exports
  fine, because white paper, gray faces and black lines fit inside 256
  colors easily.  Turn on the axes and three anti-aliased colored lines put
  it over, every time.  It had nothing to do with how long the film was.

  Reproduced here on Linux in the end, tracked to the line, fixed, and there
  is now a test that exports a film **with the axes on** - which is the
  default, and which the old test did not do, which is how it got out.

- **And the files were never big.**  A four second spin of a complicated
  model is 1.35 MB at 800 x 600, and the 15.9 second recording that started
  all this now comes out at 0.70 MB.  The dialog says roughly what it will
  weigh before you press the button.

## v2026.09.13.18

### Fixed

- **The Windows access violation on exporting a GIF.**  Your report had it:
  a 15.9 second recording at 20 a second is 318 frames, and a GIF is built
  whole in memory - every frame held until the last one is in, and then the
  packing pass duplicates them all as it walks.  At 800 x 600 that is over
  half a gigabyte of frames before it even starts packing.

  The number of frames now comes from the size as well as the length,
  whatever fits in a sensible budget, and the packing step is skipped when it
  would cost more than it saves - which on a turning model is most of the
  time, since every pixel changes between frames and there is nothing still
  to leave out.  **The film keeps its full length**: what gives is the frame
  rate, not the ending, because losing the end of your move is a worse answer
  than making it slightly choppier.

  Your 15.9 seconds at 800 x 600 now comes out as 104 frames at 7 a second,
  still 15.9 seconds long.  The dialog says so before you press the button,
  and tells you a smaller size buys you more frames.

- **A recording no longer quietly ignores the seconds box.**  It fills it in
  instead, so what it says is what you get - that mismatch is how four
  seconds turned into three hundred frames.

- **A failed export now names the frame.**  It used to say "while drawing the
  frames", which covered the drawing, the packing and the writing all at
  once.  It now says which of the three, and which frame of how many.

## v2026.09.13.17

### Fixed

- **Export could fail on Windows with an access violation and no file.**  I
  have not been able to reproduce it here and I am not going to pretend
  otherwise, so this release makes it tell us instead: when an export fails it
  now says which step it died in and what it was doing, and there is a
  **Tell us about it** button right there in the dialog that sends the whole
  thing - the format, the size, the settings, the lot.  One press and the next
  release can actually fix it.

  Some real hardening went in alongside: a film now draws every frame into one
  picture instead of making and destroying one per frame, which on a long GIF
  was eighty allocations for no reason; and a picture that cannot be made at
  the size asked for now says so rather than carrying on with it.

- **The export preview would turn but not slide.**  Right-drag or Shift-drag
  now slides it, the wheel zooms, and Shift is noticed part way through a turn
  the same as it is in the drawing area - so you can frame the shot properly
  instead of only spinning it.

- **Black writing on the dark dialog.**  Windows paints its own drop-down
  lists and tick boxes and takes no notice of what color it has been asked
  for, so some of the export dialog came out black on near-black.  It draws
  its own now.

### New

- **Export sizes worth having.**  Square, tall, wide, link card, 720p, 1080p,
  small-for-an-email - or type your own.  And asking for something enormous
  now quietly brings it down to something that will actually save, instead of
  refusing with "that size will not do".

- **Record a camera move instead of describing one.**  In the GIF panel,
  "Record a move instead" opens a window with nothing in it but your model.
  It counts you down from three, then simply watches where you point the
  camera - turn it, slide it, zoom in, pause on the good bit - and you press
  Escape when you are done.  What comes out is the move you made.

  It records where the camera was, not what was on the screen, so none of the
  cursor, the snapping lines or the hover marks get anywhere near the film,
  and it can be saved at any size afterwards.  The red, green and blue axes do
  stay, because they are what tells you which way up the thing is - there is a
  tick to turn them off.

## v2026.09.13.16

### New

- **A proper export dialog.**  Press Export and you get a room with the
  formats down one side, a live view of your model in the middle, and the
  settings for that format on the right - instead of a save box with the file
  types hidden in a dropdown and nothing at all to set.

  Turn the model with the mouse and zoom with the wheel: what you see in the
  middle is the shot.  Pictures can come out at twice or four times the size
  of the screen, or any size you type, and a PNG can have nothing behind it at
  all, for dropping onto a slide.

- **Export an animated GIF.**  Frame where it should start, frame where it
  should end, and it swings between the two - a turntable spin, a slow push
  in, a tilt down onto a roof, or all three at once.  There is a button for a
  full spin from wherever you happen to be looking, and one to watch the whole
  thing before you commit to it.

## v2026.09.13.15

### Fixed

- **Blue patches on shapes that had nothing wrong with them.**  Two separate
  causes, and neither was what the last two releases were chasing.

  A shape whose top had been divided - by a line drawn across it, or a piece
  pushed up out of it - was being read as though it had a gap in it, because
  one long edge on a wall no longer matched the two shorter ones that had
  replaced it on top.  It was watertight all along, and is now recognized as
  such, so its far side stops showing through.

  And faces worked out from lines were each wound on their own, which meant
  the two slopes of a roof could end up pointing opposite ways - one of them
  into the house.  Looking at it from outside, that one was blue.  They are
  now settled against their neighbors, so a roof points out of the building
  rather than into it, and `/rebuild` puts an old drawing right.

## v2026.09.13.14

### New

- **Export to STL, for a 3D printer.**  Export, then "STL - for a 3D
  printer".  It writes the model as triangles in millimeters, which is what
  every slicer expects, so a drawing in feet comes out the size you drew it
  rather than three hundred times too small.

  It also tells you whether the shape is actually closed.  That part matters:
  a slicer will accept a model with holes in it and guess where the inside is,
  and an hour into a print is a bad time to find out it guessed wrong.

### Fixed

- **A correction to what the last release claimed.**  13 gave a number for how
  much the new depth handling improved things.  That number was measured
  against the wrong yardstick and was not real, and it has been taken out of
  the note above.  The change itself is sound and stays - a face's depth is
  now exact at its corners instead of estimated - but it did not do what was
  claimed for it, and saying so is better than leaving it there.

## v2026.09.13.13

### Fixed

- **Faces that are not flat are now drawn at the right depth.**  This is the
  end of the pale blue faces, and of a whole family of things that could go
  wrong with them.

  Spinning or pushing a sloped edge makes a face with four corners that do
  not all lie in one plane - there is no such thing as the right flat sheet
  for one of those, and the drawing had been picking the best one it could
  and living with the error.  On the crown that error was up to fifteen feet,
  which is more than enough for the far side of a solid to be judged nearer
  than the near side and painted over it.

  Every such face is now cut into triangles first.  A triangle has exactly
  one plane and always lies in it, so there is nothing left to estimate: the
  depth is right at every corner of the face, and in between it can never
  stray outside the corners it sits between.

  Faces that really are flat are untouched and cost nothing extra - a drawing
  made only of flat faces comes out pixel for pixel as it did before.

## v2026.09.13.12

### Fixed

- **The last of the pale blue on solids.**  13.11 got most of it; thin
  slivers were still showing in the crevices of a revolved shape.

  Two things, and both are now right.  The first: faces that are not flat.
  Spinning a sloped piece of an outline gives a warped four-cornered face -
  one no flat sheet passes through - and the drawing worked out how far away
  each face is by fitting a sheet through three of its corners.  On one shape
  sent in, that fit was wrong by up to five hundred feet on a model two
  hundred feet across.  It fits every corner now, evenly, which brings it
  down to twelve.

  The second, which finishes it: **the back of a closed solid is no longer
  drawn at all.**  It cannot be seen - to look at one you would have to be
  inside the thing - so however the depth works out, drawing it is wrong.
  An open shell still shows its back, because there you really can look at
  it, and that is what the pale blue is for.

## v2026.09.13.11

### Fixed

- **Pale blue faces on a solid that is not inside out.**  A round shape - a
  revolve, or anything pushed out of one - could show patches of the
  back-face color on its near side.  Nothing was wrong with it: the far side
  of the object was showing through the near side, and the far side of
  anything is its inside.

  Faces that are not flat were the cause.  Spinning a sloped piece of an
  outline gives a warped four-cornered face - one no flat sheet passes
  through - and the drawing worked out how far away each face is by fitting a
  flat sheet to three of its corners.  On one shape sent in, 48 of its 336
  faces were out of flat, and the fit was wrong by up to five hundred feet on
  a model two hundred feet across: enough for the back of the thing to be
  judged nearer than the front.

  It fits every corner now, evenly, instead of three exactly and the rest not
  at all.  Which is also why it only ever showed on faces pointing certain
  ways round a shape - whether a badly fitted sheet leans toward you or away
  depends on which way the warp is turned.

## v2026.09.13.10

### Fixed

- **The drill goes all the way through.**  It had to land its far end exactly
  on the plane of the wall it comes out of - to a millionth - or it quietly
  made a solid plug instead of a tunnel, and left what looked like a wall
  across the hole.  Nobody can drag to a millionth, and the far face is
  behind the near one so there is nothing to hover over either.  The tool
  works the distance out now: click the face, click roughly where you want
  it, and it comes out the far side.  Both mouths open, and where it crosses
  a tunnel already there the two are cut into each other.

- **The program's name has gone from the top of the window.**  The reading -
  X, Y, Z, the plane and the run - grows leftwards as it gets longer and was
  running over the top of it.  The version stays, over on the left where
  nothing reaches.

- **No stray line flashing after a shape is thrown away.**  The two ends
  flying apart is a thing about a line snapping; a rectangle or a circle only
  gets the burst now.

## v2026.09.13.9

### Fixed

- **A rectangle no longer vanishes when it is drawn nearly along an axis.**
  The alignments are built for a line, where being pulled level with the
  point you started from is the whole idea.  On a rectangle it means a side
  of no length, which is not a rectangle - so it was thrown away, with
  nothing on screen to say why, on and off depending on which way you
  happened to drag.  An alignment that would flatten a side is now ignored,
  and that side lands on the grid like everything else.

- And when a rectangle really is too small in one direction to draw, it says
  so with the sizes and the snap setting instead of just "a rectangle needs
  two sides".

### Changed

- **Push/pull, drill and offset can be called off by leaning on the button**,
  the way the drawing tools already could.  They used to happen the instant
  the button went down, so realizing it was wrong meant undo.  Now they wait
  for it to come up: let go and it happens, keep holding and the face you
  were about to build strains and goes back having built nothing.

- The whole shape comes under tension while you hold, not one strand of it -
  a rectangle swells like a frame of elastic, a circle like a hoop, a
  push/pull shows the face where it would have landed.

## v2026.09.13.8

### Changed

- **Lean on the button and the whole shape comes under tension**, not one
  strand of it.  A rectangle swells like a frame of elastic, a circle like a
  hoop, each side bowing outward and trembling harder the nearer it gets to
  letting go - then one burst at the middle.  It used to strain a single
  diagonal from the first corner to the cursor, which is not any part of the
  rectangle and read as though something else had appeared in order to be
  destroyed.

- **Up and down both lock the ground plane now.**  They are one gesture and
  they mean one thing - flat, the way up and down mean flat on a table.  Left
  and right are still the two upright planes.  Esc lets go, as it always did
  and as every message says.

- **The plane shows itself before the first corner too**, not just once you
  have started drawing - so flipping between planes tells you which one you
  are about to get while there is still nothing on the paper.

## v2026.09.13.7

### New

- **A locked plane shows itself while you draw.**  Lock a plane with the
  arrows and two short lines appear through the point, along the plane's own
  two directions, in their axis colors.  Red and blue means you are drawing
  upright; red and green means flat.  You can see you are still on the plane
  without reading anything.

## v2026.09.13.6

### Fixed

- **A plane you lock with the arrows now stays locked.**  Press L, then the
  left arrow to stand the plane up, and every point of the shape lands on
  that plane no matter what the cursor is pointed at.  It could not before:
  the plane's position came from wherever the cursor had last settled, so a
  single inference a foot off the plane took the plane with it, and every
  corner after that was on a different one.  The outline never closed, no
  face was ever made, and there was nothing on screen to say why.

  That is why drawing an upright outline in the 3D view was so hard, and why
  drawing it flat on the floor was the only thing that worked.

  An axis lock still beats it - that is you saying something more recent.
  Nothing else does: an arrow lock is a statement, not a guess.

- **And the line tool says so.**  In a 3D view it now reads *"pick a start
  point (arrows lock a flat plane: left upright, right side-on, up flat, down
  to let go)"*, and once locked, *"held on the XZ plane whatever you point
  at"*.

## v2026.09.13.5

### Changed

- **Revolve: click the outline, then click its straight side.**  Two clicks.
  The straight side of a glass outline *is* the middle of the glass, and
  clicking it is what anybody does when asked for an axis - it used to mean
  "sweep the outline along this line", which cannot be done and quietly did
  nothing.  Now it means what it looks like it means.

  Two loose points still work for an axis that is not an edge, and any other
  line is still a path to sweep along.

- **It shows you what it is about to make.**  While you are placing the axis:
  the axis itself drawn as a long line rather than a stub between two clicks,
  and the two rings the nearest and furthest corners of the outline will
  sweep - which is the footprint of the result, before you commit to it.

- **And it says when the axis is wrong.**  An axis through the middle of the
  outline sweeps the two halves into each other and makes a knot with no
  outside.  The preview goes red, and it refuses with an explanation instead
  of doing it: *"A glass is spun about a line down one side of its outline,
  not through it."*

- After it spins, it says how big the thing is - *"Spun 360° in 24 gores,
  0'-1" to 0'-9 5/8" across."*

### Fixed

- **`/replay` and `/session` keep the capitals in a file name.**  The command
  bar folds what you type to lower case so that LINE and line are the same
  tool, and it was folding the path too - so replaying anything under a
  folder with a capital letter in it said the file did not exist.

## v2026.09.13.4

### Changed

- **Follow Me is called REVOLVE now, and it is on the tool strip beside
  push/pull.**  Draw the outline of half of something - a glass, a bowl, a
  bollard, a pipe fitting - click it, then click two points for the axis, and
  it spins into a solid.  Type an angle first for a part turn.

  It could always do this.  It was called Follow Me, which is SketchUp's name
  for the other half of what it does (sweeping a face along a path, which it
  still does), and it was behind the MORE door - so the one thing everybody
  else calls a lathe was under a name nobody else uses, in a drawer.

### Fixed

- **A shape off the lathe comes out the right way round.**  Which way each
  strip faced was worked out by pointing away from the middle of the outline,
  and the middle of a thin C-shaped outline - the wall of a glass, say - is
  in the hollow rather than in the material, so half the shape came out
  inside out and pale blue.  It uses the outline's own winding now, which
  does not care what shape it is.

- **Replaying a session gets the tools that pick things.**  A recorded press
  carried the point in the model but not where that lands on the screen, so
  replaying one hit Revolve, Push/Pull and the eraser with wherever the mouse
  had last been left rather than where the click was.

## v2026.09.13.3

### Fixed

- **PLAN is on the VIEW menu again**, at the top, saying what it is - and TOP
  says what *it* is, which is the 3D camera pointed down and not a plan at
  all.  Plan had been taken off that menu back when it was a half-finished
  paper mode, so the only way into the cut and everything built on it was to
  know that `/plan` existed.

- **The doors on the tool strip close when you click them again.**  MORE
  TOOLS and SHOP opened their lists and would not put them away.  Clicking a
  tool, or the bare strip, closes an open list too.

- **The right-button menu always has the same rows**, with the ones that
  would do nothing grayed out instead of missing - and **Erase is last**.
  It was built the other way, so on a shape where the click landed on an
  edge rather than a face, Reverse Face was absent, Erase moved up into the
  row Reverse Face is normally in, and the same click in the same place
  erased the thing instead of turning it over.

- **The right button can reach the faces of a round thing.**  A cylinder's
  sides are about ten pixels wide on screen and the edge under the cursor
  was winning from nine pixels away, so a right-click on a curved surface
  always got an edge and never the face.  It takes an edge from four pixels
  now; aim at one and you still get it, be anywhere in the middle of a face
  and you get the face.

## v2026.09.13.2

### New

- **A plan shows what is underneath, dashed.**  A wall beneath a roof, a
  beam over a door, a footing under a slab - anything a plan cannot see is
  now drawn as a dashed gray line instead of being painted over and lost.
  That is what a drawing does and what a photograph from above does not.

  Only in PLAN.  In the 3D view a hidden line is round the back of something
  solid, and dashing those would put the far side of every box on top of the
  near side.

## v2026.09.13.1

### New

- **Hover anything and it tells you what it is.**  There were never any
  tooltips: the hover text went to a line at the top of the window, in the
  smallest type on it, seven hundred pixels from the pointer.  Now a card
  appears beside whatever you are pointing at, with the name and a sentence
  about what it does.

- **Open, Save, Export, Print, Undo and Redo are at the top left**, with
  their names on them, where every other program keeps them.  They were in
  the bottom right corner among twelve identical squares.  The Heckers Sketch
  name has moved to the middle of that line to make room, and Undo and Redo
  gray out when there is nothing to undo.

### Changed

- **The tools are in groups now**, with a line between them: pick, then the
  four shapes, then push/pull on its own, then move and erase, then measure,
  protractor, dimension and text, then orbit.  **Measure and the protractor
  have come back out of MORE** - measuring is most of why anybody opens this.

- **SHOP is at the foot of the strip on its own, with a spanner on it.**  It
  is a door into the trade wizards, not a drawing tool, and it had the same
  arrow as MORE which made two quite different doors look like one thing.
  The duplicate SHOP button along the bottom has gone.

- **The settings say what they are** - PRINT SCALE, SNAP TO, LINE COLOR,
  LINE WIDTH, ROUNDED TO.  "PREC" is gone; so is "SET".  The buttons beside
  them have names too: FIT, ORIGIN, GRID, UNITS, THEME, HELP.

- **The row along the bottom is one row deep** instead of three.  All of that
  height is drawing now.

- The collapse arrow says **COLLAPSE** and **EXPAND**, which is what it does.

## v2026.09.13

### New

- **The tools stand down the left, with their names on them.**  Screens are
  wide and short, and two rows of buttons along the bottom were spending the
  height of your drawing to save width there was plenty of.  A column costs
  width instead - and reads as a list rather than as a wall.

  Ten tools are on it: select, line, rectangle, circle, arc, push/pull, move,
  erase, dimension and orbit.  The rest - rotate, offset, follow me, drill,
  measure, protractor and text - are one click away behind **MORE**, and the
  shop wizards behind **SHOP**, both on the same strip.  Nothing has been
  taken away.

  The names show by default, because nobody can tell Offset from Follow Me by
  pictogram.  **< NAMES OFF** at the foot of the strip puts them away for a
  wider drawing, and it remembers which you chose.

  The row of buttons along the bottom is a row shorter for it - what is left
  there is settings and the things that act on the program rather than on the
  drawing.

- **A plan view is a slice through the model now, not a photograph from
  above.**  Switch to PLAN and a **CUT** strip appears beside the view
  button: a bottom and a top, in feet and inches.  Only what is between them
  is in the drawing - drawn, snapped to, and picked.  A barn whose roof used
  to cover the whole building cuts to just the walls.

  **Ctrl and the wheel over the drawing travels up and down through the
  model**, carrying the slice with it, so you can scroll until the plan looks
  right without taking your eyes off it.  The wheel over either number moves
  just that end; clicking one lets you type it.  Right-click a floor and
  **Plan From Here** sets the whole thing in one go.

  The bottom of the slice is also the height you draw at - which is what a
  floor plan means.  Set it to 9'-0" and you are drawing on the second
  story.

  It is off until you turn it on, it says how many things it is keeping out
  so nothing goes missing quietly, and `/cut 0 9'`, `/cut all` and `/cut off`
  do the same from the command bar.

- **A plan is drawn like a drawing.**  No more shading in PLAN: the light
  that makes a 3D view read as a solid object was turning two slopes of a
  roof into two different grays, which in a drawing means nothing at all.
  Faces fill pale so the lines carry the drawing, which is what lines are
  for.

- **Type a size into a dimension and the drawing follows.**  Pick a dimension
  with the select tool, type what it ought to read - `14'`, `12'6`, `6-8-15`
  - and press Enter.  The end the dimension was drawn to moves out, and
  everything from that end outwards goes with it, so a rectangle stays a
  rectangle.  Anything between the two ends stays where you put it.

  `/resize 14' start` moves the other end instead.

  It is an edit, not a rule that sticks: the drawing moves once and nothing
  is remembered, so nothing can go stale and nothing can end up fighting
  anything else.

- **Print it full size, across as many sheets as it takes.**  `/print full`
  lays the drawing out at 1:1 and prints a page at a time.  Tape the sheets
  together, put the paper on the metal and scribe round it - which is what a
  flat pattern was always for.

  Every sheet repeats the last half inch of the next one down its right side
  and along its bottom.  Trim on the marked line, butt the next sheet against
  it, and the drawing runs straight through.  The sheet number is printed
  inside that strip, so it goes in the bin with the trim.

  It tells you how many sheets it will be and asks before it starts.  PLAN is
  the view to print a pattern from, and it says so if you are in another one.

- **`/tiles <folder>`** writes the same pages as PNG pictures instead of
  printing them - for sending to a print shop, or for seeing what the paper
  would look like without using any.

## v2026.09.12.4

### New

- **A menu on the right button.**  With the select tool, right-click
  something in the drawing.  It picks what is under the cursor and offers
  what can be done to it - and the first thing on that list is **Reverse
  Face**.

- **Reverse Face** turns a face over, so what was its pale blue back becomes
  its front.  The program guesses which way a new face should point and the
  guess is a good one, but two walls back to back are wound the same way and
  one of them therefore shows its back to whoever is standing outside.
  Nothing in a drawing of loose faces says which side of a wall is outside,
  so this is the way to say so.  Several faces selected turns them all over;
  `/reverse` does it from the command bar.

## v2026.09.12.2

### Fixed

- **A corner you point at is the corner you get.**  Drawing on a face, the
  tool holds every point to that face - which is what drawing on it means.
  It was holding named points too, so aiming at the top of a rafter twelve
  feet up gave you the eave underneath it while the reading said ENDPOINT.
  Endpoints, midpoints, centers, crossings and the origin now beat the held
  face, the way an axis lock already did.  Everything the program is only
  guessing at - on an axis, on a face, on the grid - is still held.

- **Both halves of a roof face the sky.**  A roof built as two slopes off a
  ridge came out with one slope gray and the other pale blue, because pale
  blue is the back of a face and one of them really was inside out.  Areas
  the program fills in for you are now turned the same way up as ones you
  draw yourself.

  Two upright faces back to back - the two ends of a barn - can still show
  one of each.  There is no way to tell the outside of a loose wall from the
  inside without a solid around it - which is what Reverse Face is for.

## v2026.09.12.1

### New

- **A bug report now carries the session that caused it.**  Alongside the
  drawing, a report holds what you did to it - the tool you picked, the points
  you clicked, the lengths you typed - written so the program can read it back.
  Open the drawing, type `/replay report.txt`, and it happens again in front
  of you instead of being described.

  It records only what this window was given.  There is no system-wide hook,
  it cannot see another program, and nothing typed anywhere else can reach it.
  Points are kept as real coordinates rather than pixels, so a session
  recorded on one screen replays on any other.

- **`/session [file]`** writes what has been recorded so far to a file,
  without filing a report - for keeping a sequence you want to run again.

## v2026.09.12

### Fixed

- **Lines drawn in mid air no longer disappear behind solids.**  Drawing the
  ridge of a roof, or any line that does not lie flat on a face, showed the
  parts of it over empty background and swallowed the parts crossing anything
  solid.  The line was being painted before the faces and only put back if it
  lay in the plane of one.  Lines are now tested against the depth of the
  solids per pixel, so a line in front of something shows and a line behind it
  is properly hidden.

- **Drawing straight up off a face works again.**  Starting a line on a face
  and running it up the blue axis said LOCKED TO BLUE and then drew nothing -
  the point was being pulled back down onto the face as fast as the axis took
  it up, so the line had no length.  Picking the tool again was the only way
  out.  Running up an axis now leaves the face, which is what standing a gable
  up means.

- **Bug report pictures show the mouse pointer.**  An arrow and a red ring are
  drawn where the cursor was, so a report about what was under the mouse can
  be read without guessing.

### Better

- **A wrong row stride can no longer wander into a wild pointer.**  Nine times
  in one session a drawing surface was found holding a stride that was really
  a floating point number - already caught and repaired, but caught after the
  fact.  The arithmetic that turns a row into an address now refuses a stride
  that could not be one, and a decoy field sits where the stray write keeps
  landing so the next report says plainly what is doing it.

## v2026.09.10.2

### Faster

- **Hover on a big drawing.**  Finding the snap point under the cursor
  used to project every snap point on the drawing to the screen on every
  mouse move - a hundred and twenty thousand of them on a fifty-thousand
  thing drawing, every time the mouse twitched.  The projected positions
  are kept now and reused while the camera is still, with a box round the
  cursor throwing out the far ones before the distance is worked out, so
  a hover while placing a point costs almost nothing after the first move.

## v2026.09.10.1

### Fixed

- **A footing of concentric rings works right again with `/rebuildfaces`.**
  A drawing saved by an older build could hold its faces the wrong way -
  four concentric rectangles kept as four solid faces stacked on each
  other rather than three rings and a middle - and the ordinary rebuild
  keeps a drawing's faces on purpose, so it did not repair them.  The new
  `/rebuildfaces` command throws every face away and works them all out
  fresh from the lines: the rings come back, each its own face to push,
  pull or delete.  It is for flat work and has undo.

## v2026.09.10

### Fixed

- **Closing a sheet asks first.**  A sheet with anything on it now puts up
  a question when you close it: save the drawing, close without saving, or
  keep it open.  Close without saving discards it; keep it open leaves it.
  Nothing is thrown away silently.
- **The header says when a drawing has unsaved changes.**  A named drawing
  that has been edited since it was last written shows "unsaved changes
  (Ctrl+S)" next to its path.
- **Two new sheets no longer share a name.**  A drawing whose sheets were
  named out of order could get two "Sheet 2"s; a new sheet takes the
  lowest free number now.

### Changed

- `/saveas` from the command bar, and the save button's tip mentions
  Shift+Ctrl+S for save-as.

## v2026.09.09.4

### Changed

- **Beads and cross breaks look like the metal.**  A rolled bead is a
  ridge now, three quarters wide and standing a fat eighth proud, built
  in three facets so it shades the way rolled metal does, with its edges
  drawn along it and its profile at each end; it stops an inch short of
  the seams where the roll stops.  A cross break is the same ridge made
  shallower and narrower, the crease of the brake, stopping short of the
  corners.  They were single lines before.

## v2026.09.09.3

### New

- **Gauge and stiffening on the fitting builder.**  A Metal row: the
  gauge, left as "as needed" for what the size calls for - 26 to 12",
  24 to 30", 22 to 54", 20 to 84", 18 beyond, the usual low-pressure
  table - or picked outright, and how the big panels are stiffened: as
  needed, none, cross breaks, or beads every foot.  As needed means a
  panel over 18" wide and a foot long gets a cross break up to a yard
  long and beads beyond that.  The breaks and beads are drawn on the
  walls in a lighter line, the builder says what it chose under the row,
  and the ticket carries a Metal line naming the gauge and which walls
  are broken or beaded.  The thresholds are the common ones; a shop that
  runs lighter or heavier picks its own.

### Changed

- **Two menus cleaned up.**  The VIEW menu no longer offers the plan and
  iso paper modes - this is a 3D model, and a flat layout tool is for
  another day - and the SHOP menu loses "Field sketch, on iso paper",
  which the Fitter's scratchpad replaced.

## v2026.09.09.2

### Fixed

- **Orbiting when zoomed in.**  With the cursor on paper rather than on a
  face, the view turned about the middle of the whole drawing - a point a
  hundred feet away when you are zoomed in on one fitting - and the
  fitting swung straight out of the view.  The pivot is now the nearest
  drawn thing to the cursor on screen, from the last frame's depth buffer,
  then whatever is selected, and only then the drawing's middle.

## v2026.09.09.1

### New

- **The tape wizard does a vertical run off a furnace.**  A button on the
  wizard switches between the hallway and a furnace room: the furnace on
  the floor against a brick wall, its collar on top as the entry, the
  trunk above with the opening the transition rises to as the exit, and
  the transition dashed between.  Two views: from the side for front to
  back, taped from the wall behind the furnace, and from the front for
  left to right, taped from a wall beside it.  The same four readings, the
  same shop words - the furnace laid on its back, so the builder's top is
  the duct's front and its bottom the back - and the ticket says so.

### Changed

- The duct in the hallway is galvanized gray now.

## v2026.09.09

### Changed

- **The tape wizard's pictures are a hallway.**  Both tape pages are one
  cartoon: a hallway seen from the entry end, a smooth ceiling with a
  light, a tile floor, brick walls either side, and the duct hanging a
  foot below the ceiling the way it would on the job, its exit end
  further down the hall and offset the way the readings say.  The tape
  lines run from the floor or the ceiling, or from a wall, to the edge
  each reading was taken to, with the reading on the line.  The exit
  shows dashed through the entry so the offset and the smaller size read.

## v2026.09.08.9

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
- Center, not center: the wizards' words are American now.

## v2026.09.07

### New

- **Pipe spool.**  SHOP > Pipe spool..., or /spool: the pipe fitter's iso
  as a form.  Iso paper you click the run onto, one leg at a time - each
  leg snaps to the three axes, or with Shift to a 45 - and type the
  center-to-center length on.  Pick the pipe size, long or short radius
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
  round its center.

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
  painted in the inside color.  The builder wound those faces the wrong
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
- **A tee's branch centers itself.**  Leave "starts, from the entry" blank
  and the branch sits in the middle of the run, the way a blank height
  already centers it on the wall.

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
- A move locked to blue drew its travel line gray instead of blue.

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
