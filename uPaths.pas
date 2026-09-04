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

end.
