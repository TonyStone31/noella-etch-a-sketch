# Example drawings

## `etch-a-sketch.hsk` - the house model

The drawing every help picture uses.

One model across all of them is worth more than a good model in each: somebody
reading about the line tool and somebody reading about push/pull are then
looking at the same object from two angles, and there is one less thing to
work out on every page.

It is a toy etch-a-sketch, near enough to the real one's size:

| | |
|---|---|
| body | 12" x 9" x 1 1/4" |
| screen | 9" x 5 1/2", recessed 1/8" |
| knobs | 1 1/4" across, standing 3/8" proud |
| overall | 12.00 x 9.00 x 1.67 in |

Three closed solids - the body and the two knobs - so nothing shows a blue
back and it exports to STL as a printable object.

Its near bottom left corner sits **on the origin**, so the whole toy lies in
the quarter where all three axes are drawn solid rather than dashed.  Centred
on zero was tried first and is tidier in a picture, but it puts half the
drawing behind the dashed halves - the halves that mean *the other way* - and
that is a strange place to keep something you are measuring.  This way nine
inches along is nine inches, not minus four and a half.

The logo is block capitals, and **each letter is one closed loop** rather than
a pile of bars.  Bars were easier to write and left a line across every join,
so pushing an H up meant pushing three pieces and getting a letter with seams
down it.  One outline is one face: click it once, push it once, the whole
letter stands up.  R is the only one needing a second loop, for the hole in
its bowl - and a face with a hole extrudes with the hole, the same as a wall
with a window in it.

**The robot on the screen is faces, cut into the screen behind it.**  It was
lines only to begin with, on the reasoning that a real etch-a-sketch drawing
is lines - and it meant you could not push one, because a drawing read from a
file never has its faces worked out.  So each piece of the robot is a face now,
plugged into a hole in the screen, and the whole of it lifts: click the head,
push it, and it stands off the screen with walls round it.

The eyes are cut into the **head**, not into the screen, which is the thing to
copy if you add to it.  Cut both out of the screen and you get a hole inside a
hole with the head laid over the top of the eyes - two faces fighting over the
same pixels, and a solid that comes apart the moment either is pushed.

### Making it again

`make-etch-a-sketch.pas` writes it.  Everything in it is in inches and divided
by twelve on the way out, because the drawing's unit is the foot and nobody
thinks about a toy in feet.

```
cd examples
fpc -Mobjfpc -Sh -Fu.. make-etch-a-sketch.pas
./make-etch-a-sketch
```

It is kept because a model you cannot change is a model that slowly stops
matching the pictures: when a tool changes and the picture needs redoing, the
model needs to be adjustable, not traced.

---

## `wine-glass.hsk` - the one that explains Revolve

A red wine glass, near enough to one off the shelf:

| | |
|---|---|
| overall | 3.43" across, 8.50" tall |
| foot | 3.20" across, an eighth thick at the edge |
| stem | 0.34" |
| glass | an eighth thick at the rim |

**It is built the way a person would build it.**  Nothing in
`make-glass.pas` places a face: it draws the outline of half the glass, seen
edge on, and calls `TWorkDoc.Revolve` - the same code the tool calls.  So if
the tool changes, the model changes with it and the picture in the help stays
true.  A model traced by hand slowly stops matching the program.

The outline goes **up the outside, over the rim, back down the inside**, in to
the axis at the bottom of the bowl, and then straight down the axis to where
it started.  What that encloses is the material, so the bowl comes out hollow,
the stem solid, and the whole thing closed - 576 faces, and a slicer will take
it.  A glass drawn as a single skin looks identical on screen and is not a
thing anybody can print.

**The bowl is a curve of nine points a side, not three.**  Revolve softens the
ring a profile vertex sweeps when the outline only bends a little there, and
leaves it hard where there is a real corner.  With three points every joint is
a corner and the glass comes out banded like a barrel; with nine the bowl
reads as a curve and the only hard edges left are the two that should be hard
- the edge of the foot and the rim.  984 soft edges to 144 hard.

### Making it again

```
cd examples
fpc -Mobjfpc -Sh -Fu.. make-glass.pas
./makeglass
```

---

## Adding another

Each generator writes two things: the `.hsk` here, and a unit above with the
same drawing in it, so the program carries the example rather than needing the
folder beside it.  `uExamples.pas` is the list - a file name, a line about it,
and which unit to call.  That is the only hand-written part.

What the tests in `tests/geomtest.pas` will insist on, and they are the rules
worth keeping:

* the file and the copy inside the program are **the same bytes** - they
  drifted apart once already, when a build with a stale unit in it wrote its
  own older idea of the toy over the file and nothing noticed;
* **every face belongs to a solid**, which is what keeps `/reface` from
  throwing the model away;
* **it is a closed solid**, because an example that will not print is an
  example teaching the wrong lesson;
* and **it stands on the ground**, at z = 0, in the quarter where all three
  axes are drawn solid.
