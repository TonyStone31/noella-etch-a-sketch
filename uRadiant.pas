unit uRadiant;

{ The radiant heat layout tool: given the outline of a floor - a rectangle,
  or any closed face with as many corners as the room has - and one point
  for the manifold, fill it with tube.

  What "fill it with tube" means here is a coverage path, the same problem
  a robot lawnmower or a crop sprayer solves: cover a bounded area with
  parallel passes at a fixed spacing, in the fewest and straightest moves,
  never leaving a strip uncovered.  A round trip from a manifold and back
  is that problem with the extra rule that it has to end where it began.

  The area is cut into rows at the tube's spacing.  Each row is a lane;
  where a hole in the selected face - an elevator shaft, a column, a
  chase - crosses a lane, the lane is cut around it, the way a hole
  already cuts a lane out of a face's own area everywhere else in this
  program.  What is left is a set of short straight spans.  The tube is
  then walked spans in the order that keeps it moving forward: from
  wherever it is, to the nearest end of whichever span it has not yet
  covered.  That is greedy nearest-neighbor routing, not a search over
  every possible order - a true shortest round trip over disconnected
  spans is the traveling salesman problem, which does not have a fast
  exact answer for a floor with any real number of spans in it.  Greedy
  is not blind, though: on an open floor with no obstacles it finds
  exactly the serpentine a person would draw by hand, because the
  nearest unwalked span is always the next row over.  Where a hole
  breaks that up, it reaches for whichever piece is closest, which is
  the same thing a person walking the floor with a tape measure would
  do.

  A loop over 300 feet of 1/2" tube runs too much pressure drop to heat
  evenly - see uRadiantData for the whole table, by tube size.  So one
  walk of the whole floor is cut into pieces at row boundaries - never
  through the middle of a lane - sized to come in under the limit and
  close to even with each other, the way a real design keeps circuits
  within about ten percent of one another so the manifold's balancing
  valves are not doing all the work alone.  Cut in half, that is also
  what a big room "navigated from two ends" looks like: one loop serving
  the near half, one the far half, both starting and ending at the same
  manifold.

  A layout that looks wrong in one spot does not have to be thrown out
  whole.  A temporary obstacle - drawn the same way a real one is read,
  as a hole, but kept only in the dialog and never written to the sheet
  unless the person asks - routes the walk around whatever was circled,
  and the rest of the floor is free to be laid out again around it.

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, Math, Graphics, uWork, uRadiantData;

type
  TRadiantSpec = record
    Floor: TRadiantFloor;
    Tube: TTubeSize;
    Spacing: Double;          { world units (feet) - on center }
    MaxLoopFt: Double;        { 0 = the tube's own table maximum }
    WastePct: Double;
    { the manifold: which corner of the outline (index into it, as read),
      and how far in from it along the two edges that meet there }
    Corner: Integer;
    InAlong, InAcross: Double;
    ManifoldW, ManifoldH: Double;   { the little box drawn for it }
    { concrete slab }
    SlabThick: Double;
    TubeDepth: Double;        { 0 = centered in the slab }
    UnderR: Double;
    { wood floor - staple-up or plated }
    JoistSpacing: Double;
    Plates: Boolean;
    SubfloorThick: Double;
    BelowR: Double;
    Tag: string;
    Inch: Double;             { the drawing's own inch, as TTransitionSpec keeps it }
  end;

  TRadiantLoop = record
    Pts: TP3Array;             { the centerline, manifold to manifold }
    LenFt: Double;
  end;
  TRadiantLoopArray = array of TRadiantLoop;

  TRadiantResult = record
    Loops: TRadiantLoopArray;
    Manifold: TP3;
    AreaSqFt: Double;
    RowCount: Integer;
    ObstacleCount: Integer;
    TotalFt: Double;           { every loop, no waste }
    OrderFt: Double;           { with waste, rounded up }
    { the tightest turn the layout asks the tube to make, and the tube's
      own minimum - if Actual < Min, the spacing is tighter than the tube
      can turn on every row, and RowStep says how many rows it actually
      turns on instead (1 = every row) }
    TurnActualIn, TurnMinIn: Double;
    RowStep: Integer;
    Ok: Boolean;
    Why: string;
  end;

function DefaultRadiantSpec: TRadiantSpec;

{ The manifold's own point: at the outline's chosen corner, in from it
  along the two edges that meet there.  Shared by the dialog's live
  preview and the real build, so the two can never disagree about where
  it sits. }
function RadiantManifoldPoint(const Outline: TP3Array; const Spec: TRadiantSpec): TP3;

{ What is wrong with the spec against this outline, or '' when it is fit to
  build.  Checked before the layout is worked out, so a bad number says so
  in words instead of an empty floor. }
function RadiantProblem(const Outline: TP3Array; const Spec: TRadiantSpec): string;

{ The layout itself - pure geometry, nothing written to a drawing, so the
  dialog's live preview and the real build call the same code and can
  never disagree.  Holes are the obstacles: a solid's own (an elevator
  shaft, a column) and, appended to them, whatever the dialog is trying
  as a temporary one while the person tries a different route. }
function ComputeRadiantLayout(const Outline: TP3Array; const Holes: array of TP3Array;
  const Manifold: TP3; const Spec: TRadiantSpec): TRadiantResult;

{ Writes the result into the drawing as one part per loop, soft lines on
  their own tube-run ink, and a note on every hole that was routed
  around.  Returns the first entity added. }
function BuildRadiant(D: TWorkDoc; const Outline: TP3Array; const Holes: array of TP3Array;
  const R: TRadiantResult; const Spec: TRadiantSpec; Ink: TColor; PartName: string): Integer;

{ The material list and the numbers behind it, as words - the ticket. }
function RadiantTicketText(const Spec: TRadiantSpec; const R: TRadiantResult;
  U: TUnitSystem): string;

implementation

type
  { the floor's own plane, worked in Double throughout - a barn's worth of
    floor at sub-inch accuracy wants better than the Single precision the
    LCL's own TPointF carries for pixels }
  T2 = record X, Y: Double; end;
  TSpan = record Lo, Hi: Double; end;
  TSpanArray = array of TSpan;

function Point2(X, Y: Double): T2;
begin
  Result.X := X; Result.Y := Y;
end;

{ ---------------------------------------------------------------------- }
{ the plane the outline lies in, and a 2D frame inside it                }
{ ---------------------------------------------------------------------- }

function Newell(const L: TP3Array): TP3;
var
  I, J, N: Integer;
begin
  Result := P3(0, 0, 0);
  N := Length(L);
  for I := 0 to N - 1 do
  begin
    J := (I + 1) mod N;
    Result.X := Result.X + (L[I].Y - L[J].Y) * (L[I].Z + L[J].Z);
    Result.Y := Result.Y + (L[I].Z - L[J].Z) * (L[I].X + L[J].X);
    Result.Z := Result.Z + (L[I].X - L[J].X) * (L[I].Y + L[J].Y);
  end;
end;

function VNorm(const P: TP3): TP3;
var
  L: Double;
begin
  L := Sqrt(P.X * P.X + P.Y * P.Y + P.Z * P.Z);
  if L < 1E-12 then Exit(P3(0, 0, 0));
  Result := P3(P.X / L, P.Y / L, P.Z / L);
end;

type
  TFrame = record
    Origin: TP3;
    U, V, N: TP3;
  end;

{ the outline's own plane: the origin its first corner, U along its
  longest edge, so a rectangle is filled the way a person would - tube
  parallel to the long wall - and V and N at right angles to it }
function FrameOf(const Outline: TP3Array): TFrame;
var
  I, J, Best: Integer;
  L, BestL: Double;
begin
  Result.Origin := Outline[0];
  Result.N := VNorm(Newell(Outline));
  BestL := -1; Best := 0;
  for I := 0 to High(Outline) do
  begin
    J := (I + 1) mod Length(Outline);
    L := Dist(Outline[I], Outline[J]);
    if L > BestL then begin BestL := L; Best := I; end;
  end;
  J := (Best + 1) mod Length(Outline);
  Result.U := VNorm(P3(Outline[J].X - Outline[Best].X, Outline[J].Y - Outline[Best].Y,
    Outline[J].Z - Outline[Best].Z));
  Result.V := VNorm(Cross3(Result.N, Result.U));
end;

function To2(const F: TFrame; const P: TP3): T2;
var
  D: TP3;
begin
  D := P3(P.X - F.Origin.X, P.Y - F.Origin.Y, P.Z - F.Origin.Z);
  Result.X := Dot3(D, F.U);
  Result.Y := Dot3(D, F.V);
end;

function From2(const F: TFrame; U, V: Double): TP3;
begin
  Result := P3(F.Origin.X + F.U.X * U + F.V.X * V,
               F.Origin.Y + F.U.Y * U + F.V.Y * V,
               F.Origin.Z + F.U.Z * U + F.V.Z * V);
end;

{ ---------------------------------------------------------------------- }
{ one row: the spans a horizontal line at V crosses inside a 2D polygon  }
{ ---------------------------------------------------------------------- }

function RowSpans(const Poly: array of T2; V: Double): TSpanArray;
var
  I, J, N, K, M: Integer;
  Xs: array of Double;
  A, B, T: Double;
begin
  SetLength(Result, 0);
  N := Length(Poly);
  if N < 3 then Exit;
  SetLength(Xs, 0);
  for I := 0 to N - 1 do
  begin
    J := (I + 1) mod N;
    { half-open on the low end so a corner sitting exactly on the row is
      never counted by both the edge above it and the edge below }
    if ((Poly[I].Y <= V) and (Poly[J].Y > V)) or ((Poly[J].Y <= V) and (Poly[I].Y > V)) then
    begin
      T := (V - Poly[I].Y) / (Poly[J].Y - Poly[I].Y);
      SetLength(Xs, Length(Xs) + 1);
      Xs[High(Xs)] := Poly[I].X + T * (Poly[J].X - Poly[I].X);
    end;
  end;
  { insertion sort - a row rarely crosses more than a handful of edges }
  for I := 1 to High(Xs) do
  begin
    T := Xs[I]; K := I;
    while (K > 0) and (Xs[K - 1] > T) do begin Xs[K] := Xs[K - 1]; Dec(K); end;
    Xs[K] := T;
  end;
  M := (Length(Xs) div 2) * 2;
  SetLength(Result, M div 2);
  for I := 0 to M div 2 - 1 do
  begin
    A := Xs[I * 2]; B := Xs[I * 2 + 1];
    Result[I].Lo := A; Result[I].Hi := B;
  end;
end;

{ Outer spans, less whatever the hole spans cover - interval subtraction.
  Both arrays are sorted low to high and do not overlap themselves, which
  RowSpans already guarantees. }
function Subtract(const Outer: TSpanArray; const Cuts: TSpanArray): TSpanArray;
var
  I, J, N: Integer;
  Lo: Double;
  Piece: TSpan;
begin
  SetLength(Result, 0);
  N := 0;
  for I := 0 to High(Outer) do
  begin
    Lo := Outer[I].Lo;
    for J := 0 to High(Cuts) do
    begin
      if (Cuts[J].Hi <= Lo) or (Cuts[J].Lo >= Outer[I].Hi) then Continue;
      if Cuts[J].Lo > Lo then
      begin
        Piece.Lo := Lo; Piece.Hi := Cuts[J].Lo;
        SetLength(Result, N + 1); Result[N] := Piece; Inc(N);
      end;
      Lo := Max(Lo, Cuts[J].Hi);
    end;
    if Lo < Outer[I].Hi then
    begin
      Piece.Lo := Lo; Piece.Hi := Outer[I].Hi;
      SetLength(Result, N + 1); Result[N] := Piece; Inc(N);
    end;
  end;
end;

{ ---------------------------------------------------------------------- }
{ the walk: every span, in the order that keeps the tube moving forward  }
{ ---------------------------------------------------------------------- }

type
  TWalkSpan = record
    V: Double;
    Lo, Hi: Double;
    { which end was walked from - so the point list comes out in order }
  end;

{ Greedy nearest-end routing over every span on every row, starting from
  Start.  Returns the walk as a flat list of 2D points, and the point it
  ended on. }
procedure WalkSpans(const Rows: array of Double; const RowSpanList: array of TSpanArray;
  Start: T2; var Pts: array of T2; out NPts: Integer; out EndAt: T2);
var
  Total, Done, I, J, BestI, BestJ: Integer;
  Visited: array of array of Boolean;
  Cur: T2;
  D0, D1, BestD: Double;
  FromLo: Boolean;
begin
  NPts := 0;
  Cur := Start;
  Total := 0;
  SetLength(Visited, Length(Rows));
  for I := 0 to High(Rows) do
  begin
    SetLength(Visited[I], Length(RowSpanList[I]));
    Inc(Total, Length(RowSpanList[I]));
  end;
  Done := 0;
  while Done < Total do
  begin
    BestD := 1E30; BestI := -1; BestJ := -1; FromLo := True;
    for I := 0 to High(Rows) do
      for J := 0 to High(RowSpanList[I]) do
        if not Visited[I][J] then
        begin
          D0 := Sqr(RowSpanList[I][J].Lo - Cur.X) + Sqr(Rows[I] - Cur.Y);
          D1 := Sqr(RowSpanList[I][J].Hi - Cur.X) + Sqr(Rows[I] - Cur.Y);
          if D0 < BestD then begin BestD := D0; BestI := I; BestJ := J; FromLo := True; end;
          if D1 < BestD then begin BestD := D1; BestI := I; BestJ := J; FromLo := False; end;
        end;
    if BestI < 0 then Break;
    Visited[BestI][BestJ] := True;
    Inc(Done);
    if FromLo then
    begin
      Pts[NPts] := Point2(RowSpanList[BestI][BestJ].Lo, Rows[BestI]); Inc(NPts);
      Pts[NPts] := Point2(RowSpanList[BestI][BestJ].Hi, Rows[BestI]); Inc(NPts);
      Cur := Pts[NPts - 1];
    end
    else
    begin
      Pts[NPts] := Point2(RowSpanList[BestI][BestJ].Hi, Rows[BestI]); Inc(NPts);
      Pts[NPts] := Point2(RowSpanList[BestI][BestJ].Lo, Rows[BestI]); Inc(NPts);
      Cur := Pts[NPts - 1];
    end;
  end;
  EndAt := Cur;
end;

{ ---------------------------------------------------------------------- }

function DefaultRadiantSpec: TRadiantSpec;
begin
  Result := Default(TRadiantSpec);
  Result.Floor := rfSlab;
  Result.Tube := tsHalf;
  Result.Inch := 1 / 12;
  Result.Spacing := SPACING_DEFAULT_IN * Result.Inch;
  Result.MaxLoopFt := 0;
  Result.WastePct := WASTE_PCT_DEFAULT;
  Result.Corner := 0;
  Result.InAlong := 0;
  Result.InAcross := 0;
  Result.ManifoldW := 18 * Result.Inch;
  Result.ManifoldH := 6 * Result.Inch;
  Result.SlabThick := SLAB_THICK_DEFAULT_IN * Result.Inch;
  Result.TubeDepth := 0;
  Result.UnderR := SLAB_UNDER_R_DEFAULT;
  Result.JoistSpacing := JOIST_SPACING_DEFAULT_IN * Result.Inch;
  Result.Plates := True;
  Result.SubfloorThick := SUBFLOOR_THICK_DEFAULT_IN * Result.Inch;
  Result.BelowR := WOOD_BELOW_R_DEFAULT;
end;

function RadiantManifoldPoint(const Outline: TP3Array; const Spec: TRadiantSpec): TP3;
var
  N, Prev, Next: Integer;
  ToNext, ToPrev: TP3;
  LNext, LPrev: Double;
begin
  N := Length(Outline);
  if (N = 0) or (Spec.Corner < 0) or (Spec.Corner >= N) then Exit(P3(0, 0, 0));
  Next := (Spec.Corner + 1) mod N;
  Prev := (Spec.Corner - 1 + N) mod N;
  ToNext := P3(Outline[Next].X - Outline[Spec.Corner].X, Outline[Next].Y - Outline[Spec.Corner].Y,
    Outline[Next].Z - Outline[Spec.Corner].Z);
  ToPrev := P3(Outline[Prev].X - Outline[Spec.Corner].X, Outline[Prev].Y - Outline[Spec.Corner].Y,
    Outline[Prev].Z - Outline[Spec.Corner].Z);
  LNext := Sqrt(Sqr(ToNext.X) + Sqr(ToNext.Y) + Sqr(ToNext.Z));
  LPrev := Sqrt(Sqr(ToPrev.X) + Sqr(ToPrev.Y) + Sqr(ToPrev.Z));
  if LNext < 1E-9 then LNext := 1;
  if LPrev < 1E-9 then LPrev := 1;
  Result := P3(
    Outline[Spec.Corner].X + ToNext.X / LNext * Spec.InAlong + ToPrev.X / LPrev * Spec.InAcross,
    Outline[Spec.Corner].Y + ToNext.Y / LNext * Spec.InAlong + ToPrev.Y / LPrev * Spec.InAcross,
    Outline[Spec.Corner].Z + ToNext.Z / LNext * Spec.InAlong + ToPrev.Z / LPrev * Spec.InAcross);
end;

function RadiantProblem(const Outline: TP3Array; const Spec: TRadiantSpec): string;
var
  MaxFt: Double;
begin
  Result := '';
  if Length(Outline) < 3 then Exit('The selection has no outline to fill.');
  if Spec.Spacing <= 0 then Exit('The spacing has to read as a size.');
  if (Spec.Spacing < SPACING_MIN_IN * Spec.Inch * 0.5) then
    Exit('That spacing is tighter than any tube can run.');
  if (Spec.Corner < 0) or (Spec.Corner >= Length(Outline)) then
    Exit('The manifold has to sit at one of the outline''s corners.');
  MaxFt := Spec.MaxLoopFt;
  if MaxFt <= 0 then MaxFt := TubeOf(Spec.Tube).MaxLoopFt;
  if MaxFt < 20 then Exit('The maximum loop length has to read as a size.');
  if Spec.Floor = rfSlab then
  begin
    if Spec.SlabThick <= 0 then Exit('The slab thickness has to read as a size.');
  end
  else
  begin
    if Spec.JoistSpacing <= 0 then Exit('The joist spacing has to read as a size.');
  end;
end;

function ComputeRadiantLayout(const Outline: TP3Array; const Holes: array of TP3Array;
  const Manifold: TP3; const Spec: TRadiantSpec): TRadiantResult;
var
  F: TFrame;
  Poly2: array of T2;
  HolePoly: array of array of T2;
  I, J, K, M, Nr, Step: Integer;
  Vmin, Vmax, V0: Double;
  Rows: array of Double;
  RowSpanList: array of TSpanArray;
  Outer, Cuts, HoleRow: TSpanArray;
  EndPt, M2: T2;
  PtsBuf: array of T2;
  NPts: Integer;
  Area: Double;
  MaxFt: Double;
  Cum: array of Double;
  { the walked spans, split into loops at row boundaries }
  procedure EmitLoop(FromIdx, ToIdx: Integer; var Loops: TRadiantLoopArray);
  var
    L: TRadiantLoop;
    N, P: Integer;
    Pts3: TP3Array;
  begin
    N := ToIdx - FromIdx + 1;
    SetLength(Pts3, N + 2);
    Pts3[0] := Manifold;
    for P := 0 to N - 1 do
      Pts3[P + 1] := From2(F, PtsBuf[FromIdx + P].X, PtsBuf[FromIdx + P].Y);
    Pts3[N + 1] := Manifold;
    L.Pts := Pts3;
    L.LenFt := 0;
    for P := 1 to High(Pts3) do L.LenFt := L.LenFt + Dist(Pts3[P - 1], Pts3[P]);
    SetLength(Loops, Length(Loops) + 1);
    Loops[High(Loops)] := L;
  end;
var
  Loops: TRadiantLoopArray;
  Start, Cur, NBreaks: Integer;
  Target, RunningStart: Double;
begin
  Result := Default(TRadiantResult);
  Result.Manifold := Manifold;
  Result.Why := RadiantProblem(Outline, Spec);
  Result.Ok := Result.Why = '';
  if not Result.Ok then Exit;

  F := FrameOf(Outline);
  SetLength(Poly2, Length(Outline));
  Vmin := 1E30; Vmax := -1E30;
  for I := 0 to High(Outline) do
  begin
    Poly2[I] := To2(F, Outline[I]);
    Vmin := Min(Vmin, Poly2[I].Y); Vmax := Max(Vmax, Poly2[I].Y);
  end;
  SetLength(HolePoly, Length(Holes));
  for I := 0 to High(Holes) do
  begin
    SetLength(HolePoly[I], Length(Holes[I]));
    for J := 0 to High(Holes[I]) do HolePoly[I][J] := To2(F, Holes[I][J]);
  end;
  Result.ObstacleCount := Length(Holes);

  { the tube's own turning limit, worked in inches - a U-turn's two legs
    have to be at least twice the minimum bend radius apart, or the tube
    kinks.  Where the spacing is tighter than that, the tube can still be
    laid at that spacing, it just cannot turn on every row - it turns
    every RowStep rows instead, the rows between carried by another loop
    or another pass, which this first version does not yet lay out; see
    the note this puts on the ticket. }
  Result.TurnMinIn := 2 * TubeOf(Spec.Tube).MinBendIn;
  Result.TurnActualIn := Spec.Spacing / Spec.Inch;
  Step := 1;
  while (Step < 8) and (Result.TurnActualIn * Step < Result.TurnMinIn) do Inc(Step);
  Result.RowStep := Step;

  Nr := Max(1, Round((Vmax - Vmin) / (Spec.Spacing * Step)));
  V0 := Vmin + ((Vmax - Vmin) - (Nr - 1) * Spec.Spacing * Step) / 2;
  SetLength(Rows, 0);
  SetLength(RowSpanList, 0);
  Area := 0;
  for I := 0 to Nr - 1 do
  begin
    Outer := RowSpans(Poly2, V0 + I * Spec.Spacing * Step);
    if Length(Outer) = 0 then Continue;
    SetLength(Cuts, 0);
    for J := 0 to High(HolePoly) do
    begin
      HoleRow := RowSpans(HolePoly[J], V0 + I * Spec.Spacing * Step);
      K := Length(Cuts);
      SetLength(Cuts, K + Length(HoleRow));
      for M := 0 to High(HoleRow) do Cuts[K + M] := HoleRow[M];
    end;
    { Cuts is not necessarily sorted once more than one hole crosses this
      row; Subtract only needs each individual cut's own span to be right,
      not the whole list ordered, so it is left as it is }
    Outer := Subtract(Outer, Cuts);
    for J := 0 to High(Outer) do
      if Outer[J].Hi - Outer[J].Lo > 6 * Spec.Inch then
      begin
        SetLength(Rows, Length(Rows) + 1);
        SetLength(RowSpanList, Length(RowSpanList) + 1);
        Rows[High(Rows)] := V0 + I * Spec.Spacing * Step;
        SetLength(RowSpanList[High(RowSpanList)], 1);
        RowSpanList[High(RowSpanList)][0] := Outer[J];
        Area := Area + (Outer[J].Hi - Outer[J].Lo) * Spec.Spacing * Step;
      end;
  end;
  Result.RowCount := Length(Rows);
  { Area was accumulated in world units squared, which is already what
    FormatArea wants }
  Result.AreaSqFt := Area;

  if Length(Rows) = 0 then
  begin
    Result.Ok := False;
    Result.Why := 'Nothing is left to run tube through - check the obstacles ' +
      'have not covered the whole floor.';
    Exit;
  end;

  M2 := To2(F, Manifold);
  SetLength(PtsBuf, Result.RowCount * 4 + 4);
  WalkSpans(Rows, RowSpanList, M2, PtsBuf, NPts, EndPt);

  { the walk's own running length, at each point, so it can be cut into
    loops at row boundaries close to an even share of the whole }
  SetLength(Cum, NPts);
  Cum[0] := Dist(Manifold, From2(F, PtsBuf[0].X, PtsBuf[0].Y));
  for I := 1 to NPts - 1 do
    Cum[I] := Cum[I - 1] + Dist(From2(F, PtsBuf[I - 1].X, PtsBuf[I - 1].Y),
      From2(F, PtsBuf[I].X, PtsBuf[I].Y));
  { the maximum, in world units (feet) - both Spec.MaxLoopFt and the
    table's figure already are }
  MaxFt := Spec.MaxLoopFt;
  if MaxFt <= 0 then MaxFt := TubeOf(Spec.Tube).MaxLoopFt;

  NBreaks := Max(1, Ceil((Cum[NPts - 1] + Dist(From2(F, PtsBuf[NPts - 1].X, PtsBuf[NPts - 1].Y),
    Manifold)) / MaxFt));
  SetLength(Loops, 0);
  Start := 0;
  RunningStart := 0;
  for I := 1 to NBreaks do
  begin
    Target := RunningStart + (Cum[NPts - 1] - RunningStart) / (NBreaks - I + 1);
    Cur := Start;
    { snap to the nearest even point - point pairs are span ends, so
      cutting on an odd index would leave one end of a span stranded }
    while (Cur < NPts - 1) and ((Cur mod 2 = 1) or (Cum[Cur] < Target)) do Inc(Cur);
    if Cur >= NPts then Cur := NPts - 1;
    if Cur mod 2 = 1 then Dec(Cur);
    if I = NBreaks then Cur := NPts - 1;
    if Cur < Start then Cur := Start;
    EmitLoop(Start, Cur, Loops);
    RunningStart := Cum[Cur];
    Start := Cur + 1;
    if Start >= NPts then Break;
  end;
  Result.Loops := Loops;
  Result.TotalFt := 0;
  for I := 0 to High(Loops) do Result.TotalFt := Result.TotalFt + Loops[I].LenFt;
  Result.OrderFt := Result.TotalFt * (1 + Spec.WastePct / 100);
end;

function BuildRadiant(D: TWorkDoc; const Outline: TP3Array; const Holes: array of TP3Array;
  const R: TRadiantResult; const Spec: TRadiantSpec; Ink: TColor; PartName: string): Integer;
var
  I, J, G: Integer;
  Mid: TP3;
begin
  Result := D.Live;
  G := D.NewPart(PartName, 0);
  D.Stamp := G;
  for I := 0 to High(R.Loops) do
    for J := 1 to High(R.Loops[I].Pts) do
    begin
      D.AddLine(R.Loops[I].Pts[J - 1], R.Loops[I].Pts[J], Ink, 1, False);
      D.SetSoft(D.Live - 1, True);
    end;
  for I := 0 to High(Holes) do
    if Length(Holes[I]) > 0 then
    begin
      Mid := P3(0, 0, 0);
      for J := 0 to High(Holes[I]) do
        Mid := P3(Mid.X + Holes[I][J].X / Length(Holes[I]), Mid.Y + Holes[I][J].Y / Length(Holes[I]),
          Mid.Z + Holes[I][J].Z / Length(Holes[I]));
      D.AddNote(P3(Mid.X, Mid.Y, Mid.Z), Mid, 'no tube - obstacle', Ink);
    end;
  D.Stamp := 0;
end;

function RadiantTicketText(const Spec: TRadiantSpec; const R: TRadiantResult;
  U: TUnitSystem): string;
var
  I: Integer;
  T: TTubeFacts;
  Ties: Integer;
  MaxFt: Double;
begin
  { World units are feet throughout this program, so a length already in
    world units - LenFt, TotalFt, OrderFt, the table's MaxLoopFt, and
    Spec.MaxLoopFt when it is set - is a feet number outright and none of
    them need converting against one another.  Only where a number is
    said in inches by trade habit (spacing, slab thickness) is it divided
    by Spec.Inch first, the way TTransitionSpec's own fields are. }
  T := TubeOf(Spec.Tube);
  MaxFt := Spec.MaxLoopFt;
  if MaxFt <= 0 then MaxFt := T.MaxLoopFt;
  Result := '';
  if Spec.Tag <> '' then Result := Result + Spec.Tag + LineEnding + LineEnding;
  Result := Result + 'RADIANT HEAT LAYOUT' + LineEnding;
  Result := Result + 'floor: ' + IfThen(Spec.Floor = rfSlab, 'concrete slab', 'wood joist') + LineEnding;
  Result := Result + 'tube: ' + T.Name + ' PEX, ' + FormatFloat('0.#', Spec.Spacing / Spec.Inch) +
    '" on center' + LineEnding;
  Result := Result + 'area covered: ' + FormatArea(R.AreaSqFt, U) + LineEnding;
  Result := Result + 'loops: ' + IntToStr(Length(R.Loops)) + ', ' + FormatFloat('0', MaxFt) +
    ' ft maximum each' + LineEnding;
  for I := 0 to High(R.Loops) do
    Result := Result + Format('  loop %d: %s%s', [I + 1, FormatLen(R.Loops[I].LenFt, U),
      IfThen(R.Loops[I].LenFt > MaxFt, '  - OVER the maximum for this tube', '')]) + LineEnding;
  Result := Result + 'total tube, no waste: ' + FormatLen(R.TotalFt, U) + LineEnding;
  Result := Result + 'order (with ' + FormatFloat('0', Spec.WastePct) + '% waste): ' +
    FormatLen(R.OrderFt, U) + LineEnding;
  { R.TotalFt is feet already; times 12 is inches of run, over the tie
    spacing in inches is how many ties that run wants }
  Ties := Round(R.TotalFt * 12 / TIE_SPACING_IN);
  Result := Result + 'ties or staples (estimate, every ' + FormatFloat('0', TIE_SPACING_IN) +
    '"): about ' + IntToStr(Ties) + LineEnding;
  Result := Result + 'manifold ports needed: ' + IntToStr(Length(R.Loops)) + LineEnding;
  if R.TurnActualIn < R.TurnMinIn then
    Result := Result + Format('note: at %s" on center this tube cannot turn every row - ' +
      'it needs %s" to bend, so it turns every %d rows instead', [FormatFloat('0.#', R.TurnActualIn),
      FormatFloat('0.#', R.TurnMinIn), R.RowStep]) + LineEnding;
  if Spec.Floor = rfSlab then
  begin
    Result := Result + LineEnding + 'SLAB' + LineEnding;
    Result := Result + 'thickness: ' + FormatFloat('0.##', Spec.SlabThick / Spec.Inch) + '"' + LineEnding;
    Result := Result + 'tube depth: ' + IfThen(Spec.TubeDepth <= 0, 'centered in the pour',
      FormatFloat('0.##', Spec.TubeDepth / Spec.Inch) + '"') + LineEnding;
    Result := Result + 'insulation under the slab: R-' + FormatFloat('0', Spec.UnderR) + ' minimum' + LineEnding;
  end
  else
  begin
    Result := Result + LineEnding + 'WOOD FLOOR' + LineEnding;
    Result := Result + 'joist spacing: ' + FormatFloat('0.##', Spec.JoistSpacing / Spec.Inch) + '"' + LineEnding;
    Result := Result + 'transfer plates: ' + IfThen(Spec.Plates, 'yes', 'no - bare staple-up') + LineEnding;
    Result := Result + 'subfloor: ' + FormatFloat('0.##', Spec.SubfloorThick / Spec.Inch) + '"' + LineEnding;
    Result := Result + 'insulation below: R-' + FormatFloat('0', Spec.BelowR) + ' minimum' + LineEnding;
  end;
  if R.ObstacleCount > 0 then
    Result := Result + LineEnding + IntToStr(R.ObstacleCount) + ' obstacle(s) routed around.' + LineEnding;
  Result := Result + LineEnding + 'Flow rate and pump sizing are not worked out here - they ' +
    'come from a room-by-room heat loss, not from the tube size alone.' + LineEnding;
end;

end.
