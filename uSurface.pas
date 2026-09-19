unit uSurface;

{
  uSurface - a small software rasteriser for Heckers Sketch.

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
  Classes, SysUtils, Types, Math, StrUtils, FPImage, Graphics, GraphType,
  IntfGraphics;

type
  { one closed loop in screen coordinates - an outline, or something cut out
    of one }
  TPtFLoop = array of TPointF;

  { One screen triangle and the exact depth plane it lies in.

    A polygon of four or more corners need not be flat, and when it is not
    there is no plane to give it - see DepthMesh.  A triangle always has
    exactly one, so a face cut into triangles has an exact depth everywhere
    instead of a fitted one. }
  TDepthTri = record
    AX, AY, BX, BY, CX, CY: Single;
    ZA, ZB, ZC: Double;
    { the depths of its own three corners, low and high.  A triangle's depth
      can never be outside them, and the stretch it is given on a row is a
      pixel wider at each end than the triangle really is, so clamping to
      these is what makes that widening safe on a long thin one. }
    ZLo, ZHi: Double;
  end;
  TDepthTris = array of TDepthTri;

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
    { A tripwire, and a shield.

      Nine times in one session a surface was found carrying a stride that
      was not a stride but the bit pattern of a double around 0.14 - a zoom,
      by the look of it - while the bits pointer beside it was untouched.  An
      eight byte store landing on one field and not its neighbor is not a
      buffer running over; it is something writing through a pointer of the
      wrong type, and at this object's offset 40 sat FStride while at a
      TDrawing's offset 40 sits Zoom.

      So offset 40 is given to a field nothing reads.  If the writer is aiming
      at an offset, it now lands here and the next report says so by name
      instead of by wild pointer.  If FStride is hit anyway at its new home,
      the writer follows the field and the guess was wrong.  Either answer is
      worth more than the one we have. }
    FGuard: PtrInt;
    FStride: PtrInt;
    FBits: PByte;
    FMode: TBlendMode;
    FKeepAlpha: Boolean;
    { A depth for every pixel, so what is in front is decided per pixel
      instead of per shape.  Sorting shapes back to front works until two of
      them cannot be ordered - a wide flat panel and a small object beside it
      have no correct order at all - and then whichever is drawn last wins the
      whole overlap.  With a depth per pixel the question never arises. }
    FZ: array of Single;
    FZOn: Boolean;
    { Lines read the depth buffer but never write it.  A line is not a
      surface: it has no area to own, and letting one claim depth would have
      it hide the very face it was drawn on. }
    FZTest: Boolean;
    { The other way round, and dashed: draw only what the depth test
      REJECTS.  A hidden line in a drawing is dashed, not absent - see
      DepthBehind. }
    FZBehind: Boolean;
    FZa, FZb, FZc: Double;
    { the exact planes, when the one above is not good enough; consumed by
      the next FillLoops and then dropped }
    FZTris: TDepthTris;
    FZTriY0, FZTriY1: array of Integer;
    FDirty: TRect;
    procedure Allocate(AWidth, AHeight: Integer);
    procedure Verify;
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
    procedure RoundRect(const R: TRect; Radius: Single; const C: TPix; Alpha: Single = 1.0);
    procedure RoundRectV(const R: TRect; Radius: Single; const C1, C2: TPix; Alpha: Single = 1.0);
    procedure RoundFrame(const R: TRect; Radius, LineW: Single; const C: TPix; Alpha: Single = 1.0);
    procedure Disc(CX, CY, Radius: Single; const C: TPix; Alpha: Single = 1.0);
    procedure DiscV(CX, CY, Radius: Single; const C1, C2: TPix; Alpha: Single = 1.0);
    procedure Ring(CX, CY, Radius, LineW: Single; const C: TPix; Alpha: Single = 1.0);
    { A one pixel line, antialiased the cheap way - two pixels a step and no
      distance measured - for faint things drawn in bulk, like the ground
      grid.  Cut to the surface first, so a line that runs a long way off
      the edge costs only what is on it.  No depth test. }
    procedure HairLine(X0, Y0, X1, Y1: Single; const C: TPix; Alpha: Single);
    procedure Line(X0, Y0, X1, Y1, LineW: Single; const C: TPix; Alpha: Single = 1.0);
    procedure Arc(CX, CY, Radius, A0, A1, LineW: Single; const C: TPix; Alpha: Single = 1.0);
    procedure Poly(const Pts: array of TPointF; LineW: Single; const C: TPix;
      Closed: Boolean = False; Alpha: Single = 1.0);
    procedure Triangle(const P1, P2, P3: TPointF; const C: TPix; Alpha: Single = 1.0);
    procedure FillLoops(const Loops: array of TPtFLoop; const C: TPix;
      Alpha: Single);

    { Depth: start a pass, say what plane the next shape lies in, ask what
      depth a pixel ended up at.  Depth counts up towards the eye. }
  public
    { one coverage sample a row instead of four - the quick frame while the
      camera is moving; the full frame comes when it stops }
    QuickFill: Boolean;
  public
    procedure DepthBegin;
    procedure DepthPlane(A, B, C: Double);
    function DepthAt(X, Y: Integer): Single;
    function DepthOn: Boolean;
    procedure DepthTest(B: Boolean);
    { Draw the stretches the depth test throws away, instead of the ones it
      keeps, in a dash six pixels on and five off.

      What a drawing does with something it cannot see is dash it, not drop
      it: a beam over a doorway, a footing under a wall, a duct above a
      ceiling are all things a plan has to show and has to show as not
      visible.  Painting over them - which is what a camera does, and what
      this did - loses the information altogether.

      One flag and one pass: the depth buffer is already standing after the
      faces are down, so the hidden runs cost a second walk of the lines and
      nothing else.  Off again as soon as the pass is over. }
    procedure DepthBehind(B: Boolean);
    procedure DepthAlong(X0, Y0, Z0, X1, Y1, Z1: Double);
    { Give the NEXT FillLoops an exact depth per pixel, by handing it the
      shape already cut into triangles.

      DepthPlane says "this shape lies in this plane", which is the truth for
      a flat face and a guess for any other.  Plenty of faces are not flat: a
      revolve turns a sloped piece of an outline into a warped quad - four
      corners off a curved surface, which no plane passes through - and so
      does anything pushed out of one.  On the drawing that started this, 48
      of 336 faces were out of flat and the best plane that could be fitted
      to one of them was wrong by five hundred feet of depth on a model two
      hundred feet across.  That is the far side of a solid winning the depth
      test against the near side, and showing through it.

      A triangle cannot be anything but flat, so this removes the guess
      rather than improving it.  The fill itself is unchanged and still one
      call - filling triangle by triangle would leave a pale seam along every
      internal edge, each side of it contributing half a pixel of coverage -
      so this only supplies the depth.  A pixel no triangle claims falls back
      to whatever DepthPlane last said, which is the right answer for the
      slivers along the outside edge where this can happen.

      Set it for a face that needs it and not otherwise: a genuinely flat
      face keeps the single-plane path at no cost, and most faces are flat. }
    procedure DepthMesh(const Tris: TDepthTris);

    { --- whole-surface effects ------------------------------------------- }
    procedure ClearTransparent;
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
    property Stride: PtrInt read FStride;
    class function Repairs: Integer;
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
{ Near-black or near-white, whichever reads on this color. }
function OnPix(const C: TPix): TPix;
function ShadePix(const C: TPix; F: Single): TPix;
function HSVPix(H, S, V: Single): TPix;
function PtF(X, Y: Single): TPointF; inline;

{ Told whenever a surface finds its own buffer details changed under it, so
  the trail in a crash report can say which action was in progress when it
  happened.  Knowing that it happens is worth little; knowing that it always
  happens straight after a push, or a view change, is the whole answer. }
var
  OnSurfaceRepair: procedure(const What: string) = nil;

type
  { Told when a surface is about to be freed, so anybody holding a borrowed
    pointer to it can let go.  See WatchSurfaceGone. }
  TSurfaceGoneEvent = procedure(S: TArtSurface);

procedure WatchSurfaceGone(P: TSurfaceGoneEvent);

implementation

var
  { the watchers registered by WatchSurfaceGone, told when any surface is
    freed so a borrowed pointer to it can be let go }
  GGoneWatchers: array of TSurfaceGoneEvent;

const
  { An unlikely thing to be written by accident, and unmistakable in a report. }
  GUARD_WORD = PtrInt($5AFE5AFE5AFE5AFE);

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

{ Near-black or near-white, whichever can be read on this color.

  A theme puts text on its accent in half a dozen places - the lit row of a
  list, the tool in hand, the button you came for - and every one of them had
  the answer written into it as "dark, because the accents here are bright".
  Which is true of five themes and false of the light one, where the accent
  is a mid blue: dark text on it managed 4.2 to one and light gray text on it
  rather less.  So it is asked rather than assumed, once, here.

  The measure is the sRGB relative luminance the contrast standards use, and
  the threshold is where the two answers cross. }
function OnPix(const C: TPix): TPix;
var
  L: Single;

  function Chan(V: Byte): Single;
  var
    F: Single;
  begin
    F := V / 255;
    if F <= 0.03928 then Result := F / 12.92
    else Result := Power((F + 0.055) / 1.055, 2.4);
  end;

begin
  L := 0.2126 * Chan(C.R) + 0.7152 * Chan(C.G) + 0.0722 * Chan(C.B);
  if L > 0.183 then Result := Pix(22, 22, 26)
  else Result := Pix(246, 248, 252);
  Result.A := 255;
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
  FGuard := GUARD_WORD;
  Allocate(Max(1, AWidth), Max(1, AHeight));
end;

{ Anybody who kept a pointer to this surface without owning it is told
  before the memory goes.  See WatchSurfaceGone. }
destructor TArtSurface.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(GGoneWatchers) do
    if Assigned(GGoneWatchers[I]) then GGoneWatchers[I](Self);
  FBitmap.Free;
  FImage.Free;
  inherited Destroy;
end;

{ A surface is sometimes borrowed rather than owned: TWorkDoc keeps the last
  one it rendered into, because its depth buffer answers "is this point
  hidden" in one lookup instead of a walk over every face.  Borrowing is
  right - copying a depth buffer every frame would cost more than it saves -
  but a borrowed pointer outlives the thing it points at unless something
  says otherwise, and on 16 September something did not:

    From a note: "everything seemed to be going great until the exception happened
    after i exported the gif then click in the canvas i got the exception."

  The GIF export makes its own surface, renders every frame into it, and
  frees it.  The last of those renders left TWorkDoc.LastSurf pointing into
  freed memory, and the next question the canvas asked - a hover, a snap, the
  selection outline - read it.  EAccessViolation.

  So the surface tells its watchers on the way out rather than each of them
  remembering to clean up after every export, which is the arrangement that
  breaks the next time somebody adds a third exporter. }
procedure WatchSurfaceGone(P: TSurfaceGoneEvent);
begin
  SetLength(GGoneWatchers, Length(GGoneWatchers) + 1);
  GGoneWatchers[High(GGoneWatchers)] := P;
end;

var
  GRepairs: Integer = 0;

{ A corrupt stride has twice now turned out to be a floating point number
  wearing an integer's clothes, so the report says what it would be as one.
  A value that reads as a plausible zoom or coordinate names the culprit; one
  that reads as nonsense says to look elsewhere. }
function AsDouble(V: PtrInt): string;
var
  D: Double;
begin
  Move(V, D, SizeOf(D));
  if IsNan(D) or IsInfinite(D) then Exit('not a number');
  Result := Format('as a double %.6g', [D]);
end;

class function TArtSurface.Repairs: Integer;
begin
  Result := GRepairs;
end;

{ Take the buffer and its stride from the image again, rather than from what
  we wrote down when it was made.

  Both are written once, in Allocate, and nothing here ever touches them
  again - so finding one of them changed means something outside this object
  wrote through it, and a report from the machine says exactly that: three
  surfaces carrying a stride of 7440, and the fourth carrying the bit pattern
  of the drawing's zoom.  A stride is what turns a row number into an
  address, so a wrong one is not a wrong picture, it is a wild pointer, and
  the crash lands in whichever loop touches it first.

  Asking the image again costs two calls per composite and cannot be wrong,
  because the image is where the memory actually is.  The count of how often
  the answer differed goes into the crash report: nought means this is not
  happening and the theory is wrong, anything else says how bad it is. }
procedure TArtSurface.Verify;
var
  P: PByte;
  St: PtrInt;
begin
  if (FWidth <= 0) or (FHeight <= 0) then Exit;
  P := PByte(FImage.GetDataLineStart(0));
  if P = nil then Exit;
  if FHeight > 1 then
    St := PByte(FImage.GetDataLineStart(1)) - P
  else
    St := FWidth * 4;
  if St < FWidth * 4 then Exit;      { the image is talking nonsense too }
  if FGuard <> GUARD_WORD then
  begin
    Inc(GRepairs);
    if Assigned(OnSurfaceRepair) then
      OnSurfaceRepair(Format('surface guard hit: %d (%s), stride %s',
        [FGuard, AsDouble(FGuard),
         specialize IfThen<string>(St = FStride, 'untouched', 'also wrong')]));
    FGuard := GUARD_WORD;
  end;
  if (P <> FBits) or (St <> FStride) then
  begin
    Inc(GRepairs);
    if Assigned(OnSurfaceRepair) then
      OnSurfaceRepair(Format('surface repaired: stride %d (%s) -> %d, bits %s',
        [FStride, AsDouble(FStride), St,
         specialize IfThen<string>(P = FBits, 'same', 'moved')]));
    FBits := P;
    FStride := St;
  end;
end;

procedure TArtSurface.Allocate(AWidth, AHeight: Integer);
var
  Desc: TRawImageDescription;
  RI: TRawImage;
  Room: PtrUInt;
  St: PtrInt;
begin
  { Zeroed before it is filled in.  It is a record on the stack, the image
    decides whether to reallocate by comparing it byte for byte against the
    one it holds, and a comparison that includes whatever the stack happened
    to contain is not a comparison. }
  FillChar(Desc, SizeOf(Desc), 0);
  Desc.Init_BPP32_B8G8R8A8_BIO_TTB(AWidth, AHeight);
  FImage.DataDescription := Desc;
  FBits := PByte(FImage.GetDataLineStart(0));
  { Width and height are set from what came back, not from what was asked
    for, and they are set after the asking rather than before it.

    Everything downstream decides what is safe to touch by reading FWidth and
    FHeight - the compositor, the blitter, every clip in this unit.  Setting
    them first meant that if the image ever declined to hand over the memory,
    the surface went on reporting a size it could not back, every guard built
    on that size agreed, and the first loop to walk a row ran off the end.
    A surface with nothing behind it now says it is one pixel, which is true
    and which everything above copes with. }
  if FBits = nil then
  begin
    FWidth := 0;
    FHeight := 0;
    FStride := 0;
    FBitmapValid := False;
    ResetDirty;
    Exit;
  end;
  { The distance between two rows, measured rather than assumed, because a
    backing store is free to pad them.

    Measured is not the same as believed.  The subtraction is between two
    pointers the widget set handed over, and if the second one is not really
    a row start yet - the backing not built, the image not realized - the
    difference is not a stride, it is the gap between two unrelated addresses,
    and one report came back carrying a stride of four and a half quintillion.
    Everything downstream indexes rows by it.

    So it has to be a number a stride could be: at least a row wide, and not
    so far past one that it is obviously not padding.  Anything else and the
    packed width is used, which is what the surface would have had if nobody
    had asked.  Verify still stands behind this and still repairs a surface
    that drifts later; this stops it being wrong to begin with. }
  FStride := AWidth * 4;
  if AHeight > 1 then
  begin
    St := PByte(FImage.GetDataLineStart(1)) - FBits;
    if (St >= AWidth * 4) and (St <= PtrInt(AWidth) * 4 + 4096) then
      FStride := St;
  end;

  { How many rows there is really room for.

    Width and height are what every clip in this unit is written in terms of
    - the compositor, the blitter, ScanLine itself - so they had better be
    backed by memory that exists.  Up to now they were whatever was asked
    for, on the understanding that asking is the same as getting.  It is not:
    the image can decline, or hand back less than the description says, and
    nothing here would have known.  A surface that reports more rows than it
    owns is a surface where the guards agree with each other all the way down
    and the last row still walks off the end.

    So the height is trimmed to what the buffer can hold.  A slightly short
    surface draws a slightly short picture, which nobody will notice; the
    alternative is an access violation on a machine we cannot get at. }
  Room := 0;
  try
    FImage.GetRawImage(RI, False);
    Room := RI.DataSize;
  except
    Room := 0;
  end;
  if (Room > 0) and (FStride > 0) and
     (Room div PtrUInt(FStride) < PtrUInt(AHeight)) then
    AHeight := Integer(Room div PtrUInt(FStride));
  if AHeight < 1 then
  begin
    FWidth := 0;
    FHeight := 0;
    FStride := 0;
    FBitmapValid := False;
    ResetDirty;
    Exit;
  end;

  FWidth := AWidth;
  FHeight := AHeight;
  { the allocation is not zeroed, and anything that only partly covers the
    surface afterwards would otherwise show whatever was in that memory }
  FillChar(FBits^, PtrUInt(FStride) * PtrUInt(AHeight), 0);
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

{ Verify puts a drifted stride right, but only when it is called, and every
  pixel in between is addressed with whatever the field holds.  One bad value
  is all it takes, so the arithmetic that turns a row into an address refuses
  a stride that could not be one.  Falling back to the packed width draws a
  sheared picture; following four and a half quintillion writes into whatever
  is there. }
function TArtSurface.ScanLine(Y: Integer): PPix;
var
  St: PtrInt;
begin
  St := FStride;
  if (St < FWidth * 4) or (St > PtrInt(FWidth) * 4 + 4096) then
    St := PtrInt(FWidth) * 4;
  Result := PPix(FBits + St * Y);
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
  if (Base = nil) or (Ink = nil) then Exit;
  Verify;
  Base.Verify;
  Ink.Verify;
  { Clipped to all three, not only to where it is being written.

    It used to trust that the paper and the ink were the same size as the
    picture they compose into, which they are whenever they were sized
    together - and being right whenever nothing has gone wrong is not the
    same as being right.  One surface a row shorter than the other two and
    this walks off the end of it, which is an access violation on the last
    row of every frame rather than something that shows up once. }
  Cl := Rect(Max(0, R.Left), Max(0, R.Top),
             Min(FWidth,  Min(Base.Width,  Ink.Width)),
             Min(FHeight, Min(Base.Height, Ink.Height)));
  if R.Right < Cl.Right then Cl.Right := R.Right;
  if R.Bottom < Cl.Bottom then Cl.Bottom := R.Bottom;
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
  Y, Pad, Band: Integer;
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
{ Xiaolin Wu's line.  The ends are cut to the surface (Liang and Barsky)
  before anything is walked, then the long axis is stepped a pixel at a time
  and the two pixels either side of the line share its coverage. }
procedure TArtSurface.HairLine(X0, Y0, X1, Y1: Single; const C: TPix; Alpha: Single);
var
  T0, T1, DX, DY, Grad, Inter, F: Double;
  Steep: Boolean;
  I, IA, IB, Y: Integer;
  Tmp: Double;

  function Clip(P, Q: Double): Boolean;
  var
    R: Double;
  begin
    Result := True;
    if Abs(P) < 1E-12 then
    begin
      if Q < 0 then Result := False;
      Exit;
    end;
    R := Q / P;
    if P < 0 then
    begin
      if R > T1 then Result := False
      else if R > T0 then T0 := R;
    end
    else
    begin
      if R < T0 then Result := False
      else if R < T1 then T1 := R;
    end;
  end;

  procedure Plot(A, B: Integer; Cover: Double);
  begin
    if Steep then BlendPixel(B, A, C, Cover * Alpha)
    else BlendPixel(A, B, C, Cover * Alpha);
  end;

begin
  if (FWidth <= 0) or (FHeight <= 0) or not (Alpha > 0) then Exit;
  if IsNan(X0) or IsNan(Y0) or IsNan(X1) or IsNan(Y1) then Exit;
  DX := X1 - X0;
  DY := Y1 - Y0;
  T0 := 0;
  T1 := 1;
  { a pixel of margin all round, so a line along the very edge still lands }
  if not Clip(-DX, X0 + 1) then Exit;
  if not Clip(DX, FWidth - X0) then Exit;
  if not Clip(-DY, Y0 + 1) then Exit;
  if not Clip(DY, FHeight - Y0) then Exit;
  if T1 < T0 then Exit;
  X1 := X0 + DX * T1;  Y1 := Y0 + DY * T1;
  X0 := X0 + DX * T0;  Y0 := Y0 + DY * T0;

  Steep := Abs(Y1 - Y0) > Abs(X1 - X0);
  if Steep then
  begin
    Tmp := X0; X0 := Y0; Y0 := Tmp;
    Tmp := X1; X1 := Y1; Y1 := Tmp;
  end;
  if X0 > X1 then
  begin
    Tmp := X0; X0 := X1; X1 := Tmp;
    Tmp := Y0; Y0 := Y1; Y1 := Tmp;
  end;
  DX := X1 - X0;
  DY := Y1 - Y0;
  if DX < 1E-9 then Grad := 0 else Grad := DY / DX;

  { pixel centers sit at .5; step every whole column the line spans }
  IA := Round(X0);
  IB := Round(X1);
  Inter := Y0 + Grad * (IA + 0.5 - X0) - 0.5;
  for I := IA to IB do
  begin
    Y := Floor(Inter);
    F := Inter - Y;
    Plot(I, Y, 1 - F);
    Plot(I, Y + 1, F);
    Inter := Inter + Grad;
  end;
  Invalidate;
end;

procedure TArtSurface.Line(X0, Y0, X1, Y1, LineW: Single; const C: TPix; Alpha: Single);
var
  X, Y, IX0, IY0, IX1, IY1, RX0, RX1: Integer;
  HW, Pad, DY, Lo, Hi, XA, XB, T, Len, DX, DYc: Single;
begin
  HW := Max(LineW, 0.35) / 2;
  { A line is a capsule: a round cap reaches half the width past each end.
    On a one pixel edge that is nothing; on a two pixel profile it is a
    pixel past every corner, and at the mouth of a tunnel those pixels
    poke out onto the wall - the corner bleed.  So a line wider than a
    pixel and a half is pulled in by half its width at each end, and the
    cap then ends exactly on the point.  Two lines meeting at a corner keep
    it covered between them, gently rounded rather than notched. }
  if LineW > 1.5 then
  begin
    Len := Sqrt(Sqr(X1 - X0) + Sqr(Y1 - Y0));
    if Len > 2 * HW + 0.5 then
    begin
      DX := (X1 - X0) / Len * HW;
      DYc := (Y1 - Y0) / Len * HW;
      X0 := X0 + DX; Y0 := Y0 + DYc;
      X1 := X1 - DX; Y1 := Y1 - DYc;
    end;
  end;
  { How far round the line a pixel can be and still be touched: coverage
    ends half a pixel past the edge, and a pixel's center is half a pixel
    from its corner.  It was three pixels, which on a one pixel line walked
    and measured three times as many pixels as could ever be lit - the ground
    grid in the 3D view was most of every orbiting frame on the machine,
    17 September, and almost all of that was pixels coming out blank. }
  Pad := HW + 1;
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
    if FZOn and FZTest and FZBehind then
      for X := RX0 to RX1 do
      begin
        { the hidden half: only what is behind, and only every other few
          pixels.  The dash is measured along the line rather than in X, so
          it comes out the same length whichever way the line runs. }
        if FZa * X + FZb * Y + FZc >= FZ[Y * FWidth + X] - 1E-4 then Continue;
        { Manhattan, not Pythagoras - a square root per pixel for a dash
          pattern is a square root nobody asked for.  Measured, it was worth
          nothing much either way; the whole pass is 2.5 ms of a 37 ms plan
          on the barn, and the faces are 17 of it.  Kept because the two
          measures differ by at most root two, which on a dash nobody can
          see and nobody is measuring, so the cheaper one is free. }
        if ((Round(Abs(X - X0) + Abs(Y - Y0))) mod 13) >= 7 then Continue;
        BlendPixel(X, Y, C,
          Coverage(SdSegment(X + 0.5, Y + 0.5, X0, Y0, X1, Y1) - HW) * Alpha);
      end
    else if FZOn and FZTest then
      for X := RX0 to RX1 do
      begin
        { behind a face that is already down, so this stretch is not seen.
          The slack is a hair wider than the one the fill uses: a line drawn
          on a face works out to the same depth by a different route, and
          rounding must not be allowed to bury it. }
        if FZa * X + FZb * Y + FZc < FZ[Y * FWidth + X] - 1E-4 then Continue;
        BlendPixel(X, Y, C,
          Coverage(SdSegment(X + 0.5, Y + 0.5, X0, Y0, X1, Y1) - HW) * Alpha);
      end
    else
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
procedure TArtSurface.DepthBegin;
var
  I: Integer;
begin
  if (FWidth <= 0) or (FHeight <= 0) then Exit;
  if Length(FZ) <> FWidth * FHeight then SetLength(FZ, FWidth * FHeight);
  for I := 0 to High(FZ) do FZ[I] := -1E30;
  FZOn := True;
  FZTest := False;
  FZBehind := False;
  FZa := 0; FZb := 0; FZc := -1E30;
end;


function TArtSurface.DepthOn: Boolean;
begin
  Result := FZOn;
end;

procedure TArtSurface.DepthTest(B: Boolean);
begin
  FZTest := B;
end;

procedure TArtSurface.DepthBehind(B: Boolean);
begin
  FZBehind := B;
end;

{ The depth of a line, as the same flat function of screen position that a
  face gets.  A parallel projection makes depth linear along the segment, so
  one plane fits it exactly: the gradient runs along the line, and there is
  no slope across it - which is what keeps a line lying on a face at the
  face's own depth rather than tilting through it. }
procedure TArtSurface.DepthAlong(X0, Y0, Z0, X1, Y1, Z1: Double);
var
  DX, DY, L2: Double;
begin
  DX := X1 - X0;
  DY := Y1 - Y0;
  L2 := DX * DX + DY * DY;
  if L2 < 1E-12 then
  begin
    FZa := 0;
    FZb := 0;
    FZc := Z0;
    Exit;
  end;
  FZa := (Z1 - Z0) * DX / L2;
  FZb := (Z1 - Z0) * DY / L2;
  FZc := Z0 - FZa * X0 - FZb * Y0;
end;

procedure TArtSurface.DepthMesh(const Tris: TDepthTris);
var
  I: Integer;
  Lo, Hi: Single;
begin
  FZTris := Tris;
  SetLength(FZTriY0, Length(Tris));
  SetLength(FZTriY1, Length(Tris));
  { the rows each triangle can possibly touch, worked out once, so the row
    loop can pass over the ones it cannot with two integer compares }
  for I := 0 to High(Tris) do
  begin
    Lo := Min(Tris[I].AY, Min(Tris[I].BY, Tris[I].CY));
    Hi := Max(Tris[I].AY, Max(Tris[I].BY, Tris[I].CY));
    FZTriY0[I] := Floor(Lo) - 1;
    FZTriY1[I] := Ceil(Hi) + 1;
  end;
end;

procedure TArtSurface.DepthPlane(A, B, C: Double);
begin
  { a new plane means a new shape, and any triangles standing from the last
    one belonged to that one.  Without this, a caller that set a mesh and
    then did not fill would hand it to whatever got filled next. }
  FZTris := nil;
  FZTriY0 := nil;
  FZTriY1 := nil;
  FZa := A;
  FZb := B;
  FZc := C;
end;

function TArtSurface.DepthAt(X, Y: Integer): Single;
begin
  Result := -1E30;
  if Length(FZ) <> FWidth * FHeight then Exit;
  if (X < 0) or (Y < 0) or (X >= FWidth) or (Y >= FHeight) then Exit;
  Result := FZ[Y * FWidth + X];
end;

{ One shape, however many loops it takes to say what it is.

  The outline and anything cut out of it go in together and the crossings are
  counted the same way for all of them, so a hole is not a special case in
  here: the scanline already fills between alternate crossings, which is the
  even-odd rule, and an inner loop simply contributes two more crossings that
  turn the fill off and on again.  A window in a wall costs nothing that a
  wall did not already cost. }
procedure TArtSurface.FillLoops(const Loops: array of TPtFLoop; const C: TPix;
  Alpha: Single);
const
  SAMPLES = 4;
var
  N, I, J, Y, X, K, L, Cnt, X0, X1, Y0, Y1, Total: Integer;
  MinX, MaxX, MinY, MaxY, SY, XA, XB: Single;
  Xs: array of Single;
  Cov: array of Single;
  T: Single;
  Z: Double;
  Any: Boolean;
  Smp: Integer;
  { the exact depth for this row, where DepthMesh supplied triangles }
  Mesh: TDepthTris;
  MeshY0, MeshY1: array of Integer;
  { The edges of every loop, flattened, so a row does not have to walk the
    whole outline to find the two or three edges that actually cross it.

    This was most of the ink pass.  A face with rounded corners is eighty
    edges and a hole is thirty more; the row loop asked all of them, four
    times a row, for every row of the face's box.  On the drawing the owner sent
    at 23:19 - an etch-a-sketch toy, 409 faces - that came to eleven
    milliseconds a frame, half of it in here.  At any one row a closed
    outline is crossed by a handful of edges and no more. }
  EAX, EAY, EBX, EBY, ELo, EHi: array of Single;
  EOrder, EAct: array of Integer;
  NE, NAct, NextE, AI, AJ: Integer;
  { The stretch of the coverage row that was actually written last time.

    Clearing the whole row every row costs what a polygon's bounding box
    costs rather than what the polygon costs, and for a long thin one lying
    on the diagonal - which is every facet of a pipe - those are nothing
    like each other.  A two-inch spool was spending sixty-four milliseconds
    a frame painting a thousand faces, most of it zeroing entries no
    crossing ever reached. }
  ClrLo, ClrHi, CurLo, CurHi: Integer;
  { and the same for the depth triangles, which were walked whole for every
    row as well }
  RowZ: array of Double;
  RowHas: array of Boolean;
  TI, TC, TXLo, TXHi: Integer;
  TxA, TxB: Single;

  { grow the stretch of the row to take in one more x }
  procedure Take(V: Single; var N: Integer; var Lo, Hi: Single); inline;
  begin
    if N = 0 then begin Lo := V; Hi := V; end
    else begin if V < Lo then Lo := V; if V > Hi then Hi := V; end;
    Inc(N);
  end;

  { a corner of the triangle, if it falls inside the row's band }
  procedure Span(VX, VY: Single; Row: Integer; var N: Integer;
    var Lo, Hi: Single); inline;
  begin
    if (VY >= Row) and (VY <= Row + 1) then Take(VX, N, Lo, Hi);
  end;

  { where an edge of it crosses the top or the bottom of the band }
  procedure Cross(X1s, Y1s, X2s, Y2s: Single; Row: Integer; var N: Integer;
    var Lo, Hi: Single);
  var
    B: Integer;
    YB: Single;
  begin
    if Y1s = Y2s then Exit;
    for B := 0 to 1 do
    begin
      YB := Row + B;
      if (Y1s <= YB) = (Y2s <= YB) then Continue;
      Take(X1s + (X2s - X1s) * (YB - Y1s) / (Y2s - Y1s), N, Lo, Hi);
    end;
  end;

begin
  { take the mesh at the door: it is for this call and no other, and every
    way out of here has to leave it cleared }
  Mesh := FZTris;
  MeshY0 := FZTriY0;
  MeshY1 := FZTriY1;
  FZTris := nil;
  FZTriY0 := nil;
  FZTriY1 := nil;
  if not FZOn then Mesh := nil;
  if QuickFill then Smp := 1 else Smp := SAMPLES;
  Any := False;
  Total := 0;
  MinY := 0; MaxY := 0; MinX := 0; MaxX := 0;
  for L := 0 to High(Loops) do
  begin
    N := Length(Loops[L]);
    if N < 3 then Continue;
    Inc(Total, N);
    for I := 0 to N - 1 do
    begin
      if not Any then
      begin
        MinY := Loops[L][I].Y; MaxY := MinY;
        MinX := Loops[L][I].X; MaxX := MinX;
        Any := True;
      end
      else
      begin
        MinY := Min(MinY, Loops[L][I].Y);
        MaxY := Max(MaxY, Loops[L][I].Y);
        MinX := Min(MinX, Loops[L][I].X);
        MaxX := Max(MaxX, Loops[L][I].X);
      end;
    end;
  end;
  if not Any then Exit;

  Y0 := LoBound(MinY, FHeight);
  Y1 := HiBound(MaxY, FHeight);
  X0 := LoBound(MinX - 1, FWidth);
  X1 := HiBound(MaxX + 1, FWidth);
  if (Y1 < Y0) or (X1 < X0) then Exit;

  SetLength(Xs, Total + 2);
  SetLength(Cov, X1 - X0 + 2);

  { --- the edges, once ------------------------------------------------
        A level edge is left out: the crossing test can never fire on one,
        because both its ends answer the same side of any sample row. }
  SetLength(EAX, Total); SetLength(EAY, Total);
  SetLength(EBX, Total); SetLength(EBY, Total);
  SetLength(ELo, Total); SetLength(EHi, Total);
  SetLength(EOrder, Total); SetLength(EAct, Total);
  NE := 0;
  for L := 0 to High(Loops) do
  begin
    N := Length(Loops[L]);
    if N < 3 then Continue;
    for I := 0 to N - 1 do
    begin
      J := (I + 1) mod N;
      if Loops[L][I].Y = Loops[L][J].Y then Continue;
      EAX[NE] := Loops[L][I].X; EAY[NE] := Loops[L][I].Y;
      EBX[NE] := Loops[L][J].X; EBY[NE] := Loops[L][J].Y;
      if EAY[NE] < EBY[NE] then
      begin ELo[NE] := EAY[NE]; EHi[NE] := EBY[NE]; end
      else
      begin ELo[NE] := EBY[NE]; EHi[NE] := EAY[NE]; end;
      EOrder[NE] := NE;
      Inc(NE);
    end;
  end;
  if NE = 0 then Exit;
  { in the order they start down the screen, so the row loop can take them
    in as it reaches them - insertion sort, because a face is tens of edges
    and it is already nearly sorted by the way an outline is written }
  for I := 1 to NE - 1 do
  begin
    AI := EOrder[I];
    J := I - 1;
    while (J >= 0) and (ELo[EOrder[J]] > ELo[AI]) do
    begin
      EOrder[J + 1] := EOrder[J];
      Dec(J);
    end;
    EOrder[J + 1] := AI;
  end;
  NAct := 0;
  NextE := 0;
  if Length(Mesh) > 0 then
  begin
    SetLength(RowZ, X1 - X0 + 2);
    SetLength(RowHas, X1 - X0 + 2);
  end;

  ClrLo := 0;
  ClrHi := High(Cov);
  for Y := Y0 to Y1 do
  begin
    for X := ClrLo to ClrHi do
      Cov[X] := 0;
    CurLo := High(Cov) + 1;
    CurHi := -1;

    { --- which edges this row can possibly be crossed by ---------------
          The samples sit inside (Y, Y + 1), so an edge matters here when it
          reaches into that band.  Taken in as the rows come down to them,
          dropped once the rows have passed them, and the bounds are kept
          generous by a whole row either way: a handful of edges that cannot
          fire costs nothing, and one wrongly dropped is a hole in a face. }
    while (NextE < NE) and (ELo[EOrder[NextE]] <= Y + 1) do
    begin
      EAct[NAct] := EOrder[NextE];
      Inc(NAct);
      Inc(NextE);
    end;
    AJ := 0;
    for AI := 0 to NAct - 1 do
      if EHi[EAct[AI]] >= Y then
      begin
        EAct[AJ] := EAct[AI];
        Inc(AJ);
      end;
    NAct := AJ;
    if NAct = 0 then Continue;

    { --- the exact depth along this row, one triangle at a time --------
          Each triangle is clipped to the band of the row - not to the line
          down the middle of it, which was the first thing tried and which
          drops any triangle lying inside the row without straddling that
          line.  Ear clipping makes plenty of triangles that thin, and every
          one of them left its pixels on the fitted plane it was supposed to
          be replacing.

          Clipping to the band is also what makes widening the stretch
          unnecessary: rounding each end out to a whole pixel already covers
          the row, and the triangles tile the face, so consecutive stretches
          butt up with nothing between them.  Widening them by a pixel
          anyway - which was tried - is not free insurance: it lets a
          triangle write depth a pixel outside itself and quadrupled what
          was left wrong, from 28 pixels to 104 on the drawing this was
          built for.

          The depth written is still clamped to the triangle's own three
          corner depths, because a triangle's depth cannot be outside them
          and a long thin one has a steep enough plane to go a long way out
          on half a pixel of rounding.  Without the clamp the worst pixel on
          that same drawing is out by 307 feet instead of 69. }
    if Length(Mesh) > 0 then
    begin
      for X := 0 to High(RowHas) do
        RowHas[X] := False;
      for TI := 0 to High(Mesh) do
      begin
        if (Y < MeshY0[TI]) or (Y > MeshY1[TI]) then Continue;
        TC := 0;
        TxA := 0; TxB := 0;
        { corners of it that are in the band }
        Span(Mesh[TI].AX, Mesh[TI].AY, Y, TC, TxA, TxB);
        Span(Mesh[TI].BX, Mesh[TI].BY, Y, TC, TxA, TxB);
        Span(Mesh[TI].CX, Mesh[TI].CY, Y, TC, TxA, TxB);
        { and where its edges cross the top and the bottom of the band }
        Cross(Mesh[TI].AX, Mesh[TI].AY, Mesh[TI].BX, Mesh[TI].BY, Y, TC, TxA, TxB);
        Cross(Mesh[TI].BX, Mesh[TI].BY, Mesh[TI].CX, Mesh[TI].CY, Y, TC, TxA, TxB);
        Cross(Mesh[TI].CX, Mesh[TI].CY, Mesh[TI].AX, Mesh[TI].AY, Y, TC, TxA, TxB);
        if TC = 0 then Continue;
        TXLo := Max(X0, Floor(TxA));
        TXHi := Min(X1, Ceil(TxB));
        for X := TXLo to TXHi do
        begin
          RowZ[X - X0] := Min(Mesh[TI].ZHi, Max(Mesh[TI].ZLo,
            Mesh[TI].ZA * X + Mesh[TI].ZB * Y + Mesh[TI].ZC));
          RowHas[X - X0] := True;
        end;
      end;
    end;

    for K := 0 to Smp - 1 do
    begin
      SY := Y + (K + 0.5) / Smp;
      Cnt := 0;
      for AI := 0 to NAct - 1 do
      begin
        J := EAct[AI];
        if (EAY[J] <= SY) = (EBY[J] <= SY) then Continue;
        T := (SY - EAY[J]) / (EBY[J] - EAY[J]);
        Xs[Cnt] := EAX[J] + (EBX[J] - EAX[J]) * T;
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
          begin
            Cov[X - X0] := Cov[X - X0] + T / Smp;
            if X - X0 < CurLo then CurLo := X - X0;
            if X - X0 > CurHi then CurHi := X - X0;
          end;
        end;
      end;
    end;

    ClrLo := CurLo;
    ClrHi := CurHi;
    for X := Max(X0, X0 + CurLo) to Min(X1, X0 + CurHi) do
      if Cov[X - X0] > 0.002 then
      begin
        if FZOn then
        begin
          if (Length(Mesh) > 0) and RowHas[X - X0] then
            Z := RowZ[X - X0]
          else
            Z := FZa * X + FZb * Y + FZc;
          { behind what is already there, so it does not get drawn }
          if Z < FZ[Y * FWidth + X] - 1E-6 then Continue;
          { and only a pixel the shape genuinely covers claims the depth - a
            sliver along an edge would otherwise write a depth for ground it
            barely touches }
          if Cov[X - X0] > 0.5 then FZ[Y * FWidth + X] := Z;
        end;
        BlendPixel(X, Y, C, Cov[X - X0] * Alpha);
      end;
  end;
  Invalidate;
end;



{ Sprinkle bright/dark specks - the aluminum powder look while erasing. }
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
  Verify;
  Src.Verify;
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
    { a row at a time - this copies a whole window of paper every frame }
    Move(S^, D^, (X1 - X0) * SizeOf(TPix));
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
    { Ask the image where its pixels are again, rather than trusting the
      answer it gave before it was handed to the widgetset.

      Nothing in the declarations says the buffer can move here - the raw
      image goes in as const, and on this machine it does not move.  But this
      is the one moment in the life of a surface when something outside this
      unit has it, the only crash left standing is one that never happens on
      this machine, and the cost of asking again is one call per repaint. }
    FBits := PByte(FImage.GetDataLineStart(0));
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
