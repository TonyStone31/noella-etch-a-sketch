# Erase and Undo
Source: https://help.sketchup.com/en/sketchup/erasing-and-undoing  (fetched 2 Sep 2026)

## Undo
Reverses the last action, and names it in the Edit menu ("Undo Push/Pull").
Default shortcut **Alt+Backspace**; **Ctrl+Z** also works.  Anything undone can
be redone.

## The Eraser tool
* **Click an edge** — erases that edge *and any faces it bounds*.
* **Click and drag over several lines** — every line highlighted **blue** is
  erased when the button is released.

> "The Eraser tool doesn't allow you to erase faces.  Technically, faces are
> erased when you erase their bounding edges, opening and reshaping your
> geometry."

It can also soften, smooth or hide parts of the model.

## The Erase context command
Right-click a face or edge and choose **Erase** — *this* is what removes a face
on its own.  Selecting several things first and right-click > Erase removes them
all.

## Where we differ, deliberately
* Our eraser highlights the sweep in **red**, not blue, because blue is what we
  use for the selection and the two would read the same.
* Our eraser will delete a bare face if the cursor is over one and not over an
  edge.  In SketchUp that is the right-click Erase command.  We now have that
  too — right-click with the select tool and Erase is on the menu — so the
  eraser's own behaviour here is a convenience rather than the only way in.
* Delete on a selection does the same thing from the keyboard, and it does
  delete faces.
