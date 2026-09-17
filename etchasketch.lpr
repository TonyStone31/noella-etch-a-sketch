program etchasketch;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, SysUtils, printer4lazarus,
  {$IFDEF WINDOWS}Windows,{$ENDIF}
  uSurface, uTri, uSkin, uShoot, uDlgSkin, uRecord, uExport, uExample, uWork, uPaths, uSingle, uSplash, uNet, uMain;

{$R *.res}

{ --help is answered before any of the LCL starts up, so it prints and leaves
  rather than printing and then opening a window.  A GUI build on Windows has
  no console to write to, which is allowed to fail quietly. }
{ Say so without needing the LCL to be up, since we are about to leave. }
procedure ShowAlreadyRunning;
begin
  try
    WriteLn('Heckers Sketch is already running.');
    WriteLn('Only one copy at a time - they would share the same draft and');
    WriteLn('overwrite each other.  Use --multi if you really want two.');
    Flush(Output);
  except
  end;
  {$IFDEF WINDOWS}
  MessageBoxW(0,
    'Heckers Sketch is already running.'#13#10#13#10 +
    'Only one copy at a time - two would share the same draft and overwrite '
    + 'each other''s work.',
    'Heckers Sketch', MB_OK or MB_ICONINFORMATION);
  {$ENDIF}
end;

{ --no-splash: for anything driving the program from a script }
function AskedForNoSplash: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if LowerCase(ParamStr(I)) = '--no-splash' then Result := True;
end;

function AskedForHelp: Boolean;
var
  I: Integer;
  A: string;
begin
  Result := False;
  for I := 1 to ParamCount do
  begin
    A := LowerCase(ParamStr(I));
    if (A = '--help') or (A = '-h') or (A = '-?') or (A = '/?') then
      Result := True;
  end;
  if not Result then Exit;
  try
    WriteLn('Heckers Sketch');
    WriteLn;
    WriteLn('  etchasketch [switches] [drawing.hsk]');
    WriteLn;
    WriteLn('  --maximized        open filling the screen');
    WriteLn('  --fullscreen       open with no window frame at all');
    WriteLn('  --size=1600x1000   open at a particular size, centerd');
    WriteLn('  --multi            open a second copy anyway');
    WriteLn('  --no-splash        skip the start-up screen');
    WriteLn('  --offline          never use the network - no update check, no reports');
    WriteLn('  --blank            start on an empty sheet - no draft, no example');
    WriteLn('                     (the last draft is kept as ...-before-blank.hsk)');
    WriteLn('  --updated          wait for the copy being replaced to go');
    WriteLn('  --help             this');
    WriteLn;
    WriteLn('Without a switch the window comes back the size and the place it');
    WriteLn('was left.  A drawing named on the line is opened.');
    Flush(Output);
  except
    { no console; nothing to be done about it }
  end;
end;

{ Did somebody ask for a second window on purpose? }
function WantsAnother: Boolean;
var
  I: Integer;
  A: string;
begin
  Result := False;
  for I := 1 to ParamCount do
  begin
    A := LowerCase(ParamStr(I));
    if (A = '--multi') or (A = '--new-instance') then Result := True;
  end;
end;

{ Started by the copy it is replacing, which is still shutting down.

  Worth waiting for rather than waving through: the reason for one copy at a
  time is that two share a draft, and that is just as true during an update.
  Fifteen seconds is far longer than a close takes and still short enough that
  a genuinely stuck old copy does not leave somebody staring at nothing. }
function AfterAnUpdate: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to ParamCount do
    if LowerCase(ParamStr(I)) = '--updated' then Result := 15;
end;

var
  UpdateWait, I: Integer;

begin
  if AskedForHelp then Halt(0);

  { One copy at a time, because they share the draft and would otherwise take
    turns overwriting each other's work. }
  UpdateWait := AfterAnUpdate;
  if UpdateWait > 0 then DropInheritedUpdateLock;
  if not WantsAnother and not BecomeTheOnlyCopy(UpdateWait) then
  begin
    ShowAlreadyRunning;
    Halt(0);
  end;

  { --offline: nothing goes out to the network - see uNet.NetOffline }
  for I := 1 to ParamCount do
    if LowerCase(ParamStr(I)) = '--offline' then uNet.NetOffline := True;

  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Title := 'Heckers Sketch';
  Application.Initialize;
  { up before the window, so a slow drawing is visibly being read.

    It stays up for a few seconds even when there was nothing to wait for,
    on purpose - see SPLASH_MIN_MS.  That is right for a person and wrong
    for a script, which pays those seconds every launch and has nobody to
    reassure; the drive tests were paying them twenty-eight times a run. }
  if not AskedForNoSplash then SplashShow;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
