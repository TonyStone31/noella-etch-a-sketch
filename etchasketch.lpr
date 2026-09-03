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
  uSurface, uSkin, uWork, uMain;

{$R *.res}

{ --help is answered before any of the LCL starts up, so it prints and leaves
  rather than printing and then opening a window.  A GUI build on Windows has
  no console to write to, which is allowed to fail quietly. }
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
    WriteLn('  --size=1600x1000   open at a particular size, centred');
    WriteLn('  --help             this');
    WriteLn;
    WriteLn('Without a switch the window comes back the size and the place it');
    WriteLn('was left.  A drawing named on the line is opened.');
    Flush(Output);
  except
    { no console; nothing to be done about it }
  end;
end;

begin
  if AskedForHelp then Halt(0);
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Title := 'Heckers Sketch';
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
