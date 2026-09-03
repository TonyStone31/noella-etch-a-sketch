{ The planar region engine, on its own.

  Every case here is a drawing someone would actually make, reduced to the
  segments it is made of.  If one of these fails, a real drawing is wrong. }
program regiontest;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Math, Types, uWork, uRegion;

var
  Fails: Integer = 0;
  Checks: Integer = 0;
  Section: string = '';

procedure Say(const S: string);
begin
  Section := S;
  WriteLn(S);
end;

procedure Ok(Cond: Boolean; const What: string);
begin
  Inc(Checks);
  if Cond then WriteLn('  ok    ', What)
  else
  begin
    WriteLn('  FAIL  ', What);
    Inc(Fails);
  end;
end;

procedure EqI(Got, Want: Integer; const What: string);
begin
  Inc(Checks);
  if Got = Want then WriteLn('  ok    ', What, ' = ', Got)
  else
  begin
    WriteLn('  FAIL  ', What, ' = ', Got, ', wanted ', Want);
    Inc(Fails);
  end;
end;

procedure EqF(Got, Want: Double; const What: string; Tol: Double = 1E-6);
begin
  Inc(Checks);
  if Abs(Got - Want) <= Tol then WriteLn('  ok    ', What, ' = ', Got:0:4)
  else
  begin
    WriteLn('  FAIL  ', What, ' = ', Got:0:4, ', wanted ', Want:0:4);
    Inc(Fails);
  end;
end;

{ ------------------------------------------------------------- building - }

var
  Segs: TSegArray;
  NSeg: Integer;

procedure Clear;
begin
  NSeg := 0;
  SetLength(Segs, 32);
end;

procedure Seg(const A, B: TP3);
begin
  if NSeg >= Length(Segs) then SetLength(Segs, NSeg * 2);
  Segs[NSeg].A := A;
  Segs[NSeg].B := B;
  Inc(NSeg);
end;

procedure Box(X0, Y0, X1, Y1, Z: Double);
begin
  Seg(P3(X0, Y0, Z), P3(X1, Y0, Z));
  Seg(P3(X1, Y0, Z), P3(X1, Y1, Z));
  Seg(P3(X1, Y1, Z), P3(X0, Y1, Z));
  Seg(P3(X0, Y1, Z), P3(X0, Y0, Z));
end;

function Built: TRegionArray;
begin
  SetLength(Segs, NSeg);
  Result := BuildRegions(Segs);
end;

{ total area of everything found, holes taken off }
function NetArea(const R: TRegionArray): Double;
var
  I, J: Integer;
begin
  Result := 0;
  for I := 0 to High(R) do
  begin
    Result := Result + Abs(LoopArea(R[I].Outer, R[I].Normal));
    for J := 0 to High(R[I].Holes) do
      Result := Result - Abs(LoopArea(R[I].Holes[J], R[I].Normal));
  end;
end;

function AreaOfSmallest(const R: TRegionArray): Double;
var
  I: Integer;
  A: Double;
begin
  Result := 1E30;
  for I := 0 to High(R) do
  begin
    A := Abs(LoopArea(R[I].Outer, R[I].Normal));
    if A < Result then Result := A;
  end;
  if Result > 1E29 then Result := 0;
end;

function AreaOfLargest(const R: TRegionArray): Double;
var
  I: Integer;
  A: Double;
begin
  Result := 0;
  for I := 0 to High(R) do
  begin
    A := Abs(LoopArea(R[I].Outer, R[I].Normal));
    if A > Result then Result := A;
  end;
end;

{ ---------------------------------------------------------------- cases - }

procedure TestSquare;
var
  R: TRegionArray;
begin
  Say('a plain square');
  Clear;
  Box(0, 0, 10, 6, 0);
  R := Built;
  EqI(Length(R), 1, 'one region');
  EqF(Abs(LoopArea(R[0].Outer, R[0].Normal)), 60, 'of the right area');
  EqI(Length(R[0].Outer), 4, 'with four corners');
  EqI(Length(R[0].Holes), 0, 'and no holes');
  EqF(Abs(R[0].Normal.Z), 1, 'lying flat');
