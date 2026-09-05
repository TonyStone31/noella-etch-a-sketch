# Getting work out of the program

Written 4 September 2026, after Tony asked what could be imported and
whether a piece of duct could be unfolded for a cutting table.  Nothing here
is built.  It is written down so the order is decided once.

Today the program writes PNG and SVG, and both are pictures of the current
view rather than geometry.  Everything below is about that gap.

## What is worth reading and writing

| Format | Read | Write | Verdict |
|---|---|---|---|
| DXF, the ASCII flavour | a subset is feasible | straightforward | the right target |
| DWG | no | no | proprietary; needs a licensed library |
| SKP | no | no | SketchUp's own, C++ SDK with licence terms |
| STL | trivial | trivial | for anything cut or printed |
| OBJ | trivial | trivial | cheap, but nothing here consumes it |
| STEP, IGES | no | no | wants B-rep and NURBS; a different program |

## DXF export - worth doing, and not early

A DXF is a text file of group codes.  What this program holds maps onto it
almost one for one: `LINE` for an edge, `CIRCLE` and `ARC` for an arc,
`3DFACE` for a face, `TEXT` for a note, and a dimension as lines plus text.
There is no parsing, so the failure mode is a file that will not open rather
than one that opens and lies.

Two exports, not one, because they are different jobs:

* **A 2D DXF of the current view.**  What the SVG is now, but as entities
  somebody can snap to, measure and dimension in their own CAD.
* **A 3D DXF of the model.**  True coordinates, for handing over the thing
  itself rather than a picture of it.

Layers are worth getting right from the start - geometry, dimensions, notes,
and for a flat pattern, cut and bend on separate layers.  A cutting table
reads layers.

## DXF import - later, and deliberately narrow

Writing is bounded work.  Reading is not.  Files in the wild carry blocks
with transforms, layers, splines, ellipses, hatches, MTEXT, and units that
are not always declared.  A reader that takes `LINE`, `LWPOLYLINE`, `CIRCLE`,
`ARC` and `3DFACE`, flattens blocks, and asks which units to assume is a
weekend's work; the trouble is the failure mode.  A drawing that opens
looking right but sits at a twelfth of its size, or is missing everything
that lived inside a block, is worse than one that refuses - and the person
finding out is on a jobsite.

There is also the question of what would come in.  Architects' plans arrive
as DWG, which is out of reach anyway, or as PDF.  Manufacturers' equipment
outlines are often DXF, and that is the real case - occasional, and the one
where a quietly wrong import costs the most.

So: last, and only when there is a particular file that has to come in.

## Flat patterns - the one that is actually the trade

For duct work the valuable output is not a model, it is the sheet it gets cut
from.  This is the piece nobody gives away and the piece Tony would use.

### It only works because duct is developable

A surface can be laid out flat without stretching only if it is developable -
planes, cylinders, cones, and things made of those.  That is most of the
trade by design: a rectangular transition is four trapezoids, a
square-to-round is triangular facets and cone segments, an elbow is gores off
a cylinder.  A dome or a compound double-curve is not developable and never
will be, and saying so plainly beats producing a pattern that does not fit.

### How it would work here

The model is already flat polygons, which is the easy case.

1. Triangulate the faces of the piece.  This is the same triangulation the
   layout books teach, for the same reason.
2. Build the graph of which triangle touches which.
3. Choose a spanning tree of it.  Edges in the tree stay joined and become
   bend lines; edges left out become cuts.  Which tree you pick is where the
   seam ends up.
4. Lay the first triangle in the plane, then walk the tree, unfolding each
   one about the edge it shares with its parent.  Edge lengths are preserved,
   which is the whole trick.
5. Check the result for overlap.  This is the fiddly part: some trees fold
   back onto themselves and the seam has to move, or the piece has to come
   out in more than one part.

Output is a new sheet, cut lines solid, bend lines dashed, and then a DXF -
which is why the export comes first.

### What separates a pattern that fits from one that does not

Geometry is the easy half.

* **Seam allowance.**  A lock seam, an S-and-drive, a flange - each eats
  material and each wants its own allowance along the edges it applies to.
* **Bend allowance.**  Metal stretches on the outside of a brake.  A pattern
  developed on the neutral line and one developed on the inside dimension
  differ by enough to matter over several bends.
* **Grain and nesting.**  Several parts on one sheet, and which way round.

None of that is hard arithmetic.  All of it is knowledge Tony has and the
program does not, so it belongs in settings with sensible defaults rather
than being guessed at.

## 3D printing

STL, and it is trivial to write from triangles.  One honest caveat: a duct
model here is a *surface* with no thickness, and a printable STL wants a
closed solid.  Printing one would mean thickening the surface first - giving
it a wall - which is its own feature.  For looking at, checking, or handing
to somebody with a slicer that tolerates open surfaces, plain STL is fine.

## The order

1. **DXF export.**  Bounded, useful the day it lands, and everything else
   needs it.
2. **Flat patterns.**  The one that is the trade.
3. **STL export.**  Cheap once the faces are triangulated for unfolding.
4. **Surface thickening.**  Only if printing turns out to matter.
5. **DXF import.**  Narrow, late, and only for a file that has to come in.
