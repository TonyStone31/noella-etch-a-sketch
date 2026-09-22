unit uHeckComplete;

{ Code completion for Heck in the source window - the way an editor does it
  now, not the way Lazarus does: the list comes up on its own after a short
  pause on a word being typed, narrows as the word grows, and Enter or Tab
  takes the pick.  Escape puts it away and it stays away for that word.

  What it offers depends on where the caret is:

    at the start of a line     the things that can go there - face, line,
                               solid, group, points, circle... - and, inside
                               a block that has properties, those, with a
                               hint of what goes after the "="
    after "="                  point names in scope, then circles, then the
                               words a value can be (true, false, none, the
                               colors, the directions)
    after a number             the six directions
    anywhere else              point and circle names

  Names come out of the text itself - every "name = place" line in a points
  block above the caret, every "ring x" (as x1..xN), every "circle cN" - so
  it knows the same names the reader will.  Nothing here reads the drawing;
  it reads the words. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, Forms, ExtCtrls, LCLType,
  SynEdit, SynCompletion, SynEditKeyCmds, LazUTF8;

type

  { THeckCompleter }

  THeckCompleter = class
  private
    FEd: TSynEdit;
    FBox: TSynCompletion;
    FTimer: TTimer;
    FDeclined: string;         { the word the list was dismissed on }
    FInserts: TStringList;     { what each item puts in, matching ItemList }
    FDark: Boolean;
    procedure EditorChange(Sender: TObject);
    procedure EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TimerTick(Sender: TObject);
    procedure BoxExecute(Sender: TObject);
    procedure BoxCancel(Sender: TObject);
    procedure BoxCodeCompletion(var Value: string; SourceValue: string;
      var SourceStart, SourceEnd: TPoint; KeyChar: TUTF8Char; Shift: TShiftState);
    function BoxPaintItem(const AKey: string; ACanvas: TCanvas; X, Y: integer;
      Selected: boolean; Index: integer): boolean;
    procedure BoxSearchPosition(var APosition: integer);
    function WordBeforeCaret(out StartX: Integer): string;
    procedure Gather(const Prefix: string);
    procedure Offer(const Show, Insert, Hint: string);
  public
    constructor Create(Ed: TSynEdit);
    destructor Destroy; override;
    procedure UseDark(Dark: Boolean; Back, Fore: TColor);
    { open it now, on whatever is under the caret - Ctrl+Space }
    procedure Open;
    property Box: TSynCompletion read FBox;
  end;

implementation

const
  { blocks, and what may be said in each: "prop|hint" }
  THINGS = 'face line box rect solid group points circle arc ring const dim note guide bore';
  TOP_PROPS: array[0..3] of string = ('ink|= black, red, #RRGGBB', 'width|= 1',
    'sides|= 24', 'units|= ft in, in, mm, m');
  FACE_PROPS: array[0..3] of string = ('points|= a b c d, or places joined with "to"',
    'hole|= c1, or corners the other way round', 'paint|= orange, #RRGGBB, none', 'ink|= black, #RRGGBB');
  LINE_PROPS: array[0..4] of string = ('points|= a to b', 'ink|= black, #RRGGBB', 'width|= 1',
    'soft|= true', 'ref|= true');
  CIRCLE_PROPS: array[0..7] of string = ('center|= 2'' east, 2'' north, 0 up', 'radius|= 1''',
    'facing|= up, north, east...', 'starts|= 0°', 'sweep|= 90°  (an arc)', 'sides|= 24',
    'ink|= black', 'width|= 1');
  RING_PROPS: array[0..4] of string = ('center|= 2'' east, 2'' north, 0 up', 'radius|= 1''',
    'sides|= 24', 'facing|= up', 'starts|= 0°');
  SOLID_PROPS: array[0..0] of string = ('paint|= orange, #RRGGBB');
  BOX_PROPS: array[0..2] of string = ('at|= 0 east, 0 north, 0 up  (the low southwest corner)',
    'size|= 4'' east, 3'' north, 2'' up', 'paint|= orange, #RRGGBB');
  GROUP_PROPS: array[0..1] of string = ('locked|= true', 'jig|= ''name'' with A = 1, B = 2''');
  DIM_PROPS: array[0..4] of string = ('from|= a', 'to|= b', 'off|= 6" north', 'label|= ''text''', 'ink|= black');
  NOTE_PROPS: array[0..4] of string = ('at|= 1'' east, 1'' north, 0 up', 'text|= ''words''',
    'to|= a  (what it points at)', 'size|= 1', 'ink|= black');
  BORE_PROPS: array[0..1] of string = ('points|= a b c d', 'goes|= 6" down');
  DIRS: array[0..5] of string = ('east', 'west', 'north', 'south', 'up', 'down');
  VALUES: array[0..12] of string = ('true', 'false', 'none', 'black', 'white', 'gray',
    'red', 'orange', 'yellow', 'green', 'blue', 'purple', 'brown');
  THING_HINTS: array[0..14] of string = (
    'a flat area: face = a b c d',
    'two points: line = a to b',
    'a block: box = corner; size, or a block with at, size, paint',
    'a rectangle: rect = corner; size with two parts',
    'a closed thing, with its own points and faces',
    'things that move as one; can be locked, or made by a jig',
    'named places: a = 1'' east, 2'' north, 0 up',
    'center, radius, facing',
    'center, radius, facing, starts, sweep',
    'corners round a circle, named ra1..raN',
    'named numbers: Width = 4''',
    'a dimension: from, to, off',
    'a note: at, text',
    'guide = a place, or two',
    'a tunnel in a solid: points, goes');

constructor THeckCompleter.Create(Ed: TSynEdit);
begin
  inherited Create;
  FEd := Ed;
  FInserts := TStringList.Create;
  FBox := TSynCompletion.Create(Ed.Owner);
  FBox.Editor := Ed;
  FBox.ShortCut := KeyToShortCut(VK_SPACE, [ssCtrl]);
  FBox.CaseSensitive := False;
  FBox.Width := 520;
  FBox.LinesInWindow := 10;
  FBox.EndOfTokenChr := ' =,;()';
  FBox.ToggleReplaceWhole := True;
  FBox.OnExecute := @BoxExecute;
  FBox.OnCancel := @BoxCancel;
  FBox.OnCodeCompletion := @BoxCodeCompletion;
  FBox.OnPaintItem := @BoxPaintItem;
  FBox.OnSearchPosition := @BoxSearchPosition;
  FBox.ShowSizeDrag := True;
  { one match is still shown, never typed in for you - "lin", a pause, and
    it had become "line" under the fingers, which then typed the e }
  FBox.AutoUseSingleIdent := False;
  FTimer := TTimer.Create(nil);
  FTimer.Enabled := False;
  FTimer.Interval := 300;
  FTimer.OnTimer := @TimerTick;
  Ed.OnChange := @EditorChange;
  Ed.OnKeyDown := @EditorKeyDown;
end;

destructor THeckCompleter.Destroy;
begin
  FTimer.Free;
  FInserts.Free;
  inherited Destroy;
end;

procedure THeckCompleter.UseDark(Dark: Boolean; Back, Fore: TColor);
begin
  FDark := Dark;
  FBox.TheForm.Color := Back;
  FBox.TheForm.TextColor := Fore;
  FBox.TheForm.BackgroundColor := Back;
  if Dark then
  begin
    FBox.TheForm.ClSelect := TColor($806040);
    FBox.TheForm.TextSelectedColor := clWhite;
    FBox.TheForm.DrawBorderColor := TColor($707070);
  end
  else
  begin
    FBox.TheForm.ClSelect := TColor($F0D8C0);
    FBox.TheForm.TextSelectedColor := clBlack;
    FBox.TheForm.DrawBorderColor := TColor($A0A0A0);
  end;
end;

{ the word being typed, up to the caret }
function THeckCompleter.WordBeforeCaret(out StartX: Integer): string;
var
  L: string;
  X: Integer;
begin
  Result := '';
  StartX := FEd.CaretX;
  if (FEd.CaretY < 1) or (FEd.CaretY > FEd.Lines.Count) then Exit;
  L := FEd.Lines[FEd.CaretY - 1];
  X := FEd.CaretX - 1;
  while (X >= 1) and (X <= Length(L)) and (L[X] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Dec(X);
  StartX := X + 1;
  Result := Copy(L, X + 1, FEd.CaretX - 1 - X);
end;

procedure THeckCompleter.EditorChange(Sender: TObject);
var
  W: string;
  SX: Integer;
begin
  if FEd.ReadOnly then Exit;
  W := WordBeforeCaret(SX);
  { a word being typed, one letter or more, that has not been waved away }
  if (W = '') or not (W[1] in ['A'..'Z', 'a'..'z', '_']) then
  begin
    FTimer.Enabled := False;
    if FBox.IsActive then FBox.Deactivate;
    Exit;
  end;
  if SameText(W, FDeclined) then Exit;
  if FBox.IsActive then Exit;      { it narrows itself as the word grows }
  FTimer.Enabled := False;
  FTimer.Enabled := True;
end;

procedure THeckCompleter.EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  { arrows and the rest: not a reason to open the list }
  if Key in [VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN, VK_HOME, VK_END, VK_PRIOR, VK_NEXT, VK_ESCAPE] then
  begin
    FTimer.Enabled := False;
    FDeclined := '';
  end;
end;

procedure THeckCompleter.TimerTick(Sender: TObject);
begin
  FTimer.Enabled := False;
  if FEd.ReadOnly then Exit;
  Open;
end;

procedure THeckCompleter.Open;
var
  W: string;
  SX: Integer;
  P: TPoint;
begin
  W := WordBeforeCaret(SX);
  Gather(W);
  if FBox.ItemList.Count = 0 then Exit;
  P := FEd.ClientToScreen(FEd.RowColumnToPixels(Point(SX, FEd.CaretY)));
  P.Y := P.Y + FEd.LineHeight;
  FBox.Execute(W, P.X, P.Y);
end;

procedure THeckCompleter.BoxExecute(Sender: TObject);
begin
  { the list is filled before Execute; nothing to do here but keep the
    current string in step, which the box does itself }
end;

procedure THeckCompleter.BoxCancel(Sender: TObject);
var
  SX: Integer;
begin
  FDeclined := WordBeforeCaret(SX);
end;

procedure THeckCompleter.BoxCodeCompletion(var Value: string; SourceValue: string;
  var SourceStart, SourceEnd: TPoint; KeyChar: TUTF8Char; Shift: TShiftState);
var
  I: Integer;
begin
  I := FBox.Position;
  if (I >= 0) and (I < FInserts.Count) then Value := FInserts[I];
  FDeclined := '';
end;

{ the word in the ordinary face, and its hint after it, dim }
function THeckCompleter.BoxPaintItem(const AKey: string; ACanvas: TCanvas; X, Y: integer;
  Selected: boolean; Index: integer): boolean;
var
  P: Integer;
  W, H: string;
begin
  P := Pos('|', AKey);
  if P > 0 then
  begin
    W := Copy(AKey, 1, P - 1);
    H := Copy(AKey, P + 1, MaxInt);
  end
  else
  begin
    W := AKey;
    H := '';
  end;
  ACanvas.Font.Style := [fsBold];
  ACanvas.TextOut(X + 2, Y, W);
  if H <> '' then
  begin
    ACanvas.Font.Style := [];
    if FDark then ACanvas.Font.Color := TColor($A0A0A0) else ACanvas.Font.Color := TColor($707070);
    ACanvas.TextOut(X + 2 + ACanvas.TextWidth(W + '  '), Y, H);
  end;
  Result := True;
end;

{ the first item whose word starts with what has been typed }
procedure THeckCompleter.BoxSearchPosition(var APosition: integer);
var
  I: Integer;
  W: string;
begin
  W := LowerCase(FBox.CurrentString);
  APosition := -1;
  for I := 0 to FBox.ItemList.Count - 1 do
    if (W = '') or (Pos(W, LowerCase(FBox.ItemList[I])) = 1) then
    begin
      APosition := I;
      Exit;
    end;
end;

procedure THeckCompleter.Offer(const Show, Insert, Hint: string);
begin
  if Hint <> '' then FBox.ItemList.Add(Show + '|' + Hint)
  else FBox.ItemList.Add(Show);
  FInserts.Add(Insert);
end;

{ What fits here.  The names in scope are read off the text above the
  caret; the block the caret is in is found by walking back to the nearest
  unclosed opening line. }
procedure THeckCompleter.Gather(const Prefix: string);
var
  Y, I, K, Depth, P, N: Integer;
  L, T, Before, Key, Block, W, Stem: string;
  Names, Rings: TStringList;
  Pfx: string;

  function Opens(const S: string): Boolean;
  begin
    Result := (S <> '') and (Pos('=', S) = 0) and (S <> 'end') and (S <> 'begin') and
              (S[Length(S)] <> ')');
  end;

  procedure Props(const A: array of string);
  var
    J, Q: Integer;
  begin
    for J := 0 to High(A) do
    begin
      Q := Pos('|', A[J]);
      if (Pfx = '') or (Pos(Pfx, LowerCase(Copy(A[J], 1, Q - 1))) = 1) then
        Offer(Copy(A[J], 1, Q - 1), Copy(A[J], 1, Q - 1) + ' = ', Copy(A[J], Q + 1, MaxInt));
    end;
  end;

  procedure Word_(const S, Hint: string);
  begin
    if (Pfx = '') or (Pos(Pfx, LowerCase(S)) = 1) then Offer(S, S, Hint);
  end;

begin
  FBox.ItemList.Clear;
  FInserts.Clear;
  Pfx := LowerCase(Prefix);
  Y := FEd.CaretY - 1;
  if (Y < 0) or (Y >= FEd.Lines.Count) then Exit;
  L := FEd.Lines[Y];
  Before := Copy(L, 1, FEd.CaretX - 1 - Length(Prefix));
  T := Trim(Before);

  { the block we are in }
  Block := '';
  Depth := 0;
  for I := Y - 1 downto 0 do
  begin
    W := LowerCase(Trim(FEd.Lines[I]));
    P := Pos('{', W);
    if P > 0 then W := Trim(Copy(W, 1, P - 1));
    if W = 'end' then Inc(Depth)
    else if Opens(W) then
    begin
      if Depth = 0 then
      begin
        P := Pos(' ', W + ' ');
        Block := Copy(W, 1, P - 1);
        Break;
      end;
      Dec(Depth);
    end;
  end;

  { names in scope: every "name = " in a points block, every ring, every
    circle, above the caret and not closed off }
  Names := TStringList.Create;
  Rings := TStringList.Create;
  try
    Names.Sorted := True;
    Names.Duplicates := dupIgnore;
    for I := 0 to FEd.Lines.Count - 1 do
    begin
      if I = Y then Continue;
      W := Trim(FEd.Lines[I]);
      if LowerCase(Copy(W, 1, 7)) = 'circle ' then
        Names.Add(Trim(Copy(W, 8, MaxInt)))
      else if LowerCase(Copy(W, 1, 5)) = 'ring ' then
        Rings.Add(Trim(Copy(W, 6, MaxInt)))
      else
      begin
        P := Pos('=', W);
        if P > 0 then
        begin
          Key := Trim(Copy(W, 1, P - 1));
          if (Key <> '') and (Pos(' ', Key) = 0) and (Key[1] in ['a'..'z', 'A'..'Z']) and
             (Pos(' east', W) + Pos(' north', W) + Pos(' up', W) + Pos(' west', W) +
              Pos(' south', W) + Pos(' down', W) + Pos(' x ', W) > 0) and
             (Pos('=', Copy(W, P + 1, MaxInt)) = 0) and (Pos(' to ', W) = 0) then
            Names.Add(Key);
        end;
      end;
    end;

    { what goes here }
    if T = '' then
    begin
      { the start of a line: a thing, or a property of the block }
      if Block = 'face' then Props(FACE_PROPS)
      else if Block = 'line' then Props(LINE_PROPS)
      else if (Block = 'circle') or (Block = 'arc') then Props(CIRCLE_PROPS)
      else if Block = 'ring' then Props(RING_PROPS)
      else if Block = 'dim' then Props(DIM_PROPS)
      else if Block = 'note' then Props(NOTE_PROPS)
      else if Block = 'bore' then Props(BORE_PROPS)
      else if Block = 'group' then Props(GROUP_PROPS)
      else if Block = 'solid' then Props(SOLID_PROPS)
      else if (Block = 'box') or (Block = 'rect') then Props(BOX_PROPS)
      else if Block = 'sheet' then Props(TOP_PROPS);
      if Block = 'points' then
      begin
        Word_('ring', 'corners round a circle: ring ra ... end');
        Word_('end', 'closes the block');
      end
      else if (Block <> 'face') and (Block <> 'line') and (Block <> 'circle') and (Block <> 'arc') and
              (Block <> 'ring') and (Block <> 'dim') and (Block <> 'note') and (Block <> 'bore') and
              (Block <> 'box') and (Block <> 'rect') then
      begin
        N := 0;
        for K := 1 to Length(THINGS) + 1 do
          if (K > Length(THINGS)) or (THINGS[K] = ' ') then
          begin
            W := Copy(THINGS, 1, K - 1);
            P := Length(W);
            while (P > 0) and (W[P] <> ' ') do Dec(P);
            W := Copy(W, P + 1, MaxInt);
            if W <> '' then
              { a thing that is written on one line comes with its "= "
                ready; a block-opener is its word, and what follows it - a
                name, or a new line - is the person's }
              if (W = 'face') or (W = 'line') or (W = 'guide') or (W = 'box') or (W = 'rect') then
              begin
                if (Pfx = '') or (Pos(Pfx, W) = 1) then Offer(W, W + ' = ', THING_HINTS[N]);
              end
              else
                Word_(W, THING_HINTS[N]);
            Inc(N);
          end;
        if Block <> '' then Word_('end', 'closes the block');
      end
      else
        Word_('end', 'closes the block');
    end
    else if T[Length(T)] in ['0'..'9', '"', '''', '.'] then
    begin
      for I := 0 to High(DIRS) do Word_(DIRS[I], '');
    end
    else if (T[Length(T)] = '=') or (Copy(T, Length(T) - 2, 3) = ' to') or (T[Length(T)] = '+') then
    begin
      for I := 0 to Names.Count - 1 do Word_(Names[I], '');
      for I := 0 to Rings.Count - 1 do Word_(Rings[I] + '1', 'first corner of ring ' + Rings[I]);
      if T[Length(T)] = '=' then
        for I := 0 to High(VALUES) do Word_(VALUES[I], '');
    end
    else
    begin
      for I := 0 to Names.Count - 1 do Word_(Names[I], '');
      for I := 0 to Rings.Count - 1 do Word_(Rings[I] + '1', 'first corner of ring ' + Rings[I]);
      { a ring's corner partly typed: ra1, ra12 }
      Stem := Pfx;
      while (Stem <> '') and (Stem[Length(Stem)] in ['0'..'9']) do SetLength(Stem, Length(Stem) - 1);
      for I := 0 to Rings.Count - 1 do
        if SameText(Stem, Rings[I]) and (Stem <> Pfx) then
          for K := 1 to 48 do
            if Pos(Pfx, LowerCase(Rings[I] + IntToStr(K))) = 1 then Offer(Rings[I] + IntToStr(K), Rings[I] + IntToStr(K), '');
      for I := 0 to High(DIRS) do Word_(DIRS[I], '');
    end;
  finally
    Rings.Free;
    Names.Free;
  end;
end;

end.
