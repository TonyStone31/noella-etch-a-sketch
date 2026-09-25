program radiantbench;

{ The radiant layout, measured on a corpus of floors - the easy ones, the
  awkward ones and the owner's own - so a change to the engine can be
  judged by numbers and not by one picture.  An idea from a second opinion
  the owner brought, 25 September: "now when Claude says 'I improved the
  algorithm', you've got numbers proving whether it improved anything or
  merely moved the bug."

  For every floor: how much of it is covered, how many loops and how long
  the shortest and longest, how far apart (spread), the bends and how much
  of the tube runs in long straights, crossings, the tube in all, and the
  time.  Compared line for line with tests/radiant-baseline.txt: a floor
  that covers less, crosses where it did not, spreads its loops much
  wider or bends much more is a regression, said, and the run fails.

      tests/run-bench.sh            measure and compare
      tests/run-bench.sh --save     measure and keep as the new baseline
      ONLY=floor tests/run-bench.sh one floor alone

  The search here is the fixed one - no one watching, so no random tries -
  and the same every run. }

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Math, uWork, uRadiantData, uRadiant;

type
  TFloor = record
    Name: string;
    Outline: TP3Array;
    Holes: TRadiantHoles;
    Manifold: TP3;
    Suggest: Boolean;        { Suggest places the manifold, not Manifold }
    Tube: TTubeSize;
    Spacing: Double;
  end;

var
  Floors: array of TFloor;
  Base: TStringList;
  Save: Boolean;
  Regressions: Integer;

function Rect(X0, Y0, X1, Y1: Double): TP3Array;
begin
  SetLength(Result, 4);
  Result[0] := P3(X0, Y0, 0); Result[1] := P3(X1, Y0, 0);
  Result[2] := P3(X1, Y1, 0); Result[3] := P3(X0, Y1, 0);
end;

function Poly(const XY: array of Double): TP3Array;
var
  I: Integer;
begin
  SetLength(Result, Length(XY) div 2);
  for I := 0 to High(Result) do Result[I] := P3(XY[2 * I], XY[2 * I + 1], 0);
end;

function Circle(CX, CY, R: Double; N: Integer): TP3Array;
var
  I: Integer;
begin
  SetLength(Result, N);
  for I := 0 to N - 1 do
    Result[I] := P3(CX + R * Cos(2 * Pi * I / N), CY + R * Sin(2 * Pi * I / N), 0);
end;

procedure Add(const Name: string; const Outline: TP3Array; const Holes: array of TP3Array;
  const M: TP3; Suggest: Boolean; Tube: TTubeSize = tsThreeQuarter; Spacing: Double = 1);
var
  F: TFloor;
  I: Integer;
begin
  F.Name := Name; F.Outline := Outline;
  SetLength(F.Holes, Length(Holes));
  for I := 0 to High(Holes) do F.Holes[I] := Holes[I];
  F.Manifold := M; F.Suggest := Suggest; F.Tube := Tube; F.Spacing := Spacing;
  SetLength(Floors, Length(Floors) + 1);
  Floors[High(Floors)] := F;
end;

function OddArc: TP3Array;
begin
  Result := Poly([75.943, 105.536, 75.943, 55.536, 105.943, 55.536, 135.943, 55.536, 135.943, 65.464,
    142.274, 61.481, 149.641, 60.187, 156.950, 61.774, 163.117, 66.007, 167.226, 72.257, 168.667, 79.597,
    167.226, 86.936, 163.117, 93.186, 156.950, 97.419, 149.641, 99.006, 142.274, 97.713, 135.943, 93.729,
    135.943, 105.536, 131.474, 108.478, 126.719, 110.931, 121.732, 112.868, 116.568, 114.267, 111.285, 115.113,
    105.943, 115.396, 100.600, 115.113, 95.317, 114.267, 90.153, 112.868, 85.166, 110.931, 80.412, 108.478]);
end;

