unit uTapeWizard;

{ The tape wizard: the offsets of a transition worked out from where the
  tape went, one picture at a time.

  The builder's own form takes the offsets as the shop says them - bottom
  up by 4, right side in by 7.  In the field what you have is a tape, a
  floor or a ceiling, and a wall, and a reading at each end to whichever
  edge of the duct you could reach.  This walks through that: a picture of
  the duct against the reference with a figure holding the tape, a box on
  each tape line for the reading, and a word under each box for the edge it
  landed on.  It ends with the offsets in shop words, and hands them back
  to the form.  Nothing here changes how the form works without it. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Types, Forms, Controls, StdCtrls, Graphics, ExtCtrls,
  uWork, uFittings;

type
  TTapeWizard = class(TForm)
  private
    FUnits: TUnitSystem;
    FSpec: TTransitionSpec;
    FPage: Integer;
    { the scene, worked out by Scene: the hall in feet, the perspective, and
      the duct's two openings in hall coordinates (x from the left wall, y
      above the floor) }
    FHallW, FHallH, FVPx, FVPy, FFar: Double;
    FML, FMT, FMB: Integer;
    FSceneW, FSceneH: Integer;
    FL0, FB0, FL1, FB1: Double;
    FT0, FT1: Double;
    FDimA0, FDimA1, FDimB0, FDimB1: TPoint;   { the two tape lines, ends }
    pbPic: TPaintBox;
    lblStep, lblSay, lblResult: TLabel;
    edA, edB: TEdit;
    btnRef, btnEdgeA, btnEdgeB: TButton;
    btnBack, btnNext, btnCancel: TButton;
    procedure PicPaint(Sender: TObject);
    procedure Changed(Sender: TObject);
    procedure RefClick(Sender: TObject);
    procedure EdgeClick(Sender: TObject);
    procedure BackClick(Sender: TObject);
    procedure NextClick(Sender: TObject);
    procedure ShowPage;
    function ReadPage: Boolean;
    function InchesOf(const S: string; out V: Double): Boolean;
    { the hallway: where everything is on screen, from the readings }
    procedure Scene(W, H: Integer);
    procedure PaintScene(C: TCanvas; W, H: Integer);
    procedure PlaceBoxes;
    procedure PaintResult(C: TCanvas; W, H: Integer);
  public
    constructor CreateWizard(AOwner: TComponent; Units: TUnitSystem; const Spec: TTransitionSpec);
    { Spec comes in with the sizes; goes out with the readings, FromRef
      and the rules they come to }
    class function Ask(Units: TUnitSystem; var Spec: TTransitionSpec): Boolean;
  end;

implementation

const
  TAPE_COL = $00A06030;
  INKG = $00505050;

