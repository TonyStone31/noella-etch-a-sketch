unit uShoot;

{ Taking pictures of the model.

  Everything here writes a file and nothing here opens a window, which is the
  whole point of it being its own unit: the export dialog is built out of
  BGRAControls, and BGRAControls drags in half the IDE, so nothing that only
  wants to save a picture should have to link all that - and a test that
  wants to check a GIF really is a GIF should not need a screen at all.

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE.
}

{$mode objfpc}{$H+}{$modeswitch nestedprocvars}

interface

uses
  Classes, SysUtils, Math, Types, Graphics, FPImage, FPWriteJPEG,
  BGRABitmap, BGRABitmapTypes, BGRAAnimatedGif,
  uSurface, uWork, uSkin;

const
  { The GIF is the one export that can run away with itself - a hundred
    frames of a big drawing is a big file and a long wait - so it is kept on
    a short lead, and the dialog says what it will come to before you ask
    for it. }
  GIF_MAX_SECONDS = 20;
  GIF_MAX_FRAMES  = 300;
  { And a ceiling on the whole film, not just the number of frames.

    An animated GIF is built in memory in its entirety - every frame is held
    until the last one is in, and the packing pass then duplicates them as it
    walks.  Three hundred frames of 800 by 600 is around 576 MB of frames
    before any of that, which is what Tony's Windows machine fell over
    exporting a 15.9 second recording.

    So the number of frames is worked out from the area as well: whatever
    fits in the budget.  The film keeps its full length either way - what
    gives is the frame rate, not the ending, because losing the end of
    somebody's move is a worse answer than making it a little choppier. }
  GIF_MAX_PIXELS = 50000000;
  { and packing, which duplicates every frame as it walks, only where that
    duplication is affordable on top of the frames themselves }
  GIF_PACK_PIXELS = 20000000;

type
  { Where the camera was, and when.  A recording is a list of these and
    nothing is captured as pixels, so the film is rendered afterwards, at any
    size, and without the cursor, the snapping lines or anything else that
    happened to be on the screen while it was being made. }
  TCamKey = record
    T: Double;          { seconds from the start }
    V: TProjector;
  end;
  TCamPath = array of TCamKey;

{ Where the camera was at that moment, between whichever two it was recorded
  between. }
function SampleCamPath(const P: TCamPath; T: Double): TProjector;
{ How long the recording runs. }
function CamPathLength(const P: TCamPath): Double;

{ The three axes over a shot, the way the drawing area draws them: solid one
  way from the origin, dashed the other.  They are the one piece of screen
  furniture worth keeping in an exported film - they say which way up the
  thing is, and a spin without them is a shape turning in nothing. }
procedure PaintAxesOn(S: TArtSurface; const V: TProjector);

{ Draw the model into a surface that already exists.  A film wants this
  rather than ShootFrame: making and destroying a bitmap for every frame of
  an eighty-frame GIF is eighty allocations and, on Windows, eighty device
  contexts, which is a lot of rope for no reason. }
procedure ShootInto(S: TArtSurface; Doc: TWorkDoc; const V: TProjector;
  U: TUnitSystem; AFont: TFont; const LabelCol: TPix; EdgeW: Single;
  const Bg: TPix; Quick: Boolean);

{ One frame of the model at whatever size is wanted, with the same view the
  screen has.  Public because the printer and the report shot want it too. }
function ShootFrame(Doc: TWorkDoc; const V: TProjector; W, H: Integer;
  U: TUnitSystem; AFont: TFont; const LabelCol: TPix; EdgeW: Single;
  const Bg: TPix; Quick: Boolean): TArtSurface;

{ --- moving the camera ------------------------------------------------

  The three things a mouse does to a view, in one place, so the export
  preview and the recording window behave the same as each other and as the
  drawing area: drag turns it, shift-drag or the right button slides it, the
  wheel zooms.

  Every one of them works the sum out into a local before storing it, and
  that is not a style preference.  uMain carries a long comment about this:
  at -O3, which is what a release is built with, this compiler has been seen
  to generate

      Field := Field + (Y - Ref) * K

  with the read coming in through the register holding the object and the
  store going out through the register holding (Y - Ref), so the value lands
  at an address near zero and the program faults.  Correct at -O2 and below,
  wrong at -O3.  Writing it out into a local first costs nothing and is the
  only thing standing between these lines and that fault. }
procedure OrbitBy(var V: TProjector; DX, DY: Double);
procedure PanBy(var V: TProjector; DX, DY: Double);
procedure ZoomBy(var V: TProjector; Factor: Double);

{ The same view, framed for a different size of picture. }
function Fitted(const V: TProjector; SrcW, SrcH, W, H: Integer): TProjector;

{ Smoothly from one view to another, T running 0 to 1.  Eased at both ends,
  and the zoom is multiplied rather than added - a zoom that goes 1, 2, 3, 4
  appears to slow down as it closes in; one that goes 1, 2, 4, 8 looks even. }
function TweenView(const A, B: TProjector; T: Double): TProjector;

{ A still, written as PNG or JPEG.  Quality is for the JPEG only. }
procedure SaveStill(Doc: TWorkDoc; const V: TProjector; SrcW, SrcH, W, H: Integer;
  U: TUnitSystem; AFont: TFont; const LabelCol: TPix; EdgeW: Single;
  const Path: string; Jpeg: Boolean; Quality: Integer; Transparent, Axes: Boolean);

{ The little film: N frames easing from VA to VB, written as an animated GIF.
  Returns how many frames went in. }
function SaveOrbitGif(Doc: TWorkDoc; const VA, VB: TProjector;
  SrcW, SrcH, W, H: Integer; U: TUnitSystem; AFont: TFont;
  const LabelCol: TPix; EdgeW: Single; Seconds: Double; Fps: Integer;
  Loop, Axes: Boolean; const Path: string): Integer;

type
  { where a film says what it is up to }
  TStageSay = procedure(const S: string) of object;

var
  OnFilmStage: TStageSay = nil;

{ How many frames a film of this length at this size will actually come to,
  and the rate that gives.  The dialog asks so it can say, rather than
  letting somebody find out by waiting. }
procedure FilmPlan(Seconds: Double; Fps, W, H: Integer;
  out Frames, RealFps: Integer);

{ The same, but following a camera move somebody actually made rather than
  easing between two ends. }
function SavePathGif(Doc: TWorkDoc; const Cam: TCamPath;
  SrcW, SrcH, W, H: Integer; U: TUnitSystem; AFont: TFont;
  const LabelCol: TPix; EdgeW: Single; Fps: Integer;
  Loop, Axes: Boolean; const Path: string): Integer;

implementation

type
  { where the camera is for frame I of Count - the one thing a spin and a
    recording disagree about }
  TViewAt = function(I, Count: Integer): TProjector is nested;

{ Somewhere to say what the film is doing, so a failure names the frame it
  died on rather than the whole job.  Set by whoever is driving. }
procedure Say(const S: string);
begin
  if Assigned(OnFilmStage) then OnFilmStage(S);
end;

procedure FilmPlan(Seconds: Double; Fps, W, H: Integer;
  out Frames, RealFps: Integer);
var
  Room: Int64;
begin
  Seconds := Max(0.2, Min(GIF_MAX_SECONDS, Seconds));
  Fps := Max(2, Min(50, Fps));
  Frames := Max(2, Round(Seconds * Fps));
  if Frames > GIF_MAX_FRAMES then Frames := GIF_MAX_FRAMES;
  Room := GIF_MAX_PIXELS div Max(Int64(1), Int64(W) * H);
  if Room < 2 then Room := 2;
  if Frames > Room then Frames := Room;
  RealFps := Max(1, Round(Frames / Seconds));
end;

function CamPathLength(const P: TCamPath): Double;
begin
  if Length(P) = 0 then Result := 0 else Result := P[High(P)].T;
end;

{ Straight between two views, with no easing at all: what a recording wants,
  because whatever easing there is belongs to the hand that made it, and
  smoothing it again only fights that. }
function TweenLinear(const A, B: TProjector; T: Double): TProjector;
begin
  T := Max(0, Min(1, T));
  Result := A;
  Result.Az := A.Az + (B.Az - A.Az) * T;
  Result.El := A.El + (B.El - A.El) * T;
  Result.OX := A.OX + (B.OX - A.OX) * T;
  Result.OY := A.OY + (B.OY - A.OY) * T;
  if (A.Ppu > 1E-9) and (B.Ppu > 1E-9) then
    Result.Ppu := A.Ppu * Exp(Ln(B.Ppu / A.Ppu) * T)
  else
    Result.Ppu := A.Ppu;
end;

function SampleCamPath(const P: TCamPath; T: Double): TProjector;
var
  Lo, Hi, M: Integer;
  Span: Double;
begin
  if Length(P) = 0 then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Exit;
  end;
  if T <= P[0].T then Exit(P[0].V);
  if T >= P[High(P)].T then Exit(P[High(P)].V);
  Lo := 0;
  Hi := High(P);
  while Hi - Lo > 1 do
  begin
    M := (Lo + Hi) div 2;
    if P[M].T <= T then Lo := M else Hi := M;
  end;
  Span := P[Hi].T - P[Lo].T;
  if Span <= 1E-9 then Exit(P[Lo].V);
  Result := TweenLinear(P[Lo].V, P[Hi].V, (T - P[Lo].T) / Span);
end;

procedure PaintAxesOn(S: TArtSurface; const V: TProjector);
var
  K, N: Integer;
  L, Len, DX, DY: Double;
  B: TP3;
  PO, PB: TPointF;
  Col: TPix;
begin
  if V.Ppu <= 1E-9 then Exit;
  L := (S.Width + S.Height) / V.Ppu;
  PO := Project(V, P3(0, 0, 0));
  if IsNan(PO.X) or IsNan(PO.Y) or IsInfinite(PO.X) or IsInfinite(PO.Y) then Exit;
  for K := 0 to 2 do
  begin
    Col := AxisPix(K);
    B := P3(0, 0, 0);
    case K of
      0: B.X := L;
      1: B.Y := L;
    else B.Z := L;
    end;
    PB := Project(V, B);
    Len := Sqrt(Sqr(PB.X - PO.X) + Sqr(PB.Y - PO.Y));
    { an axis pointing straight at the camera has no length on the glass, and
      drawing it puts a dot of colour on the origin that means nothing }
    if Len < 1 then Continue;
    S.Line(PO.X, PO.Y, PB.X, PB.Y, 1.8, Col, 0.55);
    DX := (PO.X - PB.X) / Len;
    DY := (PO.Y - PB.Y) / Len;
    N := 0;
    while N * 11 < Len do
    begin
      S.Line(PO.X + DX * (N * 11), PO.Y + DY * (N * 11),
             PO.X + DX * (N * 11 + 6), PO.Y + DY * (N * 11 + 6),
             1.4, Col, 0.42);
      Inc(N);
    end;
  end;
  S.Touch;
end;

procedure OrbitBy(var V: TProjector; DX, DY: Double);
var
  A, E: Double;
begin
  { drag right and the model follows the cursor round, the way it does when
    you push something on a turntable - so the azimuth goes the other way }
  A := V.Az - DX * 0.01;
  E := V.El + DY * 0.01;
  if E < -1.45 then E := -1.45;
  if E > 1.45 then E := 1.45;
  V.Az := A;
  V.El := E;
end;

procedure PanBy(var V: TProjector; DX, DY: Double);
var
  X, Y: Double;
begin
  X := V.OX + DX;
  Y := V.OY + DY;
  V.OX := X;
  V.OY := Y;
end;

procedure ZoomBy(var V: TProjector; Factor: Double);
var
  P: Double;
begin
  if Factor <= 0 then Exit;
  P := V.Ppu * Factor;
  if P < 1E-4 then P := 1E-4;
  if P > 1E6 then P := 1E6;
  V.Ppu := P;
end;

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

procedure ShootInto(S: TArtSurface; Doc: TWorkDoc; const V: TProjector;
  U: TUnitSystem; AFont: TFont; const LabelCol: TPix; EdgeW: Single;
  const Bg: TPix; Quick: Boolean);
var
  WasQuick: Boolean;
begin
  if S = nil then Exit;
  if Bg.A < 255 then
  begin
    S.PreserveAlpha := True;
    S.ClearTransparent;
  end
  else
  begin
    S.PreserveAlpha := False;
    S.Clear(Bg);
  end;
  if Doc = nil then Exit;
  WasQuick := Doc.Quick;
  Doc.Quick := Quick;
  S.QuickFill := Quick;
  try
    if Doc.Live > 0 then
      Doc.Render(S, V, U, AFont, LabelCol, EdgeW);
  finally
    Doc.Quick := WasQuick;
  end;
end;

function ShootFrame(Doc: TWorkDoc; const V: TProjector; W, H: Integer;
  U: TUnitSystem; AFont: TFont; const LabelCol: TPix; EdgeW: Single;
  const Bg: TPix; Quick: Boolean): TArtSurface;
begin
  Result := TArtSurface.Create(Max(1, W), Max(1, H));
  { a surface that did not come back the size it was asked for is a surface
    nothing downstream should be writing into }
  if (Result.Width < Max(1, W)) or (Result.Height < Max(1, H)) then
  begin
    Result.Free;
    raise Exception.CreateFmt('could not make a picture %d by %d', [W, H]);
  end;
  ShootInto(Result, Doc, V, U, AFont, LabelCol, EdgeW, Bg, Quick);
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
  const Path: string; Jpeg: Boolean; Quality: Integer; Transparent, Axes: Boolean);
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
    if Axes then PaintAxesOn(S, Fitted(V, SrcW, SrcH, W, H));
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

