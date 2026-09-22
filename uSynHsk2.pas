unit uSynHsk2;

{ Coloring and folding for version 2 of the drawing file - docs/format2.md -
  in the source window.

  The colors are the sheet's: a length going east or west is the red of the
  X axis, north or south the green of Y, up, down and "above the floor" the
  blue of Z - the number as well as the word, so a place reads at a glance
  as three colored parts.  Keywords are bold, the program's own { notes }
  gray, text and materials their own color.

  Folding is the grammar's rule 7, and nothing else: a line with no "=" on
  it opens a block, and "end" closes one.  It is modeled on the LFM
  highlighter that comes with SynEdit, which folds the same shape. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics,
  SynEditHighlighter, SynEditHighlighterFoldBase, LazEditTextAttributes,
  LazEditHighlighter, LazEditFoldHighlighter;

type
  THskToken = (htSpace, htComment, htKey, htProp, htName, htText, htSymbol,
    htEast, htNorth, htUp, htNumber, htColor);

  { TSynHsk2Syn }

  TSynHsk2Syn = class(TSynCustomFoldHighlighter)
  private
    FAttr: array[THskToken] of TLazEditHighlighterAttributes;
    FTok: THskToken;
    FTokPos: Integer;
    Run: Integer;
    FOpens, FCloses, FDone: Boolean;   { this line opens a block / is "end" }
    FListOpens, FListCloses: Boolean;  { "key = (" and the ")" that ends it }
    FSeenEquals: Boolean;
    FAxisNext: THskToken;              { the number after "x" is red, and so on }
    function LineLen_: Integer;
    function WordAt(P: Integer; out Len: Integer): string;
    function AxisOf(const W: string): THskToken;
  protected
    function GetFoldConfigInstance(Index: Integer): TSynCustomFoldConfig; override;
    function GetFoldConfigCount: Integer; override;
    function GetFoldConfigInternalCount: Integer; override;
    procedure CreateRootCodeFoldBlock; override;
  public
    class function GetLanguageName: string; override;
    constructor Create(AOwner: TComponent); override;
    function GetTokenClassAttribute(ATkClass: TLazEditTokenClass;
      ATkDetails: TLazEditTokenDetails = []): TLazEditTextAttribute; override;
    function GetEol: Boolean; override;
    procedure InitForScanningLine; override;
    function GetToken: String; override;
    procedure GetTokenEx(out TokenStart: PChar; out TokenLength: integer); override;
    function GetTokenAttribute: TLazEditTextAttribute; override;
    function GetTokenKind: integer; override;
    function GetTokenPos: Integer; override;
    procedure Next; override;
    { the colors, for a light page or a dark one: the axes' own red, green
      and blue either way, lifted or deepened so they read on the ground }
    procedure UseDark(Dark: Boolean);
  end;

const
  { the axes as the sheet draws them, darkened enough to read on white }
  HSK_RED   = TColor($2020C8);
  HSK_GREEN = TColor($207A20);
  HSK_BLUE  = TColor($C85020);

implementation

const
  KEYWORDS = ' heckerssketch sheet group solid points ring const face noface hole line arc circle ' +
    'box rect pull bore dim note guide jig begin end to true false none ';
  NAMES: array[THskToken] of string = ('Space', 'Note', 'Keyword', 'Property',
    'Name', 'Text', 'Symbol', 'East-west', 'North-south', 'Up-down', 'Number', 'Color');

constructor TSynHsk2Syn.Create(AOwner: TComponent);
var
  T: THskToken;
begin
  inherited Create(AOwner);
  for T := Low(THskToken) to High(THskToken) do
  begin
    FAttr[T] := TLazEditHighlighterAttributes.Create(NAMES[T], NAMES[T]);
    AddAttribute(FAttr[T]);
  end;
  FAttr[htComment].Style := [fsItalic];
  FAttr[htKey].Style := [fsBold];
  UseDark(False);
  SetAttributesOnChange(@DefHighlightChange);
end;

procedure TSynHsk2Syn.UseDark(Dark: Boolean);
begin
  if Dark then
  begin
    FAttr[htComment].Foreground := TColor($8A8A8A);
    FAttr[htKey].Foreground := TColor($F0E0C0);
    FAttr[htProp].Foreground := TColor($C0B0A0);
    FAttr[htName].Foreground := TColor($E8E8E8);
    FAttr[htText].Foreground := TColor($F0C070);
    FAttr[htSymbol].Foreground := TColor($909090);
    FAttr[htEast].Foreground := TColor($6070FF);
    FAttr[htNorth].Foreground := TColor($60D060);
    FAttr[htUp].Foreground := TColor($FFA050);
    FAttr[htNumber].Foreground := TColor($E8E8E8);
    FAttr[htColor].Foreground := TColor($E080E0);
  end
  else
  begin
    FAttr[htComment].Foreground := TColor($909090);
    FAttr[htKey].Foreground := TColor($402010);
    FAttr[htProp].Foreground := TColor($705030);
    FAttr[htName].Foreground := TColor($202020);
    FAttr[htText].Foreground := TColor($1060A0);
    FAttr[htSymbol].Foreground := TColor($808080);
    FAttr[htEast].Foreground := HSK_RED;
    FAttr[htNorth].Foreground := HSK_GREEN;
    FAttr[htUp].Foreground := HSK_BLUE;
    FAttr[htNumber].Foreground := TColor($202020);
    FAttr[htColor].Foreground := TColor($8000A0);
  end;
end;

class function TSynHsk2Syn.GetLanguageName: string;
begin
  Result := 'Heckers Sketch 2';
end;

function TSynHsk2Syn.GetTokenClassAttribute(ATkClass: TLazEditTokenClass;
  ATkDetails: TLazEditTokenDetails): TLazEditTextAttribute;
begin
  case ATkClass of
    tcComment: Result := FAttr[htComment];
    tcIdentifier: Result := FAttr[htName];
    tcKeyword: Result := FAttr[htKey];
    tcString: Result := FAttr[htText];
    tcWhiteSpace: Result := FAttr[htSpace];
    tcSymbol: Result := FAttr[htSymbol];
    tcNumber: Result := FAttr[htNumber];
  else
    Result := nil;
  end;
end;

function TSynHsk2Syn.GetFoldConfigInstance(Index: Integer): TSynCustomFoldConfig;
begin
  Result := inherited GetFoldConfigInstance(Index);
  Result.Enabled := True;
  { a block's opening word and its "end" are a pair to outline together,
    as begin and end are in Lazarus }
  Result.SupportedModes := Result.SupportedModes + [fmMarkup];
  Result.Modes := Result.Modes + [fmMarkup];
end;

function TSynHsk2Syn.GetFoldConfigCount: Integer;
begin
  Result := 2;
end;

function TSynHsk2Syn.GetFoldConfigInternalCount: Integer;
begin
  Result := 3;
end;

procedure TSynHsk2Syn.CreateRootCodeFoldBlock;
begin
  inherited CreateRootCodeFoldBlock;
  RootCodeFoldBlock.InitRootBlockType(Pointer(PtrInt(0)));
end;

function TSynHsk2Syn.LineLen_: Integer;
begin
  Result := Length(CurrentLineText);
end;

function TSynHsk2Syn.WordAt(P: Integer; out Len: Integer): string;
var
  L: PChar;
  N: Integer;
begin
  L := LinePtr;
  N := LineLen_;
  Len := 0;
  while (P + Len < N) and (L[P + Len] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(Len);
  SetString(Result, L + P, Len);
  Result := LowerCase(Result);
end;

function TSynHsk2Syn.AxisOf(const W: string): THskToken;
begin
  if (W = 'x') or (W = 'east') or (W = 'west') then Result := htEast
  else if (W = 'y') or (W = 'north') or (W = 'south') then Result := htNorth
  else if (W = 'z') or (W = 'up') or (W = 'down') then Result := htUp
  else Result := htNumber;
end;

{ Rule 7, worked out once for the line: is there an "=" outside text and
  notes?  No, and it opens a block - unless it is "end", or the header. }
procedure TSynHsk2Syn.InitForScanningLine;
var
  L: PChar;
  I, N, WLen: Integer;
  InText, HasEq: Boolean;
  W: string;
begin
  inherited;
  L := LinePtr;
  N := LineLen_;
  HasEq := False;
  InText := False;
  I := 0;
  while I < N do
  begin
    if InText then
    begin
      if L[I] = '''' then InText := False;
    end
    else if (L[I] = '''') and ((I = 0) or not (L[I - 1] in ['0'..'9'])) then InText := True
    else if L[I] = '{' then Break
    else if (L[I] = '/') and (I + 1 < N) and (L[I + 1] = '/') then Break
    else if L[I] = '=' then begin HasEq := True; Break; end;
    Inc(I);
  end;
  { the last thing on the line that is not a space or a note }
  I := N - 1;
  while (I >= 0) and (L[I] = ' ') do Dec(I);
  if (I >= 0) and (L[I] = '}') then
  begin
    while (I >= 0) and (L[I] <> '{') do Dec(I);
    Dec(I);
    while (I >= 0) and (L[I] = ' ') do Dec(I);
  end;
  FListOpens := HasEq and (I >= 0) and (L[I] = '(');
  FListCloses := (not HasEq) and (I >= 0) and (L[I] = ')');
  I := 0;
  while (I < N) and (L[I] = ' ') do Inc(I);
  W := WordAt(I, WLen);
  FCloses := (W = 'end');
  { inside a bracketed list the lines are its items, not blocks }
  { a "begin" under the word that opened the block is let pass and opens
    nothing: the block is open already }
  FOpens := (not HasEq) and (WLen > 0) and (not FCloses) and (W <> 'heckerssketch') and
            (W <> 'begin') and
            (not FListCloses) and (PtrUInt(TopCodeFoldBlockType) <> 2);
  FDone := False;
  FSeenEquals := False;
  FAxisNext := htNumber;
  Run := 0;
  Next;
end;

procedure TSynHsk2Syn.Next;
var
  L: PChar;
  N, WLen, P: Integer;
  W: string;
begin
  L := LinePtr;
  N := LineLen_;
  FTokPos := Run;
  if Run >= N then Exit;

  case L[Run] of
    ' ', #9:
      begin
        FTok := htSpace;
        while (Run < N) and (L[Run] in [' ', #9]) do Inc(Run);
      end;
    '{':
      begin
        FTok := htComment;
        while (Run < N) and (L[Run] <> '}') do Inc(Run);
        if Run < N then Inc(Run);
      end;
    '''':
      begin
        FTok := htText;
        Inc(Run);
        while Run < N do
        begin
          if L[Run] = '''' then
          begin
            Inc(Run);
            if (Run < N) and (L[Run] = '''') then Inc(Run) else Break;
          end
          else
            Inc(Run);
        end;
      end;
    '#':
      begin
        FTok := htColor;
        Inc(Run);
        while (Run < N) and (L[Run] in ['0'..'9', 'A'..'F', 'a'..'f']) do Inc(Run);
      end;
    '0'..'9', '.', '-':
      begin
        if L[Run] = '-' then Inc(Run);
        { a length - 5' 10 5/8" is one - and it takes the color of the
          direction word after it, if there is one }
        while Run < N do
        begin
          if L[Run] in ['0'..'9', '.', '/', '''', '"'] then Inc(Run)
          else if (L[Run] = ' ') and (Run + 1 < N) and (L[Run + 1] in ['0'..'9']) then Inc(Run)
          else if (L[Run] = #$C2) and (Run + 1 < N) and (L[Run + 1] = #$B0) then Inc(Run, 2)
          else Break;
        end;
        { the color of the direction word that follows it - "4' east" - or
          of the letter that came before it - "x 4'" }
        FTok := FAxisNext;
        FAxisNext := htNumber;
        if FTok = htNumber then
        begin
          P := Run;
          while (P < N) and (L[P] = ' ') do Inc(P);
          W := WordAt(P, WLen);
          if WLen > 1 then FTok := AxisOf(W);
        end;
      end;
  else
    if (L[Run] = '/') and (Run + 1 < N) and (L[Run + 1] = '/') then
    begin
      FTok := htComment;
      Run := N;
    end
    else if L[Run] in ['A'..'Z', 'a'..'z', '_'] then
    begin
      W := WordAt(Run, WLen);
      Inc(Run, WLen);
      FTok := AxisOf(W);
      { "x", "y" and "z" are the axes only in front of a number; anywhere
        else a single letter is somebody's point }
      if (FTok <> htNumber) and (Length(W) = 1) then
      begin
        P := Run;
        while (P < N) and (L[P] = ' ') do Inc(P);
        if (P < N) and (L[P] in ['0'..'9', '.', '-']) then FAxisNext := FTok
        else FTok := htNumber;
      end;
      if FTok = htNumber then
      begin
        if Pos(' ' + W + ' ', KEYWORDS) > 0 then FTok := htKey
        else if not FSeenEquals then FTok := htProp
        else if (W = 'black') or (W = 'white') or (W = 'gray') or (W = 'red') or
                (W = 'orange') or (W = 'yellow') or (W = 'green') or (W = 'blue') or
                (W = 'purple') or (W = 'brown') then FTok := htColor
        else FTok := htName;
      end;
      { the block opens at its first word, and "end" closes at "end" }
      if not FDone then
      begin
        FDone := True;
        if FOpens then StartCodeFoldBlock(Pointer(PtrInt(1)), True)
        else if FCloses then EndCodeFoldBlock(True);
      end;
    end
    else
    begin
      if L[Run] = '=' then FSeenEquals := True;
      if (L[Run] = '(') and FListOpens then StartCodeFoldBlock(Pointer(PtrInt(2)), True);
      if (L[Run] = ')') and FListCloses and (PtrUInt(TopCodeFoldBlockType) = 2) then
        EndCodeFoldBlock(True);
      FTok := htSymbol;
      Inc(Run);
    end;
  end;
end;

function TSynHsk2Syn.GetEol: Boolean;
begin
  Result := FTokPos >= LineLen_;
end;

function TSynHsk2Syn.GetToken: String;
begin
  SetString(Result, LinePtr + FTokPos, Run - FTokPos);
end;

procedure TSynHsk2Syn.GetTokenEx(out TokenStart: PChar; out TokenLength: integer);
begin
  TokenStart := LinePtr + FTokPos;
  TokenLength := Run - FTokPos;
end;

function TSynHsk2Syn.GetTokenAttribute: TLazEditTextAttribute;
begin
  Result := FAttr[FTok];
end;

function TSynHsk2Syn.GetTokenKind: integer;
begin
  Result := Ord(FTok);
end;

function TSynHsk2Syn.GetTokenPos: Integer;
begin
  Result := FTokPos;
end;

end.
