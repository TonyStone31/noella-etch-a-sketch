# Heckers Sketch

An Etch A Sketch that grew up. Free Pascal / Lazarus, no third-party
dependencies.

## The story

On **19 October 2021**, Noella Hazel Stone was seven years old and decided she
wanted to write a program. She drew the screen, the two dials and the shake
button on paper, chose the colours, and told her dad what each part was
supposed to do. He typed while she directed.

The program now has two personalities. The layout is still hers.

---

## TOY

The program she designed.

* Two dials you actually grab and turn — left moves across, right moves up and
  down, exactly like the toy. Arrow keys work too, with **Shift** to sprint
  and **Ctrl** to creep a pixel at a time.
* **Five pen styles** — Classic, Neon (a glowing tube of light), Rainbow,
  Sparkle, Chalk.
* **Kaleidoscope** — repeat every stroke 1, 2, 4, 6 or 8 times around the
  centre, with an optional mirror. Scribbling turns into a mandala.
* **Auto-draw** — the machine doodles a spirograph, rose curve or lissajous
  figure. Try it with rainbow ink and 8-fold symmetry.
* **Shake to erase** dissolves the drawing into aluminium powder.

## PRO

The same idea taken seriously: a small drawing board for quick, honest
sketches. It is not a CAD program and does not want to be. It exists so you
can rough out two things and get a **real measurement** between them, down to
the sixteenth of an inch.

* **Draw by typing.** Click a start point, then type `12'6"` and press an
  arrow. Or press an arrow to set the direction first and then type. It
  accepts `12'6"`, `12-6`, `12 6`, `6 1/2"`, `150"`, `3.5m`, `350cm`.
* **A command bar that tells you what it wants next**, so there is nothing to
  memorise. Type a number and it is a length; start with `/` and it is a
  command — `/iso`, `/3d`, `/plan`, `/fit`, `/scale 1/4`, `/units`, `/new`.
* **Tools** — point, line (chained), arc, circle, push/pull, text notes,
  eraser, and a tape measure that reads out distance plus dX/dY/dZ and can be
  kept as a permanent dimension. Clicking the lit tool puts it away; Esc
  backs out one step at a time.
* **Arcs join two loose ends.** Pick the two points, pull the middle out. No
  trimming required.
* **Snapping and inference** — endpoints, midpoints and arc centres beat the
  grid, each with its own marker at the cursor (square, triangle, circle).
  **SNAP OFF turns all of it off** — grid, points and guides — and holding
  **Alt** suspends it while you reach past a sticky snap. Where two lines
  cross, the crossing itself snaps, and each line picks up fresh midpoints
  for the pieces the crossing divided it into.
  A guide only appears when the point it lines up with is off in exactly one
  direction, so guides are always parallel to an axis.
  When the cursor lines up with a point somewhere else on the drawing, it is
  pulled onto that line and a dotted guide is drawn back to whatever it lined
  up with — the same idea as SketchUp's inference, or Lazarus's alignment
  hints. Arrow keys nudge one snap step; **Shift+arrow** hops to the next
  real point, so the whole thing works from a keyboard or a touch screen.
* **The eraser highlights what it is about to delete** in red before you
  click.
* **True scale.** 1/16", 1/8", 1/4", 1/2" and 1" = 1'-0", or 1:200 through
  1:10 in metric. Printing re-renders the page from the geometry at the
  printer's own resolution, so a quarter inch on the paper really is a foot.
* **Plan, isometric and 3D.** `V` cycles them. ISO is the standard 30°
  projection — +X down-right, +Y down-left, +Z straight up — with dimensions
  labelled at true length, which is how a pipe spool drawing is laid out. 3D
  is a free orthographic view; middle-drag to orbit.
* **Push/pull.** Close a loop of lines and it becomes a face, the way it does
  in SketchUp. Pick the face, type how far, and it lifts into a shaded solid
  with its sides walled in. Good enough to size up a roof curb in about ten
  seconds.
* **Tabs** — as many sheets as you like, each with its own scale, units and
  view. All of them save into one file.
* **Its own file format.** Drawings save as `.hsk` — plain text, one line per
  entity, so it stays readable and diffable and old files keep opening. PNG
  and **SVG** are exports, not saves; the SVG is real vector output with the
  dimensions as text, so it opens in Inkscape or a CAD package.
  `heckers-sketch drawing.hsk` opens one straight from the shell.
* **Zoom and pan** are independent of the drawing scale, so zooming in to
  place something does not change what prints.
* The dials are off by default over here, but the button on the SCALE row
  brings them back — they are good for nudging.

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
| T | next theme |
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

**PRO**

