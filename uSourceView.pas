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
  SynEdit, SynEditTypes, uWork;

type
  TSourceAskState = procedure(out DocSeq, PickSeq: Int64) of object;
  TSourceAskSource = procedure(L: TStrings; out First, Last: TIntArrayW;
    out SheetName: string) of object;
  TSourceAskPicked = procedure(out Picked: TIntArrayW) of object;
  TSourcePickThings = procedure(const Things: TIntArrayW) of object;

  { TSourceForm }

  TSourceForm = class(TForm)
    chkOnlyPicked: TCheckBox;
    Editor: TSynEdit;
    lblWhat: TLabel;
    pnlTop: TPanel;
    Status: TStatusBar;
    tmrFollow: TTimer;
    procedure chkOnlyPickedChange(Sender: TObject);
    procedure EditorSpecialLineColors(Sender: TObject; Line: integer;
      var Special: boolean; var FG, BG: TColor);
    procedure EditorStatusChange(Sender: TObject; Changes: TSynStatusChanges);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tmrFollowTimer(Sender: TObject);
  private
    FAll: TStringList;          { the whole sheet's text }
    FFirst, FLast: TIntArrayW;  { thing -> its lines in FAll }
    FLineThing: TIntArrayW;     { line in FAll -> thing, or -1 }
    FRowLine: TIntArrayW;       { row shown in the editor -> line in FAll }
    FLinePicked: array of Boolean;
    FPicked: TIntArrayW;
    FDocSeq, FPickSeq: Int64;
    FHaveState: Boolean;
    FBusy: Boolean;             { we are moving the caret, not the person }
    FCaretRow, FBlockA, FBlockB: Integer;
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
  FHaveState := False;
  FCaretRow := -1;
end;

procedure TSourceForm.FormDestroy(Sender: TObject);
begin
  FAll.Free;
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
  if Assigned(OnAskSource) then OnAskSource(FAll, FFirst, FLast, Name_);
  SetLength(FLineThing, FAll.Count);
  for I := 0 to High(FLineThing) do FLineThing[I] := -1;
  for I := 0 to High(FFirst) do
    for K := FFirst[I] to FLast[I] do
      if (K >= 0) and (K < FAll.Count) then FLineThing[K] := I;
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
    if chkOnlyPicked.Checked and (Length(FPicked) > 0) then
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
    Editor.Lines.Assign(L);
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

procedure TSourceForm.TellPicked;
begin
  if Length(FPicked) = 0 then
    Status.SimpleText := Format('  %d lines, %d things.  Nothing picked - ' +
      'click a line, or drag over several.', [FAll.Count, Length(FFirst)])
  else
    Status.SimpleText := Format('  %d lines, %d things.  %d picked.',
      [FAll.Count, Length(FFirst), Length(FPicked)]);
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

procedure TSourceForm.chkOnlyPickedChange(Sender: TObject);
begin
  ShowPicked(True);
end;

end.
