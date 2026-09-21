unit uSourceView;

{ The sheet as its text, beside the sheet.

  A drawing is saved as plain lines, one thing to a line and a few things
  with a line or two more - so the file can be shown, and a line of it and a
  thing on the sheet are the same object seen two ways.  This window is that
  and, for now, only that: read only, and picking goes both ways.  Pick
  things on the sheet and their lines light up here; put the caret on a
  line here, or drag over several, and those things are picked on the sheet.

  It knows nothing about the main form.  It asks for what it needs through
  three events and polls for change on a timer, which is what lets it be a
  window today and a docked pane later without either side being rewritten:

    OnAskState   a number that changes whenever the drawing or the picking
                 does, so a tick that finds it unchanged costs nothing
    OnAskSource  the text, and which lines each thing came out as
    OnAskPicked  what is picked on the sheet
    OnPickThings the person picked lines here; pick these on the sheet

  See TODO.md, "Scripting - thinking only", for where this is meant to go. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls, ComCtrls,
  SynEdit, SynEditTypes, SynGutterBase, SynGutter, SynGutterCodeFolding,
  SynGutterLineNumber, SynEditMarkupHighAll, SynEditMouseCmds, uWork, uSynHsk2;

type
  TSourceAskState = procedure(out DocSeq, PickSeq: Int64) of object;
  { Version 1 is the file as it is saved today; 2 is the proposed format,
    docs/format2.md, written for looking at.  LineThing may come back empty,
    and is then worked out from First and Last. }
  TSourceAskSource = procedure(Version: Integer; L, Hints, Names: TStrings;
    out First, Last, LineThing: TIntArrayW; out SheetName: string) of object;
  TSourceAskPicked = procedure(out Picked: TIntArrayW) of object;
  TSourcePickThings = procedure(const Things: TIntArrayW) of object;

  { TSourceForm }

  TSourceForm = class(TForm)
    chkOnlyPicked: TCheckBox;
    chkVersion2: TCheckBox;
    btnFold: TButton;
    btnUnfold: TButton;
    edtFind: TEdit;
    Editor: TSynEdit;
    pnlTop: TPanel;
    Status: TStatusBar;
    tmrFollow: TTimer;
    procedure chkOnlyPickedChange(Sender: TObject);
    procedure chkVersion2Change(Sender: TObject);
    procedure btnFoldClick(Sender: TObject);
    procedure btnUnfoldClick(Sender: TObject);
    procedure edtFindKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditorSpecialLineColors(Sender: TObject; Line: integer;
      var Special: boolean; var FG, BG: TColor);
    procedure EditorStatusChange(Sender: TObject; Changes: TSynStatusChanges);
    procedure EditorMouseLink(Sender: TObject; X, Y: Integer;
      var AllowMouseLink: Boolean);
    procedure EditorClickLink(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure EditorMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tmrFollowTimer(Sender: TObject);
  private
    FAll: TStringList;          { the whole sheet's text }
    FHints: TStringList;        { for a point written as a step: where it is }
    FNames: TStringList;        { every named point: "line|name=place" }
    FHintWord: string;
    FWhat: string;
    FFirst, FLast: TIntArrayW;  { thing -> its lines in FAll }
    FLineThing: TIntArrayW;     { line in FAll -> thing, or -1 }
    FRowLine: TIntArrayW;       { row shown in the editor -> line in FAll }
    FLinePicked: array of Boolean;
    FPicked: TIntArrayW;
    FDocSeq, FPickSeq: Int64;
    FHaveState: Boolean;
    FBusy: Boolean;             { we are moving the caret, not the person }
    FCaretRow, FBlockA, FBlockB: Integer;
    FColors: TSynHsk2Syn;
    procedure FoldToPicked;
    { the row, counted from 0, where Name_ is given its meaning, looking
      back from FromRow: "name = ..." in a points block, or "circle name" }
    function DefinedAt(const Name_: string; FromRow: Integer): Integer;
    { where a named point is, looked up in the nearest points block above }
    function WhereIs(const Name_: string; FromRow: Integer): string;
    procedure FindNext(Back: Boolean);
    procedure LoadText;
    procedure ShowRows;
    procedure ShowPicked(Scroll: Boolean);
    procedure TellPicked;
  public
    OnAskState: TSourceAskState;
    OnAskSource: TSourceAskSource;
    OnAskPicked: TSourceAskPicked;
    OnPickThings: TSourcePickThings;
    { look again now, rather than at the next tick }
    procedure Refresh_;
  end;

var
  SourceForm: TSourceForm;

implementation

{$R *.lfm}

const
  PICKED_BG = TColor($FFE2C2);   { a pale blue, under the picked lines }
  PICKED_FG = TColor($401000);

procedure TSourceForm.FormCreate(Sender: TObject);
begin
  FAll := TStringList.Create;
  FHints := TStringList.Create;
  FNames := TStringList.Create;
  FHaveState := False;
  FCaretRow := -1;
  FColors := TSynHsk2Syn.Create(Self);

  { The things Lazarus's own editor does, because a drawing written as
    names wants them as much as a program does: every other place the word
    under the caret turns up is outlined; Ctrl and a click on a name goes
    to where it is given its meaning; and resting on one says what that
    is. }
  with Editor.MarkupByClass[TSynEditMarkupHighlightAllCaret] as TSynEditMarkupHighlightAllCaret do
  begin
    MarkupInfo.Background := clNone;
    MarkupInfo.FrameColor := TColor($C08040);
    MarkupInfo.FrameStyle := slsSolid;
    FullWord := True;
    WaitTime := 250;
    IgnoreKeywords := False;
    Enabled := True;
  end;
  Editor.MouseOptions := Editor.MouseOptions + [emShowCtrlMouseLinks, emCtrlWheelZoom];
  Editor.OnKeyDown := @EditorKeyDown;
  Editor.OnMouseLink := @EditorMouseLink;
  Editor.OnClickLink := @EditorClickLink;
  Editor.OnMouseMove := @EditorMouseMove;
  Editor.ShowHint := True;
end;

procedure TSourceForm.FormDestroy(Sender: TObject);
begin
  FAll.Free;
  FHints.Free;
  FNames.Free;
end;

procedure TSourceForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction := caHide;
end;

procedure TSourceForm.Refresh_;
begin
  FHaveState := False;
  tmrFollowTimer(nil);
end;

{ Anything changed?  The drawing, and the text is fetched again; only the
  picking, and the same text is lit differently. }
procedure TSourceForm.tmrFollowTimer(Sender: TObject);
var
  D, P: Int64;
begin
  if not Visible then Exit;
  if not Assigned(OnAskState) then Exit;
  OnAskState(D, P);
  if FHaveState and (D = FDocSeq) and (P = FPickSeq) then Exit;
  if (not FHaveState) or (D <> FDocSeq) then
  begin
    FDocSeq := D;
    FPickSeq := P;
    FHaveState := True;
    LoadText;
    ShowPicked(True);
  end
  else
  begin
    FPickSeq := P;
    ShowPicked(True);
  end;
end;

procedure TSourceForm.LoadText;
var
  I, K: Integer;
  Name_: string;
begin
  FAll.Clear;
  SetLength(FFirst, 0);
  SetLength(FLast, 0);
  Name_ := '';
  SetLength(FLineThing, 0);
  FHints.Clear;
  FNames.Clear;
  if Assigned(OnAskSource) then
    OnAskSource(1 + Ord(chkVersion2.Checked), FAll, FHints, FNames, FFirst, FLast, FLineThing, Name_);
  if Length(FLineThing) <> FAll.Count then
  begin
    SetLength(FLineThing, FAll.Count);
    for I := 0 to High(FLineThing) do FLineThing[I] := -1;
    for I := 0 to High(FFirst) do
      for K := FFirst[I] to FLast[I] do
        if (K >= 0) and (K < FAll.Count) then FLineThing[K] := I;
  end;
  if chkVersion2.Checked then
    FWhat := 'Heck (version 2, proposed) - read only.'
  else
    FWhat := 'The file as it is saved today - read only.';
  if Name_ <> '' then Caption := 'Source - ' + Name_ else Caption := 'Source';
end;

{ Put the rows in the editor: every line, or only the picked things' lines.
  FRowLine says which line of the sheet each row is, either way. }
procedure TSourceForm.ShowRows;
var
  I, N, WasTop: Integer;
  L: TStringList;
begin
  FBusy := True;
  L := TStringList.Create;
  try
    WasTop := Editor.TopLine;
    { version 2 has blocks, so there the others are folded shut rather
      than taken away - see FoldToPicked }
    if chkOnlyPicked.Checked and (Length(FPicked) > 0) and
       not chkVersion2.Checked then
    begin
      N := 0;
      SetLength(FRowLine, FAll.Count);
      for I := 0 to FAll.Count - 1 do
        if FLinePicked[I] then
        begin
          L.Add(FAll[I]);
          FRowLine[N] := I;
          Inc(N);
        end;
      SetLength(FRowLine, N);
    end
    else
    begin
      L.Assign(FAll);
      SetLength(FRowLine, FAll.Count);
      for I := 0 to FAll.Count - 1 do FRowLine[I] := I;
    end;
    if chkVersion2.Checked then Editor.Highlighter := FColors
    else Editor.Highlighter := nil;
    if Editor.Lines.Text <> L.Text then Editor.Lines.Assign(L);
    if WasTop <= Editor.Lines.Count then Editor.TopLine := WasTop;
  finally
    L.Free;
    FBusy := False;
  end;
end;

procedure TSourceForm.ShowPicked(Scroll: Boolean);
var
  I, K, FirstRow, Rows: Integer;
begin
  SetLength(FPicked, 0);
  if Assigned(OnAskPicked) then OnAskPicked(FPicked);
  SetLength(FLinePicked, FAll.Count);
  for I := 0 to High(FLinePicked) do FLinePicked[I] := False;
  for I := 0 to High(FPicked) do
    if (FPicked[I] >= 0) and (FPicked[I] <= High(FFirst)) then
      for K := FFirst[FPicked[I]] to FLast[FPicked[I]] do
        if (K >= 0) and (K < FAll.Count) then FLinePicked[K] := True;

  ShowRows;
  if chkVersion2.Checked then FoldToPicked;

  { bring the first picked line into view, unless it is there already -
    a window that jumps about while things are being picked is worse than
    one that does not move }
  FirstRow := -1;
  for I := 0 to High(FRowLine) do
    if FLinePicked[FRowLine[I]] then begin FirstRow := I; Break; end;
  if Scroll and (FirstRow >= 0) then
  begin
    Rows := Editor.LinesInWindow;
    if (FirstRow + 1 < Editor.TopLine) or (FirstRow + 1 >= Editor.TopLine + Rows) then
    begin
      FBusy := True;
      try
        if FirstRow + 1 > 3 then Editor.TopLine := FirstRow + 1 - 3
        else Editor.TopLine := 1;
      finally
        FBusy := False;
      end;
    end;
  end;
  Editor.Invalidate;
  TellPicked;
end;

{ Version 2, and "only what is picked": every block shut, then the picked
  things' blocks opened - the whole drawing still there, a line each. }
procedure TSourceForm.FoldToPicked;
var
  I, N: Integer;
begin
  FBusy := True;
  try
    Editor.UnfoldAll;
    if not (chkOnlyPicked.Checked and (Length(FPicked) > 0)) then Exit;
    Editor.FoldAll(1, False);
    N := 0;
    for I := 0 to High(FPicked) do
    begin
      if (FPicked[I] < 0) or (FPicked[I] > High(FFirst)) then Continue;
      if FFirst[FPicked[I]] > FLast[FPicked[I]] then Continue;
      Editor.CaretXY := Point(1, FLast[FPicked[I]] + 1);
      Editor.EnsureCursorPosVisible;
      Inc(N);
      if N >= 200 then Break;     { opening thousands one by one is slow }
    end;
  finally
    FBusy := False;
  end;
end;

procedure TSourceForm.TellPicked;
begin
  if Length(FPicked) = 0 then
    Status.SimpleText := Format('  %s  %d lines, %d things.  Click a line to pick it; ' +
      'Ctrl+click a name to go to it.', [FWhat, FAll.Count, Length(FFirst)])
  else
    Status.SimpleText := Format('  %s  %d lines, %d things.  %d picked.',
      [FWhat, FAll.Count, Length(FFirst), Length(FPicked)]);
end;

procedure TSourceForm.EditorSpecialLineColors(Sender: TObject; Line: integer;
  var Special: boolean; var FG, BG: TColor);
var
  R: Integer;
begin
  R := Line - 1;
  if (R < 0) or (R > High(FRowLine)) then Exit;
  if (FRowLine[R] <= High(FLinePicked)) and FLinePicked[FRowLine[R]] then
  begin
    Special := True;
    BG := PICKED_BG;
    FG := PICKED_FG;
  end;
end;

{ The person moved the caret or dragged a block: those lines' things are
  picked on the sheet.  Not while the rows are being put in, and not when
  nothing has moved - SynEdit reports status for a great many reasons. }
procedure TSourceForm.EditorStatusChange(Sender: TObject; Changes: TSynStatusChanges);
var
  A, B, R, T, N, I: Integer;
  Things: TIntArrayW;
  Dup: Boolean;
begin
  if FBusy then Exit;
  if Changes * [scCaretY, scSelection] = [] then Exit;
  A := Editor.CaretY - 1;
  B := A;
  if Editor.SelAvail then
  begin
    A := Editor.BlockBegin.Y - 1;
    B := Editor.BlockEnd.Y - 1;
    { a block that ends at the very start of a line does not include it }
    if (Editor.BlockEnd.X = 1) and (B > A) then Dec(B);
  end;
  if (A = FBlockA) and (B = FBlockB) and (Editor.CaretY - 1 = FCaretRow) then Exit;
  FBlockA := A;
  FBlockB := B;
  FCaretRow := Editor.CaretY - 1;

  N := 0;
  SetLength(Things, B - A + 1);
  for R := A to B do
  begin
    if (R < 0) or (R > High(FRowLine)) then Continue;
    T := FLineThing[FRowLine[R]];
    if T < 0 then Continue;
    Dup := False;
    for I := 0 to N - 1 do
      if Things[I] = T then begin Dup := True; Break; end;
    if Dup then Continue;
    Things[N] := T;
    Inc(N);
  end;
  SetLength(Things, N);
  if Assigned(OnPickThings) then OnPickThings(Things);
  { what the sheet made of it - a line inside a group picks the group - is
    read back at once rather than at the next tick, without scrolling: the
    person is looking at where they clicked }
  if Assigned(OnAskState) then OnAskState(FDocSeq, FPickSeq);
  { the rows stay as they are even when only the picked are shown - taking
    the other rows away from under the pointer would make a second click
    impossible }
  SetLength(FPicked, 0);
  if Assigned(OnAskPicked) then OnAskPicked(FPicked);
  SetLength(FLinePicked, FAll.Count);
  for I := 0 to High(FLinePicked) do FLinePicked[I] := False;
  for I := 0 to High(FPicked) do
    if (FPicked[I] >= 0) and (FPicked[I] <= High(FFirst)) then
      for R := FFirst[FPicked[I]] to FLast[FPicked[I]] do
        if (R >= 0) and (R < FAll.Count) then FLinePicked[R] := True;
  Editor.Invalidate;
  TellPicked;
end;

function TSourceForm.DefinedAt(const Name_: string; FromRow: Integer): Integer;
var
  R, P: Integer;
  T, Stem: string;
begin
  Result := -1;
  if (Name_ = '') or (FromRow > Editor.Lines.Count - 1) then Exit;
  Stem := LowerCase(Name_);
  P := Length(Stem);
  while (P > 0) and (Stem[P] in ['0'..'9']) do Dec(P);
  if (P = Length(Stem)) or (P = 0) then Stem := '' else Stem := Copy(Stem, 1, P);
  for R := FromRow downto 0 do
  begin
    T := LowerCase(Trim(Editor.Lines[R]));
    if (Copy(T, 1, Length(Name_) + 1) = LowerCase(Name_) + ' ') and
       (Pos('=', T) > 0) and (Trim(Copy(T, Length(Name_) + 1, Pos('=', T) - Length(Name_) - 1)) = '') then
      Exit(R);
    if T = 'circle ' + LowerCase(Name_) then Exit(R);
    { ra5 is a corner of "ring ra" }
    if (Stem <> '') and (T = 'ring ' + Stem) then Exit(R);
  end;
  { a circle may be written further down than the face that names it }
  for R := FromRow + 1 to Editor.Lines.Count - 1 do
    if LowerCase(Trim(Editor.Lines[R])) = 'circle ' + LowerCase(Name_) then Exit(R);
end;

function TSourceForm.WhereIs(const Name_: string; FromRow: Integer): string;
var
  I, Bar, Eq, Ln, BestLn, Row: Integer;
  E: string;
begin
  Result := '';
  if (FromRow < 0) or (FromRow > High(FRowLine)) then Exit;
  Row := FRowLine[FromRow];
  BestLn := -1;
  for I := 0 to FNames.Count - 1 do
  begin
    E := FNames[I];
    Bar := Pos('|', E);
    Eq := Pos('=', E);
    if (Bar = 0) or (Eq < Bar) then Continue;
    if Copy(E, Bar + 1, Eq - Bar - 1) <> LowerCase(Name_) then Continue;
    Ln := StrToIntDef(Copy(E, 1, Bar - 1), -1);
    if (Ln <= Row) and (Ln > BestLn) then
    begin
      BestLn := Ln;
      Result := Copy(E, Eq + 1, MaxInt);
    end;
  end;
end;

procedure TSourceForm.FindNext(Back: Boolean);
var
  Opt: TSynSearchOptions;
begin
  if edtFind.Text = '' then Exit;
  Opt := [];
  if Back then Opt := [ssoBackwards];
  if Editor.SearchReplace(edtFind.Text, '', Opt) = 0 then
  begin
    { round again from the other end }
    if Back then Editor.CaretXY := Point(1, Editor.Lines.Count)
    else Editor.CaretXY := Point(1, 1);
    if Editor.SearchReplace(edtFind.Text, '', Opt) = 0 then
      Status.SimpleText := '  "' + edtFind.Text + '" is not in it.';
  end;
end;

procedure TSourceForm.edtFindKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = 13 then
  begin
    FindNext(ssShift in Shift);
    Key := 0;
  end
  else if Key = 27 then
  begin
    Editor.SetFocus;
    Key := 0;
  end;
end;

{ Ctrl+F to the find box, F3 and Shift+F3 for the next and the one before }
procedure TSourceForm.EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = Ord('F')) and (ssCtrl in Shift) then
  begin
    if Editor.SelAvail and (Editor.BlockBegin.Y = Editor.BlockEnd.Y) then
      edtFind.Text := Editor.SelText;
    edtFind.SetFocus;
    edtFind.SelectAll;
    Key := 0;
  end
  else if Key = 114 then         { F3 }
  begin
    FindNext(ssShift in Shift);
    Key := 0;
  end;
end;

procedure TSourceForm.btnFoldClick(Sender: TObject);
begin
  FBusy := True;
  try
    Editor.FoldAll(1, False);
  finally
    FBusy := False;
  end;
end;

procedure TSourceForm.btnUnfoldClick(Sender: TObject);
begin
  FBusy := True;
  try
    Editor.UnfoldAll;
  finally
    FBusy := False;
  end;
end;

procedure TSourceForm.EditorMouseLink(Sender: TObject; X, Y: Integer;
  var AllowMouseLink: Boolean);
var
  W: string;
  At: Integer;
begin
  W := Editor.GetWordAtRowCol(Point(X, Y));
  At := DefinedAt(W, Y - 1);
  AllowMouseLink := (At >= 0) and (At <> Y - 1);
end;

procedure TSourceForm.EditorClickLink(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
  At: Integer;
begin
  P := Editor.PixelsToLogicalPos(Point(X, Y));
  At := DefinedAt(Editor.GetWordAtRowCol(P), P.Y - 1);
  if At < 0 then Exit;
  Editor.CaretXY := Point(1, At + 1);
  Editor.EnsureCursorPosVisible;
  Editor.BlockBegin := Point(1, At + 1);
  Editor.BlockEnd := Point(Length(Editor.Lines[At]) + 1, At + 1);
end;

{ resting on a name: the line that gives it its meaning, and for a point
  written as a step from another, where that comes to }
procedure TSourceForm.EditorMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
  W, H: string;
  At: Integer;
begin
  P := Editor.PixelsToLogicalPos(Point(X, Y));
  W := Editor.GetWordAtRowCol(P);
  if W = FHintWord then Exit;
  FHintWord := W;
  H := '';
  At := DefinedAt(W, P.Y - 1);
  if (At >= 0) and (At <> P.Y - 1) then
  begin
    H := Trim(Editor.Lines[At]);
    if WhereIs(W, P.Y - 1) <> '' then
      H := H + LineEnding + W + ' is at  ' + WhereIs(W, P.Y - 1);
  end;
  Application.CancelHint;
  Editor.Hint := H;
end;

procedure TSourceForm.chkOnlyPickedChange(Sender: TObject);
begin
  ShowPicked(True);
end;

procedure TSourceForm.chkVersion2Change(Sender: TObject);
begin
  Refresh_;
end;

end.
