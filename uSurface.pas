unit uSurface;

{
  uSurface - a small software rasteriser for Noella Hazel Sketch.

  Everything the program draws (the sketch itself, the chassis, the knobs,
  the icons) is rendered into a 32 bit BGRA pixel buffer with analytic
  anti-aliasing, then blitted to a canvas inside a paint handler.

  Doing it this way buys us three things:

    1. Smooth, good looking edges.  The LCL canvas has no anti-aliasing, so
       circles and diagonal lines drawn with Canvas.Ellipse/LineTo look
       jagged.  Here coverage is computed from a signed distance field, so
       curves come out clean.
    2. Blend modes and true alpha, which is what makes the neon glow and the
       shake-to-erase dissolve possible.
    3. Widgetset independence.  Drawing straight onto TImage.Canvas outside a
       paint event is unreliable (it stopped working entirely under GTK3);
       owning the pixels and painting them in OnPaint always works.

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE.
}

{$mode objfpc}{$H+}
{$inline on}

interface

uses
  Classes, SysUtils, Types, Math, FPImage, Graphics, GraphType, IntfGraphics;

type
  { One pixel, laid out exactly as Init_BPP32_B8G8R8A8_BIO_TTB stores it. }
  TPix = packed record
    B, G, R, A: Byte;
  end;
  PPix = ^TPix;

  { How a source color is combined with what is already on the surface. }
  TBlendMode = (
    bmNormal,    // ordinary source-over alpha blend
    bmLighten,   // keep the brighter channel - additive-ish
    bmMaxAlpha,  // keep whichever is more opaque; glow halos that do not
                 // accumulate where strokes overlap
    bmReplace    // overwrite, alpha included
  );

  { TArtSurface }

  TArtSurface = class
  private
    FImage: TLazIntfImage;
    FBitmap: TBitmap;
    FBitmapValid: Boolean;
    FWidth, FHeight: Integer;
    FStride: PtrInt;
    FBits: PByte;
    FMode: TBlendMode;
    FKeepAlpha: Boolean;
    FDirty: TRect;
    procedure Allocate(AWidth, AHeight: Integer);
    procedure Invalidate; inline;
  public
    constructor Create(AWidth, AHeight: Integer);
    destructor Destroy; override;

    procedure SetSize(AWidth, AHeight: Integer; APreserve: Boolean = False);
    function ScanLine(Y: Integer): PPix; inline;

    { --- damage tracking, so compositing only touches what changed ------- }
    procedure ResetDirty;
    procedure MarkAllDirty;
    function TakeDirty: TRect;

    { --- primitives ------------------------------------------------------ }
    procedure BlendPixel(X, Y: Integer; const C: TPix; Cover: Single); inline;
    procedure Clear(const C: TPix);
    procedure FillRect(const R: TRect; const C: TPix; Alpha: Single = 1.0);
    procedure VGradient(const R: TRect; const C1, C2: TPix);
    procedure RoundRect(const R: TRect; Radius: Single; const C: TPix; Alpha: Single = 1.0);
    procedure RoundRectV(const R: TRect; Radius: Single; const C1, C2: TPix; Alpha: Single = 1.0);
    procedure RoundFrame(const R: TRect; Radius, LineW: Single; const C: TPix; Alpha: Single = 1.0);
    procedure Disc(CX, CY, Radius: Single; const C: TPix; Alpha: Single = 1.0);
    procedure DiscV(CX, CY, Radius: Single; const C1, C2: TPix; Alpha: Single = 1.0);
    procedure Ring(CX, CY, Radius, LineW: Single; const C: TPix; Alpha: Single = 1.0);
    procedure Line(X0, Y0, X1, Y1, LineW: Single; const C: TPix; Alpha: Single = 1.0);
    procedure Arc(CX, CY, Radius, A0, A1, LineW: Single; const C: TPix; Alpha: Single = 1.0);
    procedure Poly(const Pts: array of TPointF; LineW: Single; const C: TPix;
      Closed: Boolean = False; Alpha: Single = 1.0);
    procedure Triangle(const P1, P2, P3: TPointF; const C: TPix; Alpha: Single = 1.0);
    procedure FillPoly(const Pts: array of TPointF; const C: TPix; Alpha: Single = 1.0);

    { --- whole-surface effects ------------------------------------------- }
    procedure ClearTransparent;
    procedure FadeToward(const C: TPix; Amount: Single);
    procedure FadeAlpha(Amount: Single);
    procedure CompositeOver(Base, Ink: TArtSurface; const R: TRect);
    procedure Grain(Amount, Density: Single);
    procedure SmearDown(Rows: Integer);

    { --- transfer -------------------------------------------------------- }
    procedure CopyFrom(Src: TArtSurface; DX, DY: Integer);
    procedure CopyRegion(Src: TArtSurface; SrcX, SrcY, DX, DY, W, H: Integer);
    procedure Snapshot(out Buf: TBytes);
    procedure Restore(const Buf: TBytes);
    procedure DrawTo(ACanvas: TCanvas; X, Y: Integer);
    procedure SaveToPNG(const AFileName: string);
    function TextExtent(const S: string; AFont: TFont): TSize;
    procedure TextOut(X, Y: Integer; const S: string; AFont: TFont; const C: TPix;
      Alpha: Single = 1.0);
    function AsBitmap: TBitmap;
    procedure Touch; inline;

    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
    property BlendMode: TBlendMode read FMode write FMode;
    { An ink layer keeps its own alpha so it can be composited over any
      background; a background surface stays fully opaque. }
    property PreserveAlpha: Boolean read FKeepAlpha write FKeepAlpha;
    property DirtyRect: TRect read FDirty;
  end;

