# Heckers Sketch next to the others

Written 19 September 2026.  Everything about *us* comes from the program in
this repository.  Everything about anybody else comes from their own website
or repository on that date, is linked so you can check it, and will go out
of date - if you find something wrong here, it is a mistake rather than a
sales pitch, and a pull request fixing it is welcome.

A dash means we could not establish it from their own documentation, not
that the answer is no.

**Where we are honest about losing, we lose.**  A comparison table that has
a tick in every one of our rows is an advertisement, and nobody believes
one.  The last section is the list of things the others do that we do not.

## The short version

If you draw buildings for a living, use [Revit][revit] or
[FreeCAD][freecad].  If you need parametric parts with a history tree, use
[FreeCAD][freecad] or [SolveSpace][solvespace].  If you want 2D drafting
with an AutoCAD shape to it, use [LibreCAD][librecad] or QCAD.

Use this if you want to **rough something out at a real scale, fast, on the
machine in front of you** - a duct transition, a pipe run, a shed, a
bracket, the shape of a room - and get a printed drawing at true scale or a
DXF out the other end.  And particularly if that machine runs Linux, because
the program most people would reach for does not.

## The table

| | Heckers Sketch | [SketchUp][sketchup] | [FreeCAD][freecad] | [LibreCAD][librecad] | [SolveSpace][solvespace] | [Sweet Home 3D][sh3d] | [Revit][revit] |
|---|---|---|---|---|---|---|---|
| **Native Linux build** | yes | **no** | yes | yes | yes | yes | **no** |
| Windows / macOS | Windows; macOS unbuilt | yes | yes | yes | yes | yes | Windows only |
| **Price** | free | $129-$859 a year | free | free | free | free | subscription, thousands a year |
| **Licence** | MIT | proprietary | open source | GPLv2 | GPLv3 | GPL | proprietary |
| Works with no account, no internet | yes | sign-in, it is a subscription | yes | yes | yes | yes | account required |
| Install size (rough) | one file, ~9 MB | hundreds of MB | hundreds of MB | tens of MB | tens of MB | needs Java | gigabytes |
| **3D by push/pull** | yes | yes | via workbenches | **2D only** | parametric extrude | furniture, not modelling | yes |
| Parametric history | **no** | no (groups/components) | yes | no | yes | no | yes |
| Type an exact measurement while drawing | yes | yes | yes | yes | yes | partly | yes |
| Prints at true scale | yes | yes | yes | yes | yes | yes | yes |
| DXF out | yes (view and model) | subscribers | yes | native | yes | limited | yes |
| STL out | yes | yes | yes | no | yes | via plugin | limited |
| SVG / OpenSCAD out | yes | no | SVG yes | SVG yes | no | no | no |
| **Sheet-metal unfolding** | yes, built in | extension | workbench | no | no | no | no |
| **Duct fittings from measurements** | **yes, built in** | extension | no | no | no | no | families |
| **Pipe spool from legs** | **yes, built in** | extension | workbench | no | no | no | yes |
| Animation export (GIF / WebP) | **yes, built in** | scenes to video | - | no | no | video | - |
| Groups / components / blocks | **not yet** | yes | yes | yes | yes | yes | yes |
| Plugin or scripting API | **no** | Ruby, large ecosystem | Python, large | scripting | Python | huge | Dynamo, huge |
| Photo-real rendering | no | via extensions | workbench | no | no | yes | yes |
| Touch and pen | yes | yes | - | - | - | - | - |

[sketchup]: https://sketchup.trimble.com/en/plans-and-pricing
[freecad]: https://www.freecad.org/
[librecad]: https://librecad.org/
[solvespace]: https://solvespace.com/
[sh3d]: https://www.sweethome3d.com/
[revit]: https://www.autodesk.com/products/revit/overview

Two more worth knowing about, both close to us in spirit:

* **[ZCAD](https://github.com/zamtmn/zcad)** - a CAD program written in Free
  Pascal, like this one, open source and alive.  If you want Pascal CAD with
  a drafting shape rather than a sketching one, look there.
* **[OpenSCAD](https://openscad.org/)** - modelling by writing code.  The
  opposite approach to ours on purpose, and we export to it, so a shape
  roughed out here can be taken there and made parametric.

## Where the others beat us

Not hedged, because the list is short enough to say plainly and long enough
to matter.

* **Groups and components.**  Everything in a drawing here is loose
  geometry.  Every other program on that table lets you name a thing, reuse
  it, and edit every copy at once.  This is the biggest gap and it has a
  plan of its own - `docs/groupplan.md`.
* **Parametric history.**  FreeCAD, SolveSpace and Revit remember how a
  shape was made and let you go back and change a number.  We remember the
  shape.
* **A plugin API.**  SketchUp's Ruby ecosystem is thirty years of other
  people's work, and it is the honest reason SketchUp is hard to leave.
* **Photo-real rendering**, **BIM**, **assemblies and constraints**, **FEA
  and CAM** - none of it, and none of it planned.
* **macOS.**  The code should build; nobody has built it.
* **Age.**  They have all been shipping for years and have had their corners
  knocked off by thousands of people.  This program is not yet a year old
  in its PRO form and the bug reports are still finding real faults.

## Where we beat them, and why it is not an accident

* **It is one file.**  Copy it onto a stick and run it.  No installer, no
  runtime, no account, no first-run tour, nothing phoning home.  Nine
  megabytes on Windows, and the manual is inside the program.
* **It runs on Linux natively** - the thing SketchUp has never done - while
  working the way somebody coming from SketchUp expects: the same keys, the
  same measurement typing, the same push/pull.  `docs/sketchup/` is sixteen
  of their help pages read properly and written up, and where we differ it
  is on purpose and written down.
* **The trade work is in the box.**  Duct fittings from the measurements you
  took, a pipe spool leg by leg, and the flat pattern to cut - all built in
  rather than bought as an extension.  That is the job this program was
  written for.
* **It exports its own animations** - lossless WebP, and the encoder is
  Pascal inside the program, so nothing is installed to make one.
* **MIT.**  Fork it, sell it, mount it on a CNC machine, put it on a
  touchscreen beside a 3D printer.  We would rather that happened than not.
