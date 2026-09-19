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

{ Write the frames as one animated WebP.  Lossless unless Quality is given a
  value of 0..100, which switches to lossy at that quality - the same choice
  the recorder makes, for the same reason.  Loops forever when Loop is 0. }
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

function SaveWebPAnimation(const Frames: array of TWebPFrame;
  Width, Height: Integer; const Path: string;
  Lossless: Boolean; Quality: Single; Loop: Integer): Boolean;
var
  Body, Out_: TMemoryStream;
  I, Sz, Ofs, Len: Integer;
  Enc: PByte;
  Tag: string;
  Hdr: array[0..9] of Byte;
  Anim: array[0..5] of Byte;
  AnmfHdr: array[0..15] of Byte;
  Payload: TMemoryStream;
  Ok: Boolean;
begin
  Result := False;
  if (Length(Frames) = 0) or (Width <= 0) or (Height <= 0) then Exit;

  Body := TMemoryStream.Create;
  Out_ := TMemoryStream.Create;
  try
    { --- VP8X: the canvas, and the flag that says there is an animation --
          bit 1 of the flags is ANIMATION.  The alpha bit is left off: what
          we film is opaque, and claiming alpha we do not have makes a reader
          go looking for it. }
    FillChar(Hdr, SizeOf(Hdr), 0);
    Hdr[0] := $02;
    Body.Write(Hdr[0], 1);
    PutU24(Body, 0);                   { reserved }
    PutU24(Body, Width - 1);
    PutU24(Body, Height - 1);
    Out_.Size := 0;
    { written into Body first so it can be measured, then out as a chunk }
    Body.Position := 0;
    PutChunk(Out_, 'VP8X', PByte(Body.Memory), Body.Size);

    { --- ANIM: background and loop count ------------------------------- }
    Body.Size := 0;
    FillChar(Anim, SizeOf(Anim), 0);   { transparent background }
    Body.Write(Anim[0], 4);
    PutU16(Body, Loop);
    PutChunk(Out_, 'ANIM', PByte(Body.Memory), Body.Size);

    { --- one ANMF per frame -------------------------------------------- }
    for I := 0 to High(Frames) do
    begin
      if Lossless then
        Ok := WebPEncodeLosslessBGRA(Frames[I].BGRA, Width, Height,
          Width * 4, Enc, Sz)
      else
        Ok := WebPEncodeBGRA(Frames[I].BGRA, Width, Height, Width * 4,
          Quality, Enc, Sz);
      if not Ok then Exit;
      try
        if not FindImageChunk(Enc, Sz, Tag, Ofs, Len) then Exit;
        Payload := TMemoryStream.Create;
        try
          { the ANMF header, then the picture chunk whole - tag, size and all }
          FillChar(AnmfHdr, SizeOf(AnmfHdr), 0);
          Payload.Write(AnmfHdr[0], 0);
          PutU24(Payload, 0);                  { x, in pairs of pixels }
          PutU24(Payload, 0);                  { y }
          PutU24(Payload, Width - 1);
          PutU24(Payload, Height - 1);
          PutU24(Payload, Frames[I].Millis);
          AnmfHdr[0] := 0;                     { blend over, do not dispose }
          Payload.Write(AnmfHdr[0], 1);
          PutChunk(Payload, Tag, @Enc[Ofs], Len);
          PutChunk(Out_, 'ANMF', PByte(Payload.Memory), Payload.Size);
        finally
          Payload.Free;
        end;
      finally
        FreeMem(Enc);
      end;
    end;

    { --- and the RIFF wrapper round the lot ---------------------------- }
    Body.Size := 0;
    PutTag(Body, 'RIFF');
    PutU32(Body, 4 + Out_.Size);       { 'WEBP' plus everything above }
    PutTag(Body, 'WEBP');
    Body.Position := 0;
    with TFileStream.Create(Path, fmCreate) do
    try
      CopyFrom(Body, Body.Size);
      Out_.Position := 0;
      CopyFrom(Out_, Out_.Size);
    finally
      Free;
    end;
    Result := True;
  finally
    Out_.Free;
    Body.Free;
  end;
end;

end.