end;

procedure TestOpenShape;
var
  R: TRegionArray;
begin
  Say('three sides of a square enclose nothing');
  Clear;
  Seg(P3(0, 0, 0), P3(10, 0, 0));
  Seg(P3(10, 0, 0), P3(10, 6, 0));
  Seg(P3(10, 6, 0), P3(0, 6, 0));
  R := Built;
  EqI(Length(R), 0, 'no region');
end;

procedure TestCutInHalf;
var
  R: TRegionArray;
begin
  Say('a square cut down the middle');
  Clear;
  Box(0, 0, 10, 6, 0);
  Seg(P3(5, 0, 0), P3(5, 6, 0));
  R := Built;
  EqI(Length(R), 2, 'two regions');
  EqF(NetArea(R), 60, 'that still add up');
  EqF(AreaOfSmallest(R), 30, 'and each is half');
end;

procedure TestCutStoppingInside;
var
  R: TRegionArray;
begin
  Say('a cut that stops inside divides nothing');
  Clear;
  Box(0, 0, 10, 6, 0);
  Seg(P3(5, 0, 0), P3(5, 3, 0));      { only half way across }
  R := Built;
  EqI(Length(R), 1, 'still one region');
  EqF(Abs(LoopArea(R[0].Outer, R[0].Normal)), 60, 'of the whole area');
end;

procedure TestTicTacToe;
var
  R: TRegionArray;
begin
  Say('a square divided into nine');
  Clear;
  Box(0, 0, 9, 9, 0);
  Seg(P3(3, 0, 0), P3(3, 9, 0));
  Seg(P3(6, 0, 0), P3(6, 9, 0));
  Seg(P3(0, 3, 0), P3(9, 3, 0));
  Seg(P3(0, 6, 0), P3(9, 6, 0));
  R := Built;
  EqI(Length(R), 9, 'nine regions');
  EqF(NetArea(R), 81, 'adding to the whole');
  EqF(AreaOfSmallest(R), 9, 'each one a ninth');
  EqF(AreaOfLargest(R), 9, 'and none of them bigger');
end;

procedure TestTJunctions;
var
  R: TRegionArray;
begin
  Say('lines drawn from the middle of a side');
  Clear;
  Box(0, 0, 10, 10, 0);
  { drawn midpoint to midpoint, so every meeting is a T on the outside }
  Seg(P3(5, 0, 0), P3(5, 10, 0));
  Seg(P3(0, 5, 0), P3(10, 5, 0));
  R := Built;
  EqI(Length(R), 4, 'four quarters');
  EqF(NetArea(R), 100, 'adding to the whole');
  EqF(AreaOfSmallest(R), 25, 'each a quarter');
end;

procedure TestSquareInSquare;
var
  R: TRegionArray;
  I, Holed: Integer;
begin
  Say('a square drawn inside a square');
  Clear;
  Box(0, 0, 10, 10, 0);
  Box(3, 3, 7, 7, 0);
  R := Built;
  EqI(Length(R), 2, 'two regions - the inner one and the ring');
  EqF(AreaOfSmallest(R), 16, 'the inner square');
  EqF(AreaOfLargest(R), 100, 'and the outer one');
  Holed := 0;
  for I := 0 to High(R) do
    if Length(R[I].Holes) = 1 then Inc(Holed);
  EqI(Holed, 1, 'exactly one of them has a hole in it');
  EqF(NetArea(R), 100, 'and the ring plus the middle is the whole square');
end;

procedure TestUpright;
var
  R: TRegionArray;
begin
  Say('a square standing up in the XZ plane');
  Clear;
  Seg(P3(0, 2, 0), P3(8, 2, 0));
  Seg(P3(8, 2, 0), P3(8, 2, 5));
  Seg(P3(8, 2, 5), P3(0, 2, 5));
  Seg(P3(0, 2, 5), P3(0, 2, 0));
  R := Built;
  EqI(Length(R), 1, 'one region');
  EqF(Abs(LoopArea(R[0].Outer, R[0].Normal)), 40, 'of the right area');
  EqF(Abs(R[0].Normal.Y), 1, 'facing along Y');
