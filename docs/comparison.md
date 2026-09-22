# Heckers Sketch next to the others

Written 19 September 2026, rewritten 20 September 2026 with more programs
and more rows.  Everything about *us* comes from the program in this
repository.  Everything about anybody else comes from their own website,
manual or repository on that date, is linked so you can check it, and will
go out of date - if you find something wrong here, it is a mistake rather
than a sales pitch, and a pull request fixing it is welcome.

A dash means we could not establish it from their own material, not that
the answer is no.  "Planned" in our column means it is written down in
[`TODO.md`](../TODO.md) and not built; it is not a promise of a date.

**Where we are honest about losing, we lose.**  A comparison table that has
a tick in every one of our rows is an advertisement, and nobody believes
one.  The longest section of this page is the list of things the others do
that we do not.

## The short version

| If you want | Use |
|---|---|
| A building to build from, with schedules and sections | [Revit][revit], or [FreeCAD][freecad]'s BIM workbench |
| A part whose numbers you can go back and change | [FreeCAD][freecad], [SolveSpace][solvespace], [Dune 3D][dune3d], [Fusion][fusion], [Onshape][onshape] |
| Flat 2D drafting with an AutoCAD shape to it - layers, blocks, linetypes, DXF in and out | [LibreCAD][librecad], [QCAD][qcad], [ZCAD][zcad] |
| Electrical drawings that know what a cable is and write the cable list for you | [ZCAD][zcad]'s electrical build - see below |
| Rounded, filleted, product-shaped solids without a history tree, on Linux | [Plasticity][plasticity] |
| To model with a pencil on a tablet | [Shapr3D][shapr3d] |
| A child's first 3D print, in a browser | [Tinkercad][tinkercad] |
| Characters, sculpting, animation, pictures | [Blender][blender] |
| To furnish a house and walk round it | [Sweet Home 3D][sh3d] |

Use this if you want to **rough something out at a real scale, fast, on the
machine in front of you** - a duct transition, a pipe run, a shed, a
bracket, the shape of a room - and get a printed drawing at true scale, a
flat pattern, an STL or a DXF out the other end.  And particularly if that
machine runs Linux, because the program most people would reach for does
not.

## Next to the ones you model in by pushing and pulling

These are the programs somebody choosing this one is most likely to be
choosing between.