{ --- color helpers ----------------------------------------------------- }
function Pix(R, G, B: Byte; A: Byte = 255): TPix; inline;
function ColorToPix(C: TColor): TPix; inline;
function PixToColor(const P: TPix): TColor; inline;
function MixPix(const A, B: TPix; T: Single): TPix;
function ShadePix(const C: TPix; F: Single): TPix;
function HSVPix(H, S, V: Single): TPix;
function PtF(X, Y: Single): TPointF; inline;

implementation

const
  DEG = Pi / 180;

{ ------------------------------------------------------------------------ }
{ color helpers                                                            }
{ ------------------------------------------------------------------------ }

function Pix(R, G, B: Byte; A: Byte): TPix;
begin
  Result.R := R;
  Result.G := G;
  Result.B := B;
  Result.A := A;
end;

function ColorToPix(C: TColor): TPix;
var
  V: LongInt;
begin
  V := ColorToRGB(C);
  Result.R := Byte(V);
  Result.G := Byte(V shr 8);
  Result.B := Byte(V shr 16);
  Result.A := 255;
end;

function PixToColor(const P: TPix): TColor;
begin
  Result := TColor(P.R or (P.G shl 8) or (P.B shl 16));
end;

function MixPix(const A, B: TPix; T: Single): TPix;
begin
  T := EnsureRange(T, 0, 1);
  Result.R := Round(A.R + (B.R - A.R) * T);
  Result.G := Round(A.G + (B.G - A.G) * T);
  Result.B := Round(A.B + (B.B - A.B) * T);
  Result.A := Round(A.A + (B.A - A.A) * T);
end;

function ShadePix(const C: TPix; F: Single): TPix;
begin
  Result.R := EnsureRange(Round(C.R * F), 0, 255);
  Result.G := EnsureRange(Round(C.G * F), 0, 255);
  Result.B := EnsureRange(Round(C.B * F), 0, 255);
  Result.A := C.A;
end;

function HSVPix(H, S, V: Single): TPix;
var
  I: Integer;
  F, P, Q, T, R, G, B: Single;
begin
  H := H - Floor(H / 360) * 360;
  S := EnsureRange(S, 0, 1);
  V := EnsureRange(V, 0, 1);
  if S <= 0 then
  begin
    R := V; G := V; B := V;
  end
  else
  begin
    H := H / 60;
    I := Trunc(H);
    F := H - I;
    P := V * (1 - S);
    Q := V * (1 - S * F);
    T := V * (1 - S * (1 - F));
    case I of
      0: begin R := V; G := T; B := P; end;
      1: begin R := Q; G := V; B := P; end;
      2: begin R := P; G := V; B := T; end;
      3: begin R := P; G := Q; B := V; end;
      4: begin R := T; G := P; B := V; end;
    else
      begin R := V; G := P; B := Q; end;
    end;
  end;
  Result := Pix(Round(R * 255), Round(G * 255), Round(B * 255));
end;

function PtF(X, Y: Single): TPointF;
begin
  Result.X := X;
  Result.Y := Y;
end;

{ ------------------------------------------------------------------------ }
{ signed distance fields                                                    }
{ ------------------------------------------------------------------------ }

{ Distance from (PX,PY) to a rounded box centerd on (CX,CY) with half-extents
  (HX,HY) and corner radius Rad.  Negative inside, positive outside. }
function SdRoundBox(PX, PY, CX, CY, HX, HY, Rad: Single): Single; inline;
var
  QX, QY: Single;
begin
  Rad := Min(Rad, Min(HX, HY));
  QX := Abs(PX - CX) - (HX - Rad);
  QY := Abs(PY - CY) - (HY - Rad);
  Result := Sqrt(Sqr(Max(QX, 0)) + Sqr(Max(QY, 0))) + Min(Max(QX, QY), 0) - Rad;
end;

{ Distance from (PX,PY) to the segment (AX,AY)-(BX,BY). }
function SdSegment(PX, PY, AX, AY, BX, BY: Single): Single; inline;
var
  PAX, PAY, BAX, BAY, H, D: Single;
begin
  PAX := PX - AX;
  PAY := PY - AY;
  BAX := BX - AX;
  BAY := BY - AY;
  D := BAX * BAX + BAY * BAY;
  if D < 1E-9 then
    H := 0
  else
    H := EnsureRange((PAX * BAX + PAY * BAY) / D, 0, 1);
  Result := Sqrt(Sqr(PAX - BAX * H) + Sqr(PAY - BAY * H));
end;

{ Convert a signed distance to pixel coverage (1px wide analytic edge). }
function Coverage(D: Single): Single; inline;
begin
  Result := EnsureRange(0.5 - D, 0, 1);
end;

{ ------------------------------------------------------------------------ }
{ TArtSurface                                                               }
{ ------------------------------------------------------------------------ }

constructor TArtSurface.Create(AWidth, AHeight: Integer);
begin
  inherited Create;
  FImage := TLazIntfImage.Create(0, 0);
  FBitmap := TBitmap.Create;
  FMode := bmNormal;
  Allocate(Max(1, AWidth), Max(1, AHeight));
end;

destructor TArtSurface.Destroy;
begin
  FBitmap.Free;
  FImage.Free;
  inherited Destroy;
end;

procedure TArtSurface.Allocate(AWidth, AHeight: Integer);
var
  Desc: TRawImageDescription;
