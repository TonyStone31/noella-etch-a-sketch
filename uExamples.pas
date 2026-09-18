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

{ Put one example on disk in Dir, unless somebody has made it theirs.

  Recorded is the checksum of what was written there last time, as kept in
  the settings, and comes back as the checksum of what is there now.  The
  rule, from the TODO of 13 September: an example improved in a later
  version replaces the old one, and one somebody has edited and saved over
  is theirs and is left alone.  So:

  * not there - written;
  * the same as this version - nothing to do;
  * what we wrote last time - it has not been touched, so the new version
    goes over it;
  * anything else - it has been changed since we wrote it, and it stays.

  No record at all is taken as ours: every version before this one wrote
  the examples over the top on every run, so a file that predates the
  record has never had a chance to be anybody's. }
type
  TExampleWrite = (ewWritten, ewUpToDate, ewKeptTheirs, ewFailed);

function PutExample(I: Integer; const Dir: string;
  var Recorded: string): TExampleWrite;

implementation

uses
  SysUtils, uExample, uExGlass, uExBroom, uUpdate;

const
  FILES: array[0..2] of string = ('etch-a-sketch.hsk', 'wine-glass.hsk',
    'broom.hsk');
  ABOUT: array[0..2] of string = (
    'A toy etch-a-sketch, to scale, with a robot on the screen.  Every ' +
    'face of it is something to push.',
    'A wine glass, off the lathe: an outline spun about the blue axis.  ' +
    'Hollow bowl, solid stem, and closed enough to print.',
    'A kitchen broom, banded the way a shop one is: a hundred and seventy ' +
    'bristles, every face painted, and not a pen colour anywhere.');

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
    2: BroomDrawing(L);
  end;
end;

function ReadRaw(const Path: string): string;
var
  F: TFileStream;
begin
  Result := '';
  F := TFileStream.Create(Path, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, F.Size);
    if F.Size > 0 then F.ReadBuffer(Result[1], F.Size);
  finally
    F.Free;
  end;
end;

function PutExample(I: Integer; const Dir: string;
  var Recorded: string): TExampleWrite;
var
  L: TStringList;
  Path, Sum: string;
begin
  Result := ewFailed;
  if (I < 0) or (I >= ExampleCount) then Exit;
  Path := IncludeTrailingPathDelimiter(Dir) + ExampleFile(I);
  L := TStringList.Create;
  try
    try
      ExampleLines(I, L);
      if L.Count = 0 then Exit;
      if FileExists(Path) then
      begin
        if ReadRaw(Path) = L.Text then
        begin
          Recorded := Sha256Of(Path);
          Exit(ewUpToDate);
        end;
        Sum := Sha256Of(Path);
        if (Recorded <> '') and (Sum <> Recorded) then
          Exit(ewKeptTheirs);
      end;
      L.SaveToFile(Path);
      Recorded := Sha256Of(Path);
      Result := ewWritten;
    except
      Result := ewFailed;
    end;
  finally
    L.Free;
  end;
end;

end.
