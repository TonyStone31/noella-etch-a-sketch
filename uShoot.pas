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
  { the colour reducer the GIF writer needs - see the initialization }
  BGRAPalette, BGRAColorQuantization,
  uSurface, uWork, uSkin, uWebPAnim;

const
  { The GIF is the one export that can run away with itself - a hundred
    frames of a big drawing is a big file and a long wait - so it is kept on
    a short lead, and the dialog says what it will come to before you ask
    for it. }
  GIF_MAX_SECONDS = 20;
  GIF_MAX_FRAMES  = 300;
  { What a film is asked to run at.  It used to be a box on the export
    dialog, which is a question nobody has an opinion about: the length of
    the recording and the size of the picture between them decide how many
    frames there is room for, and FilmPlan hands back what it could afford. }
  GIF_FPS = 20;
  { And a ceiling on the whole film, not just the number of frames.

    Not because it crashes - that was a missing colour quantizer and is fixed
    in the initialization below - but because a GIF is assembled whole in
    memory before any of it is written, and because the point of a GIF is
    that you can send it.

    Measured, on the most complicated drawing to hand: a four second spin at
    fifteen a second comes to 410 KB at 320x240, 1.35 MB at 800x600.  Call it
    a twentieth of a byte per pixel per frame.  Fifty million pixel-frames is
    therefore around 2.5 MB of file and 200 MB of frames held while it is
    built, which are both numbers a person can live with.

    The film keeps its full length whatever this costs it - what gives is the
    frame rate, not the ending, because losing the end of somebody's move is
    a worse answer than making it a little choppier. }
  GIF_MAX_PIXELS = 50000000;
  { Measured bytes per pixel per frame, for saying how big it will be before
    somebody waits for it.  It varies a lot with what is on the screen - a
    busy model filling the frame came to 0.047, the same model spinning and
    zooming to 0.014 - so this sits between them and the label says "about".
    The decision it has to support is 300 KB against 8 MB, not 700 KB against
    900 KB. }
  GIF_BYTES_PER_PIXEL = 0.03;
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

{ Does the clip end where it began?

  This is asked of the clip rather than of the walk that made it, because the
  clip is the thing being filmed.  A turntable comes back round to its start
  and a rise does not; so does or does not a move somebody pointed by hand,
  and nothing about how it was made needs to be remembered to find out.

  It matters because a film that loops has to join back onto itself.  A clip
  that closes must not render its first pose twice - one frozen frame every
  time round - and a clip that does not close will jump unless something is
  done about it.  See TFilmLoop. }
function CamPathCloses(const P: TCamPath): Boolean;

{ The three axes over a shot, the way the drawing area draws them: solid one
  way from the origin, dashed the other.  They are the one piece of screen
  furniture worth keeping in an exported film - they say which way up the
  thing is, and a spin without them is a shape turning in nothing. }
procedure PaintAxesOn(S: TArtSurface; const V: TProjector);

{ Draw the model into a surface that already exists.  A film wants this
  rather than ShootFrame: making and destroying a bitmap for every frame of
  an eighty-frame GIF is eighty allocations and, on Windows, eighty device
  contexts, which is a lot of rope for no reason. }
{ Axes draws the three axes UNDER the model, which is where they belong and
  where the drawing area has always put them: it rules them onto the paper
  and composites the model over the top.  Out here they used to go on
  afterwards, so every axis was drawn straight through whatever solid stood
  in front of it - a red line across the middle of a box, in a film of the
  box, which happens nowhere on screen. }
procedure ShootInto(S: TArtSurface; Doc: TWorkDoc; const V: TProjector;
  U: TUnitSystem; AFont: TFont; const LabelCol: TPix; EdgeW: Single;
  const Bg: TPix; Quick: Boolean; Axes: Boolean = False);

{ One frame of the model at whatever size is wanted, with the same view the
  screen has.  Public because the printer and the report shot want it too. }
function ShootFrame(Doc: TWorkDoc; const V: TProjector; W, H: Integer;
  U: TUnitSystem; AFont: TFont; const LabelCol: TPix; EdgeW: Single;
  const Bg: TPix; Quick: Boolean; Axes: Boolean = False): TArtSurface;

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