| Key | Action |
| --- | --- |
| Q L A C P N E M | point, line, arc, circle, push/pull, note, erase, measure |
| Space / Enter | place a point, or commit what you typed |
| Arrow keys | set the direction while drawing; otherwise nudge the cursor |
| PgUp / PgDn | the ±Y axis in isometric |
| Shift+arrow | hop to the next point on the drawing |
| digits, `'` `"` `-` | type a length into the command bar |
| `/` | start a typed command (`/iso`, `/fit`, `/scale 1/4`…) |
| Esc | back out: clear what you typed, then the operation, then the tool |
| Alt (held) | suspend snapping |
| V | cycle plan → isometric → 3D |
| I | isometric / plan |
| K | cycle the working plane (XY / XZ / YZ) |
| F | zoom to fit |
| O | put 0,0 under the cursor |
| D | dimension labels on/off |
| U | feet-and-inches / metric |
| Tab | next tool |
| Ctrl+T / Ctrl+W / Ctrl+Tab | new sheet / close sheet / next sheet |
| Right-drag | pan;  wheel = zoom |
| Middle-drag | orbit, in the 3D view |

---

## Running it on a remote or virtual display

It runs unchanged on a virtual X server - Xvfb, TigerVNC, KasmVNC - so it can
be shown on a machine with no display of its own.

Mouse motion is deliberately cheap: the handler records the pointer position
and returns, and all snapping, hit-testing and repainting happens once per
16 ms tick. That matters on a virtual display, where every repaint has to be
encoded and shipped to the client: a motion handler that painted would take
tens of milliseconds, and because GDK holds back the next motion event until
the handler returns, the event stream would collapse to a few moves a second.
Hover coordinates and click-drag drawing would stop tracking the pointer.

## Building

Needs Lazarus with the `Printer4Lazarus` package (ships with Lazarus).
Open `etchasketch.lpi` and build, or:

```sh
lazbuild etchasketch.lpi
```

Developed on Linux with the GTK3 widgetset. Plain LCL throughout, so Windows
and macOS builds should work too.

## How it is put together

| Unit | Responsibility |
| --- | --- |
| `etchasketch.lpr` | program entry point |
| `uSurface.pas` | a 32-bit BGRA raster surface — anti-aliased primitives from signed distance fields, blend modes, real alpha, damage tracking, text, PNG export |
| `uSkin.pas` | colour themes and the chassis: panels, bezel, dials, line icons, measured and isometric grids |
| `uWork.pas` | the PRO document — 3D geometry, length parsing and formatting, drawing scales, snapping, hit testing, rendering |
| `uMain.pas` | the window — layout, both modes, tools, history, tabs |

Three things are worth knowing if you come back to this later:

**Everything is drawn into pixel buffers and blitted during paint events**
rather than poked onto a canvas from event handlers. That is what makes the
anti-aliasing, the neon glow and the erase dissolve possible — and it is also
why it keeps working on GTK3, where drawing to `TImage.Canvas` outside a paint
handler silently does nothing.

**The screen is three layers** — paper, ink, and the composite you see. The
ink carries its own alpha, so changing the theme re-papers underneath the
drawing and leaves the drawing alone. Only the damaged rectangle is
recomposited, so this costs nothing while you draw.

**PRO geometry is stored in 3D from the start**, with the view as a
projection — PLAN, ISO and a free orbit camera all read the same document.
Changing scale, zooming or switching views re-renders from the geometry, so
nothing is ever resampled.

Solids are a thin layer on top of that: a closed loop of coplanar lines
becomes a face, push/pull moves the face along its own normal and walls in
the sides, and faces are drawn after the edges, back to front, with their
backs culled. That is enough for boxes and extrusions. It is deliberately not
a solid modeller — there are no booleans, no intersections and no face
merging, and the painter's ordering will show its seams if two solids
interpenetrate.

## Not there yet

There is a fuller list, with notes on what each one would take, in
[TODO.md](TODO.md).

* No **move** tool — you can draw and erase, but not drag something that is
  already down.
* A face is only made when a run of lines closes on **itself**. Drawing a
  line across an existing shape does not split its face into two, so you
  cannot yet push/pull the smaller regions that line creates. That needs
  proper planar region finding — split every edge at its crossings, build the
  graph, walk the minimal cycles — and it is the next thing worth doing.
* Push/pull only understands closed loops of coplanar lines. There are no
  booleans, no intersections and no face merging, and the painter's ordering
  will show its seams if two solids interpenetrate.
* Nothing imports. Tracing a PDF or an SVG would be a lovely thing to have
  and is not here.

## Licence

MIT — see [LICENSE](LICENSE).

Copyright (c) 2021-2026 Noella Stone.
