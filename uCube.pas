unit uCube;

{ The view cube.

  A small cube in the corner of the drawing that turns with the model, and
  that you can click to look at the thing from a named direction: a face for
  a straight-on view, an edge for a half turn between two, a corner for the
  three-quarter view most drawings are actually read from.  Dragging it
  orbits, the same as dragging the model.

  Revit has one and it is the right idea, so the behaviour here is theirs:
  twenty-six places to click, hot under the pointer, and the cube always
  showing which way you are facing.  The appearance is not theirs - ours is
  drawn in the program's own theme, and "ViewCube" is Autodesk's name for
  Autodesk's widget.  Copying how a thing works is ordinary; copying how it
  looks, under its own name, is not.

  The other half of the argument for it is the half nobody asks for: the
  VIEW button can put you in a named view but it cannot tell you where you
  are once you have orbited away from one.  Nothing else on screen can
  either.  A cube can, without being touched.

  Which way round it is: the program's own presets say FRONT is Az 0, El 0,
  and ViewDir at Az 0 is +X - so the front of a model faces +X, the right
  faces +Y and the top faces +Z.  The names here follow the presets rather
  than any convention of mine, because the two must agree or /front and the
  cube's FRONT would do different things.

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Types, uSurface, uWork, uSkin;

type
  { One of the twenty-six places you can click.  Dir is which way to look
    FROM, with components in -1, 0, 1: one non-zero is a face, two an edge,
    three a corner. }
  TCubeTarget = record
    Dir: TP3;
    Name: string;
  end;

{ How wide the cube wants to be, in pixels, at a given interface scale. }
function CubeSize(UIScale: Single): Integer;

{ Which target is under a screen point, if any.  CX, CY is the middle of the
  cube on the screen and Half is its half-width in pixels - the same two
  numbers PaintCube is given. }
function CubeAt(const V: TProjector; CX, CY, Half, SX, SY: Double;
  out T: TCubeTarget): Boolean;

{ Where to look from, for a target.  Az is carried in as well as out: a
  target straight up or straight down says nothing about which way round to
  be, so the turn you already had is kept rather than snapped to zero. }
procedure CubeAzEl(const Dir: TP3; var Az: Double; out El: Double);

{ Draw the cube into a surface of its own.  The surface should be square and
  at least 2 * Half + a few pixels across; the cube is centred in it.  Hot is
  the target under the pointer, if there is one.

  Labels are not drawn here - they want a font, and the caller has a canvas.
  CubeLabels hands back where each visible face's middle landed so the caller
  can write on it. }
procedure PaintCube(S: TArtSurface; const V: TProjector; Half: Double;
  const Th: TTheme; HaveHot: Boolean; const HotDir: TP3);

{ The visible faces, their names, and where the middle of each one is in the
  surface PaintCube just drew.  Up to three come back. }
type
  TCubeLabel = record
    Name: string;
    X, Y: Double;
    Facing: Double;     { how square-on it is, 0 to 1 - dim the steep ones }
  end;
  TCubeLabels = array of TCubeLabel;

function CubeLabels(const V: TProjector; Half: Double): TCubeLabels;

{ Where the middle of a target is drawn - what somebody aiming at it would
  point at.  An edge or a corner belongs to two or three faces, so the one
  most square-on to the camera is the one it is drawn on.  False when none of
  its faces is facing this way, which is to say it is round the back. }
function CubeTargetAt(const V: TProjector; const Dir: TP3;
  CX, CY, Half: Double; out P: TPointF): Boolean;

implementation

const
  { Where a face stops and its edges begin, as a fraction of the half-width.
    The middle 65% of a face is the face; outside that you are on an edge or
    a corner.  Revit's is about the same, and it has to be generous: an edge
    strip too thin to hit is a target nobody uses twice. }
  BAND = 0.65;

type
  TFaceDef = record
    N, A, B: TP3;     { normal, and the two directions across the face }
  end;

const
  FACES: array[0..5] of TFaceDef = (
    (N: (X: 1; Y: 0; Z: 0);  A: (X: 0; Y: 1; Z: 0);  B: (X: 0; Y: 0; Z: 1)),
    (N: (X: -1; Y: 0; Z: 0); A: (X: 0; Y: -1; Z: 0); B: (X: 0; Y: 0; Z: 1)),
    (N: (X: 0; Y: 1; Z: 0);  A: (X: -1; Y: 0; Z: 0); B: (X: 0; Y: 0; Z: 1)),
    (N: (X: 0; Y: -1; Z: 0); A: (X: 1; Y: 0; Z: 0);  B: (X: 0; Y: 0; Z: 1)),
    (N: (X: 0; Y: 0; Z: 1);  A: (X: 1; Y: 0; Z: 0);  B: (X: 0; Y: 1; Z: 0)),
    (N: (X: 0; Y: 0; Z: -1); A: (X: 1; Y: 0; Z: 0);  B: (X: 0; Y: -1; Z: 0)));

function CubeSize(UIScale: Single): Integer;
begin
  Result := Round(104 * UIScale);
end;

{ The name of a direction, built from its parts.  Front and back first, then
  left and right, then top and bottom, because that is the order the words
  come out in when somebody says where they are looking from. }
function DirName(const D: TP3): string;
begin
  Result := '';
  if D.X > 0.5 then Result := 'FRONT'
  else if D.X < -0.5 then Result := 'BACK';
  if D.Y > 0.5 then Result := Trim(Result + ' RIGHT')
  else if D.Y < -0.5 then Result := Trim(Result + ' LEFT');
  if D.Z > 0.5 then Result := Trim(Result + ' TOP')
  else if D.Z < -0.5 then Result := Trim(Result + ' BOTTOM');
end;

{ A point of the cube, in the surface's pixels.  The cube is one unit from
  the middle to each face, so a coordinate runs -1 to 1. }
function OnScreen(const V: TProjector; const P: TP3;
  CX, CY, Half: Double): TPointF;
var
  R, U: TP3;
begin
  R := ViewRight(V);
  U := ViewUp(V);
  Result.X := CX + Dot3(P, R) * Half;
  Result.Y := CY - Dot3(P, U) * Half;
end;

procedure CubeAzEl(const Dir: TP3; var Az: Double; out El: Double);
var
  Flat: Double;
begin
  Flat := Sqrt(Dir.X * Dir.X + Dir.Y * Dir.Y);
  { straight up or straight down says nothing about which way round to be,
    so keep the turn that is already in force }
  if Flat > 1E-9 then Az := ArcTan2(Dir.Y, Dir.X);
  El := ArcTan2(Dir.Z, Flat);
  { the same stop the orbit has.  Dead overhead is a gimbal: the model can
    be spun about the eye and nothing changes, so there is nowhere to go
    from there. }
  if El < -1.45 then El := -1.45;
  if El > 1.45 then El := 1.45;
end;

function CubeAt(const V: TProjector; CX, CY, Half, SX, SY: Double;
  out T: TCubeTarget): Boolean;
var
  R, U, D, O, Dir, P: TP3;
  A, B, TMin, TMax, T1, T2, Tmp: Double;
  K: Integer;

  { one axis of the slab test }
  function Slab(Oi, Di: Double): Boolean;
  begin
    Result := True;
    if Abs(Di) < 1E-12 then
    begin
      { the ray runs along this slab: it either starts inside it or misses
        the cube altogether }
      if Abs(Oi) > 1 then Result := False;
      Exit;
    end;
    T1 := (-1 - Oi) / Di;
    T2 := (1 - Oi) / Di;
    if T1 > T2 then
    begin
      Tmp := T1; T1 := T2; T2 := Tmp;
    end;
    if T1 > TMin then TMin := T1;
    if T2 < TMax then TMax := T2;
  end;

begin
  Result := False;
  T.Dir := P3(0, 0, 0);
  T.Name := '';
  if Half <= 0 then Exit;

  R := ViewRight(V);
  U := ViewUp(V);
  { ViewDir points from the model towards the eye, so the ray goes the other
    way - away from the camera, into the cube }
  D := ViewDir(V);
  Dir := P3(-D.X, -D.Y, -D.Z);

  { the point of the cube's own space that this pixel looks along }
  A := (SX - CX) / Half;
  B := (CY - SY) / Half;
  O := P3(A * R.X + B * U.X, A * R.Y + B * U.Y, A * R.Z + B * U.Z);

  TMin := -1E30;
  TMax := 1E30;
  if not Slab(O.X, Dir.X) then Exit;
  if not Slab(O.Y, Dir.Y) then Exit;
  if not Slab(O.Z, Dir.Z) then Exit;
  if TMin > TMax then Exit;

  { where it goes in - the near face, which is the one being pointed at }
  P := P3(O.X + TMin * Dir.X, O.Y + TMin * Dir.Y, O.Z + TMin * Dir.Z);

  { and which of the twenty-six that is: every coordinate out past the band
    counts towards the direction, the rest do not }
  T.Dir := P3(0, 0, 0);
  if P.X > BAND then T.Dir.X := 1 else if P.X < -BAND then T.Dir.X := -1;
  if P.Y > BAND then T.Dir.Y := 1 else if P.Y < -BAND then T.Dir.Y := -1;
  if P.Z > BAND then T.Dir.Z := 1 else if P.Z < -BAND then T.Dir.Z := -1;

  { A point that is on the cube must be against at least one face, so this
    cannot come out as nothing - unless rounding has put it a hair inside,
    which is what the nudge is for. }
  if (T.Dir.X = 0) and (T.Dir.Y = 0) and (T.Dir.Z = 0) then
  begin
    K := 0;
    if Abs(P.Y) > Abs(P.X) then K := 1;
    if (Abs(P.Z) > Abs(P.X)) and (Abs(P.Z) > Abs(P.Y)) then K := 2;
    case K of
      0: T.Dir.X := Sign(P.X);
      1: T.Dir.Y := Sign(P.Y);
    else T.Dir.Z := Sign(P.Z);
    end;
  end;

  T.Name := DirName(T.Dir);
  Result := True;
end;

function CubeLabels(const V: TProjector; Half: Double): TCubeLabels;
var
  F: Integer;
  D: TP3;
  Face: TFaceDef;
  Lit: Double;
  P: TPointF;
begin
  SetLength(Result, 0);
  D := ViewDir(V);
  for F := 0 to High(FACES) do
  begin
    Face := FACES[F];
    Lit := Dot3(Face.N, D);
    { away from the camera, or so nearly edge on that a word on it would be
      a smear.  Low, because the top face of a cube seen from a normal
      working angle is only about four tenths square-on and it is plainly
      big enough to read. }
    if Lit < 0.26 then Continue;
    P := OnScreen(V, Face.N, 0, 0, Half);
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)].Name := DirName(Face.N);
    Result[High(Result)].X := P.X;
    Result[High(Result)].Y := P.Y;
    Result[High(Result)].Facing := Lit;
  end;
