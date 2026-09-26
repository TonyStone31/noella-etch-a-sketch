unit uPdf;

{ PDF output uses FPC's fcl-pdf: Pascal code linked into the executable,
  with vector geometry. No PDF runtime or external converter.
  Copyright (c) 2026 Noella Stone - MIT, see LICENSE. }
{$mode objfpc}{$H+}

interface

uses uWork;

type
  TPdfSheet = record
    Name: string;
    W, H: Double; { millimeters, portrait }
  end;
const
  PDF_MARGIN = 10.0;
  PDF_FOOTER = 15.0;
  PDF_SHEETS: array[0..20] of TPdfSheet = (
    (Name: 'ISO A4 - 210 x 297 mm'; W: 210; H: 297),
    (Name: 'ISO A3 - 297 x 420 mm'; W: 297; H: 420),
    (Name: 'ISO A2 - 420 x 594 mm'; W: 420; H: 594),
    (Name: 'ISO A1 - 594 x 841 mm'; W: 594; H: 841),
    (Name: 'ISO A0 - 841 x 1189 mm'; W: 841; H: 1189),
    (Name: 'ANSI A / Letter - 8.5 x 11 in'; W: 215.9; H: 279.4),
    (Name: 'ANSI B / Tabloid - 11 x 17 in'; W: 279.4; H: 431.8),
    (Name: 'ANSI C - 17 x 22 in'; W: 431.8; H: 558.8),
    (Name: 'ANSI D - 22 x 34 in'; W: 558.8; H: 863.6),
    (Name: 'ANSI E - 34 x 44 in'; W: 863.6; H: 1117.6),
    (Name: 'ARCH A - 9 x 12 in'; W: 228.6; H: 304.8),
    (Name: 'ARCH B - 12 x 18 in'; W: 304.8; H: 457.2),
    (Name: 'ARCH C - 18 x 24 in'; W: 457.2; H: 609.6),
    (Name: 'ARCH D - 24 x 36 in'; W: 609.6; H: 914.4),
    (Name: 'ARCH E - 36 x 48 in'; W: 914.4; H: 1219.2),
    (Name: 'ARCH E1 - 30 x 42 in'; W: 762; H: 1066.8),
    (Name: 'ARCH E2 - 26 x 38 in'; W: 660.4; H: 965.2),
    (Name: 'ARCH E3 - 27 x 39 in'; W: 685.8; H: 990.6),
    (Name: 'Legal - 8.5 x 14 in'; W: 215.9; H: 355.6),
    (Name: 'ISO A5 - 148 x 210 mm'; W: 148; H: 210),
    (Name: 'Engineering F - 28 x 40 in'; W: 711.2; H: 1016));

procedure PdfSheetSize(Index: Integer; Landscape: Boolean; out W, H: Double);
{ The camera supplies the center and direction, not the printed scale. }
procedure SaveDrawingPDF(Doc: TWorkDoc; const V: TProjector;
  SrcW, SrcH: Integer; U: TUnitSystem; EdgeW: Single; const Path: string;
  PageW, PageH, Denominator: Double; Axes: Boolean);

implementation

uses SysUtils, Math, Types, Graphics, fpPDF, fpTTF, uVector;

type
  TPDFVectorWriter = class(TVectorWriter)
  private
    FPage: TPDFPage;
    FTop: Double;
    FFont: Integer;
    FFontMetrics: TFPFontCacheItem;
    function Coord(const P: TPointF): TPDFCoord;
  public
    constructor Create(PDF: TPDFDocument; Page: TPDFPage; Top: Double);
    destructor Destroy; override;
    procedure Path(const Loops: TVectorLoops; Ink: TColor;
      Width: Double; Filled: Boolean); override;
    procedure Text(const P: TPointF; const S: string; Ink: TColor;
      Size: Double; Centered: Boolean); override;
  end;

function PDFColor(C: TColor): LongWord;
begin
  C := ColorToRGB(C);
  Result := (LongWord(Byte(C)) shl 16) or (LongWord(Byte(C shr 8)) shl 8) or Byte(C shr 16);
end;