begin
  Desc.Init_BPP32_B8G8R8A8_BIO_TTB(AWidth, AHeight);
  FImage.DataDescription := Desc;
  FWidth := AWidth;
  FHeight := AHeight;
  FBits := PByte(FImage.GetDataLineStart(0));
  { the allocation is not zeroed, and anything that only partly covers the
    surface afterwards would otherwise show whatever was in that memory }
  FillChar(FBits^, PtrUInt(FImage.GetDataLineStart(AHeight - 1)) -
    PtrUInt(FBits) + PtrUInt(AWidth) * 4, 0);
  if AHeight > 1 then
    FStride := PByte(FImage.GetDataLineStart(1)) - FBits
  else
    FStride := AWidth * 4;
  FBitmapValid := False;
  ResetDirty;
end;

procedure TArtSurface.Invalidate;
begin
  FBitmapValid := False;
end;

procedure TArtSurface.Touch;
begin
  FBitmapValid := False;
end;

procedure TArtSurface.SetSize(AWidth, AHeight: Integer; APreserve: Boolean);
var
  Keep: TBytes;
  OldW, OldH: Integer;
  Old: TArtSurface;
begin
  AWidth := Max(1, AWidth);
  AHeight := Max(1, AHeight);
  if (AWidth = FWidth) and (AHeight = FHeight) then
    Exit;

  if not APreserve then
  begin
    Allocate(AWidth, AHeight);
    Exit;
  end;

  { Keep the old contents anchored at the top-left so a window resize no
    longer wipes the drawing - that was the "* Resizing window will erase
    image.  Sorry." caveat in the original. }
  OldW := FWidth;
  OldH := FHeight;
  Snapshot(Keep);
  Old := TArtSurface.Create(OldW, OldH);
  try
    Old.Restore(Keep);
    Allocate(AWidth, AHeight);
    FillRect(Rect(0, 0, FWidth, FHeight), Pix(255, 255, 255));
    CopyFrom(Old, 0, 0);
  finally
    Old.Free;
  end;
end;

function TArtSurface.ScanLine(Y: Integer): PPix;
begin
  Result := PPix(FBits + FStride * Y);
end;

procedure TArtSurface.BlendPixel(X, Y: Integer; const C: TPix; Cover: Single);
var
  P: PPix;
  A, DA, OA: Integer;
begin
  if (X < 0) or (Y < 0) or (X >= FWidth) or (Y >= FHeight) then Exit;
  { written as "not > 0" so a NaN coverage - a degenerate shape upstream -
    leaves rather than reaching Round below }
  if not (Cover > 0) then Exit;
  if Cover > 1 then Cover := 1;

  P := ScanLine(Y);
  Inc(P, X);
  A := Round(Cover * C.A);

  case FMode of
    bmReplace:
      begin
        P^ := C;
        P^.A := Byte(A);
      end;

    bmLighten:
      begin
        P^.R := Max(P^.R, Byte((C.R * A) div 255));
        P^.G := Max(P^.G, Byte((C.G * A) div 255));
        P^.B := Max(P^.B, Byte((C.B * A) div 255));
        if FKeepAlpha then P^.A := Max(P^.A, Byte(A)) else P^.A := 255;
      end;

    bmMaxAlpha:
      begin
        if A > P^.A then
        begin
          P^.R := C.R;
          P^.G := C.G;
          P^.B := C.B;
          P^.A := Byte(A);
        end;
      end;

  else
    if FKeepAlpha then
    begin
      { source-over onto a surface that carries its own alpha }
      DA := P^.A;
      OA := A + (DA * (255 - A)) div 255;
      if OA <= 0 then
      begin
        P^.R := 0; P^.G := 0; P^.B := 0; P^.A := 0;
      end
      else
      begin
        { out = (src*sa + dst*da*(1-sa)) / oa, kept in 0..255 integers.
          The numerator is scaled by 255 so it divides by 255*OA.
          OA is truncated down, so the quotient can come out just over 255 -
          at A=1 over DA=1 it reaches 509, which is a range check error on
          the way into a Byte.  Clamp rather than widen the arithmetic. }
        P^.R := Min(255, (C.R * A * 255 + P^.R * DA * (255 - A)) div (255 * OA));
        P^.G := Min(255, (C.G * A * 255 + P^.G * DA * (255 - A)) div (255 * OA));
        P^.B := Min(255, (C.B * A * 255 + P^.B * DA * (255 - A)) div (255 * OA));
        P^.A := Byte(OA);
      end;
    end
    else
    begin
      if A >= 255 then
      begin
        P^.R := C.R; P^.G := C.G; P^.B := C.B;
      end
      else
      begin
        P^.R := P^.R + ((C.R - P^.R) * A) div 255;
        P^.G := P^.G + ((C.G - P^.G) * A) div 255;
        P^.B := P^.B + ((C.B - P^.B) * A) div 255;
      end;
      P^.A := 255;
    end;
  end;

  if X < FDirty.Left then FDirty.Left := X;
  if Y < FDirty.Top then FDirty.Top := Y;
  if X >= FDirty.Right then FDirty.Right := X + 1;
  if Y >= FDirty.Bottom then FDirty.Bottom := Y + 1;
  FBitmapValid := False;
end;

procedure TArtSurface.ResetDirty;
begin
  FDirty := Rect(FWidth, FHeight, 0, 0);
end;

procedure TArtSurface.MarkAllDirty;
begin
  FDirty := Rect(0, 0, FWidth, FHeight);
end;

{ Returns the damaged area and clears it.  An empty rect means nothing moved. }
function TArtSurface.TakeDirty: TRect;
begin
  Result := FDirty;
  if (Result.Right <= Result.Left) or (Result.Bottom <= Result.Top) then
    Result := Rect(0, 0, 0, 0);
  ResetDirty;
end;

procedure TArtSurface.ClearTransparent;
var
  Y: Integer;
begin
  for Y := 0 to FHeight - 1 do
    FillChar(ScanLine(Y)^, FWidth * SizeOf(TPix), 0);
  MarkAllDirty;
  Invalidate;
end;

{ Wind the whole layer toward transparent - how the shake dissolves ink
  without touching the paper underneath. }
procedure TArtSurface.FadeAlpha(Amount: Single);
var
  X, Y, K: Integer;
  P: PPix;
begin
  K := EnsureRange(Round((1 - Amount) * 255), 0, 255);
  for Y := 0 to FHeight - 1 do
  begin
    P := ScanLine(Y);
    for X := 0 to FWidth - 1 do
    begin
      P^.A := (P^.A * K) div 255;
      Inc(P);
    end;
  end;
  MarkAllDirty;
  Invalidate;
end;

{ Self := Base with Ink composited on top, over the rectangle R only. }
procedure TArtSurface.CompositeOver(Base, Ink: TArtSurface; const R: TRect);
var
  X, Y, A: Integer;
  Cl: TRect;
  B, S, D: PPix;
begin
  Cl := Rect(Max(0, R.Left), Max(0, R.Top), Min(FWidth, R.Right), Min(FHeight, R.Bottom));
  if (Cl.Right <= Cl.Left) or (Cl.Bottom <= Cl.Top) then Exit;

  for Y := Cl.Top to Cl.Bottom - 1 do
  begin
    B := Base.ScanLine(Y); Inc(B, Cl.Left);
    S := Ink.ScanLine(Y);  Inc(S, Cl.Left);
    D := ScanLine(Y);      Inc(D, Cl.Left);
    for X := Cl.Left to Cl.Right - 1 do
    begin
      A := S^.A;
      if A = 0 then
        D^ := B^
      else if A = 255 then
        D^ := S^
      else
      begin
        D^.R := B^.R + ((S^.R - B^.R) * A) div 255;
        D^.G := B^.G + ((S^.G - B^.G) * A) div 255;
        D^.B := B^.B + ((S^.B - B^.B) * A) div 255;
      end;
      D^.A := 255;
      Inc(B); Inc(S); Inc(D);
    end;
  end;
  Invalidate;
end;

procedure TArtSurface.Clear(const C: TPix);
var
  X, Y: Integer;
  P: PPix;
begin
  for Y := 0 to FHeight - 1 do
  begin
    P := ScanLine(Y);
    for X := 0 to FWidth - 1 do
    begin
      P^ := C;
      P^.A := 255;
      Inc(P);
    end;
  end;
  MarkAllDirty;
  Invalidate;
end;

procedure TArtSurface.FillRect(const R: TRect; const C: TPix; Alpha: Single);
var
  X, Y: Integer;
  P: PPix;
  Cl: TRect;
begin
  Cl := Rect(Max(0, R.Left), Max(0, R.Top), Min(FWidth, R.Right), Min(FHeight, R.Bottom));
  if (Cl.Right <= Cl.Left) or (Cl.Bottom <= Cl.Top) then Exit;
  for Y := Cl.Top to Cl.Bottom - 1 do
  begin
    P := ScanLine(Y);
    Inc(P, Cl.Left);
    for X := Cl.Left to Cl.Right - 1 do
    begin
      BlendPixel(X, Y, C, Alpha);
      Inc(P);
    end;
  end;
  Invalidate;
end;

procedure TArtSurface.VGradient(const R: TRect; const C1, C2: TPix);
var
  X, Y, H: Integer;
  C: TPix;
  Cl: TRect;
begin
  Cl := Rect(Max(0, R.Left), Max(0, R.Top), Min(FWidth, R.Right), Min(FHeight, R.Bottom));
  H := R.Bottom - R.Top;
  if H <= 0 then Exit;
  for Y := Cl.Top to Cl.Bottom - 1 do
  begin
    C := MixPix(C1, C2, (Y - R.Top) / H);
    for X := Cl.Left to Cl.Right - 1 do
      BlendPixel(X, Y, C, 1.0);
  end;
  Invalidate;
end;

procedure TArtSurface.RoundRectV(const R: TRect; Radius: Single; const C1, C2: TPix;
  Alpha: Single);
var
  X, Y, H: Integer;
  CX, CY, HX, HY: Single;
  C: TPix;
  Cl: TRect;
begin
  CX := (R.Left + R.Right) / 2;
  CY := (R.Top + R.Bottom) / 2;
  HX := (R.Right - R.Left) / 2;
  HY := (R.Bottom - R.Top) / 2;
  H := R.Bottom - R.Top;
  if (HX <= 0) or (HY <= 0) then Exit;

  Cl := Rect(Max(0, R.Left - 1), Max(0, R.Top - 1),
             Min(FWidth, R.Right + 1), Min(FHeight, R.Bottom + 1));
  for Y := Cl.Top to Cl.Bottom - 1 do
  begin
    C := MixPix(C1, C2, (Y - R.Top) / H);
    for X := Cl.Left to Cl.Right - 1 do
      BlendPixel(X, Y, C,
        Coverage(SdRoundBox(X + 0.5, Y + 0.5, CX, CY, HX, HY, Radius)) * Alpha);
  end;
  Invalidate;
end;

procedure TArtSurface.RoundRect(const R: TRect; Radius: Single; const C: TPix; Alpha: Single);
begin
  RoundRectV(R, Radius, C, C, Alpha);
end;

procedure TArtSurface.RoundFrame(const R: TRect; Radius, LineW: Single; const C: TPix;
  Alpha: Single);
var
  X, Y, Pad, Band: Integer;
  CX, CY, HX, HY: Single;
  Cl: TRect;

  procedure Row(AY, AX0, AX1: Integer);
  var
    IX: Integer;
  begin
    if (AY < 0) or (AY >= FHeight) then Exit;
    for IX := Max(0, AX0) to Min(FWidth - 1, AX1) do
      BlendPixel(IX, AY, C,
        Coverage(Abs(SdRoundBox(IX + 0.5, AY + 0.5, CX, CY, HX, HY, Radius)) - LineW / 2) * Alpha);
  end;

begin
  CX := (R.Left + R.Right) / 2;
  CY := (R.Top + R.Bottom) / 2;
  HX := (R.Right - R.Left) / 2;
  HY := (R.Bottom - R.Top) / 2;
  if (HX <= 0) or (HY <= 0) then Exit;
  Pad := Ceil(LineW) + 2;
  Band := Ceil(Radius) + Pad;

  Cl := Rect(R.Left - Pad, R.Top - Pad, R.Right + Pad, R.Bottom + Pad);

  { Only the border band can be covered, so walk the perimeter rather than the
    whole rectangle - this keeps big frames (the bezel, the vignette) cheap. }
  for Y := Cl.Top to Min(Cl.Bottom, Cl.Top + 2 * Band) - 1 do
    Row(Y, Cl.Left, Cl.Right - 1);
  for Y := Max(Cl.Top + 2 * Band, Cl.Bottom - 2 * Band) to Cl.Bottom - 1 do
    Row(Y, Cl.Left, Cl.Right - 1);
  for Y := Cl.Top + 2 * Band to Cl.Bottom - 2 * Band - 1 do
  begin
    Row(Y, Cl.Left, Cl.Left + 2 * Band - 1);
    Row(Y, Cl.Right - 2 * Band, Cl.Right - 1);
  end;
  Invalidate;
end;

{ Every primitive works out an integer bounding box from float coordinates,
  and those coordinates are not bounded: a wall a hundred feet long, drawn at
  high zoom, projects to a line whose ends are millions of pixels off the
  surface.  Converting that to an Integer and clamping afterwards is a range
  check error waiting to happen - clamp first, and an off-surface shape just
  produces an empty loop. }

function LoBound(V: Double; Limit: Integer): Integer;
begin
  if IsNan(V) or (V <= 0) then Exit(0);
  if V >= Limit then Exit(Limit);        // Lo > Hi: nothing to walk
  Result := Floor(V);
end;

function HiBound(V: Double; Limit: Integer): Integer;
begin
  if IsNan(V) or (V < 0) then Exit(-1);  // Hi < Lo: nothing to walk
  if V >= Limit - 1 then Exit(Limit - 1);
  Result := Ceil(V);
end;

procedure TArtSurface.Disc(CX, CY, Radius: Single; const C: TPix; Alpha: Single);
var
  X, Y, X0, Y0, X1, Y1: Integer;
begin
  if Radius <= 0 then Exit;
  X0 := LoBound(CX - Radius - 1, FWidth);
  Y0 := LoBound(CY - Radius - 1, FHeight);
  X1 := HiBound(CX + Radius + 1, FWidth);
  Y1 := HiBound(CY + Radius + 1, FHeight);
  for Y := Y0 to Y1 do
    for X := X0 to X1 do
      BlendPixel(X, Y, C,
        Coverage(Sqrt(Sqr(X + 0.5 - CX) + Sqr(Y + 0.5 - CY)) - Radius) * Alpha);
  Invalidate;
end;

procedure TArtSurface.DiscV(CX, CY, Radius: Single; const C1, C2: TPix; Alpha: Single);
var
  X, Y, X0, Y0, X1, Y1: Integer;
  C: TPix;
begin
  if Radius <= 0 then Exit;
  X0 := LoBound(CX - Radius - 1, FWidth);
  Y0 := LoBound(CY - Radius - 1, FHeight);
  X1 := HiBound(CX + Radius + 1, FWidth);
  Y1 := HiBound(CY + Radius + 1, FHeight);
  for Y := Y0 to Y1 do
  begin
    C := MixPix(C1, C2, EnsureRange((Y - (CY - Radius)) / (2 * Radius), 0, 1));
    for X := X0 to X1 do
      BlendPixel(X, Y, C,
        Coverage(Sqrt(Sqr(X + 0.5 - CX) + Sqr(Y + 0.5 - CY)) - Radius) * Alpha);
  end;
  Invalidate;
end;

procedure TArtSurface.Ring(CX, CY, Radius, LineW: Single; const C: TPix; Alpha: Single);
var
  X, Y, X0, Y0, X1, Y1: Integer;
  Pad: Double;
begin
  Pad := Radius + LineW + 2;
  X0 := LoBound(CX - Pad, FWidth);
  Y0 := LoBound(CY - Pad, FHeight);
  X1 := HiBound(CX + Pad, FWidth);
  Y1 := HiBound(CY + Pad, FHeight);
  for Y := Y0 to Y1 do
    for X := X0 to X1 do
      BlendPixel(X, Y, C,
        Coverage(Abs(Sqrt(Sqr(X + 0.5 - CX) + Sqr(Y + 0.5 - CY)) - Radius) - LineW / 2) * Alpha);
  Invalidate;
end;

{ Walk the line, not the box around it.  A diagonal crossing the surface has
  a bounding box the size of the whole surface, so testing every pixel in it
  cost 605,000 distance evaluations for a line that covers a few thousand -
  and the isometric paper, which is four hundred such diagonals, took over a
  second to draw. For each row, work out the span the segment can actually
  reach and walk only that. }
procedure TArtSurface.Line(X0, Y0, X1, Y1, LineW: Single; const C: TPix; Alpha: Single);
var
  X, Y, IX0, IY0, IX1, IY1, RX0, RX1: Integer;
  HW, Pad, DY, Lo, Hi, XA, XB, T: Single;
begin
  HW := Max(LineW, 0.35) / 2;
  Pad := HW + 3;
  IX0 := LoBound(Min(X0, X1) - Pad, FWidth);
  IY0 := LoBound(Min(Y0, Y1) - Pad, FHeight);
  IX1 := HiBound(Max(X0, X1) + Pad, FWidth);
  IY1 := HiBound(Max(Y0, Y1) + Pad, FHeight);

  DY := Y1 - Y0;
  for Y := IY0 to IY1 do
  begin
    if Abs(DY) < 1E-6 then
    begin
      { horizontal: the whole span is in this row anyway }
      RX0 := IX0;
      RX1 := IX1;
    end
    else
    begin
      { where the segment enters and leaves this row, padded by the width }
      Lo := (Y - Pad - Y0) / DY;
      Hi := (Y + 1 + Pad - Y0) / DY;
      if Lo > Hi then begin T := Lo; Lo := Hi; Hi := T; end;
      if Lo < 0 then Lo := 0;
      if Hi > 1 then Hi := 1;
      if Lo > Hi then Continue;               // the row is past an end
      XA := X0 + (X1 - X0) * Lo;
      XB := X0 + (X1 - X0) * Hi;
      if XA > XB then begin T := XA; XA := XB; XB := T; end;
      RX0 := Max(IX0, LoBound(XA - Pad, FWidth));
      RX1 := Min(IX1, HiBound(XB + Pad, FWidth));
    end;
    for X := RX0 to RX1 do
      BlendPixel(X, Y, C,
        Coverage(SdSegment(X + 0.5, Y + 0.5, X0, Y0, X1, Y1) - HW) * Alpha);
  end;
  Invalidate;
end;

procedure TArtSurface.Arc(CX, CY, Radius, A0, A1, LineW: Single; const C: TPix; Alpha: Single);
var
  Steps, I: Integer;
  A, Step, PX, PY, NX, NY: Single;
begin
  Steps := Max(6, Round(Abs(A1 - A0) * Radius / 30));
  Step := (A1 - A0) / Steps;
  PX := CX + Cos(A0) * Radius;
  PY := CY + Sin(A0) * Radius;
  for I := 1 to Steps do
  begin
    A := A0 + Step * I;
    NX := CX + Cos(A) * Radius;
    NY := CY + Sin(A) * Radius;
    Line(PX, PY, NX, NY, LineW, C, Alpha);
    PX := NX;
    PY := NY;
  end;
end;

procedure TArtSurface.Poly(const Pts: array of TPointF; LineW: Single; const C: TPix;
  Closed: Boolean; Alpha: Single);
var
  I: Integer;
begin
  if Length(Pts) < 2 then Exit;
  for I := 0 to High(Pts) - 1 do
    Line(Pts[I].X, Pts[I].Y, Pts[I + 1].X, Pts[I + 1].Y, LineW, C, Alpha);
  if Closed then
    Line(Pts[High(Pts)].X, Pts[High(Pts)].Y, Pts[0].X, Pts[0].Y, LineW, C, Alpha);
end;

procedure TArtSurface.Triangle(const P1, P2, P3: TPointF; const C: TPix; Alpha: Single);

  function Edge(const A, B: TPointF; PX, PY: Single): Single; inline;
  begin
    Result := (PX - A.X) * (B.Y - A.Y) - (PY - A.Y) * (B.X - A.X);
  end;

var
  X, Y, X0, Y0, X1, Y1: Integer;
  E1, E2, E3, Sign: Single;
begin
  X0 := LoBound(Min(P1.X, Min(P2.X, P3.X)) - 1, FWidth);
  Y0 := LoBound(Min(P1.Y, Min(P2.Y, P3.Y)) - 1, FHeight);
  X1 := HiBound(Max(P1.X, Max(P2.X, P3.X)) + 1, FWidth);
  Y1 := HiBound(Max(P1.Y, Max(P2.Y, P3.Y)) + 1, FHeight);
  Sign := Edge(P1, P2, P3.X, P3.Y);
  if Sign = 0 then Exit;
  Sign := Math.Sign(Sign);
  for Y := Y0 to Y1 do
    for X := X0 to X1 do
    begin
      E1 := Edge(P1, P2, X + 0.5, Y + 0.5) * Sign;
      E2 := Edge(P2, P3, X + 0.5, Y + 0.5) * Sign;
      E3 := Edge(P3, P1, X + 0.5, Y + 0.5) * Sign;
      if (E1 >= 0) and (E2 >= 0) and (E3 >= 0) then
        BlendPixel(X, Y, C, Alpha);
    end;
  Invalidate;
end;

{ Scanline fill of any simple polygon, convex or not.  Four vertical
  subsamples per row plus exact horizontal span ends gives edges that are
  smooth enough to sit beside the anti-aliased strokes. }
procedure TArtSurface.FillPoly(const Pts: array of TPointF; const C: TPix;
  Alpha: Single);
const
  SAMPLES = 4;
var
  N, I, J, Y, X, K, Cnt, X0, X1, Y0, Y1: Integer;
  MinX, MaxX, MinY, MaxY, SY, XA, XB: Single;
  Xs: array of Single;
  Cov: array of Single;
  T: Single;
begin
  N := Length(Pts);
  if N < 3 then Exit;

  MinY := Pts[0].Y;
  MaxY := Pts[0].Y;
  MinX := Pts[0].X;
  MaxX := Pts[0].X;
  for I := 1 to N - 1 do
  begin
    MinY := Min(MinY, Pts[I].Y);
    MaxY := Max(MaxY, Pts[I].Y);
    MinX := Min(MinX, Pts[I].X);
    MaxX := Max(MaxX, Pts[I].X);
  end;

  Y0 := LoBound(MinY, FHeight);
  Y1 := HiBound(MaxY, FHeight);
  X0 := LoBound(MinX - 1, FWidth);
  X1 := HiBound(MaxX + 1, FWidth);
  if (Y1 < Y0) or (X1 < X0) then Exit;

  SetLength(Xs, N + 1);
  SetLength(Cov, X1 - X0 + 2);

  for Y := Y0 to Y1 do
  begin
    for X := 0 to High(Cov) do
      Cov[X] := 0;

    for K := 0 to SAMPLES - 1 do
    begin
      SY := Y + (K + 0.5) / SAMPLES;
      Cnt := 0;
      for I := 0 to N - 1 do
      begin
        J := (I + 1) mod N;
        if (Pts[I].Y <= SY) = (Pts[J].Y <= SY) then Continue;
        T := (SY - Pts[I].Y) / (Pts[J].Y - Pts[I].Y);
        Xs[Cnt] := Pts[I].X + (Pts[J].X - Pts[I].X) * T;
        Inc(Cnt);
      end;
      if Cnt < 2 then Continue;

      { insertion sort - a handful of crossings at most }
      for I := 1 to Cnt - 1 do
      begin
        T := Xs[I];
        J := I - 1;
        while (J >= 0) and (Xs[J] > T) do
        begin
          Xs[J + 1] := Xs[J];
          Dec(J);
        end;
        Xs[J + 1] := T;
      end;

      I := 0;
      while I + 1 < Cnt do
      begin
        XA := Xs[I];
        XB := Xs[I + 1];
        Inc(I, 2);
        if IsNan(XA) or IsNan(XB) then Continue;
        if XB <= X0 then Continue;
        if XA >= X1 + 1 then Continue;
        XA := Max(XA, X0);
        XB := Min(XB, X1 + 1);
        for X := Floor(XA) to Ceil(XB) - 1 do
        begin
          if (X < X0) or (X > X1) then Continue;
          { how much of this pixel the span covers horizontally }
          T := Min(XB, X + 1.0) - Max(XA, X * 1.0);
          if T > 0 then
            Cov[X - X0] := Cov[X - X0] + T / SAMPLES;
        end;
      end;
    end;

    for X := X0 to X1 do
      if Cov[X - X0] > 0.002 then
        BlendPixel(X, Y, C, Cov[X - X0] * Alpha);
  end;
  Invalidate;
end;

procedure TArtSurface.FadeToward(const C: TPix; Amount: Single);
var
  X, Y, A: Integer;
  P: PPix;
begin
  A := EnsureRange(Round(Amount * 255), 0, 255);
  if A = 0 then Exit;
  for Y := 0 to FHeight - 1 do
  begin
    P := ScanLine(Y);
    for X := 0 to FWidth - 1 do
    begin
      P^.R := P^.R + ((C.R - P^.R) * A) div 255;
      P^.G := P^.G + ((C.G - P^.G) * A) div 255;
      P^.B := P^.B + ((C.B - P^.B) * A) div 255;
      Inc(P);
    end;
  end;
  MarkAllDirty;
  Invalidate;
end;

{ Sprinkle bright/dark specks - the aluminium powder look while erasing. }
procedure TArtSurface.Grain(Amount, Density: Single);
var
  I, N, X, Y, D: Integer;
  P: PPix;
begin
  N := Round(FWidth * FHeight * EnsureRange(Density, 0, 1));
  for I := 1 to N do
  begin
    X := Random(FWidth);
    Y := Random(FHeight);
    D := Round((Random - 0.5) * 2 * Amount * 255);
    P := ScanLine(Y);
    Inc(P, X);
    P^.R := EnsureRange(P^.R + D, 0, 255);
    P^.G := EnsureRange(P^.G + D, 0, 255);
    P^.B := EnsureRange(P^.B + D, 0, 255);
  end;
  MarkAllDirty;
  Invalidate;
end;

{ Shift the image down by a few rows with a ragged edge, so the drawing
  looks like it is sliding off the screen. }
procedure TArtSurface.SmearDown(Rows: Integer);
var
  X, Y, Src: Integer;
  Dst, S: PPix;
begin
  if Rows <= 0 then Exit;
  for Y := FHeight - 1 downto 0 do
  begin
    Dst := ScanLine(Y);
    for X := 0 to FWidth - 1 do
    begin
      Src := Y - Rows - Random(2);
      if Src >= 0 then
      begin
        S := ScanLine(Src);
        Inc(S, X);
        Dst^ := S^;
      end;
      Inc(Dst);
    end;
  end;
  MarkAllDirty;
  Invalidate;
end;

procedure TArtSurface.CopyFrom(Src: TArtSurface; DX, DY: Integer);
var
  X, Y, W, H: Integer;
  S, D: PPix;
begin
  if Src = nil then Exit;
  W := Min(Src.Width, FWidth - DX);
  H := Min(Src.Height, FHeight - DY);
  for Y := 0 to H - 1 do
  begin
    S := Src.ScanLine(Y);
    D := ScanLine(Y + DY);
    Inc(D, DX);
    for X := 0 to W - 1 do
    begin
      D^ := S^;
      Inc(S);
      Inc(D);
    end;
  end;
  MarkAllDirty;
  Invalidate;
end;

procedure TArtSurface.CopyRegion(Src: TArtSurface; SrcX, SrcY, DX, DY, W, H: Integer);
var
  X, Y, X0, Y0, X1, Y1: Integer;
  S, D: PPix;
begin
  if Src = nil then Exit;
  if (W <= 0) or (H <= 0) then Exit;
  if (FWidth <= 0) or (FHeight <= 0) then Exit;
  if (Src.Width <= 0) or (Src.Height <= 0) then Exit;
  { A copy that starts a very long way outside either surface has nothing in
    it to copy, and the arithmetic that works that out overflows long before
    it can say so.  Anything further out than any real window turns into
    nothing at all, which is what it would have come to anyway.  This is the
    guard the cursor overlay needed: it asks for a square of artwork around
    the pointer, and one bad projected coordinate made that square start at
    a place no clamp could bring back. }
  if (Abs(SrcX) > 1000000) or (Abs(SrcY) > 1000000) or
     (Abs(DX) > 1000000) or (Abs(DY) > 1000000) then Exit;
  X0 := Max(0, Max(-SrcX, -DX));
  Y0 := Max(0, Max(-SrcY, -DY));
  X1 := Min(W, Min(Src.Width - SrcX, FWidth - DX));
  Y1 := Min(H, Min(Src.Height - SrcY, FHeight - DY));
  if (X1 <= X0) or (Y1 <= Y0) then Exit;
  for Y := Y0 to Y1 - 1 do
  begin
    S := Src.ScanLine(SrcY + Y);
    Inc(S, SrcX + X0);
    D := ScanLine(DY + Y);
    Inc(D, DX + X0);
    for X := X0 to X1 - 1 do
    begin
      D^ := S^;
      Inc(S);
      Inc(D);
    end;
  end;
  MarkAllDirty;
  Invalidate;
end;

procedure TArtSurface.Snapshot(out Buf: TBytes);
var
  Y: Integer;
begin
  SetLength(Buf, FWidth * FHeight * 4);
  for Y := 0 to FHeight - 1 do
    Move(ScanLine(Y)^, Buf[Y * FWidth * 4], FWidth * 4);
end;

procedure TArtSurface.Restore(const Buf: TBytes);
var
  Y: Integer;
begin
  if Length(Buf) <> FWidth * FHeight * 4 then Exit;
  for Y := 0 to FHeight - 1 do
    Move(Buf[Y * FWidth * 4], ScanLine(Y)^, FWidth * 4);
  MarkAllDirty;
  Invalidate;
end;

function TArtSurface.AsBitmap: TBitmap;
begin
  if not FBitmapValid then
  begin
    FBitmap.LoadFromIntfImage(FImage);
    FBitmapValid := True;
  end;
  Result := FBitmap;
end;

procedure TArtSurface.DrawTo(ACanvas: TCanvas; X, Y: Integer);
begin
  ACanvas.Draw(X, Y, AsBitmap);
end;

{ ---------------------------------------------------------------------- }
{ text                                                                     }
{ ---------------------------------------------------------------------- }

{ Glyphs have to come from the widgetset, so text is rendered white-on-black
  into a scratch bitmap and then blended in using its luminance as coverage.
  That keeps dimension labels as crisp as the rest of the surface. }
var
  FScratch: TBitmap = nil;
  FScratchImg: TLazIntfImage = nil;

procedure EnsureScratch;
begin
  if FScratch = nil then
  begin
    FScratch := TBitmap.Create;
    FScratch.PixelFormat := pf32bit;
    FScratch.SetSize(8, 8);
  end;
end;

function TArtSurface.TextExtent(const S: string; AFont: TFont): TSize;
begin
  EnsureScratch;
  FScratch.Canvas.Font.Assign(AFont);
  Result := FScratch.Canvas.TextExtent(S);
end;

procedure TArtSurface.TextOut(X, Y: Integer; const S: string; AFont: TFont;
  const C: TPix; Alpha: Single);
var
  Sz: TSize;
  IX, IY: Integer;
  Col: TFPColor;
  Cov: Single;
begin
  if S = '' then Exit;
  EnsureScratch;
  FScratch.Canvas.Font.Assign(AFont);
  Sz := FScratch.Canvas.TextExtent(S);
  if (Sz.cx <= 0) or (Sz.cy <= 0) then Exit;

  FScratch.SetSize(Sz.cx + 2, Sz.cy + 2);
  FScratch.Canvas.Font.Assign(AFont);
  FScratch.Canvas.Brush.Style := bsSolid;
  FScratch.Canvas.Brush.Color := clBlack;
  FScratch.Canvas.FillRect(0, 0, FScratch.Width, FScratch.Height);
  FScratch.Canvas.Brush.Style := bsClear;
  FScratch.Canvas.Font.Color := clWhite;
  FScratch.Canvas.TextOut(1, 1, S);

  if FScratchImg = nil then
    FScratchImg := TLazIntfImage.Create(0, 0);
  FScratchImg.LoadFromBitmap(FScratch.Handle, 0);

  for IY := 0 to FScratchImg.Height - 1 do
    for IX := 0 to FScratchImg.Width - 1 do
    begin
      Col := FScratchImg.Colors[IX, IY];
      Cov := ((Col.red shr 8) * 0.30 + (Col.green shr 8) * 0.59 +
              (Col.blue shr 8) * 0.11) / 255;
      if Cov > 0.004 then
        BlendPixel(X + IX - 1, Y + IY - 1, C, Cov * Alpha);
    end;
end;

procedure TArtSurface.SaveToPNG(const AFileName: string);
var
  Png: TPortableNetworkGraphic;
begin
  Png := TPortableNetworkGraphic.Create;
  try
    Png.Assign(AsBitmap);
    Png.SaveToFile(AFileName);
  finally
    Png.Free;
  end;
end;

finalization
  FScratchImg.Free;
  FScratch.Free;

end.
