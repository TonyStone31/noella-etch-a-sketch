unit uBore;

{ Tunnels that cross.

  A tunnel pushed through a solid is a set of lining walls.  When a second
  tunnel is pushed through the same solid and passes through the first, each
  one's walls run on through the other's bore - look into one and you see the
  other's walls in the way.  SketchUp leaves it like that until Intersect
  Faces is run by hand and the leftovers rubbed out.

  This does the whole of it at the push.  Where the new tunnel's walls cross
  an old one's, both are cut along the crossing; each wall is then divided
  into the pieces those cuts make, and the pieces lying inside the other
  tunnel's bore are dropped.  What is left is the manifold: one bore opening
  cleanly into the other, with the crossing drawn.  The dividing is the
  region engine's, fed a wall's own edges and the cuts across it. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Graphics, uWork, uRegion;

{ Cut the bore NewBore (an ekBore entity) against every other bore of the
  same solid it crosses.  Returns how many walls were divided. }
function CutCrossingBores(D: TWorkDoc; NewBore: Integer): Integer;

{ Strictly inside the tunnel's bore - not on its walls, not at its mouths. }
function InsideBore(D: TWorkDoc; Bore: Integer; const P: TP3; Tol: Double): Boolean;

{ How far the face may be pushed before it runs into a tunnel already through
  the solid: Dist itself when nothing is in the way, else the signed distance
  to the first tunnel wall the push would enter.  Push/pull stops there, the
  way SketchUp's does, and says so; Drill does not ask. }
function BoreLimit(D: TWorkDoc; Face: Integer; Dist: Double): Double;

implementation

type
  TCut = record
    FA, FB: Integer;       { the two walls that cross }
    S0, S1: TP3;           { where they do }
  end;

function Sub(const A, B: TP3): TP3; inline;
begin
  Result := P3(A.X - B.X, A.Y - B.Y, A.Z - B.Z);
end;

function Len(const A: TP3): Double; inline;
begin
  Result := Sqrt(A.X * A.X + A.Y * A.Y + A.Z * A.Z);
end;

function Scaled(const A: TP3; S: Double): TP3; inline;
begin
  Result := P3(A.X * S, A.Y * S, A.Z * S);
end;

function Add(const A, B: TP3): TP3; inline;
begin
  Result := P3(A.X + B.X, A.Y + B.Y, A.Z + B.Z);
end;

function Dist3(const A, B: TP3): Double; inline;
begin
  Result := Len(Sub(A, B));
end;

function BoreAxis(D: TWorkDoc; Bore: Integer): TP3;
begin
  Result := Norm3(Sub(D[Bore].B, D[Bore].Poly[0]));
end;

function BoreLen(D: TWorkDoc; Bore: Integer): Double;
begin
  Result := Dist(D[Bore].B, D[Bore].Poly[0]);
end;

{ how far P is from the nearest edge of the loop, both taken in the plane }
function DistToLoop(const P: TP3; const Loop: TP3Array): Double;
var
  I, N: Integer;
  A, B, E: TP3;
  T, L: Double;
begin
  Result := 1E300;
  N := Length(Loop);
  for I := 0 to N - 1 do
  begin
    A := Loop[I];
    B := Loop[(I + 1) mod N];
    E := Sub(B, A);
    L := Len(E);
    if L < 1E-12 then Continue;
    T := Dot3(Sub(P, A), E) / (L * L);
    if T < 0 then T := 0 else if T > 1 then T := 1;
    Result := Min(Result, Dist(P, Add(A, Scaled(E, T))));
  end;
end;

function InsideBore(D: TWorkDoc; Bore: Integer; const P: TP3; Tol: Double): Boolean;
var
  Ax, Q: TP3;
  T: Double;
begin
  Result := False;
  Ax := BoreAxis(D, Bore);
  T := Dot3(Sub(P, D[Bore].Poly[0]), Ax);
  if (T <= Tol) or (T >= BoreLen(D, Bore) - Tol) then Exit;
  Q := Sub(P, Scaled(Ax, T));
  if not PointInLoop(Q, D[Bore].Poly, Ax) then Exit;
  Result := DistToLoop(Q, D[Bore].Poly) > Tol;
end;

{ on the tunnel's wall surface: along its length and on the outline }
function OnBoreWall(D: TWorkDoc; Bore: Integer; const P: TP3; Tol: Double;
  out T: Double): Boolean;
var
  Ax, Q: TP3;
begin
  Result := False;
  Ax := BoreAxis(D, Bore);
  T := Dot3(Sub(P, D[Bore].Poly[0]), Ax);
  if (T < -Tol) or (T > BoreLen(D, Bore) + Tol) then Exit;
  Q := Sub(P, Scaled(Ax, T));
  Result := DistToLoop(Q, D[Bore].Poly) <= Tol;
end;

{ A face is a lining wall of the bore when every corner is on the bore's
  wall surface and the corners are not all at one place along it - that
  would be something lying across the mouth, not a wall. }
function IsLining(D: TWorkDoc; Bore, F: Integer; Tol: Double): Boolean;
var
  I: Integer;
  T, TMin, TMax: Double;
begin
  Result := False;
  if (D[F].Kind <> ekFace) or (D[F].Grp <> D[Bore].Grp) or (Length(D[F].Poly) < 3) then Exit;
  TMin := 1E300; TMax := -1E300;
  for I := 0 to High(D[F].Poly) do
  begin
    if not OnBoreWall(D, Bore, D[F].Poly[I], Tol, T) then Exit;
    TMin := Min(TMin, T); TMax := Max(TMax, T);
  end;
  Result := TMax - TMin > Tol;
end;

{ The parameters along the line L0 + t*Dir where it enters and leaves the
  flat polygon, as pairs.  Even-odd on the crossings with the polygon's
  edges, worked in the polygon's own plane. }
procedure LineThroughPoly(const L0, Dir: TP3; const Poly: TP3Array; const N: TP3;
  out Ts: array of Double; out Count: Integer; Tol: Double);
var
  AU, AV, A, B: TP3;
  I, J, K, M: Integer;
  lu, lv, du, dv, pu, pv, qu, qv, eu, ev, Den, T, S, Tmp: Double;
begin
  Count := 0;
  AxesFromNormal(N, AU, AV);
  lu := Dot3(L0, AU); lv := Dot3(L0, AV);
  du := Dot3(Dir, AU); dv := Dot3(Dir, AV);
  M := Length(Poly);
  for I := 0 to M - 1 do
  begin
    A := Poly[I]; B := Poly[(I + 1) mod M];
    pu := Dot3(A, AU); pv := Dot3(A, AV);
    qu := Dot3(B, AU); qv := Dot3(B, AV);
    eu := qu - pu; ev := qv - pv;
    Den := du * ev - dv * eu;
    if Abs(Den) < 1E-12 then Continue;
    { L0 + t Dir = A + s E }
    T := ((pu - lu) * ev - (pv - lv) * eu) / Den;
    S := ((pu - lu) * dv - (pv - lv) * du) / Den;
    if (S < -1E-9) or (S > 1 + 1E-9) then Continue;
    if Count >= Length(Ts) then Exit;
    Ts[Count] := T;
    Inc(Count);
  end;
  { sorted, and doubled-up corners taken once }
  for I := 0 to Count - 2 do
    for J := I + 1 to Count - 1 do
      if Ts[J] < Ts[I] then begin Tmp := Ts[I]; Ts[I] := Ts[J]; Ts[J] := Tmp; end;
  K := 0;
  for I := 0 to Count - 1 do
    if (K = 0) or (Abs(Ts[I] - Ts[K - 1]) > Tol) then
    begin
      Ts[K] := Ts[I];
      Inc(K);
    end;
  Count := K;
end;

{ Where two flat polygons cross: the segments of the line their planes share
  that lie inside both.  Parallel ones do not cross. }
function PolyCross(const PA: TP3Array; NA: TP3; const PB: TP3Array; NB: TP3;
  Tol: Double; out Segs: array of TCut; out NSegs: Integer): Boolean;
var
  Dir, L0: TP3;
  dA, dB, D2, T0, T1: Double;
  TA, TB: array[0..63] of Double;
  CA, CB, I, J: Integer;
begin
  Result := False;
  NSegs := 0;
  NA := Norm3(NA);
  NB := Norm3(NB);
  Dir := Cross3(NA, NB);
  D2 := Dot3(Dir, Dir);
  if D2 < 1E-12 then Exit;
  dA := Dot3(NA, PA[0]);
  dB := Dot3(NB, PB[0]);
  { a point on both planes }
  L0 := Scaled(Add(Scaled(Cross3(NB, Dir), dA), Scaled(Cross3(Dir, NA), dB)), 1 / D2);
  Dir := Norm3(Dir);
  LineThroughPoly(L0, Dir, PA, NA, TA, CA, Tol);
  LineThroughPoly(L0, Dir, PB, NB, TB, CB, Tol);
  { the intervals inside A are (TA[0],TA[1]), (TA[2],TA[3]) ...; same for B;
    the crossing is where those overlap }
  I := 0;
  while I + 1 < CA do
  begin
    J := 0;
    while J + 1 < CB do
    begin
      T0 := Max(TA[I], TB[J]);
      T1 := Min(TA[I + 1], TB[J + 1]);
      if (T1 - T0 > Tol) and (NSegs < Length(Segs)) then
      begin
        Segs[NSegs].FA := -1;
        Segs[NSegs].FB := -1;
        Segs[NSegs].S0 := Add(L0, Scaled(Dir, T0));
        Segs[NSegs].S1 := Add(L0, Scaled(Dir, T1));
        Inc(NSegs);
        Result := True;
      end;
      Inc(J, 2);
    end;
    Inc(I, 2);
  end;
end;

function FaceCross(D: TWorkDoc; FA, FB: Integer; Tol: Double;
  out Segs: array of TCut; out NSegs: Integer): Boolean;
var
  K: Integer;
begin
  Result := PolyCross(D[FA].Poly, D.FaceNormal(FA), D[FB].Poly, D.FaceNormal(FB), Tol, Segs, NSegs);
  for K := 0 to NSegs - 1 do
  begin
    Segs[K].FA := FA;
    Segs[K].FB := FB;
  end;
end;

function BoreLimit(D: TWorkDoc; Face: Integer; Dist: Double): Double;
var
  Nm, Ax: TP3;
  N, I, J, F, Bore, NSeg, K: Integer;
  Side: TP3Array;
  Segs: array[0..15] of TCut;
  Tol, Size, T, Best: Double;
  G: Integer;

  function Along(const P: TP3): Double;
  begin
    Result := Dot3(Sub(P, D[Face].Poly[0]), Ax);
  end;

begin
  Result := Dist;
  if (Face < 0) or (Face >= D.Live) or (D[Face].Kind <> ekFace) then Exit;
  N := Length(D[Face].Poly);
  if (N < 3) or (Abs(Dist) < 1E-9) then Exit;
  { whose solid: the face's own group, or the wall it lies on }
  G := D[Face].Grp;
  if G = 0 then
    for F := 0 to D.Live - 1 do
      if (D[F].Kind = ekFace) and D[F].Solid and (D[F].Grp <> 0) and
         (Abs(Abs(Dot3(Norm3(D.FaceNormal(F)), Norm3(D.FaceNormal(Face)))) - 1) < 1E-6) and
         (Abs(Dot3(Norm3(D.FaceNormal(F)), Sub(D[Face].Poly[0], D[F].Poly[0]))) < 1E-6) and
         PointInLoop(InnerPoint(D[Face].Poly, D.FaceNormal(Face)), D[F].Poly, D.FaceNormal(F)) then
      begin
        G := D[F].Grp;
        Break;
      end;
  if G = 0 then Exit;
  Nm := Norm3(D.FaceNormal(Face));
  Ax := Scaled(Nm, Sign(Dist));          { the way the push goes }
  Size := Abs(Dist);
  for I := 0 to N - 1 do Size := Max(Size, Dist3(D[Face].Poly[I], D[Face].Poly[0]));
  Tol := 1E-6 * (1 + Size);
  Best := Abs(Dist);
  SetLength(Side, 4);
  for Bore := 0 to D.Live - 1 do
  begin
    if (D[Bore].Kind <> ekBore) or (D[Bore].Grp <> G) then Continue;
    for F := 0 to D.Live - 1 do
    begin
      if not IsLining(D, Bore, F, Tol) then Continue;
      { the walls of the push, one per edge of the face, out to Dist }
      for I := 0 to N - 1 do
      begin
        J := (I + 1) mod N;
        Side[0] := D[Face].Poly[I];
        Side[1] := D[Face].Poly[J];
        Side[2] := Add(D[Face].Poly[J], Scaled(Ax, Abs(Dist)));
        Side[3] := Add(D[Face].Poly[I], Scaled(Ax, Abs(Dist)));
        if PolyCross(Side, Cross3(Sub(Side[1], Side[0]), Sub(Side[3], Side[0])),
                     D[F].Poly, D.FaceNormal(F), Tol, Segs, NSeg) then
          for K := 0 to NSeg - 1 do
          begin
            T := Min(Along(Segs[K].S0), Along(Segs[K].S1));
            if (T > Tol) and (T < Best) then Best := T;
          end;
      end;
      { and a wall of the tunnel that the push's own face would land on or
        pass through: its corners inside the swept prism }
      for I := 0 to High(D[F].Poly) do
      begin
        T := Along(D[F].Poly[I]);
        if (T > Tol) and (T < Best) and
           PointInLoop(Sub(D[F].Poly[I], Scaled(Ax, T)), D[Face].Poly, Nm) then
          Best := T;
      end;
    end;
  end;
  if Best < Abs(Dist) - Tol then Result := Sign(Dist) * Best;
end;

function CutCrossingBores(D: TWorkDoc; NewBore: Integer): Integer;
type
  TReplace = record
    Face: Integer;
    Pieces: array of TP3Array;
  end;
var
  Other, F, I, J, K, G, NCuts, NSeg, NRep: Integer;
  Tol, Size: Double;
  LA, LB: array of Integer;
  Cuts: array of TCut;
  Segs: array[0..15] of TCut;
  Reps: array of TReplace;
  Tmp: TReplace;
  FN: TP3;
  Ink: TColor;

  procedure Note(F: Integer; var L: array of Integer; var N: Integer);
  begin
    if N >= Length(L) then Exit;
    L[N] := F;
    Inc(N);
  end;

  { divide wall F by the cuts across it, dropping what lies in bore Against }
  procedure Divide(F, Against: Integer);
  var
    S: TSegArray;
    R: TRegionArray;
    NS, I, M, Kept: Integer;
    Drop: array of Boolean;
    Mid: TP3;
  begin
    M := Length(D[F].Poly);
    NS := 0;
    SetLength(S, M + NCuts);
    for I := 0 to M - 1 do
    begin
      S[NS].A := D[F].Poly[I];
      S[NS].B := D[F].Poly[(I + 1) mod M];
      Inc(NS);
    end;
    for I := 0 to NCuts - 1 do
      if (Cuts[I].FA = F) or (Cuts[I].FB = F) then
      begin
        S[NS].A := Cuts[I].S0;
        S[NS].B := Cuts[I].S1;
        Inc(NS);
      end;
    if NS = M then Exit;                 { nothing crosses this wall }
    SetLength(S, NS);
    R := BuildRegions(S);
    if Length(R) < 2 then Exit;
    SetLength(Drop, Length(R));
    Kept := 0;
    for I := 0 to High(R) do
    begin
      Mid := InnerPoint(R[I].Outer, R[I].Normal);
      Drop[I] := InsideBore(D, Against, Mid, Tol);
      if not Drop[I] then Inc(Kept);
    end;
    if Kept = Length(R) then Exit;       { crossed, but nothing of it is in the other bore }
    SetLength(Reps, NRep + 1);
    Reps[NRep].Face := F;
    SetLength(Reps[NRep].Pieces, Kept);
    Kept := 0;
    for I := 0 to High(R) do
      if not Drop[I] then
      begin
        Reps[NRep].Pieces[Kept] := Copy(R[I].Outer, 0, Length(R[I].Outer));
        Inc(Kept);
      end;
    Inc(NRep);
  end;

begin
  Result := 0;
  if (NewBore < 0) or (NewBore >= D.Live) or (D[NewBore].Kind <> ekBore) then Exit;
  G := D[NewBore].Grp;
  Size := BoreLen(D, NewBore);
  for I := 0 to High(D[NewBore].Poly) do
    Size := Max(Size, Dist(D[NewBore].Poly[I], D[NewBore].Poly[0]));
  Tol := 1E-6 * (1 + Size);
  NRep := 0;
  Reps := nil;

  for Other := 0 to D.Live - 1 do
  begin
    if (Other = NewBore) or (D[Other].Kind <> ekBore) or (D[Other].Grp <> G) then Continue;

    { the walls of each }
    SetLength(LA, D.Live); SetLength(LB, D.Live);
    I := 0; J := 0;
    for F := 0 to D.Live - 1 do
    begin
      if IsLining(D, Other, F, Tol) then Note(F, LA, I);
      if IsLining(D, NewBore, F, Tol) then Note(F, LB, J);
    end;
    SetLength(LA, I); SetLength(LB, J);
    if (Length(LA) = 0) or (Length(LB) = 0) then Continue;

    { every crossing between a wall of one and a wall of the other }
    NCuts := 0;
    SetLength(Cuts, 0);
    for I := 0 to High(LA) do
      for J := 0 to High(LB) do
        if FaceCross(D, LA[I], LB[J], Tol, Segs, NSeg) then
          for K := 0 to NSeg - 1 do
          begin
            SetLength(Cuts, NCuts + 1);
            Cuts[NCuts] := Segs[K];
            Inc(NCuts);
          end;
    if NCuts = 0 then Continue;

    for I := 0 to High(LA) do Divide(LA[I], NewBore);
    for I := 0 to High(LB) do Divide(LB[I], Other);

    { the crossings are edges now, so they draw }
    for I := 0 to NCuts - 1 do
      if not D.HasLine(Cuts[I].S0, Cuts[I].S1) then
      begin
        D.AddLine(Cuts[I].S0, Cuts[I].S1, D[LA[0]].Ink, 1, False);
        D.SetGroup(D.Live - 1, G);
      end;
  end;

  { replace the divided walls by their pieces - highest index first, so the
    numbers below do not shift; each piece faces the way its wall faced }
  for I := 0 to NRep - 2 do
    for J := 0 to NRep - 2 - I do
      if Reps[J].Face < Reps[J + 1].Face then
      begin
        Tmp := Reps[J];
        Reps[J] := Reps[J + 1];
        Reps[J + 1] := Tmp;
      end;
  for I := 0 to NRep - 1 do
  begin
    F := Reps[I].Face;
    FN := D.FaceNormal(F);
    Ink := D[F].Ink;
    D.Delete(F);
    for J := 0 to High(Reps[I].Pieces) do
    begin
      D.AddFaceRaw(Reps[I].Pieces[J], Ink, True);
      D.SetFaceGroup(D.Live - 1, G);
      if Dot3(D.FaceNormal(D.Live - 1), FN) < 0 then D.FlipFace(D.Live - 1);
    end;
    Inc(Result);
  end;
end;

end.
