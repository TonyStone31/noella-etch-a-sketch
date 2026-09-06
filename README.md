# Heckers Sketch

A kid's Etch A Sketch that turned into a measuring and sketching tool I use on
job sites.  Free Pascal / Lazarus, no third-party dependencies, free forever.

**[Download the latest release](../../releases/latest)** - Windows and Linux,
no installer, single file.

---

## The story

**19 October 2021.** Noella Stone was seven years old and decided she
wanted to write a program.  She drew the screen, the two dials and the shake
button on paper, picked the colors, and told her dad what each part was
supposed to do.  He typed while she directed.

That program is still here.  The layout is hers, unchanged, and it is one key
press away from everything else in the app.

**Five years later** I came back to it, mostly for the fun of seeing how far an
AI could take a seven-year-old's toy if I asked it to build the tools I
actually wanted.  The answer turned out to be further than I expected.  The
dials and the shake button are still there; next to them now is a second mode
with a drawing board, real drawing scales, snapping and inference, push/pull,
a tape measure that reads out feet and inches down to the sixteenth, and a
wizard that builds a duct fitting from the numbers on a ticket.

Somewhere in there her toy stopped being a toy.  I use it at work.

## What it is for

I am an HVAC technician, and I also do the construction side of that world -
the duct, the curbs, the sheet metal, the pipe.  A good part of what I need to
draw in a day is a transition, an elbow, a tee, a pipe run, a curb - quick
one-off things where what matters is getting an honest measurement out the
other end, fast, standing in the field, and being able to send the office a
ticket the shop can make it from.

SketchUp does that job well.  I happen to like SketchUp and I know how to use
it, so Heckers Sketch is modeled on it deliberately: close a loop and it
becomes a face, click a face and push it, snap to endpoints and midpoints,
type a length instead of dragging for it.  [`docs/sketchup/`](docs/sketchup/)
holds fifteen of their help pages, read properly and written up, each with a
note on what we have, what we don't, and where we differ on purpose.  When
there is an argument about how something ought to behave, that is what we
argue against.

Be clear about what this is not.  It is **not trying to compete** with real
CAD programs, or with SketchUp directly, and it probably never will.  You
would not produce a real set of drawings in it.  What it is trying to be is a
sketching tool that is dimensionally honest and useful for what I do, that
stays simple enough to use with one hand on a ladder, and that knows a few
things about my trade a general program never will - what a TDF flange is,
which way a slip-and-drive goes on, what a fitter can actually measure from
the end of an open duct.  We will keep it as accurate and as useful as we can
without letting it become massively complicated.  It is given away free.

[`docs/direction.md`](docs/direction.md) is the longer version of that
decision, written down so it can be argued against.

## Developed with Claude

This is an AI-built project and there is no reason to be coy about it.
Nearly all of the PRO code was written by Anthropic's **Claude**, working
from my descriptions of what the work actually needs, and checked against the
SketchUp notes in `docs/sketchup/`.  I direct it, I use the result on real
jobs, and I tell it what is wrong with it; it writes the Pascal, builds it,
and runs the tests.

That shows in how the repository is laid out.  The SketchUp reference notes,
the headless test suites, and a `TODO.md` written as a running log all exist
so the work can be picked back up cold.  If you are curious what building
something genuinely useful this way looks like, the commit history is an
honest record of it.

---

## TOY

The program Noella designed.  **W** swaps between it and PRO.

* **Two dials you actually grab and turn** - left moves across, right moves up
  and down, exactly like the toy.  Arrow keys work too, with **Shift** to
  sprint and **Ctrl** to creep a pixel at a time.
* **Five pen styles** - Classic, Neon (a glowing tube of light), Rainbow,
  Sparkle, Chalk.
* **Kaleidoscope** - repeat every stroke 1, 2, 4, 6 or 8 times around the
  center, with an optional mirror.  Scribbling turns into a mandala.
* **Auto-draw** - the machine doodles a spirograph, rose curve or lissajous
  figure.  Try it with rainbow ink and 8-fold symmetry.
* **Shake to erase** dissolves the drawing into aluminum powder.

## PRO

The same idea taken seriously.  The program starts here, in the 3D view.

**Drawing**

