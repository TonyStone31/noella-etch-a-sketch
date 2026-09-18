# Parts: making a piece of a drawing a thing of its own

*Written 18 September 2026, the night the need was agreed.  Nothing here is
built.  This is what would have to be touched, and roughly in what order, so
that the size of the job is known before anybody starts it.*

## Read this first

**This is not the next thing to build.**  Tony, the same night: "we really
want to make sure we have all the issues with basic drawing functionality in
all the tools sorted out before we pile on yet another feature."

That is the right call and it is worth saying why, because it is not
impatience talking.  Everything below sits **on top of** the pick, the move,
the eraser, the region finder and the snap.  Every one of those is a thing
Tony is finding bugs in right now.  A part that moves as one is a layer over
moving; a part that does not join onto its neighbour is a layer over the
region finder.  Build the layer first and every bug underneath it has to be
fixed twice - once in the tool and once in how the tool behaves inside a
part - and worse, some of them will be *hidden* by the layer and found much
later by somebody drawing a shed.

So: **the drawing tools get sorted out, and then this.**  The plan is
written now because the reasoning is fresh, not because the work is next.

## What it is for

Tony, by report, laying the letters of a word onto the face of the
etch-a-sketch toy he was drawing:

> "i think this is why we will need to make things groups and stuff that can
> be locked ... i could have made that etchasketch a group and locked it then
> moved the letters onto its surface where i want them, then ungrouped and
> regrouped ... im struggling to properly set my letters on the face.  i had
> it once but then the hollow part of the R fought me and i needed to put the
> red face back that was underneath it."

Nothing there is a bug.  The region finder is working exactly as designed: it
takes every edge in a plane and works out what they enclose.  The letters lie
in the plane of the face, so their edges join the face's edges, the hollow of
the R becomes a hole in the panel rather than a hole in the R, and rubbing
out the R takes a piece of the panel with it.

**The missing idea is that two bits of geometry can be in the same place and
not be the same object.**  That is the whole of it.  Everything else - moving
as one, locking, a count in the entity panel - follows from that one idea and
is comparatively easy.

## What to call it

Tony: "not certain we should call it groups... But I guess that is such a
universal term.  I just am trying not to copy SketchUp verbatim."

The honest position: **the word is not SketchUp's to own.**  Illustrator,
Inkscape, Figma, Blender, Fusion, PowerPoint and every drawing program since
MacDraw call it grouping, and the verb is what people already type into a
search box when they want it.  Using the word costs nothing in originality
and saves a person one thing they would otherwise have to learn.

Where it is worth *not* copying SketchUp is the thing underneath the word.
Theirs is two ideas wearing similar coats - a **Group**, which is one-off,
and a **Component**, which is a definition with instances, so editing one
fence post changes all forty.  People find that distinction confusing and it
is the single most-asked SketchUp question there is.  Ours could have one
idea that does both: a **part** which knows how many copies of it exist, and
copies which are either linked to it or cut loose from it.  That is a better
model and it is a real difference worth having.

Proposal, to argue with later:

* the thing is a **part**;
* the menu says **Make Part** / **Open Part** / **Explode**;
* `/group` works as another word for `/part`, because that is what people
  will type;
* the help page is titled **Parts**, and says in its first line that other
  programs call this grouping.

Nothing in the code below depends on the name.  Use `Part` in the source and
the word can still change up to the day it ships.

## What exists already

`Grp: Integer` is on every entity, and about ninety lines read it.  It is
**not** a group in this sense - it is "which solid this belongs to", set by
push/pull and revolve so that pulling one box does not deform the box beside
it that shares a corner.  `NewGroup`, `SetGroup`, `SetFaceGroup` and
`GroupClosed` are its whole interface.

That is a useful precedent and a dangerous one.  Useful, because it proves an
identity field on an entity survives save, load, undo and every tool without
anybody thinking about it.  Dangerous, because it is tempting to overload it,
and it must not be: a part and a solid are different questions.  A part can
hold six solids; a solid can be cut in half and become two.  **A new field.**

## The shape of it

```pascal
{ which part this entity belongs to, or 0 for the drawing itself }
Part: Integer;
```

and, kept beside the entities rather than on them, one record per part:

```pascal
TPart = record
  Id: Integer;
  Name: string;        // 'Part 3' until somebody names it
  Locked: Boolean;
  Parent: Integer;     // 0, or the part this one sits inside
  Of_: Integer;        // 0, or the part this is a copy of - see below
end;
```

`Parent` is what makes parts nest, which they must: a drawer is a part, a
chest of drawers is a part made of drawers.  `Of_` is the copy link that
replaces SketchUp's component/group split - a part with `Of_ = 0` is its own
thing, and one with `Of_ = N` is a copy of N and takes edits made to N.  **Do
not build `Of_` in the first pass.**  Leave the field there, always zero, and
the file format already has room for the day it matters.