end;

function CubeTargetAt(const V: TProjector; const Dir: TP3;
  CX, CY, Half: Double; out P: TPointF): Boolean;
var
  F, Best: Integer;
  D, Pt: TP3;
  Lit, BestLit, Mid, U, W: Double;
begin
  Result := False;
  P := PointF(CX, CY);
  D := ViewDir(V);
  Best := -1;
  BestLit := 0.001;
  for F := 0 to High(FACES) do
  begin
    { adjacent, meaning this target lies on this face }
    if Dot3(Dir, FACES[F].N) < 0.5 then Continue;
    Lit := Dot3(FACES[F].N, D);
    if Lit > BestLit then
    begin
      BestLit := Lit;
      Best := F;
    end;
  end;
  if Best < 0 then Exit;

  { the middle of the cell: the middle of the outer band where the target
    runs off that way, the middle of the face where it does not }
  Mid := (BAND + 1) / 2;
  U := Dot3(Dir, FACES[Best].A) * Mid;
  W := Dot3(Dir, FACES[Best].B) * Mid;
  Pt := P3(FACES[Best].N.X + U * FACES[Best].A.X + W * FACES[Best].B.X,
           FACES[Best].N.Y + U * FACES[Best].A.Y + W * FACES[Best].B.Y,
           FACES[Best].N.Z + U * FACES[Best].A.Z + W * FACES[Best].B.Z);
  P := OnScreen(V, Pt, CX, CY, Half);
  Result := True;
