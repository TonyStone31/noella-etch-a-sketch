unit uPipe;

{ A pipe spool from a fitter's iso.

  The fitter draws the run as legs - each one along an axis, or on a 45
  between two axes - and writes a center-to-center length on each.  The
  paper is not to scale; the numbers are the drawing.  From that, with the
  pipe size and the kind of elbow, this works out the centerline with its
  bends, the cut length of every straight piece (center to center less the
  elbows' take-outs), and builds the spool as one solid by pushing a circle
  along the centerline. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Graphics, uWork;

type
  TPipeEnd = (peBevel, peFlange, peCap, peThread);

  TSpoolLeg = record
    Dir: TP3;        { a unit direction: an axis, or a 45 between two }
    Len: Double;     { what the fitter measured, in drawing units }
    Has: Boolean;    { whether a length has been given at all }
    { What the measurement runs between.  A fitter measures what can be
      reached: center of elbow to center of elbow, or from the end of the
      pipe - the flange face, the weld - to the next center, or end to end.
      The shop wants center to center and cut lengths; the elbows' take-outs
      make one from the other. }
    FromEnd: Boolean;   { measured from the pipe end at the start, not the center }
    ToEnd: Boolean;     { measured to the pipe end at the finish, not the center }
    Steps: Integer;  { how long it was drawn on the paper, in grid steps }
  end;

  TSpoolSpec = record
    Size: Integer;               { index into the NPS tables }
    LongRadius: Boolean;         { long radius elbows (1.5 D) or short (1 D) }
    Ends: array[0..1] of TPipeEnd;
    Legs: array of TSpoolLeg;
    Inch: Double;                { one inch in drawing units }
    Tag: string;
    Dims: Boolean;
  end;

const
  NPS_NAMES: array[0..12] of string = ('1/2"', '3/4"', '1"', '1 1/4"', '1 1/2"',
    '2"', '2 1/2"', '3"', '4"', '6"', '8"', '10"', '12"');
  NPS_NOMINAL: array[0..12] of Double = (0.5, 0.75, 1, 1.25, 1.5, 2, 2.5, 3, 4, 6, 8, 10, 12);
  NPS_OD: array[0..12] of Double = (0.84, 1.05, 1.315, 1.66, 1.9, 2.375, 2.875, 3.5,
    4.5, 6.625, 8.625, 10.75, 12.75);
  { class 150 weld-neck flange outside diameters, and one thickness for all }
  NPS_FLANGE_OD: array[0..12] of Double = (3.5, 3.875, 4.25, 4.625, 5, 6, 7, 7.5,
    9, 11, 13.5, 16, 19);
  FLANGE_THICK_IN = 1.0;
  PIPE_END_NAMES: array[TPipeEnd] of string = ('Plain, bevelled for weld',
    'Weld-neck flange', 'Cap', 'Threaded');
  PIPE_SIDES = 24;

{ the bend radius of the elbows, in drawing units }
function ElbowRadius(const S: TSpoolSpec): Double;
{ the turn at the corner after leg I, radians, 0 where the run goes straight on }
function TurnAfter(const S: TSpoolSpec; I: Integer): Double;
{ what an elbow of that turn takes off each leg it joins }
function TakeOut(const S: TSpoolSpec; Turn: Double): Double;
{ the take-out at the start of leg I and at its end: 0 at the run's ends }
function TakeOutBefore(const S: TSpoolSpec; I: Integer): Double;
function TakeOutAfterLeg(const S: TSpoolSpec; I: Integer): Double;
{ leg I center to center, whatever the fitter measured between }
function CCLength(const S: TSpoolSpec; I: Integer): Double;
{ the cut length of leg I: center to center less its elbows }
function CutLength(const S: TSpoolSpec; I: Integer): Double;
{ whether every leg has its length, so the spool can be worked out }
function SketchComplete(const S: TSpoolSpec): Boolean;
{ the measurement in the fitter's words: center to center, end to center... }
function MeasureWords(const S: TSpoolSpec; I: Integer): string;
{ what is wrong, or '' }
function SpoolProblem(const S: TSpoolSpec): string;
{ the centerline: straight legs with the bends drawn in as arcs }
procedure SpoolPath(const S: TSpoolSpec; out Pts: TP3Array);
{ the spool as one solid; returns the index of its first entity }
function BuildSpool(D: TWorkDoc; const S: TSpoolSpec; Ink: TColor; Weight: Single): Integer;
{ the ticket, in words: size, ends, every leg with its cut length, the elbows }
function SpoolTicket(const S: TSpoolSpec): string;
{ the name of a direction the way a fitter says it }
function DirName(const Dir: TP3): string;

implementation

function Inch(const S: TSpoolSpec): Double;
begin
  Result := S.Inch;
  if Result <= 0 then Result := 1 / 12;
end;

function ElbowRadius(const S: TSpoolSpec): Double;
var
  Nom: Double;
begin
  Nom := NPS_NOMINAL[EnsureRange(S.Size, 0, High(NPS_NOMINAL))];
  if S.LongRadius then Result := 1.5 * Nom else Result := Max(1, Nom);
  Result := Result * Inch(S);
end;

function TurnAfter(const S: TSpoolSpec; I: Integer): Double;
begin
  Result := 0;
  if (I < 0) or (I >= High(S.Legs)) then Exit;
  Result := ArcCos(EnsureRange(Dot3(S.Legs[I].Dir, S.Legs[I + 1].Dir), -1.0, 1.0));
  if Result < 1E-6 then Result := 0;
end;

function TakeOut(const S: TSpoolSpec; Turn: Double): Double;
begin
  if Turn <= 0 then Result := 0
  else Result := ElbowRadius(S) * Tan(Turn / 2);
end;

function TakeOutBefore(const S: TSpoolSpec; I: Integer): Double;
begin
  if I <= 0 then Result := 0 else Result := TakeOut(S, TurnAfter(S, I - 1));
end;

function TakeOutAfterLeg(const S: TSpoolSpec; I: Integer): Double;
begin
  if I >= High(S.Legs) then Result := 0 else Result := TakeOut(S, TurnAfter(S, I));
end;

function CCLength(const S: TSpoolSpec; I: Integer): Double;
begin
  Result := S.Legs[I].Len;
  if S.Legs[I].FromEnd then Result := Result + TakeOutBefore(S, I);
  if S.Legs[I].ToEnd then Result := Result + TakeOutAfterLeg(S, I);
end;

function CutLength(const S: TSpoolSpec; I: Integer): Double;
begin
  Result := CCLength(S, I) - TakeOutBefore(S, I) - TakeOutAfterLeg(S, I);
end;

function SketchComplete(const S: TSpoolSpec): Boolean;
var
  I: Integer;
begin
  Result := Length(S.Legs) > 0;
  for I := 0 to High(S.Legs) do
    if not S.Legs[I].Has or (S.Legs[I].Len <= 0) then Exit(False);
end;

function MeasureWords(const S: TSpoolSpec; I: Integer): string;
  function EndWord(AtStart: Boolean): string;
  begin
    if AtStart and (I = 0) and (S.Ends[0] = peFlange) then Exit('face');
    if (not AtStart) and (I = High(S.Legs)) and (S.Ends[1] = peFlange) then Exit('face');
    Result := 'end';
  end;
begin
  if S.Legs[I].FromEnd then Result := EndWord(True) else Result := 'center';
  Result := Result + ' to ';
  if S.Legs[I].ToEnd then Result := Result + EndWord(False) else Result := Result + 'center';
end;

function SpoolProblem(const S: TSpoolSpec): string;
var
  I: Integer;
begin
  Result := '';
  if Length(S.Legs) = 0 then Exit('Draw the run: at least one leg with a length on it.');
  for I := 0 to High(S.Legs) do
  begin
    if not S.Legs[I].Has then Exit(Format('Leg %d has no length yet.', [I + 1]));
    if S.Legs[I].Len <= 0 then Exit(Format('Leg %d needs a length.', [I + 1]));
    if Dist(S.Legs[I].Dir, P3(0, 0, 0)) < 1E-9 then Exit(Format('Leg %d has no direction.', [I + 1]));
  end;
  for I := 0 to High(S.Legs) - 1 do
    if TurnAfter(S, I) > Pi - 1E-6 then
      Exit(Format('Legs %d and %d double straight back on each other.', [I + 1, I + 2]));
  for I := 0 to High(S.Legs) do
    if CutLength(S, I) < -1E-9 then
      Exit(Format('Leg %d is shorter than its elbows take out - it needs at least %s center to center.',
        [I + 1, FormatFloat('0.##', (CCLength(S, I) - CutLength(S, I)) / Inch(S)) + '"']));
end;

procedure SpoolPath(const S: TSpoolSpec; out Pts: TP3Array);
var
  I, K, N: Integer;
  P, A, B, T1, T2, O, Nrm, W, Rv: TP3;
  Turn, T, R: Double;

  procedure Put(const Q: TP3);
  begin
    if (Length(Pts) > 0) and (Dist(Pts[High(Pts)], Q) < 1E-9) then Exit;
    SetLength(Pts, Length(Pts) + 1);
    Pts[High(Pts)] := Q;
  end;

begin
  Pts := nil;
  if Length(S.Legs) = 0 then Exit;
  R := ElbowRadius(S);
  P := P3(0, 0, 0);
  Put(P);
  for I := 0 to High(S.Legs) do
  begin
    A := Norm3(S.Legs[I].Dir);
    P := P3(P.X + A.X * CCLength(S, I), P.Y + A.Y * CCLength(S, I), P.Z + A.Z * CCLength(S, I));
    Turn := TurnAfter(S, I);
    if (I = High(S.Legs)) or (Turn <= 0) then
    begin
      Put(P);
      Continue;
    end;
    { the bend: back off both legs by the take-out, then the arc between }
    B := Norm3(S.Legs[I + 1].Dir);
    T := TakeOut(S, Turn);
    T1 := P3(P.X - A.X * T, P.Y - A.Y * T, P.Z - A.Z * T);
    T2 := P3(P.X + B.X * T, P.Y + B.Y * T, P.Z + B.Z * T);
    Nrm := Norm3(P3(B.X - A.X * Dot3(A, B), B.Y - A.Y * Dot3(A, B), B.Z - A.Z * Dot3(A, B)));
    O := P3(T1.X + Nrm.X * R, T1.Y + Nrm.Y * R, T1.Z + Nrm.Z * R);
    W := Norm3(Cross3(A, B));
    Rv := P3(T1.X - O.X, T1.Y - O.Y, T1.Z - O.Z);
    N := Max(2, Round(Turn / (Pi / 12)));
    for K := 0 to N do
    begin
      Put(P3(O.X + RotV(Rv, W, Turn * K / N).X, O.Y + RotV(Rv, W, Turn * K / N).Y,
             O.Z + RotV(Rv, W, Turn * K / N).Z));
    end;
    Put(T2);
  end;
end;

function BuildSpool(D: TWorkDoc; const S: TSpoolSpec; Ink: TColor; Weight: Single): Integer;
var
  Path, Circle: TP3Array;
  G, I, K, Face, First: Integer;
  A, U, V, Off, P0, P1: TP3;
  OD, FOD: Double;

  { a circle of diameter Dia square to direction Dir at point At }
  procedure CircleAt(const At, Dir: TP3; Dia: Double; out Pts: TP3Array);
  var
    K: Integer;
    Ang: Double;
  begin
    AxesFromNormal(Norm3(Dir), U, V);
    SetLength(Pts, PIPE_SIDES);
    for K := 0 to PIPE_SIDES - 1 do
    begin
      Ang := 2 * Pi * K / PIPE_SIDES;
      Pts[K] := P3(At.X + (U.X * Cos(Ang) + V.X * Sin(Ang)) * Dia / 2,
                   At.Y + (U.Y * Cos(Ang) + V.Y * Sin(Ang)) * Dia / 2,
                   At.Z + (U.Z * Cos(Ang) + V.Z * Sin(Ang)) * Dia / 2);
    end;
  end;

  procedure Disc(const At, Dir: TP3; Dia, Thick: Double);
  var
    Pts, Two: TP3Array;
    F: Integer;
  begin
    CircleAt(At, Dir, Dia, Pts);
    D.AddFaceRaw(Pts, Ink, False);
    F := D.Live - 1;
    SetLength(Two, 2);
    Two[0] := At;
    Two[1] := P3(At.X + Dir.X * Thick, At.Y + Dir.Y * Thick, At.Z + Dir.Z * Thick);
    D.Sweep(F, Two, False, True);
  end;

  procedure Regroup;
  var
    I: Integer;
  begin
    for I := First to D.Live - 1 do
      if D[I].Kind = ekFace then D.SetFaceGroup(I, G) else D.SetGroup(I, G);
  end;

begin
  Result := -1;
  if SpoolProblem(S) <> '' then Exit;
  SpoolPath(S, Path);
  if Length(Path) < 2 then Exit;
  First := D.Live;
  G := D.NewGroup;
  OD := NPS_OD[EnsureRange(S.Size, 0, High(NPS_OD))] * Inch(S);
  { the pipe: a circle pushed along the centerline, open at both ends }
  A := Norm3(S.Legs[0].Dir);
  CircleAt(Path[0], A, OD, Circle);
  D.AddFaceRaw(Circle, Ink, False);
  Face := D.Live - 1;
  D.Sweep(Face, Path, False, False);
  { the ends }
  FOD := NPS_FLANGE_OD[EnsureRange(S.Size, 0, High(NPS_FLANGE_OD))] * Inch(S);
  P0 := Path[0];
  P1 := Path[High(Path)];
  case S.Ends[0] of
    peFlange: Disc(P0, A, FOD, FLANGE_THICK_IN * Inch(S));
    peCap:
      begin
        CircleAt(P0, A, OD, Circle);
        D.AddFaceRaw(Circle, Ink, True);
      end;
  end;
  A := Norm3(S.Legs[High(S.Legs)].Dir);
  case S.Ends[1] of
    peFlange: Disc(P3(P1.X - A.X * FLANGE_THICK_IN * Inch(S), P1.Y - A.Y * FLANGE_THICK_IN * Inch(S),
                      P1.Z - A.Z * FLANGE_THICK_IN * Inch(S)), A, FOD, FLANGE_THICK_IN * Inch(S));
    peCap:
      begin
        CircleAt(P1, A, OD, Circle);
        D.AddFaceRaw(Circle, Ink, True);
      end;
  end;
  Regroup;
  { the name, above the start }
  if S.Tag <> '' then
  begin
    D.AddText(P3(P0.X, P0.Y, P0.Z + OD * 1.5), S.Tag, Ink);
    D.SetGroup(D.Live - 1, G);
  end;
  { the lengths the fitter wrote, center to center, beside each leg }
  if S.Dims then
  begin
    P0 := P3(0, 0, 0);
    for I := 0 to High(S.Legs) do
    begin
      A := Norm3(S.Legs[I].Dir);
      P1 := P3(P0.X + A.X * CCLength(S, I), P0.Y + A.Y * CCLength(S, I), P0.Z + A.Z * CCLength(S, I));
      if Abs(A.Z) < 0.9 then Off := Norm3(Cross3(A, P3(0, 0, 1))) else Off := P3(1, 0, 0);
      Off := P3(Off.X * OD * 1.5, Off.Y * OD * 1.5, Off.Z * OD * 1.5);
      D.AddDim(P0, P1, Ink, Off);
      D.SetGroup(D.Live - 1, G);
      P0 := P1;
    end;
  end;
  Result := First;
end;

function DirName(const Dir: TP3): string;
var
  D: TP3;
  Parts: string;
  procedure Part(V: Double; const Pos, Neg: string);
  begin
    if V > 0.3 then Parts := Parts + Pos + ' '
    else if V < -0.3 then Parts := Parts + Neg + ' ';
  end;
begin
  D := Norm3(Dir);
  Parts := '';
  Part(D.Z, 'up', 'down');
  Part(D.X, 'right', 'left');
  Part(D.Y, 'away', 'towards you');
  Result := Trim(Parts);
  if (Abs(D.X) > 0.3) and (Abs(D.Y) > 0.3) or (Abs(D.X) > 0.3) and (Abs(D.Z) > 0.3) or
     (Abs(D.Y) > 0.3) and (Abs(D.Z) > 0.3) then
    Result := Result + ' (45)';
end;

function SpoolTicket(const S: TSpoolSpec): string;
var
  I, N90, N45, NOther: Integer;
  Turn, Total: Double;
  function Ins(V: Double): string;
  begin
    Result := FormatFloat('0.###', V / Inch(S)) + '"';
  end;
begin
  Result := 'Pipe spool';
  if S.Tag <> '' then Result := Result + ': ' + S.Tag;
  Result := Result + LineEnding +
    'Pipe: ' + NPS_NAMES[EnsureRange(S.Size, 0, High(NPS_NAMES))] + ' NPS, OD ' +
      FormatFloat('0.###', NPS_OD[EnsureRange(S.Size, 0, High(NPS_OD))]) + '"' + LineEnding +
    'Elbows: ';
  if S.LongRadius then Result := Result + 'long radius (1.5 D), R = '
  else Result := Result + 'short radius (1 D), R = ';
  Result := Result + Ins(ElbowRadius(S)) + LineEnding +
    'Start end: ' + PIPE_END_NAMES[S.Ends[0]] + LineEnding +
    'Far end: ' + PIPE_END_NAMES[S.Ends[1]] + LineEnding + LineEnding +
    'Legs, as measured, then center to center, then the cut length:' + LineEnding;
  Total := 0;
  for I := 0 to High(S.Legs) do
  begin
    if S.Legs[I].Has then
      Result := Result + Format('  %d. %s  %s %s  (c-c %s, cut %s)', [I + 1, DirName(S.Legs[I].Dir),
        Ins(S.Legs[I].Len), MeasureWords(S, I), Ins(CCLength(S, I)), Ins(Max(0, CutLength(S, I)))])
    else
      Result := Result + Format('  %d. %s  ? - no length yet', [I + 1, DirName(S.Legs[I].Dir)]);
    if I < High(S.Legs) then
    begin
      Turn := TurnAfter(S, I);
      if Turn > 0 then
        Result := Result + Format('  then a %s elbow', [FormatFloat('0.#', RadToDeg(Turn))]);
    end;
    Result := Result + LineEnding;
    if S.Legs[I].Has then Total := Total + CCLength(S, I);
  end;
  N90 := 0; N45 := 0; NOther := 0;
  for I := 0 to High(S.Legs) - 1 do
  begin
    Turn := TurnAfter(S, I);
    if Turn <= 0 then Continue;
    if Abs(RadToDeg(Turn) - 90) < 0.5 then Inc(N90)
    else if Abs(RadToDeg(Turn) - 45) < 0.5 then Inc(N45)
    else Inc(NOther);
  end;
  Result := Result + LineEnding + Format('Fittings: %d x 90, %d x 45', [N90, N45]);
  if NOther > 0 then Result := Result + Format(', %d other', [NOther]);
  if S.Ends[0] = peFlange then Result := Result + ', flange at the start';
  if S.Ends[1] = peFlange then Result := Result + ', flange at the far end';
  Result := Result + LineEnding + 'Center-to-center total: ' + Ins(Total) + LineEnding;
end;

end.
