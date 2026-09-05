# Typing a measurement

What the program takes when you type instead of dragging, what SketchUp takes,
and where we differ.  Written down because "at least as good as SketchUp"
needs a list to be checked against.

## Lengths

Anywhere a length is wanted - a line, a push, a radius, a side of a rectangle
- all of these are read:

| Typed | Means |
|---|---|
| `12` | twelve feet (whatever the current unit is) |
| `12'` | twelve feet |
| `6"` | six inches |
| `12'6"` | twelve foot six |
| `12'6` | the same; the inch mark is optional |
| `12-6` | the same again |
| `12 6` | and again |
| `3 1/2` | three and a half |
| `1/2` | half |
| `6-8-15` | **feet, inches, sixteenths** - see below |
| `2m`, `40cm`, `600mm` | metric, when the drawing is metric |

Negative runs the other way.

### Feet, inches and sixteenths

`6-8-15` is six foot eight and fifteen sixteenths.  `0-8-8` is eight and a
half inches, and that leading nought for the feet is how a truss sheet writes
anything under a foot.

This is the notation the component design software the truss shops run prints
on shop drawings and cut lists - MiTek, Alpine and the like.  It is **not** an
AutoCAD input convention; AutoCAD wants `6'8-15/16"` and will read `6-8` as
feet and inches but not a third dash.  It is a trade notation, and it is worth
having here for the reason it exists there: every field is a whole number,
there is no foot mark, inch mark or slash anywhere in it, and the whole thing
goes in from the number pad with the minus key.

The third field is sixteenths, always, because that is what a truss shop works
in.  A third field above fifteen means the drawing is in some other fraction,
and that is **refused** rather than read as sixteenths - a wrong denominator
gives a plausible number that is quietly off by a hair, on a length somebody
cuts metal from.

## Two sides at once

A rectangle takes both sides in one go:

| Typed | Means |
|---|---|
| `8x10` | eight by ten |
| `8,10` | the same |
| `8;10` | the same - SketchUp's separator |
| `8/10` | the same, and the one that is on the number pad |
| `8,` | eight on the first side, the cursor still choosing the second |
| `,10` | the other way about |

The **first** slash separates the sides; any slash after it is still a
fraction, so `2/2 1/2` is two foot by two and a half.  One rule, and it fits
in your head.  A slash with nothing typed yet is the start of `/help`, not a
rectangle.

## Points and offsets

The move and line tools take a place as well as a length:

| Typed | Means |
|---|---|
| `[4,0,8]` | that point in the drawing |
| `<4,0,8>` | that far from where you are |

## What SketchUp has that we do not

* `*6` or `x6` after a move - make six copies.
* `/3` after a move - divide the run into three.
* `24s` on a circle or an arc - set the segment count.

All three are on the list.
