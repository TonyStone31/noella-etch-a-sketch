# WebP, in Pascal, with no DLL

The program exports animations.  Until now that meant a GIF, because writing
a WebP meant shipping ffmpeg or libwebp beside a program whose whole delivery
story is one file you can copy onto a stick.

## What is here

| | |
|---|---|
| `WebPEnc.pas` | **Xelitan's**, MIT - a real VP8L lossless encoder and a VP8 lossy one, ported from libwebp 1.6.0.  Upstream `Xelitan/Pure-Pascal-Webp-for-Delphi-Lazarus-Free-Pascal`, rev 83f3561.  **With three changes of ours**, marked in the file and described at the foot of this page. |
| `LICENSE-Xelitan.txt` | his licence, kept with his code |
| `uWebPAnim.pas` | ours - the animated container, which is the piece nobody had |
| `selftest.pas` | writes a five frame animation and is the thing to run when either of the above is touched |

## Why the split

Xelitan's encoder does the hard half and does it properly: `WebPEncodeLosslessBGRA`
gives a byte-exact picture back.  Checked rather than taken on trust - a 320x200
frame of flat colour and one-pixel lines, encoded and decoded again, came back
**0 pixels wrong out of 64,000**.

What it does not do is write an *animation*.  Its animation units go the other
way - they read and play.  So `uWebPAnim.pas` is the envelope:

    RIFF .... WEBP
      VP8X    the canvas, and the flag saying this is an animation
      ANIM    background colour, loop count
      ANMF    a frame: where, how big, how long
        VP8L    ...the still picture, exactly as WebPEnc made it
      ANMF
        VP8L

That is all an animated WebP is.  The still frames are not encoded differently;
they are the same frames in a different wrapper.  Three of the numbers are
stored one less than they are, and two are counted in pairs of pixels - see the
comments in the unit, which is where the format's oddities are written down.

## Why it is vendored here rather than in LazInk

LazInk is heading for 0BSD, and its LICENSE says so: the one thing standing
between it and that is a single file's provenance.  Dropping somebody else's
MIT code into it would add a second thing.  Heckers Sketch is MIT and is
staying MIT, so the encoder lives here and LazInk keeps its road clear.

## Checking it still works

    fpc -Mobjfpc -Sh -Fu. selftest.pas && ./selftest

Then open `/tmp/atest.webp`.  Five frames, a block marching across a grid, each
frame a different length - 100, 120, 140, 160, 180 ms.

## What we changed in Xelitan's file

Three things, each marked `OUR CHANGE` where it sits.  Sent upstream is the
right thing to do with all of them; until then they are here.

**1. A mode directive.**  The unit names no `{$mode}`, so it compiles only
where the caller happens to have set one.  Inside the project lazbuild sets
objfpc for everything, but a tool or a test built by hand does not, and
`out` parameters then fail to parse.

**2. Two transforms in the lossless encoder** - subtract-green, and a
predictor that writes each pixel as the difference from the one to its left.
The encoder's own note said "no transforms, no color cache, literal pixels
only", which is honest and costly: on one frame of the ball example it was
**231 KB where PNG managed 27**.

**3. Runs.**  With literals only, a pixel costs at least one bit per channel
however predictable it is - three bits a pixel, whatever the entropy says.
The format already has the answer in tables this encoder was writing and
never using: a copy, saying "the next N pixels repeat the one before".  Only
that one match is looked for, because after the predictor above it is the
one that matters - flat fill and straight edges are runs of identical
residuals.

Measured on that same frame:

| | |
|---|---|
| as it came | 231,550 bytes |
| with subtract-green and the predictor | 155,726 |
| with runs as well | **25,188** |
| PNG, for comparison | 27,178 |
| lossy, quality 90 | 28,534 |

So the lossless file is now smaller than the same frame as a PNG, and nine
times smaller than where it started.  It is still lossless, and that is
checked rather than assumed: the frame is encoded, decoded again by a
different implementation, and compared pixel by pixel - **0 wrong out of
374,400**.

A real match finder, a colour cache and cross-colour would go further still;
libwebp has all three.  We have what a drawing needs.
