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
procedure WriteFormat2(D: TWorkDoc; const SheetName: string; U: TUnitSystem;
  L: TStrings; out First, Last, LineThing: TIntArrayW);

{ one length, the way the file writes it; always positive - the direction
  word carries the sign }
function Len2(V: Double; U: TUnitSystem): string;

implementation

type
  TPt = record
    P: TP3;
    Name: string;
  end;
  TPts = array of TPt;

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

{ "2' east, 3' north, 18" above the floor" - or an offset, which says up
  and down instead }
function Place2(const P: TP3; U: TUnitSystem; Offset: Boolean): string;

  procedure Part(V: Double; const Plus, Minus: string);
  begin
    if Abs(V) < FRIENDLY_TOL then Exit;
    if Result <> '' then Result := Result + ', ';
    if V > 0 then Result := Result + Len2(V, U) + ' ' + Plus
    else Result := Result + Len2(V, U) + ' ' + Minus;
  end;

begin
  Result := '';
  Part(P.X, 'east', 'west');
  Part(P.Y, 'north', 'south');
  if Offset then Part(P.Z, 'up', 'down')
  else Part(P.Z, 'above the floor', 'below the floor');
  if Result = '' then
    if Offset then Result := '0' else Result := 'origin';
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
  L: TStrings; out First, Last, LineThing: TIntArrayW);
