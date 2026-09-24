# Radiant routing search — 24 September 2026

The router now restarts from an empty floor with twelve combinations: both
perpendicular row directions, first-circuit budgets of 100%, 75% and 50%,
and a manifold fan band of thirteen inches or three feet. Within each
attempt it tries circuit-length limits and scores uncovered row area,
circuit count and length spread. Both directions along both axes are
available when the manifold is inside the room. The four quadrants need not
produce matching circuits. It also retries with two, four, six and eight
additional lane ranks so the initial loop-count estimate cannot silently
become a fixed manifold size. An open 40-by-40-foot square at nine-inch
spacing improves from seven circuits / 83% sampled coverage to nine
circuits / 93%.

No manifold size is required as input. The legacy `Spec.Ports` hint does
not limit routing. Required ports come from the completed circuits; the
wizard returns those counts and no longer contains a size selector.

A rejected candidate restores the rows it tentatively reserved. Before a
candidate is accepted its actual polyline is checked against itself, the
floor boundary, obstacles, previously accepted circuits and prior
manifolds. The complete return is included in the length limit. Normal
preview does not record traces; replay reruns only the winning strategy.

Coverage scoring subtracts the actual tube footprint from each available
row, including partial rows, small pieces and pieces between multiple
obstacles. It no longer calls an entire row heated because some part of
that row appears in a loop. This remains a geometric row-sampling estimate,
not a thermal calculation; wall margins and the discrete sampling mean it
is not identical to a raster measurement of the whole floor.

## Evidence

`./tests/run.sh radiant` runs the focused checks. The ordinary full run also
includes them. The new barn fixture uses the exact rectangles and manifold
position recorded in TODO.md from report `20260924-130538-f90d326164`.

| Case | Before | After |
| --- | --- | --- |
| Barn, sampled bare floor | 4,218.5 of 5,753.9 sq ft | 1,995.4 sq ft |
| Barn, tube actually drawn | 5 circuits / 1,052.7 ft | 20 circuits / 4,392.8 ft |
| Round obstacle, sampled bare floor | about 1,259 of 2,801 sq ft | about 448 sq ft |

The scoring correction changes the metric, so there is also an independent
comparison using the same 20-pixel-per-foot tube-width mask on both sets of
polylines. On the barn that gives approximately **84% bare before, 39% bare
after**, including wall margins. On the triangle the footprint is essentially
unchanged (14.82% versus 14.88% bare), although the corrected row score is
higher: the old score omitted tapered partial rows. The triangle test now
checks that corrected metric rather than preserving the false low number.

[Before/after barn geometry](media/radiant-routing-comparison-2026-09-24.svg)

The regressions independently inspect circuit lengths, tube-to-tube and
obstacle crossings, floor containment, deterministic results, derived port
counts and replay. A centered manifold and one ten feet off a wall both
reach all four quadrants; their sampled bare floor stays below 15%.

## Remaining work

This is still a bounded row-based heuristic. It does not guarantee full
coverage, and the barn still has a substantial unheated pocket. Routing
represents only the near and far pieces of a cut row; intermediate pieces
are now scored as unfilled but need a more general route representation to
be filled. Port placement still starts from a loop-count estimate internally, then
probes larger allocations. That is a bounded search, not a proof that every
possible number and ordering of circuits has been explored.

The three-foot exception bounds the fan's depth from the manifold's
connection row. It does **not** bound the total length of a diagonal fan
segment. Converting every long fan to individually occupied grid paths
outside a small neighborhood remains work to do.

The owner's proposed next repair pass is to keep short circuits, remove
selected long circuits, grow the retained ones into newly available space,
then reroute the removed circuits. Keep a repair only if its measured score
improves and every circuit passes the same geometry checks. That requires
tracking occupied intervals and connections independently of row/rank
ownership; it is not implemented by the restart pass above. Alternating
left/right circuit growth and arbitrary perimeter-following paths are also
not implemented yet. Preserve the current best layout when any bounded
search or repair stalls.