{ Every frame of a film, however the camera got there.  One place, because
  the only difference between a spin and a recording is where the view for
  frame N comes from. }
function WriteFilm(Doc: TWorkDoc; SrcW, SrcH, W, H: Integer;
  U: TUnitSystem; AFont: TFont; const LabelCol: TPix; EdgeW: Single;
  Frames: Integer; Seconds: Double; Loop, Axes: Boolean; const Path: string;
  const ViewAt: TViewAt): Integer;
var
  I, Delay: Integer;
  S: TArtSurface;
  V: TProjector;
  Gif: TBGRAAnimatedGif;
begin
  Result := Frames;
  { the wait between frames comes from the length and the count, so dropping
    the rate to fit the budget makes the film choppier and not shorter }
  Delay := Max(20, Round(Seconds * 1000 / Max(1, Frames)));
  Gif := nil;
  { one surface for the whole film, drawn over and over }
  S := TArtSurface.Create(Max(1, W), Max(1, H));
  try
    if (S.Width < W) or (S.Height < H) then
      raise Exception.CreateFmt('could not make a picture %d by %d', [W, H]);
    Gif := TBGRAAnimatedGif.Create;
    Gif.SetSize(W, H);
    for I := 0 to Frames - 1 do
    begin
      Say(Format('drawing frame %d of %d at %dx%d', [I + 1, Frames, W, H]));
      V := Fitted(ViewAt(I, Frames), SrcW, SrcH, W, H);
      ShootInto(S, Doc, V, U, AFont, LabelCol, EdgeW, Pix(255, 255, 255), False);
      { the axes go on after the drawing rather than under it - at this
        weight it reads the same and saves compositing a second surface for
        every frame }
      if Axes then PaintAxesOn(S, V);
      { the gif takes ownership of each frame it is handed }
      Gif.AddFullFrame(ToBGRA(S), Delay, True, dmSetExceptTransparent, True);
    end;
    if Loop then Gif.LoopCount := 0 else Gif.LoopCount := 1;
    { Packing walks the film making a duplicate of every frame as it goes, on
      top of the frames themselves.  On a long one that is the biggest thing
      the export ever asks for, and on a turning model it buys almost nothing
      anyway, because every pixel changes between frames and there is no
      still region to leave out.  So past a certain length it is skipped. }
    if Int64(Frames) * W * H <= GIF_PACK_PIXELS then
    begin
      Say(Format('packing %d frames', [Frames]));
      Gif.OptimizeFrames;
    end;
    Say(Format('writing %s', [ExtractFileName(Path)]));
    Gif.SaveToFile(Path);
  finally
    Gif.Free;
    S.Free;
  end;