{ Zoom keeping whatever is under a point exactly where it is, which is what
  the drawing area does and the reason a wheel over a preview that zooms to
  the middle instead feels wrong.

  No unprojecting needed: a screen position is O + Ppu * f(point), so scaling
  Ppu by k and holding A still gives O' = A - k * (A - O). }
procedure ZoomAt(var V: TProjector; Factor, AX, AY: Double);

{ Keep a point of the model at a fixed place on the screen.

  A TProjector turns about the world origin - there is no pivot in it - so
  spinning a building drawn half a mile from zero swings it clean out of
  frame.  Every camera move here therefore ends by putting the point of
  interest back where it belongs, which costs one projection and makes the
  whole thing behave as though it had a pivot. }
procedure HoldAt(var V: TProjector; const P: TP3; SX, SY: Double);

{ A canned camera move: where to look at the moment T of a walk that lasts
  one unit, turning about C and starting from V0.  These are the "show me the
  thing" moves - see TWalk. }
type
  TWalk = (wkTurntable, wkRise, wkUnderOver, wkNod, wkHalfBack, wkCorners,
           wkLookAll, wkPushIn);

const
  WALK_NAME: array[TWalk] of string =
    ('Turntable - one turn on the spot',
     'Rise - a turn, climbing as it goes',
     'Underneath to over the top',
     'Nod - down to up and back, no turn',
     'Half a turn, and back again',
     'Corner to corner, over the top',
     'The full look - round, over and under',
     'Push in - closing, drifting round');

{ Where a canned walk is looking at the moment T, 0 to 1.  C is what it turns
  about, and Frame is the screen point to hold it at. }
function WalkAt(Kind: TWalk; const V0: TProjector; const C: TP3;
  FrameX, FrameY, T: Double): TProjector;

{ The scale Fitted uses to put a source-sized view into a W by H picture, so
  a mouse movement measured in the preview can be handed back in the terms
  the view is actually kept in. }
function ViewScale(SrcW, SrcH, W, H: Integer): Double;

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

type
  { where a film says what it is up to }
  TStageSay = procedure(const S: string) of object;
  { and how far along it is, for something to show.  A twelve second film is
    three hundred drawings of the model and the wait is real, so it says so
    as it goes rather than leaving somebody looking at a window that has
    stopped answering. }
  TFilmStep = procedure(Done, Total: Integer; const What: string) of object;

var
  OnFilmStage: TStageSay = nil;
  OnFilmStep: TFilmStep = nil;

{ How many frames a film of this length at this size will actually come to,
  and the rate that gives.  The dialog asks so it can say, rather than
  letting somebody find out by waiting. }
procedure FilmPlan(Seconds: Double; Fps, W, H: Integer;
  out Frames, RealFps: Integer);

{ The same, but following a camera move somebody actually made rather than
  easing between two ends. }
{ How a film joins back onto itself.

  flAsIs      play it through once, first frame to last.  What a clip that
              does not close wants when nobody minds the jump.
  flSeamless  the same, minus the last frame, because on a clip that closes
              the last pose IS the first pose and rendering both freezes the
              picture for one frame every time round.
  flBounce    forward and then backward, so whatever the clip did it ends
              where it began.  The way to loop a move that does not close -
              a rise, a push in, or anything pointed by hand.

  Bounce is the only one that changes what you see rather than only where the
  film is cut, so it is the one offered as a choice; the other two are
  decided by asking the clip whether it closes. }
type
  TFilmLoop = (flAsIs, flSeamless, flBounce);

{ Bounce turns a clip that does not close into one that does.  WantSeconds
  overrides how long the film runs - which is the speed of it, and need not
  be the speed it was recorded at; 0 keeps the recorded length. }
function SavePathGif(Doc: TWorkDoc; const Cam: TCamPath;
  SrcW, SrcH, W, H: Integer; U: TUnitSystem; AFont: TFont;
  const LabelCol: TPix; EdgeW: Single; Fps: Integer;
  Loop, Axes: Boolean; const Path: string;
  Bounce: Boolean = False; WantSeconds: Double = 0): Integer;

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

procedure Step(Done, Total: Integer; const What: string);
begin
  if Assigned(OnFilmStep) then OnFilmStep(Done, Total, What);
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

function CamPathCloses(const P: TCamPath): Boolean;
var
  A, B: TProjector;

  { an angle brought back into -Pi..Pi, so 2*Pi reads as nothing }
  function WrapPi(X: Double): Double;
  begin
    Result := X - 2 * Pi * Round(X / (2 * Pi));
  end;

begin
  Result := False;
  if Length(P) < 2 then Exit;
  A := P[0].V;
  B := P[High(P)].V;
  { The azimuth is compared the whole way round, because a turntable ends at
    Az + 2*Pi - a different number and the same direction, and the one walk
    most obviously meant to loop would otherwise be told it does not.

    A hundredth of a radian is a third of a degree, which at any size of
    picture is under a pixel of movement; the zoom within a thousandth. }
  Result := (Abs(WrapPi(A.Az - B.Az)) < 0.01) and (Abs(A.El - B.El) < 0.01) and
            (Abs(A.Ppu - B.Ppu) < 0.001 * Max(1E-9, Abs(A.Ppu))) and
            (Abs(A.OX - B.OX) < 1.0) and (Abs(A.OY - B.OY) < 1.0);
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

procedure HoldAt(var V: TProjector; const P: TP3; SX, SY: Double);
var
  Q: TPointF;
  X, Y: Double;
begin
  Q := Project(V, P);
  if IsNan(Q.X) or IsNan(Q.Y) then Exit;
  X := V.OX + (SX - Q.X);
  Y := V.OY + (SY - Q.Y);
  V.OX := X;
  V.OY := Y;
end;

function WalkAt(Kind: TWalk; const V0: TProjector; const C: TP3;
  FrameX, FrameY, T: Double): TProjector;
var
  Turn: Double;

  { in and out again, 0 at both ends and 1 in the middle }
  function Hump(U: Double): Double;
  begin
    Result := Sin(Max(0, Min(1, U)) * Pi);
  end;

begin
  Result := V0;
  T := Max(0, Min(1, T));
  case Kind of
    wkTurntable:
      Result.Az := V0.Az + 2 * Pi * T;

    wkRise:
      begin
        { one turn, climbing from just above the horizon to looking well
          down on it - a box shows you its sides and then its lid }
        Result.Az := V0.Az + 2 * Pi * T;
        Result.El := 0.18 + (1.15 - 0.18) * T;
      end;

    wkUnderOver:
      begin
        { starts below it looking up and climbs right over the top, with a
          quarter turn so it is not a flat sweep - the one for a part whose
          underside matters as much as its face }
        Result.Az := V0.Az + 0.5 * Pi * T;
        Result.El := -1.15 + (1.15 - -1.15) * T;
      end;

    wkNod:
      begin
        { no turn at all: straight down to straight up and back.  For
          something with a front, where turning it only hides the front. }
        Result.El := V0.El - 1.0 + 2.0 * Hump(T);
      end;

    wkHalfBack:
      begin
        { half a turn one way and back, which reads as somebody picking a
          thing up and looking at it rather than a machine spinning it }
        Turn := Hump(T);
        Result.Az := V0.Az + Pi * Turn;
        Result.El := V0.El + 0.35 * Turn;
      end;

    wkCorners:
      begin
        { from one corner low to the opposite corner high, going over the
          top on the way - a single sweep that shows three faces }
        Result.Az := V0.Az - Pi / 4 + (3 * Pi / 2) * T;
        Result.El := 0.15 + 1.05 * T;
      end;

    wkLookAll:
      begin
        { Tony's sketch: up, down, back to level, then round, and a dip at
          the far side.  Two turns of azimuth with the elevation doing its
          own thing over the top, so nothing repeats and every face comes
          past the camera at some point. }
        Result.Az := V0.Az + 2 * Pi * T;
        if T < 0.25 then
          Result.El := 0.45 + 0.85 * Hump(T / 0.25)        { over the top }
        else if T < 0.5 then
          Result.El := 0.45 - 1.20 * Hump((T - 0.25) / 0.25)  { and under }
        else
          Result.El := 0.45 + 0.55 * Hump((T - 0.5) / 0.5);   { level, then a lean }
      end;

    wkPushIn:
      begin
        { a slow close with a little drift, which is how somebody shows you a
          detail without you losing where it sits }
        Result.Az := V0.Az + 0.7 * Pi * T;
        Result.El := V0.El + 0.25 * T;
        Result.Ppu := V0.Ppu * Exp(Ln(2.4) * T);
      end;
  end;
  if Result.El < -1.45 then Result.El := -1.45;
  if Result.El > 1.45 then Result.El := 1.45;
  { and whatever the angles did, the thing being looked at stays put }
  HoldAt(Result, C, FrameX, FrameY);
end;

function ViewScale(SrcW, SrcH, W, H: Integer): Double;
begin
  Result := 1;
  if (SrcW <= 0) or (SrcH <= 0) or (W <= 0) or (H <= 0) then Exit;
  Result := Min(W / SrcW, H / SrcH);
  if Result < 1E-9 then Result := 1E-9;
end;

procedure ZoomAt(var V: TProjector; Factor, AX, AY: Double);
var
  P, X, Y: Double;
begin
  if Factor <= 0 then Exit;
  P := V.Ppu * Factor;
  if P < 1E-4 then P := 1E-4;
  if P > 1E6 then P := 1E6;
  { the factor that actually got applied, after the clamp }
  Factor := P / V.Ppu;
  X := AX - Factor * (AX - V.OX);
  Y := AY - Factor * (AY - V.OY);
  V.Ppu := P;
  V.OX := X;
  V.OY := Y;
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
  const Bg: TPix; Quick: Boolean; Axes: Boolean = False);
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
  { on the background, before the model goes over it }
  if Axes then PaintAxesOn(S, V);
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
  const Bg: TPix; Quick: Boolean; Axes: Boolean = False): TArtSurface;
