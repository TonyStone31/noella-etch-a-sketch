program makerobot;

{ The robot with the etch-a-sketch in his chest.

  From a note: "draw a robot standing up with arms and the etchasketch toy is in his
  chest as if someone could walk up to the robot and sketch something."

  So he is built to be walked up to: six foot two to the top of his head,
  and the toy set in his chest with its middle at fifty inches, which is
  about where a light switch goes and about where your hands are when you
  are standing at something.

  **The toy is not drawn again here.**  It is the example in uExample - the
  same drawing the help pictures use - loaded, stood on end, and set into
  the chest.  That is the whole trick of this one: a model built out of
  another model, which is what anybody would do and what the program should
  be able to do.  If the toy is ever improved, the robot gets it.

  Everything is in inches and divided by twelve on the way out, because the
  drawing's unit is the foot and nobody thinks about a robot in feet.

  Run it to write examples/robot.hsk and ../uExRobot.pas:
      cd examples
      fpc -Mobjfpc -Sh -Fu.. make-robot.pas && ./makerobot

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE. }

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Math, Types, Graphics, uWork, uExample;

const
  IN_ = 1 / 12;

  { --- the robot, in inches ------------------------------------------- }
  FOOT_L = 10;  FOOT_W = 5.5;  FOOT_H = 2.5;
  SHIN    = 17;    SHIN_W  = 4.0;
  THIGH   = 14;    THIGH_W = 5.0;
  HIP_W   = 17;  HIP_D = 8;   HIP_H = 6;
  TORSO_W = 21;  TORSO_D = 10; TORSO_H = 23;
  NECK_H  = 3;
  HEAD_W  = 11;  HEAD_D = 9;  HEAD_H = 9;
  ARM_UP  = 13;  ARM_LO = 12;  ARM_W = 4.4;
  STANCE  = 6.5;                 { half the distance between the feet }

  { Worked out rather than typed, because typing them is how the arms ended
    up hung in mid air beside his head: the shoulders were put at 66 inches
    and the top of the torso is at 62 and a half. }
  HIP_Z   = FOOT_H + SHIN + THIGH;
  TORSO_Z = HIP_Z + HIP_H;
  TORSO_T = TORSO_Z + TORSO_H;
  SHZ     = TORSO_T - 4;          { the shoulder joint }
  BALL_R  = 3.4;                  { the shoulder ball }
  ELB_R   = 2.3;

  { where the toy sits: its middle, off the floor and off the chest }
  PANEL_Z = 50;
  { the toy is 12 x 9 x 1.67, and stands proud of the chest on a bezel }
  TOY_W = 12;  TOY_H = 9;  TOY_T = 1.67;
  BEZEL = 1.4;

var
  D: TWorkDoc;
  CSteel, CDark, CRed, CEye, CRubber: TColor;

function Pt(X, Y, Z: Double): TP3;
begin
  Result := P3(X * IN_, Y * IN_, Z * IN_);
end;

{ --- the same solid-making helpers the broom uses -------------------- }

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
  C.X := C.X / Length(Pts); C.Y := C.Y / Length(Pts); C.Z := C.Z / Length(Pts);
  N := D.FaceNormal(K);
  if Dot3(N, P3(C.X - Mid.X, C.Y - Mid.Y, C.Z - Mid.Z)) < 0 then D.FlipFace(K);
  D.SetMaterial(K, Mat);
end;

procedure Tube(const Lo, Hi: array of TP3; Mat: TColor; EdgeW: Single);
var
  N, I, J, G: Integer;
  Mid: TP3;
  Side: array[0..3] of TP3;
begin
  N := Length(Lo);
  G := D.NewGroup;
  Mid := P3(0, 0, 0);
  for I := 0 to N - 1 do
  begin
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
    if EdgeW > 0 then
    begin
      D.AddLine(Lo[I], Lo[J], clBlack, EdgeW, False); D.SetGroup(D.Live - 1, G);
      D.AddLine(Hi[I], Hi[J], clBlack, EdgeW, False); D.SetGroup(D.Live - 1, G);
      D.AddLine(Lo[I], Hi[I], clBlack, EdgeW, False); D.SetGroup(D.Live - 1, G);
    end;
  end;
end;

{ A box, corner to corner. }
procedure Box(X0, Y0, Z0, X1, Y1, Z1: Double; Mat: TColor; EdgeW: Single = 1.0);
var
  Lo, Hi: array[0..3] of TP3;
