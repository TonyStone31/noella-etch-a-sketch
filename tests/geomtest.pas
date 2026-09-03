{ Headless checks on the document model.

  Everything here runs without a window, so a regression shows up as a failed
  line rather than as something looking wrong three screenshots later.  Build
  and run it with tests/run.sh. }
program geomtest;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Math, Types, uWork;

var
  Fails: Integer = 0;
  Checks: Integer = 0;

procedure Ok(Cond: Boolean; const What: string);
begin
  Inc(Checks);
  if Cond then
    WriteLn('  ok    ', What)
  else
  begin
    WriteLn('  FAIL  ', What);
    Inc(Fails);
  end;
end;

procedure EqI(Got, Want: Integer; const What: string);
begin
  Inc(Checks);
  if Got = Want then
    WriteLn('  ok    ', What, ' = ', Got)
  else
  begin
    WriteLn('  FAIL  ', What, ' = ', Got, ', wanted ', Want);
    Inc(Fails);
  end;
end;

procedure EqF(Got, Want: Double; const What: string; Tol: Double = 1E-6);
begin
  Inc(Checks);
  if Abs(Got - Want) <= Tol then
    WriteLn('  ok    ', What, ' = ', Got:0:6)
  else
  begin
    WriteLn('  FAIL  ', What, ' = ', Got:0:6, ', wanted ', Want:0:6);
    Inc(Fails);
  end;
end;

function Rect4(X0, Y0, X1, Y1, Z: Double): TP3Array;
begin
  SetLength(Result, 4);
  Result[0] := P3(X0, Y0, Z);
  Result[1] := P3(X1, Y0, Z);
  Result[2] := P3(X1, Y1, Z);
  Result[3] := P3(X0, Y1, Z);
end;

{ A rectangle drawn the way the Rect tool draws one: four lines and a face. }
procedure MakeRect(D: TWorkDoc; X0, Y0, X1, Y1: Double);
var
  P: TP3Array;
  I: Integer;
begin
  P := Rect4(X0, Y0, X1, Y1, 0);
  for I := 0 to 3 do
    D.AddLine(P[I], P[(I + 1) mod 4], 0, 2, False);
  D.AddFace(P, 0);
end;

function CountKind(D: TWorkDoc; K: TEntKind): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to D.Live - 1 do
    if D[I].Kind = K then Inc(Result);
end;

{ ---------------------------------------------------------------- lengths - }
procedure TestParsing;
var
  V, X, Y, Z: Double;
begin
  WriteLn('parsing');
  Ok(ParseLen('12''6"', usImperial, V) and (Abs(V - 12.5) < 1E-9), '12''6" is 12.5 ft');
  Ok(ParseLen('6"', usImperial, V) and (Abs(V - 0.5) < 1E-9), '6" is half a foot');
  Ok(ParseLen('150', usImperial, V), 'a bare number parses');
  Ok(not ParseLen('banana', usImperial, V), 'nonsense does not');

  EqI(ParseTriple('<3'', 4'', 5''>', usImperial, X, Y, Z), 3, 'relative triple fields');
  EqF(X, 3, 'relative x');
  EqF(Y, 4, 'relative y');
  EqF(Z, 5, 'relative z');

  EqI(ParseTriple('[1'',2'',3'']', usImperial, X, Y, Z), 3, 'absolute triple fields');
  EqF(X, 1, 'absolute x');

  { a missing closing bracket is what you get mid-typing, and should still read }
  EqI(ParseTriple('<0,-10'',0', usImperial, X, Y, Z), 3, 'unclosed triple still reads');
  EqF(Y, -10, 'unclosed triple y');

  { an empty field leaves that axis alone }
  EqI(ParseTriple('<,,5''>', usImperial, X, Y, Z), 3, 'empty fields counted');
  EqF(X, 0, 'empty field x stays put');
  EqF(Z, 5, 'third field read');

  EqI(ParseTriple('<3'', banana, 5''>', usImperial, X, Y, Z), 0, 'a bad field spoils it');
end;

{ ------------------------------------------------------------ save/reload - }
procedure TestSaveLoad;
var
  A, B: TWorkDoc;
  L: TStringList;
  Idx: Integer;