* **Draw by typing.**  Click a start point, then type `12'6"` and press an
  arrow - or press an arrow to set the direction first, then type.  It takes
  `12'6"`, `12-6`, `12 6`, `6 1/2"`, `150"`, `3.5m`, `350cm`, and the truss
  shop's `6-8-15` (feet, inches, sixteenths).  A rectangle takes both sides
  at once: `8x10`, `8,10`, `8/10`.  The move and line tools take a place too:
  `[4,0,8]` is a point in the drawing, `<4,0,8>` is that far from where you
  are.  [`docs/typing-measurements.md`](docs/typing-measurements.md) has the
  whole list and the reasons.
* **A command bar that says what it wants next**, so there is nothing to
  memorize.  Type a number and it is a length; start with `/` and it is a
  command - the full list is below.  Every tool's tip shows an example of
  what it will take typed.
* **Tools** - select, line (chained), rectangle, arc, circle, push/pull,
  drill, offset, move, rotate, tape measure, protractor, dimension, text
  note, eraser, orbit.  Clicking the lit tool puts it away; **Esc** backs out
  one step at a time.
* **Circles and arcs take a side count.**  `24s` or `s24` while the tool is
  in hand, `+` and `-` to step it; a chip at the cursor shows the count.
  That matters when a round hole has to be drilled through a block.
* **Offset** for a wall thickness.  Click a face, move in or out, and click -
  or type `2"`.  Every edge shifts sideways and the shifted edges extend to
  meet again, so the spacing is exact at the corners too.
* **Rotate** turns a selection about a point, on the plane the arrows pick by
  color, by a dragged or typed angle.  With nothing selected it takes
  everything joined to what you click, so a box turns as a box.  The
  **protractor** measures an angle the same way.
* **Copy arrays.**  Hold **Ctrl** while moving or rotating to leave a copy,
  then type `3x` for three that far apart or `/3` to divide the run - the
  same after a turn, round the turn.
* **Notes with leader lines.**  Click what the note is about, type it -
  **Shift+Enter** for another line - move away and press Enter.  Leave the
  cursor where you clicked and it is a plain label instead.  The text size is
  typed too.
* **Lean on the button to throw away what you are drawing.**  Hold the mouse
  button down on a shape you have just made a mess of; it bows, goes red,
  and comes apart.  About a second and a half, so there is time to change
  your mind.
* **Double-click finishes a run of lines.**  A line carries on from the point
  you just put down; a double-click lets go of it without placing anything.
  Esc does the same.
* **Arcs join two loose ends.**  Pick the two points, pull the middle out.
* **Select and move.**  Click picks; double-click takes a face and its
  edges; triple-click takes everything joined.  **Ctrl** adds, **Shift**
  toggles.  Drag a box - right-to-left takes anything it touches,
  left-to-right only what fits wholly inside, SketchUp's rule.  Moving a
  corner **stretches** what is attached to it rather than tearing it off.

**Measuring**

* **The shape you are about to draw is drawn solid and heavy**, in the color
  of the axis it is locked to, the way SketchUp does it.
* **True scale.**  1/16", 1/8", 1/4", 1/2" and 1" = 1'-0", or 1:200 through
  1:10 in metric.  Printing re-renders the page from the geometry at the
  printer's own resolution, so a quarter inch on the paper really is a foot.
* **The tape measure** reads out distance plus dX/dY/dZ as you pull it.
  Enter keeps what it measured as a dimension, or drops a **guide line** you
  then snap to.
* **Dimensions between any two points** - corner to corner, corner to the
  middle of an edge, across thin air - with the extension lines snapped
  square to an axis.  The move tool taken to a dimension's line repositions
  the line; the eraser takes it away.
* **Right-click a dimension to write over its figure** - a nominal size, a
  cut length, `FIELD VERIFY`.  The measurement underneath never changes, and
  the written figure goes out in the SVG export too.
* **PREC** sets the fraction the drawing reads and writes in, 1/2 through
  1/64 or hundredths.

**Geometry**

* **Faces are derived, not stored.**  Every edge is split at its crossings,
  the coplanar ones are grouped, and the smallest closed loops are walked out
  of the resulting graph.  Draw a line across a square and you get two faces
  you can push independently; erase it and you get the square back.  Islands
  inside a face become holes.
* **Push/pull.**  Pick a face, type how far, and it lifts into a shaded solid
  with its sides walled in - including circles.  Anything drawn on the face
  rides along with it.  Pushing a face into a solid makes a pocket; pushed
  right through, it makes a tunnel, and it stops at the first tunnel it
  meets and says so.
