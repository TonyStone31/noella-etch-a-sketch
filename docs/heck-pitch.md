# Your drawing is text.  You can read it.

> **A draft, written ahead of the work - 21 September 2026.**  It describes
> Heck and JIGs *as if they were finished*, to see whether the idea sells.
> What exists today is the read-only source window (`/source`).  Reading
> Heck back, Apply, sums, constants and JIGs are not built.  Nothing in
> this page goes in the README or the manual until the thing it describes
> is real.  The plan is `docs/format2.md`.

## The pitch

Every 3D program that can be scripted makes you learn its scripting.  An
API.  An object model.  A language you did not choose, a console you did
not ask for, and four hundred pages of reference before the first box.

Heckers Sketch does not have an API.  **It has a file you can read.**

A drawing is written in **Heck**, a plain-text language that a person can
read out loud:

```
points
  eave  = 0 east, 0 north, 8' up
  ridge = eave + 12' east + 4' up
end

line Rafter
  points = eave to ridge
  ink    = red
end
```

That is not an export, and it is not a script that *produces* the
drawing.  It **is** the drawing.  Open the source window and it is there
beside the model, live.  Draw a line and watch its text appear.  Click a
face and its block lights up.  Click a line of text and the thing it
describes is picked on the sheet.  Change `12'` to `14'`, press Apply, and
the rafter is longer.

Both directions, always.  The text draws the model, and the model writes
the text.

## If you can type it, you can script it

Because the drawing is text, *anything that can write text can draw*:

* a **`.bat` file** somebody at the shop wrote in ten minutes;
* a shell script, Python, Perl, Ruby - whatever is already on the machine;
* **Pascal**, compiled on the spot with `instantfpc`, with a small unit
  that turns `Line(a, b)` into the words;
* **an AI**, yours, running wherever you run it.  The whole language fits
  on one page, so paste the page in and ask for a staircase.

There is nothing to install, no SDK, no plugin manager, and no version of
our API for your code to break against - there is no API.

## Numbers that work things out

Heck does sums, and it has constants, and that is where it stops:

```
const
  Width = 4'
  Gap   = Width / 8
end

b = a + Width east
c = b + (Width - Gap) / 2 north
```

Change `Width` and everything written from it moves.  It is a
spreadsheet, not a program: no loops, no conditions, nothing to debug.
Drag a corner with the mouse and its formula quietly becomes a number,
with a note beside it saying what it used to be.

## JIGs - Just Include Geometry

For everything a spreadsheet cannot do, there is the **JIG**: *any program
that prints Heck.*

```
group 'Hangers'
  jig = 'hangers' with Count = 6, Spacing = 16", Drop = Height
end
```

The program runs your JIG, hands it those values, and whatever it prints
becomes the group.  Change `Count` to seven, run it again, seven hangers.

If you built web pages in the nineties you already know this: it is a
**server-side include**, on a sheet instead of a server.  Your JIG can be
twelve lines of batch file or a compiled program with a physics engine in
it.  We never know and never care.  It gets `name = value` lines; it
prints Heck.

And it is safe in the way office macros never were:

* **Nothing runs when a drawing is opened.**  The file keeps the last
  result, so a drawing opens anywhere, with or without the JIG.
* **A drawing names a JIG; it never carries one.**  JIGs live in your own
  folder.  A file from a stranger is geometry with a line of text on it.
* **You press the button.**  Every run is something a person asked for.

## Next to the others

| | How you script it | Can the model write the script back? | What you must learn first |
|---|---|---|---|
| **Heckers Sketch** | Edit the drawing's own text, or print more of it from any language | **Yes - it is the same text, live, both ways** | One page |
| OpenSCAD | Its own programming language; the program *is* the model | No - there is no drawing by hand at all | A language |
| SketchUp | Ruby, against its object model | No | Ruby and the API |
| FreeCAD | Python, against its object model; a macro recorder | Partly - it records what you did as Python | Python and a very large API |
| Blender | Python, against its object model | No | Python and a very large API |
| ZCAD | Lape (Pascal Script) inside the program | No | The script engine's API |
| Fusion, Onshape | Their own API or FeatureScript, in their cloud | Onshape's features are script underneath | A language, an account |

Every one of those is more powerful than a text file, and that is the
point of this page: **most people do not want power, they want six
hangers at sixteen inches.**  The others give you a programming
environment and ask you to become a programmer.  This gives you the
drawing, in words, and lets you use whatever you already know - including
nothing but a text editor.

## In one breath

*A SketchUp-style sketcher whose drawings are readable text, editable
from either side, live - with sums, constants, and a JIG for everything
else.  If you can read it you can change it; if you can print it you can
script it.*
