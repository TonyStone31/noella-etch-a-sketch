unit uFormat2;

{ A sheet written out in the proposed version 2 of the drawing file -
  docs/format2.md - FOR LOOKING AT ONLY.

  Nothing reads this back and nothing saves it.  It exists so that the
  grammar can be seen on real drawings, in the source window, before a
  reader is written and the format is something files depend on.  When the
  page and this unit disagree, one of them is wrong and it should be found
  out which before going any further.

  What it takes care over, because the format does:
    - a length is written the friendly way only when that is exact
      (FRIENDLY_TOL), and as a decimal in full otherwise;
    - a solid's corners are named once and everything refers to them;
    - a point is written from an earlier one when it lies along an axis
      from it, which is what makes "3 inches east of a" readable;
    - only what differs from the sheet's defaults is said. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Graphics, uWork;

const
  { a million-millionth of a foot: see "Lengths" in docs/format2.md }
  FRIENDLY_TOL = 1E-12;
  { Version 1 writes a length as feet to six places, so every drawing that
    has been through a file - which is every drawing there is - holds 1.4
    inches as 1.400004.  That is version 1's rounding and not the person's
    number.  For looking at, a value within version 1's own half-millionth
    of a foot of a friendly one is shown as the friendly one; whether
    READING a version 1 file should put the friendly value back for good is
    one of the things docs/format2.md leaves to be settled. }
  V1_NOISE = 1.2E-6;    { a difference of two such numbers has twice the error }

{ L gets the text.  LineThing says, for each line of it, which entity that
  line is about, or -1; First and Last give an entity's lines, First > Last
  for one that has none of its own (an edge a solid's faces imply). }
{ Hints, when given, gets a line for each line of L: where a point written
  as a step from another actually is, for the source window to say when
  the pointer rests on its name; empty for every other line. }
{ Names, when given, gets one entry for every named point, ring corners
  included: "line|name=place", where line is the "points" line of the block
  that names it - so a name can be looked up from wherever it is used, by
  taking the nearest block above. }
procedure WriteFormat2(D: TWorkDoc; const SheetName: string; U: TUnitSystem;
  L: TStrings; out First, Last, LineThing: TIntArrayW; Hints: TStrings = nil;
  Names: TStrings = nil);

{ the two directions a flat thing's angles are measured in: from east for a
  thing facing up or down, from its level line (up x facing) for any other }
procedure SpecAxes(const F: TP3; out AU, AV: TP3);

{ one length, the way the file writes it; always positive - the direction
  word carries the sign }
function Len2(V: Double; U: TUnitSystem): string;

implementation

type
  TPt = record
    P: TP3;
    Name: string;
    Ring: Integer;       { which ring it is a corner of, or -1 }
    InHole: Boolean;     { a corner of a hole, and of no outline }
  end;
  TPts = array of TPt;

  { corners spaced evenly round a circle, said once: where, how big, how
    many, which way it faces and where the first one is }
  TRing = record
    Name: string;
    C, Facing: TP3;
    R, Starts: Double;
    N: Integer;
  end;
  TRings = array of TRing;

function Len2(V: Double; U: TUnitSystem): string;
var
  Inches, R, Frac: Double;
  Feet, Whole, Num, Den: Integer;
  S: string;
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  V := Abs(V);
  if V < FRIENDLY_TOL then Exit('0');
  if U = usMetric then
  begin
    { held in feet whatever the sheet shows; millimeters to a thousandth
      when that is exact, in full when it is not }
    R := V * 304.8;
    if Abs(Round(R * 1000) / 1000 / 304.8 - V) <= FRIENDLY_TOL then
      S := FloatToStrF(Round(R * 1000) / 1000, ffGeneral, 12, 0, FS)
    else
      S := FloatToStrF(R, ffGeneral, 15, 0, FS);
    Exit(S);
  end;
  Inches := V * 12;
  R := Round(Inches * 64) / 64;
  if Abs(R / 12 - V) > V1_NOISE then
  begin
    { not a sixty-fourth: a decimal - a short one if it is one, give or
      take what version 1 did to it, and in full if not }
    R := Round(Inches * 1000) / 1000;
    if Abs(R / 12 - V) <= V1_NOISE then
      Exit(FloatToStrF(R, ffGeneral, 12, 0, FS) + '"');
    Exit(FloatToStrF(Inches, ffGeneral, 12, 0, FS) + '"');
  end;
  Feet := Trunc(R / 12 + 1E-9);
  R := R - Feet * 12;
  Whole := Trunc(R + 1E-9);
  Frac := R - Whole;
  Num := Round(Frac * 64);
  Den := 64;
  while (Num > 0) and (Num mod 2 = 0) do begin Num := Num div 2; Den := Den div 2; end;
  S := '';
  if Feet > 0 then S := IntToStr(Feet) + '''';
  if (Whole > 0) or (Num > 0) then
  begin
    if S <> '' then S := S + ' ';
    if Whole > 0 then S := S + IntToStr(Whole);
    if Num > 0 then
    begin
      if Whole > 0 then S := S + ' ';
      S := S + IntToStr(Num) + '/' + IntToStr(Den);
    end;
    S := S + '"';
  end;
  Result := S;
end;

{ A place is "1" east, 1" north, 0 up" - all three, always, so that the
  height is there to be seen: "0 up" is on the floor.  West, south and down
  are the other way, so no number in a place is ever negative.  A step
  says only the parts that change: "4' east", or "3" east, 2" up". }
function Place2(const P: TP3; U: TUnitSystem; Offset: Boolean): string;

  procedure Part(V: Double; const Plus, Minus: string);
  begin
    if Offset and (Abs(V) < FRIENDLY_TOL) then Exit;
    if Result <> '' then Result := Result + ', ';
    if V >= -FRIENDLY_TOL then Result := Result + Len2(V, U) + ' ' + Plus
    else Result := Result + Len2(V, U) + ' ' + Minus;
  end;

begin
  Result := '';
  Part(P.X, 'east', 'west');
  Part(P.Y, 'north', 'south');
  Part(P.Z, 'up', 'down');
  if Result = '' then Result := '0 east';
end;

function Sub3(const A, B: TP3): TP3;
begin
  Result := P3(A.X - B.X, A.Y - B.Y, A.Z - B.Z);
end;

function SameP(const A, B: TP3): Boolean;
begin
  Result := (Abs(A.X - B.X) < 1E-9) and (Abs(A.Y - B.Y) < 1E-9) and
            (Abs(A.Z - B.Z) < 1E-9);
end;

{ how many of the three parts of a difference are not nought }
function AxesUsed(const V: TP3): Integer;
begin
  Result := Ord(Abs(V.X) > 1E-9) + Ord(Abs(V.Y) > 1E-9) + Ord(Abs(V.Z) > 1E-9);
end;

function FacingWord(const N: TP3): string;
begin
  Result := '';
  if AxesUsed(N) <> 1 then Exit;
  if N.X > 0.5 then Result := 'east' else if N.X < -0.5 then Result := 'west'
  else if N.Y > 0.5 then Result := 'north' else if N.Y < -0.5 then Result := 'south'
  else if N.Z > 0.5 then Result := 'up' else Result := 'down';
end;

{ The two directions a flat thing's angles are measured in - docs/format2.md,
  "facing".  For a thing facing up or down: from east.  For anything else:
  from its level line, up x facing.  V is facing x U, so that turning is
  anticlockwise seen from the side it faces. }
procedure SpecAxes(const F: TP3; out AU, AV: TP3);
var
  L: Double;
begin
  if (Abs(F.X) < 1E-9) and (Abs(F.Y) < 1E-9) then
    AU := P3(1, 0, 0)
  else
  begin
    AU := P3(-F.Y, F.X, 0);                       { up x facing }
    L := Sqrt(AU.X * AU.X + AU.Y * AU.Y);
    AU := P3(AU.X / L, AU.Y / L, 0);
  end;
  AV := P3(F.Y * AU.Z - F.Z * AU.Y, F.Z * AU.X - F.X * AU.Z, F.X * AU.Y - F.Y * AU.X);
end;

function Deg2(A: Double): string;
var
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  A := RadToDeg(A);
  if Abs(A - Round(A * 1000) / 1000) < 1E-7 then A := Round(A * 1000) / 1000;
  if Abs(A) < 1E-9 then A := 0;
  Result := FloatToStrF(A, ffGeneral, 10, 0, FS) + '°';
end;

{ "up", "east" ... or, for a thing that is tilted, how far it leans from
  facing up and which way: "up, leaning 30° toward east".  When the angles
  are not clean ones, the three numbers, which are always right. }
function Facing2(const N: TP3): string;
var
  Tilt, Head, T2, H2: Double;
  W: string;
  FS: TFormatSettings;
  Back: TP3;
begin
  Result := FacingWord(N);
  if Result <> '' then Exit;
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Tilt := ArcCos(EnsureRange(N.Z, -1, 1));
  Head := ArcTan2(N.Y, N.X);
  T2 := DegToRad(Round(RadToDeg(Tilt) * 1000) / 1000);
  H2 := DegToRad(Round(RadToDeg(Head) * 1000) / 1000);
  Back := P3(Sin(T2) * Cos(H2), Sin(T2) * Sin(H2), Cos(T2));
  if SameP(Back, N) then
  begin
    if Abs(H2) < 1E-9 then W := 'east'
    else if Abs(H2 - Pi / 2) < 1E-9 then W := 'north'
    else if Abs(Abs(H2) - Pi) < 1E-9 then W := 'west'
    else if Abs(H2 + Pi / 2) < 1E-9 then W := 'south'
    else W := Deg2(H2) + ' round from east';
    Exit('up, leaning ' + Deg2(T2) + ' toward ' + W);
  end;
  Result := Format('%.9g east, %.9g north, %.9g up', [N.X, N.Y, N.Z], FS);
end;

function Color2(C: TColor): string;
const
  NAMES: array[0..9] of string = ('black', 'white', 'gray', 'red', 'orange',
    'yellow', 'green', 'blue', 'purple', 'brown');
  VALUES: array[0..9] of Integer = ($000000, $FFFFFF, $808080, $0000FF, $3CB0FF,
    $00FFFF, $008000, $FF0000, $800080, $2A2AA5);
var
  I: Integer;
begin
  C := C and $FFFFFF;
  for I := 0 to High(NAMES) do
    if C = VALUES[I] then Exit(NAMES[I]);
  Result := Format('#%.2x%.2x%.2x', [C and $FF, (C shr 8) and $FF, (C shr 16) and $FF]);
end;

function Quoted(const S: string): string;
begin
  Result := '''' + StringReplace(S, '''', '''''', [rfReplaceAll]) + '''';
end;

procedure WriteFormat2(D: TWorkDoc; const SheetName: string; U: TUnitSystem;
  L: TStrings; out First, Last, LineThing: TIntArrayW; Hints: TStrings = nil;
  Names: TStrings = nil);
var
  NextHint: string;
  DefInk: TColor;
  DefWidth: Single;
  NLine: Integer;
  FS: TFormatSettings;
  Circles: TIntArrayW;        { the whole circles on the sheet: c1, c2... }

  function CircleName(I: Integer): string;
  var
    K: Integer;
  begin
    Result := '';
    for K := 0 to High(Circles) do
      if Circles[K] = I then Exit('c' + IntToStr(K + 1));
  end;

  procedure Put(Depth: Integer; const S: string; Thing: Integer);
  begin
    L.Add(StringOfChar(' ', Depth * 2) + S);
    if Hints <> nil then Hints.Add(NextHint);
    NextHint := '';
    if NLine >= Length(LineThing) then SetLength(LineThing, NLine * 2 + 64);
    LineThing[NLine] := Thing;
    if Thing >= 0 then
    begin
      if First[Thing] > Last[Thing] then First[Thing] := NLine;
      Last[Thing] := NLine;
    end;
    Inc(NLine);
  end;

  { the commonest ink and width are the sheet's, and are then never said }
  procedure FindDefaults;
  var
    I, J, Best, N: Integer;
  begin
    DefInk := $201C1A;
    DefWidth := 1;
    Best := 0;
    for I := 0 to Min(D.Live - 1, 400) do
      if D[I].Kind in [ekLine, ekArc] then
      begin
        N := 0;
        for J := 0 to Min(D.Live - 1, 400) do
          if (D[J].Kind in [ekLine, ekArc]) and (D[J].Ink = D[I].Ink) then Inc(N);
        if N > Best then
        begin
          Best := N;
          DefInk := D[I].Ink;
          DefWidth := D[I].Weight;
        end;
      end;
  end;

  function PointName(Index, Count: Integer): string;
  begin
    if Count <= 23 then Result := Chr(Ord('a') + Index)
    else Result := 'p' + IntToStr(Index + 1);
  end;

  function FindPt(const Pts: TPts; const P: TP3): Integer;
  var
    I: Integer;
  begin
    for I := 0 to High(Pts) do
      if SameP(Pts[I].P, P) then Exit(I);
    Result := -1;
  end;

  procedure AddPt(var Pts: TPts; const P: TP3);
  begin
    if FindPt(Pts, P) >= 0 then Exit;
    SetLength(Pts, Length(Pts) + 1);
    Pts[High(Pts)].P := P;
    Pts[High(Pts)].Ring := -1;
    Pts[High(Pts)].Name := '';
    Pts[High(Pts)].InHole := True;
  end;

  function Ref(const Pts: TPts; const P: TP3): string;
  var
    K: Integer;
  begin
    K := FindPt(Pts, P);
    if K >= 0 then Result := Pts[K].Name
    else Result := Place2(P, U, False);
  end;

  { A list of places.  Named corners are just their names.  Places written
    out are a walk: the first where it is, each one after it as the step
    from the one before - "0; + 4' east; + 4' north; + 4' west" is a
    square, and reads as one. }
  function Items(const Pts: TPts; const Poly: array of TP3): TStringArray;
  var
    K: Integer;
  begin
    SetLength(Result, Length(Poly));
    for K := 0 to High(Poly) do
      if FindPt(Pts, Poly[K]) >= 0 then Result[K] := Ref(Pts, Poly[K])
      else if K = 0 then Result[K] := Place2(Poly[K], U, False)
      else Result[K] := '+ ' + Place2(Sub3(Poly[K], Poly[K - 1]), U, True);
  end;

  function Named(const It: TStringArray): Boolean;
  var
    K: Integer;
  begin
    Result := Length(It) > 0;
    for K := 0 to High(It) do
      if Pos(' ', It[K]) > 0 then Exit(False);
  end;

  { a run of three or more names that count up or down by one is said as
    its ends: ra1..ra24 }
  function Runs(const It: TStringArray): TStringArray;
  var
    K, J, N, Step, A, B, Q: Integer;
    Stem: string;

    function Split(const S: string; out St: string; out Num: Integer): Boolean;
    var
      P: Integer;
    begin
      P := Length(S);
      while (P > 0) and (S[P] in ['0'..'9']) do Dec(P);
      St := Copy(S, 1, P);
      Result := (P < Length(S)) and (P > 0) and TryStrToInt(Copy(S, P + 1, 9), Num);
    end;

  begin
    SetLength(Result, Length(It));
    N := 0;
    K := 0;
    while K <= High(It) do
    begin
      J := K;
      if Split(It[K], Stem, A) and (K < High(It)) and Split(It[K + 1], Result[N], B) and
         (Result[N] = Stem) and (Abs(B - A) = 1) then
      begin
        Step := B - A;
        J := K + 1;
        while (J < High(It)) and Split(It[J + 1], Result[N], Q) and (Result[N] = Stem) and
              (Q - B = Step) do
        begin
          B := Q;
          Inc(J);
        end;
      end;
      if J - K >= 2 then
      begin
        Result[N] := It[K] + '..' + It[J];
        K := J + 1;
      end
      else
      begin
        Result[N] := It[K];
        Inc(K);
      end;
      Inc(N);
    end;
    SetLength(Result, N);
  end;

  function Joined(const It: TStringArray): string;
  var
    K: Integer;
  begin
    Result := '';
    for K := 0 to High(It) do
    begin
      if K > 0 then
        if Named(It) then Result := Result + ' ' else Result := Result + ' to ';
      Result := Result + It[K];
    end;
  end;

  { "key = list" on one line when it fits, and LFM's way when it does not:
    "key = (", the list over as many lines as it takes, ")" }
  procedure PutList(Depth: Integer; const Key: string; const It: TStringArray;
    Thing: Integer; const Note: string = '');
  const
    WIDE = 78;
  var
    K: Integer;
    Row, Sep: string;
  begin
    if Depth * 2 + Length(Key) + 3 + Length(Joined(It)) <= WIDE then
    begin
      Put(Depth, Key + ' = ' + Joined(It) + Note, Thing);
      Exit;
    end;
    if Named(It) then Sep := ' ' else Sep := ' to ';
    Put(Depth, Key + ' = (' + Note, Thing);
    Row := '';
    for K := 0 to High(It) do
    begin
      if (Row <> '') and ((Depth + 1) * 2 + Length(Row) + Length(Sep) + Length(It[K]) > WIDE) then
      begin
        { a row of places ends in its "to", so the rows read on as one list }
        if Sep <> ' ' then Row := Row + ' to';
        Put(Depth + 1, Row, Thing);
        Row := '';
      end;
      if Row <> '' then Row := Row + Sep;
      Row := Row + It[K];
    end;
    if Row <> '' then Put(Depth + 1, Row, Thing);
    Put(Depth, ')', Thing);
  end;

  { Is this loop one of the circles drawn on the sheet, corner for corner?
    Then it is that circle, by name - "face = c1" - and not thirty-two
    places. }
  function CircleNamed(const Poly: array of TP3; Part_: Integer): string;
  var
    C, K, Q, N, Hit: Integer;
    P: TP3;
    Ok_: Boolean;
  begin
    Result := '';
    N := Length(Poly);
    if N < 8 then Exit;
    for C := 0 to High(Circles) do
    begin
      if D[Circles[C]].Part <> Part_ then Continue;
      Ok_ := True;
      for K := 0 to N - 1 do
      begin
        P := ArcPoint(D[Circles[C]].C, D[Circles[C]].R,
          D[Circles[C]].A0 + K * 2 * Pi / N, D[Circles[C]].Plane, D[Circles[C]].Nm);
        Hit := -1;
        for Q := 0 to N - 1 do
          if SameP(Poly[Q], P) then begin Hit := Q; Break; end;
        if Hit < 0 then begin Ok_ := False; Break; end;
      end;
      if Ok_ then Exit('c' + IntToStr(C + 1));
    end;
  end;

  function Outline(const Pts: TPts; const Poly: array of TP3; Part_: Integer): TStringArray;
  var
    Nm: string;
  begin
    Nm := CircleNamed(Poly, Part_);
    if Nm <> '' then
    begin
      SetLength(Result, 1);
      Result[0] := Nm;
    end
    else
    begin
      Result := Items(Pts, Poly);
      if Named(Result) then Result := Runs(Result);
    end;
  end;

  function NameKey(const Nm: string): string;
  var
    P: Integer;
    Stem: string;
  begin
    P := Length(Nm);
    while (P > 0) and (Nm[P] in ['0'..'9']) do Dec(P);
    Stem := Copy(Nm, 1, P);
    { floor before mid before top before anything else, then the number }
    if Stem = 'floor' then Result := '1'
    else if Stem = 'floorin' then Result := '2'
    else if Stem = 'mid' then Result := '3'
    else if Stem = 'midin' then Result := '4'
    else if Stem = 'top' then Result := '5'
    else if Stem = 'topin' then Result := '6'
    else Result := '7' + Stem;
    Result := Result + Format('%.4d', [StrToIntDef(Copy(Nm, P + 1, 9), 0)]);
  end;

  procedure SortByName(var Pts: TPts);
  var
    I, J: Integer;
    T: TPt;
  begin
    for I := 1 to High(Pts) do
    begin
      T := Pts[I];
      J := I - 1;
      while (J >= 0) and (NameKey(Pts[J].Name) > NameKey(T.Name)) do
      begin
        Pts[J + 1] := Pts[J];
        Dec(J);
      end;
      Pts[J + 1] := T;
    end;
  end;

  { floor1..N, top1..N, mid1..N - or nothing, when the corners do not fall
    into a few levels }
  procedure NameByPlace(var Pts: TPts);
  var
    I, J, N, NLevels, Best, Pass: Integer;
    Z: array of Double;
    Level: array of Integer;
    Count: array of Integer;
    Order: array of Integer;
    Ang, BestAng, BestAng2, CX, CY: Double;
    W: string;

  begin
    N := 0;
    for I := 0 to High(Pts) do
      if Pts[I].Ring < 0 then Inc(N);
    if (N < 4) or (N > 24) then Exit;
    { the distinct heights }
    SetLength(Z, 0);
    SetLength(Level, Length(Pts));
    for I := 0 to High(Pts) do
    begin
      Level[I] := -1;
      if Pts[I].Ring >= 0 then Continue;
      for J := 0 to High(Z) do
        if Abs(Z[J] - Pts[I].P.Z) < 1E-6 then begin Level[I] := J; Break; end;
      if Level[I] < 0 then
      begin
        SetLength(Z, Length(Z) + 1);
        Z[High(Z)] := Pts[I].P.Z;
        Level[I] := High(Z);
      end;
    end;
    NLevels := Length(Z);
    if (NLevels < 1) or (NLevels > 3) then Exit;
    { one level only is a flat thing: its corners go round from the one
      nearest the origin, as floor1, floor2... }
    { the levels sorted low to high: which is floor, mid, top }
    SetLength(Order, NLevels);
    for I := 0 to NLevels - 1 do
    begin
      Order[I] := 0;
      for J := 0 to NLevels - 1 do
        if Z[J] < Z[I] - 1E-6 then Inc(Order[I]);
    end;
    { round each level: by angle about the level's middle, starting from
      the corner nearest the origin }
    SetLength(Count, NLevels);
    for I := 0 to NLevels - 1 do Count[I] := 0;
    for J := 0 to NLevels - 1 do
    begin
      CX := 0; CY := 0; N := 0;
      for I := 0 to High(Pts) do
        if Level[I] = J then begin CX := CX + Pts[I].P.X; CY := CY + Pts[I].P.Y; Inc(N); end;
      if N = 0 then Continue;
      CX := CX / N; CY := CY / N;
      Best := -1;
      for I := 0 to High(Pts) do
        if (Level[I] = J) and ((Best < 0) or
           (Sqr(Pts[I].P.X) + Sqr(Pts[I].P.Y) < Sqr(Pts[Best].P.X) + Sqr(Pts[Best].P.Y) - 1E-9)) then
          Best := I;
      BestAng := ArcTan2(Pts[Best].P.Y - CY, Pts[Best].P.X - CX);
      { number them anticlockwise from that one }
      for I := 0 to High(Pts) do
        if Level[I] = J then
        begin
          Ang := ArcTan2(Pts[I].P.Y - CY, Pts[I].P.X - CX) - BestAng;
          while Ang < -1E-9 do Ang := Ang + 2 * Pi;
          Count[J] := Count[J] + 1;
        end;
      { the names, in that order - the outline's corners first, then any
        that belong to a hole cut in that level, as "in" corners }
      for Pass := 0 to 1 do
      begin
      N := 0;
      while N < Count[J] do
      begin
        Best := -1;
        for I := 0 to High(Pts) do
          if (Level[I] = J) and (Pts[I].Name = '') and (Ord(Pts[I].InHole) = Pass) then
          begin
            Ang := ArcTan2(Pts[I].P.Y - CY, Pts[I].P.X - CX) - BestAng;
            while Ang < -1E-9 do Ang := Ang + 2 * Pi;
            if (Best < 0) or (Ang < BestAng2) then begin Best := I; BestAng2 := Ang; end;
          end;
        if Best < 0 then Break;
        case NLevels of
          1: W := 'p';
          2: if Order[J] = 0 then W := 'floor' else W := 'top';
        else
          case Order[J] of
            0: W := 'floor';
            1: W := 'mid';
          else
            W := 'top';
          end;
        end;
        if Pass = 1 then W := W + 'in';
        Pts[Best].Name := W + IntToStr(N + 1);
        Inc(N);
      end;
      end;
    end;
  end;

  procedure PutPoints(Depth: Integer; var Pts: TPts; const Rings: TRings);
  var
    I, J, From, Loose, K: Integer;
    V: TP3;
  begin
    if Length(Pts) = 0 then Exit;
    Loose := 0;
    for I := 0 to High(Pts) do
      if Pts[I].Ring < 0 then Inc(Loose);
    { Corners are named by where they stand, so that a line between two of
      them reads as what it is.  A corner is "floor" or "top" by its
      height - the lowest corners are the floor, the highest the top,
      anything between is "mid" - and then numbered round: floor1, floor2,
      floor3, floor4, top1... so "line = floor1 to top1" is an upright and
      "line = top1 to top2" runs along the top.  Which corner is 1 is
      whichever is nearest the origin, and the rest follow the way the
      lowest face goes round.  A solid whose corners all stand at different
      heights - something turned over - falls back on a, b, c. }
    NameByPlace(Pts);
    K := 0;
    for I := 0 to High(Pts) do
      if (Pts[I].Ring < 0) and (Pts[I].Name = '') then
      begin
        if Length(Rings) > 0 then Pts[I].Name := 'p' + IntToStr(K + 1)
        else Pts[I].Name := PointName(K, Loose);
        Inc(K);
      end;
    { in the order the names read: floor1, floor2... then top1... }
    SortByName(Pts);
    if Names <> nil then
      for I := 0 to High(Pts) do
        Names.Add(IntToStr(NLine) + '|' + LowerCase(Pts[I].Name) + '=' + Place2(Pts[I].P, U, False));
    Put(Depth, 'points', -1);
    for I := 0 to High(Rings) do
    begin
      Put(Depth + 1, 'ring ' + Rings[I].Name, -1);
      Put(Depth + 2, 'center = ' + Place2(Rings[I].C, U, False), -1);
      Put(Depth + 2, 'radius = ' + Len2(Rings[I].R, U), -1);
      Put(Depth + 2, 'sides  = ' + IntToStr(Rings[I].N), -1);
      Put(Depth + 2, 'facing = ' + Facing2(Rings[I].Facing), -1);
      if Abs(Rings[I].Starts) > 1E-9 then
        Put(Depth + 2, 'starts = ' + Deg2(Rings[I].Starts), -1);
      Put(Depth + 1, 'end', -1);
    end;
    for I := 0 to High(Pts) do
    begin
      if Pts[I].Ring >= 0 then Continue;
      { from an earlier point along one axis: the latest such, and one that
        lets it be said with east, north or up before one that needs west }
      From := -1;
      for J := I - 1 downto 0 do
      begin
        V := Sub3(Pts[I].P, Pts[J].P);
        if AxesUsed(V) <> 1 then Continue;
        if (V.X > 0) or (V.Y > 0) or (V.Z > 0) then begin From := J; Break; end;
        if From < 0 then From := J;
      end;
      if From >= 0 then NextHint := Place2(Pts[I].P, U, False);
      if From >= 0 then
        Put(Depth + 1, Format('%s = %s + %s', [Pts[I].Name, Pts[From].Name,
          Place2(Sub3(Pts[I].P, Pts[From].P), U, True)]), -1)
      else
        Put(Depth + 1, Format('%s = %s', [Pts[I].Name, Place2(Pts[I].P, U, False)]), -1);
    end;
    Put(Depth, 'end', -1);
  end;

  { Are these corners spaced evenly round a circle?  Then they are a ring. }
  function RingOf(const Poly: array of TP3; out Rg: TRing): Boolean;
  var
    K, N: Integer;
    C, Nm, AU, AV, W0, W1: TP3;
    R, A, A1: Double;
  begin
    Result := False;
    N := Length(Poly);
    if N < 8 then Exit;
    C := P3(0, 0, 0);
    for K := 0 to N - 1 do C := P3(C.X + Poly[K].X / N, C.Y + Poly[K].Y / N, C.Z + Poly[K].Z / N);
    R := Dist(Poly[0], C);
    if R < 1E-9 then Exit;
    for K := 0 to N - 1 do
      if Abs(Dist(Poly[K], C) - R) > 1E-9 then Exit;
    { the way it faces: the way its own order turns }
    W0 := Sub3(Poly[0], C);
    W1 := Sub3(Poly[1], C);
    Nm := P3(W0.Y * W1.Z - W0.Z * W1.Y, W0.Z * W1.X - W0.X * W1.Z, W0.X * W1.Y - W0.Y * W1.X);
    A := Sqrt(Nm.X * Nm.X + Nm.Y * Nm.Y + Nm.Z * Nm.Z);
    if A < 1E-12 then Exit;
    Nm := P3(Nm.X / A, Nm.Y / A, Nm.Z / A);
    SpecAxes(Nm, AU, AV);
    A := ArcTan2(Dot3(W0, AV), Dot3(W0, AU));
    for K := 1 to N - 1 do
    begin
      A1 := A + K * 2 * Pi / N;
      if not SameP(Poly[K], P3(C.X + (AU.X * Cos(A1) + AV.X * Sin(A1)) * R,
                               C.Y + (AU.Y * Cos(A1) + AV.Y * Sin(A1)) * R,
                               C.Z + (AU.Z * Cos(A1) + AV.Z * Sin(A1)) * R)) then Exit;
    end;
    Rg.C := C;
    Rg.R := R;
    Rg.N := N;
    Rg.Facing := Nm;
    Rg.Starts := A;
    Result := True;
  end;

  procedure PutInk(Depth, I: Integer);
  begin
    if D[I].Ink <> DefInk then Put(Depth, 'ink = ' + Color2(D[I].Ink), I);
    if (D[I].Kind in [ekLine, ekArc]) and (Abs(D[I].Weight - DefWidth) > 1E-3) then
      Put(Depth, 'width = ' + FloatToStrF(D[I].Weight, ffGeneral, 4, 0, FS), I);
  end;

  { HasMat/Mat: what the solid this face is in says its faces are made of,
    so a face only speaks up when it is made of something else }
  procedure PutFace(Depth, I: Integer; const Pts: TPts; HasMat: Boolean = False;
    Mat: TColor = 0);
  var
    K: Integer;
    Note, W: string;
    SameMat: Boolean;
  begin
    W := FacingWord(D.FaceNormal(I));
    if W <> '' then Note := '   { facing ' + W + ' }' else Note := '';
    SameMat := (D[I].MatSet = HasMat) and ((not HasMat) or (D[I].Mat = Mat));
    if SameMat and (Length(D[I].Holes) = 0) and (D[I].Ink = DefInk) then
    begin
      PutList(Depth, 'face', Outline(Pts, D[I].Poly, D[I].Part), I, Note);
      Exit;
    end;
    Put(Depth, 'face' + Note, I);
    PutList(Depth + 1, 'points', Outline(Pts, D[I].Poly, D[I].Part), I);
    for K := 0 to High(D[I].Holes) do
      PutList(Depth + 1, 'hole', Outline(Pts, D[I].Holes[K], D[I].Part), I);
    if not SameMat then
      if D[I].MatSet then Put(Depth + 1, 'paint = ' + Color2(D[I].Mat), I)
      else Put(Depth + 1, 'paint = none', I);
    if D[I].Ink <> DefInk then Put(Depth + 1, 'ink = ' + Color2(D[I].Ink), I);
    Put(Depth, 'end', I);
  end;

  { A line is two points.  Which is first does not matter, and nothing
    about it says a direction - the two places do. }
  procedure PutLine(Depth, I: Integer; const Pts: TPts);
  var
    Ends: string;
  begin
    Ends := Ref(Pts, D[I].A) + ' to ' + Ref(Pts, D[I].B);
    if (D[I].Ink = DefInk) and (Abs(D[I].Weight - DefWidth) <= 1E-3) and
       (not D[I].Soft) and (not D[I].Dim) then
    begin
      Put(Depth, 'line = ' + Ends, I);
      Exit;
    end;
    Put(Depth, 'line', I);
    Put(Depth + 1, 'points = ' + Ends, I);
    PutInk(Depth + 1, I);
    if D[I].Soft then Put(Depth + 1, 'soft = true', I);
    if D[I].Dim then Put(Depth + 1, 'ref = true', I);
    Put(Depth, 'end', I);
  end;

  procedure PutOther(Depth, I: Integer);
  var
    Parts: TStringList;
    K: Integer;
    Nm, AU, AV, P0: TP3;
    A0: Double;
  begin
    case D[I].Kind of
      ekArc:
        begin
          { which way it faces is the way its own turning goes round, and
            where it starts is measured the grammar's way - from the level
            line - whatever axes the program happens to keep for the plane }
          Nm := P3(0, 0, 1);
          case D[I].Plane of
            plXZ: Nm := P3(0, -1, 0);
            plYZ: Nm := P3(1, 0, 0);
            plFree: Nm := D[I].Nm;
          end;
          SpecAxes(Nm, AU, AV);
          P0 := Sub3(ArcPoint(D[I].C, D[I].R, D[I].A0, D[I].Plane, D[I].Nm), D[I].C);
          A0 := ArcTan2(Dot3(P0, AV), Dot3(P0, AU));
          { A plain circle is one line: its center and its radius, and which
            way it faces only when that is not up.  Anything else about it -
            where it starts, its own sides, an ink - and it is a block. }
          if (Abs(Abs(D[I].Sweep) - 2 * Pi) < 1E-9) and (Abs(A0) <= 1E-9) and
             (D[I].Sides < 3) and (D[I].Ink = DefInk) and
             (Abs(D[I].Weight - DefWidth) <= 1E-3) then
          begin
            if Abs(Nm.Z - 1) < 1E-9 then
              Put(Depth, Trim('circle ' + CircleName(I)) + ' = ' + Place2(D[I].C, U, False) +
                '; ' + Len2(D[I].R, U), I)
            else
              Put(Depth, Trim('circle ' + CircleName(I)) + ' = ' + Place2(D[I].C, U, False) +
                '; ' + Len2(D[I].R, U) + '; ' + Facing2(Nm), I);
            Exit;
          end;
          if Abs(Abs(D[I].Sweep) - 2 * Pi) < 1E-9 then Put(Depth, 'circle ' + CircleName(I), I)
          else Put(Depth, 'arc', I);
          Put(Depth + 1, 'center = ' + Place2(D[I].C, U, False), I);
          Put(Depth + 1, 'radius = ' + Len2(D[I].R, U), I);
          Put(Depth + 1, 'facing = ' + Facing2(Nm), I);
          if Abs(A0) > 1E-9 then Put(Depth + 1, 'starts = ' + Deg2(A0), I);
          if Abs(Abs(D[I].Sweep) - 2 * Pi) >= 1E-9 then
            Put(Depth + 1, 'sweep = ' + Deg2(D[I].Sweep), I);
          if D[I].Sides >= 3 then Put(Depth + 1, 'sides = ' + IntToStr(D[I].Sides), I);
          PutInk(Depth + 1, I);
          Put(Depth, 'end', I);
        end;
      ekDim:
        begin
          Put(Depth, 'dim', I);
          Put(Depth + 1, 'from = ' + Place2(D[I].A, U, False), I);
          Put(Depth + 1, 'to = ' + Place2(D[I].B, U, False), I);
          Put(Depth + 1, 'off = ' + Place2(D[I].C, U, True), I);
          if D[I].Txt <> '' then Put(Depth + 1, 'label = ' + Quoted(D[I].Txt), I);
          PutInk(Depth + 1, I);
          Put(Depth, 'end', I);
        end;
      ekGuide:
        if SameP(D[I].A, D[I].B) then
          Put(Depth, 'guide = ' + Place2(D[I].A, U, False), I)
        else
          Put(Depth, 'guide = ' + Place2(D[I].A, U, False) + ' to ' +
            Place2(D[I].B, U, False), I);
      ekText:
        begin
          Put(Depth, 'note', I);
          Put(Depth + 1, 'at = ' + Place2(D[I].A, U, False), I);
          if not SameP(D[I].A, D[I].B) then
            Put(Depth + 1, 'to = ' + Place2(D[I].B, U, False), I);
          Parts := TStringList.Create;
          try
            Parts.Text := D[I].Txt;
            for K := 0 to Parts.Count - 1 do
              Put(Depth + 1, 'text = ' + Quoted(Parts[K]), I);
          finally
            Parts.Free;
          end;
          if (D[I].Size > 0) and (Abs(D[I].Size - 1) > 1E-6) then
            Put(Depth + 1, 'size = ' + FloatToStrF(D[I].Size, ffGeneral, 4, 0, FS), I);
          PutInk(Depth + 1, I);
          Put(Depth, 'end', I);
        end;
    end;
  end;

  { Is this solid exactly a box - and nothing more?  Eight corners on two
    heights, six faces of four corners square to the axes with no hole,
    twelve ordinary edges, one paint over the whole or none.  Then it can
    be said as one: docs/primitives.md, "a primitive is a fold".  A box
    whose top has a circle's hole in it is not, for now - the fold under a
    circle is step 3 on that page. }
  { A disk in a box's face: a face of the solid whose outline is a circle
    by name.  Written after the box as "face = c1"; the hole it sits in is
    the circle's doing, and the reader cuts it again from the circle. }
  function IsDisk(I, Part_: Integer): Boolean;
  begin
    Result := (D[I].Kind = ekFace) and (Length(D[I].Poly) >= 8) and
      (Length(D[I].Holes) = 0) and (CircleNamed(D[I].Poly, Part_) <> '');
  end;

  function IsBox(Part_, G: Integer; out Lo, Hi: TP3; out HasPaint: Boolean; out Paint: TColor): Boolean;
  var
    I, K, NF, NL, NPaint: Integer;
    Pts: TPts;
    Nm: TP3;
  begin
    Result := False;
    SetLength(Pts, 0);
    NF := 0; NL := 0; NPaint := 0;
    HasPaint := False; Paint := 0;
    for I := 0 to D.Live - 1 do
    begin
      if (D[I].Grp <> G) or (D[I].Part <> Part_) then Continue;
      if IsDisk(I, Part_) then Continue;
      case D[I].Kind of
        ekFace:
          begin
            Inc(NF);
            if (Length(D[I].Poly) <> 4) or (D[I].Ink <> DefInk) then Exit;
            { a hole is allowed when it is a circle drawn on the face - the
              box is still a box, and the circle is written on its own }
            for K := 0 to High(D[I].Holes) do
              if CircleNamed(D[I].Holes[K], Part_) = '' then Exit;
            if FacingWord(D.FaceNormal(I)) = '' then Exit;
            for K := 0 to 3 do AddPt(Pts, D[I].Poly[K]);
            if D[I].MatSet then
            begin
              if (NPaint > 0) and (D[I].Mat <> Paint) then Exit;
              Paint := D[I].Mat;
              Inc(NPaint);
            end;
          end;
        ekLine:
          begin
            Inc(NL);
            if D[I].Soft or D[I].Dim or (D[I].Ink <> DefInk) or (Abs(D[I].Weight - DefWidth) > 1E-3) then Exit;
            if AxesUsed(Sub3(D[I].B, D[I].A)) <> 1 then Exit;
          end;
        ekBore: Exit;
      end;
    end;
    if (NF <> 6) or (NL <> 12) or (Length(Pts) <> 8) then Exit;
    if not (NPaint in [0, 6]) then Exit;
    HasPaint := NPaint = 6;
    Lo := Pts[0].P; Hi := Pts[0].P;
    for I := 1 to 7 do
    begin
      Lo := P3(Min(Lo.X, Pts[I].P.X), Min(Lo.Y, Pts[I].P.Y), Min(Lo.Z, Pts[I].P.Z));
      Hi := P3(Max(Hi.X, Pts[I].P.X), Max(Hi.Y, Pts[I].P.Y), Max(Hi.Z, Pts[I].P.Z));
    end;
    { every corner at a low or high of each axis: the eight of a box }
    for I := 0 to 7 do
      if not ((Abs(Pts[I].P.X - Lo.X) < 1E-9) or (Abs(Pts[I].P.X - Hi.X) < 1E-9)) or
         not ((Abs(Pts[I].P.Y - Lo.Y) < 1E-9) or (Abs(Pts[I].P.Y - Hi.Y) < 1E-9)) or
         not ((Abs(Pts[I].P.Z - Lo.Z) < 1E-9) or (Abs(Pts[I].P.Z - Hi.Z) < 1E-9)) then Exit;
    if (Hi.X - Lo.X < 1E-9) or (Hi.Y - Lo.Y < 1E-9) or (Hi.Z - Lo.Z < 1E-9) then Exit;
    Result := True;
  end;

  procedure PutBox(Depth, Part_, G: Integer; const Lo, Hi: TP3; HasPaint: Boolean; Paint: TColor);
  var
    I, Header: Integer;
    NoPts: TPts;
  begin
    Header := NLine;
    if HasPaint then
    begin
      Put(Depth, 'box', -1);
      Put(Depth + 1, 'at   = ' + Place2(Lo, U, False), -1);
      Put(Depth + 1, 'size = ' + Place2(Sub3(Hi, Lo), U, True), -1);
      Put(Depth + 1, 'paint = ' + Color2(Paint), -1);
      Put(Depth, 'end', -1);
    end
    else
      Put(Depth, 'box = ' + Place2(Lo, U, False) + '; ' + Place2(Sub3(Hi, Lo), U, True), -1);
    { every face and edge of it is that statement: picked on the sheet,
      the box lights up }
    for I := 0 to D.Live - 1 do
      if (D[I].Grp = G) and (D[I].Part = Part_) and (D[I].Kind in [ekFace, ekLine]) and
         not IsDisk(I, Part_) then
      begin
        First[I] := Header;
        Last[I] := NLine - 1;
      end;
    { and the disks lying in its faces, by their circles' names }
    SetLength(NoPts, 0);
    for I := 0 to D.Live - 1 do
      if (D[I].Grp = G) and (D[I].Part = Part_) and IsDisk(I, Part_) then
        PutFace(Depth, I, NoPts, HasPaint, Paint);
  end;

  { one solid: its corners once, its faces, and only the edges that are
    out of the ordinary - the rest are the faces' sides and go unsaid }
  procedure PutSolid(Depth, Part_, G: Integer);
  var
    Pts: TPts;
    I, J, K, N, Header, Best: Integer;
    HasMat: Boolean;
    SMat: TColor;
    Rings: TRings;
    Rg: TRing;

  begin
    SetLength(Pts, 0);
    N := 0;
    for I := 0 to D.Live - 1 do
      if (D[I].Kind = ekFace) and (D[I].Grp = G) and (D[I].Part = Part_) then
      begin
        Inc(N);
        { a loop that is a circle by name - "face = c1", "hole = c1" - has
          no corners to list: the circle says them }
        if CircleNamed(D[I].Poly, Part_) = '' then
          for K := 0 to High(D[I].Poly) do
          begin
            AddPt(Pts, D[I].Poly[K]);
            Pts[FindPt(Pts, D[I].Poly[K])].InHole := False;
          end;
        for J := 0 to High(D[I].Holes) do
          if CircleNamed(D[I].Holes[J], Part_) = '' then
            for K := 0 to High(D[I].Holes[J]) do AddPt(Pts, D[I].Holes[J][K]);
      end;
    { what most of its faces are made of is said once, for the solid }
    HasMat := False;
    SMat := 0;
    Best := 0;
    for I := 0 to D.Live - 1 do
      if (D[I].Kind = ekFace) and (D[I].Grp = G) and (D[I].Part = Part_) and D[I].MatSet then
      begin
        K := 0;
        for J := 0 to D.Live - 1 do
          if (D[J].Kind = ekFace) and (D[J].Grp = G) and (D[J].Part = Part_) and
             D[J].MatSet and (D[J].Mat = D[I].Mat) then Inc(K);
        if K > Best then begin Best := K; SMat := D[I].Mat; end;
        if Best * 2 > N then Break;
      end;
    HasMat := (Best >= 2) and (Best * 2 > N);
    { the round faces' corners are rings: each said once, its corners named
      ra1, ra2... in the order that face goes round }
    SetLength(Rings, 0);
    for I := 0 to High(Pts) do Pts[I].Ring := -1;
    for I := 0 to D.Live - 1 do
      if (D[I].Kind = ekFace) and (D[I].Grp = G) and (D[I].Part = Part_) then
        for J := -1 to High(D[I].Holes) do
        begin
          if J < 0 then Best := Ord(RingOf(D[I].Poly, Rg))
          else Best := Ord(RingOf(D[I].Holes[J], Rg));
          if Best = 0 then Continue;
          if J < 0 then begin if CircleNamed(D[I].Poly, Part_) <> '' then Continue; end
          else if CircleNamed(D[I].Holes[J], Part_) <> '' then Continue;
          if J < 0 then K := FindPt(Pts, D[I].Poly[0]) else K := FindPt(Pts, D[I].Holes[J][0]);
          if (K < 0) or (Pts[K].Ring >= 0) then Continue;   { that ring is known }
          Rg.Name := 'r' + Chr(Ord('a') + Length(Rings) mod 26);
          if Length(Rings) >= 26 then Rg.Name := Rg.Name + IntToStr(Length(Rings) div 26);
          SetLength(Rings, Length(Rings) + 1);
          Rings[High(Rings)] := Rg;
          for Best := 0 to Rg.N - 1 do
          begin
            if J < 0 then K := FindPt(Pts, D[I].Poly[Best]) else K := FindPt(Pts, D[I].Holes[J][Best]);
            if (K >= 0) and (Pts[K].Ring < 0) then
            begin
              Pts[K].Ring := High(Rings);
              Pts[K].Name := Rg.Name + IntToStr(Best + 1);
            end;
          end;
        end;
    Header := NLine;
    Put(Depth, 'solid', -1);
    if HasMat then Put(Depth + 1, 'paint = ' + Color2(SMat), -1);
    PutPoints(Depth + 1, Pts, Rings);
    for I := 0 to D.Live - 1 do
      if (D[I].Kind = ekFace) and (D[I].Grp = G) and (D[I].Part = Part_) then
        PutFace(Depth + 1, I, Pts, HasMat, SMat);
    for I := 0 to D.Live - 1 do
      if (D[I].Kind = ekLine) and (D[I].Grp = G) and (D[I].Part = Part_) then
      begin
        PutLine(Depth + 1, I, Pts);
      end
      else if (D[I].Kind = ekBore) and (D[I].Grp = G) and (D[I].Part = Part_) then
      begin
        Put(Depth + 1, 'bore', I);
        PutList(Depth + 2, 'points', Items(Pts, D[I].Poly), I);
        Put(Depth + 2, 'goes = ' + Place2(Sub3(D[I].B, D[I].Poly[0]), U, True), I);
        Put(Depth + 1, 'end', I);
      end;
    Put(Depth, 'end', -1);
  end;

  { everything in one group - Part_ 0 is the sheet itself - then the groups
    inside it }
  procedure PutLevel(Depth, Part_: Integer);
  var
    I, J, G: Integer;
    Done: array of Integer;
    Seen, BPaintOn: Boolean;
    None: TPts;
    BLo, BHi: TP3;
    BPaint: TColor;
  begin
    SetLength(None, 0);
    SetLength(Done, 0);
    { the circles first: faces and holes further down say them by name }
    for I := 0 to D.Live - 1 do
      if (D[I].Part = Part_) and (CircleName(I) <> '') then PutOther(Depth, I);
    for I := 0 to D.Live - 1 do
    begin
      if D[I].Part <> Part_ then Continue;
      if D[I].Kind = ekPart then Continue;
      if CircleName(I) <> '' then Continue;
      G := D[I].Grp;
      if (G <> 0) and (D[I].Kind in [ekFace, ekLine, ekBore]) then
      begin
        Seen := False;
        for J := 0 to High(Done) do
          if Done[J] = G then begin Seen := True; Break; end;
        if Seen then Continue;
        SetLength(Done, Length(Done) + 1);
        Done[High(Done)] := G;
        if IsBox(Part_, G, BLo, BHi, BPaintOn, BPaint) then
          PutBox(Depth, Part_, G, BLo, BHi, BPaintOn, BPaint)
        else
          PutSolid(Depth, Part_, G);
        Continue;
      end;
      case D[I].Kind of
        ekFace: PutFace(Depth, I, None);
        ekLine: PutLine(Depth, I, None);
      else
        PutOther(Depth, I);
      end;
    end;
    for I := 0 to D.Live - 1 do
      if (D[I].Kind = ekPart) and (D[I].Part = Part_) then
      begin
        Put(Depth, 'group ' + Quoted(D[I].Txt), I);
        if D[I].Solid then Put(Depth + 1, 'locked = true', I);
        if D[I].Jig <> '' then Put(Depth + 1, 'jig = ' + D[I].Jig, I);
        PutLevel(Depth + 1, D[I].Grp);
        Put(Depth, 'end', I);
      end;
  end;

var
  I: Integer;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  NLine := 0;
  NextHint := '';
  SetLength(LineThing, 256);
  SetLength(First, D.Live);
  SetLength(Last, D.Live);
  for I := 0 to D.Live - 1 do begin First[I] := 0; Last[I] := -1; end;
  FindDefaults;
  SetLength(Circles, 0);
  for I := 0 to D.Live - 1 do
    if (D[I].Kind = ekArc) and (Abs(Abs(D[I].Sweep) - 2 * Pi) < 1E-9) then
    begin
      SetLength(Circles, Length(Circles) + 1);
      Circles[High(Circles)] := I;
    end;

  Put(0, 'HeckersSketch 2', -1);
  if U = usMetric then Put(0, 'units = mm', -1)
  else Put(0, 'units = ft in', -1);
  Put(0, '', -1);
  Put(0, 'sheet ' + Quoted(SheetName), -1);
  Put(1, 'ink = ' + Color2(DefInk), -1);
  Put(1, 'width = ' + FloatToStrF(DefWidth, ffGeneral, 4, 0, FS), -1);
  Put(0, '', -1);
  PutLevel(1, 0);
  Put(0, 'end', -1);
  SetLength(LineThing, NLine);
end;

end.
