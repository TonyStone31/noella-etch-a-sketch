program makeball;

{ A football, the size five you would actually kick.

  Thirty-two panels - twelve pentagons and twenty hexagons - which is a
  truncated icosahedron, and it is worth saying where they come from because
  they are not typed in.  Start with an icosahedron: twelve corners, twenty
  triangles.  Cut every corner off a third of the way along each edge
  meeting it.  What was a corner becomes a pentagon, and what was a triangle
  becomes a hexagon.  That is the whole shape, and it is built here exactly
  that way, from twelve points and the golden ratio.

  Each panel is a thin slab standing off a dark inner ball, so the gaps
  between them read as the seams they are.  The panels are laid on the
  sphere rather than on the flat faces of the polyhedron, which is what
  makes it look kicked rather than folded.

  Everything is in inches and divided by twelve on the way out.  A size five
  ball is 8.65 inches across, and it is that here.

  Run it to write examples/ball.hsk and ../uExBall.pas:
      cd examples
      fpc -Mobjfpc -Sh -Fu.. make-ball.pas && ./makeball

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE. }

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Math, Types, Graphics, uWork;

const
  IN_ = 1 / 12;
  DIA = 8.65;                { a size five, across }
  { How thick a panel reads, IN INCHES - the radius is in feet, and the
    first go had this as feet by accident, which put the dark ball inside
    the ball out through the sides of every panel. }
  SKIN_IN = 0.25;
  INSET = 0.055;             { how far a panel is pulled in from its edge -
                               this is what opens the seams }
  { The dark ball behind the panels, as a fraction of the radius.  Well
    clear of them: at 0.955 it sat four hundredths of an inch under the
    panels and the depth buffer could not keep them apart, so the core came
    up through the middle of every panel in patches.  Down here the seams
    are seams and nothing fights. }
  CORE_R = 0.88;

var
  D: TWorkDoc;
  CWhite, CBlack, CSeam: TColor;
  R: Double;

function Sc(const P: TP3; Len: Double): TP3;
var
  L: Double;
begin
  L := Sqrt(P.X * P.X + P.Y * P.Y + P.Z * P.Z);
  if L < 1E-12 then L := 1;
  Result := P3(P.X / L * Len, P.Y / L * Len, P.Z / L * Len);
end;

procedure FaceOut(const Pts: array of TP3; const Mid: TP3; Mat: TColor;
  G: Integer);
var
  I, K: Integer;
  C, N: TP3;
begin
  D.AddFace(Pts, clBlack, True);
  K := D.Live - 1;
  D.SetFaceGroup(K, G);
  C := P3(0, 0, 0);
  for I := 0 to High(Pts) do
  begin
    C.X := C.X + Pts[I].X; C.Y := C.Y + Pts[I].Y; C.Z := C.Z + Pts[I].Z;
  end;
  C := P3(C.X / Length(Pts), C.Y / Length(Pts), C.Z / Length(Pts));
  N := D.FaceNormal(K);
  if Dot3(N, P3(C.X - Mid.X, C.Y - Mid.Y, C.Z - Mid.Z)) < 0 then D.FlipFace(K);
  D.SetMaterial(K, Mat);
end;

{ A panel: the same ring of points at two radii, closed up the sides.  No
  edges drawn - a stitched ball has no lines on it, and at this size the
  facet joins would be more ink than panel. }
procedure Panel(const Ring: array of TP3; Mat: TColor);
var
  N, I, J, G: Integer;
  Mid: TP3;
  Lo, Hi: array of TP3;
  Side: array[0..3] of TP3;
begin
  N := Length(Ring);
  G := D.NewGroup;
  SetLength(Lo, N);
  SetLength(Hi, N);
  Mid := P3(0, 0, 0);
  for I := 0 to N - 1 do
  begin
    Lo[I] := Sc(Ring[I], R - SKIN_IN * IN_);
    Hi[I] := Sc(Ring[I], R);
    Mid.X := Mid.X + Lo[I].X + Hi[I].X;
    Mid.Y := Mid.Y + Lo[I].Y + Hi[I].Y;
    Mid.Z := Mid.Z + Lo[I].Z + Hi[I].Z;
  end;
  Mid := P3(Mid.X / (2 * N), Mid.Y / (2 * N), Mid.Z / (2 * N));
  FaceOut(Lo, Mid, Mat, G);
  FaceOut(Hi, Mid, Mat, G);
  for I := 0 to N - 1 do
  begin
    J := (I + 1) mod N;
    Side[0] := Lo[I]; Side[1] := Lo[J]; Side[2] := Hi[J]; Side[3] := Hi[I];
    FaceOut(Side, Mid, Mat, G);
  end;
