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
    { each manifold's own heading in its zone's frame (RadiantFrameOf of
      the zone's outline), degrees - the way its long side, and the row of ports along it,
      runs.  Set by the wizard, where the manifold is a box turned by
      hand; not read by the search yet, which still takes its bearing
      from the nearest wall - kept so a search that wants it has it. }
    ManifoldAngles: array of Double;
    { the slab }
    SlabThick: Double;
    TubeDepth: Double;        { 0 = centered in the slab }
    UnderR: Double;
    Tag: string;
    Labels: Boolean;          { the loop and manifold notes on the drawing - off
                                while the paths are being inspected by hand, the
                                notes land over them }
    Inch: Double;             { the drawing's own inch, as TTransitionSpec keeps it }
    { What the search is after: this much of the floor covered, and every
      loop of a manifold within this much of its longest, percent.  0 for
      either is no goal.  A search watched in the wizard keeps trying
      other layouts until both are met or it is stopped. }
    GoalCoverPct, GoalEvenPct: Double;
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
    { which way it hangs, degrees in the zone's frame (RadiantFrameOf) -
      Spec.ManifoldAngles as asked, 0 when not }
    Heading: Double;
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
    { how far along the manifold its tubes run closer than the spacing
      before they are all out on the grid, feet: MANIFOLD_BREAKOUT_FT when
      that was enough, more when the floor could not be covered from it }
    BreakoutFt: Double;
    { how many layouts the search tried, and whether it was stopped short
      of its goals - the ticket says so }
    Tries: Integer;
    ShortOfGoals: Boolean;
    { for whoever lays it: every change of direction of the tube, and how
      much of it runs in straights of STRAIGHT_RUN_SPACINGS spacings or
      more, percent - long parallel runs are what a fitter wants, and a
      zigzag is what they curse }
    Bends: Integer;
    StraightPct: Double;
    { floor no loop could take: a lone row with no neighbor to come back
      on, or the far side of an obstacle - said on the ticket }
    UnfilledSqFt: Double;
    { a side whose rows came out odd at the spacing - one row with no
      partner, what EvenRows changes (see RowPlan) - and where they were
      evened up, the closest two rows came, the spacing when they were
      not }
    OddRows: Boolean;
    TightestGap: Double;
    { how far the search slid the manifold along its wall from where it
      was put, feet - 0 when it was not moved; see ComputeRadiantLayout }
    ManifoldShiftFt: Double;
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
  TRadiantResults = array of TRadiantResult;
  PRadiantResults = ^TRadiantResults;

  { told between tries how far a search has got - Done of Total, Total 0
    once it is past the fixed restarts and trying other layouts until its
    goals are met - with the best it has so far, and free to end it by
    setting Stop, which keeps that best }
  TRadiantProgress = procedure(Done, Total: Integer; const Best: TRadiantResult;
    var Stop: Boolean) of object;

  { goals a watcher can change while the search runs - read after every
    layout tried; see LiveGoals on ComputeRadiantLayout }
  TRadiantGoals = record
    CoverPct, EvenPct: Double;
  end;
  PRadiantGoals = ^TRadiantGoals;

function DefaultRadiantSpec: TRadiantSpec;
function Point2(X, Y: Double): T2;
function SegsMeet(const P0, P1, Q0, Q1: T2): Boolean;
function RadiantInside(const Outline: TP3Array; const P: TP3): Boolean;

{ Edge I of the outline a piece of a curve - an arc's side - rather than a
  wall: it turns only a little into a neighbor about as long as itself
  (SUGGEST_ARC_TURN, SUGGEST_ARC_RATIO).  A flat cabinet does not hang on
  one, nor square itself to one. }
function RadiantEdgeCurved(const Outline: TP3Array; I: Integer): Boolean;

{ Where a zone's manifold goes when nothing better is known: a foot in
  from the middle of the zone's wall nearest Toward - the middle of all
  the zones, so the manifolds of a building end up toward the boiler.
  The middle of a wall and not a corner, since 24 September: every tube
  out of a manifold has to be on the grid within four feet of it, and a
  corner has half the edge to let them out through - a corner manifold
  can take four loops that way, a mid-wall one eight.  And how many
  loops it takes, with one to spare. }
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
{ Every loop its own color, so one run can be followed by eye from port
  to port among forty others - the zone's color was one color for all of
  them, and there was no following a loop at all.  Neighbors never share
  one; each zone starts at a different place in the list, so zone 2's
  first loop is not zone 1's. }
function LoopInk(Zone, Loop: Integer): TColor;

{ The frame, and the way in and out of it - shared by the layout and the
  dialog's plan, so a point dragged on the plan lands where the layout
  thinks it is. }
function RadiantFrameOf(const Outline: TP3Array): TRadiantFrame;
{ The frame the wizard draws its plan in: the drawing's own plan - east to
  the right, north up - for a floor that lies flat, whichever way round
  its outline was drawn.  RadiantFrameOf turns with the outline's longest
  wall and takes its up from the way the outline winds, so a floor drawn
  clockwise came out on the wizard's plan turned and mirrored (the
  owner's odd floor, 25 September: "is the preview in the plan mirroring
  the actually selected layout").  A floor that does not lie flat keeps
  its longest wall along, seen from its upper side. }
function RadiantPlanFrame(const Outline: TP3Array): TRadiantFrame;
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
  worth of extra geometry, and nothing wants it but a person watching.
  Progress, when given, is called after every layout tried, and a
  search it stops hands back the best it had.  Found, when given, gets
  the distinct solutions kept, best first - brought up to date after
  every layout tried, so Progress can list them as they come.
  LiveGoals, when given, is read after every layout tried: goals changed
  there are the search's goals from then on - what it has kept ranked
  again by them, and done the moment its best meets them (the owner, 25
  September: "the user should be able to adjust it during its search"). }
function ComputeRadiantLayout(const Outline: TP3Array; const Holes: array of TP3Array;
  const Spec: TRadiantSpec; WantTrace: Boolean = False;
  Progress: TRadiantProgress = nil; Found: PRadiantResults = nil;
  LiveGoals: PRadiantGoals = nil): TRadiantResult;

{ How much of its floor a layout covers and how far its shortest loop
  falls short of its longest (the worst manifold), as fractions; and
  whether that meets the spec's goals. }
procedure RadiantMeasure(const R: TRadiantResult; out Cover, Spread: Double);
{ The same spread as a length: how much shorter the shortest loop is than
  the longest, feet, on the manifold whose loops are furthest apart - the
  owner, 25 September: "it should also show it as total feet apart...
  like put it in parenthesis". }
function RadiantSpreadFt(const R: TRadiantResult): Double;
function RadiantMeetsGoals(const R: TRadiantResult; const Spec: TRadiantSpec): Boolean;

{ Writes the result into the drawing as one part: the runs as reference
  lines in the tube's ink, a box and a note for the manifold, and a note
  on every hole that was routed around.  Returns the first entity added. }
function BuildRadiant(D: TWorkDoc; const Outline: TP3Array; const Holes: array of TP3Array;
  const R: TRadiantResult; const Spec: TRadiantSpec; Ink: TColor; PartName: string;
  Zone: Integer = 0): Integer;

{ About how much wall a manifold of this many loops wants, inches: its
  connections, supply and return side by side a port pitch apart the way
  the layout lays them, and the ends past them (MANIFOLD_ENDS_IN). }
function RadiantManifoldWallIn(Ports: Integer): Double;

{ The material list and the numbers behind it, as words - the ticket. }
function RadiantTicketText(const Spec: TRadiantSpec; const R: TRadiantResult;
  U: TUnitSystem): string;

implementation

type
  TSpan = record Lo, Hi: Double; end;
  TSpanArray = array of TSpan;
  TDoubleArray = array of Double;

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

function RadiantPlanFrame(const Outline: TP3Array): TRadiantFrame;
begin
  Result := RadiantFrameOf(Outline);
  if Abs(Result.N.Z) > 0.99 then
  begin
    Result.N := P3(0, 0, 1);
    Result.U := P3(1, 0, 0);
    Result.V := P3(0, 1, 0);
  end
  else if Result.N.Z < 0 then
  begin
    Result.N := P3(-Result.N.X, -Result.N.Y, -Result.N.Z);
    Result.V := VNorm(Cross3(Result.N, Result.U));
  end;
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

const
  { twelve strong colors that stay apart on white and on the dark
    theme, none of them gray - $00BBGGRR }
  LOOP_INKS: array[0..11] of TColor = ($00B4771F, $000E7FFF, $002CA02C, $002827D6,
    $00BD6794, $004B568C, $00C277E3, $0022BDBC, $00CFBE17, $00793B39, $00397963, $00393C84);

function LoopInk(Zone, Loop: Integer): TColor;
begin
  Result := LOOP_INKS[(Zone * 5 + Loop) mod Length(LOOP_INKS)];
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
  Result.GoalCoverPct := 97;
  Result.GoalEvenPct := 10;
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

function ComputeRadiantOriented(const Outline: TP3Array; const Holes: array of TP3Array;
  const Spec: TRadiantSpec; WantTrace, Turn: Boolean; FirstBudget: Double; ExtraRanks: Integer;
  BreakFt: Double; Seed: Cardinal; RowOff: Double = 0; Fingers: Boolean = True;
  Quick: Boolean = False; EvenRows: Boolean = False; LoopDelta: Integer = 0): TRadiantResult; forward;

function RadiantEdgeCurved(const Outline: TP3Array; I: Integer): Boolean;
var
  N: Integer;

  function Len(K: Integer): Double;
  begin
    K := (K + N) mod N;
    Result := Dist(Outline[K], Outline[(K + 1) mod N]);
  end;

  { the turn at corner K, from edge K-1 into edge K, degrees }
  function TurnAt(K: Integer): Double;
  var
    A, B, C: TP3;
  begin
    A := Outline[(K + N - 1) mod N]; B := Outline[K mod N]; C := Outline[(K + 1) mod N];
    Result := Abs(RadToDeg(ArcTan2((B.X - A.X) * (C.Y - B.Y) - (B.Y - A.Y) * (C.X - B.X),
      (B.X - A.X) * (C.X - B.X) + (B.Y - A.Y) * (C.Y - B.Y))));
  end;

  function Gentle(T: Double): Boolean;
  begin
    Result := (T >= 1) and (T < SUGGEST_ARC_TURN);
  end;

  function Alike(A, B: Double): Boolean;
  begin
    Result := (A <= SUGGEST_ARC_RATIO * B) and (B <= SUGGEST_ARC_RATIO * A);
  end;

begin
  N := Length(Outline);
  Result := False;
  if (N < 3) or (I < 0) or (I >= N) then Exit;
  Result := (Gentle(TurnAt(I)) and Alike(Len(I), Len(I - 1))) or
    (Gentle(TurnAt(I + 1)) and Alike(Len(I), Len(I + 1)));
end;

procedure RadiantSuggestZoneManifold(const Zone: TRadiantZone; const Toward: TP3;
  const Spec: TRadiantSpec; out At: TP3; out Ports: Integer);
type
  { A wall: the run of the outline's edges that go straight on - where a
    line from the next zone meets a wall is no corner of the room - and
    whether it is one piece of a curve.  A manifold is a flat cabinet
    that hangs on a flat wall: the owner's odd floor (25 September) had
    it suggested on a circle's side, the tubes fanned off at a slant
    from a chord of it and half the zone was left bare - "it should have
    never suggested putting the manifold in that circle wall".  A piece
    of a curve is a wall that turns only a little into a neighbor about
    as long as itself; a straight wall running on into an arc is far
    longer than the arc's pieces and stays a wall. }
  TWall = record
    First, Count: Integer;
    Len: Double;
    Curved: Boolean;
  end;
var
  I, J, K, N, Best, Start: Integer;
  BestD, BestL, BestCover, Spread: Double;
  Here: TP3;
  Cov, Dst, EdgeLen: array of Double;
  Walls: array of TWall;
  Trial: TRadiantSpec;
  R: TRadiantResult;

  { the turn at corner I, from edge I-1 into edge I, degrees, 0 to 180 }
  function TurnAt(I: Integer): Double;
  var
    A, B, C: TP3;
  begin
    A := Zone.Outline[(I + N - 1) mod N]; B := Zone.Outline[I]; C := Zone.Outline[(I + 1) mod N];
    Result := Abs(RadToDeg(ArcTan2((B.X - A.X) * (C.Y - B.Y) - (B.Y - A.Y) * (C.X - B.X),
      (B.X - A.X) * (C.X - B.X) + (B.Y - A.Y) * (C.Y - B.Y))));
  end;

  { a foot in from the point T of the way along edge I, square to it,
    on the floor's side }
  function OffWall(I: Integer; T: Double): TP3;
  var
    A, B, M, Nrm: TP3;
    Len: Double;
  begin
    A := Zone.Outline[I]; B := Zone.Outline[(I + 1) mod N];
    M := P3(A.X + T * (B.X - A.X), A.Y + T * (B.Y - A.Y), A.Z + T * (B.Z - A.Z));
    Len := Max(1E-9, Hypot(B.X - A.X, B.Y - A.Y));
    Nrm := P3(-(B.Y - A.Y) / Len, (B.X - A.X) / Len, 0);
    Result := P3(M.X + Nrm.X, M.Y + Nrm.Y, M.Z);
    if not RadiantInside(Zone.Outline, Result) then Result := P3(M.X - Nrm.X, M.Y - Nrm.Y, M.Z);
  end;

  { a foot in from the middle of wall W, measured along it }
  function MidWall(const W: TWall): TP3;
  var
    K, E: Integer;
    Along: Double;
  begin
    Along := W.Len / 2;
    for K := 0 to W.Count - 1 do
    begin
      E := (W.First + K) mod N;
      if (Along <= EdgeLen[E] + 1E-9) or (K = W.Count - 1) then
        Exit(OffWall(E, Min(1, Along / Max(1E-9, EdgeLen[E]))));
      Along := Along - EdgeLen[E];
    end;
    Result := OffWall(W.First, 0.5);
  end;

  { an obstacle inside the breakout round P - the four feet every tube
    has to get onto the grid within - leaves the tubes nowhere to go }
  function Crowded(const P: TP3): Boolean;
  var
    H, K: Integer;
    A, B: TP3;
    T, Lh: Double;
  begin
    Result := False;
    for H := 0 to High(Zone.Holes) do
    begin
      if RadiantInside(Zone.Holes[H], P) then Exit(True);
      for K := 0 to High(Zone.Holes[H]) do
      begin
        A := Zone.Holes[H][K]; B := Zone.Holes[H][(K + 1) mod Length(Zone.Holes[H])];
        Lh := Sqr(B.X - A.X) + Sqr(B.Y - A.Y);
        if Lh < 1E-12 then T := 0
        else T := Max(0, Min(1, ((P.X - A.X) * (B.X - A.X) + (P.Y - A.Y) * (B.Y - A.Y)) / Lh));
        if Hypot(P.X - A.X - T * (B.X - A.X), P.Y - A.Y - T * (B.Y - A.Y)) < MANIFOLD_BREAKOUT_FT then
          Exit(True);
      end;
    end;
  end;

  { two walls about as long as one another }
  function Alike(A, B: Double): Boolean;
  begin
    Result := (A <= SUGGEST_ARC_RATIO * B) and (B <= SUGGEST_ARC_RATIO * A);
  end;

begin
  At := P3(0, 0, 0); Ports := MANIFOLD_PORTS_MIN;
  N := Length(Zone.Outline);
  if N < 3 then Exit;
  SetLength(EdgeLen, N);
  for I := 0 to N - 1 do EdgeLen[I] := Dist(Zone.Outline[I], Zone.Outline[(I + 1) mod N]);
  { the walls, from a real corner round: an edge that goes straight on
    from the one before joins its wall }
  Start := 0;
  for I := 0 to N - 1 do
    if TurnAt(I) >= 1 then begin Start := I; Break; end;
  Walls := nil;
  for K := 0 to N - 1 do
  begin
    I := (Start + K) mod N;
    if EdgeLen[I] < 1E-9 then Continue;
    if (Length(Walls) = 0) or (TurnAt(I) >= 1) then
    begin
      SetLength(Walls, Length(Walls) + 1);
      Walls[High(Walls)].First := I; Walls[High(Walls)].Count := 0; Walls[High(Walls)].Len := 0;
    end;
    Inc(Walls[High(Walls)].Count);
    Walls[High(Walls)].Len := Walls[High(Walls)].Len + EdgeLen[I];
  end;
  if Length(Walls) = 0 then Exit;
  { a piece of a curve: a gentle turn at either end into a wall about as
    long - and while any wall is not, only the ones that are not }
  J := 0;
  for I := 0 to High(Walls) do
  begin
    K := (Walls[I].First + Walls[I].Count) mod N;
    Walls[I].Curved := (Length(Walls) > 1) and
      (((TurnAt(Walls[I].First) < SUGGEST_ARC_TURN) and
        Alike(Walls[I].Len, Walls[(I + Length(Walls) - 1) mod Length(Walls)].Len)) or
       ((TurnAt(K) < SUGGEST_ARC_TURN) and Alike(Walls[I].Len, Walls[(I + 1) mod Length(Walls)].Len)));
    if not Walls[I].Curved then Inc(J);
  end;
  if J = 0 then
    for I := 0 to High(Walls) do Walls[I].Curved := False;
  { Every flat wall's middle tried with one quick layout - no search, the
    breakout at eight feet - and the one that heats most of the floor
    kept: of any within a point of that, the nearest Toward.  An obstacle
    a few feet in front of a manifold blocks most of its lanes whether or
    not it is inside the breakout, and there is no telling that from the
    outline alone: on the owner's barn a column six feet in front of the
    nearest wall's middle left 43% of the zone bare (24 September), where
    the next wall along covered it.  A wall with an obstacle inside the
    breakout is passed over while any other will do. }
  Best := -1; BestCover := -1;
  SetLength(Cov, Length(Walls)); SetLength(Dst, Length(Walls));
  for I := 0 to High(Walls) do
  begin
    Cov[I] := -1;
    Here := MidWall(Walls[I]);
    Dst[I] := Dist(Here, Toward);
    if Walls[I].Curved then Continue;
    Trial := Spec;
    SetLength(Trial.Manifolds, 1); Trial.Manifolds[0] := Here;
    Trial.ManifoldAngles := nil; Trial.Ports := nil;
    { rows evened up at the far wall: the most the search can make of the
      wall, the cheat included, not what the plain grid leaves }
    R := ComputeRadiantOriented(Zone.Outline, Zone.Holes, Trial, False, False, 1, 0, 8, 0, 0, False, True, True);
    if not R.Ok then Continue;
    RadiantMeasure(R, Cov[I], Spread);
    if Crowded(Here) then Cov[I] := Cov[I] - 0.5;
    BestCover := Max(BestCover, Cov[I]);
  end;
  BestD := 1E300; BestL := 0;
  for I := 0 to High(Walls) do
  begin
    if (Cov[I] < 0) or (Cov[I] < BestCover - 0.01) then Continue;
    if (Dst[I] < BestD - 1E-6) or ((Abs(Dst[I] - BestD) <= 1E-6) and (Walls[I].Len > BestL)) then
    begin
      BestD := Dst[I]; Best := I; BestL := Walls[I].Len;
    end;
  end;
  { nothing laid anywhere - the old rule: the nearest flat wall's middle }
  if Best < 0 then
    for I := 0 to High(Walls) do
      if not Walls[I].Curved and ((Best < 0) or (Dst[I] < Dst[Best])) then Best := I;
  if Best < 0 then Exit;
  At := MidWall(Walls[Best]);
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

{ The bends in these loops - every point where the tube changes
  direction, not the points along a straight - and the share of the tube,
  percent, in straights of at least LongFt feet. }
function RadiantBends(const Lps: TRadiantLoopArray; out StraightPct: Double;
  LongFt: Double = 6): Integer;
var
  I, J: Integer;
  A, B, C: TP3;
  Cr, Tot, Long, Run: Double;
begin
  Result := 0; Tot := 0; Long := 0;
  for I := 0 to High(Lps) do
  begin
    Run := 0;
    for J := 1 to High(Lps[I].Pts) do
    begin
      A := Lps[I].Pts[J - 1]; B := Lps[I].Pts[J];
      Run := Run + Dist(A, B);
      Tot := Tot + Dist(A, B);
      { a bend at B when the next segment turns off this one's line }
      if J < High(Lps[I].Pts) then
      begin
        C := Lps[I].Pts[J + 1];
        Cr := Abs((B.X - A.X) * (C.Y - B.Y) - (B.Y - A.Y) * (C.X - B.X)) +
              Abs((B.Y - A.Y) * (C.Z - B.Z) - (B.Z - A.Z) * (C.Y - B.Y)) +
              Abs((B.Z - A.Z) * (C.X - B.X) - (B.X - A.X) * (C.Z - B.Z));
        if Cr > 1E-9 * Max(1, Dist(A, B) * Dist(B, C)) then
        begin
          Inc(Result);
          if Run >= LongFt - 1E-9 then Long := Long + Run;
          Run := 0;
        end;
      end;
    end;
    if Run >= LongFt - 1E-9 then Long := Long + Run;
  end;
  if Tot > 0 then StraightPct := 100 * Long / Tot else StraightPct := 0;
end;

function ComputeRadiantOriented(const Outline: TP3Array; const Holes: array of TP3Array;
  const Spec: TRadiantSpec; WantTrace, Turn: Boolean; FirstBudget: Double; ExtraRanks: Integer;
  BreakFt: Double; Seed: Cardinal; RowOff: Double = 0; Fingers: Boolean = True;
  Quick: Boolean = False; EvenRows: Boolean = False; LoopDelta: Integer = 0): TRadiantResult;
var
  { with a seed, every loop its own share of the limit and its lane's
    first guess nudged - the same seed, the same layout, so a winner can
    be laid again for the replay; seed 0 is the plain search }
  RankBudget: array[0..63] of Double;
  RankJit: array[0..63] of Integer;
  RandState: Cardinal;
  { the length every loop is laid toward, 0 for none - see LayManifold }
  TargetFt: Double;
  { the floor left bare, on FloorBare's fixed grid }
  FloorUnf: Double;
  { what RowPlan found: a side's rows odd, and the closest it brought
    two together evening them up - see OddRows on the result }
  OddSeen: Boolean;
  Tightest: Double;
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
      { on the edge counts as in; the box first, since this is asked of
        every point of every loop tried }
      if (P.X >= Min(Poly[A].X, Poly[B].X) - 1E-6) and (P.X <= Max(Poly[A].X, Poly[B].X) + 1E-6) and
         (P.Y >= Min(Poly[A].Y, Poly[B].Y) - 1E-6) and (P.Y <= Max(Poly[A].Y, Poly[B].Y) + 1E-6) and
         SegsMeet(P, P, Poly[A], Poly[B]) then Exit(True);
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

  { How much of row V between ULo and UHi no tube in Lps heats: the
    floor's pieces on that row, less half a spacing either side of every
    run that passes along it or across it.  Measures what was actually
    laid, not whether a row appeared in a plan - a short pass must not
    claim the unused rest of its row. }
  function RowBare(V, ULo, UHi: Double; const Lps: TRadiantLoopArray): Double;
  var
    Li, Si, Pn: Integer;
    A, B: T2;
    Available, Covered, Left, Outer, Cuts: TSpanArray;
    X0, X1, T0, T1, Dy, HalfPitch: Double;
  begin
    Result := 0;
    HalfPitch := Spec.Spacing / 2;
    RowBounds(V, Outer, Cuts);
    Available := Subtract(Outer, Cuts);
    Left := nil;
    for Pn := 0 to High(Available) do
    begin
      X0 := Max(Available[Pn].Lo, ULo); X1 := Min(Available[Pn].Hi, UHi);
      if X1 <= X0 then Continue;
      Si := Length(Left); SetLength(Left, Si + 1);
      Left[Si].Lo := X0; Left[Si].Hi := X1;
    end;
    SetLength(Covered, 1);
    for Li := 0 to High(Lps) do
    begin
      if Length(Left) = 0 then Break;
      for Si := 1 to High(Lps[Li].Pts) do
      begin
        A := RadiantTo2(F, Lps[Li].Pts[Si - 1]);
        B := RadiantTo2(F, Lps[Li].Pts[Si]);
        Dy := B.Y - A.Y;
        if Abs(Dy) < 1E-9 then
        begin
          if Abs(A.Y - V) > HalfPitch + 1E-6 then Continue;
          X0 := A.X; X1 := B.X;
        end
        else
        begin
          T0 := (V - HalfPitch - A.Y) / Dy;
          T1 := (V + HalfPitch - A.Y) / Dy;
          if T0 > T1 then begin X0 := T0; T0 := T1; T1 := X0; end;
          T0 := Max(0, T0); T1 := Min(1, T1);
          if T0 > T1 then Continue;
          X0 := A.X + T0 * (B.X - A.X);
          X1 := A.X + T1 * (B.X - A.X);
        end;
        Covered[0].Lo := Min(X0, X1) - HalfPitch;
        Covered[0].Hi := Max(X0, X1) + HalfPitch;
        Left := Subtract(Left, Covered);
        if Length(Left) = 0 then Break;
      end;
    end;
    for Pn := 0 to High(Left) do
      Result := Result + (Left[Pn].Hi - Left[Pn].Lo) * Spec.Spacing;
  end;

  { The rows of one direction from the manifold, as distances from its
    own row: a spacing apart from a hand's width off it (and the row grid's
    slide) out to a hand's width off the far wall - and an even number of
    them when EvenRows is asked for.  A loop takes rows in pairs, out and
    back, so an odd count leaves the last row with nobody to pair with, a
    strip bare the length of the far wall (the owner's barn, 24
    September).  The owner's answer: "cheat or shift the grid to get one
    more row at the edges... often times on an exterior wall we dont care
    if we are closer" - and then, 25 September, the grid he asks for
    first, the cheat only when the search is struggling, and no more of
    it than it takes: "cheating the far edges in by 1 inch or so or just
    enough to get an extra lane".  So an odd count gets one row more, found
    the cheapest way there is: the last row an inch closer to the far
    wall, then what is still short taken from the gaps at the far wall,
    an inch a gap on a foot's spacing, over as many gaps as that needs
    (EVEN_EDGE_IN, EVEN_GAP_SHARE) - a border a little tighter along the
    outside wall, which is where a floor loses its heat anyway.  Past that, down
    to half a spacing a gap over every one.  The first gap keeps its
    spacing: that is where the manifold's breakout runs its tracks, a
    port pitch apart, and a first gap closed up brought the second row
    down among them - on the owner's barn a zone lost half its loops to
    it. }
  function RowPlan(VDir: Integer): TDoubleArray;
  var
    A, B, L, Short, Cut: Double;
    N, K, Gaps, Squeezed: Integer;
  begin
    Result := nil;
    A := Inset + RowOff * Spec.Spacing;
    if VDir > 0 then B := Vmax - Inset - M2.Y else B := M2.Y - (Vmin + Inset);
    L := B - A;
    if L < -1E-9 then Exit;
    N := Trunc(L / Spec.Spacing + 1E-9) + 1;
    Squeezed := -1;
    if N mod 2 = 1 then OddSeen := True;
    if EvenRows and (N mod 2 = 1) then
    begin
      { N rows and one more make N gaps: Short is what the band lacks for
        them all at the spacing, less what the far wall gives up }
      Short := Max(0, N * Spec.Spacing - L - EVEN_EDGE_IN * Spec.Inch);
      { the far gaps that give up the rest - never the first, when there
        is another }
      Gaps := Max(1, N - 1);
      Squeezed := 0;
      if Short > 1E-9 then Squeezed := Min(Gaps, Ceil(Short / (EVEN_GAP_SHARE * Spec.Spacing) - 1E-9));
      Cut := 0;
      if Squeezed > 0 then Cut := Short / Squeezed;
      if Cut > Spec.Spacing / 2 + 1E-9 then Squeezed := -1;
    end;
    if Squeezed < 0 then
    begin
      SetLength(Result, N);
      for K := 0 to N - 1 do Result[K] := A + K * Spec.Spacing;
      Exit;
    end;
    SetLength(Result, N + 1);
    Result[0] := A;
    for K := 1 to N do
      if K > N - Squeezed then Result[K] := Result[K - 1] + Spec.Spacing - Cut
      else Result[K] := Result[K - 1] + Spec.Spacing;
    Tightest := Min(Tightest, Spec.Spacing - Cut);
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
      LaneD: Double;               { where its lane was found - CurD when it was kept }
    end;
  var
    C, N, Q, EstGuess: Integer;
    Plan: TDoubleArray;
    V, PortPitch, BreakD, EdgeD, CurD, AvgReach: Double;
    RowV, NLo, NHi, FLo, FHi, EdgeMax: array of Double;
    HasN, HasF, UsedN, UsedF, DeadN: array of Boolean;
    Plans: array of TPlan;
    GotFrom: Integer;
    { while Compact re-lays: the tube's own maximum is the limit, and no
      lane tried is kept for the replay }
    Compacting: Boolean;
    Sign: Integer;
    { the index of tube already down - see BuildIndex }
    IdxA, IdxB: array of T2;
    IdxN, NEnt, GW, GH, SeenStamp: Integer;
    CellHead, EntSeg, EntNext, SegSeen: array of Integer;
    GX0, GY0, GCell: Double;

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

    { The breakout, square: a tube leaves its port straight out from
      the manifold, turns once to run along it to its lane, and turns
      again up the lane - no diagonal fan, the owner's rule of 24
      September.  Each tube runs along on a track of its own, a port
      pitch apart: the loop whose lane is farthest out on the lowest
      track, so no track crosses a lane or a port it passes - the out
      tube of rank R below its home tube, rank R below rank R + 1.
      Signed, the way this direction runs from the manifold's row. }
    function JogHt(R, Home: Integer): Double;
    begin
      Result := VDir * (2 * R + Home + 1) * PortPitch;
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
      { out of the port square, along its track to the lane, then up
        the lane to the row }
      Put(AtD(PortOut(R)), M2.Y);
      Put(AtD(PortOut(R)), M2.Y + JogHt(R, 0));
      Put(AtD(LaneOut(R)), M2.Y + JogHt(R, 0));
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
      Put(AtD(LaneHome(R)), M2.Y + JogHt(R, 1));
      Put(AtD(PortHome(R)), M2.Y + JogHt(R, 1));
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

    { the breakout is the one piece of tube whose own row-bound checks
      never touch it, since it runs below the first row - so both of
      its legs, out of the port and along the track to the lane, are
      walked past every obstacle's box directly }
    function JogClear(DPort, DLane, H: Double): Boolean;
    var
      A, B, C3: T2;
      I3, K3: Integer;
    begin
      A := Point2(AtD(DPort), M2.Y); B := Point2(AtD(DPort), M2.Y + H);
      C3 := Point2(AtD(DLane), M2.Y + H);
      Result := True;
      for I3 := 0 to High(HoleB) do
        for K3 := 0 to 3 do
          if SegsMeet(A, B, HoleB[I3][K3], HoleB[I3][(K3 + 1) mod 4]) or
             SegsMeet(B, C3, HoleB[I3][K3], HoleB[I3][(K3 + 1) mod 4]) then Exit(False);
    end;

    { under the limit, both lanes inside the floor and clear of
      obstacles up to their rows, both breakouts clear of every
      obstacle, and both lanes starting inside the breakout - every
      tube on the grid within four feet of the manifold }
    function Fits(const Pl: TPlan; R: Integer): Boolean;
    var
      Lt: TRadiantLoop;
    begin
      Result := (LaneOut(R) <= BreakD + 1E-6) and
                (EdgeMax[Pl.Rows[0]] <= LaneOut(R) + 1E-6) and
                (EdgeMax[Pl.Rows[High(Pl.Rows)]] <= LaneHome(R) + 1E-6) and
                LaneClear(LaneOut(R), Pl.Rows[0]) and LaneClear(LaneHome(R), Pl.Rows[High(Pl.Rows)]) and
                JogClear(PortOut(R), LaneOut(R), JogHt(R, 0)) and
                JogClear(PortHome(R), LaneHome(R), JogHt(R, 1)) and
                (LayPlan(Pl, R, Lt) <= IfThen(Compacting, MaxFt,
                  IfThen(R = 0, Limit * FirstBudget, Limit) * RankBudget[Min(R, 63)]));
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

    { Laid to a length and not a limit (see LayManifold): the pair of rows
      that would take the loop further past the target than it now falls
      short of it is not taken - the loop stops nearest the target, over
      or under, where to a limit every loop but the last is as long as it
      can be and the last has the scraps. }
    function PastTarget(const Now_, Next: TPlan; R: Integer): Boolean;
    var
      Lt: TRadiantLoop;
      A, B: Double;
    begin
      Result := False;
      if TargetFt <= 0 then Exit;
      A := LayPlan(Now_, R, Lt);
      B := LayPlan(Next, R, Lt);
      Result := (B > TargetFt) and (B - TargetFt > TargetFt - A);
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
            if Fits(Trial, R) and not PastTarget(Pl, Trial, R) then
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
    { the cells the box round P-Q covers, clamped to the grid }
    procedure CellsOf(const P, Q: T2; out X0, Y0, X1, Y1: Integer);
    begin
      X0 := Max(0, Min(GW - 1, Trunc((Min(P.X, Q.X) - 1E-6 - GX0) / GCell)));
      X1 := Max(0, Min(GW - 1, Trunc((Max(P.X, Q.X) + 1E-6 - GX0) / GCell)));
      Y0 := Max(0, Min(GH - 1, Trunc((Min(P.Y, Q.Y) - 1E-6 - GY0) / GCell)));
      Y1 := Max(0, Min(GH - 1, Trunc((Max(P.Y, Q.Y) + 1E-6 - GY0) / GCell)));
    end;

    { Every run of tube already down, this side's and every earlier
      manifold's, in this frame and filed by the cells of a coarse grid
      it passes through - so a candidate is tested against the runs near
      it and not against every run on the floor, which was nine tenths
      of the time a search took.  Built once for each loop being placed:
      nothing is laid while its lanes are being tried. }
    procedure BuildIndex;
    var
      A4, I4, N4, X, Y, X0, X1, Y0, Y1: Integer;
      P: TP3Array;
    begin
      IdxN := 0;
      N4 := 0;
      for A4 := 0 to Length(Got) + Length(Loops) - 1 do
        if A4 < Length(Got) then Inc(N4, Length(Got[A4].Pts))
        else Inc(N4, Length(Loops[A4 - Length(Got)].Pts));
      SetLength(IdxA, N4); SetLength(IdxB, N4);
      for A4 := 0 to Length(Got) + Length(Loops) - 1 do
      begin
        if A4 < Length(Got) then P := Got[A4].Pts else P := Loops[A4 - Length(Got)].Pts;
        for I4 := 1 to High(P) do
        begin
          IdxA[IdxN] := RadiantTo2(F, P[I4 - 1]);
          IdxB[IdxN] := RadiantTo2(F, P[I4]);
          Inc(IdxN);
        end;
      end;
      GCell := Max(Spec.Spacing * 2, Max(Umax - Umin, Vmax - Vmin) / 48);
      GX0 := Umin - GCell; GY0 := Vmin - GCell;
      GW := Trunc((Umax - Umin) / GCell) + 3; GH := Trunc((Vmax - Vmin) / GCell) + 3;
      SetLength(CellHead, GW * GH);
      for I4 := 0 to High(CellHead) do CellHead[I4] := -1;
      SetLength(EntSeg, 0); SetLength(EntNext, 0);
      NEnt := 0;
      SetLength(SegSeen, IdxN);
      for I4 := 0 to IdxN - 1 do
      begin
        SegSeen[I4] := 0;
        CellsOf(IdxA[I4], IdxB[I4], X0, Y0, X1, Y1);
        for Y := Y0 to Y1 do
          for X := X0 to X1 do
          begin
            if NEnt >= Length(EntSeg) then
            begin
              SetLength(EntSeg, NEnt * 2 + 64); SetLength(EntNext, NEnt * 2 + 64);
            end;
            EntSeg[NEnt] := I4;
            EntNext[NEnt] := CellHead[Y * GW + X];
            CellHead[Y * GW + X] := NEnt;
            Inc(NEnt);
          end;
      end;
      SeenStamp := 0;
    end;

    { does P-Q meet any run of tube in the index? }
    function MeetsIndexed(const P0, P1: T2): Boolean;
    var
      X, Y, X0, X1, Y0, Y1, E, G4: Integer;
      Q0, Q1: T2;
    begin
      Result := False;
      Inc(SeenStamp);
      CellsOf(P0, P1, X0, Y0, X1, Y1);
      for Y := Y0 to Y1 do
        for X := X0 to X1 do
        begin
          E := CellHead[Y * GW + X];
          while E >= 0 do
          begin
            G4 := EntSeg[E];
            E := EntNext[E];
            if SegSeen[G4] = SeenStamp then Continue;
            SegSeen[G4] := SeenStamp;
            Q0 := IdxA[G4]; Q1 := IdxB[G4];
            if (Max(P0.X, P1.X) < Min(Q0.X, Q1.X) - 1E-6) or (Min(P0.X, P1.X) > Max(Q0.X, Q1.X) + 1E-6) or
               (Max(P0.Y, P1.Y) < Min(Q0.Y, Q1.Y) - 1E-6) or (Min(P0.Y, P1.Y) > Max(Q0.Y, Q1.Y) + 1E-6) then Continue;
            if SegsMeet(P0, P1, Q0, Q1) then Exit(True);
          end;
        end;
    end;

    function PlanCrosses(const Pl: TPlan; R: Integer): Boolean;
    var
      Lt: TRadiantLoop;
      SA: array of T2;

      { the boxes of P0-P1 and Q0-Q1 apart: they cannot meet }
      function Apart(const P0, P1, Q0, Q1: T2): Boolean;
      begin
        Result := (Max(P0.X, P1.X) < Min(Q0.X, Q1.X) - 1E-6) or (Min(P0.X, P1.X) > Max(Q0.X, Q1.X) + 1E-6) or
          (Max(P0.Y, P1.Y) < Min(Q0.Y, Q1.Y) - 1E-6) or (Min(P0.Y, P1.Y) > Max(Q0.Y, Q1.Y) + 1E-6);
      end;

      { The candidate leaves the floor, enters an obstacle, crosses
        itself or crosses tube already down - said at the first it is
        found.  Every test boxed first: this is asked of every lane and
        limit the search tries, and on a floor of many edges - an arc is
        a dozen - the tests against every edge were most of a search's
        time (the owner's odd floor, 25 September, 25 seconds a zone). }
      function Crosses: Boolean;
      var
        I4, J4, A4: Integer;
      begin
        Result := True;
        for I4 := 0 to High(SA) do
        begin
          if not InsidePoly(Poly2, SA[I4]) then Exit;
          for A4 := 0 to High(HolePoly) do
            if InsidePoly(HolePoly[A4], SA[I4]) then Exit;
        end;
        for I4 := 1 to High(SA) do
          for J4 := 0 to High(Poly2) do
            if not Apart(SA[I4 - 1], SA[I4], Poly2[J4], Poly2[(J4 + 1) mod Length(Poly2)]) and
               SegsMeet(SA[I4 - 1], SA[I4], Poly2[J4], Poly2[(J4 + 1) mod Length(Poly2)]) then Exit;
        { A lane test samples rows; test the finished segments as well so
          a connector cannot jump through a hole between those samples. }
        for I4 := 1 to High(SA) do
          for A4 := 0 to High(HolePoly) do
            for J4 := 0 to High(HolePoly[A4]) do
              if not Apart(SA[I4 - 1], SA[I4], HolePoly[A4][J4], HolePoly[A4][(J4 + 1) mod Length(HolePoly[A4])]) and
                 SegsMeet(SA[I4 - 1], SA[I4], HolePoly[A4][J4],
                   HolePoly[A4][(J4 + 1) mod Length(HolePoly[A4])]) then Exit;
        { Non-adjacent segments of this candidate must not meet either. }
        for I4 := 1 to High(SA) do
          for J4 := I4 + 2 to High(SA) do
            if not Apart(SA[I4 - 1], SA[I4], SA[J4 - 1], SA[J4]) and
               SegsMeet(SA[I4 - 1], SA[I4], SA[J4 - 1], SA[J4]) then Exit;
        for I4 := 1 to High(SA) do
          if MeetsIndexed(SA[I4 - 1], SA[I4]) then Exit;
        Result := False;
      end;

    var
      I4: Integer;
    begin
      LayPlan(Pl, R, Lt);
      SetLength(SA, Length(Lt.Pts));
      for I4 := 0 to High(SA) do SA[I4] := RadiantTo2(F, Lt.Pts[I4]);
      Result := Crosses;
      if WantTrace and not Compacting then
      begin
        SetLength(CurTrace, Length(CurTrace) + 1);
        CurTrace[High(CurTrace)].Pts := Lt.Pts;
        CurTrace[High(CurTrace)].Accepted := not Result;
      end;
    end;

    { this side's rows, as laid so far }
    function BareRows: Double;
    var
      Rr: Integer;
    begin
      Result := 0;
      for Rr := 0 to High(RowV) do
        if Sign > 0 then Result := Result + RowBare(RowV[Rr], Max(M2.X, LimLo), LimHi, Got)
        else Result := Result + RowBare(RowV[Rr], LimLo, Min(M2.X, LimHi), Got);
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
      BuildIndex;
      Result := False;
      if HasN[C] then Ceiling := NHi[C] - Spec.Spacing
      else if HasF[C] then Ceiling := FHi[C] - Spec.Spacing
      else Exit;
      { on the lanes' own lattice, half a spacing and whole spacings out -
        a ceiling off it put one rank's lane 3.6 inches from the next
        rank's, the whole way out, on the barn }
      Ceiling := Spec.Spacing / 2 + Floor((Ceiling - Spec.Spacing / 2) / Spec.Spacing + 1E-9) * Spec.Spacing;
      { the innermost loop's lanes a spacing and a half and half a spacing
        out - its home lane, a spacing inside its out lane, just clear of
        the manifold.  Half a spacing and less, as it was, put that home
        lane on the far side of the manifold, where no row of this side
        is: the innermost slot was never used, and a strip two lanes wide
        lay bare from every manifold straight to the far wall (24
        September, the owner's barn: "missing entire 2 foot lengths") }
      Start := Min(Ceiling, 3 * Spec.Spacing / 2 +
        Max(0, 2 * Max(0, EstGuess - 1 - R) + RankJit[Min(R, 63)]) * Spec.Spacing);
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

    { the plans: from the wall outward, each taking what it can, and
      each committed to Got the moment it is accepted - not gathered
      and drawn afterward - so the next loop's own crossing check, and
      the one after that, sees every run of tube actually down so far,
      this side's own included, not only what an earlier side or
      direction left behind }
    procedure PlaceAll;
    var
      C, Q: Integer;
      P: TPlan;
      L: TRadiantLoop;
    begin
      SetLength(Plans, 0);
      C := 0;
      while C <= High(RowV) do
      begin
        if TryRowFrom(C, Length(Plans), P) then
        begin
          for Q := 0 to High(P.Rows) do
            if P.Far[Q] then UsedF[P.Rows[Q]] := True else UsedN[P.Rows[Q]] := True;
          SetLength(Plans, Length(Plans) + 1);
          P.LaneD := CurD;
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
    end;

    { Every lane of this side slid in toward the manifold, the same whole
      number of spacings, when the innermost is not in the slot beside it.
      The lanes are spaced for the loops the side was guessed to want, the
      first farthest out; a guess one too many leaves the slot nearest the
      manifold empty - a strip two lanes wide, bare from the manifold
      straight up the middle of the floor to the far wall (the owner's
      barn, 24 September: "missing entire 2 foot lengths").  Slid in, every
      row reaches in with its lane and the strip is gone.  Each loop laid
      again goes through the same checks as the first time, with the
      tube's own maximum for the limit - rows reaching further in make a
      loop longer; any that fails, and the slide is tried a spacing less,
      and at none the side stays as it was. }
    procedure Compact;
    var
      I: Integer;
      MinD, Shift: Double;
      Old: TRadiantLoopArray;
      Lt: TRadiantLoop;
      Ok: Boolean;
    begin
      if Length(Plans) = 0 then Exit;
      MinD := 1E300;
      for I := 0 to High(Plans) do MinD := Min(MinD, Plans[I].LaneD);
      Shift := Floor((MinD - 3 * Spec.Spacing / 2) / Spec.Spacing + 1E-9) * Spec.Spacing;
      Old := Copy(Got, GotFrom, Length(Got) - GotFrom);
      Compacting := True;
      try
        while Shift >= Spec.Spacing - 1E-9 do
        begin
          SetLength(Got, GotFrom);
          Ok := True;
          for I := 0 to High(Plans) do
          begin
            CurD := Plans[I].LaneD - Shift;
            { the crossing index is of the tube down now - this side's
              loops laid again so far, not the ones they replace }
            BuildIndex;
            if not Fits(Plans[I], I) or PlanCrosses(Plans[I], I) then begin Ok := False; Break; end;
            LayPlan(Plans[I], I, Lt);
            Lt.Manifold := MI;
            SetLength(Got, Length(Got) + 1);
            Got[High(Got)] := Lt;
          end;
          if Ok then
          begin
            for I := 0 to High(Plans) do Plans[I].LaneD := Plans[I].LaneD - Shift;
            Exit;
          end;
          Shift := Shift - Spec.Spacing;
        end;
        { no slide would do: as it was }
        SetLength(Got, GotFrom);
        for I := 0 to High(Old) do
        begin
          SetLength(Got, Length(Got) + 1);
          Got[High(Got)] := Old[I];
        end;
      finally
        Compacting := False;
      end;
    end;

  begin
    NLOut := 0;
    Compacting := False;
    if SideK = 0 then Sign := -1 else Sign := 1;
    PortPitch := MANIFOLD_PORT_PITCH_IN * Spec.Inch;
    { how far out along the manifold a lane may start: the breakout -
      the tubes' only way off the grid }
    BreakD := BreakFt * 12 * Spec.Inch;
    SetLength(RowV, 0);
    Plan := RowPlan(VDir);
    for C := 0 to High(Plan) do
    begin
      V := M2.Y + VDir * Plan[C];
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
    end;
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

    GotFrom := Length(Got);
    PlaceAll;
    Compact;
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
    Trial, Best, Saved: TRadiantLoopArray;
    BestTrace, SavedTrace: TRadiantTrace;
    Unf, BestUnf, T, BestT, Lo, Hi, Spread, Cost, BestCost, PPitch, Total: Double;
    SavedUnf, SavedCost, SavedT: Double;
    I, NBest: Integer;

    { the whole manifold laid under one limit - or toward one length,
      Target, under the tube's own - kept if it costs less }
    procedure TryLimit(T: Double; Target: Double = 0);
    var
      I, SideK, NP: Integer;
    begin
      Trial := nil; Unf := 0;
      TargetFt := Target;
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
      TargetFt := 0;
      if Cost < BestCost - 1E-6 then
      begin
        Best := Trial; BestUnf := Unf; BestCost := Cost; BestT := T;
        if WantTrace then BestTrace := CurTrace;
      end;
    end;

  begin
    PPitch := MANIFOLD_PORT_PITCH_IN * Spec.Inch;
    Best := nil; BestUnf := 1E300; BestCost := 1E300; BestTrace := nil; BestT := MaxFt;
    { Every twelve feet from the maximum down to half of it, then every
      two either side of the best of those - the same answer as trying
      every two feet from the start nearly always, at a quarter of the
      layouts.  Only the first restart refines; the others were only
      ever tried every twelve. }
    { a quick look - Suggest weighing one wall against another - lays the
      tube's own maximum and nothing more }
    if Quick then
    begin
      TryLimit(MaxFt);
      T := 0;
    end
    else T := MaxFt;
    while T >= MaxFt / 2 do
    begin
      TryLimit(T);
      T := T - 12;
    end;
    if (FirstBudget = 1) and (ExtraRanks = 0) and not Quick then
    begin
      T := Min(MaxFt, BestT + 10);
      while T >= Max(MaxFt / 2, BestT - 10) do
      begin
        if Abs(Frac((MaxFt - T) / 12)) > 1E-9 then TryLimit(T);
        T := T - 2;
      end;
    end;
    { Then balanced: the best of those has N loops and S feet of tube
      between them, and laid again toward S/N a loop - or a loop fewer
      or more, S/(N-1) and S/(N+1), in case one less or one more is what
      evens them - every loop stops nearest that length rather than as
      long as the limit lets it.  Weighed by the same cost, so it can
      only help: the idea is Warm's, a split of the rows into loops by
      their total, where filling each loop to the limit left the last
      with the scraps (24 September, 11% on the owner's barn). }
    NBest := Length(Best);
    if (NBest > 0) and not Quick then
    begin
      Total := 0;
      for I := 0 to High(Best) do Total := Total + Best[I].LenFt;
      for I := -1 to 1 do
        if (NBest + I >= 1) and (Total / (NBest + I) <= MaxFt) then
          TryLimit(MaxFt, Total / (NBest + I));
      { And forced: LoopDelta loops more or fewer than the best came to,
        laid toward that share of the tube and kept whatever the cost
        says - the cost counts every loop against it, and a search stuck
        a point off its goals never left the count it started with (the
        owner, 25 September: "force trying to do it with 2 more loops...
        or one less loop or 2 less loops and push the distance limits").
        Fewer loops go as long as the tube's maximum and no further -
        that is the tube, not a preference.  Nothing laid, and the best
        stands. }
      if (LoopDelta <> 0) and (NBest + LoopDelta >= 1) then
      begin
        Saved := Best; SavedUnf := BestUnf; SavedCost := BestCost; SavedT := BestT;
        if WantTrace then SavedTrace := BestTrace;
        BestCost := 1E300;
        TryLimit(MaxFt, Min(MaxFt, Total / (NBest + LoopDelta)));
        if Length(Best) = 0 then
        begin
          Best := Saved; BestUnf := SavedUnf; BestCost := SavedCost; BestT := SavedT;
          if WantTrace then BestTrace := SavedTrace;
        end;
      end;
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

  { The floor of this manifold as the loops in Lps leave it: every row
    both ways from the manifold, out to the halfway lines. }
  function RegionBare(const Lps: TRadiantLoopArray): Double;
  var
    VDir, C: Integer;
    Plan: TDoubleArray;
  begin
    Result := 0;
    for VDir := -1 to 1 do
    begin
      if VDir = 0 then Continue;
      Plan := RowPlan(VDir);
      for C := 0 to High(Plan) do
        Result := Result + RowBare(M2.Y + VDir * Plan[C], LimLo, LimHi, Lps);
    end;
  end;

  { The floor of this manifold as the loops leave it, sampled every half
    spacing from the wall's own inset and not at the rows - so a layout
    whose rows sit a quarter spacing further along is measured on the
    same floor as one whose rows do not, and the strip a row grid leaves
    against the far wall is counted, where sampled at the rows it never
    was.  What a layout is finally said to leave bare; the searching
    inside measures at the rows, which is cheaper and all it needs. }
  function FloorBare(const Lps: TRadiantLoopArray): Double;
  var
    K: Integer;
    V: Double;
  begin
    Result := 0;
    K := 0;
    repeat
      V := Vmin + Inset + K * Spec.Spacing / 2;
      if V > Vmax - Inset + 1E-9 then Break;
      Result := Result + RowBare(V, LimLo, LimHi, Lps) / 2;
      Inc(K);
    until K > 20000;
  end;

  { The first step of the repair pass: grow the loops laid short of the
    maximum into bare floor beside them.  The search stops a loop at
    whole pairs of rows under the limit it is trying, and keeps the
    limit that makes the loops most even, so most loops come home with
    length to spare while floor lies bare next to them.  Growing is a
    finger - a hairpin one spacing wide, pushed out square from a
    straight run of the loop: the run is cut, the tube goes out, across
    and back, and carries on.  Fingers a spacing apart make a comb, the
    same serpentine the rows are, turned; a finger's own side can put
    out another, so a pocket fills from its edge in.  Never less than two
    spacings deep: a notch one spacing deep is three bends in a foot, a
    crenellation no fitter would lay for a foot of floor.  A finger rises
    only as far as it keeps a spacing off every other run of tube, this
    loop's own included, and a hand's width off the walls and the
    obstacles, and only as far as the loop's own length allows - which
    is the tube's maximum, not the limit the search settled on.  Each
    finger is new floor heated, never floor another run already heats,
    since nothing is let within a spacing of anything else.  Kept only
    when it costs less by the same measure the search uses. }
  procedure GrowLoops(FromLoop: Integer);
  var
    Q, BestQ: array of T2Array;
    Len, BestLen: array of Double;
    Moved, BestMoved: array of Boolean;
    Order: TIntArray;
    Bare0, BestBare, BestCost, Cap, Hi, MinFinger: Double;
    I, J, CapTry, Tmp: Integer;
    Changed: Boolean;

    function Cost(const Lens: array of Double; Bare: Double): Double;
    var
      Li: Integer;
      Lo, Hi: Double;
    begin
      Lo := 1E300; Hi := 0;
      for Li := FromLoop to High(Lens) do
      begin
        Lo := Min(Lo, Lens[Li]); Hi := Max(Hi, Lens[Li]);
      end;
      if Hi = 0 then Lo := 0;
      Result := (Hi - Lo) / LOOP_EVEN_FT + Bare / (Spec.Spacing * UNFILLED_LOOP_FT);
    end;

    function Along(const P: T2; Ax: Integer): Double;
    begin
      if Ax = 0 then Result := P.X else Result := P.Y;
    end;

    function Across(const P: T2; Ax: Integer): Double;
    begin
      if Ax = 0 then Result := P.Y else Result := P.X;
    end;

    { how high above the base line, rising Sg, the segment P-Q comes
      while it is within W of the base's own stretch A0..B0 along it:
      1E300 when it never does, 0 when it reaches the base line }
    function Rise(const P, Qp: T2; Ax, Sg: Integer; A0, B0, C0, W: Double): Double;
    var
      Pa, Qa, Pc, Qc, Lo, Hi, T0, T1, S0, S1: Double;
    begin
      Result := 1E300;
      Pa := Along(P, Ax); Qa := Along(Qp, Ax);
      Lo := A0 - W + 1E-6; Hi := B0 + W - 1E-6;
      if (Max(Pa, Qa) <= Lo) or (Min(Pa, Qa) >= Hi) then Exit;
      Pc := Sg * (Across(P, Ax) - C0); Qc := Sg * (Across(Qp, Ax) - C0);
      if Abs(Qa - Pa) < 1E-12 then begin T0 := 0; T1 := 1; end
      else
      begin
        T0 := (Lo - Pa) / (Qa - Pa); T1 := (Hi - Pa) / (Qa - Pa);
        if T0 > T1 then begin S0 := T0; T0 := T1; T1 := S0; end;
        T0 := Max(0, T0); T1 := Min(1, T1);
      end;
      S0 := Pc + T0 * (Qc - Pc); S1 := Pc + T1 * (Qc - Pc);
      if Max(S0, S1) < -1E-6 then Exit;
      if Min(S0, S1) <= 1E-6 then Exit(0);
      Result := Min(S0, S1);
    end;

    { how far a finger on loop Li's segment Seg, over A0..B0 of it, can
      rise Sg before it comes within a spacing of tube or a hand's width
      of a wall or an obstacle - leaving out this loop's own segments
      SkipLo to SkipHi, the one it grows from and, for a turn pushed
      out, the two runs either side of it; less than Enough is as good as
      none, and said as soon as it is known }
    function Room(Li, SkipLo, SkipHi, Ax, Sg: Integer; A0, B0, C0, Enough: Double): Double;
    var
      Lj, K, H2: Integer;
    begin
      Result := 1E300;
      for Lj := 0 to High(Q) do
        for K := 1 to High(Q[Lj]) do
        begin
          if (Lj = Li) and (K - 1 >= SkipLo) and (K - 1 <= SkipHi) then Continue;
          Result := Min(Result, Rise(Q[Lj][K - 1], Q[Lj][K], Ax, Sg, A0, B0, C0, Spec.Spacing) - Spec.Spacing);
          { short by more than the callers' own tolerance: a room a hair
            under Enough, stopped at here, was taken as enough by a
            caller that allows 1E-9 - and every run past it went
            unchecked.  On a floor turned off the square the rows land
            a rounding error under whole spacings, and the fingers of
            the owner's odd floor (25 September) went straight through
            four rows of tube. }
          if Result < Enough - 1E-6 then Exit;
        end;
      for K := 0 to High(Poly2) do
        Result := Min(Result, Rise(Poly2[K], Poly2[(K + 1) mod Length(Poly2)], Ax, Sg, A0, B0, C0, Inset) - Inset);
      for H2 := 0 to High(HolePoly) do
        for K := 0 to High(HolePoly[H2]) do
          Result := Min(Result, Rise(HolePoly[H2][K], HolePoly[H2][(K + 1) mod Length(HolePoly[H2])],
            Ax, Sg, A0, B0, C0, Inset) - Inset);
      { and not past the halfway line to the next manifold }
      if Ax = 1 then
      begin
        if Sg > 0 then Result := Min(Result, LimHi - C0) else Result := Min(Result, C0 - LimLo);
      end
      else if (A0 < LimLo) or (B0 > LimHi) then Result := 0;
    end;

    { One pass over loop Li: every turn pushed out as far as the floor in
      front of it is bare.  A turn - a run with the runs either side of it
      square to it and on the same side, the end of a serpentine's pair of
      rows - moved outward lengthens those two runs and adds not one bend:
      the tube goes further the way it was already going.  Tried before
      any finger, since the fitter's first choice is a longer straight,
      and rows that stopped short of a wall or of bare floor are the
      commonest bare there is. }
    function PushOne(Li: Integer): Boolean;
    var
      Seg, Ax, Sg, SPrev, SNext: Integer;
      P0, P1, Pp, Pn: T2;
      A0, B0, C0, H: Double;
    begin
      Result := False;
      for Seg := 1 to High(Q[Li]) - 2 do
      begin
        if Cap - Len[Li] < 2 * PUSH_MIN * Spec.Spacing then Exit;
        P0 := Q[Li][Seg]; P1 := Q[Li][Seg + 1];
        Pp := Q[Li][Seg - 1]; Pn := Q[Li][Seg + 2];
        if Abs(P1.Y - P0.Y) < 1E-9 then Ax := 0
        else if Abs(P1.X - P0.X) < 1E-9 then Ax := 1
        else Continue;
        { both neighbors square to it: straight in the other axis }
        if Abs(Along(Pp, Ax) - Along(P0, Ax)) > 1E-9 then Continue;
        if Abs(Along(Pn, Ax) - Along(P1, Ax)) > 1E-9 then Continue;
        C0 := Across(P0, Ax);
        SPrev := Sign(Across(Pp, Ax) - C0); SNext := Sign(Across(Pn, Ax) - C0);
        if (SPrev = 0) or (SPrev <> SNext) then Continue;
        Sg := -SPrev;
        A0 := Min(Along(P0, Ax), Along(P1, Ax)); B0 := Max(Along(P0, Ax), Along(P1, Ax));
        H := Min(Room(Li, Seg - 1, Seg + 1, Ax, Sg, A0, B0, C0, PUSH_MIN * Spec.Spacing),
          (Cap - Len[Li]) / 2 - 1E-6);
        if H < PUSH_MIN * Spec.Spacing - 1E-9 then Continue;
        if Ax = 0 then
        begin
          Q[Li][Seg].Y := C0 + Sg * H; Q[Li][Seg + 1].Y := C0 + Sg * H;
        end
        else
        begin
          Q[Li][Seg].X := C0 + Sg * H; Q[Li][Seg + 1].X := C0 + Sg * H;
        end;
        Len[Li] := Len[Li] + 2 * H;
        Moved[Li] := True;
        Result := True;
      end;
    end;

    { one pass over loop Li: a finger wherever a straight run has room }
    function GrowOne(Li: Integer): Boolean;
    var
      Seg, Ax, Dir, Sg, N: Integer;
      P0, P1: T2;
      SegLen, T, A0, B0, C0, H: Double;
      Placed: Boolean;
    begin
      Result := False;
      Seg := 0;
      while Seg < High(Q[Li]) do
      begin
        if Cap - Len[Li] < 2 * MinFinger then Exit;
        P0 := Q[Li][Seg]; P1 := Q[Li][Seg + 1];
        if Abs(P1.Y - P0.Y) < 1E-9 then Ax := 0
        else if Abs(P1.X - P0.X) < 1E-9 then Ax := 1
        else begin Inc(Seg); Continue; end;
        SegLen := Abs(Along(P1, Ax) - Along(P0, Ax));
        if Along(P1, Ax) > Along(P0, Ax) then Dir := 1 else Dir := -1;
        C0 := Across(P0, Ax);
        Placed := False;
        T := Spec.Spacing;
        while (T + 2 * Spec.Spacing <= SegLen + 1E-9) and not Placed do
        begin
          A0 := Along(P0, Ax) + Dir * T;
          B0 := A0 + Dir * Spec.Spacing;
          for Sg := 1 downto -1 do
          begin
            if Sg = 0 then Continue;
            H := Min(Room(Li, Seg, Seg, Ax, Sg, Min(A0, B0), Max(A0, B0), C0, MinFinger),
              (Cap - Len[Li]) / 2 - 1E-6);
            if H < MinFinger - 1E-9 then Continue;
            { out, across, back - after P0, before P1 }
            N := Length(Q[Li]);
            SetLength(Q[Li], N + 4);
            Move(Q[Li][Seg + 1], Q[Li][Seg + 5], (N - Seg - 1) * SizeOf(T2));
            if Ax = 0 then
            begin
              Q[Li][Seg + 1] := Point2(A0, C0);
              Q[Li][Seg + 2] := Point2(A0, C0 + Sg * H);
              Q[Li][Seg + 3] := Point2(B0, C0 + Sg * H);
              Q[Li][Seg + 4] := Point2(B0, C0);
            end
            else
            begin
              Q[Li][Seg + 1] := Point2(C0, A0);
              Q[Li][Seg + 2] := Point2(C0 + Sg * H, A0);
              Q[Li][Seg + 3] := Point2(C0 + Sg * H, B0);
              Q[Li][Seg + 4] := Point2(C0, B0);
            end;
            Len[Li] := Len[Li] + 2 * H;
            Moved[Li] := True;
            Result := True; Placed := True;
            Break;
          end;
          T := T + Spec.Spacing;
        end;
        { the rest of this run, from the finger on, is the next segment }
        if Placed then Seg := Seg + 4 else Inc(Seg);
      end;
    end;

    { a loop grown here is the loop kept: what the replay shows as laid
      is what it finally is }
    procedure Retrace(const Was: TP3Array; const Now: TP3Array);
    var
      S, P: Integer;
      Same: Boolean;
    begin
      for S := High(Trace) downto 0 do
      begin
        if not Trace[S].Accepted or (Length(Trace[S].Pts) <> Length(Was)) then Continue;
        Same := True;
        for P := 0 to High(Was) do
          if Dist(Trace[S].Pts[P], Was[P]) > 1E-9 then begin Same := False; Break; end;
        if Same then begin Trace[S].Pts := Now; Exit; end;
      end;
    end;

    procedure Keep(const From: array of T2Array; const Lens: array of Double;
      const FromMoved: array of Boolean);
    var
      Li, P: Integer;
      Was: TP3Array;
    begin
      for Li := FromLoop to High(Loops) do
      begin
        if not FromMoved[Li] then Continue;
        Was := Loops[Li].Pts;
        SetLength(Loops[Li].Pts, Length(From[Li]));
        for P := 0 to High(From[Li]) do Loops[Li].Pts[P] := World(From[Li][P]);
        Loops[Li].LenFt := 0;
        for P := 1 to High(Loops[Li].Pts) do
          Loops[Li].LenFt := Loops[Li].LenFt + Dist(Loops[Li].Pts[P - 1], Loops[Li].Pts[P]);
        if WantTrace then Retrace(Was, Loops[Li].Pts);
      end;
    end;

    function Snapshot: TRadiantLoopArray;
    var
      Li, P: Integer;
    begin
      Result := Copy(Loops);
      for Li := FromLoop to High(Loops) do
        if Moved[Li] then
        begin
          SetLength(Result[Li].Pts, Length(Q[Li]));
          for P := 0 to High(Q[Li]) do Result[Li].Pts[P] := World(Q[Li][P]);
        end;
    end;

  begin
    if FromLoop > High(Loops) then Exit;
    { a finger is a hairpin out of a straight run and back: four bends.
      Only a long one earns them - a comb of two-foot teeth heated a few
      square feet for every four bends, and on 3/4" PEX at twelve inches
      it could hardly be laid (the owner's barn, 24 September) }
    MinFinger := FINGER_MIN_SPACINGS * Spec.Spacing;
    SetLength(Len, Length(Loops));
    Hi := 0;
    for I := 0 to High(Loops) do
    begin
      Len[I] := Loops[I].LenFt;
      if I >= FromLoop then Hi := Max(Hi, Len[I]);
    end;
    Bare0 := RegionBare(Loops);
    BestCost := Cost(Len, Bare0); BestBare := Bare0;
    BestQ := nil; BestLen := nil;
    { the shortest loops grow first: they have the most to give, and
      the spread between longest and shortest is what closes }
    SetLength(Order, Length(Loops) - FromLoop);
    for I := 0 to High(Order) do Order[I] := FromLoop + I;
    for I := 1 to High(Order) do
    begin
      J := I;
      while (J > 0) and (Len[Order[J - 1]] > Len[Order[J]]) do
      begin
        Tmp := Order[J]; Order[J] := Order[J - 1]; Order[J - 1] := Tmp; Dec(J);
      end;
    end;
    { grown no longer than the longest loop already is, so the spread
      can only close; and grown to the tube's own maximum, which heats
      more floor but can widen it - whichever costs less }
    for CapTry := 0 to 1 do
    begin
      if CapTry = 0 then Cap := Hi else Cap := MaxFt;
      if (CapTry = 1) and (MaxFt <= Hi + 1E-6) then Break;
      SetLength(Q, Length(Loops));
      SetLength(Moved, Length(Loops));
      for I := 0 to High(Loops) do
      begin
        SetLength(Q[I], Length(Loops[I].Pts));
        for J := 0 to High(Loops[I].Pts) do Q[I][J] := RadiantTo2(F, Loops[I].Pts[J]);
        Len[I] := Loops[I].LenFt;
        Moved[I] := False;
      end;
      { the turns pushed out first - longer straights, no new bend - then
        fingers, long ones only }
      J := 0;
      repeat
        Changed := False;
        for I := 0 to High(Order) do
          if PushOne(Order[I]) then Changed := True;
        Inc(J);
      until not Changed or (J >= 8);
      J := 0;
      if Fingers then
        repeat
          Changed := False;
          for I := 0 to High(Order) do
            if GrowOne(Order[I]) then Changed := True;
          Inc(J);
        until not Changed or (J >= 8);
      Bare0 := RegionBare(Snapshot);
      if Cost(Len, Bare0) < BestCost - 1E-6 then
      begin
        BestCost := Cost(Len, Bare0);
        BestQ := Copy(Q); BestLen := Copy(Len); BestMoved := Copy(Moved);
        for I := 0 to High(Q) do BestQ[I] := Copy(Q[I]);
        Unfilled := Unfilled - (BestBare - Bare0);
        BestBare := Bare0;
      end;
    end;
    if BestQ <> nil then Keep(BestQ, BestLen, BestMoved);
  end;

begin
  TargetFt := 0; FloorUnf := 0;
  OddSeen := False; Tightest := Spec.Spacing;
  RandState := Seed;
  for I := 0 to 63 do
    if Seed = 0 then begin RankBudget[I] := 1; RankJit[I] := 0; end
    else
    begin
      { a small generator of our own, so a seed means the same on every
        machine and every build }
      RandState := Cardinal((QWord(RandState) * 1664525 + 1013904223) and $FFFFFFFF);
      RankBudget[I] := 0.9 + 0.1 * ((RandState shr 8) and $FFFF) / 65535;
      RandState := Cardinal((QWord(RandState) * 1664525 + 1013904223) and $FFFFFFFF);
      RankJit[I] := Integer((RandState shr 8) mod 5) - 2;
    end;
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
    if MI <= High(Spec.ManifoldAngles) then Result.Manifolds[MI].Heading := Spec.ManifoldAngles[MI];
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
    if not Quick then GrowLoops(K);
    FloorUnf := FloorUnf + FloorBare(Loops);
    Inc(Result.Crossings, Meetings(K));
    Result.Manifolds[MI].LoopCount := Length(Loops) - K;
    Result.Manifolds[MI].Ports := Max(MANIFOLD_PORTS_MIN, Length(Loops) - K);
    Result.Manifolds[MI].Ft := 0;
    for I := K to High(Loops) do Result.Manifolds[MI].Ft := Result.Manifolds[MI].Ft + Loops[I].LenFt;
  end;

  Result.Loops := Loops;
  Result.Trace := Trace;
  Result.CellCount := 0;
  { reported on the fixed grid, not the rows' own - see FloorBare }
  Result.UnfilledSqFt := FloorUnf;
  Result.OddRows := OddSeen;
  Result.TightestGap := Tightest;
  Result.Bends := RadiantBends(Loops, Result.StraightPct, STRAIGHT_RUN_SPACINGS * Spec.Spacing);
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
{ how much of its floor R covers, and how far its shortest loop falls
  short of its longest, worst manifold, both as fractions }
procedure RadiantMeasure(const R: TRadiantResult; out Cover, Spread: Double);
var
  M, L: Integer;
  Lo, Hi: Double;
begin
  if R.AreaSqFt > 0 then Cover := Max(0, 1 - R.UnfilledSqFt / R.AreaSqFt) else Cover := 0;
  Spread := 0;
  for M := 0 to High(R.Manifolds) do
  begin
    Lo := 1E300; Hi := 0;
    for L := 0 to High(R.Loops) do
      if R.Loops[L].Manifold = M then
      begin
        Lo := Min(Lo, R.Loops[L].LenFt); Hi := Max(Hi, R.Loops[L].LenFt);
      end;
    if Hi > 0 then Spread := Max(Spread, (Hi - Lo) / Hi);
  end;
end;

function RadiantSpreadFt(const R: TRadiantResult): Double;
var
  M, L: Integer;
  Lo, Hi, Worst: Double;
begin
  Result := 0; Worst := -1;
  for M := 0 to High(R.Manifolds) do
  begin
    Lo := 1E300; Hi := 0;
    for L := 0 to High(R.Loops) do
      if R.Loops[L].Manifold = M then
      begin
        Lo := Min(Lo, R.Loops[L].LenFt); Hi := Max(Hi, R.Loops[L].LenFt);
      end;
    if (Hi > 0) and ((Hi - Lo) / Hi > Worst) then
    begin
      Worst := (Hi - Lo) / Hi;
      Result := Hi - Lo;
    end;
  end;
end;

function RadiantMeetsGoals(const R: TRadiantResult; const Spec: TRadiantSpec): Boolean;
var
  Cover, Spread: Double;
begin
  RadiantMeasure(R, Cover, Spread);
  Result := R.Ok and (R.Crossings = 0) and
    ((Spec.GoalCoverPct <= 0) or (Cover * 100 >= Spec.GoalCoverPct - 1E-9)) and
    ((Spec.GoalEvenPct <= 0) or (Spread * 100 <= Spec.GoalEvenPct + 1E-9));
end;

function ComputeRadiantLayout(const Outline: TP3Array; const Holes: array of TP3Array;
  const Spec: TRadiantSpec; WantTrace: Boolean = False;
  Progress: TRadiantProgress = nil; Found: PRadiantResults = nil;
  LiveGoals: PRadiantGoals = nil): TRadiantResult;
type
  { everything a layout is laid from - enough to lay it again, the same }
  TTry = record
    Turn: Boolean;
    Budget, BreakFt: Double;
    Ranks: Integer;
    Seed: Cardinal;
    { the row grid slid this fraction of a spacing off the wall }
    RowOff: Double;
    { no fingers grown, only turns pushed out - see the try after the
      row offsets }
    NoFingers: Boolean;
    { every side's rows evened up at the far wall - see RowPlan }
    EvenRows: Boolean;
    { the manifold slid this far along its wall, feet - see Slid }
    Shift: Double;
    { this many loops more, or fewer, than the layout would choose - see
      LoopDelta on ComputeRadiantOriented }
    LoopDelta: Integer;
  end;
const
  { a search nobody stops is not left running for ever }
  MAX_TRIES = 20000;
var
  TurnIndex, TurnLo, TurnHi, BudgetIndex, RankTry, Done, Total, Level: Integer;
  BestRank, Cover, Spread, BreakFt, MostCover, FirstCover, LastCover, Reach: Double;
  { a way of turning the rows given up on at this breakout }
  Weak: array[0..1] of Boolean;
  { the solutions kept for the wizard to show - see Offer - and the tries
    that laid them }
  Kept: TRadiantResults;
  KeptRank: array of Double;
  KeptTry: array of TTry;
  KeptMeet: Boolean;
  Stop, Met, Probe, Goals: Boolean;
  RF, WF: TRadiantFrame;
  H: TP3;
  Best, R: TRadiantResult;
  BestTry, T: TTry;
  Seed, RandState: Cardinal;
  { the spec searched with - Spec, its goals as LiveGoals last had them }
  Work: TRadiantSpec;
  { the try that last bettered the best, and how far along its wall the
    manifold can slide either way - see Slid }
  BetterAt: Integer;
  RoomBack, RoomOn: Double;
  WallDir: TP3;

  function Score(const R: TRadiantResult): Double;
  var
    M, L: Integer;
    Lo, Hi: Double;
  begin
    Result := R.UnfilledSqFt / (Work.Spacing * UNFILLED_LOOP_FT) + Length(R.Loops);
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

  { Lower is better.  How far short of the goals it falls counts first -
    coverage ten times evenness, a point for a point: the floor heated is
    what the layout is for, and even loops over a bare floor are no
    layout at all.  Weighed a point for a point, as they were at first,
    a search left running traded coverage away for evenness one step at
    a time - the owner watched it settle on loops perfectly even over
    five percent of the floor (24 September).  Past the coverage goal,
    what is still bare counts twice a point of evenness.  Then the old
    cost, then a
    little for every foot of breakout past the owner's four, so of two
    layouts that both meet the goals the closer breakout wins. }
  function RankOf(const R: TRadiantResult; BreakFt: Double): Double;
  var
    Cv, Sp, Short: Double;
  begin
    if not R.Ok or (R.Crossings > 0) then Exit(1E300);
    RadiantMeasure(R, Cv, Sp);
    Short := 0;
    if Work.GoalCoverPct > 0 then
      Short := Short + 10 * Max(0, Work.GoalCoverPct - Cv * 100)
        { and past the goal the floor still bare counts, twice what a
          point of evenness does: a layout at the goal with a strip left
          along a wall is not as good as the one that heats it with the
          loops a little less even (the owner, 25 September: "the engine
          seems to favor leaving unheated space rather than cheating in
          a close run") }
        + 2 * Min(100 - Cv * 100, 100 - Work.GoalCoverPct)
    { with no coverage goal, coverage still leads: every point of it
      missing from a whole floor }
    else Short := Short + 10 * (100 - Cv * 100);
    if Work.GoalEvenPct > 0 then Short := Short + Max(0, Sp * 100 - Work.GoalEvenPct);
    Result := 5 * Short + Score(R) + 0.25 * (BreakFt - MANIFOLD_BREAKOUT_FT) + BEND_WEIGHT * R.Bends;
    { and a layout that meets the goals before any that does not: counting
      the floor bare past the coverage goal, a layout at 81% covered and
      19% apart outranked one at 75% and 8% with the goals at 30 and 10,
      and a search told the new goals went on looking with a layout that
      met them in hand (25 September) }
    if Goals and not RadiantMeetsGoals(R, Work) then Result := Result + GOAL_MISS;
  end;

  { A try kept among the solutions to show: every distinct one that meets
    the goals, best first - or, while none has, the few nearest them - for
    the wizard's arrows to step through.  Two tries that lay the same
    layout are one solution. }
  procedure Offer(const R: TRadiantResult; Rk: Double; const T: TTry);
  var
    I, J: Integer;
    Cv, Sp, Cv2, Sp2: Double;
    Meets: Boolean;
  begin
    if (Found = nil) or (Rk >= 1E299) then Exit;
    Meets := RadiantMeetsGoals(R, Work);
    { the first to meet the goals clears out the near misses kept so far }
    if Meets and (Length(Kept) > 0) and not KeptMeet then
    begin
      SetLength(Kept, 0); SetLength(KeptRank, 0); SetLength(KeptTry, 0);
    end;
    if not Meets and KeptMeet then Exit;
    KeptMeet := KeptMeet or Meets;
    RadiantMeasure(R, Cv, Sp);
    for I := 0 to High(Kept) do
    begin
      RadiantMeasure(Kept[I], Cv2, Sp2);
      if (Length(Kept[I].Loops) = Length(R.Loops)) and (Abs(Kept[I].TotalFt - R.TotalFt) < 0.5) and
         (Abs(Cv2 - Cv) < 1E-4) then Exit;
    end;
    I := Length(Kept);
    while (I > 0) and (KeptRank[I - 1] > Rk) do Dec(I);
    if I >= SOLUTIONS_KEPT then Exit;
    SetLength(Kept, Length(Kept) + 1); SetLength(KeptRank, Length(Kept)); SetLength(KeptTry, Length(Kept));
    for J := High(Kept) downto I + 1 do
    begin
      Kept[J] := Kept[J - 1]; KeptRank[J] := KeptRank[J - 1]; KeptTry[J] := KeptTry[J - 1];
    end;
    Kept[I] := R; KeptRank[I] := Rk; KeptTry[I] := T;
    if Length(Kept) > SOLUTIONS_KEPT then
    begin
      SetLength(Kept, SOLUTIONS_KEPT); SetLength(KeptRank, SOLUTIONS_KEPT); SetLength(KeptTry, SOLUTIONS_KEPT);
    end;
  end;

  { The wall the manifold is on, and how far along it the manifold can go
    either way and stay on it, a foot short of its ends - worked out once.
    A piece of a curve is not a wall to slide along. }
  procedure FindWall;
  var
    I, J, Best_: Integer;
    D, BestD, L, Tp: Double;
    A, B, M: TP3;
  begin
    RoomBack := 0; RoomOn := 0; WallDir := P3(0, 0, 0);
    if Length(Work.Manifolds) = 0 then Exit;
    M := Work.Manifolds[0];
    Best_ := -1; BestD := 1E300;
    for I := 0 to High(Outline) do
    begin
      J := (I + 1) mod Length(Outline);
      A := Outline[I]; B := Outline[J];
      L := Sqr(B.X - A.X) + Sqr(B.Y - A.Y) + Sqr(B.Z - A.Z);
      if L < 1E-12 then Continue;
      Tp := Max(0, Min(1, ((M.X - A.X) * (B.X - A.X) + (M.Y - A.Y) * (B.Y - A.Y) + (M.Z - A.Z) * (B.Z - A.Z)) / L));
      D := Dist(M, P3(A.X + Tp * (B.X - A.X), A.Y + Tp * (B.Y - A.Y), A.Z + Tp * (B.Z - A.Z)));
      if D < BestD then begin BestD := D; Best_ := I; end;
    end;
    { off every wall by more than its breakout is out in the room: nothing
      to slide along }
    if (Best_ < 0) or (BestD > MANIFOLD_BREAKOUT_FT) or RadiantEdgeCurved(Outline, Best_) then Exit;
    A := Outline[Best_]; B := Outline[(Best_ + 1) mod Length(Outline)];
    L := Dist(A, B);
    WallDir := P3((B.X - A.X) / L, (B.Y - A.Y) / L, (B.Z - A.Z) / L);
    Tp := (M.X - A.X) * WallDir.X + (M.Y - A.Y) * WallDir.Y + (M.Z - A.Z) * WallDir.Z;
    RoomBack := Max(0, Tp - 1);
    RoomOn := Max(0, L - Tp - 1);
  end;

  { the spec with the manifold slid Shift feet along its wall - the same
    spec when that would leave the floor or land in an obstacle }
  function Slid(Shift: Double): TRadiantSpec;
  var
    M: TP3;
    H2: Integer;
  begin
    Result := Work;
    if (Abs(Shift) < 1E-9) or (Length(Work.Manifolds) = 0) then Exit;
    M := Work.Manifolds[0];
    M := P3(M.X + WallDir.X * Shift, M.Y + WallDir.Y * Shift, M.Z + WallDir.Z * Shift);
    if not RadiantInside(Outline, M) then Exit;
    for H2 := 0 to High(Holes) do
      if RadiantInside(Holes[H2], M) then Exit;
    Result.Manifolds := Copy(Work.Manifolds);
    Result.Manifolds[0] := M;
  end;

  { the watcher changed the goals: everything kept ranked again by them -
    the best, and the solutions, which keep only those that meet them
    once any does }
  procedure Regoal;
  var
    I, J: Integer;
    TmpR: TRadiantResult;
    TmpK: Double;
    TmpT: TTry;
  begin
    Work.GoalCoverPct := LiveGoals^.CoverPct;
    Work.GoalEvenPct := LiveGoals^.EvenPct;
    Goals := (Work.GoalCoverPct > 0) or (Work.GoalEvenPct > 0);
    if Best.Ok then
    begin
      BestRank := RankOf(Best, BestTry.BreakFt);
      if BestTry.EvenRows and (BestRank < 1E299) then BestRank := BestRank + 1;
    end;
    for I := 0 to High(Kept) do
    begin
      KeptRank[I] := RankOf(Kept[I], Kept[I].BreakoutFt);
      if KeptTry[I].EvenRows and (KeptRank[I] < 1E299) then KeptRank[I] := KeptRank[I] + 1;
    end;
    for I := 1 to High(Kept) do
    begin
      J := I;
      while (J > 0) and (KeptRank[J - 1] > KeptRank[J]) do
      begin
        TmpR := Kept[J]; Kept[J] := Kept[J - 1]; Kept[J - 1] := TmpR;
        TmpK := KeptRank[J]; KeptRank[J] := KeptRank[J - 1]; KeptRank[J - 1] := TmpK;
        TmpT := KeptTry[J]; KeptTry[J] := KeptTry[J - 1]; KeptTry[J - 1] := TmpT;
        Dec(J);
      end;
    end;
    { one of those kept may be the best there is by the new goals }
    if (Length(Kept) > 0) and (KeptRank[0] < BestRank - 1E-6) then
    begin
      Best := Kept[0]; BestRank := KeptRank[0]; BestTry := KeptTry[0];
    end;
    KeptMeet := False;
    for I := 0 to High(Kept) do
      if RadiantMeetsGoals(Kept[I], Work) then KeptMeet := True;
    if KeptMeet then
    begin
      J := 0;
      for I := 0 to High(Kept) do
        if RadiantMeetsGoals(Kept[I], Work) then
        begin
          Kept[J] := Kept[I]; KeptRank[J] := KeptRank[I]; KeptTry[J] := KeptTry[I]; Inc(J);
        end;
      SetLength(Kept, J); SetLength(KeptRank, J); SetLength(KeptTry, J);
    end;
    if Found <> nil then Found^ := Copy(Kept);
  end;

  { one layout tried, kept if it is the best yet; says so and asks
    whether to go on }
  function Consider(const T: TTry; out R: TRadiantResult): Boolean;
  var
    Rk, Cv, Sp, Cv2, Sp2: Double;
  begin
    R := ComputeRadiantOriented(Outline, Holes, Slid(T.Shift), False, T.Turn, T.Budget, T.Ranks,
      T.BreakFt, T.Seed, T.RowOff, not T.NoFingers, False, T.EvenRows, T.LoopDelta);
    R.ManifoldShiftFt := T.Shift;
    R.BreakoutFt := T.BreakFt;
    Rk := RankOf(R, T.BreakFt);
    { the rows closed up at a wall are a cheat: of two as good, the true
      grid }
    if T.EvenRows and (Rk < 1E299) then Rk := Rk + 1;
    { the first answer stands until a better one comes, so a floor with
      no layout still says why }
    if Done = 0 then Best := R;
    { and a layout covering more than two points less than the most any
      layout has covered is not a better one, whatever else it does
      better - against the most seen, not the one kept, so coverage
      cannot walk down two points at a time.  Unless it covers as much
      as the one kept: a layout the ranking passed over for its
      evenness, covering more, is no reason to refuse one that betters
      the one kept at its own coverage (the barn's zone B, 25 September:
      its rows slid along were refused for covering less than a layout
      that was never kept). }
    if R.Ok and (R.Crossings = 0) then
    begin
      RadiantMeasure(R, Cv, Sp);
      RadiantMeasure(Best, Cv2, Sp2);
      if (Cv < MostCover - 0.02) and not (Best.Ok and (Cv >= Cv2 - 1E-9)) then Rk := 1E300;
      MostCover := Max(MostCover, Cv);
    end;
    R.Tries := Done + 1;
    Offer(R, Rk, T);
    { kept up to date as it goes, for a watcher to list }
    if Found <> nil then Found^ := Copy(Kept);
    if Rk < BestRank - 1E-6 then
    begin
      Best := R; BestRank := Rk; BestTry := T;
      BetterAt := Done;
    end;
    Inc(Done);
    Stop := False;
    if Assigned(Progress) then Progress(Done, Total, Best, Stop);
    if (LiveGoals <> nil) and ((Abs(LiveGoals^.CoverPct - Work.GoalCoverPct) > 1E-9) or
       (Abs(LiveGoals^.EvenPct - Work.GoalEvenPct) > 1E-9)) then Regoal;
    Result := not Stop;
  end;

  { A try whose rows came out odd somewhere, laid again with them evened
    up at the far wall (see RowPlan) - the owner's cheat, for a layout
    struggling: short of the goals, or floor left bare.  A twin, not a
    last resort for the best alone: tried on the best only, it came too
    late - the ladder had gone a breakout wider for coverage the cheat
    would have found closer in (the barn's zone B, 25 September). }
  procedure Twin(const T: TTry; const R: TRadiantResult);
  var
    T2: TTry;
    R2: TRadiantResult;
    Cv, Sp: Double;
  begin
    { refused for covering too little is no reason not to: evened up, it
      covers more }
    if Stop or T.EvenRows or not R.Ok or (R.Crossings > 0) or not R.OddRows then Exit;
    RadiantMeasure(R, Cv, Sp);
    if RadiantMeetsGoals(R, Work) and (Cv >= EVEN_TRY_BELOW) then Exit;
    { nor one so far short of the best seen that a row more will not
      bring it near }
    if Cv < MostCover - EVEN_TWIN_WITHIN then Exit;
    Inc(Total);
    T2 := T;
    T2.EvenRows := True;
    Consider(T2, R2);
  end;

  function Rnd: Double;
  begin
    RandState := Cardinal((QWord(RandState) * 1664525 + 1013904223) and $FFFFFFFF);
    Result := ((RandState shr 8) and $FFFFFF) / 16777216;
  end;

begin
  Work := Spec;
  if LiveGoals <> nil then
  begin
    Work.GoalCoverPct := LiveGoals^.CoverPct;
    Work.GoalEvenPct := LiveGoals^.EvenPct;
  end;
  Result := Default(TRadiantResult);
  Result.Why := RadiantProblem(Outline, Work);
  if Result.Why <> '' then Exit;
  Goals := (Work.GoalCoverPct > 0) or (Work.GoalEvenPct > 0);
  { Which way the ports run.  A manifold given a heading - the box turned
    on the wizard's plan - is laid the way it faces: ports along the
    wall it hangs on, tubes out square from it, or turned a quarter so
    they run out along the wall.  With no heading both are tried, as
    they always were. }
  TurnLo := 0; TurnHi := 1;
  if (Length(Work.ManifoldAngles) > 0) and (Length(Work.Manifolds) > 0) then
  begin
    RF := RadiantFrameOf(Outline);
    WF := FrameAt(Outline, Work.Manifolds[0]);
    H := P3(RF.U.X * Cos(DegToRad(Work.ManifoldAngles[0])) + RF.V.X * Sin(DegToRad(Work.ManifoldAngles[0])),
            RF.U.Y * Cos(DegToRad(Work.ManifoldAngles[0])) + RF.V.Y * Sin(DegToRad(Work.ManifoldAngles[0])),
            RF.U.Z * Cos(DegToRad(Work.ManifoldAngles[0])) + RF.V.Z * Sin(DegToRad(Work.ManifoldAngles[0])));
    if Abs(Dot3(H, WF.U)) >= Abs(Dot3(H, WF.V)) then TurnHi := 0 else TurnLo := 1;
  end;
  Best := Default(TRadiantResult); BestRank := 1E300; MostCover := 0; BetterAt := 0;
  RoomBack := 0; RoomOn := 0; WallDir := P3(0, 0, 0);
  Kept := nil; KeptRank := nil; KeptTry := nil; KeptMeet := False;
  BestTry := Default(TTry); BestTry.Budget := 1; BestTry.BreakFt := MANIFOLD_BREAKOUT_FT;
  Done := 0; Total := BREAKOUT_LEVELS * (TurnHi - TurnLo + 1) * (3 + 4); Stop := False;

  { The fixed restarts, at the breakout first the owner's four feet,
    where every tube is out on the grid within four feet of the
    manifold.  A manifold's tubes can only leave that square through its
    edge at the spacing, and today's lanes use the top of it, not its
    sides - so where four feet cannot meet the goals, six, then eight,
    and on to twelve: a floor that wants one loop more than eight feet
    can let out - every loop at the tube's maximum and the far rows bare
    (24 September, two zones of the owner's barn) - is better served
    closing in a little further out than left bare.
    The first try at a breakout far short of the floor is enough to move
    on: the others at the same breakout will not make up ten percent. }
  for Level := 0 to BREAKOUT_LEVELS - 1 do
  begin
    if Stop then Break;
    BreakFt := MANIFOLD_BREAKOUT_FT + 2 * Level;
    Probe := True;
    Weak[0] := False; Weak[1] := False; FirstCover := 0;
    for TurnIndex := TurnLo to TurnHi do
      for BudgetIndex := 0 to 2 do
      begin
        if Stop or not Probe or Weak[TurnIndex] then Continue;
        T := Default(TTry);
        T.Turn := TurnIndex = 1; T.Budget := 1 - BudgetIndex * 0.25; T.BreakFt := BreakFt;
        if not Consider(T, R) then Break;
        if BudgetIndex = 0 then
        begin
          RadiantMeasure(R, Cover, Spread);
          if not R.Ok then Cover := 0;
          if (TurnIndex = TurnLo) and (Level < BREAKOUT_LEVELS - 1) and
             (Cover < Max(BREAKOUT_COVER, Work.GoalCoverPct / 100) - 0.1) then Probe := False;
          { The rows turned the other way, far behind the first way at
            its first try: no more of them at this breakout.  On the
            owner's odd floor (25 September) the turned rows trailed by
            fifteen to thirty points at every breakout, and their other
            tries were a third of a search that took 25 seconds. }
          if TurnIndex = TurnLo then FirstCover := Cover
          else if Cover < FirstCover - TURN_WEAK then Weak[TurnIndex] := True;
        end;
        if Probe then Twin(T, R);
      end;
    { A length-based estimate is only a starting point. Shortened circuits
      and detours may need more connections. Restart with additional lane
      ranks rather than silently stopping at that estimated manifold size. }
    if Probe then
      for TurnIndex := TurnLo to TurnHi do
      begin
        if Weak[TurnIndex] then Continue;
        LastCover := -1;
        for RankTry := 1 to 4 do
        begin
          if Stop then Break;
          T := Default(TTry);
          T.Turn := TurnIndex = 1; T.Budget := 1; T.Ranks := RankTry * 2; T.BreakFt := BreakFt;
          if not Consider(T, R) then Break;
          Twin(T, R);
          if R.Ok and (R.UnfilledSqFt < R.AreaSqFt * 0.03) then Break;
          { more ranks covering less than fewer did: more will not turn
            it round }
          RadiantMeasure(R, Cover, Spread);
          if not R.Ok then Cover := 0;
          if Cover < LastCover - 0.02 then Break;
          LastCover := Cover;
        end;
      end;
    { Covered from this close in: no wider.  Coverage alone decides it -
      the owner's four feet give way to heat the floor, not to even the
      loops a little more; evenness is sought at the breakout the floor
      needed, by the tries below. }
    if Best.Ok then
    begin
      RadiantMeasure(Best, Cover, Spread);
      if Cover >= IfThen(Work.GoalCoverPct > 0, Work.GoalCoverPct / 100, BREAKOUT_COVER) - 1E-9 then Break;
    end;
  end;

  { The row grid slid along: the best so far laid again with every row a
    quarter, a half and three quarters of a spacing further from the
    manifold.  Where the rows fall against a slanting wall, an obstacle
    or the far wall changes what is left bare - heizkreis-planer's panel
    offset, pointed at the floor instead of the panels. }
  if not Stop and Best.Ok and not RadiantMeetsGoals(Best, Work) then
  begin
    Inc(Total, 3);
    T := BestTry;
    for Level := 1 to 3 do
    begin
      T.RowOff := Level * 0.25;
      if not Consider(T, R) then Break;
      Twin(T, R);
    end;
  end;
  { And the best laid again without fingers - its turns pushed out, but
    no hairpins grown off its straights.  The ranking weighs the bends
    against the floor they heated: where the goals were met without them
    the plainer layout is kept. }
  if not Stop and Best.Ok and not BestTry.NoFingers then
  begin
    Inc(Total);
    T := BestTry;
    T.NoFingers := True;
    Consider(T, R);
  end;

  { Then, with somebody watching, other layouts until the goals are met
    or they say stop: every loop a random share of the limit - some short
    ones first, the owner's idea - its lane nudged, the breakout and the
    turn of the rows drawn at random.  Each one is its seed, so the one
    kept can be laid again exactly. }
  Met := RadiantMeetsGoals(Best, Work);
  if Assigned(Progress) and Goals and not Stop and not Met then
  begin
    Total := 0;
    Seed := 0;
    FindWall;
    while not Stop and not Met and (Done < MAX_TRIES) do
    begin
      Inc(Seed);
      RandState := Cardinal((QWord(Seed) * 2654435761) and $FFFFFFFF);
      T := Default(TTry);
      T.Turn := (TurnLo = 1) or ((TurnHi = 1) and (Rnd < 0.5));
      { a loop cut well short of the limit is one more loop and a wide
        spread - tried on the barn, every such layout was worse - so
        the shares stay near the whole of it }
      T.Budget := 0.85 + 0.15 * Rnd;
      T.Ranks := 2 * Trunc(Rnd * 5);
      T.BreakFt := MANIFOLD_BREAKOUT_FT + 2 * Trunc(Rnd * BREAKOUT_LEVELS);
      T.RowOff := Trunc(Rnd * 4) * 0.25;
      T.NoFingers := Rnd < 0.25;
      T.EvenRows := Rnd < 0.5;
      { The manifold slid along its wall, more often and further the
        longer nothing has bettered the best - the owner, 25 September:
        "it needs to get more aggressive with moving the manifold i think
        when it has 500 tries in and its not making progress" (report
        174734).  A few feet at first, a foot more every SHIFT_GROW tries
        without a better layout, never off the wall's ends. }
      if (Done - BetterAt > SHIFT_AFTER) or (Rnd < 0.15) then
      begin
        Reach := SHIFT_FT + Max(0, Done - BetterAt - SHIFT_AFTER) / SHIFT_GROW;
        if Rnd < 0.5 then T.Shift := -Min(RoomBack, Reach) * Rnd
        else T.Shift := Min(RoomOn, Reach) * Rnd;
        { whole inches, so a layout is laid again the same }
        T.Shift := Round(T.Shift * 12) / 12;
      end;
      { and, stuck, the loops forced one or two more or fewer than the
        layout would take - see LoopDelta }
      if (Done - BetterAt > SHIFT_AFTER) and (Rnd < 0.4) then
      begin
        T.LoopDelta := 1 + Trunc(Rnd * 2);
        if Rnd < 0.5 then T.LoopDelta := -T.LoopDelta;
      end;
      T.Seed := Seed;
      if not Consider(T, R) then Break;
      Met := RadiantMeetsGoals(Best, Work);
    end;
  end;

  Result := Best;
  { Replay the winning layout only, so discarded tries cannot appear as
    accepted loops in the animation. Normal preview allocates no trace. }
  if WantTrace and Result.Ok then
  begin
    Result := ComputeRadiantOriented(Outline, Holes, Slid(BestTry.Shift), True,
      BestTry.Turn, BestTry.Budget, BestTry.Ranks, BestTry.BreakFt, BestTry.Seed, BestTry.RowOff,
      not BestTry.NoFingers, False, BestTry.EvenRows, BestTry.LoopDelta);
    Result.BreakoutFt := BestTry.BreakFt;
    Result.ManifoldShiftFt := BestTry.Shift;
  end;
  Result.Tries := Done;
  Result.ShortOfGoals := Goals and not RadiantMeetsGoals(Result, Work);
  if Found <> nil then
  begin
    for Level := 0 to High(Kept) do
    begin
      Kept[Level].Tries := Done;
      Kept[Level].ShortOfGoals := Goals and not RadiantMeetsGoals(Kept[Level], Work);
    end;
    Found^ := Kept;
  end;
end;

function BuildRadiant(D: TWorkDoc; const Outline: TP3Array; const Holes: array of TP3Array;
  const R: TRadiantResult; const Spec: TRadiantSpec; Ink: TColor; PartName: string;
  Zone: Integer = 0): Integer;
var
  I, J, G, M, LoopG, LabelG, ManG, K: Integer;
  Mid, C, Ax, Ay: TP3;
  F: TRadiantFrame;
  Nth: TIntArray;
  Box: array[0..3] of TP3;
  Ca, Sa, W, H: Double;
  Summary: string;
const
  SX: array[0..3] of Integer = (-1, 1, 1, -1);
  SY: array[0..3] of Integer = (-1, -1, 1, 1);
begin
  Result := D.Live;
  { A zone is a group, named for the system it is - tube, spacing, loops,
    footage - so the entity panel says what was laid without a ticket to
    hand.  Inside it, nothing special to radiant: every loop a group of
    its own, so a click takes the whole run from port to port and the
    ordinary panel gives its length and its box; the manifold a group;
    and every label in one more group, so "/hide labels" puts a zone's
    notes away - every zone's at once - and "/show labels" brings them
    back.  The standard tools do the rest. }
  { the spacing as the trade says it - 9", not 0'-9" }
  Summary := Format('%s at %s" o.c. - %d loop%s, %s', [StringReplace(TUBE_NAMES[Spec.Tube], '  ', ' ', [rfReplaceAll]),
    FormatFloat('0.##', Spec.Spacing / Spec.Inch), Length(R.Loops), IfThen(Length(R.Loops) = 1, '', 's'),
    FormatLen(R.TotalFt, usImperial)]);
  G := D.NewPart(PartName + ' - ' + Summary, 0);
  LabelG := D.NewPart(PartName + ' labels', G);
  { unticked, the labels are there all the same, put away }
  if not Spec.Labels then D.SetPartHidden(LabelG, True);
  { The runs are reference lines - Heck's "ref = true", the kind a
    dimension's own line is.  They draw in full, in the tube's ink, and
    the region finder leaves them alone: a hard line would close faces
    with the floor's edges (a serpentine and its leads is one long closed
    loop), and a soft one is hidden wherever it is not the edge of a face,
    which on a flat floor is everywhere - the first build had them
    invisible for exactly that reason. }
  { each manifold is a zone in its own color; its loops alternate thick
    and thin so two side by side can be told apart; and each carries its
    number and length, since a plan with the footage on it is the plan a
    fitter wants }
  SetLength(Nth, Length(R.Manifolds));
  for I := 0 to High(R.Loops) do
  begin
    M := R.Loops[I].Manifold;
    LoopG := D.NewPart(Format('Z%d L%d  %s', [Zone + M + 1, Nth[M] + 1,
      FormatLen(R.Loops[I].LenFt, usImperial)]), G);
    D.Stamp := LoopG;
    for J := 1 to High(R.Loops[I].Pts) do
      D.AddLine(R.Loops[I].Pts[J - 1], R.Loops[I].Pts[J], LoopInk(Zone + M, Nth[M]), LoopWeight(Nth[M]), True);
    if Length(R.Loops[I].Pts) > 3 then
    begin
      D.Stamp := LabelG;
      Mid := R.Loops[I].Pts[Length(R.Loops[I].Pts) div 2];
      D.AddNote(Mid, Mid, Format('Z%d L%d  %s', [Zone + M + 1, Nth[M] + 1,
        FormatLen(R.Loops[I].LenFt, usImperial)]), LoopInk(Zone + M, Nth[M]));
    end;
    Inc(Nth[M]);
  end;
  D.Stamp := LabelG;
  for I := 0 to High(Holes) do
    if Length(Holes[I]) > 0 then
    begin
      Mid := P3(0, 0, 0);
      for J := 0 to High(Holes[I]) do
        Mid := P3(Mid.X + Holes[I][J].X / Length(Holes[I]), Mid.Y + Holes[I][J].Y / Length(Holes[I]),
          Mid.Z + Holes[I][J].Z / Length(Holes[I]));
      D.AddNote(P3(Mid.X, Mid.Y, Mid.Z), Mid, 'no tube - obstacle', Ink);
    end;
  { The manifold: the box it is, turned the way it hangs, in a group of
    its own - and the zone's summary on a note beside it. }
  F := RadiantFrameOf(Outline);
  for M := 0 to High(R.Manifolds) do
  begin
    ManG := D.NewPart(Format('Z%d manifold - %d loop%s', [Zone + M + 1, R.Manifolds[M].LoopCount,
      IfThen(R.Manifolds[M].LoopCount = 1, '', 's')]), G);
    D.Stamp := ManG;
    C := R.Manifolds[M].At;
    Ca := Cos(DegToRad(R.Manifolds[M].Heading)); Sa := Sin(DegToRad(R.Manifolds[M].Heading));
    Ax := P3(F.U.X * Ca + F.V.X * Sa, F.U.Y * Ca + F.V.Y * Sa, F.U.Z * Ca + F.V.Z * Sa);
    Ay := P3(-F.U.X * Sa + F.V.X * Ca, -F.U.Y * Sa + F.V.Y * Ca, -F.U.Z * Sa + F.V.Z * Ca);
    W := Spec.ManifoldW / 2; H := Spec.ManifoldH / 2;
    for K := 0 to 3 do
      Box[K] := P3(C.X + SX[K] * W * Ax.X + SY[K] * H * Ay.X,
        C.Y + SX[K] * W * Ax.Y + SY[K] * H * Ay.Y,
        C.Z + SX[K] * W * Ax.Z + SY[K] * H * Ay.Z);
    for K := 0 to 3 do
      D.AddLine(Box[K], Box[(K + 1) mod 4], ZoneInk(Zone + M), 2, True);
    D.Stamp := LabelG;
    D.AddNote(P3(C.X + F.V.X * 2, C.Y + F.V.Y * 2, C.Z + F.V.Z * 2), C,
      Format('Zone %d manifold - %s', [Zone + M + 1, Summary]),
      ZoneInk(Zone + M));
  end;
  { an obstacle added in the wizard goes onto the floor as a ring of plain
    lines; lying flat inside the face, the program's own rule makes it a
    hole, the same as one drawn by hand }
  D.Stamp := G;
  if Zone = 0 then
    for I := 0 to High(Spec.Extra) do
      for J := 0 to High(Spec.Extra[I]) do
        D.AddLine(Spec.Extra[I][J], Spec.Extra[I][(J + 1) mod Length(Spec.Extra[I])], Ink, 1, False);
  D.Stamp := 0;
end;

function RadiantManifoldWallIn(Ports: Integer): Double;
begin
  Result := Ceil(2 * Max(Ports, MANIFOLD_PORTS_MIN) * MANIFOLD_PORT_PITCH_IN + MANIFOLD_ENDS_IN);
end;

function RadiantTicketText(const Spec: TRadiantSpec; const R: TRadiantResult;
  U: TUnitSystem): string;
var
  I, M: Integer;
  T: TTubeFacts;
  Ties: Integer;
  MaxFt, Cover, Spread: Double;
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
    { the owner, 25 September: "in the final notes it should tell roughly
      the wall space required for the manifold" }
    Result := Result + Format('  wall space: about %s along the wall - supply and return side by side %s" apart, ' +
      'and %s" for the valves and end caps', [FormatLen(RadiantManifoldWallIn(R.Manifolds[M].Ports) * Spec.Inch, U),
      FormatFloat('0.#', MANIFOLD_PORT_PITCH_IN), FormatFloat('0', MANIFOLD_ENDS_IN)]) + LineEnding;
    for I := 0 to High(R.Loops) do
      if R.Loops[I].Manifold = M then
        Result := Result + Format('  loop %d: %s%s', [I + 1, FormatLen(R.Loops[I].LenFt, U),
          IfThen(R.Loops[I].LenFt > MaxFt, '  - OVER the maximum for this tube', '')]) + LineEnding;
  end;
  if R.BreakoutFt > 0 then
    Result := Result + Format('breakout: every tube on the %s" grid within %s ft of its manifold%s',
      [FormatFloat('0.#', Spec.Spacing / Spec.Inch), FormatFloat('0', R.BreakoutFt),
       IfThen(R.BreakoutFt > MANIFOLD_BREAKOUT_FT + 1E-6,
         Format(' - wider than %s ft to cover the floor', [FormatFloat('0', MANIFOLD_BREAKOUT_FT)]), '')]) + LineEnding;
  { the manifold where the search moved it, said: it is not where it was
    put }
  if (Length(R.Loops) > 0) and (Abs(R.ManifoldShiftFt) > 1E-6) then
    Result := Result + Format('manifold moved %s along its wall from where it was placed, for a better layout',
      [FormatLen(Abs(R.ManifoldShiftFt), U)]) + LineEnding;
  { the owner's cheat, where it was taken: said, since a fitter chalking
    the rows out at the spacing would come up a row short }
  if (Length(R.Loops) > 0) and (R.TightestGap < Spec.Spacing - 1E-6) then
    Result := Result + Format('rows at the far wall closed up to %s" (from %s") so every row pairs with another',
      [FormatFloat('0.#', R.TightestGap / Spec.Inch), FormatFloat('0.#', Spec.Spacing / Spec.Inch)]) + LineEnding;
  if R.ShortOfGoals then
  begin
    RadiantMeasure(R, Cover, Spread);
    Result := Result + Format('SHORT OF THE GOALS: %s%% covered (goal %s%%), loops within %s%% (%s) (goal %s%%) - ' +
      'the best of %d layouts tried', [FormatFloat('0.0', Cover * 100), FormatFloat('0', Spec.GoalCoverPct),
      FormatFloat('0', Spread * 100), FormatLen(RadiantSpreadFt(R), U), FormatFloat('0', Spec.GoalEvenPct),
      R.Tries]) + LineEnding;
  end;
  { the breakout lets out only so many tubes at the spacing: a floor that
    wants more loops than that is left bare, and the fix is not here }
  if (R.BreakoutFt > 0) and (R.AreaSqFt > 0) and (R.UnfilledSqFt > R.AreaSqFt * (1 - BREAKOUT_COVER)) then
    Result := Result + Format('NOT COVERED: %s of the floor is bare - more loops than one manifold can let out ' +
      'at this spacing.  A second manifold, a bigger tube or a wider spacing.',
      [FormatArea(R.UnfilledSqFt, U)]) + LineEnding;
  if Length(R.Loops) > 0 then
    Result := Result + Format('to lay: %d bends, %s%% of the tube in straights of %s or more',
      [R.Bends, FormatFloat('0', R.StraightPct), FormatLen(STRAIGHT_RUN_SPACINGS * Spec.Spacing, U)]) + LineEnding;
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
