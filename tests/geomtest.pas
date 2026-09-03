{ Headless checks on the document model.

  Everything here runs without a window, so a regression shows up as a failed
  line rather than as something looking wrong three screenshots later.  Build
  and run it with tests/run.sh. }
program geomtest;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Math, uWork;

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
    A.AddDim(P3(0, 0, 0), P3(10, 0, 0), 0, 20);
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

begin
  WriteLn('Heckers Sketch - geometry checks');
  WriteLn;
  TestParsing;      WriteLn;
  TestSaveLoad;     WriteLn;
  TestDuplicate;    WriteLn;
  TestMove;         WriteLn;
  TestSplitAndMerge; WriteLn;
  WriteLn(Format('%d checks, %d failed', [Checks, Fails]));
  if Fails > 0 then Halt(1);
end.