constructor TTapeWizard.CreateWizard(AOwner: TComponent; Units: TUnitSystem; const Spec: TTransitionSpec);
begin
  inherited CreateNew(AOwner);
  FUnits := Units;
  FSpec := Spec;
  Caption := 'Tape it - the offsets from a floor or ceiling and a wall';
  Position := poMainFormCenter;
  BorderStyle := bsDialog;
  ClientWidth := 760;
  ClientHeight := 560;
  Color := clWhite;

  lblStep := TLabel.Create(Self);
  lblStep.Parent := Self;
  lblStep.Font.Size := 13;
  lblStep.Font.Style := [fsBold];
  lblStep.SetBounds(20, 12, 720, 26);

  lblSay := TLabel.Create(Self);
  lblSay.Parent := Self;
  lblSay.AutoSize := False;
  lblSay.WordWrap := True;
  lblSay.Font.Color := clGrayText;
  lblSay.SetBounds(20, 40, 720, 40);

  pbPic := TPaintBox.Create(Self);
  pbPic.Parent := Self;
  pbPic.SetBounds(20, 84, 720, 380);
  pbPic.OnPaint := @PicPaint;

  { the two readings and their edge words, placed on the picture by ShowPage }
  edA := TEdit.Create(Self); edA.Parent := Self; edA.Width := 70; edA.OnChange := @Changed;
  edB := TEdit.Create(Self); edB.Parent := Self; edB.Width := 70; edB.OnChange := @Changed;
  btnEdgeA := TButton.Create(Self); btnEdgeA.Parent := Self; btnEdgeA.Width := 110; btnEdgeA.Height := 26; btnEdgeA.OnClick := @EdgeClick;
  btnEdgeB := TButton.Create(Self); btnEdgeB.Parent := Self; btnEdgeB.Width := 110; btnEdgeB.Height := 26; btnEdgeB.OnClick := @EdgeClick;
  btnRef := TButton.Create(Self); btnRef.Parent := Self; btnRef.Width := 150; btnRef.Height := 26; btnRef.OnClick := @RefClick;

  lblResult := TLabel.Create(Self);
  lblResult.Parent := Self;
  lblResult.Font.Size := 11;
  lblResult.Font.Style := [fsBold];
  lblResult.SetBounds(20, 478, 720, 24);

  btnCancel := TButton.Create(Self);
  btnCancel.Parent := Self;
  btnCancel.Caption := 'Cancel';
  btnCancel.ModalResult := mrCancel;
  btnCancel.Cancel := True;
  btnCancel.SetBounds(20, 516, 100, 32);
  btnBack := TButton.Create(Self);
  btnBack.Parent := Self;
  btnBack.Caption := '< Back';
  btnBack.OnClick := @BackClick;
  btnBack.SetBounds(520, 516, 100, 32);
  btnNext := TButton.Create(Self);
  btnNext.Parent := Self;
  btnNext.Caption := 'Next >';
  btnNext.OnClick := @NextClick;
  btnNext.SetBounds(640, 516, 100, 32);

  edA.Text := FormatFloat('0.###', FSpec.RefH0 / FSpec.Inch);
  edB.Text := FormatFloat('0.###', FSpec.RefH1 / FSpec.Inch);
  FPage := 0;
  ShowPage;
end;

class function TTapeWizard.Ask(Units: TUnitSystem; var Spec: TTransitionSpec): Boolean;
var
  F: TTapeWizard;
begin
  Result := False;
  if Spec.Inch <= 0 then Spec.Inch := 1 / 12;
  F := TTapeWizard.CreateWizard(nil, Units, Spec);
  try
    if F.ShowModal <> mrOK then Exit;
    Spec := F.FSpec;
    Spec.FromRef := True;
    TapeRules(Spec);
    Result := True;
  finally
    F.Free;
  end;
end;

