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
procedure SkinCombo(C: TComboBox);
procedure SkinTrack(T: TTrackBar);

implementation

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
        { the one you came for: the theme's own accent, and dark text on it
          because the accents here are bright }
        Fill := PixToColor(DlgTheme.Accent);
        Edge := Shade(Fill, -0.25);
        Txt := PixToColor(DlgTheme.Shell2);
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

procedure SkinCombo(C: TComboBox);
begin
  C.Color := PixToColor(DlgTheme.Shell2);
  C.Font.Color := PixToColor(DlgTheme.Text);
  C.Font.Height := -13;
  C.Style := csDropDownList;
end;

procedure SkinTrack(T: TTrackBar);
begin
  T.Color := PixToColor(DlgTheme.Panel);
  T.ParentColor := False;
  T.ShowSelRange := False;
  T.TickStyle := tsNone;
end;

end.