constructor TPDFVectorWriter.Create(PDF: TPDFDocument; Page: TPDFPage; Top: Double);
var FontPath: string;
begin
  inherited Create;
  FPage := Page;
  FTop := Top;
  { Read a system font directly: no fontconfig library, shell or converter.
    Embed its subset so the recipient needs neither the font nor the app. }
  {$ifdef windows}
  FontPath := IncludeTrailingPathDelimiter(GetEnvironmentVariable('WINDIR')) + 'Fonts\arial.ttf';
  {$else}
  FontPath := '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';
  if not FileExists(FontPath) then
    FontPath := '/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf';
  {$endif}
  if FileExists(FontPath) then
  begin
    FFontMetrics := TFPFontCacheItem.Create(FontPath);
    FFont := PDF.AddFont(FontPath, 'ExportSans');
  end
  else
    { A PDF standard font needs no installed file. Courier has exact,
      fixed metrics for centered labels even on a minimal installation. }
    FFont := PDF.AddFont('Courier');
end;

destructor TPDFVectorWriter.Destroy;
begin
  FFontMetrics.Free;
  inherited Destroy;
end;

function TPDFVectorWriter.Coord(const P: TPointF): TPDFCoord;
begin
  { Geometry uses a fixed 96-unit paper inch; PDF coordinates are mm,
    bottom-up. Fonts and pen widths stay independent of screen zoom. }
  Result.X := PDF_MARGIN + P.X * 25.4 / 96;
  Result.Y := FTop - P.Y * 25.4 / 96;
end;

procedure TPDFVectorWriter.Path(const Loops: TVectorLoops; Ink: TColor;
  Width: Double; Filled: Boolean);
var
  I, J: Integer;
  A, B: TPDFCoord;
begin
  FPage.SetColor(PDFColor(Ink), True);
  if Filled then FPage.SetColor($D8D8D8, False);
  for I := 0 to High(Loops) do
  begin
    if Length(Loops[I]) < 2 then Continue;
    A := Coord(Loops[I][0]);
    FPage.MoveTo(A);
    for J := 1 to High(Loops[I]) do
    begin
      B := Coord(Loops[I][J]);
      { fpPDF takes line widths in points even when positions use mm. }
      FPage.DrawLine(A, B, Width * 72 / 96, False);
      A := B;
    end;
    if Filled then FPage.ClosePath;
  end;
  if Filled then FPage.FillEvenOddStrokePath else FPage.StrokePath;
end;

procedure TPDFVectorWriter.Text(const P: TPointF; const S: string;
  Ink: TColor; Size: Double; Centered: Boolean);
var A: TPDFCoord; TextW: Double;
begin
  A := Coord(P);
  FPage.SetColor(PDFColor(Ink), False);
  FPage.SetFont(FFont, Size * 72 / 96);
  if Centered then
  begin
    if Assigned(FFontMetrics) then
      TextW := FFontMetrics.TextWidth(S, 0) / FFontMetrics.FontData.Head.UnitsPerEm * Size * 25.4 / 96
    else TextW := Length(UTF8Decode(S)) * Size * 0.6 * 25.4 / 96;
    A.X := A.X - TextW / 2;
  end;
  FPage.WriteText(A, S);
end;

procedure PdfSheetSize(Index: Integer; Landscape: Boolean; out W, H: Double);
begin
  if (Index < Low(PDF_SHEETS)) or (Index > High(PDF_SHEETS)) then
    raise Exception.Create('Choose a PDF paper size');
  if Landscape then
  begin
    W := PDF_SHEETS[Index].H; H := PDF_SHEETS[Index].W;
  end
  else
  begin
    W := PDF_SHEETS[Index].W; H := PDF_SHEETS[Index].H;
  end;
end;

procedure SaveDrawingPDF(Doc: TWorkDoc; const V: TProjector;
  SrcW, SrcH: Integer; U: TUnitSystem; EdgeW: Single; const Path: string;
  PageW, PageH, Denominator: Double; Axes: Boolean);
var
  PDF: TPDFDocument;
  Page: TPDFPage;
  Paper: TPDFPaper;
  Writer: TPDFVectorWriter;
  PV: TProjector;
  W, H, MMUnit, Bar, BarMM, Extent: Double;
  Loops: TVectorLoops;
  I: Integer;
  A, B: TP3;
  AxisInk: TColor;
