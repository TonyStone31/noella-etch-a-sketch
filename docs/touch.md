# Touch, tablets and the remote desktop

What was agreed on 2026-09-08, so it does not have to be argued again.

## What the toolkit does

The Lazarus GTK3 backend asks GDK for touch on every window it makes and
then does nothing with the events - it only knows their names for its
debug output.  Once a window asks for raw touch, GDK stops turning fingers
into mouse events for it.  So on a Linux touchscreen the drawing area got
nothing while the toolkit's own buttons and the window frame, which handle
touch themselves, worked.  On Windows the toolkit does nothing with touch
either, but Windows itself turns one finger into a mouse and a pinch into
Ctrl and the wheel for old-style programs, which is why it half works there.

## What is done

`uTouch.pas` connects to the form's touch-event signal on GTK3 and hands
each finger to `TMainForm.OnTouch` as it is: begins, moves, ends, cancelled,
with where it is on the screen.  The gesture layer in uMain decides:

* **one finger is the mouse**, but the press waits until the finger moves,
  or has been held a moment, or lifts.  A lift with no press sent is a tap
  and gets the press and the release together.  This is what lets a second
  finger arriving turn the first into a gesture without a stray click.
* **two fingers pan** by their middle and **pinch to zoom** by their
  spread, through the same `PanBy` and `ZoomAt` the mouse wheel uses, in
  quick frames while they move; the full frame comes when they settle.
* when one of two fingers lifts the gesture is over and the finger left
  behind is ignored until it lifts too.

`/touch` says whether the hook is in and counts the events; `/timings`
prints every finger event to the console.  Windows gets nothing of its own
yet; the hook returns False there and the mouse path is untouched.

## What comes next, in order

1. **Windows native touch**: register the window for touch messages and
   feed the same gesture layer.
2. **No hover on glass.**  Tooltips, the snap readout and the hover
   highlight assume a mouse floating over things.  On touch-down, show what
   a hover would have shown.  Deck buttons sized for fingers - most are.
3. **One button and a wheel.**  A remote desktop in a browser (Kasm) sends
   the program a mouse and a keyboard and nothing else: two fingers there
   become a wheel or a drag before we see them.  So: the wheel zooms, a
   modifier with the wheel pans, a modifier with a drag orbits, and the
   command bar carries the rest.  This helps every remote user, not only
   tablets.
4. **A point-setting control.**  A fingertip cannot place a point.  The
   idea on the table is a controller: one thumb walks the cursor up and
   down, the other left and right, by snap steps, like the toy mode's
   knobs grown up, and a tap commits.  A game pad on a desktop would drive
   the same thing.  It only moves the cursor; the snapping does the rest,
   so no tool has to change for it.

## Platforms

Android through LAMW or laz4android is plausible precisely because almost
everything on screen is our own painting on one surface; only the real
dialogs - the report form, the fitting wizards - are toolkit controls.
iPad has no Lazarus target worth the maintenance.  A remote desktop on a
tablet gets there sooner with none of that.
