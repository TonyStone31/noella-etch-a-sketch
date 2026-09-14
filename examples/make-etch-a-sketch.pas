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
  BR = 0.70;      SR = 0.30;                    { the rounding on each }
  ROUND_STEPS = 7;                              { pieces per quarter turn }
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

{ A rounded rectangle, anticlockwise seen from above, at height Z.

  The corners are the whole point of it: a real toy has no sharp edge on it
  anywhere, and a box with square corners reads as a box rather than as a
  thing somebody would hand a child. }
function RoundRect(X0, Y0, X1, Y1, R, Z: Double): TP3Array;
var
  C, I, N: Integer;
  A, CX, CY, A0: Double;
begin
  R := Min(R, Min((X1 - X0) / 2, (Y1 - Y0) / 2));
  N := 0;
  SetLength(Result, 4 * (ROUND_STEPS + 1));
  for C := 0 to 3 do
  begin
    { anticlockwise from the bottom right, so the whole ring is anticlockwise }
    case C of
      0: begin CX := X1 - R; CY := Y0 + R; A0 := -Pi / 2; end;
      1: begin CX := X1 - R; CY := Y1 - R; A0 := 0;       end;
      2: begin CX := X0 + R; CY := Y1 - R; A0 := Pi / 2;  end;
    else begin CX := X0 + R; CY := Y0 + R; A0 := Pi;      end;
    end;
    for I := 0 to ROUND_STEPS do
    begin
      A := A0 + (Pi / 2) * I / ROUND_STEPS;
      Result[N] := P(CX + R * Cos(A), CY + R * Sin(A), Z);
      Inc(N);
    end;
  end;
  SetLength(Result, N);
end;

{ The same ring the other way round, which is what a hole and an underside
  both want. }
function Reversed(const Pts: TP3Array): TP3Array;
var
  I: Integer;
begin
  SetLength(Result, Length(Pts));
  for I := 0 to High(Pts) do Result[I] := Pts[High(Pts) - I];
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

{ A wall all the way round a ring, from Z0 up to Z1.  Wound so the normal is
  to the right of the way round, which means an anticlockwise ring walls
  itself outwards and a clockwise one walls itself inwards - a body and a
  pocket from the same routine. }
procedure Skirt(const Ring: TP3Array; Z0, Z1: Double; Ink: TColor);
var
  I, N: Integer;
  A, B: TP3;
begin
  N := Length(Ring);
  for I := 0 to N - 1 do
  begin
    A := Ring[I];
    B := Ring[(I + 1) mod N];
    Face([P3(A.X, A.Y, I_(Z0)), P3(B.X, B.Y, I_(Z0)),
          P3(B.X, B.Y, I_(Z1)), P3(A.X, A.Y, I_(Z1))], Ink);
  end;
end;

{ An upright wall between two points, from Z0 up to Z1.  Wound so its normal
  is to the left of the direction of travel, which is the rule that lets a
  loop of walls come out consistently. }
procedure Wall(X0, Y0, X1, Y1, Z0, Z1: Double; Ink: TColor);
begin
  Face([P(X0, Y0, Z0), P(X1, Y1, Z0), P(X1, Y1, Z1), P(X0, Y0, Z1)], Ink);
end;

{ --- block capitals, drawn in lines -------------------------------------

  Only seven letters are needed - H E C K R S T spell HECKERS SKETCH between
  them - so this is not a font, it is seven shapes.

  Each is drawn in a box six wide and ten tall, out of bars two thick, and
  each bar is its own closed loop.  That is deliberate twice over.  A closed
  loop is a face waiting to happen, so every bar of every letter can be
  pushed up on its own - which is the demonstration the push/pull page wants.
  And where two bars meet they leave a line across the join, which is exactly
  what a real etch-a-sketch does, because a real one draws everything with
  one unbroken line and cannot lift the stylus. }

type
  TBar = array[0..7] of Double;     { x,y four times round; a quad }

{ One bar of a letter, placed and scaled.  OX and OY are where the letter's
  bottom left corner goes, S is how big the six-by-ten box is drawn. }
