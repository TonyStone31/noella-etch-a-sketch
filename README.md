# Heckers Sketch

A kid's Etch A Sketch that turned into a measuring tool I use on job sites.
Free Pascal / Lazarus, no third-party dependencies, free forever.

**[Download the latest release](../../releases/latest)** — Windows and Linux,
no installer, single file.

---

## The story

**19 October 2021.** Noella Hazel Stone was seven years old and decided she
wanted to write a program. She drew the screen, the two dials and the shake
button on paper, picked the colors, and told her dad what each part was
supposed to do. He typed while she directed.

That program is still here. The layout is hers, unchanged, and it is still the
first thing the app opens into.

**Five years later** I came back to it, mostly for the fun of seeing how far an
AI could take a seven-year-old's toy if I asked it to build the tools I
actually wanted. The answer turned out to be further than I expected. The dials
and the shake button are still there; next to them now is a second mode with a
drawing board, real drawing scales, snapping and inference, push/pull, and a
tape measure that reads out feet and inches down to the sixteenth.

Somewhere in there her toy stopped being a toy. I use it at work.

## What it is for

I work in HVAC and construction. A good part of what I need to draw in a day is
a duct transition, a pipe run, a curb, a piece of sheet metal — quick one-off
ideas where the only thing that truly matters is getting an honest measurement
out the other end, and getting it fast, standing in the field.

SketchUp does that job well. It also costs hundreds of dollars a year, and I
don't need most of what I'd be paying for.

So Heckers Sketch is modeled on SketchUp deliberately. I know the SketchUp
basics and I know how to build a useful model in it, so I wanted that same
simplicity and those same tools here: close a loop and it becomes a face, click
a face and push it, snap to endpoints and midpoints, type a length instead of
dragging for it. [`docs/sketchup/`](docs/sketchup/) holds sixteen of their help
pages, read properly and written up, each with a note on what we have, what we
don't, and where we differ on purpose. When there is an argument about how
something ought to behave, that is what we argue against.

It is **not** a modeler and is not trying to become one. You would not produce a
real set of drawings in it. It is for quick, scaled, honest sketches — the
mockup you would otherwise open SketchUp to do — and it is given away free.

## Developed with Claude

This is an AI-built project and there is no reason to be coy about it. Nearly
all of the PRO code was written by Anthropic's **Claude**, working from my
descriptions of what the work actually needs, and checked against the SketchUp
notes in `docs/sketchup/`. I direct it, I use the result on real jobs, and I
tell it what is wrong with it; it writes the Pascal, builds it, and runs the
tests.

That shows in how the repository is laid out. The SketchUp reference notes, the
headless test suites, and a `TODO.md` written as a running log all exist so the
work can be picked back up cold. If you are curious what building something
genuinely useful this way looks like, the commit history is an honest record of
it.

---

## TOY

The program Noella designed.

* **Two dials you actually grab and turn** — left moves across, right moves up
  and down, exactly like the toy. Arrow keys work too, with **Shift** to sprint
  and **Ctrl** to creep a pixel at a time.
* **Five pen styles** — Classic, Neon (a glowing tube of light), Rainbow,
  Sparkle, Chalk.
* **Kaleidoscope** — repeat every stroke 1, 2, 4, 6 or 8 times around the
  center, with an optional mirror. Scribbling turns into a mandala.
* **Auto-draw** — the machine doodles a spirograph, rose curve or lissajous
  figure. Try it with rainbow ink and 8-fold symmetry.
* **Shake to erase** dissolves the drawing into aluminum powder.

## PRO

The same idea taken seriously.

**Drawing**

* **Draw by typing.** Click a start point, then type `12'6"` and press an
  arrow — or press an arrow to set the direction first, then type. It takes
  `12'6"`, `12-6`, `12 6`, `6 1/2"`, `150"`, `3.5m`, `350cm`.
* **A command bar that says what it wants next**, so there is nothing to
  memorize. Type a number and it is a length; start with `/` and it is a
  command — `/iso`, `/3d`, `/plan`, `/fit`, `/scale 1/4`, `/units`, `/new`.
* **Tools** — select, line (chained), rectangle, arc, circle, push/pull,
  offset, move, tape measure, dimension, text note, eraser. Clicking the lit
  tool puts it away; **Esc** backs out one step at a time.
* **Offset** for a wall thickness. Click a face, move in or out, and click —
  or type `2"`. Every edge shifts sideways and the shifted edges extend to
  meet again, so the spacing is exact at the corners too, which is the whole
  point when the number is going to a shop.
