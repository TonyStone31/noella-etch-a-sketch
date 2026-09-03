# Stretching — what Move does to attached geometry
Source: https://help.sketchup.com/en/sketchup/stretching-geometry  (fetched 2 Sep 2026)

**The whole rule:** moving geometry that is connected to other geometry stretches
the model rather than relocating a piece of it.

## What each grab stretches
| Grab a... | Result |
|---|---|
| **Face** | Stretches the entity, keeping the selected face intact. |
| **Edge** | Stretches all faces adjacent to that edge. |
| **Endpoint** | Stretches all edges and faces adjacent to that endpoint. |

## Control edges on surfaces
A surface made by extruding an arc, circle or polygon has *control edges* that
resize it without distorting it.  Hovering the Move tool over one lights it up in
a way nearby edges do not.  `View > Hidden Geometry` helps find them.

Limits: surfaces extruded from curve entities have no control edges, and a
circular cylinder stretched into an ellipse loses its own.

## Autofold
Every face in SketchUp must stay planar.  Stretching in a way that would bend a
face makes Autofold put a crease in instead.  If SketchUp is refusing the move
rather than folding, tap **Alt** while dragging (Windows) to free it.

*(Not implemented here: control edges, Autofold.)*