begin
  Result := TArtSurface.Create(Max(1, W), Max(1, H));
  { a surface that did not come back the size it was asked for is a surface
    nothing downstream should be writing into }
  if (Result.Width < Max(1, W)) or (Result.Height < Max(1, H)) then
  begin
    Result.Free;
    raise Exception.CreateFmt('could not make a picture %d by %d', [W, H]);
  end;
  ShootInto(Result, Doc, V, U, AFont, LabelCol, EdgeW, Bg, Quick, Axes);
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
    EdgeW, Bg, False, Axes);
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

{ Every frame of a film, however the camera got there.  One place, because
  the only difference between a spin and a recording is where the view for
  frame N comes from. }
{ A film, as a GIF or as a WebP, decided by what it is being asked to
  write.

  The two formats differ only at the moment a frame is handed over.  A GIF
  is assembled whole in memory and squeezed to 256 colours at the end; a
  WebP frame is encoded as it is drawn - losslessly, which for flat fills
  and one pixel lines is both smaller and exact - and only the encoded
  bytes are kept, so the memory a film needs stops depending on how long it
  is.

  Lossless, and not offered as a choice.  We learned this the expensive way
  on the manual: WebP does both, and lossy is visibly grainy the moment
  anybody zooms in on a drawing, which is exactly what a drawing is for.
  Tony: "we probably want to export lossless webp!" }