* **Notes with leader lines.** Click what the note is about, type it —
  **Shift+Enter** for another line — move away and press Enter. You get a
  boxed note on the end of a line pointing at the thing. Leave the cursor
  where you clicked and it is a plain label instead. On an isometric this is
  most of the drawing: `8" SCH 40` floating in space is a riddle, and the
  same words on the end of a leader are an instruction.
* **Lean on the button to throw away what you are drawing.** You know you
  have made a mess the instant the button goes down — so keep leaning on it.
  The shape stops being elastic: it bows, goes bold and red, asks **made a
  mess? keep holding**, and comes apart. Nothing is drawn. Works on lines,
  rectangles, circles and arcs; on a run of lines it lets go of the run
  instead. About a second and a half, deliberately, so there is time to read
  it and change your mind — let go early, or move the mouse, and it was just
  an ordinary click. No switching to the eraser to undo something you had not
  finished making.
* **Double-click finishes a run of lines.** A line carries on from the point
  you just put down, which is what you want nine times in ten; a double-click
  lets go of it without placing anything. Esc does the same. (SketchUp has no
  mouse way to do this — there a second click just drops another point — and
  this is one of the few places worth being deliberately unlike it.)
* **Arcs join two loose ends.** Pick the two points, pull the middle out. No
  trimming required.
* **Select and move.** Click picks; **Ctrl** adds, **Shift** toggles,
  **Ctrl+Shift** removes. Drag a box — right-to-left takes anything it touches,
  left-to-right only what fits wholly inside, which is SketchUp's rule, and the
  dashed or solid box says which is in force. Moving a corner **stretches** what
  is attached to it rather than tearing it off. **Ctrl** while moving copies.

**Measuring**

* **The shape you are about to draw is drawn solid and heavy**, in the color
  of the axis it is locked to, the way SketchUp does it. A dashed hairline
  reads as faint and provisional when it is in fact the thing you are about
  to commit.
* **True scale.** 1/16", 1/8", 1/4", 1/2" and 1" = 1'-0", or 1:200 through 1:10
  in metric. Printing re-renders the page from the geometry at the printer's own
  resolution, so a quarter inch on the paper really is a foot.
* **The tape measure** reads out distance plus dX/dY/dZ at the cursor as you
  pull it, and can drop a **guide line** you then snap to — same as SketchUp.
* **Dimensions you place yourself**, with the extension lines snapped square to
  an axis so they read like a drawing instead of a sketch.
* **Right-click a dimension to write over its figure** — a nominal size, a cut
  length that allows for a fitting, `FIELD VERIFY`. It types into the command
  bar like everything else; Enter commits, Esc leaves it alone, and clearing
  it hands the dimension back to the measured length. The measurement
  underneath never changes, so the drawing still knows what it really is —
  and the written figure goes out in the SVG export too.

**Geometry**

* **Faces are derived, not stored.** Every edge is split at its crossings, the
  coplanar ones are grouped, and the smallest closed loops are walked out of the
  resulting graph. Draw a line across a square and you get two faces you can
  push independently; erase it and you get the square back. Islands inside a
  face become holes.
* **Push/pull.** Pick a face, type how far, and it lifts into a shaded solid
  with its sides walled in — including circles. Anything drawn on the face rides
  along with it. Good enough to size up a roof curb in about ten seconds.
* **Shake the mouse to say which way you meant it.** Drawing in mid air and
  the shape keeps standing up when you wanted it flat? Jerk the mouse side to
  side and it lies down; jerk it up and down and it stands up. The plane
  latches, so it is an instruction rather than a hint, and **Esc** hands it
  back to following the faces. It needs four proper reversals inside about
  three quarters of a second, which is not something an ordinary hand moving
  to a point ever does.
* **Snapping and inference** — endpoints, midpoints and arc centers beat the
  grid, each with its own marker at the cursor. Where two lines cross, the
  crossing snaps, and each line picks up fresh midpoints for the pieces it was
  divided into. When the cursor lines up with a point elsewhere in the drawing
  it is pulled onto that line and a dotted guide is drawn back to whatever it
  lined up with. **SNAP OFF** kills all of it; holding **Alt** suspends it while
  you reach past a sticky snap.
* **Profiles.** The silhouette of a shape is drawn heavier than the edges inside
  it, and the facets of a curved surface are softened away, so a pushed circle
  reads as a pipe instead of a 24-sided prism. Line weight is a property of the
  drawing, not of individual edges — SketchUp's rule, and the right one.

