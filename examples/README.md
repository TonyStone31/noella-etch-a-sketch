# Example drawings

## `etch-a-sketch.hsk` - the house model

The drawing every help picture uses.

One model across all of them is worth more than a good model in each: somebody
reading about the line tool and somebody reading about push/pull are then
looking at the same object from two angles, and there is one less thing to
work out on every page.

It is a toy etch-a-sketch, near enough to the real one's size:

| | |
|---|---|
| body | 12" x 9" x 1 1/4" |
| screen | 9" x 5 1/2", recessed 1/8" |
| knobs | 1 1/4" across, standing 3/8" proud |
| overall | 12.00 x 9.00 x 1.67 in |

Three closed solids - the body and the two knobs - so nothing shows a blue
back and it exports to STL as a printable object.  It sits centred on the
origin, left to right and front to back, and rests on the ground the way a toy
rests on a table, so the axes run through the middle of it rather than off one
corner.

**The robot on the screen is lines, not faces**, exactly as a real
etch-a-sketch drawing is.  That is on purpose and it is the model's other job:
the push/pull page can click one of the robot's squares, let the region finder
make a face out of it, and lift the robot's head clean off the screen.  A
picture of that is worth three paragraphs about how faces are derived.

### Making it again

`make-etch-a-sketch.pas` writes it.  Everything in it is in inches and divided
by twelve on the way out, because the drawing's unit is the foot and nobody
thinks about a toy in feet.

```
cd examples
fpc -Mobjfpc -Sh -Fu.. make-etch-a-sketch.pas
./make-etch-a-sketch
```

It is kept because a model you cannot change is a model that slowly stops
matching the pictures: when a tool changes and the picture needs redoing, the
model needs to be adjustable, not traced.