| | Heckers Sketch | [SketchUp][sketchup] | [Plasticity][plasticity] | [Shapr3D][shapr3d] | [Tinkercad][tinkercad] | [Blender][blender] |
|---|---|---|---|---|---|---|
| **Native Linux build** | yes | **no** | yes (.deb, .rpm) | **no** | browser | yes |
| Windows / macOS / tablet | Windows; macOS unbuilt | Windows, macOS, web, iPad | Windows, macOS | Windows, macOS, iPad, Vision | browser, iPad app | Windows, macOS |
| **Price** | free | Go $129, Pro $399, Studio $859 a year; a cut-down free web version | $175 Indie, $299 Studio, once | free plan of 2 projects; Pro $299 a year | free | free |
| **License** | MIT | proprietary | proprietary | proprietary | proprietary | GPL |
| No account, no internet | yes | sign-in | runs offline; the trial wants an account | sign up to download; works offline | account and internet | yes |
| Download | one file, 11 MB (Windows), 21 MB (Linux) | hundreds of MB | ~250-330 MB | 1.5 GB on iPad | nothing | ~350 MB |
| **How you model** | push/pull on faces drawn from edges | the same - it is theirs | direct editing of real solids (Parasolid) | direct or history, real solids (Parasolid) | ready-made shapes added and subtracted | meshes |
| Type an exact size while drawing | yes | yes | yes | yes | yes, with the ruler | yes |
| Inference: snaps, axis locks, guides, tape, protractor | yes | yes | snaps | snaps and sketch constraints | - | snaps |
| Groups | yes - open, lock, name, nest | yes | yes | - | grouping is how it models | collections |
| **Components** (copies that change together) | **no** | yes | - | - | no | linked duplicates |
| **Layers / tags** | **no** | tags | - | - | no | collections |
| **Solid add / subtract / intersect** | **subtract only** - drill a shape through | yes, paid plans; outer shell in all | yes | yes | yes, it is the whole idea | yes, as a modifier |
| **Round or chamfer a 3D edge** | **no** (the arc tool fillets a flat corner) | not natively | yes, its best trick | yes | - | bevel |
| Revolve, and sweep along a path | yes | Follow Me | yes, and pipe | sweep and loft | - | yes |
| Offset a face's outline | yes | yes | yes | - | - | inset |
| Cut through it to look inside | plan slice between two heights | section planes, any angle | section analysis | - | - | - |
| Paint a face | flat colors | colors and textures | materials | - | colors | full materials |
| **Light and shadow** | light that follows the camera; **shadows planned** | the same light, and sun shadows by place, date and hour | - | visualization, AR | no | a full renderer |
| Perspective camera | **no**, parallel only; planned for looking | yes | yes | yes | yes | yes |
| Dimensions and notes on the model | yes | yes; drawings in LayOut (Pro) | measuring; no drawings | full 2D drawings, paid | - | an extension |
| Prints at true scale | yes | yes | hidden-line SVG out | yes, paid | - | - |
| **Reads** | **its own files only**; DXF planned, last | SKP, images; DWG/DXF for subscribers | STEP, OBJ, STL, SVG, 3MF and more | STEP, IGES, DWG, STL and more | SVG, STL, OBJ | most mesh formats; no STEP |
| **Writes** | PNG, JPEG, GIF, WebP, SVG, DXF, STL, OpenSCAD | SKP, PNG, STL free; DWG/DXF paid | STEP, OBJ, STL, 3MF, SVG; IGES in Studio | STL/3MF free; STEP, DXF, DWG, PDF paid | STL, OBJ, glTF, SVG | most mesh formats |
| **Sheet-metal unfolding** | yes, built in | extension | - | - | - | - |
| **Duct fittings from measurements** | **yes, built in** | extension | no | no | no | no |
| **Pipe spool from legs** | **yes, built in** | extension | no | no | no | no |
| Animation out (GIF / WebP) | yes, built in | scenes to video | - | - | - | yes, anything |
| Commands you can type | yes, `/` and about eighty of them | no | a command palette | - | - | operator search |
| Scripting or plugins | **the drawing is text (Heck), and a jig is any program that prints it - experimental** | Ruby, and twenty years of extensions | - | - | Codeblocks | Python, enormous |
| Touch and pen | yes | yes (iPad) | - | **yes, it is built for it** | iPad | tablet and touch |
| Interface languages | **English only** | several | - | - | - | many |

## Next to the ones you draft or constrain in

Different kind of program: you describe the thing exactly and the program
holds you to it.  Slower to start in, and far better once the drawing has
to be right in every number or has to change later.