end;

{ The ball behind the panels, so the seams have something dark in them
  rather than a hole. }
procedure Core(Rad: Double; Mat: TColor);
const
  SEG = 24; RINGS = 12;
var
  G, I, J: Integer;
  La0, La1, Lo0, Lo1: Double;
  P: array[0..3] of TP3;

  function Sph(La, Lo: Double): TP3;
  begin
    Result := P3(Rad * Cos(La) * Cos(Lo), Rad * Cos(La) * Sin(Lo),
                 Rad * Sin(La));
  end;

begin
  G := D.NewGroup;
  for I := 0 to RINGS - 1 do
  begin
    La0 := -Pi / 2 + Pi * I / RINGS;
    La1 := -Pi / 2 + Pi * (I + 1) / RINGS;
    for J := 0 to SEG - 1 do
    begin
      Lo0 := 2 * Pi * J / SEG;
      Lo1 := 2 * Pi * (J + 1) / SEG;
      if I = 0 then
        FaceOut([Sph(La0, 0), Sph(La1, Lo0), Sph(La1, Lo1)], P3(0, 0, 0), Mat, G)
      else if I = RINGS - 1 then
        FaceOut([Sph(La0, Lo0), Sph(La0, Lo1), Sph(La1, 0)], P3(0, 0, 0), Mat, G)
      else
      begin
        P[0] := Sph(La0, Lo0); P[1] := Sph(La0, Lo1);
        P[2] := Sph(La1, Lo1); P[3] := Sph(La1, Lo0);
        FaceOut([P[0], P[1], P[2], P[3]], P3(0, 0, 0), Mat, G);
      end;
    end;
  end;
end;

var
  Ico: array[0..11] of TP3;
  Nb: array[0..11] of array of Integer;
  Tri: array of array[0..2] of Integer;
  L, Out_, U: TStringList;
  Phi, Ed, A: Double;
  I, J, K, M, NT, F: Integer;
  Ring: array of TP3;
  Cen, Ax, U1, V1, Pt0: TP3;
  Ord_: array[0..4] of Integer;
  All_: array of Integer;
  Ang: array[0..4] of Double;
  Tmp: Integer; TmpA: Double;
  BLo, BHi, CamMid: TP3;
  CamV: TProjector;
  CamP: TPointF;
  BaseP, Diag, CamZoom: Double;
const
  ART_W = 1200; ART_H = 760;

  { one third and two thirds along from A towards B }
  function Cut(const P, Q: TP3; T: Double): TP3;
  begin
    Result := P3(P.X + (Q.X - P.X) * T, P.Y + (Q.Y - P.Y) * T,
                 P.Z + (Q.Z - P.Z) * T);
  end;

  { pulled in towards the middle of its own panel, which is what opens the
    seam between one panel and the next }
  function Pull(const P, C: TP3): TP3;
  begin
    Result := P3(P.X + (C.X - P.X) * INSET, P.Y + (C.Y - P.Y) * INSET,
                 P.Z + (C.Z - P.Z) * INSET);
  end;

