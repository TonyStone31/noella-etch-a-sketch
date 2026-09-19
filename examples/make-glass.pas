program makeglass;

{ The wine glass.

  The second example, and the one that explains Revolve.  It is built the way
  a person would build it: draw the outline of half of it, seen edge on, and
  spin that round the blue axis.  Nothing here reaches into the document to
  place a face by hand - it draws a profile and calls TWorkDoc.Revolve, which
  is the same code the tool calls.  That is the point of keeping it: if the
  tool changes, this changes with it, and the picture in the help stays true.

  The outline goes up the outside, over the rim, back down the inside and in
  to the axis at the bottom of the bowl, then straight down the axis to where
  it started.  What that encloses is the glass itself - the material - so the
  bowl comes out hollow, the stem solid, and the whole thing closed.  A glass
  drawn as a single skin looks the same on screen and is not a thing that can
  be printed.

  Everything is in inches and divided by twelve on the way out, because the
  drawing's unit is the foot and nobody thinks about a glass in feet.

  Run it to write examples/wine-glass.hsk and ../uExGlass.pas:
      cd examples
      fpc -Mobjfpc -Sh -Fu.. make-glass.pas && ./makeglass

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE.
}

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Math, Types, Graphics, uSurface, uWork;

const
  { The glass, in inches.  A red wine glass off the shelf rather than a shape
    that looked right: eight and a half tall, a bowl three and a half across,
    a foot a shade over three.  The whole argument for this program is that
    things in it are the size they say they are, and an example that is not
    is an example teaching the wrong lesson. }
  FOOT_R  = 1.60;   FOOT_T  = 0.12;    { the foot, and how thick its edge is }
  STEM_R  = 0.17;   STEM_TOP = 3.45;   { the stem }
  STEM_BOT = 0.95;
  BOWL_BOT = 4.05;  BOWL_R0 = 0.46;    { where the bowl leaves the stem }
  RIM_Z   = 8.50;   RIM_R   = 1.42;    { the rim, outside }
  WALL    = 0.13;   { how thick the glass is }
  BOWL_N  = 8;      { points down each side of the bowl }

  SIDES = 24;              { pieces round - smooth enough, and not a huge file }

  { the drawing area of a window somebody would actually open, for working
    out where the camera should stand }
  ART_W = 1280;
  ART_H = 720;

  { TColor is $00BBGGRR }
  GLASS = $00E0D8C8;       { a pale cold gray, which is what glass reads as }

var
  D: TWorkDoc;
  L, U: TStringList;
  Pts: TP3Array;
  NP: Integer;
  I, Face, First, NFace, Grp: Integer;
  BaseP, Diag, CamZoom: Double;
  BLo, BHi, CamMid: TP3;
  CamV: TProjector;
  CamP: TPointF;

