# The drawing file, version 2 - the grammar

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

  circle
    center = 2' east, 2' north, 4' up
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
* **`facing`** is the way a flat thing looks: `up`, `down`, `east`,
  `west`, `north`, `south`, or three numbers for anything else -
  `facing = 0.5 east, 0.5 north, 0.7071 up`.  Turning is anticlockwise seen from the
  side it faces.  `starts` is measured from east for a thing facing up or
  north, from north for one facing east; on any other plane it is
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
  center = 2' east, 2' north, 4' up
  radius = 1'
  facing = up
  sides = 24
end
solid
  points
    a = 0 east, 0 north, 4' up
    b = a + 4' east
    c = b + 4' north
    d = a + 4' north
    e = d + 4' down
    ...
  end
  face   { facing up }
    points = a b c d
    hole = c1
  end
  face = e f g h   { facing down }
  face = h g b a   { facing south }
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

### 3. Makers - a node whose contents a script writes

Working name; it wants a better one.  (`recipe` and `made by` were the
other candidates.)  A group can say that a script makes it:

```
group 'Hangers'
  made by = 'hangers' with Count = 6, Spacing = 16", Drop = Height
  ...what the script gave back, folded, gray, the program's to write...
end
```

The program runs the script - any language: a Pascal file through
`instantfpc`, a `.bat` file, a shell script - hands it the values after
`with`, and what it prints, which is this same markup, becomes the group's
contents.  The values can be constants, so change `Count`, make it again,
and there are seven hangers.  It is a server-side include, not a script in
the page.  Three rules make it safe and none of them bends:

1. **Nothing runs when a drawing is opened.**  The file keeps the last
   result beside the `made by` line, like a spreadsheet keeping the last
   value of a cell, so a drawing opens anywhere - with no script and no
   compiler on the machine - and a drawing from a stranger, or inside a
   bug report, is geometry with a line of text on it.  Making it again is
   something a person presses.
2. **A drawing names a script and never carries one**, and the name is
   looked up in the person's own scripts folder and nowhere else - not a
   path, not a web address, nothing a file can point outside.
3. **Change the contents by hand or with a tool and the group lets go of
   its maker** - it becomes an ordinary group, and the program says so
   rather than quietly throwing the change away the next time it is made.

A script's side of it is one page: it is given `name = value` lines, it
prints markup, and what it prints goes through the same reader as any
file a stranger sent.

### The order

1. The reader, and **Apply** in the source window: nothing touches the
   drawing until the whole text has been read without a fault; a fault
   marks its line and offers to go on editing or put the text back; an
   Apply is one undo step.
2. Sums - nearly free once there is a reader.
3. Makers.
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
  `x y z` as what the program *writes* (the third go) - easy to understand
  and it does not read; the letters are still read.  `above the floor` -
  too many words; `0 up` says it.  `box` as a statement of its own - a
  second way to say what twelve lines say.  `goes = 4' east` on a line - a
  line is two points.  `yes`/`no` - Pascal says `true` and `false`.
  Executable Pascal inside the file - see "What it grows into".
