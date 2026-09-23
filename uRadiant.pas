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
  program.  What is left is a set of short straight spans, and those are
  gathered into cells: a cell is a run of rows in which each span carries
  straight on from the one below it, so a floor with a column in it has
  a cell below the column, one either side of it, and one above.  That is
  boustrophedon cellular decomposition, the usual answer to covering a
  floor with things in the way.  Within a cell the tube is a plain
  serpentine - every turn a short jog at the end of a row - and from the
  end of one cell it goes into the nearest end of the nearest cell not yet
  walked.  That last choice is greedy, not a search over every order: a
  true shortest tour of the cells is the traveling salesman problem.  On
  an open floor there is one cell and the walk is exactly the serpentine
  a person would draw by hand.  A join between cells that would pass
  straight through an obstacle is counted and said on the ticket rather
  than drawn as if it were a route.

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
    RunsPerBay: Integer;      { the spacing is the bay over this, on a wood floor }
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
    { the turn the layout asks of the tube at the end of every row - the
      spacing, in inches - against what the tube can do: eight times its
      outer diameter for PEX-B and PEX-C, six for PEX-A.  The layout is
      laid at the spacing asked for either way; the ticket says which
      tube can make the turn. }
    TurnActualIn, TurnMinIn, TurnMinPexAIn: Double;
    { how many of the joins between spans, and leads to the manifold,
      run straight through an obstacle.  Zero on an open floor and on
      most floors with a column or two; where it is not, those joins want
      routing by hand, and the ticket says which count }
    Crossings: Integer;
    CellCount: Integer;
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

{ Writes the result into the drawing as one part: the runs as reference
  lines in the tube's ink, a box and a note for the manifold, and a note
  on every hole that was routed around.  Returns the first entity added. }
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
  T2Array = array of T2;
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
{ the walk: cells first, then every span of each cell in turn             }
{ ---------------------------------------------------------------------- }

type
  TFieldSpan = record
    Row: Integer;          { which row, bottom to top }
    V, Lo, Hi: Double;
    Cell: Integer;         { which cell it belongs to, once decided }
  end;
  TFieldSpanArray = array of TFieldSpan;
  TIntArray = array of Integer;

{ Does the straight line from A to B pass through this polygon?  Either it
  crosses one of the polygon's edges, or it lies wholly inside - which the
  midpoint tells. }
function SegCrossesPoly(const A, B: T2; const Poly: array of T2): Boolean;
var
  I, J, N: Integer;
  Mid: T2;
  Inside: Boolean;

  function Orient(const P, Q, R: T2): Double;
  begin
    Result := (Q.X - P.X) * (R.Y - P.Y) - (Q.Y - P.Y) * (R.X - P.X);
  end;

  function Crosses(const P1, P2, Q1, Q2: T2): Boolean;
  var
    D1, D2, D3, D4: Double;
  begin
    D1 := Orient(Q1, Q2, P1); D2 := Orient(Q1, Q2, P2);
    D3 := Orient(P1, P2, Q1); D4 := Orient(P1, P2, Q2);
    Result := ((D1 > 1E-12) <> (D2 > 1E-12)) and ((D1 < -1E-12) <> (D2 < -1E-12)) and
              ((D3 > 1E-12) <> (D4 > 1E-12)) and ((D3 < -1E-12) <> (D4 < -1E-12));
  end;

begin
  Result := False;
  N := Length(Poly);
  if N < 3 then Exit;
  for I := 0 to N - 1 do
    if Crosses(A, B, Poly[I], Poly[(I + 1) mod N]) then Exit(True);
  Mid := Point2((A.X + B.X) / 2, (A.Y + B.Y) / 2);
  Inside := False;
  J := N - 1;
  for I := 0 to N - 1 do
  begin
    if ((Poly[I].Y > Mid.Y) <> (Poly[J].Y > Mid.Y)) and
       (Mid.X < (Poly[J].X - Poly[I].X) * (Mid.Y - Poly[I].Y) / (Poly[J].Y - Poly[I].Y) + Poly[I].X) then
      Inside := not Inside;
    J := I;
  end;
  Result := Inside;
end;

