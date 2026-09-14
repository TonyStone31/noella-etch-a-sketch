program makeetchasketch;

{ The house model.

  A toy etch-a-sketch, near enough to the real thing's size: twelve inches by
  nine by an inch and a quarter, a recessed grey screen, two white knobs in
  the bottom corners, and a block robot drawn on the screen in stylus lines.

  It exists to be the drawing in every help picture.  One model across all of
  them means somebody reading about the line tool and somebody reading about
  push/pull are looking at the same object from two angles, which is one less
  thing to work out each time.  And it has a job in the pictures beyond
  sitting there: the robot is LINES, not faces, exactly as a real
  etch-a-sketch drawing is - so the push/pull page can click one of its
  squares, let the region finder make a face of it, and lift the robot's head
  off the screen.

  Everything is written in inches and divided by twelve on the way out,
  because the drawing's unit is the foot and nobody thinks about a toy in
  feet.

  Run it to write examples/etch-a-sketch.hsk:
      fpc -Fu.. make-etch-a-sketch.pas && ./makeetchasketch

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE.
}

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Math, Types, Graphics, uSurface, uWork;

const
  { the toy, in inches }
  BW = 12.0;      BH = 9.0;      BT = 1.25;     { body: wide, high, thick }
  SX0 = 1.5;      SX1 = 10.5;                   { the screen opening }
  SY0 = 2.25;     SY1 = 7.75;
  RECESS = 0.12;                                { how far the screen sits in }
  KNOB_R = 0.625; KNOB_H = 0.42;                { the knobs }
  KNOB_Y = 1.125;
  KNOB_X0 = 2.25; KNOB_X1 = 9.75;
  KNOB_SIDES = 20;

  { TColor is $00BBGGRR }
  RED   = $002030C8;    { the toy's red }
  GREY  = $00B8B4AE;    { the screen }
  WHITE = $00E8ECEE;    { the knobs }
  INK   = $00201C1A;    { the stylus line }

var
  D: TWorkDoc;
  L: TStringList;
  Grp: Integer;

{ inches to the drawing's unit }
function I_(V: Double): Double;
begin
  Result := V / 12;
end;

{ Centred on the origin left to right and front to back, and sitting on it
  the way a toy sits on a table.  The axes then run through the middle of the
  thing rather than off one corner, which is what you want in a picture. }
function P(X, Y, Z: Double): TP3;
begin
  Result := P3(I_(X - BW / 2), I_(Y - BH / 2), I_(Z));
end;

{ A face, wound as given, belonging to this solid. }
procedure Face(const Pts: array of TP3; Ink: TColor);
begin
  D.AddFaceRaw(Pts, Ink, True);
  D.SetFaceGroup(D.Live - 1, Grp);
end;

{ A flat rectangle at height Z, seen from above.  Up says which way its
  normal points, so the same call makes a lid or a floor. }
procedure Flat(X0, Y0, X1, Y1, Z: Double; Ink: TColor; Up: Boolean);
begin
  if Up then
    Face([P(X0, Y0, Z), P(X1, Y0, Z), P(X1, Y1, Z), P(X0, Y1, Z)], Ink)
  else
    Face([P(X0, Y0, Z), P(X0, Y1, Z), P(X1, Y1, Z), P(X1, Y0, Z)], Ink);
end;

{ An upright wall between two points, from Z0 up to Z1.  Wound so its normal
  is to the left of the direction of travel, which is the rule that lets a
  loop of walls come out consistently. }
procedure Wall(X0, Y0, X1, Y1, Z0, Z1: Double; Ink: TColor);
begin
  Face([P(X0, Y0, Z0), P(X1, Y1, Z0), P(X1, Y1, Z1), P(X0, Y0, Z1)], Ink);
end;

{ A line of the drawing on the screen. }
procedure Stroke(X0, Y0, X1, Y1: Double);
begin
  D.AddLine(P(X0, Y0, BT - RECESS), P(X1, Y1, BT - RECESS), INK, 1.0, False);
end;

{ A box drawn in stylus lines, which is all the robot is made of. }
procedure BoxLine(X0, Y0, X1, Y1: Double);
begin
  Stroke(X0, Y0, X1, Y0);
  Stroke(X1, Y0, X1, Y1);
  Stroke(X1, Y1, X0, Y1);
  Stroke(X0, Y1, X0, Y0);
end;

{ One knob: a short cylinder sunk a little into the frame so no two faces
  land in the same place. }
procedure Knob(CX, CY: Double);
var
  I: Integer;
  A0, A1, Z0, Z1: Double;
  Top, Bot: array of TP3;
begin
  Inc(Grp);
  Z0 := BT - 0.06;
  Z1 := BT + KNOB_H;
  SetLength(Top, KNOB_SIDES);
  SetLength(Bot, KNOB_SIDES);
  for I := 0 to KNOB_SIDES - 1 do
  begin
    A0 := I * 2 * Pi / KNOB_SIDES;
    Top[I] := P(CX + KNOB_R * Cos(A0), CY + KNOB_R * Sin(A0), Z1);
    Bot[KNOB_SIDES - 1 - I] :=
      P(CX + KNOB_R * Cos(A0), CY + KNOB_R * Sin(A0), Z0);
  end;
  Face(Top, WHITE);                 { the lid, anticlockwise seen from above }
  Face(Bot, WHITE);                 { the underside, the other way round }
  for I := 0 to KNOB_SIDES - 1 do
  begin
    A0 := I * 2 * Pi / KNOB_SIDES;
    A1 := ((I + 1) mod KNOB_SIDES) * 2 * Pi / KNOB_SIDES;
    Wall(CX + KNOB_R * Cos(A0), CY + KNOB_R * Sin(A0),
         CX + KNOB_R * Cos(A1), CY + KNOB_R * Sin(A1), Z0, Z1, WHITE);
  end;
end;

var
  ZF: Double;
begin
  D := TWorkDoc.Create;
  L := TStringList.Create;
  ZF := BT - RECESS;
  Grp := 1;

  { --- the body ----------------------------------------------------- }
  Flat(0, 0, BW, BH, 0, RED, False);                  { underneath }

  { the frame around the screen, in four strips rather than one face with a
    hole in it - every edge is then an ordinary edge and the shape reads as
    closed, which a face with a hole does not }
  Flat(0, 0, BW, SY0, BT, RED, True);
  Flat(0, SY1, BW, BH, BT, RED, True);
  Flat(0, SY0, SX0, SY1, BT, RED, True);
  Flat(SX1, SY0, BW, SY1, BT, RED, True);

  { the four outside walls, anticlockwise seen from above }
  Wall(0, 0, BW, 0, 0, BT, RED);
  Wall(BW, 0, BW, BH, 0, BT, RED);
  Wall(BW, BH, 0, BH, 0, BT, RED);
  Wall(0, BH, 0, 0, 0, BT, RED);

  { the pocket the screen sits in: four walls going down, wound the other way
    round because the material is outside them }
  Wall(SX0, SY0, SX0, SY1, ZF, BT, RED);
  Wall(SX0, SY1, SX1, SY1, ZF, BT, RED);
  Wall(SX1, SY1, SX1, SY0, ZF, BT, RED);
  Wall(SX1, SY0, SX0, SY0, ZF, BT, RED);

  Flat(SX0, SY0, SX1, SY1, ZF, GREY, True);           { the screen }

  { --- the knobs ---------------------------------------------------- }
  Knob(KNOB_X0, KNOB_Y);
  Knob(KNOB_X1, KNOB_Y);

  { --- the robot, drawn on the screen -------------------------------- }
  BoxLine(5.2, 5.6, 6.8, 6.9);        { head }
  BoxLine(5.5, 6.1, 5.8, 6.4);        { left eye }
  BoxLine(6.2, 6.1, 6.5, 6.4);        { right eye }
  Stroke(5.6, 5.85, 6.4, 5.85);       { mouth }
  BoxLine(4.8, 3.4, 7.2, 5.6);        { body }
  BoxLine(3.6, 4.4, 4.8, 5.0);        { left arm }
  BoxLine(7.2, 4.4, 8.4, 5.0);        { right arm }
  BoxLine(5.2, 2.6, 5.9, 3.4);        { left leg }
  BoxLine(6.1, 2.6, 6.8, 3.4);        { right leg }

  { --- and out ------------------------------------------------------ }
  L.Add('HECKERS-SKETCH 1');
  L.Add('SHEET Etch a Sketch');
  L.Add('UNITS 0');
  { the biggest scale there is - 1" = 1'-0" - because this is a toy and not
    a building, and a snap of a sixteenth to match }
  L.Add('SCALE 4');
  L.Add('SNAP 1');
  L.Add('VIEW 2');
  { looking down on it from the front left, which is how you would pick one
    up off a table }
  L.Add('CAMERA -0.785398 0.700000 1.000000 0.000 0.000');
  D.SaveTo(L);
  L.Add('ENDSHEET');
  L.SaveToFile('etch-a-sketch.hsk');
  WriteLn(Format('%d things -> etch-a-sketch.hsk', [D.Live]));
end.
