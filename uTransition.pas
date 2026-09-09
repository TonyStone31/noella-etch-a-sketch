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
  ComCtrls, Dialogs, LCLIntf, IniFiles, uPaths, uWork, uFittings, uFieldElbow;

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
    rgFitting: TRadioGroup;
    rgAngle: TRadioGroup;
    edAngle: TEdit;
    lblDeg: TLabel;
    rgTurn: TRadioGroup;
    lblThroat: TLabel;
    edThroat: TEdit;
    lblThroatHint: TLabel;
    cbSquareHeel: TCheckBox;
    lblLegs: TLabel;
    edLeg0: TEdit;
    edLeg1: TEdit;
    lblLegHint: TLabel;
    lblBranch: TLabel;
    edBW: TEdit;
    lblBX: TLabel;
    edBH: TEdit;
    lblBHint: TLabel;
    rgBranchOn: TRadioGroup;
    lblBFrom: TLabel;
    edBFrom: TEdit;
    lblBUp: TLabel;
    edBUp: TEdit;
    lblBUpHint: TLabel;
    lblBLen: TLabel;
    edBLen: TEdit;
    lblBranchEnd: TLabel;
    cbBranchEnd: TComboBox;
    edBranchEndAmt: TEdit;
    lblEndUnit3: TLabel;
    btnField: TButton;
    lblExitHint: TLabel;
    lblBFromHint: TLabel;
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
    cbFromRef: TCheckBox;
    lblRefEntry: TLabel;
    lblRefExit: TLabel;
    rgRefH: TRadioGroup;
    edRefH0: TEdit;
    edRefH1: TEdit;
    rgRefW: TRadioGroup;
    edRefW0: TEdit;
    edRefW1: TEdit;
    lblRefHint: TLabel;
    lblFlex: TLabel;
    cbRefH0Edge: TComboBox;
    cbRefH1Edge: TComboBox;
    cbRefW0Edge: TComboBox;
    cbRefW1Edge: TComboBox;
    tsTape: TTabSheet;
    pbTape: TPaintBox;
    cbEntryFlex: TComboBox;
    cbExitFlex: TComboBox;
    procedure AnyChange(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure pbSketchPaint(Sender: TObject);
    procedure btnReportClick(Sender: TObject);
    procedure EndKindChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure pbIsoPaint(Sender: TObject);
    procedure btnEmailClick(Sender: TObject);
    procedure btnFilesClick(Sender: TObject);
    procedure FittingChange(Sender: TObject);
    procedure btnFieldClick(Sender: TObject);
    procedure RefModeChange(Sender: TObject);
    procedure pbTapePaint(Sender: TObject);
  private
    FUnits: TUnitSystem;
    { the controls each kind of fitting uses shown, the rest hidden, and the
      shared ones relabelled }
    procedure ShowKind;
    { the two drawings, at any size: the paint boxes and the pictures for
      an email both come from these }
    procedure PaintPlan(C: TCanvas; W, H: Integer);
    procedure PaintElbowPlan(C: TCanvas; W, H: Integer; const T: TTransitionSpec);
    procedure PaintTeePlan(C: TCanvas; W, H: Integer; const T: TTransitionSpec);
    procedure PaintIso(C: TCanvas; W, H: Integer);
    procedure PaintTape(C: TCanvas; W, H: Integer);
    { the pictures and the ticket written to disk; the files made, and where }
    function ExportFiles(out Dir: string; out Files: TStringArray): Boolean;
    function Read(out T: TTransitionSpec): Boolean;
    function InchesOf(const S: string; out V: Double): Boolean;
    { the form as it was for the last fitting built, kept in the settings:
      one fitting is usually much like the one before it }
    procedure LoadLast;
    procedure SaveLast;
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
  MainForm.ReportFromDialog('Build a fitting',
    'fitting: ' + rgFitting.Items[Max(0, rgFitting.ItemIndex)] + LineEnding +
    'entry ' + edEntryW.Text + ' x ' + edEntryH.Text +
    ', exit ' + edExitW.Text + ' x ' + edExitH.Text +
    ', length ' + edLen.Text + LineEnding +
    'width: ' + rgSide.Items[Max(0, rgSide.ItemIndex)] + ' ' + edSideAmount.Text + LineEnding +
    'height: ' + rgHeight.Items[Max(0, rgHeight.ItemIndex)] + ' ' + edHeightAmount.Text + LineEnding +
    'entry end: ' + cbEntryEnd.Text + ' ' + edEntryEndAmt.Text + LineEnding +
    'exit end: ' + cbExitEnd.Text + ' ' + edExitEndAmt.Text + LineEnding +
    'branch end: ' + cbBranchEnd.Text + ' ' + edBranchEndAmt.Text + LineEnding +
    'angle ' + rgAngle.Items[Max(0, rgAngle.ItemIndex)] + ' ' + edAngle.Text +
    ', turn ' + rgTurn.Items[Max(0, rgTurn.ItemIndex)] +
    ', throat ' + edThroat.Text + ', square heel ' + BoolToStr(cbSquareHeel.Checked, True) +
    ', legs ' + edLeg0.Text + ' / ' + edLeg1.Text + LineEnding +
    'branch ' + edBW.Text + ' x ' + edBH.Text + ' on ' + rgBranchOn.Items[Max(0, rgBranchOn.ItemIndex)] +
    ', from ' + edBFrom.Text + ', up ' + edBUp.Text + ', long ' + edBLen.Text + LineEnding +
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
var
  Deg, Off, A0, A1: Double;
begin
  T := Default(TTransitionSpec);
  T.Kind := TFittingKind(Max(0, rgFitting.ItemIndex));
  Result := InchesOf(edEntryW.Text, T.W0) and InchesOf(edEntryH.Text, T.H0);
  case T.Kind of
    fkElbow:
      begin
        case rgAngle.ItemIndex of
          0: T.Angle := DegToRad(22.5);
          1: T.Angle := DegToRad(45);
          2: T.Angle := DegToRad(90);
        else
          begin
            Result := Result and TryStrToFloat(Trim(edAngle.Text), Deg);
            T.Angle := DegToRad(Deg);
          end;
        end;
        T.Turn := TTurn(Max(0, rgTurn.ItemIndex));
        Result := Result and InchesOf(edThroat.Text, T.Throat) and
          InchesOf(edLeg0.Text, T.Leg0) and InchesOf(edLeg1.Text, T.Leg1);
        T.SquareHeel := cbSquareHeel.Checked;
        { the exit opening, blank meaning the same as the entry }
        if Trim(edExitW.Text) = '' then T.W1 := T.W0
        else Result := Result and InchesOf(edExitW.Text, T.W1);
        if Trim(edExitH.Text) = '' then T.H1 := T.H0
        else Result := Result and InchesOf(edExitH.Text, T.H1);
      end;
    fkTee:
      begin
        Result := Result and InchesOf(edLen.Text, T.Len) and
          InchesOf(edBW.Text, T.BW) and InchesOf(edBH.Text, T.BH) and
          InchesOf(edBLen.Text, T.BranchLen);
        T.BranchOn := TBranchSide(Max(0, rgBranchOn.ItemIndex));
        { blank is centred along the run }
        if Trim(edBFrom.Text) = '' then T.BranchFrom := (T.Len - T.BW) / 2
        else Result := Result and InchesOf(edBFrom.Text, T.BranchFrom);
        { blank is centred on the wall }
        if Trim(edBUp.Text) = '' then
        begin
          if T.BranchOn in [bsLeft, bsRight] then T.BranchUp := (T.H0 - T.BH) / 2
          else T.BranchUp := (T.W0 - T.BH) / 2;
        end
        else
          Result := Result and InchesOf(edBUp.Text, T.BranchUp);
        T.W1 := T.W0; T.H1 := T.H0;
        T.Ends[2].Kind := TDuctEnd(Max(0, cbBranchEnd.ItemIndex));
        if T.Ends[2].Kind <> deRaw then
          Result := Result and InchesOf(edBranchEndAmt.Text, T.Ends[2].Amount);
      end;
  else
    begin
      Result := Result and InchesOf(edExitW.Text, T.W1) and InchesOf(edExitH.Text, T.H1) and
                InchesOf(edLen.Text, T.Len);
      if cbFromRef.Checked then
      begin
        { From the tape.  One reference per axis, a reading at each end;
          the rules fall out as differences, and the other edge follows
          from the size once one edge is fixed. }
        T.FromRef := True;
        T.RefH := TRefHeight(Max(0, rgRefH.ItemIndex));
        T.RefW := TRefWidth(Max(0, rgRefW.ItemIndex));
        Result := Result and InchesOf(edRefH0.Text, T.RefH0) and InchesOf(edRefH1.Text, T.RefH1) and
          InchesOf(edRefW0.Text, T.RefW0) and InchesOf(edRefW1.Text, T.RefW1);
        T.RefH0Top := cbRefH0Edge.ItemIndex = 1;
        T.RefH1Top := cbRefH1Edge.ItemIndex = 1;
        T.RefW0Right := cbRefW0Edge.ItemIndex = 1;
        T.RefW1Right := cbRefW1Edge.ItemIndex = 1;
        { Brought to one edge before the difference is taken: from the
          floor everything is said as the bottom, a reading to the top
          less the height; from the ceiling everything as the top, a
          reading to the bottom less the height.  The sides the same. }
        if T.RefH = rhFloor then
        begin
          if T.RefH0Top then A0 := T.RefH0 - T.H0 else A0 := T.RefH0;
          if T.RefH1Top then A1 := T.RefH1 - T.H1 else A1 := T.RefH1;
        end
        else
        begin
          if T.RefH0Top then A0 := T.RefH0 else A0 := T.RefH0 - T.H0;
          if T.RefH1Top then A1 := T.RefH1 else A1 := T.RefH1 - T.H1;
        end;
        Off := A1 - A0;
        if T.RefH = rhFloor then
        begin
          if Abs(Off) < 1E-9 then T.Height := hrFlatBottom
          else if Off > 0 then begin T.Height := hrBottomUp; T.HeightAmount := Off; end
          else begin T.Height := hrBottomDown; T.HeightAmount := -Off; end;
        end
        else
        begin
          if Abs(Off) < 1E-9 then T.Height := hrFlatTop
          else if Off > 0 then begin T.Height := hrTopDown; T.HeightAmount := Off; end
          else begin T.Height := hrTopUp; T.HeightAmount := -Off; end;
        end;
        if T.RefW = rwLeft then
        begin
          if T.RefW0Right then A0 := T.RefW0 - T.W0 else A0 := T.RefW0;
          if T.RefW1Right then A1 := T.RefW1 - T.W1 else A1 := T.RefW1;
        end
        else
        begin
          if T.RefW0Right then A0 := T.RefW0 else A0 := T.RefW0 - T.W0;
          if T.RefW1Right then A1 := T.RefW1 else A1 := T.RefW1 - T.W1;
        end;
        Off := A1 - A0;
        if T.RefW = rwLeft then T.Side := srLeftIn else T.Side := srRightIn;
        T.SideAmount := Off;
      end
      else
      begin
        T.Side := TSideRule(Max(0, rgSide.ItemIndex));
        T.Height := THeightRule(Max(0, rgHeight.ItemIndex));
        if T.Side <> srCentred then
          Result := Result and InchesOf(edSideAmount.Text, T.SideAmount);
        if T.Height in [hrTopUp, hrTopDown, hrBottomUp, hrBottomDown] then
          Result := Result and InchesOf(edHeightAmount.Text, T.HeightAmount);
      end;
    end;
  end;
  T.Ends[0].Kind := TDuctEnd(Max(0, cbEntryEnd.ItemIndex));
  T.Ends[1].Kind := TDuctEnd(Max(0, cbExitEnd.ItemIndex));
  if T.Kind = fkTransition then
  begin
    T.Ends[0].Flex := TFlexSize(Max(0, cbEntryFlex.ItemIndex));
    T.Ends[1].Flex := TFlexSize(Max(0, cbExitFlex.ItemIndex));
  end;
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
  FX: TFlexSize;
begin
  for K := Low(TDuctEnd) to High(TDuctEnd) do
  begin
    cbEntryEnd.Items.Add(DUCT_END_NAMES[K]);
    cbExitEnd.Items.Add(DUCT_END_NAMES[K]);
    cbBranchEnd.Items.Add(DUCT_END_NAMES[K]);
  end;
  cbEntryEnd.ItemIndex := 0;
  cbExitEnd.ItemIndex := 0;
  cbBranchEnd.ItemIndex := 0;
  for FX := Low(TFlexSize) to High(TFlexSize) do
  begin
    cbEntryFlex.Items.Add(FLEX_NAMES[FX]);
    cbExitFlex.Items.Add(FLEX_NAMES[FX]);
  end;
  cbEntryFlex.ItemIndex := 0;
  cbExitFlex.ItemIndex := 0;
  ShowKind;
end;

procedure TTransitionForm.FittingChange(Sender: TObject);
begin
  ShowKind;
  AnyChange(nil);
end;

{ The angle and the legs from what was measured on the job, put into the
  elbow's fields as if they had been typed. }
procedure TTransitionForm.RefModeChange(Sender: TObject);
begin
  ShowKind;
  if cbFromRef.Checked and tsTape.TabVisible then pcViews.ActivePage := tsTape
  else if pcViews.ActivePage = tsTape then pcViews.ActivePage := tsPlan;
  AnyChange(nil);
end;

procedure TTransitionForm.pbTapePaint(Sender: TObject);
begin
  PaintTape(pbTape.Canvas, pbTape.Width, pbTape.Height);
end;

procedure TTransitionForm.btnFieldClick(Sender: TObject);
var
  T: TTransitionSpec;
begin
  if not Read(T) then
  begin
    lblProblem.Caption := 'The opening and the throat radius have to read first.';
    Exit;
  end;
  if not TFieldElbowForm.Ask(FUnits, T) then Exit;
  rgAngle.ItemIndex := 3;
  edAngle.Text := FormatFloat('0.##', RadToDeg(T.Angle));
  edLeg0.Text := FormatFloat('0.###', T.Leg0 / T.Inch);
  edLeg1.Text := FormatFloat('0.###', T.Leg1 / T.Inch);
  AnyChange(nil);
end;

procedure TTransitionForm.ShowKind;
var
  K: TFittingKind;
  Tr, El, Te: Boolean;
begin
  K := TFittingKind(Max(0, rgFitting.ItemIndex));
  Tr := K = fkTransition; El := K = fkElbow; Te := K = fkTee;
  { the transition's own - and the exit size is the elbow's too, for a
    reducing elbow }
  lblExit.Visible := not Te; edExitW.Visible := not Te; lblExitX.Visible := not Te; edExitH.Visible := not Te;
  lblExitHint.Visible := El;
  btnField.Visible := El;
  cbFromRef.Visible := Tr;
  lblFlex.Visible := Tr; cbEntryFlex.Visible := Tr; cbExitFlex.Visible := Tr;
  rgSide.Visible := Tr and not cbFromRef.Checked; edSideAmount.Visible := rgSide.Visible;
  rgHeight.Visible := rgSide.Visible; edHeightAmount.Visible := rgSide.Visible;
  lblRefEntry.Visible := Tr and cbFromRef.Checked; lblRefExit.Visible := lblRefEntry.Visible;
  rgRefH.Visible := lblRefEntry.Visible; edRefH0.Visible := lblRefEntry.Visible; edRefH1.Visible := lblRefEntry.Visible;
  rgRefW.Visible := lblRefEntry.Visible; edRefW0.Visible := lblRefEntry.Visible; edRefW1.Visible := lblRefEntry.Visible;
  lblRefHint.Visible := lblRefEntry.Visible;
  cbRefH0Edge.Visible := lblRefEntry.Visible; cbRefH1Edge.Visible := lblRefEntry.Visible;
  cbRefW0Edge.Visible := lblRefEntry.Visible; cbRefW1Edge.Visible := lblRefEntry.Visible;
  tsTape.TabVisible := lblRefEntry.Visible;
  { the length row is the transition's and the tee's }
  lblLen.Visible := not El; edLen.Visible := not El; lblLenHint.Visible := not El;
  { the elbow's }
  rgAngle.Visible := El; edAngle.Visible := El; lblDeg.Visible := El;
  rgTurn.Visible := El;
  lblThroat.Visible := El; edThroat.Visible := El; lblThroatHint.Visible := El;
  cbSquareHeel.Visible := El;
  lblLegs.Visible := El; edLeg0.Visible := El; edLeg1.Visible := El; lblLegHint.Visible := El;
  { the tee's }
  lblBranch.Visible := Te; edBW.Visible := Te; lblBX.Visible := Te; edBH.Visible := Te; lblBHint.Visible := Te;
  rgBranchOn.Visible := Te;
  lblBFrom.Visible := Te; edBFrom.Visible := Te; lblBFromHint.Visible := Te;
  lblBUp.Visible := Te; edBUp.Visible := Te; lblBUpHint.Visible := Te;
  lblBLen.Visible := Te; edBLen.Visible := Te;
  lblBranchEnd.Visible := Te; cbBranchEnd.Visible := Te; edBranchEndAmt.Visible := Te; lblEndUnit3.Visible := Te;
  { the shared rows, said the right way }
  case K of
    fkElbow:
      begin
        lblTitle.Caption := 'Measure the turn';
        lblEntry.Caption := 'Opening';
        lblExit.Caption := 'Exit opening';
      end;
    fkTee:
      begin
        lblTitle.Caption := 'Measure the run and the branch';
        lblEntry.Caption := 'Run opening';
        lblLen.Caption := 'Run length';
        lblLenHint.Caption := 'entry to exit';
      end;
  else
    begin
      lblTitle.Caption := 'Measure the gap it fills';
      lblEntry.Caption := 'Entry opening';
      lblLen.Caption := 'Length';
      lblLenHint.Caption := 'the gap, entry to exit';
    end;
  end;
end;

{ A kind of end picked: its size starts at what the shop would say - a one
  inch notch, a one inch flange, the TDF's one and three eighths - and can
  be typed over. }
procedure TTransitionForm.EndKindChange(Sender: TObject);
var
  Ed: TEdit;
  K: TDuctEnd;
begin
  if Sender = cbEntryEnd then Ed := edEntryEndAmt
  else if Sender = cbBranchEnd then Ed := edBranchEndAmt
  else Ed := edExitEndAmt;
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
{ The elbow from above its cheek: the throat, the heel, the legs, with the
  angle and the throat radius written on it. }
procedure TTransitionForm.PaintElbowPlan(C: TCanvas; W, H: Integer; const T: TTransitionSpec);
var
  Pts: TP3Array;
  P: array of TPoint;
  I, Margin: Integer;
  MinX, MaxX, MinY, MaxY, Sc: Double;
  S: string;
begin
  ElbowCheek(T, Pts);
  if Length(Pts) < 3 then Exit;
  Margin := 36;
  MinX := 1E30; MaxX := -1E30; MinY := 1E30; MaxY := -1E30;
  for I := 0 to High(Pts) do
  begin
    MinX := Min(MinX, Pts[I].X); MaxX := Max(MaxX, Pts[I].X);
    MinY := Min(MinY, Pts[I].Y); MaxY := Max(MaxY, Pts[I].Y);
  end;
  Sc := Min((W - 2 * Margin) / Max(MaxX - MinX, 1E-9), (H - 2 * Margin) / Max(MaxY - MinY, 1E-9));
  SetLength(P, Length(Pts));
  for I := 0 to High(Pts) do
    P[I] := Point(Round(Margin + (Pts[I].X - MinX) * Sc), Round(H - Margin - (Pts[I].Y - MinY) * Sc));
  C.Pen.Color := clBlack;
  C.Pen.Width := 2;
  C.Brush.Style := bsClear;
  C.Polygon(P);
  C.Pen.Width := 1;
  C.Font.Color := clBlack;
  S := Format('%s x %s, %s%s', [FormatLen(T.W0, FUnits), FormatLen(T.H0, FUnits),
    FormatFloat('0.#', RadToDeg(T.Angle)), #176]);
  C.TextOut(8, 6, S);
  if T.Throat > 0 then S := 'throat R ' + FormatLen(T.Throat, FUnits) else S := 'square throat';
  if T.SquareHeel then S := S + ', square heel';
  C.Font.Color := clGray;
  C.TextOut(8, H - 20, S + ', turns ' + LowerCase(TURN_NAMES[T.Turn]));
  { the entry, marked }
  C.TextOut(P[High(P)].X, P[High(P)].Y + 4, 'entry');
end;

{ The tee: the run along the page, the branch off whichever wall, seen
  from above for a side branch and from the side for a top or bottom one. }
procedure TTransitionForm.PaintTeePlan(C: TCanvas; W, H: Integer; const T: TTransitionSpec);
var
  Margin: Integer;
  Across, MinX, MaxX, Sc, OX: Double;
  Sign: Integer;
  S: string;
  function SX(V: Double): Integer; begin Result := Round(Margin + (V - OX) * Sc); end;
  function SY(V: Double): Integer; begin Result := Round(H - Margin - V * Sc); end;
begin
  Margin := 36;
  if T.BranchOn in [bsLeft, bsRight] then Across := T.W0 else Across := T.H0;
  if T.BranchOn in [bsRight, bsTop] then Sign := 1 else Sign := -1;
  MinX := Min(0, Sign * T.BranchLen);
  MaxX := Max(Across, Across + Sign * T.BranchLen);
  if Sign < 0 then begin MinX := -T.BranchLen; MaxX := Across; end
  else begin MinX := 0; MaxX := Across + T.BranchLen; end;
  OX := MinX;
  Sc := Min((W - 2 * Margin) / Max(MaxX - MinX, 1E-9), (H - 2 * Margin) / Max(T.Len, 1E-9));
  C.Pen.Color := clBlack;
  C.Pen.Width := 2;
  C.Brush.Style := bsClear;
  C.Rectangle(SX(0), SY(0), SX(Across), SY(T.Len));
  if Sign > 0 then
    C.Rectangle(SX(Across), SY(T.BranchFrom), SX(Across + T.BranchLen), SY(T.BranchFrom + T.BW))
  else
    C.Rectangle(SX(-T.BranchLen), SY(T.BranchFrom), SX(0), SY(T.BranchFrom + T.BW));
  C.Pen.Width := 1;
  C.Font.Color := clBlack;
  S := Format('run %s x %s, %s long', [FormatLen(T.W0, FUnits), FormatLen(T.H0, FUnits), FormatLen(T.Len, FUnits)]);
  C.TextOut(8, 6, S);
  S := Format('branch %s x %s off the %s', [FormatLen(T.BW, FUnits), FormatLen(T.BH, FUnits),
    LowerCase(BRANCH_NAMES[T.BranchOn])]);
  C.Font.Color := clGray;
  C.TextOut(8, H - 20, S);
  if T.BranchOn in [bsTop, bsBottom] then C.TextOut(8, H - 36, 'seen from the side');
  C.TextOut(SX(0), SY(0) + 4, 'entry');
end;

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
  Lo, Hi: TP3;
  K: Integer;
  Crate: array[0..7] of TP3;
  S: string;

  function PX(const P: TP3): Double; begin Result := (P.X + P.Y) * CX; end;
  function PY(const P: TP3): Double; begin Result := -P.Z + (P.X - P.Y) * 0.5; end;
  function SX(const P: TP3): Integer; begin Result := Round(Margin + (PX(P) - MinX) * Sc); end;
  function SY(const P: TP3): Integer; begin Result := Round(Margin + (PY(P) - MinY) * Sc); end;
  { nearer the viewer is larger }
  function Near(const P: TP3): Double; begin Result := P.X - P.Y + P.Z; end;

  procedure Edge(A, B: Integer);
  begin
    C.Line(SX(Crate[A]), SY(Crate[A]), SX(Crate[B]), SY(Crate[B]));
  end;

begin
  C.Brush.Color := clWhite;
  C.FillRect(0, 0, W, H);
  C.Pen.Color := clSilver;
  C.Rectangle(0, 0, W, H);
  if not Read(T) or (FittingProblem(T) <> '') then Exit;
  T.Dims := False;
  D := TWorkDoc.Create;
  try
    BuildFitting(D, T, clBlack, 1);
    Margin := 30;
    MinX := 1E30; MaxX := -1E30; MinY := 1E30; MaxY := -1E30;
    Lo := P3(1E30, 1E30, 1E30);
    Hi := P3(-1E30, -1E30, -1E30);
    for I := 0 to D.Live - 1 do
      if D[I].Kind = ekLine then
      begin
        Lo := P3(Min(Lo.X, Min(D[I].A.X, D[I].B.X)), Min(Lo.Y, Min(D[I].A.Y, D[I].B.Y)), Min(Lo.Z, Min(D[I].A.Z, D[I].B.Z)));
        Hi := P3(Max(Hi.X, Max(D[I].A.X, D[I].B.X)), Max(Hi.Y, Max(D[I].A.Y, D[I].B.Y)), Max(Hi.Z, Max(D[I].A.Z, D[I].B.Z)));
        MinX := Min(MinX, Min(PX(D[I].A), PX(D[I].B)));
        MaxX := Max(MaxX, Max(PX(D[I].A), PX(D[I].B)));
        MinY := Min(MinY, Min(PY(D[I].A), PY(D[I].B)));
        MaxY := Max(MaxY, Max(PY(D[I].A), PY(D[I].B)));
      end;
    if MaxX <= MinX then Exit;
    Crate[0] := P3(Lo.X, Lo.Y, Lo.Z); Crate[1] := P3(Hi.X, Lo.Y, Lo.Z);
    Crate[2] := P3(Hi.X, Hi.Y, Lo.Z); Crate[3] := P3(Lo.X, Hi.Y, Lo.Z);
    for K := 0 to 3 do Crate[K + 4] := P3(Crate[K].X, Crate[K].Y, Hi.Z);
    for K := 0 to 7 do
    begin
      MinX := Min(MinX, PX(Crate[K])); MaxX := Max(MaxX, PX(Crate[K]));
      MinY := Min(MinY, PY(Crate[K])); MaxY := Max(MaxY, PY(Crate[K]));
    end;
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
    { The crate: the box the fitting fits in, so a strange one orbited or
      looked at from below still says which way is up and which end is the
      entry.  Drawn, not built - nothing of it goes into the drawing. }
    C.Pen.Style := psClear;
    C.Brush.Style := bsSolid;
    C.Brush.Color := $00E4EEE4;
    C.Polygon([Point(SX(Crate[0]), SY(Crate[0])), Point(SX(Crate[1]), SY(Crate[1])),
               Point(SX(Crate[2]), SY(Crate[2])), Point(SX(Crate[3]), SY(Crate[3]))]);
    C.Pen.Style := psSolid;
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
    { the crate's edges over everything, dashed and light }
    C.Pen.Style := psDash;
    C.Pen.Color := $00B0B0B0;
    C.Brush.Style := bsClear;
    Edge(0, 1); Edge(1, 2); Edge(2, 3); Edge(3, 0);
    Edge(4, 5); Edge(5, 6); Edge(6, 7); Edge(7, 4);
    Edge(0, 4); Edge(1, 5); Edge(2, 6); Edge(3, 7);
    C.Pen.Style := psSolid;
    C.Font.Color := $00507050;
    C.Font.Style := [fsBold];
    S := 'IN';
    C.TextOut((SX(Crate[0]) + SX(Crate[5])) div 2 - C.TextWidth(S) div 2,
      (SY(Crate[0]) + SY(Crate[5])) div 2 - 8, S);
    S := 'OUT';
    C.TextOut((SX(Crate[3]) + SX(Crate[6])) div 2 - C.TextWidth(S) div 2,
      (SY(Crate[3]) + SY(Crate[6])) div 2 - 8, S);
    S := 'TOP';
    C.TextOut((SX(Crate[4]) + SX(Crate[6])) div 2 - C.TextWidth(S) div 2,
      (SY(Crate[4]) + SY(Crate[6])) div 2 - 8, S);
    C.Font.Style := [];
    C.Font.Color := clGray;
    C.TextOut(8, H - 20, 'entry at the front left; the crate is drawn, not built');
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
  edBranchEndAmt.Enabled := cbBranchEnd.ItemIndex > 0;
  edAngle.Enabled := rgAngle.ItemIndex = 3;
  if not Read(T) then
    lblProblem.Caption := 'A size did not read - 20, 20.5, 8 3/4, or 2'' with a mark.'
  else
    lblProblem.Caption := FittingProblem(T);
  btnBuild.Enabled := lblProblem.Caption = '';
  pbSketch.Invalidate;
  pbIso.Invalidate;
  pbTape.Invalidate;
end;

{ Every edit, combo, radio group and checkbox on the form, by name, under
  [fitting] in the settings.  The tag is left out: it names one part. }
procedure TTransitionForm.SaveLast;
var
  Ini: TIniFile;
  I: Integer;
  C: TComponent;
begin
  try
    Ini := TIniFile.Create(ConfigFile);
    try
      for I := 0 to ComponentCount - 1 do
      begin
        C := Components[I];
        if C = edTag then Continue;
        if C is TEdit then Ini.WriteString('fitting', C.Name, TEdit(C).Text)
        else if C is TComboBox then Ini.WriteInteger('fitting', C.Name, TComboBox(C).ItemIndex)
        else if C is TRadioGroup then Ini.WriteInteger('fitting', C.Name, TRadioGroup(C).ItemIndex)
        else if C is TCheckBox then Ini.WriteBool('fitting', C.Name, TCheckBox(C).Checked);
      end;
    finally
      Ini.Free;
    end;
  except
    { a settings file that will not take it is not a reason to stop }
  end;
end;

procedure TTransitionForm.LoadLast;
var
  Ini: TIniFile;
  I: Integer;
  C: TComponent;
begin
  try
    Ini := TIniFile.Create(ConfigFile);
    try
      if not Ini.SectionExists('fitting') then Exit;
      for I := 0 to ComponentCount - 1 do
      begin
        C := Components[I];
        if C = edTag then Continue;
        if not Ini.ValueExists('fitting', C.Name) then Continue;
        if C is TEdit then TEdit(C).Text := Ini.ReadString('fitting', C.Name, TEdit(C).Text)
        else if C is TComboBox then
          TComboBox(C).ItemIndex := EnsureRange(Ini.ReadInteger('fitting', C.Name, 0), 0, TComboBox(C).Items.Count - 1)
        else if C is TRadioGroup then
          TRadioGroup(C).ItemIndex := EnsureRange(Ini.ReadInteger('fitting', C.Name, 0), 0, TRadioGroup(C).Items.Count - 1)
        else if C is TCheckBox then TCheckBox(C).Checked := Ini.ReadBool('fitting', C.Name, TCheckBox(C).Checked);
      end;
    finally
      Ini.Free;
    end;
  except
  end;
  ShowKind;
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

{ The Tape tab: where the tape went.  Two schematics of a horizontal duct,
  entry on the left, exit on the right - an elevation against the floor or
  ceiling above, a plan against the wall below - with a dimension line
  from the reference to whichever edge each reading was taken to.  Change
  the edge and the line jumps; the fitting comes out the same. }
procedure TTransitionForm.PaintTape(C: TCanvas; W, H: Integer);
var
  T: TTransitionSpec;
  Half, Margin, EX0, EX1: Integer;
  RefTop: Boolean;
  A0, A1, B0, B1, Ext: Double;
  S: string;

  { a dimension line from the reference (Y0) to the edge (Y1), its words
    beside its middle - or, when it is too short for that, just past the
    reference on the side away from the duct }
  procedure Dim(X, Y0, Y1: Integer; const Txt: string; Col: TColor; RefAtTop, Rightward: Boolean);
  var
    TY, TX: Integer;
  begin
    C.Pen.Color := Col;
    C.Font.Color := Col;
    C.Line(X, Y0, X, Y1);
    C.Line(X - 4, Y0, X + 4, Y0);
    C.Line(X - 4, Y1, X + 4, Y1);
    { a short line's words go just below the reference, where the far end
      of the band is empty whichever edge the reference is on }
    if Abs(Y1 - Y0) >= 22 then TY := (Y0 + Y1) div 2 - 8
    else TY := Y0 + 4;
    if Rightward then TX := X + 6 else TX := X - 6 - C.TextWidth(Txt);
    C.TextOut(TX, TY, Txt);
  end;

  { one schematic in the band Top..Top+Hgt: the reference line along one
    edge, the two openings as vertical bars joined by the body, and the
    two dimension lines.  A0/B0 are the entry's near and far edge from
    the reference, A1/B1 the exit's, Reading0/1 what was typed, To0/To1
    whether the reading was to the far edge. }
  procedure Band(Top, Hgt: Integer; const RefName, NearName, FarName: string;
    A0, B0, A1, B1, Reading0, Reading1: Double; To0, To1: Boolean; RefAtTop: Boolean);
  var
    Y0, Y1, Ya0, Yb0, Ya1, Yb1, RefY: Integer;
    Sc: Double;
    function YOf(V: Double): Integer;
    begin
      if RefAtTop then Result := Round(RefY + V * Sc) else Result := Round(RefY - V * Sc);
    end;
  begin
    Ext := Max(Max(B0, B1), Max(A0, A1));
    if Ext < 1E-9 then Ext := 1;
    Sc := (Hgt - 2 * Margin - 16) / Ext;
    if RefAtTop then RefY := Top + Margin else RefY := Top + Hgt - Margin;
    { the reference }
    C.Pen.Color := $00505050;
    C.Pen.Width := 3;
    C.Line(Margin div 2, RefY, W - Margin div 2, RefY);
    C.Pen.Width := 1;
    C.Font.Color := $00505050;
    if RefAtTop then C.TextOut((W - C.TextWidth(RefName)) div 2, RefY - 19, RefName)
    else C.TextOut((W - C.TextWidth(RefName)) div 2, RefY + 4, RefName);
    Ya0 := YOf(A0); Yb0 := YOf(B0); Ya1 := YOf(A1); Yb1 := YOf(B1);
    { the body and the two openings }
    C.Pen.Color := $00B0B0B0;
    C.Brush.Color := $00F0ECE6;
    C.Brush.Style := bsSolid;
    C.Polygon([Point(EX0, Ya0), Point(EX1, Ya1), Point(EX1, Yb1), Point(EX0, Yb0)]);
    C.Brush.Style := bsClear;
    C.Pen.Color := clBlack;
    C.Pen.Width := 3;
    C.Line(EX0, Ya0, EX0, Yb0);
    C.Line(EX1, Ya1, EX1, Yb1);
    C.Pen.Width := 1;
    C.Font.Color := clGray;
    C.TextOut(EX0 - 14, Top + 4, 'entry');
    C.TextOut(EX1 - 10, Top + 4, 'exit');
    { the tape: from the reference to the edge it was taken to }
    if To0 then Y0 := Yb0 else Y0 := Ya0;
    if To1 then Y1 := Yb1 else Y1 := Ya1;
    { the tape lines at the outer edges, their words toward the duct }
    if To0 then S := ' to ' + FarName else S := ' to ' + NearName;
    Dim(Margin div 2 + 4, RefY, Y0, FormatLen(Reading0, FUnits) + S, $00A06030, RefAtTop, True);
    if To1 then S := ' to ' + FarName else S := ' to ' + NearName;
    Dim(W - Margin div 2 - 4, RefY, Y1, FormatLen(Reading1, FUnits) + S, $00A06030, RefAtTop, False);
  end;

begin
  C.Brush.Color := clWhite;
  C.FillRect(0, 0, W, H);
  C.Pen.Color := clSilver;
  C.Rectangle(0, 0, W, H);
  if not Read(T) or (FittingProblem(T) <> '') or not T.FromRef then
  begin
    C.Font.Color := clGray;
    C.TextOut(8, 8, 'Tick "Taped from..." and the tape shows here.');
    Exit;
  end;
  Margin := 22;
  Half := H div 2;
  EX0 := Round(W * 0.36);
  EX1 := Round(W * 0.66);
  C.Font.Style := [];
  { height, against the floor or the ceiling: near edge is the bottom from
    the floor and the top from the ceiling }
  RefTop := T.RefH = rhCeiling;
  if not RefTop then
  begin
    if T.RefH0Top then A0 := T.RefH0 - T.H0 else A0 := T.RefH0;
    if T.RefH1Top then A1 := T.RefH1 - T.H1 else A1 := T.RefH1;
    Band(0, Half, 'floor', 'bottom', 'top', A0, A0 + T.H0, A1, A1 + T.H1, T.RefH0, T.RefH1, T.RefH0Top, T.RefH1Top, False);
  end
  else
  begin
    if T.RefH0Top then A0 := T.RefH0 else A0 := T.RefH0 - T.H0;
    if T.RefH1Top then A1 := T.RefH1 else A1 := T.RefH1 - T.H1;
    Band(0, Half, 'ceiling', 'top', 'bottom', A0, A0 + T.H0, A1, A1 + T.H1, T.RefH0, T.RefH1, not T.RefH0Top, not T.RefH1Top, True);
  end;
  C.Pen.Color := clSilver;
  C.Line(0, Half, W, Half);
  { width, against a wall: seen from above with the entry on the left, the
    left side of the flow is the top of the picture }
  if T.RefW = rwLeft then
  begin
    if T.RefW0Right then B0 := T.RefW0 - T.W0 else B0 := T.RefW0;
    if T.RefW1Right then B1 := T.RefW1 - T.W1 else B1 := T.RefW1;
    Band(Half, H - Half, 'left wall', 'left side', 'right side', B0, B0 + T.W0, B1, B1 + T.W1, T.RefW0, T.RefW1, T.RefW0Right, T.RefW1Right, True);
  end
  else
  begin
    if T.RefW0Right then B0 := T.RefW0 else B0 := T.RefW0 - T.W0;
    if T.RefW1Right then B1 := T.RefW1 else B1 := T.RefW1 - T.W1;
    Band(Half, H - Half, 'right wall', 'right side', 'left side', B0, B0 + T.W0, B1, B1 + T.W1, T.RefW0, T.RefW1, not T.RefW0Right, not T.RefW1Right, False);
  end;
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
  if not Read(T) or (FittingProblem(T) <> '') then Exit;
  Margin := 36;
  if T.Kind = fkElbow then
  begin
    PaintElbowPlan(C, W, H, T);
    Exit;
  end;
  if T.Kind = fkTee then
  begin
    PaintTeePlan(C, W, H, T);
    Exit;
  end;
  TransitionCorners(T, E, X);
  OX := Min(0, X[0].X);
  Wmax := Max(Max(E[1].X, X[1].X) - OX, 1E-6);
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
    hrCentred:    S := 'centered';
    hrTopUp:      S := 'top up ' + FormatLen(T.HeightAmount, FUnits);
    hrTopDown:    S := 'top down ' + FormatLen(T.HeightAmount, FUnits);
    hrBottomUp:   S := 'bottom up ' + FormatLen(T.HeightAmount, FUnits);
  else
    S := 'bottom down ' + FormatLen(T.HeightAmount, FUnits);
  end;
  C.Font.Style := [fsBold];
  C.TextOut(8, 8, S);
  C.Font.Style := [];
  C.TextOut(8, H - 20, Format('length %s', [FormatLen(T.Len, FUnits)]));
  { taped from a wall or not, the plan shows the result - the offset - and
    not the readings; the wall was only where the tape was hooked }
end;

class function TTransitionForm.Ask(Units: TUnitSystem; out Spec: TTransitionSpec): Boolean;
var
  F: TTransitionForm;
begin
  Result := False;
  F := TTransitionForm.Create(nil);
  try
    F.FUnits := Units;
    F.LoadLast;
    if F.ShowModal <> mrOK then Exit;
    Result := F.Read(Spec) and (FittingProblem(Spec) = '');
    if Result then F.SaveLast;
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
  if not Read(T) or (FittingProblem(T) <> '') then Exit;
  { beside the program, with the settings and the draft: it all has to run
    from a USB stick and leave nothing behind }
  Dir := AppDataDir + 'fittings' + PathDelim;
  if not ForceDirectories(Dir) then Exit;
  Name_ := T.Tag;
  for I := 1 to Length(Name_) do
    if not (Name_[I] in ['A'..'Z', 'a'..'z', '0'..'9', '-', '_']) then Name_[I] := '_';
  if Name_ = '' then Name_ := LowerCase(FITTING_NAMES[T.Kind]);
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
  if not Read(T) or (FittingProblem(T) <> '') then Exit;
  if not ExportFiles(Dir, Files) then
  begin
    ShowMessage('The pictures could not be written under ' + Dir);
    Exit;
  end;
  Subject := FITTING_NAMES[T.Kind];
  if T.Tag <> '' then Subject := Subject + ' ' + T.Tag;
  Subject := Subject + ': ' + FormatFloat('0.###', T.W0 / T.Inch) + ' x ' +
    FormatFloat('0.###', T.H0 / T.Inch);
  case T.Kind of
    fkElbow: Subject := Subject + ' ' + FormatFloat('0.#', RadToDeg(T.Angle)) + ' degree elbow';
    fkTee: Subject := Subject + ' tee, ' + FormatFloat('0.###', T.BW / T.Inch) + ' x ' +
      FormatFloat('0.###', T.BH / T.Inch) + ' branch';
  else
    Subject := Subject + ' to ' + FormatFloat('0.###', T.W1 / T.Inch) + ' x ' +
      FormatFloat('0.###', T.H1 / T.Inch);
  end;
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
