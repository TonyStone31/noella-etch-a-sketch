unit uExamples;

{ The example drawings the program carries, and their names on disk.

  Each one is generated - examples/make-*.pas writes both the .hsk in
  examples/ and a unit here with the same drawing in it, so the file in the
  repository and the file the program writes out are the same bytes.  This
  unit is the only hand-written part: a list, so adding a model is a
  generator and one line rather than a change to three places.

  Why carry them at all, rather than shipping a folder: the program is one
  executable on purpose, and an example that exists only as a file beside it
  is an example most people would never see - it would be missing the first
  time somebody ran the thing, which is exactly when it is wanted.

  The first in the list is the one a fresh run opens.

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE.
}

{$mode objfpc}{$H+}

interface

uses
  Classes;

{ How many there are, and what each is called on disk. }
function ExampleCount: Integer;
function ExampleFile(I: Integer): string;
{ A short line about it, for anything that lists them. }
function ExampleAbout(I: Integer): string;
{ The drawing itself, as the lines of a .hsk file. }
procedure ExampleLines(I: Integer; L: TStrings);

implementation

uses
  uExample, uExGlass;

const
  FILES: array[0..1] of string = ('etch-a-sketch.hsk', 'wine-glass.hsk');
  ABOUT: array[0..1] of string = (
    'A toy etch-a-sketch, to scale, with a robot on the screen.  Every ' +
    'face of it is something to push.',
    'A wine glass, off the lathe: an outline spun about the blue axis.  ' +
    'Hollow bowl, solid stem, and closed enough to print.');

function ExampleCount: Integer;
begin
  Result := Length(FILES);
end;

function ExampleFile(I: Integer): string;
begin
  if (I < 0) or (I > High(FILES)) then Result := '' else Result := FILES[I];
end;

function ExampleAbout(I: Integer): string;
begin
  if (I < 0) or (I > High(ABOUT)) then Result := '' else Result := ABOUT[I];
end;

procedure ExampleLines(I: Integer; L: TStrings);
begin
  case I of
    0: ExampleDrawing(L);
    1: GlassDrawing(L);
  end;
end;

end.
