unit uWork;

{
  uWork - the drafting side of Poopin Heckers Sketch.

  PRO mode is a small 2D drawing board with SketchUp's habits: pick a tool,
  click a point, and either move to the next one or just type the distance.
  Nothing here knows about dials or pen styles - that is the toy's half of
  the program.

  What lives here:
    * a document of entities - lines, arcs (a circle is a full-sweep arc),
      text notes and standalone dimensions - measured in real units and kept
      as geometry, so changing the drawing scale re-draws everything exactly
      instead of resampling pixels;
    * length parsing and formatting - 12'6", 12-6, 6 1/2", 3.5m, 350cm;
    * the drawing scale table and snap increments;
    * hit testing (for the eraser), snap-point gathering, and rendering.

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Math, StrUtils, Graphics, uSurface;

type
  TUnitSystem = (usImperial, usMetric);

  { A point in the model.  Everything is stored in 3D from the start, so
    adding views later is a projection change rather than a rewrite: PLAN
    ignores Z, ISO folds all three axes onto the screen, and a perspective
    view would slot in beside them. }
  TP3 = record
    X, Y, Z: Double;
  end;

  { How the model is mapped onto the screen.

    vkPlan  - straight down the Z axis, the 2D drawing board.
    vkIso   - the 30 degree drafting isometric: axes at true length, which is
              what a dimensioned spool drawing needs.
    vkOrbit - a free orthographic 3D view you can spin.  This is the one that
              makes push/pull worth having. }
  TViewKind = (vkPlan, vkIso, vkOrbit);

  { The plane an arc or circle lies in. }
  TPlane = (plXY, plXZ, plYZ);

  TProjector = record
    Kind: TViewKind;
    Ppu: Double;          // pixels per world unit
    OX, OY: Double;       // screen position of world 0,0,0
    Az, El: Double;       // vkOrbit only: turntable and tilt, in radians
  end;

  { A drawing scale.  Paper is the fraction of a paper unit that one world
    unit occupies - for 1/4" = 1'-0" that is 0.25 paper inches per foot. }
  TDrawScale = record
    Name: string;
    Paper: Double;
  end;

  TEntKind = (ekLine, ekArc, ekText, ekDim, ekFace);

  { One thing on the drawing.  World coordinates, Y up, in feet or metres.

    ekLine  uses A and B.
    ekArc   uses C (centre), R, A0 (start angle) and Sweep; a circle is just
            a sweep of 2*pi.  A and B are kept as the endpoints for snapping.
    ekText  uses A and Txt.
    ekDim   uses A and B and always draws its dimension line. }
  TWorkEnt = record
    Kind: TEntKind;
    A, B, C: TP3;
    R, A0, Sweep: Double;
    Plane: TPlane;
    Poly: array of TP3;   // ekFace: the closed outline, in order
    Solid: Boolean;       // ekFace: part of a solid, so its back is hidden
    Txt: string;
    Ink: TColor;
    Weight: Single;
    Dim: Boolean;
  end;

  TWorkEntArray = array of TWorkEnt;
  TP3Array = array of TP3;
  TPointFArray = array of TPointF;

  { snSubMid is the midpoint of a piece of a line that something else has
    crossed, as opposed to snMidpoint, the middle of a whole uncrossed one.
    Splitting a rectangle in half puts one of these at the quarter point of
    every edge it touched, so they multiply fast and are worth much less
    than the point you actually aimed at. }
  TSnapKind = (snNone, snGrid, snEndpoint, snMidpoint, snCentre, snCross,
    snSubMid);

  TSnapHit = record
    P: TP3;
    Kind: TSnapKind;
  end;

  { TWorkDoc }

  TWorkDoc = class
  private
    FEnts: array of TWorkEnt;
    FLive: Integer;      // entities in play; anything past this is redo space
    FSnapCache: array of TSnapHit;
    FSnapDirty: Boolean;
    function GetEnt(I: Integer): TWorkEnt;
    procedure RebuildSnapCache;
  public
    procedure AddLine(const A, B: TP3; Ink: TColor; Weight: Single; Dim: Boolean);
    procedure AddArc(const C: TP3; R, A0, Sweep: Double; Pl: TPlane;
      Ink: TColor; Weight: Single);
    procedure AddText(const A: TP3; const S: string; Ink: TColor);
    procedure AddDim(const A, B: TP3; Ink: TColor);
    procedure AddFace(const Pts: array of TP3; Ink: TColor; Solid: Boolean = False);

    { push/pull: lift the face along its own normal and wall in the sides }
    function PushPull(Index: Integer; Dist: Double): Boolean;
    { Cut every flat face this segment crosses in two.  Returns how many were
      split.  This is what makes a line drawn across a shape divide it. }
    function SplitFacesWith(const A, B: TP3): Integer;
    function SplitFace(Index: Integer; const A, B: TP3): Boolean;
    function HitFace(const V: TProjector; SX, SY: Double): Integer;
    function FaceNormal(Index: Integer): TP3;
    function FaceArea(Index: Integer): Double;

    { the closed loop of lines ending at the last entity, if there is one }
    function ClosedChain(Tol: Double; out Pts: TP3Array): Boolean;
    procedure Delete(I: Integer);
    procedure Clear;
    procedure SetLive(N: Integer);
    function Snapshot: TWorkEntArray;
    procedure RestoreSnap(const A: TWorkEntArray);
    function Stored: Integer;

    { the run of chained lines ending at the last entity }
    function FirstOfChain: Integer;
    function ChainLength: Double;
    function ChainClosed(Tol: Double): Boolean;
    function ChainArea: Double;

    { Hit testing and snapping are done in screen space so they behave the
      same in every view. }
    function HitTest(const V: TProjector; SX, SY, TolPx: Double): Integer;

    { Every point worth snapping or aligning to, including the places lines
      cross each other and the midpoints those crossings create. }
    procedure SnapPoints(out Pts: TP3Array);

    { An entity's outline in screen coordinates, for highlighting it. }
    function Outline(const V: TProjector; I: Integer): TPointFArray;
    function BestSnap(const V: TProjector; SX, SY, TolPx: Double;
      out Hit: TSnapHit): Boolean;
    function Bounds(out Lo, Hi: TP3): Boolean;

    procedure Render(S: TArtSurface; const V: TProjector; ShowDims: Boolean;
      U: TUnitSystem; AFont: TFont; const LabelCol: TPix);

    { the document, as plain text - one line per entity }
    procedure SaveTo(L: TStrings);
    procedure LoadFrom(L: TStrings; var Idx: Integer);
    procedure WriteSVG(L: TStrings; const V: TProjector; U: TUnitSystem);

    property Live: Integer read FLive;
    property Ent[I: Integer]: TWorkEnt read GetEnt; default;
  end;

const
  SCALE_COUNT = 5;

  IMPERIAL_SCALES: array[0..SCALE_COUNT - 1] of TDrawScale = (
    (Name: '1/16"'; Paper: 0.0625),
    (Name: '1/8"';  Paper: 0.125),
    (Name: '1/4"';  Paper: 0.25),
    (Name: '1/2"';  Paper: 0.5),
    (Name: '1"';    Paper: 1.0));

  METRIC_SCALES: array[0..SCALE_COUNT - 1] of TDrawScale = (
    (Name: '1:200'; Paper: 0.005),
    (Name: '1:100'; Paper: 0.01),
    (Name: '1:50';  Paper: 0.02),
    (Name: '1:20';  Paper: 0.05),
    (Name: '1:10';  Paper: 0.1));

  SNAP_COUNT = 6;

  { snap increments, in world units (feet / metres); 0 means no snapping }
  IMPERIAL_SNAPS: array[0..SNAP_COUNT - 1] of Double =
    (0, 1 / 192, 1 / 12, 0.25, 0.5, 1.0);
  IMPERIAL_SNAP_NAMES: array[0..SNAP_COUNT - 1] of string =
    ('OFF', '1/16"', '1"', '3"', '6"', '1''-0"');

  METRIC_SNAPS: array[0..SNAP_COUNT - 1] of Double =
    (0, 0.001, 0.01, 0.05, 0.1, 1.0);
  METRIC_SNAP_NAMES: array[0..SNAP_COUNT - 1] of string =
    ('OFF', '1mm', '10mm', '50mm', '100mm', '1m');

function UnitName(U: TUnitSystem): string;
function UnitShort(U: TUnitSystem): string;
function ScaleTable(U: TUnitSystem; I: Integer): TDrawScale;
function SnapValue(U: TUnitSystem; I: Integer): Double;
function SnapName(U: TUnitSystem; I: Integer): string;

{ Pixels per world unit for a scale, given the display resolution in pixels
  per paper inch. }
function PixelsPerUnit(U: TUnitSystem; const Sc: TDrawScale; DPI: Double): Double;

function FormatLen(V: Double; U: TUnitSystem): string;
function FormatArea(V: Double; U: TUnitSystem): string;
function ParseLen(const S: string; U: TUnitSystem; out V: Double): Boolean;

{ A "nice" round bar length that lands between MinPx and MaxPx on screen. }
function NiceBarLength(Ppu: Double; MinPx, MaxPx: Double; U: TUnitSystem): Double;

{ Build an arc through A and B that bulges Bulge units away from the chord.
  This is how two loose line ends get joined by a curve without any trimming:
  pick the two ends, then pull the middle out. }
function ArcFromChord(const A, B: TP3; Bulge: Double; Pl: TPlane;
  out C: TP3; out R, A0, Sweep: Double): Boolean;

function P3(X, Y, Z: Double): TP3; inline;
function Dist(const A, B: TP3): Double; inline;
function SamePt(const A, B: TP3; Tol: Double): Boolean; inline;

{ --- projection ---------------------------------------------------------- }
function Project(const V: TProjector; const P: TP3): TPointF;

{ Screen point back to the model, on the working plane through Base.  In PLAN
  that is simply the XY plane; in ISO the plane is picked by Pl. }
function Unproject(const V: TProjector; SX, SY: Double; Pl: TPlane;
  const Base: TP3): TP3;

{ The six axis directions, and how they read on screen in the given view. }
function AxisDir(Index: Integer): TP3;
function AxisName(Index: Integer): string;

{ A point on a circle of radius R about C, at Ang radians, in plane Pl. }
function ArcPoint(const C: TP3; R, Ang: Double; Pl: TPlane): TP3;

{ Unit vectors of the view: screen right, screen up, and the direction the
  camera looks along (used to sort faces back to front). }
function ViewRight(const V: TProjector): TP3;
function ViewUp(const V: TProjector): TP3;
function ViewDir(const V: TProjector): TP3;

function Cross3(const A, B: TP3): TP3;
function Dot3(const A, B: TP3): Double; inline;
function Norm3(const A: TP3): TP3;

{ The two in-plane coordinates of a model point. }
procedure PlaneCoords(Pl: TPlane; const P: TP3; out U, W: Double);

const
  ISO_COS = 0.86602540378443865;   // cos 30
  ISO_SIN = 0.5;                   // sin 30

implementation

const
  MM_PER_INCH = 25.4;

function UnitName(U: TUnitSystem): string;
begin
  if U = usImperial then Result := 'FEET' else Result := 'METRIC';
end;

function UnitShort(U: TUnitSystem): string;
begin
  if U = usImperial then Result := 'ft' else Result := 'm';
end;

function ScaleTable(U: TUnitSystem; I: Integer): TDrawScale;
begin
  I := EnsureRange(I, 0, SCALE_COUNT - 1);
  if U = usImperial then
    Result := IMPERIAL_SCALES[I]
  else
    Result := METRIC_SCALES[I];
end;

function SnapValue(U: TUnitSystem; I: Integer): Double;
begin
  I := EnsureRange(I, 0, SNAP_COUNT - 1);
  if U = usImperial then Result := IMPERIAL_SNAPS[I] else Result := METRIC_SNAPS[I];
end;

function SnapName(U: TUnitSystem; I: Integer): string;
begin
  I := EnsureRange(I, 0, SNAP_COUNT - 1);
  if U = usImperial then
    Result := IMPERIAL_SNAP_NAMES[I]
  else
    Result := METRIC_SNAP_NAMES[I];
end;

function PixelsPerUnit(U: TUnitSystem; const Sc: TDrawScale; DPI: Double): Double;
begin
  if U = usImperial then
    { Sc.Paper is paper inches per foot, DPI is pixels per paper inch }
    Result := Sc.Paper * DPI
  else
    { Sc.Paper is paper metres per metre }
    Result := Sc.Paper * (DPI / 0.0254);
  if Result < 0.5 then Result := 0.5;
end;

{ ---------------------------------------------------------------------- }
{ formatting                                                              }
{ ---------------------------------------------------------------------- }

{ Reduce SIXTEENTHS/16 to the tidiest fraction, e.g. 8/16 -> 1/2. }
function FractionText(Sixteenths: Integer): string;
var
  N, D: Integer;
begin
  N := Sixteenths;
  D := 16;
  while (N > 0) and (N mod 2 = 0) do
  begin
    N := N div 2;
    D := D div 2;
  end;
  if N = 0 then
    Result := ''
  else
    Result := Format('%d/%d', [N, D]);
end;

function FormatLen(V: Double; U: TUnitSystem): string;
var
  Neg: Boolean;
  TotalSix, Ft, Inch, Six: Int64;
  Frac: string;
begin
  Neg := V < 0;
  V := Abs(V);

  if U = usMetric then
  begin
    if V < 1 then
      Result := Format('%.0f mm', [V * 1000])
    else
      Result := Format('%.3f m', [V]);
  end
  else
  begin
    { round to the nearest sixteenth of an inch }
    TotalSix := Round(V * 12 * 16);
    Ft := TotalSix div (12 * 16);
    TotalSix := TotalSix - Ft * 12 * 16;
    Inch := TotalSix div 16;
    Six := TotalSix - Inch * 16;
    Frac := FractionText(Six);

    if Frac <> '' then
      Result := Format('%d''-%d %s"', [Ft, Inch, Frac])
    else
      Result := Format('%d''-%d"', [Ft, Inch]);
  end;

  if Neg then
    Result := '-' + Result;
end;

function FormatArea(V: Double; U: TUnitSystem): string;
begin
  if U = usMetric then
    Result := Format('%.2f m2', [V])
  else
    Result := Format('%.1f sq ft', [V]);
end;

{ ---------------------------------------------------------------------- }
{ parsing                                                                 }
{ ---------------------------------------------------------------------- }

{ Accepts a plain number, or a number with a fraction: 6, 6.5, 6 1/2, 6-1/2 }
function ParseMixed(S: string; out V: Double): Boolean;
var
  P, Q: Integer;
  Whole, Num, Den: Double;
  FracPart: string;
  FS: TFormatSettings;
begin
  Result := False;
  V := 0;
  S := Trim(S);
  if S = '' then Exit;
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';

  { split off a trailing fraction }
  FracPart := '';
  P := Pos('/', S);
  if P > 0 then
  begin
    Q := P - 1;
    while (Q > 0) and (S[Q] in ['0'..'9']) do Dec(Q);
    FracPart := Copy(S, Q + 1, MaxInt);
    S := Trim(Copy(S, 1, Q));
    while (S <> '') and (S[Length(S)] in [' ', '-']) do
      SetLength(S, Length(S) - 1);
  end;

  Whole := 0;
  if S <> '' then
    if not TryStrToFloat(S, Whole, FS) then Exit;

  if FracPart <> '' then
  begin
    P := Pos('/', FracPart);
    if not TryStrToFloat(Copy(FracPart, 1, P - 1), Num, FS) then Exit;
    if not TryStrToFloat(Copy(FracPart, P + 1, MaxInt), Den, FS) then Exit;
    if Den = 0 then Exit;
    Whole := Whole + Num / Den;
  end;

  V := Whole;
  Result := True;
end;

{ Turn what the user typed into a length in world units.

  Imperial:  12'6"   12' 6   12-6   12'   6"   150"   12   6 1/2"
             a bare number is feet; anything after a ' or ending in " is inches
  Metric:    3.5   3.5m   350cm   3500mm   (bare number is metres) }
function ParseLen(const S: string; U: TUnitSystem; out V: Double): Boolean;
var
  T, FtPart, InPart: string;
  P: Integer;
  A, B: Double;
begin
  Result := False;
  V := 0;
  T := Trim(S);
  if T = '' then Exit;

  if U = usMetric then
  begin
    T := LowerCase(T);
    if (Length(T) > 2) and (Copy(T, Length(T) - 1, 2) = 'mm') then
    begin
      if not ParseMixed(Copy(T, 1, Length(T) - 2), A) then Exit;
      V := A / 1000;
    end
    else if (Length(T) > 2) and (Copy(T, Length(T) - 1, 2) = 'cm') then
    begin
      if not ParseMixed(Copy(T, 1, Length(T) - 2), A) then Exit;
      V := A / 100;
    end
    else if (Length(T) > 1) and (T[Length(T)] = 'm') then
    begin
      if not ParseMixed(Copy(T, 1, Length(T) - 1), A) then Exit;
      V := A;
    end
    else
    begin
      if not ParseMixed(T, A) then Exit;
      V := A;
    end;
    Result := True;
    Exit;
  end;

  { imperial }
  if (T <> '') and (T[Length(T)] = '"') then
    SetLength(T, Length(T) - 1);
  T := Trim(T);
  if T = '' then Exit;

  P := Pos('''', T);
  if P > 0 then
  begin
    FtPart := Trim(Copy(T, 1, P - 1));
    InPart := Trim(Copy(T, P + 1, MaxInt));
    while (InPart <> '') and (InPart[1] = '-') do
      Delete(InPart, 1, 1);
    A := 0;
    B := 0;
    if (FtPart <> '') and not ParseMixed(FtPart, A) then Exit;
    if (InPart <> '') and not ParseMixed(InPart, B) then Exit;
    V := A + B / 12;
    Result := True;
    Exit;
  end;

  { it ended with a double-quote, so it was inches all along }
  if (Length(S) > 0) and (Trim(S)[Length(Trim(S))] = '"') then
  begin
    if not ParseMixed(T, A) then Exit;
    V := A / 12;
    Result := True;
    Exit;
  end;

  { "12-6" and "12 6" mean twelve foot six }
  P := Pos('-', T);
  if P = 0 then P := Pos(' ', T);
  if (P > 1) and (Pos('/', T) = 0) then
  begin
    if not ParseMixed(Copy(T, 1, P - 1), A) then Exit;
    if not ParseMixed(Copy(T, P + 1, MaxInt), B) then Exit;
    V := A + B / 12;
    Result := True;
    Exit;
  end;

  if not ParseMixed(T, A) then Exit;
  V := A;
  Result := True;
end;

function NiceBarLength(Ppu: Double; MinPx, MaxPx: Double; U: TUnitSystem): Double;
const
  IMP: array[0..8] of Double = (0.5, 1, 2, 5, 10, 20, 50, 100, 200);
  MET: array[0..8] of Double = (0.1, 0.25, 0.5, 1, 2, 5, 10, 20, 50);
var
  I: Integer;
  V: Double;
begin
  Result := 1;
  for I := 0 to 8 do
  begin
    if U = usImperial then V := IMP[I] else V := MET[I];
    Result := V;
    if V * Ppu >= MinPx then
    begin
      if V * Ppu <= MaxPx then Exit;
      Exit;
    end;
  end;
end;

{ ---------------------------------------------------------------------- }
{ geometry and projection                                                  }
{ ---------------------------------------------------------------------- }

function P3(X, Y, Z: Double): TP3;
begin
  Result.X := X;
  Result.Y := Y;
  Result.Z := Z;
end;

function Dist(const A, B: TP3): Double;
begin
  Result := Sqrt(Sqr(B.X - A.X) + Sqr(B.Y - A.Y) + Sqr(B.Z - A.Z));
end;

function SamePt(const A, B: TP3; Tol: Double): Boolean;
begin
  Result := Dist(A, B) <= Tol;
end;

function Cross3(const A, B: TP3): TP3;
begin
  Result.X := A.Y * B.Z - A.Z * B.Y;
  Result.Y := A.Z * B.X - A.X * B.Z;
  Result.Z := A.X * B.Y - A.Y * B.X;
end;

function Dot3(const A, B: TP3): Double;
begin
  Result := A.X * B.X + A.Y * B.Y + A.Z * B.Z;
end;

function Norm3(const A: TP3): TP3;
var
  L: Double;
begin
  L := Sqrt(A.X * A.X + A.Y * A.Y + A.Z * A.Z);
  if L < 1E-12 then
    Result := P3(0, 0, 1)
  else
    Result := P3(A.X / L, A.Y / L, A.Z / L);
end;

{ A turntable camera: Az spins about the world Z axis, El tilts up from the
  horizon.  Z is up in the model, which is what push/pull assumes. }
function ViewRight(const V: TProjector): TP3;
begin
  case V.Kind of
    vkOrbit: Result := P3(-Sin(V.Az), Cos(V.Az), 0);
    vkIso:   Result := P3(ISO_COS, -ISO_COS, 0);
  else
    Result := P3(1, 0, 0);
  end;
end;

function ViewUp(const V: TProjector): TP3;
begin
  case V.Kind of
    vkOrbit: Result := P3(-Sin(V.El) * Cos(V.Az), -Sin(V.El) * Sin(V.Az), Cos(V.El));
    vkIso:   Result := P3(ISO_SIN, ISO_SIN, 1);
  else
    Result := P3(0, 1, 0);
  end;
end;

{ The direction out of the screen, toward the viewer.  For the drafting
  isometric this follows from the projection itself: right x up works out to
  (-1,-1,1), so +X and +Y run away from the camera while +Z comes toward it. }
function ViewDir(const V: TProjector): TP3;
begin
  case V.Kind of
    vkOrbit: Result := P3(Cos(V.El) * Cos(V.Az), Cos(V.El) * Sin(V.Az), Sin(V.El));
    vkIso:   Result := Norm3(P3(-1, -1, 1));
  else
    Result := P3(0, 0, 1);
  end;
end;

{ PLAN looks straight down the Z axis.  ISO is the standard 30 degree
  isometric: +X runs down-right, +Y down-left, +Z straight up - which is
  exactly how a pipe spool drawing is laid out. }
function Project(const V: TProjector; const P: TP3): TPointF;
var
  R, U: TP3;
begin
  if V.Kind = vkOrbit then
  begin
    R := ViewRight(V);
    U := ViewUp(V);
    Result.X := V.OX + Dot3(P, R) * V.Ppu;
    Result.Y := V.OY - Dot3(P, U) * V.Ppu;
    Exit;
  end;
  if V.Kind = vkIso then
  begin
    Result.X := V.OX + (P.X - P.Y) * ISO_COS * V.Ppu;
    Result.Y := V.OY - ((P.X + P.Y) * ISO_SIN + P.Z) * V.Ppu;
  end
  else
  begin
    Result.X := V.OX + P.X * V.Ppu;
    Result.Y := V.OY - P.Y * V.Ppu;
  end;
end;

{ Two screen equations, three unknowns, so the working plane pins one of
  them; the remaining 2x2 system is solved directly. }
procedure UnprojectOrbit(const V: TProjector; SX, SY: Double; Pl: TPlane;
  const Base: TP3; out Res: TP3);
var
  R, U: TP3;
  A11, A12, A21, A22, B1, B2, Det, S, T: Double;
begin
  Res := Base;
  R := ViewRight(V);
  U := ViewUp(V);
  B1 := (SX - V.OX) / V.Ppu;
  B2 := (V.OY - SY) / V.Ppu;

  case Pl of
    plXY:
      begin
        A11 := R.X; A12 := R.Y; B1 := B1 - R.Z * Base.Z;
        A21 := U.X; A22 := U.Y; B2 := B2 - U.Z * Base.Z;
      end;
    plXZ:
      begin
        A11 := R.X; A12 := R.Z; B1 := B1 - R.Y * Base.Y;
        A21 := U.X; A22 := U.Z; B2 := B2 - U.Y * Base.Y;
      end;
  else
    begin
      A11 := R.Y; A12 := R.Z; B1 := B1 - R.X * Base.X;
      A21 := U.Y; A22 := U.Z; B2 := B2 - U.X * Base.X;
    end;
  end;

  Det := A11 * A22 - A12 * A21;
  if Abs(Det) < 1E-9 then Exit;      // looking edge-on at the plane
  S := (B1 * A22 - A12 * B2) / Det;
  T := (A11 * B2 - B1 * A21) / Det;

  case Pl of
    plXY: begin Res.X := S; Res.Y := T; end;
    plXZ: begin Res.X := S; Res.Z := T; end;
  else
    begin Res.Y := S; Res.Z := T; end;
  end;
end;

function Unproject(const V: TProjector; SX, SY: Double; Pl: TPlane;
  const Base: TP3): TP3;
var
  U, W: Double;
begin
  Result := Base;
  if V.Kind = vkPlan then
  begin
    Result.X := (SX - V.OX) / V.Ppu;
    Result.Y := (V.OY - SY) / V.Ppu;
    Exit;
  end;

  if V.Kind = vkOrbit then
  begin
    UnprojectOrbit(V, SX, SY, Pl, Base, Result);
    Exit;
  end;

  { ISO.  Two screen equations, so one of the three model axes has to be
    pinned - that is what the working plane is for. }
  U := (SX - V.OX) / (V.Ppu * ISO_COS);          // = X - Y  (XY plane)
  W := (V.OY - SY) / V.Ppu;                      // = (X+Y)*sin + Z

  case Pl of
    plXY:
      begin
        Result.Z := Base.Z;
        Result.X := (U + (W - Base.Z) / ISO_SIN) / 2;
        Result.Y := ((W - Base.Z) / ISO_SIN - U) / 2;
      end;
    plXZ:
      begin
        Result.Y := Base.Y;
        Result.X := U + Base.Y;
        Result.Z := W - (Result.X + Base.Y) * ISO_SIN;
      end;
  else
    begin
      Result.X := Base.X;
      Result.Y := Base.X - U;
      Result.Z := W - (Base.X + Result.Y) * ISO_SIN;
    end;
  end;
end;

function AxisDir(Index: Integer): TP3;
begin
  case Index of
    0: Result := P3(1, 0, 0);
    1: Result := P3(-1, 0, 0);
    2: Result := P3(0, 1, 0);
    3: Result := P3(0, -1, 0);
    4: Result := P3(0, 0, 1);
  else
    Result := P3(0, 0, -1);
  end;
end;

function AxisName(Index: Integer): string;
begin
  case Index of
    0: Result := '+X';
    1: Result := '-X';
    2: Result := '+Y';
    3: Result := '-Y';
    4: Result := 'UP';
  else
    Result := 'DOWN';
  end;
end;

{ In-plane coordinates for an arc: (u, v) are the two axes of Pl. }
procedure PlaneAxes(Pl: TPlane; out AU, AV: TP3);
begin
  case Pl of
    plXY: begin AU := P3(1, 0, 0); AV := P3(0, 1, 0); end;
    plXZ: begin AU := P3(1, 0, 0); AV := P3(0, 0, 1); end;
  else
    begin AU := P3(0, 1, 0); AV := P3(0, 0, 1); end;
  end;
end;

procedure PlaneCoords(Pl: TPlane; const P: TP3; out U, W: Double);
var
  AU, AV: TP3;
begin
  PlaneAxes(Pl, AU, AV);
  U := P.X * AU.X + P.Y * AU.Y + P.Z * AU.Z;
  W := P.X * AV.X + P.Y * AV.Y + P.Z * AV.Z;
end;

function ArcPoint(const C: TP3; R, Ang: Double; Pl: TPlane): TP3;
var
  AU, AV: TP3;
  Cs, Sn: Double;
begin
  PlaneAxes(Pl, AU, AV);
  Cs := Cos(Ang) * R;
  Sn := Sin(Ang) * R;
  Result.X := C.X + AU.X * Cs + AV.X * Sn;
  Result.Y := C.Y + AU.Y * Cs + AV.Y * Sn;
  Result.Z := C.Z + AU.Z * Cs + AV.Z * Sn;
end;

function ArcFromChord(const A, B: TP3; Bulge: Double; Pl: TPlane;
  out C: TP3; out R, A0, Sweep: Double): Boolean;
var
  AU, AV: TP3;
  AUx, AUy, BUx, BUy, Ch, H, NX, NY, MX, MY, D, AngA, AngB: Double;

  procedure ToPlane(const P: TP3; out U, W: Double);
  begin
    U := P.X * AU.X + P.Y * AU.Y + P.Z * AU.Z;
    W := P.X * AV.X + P.Y * AV.Y + P.Z * AV.Z;
  end;

begin
  Result := False;
  C := A;
  R := 0;
  A0 := 0;
  Sweep := 0;
  PlaneAxes(Pl, AU, AV);
  ToPlane(A, AUx, AUy);
  ToPlane(B, BUx, BUy);

  Ch := Sqrt(Sqr(BUx - AUx) + Sqr(BUy - AUy));
  H := Bulge;
  if (Ch < 1E-9) or (Abs(H) < 1E-9) then Exit;

  NX := -(BUy - AUy) / Ch;
  NY := (BUx - AUx) / Ch;
  MX := (AUx + BUx) / 2;
  MY := (AUy + BUy) / 2;

  R := (Sqr(Ch / 2) + Sqr(H)) / (2 * Abs(H));
  D := R - Abs(H);
  if H >= 0 then
  begin
    MX := MX - NX * D;
    MY := MY - NY * D;
  end
  else
  begin
    MX := MX + NX * D;
    MY := MY + NY * D;
  end;

  { back out of the plane into model space }
  C.X := AU.X * MX + AV.X * MY;
  C.Y := AU.Y * MX + AV.Y * MY;
  C.Z := AU.Z * MX + AV.Z * MY;
  case Pl of
    plXY: C.Z := A.Z;
    plXZ: C.Y := A.Y;
    plYZ: C.X := A.X;
  end;

  AngA := ArcTan2(AUy - MY, AUx - MX);
  AngB := ArcTan2(BUy - MY, BUx - MX);
  A0 := AngA;
  Sweep := AngB - AngA;
  while Sweep <= -Pi do Sweep := Sweep + 2 * Pi;
  while Sweep > Pi do Sweep := Sweep - 2 * Pi;
  if Abs(H) > Ch / 2 then
    if Sweep > 0 then Sweep := Sweep - 2 * Pi else Sweep := Sweep + 2 * Pi;
  if ((H > 0) and (Sweep > 0)) or ((H < 0) and (Sweep < 0)) then
    if Sweep > 0 then Sweep := Sweep - 2 * Pi else Sweep := Sweep + 2 * Pi;

  Result := True;
end;

function DistToSeg2(PX, PY, AX, AY, BX, BY: Double): Double;
var
  DX, DY, T, L2: Double;
begin
  DX := BX - AX;
  DY := BY - AY;
  L2 := DX * DX + DY * DY;
  if L2 < 1E-12 then
    Exit(Sqrt(Sqr(PX - AX) + Sqr(PY - AY)));
  T := EnsureRange(((PX - AX) * DX + (PY - AY) * DY) / L2, 0, 1);
  Result := Sqrt(Sqr(PX - (AX + DX * T)) + Sqr(PY - (AY + DY * T)));
end;

{ ---------------------------------------------------------------------- }
{ TWorkDoc                                                                }
{ ---------------------------------------------------------------------- }

function TWorkDoc.GetEnt(I: Integer): TWorkEnt;
begin
  Result := FEnts[I];
end;

function TWorkDoc.Stored: Integer;
begin
  Result := Length(FEnts);
end;

{ Anything in redo space is dropped the moment you draw again. }
procedure TWorkDoc.AddLine(const A, B: TP3; Ink: TColor; Weight: Single;
  Dim: Boolean);
begin
  SetLength(FEnts, FLive + 1);
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FEnts[FLive].Kind := ekLine;
  FEnts[FLive].A := A;
  FEnts[FLive].B := B;
  FEnts[FLive].Ink := Ink;
  FEnts[FLive].Weight := Weight;
  FEnts[FLive].Dim := Dim;
  Inc(FLive);
  FSnapDirty := True;
end;

procedure TWorkDoc.AddArc(const C: TP3; R, A0, Sweep: Double; Pl: TPlane;
  Ink: TColor; Weight: Single);
begin
  SetLength(FEnts, FLive + 1);
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FEnts[FLive].Kind := ekArc;
  FEnts[FLive].C := C;
  FEnts[FLive].R := R;
  FEnts[FLive].A0 := A0;
  FEnts[FLive].Sweep := Sweep;
  FEnts[FLive].Plane := Pl;
  FEnts[FLive].A := ArcPoint(C, R, A0, Pl);
  FEnts[FLive].B := ArcPoint(C, R, A0 + Sweep, Pl);
  FEnts[FLive].Ink := Ink;
  FEnts[FLive].Weight := Weight;
  Inc(FLive);
  FSnapDirty := True;
end;

procedure TWorkDoc.AddText(const A: TP3; const S: string; Ink: TColor);
begin
  SetLength(FEnts, FLive + 1);
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FEnts[FLive].Kind := ekText;
  FEnts[FLive].A := A;
  FEnts[FLive].B := A;
  FEnts[FLive].Txt := S;
  FEnts[FLive].Ink := Ink;
  FEnts[FLive].Weight := 1;
  Inc(FLive);
  FSnapDirty := True;
end;

procedure TWorkDoc.AddDim(const A, B: TP3; Ink: TColor);
begin
  SetLength(FEnts, FLive + 1);
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FEnts[FLive].Kind := ekDim;
  FEnts[FLive].A := A;
  FEnts[FLive].B := B;
  FEnts[FLive].Ink := Ink;
  FEnts[FLive].Weight := 1;
  FEnts[FLive].Dim := True;
  Inc(FLive);
  FSnapDirty := True;
end;

procedure TWorkDoc.Delete(I: Integer);
var
  K: Integer;
begin
  if (I < 0) or (I >= FLive) then Exit;
  for K := I to FLive - 2 do
    FEnts[K] := FEnts[K + 1];
  Dec(FLive);
  SetLength(FEnts, FLive);
  FSnapDirty := True;
end;

procedure TWorkDoc.Clear;
begin
  SetLength(FEnts, 0);
  FLive := 0;
  FSnapDirty := True;
end;

procedure TWorkDoc.SetLive(N: Integer);
begin
  FLive := EnsureRange(N, 0, Length(FEnts));
  FSnapDirty := True;
end;

{ A face carries its outline in a dynamic array, and plain record assignment
  would only share the reference - so a later push/pull that rewrites those
  points in place would reach back and corrupt the undo snapshot with it.
  Every copy has to be a deep one. }
function CopyEnt(const Src: TWorkEnt): TWorkEnt;
var
  I: Integer;
begin
  Result := Src;
  Result.Poly := nil;
  SetLength(Result.Poly, Length(Src.Poly));
  for I := 0 to High(Src.Poly) do
    Result.Poly[I] := Src.Poly[I];
end;

{ Undo copies the whole document.  There are only ever a few hundred
  entities, so this is simpler and more correct than replaying edits. }
function TWorkDoc.Snapshot: TWorkEntArray;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, FLive);
  for I := 0 to FLive - 1 do
    Result[I] := CopyEnt(FEnts[I]);
end;

procedure TWorkDoc.RestoreSnap(const A: TWorkEntArray);
var
  I: Integer;
begin
  SetLength(FEnts, Length(A));
  for I := 0 to High(A) do
    FEnts[I] := CopyEnt(A[I]);
  FLive := Length(A);
  FSnapDirty := True;
end;

function TWorkDoc.FirstOfChain: Integer;
var
  I: Integer;
begin
  Result := FLive;
  for I := FLive - 1 downto 0 do
  begin
    if FEnts[I].Kind <> ekLine then Break;
    if (I < FLive - 1) and not SamePt(FEnts[I].B, FEnts[I + 1].A, 1E-6) then Break;
    Result := I;
  end;
end;

function TWorkDoc.ChainLength: Double;
var
  I: Integer;
begin
  Result := 0;
  for I := FirstOfChain to FLive - 1 do
    if FEnts[I].Kind = ekLine then
      Result := Result + Dist(FEnts[I].A, FEnts[I].B);
end;

function TWorkDoc.ChainClosed(Tol: Double): Boolean;
var
  First: Integer;
begin
  First := FirstOfChain;
  Result := (FLive - First >= 3) and
            SamePt(FEnts[FLive - 1].B, FEnts[First].A, Tol);
end;

{ Shoelace in the XY plane - only meaningful for a flat closed run. }
function TWorkDoc.ChainArea: Double;
var
  I: Integer;
  Acc: Double;
begin
  Acc := 0;
  for I := FirstOfChain to FLive - 1 do
    if FEnts[I].Kind = ekLine then
      Acc := Acc + (FEnts[I].A.X * FEnts[I].B.Y - FEnts[I].B.X * FEnts[I].A.Y);
  Result := Abs(Acc) / 2;
end;

{ ---------------------------------------------------------------------- }
{ faces and push/pull                                                      }
{ ---------------------------------------------------------------------- }

procedure TWorkDoc.AddFace(const Pts: array of TP3; Ink: TColor; Solid: Boolean);
var
  I: Integer;
begin
  if Length(Pts) < 3 then Exit;
  SetLength(FEnts, FLive + 1);
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FEnts[FLive].Kind := ekFace;
  SetLength(FEnts[FLive].Poly, Length(Pts));
  for I := 0 to High(Pts) do
    FEnts[FLive].Poly[I] := Pts[I];
  FEnts[FLive].A := Pts[0];
  FEnts[FLive].B := Pts[High(Pts)];
  FEnts[FLive].Ink := Ink;
  FEnts[FLive].Weight := 1;
  FEnts[FLive].Solid := Solid;
  Inc(FLive);
  FSnapDirty := True;
end;

{ Newell's method, which copes with slightly non-planar loops. }
function TWorkDoc.FaceNormal(Index: Integer): TP3;
var
  I, J, N: Integer;
  Acc: TP3;
begin
  Result := P3(0, 0, 1);
  if (Index < 0) or (Index >= FLive) or (FEnts[Index].Kind <> ekFace) then Exit;
  N := Length(FEnts[Index].Poly);
  if N < 3 then Exit;
  Acc := P3(0, 0, 0);
  for I := 0 to N - 1 do
  begin
    J := (I + 1) mod N;
    Acc.X := Acc.X + (FEnts[Index].Poly[I].Y - FEnts[Index].Poly[J].Y) *
                     (FEnts[Index].Poly[I].Z + FEnts[Index].Poly[J].Z);
    Acc.Y := Acc.Y + (FEnts[Index].Poly[I].Z - FEnts[Index].Poly[J].Z) *
                     (FEnts[Index].Poly[I].X + FEnts[Index].Poly[J].X);
    Acc.Z := Acc.Z + (FEnts[Index].Poly[I].X - FEnts[Index].Poly[J].X) *
                     (FEnts[Index].Poly[I].Y + FEnts[Index].Poly[J].Y);
  end;
  Result := Norm3(Acc);
end;

function TWorkDoc.FaceArea(Index: Integer): Double;
var
  I, J, N: Integer;
  Acc: TP3;
begin
  Result := 0;
  if (Index < 0) or (Index >= FLive) or (FEnts[Index].Kind <> ekFace) then Exit;
  N := Length(FEnts[Index].Poly);
  if N < 3 then Exit;
  Acc := P3(0, 0, 0);
  for I := 0 to N - 1 do
  begin
    J := (I + 1) mod N;
    Acc.X := Acc.X + FEnts[Index].Poly[I].Y * FEnts[Index].Poly[J].Z -
                     FEnts[Index].Poly[I].Z * FEnts[Index].Poly[J].Y;
    Acc.Y := Acc.Y + FEnts[Index].Poly[I].Z * FEnts[Index].Poly[J].X -
                     FEnts[Index].Poly[I].X * FEnts[Index].Poly[J].Z;
    Acc.Z := Acc.Z + FEnts[Index].Poly[I].X * FEnts[Index].Poly[J].Y -
                     FEnts[Index].Poly[I].Y * FEnts[Index].Poly[J].X;
  end;
  Result := Sqrt(Acc.X * Acc.X + Acc.Y * Acc.Y + Acc.Z * Acc.Z) / 2;
end;

{ Topmost first, so a small face sitting on a big one wins the click. }
{ Which face is under the cursor.

  This has to agree with what is on the screen, or you pick up something you
  cannot see. It used to take the most recently added face, which meant a
  wall behind a block could be grabbed through it, and which square you got
  depended on the order they were drawn in.

  So: the same back-face test the renderer uses, and then the same depth key,
  picking the largest - the face the renderer draws last is the face on top.

  The depth is taken at the cursor, not at the face's centre. Centres of two
  flat faces lying in the same plane sit at different depths, and that
  difference swamped the tiebreak: clicking a small square inside a big slab
  picked up the slab. Solving for the point on the face under the cursor puts
  coplanar faces at exactly the same depth, and then the area term does what
  it is there for and the smaller face wins.

  The point is found through Project itself rather than by inverting it:
  the projection is affine, so three points on the face plane fix the mapping
  and a 2x2 solve gives the rest. }
function TWorkDoc.HitFace(const V: TProjector; SX, SY: Double): Integer;
var
  I, J, K, N: Integer;
  Inside: Boolean;
  P: array of TPointF;
  Look, Org, U, W, Hit: TP3;
  P0, P1, P2: TPointF;
  AX, AY, BX, BY, Det, SS, TT, D, Best: Double;
begin
  Result := -1;
  Best := -1E300;
  Look := ViewDir(V);

  for I := 0 to FLive - 1 do
  begin
    if FEnts[I].Kind <> ekFace then Continue;
    N := Length(FEnts[I].Poly);
    if N < 3 then Continue;
    { the back of a solid is not drawn, so it cannot be clicked either }
    if FEnts[I].Solid and (Dot3(FaceNormal(I), Look) <= 0) then Continue;

    SetLength(P, N);
    for K := 0 to N - 1 do
      P[K] := Project(V, FEnts[I].Poly[K]);

    Inside := False;
    J := N - 1;
    for K := 0 to N - 1 do
    begin
      if ((P[K].Y > SY) <> (P[J].Y > SY)) and
         (SX < (P[J].X - P[K].X) * (SY - P[K].Y) / (P[J].Y - P[K].Y) + P[K].X) then
        Inside := not Inside;
      J := K;
    end;
    if not Inside then Continue;

    { where the cursor meets this face's plane }
    Org := FEnts[I].Poly[0];
    U := P3(FEnts[I].Poly[1].X - Org.X, FEnts[I].Poly[1].Y - Org.Y,
            FEnts[I].Poly[1].Z - Org.Z);
    W := Cross3(FaceNormal(I), U);
    P0 := Project(V, Org);
    P1 := Project(V, P3(Org.X + U.X, Org.Y + U.Y, Org.Z + U.Z));
    P2 := Project(V, P3(Org.X + W.X, Org.Y + W.Y, Org.Z + W.Z));
    AX := P1.X - P0.X; AY := P1.Y - P0.Y;
    BX := P2.X - P0.X; BY := P2.Y - P0.Y;
    Det := AX * BY - AY * BX;
    if Abs(Det) < 1E-12 then Continue;      // edge-on: nothing to click
    SS := ((SX - P0.X) * BY - (SY - P0.Y) * BX) / Det;
    TT := (AX * (SY - P0.Y) - AY * (SX - P0.X)) / Det;
    Hit := P3(Org.X + U.X * SS + W.X * TT,
              Org.Y + U.Y * SS + W.Y * TT,
              Org.Z + U.Z * SS + W.Z * TT);
    D := Dot3(Hit, Look) + 1E-6 / Max(1E-9, FaceArea(I));
    if D > Best then
    begin
      Best := D;
      Result := I;
    end;
  end;
end;

{ Lift the face along its normal and wall in the sides.  The original outline
  stays behind as the base, so what you get is a closed box - which is all
  push/pull needs to be for roughing something out. }
{ Cut one face along a segment that crosses it.

  The face is flattened into its own plane, the segment is intersected with
  each edge in turn, and if it enters and leaves exactly once the boundary is
  walked from one crossing round to the other, and then the other way, to
  give the two halves.

  Anything else is left alone. A segment that only clips a corner, that lies
  along an edge, or that stops inside the face gives no clean pair of halves,
  and half a cut is worse than none. }
function TWorkDoc.SplitFace(Index: Integer; const A, B: TP3): Boolean;
const
  EPS = 1E-9;
var
  N, I, J, K, NHit, C1, C2: Integer;
  Nm, U, V, Org, W: TP3;
  PX, PY: array of Double;
  AX, AY, BX, BY: Double;
  EX, EY, RX, RY, Den, T, Q: Double;
  HitEdge: array[0..1] of Integer;
  HitP: array[0..1] of TP3;
  Src, H1, H2: TP3Array;
  Ink: TColor;

  function Same(const P, R: TP3): Boolean;
  begin
    Result := Dist(P, R) < 1E-7;
  end;

begin
  Result := False;
  if (Index < 0) or (Index >= FLive) then Exit;
  if FEnts[Index].Kind <> ekFace then Exit;
  if FEnts[Index].Solid then Exit;          // belongs to a solid, not a drawing
  N := Length(FEnts[Index].Poly);
  if N < 3 then Exit;

  { work from a copy - the original is overwritten with one of the halves }
  SetLength(Src, N);
  for I := 0 to N - 1 do
    Src[I] := FEnts[Index].Poly[I];

  Nm := FaceNormal(Index);
  Org := Src[0];

  { the cut has to lie in the face's plane }
  W := P3(A.X - Org.X, A.Y - Org.Y, A.Z - Org.Z);
  if Abs(Dot3(W, Nm)) > 1E-6 then Exit;
  W := P3(B.X - Org.X, B.Y - Org.Y, B.Z - Org.Z);
  if Abs(Dot3(W, Nm)) > 1E-6 then Exit;

  { a basis in that plane }
  U := Norm3(P3(Src[1].X - Org.X, Src[1].Y - Org.Y, Src[1].Z - Org.Z));
  V := Cross3(Nm, U);

  SetLength(PX, N);
  SetLength(PY, N);
  for I := 0 to N - 1 do
  begin
    W := P3(Src[I].X - Org.X, Src[I].Y - Org.Y, Src[I].Z - Org.Z);
    PX[I] := Dot3(W, U);
    PY[I] := Dot3(W, V);
  end;
  W := P3(A.X - Org.X, A.Y - Org.Y, A.Z - Org.Z);
  AX := Dot3(W, U); AY := Dot3(W, V);
  W := P3(B.X - Org.X, B.Y - Org.Y, B.Z - Org.Z);
  BX := Dot3(W, U); BY := Dot3(W, V);

  RX := BX - AX;
  RY := BY - AY;
  if Sqrt(RX * RX + RY * RY) < 1E-9 then Exit;

  NHit := 0;
  for I := 0 to N - 1 do
  begin
    J := (I + 1) mod N;
    EX := PX[J] - PX[I];
    EY := PY[J] - PY[I];
    Den := RX * EY - RY * EX;
    if Abs(Den) < EPS then Continue;        // parallel, including along an edge
    T := ((PX[I] - AX) * EY - (PY[I] - AY) * EX) / Den;   // along the cut
    Q := ((PX[I] - AX) * RY - (PY[I] - AY) * RX) / Den;   // along this edge
    if (T < -1E-9) or (T > 1 + 1E-9) then Continue;
    { a crossing exactly on a vertex would be reported by both edges that
      meet there, so each edge owns its start and leaves its end to the next }
    if (Q < -1E-9) or (Q > 1 - 1E-9) then Continue;
    if NHit >= 2 then Exit;                 // more than a clean pair
    HitEdge[NHit] := I;
    HitP[NHit] := P3(Src[I].X + (Src[J].X - Src[I].X) * Q,
                     Src[I].Y + (Src[J].Y - Src[I].Y) * Q,
                     Src[I].Z + (Src[J].Z - Src[I].Z) * Q);
    Inc(NHit);
  end;

  if NHit <> 2 then Exit;
  if HitEdge[0] = HitEdge[1] then Exit;     // in and out through one edge
  if Same(HitP[0], HitP[1]) then Exit;

  Ink := FEnts[Index].Ink;

  { one half: crossing 0, round the boundary, crossing 1 }
  SetLength(H1, N + 4);
  C1 := 0;
  H1[C1] := HitP[0]; Inc(C1);
  I := HitEdge[0];
  repeat
    I := (I + 1) mod N;
    if not Same(Src[I], HitP[0]) and not Same(Src[I], HitP[1]) then
    begin
      H1[C1] := Src[I]; Inc(C1);
    end;
  until I = HitEdge[1];
  H1[C1] := HitP[1]; Inc(C1);
  SetLength(H1, C1);

  { the other half: crossing 1, round the rest, crossing 0 }
  SetLength(H2, N + 4);
  C2 := 0;
  H2[C2] := HitP[1]; Inc(C2);
  K := HitEdge[1];
  repeat
    K := (K + 1) mod N;
    if not Same(Src[K], HitP[0]) and not Same(Src[K], HitP[1]) then
    begin
      H2[C2] := Src[K]; Inc(C2);
    end;
  until K = HitEdge[0];
  H2[C2] := HitP[0]; Inc(C2);
  SetLength(H2, C2);

  if (C1 < 3) or (C2 < 3) then Exit;

  SetLength(FEnts[Index].Poly, C1);
  for I := 0 to C1 - 1 do
    FEnts[Index].Poly[I] := H1[I];
  FEnts[Index].A := H1[0];
  FEnts[Index].B := H1[C1 - 1];

  AddFace(H2, Ink, False);
  FSnapDirty := True;
  Result := True;
end;

function TWorkDoc.SplitFacesWith(const A, B: TP3): Integer;
var
  I, Was: Integer;
begin
  Result := 0;
  Was := FLive;                { only faces that were there before the cut }
  for I := Was - 1 downto 0 do
    if SplitFace(I, A, B) then Inc(Result);
end;

function TWorkDoc.PushPull(Index: Integer; Dist: Double): Boolean;
var
  I, J, N: Integer;
  Nm: TP3;
  Base, Top, Rev: TP3Array;
  Quad: array[0..3] of TP3;
  Ink: TColor;
begin
  Result := False;
  if (Index < 0) or (Index >= FLive) or (FEnts[Index].Kind <> ekFace) then Exit;
  if Abs(Dist) < 1E-9 then Exit;

  N := Length(FEnts[Index].Poly);
  if N < 3 then Exit;
  Nm := FaceNormal(Index);
  Ink := FEnts[Index].Ink;

  SetLength(Base, N);
  SetLength(Top, N);
  for I := 0 to N - 1 do
  begin
    Base[I] := FEnts[Index].Poly[I];
    Top[I] := P3(Base[I].X + Nm.X * Dist,
                 Base[I].Y + Nm.Y * Dist,
                 Base[I].Z + Nm.Z * Dist);
  end;

  { The picked face travels to the new position and a copy stays behind, so
    the result is a closed solid rather than an open shell.  The copy is
    wound the other way round so its normal points out of the solid, which is
    what lets the renderer hide the inside. }
  for I := 0 to N - 1 do
    FEnts[Index].Poly[I] := Top[I];
  FEnts[Index].Solid := True;

  SetLength(Rev, N);
  for I := 0 to N - 1 do
    Rev[I] := Base[N - 1 - I];
  AddFace(Rev, Ink, True);

  { walls, plus the edges so it reads as a solid in wireframe too }
  for I := 0 to N - 1 do
  begin
    J := (I + 1) mod N;
    Quad[0] := Base[I];
    Quad[1] := Base[J];
    Quad[2] := Top[J];
    Quad[3] := Top[I];
    AddFace(Quad, Ink, True);
    AddLine(Base[I], Top[I], Ink, 1, False);
    AddLine(Top[I], Top[J], Ink, 1, False);
  end;

  FSnapDirty := True;
  Result := True;
end;

{ The loop of chained lines ending at the last entity, if it closes. }
function TWorkDoc.ClosedChain(Tol: Double; out Pts: TP3Array): Boolean;
var
  I, First, N: Integer;
begin
  Pts := nil;
  Result := False;
  First := FirstOfChain;
  N := FLive - First;
  if N < 3 then Exit;
  if not SamePt(FEnts[FLive - 1].B, FEnts[First].A, Tol) then Exit;

  SetLength(Pts, N);
  for I := 0 to N - 1 do
    Pts[I] := FEnts[First + I].A;
  Result := True;
end;

{ Where two segments come closest.  They are treated as crossing only if
  that gap is negligible and the meeting point is properly inside both. }
function SegCross(const A1, A2, B1, B2: TP3; out P: TP3;
  out TA, TB: Double): Boolean;
var
  UX, UY, UZ, VX, VY, VZ, WX, WY, WZ: Double;
  A, B, C, D, E, Den, Scale: Double;
  PA, PB: TP3;
begin
  Result := False;
  TA := 0;
  TB := 0;
  P := A1;

  UX := A2.X - A1.X; UY := A2.Y - A1.Y; UZ := A2.Z - A1.Z;
  VX := B2.X - B1.X; VY := B2.Y - B1.Y; VZ := B2.Z - B1.Z;
  WX := A1.X - B1.X; WY := A1.Y - B1.Y; WZ := A1.Z - B1.Z;

  A := UX * UX + UY * UY + UZ * UZ;
  B := UX * VX + UY * VY + UZ * VZ;
  C := VX * VX + VY * VY + VZ * VZ;
  D := UX * WX + UY * WY + UZ * WZ;
  E := VX * VX * 0 + VX * WX + VY * WY + VZ * WZ;

  Den := A * C - B * B;
  if (Den < 1E-12) or (A < 1E-12) or (C < 1E-12) then Exit;   // parallel

  TA := (B * E - C * D) / Den;
  TB := (A * E - B * D) / Den;
  { strictly inside, so touching endpoints do not count - those are already
    endpoint snaps }
  if (TA <= 0.001) or (TA >= 0.999) or (TB <= 0.001) or (TB >= 0.999) then Exit;

  PA := P3(A1.X + UX * TA, A1.Y + UY * TA, A1.Z + UZ * TA);
  PB := P3(B1.X + VX * TB, B1.Y + VY * TB, B1.Z + VZ * TB);
  Scale := Sqrt(A) + Sqrt(C);
  if Dist(PA, PB) > Scale * 1E-6 + 1E-9 then Exit;            // skew, not crossing

  P := PA;
  Result := True;
end;

{ Rebuilt only when the document changes, because it is quadratic in the
  number of lines and the cursor asks for it on every mouse move. }
procedure TWorkDoc.RebuildSnapCache;
const
  MAX_LINES = 500;
var
  I, J, N, LineCount: Integer;
  P: TP3;
  TA, TB: Double;
  Cuts: array of array of Double;
  Idx: array of Integer;
  Tmp: Double;
  K, M: Integer;
  MidKind: TSnapKind;

  procedure Put(const Q: TP3; Kind: TSnapKind);
  begin
    if N >= Length(FSnapCache) then SetLength(FSnapCache, Max(32, N * 2));
    FSnapCache[N].P := Q;
    FSnapCache[N].Kind := Kind;
    Inc(N);
  end;

begin
  N := 0;
  SetLength(FSnapCache, 128);

  for I := 0 to FLive - 1 do
    case FEnts[I].Kind of
      ekLine:
        begin
          Put(FEnts[I].A, snEndpoint);
          Put(FEnts[I].B, snEndpoint);
        end;
      ekArc:
        begin
          Put(FEnts[I].A, snEndpoint);
          Put(FEnts[I].B, snEndpoint);
          Put(FEnts[I].C, snCentre);
        end;
      ekFace: ;
    else
      Put(FEnts[I].A, snEndpoint);
    end;

  { every line gets a list of the parameters where something crosses it }
  SetLength(Idx, FLive);
  LineCount := 0;
  for I := 0 to FLive - 1 do
    if FEnts[I].Kind = ekLine then
    begin
      Idx[LineCount] := I;
      Inc(LineCount);
    end;

  SetLength(Cuts, LineCount);
  if LineCount <= MAX_LINES then
    for I := 0 to LineCount - 2 do
      for J := I + 1 to LineCount - 1 do
        if SegCross(FEnts[Idx[I]].A, FEnts[Idx[I]].B,
                    FEnts[Idx[J]].A, FEnts[Idx[J]].B, P, TA, TB) then
        begin
          Put(P, snCross);
          SetLength(Cuts[I], Length(Cuts[I]) + 1);
          Cuts[I][High(Cuts[I])] := TA;
          SetLength(Cuts[J], Length(Cuts[J]) + 1);
          Cuts[J][High(Cuts[J])] := TB;
        end;

  { a crossed line is really several sub-segments, so give each of them a
    midpoint of its own }
  for I := 0 to LineCount - 1 do
  begin
    SetLength(Cuts[I], Length(Cuts[I]) + 2);
    Cuts[I][High(Cuts[I]) - 1] := 0;
    Cuts[I][High(Cuts[I])] := 1;
    for K := 1 to High(Cuts[I]) do
    begin
      Tmp := Cuts[I][K];
      M := K - 1;
      while (M >= 0) and (Cuts[I][M] > Tmp) do
      begin
        Cuts[I][M + 1] := Cuts[I][M];
        Dec(M);
      end;
      Cuts[I][M + 1] := Tmp;
    end;
    { an uncrossed line has one piece, and its middle is the real midpoint;
      anything else is a piece of a line and ranks well below it }
    if Length(Cuts[I]) > 2 then MidKind := snSubMid else MidKind := snMidpoint;
    for K := 0 to High(Cuts[I]) - 1 do
    begin
      Tmp := (Cuts[I][K] + Cuts[I][K + 1]) / 2;
      if Cuts[I][K + 1] - Cuts[I][K] < 1E-6 then Continue;
      Put(P3(FEnts[Idx[I]].A.X + (FEnts[Idx[I]].B.X - FEnts[Idx[I]].A.X) * Tmp,
             FEnts[Idx[I]].A.Y + (FEnts[Idx[I]].B.Y - FEnts[Idx[I]].A.Y) * Tmp,
             FEnts[Idx[I]].A.Z + (FEnts[Idx[I]].B.Z - FEnts[Idx[I]].A.Z) * Tmp),
          MidKind);
    end;
  end;

  SetLength(FSnapCache, N);
  FSnapDirty := False;
end;

procedure TWorkDoc.SnapPoints(out Pts: TP3Array);
var
  I: Integer;
begin
  if FSnapDirty then RebuildSnapCache;
  SetLength(Pts, Length(FSnapCache));
  for I := 0 to High(FSnapCache) do
    Pts[I] := FSnapCache[I].P;
end;

function TWorkDoc.Outline(const V: TProjector; I: Integer): TPointFArray;
var
  K, Steps: Integer;
  Ang: Double;
begin
  Result := nil;
  if (I < 0) or (I >= FLive) then Exit;
  case FEnts[I].Kind of
    ekArc:
      begin
        Steps := 48;
        SetLength(Result, Steps + 1);
        for K := 0 to Steps do
        begin
          Ang := FEnts[I].A0 + FEnts[I].Sweep * K / Steps;
          Result[K] := Project(V, ArcPoint(FEnts[I].C, FEnts[I].R, Ang, FEnts[I].Plane));
        end;
      end;
    ekFace:
      begin
        SetLength(Result, Length(FEnts[I].Poly) + 1);
        for K := 0 to High(FEnts[I].Poly) do
          Result[K] := Project(V, FEnts[I].Poly[K]);
        if Length(FEnts[I].Poly) > 0 then
          Result[High(Result)] := Result[0];
      end;
    ekText:
      begin
        SetLength(Result, 1);
        Result[0] := Project(V, FEnts[I].A);
      end;
  else
    begin
      SetLength(Result, 2);
      Result[0] := Project(V, FEnts[I].A);
      Result[1] := Project(V, FEnts[I].B);
    end;
  end;
end;

function TWorkDoc.HitTest(const V: TProjector; SX, SY, TolPx: Double): Integer;
var
  I, K, Steps: Integer;
  D, Best, Ang: Double;
  PA, PB: TPointF;
begin
  for I := FLive - 1 downto 0 do
  begin
    case FEnts[I].Kind of
      ekArc:
        begin
          Best := 1E30;
          Steps := 48;
          PA := Project(V, ArcPoint(FEnts[I].C, FEnts[I].R, FEnts[I].A0, FEnts[I].Plane));
          for K := 1 to Steps do
          begin
            Ang := FEnts[I].A0 + FEnts[I].Sweep * K / Steps;
            PB := Project(V, ArcPoint(FEnts[I].C, FEnts[I].R, Ang, FEnts[I].Plane));
            Best := Min(Best, DistToSeg2(SX, SY, PA.X, PA.Y, PB.X, PB.Y));
            PA := PB;
          end;
          D := Best;
        end;
      ekText:
        begin
          PA := Project(V, FEnts[I].A);
          D := Sqrt(Sqr(SX - PA.X) + Sqr(SY - PA.Y));
        end;
    else
      begin
        PA := Project(V, FEnts[I].A);
        PB := Project(V, FEnts[I].B);
        D := DistToSeg2(SX, SY, PA.X, PA.Y, PB.X, PB.Y);
      end;
    end;
    if D <= TolPx then
      Exit(I);
  end;
  Result := -1;
end;

{ One list feeds both snapping and inference, so a crossing and the
  midpoints it creates are just as snappable as an original endpoint.  A
  small bias keeps the more definite kinds winning a close contest. }
function TWorkDoc.BestSnap(const V: TProjector; SX, SY, TolPx: Double;
  out Hit: TSnapHit): Boolean;
const
  BIAS: array[TSnapKind] of Double = (0, 0, 3.5, 1.0, 2.0, 1.5, 0.25);
var
  I: Integer;
  P: TPointF;
  D, Best: Double;
begin
  if FSnapDirty then RebuildSnapCache;

  Best := 1E30;
  Hit.Kind := snNone;
  Hit.P := P3(0, 0, 0);

  for I := 0 to High(FSnapCache) do
  begin
    P := Project(V, FSnapCache[I].P);
    D := Sqrt(Sqr(SX - P.X) + Sqr(SY - P.Y));
    if D > TolPx then Continue;
    D := D - BIAS[FSnapCache[I].Kind];
    if D < Best then
    begin
      Best := D;
      Hit := FSnapCache[I];
    end;
  end;

  Result := Hit.Kind <> snNone;
end;

function TWorkDoc.Bounds(out Lo, Hi: TP3): Boolean;
var
  I, K: Integer;

  procedure Grow(const P: TP3);
  begin
    Lo.X := Min(Lo.X, P.X); Lo.Y := Min(Lo.Y, P.Y); Lo.Z := Min(Lo.Z, P.Z);
    Hi.X := Max(Hi.X, P.X); Hi.Y := Max(Hi.Y, P.Y); Hi.Z := Max(Hi.Z, P.Z);
  end;

begin
  Result := FLive > 0;
  Lo := P3(1E30, 1E30, 1E30);
  Hi := P3(-1E30, -1E30, -1E30);
  for I := 0 to FLive - 1 do
    case FEnts[I].Kind of
      ekArc:
        begin
          Grow(P3(FEnts[I].C.X - FEnts[I].R, FEnts[I].C.Y - FEnts[I].R,
                  FEnts[I].C.Z - FEnts[I].R));
          Grow(P3(FEnts[I].C.X + FEnts[I].R, FEnts[I].C.Y + FEnts[I].R,
                  FEnts[I].C.Z + FEnts[I].R));
        end;
      ekFace:
        for K := 0 to High(FEnts[I].Poly) do
          Grow(FEnts[I].Poly[K]);
    else
      begin
        Grow(FEnts[I].A);
        Grow(FEnts[I].B);
      end;
    end;
end;

{ ---------------------------------------------------------------------- }
{ persistence                                                              }
{ ---------------------------------------------------------------------- }

{ A plain text format, so a drawing stays readable and diffable, and an old
  file keeps opening after the program moves on. }

function FS: TFormatSettings;
begin
  Result := DefaultFormatSettings;
  Result.DecimalSeparator := '.';
end;

function N3(const P: TP3): string;
begin
  Result := Format('%.6f %.6f %.6f', [P.X, P.Y, P.Z], FS);
end;

function RdF(const S: string): Double;
begin
  if not TryStrToFloat(S, Result, FS) then Result := 0;
end;

procedure TWorkDoc.SaveTo(L: TStrings);
var
  I, K: Integer;
  Line: string;
begin
  for I := 0 to FLive - 1 do
    case FEnts[I].Kind of
      ekLine:
        L.Add(Format('LINE %s %s %d %.3f %d',
          [N3(FEnts[I].A), N3(FEnts[I].B), FEnts[I].Ink, FEnts[I].Weight,
           Ord(FEnts[I].Dim)], FS));
      ekArc:
        L.Add(Format('ARC %s %.6f %.6f %.6f %d %d %.3f',
          [N3(FEnts[I].C), FEnts[I].R, FEnts[I].A0, FEnts[I].Sweep,
           Ord(FEnts[I].Plane), FEnts[I].Ink, FEnts[I].Weight], FS));
      ekDim:
        L.Add(Format('DIM %s %s %d', [N3(FEnts[I].A), N3(FEnts[I].B), FEnts[I].Ink], FS));
      ekText:
        L.Add(Format('TEXT %s %d %s', [N3(FEnts[I].A), FEnts[I].Ink, FEnts[I].Txt], FS));
      ekFace:
        begin
          Line := Format('FACE %d %d %d',
            [FEnts[I].Ink, Ord(FEnts[I].Solid), Length(FEnts[I].Poly)]);
          for K := 0 to High(FEnts[I].Poly) do
            Line := Line + ' ' + N3(FEnts[I].Poly[K]);
          L.Add(Line);
        end;
    end;
end;

procedure TWorkDoc.LoadFrom(L: TStrings; var Idx: Integer);
var
  T: TStringList;
  Line, Kind: string;
  I, N: Integer;
  Pts: TP3Array;
  P: Integer;
begin
  Clear;
  T := TStringList.Create;
  try
    T.Delimiter := ' ';
    T.StrictDelimiter := True;
    while Idx < L.Count do
    begin
      Line := Trim(L[Idx]);
      if (Line = 'ENDSHEET') or (Copy(Line, 1, 6) = 'SHEET ') then Break;
      Inc(Idx);
      if Line = '' then Continue;
      T.DelimitedText := Line;
      if T.Count < 1 then Continue;
      Kind := T[0];

      if (Kind = 'LINE') and (T.Count >= 10) then
        AddLine(P3(RdF(T[1]), RdF(T[2]), RdF(T[3])),
                P3(RdF(T[4]), RdF(T[5]), RdF(T[6])),
                StrToIntDef(T[7], 0), RdF(T[8]), T[9] = '1')
      else if (Kind = 'ARC') and (T.Count >= 10) then
        AddArc(P3(RdF(T[1]), RdF(T[2]), RdF(T[3])), RdF(T[4]), RdF(T[5]),
               RdF(T[6]), TPlane(StrToIntDef(T[7], 0)),
               StrToIntDef(T[8], 0), RdF(T[9]))
      else if (Kind = 'DIM') and (T.Count >= 8) then
        AddDim(P3(RdF(T[1]), RdF(T[2]), RdF(T[3])),
               P3(RdF(T[4]), RdF(T[5]), RdF(T[6])), StrToIntDef(T[7], 0))
      else if (Kind = 'TEXT') and (T.Count >= 6) then
      begin
        { the note itself is the rest of the line, spaces and all }
        P := Pos(' ', Line);
        for I := 1 to 4 do
        begin
          P := PosEx(' ', Line, P + 1);
          if P = 0 then Break;
        end;
        if P > 0 then
          AddText(P3(RdF(T[1]), RdF(T[2]), RdF(T[3])),
                  Copy(Line, P + 1, MaxInt), StrToIntDef(T[4], 0));
      end
      else if (Kind = 'FACE') and (T.Count >= 4) then
      begin
        N := StrToIntDef(T[3], 0);
        if (N >= 3) and (T.Count >= 4 + N * 3) then
        begin
          SetLength(Pts, N);
          for I := 0 to N - 1 do
            Pts[I] := P3(RdF(T[4 + I * 3]), RdF(T[5 + I * 3]), RdF(T[6 + I * 3]));
          AddFace(Pts, StrToIntDef(T[1], 0), T[2] = '1');
        end;
      end;
    end;
  finally
    T.Free;
  end;
end;

{ SVG export - real vectors, so it opens in Inkscape or a CAD package at the
  same size it prints. }
procedure TWorkDoc.WriteSVG(L: TStrings; const V: TProjector; U: TUnitSystem);
var
  I, K, Steps: Integer;
  PA, PB: TPointF;
  Ang, MinX, MinY, MaxX, MaxY: Double;
  D: string;

  procedure Grow(const P: TPointF);
  begin
    MinX := Min(MinX, P.X); MinY := Min(MinY, P.Y);
    MaxX := Max(MaxX, P.X); MaxY := Max(MaxY, P.Y);
  end;

  function Col(C: TColor): string;
  begin
    Result := Format('#%.2x%.2x%.2x',
      [Byte(C), Byte(C shr 8), Byte(C shr 16)]);
  end;

begin
  MinX := 1E30; MinY := 1E30; MaxX := -1E30; MaxY := -1E30;
  for I := 0 to FLive - 1 do
    for K := 0 to 1 do
      if K = 0 then Grow(Project(V, FEnts[I].A)) else Grow(Project(V, FEnts[I].B));
  if MinX > MaxX then
  begin
    MinX := 0; MinY := 0; MaxX := 100; MaxY := 100;
  end;
  MinX := MinX - 30; MinY := MinY - 30; MaxX := MaxX + 30; MaxY := MaxY + 30;

  L.Add('<?xml version="1.0" encoding="UTF-8"?>');
  L.Add(Format('<svg xmlns="http://www.w3.org/2000/svg" width="%.0f" height="%.0f" ' +
    'viewBox="%.2f %.2f %.2f %.2f">',
    [MaxX - MinX, MaxY - MinY, MinX, MinY, MaxX - MinX, MaxY - MinY], FS));

  for I := 0 to FLive - 1 do
    case FEnts[I].Kind of
      ekFace:
        begin
          D := '';
          for K := 0 to High(FEnts[I].Poly) do
          begin
            PA := Project(V, FEnts[I].Poly[K]);
            D := D + Format('%.2f,%.2f ', [PA.X, PA.Y], FS);
          end;
          L.Add(Format('<polygon points="%s" fill="#d8d8d8" stroke="%s" ' +
            'stroke-width="1"/>', [Trim(D), Col(FEnts[I].Ink)]));
        end;
      ekArc:
        begin
          Steps := 64;
          D := '';
          for K := 0 to Steps do
          begin
            Ang := FEnts[I].A0 + FEnts[I].Sweep * K / Steps;
            PA := Project(V, ArcPoint(FEnts[I].C, FEnts[I].R, Ang, FEnts[I].Plane));
            D := D + Format('%.2f,%.2f ', [PA.X, PA.Y], FS);
          end;
          L.Add(Format('<polyline points="%s" fill="none" stroke="%s" ' +
            'stroke-width="%.2f"/>', [Trim(D), Col(FEnts[I].Ink), FEnts[I].Weight], FS));
        end;
      ekText:
        begin
          PA := Project(V, FEnts[I].A);
          L.Add(Format('<text x="%.2f" y="%.2f" font-family="sans-serif" ' +
            'font-size="12" fill="%s">%s</text>',
            [PA.X + 5, PA.Y - 4, Col(FEnts[I].Ink), FEnts[I].Txt], FS));
        end;
      ekLine, ekDim:
        begin
          PA := Project(V, FEnts[I].A);
          PB := Project(V, FEnts[I].B);
          L.Add(Format('<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" ' +
            'stroke="%s" stroke-width="%.2f"/>',
            [PA.X, PA.Y, PB.X, PB.Y, Col(FEnts[I].Ink), FEnts[I].Weight], FS));
          if FEnts[I].Dim then
            L.Add(Format('<text x="%.2f" y="%.2f" font-family="sans-serif" ' +
              'font-size="11" text-anchor="middle" fill="%s">%s</text>',
              [(PA.X + PB.X) / 2, (PA.Y + PB.Y) / 2 - 6, Col(FEnts[I].Ink),
               FormatLen(Dist(FEnts[I].A, FEnts[I].B), U)], FS));
        end;
    end;

  L.Add('</svg>');
end;

procedure TWorkDoc.Render(S: TArtSurface; const V: TProjector; ShowDims: Boolean;
  U: TUnitSystem; AFont: TFont; const LabelCol: TPix);
var
  I, J, K, N, Steps, NFace: Integer;
  PA, PB: TPointF;
  Ang, Sh: Double;
  Col: TPix;
  Look, Lamp, Cen, Nm: TP3;
  Order: array of Integer;
  Depth: array of Double;
  Flat: array of TPointF;

  { A dimension line parallel to the projected segment, always labelled with
    the true 3D length - which is what makes an isometric readable. }
  procedure Dimension(const A, B: TP3);
  var
    SA, SB: TPointF;
    NX, NY, L, Off, UX, UY, MX, MY: Double;
    Txt: string;
    Sz: TSize;
  begin
    SA := Project(V, A);
    SB := Project(V, B);
    L := Sqrt(Sqr(SB.X - SA.X) + Sqr(SB.Y - SA.Y));
    if L < 14 then Exit;
    UX := (SB.X - SA.X) / L;
    UY := (SB.Y - SA.Y) / L;
    NX := -UY;
    NY := UX;
    if (NY < 0) or ((Abs(NY) < 0.001) and (NX < 0)) then
    begin
      NX := -NX;
      NY := -NY;
    end;
    Off := 20;

    S.Line(SA.X + NX * 4, SA.Y + NY * 4, SA.X + NX * (Off + 5), SA.Y + NY * (Off + 5),
      1.0, LabelCol, 0.5);
    S.Line(SB.X + NX * 4, SB.Y + NY * 4, SB.X + NX * (Off + 5), SB.Y + NY * (Off + 5),
      1.0, LabelCol, 0.5);
    S.Line(SA.X + NX * Off, SA.Y + NY * Off, SB.X + NX * Off, SB.Y + NY * Off,
      1.2, LabelCol, 0.85);
    S.Line(SA.X + NX * Off - UX * 4 - NX * 4, SA.Y + NY * Off - UY * 4 - NY * 4,
           SA.X + NX * Off + UX * 4 + NX * 4, SA.Y + NY * Off + UY * 4 + NY * 4,
           1.4, LabelCol, 0.9);
    S.Line(SB.X + NX * Off - UX * 4 - NX * 4, SB.Y + NY * Off - UY * 4 - NY * 4,
           SB.X + NX * Off + UX * 4 + NX * 4, SB.Y + NY * Off + UY * 4 + NY * 4,
           1.4, LabelCol, 0.9);

    Txt := FormatLen(Dist(A, B), U);
    Sz := S.TextExtent(Txt, AFont);
    MX := (SA.X + SB.X) / 2 + NX * (Off + 3);
    MY := (SA.Y + SB.Y) / 2 + NY * (Off + 3);
    S.TextOut(Round(MX - Sz.cx / 2), Round(MY - Sz.cy / 2), Txt, AFont, LabelCol);
  end;

begin
  S.BlendMode := bmNormal;

  for I := 0 to FLive - 1 do
  begin
    Col := ColorToPix(FEnts[I].Ink);
    case FEnts[I].Kind of
      ekFace: ;   // already painted
      ekLine:
        begin
          PA := Project(V, FEnts[I].A);
          PB := Project(V, FEnts[I].B);
          S.Line(PA.X, PA.Y, PB.X, PB.Y, FEnts[I].Weight, Col);
        end;

      ekArc:
        begin
          Steps := Max(10, Round(Abs(FEnts[I].Sweep) * FEnts[I].R * V.Ppu / 4));
          Steps := Min(Steps, 1500);
          PA := Project(V, ArcPoint(FEnts[I].C, FEnts[I].R, FEnts[I].A0, FEnts[I].Plane));
          for K := 1 to Steps do
          begin
            Ang := FEnts[I].A0 + FEnts[I].Sweep * K / Steps;
            PB := Project(V, ArcPoint(FEnts[I].C, FEnts[I].R, Ang, FEnts[I].Plane));
            S.Line(PA.X, PA.Y, PB.X, PB.Y, FEnts[I].Weight, Col);
            PA := PB;
          end;
        end;

      ekText, ekDim: ;   // drawn last, so solids never hide a label
    end;
  end;

  { --- solids go on top of the edges, which is what hides the lines that
        run behind them ------------------------------------------------- }
  { --- solid faces, painter's algorithm ------------------------------- }
  NFace := 0;
  SetLength(Order, FLive);
  SetLength(Depth, FLive);
  Look := ViewDir(V);
  Lamp := Norm3(P3(0.35, -0.55, 0.75));
  for I := 0 to FLive - 1 do
    if (FEnts[I].Kind = ekFace) and (Length(FEnts[I].Poly) >= 3) then
    begin
      { A solid hides its own back faces.  The test is the winding of the
        projected outline rather than the world normal, because that cannot
        disagree with whatever projection is in use.  A lone flat face is
        double-sided and always drawn. }
      if FEnts[I].Solid and (Dot3(FaceNormal(I), Look) <= 0) then Continue;

      Cen := P3(0, 0, 0);
      for K := 0 to High(FEnts[I].Poly) do
      begin
        Cen.X := Cen.X + FEnts[I].Poly[K].X;
        Cen.Y := Cen.Y + FEnts[I].Poly[K].Y;
        Cen.Z := Cen.Z + FEnts[I].Poly[K].Z;
      end;
      K := Length(FEnts[I].Poly);
      Cen := P3(Cen.X / K, Cen.Y / K, Cen.Z / K);
      Order[NFace] := I;
      { Nudge the sort by area so that a small face lying on a big one is
        drawn after it - otherwise the slab swallows the squares drawn on
        top of it and there is nothing left to click. }
      Depth[NFace] := Dot3(Cen, Look) + 1E-6 / Max(1E-9, FaceArea(I));
      Inc(NFace);
    end;

  { farthest from the camera first }
  for I := 1 to NFace - 1 do
  begin
    K := Order[I];
    Sh := Depth[I];
    J := I - 1;
    while (J >= 0) and (Depth[J] > Sh) do
    begin
      Depth[J + 1] := Depth[J];
      Order[J + 1] := Order[J];
      Dec(J);
    end;
    Depth[J + 1] := Sh;
    Order[J + 1] := K;
  end;

  for I := 0 to NFace - 1 do
  begin
    K := Order[I];
    SetLength(Flat, Length(FEnts[K].Poly));
    for J := 0 to High(FEnts[K].Poly) do
      Flat[J] := Project(V, FEnts[K].Poly[J]);
    Nm := FaceNormal(K);
    Sh := 0.45 + 0.55 * Abs(Dot3(Nm, Lamp));
    Col := ColorToPix(FEnts[K].Ink);
    { faces read as surfaces, not ink, so they are lightened and flat-shaded }
    { Opaque in the 3D views, where a solid has to hide what is behind it.
      In plan there is nothing to hide and a filled room would just bury the
      drawing, so the fill is only a tint. }
    if V.Kind = vkPlan then
      S.FillPoly(Flat, ShadePix(MixPix(Col, Pix(255, 255, 255), 0.62), Sh), 0.16)
    else
      S.FillPoly(Flat, ShadePix(MixPix(Col, Pix(255, 255, 255), 0.62), Sh), 1.0);
    S.Poly(Flat, 1.1, Col, True, 0.9);
  end;


  { --- lines that live on a visible face -------------------------------
        The face pass runs after the edges so that a solid hides whatever is
        behind it, but that also buries the lines drawn ON its surface.
        Those are put back here: a line counts if both ends sit in the plane
        of a face that survived the culling. }
  for I := 0 to FLive - 1 do
  begin
    if FEnts[I].Kind <> ekLine then Continue;
    for J := 0 to NFace - 1 do
    begin
      K := Order[J];
      Nm := FaceNormal(K);
      Sh := Dot3(Nm, FEnts[K].Poly[0]);
      if (Abs(Dot3(Nm, FEnts[I].A) - Sh) < 1E-6) and
         (Abs(Dot3(Nm, FEnts[I].B) - Sh) < 1E-6) then
      begin
        PA := Project(V, FEnts[I].A);
        PB := Project(V, FEnts[I].B);
        S.Line(PA.X, PA.Y, PB.X, PB.Y, FEnts[I].Weight, ColorToPix(FEnts[I].Ink));
        Break;
      end;
    end;
  end;

  { --- labels, always on top ----------------------------------------- }
  for I := 0 to FLive - 1 do
    case FEnts[I].Kind of
      ekText:
        begin
          PA := Project(V, FEnts[I].A);
          S.TextOut(Round(PA.X) + 5, Round(PA.Y) - S.TextExtent('X', AFont).cy - 3,
            FEnts[I].Txt, AFont, ColorToPix(FEnts[I].Ink));
          S.Disc(PA.X, PA.Y, 2.2, ColorToPix(FEnts[I].Ink), 0.9);
        end;
      ekDim:
        Dimension(FEnts[I].A, FEnts[I].B);
      ekLine, ekArc, ekFace: ;
    end;

  if not ShowDims then Exit;
  for I := 0 to FLive - 1 do
    if (FEnts[I].Kind = ekLine) and FEnts[I].Dim then
      Dimension(FEnts[I].A, FEnts[I].B);
end;

end.
