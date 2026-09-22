# Heck beside the formats that came before it

Written 21 September 2026, to see how far Heck is from the text formats
that were already there - and what each of them worked out that we have
not.  The samples are from memory of each format's own examples and may
be off in a detail; the shape of each is right.  Three things, in each:
a box, a circle on its top, and a line.

## VRML 2.0 (1997) - the first "HTML for 3D"

```
#VRML V2.0 utf8
Transform {
  translation 2 1 2
  children Shape {
    appearance Appearance { material Material { diffuseColor 0.8 0.8 0.8 } }
    geometry Box { size 4 2 4 }
  }
}
Shape {
  geometry IndexedLineSet {
    coord Coordinate { point [ 0 0 0, 4 0 0 ] }
    coordIndex [ 0 1 -1 ]
  }
}
```

Brace blocks, named fields, nesting - the same shape as Heck and as an
`.lfm`.  Two things it has that we do not: **`Transform`** (a thing is
described once at the origin and then moved, turned and scaled by its
parent - which is how a wheel is drawn once and used four times), and
**primitives** (`Box`, `Cylinder`, `Sphere`, `Cone`, each with a size).
Two things it lacks: units (a bare `4` is whatever you say it is) and any
way to refer to a point by name.  Every coordinate is a number, and faces
refer to points by *index* into a list, which is exactly what a person
cannot read.

## X3D (2001) - VRML in XML

```xml
<Transform translation="2 1 2">
  <Shape>
    <Box size="4 2 4"/>
    <Appearance><Material diffuseColor="0.8 0.8 0.8"/></Appearance>
  </Shape>
</Transform>
<Shape>
  <IndexedFaceSet coordIndex="0 1 2 3 -1">
    <Coordinate point="0 0 0 4 0 0 4 4 0 0 4 0"/>
  </IndexedFaceSet>
</Shape>
```

The same model in angle brackets - the syntax this project set out to
avoid typing.  It added **`DEF`/`USE`** - name a thing once, use it
again by name - which is the component idea, and **`Extrusion`** (a
cross-section swept along a spine), which is push/pull and Follow Me in
one node.  Faces are still index lists.

## OpenSCAD (2010) - the model as a program

```
translate([0, 0, 0]) cube([4, 4, 4]);
translate([2, 2, 4]) cylinder(h = 0.01, r = 1);
```

Two lines for the cube and the circle, and nobody can misread them.  It
wins on brevity because it has **primitives** and **transforms** and no
faces at all - the solid is the unit, not the face.  What it cannot do is
the thing we are built on: a person cannot pull one face of that cube
with the mouse, because the text is a program and the model is only its
output.  And it has no units either; `4` is a number.

## OBJ (1980s) - the mesh, as plainly as possible

```
v 0 0 0
v 4 0 0
v 4 4 0
v 0 4 0
f 1 2 3 4
l 1 2
```

Vertices, then faces by index.  It is the ancestor of `points ... end`
and `face = a b c d`: ours is OBJ with the numbers given names, the
names chosen to mean something, the units real, and the faces worked out
for you.  `face = rb24 rb23 ra2 ra1` is `f 24 23 26 25` with letters.
That is the whole of the improvement, and also the whole of the problem:
a face is still a list.

## OpenSCAD's cousin, the STEP-CSG family - and SketchUp's own `.skp`

Not text at all, or text nobody reads.  Left out.

## Where Heck stands

```
points
  floor1 = 0 east, 0 north, 0 up
  floor2 = floor1 + 4' east
  ...
end
face = floor1 floor2 top2 top1   { facing south }
line = floor1 to top1
circle c1
  center = 2' east, 2' north, 4' up
  radius = 1'
  facing = up
end
```

What we have that none of them do:

* **Real units, written the way a tradesman says them.**  `4'`, `2 1/2"`,
  `1200mm`.  Every one of the others is unitless numbers.
* **Named points, named by where they stand** (`floor1`, `top1`), and
  places written from each other (`floor1 + 4' east`).  OBJ and X3D use
  indices; VRML and OpenSCAD have no names at all.
* **Directions as words.**  `east`, `up`.  Everyone else: `x y z`.
* **Faces worked out for you.**  Type the lines, get the faces.  In every
  other format the face is yours to list, corner by corner.
* **Written back by the program**, live, as you draw.  OpenSCAD cannot;
  the rest are written once by an exporter and never read by a person.
* **Sums** in a place (`a + (Width - 1')/2 north`) - only OpenSCAD has
  this, and it has it because it is a language.

What they have that we do not - the list that matters:

1. **Primitives.**  `Box { size 4 2 4 }`, `cube([4,4,4])`, `Cylinder`,
   `Sphere`.  This is why OpenSCAD's cube is one line and ours is
   twenty-six.  We tried `box` and pulled it for saying twice what the
   lines say; but every one of these formats decided the opposite, that
   a box is one thing and its faces are its business.  **The face list is
   the price of not having primitives.**  A `box` that the reader expands
   to lines - and the writer folds back to `box` when a solid is still
   exactly a box - would take the cube to three lines and lose nothing.
   The same for `cylinder` (which is what a pulled circle is) and
   `wedge`.
2. **Transforms.**  Draw the wheel once; `at 3' east, turned 90°` puts it
   there.  We have no way to say "this, moved" - a copy is a copy.  It is
   the other half of what makes OpenSCAD short, and it is what groups
   would need to become components.
3. **`DEF`/`USE`** - a thing defined once and used by name in several
   places.  Components again.  A group with a name is halfway there.
4. **A sweep.**  X3D's `Extrusion`: a cross-section and a path.  Ours is
   the push/pull and revolve *tools*, whose results are written as faces.
   A `pull = 2'` on a face block, or `sweep` on a circle, would be the
   text of what the tool did - the verbs-in-transit idea, kept.

What the face statement could become, given 1:

```
box                                 // the cube, all of it
  at   = 0 east, 0 north, 0 up
  size = 4' east, 4' north, 4' up
end
circle c1                           // on its top
  center = 2' east, 2' north, 4' up
  radius = 1'
  facing = up
end
```

Nine lines, and a child reads it.  The faces are still there in the
drawing, still pickable, still worked out; the writer only says `box`
while the solid *is* a box, and falls back to the face list the moment it
is not (a hole in its top, a face pushed).  That is what OpenSCAD and
VRML both got right and we walked away from.

## Where each of them went

VRML and X3D are still an ISO standard and nobody writes them by hand;
they became what exporters produce.  OBJ is everywhere for the same
reason: it is the simplest thing that works, and it was never meant to be
read.  OpenSCAD is the one people actually type, and they type it
*because* of primitives and transforms - the two things on the list
above.  The lesson is not subtle: the readable formats are the ones with
a small vocabulary of whole things.  Faces by corner are for machines.
