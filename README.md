# Heckers Sketch

A simple 3D sketching program for Windows and Linux PCs, modeled on SketchUp.
It started out as my daughter's Etch A Sketch program.  Free Pascal / Lazarus, free to use,
MIT licensed.

**[Download the latest release](../../releases/latest)** - one file, no
installer.
**[Read the manual](https://tonystone31.github.io/noella-etch-a-sketch/)** -
every tool, command and key.

> **It is a desktop program.**  It needs a Windows or Linux computer with a
> mouse and a keyboard.  There is no phone or tablet version, and it will not
> run in a web browser.  There's no Mac version yet either -
> [help wanted](#mac-builders-wanted).

---

## The story

In October 2021 Noella Stone, seven years old, decided she wanted to write a
program.  She drew the screen, the two dials and the shake button on paper,
picked the colors, and told her dad what each part should do.  He typed while
she directed.  That toy is still in here, unchanged, one command away
(`/toy`).

Five years later I came back to it to see how far an AI could take it if I
asked for the tools I actually wanted.  It grew a second mode: a 3D drawing
board with real scales, snapping, push/pull and a tape measure that reads
feet and inches to the sixteenth.  I'm an HVAC technician and I do use it at
work for quick sketches.

## What it is, and what it isn't

It is a **sketching tool that gets the measurements right** - quick one-off
models and layouts where an honest dimension matters more than a pretty
drawing.

It is **not a CAD program** and isn't trying to compete with one, or with
SketchUp.  You would not produce a real set of drawings in it.  The plan is to
keep it accurate and useful without letting it get complicated.

SketchUp is the model for how the tools behave, on purpose: close a loop and
it becomes a face, push a face into a solid, snap to endpoints and midpoints,
type a length instead of dragging for it.  [`docs/sketchup/`](docs/sketchup/)
has our notes on their help pages, including where we differ and why.

## What's in it

The manual covers all of this properly.  The short version:

* **Drawing** - lines, rectangles, circles, arcs, offset, move, rotate,
  erase, text notes with leaders.  [Tools](https://tonystone31.github.io/noella-etch-a-sketch/)
* **Typed lengths** - `12'6"`, `6-8-15`, `3.5m`, `8x10`, and exact points
  like `[4,0,8]`.  [Typing measurements](https://tonystone31.github.io/noella-etch-a-sketch/typing.html)
* **Faces and solids** - faces come from the edges that close them;
  push/pull, drill and revolve turn them into solids.
  [Faces](https://tonystone31.github.io/noella-etch-a-sketch/faces.html) ·
  [Solids](https://tonystone31.github.io/noella-etch-a-sketch/solids.html)
* **Snapping and inference** - endpoints, midpoints, centers, crossings,
  axis locks.  [Snapping](https://tonystone31.github.io/noella-etch-a-sketch/snapping.html)
* **Measuring** - tape measure, guides, protractor, dimensions you can type
  over to resize what they measure.
  [Tape measure](https://tonystone31.github.io/noella-etch-a-sketch/tools/measure.html) ·
  [Dimensions](https://tonystone31.github.io/noella-etch-a-sketch/tools/dim.html)
* **Views** - free 3D with a view cube, plan with a height slice, and true
  isometric paper.  [Plan](https://tonystone31.github.io/noella-etch-a-sketch/plan.html) ·
  [View cube](https://tonystone31.github.io/noella-etch-a-sketch/cube.html) ·
  [Orbit](https://tonystone31.github.io/noella-etch-a-sketch/tools/orbit.html)
* **Printing to scale**, and exporting PNG, JPEG, animated GIF, SVG, DXF,
  STL and OpenSCAD.
  [Printing](https://tonystone31.github.io/noella-etch-a-sketch/printing.html) ·
  [Export](https://tonystone31.github.io/noella-etch-a-sketch/export.html)
* **Sheets** - several drawings in tabs, saved together in one `.hsk` file.
  Your work is also saved to a draft every few seconds.
  [Sheets](https://tonystone31.github.io/noella-etch-a-sketch/sheets.html)
* **A command bar** - type `/` and a searchable list of every command comes
  up, so there is nothing to memorize.
  [Commands](https://tonystone31.github.io/noella-etch-a-sketch/commands.html) ·
  [Keys](https://tonystone31.github.io/noella-etch-a-sketch/keys.html)

### The shop tools

The **SHOP** menu holds a few tools built for my own work in HVAC - duct
fittings, pipe spools and sheet metal flat patterns.  They're specific to my
trade, so they're kept out of the way; the rest of the program doesn't need
them.  The manual covers them if you're curious.

## Installing

Download the file for your computer from
**[Releases](../../releases/latest)** and run it.

| File | For |
| --- | --- |
| `heckers-sketch.exe` | Windows |
| `heckers-sketch-linux` | Linux (`chmod +x` it first) |
| `*-checked` | the same, with extra error checking - slower, but better crash reports |

It's portable: settings and the draft live next to the program, so it can
run from a USB stick.  It checks GitHub once a day for a newer version and
`/update` installs it.  `--help` lists the command-line switches.

## Problems and feedback

**Help → Report a problem** sends a screenshot, your note, and what the
program was doing.  Your drawing is only included if you tick the box.  No
account needed.  If it crashes, it offers to send the crash report.
[Reporting a problem](https://tonystone31.github.io/noella-etch-a-sketch/reporting.html)

## Developed with Claude

Nearly all of the 3D side was written by Anthropic's Claude, from my
descriptions of what the work needs.  I direct it, test it, and tell it what's
wrong; it writes the Pascal, builds it and runs the tests.  `TODO.md` is the
running log and the commit history is an honest record of how it was built.

---

## Building

Needs Lazarus, plus these packages:

* **BGRABitmap** and **BGRAControls** - install both from Lazarus's Online
  Package Manager.
* **[LazInk](https://github.com/TonyStone31/LazInk)** - clone it next to this
  folder (`../LazInk`), and the project finds it there.  It draws the
  release notes window.
* `Printer4Lazarus` ships with Lazarus.

```sh
lazbuild etchasketch.lpi      # or ./build.sh
```

`./build.sh ship` builds all four binaries into one zip, and
`./build.sh github` runs the tests and cuts a release.  Developed on Linux;
the Windows build is cross-compiled.

### Mac builders wanted

A macOS build has never been tried.  I don't have a Mac, and I don't have
much desire to get one, so if you do and you'd like to have a go, I'd love
the help.  It's Lazarus/LCL plus BGRABitmap, BGRAControls and LazInk, which
are all meant to work on macOS, and nearly all the drawing is done in the program's own pixel
buffers rather than through the platform, so there's a fair chance it builds
without much trouble.  Open an
issue or a pull request with how it went - even a list of what broke is
useful.

## Tests

```sh
./tests/run.sh          # headless geometry, document and fitting checks
./tests/run-region.sh   # the planar region engine
./tests/run-cmds.sh     # every command the list offers actually exists
./tests/run-drive.sh    # drives the real window in a nested X server
```

The last one needs Xephyr and
[LazHIDControl](https://github.com/TonyStone31/LazHIDControl) next to this
folder.  It's a smoke test that runs several scripts at once, and a few of
them run back to back in one program to catch problems that only show up
later in a session.

## Source layout

| Unit | What it does |
| --- | --- |
| `uWork.pas` | the 3D document: geometry, snapping, hit testing, rendering, file format |
| `uRegion.pas` | turns edges into faces and holes |
| `uSurface.pas` | the software rasterizer everything is drawn with |
| `uMain.pas` | the window, the tools, both modes |
| `uFittings.pas`, `uTransition.pas` | fitting builders and the fitting wizard |
| `uPipe.pas`, `uSpool.pas` | the pipe spool scratchpad |
| `uUnfold.pas`, `uDxf.pas` | flat patterns and DXF |
| `uCube.pas` | the view cube |
| `uUpdate.pas`, `uReport.pas` | updates and bug reports |

Longer design notes are in [`docs/`](docs/), and what's still to do is in
[`TODO.md`](TODO.md).

## License

**MIT** - see [LICENSE](LICENSE).

Copyright (c) 2021-2026 Noella Stone and Tony Stone.