**Views and files**

* **Plan, isometric and 3D.** `V` cycles them. ISO is the standard 30°
  projection — +X down-right, +Y down-left, +Z straight up — with dimensions
  labeled at true length, which is how a pipe spool drawing is laid out. The
  isometric grid is real iso paper. 3D is a free orthographic view;
  middle-drag to orbit.
* **Tabs** — as many sheets as you like, each with its own scale, units and
  view. All of them save into one file.
* **Its own file format.** Drawings save as `.hsk` — plain text, one line per
  entity, so it stays readable and diffable and old files keep opening. PNG and
  **SVG** are exports, not saves; the SVG is real vector output with the
  dimensions as text, so it opens in Inkscape or a CAD package.
  `heckers-sketch drawing.hsk` opens one straight from the shell.
* **Nothing is ever lost.** A couple of seconds after you stop drawing, the
  whole session — every sheet — is written to a draft beside the settings, and
  the next launch picks it straight back up, named or not. Pull the plug and
  it is still there. `Ctrl+S` gives it a real name when you want one; a file
  named on the command line always wins over the draft.
* **Delete asks** before clearing a sheet in PRO. It deletes the selection if
  there is one, and otherwise wants a yes — it sits next to the key that
  deletes what you picked, and there used to be nothing between it and losing
  the lot.
* **Zoom and pan are independent of the drawing scale**, so zooming in to place
  something does not change what prints.

---

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
| W | swap TOY ⇄ PRO |
| F1 | about |
| `[` `]` | thinner / thicker line |

**TOY**

| Key | Action |
| --- | --- |
| Arrow keys | draw |
| Shift / Ctrl | fast / slow |
| Space or Alt | lift the pen |
| 1 … 5 | pen style |
| S | cycle the kaleidoscope |
| M | mirror |
| A | auto-draw |
| T | next theme |

**PRO**

| Key | Action |
| --- | --- |
| Q L R A C P F M T D N E O | select, line, rect, arc, circle, push/pull, offset, move, tape, dimension, note, erase, orbit |
| Tab | next tool |
| Space / Enter | place a point, or commit what you typed |
| Double-click | finish a run of lines (the first click still places a point) |
| Hold the left button | snap the line off without placing anything |
| Shift+Enter | another line in a note |
| Arrow keys | set the direction while drawing; otherwise nudge the cursor |
| Shift+arrow | hop to the next point on the drawing |
| PgUp / PgDn | the ±Y axis in isometric |
| digits, `'` `"` `-` | type a length into the command bar |
| `/` | start a typed command (`/iso`, `/fit`, `/scale 1/4`…) |
| Esc | back out: clear what you typed, then the operation, then the tool |
| Alt (held) | suspend snapping |
| V | cycle plan → isometric → 3D |
| I | isometric / plan |
| K | cycle the working plane (XY / XZ / YZ) |
| Shift+F | zoom to fit |
| U | feet-and-inches / metric |
| Ctrl+T / Ctrl+W / Ctrl+Tab | new sheet / close sheet / next sheet |
| Right-click a dimension | write over its figure |
| Right-drag | pan;  wheel = zoom |
| Middle-drag | orbit — from any view, with any tool in hand, mid-line |

---

## Keeping it up to date

It looks at the GitHub releases page **once a day** and says in the status bar
if there is a newer build. `/update` fetches it, checks it against the
checksums published with the release, puts it in place and starts again —
your drawing is kept and comes straight back, which is what makes replacing
the program underneath you a reasonable thing to do at all.

If you would rather it did not: **`/update never`** and it stops looking.
`/update` still works whenever you ask it to, and `/update always` turns the
daily look back on.

What it sends: nothing. It asks GitHub one question — what is the newest
release — over the same public URL your browser would use, and no part of the
request says anything about you, your machine or your drawing. It will not
touch a copy running from its own source folder, because that is somebody's
working build.

If it crashes, the next launch offers to report it: your browser opens a
GitHub issue **filled in but not sent**, so you can read exactly what is in it
and add what you were doing. Say no and the file stays put with its name on
screen. There is no account, key or token anywhere in the program — a token
with write access, in a binary given to strangers, is a token given to
strangers.

## Installing

Grab the build for your machine from
**[Releases](../../releases/latest)** and run it. There is no installer and
nothing to set up.

