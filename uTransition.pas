unit uTransition;

{ The transition wizard: the gap measured, the fitting built.

  The form reads like the ticket in docs/transition-ticket.md - the two
  openings, the length, and for each axis the one edge that is called out -
  and draws the plan-view sketch beside the numbers as they are typed, the
  way it is drawn on paper: entry at the bottom, exit at the top, the sides
  slanting in, the flow arrow up the page, the height rule as a word. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, StdCtrls, ExtCtrls, Graphics,
  ComCtrls, Dialogs, LCLIntf, uWork, uFittings;

type
  TTransitionForm = class(TForm)
    btnBuild: TButton;
    btnCancel: TButton;
    btnReport: TButton;
    cbEntryEnd: TComboBox;
    cbExitEnd: TComboBox;
    cbDims: TCheckBox;
    edEntryEndAmt: TEdit;
    edExitEndAmt: TEdit;
    lblEnds: TLabel;
    lblEntryEnd: TLabel;
    lblExitEnd: TLabel;
    lblEndUnit1: TLabel;
    lblEndUnit2: TLabel;
    pbIso: TPaintBox;
    pcViews: TPageControl;
    tsPlan: TTabSheet;
    tsIso: TTabSheet;
    lblTag: TLabel;
    lblTagHint: TLabel;
    edTag: TEdit;
    btnEmail: TButton;
    btnFiles: TButton;
    edEntryW: TEdit;
    edEntryH: TEdit;
    edExitW: TEdit;
    edExitH: TEdit;
    edLen: TEdit;
    edSideAmount: TEdit;
    edHeightAmount: TEdit;
    lblTitle: TLabel;
    lblUnits: TLabel;
    lblEntry: TLabel;
    lblEntryX: TLabel;
    lblEntryHint: TLabel;
    lblExit: TLabel;
    lblExitX: TLabel;
    lblLen: TLabel;
    lblLenHint: TLabel;
    lblProblem: TLabel;
    pbSketch: TPaintBox;
    rgSide: TRadioGroup;
    rgHeight: TRadioGroup;
    procedure AnyChange(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure pbSketchPaint(Sender: TObject);
    procedure btnReportClick(Sender: TObject);
    procedure EndKindChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure pbIsoPaint(Sender: TObject);
    procedure btnEmailClick(Sender: TObject);
    procedure btnFilesClick(Sender: TObject);
  private
    FUnits: TUnitSystem;
    { the two drawings, at any size: the paint boxes and the pictures for
      an email both come from these }
    procedure PaintPlan(C: TCanvas; W, H: Integer);
    procedure PaintIso(C: TCanvas; W, H: Integer);
    { the pictures and the ticket written to disk; the files made, and where }
    function ExportFiles(out Dir: string; out Files: TStringArray): Boolean;
    function Read(out T: TTransitionSpec): Boolean;
    function InchesOf(const S: string; out V: Double): Boolean;
  public
    { the whole exchange: returns True with the spec when Build was pressed }
    class function Ask(Units: TUnitSystem; out Spec: TTransitionSpec): Boolean;
  end;

implementation

{$R *.lfm}

uses
  uMain, uMailOut;

{ A problem with the wizard is reported from the wizard, with the wizard in
  the picture and what was typed into it in the words.  From the main window
  the report cannot see the dialog, and the dialog is the thing wrong. }
procedure TTransitionForm.btnReportClick(Sender: TObject);
begin
  MainForm.ReportFromDialog('Build a transition',
    'entry ' + edEntryW.Text + ' x ' + edEntryH.Text +
    ', exit ' + edExitW.Text + ' x ' + edExitH.Text +
    ', length ' + edLen.Text + LineEnding +
    'width: ' + rgSide.Items[Max(0, rgSide.ItemIndex)] + ' ' + edSideAmount.Text + LineEnding +
    'height: ' + rgHeight.Items[Max(0, rgHeight.ItemIndex)] + ' ' + edHeightAmount.Text + LineEnding +
    'entry end: ' + cbEntryEnd.Text + ' ' + edEntryEndAmt.Text + LineEnding +
    'exit end: ' + cbExitEnd.Text + ' ' + edExitEndAmt.Text + LineEnding +
    'dimensions: ' + BoolToStr(cbDims.Checked, True) + LineEnding +
    'tag: ' + edTag.Text + LineEnding +
    'problem shown: ' + lblProblem.Caption);
end;

{ Duct sizes are said in inches - 20x20, 8 3/4 - so a bare number here is
  inches.  A foot mark or an inch mark makes it the drawing's own notation. }
function TTransitionForm.InchesOf(const S: string; out V: Double): Boolean;
var
  T: string;
  F: Double;
begin
  T := Trim(S);
  V := 0;
  if T = '' then Exit(False);
  if (Pos('''', T) > 0) or (Pos('"', T) > 0) or (Pos('m', LowerCase(T)) > 0) then
    Result := ParseLen(T, FUnits, V)
  else
  begin
    Result := ParseLen(T + '"', usImperial, F);
    if Result then V := F;
  end;
end;

function TTransitionForm.Read(out T: TTransitionSpec): Boolean;
begin
  T := Default(TTransitionSpec);
  Result := InchesOf(edEntryW.Text, T.W0) and InchesOf(edEntryH.Text, T.H0) and
            InchesOf(edExitW.Text, T.W1) and InchesOf(edExitH.Text, T.H1) and
            InchesOf(edLen.Text, T.Len);
  T.Side := TSideRule(Max(0, rgSide.ItemIndex));
  T.Height := THeightRule(Max(0, rgHeight.ItemIndex));
  if T.Side <> srCentred then
    Result := Result and InchesOf(edSideAmount.Text, T.SideAmount);
  if T.Height in [hrTopUp, hrTopDown, hrBottomUp, hrBottomDown] then
    Result := Result and InchesOf(edHeightAmount.Text, T.HeightAmount);
  T.Ends[0].Kind := TDuctEnd(Max(0, cbEntryEnd.ItemIndex));
  T.Ends[1].Kind := TDuctEnd(Max(0, cbExitEnd.ItemIndex));
  if T.Ends[0].Kind <> deRaw then
    Result := Result and InchesOf(edEntryEndAmt.Text, T.Ends[0].Amount);
  if T.Ends[1].Kind <> deRaw then
    Result := Result and InchesOf(edExitEndAmt.Text, T.Ends[1].Amount);
  if not InchesOf('1', T.Inch) then T.Inch := 1 / 12;
  T.Dims := cbDims.Checked;
  T.Tag := Trim(edTag.Text);
end;

procedure TTransitionForm.FormCreate(Sender: TObject);
var
  K: TDuctEnd;
begin
  for K := Low(TDuctEnd) to High(TDuctEnd) do
  begin
    cbEntryEnd.Items.Add(DUCT_END_NAMES[K]);
    cbExitEnd.Items.Add(DUCT_END_NAMES[K]);
  end;
  cbEntryEnd.ItemIndex := 0;
  cbExitEnd.ItemIndex := 0;
end;

{ A kind of end picked: its size starts at what the shop would say - a one
  inch notch, a one inch flange, the TDF's one and three eighths - and can
  be typed over. }
procedure TTransitionForm.EndKindChange(Sender: TObject);
var
  Ed: TEdit;
  K: TDuctEnd;
begin
  if Sender = cbEntryEnd then Ed := edEntryEndAmt else Ed := edExitEndAmt;
  K := TDuctEnd(Max(0, TComboBox(Sender).ItemIndex));
  Ed.Enabled := K <> deRaw;
  if K = deRaw then Ed.Text := ''
  else Ed.Text := FormatFloat('0.###', DUCT_END_DEFAULT_IN[K]);
  AnyChange(nil);
end;

{ The corner view: the fitting as it will stand in the drawing, ends and
  all, seen from in front of the entry, to the right and above.  Built with
  the same code that builds it for real, so what is shown is what is
  made. }
procedure TTransitionForm.PaintIso(C: TCanvas; W, H: Integer);
const
  CX = 0.866;
var
  T: TTransitionSpec;
  D: TWorkDoc;
  I, J, Margin, N: Integer;
  MinX, MaxX, MinY, MaxY, Sc: Double;
  Order: array of Integer;
  Depth: array of Double;
  Pts: array of TPoint;
  Sw: Boolean;

  function PX(const P: TP3): Double; begin Result := (P.X + P.Y) * CX; end;
  function PY(const P: TP3): Double; begin Result := -P.Z + (P.X - P.Y) * 0.5; end;
  function SX(const P: TP3): Integer; begin Result := Round(Margin + (PX(P) - MinX) * Sc); end;
  function SY(const P: TP3): Integer; begin Result := Round(Margin + (PY(P) - MinY) * Sc); end;
  { nearer the viewer is larger }
  function Near(const P: TP3): Double; begin Result := P.X - P.Y + P.Z; end;

begin
  C.Brush.Color := clWhite;
  C.FillRect(0, 0, W, H);
  C.Pen.Color := clSilver;
  C.Rectangle(0, 0, W, H);
  if not Read(T) or (TransitionProblem(T) <> '') then Exit;
  T.Dims := False;
  D := TWorkDoc.Create;
  try
    BuildTransition(D, T, clBlack, 1);
    Margin := 16;
    MinX := 1E30; MaxX := -1E30; MinY := 1E30; MaxY := -1E30;
    for I := 0 to D.Live - 1 do
      if D[I].Kind = ekLine then
      begin
        MinX := Min(MinX, Min(PX(D[I].A), PX(D[I].B)));
        MaxX := Max(MaxX, Max(PX(D[I].A), PX(D[I].B)));
        MinY := Min(MinY, Min(PY(D[I].A), PY(D[I].B)));
        MaxY := Max(MaxY, Max(PY(D[I].A), PY(D[I].B)));
      end;
    if MaxX <= MinX then Exit;
    Sc := Min((W - 2 * Margin) / Max(MaxX - MinX, 1E-9),
              (H - 2 * Margin) / Max(MaxY - MinY, 1E-9));
    { the sides, far ones first so the near ones paint over them }
    SetLength(Order, 0);
    SetLength(Depth, 0);
    for I := 0 to D.Live - 1 do
      if D[I].Kind = ekFace then
      begin
        SetLength(Order, Length(Order) + 1);
        SetLength(Depth, Length(Depth) + 1);
        Order[High(Order)] := I;
        Depth[High(Depth)] := 0;
        for J := 0 to High(D[I].Poly) do
          Depth[High(Depth)] := Depth[High(Depth)] + Near(D[I].Poly[J]) / Length(D[I].Poly);
      end;
    repeat
      Sw := False;
      for I := 0 to High(Order) - 1 do
        if Depth[I] > Depth[I + 1] then
        begin
          N := Order[I]; Order[I] := Order[I + 1]; Order[I + 1] := N;
          Sc := Depth[I]; Depth[I] := Depth[I + 1]; Depth[I + 1] := Sc;
          Sw := True;
        end;
    until not Sw;
    Sc := Min((W - 2 * Margin) / Max(MaxX - MinX, 1E-9),
              (H - 2 * Margin) / Max(MaxY - MinY, 1E-9));
    C.Pen.Color := $00909090;
    C.Pen.Width := 1;
    for I := 0 to High(Order) do
    begin
      SetLength(Pts, Length(D[Order[I]].Poly));
      for J := 0 to High(Pts) do
        Pts[J] := Point(SX(D[Order[I]].Poly[J]), SY(D[Order[I]].Poly[J]));
      C.Brush.Color := $00F0ECE6;
      C.Brush.Style := bsSolid;
      C.Polygon(Pts);
    end;
    { and every edge, so the notches and folds read }
    C.Pen.Color := clBlack;
    C.Brush.Style := bsClear;
    for I := 0 to D.Live - 1 do
      if D[I].Kind = ekLine then
        C.Line(SX(D[I].A), SY(D[I].A), SX(D[I].B), SY(D[I].B));
    C.Font.Color := clGray;
    C.TextOut(8, H - 20, 'entry at the front left');
    if T.Tag <> '' then
    begin
      C.Font.Color := clBlack;
      C.Font.Style := [fsBold];
      C.TextOut(8, 6, T.Tag);
      C.Font.Style := [];
    end;
  finally
    D.Free;
  end;
end;

procedure TTransitionForm.AnyChange(Sender: TObject);
var
  T: TTransitionSpec;
begin
  edSideAmount.Enabled := rgSide.ItemIndex > 0;
  edHeightAmount.Enabled := rgHeight.ItemIndex >= 3;
  edEntryEndAmt.Enabled := cbEntryEnd.ItemIndex > 0;
  edExitEndAmt.Enabled := cbExitEnd.ItemIndex > 0;
  if not Read(T) then
    lblProblem.Caption := 'A size did not read - 20, 20.5, 8 3/4, or 2'' with a mark.'
  else
    lblProblem.Caption := TransitionProblem(T);
  btnBuild.Enabled := lblProblem.Caption = '';
  pbSketch.Invalidate;
  pbIso.Invalidate;
end;

procedure TTransitionForm.FormShow(Sender: TObject);
begin
  AnyChange(nil);
  edEntryW.SetFocus;
  edEntryW.SelectAll;
end;

{ The sketch on the ticket: plan view, entry across the bottom, exit across
  the top, the sides between them, the flow arrow, and the height rule
  written on it because a plan view cannot show height. }
procedure TTransitionForm.pbSketchPaint(Sender: TObject);
begin
  PaintPlan(pbSketch.Canvas, pbSketch.Width, pbSketch.Height);
end;

procedure TTransitionForm.pbIsoPaint(Sender: TObject);
begin
  PaintIso(pbIso.Canvas, pbIso.Width, pbIso.Height);
end;

procedure TTransitionForm.PaintPlan(C: TCanvas; W, H: Integer);
var
  T: TTransitionSpec;
  E, X: array[0..3] of TP3;
  Margin: Integer;
  Sc, Wmax, OX: Double;
  S: string;

  function SX(V: Double): Integer; begin Result := Round(Margin + (V - OX) * Sc); end;
  function SY(V: Double): Integer; begin Result := Round(H - Margin - V * Sc); end;

begin
  C.Brush.Color := clWhite;
  C.FillRect(0, 0, W, H);
  C.Pen.Color := clSilver;
  C.Rectangle(0, 0, W, H);
  if not Read(T) or (TransitionProblem(T) <> '') then Exit;
  TransitionCorners(T, E, X);
  Margin := 36;
  Wmax := Max(Max(E[1].X, X[1].X) - Min(0, X[0].X), 1E-6);
  OX := Min(0, X[0].X);
  Sc := Min((W - 2 * Margin) / Wmax, (H - 2 * Margin) / Max(T.Len, 1E-6));
  { the fitting, entry along the bottom }
  C.Pen.Color := clBlack;
  C.Pen.Width := 2;
  C.Brush.Style := bsClear;
  C.Polygon([Point(SX(E[0].X), SY(0)), Point(SX(E[1].X), SY(0)),
             Point(SX(X[1].X), SY(T.Len)), Point(SX(X[0].X), SY(T.Len))]);
  C.Pen.Width := 1;
  { the flow arrow up the middle }
  C.Pen.Color := clGray;
  C.Line((SX(E[0].X) + SX(E[1].X)) div 2, SY(T.Len * 0.15),
         (SX(E[0].X) + SX(E[1].X)) div 2, SY(T.Len * 0.85));
  C.Line((SX(E[0].X) + SX(E[1].X)) div 2, SY(T.Len * 0.85),
         (SX(E[0].X) + SX(E[1].X)) div 2 - 5, SY(T.Len * 0.85) + 8);
  C.Line((SX(E[0].X) + SX(E[1].X)) div 2, SY(T.Len * 0.85),
         (SX(E[0].X) + SX(E[1].X)) div 2 + 5, SY(T.Len * 0.85) + 8);
  { the sizes, top and bottom, as the ticket writes them }
  C.Font.Color := clBlack;
  S := Format('%s x %s', [FormatLen(T.W0, FUnits), FormatLen(T.H0, FUnits)]);
  C.TextOut((SX(E[0].X) + SX(E[1].X)) div 2 - C.TextWidth(S) div 2, SY(0) + 6, S);
  S := Format('%s x %s', [FormatLen(T.W1, FUnits), FormatLen(T.H1, FUnits)]);
  C.TextOut((SX(X[0].X) + SX(X[1].X)) div 2 - C.TextWidth(S) div 2, SY(T.Len) - 20, S);
  { the side that comes in, with its amount against it }
  case T.Side of
    srLeftIn:  begin S := '< ' + FormatLen(T.SideAmount, FUnits); C.TextOut(SX(X[0].X) + 4, SY(T.Len / 2) - 8, S); end;
    srRightIn: begin S := FormatLen(T.SideAmount, FUnits) + ' >'; C.TextOut(SX(X[1].X) - C.TextWidth(S) - 4, SY(T.Len / 2) - 8, S); end;
  end;
  { the height rule, in words, where the paper would carry it }
  case T.Height of
    hrFlatBottom: S := 'FB';
    hrFlatTop:    S := 'FT';
    hrCentred:    S := 'centred';
    hrTopUp:      S := 'top up ' + FormatLen(T.HeightAmount, FUnits);
  else
    S := 'bottom down ' + FormatLen(T.HeightAmount, FUnits);
  end;
  C.Font.Style := [fsBold];
  C.TextOut(8, 8, S);
  C.Font.Style := [];
  C.TextOut(8, H - 20, Format('length %s', [FormatLen(T.Len, FUnits)]));
end;

class function TTransitionForm.Ask(Units: TUnitSystem; out Spec: TTransitionSpec): Boolean;
var
  F: TTransitionForm;
begin
  Result := False;
  F := TTransitionForm.Create(nil);
  try
    F.FUnits := Units;
    if F.ShowModal <> mrOK then Exit;
    Result := F.Read(Spec) and (TransitionProblem(Spec) = '');
  finally
    F.Free;
  end;
end;


{ The pictures at a size worth printing, and the ticket as words, into a
  folder under the home directory that can be found again. }
function TTransitionForm.ExportFiles(out Dir: string; out Files: TStringArray): Boolean;
var
  T: TTransitionSpec;
  Bmp: TBitmap;
  Png: TPortableNetworkGraphic;
  Base, Name_: string;
  L: TStringList;
  I: Integer;

  procedure Picture(const Path: string; Iso: Boolean);
  begin
    Bmp := TBitmap.Create;
    Png := TPortableNetworkGraphic.Create;
    try
      Bmp.SetSize(1200, 900);
      if Iso then PaintIso(Bmp.Canvas, Bmp.Width, Bmp.Height)
      else PaintPlan(Bmp.Canvas, Bmp.Width, Bmp.Height);
      Png.Assign(Bmp);
      Png.SaveToFile(Path);
    finally
      Png.Free;
      Bmp.Free;
    end;
  end;

begin
  Result := False;
  Files := nil;
  if not Read(T) or (TransitionProblem(T) <> '') then Exit;
  Dir := IncludeTrailingPathDelimiter(GetUserDir) + 'Heckers Sketch' + PathDelim +
    'fittings' + PathDelim;
  if not ForceDirectories(Dir) then Exit;
  Name_ := T.Tag;
  for I := 1 to Length(Name_) do
    if not (Name_[I] in ['A'..'Z', 'a'..'z', '0'..'9', '-', '_']) then Name_[I] := '_';
  if Name_ = '' then Name_ := 'transition';
  Base := Dir + Name_ + '-' + FormatDateTime('yyyymmdd-hhnnss', Now);
  SetLength(Files, 3);
  Files[0] := Base + '-plan.png';
  Files[1] := Base + '-3d.png';
  Files[2] := Base + '.txt';
  Picture(Files[0], False);
  Picture(Files[1], True);
  L := TStringList.Create;
  try
    L.Text := TicketText(T) + LineEnding + 'Drawn with Heckers Sketch, ' +
      FormatDateTime('yyyy-mm-dd hh:nn', Now);
    L.SaveToFile(Files[2]);
  finally
    L.Free;
  end;
  Result := True;
end;

{ The ticket to the office, from here: the plan, the corner view and the
  words, on a new message in the mail program.  The files stay in the
  folder either way, so when no mail program answers they can still be
  sent by hand. }
procedure TTransitionForm.btnEmailClick(Sender: TObject);
var
  T: TTransitionSpec;
  Dir, Err, Subject: string;
  Files: TStringArray;
begin
  if not Read(T) or (TransitionProblem(T) <> '') then Exit;
  if not ExportFiles(Dir, Files) then
  begin
    ShowMessage('The pictures could not be written under ' + Dir);
    Exit;
  end;
  Subject := 'Transition';
  if T.Tag <> '' then Subject := Subject + ' ' + T.Tag;
  Subject := Subject + ': ' + FormatFloat('0.###', T.W0 / T.Inch) + ' x ' +
    FormatFloat('0.###', T.H0 / T.Inch) + ' to ' + FormatFloat('0.###', T.W1 / T.Inch) +
    ' x ' + FormatFloat('0.###', T.H1 / T.Inch);
  if SendByEmail(Subject, TicketText(T), Files, Err) then
    lblProblem.Caption := 'Handed to your mail program.  The files are in ' + Dir
  else
  begin
    ShowMessage(Err + LineEnding + LineEnding + 'The plan, the corner view and the ticket ' +
      'are in ' + Dir + ' - attach them by hand.');
    SelectInFolder(Files[0]);
  end;
end;

{ The files without the email: written, and shown in the file manager with
  the plan picked out, ready to drag wherever they go. }
procedure TTransitionForm.btnFilesClick(Sender: TObject);
var
  Dir: string;
  Files: TStringArray;
begin
  if not ExportFiles(Dir, Files) then
  begin
    ShowMessage('The pictures could not be written under ' + Dir);
    Exit;
  end;
  if SelectInFolder(Files[0]) then
    lblProblem.Caption := 'The plan, the corner view and the ticket are in ' + Dir
  else
    ShowMessage('The plan, the corner view and the ticket are in ' + Dir +
      LineEnding + '(no file manager answered to show them)');
end;

end.
