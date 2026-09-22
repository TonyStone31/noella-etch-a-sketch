# What the Heck - the drawing file, version 2

**Heck** is the language a Heckers Sketch drawing is written in: plain
text that draws, which the drawing also writes.  A markup, the way HTML is
- except that what it renders is a model and not a page.  `.hsk` files are
Heck.  This page is its grammar.

Proposed 20 September 2026; this is the fourth go at it, each one after
the last had been looked at on real drawings.  **Not built.**  The program reads and writes
version 1 today; this is the page to argue with before any of it exists.
The order of work is: agree how it *reads*, show it read-only in the source
window (`/source`) on real drawings, live with it, and only then write a
reader and save in it.

What it is for: a drawing a person can open and *understand* - this is
eighteen inches above the floor, it is four feet long, it goes east - and
change by editing the number that says so.  And a drawing any program can
change the same way, in any language, with nothing but text tools.

## The rules the rest follows from

1. **It is data, not a program.**  No variables, no arithmetic, no loops,
   nothing executed.  Every statement says one fact about one thing.
2. **One fact, one place.**  Nothing is stated twice, so nothing in a file
   can contradict itself.  A line is its two points, and its length is
   whatever that makes it.
3. **Saving loses nothing.**  What is read back is what was there.
4. **Only what differs from the default is written** - the `.lfm` habit.
   A plain black edge of ordinary width says nothing about ink or width.
5. **One statement to a line.**  So `grep`, `sed`, a `.bat` file and
   `git diff` all work on a drawing, and a line in the source window is a
   thing on the sheet.
6. **A reader skips what it does not know** - and can, because of rule 7.
7. **A line with `=` is complete.  A line without `=` opens a block, and
   `end` closes it.**  That is the whole block grammar - but for a long
   list, which runs from `(` to `)`.  It is what lets a reader that has
   never heard of `weld` skip a `weld` block correctly.
8. **Within version 2, things are only ever added.**  No word changes its
   meaning.  A change that would break that is version 3.

## The test it has to pass

Somebody imagines a four-foot cube with a circle on its top, and types it.
Everything is a line, and a line is two points:

```
HeckersSketch 2
units = ft in

sheet 'Cube'
  points
    a = 0 east, 0 north, 0 up      // on the floor
    b = a + 4' east
    c = b + 4' north
    d = a + 4' north
    e = a + 4' up                  // and the same four, 4 feet up
    f = b + 4' up
    g = c + 4' up
    h = d + 4' up
  end

  line = a to b
  line = b to c
  line = c to d
  line = d to a
  line = e to f
  line = f to g
  line = g to h
  line = h to e
  line = a to e
  line = b to f
  line = c to g
  line = d to h

  circle = 2' east, 2' north, 4' up; 1'
end
```

Or, since a box is a box:

```
box = 0 east, 0 north, 0 up; 4' east, 4' north, 4' up
circle = 2' east, 2' north, 4' up; 1'
```

Nothing in that needs explaining to somebody who has not seen it before,
and none of it had to be in that order or spaced that way.  The six faces,
the hole the circle cuts in the top and the disk inside it are what the
program works out whenever lines close a loop or a circle is drawn on a
face - so they are not typed.  A point could equally have been written
where it is used: `line = 0 east, 0 north, 0 up to + 4' east`.

## Words and marks

* UTF-8.  Keywords in lower case; **the reader does not care about case**.
* **Spaces do not matter.**  Any run of spaces or tabs is one space, and
  none is needed round `=` `+` `(` `)`.  Indentation is for the eye.
  Blank lines can go anywhere.  `5'10 5/8"` is `5' 10 5/8"`.
* **Comments are Pascal's**: `// to the end of the line`, or `{ like this }`.
  The program writes `{ }` notes of its own - `{ facing up }` - for
  orientation.  They are never read back as facts.
* **Names**: a letter, then letters, digits or `_`.  `a`, `p272`, `c1`.
  Not `x`, `y` or `z`, which are the axes' letters.
* **Text**: in single quotes, a quote inside doubled -
  `'the fitter''s bracket'`.
* **The feet mark**: a `'` straight after a digit is feet.  Anywhere else
  it opens text.
* **Marks that are awkward to type** have words: `4ft` is `4'`, `6in` is
  `6"`, `90deg` is `90°`.  A `.bat` file or a shell script fights quote
  marks; it need not use any.
* **True and false** are `true` and `false`, as in Pascal; `1` and `0` are
  read as well.  **Nothing** is `none`.