end;

function SaveOrbitGif(Doc: TWorkDoc; const VA, VB: TProjector;
  SrcW, SrcH, W, H: Integer; U: TUnitSystem; AFont: TFont;
  const LabelCol: TPix; EdgeW: Single; Seconds: Double; Fps: Integer;
  Loop, Axes: Boolean; const Path: string): Integer;
var
  A, B: TProjector;
  N, Rate: Integer;

  { One frame short of the whole way round.  The last frame of a loop IS the
    first one, and sending both makes the spin catch once every time round. }
  function At(I, Count: Integer): TProjector;
  begin
    Result := TweenView(A, B, I / Count);
  end;

begin
  A := VA;
  B := VB;
  Seconds := Max(0.2, Min(GIF_MAX_SECONDS, Seconds));
  FilmPlan(Seconds, Fps, W, H, N, Rate);
  Result := WriteFilm(Doc, SrcW, SrcH, W, H, U, AFont, LabelCol, EdgeW,
    N, Seconds, Loop, Axes, Path, @At);
end;

function SavePathGif(Doc: TWorkDoc; const Cam: TCamPath;
  SrcW, SrcH, W, H: Integer; U: TUnitSystem; AFont: TFont;
  const LabelCol: TPix; EdgeW: Single; Fps: Integer;
  Loop, Axes: Boolean; const Path: string): Integer;
var
  Secs: Double;
  N, Rate: Integer;
  Rec: TCamPath;

  function At(I, Count: Integer): TProjector;
  begin
    { a recording plays to its end, so the last frame IS the last moment -
      unlike a loop, which would otherwise show its first frame twice }
    if Count < 2 then Result := SampleCamPath(Rec, 0)
    else Result := SampleCamPath(Rec, Secs * I / (Count - 1));
  end;

begin
  Rec := Cam;
  Secs := Max(0.2, Min(GIF_MAX_SECONDS, CamPathLength(Cam)));
  FilmPlan(Secs, Fps, W, H, N, Rate);
  Result := WriteFilm(Doc, SrcW, SrcH, W, H, U, AFont, LabelCol, EdgeW,
    N, Secs, Loop, Axes, Path, @At);
end;


end.
