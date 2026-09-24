unit uRadiant;

{ The radiant heat layout tool: given the outline of a floor - a rectangle,
  or any closed face with as many corners as the room has - and one point
  for the manifold, fill it with tube.

  The area is cut into rows at the tube's spacing, out from the manifold's
  own row in both directions when it is not pinned to a wall.  Where a
  hole in the selected face - an elevator shaft, a column, a chase -
  crosses a row, the row is cut around it, the near piece toward the
  manifold and the far piece past the obstacle kept apart, the way a hole
  already cuts a lane out of a face's own area everywhere else in this
  program.

  A loop over 300 feet of 1/2" tube runs too much pressure drop to heat
  evenly - see uRadiantData for the whole table, by tube size - so every
  loop is a manifold-to-manifold round trip built up a row-pair at a time
  and checked against that limit as it grows, the return leg included, not
  a coverage path cut apart afterward.  Which lane a loop takes from the
  manifold to its rows is not assumed either: it is grown, outermost rank
  first, and a candidate is kept only once it is checked - the identical
  segment-by-segment test the finished ticket's own crossing count runs -
  against every run of tube already laid for that manifold.  One turned
  back for crossing tries the next position in, out to in, until one is
  clean or the row has nothing left to give.  Loop after loop outward from
  the manifold's own row this way, the shallowest reaching the least width
  of its own row so the ranks after it have room to nest inside it.

  A layout that looks wrong in one spot does not have to be thrown out
  whole.  A temporary obstacle - drawn the same way a real one is read,
  as a hole, but kept only in the dialog and never written to the sheet
  unless the person asks - keeps every loop clear of whatever was circled,
  and the rest of the floor is free to be laid out again around it.

  The search restarts with both row directions and shorter first-loop
  budgets, and scores the floor actually reached by the finished tube,
  circuit count and length spread. A local fan may grow to three feet;
  field rows keep their requested pitch. This remains a bounded heuristic,
  not a guarantee that every reachable part of an arbitrary floor is filled.

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
    Tube: TTubeSize;
    Spacing: Double;          { world units (feet) - on center }
    MaxLoopFt: Double;        { 0 = the tube's own table maximum }
    WastePct: Double;
    { the manifolds, where they stand and how many loops each takes; a
      loop goes to the nearest.  Extra is what the wizard added as
      obstacles over what the face already had as holes. }
    Manifolds: TP3Array;
    Ports: TIntArray;             { legacy hint only; routing sizes the manifold afterward }
    Extra: TRadiantHoles;
    ManifoldW, ManifoldH: Double;   { the little box drawn for each }
    { the slab }
    SlabThick: Double;
    TubeDepth: Double;        { 0 = centered in the slab }
    UnderR: Double;
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

  { one lane the search tried, in the order it tried them, for whoever
    wants to watch it work rather than just see what it settled on -
    kept only when asked for (see WantTrace on ComputeRadiantLayout
    below), since building it costs a real search's worth of geometry
    a second time over }
  TRadiantTraceStep = record
    Pts: TP3Array;             { the candidate loop, exactly as it would be kept }
    Accepted: Boolean;         { kept, or turned back for crossing tube already down }
  end;
  TRadiantTrace = array of TRadiantTraceStep;

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
    { every lane the search tried to reach this - empty unless asked
      for with WantTrace }
    Trace: TRadiantTrace;
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
function SegsMeet(const P0, P1, Q0, Q1: T2): Boolean;
function RadiantInside(const Outline: TP3Array; const P: TP3): Boolean;

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
  as a temporary one while the person tries a different route.
  WantTrace fills Result.Trace with every lane the search tried, not
  just the ones it kept - off by default, since it costs a search's
  worth of extra geometry, and nothing wants it but a person watching. }
function ComputeRadiantLayout(const Outline: TP3Array; const Holes: array of TP3Array;
  const Spec: TRadiantSpec; WantTrace: Boolean = False): TRadiantResult;

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

{ Is the point inside the outline, seen from above the floor's own
  plane - not the world's.  This used to test Outline[I].X/Y and P.X/Y
  directly: invisible on an ordinary horizontal slab, since ray
  casting does not care which way a flat polygon is rotated, but
  wrong on a floor that is not flat in world X/Y (a sloped pour, or a
  face picked by mistake) - the outline and the point could disagree
  about which plane they are even in.  Working in the frame both the
  layout and the plan already share removes the assumption instead of
  relying on every floor happening to be flat the convenient way. }
function RadiantInside(const Outline: TP3Array; const P: TP3): Boolean;
var
  F: TRadiantFrame;
  Poly: T2Array;
  Pt: T2;
  I, J, N: Integer;
begin
  Result := False;
  N := Length(Outline);
  if N < 3 then Exit;
  F := RadiantFrameOf(Outline);
  SetLength(Poly, N);
  for I := 0 to N - 1 do Poly[I] := RadiantTo2(F, Outline[I]);
  Pt := RadiantTo2(F, P);
  J := N - 1;
  for I := 0 to N - 1 do
  begin
    if ((Poly[I].Y > Pt.Y) <> (Poly[J].Y > Pt.Y)) and
       (Pt.X < (Poly[J].X - Poly[I].X) * (Pt.Y - Poly[I].Y) / (Poly[J].Y - Poly[I].Y) + Poly[I].X) then
      Result := not Result;
    J := I;
  end;
end;

{ Do the closed segments P0-P1 and Q0-Q1 share any point - a crossing, a
  touch, or a length run together?  Two runs of tube in a slab may do
  none of them. }
function SegsMeet(const P0, P1, Q0, Q1: T2): Boolean;
const
  E = 1E-7;

  function Orient(const P, Q, R: T2): Double;
  begin
    Result := (Q.X - P.X) * (R.Y - P.Y) - (Q.Y - P.Y) * (R.X - P.X);
  end;

  function OnSeg(const P, Q, R: T2): Boolean;   { R on P-Q, given collinear }
  begin
    Result := (R.X >= Min(P.X, Q.X) - E) and (R.X <= Max(P.X, Q.X) + E) and
              (R.Y >= Min(P.Y, Q.Y) - E) and (R.Y <= Max(P.Y, Q.Y) + E);
  end;

var
  D1, D2, D3, D4: Double;
begin
  D1 := Orient(Q0, Q1, P0); D2 := Orient(Q0, Q1, P1);
  D3 := Orient(P0, P1, Q0); D4 := Orient(P0, P1, Q1);
  if (((D1 > E) and (D2 < -E)) or ((D1 < -E) and (D2 > E))) and
     (((D3 > E) and (D4 < -E)) or ((D3 < -E) and (D4 > E))) then Exit(True);
  if (Abs(D1) <= E) and OnSeg(Q0, Q1, P0) then Exit(True);
  if (Abs(D2) <= E) and OnSeg(Q0, Q1, P1) then Exit(True);
  if (Abs(D3) <= E) and OnSeg(P0, P1, Q0) then Exit(True);
  if (Abs(D4) <= E) and OnSeg(P0, P1, Q1) then Exit(True);
  Result := False;
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
  MaxFt := Spec.MaxLoopFt;
  if MaxFt <= 0 then MaxFt := TubeOf(Spec.Tube).MaxLoopFt;
  if MaxFt < 20 then Exit('The maximum loop length has to read as a size.');
  if Spec.SlabThick <= 0 then Exit('The slab thickness has to read as a size.');
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

function ComputeRadiantOriented(const Outline: TP3Array; const Holes: array of TP3Array;
  const Spec: TRadiantSpec; WantTrace, Turn: Boolean; FirstBudget, FanIn: Double; ExtraRanks: Integer): TRadiantResult;
var
  F: TRadiantFrame;
  SwapAxis: TP3;
  Poly2: T2Array;
  HolePoly: array of T2Array;
  I, J, K, MI, NM: Integer;
  Vmin, Vmax, Umin, Umax, Inset, MaxFt, LimLo, LimHi, HLo, HHi, HV0, HV1: Double;
  M2, O2: T2;
  Loops: TRadiantLoopArray;
  { the rows, and on each row the one span this side of the manifold
    column - the piece the loop's pass covers }
  HoleB: array of T2Array;
  Unfilled: Double;
  Pts: T2Array;
  NPts: Integer;
  { every lane tried for the manifold currently being laid out, in
    order - LayManifold resets this once per T it tries and keeps a
    copy alongside whichever T wins; Trace is what actually survives,
    across every manifold this call lays out }
  CurTrace, Trace: TRadiantTrace;

  function World(const P: T2): TP3;
  begin
    Result := RadiantFrom2(F, P.X, P.Y);
  end;

  function InsidePoly(const Poly: T2Array; const P: T2): Boolean;
  var
    A, B: Integer;
  begin
    Result := False;
    B := High(Poly);
    for A := 0 to High(Poly) do
    begin
      if SegsMeet(P, P, Poly[A], Poly[B]) then Exit(True);
      if ((Poly[A].Y > P.Y) <> (Poly[B].Y > P.Y)) and
        (P.X < (Poly[B].X - Poly[A].X) * (P.Y - Poly[A].Y) /
          (Poly[B].Y - Poly[A].Y) + Poly[A].X) then Result := not Result;
      B := A;
    end;
  end;

  procedure Put(X, Y: Double);
  begin
    if (NPts > 0) and (Abs(Pts[NPts - 1].X - X) < 1E-9) and (Abs(Pts[NPts - 1].Y - Y) < 1E-9) then Exit;
    if NPts >= Length(Pts) then SetLength(Pts, NPts * 2 + 16);
    Pts[NPts] := Point2(X, Y); Inc(NPts);
  end;

  { The pieces of row V on this side of the manifold, along the wall:
    the near piece, from the manifold out to the far end of the floor or
    the first obstacle; and the far piece, from the last obstacle to the
    far end, when an obstacle cuts the row.  In D - distance from the
    manifold along this side - so both sides read the same way.  The
    floor's spans are pulled in a hand's width at their ends; an
    obstacle's box already stands that much bigger. }
  { Shared by routing and scoring, including every piece between holes. }
  procedure RowBounds(V: Double; out Outer, Cuts: TSpanArray);
  var
    P, Q, K, K0: Integer;
    HoleRow: TSpanArray;
    T: TSpan;
  begin
    { an obstacle cuts the row where its own outline does, a hand's
      width wider each way, and where it does within a hand's width
      above or below - sampled, so a round one is round and not its
      box }
    Cuts := nil;
    for P := 0 to High(HolePoly) do
      for K := -2 to 2 do
      begin
        HoleRow := RowSpans(HolePoly[P], V + K * Inset / 2);
        K0 := Length(Cuts);
        SetLength(Cuts, K0 + Length(HoleRow));
        for Q := 0 to High(HoleRow) do
        begin
          Cuts[K0 + Q].Lo := HoleRow[Q].Lo - Inset;
          Cuts[K0 + Q].Hi := HoleRow[Q].Hi + Inset;
        end;
      end;
    for P := 1 to High(Cuts) do
    begin
      T := Cuts[P]; K := P;
      while (K > 0) and (Cuts[K - 1].Lo > T.Lo) do begin Cuts[K] := Cuts[K - 1]; Dec(K); end;
      Cuts[K] := T;
    end;
    { and overlapping cuts made one, so a piece's edge is a real edge }
    K := 0;
    for P := 1 to High(Cuts) do
      if Cuts[P].Lo <= Cuts[K].Hi + 1E-9 then Cuts[K].Hi := Max(Cuts[K].Hi, Cuts[P].Hi)
      else begin Inc(K); Cuts[K] := Cuts[P]; end;
    if Length(Cuts) > 0 then SetLength(Cuts, K + 1);
    Outer := RowSpans(Poly2, V);
    for P := 0 to High(Outer) do
    begin
      Outer[P].Lo := Outer[P].Lo + Inset; Outer[P].Hi := Outer[P].Hi - Inset;
    end;
  end;

  procedure RowPieces(V: Double; Sign: Integer; out EdgeD, NearLo, NearHi, FarLo, FarHi: Double;
    out HasNear, HasFar: Boolean);
  var
    Pieces, Cuts, Outer: TSpanArray;
    P, Q, K: Integer;
    Lo, Hi, StartU: Double;
    CutEdge, First: Boolean;
  begin
    HasNear := False; HasFar := False;
    NearLo := 0; NearHi := 0; FarLo := 0; FarHi := 0; EdgeD := 1E300;
    RowBounds(V, Outer, Cuts);
    { where the floor's own edge is on this side, obstacles or not: the
      first outer span on this side, or the one the manifold is in }
    for P := 0 to High(Outer) do
    begin
      if Sign > 0 then begin Lo := Outer[P].Lo - M2.X; Hi := Outer[P].Hi - M2.X; end
      else begin Lo := M2.X - Outer[P].Hi; Hi := M2.X - Outer[P].Lo; end;
      if Hi <= 0 then Continue;
      EdgeD := Min(EdgeD, Max(0, Lo));
    end;
    Pieces := Subtract(Outer, Cuts);
    { in D: the near piece is the first on this side, when it begins at
      the floor's own edge and not past an obstacle - a slanting wall
      can put that edge a way out from the manifold; the far piece is
      the last one, when an obstacle is what it begins past }
    First := True;
    for K := 0 to High(Pieces) do
    begin
      { in order of distance from the manifold: which is the other way
        along U on the far side }
      if Sign > 0 then P := K else P := High(Pieces) - K;
      if Sign > 0 then begin Lo := Pieces[P].Lo - M2.X; Hi := Pieces[P].Hi - M2.X; StartU := Pieces[P].Lo; end
      else begin Lo := M2.X - Pieces[P].Hi; Hi := M2.X - Pieces[P].Lo; StartU := Pieces[P].Hi; end;
      if Hi <= Spec.Spacing then Continue;
      CutEdge := False;
      for Q := 0 to High(Cuts) do
        if (Abs(Cuts[Q].Hi - StartU) < 1E-6) or (Abs(Cuts[Q].Lo - StartU) < 1E-6) then CutEdge := True;
      if First and not CutEdge then
      begin
        NearLo := Max(0, Lo); NearHi := Hi;
        HasNear := True;
      end
      else if CutEdge then
      begin
        FarLo := Lo; FarHi := Hi;
        HasFar := FarHi - FarLo > Spec.Spacing;
      end;
      First := False;
    end;
  end;

  { Lay one side of the manifold: the game of snake.  The rows run along
    the manifold's own row - the wall's inset, when it hangs on a wall,
    but a manifold dragged off the wall has rows both ways from it, and
    VDir says which: +1 the way this has always run, -1 back toward the
    wall it left.  The first row a hand's width off the manifold either
    way, and a loop is a snake of them: out of its port straight to its
    first row, along it to the far end of the floor, a turn into the
    next row and back, out again on the one after - as many pairs as
    Limit allows, measured as laid - and home down its other port.
    Loop after loop outward from the manifold's own row, one side then
    the other, mirror image; and where there is a second direction too,
    that runs entirely after the first and past every port the first
    used (`PortOff`), so a loop going one way is never given the same
    connection as one going the other.  Every foot of it is heater.
    The ports are two inches apart and the grid a spacing, so the tube
    out of each port opens out across a fan to a grid lane of its own,
    and goes up the lane to its rows: the fan is the only tube off the
    grid, and it thins from the manifold out instead of running as a
    bundle.  Nothing about a fan's own straightness keeps two of them
    from crossing - that is exactly what the crossing check below
    catches, the same as it catches a lane crossing a row.

    The loop nearest the manifold's own row is grown first and reaches
    for the outermost lane its own row allows, so it is usually the
    widest; each loop after it is grown the same way but is turned
    away from any lane a loop before it already claimed, the same
    check its port, its fan and its rows all answer to - so a lane
    passing an earlier loop's own rows on its way out does not have
    to be assumed clear by an ordering rule, it is walked and checked.
    The far side of an obstacle is reached by one loop and one only:
    out on a clear row short of it, the far pieces beside it, home on
    the clear row past it, and the near pieces under it on the way
    home.  A row cut by an obstacle turns at it.

    Which ports a loop gets only has to fall the same way its lane
    does - the one thing here still taken on faith rather than
    checked, since nothing walks past a port the way a lane walks
    past a row - so a rank's own place in that fall is room enough;
    it never has to be exactly right, only never fewer ranks than the
    floor could really hold.  Which lane it gets is not: a lane has
    to reach past whatever is really between it and the manifold, and
    has to actually miss every run of tube laid before it, on this
    side or the last.  So a lane is not assumed, it is grown - out as
    far as the row it starts on can take it, exactly the way a loop
    is grown along that lane once it has one - and checked against
    every point of every loop already down, the same segment-by-
    segment test the finished ticket's own crossing count uses,
    before it is ever kept rather than after.  Too close to one
    already laid, and the next position in is tried, out to in,
    until one is found that is clean or the row has none to give. }
  procedure LaySide(SideK, VDir: Integer; PortOff: Double; Limit: Double;
    var Got: TRadiantLoopArray; var Unf: Double; out NLOut: Integer);
  type
    TPlan = record
      Rows: array of Integer;      { the rows, in walking order }
      Far: array of Boolean;       { the far piece of that row, not the near }
      Cut: array of Double;        { a near piece stopped short, here; 0 for the whole }
    end;
  var
    C, N, Q, EstGuess: Integer;
    V, PortPitch, FanH, EdgeD, CurD, AvgReach: Double;
    RowV, NLo, NHi, FLo, FHi, EdgeMax: array of Double;
    HasN, HasF, UsedN, UsedF, DeadN: array of Boolean;
    Plans: array of TPlan;
    P: TPlan;
    L: TRadiantLoop;
    Sign: Integer;

    { where the loop of rank R - R = 0 nearest the manifold's own row -
      leaves and comes home, as distance from the manifold along this
      side: the home port inside, the out port beside it.  PortOff
      moves the whole set past whatever the other direction, if there
      is one, already used - 0 when this is the only direction, or the
      first of the two laid.  Unlike a lane, a port carries no risk
      from a guess: there is never more than one loop per rank, so
      counting up from rank 0 with nothing held back is always enough,
      whatever the true count turns out to be. }
    function PortHome(R: Integer): Double;
    begin
      { falling the same way the lane's own starting guess does, and
        at the same pace - a port counting up while its lane counts
        down was found the hard way: the crossing check below catches
        the crossed fan that makes, correctly, but a lane has nowhere
        left to search to fix it, since no position moves a port that
        is already on the wrong side of another rank's own.  A guess
        too small to tell two ranks' ports apart is no more than the
        guess being wrong about the count again, exactly the failure
        the lane search already recovers from below - whichever rank
        it happens to stays unplaced rather than sharing a
        connection, which the crossing check catches just the same. }
      Result := (2 * Max(0, EstGuess - 1 - R) + 1) * PortPitch + PortOff;
    end;

    function PortOut(R: Integer): Double;
    begin
      Result := PortHome(R) + PortPitch;
    end;

    { the lane the loop being tried right now takes from the fan up to
      its rows - whatever the search below is currently trying, the
      same for both directions of the one loop it belongs to }
    function LaneHome(R: Integer): Double;
    begin
      Result := CurD - Spec.Spacing;
    end;

    function LaneOut(R: Integer): Double;
    begin
      Result := CurD;
    end;

    function AtD(D: Double): Double;   { back to U }
    begin
      Result := M2.X + Sign * D;
    end;

    { the fan's signed height toward TargetV, capped at FanH either way }
    function FanHt(TargetV: Double): Double;
    begin
      Result := VDir * Min(FanH, VDir * (TargetV - M2.Y));
    end;

    { the V the fan reaches on its way to the row at TargetV }
    function FanTop(TargetV: Double): Double;
    begin
      Result := M2.Y + FanHt(TargetV);
    end;

    { the loop as laid: out of its port to its first row, the rows,
      home from the last down its other port; every turn leveled.  The
      length is the result. }
    function LayPlan(const Pl: TPlan; R: Integer; out L: TRadiantLoop): Double;
    var
      J, Rr: Integer;
      D0, D1: Double;
      Lo, Hi: array of Double;
      Back: Boolean;
    begin
      NPts := 0;
      { out of the port and across the fan to the lane - straight, the
        fan's height or the first row's, whichever is lower - then up
        the lane to the row }
      Put(AtD(PortOut(R)), M2.Y);
      Put(AtD(LaneOut(R)), FanTop(RowV[Pl.Rows[0]]));
      { each row's near and far end, then every turn leveled: going out
        the two rows turn at the nearer of their far ends, coming back at
        the farther of their near ends - a turn is always level.  A near
        piece begins at the out lane, the last at the home lane; a far
        piece past its obstacle, or at the out lane when the obstacle
        sits nearer the manifold than that. }
      SetLength(Lo, Length(Pl.Rows)); SetLength(Hi, Length(Pl.Rows));
      for J := 0 to High(Pl.Rows) do
      begin
        Rr := Pl.Rows[J];
        if Pl.Far[J] then begin Lo[J] := Max(FLo[Rr], LaneOut(R)); Hi[J] := FHi[Rr]; end
        else begin Lo[J] := Max(LaneOut(R), NLo[Rr]); Hi[J] := NHi[Rr]; end;
        if Pl.Cut[J] > 0 then Hi[J] := Min(Hi[J], Pl.Cut[J]);
      end;
      Lo[High(Lo)] := Max(LaneHome(R), NLo[Pl.Rows[High(Pl.Rows)]]);
      Back := False;
      for J := 0 to High(Pl.Rows) - 1 do
      begin
        if not Back then begin Hi[J] := Min(Hi[J], Hi[J + 1]); Hi[J + 1] := Hi[J]; end
        else begin Lo[J] := Max(Lo[J], Lo[J + 1]); Lo[J + 1] := Lo[J]; end;
        Back := not Back;
      end;
      Back := False;   { the first row is walked out, away from the manifold }
      for J := 0 to High(Pl.Rows) do
      begin
        Rr := Pl.Rows[J];
        if Back then begin D0 := Hi[J]; D1 := Lo[J]; end else begin D0 := Lo[J]; D1 := Hi[J]; end;
        Put(AtD(D0), RowV[Rr]);
        Put(AtD(D1), RowV[Rr]);
        Back := not Back;
      end;
      Put(AtD(LaneHome(R)), FanTop(RowV[Pl.Rows[High(Pl.Rows)]]));
      Put(AtD(PortHome(R)), M2.Y);
      SetLength(L.Pts, NPts);
      for J := 0 to NPts - 1 do L.Pts[J] := World(Pts[J]);
      L.LenFt := 0;
      for J := 1 to High(L.Pts) do L.LenFt := L.LenFt + Dist(L.Pts[J - 1], L.Pts[J]);
      Result := L.LenFt;
    end;

    { is a lane at D clear of obstacles on every row below UpTo?  It is
      where each row has a piece of floor at D. }
    function LaneClear(D: Double; UpTo: Integer): Boolean;
    var
      Rr: Integer;
    begin
      Result := True;
      for Rr := 0 to UpTo - 1 do
        if not ((HasN[Rr] and (D >= NLo[Rr] - 1E-6) and (D <= NHi[Rr] + 1E-6)) or
                (HasF[Rr] and (D >= FLo[Rr] - 1E-6) and (D <= FHi[Rr] + 1E-6))) then Exit(False);
    end;

    { the fan is the one piece of tube whose own row-bound checks never
      touch it, since it runs at an angle rather than along a row - so
      the two fan segments of this loop, port to lane, are walked past
      every obstacle's box directly. }
    function FanClear(D0, V0, D1, V1: Double): Boolean;
    var
      A, B: T2;
      I3, K3: Integer;
    begin
      A := Point2(AtD(D0), M2.Y + V0); B := Point2(AtD(D1), M2.Y + V1);
      Result := True;
      for I3 := 0 to High(HoleB) do
        for K3 := 0 to 3 do
          if SegsMeet(A, B, HoleB[I3][K3], HoleB[I3][(K3 + 1) mod 4]) then Exit(False);
    end;

    { under the limit, both lanes inside the floor and clear of
      obstacles up to their rows, and both fans clear of every
      obstacle along their own length }
    function Fits(const Pl: TPlan; R: Integer): Boolean;
    var
      Lt: TRadiantLoop;
      V0, V1: Double;
    begin
      V0 := FanHt(RowV[Pl.Rows[0]]);
      V1 := FanHt(RowV[Pl.Rows[High(Pl.Rows)]]);
      Result := (EdgeMax[Pl.Rows[0]] <= LaneOut(R) + 1E-6) and
                (EdgeMax[Pl.Rows[High(Pl.Rows)]] <= LaneHome(R) + 1E-6) and
                LaneClear(LaneOut(R), Pl.Rows[0]) and LaneClear(LaneHome(R), Pl.Rows[High(Pl.Rows)]) and
                FanClear(PortOut(R), 0, LaneOut(R), V0) and
                FanClear(LaneHome(R), V1, PortHome(R), 0) and
                (LayPlan(Pl, R, Lt) <= IfThen(R = 0, Limit * FirstBudget, Limit));
    end;

    { is there a run's worth of this piece beyond the loop's port? }
    function NearOk(C, R: Integer): Boolean;
    begin
      Result := (C >= 0) and (C <= High(RowV)) and HasN[C] and not UsedN[C] and not DeadN[C] and
        (NHi[C] - Max(LaneOut(R), NLo[C]) >= Spec.Spacing - 1E-6);
    end;

    function FarOk(C, R: Integer): Boolean;
    begin
      Result := (C >= 0) and (C <= High(RowV)) and HasF[C] and not UsedF[C] and
        (FHi[C] - Max(FLo[C], LaneOut(R)) >= Spec.Spacing - 1E-6);
    end;

    function Clear(C: Integer): Boolean;   { a near piece to the far end }
    begin
      Result := (C >= 0) and (C <= High(RowV)) and HasN[C] and not HasF[C];
    end;

    procedure Add(var Pl: TPlan; C: Integer; IsFar: Boolean; CutAt: Double = 0);
    begin
      SetLength(Pl.Rows, Length(Pl.Rows) + 1); SetLength(Pl.Far, Length(Pl.Far) + 1);
      SetLength(Pl.Cut, Length(Pl.Cut) + 1);
      Pl.Rows[High(Pl.Rows)] := C; Pl.Far[High(Pl.Far)] := IsFar; Pl.Cut[High(Pl.Cut)] := CutAt;
    end;

    procedure Trim(var Pl: TPlan; N: Integer);
    begin
      SetLength(Pl.Rows, N); SetLength(Pl.Far, N); SetLength(Pl.Cut, N);
    end;

    { a clear row with an obstacle's far side just past it is the way
      out to those far pieces: no loop may end on it }
    function Reserved(C: Integer): Boolean;
    begin
      Result := Clear(C) and (C + 1 <= High(RowV)) and HasF[C + 1] and not UsedF[C + 1];
    end;

    { The excursion round an obstacle, from row Cc, the last in Pl and
      walked out: the far pieces beside it, all of them, then home on
      the clear row past them - or, when an odd count of far pieces
      leaves that row walked out, along it from the obstacle to the end
      and home on the one after - and the near pieces under the obstacle
      on the way, an even number of them from the far end.  Too long,
      and the far pieces come off from the near end, and the near pieces
      under those are lost: a loop of their own would sit between this
      one's rows and cross its way home. }
    function Excursion(Cc, R: Integer; var Pl: TPlan): Boolean;
    var
      First, Home, M, J, Q, NearN, Was: Integer;
      Trial: TPlan;
    begin
      Result := False;
      First := Cc + 1;
      M := 0;
      while FarOk(First + M, R) do Inc(M);
      if M < 1 then Exit;
      Home := First + M;
      if not NearOk(Home, R) or not Clear(Home) then Exit;
      J := M;
      while J >= 1 do
      begin
        Trial := Pl;
        for Q := Home - J to Home - 1 do Add(Trial, Q, True);
        Add(Trial, Home, False);
        NearN := J;
        Was := Length(Trial.Rows);
        if J mod 2 = 1 then
        begin
          { the home row was walked out from the obstacle: home on the
            one after, and the near part of the home row, up to the
            obstacle, comes with the near pieces - which makes their
            count even }
          if not NearOk(Home + 1, R) or not Clear(Home + 1) then Exit;
          Add(Trial, Home + 1, False);
          Was := Length(Trial.Rows);
          Add(Trial, Home, False, FLo[Home - 1]);
          NearN := J + 1;
        end;
        { the near pieces under the far pieces taken - all or none, an
          odd few could not come home }
        for Q := Home - 1 downto Home - J do
          if NearOk(Q, R) then Add(Trial, Q, False) else Break;
        if Length(Trial.Rows) - Was < NearN then Trim(Trial, Was);
        if Fits(Trial, R) then
        begin
          Pl := Trial;
          for Q := First to Home - 1 do
            if HasN[Q] and not UsedN[Q] then
            begin
              Was := 0;
              for NearN := 0 to High(Trial.Rows) do
                if (Trial.Rows[NearN] = Q) and not Trial.Far[NearN] then Was := 1;
              if Was = 0 then DeadN[Q] := True;
            end;
          Exit(True);
        end;
        Dec(J);
      end;
    end;

    { the plan of the loop of rank R from row C: out on C; then the
      excursion round an obstacle, or pairs of near pieces, as many as
      fit under Limit }
    function PlanFrom(C, R: Integer; out Pl: TPlan): Boolean;
    var
      Cc: Integer;
      Trial: TPlan;
    begin
      Result := False;
      Trim(Pl, 0);
      if not NearOk(C, R) then
      begin
        { nothing here to walk out from - an obstacle sitting right at
          the manifold's own column blocks every near piece for a whole
          run of rows, with no clear row anywhere among them to anchor
          an excursion the way one usually starts mid-row.  Its far
          piece, past that obstacle, is reached the same way an
          excursion already reaches the far side of one met partway
          out a row - starting there instead of arriving there. }
        if FarOk(C, R) then Result := Excursion(C - 1, R, Pl);
        Exit;
      end;
      Add(Pl, C, False);
      Cc := C;
      repeat
        if Cc + 1 > High(RowV) then Break;
        if Length(Pl.Rows) mod 2 = 1 then
        begin
          { on a row walked out: round an obstacle, or the next row back }
          if Clear(Cc) and Excursion(Cc, R, Pl) then begin Result := True; Break; end;
          if NearOk(Cc + 1, R) and not Reserved(Cc + 1) then
          begin
            Trial := Pl;
            Add(Trial, Cc + 1, False);
            if Fits(Trial, R) then
            begin
              Pl := Trial; Cc := Cc + 1; Result := True;
              Continue;
            end;
          end;
          Break;
        end
        else
        begin
          { on a row walked back: out again on the next, if it is the
            way out round an obstacle or the pair after it fits }
          if Reserved(Cc + 1) and NearOk(Cc + 1, R) then
          begin
            Trial := Pl;
            Add(Trial, Cc + 1, False);
            if Excursion(Cc + 1, R, Trial) then begin Pl := Trial; Result := True; end;
            Break;
          end;
          if NearOk(Cc + 1, R) and NearOk(Cc + 2, R) and not Reserved(Cc + 2) then
          begin
            Trial := Pl;
            Add(Trial, Cc + 1, False);
            Add(Trial, Cc + 2, False);
            if Fits(Trial, R) then
            begin
              Pl := Trial; Cc := Cc + 2;
              Continue;
            end;
          end;
          Break;
        end;
      until False;
      { an odd number of rows cannot come home: drop the last }
      if Result and (Length(Pl.Rows) mod 2 = 1) then
      begin
        Trim(Pl, Length(Pl.Rows) - 1);
        Result := Length(Pl.Rows) >= 2;
      end;
    end;

    { does the plan just built, laid at the lane the search above is
      currently trying, meet a single point of anything already laid
      for this manifold - the same segment-by-segment test the
      finished ticket's own crossing count runs, called here before a
      candidate is ever kept rather than after }
    function PlanCrosses(const Pl: TPlan; R: Integer): Boolean;
    var
      Lt: TRadiantLoop;
      SA, SB: array of T2;
      I4, J4, A4: Integer;
      Existing: TP3Array;
      P0, P1, Q0, Q1: T2;
    begin
      Result := False;
      LayPlan(Pl, R, Lt);
      SetLength(SA, Length(Lt.Pts));
      for I4 := 0 to High(SA) do SA[I4] := RadiantTo2(F, Lt.Pts[I4]);
      for I4 := 0 to High(SA) do
      begin
        if not InsidePoly(Poly2, SA[I4]) then Result := True;
        for A4 := 0 to High(HolePoly) do
          if InsidePoly(HolePoly[A4], SA[I4]) then Result := True;
      end;
      for I4 := 1 to High(SA) do
        for J4 := 0 to High(Poly2) do
          if SegsMeet(SA[I4 - 1], SA[I4], Poly2[J4],
            Poly2[(J4 + 1) mod Length(Poly2)]) then Result := True;
      { A lane test samples rows; test the finished segments as well so
        a connector cannot jump through a hole between those samples. }
      for I4 := 1 to High(SA) do
        for A4 := 0 to High(HolePoly) do
          for J4 := 0 to High(HolePoly[A4]) do
            if SegsMeet(SA[I4 - 1], SA[I4], HolePoly[A4][J4],
              HolePoly[A4][(J4 + 1) mod Length(HolePoly[A4])]) then
              Result := True;
      { Non-adjacent segments of this candidate must not meet either. }
      for I4 := 1 to High(SA) do
        for J4 := I4 + 2 to High(SA) do
          if SegsMeet(SA[I4 - 1], SA[I4], SA[J4 - 1], SA[J4]) then
            Result := True;
      for A4 := 0 to Length(Got) + Length(Loops) - 1 do
      begin
        if A4 < Length(Got) then Existing := Got[A4].Pts
        else Existing := Loops[A4 - Length(Got)].Pts;
        SetLength(SB, Length(Existing));
        for I4 := 0 to High(SB) do SB[I4] := RadiantTo2(F, Existing[I4]);
        for I4 := 1 to High(SA) do
          for J4 := 1 to High(SB) do
          begin
            P0 := SA[I4 - 1]; P1 := SA[I4]; Q0 := SB[J4 - 1]; Q1 := SB[J4];
            if (Max(P0.X, P1.X) < Min(Q0.X, Q1.X) - 1E-6) or (Min(P0.X, P1.X) > Max(Q0.X, Q1.X) + 1E-6) or
               (Max(P0.Y, P1.Y) < Min(Q0.Y, Q1.Y) - 1E-6) or (Min(P0.Y, P1.Y) > Max(Q0.Y, Q1.Y) + 1E-6) then Continue;
            if SegsMeet(P0, P1, Q0, Q1) then
            begin
              Result := True;
              if not WantTrace then Break;
            end;
          end;
        if Result and not WantTrace then Break;
      end;
      if WantTrace then
      begin
        SetLength(CurTrace, Length(CurTrace) + 1);
        CurTrace[High(CurTrace)].Pts := Lt.Pts;
        CurTrace[High(CurTrace)].Accepted := not Result;
      end;
    end;

    { Measure what was actually laid, not whether a row appeared in a
      plan. A short pass must not claim the unused rest of its row. }
    function BareRows: Double;
    var
      Rr, Li, Si, Pn: Integer;
      A, B: T2;
      Available, Covered, Left, Outer, Cuts: TSpanArray;
      X0, X1, T0, T1, Dy, HalfPitch: Double;
    begin
      Result := 0;
      HalfPitch := Spec.Spacing / 2;
      for Rr := 0 to High(RowV) do
      begin
        RowBounds(RowV[Rr], Outer, Cuts);
        Available := Subtract(Outer, Cuts);
        Left := nil;
        for Pn := 0 to High(Available) do
        begin
          if Sign > 0 then
          begin
            X0 := Max(Available[Pn].Lo, Max(M2.X, LimLo)) - M2.X;
            X1 := Min(Available[Pn].Hi, LimHi) - M2.X;
          end
          else
          begin
            X0 := M2.X - Min(Available[Pn].Hi, Min(M2.X, LimHi));
            X1 := M2.X - Max(Available[Pn].Lo, LimLo);
          end;
          if X1 <= X0 then Continue;
          Si := Length(Left); SetLength(Left, Si + 1);
          Left[Si].Lo := X0; Left[Si].Hi := X1;
        end;
        SetLength(Covered, 1);
        for Li := 0 to High(Got) do
          for Si := 1 to High(Got[Li].Pts) do
          begin
            A := RadiantTo2(F, Got[Li].Pts[Si - 1]);
            B := RadiantTo2(F, Got[Li].Pts[Si]);
            Dy := B.Y - A.Y;
            if Abs(Dy) < 1E-9 then
            begin
              if Abs(A.Y - RowV[Rr]) > HalfPitch + 1E-6 then Continue;
              X0 := A.X; X1 := B.X;
            end
            else
            begin
              T0 := (RowV[Rr] - HalfPitch - A.Y) / Dy;
              T1 := (RowV[Rr] + HalfPitch - A.Y) / Dy;
              if T0 > T1 then begin X0 := T0; T0 := T1; T1 := X0; end;
              T0 := Max(0, T0); T1 := Min(1, T1);
              if T0 > T1 then Continue;
              X0 := A.X + T0 * (B.X - A.X);
              X1 := A.X + T1 * (B.X - A.X);
            end;
            X0 := Sign * (X0 - M2.X); X1 := Sign * (X1 - M2.X);
            Covered[0].Lo := Min(X0, X1) - HalfPitch;
            Covered[0].Hi := Max(X0, X1) + HalfPitch;
            Left := Subtract(Left, Covered);
            if Length(Left) = 0 then Break;
          end;
        for Pn := 0 to High(Left) do
          Result := Result + (Left[Pn].Hi - Left[Pn].Lo) * Spec.Spacing;
      end;
    end;

    { the loop of rank R, grown from row C: try the widest lane that
      row can offer on its own - using nearly all of it, the way the
      owner's own picture has the first snake out of a manifold
      running as far as the floor allows - and if what grows there
      either does not fit the floor or does fit but runs into tube
      already down, the same row tried again one spacing further in,
      until one is found that is both, or the row has nothing left to
      give.  A rank already placed never has to be revisited: nothing
      here changes what an earlier rank was laid at. }
    function TryRowFrom(C, R: Integer; out Pl: TPlan): Boolean;
    var
      Start, Ceiling: Double;
      Tries: Integer;
      SavedDead: array of Boolean;

      function Candidate: Boolean;
      begin
        DeadN := Copy(SavedDead);
        Result := PlanFrom(C, R, Pl) and not PlanCrosses(Pl, R);
      end;
    begin
      SavedDead := Copy(DeadN);
      Result := False;
      if HasN[C] then Ceiling := NHi[C] - Spec.Spacing
      else if HasF[C] then Ceiling := FHi[C] - Spec.Spacing
      else Exit;
      Start := Min(Ceiling, Spec.Spacing / 2 + 2 * Max(0, EstGuess - 1 - R) * Spec.Spacing);
      CurD := Start;
      Tries := 0;
      while (CurD >= -1E-6) and (Tries <= 4000) do
      begin
        if Candidate then Exit(True);
        CurD := CurD - Spec.Spacing;
        Inc(Tries);
      end;
      { the guess above was too shy of the manifold, not too bold -
        an obstacle can swallow every reach the estimate ever tried,
        with real room only past it, farther out than a modest guess
        assumed anyone would need to go }
      CurD := Start + Spec.Spacing;
      Tries := 0;
      while (CurD <= Ceiling + 1E-6) and (Tries <= 4000) do
      begin
        if Candidate then Exit(True);
        CurD := CurD + Spec.Spacing;
        Inc(Tries);
      end;
      DeadN := SavedDead;
      Result := False;
    end;

  begin
    NLOut := 0;
    if SideK = 0 then Sign := -1 else Sign := 1;
    PortPitch := MANIFOLD_PORT_PITCH_IN * Spec.Inch;
    { The only off-grid allowance: thirteen inches normally, or three
      feet in a restart. The field keeps the requested row spacing. }
    FanH := Max(Inset, FanIn * Spec.Inch);
    SetLength(RowV, 0);
    C := 0;
    repeat
      V := M2.Y + VDir * (Inset + C * Spec.Spacing);
      if VDir > 0 then begin if V > Vmax - Inset + 1E-9 then Break; end
      else begin if V < Vmin + Inset - 1E-9 then Break; end;
      SetLength(RowV, C + 1); SetLength(NLo, C + 1); SetLength(NHi, C + 1); SetLength(EdgeMax, C + 1);
      SetLength(FLo, C + 1); SetLength(FHi, C + 1); SetLength(HasN, C + 1); SetLength(HasF, C + 1);
      RowV[C] := V;
      RowPieces(V, Sign, EdgeD, NLo[C], NHi[C], FLo[C], FHi[C], HasN[C], HasF[C]);
      { how far out the floor's edge has come by this row: a lane up to
        a row must lie inside the floor the whole way }
      if C = 0 then EdgeMax[C] := EdgeD else EdgeMax[C] := Max(EdgeMax[C - 1], EdgeD);
      { this side stops halfway to the next manifold along the wall }
      if Sign > 0 then NHi[C] := Min(NHi[C], LimHi - M2.X) else NHi[C] := Min(NHi[C], M2.X - LimLo);
      if HasN[C] and (NHi[C] <= Spec.Spacing) then HasN[C] := False;
      Inc(C);
    until C > 4000;
    N := Length(RowV);
    if N < 2 then
    begin
      Unf := Unf + BareRows;
      Exit;
    end;
    SetLength(UsedN, N); SetLength(UsedF, N); SetLength(DeadN, N);
    { where the search below starts looking - not a promise, since
      every rank's own lane is found by looking and checked against
      every run of tube already down, so a bad guess here costs
      coverage, never a crossed run.  A loop at full width holds
      about Limit / (4 * how far a row reaches) rows; the count that
      many loops takes to cover every row on this side is the guess
      the first rank starts from, leaving that much less for itself
      so the ranks after it have room to nest inside it. }
    AvgReach := Spec.Spacing;
    for C := 0 to N - 1 do
      if HasN[C] then AvgReach := Max(AvgReach, NHi[C]);
    EstGuess := Max(1, Ceil(N / Max(2, Limit / AvgReach))) + ExtraRanks;

    { the plans: from the wall outward, each taking what it can, and
      each committed to Got the moment it is accepted - not gathered
      and drawn afterward - so the next loop's own crossing check, and
      the one after that, sees every run of tube actually down so far,
      this side's own included, not only what an earlier side or
      direction left behind }
    SetLength(Plans, 0);
    C := 0;
    while C <= High(RowV) do
    begin
      if TryRowFrom(C, Length(Plans), P) then
      begin
        for Q := 0 to High(P.Rows) do
          if P.Far[Q] then UsedF[P.Rows[Q]] := True else UsedN[P.Rows[Q]] := True;
        SetLength(Plans, Length(Plans) + 1);
        Plans[High(Plans)] := P;
        LayPlan(P, High(Plans), L);
        L.Manifold := MI;
        SetLength(Got, Length(Got) + 1);
        Got[High(Got)] := L;
        { the next row with a piece still unused - a near one, or, with
          nothing nearer to reach it by, a far one on its own }
        Inc(C);
        while (C <= High(RowV)) and ((not HasN[C]) or UsedN[C]) and
              ((not HasF[C]) or UsedF[C]) do Inc(C);
      end
      else Inc(C);
    end;
    Unf := Unf + BareRows;
    NLOut := Length(Plans);
  end;

  { One side, laid once - LaySide grows every loop it can on its own,
    there is no guess to climb or settle any more, since each lane
    answers for itself as it is grown rather than trusting a formula
    to keep every rank apart.  NLFinal, out, is how many loops this
    direction actually used - what the other direction, if there is
    one, offsets its own ports past, so the two are never given the
    same manifold connection. }
  procedure LaySideSettled(SideK, VDir: Integer; PortOff, Limit: Double;
    var Got: TRadiantLoopArray; var Unf: Double; out NLFinal: Integer);
  var
    K0, NLOut: Integer;
  begin
    K0 := Length(Got);
    LaySide(SideK, VDir, PortOff, Limit, Got, Unf, NLOut);
    NLFinal := Length(Got) - K0;
  end;

  { Both sides under one limit per loop.  The owner's game: a loop
    that takes all the maximum allows leaves the last loop on the side
    with the scraps, so the limit is tried from the maximum down, and
    the layout kept is the one that costs least: a loop counts the same
    as LOOP_EVEN_FT of spread between the longest and the shortest, and
    the same as UNFILLED_LOOP_FT of row left unfilled.  Whole rows come
    in pairs, so on a wide floor the spread cannot always come down
    without doubling the loops, and the cost is the middle ground: an
    even dozen short loops are not an answer either. }
  procedure LayManifold;
  var
    Trial, Best: TRadiantLoopArray;
    BestTrace: TRadiantTrace;
    Unf, BestUnf, T, Lo, Hi, Spread, Cost, BestCost, PPitch: Double;
    I, SideK, NP: Integer;
    Better: Boolean;
  begin
    PPitch := MANIFOLD_PORT_PITCH_IN * Spec.Inch;
    Best := nil; BestUnf := 1E300; BestCost := 1E300; BestTrace := nil;
    T := MaxFt;
    while T >= MaxFt / 2 do
    begin
      Trial := nil; Unf := 0;
      if WantTrace then CurTrace := nil;
      for SideK := 0 to 1 do
      begin
        { away from the manifold's own row first, exactly as always;
          then, when the manifold is off its wall and there is floor
          the other way too, back toward the wall it left - past every
          port the first direction used, so the two never share a
          connection.  Their lanes need no such offset: the two
          directions' rows never share a row to begin with, and a
          lane that did somehow reach back across the manifold's own
          row would be caught by the crossing check like anything
          else. }
        LaySideSettled(SideK, 1, 0, T, Trial, Unf, NP);
        LaySideSettled(SideK, -1, 2 * NP * PPitch, T, Trial, Unf, NP);
      end;
      Lo := 1E300; Hi := 0;
      if Length(Trial) = 0 then Lo := 0;
      for I := 0 to High(Trial) do
      begin
        Lo := Min(Lo, Trial[I].LenFt); Hi := Max(Hi, Trial[I].LenFt);
      end;
      Spread := Hi - Lo;
      Cost := Length(Trial) + Spread / LOOP_EVEN_FT + Unf / (Spec.Spacing * UNFILLED_LOOP_FT);
      if BestCost = 1E300 then Better := True
      else Better := Cost < BestCost - 1E-6;
      if Better then
      begin
        Best := Trial; BestUnf := Unf; BestCost := Cost;
        if WantTrace then BestTrace := CurTrace;
      end;
      if (FirstBudget = 1) and (FanIn = MANIFOLD_FAN_IN) and (ExtraRanks = 0) then T := T - 2
      else T := T - 12;
    end;
    for I := 0 to High(Best) do
    begin
      SetLength(Loops, Length(Loops) + 1);
      Loops[High(Loops)] := Best[I];
    end;
    Unfilled := Unfilled + BestUnf;
    if WantTrace then
      for I := 0 to High(BestTrace) do
      begin
        SetLength(Trace, Length(Trace) + 1);
        Trace[High(Trace)] := BestTrace[I];
      end;
  end;

  { where any two runs of tube meet - a crossing, or a touch, which is
    as bad in a slab.  Counted in the manifold's own frame; a loop's
    consecutive segments share a corner and are not counted. }
  function Meetings(FromLoop: Integer): Integer;
  var
    A, B, I, J: Integer;
    P0, P1, Q0, Q1: T2;
    SA, SB: array of T2;
  begin
    Result := 0;
    for A := FromLoop to High(Loops) do
    begin
      SetLength(SA, Length(Loops[A].Pts));
      for I := 0 to High(SA) do SA[I] := RadiantTo2(F, Loops[A].Pts[I]);
      for B := 0 to High(Loops) do
      begin
        if (B < A) and (B >= FromLoop) then Continue;
        SetLength(SB, Length(Loops[B].Pts));
        for I := 0 to High(SB) do SB[I] := RadiantTo2(F, Loops[B].Pts[I]);
        for I := 1 to High(SA) do
          for J := 1 to High(SB) do
          begin
            if (A = B) and (J <= I + 1) then Continue;
            P0 := SA[I - 1]; P1 := SA[I]; Q0 := SB[J - 1]; Q1 := SB[J];
            if (Max(P0.X, P1.X) < Min(Q0.X, Q1.X) - 1E-6) or (Min(P0.X, P1.X) > Max(Q0.X, Q1.X) + 1E-6) or
               (Max(P0.Y, P1.Y) < Min(Q0.Y, Q1.Y) - 1E-6) or (Min(P0.Y, P1.Y) > Max(Q0.Y, Q1.Y) + 1E-6) then Continue;
            if SegsMeet(P0, P1, Q0, Q1) then Inc(Result);
          end;
      end;
    end;
  end;

begin
  Result := Default(TRadiantResult);
  Result.Crossings := 0;
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
    if Turn then
    begin
      SwapAxis := F.U; F.U := F.V;
      F.V := P3(-SwapAxis.X, -SwapAxis.Y, -SwapAxis.Z);
    end;
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
        if O2.X < M2.X then LimLo := Max(LimLo, (O2.X + M2.X) / 2 + Spec.Spacing / 2)
        else if O2.X > M2.X then LimHi := Min(LimHi, (O2.X + M2.X) / 2 - Spec.Spacing / 2);
      end;

    { each obstacle as its box, a hand's width bigger all round - so a
      row keeps off it at its end and beside it alike }
    SetLength(HoleB, Length(HolePoly));
    for I := 0 to High(HolePoly) do
    begin
      HLo := 1E300; HHi := -1E300; HV0 := 1E300; HV1 := -1E300;
      for J := 0 to High(HolePoly[I]) do
      begin
        HLo := Min(HLo, HolePoly[I][J].X); HHi := Max(HHi, HolePoly[I][J].X);
        HV0 := Min(HV0, HolePoly[I][J].Y); HV1 := Max(HV1, HolePoly[I][J].Y);
      end;
      SetLength(HoleB[I], 4);
      HoleB[I][0] := Point2(HLo - Inset, HV0 - Inset);
      HoleB[I][1] := Point2(HHi + Inset, HV0 - Inset);
      HoleB[I][2] := Point2(HHi + Inset, HV1 + Inset);
      HoleB[I][3] := Point2(HLo - Inset, HV1 + Inset);
    end;
    { the manifold no longer has to hang on the wall it was framed
      from - M2.Y keeps wherever it was dragged to, clamped inside the
      floor above, and LayManifold lays rows away from it in both
      directions when there is floor both ways }
    Result.RowCount := Max(1, Floor(((Vmax - Vmin) - 2 * Inset) / Spec.Spacing));
    K := Length(Loops);
    LayManifold;
    Inc(Result.Crossings, Meetings(K));
    Result.Manifolds[MI].LoopCount := Length(Loops) - K;
    Result.Manifolds[MI].Ports := Max(MANIFOLD_PORTS_MIN, Length(Loops) - K);
    Result.Manifolds[MI].Ft := 0;
    for I := K to High(Loops) do Result.Manifolds[MI].Ft := Result.Manifolds[MI].Ft + Loops[I].LenFt;
  end;

  Result.Loops := Loops;
  Result.Trace := Trace;
  Result.CellCount := 0;
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

{ Restart from an empty floor: changing the first loop after a later loop
  stalls must not leave any of the earlier trial's occupied rows behind.
  Try both axes, a shorter first circuit, and a return fan of at most three
  feet. Each attempt still lays all four quadrants of an interior manifold.
  The requested port count is never a routing limit. }
function ComputeRadiantLayout(const Outline: TP3Array; const Holes: array of TP3Array;
  const Spec: TRadiantSpec; WantTrace: Boolean = False): TRadiantResult;
var
  Alternative: TRadiantResult;
  TurnIndex, BudgetIndex, FanIndex, BestTurn, RankTry, BestRanks: Integer;
  FirstBudget, FanIn, BestBudget, BestFan, Cost, BestCost: Double;

  function Score(const R: TRadiantResult): Double;
  var
    M, L: Integer;
    Lo, Hi: Double;
  begin
    Result := R.UnfilledSqFt / (Spec.Spacing * UNFILLED_LOOP_FT) + Length(R.Loops);
    for M := 0 to High(R.Manifolds) do
    begin
      Lo := 1E300; Hi := 0;
      for L := 0 to High(R.Loops) do
        if R.Loops[L].Manifold = M then
        begin
          Lo := Min(Lo, R.Loops[L].LenFt); Hi := Max(Hi, R.Loops[L].LenFt);
        end;
      if Hi > 0 then Result := Result + (Hi - Lo) / LOOP_EVEN_FT;
    end;
  end;

begin
  Result := Default(TRadiantResult);
  Result.Why := RadiantProblem(Outline, Spec);
  if Result.Why <> '' then Exit;
  BestCost := 1E300; BestTurn := 0; BestBudget := 1; BestFan := MANIFOLD_FAN_IN; BestRanks := 0;
  for TurnIndex := 0 to 1 do
    for BudgetIndex := 0 to 2 do
      for FanIndex := 0 to 1 do
      begin
        FirstBudget := 1 - BudgetIndex * 0.25;
        if FanIndex = 0 then FanIn := MANIFOLD_FAN_IN else FanIn := 36;
        Alternative := ComputeRadiantOriented(Outline, Holes, Spec, False,
          TurnIndex = 1, FirstBudget, FanIn, 0);
        Cost := Score(Alternative);
        if (TurnIndex = 0) and (BudgetIndex = 0) and (FanIndex = 0) then Result := Alternative;
        if Alternative.Ok and (Alternative.Crossings = 0) and (Cost < BestCost - 1E-6) then
        begin
          Result := Alternative; BestCost := Cost;
          BestTurn := TurnIndex; BestBudget := FirstBudget; BestFan := FanIn; BestRanks := 0;
        end;
      end;
  { A length-based estimate is only a starting point. Shortened circuits
    and detours may need more connections. Restart with additional lane
    ranks rather than silently stopping at that estimated manifold size. }
  for TurnIndex := 0 to 1 do
    for RankTry := 1 to 4 do
    begin
      Alternative := ComputeRadiantOriented(Outline, Holes, Spec, False,
        TurnIndex = 1, 1, MANIFOLD_FAN_IN, RankTry * 2);
      Cost := Score(Alternative);
      if Alternative.Ok and (Alternative.Crossings = 0) and (Cost < BestCost - 1E-6) then
      begin
        Result := Alternative; BestCost := Cost;
        BestTurn := TurnIndex; BestBudget := 1; BestFan := MANIFOLD_FAN_IN;
        BestRanks := RankTry * 2;
      end;
      if Alternative.Ok and (Alternative.UnfilledSqFt < Alternative.AreaSqFt * 0.03) then Break;
    end;
  { Replay the winning strategy only, so discarded restarts cannot appear
    as accepted loops in the animation. Normal preview allocates no trace. }
  if WantTrace and Result.Ok then
    Result := ComputeRadiantOriented(Outline, Holes, Spec, True,
      BestTurn = 1, BestBudget, BestFan, BestRanks);
end;

function BuildRadiant(D: TWorkDoc; const Outline: TP3Array; const Holes: array of TP3Array;
  const R: TRadiantResult; const Spec: TRadiantSpec; Ink: TColor; PartName: string;
  Zone: Integer = 0): Integer;
var
  I, J, G, M: Integer;
  Mid: TP3;
  F: TRadiantFrame;
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
  { the manifold itself is not drawn: it hangs on the wall above the
    slab, and the fan of tube out of the ports says where.  A label
    only when asked. }
  F := RadiantFrameOf(Outline);
  for M := 0 to High(R.Manifolds) do
    if Spec.Labels then
    begin
      Mid := R.Manifolds[M].At;
      D.AddNote(P3(Mid.X + F.V.X * 2, Mid.Y + F.V.Y * 2, Mid.Z + F.V.Z * 2), Mid,
        Format('zone %d manifold - %d loops', [Zone + M + 1, R.Manifolds[M].LoopCount]), ZoneInk(Zone + M));
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
  Result := Result + 'floor: concrete slab' + LineEnding;
  Result := Result + 'tube: ' + T.Name + ' PEX, ' + FormatFloat('0.#', Spec.Spacing / Spec.Inch) +
    '" on center' + LineEnding;
  Result := Result + 'floor area: ' + FormatArea(R.AreaSqFt, U) + LineEnding;
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
  Result := Result + LineEnding + 'SLAB' + LineEnding;
  Result := Result + 'thickness: ' + FormatFloat('0.##', Spec.SlabThick / Spec.Inch) + '"' + LineEnding;
  Result := Result + 'tube depth: ' + IfThen(Spec.TubeDepth <= 0, 'centered in the pour',
    FormatFloat('0.##', Spec.TubeDepth / Spec.Inch) + '"') + LineEnding;
  Result := Result + 'insulation under the slab: R-' + FormatFloat('0', Spec.UnderR) + ' minimum' + LineEnding;
  if R.ObstacleCount > 0 then
    Result := Result + LineEnding + IntToStr(R.ObstacleCount) + ' obstacle(s) routed around.' + LineEnding;
  if R.UnfilledSqFt > 1 then
    Result := Result + Format('not reached: about %s - a lone row, or the far side of an obstacle', [FormatArea(R.UnfilledSqFt, U)]) + LineEnding;
  Result := Result + LineEnding + 'Flow rate and pump sizing are not worked out here - they ' +
    'come from a room-by-room heat loss, not from the tube size alone.' + LineEnding;
end;

end.
