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
    btnReplay: TButton;
    btnReport: TButton;
    btnSuggest: TButton;
    cbLabels: TCheckBox;
    cbPorts: TComboBox;
    cbTube: TComboBox;
    edMaxLoop: TEdit;
    edObsH: TEdit;
    edObsW: TEdit;
    edSpacing: TEdit;
    edTag: TEdit;
    edWaste: TEdit;
    lbManifolds: TListBox;
    lblManifoldHead: TLabel;
    lblMaxLoop: TLabel;
    lblMaxLoopHint: TLabel;
    lblNeed: TLabel;
    lblObsHead: TLabel;
    lblObsX: TLabel;
    lblPorts: TLabel;
    lblProblem: TLabel;
    lblSpacing: TLabel;
    lblSpacingIn: TLabel;
    lblTag: TLabel;
    lblTagHint: TLabel;
    lblTicket: TLabel;
    lblTitle: TLabel;
    lblTube: TLabel;
    lblUnits: TLabel;
    lblWaste: TLabel;
    lblWastePct: TLabel;
    lbObstacles: TListBox;
    memTicket: TMemo;
    pbCoverage: TPaintBox;
    pbEven: TPaintBox;
    pbPlan: TPaintBox;
    pcRight: TPageControl;
    tmrDragSettle: TTimer;
    tmrReplay: TTimer;
    tsPlan: TTabSheet;
    procedure AnyChange(Sender: TObject);
    procedure btnAddManifoldClick(Sender: TObject);
    procedure btnAddObstacleClick(Sender: TObject);
    procedure btnRemoveManifoldClick(Sender: TObject);
    procedure btnRemoveObstacleClick(Sender: TObject);
    procedure btnReplayClick(Sender: TObject);
    procedure btnReportClick(Sender: TObject);
    procedure btnSuggestClick(Sender: TObject);
    procedure cbPortsChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure lbManifoldsClick(Sender: TObject);
    procedure lbObstaclesClick(Sender: TObject);
    procedure pbCoveragePaint(Sender: TObject);
    procedure pbEvenPaint(Sender: TObject);
    procedure pbPlanMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure pbPlanMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbPlanMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure pbPlanPaint(Sender: TObject);
    procedure tmrDragSettleTimer(Sender: TObject);
    procedure tmrReplayTimer(Sender: TObject);
  private
    FUnits: TUnitSystem;
    FZones: TRadiantZones;           { every face selected, with its holes }
    FExtra: array of TP3Array;       { obstacles added here, as rectangles }
    FManifolds: TP3Array;            { one per zone }
    FPorts: TIntArray;
    FLayouts: array of TRadiantResult;
    { the outline of everything, for the plan's frame and the fit }
    FOutline: TP3Array;
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
    { the two gauges, kept from the last Recompute for the bars to paint
      from - -1 means nothing to show yet }
    FCoverage, FEvenness: Double;
    { the search behind whichever zone Replay search last ran for - -1
      means nothing is playing, so the plan paints the settled layout
      the ordinary way; FReplayPerTick steps more than one candidate a
      tick on a long search, so watching it never takes more than a
      few seconds regardless of how many lanes it tried }
    FReplayZone, FReplayStep, FReplayPerTick: Integer;
    FReplayTrace: TRadiantTrace;
    procedure Recompute;
    function Read(out Spec: TRadiantSpec): Boolean;
    function ZoneHoles(Z: Integer): TRadiantHoles;
    function AnyLayout: Boolean;
    procedure ListManifolds;
    procedure ListObstacles;
    function PlanX(U: Double): Integer;
    function PlanY(V: Double): Integer;
    function PlanU(X: Integer): Double;
    function PlanV(Y: Integer): Double;
    procedure MoveObstacle(I: Integer; const ToMid: T2);
    function ObstacleMid(I: Integer): T2;
    function FirstExtraRow: Integer;
  public
    class function Ask(Units: TUnitSystem; const Zones: TRadiantZones;
      out Spec: TRadiantSpec; out Manifolds: TP3Array; out Ports: TIntArray): Boolean;
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
  for I := MANIFOLD_PORTS_MIN to MANIFOLD_PORTS_MAX do cbPorts.Items.Add(Format('%d-loop', [I]));
  FDragManifold := -1;
  FDragObstacle := -1;
  FCoverage := -1; FEvenness := -1;
  FReplayZone := -1;
end;

procedure TRadiantForm.FormShow(Sender: TObject);
begin
  { right off: what this floor wants, and a manifold or several to suit,
    where a manifold goes - on a wall.  To be dragged from there. }
  if Length(FManifolds) = 0 then btnSuggestClick(nil)
  else AnyChange(nil);
end;

function TRadiantForm.ZoneHoles(Z: Integer): TRadiantHoles;
var
  I, N: Integer;
begin
  N := Length(FZones[Z].Holes);
  SetLength(Result, N + Length(FExtra));
  for I := 0 to N - 1 do Result[I] := FZones[Z].Holes[I];
  for I := 0 to High(FExtra) do Result[N + I] := FExtra[I];
end;

function TRadiantForm.AnyLayout: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(FLayouts) do if FLayouts[I].Ok then Exit(True);
end;

function TRadiantForm.Read(out Spec: TRadiantSpec): Boolean;
var
  I: Integer;
begin
  Spec := DefaultRadiantSpec;
  Spec.Tube := TTubeSize(Max(0, cbTube.ItemIndex));
  Result := InchesOf(edSpacing.Text, FUnits, Spec.Spacing);
  if Trim(edMaxLoop.Text) = '' then Spec.MaxLoopFt := 0
  else Result := Result and FeetOf(edMaxLoop.Text, FUnits, Spec.MaxLoopFt);
  Result := Result and TryStrToFloat(Trim(edWaste.Text), Spec.WastePct);
  { the slab itself is not asked about yet - concrete, default thickness,
    tube centered, R-15 under it, while the engine underneath it is what
    is being worked on }
  SetLength(Spec.Extra, Length(FExtra));
  for I := 0 to High(FExtra) do Spec.Extra[I] := Copy(FExtra[I]);
  Spec.Tag := Trim(edTag.Text);
  Spec.Labels := cbLabels.Checked;
end;

procedure TRadiantForm.Recompute;
var
  Spec, ZS: TRadiantSpec;
  Z, NeedAll: Integer;
  Ticket: string;
  TotalFt, OrderFt, Worst, Lo, Hi, TotalArea, TotalUnfilled: Double;
  Loops, I: Integer;
  HasEven: Boolean;
begin
  if not Read(Spec) then
  begin
    lblProblem.Caption := 'A size did not read - 9, 9.5, or a foot mark.';
    memTicket.Lines.Text := '';
    SetLength(FLayouts, 0);
    FCoverage := -1; FEvenness := -1;
    pbPlan.Invalidate; pbCoverage.Invalidate; pbEven.Invalidate;
    Exit;
  end;
  if Length(FZones) = 0 then
  begin
    lblProblem.Caption := 'Nothing is selected to fill - select the floor and run this again.';
    memTicket.Lines.Text := '';
    SetLength(FLayouts, 0);
    FCoverage := -1; FEvenness := -1;
    pbPlan.Invalidate; pbCoverage.Invalidate; pbEven.Invalidate;
    Exit;
  end;
  { what the floor wants, zone by zone, said before anything else }
  NeedAll := 0;
  for Z := 0 to High(FZones) do
    NeedAll := NeedAll + RadiantLoopsNeeded(FZones[Z].Outline, ZoneHoles(Z), Spec);
  lblNeed.Caption := Format('%d zone%s, about %d loops all told - one manifold a zone',
    [Length(FZones), IfThen(Length(FZones) = 1, '', 's'), NeedAll]);
  lblProblem.Caption := '';
  SetLength(FLayouts, Length(FZones));
  Ticket := '';
  if Spec.Tag <> '' then Ticket := Spec.Tag + LineEnding + LineEnding;
  TotalFt := 0; OrderFt := 0; Loops := 0; TotalArea := 0; TotalUnfilled := 0;
  for Z := 0 to High(FZones) do
  begin
    ZS := Spec;
    SetLength(ZS.Manifolds, 1); SetLength(ZS.Ports, 1);
    ZS.Manifolds[0] := FManifolds[Z]; ZS.Ports[0] := FPorts[Z];
    ZS.Tag := '';
    if lblProblem.Caption = '' then lblProblem.Caption := RadiantProblem(FZones[Z].Outline, ZS);
    FLayouts[Z] := ComputeRadiantLayout(FZones[Z].Outline, ZoneHoles(Z), ZS);
    if not FLayouts[Z].Ok and (lblProblem.Caption = '') then
      lblProblem.Caption := Format('Zone %d: %s', [Z + 1, FLayouts[Z].Why]);
    Ticket := Ticket + Format('===== ZONE %d =====', [Z + 1]) + LineEnding +
      RadiantTicketText(ZS, FLayouts[Z], FUnits) + LineEnding;
    if FLayouts[Z].Ok then
    begin
      TotalFt := TotalFt + FLayouts[Z].TotalFt;
      OrderFt := OrderFt + FLayouts[Z].OrderFt;
      Loops := Loops + Length(FLayouts[Z].Loops);
      TotalArea := TotalArea + FLayouts[Z].AreaSqFt;
      TotalUnfilled := TotalUnfilled + FLayouts[Z].UnfilledSqFt;
    end;
  end;
  { the two gauges to watch while a manifold is dragged: how much of
    the floor the layout actually reaches, and how close the loops of
    each zone come to one another in length - green when they are,
    red when they are not }
  if TotalArea > 0 then FCoverage := Max(0, Min(1, 1 - TotalUnfilled / TotalArea))
  else FCoverage := -1;
  Worst := 0; HasEven := False;
  for Z := 0 to High(FLayouts) do
    if FLayouts[Z].Ok and (Length(FLayouts[Z].Loops) > 0) then
    begin
      HasEven := True;
      if Length(FLayouts[Z].Loops) > 1 then
      begin
        Lo := 1E300; Hi := 0;
        for I := 0 to High(FLayouts[Z].Loops) do
        begin
          Lo := Min(Lo, FLayouts[Z].Loops[I].LenFt); Hi := Max(Hi, FLayouts[Z].Loops[I].LenFt);
        end;
        if Hi > 0 then Worst := Max(Worst, (Hi - Lo) / Hi);
      end;
    end;
  if HasEven then FEvenness := 1 - Worst else FEvenness := -1;
  if Length(FZones) > 1 then
    Ticket := Ticket + '===== ALL ZONES =====' + LineEnding +
      Format('%d zones, %d loops, %d manifolds', [Length(FZones), Loops, Length(FZones)]) + LineEnding +
      'total tube, no waste: ' + FormatLen(TotalFt, FUnits) + LineEnding +
      'order: ' + FormatLen(OrderFt, FUnits) + LineEnding;
  memTicket.Lines.Text := Ticket;
  btnBuild.Enabled := AnyLayout and (lblProblem.Caption = '');
  ListManifolds;
  pbPlan.Invalidate; pbCoverage.Invalidate; pbEven.Invalidate;
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
      S := Format('zone %d:  at %s along, %s in', [I + 1, FormatLen(P.X, FUnits), FormatLen(P.Y, FUnits)]);
      if (I <= High(FLayouts)) and FLayouts[I].Ok and (Length(FLayouts[I].Manifolds) > 0) then
        S := S + Format('  -  a %d-loop manifold', [FLayouts[I].Manifolds[0].Ports]);
      lbManifolds.Items.Add(S);
    end;
    if FSelectLast then Sel := lbManifolds.Items.Count - 1;
    FSelectLast := False;
    if (Sel >= 0) and (Sel < lbManifolds.Items.Count) then lbManifolds.ItemIndex := Sel
    else if lbManifolds.Items.Count > 0 then lbManifolds.ItemIndex := 0;
    if (lbManifolds.ItemIndex >= 0) and (lbManifolds.ItemIndex <= High(FPorts)) then
      cbPorts.ItemIndex := FPorts[lbManifolds.ItemIndex] - MANIFOLD_PORTS_MIN;
    cbPorts.Enabled := False;
    cbPorts.Visible := False; lblPorts.Visible := False;
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
  Z, I, N: Integer;
  Mid: TP3;
begin
  if not Read(Spec) or (Length(FZones) = 0) then begin Recompute; Exit; end;
  { the middle of everything - where the boiler most likely is - and each
    zone's manifold at its corner nearest that }
  Mid := P3(0, 0, 0); N := 0;
  for Z := 0 to High(FZones) do
    for I := 0 to High(FZones[Z].Outline) do
    begin
      Mid := P3(Mid.X + FZones[Z].Outline[I].X, Mid.Y + FZones[Z].Outline[I].Y, Mid.Z + FZones[Z].Outline[I].Z);
      Inc(N);
    end;
  if N > 0 then Mid := P3(Mid.X / N, Mid.Y / N, Mid.Z / N);
  SetLength(FManifolds, Length(FZones));
  SetLength(FPorts, Length(FZones));
  for Z := 0 to High(FZones) do
    RadiantSuggestZoneManifold(FZones[Z], Mid, Spec, FManifolds[Z], FPorts[Z]);
  lbManifolds.ItemIndex := -1;
  Recompute;
end;

{ Runs the zone currently selected (or the first, with none) a second
  time, this once asking for the trace of every lane the search tried
  - not just what it kept - and plays that back a few candidates a
  tick, capped so a long search is never more than a few seconds to
  watch: red for one turned back for crossing tube already down,
  green for the one that settled it, before it takes the ordinary
  color and stays.  The settled layout beneath it is untouched; this
  only changes what the plan paints while it is running. }
procedure TRadiantForm.btnReplayClick(Sender: TObject);
var
  Spec, ZS: TRadiantSpec;
  Z: Integer;
  R: TRadiantResult;
begin
  if not Read(Spec) or (Length(FZones) = 0) then Exit;
  Z := lbManifolds.ItemIndex;
  if (Z < 0) or (Z > High(FZones)) then Z := 0;
  ZS := Spec;
  SetLength(ZS.Manifolds, 1); SetLength(ZS.Ports, 1);
  ZS.Manifolds[0] := FManifolds[Z]; ZS.Ports[0] := FPorts[Z];
  R := ComputeRadiantLayout(FZones[Z].Outline, ZoneHoles(Z), ZS, True);
  FReplayTrace := R.Trace;
  FReplayStep := 0;
  FReplayPerTick := Max(1, Ceil(Length(FReplayTrace) / 200));
  if Length(FReplayTrace) > 0 then
  begin
    FReplayZone := Z;
    tmrReplay.Enabled := True;
  end
  else FReplayZone := -1;
  pbPlan.Invalidate;
end;

procedure TRadiantForm.tmrReplayTimer(Sender: TObject);
begin
  Inc(FReplayStep, FReplayPerTick);
  if FReplayStep >= Length(FReplayTrace) then
  begin
    tmrReplay.Enabled := False;
    FReplayZone := -1;
  end;
  pbPlan.Invalidate;
end;

procedure TRadiantForm.btnAddManifoldClick(Sender: TObject);
begin
  { one manifold a zone: to have two, draw a line across the zone on the
    sheet and it is two zones }
  lblProblem.Caption := 'One manifold a zone - draw a line across the floor to make two zones.';
end;

procedure TRadiantForm.btnRemoveManifoldClick(Sender: TObject);
begin
  lblProblem.Caption := 'One manifold a zone - it cannot be taken away.';
end;

{ ---- obstacles ---- }

procedure TRadiantForm.ListObstacles;
var
  I, Z, N: Integer;
  P: T2;
  Sel: Integer;
begin
  FListing := True;
  try
    Sel := lbObstacles.ItemIndex;
    lbObstacles.Items.Clear;
    N := 0;
    for Z := 0 to High(FZones) do N := N + Length(FZones[Z].Holes);
    if N > 0 then lbObstacles.Items.Add(Format('%d in the drawing already - removed faces', [N]));
    N := Min(1, N);
    if Length(FOutline) >= 3 then FFrame := RadiantFrameOf(FOutline);
    for I := 0 to High(FExtra) do
    begin
      P := ObstacleMid(I);
      lbObstacles.Items.Add(Format('%d:  %s x %s at %s along, %s in', [N + I + 1,
        FormatLen(Dist(FExtra[I][0], FExtra[I][1]), FUnits), FormatLen(Dist(FExtra[I][1], FExtra[I][2]), FUnits),
        FormatLen(P.X, FUnits), FormatLen(P.Y, FUnits)]));
    end;
    if (Sel >= 0) and (Sel < lbObstacles.Items.Count) then lbObstacles.ItemIndex := Sel;
    btnRemoveObstacle.Enabled := lbObstacles.ItemIndex >= N;
  finally
    FListing := False;
  end;
end;

function TRadiantForm.FirstExtraRow: Integer;
var
  Z: Integer;
begin
  Result := 0;
  for Z := 0 to High(FZones) do if Length(FZones[Z].Holes) > 0 then Exit(1);
end;

procedure TRadiantForm.lbObstaclesClick(Sender: TObject);
begin
  btnRemoveObstacle.Enabled := lbObstacles.ItemIndex >= FirstExtraRow;
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
  K := lbObstacles.ItemIndex - FirstExtraRow;
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
  { a stale search is worse than none - a fresh drag means whatever
    position it was tried at is already out of date }
  if FReplayZone >= 0 then begin tmrReplay.Enabled := False; FReplayZone := -1; end;
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
      lbObstacles.ItemIndex := FirstExtraRow + I;
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
  if FDragManifold >= 0 then
  begin
    { a manifold stays in its own zone: a drag out of it is ignored }
    if not RadiantInside(FZones[FDragManifold].Outline, RadiantFrom2(FFrame, M.X, M.Y)) then Exit;
    FManifolds[FDragManifold] := RadiantFrom2(FFrame, M.X, M.Y);
  end
  else MoveObstacle(FDragObstacle, M);
  { the marker itself is drawn from FManifolds/FExtra directly, so it
    tracks the pointer right away; the engine is the expensive part and
    only gets asked once the pointer has sat still for a moment, not on
    every one of a drag's hundred mouse-move events }
  pbPlan.Invalidate;
  if FDragObstacle >= 0 then ListObstacles;
  tmrDragSettle.Enabled := False;
  tmrDragSettle.Enabled := True;
end;

procedure TRadiantForm.pbPlanMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  WasDragging: Boolean;
begin
  WasDragging := (FDragManifold >= 0) or (FDragObstacle >= 0);
  FDragManifold := -1;
  FDragObstacle := -1;
  if WasDragging then
  begin
    tmrDragSettle.Enabled := False;
    Recompute;
  end;
end;

procedure TRadiantForm.tmrDragSettleTimer(Sender: TObject);
begin
  tmrDragSettle.Enabled := False;
  Recompute;
end;

{ A gauge, painted the same way on both boxes: a bordered bar, filled
  from the left to Frac (0..1) of its width, in a color that says how
  good that fraction is - green well up, amber part way, red poor -
  with the caption centered over it.  Frac < 0 means nothing has been
  worked out yet, and the bar says so instead of guessing. }
procedure PaintGauge(PB: TPaintBox; Frac: Double; const Cap: string);
var
  C: TCanvas;
  W, H, FillW, TW: Integer;
begin
  C := PB.Canvas;
  W := PB.Width; H := PB.Height;
  C.Brush.Color := $00E8E8E8;
  C.FillRect(0, 0, W, H);
  if Frac >= 0 then
  begin
    FillW := Round(W * Frac);
    if Frac >= 0.85 then C.Brush.Color := $00308030
    else if Frac >= 0.65 then C.Brush.Color := $000080C0
    else C.Brush.Color := $002020C0;
    C.FillRect(0, 0, FillW, H);
  end;
  C.Brush.Style := bsClear;
  C.Pen.Color := clSilver;
  C.Rectangle(0, 0, W, H);
  C.Brush.Style := bsSolid;
  C.Font.Color := clBlack;
  TW := C.TextWidth(Cap);
  C.TextOut((W - TW) div 2, (H - C.TextHeight(Cap)) div 2, Cap);
end;

procedure TRadiantForm.pbCoveragePaint(Sender: TObject);
begin
  if FCoverage < 0 then PaintGauge(pbCoverage, -1, 'Coverage - drag a manifold, or press Suggest')
  else PaintGauge(pbCoverage, FCoverage, Format('Coverage: %d%% of the floor reached', [Round(FCoverage * 100)]));
end;

procedure TRadiantForm.pbEvenPaint(Sender: TObject);
begin
  if FEvenness < 0 then PaintGauge(pbEven, -1, 'Evenness - how close the loop lengths come')
  else PaintGauge(pbEven, FEvenness, Format('Evenness: loops within %d%% of each other', [Round((1 - FEvenness) * 100)]));
end;

{ The plan: the outline, its holes shaded, every loop in its own color so
  a long run is easy to follow by eye, and the manifolds as numbered
  squares that can be taken hold of. }
procedure TRadiantForm.pbPlanPaint(Sender: TObject);
type
  TPtArr = array of TPoint;
var
  C: TCanvas;
  W, H, I, J, Z, Loops: Integer;
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
  for Z := 0 to High(FZones) do
    for I := 0 to High(FZones[Z].Outline) do
    begin
      P := RadiantTo2(FFrame, FZones[Z].Outline[I]);
      FMinX := Min(FMinX, P.X); MaxX := Max(MaxX, P.X);
      FMinY := Min(FMinY, P.Y); MaxY := Max(MaxY, P.Y);
    end;
  FSc := Min((W - 2 * FMargin) / Max(MaxX - FMinX, 1E-6), (H - 2 * FMargin) / Max(MaxY - FMinY, 1E-6));

  for Z := 0 to High(FZones) do
  begin
    C.Pen.Color := clBlack; C.Pen.Width := 2; C.Brush.Style := bsClear;
    C.Polygon(Poly(FZones[Z].Outline));
    C.Pen.Width := 1;
    C.Brush.Style := bsSolid; C.Brush.Color := $00D0D0D0;
    for I := 0 to High(FZones[Z].Holes) do
      if Length(FZones[Z].Holes[I]) >= 3 then C.Polygon(Poly(FZones[Z].Holes[I]));
  end;
  for I := 0 to High(FExtra) do
  begin
    if lbObstacles.ItemIndex = FirstExtraRow + I then C.Pen.Color := clBlue else C.Pen.Color := clBlack;
    C.Brush.Color := $00E0D0C0;
    C.Polygon(Poly(FExtra[I]));
  end;
  C.Brush.Style := bsClear;
  for Z := 0 to High(FLayouts) do
    if Z = FReplayZone then
    begin
      { every lane tried, up to the one the timer is currently on: one
        already kept paints in the zone's own color and stays: one
        turned back paints only for its own moment, in red, and is
        skipped from here on - it never became part of the floor }
      for I := 0 to Min(FReplayStep, High(FReplayTrace)) do
      begin
        if I = FReplayStep then
        begin
          if FReplayTrace[I].Accepted then C.Pen.Color := clLime else C.Pen.Color := clRed;
          C.Pen.Width := 3;
        end
        else if FReplayTrace[I].Accepted then
        begin
          C.Pen.Color := ZoneInk(Z);
          C.Pen.Width := 1;
        end
        else Continue;
        for J := 1 to High(FReplayTrace[I].Pts) do
        begin
          P := RadiantTo2(FFrame, FReplayTrace[I].Pts[J - 1]);
          C.MoveTo(PlanX(P.X), PlanY(P.Y));
          P := RadiantTo2(FFrame, FReplayTrace[I].Pts[J]);
          C.LineTo(PlanX(P.X), PlanY(P.Y));
        end;
      end;
    end
    else if FLayouts[Z].Ok then
      for I := 0 to High(FLayouts[Z].Loops) do
      begin
        { the zone's color, thick and thin by turns - what the build draws }
        C.Pen.Color := ZoneInk(Z);
        C.Pen.Width := Round(LoopWeight(I));
        for J := 1 to High(FLayouts[Z].Loops[I].Pts) do
        begin
          P := RadiantTo2(FFrame, FLayouts[Z].Loops[I].Pts[J - 1]);
          C.MoveTo(PlanX(P.X), PlanY(P.Y));
          P := RadiantTo2(FFrame, FLayouts[Z].Loops[I].Pts[J]);
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
  Loops := 0;
  for Z := 0 to High(FLayouts) do if FLayouts[Z].Ok then Loops := Loops + Length(FLayouts[Z].Loops);
  if not AnyLayout then C.TextOut(8, H - 20, 'not yet a valid layout - drag a manifold, or press Suggest')
  else C.TextOut(8, H - 20, Format('%d zone(s), %d loop(s) - drag a manifold or an obstacle',
    [Length(FZones), Loops]));
end;

procedure TRadiantForm.btnReportClick(Sender: TObject);
begin
  MainForm.ReportFromDialog('Radiant heat layout',
    'floor: concrete slab' + LineEnding +
    'tube: ' + cbTube.Text + ', spacing ' + edSpacing.Text + LineEnding +
    'manifolds: ' + IntToStr(Length(FManifolds)) + ', obstacles added: ' + IntToStr(Length(FExtra)) + LineEnding +
    'problem shown: ' + lblProblem.Caption);
end;

class function TRadiantForm.Ask(Units: TUnitSystem; const Zones: TRadiantZones;
  out Spec: TRadiantSpec; out Manifolds: TP3Array; out Ports: TIntArray): Boolean;
var
  F: TRadiantForm;
begin
  Result := False;
  F := TRadiantForm.Create(nil);
  try
    F.FUnits := Units;
    F.FZones := Zones;
    { the frame the plan is drawn in is the first zone's - the biggest is
      usually first, and any one will do as long as it is the same one
      every time }
    if Length(Zones) > 0 then F.FOutline := Zones[0].Outline;
    F.ListObstacles;
    if F.ShowModal <> mrOK then Exit;
    Result := F.Read(Spec) and (Length(F.FManifolds) = Length(Zones));
    Manifolds := Copy(F.FManifolds);
    Ports := Copy(F.FPorts);
  finally
    F.Free;
  end;
end;

end.
