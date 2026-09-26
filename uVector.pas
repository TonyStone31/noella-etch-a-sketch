unit uVector;

{ The drawing primitives shared by SVG and PDF export.
  Copyright (c) 2026 Noella Stone and Tony Stone - MIT, see LICENSE. }
{$mode objfpc}{$H+}

interface

uses Classes, Types, Graphics;

type
  TVectorLoop = array of TPointF;
  TVectorLoops = array of TVectorLoop;
  TVectorWriter = class
    procedure Path(const Loops: TVectorLoops; Ink: TColor;
      Width: Double; Filled: Boolean); virtual; abstract;
    procedure Text(const P: TPointF; const S: string; Ink: TColor;
      Size: Double; Centered: Boolean); virtual; abstract;
  end;
  TSVGWriter = class(TVectorWriter)
  private
    FLines: TStrings;
  public
    constructor Create(Lines: TStrings);
    procedure Path(const Loops: TVectorLoops; Ink: TColor;
      Width: Double; Filled: Boolean); override;
    procedure Text(const P: TPointF; const S: string; Ink: TColor;
      Size: Double; Centered: Boolean); override;
  end;

implementation

uses SysUtils;

function Num(V: Double): string;
var F: TFormatSettings;
begin
  F := DefaultFormatSettings;
  F.DecimalSeparator := '.';
  Result := FormatFloat('0.00', V, F);
end;

function Col(C: TColor): string;
begin
  Result := Format('#%.2x%.2x%.2x', [Byte(C), Byte(C shr 8), Byte(C shr 16)]);
end;

function Escape(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
end;

constructor TSVGWriter.Create(Lines: TStrings);
begin
  inherited Create;
  FLines := Lines;
end;

procedure TSVGWriter.Path(const Loops: TVectorLoops; Ink: TColor;
  Width: Double; Filled: Boolean);
var
  I, J: Integer;
  D, Fill: string;
begin
  D := '';
  for I := 0 to High(Loops) do
  begin
    if Length(Loops[I]) = 0 then Continue;
    for J := 0 to High(Loops[I]) do
    begin
      if J = 0 then D := D + 'M ' else D := D + 'L ';
      D := D + Num(Loops[I][J].X) + ' ' + Num(Loops[I][J].Y) + ' ';
    end;
    if Filled then D := D + 'Z ';
  end;
  if D = '' then Exit;
  if Filled then Fill := '#d8d8d8' else Fill := 'none';
  FLines.Add('<path d="' + Trim(D) + '" fill="' + Fill +
    '" fill-rule="evenodd" stroke="' + Col(Ink) +
    '" stroke-width="' + Num(Width) + '"/>');
end;

procedure TSVGWriter.Text(const P: TPointF; const S: string; Ink: TColor;
  Size: Double; Centered: Boolean);
var Anchor: string;
begin
  if Centered then Anchor := 'middle' else Anchor := 'start';
  FLines.Add('<text x="' + Num(P.X) + '" y="' + Num(P.Y) +
    '" font-family="sans-serif" font-size="' + Num(Size) +
    '" text-anchor="' + Anchor + '" fill="' + Col(Ink) + '">' + Escape(S) + '</text>');
end;

end.
