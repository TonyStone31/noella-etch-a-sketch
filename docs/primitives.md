# Primitives for Heck - on paper, 21 September 2026; mostly built by the 22nd

The set, drawn up to be argued with before it went into the reader or the
writer.  **Built so far:** `box`, both forms, read and folded; `rect`,
both forms, read and folded; the one-line
`circle`; the box under a circle, (b) below - the cube with a circle on
it is two lines; and **`pull`**, which was not on this page and turned
out to be the one that matters: a flat outline gone some way, which is
what push/pull makes of anything.  `pull = c1; 2' up` is the cylinder, so
`cylinder` is not needed; an L-shaped room is its six floor corners and
`by = 8' up`.  Since 22 September a plain face is never written at all -
faces are what closed lines become, in the text as with the tools - which
is why a `pull` can be edges only.  See `heck-vs-the-others.md` for why:
the readable formats are the ones with a small vocabulary of whole things,
and a face list is what you write when you have none.

## The one rule

**A primitive is a fold, never a second truth.**

The drawing underneath is lines and faces, exactly as the tools make
them.  A primitive is a shorter way of *writing* some of them:

* The **reader** expands a primitive into the lines and faces it stands
  for.  `box` becomes twelve lines and six faces in the drawing, the same
  ones a rectangle pulled up would have made.
* The **writer** folds back the other way, and only while the fold is
  exact: a solid is written `box` while its eight corners, six faces and
  twelve edges are precisely a box and nothing about it is unusual.  Move
  one corner, cut a hole in its top, paint one face, push one side, and
  it is no longer a box - so the writer writes what it is, the lines and
  faces, and the word goes.
* Nothing is ever said twice.  A solid is `box` *or* its faces, never
  both.  (This is the "one fact, one place" rule, kept.  A box is one
  fact.)

So a primitive is exactly what `ring` already is: twenty-four corners
spaced evenly round a circle are written `ring ra`, and would be written
out one by one the moment one of them was nudged.  `circle` is already a
primitive too - which is why it reads well and the ring of corners does
not.

What this buys: the cube with a circle on it goes from twenty-six lines
to nine, and a child reads it.  What it costs: nothing in the drawing,
and a fold test in the writer for each primitive.

## What a primitive says

Every one is written the same way: its kind, then where it is and how big,
in the words a person would use.  Two forms, as with everything in Heck -
one line when nothing is unusual, a block when something is (a paint, a
name).

```
box = 0 east, 0 north, 0 up; 4' east, 4' north, 4' up

box
  at   = 0 east, 0 north, 0 up
  size = 4' east, 4' north, 4' up
  paint = orange
end
```

`at` is the corner nearest the origin - the lowest, southwest corner -
and `size` is a step, always positive, from it.  Square to the axes,
always; a turned box is not a box (see *Turned things*).

## The set

Flat things first, then solids.  Each with: what it says, what it expands
to, and when the writer may fold it.

### `rect` - a rectangle

```
rect = 0 east, 0 north, 0 up; 4' east, 3' north
```

* **Says:** a corner and a size with two parts.  The two parts name the
  plane: `east, north` is flat on the floor; `east, up` stands facing
  south; `north, up` faces east.
* **Expands to:** four lines.  The face comes from the lines, as always.
* **Folds when:** four lines close a rectangle square to the axes, and
  the face inside them is plain (no hole, no paint) or absent.  With a
  paint, the block form: `rect ... paint = red ... end`.
* Also the RECT tool's own record of what it drew, if a `/replay` ever
  wants to say it in Heck.

### `circle` - already here

```
circle c1
  center = 2' east, 2' north, 4' up
  radius = 1'
  facing = up
end
```

One-line form: `circle c1 = 2' east, 2' north, 4' up; 1'`, facing up;
a third part says otherwise: `circle c1 = 0 east, 2' north, 2' up; 1'; east`.
The writer folds to it when nothing else about the circle is unusual -
its own `sides`, a `starts`, an ink - and those keep the block.

### `arc` - already here

As it is.  No one-line form: an arc wants its start and sweep said.

### `box` - a block

```
box = 0 east, 0 north, 0 up; 4' east, 3' north, 2' up
```

* **Expands to:** eight corners, twelve lines, six faces, one solid.
* **Folds when:** a solid of exactly six faces and twelve edges whose
  corners are the eight of a box square to the axes, no face with a
  hole, every edge ordinary, and at most one paint over the whole thing.
* **Block form** adds `paint`, and a name: `box Foot ... end`.

### `cylinder` - a pulled circle

```
cylinder = 2' east, 2' north, 0 up; 1'; 2' up
```

* **Says:** the center of the bottom, the radius, and the height as a
  step - which also says which way it stands (`2' up`, `3' east` for one
  lying down).
