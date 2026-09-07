unit uSpool;

{ The pipe fitter's iso scratchpad.

  A sheet of iso paper the fitter draws the run on, one leg at a time: click
  where the leg ends and the paper snaps it to one of the three axes - or,
  with Shift held, to a 45 between two of them - then type the
  center-to-center length.  The paper is not to scale; the numbers are.  A
  corner view of the spool builds itself on the other tab from the same
  numbers, the ticket writes itself underneath with every cut length, and
  the whole thing goes to the office by email or drops into the drawing. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, StdCtrls, ExtCtrls, Graphics,
  ComCtrls, Dialogs, LCLIntf, LCLType, Types, uWork, uPipe, uPreview;

type
  TSpoolForm = class(TForm)
    btnBuild: TButton;
    btnCancel: TButton;
    btnEmail: TButton;
    btnFiles: TButton;
    btnLeg: TButton;
    btnReport: TButton;
    btnUndo: TButton;
    cbDims: TCheckBox;
    cbLines: TCheckBox;
    cbMeasure: TComboBox;
    lblMeasureHint: TLabel;
    cbAfter: TComboBox;
    cbNewSize: TComboBox;
    cbEnd0: TComboBox;
    cbEnd1: TComboBox;
    cbSize: TComboBox;
    edLen: TEdit;
    edTag: TEdit;
    lblEnd0: TLabel;
    lblEnd1: TLabel;
    lblHint: TLabel;
    lblLen: TLabel;
    lblLenUnit: TLabel;
    lblSize: TLabel;
    lblStatus: TLabel;
    lblTag: TLabel;
    lblTitle: TLabel;
    memTicket: TMemo;
    pb3D: TPaintBox;
    pbSketch: TPaintBox;
    pcViews: TPageControl;
    rgRadius: TRadioGroup;
    tsIso: TTabSheet;
    ts3D: TTabSheet;
    procedure AnyChange(Sender: TObject);
    procedure MeasureChange(Sender: TObject);
    procedure AfterChange(Sender: TObject);
    procedure btnEmailClick(Sender: TObject);
    procedure btnFilesClick(Sender: TObject);
    procedure btnLegClick(Sender: TObject);
    procedure btnReportClick(Sender: TObject);
    procedure btnUndoClick(Sender: TObject);
    procedure edLenKeyPress(Sender: TObject; var Key: char);
    procedure FormCreate(Sender: TObject);
    procedure pb3DPaint(Sender: TObject);
    procedure pbSketchMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pbSketchMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbSketchPaint(Sender: TObject);
  private
    FUnits: TUnitSystem;
    FLegs: array of TSpoolLeg;
    { the paper advance of each leg per step, whole numbers, so the paper
      stays on its lattice }
    FAdv: array of TP3;
    FSel: Integer;            { the leg the length box is about, or -1 }
    FHover: Boolean;          { the leg the cursor would make }
    FHoverAdv: TP3;
    FHoverSteps: Integer;
    FGrid: Integer;
    function InchesOf(const S: string; out V: Double): Boolean;
    function Read(out S: TSpoolSpec): Boolean;
    function Origin: TPoint;
    function Scr(const Node: TP3): TPoint;
    function EndNode: TP3;
    procedure Refresh;
    procedure PaintSketch(C: TCanvas; W, H: Integer);
    procedure Paint3D(C: TCanvas; W, H: Integer);
    function ExportFiles(out Dir: string; out Files: TStringArray): Boolean;
    procedure Select(I: Integer);
    function SpecOf: TSpoolSpec;
  public
    class function Ask(Units: TUnitSystem; out Spec: TSpoolSpec): Boolean;
  end;

implementation

{$R *.lfm}

uses
  uMain, uMailOut;

const
  { the six axes, then the twelve 45s, as paper advances }
  AXES: array[0..5] of TP3 = ((X: 1; Y: 0; Z: 0), (X: -1; Y: 0; Z: 0), (X: 0; Y: 1; Z: 0),
    (X: 0; Y: -1; Z: 0), (X: 0; Y: 0; Z: 1), (X: 0; Y: 0; Z: -1));
  DIAG: array[0..11] of TP3 = ((X: 1; Y: 1; Z: 0), (X: 1; Y: -1; Z: 0), (X: -1; Y: 1; Z: 0),
    (X: -1; Y: -1; Z: 0), (X: 1; Y: 0; Z: 1), (X: 1; Y: 0; Z: -1), (X: -1; Y: 0; Z: 1),
    (X: -1; Y: 0; Z: -1), (X: 0; Y: 1; Z: 1), (X: 0; Y: 1; Z: -1), (X: 0; Y: -1; Z: 1),
    (X: 0; Y: -1; Z: -1));

function TSpoolForm.InchesOf(const S: string; out V: Double): Boolean;
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

procedure TSpoolForm.FormCreate(Sender: TObject);
var
  I: Integer;
  E: TPipeEnd;
begin
  FGrid := 26;
  cbLines.Checked := False;
  for I := 0 to High(NPS_NAMES) do cbSize.Items.Add(NPS_NAMES[I]);
  cbSize.ItemIndex := 5;
  for E := Low(TPipeEnd) to High(TPipeEnd) do
  begin
    cbEnd0.Items.Add(PIPE_END_NAMES[E]);
    cbEnd1.Items.Add(PIPE_END_NAMES[E]);
  end;
  cbEnd0.ItemIndex := 0;
  cbEnd1.ItemIndex := 0;
  cbMeasure.Items.Add('center to center');
  cbMeasure.Items.Add('end to center');
  cbMeasure.Items.Add('center to end');
  cbMeasure.Items.Add('end to end');
  cbMeasure.ItemIndex := 0;
  cbAfter.Items.Add(LEG_AFTER_NAMES[laNothing]);
  cbAfter.Items.Add(LEG_AFTER_NAMES[laReducer]);
  cbAfter.Items.Add(LEG_AFTER_NAMES[laFlanges]);
  cbAfter.ItemIndex := 0;
  for I := 0 to High(NPS_NAMES) do cbNewSize.Items.Add(NPS_NAMES[I]);
  cbNewSize.ItemIndex := 4;
  cbNewSize.Visible := False;
  FSel := -1;
  lblStatus.Caption := 'Click where the first leg ends.';
end;

{ the measurement kind picked applies to the leg in hand, and is remembered
  for the next }
{ the fitting at the far end of the leg in hand }
procedure TSpoolForm.AfterChange(Sender: TObject);
begin
  cbNewSize.Visible := cbAfter.ItemIndex = 1;
  if (FSel >= 0) and (FSel <= High(FLegs)) then
  begin
    FLegs[FSel].After := TLegAfter(Max(0, cbAfter.ItemIndex));
    FLegs[FSel].NewSize := Max(0, cbNewSize.ItemIndex);
  end;
  Refresh;
end;

procedure TSpoolForm.MeasureChange(Sender: TObject);
begin
  if (FSel >= 0) and (FSel <= High(FLegs)) then
  begin
    FLegs[FSel].FromEnd := cbMeasure.ItemIndex in [1, 3];
    FLegs[FSel].ToEnd := cbMeasure.ItemIndex in [2, 3];
  end;
  Refresh;
end;

function TSpoolForm.Read(out S: TSpoolSpec): Boolean;
begin
  S := Default(TSpoolSpec);
  S.Size := Max(0, cbSize.ItemIndex);
  S.LongRadius := rgRadius.ItemIndex <> 1;
  S.Ends[0] := TPipeEnd(Max(0, cbEnd0.ItemIndex));
  S.Ends[1] := TPipeEnd(Max(0, cbEnd1.ItemIndex));
  S.Legs := Copy(FLegs);
  if not InchesOf('1', S.Inch) then S.Inch := 1 / 12;
  S.Tag := Trim(edTag.Text);
  S.Dims := cbDims.Checked;
  Result := True;
end;

function TSpoolForm.SpecOf: TSpoolSpec;
begin
  Read(Result);
end;

function TSpoolForm.Origin: TPoint;
begin
  Result := Point(Round(pbSketch.Width * 0.30), Round(pbSketch.Height * 0.62));
end;

function TSpoolForm.Scr(const Node: TP3): TPoint;
var
  O: TPoint;
begin
  O := Origin;
  Result.X := Round(O.X + FGrid * (Node.X * 0.866 - Node.Y * 0.866));
  Result.Y := Round(O.Y + FGrid * (Node.X * 0.5 + Node.Y * 0.5 - Node.Z));
end;

function TSpoolForm.EndNode: TP3;
var
  I: Integer;
begin
  Result := P3(0, 0, 0);
  for I := 0 to High(FLegs) do
    Result := P3(Result.X + FAdv[I].X * FLegs[I].Steps, Result.Y + FAdv[I].Y * FLegs[I].Steps,
                 Result.Z + FAdv[I].Z * FLegs[I].Steps);
end;

procedure TSpoolForm.Refresh;
var
  S: TSpoolSpec;
  Err: string;
begin
  Read(S);
  Err := SpoolProblem(S);
  if Length(S.Legs) = 0 then memTicket.Text := Err
  else if Err = '' then memTicket.Text := SpoolTicket(S)
  else memTicket.Text := Err + LineEnding + LineEnding + SpoolTicket(S);
  btnBuild.Enabled := Err = '';
  { a sketch with lengths still to come can still go to the office }
  btnEmail.Enabled := Length(S.Legs) > 0;
  btnFiles.Enabled := Length(S.Legs) > 0;
  pbSketch.Invalidate;
  pb3D.Invalidate;
end;

procedure TSpoolForm.AnyChange(Sender: TObject);
begin
  Refresh;
end;

procedure TSpoolForm.pbSketchMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  E, O: TPoint;
  DX, DY, Best, Score, L: Double;
  I: Integer;
  V: TPoint;
  Cand: TP3;
begin
  E := Scr(EndNode);
  DX := X - E.X; DY := Y - E.Y;
  FHover := False;
  Best := 0;
  O := Scr(P3(0, 0, 0));
  { the axis - or with Shift the 45 - the cursor is most along, and how
    many paper steps out along it }
  for I := 0 to 5 + 12 * Ord(ssShift in Shift) do
  begin
    if I < 6 then Cand := AXES[I] else Cand := DIAG[I - 6];
    if (ssShift in Shift) and (I < 6) then Continue;
    V := Scr(Cand);
    V.X := V.X - O.X; V.Y := V.Y - O.Y;
    L := Sqrt(Sqr(V.X) + Sqr(V.Y));
    if L < 1E-6 then Continue;
    Score := (DX * V.X + DY * V.Y) / L;
    if Score > Best then
    begin
      Best := Score;
      FHover := True;
      FHoverAdv := Cand;
      FHoverSteps := Max(1, Round(Score / L));
    end;
  end;
  if Best < FGrid * 0.5 then FHover := False;
  pbSketch.Invalidate;
end;

procedure TSpoolForm.pbSketchMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  I, K, Best: Integer;
  A, B: TPoint;
  Node: TP3;
  D, BestD, T, L2: Double;
  V: Double;
begin
  if Button = mbRight then
  begin
    { the leg under the click comes out, and the ones after it close up }
    Node := P3(0, 0, 0);
    Best := -1; BestD := 9;
    for I := 0 to High(FLegs) do
    begin
      A := Scr(Node);
      Node := P3(Node.X + FAdv[I].X * FLegs[I].Steps, Node.Y + FAdv[I].Y * FLegs[I].Steps,
                 Node.Z + FAdv[I].Z * FLegs[I].Steps);
      B := Scr(Node);
      L2 := Sqr(B.X - A.X) + Sqr(B.Y - A.Y);
      if L2 < 1 then Continue;
      T := EnsureRange(((X - A.X) * (B.X - A.X) + (Y - A.Y) * (B.Y - A.Y)) / L2, 0, 1);
      D := Sqrt(Sqr(X - (A.X + (B.X - A.X) * T)) + Sqr(Y - (A.Y + (B.Y - A.Y) * T)));
      if D < BestD then begin BestD := D; Best := I; end;
    end;
    if Best >= 0 then
    begin
      for K := Best to High(FLegs) - 1 do
      begin
        FLegs[K] := FLegs[K + 1];
        FAdv[K] := FAdv[K + 1];
      end;
      SetLength(FLegs, Length(FLegs) - 1);
      SetLength(FAdv, Length(FAdv) - 1);
      FSel := -1;
      edLen.Text := '';
      lblStatus.Caption := 'Leg taken out.';
      Refresh;
    end;
    Exit;
  end;
  if Button <> mbLeft then Exit;
  { a click on a leg already drawn picks it up, so its length can be given
    or changed }
  Node := P3(0, 0, 0);
  Best := -1; BestD := 14;
  for I := 0 to High(FLegs) do
  begin
    A := Scr(Node);
    Node := P3(Node.X + FAdv[I].X * FLegs[I].Steps, Node.Y + FAdv[I].Y * FLegs[I].Steps,
               Node.Z + FAdv[I].Z * FLegs[I].Steps);
    B := Scr(Node);
    L2 := Sqr(B.X - A.X) + Sqr(B.Y - A.Y);
    if L2 < 1 then Continue;
    T := EnsureRange(((X - A.X) * (B.X - A.X) + (Y - A.Y) * (B.Y - A.Y)) / L2, 0, 1);
    { the far end of the last leg is where the next one starts, not a pick }
    if (I = High(FLegs)) and (T > 0.85) then Continue;
    D := Sqrt(Sqr(X - (A.X + (B.X - A.X) * T)) + Sqr(Y - (A.Y + (B.Y - A.Y) * T)));
    if D < BestD then begin BestD := D; Best := I; end;
  end;
  if Best >= 0 then
  begin
    Select(Best);
    Exit;
  end;
  pbSketchMouseMove(Sender, Shift, X, Y);
  if not FHover then Exit;
  { a new leg, with no length yet; a length already typed is its }
  SetLength(FLegs, Length(FLegs) + 1);
  SetLength(FAdv, Length(FAdv) + 1);
  FLegs[High(FLegs)] := Default(TSpoolLeg);
  FLegs[High(FLegs)].Dir := Norm3(FHoverAdv);
  FLegs[High(FLegs)].Steps := FHoverSteps;
  FLegs[High(FLegs)].FromEnd := cbMeasure.ItemIndex in [1, 3];
  FLegs[High(FLegs)].ToEnd := cbMeasure.ItemIndex in [2, 3];
  FAdv[High(FAdv)] := FHoverAdv;
  FHover := False;
  FSel := High(FLegs);
  if InchesOf(edLen.Text, V) and (V > 0) then
    btnLegClick(nil)
  else
  begin
    lblStatus.Caption := Format('Leg %d, %s.  How long, %s?  Type it and press Enter - or click on to the next leg and come back to it.',
      [FSel + 1, DirName(FLegs[FSel].Dir), cbMeasure.Text]);
    edLen.SetFocus;
    Refresh;
  end;
end;

{ the leg the length box is about: its numbers into the box }
procedure TSpoolForm.Select(I: Integer);
begin
  FSel := I;
  if (I < 0) or (I > High(FLegs)) then Exit;
  if FLegs[I].Has then edLen.Text := FormatFloat('0.###', FLegs[I].Len * 12)
  else edLen.Text := '';
  cbMeasure.OnChange := nil;
  cbMeasure.ItemIndex := Ord(FLegs[I].FromEnd) + 2 * Ord(FLegs[I].ToEnd);
  cbMeasure.OnChange := @MeasureChange;
  cbAfter.OnChange := nil;
  cbNewSize.OnChange := nil;
  cbAfter.ItemIndex := Ord(FLegs[I].After);
  if FLegs[I].After = laReducer then cbNewSize.ItemIndex := FLegs[I].NewSize;
  cbNewSize.Visible := FLegs[I].After = laReducer;
  cbAfter.OnChange := @AfterChange;
  cbNewSize.OnChange := @AfterChange;
  lblStatus.Caption := Format('Leg %d, %s: type its length and press Enter.', [I + 1, DirName(FLegs[I].Dir)]);
  edLen.SetFocus;
  edLen.SelectAll;
  Refresh;
end;

procedure TSpoolForm.btnLegClick(Sender: TObject);
var
  V: Double;
begin
  if (FSel < 0) or (FSel > High(FLegs)) then
  begin
    lblStatus.Caption := 'Click where a leg ends first, or click a leg, then give its length.';
    Exit;
  end;
  if not InchesOf(edLen.Text, V) or (V <= 0) then
  begin
    lblStatus.Caption := 'The length did not read - 24, 30.5, 2''6".';
    Exit;
  end;
  FLegs[FSel].Len := V;
  FLegs[FSel].Has := True;
  FLegs[FSel].FromEnd := cbMeasure.ItemIndex in [1, 3];
  FLegs[FSel].ToEnd := cbMeasure.ItemIndex in [2, 3];
  lblStatus.Caption := Format('Leg %d: %s, %s %s.  Click where the next one ends, or Build it.',
    [FSel + 1, DirName(FLegs[FSel].Dir), edLen.Text + '"', cbMeasure.Text]);
  if FSel = High(FLegs) then
  begin
    FSel := -1;
    edLen.Text := '';
  end;
  Refresh;
end;

procedure TSpoolForm.edLenKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then
  begin
    Key := #0;
    btnLegClick(nil);
  end;
end;

procedure TSpoolForm.btnUndoClick(Sender: TObject);
var
  K, Which: Integer;
begin
  if Length(FLegs) = 0 then Exit;
  if (FSel >= 0) and (FSel <= High(FLegs)) then Which := FSel else Which := High(FLegs);
  for K := Which to High(FLegs) - 1 do
  begin
    FLegs[K] := FLegs[K + 1];
    FAdv[K] := FAdv[K + 1];
  end;
  SetLength(FLegs, Length(FLegs) - 1);
  SetLength(FAdv, Length(FAdv) - 1);
  FSel := -1;
  edLen.Text := '';
  lblStatus.Caption := Format('Leg %d taken off.', [Which + 1]);
  Refresh;
end;

procedure TSpoolForm.PaintSketch(C: TCanvas; W, H: Integer);
var
  I, J, K: Integer;
  O, A, B, M: TPoint;
  Node: TP3;
  S: string;
  Sz: TSize;

  procedure Label_(const A, B: TPoint; const Txt: string; Faint: Boolean);
  begin
    M := Point((A.X + B.X) div 2, (A.Y + B.Y) div 2);
    Sz := C.TextExtent(Txt);
    C.Brush.Style := bsSolid;
    C.Brush.Color := clWhite;
    if Faint then C.Font.Color := clGray else C.Font.Color := $00602000;
    C.TextOut(M.X - Sz.cx div 2 + 10, M.Y - Sz.cy div 2 - 10, Txt);
    C.Brush.Style := bsClear;
  end;

  procedure EndWord(const P: TPoint; E: Integer; AtStart: Boolean);
  const
    Short: array[TPipeEnd] of string = ('bevel', 'FLANGE', 'CAP', 'thread');
  var
    T: string;
  begin
    T := Short[TPipeEnd(E)];
    if AtStart then T := 'start, ' + T;
    C.Font.Color := clGray;
    C.TextOut(P.X + 8, P.Y + 6, T);
  end;

begin
  C.Brush.Color := clWhite;
  C.FillRect(0, 0, W, H);
  O := Origin;
  if cbLines.Checked then
  begin
    { iso paper: light lines along the three axes through every lattice
      point, the way the printed sheet is ruled }
    C.Pen.Color := $00E4E4E4;
    for I := -80 to 80 do
    begin
      A := Scr(P3(I, -80, 0)); B := Scr(P3(I, 80, 0)); C.Line(A.X, A.Y, B.X, B.Y);
      A := Scr(P3(-80, I, 0)); B := Scr(P3(80, I, 0)); C.Line(A.X, A.Y, B.X, B.Y);
      A := Scr(P3(I, -I, -80)); B := Scr(P3(I, -I, 80)); C.Line(A.X, A.Y, B.X, B.Y);
    end;
  end
  else
    for I := -60 to 60 do
      for J := -60 to 60 do
      begin
        A := Scr(P3(I, J, 0));
        if (A.X < 0) or (A.X >= W) or (A.Y < 0) or (A.Y >= H) then Continue;
        C.Pixels[A.X, A.Y] := $00B8B8B8;
        C.Pixels[A.X + 1, A.Y] := $00D8D8D8;
      end;
  { the three axes off the start, faintly, so the paper says which way is up }
  C.Pen.Color := $00E0C8C8; C.Line(O.X, O.Y, Scr(P3(3, 0, 0)).X, Scr(P3(3, 0, 0)).Y);
  C.Pen.Color := $00C8E0C8; C.Line(O.X, O.Y, Scr(P3(0, 3, 0)).X, Scr(P3(0, 3, 0)).Y);
  C.Pen.Color := $00E0C8C8; C.Pen.Color := $00F0C0C0;
  C.Pen.Color := $00F0D0D0; C.Line(O.X, O.Y, Scr(P3(0, 0, 3)).X, Scr(P3(0, 0, 3)).Y);
  { the legs }
  Node := P3(0, 0, 0);
  C.Font.Size := 10;
  for I := 0 to High(FLegs) do
  begin
    A := Scr(Node);
    Node := P3(Node.X + FAdv[I].X * FLegs[I].Steps, Node.Y + FAdv[I].Y * FLegs[I].Steps,
               Node.Z + FAdv[I].Z * FLegs[I].Steps);
    B := Scr(Node);
    if I = FSel then C.Pen.Color := $000080FF else C.Pen.Color := $00A05020;
    if I = FSel then C.Pen.Width := 5 else C.Pen.Width := 3;
    C.Line(A.X, A.Y, B.X, B.Y);
    C.Pen.Width := 1;
    C.Brush.Color := $00A05020;
    C.Brush.Style := bsSolid;
    C.Ellipse(A.X - 3, A.Y - 3, A.X + 4, A.Y + 4);
    C.Ellipse(B.X - 3, B.Y - 3, B.X + 4, B.Y + 4);
    if FLegs[I].Has then
    begin
      S := FormatFloat('0.###', FLegs[I].Len * 12) + '"';
      if FLegs[I].FromEnd or FLegs[I].ToEnd then
        S := S + ' ' + StringReplace(StringReplace(MeasureWords(SpecOf, I), 'center', 'c', [rfReplaceAll]), ' to ', '-', []);
      Label_(A, B, S, False);
    end
    else
      Label_(A, B, '?', False);
    if I = 0 then EndWord(A, cbEnd0.ItemIndex, True);
    if I = High(FLegs) then EndWord(B, cbEnd1.ItemIndex, False);
    { a reducer is a wedge near the far end, a flanged joint two bars }
    if FLegs[I].After = laReducer then
    begin
      C.Pen.Color := $00A05020;
      C.Brush.Style := bsClear;
      C.Polygon([Point(B.X - (B.X - A.X) div 5 - 6, B.Y - (B.Y - A.Y) div 5 - 6),
                 Point(B.X - (B.X - A.X) div 5 + 6, B.Y - (B.Y - A.Y) div 5 + 6),
                 Point(B.X - (B.X - A.X) div 10 + 3, B.Y - (B.Y - A.Y) div 10 + 3),
                 Point(B.X - (B.X - A.X) div 10 - 3, B.Y - (B.Y - A.Y) div 10 - 3)]);
      C.Font.Color := clGray;
      C.TextOut(B.X - (B.X - A.X) div 6 + 8, B.Y - (B.Y - A.Y) div 6 + 8,
        'red. ' + NPS_NAMES[EnsureRange(FLegs[I].NewSize, 0, High(NPS_NAMES))]);
    end
    else if FLegs[I].After = laFlanges then
    begin
      C.Pen.Color := $00A05020;
      C.Pen.Width := 3;
      C.Line(B.X - 7, B.Y - 6, B.X + 7, B.Y + 6);
      C.Line(B.X - 7 - 5, B.Y - 6 + 3, B.X + 7 - 5, B.Y + 6 + 3);
      C.Pen.Width := 1;
      C.Font.Color := clGray;
      C.TextOut(B.X + 10, B.Y - 22, 'flanges');
    end;
  end;
  if Length(FLegs) = 0 then
  begin
    C.Brush.Color := $00A05020;
    C.Brush.Style := bsSolid;
    C.Ellipse(O.X - 3, O.Y - 3, O.X + 4, O.Y + 4);
    C.Brush.Style := bsClear;
    C.Font.Color := clGray;
    C.TextOut(O.X + 8, O.Y + 6, 'start');
  end;
  { the leg the cursor would make }
  if FHover then
  begin
    A := Scr(Node);
    B := Scr(P3(Node.X + FHoverAdv.X * FHoverSteps, Node.Y + FHoverAdv.Y * FHoverSteps,
                Node.Z + FHoverAdv.Z * FHoverSteps));
    C.Pen.Color := $00F09040;
    C.Pen.Style := psDash;
    C.Pen.Width := 2;
    C.Line(A.X, A.Y, B.X, B.Y);
    C.Pen.Style := psSolid;
    C.Pen.Width := 1;
    C.Brush.Color := $00F09040;
    C.Brush.Style := bsSolid;
    C.Ellipse(B.X - 4, B.Y - 4, B.X + 5, B.Y + 5);
    C.Brush.Style := bsClear;
    Label_(A, B, DirName(FHoverAdv) + ', ' + IntToStr(FHoverSteps) + ' steps', True);
  end;
  C.Brush.Style := bsClear;
  C.Font.Color := clGray;
  C.TextOut(8, H - 20, 'iso paper - not to scale; the numbers are the drawing.  Shift for a 45.  Click a leg to change its length.');
end;

procedure TSpoolForm.pbSketchPaint(Sender: TObject);
begin
  PaintSketch(pbSketch.Canvas, pbSketch.Width, pbSketch.Height);
end;

procedure TSpoolForm.Paint3D(C: TCanvas; W, H: Integer);
var
  S: TSpoolSpec;
  D: TWorkDoc;
begin
  C.Brush.Color := clWhite;
  C.FillRect(0, 0, W, H);
  C.Pen.Color := clSilver;
  C.Rectangle(0, 0, W, H);
  Read(S);
  if SpoolProblem(S) <> '' then
  begin
    C.Font.Color := clGray;
    C.TextOut(16, 16, 'The 3D view needs a length on every leg: ' + SpoolProblem(S));
    Exit;
  end;
  S.Dims := False;
  D := TWorkDoc.Create;
  try
    BuildSpool(D, S, clBlack, 1);
    PaintDocIso(C, W, H, D, S.Tag, 'start at the front left');
  finally
    D.Free;
  end;
end;

procedure TSpoolForm.pb3DPaint(Sender: TObject);
begin
  Paint3D(pb3D.Canvas, pb3D.Width, pb3D.Height);
end;

procedure TSpoolForm.btnReportClick(Sender: TObject);
var
  S: TSpoolSpec;
begin
  Read(S);
  MainForm.ReportFromDialog('Fitter''s scratchpad', SpoolTicket(S) + LineEnding +
    'problem shown: ' + memTicket.Text);
end;

function TSpoolForm.ExportFiles(out Dir: string; out Files: TStringArray): Boolean;
var
  S: TSpoolSpec;
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
      if Iso then Paint3D(Bmp.Canvas, Bmp.Width, Bmp.Height)
      else PaintSketch(Bmp.Canvas, Bmp.Width, Bmp.Height);
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
  Read(S);
  if Length(S.Legs) = 0 then Exit;
  Dir := IncludeTrailingPathDelimiter(GetUserDir) + 'Heckers Sketch' + PathDelim +
    'fittings' + PathDelim;
  if not ForceDirectories(Dir) then Exit;
  Name_ := S.Tag;
  for I := 1 to Length(Name_) do
    if not (Name_[I] in ['A'..'Z', 'a'..'z', '0'..'9', '-', '_']) then Name_[I] := '_';
  if Name_ = '' then Name_ := 'spool';
  Base := Dir + Name_ + '-' + FormatDateTime('yyyymmdd-hhnnss', Now);
  { the iso always; the corner view only when there is one to draw }
  SetLength(Files, 3);
  Files[0] := Base + '-iso.png';
  Files[1] := Base + '-3d.png';
  Files[2] := Base + '.txt';
  Picture(Files[0], False);
  if SpoolProblem(S) = '' then Picture(Files[1], True)
  else
  begin
    Files[1] := Files[2];
    SetLength(Files, 2);
    Files[1] := Base + '.txt';
  end;
  L := TStringList.Create;
  try
    L.Text := SpoolTicket(S) + LineEnding + 'Drawn with Heckers Sketch, ' +
      FormatDateTime('yyyy-mm-dd hh:nn', Now);
    L.SaveToFile(Files[High(Files)]);
  finally
    L.Free;
  end;
  Result := True;
end;

procedure TSpoolForm.btnEmailClick(Sender: TObject);
var
  S: TSpoolSpec;
  Dir, Err, Subject: string;
  Files: TStringArray;
begin
  Read(S);
  if Length(S.Legs) = 0 then Exit;
  if not ExportFiles(Dir, Files) then
  begin
    ShowMessage('The pictures could not be written under ' + Dir);
    Exit;
  end;
  Subject := 'Pipe spool';
  if not SketchComplete(S) then Subject := 'Pipe spool sketch';
  if S.Tag <> '' then Subject := Subject + ' ' + S.Tag;
  Subject := Subject + ': ' + NPS_NAMES[S.Size] + ' with ' + IntToStr(Length(S.Legs)) + ' legs';
  if SendByEmail(Subject, SpoolTicket(S), Files, Err) then
    lblStatus.Caption := 'Handed to your mail program.  The files are in ' + Dir
  else
  begin
    ShowMessage(Err + LineEnding + LineEnding + 'The iso, the corner view and the ticket ' +
      'are in ' + Dir + ' - attach them by hand.');
    SelectInFolder(Files[0]);
  end;
end;

procedure TSpoolForm.btnFilesClick(Sender: TObject);
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
    lblStatus.Caption := 'The iso, the corner view and the ticket are in ' + Dir
  else
    ShowMessage('The iso, the corner view and the ticket are in ' + Dir);
end;

class function TSpoolForm.Ask(Units: TUnitSystem; out Spec: TSpoolSpec): Boolean;
var
  F: TSpoolForm;
begin
  Result := False;
  F := TSpoolForm.Create(nil);
  try
    F.FUnits := Units;
    F.Refresh;
    if F.ShowModal <> mrOK then Exit;
    Result := F.Read(Spec) and (SpoolProblem(Spec) = '');
  finally
    F.Free;
  end;
end;

end.