begin
  Lo[0] := Pt(X0, Y0, Z0); Lo[1] := Pt(X1, Y0, Z0);
  Lo[2] := Pt(X1, Y1, Z0); Lo[3] := Pt(X0, Y1, Z0);
  Hi[0] := Pt(X0, Y0, Z1); Hi[1] := Pt(X1, Y0, Z1);
  Hi[2] := Pt(X1, Y1, Z1); Hi[3] := Pt(X0, Y1, Z1);
  Tube(Lo, Hi, Mat, EdgeW);
end;

{ A ball, for a joint.

  From a note: "his arms are floating... attch his arms to his uppert chest with
  like a ball joint."  So there is a ball where the arm meets the chest, big
  enough to bury itself in the torso, and a smaller one at the elbow.  An arm
  that starts inside a ball that is inside the body is an arm that is
  attached, and it turns the corner at the elbow without a seam.

  Rings of latitude with quads between them and a fan at each pole, and no
  edges drawn at all: what you see is the shading, which is what makes a
  faceted ball read as a ball. }
procedure Ball(const C: TP3; R: Double; Mat: TColor);
const
  { Few enough that a facet is bigger than a pixel at the size anybody looks
    at him.  Eighteen by nine was tried and speckles: the facets come out
    under a pixel each and the flat shading turns to noise. }
  SEG = 12; RINGS = 6;
var
  G, I, J: Integer;
  Lat0, Lat1, Lon0, Lon1: Double;
  P: array[0..3] of TP3;

  function Sph(Lat, Lon: Double): TP3;
  begin
    Result := P3(C.X + R * Cos(Lat) * Cos(Lon),
                 C.Y + R * Cos(Lat) * Sin(Lon),
                 C.Z + R * Sin(Lat));
  end;

begin
  G := D.NewGroup;
  for I := 0 to RINGS - 1 do
  begin
    Lat0 := -Pi / 2 + Pi * I / RINGS;
    Lat1 := -Pi / 2 + Pi * (I + 1) / RINGS;
    for J := 0 to SEG - 1 do
    begin
      Lon0 := 2 * Pi * J / SEG;
      Lon1 := 2 * Pi * (J + 1) / SEG;
      if I = 0 then
      begin
        P[0] := Sph(Lat0, 0); P[1] := Sph(Lat1, Lon0); P[2] := Sph(Lat1, Lon1);
        FaceOut([P[0], P[1], P[2]], C, Mat, G);
      end
      else if I = RINGS - 1 then
      begin
        P[0] := Sph(Lat0, Lon0); P[1] := Sph(Lat0, Lon1); P[2] := Sph(Lat1, 0);
        FaceOut([P[0], P[1], P[2]], C, Mat, G);
      end
      else
      begin
        P[0] := Sph(Lat0, Lon0); P[1] := Sph(Lat0, Lon1);
        P[2] := Sph(Lat1, Lon1); P[3] := Sph(Lat1, Lon0);
        FaceOut([P[0], P[1], P[2], P[3]], C, Mat, G);
      end;
    end;
  end;
end;

{ A limb: a square section swept from one point to another, so an arm can
  lie along any direction rather than only along an axis. }
procedure Limb(const A, B: TP3; W: Double; Mat: TColor);
var
  Dir, U, V: TP3;
  Lo, Hi: array[0..3] of TP3;
  I: Integer;
  H: Double;
begin
  H := W * IN_ / 2;
  Dir := Norm3(P3(B.X - A.X, B.Y - A.Y, B.Z - A.Z));
  AxesFromNormal(Dir, U, V);
  for I := 0 to 3 do
  begin
    case I of
      0: begin Lo[I] := P3(A.X - U.X * H - V.X * H, A.Y - U.Y * H - V.Y * H, A.Z - U.Z * H - V.Z * H); end;
      1: begin Lo[I] := P3(A.X + U.X * H - V.X * H, A.Y + U.Y * H - V.Y * H, A.Z + U.Z * H - V.Z * H); end;
      2: begin Lo[I] := P3(A.X + U.X * H + V.X * H, A.Y + U.Y * H + V.Y * H, A.Z + U.Z * H + V.Z * H); end;
    else  begin Lo[I] := P3(A.X - U.X * H + V.X * H, A.Y - U.Y * H + V.Y * H, A.Z - U.Z * H + V.Z * H); end;
    end;
    Hi[I] := P3(Lo[I].X + B.X - A.X, Lo[I].Y + B.Y - A.Y, Lo[I].Z + B.Z - A.Z);
  end;
  Tube(Lo, Hi, Mat, 1.0);
end;

{ --- the toy, stood on end and set in the chest ---------------------- }

