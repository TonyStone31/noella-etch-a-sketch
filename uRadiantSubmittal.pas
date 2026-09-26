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
  Classes, SysUtils, Math, StrUtils, Graphics, uWork, uRadiantData, uRadiant;

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

implementation

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
  Lines: TStringList;

  procedure Add(Kind: TSubmittalKind; const Text: string; Zone: Integer = -1);
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Default(TSubmittalBlock);
    Result[High(Result)].Kind := Kind;
    Result[High(Result)].Text := Text;
    Result[High(Result)].Zone := Zone;
  end;

  procedure Table(const Cols: array of string);
  var
    K: Integer;
  begin
    Add(skTable, '');
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

  { a zone to a page }
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
    Add(skPlan, Format('Zone %d - north up', [Z + 1]), Z);
    Table(['Loop', 'Length', 'Ink']);
    for I := 0 to High(R.Loops) do
      Row([Format('Z%d L%d', [Z + 1, I + 1]), FormatLen(R.Loops[I].LenFt, Job.Units), InkHex(LoopInk(Z, I))]);
    Add(skHeading, Format('Zone %d - material and notes', [Z + 1]));
    Lines := TStringList.Create;
    try
      Lines.Text := RadiantTicketText(ZS, R, Job.Units);
      for I := 0 to Lines.Count - 1 do
        if Trim(Lines[I]) <> '' then Add(skPara, Lines[I]);
    finally
      Lines.Free;
    end;

    { the design record: what the search did, and what else it found }
    Add(skHeading, Format('Zone %d - design record', [Z + 1]));
    Add(skPara, Format('%d layouts tried in %s.', [R.Tries, RadiantDuration(R.SearchSecs)]));
    for I := 0 to High(R.SearchLog) do Add(skPara, R.SearchLog[I]);
    if (Z <= High(Job.Solutions)) and (Length(Job.Solutions[Z]) > 1) then
    begin
      Add(skPara, Format('The %d layouts the search kept, best first - the one marked is this zone''s:',
        [Length(Job.Solutions[Z])]));
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

  Add(skPageBreak, '');
  Add(skHeading, 'How this layout was made');
  Add(skPara, 'Each zone''s tube runs in rows parallel to the wall its manifold hangs on, a spacing apart, in loops ' +
    'that go out and come back on neighboring rows.  Every tube leaves its manifold square to it and is on the ' +
    'grid within the breakout the ticket gives; the tube keeps ' + FormatFloat('0', EDGE_INSET_IN) +
    '" off every wall and obstacle.  Where a zone''s rows did not pair up, the rows at its far wall may have been ' +
    'closed up a little so every row has a partner - the ticket says so where it was done.');
  Add(skPara, 'Loop lengths run from the manifold and back, both leads included.  The order adds the waste given.');
  Add(skPara, 'The spacing, the tube and the zones are as entered.  Heat loss, water temperature and flow were not ' +
    'worked out here and are not implied by this layout.');
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
      K := 0; A := -1;
      for J := 1 to High(Pts) do
        if Hypot(Pts[J].X - Pts[J - 1].X, Pts[J].Y - Pts[J - 1].Y) > A then
        begin
          A := Hypot(Pts[J].X - Pts[J - 1].X, Pts[J].Y - Pts[J - 1].Y);
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

end.
