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
  { the body is the first solid; the knobs take the numbers after it, so
    anything added later has to name this rather than trust a counter }
  BODY = 1;
  { the drawing area of a window somebody would actually open - only used to
    work out where the camera should stand when the file is written }
  ART_W = 1280;
  ART_H = 720;

  { TColor is $00BBGGRR }
  RED   = $002030C8;    { the toy's red }
  GREY  = $00B8B4AE;    { the screen }
  WHITE = $00E8ECEE;    { the knobs }
  INK   = $00201C1A;    { the stylus line }

var
  D: TWorkDoc;
  L: TStringList;
  Grp: Integer;
  { every closed loop drawn on a flat face, in the order it was drawn }
  Drawn: array of TP3Array;

{ inches to the drawing's unit }
function I_(V: Double): Double;
begin
  Result := V / 12;
end;

{ The near bottom left corner sits on the origin, so the whole toy lies in the
  quarter where all three axes are solid rather than dashed.

  Centred on zero was tried first and looks tidier in a picture, but it puts
  half the drawing behind the dashed halves of the axes - the halves that mean
  "the other way" - and that is a strange place to keep a thing you are
  measuring.  Everything here reads positive: nine inches along is nine
  inches, not minus four and a half. }
function P(X, Y, Z: Double): TP3;
begin
  Result := P3(I_(X), I_(Y), I_(Z));
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

{ One closed loop, placed and scaled: x,y,x,y... round the outside of a
  letter.  OX and OY are where the letter's bottom left corner goes and S is
  how big the six-by-ten box is drawn. }
procedure Loop(const XY: array of Double; OX, OY, S, Z: Double);
var
  I, N: Integer;
  Pts: TP3Array;
begin
  N := Length(XY) div 2;
  SetLength(Pts, N);
  for I := 0 to N - 1 do
    Pts[I] := P(OX + XY[I * 2] * S, OY + XY[I * 2 + 1] * S, Z);
  for I := 0 to N - 1 do
    D.AddLine(Pts[I], Pts[(I + 1) mod N], INK, 1.0, False);
  { kept as well as drawn.  A loop of lines is only a face once somebody has
    worked the faces out, and a drawing read from a file does not get that
    done to it - see the note by the faces at the bottom - so the faces go in
    the file too. }
  SetLength(Drawn, Length(Drawn) + 1);
  Drawn[High(Drawn)] := Pts;
end;

{ One letter.  Returns how wide it was, so the caller can walk along.

  Each letter is ONE loop round the outside of it, not a pile of bars.  Bars
  were easier to write and left a line across every join, so pushing an H up
  meant pushing three pieces and getting a letter with seams down it.  A
  single outline is a single face: click it once, push it once, and the whole
  letter stands up.  R is the only one that needs a second loop, for the hole
  in its bowl - and a face with a hole in it extrudes with the hole, the same
  as a wall with a window. }
function Letter(C: Char; OX, OY, S, Z: Double): Double;
begin
  Result := 6 * S;
  case C of
    'H': Loop([0,0, 2,0, 2,4, 4,4, 4,0, 6,0,
               6,10, 4,10, 4,6, 2,6, 2,10, 0,10], OX, OY, S, Z);
    'E': Loop([0,0, 6,0, 6,2, 2,2, 2,4, 5,4,
               5,6, 2,6, 2,8, 6,8, 6,10, 0,10], OX, OY, S, Z);
    'C': Loop([0,0, 6,0, 6,2, 2,2, 2,8, 6,8, 6,10, 0,10], OX, OY, S, Z);
    'T': Loop([2,0, 4,0, 4,8, 6,8, 6,10, 0,10, 0,8, 2,8], OX, OY, S, Z);
    'S': Loop([0,0, 6,0, 6,6, 2,6, 2,8, 6,8,
               6,10, 0,10, 0,4, 4,4, 4,2, 0,2], OX, OY, S, Z);
    'K': Loop([0,0, 2,0, 2,3.5, 4,0, 6,0, 3,5,
               6,10, 4,10, 2,6.5, 2,10, 0,10], OX, OY, S, Z);
    'R': begin
           { the leg leans, or it is a P with a heavy side }
           Loop([0,0, 2,0, 2,4, 3.6,4, 4,0, 6,0, 5.6,4, 6,4,
                 6,10, 0,10], OX, OY, S, Z);
           { the counter, wound the other way about, which is what makes it
             a hole and not a second letter }
           Loop([2,6, 2,8, 4,8, 4,6], OX, OY, S, Z);
         end;
    ' ': Result := 3 * S;
  end;
end;

{ Is this loop the counter of the letter before it?  Only R has one, and it
  is always the loop straight after R's outline, so "did the loop before me
  contain me" is the whole test - and it is cheap because there are thirteen
  of them and not thirteen thousand. }
function IsCounter(const All: array of TP3Array; I: Integer): Boolean;
var
  Lo, Hi, PLo, PHi: TP3;

  procedure Span(const Pts: TP3Array; out A, B: TP3);
  var
    K: Integer;
  begin
    A := Pts[0]; B := Pts[0];
    for K := 1 to High(Pts) do
    begin
      A.X := Min(A.X, Pts[K].X); A.Y := Min(A.Y, Pts[K].Y);
      B.X := Max(B.X, Pts[K].X); B.Y := Max(B.Y, Pts[K].Y);
    end;
  end;

begin
  Result := False;
  if I = 0 then Exit;
  Span(All[I], Lo, Hi);
  Span(All[I - 1], PLo, PHi);
  Result := (Lo.X > PLo.X - 1E-9) and (Hi.X < PHi.X + 1E-9) and
            (Lo.Y > PLo.Y - 1E-9) and (Hi.Y < PHi.Y + 1E-9) and
            ((Hi.X - Lo.X) < (PHi.X - PLo.X) - 1E-9);
end;

{ Which of these loops this one sits inside, or -1 for one that sits on the
  drawing itself.  The smallest container wins, so a thing inside a thing
  inside a thing lands on its own immediate parent.

  A drawing is not a flat list of shapes.  The robot's eyes are inside its
  head, and the hole cut to hold an eye has to be cut out of the head, not
  out of the screen two shapes back.  Cut both out of the screen and the
  screen ends up with a hole inside a hole and the head laid straight over
  the eyes - two faces fighting over the same pixels, and a solid that stops
  being closed the moment either one is pushed. }
function ParentOf(const All: array of TP3Array; I: Integer): Integer;
var
  J: Integer;
  Lo, Hi, QLo, QHi, BestLo, BestHi: TP3;

  procedure Span(const Pts: TP3Array; out A, B: TP3);
  var
    K: Integer;
  begin
    A := Pts[0]; B := Pts[0];
    for K := 1 to High(Pts) do
    begin
      A.X := Min(A.X, Pts[K].X); A.Y := Min(A.Y, Pts[K].Y);
      B.X := Max(B.X, Pts[K].X); B.Y := Max(B.Y, Pts[K].Y);
    end;
  end;

begin
  Result := -1;
  Span(All[I], Lo, Hi);
  BestLo := P3(0, 0, 0); BestHi := P3(0, 0, 0);
  for J := 0 to High(All) do
  begin
    if J = I then Continue;
    Span(All[J], QLo, QHi);
    if (Lo.X < QLo.X - 1E-9) or (Hi.X > QHi.X + 1E-9) or
       (Lo.Y < QLo.Y - 1E-9) or (Hi.Y > QHi.Y + 1E-9) then Continue;
    { the same size is not inside }
    if ((QHi.X - QLo.X) - (Hi.X - Lo.X) < 1E-9) and
       ((QHi.Y - QLo.Y) - (Hi.Y - Lo.Y) < 1E-9) then Continue;
    if (Result < 0) or
       ((QHi.X - QLo.X) * (QHi.Y - QLo.Y) <
        (BestHi.X - BestLo.X) * (BestHi.Y - BestLo.Y)) then
    begin
      Result := J; BestLo := QLo; BestHi := QHi;
    end;
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

{ A box drawn in stylus lines, which is all the robot is made of.  It goes
  through Loop like the letters do, so it is remembered and gets a face of its
  own - draw it with Stroke and it is four lines nobody can push. }
procedure BoxLine(X0, Y0, X1, Y1: Double);
begin
  Loop([X0, Y0, X1, Y0, X1, Y1, X0, Y1], 0, 0, 1, BT - RECESS);
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
  I, J, TopFace, ScrFace: Integer;
  U: TStringList;
  Outer, Screen: TP3Array;
  Logo, Robot: array of TP3Array;
  Holes: array of TP3Array;
  BaseP, Diag, CamZoom: Double;
  BLo, BHi, CamMid: TP3;
  CamV: TProjector;
  CamP: TPointF;
begin
  D := TWorkDoc.Create;
  L := TStringList.Create;
  ZF := BT - RECESS;
  Grp := BODY;

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
  TopFace := D.Live - 1;

  Skirt(Outer, 0, BT, RED);                    { the outside, walling out }
  Skirt(Reversed(Screen), ZF, BT, RED);        { the pocket, walling in }
  D.AddFaceRaw(RoundRect(SX0, SY0, SX1, SY1, SR, ZF), GREY, True);
  D.SetFaceGroup(D.Live - 1, Grp);
  ScrFace := D.Live - 1;

  { --- the knobs ---------------------------------------------------- }
  Knob(KNOB_X0, KNOB_Y);
  Knob(KNOB_X1, KNOB_Y);

  { --- the logo on the top edge, in the toy's own lines ---------------- }
  SetLength(Drawn, 0);
  Word_('HECKERS SKETCH', BW / 2, 8.05, 0.075, BT);
  SetLength(Logo, Length(Drawn));
  for I := 0 to High(Drawn) do Logo[I] := Drawn[I];

  { --- the robot, drawn on the screen -------------------------------- }
  SetLength(Drawn, 0);
  BoxLine(5.2, 5.6, 6.8, 6.9);        { head }
  BoxLine(5.5, 6.1, 5.8, 6.4);        { left eye }
  BoxLine(6.2, 6.1, 6.5, 6.4);        { right eye }
  Stroke(5.6, 5.85, 6.4, 5.85);       { mouth }
  BoxLine(4.8, 3.4, 7.2, 5.6);        { body }
  BoxLine(3.6, 4.4, 4.8, 5.0);        { left arm }
  BoxLine(7.2, 4.4, 8.4, 5.0);        { right arm }
  BoxLine(5.2, 2.6, 5.9, 3.4);        { left leg }
  BoxLine(6.1, 2.6, 6.8, 3.4);        { right leg }

  SetLength(Robot, Length(Drawn));
  for I := 0 to High(Drawn) do Robot[I] := Drawn[I];

  { --- the faces under the drawing ------------------------------------

    A loop of lines is only a face once somebody has worked the faces out,
    and that is not done to a drawing read from a file: everything in a saved
    file is taken as already settled, so a region with no face is one whose
    face was rubbed out on purpose and it is never handed another.  Quite
    right for a file the program saved - rub a face out, save, open it again,
    and it should stay rubbed out - and it means a file written by hand has
    to carry its faces or they will never appear.

    So each letter and each piece of the robot gets a face, and is cut out of
    the face it sits on.  Cut out, not laid over: two faces in the same place
    is two faces fighting over the same pixels.  The hole's edge and the
    letter's edge are then the same edge run opposite ways, which is what
    keeps the whole toy a closed solid.

    This is also what makes them push: click the H, push it, and the letter
    stands up off the frame. }
  SetLength(Holes, 1);
  Holes[0] := Reversed(Screen);
  for I := 0 to High(Logo) do
  begin
    { the counter is inside its letter, not inside the frame }
    if IsCounter(Logo, I) then Continue;
    SetLength(Holes, Length(Holes) + 1);
    Holes[High(Holes)] := Reversed(Logo[I]);
  end;
  D.SetFaceHoles(TopFace, Holes);

  { Only the pieces that sit straight on the screen are cut out of it.  An
    eye is cut out of the head it is drawn inside, further down. }
  SetLength(Holes, 0);
  for I := 0 to High(Robot) do
    if ParentOf(Robot, I) < 0 then
    begin
      SetLength(Holes, Length(Holes) + 1);
      Holes[High(Holes)] := Reversed(Robot[I]);
    end;
  D.SetFaceHoles(ScrFace, Holes);

  { the letters themselves.  R is the one with a counter: its hole is the
    loop after it, and that loop is a face in its own right as well - the
    island in the middle of the bowl. }
  for I := 0 to High(Logo) do
  begin
    { a counter belongs to the letter before it and is dealt with there }
    if IsCounter(Logo, I) then Continue;
    D.AddFaceRaw(Logo[I], RED, True);
    D.SetFaceGroup(D.Live - 1, BODY);
    if (I < High(Logo)) and IsCounter(Logo, I + 1) then
    begin
      { the bowl of the R: a hole in the letter, and the island inside it is
        a face of its own, wound the other way about }
      SetLength(Holes, 1);
      Holes[0] := Logo[I + 1];
      D.SetFaceHoles(D.Live - 1, Holes);
      D.AddFaceRaw(Reversed(Logo[I + 1]), RED, True);
      D.SetFaceGroup(D.Live - 1, BODY);
    end;
  end;

  for I := 0 to High(Robot) do
  begin
    D.AddFaceRaw(Robot[I], GREY, True);
    D.SetFaceGroup(D.Live - 1, BODY);
    { and whatever was drawn inside it is cut out of it }
    SetLength(Holes, 0);
    for J := 0 to High(Robot) do
      if ParentOf(Robot, J) = I then
      begin
        SetLength(Holes, Length(Holes) + 1);
        Holes[High(Holes)] := Reversed(Robot[J]);
      end;
    if Length(Holes) > 0 then D.SetFaceHoles(D.Live - 1, Holes);
  end;

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
  { Where the camera stands, worked out the same way the Fit button works it
    out, for a drawing area about the size of a window somebody would open.

    Written out rather than guessed because the numbers are a zoom and a PAN,
    and a pan of nought puts the world's origin in the top left corner of the
    view - which is why this used to open with the toy away off to one side
    and the origin somewhere in right field. }
  BaseP := PixelsPerUnit(usImperial, ScaleTable(usImperial, 4), 96);
  D.Bounds(BLo, BHi);
  CamMid := P3((BLo.X + BHi.X) / 2, (BLo.Y + BHi.Y) / 2, (BLo.Z + BHi.Z) / 2);
  { in a free camera the diagonal is the safe bound from any angle, which is
    what FitView uses }
  Diag := Sqrt(Sqr(BHi.X - BLo.X) + Sqr(BHi.Y - BLo.Y) + Sqr(BHi.Z - BLo.Z));
  CamZoom := Min((ART_W * 0.8) / (Diag * BaseP), (ART_H * 0.8) / (Diag * BaseP));
  CamV.Kind := vkOrbit;
  CamV.Az := -0.785398;
  CamV.El := 0.700000;
  CamV.Ppu := BaseP * CamZoom;
  CamV.OX := 0;
  CamV.OY := 0;
  CamP := Project(CamV, CamMid);
  L.Add(StringReplace(Format('CAMERA %.6f %.6f %.6f %.3f %.3f',
    [CamV.Az, CamV.El, CamZoom, ART_W / 2 - CamP.X, ART_H / 2 - CamP.Y]),
    DefaultFormatSettings.DecimalSeparator, '.', [rfReplaceAll]));
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
