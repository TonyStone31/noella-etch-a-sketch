unit uRadiantDlg;

{ The radiant heat layout wizard: given the outline of the floor it is
  asked to fill - the selection's own corners, and its holes as the real
  obstacles already cut into it - it asks the standard things a design
  wants, works the layout out live as they are typed, and shows the plan
  and the material list beside the numbers.

  The manifold is placed at one of the outline's own corners, in from it
  along each of the two edges that meet there - the way a real one sits
  tucked in a corner of the room, not floating free.  A true "click the
  spot on the sheet" picker wants the wizard to run alongside the sheet
  rather than in front of it, the way the source window does; that is
  the next step, not this one. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, StdCtrls, ExtCtrls, Graphics,
  ComCtrls, Dialogs, uWork, uRadiantData, uRadiant;

type

  { TRadiantForm }

  TRadiantForm = class(TForm)
    btnBuild: TButton;
    btnCancel: TButton;
    btnReport: TButton;
    cbCorner: TComboBox;
    cbPlates: TCheckBox;
    cbTube: TComboBox;
    edBelowR: TEdit;
    edInAcross: TEdit;
    edInAlong: TEdit;
    edJoist: TEdit;
    edMaxLoop: TEdit;
    edSlabThick: TEdit;
    edSpacing: TEdit;
    edSubfloor: TEdit;
    edTag: TEdit;
    edTubeDepth: TEdit;
    edUnderR: TEdit;
    edWaste: TEdit;
    lblBelowR: TLabel;
    lblCorner: TLabel;
    lblInAcross: TLabel;
    lblInAlong: TLabel;
    lblJoist: TLabel;
    lblJoistHead: TLabel;
    lblManifoldHead: TLabel;
    lblMaxLoop: TLabel;
    lblMaxLoopHint: TLabel;
    lblProblem: TLabel;
    lblSlabHead: TLabel;
    lblSlabThick: TLabel;
    lblSpacing: TLabel;
    lblSpacingIn: TLabel;
    lblSubfloor: TLabel;
    lblTag: TLabel;
    lblTagHint: TLabel;
    lblTicket: TLabel;
    lblTitle: TLabel;
    lblTube: TLabel;
    lblTubeDepth: TLabel;
    lblTubeDepthHint: TLabel;
    lblUnderR: TLabel;
    lblUnits: TLabel;
    lblWaste: TLabel;
    lblWastePct: TLabel;
    memTicket: TMemo;
    pbPlan: TPaintBox;
    pcRight: TPageControl;
    rgFloor: TRadioGroup;
    tsPlan: TTabSheet;
    procedure AnyChange(Sender: TObject);
    procedure btnReportClick(Sender: TObject);
    procedure FloorChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure pbPlanPaint(Sender: TObject);
  private
    FUnits: TUnitSystem;
    FOutline: TP3Array;
    FHoles: array of TP3Array;
    { every hole plus, while a mark is being tried, one more that is not
      written to the drawing unless Build is pressed with it still there -
      the circle-it-and-reroute idea: a temporary obstacle }
    FLayout: TRadiantResult;
    procedure ShowFloorKind;
    procedure Recompute;
    function Read(out Spec: TRadiantSpec): Boolean;
  public
    class function Ask(Units: TUnitSystem; const Outline: TP3Array;
      const Holes: array of TP3Array; out Spec: TRadiantSpec): Boolean;
  end;

implementation

{$R *.lfm}

uses
  uMain;

function InchesOf(const S: string; U: TUnitSystem; Inch: Double; out V: Double): Boolean;
var
  T: string;
  F: Double;
begin
  T := Trim(S);
  V := 0;
  if T = '' then Exit(False);
  if (Pos('''', T) > 0) or (Pos('"', T) > 0) or (Pos('m', LowerCase(T)) > 0) then
    Result := ParseLen(T, U, V)
  else
  begin
    Result := ParseLen(T + '"', usImperial, F);
    if Result then V := F;
  end;
end;

procedure TRadiantForm.FormCreate(Sender: TObject);
var
  S: TTubeSize;
begin
  for S := Low(TTubeSize) to High(TTubeSize) do cbTube.Items.Add(TUBE_NAMES[S]);
  cbTube.ItemIndex := Ord(tsHalf);
  ShowFloorKind;
end;

procedure TRadiantForm.ShowFloorKind;
var
  Slab: Boolean;
begin
  Slab := rgFloor.ItemIndex = 0;
  lblSlabHead.Visible := Slab;
  lblSlabThick.Visible := Slab; edSlabThick.Visible := Slab;
  lblTubeDepth.Visible := Slab; edTubeDepth.Visible := Slab; lblTubeDepthHint.Visible := Slab;
  lblUnderR.Visible := Slab; edUnderR.Visible := Slab;
  lblJoistHead.Visible := not Slab;
  lblJoist.Visible := not Slab; edJoist.Visible := not Slab;
  cbPlates.Visible := not Slab;
  lblSubfloor.Visible := not Slab; edSubfloor.Visible := not Slab;
  lblBelowR.Visible := not Slab; edBelowR.Visible := not Slab;
end;

procedure TRadiantForm.FloorChange(Sender: TObject);
begin
  ShowFloorKind;
  AnyChange(nil);
end;

procedure TRadiantForm.FormShow(Sender: TObject);
var
  I: Integer;
begin
  cbCorner.Items.Clear;
  for I := 0 to High(FOutline) do
    cbCorner.Items.Add(Format('corner %d of %d', [I + 1, Length(FOutline)]));
  if cbCorner.Items.Count > 0 then cbCorner.ItemIndex := 0;
  AnyChange(nil);
end;

function TRadiantForm.Read(out Spec: TRadiantSpec): Boolean;
begin
  Spec := DefaultRadiantSpec;
  Spec.Floor := TRadiantFloor(Max(0, rgFloor.ItemIndex));
  Spec.Tube := TTubeSize(Max(0, cbTube.ItemIndex));
  Result := InchesOf(edSpacing.Text, usImperial, Spec.Inch, Spec.Spacing);
  if Trim(edMaxLoop.Text) = '' then Spec.MaxLoopFt := 0
  else Result := Result and InchesOf(edMaxLoop.Text + '''', usImperial, Spec.Inch, Spec.MaxLoopFt);
  Result := Result and TryStrToFloat(Trim(edWaste.Text), Spec.WastePct);
  Spec.Corner := Max(0, cbCorner.ItemIndex);
  Result := Result and InchesOf(edInAlong.Text, usImperial, Spec.Inch, Spec.InAlong);
  Result := Result and InchesOf(edInAcross.Text, usImperial, Spec.Inch, Spec.InAcross);
  if Spec.Floor = rfSlab then
  begin
    Result := Result and InchesOf(edSlabThick.Text, usImperial, Spec.Inch, Spec.SlabThick);
    if Trim(edTubeDepth.Text) = '' then Spec.TubeDepth := 0
    else Result := Result and InchesOf(edTubeDepth.Text, usImperial, Spec.Inch, Spec.TubeDepth);
    Result := Result and TryStrToFloat(Trim(edUnderR.Text), Spec.UnderR);
  end
  else
  begin
    Result := Result and InchesOf(edJoist.Text, usImperial, Spec.Inch, Spec.JoistSpacing);
    Spec.Plates := cbPlates.Checked;
    Result := Result and InchesOf(edSubfloor.Text, usImperial, Spec.Inch, Spec.SubfloorThick);
    Result := Result and TryStrToFloat(Trim(edBelowR.Text), Spec.BelowR);
  end;
  Spec.Tag := Trim(edTag.Text);
end;

procedure TRadiantForm.Recompute;
var
  Spec: TRadiantSpec;
  M: TP3;
begin
  if not Read(Spec) then
  begin
    lblProblem.Caption := 'A size did not read - 9, 9.5, or a foot mark.';
    memTicket.Lines.Text := '';
    FLayout.Ok := False;
    pbPlan.Invalidate;
    Exit;
  end;
  if Length(FOutline) < 3 then
  begin
    lblProblem.Caption := 'Nothing is selected to fill - select a face and run this again.';
    memTicket.Lines.Text := '';
    FLayout.Ok := False;
    pbPlan.Invalidate;
    Exit;
  end;
  lblProblem.Caption := RadiantProblem(FOutline, Spec);
  if lblProblem.Caption <> '' then
  begin
    memTicket.Lines.Text := '';
    FLayout.Ok := False;
    pbPlan.Invalidate;
    Exit;
  end;
  M := RadiantManifoldPoint(FOutline, Spec);
  FLayout := ComputeRadiantLayout(FOutline, FHoles, M, Spec);
  if not FLayout.Ok then lblProblem.Caption := FLayout.Why;
  memTicket.Lines.Text := RadiantTicketText(Spec, FLayout, FUnits);
  btnBuild.Enabled := FLayout.Ok;
  pbPlan.Invalidate;
end;

procedure TRadiantForm.AnyChange(Sender: TObject);
begin
  edMaxLoop.Enabled := True;
  Recompute;
end;

procedure TRadiantForm.btnReportClick(Sender: TObject);
begin
  MainForm.ReportFromDialog('Radiant heat layout',
    'floor: ' + rgFloor.Items[Max(0, rgFloor.ItemIndex)] + LineEnding +
    'tube: ' + cbTube.Text + ', spacing ' + edSpacing.Text + LineEnding +
    'corner: ' + cbCorner.Text + ', in ' + edInAlong.Text + ' / ' + edInAcross.Text + LineEnding +
    'problem shown: ' + lblProblem.Caption);
end;

{ The plan: the outline, its holes shaded, and every loop in its own
  color so a long run is easy to follow by eye.  Its own small screen
  projection, worked out here rather than shared with uRadiant's - that
  one is the build's own geometry and never leaves the unit; this one
  only ever has to turn a point into a pixel, the way PaintIso keeps its
  own PX/PY rather than reaching for another unit's. }
procedure TRadiantForm.pbPlanPaint(Sender: TObject);
const
  LOOP_COLORS: array[0..5] of TColor = (clRed, clBlue, clGreen, $00A0A0, $00A000A0, $00008080);
type
  TPtArr = array of TPoint;
var
  C: TCanvas;
  W, H, Margin, I, J: Integer;
  MinX, MaxX, MinY, MaxY, Sc: Double;
  Org, Ax, Ay, Nm: TP3;

  function VLen(const P: TP3): Double;
  begin
    Result := Sqrt(P.X * P.X + P.Y * P.Y + P.Z * P.Z);
  end;

  function SX(const P: TP3): Double;
  begin
    Result := (P.X - Org.X) * Ax.X + (P.Y - Org.Y) * Ax.Y + (P.Z - Org.Z) * Ax.Z;
  end;

  function SY(const P: TP3): Double;
  begin
    Result := (P.X - Org.X) * Ay.X + (P.Y - Org.Y) * Ay.Y + (P.Z - Org.Z) * Ay.Z;
  end;

  function PX(const P: TP3): Integer; begin Result := Round(Margin + (SX(P) - MinX) * Sc); end;
  function PY(const P: TP3): Integer; begin Result := Round(H - Margin - (SY(P) - MinY) * Sc); end;

  function Poly(const Pts: TP3Array): TPtArr;
  var
    K: Integer;
  begin
    SetLength(Result, Length(Pts));
    for K := 0 to High(Pts) do Result[K] := Point(PX(Pts[K]), PY(Pts[K]));
  end;

begin
  C := pbPlan.Canvas;
  W := pbPlan.Width; H := pbPlan.Height;
  C.Brush.Color := clWhite;
  C.FillRect(0, 0, W, H);
  C.Pen.Color := clSilver;
  C.Rectangle(0, 0, W, H);
  if Length(FOutline) < 3 then Exit;
  { the outline's own plane by Newell's method, its longest edge across
    the page }
  Nm := P3(0, 0, 0);
  for I := 0 to High(FOutline) do
  begin
    J := (I + 1) mod Length(FOutline);
    Nm.X := Nm.X + (FOutline[I].Y - FOutline[J].Y) * (FOutline[I].Z + FOutline[J].Z);
    Nm.Y := Nm.Y + (FOutline[I].Z - FOutline[J].Z) * (FOutline[I].X + FOutline[J].X);
    Nm.Z := Nm.Z + (FOutline[I].X - FOutline[J].X) * (FOutline[I].Y + FOutline[J].Y);
  end;
  if VLen(Nm) < 1E-9 then Nm := P3(0, 0, 1) else Nm := P3(Nm.X / VLen(Nm), Nm.Y / VLen(Nm), Nm.Z / VLen(Nm));
  Org := FOutline[0];
  Ax := P3(FOutline[1].X - FOutline[0].X, FOutline[1].Y - FOutline[0].Y, FOutline[1].Z - FOutline[0].Z);
  if VLen(Ax) < 1E-9 then Ax := P3(1, 0, 0) else Ax := P3(Ax.X / VLen(Ax), Ax.Y / VLen(Ax), Ax.Z / VLen(Ax));
  Ay := Cross3(Nm, Ax);
  if VLen(Ay) > 1E-9 then Ay := P3(Ay.X / VLen(Ay), Ay.Y / VLen(Ay), Ay.Z / VLen(Ay));

  Margin := 30;
  MinX := 1E30; MaxX := -1E30; MinY := 1E30; MaxY := -1E30;
  for I := 0 to High(FOutline) do
  begin
    MinX := Min(MinX, SX(FOutline[I])); MaxX := Max(MaxX, SX(FOutline[I]));
    MinY := Min(MinY, SY(FOutline[I])); MaxY := Max(MaxY, SY(FOutline[I]));
  end;
  Sc := Min((W - 2 * Margin) / Max(MaxX - MinX, 1E-6), (H - 2 * Margin) / Max(MaxY - MinY, 1E-6));

  C.Pen.Color := clBlack; C.Pen.Width := 2; C.Brush.Style := bsClear;
  C.Polygon(Poly(FOutline));
  C.Pen.Width := 1;
  C.Brush.Style := bsSolid; C.Brush.Color := $00D0D0D0;
  for I := 0 to High(FHoles) do
    if Length(FHoles[I]) >= 3 then C.Polygon(Poly(FHoles[I]));
  C.Brush.Style := bsClear;
  if FLayout.Ok then
    for I := 0 to High(FLayout.Loops) do
    begin
      C.Pen.Color := LOOP_COLORS[I mod Length(LOOP_COLORS)];
      C.Pen.Width := 2;
      for J := 1 to High(FLayout.Loops[I].Pts) do
      begin
        C.MoveTo(PX(FLayout.Loops[I].Pts[J - 1]), PY(FLayout.Loops[I].Pts[J - 1]));
        C.LineTo(PX(FLayout.Loops[I].Pts[J]), PY(FLayout.Loops[I].Pts[J]));
      end;
    end;
  C.Pen.Width := 1;
  C.Font.Color := clGray;
  if not FLayout.Ok then C.TextOut(8, H - 20, 'not yet a valid layout')
  else C.TextOut(8, H - 20, Format('%d loop(s), %d row(s)', [Length(FLayout.Loops), FLayout.RowCount]));
end;

class function TRadiantForm.Ask(Units: TUnitSystem; const Outline: TP3Array;
  const Holes: array of TP3Array; out Spec: TRadiantSpec): Boolean;
var
  F: TRadiantForm;
  I: Integer;
begin
  Result := False;
  F := TRadiantForm.Create(nil);
  try
    F.FUnits := Units;
    F.FOutline := Outline;
    SetLength(F.FHoles, Length(Holes));
    for I := 0 to High(Holes) do F.FHoles[I] := Holes[I];
    if F.ShowModal <> mrOK then Exit;
    Result := F.Read(Spec) and (RadiantProblem(Outline, Spec) = '');
  finally
    F.Free;
  end;
end;

end.
