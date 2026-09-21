# The drawing file, version 2 - the grammar

Proposed 20 September 2026.  **Not built.**  The program reads and writes
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
   `end` closes it.**  That is the whole block grammar.  It is what lets a
   reader that has never heard of `weld` skip a `weld` block correctly.
8. **Within version 2, things are only ever added.**  No word changes its
   meaning.  A change that would break that is version 3.

## Words and marks

* UTF-8.  Keywords in lower case; the reader does not care about case.
* **Comments**: `{ like this }` on one line, or `// to the end of the line`.
  The program writes `{ }` notes of its own - sizes, "level", "plumb" -
  for orientation.  They are never read back as facts.
* **Names**: a letter, then letters, digits or `_`.  `a`, `p12`, `front`.
* **Text**: in single quotes, a quote inside doubled - `'the fitter''s bracket'`.
* **The feet mark**: a `'` straight after a digit is feet.  Anywhere else
  it opens text.  `4'` is four feet; `'4'` is the text "4".
* **Yes and no**: `yes`, `no`.
* **Colors**: `#RRGGBB`, or one of `black white gray red orange yellow
  green blue purple brown` when it is exactly that color.
* **Angles**: `90°` or `90 deg`.  Written as `°`.
* Indentation is two spaces a level and means nothing to the reader.

## Lengths

The first lines of the file say how lengths are written in it:

```
HeckersSketch 2
lengths = feet and inches      { or: inches, feet, millimeters, meters }
```

| `lengths =` | Written | Also read |
|---|---|---|
| `feet and inches` | `5' 10 5/8"`  `4'`  `18"`  `3/4"`  `0` | `1.5'`  `2.8437219"` |
| `inches` | `70 5/8"`  `3/4"` | `70.625"` |
| `feet` | `5.885'` | |
| `millimeters` | `1200`  `12.5` | `1200 mm` |
| `meters` | `1.2` | `1.2 m` |

Fractions are halves down to sixty-fourths.  **A friendly form is written
only when it is exact** - when reading it back gives the stored value to
within a million-millionth of a foot, a thousand times finer than anything
the program joins or compares by.  Otherwise the number is written as a
decimal in full: `2.843721934"`.  Nearly everything somebody drew by
typing sizes comes out friendly; a corner worked out by turning something
through 17° does not, and is not rounded to look as if it did.

## Directions

Fixed, for ever, and the same as the axes on the sheet:

| Word | Axis | Color on the sheet, and in the source window |
|---|---|---|
| `east` / `west` | X, plus and minus | red |
| `north` / `south` | Y, plus and minus | green |
| `up` / `down` | Z, plus and minus | blue |

`above the floor` and `below the floor` mean `up` and `down`, and are what
the program writes in a place measured from the origin.  The floor is
height nought.

## Places

A **place** is up to three parts, in any order, separated by commas; a part
left out is nought.  Written east, north, up.

```
2' east, 3' north, 18" above the floor
6" west, 4' above the floor
origin
```

An **offset** is the same thing meaning "this far from somewhere":
`3" east` or `3" east, 2" up`.

Where a drawing needs a place it can have a place, a **point's name**, or
**a name plus an offset**: `a`, or `a + 3" east`.

## Points

A block may begin with its points.  Everything in that block, and in the
blocks inside it, can use them by name - which is what makes a corner
shared by three faces *one* corner, that moves as one.

```
points
  a = 4 3/8" west, 4 1/2" south, 5' 10 5/8" above the floor
  b = a + 3" east
  c = b + 2 3/8" up
  d = a + 2 3/8" up
end
```

`b = a + 3" east` is a way of *writing down where b is*, chosen by the
program when it saves because it reads well: each point from the one
before it, along an axis when it can.  It is not a link that is kept.
Change the `3"` and `b` moves, and so does whatever was written from `b`;
save, and the program writes the points out again its own way, the
geometry exactly as it was left.

The program names points `a` to `z` in a block of twenty-six or fewer and
`p1`, `p2`... in a bigger one.  Any name is read.

## Things

Every thing has two forms, and rule 7 says which is which:

```
face top = e f g h                 { complete: it has an = }

face front                         { a block: no = on this line }
  corners  = a b c d
  material = orange
end
```

