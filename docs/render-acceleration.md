# Threads, and OpenGL as an accelerator

Written 7 September 2026 after a long discussion, so it does not have to be
had again.  Nothing here is built except where it says so.

## What we agreed

* **Single-thread wins first, threads second, OpenGL last if ever.**  The
  single-thread list is nearly done (see TODO, "Performance with fittings").
  The face fill is the one that stands between us and threads: it is the
  whole cost of a frame when zoomed in, and it is also the exact code
  threads will split.
* **The face fill talks to a painter.**  The face pass in `TWorkDoc.Render`
  hands its faces - projected polygon, colour, depth plane - to a painter
  and gets back a surface whose colour and depth arrays are complete.  Two
  painters: the software one, which is today's `FillLoops`, and one day a
  GL one.  The renderer above never knows which ran and never spawns threads
  itself.
* **The painter decides how to spread the work.**  The software painter, when
  threaded, splits rows into bands, one per core, and joins.  A GL painter
  ignores bands, draws the lot on the card into an offscreen buffer, reads
  colour and depth back into the surface's arrays, and returns.  A GL
  context belongs to one thread, so the painter is always called from one
  thread; that is a law for GL and a choice for software.
* **The painter returns only when colour and depth are complete.**  One sync
  point either way - threads joined or readback done.  Everything after the
  fill reads those arrays and nothing else.  The depth array is written by
  the painter only; the passes after it only read, which is what lets them
  be threaded too.
* **GL is an accelerator, not a renderer.**  It paints faces.  We keep
  drawing the lines: profiles, soft creases at the silhouette, the cover
  tolerance, crisp corners, back-face colour, paper and ink layering,
  printing at the printer's resolution, TOY's neon and dissolve.  None of
  that is rewritten for GL.  Two hundred new lines and ten changed, roughly.
* **Available and easy to shut off.**  Try a context once at startup; if it
  fails, the display is remote, or a GL frame ever throws, use software and
  say so in About.  A setting and a command (`/gl`, like `/quick`) turn it
  off by hand.  The software painter stays the reference: a test renders a
  drawing both ways and compares depth buffers within tolerance.  Measure
  the readback on a real Windows machine before believing it - Lazarus GL
  contexts on GTK and Windows have a history.

## Threads: the order and the rules

Behind a toggle (`/threads`), each one separately switchable, so a
misbehaving one can be turned off without losing the rest.

1. **The geometry caches off the main thread** - first, because it is the
   simplest and nothing visible depends on it: `FOnFace` (which faces each
   edge lies on) and later the snap cache.  The worker gets a deep copy of
   the entities, computes, and queues the result back; the main thread swaps
   it in only if the drawing has not changed since (an edit sequence
   number).  Until it arrives the renderer uses the slow full search, so the
   worker only ever accelerates; correctness never depends on it.
2. **The face fill by bands** inside the software painter.
3. **The lines-on-faces pass by line**, reading the depth buffer only.
4. **The snap cache** the same way as (1).

Rules: a worker touches only its own snapshot and its own result; nothing
in the LCL, the document, the undo stack or the surface is touched from a
worker; results come back through `TThread.Queue`; every worker catches
everything and reports through a counter, never a dialog; counters and
timings show in `/rendertime` and `/timings` so a thread can be watched.

## What is done

- **Lines-on-faces cache on a worker** (`TOnFaceWorker` in uWork.pas).
  The worker owns a deep copy of the entities, computes with a pure
  procedure (`ComputeOnFace`), and queues one method back to the main
  thread.  The main thread checks the edit sequence before taking the
  result, and the renderer searches every face while the cache is not
  there.  Nothing but that method touches the document, and nothing
  touches the screen.  `DefaultThreads` is off outside the program so the
  tests and tools never start a thread; `/threads` toggles it live and
  `/rendertime` prints worker time, frames without the cache, results
  discarded and failures.
