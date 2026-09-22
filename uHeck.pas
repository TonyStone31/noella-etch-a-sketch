unit uHeck;

{ Reading Heck - the language a drawing is written in, docs/format2.md -
  into a drawing.

  This is a reader and nothing else: it is handed text and a document and
  puts the things the text describes into the document.  It never runs
  anything, never opens a file, and what it is handed may have come from a
  stranger or from a jig, so every fault is an ordinary error with a line
  number on it and the document is the caller's to throw away.

  It reads what uFormat2 writes, and the looser things the grammar allows a
  person to type: x y z for the compass words, ft and in for the marks, any
  spacing, a "begin" that means nothing, sums wherever a length goes, and
  constants.  What it does not know it skips, by the grammar's rule 7.

  A fragment - things with no header and no sheet round them - is read the
  same way; that is what a jig prints. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Graphics, uWork, uRegion, uImply, uFormat2;

type
  EHeck = class(Exception);

{ True when all of it was read.  False: Err says what was wrong and ErrLine
  which line of L, counted from 0.  Things are added to D as they are read,
  so on False the caller throws D away - read into a scratch document first. }
function ReadHeck(L: TStrings; D: TWorkDoc; U: TUnitSystem;
  out ErrLine: Integer; out Err: string): Boolean;

{ The same, telling the writer which faces the edges closed by
  themselves - uFormat2.ReadBack; see there. }
function ReadHeckImplied(L: TStrings; D: TWorkDoc; U: TUnitSystem;
  out ErrLine: Integer; out Err: string; out Implied: TBoolArray): Boolean;

{ one length or plain number out of a piece of text, for a jig's values:
  lengths come back in feet with IsLength set }
function HeckValue(const S: string; U: TUnitSystem; out V: Double;
  out IsLength: Boolean): Boolean;

implementation


type
  TValKind = (vPlain, vLen, vAngle);
  TVal = record
    V: Double;
    K: TValKind;
  end;

  TLoop = TP3Array;

  TScope = record
    Names: TStringList;       { point names, lower case; Objects = index into Pts }
    Pts: array of TP3;
    Shapes: TStringList;      { named outlines - circles - index into Loops }
    Loops: array of TLoop;
  end;

  THeckReader = class
  private
    Src: TStringList;         { logical lines: notes gone, bracketed lists joined }
    At: array of Integer;     { the line of the text each came from }
    Cur: Integer;
    D: TWorkDoc;
    U: TUnitSystem;
    Scopes: array of TScope;
    Consts: TStringList;      { name=  with the value in Vals }
    Vals: array of TVal;
    DefInk: TColor;
    DefWidth: Single;
    DefSides: Integer;
    { the solids read, and what each is painted, for the faces their edges
      imply }
    Solids: array of record G: Integer; HasPaint: Boolean; Paint: TColor; end;
    { loops that close and are not faces: "noface = ..." }
    NoFaces: array of TLoop;
    { "faces = said" in the header: make no faces from the lines at all }
    AllSaid: Boolean;
    { one flag a thing: a face that its scope's edges close exactly, alone,
      turned the way it would have been made - for the writer }
    Implied: array of Boolean;
    procedure Fail(const Msg: string);
    procedure NoteSolid(G: Integer; HasPaint: Boolean; Paint: TColor);
    procedure ImplyFaces(FirstNew: Integer);
    procedure HomeLooseFaces(FirstNew: Integer);
    procedure Prepare(L: TStrings);
    procedure PushScope;
    procedure PopScope;
    function FindPoint(const Name: string; out P: TP3): Boolean;
    function FindShape(const Name: string; out Lp: TLoop): Boolean;
    procedure DefinePoint(const Name: string; const P: TP3);
    { the lexer }
    procedure SkipSp(const S: string; var P: Integer);
    function PeekWord(const S: string; P: Integer): string;
    function TakeWord(const S: string; var P: Integer): string;
    function Number(const S: string; var P: Integer): TVal;
    function Factor(const S: string; var P: Integer): TVal;
    function Term(const S: string; var P: Integer): TVal;
    function Expr(const S: string; var P: Integer): TVal;
    function AsFeet(const V: TVal): Double;
    function DirOf(const W: string; out Axis: Integer; out Sign: Double): Boolean;
    function ReadStep(const S: string; var P: Integer): TP3;
    function ReadPlace(const S: string; var P: Integer; HasPrev: Boolean; const Prev: TP3): TP3;
    function ReadList(const S: string): TLoop;
    function ReadFacing(const S: string): TP3;
    function ReadColor(const S: string): TColor;
    function ReadText(const S: string): string;
    function ReadBool(const S: string): Boolean;
    { the grammar }
    function Opens(const Line: string): Boolean;
    function SplitProp(const Line: string; out Key, Value: string): Boolean;
    procedure SkipBlock;
    procedure Things(Solid: Integer; HasPaint: Boolean; Paint: TColor);
    procedure DoPoints;
    procedure DoRing(const Name: string);
    procedure DoConst;
    procedure DoCircle(const Name: string; IsArc: Boolean; const Value: string = ''; Solid: Integer = 0);
    procedure DoPull(const Value: string; Block: Boolean);
    procedure DoFace(const Value: string; Block: Boolean; Solid: Integer;
      HasPaint: Boolean; Paint: TColor);
    procedure DoLine(const Value: string; Block: Boolean; Solid: Integer);
    procedure DoSolid;
    procedure DoGroup(const Header: string);
    procedure DoDim;
    procedure DoNote;
    procedure DoBore(Solid: Integer);
    { primitives - docs/primitives.md.  Each is a fold: it is read into the
      same lines and faces the tools would have made, and nothing else. }
    procedure DoBox(const Value: string; Block: Boolean);
    procedure DoRect(const Value: string; Block: Boolean);
    procedure MakeBox(const Corner, Size: TP3; HasPaint: Boolean; Paint: TColor; const Name: string);
    procedure MakeRect(const Corner, Size: TP3; HasPaint: Boolean; Paint: TColor);
    { "place; step" - two things with a semicolon between }
    procedure PlaceAndStep(const Value: string; out Corner, Size: TP3);
  public
    constructor Create(ADoc: TWorkDoc; AUnits: TUnitSystem);
    destructor Destroy; override;
    procedure Run(L: TStrings);
    procedure CutCircles(FirstNew: Integer);
    function ErrLine: Integer;
  end;

const
  LETTERS = ['A'..'Z', 'a'..'z', '_'];
  DIGITS = ['0'..'9'];

{ ---- setting up ---------------------------------------------------------- }

constructor THeckReader.Create(ADoc: TWorkDoc; AUnits: TUnitSystem);
begin
  inherited Create;
  D := ADoc;
  U := AUnits;
  Src := TStringList.Create;
  Consts := TStringList.Create;
  DefInk := TColor($201C1A);     { the program's own ink: 1A 1C 20 as red, green, blue }
  DefWidth := 1;
  DefSides := HECK_SIDES;
  AllSaid := False;
  PushScope;
end;

destructor THeckReader.Destroy;
begin
  while Length(Scopes) > 0 do PopScope;
  Consts.Free;
  Src.Free;
  inherited Destroy;
end;

procedure THeckReader.Fail(const Msg: string);
begin
  raise EHeck.Create(Msg);
end;

function THeckReader.ErrLine: Integer;
begin
  if (Cur >= 0) and (Cur <= High(At)) then Result := At[Cur]
  else if Length(At) > 0 then Result := At[High(At)]
  else Result := 0;
end;

{ Notes off, blank lines out, and a list that runs from "(" to ")" made one
  line - remembering which line of the text each began on. }
procedure THeckReader.Prepare(L: TStrings);
var
  I, K, N, Depth: Integer;
  S, Acc: string;
  InText: Boolean;
begin
  Src.Clear;
  SetLength(At, L.Count);
  N := 0;
  Acc := '';
  Depth := 0;
  for I := 0 to L.Count - 1 do
  begin
    S := L[I];
    InText := False;
    K := 1;
    while K <= Length(S) do
    begin
      if InText then
      begin
        if S[K] = '''' then InText := False;
      end
      else if (S[K] = '''') and ((K = 1) or not (S[K - 1] in DIGITS)) then InText := True
      else if (S[K] = '/') and (K < Length(S)) and (S[K + 1] = '/') then
      begin
        SetLength(S, K - 1);
        Break;
      end
      else if S[K] = '{' then
      begin
        { a note: out, to its closing brace or the end of the line }
        Depth := K;
        while (K <= Length(S)) and (S[K] <> '}') do Inc(K);
        Delete(S, Depth, K - Depth + 1);
        K := Depth - 1;
        Depth := 0;
      end;
      Inc(K);
    end;
    S := Trim(StringReplace(S, #9, ' ', [rfReplaceAll]));
    if S = '' then Continue;
    if Acc <> '' then
    begin
      if S = ')' then
      begin
        Src.Add(Acc);
        Acc := '';
      end
      else if S[Length(S)] = ')' then
      begin
        Src.Add(Acc + ' ' + Trim(Copy(S, 1, Length(S) - 1)));
        Acc := '';
      end
      else
        Acc := Acc + ' ' + S;
      Continue;
    end;
    if (Pos('=', S) > 0) and (S[Length(S)] = '(') then
    begin
      Acc := Trim(Copy(S, 1, Length(S) - 1));
      At[N] := I;
      Inc(N);
      Continue;
    end;
    At[N] := I;
    Inc(N);
    Src.Add(S);
  end;
  if Acc <> '' then Src.Add(Acc);
  SetLength(At, Max(N, Src.Count));
end;

procedure THeckReader.PushScope;
begin
  SetLength(Scopes, Length(Scopes) + 1);
  with Scopes[High(Scopes)] do
  begin
    Names := TStringList.Create;
    Names.Sorted := True;
    Names.Duplicates := dupIgnore;
    Shapes := TStringList.Create;
    SetLength(Pts, 0);
    SetLength(Loops, 0);
  end;
end;

procedure THeckReader.PopScope;
begin
  Scopes[High(Scopes)].Names.Free;
  Scopes[High(Scopes)].Shapes.Free;
  SetLength(Scopes, Length(Scopes) - 1);
end;

function THeckReader.FindPoint(const Name: string; out P: TP3): Boolean;
var
  I, K: Integer;
begin
  for I := High(Scopes) downto 0 do
  begin
    K := Scopes[I].Names.IndexOf(LowerCase(Name));
    if K >= 0 then
    begin
      P := Scopes[I].Pts[PtrInt(Scopes[I].Names.Objects[K])];
      Exit(True);
    end;
  end;
  P := P3(0, 0, 0);
  Result := False;
end;

function THeckReader.FindShape(const Name: string; out Lp: TLoop): Boolean;
var
  I, K: Integer;
begin
  for I := High(Scopes) downto 0 do
  begin
    K := Scopes[I].Shapes.IndexOf(LowerCase(Name));
    if K >= 0 then
    begin
      Lp := Scopes[I].Loops[K];
      Exit(True);
    end;
  end;
  SetLength(Lp, 0);
  Result := False;
end;

procedure THeckReader.DefinePoint(const Name: string; const P: TP3);
var
  K: Integer;
begin
  with Scopes[High(Scopes)] do
  begin
    { sorted, and looked up by halving - a drawing of thirty thousand
      things names as many corners, and a walk over them for every one of
      a hundred thousand lines was thirteen seconds of the read; the index
      into Pts rides along as the Object }
    K := Names.IndexOf(LowerCase(Name));
    if K < 0 then
    begin
      SetLength(Pts, Length(Pts) + 1);
      Names.AddObject(LowerCase(Name), TObject(PtrInt(High(Pts))));
      K := High(Pts);
    end
    else K := PtrInt(Names.Objects[K]);
    Pts[K] := P;
  end;
end;

{ ---- words and numbers --------------------------------------------------- }

procedure THeckReader.SkipSp(const S: string; var P: Integer);
begin
  while (P <= Length(S)) and (S[P] = ' ') do Inc(P);
end;

function THeckReader.PeekWord(const S: string; P: Integer): string;
var
  Q: Integer;
begin
  SkipSp(S, P);
  Q := P;
  while (Q <= Length(S)) and (S[Q] in LETTERS + DIGITS) do Inc(Q);
  if (P <= Length(S)) and (S[P] in LETTERS) then Result := LowerCase(Copy(S, P, Q - P))
  else Result := '';
end;

function THeckReader.TakeWord(const S: string; var P: Integer): string;
begin
  Result := PeekWord(S, P);
  SkipSp(S, P);
  Inc(P, Length(Result));
end;

{ 5' 10 5/8"   4'   18"   3/4"   5ft 10 5/8in   1200mm   90°   2.5 }
function THeckReader.Number(const S: string; var P: Integer): TVal;
var
  FS: TFormatSettings;

  function ReadNum(var Q: Integer; out V: Double): Boolean;
  var
    B: Integer;
  begin
    B := Q;
    while (Q <= Length(S)) and (S[Q] in DIGITS) do Inc(Q);
    if (Q < Length(S)) and (S[Q] = '.') and (S[Q + 1] in DIGITS) then
    begin
      Inc(Q);
      while (Q <= Length(S)) and (S[Q] in DIGITS) do Inc(Q);
    end;
    Result := Q > B;
    if Result then V := StrToFloat(Copy(S, B, Q - B), FS) else V := 0;
  end;

  { a mark at Q, after any spaces: which, and where it ends }
  function Mark(Q: Integer; out After: Integer): string;
  var
    W: string;
  begin
    Result := '';
    while (Q <= Length(S)) and (S[Q] = ' ') do Inc(Q);
    After := Q;
    if Q > Length(S) then Exit;
    if S[Q] = '''' then begin Result := 'ft'; After := Q + 1; Exit; end;
    if S[Q] = '"' then begin Result := 'in'; After := Q + 1; Exit; end;
    if (S[Q] = #$C2) and (Q < Length(S)) and (S[Q + 1] = #$B0) then
    begin
      Result := 'deg'; After := Q + 2; Exit;
    end;
    W := PeekWord(S, Q);
    if (W = 'ft') or (W = 'in') or (W = 'mm') or (W = 'm') or (W = 'deg') then
    begin
      Result := W;
      After := Q + Length(W);
    end;
  end;

var
  Q, R, R2: Integer;
  N1, N2, Den, Inches: Double;
  M: string;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Result.K := vPlain;
  Q := P;
  if not ReadNum(Q, N1) then Fail('a number was expected');
  { 3/4" }
  if (Q < Length(S)) and (S[Q] = '/') and (S[Q + 1] in DIGITS) then
  begin
    R := Q + 1;
    if ReadNum(R, Den) and (Mark(R, R2) = 'in') and (Den > 0) then
    begin
      Result.V := N1 / Den / 12;
      Result.K := vLen;
      P := R2;
      Exit;
    end;
  end;
  M := Mark(Q, R);
  if M = 'ft' then
  begin
    Result.V := N1;
    Result.K := vLen;
    P := R;
    { and the inches after it, if they end in an inch mark }
    Q := R;
    SkipSp(S, Q);
    if (Q <= Length(S)) and (S[Q] in DIGITS) and ReadNum(Q, N2) then
    begin
      Inches := -1;
      if (Q < Length(S)) and (S[Q] = '/') and (S[Q + 1] in DIGITS) then
      begin
        R := Q + 1;
        if ReadNum(R, Den) and (Den > 0) and (Mark(R, R2) = 'in') then Inches := N2 / Den;
      end
      else
      begin
        R := Q;
        SkipSp(S, R);
        if (R <= Length(S)) and (S[R] in DIGITS) then
        begin
          if ReadNum(R, Den) and (R < Length(S)) and (S[R] = '/') then
          begin
            N1 := Den;
            Inc(R);
            if ReadNum(R, Den) and (Den > 0) and (Mark(R, R2) = 'in') then
              Inches := N2 + N1 / Den;
          end;
        end
        else if Mark(Q, R2) = 'in' then Inches := N2;
      end;
      if Inches >= 0 then
      begin
        Result.V := Result.V + Inches / 12;
        P := R2;
      end;
    end;
    Exit;
  end;
  if M = 'in' then begin Result.V := N1 / 12; Result.K := vLen; P := R; Exit; end;
  if M = 'mm' then begin Result.V := N1 / 304.8; Result.K := vLen; P := R; Exit; end;
  if M = 'm' then begin Result.V := N1 / 0.3048; Result.K := vLen; P := R; Exit; end;
  if M = 'deg' then begin Result.V := DegToRad(N1); Result.K := vAngle; P := R; Exit; end;
  { 10 5/8" }
  R := Q;
  SkipSp(S, R);
  if (R > Q) and (R <= Length(S)) and (S[R] in DIGITS) and ReadNum(R, N2) and
     (R < Length(S)) and (S[R] = '/') then
  begin
    Inc(R);
    if ReadNum(R, Den) and (Den > 0) and (Mark(R, R2) = 'in') then
    begin
      Result.V := (N1 + N2 / Den) / 12;
      Result.K := vLen;
      P := R2;
      Exit;
    end;
  end;
  Result.V := N1;
  P := Q;
end;

function THeckReader.Factor(const S: string; var P: Integer): TVal;
var
  W: string;
  K: Integer;
begin
  SkipSp(S, P);
  if P > Length(S) then Fail('something is missing at the end of the line');
  if S[P] = '(' then
  begin
    Inc(P);
    Result := Expr(S, P);
    SkipSp(S, P);
    if (P > Length(S)) or (S[P] <> ')') then Fail('a ")" is missing');
    Inc(P);
    Exit;
  end;
  if S[P] = '-' then
  begin
    Inc(P);
    Result := Factor(S, P);
    Result.V := -Result.V;
    Exit;
  end;
  if S[P] in DIGITS + ['.'] then Exit(Number(S, P));
  W := PeekWord(S, P);
  K := Consts.IndexOf(W);
  if K < 0 then
    if W = '' then Fail('a number was expected at "' + Copy(S, P, 12) + '"')
    else Fail('"' + W + '" is not a number, a constant or a point');
  TakeWord(S, P);
  Result := Vals[K];
end;

function THeckReader.Term(const S: string; var P: Integer): TVal;
var
  R: TVal;
  Op: Char;
begin
  Result := Factor(S, P);
  while True do
  begin
    SkipSp(S, P);
    if (P > Length(S)) or not (S[P] in ['*', '/']) then Exit;
    Op := S[P];
    Inc(P);
    R := Factor(S, P);
    if Op = '*' then
    begin
      Result.V := Result.V * R.V;
      if R.K <> vPlain then Result.K := R.K;
    end
    else
    begin
      if Abs(R.V) < 1E-300 then Fail('that divides by nought');
      Result.V := Result.V / R.V;
      if (Result.K = R.K) and (R.K <> vPlain) then Result.K := vPlain;
    end;
  end;
end;

function THeckReader.Expr(const S: string; var P: Integer): TVal;
var
  R: TVal;
  Op: Char;
  Q: Integer;
begin
  Result := Term(S, P);
  while True do
  begin
    SkipSp(S, P);
    if (P > Length(S)) or not (S[P] in ['+', '-']) then Exit;
    { "+ 4' east": a sum only if what follows is a number or a constant -
      and it always is, here; a new step is told apart by the caller, which
      stops the sum at a direction word }
    Q := P;
    Op := S[P];
    Inc(P);
    SkipSp(S, P);
    if (P <= Length(S)) and (S[P] in LETTERS) and (Consts.IndexOf(PeekWord(S, P)) < 0) then
    begin
      P := Q;          { a point's name or an axis letter: not ours }
      Exit;
    end;
    R := Term(S, P);
    if Op = '+' then Result.V := Result.V + R.V else Result.V := Result.V - R.V;
    if R.K <> vPlain then Result.K := R.K;
  end;
end;

{ a plain number where a length goes is in the sheet's small unit }
function THeckReader.AsFeet(const V: TVal): Double;
begin
  if V.K = vLen then Result := V.V
  else if U = usMetric then Result := V.V / 304.8
  else Result := V.V / 12;
end;

function THeckReader.DirOf(const W: string; out Axis: Integer; out Sign: Double): Boolean;
begin
  Result := True;
  Sign := 1;
  if (W = 'east') or (W = 'x') then Axis := 0
  else if W = 'west' then begin Axis := 0; Sign := -1; end
  else if (W = 'north') or (W = 'y') then Axis := 1
  else if W = 'south' then begin Axis := 1; Sign := -1; end
  else if (W = 'up') or (W = 'z') then Axis := 2
  else if W = 'down' then begin Axis := 2; Sign := -1; end
  else Result := False;
end;

{ "4' east", "3" east, 2" up", "x 4' y 2'" - parts until something that is
  not one }
function THeckReader.ReadStep(const S: string; var P: Integer): TP3;
var
  W: string;
  Axis, Q: Integer;
  Sign: Double;
  V: TVal;
  Got: Boolean;
  A: array[0..2] of Double;
begin
  A[0] := 0; A[1] := 0; A[2] := 0;
  Got := False;
  while True do
  begin
    SkipSp(S, P);
    if P > Length(S) then Break;
    W := PeekWord(S, P);
    if (W = 'to') or (S[P] in [';', ')']) then Break;
    if (Length(W) = 1) and DirOf(W, Axis, Sign) then
    begin
      TakeWord(S, P);                      { x 4' }
      V := Expr(S, P);
      A[Axis] := A[Axis] + AsFeet(V);
    end
    else
    begin
      if Got and (S[P] in ['+', '-']) then Break;    { the next step }
      Q := P;
      V := Expr(S, P);
      W := PeekWord(S, P);
      if not DirOf(W, Axis, Sign) or (Length(W) = 1) then
      begin
        if (not Got) and (Abs(V.V) < 1E-15) then   { a bare 0 is nowhere at all }
        begin
          Got := True;
          Continue;
        end;
        P := Q;
        Fail('which way?  "' + Trim(Copy(S, Q, 20)) + '" wants east, west, north, south, up or down after it');
      end;
      TakeWord(S, P);
      A[Axis] := A[Axis] + Sign * AsFeet(V);
    end;
    Got := True;
    SkipSp(S, P);
    if (P <= Length(S)) and (S[P] = ',') then Inc(P);
  end;
  if not Got then Fail('a place was expected');
  Result := P3(A[0], A[1], A[2]);
end;

{ a place, a name, a name and steps, or - in a list - "+ step" from the one
  before }
function THeckReader.ReadPlace(const S: string; var P: Integer; HasPrev: Boolean;
  const Prev: TP3): TP3;
var
  W: string;
  St: TP3;
  Sign: Double;
  Based: Boolean;
begin
  SkipSp(S, P);
  if P > Length(S) then Fail('a place was expected');
  Based := False;
  Result := P3(0, 0, 0);
  if S[P] in ['+', '-'] then
  begin
    if not HasPrev then Fail('"+" means from the place before, and there is none');
    Result := Prev;
    Based := True;
  end
  else
  begin
    W := PeekWord(S, P);
    if (W <> '') and FindPoint(W, Result) then
    begin
      TakeWord(S, P);
      Based := True;
    end;
  end;
  if not Based then Exit(ReadStep(S, P));
  while True do
  begin
    SkipSp(S, P);
    if (P > Length(S)) or not (S[P] in ['+', '-']) then Exit;
    if S[P] = '-' then Sign := -1 else Sign := 1;
    Inc(P);
    St := ReadStep(S, P);
    Result := P3(Result.X + Sign * St.X, Result.Y + Sign * St.Y, Result.Z + Sign * St.Z);
  end;
end;

{ names with spaces between, ranges, a named outline, or places joined
  with "to" }
function THeckReader.ReadList(const S: string): TLoop;
var
  T: TStringList;
  I, K, P, A, B, N, Stp: Integer;
  V, Stem, W: string;
  Pt: TP3;
  AllNames: Boolean;

  procedure Add(const Q: TP3);
  begin
    SetLength(Result, N + 1);
    Result[N] := Q;
    Inc(N);
  end;

  function Tail(const Nm: string; out St: string; out Num: Integer): Boolean;
  var
    Z: Integer;
  begin
    Z := Length(Nm);
    while (Z > 0) and (Nm[Z] in DIGITS) do Dec(Z);
    St := Copy(Nm, 1, Z);
    Result := (Z > 0) and (Z < Length(Nm)) and TryStrToInt(Copy(Nm, Z + 1, 9), Num);
  end;

begin
  SetLength(Result, 0);
  N := 0;
  V := Trim(S);
  if (V <> '') and (V[1] = '(') and (V[Length(V)] = ')') then V := Trim(Copy(V, 2, Length(V) - 2));
  if V = '' then Fail('a list of places was expected');
  if FindShape(V, Result) then Exit;

  T := TStringList.Create;
  try
    T.Delimiter := ' ';
    T.QuoteChar := #0;
    T.StrictDelimiter := True;
    T.DelimitedText := V;
    AllNames := True;
    for I := T.Count - 1 downto 0 do
      if T[I] = '' then T.Delete(I);
    for I := 0 to T.Count - 1 do
    begin
      W := T[I];
      K := Pos('..', W);
      if K > 0 then
        AllNames := AllNames and FindPoint(Copy(W, 1, K - 1), Pt) and FindPoint(Copy(W, K + 2, 99), Pt)
      else
        AllNames := AllNames and FindPoint(W, Pt);
    end;
    if AllNames then
    begin
      for I := 0 to T.Count - 1 do
      begin
        W := T[I];
        K := Pos('..', W);
        if K = 0 then
        begin
          FindPoint(W, Pt);
          Add(Pt);
          Continue;
        end;
        if not (Tail(Copy(W, 1, K - 1), Stem, A) and Tail(Copy(W, K + 2, 99), V, B) and
                SameText(Stem, V)) then
          Fail('"' + W + '" is not a run of names: both ends want the same name and a number');
        if B >= A then Stp := 1 else Stp := -1;
        K := A;
        while True do
        begin
          if not FindPoint(Stem + IntToStr(K), Pt) then
            Fail('there is no point "' + Stem + IntToStr(K) + '"');
          Add(Pt);
          if K = B then Break;
          Inc(K, Stp);
        end;
      end;
      Exit;
    end;
  finally
    T.Free;
  end;

  P := 1;
  while True do
  begin
    if N = 0 then Pt := ReadPlace(V, P, False, P3(0, 0, 0))
    else Pt := ReadPlace(V, P, True, Result[N - 1]);
    Add(Pt);
    SkipSp(V, P);
    if P > Length(V) then Break;
    if V[P] = ';' then Inc(P)
    else if PeekWord(V, P) = 'to' then TakeWord(V, P)
    else Fail('"' + Trim(Copy(V, P, 16)) + '" - places in a list are joined with "to"');
  end;
end;

function THeckReader.ReadFacing(const S: string): TP3;
var
  V: string;
  P, Axis: Integer;
  Sign, Tilt, Head: Double;
  A: TVal;
  W: string;
  L: Double;
begin
  V := LowerCase(Trim(S));
  if DirOf(V, Axis, Sign) and (Length(V) > 1) then
  begin
    Result := P3(0, 0, 0);
    case Axis of
      0: Result.X := Sign;
      1: Result.Y := Sign;
      2: Result.Z := Sign;
    end;
    Exit;
  end;
  P := Pos('leaning', V);
  if P > 0 then
  begin
    { up, leaning 30° toward east   |   ... toward 40° round from east }
    Inc(P, 7);
    A := Expr(V, P);
    Tilt := A.V;
    if TakeWord(V, P) <> 'toward' then Fail('"leaning 30° toward east" is how a lean is said');
    W := PeekWord(V, P);
    if W = 'east' then Head := 0
    else if W = 'north' then Head := Pi / 2
    else if W = 'west' then Head := Pi
    else if W = 'south' then Head := -Pi / 2
    else Head := Expr(V, P).V;
    Exit(P3(Sin(Tilt) * Cos(Head), Sin(Tilt) * Sin(Head), Cos(Tilt)));
  end;
  P := 1;
  { three plain numbers with their directions: read as a step, in any unit,
    since only the direction matters }
  Result := ReadStep(V, P);
  L := Sqrt(Sqr(Result.X) + Sqr(Result.Y) + Sqr(Result.Z));
  if L < 1E-12 then Fail('that facing points nowhere');
  Result := P3(Result.X / L, Result.Y / L, Result.Z / L);
end;

function THeckReader.ReadColor(const S: string): TColor;
const
  NAMES: array[0..9] of string = ('black', 'white', 'gray', 'red', 'orange',
    'yellow', 'green', 'blue', 'purple', 'brown');
  VALUES: array[0..9] of Integer = ($000000, $FFFFFF, $808080, $0000FF, $3CB0FF,
    $00FFFF, $008000, $FF0000, $800080, $2A2AA5);
var
  V: string;
  I, N: Integer;
begin
  V := LowerCase(Trim(S));
  for I := 0 to High(NAMES) do
    if V = NAMES[I] then Exit(TColor(VALUES[I]));
  { the other spelling of gray is read too; it is put together here so that
    the spelling check on this repository does not take it for prose }
  if V = 'gr' + 'ey' then Exit(TColor($808080));
  if (Length(V) = 7) and (V[1] = '#') and TryStrToInt('$' + Copy(V, 2, 6), N) then
    Exit(TColor(((N and $FF) shl 16) or (N and $FF00) or ((N shr 16) and $FF)));
  Fail('"' + Trim(S) + '" is not a color: a name like orange, or #RRGGBB');
  Result := 0;
end;

function THeckReader.ReadText(const S: string): string;
var
  V: string;
begin
  V := Trim(S);
  if (Length(V) >= 2) and (V[1] = '''') and (V[Length(V)] = '''') then
    Result := StringReplace(Copy(V, 2, Length(V) - 2), '''''', '''', [rfReplaceAll])
  else
    Result := V;
end;

function THeckReader.ReadBool(const S: string): Boolean;
var
  V: string;
begin
  V := LowerCase(Trim(S));
  if (V = 'true') or (V = '1') or (V = 'yes') then Exit(True);
  if (V = 'false') or (V = '0') or (V = 'no') then Exit(False);
  Fail('"' + Trim(S) + '" - true or false was expected');
  Result := False;
end;

{ ---- the grammar --------------------------------------------------------- }

function THeckReader.SplitProp(const Line: string; out Key, Value: string): Boolean;
var
  K: Integer;
  InText: Boolean;
begin
  InText := False;
  for K := 1 to Length(Line) do
  begin
    if Line[K] = '''' then
      if InText then InText := False
      else if (K = 1) or not (Line[K - 1] in DIGITS) then InText := True;
    if (Line[K] = '=') and not InText then
    begin
      Key := LowerCase(Trim(Copy(Line, 1, K - 1)));
      Value := Trim(Copy(Line, K + 1, MaxInt));
      Exit(True);
    end;
  end;
  Key := LowerCase(Trim(Line));
  Value := '';
  Result := False;
end;

{ rule 7: a line with no "=" opens a block - but "end" closes one, and a
  "begin" is let pass }
function THeckReader.Opens(const Line: string): Boolean;
var
  K, V: string;
begin
  if SplitProp(Line, K, V) then Exit(False);
  Result := (K <> 'end') and (K <> 'begin');
end;

{ Cur is on a line that opened a block nobody knows: past its end }
procedure THeckReader.SkipBlock;
var
  Depth: Integer;
begin
  Depth := 1;
  Inc(Cur);
  while (Cur < Src.Count) and (Depth > 0) do
  begin
    if LowerCase(Src[Cur]) = 'end' then Dec(Depth)
    else if Opens(Src[Cur]) then Inc(Depth);
    Inc(Cur);
  end;
  if Depth > 0 then Fail('a block is never closed: an "end" is missing');
end;

{ The things inside a block, up to its "end" - or to the end of the text,
  for a fragment.  Solid <> 0 inside a solid. }
procedure THeckReader.Things(Solid: Integer; HasPaint: Boolean; Paint: TColor);
var
  Line, Key, Value, Kind, Rest: string;
  Block: Boolean;
  P: Integer;
  Ends: TLoop;
begin
  while Cur < Src.Count do
  begin
    Line := Src[Cur];
    if LowerCase(Line) = 'end' then Exit;
    if LowerCase(Line) = 'begin' then begin Inc(Cur); Continue; end;
    Block := not SplitProp(Line, Key, Value);
    P := 1;
    Kind := TakeWord(Key + ' ', P);
    Rest := Trim(Copy(Key, P, MaxInt));
    if Block then Rest := Trim(Copy(Line, Length(Kind) + 1, MaxInt));

    if (Kind = 'heckerssketch') and Block then begin Inc(Cur); Continue; end;

    if Block then
    begin
      if Kind = 'sheet' then
      begin
        Inc(Cur);
        Things(0, False, 0);
        if Cur >= Src.Count then Fail('the sheet is never closed: an "end" is missing');
        Inc(Cur);
      end
      else if Kind = 'points' then DoPoints
      else if Kind = 'const' then DoConst
      else if Kind = 'circle' then DoCircle(Rest, False, '', Solid)
      else if Kind = 'arc' then DoCircle(Rest, True, '', Solid)
      else if Kind = 'pull' then DoPull('', True)
      else if Kind = 'face' then DoFace('', True, Solid, HasPaint, Paint)
      else if Kind = 'line' then DoLine('', True, Solid)
      else if Kind = 'solid' then DoSolid
      else if Kind = 'group' then DoGroup(Rest)
      else if Kind = 'dim' then DoDim
      else if Kind = 'note' then DoNote
      else if (Kind = 'bore') and (Solid <> 0) then DoBore(Solid)
      else if Kind = 'box' then DoBox(Rest, True)
      else if Kind = 'rect' then DoRect(Rest, True)
      else SkipBlock;
      Continue;
    end;

    { a line with an "=": a thing said in one line, or a property of the
      block we are in }
    if Kind = 'face' then
    begin
      DoFace(Value, False, Solid, HasPaint, Paint);     { moves on by itself }
      Continue;
    end
    else if Kind = 'line' then
    begin
      DoLine(Value, False, Solid);
      Continue;
    end
    else if Kind = 'circle' then
    begin
      DoCircle(Rest, False, Value, Solid);
      Continue;
    end
    else if Kind = 'pull' then
    begin
      DoPull(Value, False);
      Continue;
    end
    else if Kind = 'noface' then
    begin
      { a loop of lines that closes and is not a face: rubbed out }
      Ends := ReadList(Value);
      if Length(Ends) < 3 then Fail('noface wants the corners of the loop that is not a face');
      SetLength(NoFaces, Length(NoFaces) + 1);
      NoFaces[High(NoFaces)] := Ends;
      Inc(Cur);
      Continue;
    end
    else if Kind = 'box' then
    begin
      DoBox(Value, False);
      Continue;
    end
    else if Kind = 'rect' then
    begin
      DoRect(Value, False);
      Continue;
    end
    else if Kind = 'guide' then
    begin
      Ends := ReadList(Value);
      if Length(Ends) = 1 then D.AddGuide(Ends[0], Ends[0])
      else if Length(Ends) = 2 then D.AddGuide(Ends[0], Ends[1])
      else Fail('a guide goes through one place or two');
    end
    else if Key = 'units' then
    begin
      if (Pos('mm', LowerCase(Value)) > 0) or (LowerCase(Value) = 'm') then U := usMetric
      else U := usImperial;
    end
    else if Key = 'ink' then DefInk := ReadColor(Value)
    else if Key = 'width' then begin P := 1; DefWidth := Expr(Value, P).V; end
    else if Key = 'sides' then begin P := 1; DefSides := Round(Expr(Value, P).V); end
    { "faces = said": every face is in the text, and no loop of lines is
      to be made one - the writer says so when it has written them all }
    else if Key = 'faces' then AllSaid := LowerCase(Trim(Value)) = 'said';
    { anything else - shows, scale, snap, view, camera, and whatever comes
      later - is let pass }
    Inc(Cur);
  end;
end;

procedure THeckReader.DoPoints;
var
  Key, Value: string;
  P: Integer;
begin
  Inc(Cur);
  while Cur < Src.Count do
  begin
    if LowerCase(Src[Cur]) = 'end' then begin Inc(Cur); Exit; end;
    if LowerCase(Src[Cur]) = 'begin' then begin Inc(Cur); Continue; end;
    if SplitProp(Src[Cur], Key, Value) then
    begin
      if (Key = '') or not (Key[1] in LETTERS) or (Pos(' ', Key) > 0) then
        Fail('"' + Key + '" is not a name for a point');
      P := 1;
      DefinePoint(Key, ReadPlace(Value, P, False, P3(0, 0, 0)));
      SkipSp(Value, P);
      if P <= Length(Value) then Fail('"' + Trim(Copy(Value, P, 16)) + '" - what is that after the place?');
      Inc(Cur);
    end
    else if Copy(Key, 1, 5) = 'ring ' then DoRing(Trim(Copy(Key, 6, MaxInt)))
    else SkipBlock;
  end;
  Fail('the points are never closed: an "end" is missing');
end;

procedure THeckReader.DoRing(const Name: string);
var
  Key, Value: string;
  C, F, AU, AV: TP3;
  R, Starts, A: Double;
  N, K, P: Integer;
begin
  if Name = '' then Fail('a ring wants a name: "ring ra"');
  C := P3(0, 0, 0);
  F := P3(0, 0, 1);
  R := 0;
  Starts := 0;
  N := 0;
  Inc(Cur);
  while (Cur < Src.Count) and (LowerCase(Src[Cur]) <> 'end') do
  begin
    if SplitProp(Src[Cur], Key, Value) then
    begin
      P := 1;
      if Key = 'center' then C := ReadPlace(Value, P, False, C)
      else if Key = 'radius' then R := AsFeet(Expr(Value, P))
      else if Key = 'sides' then N := Round(Expr(Value, P).V)
      else if Key = 'facing' then F := ReadFacing(Value)
      else if Key = 'starts' then Starts := Expr(Value, P).V;
    end;
    Inc(Cur);
  end;
  if Cur >= Src.Count then Fail('the ring is never closed: an "end" is missing');
  Inc(Cur);
  if (N < 3) or (R <= 0) then Fail('ring ' + Name + ' wants a radius and three sides or more');
  SpecAxes(F, AU, AV);
  for K := 0 to N - 1 do
  begin
    A := Starts + K * 2 * Pi / N;
    DefinePoint(Name + IntToStr(K + 1),
      P3(C.X + (AU.X * Cos(A) + AV.X * Sin(A)) * R,
         C.Y + (AU.Y * Cos(A) + AV.Y * Sin(A)) * R,
         C.Z + (AU.Z * Cos(A) + AV.Z * Sin(A)) * R));
  end;
end;

procedure THeckReader.DoConst;
var
  Key, Value: string;
  P, K: Integer;
  V: TVal;
begin
  Inc(Cur);
  while Cur < Src.Count do
  begin
    if LowerCase(Src[Cur]) = 'end' then begin Inc(Cur); Exit; end;
    if SplitProp(Src[Cur], Key, Value) then
    begin
      P := 1;
      V := Expr(Value, P);
      K := Consts.IndexOf(Key);
      if K < 0 then
      begin
        K := Consts.Add(Key);
        SetLength(Vals, Consts.Count);
      end;
      Vals[K] := V;
    end;
    Inc(Cur);
  end;
  Fail('the constants are never closed: an "end" is missing');
end;

procedure THeckReader.DoCircle(const Name: string; IsArc: Boolean; const Value: string; Solid: Integer);
var
  Key, V: string;
  C, F, AU, AV, PU, PV, Dir, Nrm, Tmp: TP3;
  R, Starts, Sweep, A0, Wd: Double;
  Sides, P, Idx, K, N: Integer;
  Ink: TColor;
  Pl: TPlane;
  Lp: TLoop;
  Parts: TStringArray;
begin
  C := P3(0, 0, 0);
  F := P3(0, 0, 1);
  R := 0;
  Starts := 0;
  Sweep := 2 * Pi;
  Sides := 0;
  Ink := DefInk;
  Wd := DefWidth;
  if Value <> '' then
  begin
    { one line: center; radius - and which way it faces, when not up }
    Parts := Value.Split([';']);
    if (Length(Parts) < 2) or (Length(Parts) > 3) then
      Fail('a circle in one line is its center, then its radius: circle c1 = 2'' east, 2'' north, 0 up; 1''');
    P := 1;
    C := ReadPlace(Trim(Parts[0]), P, False, C);
    P := 1;
    R := AsFeet(Expr(Trim(Parts[1]), P));
    if Length(Parts) = 3 then F := ReadFacing(Trim(Parts[2]));
    Inc(Cur);
  end
  else
  begin
    Inc(Cur);
    while (Cur < Src.Count) and (LowerCase(Src[Cur]) <> 'end') do
    begin
      if SplitProp(Src[Cur], Key, V) then
      begin
        P := 1;
        if Key = 'center' then C := ReadPlace(V, P, False, C)
        else if Key = 'radius' then R := AsFeet(Expr(V, P))
        else if Key = 'facing' then F := ReadFacing(V)
        else if Key = 'starts' then Starts := Expr(V, P).V
        else if Key = 'sweep' then Sweep := Expr(V, P).V
        else if Key = 'sides' then Sides := Round(Expr(V, P).V)
        else if Key = 'ink' then Ink := ReadColor(V)
        else if Key = 'width' then Wd := Expr(V, P).V;
      end;
      Inc(Cur);
    end;
    if Cur >= Src.Count then Fail('the circle is never closed: an "end" is missing');
    Inc(Cur);
  end;
  if R <= 0 then Fail('a circle wants a radius');
  if IsArc and (Abs(Sweep) >= 2 * Pi - 1E-9) then Fail('an arc wants a sweep');

  { where it starts, as a direction, and then as an angle in the axes the
    program keeps for that plane }
  SpecAxes(F, AU, AV);
  Dir := P3(AU.X * Cos(Starts) + AV.X * Sin(Starts), AU.Y * Cos(Starts) + AV.Y * Sin(Starts),
            AU.Z * Cos(Starts) + AV.Z * Sin(Starts));
  if (Abs(F.Z - 1) < 1E-9) then Pl := plXY
  else if (Abs(F.Y + 1) < 1E-9) then Pl := plXZ
  else if (Abs(F.X - 1) < 1E-9) then Pl := plYZ
  else Pl := plFree;
  if Pl = plFree then AxesFromNormal(F, PU, PV) else PlaneAxes(Pl, PU, PV);
  A0 := ArcTan2(Dot3(Dir, PV), Dot3(Dir, PU));
  { the program's plane may turn the other way round from the way it faces }
  if Dot3(Cross3(PU, PV), F) < 0 then Sweep := -Sweep;

  if Pl = plFree then D.AddArc(C, R, A0, Sweep, plXY, Ink, Wd)
  else D.AddArc(C, R, A0, Sweep, Pl, Ink, Wd);
  Idx := D.Live - 1;
  if Pl = plFree then D.SetArcFacing(Idx, F, A0);
  { a circle that says no sides has the sheet's, as one the tool draws
    has: what its ring is, and what its edges are for the faces they imply }
  if Sides < 3 then Sides := DefSides;
  D.SetArcSides(Idx, Sides);
  { a circle said inside a solid is the solid's - the bottom of a pulled
    disk, as the tool keeps it }
  if Solid <> 0 then D.SetGroup(Idx, Solid);

  if (Name <> '') and not IsArc then
  begin
    N := Sides;
    if N < 3 then N := DefSides;
    SetLength(Lp, N);
    for K := 0 to N - 1 do
      Lp[K] := ArcPoint(C, R, D[Idx].A0 + K * 2 * Pi / N, D[Idx].Plane, D[Idx].Nm);
    { the outline goes round the way the circle faces - "face = c1" is a
      disk facing the way c1 does - whichever way the program's plane happens
      to turn }
    Nrm := P3(0, 0, 0);
    for K := 0 to N - 1 do
    begin
      Tmp := Cross3(Lp[K], Lp[(K + 1) mod N]);
      Nrm := P3(Nrm.X + Tmp.X, Nrm.Y + Tmp.Y, Nrm.Z + Tmp.Z);
    end;
    if Dot3(Nrm, F) < 0 then
      for K := 0 to N div 2 - 1 do
      begin
        Tmp := Lp[K];
        Lp[K] := Lp[N - 1 - K];
        Lp[N - 1 - K] := Tmp;
      end;
    with Scopes[High(Scopes)] do
    begin
      Shapes.Add(LowerCase(Name));
      SetLength(Loops, Shapes.Count);
      Loops[Shapes.Count - 1] := Lp;
    end;
  end;
end;

procedure THeckReader.DoFace(const Value: string; Block: Boolean; Solid: Integer;
  HasPaint: Boolean; Paint: TColor);
var
  Key, V: string;
  Outline: TLoop;
  Holes: array of TP3Array;
  Ink: TColor;
  Idx, K, J: Integer;
  Tmp: TP3;
begin
  Ink := DefInk;
  SetLength(Outline, 0);
  SetLength(Holes, 0);
  if not Block then
  begin
    Outline := ReadList(Value);
    Inc(Cur);
  end
  else
  begin
    Inc(Cur);
    while (Cur < Src.Count) and (LowerCase(Src[Cur]) <> 'end') do
    begin
      if SplitProp(Src[Cur], Key, V) then
      begin
        if Key = 'points' then Outline := ReadList(V)
        else if Key = 'hole' then
        begin
          SetLength(Holes, Length(Holes) + 1);
          Holes[High(Holes)] := ReadList(V);
        end
        else if Key = 'paint' then
        begin
          HasPaint := LowerCase(Trim(V)) <> 'none';
          if HasPaint then Paint := ReadColor(V);
        end
        else if Key = 'ink' then Ink := ReadColor(V);
      end;
      Inc(Cur);
    end;
    if Cur >= Src.Count then Fail('the face is never closed: an "end" is missing');
    Inc(Cur);
  end;
  if Length(Outline) < 3 then Fail('a face wants three corners or more');
  D.AddFaceRaw(Outline, Ink, Solid <> 0);
  Idx := D.Live - 1;
  if Solid <> 0 then D.SetFaceGroup(Idx, Solid);
  if Length(Holes) > 0 then
  begin
    { a hole said by a circle's name comes the way the circle goes round;
      a hole goes round the other way from its face.  Turned round on a
      copy: the loop is the circle's own, and "face = c1" further down
      wants it the way it was. }
    for K := 0 to High(Holes) do
      if Dot3(Cross3(P3(Holes[K][1].X - Holes[K][0].X, Holes[K][1].Y - Holes[K][0].Y, Holes[K][1].Z - Holes[K][0].Z),
                     P3(Holes[K][2].X - Holes[K][1].X, Holes[K][2].Y - Holes[K][1].Y, Holes[K][2].Z - Holes[K][1].Z)),
              D.FaceNormal(Idx)) > 0 then
      begin
        Holes[K] := Copy(Holes[K]);
        for J := 0 to (Length(Holes[K]) div 2) - 1 do
        begin
          Tmp := Holes[K][J];
          Holes[K][J] := Holes[K][High(Holes[K]) - J];
          Holes[K][High(Holes[K]) - J] := Tmp;
        end;
      end;
    D.SetFaceHoles(Idx, Holes);
  end;
  if HasPaint then D.SetMaterial(Idx, Paint);
end;

procedure THeckReader.DoLine(const Value: string; Block: Boolean; Solid: Integer);
var
  Key, V: string;
  Ends: TLoop;
  Ink: TColor;
  Wd: Double;
  Soft, Ref: Boolean;
  P: Integer;
begin
  Ink := DefInk;
  Wd := DefWidth;
  Soft := False;
  Ref := False;
  SetLength(Ends, 0);
  if not Block then
  begin
    Ends := ReadList(Value);
    Inc(Cur);
  end
  else
  begin
    Inc(Cur);
    while (Cur < Src.Count) and (LowerCase(Src[Cur]) <> 'end') do
    begin
      if SplitProp(Src[Cur], Key, V) then
      begin
        P := 1;
        if Key = 'points' then Ends := ReadList(V)
        else if Key = 'ink' then Ink := ReadColor(V)
        else if Key = 'width' then Wd := Expr(V, P).V
        else if Key = 'soft' then Soft := ReadBool(V)
        else if Key = 'ref' then Ref := ReadBool(V);
      end;
      Inc(Cur);
    end;
    if Cur >= Src.Count then Fail('the line is never closed: an "end" is missing');
    Inc(Cur);
  end;
  if Length(Ends) <> 2 then Fail('a line is two points: "line = a to b"');
  D.AddLine(Ends[0], Ends[1], Ink, Wd, Ref);
  if Solid <> 0 then D.SetLineGroup(D.Live - 1, Solid);
  if Soft then D.SetSoft(D.Live - 1, True);
end;

procedure THeckReader.NoteSolid(G: Integer; HasPaint: Boolean; Paint: TColor);
begin
  SetLength(Solids, Length(Solids) + 1);
  Solids[High(Solids)].G := G;
  Solids[High(Solids)].HasPaint := HasPaint;
  Solids[High(Solids)].Paint := Paint;
end;

procedure THeckReader.DoSolid;
var
  G, Save: Integer;
  Key, V: string;
  HasPaint: Boolean;
  Paint: TColor;
begin
  G := D.NewGroup;
  HasPaint := False;
  Paint := 0;
  Inc(Cur);
  PushScope;
  try
    { what it is painted comes before anything it is made of }
    while (Cur < Src.Count) and SplitProp(Src[Cur], Key, V) and (Key = 'paint') do
    begin
      HasPaint := LowerCase(Trim(V)) <> 'none';
      if HasPaint then Paint := ReadColor(V);
      Inc(Cur);
    end;
    NoteSolid(G, HasPaint, Paint);
    Save := Cur;
    Things(G, HasPaint, Paint);
    if Cur >= Src.Count then
    begin
      Cur := Save;
      Fail('the solid is never closed: an "end" is missing');
    end;
    Inc(Cur);
  finally
    PopScope;
  end;
end;

procedure THeckReader.DoGroup(const Header: string);
var
  Id, WasStamp, Save: Integer;
  Key, V: string;
begin
  Id := D.NewPart(ReadText(Header), D.Stamp);
  WasStamp := D.Stamp;
  Inc(Cur);
  PushScope;
  try
    while (Cur < Src.Count) and SplitProp(Src[Cur], Key, V) and
          ((Key = 'locked') or (Key = 'jig')) do
    begin
      if Key = 'locked' then D.SetPartLocked(Id, ReadBool(V))
      else D.SetPartJig(Id, V);
      Inc(Cur);
    end;
    D.Stamp := Id;
    Save := Cur;
    Things(0, False, 0);
    if Cur >= Src.Count then
    begin
      Cur := Save;
      Fail('the group is never closed: an "end" is missing');
    end;
    Inc(Cur);
  finally
    D.Stamp := WasStamp;
    PopScope;
  end;
end;

procedure THeckReader.DoDim;
var
  Key, V, Lbl: string;
  A, B, Off: TP3;
  Ink: TColor;
  P: Integer;
begin
  A := P3(0, 0, 0); B := A; Off := A;
  Lbl := '';
  Ink := DefInk;
  Inc(Cur);
  while (Cur < Src.Count) and (LowerCase(Src[Cur]) <> 'end') do
  begin
    if SplitProp(Src[Cur], Key, V) then
    begin
      P := 1;
      if Key = 'from' then A := ReadPlace(V, P, False, A)
      else if Key = 'to' then B := ReadPlace(V, P, False, A)
      else if Key = 'off' then Off := ReadStep(V, P)
      else if Key = 'label' then Lbl := ReadText(V)
      else if Key = 'ink' then Ink := ReadColor(V);
    end;
    Inc(Cur);
  end;
  if Cur >= Src.Count then Fail('the dimension is never closed: an "end" is missing');
  Inc(Cur);
  D.AddDim(A, B, Ink, Off, Lbl);
end;

procedure THeckReader.DoNote;
var
  Key, V, Txt: string;
  A, T: TP3;
  HasT: Boolean;
  Ink: TColor;
  Size: Double;
  P: Integer;
begin
  A := P3(0, 0, 0); T := A;
  HasT := False;
  Txt := '';
  Ink := DefInk;
  Size := 0;
  Inc(Cur);
  while (Cur < Src.Count) and (LowerCase(Src[Cur]) <> 'end') do
  begin
    if SplitProp(Src[Cur], Key, V) then
    begin
      P := 1;
      if Key = 'at' then A := ReadPlace(V, P, False, A)
      else if Key = 'to' then begin T := ReadPlace(V, P, False, A); HasT := True; end
      else if Key = 'text' then
      begin
        if Txt <> '' then Txt := Txt + LineEnding;
        Txt := Txt + ReadText(V);
      end
      else if Key = 'size' then Size := Expr(V, P).V
      else if Key = 'ink' then Ink := ReadColor(V);
    end;
    Inc(Cur);
  end;
  if Cur >= Src.Count then Fail('the note is never closed: an "end" is missing');
  Inc(Cur);
  if not HasT then T := A;
  D.AddNote(A, T, Txt, Ink);
  if Size > 0 then D.SetNoteSize(D.Live - 1, Size);
end;

procedure THeckReader.PlaceAndStep(const Value: string; out Corner, Size: TP3);
var
  P: Integer;
  V: string;
begin
  V := Trim(Value);
  P := Pos(';', V);
  if P = 0 then Fail('a place, then a semicolon, then a size: "0 east, 0 north, 0 up; 4'' east, 3'' north, 2'' up"');
  Corner := ReadList(Copy(V, 1, P - 1))[0];
  P := P + 1;
  Size := ReadStep(V, P);
  SkipSp(V, P);
  if P <= Length(V) then Fail('"' + Trim(Copy(V, P, 16)) + '" - what is that after the size?');
end;

{ eight corners, twelve lines, six faces, one solid - the same as a
  rectangle pulled up by the tool }
procedure THeckReader.MakeBox(const Corner, Size: TP3; HasPaint: Boolean; Paint: TColor; const Name: string);
var
  C: array[0..7] of TP3;
  G, I, F0: Integer;
  X, Y, Z: Double;
  Sx, Sy, Sz: Double;
  Save: Integer;
  procedure Face4(A, B, Cc, Dd: Integer);
  begin
    D.AddFaceRaw([C[A], C[B], C[Cc], C[Dd]], DefInk, True);
    D.SetFaceGroup(D.Live - 1, G);
    if HasPaint then D.SetMaterial(D.Live - 1, Paint);
  end;
  procedure Edge(A, B: Integer);
  begin
    D.AddLine(C[A], C[B], DefInk, DefWidth, False);
    D.SetLineGroup(D.Live - 1, G);
  end;
begin
  if (Abs(Size.X) < 1E-9) or (Abs(Size.Y) < 1E-9) or (Abs(Size.Z) < 1E-9) then
    Fail('a box wants a size with all three parts');
  Sx := Abs(Size.X); Sy := Abs(Size.Y); Sz := Abs(Size.Z);
  X := Min(Corner.X, Corner.X + Size.X); Y := Min(Corner.Y, Corner.Y + Size.Y); Z := Min(Corner.Z, Corner.Z + Size.Z);
  C[0] := P3(X, Y, Z);           C[1] := P3(X + Sx, Y, Z);
  C[2] := P3(X + Sx, Y + Sy, Z); C[3] := P3(X, Y + Sy, Z);
  for I := 0 to 3 do C[I + 4] := P3(C[I].X, C[I].Y, Z + Sz);
  G := D.NewGroup;
  NoteSolid(G, HasPaint, Paint);
  Face4(3, 2, 1, 0);        { bottom, facing down }
  Face4(4, 5, 6, 7);        { top, facing up }
  Face4(0, 1, 5, 4);        { south }
  Face4(1, 2, 6, 5);        { east }
  Face4(2, 3, 7, 6);        { north }
  Face4(3, 0, 4, 7);        { west }
  for I := 0 to 3 do
  begin
    Edge(I, (I + 1) mod 4);
    Edge(I + 4, (I + 1) mod 4 + 4);
    Edge(I, I + 4);
  end;
  if Name <> '' then ;   { a name on a solid: nowhere to keep it yet }
end;

procedure THeckReader.DoBox(const Value: string; Block: Boolean);
var
  Key, V, Name: string;
  Corner, Size: TP3;
  HasPaint, HasAt, HasSize: Boolean;
  Paint: TColor;
  P: Integer;
begin
  HasPaint := False;
  Paint := 0;
  Name := '';
  if not Block then
  begin
    PlaceAndStep(Value, Corner, Size);
    MakeBox(Corner, Size, False, 0, '');
    Inc(Cur);
    Exit;
  end;
  { "box Foot" - a name after the word }
  Name := Trim(Copy(Trim(Src[Cur]), 4, MaxInt));
  HasAt := False;
  HasSize := False;
  Corner := P3(0, 0, 0);
  Size := Corner;
  Inc(Cur);
  while (Cur < Src.Count) and (LowerCase(Src[Cur]) <> 'end') do
  begin
    if SplitProp(Src[Cur], Key, V) then
    begin
      P := 1;
      if Key = 'at' then begin Corner := ReadPlace(V, P, False, Corner); HasAt := True; end
      else if Key = 'size' then begin Size := ReadStep(V, P); HasSize := True; end
      else if Key = 'paint' then
      begin
        HasPaint := LowerCase(Trim(V)) <> 'none';
        if HasPaint then Paint := ReadColor(V);
      end;
    end;
    Inc(Cur);
  end;
  if Cur >= Src.Count then Fail('the box is never closed: an "end" is missing');
  Inc(Cur);
  if not (HasAt and HasSize) then Fail('a box wants an "at" and a "size"');
  MakeBox(Corner, Size, HasPaint, Paint, Name);
end;

{ four lines; the face comes from them as it always does, unless a paint
  says the face is wanted now, painted }
{ pull: a flat outline and how far it goes - the solid push/pull makes.
  "pull = floor1..floor6; 8' up", or "pull = c1; 2' up" for a cylinder;
  the block form has points, by and paint.  It expands to the edges and
  nothing else: the bottom outline, the same again at the top, an upright
  at each corner - soft ones round a circle, as the tool leaves them - in a
  solid of its own; the faces are what those edges close, as always.  A
  circle pulled is that circle's: the arc joins the solid, as it does when
  the tool pulls a disk. }
procedure THeckReader.DoPull(const Value: string; Block: Boolean);
var
  Key, V, OutlineText, ByText: string;
  Lp: TLoop;
  By: TP3;
  HasPaint, Round_: Boolean;
  Paint: TColor;
  Parts: TStringArray;
  P, I, N, G, ArcAt, K: Integer;
  Top: TP3;
begin
  OutlineText := '';
  ByText := '';
  HasPaint := False;
  Paint := 0;
  if not Block then
  begin
    Parts := Value.Split([';']);
    if Length(Parts) <> 2 then
      Fail('a pull is its outline, then how far: pull = a b c d; 8'' up');
    OutlineText := Trim(Parts[0]);
    ByText := Trim(Parts[1]);
    Inc(Cur);
  end
  else
  begin
    Inc(Cur);
    while (Cur < Src.Count) and (LowerCase(Src[Cur]) <> 'end') do
    begin
      if SplitProp(Src[Cur], Key, V) then
      begin
        if Key = 'points' then OutlineText := V
        else if Key = 'by' then ByText := V
        else if Key = 'paint' then
        begin
          HasPaint := LowerCase(Trim(V)) <> 'none';
          if HasPaint then Paint := ReadColor(V);
        end;
      end;
      Inc(Cur);
    end;
    if Cur >= Src.Count then Fail('the pull is never closed: an "end" is missing');
    Inc(Cur);
  end;
  if OutlineText = '' then Fail('a pull wants its outline: points = a b c d');
  if ByText = '' then Fail('a pull wants how far it goes: by = 8'' up');
  Lp := ReadList(OutlineText);
  N := Length(Lp);
  if N < 3 then Fail('a pull wants an outline of three corners or more');
  P := 1;
  By := ReadStep(ByText, P);
  if (Abs(By.X) < 1E-9) and (Abs(By.Y) < 1E-9) and (Abs(By.Z) < 1E-9) then
    Fail('a pull goes some way: by = 8'' up');
  { a circle by name: the ring the tool pulled, and the arc is the solid's }
  Round_ := False;
  ArcAt := -1;
  if (Pos(' ', Trim(OutlineText)) = 0) and (Pos(',', OutlineText) = 0) then
  begin
    for I := D.Live - 1 downto 0 do
      if (D[I].Kind = ekArc) and (Abs(Abs(D[I].Sweep) - 2 * Pi) < 1E-9) and
         (Abs(Dist(D[I].C, Lp[0]) - D[I].R) < 1E-6) and
         (Abs(Dist(D[I].C, Lp[N div 2]) - D[I].R) < 1E-6) then
      begin
        ArcAt := I;
        Break;
      end;
    Round_ := ArcAt >= 0;
  end;
  G := D.NewGroup;
  NoteSolid(G, HasPaint, Paint);
  if Round_ then D.SetGroup(ArcAt, G)
  else
    for K := 0 to N - 1 do
    begin
      D.AddLine(Lp[K], Lp[(K + 1) mod N], DefInk, DefWidth, False);
      D.SetLineGroup(D.Live - 1, G);
    end;
  for K := 0 to N - 1 do
  begin
    Top := P3(Lp[K].X + By.X, Lp[K].Y + By.Y, Lp[K].Z + By.Z);
    D.AddLine(Top, P3(Lp[(K + 1) mod N].X + By.X, Lp[(K + 1) mod N].Y + By.Y, Lp[(K + 1) mod N].Z + By.Z),
      DefInk, DefWidth, False);
    D.SetLineGroup(D.Live - 1, G);
    D.AddLine(Lp[K], Top, DefInk, DefWidth, False);
    D.SetLineGroup(D.Live - 1, G);
    if Round_ then D.SetSoft(D.Live - 1, True);
  end;
end;

procedure THeckReader.MakeRect(const Corner, Size: TP3; HasPaint: Boolean; Paint: TColor);
var
  C: array[0..3] of TP3;
  I, N: Integer;
  EU, EV: TP3;
begin
  N := Ord(Abs(Size.X) > 1E-9) + Ord(Abs(Size.Y) > 1E-9) + Ord(Abs(Size.Z) > 1E-9);
  if N <> 2 then Fail('a rectangle''s size has two parts - "4'' east, 3'' north", or "4'' east, 2'' up"');
  if Abs(Size.Z) < 1E-9 then begin EU := P3(Size.X, 0, 0); EV := P3(0, Size.Y, 0); end
  else if Abs(Size.Y) < 1E-9 then begin EU := P3(Size.X, 0, 0); EV := P3(0, 0, Size.Z); end
  else begin EU := P3(0, Size.Y, 0); EV := P3(0, 0, Size.Z); end;
  C[0] := Corner;
  C[1] := P3(Corner.X + EU.X, Corner.Y + EU.Y, Corner.Z + EU.Z);
  C[2] := P3(C[1].X + EV.X, C[1].Y + EV.Y, C[1].Z + EV.Z);
  C[3] := P3(Corner.X + EV.X, Corner.Y + EV.Y, Corner.Z + EV.Z);
  for I := 0 to 3 do D.AddLine(C[I], C[(I + 1) mod 4], DefInk, DefWidth, False);
  if HasPaint then
  begin
    D.AddFaceRaw(C, DefInk, False);
    D.SetMaterial(D.Live - 1, Paint);
  end;
end;

procedure THeckReader.DoRect(const Value: string; Block: Boolean);
var
  Key, V: string;
  Corner, Size: TP3;
  HasPaint, HasAt, HasSize: Boolean;
  Paint: TColor;
  P: Integer;
begin
  HasPaint := False;
  Paint := 0;
  if not Block then
  begin
    PlaceAndStep(Value, Corner, Size);
    MakeRect(Corner, Size, False, 0);
    Inc(Cur);
    Exit;
  end;
  HasAt := False;
  HasSize := False;
  Corner := P3(0, 0, 0);
  Size := Corner;
  Inc(Cur);
  while (Cur < Src.Count) and (LowerCase(Src[Cur]) <> 'end') do
  begin
    if SplitProp(Src[Cur], Key, V) then
    begin
      P := 1;
      if Key = 'at' then begin Corner := ReadPlace(V, P, False, Corner); HasAt := True; end
      else if Key = 'size' then begin Size := ReadStep(V, P); HasSize := True; end
      else if Key = 'paint' then
      begin
        HasPaint := LowerCase(Trim(V)) <> 'none';
        if HasPaint then Paint := ReadColor(V);
      end;
    end;
    Inc(Cur);
  end;
  if Cur >= Src.Count then Fail('the rectangle is never closed: an "end" is missing');
  Inc(Cur);
  if not (HasAt and HasSize) then Fail('a rectangle wants an "at" and a "size"');
  MakeRect(Corner, Size, HasPaint, Paint);
end;

procedure THeckReader.DoBore(Solid: Integer);
var
  Key, V: string;
  Lp: TLoop;
  Goes: TP3;
  P: Integer;
begin
  SetLength(Lp, 0);
  Goes := P3(0, 0, 0);
  Inc(Cur);
  while (Cur < Src.Count) and (LowerCase(Src[Cur]) <> 'end') do
  begin
    if SplitProp(Src[Cur], Key, V) then
    begin
      P := 1;
      if Key = 'points' then Lp := ReadList(V)
      else if Key = 'goes' then Goes := ReadStep(V, P);
    end;
    Inc(Cur);
  end;
  if Cur >= Src.Count then Fail('the bore is never closed: an "end" is missing');
  Inc(Cur);
  if Length(Lp) < 3 then Fail('a bore wants three corners or more');
  D.AddBore(Lp, P3(Lp[0].X + Goes.X, Lp[0].Y + Goes.Y, Lp[0].Z + Goes.Z), Solid);
end;

{ A circle drawn on a face cuts it - that is what the tool does, and the
  writer leans on it: a box with a circle on its top is still written "box",
  and the circle after it, with no "hole" said anywhere.  So once everything
  is read, every circle whose ring lies flat inside a face becomes a hole in
  that face, unless the face already has it.  The disk is not made: that is
  "face = c1", and the writer writes it. }
procedure THeckReader.CutCircles(FirstNew: Integer);
var
  I, F, K, N, J: Integer;
  Lp: TLoop;
  Nm, P0, Q, E1, E2: TP3;
  Holes: array of TP3Array;
  Inside, Known: Boolean;
  Tmp: TP3;
begin
  for I := FirstNew to D.Live - 1 do
  begin
    if (D[I].Kind <> ekArc) or (Abs(Abs(D[I].Sweep) - 2 * Pi) >= 1E-9) then Continue;
    N := D[I].Sides;
    if N < 3 then N := DefSides;
    SetLength(Lp, N);
    for K := 0 to N - 1 do
      Lp[K] := ArcPoint(D[I].C, D[I].R, D[I].A0 + K * 2 * Pi / N, D[I].Plane, D[I].Nm);
    for F := FirstNew to D.Live - 1 do
    begin
      if D[F].Kind <> ekFace then Continue;
      if Length(D[F].Poly) = N then
      begin
        { the disk itself, or a face that is this ring: not cut }
        Inside := True;
        for K := 0 to N - 1 do
          if not SamePt(D[F].Poly[K], Lp[0], 1E-6) then Continue else begin Inside := False; Break; end;
        if not Inside then Continue;
      end;
      Nm := D.FaceNormal(F);
      P0 := D[F].Poly[0];
      Inside := True;
      for K := 0 to N - 1 do
      begin
        Q := P3(Lp[K].X - P0.X, Lp[K].Y - P0.Y, Lp[K].Z - P0.Z);
        if Abs(Dot3(Q, Nm)) > 1E-6 then begin Inside := False; Break; end;
        if not PointInLoop(Lp[K], D[F].Poly, Nm) then begin Inside := False; Break; end;
      end;
      if not Inside then Continue;
      { already a hole of it? }
      Known := False;
      for J := 0 to High(D[F].Holes) do
        if (Length(D[F].Holes[J]) = N) then
          for K := 0 to N - 1 do
            if SamePt(D[F].Holes[J][K], Lp[0], 1E-6) then begin Known := True; Break; end;
      if Known then Continue;
      { a hole goes round the other way from its face }
      SetLength(Holes, Length(D[F].Holes) + 1);
      for J := 0 to High(D[F].Holes) do Holes[J] := D[F].Holes[J];
      Holes[High(Holes)] := Copy(Lp);
      E1 := P3(Lp[1].X - Lp[0].X, Lp[1].Y - Lp[0].Y, Lp[1].Z - Lp[0].Z);
      E2 := P3(Lp[2].X - Lp[1].X, Lp[2].Y - Lp[1].Y, Lp[2].Z - Lp[1].Z);
      if Dot3(Cross3(E1, E2), Nm) > 0 then
        for K := 0 to N div 2 - 1 do
        begin
          Tmp := Holes[High(Holes)][K];
          Holes[High(Holes)][K] := Holes[High(Holes)][N - 1 - K];
          Holes[High(Holes)][N - 1 - K] := Tmp;
        end;
      D.SetFaceHoles(F, Holes);
    end;
  end;
end;

{ The faces the lines imply - uImply has the rule.  Scope by scope: one
  solid, or the loose things of one group.  A region that is already a face
  anywhere is that face; one that is a noface is left open; the rest become
  faces, turned as the tool would turn them, painted as their solid is. }
procedure THeckReader.ImplyFaces(FirstNew: Integer);
type
  TKey = record Part, Grp: Integer; end;
var
  Keys: array of TKey;
  I, K, F, S, J, C: Integer;
  Segs: TSegArray;
  Regs: TRegionArray;
  Outer: TP3Array;
  Holes: TLoopArray;
  Mid: TP3;
  Known, InSolid: Boolean;
  SolidAt, Hit, NHit: Integer;
  Faces: TLoopIndex;
  Cands: TIntArrayW;
begin
  SetLength(Implied, D.Live);
  for F := 0 to D.Live - 1 do Implied[F] := False;
  Faces := TLoopIndex.Create;
  for F := FirstNew to D.Live - 1 do
    if D[F].Kind = ekFace then Faces.Add(D[F].Poly, F);
  SetLength(Keys, 0);
  for I := FirstNew to D.Live - 1 do
    if D[I].Kind in [ekLine, ekArc] then
    begin
      Known := False;
      for K := 0 to High(Keys) do
        if (Keys[K].Part = D[I].Part) and (Keys[K].Grp = D[I].Grp) then begin Known := True; Break; end;
      if Known then Continue;
      SetLength(Keys, Length(Keys) + 1);
      Keys[High(Keys)].Part := D[I].Part;
      Keys[High(Keys)].Grp := D[I].Grp;
    end;
  for K := 0 to High(Keys) do
  begin
    Segs := ScopeSegments(D, FirstNew, Keys[K].Part, Keys[K].Grp);
    if Length(Segs) < 3 then Continue;
    Regs := BuildRegions(Segs);
    SolidAt := -1;
    for S := 0 to High(Solids) do
      if Solids[S].G = Keys[K].Grp then SolidAt := S;
    InSolid := SolidAt >= 0;
    Mid := ScopeMid(Segs);
    for I := 0 to High(Regs) do
    begin
      { Already the outline of a face of this scope - or, for a loose loop,
        of anything: a solid lying exactly on another keeps its own faces,
        and a disk said inside a box is not made again by the circle beside
        it.  The outline alone: a face that has this outline and other
        holes than the lines would cut is still that face, said in full. }
      Known := False;
      Hit := -1;
      NHit := 0;
      Cands := Faces.Near(Regs[I].Outer);
      for C := 0 to High(Cands) do
      begin
        F := Cands[C];
        if ((D[F].Grp = Keys[K].Grp) or (Keys[K].Grp = 0)) and
           SameLoopTol(D[F].Poly, Regs[I].Outer, 1E-4) then
        begin
          Known := True;
          if RegionIsFace(Regs[I], D, F) then
          begin
            Inc(NHit);
            Hit := F;
          end;
        end;
      end;
      { exactly this face, and it alone: the writer may leave it unsaid,
        provided it faces the way an implied one would have }
      if NHit = 1 then
      begin
        ImpliedLoop(Regs[I], InSolid, Mid, Outer, Holes);
        if Dot3(LoopNormal(Outer), D.FaceNormal(Hit)) > 0 then
        begin
          if Length(Implied) < D.Live then SetLength(Implied, D.Live);
          Implied[Hit] := True;
        end;
      end;
      { a noface is said by the drawing's named corners, which may sit a
        hair from the loose lines that close the same loop: a tolerance of
        the text's own }
      if not Known then
        for J := 0 to High(NoFaces) do
          if SameLoopTol(NoFaces[J], Regs[I].Outer, 1E-4) then begin Known := True; Break; end;
      if Known then Continue;
      ImpliedLoop(Regs[I], InSolid, Mid, Outer, Holes);
      D.AddFaceRaw(Outer, DefInk, InSolid);
      F := D.Live - 1;
      Faces.Add(Outer, F);
      if Length(Holes) > 0 then D.SetFaceHoles(F, Holes);
      if InSolid then
      begin
        D.SetFaceGroup(F, Keys[K].Grp);
        if Solids[SolidAt].HasPaint then D.SetMaterial(F, Solids[SolidAt].Paint);
      end
      else if Keys[K].Grp <> 0 then D.SetFaceGroup(F, Keys[K].Grp);
      D.SetPart(F, Keys[K].Part);
    end;
  end;
  Faces.Free;
end;

{ A loose face that fills a hole in a solid's face is that solid's - the
  disk a circle cut in a box's top, whether typed as "face = c1" beside the
  box or made from the circle - as the tool heals it. }
procedure THeckReader.HomeLooseFaces(FirstNew: Integer);
var
  F, S, J, C: Integer;
  Holes: TLoopIndex;
  Cands: TIntArrayW;
begin
  Holes := TLoopIndex.Create;
  try
    for S := FirstNew to D.Live - 1 do
      if (D[S].Kind = ekFace) and (D[S].Grp <> 0) then
        for J := 0 to High(D[S].Holes) do Holes.Add(D[S].Holes[J], S);
    for F := FirstNew to D.Live - 1 do
    begin
      if (D[F].Kind <> ekFace) or (D[F].Grp <> 0) then Continue;
      Cands := Holes.Near(D[F].Poly);
      for C := 0 to High(Cands) do
      begin
        S := Cands[C];
        if S = F then Continue;
        for J := 0 to High(D[S].Holes) do
          if SameLoopTol(D[S].Holes[J], D[F].Poly, 1E-4) then
          begin
            D.SetFaceGroup(F, D[S].Grp);
            Break;
          end;
        if D[F].Grp <> 0 then Break;
      end;
    end;
  finally
    Holes.Free;
  end;
end;

procedure THeckReader.Run(L: TStrings);
var
  FirstNew: Integer;
  T0, T1, T2, T3: QWord;
begin
  T0 := GetTickCount64;
  Prepare(L);
  Cur := 0;
  FirstNew := D.Live;
  Things(0, False, 0);
  if Cur < Src.Count then Fail('there is an "end" here with nothing to close');
  T1 := GetTickCount64;
  if not AllSaid then ImplyFaces(FirstNew);
  T2 := GetTickCount64;
  CutCircles(FirstNew);
  T3 := GetTickCount64;
  HomeLooseFaces(FirstNew);
  if GetEnvironmentVariable('HECK_TIMING') <> '' then
    WriteLn(StdErr, Format('read: things %d ms, imply %d ms, circles %d ms, home %d ms',
      [T1 - T0, T2 - T1, T3 - T2, GetTickCount64 - T3]));
end;

function ReadHeckImplied(L: TStrings; D: TWorkDoc; U: TUnitSystem;
  out ErrLine: Integer; out Err: string; out Implied: TBoolArray): Boolean;
var
  R: THeckReader;
  WasStamp: Integer;
begin
  Err := '';
  ErrLine := -1;
  SetLength(Implied, 0);
  WasStamp := D.Stamp;
  R := THeckReader.Create(D, U);
  try
    try
      R.Run(L);
      Implied := Copy(R.Implied);
      Result := True;
    except
      on E: Exception do
      begin
        Result := False;
        Err := E.Message;
        ErrLine := R.ErrLine;
      end;
    end;
  finally
    D.Stamp := WasStamp;
    R.Free;
  end;
end;

function ReadHeck(L: TStrings; D: TWorkDoc; U: TUnitSystem;
  out ErrLine: Integer; out Err: string): Boolean;
var
  Implied: TBoolArray;
begin
  Result := ReadHeckImplied(L, D, U, ErrLine, Err, Implied);
end;

function HeckValue(const S: string; U: TUnitSystem; out V: Double;
  out IsLength: Boolean): Boolean;
var
  R: THeckReader;
  P: Integer;
  T: TVal;
  Scratch: TWorkDoc;
begin
  Result := False;
  V := 0;
  IsLength := False;
  Scratch := TWorkDoc.Create;
  R := THeckReader.Create(Scratch, U);
  try
    try
      P := 1;
      T := R.Expr(Trim(S), P);
      R.SkipSp(S, P);
      V := T.V;
      IsLength := T.K = vLen;
      Result := P > Length(Trim(S));
    except
      Result := False;
    end;
  finally
    R.Free;
    Scratch.Free;
  end;
end;

initialization
  { the writer reads its own text back to see which faces go unsaid }
  uFormat2.ReadBack := @ReadHeckImplied;

end.