begin
  WriteLn('save and reload');
  A := TWorkDoc.Create;
  B := TWorkDoc.Create;
  L := TStringList.Create;
  try
    MakeRect(A, 0, 0, 10, 6);
    A.AddArc(P3(20, 0, 0), 3, 0, 2 * Pi, plXY, 0, 2);
    A.AddDim(P3(0, 0, 0), P3(10, 0, 0), 0, P3(0, -2, 0));
    A.AddText(P3(1, 1, 0), 'a note with spaces', 0);
    Ok(A.PushPull(4, 4), 'the face pushed');   // entity 4 is the face

    A.SaveTo(L);
    Idx := 0;
    B.LoadFrom(L, Idx);

    EqI(B.Live, A.Live, 'entity count survives a round trip');
    EqI(CountKind(B, ekFace), CountKind(A, ekFace), 'faces survive');
    EqI(CountKind(B, ekLine), CountKind(A, ekLine), 'lines survive');
    EqI(CountKind(B, ekArc), CountKind(A, ekArc), 'arcs survive');
    EqI(CountKind(B, ekDim), CountKind(A, ekDim), 'dimensions survive');
    EqI(CountKind(B, ekText), CountKind(A, ekText), 'notes survive');
    Ok(CountKind(B, ekFace) > 0, 'a reloaded drawing actually has faces');
  finally
    L.Free;
    B.Free;
    A.Free;
  end;
end;

{ --------------------------------------------------------------- copying - }
procedure TestDuplicate;
var
  D: TWorkDoc;
  Sel: array of Integer;
  Orig: TP3Array;
  I, K, Base, G0, G1, Copy0, Moved: Integer;
begin
  WriteLn('copying a solid');
  D := TWorkDoc.Create;
  try
    MakeRect(D, 0, 0, 10, 6);
    Ok(D.PushPull(4, 4), 'pushed into a box');
    Base := D.Live;

    SetLength(Sel, Base);
    for I := 0 to Base - 1 do Sel[I] := I;
    D.Duplicate(Sel, P3(30, 0, 0));
    EqI(D.Live, Base * 2, 'the copy doubled the drawing');

    { whatever group the original solid ended up in, the copy must not share it }
    G0 := 0;
    G1 := 0;
    for I := 0 to Base - 1 do
      if D[I].Grp <> 0 then G0 := D[I].Grp;
    for I := Base to D.Live - 1 do
      if D[I].Grp <> 0 then G1 := D[I].Grp;
    Ok(G0 <> 0, 'the original solid has a group');
    Ok(G1 <> 0, 'the copy has a group');
    Ok(G0 <> G1, 'the copy got its own group, so push/pull can tell them apart');

    { and prove it: pulling a face on the copy must leave the original alone }
    SetLength(Orig, 0);
    for I := 0 to Base - 1 do
      if D[I].Kind = ekFace then
      begin
        SetLength(Orig, Length(Orig) + 1);
        Orig[High(Orig)] := D[I].Poly[0];
      end;
    Copy0 := -1;
    for I := Base to D.Live - 1 do
      if (D[I].Kind = ekFace) and (Copy0 < 0) then Copy0 := I;
    Ok(Copy0 >= 0, 'the copy has a face to pull');
    Ok(D.PushPull(Copy0, 3), 'pulled a face on the copy');

    Moved := 0;
    K := 0;
    for I := 0 to Base - 1 do
      if D[I].Kind = ekFace then
      begin
        if Dist(D[I].Poly[0], Orig[K]) > 1E-9 then Inc(Moved);
        Inc(K);
      end;
    EqI(Moved, 0, 'nothing on the original moved');
  finally
    D.Free;
  end;
end;

{ ----------------------------------------------------------- moving parts - }
procedure TestMove;
var
  D: TWorkDoc;
  Sel: array of Integer;
  Pts: TP3Array;
  I, Before: Integer;
begin
  WriteLn('moving and stretching');
  D := TWorkDoc.Create;
  try
    MakeRect(D, 0, 0, 10, 6);
    Before := D.Live;

    { grab the top edge alone: the two side edges should follow it }
    SetLength(Sel, 1);
    Sel[0] := 2;                                    // the y = 6 edge
    D.VertsOf(Sel, Pts);
    EqI(Length(Pts), 2, 'an edge offers two corners');
    D.MoveVerts(Pts, P3(0, 4, 0));

    EqI(D.Live, Before, 'stretching adds nothing');
    EqF(D[2].A.Y, 10, 'the moved edge is at y = 10');
    { the sides run from y = 0 to the moved edge, so one end of each moved }
    EqF(Max(D[1].A.Y, D[1].B.Y), 10, 'the right side stretched with it');
    EqF(Max(D[3].A.Y, D[3].B.Y), 10, 'the left side stretched with it');
    EqF(Min(D[0].A.Y, D[0].B.Y), 0, 'the bottom edge stayed put');

    { and the face followed, so its outline is still the rectangle }
    I := 4;
    EqI(Length(D[I].Poly), 4, 'the face still has four corners');
    EqF(D.FaceArea(I), 100, 'the face grew to 10 x 10');
  finally
    D.Free;
  end;
