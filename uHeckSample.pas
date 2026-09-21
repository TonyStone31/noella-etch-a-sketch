unit uHeckSample;

{ A little drawing in Heck and three jigs to go with it - a star in Pascal,
  a balloon in Python, a fence in Perl - for trying the source window.
  The jigs are written into the person's jigs folder if they are not there;
  one that is there already is left alone, since it may have been changed. }

{$mode objfpc}{$H+}

interface

function SampleHeck: string;
procedure WriteSampleJigs(const Dir: string);

implementation

uses
  Classes, SysUtils;

const
  NL = LineEnding;

function SampleHeck: string;
begin
  Result :=
    'HeckersSketch 2' + NL +
    'units = ft in' + NL +
    NL +
    'sheet ''Sample''' + NL +
    '  // A four foot cube: eight corners, and the twelve lines between them.' + NL +
    '  // The faces are not typed - the program works them out.' + NL +
    '  points' + NL +
    '    a = 0 east, 0 north, 0 up' + NL +
    '    b = a + 4'' east' + NL +
    '    c = b + 4'' north' + NL +
    '    d = a + 4'' north' + NL +
    '    e = a + 4'' up' + NL +
    '    f = b + 4'' up' + NL +
    '    g = c + 4'' up' + NL +
    '    h = d + 4'' up' + NL +
    '  end' + NL +
    '  line = a to b' + NL +
    '  line = b to c' + NL +
    '  line = c to d' + NL +
    '  line = d to a' + NL +
    '  line = e to f' + NL +
    '  line = f to g' + NL +
    '  line = g to h' + NL +
    '  line = h to e' + NL +
    '  line = a to e' + NL +
    '  line = b to f' + NL +
    '  line = c to g' + NL +
    '  line = d to h' + NL +
    NL +
    '  // A circle on its top.  Try changing the radius and pressing Apply.' + NL +
    '  circle' + NL +
    '    center = 2'' east, 2'' north, 4'' up' + NL +
    '    radius = 1''' + NL +
    '    facing = up' + NL +
    '  end' + NL +
    NL +
    '  // A few loose lines, the second written as steps from where it starts.' + NL +
    '  line = 6'' east, 0 north, 0 up to 6'' east, 3'' north, 0 up' + NL +
    '  line = 6'' east, 3'' north, 0 up to + 2'' east + 1'' 6" up' + NL +
    '  line Red' + NL +
    '    points = 6'' east, 0 north, 0 up to 8'' east, 3'' north, 1'' 6" up' + NL +
    '    ink    = red' + NL +
    '    width  = 2' + NL +
    '  end' + NL +
    NL +
    '  // Three jigs.  Each group is filled by a little program of yours, in' + NL +
    '  // your jigs folder.  Press "Run jigs", then change a number and run again.' + NL +
    '  // Ctrl+click a jig line to open its program.' + NL +
    '  group ''Star''' + NL +
    '    jig = ''star'' with Points = 5, Radius = 2'', East = 12'', North = 2''' + NL +
    '  end' + NL +
    '  group ''Balloon''' + NL +
    '    jig = ''balloon'' with Radius = 1'' 6", East = 12'', North = 7'', Height = 6''' + NL +
    '  end' + NL +
    '  group ''Fence''' + NL +
    '    jig = ''fence'' with Posts = 6, Spacing = 2'', Height = 3'', North = 11''' + NL +
    '  end' + NL +
    'end' + NL;
end;

