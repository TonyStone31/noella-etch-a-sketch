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
  THeightRule = (hrFlatBottom, hrFlatTop, hrCentred, hrTopUp, hrBottomDown);

  TTransitionSpec = record
    W0, H0: Double;         { entry opening, width and height }
    W1, H1: Double;         { exit opening }
    Len: Double;            { along the run }
    Side: TSideRule;
    SideAmount: Double;     { how far the named side comes in }
    Height: THeightRule;
    HeightAmount: Double;   { for top up / bottom down }
  end;

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
    top up lifts the whole ceiling, bottom down drops the whole floor }
  case T.Height of
    hrFlatBottom: ZB := 0;
    hrFlatTop:    ZB := T.H0 - T.H1;
    hrTopUp:      ZB := (T.H0 + T.HeightAmount) - T.H1;
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
begin
  Result := '';
  if (T.W0 <= 0) or (T.H0 <= 0) then Exit('The entry opening needs a width and a height.');
  if (T.W1 <= 0) or (T.H1 <= 0) then Exit('The exit opening needs a width and a height.');
  if T.Len <= 0 then Exit('The length has to be more than nothing.');
  if (T.Side in [srLeftIn, srRightIn]) and (T.SideAmount < 0) then
    Exit('A side comes in by a positive amount - name the other side to go the other way.');
  if (T.Height in [hrTopUp, hrBottomDown]) and (T.HeightAmount < 0) then
    Exit('Top up and bottom down take a positive amount.');
end;

function BuildTransition(D: TWorkDoc; const T: TTransitionSpec; Ink: TColor;
  Weight: Single): Integer;
var
  E, X: array[0..3] of TP3;
  Side: array[0..3] of TP3;
  I, J, G: Integer;
begin
  Result := D.Live;
  TransitionCorners(T, E, X);
  G := D.NewGroup;
  { the four sides, each wound so its normal points out of the duct: the
    entry edge from corner I to J, then back along the exit from J to I }
  for I := 0 to 3 do
  begin
    J := (I + 1) mod 4;
    Side[0] := E[I]; Side[1] := X[I]; Side[2] := X[J]; Side[3] := E[J];
    D.AddFaceRaw(Side, Ink, True);
    D.SetFaceGroup(D.Live - 1, G);
  end;
  { and the edges: the two openings and the four seams }
  for I := 0 to 3 do
  begin
    J := (I + 1) mod 4;
    D.AddLine(E[I], E[J], Ink, Weight, False); D.SetGroup(D.Live - 1, G);
    D.AddLine(X[I], X[J], Ink, Weight, False); D.SetGroup(D.Live - 1, G);
    D.AddLine(E[I], X[I], Ink, Weight, False); D.SetGroup(D.Live - 1, G);
  end;
end;

end.
