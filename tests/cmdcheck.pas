program cmdcheck;

{ Every command the list offers is a command the program answers to.

  The autocomplete list in uMain is a hand-written table, and the dispatcher
  in RunCommand is a hand-written chain of comparisons.  Nothing ties them
  together, so a command can be added to one and not the other: offer a name
  that does nothing, or hide a name that works.  This reads both out of the
  source and says where they disagree.

  It cannot go all the way the other round.  The chain has debugging words
  that are deliberately not offered, and a list that had to hold all of them
  would be worse than no list.  What it can do is hold the table's own other
  words - the Also column - to the chain: each one has to be answered by the
  same branch as the name it sits beside, or typing it does something other
  than the row it finds.

  This was a Python script inside run-cmds.sh until 17 September.  It is
  Pascal now, like everything else here, so nothing in the repository needs
  a Python to run. }

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, RegExpr;

var
  Src, Table, Body: string;
  Bad: Boolean;
  Names, Hints, Egs, Alsos, Args: TStringList;
  Known, Seen: TStringList;

procedure Fail(const Msg: string);
begin
  WriteLn(Msg);
  Bad := True;
end;

function ReadAll(const Path: string): string;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.LoadFromFile(Path);
    Result := L.Text;
  finally
    L.Free;
  end;
end;

