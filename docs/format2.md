# The drawing file, version 2 - the grammar

Proposed 20 September 2026; this is the second go at it, the same day,
after the first had been looked at on real drawings.  **Not built.**  The program reads and writes
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
   can contradict itself.  A line has a length *or* a far end, never both.
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

Somebody who has never seen the inside of the program imagines a
four-foot cube with a circle on its top, and types it:

```
HeckersSketch 2
units = ft in

sheet 'Cube'
  box = 0; 4' east, 4' north, 4' up

  circle
    center = 2' east, 2' north, 4' up
    radius = 1'
    facing = up
  end
end
```

That is the whole file.  The hole the circle cuts in the top, and the disk
inside it, are what the program works out whenever a circle is drawn on a
face - so they need not be typed.  If a file this short, in words this
plain, does not open as that drawing, the format has failed.

## Words and marks

* UTF-8.  Keywords in lower case; **the reader does not care about case**.
* **Spaces do not matter.**  Any run of spaces or tabs is one space, and
  none is needed round `=` `,` `;` `+` `(` `)`.  Indentation is for the
  eye.  Blank lines can go anywhere.  `5'10 5/8"` is `5' 10 5/8"`.
* **Comments**: `{ like this }` on one line, or `// to the end of the line`.
  The program writes `{ }` notes of its own - `{ facing south }` - for
  orientation.  They are never read back as facts.
* **Names**: a letter, then letters, digits or `_`.  `a`, `p12`, `c1`.
* **Text**: in single quotes, a quote inside doubled -
  `'the fitter''s bracket'`.
* **The feet mark**: a `'` straight after a digit is feet.  Anywhere else
  it opens text.
* **Marks that are awkward to type** have words: `4ft` is `4'`, `6in` is
  `6"`, `90deg` is `90°`.  A `.bat` file or a shell script fights quote
  marks; it need not use any.
* **Yes and no**: `yes`, `no`.  **Nothing**: `none`.
* **Colors**: `#RRGGBB`, or one of `black white gray red orange yellow
  green blue purple brown` when it is exactly that color.

## Lengths

The top of the file says how lengths are written in it:

```
HeckersSketch 2
units = ft in          { or: in, ft, mm, m }
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

## Directions

Six words, fixed for ever, the same as the axes on the sheet and colored
like them in the source window - the number as well as the word:

| Word | Axis | Color |
|---|---|---|
| `east` / `west` | X, plus and minus | red |
| `north` / `south` | Y, plus and minus | green |
| `up` / `down` | Z, plus and minus | blue |

## Places, steps and lists

A **place** is up to three parts in any order, separated by commas; a part
left out is nought, and nought itself is `0`.

```
2' east, 3' north, 18" up
6" west, 4' up
0
```

A **step** is the same thing meaning "this far from somewhere":
`3" east`, or `3" east, 2" up`.

Wherever a place is wanted it may be a place, a **name**, or **a name and
a step**: `a`, or `a + 3" east`.

A **list** of places is separated by semicolons, and in a list **`+` and a
step means "from the one before"** - so a list is a walk, and a square is:

```
face = 0; + 4' east; + 4' north; + 4' west
```

A list of names needs only spaces: `face = a b c d`.

**A list too long for a line** is written the way an `.lfm` writes one -
an opening bracket, as many lines as it takes, a closing bracket:

```
face = (
  p1 p2 p3 p4 p5 p6 p7 p8 p9 p10 p11 p12
  p13 p14 p15 p16 p17 p18 p19 p20 p21 p22 p23 p24
)
```

The program keeps its lines under eighty characters.

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
an axis when it can.  It is not a link that is kept.  Change the `3"` and
`b` moves, and so does whatever was written from `b`; save, and the
program writes the points out again its own way, the geometry exactly as
it was left.

The program names points `a` to `z` in a block of twenty-six or fewer and
`p1`, `p2`... in a bigger one, and circles `c1`, `c2`...  Any name is read.

## Things

Every thing has two forms, and rule 7 says which is which:

