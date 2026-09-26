unit uRadiantSubmittal;

{ A radiant layout as a submittal - what goes to whoever approves the job,
  and to whoever lays the tube: the system in brief, a schedule of the
  zones and of every loop, each zone's material list and notes, the plan,
  and the design record - when each zone was searched, how many layouts,
  how long, what happened on the way, and the other layouts it kept, the
  chosen one marked.  The owner, 25 September: "our wizard itself is gonna
  need the export facility because its all a specialized shop tool... the
  material list will be important and the attempts and how long it worked
  and all the good details as if we are building a submittal for
  approval".

  Content only, in blocks - a title, headings, paragraphs, tables, a plan
  - so a writer lays it out for its own page: plain text now, the PDF
  writer when it takes pages of text and vectors.  The plan is strokes and
  labels in feet, in the drawing's own plan (east along X, north along Y),
  for a writer to scale onto its paper. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, StrUtils, Types, Graphics, uWork, uRadiantData, uRadiant;

type
  { everything the wizard knows about the job }
  TRadiantJob = record
    Title: string;                     { the tag, or none }
    When: TDateTime;
    Made: string;                      { the program and its version }
    Units: TUnitSystem;
    Spec: TRadiantSpec;                { as searched, its goals included }
    ZoneSpecs: array of TRadiantSpec;  { each zone's own: its manifold, heading }
    Zones: TRadiantZones;
    Searched: array of Boolean;
    Layouts: TRadiantResults;          { the layout each zone will build }
    Solutions: array of TRadiantResults; { what each zone's search kept }
    Picked: TIntArray;                 { which of those is the layout }
  end;

  TSubmittalKind = (skTitle, skHeading, skPara, skTable, skPlan, skPageBreak);
  TSubmittalBlock = record
    Kind: TSubmittalKind;
    Text: string;                      { title, heading, paragraph, a plan's caption }
    Cols: TStringArray;                { a table's column heads }
    Rows: array of TStringArray;
    Zone: Integer;                     { a plan's zone, -1 for all of them }
    { a table as wide as half the page: two in a row sit side by side }
    Half: Boolean;
  end;
  TSubmittalBlocks = array of TSubmittalBlock;

  TPlanStrokeKind = (psWall, psHole, psLoop, psManifold);
  TPlanStroke = record
    Kind: TPlanStrokeKind;
    Pts: T2Array;                      { feet, east along X, north along Y }
    Closed: Boolean;
    Color: TColor;
    WeightMM: Double;                  { how heavy on paper }
  end;
  TPlanStrokes = array of TPlanStroke;
  TPlanLabel = record
    At: T2;
    Text: string;
    Color: TColor;
  end;
  TPlanLabels = array of TPlanLabel;

function RadiantSubmittal(const Job: TRadiantJob): TSubmittalBlocks;
{ The plan of zone Zone, or every zone with -1: its walls, the obstacles,
  every loop in its own ink and the manifold as the box it is, and where
  the zone numbers and manifold names go. }
procedure RadiantPlanStrokes(const Job: TRadiantJob; Zone: Integer;
  out Strokes: TPlanStrokes; out Labels: TPlanLabels);
{ the blocks as plain text - a title underlined, tables in columns }
function SubmittalAsText(const Blocks: TSubmittalBlocks): string;
{ #RRGGBB, for a table that names an ink }
function InkHex(C: TColor): string;
{ The submittal as a PDF of PageW x PageH millimeters - letter, a zone to
  a page ("our letter sized pages should show the zones... basically each
  zone should get a page... like a good submittal package", the owner, 25
  September): the blocks laid down in order, text wrapped to the page,
  tables measured to fit, each plan at the largest standard scale its box
  takes, with a north arrow and its scale, and a title block on every
  sheet - the job, the date, sheet N of M. }
procedure SubmittalToPdf(const Job: TRadiantJob; const Blocks: TSubmittalBlocks;
  const Path: string; PageW, PageH: Double);

implementation

uses uPdf;

function InkHex(C: TColor): string;
begin
  C := ColorToRGB(C);
  Result := Format('#%.2X%.2X%.2X', [Red(C), Green(C), Blue(C)]);
end;

function Pct(F: Double): string;
begin
  Result := FormatFloat('0.0', F * 100) + '%';
end;

function RadiantSubmittal(const Job: TRadiantJob): TSubmittalBlocks;
var
  Z, I, Zones, Loops, Tried, Ports: Integer;
  Area, Bare, TubeFt, OrderFt, Secs, Cover, Spread: Double;
  R: TRadiantResult;
  ZS: TRadiantSpec;
  T: TTubeFacts;
  MaxFt: Double;
  Line: string;

  procedure Add(Kind: TSubmittalKind; const Text: string; Zone: Integer = -1);
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Default(TSubmittalBlock);
    Result[High(Result)].Kind := Kind;
    Result[High(Result)].Text := Text;
    Result[High(Result)].Zone := Zone;
  end;

  procedure Table(const Cols: array of string; Half: Boolean = False);
  var
    K: Integer;
  begin
    Add(skTable, '');
    Result[High(Result)].Half := Half;
    SetLength(Result[High(Result)].Cols, Length(Cols));
    for K := 0 to High(Cols) do Result[High(Result)].Cols[K] := Cols[K];
  end;

  procedure Row(const Cells: array of string);
  var
    K, N: Integer;
  begin
    N := Length(Result[High(Result)].Rows);
    SetLength(Result[High(Result)].Rows, N + 1);
    SetLength(Result[High(Result)].Rows[N], Length(Cells));
    for K := 0 to High(Cells) do Result[High(Result)].Rows[N][K] := Cells[K];
  end;

  function Done(Z: Integer): Boolean;
  begin
    Result := (Z <= High(Job.Searched)) and Job.Searched[Z] and (Z <= High(Job.Layouts)) and Job.Layouts[Z].Ok;
  end;

  function ZoneSpecOf(Z: Integer): TRadiantSpec;
  begin
    if Z <= High(Job.ZoneSpecs) then Result := Job.ZoneSpecs[Z] else Result := Job.Spec;
  end;

begin
  Result := nil;
  T := TubeOf(Job.Spec.Tube);
  MaxFt := Job.Spec.MaxLoopFt;
  if MaxFt <= 0 then MaxFt := T.MaxLoopFt;
  Zones := Length(Job.Zones);

  { the whole of it, first }
  Area := 0; Bare := 0; TubeFt := 0; OrderFt := 0; Loops := 0; Tried := 0; Secs := 0;
  for Z := 0 to Zones - 1 do
    if Done(Z) then
    begin
      R := Job.Layouts[Z];
      Area := Area + R.AreaSqFt; Bare := Bare + R.UnfilledSqFt;
      TubeFt := TubeFt + R.TotalFt; OrderFt := OrderFt + R.TotalFt * (1 + Job.Spec.WastePct / 100);
      Loops := Loops + Length(R.Loops);
      Tried := Tried + R.Tries; Secs := Secs + R.SearchSecs;
    end;
  if Job.Title <> '' then Add(skTitle, Job.Title) else Add(skTitle, 'Radiant heat layout');
  Add(skPara, Format('Radiant floor heating - a tube layout for %d zone%s, prepared %s with %s.',
    [Zones, IfThen(Zones = 1, '', 's'), FormatDateTime('yyyy-mm-dd hh:nn', Job.When), Job.Made]));

  Add(skHeading, 'System');
  Table(['', '']);
  Row(['Floor', 'concrete slab']);
  Row(['Tube', T.Name + ' PEX, ' + FormatFloat('0.#', Job.Spec.Spacing / Job.Spec.Inch) + '" on center']);
  Row(['Longest loop allowed', FormatLen(MaxFt, Job.Units)]);
  Row(['Zones and manifolds', Format('%d, one manifold each', [Zones])]);
  Row(['Loops', IntToStr(Loops)]);
  Row(['Floor to heat', FormatArea(Area, Job.Units)]);
  if Area > 0 then Row(['Reached by the tube', Pct(1 - Bare / Area)]);
  Row(['Tube, no waste', FormatLen(TubeFt, Job.Units)]);
  Row(['To order', FormatLen(OrderFt, Job.Units) + Format(' (%s%% waste)', [FormatFloat('0', Job.Spec.WastePct)])]);
  Row(['Ties or staples', Format('about %d, one every %s"', [Round(TubeFt * 12 / TIE_SPACING_IN),
    FormatFloat('0', TIE_SPACING_IN)])]);
  Row(['Goals', Format('%s%% of the floor, loops within %s%% of each other',
    [FormatFloat('0.#', Job.Spec.GoalCoverPct), FormatFloat('0.#', Job.Spec.GoalEvenPct)])]);
  if Tried > 0 then Row(['Design effort', Format('%d layouts tried, %s of searching', [Tried, RadiantDuration(Secs)])]);

  Row(['Slab', Format('%s" thick, tube %s, R-%s under it', [FormatFloat('0.#', Job.Spec.SlabThick / Job.Spec.Inch),
    IfThen(Job.Spec.TubeDepth > 0, FormatFloat('0.#', Job.Spec.TubeDepth / Job.Spec.Inch) + '" deep', 'centered'),
    FormatFloat('0', Job.Spec.UnderR)])]);

  { what to buy, all told }
  Add(skHeading, 'Material list');
  Table(['Item', 'Quantity', '']);
  Row([T.Name + ' PEX tube', FormatLen(OrderFt, Job.Units), Format('%s laid, and %s%% for waste',
    [FormatLen(TubeFt, Job.Units), FormatFloat('0', Job.Spec.WastePct)])]);
  { manifolds by size }
  for Ports := MANIFOLD_PORTS_MIN to 64 do
  begin
    I := 0;
    for Z := 0 to Zones - 1 do
      if Done(Z) and (Length(Job.Layouts[Z].Manifolds) > 0) and (Job.Layouts[Z].Manifolds[0].Ports = Ports) then Inc(I);
    if I > 0 then
      Row([Format('Manifold, %d-loop', [Ports]), IntToStr(I), Format('about %s of wall each',
        [FormatLen(RadiantManifoldWallIn(Ports) * Job.Spec.Inch, Job.Units)])]);
  end;
  Row(['Ties or staples', Format('about %d', [Round(TubeFt * 12 / TIE_SPACING_IN)]),
    Format('one every %s" of tube', [FormatFloat('0', TIE_SPACING_IN)])]);
  Row(['Insulation under the slab', Format('R-%s', [FormatFloat('0', Job.Spec.UnderR)]), FormatArea(Area, Job.Units)]);

  Add(skHeading, 'Zones');
  Table(['Zone', 'Floor', 'Loops', 'Manifold', 'Wall space', 'Tube', 'Reached', 'Loops within', 'Bends', 'Goals']);
  for Z := 0 to Zones - 1 do
    if Done(Z) then
    begin
      R := Job.Layouts[Z];
      RadiantMeasure(R, Cover, Spread);
      if Length(R.Manifolds) > 0 then Ports := R.Manifolds[0].Ports else Ports := 0;
      Row([IntToStr(Z + 1), FormatArea(R.AreaSqFt, Job.Units), IntToStr(Length(R.Loops)),
        Format('%d-loop', [Ports]), FormatLen(RadiantManifoldWallIn(Ports) * Job.Spec.Inch, Job.Units),
        FormatLen(R.TotalFt, Job.Units), Pct(Cover),
        Pct(Spread) + ' (' + FormatLen(RadiantSpreadFt(R), Job.Units) + ')', IntToStr(R.Bends),
        IfThen(R.ShortOfGoals, 'short', 'met')]);
    end
    else Row([IntToStr(Z + 1), '', '', '', '', '', '', '', '', 'not laid out']);

  Add(skPlan, 'Plan - every zone, north up', -1);

  { A zone to a page: its plan, its loops beside what it takes, what is
    special about it, and a line on how it was found - the search's own
    record is at the back. }
  for Z := 0 to Zones - 1 do
  begin
    Add(skPageBreak, '');
    Add(skHeading, Format('Zone %d', [Z + 1]));
    if not Done(Z) then
    begin
      Add(skPara, 'This zone has no layout - it was not searched, or nothing could be laid.');
      Continue;
    end;
    R := Job.Layouts[Z];
    ZS := ZoneSpecOf(Z);
    RadiantMeasure(R, Cover, Spread);
    if Length(R.Manifolds) > 0 then Ports := R.Manifolds[0].Ports else Ports := 0;
    Add(skPlan, Format('Zone %d - north up', [Z + 1]), Z);
    Table(['Loop', 'Length', 'Ink'], True);
    for I := 0 to High(R.Loops) do
      Row([Format('Z%d L%d', [Z + 1, I + 1]), FormatLen(R.Loops[I].LenFt, Job.Units), InkHex(LoopInk(Z, I))]);
    Table(['Zone ' + IntToStr(Z + 1), ''], True);
    Row(['Floor', FormatArea(R.AreaSqFt, Job.Units)]);
    Row(['Manifold', Format('%d-loop, about %s of wall', [Ports,
      FormatLen(RadiantManifoldWallIn(Ports) * Job.Spec.Inch, Job.Units)])]);
    Row(['Tube', FormatLen(R.TotalFt, Job.Units) + ', order ' +
      FormatLen(R.TotalFt * (1 + Job.Spec.WastePct / 100), Job.Units)]);
    Row(['Ties or staples', Format('about %d', [Round(R.TotalFt * 12 / TIE_SPACING_IN)])]);
    Row(['Reached', Pct(Cover) + IfThen(R.UnfilledSqFt > 0.5, ', ' + FormatArea(R.UnfilledSqFt, Job.Units) + ' bare', '')]);
    Row(['Loops within', Pct(Spread) + ' (' + FormatLen(RadiantSpreadFt(R), Job.Units) + ')']);
    Row(['Breakout', Format('on the grid within %s ft of the manifold', [FormatFloat('0', R.BreakoutFt)])]);
    Row(['To lay', Format('%d bends, %s%% in straights of %s or more', [R.Bends, FormatFloat('0', R.StraightPct),
      FormatLen(STRAIGHT_RUN_SPACINGS * Job.Spec.Spacing, Job.Units)])]);
    { what is out of the ordinary }
    if R.BreakoutFt > MANIFOLD_BREAKOUT_FT + 1E-6 then
      Add(skPara, Format('The breakout is wider than %s ft to cover the floor.', [FormatFloat('0', MANIFOLD_BREAKOUT_FT)]));
    if Abs(R.ManifoldShiftFt) > 1E-6 then
      Add(skPara, Format('The manifold was moved %s along its wall from where it was placed, for a better layout.',
        [FormatLen(Abs(R.ManifoldShiftFt), Job.Units)]));
    if R.TightestGap < ZS.Spacing - 1E-6 then
      Add(skPara, Format('Rows at the far wall close up to %s" (from %s") so every row pairs with another.',
        [FormatFloat('0.#', R.TightestGap / ZS.Inch), FormatFloat('0.#', ZS.Spacing / ZS.Inch)]));
    if R.TurnActualIn < R.TurnMinPexAIn then
      Add(skPara, Format('The %s" turn at the end of each row is tighter than this tube bends - PEX-A needs %s".',
        [FormatFloat('0.#', R.TurnActualIn), FormatFloat('0.#', R.TurnMinPexAIn)]))
    else if R.TurnActualIn < R.TurnMinIn then
      Add(skPara, Format('The %s" turn at the end of each row suits PEX-A (%s" at least); PEX-B and PEX-C want %s".',
        [FormatFloat('0.#', R.TurnActualIn), FormatFloat('0.#', R.TurnMinPexAIn), FormatFloat('0.#', R.TurnMinIn)]));
    if R.ShortOfGoals then
      Add(skPara, 'Short of the goals - the nearest the search came.');
    { how it was found, in a line }
    Line := Format('Found in %d layouts, %s of searching', [R.Tries, RadiantDuration(R.SearchSecs)]);
    if (Z <= High(Job.Solutions)) and (Length(Job.Solutions[Z]) > 1) and (Z <= High(Job.Picked)) then
      Line := Line + Format('; layout %d of the %d it kept', [Job.Picked[Z] + 1, Length(Job.Solutions[Z])]);
    Add(skPara, Line + ' - see the design record.');
  end;

  { the search's record, zone by zone }
  Add(skPageBreak, '');
  Add(skHeading, 'Design record');
  Add(skPara, Format('Each zone was searched for a layout that heats at least %s%% of its floor with its loops ' +
    'within %s%% of each other in length: set layouts first, then others tried at random until the goals ' +
    'were met or the search was stopped.  What each search did, and the layouts it kept, best first - the one ' +
    'marked is the zone''s.', [FormatFloat('0.#', Job.Spec.GoalCoverPct), FormatFloat('0.#', Job.Spec.GoalEvenPct)]));
  for Z := 0 to Zones - 1 do
  begin
    if not Done(Z) then Continue;
    R := Job.Layouts[Z];
    Add(skHeading, Format('Zone %d', [Z + 1]));
    Add(skPara, Format('%d layouts tried in %s.', [R.Tries, RadiantDuration(R.SearchSecs)]));
    for I := 0 to High(R.SearchLog) do Add(skPara, R.SearchLog[I]);
    if (Z <= High(Job.Solutions)) and (Length(Job.Solutions[Z]) > 1) then
    begin
      Table(['', 'Reached', 'Loops within', 'Loops', 'Bends', 'Tube', 'Goals']);
      for I := 0 to High(Job.Solutions[Z]) do
      begin
        RadiantMeasure(Job.Solutions[Z][I], Cover, Spread);
        Row([IfThen((Z <= High(Job.Picked)) and (Job.Picked[Z] = I), '>', '') + IntToStr(I + 1),
          Pct(Cover), Pct(Spread) + ' (' + FormatLen(RadiantSpreadFt(Job.Solutions[Z][I]), Job.Units) + ')',
          IntToStr(Length(Job.Solutions[Z][I].Loops)), IntToStr(Job.Solutions[Z][I].Bends),
          FormatLen(Job.Solutions[Z][I].TotalFt, Job.Units), IfThen(RadiantMeetsGoals(Job.Solutions[Z][I], Job.Spec), 'met', 'short')]);
      end;
    end;
  end;

  Add(skHeading, 'How this layout was made');
  Add(skPara, 'Each zone''s tube runs in rows parallel to the wall its manifold hangs on, a spacing apart, in loops ' +
    'that go out and come back on neighboring rows.  Every tube leaves its manifold square to it and is on the ' +
    'grid within the breakout given for the zone; the tube keeps ' + FormatFloat('0', EDGE_INSET_IN) +
    '" off every wall and obstacle.  Where a zone''s rows did not pair up, the rows at its far wall may have been ' +
    'closed up a little so every row has a partner - the zone''s page says so where it was done.');
  Add(skPara, 'Loop lengths run from the manifold and back, both leads included.  The order adds the waste given.');
  Add(skPara, 'The spacing, the tube and the zones are as entered.  Heat loss, water temperature, flow and pump ' +
    'sizing were not worked out here and are not implied by this layout - they come from a room-by-room heat loss.');
end;

procedure RadiantPlanStrokes(const Job: TRadiantJob; Zone: Integer;
  out Strokes: TPlanStrokes; out Labels: TPlanLabels);
const
  SX: array[0..3] of Integer = (-1, 1, 1, -1);
  SY: array[0..3] of Integer = (-1, -1, 1, 1);
var
  F, ZF: TRadiantFrame;
  Z, I, J, K: Integer;
  C, Mid: T2;
  W, H, A: Double;
  Dir: TP3;
  Pts: T2Array;

  procedure Stroke(Kind: TPlanStrokeKind; const P: T2Array; Closed: Boolean; Color: TColor; WeightMM: Double);
  begin
    SetLength(Strokes, Length(Strokes) + 1);
    Strokes[High(Strokes)].Kind := Kind;
    Strokes[High(Strokes)].Pts := P;
    Strokes[High(Strokes)].Closed := Closed;
    Strokes[High(Strokes)].Color := Color;
    Strokes[High(Strokes)].WeightMM := WeightMM;
  end;

  procedure LabelAt(const P: T2; const Text: string; Color: TColor);
  begin
    SetLength(Labels, Length(Labels) + 1);
    Labels[High(Labels)].At := P;
    Labels[High(Labels)].Text := Text;
    Labels[High(Labels)].Color := Color;
  end;

  function Flat(const Src: TP3Array): T2Array;
  var
    K: Integer;
  begin
    SetLength(Result, Length(Src));
    for K := 0 to High(Src) do Result[K] := RadiantTo2(F, Src[K]);
  end;

begin
  Strokes := nil;
  Labels := nil;
  if Length(Job.Zones) = 0 then Exit;
  { the drawing's own plan, the frame the wizard draws in }
  F := RadiantPlanFrame(Job.Zones[0].Outline);
  for Z := 0 to High(Job.Zones) do
  begin
    if (Zone >= 0) and (Z <> Zone) then Continue;
    Stroke(psWall, Flat(Job.Zones[Z].Outline), True, clBlack, 0.5);
    for I := 0 to High(Job.Zones[Z].Holes) do
      Stroke(psHole, Flat(Job.Zones[Z].Holes[I]), True, clGray, 0.35);
    { the zone's number at the middle of its corners }
    Mid.X := 0; Mid.Y := 0;
    Pts := Flat(Job.Zones[Z].Outline);
    for I := 0 to High(Pts) do
    begin
      Mid.X := Mid.X + Pts[I].X / Length(Pts); Mid.Y := Mid.Y + Pts[I].Y / Length(Pts);
    end;
    LabelAt(Mid, Format('Zone %d', [Z + 1]), clBlack);
    if (Z > High(Job.Searched)) or not Job.Searched[Z] or (Z > High(Job.Layouts)) or not Job.Layouts[Z].Ok then
      Continue;
    for I := 0 to High(Job.Layouts[Z].Loops) do
    begin
      Pts := Flat(Job.Layouts[Z].Loops[I].Pts);
      Stroke(psLoop, Copy(Pts), False, LoopInk(Z, I), 0.18 + 0.08 * Ord(LoopWeight(I) > 1));
      { its tag - the name the drawing gives it, its length - on its
        longest run, in its own ink: "each loop will need a tag... its
        length its color" (the owner, 25 September) }
      { of its runs at least half as long as its longest, the one
        farthest from the manifold - out on its own rows, not on the
        leads every loop runs side by side from the manifold, where the
        tags of a zone piled on one another }
      A := 0;
      for J := 1 to High(Pts) do A := Max(A, Hypot(Pts[J].X - Pts[J - 1].X, Pts[J].Y - Pts[J - 1].Y));
      if Length(Job.Layouts[Z].Manifolds) > 0 then C := RadiantTo2(F, Job.Layouts[Z].Manifolds[0].At)
      else C := Pts[0];
      K := 0; W := -1;
      for J := 1 to High(Pts) do
        if (Hypot(Pts[J].X - Pts[J - 1].X, Pts[J].Y - Pts[J - 1].Y) >= A / 2) and
           (Hypot((Pts[J].X + Pts[J - 1].X) / 2 - C.X, (Pts[J].Y + Pts[J - 1].Y) / 2 - C.Y) > W) then
        begin
          W := Hypot((Pts[J].X + Pts[J - 1].X) / 2 - C.X, (Pts[J].Y + Pts[J - 1].Y) / 2 - C.Y);
          K := J;
        end;
      if K > 0 then
      begin
        Mid.X := (Pts[K].X + Pts[K - 1].X) / 2; Mid.Y := (Pts[K].Y + Pts[K - 1].Y) / 2;
        LabelAt(Mid, Format('Z%d L%d  %s', [Z + 1, I + 1, FormatLen(Job.Layouts[Z].Loops[I].LenFt, Job.Units)]),
          LoopInk(Z, I));
      end;
    end;
    { the manifold: its box, turned the way it hangs }
    for J := 0 to High(Job.Layouts[Z].Manifolds) do
    begin
      C := RadiantTo2(F, Job.Layouts[Z].Manifolds[J].At);
      if (Z <= High(Job.ZoneSpecs)) and (J <= High(Job.ZoneSpecs[Z].ManifoldAngles)) then
      begin
        { the zone's heading is in its own frame: into the world, then the
          plan's }
        A := DegToRad(Job.ZoneSpecs[Z].ManifoldAngles[J]);
        ZF := RadiantFrameOf(Job.Zones[Z].Outline);
        Dir := P3(ZF.U.X * Cos(A) + ZF.V.X * Sin(A), ZF.U.Y * Cos(A) + ZF.V.Y * Sin(A),
          ZF.U.Z * Cos(A) + ZF.V.Z * Sin(A));
        A := ArcTan2(Dot3(Dir, F.V), Dot3(Dir, F.U));
      end
      else A := 0;
      W := Job.Spec.ManifoldW; H := Job.Spec.ManifoldH;
      SetLength(Pts, 4);
      for K := 0 to 3 do
      begin
        Pts[K].X := C.X + SX[K] * W / 2 * Cos(A) - SY[K] * H / 2 * Sin(A);
        Pts[K].Y := C.Y + SX[K] * W / 2 * Sin(A) + SY[K] * H / 2 * Cos(A);
      end;
      Stroke(psManifold, Copy(Pts), True, ZoneInk(Z), 0.5);
      LabelAt(C, Format('M%d', [Z + 1]), ZoneInk(Z));
    end;
  end;
end;

function SubmittalAsText(const Blocks: TSubmittalBlocks): string;
var
  B, I, J, N: Integer;
  Widths: array of Integer;
  S, Line: string;
  Out_: TStringList;
begin
  Out_ := TStringList.Create;
  try
    for B := 0 to High(Blocks) do
      case Blocks[B].Kind of
        skTitle:
          begin
            Out_.Add(Blocks[B].Text);
            Out_.Add(StringOfChar('=', Length(Blocks[B].Text)));
            Out_.Add('');
          end;
        skHeading:
          begin
            Out_.Add('');
            Out_.Add(Blocks[B].Text);
            Out_.Add(StringOfChar('-', Length(Blocks[B].Text)));
          end;
        skPara: Out_.Add(Blocks[B].Text);
        skPlan: Out_.Add('[' + Blocks[B].Text + ']');
        skPageBreak: Out_.Add('');
        skTable:
          begin
            N := Length(Blocks[B].Cols);
            for I := 0 to High(Blocks[B].Rows) do N := Max(N, Length(Blocks[B].Rows[I]));
            SetLength(Widths, N);
            for J := 0 to N - 1 do Widths[J] := 0;
            for J := 0 to High(Blocks[B].Cols) do Widths[J] := Max(Widths[J], Length(Blocks[B].Cols[J]));
            for I := 0 to High(Blocks[B].Rows) do
              for J := 0 to High(Blocks[B].Rows[I]) do Widths[J] := Max(Widths[J], Length(Blocks[B].Rows[I][J]));
            Line := '';
            for J := 0 to High(Blocks[B].Cols) do Line := Line + Format('%-*s  ', [Widths[J], Blocks[B].Cols[J]]);
            if Trim(Line) <> '' then
            begin
              Out_.Add(TrimRight(Line));
              S := '';
              for J := 0 to N - 1 do S := S + StringOfChar('-', Widths[J]) + '  ';
              Out_.Add(TrimRight(S));
            end;
            for I := 0 to High(Blocks[B].Rows) do
            begin
              Line := '';
              for J := 0 to High(Blocks[B].Rows[I]) do Line := Line + Format('%-*s  ', [Widths[J], Blocks[B].Rows[I][J]]);
              Out_.Add(TrimRight(Line));
            end;
          end;
      end;
    Result := Out_.Text;
  finally
    Out_.Free;
  end;
end;

procedure SubmittalToPdf(const Job: TRadiantJob; const Blocks: TSubmittalBlocks;
  const Path: string; PageW, PageH: Double);
const
  MARGIN = 12.7;
  FOOT = 12.0;
  PT = 25.4 / 72;
var
  Book: TPdfBook;
  Top, Bottom, Left, Right, Wide, Yc: Double;
  B, I, N: Integer;
  Title, Stamp: string;
  Paired: Boolean;

  procedure NewPage;
  begin
    Book.NewPage;
    Yc := Top;
  end;

  procedure Need(H: Double);
  begin
    if Yc + H > Bottom then NewPage;
  end;

  { S cut into lines no wider than W at Size }
  function Wrap(const S: string; Size, W: Double; Bold: Boolean = False): TStringArray;
  var
    Words: TStringArray;
    K: Integer;
    Cur: string;
  begin
    Result := nil;
    Words := S.Split([' '], TStringSplitOptions.ExcludeEmpty);
    { a line that leads with spaces keeps them - the ticket indents }
    Cur := Copy(S, 1, Length(S) - Length(TrimLeft(S)));
    for K := 0 to High(Words) do
    begin
      if (Trim(Cur) <> '') and (Book.TextWidth(Cur + ' ' + Words[K], Size, Bold) > W) then
      begin
        SetLength(Result, Length(Result) + 1); Result[High(Result)] := Cur;
        Cur := '    ' + Words[K];
      end
      else if Trim(Cur) = '' then Cur := Cur + Words[K]
      else Cur := Cur + ' ' + Words[K];
    end;
    if Trim(Cur) <> '' then begin SetLength(Result, Length(Result) + 1); Result[High(Result)] := Cur; end;
  end;

  procedure Para(const S: string; Size: Double; Ink: TColor = clBlack; Bold: Boolean = False);
  var
    Lines: TStringArray;
    K: Integer;
    LH: Double;
  begin
    LH := Size * PT * 1.35;
    Lines := Wrap(S, Size, Wide, Bold);
    for K := 0 to High(Lines) do
    begin
      Need(LH);
      Book.Text(Left, Yc + LH * 0.8, Lines[K], Size, Ink, Bold);
      Yc := Yc + LH;
    end;
  end;

  { a table laid at X0 in WAvail: its type size, column widths and row
    height worked out to fit; drawn from the cursor, a new page (the heads
    again) when it runs off one unless Keep; the cursor left under it }
  procedure Table(const Blk: TSubmittalBlock; X0, WAvail: Double; Keep: Boolean = False);
  var
    Cols, R, C, Ink: Integer;
    W: array of Double;
    Sum, Size, RH, X: Double;
    HasHead: Boolean;

    procedure Head;
    var
      C2: Integer;
      X2: Double;
    begin
      if not HasHead then Exit;
      if not Keep then Need(RH * 2);
      X2 := X0;
      for C2 := 0 to High(Blk.Cols) do
      begin
        Book.Text(X2, Yc + RH * 0.75, Blk.Cols[C2], Size, clBlack, True);
        X2 := X2 + W[C2];
      end;
      Yc := Yc + RH;
      Book.Line(X0, Yc - RH * 0.1, X0 + Sum, Yc - RH * 0.1, clBlack, 0.2);
    end;

  begin
    Cols := Length(Blk.Cols);
    for R := 0 to High(Blk.Rows) do Cols := Max(Cols, Length(Blk.Rows[R]));
    if Cols = 0 then Exit;
    HasHead := False;
    for C := 0 to High(Blk.Cols) do if Blk.Cols[C] <> '' then HasHead := True;
    Size := 8;
    repeat
      SetLength(W, Cols);
      for C := 0 to Cols - 1 do W[C] := 0;
      for C := 0 to High(Blk.Cols) do W[C] := Max(W[C], Book.TextWidth(Blk.Cols[C], Size, True));
      for R := 0 to High(Blk.Rows) do
        for C := 0 to High(Blk.Rows[R]) do
          W[C] := Max(W[C], Book.TextWidth(Blk.Rows[R][C], Size) + 5 * Ord(Copy(Blk.Rows[R][C], 1, 1) = '#'));
      Sum := 0;
      for C := 0 to Cols - 1 do
      begin
        W[C] := W[C] + 3;
        Sum := Sum + W[C];
      end;
      if (Sum <= WAvail) or (Size <= 5.5) then Break;
      Size := Max(5.5, Size * WAvail / Sum - 0.05);
    until False;
    RH := Size * PT * 1.45;
    Yc := Yc + 1;
    Head;
    for R := 0 to High(Blk.Rows) do
    begin
      if not Keep and (Yc + RH > Bottom) then begin NewPage; Head; end;
      X := X0;
      for C := 0 to High(Blk.Rows[R]) do
      begin
        { an ink, #RRGGBB: a swatch of it, and its name }
        if (Length(Blk.Rows[R][C]) = 7) and (Blk.Rows[R][C][1] = '#') and
           TryStrToInt('$' + Copy(Blk.Rows[R][C], 2, 6), Ink) then
        begin
          Book.Poly([PointF(X, Yc + RH * 0.2), PointF(X + 4, Yc + RH * 0.2), PointF(X + 4, Yc + RH * 0.85),
            PointF(X, Yc + RH * 0.85)], True, clBlack, 0.1, RGBToColor((Ink shr 16) and $FF, (Ink shr 8) and $FF, Ink and $FF));
          Book.Text(X + 5, Yc + RH * 0.75, Blk.Rows[R][C], Size);
        end
        else Book.Text(X, Yc + RH * 0.75, Blk.Rows[R][C], Size);
        X := X + W[C];
      end;
      Yc := Yc + RH;
    end;
    Yc := Yc + 2;
  end;

  { how tall a table comes out, laid in WAvail }
  function TableHeight(const Blk: TSubmittalBlock; WAvail: Double): Double;
  var
    Y0: Double;
    Was: Integer;
  begin
    { laid on a scratch page nobody sees would cost a page; the rows at
      8 pt, the header, and the gaps are enough to know }
    Was := Length(Blk.Rows) + Ord(Length(Blk.Cols) > 0);
    Y0 := 8 * PT * 1.45;
    Result := Was * Y0 + 3;
  end;

  { two half-width tables side by side }
  procedure TablePair(const A, B2: TSubmittalBlock);
  var
    Y0, Ya, H: Double;
  begin
    H := Max(TableHeight(A, Wide / 2 - 3), TableHeight(B2, Wide / 2 - 3));
    Need(H);
    Y0 := Yc;
    Table(A, Left, Wide / 2 - 3, True);
    Ya := Yc;
    Yc := Y0;
    Table(B2, Left + Wide / 2 + 3, Wide / 2 - 3, True);
    Yc := Max(Ya, Yc);
  end;

  { the plan of a zone, or every zone, into the box below the cursor }
  procedure Plan(const Blk: TSubmittalBlock);
  const
    { inches of paper to the foot, largest first }
    SCALES: array[0..9] of Double = (0.5, 0.375, 0.25, 0.1875, 0.125, 0.09375, 0.0625, 0.046875, 0.03125,
      0.015625);
    SCALE_NAMES: array[0..9] of string = ('1/2"', '3/8"', '1/4"', '3/16"', '1/8"', '3/32"', '1/16"', '3/64"',
      '1/32"', '1/64"');
  var
    St: TPlanStrokes;
    Lb: TPlanLabels;
    K, J, Pick: Integer;
    MinX, MinY, MaxX, MaxY, BoxH, BoxW, Sc, OX, OY, AX, AY: Double;
    Pts: array of TPointF;
    Words: string;
  begin
    RadiantPlanStrokes(Job, Blk.Zone, St, Lb);
    if Length(St) = 0 then Exit;
    MinX := 1E300; MinY := 1E300; MaxX := -1E300; MaxY := -1E300;
    for K := 0 to High(St) do
      for J := 0 to High(St[K].Pts) do
      begin
        MinX := Min(MinX, St[K].Pts[J].X); MaxX := Max(MaxX, St[K].Pts[J].X);
        MinY := Min(MinY, St[K].Pts[J].Y); MaxY := Max(MaxY, St[K].Pts[J].Y);
      end;
    { the rest of the page, or a new one when less than a third is left }
    if Bottom - Yc < (Bottom - Top) / 3 then NewPage;
    BoxW := Wide;
    BoxH := Min(Bottom - Yc - 10, IfThen(Blk.Zone < 0, Bottom - Top - 10, (Bottom - Top) * 0.62));
    { the largest standard scale it fits at; a metric drawing, or a floor
      too big for any, is fitted and says so }
    Pick := -1;
    if Job.Units = usImperial then
      for K := 0 to High(SCALES) do
        if ((MaxX - MinX) * SCALES[K] * 25.4 <= BoxW) and ((MaxY - MinY) * SCALES[K] * 25.4 <= BoxH) then
        begin
          Pick := K;
          Break;
        end;
    if Pick >= 0 then
    begin
      Sc := SCALES[Pick] * 25.4;
      Words := 'scale ' + SCALE_NAMES[Pick] + ' = 1''-0"';
    end
    else
    begin
      Sc := Min(BoxW / Max(MaxX - MinX, 1E-6), BoxH / Max(MaxY - MinY, 1E-6));
      Words := 'not to scale';
    end;
    OX := Left + (BoxW - (MaxX - MinX) * Sc) / 2;
    OY := Yc + 2;
    for K := 0 to High(St) do
    begin
      SetLength(Pts, Length(St[K].Pts));
      for J := 0 to High(St[K].Pts) do
        Pts[J] := PointF(OX + (St[K].Pts[J].X - MinX) * Sc, OY + (MaxY - St[K].Pts[J].Y) * Sc);
      case St[K].Kind of
        psHole: Book.Poly(Pts, True, St[K].Color, St[K].WeightMM, $00D8D8D8);
        psManifold: Book.Poly(Pts, True, St[K].Color, St[K].WeightMM, clWhite);
      else Book.Poly(Pts, St[K].Closed, St[K].Color, St[K].WeightMM);
      end;
    end;
    for K := 0 to High(Lb) do
    begin
      AX := OX + (Lb[K].At.X - MinX) * Sc; AY := OY + (MaxY - Lb[K].At.Y) * Sc;
      if Pos('Zone ', Lb[K].Text) = 1 then
        Book.Text(AX - Book.TextWidth(Lb[K].Text, 9, True) / 2, AY, Lb[K].Text, 9, $00606060, True)
      else Book.Text(AX - Book.TextWidth(Lb[K].Text, 5) / 2, AY - 0.6, Lb[K].Text, 5, Lb[K].Color);
    end;
    { north, at the box's top right }
    AX := Left + BoxW - 6; AY := OY + 2;
    Book.Line(AX, AY + 8, AX, AY, clBlack, 0.35);
    Book.Line(AX, AY, AX - 1.5, AY + 3, clBlack, 0.35);
    Book.Line(AX, AY, AX + 1.5, AY + 3, clBlack, 0.35);
    Book.Text(AX - Book.TextWidth('N', 8, True) / 2, AY - 1, 'N', 8, clBlack, True);
    Yc := OY + (MaxY - MinY) * Sc + 4;
    Book.Text(Left, Yc + 3, Blk.Text + ' - ' + Words, 8, $00404040);
    Yc := Yc + 7;
  end;

begin
  Left := MARGIN; Right := PageW - MARGIN; Wide := Right - Left;
  Top := MARGIN; Bottom := PageH - MARGIN - FOOT;
  if Job.Title <> '' then Title := Job.Title else Title := 'Radiant heat layout';
  Book := TPdfBook.Create(Title + ' - radiant submittal', PageW, PageH);
  try
    NewPage;
    Paired := False;
    for B := 0 to High(Blocks) do
    begin
      { the second of a pair is laid with the first }
      if Paired then begin Paired := False; Continue; end;
      case Blocks[B].Kind of
        skTitle:
          begin
            Need(14);
            Book.Text(Left, Yc + 7, Blocks[B].Text, 16, clBlack, True);
            Yc := Yc + 11;
          end;
        skHeading:
          begin
            Need(14);
            Yc := Yc + 2;
            Book.Text(Left, Yc + 4.5, Blocks[B].Text, 11, clBlack, True);
            Yc := Yc + 6;
            Book.Line(Left, Yc, Right, Yc, $00A0A0A0, 0.2);
            Yc := Yc + 2;
          end;
        skPara: Para(Blocks[B].Text, 9);
        skTable:
          if Blocks[B].Half and (B < High(Blocks)) and (Blocks[B + 1].Kind = skTable) and Blocks[B + 1].Half then
          begin
            TablePair(Blocks[B], Blocks[B + 1]);
            Paired := True;
          end
          else Table(Blocks[B], Left, Wide);
        skPlan: Plan(Blocks[B]);
        skPageBreak: if Yc > Top + 1 then NewPage;
      end;
    end;
    { the title block on every sheet, now the count is known }
    N := Book.PageCount;
    Stamp := FormatDateTime('yyyy-mm-dd', Job.When);
    for I := 1 to N do
    begin
      Book.OnPage(I);
      Book.Line(Left, PageH - MARGIN - FOOT + 3, Right, PageH - MARGIN - FOOT + 3, clBlack, 0.3);
      Book.Text(Left, PageH - MARGIN - FOOT + 8, Title, 9, clBlack, True);
      Book.Text(Left, PageH - MARGIN - FOOT + 12, 'Radiant floor heating - submittal', 7, $00404040);
      Book.Text(Left + Wide / 2 - Book.TextWidth(Stamp, 8) / 2, PageH - MARGIN - FOOT + 8, Stamp, 8);
      Book.Text(Left + Wide / 2 - Book.TextWidth(Job.Made, 6) / 2, PageH - MARGIN - FOOT + 12, Job.Made, 6, $00606060);
      Book.Text(Right - Book.TextWidth(Format('sheet %d of %d', [I, N]), 9, True), PageH - MARGIN - FOOT + 8,
        Format('sheet %d of %d', [I, N]), 9, clBlack, True);
    end;
    Book.SaveToFile(Path);
  finally
    Book.Free;
  end;
end;

end.
