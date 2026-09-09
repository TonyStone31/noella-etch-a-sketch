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
    btnRef, btnEdgeA, btnEdgeB, btnRun: TButton;
    btnBack, btnNext, btnCancel: TButton;
    procedure PicPaint(Sender: TObject);
    procedure Changed(Sender: TObject);
    procedure RefClick(Sender: TObject);
    procedure RunClick(Sender: TObject);
    procedure PaintFurnace(C: TCanvas; W, H: Integer);
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
  btnRun := TButton.Create(Self); btnRun.Parent := Self; btnRun.OnClick := @RunClick;
  btnRun.SetBounds(560, 10, 180, 28);

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
        if FSpec.Vertical then
        begin
          lblStep.Caption := 'Step 1 of 3 - front to back, from the wall behind the furnace';
          lblSay.Caption := 'Seen from the side.  The entry is the collar on top of the furnace, the exit the ' +
            'opening in the trunk above.  Hook the tape on the back wall and read to the back or the front of each.';
          if FSpec.RefH = rhFloor then btnRef.Caption := 'taped from the back wall' else btnRef.Caption := 'taped from the front';
          if FSpec.RefH0Top then btnEdgeA.Caption := 'to the front' else btnEdgeA.Caption := 'to the back';
          if FSpec.RefH1Top then btnEdgeB.Caption := 'to the front' else btnEdgeB.Caption := 'to the back';
        end
        else
        begin
          lblStep.Caption := 'Step 1 of 3 - the height, from the floor or the ceiling';
          lblSay.Caption := 'The duct hangs in a hallway, entry end nearest.  Hook the tape on the floor, or on ' +
            'the ceiling, and read to whichever edge of the duct you can reach at each end - say which under each box.';
          if FSpec.RefH = rhFloor then btnRef.Caption := 'taped from the floor' else btnRef.Caption := 'taped from the ceiling';
          if FSpec.RefH0Top then btnEdgeA.Caption := 'to the top' else btnEdgeA.Caption := 'to the bottom';
          if FSpec.RefH1Top then btnEdgeB.Caption := 'to the top' else btnEdgeB.Caption := 'to the bottom';
        end;
        edA.Text := FormatFloat('0.###', FSpec.RefH0 / FSpec.Inch);
        edB.Text := FormatFloat('0.###', FSpec.RefH1 / FSpec.Inch);
        btnNext.Caption := 'Next >';
      end;
    1:
      begin
        if FSpec.Vertical then
        begin
          lblStep.Caption := 'Step 2 of 3 - left to right, from a wall beside the furnace';
          lblSay.Caption := 'Seen from the front.  Hook the tape on the wall to the left or the right and read ' +
            'to whichever side of the collar, and of the trunk opening, you can reach.';
        end
        else
        begin
          lblStep.Caption := 'Step 2 of 3 - the width, from a wall';
          lblSay.Caption := 'Hook the tape on the wall to the left or the right of the run, looking from the ' +
            'entry to the exit, and read to whichever side you can reach at each end.';
        end;
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
  if FSpec.Vertical then btnRun.Caption := 'vertical run, off a furnace' else btnRun.Caption := 'horizontal run, in a hall';
  btnRun.Visible := FPage < 2;
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

procedure TTapeWizard.RunClick(Sender: TObject);
begin
  ReadPage;
  FSpec.Vertical := not FSpec.Vertical;
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
  if FPage >= 2 then PaintResult(pbPic.Canvas, pbPic.Width, pbPic.Height)
  else if FSpec.Vertical then PaintFurnace(pbPic.Canvas, pbPic.Width, pbPic.Height)
  else PaintScene(pbPic.Canvas, pbPic.Width, pbPic.Height);
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
  Quad(X0, X1, X2, X3, $00A4A8AA);                { the far opening, closed }
  Quad(E3, E2, X2, X3, $00E2E4E4);                { top, catching the light }
  Quad(E0, E1, X1, X0, $00909496);                { bottom }
  Quad(E0, E3, X3, X0, $00C8CBCC);                { left side }
  Quad(E1, E2, X2, X1, $00B2B6B8);                { right side }
  Quad(E0, E1, E2, E3, $00585C60);                { the entry opening, dark inside }
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