{ a Pascal string doubles its apostrophes; the screen shows one }
function Unquote(const S: string): string;
begin
  Result := StringReplace(S, '''''', '''', [rfReplaceAll]);
end;

procedure ReadTable;
var
  R: TRegExpr;
  P, Q, Bound, I, Rows: Integer;
begin
  R := TRegExpr.Create('CMD_LIST: array\[0\.\.(\d+)\] of TCmdItem = \(');
  try
    if not R.Exec(Src) then
    begin
      WriteLn('CMD_LIST not found - has it been renamed?');
      Halt(1);
    end;
    Bound := StrToInt(R.Match[1]);
    P := R.MatchPos[0] + R.MatchLen[0];
  finally
    R.Free;
  end;
  { the table ends where a row closes the array as well as itself }
  Q := Pos('));' + LineEnding, Copy(Src, P, MaxInt));
  if Q = 0 then
  begin
    WriteLn('the end of CMD_LIST was not found');
    Halt(1);
  end;
  Table := Copy(Src, P, Q + 1);

  R := TRegExpr.Create(
    '\(Name:\s*''([a-z0-9]+)'';\s*Hint:\s*''((?:[^'']|'''')*)'';\s*' +
    'Arg:\s*(True|False)' +
    '(?:;\s*Eg:\s*''((?:[^'']|'''')*)'')?' +
    '(?:;\s*Also:\s*''([^'']*)'')?' +
    '\s*\)');
  try
    if R.Exec(Table) then
      repeat
        Names.Add(R.Match[1]);
        Hints.Add(Unquote(R.Match[2]));
        Args.Add(R.Match[3]);
        Egs.Add(Unquote(R.Match[4]));
        Alsos.Add(R.Match[5]);
      until not R.ExecNext;
  finally
    R.Free;
  end;

  Rows := 0;
  I := Pos('(Name:', Table);
  while I > 0 do
  begin
    Inc(Rows);
    I := Pos('(Name:', Table, I + 1);
  end;
  if Rows <> Names.Count then
    Fail(Format('could not read every row of CMD_LIST (%d of %d)',
      [Names.Count, Rows]));
  if Bound <> Names.Count - 1 then
    Fail(Format('CMD_LIST says [0..%d] but holds %d entries',
      [Bound, Names.Count]));
end;

procedure ReadDispatcher;
var
  P, Q: Integer;
  Tail: string;
  R: TRegExpr;
begin
  P := Pos('function TMainForm.RunCommand', Src);
  if P = 0 then
  begin
    WriteLn('RunCommand not found - has it been renamed?');
    Halt(1);
  end;
  Tail := Copy(Src, P + 10, MaxInt);
  R := TRegExpr.Create('\n(?:function|procedure) TMainForm\.');
  try
    if R.Exec(Tail) then Q := R.MatchPos[0] else Q := Length(Tail) + 1;
  finally
    R.Free;
  end;
  Body := Copy(Src, P, Q + 9);

  { every quoted word it compares W against - and a few are dispatched by
    prefix or by their own routine, so those are read for separately }
  R := TRegExpr.Create(
    '(?:W = ''([a-z0-9?]+)'')|(?:Cmd = ''([a-z0-9]+)'')|' +
    '(?:Copy\(W, 1, \d+\) = ''([a-z0-9]+)'')');
  try
    if R.Exec(Body) then
      repeat
        if R.Match[1] <> '' then Known.Add(R.Match[1])
        else if R.Match[2] <> '' then Known.Add(R.Match[2])
        else Known.Add(R.Match[3]);
      until not R.ExecNext;
  finally
    R.Free;
  end;
end;

{ The condition of the branch that compares W with Word: from the "if"
  before the comparison to the "then" after it. }
function BranchOf(const Word: string): string;
var
  K, A, B: Integer;
begin
  Result := '';
  K := Pos('W = ''' + Word + '''', Body);
  if K = 0 then Exit;
  A := K;
  while (A > 3) and (Copy(Body, A - 3, 3) <> 'if ') do Dec(A);
  B := Pos(' then', Body, K);
  if B = 0 then Exit;
  Result := Copy(Body, A, B - A);
end;

procedure CheckRows;
var
  I, K: Integer;
  Words: TStringList;
  Branch, Prev: string;
begin
  { alphabetical, because that is where a thing is when you do not know what
    it is called }
  Prev := '';
  for I := 0 to Names.Count - 1 do
  begin
    if (Prev <> '') and (CompareStr(Names[I], Prev) < 0) then
    begin
      Fail(Format('CMD_LIST is out of alphabetical order at ''%s''', [Names[I]]));
      Break;
    end;
    Prev := Names[I];
  end;

  Words := TStringList.Create;
  try
    Words.Delimiter := ' ';
    Words.StrictDelimiter := True;
    for I := 0 to Names.Count - 1 do
    begin
      { one example per row that wants something after it, each one a real
        use of that command }
      if (Args[I] = 'True') and (Egs[I] = '') then
        Fail(Format('/%s wants something after it and has no example', [Names[I]]));
      if (Egs[I] <> '') and (Copy(Egs[I], 1, Length(Names[I]) + 2) <> '/' + Names[I] + ' ') then
        Fail(Format('/%s has the example "%s", which is not that command with ' +
          'something after it', [Names[I], Egs[I]]));

      if Known.IndexOf(Names[I]) < 0 then
        Fail(Format('offered by the list, answered by nothing: %s', [Names[I]]));

      { every other word runs the same thing the name runs }
      Words.DelimitedText := Alsos[I];
      Branch := BranchOf(Names[I]);
      for K := 0 to Words.Count - 1 do
      begin
        if Words[K] = '' then Continue;
        if Seen.IndexOf(Words[K]) >= 0 then
          Fail(Format('''%s'' is listed twice in CMD_LIST', [Words[K]]))
        else
          Seen.Add(Words[K]);
        if Pos('W = ''' + Words[K] + '''', Branch) = 0 then
          Fail(Format('/%s lists ''%s'' as another word for it, but RunCommand ' +
            'does not answer ''%s'' in the same branch', [Names[I], Words[K], Words[K]]));
      end;
      if Seen.IndexOf(Names[I]) >= 0 then
        Fail(Format('''%s'' is listed twice in CMD_LIST', [Names[I]]))
      else
        Seen.Add(Names[I]);
    end;
  finally
    Words.Free;
  end;
end;

{ A word compared twice is a word answered once.  The chain runs top to
  bottom and the first branch that matches wins, so a later branch comparing
  the same word is unreachable - and if that later branch is the one the list
  is advertising, the command does something other than what it says.

  /new did exactly that: it was an alias on the /whatsnew branch and the
  branch that makes a new sheet sat below it, so /new opened the release
  notes and the list said "a new sheet". }
procedure CheckTwice;
var
  R: TRegExpr;
  Once: TStringList;
begin
  Once := TStringList.Create;
  R := TRegExpr.Create('W = ''([a-z0-9?]+)''');
  try
    if R.Exec(Body) then
      repeat
        if Once.IndexOf(R.Match[1]) >= 0 then
          Fail(Format('''%s'' is compared twice in RunCommand - the second is ' +
            'dead code, and the first is what /%s actually does',
            [R.Match[1], R.Match[1]]))
        else
          Once.Add(R.Match[1]);
      until not R.ExecNext;
  finally
    R.Free;
    Once.Free;
  end;
end;

var
  Path: string;
  Distinct: TStringList;
  I: Integer;
begin
  Path := 'uMain.pas';
  if ParamCount > 0 then Path := ParamStr(1);
  Src := ReadAll(Path);
  Bad := False;
  Names := TStringList.Create;
  Hints := TStringList.Create;
  Egs := TStringList.Create;
  Alsos := TStringList.Create;
  Args := TStringList.Create;
  Known := TStringList.Create;
  Seen := TStringList.Create;
  try
    ReadTable;
    ReadDispatcher;
    CheckRows;
    CheckTwice;
    Distinct := TStringList.Create;
    try
      Distinct.Sorted := True;
      Distinct.Duplicates := dupIgnore;
      for I := 0 to Known.Count - 1 do Distinct.Add(Known[I]);
      WriteLn(Format('%d commands offered, %d words the dispatcher knows',
        [Names.Count, Distinct.Count]));
    finally
      Distinct.Free;
    end;
  finally
    Names.Free; Hints.Free; Egs.Free; Alsos.Free; Args.Free;
    Known.Free; Seen.Free;
  end;
  if Bad then
  begin
    WriteLn('command list FAILED');
    Halt(1);
  end;
  WriteLn('command list ok');
end.
