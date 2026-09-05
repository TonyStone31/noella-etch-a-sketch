{ Planar regions, worked out from the edges rather than stored and patched.

  Give it a bag of segments and it hands back the flat areas they enclose.
  Nothing here knows about the document, the screen, or any tool - it is a
  pure function from segments to regions, which is what makes it testable on
  its own and what stops the special cases creeping back in.

  The pipeline, in order:

    1. cut every segment where another one crosses or touches it
    2. weld endpoints that are within one tolerance of each other
    3. gather the edges into the planes they lie in
    4. in each plane, walk the smallest cycles of a directed half-edge graph
    5. a cycle sitting inside another is a hole in it, as well as a region
       in its own right

  Step 4 is the only clever part.  Every undirected edge becomes two darts.
  At each vertex the darts leaving it are sorted by angle.  Walking a face
  means: having arrived along a dart, leave by the dart immediately clockwise
  of the way you came.  Follow that and you trace one face; do it from every
  dart and you have traced them all.  The one cycle that comes out wound the
  wrong way is the infinite space around the drawing, and is thrown away.

  The tolerance is a distance in model units and there is exactly one of it.
  Everything - welding, "is this point on that line", "is this the same
  plane" - is decided by REGION_TOL, so there is one number to argue about
  rather than a dozen scattered epsilons. }
unit uRegion;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, uWork;

const
  { One tolerance for the whole pipeline.  Model units are feet, so this is
    about a ten-thousandth of an inch - far below anything drawable, and far
    above the rounding in a projection. }
  REGION_TOL = 1E-6;

type
  TSeg = record
    A, B: TP3;
  end;
  TSegArray = array of TSeg;

  TLoopArray = array of TP3Array;

  { A flat area: the plane it lies in, the loop round the outside, and the
    loops of anything cut out of it. }
  TRegion = record
    Normal: TP3;
    Outer: TP3Array;
    Holes: TLoopArray;
  end;
  TRegionArray = array of TRegion;

  { A plane, in a form two of them can be compared: a unit normal whose first
    non-zero part is positive, and how far along it the plane sits. }
  TPlaneKey = record
    N: TP3;
    D: Double;
  end;
  TPlaneArray = array of TPlaneKey;

  { What a rebuild remembers, so a plane whose edges did not move is not
    worked out again.  Hand the same one back each time. }
  TRegionCache = record
    Keys: TPlaneArray;
    Sig: array of Int64;
    Found: array of TRegionArray;
  end;

{ The whole pipeline.  Segments in, regions out. }
function BuildRegions(const Segs: TSegArray; Tol: Double = REGION_TOL): TRegionArray;

{ The same, but a plane whose segments have not moved since last time keeps
  the regions it had.  Editing one wall of a model with forty planes in it
  then costs one wall's worth of work rather than the whole model's.  Hand
  back the same cache each time; an empty one is a full rebuild. }
function BuildRegionsCached(const Segs: TSegArray; var Cache: TRegionCache;
  Tol: Double = REGION_TOL): TRegionArray;

{ Step 1 on its own, because it is worth testing by itself: every segment cut
  wherever another crosses or touches it. }
function SplitAtCrossings(const Segs: TSegArray; Tol: Double = REGION_TOL): TSegArray;

{ Area of a closed loop, signed by which way round it goes, measured in its
  own plane. }
function LoopArea(const Loop: TP3Array; const Normal: TP3): Double;

{ Is this point inside that loop?  The loop is assumed flat and the point in
  its plane; a point exactly on the boundary counts as inside. }
function PointInLoop(const P: TP3; const Loop: TP3Array; const Normal: TP3;
  Tol: Double = REGION_TOL): Boolean;

implementation

