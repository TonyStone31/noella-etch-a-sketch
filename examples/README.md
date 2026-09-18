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

The logo is **raised off the body by a sixteenth**, the way it is moulded
into the real one - a name printed flat reads as a sticker.  It is raised
with `TWorkDoc.PushPull`, the code the tool runs, so a letter comes up the
way it would come up under somebody's hand.

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

## `broom.hsk` - the one that explains materials

A kitchen angle broom, the kind that stands behind a door:

| | |
|---|---|
| overall | 11.5" wide, about 53" tall |
| head | 11.5" x 2.6" x 2", blue, 5.4" off the floor |
| bristles | 170 of them, 5 rows of 34, cut on a slant |
| handle | 46", leaning back 14 degrees out of the head |

**It is here because nothing else in the folder is coloured.**  The toy and
the glass are both near-white, which is what a face looks like when nobody
has painted it, and until the 17th that was the only thing a face could look
like.  Every face on this one carries a **material** - and not one carries a
pen colour, which is the distinction the whole change was about.

Two things in `make-broom.pas` were arrived at by looking rather than by
reasoning, and both are worth knowing before anybody "tidies" them:

* **The bristles carry no edges at all.**  A bristle is a tenth of an inch
  across and would carry twelve of them.  With edges on, a hundred and
  seventy of them came out as one black wedge at any zoom you would actually
  use - the ink swallowed the colour completely.  Without them the material
  is all there is, which is what a bristle should be, and the model went from
  3,724 things to 1,324.
* **Every bristle is a little different.**  All the same length and dead
  straight reads as a comb rather than a broom, so each gets its own tip
  height and a nudge sideways from a hash of where it sits.  The same broom
  comes out every time; there is just no pattern in it the eye can pick up.

Each solid - every bristle, the block, the handle, each band - is a closed
run of faces wound outwards with a **group of its own**, which is what stops
the region finder merging bristles into each other where they nearly touch.

At 1,108 faces it is also the heaviest thing in the folder, which makes it
the honest one to open when somebody wants to know how the program handles a
real model: about 15 ms a frame in an orbit view.

### Making it again

```
cd examples
fpc -Mobjfpc -Sh -Fu.. make-broom.pas
./makebroom
```

---

## `robot.hsk` - the one built out of another model

A robot six foot two, standing, with **the etch-a-sketch set in his chest**
at fifty inches - about where a light switch goes, and about where your
hands are when you are standing at something.  Tony: "as if someone could
walk up to the robot and sketch something."

| | |
|---|---|
| overall | 74" tall, 30" across the hands |
| torso | 21 x 10 x 23, the toy on a red bezel at its middle |
| arms | ball joint at the shoulder, ball at the elbow, two fingers |

**The toy is not drawn again.**  It is loaded out of `uExample` - the same
drawing every help picture uses - stood on end with a quarter turn about
red, and set on the chest.  A model built out of another model, which is
what anybody would do.  If the toy is improved, the robot gets it.

That is also the clearest argument in the folder for **parts**
(`docs/groupplan.md`): `PlaceDrawing` in the generator copies every line and
face and hole across, because there is no way yet to say "one of those,
here."  When parts arrive this becomes a placement instead of a second set
of geometry.

Two things learned putting him together, both worth keeping:

* **The arms floated the first time**, because the shoulders were typed as
  66 inches and the top of the torso works out at 62 and a half.  Every
  height is derived now - `TORSO_T`, `SHZ` - rather than typed.
* **A ball with eighteen segments by nine speckles.**  The facets come out
  under a pixel at the size anybody looks at him and the flat shading turns
  to noise; twelve by six reads as a ball.  The same lesson the pipe taught
  from the other end.

### Making it again

```
cd examples
fpc -Mobjfpc -Sh -Fu.. make-robot.pas
./makerobot
```

---

## `ball.hsk` - the one that is worked out rather than drawn

A size five football, 8.65 inches across, which is the size it is on the
shelf.  Twelve black pentagons and twenty white hexagons - a truncated
icosahedron.

**Nothing in it is typed in but twelve points and the golden ratio.**  Start
with an icosahedron: twelve corners, twenty triangles, its corners at the
cyclic permutations of (0, ±1, ±φ).  Cut every corner off a third of the way
along each edge meeting it.  What was a corner becomes a pentagon; what was a
triangle becomes a hexagon.  The generator does exactly that - it finds the
edges by distance and the triangles by mutual adjacency, so the panel layout
is derived and not a table somebody transcribed.

Each panel is a thin slab pulled slightly in from its own edge and laid on
the sphere, standing off a dark inner ball.  That is what makes the seams
read as seams: the gaps between the panels show the dark ball behind them.

**One number that mattered.**  The inner ball started at 0.955 of the radius
and the panels are a quarter inch thick, which left it four hundredths of an
inch under them - closer than the depth buffer can keep apart, so the dark
ball came up through the middle of every panel in patches.  At 0.88 the
seams are deep and nothing fights.  The same lesson as anything else drawn
too close to itself.

### Making it again

```
cd examples
fpc -Mobjfpc -Sh -Fu.. make-ball.pas
./makeball
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
