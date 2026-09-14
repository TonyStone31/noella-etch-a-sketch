{ Where this program keeps its things.

  It is a portable program: a single file you put in a folder and run, with
  no installer and nothing to uninstall.  So it keeps its settings, its draft
  and its scratch files in that same folder, and a copy carried on a stick
  carries its work with it.

  This is not only tidiness.  A fresh copy dropped in an empty folder was
  still picking up the settings and the draft of every other copy on the
  machine, out of the user's home - so Nikki's brand new build restored the
  very drawing that had been crashing the old one, and crashed the same way.
  A portable program that quietly shares state with its siblings is not
  portable, it is just untidy in a hidden place.

  The home folder is still used when the program lives somewhere its own
  folder cannot be written to - installed under /usr/bin, or in Program
  Files - because there it is not portable and pretending otherwise would
  mean losing settings at every launch. }
unit uPaths;

{$mode objfpc}{$H+}

interface

{ The folder for settings, draft and scratch, ending in a path separator. }
function AppDataDir: string;
{ True when that is the program's own folder rather than the user's home. }
function IsPortable: Boolean;
function ConfigFile: string;
function DraftFile: string;
{ Where the example drawings are put: beside the program when it is portable,
  and in the user's folder when it is not. }
function ExamplesDir: string;

{ Where a drawing is saved, and where a picture is exported, when nobody has
  said otherwise: folders beside the program, made the first time one is
  needed.

  This is the same argument as the settings and the draft.  A portable
  program that drops the user in their home folder the moment they press Save
  has scattered their work across a machine they may not even own - and the
  next time they plug the stick in somewhere else, none of it is there.
  Beside the program, it travels with the program.

  Wherever they go instead is remembered, per kind of file, because people
  keep drawings in one place and pictures for a forum in another.  That is
  the caller's business; these are only the defaults. }
function DrawingsDir: string;
function ExportsDir: string;
{ A folder beside the program, made if it is not there.  Comes back empty if
  it cannot be made, which is the caller's signal to let the dialog decide. }
function WorkDir(const Name: string): string;

implementation

uses
  SysUtils, Classes;

var
  Cached: string = '';
  CachedPortable: Boolean = False;

function CanWriteIn(const Dir: string): Boolean;
var
  F: TFileStream;
  Probe: string;
begin
  Result := False;
  if Dir = '' then Exit;
  Probe := IncludeTrailingPathDelimiter(Dir) + '.hsk-write-probe';
  try
    F := TFileStream.Create(Probe, fmCreate);
    F.Free;
    DeleteFile(Probe);
    Result := True;
  except
    Result := False;
  end;
end;

function AppDataDir: string;
var
  Own: string;
begin
  if Cached <> '' then Exit(Cached);
  Own := ExtractFilePath(ExpandFileName(ParamStr(0)));
  if CanWriteIn(Own) then
  begin
    Cached := Own;
    CachedPortable := True;
  end
  else
  begin
    Cached := IncludeTrailingPathDelimiter(GetAppConfigDir(False));
    CachedPortable := False;
    ForceDirectories(Cached);
  end;
  Result := Cached;
end;

function IsPortable: Boolean;
begin
  AppDataDir;
  Result := CachedPortable;
end;

function ConfigFile: string;
begin
  Result := AppDataDir + 'heckers-sketch.cfg';
end;

function DraftFile: string;
begin
  Result := AppDataDir + 'heckers-sketch-draft.hsk';
end;

function ExamplesDir: string;
begin
  Result := AppDataDir + 'examples' + PathDelim;
end;

function WorkDir(const Name: string): string;
begin
  Result := AppDataDir + Name + PathDelim;
  if not DirectoryExists(Result) then
    if not ForceDirectories(Result) then
      Result := '';
end;

function DrawingsDir: string;
begin
  Result := WorkDir('drawings');
end;

function ExportsDir: string;
begin
  Result := WorkDir('exports');
end;

end.
