# The drawing file, version 2 - the grammar

Proposed 20 September 2026; this is the third go at it, the same day,
each one after the last had been looked at on real drawings.  **Not built.**  The program reads and writes
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
    a = x 0 y 0 z 0          // on the floor
    b = a + x 4'
    c = b + y 4'
    d = a + y 4'
    e = a + z 4'             // and the same four, 4 feet up
    f = b + z 4'
    g = c + z 4'
    h = d + z 4'
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

  circle
    center = x 2' y 2' z 4'
    radius = 1'
    facing = up
  end
end
```

Nothing in that needs explaining to somebody who has not seen it before,
and none of it had to be in that order or spaced that way.  The six faces,
the hole the circle cuts in the top and the disk inside it are what the
program works out whenever lines close a loop or a circle is drawn on a
face - so they are not typed.  A point could equally have been written
where it is used: `line = x 0 y 0 z 0 to x 4' y 0 z 0`.

## Words and marks

* UTF-8.  Keywords in lower case; **the reader does not care about case**.
* **Spaces do not matter.**  Any run of spaces or tabs is one space, and
  none is needed round `=` `+` `(` `)`.  Indentation is for the eye.
  Blank lines can go anywhere.  `5'10 5/8"` is `5' 10 5/8"`.
* **Comments are Pascal's**: `// to the end of the line`, or `{ like this }`.
  The program writes `{ }` notes of its own - `{ facing up }` - for
  orientation.  They are never read back as facts.
* **Names**: a letter, then letters, digits or `_`.  `a`, `p272`, `c1`.
  Not `x`, `y` or `z`.
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

## Where a thing is: x, y and z

The same three letters the program shows at the top of its window, and
the same three colors as the axes on the sheet - in the source window the
letter and its number are colored together.

| | Runs | On the sheet |
|---|---|---|
| `x` | across the floor | the red axis |
| `y` | across the floor, square to x | the green axis |
| `z` | **up from the floor** - `z 0` is on it, `z 1"` an inch above, `z -1"` an inch below | the blue axis |

A **place** is all three, always, so that the height is there to be seen:

```
x 1" y 1" z 0          // sitting on the floor
x 1" y 1" z 1"         // the same spot, an inch up
```

Any order, and commas between them if you like them.  A number carries its
own sign: `x -4 3/8"`.

A **step** is how far from somewhere, and says only what changes:
`x 4'`, or `x 3" z 2"`.

Wherever a place is wanted it may be **a place, a name, or a name and a
step** - `x 1" y 1" z 0`, or `a`, or `a + z 1"`.  Names are a convenience,
never a requirement.

A **list of places** is joined with `to`, and in a list **`+` and a step
means "from the one before"** - so a list is a walk, and a square is:

```
face = x 0 y 0 z 0 to + x 4' to + y 4' to + x -4'
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
  a = x -4 3/8" y -4 1/2" z 5' 10 5/8"
  b = a + x 3"
  c = b + z 2 3/8"
  d = a + z 2 3/8"
end
```

`b = a + x 3"` is a way of *writing down where b is*, chosen by the
program when it saves because it reads well: from an earlier point, along
one axis when it can.  It is not a link that is kept.  Change the `3"` and
`b` moves, and so does whatever was written from `b`; save, and the
program writes the points out again its own way, the geometry exactly as
it was left.

The program names points `a` to `w` in a small block and `p1`, `p2`... in a
bigger one, and circles `c1`, `c2`...  Any name is read.

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

**Rule 7, in full:** a line with `=` is complete - unless what follows the
`=` opens a bracket, and then it runs to the line that closes it.  A line
without `=` opens a block, and `end` closes it.

### What there is