end;

procedure TestTilted;
var
  R: TRegionArray;
begin
  Say('a square on a slope');
  Clear;
  { a 3-4-5 slope, so the area is exactly 50 }
  Seg(P3(0, 0, 0), P3(10, 0, 0));
  Seg(P3(10, 0, 0), P3(10, 4, 3));
  Seg(P3(10, 4, 3), P3(0, 4, 3));
  Seg(P3(0, 4, 3), P3(0, 0, 0));
  R := Built;
  EqI(Length(R), 1, 'one region');
  EqF(Abs(LoopArea(R[0].Outer, R[0].Normal)), 50, 'of the right area');
end;

procedure TestTwoPlanes;
var
  R: TRegionArray;
begin
  Say('two squares meeting along an edge, like a wall and a floor');
  Clear;
  Box(0, 0, 6, 6, 0);
  Seg(P3(0, 0, 0), P3(0, 0, 4));
  Seg(P3(0, 0, 4), P3(6, 0, 4));
  Seg(P3(6, 0, 4), P3(6, 0, 0));
  R := Built;
  EqI(Length(R), 2, 'one region in each plane');
  EqF(NetArea(R), 60, 'thirty-six on the floor and twenty-four up the wall');
end;

procedure TestCrossingLines;
var
  R: TRegionArray;
begin
  Say('two lines crossing in mid air enclose nothing');
  Clear;
  Seg(P3(0, 0, 0), P3(10, 10, 0));
  Seg(P3(0, 10, 0), P3(10, 0, 0));
  R := Built;
  EqI(Length(R), 0, 'no region');
end;

procedure TestDiagonalCut;
var
  R: TRegionArray;
begin
  Say('a square cut corner to corner');
  Clear;
  Box(0, 0, 8, 8, 0);
  Seg(P3(0, 0, 0), P3(8, 8, 0));
  R := Built;
  EqI(Length(R), 2, 'two triangles');
  EqF(AreaOfSmallest(R), 32, 'each half the square');
  EqF(NetArea(R), 64, 'adding up');
end;

procedure TestCutMadeOfTwoLines;
var
  R: TRegionArray;
begin
  Say('a cut assembled from two separate lines');
  Clear;
  Box(0, 0, 10, 6, 0);
  { the divider drawn as two strokes that meet in the middle }
  Seg(P3(5, 0, 0), P3(5, 3, 0));
  Seg(P3(5, 3, 0), P3(5, 6, 0));
  R := Built;
  EqI(Length(R), 2, 'still two regions');
  EqF(NetArea(R), 60, 'adding up');
end;

procedure TestDuplicateEdge;
var
  R: TRegionArray;
begin
  Say('the same edge drawn twice');
  Clear;
  Box(0, 0, 10, 6, 0);
  Seg(P3(0, 0, 0), P3(10, 0, 0));     { again }
  R := Built;
  EqI(Length(R), 1, 'one region, not two');
  EqF(Abs(LoopArea(R[0].Outer, R[0].Normal)), 60, 'of the right area');
end;

procedure TestOverlappingEdge;
var
  R: TRegionArray;
begin
  Say('an edge drawn over part of another');
  Clear;
  Box(0, 0, 10, 6, 0);
  Seg(P3(2, 0, 0), P3(8, 0, 0));      { lies along the bottom }
  R := Built;
  Ok(Length(R) >= 1, 'at least one region');
  EqF(AreaOfLargest(R), 60, 'and the shape is the right size');
end;

procedure TestSplitCounts;
var
  Cut: TSegArray;
