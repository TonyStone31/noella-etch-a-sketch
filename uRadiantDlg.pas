unit uRadiantDlg;

{ The radiant heat layout wizard: given the outline of the floor it is
  asked to fill - the selection's own corners, and its holes as the real
  obstacles already cut into it - it asks the standard things a design
  wants, works the layout out live as they are typed, and shows the plan
  and the material list beside the numbers.

  The moment it opens it says how many loops the floor wants and puts as
  many manifolds as that takes along the long wall, sized to suit; from
  there the manifolds and any obstacle added here are dragged about on
  the plan, and the layout follows the hand.  A true "click the spot on
  the sheet" picker wants the wizard to run alongside the sheet rather
  than in front of it, the way the source window does; that is the next
  step, not this one - dragging on the plan is most of it. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, StdCtrls, ExtCtrls, Graphics,
  ComCtrls, Dialogs, StrUtils, uWork, uRadiantData, uRadiant;

type

  { TRadiantForm }

  TRadiantForm = class(TForm)
    btnAddManifold: TButton;
    btnAddObstacle: TButton;
    btnBuild: TButton;
    btnCancel: TButton;
    btnRemoveManifold: TButton;
    btnRemoveObstacle: TButton;
    btnReport: TButton;
    btnSuggest: TButton;
    cbPlates: TCheckBox;
    cbPorts: TComboBox;
    cbRunsPerBay: TComboBox;
    cbTube: TComboBox;
    edBelowR: TEdit;
    edJoist: TEdit;
    edMaxLoop: TEdit;
    edObsH: TEdit;
    edObsW: TEdit;
    edSlabThick: TEdit;
    edSpacing: TEdit;
    edSubfloor: TEdit;
    edTag: TEdit;
    edTubeDepth: TEdit;
    edUnderR: TEdit;
    edWaste: TEdit;
    lbManifolds: TListBox;
    lblBelowR: TLabel;
    lblJoist: TLabel;
    lblJoistHead: TLabel;
    lblManifoldHead: TLabel;
    lblMaxLoop: TLabel;
    lblMaxLoopHint: TLabel;
    lblNeed: TLabel;
    lblObsHead: TLabel;
    lblObsX: TLabel;
    lblPorts: TLabel;
    lblProblem: TLabel;
    lblRunsPerBay: TLabel;
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
    lbObstacles: TListBox;
    memTicket: TMemo;
    pbPlan: TPaintBox;
    pcRight: TPageControl;
    rgFloor: TRadioGroup;
    tsPlan: TTabSheet;
    procedure AnyChange(Sender: TObject);
    procedure btnAddManifoldClick(Sender: TObject);
    procedure btnAddObstacleClick(Sender: TObject);
    procedure btnRemoveManifoldClick(Sender: TObject);
    procedure btnRemoveObstacleClick(Sender: TObject);
    procedure btnReportClick(Sender: TObject);
    procedure btnSuggestClick(Sender: TObject);
    procedure cbPortsChange(Sender: TObject);
    procedure FloorChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure lbManifoldsClick(Sender: TObject);
    procedure lbObstaclesClick(Sender: TObject);
    procedure pbPlanMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure pbPlanMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbPlanMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure pbPlanPaint(Sender: TObject);
  private
    FUnits: TUnitSystem;
    FOutline: TP3Array;
    FHoles: array of TP3Array;       { the face's own }
    FExtra: array of TP3Array;       { added here, as rectangles }
    FManifolds: TP3Array;
    FPorts: TIntArray;
    FLayout: TRadiantResult;
    { the plan's own projection, worked out at paint time and kept for the
      mouse: the outline's frame, and how its plane maps to pixels }
    FFrame: TRadiantFrame;
    FMinX, FMinY, FSc: Double;
    FMargin: Integer;
    { what is being dragged on the plan: a manifold (0..), an obstacle
      (0..) or nothing }
    FDragManifold, FDragObstacle: Integer;
    FDragOff: T2;
    FListing, FSelectLast: Boolean;
    procedure ShowFloorKind;
    procedure Recompute;
    function Read(out Spec: TRadiantSpec): Boolean;
    function AllHoles: TRadiantHoles;
    procedure ListManifolds;
    procedure ListObstacles;
    function PlanX(U: Double): Integer;
    function PlanY(V: Double): Integer;
    function PlanU(X: Integer): Double;
    function PlanV(Y: Integer): Double;
    procedure MoveObstacle(I: Integer; const ToMid: T2);
    function ObstacleMid(I: Integer): T2;
  public
    class function Ask(Units: TUnitSystem; const Outline: TP3Array;
      const Holes: array of TP3Array; out Spec: TRadiantSpec): Boolean;
  end;

implementation

{$R *.lfm}

uses
  uMain;

{ A bare number is inches - the trade says 9, not 9" - and a mark makes it
  the drawing's own notation, the same rule the fitting wizard keeps. }
function InchesOf(const S: string; U: TUnitSystem; out V: Double): Boolean;
var
  T: string;
begin
  T := Trim(S);
  V := 0;
  if T = '' then Exit(False);
  if (Pos('''', T) > 0) or (Pos('"', T) > 0) or (Pos('m', LowerCase(T)) > 0) then
    Result := ParseLen(T, U, V)
  else
    Result := ParseLen(T + '"', usImperial, V);
end;

{ A bare number here is feet - a loop is 300, not 300" }
function FeetOf(const S: string; U: TUnitSystem; out V: Double): Boolean;
var
  T: string;
begin
  T := Trim(S);
  V := 0;
  if T = '' then Exit(False);
  if (Pos('''', T) > 0) or (Pos('"', T) > 0) or (Pos('m', LowerCase(T)) > 0) then
    Result := ParseLen(T, U, V)
  else
    Result := ParseLen(T + '''', usImperial, V);
end;

procedure TRadiantForm.FormCreate(Sender: TObject);
var
  S: TTubeSize;
  I: Integer;
begin
  for S := Low(TTubeSize) to High(TTubeSize) do cbTube.Items.Add(TUBE_NAMES[S]);
  cbTube.ItemIndex := Ord(tsHalf);
  cbRunsPerBay.Items.Add('1 run per bay');
  cbRunsPerBay.Items.Add('2 runs per bay');
  cbRunsPerBay.Items.Add('3 runs per bay');
  cbRunsPerBay.Items.Add('4 runs per bay');
  cbRunsPerBay.ItemIndex := RUNS_PER_BAY_DEFAULT - 1;
  for I := MANIFOLD_PORTS_MIN to MANIFOLD_PORTS_MAX do cbPorts.Items.Add(Format('%d-loop', [I]));
  FDragManifold := -1;
  FDragObstacle := -1;
  ShowFloorKind;
end;

procedure TRadiantForm.ShowFloorKind;
var
  Slab: Boolean;
begin
  Slab := rgFloor.ItemIndex = 0;
  { the spacing is typed on a slab; on a wood floor it follows the joists }
  edSpacing.Enabled := Slab;
  lblRunsPerBay.Visible := not Slab; cbRunsPerBay.Visible := not Slab;
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
begin
  { right off: what this floor wants, and a manifold or several to suit,
    where a manifold goes - on a wall.  To be dragged from there. }
  if Length(FManifolds) = 0 then btnSuggestClick(nil)
  else AnyChange(nil);
end;

function TRadiantForm.AllHoles: TRadiantHoles;
var
  I: Integer;
begin
  SetLength(Result, Length(FHoles) + Length(FExtra));
  for I := 0 to High(FHoles) do Result[I] := FHoles[I];
  for I := 0 to High(FExtra) do Result[Length(FHoles) + I] := FExtra[I];
end;

function TRadiantForm.Read(out Spec: TRadiantSpec): Boolean;
var
  I: Integer;
begin
  Spec := DefaultRadiantSpec;
  Spec.Floor := TRadiantFloor(Max(0, rgFloor.ItemIndex));
  Spec.Tube := TTubeSize(Max(0, cbTube.ItemIndex));
  Result := InchesOf(edSpacing.Text, FUnits, Spec.Spacing);
  if Trim(edMaxLoop.Text) = '' then Spec.MaxLoopFt := 0
  else Result := Result and FeetOf(edMaxLoop.Text, FUnits, Spec.MaxLoopFt);
  Result := Result and TryStrToFloat(Trim(edWaste.Text), Spec.WastePct);
  if Spec.Floor = rfSlab then
  begin
    Result := Result and InchesOf(edSlabThick.Text, FUnits, Spec.SlabThick);
    if Trim(edTubeDepth.Text) = '' then Spec.TubeDepth := 0
    else Result := Result and InchesOf(edTubeDepth.Text, FUnits, Spec.TubeDepth);
    Result := Result and TryStrToFloat(Trim(edUnderR.Text), Spec.UnderR);
  end
  else
  begin
    Result := Result and InchesOf(edJoist.Text, FUnits, Spec.JoistSpacing);
    Spec.RunsPerBay := Max(1, cbRunsPerBay.ItemIndex + 1);
    { on a wood floor the tube runs along the joist bays, so the spacing
      is the bay's width over the runs in it - not typed }
    if Spec.RunsPerBay > 0 then Spec.Spacing := Spec.JoistSpacing / Spec.RunsPerBay;
    Spec.Plates := cbPlates.Checked;
    Result := Result and InchesOf(edSubfloor.Text, FUnits, Spec.SubfloorThick);
    Result := Result and TryStrToFloat(Trim(edBelowR.Text), Spec.BelowR);
  end;
  Spec.Manifolds := Copy(FManifolds);
  Spec.Ports := Copy(FPorts);
  SetLength(Spec.Extra, Length(FExtra));
  for I := 0 to High(FExtra) do Spec.Extra[I] := Copy(FExtra[I]);
  Spec.Tag := Trim(edTag.Text);
end;

procedure TRadiantForm.Recompute;
var
  Spec: TRadiantSpec;
  Need, NM: Integer;
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
  { what the floor wants, said before anything else, from its size alone }
  Need := RadiantLoopsNeeded(FOutline, AllHoles, Spec);
  NM := Max(1, Ceil(Need / MANIFOLD_PORTS_MAX));
  lblNeed.Caption := Format('This floor wants about %d loops - %d manifold%s of %d',
    [Need, NM, IfThen(NM = 1, '', 's'), Max(MANIFOLD_PORTS_MIN, Ceil(Need / NM))]);
  lblProblem.Caption := RadiantProblem(FOutline, Spec);
  if lblProblem.Caption <> '' then
  begin
    memTicket.Lines.Text := '';
    FLayout.Ok := False;
    btnBuild.Enabled := False;
    pbPlan.Invalidate;
    Exit;
  end;
  FLayout := ComputeRadiantLayout(FOutline, AllHoles, Spec);
  if not FLayout.Ok then lblProblem.Caption := FLayout.Why;
  memTicket.Lines.Text := RadiantTicketText(Spec, FLayout, FUnits);
  btnBuild.Enabled := FLayout.Ok;
  ListManifolds;
  pbPlan.Invalidate;
end;

procedure TRadiantForm.AnyChange(Sender: TObject);
begin
  if FListing then Exit;
  Recompute;
end;

{ ---- manifolds ---- }

procedure TRadiantForm.ListManifolds;
var
  I, Sel: Integer;
  P: T2;
  S: string;
begin
  FListing := True;
  try
    Sel := lbManifolds.ItemIndex;
    lbManifolds.Items.Clear;
    if Length(FOutline) >= 3 then FFrame := RadiantFrameOf(FOutline);
    for I := 0 to High(FManifolds) do
    begin
      P := RadiantTo2(FFrame, FManifolds[I]);
      S := Format('%d:  %d-loop  at %s along, %s in', [I + 1, FPorts[I],
        FormatLen(P.X, FUnits), FormatLen(P.Y, FUnits)]);
      if FLayout.Ok and (I <= High(FLayout.Manifolds)) then
        S := S + Format('  -  %d laid', [FLayout.Manifolds[I].LoopCount]);
      lbManifolds.Items.Add(S);
    end;
    if FSelectLast then Sel := lbManifolds.Items.Count - 1;
    FSelectLast := False;
    if (Sel >= 0) and (Sel < lbManifolds.Items.Count) then lbManifolds.ItemIndex := Sel
    else if lbManifolds.Items.Count > 0 then lbManifolds.ItemIndex := 0;
    if (lbManifolds.ItemIndex >= 0) and (lbManifolds.ItemIndex <= High(FPorts)) then
      cbPorts.ItemIndex := FPorts[lbManifolds.ItemIndex] - MANIFOLD_PORTS_MIN;
    cbPorts.Enabled := lbManifolds.ItemIndex >= 0;
    btnRemoveManifold.Enabled := lbManifolds.ItemIndex >= 0;
  finally
    FListing := False;
  end;
end;

procedure TRadiantForm.lbManifoldsClick(Sender: TObject);
begin
  if (lbManifolds.ItemIndex >= 0) and (lbManifolds.ItemIndex <= High(FPorts)) then
  begin
    FListing := True;
    cbPorts.ItemIndex := FPorts[lbManifolds.ItemIndex] - MANIFOLD_PORTS_MIN;
    FListing := False;
  end;
  pbPlan.Invalidate;
end;

procedure TRadiantForm.cbPortsChange(Sender: TObject);
begin
  if FListing then Exit;
  if (lbManifolds.ItemIndex >= 0) and (lbManifolds.ItemIndex <= High(FPorts)) and (cbPorts.ItemIndex >= 0) then
  begin
    FPorts[lbManifolds.ItemIndex] := cbPorts.ItemIndex + MANIFOLD_PORTS_MIN;
    Recompute;
  end;
end;

procedure TRadiantForm.btnSuggestClick(Sender: TObject);
var
  Spec: TRadiantSpec;
begin
  if not Read(Spec) or (Length(FOutline) < 3) then begin Recompute; Exit; end;
  RadiantSuggestManifolds(FOutline, AllHoles, Spec, FManifolds, FPorts);
  lbManifolds.ItemIndex := -1;
  Recompute;
end;

procedure TRadiantForm.btnAddManifoldClick(Sender: TObject);
var
  Mid: TP3;
  I: Integer;
begin
  { in the middle of the floor, to be dragged to the wall it hangs on }
  Mid := P3(0, 0, 0);
  if Length(FOutline) = 0 then Exit;
  for I := 0 to High(FOutline) do
    Mid := P3(Mid.X + FOutline[I].X / Length(FOutline), Mid.Y + FOutline[I].Y / Length(FOutline),
      Mid.Z + FOutline[I].Z / Length(FOutline));
  SetLength(FManifolds, Length(FManifolds) + 1);
  SetLength(FPorts, Length(FPorts) + 1);
  FManifolds[High(FManifolds)] := Mid;
  FPorts[High(FPorts)] := 8;
  { the list does not have the new row until Recompute lists it; picking
    a row it does not have raised the exception reported on 23 September }
  FSelectLast := True;
  Recompute;
end;

procedure TRadiantForm.btnRemoveManifoldClick(Sender: TObject);
var
  I, K: Integer;
begin
  K := lbManifolds.ItemIndex;
  if (K < 0) or (K > High(FManifolds)) then Exit;
  for I := K to High(FManifolds) - 1 do
  begin
    FManifolds[I] := FManifolds[I + 1];
    FPorts[I] := FPorts[I + 1];
  end;
  SetLength(FManifolds, Length(FManifolds) - 1);
  SetLength(FPorts, Length(FPorts) - 1);
  lbManifolds.ItemIndex := -1;
  Recompute;
end;

{ ---- obstacles ---- }

procedure TRadiantForm.ListObstacles;
var
  I: Integer;
  P: T2;
  Sel: Integer;
begin
  FListing := True;
  try
    Sel := lbObstacles.ItemIndex;
    lbObstacles.Items.Clear;
    for I := 0 to High(FHoles) do
      lbObstacles.Items.Add(Format('%d:  in the drawing already, %d corners', [I + 1, Length(FHoles[I])]));
    if Length(FOutline) >= 3 then FFrame := RadiantFrameOf(FOutline);
    for I := 0 to High(FExtra) do
    begin
      P := ObstacleMid(I);
      lbObstacles.Items.Add(Format('%d:  %s x %s at %s along, %s in', [Length(FHoles) + I + 1,
        FormatLen(Dist(FExtra[I][0], FExtra[I][1]), FUnits), FormatLen(Dist(FExtra[I][1], FExtra[I][2]), FUnits),
        FormatLen(P.X, FUnits), FormatLen(P.Y, FUnits)]));
    end;
    if (Sel >= 0) and (Sel < lbObstacles.Items.Count) then lbObstacles.ItemIndex := Sel;
    btnRemoveObstacle.Enabled := lbObstacles.ItemIndex >= Length(FHoles);
  finally
    FListing := False;
  end;
end;

procedure TRadiantForm.lbObstaclesClick(Sender: TObject);
begin
  btnRemoveObstacle.Enabled := lbObstacles.ItemIndex >= Length(FHoles);
  pbPlan.Invalidate;
end;

function TRadiantForm.ObstacleMid(I: Integer): T2;
var
  J: Integer;
  P: T2;
begin
  Result := Point2(0, 0);
  if (I < 0) or (I > High(FExtra)) or (Length(FExtra[I]) = 0) then Exit;
  for J := 0 to High(FExtra[I]) do
  begin
    P := RadiantTo2(FFrame, FExtra[I][J]);
    Result.X := Result.X + P.X / Length(FExtra[I]);
    Result.Y := Result.Y + P.Y / Length(FExtra[I]);
  end;
end;

procedure TRadiantForm.MoveObstacle(I: Integer; const ToMid: T2);
var
  Was: T2;
  J: Integer;
  P: T2;
begin
  Was := ObstacleMid(I);
  for J := 0 to High(FExtra[I]) do
  begin
    P := RadiantTo2(FFrame, FExtra[I][J]);
    FExtra[I][J] := RadiantFrom2(FFrame, P.X + ToMid.X - Was.X, P.Y + ToMid.Y - Was.Y);
  end;
end;

procedure TRadiantForm.btnAddObstacleClick(Sender: TObject);
var
  W, H, U, V: Double;
  Mid: TP3;
  I: Integer;
  P: T2;
begin
  if Length(FOutline) < 3 then Exit;
  if not InchesOf(edObsW.Text, FUnits, W) or not InchesOf(edObsH.Text, FUnits, H) or (W <= 0) or (H <= 0) then
  begin
    lblProblem.Caption := 'An obstacle wants a width and a depth - 4'' x 4''.';
    Exit;
  end;
  { in the middle of the floor, square to its frame, to be dragged }
  FFrame := RadiantFrameOf(FOutline);
  Mid := P3(0, 0, 0);
  for I := 0 to High(FOutline) do
    Mid := P3(Mid.X + FOutline[I].X / Length(FOutline), Mid.Y + FOutline[I].Y / Length(FOutline),
      Mid.Z + FOutline[I].Z / Length(FOutline));
  P := RadiantTo2(FFrame, Mid);
  U := P.X; V := P.Y;
  SetLength(FExtra, Length(FExtra) + 1);
  SetLength(FExtra[High(FExtra)], 4);
  FExtra[High(FExtra)][0] := RadiantFrom2(FFrame, U - W / 2, V - H / 2);
  FExtra[High(FExtra)][1] := RadiantFrom2(FFrame, U + W / 2, V - H / 2);
  FExtra[High(FExtra)][2] := RadiantFrom2(FFrame, U + W / 2, V + H / 2);
  FExtra[High(FExtra)][3] := RadiantFrom2(FFrame, U - W / 2, V + H / 2);
  ListObstacles;
  if lbObstacles.Items.Count > 0 then lbObstacles.ItemIndex := lbObstacles.Items.Count - 1;
  Recompute;
end;

procedure TRadiantForm.btnRemoveObstacleClick(Sender: TObject);
var
  I, K: Integer;
begin
  K := lbObstacles.ItemIndex - Length(FHoles);
  if (K < 0) or (K > High(FExtra)) then Exit;
  for I := K to High(FExtra) - 1 do FExtra[I] := FExtra[I + 1];
  SetLength(FExtra, Length(FExtra) - 1);
  lbObstacles.ItemIndex := -1;
  ListObstacles;
  Recompute;
end;

{ ---- the plan, and dragging on it ---- }

function TRadiantForm.PlanX(U: Double): Integer;
begin
  Result := Round(FMargin + (U - FMinX) * FSc);
end;

function TRadiantForm.PlanY(V: Double): Integer;
begin
  Result := Round(pbPlan.Height - FMargin - (V - FMinY) * FSc);
end;

function TRadiantForm.PlanU(X: Integer): Double;
begin
  if FSc <= 0 then Exit(0);
  Result := FMinX + (X - FMargin) / FSc;
end;

function TRadiantForm.PlanV(Y: Integer): Double;
begin
  if FSc <= 0 then Exit(0);
  Result := FMinY + (pbPlan.Height - FMargin - Y) / FSc;
end;

procedure TRadiantForm.pbPlanMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
  P, M: T2;
  D, Best: Double;
begin
  if (Button <> mbLeft) or (Length(FOutline) < 3) or (FSc <= 0) then Exit;
  M := Point2(PlanU(X), PlanV(Y));
  { a manifold under the pointer, nearest first; then an obstacle }
  Best := Sqr(12 / FSc); FDragManifold := -1; FDragObstacle := -1;
  for I := 0 to High(FManifolds) do
  begin
    P := RadiantTo2(FFrame, FManifolds[I]);
    D := Sqr(P.X - M.X) + Sqr(P.Y - M.Y);
    if D < Best then begin Best := D; FDragManifold := I; FDragOff := Point2(P.X - M.X, P.Y - M.Y); end;
  end;
  if FDragManifold >= 0 then
  begin
    lbManifolds.ItemIndex := FDragManifold;
    lbManifoldsClick(nil);
    Exit;
  end;
  for I := 0 to High(FExtra) do
  begin
    P := ObstacleMid(I);
    if (Abs(P.X - M.X) <= Dist(FExtra[I][0], FExtra[I][1]) / 2) and
       (Abs(P.Y - M.Y) <= Dist(FExtra[I][1], FExtra[I][2]) / 2) then
    begin
      FDragObstacle := I;
      FDragOff := Point2(P.X - M.X, P.Y - M.Y);
      lbObstacles.ItemIndex := Length(FHoles) + I;
      lbObstaclesClick(nil);
      Exit;
    end;
  end;
end;

procedure TRadiantForm.pbPlanMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  M: T2;
begin
  if (FDragManifold < 0) and (FDragObstacle < 0) then Exit;
  M := Point2(PlanU(X) + FDragOff.X, PlanV(Y) + FDragOff.Y);
  if FDragManifold >= 0 then FManifolds[FDragManifold] := RadiantFrom2(FFrame, M.X, M.Y)
  else MoveObstacle(FDragObstacle, M);
  Recompute;
  if FDragObstacle >= 0 then ListObstacles;
end;

procedure TRadiantForm.pbPlanMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FDragManifold := -1;
  FDragObstacle := -1;
end;

{ The plan: the outline, its holes shaded, every loop in its own color so
  a long run is easy to follow by eye, and the manifolds as numbered
  squares that can be taken hold of. }
procedure TRadiantForm.pbPlanPaint(Sender: TObject);
type
  TPtArr = array of TPoint;
var
  C: TCanvas;
  W, H, I, J, Nth: Integer;
  MaxX, MaxY: Double;
  P: T2;
  S: string;

  function Poly(const Pts: TP3Array): TPtArr;
  var
    K: Integer;
    Q: T2;
  begin
    SetLength(Result, Length(Pts));
    for K := 0 to High(Pts) do
    begin
      Q := RadiantTo2(FFrame, Pts[K]);
      Result[K] := Point(PlanX(Q.X), PlanY(Q.Y));
    end;
  end;

begin
  C := pbPlan.Canvas;
  W := pbPlan.Width; H := pbPlan.Height;
  C.Brush.Color := clWhite;
  C.FillRect(0, 0, W, H);
  C.Pen.Color := clSilver;
  C.Rectangle(0, 0, W, H);
  FSc := 0;
  if Length(FOutline) < 3 then Exit;
  FFrame := RadiantFrameOf(FOutline);
  FMargin := 30;
  FMinX := 1E30; MaxX := -1E30; FMinY := 1E30; MaxY := -1E30;
  for I := 0 to High(FOutline) do
  begin
    P := RadiantTo2(FFrame, FOutline[I]);
    FMinX := Min(FMinX, P.X); MaxX := Max(MaxX, P.X);
    FMinY := Min(FMinY, P.Y); MaxY := Max(MaxY, P.Y);
  end;
  FSc := Min((W - 2 * FMargin) / Max(MaxX - FMinX, 1E-6), (H - 2 * FMargin) / Max(MaxY - FMinY, 1E-6));

  C.Pen.Color := clBlack; C.Pen.Width := 2; C.Brush.Style := bsClear;
  C.Polygon(Poly(FOutline));
  C.Pen.Width := 1;
  C.Brush.Style := bsSolid; C.Brush.Color := $00D0D0D0;
  for I := 0 to High(FHoles) do
    if Length(FHoles[I]) >= 3 then C.Polygon(Poly(FHoles[I]));
  for I := 0 to High(FExtra) do
  begin
    if lbObstacles.ItemIndex = Length(FHoles) + I then C.Pen.Color := clBlue else C.Pen.Color := clBlack;
    C.Brush.Color := $00E0D0C0;
    C.Polygon(Poly(FExtra[I]));
  end;
  C.Brush.Style := bsClear;
  if FLayout.Ok then
    for I := 0 to High(FLayout.Loops) do
    begin
      { the zone's color, thick and thin by turns - what the build draws }
      C.Pen.Color := ZoneInk(FLayout.Loops[I].Manifold);
      Nth := 0;
      for J := 0 to I - 1 do
        if FLayout.Loops[J].Manifold = FLayout.Loops[I].Manifold then Inc(Nth);
      C.Pen.Width := Round(LoopWeight(Nth));
      for J := 1 to High(FLayout.Loops[I].Pts) do
      begin
        P := RadiantTo2(FFrame, FLayout.Loops[I].Pts[J - 1]);
        C.MoveTo(PlanX(P.X), PlanY(P.Y));
        P := RadiantTo2(FFrame, FLayout.Loops[I].Pts[J]);
        C.LineTo(PlanX(P.X), PlanY(P.Y));
      end;
    end;
  { the manifolds last, on top: a filled square with its number }
  C.Pen.Width := 1;
  for I := 0 to High(FManifolds) do
  begin
    P := RadiantTo2(FFrame, FManifolds[I]);
    if lbManifolds.ItemIndex = I then C.Brush.Color := clYellow else C.Brush.Color := clWhite;
    C.Brush.Style := bsSolid;
    C.Pen.Color := ZoneInk(I);
    C.Pen.Width := 2;
    C.Rectangle(PlanX(P.X) - 9, PlanY(P.Y) - 9, PlanX(P.X) + 9, PlanY(P.Y) + 9);
    S := IntToStr(I + 1);
    C.Font.Color := clBlack;
    C.TextOut(PlanX(P.X) - C.TextWidth(S) div 2, PlanY(P.Y) - C.TextHeight(S) div 2, S);
  end;
  C.Brush.Style := bsClear;
  C.Font.Color := clGray;
  if not FLayout.Ok then C.TextOut(8, H - 20, 'not yet a valid layout - drag a manifold, or press Suggest')
  else C.TextOut(8, H - 20, Format('%d loop(s) on %d manifold(s), %d row(s) - drag a manifold or an obstacle',
    [Length(FLayout.Loops), Length(FLayout.Manifolds), FLayout.RowCount]));
end;

procedure TRadiantForm.btnReportClick(Sender: TObject);
begin
  MainForm.ReportFromDialog('Radiant heat layout',
    'floor: ' + rgFloor.Items[Max(0, rgFloor.ItemIndex)] + LineEnding +
    'tube: ' + cbTube.Text + ', spacing ' + edSpacing.Text + LineEnding +
    'manifolds: ' + IntToStr(Length(FManifolds)) + ', obstacles added: ' + IntToStr(Length(FExtra)) + LineEnding +
    'problem shown: ' + lblProblem.Caption);
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
    F.ListObstacles;
    if F.ShowModal <> mrOK then Exit;
    Result := F.Read(Spec) and (RadiantProblem(Outline, Spec) = '');
  finally
    F.Free;
  end;
end;

end.
