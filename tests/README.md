# Tests

## `./tests/run.sh` — the headless ones

Geometry checks against `uWork` with no window: parsing, save and reload,
copying, moving and stretching, splitting, on-edge snapping, the midpoints a
crossing makes, and picking a small face off a big one.  Run it after any
change to the document model.  It compiles `uWork` fresh every time, so it
always tests what is on disk.

These catch the class of bug screenshots never will.  Two examples: every face
being silently dropped on reload, and a circle drawn on a slab being
unpickable because the two coplanar faces' depths differed by rounding.

## The standing visual test — the grid

The standing scenario, and the one that has found the most.  Do it in the GUI:

1. **A square with the rectangle tool.**
2. **Fill it in at the midpoints** to make a 6 x 6 grid — lines from the middle
   of one side to the middle of the other, then keep subdividing.  Each piece
   of every edge should offer its own midpoint to snap to as you go.
3. **Switch to the 3D view** (not ISO — both, ideally).
4. **Push a couple of cells up** to different heights.
5. **Look at the towers.**  Nothing behind them may show through: not the grid
   lines on the base, not the far edges, not a dimension.
6. **Draw circles inside some cells and push those too.**  A circle drawn on a
   face has to be pickable in its own right, and has to come up round.

What it has caught so far:

* lines on a flat face being painted back over the solids standing in front of
  them, so a box looked like glass
* faces filled with a 16 percent tint in plan
* dimensions drawn last on purpose, so every base dimension floated over the
  top of the box it belonged under
* T-junctions never cutting the line they meet, so the outer edges of a grid
  had no midpoints
* a circle on a slab never winning the pick against the slab

## Radiant routing

`./tests/run.sh radiant` runs just the radiant geometry and search checks.
The full `./tests/run.sh` includes them too. Fixtures cover obstacles, the
saved barn failure, derived manifold sizes, four-quadrant coverage from an
interior manifold, complete return lengths, deterministic search and replay.
See [the search notes](../docs/radiant-search.md) for measured improvements
and the remaining coverage limits.

## PDF export

`./tests/run-pdf.sh` builds the pure Pascal writer with runtime checks and
verifies all 21 paper sizes in both orientations, metric/imperial printed
lengths, zoom independence, holes, clipping, and SVG labels. It independently
reads PDF coordinates and rejects image objects.
The outputs are `/tmp/hsk-pdf-*.pdf`. `./tests/run-drive.sh export-dialog`
also opens the PDF controls and exports `/tmp/hsk-dialog-export.pdf` through
the real UI (remove a previous output first to avoid the overwrite prompt).