* **Drill.**  Where push/pull stops, the drill goes on: a second tunnel cuts
  clean through the first, square or round, from any side, so a block can be
  bored in several directions like a manifold.
* **Shake the mouse to say which way you meant it.**  Drawing in mid air and
  the shape keeps standing up when you wanted it flat?  Jerk the mouse side
  to side and it lies down; jerk it up and down and it stands up.
* **Snapping and inference** - endpoints, midpoints, arc centers and
  crossings beat the grid, each with its own marker.  A point on a face says
  ON FACE.  Nothing hidden behind a face is snapped to.  When the cursor
  lines up with a point elsewhere it is pulled onto that line and a dotted
  guide is drawn back to it.  **SNAP OFF** kills all of it; holding **Alt**
  suspends it.
* **Profiles and back faces.**  The silhouette of a shape is drawn heavier
  than the edges inside it, the facets of a curved surface are softened away,
  and the back of a face is painted pale blue, SketchUp's way of showing a
  solid built inside out - and of showing the inside of a hollow duct
  through its open end.  Hidden lines stay hidden with crisp corners.

**Views and files**

* **One drawing, one camera, one VIEW button.**  Click it to step through
  the views - the four corners, front, right, back, left, top - or open its
  arrow for the list.  Middle-drag orbits from any view with any tool in
  hand.  **PLAN** and **ISO** are paper modes: plan is a flat sheet, ISO is
  real 30° isometric paper, +X down-right, +Y down-left, +Z straight up, the
  way a pipe spool is drawn.  Work done on paper is kept when you go back to
  3D.
* **Tabs** - as many sheets as you like, each with its own scale, units and
  view.  All of them save into one file.
* **Its own file format.**  Drawings save as `.hsk` - plain text, one line
  per entity, so it stays readable and diffable and old files keep opening.
  PNG and **SVG** are exports, not saves; the SVG is real vector output with
  the dimensions as text.  A flat pattern goes out as **DXF** for a cutting
  table.  `heckers-sketch drawing.hsk` opens one straight from the shell.
* **Nothing is ever lost.**  A couple of seconds after you stop drawing the
  whole session is written to a draft beside the settings, and the next
  launch picks it straight back up.  Pull the plug and it is still there.
  `Ctrl+S` gives it a real name when you want one.
* **Delete asks** before clearing a sheet.  It deletes the selection if there
  is one, and otherwise wants a yes.
* **Zoom and pan are independent of the drawing scale**, so zooming in to
  place something does not change what prints.

## The shop tools

This is the part no general program has, and the reason the project kept
going.  Everything here is under **SHOP** on the deck.

**Build a fitting** (also `/transition`, `/elbow`, `/tee`) is a wizard - a
real form, not a drawing exercise - that reads like the ticket a fitter
hands the shop.  Radio buttons at the top pick the kind:

* **Transition.**  Entry opening, exit opening, the length, which side comes
  in and by how much, and what the height does: flat bottom, flat top,
  centred, or the top or bottom moved up or down by an amount - whichever
  edge you could actually get a tape on.
* **Elbow.**  The opening, the angle - 22.5, 45, 90 or any other - which way
  it turns seen from the entry, the throat radius (0 is a square throat), a
  square or rolled heel, and a straight leg at each end.  Give it a
  different exit size and it is a reducing elbow: the size across the turn
  changes through the turn, the other size in the exit leg.  **From field
  measurements** works the angle and both legs out from what you can measure
  standing at the open end - ahead and across to the duct it has to meet,
  and that duct's direction - so the elbow lands where it has to.
* **Tee.**  The run, the branch opening, which wall it comes off, where it
  starts, and how long the branch is.  Blanks centre it.

Every fitting takes an **end type for each end**: raw, notched all round for
a field slip, flange out, flange in, TDF flange, slip and drive, or drive
and slip, each with its size, and the fitting is built with them - notches
cut, flanges and drive edges bent, the TDF fold-back - so the 3D part shows
the connection.  A **tag** names it on the ticket and on the part.  The
sizes go on as dimensions.  A plan sketch and a corner view draw themselves
as you type, and the corner view is built by the same code that builds the
real thing.

Then: **Build it** drops the part into the drawing, hollow, on the cursor.
**Email it** writes the plan, the corner view and every input as words,
and opens them as a new message in your own mail program, ready to send to
the office.  **Show the files** puts the same files in front of you in the
file manager.  Nothing is sent by the program itself.

