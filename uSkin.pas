unit uSkin;

{
  uSkin - the look of Noella Hazel Sketch.

  Color themes plus the chassis parts (panels, knobs, buttons, line icons).
  Everything here paints into a TArtSurface so the edges come out smooth;
  text is left to the caller because only the widgetset can render glyphs.

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Math, uSurface;

type
  TTheme = record
    Name: string;
    Shell1, Shell2: TPix;   // window background, top -> bottom
    Bezel1, Bezel2: TPix;   // frame surrounding the screen
    Panel: TPix;            // control deck panel
    PanelHi: TPix;          // panel top highlight
    Screen1, Screen2: TPix; // the drawing surface itself
    Ink: TPix;              // default pen color on this screen
    Accent: TPix;           // knob markers, active controls
    Text: TPix;
    TextDim: TPix;
    Grid: TPix;
    DarkScreen: Boolean;    // true => glow/neon effects read well
  end;

  TIconKind = (
    ikUndo, ikRedo, ikShake, ikSave, ikPrint, ikMagic,
    ikTheme, ikGrid, ikHelp, ikMirror, ikDroplet,
    ikUnits, ikDim, ikMeasure, ikOrigin,
    ikOpen, ikFit, ikExport, ikArrow,
    { one per tool, so a button and the cursor can both say which is which }
    ikTPoint, ikTLine, ikTRect, ikTArc, ikTCircle, ikTPush, ikTText,
    ikTErase, ikTMeasure, ikTOrbit, ikChevron, ikTSelect, ikTMove
  );

const
  THEME_COUNT = 6;
  { PRO uses only these two: the drawing area is white in both, because that
    is what a SketchUp model looks like and what prints.  The four playful
    ones stay for TOY, where the screen color is half the point. }
  THEME_PRO_LIGHT = 4;
  THEME_PRO_DARK  = 5;

var
  Themes: array[0..THEME_COUNT - 1] of TTheme;

{ Chassis parts. }
procedure PaintShell(S: TArtSurface; const T: TTheme);
procedure PaintBezel(S: TArtSurface; const R: TRect; const T: TTheme;
  Radius: Single = 22);
procedure PaintPanel(S: TArtSurface; const R: TRect; const T: TTheme; Radius: Single = 14);
procedure PaintKnob(S: TArtSurface; const R: TRect; Angle: Single;
  const T: TTheme; Hot: Boolean);
procedure PaintPill(S: TArtSurface; const R: TRect; Radius: Single;
  const C1, C2, Edge: TPix; Alpha: Single = 1.0);
procedure PaintSwatch(S: TArtSurface; const R: TRect; const C: TPix;
  Selected, Hot: Boolean; const T: TTheme);
procedure PaintIcon(S: TArtSurface; Kind: TIconKind; const R: TRect;
  const C: TPix; Alpha: Single = 1.0);
procedure PaintScreenPaper(S: TArtSurface; const T: TTheme; Grid: Boolean;
  RefW: Integer = 0; RefH: Integer = 0);
procedure PaintScreenWell(S: TArtSurface; const R: TRect; Radius: Single);
procedure PaintMeasuredGrid(S: TArtSurface; const T: TTheme;
  Ppu, OX, OY: Double; MajorEvery: Integer);
procedure PaintIsoGrid(S: TArtSurface; const T: TTheme;
  Ppu, OX, OY: Double; MajorEvery: Integer);

{ The model axes, in SketchUp's colors: X red, Y green, Z blue.  Index is
  0 X, 1 Y, 2 Z; anything else comes back gray. }
function AxisPix(Index: Integer): TPix;

implementation

function AxisPix(Index: Integer): TPix;
begin
  case Index of
    0: Result := Pix($E0, $46, $46);
    1: Result := Pix($3C, $B0, $54);
    2: Result := Pix($46, $78, $E6);
  else
    Result := Pix($90, $90, $98);
  end;
end;

procedure InitThemes;
begin
  { 0 - Classic: the toy everybody remembers, cleaned up. }
  with Themes[0] do
  begin
    Name := 'Classic';
    Shell1 := Pix($C4, $1B, $22);
    Shell2 := Pix($6E, $0B, $12);
    Bezel1 := Pix($3A, $3A, $40);
    Bezel2 := Pix($16, $16, $1A);
    Panel := Pix($27, $12, $16);
    PanelHi := Pix($4A, $22, $28);
    Screen1 := Pix($D8, $DA, $D2);
    Screen2 := Pix($A9, $AD, $A4);
    Ink := Pix($2A, $2C, $2A);
    Accent := Pix($FF, $D2, $4A);
    Text := Pix($FF, $EE, $EE);
    TextDim := Pix($E0, $A8, $AA);
    Grid := Pix($98, $9C, $94);
    DarkScreen := False;
  end;

  { 1 - Midnight: dark slate, neon reads beautifully here. }
  with Themes[1] do
  begin
    Name := 'Midnight';
    Shell1 := Pix($1B, $1E, $28);
    Shell2 := Pix($0B, $0D, $13);
    Bezel1 := Pix($2C, $31, $3E);
    Bezel2 := Pix($10, $12, $19);
    Panel := Pix($15, $18, $21);
    PanelHi := Pix($2A, $30, $40);
    Screen1 := Pix($0D, $10, $17);
    Screen2 := Pix($05, $06, $0A);
    Ink := Pix($4A, $F0, $E4);
    Accent := Pix($4A, $F0, $E4);
    Text := Pix($E8, $EE, $F6);
    TextDim := Pix($78, $84, $9A);
    Grid := Pix($1E, $24, $32);
    DarkScreen := True;
  end;

  { 2 - Blueprint: drafting paper. }
  with Themes[2] do
  begin
    Name := 'Blueprint';
    Shell1 := Pix($16, $2C, $4A);
    Shell2 := Pix($08, $16, $2A);
    Bezel1 := Pix($26, $3E, $60);
    Bezel2 := Pix($0C, $18, $2C);
    Panel := Pix($0E, $1E, $36);
    PanelHi := Pix($1E, $36, $58);
    Screen1 := Pix($15, $3A, $72);
    Screen2 := Pix($0C, $28, $54);
    Ink := Pix($EC, $F4, $FF);
    Accent := Pix($6E, $C8, $FF);
    Text := Pix($DE, $EC, $FF);
    TextDim := Pix($7C, $9A, $C0);
    Grid := Pix($2A, $58, $96);
    DarkScreen := True;
  end;

  { 3 - Bubblegum: Noella's pick. }
  with Themes[3] do
  begin
    Name := 'Bubblegum';
    Shell1 := Pix($E8, $63, $A8);
    Shell2 := Pix($8E, $2C, $7A);
    Bezel1 := Pix($6E, $24, $5E);
    Bezel2 := Pix($30, $0C, $28);
    Panel := Pix($5E, $1C, $52);
    PanelHi := Pix($8E, $34, $7C);
    Screen1 := Pix($FF, $F6, $FB);
    Screen2 := Pix($F2, $DC, $EA);
    Ink := Pix($C0, $1C, $84);
    Accent := Pix($FF, $E8, $58);
    Text := Pix($FF, $F0, $F8);
    TextDim := Pix($F0, $BC, $DA);
    Grid := Pix($E4, $C4, $D8);
    DarkScreen := False;
  end;

  { 4 - Light: SketchUp's own look.  Pale chrome, white paper, black lines. }
  with Themes[THEME_PRO_LIGHT] do
  begin
    Name := 'Light';
    Shell1 := Pix($E4, $E6, $E9);
    Shell2 := Pix($CF, $D3, $D8);
    Bezel1 := Pix($BF, $C4, $CA);
    Bezel2 := Pix($9F, $A6, $AE);
    Panel := Pix($EC, $EE, $F1);
    PanelHi := Pix($FF, $FF, $FF);
    Screen1 := Pix($FF, $FF, $FF);
    Screen2 := Pix($F4, $F5, $F6);
    Ink := Pix($1A, $1C, $20);
    Accent := Pix($1C, $7C, $D6);
    Text := Pix($22, $26, $2C);
    TextDim := Pix($6A, $72, $7C);
    { dark enough to read on white paper - the old value was a shade off
      the paper itself and simply vanished }
    Grid := Pix($BE, $C6, $D0);
    DarkScreen := False;
  end;

  { 5 - Dark: the same white paper, dark chrome around it. }
  with Themes[THEME_PRO_DARK] do
  begin
    Name := 'Dark';
    Shell1 := Pix($23, $26, $2C);
    Shell2 := Pix($15, $17, $1C);
    Bezel1 := Pix($33, $37, $3F);
    Bezel2 := Pix($16, $18, $1E);
    Panel := Pix($1D, $20, $27);
    PanelHi := Pix($33, $38, $43);
    Screen1 := Pix($FF, $FF, $FF);
    Screen2 := Pix($F4, $F5, $F6);
    Ink := Pix($1A, $1C, $20);
    Accent := Pix($4A, $C8, $F0);
    Text := Pix($E8, $EC, $F2);
    TextDim := Pix($8A, $93, $A0);
    { dark enough to read on white paper - the old value was a shade off
      the paper itself and simply vanished }
    Grid := Pix($BE, $C6, $D0);
    DarkScreen := False;
  end;
end;

{ ------------------------------------------------------------------------ }

procedure PaintShell(S: TArtSurface; const T: TTheme);
var
  X, Y: Integer;
  CX, CY, MaxD, D, V: Single;
  P: PPix;
  Row: TPix;
begin
  S.BlendMode := bmNormal;
  CX := S.Width / 2;
  CY := S.Height / 2;
  MaxD := Sqrt(CX * CX + CY * CY);
  if MaxD < 1 then MaxD := 1;

  { Vertical gradient plus a radial vignette, in a single pass. }
  for Y := 0 to S.Height - 1 do
  begin
    Row := MixPix(T.Shell1, T.Shell2, Y / Max(1, S.Height - 1));
    P := S.ScanLine(Y);
    for X := 0 to S.Width - 1 do
    begin
      D := Sqrt(Sqr(X - CX) + Sqr(Y - CY)) / MaxD;
      V := 1 - 0.42 * D * D;
      P^.R := Round(Row.R * V);
      P^.G := Round(Row.G * V);
      P^.B := Round(Row.B * V);
      P^.A := 255;
      Inc(P);
    end;
  end;
  S.Touch;
end;

{ Recessed frame around the drawing screen: outer bevel, inner shadow. }
{ Radius is the whole difference between a toy and an instrument.  TOY keeps
  the fat rounded frame of the thing it is pretending to be; PRO squares it
  off to something that reads as a drawing board. }
procedure PaintBezel(S: TArtSurface; const R: TRect; const T: TTheme;
  Radius: Single);
var
  I: Integer;
  Outer: TRect;
begin
  S.BlendMode := bmNormal;
  Outer := R;

  { drop shadow under the whole assembly }
  for I := 6 downto 1 do
    S.RoundRect(Rect(Outer.Left - I, Outer.Top - I + 4, Outer.Right + I,
      Outer.Bottom + I + 6), Radius + I, Pix(0, 0, 0), 0.05);

  S.RoundRectV(Outer, Radius, T.Bezel1, T.Bezel2);
  { top light catch }
  S.RoundFrame(Rect(Outer.Left + 1, Outer.Top + 1, Outer.Right - 1, Outer.Bottom - 1),
    Max(1, Radius - 1), 1.4, Pix(255, 255, 255), 0.16);
  S.RoundFrame(Outer, Radius, 1.2, Pix(0, 0, 0), 0.45);
end;

procedure PaintPanel(S: TArtSurface; const R: TRect; const T: TTheme; Radius: Single);
begin
  S.BlendMode := bmNormal;
  S.RoundRect(Rect(R.Left, R.Top + 3, R.Right, R.Bottom + 4), Radius, Pix(0, 0, 0), 0.25);
  S.RoundRectV(R, Radius, T.PanelHi, T.Panel);
  S.RoundFrame(R, Radius, 1.1, Pix(255, 255, 255), 0.10);
end;

procedure PaintPill(S: TArtSurface; const R: TRect; Radius: Single;
  const C1, C2, Edge: TPix; Alpha: Single);
begin
  S.BlendMode := bmNormal;
  S.RoundRectV(R, Radius, C1, C2, Alpha);
  S.RoundFrame(R, Radius, 1.0, Edge, Alpha * 0.85);
end;

{ The star of the show: a chunky knob you can actually grab and turn. }
procedure PaintKnob(S: TArtSurface; const R: TRect; Angle: Single;
  const T: TTheme; Hot: Boolean);
var
  CX, CY, Rad, A, I, Ridge0, Ridge1: Single;
  N, K: Integer;
  Face1, Face2: TPix;
begin
  S.BlendMode := bmNormal;
  CX := (R.Left + R.Right) / 2;
  CY := (R.Top + R.Bottom) / 2;
  Rad := Min(R.Right - R.Left, R.Bottom - R.Top) / 2 - 3;
  if Rad < 6 then Exit;

  { cast shadow }
  S.Disc(CX, CY + 4, Rad + 1, Pix(0, 0, 0), 0.28);
  S.Disc(CX, CY + 2, Rad + 1, Pix(0, 0, 0), 0.18);

  { outer collar - the dark rubber rim }
  S.DiscV(CX, CY, Rad, Pix($3C, $3C, $44), Pix($12, $12, $16));

  { grip ridges cut into the collar, rotating with the knob }
  N := 24;
  Ridge0 := Rad * 0.80;
  Ridge1 := Rad * 0.99;
  for K := 0 to N - 1 do
  begin
    A := Angle + K * (2 * Pi / N);
    S.Line(CX + Cos(A) * Ridge0, CY + Sin(A) * Ridge0,
           CX + Cos(A) * Ridge1, CY + Sin(A) * Ridge1,
           Max(2.0, Rad * 0.075), Pix($6E, $6E, $7A), 0.55);
    A := A + (Pi / N);
    S.Line(CX + Cos(A) * Ridge0, CY + Sin(A) * Ridge0,
           CX + Cos(A) * Ridge1, CY + Sin(A) * Ridge1,
           Max(1.6, Rad * 0.055), Pix(0, 0, 0), 0.45);
  end;

  { the face }
  if Hot then
  begin
    Face1 := Pix($FA, $FA, $FC);
    Face2 := Pix($C2, $C4, $CC);
  end
  else
  begin
    Face1 := Pix($EE, $EE, $F2);
    Face2 := Pix($AC, $AE, $B6);
  end;
  S.DiscV(CX, CY, Rad * 0.78, Face1, Face2);
  S.Ring(CX, CY, Rad * 0.78, 1.2, Pix(0, 0, 0), 0.30);

  { specular sweep across the top-left of the face }
  I := Rad * 0.78;
  S.Arc(CX, CY, I * 0.80, -2.5, -1.5, Max(1.6, Rad * 0.075), Pix(255, 255, 255), 0.42);
  S.Arc(CX, CY, I * 0.80, -1.5, -0.8, Max(1.6, Rad * 0.075), Pix(255, 255, 255), 0.20);

  { pointer stripe so the rotation is readable }
  S.Line(CX + Cos(Angle) * (Rad * 0.14), CY + Sin(Angle) * (Rad * 0.14),
         CX + Cos(Angle) * (Rad * 0.66), CY + Sin(Angle) * (Rad * 0.66),
         Max(3.0, Rad * 0.11), T.Accent, 0.95);

  { hub }
  S.DiscV(CX, CY, Rad * 0.20, Pix($5A, $5C, $66), Pix($26, $28, $30));
  S.Disc(CX - Rad * 0.05, CY - Rad * 0.06, Rad * 0.07, Pix(255, 255, 255), 0.45);

  if Hot then
    S.Ring(CX, CY, Rad + 2, 2.0, T.Accent, 0.75);
end;

procedure PaintSwatch(S: TArtSurface; const R: TRect; const C: TPix;
  Selected, Hot: Boolean; const T: TTheme);
var
  Rr: TRect;
begin
  S.BlendMode := bmNormal;
  Rr := R;
  if Selected then
  begin
    S.RoundRect(Rect(Rr.Left - 3, Rr.Top - 3, Rr.Right + 3, Rr.Bottom + 3), 8,
      T.Accent, 0.95);
  end
  else if Hot then
    S.RoundRect(Rect(Rr.Left - 2, Rr.Top - 2, Rr.Right + 2, Rr.Bottom + 2), 7,
      Pix(255, 255, 255), 0.40);

  S.RoundRectV(Rr, 5, ShadePix(C, 1.14), ShadePix(C, 0.86));
  S.RoundFrame(Rr, 5, 1.0, Pix(0, 0, 0), 0.35);
  S.Line(Rr.Left + 2, Rr.Top + 2, Rr.Right - 3, Rr.Top + 2, 1.4,
    Pix(255, 255, 255), 0.22);
end;

{ ------------------------------------------------------------------------ }
{ line icons - all stroked, so they scale and stay crisp                    }
{ ------------------------------------------------------------------------ }

procedure PaintIcon(S: TArtSurface; Kind: TIconKind; const R: TRect;
  const C: TPix; Alpha: Single);
var
  X, Y, W, H, U, CX, CY, LW, RR: Single;

  function Px(FX, FY: Single): TPointF;
  begin
    Result := PtF(X + FX * W, Y + FY * H);
  end;

var
  P: TPointF;
begin
  S.BlendMode := bmNormal;
  X := R.Left;
  Y := R.Top;
  W := R.Right - R.Left;
  H := R.Bottom - R.Top;
  U := Min(W, H);
  CX := X + W / 2;
  CY := Y + H / 2;
  LW := Max(1.6, U * 0.11);

  case Kind of
    ikTPoint:
      begin
        S.Ring(CX, CY, U * 0.17, LW, C, Alpha);
        S.Disc(CX, CY, LW * 0.7, C, Alpha);
      end;

    { the usual arrow, pointing up and to the left }
    ikTSelect:
      S.Poly([Px(0.30, 0.16), Px(0.30, 0.80), Px(0.46, 0.64), Px(0.57, 0.86),
              Px(0.67, 0.80), Px(0.56, 0.60), Px(0.74, 0.58)],
        LW, C, True, Alpha);

    { four arrowheads on a cross - move in any direction }
    ikTMove:
      begin
        S.Line(CX, Y + H * 0.18, CX, Y + H * 0.82, LW, C, Alpha);
        S.Line(X + W * 0.18, CY, X + W * 0.82, CY, LW, C, Alpha);
        S.Line(CX, Y + H * 0.18, CX - U * 0.11, Y + H * 0.30, LW, C, Alpha);
        S.Line(CX, Y + H * 0.18, CX + U * 0.11, Y + H * 0.30, LW, C, Alpha);
        S.Line(CX, Y + H * 0.82, CX - U * 0.11, Y + H * 0.70, LW, C, Alpha);
        S.Line(CX, Y + H * 0.82, CX + U * 0.11, Y + H * 0.70, LW, C, Alpha);
        S.Line(X + W * 0.18, CY, X + W * 0.30, CY - U * 0.11, LW, C, Alpha);
        S.Line(X + W * 0.18, CY, X + W * 0.30, CY + U * 0.11, LW, C, Alpha);
        S.Line(X + W * 0.82, CY, X + W * 0.70, CY - U * 0.11, LW, C, Alpha);
        S.Line(X + W * 0.82, CY, X + W * 0.70, CY + U * 0.11, LW, C, Alpha);
      end;

    ikTLine:
      begin
        S.Line(X + W * 0.22, Y + H * 0.74, X + W * 0.78, Y + H * 0.26, LW, C, Alpha);
        S.Disc(X + W * 0.22, Y + H * 0.74, LW * 0.9, C, Alpha);
        S.Disc(X + W * 0.78, Y + H * 0.26, LW * 0.9, C, Alpha);
      end;

    ikTRect:
      S.Poly([Px(0.20, 0.28), Px(0.80, 0.28), Px(0.80, 0.72), Px(0.20, 0.72)],
        LW, C, True, Alpha);

    ikTArc:
      begin
        S.Arc(CX, Y + H * 0.78, U * 0.34, Pi, 2 * Pi, LW, C, Alpha);
        S.Line(X + W * 0.16, Y + H * 0.78, X + W * 0.84, Y + H * 0.78,
          LW * 0.7, C, Alpha * 0.55);
      end;

    ikTCircle:
      S.Ring(CX, CY, U * 0.30, LW, C, Alpha);

    ikTPush:
      begin
        S.Poly([Px(0.24, 0.62), Px(0.52, 0.74), Px(0.80, 0.62), Px(0.52, 0.50)],
          LW * 0.8, C, True, Alpha);
        S.Line(CX, Y + H * 0.50, CX, Y + H * 0.20, LW, C, Alpha);
        S.Poly([PtF(CX - U * 0.11, Y + H * 0.31), PtF(CX, Y + H * 0.18),
                PtF(CX + U * 0.11, Y + H * 0.31)], LW, C, False, Alpha);
      end;

    ikTText:
      begin
        S.Line(X + W * 0.24, Y + H * 0.28, X + W * 0.76, Y + H * 0.28, LW, C, Alpha);
        S.Line(CX, Y + H * 0.28, CX, Y + H * 0.74, LW, C, Alpha);
      end;

    ikTErase:
      begin
        S.Poly([Px(0.20, 0.66), Px(0.52, 0.30), Px(0.80, 0.50), Px(0.48, 0.76)],
          LW, C, True, Alpha);
        S.Line(X + W * 0.30, Y + H * 0.78, X + W * 0.82, Y + H * 0.78,
          LW * 0.8, C, Alpha * 0.6);
      end;

    ikTMeasure:
      begin
        S.Poly([Px(0.16, 0.40), Px(0.84, 0.40), Px(0.84, 0.62), Px(0.16, 0.62)],
          LW * 0.8, C, True, Alpha);
        S.Line(X + W * 0.34, Y + H * 0.40, X + W * 0.34, Y + H * 0.52, LW * 0.7, C, Alpha);
        S.Line(X + W * 0.50, Y + H * 0.40, X + W * 0.50, Y + H * 0.55, LW * 0.7, C, Alpha);
        S.Line(X + W * 0.66, Y + H * 0.40, X + W * 0.66, Y + H * 0.52, LW * 0.7, C, Alpha);
      end;

    ikTOrbit:
      begin
        S.Ring(CX, CY, U * 0.30, LW * 0.9, C, Alpha);
        S.Arc(CX, CY, U * 0.30, Pi * 0.15, Pi * 0.85, LW * 0.5, C, Alpha * 0.5);
        S.Disc(CX + U * 0.30, CY, LW * 1.1, C, Alpha);
      end;

    ikChevron:
      S.Poly([PtF(CX - U * 0.16, CY - U * 0.08), PtF(CX, CY + U * 0.10),
              PtF(CX + U * 0.16, CY - U * 0.08)], LW, C, False, Alpha);

    ikUndo, ikRedo:
      begin
        if Kind = ikUndo then
        begin
          S.Arc(CX, CY + U * 0.06, U * 0.30, Pi * 1.05, Pi * 2.35, LW, C, Alpha);
          P := PtF(CX - U * 0.30, CY - U * 0.20);
          S.Poly([PtF(P.X - U * 0.13, P.Y + U * 0.02),
                  P,
                  PtF(P.X + U * 0.05, P.Y + U * 0.17)], LW, C, False, Alpha);
        end
        else
        begin
          S.Arc(CX, CY + U * 0.06, U * 0.30, Pi * 0.65, Pi * 1.95, LW, C, Alpha);
          P := PtF(CX + U * 0.30, CY - U * 0.20);
          S.Poly([PtF(P.X + U * 0.13, P.Y + U * 0.02),
                  P,
                  PtF(P.X - U * 0.05, P.Y + U * 0.17)], LW, C, False, Alpha);
        end;
      end;

    ikShake:
      begin
        S.RoundFrame(Rect(Round(X + W * 0.28), Round(Y + H * 0.24),
                          Round(X + W * 0.72), Round(Y + H * 0.76)),
                     U * 0.10, LW, C, Alpha);
        S.Arc(X + W * 0.18, CY, U * 0.16, Pi * 0.55, Pi * 1.45, LW * 0.8, C, Alpha * 0.8);
        S.Arc(X + W * 0.82, CY, U * 0.16, -Pi * 0.45, Pi * 0.45, LW * 0.8, C, Alpha * 0.8);
      end;

    ikSave:
      begin
        S.Poly([Px(0.24, 0.60), Px(0.24, 0.78), Px(0.76, 0.78), Px(0.76, 0.60)],
          LW, C, False, Alpha);
        S.Line(CX, Y + H * 0.20, CX, Y + H * 0.58, LW, C, Alpha);
        S.Poly([Px(0.34, 0.44), Px(0.50, 0.60), Px(0.66, 0.44)], LW, C, False, Alpha);
      end;

    ikPrint:
      begin
        S.Poly([Px(0.30, 0.36), Px(0.30, 0.20), Px(0.70, 0.20), Px(0.70, 0.36)],
          LW, C, False, Alpha);
        S.RoundFrame(Rect(Round(X + W * 0.18), Round(Y + H * 0.36),
                          Round(X + W * 0.82), Round(Y + H * 0.66)),
                     U * 0.08, LW, C, Alpha);
        S.RoundFrame(Rect(Round(X + W * 0.32), Round(Y + H * 0.60),
                          Round(X + W * 0.68), Round(Y + H * 0.84)),
                     U * 0.05, LW, C, Alpha);
      end;

    ikMagic:
      begin
        S.Line(X + W * 0.22, Y + H * 0.80, X + W * 0.62, Y + H * 0.38, LW, C, Alpha);
        S.Line(X + W * 0.72, Y + H * 0.14, X + W * 0.72, Y + H * 0.40, LW * 0.8, C, Alpha);
        S.Line(X + W * 0.59, Y + H * 0.27, X + W * 0.85, Y + H * 0.27, LW * 0.8, C, Alpha);
        S.Line(X + W * 0.30, Y + H * 0.14, X + W * 0.30, Y + H * 0.30, LW * 0.6, C, Alpha * 0.8);
        S.Line(X + W * 0.22, Y + H * 0.22, X + W * 0.38, Y + H * 0.22, LW * 0.6, C, Alpha * 0.8);
      end;

    ikTheme:
      begin
        { a contrast disc: outlined circle with one half filled }
        S.Ring(CX, CY, U * 0.32, LW, C, Alpha);
        RR := 0;
        while RR < U * 0.30 do
        begin
          S.Arc(CX, CY, RR, -Pi / 2, Pi / 2, 1.3, C, Alpha);
          RR := RR + 0.6;
        end;
      end;

    ikGrid:
      begin
        S.RoundFrame(Rect(Round(X + W * 0.22), Round(Y + H * 0.22),
                          Round(X + W * 0.78), Round(Y + H * 0.78)),
                     U * 0.06, LW * 0.9, C, Alpha);
        S.Line(CX, Y + H * 0.22, CX, Y + H * 0.78, LW * 0.7, C, Alpha * 0.85);
        S.Line(X + W * 0.22, CY, X + W * 0.78, CY, LW * 0.7, C, Alpha * 0.85);
      end;

    ikHelp:
      begin
        S.Ring(CX, CY, U * 0.34, LW * 0.9, C, Alpha);
        S.Arc(CX, CY - U * 0.10, U * 0.13, Pi * 0.95, Pi * 2.15, LW * 0.9, C, Alpha);
        S.Line(CX + U * 0.005, CY - U * 0.01, CX + U * 0.005, CY + U * 0.10, LW * 0.9, C, Alpha);
        S.Disc(CX, CY + U * 0.21, LW * 0.55, C, Alpha);
      end;

    ikMirror:
      begin
        S.Line(CX, Y + H * 0.14, CX, Y + H * 0.86, LW * 0.75, C, Alpha * 0.7);
        S.Triangle(PtF(CX - U * 0.10, CY - U * 0.22), PtF(CX - U * 0.10, CY + U * 0.22),
                   PtF(CX - U * 0.34, CY), C, Alpha);
        S.Triangle(PtF(CX + U * 0.10, CY - U * 0.22), PtF(CX + U * 0.10, CY + U * 0.22),
                   PtF(CX + U * 0.34, CY), C, Alpha * 0.55);
      end;

    ikUnits:
      begin
        { a ruler with tick marks }
        S.RoundFrame(Rect(Round(X + W * 0.14), Round(Y + H * 0.36),
                          Round(X + W * 0.86), Round(Y + H * 0.64)),
                     U * 0.05, LW * 0.9, C, Alpha);
        S.Line(X + W * 0.30, Y + H * 0.36, X + W * 0.30, Y + H * 0.52, LW * 0.7, C, Alpha);
        S.Line(X + W * 0.44, Y + H * 0.36, X + W * 0.44, Y + H * 0.46, LW * 0.7, C, Alpha);
        S.Line(X + W * 0.58, Y + H * 0.36, X + W * 0.58, Y + H * 0.52, LW * 0.7, C, Alpha);
        S.Line(X + W * 0.72, Y + H * 0.36, X + W * 0.72, Y + H * 0.46, LW * 0.7, C, Alpha);
      end;

    ikDim:
      begin
        { a dimension line between two extension lines }
        S.Line(X + W * 0.20, Y + H * 0.22, X + W * 0.20, Y + H * 0.72, LW * 0.7, C, Alpha * 0.8);
        S.Line(X + W * 0.80, Y + H * 0.22, X + W * 0.80, Y + H * 0.72, LW * 0.7, C, Alpha * 0.8);
        S.Line(X + W * 0.20, Y + H * 0.60, X + W * 0.80, Y + H * 0.60, LW * 0.9, C, Alpha);
        S.Triangle(PtF(X + W * 0.20, CY + U * 0.10),
                   PtF(X + W * 0.34, CY + U * 0.02),
                   PtF(X + W * 0.34, CY + U * 0.19), C, Alpha);
        S.Triangle(PtF(X + W * 0.80, CY + U * 0.10),
                   PtF(X + W * 0.66, CY + U * 0.02),
                   PtF(X + W * 0.66, CY + U * 0.19), C, Alpha);
      end;

    ikMeasure:
      begin
        { calipers }
        S.Line(X + W * 0.16, Y + H * 0.30, X + W * 0.84, Y + H * 0.30, LW, C, Alpha);
        S.Line(X + W * 0.24, Y + H * 0.30, X + W * 0.24, Y + H * 0.78, LW, C, Alpha);
        S.Line(X + W * 0.66, Y + H * 0.30, X + W * 0.66, Y + H * 0.66, LW, C, Alpha);
        S.Line(X + W * 0.16, Y + H * 0.20, X + W * 0.16, Y + H * 0.40, LW * 0.8, C, Alpha);
        S.Line(X + W * 0.84, Y + H * 0.20, X + W * 0.84, Y + H * 0.40, LW * 0.8, C, Alpha);
      end;

    ikOrigin:
      begin
        S.Ring(CX, CY, U * 0.20, LW * 0.9, C, Alpha);
        S.Line(CX - U * 0.38, CY, CX - U * 0.26, CY, LW * 0.9, C, Alpha);
        S.Line(CX + U * 0.26, CY, CX + U * 0.38, CY, LW * 0.9, C, Alpha);
        S.Line(CX, CY - U * 0.38, CX, CY - U * 0.26, LW * 0.9, C, Alpha);
        S.Line(CX, CY + U * 0.26, CX, CY + U * 0.38, LW * 0.9, C, Alpha);
      end;

    ikOpen:
      begin
        { a folder }
        S.Poly([Px(0.16, 0.74), Px(0.16, 0.30), Px(0.42, 0.30), Px(0.50, 0.40),
                Px(0.84, 0.40), Px(0.84, 0.74)], LW * 0.9, C, True, Alpha);
      end;

    ikFit:
      begin
        S.RoundFrame(Rect(Round(X + W * 0.20), Round(Y + H * 0.24),
                          Round(X + W * 0.80), Round(Y + H * 0.76)),
                     U * 0.06, LW * 0.8, C, Alpha * 0.6);
        S.Line(CX - U * 0.20, CY - U * 0.10, CX - U * 0.20, CY - U * 0.20, LW, C, Alpha);
        S.Line(CX - U * 0.20, CY - U * 0.20, CX - U * 0.10, CY - U * 0.20, LW, C, Alpha);
        S.Line(CX + U * 0.20, CY + U * 0.10, CX + U * 0.20, CY + U * 0.20, LW, C, Alpha);
        S.Line(CX + U * 0.20, CY + U * 0.20, CX + U * 0.10, CY + U * 0.20, LW, C, Alpha);
        S.Line(CX - U * 0.18, CY - U * 0.18, CX + U * 0.18, CY + U * 0.18, LW * 0.8, C, Alpha);
      end;

    ikExport:
      begin
        S.Poly([Px(0.24, 0.62), Px(0.24, 0.80), Px(0.76, 0.80), Px(0.76, 0.62)],
          LW, C, False, Alpha);
        S.Line(CX, Y + H * 0.66, CX, Y + H * 0.24, LW, C, Alpha);
        S.Poly([Px(0.34, 0.40), Px(0.50, 0.24), Px(0.66, 0.40)], LW, C, False, Alpha);
      end;

    ikArrow:
      begin
        S.Poly([Px(0.30, 0.16), Px(0.30, 0.78), Px(0.45, 0.63),
                Px(0.56, 0.84), Px(0.66, 0.79), Px(0.55, 0.59), Px(0.74, 0.55)],
          LW * 0.85, C, True, Alpha);
      end;

    ikDroplet:
      begin
        S.Arc(CX, CY + U * 0.08, U * 0.26, 0, 2 * Pi, LW, C, Alpha);
        S.Poly([PtF(CX - U * 0.185, CY - U * 0.10), PtF(CX, CY - U * 0.36),
                PtF(CX + U * 0.185, CY - U * 0.10)], LW, C, False, Alpha);
      end;
  end;
end;

{ A fresh sheet of aluminium powder.

  RefW/RefH let the caller anchor the gradient and the grid to a different
  size than the surface.  After a window resize the old drawing is pasted back
  on top, and anchoring to the old size is what makes the newly uncovered
  strip line up with it instead of showing a seam. }
procedure PaintScreenPaper(S: TArtSurface; const T: TTheme; Grid: Boolean;
  RefW: Integer; RefH: Integer);
var
  X, Y, Step: Integer;
  C: TPix;
  P: PPix;
begin
  if RefW <= 0 then RefW := S.Width;
  if RefH <= 0 then RefH := S.Height;
  S.BlendMode := bmNormal;

  for Y := 0 to S.Height - 1 do
  begin
    C := MixPix(T.Screen1, T.Screen2, EnsureRange(Y / Max(1, RefH - 1), 0, 1));
    P := S.ScanLine(Y);
    for X := 0 to S.Width - 1 do
    begin
      P^ := C;
      P^.A := 255;
      Inc(P);
    end;
  end;
  S.Touch;

  { faint speckle so a light screen reads as powder, not paper }
  if not T.DarkScreen then
    S.Grain(0.05, 0.16);

  if Grid then
  begin
    Step := 40;
    X := Step;
    while X < S.Width do
    begin
      S.Line(X, 0, X, S.Height, 1.0, T.Grid, IfThen(T.DarkScreen, 0.55, 0.85));
      Inc(X, Step);
    end;
    Y := Step;
    while Y < S.Height do
    begin
      S.Line(0, Y, S.Width, Y, 1.0, T.Grid, IfThen(T.DarkScreen, 0.55, 0.85));
      Inc(Y, Step);
    end;
  end;
  S.Touch;
end;

{ The recess around the screen opening.  This is painted on the chassis, not
  on the sketch, so it never gets baked into the artwork. }
procedure PaintScreenWell(S: TArtSurface; const R: TRect; Radius: Single);
var
  I: Integer;
begin
  S.BlendMode := bmNormal;
  for I := 0 to 9 do
    S.RoundFrame(Rect(R.Left - I, R.Top - I, R.Right + I, R.Bottom + I),
      Radius + I, 1.0, Pix(0, 0, 0), 0.07 * (1 - I / 11));
  S.RoundFrame(Rect(R.Left - 1, R.Top - 1, R.Right + 1, R.Bottom + 1),
    Radius, 1.2, Pix(0, 0, 0), 0.5);
  S.Touch;
end;

{ A grid in real units, anchored to the drawing origin so the lines land on
  whole feet (or metres) no matter where the paper has been panned to. }
procedure PaintMeasuredGrid(S: TArtSurface; const T: TTheme;
  Ppu, OX, OY: Double; MajorEvery: Integer);
var
  I, First, Last: Integer;
  V: Double;
  Major: Boolean;
begin
  if Ppu < 3 then Exit;          // too dense to be anything but noise
  S.BlendMode := bmNormal;

  First := Floor(-OX / Ppu);
  Last := Ceil((S.Width - OX) / Ppu);
  for I := First to Last do
  begin
    V := OX + I * Ppu;
    Major := (MajorEvery > 0) and (I mod MajorEvery = 0);
    if Major then
      S.Line(V, 0, V, S.Height, 1.0, T.Grid, 0.85)
    else if Ppu >= 7 then
      S.Line(V, 0, V, S.Height, 1.0, T.Grid, 0.34);
  end;

  First := Floor((OY - S.Height) / Ppu);
  Last := Ceil(OY / Ppu);
  for I := First to Last do
  begin
    V := OY - I * Ppu;
    Major := (MajorEvery > 0) and (I mod MajorEvery = 0);
    if Major then
      S.Line(0, V, S.Width, V, 1.0, T.Grid, 0.85)
    else if Ppu >= 7 then
      S.Line(0, V, S.Width, V, 1.0, T.Grid, 0.34);
  end;

  { the origin itself gets an axis cross }
  S.Line(OX, 0, OX, S.Height, 1.4, T.Accent, 0.35);
  S.Line(0, OY, S.Width, OY, 1.4, T.Accent, 0.35);
  S.Touch;
end;

{ The 30 degree lattice an isometric is drawn on, plus the three axes rising
  from the origin. }
procedure PaintIsoGrid(S: TArtSurface; const T: TTheme;
  Ppu, OX, OY: Double; MajorEvery: Integer);
const
  C30 = 0.86602540378443865;
  S30 = 0.5;
var
  I, Span: Integer;
  DX, DY, L, A: Double;
  Major: Boolean;
begin
  if Ppu < 4 then Exit;
  S.BlendMode := bmNormal;
  L := (S.Width + S.Height) * 1.2;
  Span := Ceil(L / (Ppu * C30)) + 2;

  for I := -Span to Span do
  begin
    Major := (MajorEvery > 0) and (I mod MajorEvery = 0);
    if not Major and (Ppu < 9) then Continue;
    { On white paper a quarter-strength gray line is barely a shade off the
      sheet, which is why the isometric lattice went missing when PRO turned
      white.  A dark screen needs the opposite - a bright grid at that
      strength would shout. }
    if T.DarkScreen then
    begin
      if Major then A := 0.7 else A := 0.26;
    end
    else
    begin
      if Major then A := 0.95 else A := 0.5;
    end;

    { Lines running along +X (down-right), stepped along +Y.  +Y projects to
      (-C30, +S30): stepping by (-C30, -S30) instead put every line of the
      family exactly on top of the last one, because that is the -X
      direction - so the isometric paper has always been two lines. }
    DX := OX - I * C30 * Ppu;
    DY := OY + I * S30 * Ppu;
    S.Line(DX - L * C30, DY - L * S30, DX + L * C30, DY + L * S30, 1.0, T.Grid, A);
    { lines running along +Y (down-left), stepped along +X }
    DX := OX + I * C30 * Ppu;
    DY := OY + I * S30 * Ppu;
    S.Line(DX + L * C30, DY - L * S30, DX - L * C30, DY + L * S30, 1.0, T.Grid, A);
  end;

  { No axes here.  Isometric is a drafting projection - what it wants is
    isometric paper, the way plan gets a measured grid.  The colored axes
    belong to the orbit view, where they are the only thing saying which way
    is which. }
  S.Touch;
end;

initialization
  InitThemes;

end.