| | Heckers Sketch | [ZCAD][zcad] | [LibreCAD][librecad] | [QCAD][qcad] | [FreeCAD][freecad] | [SolveSpace][solvespace] | [Dune 3D][dune3d] | [Fusion][fusion] | [Onshape][onshape] |
|---|---|---|---|---|---|---|---|---|---|
| **Native Linux build** | yes | build it yourself; the current release ships Windows only | yes | yes | yes | yes | yes (Flatpak) | **no** | browser |
| **Price** | free | free | free | free community; Pro $48 once | free | free | free | $57 a month; free for hobby use, 10 live documents | free if your work is public; $1,500 a year if not |
| **License** | MIT | GPL3 / MPL2 | GPLv2 | GPLv3 community | LGPL | GPLv3 | GPLv3 | proprietary | proprietary |
| Written in | **Free Pascal / Lazarus** | **Free Pascal / Lazarus** | C++ / Qt | C++ / Qt, JavaScript | C++, Python | C++ | C++ / GTK | - | - |
| No account, no internet | yes | yes | yes | yes | yes | yes | yes | account; needs internet | account; **only** in a browser |
| Download | 11-21 MB | 52 MB (61 MB electrical) | - | 136 MB | hundreds of MB | - | 42 MB | 8.5 GB | nothing |
| **2D or 3D** | 3D, and flat plans of it | 2D, with 3D coordinates and faces; no solids | 2D only | 2D only | 3D | 3D | 3D | 3D | 3D |
| **Goes back and changes a number** (history, constraints) | **no** - one typed resize by a dimension | variables on objects | no | no | yes | yes, that is what it is | yes, SolveSpace's solver | yes | yes |
| **Layers** | **no** | yes | yes | yes | yes | no | - | - | - |
| **Blocks / components** | groups | blocks, a shared block library | blocks | blocks | yes | groups | groups, clusters | components | parts, assemblies |
| **Linetypes, lineweights, text styles** | pen color and width | yes - true DXF linetypes, SHX and TTF fonts | yes | yes | in drawings | no | no | in drawings | in drawings |
| **Hatching** | **no** | the entity; a command to make one not found | yes | yes | yes | no | no | yes | yes |
| **Dimensions** | linear, and a typed resize through one | linear, aligned, radius, diameter, styles - "partially done", by their README | yes | yes; styles in Pro | yes | as constraints | as constraints | yes | yes |
| Trim, extend, offset, fillet, array | offset, corner fillet, move-copy; **trim planned** | **not found** in its commands: it has copy, move, rotate, mirror, scale, stretch | all of them | all of them | all of them | trim, 2D fillet | fillet, chamfer | - | - |
| Solid add / subtract / intersect | subtract only | no solids | - | - | yes | yes | yes | yes | yes |
| **Reads DXF** | **no**; planned, last | yes, R12 to 2018 | yes | yes (R15 in community) | yes | yes | yes | yes | - |
| **Reads DWG** | no, and not planned | yes, through LibreDWG | yes | Pro | with a converter | yes | - | yes | - |
| Writes DXF | yes, the view or the model | yes, 2000 and 2007 | yes | yes | yes | yes | yes | paid plans | yes |
| Writes DWG | no | **no** | unclear - their own pages disagree | Pro | with a converter | no | no | - | yes |
| STEP | **no**; on the list, a long way down | no | - | - | yes | out | in and out | yes | yes |
| STL out | yes | no | no | no | yes | yes | yes | yes | yes |
| Prints at true scale | yes | prints; paper layouts not found | yes, and PDF | yes, and PDF | yes | PDF out | - | yes | yes |
| **Typed command line** | yes, `/` | yes | yes | yes | Python console | no | no | no | no |
| **Scripting** | **Heck text, and jigs - experimental** | Lape (Pascal script) | - | JavaScript | Python, enormous | batch export | Python, a proof of concept | an API | FeatureScript |
| **Sheet metal** | unfolding, built in | no | no | no | workbench | no | - | yes | yes, with a live flat pattern |
| **Trade work built in** | duct fittings, pipe spool, flat patterns | **electrical**: devices, cables, cable legend, materials list, bill of materials, CSV and XLSX | no | CAM in QCAD/CAM | workbenches for nearly everything | no | no | CAM | - |
| Interface languages | **English only** | English, Russian | over 30 | - | many | 10 | - | - | - |
| The manual | inside the program, and on the web | **Russian only**, unfinished | web | web, and a book | wiki | web | web | web | web |
| How alive | daily | **daily** - 9,357 commits, 330 stars, the last one today | 2.2.1.5, May 2026 | 3.33.1, September 2026 | 1.1.3, July 2026 | 3.2, March 2026 | 1.4.0, January 2026 | an update in July 2026 | an update in September 2026 |

## Two more, for buildings

Kept from the first version of this page, because people ask.

| | Heckers Sketch | [Sweet Home 3D][sh3d] | [Revit][revit] |
|---|---|---|---|
| Native Linux | yes | yes (Java) | **no**, Windows only |
| Price / license | free, MIT | free, GPL | subscription, proprietary |
| What it is | a sketcher | furniture in rooms, on levels | building information modeling |
| Draws a wall you can build from | a box is a box | walls, doors, windows from a catalog | yes - that is the product |
| Sun and shadow | planned | sunlight by hour and place | solar studies |
| Reads a plan to trace over | no | a picture (PNG, JPEG) | DWG, DXF, DGN, SKP |
| Languages | English | 29 | 14 |

[BricsCAD Shape][shape], the free push/pull modeler that used to belong in
the first table, was discontinued with BricsCAD V26 in 2025.

## ZCAD, because it is the other Pascal one