const
  STAR_PAS =
    '#!/usr/bin/env instantfpc' + NL +
    '{ A JIG: any program that prints Heck.  This one prints a star.' + NL +
    '  It is handed its values as  Name=value  - lengths as plain inches. }' + NL +
    'program star;' + NL +
    '{$mode objfpc}{$H+}' + NL +
    'uses SysUtils, Math;' + NL +
    NL +
    'function Value(const Name: string; Default: Double): Double;' + NL +
    'var I: Integer; S: string;' + NL +
    'begin' + NL +
    '  Result := Default;' + NL +
    '  for I := 1 to ParamCount do' + NL +
    '  begin' + NL +
    '    S := ParamStr(I);' + NL +
    '    if SameText(Copy(S, 1, Length(Name) + 1), Name + ''='') then' + NL +
    '      Result := StrToFloatDef(Copy(S, Length(Name) + 2, 99), Default);' + NL +
    '  end;' + NL +
    'end;' + NL +
    NL +
    'var' + NL +
    '  N, I: Integer;' + NL +
    '  R, E, No, A, Rad: Double;' + NL +
    '  X, Y: array of Double;' + NL +
    'begin' + NL +
    '  DefaultFormatSettings.DecimalSeparator := ''.'';' + NL +
    '  N  := Round(Value(''Points'', 5));' + NL +
    '  R  := Value(''Radius'', 24);' + NL +
    '  E  := Value(''East'', 0);' + NL +
    '  No := Value(''North'', 0);' + NL +
    '  SetLength(X, 2 * N);' + NL +
    '  SetLength(Y, 2 * N);' + NL +
    '  for I := 0 to 2 * N - 1 do' + NL +
    '  begin' + NL +
    '    if Odd(I) then Rad := R * 0.4 else Rad := R;' + NL +
    '    A := Pi / 2 + I * Pi / N;' + NL +
    '    X[I] := E + Rad * Cos(A);' + NL +
    '    Y[I] := No + Rad * Sin(A);' + NL +
    '  end;' + NL +
    '  for I := 0 to 2 * N - 1 do' + NL +
    '    WriteLn(Format(''line = %.4f" east, %.4f" north, 0 up to %.4f" east, %.4f" north, 0 up'',' + NL +
    '      [X[I], Y[I], X[(I + 1) mod (2 * N)], Y[(I + 1) mod (2 * N)]]));' + NL +
    'end.' + NL;

  BALLOON_PY =
    '#!/usr/bin/env python3' + NL +
    '# A JIG: any program that prints Heck.  This one prints a balloon on a string.' + NL +
    '# It is handed its values as  Name=value  - lengths as plain inches.' + NL +
    'import sys, math' + NL +
    NL +
    'v = dict(a.split("=", 1) for a in sys.argv[1:] if "=" in a)' + NL +
    'r = float(v.get("Radius", 18))' + NL +
    'e = float(v.get("East", 0))' + NL +
    'n = float(v.get("North", 0))' + NL +
    'h = float(v.get("Height", 72))' + NL +
    NL +
    '# the balloon: a circle standing up, facing south' + NL +
    'print("circle")' + NL +
    'print(f"  center = {e}\" east, {n}\" north, {h}\" up")' + NL +
    'print(f"  radius = {r}\"")' + NL +
    'print("  facing = south")' + NL +
    'print("  ink = red")' + NL +
    'print("end")' + NL +
    NL +
    '# the knot: a little triangle under it' + NL +
    'k = r / 8' + NL +
    'top = h - r' + NL +
    'print(f"line = {e}\" east, {n}\" north, {top}\" up to {e - k}\" east, {n}\" north, {top - k}\" up")' + NL +
    'print(f"line = {e - k}\" east, {n}\" north, {top - k}\" up to {e + k}\" east, {n}\" north, {top - k}\" up")' + NL +
    'print(f"line = {e + k}\" east, {n}\" north, {top - k}\" up to {e}\" east, {n}\" north, {top}\" up")' + NL +
    NL +
    '# the string: a gentle wave down to the floor' + NL +
    'steps = 12' + NL +
    'x0, z0 = e, top - k' + NL +
    'for i in range(1, steps + 1):' + NL +
    '    z1 = (top - k) * (1 - i / steps)' + NL +
    '    x1 = e + math.sin(i * math.pi / 3) * r / 6' + NL +
    '    print(f"line = {x0:.4f}\" east, {n}\" north, {z0:.4f}\" up to {x1:.4f}\" east, {n}\" north, {z1:.4f}\" up")' + NL +
    '    x0, z0 = x1, z1' + NL;

  FENCE_PL =
    '#!/usr/bin/env perl' + NL +
    '# A JIG: any program that prints Heck.  This one prints a fence.' + NL +
    '# It is handed its values as  Name=value  - lengths as plain inches.' + NL +
    'use strict; use warnings;' + NL +
    'my %v = map { /^(\w+)=(.*)$/ ? ($1 => $2) : () } @ARGV;' + NL +
    'my $posts   = $v{Posts}   // 6;' + NL +
    'my $spacing = $v{Spacing} // 24;' + NL +
    'my $height  = $v{Height}  // 36;' + NL +
    'my $north   = $v{North}   // 0;' + NL +
    'my $east    = $v{East}    // 0;' + NL +
    NL +
    'for my $i (0 .. $posts - 1) {' + NL +
    '    my $x = $east + $i * $spacing;' + NL +
    '    print qq{line = $x" east, $north" north, 0 up to + $height" up\n};' + NL +
    '}' + NL +
    'my $end = $east + ($posts - 1) * $spacing;' + NL +
    'for my $rail ($height * 0.3, $height * 0.8) {' + NL +
    '    print qq{line = $east" east, $north" north, $rail" up to $end" east, $north" north, $rail" up\n};' + NL +
    '}' + NL;

procedure WriteOne(const FileName, Text: string);
var
  L: TStringList;
begin
  if FileExists(FileName) then Exit;
  L := TStringList.Create;
  try
    L.Text := Text;
    try
      L.SaveToFile(FileName);
    except
      { a folder that cannot be written to is not worth stopping for }
    end;
  finally
    L.Free;
  end;
end;

procedure WriteSampleJigs(const Dir: string);
begin
  WriteOne(Dir + 'star.pas', STAR_PAS);
  WriteOne(Dir + 'balloon.py', BALLOON_PY);
  WriteOne(Dir + 'fence.pl', FENCE_PL);
end;

end.