end;

{ ------------------------------------------------------- splitting a face - }
procedure TestSplitAndMerge;
var
  D: TWorkDoc;
begin
  WriteLn('splitting and healing');
  D := TWorkDoc.Create;
  try
    MakeRect(D, 0, 0, 10, 6);
    EqI(CountKind(D, ekFace), 1, 'one face to start');
    D.AddLine(P3(5, 0, 0), P3(5, 6, 0), 0, 2, False);
    EqI(D.SplitFacesWith(P3(5, 0, 0), P3(5, 6, 0)), 1, 'the line split one face');
    EqI(CountKind(D, ekFace), 2, 'two faces after the cut');
    EqF(D.FaceArea(4) + D.FaceArea(D.Live - 1), 60, 'the halves still add up', 1E-6);
  finally
    D.Free;
  end;
end;

{ ------------------------------------------------------- on-edge snapping - }
procedure TestEdgeSnap;
var
  D: TWorkDoc;
  V: TProjector;
  P: TP3;
  Ent: Integer;
  S: TPointF;
begin
  WriteLn('snapping onto an edge');
  D := TWorkDoc.Create;
  try
    MakeRect(D, 0, 0, 10, 6);
    FillChar(V, SizeOf(V), 0);
    V.Kind := vkPlan;
    V.Ppu := 20;
    V.OX := 400;
    V.OY := 300;

    { a point three-quarters along the bottom edge, nudged two pixels off it }
    S := Project(V, P3(7.5, 0, 0));
    Ok(D.EdgeSnap(V, S.X, S.Y + 2, 7, P, Ent), 'found the edge under the pointer');
    EqF(P.Y, 0, 'the point landed on the edge', 1E-6);
    EqF(P.X, 7.5, 'and at the right place along it', 0.2);

    { far enough away and it should find nothing }
    Ok(not D.EdgeSnap(V, S.X, S.Y + 40, 7, P, Ent), 'nothing when well clear');
  finally
    D.Free;
  end;
end;

{ --------------------------------------------- midpoints of cut-up lines - }
procedure TestSubMidpoints;
var
  D: TWorkDoc;
  V: TProjector;
  Hit: TSnapHit;
  S: TPointF;

  procedure Want(const P: TP3; const What: string);
  var
    Q: TPointF;
  begin
    Q := Project(V, P);
    if D.BestSnap(V, Q.X, Q.Y, 6, Hit) and (Dist(Hit.P, P) < 1E-6) then
      Ok(True, What)
    else
      Ok(False, What);
  end;

begin
  WriteLn('midpoints of the pieces a crossing makes');
  D := TWorkDoc.Create;
  try
    FillChar(V, SizeOf(V), 0);
    V.Kind := vkPlan;
    V.Ppu := 20;
    V.OX := 400;
    V.OY := 300;

    { a rectangle, then lines across it midpoint to midpoint - the tic-tac-toe
      board.  Each piece of an outer edge should offer its own middle. }
    MakeRect(D, 0, 0, 12, 12);
    D.AddLine(P3(4, 0, 0), P3(4, 12, 0), 0, 2, False);
    D.AddLine(P3(8, 0, 0), P3(8, 12, 0), 0, 2, False);
    D.AddLine(P3(0, 4, 0), P3(12, 4, 0), 0, 2, False);
    D.AddLine(P3(0, 8, 0), P3(12, 8, 0), 0, 2, False);

    Want(P3(6, 0, 0), 'the middle of the whole bottom edge');
    Want(P3(2, 0, 0), 'the middle of the bottom edge left piece');
    Want(P3(6, 4, 0), 'the middle of a piece of an inner line');
    Want(P3(4, 2, 0), 'the middle of a vertical piece');
    Want(P3(4, 4, 0), 'a crossing');
    S := Project(V, P3(2, 0, 0));
    Ok(D.BestSnap(V, S.X, S.Y, 6, Hit) and (Hit.Kind = snSubMid),
       'and it is reported as a piece midpoint');
  finally
    D.Free;
  end;
end;

{ ------------------------------------------- a circle drawn on a big face - }
procedure TestCircleOnFace;
var
  D: TWorkDoc;
  V: TProjector;
  Loop: TP3Array;
  I, Big, Ring, Got, Before: Integer;
  S: TPointF;
