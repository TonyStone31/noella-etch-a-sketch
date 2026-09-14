unit uDlgSkin;

{ Making a dialog look like it belongs to this program.

  The drawing area has been skinned since the first week; the dialogs never
  were, so pressing a button took you from a considered piece of chrome to
  stock GTK and back.  This is the bridge: it takes whatever theme the
  program is wearing - the same TTheme record the shell and the deck are
  painted from - and dresses BGRAControls in it, so a dialog is the same
  object as the window behind it rather than a visitor.

  Everything is applied at runtime.  Nothing here is designed in the form
  editor and nothing here is a second palette to keep in step with the first:
  there is one set of colours, in uSkin, and this reads it.

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Controls, StdCtrls, ExtCtrls, ComCtrls, Forms,
  BGRABitmap, BGRABitmapTypes, BCButton, BCPanel, BCLabel, BCTypes,
  uSkin, uSurface;

type
  { What a button is for, which decides how loudly it is painted.  A dialog
    with two equally bright buttons has not said which one you came for. }
  TBtnKind = (bkGo, bkPlain, bkQuiet);

  { Dragging a window that draws its own title bar.

    Every dialog here is borderless, so the moving is ours to do, and the
    obvious way to do it is wrong in two ways that both show as a window
    that skips about under the hand.

    The first is the anchor.  Taking the delta from the pointer's position
    *inside the title bar* assumes the window has already moved by the time
    the next motion event arrives - and on X11 it has not.  The move is a
    request to the window manager; motion that arrives before it lands is
    still measured against where the window used to be, so the delta is
    counted twice, the window overshoots, the next event corrects it, and
    the whole drag oscillates.  The pointer's position on the *screen* does
    not depend on where the window is, so an anchor taken there cannot feed
    back into itself: the window goes exactly where the hand says, however
    late the events are.

    The second is moving twice.  Setting Left and then Top is two separate
    requests to the window manager, and a compositor is free to draw the
    window between them - so it visibly steps sideways and then down, every
    frame of the drag.  One SetBounds is one move. }
  TFormDrag = record
    Live: Boolean;
    GrabX, GrabY: Integer;    { the pointer, on the screen, when it went down }
    FormX, FormY: Integer;    { where the window was at that moment }
  end;

{ Begin, continue and end a title-bar drag.  The X and Y an LCL mouse event
  carries are deliberately not used - see above. }
procedure DragBegin(out D: TFormDrag; F: TForm);
procedure DragTo(const D: TFormDrag; F: TForm);
procedure DragEnd(var D: TFormDrag);

var
  { the theme the dialogs are currently wearing, set by UseTheme }
  DlgTheme: TTheme;

{ Take the program's current theme.  Call this before building a dialog. }
procedure UseTheme(const T: TTheme);

{ A shade of a colour - Amount above 0 lightens, below 0 darkens.
  PixToColor, for turning a TPix into an LCL colour, comes from uSurface. }
function Shade(C: TColor; Amount: Double): TColor;

procedure SkinForm(F: TForm);
procedure SkinPanel(P: TBCPanel; Raised: Boolean = False; Rounding: Integer = 10);
procedure SkinButton(B: TBCButton; Kind: TBtnKind; FontH: Integer = 0);
procedure SkinLabel(L: TBCLabel; Dim: Boolean = False; FontH: Integer = 0;
  Bold: Boolean = False);
procedure SkinEdit(E: TEdit);
procedure SkinCheck(C: TCheckBox);
procedure SkinTrack(T: TTrackBar);

implementation

procedure DragBegin(out D: TFormDrag; F: TForm);
var
  P: TPoint;
begin
  P := Mouse.CursorPos;
  D.Live := True;
  D.GrabX := P.X;
  D.GrabY := P.Y;
  D.FormX := F.Left;
  D.FormY := F.Top;
end;

procedure DragTo(const D: TFormDrag; F: TForm);
var
  P: TPoint;
  NX, NY: Integer;
begin
  if not D.Live then Exit;
  P := Mouse.CursorPos;
  NX := D.FormX + (P.X - D.GrabX);
  NY := D.FormY + (P.Y - D.GrabY);
  { nothing to ask for, so do not ask - a run of motion events inside one
    pixel would otherwise be a run of window moves }
  if (NX = F.Left) and (NY = F.Top) then Exit;
  F.SetBounds(NX, NY, F.Width, F.Height);
end;

procedure DragEnd(var D: TFormDrag);
begin
  D.Live := False;
end;

procedure UseTheme(const T: TTheme);
begin
  DlgTheme := T;
end;

function Shade(C: TColor; Amount: Double): TColor;
var
  R, G, B: Integer;

  function Mix(V: Integer): Integer;
  begin
    if Amount >= 0 then Result := Round(V + (255 - V) * Amount)
    else Result := Round(V * (1 + Amount));
    if Result < 0 then Result := 0;
    if Result > 255 then Result := 255;
  end;

begin
  R := C and $FF;
  G := (C shr 8) and $FF;
  B := (C shr 16) and $FF;
  Result := TColor(Mix(R) or (Mix(G) shl 8) or (Mix(B) shl 16));
end;

procedure SkinForm(F: TForm);
begin
  F.Color := PixToColor(DlgTheme.Shell1);
  F.Font.Color := PixToColor(DlgTheme.Text);
  F.Font.Height := -13;
end;

procedure SkinPanel(P: TBCPanel; Raised: Boolean; Rounding: Integer);
var
  Base: TColor;
begin
  if Raised then Base := PixToColor(DlgTheme.PanelHi)
  else Base := PixToColor(DlgTheme.Panel);
  P.Background.Style := bbsColor;
  P.Background.Color := Base;
  { and the plain LCL colour with it.  A BCPanel paints its own background
    and leaves Color alone, but a child with ParentColor set - which a
    BCLabel has by default - reads Color, not what was painted.  So a label
    on a skinned panel was filling its own rectangle with the form's default
    grey and printing the title inside a pale box. }
  P.Color := Base;
  P.Border.Style := bboSolid;
  P.Border.Color := PixToColor(DlgTheme.Bezel1);
  P.Border.Width := 1;
  P.Rounding.RoundX := Rounding;
  P.Rounding.RoundY := Rounding;
  P.FontEx.Color := PixToColor(DlgTheme.Text);
  P.FontEx.Height := -13;
end;

{ One state of a button: the fill, the edge and the text. }
procedure OneState(S: TBCButtonState; Fill, Edge, Text: TColor);
begin
  S.Background.Style := bbsColor;
  S.Background.Color := Fill;
  S.Border.Style := bboSolid;
  S.Border.Color := Edge;
  S.Border.Width := 1;
  S.FontEx.Color := Text;
  S.FontEx.Style := [];
end;

procedure SkinButton(B: TBCButton; Kind: TBtnKind; FontH: Integer);
var
  Fill, Edge, Txt: TColor;
begin
  case Kind of
    bkGo:
      begin
        { the one you came for: the theme's own accent, with whichever of
          black or white can be read on it.  It used to take the theme's
          Shell2 on the reasoning that the accents are all bright - true of
          five themes, and in the light one it put pale grey on mid blue. }
        Fill := PixToColor(DlgTheme.Accent);
        Edge := Shade(Fill, -0.25);
        Txt := PixToColor(OnPix(DlgTheme.Accent));
      end;
    bkQuiet:
      begin
        Fill := PixToColor(DlgTheme.Panel);
        Edge := PixToColor(DlgTheme.Panel);
        Txt := PixToColor(DlgTheme.TextDim);
      end;
  else
    Fill := PixToColor(DlgTheme.PanelHi);
    Edge := PixToColor(DlgTheme.Bezel1);
    Txt := PixToColor(DlgTheme.Text);
  end;

  B.Rounding.RoundX := 8;
  B.Rounding.RoundY := 8;
  OneState(B.StateNormal, Fill, Edge, Txt);
  OneState(B.StateHover, Shade(Fill, 0.10), Shade(Edge, 0.15), Txt);
  OneState(B.StateClicked, Shade(Fill, -0.12), Edge, Txt);
  if FontH = 0 then FontH := -13;
  B.StateNormal.FontEx.Height := FontH;
  B.StateHover.FontEx.Height := FontH;
  B.StateClicked.FontEx.Height := FontH;
  B.StateNormal.FontEx.Name := 'default';
  B.StateHover.FontEx.Name := 'default';
  B.StateClicked.FontEx.Name := 'default';
end;

procedure SkinLabel(L: TBCLabel; Dim: Boolean; FontH: Integer; Bold: Boolean);
begin
  if Dim then L.FontEx.Color := PixToColor(DlgTheme.TextDim)
  else L.FontEx.Color := PixToColor(DlgTheme.Text);
  if FontH = 0 then FontH := -13;
  L.FontEx.Height := FontH;
  if Bold then L.FontEx.Style := [fsBold] else L.FontEx.Style := [];
  L.Background.Style := bbsClear;
  L.Border.Style := bboNone;
end;

procedure SkinEdit(E: TEdit);
begin
  E.Color := PixToColor(DlgTheme.Shell2);
  E.Font.Color := PixToColor(DlgTheme.Text);
  E.Font.Height := -13;
  E.BorderStyle := bsSingle;
end;

procedure SkinCheck(C: TCheckBox);
begin
  C.Color := PixToColor(DlgTheme.Panel);
  C.Font.Color := PixToColor(DlgTheme.Text);
  C.Font.Height := -13;
  C.ParentColor := False;
end;

procedure SkinTrack(T: TTrackBar);
begin
  T.Color := PixToColor(DlgTheme.Panel);
  T.ParentColor := False;
  T.ShowSelRange := False;
  T.TickStyle := tsNone;
end;

end.
