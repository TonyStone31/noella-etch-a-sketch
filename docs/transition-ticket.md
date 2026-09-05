# How a transition gets called out

Tony's description, 4 September 2026, written down before anything is built
so the tool matches how his shop already writes a ticket rather than a
dialect nobody uses.  **The questions at the end need answering before this
is built.**

## The sketch

It is a plan view.  You are standing on the square duct run looking down at
the gap where the fitting will go, and what you draw is the missing piece.

* An **arrow for the direction of flow**.
* A **rectangle** for the fitting seen from above - narrower at the top of
  the page where it reduces.
* The **sizes written at the top and bottom of the page**: the big end at the
  bottom, the small end at the top.
* If a side comes in, that side of the rectangle is **slanted in**, with an
  arrow and the number of inches it comes in by.
* The height is not in a plan view at all, so it is **written**: `FB` for flat
  bottom, `FT` for flat top, or `top up` / `bottom down` with an amount.

So the paper carries the width and the length as a picture, the offsets as
arrows on the sides, and everything about height as words.

## What that comes to as numbers

| | |
|---|---|
| Big end | width x height |
| Small end | width x height |
| Length | along the run |
| Left offset | inches the left side comes in |
| Right offset | inches the right side comes in |
| Height treatment | flat bottom, flat top, centred, or an amount up or down |

Width and the two side offsets are the same fact twice over - the small width
plus the two offsets is the big width - so the tool should take any two and
work out the third, the way the sketch does.

## The tool this suggests

Not a form of twelve boxes.  A **plan view of the fitting that looks like the
sketch**, with the numbers typed onto it where they are written on paper: the
two sizes above and below, the offsets against the sides they belong to, the
height treatment as a word.  The flow arrow drawn because it is drawn.

Then it builds the four sides in 3D, and from there it can be unfolded and
cut, which is the whole point of putting it in here rather than on paper.

## What is not yet settled

1. **`top up` and `bottom down` - up or down by how much, and measured from
   what?**  The reading here is that they say where a change in height is
   taken: flat bottom puts all of it in the top, flat top puts all of it in
   the bottom, and `top up 2` raises the top of the small end two inches
   above where flat-bottom would put it.  That may be wrong.
2. **Which way round is the page?**  Assumed flow goes up the page, big end
   at the bottom, small end at the top.
3. **Left and right of what?**  Assumed as drawn on the page, looking down
   with the flow going away from you - so "left" is the left of the sketch.
   Whether that matches how it is called out on the shop floor, when the
   fitter may be standing the other way round, is worth knowing.
4. **Does the same ticket cover an offset with no reduction** - a jog, same
   size both ends, shifted across - or is that a different fitting with its
   own notation?
5. **Square to round.**  A different animal, and it is the one where the
   unfolding earns its keep.  Worth knowing how those get called out too.
