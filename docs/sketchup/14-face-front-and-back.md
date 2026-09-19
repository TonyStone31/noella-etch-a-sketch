# Which way a face points

A face has a front and a back.  The front takes the material; the back is
drawn in a pale blue that means nothing else, so a face that is inside out
can be seen at a glance rather than found later when something behaves oddly.
SketchUp works this way and it is worth copying exactly: a model where every
face is the same white reads worse.

**A material is not a pen color, and ours used to be** (fixed 17 September
2026).  A face carried only the ink of whatever drew it, at eight percent
over the near-white default, so a face painted red came out (250, 230, 226)
before the shading had even had a go at it - a warm gray.  The eight percent
was not timidity for its own sake: one field held both the pen and the
material, so any more than a hint would have turned every face drawn with a
red pen red.  Faces now have a material of their own, unset until somebody
paints one, and a painted face shows that color at full strength with the
shading still multiplying it.  The entity panel paints, and paints every
picked face at once.  Not built: named materials, textures, a materials
browser, and painting the back separately from the front.

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
