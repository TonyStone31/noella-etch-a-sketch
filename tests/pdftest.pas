program pdftest;
{$mode objfpc}{$H+}{$codepage utf8}
uses SysUtils, Classes, Math, Graphics, uWork, uPdf;
var
  Doc: TWorkDoc;
  V: TProjector;
  I, J: Integer;
  W, H: Double;
  Hole: TP3Array;
  SVG: TStringList;
begin
  Doc := TWorkDoc.Create;
  SVG := TStringList.Create;
  try
    Doc.AddLine(P3(0, 0, 0), P3(10, 0, 0), clRed, 1, False);
    Doc.AddFace([P3(-6, 1, 0), P3(-2, 1, 0), P3(-2, 5, 0), P3(-6, 5, 0)], clBlack);
    SetLength(Hole, 4);
    Hole[0] := P3(-5, 2, 0); Hole[1] := P3(-3, 2, 0);
    Hole[2] := P3(-3, 4, 0); Hole[3] := P3(-5, 4, 0);
    Doc.SetFaceHoles(1, [Hole]);
    Doc.AddArc(P3(3, 3, 0), 1, 0, 2 * Pi, plXY, clBlue, 1);
    Doc.AddArc(P3(6, 3, 0), 1, 0, 2 * Pi, plXY, clBlue, 1);
    Doc.SetArcSides(Doc.Live - 1, 6);
    Doc.AddText(P3(-5, -2, 0), 'A&B <plan> café Ω', clBlack);
    Doc.AddDim(P3(0, -4, 0), P3(5, -4, 0), clBlack, P3(0, 0, 0), 'FIELD VERIFY');
    V := Default(TProjector);
    V.Kind := vkPlan;
    V.Ppu := 20;
    V.OX := 400;
    V.OY := 300;
    for I := Low(PDF_SHEETS) to High(PDF_SHEETS) do
      for J := 0 to 1 do
      begin
        PdfSheetSize(I, J = 1, W, H);
        SaveDrawingPDF(Doc, V, 800, 600, usMetric, 1,
          Format('/tmp/hsk-pdf-%d-%d.pdf', [I, J]), W, H, 100, False);
      end;
    Doc.WriteSVG(SVG, V, usMetric, 1);
    SVG.SaveToFile('/tmp/hsk-pdf-parity.svg');
    V.Ppu := 200;
    SaveDrawingPDF(Doc, V, 800, 600, usMetric, 1,
      '/tmp/hsk-pdf-zoom.pdf', 210, 297, 100, False);
    Doc.Clear;
    Doc.AddLine(P3(0, 0, 0), P3(1, 0, 0), clRed, 1, False);
    SaveDrawingPDF(Doc, V, 800, 600, usImperial, 1,
      '/tmp/hsk-pdf-imperial.pdf', 210, 297, 12, False);
    WriteLn('Vector PDF fixtures written.');
  finally
    SVG.Free;
    Doc.Free;
  end;
end.
