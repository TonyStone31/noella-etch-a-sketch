unit uShoot;

{ Taking pictures of the model.

  Everything here writes a file and nothing here opens a window, which is the
  whole point of it being its own unit: the export dialog is built out of
  BGRAControls, and BGRAControls drags in half the IDE, so nothing that only
  wants to save a picture should have to link all that - and a test that
  wants to check a GIF really is a GIF should not need a screen at all.

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Types, Graphics, FPImage, FPWriteJPEG,
  BGRABitmap, BGRABitmapTypes, BGRAAnimatedGif,
  uSurface, uWork;

const
  { The GIF is the one export that can run away with itself - a hundred
    frames of a big drawing is a big file and a long wait - so it is kept on
    a short lead, and the dialog says what it will come to before you ask
    for it. }
  GIF_MAX_SECONDS = 20;
  GIF_MAX_FRAMES  = 300;

{ One frame of the model at whatever size is wanted, with the same view the
  screen has.  Public because the printer and the report shot want it too. }
function ShootFrame(Doc: TWorkDoc; const V: TProjector; W, H: Integer;
  U: TUnitSystem; AFont: TFont; const LabelCol: TPix; EdgeW: Single;
  const Bg: TPix; Quick: Boolean): TArtSurface;

{ The same view, framed for a different size of picture. }
function Fitted(const V: TProjector; SrcW, SrcH, W, H: Integer): TProjector;

{ Smoothly from one view to another, T running 0 to 1.  Eased at both ends,
  and the zoom is multiplied rather than added - a zoom that goes 1, 2, 3, 4
  appears to slow down as it closes in; one that goes 1, 2, 4, 8 looks even. }
function TweenView(const A, B: TProjector; T: Double): TProjector;

{ A still, written as PNG or JPEG.  Quality is for the JPEG only. }
procedure SaveStill(Doc: TWorkDoc; const V: TProjector; SrcW, SrcH, W, H: Integer;
  U: TUnitSystem; AFont: TFont; const LabelCol: TPix; EdgeW: Single;
  const Path: string; Jpeg: Boolean; Quality: Integer; Transparent: Boolean);

{ The little film: N frames easing from VA to VB, written as an animated GIF.
  Returns how many frames went in. }
function SaveOrbitGif(Doc: TWorkDoc; const VA, VB: TProjector;
  SrcW, SrcH, W, H: Integer; U: TUnitSystem; AFont: TFont;
  const LabelCol: TPix; EdgeW: Single; Seconds: Double; Fps: Integer;
  Loop: Boolean; const Path: string): Integer;

implementation

function Fitted(const V: TProjector; SrcW, SrcH, W, H: Integer): TProjector;
var
  K: Double;
begin
  Result := V;
  if (SrcW <= 0) or (SrcH <= 0) or (W <= 0) or (H <= 0) then Exit;
  { the same framing, not the same pixels: everything scales together, so a
    picture asked for at four times the size is the same picture }
  K := Min(W / SrcW, H / SrcH);
  Result.Ppu := V.Ppu * K;
  Result.OX := W / 2 + (V.OX - SrcW / 2) * K;
  Result.OY := H / 2 + (V.OY - SrcH / 2) * K;
end;

function ShootFrame(Doc: TWorkDoc; const V: TProjector; W, H: Integer;
  U: TUnitSystem; AFont: TFont; const LabelCol: TPix; EdgeW: Single;
  const Bg: TPix; Quick: Boolean): TArtSurface;
var
  WasQuick: Boolean;
begin
  Result := TArtSurface.Create(Max(1, W), Max(1, H));
  { A surface is opaque unless it is told otherwise - right for the screen,
    where there is always paper behind it, and wrong for a picture meant to
    be dropped onto somebody's slide.  Clear paints alpha 255 whatever it is
    given, so a see-through background is a different call, and the flag has
    to go on before anything is drawn or every stroke fills its alpha in
    again on the way past. }
  if Bg.A < 255 then
  begin
    Result.PreserveAlpha := True;
    Result.ClearTransparent;
  end
  else
    Result.Clear(Bg);
  if Doc = nil then Exit;
  WasQuick := Doc.Quick;
  Doc.Quick := Quick;
  Result.QuickFill := Quick;
  try
    if Doc.Live > 0 then
      Doc.Render(Result, V, U, AFont, LabelCol, EdgeW);
  finally
    Doc.Quick := WasQuick;
  end;
end;

{ Straight across: TPix and TBGRAPixel are both blue, green, red, alpha in
  that order, so a row is a row. }
function ToBGRA(S: TArtSurface): TBGRABitmap;
var
  Y: Integer;
begin
  Result := TBGRABitmap.Create(S.Width, S.Height);
  for Y := 0 to S.Height - 1 do
    Move(S.ScanLine(Y)^, Result.ScanLine[Y]^, S.Width * SizeOf(TBGRAPixel));
  Result.InvalidateBitmap;
end;

function TweenView(const A, B: TProjector; T: Double): TProjector;
var
  E: Double;
begin
  E := Max(0, Min(1, T));
  E := E * E * (3 - 2 * E);        { ease in and out }
  Result := A;
  Result.Az := A.Az + (B.Az - A.Az) * E;
  Result.El := A.El + (B.El - A.El) * E;
  Result.OX := A.OX + (B.OX - A.OX) * E;
  Result.OY := A.OY + (B.OY - A.OY) * E;
  if (A.Ppu > 1E-9) and (B.Ppu > 1E-9) then
    Result.Ppu := A.Ppu * Exp(Ln(B.Ppu / A.Ppu) * E)
  else
    Result.Ppu := A.Ppu;
end;

procedure SaveStill(Doc: TWorkDoc; const V: TProjector; SrcW, SrcH, W, H: Integer;
  U: TUnitSystem; AFont: TFont; const LabelCol: TPix; EdgeW: Single;
  const Path: string; Jpeg: Boolean; Quality: Integer; Transparent: Boolean);
var
  S: TArtSurface;
  Bmp: TBGRABitmap;
  Wr: TFPWriterJPEG;
  Img: TFPMemoryImage;
  Bg: TPix;
begin
  if Transparent and not Jpeg then Bg := Pix(255, 255, 255, 0)
  else Bg := Pix(255, 255, 255);
  S := ShootFrame(Doc, Fitted(V, SrcW, SrcH, W, H), W, H, U, AFont, LabelCol,
    EdgeW, Bg, False);
  try
    Bmp := ToBGRA(S);
    try
      if not Jpeg then
        Bmp.SaveToFile(Path)
      else
      begin
        { JPEG has no transparency to keep and its own idea of quality }
        Img := TFPMemoryImage.Create(0, 0);
        Wr := TFPWriterJPEG.Create;
        try
          Img.Assign(Bmp);
          Wr.CompressionQuality := Max(20, Min(100, Quality));
          Img.SaveToFile(Path, Wr);
        finally
          Wr.Free;
          Img.Free;
        end;
      end;
    finally
      Bmp.Free;
    end;
  finally
    S.Free;
  end;
end;

function SaveOrbitGif(Doc: TWorkDoc; const VA, VB: TProjector;
  SrcW, SrcH, W, H: Integer; U: TUnitSystem; AFont: TFont;
  const LabelCol: TPix; EdgeW: Single; Seconds: Double; Fps: Integer;
  Loop: Boolean; const Path: string): Integer;
var
  I, Delay: Integer;
  S: TArtSurface;
  Gif: TBGRAAnimatedGif;
begin
  Seconds := Max(0.2, Min(GIF_MAX_SECONDS, Seconds));
  Fps := Max(2, Min(50, Fps));
  Result := Max(2, Min(GIF_MAX_FRAMES, Round(Seconds * Fps)));
  Delay := Max(20, Round(1000 / Fps));
  Gif := TBGRAAnimatedGif.Create;
  try
    Gif.SetSize(W, H);
    { One frame short of the whole way round.  The last frame of a loop IS
      the first frame, and sending it twice makes the spin catch once every
      time round. }
    for I := 0 to Result - 1 do
    begin
      S := ShootFrame(Doc, Fitted(TweenView(VA, VB, I / Result), SrcW, SrcH, W, H),
        W, H, U, AFont, LabelCol, EdgeW, Pix(255, 255, 255), False);
      try
        { the gif takes ownership of the frame }
        Gif.AddFullFrame(ToBGRA(S), Delay, True, dmSetExceptTransparent, True);
      finally
        S.Free;
      end;
    end;
    if Loop then Gif.LoopCount := 0 else Gif.LoopCount := 1;
    Gif.OptimizeFrames;
    Gif.SaveToFile(Path);
  finally
    Gif.Free;
  end;
end;


end.