**Lay a piece out flat** (`/unfold`) takes a folded piece of sheet metal -
a duct you pushed up, say - and unfolds it into a pattern: solid where it
gets cut, dashed where it gets folded, brake notches marked, the sheet size
written on it, and a DXF for the table.

**Field sketch** puts you on isometric paper for a rough sketch the way a
pipe fitter draws one.  Turning that sketch into a built run is on the list.

[`docs/transition-ticket.md`](docs/transition-ticket.md) is the fitting
wizard's own notebook - the notation, the end types with their assumed
sizes, the elbow geometry, the field-measurement solve.
[`docs/interchange-and-flat-patterns.md`](docs/interchange-and-flat-patterns.md)
is the thinking behind the flat pattern and the DXF.

---

## Commands

Type `/` in PRO and then one of these.  Most tools also have a key.

| Command | Does |
| --- | --- |
| `/line` `/l`, `/rect` `/r`, `/arc` `/a`, `/circle` `/c` | the drawing tools |
| `/push` `/pull` `/p`, `/drill` `/bore` `/punch`, `/offset` `/f` | the solid tools |
| `/select` `/s`, `/move` `/mv`, `/rotate` `/q` `/turn`, `/erase` `/e` `/del` | select, move, turn, erase |
| `/measure` `/m` `/tape`, `/protractor` `/angle`, `/dimension` `/dim` | measuring |
| `/text` `/note` `/n` | a note |
| `/orbit` `/spin` | the orbit tool |
| `/transition` `/trans` `/fitting` `/elbow` `/tee` | the fitting wizard |
| `/unfold` `/layout` | lay a piece out flat |
| `/view` | the next view preset (the VIEW button) |
| `/corner` `/front` `/right` `/back` `/left` `/top` `/down` | go straight to that view |
| `/3d` `/orbit`, `/iso`, `/plan` `/2d` `/flat` | the 3D camera, isometric paper, plan paper |
| `/fit` `/zoom` | zoom to fit the drawing |
| `/plane xy` `/plane xz` `/plane yz` | the working plane; `/plane` alone cycles |
| `/origin` `/o` | move the origin to the cursor |
| `/grid` | grid on / off |
| `/guides` `/noguides` | clear the guide lines |
| `/units` | feet-and-inches / metric |
| `/scale 1/4` | the drawing scale (`1/16` `1/8` `1/4` `1/2` `1`) |
| `/new` `/tab`, `/close`, `/clear` | sheets: a new one, close this one, clear this one |
| `/save`, `/print` | the same as Ctrl+S and Ctrl+P |
| `/undo` `/u`, `/redo` | history |
| `/update`, `/update never`, `/update always` | fetch a newer build; stop looking daily; look again |
| `/whatsnew` `/changes` | the release notes |
| `/version` | which build this is |
| `/help` `/?` | about |
| `/regions`, `/rebuild`, `/rendertime` | for debugging: report the flat areas, work them out again, time a frame |

While a tool is in hand the command bar also takes the tool's own input: a
length, `8x10`, `[x,y,z]`, `<x,y,z>`, `24s`, `3x`, `/3`.

## Keyboard

**Both modes**

| Key | Action |
| --- | --- |
| Ctrl+Z / Ctrl+Y | undo / redo |
| Ctrl+O | open a drawing |
| Ctrl+S / Ctrl+Shift+S | save / save as |
| Ctrl+E | export a picture (PNG or SVG) |
| Ctrl+P | print |
| Delete | shake to erase / clear the sheet |
| G | grid on/off |
| W | swap TOY and PRO |
| F1 | about |
| `[` `]` | thinner / thicker line |

**TOY**

| Key | Action |
| --- | --- |
| Arrow keys | draw |
| Shift / Ctrl | fast / slow |
| Space or Alt | lift the pen |
| 1 ... 5 | pen style |
| S | cycle the kaleidoscope |
| M | mirror |
| A | auto-draw |
| T | next theme |

**PRO**