type
  TIntArray = array of Integer;

  TDart = record
    V0, V1: Integer;      { from, to }
    Twin: Integer;
    Ang: Double;          { direction leaving V0, in the plane's coordinates }
    Used: Boolean;
  end;

{ ---------------------------------------------------------------- helpers - }

function Len3(const A: TP3): Double; inline;
begin
  Result := Sqrt(A.X * A.X + A.Y * A.Y + A.Z * A.Z);
end;

function Sub3(const A, B: TP3): TP3; inline;
begin
  Result := P3(A.X - B.X, A.Y - B.Y, A.Z - B.Z);
end;

function Add3(const A, B: TP3): TP3; inline;
begin
  Result := P3(A.X + B.X, A.Y + B.Y, A.Z + B.Z);
end;

function Mul3(const A: TP3; S: Double): TP3; inline;
begin
  Result := P3(A.X * S, A.Y * S, A.Z * S);
end;

function Lerp(const A, B: TP3; T: Double): TP3; inline;
begin
  Result := P3(A.X + (B.X - A.X) * T, A.Y + (B.Y - A.Y) * T,
               A.Z + (B.Z - A.Z) * T);
end;

{ Where P falls along AB, and how far off it is.  T is clamped to the segment
  so Off is the real distance to the segment, not to its infinite line. }
procedure ClosestOnSeg(const P, A, B: TP3; out T, Off: Double);
var
  D: TP3;
  L2: Double;
begin
  D := Sub3(B, A);
  L2 := D.X * D.X + D.Y * D.Y + D.Z * D.Z;
  if L2 < 1E-18 then
  begin
    T := 0;
    Off := Dist(P, A);
    Exit;
  end;
  T := ((P.X - A.X) * D.X + (P.Y - A.Y) * D.Y + (P.Z - A.Z) * D.Z) / L2;
  T := EnsureRange(T, 0, 1);
  Off := Dist(P, Add3(A, Mul3(D, T)));
end;

{ Make a plane comparable: flip it so the first part of the normal that is not
  zero is positive, which gives one key per plane rather than two. }
function MakePlane(const N: TP3; const Through: TP3): TPlaneKey;
var
  U: TP3;
  L: Double;
begin
  L := Len3(N);
  if L < 1E-12 then
  begin
    Result.N := P3(0, 0, 1);
    Result.D := 0;
    Exit;
  end;
  U := Mul3(N, 1 / L);
  if (U.X < -REGION_TOL) or
     ((Abs(U.X) <= REGION_TOL) and (U.Y < -REGION_TOL)) or
     ((Abs(U.X) <= REGION_TOL) and (Abs(U.Y) <= REGION_TOL) and (U.Z < 0)) then
    U := Mul3(U, -1);
  Result.N := U;
  Result.D := U.X * Through.X + U.Y * Through.Y + U.Z * Through.Z;
end;

function SamePlane(const A, B: TPlaneKey; Tol: Double): Boolean;
begin
  Result := (Abs(A.N.X - B.N.X) < 1E-6) and (Abs(A.N.Y - B.N.Y) < 1E-6) and
            (Abs(A.N.Z - B.N.Z) < 1E-6) and (Abs(A.D - B.D) < Tol);
end;

{ Two axes across a plane, so points in it can be treated as flat. }
procedure PlaneBasis(const N: TP3; out U, W: TP3);
var
  T: TP3;
begin
  if Abs(N.Z) < 0.9 then T := P3(0, 0, 1) else T := P3(1, 0, 0);
  U := Norm3(Cross3(T, N));
  W := Norm3(Cross3(N, U));
end;

{ ------------------------------------------------- 1. cut at the crossings - }

{ Where two segments properly cross - each passing through the other's middle.
  An end landing on another segment is not handled here: that case, and a
  segment lying along part of another, are both just "this point sits inside
  that segment", which SplitAtCrossings asks directly.  Keeping the two apart
  is what removed the special case for parallel lines. }
function MeetAt(const A1, A2, B1, B2: TP3; Tol: Double;
  out TA, TB: Double): Boolean;
var
  U, V, W, PA, PB: TP3;
  A, B, C, D, E, Den: Double;
begin
  Result := False;
  TA := 0;
  TB := 0;

  U := Sub3(A2, A1);
  V := Sub3(B2, B1);
  W := Sub3(A1, B1);

  A := Dot3(U, U);
  B := Dot3(U, V);
  C := Dot3(V, V);
  D := Dot3(U, W);
  E := Dot3(V, W);
  Den := A * C - B * B;
  if (A < 1E-18) or (C < 1E-18) then Exit;

  { parallel, so there is no single crossing point - the overlap case is
    handled by the endpoint pass instead }
  if Abs(Den) < 1E-15 * A * C then Exit;

  TA := (B * E - C * D) / Den;
  TB := (A * E - B * D) / Den;
  { strictly inside both, or it is an endpoint case and not ours }
  if (TA <= Tol) or (TA >= 1 - Tol) or (TB <= Tol) or (TB >= 1 - Tol) then Exit;

  PA := Add3(A1, Mul3(U, TA));
  PB := Add3(B1, Mul3(V, TB));
  if Dist(PA, PB) > Tol then Exit;      { skew, passing at a distance }
  Result := True;
end;

function SplitAtCrossings(const Segs: TSegArray; Tol: Double): TSegArray;
var
  Cuts: array of array of Double;
  I, J, K, M, N, Count, GMask: Integer;
  TA, TB, Tmp, Cell: Double;
  P, Q, Lo, Hi: TP3;
  Grid: array of TIntArray;
  Near: TIntArray;

  procedure GrowBox(const R: TP3);
  begin
    Lo := P3(Min(Lo.X, R.X), Min(Lo.Y, R.Y), Min(Lo.Z, R.Z));
    Hi := P3(Max(Hi.X, R.X), Max(Hi.Y, R.Y), Max(Hi.Z, R.Z));
  end;

  function GridHash(CX, CY, CZ: Int64): Integer;
  begin
    Result := Integer((CX * 73856093) xor (CY * 19349663) xor (CZ * 83492791))
      and GMask;
  end;

  { Walk the cells this segment's box covers.  Putting it in when Add is set,
    otherwise gathering everything already there. }
  procedure Visit(Which: Integer; Add: Boolean);
  var
    X0, Y0, Z0, X1, Y1, Z1, CX, CY, CZ: Int64;
    H, Q2: Integer;
  begin
    X0 := Floor(Min(Segs[Which].A.X, Segs[Which].B.X) / Cell);
    X1 := Floor(Max(Segs[Which].A.X, Segs[Which].B.X) / Cell);
    Y0 := Floor(Min(Segs[Which].A.Y, Segs[Which].B.Y) / Cell);
    Y1 := Floor(Max(Segs[Which].A.Y, Segs[Which].B.Y) / Cell);
    Z0 := Floor(Min(Segs[Which].A.Z, Segs[Which].B.Z) / Cell);
    Z1 := Floor(Max(Segs[Which].A.Z, Segs[Which].B.Z) / Cell);
    for CX := X0 to X1 do
      for CY := Y0 to Y1 do
        for CZ := Z0 to Z1 do
        begin
          H := GridHash(CX, CY, CZ);
          if Add then
          begin
            SetLength(Grid[H], Length(Grid[H]) + 1);
            Grid[H][High(Grid[H])] := Which;
          end
          else
            for Q2 := 0 to High(Grid[H]) do
            begin
              SetLength(Near, Length(Near) + 1);
              Near[High(Near)] := Grid[H][Q2];
            end;
        end;
  end;

  procedure AddCut(Which: Integer; T: Double);
  var
    Z: Integer;
  begin
    if (T <= Tol) or (T >= 1 - Tol) then Exit;
    for Z := 0 to High(Cuts[Which]) do
      if Abs(Cuts[Which][Z] - T) < Tol then Exit;
    SetLength(Cuts[Which], Length(Cuts[Which]) + 1);
    Cuts[Which][High(Cuts[Which])] := T;
  end;

begin
  N := Length(Segs);
  SetLength(Cuts, N);

  { Only segments that come near each other can meet, so rather than trying
    every pair, each one is listed in the cells of a coarse grid its box
    covers and only the pairs that share a cell are tried.  Testing a pair
    twice costs nothing - a cut already recorded is ignored. }
  Lo := Segs[0].A; Hi := Segs[0].A;
  for I := 0 to N - 1 do
  begin
    GrowBox(Segs[I].A);
    GrowBox(Segs[I].B);
  end;
  Cell := Max(Dist(Lo, Hi) / Max(4, Round(Sqrt(N))), 1E-9);
  GMask := 1;
  while GMask < N * 4 do GMask := GMask * 2;
  Dec(GMask);
  SetLength(Grid, GMask + 1);
  for I := 0 to N - 1 do
    Visit(I, True);

  for I := 0 to N - 1 do
  begin
    SetLength(Near, 0);
    Visit(I, False);
    for K := 0 to High(Near) do
    begin
      J := Near[K];
      if J <= I then Continue;
      { a proper crossing, each through the other's middle }
      if MeetAt(Segs[I].A, Segs[I].B, Segs[J].A, Segs[J].B, Tol, TA, TB) then
      begin
        AddCut(I, TA);
        AddCut(J, TB);
      end;
      { and every end that lands inside the other one.  This is the T-junction
        a grid of lines is made of, and it is also what cuts a segment that
        lies along part of another - one rule for both, asked all four ways. }
      ClosestOnSeg(Segs[J].A, Segs[I].A, Segs[I].B, TA, TB);
      if TB < Tol then AddCut(I, TA);
      ClosestOnSeg(Segs[J].B, Segs[I].A, Segs[I].B, TA, TB);
      if TB < Tol then AddCut(I, TA);
      ClosestOnSeg(Segs[I].A, Segs[J].A, Segs[J].B, TA, TB);
      if TB < Tol then AddCut(J, TA);
      ClosestOnSeg(Segs[I].B, Segs[J].A, Segs[J].B, TA, TB);
      if TB < Tol then AddCut(J, TA);
    end;
  end;

  Count := 0;
  SetLength(Result, N);
  for I := 0 to N - 1 do
  begin
    { sort this segment's cuts along it }
    for J := 1 to High(Cuts[I]) do
    begin
      Tmp := Cuts[I][J];
      K := J - 1;
      while (K >= 0) and (Cuts[I][K] > Tmp) do
      begin
        Cuts[I][K + 1] := Cuts[I][K];
        Dec(K);
      end;
      Cuts[I][K + 1] := Tmp;
    end;

    P := Segs[I].A;
    for J := 0 to Length(Cuts[I]) do
    begin
      if J = Length(Cuts[I]) then Q := Segs[I].B
      else Q := Lerp(Segs[I].A, Segs[I].B, Cuts[I][J]);
      if Dist(P, Q) > Tol then
      begin
        if Count >= Length(Result) then SetLength(Result, Count * 2 + 8);
        Result[Count].A := P;
        Result[Count].B := Q;
        Inc(Count);
      end;
      P := Q;
    end;
  end;
  SetLength(Result, Count);
  M := 0;
  if M > 0 then ;
end;

{ ------------------------------------------------------------- the rest - }

function LoopArea(const Loop: TP3Array; const Normal: TP3): Double;
var
  I, N: Integer;
  Acc: TP3;
begin
  Result := 0;
  N := Length(Loop);
  if N < 3 then Exit;
  Acc := P3(0, 0, 0);
  for I := 0 to N - 1 do
    Acc := Add3(Acc, Cross3(Loop[I], Loop[(I + 1) mod N]));
  Result := Dot3(Acc, Normal) / 2;
end;

function PointInLoop(const P: TP3; const Loop: TP3Array; const Normal: TP3;
  Tol: Double): Boolean;
var
  I, J, N: Integer;
  U, W: TP3;
  PU, PV: Double;
  AU, AV, BU, BV: Double;
  Inside: Boolean;
  T, Off: Double;
begin
  Result := False;
  N := Length(Loop);
  if N < 3 then Exit;
  PlaneBasis(Normal, U, W);

  { on the boundary counts, and has to be asked separately - a ray cast is
    unreliable exactly on an edge }
  for I := 0 to N - 1 do
  begin
    ClosestOnSeg(P, Loop[I], Loop[(I + 1) mod N], T, Off);
    if Off < Tol then Exit(True);
  end;

  PU := Dot3(Sub3(P, Loop[0]), U);
  PV := Dot3(Sub3(P, Loop[0]), W);
  Inside := False;
  J := N - 1;
  for I := 0 to N - 1 do
  begin
    AU := Dot3(Sub3(Loop[I], Loop[0]), U);
    AV := Dot3(Sub3(Loop[I], Loop[0]), W);
    BU := Dot3(Sub3(Loop[J], Loop[0]), U);
    BV := Dot3(Sub3(Loop[J], Loop[0]), W);
    if ((AV > PV) <> (BV > PV)) and
       (PU < (BU - AU) * (PV - AV) / (BV - AV) + AU) then
      Inside := not Inside;
    J := I;
  end;
  Result := Inside;
end;

{ Which plane each input segment can lie in, worked out from the segments
  alone - no splitting, no welding.  Cheap enough to run on every edit, which
  is what lets the planes that did not change be left alone. }
function PlanesOf(const Segs: TSegArray; Tol: Double): TPlaneArray;
var
  I, J, K, N, NP: Integer;
  Ends: TP3Array;
  NEnds: Integer;
  AtEnd: array of TIntArray;
  Key: TPlaneKey;
  Dir1, Dir2: TP3;

  function EndOf(const P: TP3): Integer;
  var
    Q: Integer;
  begin
    for Q := 0 to NEnds - 1 do
      if Dist(Ends[Q], P) < Tol then Exit(Q);
    if NEnds >= Length(Ends) then SetLength(Ends, Max(16, NEnds * 2));
    Ends[NEnds] := P;
    Result := NEnds;
    Inc(NEnds);
  end;

begin
  Result := nil;
  N := Length(Segs);
  if N < 3 then Exit;
  NEnds := 0;
  SetLength(Ends, N * 2);
  SetLength(AtEnd, N * 2);
  for I := 0 to N - 1 do
  begin
    J := EndOf(Segs[I].A);
    SetLength(AtEnd[J], Length(AtEnd[J]) + 1);
    AtEnd[J][High(AtEnd[J])] := I;
    J := EndOf(Segs[I].B);
    SetLength(AtEnd[J], Length(AtEnd[J]) + 1);
    AtEnd[J][High(AtEnd[J])] := I;
  end;

  NP := 0;
  SetLength(Result, 8);
  for K := 0 to NEnds - 1 do
    for I := 0 to High(AtEnd[K]) - 1 do
      for J := I + 1 to High(AtEnd[K]) do
      begin
        Dir1 := Sub3(Segs[AtEnd[K][I]].B, Segs[AtEnd[K][I]].A);
        Dir2 := Sub3(Segs[AtEnd[K][J]].B, Segs[AtEnd[K][J]].A);
        if Len3(Cross3(Dir1, Dir2)) < 1E-9 then Continue;
        Key := MakePlane(Cross3(Dir1, Dir2), Ends[K]);
        for N := 0 to NP - 1 do
          if SamePlane(Result[N], Key, Tol) then Key.D := 1E300;
        if Key.D > 1E299 then Continue;
        if NP >= Length(Result) then SetLength(Result, NP * 2);
        Result[NP] := Key;
        Inc(NP);
      end;
  SetLength(Result, NP);
end;

{ The segments lying in one plane, and a number that changes whenever they do.
  Two drawings with the same segments in a plane give the same signature, so a
  plane whose signature has not moved does not need working out again. }
function SegsInPlane(const Segs: TSegArray; const K: TPlaneKey; Tol: Double;
  out Sig: Int64): TSegArray;
var
  I, N: Integer;

  function Mix(const P: TP3): Int64;
  begin
    Result := Round(P.X / Tol) * 73856093;
    Result := Result xor (Round(P.Y / Tol) * 19349663);
    Result := Result xor (Round(P.Z / Tol) * 83492791);
  end;

begin
  N := 0;
  Sig := 0;
  SetLength(Result, Length(Segs));
  for I := 0 to High(Segs) do
    if (Abs(Dot3(K.N, Segs[I].A) - K.D) < Tol) and
       (Abs(Dot3(K.N, Segs[I].B) - K.D) < Tol) then
    begin
      Result[N] := Segs[I];
      { order must not matter, so the two ends are added and the pair is
        added into the running total }
      Sig := Sig + (Mix(Segs[I].A) + Mix(Segs[I].B));
      Inc(N);
    end;
  SetLength(Result, N);
  Sig := Sig xor (Int64(N) * 2654435761);
end;

function BuildRegionsCached(const Segs: TSegArray; var Cache: TRegionCache;
  Tol: Double): TRegionArray;
var
  Keys: TPlaneArray;
  Mine: TSegArray;
  Fresh: TRegionCache;
  Sig: Int64;
  I, J, N, Count: Integer;
  Hit: Boolean;
begin
  Result := nil;
  Keys := PlanesOf(Segs, Tol);
  if Length(Keys) = 0 then
  begin
    Cache.Keys := nil;
    Cache.Sig := nil;
    Cache.Found := nil;
    Exit;
  end;

  N := Length(Keys);
  SetLength(Fresh.Keys, N);
  SetLength(Fresh.Sig, N);
  SetLength(Fresh.Found, N);
  Count := 0;

  for I := 0 to N - 1 do
  begin
    Mine := SegsInPlane(Segs, Keys[I], Tol, Sig);
    Fresh.Keys[I] := Keys[I];
    Fresh.Sig[I] := Sig;

    Hit := False;
    for J := 0 to High(Cache.Keys) do
      if (Cache.Sig[J] = Sig) and SamePlane(Cache.Keys[J], Keys[I], Tol) then
      begin
        Fresh.Found[I] := Cache.Found[J];
        Hit := True;
        Break;
      end;
    if not Hit then
      Fresh.Found[I] := BuildRegions(Mine, Tol);

    Inc(Count, Length(Fresh.Found[I]));
  end;

  Cache := Fresh;
  SetLength(Result, Count);
  Count := 0;
  for I := 0 to N - 1 do
    for J := 0 to High(Fresh.Found[I]) do
    begin
      Result[Count] := Fresh.Found[I][J];
      Inc(Count);
    end;
end;

function BuildRegions(const Segs: TSegArray; Tol: Double): TRegionArray;
var
  Cut: TSegArray;
  Verts: TP3Array;
  NV: Integer;
  Bucket: array of TIntArray;
  EBucket: array of TIntArray;
  Parent: TIntArray;
  HashMask: Integer;

  EA, EB: TIntArray;          { each undirected edge, as two vertex numbers }
  NE: Integer;
  Planes: array of TPlaneKey;
  NP: Integer;
  Loops: TLoopArray;
  LoopPlane: TIntArray;
  NLoop: Integer;

  { Which bucket a grid cell falls in.  Any mixing will do - the cells are one
    tolerance across, so a bucket holds one or two vertices. }
  function CellHash(CX, CY, CZ: Int64): Integer;
  begin
    Result := Integer((CX * 73856093) xor (CY * 19349663) xor (CZ * 83492791))
      and HashMask;
  end;

  { Has this pair of vertices already been joined?  Records it if not. }
  function EdgeSeen(A, B: Integer): Boolean;
  var
    H, K, T: Integer;
  begin
    if A > B then begin T := A; A := B; B := T; end;
    H := ((A * 92837111) xor (B * 689287499)) and HashMask;
    if H < 0 then H := -H and HashMask;
    for K := 0 to High(EBucket[H]) do
      if (EA[EBucket[H][K]] = A) and (EB[EBucket[H][K]] = B) then Exit(True);
    SetLength(EBucket[H], Length(EBucket[H]) + 1);
    EBucket[H][High(EBucket[H])] := NE;
    Result := False;
  end;

  { Which piece of the drawing a vertex belongs to.  Two loops can only sit
    one inside the other if they are not joined up to each other, so this is
    what stops every loop being measured against every other. }
  function Root(V: Integer): Integer;
  begin
    while Parent[V] <> V do
    begin
      Parent[V] := Parent[Parent[V]];
      V := Parent[V];
    end;
    Result := V;
  end;

  { Welding by walking every vertex found so far is what made a big drawing
    crawl - a grid of forty lines welds three thousand ends against sixteen
    hundred vertices, five million distance sums.  The points are dropped into
    a grid of cells one tolerance across instead, so anything close enough to
    weld is in this cell or one of the twenty-six around it. }
  function VertexOf(const P: TP3): Integer;
  var
    CX, CY, CZ, DX, DY, DZ: Int64;
    H, I, K: Integer;
  begin
    CX := Floor(P.X / Tol);
    CY := Floor(P.Y / Tol);
    CZ := Floor(P.Z / Tol);
    for DX := -1 to 1 do
      for DY := -1 to 1 do
        for DZ := -1 to 1 do
        begin
          H := CellHash(CX + DX, CY + DY, CZ + DZ);
          for K := 0 to High(Bucket[H]) do
          begin
            I := Bucket[H][K];
            if Dist(Verts[I], P) < Tol then Exit(I);
          end;
        end;
    if NV >= Length(Verts) then SetLength(Verts, Max(16, NV * 2));
    Verts[NV] := P;
    Result := NV;
    H := CellHash(CX, CY, CZ);
    SetLength(Bucket[H], Length(Bucket[H]) + 1);
    Bucket[H][High(Bucket[H])] := NV;
    Inc(NV);
  end;

  procedure NotePlane(const N, Through: TP3);
  var
    K: TPlaneKey;
    I: Integer;
  begin
    if Len3(N) < 1E-9 then Exit;
    K := MakePlane(N, Through);
    for I := 0 to NP - 1 do
      if SamePlane(Planes[I], K, Tol) then Exit;
    if NP >= Length(Planes) then SetLength(Planes, Max(8, NP * 2));
    Planes[NP] := K;
    Inc(NP);
  end;

  function EdgeInPlane(E: Integer; const K: TPlaneKey): Boolean;
  begin
    Result := (Abs(Dot3(K.N, Verts[EA[E]]) - K.D) < Tol) and
              (Abs(Dot3(K.N, Verts[EB[E]]) - K.D) < Tol);
  end;

  { Walk one plane's sub-graph and collect every cycle that goes round the
    right way. }
  procedure WalkPlane(PI: Integer);
  var
    K: TPlaneKey;
    U, W: TP3;
    Darts: array of TDart;
    ND, I, J, E, D, T, Start, Cur, Best, Steps: Integer;
    Out_: array of TIntArray;      { darts leaving each vertex, by angle }
    Loop: TP3Array;
    NL: Integer;
    Ang: Double;
    Tmp: Integer;
  begin
    K := Planes[PI];
    PlaneBasis(K.N, U, W);

    ND := 0;
    SetLength(Darts, NE * 2);
    for E := 0 to NE - 1 do
    begin
      if not EdgeInPlane(E, K) then Continue;
      Darts[ND].V0 := EA[E];
      Darts[ND].V1 := EB[E];
      Darts[ND].Twin := ND + 1;
      Darts[ND + 1].V0 := EB[E];
      Darts[ND + 1].V1 := EA[E];
      Darts[ND + 1].Twin := ND;
      Inc(ND, 2);
    end;
    SetLength(Darts, ND);
    if ND < 6 then Exit;             { fewer than three edges encloses nothing }

    for I := 0 to ND - 1 do
    begin
      Darts[I].Used := False;
      Darts[I].Ang := ArcTan2(
        Dot3(Sub3(Verts[Darts[I].V1], Verts[Darts[I].V0]), W),
        Dot3(Sub3(Verts[Darts[I].V1], Verts[Darts[I].V0]), U));
    end;

    { the darts leaving each vertex, sorted anticlockwise }
    SetLength(Out_, NV);
    for I := 0 to NV - 1 do SetLength(Out_[I], 0);
    for I := 0 to ND - 1 do
    begin
      J := Darts[I].V0;
      SetLength(Out_[J], Length(Out_[J]) + 1);
      Out_[J][High(Out_[J])] := I;
    end;
    for I := 0 to NV - 1 do
      for J := 1 to High(Out_[I]) do
      begin
        Tmp := Out_[I][J];
        Ang := Darts[Tmp].Ang;
        T := J - 1;
        while (T >= 0) and (Darts[Out_[I][T]].Ang > Ang) do
        begin
          Out_[I][T + 1] := Out_[I][T];
          Dec(T);
        end;
        Out_[I][T + 1] := Tmp;
      end;

    for Start := 0 to ND - 1 do
    begin
      if Darts[Start].Used then Continue;
      Cur := Start;
      NL := 0;
      SetLength(Loop, 8);
      Steps := 0;
      repeat
        Darts[Cur].Used := True;
        if NL >= Length(Loop) then SetLength(Loop, NL * 2);
        Loop[NL] := Verts[Darts[Cur].V0];
        Inc(NL);

        { arrived along Cur; leave by the dart immediately clockwise of the
          way back }
        D := Darts[Cur].Twin;
        J := Darts[D].V0;
        Best := -1;
        for I := 0 to High(Out_[J]) do
          if Out_[J][I] = D then
          begin
            if Length(Out_[J]) = 1 then Best := D
            else if I = 0 then Best := Out_[J][High(Out_[J])]
            else Best := Out_[J][I - 1];
            Break;
          end;
        if Best < 0 then Break;
        Cur := Best;
        Inc(Steps);
      until (Cur = Start) or (Steps > ND + 2);

      if (Cur <> Start) or (NL < 3) then Continue;
      SetLength(Loop, NL);
      { the one wound the other way is the space around the drawing }
      if LoopArea(Loop, K.N) <= Tol then Continue;
      if NLoop >= Length(Loops) then
      begin
        SetLength(Loops, Max(8, NLoop * 2));
        SetLength(LoopPlane, Length(Loops));
      end;
      Loops[NLoop] := Copy(Loop, 0, NL);
      LoopPlane[NLoop] := PI;
      Inc(NLoop);
    end;
  end;

var
  I, J, K, E, Count: Integer;
  Dir1, Dir2: TP3;
  Mid: TP3;
  AtVert: array of TIntArray;
  LoopArea_: array of Double;
  LoopPart: TIntArray;
begin
  Result := nil;
  Cut := SplitAtCrossings(Segs, Tol);
  if Length(Cut) < 3 then Exit;

  { 2. weld the ends together }
  NV := 0;
  SetLength(Verts, 32);
  HashMask := 1;
  while HashMask < Length(Cut) * 4 do HashMask := HashMask * 2;
  Dec(HashMask);
  SetLength(Bucket, HashMask + 1);
  SetLength(EBucket, HashMask + 1);
  NE := 0;
  SetLength(EA, Length(Cut));
  SetLength(EB, Length(Cut));
  SetLength(Parent, Length(Cut) * 2 + 4);
  for I := 0 to High(Parent) do Parent[I] := I;
  for I := 0 to High(Cut) do
  begin
    J := VertexOf(Cut[I].A);
    E := VertexOf(Cut[I].B);
    if J = E then Continue;
    { The same edge twice adds nothing.  Asked through a hash: looking back
      over every edge so far turned a grid of forty lines into ten million
      comparisons on its own. }
    if EdgeSeen(J, E) then Continue;
    EA[NE] := J;
    EB[NE] := E;
    Inc(NE);
    Parent[Root(J)] := Root(E);
  end;
  SetLength(Verts, NV);
  if NE < 3 then Exit;

  { 3. every plane two joined edges can lie in.  Asked through the vertices:
       only edges meeting at one can define a plane together, and looking for
       those pairs by trying every pair of edges was the other half of why a
       big drawing crawled. }
  SetLength(AtVert, NV);
  for I := 0 to NV - 1 do SetLength(AtVert[I], 0);
  for I := 0 to NE - 1 do
  begin
    SetLength(AtVert[EA[I]], Length(AtVert[EA[I]]) + 1);
    AtVert[EA[I]][High(AtVert[EA[I]])] := I;
    SetLength(AtVert[EB[I]], Length(AtVert[EB[I]]) + 1);
    AtVert[EB[I]][High(AtVert[EB[I]])] := I;
  end;
  NP := 0;
  SetLength(Planes, 8);
  for K := 0 to NV - 1 do
    for I := 0 to High(AtVert[K]) - 1 do
      for J := I + 1 to High(AtVert[K]) do
      begin
        Dir1 := Sub3(Verts[EB[AtVert[K][I]]], Verts[EA[AtVert[K][I]]]);
        Dir2 := Sub3(Verts[EB[AtVert[K][J]]], Verts[EA[AtVert[K][J]]]);
        NotePlane(Cross3(Dir1, Dir2), Verts[K]);
      end;

  { 4. walk each plane }
  NLoop := 0;
  SetLength(Loops, 16);
  SetLength(LoopPlane, 16);
  for I := 0 to NP - 1 do
    WalkPlane(I);
  SetLength(Loops, NLoop);
  SetLength(LoopPlane, NLoop);
  if NLoop = 0 then Exit;

  { 5. a loop sitting inside another is a hole in it as well as a region of
       its own - which is what lets you draw a square inside a square and
       push either one.

       Only loops belonging to different pieces of the drawing can nest: if
       they are joined up to each other then the cycle walk has already put
       the boundary between them.  On a grid, where everything is one piece,
       that means no loop is measured against any other at all. }
  SetLength(LoopArea_, NLoop);
  SetLength(LoopPart, NLoop);
  for I := 0 to NLoop - 1 do
  begin
    LoopArea_[I] := Abs(LoopArea(Loops[I], Planes[LoopPlane[I]].N));
    LoopPart[I] := Root(VertexOf(Loops[I][0]));
  end;

  Count := 0;
  SetLength(Result, NLoop);
  for I := 0 to NLoop - 1 do
  begin
    Result[Count].Normal := Planes[LoopPlane[I]].N;
    Result[Count].Outer := Loops[I];
    SetLength(Result[Count].Holes, 0);
    for J := 0 to NLoop - 1 do
    begin
      if J = I then Continue;
      if LoopPart[J] = LoopPart[I] then Continue;
      if LoopPlane[J] <> LoopPlane[I] then Continue;
      if LoopArea_[J] >= LoopArea_[I] then Continue;
      Mid := Loops[J][0];
      for E := 1 to High(Loops[J]) do Mid := Add3(Mid, Loops[J][E]);
      Mid := Mul3(Mid, 1 / Length(Loops[J]));
      if not PointInLoop(Mid, Loops[I], Planes[LoopPlane[I]].N, Tol) then
        Continue;
      SetLength(Result[Count].Holes, Length(Result[Count].Holes) + 1);
      Result[Count].Holes[High(Result[Count].Holes)] := Loops[J];
    end;
    Inc(Count);
  end;
  SetLength(Result, Count);
end;

end.
