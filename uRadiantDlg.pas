unit uRadiantDlg;

{ The radiant heat layout wizard: given the outline of the floor it is
  asked to fill - the selection's own corners, and its holes as the real
  obstacles already cut into it - it asks the standard things a design
  wants, and shows the plan and the material list beside the numbers.

  The moment it opens it puts a manifold in each zone, where one most
  likely hangs, and searches nothing: the search takes seconds a zone on
  a real floor, so it runs only when asked - Search this zone, Search all
  zones, or the same on the plan's or the list's right-click - under a
  window with a bar and a Stop.  Anything that changes where the tube can
  go - a manifold dragged, an obstacle added, moved or taken away, the
  tube, the spacing or the maximum typed in - clears the zones it
  touches rather than searching them again on every keystroke, and they
  wait to be asked for again.  A true "click the spot on
  the sheet" picker wants the wizard to run alongside the sheet rather
  than in front of it, the way the source window does; that is the next
  step, not this one - dragging on the plan is most of it. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, StdCtrls, ExtCtrls, Graphics,
  ComCtrls, Dialogs, StrUtils, Menus, uWork, uRadiantData, uRadiant, uRadiantBusy;

type

  { TRadiantForm }

  TRadiantForm = class(TForm)
    btnAddObstacle: TButton;
    btnBuild: TButton;
    btnCancel: TButton;
    btnRemoveObstacle: TButton;
    btnReport: TButton;
    btnSearchAll: TButton;
    btnSuggest: TButton;
    btnZoneClear: TButton;
    btnZoneSearch: TButton;
    lblFoundHead: TLabel;
    lblZoneHead: TLabel;
    lblZonesHint: TLabel;
    lbSolutions: TListBox;
    pnZone: TPanel;
    tcZones: TTabControl;
    cbLabels: TCheckBox;
    cbTube: TComboBox;
    edMaxLoop: TEdit;
    edObsH: TEdit;
    edGoalCover: TEdit;
    edGoalEven: TEdit;
    edObsW: TEdit;
    edSpacing: TEdit;
    edTag: TEdit;
    edWaste: TEdit;
    lblGoal: TLabel;
    lblGoalCover: TLabel;
    lblGoalEven: TLabel;
    lblManifoldHead: TLabel;
    lblMaxLoop: TLabel;
    lblMaxLoopHint: TLabel;
    lblNeed: TLabel;
    lblObsHead: TLabel;
    lblObsX: TLabel;
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
    miClearAll: TMenuItem;
    miClearZone: TMenuItem;
    miRotate: TMenuItem;
    miFace: TMenuItem;
    miFaceEW: TMenuItem;
    miFaceNS: TMenuItem;
    miFace45: TMenuItem;
    miFace135: TMenuItem;
    miSearchAll: TMenuItem;
    miSearchZone: TMenuItem;
    miSep: TMenuItem;
    pbCoverage: TPaintBox;
    pbEven: TPaintBox;
    pbPlan: TPaintBox;
    pcRight: TPageControl;
    pmZone: TPopupMenu;
    tsPlan: TTabSheet;
    procedure AnyChange(Sender: TObject);
    procedure btnAddObstacleClick(Sender: TObject);
    procedure btnRemoveObstacleClick(Sender: TObject);
    procedure btnReportClick(Sender: TObject);
    procedure btnSearchAllClick(Sender: TObject);
    procedure btnSearchZoneClick(Sender: TObject);
    procedure btnSuggestClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure lbObstaclesClick(Sender: TObject);
    procedure lbSolutionsClick(Sender: TObject);
    procedure tcZonesChange(Sender: TObject);
    procedure pbCoveragePaint(Sender: TObject);
    procedure pbEvenPaint(Sender: TObject);
    procedure pbPlanMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure pbPlanMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbPlanMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure pbPlanPaint(Sender: TObject);
    procedure miClearAllClick(Sender: TObject);
    procedure miClearZoneClick(Sender: TObject);
    procedure miRotateClick(Sender: TObject);
    procedure miFaceClick(Sender: TObject);
    procedure miSearchZoneClick(Sender: TObject);
    procedure pmZonePopup(Sender: TObject);
    procedure RoutingChange(Sender: TObject);
  private
    FUnits: TUnitSystem;
    FZones: TRadiantZones;           { every face selected, with its holes }
    FExtra: array of TP3Array;       { obstacles added here, as rectangles }
    FManifolds: TP3Array;            { one per zone }
    { each manifold's heading in the plan's frame, degrees: its long
      side, the row of ports, runs this way }
    FAngles: array of Double;
    FPorts: TIntArray;
    FLayouts: TRadiantResults;
    { which zones have been searched since anything that moves tube last
      changed - a zone not searched shows no tube and cannot be built }
    FSearched: array of Boolean;
    { the search under way, for the bar: its window, and which of how
      many zones it is on }
    FBusy: TRadiantBusyForm;
    FBusyIndex, FBusyCount: Integer;
    { the solutions the search has kept so far, best first, kept up to
      date by it as it goes - for the busy window's list }
    FLiveFound: TRadiantResults;
    { the goals as the busy window has them, read by the search after
      every layout; when the zone being searched began; and the busy
      window's give-up choice, remembered with the rest }
    FLiveGoals: TRadiantGoals;
    FZoneStart: QWord;
    FGiveUpIdx: Integer;
    { the evenness gauge's worst zone as a length: its longest loop less
      its shortest, feet }
    FEvenFt: Double;
    { what SearchWork is to search: set by Search, which shows the busy
      window and has it run SearchWork }
    FWorkSpec: TRadiantSpec;
    FWorkZones: TIntArray;
    { the outline of everything, for the plan's frame and the fit }
    FOutline: TP3Array;
    { the plan's own projection, worked out at paint time and kept for the
      mouse: the outline's frame, and how its plane maps to pixels }
    FFrame: TRadiantFrame;
    FMinX, FMinY, FSc: Double;
    { what centers the floor in the plan's box }
    FOffX, FOffY: Double;
    FMargin: Integer;
    { what is being dragged on the plan: a manifold (0..), an obstacle
      (0..) or nothing }
    FDragManifold, FDragObstacle: Integer;
    FDragOff: T2;
    FDragMoved: Boolean;
    FListing: Boolean;
    { the two gauges, kept from the last Summarize for the bars to paint
      from - -1 means nothing to show yet }
    FCoverage, FEvenness: Double;
    { each zone's material list, and every zone's together, as Summarize
      last wrote them - the zone tabs show one or the other }
    FZoneTicket: array of string;
    FAllTicket: string;
    { how the zone's search just ended, when it was not by itself - the
      busy window's Stop, or its give-up time - for the search's record }
    FStopWhy: string;
    { every zone's solutions as its last search found them - the ones
      that met the goals, best first, or the nearest few when none did -
      and which of them the zone is showing and will build }
    FSolutions: array of TRadiantResults;
    FSolIdx: TIntArray;
    procedure ShowSolution(Z, Idx: Integer);
    { the zone tabs, one a zone and one for them all, and the panel under
      them filled for the tab that is up }
    procedure ListZones;
    procedure ShowZonePanel;
    procedure SelectZone(Z: Integer);
    procedure Summarize;
    procedure LoadLast;
    procedure SaveLast;
    procedure ClearZone(Z: Integer);
    procedure ClearAll;
    function ZoneSpec(Z: Integer; const Spec: TRadiantSpec): TRadiantSpec;
    function SelectedZone: Integer;
    function WallAngle(Z: Integer): Double;
    function ManifoldBox(Z: Integer): T2Array;
    function ManifoldAt(X, Y: Integer): Integer;
    procedure Search(const Which: array of Integer);
    procedure SearchWork(Sender: TObject);
    procedure SearchProgress(Done, Total: Integer; const Best: TRadiantResult; var Stop: Boolean);
    { one kept solution as a line of the busy window's list, and shorter
      for the zone tab's }
    function FoundLine(const R: TRadiantResult): string;
    function ShortLine(const R: TRadiantResult): string;
    procedure PaintCompass(C: TCanvas; CX, CY: Integer);
    function Read(out Spec: TRadiantSpec): Boolean;
    function ZoneHoles(Z: Integer): TRadiantHoles;
    function AnyLayout: Boolean;
    procedure ListObstacles;
    function PlanX(U: Double): Integer;
    function PlanY(V: Double): Integer;
    function PlanU(X: Integer): Double;
    function PlanV(Y: Integer): Double;
    procedure MoveObstacle(I: Integer; const ToMid: T2);
    function ObstacleMid(I: Integer): T2;
    function FirstExtraRow: Integer;
  public
    { the layouts come back as searched, zone by zone, so building them
      never searches a second time }
    class function Ask(Units: TUnitSystem; const Zones: TRadiantZones;
      out Spec: TRadiantSpec; out Manifolds: TP3Array; out Ports: TIntArray;
      out Layouts: TRadiantResults): Boolean;
  end;

implementation

{$R *.lfm}

uses
  IniFiles, uPaths, uMain;

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
begin
  for S := Low(TTubeSize) to High(TTubeSize) do cbTube.Items.Add(TUBE_NAMES[S]);
  cbTube.ItemIndex := Ord(tsHalf);
  FDragManifold := -1;
  FDragObstacle := -1;
  FCoverage := -1; FEvenness := -1;
  LoadLast;
end;

{ Every edit, combo and check box on the form, by name, under [radiant] in
  the settings - the tube, the spacing, the goals as they were last left,
  so they are not set again every time (the owner, 25 September).  The tag
  is left out: it names one job. }
procedure TRadiantForm.SaveLast;
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
        if C is TEdit then Ini.WriteString('radiant', C.Name, TEdit(C).Text)
        else if C is TComboBox then Ini.WriteInteger('radiant', C.Name, TComboBox(C).ItemIndex)
        else if C is TCheckBox then Ini.WriteBool('radiant', C.Name, TCheckBox(C).Checked);
      end;
      Ini.WriteInteger('radiant', 'GiveUp', FGiveUpIdx);
    finally
      Ini.Free;
    end;
  except
    { a settings file that will not take it is not a reason to stop }
  end;
end;

procedure TRadiantForm.LoadLast;
var
  Ini: TIniFile;
  I: Integer;
  C: TComponent;
begin
  FListing := True;
  try
    try
      Ini := TIniFile.Create(ConfigFile);
      try
        if not Ini.SectionExists('radiant') then Exit;
        FGiveUpIdx := Ini.ReadInteger('radiant', 'GiveUp', 0);
        for I := 0 to ComponentCount - 1 do
        begin
          C := Components[I];
          if C = edTag then Continue;
          if not Ini.ValueExists('radiant', C.Name) then Continue;
          if C is TEdit then TEdit(C).Text := Ini.ReadString('radiant', C.Name, TEdit(C).Text)
          else if C is TComboBox then
            TComboBox(C).ItemIndex := EnsureRange(Ini.ReadInteger('radiant', C.Name, 0), 0, TComboBox(C).Items.Count - 1)
          else if C is TCheckBox then TCheckBox(C).Checked := Ini.ReadBool('radiant', C.Name, TCheckBox(C).Checked);
        end;
      finally
        Ini.Free;
      end;
    except
    end;
  finally
    FListing := False;
  end;
end;

procedure TRadiantForm.FormShow(Sender: TObject);
begin
  { right off: a manifold a zone, where a manifold goes - on a wall.  To
    be dragged from there, and searched when it is where it belongs. }
  if Length(FManifolds) = 0 then btnSuggestClick(nil)
  else Summarize;
end;

{ a search pumps messages for its bar, so the window could be closed out
  from under it: Stop first }
procedure TRadiantForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := FBusy = nil;
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
  for I := 0 to High(FLayouts) do
    if (I <= High(FSearched)) and FSearched[I] and FLayouts[I].Ok then Exit(True);
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
  { the goals the search keeps going for; blank is no goal }
  if Trim(edGoalCover.Text) = '' then Spec.GoalCoverPct := 0
  else Result := Result and TryStrToFloat(Trim(edGoalCover.Text), Spec.GoalCoverPct);
  if Trim(edGoalEven.Text) = '' then Spec.GoalEvenPct := 0
  else Result := Result and TryStrToFloat(Trim(edGoalEven.Text), Spec.GoalEvenPct);
end;

{ What is known so far, without searching anything: the ticket for every
  zone searched, a line for every zone not, the gauges over the searched
  ones, and Build only once every zone has a layout. }
procedure TRadiantForm.Summarize;
var
  Spec, ZS: TRadiantSpec;
  Z: Integer;
  Ticket: string;
  TotalFt, OrderFt, Worst, Lo, Hi, TotalArea, TotalUnfilled, Secs: Double;
  Loops, I, Waiting, Tried: Integer;
  HasEven: Boolean;
begin
  SetLength(FLayouts, Length(FZones));
  SetLength(FSearched, Length(FZones));
  if not Read(Spec) then
  begin
    lblProblem.Caption := 'A size did not read - 9, 9.5, or a foot mark.';
    FAllTicket := ''; FZoneTicket := nil;
    ListZones;
    FCoverage := -1; FEvenness := -1;
    btnBuild.Enabled := False;
    pbPlan.Invalidate; pbCoverage.Invalidate; pbEven.Invalidate;
    Exit;
  end;
  if Length(FZones) = 0 then
  begin
    lblProblem.Caption := 'Nothing is selected to fill - select the floor and run this again.';
    FAllTicket := ''; FZoneTicket := nil;
    ListZones;
    FCoverage := -1; FEvenness := -1;
    btnBuild.Enabled := False;
    pbPlan.Invalidate; pbCoverage.Invalidate; pbEven.Invalidate;
    Exit;
  end;
  lblProblem.Caption := '';
  Ticket := '';
  if Spec.Tag <> '' then Ticket := Spec.Tag + LineEnding + LineEnding;
  SetLength(FZoneTicket, Length(FZones));
  TotalFt := 0; OrderFt := 0; Loops := 0; TotalArea := 0; TotalUnfilled := 0; Waiting := 0;
  for Z := 0 to High(FZones) do
  begin
    ZS := ZoneSpec(Z, Spec);
    if lblProblem.Caption = '' then lblProblem.Caption := RadiantProblem(FZones[Z].Outline, ZS);
    Ticket := Ticket + Format('===== ZONE %d =====', [Z + 1]) + LineEnding;
    if not FSearched[Z] then
    begin
      Inc(Waiting);
      Ticket := Ticket + 'not searched yet' + LineEnding + LineEnding;
      FZoneTicket[Z] := 'not searched yet - Search this zone, or right-click its manifold';
      Continue;
    end;
    if not FLayouts[Z].Ok and (lblProblem.Caption = '') then
      lblProblem.Caption := Format('Zone %d: %s', [Z + 1, FLayouts[Z].Why]);
    { the waste is only the order, never the layout - typed after a
      search, it changes the order without asking for the search again }
    FLayouts[Z].OrderFt := FLayouts[Z].TotalFt * (1 + ZS.WastePct / 100);
    FZoneTicket[Z] := RadiantTicketText(ZS, FLayouts[Z], FUnits);
    { which of the layouts the search kept this is }
    if (Z <= High(FSolutions)) and (Length(FSolutions[Z]) > 1) then
      FZoneTicket[Z] := FZoneTicket[Z] + Format('layout %d of the %d the search kept', [FSolIdx[Z] + 1,
        Length(FSolutions[Z])]) + LineEnding;
    Ticket := Ticket + FZoneTicket[Z] + LineEnding;
    if FLayouts[Z].Ok then
    begin
      TotalFt := TotalFt + FLayouts[Z].TotalFt;
      OrderFt := OrderFt + FLayouts[Z].OrderFt;
      Loops := Loops + Length(FLayouts[Z].Loops);
      TotalArea := TotalArea + FLayouts[Z].AreaSqFt;
      TotalUnfilled := TotalUnfilled + FLayouts[Z].UnfilledSqFt;
    end;
  end;
  { the two gauges, over the zones searched: how much of the floor the
    layout actually reaches, and how close the loops of each zone come
    to one another in length - green when they are, red when they are
    not }
  if TotalArea > 0 then FCoverage := Max(0, Min(1, 1 - TotalUnfilled / TotalArea))
  else FCoverage := -1;
  Worst := 0; HasEven := False; FEvenFt := 0;
  for Z := 0 to High(FLayouts) do
    if FSearched[Z] and FLayouts[Z].Ok and (Length(FLayouts[Z].Loops) > 0) then
    begin
      HasEven := True;
      if Length(FLayouts[Z].Loops) > 1 then
      begin
        Lo := 1E300; Hi := 0;
        for I := 0 to High(FLayouts[Z].Loops) do
        begin
          Lo := Min(Lo, FLayouts[Z].Loops[I].LenFt); Hi := Max(Hi, FLayouts[Z].Loops[I].LenFt);
        end;
        if (Hi > 0) and ((Hi - Lo) / Hi >= Worst) then
        begin
          Worst := (Hi - Lo) / Hi;
          FEvenFt := Hi - Lo;
        end;
      end;
    end;
  if HasEven then FEvenness := 1 - Worst else FEvenness := -1;
  if Length(FZones) > 1 then
  begin
    Ticket := Ticket + '===== ALL ZONES =====' + LineEnding +
      Format('%d of %d zones searched, %d loops', [Length(FZones) - Waiting, Length(FZones), Loops]) + LineEnding +
      'total tube, no waste: ' + FormatLen(TotalFt, FUnits) + LineEnding +
      'order: ' + FormatLen(OrderFt, FUnits) + LineEnding;
    { the effort, all told }
    Secs := 0; Tried := 0;
    for Z := 0 to High(FLayouts) do
      if FSearched[Z] then
      begin
        Secs := Secs + FLayouts[Z].SearchSecs;
        Tried := Tried + FLayouts[Z].Tries;
      end;
    if Tried > 0 then
      Ticket := Ticket + Format('searching: %d layouts tried in %s', [Tried, RadiantDuration(Secs)]) + LineEnding;
  end;
  if Waiting = Length(FZones) then
    lblNeed.Caption := Format('%d zone%s, none searched yet - place the manifolds, then Search',
      [Length(FZones), IfThen(Length(FZones) = 1, '', 's')])
  else if Waiting > 0 then
    lblNeed.Caption := Format('%d of %d zones searched, %d routed loops - right-click a manifold to search its zone',
      [Length(FZones) - Waiting, Length(FZones), Loops])
  else
    lblNeed.Caption := Format('%d zone%s, %d routed loops - manifold sizes follow the layout',
      [Length(FZones), IfThen(Length(FZones) = 1, '', 's'), Loops]);
  FAllTicket := Ticket;
  btnBuild.Enabled := (Waiting = 0) and AnyLayout and (lblProblem.Caption = '');
  ListZones;
  pbPlan.Invalidate; pbCoverage.Invalidate; pbEven.Invalidate;
end;

function TRadiantForm.ZoneSpec(Z: Integer; const Spec: TRadiantSpec): TRadiantSpec;
var
  ZF: TRadiantFrame;
  Ca, Sa: Double;
  Wv: TP3;
begin
  Result := Spec;
  SetLength(Result.Manifolds, 1); SetLength(Result.Ports, 1);
  Result.Manifolds[0] := FManifolds[Z]; Result.Ports[0] := FPorts[Z];
  { the plan turns every zone in the first zone's frame; the layout and
    the build read a heading in the zone's own }
  SetLength(Result.ManifoldAngles, 1);
  Result.ManifoldAngles[0] := 0;
  if (Z <= High(FAngles)) and (Length(FZones[Z].Outline) >= 3) then
  begin
    ZF := RadiantFrameOf(FZones[Z].Outline);
    Ca := Cos(DegToRad(FAngles[Z])); Sa := Sin(DegToRad(FAngles[Z]));
    Wv := P3(FFrame.U.X * Ca + FFrame.V.X * Sa, FFrame.U.Y * Ca + FFrame.V.Y * Sa,
      FFrame.U.Z * Ca + FFrame.V.Z * Sa);
    Result.ManifoldAngles[0] := RadToDeg(ArcTan2(Dot3(Wv, ZF.V), Dot3(Wv, ZF.U)));
  end;
  Result.Tag := '';
end;

{ the heading of zone Z's wall nearest its manifold, in the plan's frame
  - a manifold hangs on a wall, long side along it }
function TRadiantForm.WallAngle(Z: Integer): Double;
var
  I, J: Integer;
  A, B, M: T2;
  T, L, D, Best: Double;
  Curved: Boolean;
begin
  Result := 0;
  Curved := False;
  if (Z < 0) or (Z > High(FZones)) or (Z > High(FManifolds)) then Exit;
  M := RadiantTo2(FFrame, FManifolds[Z]);
  Best := 1E300;
  for I := 0 to High(FZones[Z].Outline) do
  begin
    J := (I + 1) mod Length(FZones[Z].Outline);
    A := RadiantTo2(FFrame, FZones[Z].Outline[I]);
    B := RadiantTo2(FFrame, FZones[Z].Outline[J]);
    L := Sqr(B.X - A.X) + Sqr(B.Y - A.Y);
    if L < 1E-12 then Continue;
    T := Max(0, Min(1, ((M.X - A.X) * (B.X - A.X) + (M.Y - A.Y) * (B.Y - A.Y)) / L));
    D := Hypot(M.X - A.X - T * (B.X - A.X), M.Y - A.Y - T * (B.Y - A.Y));
    if D < Best then
    begin
      Best := D;
      Result := RadToDeg(ArcTan2(B.Y - A.Y, B.X - A.X));
      Curved := RadiantEdgeCurved(FZones[Z].Outline, I);
    end;
  end;
  { A piece of a curve is no wall to square to: a chord of the circle ran
    at whatever angle it ran, and the quarter turn kept it (report
    174734).  Square to the sheet, whichever of the two is nearer. }
  if Curved then Result := 90 * Round(Result / 90);
  { a heading, not a direction: 0 up to 180 }
  while Result < 0 do Result := Result + 180;
  while Result >= 180 do Result := Result - 180;
end;

{ zone Z's manifold as the box it is - 18 by 6 inches, turned to its
  heading - but never smaller on the plan than something a pointer can
  take hold of.  Kept small even so: the manifolds of a building are
  suggested a couple of feet apart at the zones' common corner, and a
  bigger box drew one clean over another - four zones showed three. }
function TRadiantForm.ManifoldBox(Z: Integer): T2Array;
var
  Spec: TRadiantSpec;
  C: T2;
  W, H, Ca, Sa: Double;
  K: Integer;
const
  SX: array[0..3] of Integer = (-1, 1, 1, -1);
  SY: array[0..3] of Integer = (-1, -1, 1, 1);
begin
  SetLength(Result, 4);
  C := RadiantTo2(FFrame, FManifolds[Z]);
  Spec := DefaultRadiantSpec;
  W := Spec.ManifoldW; H := Spec.ManifoldH;
  if FSc > 0 then
  begin
    W := Max(W, 14 / FSc); H := Max(H, 7 / FSc);
  end;
  Ca := Cos(DegToRad(FAngles[Z])); Sa := Sin(DegToRad(FAngles[Z]));
  for K := 0 to 3 do
    Result[K] := Point2(C.X + SX[K] * W / 2 * Ca - SY[K] * H / 2 * Sa,
      C.Y + SX[K] * W / 2 * Sa + SY[K] * H / 2 * Ca);
end;

{ the manifold whose box is under the pixel - the nearest, where boxes
  crowd together - or -1 }
function TRadiantForm.ManifoldAt(X, Y: Integer): Integer;
var
  Z: Integer;
  M, C: T2;
  U, V, W, H, Ca, Sa, Slack, D, Best: Double;
  Spec: TRadiantSpec;
begin
  Result := -1;
  if FSc <= 0 then Exit;
  M := Point2(PlanU(X), PlanV(Y));
  Spec := DefaultRadiantSpec;
  Slack := 4 / FSc;
  Best := 1E300;
  for Z := 0 to High(FManifolds) do
  begin
    C := RadiantTo2(FFrame, FManifolds[Z]);
    W := Max(Spec.ManifoldW, 14 / FSc); H := Max(Spec.ManifoldH, 7 / FSc);
    Ca := Cos(DegToRad(FAngles[Z])); Sa := Sin(DegToRad(FAngles[Z]));
    { into the box's own axes }
    U := (M.X - C.X) * Ca + (M.Y - C.Y) * Sa;
    V := -(M.X - C.X) * Sa + (M.Y - C.Y) * Ca;
    if (Abs(U) > W / 2 + Slack) or (Abs(V) > H / 2 + Slack) then Continue;
    D := Sqr(M.X - C.X) + Sqr(M.Y - C.Y);
    if D < Best then begin Best := D; Result := Z; end;
  end;
end;

procedure TRadiantForm.miRotateClick(Sender: TObject);
var
  Z: Integer;
begin
  Z := SelectedZone;
  if (Z < 0) or (Z > High(FAngles)) then Exit;
  FAngles[Z] := FAngles[Z] + 90;
  if FAngles[Z] >= 180 then FAngles[Z] := FAngles[Z] - 180;
  ClearZone(Z);
  Summarize;
end;

{ The manifold set square to the sheet, or on a diagonal - the owner, 25
  September (reports 173001 and 174734): on a round zone it hung on a
  chord of the circle at whatever angle that ran, a quarter turn kept the
  angle, and "its still not square to the paper... give some fixed
  squared options".  The tag is the heading in the plan, which is the
  drawing's own: 0 the long side east - west. }
procedure TRadiantForm.miFaceClick(Sender: TObject);
var
  Z: Integer;
begin
  Z := SelectedZone;
  if (Z < 0) or (Z > High(FAngles)) or not (Sender is TMenuItem) then Exit;
  FAngles[Z] := TMenuItem(Sender).Tag;
  ClearZone(Z);
  Summarize;
end;

procedure TRadiantForm.ClearZone(Z: Integer);
begin
  if (Z < 0) or (Z > High(FZones)) then Exit;
  SetLength(FLayouts, Length(FZones));
  SetLength(FSearched, Length(FZones));
  FLayouts[Z] := Default(TRadiantResult);
  FSearched[Z] := False;
  SetLength(FSolutions, Length(FZones)); SetLength(FSolIdx, Length(FZones));
  FSolutions[Z] := nil; FSolIdx[Z] := 0;
end;

procedure TRadiantForm.ClearAll;
var
  Z: Integer;
begin
  for Z := 0 to High(FZones) do ClearZone(Z);
end;

{ the zone whose tab is up; -1 on the All zones tab }
function TRadiantForm.SelectedZone: Integer;
begin
  Result := tcZones.TabIndex;
  if (Result < 0) or (Result > High(FZones)) then Result := -1;
end;

procedure TRadiantForm.SelectZone(Z: Integer);
begin
  if (Z < 0) or (Z > High(FZones)) or (Z >= tcZones.Tabs.Count) then Exit;
  if tcZones.TabIndex <> Z then tcZones.TabIndex := Z;
  ShowZonePanel;
  pbPlan.Invalidate;
end;

procedure TRadiantForm.tcZonesChange(Sender: TObject);
begin
  ShowZonePanel;
  pbPlan.Invalidate;
end;

{ One tab a zone, and All zones after them when there is more than one;
  the tab that was up stays up. }
procedure TRadiantForm.ListZones;
var
  Z, Was, N: Integer;
begin
  Was := tcZones.TabIndex;
  N := Length(FZones);
  if N > 1 then Inc(N);
  if tcZones.Tabs.Count <> N then
  begin
    tcZones.Tabs.BeginUpdate;
    try
      tcZones.Tabs.Clear;
      for Z := 0 to High(FZones) do tcZones.Tabs.Add(Format('Zone %d', [Z + 1]));
      if Length(FZones) > 1 then tcZones.Tabs.Add('All zones');
    finally
      tcZones.Tabs.EndUpdate;
    end;
  end;
  if (Was >= 0) and (Was < tcZones.Tabs.Count) then tcZones.TabIndex := Was
  else if tcZones.Tabs.Count > 0 then tcZones.TabIndex := 0;
  ShowZonePanel;
end;

{ The panel under the tabs: the zone's manifold and how its search went,
  the layouts its search kept - click one and it is the zone's - and its
  material list; on All zones, the whole list. }
procedure TRadiantForm.ShowZonePanel;
var
  Z, I: Integer;
  P: T2;
  S: string;
begin
  Z := SelectedZone;
  FListing := True;
  try
    lbSolutions.Items.BeginUpdate;
    try
      lbSolutions.Items.Clear;
      if (Z >= 0) and (Z <= High(FSolutions)) then
        for I := 0 to High(FSolutions[Z]) do lbSolutions.Items.Add(ShortLine(FSolutions[Z][I]));
    finally
      lbSolutions.Items.EndUpdate;
    end;
    if (Z >= 0) and (Z <= High(FSolIdx)) and (FSolIdx[Z] < lbSolutions.Items.Count) then
      lbSolutions.ItemIndex := FSolIdx[Z];
  finally
    FListing := False;
  end;
  btnZoneSearch.Enabled := (Z >= 0) and (FBusy = nil);
  btnZoneClear.Enabled := (Z >= 0) and (Z <= High(FSearched)) and FSearched[Z];
  lbSolutions.Enabled := Z >= 0;
  lblFoundHead.Enabled := Z >= 0;
  if Z < 0 then
  begin
    lblZoneHead.Caption := Format('Every zone: %d of them.  Pick a zone''s tab, or click it on the plan, to work on it.',
      [Length(FZones)]);
    memTicket.Lines.Text := FAllTicket;
    Exit;
  end;
  if Length(FOutline) >= 3 then FFrame := RadiantPlanFrame(FOutline);
  S := '';
  if Z <= High(FManifolds) then
  begin
    P := RadiantTo2(FFrame, FManifolds[Z]);
    S := Format('Manifold at %s along, %s in', [FormatLen(P.X, FUnits), FormatLen(P.Y, FUnits)]);
    if Z <= High(FAngles) then S := S + Format(', long side at %s degrees', [FormatFloat('0', FAngles[Z])]);
  end;
  if (Z > High(FSearched)) or not FSearched[Z] then S := S + ' - not searched yet.'
  else if FLayouts[Z].Ok then
  begin
    if Length(FLayouts[Z].Manifolds) > 0 then S := S + Format(' - a %d-loop manifold.', [FLayouts[Z].Manifolds[0].Ports]);
    S := S + Format('  Searched %d layouts in %s.', [FLayouts[Z].Tries, RadiantDuration(FLayouts[Z].SearchSecs)]);
  end
  else S := S + ' - no layout.';
  lblZoneHead.Caption := S;
  if Z <= High(FZoneTicket) then memTicket.Lines.Text := FZoneTicket[Z] else memTicket.Lines.Text := '';
end;

procedure TRadiantForm.lbSolutionsClick(Sender: TObject);
var
  Z: Integer;
begin
  if FListing then Exit;
  Z := SelectedZone;
  if (Z >= 0) and (lbSolutions.ItemIndex >= 0) then ShowSolution(Z, lbSolutions.ItemIndex);
end;

{ Search the zones in Which, one after another, under the busy window.
  Everything but that window is disabled while it runs, so nothing can
  be dragged or typed into a layout that is half worked out.  A zone
  stopped part way keeps the best it had, and its record says so. }
procedure TRadiantForm.Search(const Which: array of Integer);
var
  K: Integer;
begin
  if FBusy <> nil then Exit;
  if not Read(FWorkSpec) or (Length(FZones) = 0) or (Length(Which) = 0) then begin Summarize; Exit; end;
  SetLength(FLayouts, Length(FZones));
  SetLength(FSearched, Length(FZones));
  SetLength(FWorkZones, Length(Which));
  for K := 0 to High(Which) do FWorkZones[K] := Which[K];
  SaveLast;
  { the search runs inside the busy window, shown modal over this one -
    see uRadiantBusy for why it cannot be the other way round }
  FBusy := TRadiantBusyForm.CreateBusy(Self);
  try
    FBusy.OnWork := @SearchWork;
    FLiveGoals.CoverPct := FWorkSpec.GoalCoverPct;
    FLiveGoals.EvenPct := FWorkSpec.GoalEvenPct;
    FBusy.SetGoals(FLiveGoals.CoverPct, FLiveGoals.EvenPct);
    FBusy.cbGiveUp.ItemIndex := EnsureRange(FGiveUpIdx, 0, FBusy.cbGiveUp.Items.Count - 1);
    FBusy.ShowModal;
    { goals changed while it searched are the goals now }
    FGiveUpIdx := FBusy.cbGiveUp.ItemIndex;
    FListing := True;
    try
      edGoalCover.Text := FormatFloat('0.#', FLiveGoals.CoverPct);
      edGoalEven.Text := FormatFloat('0.#', FLiveGoals.EvenPct);
    finally
      FListing := False;
    end;
    SaveLast;
  finally
    FreeAndNil(FBusy);
  end;
  Summarize;
end;

{ the zones asked for, one after another, the busy window up the while }
procedure TRadiantForm.SearchWork(Sender: TObject);
var
  K, Z, I: Integer;
  R: TRadiantResult;
  Picked: string;
  Began: TDateTime;
  Extra: TStringArray;
begin
  FBusyCount := Length(FWorkZones);
  for K := 0 to High(FWorkZones) do
  begin
    Z := FWorkZones[K];
    if (Z < 0) or (Z > High(FZones)) then Continue;
    FBusyIndex := K;
    ClearZone(Z);
    FBusy.Stage(Format('Zone %d%s', [Z + 1, IfThen(FBusyCount > 1,
      Format(' - %d of %d', [K + 1, FBusyCount]), '')]), 'Starting the search...',
      Round(100 * K / FBusyCount));
    FLiveFound := nil;
    FZoneStart := GetTickCount64;
    FStopWhy := '';
    Began := Now;
    R := ComputeRadiantLayout(FZones[Z].Outline, ZoneHoles(Z), ZoneSpec(Z, FWorkSpec),
      False, @SearchProgress, @FLiveFound, @FLiveGoals);
    SetLength(FSolutions, Length(FZones)); SetLength(FSolIdx, Length(FZones));
    FSolutions[Z] := FLiveFound; FSolIdx[Z] := 0;
    FLiveFound := nil;
    { what the search hands back is its best, the first of the ones it
      kept }
    if Length(FSolutions[Z]) > 0 then FSolutions[Z][0] := R
    else begin SetLength(FSolutions[Z], 1); FSolutions[Z][0] := R; end;
    { the record, every solution's: when, and how it ended when that was
      not by itself }
    Extra := nil;
    SetLength(Extra, 1);
    Extra[0] := 'searched ' + FormatDateTime('yyyy-mm-dd hh:nn', Began);
    if FStopWhy <> '' then
    begin
      SetLength(Extra, 2);
      Extra[1] := FStopWhy;
    end;
    { one picked from the busy window's list is the one shown }
    Picked := FBusy.Picked;
    if Picked <> '' then
      for I := 0 to High(FSolutions[Z]) do
        if FoundLine(FSolutions[Z][I]) = Picked then
        begin
          FSolIdx[Z] := I;
          SetLength(Extra, Length(Extra) + 1);
          Extra[High(Extra)] := Format('layout %d of %d picked by hand in the search window', [I + 1, Length(FSolutions[Z])]);
          Break;
        end;
    for I := 0 to High(FSolutions[Z]) do
      FSolutions[Z][I].SearchLog := Concat(Extra, FSolutions[Z][I].SearchLog);
    R := FSolutions[Z][FSolIdx[Z]];
    { stopped, it hands back the best it had - kept, and the ticket says
      if it fell short of the goals }
    FLayouts[Z] := R;
    FSearched[Z] := True;
    if R.Ok and (Length(R.Manifolds) > 0) then
    begin
      FPorts[Z] := R.Manifolds[0].Ports;
      { where the layout has it - the search may have slid it along its
        wall, and the plan shows the manifold the layout was laid from }
      FManifolds[Z] := R.Manifolds[0].At;
    end;
    { each zone shows as it comes, not all at the end, its tab up }
    Summarize;
    SelectZone(Z);
    { Stop kept this zone's best; Stop all, and there is no next zone }
    if FBusy.StoppingAll then Break;
    FBusy.NextZone;
  end;
end;

{ The fixed restarts first, as a fraction; then - the goals not met -
  layouts tried at random for as long as it takes or until Stop, the bar
  showing the best coverage so far against the goal. }
procedure TRadiantForm.SearchProgress(Done, Total: Integer; const Best: TRadiantResult; var Stop: Boolean);
var
  Cover, Spread: Double;
  Now_: string;
  Lines: array of string;
  I: Integer;
begin
  if FBusy = nil then Exit;
  { the goals as typed in the busy window now - the search reads them
    back when this returns }
  FBusy.ReadGoals(FLiveGoals.CoverPct, FLiveGoals.EvenPct);
  FWorkSpec.GoalCoverPct := FLiveGoals.CoverPct;
  FWorkSpec.GoalEvenPct := FLiveGoals.EvenPct;
  { what it has kept so far, best first, for the owner to pick from -
    before the stage line, which paints the window }
  SetLength(Lines, Length(FLiveFound));
  for I := 0 to High(FLiveFound) do Lines[I] := FoundLine(FLiveFound[I]);
  FBusy.ShowFound(Lines);
  RadiantMeasure(Best, Cover, Spread);
  if Best.Ok then
    Now_ := Format('best so far: %s%% covered, loops within %s%% (%s ft), %d loops',
      [FormatFloat('0.0', Cover * 100), FormatFloat('0', Spread * 100), FormatFloat('0', RadiantSpreadFt(Best)),
       Length(Best.Loops)])
  else Now_ := 'no layout yet';
  if Total > 0 then
    FBusy.Stage(FBusy.lblStage.Caption,
      Format('Restart %d of %d - %s', [Done, Total, Now_]),
      Round(100 * (FBusyIndex + Done / Total) / Max(1, FBusyCount)))
  else
    FBusy.Stage(FBusy.lblStage.Caption,
      Format('Still after the goals - layout %d tried.  %s.  Stop keeps it.', [Done, Now_]),
      Round(100 * Cover));
  Stop := FBusy.Stopping;
  if Stop and (FStopWhy = '') then FStopWhy := Format('stopped by hand at layout %d', [Done]);
  if not Stop and (FBusy.GiveUpSecs > 0) and (GetTickCount64 - FZoneStart > QWord(FBusy.GiveUpSecs) * 1000) then
  begin
    Stop := True;
    FStopWhy := Format('gave up after %s, at layout %d', [RadiantDuration(FBusy.GiveUpSecs), Done]);
  end;
end;

function TRadiantForm.FoundLine(const R: TRadiantResult): string;
var
  Cover, Spread: Double;
begin
  RadiantMeasure(R, Cover, Spread);
  Result := Format('%5s%% covered  %4s%% apart (%3s ft)  %2d loops  %4d bends  %5s ft%s',
    [FormatFloat('0.0', Cover * 100), FormatFloat('0.0', Spread * 100), FormatFloat('0', RadiantSpreadFt(R)),
     Length(R.Loops), R.Bends, FormatFloat('0', R.TotalFt), IfThen(RadiantMeetsGoals(R, FWorkSpec), '  ok', '')]);
end;

function TRadiantForm.ShortLine(const R: TRadiantResult): string;
var
  Cover, Spread: Double;
begin
  RadiantMeasure(R, Cover, Spread);
  Result := Format('%5s%%  %3s%% (%3s ft)  %2d loops  %3d bends%s',
    [FormatFloat('0.0', Cover * 100), FormatFloat('0', Spread * 100), FormatFloat('0', RadiantSpreadFt(R)),
     Length(R.Loops), R.Bends, IfThen(RadiantMeetsGoals(R, FWorkSpec), '  ok', '')]);
end;

procedure TRadiantForm.btnSearchZoneClick(Sender: TObject);
begin
  if SelectedZone >= 0 then Search([SelectedZone]);
end;

procedure TRadiantForm.btnSearchAllClick(Sender: TObject);
var
  Which: TIntArray;
  Z: Integer;
begin
  SetLength(Which, Length(FZones));
  for Z := 0 to High(FZones) do Which[Z] := Z;
  Search(Which);
end;

procedure TRadiantForm.miSearchZoneClick(Sender: TObject);
begin
  btnSearchZoneClick(Sender);
end;

procedure TRadiantForm.miClearZoneClick(Sender: TObject);
begin
  ClearZone(SelectedZone);
  Summarize;
end;

procedure TRadiantForm.miClearAllClick(Sender: TObject);
begin
  ClearAll;
  Summarize;
end;

{ the menu names the zone it will act on - the one right-clicked, which
  the mouse-down on the plan or the list has already selected }
procedure TRadiantForm.pmZonePopup(Sender: TObject);
var
  Z: Integer;
begin
  Z := SelectedZone;
  miSearchZone.Enabled := (Z >= 0) and (FBusy = nil);
  miClearZone.Enabled := Z >= 0;
  miRotate.Enabled := (Z >= 0) and (FBusy = nil);
  miFace.Enabled := (Z >= 0) and (FBusy = nil);
  miSearchAll.Enabled := (Length(FZones) > 0) and (FBusy = nil);
  if Z >= 0 then
  begin
    miSearchZone.Caption := Format('Search zone %d', [Z + 1]);
    miClearZone.Caption := Format('Clear zone %d', [Z + 1]);
  end;
end;

{ what the tube itself may do changed: every zone's layout is stale }
procedure TRadiantForm.RoutingChange(Sender: TObject);
begin
  if FListing then Exit;
  ClearAll;
  Summarize;
end;

{ the waste or the tag: the ticket only }
procedure TRadiantForm.AnyChange(Sender: TObject);
begin
  if FListing then Exit;
  Summarize;
end;

{ ---- manifolds ---- }

procedure TRadiantForm.btnSuggestClick(Sender: TObject);
var
  Spec: TRadiantSpec;
  Z, I, N: Integer;
  Mid: TP3;
begin
  if not Read(Spec) or (Length(FZones) = 0) then begin Summarize; Exit; end;
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
  if Length(FOutline) >= 3 then FFrame := RadiantPlanFrame(FOutline);
  SetLength(FAngles, Length(FZones));
  for Z := 0 to High(FZones) do FAngles[Z] := WallAngle(Z);
  ClearAll;
  Summarize;
end;

{ The zone selected shows, and will build, the solution Idx of the ones its
  last search kept - wrapping round at either end. }
procedure TRadiantForm.ShowSolution(Z, Idx: Integer);
var
  N: Integer;
begin
  if (Z < 0) or (Z > High(FSolutions)) then Exit;
  N := Length(FSolutions[Z]);
  if N = 0 then Exit;
  Idx := ((Idx mod N) + N) mod N;
  FSolIdx[Z] := Idx;
  FLayouts[Z] := FSolutions[Z][Idx];
  if FLayouts[Z].Ok and (Length(FLayouts[Z].Manifolds) > 0) then
  begin
    FPorts[Z] := FLayouts[Z].Manifolds[0].Ports;
    FManifolds[Z] := FLayouts[Z].Manifolds[0].At;
  end;
  Summarize;
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
    if Length(FOutline) >= 3 then FFrame := RadiantPlanFrame(FOutline);
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
  FFrame := RadiantPlanFrame(FOutline);
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
  ClearAll;
  Summarize;
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
  ClearAll;
  Summarize;
end;

{ ---- the plan, and dragging on it ---- }

function TRadiantForm.PlanX(U: Double): Integer;
begin
  Result := Round(FMargin + FOffX + (U - FMinX) * FSc);
end;

function TRadiantForm.PlanY(V: Double): Integer;
begin
  Result := Round(pbPlan.Height - FMargin - FOffY - (V - FMinY) * FSc);
end;

function TRadiantForm.PlanU(X: Integer): Double;
begin
  if FSc <= 0 then Exit(0);
  Result := FMinX + (X - FMargin - FOffX) / FSc;
end;

function TRadiantForm.PlanV(Y: Integer): Double;
begin
  if FSc <= 0 then Exit(0);
  Result := FMinY + (pbPlan.Height - FMargin - FOffY - Y) / FSc;
end;

procedure TRadiantForm.pbPlanMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
  P, M: T2;
begin
  if (Length(FOutline) < 3) or (FSc <= 0) or (FBusy <> nil) then Exit;
  M := Point2(PlanU(X), PlanV(Y));
  if Button = mbRight then
  begin
    { the zone the menu that follows acts on: the manifold under the
      pointer, or the zone the pointer is in, or what was selected }
    I := ManifoldAt(X, Y);
    if I < 0 then
      for I := High(FZones) downto 0 do
        if RadiantInside(FZones[I].Outline, RadiantFrom2(FFrame, M.X, M.Y)) then Break;
    if I >= 0 then SelectZone(I);
    pbPlan.Invalidate;
    Exit;
  end;
  if Button <> mbLeft then Exit;
  { a manifold under the pointer; then an obstacle }
  FDragManifold := ManifoldAt(X, Y); FDragObstacle := -1; FDragMoved := False;
  if FDragManifold >= 0 then
  begin
    P := RadiantTo2(FFrame, FManifolds[FDragManifold]);
    FDragOff := Point2(P.X - M.X, P.Y - M.Y);
    SelectZone(FDragManifold);
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
  { nothing to drag: the zone clicked in, its tab up (the owner, 25
    September: "clicking in a zone in the image should show the
    respective panel") }
  for I := High(FZones) downto 0 do
    if RadiantInside(FZones[I].Outline, RadiantFrom2(FFrame, M.X, M.Y)) then
    begin
      SelectZone(I);
      Exit;
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
    { the layout was for where it stood: gone the moment it moves, and
      only this zone's - an obstacle is every zone's }
    if not FDragMoved then ClearZone(FDragManifold);
  end
  else
  begin
    MoveObstacle(FDragObstacle, M);
    if not FDragMoved then ClearAll;
    ListObstacles;
  end;
  FDragMoved := True;
  pbPlan.Invalidate;
end;

procedure TRadiantForm.pbPlanMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FDragManifold := -1;
  FDragObstacle := -1;
  if FDragMoved then Summarize;
  FDragMoved := False;
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
  if FCoverage < 0 then PaintGauge(pbCoverage, -1, 'Coverage - search a zone to see it')
  else PaintGauge(pbCoverage, FCoverage, Format('Coverage: %d%% of the floor reached', [Round(FCoverage * 100)]));
end;

procedure TRadiantForm.pbEvenPaint(Sender: TObject);
begin
  if FEvenness < 0 then PaintGauge(pbEven, -1, 'Evenness - how close the loop lengths come')
  else PaintGauge(pbEven, FEvenness, Format('Evenness: loops within %d%% (%s ft) of each other',
    [Round((1 - FEvenness) * 100), FormatFloat('0', FEvenFt)]));
end;

{ The plan: the outline, its holes shaded, every loop in its own color so
  a long run is easy to follow by eye, and the manifolds as numbered
  squares that can be taken hold of. }
procedure TRadiantForm.pbPlanPaint(Sender: TObject);
type
  TPtArr = array of TPoint;
var
  C: TCanvas;
  W, H, I, J, Z, Loops, Waiting: Integer;
  MaxX, MaxY: Double;
  P: T2;
  S: string;
  Box: T2Array;
  BoxPx: TPtArr;
  Order: TIntArray;
  K, LX, LY: Integer;
  Mid, Q: T2;
  Off: Double;

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
  FFrame := RadiantPlanFrame(FOutline);
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
  FOffX := Max(0, (W - 2 * FMargin - (MaxX - FMinX) * FSc) / 2);
  FOffY := Max(0, (H - 2 * FMargin - (MaxY - FMinY) * FSc) / 2);

  for Z := 0 to High(FZones) do
  begin
    C.Pen.Color := clBlack; C.Pen.Width := 2; C.Brush.Style := bsClear;
    { the zone whose tab is up, lightly tinted }
    if Z = SelectedZone then begin C.Brush.Style := bsSolid; C.Brush.Color := $00E6F7FF; end;
    C.Polygon(Poly(FZones[Z].Outline));
    C.Brush.Style := bsClear;
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
    if (Z <= High(FSearched)) and FSearched[Z] and FLayouts[Z].Ok then
      for I := 0 to High(FLayouts[Z].Loops) do
      begin
        { every loop its own color - what the build draws }
        C.Pen.Color := LoopInk(Z, I);
        C.Pen.Width := Round(LoopWeight(I));
        for J := 1 to High(FLayouts[Z].Loops[I].Pts) do
        begin
          P := RadiantTo2(FFrame, FLayouts[Z].Loops[I].Pts[J - 1]);
          C.MoveTo(PlanX(P.X), PlanY(P.Y));
          P := RadiantTo2(FFrame, FLayouts[Z].Loops[I].Pts[J]);
          C.LineTo(PlanX(P.X), PlanY(P.Y));
        end;
      end;
  { the manifolds last, on top: each the box it is, turned the way it
    hangs, the one selected over the rest; its number is set off toward
    the middle of its own zone, so four manifolds at one corner still
    read as four }
  C.Pen.Width := 1;
  SetLength(FAngles, Length(FManifolds));
  SetLength(Order, 0);
  for I := 0 to High(FManifolds) do
    if I <> SelectedZone then
    begin
      SetLength(Order, Length(Order) + 1); Order[High(Order)] := I;
    end;
  if (SelectedZone >= 0) and (SelectedZone <= High(FManifolds)) then
  begin
    SetLength(Order, Length(Order) + 1); Order[High(Order)] := SelectedZone;
  end;
  for K := 0 to High(Order) do
  begin
    I := Order[K];
    P := RadiantTo2(FFrame, FManifolds[I]);
    if SelectedZone = I then C.Brush.Color := clYellow else C.Brush.Color := clWhite;
    C.Brush.Style := bsSolid;
    C.Pen.Color := ZoneInk(I);
    C.Pen.Width := 2;
    Box := ManifoldBox(I);
    SetLength(BoxPx, 4);
    for J := 0 to 3 do BoxPx[J] := Point(PlanX(Box[J].X), PlanY(Box[J].Y));
    C.Polygon(BoxPx);
    { the number, a little way toward the middle of its zone }
    Mid := Point2(0, 0);
    if I <= High(FZones) then
      for J := 0 to High(FZones[I].Outline) do
      begin
        Q := RadiantTo2(FFrame, FZones[I].Outline[J]);
        Mid.X := Mid.X + Q.X / Length(FZones[I].Outline);
        Mid.Y := Mid.Y + Q.Y / Length(FZones[I].Outline);
      end;
    Off := Hypot(PlanX(Mid.X) - PlanX(P.X), PlanY(Mid.Y) - PlanY(P.Y));
    if Off > 1 then
    begin
      LX := PlanX(P.X) + Round(16 * (PlanX(Mid.X) - PlanX(P.X)) / Off);
      LY := PlanY(P.Y) + Round(16 * (PlanY(Mid.Y) - PlanY(P.Y)) / Off);
    end
    else begin LX := PlanX(P.X); LY := PlanY(P.Y); end;
    { black on a patch of white: in the zone's own ink it vanished into
      the zone's own tube the moment there was any }
    S := IntToStr(I + 1);
    C.Brush.Style := bsSolid; C.Brush.Color := clWhite;
    C.Font.Color := clBlack;
    C.TextOut(LX - C.TextWidth(S) div 2, LY - C.TextHeight(S) div 2, S);
  end;
  C.Brush.Style := bsClear;
  C.Font.Color := clGray;
  Loops := 0; Waiting := 0;
  for Z := 0 to High(FLayouts) do
    if (Z <= High(FSearched)) and FSearched[Z] then
    begin
      if FLayouts[Z].Ok then Loops := Loops + Length(FLayouts[Z].Loops);
    end
    else Inc(Waiting);
  if Waiting > 0 then
    C.TextOut(8, H - 20, Format('%d zone(s) not searched - place the manifolds, then right-click one: Search',
      [Waiting]))
  else if not AnyLayout then C.TextOut(8, H - 20, 'no layout found - move a manifold and search again')
  else C.TextOut(8, H - 20, Format('%d zone(s), %d loop(s) - drag a manifold, right-click to turn it',
    [Length(FZones), Loops]));
  PaintCompass(C, W - 34, 62);
end;

{ Which way north is on the plan, at CX, CY - the owner, 25 September:
  "in the previews of the different builders we should have the compass!
  then i would have noticed this long ago" (the plan had been drawn turned
  and mirrored).  North is the drawing's green axis, east its red, carried
  through the plan's own frame, so the rose says what the plan shows even
  when it is not the drawing's plan. }
procedure TRadiantForm.PaintCompass(C: TCanvas; CX, CY: Integer);
const
  R = 16;
  TAGS: array[0..3] of string = ('N', 'E', 'S', 'W');
var
  K: Integer;
  NU, NV, EU, EV, L, DX, DY: Double;
begin
  NU := FFrame.U.Y; NV := FFrame.V.Y;
  EU := FFrame.U.X; EV := FFrame.V.X;
  L := Hypot(NU, NV);
  if L < 0.2 then Exit;
  NU := NU / L; NV := NV / L;
  L := Hypot(EU, EV);
  if L < 0.2 then Exit;
  EU := EU / L; EV := EV / L;
  C.Pen.Width := 1;
  C.Pen.Color := clSilver;
  C.Brush.Style := bsClear;
  C.Ellipse(CX - R, CY - R, CX + R + 1, CY + R + 1);
  { the four points, screen y down; north the heavy one }
  for K := 0 to 3 do
  begin
    case K of
      0: begin DX := NU; DY := -NV; end;
      1: begin DX := EU; DY := -EV; end;
      2: begin DX := -NU; DY := NV; end;
    else begin DX := -EU; DY := EV; end;
    end;
    { north the drawing's green axis and east its red, as the drawing's
      own compass has them }
    case K of
      0: begin C.Pen.Color := $0030A030; C.Pen.Width := 2; end;
      1: begin C.Pen.Color := $002030C8; C.Pen.Width := 2; end;
    else begin C.Pen.Color := clGray; C.Pen.Width := 1; end;
    end;
    C.Line(CX, CY, CX + Round(DX * R), CY + Round(DY * R));
    if K <= 1 then C.Font.Style := [fsBold] else C.Font.Style := [];
    if K <= 1 then C.Font.Color := C.Pen.Color else C.Font.Color := clGray;
    C.TextOut(CX + Round(DX * (R + 9)) - C.TextWidth(TAGS[K]) div 2,
      CY + Round(DY * (R + 9)) - C.TextHeight(TAGS[K]) div 2, TAGS[K]);
  end;
  C.Font.Style := [];
  C.Pen.Width := 1;
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
  out Spec: TRadiantSpec; out Manifolds: TP3Array; out Ports: TIntArray;
  out Layouts: TRadiantResults): Boolean;
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
    F.SaveLast;
    Result := F.Read(Spec) and (Length(F.FManifolds) = Length(Zones));
    Manifolds := Copy(F.FManifolds);
    Ports := Copy(F.FPorts);
    Layouts := Copy(F.FLayouts);
  finally
    F.Free;
  end;
end;

end.
