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
  TIntArrayW = uWork.TIntArrayW;

type
  TPipeEnd = (peBevel, peFlange, peCap, peThread);
  { what sits at the far end of a leg, before the elbow if there is one }
  TLegAfter = (laNothing, laReducer, laFlanges);

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
    After: TLegAfter;   { a reducer or a pair of flanges at the far end }
    NewSize: Integer;   { the size a reducer goes to, an NPS index }
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
  LEG_AFTER_NAMES: array[TLegAfter] of string = ('nothing after it', 'a reducer to...',
    'a flanged joint');
  { concentric reducer lengths by the larger size, near enough to B16.9 }
  NPS_REDUCER_LEN: array[0..12] of Double = (1.5, 1.5, 2, 2, 2.5, 3, 3.5, 3.5, 4, 5.5, 6, 7, 8);
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
{ the pipe size in force on leg I, reducers before it counted }
function SizeOfLeg(const S: TSpoolSpec; I: Integer): Integer;
{ how long the fitting after leg I is along the run, 0 for none }
function AfterLength(const S: TSpoolSpec; I: Integer): Double;
{ the measurement in the fitter's words: center to center, end to center... }
function MeasureWords(const S: TSpoolSpec; I: Integer): string;
{ what is wrong, or '' }
function SpoolProblem(const S: TSpoolSpec): string;
{ the centerline: straight legs with the bends drawn in as arcs.  Where a
  leg carries a reducer or a flanged joint the path is cut there, and Kind
  says what each point starts: 0 pipe at the size in Size, 1 a reducer, 2 a
  flanged joint. }
procedure SpoolPath(const S: TSpoolSpec; out Pts: TP3Array);
procedure SpoolPathFull(const S: TSpoolSpec; out Pts: TP3Array; out Kind, Size: TIntArrayW);
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

function SizeOfLeg(const S: TSpoolSpec; I: Integer): Integer;
var
  K: Integer;
begin
  Result := S.Size;
  for K := 0 to Min(I - 1, High(S.Legs)) do
    if S.Legs[K].After = laReducer then Result := EnsureRange(S.Legs[K].NewSize, 0, High(NPS_OD));
end;

function AfterLength(const S: TSpoolSpec; I: Integer): Double;
var
  Big: Integer;
begin
  Result := 0;
  if (I < 0) or (I > High(S.Legs)) then Exit;
  case S.Legs[I].After of
    laReducer:
      begin
        Big := Max(SizeOfLeg(S, I), EnsureRange(S.Legs[I].NewSize, 0, High(NPS_OD)));
        Result := NPS_REDUCER_LEN[Big] * Inch(S);
      end;
    laFlanges: Result := 2 * FLANGE_THICK_IN * Inch(S);
  end;
end;

function CutLength(const S: TSpoolSpec; I: Integer): Double;
begin
  Result := CCLength(S, I) - TakeOutBefore(S, I) - TakeOutAfterLeg(S, I);
  { a reducer at the end of the leg is its own piece; a flanged joint is a
    flange on each side of the break }
  case S.Legs[I].After of
    laReducer: Result := Result - AfterLength(S, I);
    laFlanges: Result := Result - FLANGE_THICK_IN * Inch(S);
  end;
  if (I > 0) and (S.Legs[I - 1].After = laFlanges) then
    Result := Result - FLANGE_THICK_IN * Inch(S);
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
      Exit(Format('Leg %d is shorter than its fittings take out - it needs at least %s center to center.',
        [I + 1, FormatFloat('0.##', (CCLength(S, I) - CutLength(S, I)) / Inch(S)) + '"']));
  for I := 0 to High(S.Legs) do
    if (S.Legs[I].After = laReducer) and (S.Legs[I].NewSize = SizeOfLeg(S, I)) then
      Exit(Format('The reducer after leg %d goes to the same size - pick another.', [I + 1]));
end;

procedure SpoolPath(const S: TSpoolSpec; out Pts: TP3Array);
var
  Kind, Size: TIntArrayW;
begin
  SpoolPathFull(S, Pts, Kind, Size);
end;

procedure SpoolPathFull(const S: TSpoolSpec; out Pts: TP3Array; out Kind, Size: TIntArrayW);
var
  I, K, N, CurKind, CurSize: Integer;
  P, A, B, T1, T2, O, Nrm, W, Rv, F0, F1: TP3;
  Turn, T, R, Fl: Double;

  procedure Put(const Q: TP3);
  begin
    if (Length(Pts) > 0) and (Dist(Pts[High(Pts)], Q) < 1E-9) then
    begin
      { the same point again only changes what starts there }
      Kind[High(Kind)] := CurKind;
      Size[High(Size)] := CurSize;
      Exit;
    end;
    SetLength(Pts, Length(Pts) + 1);
    Pts[High(Pts)] := Q;
    SetLength(Kind, Length(Pts));
    SetLength(Size, Length(Pts));
    Kind[High(Kind)] := CurKind;
    Size[High(Size)] := CurSize;
  end;

begin
  Pts := nil; Kind := nil; Size := nil;
  if Length(S.Legs) = 0 then Exit;
  R := ElbowRadius(S);
  P := P3(0, 0, 0);
  CurKind := 0;
  CurSize := S.Size;
  Put(P);
  for I := 0 to High(S.Legs) do
  begin
    A := Norm3(S.Legs[I].Dir);
    CurSize := SizeOfLeg(S, I);
    P := P3(P.X + A.X * CCLength(S, I), P.Y + A.Y * CCLength(S, I), P.Z + A.Z * CCLength(S, I));
    Turn := TurnAfter(S, I);
    { the fitting at the far end sits before the elbow's take-out }
    Fl := AfterLength(S, I);
    if Fl > 0 then
    begin
      T := TakeOutAfterLeg(S, I);
      F1 := P3(P.X - A.X * T, P.Y - A.Y * T, P.Z - A.Z * T);
      F0 := P3(F1.X - A.X * Fl, F1.Y - A.Y * Fl, F1.Z - A.Z * Fl);
      Put(F0);
      if S.Legs[I].After = laReducer then CurKind := 1 else CurKind := 2;
      Put(F0);
      CurKind := 0;
      if S.Legs[I].After = laReducer then CurSize := SizeOfLeg(S, I + 1);
      Put(F1);
    end;
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
  Path, Circle, Run: TP3Array;
  Kind, Size: TIntArrayW;
  G, I, K, Face, First, RunStart, RunEnd: Integer;
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

  { a reducer: a ring of the big size at P0 down to a ring of the small at
    P1, a quad between each pair of points, wound outward }
  procedure Frustum(const P0, P1, Dir: TP3; DiaA, DiaB: Double);
  var
    RA, RB: TP3Array;
    K, K2, F: Integer;
    Mid, Cen: TP3;
  begin
    CircleAt(P0, Dir, DiaA, RA);
    CircleAt(P1, Dir, DiaB, RB);
    Cen := P3((P0.X + P1.X) / 2, (P0.Y + P1.Y) / 2, (P0.Z + P1.Z) / 2);
    for K := 0 to PIPE_SIDES - 1 do
    begin
      K2 := (K + 1) mod PIPE_SIDES;
      D.AddFaceRaw([RA[K], RA[K2], RB[K2], RB[K]], Ink, True);
      F := D.Live - 1;
      Mid := P3((RA[K].X + RB[K2].X) / 2 - Cen.X, (RA[K].Y + RB[K2].Y) / 2 - Cen.Y,
                (RA[K].Z + RB[K2].Z) / 2 - Cen.Z);
      if Dot3(D.FaceNormal(F), Mid) < 0 then D.FlipFace(F);
      D.AddLine(RA[K], RB[K], Ink, Weight, False);
      D.SetSoft(D.Live - 1, True);
    end;
    for K := 0 to PIPE_SIDES - 1 do
    begin
      D.AddLine(RA[K], RA[(K + 1) mod PIPE_SIDES], Ink, Weight, False);
      D.AddLine(RB[K], RB[(K + 1) mod PIPE_SIDES], Ink, Weight, False);
    end;
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
  SpoolPathFull(S, Path, Kind, Size);
  if Length(Path) < 2 then Exit;
  First := D.Live;
  G := D.NewGroup;
  OD := NPS_OD[EnsureRange(S.Size, 0, High(NPS_OD))] * Inch(S);
  { the pipe: a circle pushed along the centerline, open at both ends -
    one run per size, with a reducer or a flanged joint between runs }
  RunStart := 0;
  for I := 1 to High(Path) do
    if (Kind[I] <> 0) or (I = High(Path)) then
    begin
      if I = High(Path) then RunEnd := I else RunEnd := I;
      if RunEnd > RunStart then
      begin
        SetLength(Run, RunEnd - RunStart + 1);
        for K := RunStart to RunEnd do Run[K - RunStart] := Path[K];
        A := Norm3(P3(Run[1].X - Run[0].X, Run[1].Y - Run[0].Y, Run[1].Z - Run[0].Z));
        CircleAt(Run[0], A, NPS_OD[EnsureRange(Size[RunStart], 0, High(NPS_OD))] * Inch(S), Circle);
        D.AddFaceRaw(Circle, Ink, False);
        Face := D.Live - 1;
        D.Sweep(Face, Run, False, False);
      end;
      if (Kind[I] <> 0) and (I < High(Path)) then
      begin
        A := Norm3(P3(Path[I + 1].X - Path[I].X, Path[I + 1].Y - Path[I].Y, Path[I + 1].Z - Path[I].Z));
        if Kind[I] = 1 then
          Frustum(Path[I], Path[I + 1], A, NPS_OD[EnsureRange(Size[I - 1], 0, High(NPS_OD))] * Inch(S),
            NPS_OD[EnsureRange(Size[I + 1], 0, High(NPS_OD))] * Inch(S))
        else
        begin
          FOD := NPS_FLANGE_OD[EnsureRange(Size[I], 0, High(NPS_FLANGE_OD))] * Inch(S);
          Disc(Path[I], A, FOD, FLANGE_THICK_IN * Inch(S));
          Disc(P3(Path[I].X + A.X * FLANGE_THICK_IN * Inch(S), Path[I].Y + A.Y * FLANGE_THICK_IN * Inch(S),
                  Path[I].Z + A.Z * FLANGE_THICK_IN * Inch(S)), A, FOD, FLANGE_THICK_IN * Inch(S));
        end;
        RunStart := I + 1;
      end;
    end;
  { the ends }
  FOD := NPS_FLANGE_OD[EnsureRange(S.Size, 0, High(NPS_FLANGE_OD))] * Inch(S);
  P0 := Path[0];
  P1 := Path[High(Path)];
  A := Norm3(S.Legs[0].Dir);
  case S.Ends[0] of
    peFlange: Disc(P0, A, FOD, FLANGE_THICK_IN * Inch(S));
    peCap:
      begin
        CircleAt(P0, A, OD, Circle);
        D.AddFaceRaw(Circle, Ink, True);
      end;
  end;
  A := Norm3(S.Legs[High(S.Legs)].Dir);
  OD := NPS_OD[SizeOfLeg(S, High(S.Legs))] * Inch(S);
  FOD := NPS_FLANGE_OD[SizeOfLeg(S, High(S.Legs))] * Inch(S);
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
    case S.Legs[I].After of
      laReducer: Result := Result + Format('  then a %s x %s reducer, %s long',
        [NPS_NAMES[SizeOfLeg(S, I)], NPS_NAMES[EnsureRange(S.Legs[I].NewSize, 0, High(NPS_NAMES))],
         Ins(AfterLength(S, I))]);
      laFlanges: Result := Result + '  then a flanged joint';
    end;
    if I < High(S.Legs) then
    begin
      Turn := TurnAfter(S, I);
      if Turn > 0 then
        Result := Result + Format('  then a %s %s elbow',
          [NPS_NAMES[SizeOfLeg(S, I + 1)], FormatFloat('0.#', RadToDeg(Turn))]);
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
  N90 := 0; N45 := 0;
  for I := 0 to High(S.Legs) do
    if S.Legs[I].After = laReducer then Inc(N90)
    else if S.Legs[I].After = laFlanges then Inc(N45);
  if N90 > 0 then Result := Result + Format(', %d reducer%s', [N90, Copy('s', 1, Ord(N90 > 1))]);
  if N45 > 0 then Result := Result + Format(', %d flanged joint%s', [N45, Copy('s', 1, Ord(N45 > 1))]);
  if S.Ends[0] = peFlange then Result := Result + ', flange at the start';
  if S.Ends[1] = peFlange then Result := Result + ', flange at the far end';
  Result := Result + LineEnding + 'Center-to-center total: ' + Ins(Total) + LineEnding;
end;

end.
