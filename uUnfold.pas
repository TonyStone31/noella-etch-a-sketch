unit uUnfold;

{ Laying a piece out flat, the way a sheet metal shop does it.

  A surface can be laid flat without stretching only if it is developable -
  planes, cylinders, cones, and things made of those.  Most of the trade is,
  by design: a rectangular transition is four trapezoids, a square-to-round is
  triangular facets and cone segments, an elbow is gores off a cylinder.  A
  dome is not, and never will be, and this says so rather than handing over a
  pattern that does not fit.

  The method is the one the layout books teach, and for the same reason.  Cut
  the piece into triangles; a triangle is flat whatever else is true.  Work
  out which triangle touches which.  Choose a spanning tree of that - the
  edges kept in the tree stay joined and become bends, the ones left out
  become cuts, so picking the tree is picking where the seam goes.  Then lay
  the first triangle down and unfold each of its neighbours about the edge
  they share, and their neighbours after them.  Every edge keeps its length,
  which is the whole trick and the reason the pattern fits.

  What this does not do is the half that decides whether it fits in the shop:
  seam allowance, bend allowance, grain, nesting.  Those are knowledge the
  person at the brake has and this program does not, and they belong in
  settings with defaults rather than being guessed at here. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, uWork;

type
  TIntArray = array of Integer;

  { A point on the sheet.  Its own type, so this unit needs nothing from the
    widget set to do arithmetic. }
  TFlatPt = record
    X, Y: Double;
  end;

  { What an edge of the pattern turns out to be. }
  TFoldKind = (
    fkCut,     // nothing joined here: it gets cut
    fkBend     // joined, and the metal turns: it gets a bend line
  );

  TFlatEdge = record
    AX, AY, BX, BY: Double;   // where it lies on the sheet
    Kind: TFoldKind;
    Angle: Double;            // how far the metal turns, radians, signed
  end;

  { One panel, laid out.  A face of the model, in the plane, still the same
    shape and the same size it was. }
  TFlatFace = record
    P: array of TFlatPt;
    Face: Integer;            // which face of the document it came from
  end;

  TFlatPattern = record
    Faces: array of TFlatFace;
    Edges: array of TFlatEdge;
    MinX, MinY, MaxX, MaxY: Double;   // the sheet it needs
    Overlaps: Boolean;                // it folds back onto itself
    Laid: Integer;                    // panels placed
    Total: Integer;                   // panels asked for
    Ok: Boolean;
    Why: string;
  end;

{ Lay the given faces of a document out flat.  Pass every face of one piece. }
function Unfold(const Doc: TWorkDoc; const Faces: array of Integer;
  Tol: Double = 1E-6): TFlatPattern;

{ Every face belonging to the same solid as the one given, so a click on any
  part of a piece lays the whole piece out. }
function SolidFaces(const Doc: TWorkDoc; Index: Integer): TIntArray;

implementation

type
  TPanel = record
    Doc: Integer;                 // index in the document
    V: TIntArray;                 // welded vertex numbers, in order
    L: array of TFlatPt;          // the panel in its own plane
    Q: array of TFlatPt;          // and where it ended up on the sheet
    Nm: TP3;
    Placed: Boolean;
  end;

  TEdgeRef = record
    A, B: Integer;
    F: array[0..1] of Integer;    // the panels that share it
    N: Integer;
  end;

function SolidFaces(const Doc: TWorkDoc; Index: Integer): TIntArray;
var
  I, N, G: Integer;
begin
  Result := nil;
  if (Index < 0) or (Index >= Doc.Live) then Exit;
  G := Doc[Index].Grp;
  N := 0;
  SetLength(Result, Doc.Live);
  for I := 0 to Doc.Live - 1 do
    if (Doc[I].Kind = ekFace) and (Length(Doc[I].Poly) >= 3) then
      { Grp nought means loose drawing rather than part of a solid, so a loose
        face is a piece all of its own. }
      if ((G <> 0) and (Doc[I].Grp = G)) or ((G = 0) and (I = Index)) then
      begin
        Result[N] := I;
        Inc(N);
      end;
  SetLength(Result, N);
end;

{ Do two laid-out panels cover the same ground?

  Panels that share a fold always touch, which is not overlapping.  Both are
  pulled a hair towards their own middle first, so touching does not count and
  folding back onto itself does.  A separating axis for each edge of each: if
  any line has one panel wholly on one side and the other wholly on the other,
  they are apart. }
function PanelsOverlap(const A, B: TFlatFace): Boolean;
const
  SHRINK = 0.02;
var
  P, Q: array of TFlatPt;
  I, J, K, N: Integer;
  EX, EY, D, MinA, MaxA, MinB, MaxB: Double;

  procedure Pull(const S: TFlatFace; out R: array of TFlatPt);
  var
    M: Integer;
    MX, MY: Double;
  begin
    MX := 0; MY := 0;
    for M := 0 to High(S.P) do
    begin
      MX := MX + S.P[M].X;
      MY := MY + S.P[M].Y;
    end;
    MX := MX / Length(S.P);
    MY := MY / Length(S.P);
    for M := 0 to High(S.P) do
    begin
      R[M].X := S.P[M].X + (MX - S.P[M].X) * SHRINK;
      R[M].Y := S.P[M].Y + (MY - S.P[M].Y) * SHRINK;
    end;
  end;

begin
  Result := False;
  if (Length(A.P) < 3) or (Length(B.P) < 3) then Exit;
  SetLength(P, Length(A.P));
  SetLength(Q, Length(B.P));
  Pull(A, P);
  Pull(B, Q);
  for K := 0 to 1 do
  begin
    if K = 0 then N := High(P) else N := High(Q);
    for I := 0 to N do
    begin
      if K = 0 then
      begin
        EX := P[(I + 1) mod Length(P)].Y - P[I].Y;
        EY := P[I].X - P[(I + 1) mod Length(P)].X;
      end
      else
      begin
        EX := Q[(I + 1) mod Length(Q)].Y - Q[I].Y;
        EY := Q[I].X - Q[(I + 1) mod Length(Q)].X;
      end;
      MinA := 1E30; MaxA := -1E30; MinB := 1E30; MaxB := -1E30;
      for J := 0 to High(P) do
      begin
        D := P[J].X * EX + P[J].Y * EY;
        MinA := Min(MinA, D); MaxA := Max(MaxA, D);
      end;
      for J := 0 to High(Q) do
      begin
        D := Q[J].X * EX + Q[J].Y * EY;
        MinB := Min(MinB, D); MaxB := Max(MaxB, D);
      end;
      if (MaxA <= MinB) or (MaxB <= MinA) then Exit(False);
    end;
  end;
  Result := True;
end;

function Unfold(const Doc: TWorkDoc; const Faces: array of Integer;
  Tol: Double): TFlatPattern;
var
  Pan: array of TPanel;
  Verts: array of TP3;
  Edges: array of TEdgeRef;
  NP, NV, NE: Integer;
  Order, Parent: TIntArray;
  I, J, K, F, Head, Tail, T, O, E, Ai, Bi: Integer;
  U, V, Nm, D3: TP3;
  Poly: TP3Array;
  Dot, Ang, Sx, Sy, Cs, Sn, LenL, LenP: Double;
  PA, PB, LA, LB, Inside: TFlatPt;

  function WeldVertex(const Q: TP3): Integer;
  var
    M2: Integer;
  begin
    for M2 := 0 to NV - 1 do
      if (Abs(Verts[M2].X - Q.X) < Tol) and (Abs(Verts[M2].Y - Q.Y) < Tol) and
         (Abs(Verts[M2].Z - Q.Z) < Tol) then Exit(M2);
    if NV >= Length(Verts) then SetLength(Verts, Max(16, NV * 2));
    Verts[NV] := Q;
    Result := NV;
    Inc(NV);
  end;

  function FindEdge(A, B: Integer): Integer;
  var
    M2: Integer;
  begin
    for M2 := 0 to NE - 1 do
      if ((Edges[M2].A = A) and (Edges[M2].B = B)) or
         ((Edges[M2].A = B) and (Edges[M2].B = A)) then Exit(M2);
    Result := -1;
  end;

  procedure NoteEdge(A, B, Panel: Integer);
  var
    M2: Integer;
  begin
    M2 := FindEdge(A, B);
    if M2 < 0 then
    begin
      if NE >= Length(Edges) then SetLength(Edges, Max(32, NE * 2));
      M2 := NE;
      Edges[M2].A := A;
      Edges[M2].B := B;
      Edges[M2].N := 0;
      Inc(NE);
    end;
    if Edges[M2].N < 2 then
    begin
      Edges[M2].F[Edges[M2].N] := Panel;
      Inc(Edges[M2].N);
    end;
  end;

  function CornerOf(Panel, Vtx: Integer): Integer;
  var
    M2: Integer;
  begin
    Result := -1;
    for M2 := 0 to High(Pan[Panel].V) do
      if Pan[Panel].V[M2] = Vtx then Exit(M2);
  end;

  function Mid(const S: array of TFlatPt): TFlatPt;
  var
    M2: Integer;
  begin
    Result.X := 0;
    Result.Y := 0;
    for M2 := 0 to High(S) do
    begin
      Result.X := Result.X + S[M2].X;
      Result.Y := Result.Y + S[M2].Y;
    end;
    Result.X := Result.X / Length(S);
    Result.Y := Result.Y / Length(S);
  end;

  { Which side of the line PA..PB a point falls. }
  function Side(const PA2, PB2, Pt: TFlatPt): Double;
  begin
    Result := (PB2.X - PA2.X) * (Pt.Y - PA2.Y) -
              (PB2.Y - PA2.Y) * (Pt.X - PA2.X);
  end;

begin
  Result := Default(TFlatPattern);
  NP := 0; NV := 0; NE := 0;
  SetLength(Pan, Max(4, Length(Faces)));
  SetLength(Verts, 64);
  SetLength(Edges, 128);

  { --- every face, in its own plane ---------------------------------- }
  for I := 0 to High(Faces) do
  begin
    F := Faces[I];
    if (F < 0) or (F >= Doc.Live) then Continue;
    if Doc[F].Kind <> ekFace then Continue;
    Poly := Doc[F].Poly;
    if Length(Poly) < 3 then Continue;
    if NP >= Length(Pan) then SetLength(Pan, NP * 2);
    Nm := Doc.FaceNormal(F);
    AxesFromNormal(Nm, U, V);
    Pan[NP].Doc := F;
    Pan[NP].Nm := Nm;
    Pan[NP].Placed := False;
    SetLength(Pan[NP].V, Length(Poly));
    SetLength(Pan[NP].L, Length(Poly));
    SetLength(Pan[NP].Q, Length(Poly));
    for J := 0 to High(Poly) do
    begin
      Pan[NP].V[J] := WeldVertex(Poly[J]);
      D3 := P3(Poly[J].X - Poly[0].X, Poly[J].Y - Poly[0].Y,
               Poly[J].Z - Poly[0].Z);
      Pan[NP].L[J].X := Dot3(D3, U);
      Pan[NP].L[J].Y := Dot3(D3, V);
    end;
    Inc(NP);
  end;
  Result.Total := NP;
  if NP = 0 then
  begin
    Result.Why := 'there are no faces here to lay out';
    Exit;
  end;

  { --- which panel touches which -------------------------------------- }
  for I := 0 to NP - 1 do
    for J := 0 to High(Pan[I].V) do
      NoteEdge(Pan[I].V[J], Pan[I].V[(J + 1) mod Length(Pan[I].V)], I);

  { --- walk the piece, unfolding as we go ----------------------------- }
  SetLength(Order, NP);
  SetLength(Parent, NP);
  for I := 0 to NP - 1 do Parent[I] := -1;

  Pan[0].Q := Copy(Pan[0].L);
  Pan[0].Placed := True;
  Order[0] := 0;
  Head := 0; Tail := 1;

  while Head < Tail do
  begin
    T := Order[Head];
    Inc(Head);
    for J := 0 to High(Pan[T].V) do
    begin
      E := FindEdge(Pan[T].V[J], Pan[T].V[(J + 1) mod Length(Pan[T].V)]);
      if (E < 0) or (Edges[E].N < 2) then Continue;
      if Edges[E].F[0] = T then O := Edges[E].F[1] else O := Edges[E].F[0];
      if (O < 0) or (O >= NP) or Pan[O].Placed then Continue;

      Ai := CornerOf(T, Edges[E].A);
      Bi := CornerOf(T, Edges[E].B);
      if (Ai < 0) or (Bi < 0) then Continue;
      PA := Pan[T].Q[Ai];
      PB := Pan[T].Q[Bi];

      Ai := CornerOf(O, Edges[E].A);
      Bi := CornerOf(O, Edges[E].B);
      if (Ai < 0) or (Bi < 0) then Continue;
      LA := Pan[O].L[Ai];
      LB := Pan[O].L[Bi];

      { The rigid move that puts the shared edge where the parent already has
        it.  Lengths are equal by construction - it is the same edge - so this
        is a turn and a shift and nothing else, which is why the pattern
        fits. }
      LenL := Sqrt(Sqr(LB.X - LA.X) + Sqr(LB.Y - LA.Y));
      LenP := Sqrt(Sqr(PB.X - PA.X) + Sqr(PB.Y - PA.Y));
      if (LenL < 1E-12) or (LenP < 1E-12) then Continue;
      Cs := ((LB.X - LA.X) * (PB.X - PA.X) +
             (LB.Y - LA.Y) * (PB.Y - PA.Y)) / (LenL * LenP);
      Sn := ((LB.X - LA.X) * (PB.Y - PA.Y) -
             (LB.Y - LA.Y) * (PB.X - PA.X)) / (LenL * LenP);

      for K := 0 to High(Pan[O].L) do
      begin
        Sx := Pan[O].L[K].X - LA.X;
        Sy := Pan[O].L[K].Y - LA.Y;
        Pan[O].Q[K].X := PA.X + Sx * Cs - Sy * Sn;
        Pan[O].Q[K].Y := PA.Y + Sx * Sn + Sy * Cs;
      end;

      { It has to open away from the parent, not fold back over it.  If the
        middle of the new panel came down the same side of the shared edge as
        the middle of the old one, mirror it across that edge. }
      Inside := Mid(Pan[T].Q);
      if Side(PA, PB, Mid(Pan[O].Q)) * Side(PA, PB, Inside) > 0 then
        for K := 0 to High(Pan[O].Q) do
        begin
          Sx := Pan[O].Q[K].X - PA.X;
          Sy := Pan[O].Q[K].Y - PA.Y;
          Cs := (PB.X - PA.X) / LenP;
          Sn := (PB.Y - PA.Y) / LenP;
          { reflect in the line through PA along (Cs, Sn) }
          Pan[O].Q[K].X := PA.X + Sx * (Cs * Cs - Sn * Sn) + Sy * (2 * Cs * Sn);
          Pan[O].Q[K].Y := PA.Y + Sx * (2 * Cs * Sn) - Sy * (Cs * Cs - Sn * Sn);
        end;

      Pan[O].Placed := True;
      Parent[O] := T;
      Order[Tail] := O;
      Inc(Tail);
    end;
  end;

  { --- hand back the panels ------------------------------------------- }
  Result.Laid := 0;
  SetLength(Result.Faces, NP);
  for I := 0 to NP - 1 do
    if Pan[I].Placed then
    begin
      Result.Faces[Result.Laid].Face := Pan[I].Doc;
      SetLength(Result.Faces[Result.Laid].P, Length(Pan[I].Q));
      for J := 0 to High(Pan[I].Q) do
        Result.Faces[Result.Laid].P[J] := Pan[I].Q[J];
      Inc(Result.Laid);
    end;
  SetLength(Result.Faces, Result.Laid);

  { --- and say what every edge is ------------------------------------- }
  SetLength(Result.Edges, NE);
  K := 0;
  for I := 0 to NE - 1 do
  begin
    T := Edges[I].F[0];
    if (T < 0) or (T >= NP) or not Pan[T].Placed then Continue;
    Ai := CornerOf(T, Edges[I].A);
    Bi := CornerOf(T, Edges[I].B);
    if (Ai < 0) or (Bi < 0) then Continue;
    Result.Edges[K].AX := Pan[T].Q[Ai].X;
    Result.Edges[K].AY := Pan[T].Q[Ai].Y;
    Result.Edges[K].BX := Pan[T].Q[Bi].X;
    Result.Edges[K].BY := Pan[T].Q[Bi].Y;
    Result.Edges[K].Angle := 0;
    Result.Edges[K].Kind := fkCut;
    if Edges[I].N = 2 then
    begin
      O := Edges[I].F[1];
      if O = T then O := Edges[I].F[0];
      Dot := EnsureRange(Dot3(Pan[T].Nm, Pan[O].Nm), -1, 1);
      Ang := ArcCos(Dot);
      D3 := P3(Verts[Edges[I].B].X - Verts[Edges[I].A].X,
               Verts[Edges[I].B].Y - Verts[Edges[I].A].Y,
               Verts[Edges[I].B].Z - Verts[Edges[I].A].Z);
      if Dot3(Cross3(Pan[T].Nm, Pan[O].Nm), D3) < 0 then Ang := -Ang;
      Result.Edges[K].Angle := Ang;
      if (Parent[O] = T) or (Parent[T] = O) then
        Result.Edges[K].Kind := fkBend;
    end;
    Inc(K);
  end;
  SetLength(Result.Edges, K);

  { --- the sheet it needs --------------------------------------------- }
  Result.MinX := 1E30; Result.MinY := 1E30;
  Result.MaxX := -1E30; Result.MaxY := -1E30;
  for I := 0 to High(Result.Faces) do
    for J := 0 to High(Result.Faces[I].P) do
    begin
      Result.MinX := Min(Result.MinX, Result.Faces[I].P[J].X);
      Result.MaxX := Max(Result.MaxX, Result.Faces[I].P[J].X);
      Result.MinY := Min(Result.MinY, Result.Faces[I].P[J].Y);
      Result.MaxY := Max(Result.MaxY, Result.Faces[I].P[J].Y);
    end;

  { --- does it fold back onto itself? --------------------------------- }
  Result.Overlaps := False;
  for I := 0 to High(Result.Faces) do
  begin
    for J := I + 1 to High(Result.Faces) do
      if PanelsOverlap(Result.Faces[I], Result.Faces[J]) then
      begin
        Result.Overlaps := True;
        Break;
      end;
    if Result.Overlaps then Break;
  end;

  Result.Ok := True;
  if Result.Laid < Result.Total then
    Result.Why := 'some of it is not joined to the rest';
end;

end.