| Key | Action |
| --- | --- |
| L R A C | line, rectangle, arc, circle |
| P B F | push/pull, drill (bore), offset |
| M Q E | move, rotate, erase |
| T D N | tape measure, dimension, note |
| O | orbit |
| Tab | next tool |
| Enter | place a point, or commit what you typed |
| Space | the select tool when nothing is in hand; otherwise the same as Enter |
| Double-click | finish a run of lines |
| Hold the left button | throw away what you are drawing |
| Shift+Enter | another line in a note |
| Arrow keys | set the direction while drawing; otherwise nudge the cursor |
| Shift+arrow | hop to the next point on the drawing |
| digits, `'` `"` `-` `x` `/` `s` | type into the command bar |
| `/` | start a command |
| `+` `-` | more or fewer sides on a circle or arc |
| Esc | back out: clear what you typed, then the operation, then the tool |
| Alt (held) | suspend snapping |
| Ctrl (held) while moving or turning | leave a copy behind |
| V / Shift+V | next / previous view preset |
| I | isometric paper / plan paper |
| K | cycle the working plane (XY / XZ / YZ) |
| Shift+F | zoom to fit |
| U | feet-and-inches / metric |
| H | next theme |
| Ctrl+T / Ctrl+W / Ctrl+Tab | new sheet / close sheet / next sheet |
| Right-click a dimension | write over its figure |
| Right-drag | pan;  wheel = zoom |
| Middle-drag | orbit - from any view, with any tool in hand, mid-line |

---

## Keeping it up to date, and telling me when it breaks

The **help button** on the deck - bottom right, the `?` - has About, Check
for updates, What's new, Downloads, the manual, Report a problem, and the
project page.  The version is shown next to the name in the header.

**Updates.**  It looks at the GitHub releases page **once a day** and says in
the status bar if there is a newer build.  `/update` fetches it, checks it
against the checksums published with the release, puts it in place and
starts again - your drawing is kept and comes straight back.  After an
update it shows you what changed.  `/update never` stops the daily look;
`/update` still works whenever you ask; `/update always` turns it back on.
It will not touch a copy running from its own source folder.

What the update check sends: nothing.  It asks GitHub one question - what is
the newest release - over the same public URL your browser would use.

**Reporting a problem.**  Pick it from the help menu, or from the button
inside the fitting wizard when the wizard is the problem.  It takes a
picture first - now, or after ten seconds so you can set the screen up the
way it went wrong - then a line or two from you, and adds what the program
was doing: the version, the tool, the view, and the last few dozen things
that happened.  The drawing file goes with it only if you tick the box,
because it is your work.  Reports go to a free file-drop service, so nobody
needs an account, a key or a token to send one - and there is no token of
any kind in the program.  A progress window shows it going.
[`docs/reporting-a-problem.md`](docs/reporting-a-problem.md) has the
details.

**Crashes.**  If the program falls over and survives, it offers to send the
report right away.  If it goes down for good, it writes the report next to
itself and offers to send it the next time it starts - only if you say so,
and you can read it first.  A drawing that took the program down as it
opened is not opened again on the next launch: it is set aside beside the
settings as `-would-not-open.hsk` and you start clean.  Nothing is thrown
away; it just stops being the thing that runs on startup.

## Installing

Grab the build for your machine from
**[Releases](../../releases/latest)** and run it.  There is no installer and
nothing to set up.

| File | For |
| --- | --- |
| `heckers-sketch.exe` | Windows |
| `heckers-sketch-linux` | Linux (`chmod +x` it first) |
| `checked/...` | the same two with range, overflow and heap checking on - slower, but they say what went wrong |

**It is portable.**  Settings, the draft and any scratch file live in the
same folder as the program, not in your home directory - put it on a stick
and it carries its work with it.  Only when the program's own folder cannot
be written to (installed under `/usr/bin`, say) does it fall back to the
usual per-user place.  The pictures and tickets the fitting wizard writes
go under `Heckers Sketch/fittings` in your home folder, where a mail program
and a file manager can find them.

**One copy at a time.**  Two would share the same draft and take turns
overwriting each other's work.  A second launch says so and stops.
`--multi` opens another anyway if you really want two.

Command line: `heckers-sketch [file.hsk] [--maximized] [--fullscreen]
[--size=WxH] [--multi]`, and `--help`.

## Building

Needs Lazarus with the `Printer4Lazarus` package (it ships with Lazarus).
Open `etchasketch.lpi` and build, or:

```sh
lazbuild etchasketch.lpi
```

`build.sh` does the plumbing: `./build.sh` is a development build,
`./build.sh ship` produces all four binaries above and packs them into one
zip, and `./build.sh github` runs both test suites, refuses to tag if
either is red, names the release notes, cuts the release and keeps the
debug symbols for it.

Developed on Linux; Windows builds are cross-compiled from the same tree.
Plain LCL throughout, so a macOS build should work too.

