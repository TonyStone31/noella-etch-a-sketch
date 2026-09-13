# Which way a face points

A face has a front and a back.  The front takes the material; the back is
drawn in a pale blue that means nothing else, so a face that is inside out
can be seen at a glance rather than found later when something behaves oddly.
SketchUp works this way and it is worth copying exactly: a model where every
face is the same white reads worse.

## How a new face is wound

* A face built by **push/pull** is part of a solid.  Its winding is worked out
  on purpose, outwards, and nothing second-guesses it.  A closed solid never
  shows a back at all, because its backs are culled.
* Every other face - one you draw, one the region finder fills in behind you -
  is wound to face along whichever **axis it is squarest to, positively**.
  That is a guess, and it is the same guess SketchUp falls back on.

The guess gets a roof right: both slopes of a roof under 45 degrees are
squarest to blue, so both face the sky.  It cannot get the two ends of a barn
right.  They are back to back, they are both squarest to red, they therefore
both face the positive way along red, and one of them shows its back to
anybody standing outside it.  Nothing in a drawing of loose faces says which
side of a wall is outside, so nothing can work it out.

## Reverse Face

Right-click a face with the select tool and choose **Reverse Face**.  That is
the last word on which way it points.  Several faces selected reverses all of
them at once; `/reverse` does the same from the command bar.

## Where we differ, deliberately

* SketchUp also has **Orient Faces**, which spreads one face's sense outwards
  across shared edges.  We do not.  It cannot be made to work everywhere it
  would be asked: a house has edges where three faces meet - the top of a
  wall, the wall under it, the gable standing on it - and no winding of the
  three can make them all agree.
* The real answer is knowing which side is outside, and only a closed solid
  knows that.  `TODO.md` carries it under Open questions.