{ Bring another drawing in, turned and moved to where it is wanted.

  A model built out of another model needs exactly this and the program has
  no other way to do it yet - which is worth knowing: when parts arrive (see
  docs/groupplan.md) this is the job they do properly, with one copy and a
  placement rather than a second set of geometry. }
procedure PlaceDrawing(Src: TWorkDoc; const Turn: TP3; Ang: Double;
  const Shift: TP3);
var
  I, J, K, G, F: Integer;
  Poly: TP3Array;
  Holes: array of TP3Array;

  function Put(const P: TP3): TP3;
  begin
    Result := RotP(P, P3(0, 0, 0), Turn, Ang);
    Result := P3(Result.X + Shift.X, Result.Y + Shift.Y, Result.Z + Shift.Z);
  end;

begin
  G := D.NewGroup;
  for I := 0 to Src.Live - 1 do
    case Src[I].Kind of
      ekLine:
        begin
          D.AddLine(Put(Src[I].A), Put(Src[I].B), Src[I].Ink, Src[I].Weight, False);
          D.SetGroup(D.Live - 1, G);
          D.SetSoft(D.Live - 1, Src[I].Soft);
        end;
      ekFace:
        begin
          SetLength(Poly, Length(Src[I].Poly));
          for J := 0 to High(Poly) do Poly[J] := Put(Src[I].Poly[J]);
          D.AddFaceRaw(Poly, Src[I].Ink, True);
          F := D.Live - 1;
          D.SetFaceGroup(F, G);
          { The toy was drawn before faces could carry a material, so its
            colors live in the pen.  Painting each face with the color it
            was drawn in is what makes it read as a red toy with a gray
            screen rather than as a white box. }
          D.SetMaterial(F, Src[I].Ink);
          if Length(Src[I].Holes) > 0 then
          begin
            SetLength(Holes, Length(Src[I].Holes));
            for K := 0 to High(Holes) do
            begin
              SetLength(Holes[K], Length(Src[I].Holes[K]));
              for J := 0 to High(Holes[K]) do Holes[K][J] := Put(Src[I].Holes[K][J]);
            end;
            D.SetFaceHoles(F, Holes);
          end;
        end;
    end;
end;

var
  Toy: TWorkDoc;
  L, Out_, U: TStringList;
  Idx, I, F: Integer;
  BLo, BHi, CamMid: TP3;
  CamV: TProjector;
  CamP: TPointF;
  BaseP, Diag, CamZoom: Double;
  SLo, SHi: TP3;
  FS: TFormatSettings;