## Tests

```sh
./tests/run.sh          # 455 headless geometry, document and fitting checks
./tests/run-region.sh   #  76 planar-region checks
```

The region suite is worth a look on its own: squares cut in half, cuts that
stop partway and divide nothing, tic-tac-toe grids, holes, concave shapes,
vertices a nanometre apart, and timings at scale.  The main suite covers
length parsing, snapping, push/pull, tunnels that cross, arcs on free
planes, arrays, and every fitting the wizard builds.

## How it is put together

| Unit | Responsibility |
| --- | --- |
| `etchasketch.lpr` | program entry point, command line |
| `uSurface.pas` | a 32-bit BGRA raster surface - anti-aliased primitives from signed distance fields, blend modes, real alpha, damage tracking, text, PNG export |
| `uSkin.pas` | color themes and the chassis: panels, bezel, dials, line icons, measured and isometric grids |
| `uRegion.pas` | the planar region engine - segments in, faces and holes out.  Knows nothing about the document, the screen or the tools |
| `uWork.pas` | the PRO document - 3D geometry, length parsing and formatting, drawing scales, snapping, hit testing, rendering, the file format |
| `uBore.pas` | tunnels that cross: cutting one bore through another |
| `uFittings.pas` | the fitting builders - transition, elbow, tee, the end types, the field-measurement solve, the ticket text |
| `uTransition.pas` | the fitting wizard form; `uFieldElbow.pas` the field-measurement form |
| `uUnfold.pas`, `uFlatView.pas`, `uDxf.pas` | flat patterns: unfolding, showing, writing DXF |
| `uMailOut.pas` | handing files to the mail program - xdg-email on Linux, Simple MAPI on Windows |
| `uNet.pas`, `uUpdate.pas`, `uUpdateForm.pas` | fetching over HTTPS, the update check and install, its progress window |
| `uReport.pas`, `uSendForm.pas` | sending a report to the postbox, and its progress window |
| `uWhatsNew.pas` | the release notes dialog |
| `uSingle.pas`, `uPaths.pas` | one copy at a time; where the settings and the draft live |
| `uMain.pas` | the window - layout, both modes, tools, history, tabs |

Four things are worth knowing if you come back to this later.

**Everything is drawn into pixel buffers and blitted during paint events**
rather than poked onto a canvas from event handlers.  That is what makes the
anti-aliasing, the neon glow and the erase dissolve possible - and it is
also why it keeps working on GTK3, where drawing to `TImage.Canvas` outside
a paint handler silently does nothing.

**The screen is three layers** - paper, ink, and the composite you see.  The
ink carries its own alpha, so changing the theme re-papers underneath the
drawing and leaves the drawing alone.  Only the damaged rectangle is
recomposited.

**PRO geometry is stored in 3D from the start**, with the view as a
projection - the paper modes and the camera all read the same document.
Changing scale, zooming or switching views re-renders from the geometry,
so nothing is ever resampled.

**Faces come from the edges, every time.**  `uRegion.pas` welds coincident
vertices with a spatial hash, splits every segment at its crossings, groups
by plane, and walks the minimal cycles of the resulting half-edge graph.
Only the planes an edit actually touched are rebuilt, and results are cached
by signature.  A built fitting is the exception: its faces are solids, and
its open ends are taken as seen so they are never capped.

**Mouse motion is deliberately cheap**, which matters over VNC or on a
virtual display: the handler records the pointer position and returns, and
all snapping, hit-testing and repainting happens once per tick.

## Not there yet

There is a fuller list, with notes on what each one would take, in
[TODO.md](TODO.md).

* The field-sketch wizard: an isometric paper sketch with a few dimensions
  on it, turned into a built run.
* The flat pattern of a fitting with its ends on, and TDF corner pieces.
* The dimension tool has no radius or diameter mode yet.
* Orbiting a drawing full of fittings gets sluggish; there is a performance
  pass to do before anything is threaded.
* Two solids that interpenetrate sort wrongly - the painter's algorithm
  works on whole faces, so it will show a seam.
* Nothing imports.  Tracing a PDF or an SVG would be a lovely thing to have
  and is not here.

## License

**MIT** - see [LICENSE](LICENSE).  Do whatever you want with it: use it,
change it, ship it, sell it.  Keep the copyright line and that is the whole
of it.

Copyright (c) 2021-2026 Noella Stone and Tony Stone.