The program writes the short form when nothing about the thing differs
from the default, and the block when something does.  A thing may have a
name after its kind - `face front`, `solid eye`, `group 'Left eye'` - and
need not.  A group's name is text because people type it.

### What there is

| Thing | Says | Properties (default) |
|---|---|---|
| `line` | `from`, then `goes` *or* `to` | `ink` (the sheet's), `width` (the sheet's), `soft` (no), `reference` (no) |
| `arc`, `circle` | `center`, `radius`, `facing` | `starts` (0°), `sweep` (arc only), `sides` (the sheet's), `ink`, `width` |
| `face` | `corners` | `hole` (as many as there are), `material` (none), `ink` |
| `solid` | its `points`, `face`s, and the exceptions among its edges | - |
| `edge`, `no edge` | inside a solid: an `edge` block says `between = a b` and what is unusual about it - `soft`, `ink`, `width`; `no edge = a b` where a face's side has no edge on it | - |
| `drilled` | inside a solid: `outline`, `through` (an offset) | - |
| `group` | everything inside it, groups included | `locked` (no) |
| `dimension` | `from`, `to`, `stands off` (an offset) | `label` (the measured length), `ink` |
| `note` | `at`, `text` (one line each, repeated) | `points to` (nowhere), `size` (1), `ink` |
| `guide` | `through` two places - or one, which is a guide point | - |

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
* **`corners`** go round anticlockwise seen from the front, which is the
  side a `material` is on.  A `hole` goes round the other way.
* **Faces the program worked out** from loose edges are written like any
  other, because they carry things that are the person's: paint, which way
  they face, and the fact of not having been rubbed out.

## The sheet

```
sheet 'Robot'
  shows    = feet and inches       { what the rulers and readouts say }
  scale    = 1/4" to 1'
  snap     = 1/16"
  view     = 3d                    { or: plan, iso }
  camera   = 98° round, 12° up, 15.2 times, centered 812, 2640
  ink      = #201C1A               { the default for everything on it }
  width    = 1
  sides    = 24
  ...
end
```

A file is its header and then one `sheet` block for each sheet.

## The same box, both ways

Version 1 - eighteen lines like this:

```
FACE 2104346 1 4 0.000000 0.000000 2.000000 4.000000 0.000000 2.000000 4.000000 4.000000 2.000000 0.000000 4.000000 2.000000 1
LINE 0.000000 0.000000 0.000000 4.000000 0.000000 0.000000 2104346 1.000 0 1 0
```

Version 2 - all of it:

```
solid
  points
    a = origin
    b = a + 4' east
    c = b + 4' north
    d = a + 4' north
    e = a + 2' up
    f = b + 2' up
    g = c + 2' up
    h = d + 2' up
  end
  face = d c b a                   { 4' x 4', the bottom }
  face = e f g h                   { 4' x 4', 2' above the floor }
  face = a b f e                   { 4' x 2', facing south }
  face = b c g f
  face = c d h g
  face = d a e h
end
```

To make it five feet long, change one `4'`.

## The Robot's eye

A small orange box standing off the head, in a locked group:

```
group 'Left eye'
  locked = yes
  solid
    points
      a = 4 3/8" west, 4 3/4" south, 5' 10 5/8" above the floor
      b = a + 3" east
      c = b + 2 3/8" up
      d = a + 2 3/8" up
      e = a + 1/4" north
      f = b + 1/4" north
      g = c + 1/4" north
      h = d + 1/4" north
    end
    face front                     { 3" x 2 3/8", facing south }
      corners  = a b c d
      material = orange
    end
    face
      corners  = f e h g
      material = orange
    end
    ...
  end
end
```

## The awkward case

A bracket turned 17° about the vertical.  Nothing in it runs along an axis
any more, and this is what it costs:

```
solid
  points
    a = 1' east, 2' north
    b = a + 3.8252190" east, 1.1694869" north     { 4" long, 17° north of east }
    c = b + 0.5847434" west, 1.9126095" north     { 2" long }
    d = a + 0.5847434" west, 1.9126095" north
    e = a + 1/8" up
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
* The **colors in the source window**: `east`/`west` and what they measure
  in the sheet's red, `north`/`south` green, `up`/`down` and `above the
  floor` blue; keywords bold; the program's `{ notes }` gray; text and
  materials in their own color, a material's name in the color it names.
