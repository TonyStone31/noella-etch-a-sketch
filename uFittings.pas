unit uFittings;

{ Fittings built from numbers.

  A transition is defined by the gap it fills: the size of the opening at
  each end, the distance between them, and how the two openings sit against
  each other - which is said with one named edge per axis and how far it
  moves, everything measured from the entry.  docs/transition-ticket.md is
  the notation this follows.

  The result is four flat sides, open at both ends, as one solid: each side's
  two long edges are parallel - the vertical edges of a side, the horizontal
  edges of the top and bottom - so every side is a true plane and unfolds to
  a flat piece, which is the point of building it here. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Graphics, uWork;

type
  { which edge is called out on the width, and on the height }
  TSideRule = (srCentred, srLeftIn, srRightIn);
  THeightRule = (hrFlatBottom, hrFlatTop, hrCentred, hrTopUp, hrTopDown,
    hrBottomUp, hrBottomDown);

  { How an end is finished.  Raw is the sheet cut square.  Notched is the
    corners cut back all round so a slip goes on in the field.  A flange is
    the end bent out or in.  TDF is the roll-formed flange commercial duct
    is joined with - out, with a fold back.  Slip and drive has the drives -
    the end bent out for the drive cleat - on two opposite sides and the
    slips, which are just the notch, on the other two: named with the top
    and bottom first, so "slip and drive" is slips top and bottom and drives
    on the sides. }
  TDuctEnd = (deRaw, deNotch, deFlangeOut, deFlangeIn, deTDF, deSlipDrive,
    deDriveSlip);
  TEndSpec = record
    Kind: TDuctEnd;
    Amount: Double;         { the notch depth or the flange width }
  end;

  TTransitionSpec = record
    W0, H0: Double;         { entry opening, width and height }
    W1, H1: Double;         { exit opening }
    Len: Double;            { along the run }
    Side: TSideRule;
    SideAmount: Double;     { how far the named side comes in }
    Height: THeightRule;
    HeightAmount: Double;   { for top up / down, bottom up / down }
    Ends: array[0..1] of TEndSpec;  { entry, exit }
    Inch: Double;           { one inch in drawing units, for the fixed sizes }
    Dims: Boolean;          { put the sizes on it as dimensions }
  end;

const
  DRIVE_FLANGE_IN = 0.5;    { the drive edge, bent out: inches }
  TDF_RETURN_IN = 0.5;      { the fold back on a TDF flange: inches }
  DUCT_END_NAMES: array[TDuctEnd] of string = (
    'Raw', 'Notched all round - slip it in the field', 'Flange out',
    'Flange in', 'TDF flange',
    'Slip and drive - slips top and bottom, drives on the sides',
    'Drive and slip - drives top and bottom, slips on the sides');
  { the size each kind starts at, in inches: a notch, a flange, the TDF }
  DUCT_END_DEFAULT_IN: array[TDuctEnd] of Double = (0, 1, 1, 1, 1.375, 1, 1);

{ whether that end's corners are cut back }
function EndNotched(const E: TEndSpec): Boolean;

{ The fitting's corners.  Entry at y = 0, flow along +Y, the entry's
  bottom-left corner at the origin: E0..E3 round the entry opening,
  X0..X3 round the exit, both anticlockwise seen from the entry side
  (bottom-left, bottom-right, top-right, top-left). }
procedure TransitionCorners(const T: TTransitionSpec; out E, X: array of TP3);

{ Add the fitting to the drawing as one solid.  Returns the index of its
  first entity; everything from there to Live - 1 is the fitting. }
function BuildTransition(D: TWorkDoc; const T: TTransitionSpec; Ink: TColor;
  Weight: Single): Integer;

{ What is wrong with the spec, or '' when it can be built. }
function TransitionProblem(const T: TTransitionSpec): string;

implementation

function EndNotched(const E: TEndSpec): Boolean;
begin
  Result := E.Kind in [deNotch, deSlipDrive, deDriveSlip];
end;

procedure TransitionCorners(const T: TTransitionSpec; out E, X: array of TP3);
var
  XL, ZB: Double;
begin
  E[0] := P3(0, 0, 0);
  E[1] := P3(T.W0, 0, 0);
  E[2] := P3(T.W0, 0, T.H0);
  E[3] := P3(0, 0, T.H0);
  { the width: the named side moves in by the amount, the other follows
    from the exit width; centred splits the difference }
  case T.Side of
    srLeftIn:  XL := T.SideAmount;
    srRightIn: XL := (T.W0 - T.SideAmount) - T.W1;
  else
    XL := (T.W0 - T.W1) / 2;
  end;
  { the height: a flat bottom stays on the floor, a flat top on the ceiling,
    and the named edge - whichever one could be measured in the space -
    moves by the amount, the other following from the exit height }
  case T.Height of
    hrFlatBottom: ZB := 0;
    hrFlatTop:    ZB := T.H0 - T.H1;
    hrTopUp:      ZB := (T.H0 + T.HeightAmount) - T.H1;
    hrTopDown:    ZB := (T.H0 - T.HeightAmount) - T.H1;
    hrBottomUp:   ZB := T.HeightAmount;
    hrBottomDown: ZB := -T.HeightAmount;
  else
    ZB := (T.H0 - T.H1) / 2;
  end;
  X[0] := P3(XL, T.Len, ZB);
  X[1] := P3(XL + T.W1, T.Len, ZB);
  X[2] := P3(XL + T.W1, T.Len, ZB + T.H1);
  X[3] := P3(XL, T.Len, ZB + T.H1);
end;

function TransitionProblem(const T: TTransitionSpec): string;
var
  K: Integer;
  Small: Double;
begin
  Result := '';
  if (T.W0 <= 0) or (T.H0 <= 0) then Exit('The entry opening needs a width and a height.');
  if (T.W1 <= 0) or (T.H1 <= 0) then Exit('The exit opening needs a width and a height.');
  if T.Len <= 0 then Exit('The length has to be more than nothing.');
  if (T.Side in [srLeftIn, srRightIn]) and (T.SideAmount < 0) then
    Exit('A side comes in by a positive amount - name the other side to go the other way.');
  if (T.Height in [hrTopUp, hrTopDown, hrBottomUp, hrBottomDown]) and (T.HeightAmount < 0) then
    Exit('Up and down take a positive amount - name the other way to go the other way.');
  for K := 0 to 1 do
    if T.Ends[K].Kind <> deRaw then
    begin
      if K = 0 then Small := Min(T.W0, T.H0) else Small := Min(T.W1, T.H1);
      if T.Ends[K].Amount <= 0 then
        Exit('The notch or flange on an end needs a size.');
      if T.Ends[K].Amount * 2 >= Small then
        Exit('The notch or flange on an end is bigger than the opening.');
    end;
end;

function BuildTransition(D: TWorkDoc; const T: TTransitionSpec; Ink: TColor;
  Weight: Single): Integer;
var
  C: array[0..1] of array[0..3] of TP3;   { corners: entry, then exit }
  G, K, EndIx: Integer;
  Centre: TP3;
  Inch, Off: Double;
  Poly: array of TP3;

  function Add(const A, B: TP3; F: Double): TP3;
  begin
    Result := P3(A.X + B.X * F, A.Y + B.Y * F, A.Z + B.Z * F);
  end;

  function Towards(const A, B: TP3): TP3;
  begin
    Result := Norm3(P3(B.X - A.X, B.Y - A.Y, B.Z - A.Z));
  end;

  procedure Line(const A, B: TP3);
  begin
    if Dist(A, B) < 1E-9 then Exit;
    D.AddLine(A, B, Ink, Weight, False);
    D.SetGroup(D.Live - 1, G);
  end;

  procedure Face(const P: array of TP3);
  begin
    D.AddFaceRaw(P, Ink, True);
    D.SetFaceGroup(D.Live - 1, G);
  end;

  { the four bent-up sides of a flange or a lip: a face, and the three edges
    that are not the fold it hangs from }
  procedure Strip(const A, B, B2, A2: TP3);
  begin
    Face([A, B, B2, A2]);
    Line(B, B2); Line(B2, A2); Line(A2, A);
  end;

  function Notch(E: Integer): Double;
  begin
    if EndNotched(T.Ends[E]) then Result := T.Ends[E].Amount else Result := 0;
  end;

  { wall K runs from corner K to corner K + 1: 0 bottom, 1 right, 2 top,
    3 left.  Its normal pointing out of the duct. }
  function OutNormal(K: Integer): TP3;
  var
    J: Integer;
    Mid: TP3;
  begin
    J := (K + 1) mod 4;
    Result := Norm3(Cross3(Towards(C[0][K], C[0][J]), Towards(C[0][K], C[1][K])));
    Mid := P3((C[0][K].X + C[0][J].X + C[1][K].X + C[1][J].X) / 4,
              (C[0][K].Y + C[0][J].Y + C[1][K].Y + C[1][J].Y) / 4,
              (C[0][K].Z + C[0][J].Z + C[1][K].Z + C[1][J].Z) / 4);
    if Dot3(Result, P3(Mid.X - Centre.X, Mid.Y - Centre.Y, Mid.Z - Centre.Z)) < 0 then
      Result := P3(-Result.X, -Result.Y, -Result.Z);
  end;

  { The run of wall K along end E, from the seam at its first corner to the
    seam at its second.  Square-cut it is the two corners; notched it steps
    in round the cut-out at each corner. }
  procedure EndPath(E, K: Integer; var P: array of TP3; out N: Integer);
  var
    J: Integer;
    CI, CJ, U, SI, SJ: TP3;
    Nt: Double;
  begin
    J := (K + 1) mod 4;
    CI := C[E][K]; CJ := C[E][J];
    Nt := Notch(E);
    if Nt <= 0 then
    begin
      P[0] := CI; P[1] := CJ; N := 2;
      Exit;
    end;
    U := Towards(CI, CJ);
    SI := Towards(CI, C[1 - E][K]);
    SJ := Towards(CJ, C[1 - E][J]);
    P[0] := Add(CI, SI, Nt);
    P[1] := Add(P[0], U, Nt);
    P[2] := Add(CI, U, Nt);
    P[3] := Add(CJ, U, -Nt);
    P[4] := Add(P[3], SJ, Nt);
    P[5] := Add(CJ, SJ, Nt);
    N := 6;
  end;

  { whether wall K takes a drive flange at an end finished slip-and-drive }
  function DriveWall(E, K: Integer): Boolean;
  begin
    case T.Ends[E].Kind of
      deSlipDrive: Result := K in [1, 3];
      deDriveSlip: Result := K in [0, 2];
    else
      Result := False;
    end;
  end;

  { everything at end E of wall K that is not the wall itself: the opening
    edge in its pieces, the notch cuts, the flange }
  procedure FinishEnd(E, K: Integer);
  var
    J, I: Integer;
    CI, CJ, U, SI, SJ, Nrm, S, A, B, A2, B2: TP3;
    Nt, F, R: Double;
    P: array[0..5] of TP3;
    N: Integer;
  begin
    J := (K + 1) mod 4;
    CI := C[E][K]; CJ := C[E][J];
    U := Towards(CI, CJ);
    SI := Towards(CI, C[1 - E][K]);
    SJ := Towards(CJ, C[1 - E][J]);
    Nt := Notch(E);
    Nrm := OutNormal(K);
    case T.Ends[E].Kind of
      deFlangeOut, deFlangeIn, deTDF:
        begin
          { the fold line is the middle piece of the opening edge; the
            flange stops its own width short of each corner, which is the
            corner cut that lets the next side's flange fold }
          F := T.Ends[E].Amount;
          A := Add(CI, U, F);
          B := Add(CJ, U, -F);
          Line(CI, A); Line(A, B); Line(B, CJ);
          if T.Ends[E].Kind = deFlangeIn then
            Nrm := P3(-Nrm.X, -Nrm.Y, -Nrm.Z);
          A2 := Add(A, Nrm, F);
          B2 := Add(B, Nrm, F);
          Strip(A, B, B2, A2);
          if T.Ends[E].Kind = deTDF then
          begin
            { the fold back, along the duct, that the corner piece and the
              cleat take hold of }
            R := TDF_RETURN_IN * Inch;
            S := SI;
            Strip(A2, B2, Add(B2, S, R), Add(A2, S, R));
          end;
        end;
    else
      begin
        EndPath(E, K, P, N);
        if Nt > 0 then
        begin
          { the cut-outs, and the opening edge between them }
          Line(P[0], P[1]); Line(P[1], P[2]);
          Line(P[2], P[3]);
          Line(P[3], P[4]); Line(P[4], P[5]);
        end
        else
          Line(CI, CJ);
        if DriveWall(E, K) then
        begin
          F := DRIVE_FLANGE_IN * Inch;
          A := P[2]; B := P[3];
          Strip(A, B, Add(B, Nrm, F), Add(A, Nrm, F));
        end;
      end;
    end;
  end;

var
  P0, P1: array[0..5] of TP3;
  N0, N1, I, J: Integer;
begin
  Result := D.Live;
  Inch := T.Inch;
  if Inch <= 0 then Inch := 1 / 12;
  TransitionCorners(T, C[0], C[1]);
  Centre := P3(0, 0, 0);
  for K := 0 to 3 do
  begin
    Centre := Add(Centre, C[0][K], 1);
    Centre := Add(Centre, C[1][K], 1);
  end;
  Centre := P3(Centre.X / 8, Centre.Y / 8, Centre.Z / 8);
  G := D.NewGroup;
  { the four walls, each wound so its normal points out of the duct: up the
    seam at the first corner, along the exit, down the seam at the second,
    back along the entry - stepping round the corner cut-outs where an end
    is notched }
  for K := 0 to 3 do
  begin
    EndPath(0, K, P0, N0);
    EndPath(1, K, P1, N1);
    SetLength(Poly, N0 + N1);
    for I := 0 to N1 - 1 do Poly[I] := P1[I];
    for I := 0 to N0 - 1 do Poly[N1 + I] := P0[N0 - 1 - I];
    Face(Poly);
  end;
  { the seams, from cut-out to cut-out }
  for K := 0 to 3 do
    Line(Add(C[0][K], Towards(C[0][K], C[1][K]), Notch(0)),
         Add(C[1][K], Towards(C[1][K], C[0][K]), Notch(1)));
  { and each end of each wall, finished the way it was asked for }
  for EndIx := 0 to 1 do
    for K := 0 to 3 do
      FinishEnd(EndIx, K);
  { the sizes a ticket carries: both openings, and the run }
  if T.Dims then
  begin
    Off := Max(4 * Inch, 0.15 * Max(Max(T.W0, T.H0), Max(T.W1, T.H1)));
    D.AddDim(C[0][0], C[0][1], Ink, P3(0, 0, -Off)); D.SetGroup(D.Live - 1, G);
    D.AddDim(C[0][1], C[0][2], Ink, P3(Off, 0, 0));  D.SetGroup(D.Live - 1, G);
    D.AddDim(C[1][3], C[1][2], Ink, P3(0, 0, Off));  D.SetGroup(D.Live - 1, G);
    D.AddDim(C[1][1], C[1][2], Ink, P3(Off, 0, 0));  D.SetGroup(D.Live - 1, G);
    { the run is the gap, entry plane to exit plane, which is what was
      measured - not the seam, which is longer whenever a side comes in }
    D.AddDim(C[0][1], P3(C[0][1].X, C[1][1].Y, C[0][1].Z), Ink, P3(0, 0, -Off));
    D.SetGroup(D.Live - 1, G);
  end;
end;

end.