end;

procedure PaintCube(S: TArtSurface; const V: TProjector; Half: Double;
  const Th: TTheme; HaveHot: Boolean; const HotDir: TP3);
var
  F, I, J: Integer;
  Face: TFaceDef;
  D, N, Cell: TP3;
  Lit, Up: Double;
  CX, CY: Double;
  Q: array[0..3] of TPointF;
  Fill, Line: TPix;
  Hot: Boolean;

  { the corners of cell I,J of a face, in cube space }
  function Corner(const AFace: TFaceDef; UI, WI: Integer): TP3;
  var
    Ub, Wb: Double;
  begin
    case UI of
      0: Ub := -1;
      1: Ub := -BAND;
      2: Ub := BAND;
    else Ub := 1;
    end;
    case WI of
      0: Wb := -1;
      1: Wb := -BAND;
      2: Wb := BAND;
    else Wb := 1;
    end;
    Result := P3(AFace.N.X + Ub * AFace.A.X + Wb * AFace.B.X,
                 AFace.N.Y + Ub * AFace.A.Y + Wb * AFace.B.Y,
                 AFace.N.Z + Ub * AFace.A.Z + Wb * AFace.B.Z);
  end;

begin
  if (S = nil) or (Half <= 0) then Exit;
  CX := S.Width / 2;
  CY := S.Height / 2;
  D := ViewDir(V);

  { No pad and no cast shadow.

    Both were tried and both were wrong.  A rounded tray behind it and a
    silhouette shifted down to fake a shadow gave the thing two outlines that
    were not the cube's - a rounded square, a hexagon, and a second hexagon
    peeking out of the bottom of the first - and the eye read the lot as one
    strange shape rather than as a cube with dressing on it.  A cube is a
    shape everybody already knows; the job is to draw that shape crisply and
    let it be recognised, not to decorate round it. }

  for F := 0 to High(FACES) do
  begin
    Face := FACES[F];
    N := Face.N;
    Lit := Dot3(N, D);
    if Lit <= 0.001 then Continue;      { facing away }

    for I := 0 to 2 do
      for J := 0 to 2 do
      begin
        { which of the twenty-six this cell is: the face itself in the
          middle, an edge along a side, a corner in a corner }
        Cell := N;
        if I = 0 then Cell := P3(Cell.X - Face.A.X, Cell.Y - Face.A.Y, Cell.Z - Face.A.Z)
        else if I = 2 then Cell := P3(Cell.X + Face.A.X, Cell.Y + Face.A.Y, Cell.Z + Face.A.Z);
        if J = 0 then Cell := P3(Cell.X - Face.B.X, Cell.Y - Face.B.Y, Cell.Z - Face.B.Z)
        else if J = 2 then Cell := P3(Cell.X + Face.B.X, Cell.Y + Face.B.Y, Cell.Z + Face.B.Z);

        Hot := HaveHot and (Abs(Cell.X - HotDir.X) < 0.01) and
               (Abs(Cell.Y - HotDir.Y) < 0.01) and (Abs(Cell.Z - HotDir.Z) < 0.01);

        Q[0] := OnScreen(V, Corner(Face, I, J), CX, CY, Half);
        Q[1] := OnScreen(V, Corner(Face, I + 1, J), CX, CY, Half);
        Q[2] := OnScreen(V, Corner(Face, I + 1, J + 1), CX, CY, Half);
        Q[3] := OnScreen(V, Corner(Face, I, J + 1), CX, CY, Half);

        { Shaded by how square-on the face is, so the cube reads as a solid
          rather than a flat hexagon - and lifted on the way up, because a
          thing lit from above has a bright lid.  Facing alone made the top
          the darkest face of the three, which reads as a hole. }
        if Hot then
          Fill := ShadePix(Th.Accent, 0.85 + 0.35 * Lit)
        else
          Fill := MixPix(Th.Panel, Pix(255, 255, 255),
                         0.10 + 0.20 * Lit + 0.14 * Max(0, N.Z));

        S.Triangle(Q[0], Q[1], Q[2], Fill, 1.0);
        S.Triangle(Q[0], Q[2], Q[3], Fill, 1.0);
      end;

    { The outline of the face, and a rim light along whichever of its edges
      is uppermost - the trick that makes a flat fill look like a bevel, and
      the same one the panels and buttons use. }
    Line := MixPix(Th.PanelHi, Pix(255, 255, 255), 0.35);
    Q[0] := OnScreen(V, Corner(Face, 0, 0), CX, CY, Half);
    Q[1] := OnScreen(V, Corner(Face, 3, 0), CX, CY, Half);
    Q[2] := OnScreen(V, Corner(Face, 3, 3), CX, CY, Half);
    Q[3] := OnScreen(V, Corner(Face, 0, 3), CX, CY, Half);
    S.Line(Q[0].X, Q[0].Y, Q[1].X, Q[1].Y, 1.2, Line, 0.85);
    S.Line(Q[1].X, Q[1].Y, Q[2].X, Q[2].Y, 1.2, Line, 0.85);
    S.Line(Q[2].X, Q[2].Y, Q[3].X, Q[3].Y, 1.2, Line, 0.85);
    S.Line(Q[3].X, Q[3].Y, Q[0].X, Q[0].Y, 1.2, Line, 0.85);

    for I := 0 to 3 do
    begin
      J := (I + 1) mod 4;
      { the higher an edge sits on the screen, the more light it catches }
      Up := 1 - (Q[I].Y + Q[J].Y) / 2 / Max(1, S.Height);
      if Up < 0.55 then Continue;
      S.Line(Q[I].X, Q[I].Y, Q[J].X, Q[J].Y, 1.4,
        MixPix(Th.PanelHi, Pix(255, 255, 255), 0.75), (Up - 0.55) * 1.6);
    end;
  end;
  S.Touch;
end;

end.
