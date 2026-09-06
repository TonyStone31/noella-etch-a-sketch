unit uFlatView;

{ A window showing a piece laid out flat.

  Deliberately plain.  It is a pattern, not a picture: solid where the metal
  gets cut, dashed where it gets folded, and the size of the sheet it needs
  written where it can be read before anybody walks to the shear. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, ExtCtrls, StdCtrls,
  uWork, uUnfold;

{ Put a pattern on screen.  Returns when the window is closed. }
procedure ShowFlatPattern(const Pat: TFlatPattern; U: TUnitSystem;
  const Caption: string);

implementation

type
  TFlatForm = class(TForm)
  public
    Pat: TFlatPattern;
    Units: TUnitSystem;
    procedure Paint; override;
  end;

procedure TFlatForm.Paint;
var
  I, J, K, H: Integer;
  Sc, OX, OY, W, HH: Double;
  HeadH, FootH: Integer;
  Pts: array of TPoint;
  S: string;

  function SX(X: Double): Integer; inline;
  begin
    Result := Round(OX + (X - Pat.MinX) * Sc);
  end;

  function SY(Y: Double): Integer; inline;
  begin
    { the sheet is drawn the way it lies, so up the page is up the sheet }
    Result := Round(OY - (Y - Pat.MinY) * Sc);
  end;

begin
  HeadH := 58;
  FootH := 34;
  Canvas.Brush.Color := clWhite;
  Canvas.FillRect(0, 0, ClientWidth, ClientHeight);

  W := Max(Pat.MaxX - Pat.MinX, 1E-9);
  HH := Max(Pat.MaxY - Pat.MinY, 1E-9);
  Sc := Min((ClientWidth - 80) / W, (ClientHeight - HeadH - FootH - 40) / HH);
  if Sc <= 0 then Sc := 1;
  OX := (ClientWidth - W * Sc) / 2;
  OY := HeadH + (ClientHeight - HeadH - FootH - HH * Sc) / 2 + HH * Sc;

  { the panels, filled faintly so the shape of the sheet reads at a glance }
  Canvas.Pen.Style := psClear;
  for I := 0 to High(Pat.Faces) do
  begin
    Canvas.Brush.Color := $00F4F0EC;
    SetLength(Pts, Length(Pat.Faces[I].P));
    for J := 0 to High(Pat.Faces[I].P) do
      Pts[J] := Point(SX(Pat.Faces[I].P[J].X), SY(Pat.Faces[I].P[J].Y));
    Canvas.Polygon(Pts);
    { and the openings, in the color of the sheet, so a window in a panel
      reads as metal that is not there rather than as a shape drawn on it }
    Canvas.Brush.Color := clWhite;
    for H := 0 to High(Pat.Faces[I].Holes) do
    begin
      SetLength(Pts, Length(Pat.Faces[I].Holes[H]));
      for J := 0 to High(Pat.Faces[I].Holes[H]) do
        Pts[J] := Point(SX(Pat.Faces[I].Holes[H][J].X),
                        SY(Pat.Faces[I].Holes[H][J].Y));
      if Length(Pts) >= 3 then Canvas.Polygon(Pts);
    end;
  end;
  Canvas.Pen.Style := psSolid;
  Canvas.Brush.Style := bsClear;

  { folds first, so a cut drawn over one still reads as a cut }
  for K := 0 to 1 do
    for I := 0 to High(Pat.Edges) do
    begin
      if (K = 0) <> (Pat.Edges[I].Kind = fkBend) then Continue;
      if Pat.Edges[I].Kind = fkBend then
      begin
        Canvas.Pen.Color := $00B07030;
        Canvas.Pen.Style := psDash;
        Canvas.Pen.Width := 1;
      end
      else
      begin
        Canvas.Pen.Color := clBlack;
        Canvas.Pen.Style := psSolid;
        Canvas.Pen.Width := 2;
      end;
      Canvas.Line(SX(Pat.Edges[I].AX), SY(Pat.Edges[I].AY),
                  SX(Pat.Edges[I].BX), SY(Pat.Edges[I].BY));
    end;
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Width := 1;

  { what it is and what it needs }
  Canvas.Font.Name := 'Sans';
  Canvas.Font.Size := 11;
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := clBlack;
  Canvas.TextOut(16, 12, Caption);

  Canvas.Font.Size := 9;
  Canvas.Font.Style := [];
  S := Format('sheet %s x %s', [FormatLen(W, Units), FormatLen(HH, Units)]);
  Canvas.TextOut(16, 34, S);

  Canvas.Font.Color := $00303030;
  S := Format('%d panels, %d folds', [Length(Pat.Faces), 0]);
  K := 0;
  for I := 0 to High(Pat.Edges) do
    if Pat.Edges[I].Kind = fkBend then Inc(K);
  S := Format('%d panels, %d folds  -  solid is cut, dashed is folded',
    [Length(Pat.Faces), K]);
  Canvas.TextOut(16, ClientHeight - 26, S);

  if Pat.Overlaps then
  begin
    Canvas.Font.Color := $000000C0;
    Canvas.Font.Style := [fsBold];
    Canvas.TextOut(16, ClientHeight - 44,
      'This pattern folds back over itself - the seam wants moving.');
  end
  else if Pat.Laid < Pat.Total then
  begin
    Canvas.Font.Color := $000000C0;
    Canvas.TextOut(16, ClientHeight - 44,
      Format('Only %d of %d panels are joined to the rest.',
        [Pat.Laid, Pat.Total]));
  end;
end;

procedure ShowFlatPattern(const Pat: TFlatPattern; U: TUnitSystem;
  const Caption: string);
var
  F: TFlatForm;
begin
  F := TFlatForm.CreateNew(nil);
  try
    F.Pat := Pat;
    F.Units := U;
    F.Caption := Caption;
    F.Width := 900;
    F.Height := 680;
    F.Position := poScreenCenter;
    F.DoubleBuffered := True;
    F.Color := clWhite;
    F.ShowModal;
  finally
    F.Free;
  end;
end;

end.