{ ---- the furnace -----------------------------------------------------------

  A vertical run: the furnace standing on the floor against a wall, its
  collar on top - the entry - and the trunk above with the opening the
  transition rises to - the exit.  Two flat cartoons: the side view for
  front-to-back, the front view for left-to-right, the furnace laid on its
  back in the builder's words - top is front, bottom is back. }
procedure TTapeWizard.PaintFurnace(C: TCanvas; W, H: Integer);
const
  FURN_W = 2.2; FURN_D = 2.6; FURN_H = 3.8; COLLAR_H = 0.5; GAP = 1.3; TRUNK_H = 1.0;
var
  T: TTransitionSpec;
  E, X: array[0..3] of TP3;
  Room, Tall, ScX, ScY, XOff: Double;
  Side: Boolean;                 { the side view (page 0) or the front (page 1) }
  FX, FW, DA, DB, EntA, EntB, ExA, ExB, Shift: Double;
  FloorY, RefX, I: Integer;
  Y0, Y1, TX0, TX1: Integer;
  Txt: string;

  function SX(V: Double): Integer; begin Result := Round(XOff + V * ScX); end;
  function SY(V: Double): Integer; begin Result := Round(FloorY - V * ScY); end;

  procedure Box(X0, Y0, X1, Y1: Integer; Fill: TColor);
  begin
    C.Brush.Color := Fill; C.Brush.Style := bsSolid;
    C.Pen.Color := $00404448;
    C.Rectangle(X0, Y0, X1, Y1);
  end;

  procedure Tape(X0, Y, X1: Integer; const S: string);
  begin
    C.Pen.Color := TAPE_COL; C.Pen.Width := 3;
    C.Line(X0, Y, X1, Y);
    C.Line(X0, Y - 7, X0, Y + 7);
    C.Line(X1, Y - 7, X1, Y + 7);
    C.Pen.Width := 1;
    C.Brush.Color := TAPE_COL; C.Brush.Style := bsSolid;
    C.Rectangle(X0 - 6, Y - 6, X0 + 6, Y + 6);
    C.Brush.Style := bsClear;
    C.Font.Color := TAPE_COL; C.Font.Style := [fsBold]; C.Font.Size := 9;
    C.TextOut((X0 + X1) div 2 - C.TextWidth(S) div 2, Y - 22, S);
    C.Font.Style := [];
  end;

begin
  C.Brush.Color := clWhite;
  C.FillRect(0, 0, W, H);
  Side := FPage = 0;
  T := FSpec;
  T.FromRef := True;
  TapeRules(T);
  TransitionCorners(T, E, X);
  { the room, in feet: the furnace a foot and a half off the reference
    wall, the collar centred on it, the trunk above with its opening off
    the collar by what the readings come to }
  Tall := FURN_H + COLLAR_H + GAP + TRUNK_H + 0.8;
  if Side then begin FW := FURN_D; DA := FSpec.H0; DB := FSpec.H1; end
  else begin FW := FURN_W; DA := FSpec.W0; DB := FSpec.W1; end;
  FX := 1.5;
  EntA := FX + (FW - DA) / 2;
  EntB := EntA + DA;
  if Side then ExA := EntA + X[0].Z else ExA := EntA + X[0].X;
  ExB := ExA + DB;
  Shift := 0.4 - Min(Min(EntA, ExA), FX);
  if Shift > 0 then
  begin
    FX := FX + Shift; EntA := EntA + Shift; EntB := EntB + Shift; ExA := ExA + Shift; ExB := ExB + Shift;
  end;
  Room := Max(FX + FW, Max(EntB, ExB)) + 1.5;
  { a cartoon: the heights to their own scale, the widths stretched a
    little so the room fills the picture }
  ScY := (H - 60) / Tall;
  ScX := Min((W - 60) / Room, ScY * 1.6);
  XOff := (W - Room * ScX) / 2;
  FloorY := H - 28;
  { the wall behind - brick - and the floor }
  C.Brush.Color := $007A92C6; C.Brush.Style := bsSolid; C.Pen.Style := psClear;
  C.Rectangle(0, 0, W, FloorY);
  C.Pen.Style := psSolid;
  C.Pen.Color := $00A0B4D8;
  Y0 := FloorY;
  I := 0;
  while Y0 > 0 do
  begin
    C.Line(0, Y0, W, Y0);
    TX0 := (I mod 2) * 22;
    while TX0 < W do begin C.Line(TX0, Y0 - 12, TX0, Y0); Inc(TX0, 44); end;
    Dec(Y0, 12); Inc(I);
  end;
  C.Brush.Color := $00D6D0C6; C.Pen.Color := $00B4AC9E;
  C.Rectangle(0, FloorY, W, H);
  Y0 := 0;
  while Y0 < W do begin C.Line(Y0, FloorY, Y0, H); Inc(Y0, 40); end;
  { the reference wall, drawn as the room's end: at the left or the right }
  if (Side and (FSpec.RefH = rhFloor)) or ((not Side) and (FSpec.RefW = rwLeft)) then RefX := SX(0)
  else RefX := SX(Room);
  C.Brush.Color := $00606468; C.Brush.Style := bsSolid; C.Pen.Style := psClear;
  if RefX < W div 2 then C.Rectangle(0, 0, RefX, FloorY) else C.Rectangle(RefX, 0, W, FloorY);
  C.Pen.Style := psSolid;
  C.Font.Color := clWhite; C.Font.Size := 9;
  if Side then begin if FSpec.RefH = rhFloor then Txt := 'back wall' else Txt := 'front'; end
  else begin if FSpec.RefW = rwLeft then Txt := 'left wall' else Txt := 'right wall'; end;
  C.Brush.Style := bsClear;
  if RefX < W div 2 then C.TextOut(6, 8, Txt) else C.TextOut(W - 6 - C.TextWidth(Txt), 8, Txt);
  { the furnace: a cabinet with two panels and a little badge }
  Box(SX(FX), SY(FURN_H), SX(FX + FW), SY(0), $00B8BCC0);
  Box(SX(FX) + 8, SY(FURN_H) + 10, SX(FX + FW) - 8, SY(FURN_H * 0.55), $00A8ACB0);
  Box(SX(FX) + 8, SY(FURN_H * 0.5), SX(FX + FW) - 8, SY(0) - 8, $00B0B4B8);
  C.Brush.Style := bsClear;
  C.Font.Color := $00404448;
  C.TextOut(SX(FX) + 14, SY(FURN_H * 0.28), 'furnace');
  { the collar on top - the entry }
  Box(SX(EntA), SY(FURN_H + COLLAR_H), SX(EntB), SY(FURN_H), $00CACDCE);
  { the trunk above, and the opening in its underside - the exit }
  Box(SX(0.3), SY(FURN_H + COLLAR_H + GAP + TRUNK_H), SX(Room - 0.3), SY(FURN_H + COLLAR_H + GAP), $00C2C6C8);
  C.Pen.Color := $00404448;
  C.Brush.Color := $00585C60; C.Brush.Style := bsSolid;
  C.Rectangle(SX(ExA), SY(FURN_H + COLLAR_H + GAP) - 8, SX(ExB), SY(FURN_H + COLLAR_H + GAP) + 3);
  C.Brush.Style := bsClear;
  C.Font.Color := $00404448;
  C.TextOut(SX(0.3) + 8, SY(FURN_H + COLLAR_H + GAP + TRUNK_H) + 4, 'trunk');
  { the transition to be, dashed, collar to opening }
  C.Pen.Style := psDash;
  C.Pen.Color := $00606468;
  C.Polygon([Point(SX(EntA), SY(FURN_H + COLLAR_H)), Point(SX(EntB), SY(FURN_H + COLLAR_H)),
             Point(SX(ExB), SY(FURN_H + COLLAR_H + GAP)), Point(SX(ExA), SY(FURN_H + COLLAR_H + GAP))]);
  C.Pen.Style := psSolid;
  C.Font.Color := $00404448;
  C.TextOut(SX(EntB) + 6, SY(FURN_H + COLLAR_H / 2) - 8, 'entry');
  C.TextOut(SX(ExB) + 6, SY(FURN_H + COLLAR_H + GAP) - 6, 'exit');
  { the tapes: along the collar, and along the opening }
  Y0 := SY(FURN_H + COLLAR_H / 2);
  Y1 := SY(FURN_H + COLLAR_H + GAP) + 16;
  if Side then
  begin
    if FSpec.RefH0Top then TX0 := SX(EntB) else TX0 := SX(EntA);
    if FSpec.RefH1Top then TX1 := SX(ExB) else TX1 := SX(ExA);
    if FSpec.RefH = rhCeiling then
    begin
      { from the front: the far edge is the back }
      if FSpec.RefH0Top then TX0 := SX(EntB) else TX0 := SX(EntA);
    end;
    Tape(RefX, Y0, TX0, FormatLen(FSpec.RefH0, FUnits));
    Tape(RefX, Y1, TX1, FormatLen(FSpec.RefH1, FUnits));
  end
  else
  begin
    if FSpec.RefW0Right then TX0 := SX(EntB) else TX0 := SX(EntA);
    if FSpec.RefW1Right then TX1 := SX(ExB) else TX1 := SX(ExA);
    Tape(RefX, Y0, TX0, FormatLen(FSpec.RefW0, FUnits));
    Tape(RefX, Y1, TX1, FormatLen(FSpec.RefW1, FUnits));
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
  if T.Vertical then
  begin
    if T.RefH = rhFloor then S := 'from the back wall' else S := 'from the front';
    C.TextOut(50, Y, Format('%s: %s to the %s of the entry, %s to the %s of the exit',
      [S, FormatLen(T.RefH0, FUnits), Pick(T.RefH0Top, 'front', 'back'),
       FormatLen(T.RefH1, FUnits), Pick(T.RefH1Top, 'front', 'back')])); Inc(Y, 22);
  end
  else
  begin
    if T.RefH = rhFloor then S := 'from the floor' else S := 'from the ceiling';
    C.TextOut(50, Y, Format('%s: %s to the %s of the entry, %s to the %s of the exit',
      [S, FormatLen(T.RefH0, FUnits), Pick(T.RefH0Top, 'top', 'bottom'),
       FormatLen(T.RefH1, FUnits), Pick(T.RefH1Top, 'top', 'bottom')])); Inc(Y, 22);
  end;
  if T.RefW = rwLeft then S := 'from the left wall' else S := 'from the right wall';
  C.TextOut(50, Y, Format('%s: %s to the %s side of the entry, %s to the %s side of the exit',
    [S, FormatLen(T.RefW0, FUnits), Pick(T.RefW0Right, 'right', 'left'),
     FormatLen(T.RefW1, FUnits), Pick(T.RefW1Right, 'right', 'left')])); Inc(Y, 34);
  C.TextOut(30, Y, Format('With the entry %s x %s and the exit %s x %s.',
    [FormatLen(T.W0, FUnits), FormatLen(T.H0, FUnits), FormatLen(T.W1, FUnits), FormatLen(T.H1, FUnits)]));
  if T.Vertical then
  begin
    Inc(Y, 30);
    C.TextOut(30, Y, 'A vertical run is said the way the builder says it, the furnace laid on its back:');
    Inc(Y, 22);
    C.TextOut(50, Y, 'top is the front of the duct, bottom is the back; left and right stay left and right.');
  end;
end;

end.
