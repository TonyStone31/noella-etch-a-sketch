unit uPreview;

{ A corner view of a drawing on an ordinary canvas: what the wizards show
  beside their inputs, built by the same code that builds the real thing and
  projected from in front, to the right and above.  Faces are painted far
  to near so the near ones cover the far ones; every edge is drawn on top,
  soft ones faintly, so a curve reads as a curve and not as a cage. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Graphics, uWork;

procedure PaintDocIso(C: TCanvas; W, H: Integer; D: TWorkDoc;
  const Title, Foot: string);

implementation

procedure PaintDocIso(C: TCanvas; W, H: Integer; D: TWorkDoc;
  const Title, Foot: string);
const
  CX = 0.866;
var
  I, J, Margin, N: Integer;
  MinX, MaxX, MinY, MaxY, Sc: Double;
  Order: array of Integer;
  Depth: array of Double;
  Pts: array of TPoint;
  Sw: Boolean;

  function PX(const P: TP3): Double; begin Result := (P.X + P.Y) * CX; end;
  function PY(const P: TP3): Double; begin Result := -P.Z + (P.X - P.Y) * 0.5; end;
  function SX(const P: TP3): Integer; begin Result := Round(Margin + (PX(P) - MinX) * Sc); end;
  function SY(const P: TP3): Integer; begin Result := Round(Margin + (PY(P) - MinY) * Sc); end;
  function Near(const P: TP3): Double; begin Result := P.X - P.Y + P.Z; end;

begin
  C.Brush.Color := clWhite;
  C.FillRect(0, 0, W, H);
  C.Pen.Color := clSilver;
  C.Rectangle(0, 0, W, H);
  Margin := 16;
  MinX := 1E30; MaxX := -1E30; MinY := 1E30; MaxY := -1E30;
  for I := 0 to D.Live - 1 do
    if D[I].Kind = ekLine then
    begin
      MinX := Min(MinX, Min(PX(D[I].A), PX(D[I].B)));
      MaxX := Max(MaxX, Max(PX(D[I].A), PX(D[I].B)));
      MinY := Min(MinY, Min(PY(D[I].A), PY(D[I].B)));
      MaxY := Max(MaxY, Max(PY(D[I].A), PY(D[I].B)));
    end;
  if MaxX <= MinX then Exit;
  Sc := Min((W - 2 * Margin) / Max(MaxX - MinX, 1E-9),
            (H - 2 * Margin) / Max(MaxY - MinY, 1E-9));
  SetLength(Order, 0);
  SetLength(Depth, 0);
  for I := 0 to D.Live - 1 do
    if D[I].Kind = ekFace then
    begin
      SetLength(Order, Length(Order) + 1);
      SetLength(Depth, Length(Depth) + 1);
      Order[High(Order)] := I;
      Depth[High(Depth)] := 0;
      for J := 0 to High(D[I].Poly) do
        Depth[High(Depth)] := Depth[High(Depth)] + Near(D[I].Poly[J]) / Length(D[I].Poly);
    end;
  { far to near }
  repeat
    Sw := False;
    for I := 0 to High(Order) - 1 do
      if Depth[I] > Depth[I + 1] then
      begin
        N := Order[I]; Order[I] := Order[I + 1]; Order[I + 1] := N;
        Sc := Depth[I]; Depth[I] := Depth[I + 1]; Depth[I + 1] := Sc;
        Sw := True;
      end;
  until not Sw;
  Sc := Min((W - 2 * Margin) / Max(MaxX - MinX, 1E-9),
            (H - 2 * Margin) / Max(MaxY - MinY, 1E-9));
  C.Pen.Color := $00B0B0B0;
  C.Pen.Width := 1;
  for I := 0 to High(Order) do
  begin
    SetLength(Pts, Length(D[Order[I]].Poly));
    for J := 0 to High(Pts) do
      Pts[J] := Point(SX(D[Order[I]].Poly[J]), SY(D[Order[I]].Poly[J]));
    C.Brush.Color := $00F0ECE6;
    C.Brush.Style := bsSolid;
    C.Polygon(Pts);
  end;
  C.Brush.Style := bsClear;
  { soft edges faintly, then the hard ones over them }
  C.Pen.Color := $00D0D0D0;
  for I := 0 to D.Live - 1 do
    if (D[I].Kind = ekLine) and D[I].Soft then
      C.Line(SX(D[I].A), SY(D[I].A), SX(D[I].B), SY(D[I].B));
  C.Pen.Color := clBlack;
  for I := 0 to D.Live - 1 do
    if (D[I].Kind = ekLine) and not D[I].Soft then
      C.Line(SX(D[I].A), SY(D[I].A), SX(D[I].B), SY(D[I].B));
  if Foot <> '' then
  begin
    C.Font.Color := clGray;
    C.TextOut(8, H - 20, Foot);
  end;
  if Title <> '' then
  begin
    C.Font.Color := clBlack;
    C.Font.Style := [fsBold];
    C.TextOut(8, 6, Title);
    C.Font.Style := [];
  end;
end;

end.