begin
  Say('cutting segments where they meet');
  Clear;
  Seg(P3(0, 0, 0), P3(10, 0, 0));
  Seg(P3(5, -5, 0), P3(5, 5, 0));
  SetLength(Segs, NSeg);
  Cut := SplitAtCrossings(Segs);
  EqI(Length(Cut), 4, 'a proper crossing makes four pieces');

  Clear;
  Seg(P3(0, 0, 0), P3(10, 0, 0));
  Seg(P3(5, 0, 0), P3(5, 5, 0));
  SetLength(Segs, NSeg);
  Cut := SplitAtCrossings(Segs);
  EqI(Length(Cut), 3, 'a T makes three');

  Clear;
  Seg(P3(0, 0, 0), P3(10, 0, 0));
  Seg(P3(10, 0, 0), P3(10, 5, 0));
  SetLength(Segs, NSeg);
  Cut := SplitAtCrossings(Segs);
  EqI(Length(Cut), 2, 'meeting end to end cuts nothing');

  Clear;
  Seg(P3(0, 0, 0), P3(10, 0, 0));
  Seg(P3(0, 1, 0), P3(10, 1, 0));
  SetLength(Segs, NSeg);
  Cut := SplitAtCrossings(Segs);
  EqI(Length(Cut), 2, 'parallel and apart cuts nothing');

  Clear;
  Seg(P3(0, 0, 0), P3(10, 0, 0));
  Seg(P3(3, 0, 0), P3(7, 0, 0));
  SetLength(Segs, NSeg);
  Cut := SplitAtCrossings(Segs);
  EqI(Length(Cut), 4, 'one lying along another cuts it in three');
end;

procedure TestRing;
var
  R: TRegionArray;
  I, J, N: Integer;
  A: Double;
begin
  Say('a circle approximated by a ring of segments');
  Clear;
  N := 24;
  for I := 0 to N - 1 do
  begin
    J := (I + 1) mod N;
    Seg(P3(5 * Cos(2 * Pi * I / N), 5 * Sin(2 * Pi * I / N), 0),
        P3(5 * Cos(2 * Pi * J / N), 5 * Sin(2 * Pi * J / N), 0));
  end;
  R := Built;
  EqI(Length(R), 1, 'one region');
  A := Abs(LoopArea(R[0].Outer, R[0].Normal));
  { a 24-gon in a circle of radius 5 }
  EqF(A, 0.5 * N * 25 * Sin(2 * Pi / N), 'of the polygon''s area', 1E-6);
  EqI(Length(R[0].Outer), N, 'with a corner per segment');
end;

procedure TestToleranceWeld;
var
  R: TRegionArray;
begin
  Say('corners that do not quite meet still close the shape');
  Clear;
  Seg(P3(0, 0, 0), P3(10, 0, 0));
  Seg(P3(10 + 1E-9, 1E-9, 0), P3(10, 6, 0));
  Seg(P3(10, 6, 0), P3(0, 6, 0));
  Seg(P3(-1E-9, 6, 0), P3(0, 0, 0));
  R := Built;
  EqI(Length(R), 1, 'one region');
  EqF(Abs(LoopArea(R[0].Outer, R[0].Normal)), 60, 'of the right area', 1E-4);
end;

procedure TestLShape;
var
  R: TRegionArray;
begin
  Say('an L, which is concave');
  Clear;
  Seg(P3(0, 0, 0), P3(10, 0, 0));
  Seg(P3(10, 0, 0), P3(10, 4, 0));
  Seg(P3(10, 4, 0), P3(4, 4, 0));
  Seg(P3(4, 4, 0), P3(4, 10, 0));
  Seg(P3(4, 10, 0), P3(0, 10, 0));
  Seg(P3(0, 10, 0), P3(0, 0, 0));
  R := Built;
  EqI(Length(R), 1, 'one region');
  EqF(Abs(LoopArea(R[0].Outer, R[0].Normal)), 40 + 24, 'of the L''s area');
  EqI(Length(R[0].Outer), 6, 'with six corners');
end;

procedure TestSideBySide;
var
  R: TRegionArray;
begin
  Say('two squares sharing a whole edge');
  Clear;
  Box(0, 0, 5, 5, 0);
  Box(5, 0, 10, 5, 0);
  R := Built;
  EqI(Length(R), 2, 'two regions');
  EqF(NetArea(R), 50, 'adding up');
  EqF(AreaOfSmallest(R), 25, 'each twenty-five');
  EqF(AreaOfLargest(R), 25, 'and neither one bigger');
end;

procedure TestInnerTouchingOuter;
var
  R: TRegionArray;
