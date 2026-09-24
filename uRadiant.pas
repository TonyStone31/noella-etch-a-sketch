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
  { the floor's own plane, in Double throughout - a barn's worth of floor
    at sub-inch accuracy wants better than the Single the LCL's TPointF
    carries for pixels }
  T2 = record X, Y: Double; end;
  T2Array = array of T2;
  TIntArray = array of Integer;
  TRadiantHoles = array of TP3Array;

  { the frame the layout is worked in: the outline's first corner, U
    along its longest edge, V across, N out of it }
  TRadiantFrame = record
    Origin: TP3;
    U, V, N: TP3;
  end;

  TRadiantSpec = record
    Floor: TRadiantFloor;
    Tube: TTubeSize;
    Spacing: Double;          { world units (feet) - on center }
    MaxLoopFt: Double;        { 0 = the tube's own table maximum }
    WastePct: Double;
    { the manifolds, where they stand and how many loops each takes; a
      loop goes to the nearest.  Extra is what the wizard added as
      obstacles over what the face already had as holes. }
    Manifolds: TP3Array;
    Ports: TIntArray;
    Extra: TRadiantHoles;
    ManifoldW, ManifoldH: Double;   { the little box drawn for each }
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
    Labels: Boolean;          { the loop and manifold notes on the drawing - off
                                while the paths are being inspected by hand, the
                                notes land over them }
    Inch: Double;             { the drawing's own inch, as TTransitionSpec keeps it }
  end;

  TRadiantLoop = record
    Pts: TP3Array;             { the centerline, manifold to manifold }
    LenFt: Double;
    Manifold: Integer;         { which one it runs from }
  end;
  TRadiantLoopArray = array of TRadiantLoop;

  TManifoldResult = record
    At: TP3;
    Ports: Integer;            { as chosen }
    LoopCount: Integer;        { as laid }
    Ft: Double;
  end;

  TRadiantResult = record
    Loops: TRadiantLoopArray;
    Manifolds: array of TManifoldResult;
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
    { floor no loop could take: a lone row with no neighbor to come back
      on, or the far side of an obstacle - said on the ticket }
    UnfilledSqFt: Double;
    Ok: Boolean;
    Why: string;
  end;

  { a zone: one face of the drawing and the holes cut into it, each with
    a manifold of its own }
  TRadiantZone = record
    Outline: TP3Array;
    Holes: TRadiantHoles;
  end;
  TRadiantZones = array of TRadiantZone;

function DefaultRadiantSpec: TRadiantSpec;
function Point2(X, Y: Double): T2;

{ Where a zone's manifold goes when nothing better is known: at the
  zone's corner nearest Toward - the middle of all the zones, so the
  manifolds of a building end up near each other and the boiler - a
  foot in along both edges; and how many loops it takes, with one to
  spare. }
procedure RadiantSuggestZoneManifold(const Zone: TRadiantZone; const Toward: TP3;
  const Spec: TRadiantSpec; out At: TP3; out Ports: Integer);

const
  { a color for each manifold - its zone - and every loop of it in that
    color, told apart by line weight, thick and thin by turns, so a run
    can be followed by eye across a plan that carries fifty of them }
  ZONE_INKS: array[0..7] of TColor = ($002030C8, $00C86020, $0030A030, $008020A0,
    $0020A0A0, $00A0A020, $00C03080, $00606060);

function ZoneInk(Manifold: Integer): TColor;
function LoopWeight(LoopOfManifold: Integer): Single;

{ The frame, and the way in and out of it - shared by the layout and the
  dialog's plan, so a point dragged on the plan lands where the layout
  thinks it is. }
function RadiantFrameOf(const Outline: TP3Array): TRadiantFrame;
function RadiantTo2(const F: TRadiantFrame; const P: TP3): T2;
function RadiantFrom2(const F: TRadiantFrame; U, V: Double): TP3;

{ How many loops this floor wants at this tube and spacing, before any
  manifold is placed: its area over what one loop covers. }
function RadiantLoopsNeeded(const Outline: TP3Array; const Holes: array of TP3Array;
  const Spec: TRadiantSpec): Integer;

{ Where to put the manifolds, and how many loops each: as many as the
  loop count wants at twelve a manifold, spaced evenly along the longest
  wall a foot in from it, since a manifold hangs on a wall.  A starting
  point to drag from, not an answer. }
procedure RadiantSuggestManifolds(const Outline: TP3Array; const Holes: array of TP3Array;
  const Spec: TRadiantSpec; out At: TP3Array; out Ports: TIntArray);

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
  const Spec: TRadiantSpec): TRadiantResult;

{ Writes the result into the drawing as one part: the runs as reference
  lines in the tube's ink, a box and a note for the manifold, and a note
  on every hole that was routed around.  Returns the first entity added. }
function BuildRadiant(D: TWorkDoc; const Outline: TP3Array; const Holes: array of TP3Array;
  const R: TRadiantResult; const Spec: TRadiantSpec; Ink: TColor; PartName: string;
  Zone: Integer = 0): Integer;

{ The material list and the numbers behind it, as words - the ticket. }
function RadiantTicketText(const Spec: TRadiantSpec; const R: TRadiantResult;
  U: TUnitSystem): string;

implementation

type
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

{ the outline's own plane: the origin its first corner, U along its
  longest edge, so a rectangle is filled the way a person would - tube
  parallel to the long wall - and V and N at right angles to it }
function RadiantFrameOf(const Outline: TP3Array): TRadiantFrame;
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

function RadiantTo2(const F: TRadiantFrame; const P: TP3): T2;
var
  D: TP3;
begin
  D := P3(P.X - F.Origin.X, P.Y - F.Origin.Y, P.Z - F.Origin.Z);
  Result.X := Dot3(D, F.U);
  Result.Y := Dot3(D, F.V);
end;

function RadiantFrom2(const F: TRadiantFrame; U, V: Double): TP3;
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

function ZoneInk(Manifold: Integer): TColor;
begin
  Result := ZONE_INKS[Manifold mod Length(ZONE_INKS)];
end;

function LoopWeight(LoopOfManifold: Integer): Single;
begin
  { one weight: thick and thin by turns read as doubled tube on the plan }
  Result := 2;
end;

function DefaultRadiantSpec: TRadiantSpec;
begin
  Result := Default(TRadiantSpec);
  Result.Floor := rfSlab;
  Result.Tube := tsHalf;
  Result.Inch := 1 / 12;
  Result.Spacing := SPACING_DEFAULT_IN * Result.Inch;
  Result.MaxLoopFt := 0;
  Result.WastePct := WASTE_PCT_DEFAULT;
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

function FloorArea(const Outline: TP3Array; const Holes: array of TP3Array;
  const F: TRadiantFrame): Double;
var
  P: T2Array;
  I, J: Integer;
begin
  SetLength(P, Length(Outline));
  for I := 0 to High(Outline) do P[I] := RadiantTo2(F, Outline[I]);
  Result := PolyArea2(P);
  for I := 0 to High(Holes) do
  begin
    SetLength(P, Length(Holes[I]));
    for J := 0 to High(Holes[I]) do P[J] := RadiantTo2(F, Holes[I][J]);
    Result := Result - PolyArea2(P);
  end;
end;

function RadiantLoopsNeeded(const Outline: TP3Array; const Holes: array of TP3Array;
  const Spec: TRadiantSpec): Integer;
var
  MaxFt, Each: Double;
begin
  if (Length(Outline) < 3) or (Spec.Spacing <= 0) then Exit(0);
  MaxFt := Spec.MaxLoopFt;
  if MaxFt <= 0 then MaxFt := TubeOf(Spec.Tube).MaxLoopFt;
  Each := MaxFt * Spec.Spacing * LOOP_AREA_FACTOR;
  if Each <= 0 then Exit(0);
  Result := Max(1, Ceil(FloorArea(Outline, Holes, RadiantFrameOf(Outline)) / Each));
end;

procedure RadiantSuggestManifolds(const Outline: TP3Array; const Holes: array of TP3Array;
  const Spec: TRadiantSpec; out At: TP3Array; out Ports: TIntArray);
var
  F: TRadiantFrame;
  Loops, N, I, Each: Integer;
  Umin, Umax, Vmin, Vmax, U, V: Double;
  P: T2;
begin
  SetLength(At, 0); SetLength(Ports, 0);
  if Length(Outline) < 3 then Exit;
  Loops := RadiantLoopsNeeded(Outline, Holes, Spec);
  if Loops <= 0 then Exit;
  N := Max(1, Ceil(Loops / MANIFOLD_PORTS_MAX));
  { a port to spare each: the guess is a guess, and a manifold short a
    port is a second manifold }
  Each := Min(MANIFOLD_PORTS_MAX, Max(MANIFOLD_PORTS_MIN, Ceil(Loops / N) + 1));
  F := RadiantFrameOf(Outline);
  Umin := 1E30; Umax := -1E30; Vmin := 1E30; Vmax := -1E30;
  for I := 0 to High(Outline) do
  begin
    P := RadiantTo2(F, Outline[I]);
    Umin := Min(Umin, P.X); Umax := Max(Umax, P.X);
    Vmin := Min(Vmin, P.Y); Vmax := Max(Vmax, P.Y);
  end;
  { along the long wall - U is the longest edge - a foot in from it, each
    at the middle of its share of the length }
  SetLength(At, N); SetLength(Ports, N);
  V := Vmin + 1;
  for I := 0 to N - 1 do
  begin
    U := Umin + (Umax - Umin) * (I + 0.5) / N;
    At[I] := RadiantFrom2(F, U, V);
    Ports[I] := Each;
  end;
end;

procedure RadiantSuggestZoneManifold(const Zone: TRadiantZone; const Toward: TP3;
  const Spec: TRadiantSpec; out At: TP3; out Ports: Integer);
var
  I, N, Best, Prev, Next: Integer;
  D, BestD, LN, LP: Double;
  ToNext, ToPrev: TP3;
begin
  At := P3(0, 0, 0); Ports := MANIFOLD_PORTS_MIN;
  N := Length(Zone.Outline);
  if N < 3 then Exit;
  Best := 0; BestD := 1E300;
  for I := 0 to N - 1 do
  begin
    D := Dist(Zone.Outline[I], Toward);
    if D < BestD then begin BestD := D; Best := I; end;
  end;
  Next := (Best + 1) mod N; Prev := (Best - 1 + N) mod N;
  ToNext := P3(Zone.Outline[Next].X - Zone.Outline[Best].X, Zone.Outline[Next].Y - Zone.Outline[Best].Y, 0);
  ToPrev := P3(Zone.Outline[Prev].X - Zone.Outline[Best].X, Zone.Outline[Prev].Y - Zone.Outline[Best].Y, 0);
  LN := Max(1E-9, Sqrt(Sqr(ToNext.X) + Sqr(ToNext.Y)));
  LP := Max(1E-9, Sqrt(Sqr(ToPrev.X) + Sqr(ToPrev.Y)));
  At := P3(Zone.Outline[Best].X + ToNext.X / LN + ToPrev.X / LP,
           Zone.Outline[Best].Y + ToNext.Y / LN + ToPrev.Y / LP, Zone.Outline[Best].Z);
  Ports := Min(MANIFOLD_PORTS_MAX, Max(MANIFOLD_PORTS_MIN,
    RadiantLoopsNeeded(Zone.Outline, Zone.Holes, Spec) + 1));
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
  if Length(Spec.Manifolds) = 0 then Exit('Place a manifold - or press Suggest.');
  if Length(Spec.Ports) <> Length(Spec.Manifolds) then Exit('Every manifold wants a size.');
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

{ The frame the layout is worked in, for one manifold: U along the wall
  the manifold is nearest, V away from that wall into the floor - so the
  rows run parallel to the manifold's wall and a loop runs out along a
  row, turns, and comes back. }
function FrameAt(const Outline: TP3Array; const M: TP3): TRadiantFrame;
var
  I, J, Best: Integer;
  D, BestD, BestL, T, L: Double;
  A, B, Q: TP3;
begin
  Result := RadiantFrameOf(Outline);
  BestD := 1E300; Best := 0; BestL := 1E300;
  for I := 0 to High(Outline) do
  begin
    J := (I + 1) mod Length(Outline);
    A := Outline[I]; B := Outline[J];
    L := Sqr(B.X - A.X) + Sqr(B.Y - A.Y) + Sqr(B.Z - A.Z);
    if L < 1E-12 then Continue;
    T := ((M.X - A.X) * (B.X - A.X) + (M.Y - A.Y) * (B.Y - A.Y) + (M.Z - A.Z) * (B.Z - A.Z)) / L;
    T := Max(0, Min(1, T));
    Q := P3(A.X + (B.X - A.X) * T, A.Y + (B.Y - A.Y) * T, A.Z + (B.Z - A.Z) * T);
    D := Dist(M, Q);
    { A manifold in a corner is as near one wall as the other.  It hangs
      on the SHORTER one, so the runs go the zone's long way: fewer,
      longer loops, and half the fan of leads along the wall - twenty
      short loops from one corner is forty tubes leaving it, which is the
      picture that settled this on 23 September. }
    if (D < BestD - 1E-6) or ((Abs(D - BestD) <= 1E-6) and (L < BestL)) then
    begin
      BestD := D; Best := I; BestL := L;
    end;
  end;
  J := (Best + 1) mod Length(Outline);
  Result.Origin := Outline[Best];
  Result.U := VNorm(P3(Outline[J].X - Outline[Best].X, Outline[J].Y - Outline[Best].Y,
    Outline[J].Z - Outline[Best].Z));
  Result.V := VNorm(Cross3(Result.N, Result.U));
  { V into the floor: the outline's middle is on the positive side }
  A := P3(0, 0, 0);
  for I := 0 to High(Outline) do A := P3(A.X + Outline[I].X / Length(Outline),
    A.Y + Outline[I].Y / Length(Outline), A.Z + Outline[I].Z / Length(Outline));
  if Dot3(P3(A.X - Result.Origin.X, A.Y - Result.Origin.Y, A.Z - Result.Origin.Z), Result.V) < 0 then
  begin
    Result.V := P3(-Result.V.X, -Result.V.Y, -Result.V.Z);
    Result.N := P3(-Result.N.X, -Result.N.Y, -Result.N.Z);
  end;
end;

function ComputeRadiantLayout(const Outline: TP3Array; const Holes: array of TP3Array;
  const Spec: TRadiantSpec): TRadiantResult;
var
  F: TRadiantFrame;
  Poly2: T2Array;
  HolePoly: array of T2Array;
  I, J, K, MI, NM: Integer;
  Vmin, Vmax, Umin, Umax, Inset, MaxFt, LimLo, LimHi, HLo, HHi, HV0, HV1: Double;
  M2, O2: T2;
  Loops: TRadiantLoopArray;
  { the rows, and on each row the one span this side of the manifold
    column - the piece the loop's pass covers }
  PolyT: T2Array;
  HoleT: array of T2Array;
  Unfilled: Double;
  Pts: T2Array;
  NPts: Integer;
  ThisSide: Integer;

  function World(const P: T2): TP3;
  begin
    Result := RadiantFrom2(F, P.X, P.Y);
  end;

  procedure Put(X, Y: Double);
  begin
    if (NPts > 0) and (Abs(Pts[NPts - 1].X - X) < 1E-9) and (Abs(Pts[NPts - 1].Y - Y) < 1E-9) then Exit;
    if NPts >= Length(Pts) then SetLength(Pts, NPts * 2 + 16);
    Pts[NPts] := Point2(X, Y); Inc(NPts);
  end;

  { The pieces of column U on this side, straight out from the manifold's
    wall: the near piece, from the wall to the far wall or the first
    obstacle; and the far piece, from the last obstacle to the far wall,
    when an obstacle cuts the column.  Columns are lines of constant U;
    the polygon is turned on its side so RowSpans can walk them. }
  procedure ColumnPieces(U: Double; out NearLo, NearHi, FarLo, FarHi: Double;
    out HasNear, HasFar: Boolean);
  var
    Pieces, Cuts, HoleRow: TSpanArray;
    P, Q, K0: Integer;
  begin
    HasNear := False; HasFar := False;
    NearLo := 0; NearHi := 0; FarLo := 0; FarHi := 0;
    Cuts := nil;
    for P := 0 to High(HoleT) do
    begin
      HoleRow := RowSpans(HoleT[P], U);
      K0 := Length(Cuts);
      SetLength(Cuts, K0 + Length(HoleRow));
      for Q := 0 to High(HoleRow) do Cuts[K0 + Q] := HoleRow[Q];
    end;
    Pieces := Subtract(RowSpans(PolyT, U), Cuts);
    for P := 0 to High(Pieces) do
    begin
      if (Pieces[P].Lo <= M2.Y + Inset) and (Pieces[P].Hi > M2.Y + Inset) then
      begin
        NearLo := Max(Pieces[P].Lo, M2.Y) + Inset;
        if Pieces[P].Hi >= Vmax - 1E-6 then NearHi := Pieces[P].Hi - Inset else NearHi := Pieces[P].Hi;
        HasNear := NearHi - NearLo > Spec.Spacing;
      end
      else if Pieces[P].Hi >= Vmax - 1E-6 then
      begin
        FarLo := Pieces[P].Lo;
        FarHi := Pieces[P].Hi - Inset;
        HasFar := FarHi - FarLo > Spec.Spacing;
      end;
    end;
    { a clear column is one near piece to the far wall: no far piece then }
    if HasNear and (NearHi >= Vmax - Inset - 1E-6) then HasFar := False;
  end;

  { Lay one side of the manifold: columns out from its wall, the first a
    half spacing off the manifold, loop after loop outward; each loop as
    many pairs of columns - out on one, back on the next - as the
    maximum allows, measured as laid.  A column cut by an obstacle turns
    at it; the far side of the obstacle is reached the way the owner
    described: a loop out on a clear column past it turns into the
    blocked column's far piece, serpentines the far pieces of the
    blocked columns beside it, and comes home down the next clear
    column; the near pieces below the obstacle are paired by a loop of
    their own after.  Every loop leaves by its own port, runs along the
    wall in the fan to its first column, and comes home the same way;
    the fan is the only tube off the grid.  Laterals are stacked by how
    far out the loop's columns are - the nearest highest - so a lateral
    passes only under columns nearer the manifold than its own, above
    their laterals and below where they start. }
  procedure LaySide(SideK: Integer);
  type
    TPlan = record
      Cols: array of Integer;      { the columns, in walking order }
      Far: array of Boolean;       { the far piece of that column, not the near }
      FirstCol: Integer;
      Rank: Integer;
    end;
  var
    C, N, Loop, NL, Q, Dir, R, M, I2: Integer;
    U, PortU, PortR, VUp, VDn, VStart, PortPitch, Y0, Y1, Turn: Double;
    ColU, NLo, NHi, FLo, FHi: array of Double;
    HasN, HasF, UsedN, UsedF: array of Boolean;
    Plans: array of TPlan;
    P: TPlan;
    L: TRadiantLoop;
    Sign: Integer;
    FitsMore: Boolean;

    { the length of a plan as laid from this lateral height }
    function LayPlan(const Pl: TPlan; PortU_, PortR_, VUp_, VDn_, VStart_: Double; out L: TRadiantLoop): Double;
    var
      J, Cc: Integer;
      Y0_, Y1_: Double;
      Bot, Top: array of Double;
      Down: Boolean;
    begin
      NPts := 0;
      Put(PortU_, M2.Y);
      Put(PortU_, VUp_);
      Put(ColU[Pl.Cols[0]], VUp_);
      { each column's bottom and top, then every turn leveled: going out
        the two columns turn at the lower of their tops, coming back at
        the higher of their bottoms - a turn is always level }
      SetLength(Bot, Length(Pl.Cols)); SetLength(Top, Length(Pl.Cols));
      for J := 0 to High(Pl.Cols) do
      begin
        Cc := Pl.Cols[J];
        if Pl.Far[J] then begin Bot[J] := FLo[Cc]; Top[J] := FHi[Cc]; end
        else begin Bot[J] := Max(VStart_, NLo[Cc]); Top[J] := NHi[Cc]; end;
      end;
      Down := False;
      for J := 0 to High(Pl.Cols) - 1 do
      begin
        if not Down then begin Top[J] := Min(Top[J], Top[J + 1]); Top[J + 1] := Top[J]; end
        else begin Bot[J] := Max(Bot[J], Bot[J + 1]); Bot[J + 1] := Bot[J]; end;
        Down := not Down;
      end;
      Down := False;   { the first column is walked out, away from the wall }
      for J := 0 to High(Pl.Cols) do
      begin
        Cc := Pl.Cols[J];
        if Down then begin Y0_ := Top[J]; Y1_ := Bot[J]; end else begin Y0_ := Bot[J]; Y1_ := Top[J]; end;
        Put(ColU[Cc], Y0_);
        Put(ColU[Cc], Y1_);
        Down := not Down;
      end;
      Put(ColU[Pl.Cols[High(Pl.Cols)]], VDn_);
      Put(PortR_, VDn_);
      Put(PortR_, M2.Y);
      SetLength(L.Pts, NPts);
      for J := 0 to NPts - 1 do L.Pts[J] := World(Pts[J]);
      L.LenFt := 0;
      for J := 1 to High(L.Pts) do L.LenFt := L.LenFt + Dist(L.Pts[J - 1], L.Pts[J]);
      Result := L.LenFt;
    end;

    { the plan from column C: out on C; then either the excursion round
      an obstacle, or pairs of near pieces, as many as fit }
    function PlanFrom(C: Integer; out Pl: TPlan): Boolean;
    var
      Cc, M, J: Integer;
      Lt: TRadiantLoop;
      Trial: TPlan;
    begin
      Result := False;
      SetLength(Pl.Cols, 0); SetLength(Pl.Far, 0);
      if not HasN[C] or UsedN[C] then Exit;
      Pl.FirstCol := C;
      SetLength(Pl.Cols, 1); SetLength(Pl.Far, 1);
      Pl.Cols[0] := C; Pl.Far[0] := False;
      Cc := C;
      repeat
        { the column after Cc }
        if Cc + 1 > High(ColU) then Break;
        if not Pl.Far[High(Pl.Far)] and (NHi[Cc] >= Vmax - Inset - 1E-6) then
        begin
          { we are at the far wall on a clear column: an obstacle's far
            side beside us?  even so many far pieces, then a clear column
            home }
          M := 0;
          while (Cc + 1 + M <= High(ColU)) and HasF[Cc + 1 + M] and not UsedF[Cc + 1 + M] do Inc(M);
          if M mod 2 = 1 then Dec(M);
          if (M >= 2) and (Cc + 1 + M <= High(ColU)) and HasN[Cc + 1 + M] and not UsedN[Cc + 1 + M] and
             (NHi[Cc + 1 + M] >= Vmax - Inset - 1E-6) then
          begin
            Trial := Pl;
            SetLength(Trial.Cols, Length(Pl.Cols) + M + 1);
            SetLength(Trial.Far, Length(Pl.Far) + M + 1);
            for J := 1 to M do
            begin
              Trial.Cols[High(Pl.Cols) + J] := Cc + J; Trial.Far[High(Pl.Far) + J] := True;
            end;
            Trial.Cols[High(Trial.Cols)] := Cc + 1 + M; Trial.Far[High(Trial.Far)] := False;
            if LayPlan(Trial, M2.X, M2.X, M2.Y + Inset / 2, M2.Y + Inset / 2 + PortPitch,
                 M2.Y + Inset / 2 + 2 * PortPitch, Lt) <= MaxFt then
            begin
              Pl := Trial;
              Cc := Cc + 1 + M;
              Result := True;
              Continue;
            end;
          end;
        end;
        { a plain pair: the next near piece back, if it fits }
        if (Cc + 1 <= High(ColU)) and HasN[Cc + 1] and not UsedN[Cc + 1] and
           (Length(Pl.Cols) mod 2 = 1) then
        begin
          Trial := Pl;
          SetLength(Trial.Cols, Length(Pl.Cols) + 1); SetLength(Trial.Far, Length(Pl.Far) + 1);
          Trial.Cols[High(Trial.Cols)] := Cc + 1; Trial.Far[High(Trial.Far)] := False;
          if LayPlan(Trial, M2.X, M2.X, M2.Y + Inset / 2, M2.Y + Inset / 2 + PortPitch,
               M2.Y + Inset / 2 + 2 * PortPitch, Lt) <= MaxFt then
          begin
            Pl := Trial; Cc := Cc + 1; Result := True;
            { and out again on the one after, if that pair would fit - but
              not onto a clear column that has an obstacle's far side just
              beyond it: that column is the next loop's way out to those
              far pieces, and it must go out on it, not come back on it }
            if (Cc + 2 <= High(ColU)) and HasN[Cc + 1] and not UsedN[Cc + 1] and HasN[Cc + 2] and not UsedN[Cc + 2] and
               not ((NHi[Cc + 2] >= Vmax - Inset - 1E-6) and (Cc + 3 <= High(ColU)) and HasF[Cc + 3] and not UsedF[Cc + 3]) then
            begin
              Trial := Pl;
              SetLength(Trial.Cols, Length(Pl.Cols) + 2); SetLength(Trial.Far, Length(Pl.Far) + 2);
              Trial.Cols[High(Trial.Cols) - 1] := Cc + 1; Trial.Far[High(Trial.Far) - 1] := False;
              Trial.Cols[High(Trial.Cols)] := Cc + 2; Trial.Far[High(Trial.Far)] := False;
              if LayPlan(Trial, M2.X, M2.X, M2.Y + Inset / 2, M2.Y + Inset / 2 + PortPitch,
                   M2.Y + Inset / 2 + 2 * PortPitch, Lt) <= MaxFt then
              begin
                Pl := Trial; Cc := Cc + 2;
                Continue;
              end;
            end;
            Break;
          end;
        end;
        Break;
      until False;
      { an odd number of near columns cannot come home: drop the last }
      if Result and (Length(Pl.Cols) mod 2 = 1) then
      begin
        SetLength(Pl.Cols, Length(Pl.Cols) - 1); SetLength(Pl.Far, Length(Pl.Far) - 1);
        Result := Length(Pl.Cols) >= 2;
      end;
    end;

  begin
    if SideK = 0 then Sign := -1 else Sign := 1;
    PortPitch := MANIFOLD_PORT_PITCH_IN * Spec.Inch;
    SetLength(ColU, 0);
    C := 0;
    repeat
      U := M2.X + Sign * (Spec.Spacing / 2 + C * Spec.Spacing);
      if (U < Umin + Inset) or (U > Umax - Inset) then Break;
      SetLength(ColU, C + 1); SetLength(NLo, C + 1); SetLength(NHi, C + 1);
      SetLength(FLo, C + 1); SetLength(FHi, C + 1); SetLength(HasN, C + 1); SetLength(HasF, C + 1);
      ColU[C] := U;
      ColumnPieces(U, NLo[C], NHi[C], FLo[C], FHi[C], HasN[C], HasF[C]);
      Inc(C);
    until C > 4000;
    N := Length(ColU);
    if N < 2 then Exit;
    SetLength(UsedN, N); SetLength(UsedF, N);

    { the plans: from the manifold outward, each taking what it can }
    SetLength(Plans, 0);
    C := 0;
    while C <= High(ColU) do
    begin
      if PlanFrom(C, P) then
      begin
        for Q := 0 to High(P.Cols) do
          if P.Far[Q] then UsedF[P.Cols[Q]] := True else UsedN[P.Cols[Q]] := True;
        SetLength(Plans, Length(Plans) + 1);
        Plans[High(Plans)] := P;
        { the next unused near piece }
        Inc(C);
        while (C <= High(ColU)) and (not HasN[C] or UsedN[C]) do Inc(C);
      end
      else Inc(C);
    end;
    { what nothing took }
    for C := 0 to High(ColU) do
    begin
      if HasN[C] and not UsedN[C] then Unfilled := Unfilled + (NHi[C] - NLo[C]) * Spec.Spacing;
      if HasF[C] and not UsedF[C] then Unfilled := Unfilled + (FHi[C] - FLo[C]) * Spec.Spacing;
    end;

    { laterals by how far out each plan's first column is: the nearest
      the highest }
    NL := Length(Plans);
    for I2 := 0 to NL - 1 do
    begin
      R := 0;
      for M := 0 to NL - 1 do
        if (M <> I2) and ((Plans[M].FirstCol < Plans[I2].FirstCol) or
           ((Plans[M].FirstCol = Plans[I2].FirstCol) and (M < I2))) then Inc(R);
      Plans[I2].Rank := R;
    end;
    for I2 := 0 to NL - 1 do
    begin
      R := Plans[I2].Rank;
      VUp := M2.Y + Inset / 2 + (2 * (NL - 1 - R)) * PortPitch;
      VDn := VUp + PortPitch;
      VStart := VDn + PortPitch;
      PortU := M2.X + Sign * (2 * R + 1) * PortPitch;
      PortR := M2.X + Sign * (2 * R + 2) * PortPitch;
      LayPlan(Plans[I2], PortU, PortR, VUp, VDn, VStart, L);
      L.Manifold := MI;
      SetLength(Loops, Length(Loops) + 1);
      Loops[High(Loops)] := L;
    end;
  end;

begin
  Result := Default(TRadiantResult);
  Result.Why := RadiantProblem(Outline, Spec);
  Result.Ok := Result.Why = '';
  if not Result.Ok then Exit;
  MaxFt := Spec.MaxLoopFt;
  if MaxFt <= 0 then MaxFt := TubeOf(Spec.Tube).MaxLoopFt;
  Inset := EDGE_INSET_IN * Spec.Inch;

  Result.TurnActualIn := Spec.Spacing / Spec.Inch;
  Result.TurnMinIn := 2 * TubeOf(Spec.Tube).MinBendIn;
  Result.TurnMinPexAIn := 2 * TubeOf(Spec.Tube).OdIn * 6;
  Result.ObstacleCount := Length(Holes);
  NM := Length(Spec.Manifolds);
  SetLength(Result.Manifolds, NM);
  SetLength(Loops, 0);
  Unfilled := 0;
  SetLength(Pts, 64);

  for MI := 0 to NM - 1 do
  begin
    Result.Manifolds[MI].At := Spec.Manifolds[MI];
    F := FrameAt(Outline, Spec.Manifolds[MI]);
    SetLength(Poly2, Length(Outline));
    Vmin := 1E30; Vmax := -1E30; Umin := 1E30; Umax := -1E30;
    for I := 0 to High(Outline) do
    begin
      Poly2[I] := RadiantTo2(F, Outline[I]);
      Vmin := Min(Vmin, Poly2[I].Y); Vmax := Max(Vmax, Poly2[I].Y);
      Umin := Min(Umin, Poly2[I].X); Umax := Max(Umax, Poly2[I].X);
    end;
    SetLength(HolePoly, Length(Holes));
    for I := 0 to High(Holes) do
    begin
      SetLength(HolePoly[I], Length(Holes[I]));
      for J := 0 to High(Holes[I]) do HolePoly[I][J] := RadiantTo2(F, Holes[I][J]);
    end;
    if MI = 0 then
    begin
      Result.AreaSqFt := PolyArea2(Poly2);
      for I := 0 to High(HolePoly) do Result.AreaSqFt := Result.AreaSqFt - PolyArea2(HolePoly[I]);
    end;
    M2 := RadiantTo2(F, Spec.Manifolds[MI]);
    M2.Y := Max(Vmin + Inset / 2, Min(Vmax - Inset / 2, M2.Y));
    { the halfway lines to the other manifolds along this wall: this
      one's rows stop there }
    LimLo := -1E300; LimHi := 1E300;
    for I := 0 to NM - 1 do
      if I <> MI then
      begin
        O2 := RadiantTo2(F, Spec.Manifolds[I]);
        if O2.X < M2.X then LimLo := Max(LimLo, (O2.X + M2.X) / 2 - Inset / 2)
        else if O2.X > M2.X then LimHi := Min(LimHi, (O2.X + M2.X) / 2 + Inset / 2);
      end;

    { the polygon and the holes turned on their side, so a column is a
      row to RowSpans }
    SetLength(PolyT, Length(Poly2));
    for I := 0 to High(Poly2) do PolyT[I] := Point2(Poly2[I].Y, Poly2[I].X);
    { each obstacle as its box, a hand's width bigger all round, turned
      on its side - so a column keeps off it sideways as well as at the
      end of its run }
    SetLength(HoleT, Length(HolePoly));
    for I := 0 to High(HolePoly) do
    begin
      HLo := 1E300; HHi := -1E300; HV0 := 1E300; HV1 := -1E300;
      for J := 0 to High(HolePoly[I]) do
      begin
        HLo := Min(HLo, HolePoly[I][J].X); HHi := Max(HHi, HolePoly[I][J].X);
        HV0 := Min(HV0, HolePoly[I][J].Y); HV1 := Max(HV1, HolePoly[I][J].Y);
      end;
      SetLength(HoleT[I], 4);
      HoleT[I][0] := Point2(HV0 - Inset, HLo - Inset);
      HoleT[I][1] := Point2(HV1 + Inset, HLo - Inset);
      HoleT[I][2] := Point2(HV1 + Inset, HHi + Inset);
      HoleT[I][3] := Point2(HV0 - Inset, HHi + Inset);
    end;
    { the manifold hangs on its wall: its line is the wall's inset }
    M2.Y := Vmin;
    Result.RowCount := Max(1, Floor(((Umax - Umin) - 2 * Inset) / Spec.Spacing));
    K := Length(Loops);
    LaySide(0);
    LaySide(1);
    Result.Manifolds[MI].LoopCount := Length(Loops) - K;
    Result.Manifolds[MI].Ports := Max(MANIFOLD_PORTS_MIN, Length(Loops) - K);
    Result.Manifolds[MI].Ft := 0;
    for I := K to High(Loops) do Result.Manifolds[MI].Ft := Result.Manifolds[MI].Ft + Loops[I].LenFt;
  end;

  Result.Loops := Loops;
  Result.CellCount := 0;
  Result.Crossings := 0;
  Result.UnfilledSqFt := Unfilled;
  Result.TotalFt := 0;
  for I := 0 to High(Loops) do Result.TotalFt := Result.TotalFt + Loops[I].LenFt;
  Result.OrderFt := Result.TotalFt * (1 + Spec.WastePct / 100);
  if Length(Loops) = 0 then
  begin
    Result.Ok := False;
    Result.Why := 'No loop fits - the floor is narrower than a run and back, or the maximum is too short.';
  end;
end;

function BuildRadiant(D: TWorkDoc; const Outline: TP3Array; const Holes: array of TP3Array;
  const R: TRadiantResult; const Spec: TRadiantSpec; Ink: TColor; PartName: string;
  Zone: Integer = 0): Integer;
var
  I, J, G, M: Integer;
  Mid: TP3;
  F: TRadiantFrame;
  W, H: Double;
  C: array[0..3] of TP3;
  Nth: TIntArray;
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
  { each manifold is a zone in its own color; its loops alternate thick
    and thin so two side by side can be told apart; and each carries its
    number and length where it enters the field, since a plan with the
    footage on it is the plan a fitter wants }
  SetLength(Nth, Length(R.Manifolds));
  for I := 0 to High(R.Loops) do
  begin
    M := R.Loops[I].Manifold;
    for J := 1 to High(R.Loops[I].Pts) do
      D.AddLine(R.Loops[I].Pts[J - 1], R.Loops[I].Pts[J], ZoneInk(Zone + M), LoopWeight(Nth[M]), True);
    if Spec.Labels and (Length(R.Loops[I].Pts) > 3) then
    begin
      Mid := R.Loops[I].Pts[Length(R.Loops[I].Pts) div 2];
      D.AddNote(Mid, Mid, Format('Z%d L%d  %s', [Zone + M + 1, Nth[M] + 1,
        FormatLen(R.Loops[I].LenFt, usImperial)]), ZoneInk(Zone + M));
    end;
    Inc(Nth[M]);
  end;
  for I := 0 to High(Holes) do
    if Length(Holes[I]) > 0 then
    begin
      Mid := P3(0, 0, 0);
      for J := 0 to High(Holes[I]) do
        Mid := P3(Mid.X + Holes[I][J].X / Length(Holes[I]), Mid.Y + Holes[I][J].Y / Length(Holes[I]),
          Mid.Z + Holes[I][J].Z / Length(Holes[I]));
      if Spec.Labels then D.AddNote(P3(Mid.X, Mid.Y, Mid.Z), Mid, 'no tube - obstacle', Ink);
    end;
  { each manifold: a small box on the floor where it sits, square to the
    outline's own frame, hard-edged so it reads as a thing and not a run }
  F := RadiantFrameOf(Outline);
  for M := 0 to High(R.Manifolds) do
    if (Spec.ManifoldW > 0) and (Spec.ManifoldH > 0) then
    begin
      { wide enough for its ports, two a loop at the port pitch each side }
      W := Max(Spec.ManifoldW, (2 * R.Manifolds[M].LoopCount + 2) * MANIFOLD_PORT_PITCH_IN * Spec.Inch) / 2;
      H := Spec.ManifoldH / 2;
      Mid := R.Manifolds[M].At;
      C[0] := P3(Mid.X - F.U.X * W - F.V.X * H, Mid.Y - F.U.Y * W - F.V.Y * H, Mid.Z - F.U.Z * W - F.V.Z * H);
      C[1] := P3(Mid.X + F.U.X * W - F.V.X * H, Mid.Y + F.U.Y * W - F.V.Y * H, Mid.Z + F.U.Z * W - F.V.Z * H);
      C[2] := P3(Mid.X + F.U.X * W + F.V.X * H, Mid.Y + F.U.Y * W + F.V.Y * H, Mid.Z + F.U.Z * W + F.V.Z * H);
      C[3] := P3(Mid.X - F.U.X * W + F.V.X * H, Mid.Y - F.U.Y * W + F.V.Y * H, Mid.Z - F.U.Z * W + F.V.Z * H);
      for I := 0 to 3 do D.AddLine(C[I], C[(I + 1) mod 4], ZoneInk(Zone + M), 2, False);
      if Spec.Labels then
        D.AddNote(C[2], Mid, Format('zone %d manifold - %d loops', [Zone + M + 1,
          R.Manifolds[M].LoopCount]), ZoneInk(Zone + M));
    end;
  { an obstacle added in the wizard goes onto the floor as a ring of plain
    lines; lying flat inside the face, the program's own rule makes it a
    hole, the same as one drawn by hand }
  if Zone = 0 then
    for I := 0 to High(Spec.Extra) do
      for J := 0 to High(Spec.Extra[I]) do
        D.AddLine(Spec.Extra[I][J], Spec.Extra[I][(J + 1) mod Length(Spec.Extra[I])], Ink, 1, False);
  D.Stamp := 0;
end;

function RadiantTicketText(const Spec: TRadiantSpec; const R: TRadiantResult;
  U: TUnitSystem): string;
var
  I, M: Integer;
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
    ' ft maximum each, on ' + IntToStr(Length(R.Manifolds)) + ' manifold(s)' + LineEnding;
  for M := 0 to High(R.Manifolds) do
  begin
    Result := Result + Format('manifold %d: a %d-loop%s', [M + 1, R.Manifolds[M].Ports,
      IfThen(R.Manifolds[M].Ports > MANIFOLD_PORTS_MAX, ' - MORE THAN ' + IntToStr(MANIFOLD_PORTS_MAX) +
        ': split the zone with a line',
      IfThen(R.Manifolds[M].LoopCount = 0, '  - nothing near it', ''))]) + LineEnding;
    for I := 0 to High(R.Loops) do
      if R.Loops[I].Manifold = M then
        Result := Result + Format('  loop %d: %s%s', [I + 1, FormatLen(R.Loops[I].LenFt, U),
          IfThen(R.Loops[I].LenFt > MaxFt, '  - OVER the maximum for this tube', '')]) + LineEnding;
  end;
  Result := Result + 'total tube, no waste: ' + FormatLen(R.TotalFt, U) + LineEnding;
  Result := Result + 'order (with ' + FormatFloat('0', Spec.WastePct) + '% waste): ' +
    FormatLen(R.OrderFt, U) + LineEnding;
  { R.TotalFt is feet already; times 12 is inches of run, over the tie
    spacing in inches is how many ties that run wants }
  Ties := Round(R.TotalFt * 12 / TIE_SPACING_IN);
  Result := Result + 'ties or staples (estimate, every ' + FormatFloat('0', TIE_SPACING_IN) +
    '"): about ' + IntToStr(Ties) + LineEnding;
  Result := Result + 'manifold ports needed, all told: ' + IntToStr(Length(R.Loops)) + LineEnding;
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
  if R.UnfilledSqFt > 1 then
    Result := Result + Format('not reached: about %s - a lone row, or the far side of an obstacle', [FormatArea(R.UnfilledSqFt, U)]) + LineEnding;
  Result := Result + LineEnding + 'Flow rate and pump sizing are not worked out here - they ' +
    'come from a room-by-room heat loss, not from the tube size alone.' + LineEnding;
end;

end.
