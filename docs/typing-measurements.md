# Typing a measurement

What the program takes when you type instead of dragging, what SketchUp takes,
and where we differ.  Written down because "at least as good as SketchUp"
needs a list to be checked against.

## Lengths

Anywhere a length is wanted - a line, a push, a radius, a side of a rectangle
- all of these are read:

| Typed | Means |
|---|---|
| `12` | twelve feet |
| `12'` | twelve feet |
| `6"` | six inches |
| `12'6"` | twelve foot six |
| `12'6` | the same; the inch mark is optional |
| `12-6` | the same again |
| `12 6` | and again |
| `3 1/2` | three and a half |
| `1/2` | half |
| `6-8 1/2` | six foot eight and a half |
| `6-8.5` | the same |
| `6-8-15` | **feet, inches, sixteenths** - see below |
| `2m`, `40cm`, `600mm` | metric, when the drawing is metric |

Negative runs the other way.

### How many numbers you type is what they mean

One number is feet.  Two are feet and inches.  Three are feet, inches and the
fraction.  Leaving the last one off does not leave a fraction behind - `6-8`
is exactly six foot eight - so a drawing that is all whole feet stays as fast
to type as it should be.

A dash may carry a fraction or a decimal after it, because a dash says plainly
where the feet stop: `6-8 1/2` and `6-8.5` both work.  A *space* cannot, since
`3 1/2` is three and a half feet, so the space form is only read when there is
no fraction in it.

Two decimal points in one number - `2.5.5` - is a typo rather than a notation,
and is refused.  What that was reaching for is `2-6-8`.

### Which unit a bare number means

Feet.  This is the same answer SketchUp gives and it gives it the same way: a
bare number means the model's unit, and you override it for one entry by
writing the mark - `30"` is thirty inches whatever the drawing is set to.
There is no guessing from the size of the number, which is the only way `2.5`
can be relied on to mean one thing.

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

The third field counts in whatever the **PREC** setting says, which is
sixteenths unless you change it - 1/2 through 1/64, or hundredths of an inch.
A field at or above the denominator means the drawing is in some other
fraction, and that is **refused** rather than guessed at: a wrong denominator
gives a plausible number that is quietly off by a hair, on a length somebody
cuts metal from.

PREC is one setting for reading and writing both.  A drawing that printed
sixteenths while accepting sixty-fourths would take a number and then show a
different one, which is the sort of thing you find out after cutting.  It
never changes what the drawing holds - a length typed finer than the display
keeps every digit and is only *written* rounded, which is what Precision means
in SketchUp too.

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