begin
  Say('an inner square sharing one edge with the outer');
  Clear;
  Box(0, 0, 10, 10, 0);
  Box(0, 3, 4, 7, 0);      { its left edge lies on the outer left edge }
  R := Built;
  EqI(Length(R), 2, 'two regions');
  EqF(AreaOfSmallest(R), 16, 'the inner one');
  EqF(NetArea(R), 100, 'and together they are the whole square');
end;

procedure TestGrid6x6;
var
  R: TRegionArray;
  I: Integer;
begin
  Say('the standing test: a square filled in to a six by six grid');
  Clear;
  Box(0, 0, 12, 12, 0);
  for I := 1 to 5 do
  begin
    Seg(P3(I * 2, 0, 0), P3(I * 2, 12, 0));
    Seg(P3(0, I * 2, 0), P3(12, I * 2, 0));
  end;
  R := Built;
  EqI(Length(R), 36, 'thirty-six cells');
  EqF(NetArea(R), 144, 'adding to the whole');
  EqF(AreaOfSmallest(R), 4, 'each two by two');
  EqF(AreaOfLargest(R), 4, 'and none of them bigger');
end;

procedure TestManyCuts;
var
  R: TRegionArray;
  I: Integer;
begin
  Say('several cuts crossing each other');
  Clear;
  Box(0, 0, 10, 10, 0);
  Seg(P3(0, 0, 0), P3(10, 10, 0));
  Seg(P3(0, 10, 0), P3(10, 0, 0));
  Seg(P3(5, 0, 0), P3(5, 10, 0));
  R := Built;
  { the two diagonals and the middle line cut the square into six }
  EqI(Length(R), 6, 'six pieces');
  EqF(NetArea(R), 100, 'adding to the whole');
  for I := 0 to High(R) do
    if Abs(LoopArea(R[I].Outer, R[I].Normal)) < 1E-9 then
      Ok(False, 'no piece has zero area');
  Ok(True, 'and none of them is degenerate');
end;

procedure TestSize;
var
  R: TRegionArray;
  I, N: Integer;
  T0: TDateTime;
  Ms: Double;
begin
  Say('a big grid, to see what it costs');
  N := 12;
  Clear;
  Box(0, 0, N * 2, N * 2, 0);
  for I := 1 to N - 1 do
  begin
    Seg(P3(I * 2, 0, 0), P3(I * 2, N * 2, 0));
    Seg(P3(0, I * 2, 0), P3(N * 2, I * 2, 0));
  end;
  T0 := Now;
  R := Built;
  Ms := (Now - T0) * 24 * 60 * 60 * 1000;
  EqI(Length(R), N * N, 'every cell found');
  EqF(NetArea(R), N * N * 4, 'adding to the whole');
  WriteLn(Format('        (%d segments in, %d cells out, %.0f ms)',
    [NSeg, Length(R), Ms]));
  Ok(Ms < 5000, 'and it did not take all day');
end;

begin
  WriteLn('Heckers Sketch - planar region engine');
  WriteLn;
  TestSplitCounts;      WriteLn;
  TestSquare;           WriteLn;
  TestOpenShape;        WriteLn;
  TestCutInHalf;        WriteLn;
  TestCutStoppingInside; WriteLn;
  TestTicTacToe;        WriteLn;
  TestTJunctions;       WriteLn;
  TestSquareInSquare;   WriteLn;
  TestUpright;          WriteLn;
  TestTilted;           WriteLn;
  TestTwoPlanes;        WriteLn;
  TestCrossingLines;    WriteLn;
  TestDiagonalCut;      WriteLn;
  TestCutMadeOfTwoLines; WriteLn;
  TestDuplicateEdge;    WriteLn;
  TestOverlappingEdge;  WriteLn;
  TestRing;             WriteLn;
  TestToleranceWeld;    WriteLn;
  TestLShape;           WriteLn;
  TestSideBySide;       WriteLn;
  TestInnerTouchingOuter; WriteLn;
  TestManyCuts;         WriteLn;
  TestGrid6x6;          WriteLn;
  TestSize;             WriteLn;
  WriteLn(Format('%d checks, %d failed', [Checks, Fails]));
  if Fails > 0 then Halt(1);
end.