function WriteFilm(Doc: TWorkDoc; SrcW, SrcH, W, H: Integer;
  U: TUnitSystem; AFont: TFont; const LabelCol: TPix; EdgeW: Single;
  Frames: Integer; Seconds: Double; Loop, Axes: Boolean; const Path: string;
  const ViewAt: TViewAt): Integer;
var
  I, Delay: Integer;
  S: TArtSurface;
  V: TProjector;
  Gif: TBGRAAnimatedGif;
  Web: TWebPAnimWriter;
  AsWebP: Boolean;
begin
  Result := Frames;
  { the wait between frames comes from the length and the count, so dropping
    the rate to fit the budget makes the film choppier and not shorter }
  Delay := Max(20, Round(Seconds * 1000 / Max(1, Frames)));
  Gif := nil;
  Web := nil;
  AsWebP := LowerCase(ExtractFileExt(Path)) = '.webp';
  { one surface for the whole film, drawn over and over }
  S := TArtSurface.Create(Max(1, W), Max(1, H));
  try
    if (S.Width < W) or (S.Height < H) then
      raise Exception.CreateFmt('could not make a picture %d by %d', [W, H]);
    if AsWebP then
      Web := TWebPAnimWriter.Create(W, H, True, 100, IfThen(Loop, 0, 1))
    else
    begin
      Gif := TBGRAAnimatedGif.Create;
      Gif.SetSize(W, H);
    end;
    for I := 0 to Frames - 1 do
    begin
      Say(Format('drawing frame %d of %d at %dx%d', [I + 1, Frames, W, H]));
      Step(I, Frames, Format('Drawing frame %d of %d', [I + 1, Frames]));
      V := Fitted(ViewAt(I, Frames), SrcW, SrcH, W, H);
      ShootInto(S, Doc, V, U, AFont, LabelCol, EdgeW, Pix(255, 255, 255),
        False, Axes);
      if AsWebP then
      begin
        { straight off the surface: TPix is B, G, R, A in that order, which
          is what the encoder reads, so there is no copy and no bitmap }
        Say(Format('encoding frame %d of %d', [I + 1, Frames]));
        if not Web.AddFrame(PByte(S.ScanLine(0)), Delay, S.Stride) then
          raise Exception.CreateFmt('frame %d would not encode', [I + 1]);
        Continue;
      end;
      { the gif takes ownership of each frame it is handed }
      Gif.AddFullFrame(ToBGRA(S), Delay, False, dmSetExceptTransparent, True);
    end;
    if AsWebP then
    begin
      Say(Format('writing %s', [ExtractFileName(Path)]));
      Step(Frames, Frames, 'Writing ' + ExtractFileName(Path) + '...');
      if not Web.SaveToFile(Path) then
        raise Exception.Create('the film would not write');
      Exit;
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
      Step(Frames, Frames, 'Packing the frames...');
      Gif.OptimizeFrames;
    end;
    Say(Format('writing %s', [ExtractFileName(Path)]));
    Step(Frames, Frames, 'Writing ' + ExtractFileName(Path) + '...');
    Gif.SaveToFile(Path);
  finally
    Web.Free;
    Gif.Free;
    S.Free;
  end;
