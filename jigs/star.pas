#!/usr/bin/env instantfpc
{ A JIG: any program that prints Heck.  This one prints a star.
  It is handed its values as  Name=value  - lengths as plain inches. }
program star;
{$mode objfpc}{$H+}
uses SysUtils, Math;

function Value(const Name: string; Default: Double): Double;
var I: Integer; S: string;
begin
  Result := Default;
  for I := 1 to ParamCount do
  begin
    S := ParamStr(I);
    if SameText(Copy(S, 1, Length(Name) + 1), Name + '=') then
      Result := StrToFloatDef(Copy(S, Length(Name) + 2, 99), Default);
  end;
end;

var
  N, I: Integer;
  R, E, No, A, Rad: Double;
  X, Y: array of Double;
begin
  DefaultFormatSettings.DecimalSeparator := '.';
  N  := Round(Value('Points', 5));
  R  := Value('Radius', 24);
  E  := Value('East', 0);
  No := Value('North', 0);
  SetLength(X, 2 * N);
  SetLength(Y, 2 * N);
  for I := 0 to 2 * N - 1 do
  begin
    if Odd(I) then Rad := R * 0.4 else Rad := R;
    A := Pi / 2 + I * Pi / N;
    X[I] := E + Rad * Cos(A);
    Y[I] := No + Rad * Sin(A);
  end;
  for I := 0 to 2 * N - 1 do
    WriteLn(Format('line = %.4f" east, %.4f" north, 0 up to %.4f" east, %.4f" north, 0 up',
      [X[I], Y[I], X[(I + 1) mod (2 * N)], Y[(I + 1) mod (2 * N)]]));
end.
