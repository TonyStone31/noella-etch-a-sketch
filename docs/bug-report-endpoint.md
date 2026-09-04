# Where bug reports go

The program has no server.  GitHub is the permanent address and Filebin is
the postbox, and the postbox is meant to be thrown away and replaced.

`.github/workflows/rotate-bug-bin.yml` makes a fresh Filebin bin every three
days, initializes it, and writes where it is into
`docs/bug-report-endpoint.json`.  The program hardcodes exactly one address -
the raw URL of that file - and looks up everything else:

    https://raw.githubusercontent.com/TonyStone31/noella-etch-a-sketch/main/docs/bug-report-endpoint.json

```json
{
  "version": 1,
  "service": "filebin",
  "current_bin": "noella-bugs-…",
  "upload_base": "https://filebin.net/noella-bugs-…",
  "previous_bin": "…",
  "updated_utc": "…"
}
```

A report is a plain HTTP POST of the report's text to
`{upload_base}/{unique-name}`.

## What the program does

`uReport.pas` is the whole of it, and it is deliberately dull.

* It remembers the last endpoint that worked, in its own settings file, and
  tries that first - one fewer request, and usually right.
* A refusal that means *the bin has gone* - 401, 403, 404, 405, 409, 410,
  423 - is worth asking GitHub again and trying once more.  That is the case
  this whole arrangement exists for.  Any other refusal is taken at its word,
  because trying the same thing again would fail the same way.
* Nothing it does can take the program down or hold it up.  These are the
  paths that run *because* something already went wrong.

## What goes in a report

What the program was doing: version, tool, view, plane, cursor, counts of
each kind of thing on the sheet, and the last few dozen actions with their
world coordinates.  Nothing about the person or the machine.

The drawing itself is **offered, never assumed**.  It is the single most
useful thing for finding a fault - it is what found the last one - but it is
somebody's work, possibly with a customer's name on it, and it does not leave
the machine unless the checkbox is ticked.

## If the bin is missing

Nothing breaks.  The upload fails, the program says so plainly, and the
person carries on.  A crash report is still written next to the program, with
the drawing beside it, exactly as before.