procedure Corpus;
begin
  { the plain ones }
  Add('rect-40x30-midwall', Rect(0, 0, 40, 30), [], P3(20, 1, 0), False);
  Add('rect-40x30-suggest', Rect(0, 0, 40, 30), [], P3(0, 0, 0), True);
  Add('rect-60x50-corner', Rect(0, 0, 60, 50), [], P3(1, 1, 0), False);
  Add('rect-60x50-middle', Rect(0, 0, 60, 50), [], P3(30, 25, 0), False);
  Add('rect-40x40-half-9in', Rect(0, 0, 40, 40), [], P3(20, 1, 0), False, tsHalf, 0.75);
  { shapes }
  Add('L-50', Poly([0, 0, 50, 0, 50, 25, 25, 25, 25, 50, 0, 50]), [], P3(0, 0, 0), True);
  Add('T-60', Poly([0, 30, 60, 30, 60, 50, 0, 50, 0, 30, 0, 30]), [], P3(30, 49, 0), False);
  Add('T-stem', Poly([0, 30, 20, 30, 20, 0, 40, 0, 40, 30, 60, 30, 60, 50, 0, 50]), [], P3(30, 49, 0), False);
  Add('hallway-60x8', Rect(0, 0, 60, 8), [], P3(1, 4, 0), False);
  Add('triangle', Poly([0, 0, 60, 0, 30, 50]), [], P3(30, 1, 0), False, tsHalf, 0.75);
  Add('round-room-30', Circle(15, 15, 15, 32), [], P3(15, 1, 0), False);
  { obstacles }
  Add('one-column', Rect(0, 0, 40, 40), [Rect(18, 18, 22, 22)], P3(20, 1, 0), False);
  Add('four-columns', Rect(0, 0, 60, 50), [Rect(14, 12, 16, 14), Rect(44, 12, 46, 14),
    Rect(14, 36, 16, 38), Rect(44, 36, 46, 38)], P3(30, 1, 0), False);
  Add('big-hole', Rect(0, 0, 40, 40), [Rect(10, 10, 30, 30)], P3(20, 1, 0), False);
  Add('obstacle-on-wall', Rect(0, 0, 50, 40), [Rect(20, 30, 30, 40)], P3(25, 1, 0), False);
  Add('channels', Rect(0, 0, 60, 40), [Rect(10, 8, 50, 12), Rect(10, 20, 50, 24), Rect(10, 30, 50, 34)],
    P3(1, 20, 0), False);
  Add('column-before-manifold', Rect(0, 0, 60, 50), [Rect(26, 4, 34, 8)], P3(30, 1, 0), False);
  { the owner's own }
  Add('barn-120-A-obstacle', Rect(0, 0, 60, 50), [Rect(49.677083, 11.572917, 53.083333, 29.640625)],
    P3(47.768116, 17.028986, 0), False);
  Add('barn-120-B', Rect(60, 0, 120, 50), [], P3(87.086957, 49.637681, 0), False);
  Add('circle-bump-big', Poly([116.615, 51.349, 116.615, 111.349, 106.615, 111.349, 110.938, 117.021,
    112.684, 123.935, 111.570, 130.979, 107.778, 137.018, 101.916, 141.080, 94.930, 142.510,
    87.944, 141.080, 82.083, 137.018, 78.290, 130.979, 77.177, 123.935, 78.922, 117.021,
    83.245, 111.349, 66.615, 111.349, 66.615, 51.349]), [], P3(66.786, 79.368, 0), False);
  Add('circle-bump-small', Poly([16.615, 111.349, 16.615, 51.349, 66.615, 51.349, 66.615, 111.349,
    54.404, 111.349, 53.866, 114.388, 52.581, 117.194, 50.634, 119.588, 48.148, 121.416,
    45.283, 122.563, 42.222, 122.953, 39.161, 122.563, 36.295, 121.416, 33.809, 119.588,
    31.862, 117.194, 30.578, 114.388, 30.039, 111.349]), [], P3(66.176, 70.030, 0), False);
  { the owner's odd floor, 25 September: an arch, two triangles cut by a
    diagonal, a big arc with a circle bumped out of it }
  Add('odd-arch', Poly([15.943, 105.536, 15.943, 55.536, 75.943, 55.536, 75.943, 105.536, 75.293, 113.629,
    72.500, 121.252, 67.768, 127.848, 61.443, 132.938, 53.987, 136.148, 45.943, 137.245, 37.899, 136.148,
    30.442, 132.938, 24.117, 127.848, 19.386, 121.252, 16.593, 113.629]), [], P3(45.943, 56.536, 0), False);
  Add('odd-triangle-top', Poly([15.943, 55.536, 15.943, 5.536, 105.943, 55.536, 75.943, 55.536]), [],
    P3(45.943, 54.536, 0), False);
  Add('odd-triangle-slant', Poly([15.943, 55.536, 15.943, 5.536, 105.943, 55.536, 75.943, 55.536]), [],
    P3(60.46, 31.41, 0), False);
  Add('odd-wedge-bump', Poly([15.943, 5.536, 75.943, 5.536, 135.943, 5.536, 135.943, 13.351, 140.206, 12.831,
    144.427, 13.626, 148.208, 15.662, 151.196, 18.748, 153.109, 22.593, 153.767, 26.837, 153.109, 31.082,
    151.196, 34.927, 148.208, 38.013, 144.427, 40.049, 140.206, 40.844, 135.943, 40.324, 135.943, 55.536,
    105.943, 55.536]), [], P3(120.943, 54.536, 0), False);
  Add('odd-arc-on-circle', OddArc, [], P3(139.641, 64.319, 0), False);
  Add('odd-arc-suggest', OddArc, [], P3(0, 0, 0), True);
end;

{ the baseline's line for Name, split, or nil }
function Baseline(const Name: string): TStringArray;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Base.Count - 1 do
    if Copy(Base[I], 1, Length(Name) + 1) = Name + ' ' then
      Exit(Base[I].Split([' '], TStringSplitOptions.ExcludeEmpty));
end;

var
  I, J, Ports: Integer;
  Spec: TRadiantSpec;
  Zone: TRadiantZone;
  R: TRadiantResult;
  Cover, Spread, Lo, Hi, Secs, TotalSecs, SumCover: Double;
  T0: QWord;
  Line, Verdict: string;
  Out_: TStringList;
  B: TStringArray;
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings; FS.DecimalSeparator := '.';
  Save := (ParamCount >= 1) and (ParamStr(1) = '--save');
  Base := TStringList.Create;
  Out_ := TStringList.Create;
  if FileExists('tests/radiant-baseline.txt') then Base.LoadFromFile('tests/radiant-baseline.txt');
  Corpus;
  Regressions := 0; TotalSecs := 0; SumCover := 0;
  WriteLn(Format('%-26s %6s %5s %9s %6s %6s %6s %5s %8s %6s', ['floor', 'cover', 'loops', 'shortest-longest',
    'spread', 'bends', 'strt%', 'cross', 'tube ft', 'secs'], FS));
  for I := 0 to High(Floors) do
  begin
    { ONLY=name measures that floor alone }
    if (GetEnvironmentVariable('ONLY') <> '') and (GetEnvironmentVariable('ONLY') <> Floors[I].Name) then Continue;
    Spec := DefaultRadiantSpec;
    Spec.Tube := Floors[I].Tube; Spec.Spacing := Floors[I].Spacing;
    SetLength(Spec.Manifolds, 1);
    if Floors[I].Suggest then
    begin
      Zone.Outline := Floors[I].Outline; Zone.Holes := Floors[I].Holes;
      RadiantSuggestZoneManifold(Zone, P3(0, 0, 0), Spec, Spec.Manifolds[0], Ports);
    end
    else Spec.Manifolds[0] := Floors[I].Manifold;
    T0 := GetTickCount64;
    R := ComputeRadiantLayout(Floors[I].Outline, Floors[I].Holes, Spec);
    Secs := (GetTickCount64 - T0) / 1000;
    TotalSecs := TotalSecs + Secs;
    RadiantMeasure(R, Cover, Spread);
    SumCover := SumCover + Cover;
    Lo := 0; Hi := 0;
    if Length(R.Loops) > 0 then
    begin
      Lo := 1E300;
      for J := 0 to High(R.Loops) do
      begin
        Lo := Min(Lo, R.Loops[J].LenFt); Hi := Max(Hi, R.Loops[J].LenFt);
      end;
    end;
    Line := Format('%s %.1f %d %.0f %.0f %.1f %d %.0f %d %.0f', [Floors[I].Name, Cover * 100, Length(R.Loops),
      Lo, Hi, Spread * 100, R.Bends, R.StraightPct, R.Crossings, R.TotalFt], FS);
    Out_.Add(Line);
    { against the baseline: less floor, a crossing, much wider spread, or
      many more bends, is worse }
    Verdict := '';
    B := Baseline(Floors[I].Name);
    if Length(B) >= 10 then
    begin
      if Cover * 100 < StrToFloat(B[1], FS) - 0.5 then Verdict := Verdict + ' COVER';
      if R.Crossings > StrToInt(B[8]) then Verdict := Verdict + ' CROSSES';
      if Spread * 100 > StrToFloat(B[5], FS) + 5 then Verdict := Verdict + ' SPREAD';
      if R.Bends > StrToInt(B[6]) * 1.15 + 5 then Verdict := Verdict + ' BENDS';
      if Verdict <> '' then Inc(Regressions)
      else if Cover * 100 > StrToFloat(B[1], FS) + 0.5 then Verdict := ' better cover';
      Verdict := Verdict + Format(' (was %s%%)', [B[1]]);
    end
    else if not Save then Verdict := ' (no baseline)';
    WriteLn(Format('%-26s %5.1f%% %5d %4.0f-%-4.0f %5.1f%% %6d %5.0f%% %5d %8.0f %6.1f%s',
      [Floors[I].Name, Cover * 100, Length(R.Loops), Lo, Hi, Spread * 100, R.Bends, R.StraightPct,
       R.Crossings, R.TotalFt, Secs, Verdict], FS));
  end;
  WriteLn(Format('%d floors, mean cover %.1f%%, %.1f s', [Length(Floors), 100 * SumCover / Max(1, Length(Floors)),
    TotalSecs], FS));
  if Save then
  begin
    Out_.SaveToFile('tests/radiant-baseline.txt');
    WriteLn('baseline saved: tests/radiant-baseline.txt');
  end
  else if Regressions > 0 then
  begin
    WriteLn(Format('%d floor(s) worse than the baseline', [Regressions]));
    Halt(1);
  end;
end.