```
face = e f g h                     { complete: it has an = }

face                               { a block: no = on this line }
  points = a b c d
  hole   = c1
  paint  = orange
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
| `box` | `box = ` low corner`;` size | `at`, `size`, `paint` (none) |
| `line` | `line = ` from`;` to - and `to` may be `+` a step | `from`, then `goes` (a step) *or* `to`; `ink`, `width`, `soft` (no), `ref` (no) |
| `circle`, `arc` | - | `center`, `radius`, `facing`; `starts` (0°), `sweep` (arc only), `sides`, `ink`, `width` |
| `face` | `face = ` its outline | `points`, `hole` (as many as there are), `paint` (the solid's), `ink` |
| `solid` | - | `paint` (none) - what its faces are made of unless they say otherwise; its `points`, `face`s, and the exceptions among its edges |
| `edge` | `no edge = a b` - a face's side with no edge on it | `between`, and what is unusual: `soft`, `ink`, `width` |
| `bore` | - | inside a solid: `points`, `goes` (a step) |
| `group` | - | `locked` (no), and everything inside it, groups included |
| `dim` | - | `from`, `to`, `off` (a step); `label` (the measured length), `ink` |
| `note` | - | `at`, `text` (one line each, repeated); `to` (nowhere), `size` (1), `ink` |
| `guide` | `guide = ` two places - or one, which is a guide point | - |

* **An outline can be a name.**  A circle that is named is an outline:
  `face = c1` is the disk inside circle `c1`, and `hole = c1` is that
  circle cut out of a face.  Thirty-two corners become two letters.
* **`box`** is a solid that is nothing but a box square to the axes: eight
  corners, six whole faces, ordinary edges, one paint or none.  The
  moment it is anything more - a hole in its top, one face painted - it
  is written as the `solid` it is.  Both read the same.
* **`goes` or `to`.**  `goes = 4' east` when the line runs along an axis,
  `to = ` a place when it does not.  Both are read; never both at once.
* **A solid's edges are its faces' sides.**  They are not listed.  What is
  listed is what is unusual: an edge that is soft, or inked, or heavier; a
  side with no edge on it; and any `line` in the solid that is not the side
  of a face.
* **`facing`** is the way a flat thing looks: `up`, `north`, `east`, their
  opposites, or three numbers for anything else - `facing = 0.5 east,
  0.5 north, 0.7071 up`.  Turning is anticlockwise seen from the side it
  faces.  `starts` is measured from east for a thing facing up or north,
  from north for one facing east; on any other plane it is
  `starts toward = ` and a direction.
* **A face's outline** goes round anticlockwise seen from the front, which
  is the side `paint` is on.  A `hole` goes round the other way.

## What may be left out

The program works flat areas out for itself: close a loop of lines and
there is a face; draw a circle on a face and the face has a hole and the
circle has a disk.  It does this after every edit, and it does it after
reading a file.  So somebody typing a drawing types the lines, the boxes
and the circles, and **does not type the faces those make**.

The program *does* write them, because they carry things that are the
person's: paint, which way they face, and having not been rubbed out.
Which leaves one thing to say when it is so: `no face = c1` - the disk
was rubbed out, and the circle is an opening.

## The sheet

```
sheet 'Robot'
  shows  = ft in                   { what the rulers and readouts say }
  scale  = 1/4" to 1'
  snap   = 1/16"
  view   = 3d                      { or: plan, iso }
  camera = 98° round, 12° up, 15.2 times, centered 812, 2640
  ink    = #201C1A                 { the default for everything on it }
  width  = 1
  sides  = 24
  ...
end
```

A file is its header and then one `sheet` block for each sheet.

## What the program writes for that cube

Drawn with the mouse and shown in `/source` - thirty-seven lines, where
version 1 has eighteen lines of numbers and a thirty-two-cornered hole:

```
circle c1
  center = 2' east, 2' north, 4' up
  radius = 1'
  facing = up
end
solid
  points
    a = 4' up
    b = a + 4' east
    c = b + 4' north
    d = a + 4' north
    e = d + 4' down
    f = e + 4' east
    g = f + 4' south
    h = g + 4' west
  end
  face   { facing up }
    points = a b c d
    hole = c1
  end
  face = e f g h   { facing down }
  face = h g b a   { facing south }
  ...
end
face = c1   { facing up }
```

It is a `solid` and not a `box` because its top has a hole in it.

## The awkward case

A bracket turned 17° about the vertical.  Nothing in it runs along an axis
any more, and this is what it costs:

```
solid
  points
    a = 1' east, 2' north
    b = a + 3.8252190" east, 1.1694869" north     { 4" long, 17° north of east }
    c = b + 0.5847434" west, 1.9126095" north     { 2" long }
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
* **Single letters for the directions** - `4' e, 2' n` - were considered
  and left out: `e`, `n`, `s`, `u`, `d` and `w` are the names the program
  gives corners, and a word that is sometimes a point is a trap.