begin
  CWhite := RGBToColor(238, 238, 234);
  CBlack := RGBToColor( 34,  34,  38);
  CSeam  := RGBToColor( 22,  22,  24);
  R := DIA / 2 * IN_;

  D := TWorkDoc.Create;
  L := TStringList.Create;
  Out_ := TStringList.Create;
  try
    { --- the icosahedron the ball is cut from ------------------------- }
    Phi := (1 + Sqrt(5)) / 2;
    Ico[0]  := P3( 0,  1,  Phi);  Ico[1]  := P3( 0,  1, -Phi);
    Ico[2]  := P3( 0, -1,  Phi);  Ico[3]  := P3( 0, -1, -Phi);
    Ico[4]  := P3( 1,  Phi,  0);  Ico[5]  := P3( 1, -Phi,  0);
    Ico[6]  := P3(-1,  Phi,  0);  Ico[7]  := P3(-1, -Phi,  0);
    Ico[8]  := P3( Phi,  0,  1);  Ico[9]  := P3(-Phi,  0,  1);
    Ico[10] := P3( Phi,  0, -1);  Ico[11] := P3(-Phi,  0, -1);
    Ed := 2;                        { the edge length of that construction }

    for I := 0 to 11 do
    begin
      SetLength(Nb[I], 0);
      for J := 0 to 11 do
        if (I <> J) and (Abs(Dist(Ico[I], Ico[J]) - Ed) < 1E-6) then
        begin
          SetLength(Nb[I], Length(Nb[I]) + 1);
          Nb[I][High(Nb[I])] := J;
        end;
    end;

    { every triangle: three corners each next to the other two }
    NT := 0;
    SetLength(Tri, 20);
    for I := 0 to 11 do
      for J := I + 1 to 11 do
        for K := J + 1 to 11 do
          if (Abs(Dist(Ico[I], Ico[J]) - Ed) < 1E-6) and
             (Abs(Dist(Ico[J], Ico[K]) - Ed) < 1E-6) and
             (Abs(Dist(Ico[I], Ico[K]) - Ed) < 1E-6) then
          begin
            Tri[NT][0] := I; Tri[NT][1] := J; Tri[NT][2] := K;
            Inc(NT);
          end;

    { --- the dark ball the panels sit on ----------------------------- }
    Core(R * CORE_R, CSeam);

    { --- twelve pentagons, one where each corner was ------------------ }
    for I := 0 to 11 do
    begin
      { the five neighbours, put in order round the corner so the pentagon
        is a ring rather than a star }
      Ax := Sc(Ico[I], 1);
      AxesFromNormal(Ax, U1, V1);
      for J := 0 to 4 do
      begin
        Ord_[J] := Nb[I][J];
        Pt0 := P3(Ico[Ord_[J]].X - Ico[I].X, Ico[Ord_[J]].Y - Ico[I].Y,
                  Ico[Ord_[J]].Z - Ico[I].Z);
        Ang[J] := ArcTan2(Dot3(Pt0, V1), Dot3(Pt0, U1));
      end;
      for J := 0 to 3 do
        for K := 0 to 3 - J do
          if Ang[K] > Ang[K + 1] then
          begin
            TmpA := Ang[K]; Ang[K] := Ang[K + 1]; Ang[K + 1] := TmpA;
            Tmp := Ord_[K]; Ord_[K] := Ord_[K + 1]; Ord_[K + 1] := Tmp;
          end;
      SetLength(Ring, 5);
      Cen := P3(0, 0, 0);
      for J := 0 to 4 do
      begin
        Ring[J] := Cut(Ico[I], Ico[Ord_[J]], 1 / 3);
        Cen.X := Cen.X + Ring[J].X; Cen.Y := Cen.Y + Ring[J].Y;
        Cen.Z := Cen.Z + Ring[J].Z;
      end;
      Cen := P3(Cen.X / 5, Cen.Y / 5, Cen.Z / 5);
      for J := 0 to 4 do Ring[J] := Pull(Ring[J], Cen);
      Panel(Ring, CBlack);
    end;

    { --- twenty hexagons, one where each triangle was ----------------- }
    for M := 0 to NT - 1 do
    begin
      SetLength(Ring, 6);
      Cen := P3(0, 0, 0);
      for J := 0 to 2 do
      begin
        K := Tri[M][J];
        I := Tri[M][(J + 1) mod 3];
        Ring[J * 2]     := Cut(Ico[K], Ico[I], 1 / 3);
        Ring[J * 2 + 1] := Cut(Ico[K], Ico[I], 2 / 3);
      end;
      for J := 0 to 5 do
      begin
        Cen.X := Cen.X + Ring[J].X; Cen.Y := Cen.Y + Ring[J].Y;
        Cen.Z := Cen.Z + Ring[J].Z;
      end;
      Cen := P3(Cen.X / 6, Cen.Y / 6, Cen.Z / 6);
      { the three edges were walked corner to corner, which leaves the six
        points in a zig-zag; sorting them round the middle puts them in a
        ring }
      Ax := Sc(Cen, 1);
      AxesFromNormal(Ax, U1, V1);
      for J := 0 to 5 do
        for K := 0 to 4 - J do
        begin
          Pt0 := P3(Ring[K].X - Cen.X, Ring[K].Y - Cen.Y, Ring[K].Z - Cen.Z);
          A := ArcTan2(Dot3(Pt0, V1), Dot3(Pt0, U1));
          Pt0 := P3(Ring[K + 1].X - Cen.X, Ring[K + 1].Y - Cen.Y,
                    Ring[K + 1].Z - Cen.Z);
          if A > ArcTan2(Dot3(Pt0, V1), Dot3(Pt0, U1)) then
          begin
            Pt0 := Ring[K]; Ring[K] := Ring[K + 1]; Ring[K + 1] := Pt0;
          end;
        end;
      for J := 0 to 5 do Ring[J] := Pull(Ring[J], Cen);
      Panel(Ring, CWhite);
    end;

    { stand it on the floor, where everything else in the folder stands }
    D.Bounds(BLo, BHi);
    SetLength(All_, D.Live);
    for I := 0 to D.Live - 1 do All_[I] := I;
    D.TranslateEnts(All_, P3(0, 0, -BLo.Z));

    { --- out it goes -------------------------------------------------- }
    BaseP := PixelsPerUnit(usImperial, ScaleTable(usImperial, 4), 96);
    D.Bounds(BLo, BHi);
    CamMid := P3((BLo.X + BHi.X) / 2, (BLo.Y + BHi.Y) / 2, (BLo.Z + BHi.Z) / 2);
    Diag := Sqrt(Sqr(BHi.X - BLo.X) + Sqr(BHi.Y - BLo.Y) + Sqr(BHi.Z - BLo.Z));
    CamZoom := Min((ART_W * 0.70) / (Diag * BaseP),
                   (ART_H * 0.70) / (Diag * BaseP));
    CamV.Kind := vkOrbit;
    CamV.Az := -0.95;
    CamV.El := 0.38;
    CamV.Ppu := BaseP * CamZoom;
    CamV.OX := 0;
    CamV.OY := 0;
    CamP := Project(CamV, CamMid);

    Out_.Add('HECKERS-SKETCH 1');
    Out_.Add('SHEET Ball');
    Out_.Add('UNITS 0');
    Out_.Add('SCALE 4');
    Out_.Add('SNAP 1');
    Out_.Add('VIEW 2');
    Out_.Add(StringReplace(Format('CAMERA %.6f %.6f %.6f %.3f %.3f',
      [CamV.Az, CamV.El, CamZoom, ART_W / 2 - CamP.X, ART_H / 2 - CamP.Y]),
      DefaultFormatSettings.DecimalSeparator, '.', [rfReplaceAll]));
    D.SaveTo(Out_);
    Out_.Add('ENDSHEET');
    Out_.SaveToFile('ball.hsk');

    U := TStringList.Create;
    U.Add('unit uExBall;');
    U.Add('');
    U.Add('{ The football example.');
    U.Add('');
    U.Add('  Generated by examples/make-ball.pas - do not edit this by hand,');
    U.Add('  edit that and run it again.  It is the same drawing as');
    U.Add('  examples/ball.hsk, carried inside the program so that a');
    U.Add('  portable build is one file and the examples folder can be written');
    U.Add('  out beside it on a machine that has never seen one. }');
    U.Add('');
    U.Add('{$mode objfpc}{$H+}');
    U.Add('');
    U.Add('interface');
    U.Add('');
    U.Add('uses');
    U.Add('  Classes;');
    U.Add('');
    U.Add('{ The football, as the lines of a .hsk file. }');
    U.Add('procedure BallDrawing(L: TStrings);');
    U.Add('');
    U.Add('implementation');
    U.Add('');
    U.Add('procedure BallDrawing(L: TStrings);');
    U.Add('begin');
    for I := 0 to Out_.Count - 1 do
      U.Add('  L.Add(' + QuotedStr(Out_[I]) + ');');
    U.Add('end;');
    U.Add('');
    U.Add('end.');
    U.SaveToFile('../uExBall.pas');
    U.Free;

    F := 0;
    for I := 0 to D.Live - 1 do if D[I].Kind = ekFace then Inc(F);
    WriteLn(Format('%d things, %d faces, %d triangles cut -> ball.hsk',
      [D.Live, F, NT]));
  finally
    Out_.Free; L.Free; D.Free;
  end;
end.