begin
  WriteLn('a circle drawn on a bigger face');
  D := TWorkDoc.Create;
  try
    FillChar(V, SizeOf(V), 0);
    V.Kind := vkPlan;
    V.Ppu := 20;
    V.OX := 400;
    V.OY := 300;

    MakeRect(D, 0, 0, 20, 16);
    Big := 4;
    EqI(Ord(D[Big].Kind), Ord(ekFace), 'the big face is where we think');

    { the circle tool: an arc, then a polygon face over the same ground }
    D.AddArc(P3(10, 8, 0), 3, 0, 2 * Pi, plXY, 0, 2);
    SetLength(Loop, 48);
    for I := 0 to 47 do
      Loop[I] := ArcPoint(P3(10, 8, 0), 3, 2 * Pi * I / 48, plXY);
    D.AddFace(Loop, 0);
    Ring := D.Live - 1;
    EqI(Ord(D[Ring].Kind), Ord(ekFace), 'the circle made a face');
    Ok(D.FaceArea(Ring) < D.FaceArea(Big), 'and it is the smaller of the two');

    S := Project(V, P3(10, 8, 0));
    Got := D.HitFace(V, S.X, S.Y);
    EqI(Got, Ring, 'clicking the middle of the circle picks the circle');

    { the same click in the other two views - this is where it went wrong }
    V.Kind := vkIso;
    S := Project(V, P3(10, 8, 0));
    Got := D.HitFace(V, S.X, S.Y);
    EqI(Got, Ring, 'and in the isometric view');

    V.Kind := vkOrbit;
    V.Az := 0.7;
    V.El := 0.6;
    S := Project(V, P3(10, 8, 0));
    Got := D.HitFace(V, S.X, S.Y);
    EqI(Got, Ring, 'and in the 3D view');

    { and pulling it should give a round tower, not a square one }
    Before := D.Live;
    Ok(D.PushPull(Ring, 10), 'the circle pulled');
    Got := -1;
    for I := Before to D.Live - 1 do
      if (D[I].Kind = ekFace) and (Length(D[I].Poly) = 48) then Got := I;
    Ok(Got >= 0, 'a 48-sided face came out of it - a round top, not a box');
    EqF(D[Ring].Poly[0].Z, 10, 'the circle went up', 1E-9);
    EqF(D[Big].Poly[0].Z, 0, 'and the rectangle stayed put', 1E-9);
  finally
    D.Free;
  end;

  { The one that bit us: coplanar faces whose depths differ only by rounding.
    A circle's polygon has very short sides, so solving the cursor onto its
    plane was less accurate than doing it on the slab, and the difference was
    thousands of times bigger than the nudge meant to prefer the smaller
    face.  Real numbers from the app: a 24-sided circle of radius 5 on a
    20.8 x 16.7 slab, the whole thing sitting well away from the origin. }
  WriteLn('the same thing at the scale the app works at');
  D := TWorkDoc.Create;
  try
    FillChar(V, SizeOf(V), 0);
    V.Kind := vkIso;
    V.Ppu := 27.4;
    V.OX := 120;
    V.OY := 560;

    MakeRect(D, 9, 2.08, 29.83, 18.75);
    Big := 4;
    SetLength(Loop, 24);
    for I := 0 to 23 do
      Loop[I] := ArcPoint(P3(19.42, 10.42, 0), 5, 2 * Pi * I / 24, plXY);
    D.AddFace(Loop, 0);
    Ring := D.Live - 1;

    S := Project(V, P3(19.42, 10.42, 0));
    EqI(D.HitFace(V, S.X, S.Y), Ring, 'the circle wins at the middle');
    S := Project(V, P3(19.42 + 4.0, 10.42, 0));
    EqI(D.HitFace(V, S.X, S.Y), Ring, 'and near its edge');
    S := Project(V, P3(19.42 + 7.0, 10.42, 0));
    EqI(D.HitFace(V, S.X, S.Y), Big, 'the slab wins outside it');
  finally
    D.Free;
  end;
end;

begin
  WriteLn('Heckers Sketch - geometry checks');
  WriteLn;
  TestParsing;      WriteLn;
  TestSaveLoad;     WriteLn;
  TestDuplicate;    WriteLn;
  TestMove;         WriteLn;
  TestSplitAndMerge; WriteLn;
  TestEdgeSnap;     WriteLn;
  TestSubMidpoints; WriteLn;
  TestCircleOnFace; WriteLn;
  WriteLn(Format('%d checks, %d failed', [Checks, Fails]));
  if Fails > 0 then Halt(1);
end.
