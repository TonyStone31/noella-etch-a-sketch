unit uWebPAnim;

{ Writing an ANIMATED WebP, which is the one piece nobody had.

  Xelitan's encoder in WebPEnc.pas does the hard half - VP8L, a real lossless
  encoder ported from libwebp, in Pascal and with no DLL behind it.  What it
  makes is one still picture.  Its animation units go the other way: they
  read and play, they do not write.

  So this is the other half, and it is much the smaller one, because an
  animated WebP is not a different encoding - it is the same still frames in
  a different envelope:

      RIFF .... WEBP
        VP8X    what the canvas is, and that this is an animation
        ANIM    the background colour and how many times to loop
        ANMF    a frame: where, how big, how long, how to blend
          VP8L    ...the still picture, exactly as WebPEnc made it
        ANMF    the next frame
          VP8L
        ...

  Every number is little-endian.  Three of them are stored one less than they
  are - canvas width, canvas height, frame width, frame height - because zero
  is not a useful size and the format would rather have the extra value.  Two
  of them, the frame's x and y, are counted in PAIRS of pixels, which is why
  a frame can only be placed on an even column.  Ours are all full-canvas at
  0,0, so that costs us nothing.

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE.
  WebPEnc.pas beside this is Xelitan's, MIT - see LICENSE-Xelitan.txt. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, WebPEnc;

type
  { One frame: the picture, and how long it stays up. }
  TWebPFrame = record
    BGRA: PByte;        { Width * Height * 4, top-down }
    Millis: Integer;
  end;

type
  { A film written a frame at a time.

    The whole-array call below wants every frame in memory at once, and a
    frame is four bytes a pixel: a minute of 1920 x 1080 is eight gigabytes,
    which is not a thing to ask of a laptop for a file that will come back
    under ten megabytes.

    So this takes them one at a time and keeps only what the file will hold
    - each frame ENCODED, which is the compressed VP8L chunk and a hundredth
    of the size.  The most it ever holds is the finished file. }
  TWebPAnimWriter = class
  private
    FW, FH, FLoop: Integer;
    FLossless: Boolean;
    FQuality: Single;
    FFrames: TMemoryStream;   { the ANMF chunks, one after another }
    FCount: Integer;
  public
    constructor Create(AWidth, AHeight: Integer; ALossless: Boolean = True;
      AQuality: Single = 92; ALoop: Integer = 0);
    destructor Destroy; override;
    { One frame, top-down BGRA.  Stride is the bytes from one row to the
      next, which is Width * 4 unless the surface it came from pads its
      rows; 0 means that default.  The frame is encoded here and the pixels
      are not kept, so the caller may draw over them at once. }
    function AddFrame(BGRA: PByte; Millis: Integer; Stride: Integer = 0): Boolean;
    { The container round everything added so far. }
    function SaveToFile(const Path: string): Boolean;
    property Count: Integer read FCount;
  end;

{ Write the frames as one animated WebP.  Lossless unless Quality is given a
  value of 0..100, which switches to lossy at that quality - the same choice
  the recorder makes, for the same reason.  Loops forever when Loop is 0.

  Convenient when the frames are already in hand; a long film should use
  TWebPAnimWriter above and hand them over one at a time. }
function SaveWebPAnimation(const Frames: array of TWebPFrame;
  Width, Height: Integer; const Path: string;
  Lossless: Boolean = True; Quality: Single = 92;
  Loop: Integer = 0): Boolean;

implementation

{ --- the little-endian writers the format is made of ------------------- }

procedure PutU16(S: TStream; V: Integer);
var
  B: array[0..1] of Byte;
begin
  B[0] := V and $FF; B[1] := (V shr 8) and $FF;
  S.WriteBuffer(B, 2);
end;

procedure PutU24(S: TStream; V: Integer);
var
  B: array[0..2] of Byte;
begin
  B[0] := V and $FF; B[1] := (V shr 8) and $FF; B[2] := (V shr 16) and $FF;
  S.WriteBuffer(B, 3);
end;

procedure PutU32(S: TStream; V: LongWord);
var
  B: array[0..3] of Byte;
begin
  B[0] := V and $FF; B[1] := (V shr 8) and $FF;
  B[2] := (V shr 16) and $FF; B[3] := (V shr 24) and $FF;
  S.WriteBuffer(B, 4);
end;

procedure PutTag(S: TStream; const Tag: string);
begin
  S.WriteBuffer(Tag[1], 4);
end;

{ Every chunk is padded to an even length, and the pad byte is not counted in
  the size.  Forgetting that is the classic way to write a file that opens in
  one reader and not in another. }
procedure PutChunk(S: TStream; const Tag: string; Data: PByte; Size: Integer);
var
  Pad: Byte;
begin
  PutTag(S, Tag);
  PutU32(S, Size);
  if Size > 0 then S.WriteBuffer(Data^, Size);
  if (Size and 1) <> 0 then
  begin
    Pad := 0;
    S.WriteBuffer(Pad, 1);
  end;
end;

{ The still frame WebPEnc hands back is a whole WebP file.  What goes inside
  an ANMF is only its picture chunk, so this finds it: walk the chunks and
  return the one that holds the image. }
function FindImageChunk(Data: PByte; Size: Integer; out Tag: string;
  out Ofs, Len: Integer): Boolean;
var
  P, ChunkSize: Integer;
  T: string;
begin
  Result := False;
  Tag := ''; Ofs := 0; Len := 0;
  if Size < 20 then Exit;
  P := 12;                            { past RIFF size WEBP }
  while P + 8 <= Size do
  begin
    SetLength(T, 4);
    Move(Data[P], T[1], 4);
    ChunkSize := Data[P + 4] or (Data[P + 5] shl 8) or
                 (Data[P + 6] shl 16) or (Data[P + 7] shl 24);
    if (T = 'VP8L') or (T = 'VP8 ') then
    begin
      Tag := T; Ofs := P + 8; Len := ChunkSize;
      Exit(True);
    end;
    Inc(P, 8 + ChunkSize + (ChunkSize and 1));
  end;
end;

{ --- the writer ------------------------------------------------------- }

constructor TWebPAnimWriter.Create(AWidth, AHeight: Integer;
  ALossless: Boolean; AQuality: Single; ALoop: Integer);
begin
  inherited Create;
  FW := AWidth; FH := AHeight;
  FLossless := ALossless; FQuality := AQuality; FLoop := ALoop;
  FFrames := TMemoryStream.Create;
end;

destructor TWebPAnimWriter.Destroy;
begin
  FFrames.Free;
  inherited Destroy;
end;

function TWebPAnimWriter.AddFrame(BGRA: PByte; Millis: Integer;
  Stride: Integer): Boolean;
var
  Enc: PByte;
  Sz, Ofs, Len: Integer;
  Tag: string;
  Payload: TMemoryStream;
  Byte0: Byte;
begin
  Result := False;
  if (BGRA = nil) or (FW <= 0) or (FH <= 0) then Exit;
  if Stride <= 0 then Stride := FW * 4;
  if FLossless then
    Result := WebPEncodeLosslessBGRA(BGRA, FW, FH, Stride, Enc, Sz)
  else
    Result := WebPEncodeBGRA(BGRA, FW, FH, Stride, FQuality, Enc, Sz);
  if not Result then Exit;
  try
    Result := FindImageChunk(Enc, Sz, Tag, Ofs, Len);
    if not Result then Exit;
    Payload := TMemoryStream.Create;
    try
      { the ANMF header, then the picture chunk whole - tag, size and all }
      PutU24(Payload, 0);                  { x, in pairs of pixels }
      PutU24(Payload, 0);                  { y }
      PutU24(Payload, FW - 1);
      PutU24(Payload, FH - 1);
      PutU24(Payload, Millis);
      Byte0 := 0;                          { blend over, do not dispose }
      Payload.Write(Byte0, 1);
      PutChunk(Payload, Tag, @Enc[Ofs], Len);
      PutChunk(FFrames, 'ANMF', PByte(Payload.Memory), Payload.Size);
    finally
      Payload.Free;
    end;
    Inc(FCount);
  finally
    FreeMem(Enc);
  end;
end;

function TWebPAnimWriter.SaveToFile(const Path: string): Boolean;
var
  Head: TMemoryStream;
  Hdr: array[0..9] of Byte;
  Anim: array[0..5] of Byte;
  Chunks: TMemoryStream;
begin
  Result := False;
  if FCount = 0 then Exit;
  Head := TMemoryStream.Create;
  Chunks := TMemoryStream.Create;
  try
    { --- VP8X: the canvas, and the flag that says there is an animation --
          bit 1 of the flags is ANIMATION.  The alpha bit is left off: what
          we film is opaque, and claiming alpha we do not have makes a reader
          go looking for it. }
    FillChar(Hdr, SizeOf(Hdr), 0);
    Hdr[0] := $02;
    Head.Write(Hdr[0], 1);
    PutU24(Head, 0);                   { reserved }
    PutU24(Head, FW - 1);
    PutU24(Head, FH - 1);
    PutChunk(Chunks, 'VP8X', PByte(Head.Memory), Head.Size);

    { --- ANIM: background and loop count ------------------------------- }
    Head.Size := 0;
    FillChar(Anim, SizeOf(Anim), 0);   { transparent background }
    Head.Write(Anim[0], 4);
    PutU16(Head, FLoop);
    PutChunk(Chunks, 'ANIM', PByte(Head.Memory), Head.Size);

    { --- and the RIFF wrapper round the lot, frames and all ------------ }
    Head.Size := 0;
    PutTag(Head, 'RIFF');
    PutU32(Head, 4 + Chunks.Size + FFrames.Size);   { 'WEBP' plus the rest }
    PutTag(Head, 'WEBP');
    Head.Position := 0;
    with TFileStream.Create(Path, fmCreate) do
    try
      CopyFrom(Head, Head.Size);
      Chunks.Position := 0;
      CopyFrom(Chunks, Chunks.Size);
      FFrames.Position := 0;
      CopyFrom(FFrames, FFrames.Size);
    finally
      Free;
    end;
    Result := True;
  finally
    Chunks.Free;
    Head.Free;
  end;
end;

{ The whole-array call, which is now the writer with a loop round it. }
function SaveWebPAnimation(const Frames: array of TWebPFrame;
  Width, Height: Integer; const Path: string;
  Lossless: Boolean; Quality: Single; Loop: Integer): Boolean;
var
  W: TWebPAnimWriter;
  I: Integer;
begin
  Result := False;
  if (Length(Frames) = 0) or (Width <= 0) or (Height <= 0) then Exit;
  W := TWebPAnimWriter.Create(Width, Height, Lossless, Quality, Loop);
  try
    for I := 0 to High(Frames) do
      if not W.AddFrame(Frames[I].BGRA, Frames[I].Millis) then Exit;
    Result := W.SaveToFile(Path);
  finally
    W.Free;
  end;
end;

end.
