# Screenshots this help wants

One per line, with what should be in it.  Drop them in this folder under
exactly these names and the pages pick them up - nothing else needs
changing.

Take them at a sensible window size with the PRO Dark theme, and keep the
drawing simple: the point of each one is the tool, not the model.  Draw the
smallest thing that shows what the tool does - a square and a circle is
usually the whole cast.

## How they get taken

Not by hand.  `tools/help-shots.txt` is a script for the same rig the drive
tests use - a nested X server, the program driven by hidctl - and it writes
straight into this folder under the names below:

    tools/xephyr.sh tools/help-shots.txt tools/blank.hsk

**On a clean sheet.**  These used to open the example toy and draw over it,
which put a robot and a pair of knobs behind a picture whose subject was a
circle.  Tony: "the screen shots you did in some previous help files are
stupid because you did in fact use the toy model and drew a circle over it.
The help files don't need the toy model."  `tools/blank.hsk` is an empty
sheet and every picture starts from it.  A page about one tool wants the
smallest thing that shows the tool and nothing else in the frame.

It needs Xephyr and LazHIDControl, the same as `tests/run-drive.sh`.  It runs
a copy of the program in a folder of its own, so nothing it does - including
the `/update never` at the top, which keeps the "a newer build is available"
nag out of the corner of every picture - reaches the copy you are sitting in
front of.

## Moving pictures

`tools/gif-shot.sh` records one.  It starts the same nested X server, waits
for the program to come up, and points ffmpeg at the display while the script
plays:

    tools/gif-shot.sh tools/gif-push.txt docs/help/shots/tool-push.gif \
                      tools/gif-circle.hsk

The drawing it opens is already set up - `tools/gif-circle.hsk` has the
circle on it - so everything recorded is the thing being shown and there is
nothing to trim off the front.

Two things worth knowing if you write another:

* **Walk the pointer, do not jump it.**  `at x y 700` walks it there over
  seven hundred milliseconds; `at x y` on its own is a teleport, and the
  whole point of a moving picture is seeing where the hand went.  `drag`
  takes the same trailing number.  This is LazHIDControl's timed
  `TMouseInput.Move`, which hidctl passes through.
* **It plays back a little faster than it records.**  hidctl settles after
  every step, so a script that reads as nine seconds records as twelve.
  `SPEED` in `gif-shot.sh` puts that back; `WIDE`, `FPS` and `COLORS` keep
  the file small enough to sit on a page.

Keep them short.  Nine seconds is plenty for one tool, and a help animation
that outstays its welcome does not get watched twice.

## Adding a still

Adding one is three lines: put the tool in hand, put the pointer where the
picture wants it, and `shot docs/help/shots/<name>.png`.  Screen positions
come from looking at a shot you have already taken; the example drawing opens
in the same place every time, which is what makes that work.  Then swap the
`shot-missing` div on the page for an `<img>`.

Eight are done - `tool-rect`, `tool-line`, `tool-circle`, `tool-push`,
`tool-offset`, `typing`, `commands` and `recording` - and they are the worked
examples to copy.

- `tool-select.png` - The Select tool in use.
- `tool-line.png` - The Line tool in use.  DONE
- `tool-rect.png` - The Rectangle tool in use.  DONE
- `tool-circle.png` - The Circle tool in use.  DONE
- `tool-push.png` - The Push/Pull tool in use.  DONE
- `tool-push.gif` - Picking the tool and raising a circle.  DONE
- `tool-revolve.png` - The Revolve tool in use.
- `tool-move.png` - The Move tool in use.
- `tool-rotate.png` - The Rotate tool in use.
- `tool-offset.png` - The Offset tool in use.  DONE
- `tool-drill.png` - The Drill tool in use.
- `tool-erase.png` - The Erase tool in use.
- `tool-measure.png` - The Measure tool in use.
- `tool-dim.png` - The Dimension tool in use.
- `tool-protractor.png` - The Protractor tool in use.
- `tool-text.png` - The Text tool in use.
- `tool-orbit.png` - The Orbit tool in use.
- `export.png` - Exporting.
- `recording.png` - Recording a move.  DONE
- `printing.png` - Printing.
- `plan.png` - The plan view.
- `typing.png` - Typing measurements.  DONE
- `solids.png` - Solids and 3D printing.
- `reporting.png` - When it breaks.
- `commands.png` - The command list, open and narrowed: a slash typed, a couple of letters after it, the list showing what matched.  DONE
- `keys.png` - The hint line naming the keys for the tool in hand.