begin
  if Doc = nil then raise Exception.Create('No drawing for the PDF');
  if (Denominator <= 0) or IsNan(Denominator) or IsInfinite(Denominator) or
     (V.Ppu <= 0) then raise Exception.Create('Invalid PDF drawing scale');
  if (PageW <= 2 * PDF_MARGIN) or
     (PageH <= 2 * PDF_MARGIN + PDF_FOOTER) then
    raise Exception.Create('The PDF paper is too small');
  W := (PageW - 2 * PDF_MARGIN) * 96 / 25.4;
  H := (PageH - 2 * PDF_MARGIN - PDF_FOOTER) * 96 / 25.4;
  if U = usImperial then MMUnit := 304.8 else MMUnit := 1000;
  PV := V;
  PV.Ppu := MMUnit / Denominator * 96 / 25.4;
  PV.OX := W / 2 + (V.OX - SrcW / 2) * PV.Ppu / V.Ppu;
  PV.OY := H / 2 + (V.OY - SrcH / 2) * PV.Ppu / V.Ppu;
  PDF := TPDFDocument.Create(nil);
  try
    PDF.Options := [poSubsetFont, poCompressFonts];
    PDF.Infos.Title := ChangeFileExt(ExtractFileName(Path), '');
    PDF.Infos.Producer := 'Heckers Sketch';
    PDF.Infos.CreationDate := Now;
    PDF.DefaultUnitOfMeasure := uomMillimeters;
    PDF.StartDocument;
    Page := PDF.Pages.AddPage;
    Paper := Default(TPDFPaper);
    Paper.W := PageW * 72 / 25.4;
    Paper.H := PageH * 72 / 25.4;
    Page.Paper := Paper;
    PDF.Sections.AddSection.AddPage(Page);
    Writer := TPDFVectorWriter.Create(PDF, Page, PageH - PDF_MARGIN);
    try
      { The model is clipped; it is never rescaled to fit. Restore the
        graphics state before the footer so it cannot be clipped away. }
      Page.PushGraphicsStack;
      Page.MoveTo(PDF_MARGIN, PDF_MARGIN + PDF_FOOTER);
      Page.DrawLine(PDF_MARGIN, PDF_MARGIN + PDF_FOOTER,
        PageW - PDF_MARGIN, PDF_MARGIN + PDF_FOOTER, 0, False);
      Page.DrawLine(PageW - PDF_MARGIN, PDF_MARGIN + PDF_FOOTER,
        PageW - PDF_MARGIN, PageH - PDF_MARGIN, 0, False);
      Page.DrawLine(PageW - PDF_MARGIN, PageH - PDF_MARGIN,
        PDF_MARGIN, PageH - PDF_MARGIN, 0, False);
      Page.ClosePath;
      Page.ClipPath;
      if Axes then
      begin
        SetLength(Loops, 1); SetLength(Loops[0], 2);
        Extent := (Abs(PV.OX) + Abs(PV.OY) + W + H) / PV.Ppu * 100;
        for I := 0 to 2 do
        begin
          A := P3(0, 0, 0); B := A;
          case I of
            0: begin A.X := -Extent; B.X := Extent; AxisInk := $8888CC; end;
            1: begin A.Y := -Extent; B.Y := Extent; AxisInk := $88BB88; end;
          else begin A.Z := -Extent; B.Z := Extent; AxisInk := $CC8888; end;
          end;
          Loops[0][0] := Project(PV, A); Loops[0][1] := Project(PV, B);
          Writer.Path(Loops, AxisInk, 0.5, False);
        end;
      end;
      Doc.WriteVectors(Writer, PV, U, EdgeW);
      Page.PopGraphicsStack;
      Bar := NiceBarLength(MMUnit / Denominator, 25, 60, U);
      BarMM := Bar * MMUnit / Denominator;
      Page.SetColor(0, True);
      Page.SetColor(0, False);
      Page.DrawLine(PDF_MARGIN, 12, PDF_MARGIN + BarMM, 12, 0.7);
      Page.DrawLine(PDF_MARGIN, 10, PDF_MARGIN, 14, 0.7);
      Page.DrawLine(PDF_MARGIN + BarMM, 10, PDF_MARGIN + BarMM, 14, 0.7);
      Page.SetFont(Writer.FFont, 9);
      Page.WriteText(PDF_MARGIN, 16, FormatLen(Bar, U));
      Page.WriteText(PDF_MARGIN, 5, Format('1:%g (view plane) - print at 100%% / Actual size', [Denominator]));
      PDF.SaveToFile(Path);
    finally
      Writer.Free;
    end;
  finally
    PDF.Free;
  end;
end;

end.