* **Colors**: `#RRGGBB`, or one of `black white gray red orange yellow
  green blue purple brown` when it is exactly that color.

## Lengths

The top of the file says how lengths are written in it:

```
HeckersSketch 2
units = ft in          // or: in, ft, mm, m
```

| `units =` | Written | Also read |
|---|---|---|
| `ft in` | `5' 10 5/8"`  `4'`  `18"`  `3/4"`  `0` | `1.5'`  `2.84"`  `5ft 10 5/8in` |
| `in` | `70 5/8"`  `3/4"` | `70.625"` |
| `ft` | `5.885'` | |
| `mm` | `1200`  `12.5` | `1200mm` |
| `m` | `1.2` | `1.2m` |

Fractions are halves down to sixty-fourths.  **A friendly form is written
only when it is exact** - when reading it back gives the stored value to
within a million-millionth of a foot, a thousand times finer than anything
the program joins or compares by.  Otherwise the number is written as a
decimal in full: `2.843721934"`.  Nearly everything somebody drew by
typing sizes comes out friendly; a corner worked out by turning something
through 17° does not, and is not rounded to look as if it did.

## Where a thing is: east, north and up

Six words.  `east`, `west`, `north` and `south` are directions across the
floor; `up` and `down` are above and below it.  They are the axes on the
sheet and wear the same colors in the source window - the number as well
as the word.

| Words | Axis | Color |
|---|---|---|
| `east` / `west` | X, plus and minus | red |
| `north` / `south` | Y, plus and minus | green |
| `up` / `down` | Z, plus and minus - `0 up` is on the floor | blue |

A **place** says all three, always, so that the height is there to be
seen, and because there is a word for each way no number in a place is
ever negative:

```
1" east, 1" north, 0 up          // sitting on the floor
1" east, 1" north, 1" up         // the same spot, an inch above it
4" west, 2' north, 6" down       // and one below it
```

Any order; the commas are for the eye.  It is longer to type than
`x 1" y 1" z 0` and it reads as a sentence, which is the bargain Pascal
makes with `begin` and `end`.  **The letters are read too** - `x 1" y 1"
z -6"` means the same, for whoever is typing fast or writing a script -
but the program always writes the words.

A **step** is how far from somewhere, and says only what changes:
`4' east`, or `3" east, 2" up`.

Wherever a place is wanted it may be **a place, a name, or a name and a
step** - `1" east, 1" north, 0 up`, or `a`, or `a + 1" up`.  Names are a
convenience, never a requirement.

A **list of places** is joined with `to`, and in a list **`+` and a step
means "from the one before"** - so a list is a walk, and a square is:

```
face = 0 east, 0 north, 0 up to + 4' east to + 4' north to + 4' west
```

A list of names needs only spaces: `face = a b c d`.

**A list too long for a line** is written the way an `.lfm` writes one -
an opening bracket, as many lines as it takes, a closing bracket.  The
program keeps its lines under eighty characters.

```
face = (
  p1 p2 p3 p4 p5 p6 p7 p8 p9 p10 p11 p12
  p13 p14 p15 p16 p17 p18 p19 p20 p21 p22 p23 p24
)
```

## Points

A block may begin with its points.  Everything in that block, and in the
blocks inside it, can use them by name - which is what makes a corner
shared by three faces *one* corner, that moves as one.

```
points
  a = 4 3/8" west, 4 1/2" south, 5' 10 5/8" up
  b = a + 3" east
  c = b + 2 3/8" up
  d = a + 2 3/8" up
end
```

`b = a + 3" east` is a way of *writing down where b is*, chosen by the
program when it saves because it reads well: from an earlier point, along
one axis when it can.  It is not a link that is kept.  Change the `3"` and
`b` moves, and so does whatever was written from `b`; save, and the
program writes the points out again its own way, the geometry exactly as
it was left.

The program names a solid's corners **by where they stand**: the lowest
are `floor1`, `floor2`... round from the one nearest the origin, the
highest are `top1`, `top2`..., anything between is `mid`, and a corner that
belongs only to a hole cut in that level is `topin1`... So a box is

```
line = floor1 to floor2        // along the floor
line = floor1 to top1          // an upright
face = floor1 floor2 top2 top1 // the south wall
```

and reads without a picture.  A solid whose corners stand at more than
three heights - something turned over, a revolve - falls back on `a`, `b`,
`c` (or `p1`, `p2`... past twenty-three).  Circles are `c1`, `c2`... and a
ring's corners `ra1`, `ra2`...  Any name is read.

### Rings

