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
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls, ComCtrls, Menus,
  SynEdit, SynEditTypes, SynGutterBase, SynGutter, SynGutterCodeFolding,
  SynGutterLineNumber, SynEditMarkupHighAll, SynEditMarkupWordGroup, SynEditMouseCmds, LCLIntf,
  uWork, uSynHsk2, uJig, uHeckSample, uHeckComplete;

type
  TSourceAskState = procedure(out DocSeq, PickSeq: Int64) of object;
  { Version 1 is the file as it is saved today; 2 is the proposed format,
    docs/format2.md, written for looking at.  LineThing may come back empty,
    and is then worked out from First and Last. }
  TSourceAskSource = procedure(Version: Integer; L, Hints, Names: TStrings;
    out First, Last, LineThing: TIntArrayW; out SheetName: string) of object;
  TSourceAskPicked = procedure(out Picked: TIntArrayW) of object;
  TSourcePickThings = procedure(const Things: TIntArrayW) of object;
  { the text, to be made the drawing: False, a line and why, when it cannot }
  TSourceApply = function(L: TStrings; out ErrLine: Integer; out Err: string): Boolean of object;
  TSourceRunJigs = function: Integer of object;
  { bring what is picked on the sheet to the middle of the view, sized }
  TSourceCenter = procedure of object;

  { TSourceForm }

  TSourceForm = class(TForm)
    chkOnlyPicked: TCheckBox;
    chkOnTop: TCheckBox;
    chkVersion2: TCheckBox;
    btnFold: TButton;
    btnApply: TButton;
    btnRevert: TButton;
    btnSample: TButton;
    btnJigs: TButton;
    lblApply: TLabel;
    pnlApply: TPanel;
    btnUnfold: TButton;
    edtFind: TEdit;
    Editor: TSynEdit;
    pnlTop: TPanel;
    Status: TStatusBar;
    tmrFollow: TTimer;
    pmEditor: TPopupMenu;
    miCenter: TMenuItem;
    miGoTo: TMenuItem;
    miRunJig: TMenuItem;
    procedure chkOnlyPickedChange(Sender: TObject);
    procedure chkVersion2Change(Sender: TObject);
    procedure chkOnTopChange(Sender: TObject);
    procedure btnFoldClick(Sender: TObject);
    procedure btnApplyClick(Sender: TObject);
    procedure btnRevertClick(Sender: TObject);
    procedure btnSampleClick(Sender: TObject);
    procedure btnJigsClick(Sender: TObject);
    procedure EditorChange(Sender: TObject);
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
    procedure miCenterClick(Sender: TObject);
    procedure miGoToClick(Sender: TObject);
    procedure miRunJigClick(Sender: TObject);
    procedure pmEditorPopup(Sender: TObject);
  private
    FAll: TStringList;          { the whole sheet's text }
    FHints: TStringList;        { for a point written as a step: where it is }
    FNames: TStringList;        { every named point: "line|name=place" }
    FHintWord: string;
    FWhat: string;
    FEdited: Boolean;           { the text is the person's now, not the drawing's }
    FErrRow: Integer;
    FDark: Boolean;
    FPickBG, FPickFG: TColor;
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
    FComplete: THeckCompleter;
    FCompleteChange: TNotifyEvent;
    FCompleteKey: TKeyEvent;
    procedure SetEdited(On_: Boolean; const Msg: string = '');
    procedure FoldToPicked;
    { the row, counted from 0, where Name_ is given its meaning, looking
      back from FromRow: "name = ..." in a points block, or "circle name" }
    function DefinedAt(const Name_: string; FromRow: Integer): Integer;
    { where a named point is, looked up in the nearest points block above }
    function WhereIs(const Name_: string; FromRow: Integer): string;
    procedure FindNext(Back: Boolean);
    procedure OpenJigOn(const Line: string);
    procedure JumpTo(Row: Integer);
    procedure EditorMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure LoadText;
    procedure ShowRows;
    procedure ShowPicked(Scroll: Boolean);
    procedure TellPicked;
  public
    OnAskState: TSourceAskState;
    OnAskSource: TSourceAskSource;
    OnAskPicked: TSourceAskPicked;
    OnPickThings: TSourcePickThings;
    OnApply: TSourceApply;
    OnRunJigs: TSourceRunJigs;
    OnCenter: TSourceCenter;
    { look again now, rather than at the next tick }
    procedure Refresh_;
    { the program's theme: the page dark or light to match, and the
      picked-line wash and the axis colors with it }
    procedure UseDark(Dark: Boolean; Back, Fore: TColor);
    { the line of the sheet's text that is thing I - its number, counted
      from 1, and the line itself; False when the text is not current }
    function LineOfThing(I: Integer; out LineNo: Integer; out Line: string): Boolean;
    { the buttons, for a command or a test to press }
    procedure LoadSample;
    procedure ApplyNow;
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
  FErrRow := -1;
  FPickBG := PICKED_BG;
  FPickFG := PICKED_FG;
  FColors := TSynHsk2Syn.Create(Self);
  FComplete := THeckCompleter.Create(Editor);
  FCompleteChange := Editor.OnChange;
  FCompleteKey := Editor.OnKeyDown;
  Editor.OnChange := @EditorChange;

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
  { the word that opens the block the caret is in, and its "end", both
    outlined - what Lazarus does for begin and end }
  with Editor.MarkupByClass[TSynEditMarkupWordGroup] as TSynEditMarkupWordGroup do
  begin
    MarkupInfo.Background := clNone;
    MarkupInfo.Foreground := clNone;
    MarkupInfo.FrameColor := TColor($2060C0);
    MarkupInfo.FrameStyle := slsSolid;
    MarkupInfo.FrameEdges := sfeAround;
    Enabled := True;
  end;
  Editor.MouseOptions := Editor.MouseOptions + [emShowCtrlMouseLinks, emCtrlWheelZoom];
  Editor.OnKeyDown := @EditorKeyDown;   { and it hands on to the completer }
  Editor.OnMouseLink := @EditorMouseLink;
  Editor.OnClickLink := @EditorClickLink;
  Editor.OnMouseMove := @EditorMouseMove;
  Editor.PopupMenu := pmEditor;
  Editor.OnMouseDown := @EditorMouseDown;
  { a little room between the fold marks and the first letter, so the caret
    on column one is not lost against the gutter }
  Editor.Gutter.RightOffset := 6;
  Editor.ShowHint := True;
end;

procedure TSourceForm.FormDestroy(Sender: TObject);
begin
  FComplete.Free;
  FAll.Free;
  FHints.Free;
  FNames.Free;
end;

procedure TSourceForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction := caHide;
end;

procedure TSourceForm.LoadSample;
begin
  btnSampleClick(nil);
end;

procedure TSourceForm.ApplyNow;
begin
  if FEdited then btnApplyClick(nil);
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
  if FEdited then Exit;        { the text is being typed: the drawing waits for Apply }
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
    { Heck can be typed into; the file as it is saved today cannot }
    Editor.ReadOnly := not chkVersion2.Checked or
      (chkOnlyPicked.Checked and not chkVersion2.Checked);
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
  if R = FErrRow then
  begin
    Special := True;
    BG := TColor($D0D0FF);
    FG := TColor($000080);
    Exit;
  end;
  if FEdited then Exit;
  if (R < 0) or (R > High(FRowLine)) then Exit;
  if (FRowLine[R] <= High(FLinePicked)) and FLinePicked[FRowLine[R]] then
  begin
    Special := True;
    BG := FPickBG;
    FG := FPickFG;
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
  if FBusy or FEdited then Exit;
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
    { ra5 is a corner of "ring ra" - but floor1 and top1 are their own }
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

{ jig = 'star' with ... : open star, whatever kind of file it is, in
  whatever this machine opens such files with }
procedure TSourceForm.OpenJigOn(const Line: string);
var
  A, B: Integer;
  F: string;
begin
  A := Pos('''', Line);
  if A = 0 then Exit;
  B := A + 1;
  while (B <= Length(Line)) and (Line[B] <> '''') do Inc(B);
  F := FindJig(Copy(Line, A + 1, B - A - 1));
  if F = '' then
    Status.SimpleText := '  There is no jig called "' + Copy(Line, A + 1, B - A - 1) + '" in ' + JigsDir
  else
    OpenDocument(F);
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
  if Assigned(FCompleteKey) then FCompleteKey(Sender, Key, Shift);
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

{ The text has been typed into.  From here until Apply or Revert it is the
  person's: the drawing is not read again, lines are not picked from it,
  and nothing on the sheet changes. }
procedure TSourceForm.SetEdited(On_: Boolean; const Msg: string);
begin
  FEdited := On_;
  pnlApply.Visible := On_;
  if Msg <> '' then lblApply.Caption := Msg
  else lblApply.Caption := 'Changed.  Apply makes the drawing match; nothing on the sheet moves until then.';
  if not On_ then FErrRow := -1;
  Editor.Invalidate;
end;

procedure TSourceForm.EditorChange(Sender: TObject);
begin
  if Assigned(FCompleteChange) and not FBusy then FCompleteChange(Sender);
  if FBusy or Editor.ReadOnly then Exit;
  if not FEdited then SetEdited(True)
  else if FErrRow >= 0 then
  begin
    FErrRow := -1;
    Editor.Invalidate;
  end;
end;

procedure TSourceForm.btnApplyClick(Sender: TObject);
var
  ErrLine, WasTop, CY: Integer;
  Err: string;
begin
  if not Assigned(OnApply) then Exit;
  WasTop := Editor.TopLine;
  CY := Editor.CaretY;
  if OnApply(Editor.Lines, ErrLine, Err) then
  begin
    SetEdited(False);
    Refresh_;
    FBusy := True;
    try
      if WasTop <= Editor.Lines.Count then Editor.TopLine := WasTop;
      if CY <= Editor.Lines.Count then Editor.CaretY := CY;
    finally
      FBusy := False;
    end;
    Exit;
  end;
  { the title can have its joke; the message under it is plain }
  FErrRow := ErrLine;
  SetEdited(True, Format('What the Heck?  Line %d: %s', [ErrLine + 1, Err]));
  FErrRow := ErrLine;
  if (ErrLine >= 0) and (ErrLine < Editor.Lines.Count) then
  begin
    FBusy := True;
    try
      Editor.CaretXY := Point(1, ErrLine + 1);
      Editor.EnsureCursorPosVisible;
    finally
      FBusy := False;
    end;
  end;
  Editor.Invalidate;
end;

procedure TSourceForm.btnRevertClick(Sender: TObject);
begin
  SetEdited(False);
  Refresh_;
end;

{ A little drawing and three jigs to try it on: the text goes into the
  editor as if it had been typed, so Apply is what makes it happen. }
procedure TSourceForm.btnSampleClick(Sender: TObject);
begin
  if not chkVersion2.Checked then chkVersion2.Checked := True;
  WriteSampleJigs(JigsDir);
  FBusy := True;
  try
    Editor.ReadOnly := False;
    Editor.Lines.Text := SampleHeck;
  finally
    FBusy := False;
  end;
  SetEdited(True, 'A sample, and its jigs are in ' + JigsDir + '.  Press Apply, then Run jigs.');
end;

procedure TSourceForm.btnJigsClick(Sender: TObject);
begin
  if FEdited then
  begin
    lblApply.Caption := 'Apply or Revert first - the jigs run on the drawing, not on what is typed here.';
    Exit;
  end;
  if Assigned(OnRunJigs) then OnRunJigs();
  Refresh_;
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
  AllowMouseLink := ((At >= 0) and (At <> Y - 1)) or
    ((Y >= 1) and (Y <= Editor.Lines.Count) and
     (LowerCase(Copy(Trim(Editor.Lines[Y - 1]), 1, 3)) = 'jig'));
end;

procedure TSourceForm.EditorClickLink(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
  At: Integer;
begin
  P := Editor.PixelsToLogicalPos(Point(X, Y));
  if (P.Y >= 1) and (P.Y <= Editor.Lines.Count) and
     (LowerCase(Copy(Trim(Editor.Lines[P.Y - 1]), 1, 3)) = 'jig') then
  begin
    OpenJigOn(Editor.Lines[P.Y - 1]);
    Exit;
  end;
  At := DefinedAt(Editor.GetWordAtRowCol(P), P.Y - 1);
  if At < 0 then Exit;
  JumpTo(At);
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

{ Right-click: the thing on the caret's line is picked on the sheet - the
  same as a click here does - and then brought to the middle of the view
  and sized, gliding, so the text and the drawing are looking at the same
  thing.  Asked for 21 September: "a right click in the block could be the
  go to and fit". }
{ The right button puts the caret where it went down, before the menu is
  up - so Go to Definition and Center in View act on the word and the line
  under the pointer, and not on wherever the caret happened to be.  What
  Lazarus does, and what makes a right-click menu feel aimed. }
procedure TSourceForm.EditorMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbRight then Exit;
  FBusy := True;
  try
    Editor.CaretXY := Editor.PixelsToLogicalPos(Point(X, Y));
    if Editor.SelAvail then
    begin
      Editor.BlockBegin := Editor.CaretXY;
      Editor.BlockEnd := Editor.CaretXY;
    end;
  finally
    FBusy := False;
  end;
end;

function TSourceForm.LineOfThing(I: Integer; out LineNo: Integer; out Line: string): Boolean;
begin
  Result := False;
  LineNo := 0;
  Line := '';
  if FEdited or (I < 0) or (I > High(FFirst)) then Exit;
  if (FFirst[I] < 0) or (FFirst[I] >= FAll.Count) then Exit;
  LineNo := FFirst[I] + 1;
  Line := Trim(FAll[FFirst[I]]);
  Result := True;
end;

procedure TSourceForm.miCenterClick(Sender: TObject);
var
  A, B, Depth, R: Integer;
  T: string;
begin
  if FEdited then Exit;
  { on a line that opens a block - solid, group, points - the block is
    what is meant: its lines are all picked, as a drag over them would }
  A := Editor.CaretY - 1;
  B := A;
  if (A >= 0) and (A < Editor.Lines.Count) then
  begin
    T := LowerCase(Trim(Editor.Lines[A]));
    if (Pos('=', T) = 0) and (T <> 'end') and (T <> '') then
    begin
      Depth := 1;
      R := A + 1;
      while (R < Editor.Lines.Count) and (Depth > 0) do
      begin
        T := LowerCase(Trim(Editor.Lines[R]));
        if T = 'end' then Dec(Depth)
        else if (T <> '') and (Pos('=', T) = 0) and (T <> 'begin') and
                (T[Length(T)] <> ')') then Inc(Depth);
        Inc(R);
      end;
      B := R - 1;
    end;
  end;
  FBusy := True;
  try
    Editor.BlockBegin := Point(1, A + 1);
    Editor.BlockEnd := Point(1, B + 1);
    if B > A then Editor.BlockEnd := Point(Length(Editor.Lines[B]) + 1, B + 1);
  finally
    FBusy := False;
  end;
  FCaretRow := -1;
  FBlockA := -1;
  FBlockB := -1;
  EditorStatusChange(nil, [scSelection]);
  if Assigned(OnCenter) then OnCenter();
end;

procedure TSourceForm.miGoToClick(Sender: TObject);
var
  At: Integer;
  W: string;
begin
  W := Editor.GetWordAtRowCol(Editor.CaretXY);
  At := DefinedAt(W, Editor.CaretY - 1);
  if At < 0 then Exit;
  JumpTo(At);
end;

{ Go to a line the way Lazarus goes to a definition: the caret on the first
  word rather than in the margin, the line shaded because it is the caret's,
  and the window scrolled so it sits a few lines down from the top. }
procedure TSourceForm.JumpTo(Row: Integer);
var
  C: Integer;
  T: string;
begin
  if (Row < 0) or (Row >= Editor.Lines.Count) then Exit;
  T := Editor.Lines[Row];
  C := 1;
  while (C <= Length(T)) and (T[C] = ' ') do Inc(C);
  FBusy := True;
  try
    if Row + 1 > 4 then Editor.TopLine := Row + 1 - 3 else Editor.TopLine := 1;
    Editor.CaretXY := Point(C, Row + 1);
    Editor.BlockBegin := Editor.CaretXY;
    Editor.BlockEnd := Editor.CaretXY;
  finally
    FBusy := False;
  end;
  Editor.EnsureCursorPosVisible;
  Editor.SetFocus;
end;

procedure TSourceForm.miRunJigClick(Sender: TObject);
begin
  btnJigsClick(nil);
end;

procedure TSourceForm.pmEditorPopup(Sender: TObject);
var
  R: Integer;
  T: string;
begin
  R := Editor.CaretY - 1;
  T := '';
  if (R >= 0) and (R < Editor.Lines.Count) then T := LowerCase(Trim(Editor.Lines[R]));
  miCenter.Enabled := (not FEdited) and (R >= 0) and (T <> '') and (T <> 'end');
  miGoTo.Enabled := DefinedAt(Editor.GetWordAtRowCol(Editor.CaretXY), R) >= 0;
  miRunJig.Visible := Copy(T, 1, 3) = 'jig';
end;

procedure TSourceForm.chkOnlyPickedChange(Sender: TObject);
begin
  ShowPicked(True);
end;

procedure TSourceForm.chkVersion2Change(Sender: TObject);
begin
  Refresh_;
end;

procedure TSourceForm.chkOnTopChange(Sender: TObject);
begin
  if chkOnTop.Checked then FormStyle := fsSystemStayOnTop
  else FormStyle := fsNormal;
end;

procedure TSourceForm.UseDark(Dark: Boolean; Back, Fore: TColor);
var
  I: Integer;
begin
  FDark := Dark;
  FColors.UseDark(Dark);
  Editor.Color := Back;
  Editor.Font.Color := Fore;
  { the gutter: numbers, the fold marks and the separator, all of them
    dressed, since each keeps its own colors and a white one on a dark
    page is what could not be read }
  Editor.Gutter.Color := Back;
  for I := 0 to Editor.Gutter.Parts.Count - 1 do
  begin
    Editor.Gutter.Parts[I].MarkupInfo.Background := Back;
    if Dark then Editor.Gutter.Parts[I].MarkupInfo.Foreground := TColor($A0A0A0)
    else Editor.Gutter.Parts[I].MarkupInfo.Foreground := TColor($606060);
  end;
  Editor.FoldedCodeColor.Foreground := TColor($A0A0A0);
  Editor.FoldedCodeColor.FrameColor := TColor($A0A0A0);
  if Dark then
  begin
    Editor.RightGutter.Color := Back;
    FPickBG := TColor($604020);
    FPickFG := TColor($FFF0E0);
    Editor.SelectedColor.Background := TColor($806040);
    Editor.SelectedColor.Foreground := clWhite;
    { the caret's line a shade lighter, so the eye finds it after a jump }
    Editor.LineHighlightColor.Background := TColor($3A3430);
    Editor.BracketMatchColor.FrameColor := TColor($F0C070);
    (Editor.MarkupByClass[TSynEditMarkupWordGroup] as TSynEditMarkupWordGroup).MarkupInfo.FrameColor := TColor($F0C070);
    (Editor.MarkupByClass[TSynEditMarkupHighlightAllCaret] as TSynEditMarkupHighlightAllCaret).MarkupInfo.FrameColor := TColor($E0A060);
    pnlApply.Color := TColor($405060);
    lblApply.Font.Color := Fore;
  end
  else
  begin
    FPickBG := PICKED_BG;
    FPickFG := PICKED_FG;
    Editor.SelectedColor.Background := clHighlight;
    Editor.SelectedColor.Foreground := clHighlightText;
    Editor.LineHighlightColor.Background := TColor($F4EEE6);
    Editor.BracketMatchColor.FrameColor := clNone;
    (Editor.MarkupByClass[TSynEditMarkupWordGroup] as TSynEditMarkupWordGroup).MarkupInfo.FrameColor := TColor($2060C0);
    (Editor.MarkupByClass[TSynEditMarkupHighlightAllCaret] as TSynEditMarkupHighlightAllCaret).MarkupInfo.FrameColor := TColor($C08040);
    pnlApply.Color := TColor($CCFFFF);
    lblApply.Font.Color := clBlack;
  end;
  Color := Back;
  pnlTop.Color := Back;
  if FComplete <> nil then FComplete.UseDark(Dark, Back, Fore);
  { the buttons keep the platform's own look: their faces stay light, so
    their words have to stay dark whatever the page is }
  for I := 0 to pnlTop.ControlCount - 1 do
    if pnlTop.Controls[I] is TButton then pnlTop.Controls[I].Font.Color := clBlack
    else if pnlTop.Controls[I] is TEdit then
    begin
      pnlTop.Controls[I].Color := clWindow;
      pnlTop.Controls[I].Font.Color := clWindowText;
    end
    else pnlTop.Controls[I].Font.Color := Fore;
  btnApply.Font.Color := clBlack;
  btnRevert.Font.Color := clBlack;
  Status.Color := Back;
  Status.Font.Color := Fore;
  Font.Color := Fore;
  Editor.Invalidate;
end;

end.