var
  DefInk: TColor;
  DefWidth: Single;
  NLine: Integer;
  FS: TFormatSettings;

  procedure Put(Depth: Integer; const S: string; Thing: Integer);
  begin
    L.Add(StringOfChar(' ', Depth * 2) + S);
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
    DefInk := $1A1C20;
    DefWidth := 1;
    Best := 0;
    for I := 0 to Min(D.Live - 1, 400) do
      if D[I].Kind = ekLine then
      begin
        N := 0;
        for J := 0 to Min(D.Live - 1, 400) do
          if (D[J].Kind = ekLine) and (D[J].Ink = D[I].Ink) then Inc(N);
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
    if Count <= 26 then Result := Chr(Ord('a') + Index)
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
  end;

  function Ref(const Pts: TPts; const P: TP3): string;
  var
    K: Integer;
  begin
    K := FindPt(Pts, P);
    if K >= 0 then Result := Pts[K].Name
    else Result := Place2(P, U, False);
  end;

  function Loop(const Pts: TPts; const Poly: array of TP3): string;
  var
    K: Integer;
  begin
    Result := '';
    for K := 0 to High(Poly) do
    begin
      if K > 0 then
        if FindPt(Pts, Poly[K]) >= 0 then Result := Result + ' '
        else Result := Result + ';  ';
      Result := Result + Ref(Pts, Poly[K]);
    end;
  end;

  procedure PutPoints(Depth: Integer; var Pts: TPts);
  var
    I, J, From: Integer;
    V: TP3;
  begin
    if Length(Pts) = 0 then Exit;
    for I := 0 to High(Pts) do Pts[I].Name := PointName(I, Length(Pts));
    Put(Depth, 'points', -1);
    for I := 0 to High(Pts) do
    begin
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
      if From >= 0 then
        Put(Depth + 1, Format('%s = %s + %s', [Pts[I].Name, Pts[From].Name,
          Place2(Sub3(Pts[I].P, Pts[From].P), U, True)]), -1)
      else
        Put(Depth + 1, Format('%s = %s', [Pts[I].Name, Place2(Pts[I].P, U, False)]), -1);
    end;
    Put(Depth, 'end', -1);
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
      Put(Depth, 'face = ' + Loop(Pts, D[I].Poly) + Note, I);
      Exit;
    end;
    Put(Depth, 'face' + Note, I);
    Put(Depth + 1, 'corners = ' + Loop(Pts, D[I].Poly), I);
    for K := 0 to High(D[I].Holes) do
      Put(Depth + 1, 'hole = ' + Loop(Pts, D[I].Holes[K]), I);
    if not SameMat then
      if D[I].MatSet then Put(Depth + 1, 'material = ' + Color2(D[I].Mat), I)
      else Put(Depth + 1, 'material = none', I);
    if D[I].Ink <> DefInk then Put(Depth + 1, 'ink = ' + Color2(D[I].Ink), I);
    Put(Depth, 'end', I);
  end;

  procedure PutLine(Depth, I: Integer; const Pts: TPts);
  var
    V: TP3;
  begin
    Put(Depth, 'line', I);
    Put(Depth + 1, 'from = ' + Ref(Pts, D[I].A), I);
    V := Sub3(D[I].B, D[I].A);
    if (AxesUsed(V) = 1) and (FindPt(Pts, D[I].B) < 0) then
      Put(Depth + 1, 'goes = ' + Place2(V, U, True), I)
    else
      Put(Depth + 1, 'to = ' + Ref(Pts, D[I].B), I);
    PutInk(Depth + 1, I);
    if D[I].Soft then Put(Depth + 1, 'soft = yes', I);
    if D[I].Dim then Put(Depth + 1, 'reference = yes', I);
    Put(Depth, 'end', I);
  end;

  procedure PutOther(Depth, I: Integer);
  var
    Parts: TStringList;
    K: Integer;
    W: string;
    Nm: TP3;
  begin
    case D[I].Kind of
      ekArc:
        begin
          if Abs(Abs(D[I].Sweep) - 2 * Pi) < 1E-9 then Put(Depth, 'circle', I)
          else Put(Depth, 'arc', I);
          Put(Depth + 1, 'center = ' + Place2(D[I].C, U, False), I);
          Put(Depth + 1, 'radius = ' + Len2(D[I].R, U), I);
          case D[I].Plane of
            plXY: W := 'up';
            plXZ: W := 'north';
            plYZ: W := 'east';
          else
            begin
              Nm := D[I].Nm;
              W := FacingWord(Nm);
              if W = '' then
                W := Format('%.6g east, %.6g north, %.6g up', [Nm.X, Nm.Y, Nm.Z], FS);
            end;
          end;
          Put(Depth + 1, 'facing = ' + W, I);
          if Abs(D[I].A0) > 1E-9 then
            Put(Depth + 1, 'starts = ' + FloatToStrF(RadToDeg(D[I].A0), ffGeneral, 10, 0, FS) + '°', I);
          if Abs(Abs(D[I].Sweep) - 2 * Pi) >= 1E-9 then
            Put(Depth + 1, 'sweep = ' + FloatToStrF(RadToDeg(D[I].Sweep), ffGeneral, 10, 0, FS) + '°', I);
          if D[I].Sides >= 3 then Put(Depth + 1, 'sides = ' + IntToStr(D[I].Sides), I);
          PutInk(Depth + 1, I);
          Put(Depth, 'end', I);
        end;
      ekDim:
        begin
          Put(Depth, 'dimension', I);
          Put(Depth + 1, 'from = ' + Place2(D[I].A, U, False), I);
          Put(Depth + 1, 'to = ' + Place2(D[I].B, U, False), I);
          Put(Depth + 1, 'stands off = ' + Place2(D[I].C, U, True), I);
          if D[I].Txt <> '' then Put(Depth + 1, 'label = ' + Quoted(D[I].Txt), I);
          PutInk(Depth + 1, I);
          Put(Depth, 'end', I);
        end;
      ekGuide:
        if SameP(D[I].A, D[I].B) then
          Put(Depth, 'guide = ' + Place2(D[I].A, U, False), I)
        else
          Put(Depth, 'guide = ' + Place2(D[I].A, U, False) + ';  ' +
            Place2(D[I].B, U, False), I);
      ekText:
        begin
          Put(Depth, 'note', I);
          Put(Depth + 1, 'at = ' + Place2(D[I].A, U, False), I);
          if not SameP(D[I].A, D[I].B) then
            Put(Depth + 1, 'points to = ' + Place2(D[I].B, U, False), I);
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

  { one solid: its corners once, its faces, and only the edges that are
    out of the ordinary - the rest are the faces' sides and go unsaid }
  procedure PutSolid(Depth, Part_, G: Integer);
  var
    Pts: TPts;
    I, J, K, N, Header, Best: Integer;
    HasMat: Boolean;
    SMat: TColor;
    Side: array of Boolean;      { is line I the side of one of the faces? }

    function IsSide(const A, B: TP3): Boolean;
    var
      F, Q, M: Integer;
    begin
      Result := False;
      for F := 0 to D.Live - 1 do
        if (D[F].Kind = ekFace) and (D[F].Grp = G) and (D[F].Part = Part_) then
        begin
          M := Length(D[F].Poly);
          for Q := 0 to M - 1 do
            if (SameP(D[F].Poly[Q], A) and SameP(D[F].Poly[(Q + 1) mod M], B)) or
               (SameP(D[F].Poly[Q], B) and SameP(D[F].Poly[(Q + 1) mod M], A)) then
              Exit(True);
        end;
    end;

  begin
    SetLength(Pts, 0);
    N := 0;
    for I := 0 to D.Live - 1 do
      if (D[I].Kind = ekFace) and (D[I].Grp = G) and (D[I].Part = Part_) then
      begin
        Inc(N);
        for K := 0 to High(D[I].Poly) do AddPt(Pts, D[I].Poly[K]);
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
    Header := NLine;
    Put(Depth, 'solid', -1);
    if HasMat then Put(Depth + 1, 'material = ' + Color2(SMat), -1);
    PutPoints(Depth + 1, Pts);
    for I := 0 to D.Live - 1 do
      if (D[I].Kind = ekFace) and (D[I].Grp = G) and (D[I].Part = Part_) then
        PutFace(Depth + 1, I, Pts, HasMat, SMat);
    SetLength(Side, D.Live);
    for I := 0 to D.Live - 1 do
      if (D[I].Kind = ekLine) and (D[I].Grp = G) and (D[I].Part = Part_) then
      begin
        { a big solid is asked about each of its edges against each of its
          faces; past a point, say they are all sides and be quick }
        if N > 600 then Side[I] := True else Side[I] := IsSide(D[I].A, D[I].B);
        if not Side[I] then
          PutLine(Depth + 1, I, Pts)
        else if D[I].Soft or (D[I].Ink <> DefInk) or (Abs(D[I].Weight - DefWidth) > 1E-3) then
        begin
          Put(Depth + 1, 'edge', I);
          Put(Depth + 2, 'between = ' + Ref(Pts, D[I].A) + ' ' + Ref(Pts, D[I].B), I);
          if D[I].Soft then Put(Depth + 2, 'soft = yes', I);
          PutInk(Depth + 2, I);
          Put(Depth + 1, 'end', I);
        end;
        { an ordinary side has no line of its own; picked on the sheet, it
          lights the solid it belongs to }
        if First[I] > Last[I] then
        begin
          First[I] := Header;
          Last[I] := Header;
        end;
      end
      else if (D[I].Kind = ekBore) and (D[I].Grp = G) and (D[I].Part = Part_) then
      begin
        Put(Depth + 1, 'drilled', I);
        Put(Depth + 2, 'outline = ' + Loop(Pts, D[I].Poly), I);
        Put(Depth + 2, 'through = ' + Place2(D[I].B, U, True), I);
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
    Seen: Boolean;
    None: TPts;
  begin
    SetLength(None, 0);
    SetLength(Done, 0);
    for I := 0 to D.Live - 1 do
    begin
      if D[I].Part <> Part_ then Continue;
      if D[I].Kind = ekPart then Continue;
      G := D[I].Grp;
      if (G <> 0) and (D[I].Kind in [ekFace, ekLine, ekBore]) then
      begin
        Seen := False;
        for J := 0 to High(Done) do
          if Done[J] = G then begin Seen := True; Break; end;
        if Seen then Continue;
        SetLength(Done, Length(Done) + 1);
        Done[High(Done)] := G;
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
        if D[I].Solid then Put(Depth + 1, 'locked = yes', I);
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
  SetLength(LineThing, 256);
  SetLength(First, D.Live);
  SetLength(Last, D.Live);
  for I := 0 to D.Live - 1 do begin First[I] := 0; Last[I] := -1; end;
  FindDefaults;

  Put(0, 'HeckersSketch 2', -1);
  if U = usMetric then Put(0, 'lengths = millimeters', -1)
  else Put(0, 'lengths = feet and inches', -1);
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
