# WebP, in Pascal, with no DLL

The program exports animations.  Until now that meant a GIF, because writing
a WebP meant shipping ffmpeg or libwebp beside a program whose whole delivery
story is one file you can copy onto a stick.

## What is here

| | |
|---|---|
| `WebPEnc.pas` | **Xelitan's**, MIT - a real VP8L lossless encoder and a VP8 lossy one, ported from libwebp 1.6.0.  Upstream `Xelitan/Pure-Pascal-Webp-for-Delphi-Lazarus-Free-Pascal`, rev 83f3561. |
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
