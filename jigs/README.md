# The jigs that come with the program

A **JIG** - *Just Include Geometry* - is any program that prints Heck, the
language a Heckers Sketch drawing is written in (`docs/format2.md`).  A
group in a drawing says

    jig = 'star' with Points = 5, Radius = 2'

and the program finds `star` in the person's jigs folder, runs it with
`Points=5 Radius=24` as its arguments - lengths arrive as plain inches, or
millimeters on a metric sheet - and what it prints becomes the group.

These are the ones the program carries, to show that the language does not
matter:

| Jig | Written in | Draws |
|---|---|---|
| `star.pas` | Pascal, run by `instantfpc` | a star of any number of points |
| `balloon.py` | Python | a balloon on a string |
| `fence.pl` | Perl | posts and two rails |
| `steps.sh`, `steps.ps1` | shell with awk; PowerShell | a flight of steps - the same jig twice, so it runs on a machine that has only one of them |

They are written out to the jigs folder the first time the program runs, by
the same rule as the example drawings: one that has been changed there is
left alone.  `make-jigs.pas` turns these files into `../uJigFiles.pas`, which
is how they get inside a program that is one file; run it after changing
any of them.