procedure Bar(const B: TBar; N: Integer; OX, OY, S, Z: Double);
var
  I: Integer;
  Pts: array of TP3;
begin
  SetLength(Pts, N);
  for I := 0 to N - 1 do
    Pts[I] := P(OX + B[I * 2] * S, OY + B[I * 2 + 1] * S, Z);
  for I := 0 to N - 1 do
    D.AddLine(Pts[I], Pts[(I + 1) mod N], INK, 1.0, False);
end;

{ An upright bar of a letter, given as a rectangle. }
procedure Rect_(X0, Y0, X1, Y1, OX, OY, S, Z: Double);
var
  B: TBar;
begin
  B[0] := X0; B[1] := Y0;
  B[2] := X1; B[3] := Y0;
  B[4] := X1; B[5] := Y1;
  B[6] := X0; B[7] := Y1;
  Bar(B, 4, OX, OY, S, Z);
end;

{ A leaning bar, for the legs of a K.  The two ends are horizontal, so it
  reads as a stroke of a pen rather than a lozenge. }
procedure Lean(AX0, AX1, AY, BX0, BX1, BY, OX, OY, S, Z: Double);
var
  B: TBar;
begin
  B[0] := AX0; B[1] := AY;
  B[2] := AX1; B[3] := AY;
  B[4] := BX1; B[5] := BY;
  B[6] := BX0; B[7] := BY;
  Bar(B, 4, OX, OY, S, Z);
end;

{ One letter.  Returns how wide it was, so the caller can walk along. }
function Letter(C: Char; OX, OY, S, Z: Double): Double;
begin
  Result := 6 * S;
  case C of
    'H': begin
           Rect_(0, 0, 2, 10, OX, OY, S, Z);
           Rect_(4, 0, 6, 10, OX, OY, S, Z);
           Rect_(2, 4, 4, 6, OX, OY, S, Z);
         end;
    'E': begin
           Rect_(0, 0, 2, 10, OX, OY, S, Z);
           Rect_(2, 0, 6, 2, OX, OY, S, Z);
           Rect_(2, 4, 5, 6, OX, OY, S, Z);
           Rect_(2, 8, 6, 10, OX, OY, S, Z);
         end;
    'C': begin
           Rect_(0, 0, 2, 10, OX, OY, S, Z);
           Rect_(2, 0, 6, 2, OX, OY, S, Z);
           Rect_(2, 8, 6, 10, OX, OY, S, Z);
         end;
    'K': begin
           Rect_(0, 0, 2, 10, OX, OY, S, Z);
           Lean(2, 4, 5, 4, 6, 10, OX, OY, S, Z);
           Lean(2, 4, 5, 4, 6, 0, OX, OY, S, Z);
         end;
    'R': begin
           Rect_(0, 0, 2, 10, OX, OY, S, Z);
           Rect_(2, 8, 6, 10, OX, OY, S, Z);
           Rect_(4, 6, 6, 8, OX, OY, S, Z);
           Rect_(2, 4, 6, 6, OX, OY, S, Z);
           Lean(3, 5, 4, 4, 6, 0, OX, OY, S, Z);
         end;
    'S': begin
           Rect_(0, 8, 6, 10, OX, OY, S, Z);
           Rect_(0, 6, 2, 8, OX, OY, S, Z);
           Rect_(0, 4, 6, 6, OX, OY, S, Z);
           Rect_(4, 2, 6, 4, OX, OY, S, Z);
           Rect_(0, 0, 6, 2, OX, OY, S, Z);
         end;
    'T': begin
           Rect_(0, 8, 6, 10, OX, OY, S, Z);
           Rect_(2, 0, 4, 8, OX, OY, S, Z);
         end;
    ' ': Result := 3 * S;
  end;
end;

{ A word, centred on CX. }
procedure Word_(const W: string; CX, OY, S, Z: Double);
var
  I: Integer;
  Wide, X: Double;