{ as the builder reads sizes: a bare number is inches, a mark makes it the
  drawing's own notation }
function TTapeWizard.InchesOf(const S: string; out V: Double): Boolean;
var
  T: string;
  F: Double;
begin
  T := Trim(S);
  V := 0;
  if T = '' then Exit(False);
  if (Pos('''', T) > 0) or (Pos('"', T) > 0) or (Pos('m', LowerCase(T)) > 0) then
    Result := ParseLen(T, FUnits, V)
  else
  begin
    Result := ParseLen(T + '"', usImperial, F);
    if Result then V := F;
  end;
end;

function Pick(B: Boolean; const Yes, No: string): string;
begin
  if B then Result := Yes else Result := No;
end;

{ the page's boxes into the spec; False when one will not read }
function TTapeWizard.ReadPage: Boolean;
var
  A, B: Double;
begin
  Result := InchesOf(edA.Text, A) and InchesOf(edB.Text, B);
  if not Result then Exit;
  if FPage = 0 then
  begin
    FSpec.RefH0 := A; FSpec.RefH1 := B;
  end
  else if FPage = 1 then
  begin
    FSpec.RefW0 := A; FSpec.RefW1 := B;
  end;
end;

procedure TTapeWizard.ShowPage;
var
  T: TTransitionSpec;
  OnPic: Boolean;
begin
  OnPic := FPage < 2;
  edA.Visible := OnPic; edB.Visible := OnPic;
  btnEdgeA.Visible := OnPic; btnEdgeB.Visible := OnPic; btnRef.Visible := OnPic;
  btnBack.Enabled := FPage > 0;
  case FPage of
    0:
      begin
        lblStep.Caption := 'Step 1 of 3 - the height, from the floor or the ceiling';
        lblSay.Caption := 'The duct hangs in a hallway, entry end nearest.  Hook the tape on the floor, or on ' +
          'the ceiling, and read to whichever edge of the duct you can reach at each end - say which under each box.';
        if FSpec.RefH = rhFloor then btnRef.Caption := 'taped from the floor' else btnRef.Caption := 'taped from the ceiling';
        edA.Text := FormatFloat('0.###', FSpec.RefH0 / FSpec.Inch);
        edB.Text := FormatFloat('0.###', FSpec.RefH1 / FSpec.Inch);
        if FSpec.RefH0Top then btnEdgeA.Caption := 'to the top' else btnEdgeA.Caption := 'to the bottom';
        if FSpec.RefH1Top then btnEdgeB.Caption := 'to the top' else btnEdgeB.Caption := 'to the bottom';
        btnNext.Caption := 'Next >';
      end;
    1:
      begin
        lblStep.Caption := 'Step 2 of 3 - the width, from a wall';
        lblSay.Caption := 'Hook the tape on the wall to the left or the right of the run, looking from the ' +
          'entry to the exit, and read to whichever side you can reach at each end.';
        if FSpec.RefW = rwLeft then btnRef.Caption := 'taped from the left wall' else btnRef.Caption := 'taped from the right wall';
        edA.Text := FormatFloat('0.###', FSpec.RefW0 / FSpec.Inch);
        edB.Text := FormatFloat('0.###', FSpec.RefW1 / FSpec.Inch);
        if FSpec.RefW0Right then btnEdgeA.Caption := 'to the right side' else btnEdgeA.Caption := 'to the left side';
        if FSpec.RefW1Right then btnEdgeB.Caption := 'to the right side' else btnEdgeB.Caption := 'to the left side';
        btnNext.Caption := 'Next >';
      end;
    2:
      begin
        lblStep.Caption := 'Step 3 of 3 - what it comes to';
        lblSay.Caption := 'These are the offsets in shop words, the way the ticket says them.  ' +
          'Use them and they go into the form; the readings go on the ticket too.';
        btnNext.Caption := 'Use these';
      end;
  end;
  PlaceBoxes;
  btnRef.SetBounds(pbPic.Left + (pbPic.Width - 170) div 2, pbPic.Top + pbPic.Height - 34, 170, 26);
  T := FSpec;
  T.FromRef := True;
  TapeRules(T);
  lblResult.Caption := 'So far: ' + TapeWords(T);
  pbPic.Invalidate;
end;

procedure TTapeWizard.Changed(Sender: TObject);
var
  T: TTransitionSpec;
begin
  if not ReadPage then
  begin
    lblResult.Caption := 'A reading did not read - 20, 20.5, 8 3/4, or 2'' with a mark.';
    Exit;
  end;
  T := FSpec;
  T.FromRef := True;
  TapeRules(T);
  lblResult.Caption := 'So far: ' + TapeWords(T);
  PlaceBoxes;
  pbPic.Invalidate;
end;

procedure TTapeWizard.RefClick(Sender: TObject);
begin
  ReadPage;
  if FPage = 0 then
  begin
    if FSpec.RefH = rhFloor then FSpec.RefH := rhCeiling else FSpec.RefH := rhFloor;
  end
  else if FSpec.RefW = rwLeft then FSpec.RefW := rwRight else FSpec.RefW := rwLeft;
  ShowPage;
end;

procedure TTapeWizard.EdgeClick(Sender: TObject);
begin
  ReadPage;
  if FPage = 0 then
  begin
    if Sender = btnEdgeA then FSpec.RefH0Top := not FSpec.RefH0Top else FSpec.RefH1Top := not FSpec.RefH1Top;
  end
  else
  begin
    if Sender = btnEdgeA then FSpec.RefW0Right := not FSpec.RefW0Right else FSpec.RefW1Right := not FSpec.RefW1Right;
  end;
  ShowPage;
end;

procedure TTapeWizard.BackClick(Sender: TObject);
begin
  ReadPage;
  if FPage > 0 then Dec(FPage);
  ShowPage;
end;

procedure TTapeWizard.NextClick(Sender: TObject);
begin
  if (FPage < 2) and not ReadPage then
  begin
    lblResult.Caption := 'A reading did not read - 20, 20.5, 8 3/4, or 2'' with a mark.';
    Exit;
  end;
  if FPage = 2 then
  begin
    ModalResult := mrOK;
    Exit;
  end;
  Inc(FPage);
  ShowPage;
end;

procedure TTapeWizard.PicPaint(Sender: TObject);
begin
  if FPage < 2 then PaintScene(pbPic.Canvas, pbPic.Width, pbPic.Height)
  else PaintResult(pbPic.Canvas, pbPic.Width, pbPic.Height);
end;

{ ---- the hallway ---------------------------------------------------------

  A cartoon: a hallway seen from the entry end, one-point perspective, a
  smooth ceiling above, tiles below, brick either side, and the duct
  floating in it where the readings put it - the entry opening near, the
  exit opening further down the hall.  The tape lines go from the
  reference to the edge each reading was taken to, on the opening it was
  taken at.  Both pages are this one picture with different tape lines. }

const
  DEPTH0 = 0.16;      { how far down the hall the entry opening sits }
  DEPTH1 = 0.55;      { and the exit }

procedure TTapeWizard.Scene(W, H: Integer);
var
  T: TTransitionSpec;
  E, X: array[0..3] of TP3;
  Lo, Hi: Double;
begin
  FSceneW := W;
  FSceneH := H;
  FML := 16; FMT := 12; FMB := 16;
  FFar := 0.36;
  { The duct hangs where a duct hangs: a foot below the ceiling, in the
    middle of the hall, entry end nearest.  The exit sits off the entry by
    whatever the readings come to, so the picture shows the offset going
    the right way; the readings themselves are the numbers on the tapes,
    not the height it is drawn at. }
  FHallW := 8;
  FHallH := 9;
  FB0 := FHallH - 1 - FSpec.H0;
  FL0 := (FHallW - FSpec.W0) / 2;
  T := FSpec;
  T.FromRef := True;
  TapeRules(T);
  TransitionCorners(T, E, X);
  FB1 := FB0 + X[0].Z;
  FL1 := FL0 + X[0].X;
  { a big offset gets a bigger hall rather than a duct through the wall }
  Lo := Min(FB0, FB1); Hi := Max(FB0 + FSpec.H0, FB1 + FSpec.H1);
  if Lo < 0.5 then
  begin
    FHallH := FHallH + (0.5 - Lo);
    FB0 := FB0 + (0.5 - Lo); FB1 := FB1 + (0.5 - Lo);
  end;
  if Hi > FHallH - 0.5 then FHallH := Hi + 0.5;
  Lo := Min(FL0, FL1); Hi := Max(FL0 + FSpec.W0, FL1 + FSpec.W1);
  if Lo < 0.5 then
  begin
    FHallW := FHallW + (0.5 - Lo);
    FL0 := FL0 + (0.5 - Lo); FL1 := FL1 + (0.5 - Lo);
  end;
  if Hi > FHallW - 0.5 then FHallW := Hi + 0.5;
  { the eye a little above the middle of the hall }
  FVPx := W / 2;
  FVPy := (H - FMB) - 0.55 * (H - FMB - FMT);
  FT0 := DEPTH0;
  FT1 := DEPTH1;
end;

procedure TTapeWizard.PaintScene(C: TCanvas; W, H: Integer);
var
  S: Double;

  function P(X, Y, T: Double): TPoint;
  var
    NX, NY, Sc: Double;
  begin
    Sc := 1 - T * (1 - FFar);
    NX := FML + X / FHallW * (W - 2 * FML);
    NY := (H - FMB) - Y / FHallH * (H - FMB - FMT);
    Result := Point(Round(FVPx + (NX - FVPx) * Sc), Round(FVPy + (NY - FVPy) * Sc));
  end;

  procedure Quad(const A, B, CC, D: TPoint; Fill: TColor);
  begin
    C.Brush.Color := Fill;
    C.Brush.Style := bsSolid;
    C.Pen.Color := Fill;
    C.Polygon([A, B, CC, D]);
  end;

  procedure Seg(const A, B: TPoint; Col: TColor; Wd: Integer);
  begin
    C.Pen.Color := Col;
    C.Pen.Width := Wd;
    C.Line(A.X, A.Y, B.X, B.Y);
    C.Pen.Width := 1;
  end;

  { a tape line between two hall points, its ticks, and a label }
  procedure Tape(const A, B: TPoint; const Txt: string; Horizontal: Boolean);
  var
    TX, TY: Integer;
  begin
    C.Pen.Color := TAPE_COL;
    C.Pen.Width := 3;
    C.Line(A.X, A.Y, B.X, B.Y);
    if Horizontal then
    begin
      C.Line(A.X, A.Y - 7, A.X, A.Y + 7);
      C.Line(B.X, B.Y - 7, B.X, B.Y + 7);
    end
    else
    begin
      C.Line(A.X - 7, A.Y, A.X + 7, A.Y);
      C.Line(B.X - 7, B.Y, B.X + 7, B.Y);
    end;
    C.Pen.Width := 1;
    { the tape case at the reference end }
    C.Brush.Color := TAPE_COL;
    C.Brush.Style := bsSolid;
    C.Pen.Color := TAPE_COL;
    C.Rectangle(A.X - 6, A.Y - 6, A.X + 6, A.Y + 6);
    C.Brush.Style := bsClear;
    C.Font.Color := TAPE_COL;
    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    TX := (A.X + B.X) div 2; TY := (A.Y + B.Y) div 2;
    if Horizontal then C.TextOut(TX - C.TextWidth(Txt) div 2, TY - 22, Txt)
    else C.TextOut(TX + 10, TY - 8, Txt);
    C.Font.Style := [];
  end;

var
  I, J: Integer;
  T, X, Y: Double;
  E0, E1, E2, E3, X0, X1, X2, X3: TPoint;
  Fl, Ce, Lw, Rw: TColor;
  Txt: string;
begin
  Scene(W, H);
  C.Brush.Color := clWhite;
  C.FillRect(0, 0, W, H);
  Fl := $00D2CCC2; Ce := $00F4F2EE; Lw := $007A92C6; Rw := $006E86BA;
  { the end of the hall, then the four surfaces }
  Quad(P(0, 0, 1), P(FHallW, 0, 1), P(FHallW, FHallH, 1), P(0, FHallH, 1), $00B0B8C4);
  Quad(P(0, FHallH, 0), P(FHallW, FHallH, 0), P(FHallW, FHallH, 1), P(0, FHallH, 1), Ce);
  Quad(P(0, 0, 0), P(FHallW, 0, 0), P(FHallW, 0, 1), P(0, 0, 1), Fl);
  Quad(P(0, 0, 0), P(0, FHallH, 0), P(0, FHallH, 1), P(0, 0, 1), Lw);
  Quad(P(FHallW, 0, 0), P(FHallW, FHallH, 0), P(FHallW, FHallH, 1), P(FHallW, 0, 1), Rw);
  { tiles: lines down the hall a foot apart, and across it closing up }
  X := 0;
  while X <= FHallW + 1E-9 do
  begin
    Seg(P(X, 0, 0), P(X, 0, 1), $00B4AC9E, 1);
    X := X + 1;
  end;
  for I := 1 to 14 do
  begin
    T := 1 - 1 / (1 + I * 0.28);
    Seg(P(0, 0, T), P(FHallW, 0, T), $00B4AC9E, 1);
  end;
  { brick courses on both walls, and a few joints }
  Y := 0;
  while Y <= FHallH do
  begin
    Seg(P(0, Y, 0), P(0, Y, 1), $00A0B4D8, 1);
    Seg(P(FHallW, Y, 0), P(FHallW, Y, 1), $00A0B4D8, 1);
    Y := Y + 0.33;
  end;
  for I := 1 to 12 do
  begin
    T := 1 - 1 / (1 + I * 0.28);
    J := I mod 2;
    Y := J * 0.33;
    while Y <= FHallH do
    begin
      Seg(P(0, Y, T), P(0, Y + 0.33, T), $00A0B4D8, 1);
      Seg(P(FHallW, Y, T), P(FHallW, Y + 0.33, T), $00A0B4D8, 1);
      Y := Y + 0.66;
    end;
  end;
  { a light in the ceiling, and its seams }
  Quad(P(FHallW / 2 - 1, FHallH, 0.3), P(FHallW / 2 + 1, FHallH, 0.3),
       P(FHallW / 2 + 1, FHallH, 0.42), P(FHallW / 2 - 1, FHallH, 0.42), $00FFFDF6);
  C.Font.Size := 9;
  C.Font.Color := $00606060;
  C.Brush.Style := bsClear;
  C.TextOut(P(FHallW / 2, FHallH, 0.06).X - 22, P(FHallW / 2, FHallH, 0.06).Y + 4, 'ceiling');
  C.TextOut(P(FHallW / 2, 0, 0.06).X - 14, P(FHallW / 2, 0, 0.06).Y - 20, 'floor');
  C.TextOut(P(0, FHallH * 0.5, 0.04).X + 6, P(0, FHallH * 0.5, 0.04).Y - 8, 'left wall');
  Txt := 'right wall';
  C.TextOut(P(FHallW, FHallH * 0.5, 0.04).X - 6 - C.TextWidth(Txt), P(FHallW, FHallH * 0.5, 0.04).Y - 8, Txt);
  { the duct: exit opening far, entry near, the sides between }
  X0 := P(FL1, FB1, FT1); X1 := P(FL1 + FSpec.W1, FB1, FT1);
  X2 := P(FL1 + FSpec.W1, FB1 + FSpec.H1, FT1); X3 := P(FL1, FB1 + FSpec.H1, FT1);
  E0 := P(FL0, FB0, FT0); E1 := P(FL0 + FSpec.W0, FB0, FT0);
  E2 := P(FL0 + FSpec.W0, FB0 + FSpec.H0, FT0); E3 := P(FL0, FB0 + FSpec.H0, FT0);
  Quad(X0, X1, X2, X3, $00A8AEB4);                { the far opening, closed }
  Quad(E3, E2, X2, X3, $00DCE0E4);                { top }
  Quad(E0, E1, X1, X0, $00A0A6AC);                { bottom }
  Quad(E0, E3, X3, X0, $00C4C9CE);                { left side }
  Quad(E1, E2, X2, X1, $00B4BABF);                { right side }
  Quad(E0, E1, E2, E3, $00505860);                { the entry opening, dark inside }
  C.Pen.Color := $00404448;
  C.Pen.Width := 2;
  C.Brush.Style := bsClear;
  C.Polygon([E0, E1, E2, E3]);
  C.Polygon([X0, X1, X2, X3]);
  Seg(E0, X0, $00404448, 1); Seg(E1, X1, $00404448, 1); Seg(E2, X2, $00404448, 1); Seg(E3, X3, $00404448, 1);
  { the exit opening seen through the entry, dashed, so the offset and
    the smaller size read even when the entry hides it }
  C.Pen.Style := psDash;
  C.Pen.Color := $00E0E4E8;
  C.Polygon([X0, X1, X2, X3]);
  C.Pen.Style := psSolid;
  C.Pen.Width := 1;
  C.Font.Color := clWhite;
  C.Font.Size := 9;
  C.TextOut(E0.X + 6, E3.Y + 4, 'entry');
  C.Font.Color := $00E0E4E8;
  C.TextOut(X1.X - 26, X1.Y - 16, 'exit');
  { the tapes }
  if FPage = 0 then
  begin
    if FSpec.RefH = rhFloor then
    begin
      if FSpec.RefH0Top then Y := FB0 + FSpec.H0 else Y := FB0;
      FDimA0 := P(FL0 - 0.7, 0, FT0); FDimA1 := P(FL0 - 0.7, Y, FT0);
      if FSpec.RefH1Top then Y := FB1 + FSpec.H1 else Y := FB1;
      FDimB0 := P(FL1 + FSpec.W1 + 0.7, 0, FT1); FDimB1 := P(FL1 + FSpec.W1 + 0.7, Y, FT1);
    end
    else
    begin
      if FSpec.RefH0Top then Y := FB0 + FSpec.H0 else Y := FB0;
      FDimA0 := P(FL0 - 0.7, FHallH, FT0); FDimA1 := P(FL0 - 0.7, Y, FT0);
      if FSpec.RefH1Top then Y := FB1 + FSpec.H1 else Y := FB1;
      FDimB0 := P(FL1 + FSpec.W1 + 0.7, FHallH, FT1); FDimB1 := P(FL1 + FSpec.W1 + 0.7, Y, FT1);
    end;
    { a dotted reach from the tape's end to the edge it lands on }
    C.Pen.Style := psDot;
    Seg(FDimA1, Point(E0.X, FDimA1.Y), TAPE_COL, 1);
    Seg(FDimB1, Point(X1.X, FDimB1.Y), TAPE_COL, 1);
    C.Pen.Style := psSolid;
    Tape(FDimA0, FDimA1, FormatLen(FSpec.RefH0, FUnits), False);
    Tape(FDimB0, FDimB1, FormatLen(FSpec.RefH1, FUnits), False);
  end
  else
  begin
    Y := FB0 + FSpec.H0 * 0.5;
    if FSpec.RefW = rwLeft then
    begin
      if FSpec.RefW0Right then X := FL0 + FSpec.W0 else X := FL0;
      FDimA0 := P(0, Y, FT0); FDimA1 := P(X, Y, FT0);
      Y := FB1 + FSpec.H1 * 0.5;
      if FSpec.RefW1Right then X := FL1 + FSpec.W1 else X := FL1;
      FDimB0 := P(0, Y, FT1); FDimB1 := P(X, Y, FT1);
    end
    else
    begin
      if FSpec.RefW0Right then X := FL0 + FSpec.W0 else X := FL0;
      FDimA0 := P(FHallW, Y, FT0); FDimA1 := P(X, Y, FT0);
      Y := FB1 + FSpec.H1 * 0.5;
      if FSpec.RefW1Right then X := FL1 + FSpec.W1 else X := FL1;
      FDimB0 := P(FHallW, Y, FT1); FDimB1 := P(X, Y, FT1);
    end;
    Tape(FDimA0, FDimA1, FormatLen(FSpec.RefW0, FUnits), True);
    Tape(FDimB0, FDimB1, FormatLen(FSpec.RefW1, FUnits), True);
  end;
end;

{ the reading boxes and their edge buttons beside their tape lines }
procedure TTapeWizard.PlaceBoxes;
var
  MX, MY: Integer;
begin
  if FPage >= 2 then Exit;
  Scene(pbPic.Width, pbPic.Height);
  { the tape ends are only known after a paint; place by the openings'
    positions instead, which Scene knows }
  MX := pbPic.Left + 12;
  MY := pbPic.Top + 60;
  edA.SetBounds(MX, MY, 70, 28);
  btnEdgeA.SetBounds(MX, MY + 32, 120, 26);
  MX := pbPic.Left + pbPic.Width - 132;
  edB.SetBounds(MX + 50, MY, 70, 28);
  btnEdgeB.SetBounds(MX, MY + 32, 120, 26);
end;

procedure TTapeWizard.PaintResult(C: TCanvas; W, H: Integer);
var
  T: TTransitionSpec;
  Y: Integer;
  S: string;
begin
  C.Brush.Color := clWhite;
  C.FillRect(0, 0, W, H);
  T := FSpec;
  T.FromRef := True;
  TapeRules(T);
  C.Font.Color := clBlack;
  C.Font.Size := 16;
  C.Font.Style := [fsBold];
  C.TextOut(30, 30, TapeWords(T));
  C.Font.Style := [];
  C.Font.Size := 10;
  C.Font.Color := INKG;
  Y := 90;
  C.TextOut(30, Y, 'From the readings:'); Inc(Y, 26);
  if T.RefH = rhFloor then S := 'from the floor' else S := 'from the ceiling';
  C.TextOut(50, Y, Format('%s: %s to the %s of the entry, %s to the %s of the exit',
    [S, FormatLen(T.RefH0, FUnits), Pick(T.RefH0Top, 'top', 'bottom'),
     FormatLen(T.RefH1, FUnits), Pick(T.RefH1Top, 'top', 'bottom')])); Inc(Y, 22);
  if T.RefW = rwLeft then S := 'from the left wall' else S := 'from the right wall';
  C.TextOut(50, Y, Format('%s: %s to the %s side of the entry, %s to the %s side of the exit',
    [S, FormatLen(T.RefW0, FUnits), Pick(T.RefW0Right, 'right', 'left'),
     FormatLen(T.RefW1, FUnits), Pick(T.RefW1Right, 'right', 'left')])); Inc(Y, 34);
  C.TextOut(30, Y, Format('With the entry %s x %s and the exit %s x %s.',
    [FormatLen(T.W0, FUnits), FormatLen(T.H0, FUnits), FormatLen(T.W1, FUnits), FormatLen(T.H1, FUnits)]));
end;

end.