| Thing | Short form | In a block (default) |
|---|---|---|
| `line` | `line = ` one point ` to ` the other | `points`; `ink`, `width`, `soft` (false), `ref` (false) |
| `circle`, `arc` | - | `center`, `radius`, `facing`; `starts` (0°), `sweep` (arc only), `sides`, `ink`, `width` |
| `face` | `face = ` its outline | `points`, `hole` (as many as there are), `paint` (the solid's), `ink` |
| `solid` | - | `paint` (none) - what its faces are made of unless they say otherwise; then its `points`, `face`s and `line`s |
| `bore` | - | inside a solid: `points`, `goes` (a step) |
| `group` | - | `locked` (false), and everything inside it, groups included |
| `dim` | - | `from`, `to`, `off` (a step); `label` (the measured length), `ink` |
| `note` | - | `at`, `text` (one line each, repeated); `to` (nowhere), `size` (1), `ink` |
| `guide` | `guide = ` two places - or one, which is a guide point | - |

* **A line is two points.**  Which comes first does not matter, and the
  line says nothing about its direction or its length - the two points do,
  and so there is one way to write a line and one number to change.
* **An outline can be a name.**  A circle that is named is an outline:
  `face = c1` is the disk inside circle `c1`, and `hole = c1` is that
  circle cut out of a face.  Thirty-two corners become two letters.
* **`facing`** is the way a flat thing looks: `up`, `down`, `+x`, `-x`,
  `+y`, `-y`, or three numbers for anything else -
  `facing = x 0.5 y 0.5 z 0.7071`.  Turning is anticlockwise seen from the
  side it faces.  `starts` is measured from x for a thing facing up or
  along y, from y for one facing along x; on any other plane it is
  `starts toward = ` and a direction.
* **A face's outline** goes round anticlockwise seen from the front, which
  is the side `paint` is on.  A `hole` goes round the other way.

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
circle c1
  center = x 2' y 2' z 4'
  radius = 1'
  facing = up
  sides = 24
end
solid
  points
    a = x 0 y 0 z 4'
    b = a + x 4'
    c = b + y 4'
    d = a + y 4'
    e = d + z -4'
    ...
  end
  face   { facing up }
    points = a b c d
    hole = c1
  end
  face = e f g h   { facing down }
  face = h g b a   { facing -y }
  ...
  line = h to g
  line = g to f
  ...
end
face = c1   { facing up }
```

## The awkward case

A bracket turned 17° about the vertical.  Nothing in it runs along an axis
any more, and this is what it costs:

```
solid
  points
    a = x 1' y 2' z 0
    b = a + x 3.8252190" y 1.1694869"      { 4" long, 17° round from x }
    c = b + x -0.5847434" y 1.9126095"     { 2" long }
    ...
```

The numbers are ugly because they are ugly; the note beside them says what
a person wants to know.  A later version could let the solid carry
`turned = 17°` and keep its points square - that is an addition, which
rule 8 allows, and it is not needed to begin.

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
* **Round solids.**  A cylinder is forty-eight corners with ugly numbers
  and twenty-four walls.  A `ring` in a points block - center, radius,
  sides, facing, which names `r1` to `r24` at a stroke - and a range in a
  list, `face = r1..r24`, would cut it to a third.  Wanted, not yet drawn
  up.
* **Soft edges on round things.**  A cylinder of twenty-four sides has
  twenty-four soft edges, and an `edge` block each is a hundred lines that
  say one thing.  A solid-level `soft edges = a i, b j, ...` would say it
  in one.
* Whether a **solid may be named** by the program (`solid 3`) so a script
  can point at it, or only by a person.
* Whether `turned`, and a `box` that says only corner and size, are worth
  having: they read beautifully and they are a second way to say a thing.
* What the source window does with a drawing of fifteen thousand things -
  the text is built for what is shown, or for all of it.
* **What was tried and dropped**, so it is not tried again by accident:
  `east`/`north`/`up` for the axes (the first two goes) - they read well
  in a sentence and were one more thing to keep straight, where `x y z`
  is what the program already shows; `above the floor` - too many words;
  `box` as a statement of its own - a second way to say what twelve lines
  say; `goes = 4' east` on a line - a line is two points; `yes`/`no`.