Corners spaced evenly round a circle are said once, as a **ring**: where
its middle is, how big it is, how many corners, and which way it faces.
The ring's name and a number is each corner - `ra1` to `ra24` - counted
round anticlockwise as seen from the side it faces.

```
points
  ring ra
    center = 2' east, 2' north, 2' up
    radius = 1'
    sides  = 24
    facing = up
  end
  ring rb
    center = 2' east, 2' north, 0 up
    radius = 1'
    sides  = 24
    facing = down
    starts = 15°
  end
end
face = ra1..ra24                   // the top: a run of names is its two ends
face = rb24 rb23 ra2 ra1           // one of the twenty-four walls
```

That is a cylinder: forty-eight corners in twelve lines, and not one ugly
number, where writing each corner out is forty-eight lines of them.

* **`a..b`** in a list of names is every name from one to the other,
  counting up or down.
* **`starts`** is where corner 1 is, as an angle; left out, it is nought.
  For a ring facing up or down it is measured from east.  For any other it
  is measured from the ring's **level line** - the one direction in its
  plane that is neither up nor down (`up x facing`, for whoever has to
  compute it) - and always turning anticlockwise seen from the side it
  faces.  `circle` and `arc` measure theirs the same way.
* **A ring that is not square to anything** says how it leans:
  `facing = up, leaning 30° toward east`, or `... toward 40° round from
  east` when it leans between the compass points.  When the angles are not
  clean ones it falls back on three numbers - `facing = 0.5 east,
  0.5 north, 0.7071 up` - which is harder to read and always right.
  This is the honest limit of reading a drawing as text: a thing tilted
  two ways at once is hard to picture from *any* words.

**In the source window** a name behaves as it does in Lazarus: every other
place it turns up is outlined when the caret is on it; **Ctrl and a click**
goes to the line that gives it its meaning; and **resting the pointer** on
it says what that line is - and, for a point written as a step, where that
comes to.

## Things

Every thing has two forms, and rule 7 says which is which:

```
line = a to b                      // complete: it has an =

line                               // a block: no = on this line
  points = a to b
  ink    = red
  width  = 2
end
```

The program writes the short form when nothing about the thing differs
from the default, and the block when something does.  A thing may have a
name after its kind - `circle c1`, `group 'Left eye'` - and need not.  A
group's name is text because people type it.

**There is no `begin`.**  A block opens with the word that says what it
is and closes with `end` - the way Pascal writes a `record`, a `class`, a
`case`, and the way every `.lfm` writes an `object`.  Pascal keeps `begin`
for blocks of *statements*, and there are no statements here; a `begin`
under every thing would be a line that says nothing, twelve hundred of
them in a drawing of any size.  The reader lets one pass if it is typed,
as it lets extra spaces pass; the program never writes it.

**Names are a person's.**  `line Rafter`, `solid Foot`, `group 'Left
eye'`.  The program does not invent them - `line1` to `line753` would be
noise, and would renumber the moment something was rubbed out, which is
the opposite of a name.  A name somebody gave is kept and saved.  (Points
and circles are the exception: they are named by the program because
other lines have to be able to say them.)

**Rule 7, in full:** a line with `=` is complete - unless what follows the
`=` opens a bracket, and then it runs to the line that closes it.  A line
without `=` opens a block, and `end` closes it.

### What there is

