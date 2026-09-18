program makebroom;

{ The kitchen broom.

  The third example, and the one that explains materials - a hundred and
  seventy bristles in four colours, a blue moulded head, a wooden handle,
  and not a pen colour anywhere.  Every face carries a material, which is
  the thing that went in on 17 September and the thing a drawing full of
  white faces cannot show you.

  It is a real angle broom.  The block is cut on a slant, which is what lets
  a broom into a corner; the bristles splay as they come down; the handle
  leans back out of the head the way one does; and the bristles are banded
  across the width the way a shop broom is made up.

  Two decisions in here are worth knowing about, because both were arrived
  at by looking at the thing rather than by reasoning:

  * **The bristles carry no edges.**  A bristle is a tenth of an inch across
    and would carry twelve of them.  With edges on, a hundred and seventy of
    them came out as one black wedge at any zoom you would actually use -
    the ink swallowed the colour entirely.  Without them the material is all
    there is, which is what a bristle should be, and the model is a third of
    the size.
  * **Every bristle is a little different.**  All the same length and dead
    straight reads as a comb, not a broom.  Each gets its own tip height and
    a nudge sideways from a hash of its position: the same broom comes out
    every time, with no pattern the eye can pick up.

  Each solid is a closed run of faces wound outwards with a group of its
  own, which is what stops the region finder merging the bristles into each
  other where they nearly touch.

  Run it to write examples/broom.hsk and ../uExBroom.pas:
      cd examples
      fpc -Mobjfpc -Sh -Fu.. make-broom.pas && ./makebroom

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE. }

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Math, Types, Graphics, uWork;

const
  { Everything is in feet, which is what a drawing holds. }
  IN_ = 1 / 12;

  { --- the broom, in inches, so the numbers read like a tape measure --- }
  HEAD_W    = 11.5;   { across the head }
  HEAD_D    = 2.6;    { front to back }
  HEAD_H    = 2.0;    { the block itself }
  HEAD_Z    = 5.4;    { underside of the block, off the floor }

  BRIS_ROWS = 5;      { rows front to back }
  BRIS_COLS = 34;     { bristles across each row }
  BRIS_W    = 0.075;  { a bristle, square in section - half its own spacing,
                        so there is daylight between them and the banding can
                        be seen at all }
  FLARE_X   = 1.10;   { how much wider the tips are than the roots }
  FLARE_Y   = 1.45;   { and how much they fan front to back }
  SLANT     = 1.9;    { the angle the block is cut at, across the width }

  HANDLE_L  = 46.0;
  HANDLE_R  = 0.52;
  HANDLE_N  = 14;     { sides of the handle - 14 reads as round }
  LEAN      = 14.0;   { degrees the handle leans back out of the head }

  FERRULE_L = 3.2;
  FERRULE_R = 0.62;

  { the size the camera is worked out for - the same numbers the other
    examples use, so all three open looking about as big as each other }
  ART_W = 1200;
  ART_H = 760;

var
  D: TWorkDoc;

  { the colours, once }
  CWood, CFerrule, CHead, CCap, CBand: TColor;
  CBris: array[0..3] of TColor;

function Pt(X, Y, Z: Double): TP3;
begin
  Result := P3(X * IN_, Y * IN_, Z * IN_);
end;

{ Add one face of a solid, wound so its front looks away from Mid - which is
  what keeps the pale blue back-face colour off the outside of the model. }
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

procedure Edge(const A, B: TP3; G: Integer; W: Single);
begin
  D.AddLine(A, B, clBlack, W, False);
  D.SetGroup(D.Live - 1, G);
end;

{ A solid with a top ring of points and a bottom ring of the same count: a
  box, a tapered bristle, a many-sided handle.  One group, one material, and
  every face turned to look outwards. }
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
  Mid.X := Mid.X / (2 * N); Mid.Y := Mid.Y / (2 * N); Mid.Z := Mid.Z / (2 * N);

  FaceOut(Lo, Mid, Mat, G);
  FaceOut(Hi, Mid, Mat, G);
  for I := 0 to N - 1 do
  begin
    J := (I + 1) mod N;
    Side[0] := Lo[I]; Side[1] := Lo[J]; Side[2] := Hi[J]; Side[3] := Hi[I];
    FaceOut(Side, Mid, Mat, G);
    { EdgeW of nought means no edges at all.  A bristle is a tenth of an inch
      across and carries twelve of them; at any zoom you would actually look
      at this from, the ink swallows the colour and the whole block comes out
      as one black wedge.  Without them the material is all there is, which
      is what a bristle should be. }
    if EdgeW > 0 then
    begin
      Edge(Lo[I], Lo[J], G, EdgeW);
      Edge(Hi[I], Hi[J], G, EdgeW);
      Edge(Lo[I], Hi[I], G, EdgeW);
    end;
  end;