end;

function SavePathGif(Doc: TWorkDoc; const Cam: TCamPath;
  SrcW, SrcH, W, H: Integer; U: TUnitSystem; AFont: TFont;
  const LabelCol: TPix; EdgeW: Single; Fps: Integer;
  Loop, Axes: Boolean; const Path: string;
  Bounce: Boolean = False; WantSeconds: Double = 0): Integer;
var
  Secs, Clip: Double;
  N, Rate: Integer;
  Rec: TCamPath;
  How: TFilmLoop;

  function At(I, Count: Integer): TProjector;
  var
    U01: Double;
  begin
    if Count < 2 then Exit(SampleCamPath(Rec, 0));
    case How of
      flBounce:
        begin
          { Out and back inside the one budget: the first half of the frames
            walk the clip forward and the second half walk it home.  The far
            end lands on one frame rather than two, and the film ends one
            step short of the start, so it joins up. }
          U01 := 2 * I / Count;
          if U01 > 1 then U01 := 2 - U01;
        end;
      flSeamless:
        { one step short of the end, because the end is the beginning }
        U01 := I / Count;
    else
      U01 := I / (Count - 1);
    end;
    Result := SampleCamPath(Rec, Clip * U01);
  end;

begin
  Rec := Cam;
  Clip := Max(0.2, CamPathLength(Cam));
  if WantSeconds > 0 then Secs := WantSeconds else Secs := Clip;
  Secs := Max(0.2, Min(GIF_MAX_SECONDS, Secs));

  if CamPathCloses(Cam) then How := flSeamless
  else if Bounce then How := flBounce
  else How := flAsIs;

  FilmPlan(Secs, Fps, W, H, N, Rate);
  Result := WriteFilm(Doc, SrcW, SrcH, W, H, U, AFont, LabelCol, EdgeW,
    N, Secs, Loop, Axes, Path, @At);
end;


initialization
  { A GIF holds 256 colours and a drawing does not, so something has to choose
    which 256.  BGRABitmap keeps that choice pluggable and ships the plug in a
    separate unit, and it is NOT enough to name that unit in the uses clause -
    the factory has to be handed over, which is what this line does.

    Without it, a frame of more than 256 colours reaches a nil quantizer and
    the writer faults.  That is why exporting a plain line drawing worked and
    exporting the same drawing with the axes on did not: white paper, grey
    faces and black lines fit inside 256 easily, and the moment three
    anti-aliased coloured axes are drawn over them they do not.  Tony's
    Windows crash on 13 September was this and nothing else - it was reported
    as "access violation while drawing the frames", and the frames were fine.

    Anything that writes a GIF wants this line to have run, so it lives here
    rather than at the call. }
  BGRAColorQuantizerFactory := TBGRAColorQuantizer;

end.