[ZCAD][zcad] deserves more than a column.  It is written in Free Pascal
and Lazarus, as this is; it has been going for years longer; and it is
being worked on daily - 9,357 commits and the most recent on the day this
was written.  The two programs do not overlap much, which is the useful
thing to know: **they are different tools that happen to share a
language**, and somebody who likes one may well want the other too.

**Reach for ZCAD when you need**

* **to open somebody's DXF or DWG.**  It reads DXF from R12 to 2018 and
  reads DWG through LibreDWG.  We read neither - our own format only, with
  DXF import on the list and deliberately last.
* **a drawing made of layers, blocks, linetypes and text styles** - the
  AutoCAD way of organizing a drawing.  ZCAD has all four, true DXF
  linetypes, SHX and TTF fonts, and a block library shared between
  drawings.  We have groups and a pen.
* **a DXF that another CAD program will treat as native**, with its layers
  and blocks and styles intact.  Ours writes honest geometry and
  dimensions; it is not a round trip.
* **electrical work.**  The `zcadelectrotech` build knows what a device and
  a cable are: it routes cables, numbers and marks them, builds schemes,
  and writes the **cable legend**, the **materials list** and a **bill of
  materials** out as CSV and XLSX, with a spreadsheet built in.  That is
  the same idea as our duct fittings and pipe spool - the trade's own work
  inside the drawing program - in a different trade, and nothing here
  touches it.
* **an object inspector** - every property of whatever is picked, editable,
  and several things at once.  Ours is a small panel with a few rows.
* **scripting**, in Pascal Script (Lape).  We have no script engine; we
  have the drawing as text (Heck, experimental) and jigs, programs in any
  language that print it - see `docs/heck-pitch.md`.
* **Russian.**  Its interface is in English and Russian; ours is English
  only.

**Stay here when you need**

* **a solid.**  ZCAD is a drafting program with 3D coordinates, faces and
  isometric views; it has no solids, no extrude and no push/pull.
* **trim, extend, offset, fillet or array** - we could not find these among
  its 162 command units (copy, move, rotate, mirror, scale and stretch are
  there).  Offset and a corner fillet are here; trim is planned.
* **a manual in English.**  Its user guide is in Russian and unfinished;
  ours is in the program.
* **a Linux download.**  Its current release, 0.9.19.0, ships two Windows
  archives; the last Linux binaries were 0.9.11.0, and after that it is a
  build from source.  It does build - Lazarus, GTK or Qt.
* **flat patterns, fittings, a pipe spool, STL for a printer, an animated
  picture** - none of which is its business.

If you know Pascal and want to work on a CAD program, both are open.  Ours
is MIT and small; theirs is GPL3/MPL2 and large, with a real entity engine
(`zengine`) that is worth reading whichever you choose.

## What is planned here

Written down, not built.  The rows above that say "planned" are these.

* **Shadows, the way SketchUp has them** - a sun placed by hour, date and
  place, shadows on faces and the ground.  The shading half is done: the
  light follows the camera as theirs does.
* **The rest of the SketchUp look** - harder black outlines, their dotted
  hover on a face.
* **A perspective camera, for looking** - drawing stays parallel.
* **A trim tool**, and **a rectangle that takes its plane from the face it
  starts on**.
* **Hidden edges** - Shift on the eraser, as theirs.
* **Components** - room has been left in the group record for a "copy of"
  link (`docs/groupplan.md`); nobody has asked for it yet.
* **DXF import**, deliberately last: writing a format is bounded work and
  reading one is not.  DWG is not planned at all.
* **A macOS build** - the code should build; nobody has built it.

## Where the others beat us

Not hedged, because nobody is helped by it being hedged.

* **Reading other people's files.**  We read our own and nothing else.
  Every program on this page reads something - DXF at the least.
* **Layers.**  Every drafting program has them and SketchUp has tags.  We
  have groups, which hide nothing and organize by what a thing *is* rather
  than by what kind of line it is.
* **Components.**  A copy of a group here is a group of its own; change
  one and the others stay as they were.
* **Solid operations.**  We subtract - a shape drilled through a solid -
  and that is all.  No union, no intersection, no trimming one solid with
  another.  Plasticity, FreeCAD, SolveSpace, Dune 3D, Tinkercad and the
  paid SketchUp all do.