* **Expands to:** two circles (rings, in the solid's points), the walls
  between them, top and bottom faces.  `sides` from the sheet, or a
  property.
* **Folds when:** a solid whose faces are two matching rings' disks and
  the N walls between them, and nothing else.  This is most of what the
  Robot's joints and the wine glass are.

### `wedge` - half a box, cut corner to corner

```
wedge = 0 east, 0 north, 0 up; 4' east, 3' north, 2' up; low = south
```

* **Says:** a box, and which side is the low edge.  The slope rises from
  that side to the opposite one.
* **Expands to:** six corners, nine lines, five faces.
* **Folds when:** a solid of five faces with that shape.
* Roofs, ramps, gussets.  Worth having; the fold test is fiddly.

### The industry set

What every 3D format and toolkit agrees on - VRML, X3D, OpenSCAD, and
the toolkits behind games and CAD - is a short list, and it is worth
having the same names for the same things so that somebody arriving from
any of them knows what to type:

| Everyone's name | Ours | Says |
|---|---|---|
| box / cube | `box` | corner and size |
| cylinder | `cylinder` | bottom center, radius, height as a step |
| cone | `cone` | bottom center, radius, height as a step; `top = 6"` for a frustum |
| sphere | `sphere` | center, radius |
| torus | `torus` | center, ring radius, tube radius, facing |
| wedge / prism | `wedge` | a box and which side is low |
| pyramid | `pyramid` | base corner and size, height |
| plane / rect | `rect` | corner and size with two parts |
| disc / circle | `circle` | as it is |
| polygon | - | a `face`, which it is |

`sphere`, `cone`, `torus` and `pyramid` have no tool behind them yet.  A
primitive with no tool is text-only - it can be typed and it reads back
exactly, but the writer never folds to it because nothing the mouse makes
comes out as one.  That is fine to begin with: the reader takes all of
them, the writer folds the ones the tools make (`box`, `cylinder`,
`rect`, `circle`), and each of the others gets its fold when it gets its
tool.  The revolve tool is most of a sphere and a torus already.

## Turned things

A box turned 17° is not a box in this scheme, and its corners are ugly
numbers - the awkward case in `format2.md`.  The way out is not a
primitive but a **transform**, which every format that came before us
has and we do not:

```
box
  at   = 0 east, 0 north, 0 up
  size = 4' east, 3' north, 2' up
  turned = 17°                      // about up, about its own corner
end
```

That is the same box, said square, and turned afterwards - which is also
exactly how the person made it (draw it square, rotate it).  The writer
can fold it only if it can *find* the turn: eight corners that are a box
after being turned back by some angle about some axis.  Findable for a
turn about up (the common case: the corners' heights say the axis, the
first edge says the angle).  A thing turned two ways at once stays as
lines, which is honest.  Transforms are a bigger thing than primitives and
belong with groups and components; parked, but the door is left open.

## What it does to the cube

Today, twenty-six lines:

```
solid
  points
    floor1 = 0 east, 0 north, 0 up
    floor2 = floor1 + 4' east
    ... six more ...
  end
  face   { facing up }
    points = top1..top4
    hole = c1
  end
  face = floor4..floor1   { facing down }
  ... four more faces, twelve lines ...
end
circle c1 ... end
face = c1
```

With primitives, and the circle's hole meaning the top is no longer a
plain face - so this one does **not** fold to `box`.  It folds to the
next best thing, which is the point of doing them all: a box with a
circle on it is a common enough thing that it wants saying.  Two answers:

**(a)** accept it: a box with anything on it is written out.  Nine lines
for a plain box, twenty-six the moment a circle lands on it.  Honest, and
a cliff.

**(b)** let a face carry its holes *as things drawn on it*:

```
box = 0 east, 0 north, 0 up; 4' east, 4' north, 4' up
circle c1 = 2' east, 2' north, 4' up; 1'
```

- and the reader, expanding the box, then reading the circle, finds it
lies on the box's top and cuts the hole itself, as it does when the
circle is drawn there with the tool.  The writer folds the box because
the *box's own* corners and faces are still a box's; the hole is the
circle's doing, and the circle is written.  This is what the tools do
already - a circle on a face makes a hole - so it is not a new rule, only
the writer noticing it.  **(b) is the one.**  It makes the example:

```
box = 0 east, 0 north, 0 up; 4' east, 4' north, 4' up
circle c1 = 2' east, 2' north, 4' up; 1'
```

Two lines.  A child reads it.  Everything the tools know is still in the
drawing.

## Order of work

0. The reader takes the whole industry set, so anything typed reads.
   (Only `box` and `rect` so far.)
1. ~~`box`, both forms, reader and writer, with the fold test and its test
   in geomtest: a box goes out as `box`, a nudged one goes out as lines,
   both come back exactly.~~  Done, 21 September 2026.
2. ~~`rect`~~ - read and folded, 22 September 2026.
3. ~~The one-line `circle`, and the writer folding a box under a circle
   (b above).~~  Done, 22 September 2026.  The reader cuts a circle into
   the face it lies on, so the fold needs no `hole` said.
4. ~~`cylinder`~~ - `pull = c1; 2' up`, done with `pull`, 22 September 2026.
5. `wedge`, if wanted.
6. `turned`, with transforms, when groups get there.
