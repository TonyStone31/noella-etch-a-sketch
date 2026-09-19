program atest;
{$mode objfpc}{$H+}
uses SysUtils, uWebPAnim;
const
  W = 240; H = 160; N = 5;
var
  Fr: array[0..N-1] of TWebPFrame;
  I, X, Y, P: Integer;
begin
  for I := 0 to N - 1 do
  begin
    GetMem(Fr[I].BGRA, W * H * 4);
    Fr[I].Millis := 100 + I * 20;      { each frame a different length }
    for Y := 0 to H - 1 do
      for X := 0 to W - 1 do
      begin
        P := (Y * W + X) * 4;
        { a block that marches across, on flat color with a grid }
        if (X mod 30 = 0) or (Y mod 30 = 0) then
        begin Fr[I].BGRA[P] := 0; Fr[I].BGRA[P+1] := 0; Fr[I].BGRA[P+2] := 0; end
        else if (X >= 20 + I * 40) and (X < 60 + I * 40) and (Y > 40) and (Y < 120) then
        begin Fr[I].BGRA[P] := 32; Fr[I].BGRA[P+1] := 48; Fr[I].BGRA[P+2] := 200; end
        else
        begin Fr[I].BGRA[P] := 232; Fr[I].BGRA[P+1] := 236; Fr[I].BGRA[P+2] := 238; end;
        Fr[I].BGRA[P+3] := 255;
      end;
  end;
  if SaveWebPAnimation(Fr, W, H, '/tmp/atest.webp') then
    WriteLn('wrote /tmp/atest.webp')
  else
    WriteLn('FAILED');
  for I := 0 to N - 1 do FreeMem(Fr[I].BGRA);
end.