end;

procedure Box(X0, Y0, Z0, X1, Y1, Z1: Double; Mat: TColor; EdgeW: Single);
var
  Lo, Hi: array[0..3] of TP3;
begin
  Lo[0] := Pt(X0, Y0, Z0); Lo[1] := Pt(X1, Y0, Z0);
  Lo[2] := Pt(X1, Y1, Z0); Lo[3] := Pt(X0, Y1, Z0);
  Hi[0] := Pt(X0, Y0, Z1); Hi[1] := Pt(X1, Y0, Z1);
  Hi[2] := Pt(X1, Y1, Z1); Hi[3] := Pt(X0, Y1, Z1);
  Tube(Lo, Hi, Mat, EdgeW);
end;

{ The handle, leaning back out of the head: a many-sided prism swept from a
  point on the top of the block along a direction tilted by LEAN. }
procedure Handle(BaseX, BaseY, BaseZ, Len, Rad: Double; Mat: TColor);
var
  I: Integer;
  Ang, S, C: Double;
  Dir, Up, Side: TP3;
  Lo, Hi: array of TP3;
begin
  { lean back in Y, up in Z }
  S := Sin(DegToRad(LEAN));
  C := Cos(DegToRad(LEAN));
  Dir := P3(0, -S, C);
  Side := P3(1, 0, 0);
  Up := P3(0, C, S);          { across the handle, square to Dir and Side }

  SetLength(Lo, HANDLE_N);
  SetLength(Hi, HANDLE_N);
  for I := 0 to HANDLE_N - 1 do
  begin
    Ang := 2 * Pi * I / HANDLE_N;
    Lo[I] := Pt(BaseX + Rad * Cos(Ang) * Side.X + Rad * Sin(Ang) * Up.X,
                BaseY + Rad * Cos(Ang) * Side.Y + Rad * Sin(Ang) * Up.Y,
                BaseZ + Rad * Cos(Ang) * Side.Z + Rad * Sin(Ang) * Up.Z);
    Hi[I] := Pt(BaseX + Rad * Cos(Ang) * Side.X + Rad * Sin(Ang) * Up.X + Len * Dir.X,
                BaseY + Rad * Cos(Ang) * Side.Y + Rad * Sin(Ang) * Up.Y + Len * Dir.Y,
                BaseZ + Rad * Cos(Ang) * Side.Z + Rad * Sin(Ang) * Up.Z + Len * Dir.Z);
  end;
  Tube(Lo, Hi, Mat, 1.0);
end;

{ One bristle: square in section, rooted in the underside of the block and
  splayed out and down to its tip. }
procedure Bristle(RootX, RootY, RootZ, TipX, TipY, TipZ, W: Double;
  Mat: TColor);
var
  Lo, Hi: array[0..3] of TP3;
  T: Double;
begin
  T := W * 0.72;              { tips a little finer than the roots }
  Hi[0] := Pt(RootX - W, RootY - W, RootZ); Hi[1] := Pt(RootX + W, RootY - W, RootZ);
  Hi[2] := Pt(RootX + W, RootY + W, RootZ); Hi[3] := Pt(RootX - W, RootY + W, RootZ);
  Lo[0] := Pt(TipX - T, TipY - T, TipZ);    Lo[1] := Pt(TipX + T, TipY - T, TipZ);
  Lo[2] := Pt(TipX + T, TipY + T, TipZ);    Lo[3] := Pt(TipX - T, TipY + T, TipZ);
  Tube(Lo, Hi, Mat, 0);
end;