{ The cells: a cell is a run of rows in which one span carries straight on
  from the one below it - overlapping it in U, and neither of them
  overlapping anything else.  Where a hole starts, one span becomes two
  and both begin new cells; where it ends, two become one and that one
  begins a new cell.  This is boustrophedon cellular decomposition, the
  usual answer to covering a floor with obstacles in it, and it is what
  keeps the tube from being drawn through a column: within a cell every
  turn is a short jog at the end of a row, and a cell's boundary is
  exactly where an obstacle's is. }
function DecomposeCells(var Spans: TFieldSpanArray; NRows: Integer): Integer;
var
  I, J, K, Cells, NPrev, NNext: Integer;
  Prev: Integer;
  Overlap: Boolean;
begin
  Cells := 0;
  for I := 0 to High(Spans) do Spans[I].Cell := -1;
  for I := 0 to High(Spans) do
  begin
    { the spans on the row below that this one overlaps }
    Prev := -1; NPrev := 0;
    for J := 0 to High(Spans) do
      if (Spans[J].Row = Spans[I].Row - 1) and
         (Spans[J].Lo < Spans[I].Hi) and (Spans[J].Hi > Spans[I].Lo) then
      begin
        Prev := J; Inc(NPrev);
      end;
    if NPrev = 1 then
    begin
      { and does that one carry on into only this span? }
      NNext := 0;
      for K := 0 to High(Spans) do
        if (Spans[K].Row = Spans[I].Row) and
           (Spans[Prev].Lo < Spans[K].Hi) and (Spans[Prev].Hi > Spans[K].Lo) then
          Inc(NNext);
      Overlap := NNext = 1;
    end
    else Overlap := False;
    if Overlap then Spans[I].Cell := Spans[Prev].Cell
    else
    begin
      Spans[I].Cell := Cells;
      Inc(Cells);
    end;
  end;
  Result := Cells;
end;

{ The walk over the cells: from wherever the tube is, into the nearest
  end of the nearest unwalked cell, serpentine through it, out the far
  end, and on.  Each span is put out as its two ends in the order walked,
  so the list is pairs and can be cut between any pair. }
procedure WalkCells(const Spans: TFieldSpanArray; NCells: Integer; Start: T2;
  const HolePoly: array of T2Array; var Pts: array of T2; out NPts: Integer);
var
  Members: array of TIntArray;   { each cell's spans, bottom row first }
  Done: array of Boolean;
  I, J, C, BestC, K, N, Cnt, H: Integer;
  Cur: T2;
  D, BestD: Double;
  FromTop, FromLo, BestTop, BestLo: Boolean;
  Sp: TFieldSpan;
  Tmp: Integer;
begin
  NPts := 0;
  SetLength(Members, NCells);
  for I := 0 to High(Spans) do
  begin
    C := Spans[I].Cell;
    SetLength(Members[C], Length(Members[C]) + 1);
    Members[C][High(Members[C])] := I;
  end;
  { each cell's spans in row order - they were found in row order, but
    say so }
  for C := 0 to NCells - 1 do
    for I := 1 to High(Members[C]) do
    begin
      K := I;
      while (K > 0) and (Spans[Members[C][K - 1]].Row > Spans[Members[C][K]].Row) do
      begin
        Tmp := Members[C][K]; Members[C][K] := Members[C][K - 1]; Members[C][K - 1] := Tmp;
        Dec(K);
      end;
    end;
  SetLength(Done, NCells);
  Cur := Start;
  for Cnt := 1 to NCells do
  begin
    BestD := 1E30; BestC := -1; BestTop := False; BestLo := True;
    for C := 0 to NCells - 1 do
      if not Done[C] and (Length(Members[C]) > 0) then
        for J := 0 to 3 do
        begin
          FromTop := J >= 2;
          FromLo := (J mod 2) = 0;
          if FromTop then Sp := Spans[Members[C][High(Members[C])]]
          else Sp := Spans[Members[C][0]];
          if FromLo then D := Sqr(Sp.Lo - Cur.X) + Sqr(Sp.V - Cur.Y)
          else D := Sqr(Sp.Hi - Cur.X) + Sqr(Sp.V - Cur.Y);
          { a join that would go straight through an obstacle is the last
            resort, whatever its length: the far side of a column is near
            as the crow flies and not as the tube runs }
          for H := 0 to High(HolePoly) do
            if SegCrossesPoly(Cur, Point2(IfThen(FromLo, Sp.Lo, Sp.Hi), Sp.V), HolePoly[H]) then
            begin
              D := D + 1E12;
              Break;
            end;
          if D < BestD then
          begin
            BestD := D; BestC := C; BestTop := FromTop; BestLo := FromLo;
          end;
        end;
    if BestC < 0 then Break;
    Done[BestC] := True;
    N := Length(Members[BestC]);
    FromLo := BestLo;
    for I := 0 to N - 1 do
    begin
      if BestTop then Sp := Spans[Members[BestC][N - 1 - I]]
      else Sp := Spans[Members[BestC][I]];
      if FromLo then
      begin
        Pts[NPts] := Point2(Sp.Lo, Sp.V); Inc(NPts);
        Pts[NPts] := Point2(Sp.Hi, Sp.V); Inc(NPts);
      end
      else
      begin
        Pts[NPts] := Point2(Sp.Hi, Sp.V); Inc(NPts);
        Pts[NPts] := Point2(Sp.Lo, Sp.V); Inc(NPts);
      end;
      Cur := Pts[NPts - 1];
      FromLo := not FromLo;
    end;
  end;
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
  Result.RunsPerBay := RUNS_PER_BAY_DEFAULT;
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
    if (Spec.RunsPerBay < 1) or (Spec.RunsPerBay > 4) then Exit('One to four runs per bay.');
  end;
end;

{ the area of a 2D polygon, whichever way round it goes }
function PolyArea2(const P: array of T2): Double;
var
  I, J: Integer;
begin
  Result := 0;
  for I := 0 to High(P) do
  begin
    J := (I + 1) mod Length(P);
    Result := Result + P[I].X * P[J].Y - P[J].X * P[I].Y;
  end;
  Result := Abs(Result) / 2;
end;

function ComputeRadiantLayout(const Outline: TP3Array; const Holes: array of TP3Array;
  const Manifold: TP3; const Spec: TRadiantSpec): TRadiantResult;
var
  F: TFrame;
  Poly2: array of T2;
  HolePoly: array of T2Array;
  I, J, K, M, Nr, NCells: Integer;
  Vmin, Vmax, V0, V, Inset: Double;
  Outer, Cuts, HoleRow: TSpanArray;
  Spans: TFieldSpanArray;
  M2: T2;
  PtsBuf: array of T2;
  NPts: Integer;
  MaxFt: Double;
  Cum: array of Double;
  Loops: TRadiantLoopArray;
  Start, Cur, NBreaks, Tries, LeadCrossings: Integer;
  Target, RunningStart, Longest, Umin, Umax: Double;
  IsRect: Boolean;
  Join: T2Array;

  function World(const P: T2): TP3;
  begin
    Result := From2(F, P.X, P.Y);
  end;

  { does this straight run pass through any obstacle? }
  function ThroughAHole(const A, B: T2): Boolean;
  var
    H: Integer;
  begin
    Result := False;
    for H := 0 to High(HolePoly) do
      if SegCrossesPoly(A, B, HolePoly[H]) then Exit(True);
  end;

  { A lead from the manifold to where a loop starts or ends.  On a
    rectangular floor it keeps to the band along the walls that the runs
    already stay out of - along the manifold's own wall, then up the side
    the run ends on - so it crosses nothing, the way a fitter runs leads.
    On any other shape it is a straight line, and if that passes through
    an obstacle the count on the ticket says so. }
  function LeadPath(const T: T2): T2Array;
  var
    Band, Vb, Xs: Double;
    Pts: T2Array;
    N: Integer;
    procedure Put(X, Y: Double);
    begin
      if (N > 0) and (Abs(Pts[N - 1].X - X) < 1E-9) and (Abs(Pts[N - 1].Y - Y) < 1E-9) then Exit;
      Pts[N] := Point2(X, Y); Inc(N);
    end;
  begin
    SetLength(Pts, 6);
    N := 0;
    Put(M2.X, M2.Y);
    if IsRect and (Inset > 0) then
    begin
      Band := Inset / 2;
      { the wall the manifold sits along, and the side the run ends on }
      if M2.Y - Vmin < Vmax - M2.Y then Vb := Vmin + Band else Vb := Vmax - Band;
      if T.X - Umin < Umax - T.X then Xs := Umin + Band else Xs := Umax + 0 - Band;
      if Abs(M2.X - Xs) > Inset then
      begin
        Put(M2.X, Vb);
        Put(Xs, Vb);
      end;
      Put(Xs, T.Y);
    end;
    Put(T.X, T.Y);
    SetLength(Pts, N);
    Result := Pts;
  end;

  { The join from the end of one span to the start of the next.  Next
    row over, it is the jog at the end of the row and nothing more.  Any
    further - the next cell, across the room - and on a rectangular floor
    it goes the way a fitter would take it: out into the wall band, along
    it, and in again, crossing no run on the way.  Elsewhere, straight. }
  function JoinPath(const A, B: T2): T2Array;
  var
    Band, Vb, XsA, XsB: Double;
    Pts: T2Array;
    N: Integer;
    procedure Put(X, Y: Double);
    begin
      if (N > 0) and (Abs(Pts[N - 1].X - X) < 1E-9) and (Abs(Pts[N - 1].Y - Y) < 1E-9) then Exit;
      Pts[N] := Point2(X, Y); Inc(N);
    end;
  begin
    SetLength(Pts, 8);
    N := 0;
    Put(A.X, A.Y);
    if IsRect and (Inset > 0) and
       (Sqr(A.X - B.X) + Sqr(A.Y - B.Y) > Sqr(1.5 * Spec.Spacing)) then
    begin
      Band := Inset / 2;
      if A.X - Umin < Umax - A.X then XsA := Umin + Band else XsA := Umax - Band;
      if B.X - Umin < Umax - B.X then XsB := Umin + Band else XsB := Umax - Band;
      Put(XsA, A.Y);
      if Abs(XsA - XsB) > 1E-9 then
      begin
        { round by whichever end wall is nearer where it starts }
        if A.Y - Vmin < Vmax - A.Y then Vb := Vmin + Band else Vb := Vmax - Band;
        Put(XsA, Vb);
        Put(XsB, Vb);
      end;
      Put(XsB, B.Y);
    end;
    Put(B.X, B.Y);
    SetLength(Pts, N);
    Result := Pts;
  end;

  { one loop: the lead in, the walk from FromIdx to ToIdx, the lead out }
  procedure EmitLoop(FromIdx, ToIdx: Integer);
  var
    L: TRadiantLoop;
    N, P, K, Q: Integer;
    LeadIn, LeadOut, Join: T2Array;
  begin
    N := ToIdx - FromIdx + 1;
    LeadIn := LeadPath(PtsBuf[FromIdx]);
    LeadOut := LeadPath(PtsBuf[ToIdx]);
    SetLength(L.Pts, Length(LeadIn) - 1 + N + Length(LeadOut) - 1);
    K := 0;
    for P := 0 to High(LeadIn) - 1 do begin L.Pts[K] := World(LeadIn[P]); Inc(K); end;
    for P := 0 to N - 1 do
    begin
      { between the end of one span and the start of the next, the join's
        own way round }
      if (P > 0) and (P mod 2 = 0) then
      begin
        Join := JoinPath(PtsBuf[FromIdx + P - 1], PtsBuf[FromIdx + P]);
        for Q := 1 to High(Join) - 1 do
        begin
          SetLength(L.Pts, Length(L.Pts) + 1);
          L.Pts[K] := World(Join[Q]); Inc(K);
        end;
      end;
      L.Pts[K] := World(PtsBuf[FromIdx + P]); Inc(K);
    end;
    for P := High(LeadOut) - 1 downto 0 do begin L.Pts[K] := World(LeadOut[P]); Inc(K); end;
    L.LenFt := 0;
    for P := 1 to High(L.Pts) do L.LenFt := L.LenFt + Dist(L.Pts[P - 1], L.Pts[P]);
    { the legs of both leads, against the obstacles }
    for P := 1 to High(LeadIn) do
      if ThroughAHole(LeadIn[P - 1], LeadIn[P]) then Inc(LeadCrossings);
    for P := 1 to High(LeadOut) do
      if ThroughAHole(LeadOut[P - 1], LeadOut[P]) then Inc(LeadCrossings);
    SetLength(Loops, Length(Loops) + 1);
    Loops[High(Loops)] := L;
  end;

begin
  Result := Default(TRadiantResult);
  Result.Manifold := Manifold;
  Result.Why := RadiantProblem(Outline, Spec);
  Result.Ok := Result.Why = '';
  if not Result.Ok then Exit;

  F := FrameOf(Outline);
  SetLength(Poly2, Length(Outline));
  Vmin := 1E30; Vmax := -1E30; Umin := 1E30; Umax := -1E30;
  for I := 0 to High(Outline) do
  begin
    Poly2[I] := To2(F, Outline[I]);
    Vmin := Min(Vmin, Poly2[I].Y); Vmax := Max(Vmax, Poly2[I].Y);
    Umin := Min(Umin, Poly2[I].X); Umax := Max(Umax, Poly2[I].X);
  end;
  { a rectangle: four corners, each on two of the four bounds }
  IsRect := Length(Poly2) = 4;
  for I := 0 to High(Poly2) do
    if IsRect then
      IsRect := ((Abs(Poly2[I].X - Umin) < 1E-6) or (Abs(Poly2[I].X - Umax) < 1E-6)) and
                ((Abs(Poly2[I].Y - Vmin) < 1E-6) or (Abs(Poly2[I].Y - Vmax) < 1E-6));
  SetLength(HolePoly, Length(Holes));
  for I := 0 to High(Holes) do
  begin
    SetLength(HolePoly[I], Length(Holes[I]));
    for J := 0 to High(Holes[I]) do HolePoly[I][J] := To2(F, Holes[I][J]);
  end;
  Result.ObstacleCount := Length(Holes);

  { the floor's real area, less its holes - what the ticket calls covered }
  Result.AreaSqFt := PolyArea2(Poly2);
  for I := 0 to High(HolePoly) do Result.AreaSqFt := Result.AreaSqFt - PolyArea2(HolePoly[I]);

  { the turn at the end of every row is the spacing; whether the tube can
    make it is said on the ticket, not decided here }
  Result.TurnActualIn := Spec.Spacing / Spec.Inch;
  Result.TurnMinIn := 2 * TubeOf(Spec.Tube).MinBendIn;
  Result.TurnMinPexAIn := 2 * TubeOf(Spec.Tube).OdIn * 6;

  { rows at the spacing, kept a hand's width off every wall - the same
    inset at the row ends as at the first and last row }
  Inset := EDGE_INSET_IN * Spec.Inch;
  if (Vmax - Vmin) < 2 * Inset + Spec.Spacing then Inset := Max(0, ((Vmax - Vmin) - Spec.Spacing) / 2);
  Nr := Max(1, Floor(((Vmax - Vmin) - 2 * Inset) / Spec.Spacing) + 1);
  V0 := Vmin + Inset + (((Vmax - Vmin) - 2 * Inset) - (Nr - 1) * Spec.Spacing) / 2;
  SetLength(Spans, 0);
  for I := 0 to Nr - 1 do
  begin
    V := V0 + I * Spec.Spacing;
    Outer := RowSpans(Poly2, V);
    if Length(Outer) = 0 then Continue;
    SetLength(Cuts, 0);
    for J := 0 to High(HolePoly) do
    begin
      HoleRow := RowSpans(HolePoly[J], V);
      K := Length(Cuts);
      SetLength(Cuts, K + Length(HoleRow));
      { the inset off an obstacle is the same one taken off every span's
        ends below, so the cut itself is the hole's own width }
      for M := 0 to High(HoleRow) do Cuts[K + M] := HoleRow[M];
    end;
    Outer := Subtract(Outer, Cuts);
    for J := 0 to High(Outer) do
      if (Outer[J].Hi - Inset) - (Outer[J].Lo + Inset) > 6 * Spec.Inch then
      begin
        SetLength(Spans, Length(Spans) + 1);
        Spans[High(Spans)].Row := I;
        Spans[High(Spans)].V := V;
        Spans[High(Spans)].Lo := Outer[J].Lo + Inset;
        Spans[High(Spans)].Hi := Outer[J].Hi - Inset;
      end;
  end;
  Result.RowCount := Nr;
  if Length(Spans) = 0 then
  begin
    Result.Ok := False;
    Result.Why := 'Nothing is left to run tube through - check the obstacles ' +
      'have not covered the whole floor.';
    Exit;
  end;

  NCells := DecomposeCells(Spans, Nr);
  Result.CellCount := NCells;
  M2 := To2(F, Manifold);
  SetLength(PtsBuf, Length(Spans) * 2);
  WalkCells(Spans, NCells, M2, HolePoly, PtsBuf, NPts);

  { the walk's running length at each point - a join between spans
    measured the way it will be run, not as the crow flies - so it can be
    cut into loops at span ends close to an even share of the whole.  And
    every leg of every join against the obstacles: a join that passes
    through a column is not a route, and the ticket says how many }
  Result.Crossings := 0;
  SetLength(Cum, NPts);
  Cum[0] := 0;
  for I := 1 to NPts - 1 do
    if I mod 2 = 0 then
    begin
      Join := JoinPath(PtsBuf[I - 1], PtsBuf[I]);
      Cum[I] := Cum[I - 1];
      for J := 1 to High(Join) do
      begin
        Cum[I] := Cum[I] + Dist(World(Join[J - 1]), World(Join[J]));
        if ThroughAHole(Join[J - 1], Join[J]) then Inc(Result.Crossings);
      end;
    end
    else
      Cum[I] := Cum[I - 1] + Dist(World(PtsBuf[I - 1]), World(PtsBuf[I]));
  MaxFt := Spec.MaxLoopFt;
  if MaxFt <= 0 then MaxFt := TubeOf(Spec.Tube).MaxLoopFt;

  { Each piece gets its own two leads to the manifold, and those count.
    So: cut, measure, and if any piece is still over, cut one more way
    and try again. }
  NBreaks := Max(1, Ceil((Cum[NPts - 1] + Dist(Manifold, World(PtsBuf[0])) +
    Dist(World(PtsBuf[NPts - 1]), Manifold)) / MaxFt));
  for Tries := 1 to 64 do
  begin
    SetLength(Loops, 0);
    LeadCrossings := 0;
    Start := 0;
    RunningStart := 0;
    for I := 1 to NBreaks do
    begin
      Target := RunningStart + (Cum[NPts - 1] - RunningStart) / (NBreaks - I + 1);
      Cur := Start;
      { only ever between pairs: a pair is a span, and a span is walked
        whole }
      while (Cur < NPts - 1) and ((Cur mod 2 = 0) or (Cum[Cur] < Target)) do Inc(Cur);
      if Cur mod 2 = 0 then Dec(Cur);
      if Cur < Start + 1 then Cur := Start + 1;
      if (I = NBreaks) or (Cur >= NPts - 1) then Cur := NPts - 1;
      EmitLoop(Start, Cur);
      RunningStart := Cum[Cur];
      Start := Cur + 1;
      if Start >= NPts then Break;
    end;
    Longest := 0;
    for I := 0 to High(Loops) do Longest := Max(Longest, Loops[I].LenFt);
    if (Longest <= MaxFt) or (NBreaks >= NPts div 2) then Break;
    Inc(NBreaks);
  end;
  Inc(Result.Crossings, LeadCrossings);
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
  F: TFrame;
  W, H: Double;
  C: array[0..3] of TP3;
begin
  Result := D.Live;
  G := D.NewPart(PartName, 0);
  D.Stamp := G;
  { The runs are reference lines - Heck's "ref = true", the kind a
    dimension's own line is.  They draw in full, in the tube's ink, and
    the region finder leaves them alone: a hard line would close faces
    with the floor's edges (a serpentine and its leads is one long closed
    loop), and a soft one is hidden wherever it is not the edge of a face,
    which on a flat floor is everywhere - the first build had them
    invisible for exactly that reason. }
  for I := 0 to High(R.Loops) do
    for J := 1 to High(R.Loops[I].Pts) do
      D.AddLine(R.Loops[I].Pts[J - 1], R.Loops[I].Pts[J], Ink, 2, True);
  for I := 0 to High(Holes) do
    if Length(Holes[I]) > 0 then
    begin
      Mid := P3(0, 0, 0);
      for J := 0 to High(Holes[I]) do
        Mid := P3(Mid.X + Holes[I][J].X / Length(Holes[I]), Mid.Y + Holes[I][J].Y / Length(Holes[I]),
          Mid.Z + Holes[I][J].Z / Length(Holes[I]));
      D.AddNote(P3(Mid.X, Mid.Y, Mid.Z), Mid, 'no tube - obstacle', Ink);
    end;
  { the manifold: a small box on the floor where it sits, square to the
    outline's own frame, hard-edged so it reads as a thing and not a run }
  F := FrameOf(Outline);
  if (Spec.ManifoldW > 0) and (Spec.ManifoldH > 0) then
  begin
    W := Spec.ManifoldW / 2; H := Spec.ManifoldH / 2;
    C[0] := P3(R.Manifold.X - F.U.X * W - F.V.X * H, R.Manifold.Y - F.U.Y * W - F.V.Y * H, R.Manifold.Z - F.U.Z * W - F.V.Z * H);
    C[1] := P3(R.Manifold.X + F.U.X * W - F.V.X * H, R.Manifold.Y + F.U.Y * W - F.V.Y * H, R.Manifold.Z + F.U.Z * W - F.V.Z * H);
    C[2] := P3(R.Manifold.X + F.U.X * W + F.V.X * H, R.Manifold.Y + F.U.Y * W + F.V.Y * H, R.Manifold.Z + F.U.Z * W + F.V.Z * H);
    C[3] := P3(R.Manifold.X - F.U.X * W + F.V.X * H, R.Manifold.Y - F.U.Y * W + F.V.Y * H, R.Manifold.Z - F.U.Z * W + F.V.Z * H);
    for I := 0 to 3 do D.AddLine(C[I], C[(I + 1) mod 4], Ink, 1, False);
    D.AddNote(C[2], R.Manifold, 'manifold - ' + IntToStr(Length(R.Loops)) + ' loops', Ink);
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
  { the turn at the end of a row is the spacing.  PEX-B and PEX-C bend to
    eight times their outer diameter, PEX-A to six; say which can make
    this turn, and what to do when neither can }
  if R.TurnActualIn < R.TurnMinPexAIn then
    Result := Result + Format('note: the %s" turn at the end of each row is tighter than ' +
      'this tube bends - PEX-A needs %s", PEX-B and PEX-C %s".  Double back (two ' +
      'interleaved passes, turning at %s") or widen the spacing.',
      [FormatFloat('0.#', R.TurnActualIn), FormatFloat('0.#', R.TurnMinPexAIn),
       FormatFloat('0.#', R.TurnMinIn), FormatFloat('0.#', 2 * R.TurnActualIn)]) + LineEnding
  else if R.TurnActualIn < R.TurnMinIn then
    Result := Result + Format('note: the %s" turn at the end of each row is fine for PEX-A ' +
      '(%s" minimum) but tighter than PEX-B or PEX-C bend (%s").',
      [FormatFloat('0.#', R.TurnActualIn), FormatFloat('0.#', R.TurnMinPexAIn),
       FormatFloat('0.#', R.TurnMinIn)]) + LineEnding;
  if R.Crossings > 0 then
    Result := Result + Format('WARNING: %d join(s) between runs, or leads, pass straight ' +
      'through an obstacle - route those by hand.', [R.Crossings]) + LineEnding;
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
    Result := Result + 'joist spacing: ' + FormatFloat('0.##', Spec.JoistSpacing / Spec.Inch) +
      '", ' + IntToStr(Spec.RunsPerBay) + ' run(s) per bay' + LineEnding;
    Result := Result + 'runs are laid along the outline''s longest edge - check that is ' +
      'the way the joists run' + LineEnding;
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