## What has to change, and how hard each is

Ordered by how much of the job each one is.

### 1. The region finder must stop at a part's edge - *the whole job*

`RebuildFlatFaces` in uMain collects **every** edge in the drawing into
`EdgeSegments`, hands them to `BuildRegionsCached`, and turns what comes back
into faces.  Twenty-one places call it.  That single pass is why the letters
merged into the panel.

It has to run **once per part, plus once for the drawing itself**, each with
only its own edges.  The region cache (`FRegionCache`, keyed by plane) has to
be keyed by part as well, or a plane shared by two parts will hand one part's
regions to the other.

Then the consequences, which are the actual work:

* **Splitting.**  `AddLineSplit` and `SplitCrossings` cut edges where they
  cross.  They must not cut an edge against an edge in another part - two
  crossing lines in different parts pass through each other untouched.  This
  is the same rule as the region finder, said in a second place.
* **Healing.**  `HealsThis` and the "area somebody did not want" memory are
  per-drawing and would need to be per-part.
* **Welding.**  Wherever the code decides two points are the same point -
  and it does, a lot - it must ask whether they are in the same part first.

This is the item that makes the estimate.  Everything else is small beside it.

### 2. The pick has to answer with the part, not the entity

`PickAt` asks `HitGuidePoint`, then `HitEdge`, then `HitFace`, then
`HitTest`, and hands back one entity index.  With parts:

* outside a part, a hit on anything inside it selects **the whole part**;
* inside an opened part, picking works exactly as it does now, and things
  outside the part are not pickable at all;
* a locked part is not pickable, full stop - which is precisely the thing
  Tony wanted when he said he would have locked the toy and then dropped the
  letters on it.

`BoxPick` needs the same rule, and the selection (`FSel`, a flat array of
entity indices) needs to be able to hold a part.  The cheapest honest way is
a parallel `FSelParts: array of Integer` rather than magic values in `FSel`,
because every one of the twenty-odd places that walks `FSel` and asks
`FD.Doc[I].Kind` would otherwise need to learn a new case.

### 3. Opening and closing one

The state is small - "which part is open, or 0" - and the consequences are
everywhere:

* the title bar or the crumb line says what you are inside;
* **Escape** closes the innermost open part, which is one more job for a key
  that already has several;
* everything outside the open part draws dimmed, the way SketchUp does it,
  which is a colour decision in `Render` and nothing more;
* saving while a part is open must save the drawing, not the part.

Double-click with the select tool opens a part.  That gesture is already
taken - double-click takes what is attached - so it needs thought rather than
a line of code.

### 4. Moving, erasing, and the tools

* **Move** must move a whole part when one is picked, and must not stretch
  geometry across a part boundary - the stretch rule (a corner sitting where
  a moving corner sits moves too) is exactly the thing parts exist to stop.
* **Erase** takes a part whole, or its bounding edges when opened.
* **Push/pull, offset, revolve** work inside an open part and make geometry
  that belongs to it.  Their `Grp` handling is a fair model for how to carry
  `Part` through: set it once where the geometry is made.
* **Snapping** should still find points inside a closed part - you must be
  able to line a letter up with a corner of the toy without opening the toy.
  SketchUp does this and it would be maddening otherwise.

### 5. Save and load

One `PART` line per part before the entities, and one more field on every
entity line - and **not** a new field on `FACE`, `LINE` and the rest, which
would break every older reader.  The same trick the material used this week:
a keyword line of its own.

```
PART 3 "Left knob" locked parent=0
```

and an entity's membership written as its own line after it, or - better,
because it is far fewer lines - a `PARTOF 3` line that applies to everything
following it until the next one.  A reader that has never heard of `PARTOF`
skips it and gets the drawing flattened, which is exactly the right thing for
it to get.

### 6. The entity panel

A part selected shows its name, what it holds, whether it is locked, and
buttons for Open, Explode and Lock.  This is the easy end and it is worth
doing early anyway, because it is how the rest gets tested by hand.

## What it would cost

Item 1 is most of it and it is the one that can go quietly wrong - a bug
there does not crash, it produces a face that should not exist, three edits
later.  Items 2, 3 and 4 are broad but shallow: many places, each obvious.
Items 5 and 6 are an evening each.

The thing to hold onto: **there is no half-version that is useful.**  Parts
that move as one but still merge geometry would be worse than nothing,
because they would look like they worked.  Item 1 is not optional, and item 1
is why this waits until the drawing tools underneath it are solid.

## Before any of it

A list to be filled in from the reports as they come in - the basic drawing
issues that should be closed out first.  At the time of writing:

* the pick and the eraser on crowded geometry (one fixed 17 September, the
  rim-against-wall case);
* healing a face back on a curved boundary, which needs a straight line
  traced along one facet of an arc and is impractical at a knob's scale;
* whatever this week's testing turns up.

When that list is empty, this document is the next thing.
