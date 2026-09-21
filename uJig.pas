unit uJig;

{ Running a JIG - "Just Include Geometry": any program that prints Heck.
  docs/format2.md, "Jigs".

  A group says  jig = 'star' with Points = 5, Radius = 2'  and this finds a
  program called star in the person's own jigs folder, runs it with those
  values, and hands back what it printed.  That is all.  What is printed is
  read by the same reader as any text a stranger sent (uHeck), by the
  caller, into a scratch drawing first.

  The rules, which are the point:
    - a jig is found by NAME, in ONE folder, the person's own.  A name with
      a slash, a dot-dot or a drive letter in it is refused: a drawing can
      name a jig and can never point at a file;
    - nothing here is ever called because a drawing was opened - only
      because a person asked for a jig to be run;
    - it gets its values as arguments, name=value, lengths as plain numbers
      in the sheet's small unit (inches, or millimeters), and nothing else. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uWork;

{ where the person's jigs live; made if it is not there }
function JigsDir: string;

{ 'star' with Points = 5, Radius = 2'  ->  star, and Points=5 Radius=24 }
function ParseJigSpec(const Spec: string; U: TUnitSystem; out Name: string;
  Args: TStrings; out Err: string): Boolean;

{ the file that is this jig, or '' }
function FindJig(const Name: string): string;

{ Run it.  Output gets what it printed.  False, and Err, when it could not
  be found or run, ran too long, or ended with an error of its own. }
function RunJig(const Spec: string; U: TUnitSystem; Output: TStrings;
  out Err: string): Boolean;

implementation

uses
  Process, uPaths, uHeck;

const
  JIG_SECONDS = 30;

function JigsDir: string;
begin
  Result := AppDataDir + 'jigs' + PathDelim;
  ForceDirectories(Result);
end;

function SafeName(const Name: string): Boolean;
var
  I: Integer;
begin
  Result := (Name <> '') and (Length(Name) <= 64);
  for I := 1 to Length(Name) do
    if not (Name[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '-']) then Exit(False);
end;

function ParseJigSpec(const Spec: string; U: TUnitSystem; out Name: string;
  Args: TStrings; out Err: string): Boolean;
var
  S, Rest, Item, Key, Val: string;
  P, Q: Integer;
  V: Double;
  IsLen: Boolean;
  FS: TFormatSettings;
begin
  Result := False;
  Err := '';
  Name := '';
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  S := Trim(Spec);
  if (S = '') or (S[1] <> '''') then
  begin
    Err := 'a jig is named in quotes: jig = ''star'' with Points = 5';
    Exit;
  end;
  P := 2;
  while (P <= Length(S)) and (S[P] <> '''') do Inc(P);
  Name := Copy(S, 2, P - 2);
  if not SafeName(Name) then
  begin
    Err := '"' + Name + '" is not a name a jig can have: letters, digits, - and _ only';
    Exit;
  end;
  Rest := Trim(Copy(S, P + 1, MaxInt));
  if Rest = '' then Exit(True);
  if LowerCase(Copy(Rest, 1, 5)) <> 'with ' then
  begin
    Err := 'after the jig''s name comes "with" and its values';
    Exit;
  end;
  Rest := Trim(Copy(Rest, 6, MaxInt)) + ',';
  while Rest <> '' do
  begin
    Q := Pos(',', Rest);
    Item := Trim(Copy(Rest, 1, Q - 1));
    Delete(Rest, 1, Q);
    Rest := Trim(Rest);
    if Item = '' then Continue;
    Q := Pos('=', Item);
    if Q = 0 then
    begin
      Err := '"' + Item + '" - a jig''s values are name = value';
      Exit;
    end;
    Key := Trim(Copy(Item, 1, Q - 1));
    Val := Trim(Copy(Item, Q + 1, MaxInt));
    if not SafeName(Key) then
    begin
      Err := '"' + Key + '" is not a name for a value';
      Exit;
    end;
    { a length goes as a plain number in the sheet's small unit, so that a
      ten-line script does not have to know what 2' 6" means }
    if HeckValue(Val, U, V, IsLen) then
    begin
      if IsLen then
        if U = usMetric then V := V * 304.8 else V := V * 12;
      Val := FloatToStrF(V, ffGeneral, 12, 0, FS);
    end
    else if (Length(Val) >= 2) and (Val[1] = '''') and (Val[Length(Val)] = '''') then
      Val := Copy(Val, 2, Length(Val) - 2);
    Args.Add(Key + '=' + Val);
  end;
  Result := True;
end;

function FindJig(const Name: string): string;
var
  SR: TSearchRec;
begin
  Result := '';
  if not SafeName(Name) then Exit;
  if FileExists(JigsDir + Name) then Exit(JigsDir + Name);
  if FindFirst(JigsDir + Name + '.*', faAnyFile and not faDirectory, SR) = 0 then
  begin
    Result := JigsDir + SR.Name;
    FindClose(SR);
  end;
end;

{ what runs a file of that kind; '' when it runs by itself }
function RunnerFor(const FileName: string; Pre: TStrings): string;
var
  Ext, T: string;
begin
  Result := '';
  Ext := LowerCase(ExtractFileExt(FileName));
  if Ext = '.pas' then
  begin
    Result := ExeSearch('instantfpc' + {$IFDEF WINDOWS}'.exe'{$ELSE}''{$ENDIF}, GetEnvironmentVariable('PATH'));
    if Result = '' then
    begin
      { the toolchain this project is built with, when there is no other }
      T := '/media/tony/storpart/fpctrunklaztrunk/fpc/bin/x86_64-linux/';
      if FileExists(T + 'instantfpc') then
      begin
        Result := T + 'instantfpc';
        Pre.Add('--compiler=' + T + 'fpc');
      end;
    end;
  end
  else if Ext = '.py' then
  begin
    Result := ExeSearch({$IFDEF WINDOWS}'python.exe'{$ELSE}'python3'{$ENDIF}, GetEnvironmentVariable('PATH'));
    if Result = '' then Result := ExeSearch('python' + {$IFDEF WINDOWS}'.exe'{$ELSE}''{$ENDIF}, GetEnvironmentVariable('PATH'));
  end
  else if Ext = '.pl' then
    Result := ExeSearch('perl' + {$IFDEF WINDOWS}'.exe'{$ELSE}''{$ENDIF}, GetEnvironmentVariable('PATH'))
  else if Ext = '.sh' then
    Result := ExeSearch('sh', GetEnvironmentVariable('PATH'))
  else if Ext = '.ps1' then
  begin
    Result := ExeSearch({$IFDEF WINDOWS}'powershell.exe'{$ELSE}'pwsh'{$ENDIF}, GetEnvironmentVariable('PATH'));
    Pre.Add('-NoProfile');
    Pre.Add('-ExecutionPolicy');
    Pre.Add('Bypass');
    Pre.Add('-File');
  end
  else if (Ext = '.bat') or (Ext = '.cmd') then
  begin
    Result := ExeSearch('cmd.exe', GetEnvironmentVariable('PATH'));
    Pre.Add('/c');
  end
  else
    Result := FileName;
end;

function RunJig(const Spec: string; U: TUnitSystem; Output: TStrings;
  out Err: string): Boolean;
var
  Name, FileName, Runner, ErrText: string;
  Args, Pre: TStringList;
  P: TProcess;
  Buf: array[0..4095] of Byte;
  N, I: Integer;
  OutS, ErrS: TMemoryStream;
  Started: QWord;
begin
  Result := False;
  Args := TStringList.Create;
  Pre := TStringList.Create;
  OutS := TMemoryStream.Create;
  ErrS := TMemoryStream.Create;
  try
    if not ParseJigSpec(Spec, U, Name, Args, Err) then Exit;
    FileName := FindJig(Name);
    if FileName = '' then
    begin
      Err := 'there is no jig called "' + Name + '" in ' + JigsDir;
      Exit;
    end;
    Runner := RunnerFor(FileName, Pre);
    if Runner = '' then
    begin
      Err := 'nothing on this machine runs a ' + ExtractFileExt(FileName) + ' file, which is what the jig "' +
        Name + '" is';
      Exit;
    end;
    P := TProcess.Create(nil);
    try
      P.Executable := Runner;
      for I := 0 to Pre.Count - 1 do P.Parameters.Add(Pre[I]);
      if Runner <> FileName then P.Parameters.Add(FileName);
      for I := 0 to Args.Count - 1 do P.Parameters.Add(Args[I]);
      P.CurrentDirectory := JigsDir;
      P.Options := [poUsePipes, poNoConsole];
      P.ShowWindow := swoHIDE;
      try
        P.Execute;
      except
        on E: Exception do
        begin
          Err := 'the jig "' + Name + '" would not start: ' + E.Message;
          Exit;
        end;
      end;
      P.CloseInput;
      Started := GetTickCount64;
      repeat
        N := 0;
        if P.Output.NumBytesAvailable > 0 then
        begin
          N := P.Output.Read(Buf, SizeOf(Buf));
          if N > 0 then OutS.Write(Buf, N);
        end;
        if P.Stderr.NumBytesAvailable > 0 then
        begin
          I := P.Stderr.Read(Buf, SizeOf(Buf));
          if I > 0 then ErrS.Write(Buf, I);
          Inc(N, I);
        end;
        if N = 0 then Sleep(10);
        if GetTickCount64 - Started > JIG_SECONDS * 1000 then
        begin
          P.Terminate(1);
          Err := Format('the jig "%s" was still running after %d seconds, and was stopped', [Name, JIG_SECONDS]);
          Exit;
        end;
        if OutS.Size > 32 * 1024 * 1024 then
        begin
          P.Terminate(1);
          Err := 'the jig "' + Name + '" printed more than 32 MB, and was stopped';
          Exit;
        end;
      until (not P.Running) and (P.Output.NumBytesAvailable = 0) and (P.Stderr.NumBytesAvailable = 0);
      if P.ExitStatus <> 0 then
      begin
        SetString(ErrText, PChar(ErrS.Memory), ErrS.Size);
        Err := Format('the jig "%s" ended with an error (%d): %s', [Name, P.ExitStatus,
          Trim(Copy(ErrText, 1, 400))]);
        Exit;
      end;
    finally
      P.Free;
    end;
    OutS.Position := 0;
    Output.LoadFromStream(OutS);
    Result := True;
  finally
    ErrS.Free;
    OutS.Free;
    Pre.Free;
    Args.Free;
  end;
end;

end.