var
  R, C2, I: Integer;
  J1: Int64;
  X, Y, RootZ, TipZ, TX, TY, Frac, Wob, Wob2: Double;
  L, Out_, U: TStringList;
  Band: Integer;
  BLo, BHi, CamMid: TP3;
  CamV: TProjector;
  CamP: TPointF;
  BaseP, Diag, CamZoom: Double;
begin
  CWood    := RGBToColor(198, 154,  96);
  CFerrule := RGBToColor(168, 174, 182);
  CHead    := RGBToColor( 28,  86, 150);
  CCap     := RGBToColor( 18,  58, 108);
  CBand    := RGBToColor(206,  66,  52);
  CBris[0] := RGBToColor(232, 186,  78);   { straw }
  CBris[1] := RGBToColor( 52,  58,  68);   { near black }
  CBris[2] := RGBToColor(212,  78,  58);   { red }
  CBris[3] := RGBToColor(232, 186,  78);   { straw again }

  D := TWorkDoc.Create;
  L := TStringList.Create;
  Out_ := TStringList.Create;
  try
    { --- the head block, and a cap band round the top of it ------------- }
    Box(-HEAD_W / 2, -HEAD_D / 2, HEAD_Z,
         HEAD_W / 2,  HEAD_D / 2, HEAD_Z + HEAD_H, CHead, 1.4);
    Box(-HEAD_W / 2 - 0.12, -HEAD_D / 2 - 0.12, HEAD_Z + HEAD_H,
         HEAD_W / 2 + 0.12,  HEAD_D / 2 + 0.12, HEAD_Z + HEAD_H + 0.45,
        CCap, 1.2);
    { a stripe across the front of the block, because a shop broom has one }
    Box(-HEAD_W / 2 - 0.02, -HEAD_D / 2 - 0.14, HEAD_Z + 0.55,
         HEAD_W / 2 + 0.02, -HEAD_D / 2 - 0.02, HEAD_Z + 1.15, CBand, 0.9);

    { --- the socket the handle screws into, and its ferrule ------------- }
    Box(-1.15, -0.55, HEAD_Z + HEAD_H + 0.45,
         1.15,  0.55, HEAD_Z + HEAD_H + 1.7, CCap, 1.2);
    Handle(0, 0.18, HEAD_Z + HEAD_H + 1.5, FERRULE_L, FERRULE_R, CFerrule);

    { --- the handle ----------------------------------------------------- }
    Handle(0, 0.18, HEAD_Z + HEAD_H + 1.5, HANDLE_L, HANDLE_R, CWood);
    { a grip band two thirds of the way up, and a cap on the end }
    Handle(0, 0.18 - Sin(DegToRad(LEAN)) * HANDLE_L * 0.64,
           HEAD_Z + HEAD_H + 1.5 + Cos(DegToRad(LEAN)) * HANDLE_L * 0.64,
           4.5, HANDLE_R + 0.09, CBand);
    Handle(0, 0.18 - Sin(DegToRad(LEAN)) * (HANDLE_L - 0.6),
           HEAD_Z + HEAD_H + 1.5 + Cos(DegToRad(LEAN)) * (HANDLE_L - 0.6),
           0.75, HANDLE_R + 0.05, CFerrule);

    { --- the bristles ---------------------------------------------------
          Rooted in the underside of the block, splayed out and down.  The
          block is cut on a slant, so a bristle's tip height depends on where
          across the head it sits - which is what makes it an angle broom and
          what lets it get into a corner. }
    for R := 0 to BRIS_ROWS - 1 do
      for C2 := 0 to BRIS_COLS - 1 do
      begin
        Frac := C2 / (BRIS_COLS - 1);
        X := -HEAD_W / 2 + 0.35 + Frac * (HEAD_W - 0.7);
        Y := -HEAD_D / 2 + 0.32 + R * ((HEAD_D - 0.64) / (BRIS_ROWS - 1));
        RootZ := HEAD_Z + 0.05;
        TipZ := SLANT * Frac;          { the slant across the head }
        TX := X * FLARE_X;
        TY := Y * FLARE_Y;

        { A swept floor has never met a broom whose bristles were all the
          same length and all dead straight, and a model of one reads as a
          comb.  So each gets a little of its own: a shorter or longer tip,
          and a nudge sideways.  Deterministic - the same broom comes out of
          here every time - but with no pattern the eye can pick up. }
        J1 := (Int64(C2 + 7) * 73856093) xor (Int64(R + 3) * 19349663);
        Wob := ((J1 shr 5) and 1023) / 1023 - 0.5;
        J1 := (Int64(C2 + 11) * 83492791) xor (Int64(R + 5) * 1274126177);
        Wob2 := ((J1 shr 9) and 1023) / 1023 - 0.5;
        TipZ := TipZ + Wob * 0.55;
        if TipZ < 0 then TipZ := 0;
        TX := TX + Wob2 * 0.22;
        TY := TY + Wob * 0.18;

        { broad bands across the head, the way a shop broom is made up }
        Band := (C2 * 4) div BRIS_COLS;
        if Band > 3 then Band := 3;
        Bristle(X, Y, RootZ, TX, TY, TipZ, BRIS_W, CBris[Band]);
      end;

    { --- out it goes ---------------------------------------------------
          The camera is worked out from what was built rather than typed in,
          the way the glass does it, so the drawing opens framed however the
          broom's proportions end up. }
    BaseP := PixelsPerUnit(usImperial, ScaleTable(usImperial, 2), 96);
    D.Bounds(BLo, BHi);
    CamMid := P3((BLo.X + BHi.X) / 2, (BLo.Y + BHi.Y) / 2, (BLo.Z + BHi.Z) / 2);
    Diag := Sqrt(Sqr(BHi.X - BLo.X) + Sqr(BHi.Y - BLo.Y) + Sqr(BHi.Z - BLo.Z));
    CamZoom := Min((ART_W * 0.74) / (Diag * BaseP), (ART_H * 0.74) / (Diag * BaseP));
    CamV.Kind := vkOrbit;
    CamV.Az := -0.907571;
    CamV.El := 0.430000;   { low enough to look along the bristles rather
                             than down onto the head }
    CamV.Ppu := BaseP * CamZoom;
    CamV.OX := 0;
    CamV.OY := 0;
    CamP := Project(CamV, CamMid);

    Out_.Add('HECKERS-SKETCH 1');
    Out_.Add('SHEET Broom');
    Out_.Add('UNITS 0');
    Out_.Add('SCALE 2');
    Out_.Add('SNAP 1');
    Out_.Add('VIEW 2');
    Out_.Add(StringReplace(Format('CAMERA %.6f %.6f %.6f %.3f %.3f',
      [CamV.Az, CamV.El, CamZoom, ART_W / 2 - CamP.X, ART_H / 2 - CamP.Y]),
      DefaultFormatSettings.DecimalSeparator, '.', [rfReplaceAll]));
    D.SaveTo(Out_);
    Out_.Add('ENDSHEET');
    Out_.SaveToFile('broom.hsk');

    { and the same thing as a unit, so the program carries it }
    U := TStringList.Create;
    U.Add('unit uExBroom;');
    U.Add('');
    U.Add('{ The kitchen broom example.');
    U.Add('');
    U.Add('  Generated by examples/make-broom.pas - do not edit this by hand,');
    U.Add('  edit that and run it again.  It is the same drawing as');
    U.Add('  examples/broom.hsk, carried inside the program so that a');
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
    U.Add('{ The kitchen broom, as the lines of a .hsk file. }');
    U.Add('procedure BroomDrawing(L: TStrings);');
    U.Add('');
    U.Add('implementation');
    U.Add('');
    U.Add('procedure BroomDrawing(L: TStrings);');
    U.Add('begin');
    for I := 0 to Out_.Count - 1 do
      U.Add('  L.Add(' + QuotedStr(Out_[I]) + ');');
    U.Add('end;');
    U.Add('');
    U.Add('end.');
    U.SaveToFile('../uExBroom.pas');
    U.Free;

    I := 0;
    for R := 0 to D.Live - 1 do if D[R].Kind = ekFace then Inc(I);
    WriteLn(Format('%d things, %d faces, %d bristles -> broom.hsk and ' +
      'uExBroom.pas (%d lines)',
      [D.Live, I, BRIS_ROWS * BRIS_COLS, Out_.Count]));
  finally
    Out_.Free; L.Free; D.Free;
  end;
end.