| File | For |
| --- | --- |
| `heckers-sketch.exe` | Windows |
| `heckers-sketch-linux` | Linux (`chmod +x` it first) |
| `checked/…` | the same two with range, overflow and heap checking on — slower, but they say what went wrong |

Command line: `heckers-sketch [file.hsk] [--maximized] [--fullscreen]
[--size=WxH]`, and `--help`.

## Building

Needs Lazarus with the `Printer4Lazarus` package (it ships with Lazarus).
Open `etchasketch.lpi` and build, or:

```sh
lazbuild etchasketch.lpi
```

`build.sh` does the release plumbing — `./build.sh ship` produces all four
binaries above and packs them into one zip.

Developed on Linux with the GTK3 widgetset; Windows builds are cross-compiled
from the same tree. Plain LCL throughout, so a macOS build should work too.

## Tests

```sh
./tests/run.sh          # 135 headless geometry and document checks
./tests/run-region.sh   #  76 planar-region checks
```

The region suite is worth a look on its own: squares cut in half, cuts that stop
partway and divide nothing, tic-tac-toe grids, holes, concave shapes, vertices a
nanometre apart, and timings at scale.

## How it is put together

| Unit | Responsibility |
| --- | --- |
| `etchasketch.lpr` | program entry point |
| `uSurface.pas` | a 32-bit BGRA raster surface — anti-aliased primitives from signed distance fields, blend modes, real alpha, damage tracking, text, PNG export |
| `uSkin.pas` | color themes and the chassis: panels, bezel, dials, line icons, measured and isometric grids |
| `uRegion.pas` | the planar region engine — segments in, faces and holes out. Knows nothing about the document, the screen or the tools |
| `uWork.pas` | the PRO document — 3D geometry, length parsing and formatting, drawing scales, snapping, hit testing, rendering |
| `uMain.pas` | the window — layout, both modes, tools, history, tabs |

Four things are worth knowing if you come back to this later.

**Everything is drawn into pixel buffers and blitted during paint events**
rather than poked onto a canvas from event handlers. That is what makes the
anti-aliasing, the neon glow and the erase dissolve possible — and it is also
why it keeps working on GTK3, where drawing to `TImage.Canvas` outside a paint
handler silently does nothing.

**The screen is three layers** — paper, ink, and the composite you see. The ink
carries its own alpha, so changing the theme re-papers underneath the drawing
and leaves the drawing alone. Only the damaged rectangle is recomposited, so
this costs nothing while you draw.

**PRO geometry is stored in 3D from the start**, with the view as a projection —
PLAN, ISO and the free orbit camera all read the same document. Changing scale,
zooming or switching views re-renders from the geometry, so nothing is ever
resampled.

**Faces come from the edges, every time.** `uRegion.pas` welds coincident
vertices with a spatial hash, splits every segment at its crossings, groups by
plane, and walks the minimal cycles of the resulting half-edge graph — arriving
along a dart, it leaves by the dart immediately clockwise of the way it came.
The cycle wound the wrong way is the infinite outer face and is thrown away.
Only the planes an edit actually touched are rebuilt, and results are cached by
signature, which is what keeps a full rebuild in the low milliseconds.

**Mouse motion is deliberately cheap**, which matters when this is running over
VNC or on a virtual display: the handler records the pointer position and
returns, and all snapping, hit-testing and repainting happens once per 16 ms
tick. A motion handler that painted would take tens of milliseconds, and since
GDK holds back the next motion event until the handler returns, the event stream
would collapse to a few moves a second.

## Not there yet

There is a fuller list, with notes on what each one would take, in
[TODO.md](TODO.md).

* No **offset** tool — duct wall thickness and flanges want it.
* No **rotate** tool. Forty-fives are the job.
* The dimension tool has no radius or diameter mode, and you cannot yet drag an
  extension line or type over the text.
* Back faces are not shown in their own color the way SketchUp shows them pale
  blue, which is how you spot a solid built inside out.
* No copy arrays (`*6`, `/3` after a Ctrl-move).
* Two solids that interpenetrate sort wrongly — the painter's algorithm works on
  whole faces, so it will show a seam.
* Nothing imports. Tracing a PDF or an SVG would be a lovely thing to have and
  is not here.

## License

**MIT** — see [LICENSE](LICENSE). Do whatever you want with it: use it, change
it, ship it, sell it. Keep the copyright line and that is the whole of it.

Copyright © 2021–2026 Noella Stone and Tony Stone.