* **Rounded edges in 3D.**  Plasticity and Shapr3D are built round this.
  We fillet a corner in the flat and that is it.
* **Changing your mind.**  No history tree, no constraints.  A dimension
  can be retyped and the thing it measures moves, once, and that is as
  parametric as it gets.  If the design will change, draw it in FreeCAD,
  SolveSpace or Dune 3D - and note we export OpenSCAD, so a shape roughed
  out here can be taken there and made parametric.
* **Drafting furniture.**  Hatching, linetypes, text styles, dimension
  styles, paper layouts with viewports - LibreCAD, QCAD and ZCAD are years
  ahead, because that is what they are for.
* **Light.**  Shading only.  SketchUp, Sweet Home 3D and Revit cast
  shadows from a real sun; Blender renders photographs.
* **A perspective view.**
* **Plugins.**  SketchUp's Ruby, FreeCAD's and Blender's Python, QCAD's
  JavaScript, ZCAD's Lape, Onshape's FeatureScript.  We have no API and no
  plugin language: the drawing is text (Heck) and a jig is any program
  that prints it.  Experimental, and a different bet - see
  `docs/heck-pitch.md` for the case and `docs/heck-vs-the-others.md`
  for Heck beside VRML, X3D, OpenSCAD and OBJ.
* **Languages.**  English.  LibreCAD is in over thirty.
* **STEP, IGES, 3MF, OBJ.**  STL is the only solid format we write.
* **A Mac, a tablet, a browser.**

## Where we beat them, and why it is not an accident

* **It is one file.**  Copy it onto a stick and run it.  No installer, no
  runtime, no account, no first-run tour, nothing phoning home.  Eleven
  megabytes on Windows and twenty-one on Linux, with the manual inside.
* **It runs on Linux natively** - the thing SketchUp, Shapr3D and Fusion
  have never done - while working the way somebody coming from SketchUp
  expects: the same keys, the same measurement typing, the same push/pull,
  now the same light.  `docs/sketchup/` is sixteen of their help pages read
  properly and written up, and where we differ it is on purpose and written
  down.
* **The trade work is in the box.**  Duct fittings from the measurements you
  took, a pipe spool leg by leg, and the flat pattern to cut - built in
  rather than bought as an extension.  That is the job this program was
  written for.  Only ZCAD, in its own trade, and Onshape and Fusion, at
  their prices, do the like.
* **It prints at true scale and says what scale.**  Pick 1/4" to the foot
  and that is what comes out of the printer.  Half the 3D programs above
  cannot print a drawing at all.
* **Commands you can type.**  `/` and a word, about eighty of them, every
  one listed with its aliases.  The drafting programs have this; none of
  the push/pull ones do.
* **It exports its own animations** - lossless WebP, and the encoder is
  Pascal inside the program, so nothing is installed to make one.
* **When it breaks, it tells us properly.**  A report carries what the
  program was doing, a picture and the drawing if you allow it, is
  encrypted on your machine before it leaves, and shows you exactly what
  went.  Then the session can be replayed from it.
* **It updates itself**, from one file to one file.
* **MIT.**  Fork it, sell it, mount it on a CNC machine, put it on a
  touchscreen beside a 3D printer.  We would rather that happened than not.
  Every other open program on this page is GPL, LGPL or MPL.

[sketchup]: https://sketchup.trimble.com/en/plans-and-pricing
[freecad]: https://www.freecad.org/
[librecad]: https://librecad.org/
[solvespace]: https://solvespace.com/
[sh3d]: https://www.sweethome3d.com/
[revit]: https://www.autodesk.com/products/revit/overview
[zcad]: https://github.com/zamtmn/zcad
[qcad]: https://qcad.org/en/qcad-documentation/qcad-features
[plasticity]: https://www.plasticity.xyz/
[shapr3d]: https://www.shapr3d.com/product/3d-modeling
[tinkercad]: https://www.tinkercad.com/
[blender]: https://www.blender.org/
[dune3d]: https://dune3d.org/
[fusion]: https://www.autodesk.com/products/fusion-360/personal
[onshape]: https://www.onshape.com/en/products/free
[shape]: https://bricscad.octave.com/news/bricscad-shape-discontinued

## Where each fact came from