const
  ART_W = 1200; ART_H = 760;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  CSteel  := RGBToColor(172, 179, 187);
  CDark   := RGBToColor( 86,  92, 100);
  CRed    := RGBToColor(200,  48,  32);   { the toy's own red }
  CEye    := RGBToColor(255, 176,  60);
  CRubber := RGBToColor( 46,  48,  52);

  D := TWorkDoc.Create;
  Toy := TWorkDoc.Create;
  L := TStringList.Create;
  Out_ := TStringList.Create;
  try
    { --- feet and legs ----------------------------------------------- }
    for I := 0 to 1 do
    begin
      F := 1 - 2 * I;            { +1 right, -1 left }
      Box(F * STANCE - FOOT_W / 2, -FOOT_L * 0.62, 0,
          F * STANCE + FOOT_W / 2,  FOOT_L * 0.38, FOOT_H, CRubber);
      Limb(Pt(F * STANCE, 0, FOOT_H), Pt(F * STANCE, 0, FOOT_H + SHIN),
        SHIN_W, CDark);
      Limb(Pt(F * STANCE, 0, FOOT_H + SHIN),
           Pt(F * (HIP_W / 2 - THIGH_W / 2), 0, FOOT_H + SHIN + THIGH),
        THIGH_W, CSteel);
    end;

    { --- hips and torso ---------------------------------------------- }
    Box(-HIP_W / 2, -HIP_D / 2, FOOT_H + SHIN + THIGH,
         HIP_W / 2,  HIP_D / 2, FOOT_H + SHIN + THIGH + HIP_H, CDark);
    Box(-TORSO_W / 2, -TORSO_D / 2, FOOT_H + SHIN + THIGH + HIP_H,
         TORSO_W / 2,  TORSO_D / 2, FOOT_H + SHIN + THIGH + HIP_H + TORSO_H,
      CSteel);

    { --- the chest panel: a red bezel, and the toy standing in it ----- }
    Box(-(TOY_W / 2 + BEZEL), -TORSO_D / 2 - 0.6, PANEL_Z - (TOY_H / 2 + BEZEL),
         (TOY_W / 2 + BEZEL), -TORSO_D / 2,       PANEL_Z + (TOY_H / 2 + BEZEL),
      CRed);

    { --- arms, hung off a ball at the top of the chest ----------------- }
    for I := 0 to 1 do
    begin
      F := 1 - 2 * I;
      { The ball sits half inside the torso, so the joint is a joint rather
        than a sphere parked next to a box. }
      Ball(Pt(F * (TORSO_W / 2 - 0.8), 0, SHZ), BALL_R * IN_, CDark);
      { upper arm, out of the middle of the ball and down }
      Limb(Pt(F * (TORSO_W / 2 - 0.8), 0, SHZ),
           Pt(F * (TORSO_W / 2 + 4.2), 0, SHZ - ARM_UP), ARM_W, CSteel);
      { the elbow, and the forearm forward - as if he is offering the panel }
      Ball(Pt(F * (TORSO_W / 2 + 4.2), 0, SHZ - ARM_UP), ELB_R * IN_, CDark);
      Limb(Pt(F * (TORSO_W / 2 + 4.2), 0, SHZ - ARM_UP),
           Pt(F * (TORSO_W / 2 + 4.2), -ARM_LO * 0.82, SHZ - ARM_UP - ARM_LO * 0.34),
        ARM_W, CDark);
      { and a two-fingered hand on the end of it }
      Box(F * (TORSO_W / 2 + 4.2) - 1.6, -ARM_LO * 0.82 - 3.4, SHZ - ARM_UP - ARM_LO * 0.34 - 1.4,
          F * (TORSO_W / 2 + 4.2) - 0.2, -ARM_LO * 0.82,       SHZ - ARM_UP - ARM_LO * 0.34 + 1.4,
        CSteel);
      Box(F * (TORSO_W / 2 + 4.2) + 0.2, -ARM_LO * 0.82 - 3.4, SHZ - ARM_UP - ARM_LO * 0.34 - 1.4,
          F * (TORSO_W / 2 + 4.2) + 1.6, -ARM_LO * 0.82,       SHZ - ARM_UP - ARM_LO * 0.34 + 1.4,
        CSteel);
    end;

    { --- neck, head, eyes, antenna ------------------------------------ }
    Box(-2.6, -2.6, FOOT_H + SHIN + THIGH + HIP_H + TORSO_H,
         2.6,  2.6, FOOT_H + SHIN + THIGH + HIP_H + TORSO_H + NECK_H, CDark);
    Box(-HEAD_W / 2, -HEAD_D / 2, FOOT_H + SHIN + THIGH + HIP_H + TORSO_H + NECK_H,
         HEAD_W / 2,  HEAD_D / 2, FOOT_H + SHIN + THIGH + HIP_H + TORSO_H + NECK_H + HEAD_H,
      CSteel);
    { the eyes, standing a little proud of the face so they catch the light }
    for I := 0 to 1 do
    begin
      F := 1 - 2 * I;
      Box(F * 2.9 - 1.5, -HEAD_D / 2 - 0.35, TORSO_T + NECK_H + 5.1,
          F * 2.9 + 1.5, -HEAD_D / 2,        TORSO_T + NECK_H + 7.5, CEye, 0.8);
    end;
    { a jaw band, so the head has a front }
    Box(-HEAD_W / 2 - 0.2, -HEAD_D / 2 - 0.25, TORSO_T + NECK_H + 1.2,
         HEAD_W / 2 + 0.2, -HEAD_D / 2,        TORSO_T + NECK_H + 3.0, CDark, 0.8);
    { antenna }
    Box(-0.35, -0.35, FOOT_H + SHIN + THIGH + HIP_H + TORSO_H + NECK_H + HEAD_H,
         0.35,  0.35, FOOT_H + SHIN + THIGH + HIP_H + TORSO_H + NECK_H + HEAD_H + 5.5,
      CDark, 0.8);
    Box(-1.1, -1.1, FOOT_H + SHIN + THIGH + HIP_H + TORSO_H + NECK_H + HEAD_H + 5.5,
         1.1,  1.1, FOOT_H + SHIN + THIGH + HIP_H + TORSO_H + NECK_H + HEAD_H + 7.0,
      CRed, 0.8);

    { --- and the toy itself, stood on end and set on the bezel -------- }
    ExampleDrawing(L);
    Idx := 0;
    while (Idx < L.Count) and (Copy(Trim(L[Idx]), 1, 6) <> 'SHEET ') do Inc(Idx);
    if Idx < L.Count then Inc(Idx) else Idx := 0;
    Toy.LoadFrom(L, Idx);
    { it lies flat with its near bottom left corner on the origin, screen up.
      A quarter turn about red stands it up with the screen facing front. }
    PlaceDrawing(Toy, P3(1, 0, 0), Pi / 2,
      Pt(-TOY_W / 2, -TORSO_D / 2 - 0.6, PANEL_Z - TOY_H / 2));

    { --- out it goes -------------------------------------------------- }
    BaseP := PixelsPerUnit(usImperial, ScaleTable(usImperial, 2), 96);
    D.Bounds(BLo, BHi);
    CamMid := P3((BLo.X + BHi.X) / 2, (BLo.Y + BHi.Y) / 2, (BLo.Z + BHi.Z) / 2);
    Diag := Sqrt(Sqr(BHi.X - BLo.X) + Sqr(BHi.Y - BLo.Y) + Sqr(BHi.Z - BLo.Z));
    { Fitted to what he actually covers on the screen rather than to the
      diagonal of his box.  He is six foot two and a foot and a half wide, so
      his diagonal is nearly his height and fitting by it leaves him hanging
      out of the bottom of a small window - which is exactly what happened. }
    CamV.Kind := vkOrbit;
    CamV.Az := -1.05;
    CamV.El := 0.26;
    CamV.Ppu := 1; CamV.OX := 0; CamV.OY := 0;
    SLo := P3(1E30, 1E30, 0); SHi := P3(-1E30, -1E30, 0);
    for I := 0 to 7 do
    begin
      CamP := Project(CamV, P3(
        specialize IfThen<Double>((I and 1) = 0, BLo.X, BHi.X),
        specialize IfThen<Double>((I and 2) = 0, BLo.Y, BHi.Y),
        specialize IfThen<Double>((I and 4) = 0, BLo.Z, BHi.Z)));
      SLo.X := Min(SLo.X, CamP.X); SHi.X := Max(SHi.X, CamP.X);
      SLo.Y := Min(SLo.Y, CamP.Y); SHi.Y := Max(SHi.Y, CamP.Y);
    end;
    CamZoom := Min((ART_W * 0.86) / ((SHi.X - SLo.X) * BaseP),
                   (ART_H * 0.86) / ((SHi.Y - SLo.Y) * BaseP));
    CamV.Ppu := BaseP * CamZoom;   { low elevation: you look at him, not down on him }
    CamV.OX := 0;
    CamV.OY := 0;
    CamP := Project(CamV, CamMid);

    Out_.Add('HECKERS-SKETCH 1');
    Out_.Add('SHEET Robot');
    Out_.Add('UNITS 0');
    Out_.Add('SCALE 2');
    Out_.Add('SNAP 1');
    Out_.Add('VIEW 2');
    Out_.Add(StringReplace(Format('CAMERA %.6f %.6f %.6f %.3f %.3f',
      [CamV.Az, CamV.El, CamZoom, ART_W / 2 - CamP.X, ART_H / 2 - CamP.Y]),
      DefaultFormatSettings.DecimalSeparator, '.', [rfReplaceAll]));
    D.SaveTo(Out_);
    Out_.Add('ENDSHEET');
    Out_.SaveToFile('robot.hsk');

    U := TStringList.Create;
    U.Add('unit uExRobot;');
    U.Add('');
    U.Add('{ The robot with the etch-a-sketch in his chest.');
    U.Add('');
    U.Add('  Generated by examples/make-robot.pas - do not edit this by hand,');
    U.Add('  edit that and run it again.  It is the same drawing as');
    U.Add('  examples/robot.hsk, carried inside the program so that a');
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
    U.Add('{ The robot, as the lines of a .hsk file. }');
    U.Add('procedure RobotDrawing(L: TStrings);');
    U.Add('');
    U.Add('implementation');
    U.Add('');
    U.Add('procedure RobotDrawing(L: TStrings);');
    U.Add('begin');
    for I := 0 to Out_.Count - 1 do
      U.Add('  L.Add(' + QuotedStr(Out_[I]) + ');');
    U.Add('end;');
    U.Add('');
    U.Add('end.');
    U.SaveToFile('../uExRobot.pas');
    U.Free;

    F := 0;
    for I := 0 to D.Live - 1 do if D[I].Kind = ekFace then Inc(F);
    WriteLn(Format('%d things, %d faces -> robot.hsk and uExRobot.pas (%d lines)',
      [D.Live, F, Out_.Count]));
  finally
    Out_.Free; L.Free; Toy.Free; D.Free;
  end;
end.