| Thing | Short form | In a block (default) |
|---|---|---|
| `line` | `line = ` one point ` to ` the other | `points`; `ink`, `width`, `soft` (false), `ref` (false) |
| `circle` | `circle c1 = ` its center `; ` its radius - `; ` which way it faces, when not up | `center`, `radius`, `facing`; `starts` (0°), `sides`, `ink`, `width` |
| `arc` | - | `center`, `radius`, `facing`, `sweep`; `starts` (0°), `sides`, `ink`, `width` |
| `face` | `face = ` its outline | `points`, `hole` (as many as there are), `paint` (the solid's), `ink` |
| `solid` | - | `paint` (none) - what its faces are made of unless they say otherwise; then its `points`, `face`s and `line`s |
| `bore` | - | inside a solid: `points`, `goes` (a step) |
| `group` | - | `locked` (false), and everything inside it, groups included |
| `dim` | - | `from`, `to`, `off` (a step); `label` (the measured length), `ink` |
| `note` | - | `at`, `text` (one line each, repeated); `to` (nowhere), `size` (1), `ink` |
| `guide` | `guide = ` two places - or one, which is a guide point | - |
| `box` | `box = ` its low southwest corner `; ` its size as a step | `at`, `size`; `paint` (none) |
| `rect` | `rect = ` a corner `; ` a size with two parts | `at`, `size`; `paint` (none) |

* **A line is two points.**  Which comes first does not matter, and the
  line says nothing about its direction or its length - the two points do,
  and so there is one way to write a line and one number to change.
* **An outline can be a name.**  A circle that is named is an outline:
  `face = c1` is the disk inside circle `c1`, and `hole = c1` is that
  circle cut out of a face.  Thirty-two corners become two letters.
* **A circle on a face cuts it.**  Once everything is read, a circle whose
  ring lies flat inside a face becomes a hole in that face, whether or not
  the face said `hole` - the tool does the same the moment a circle is
  drawn on a face.  So a `box` with a `circle` on its top is a box with a
  round hole, and `face = c1` puts the disk back in it.
* **`facing`** is the way a flat thing looks: `up`, `down`, `east`,
  `west`, `north`, `south`, or three numbers for anything else -
  `facing = 0.5 east, 0.5 north, 0.7071 up`.  Turning is anticlockwise seen from the
  side it faces.  `starts` is measured from east for a thing facing up or
  north, from north for one facing east; on any other plane it is
  `starts toward = ` and a direction.
* **A face's outline** goes round anticlockwise seen from the front, which
  is the side `paint` is on.  A `hole` goes round the other way.
* **`box` and `rect` are folds, not things of their own** - see
  `primitives.md`.  The reader expands a `box` into the eight corners,
  twelve lines and six faces a pulled rectangle would have made, and the
  writer folds a solid back to `box` only while it is exactly that: square
  to the axes, no hole, nothing pushed, one paint over the whole or none.
  Nudge a corner and the word goes and the faces are written.  A `rect` is
  four lines; its face is worked out as always, and it is written back as
  lines until the writer learns the fold.  The two parts of its size say
  the plane: `east, north` is flat; `east, up` faces south.

## What may be left out

The program works flat areas out for itself: close a loop of lines and
there is a face; draw a circle on a face and the face has a hole and the
circle has a disk.  It does this after every edit, and it does it after
reading a file.  So somebody typing a drawing types the lines and the
circles, and **does not type the faces those make**.

The program *does* write them, because they carry things that are the
person's: paint, which way they face, and having not been rubbed out.
Which leaves one thing to say when it is so: `no face = c1` - the disk
was rubbed out, and the circle is an opening.

One thing this does not yet answer: six faces that close, typed as twelve
lines, are six loose faces and not a `solid` - the program has no way yet
to make a solid out of what was drawn (TODO, "Making a solid out of what
you drew").  Until it has, a typed cube can be painted and measured but
not pushed as one.

## The sheet

```
sheet 'Robot'
  shows  = ft in                   // what the rulers and readouts say
  scale  = 1/4" to 1'
  snap   = 1/16"
  view   = 3d                      // or: plan, iso
  camera = 98° round, 12° up, 15.2 times, centered 812, 2640
  ink    = #201C1A                 // the default for everything on it
  width  = 1
  sides  = 24
  ...
end
```

A file is its header and then one `sheet` block for each sheet.

## What the program writes for that cube

Drawn with the mouse - a rectangle, pushed up, a circle on top - and shown
in `/source`:

```
circle c1 = 2' east, 2' north, 4' up; 1'
box = 0 east, 0 north, 0 up; 4' east, 4' north, 4' up
face = c1   { facing up }
```

Three lines (22 September 2026; it was twenty-six).  The circle is a
circle by name, the box folds because its own corners and faces are still
a box's - the hole in its top is the circle's doing, and the reader cuts it
again from the circle, as the tool did - and the disk inside the hole is
the circle's outline, `face = c1`.  Push one side of the box in, or nudge
a corner, and it is written as its faces again:

```
solid
  points
    floor1 = 0 east, 0 north, 0 up
    floor2 = floor1 + 4' east
    ...
  end
  face   { facing up }
    points = top1..top4
    hole = c1
  end
  face = floor4..floor1   { facing down }
  ...
end
```

## The awkward case

A bracket turned 17° about the vertical.  Nothing in it runs along an axis
any more, and this is what it costs:

```
solid
  points
    a = 1' east, 2' north, 0 up
    b = a + 3.8252190" east, 1.1694869" north     { 4" long, 17° north of east }
    c = b + 0.5847434" west, 1.9126095" north     { 2" long }
    ...
```

The numbers are ugly because they are ugly; the note beside them says what
a person wants to know.  A later version could let the solid carry
`turned = 17°` and keep its points square - that is an addition, which
rule 8 allows, and it is not needed to begin.

## What it grows into

Agreed in outline on 21 September, none of it built, and written down here
so the grammar above is judged knowing where it is headed.  **It stays a
markup and never becomes a program: no loops, no conditions, nothing that
runs when a drawing is opened.**  The reason is the one that separates
this from OpenSCAD.  There the text is a program, so the model cannot
write the text: drag one of twenty-four holes a loop made and there is no
right answer to what the loop should become, which is why OpenSCAD has no
push/pull.  A markup can always be written back.  HTML could be edited
both ways; the JavaScript in the page never could.

### 1. Sums

Anywhere a length goes, a sum may go: `+`, `-`, and `*` and `/` by a plain
number, with brackets.

```
b = a + 4' east + 8" east
c = b + (3' 6" - 3/4") / 2 north
```

Type `+ 8"` on the end of a point, press Apply, and it has moved eight
inches on the sheet.  **The program writes back the answer** - `4' 8" east`
- so the file stays plain data.  This comes nearly free with the reader.

### 2. Constants

```
const
  Width  = 4'
  Height = 2' 6"
  Gap    = Width / 8
end

points
  a = 0 east, 0 north, 0 up
  b = a + Width east
  c = b + Height up
end
```

Change `Width` and everything written from it moves.  Here the file has
to remember the *formula* as well as the answer, the way a spreadsheet
cell does - and that is the one step in this list that changes what a
drawing has to hold.  The way to do it without touching how geometry is
stored: a table beside the drawing of named points and constants - name,
formula, value.  Change a constant, work the table out again, see which
places moved, and move every corner that sat at an old place to its new
one; the faces are then worked out again as after any edit.

* **Move a point with the mouse and its formula becomes a plain number.**
  The source says so beside it - `{ was: a + Width east }`.  The same as
  typing a value over a formula in a spreadsheet.  The alternative is
  working out what `Width` would have to be, which is a constraint solver
  and another program.
* `const` and `points` blocks **fold**, like everything else.
* Names are Pascal's: a constant is `Width`, not `$width`.

### 3. Jigs - a group whose contents a script writes

A jig is what a shop makes once so that a part can be made the same way
again and again, and that is what this is.  It is also **JIG: Just
Include Geometry** - or, for those who like them that way, *JIG Includes
Geometry*.  The whole of it in a sentence:

> **A JIG is any program that prints Heck.**

A script, a `.bat` file, something compiled and enormous - what is behind
it is nobody's business but its author's.  It is handed `name = value`
lines, it prints Heck, and the drawing includes what it printed.

**If you remember SSI, you already know what a JIG is.**  Server-side
includes, from web pages in the nineties: a line in the page named a
program, the server ran it, and what it printed became part of the page.
This is that, on a sheet instead of a server.

(Settled 21 September.  `makers`, `recipe` and `made by` were the other
names tried.)  A group says that a jig makes it:

```
group 'Hangers'
  jig = 'hangers' with Count = 6, Spacing = 16", Drop = Height
  ...what the script gave back, folded, gray, the program's to write...
end
```

The program runs the script - any language: a Pascal file through
`instantfpc`, a `.bat` file, a shell script - hands it the values after
`with`, and what it prints, which is this same markup, becomes the group's
contents.  The values can be constants, so change `Count`, make it again,
and there are seven hangers.  Anybody who wrote web pages in the nineties
knows it already: it is a server-side include, on a sheet instead of a
server - and not a script in the page.  Three rules make it safe and none of them bends:

1. **Nothing runs when a drawing is opened.**  The file keeps the last
   result beside the `jig` line, like a spreadsheet keeping the last
   value of a cell, so a drawing opens anywhere - with no script and no
   compiler on the machine - and a drawing from a stranger, or inside a
   bug report, is geometry with a line of text on it.  Making it again is
   something a person presses.
2. **A drawing names a script and never carries one**, and the name is
   looked up in the person's own scripts folder and nowhere else - not a
   path, not a web address, nothing a file can point outside.
3. **A jig fills its own group and touches nothing else.**  That is what
   makes running it again always safe to reason about: the only thing
   that can change is what is inside that one block.

The group stays the jig's for good.  What it made is ordinary geometry:
it can be pushed, moved and painted on the sheet like anything else, and
the group goes on saying which jig made it.  Make a mess of it and the
cure is to **run the jig again** - which replaces what is in the group,
hand changes and all, says so before it does, and is one undo step.  (An
earlier draft had a hand edit cut the group loose from its jig.  Keeping
the tag is simpler and kinder: nothing is ever lost that Undo does not
give back.)  The source window marks a group changed by hand since it
was made - `{ changed by hand since it was made }` - so it is no
surprise when running it again puts it back.

**Two kinds, and only one of them lives in the drawing** (talked through
21 September, not settled in detail):

* The **JIG**, above - a thing in the drawing that remembers where it
  came from.  *A JIG is any program that prints Heck.*  Delphi's
  component: it sits on the form and is saved with it.
* The **jigsaw** - not in the drawing at all.  *A jigsaw is any program
  that reads Heck and prints it back changed.*  A jig helps make a thing;
  a jigsaw cuts into what is already there.  Run on purpose, from a menu
  or `/jigsaw name`; it is handed what is picked, or the sheet, as Heck,
  and hands back a changed version, which goes through the same Apply as
  an edit typed by hand: shown first, accepted or not, one undo step.
  Nothing of it is saved but what it did.  And because a drawing is a
  text file, a jigsaw does not need this program at all - it can be run
  from a command line over a folder of drawings.  (The name is the working
  one as of 21 September and may yet change; `rejig` was the other
  finalist, and stays an ordinary word - you run a jigsaw to rejig a
  drawing.  The people who write either are jigwrights.)

The same program can be either; which it is, is how it was called.  Both
are handed the drawing as Heck, which is how a jig sees every constant,
group and name there is **without there being an API**: the file format
is the API.  And Ctrl+click on a `jig =` line opens the script in
whatever edits such things on the machine.

A script's side of it is one page: it is given `name = value` lines, it
prints markup, and what it prints goes through the same reader as any
file a stranger sent.

### The order

1. The reader, and **Apply** in the source window: nothing touches the
   drawing until the whole text has been read without a fault; a fault
   marks its line and offers to go on editing or put the text back; an
   Apply is one undo step.
2. Sums - nearly free once there is a reader.
3. Jigs.
4. Constants, last, because they are the one that changes what a drawing
   remembers.

Before any of it is *saved*: the audit in TODO.md - every field version 1
stores has a home here, proved by writing a drawing out, reading it back
and comparing.

## Version 1

* **Read for ever.**  Every drawing that exists is version 1, and so are
  the examples inside the program.
* **No conversion step.**  A version 1 drawing opens as it always has and
  is written as version 2 the next time it is saved - once saving in
  version 2 exists.  Until then nothing on disk changes.
* **Save as version 1** stays, for a machine with an older build.
* **Reports** may go on sending version 1: the collector caps a report's
  size, and version 1 is compact.

## Still to settle

* **What version 1 did to the numbers.**  Found on the first real drawing
  put through this: version 1 writes feet to six places, so a drawing
  that has been saved holds 1.4 inches as 1.400004 - and every drawing
  there is has been saved.  The source window shows a value within
  version 1's own half-millionth of a foot of a friendly one as the
  friendly one (`V1_NOISE` in `uFormat2.pas`).  The question is whether
  *reading* a version 1 file should put the friendly value back for good.
  It would be right nearly always, and it is the one place the reader
  would be deciding what somebody meant.
* **The walls of a round solid** are still a line each -
  `face = rb24 rb23 ra2 ra1`, twenty-four times.  "The walls between `ra`
  and `rb`" in one line would be the next saving, if it is wanted.
* **Soft edges on round things.**  A cylinder of twenty-four sides has
  twenty-four soft edges, and an `edge` block each is a hundred lines that
  say one thing.  A solid-level `soft edges = a i, b j, ...` would say it
  in one.
* Whether a **solid may be named** by the program (`solid 3`) so a script
  can point at it, or only by a person.
* Whether `turned` is worth having - a box turned 17° said as the box
  and the turn.  (`box` itself is settled: a fold, see `primitives.md`.)
* What the source window does with a drawing of fifteen thousand things -
  the text is built for what is shown, or for all of it.
* **What was tried and dropped**, so it is not tried again by accident:
  `x y z` as what the program *writes* (the third go) - easy to understand
  and it does not read; the letters are still read.  `above the floor` -
  too many words; `0 up` says it.  `box` as a statement of its own,
  written *beside* the twelve lines - twice the truth; it came back as a
  fold, written instead of them.  `goes = 4' east` on a line - a
  line is two points.  `yes`/`no` - Pascal says `true` and `false`.
  Executable Pascal inside the file - see "What it grows into".