The links above are the front doors.  The particular pages, for the claims
most likely to be argued with:

* **ZCAD** - formats read and written:
  [`uzcregfileformats.pas`](https://github.com/zamtmn/zcad/blob/master/cad_source/zcad/register/uzcregfileformats.pas)
  and [`uzeffdxf.pas`](https://github.com/zamtmn/zcad/blob/master/cad_source/zengine/fileformats/uzeffdxf.pas);
  commands present and absent: the
  [commands directory](https://github.com/zamtmn/zcad/tree/master/cad_source/zcad/commands);
  dimensions "partially done", platforms and entity list: its
  [README](https://github.com/zamtmn/zcad#readme); electrical outputs:
  [`velec`](https://github.com/zamtmn/zcad/tree/master/cad_source/zcad/velec)
  and [`uzccomelectrical.pas`](https://github.com/zamtmn/zcad/blob/master/cad_source/zcad/electrotech/uzccomelectrical.pas);
  the Russian-only guide: [`docs/userguide`](https://github.com/zamtmn/zcad/tree/master/cad_source/docs/userguide);
  download sizes: its [releases](https://github.com/zamtmn/zcad/releases).
* **SketchUp** - prices: [plans and pricing](https://sketchup.trimble.com/en/plans-and-pricing);
  the free web version and what it lacks: [SketchUp Free](https://sketchup.trimble.com/en/plans-and-pricing/sketchup-free);
  solid tools by plan: [Solid Tools](https://help.sketchup.com/en/sketchup/modeling-complex-3d-shapes-solid-tools);
  CAD files for subscribers: [importing and exporting CAD files](https://help.sketchup.com/en/sketchup/importing-and-exporting-cad-files);
  shadows: [casting real-world shadows](https://help.sketchup.com/en/sketchup/casting-real-world-shadows).
* **QCAD** - what is community and what is Pro: [features](https://qcad.org/en/qcad-documentation/qcad-features); price: [shop](https://www.qcad.org/online-shop).
* **Plasticity** - prices, platforms, "no history tree required": [plasticity.xyz](https://www.plasticity.xyz/); formats by edition: [import and export](https://doc.plasticity.xyz/plasticity-essentials/import-export).
* **Shapr3D** - platforms and modeling: [3D modeling](https://www.shapr3d.com/product/3d-modeling); plans: [pricing](https://www.shapr3d.com/pricing).
* **Tinkercad** - export types: [export file types](https://www.tinkercad.com/help/3d-editor/export-filetypes).
* **Blender** - formats: [importing and exporting](https://docs.blender.org/manual/en/latest/files/import_export.html); sizes: [download](https://www.blender.org/download/).
* **Dune 3D** - [installation](https://docs.dune3d.org/en/latest/installation.html), [groups and operations](https://docs.dune3d.org/en/latest/groups.html), [export](https://docs.dune3d.org/en/latest/export.html).
* **Fusion** - hobby terms: [personal use](https://www.autodesk.com/products/fusion-360/personal); formats by plan: [supported file formats](https://help.autodesk.com/view/fusion360/ENU/?guid=TPD-SUPPORTED-FILE-FORMATS).
* **Onshape** - [free plan](https://www.onshape.com/en/products/free), [pricing](https://www.onshape.com/en/pricing), [sheet metal](https://www.onshape.com/en/features/sheet-metal).
* **FreeCAD** - DXF and DWG: [DXF import](https://wiki.freecad.org/FreeCAD_and_DXF_Import), [DWG import](https://wiki.freecad.org/FreeCAD_and_DWG_Import).
* **LibreCAD** - [README](https://github.com/LibreCAD/LibreCAD#readme), [tools](https://docs.librecad.org/en/latest/ref/tools.html).  Its repository description says it writes DWG and its README says read only; hence "unclear".
* **SolveSpace** - [features](https://solvespace.com/features.pl), [changelog](https://github.com/solvespace/solvespace/blob/master/CHANGELOG.md).
* **Sweet Home 3D** - [features](https://www.sweethome3d.com/features.jsp), [download](https://www.sweethome3d.com/download.jsp).
* **Revit** - Autodesk's pages refused to be read by a program on the day, so its rows rest on their help site's search results; treat them as the least certain here.
