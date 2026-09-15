# Screenshots this help wants

One per line, with what should be in it.  Drop them in this folder under
exactly these names and the pages pick them up - nothing else needs
changing.

Take them at a sensible window size with the PRO Dark theme, and keep the
drawing simple: the point of each one is the tool, not the model.

## How they get taken

Not by hand.  `tools/help-shots.txt` is a script for the same rig the drive
tests use - a nested X server, the program driven by hidctl - and it writes
straight into this folder under the names below:

    tools/xephyr.sh tools/help-shots.txt

It needs Xephyr and LazHIDControl, the same as `tests/run-drive.sh`.  It runs
a copy of the program in a folder of its own, so nothing it does - including
the `/update never` at the top, which keeps the "a newer build is available"
nag out of the corner of every picture - reaches the copy you are sitting in
front of.

Adding one is three lines: put the tool in hand, put the pointer where the
picture wants it, and `shot docs/help/shots/<name>.png`.  Screen positions
come from looking at a shot you have already taken; the example drawing opens
in the same place every time, which is what makes that work.  Then swap the
`shot-missing` div on the page for an `<img>`.

Five are done - `tool-circle`, `tool-push`, `commands`, `typing` and
`recording` - and they are the worked examples to copy.

- `tool-select.png` - The Select tool in use.
- `tool-line.png` - The Line tool in use.
- `tool-rect.png` - The Rectangle tool in use.
- `tool-circle.png` - The Circle tool in use.  DONE
- `tool-arc.png` - The Arc tool in use.
- `tool-push.png` - The Push/Pull tool in use.  DONE
- `tool-revolve.png` - The Revolve tool in use.
- `tool-move.png` - The Move tool in use.
- `tool-rotate.png` - The Rotate tool in use.
- `tool-offset.png` - The Offset tool in use.
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
