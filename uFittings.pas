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

  { what the wizard builds }
  TFittingKind = (fkTransition, fkElbow, fkTee);
  { which way an elbow turns, seen from the entry }
  TTurn = (tuRight, tuLeft, tuUp, tuDown);
  { which wall of a tee the branch comes off }
  TBranchSide = (bsLeft, bsRight, bsTop, bsBottom);

  TTransitionSpec = record
    Kind: TFittingKind;
    W0, H0: Double;         { entry opening, width and height }
    W1, H1: Double;         { exit opening (a transition) }
    Len: Double;            { along the run }
    Side: TSideRule;
    SideAmount: Double;     { how far the named side comes in }
    Height: THeightRule;
    HeightAmount: Double;   { for top up / down, bottom up / down }
    Ends: array[0..2] of TEndSpec;  { entry, exit, and a tee's branch }
    Inch: Double;           { one inch in drawing units, for the fixed sizes }
    Dims: Boolean;          { put the sizes on it as dimensions }
    Tag: string;            { the name on the ticket, written on the part }
    { an elbow }
    Angle: Double;          { of the turn, radians }
    Turn: TTurn;
    Throat: Double;         { throat radius; 0 is a square throat }
    SquareHeel: Boolean;    { the heel mitred rather than rolled }
    Leg0, Leg1: Double;     { straight collars, entry side and exit side }
    { a tee: the run is W0 x H0 by Len }
    BW, BH: Double;         { the branch opening: along the run, and across }
    BranchOn: TBranchSide;
    BranchFrom: Double;     { entry to the near edge of the branch }
    BranchUp: Double;       { bottom (or left, for top and bottom) to the branch }
    BranchLen: Double;      { the branch collar }
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
  FITTING_NAMES: array[TFittingKind] of string = ('Transition', 'Elbow', 'Tee');
  TURN_NAMES: array[TTurn] of string = ('Right', 'Left', 'Up', 'Down');
  BRANCH_NAMES: array[TBranchSide] of string = ('Left side', 'Right side', 'Top', 'Bottom');

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
function BuildElbow(D: TWorkDoc; const T: TTransitionSpec; Ink: TColor;
  Weight: Single): Integer;
function BuildTee(D: TWorkDoc; const T: TTransitionSpec; Ink: TColor;
  Weight: Single): Integer;
{ whichever the spec says it is }
function BuildFitting(D: TWorkDoc; const T: TTransitionSpec; Ink: TColor;
  Weight: Single): Integer;

{ What is wrong with the spec, or '' when it can be built. }
function TransitionProblem(const T: TTransitionSpec): string;
function FittingProblem(const T: TTransitionSpec): string;

{ The ticket, as words: every input, in inches, one to a line.  What goes
  in the email and in the text file beside the pictures. }
function TicketText(const T: TTransitionSpec): string;

{ The plan outline of an elbow's cheek, for a sketch: throat points then
  heel points, as x along the width and y along the run. }
procedure ElbowCheek(const T: TTransitionSpec; out Pts: TP3Array);

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

function EndProblem(const T: TTransitionSpec; K: Integer; W, H: Double): string;
begin
  Result := '';
  if T.Ends[K].Kind = deRaw then Exit;
  if T.Ends[K].Amount <= 0 then
    Exit('The notch or flange on an end needs a size.');
  if T.Ends[K].Amount * 2 >= Min(W, H) then
    Exit('The notch or flange on an end is bigger than the opening.');
end;

function TransitionProblem(const T: TTransitionSpec): string;
begin
  Result := '';
  if (T.W0 <= 0) or (T.H0 <= 0) then Exit('The entry opening needs a width and a height.');
  if (T.W1 <= 0) or (T.H1 <= 0) then Exit('The exit opening needs a width and a height.');
  if T.Len <= 0 then Exit('The length has to be more than nothing.');
  if (T.Side in [srLeftIn, srRightIn]) and (T.SideAmount < 0) then
    Exit('A side comes in by a positive amount - name the other side to go the other way.');
  if (T.Height in [hrTopUp, hrTopDown, hrBottomUp, hrBottomDown]) and (T.HeightAmount < 0) then
    Exit('Up and down take a positive amount - name the other way to go the other way.');
  Result := EndProblem(T, 0, T.W0, T.H0);
  if Result = '' then Result := EndProblem(T, 1, T.W1, T.H1);
end;

function ElbowProblem(const T: TTransitionSpec): string;
var
  K: Integer;
begin
  Result := '';
  if (T.W0 <= 0) or (T.H0 <= 0) then Exit('The opening needs a width and a height.');
  if (T.Angle <= 0) or (T.Angle >= Pi) then Exit('The angle has to be between 0 and 180.');
  if T.Throat < 0 then Exit('The throat radius cannot be less than nothing - 0 is a square throat.');
  if (T.Leg0 < 0) or (T.Leg1 < 0) then Exit('A leg cannot be less than nothing.');
  for K := 0 to 1 do
  begin
    Result := EndProblem(T, K, T.W0, T.H0);
    if Result <> '' then Exit;
    { a notch or a flange is cut from straight metal, so an end that has one
      needs a leg at least that long to cut it from }
    if (T.Ends[K].Kind <> deRaw) and
       (((K = 0) and (T.Leg0 < T.Ends[K].Amount)) or ((K = 1) and (T.Leg1 < T.Ends[K].Amount))) then
      Exit('An end with a notch or flange needs a straight leg at least that long.');
  end;
end;

function TeeProblem(const T: TTransitionSpec): string;
var
  Across: Double;
begin
  Result := '';
  if (T.W0 <= 0) or (T.H0 <= 0) then Exit('The run needs a width and a height.');
  if T.Len <= 0 then Exit('The run needs a length.');
  if (T.BW <= 0) or (T.BH <= 0) then Exit('The branch opening needs a width and a height.');
  if T.BranchLen <= 0 then Exit('The branch needs a length.');
  if T.BranchFrom < 0 then Exit('The branch cannot start before the entry.');
  if T.BranchFrom + T.BW > T.Len + 1E-9 then Exit('The branch runs past the exit - lengthen the run.');
  if T.BranchOn in [bsLeft, bsRight] then Across := T.H0 else Across := T.W0;
  if T.BranchUp < 0 then Exit('The branch cannot sit below the bottom.');
  if T.BranchUp + T.BH > Across + 1E-9 then Exit('The branch is taller than the wall it comes off.');
  Result := EndProblem(T, 0, T.W0, T.H0);
  if Result = '' then Result := EndProblem(T, 1, T.W0, T.H0);
  if Result = '' then Result := EndProblem(T, 2, T.BW, T.BH);
end;

function FittingProblem(const T: TTransitionSpec): string;
begin
  case T.Kind of
    fkElbow: Result := ElbowProblem(T);
    fkTee: Result := TeeProblem(T);
  else
    Result := TransitionProblem(T);
  end;
end;

function TicketText(const T: TTransitionSpec): string;
const
  SideWords: array[TSideRule] of string = ('Centred', 'Left side in by', 'Right side in by');
  HeightWords: array[THeightRule] of string = ('Flat bottom (FB)', 'Flat top (FT)',
    'Centred', 'Top up by', 'Top down by', 'Bottom up by', 'Bottom down by');
var
  Inch: Double;
  function Ins(V: Double): string;
  begin
    Result := FormatFloat('0.###', V / Inch) + '"';
  end;
  function EndWords(const E: TEndSpec): string;
  begin
    Result := DUCT_END_NAMES[E.Kind];
    if E.Kind <> deRaw then Result := Result + ', ' + Ins(E.Amount);
  end;
begin
  Inch := T.Inch;
  if Inch <= 0 then Inch := 1 / 12;
  Result := FITTING_NAMES[T.Kind];
  if T.Tag <> '' then Result := Result + ': ' + T.Tag;
  Result := Result + LineEnding;
  case T.Kind of
    fkElbow:
      begin
        Result := Result +
          'Opening: ' + Ins(T.W0) + ' x ' + Ins(T.H0) + ' (width x height)' + LineEnding +
          'Angle: ' + FormatFloat('0.##', RadToDeg(T.Angle)) + ' degrees, turning ' +
            LowerCase(TURN_NAMES[T.Turn]) + LineEnding;
        if T.Throat > 0 then Result := Result + 'Throat radius: ' + Ins(T.Throat) + LineEnding
        else Result := Result + 'Square throat' + LineEnding;
        if T.SquareHeel then Result := Result + 'Square heel' + LineEnding
        else Result := Result + 'Heel radius: ' + Ins(T.Throat + T.W0) + LineEnding;
        Result := Result + 'Legs: ' + Ins(T.Leg0) + ' entry, ' + Ins(T.Leg1) + ' exit' + LineEnding;
      end;
    fkTee:
      begin
        Result := Result +
          'Run: ' + Ins(T.W0) + ' x ' + Ins(T.H0) + ' (width x height), ' + Ins(T.Len) + ' long' + LineEnding +
          'Branch: ' + Ins(T.BW) + ' x ' + Ins(T.BH) + ' off the ' + LowerCase(BRANCH_NAMES[T.BranchOn]) +
            ', ' + Ins(T.BranchLen) + ' long' + LineEnding +
          'Branch starts ' + Ins(T.BranchFrom) + ' from the entry, ' + Ins(T.BranchUp);
        if T.BranchOn in [bsLeft, bsRight] then Result := Result + ' up from the bottom' + LineEnding
        else Result := Result + ' in from the left' + LineEnding;
      end;
  else
    begin
      Result := Result +
        'Entry opening: ' + Ins(T.W0) + ' x ' + Ins(T.H0) + ' (width x height)' + LineEnding +
        'Exit opening: ' + Ins(T.W1) + ' x ' + Ins(T.H1) + LineEnding +
        'Length, entry to exit: ' + Ins(T.Len) + LineEnding +
        'Width: ' + SideWords[T.Side];
      if T.Side <> srCentred then Result := Result + ' ' + Ins(T.SideAmount);
      Result := Result + LineEnding + 'Height: ' + HeightWords[T.Height];
      if T.Height in [hrTopUp, hrTopDown, hrBottomUp, hrBottomDown] then
        Result := Result + ' ' + Ins(T.HeightAmount);
      Result := Result + LineEnding;
    end;
  end;
  Result := Result +
    'Entry end: ' + EndWords(T.Ends[0]) + LineEnding +
    'Exit end: ' + EndWords(T.Ends[1]) + LineEnding;
  if T.Kind = fkTee then
    Result := Result + 'Branch end: ' + EndWords(T.Ends[2]) + LineEnding;
end;

{ ------------------------------------------------------------------------ }
{ The pieces every fitting is made of.                                     }
{ ------------------------------------------------------------------------ }

type
  TP3x4 = array[0..3] of TP3;

  { What is being built into: the drawing, the group, the ink }
  TBuild = record
    D: TWorkDoc;
    G: Integer;
    Ink: TColor;
    Weight: Single;
    Inch: Double;
  end;

function Add(const A, B: TP3; F: Double): TP3;
begin
  Result := P3(A.X + B.X * F, A.Y + B.Y * F, A.Z + B.Z * F);
end;

function Towards(const A, B: TP3): TP3;
begin
  Result := Norm3(P3(B.X - A.X, B.Y - A.Y, B.Z - A.Z));
end;

procedure BLine(const B: TBuild; const P, Q: TP3);
begin
  if Dist(P, Q) < 1E-9 then Exit;
  B.D.AddLine(P, Q, B.Ink, B.Weight, False);
  B.D.SetGroup(B.D.Live - 1, B.G);
end;

procedure BFace(const B: TBuild; const P: array of TP3);
begin
  B.D.AddFaceRaw(P, B.Ink, True);
  B.D.SetFaceGroup(B.D.Live - 1, B.G);
end;

{ a flange or a lip: a face, and the three edges that are not the fold it
  hangs from }
procedure BStrip(const B: TBuild; const A, C, C2, A2: TP3);
begin
  BFace(B, [A, C, C2, A2]);
  BLine(B, C, C2); BLine(B, C2, A2); BLine(B, A2, A);
end;

procedure BDim(const B: TBuild; const P, Q, Off: TP3);
begin
  B.D.AddDim(P, Q, B.Ink, Off);
  B.D.SetGroup(B.D.Live - 1, B.G);
end;

{ A straight run of duct between two openings, E and X, each given as its
  four corners - bottom-left, bottom-right, top-right, top-left seen from
  the entry side.  Wall K runs from corner K to K + 1: 0 bottom, 1 right,
  2 top, 3 left.  Each end finished as its spec says; Draw says whether the
  opening edges at that end are drawn here or belong to whatever the run
  is joined to.  SkipWall leaves one wall out for the caller to draw - a
  tee cuts its branch out of it. }
procedure BuildRun(const B: TBuild; const E, X: TP3x4;
  const Ends: array of TEndSpec; const Draw: array of Boolean; SkipWall: Integer);
var
  C: array[0..1] of TP3x4;
  K, EndIx: Integer;
  Centre: TP3;
  Poly: array of TP3;
  P0, P1: array[0..5] of TP3;
  N0, N1, I: Integer;

  function Notch(EndIx: Integer): Double;
  begin
    if EndNotched(Ends[EndIx]) then Result := Ends[EndIx].Amount else Result := 0;
  end;

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

  function DriveWall(E, K: Integer): Boolean;
  begin
    case Ends[E].Kind of
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
    J: Integer;
    CI, CJ, U, SI, Nrm, A, C2, A2, B2: TP3;
    Nt, F, R: Double;
    P: array[0..5] of TP3;
    N: Integer;
  begin
    J := (K + 1) mod 4;
    CI := C[E][K]; CJ := C[E][J];
    U := Towards(CI, CJ);
    SI := Towards(CI, C[1 - E][K]);
    Nt := Notch(E);
    Nrm := OutNormal(K);
    case Ends[E].Kind of
      deFlangeOut, deFlangeIn, deTDF:
        begin
          { the fold line is the middle piece of the opening edge; the
            flange stops its own width short of each corner, which is the
            corner cut that lets the next side's flange fold }
          F := Ends[E].Amount;
          A := Add(CI, U, F);
          C2 := Add(CJ, U, -F);
          if Draw[E] then
          begin
            BLine(B, CI, A); BLine(B, A, C2); BLine(B, C2, CJ);
          end;
          if Ends[E].Kind = deFlangeIn then
            Nrm := P3(-Nrm.X, -Nrm.Y, -Nrm.Z);
          A2 := Add(A, Nrm, F);
          B2 := Add(C2, Nrm, F);
          BStrip(B, A, C2, B2, A2);
          if Ends[E].Kind = deTDF then
          begin
            { the fold back, along the duct, that the corner piece and the
              cleat take hold of }
            R := TDF_RETURN_IN * B.Inch;
            BStrip(B, A2, B2, Add(B2, SI, R), Add(A2, SI, R));
          end;
        end;
    else
      begin
        EndPath(E, K, P, N);
        if Nt > 0 then
        begin
          { the cut-outs, and the opening edge between them }
          BLine(B, P[0], P[1]); BLine(B, P[1], P[2]);
          BLine(B, P[2], P[3]);
          BLine(B, P[3], P[4]); BLine(B, P[4], P[5]);
        end
        else if Draw[E] then
          BLine(B, CI, CJ);
        if DriveWall(E, K) then
        begin
          F := DRIVE_FLANGE_IN * B.Inch;
          BStrip(B, P[2], P[3], Add(P[3], Nrm, F), Add(P[2], Nrm, F));
        end;
      end;
    end;
  end;

begin
  C[0] := E; C[1] := X;
  Centre := P3(0, 0, 0);
  for K := 0 to 3 do
  begin
    Centre := Add(Centre, C[0][K], 1);
    Centre := Add(Centre, C[1][K], 1);
  end;
  Centre := P3(Centre.X / 8, Centre.Y / 8, Centre.Z / 8);
  { the four walls, each wound so its normal points out of the duct: up the
    seam at the first corner, along the exit, down the seam at the second,
    back along the entry - stepping round the corner cut-outs where an end
    is notched }
  for K := 0 to 3 do
  begin
    if K = SkipWall then Continue;
    EndPath(0, K, P0, N0);
    EndPath(1, K, P1, N1);
    SetLength(Poly, N0 + N1);
    for I := 0 to N1 - 1 do Poly[I] := P1[I];
    for I := 0 to N0 - 1 do Poly[N1 + I] := P0[N0 - 1 - I];
    BFace(B, Poly);
  end;
  { the seams, from cut-out to cut-out }
  for K := 0 to 3 do
    BLine(B, Add(C[0][K], Towards(C[0][K], C[1][K]), Notch(0)),
             Add(C[1][K], Towards(C[1][K], C[0][K]), Notch(1)));
  { and each end of each wall, finished the way it was asked for }
  for EndIx := 0 to 1 do
    for K := 0 to 3 do
      FinishEnd(EndIx, K);
end;

function StartBuild(D: TWorkDoc; const T: TTransitionSpec; Ink: TColor;
  Weight: Single): TBuild;
begin
  Result.D := D;
  Result.G := D.NewGroup;
  Result.Ink := Ink;
  Result.Weight := Weight;
  Result.Inch := T.Inch;
  if Result.Inch <= 0 then Result.Inch := 1 / 12;
end;

{ the offset the dimensions and the tag stand off by }
function StandOff(const B: TBuild; const T: TTransitionSpec): Double;
begin
  Result := Max(4 * B.Inch, 0.15 * Max(Max(T.W0, T.H0), Max(T.W1, T.H1)));
end;

procedure BTag(const B: TBuild; const T: TTransitionSpec; const At: TP3);
begin
  if T.Tag = '' then Exit;
  B.D.AddText(At, T.Tag, B.Ink);
  B.D.SetGroup(B.D.Live - 1, B.G);
end;

{ ------------------------------------------------------------------------ }

function BuildTransition(D: TWorkDoc; const T: TTransitionSpec; Ink: TColor;
  Weight: Single): Integer;
var
  B: TBuild;
  E, X: TP3x4;
  Off: Double;
begin
  Result := D.Live;
  B := StartBuild(D, T, Ink, Weight);
  TransitionCorners(T, E, X);
  BuildRun(B, E, X, [T.Ends[0], T.Ends[1]], [True, True], -1);
  Off := StandOff(B, T);
  { its name, above the entry, so ten of them on a job can be told apart }
  BTag(B, T, P3(E[3].X, E[3].Y, E[3].Z + Off));
  { the sizes a ticket carries: both openings, and the run - the run being
    the gap, entry plane to exit plane, not the seam, which is longer
    whenever a side comes in }
  if T.Dims then
  begin
    BDim(B, E[0], E[1], P3(0, 0, -Off));
    BDim(B, E[1], E[2], P3(Off, 0, 0));
    BDim(B, X[3], X[2], P3(0, 0, Off));
    BDim(B, X[1], X[2], P3(Off, 0, 0));
    BDim(B, E[1], P3(E[1].X, X[1].Y, E[1].Z), P3(0, 0, -Off));
  end;
end;

{ The cheek of an elbow in its own plane: x across the turn, y along the
  run, the throat on the x = A side (the turn is towards +x), the entry
  across the bottom.  Throat points first, heel points back, so the list
  closes into the cheek outline. }
procedure CheekOutline(const T: TTransitionSpec; A: Double;
  out Throat, Heel: TP3Array; out N: Integer);
var
  R, Cx, Cy, Phi, Tt: Double;
  I: Integer;
  D, H1, Corner: TP3;
begin
  R := T.Throat;
  Cx := A + R; Cy := T.Leg0;
  N := Max(1, Round(T.Angle / (Pi / 24)));
  SetLength(Throat, N + 1);
  SetLength(Heel, N + 1);
  for I := 0 to N do
  begin
    Phi := T.Angle * I / N;
    Throat[I] := P3(Cx - R * Cos(Phi), Cy + R * Sin(Phi), 0);
    Heel[I] := P3(Cx - (R + A) * Cos(Phi), Cy + (R + A) * Sin(Phi), 0);
  end;
  if T.SquareHeel then
  begin
    { the heel is the two straight outer walls meeting at the mitre: where
      the entry's heel line meets the exit's }
    D := P3(Sin(T.Angle), Cos(T.Angle), 0);
    H1 := Heel[N];
    Tt := -H1.X / D.X;
    Corner := P3(0, H1.Y + Tt * D.Y, 0);
    SetLength(Heel, 3);
    Heel[0] := P3(0, Cy, 0);
    Heel[1] := Corner;
    Heel[2] := H1;
  end;
end;

procedure ElbowCheek(const T: TTransitionSpec; out Pts: TP3Array);
var
  Throat, Heel: TP3Array;
  N, I, K: Integer;
  A: Double;
  D: TP3;
begin
  if T.Turn in [tuUp, tuDown] then A := T.H0 else A := T.W0;
  CheekOutline(T, A, Throat, Heel, N);
  D := P3(Sin(T.Angle), Cos(T.Angle), 0);
  SetLength(Pts, Length(Throat) + Length(Heel) + 4);
  K := 0;
  Pts[K] := P3(A, 0, 0); Inc(K);
  for I := 0 to High(Throat) do begin Pts[K] := Throat[I]; Inc(K); end;
  Pts[K] := Add(Throat[High(Throat)], D, T.Leg1); Inc(K);
  Pts[K] := Add(Heel[High(Heel)], D, T.Leg1); Inc(K);
  for I := High(Heel) downto 0 do begin Pts[K] := Heel[I]; Inc(K); end;
  Pts[K] := P3(0, 0, 0); Inc(K);
  SetLength(Pts, K);
end;

function BuildElbow(D: TWorkDoc; const T: TTransitionSpec; Ink: TColor;
  Weight: Single): Integer;
var
  B: TBuild;
  A, Bc, Off: Double;
  Throat, Heel: TP3Array;
  N, I, K: Integer;
  Dir: TP3;
  E0, X0, E1, X1: TP3x4;    { the entry leg's ends, the exit leg's ends }
  Q: TP3x4;
  Poly: array of TP3;
  Order: array[0..3] of Integer;
  Raw: TEndSpec;

  { canonical to world: x across the turn, y along, z the constant side }
  function W(const P: TP3): TP3;
  begin
    case T.Turn of
      tuLeft: Result := P3(A - P.X, P.Y, P.Z);
      tuUp:   Result := P3(P.Z, P.Y, P.X);
      tuDown: Result := P3(P.Z, P.Y, A - P.X);
    else
      Result := P;
    end;
  end;

  { the four corners of an opening whose bottom edge in the cheek plane runs
    from heel point Hp to throat point Tp, in the world order the run
    builder wants: bottom-left, bottom-right, top-right, top-left }
  function Opening(const Hp, Tp: TP3): TP3x4;
  var
    Raw4: TP3x4;
    J: Integer;
  begin
    Raw4[0] := Hp; Raw4[1] := Tp;
    Raw4[2] := P3(Tp.X, Tp.Y, Bc); Raw4[3] := P3(Hp.X, Hp.Y, Bc);
    for J := 0 to 3 do Result[J] := W(Raw4[Order[J]]);
  end;

  procedure Lift(const P: TP3; out Lo, Hi: TP3);
  begin
    Lo := W(P);
    Hi := W(P3(P.X, P.Y, Bc));
  end;

var
  Lo, Hi, Lo2, Hi2: TP3;
begin
  Result := D.Live;
  B := StartBuild(D, T, Ink, Weight);
  if T.Turn in [tuUp, tuDown] then begin A := T.H0; Bc := T.W0; end
  else begin A := T.W0; Bc := T.H0; end;
  case T.Turn of
    tuLeft: begin Order[0] := 1; Order[1] := 0; Order[2] := 3; Order[3] := 2; end;
    tuUp, tuDown: begin Order[0] := 0; Order[1] := 3; Order[2] := 2; Order[3] := 1; end;
  else
    begin Order[0] := 0; Order[1] := 1; Order[2] := 2; Order[3] := 3; end;
  end;
  CheekOutline(T, A, Throat, Heel, N);
  Dir := P3(Sin(T.Angle), Cos(T.Angle), 0);
  Raw.Kind := deRaw; Raw.Amount := 0;
  { the entry leg }
  E0 := Opening(P3(0, 0, 0), P3(A, 0, 0));
  X0 := Opening(Heel[0], Throat[0]);
  if T.Leg0 > 0 then
    BuildRun(B, E0, X0, [T.Ends[0], Raw], [True, True], -1);
  { the exit leg }
  E1 := Opening(Heel[High(Heel)], Throat[N]);
  X1 := Opening(Add(Heel[High(Heel)], Dir, T.Leg1), Add(Throat[N], Dir, T.Leg1));
  if T.Leg1 > 0 then
    BuildRun(B, E1, X1, [Raw, T.Ends[1]], [True, True], -1);
  { the two cheeks: throat points forward, heel points back }
  for K := 0 to 1 do
  begin
    SetLength(Poly, Length(Throat) + Length(Heel));
    for I := 0 to High(Throat) do
      if K = 0 then Poly[I] := W(Throat[I]) else Poly[I] := W(P3(Throat[I].X, Throat[I].Y, Bc));
    for I := 0 to High(Heel) do
      if K = 0 then Poly[Length(Throat) + I] := W(Heel[High(Heel) - I])
      else Poly[Length(Throat) + I] := W(P3(Heel[High(Heel) - I].X, Heel[High(Heel) - I].Y, Bc));
    { a square throat has every throat point in one place; the polygon
      still closes, the doubled corners cost nothing }
    BFace(B, Poly);
  end;
  { the throat wrap, gore by gore, and its edges }
  for I := 0 to High(Throat) - 1 do
  begin
    if Dist(Throat[I], Throat[I + 1]) < 1E-9 then Continue;
    Lift(Throat[I], Lo, Hi);
    Lift(Throat[I + 1], Lo2, Hi2);
    BFace(B, [Lo, Lo2, Hi2, Hi]);
    BLine(B, Lo, Lo2); BLine(B, Hi, Hi2);
    if I > 0 then BLine(B, Lo, Hi);
  end;
  { the heel wrap }
  for I := 0 to High(Heel) - 1 do
  begin
    Lift(Heel[I], Lo, Hi);
    Lift(Heel[I + 1], Lo2, Hi2);
    BFace(B, [Lo, Lo2, Hi2, Hi]);
    BLine(B, Lo, Lo2); BLine(B, Hi, Hi2);
    if I > 0 then BLine(B, Lo, Hi);
  end;
  { the bend's own opening edges, where no leg draws them }
  if T.Leg0 <= 0 then
    for I := 0 to 3 do BLine(B, X0[I], X0[(I + 1) mod 4]);
  if T.Leg1 <= 0 then
    for I := 0 to 3 do BLine(B, E1[I], E1[(I + 1) mod 4]);
  { the square throat is one line where the two legs' throats meet }
  if T.Throat <= 0 then
  begin
    Lift(Throat[0], Lo, Hi);
    BLine(B, Lo, Hi);
  end;
  Off := StandOff(B, T);
  Q := E0;
  BTag(B, T, P3(Q[3].X, Q[3].Y, Q[3].Z + Off));
  if T.Dims then
  begin
    BDim(B, Q[0], Q[1], P3(0, 0, -Off));
    BDim(B, Q[1], Q[2], P3(Off, 0, 0));
    if T.Leg0 > 0 then BDim(B, Q[1], X0[1], P3(0, 0, -Off));
    if T.Leg1 > 0 then BDim(B, E1[1], X1[1], P3(0, 0, -Off));
  end;
end;

function BuildTee(D: TWorkDoc; const T: TTransitionSpec; Ink: TColor;
  Weight: Single): Integer;
var
  B: TBuild;
  E, X, BE, BX: TP3x4;
  Wall: Integer;
  Nrm, U, V, O: TP3;
  Raw: TEndSpec;
  Hole: TP3Array;
  I: Integer;
  Off: Double;
  WallPoly: TP3x4;
  P0: TP3;
begin
  Result := D.Live;
  B := StartBuild(D, T, Ink, Weight);
  E[0] := P3(0, 0, 0); E[1] := P3(T.W0, 0, 0); E[2] := P3(T.W0, 0, T.H0); E[3] := P3(0, 0, T.H0);
  for I := 0 to 3 do X[I] := P3(E[I].X, T.Len, E[I].Z);
  { the wall the branch comes off, the way out through it, and the two
    directions the opening is measured along: U along the run, V up the
    wall - or across it, for the top and the bottom }
  case T.BranchOn of
    bsLeft:   begin Wall := 3; Nrm := P3(-1, 0, 0); O := P3(0, 0, 0);     V := P3(0, 0, 1); end;
    bsRight:  begin Wall := 1; Nrm := P3(1, 0, 0);  O := P3(T.W0, 0, 0);  V := P3(0, 0, 1); end;
    bsTop:    begin Wall := 2; Nrm := P3(0, 0, 1);  O := P3(0, 0, T.H0);  V := P3(1, 0, 0); end;
  else
    begin Wall := 0; Nrm := P3(0, 0, -1); O := P3(0, 0, 0); V := P3(1, 0, 0); end;
  end;
  U := P3(0, 1, 0);
  Raw.Kind := deRaw; Raw.Amount := 0;
  { the run, less that wall }
  BuildRun(B, E, X, [T.Ends[0], T.Ends[1]], [True, True], Wall);
  { the opening: from BranchFrom along the run, BranchUp across the wall }
  Hole := nil;
  SetLength(Hole, 4);
  Hole[0] := Add(Add(O, U, T.BranchFrom), V, T.BranchUp);
  Hole[1] := Add(Hole[0], U, T.BW);
  Hole[2] := Add(Hole[1], V, T.BH);
  Hole[3] := Add(Hole[0], V, T.BH);
  { the wall with the opening in it }
  WallPoly[0] := E[Wall]; WallPoly[1] := X[Wall];
  WallPoly[2] := X[(Wall + 1) mod 4]; WallPoly[3] := E[(Wall + 1) mod 4];
  BFace(B, WallPoly);
  B.D.SetFaceHoles(B.D.Live - 1, [Hole]);
  for I := 0 to 3 do BLine(B, Hole[I], Hole[(I + 1) mod 4]);
  { the branch: its entry is the opening, ordered bottom-left, bottom-right,
    top-right, top-left seen from outside; its edges there are the hole's }
  case T.BranchOn of
    bsLeft:  begin BE[0] := Hole[1]; BE[1] := Hole[0]; BE[2] := Hole[3]; BE[3] := Hole[2]; end;
    bsRight: begin BE[0] := Hole[0]; BE[1] := Hole[1]; BE[2] := Hole[2]; BE[3] := Hole[3]; end;
    bsTop:   begin BE[0] := Hole[0]; BE[1] := Hole[1]; BE[2] := Hole[2]; BE[3] := Hole[3]; end;
  else
    begin BE[0] := Hole[1]; BE[1] := Hole[0]; BE[2] := Hole[3]; BE[3] := Hole[2]; end;
  end;
  for I := 0 to 3 do BX[I] := Add(BE[I], Nrm, T.BranchLen);
  BuildRun(B, BE, BX, [Raw, T.Ends[2]], [False, True], -1);
  Off := StandOff(B, T);
  BTag(B, T, P3(E[3].X, E[3].Y, E[3].Z + Off));
  if T.Dims then
  begin
    BDim(B, E[0], E[1], P3(0, 0, -Off));
    BDim(B, E[1], E[2], P3(Off, 0, 0));
    BDim(B, E[1], X[1], P3(0, 0, -Off));
    BDim(B, BX[0], BX[1], Add(P3(0, 0, 0), Nrm, Off));
    BDim(B, BX[1], BX[2], Add(P3(0, 0, 0), Nrm, Off));
    { where the branch starts: along the run from the entry, then up (or
      in) from the wall's edge, each measured straight, not corner to corner }
    P0 := Add(O, U, T.BranchFrom);
    BDim(B, O, P0, Add(P3(0, 0, 0), Nrm, Off));
    BDim(B, P0, Hole[0], Add(P3(0, 0, 0), Nrm, Off));
  end;
end;

function BuildFitting(D: TWorkDoc; const T: TTransitionSpec; Ink: TColor;
  Weight: Single): Integer;
begin
  case T.Kind of
    fkElbow: Result := BuildElbow(D, T, Ink, Weight);
    fkTee: Result := BuildTee(D, T, Ink, Weight);
  else
    Result := BuildTransition(D, T, Ink, Weight);
  end;
end;

end.