{ inches to the drawing's unit }
function I_(V: Double): Double;
begin
  Result := V / 12;
end;

{ Put a point on the end of the outline, in inches.

  Revolve softens the ring a profile vertex sweeps when the outline only
  bends a little there - under thirty degrees - and leaves it hard where
  there is a real corner.  That is what tells a curved bowl from a foot with
  an edge on it, and it is why the bowl is a curve of ten points rather than
  three: with three, every joint is a corner and the glass comes out banded
  like a barrel. }
procedure Put(R, Z: Double);
begin
  if NP >= Length(Pts) then SetLength(Pts, Max(16, NP * 2));
  Pts[NP] := P3(I_(R), 0, I_(Z));
  Inc(NP);
end;

{ one point of a cubic Bezier, which is how both sides of the bowl are
  drawn - a shape with no corners in it anywhere }
procedure Bez(R0, Z0, R1, Z1, R2, Z2, R3, Z3, T: Double);
var
  U, A, B, C, E: Double;
begin
  U := 1 - T;
  A := U * U * U;
  B := 3 * U * U * T;
  C := 3 * U * T * T;
  E := T * T * T;
  Put(A * R0 + B * R1 + C * R2 + E * R3,
      A * Z0 + B * Z1 + C * Z2 + E * Z3);
end;

begin
  D := TWorkDoc.Create;
  L := TStringList.Create;

  { --- the outline, in the XZ plane, standing on the ground -----------

    Up the outside, over the rim, back down the inside, in to the axis at
    the bottom of the bowl, and then straight down the axis to where it
    started.  What that encloses is the material: the bowl comes out hollow,
    the stem solid, and the whole thing closed. }
  NP := 0;
  SetLength(Pts, 64);

  Put(0.00, 0.00);                        { the middle of the underside }
  Put(FOOT_R - 0.05, 0.00);               { out along the foot }
  Put(FOOT_R, FOOT_T);                    { the edge of it }
  Put(0.34, 0.40);                        { back in, over the top of the foot }
  Put(STEM_R, STEM_BOT);                  { into the stem }
  Put(STEM_R, STEM_TOP);                  { up the stem }

  { the outside of the bowl, leaving the stem and swelling to the rim }
  for I := 0 to BOWL_N do
    Bez(BOWL_R0, BOWL_BOT, 1.66, 4.55, 2.06, 6.95, RIM_R, RIM_Z,
        I / BOWL_N);

  { over the rim and back down the inside, the same curve held in by the
    thickness of the glass }
  for I := 0 to BOWL_N do
    Bez(RIM_R - WALL, RIM_Z - 0.10, 1.92, 6.90, 1.52, 4.60, 0.33, 4.18,
        I / BOWL_N);

  Put(0.00, 3.92);                        { the bottom of the bowl, on the axis }

  SetLength(Pts, NP);
  D.AddFaceRaw(Pts, GLASS, False);
  Face := D.Live - 1;

  { The axis has to run down one side of the outline and not through it.
    Asking first is what the tool does, and getting the answer wrong here
    would make a glass that sweeps into itself - so it is asked, and the
    program stops rather than writing a wreck. }
  if D.AxisSplitsFace(Face, P3(0, 0, 0), P3(0, 0, 1), Diag, CamZoom) then
  begin
    WriteLn('the blue axis splits the outline - the profile is wrong');
    Halt(1);
  end;

  { --- spin it -------------------------------------------------------- }
  First := D.Revolve(Face, P3(0, 0, 0), P3(0, 0, 1), 2 * Pi, SIDES);
  if First < 0 then
  begin
    WriteLn('the revolve was refused');
    Halt(1);
  end;

  NFace := 0;
  Grp := 0;
  for I := 0 to D.Live - 1 do
    if D[I].Kind = ekFace then
    begin
      Inc(NFace);
      if D[I].Grp <> 0 then Grp := D[I].Grp;
    end;

  WriteLn(Format('%d faces, group %d, closed=%s',
    [NFace, Grp, BoolToStr(D.GroupClosed(Grp), True)]));
  if not D.GroupClosed(Grp) then
  begin
    WriteLn('it did not come out closed - that is a model nobody can print');
    Halt(1);
  end;

  { --- and out -------------------------------------------------------- }
  { the same three lines the program writes when it puts this beside itself,
    so the file it writes and the file in the repository are the same bytes }
  L.Add('# Written out by Heckers Sketch every time it starts, over the top');
  L.Add('# of whatever was here.  Draw on it all you like - to keep what you');
  L.Add('# have done, save it under a name of your own.');
  L.Add('HECKERS-SKETCH 1');
  L.Add('SHEET Wine Glass');
  L.Add('UNITS 0');
  { 1" = 1'-0", the biggest scale there is, because this is a glass and not
    a building - and a sixteenth of an inch to snap to }
  L.Add('SCALE 4');
  L.Add('SNAP 1');
  L.Add('VIEW 2');

  { Where the camera stands, worked out the way the Fit button works it out.
    Written rather than guessed because a pan of nought puts the origin in
    the corner of the view and the drawing away off to one side. }
  BaseP := PixelsPerUnit(usImperial, ScaleTable(usImperial, 4), 96);
  D.Bounds(BLo, BHi);
  CamMid := P3((BLo.X + BHi.X) / 2, (BLo.Y + BHi.Y) / 2, (BLo.Z + BHi.Z) / 2);
  Diag := Sqrt(Sqr(BHi.X - BLo.X) + Sqr(BHi.Y - BLo.Y) + Sqr(BHi.Z - BLo.Z));
  { a little more room round it than the toy gets: a glass is tall and thin,
    and the diagonal of a tall thin thing leaves it filling the height }
  CamZoom := Min((ART_W * 0.72) / (Diag * BaseP), (ART_H * 0.72) / (Diag * BaseP));
  CamV.Kind := vkOrbit;
  CamV.Az := -0.785398;
  CamV.El := 0.450000;    { lower than the toy: a glass is read from nearer
                            its own height than from above, but high enough
                            to see that the foot and the rim are round }
  CamV.Ppu := BaseP * CamZoom;
  CamV.OX := 0;
  CamV.OY := 0;
  CamP := Project(CamV, CamMid);
  L.Add(StringReplace(Format('CAMERA %.6f %.6f %.6f %.3f %.3f',
    [CamV.Az, CamV.El, CamZoom, ART_W / 2 - CamP.X, ART_H / 2 - CamP.Y]),
    DefaultFormatSettings.DecimalSeparator, '.', [rfReplaceAll]));
  D.SaveTo(L);
  L.Add('ENDSHEET');
  L.SaveToFile('wine-glass.hsk');

  { and the same thing as a unit, so the program carries it }
  U := TStringList.Create;
  U.Add('unit uExGlass;');
  U.Add('');
  U.Add('{ The wine glass example.');
  U.Add('');
  U.Add('  Generated by examples/make-glass.pas - do not edit this by hand,');
  U.Add('  edit that and run it again.  It is the same drawing as');
  U.Add('  examples/wine-glass.hsk, carried inside the program so that a');
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
  U.Add('{ The wine glass, as the lines of a .hsk file. }');
  U.Add('procedure GlassDrawing(L: TStrings);');
  U.Add('');
  U.Add('implementation');
  U.Add('');
  U.Add('procedure GlassDrawing(L: TStrings);');
  U.Add('begin');
  for I := 0 to L.Count - 1 do
    U.Add('  L.Add(' + QuotedStr(L[I]) + ');');
  U.Add('end;');
  U.Add('');
  U.Add('end.');
  U.SaveToFile('../uExGlass.pas');
  U.Free;

  WriteLn(Format('%d things -> wine-glass.hsk and uExGlass.pas (%d lines)',
    [D.Live, L.Count]));
end.