begin
  Wide := 0;
  for I := 1 to Length(W) do
  begin
    if W[I] = ' ' then Wide := Wide + 3 * S else Wide := Wide + 6 * S;
    if I < Length(W) then Wide := Wide + S;
  end;
  X := CX - Wide / 2;
  for I := 1 to Length(W) do
    X := X + Letter(W[I], X, OY, S, Z) + S;
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
  I: Integer;
  U: TStringList;
  Outer, Screen: TP3Array;
  Holes: array of TP3Array;
begin
  D := TWorkDoc.Create;
  L := TStringList.Create;
  ZF := BT - RECESS;
  Grp := 1;

  { --- the body ----------------------------------------------------- }
  Outer := RoundRect(0, 0, BW, BH, BR, BT);
  Screen := RoundRect(SX0, SY0, SX1, SY1, SR, BT);

  { underneath: the same ring the other way about, so it looks down }
  Face(Reversed(RoundRect(0, 0, BW, BH, BR, 0)), RED);

  { the top, in one piece with the screen opening cut out of it.  It reads as
    a closed solid because GroupClosed counts a hole's edge as the boundary
    it is - which it did not until this model asked it to. }
  D.AddFaceRaw(Outer, RED, True);
  D.SetFaceGroup(D.Live - 1, Grp);
  SetLength(Holes, 1);
  Holes[0] := Reversed(Screen);
  D.SetFaceHoles(D.Live - 1, Holes);

  Skirt(Outer, 0, BT, RED);                    { the outside, walling out }
  Skirt(Reversed(Screen), ZF, BT, RED);        { the pocket, walling in }
  Face(RoundRect(SX0, SY0, SX1, SY1, SR, ZF), GREY);   { the screen }

  { --- the knobs ---------------------------------------------------- }
  Knob(KNOB_X0, KNOB_Y);
  Knob(KNOB_X1, KNOB_Y);

  { --- the logo on the top edge, in the toy's own lines ---------------- }
  Word_('HECKERS SKETCH', BW / 2, 8.05, 0.075, BT);

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
  { the same three lines the program writes when it puts this beside itself,
    so the file it writes and the file in the repository are the same bytes }
  L.Add('# Written out by Heckers Sketch every time it starts, over the top');
  L.Add('# of whatever was here.  Draw on it all you like - to keep what you');
  L.Add('# have done, save it under a name of your own.');
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

  { And the same thing as a unit, so the program carries it without needing a
    file beside it.  A portable build is one executable and nothing else; an
    example drawing that only exists as a file on disk is an example most
    people would never see. }
  U := TStringList.Create;
  U.Add('unit uExample;');
  U.Add('');
  U.Add('{ The drawing somebody sees the first time they run this.');
  U.Add('');
  U.Add('  Generated by examples/make-etch-a-sketch.pas - do not edit this by');
  U.Add('  hand, edit that and run it again.  It is the same toy etch-a-sketch');
  U.Add('  as examples/etch-a-sketch.hsk, carried inside the program so that a');
  U.Add('  portable build is still one file and nothing else.');
  U.Add('');
  U.Add('  Why have one at all: an empty sheet tells somebody nothing about');
  U.Add('  what this is for, and the first thing most people do with a drawing');
  U.Add('  program is look for something to click.  A toy with a robot on it');
  U.Add('  answers both - and every one of its faces is something to push. }');
  U.Add('');
  U.Add('{$mode objfpc}{$H+}');
  U.Add('');
  U.Add('interface');
  U.Add('');
  U.Add('uses');
  U.Add('  Classes;');
  U.Add('');
  U.Add('{ The example drawing, as the lines of a .hsk file. }');
  U.Add('procedure ExampleDrawing(L: TStrings);');
  U.Add('');
  U.Add('implementation');
  U.Add('');
  U.Add('procedure ExampleDrawing(L: TStrings);');
  U.Add('begin');
  for I := 0 to L.Count - 1 do
    U.Add('  L.Add(' + QuotedStr(L[I]) + ');');
  U.Add('end;');
  U.Add('');
  U.Add('end.');
  U.SaveToFile('../uExample.pas');
  U.Free;

  WriteLn(Format('%d things -> etch-a-sketch.hsk and uExample.pas (%d lines)',
    [D.Live, L.Count]));
end.
