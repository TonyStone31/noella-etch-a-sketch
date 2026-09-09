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
    procedure PaintHeight(C: TCanvas; W, H: Integer);
    procedure PaintWidth(C: TCanvas; W, H: Integer);
    procedure PaintResult(C: TCanvas; W, H: Integer);
  public
    constructor CreateWizard(AOwner: TComponent; Units: TUnitSystem; const Spec: TTransitionSpec);
    { Spec comes in with the sizes; goes out with the readings, FromRef
      and the rules they come to }
    class function Ask(Units: TUnitSystem; var Spec: TTransitionSpec): Boolean;
  end;

implementation

const
  TAPE = $00A06030;
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
        lblSay.Caption := 'Hook the tape on the floor, or on the ceiling, and read to whichever edge of ' +
          'the duct you can reach at each end.  Say which edge under each box.  The entry usually reads 0.';
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
  { the boxes sit on the tape lines: entry at the left, exit at the right }
  edA.SetBounds(pbPic.Left + 118, pbPic.Top + 150, 70, 28);
  btnEdgeA.SetBounds(pbPic.Left + 98, pbPic.Top + 182, 110, 26);
  edB.SetBounds(pbPic.Left + 574, pbPic.Top + 150, 70, 28);
  btnEdgeB.SetBounds(pbPic.Left + 554, pbPic.Top + 182, 110, 26);
  btnRef.SetBounds(pbPic.Left + 285, pbPic.Top + 344, 150, 26);
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
  case FPage of
    0: PaintHeight(pbPic.Canvas, pbPic.Width, pbPic.Height);
    1: PaintWidth(pbPic.Canvas, pbPic.Width, pbPic.Height);
  else
    PaintResult(pbPic.Canvas, pbPic.Width, pbPic.Height);
  end;
end;

{ a stick figure standing on Y, reaching a hand to (HX, HY) }
procedure Figure(C: TCanvas; X, Y, HX, HY: Integer);
begin
  C.Pen.Color := INKG;
  C.Pen.Width := 2;
  C.Brush.Style := bsClear;
  C.Ellipse(X - 9, Y - 118, X + 9, Y - 100);
  C.Line(X, Y - 100, X, Y - 48);
  C.Line(X, Y - 48, X - 14, Y);
  C.Line(X, Y - 48, X + 14, Y);
  C.Line(X, Y - 90, HX, HY);
  C.Line(X, Y - 90, X - 16, Y - 60);
  C.Pen.Width := 1;
end;

{ a tape line from Y0 to Y1 at X, the case at the near end }
procedure TapeLine(C: TCanvas; X, Y0, Y1: Integer);
begin
  C.Pen.Color := TAPE;
  C.Pen.Width := 2;
  C.Line(X, Y0, X, Y1);
  C.Line(X - 6, Y0, X + 6, Y0);
  C.Line(X - 6, Y1, X + 6, Y1);
  C.Pen.Width := 1;
  C.Brush.Color := TAPE;
  C.Brush.Style := bsSolid;
  C.Rectangle(X - 7, Y0 - 7, X + 7, Y0 + 7);
  C.Brush.Style := bsClear;
end;

procedure TTapeWizard.PaintHeight(C: TCanvas; W, H: Integer);
var
  RefY, X0, X1, TX0, TX1, Ya0, Yb0, Ya1, Yb1, Y0, Y1: Integer;
  A0, A1, Ext, Sc: Double;
  Ceiling: Boolean;
  function YOf(V: Double): Integer;
  begin
    if Ceiling then Result := Round(RefY + V * Sc) else Result := Round(RefY - V * Sc);
  end;
begin
  C.Brush.Color := clWhite;
  C.FillRect(0, 0, W, H);
  Ceiling := FSpec.RefH = rhCeiling;
  { everything to one edge: the bottom from the floor, the top from the ceiling }
  if not Ceiling then
  begin
    if FSpec.RefH0Top then A0 := FSpec.RefH0 - FSpec.H0 else A0 := FSpec.RefH0;
    if FSpec.RefH1Top then A1 := FSpec.RefH1 - FSpec.H1 else A1 := FSpec.RefH1;
  end
  else
  begin
    if FSpec.RefH0Top then A0 := FSpec.RefH0 else A0 := FSpec.RefH0 - FSpec.H0;
    if FSpec.RefH1Top then A1 := FSpec.RefH1 else A1 := FSpec.RefH1 - FSpec.H1;
  end;
  Ext := Max(Max(A0 + FSpec.H0, A1 + FSpec.H1), Max(FSpec.RefH0, FSpec.RefH1));
  if Ext < 1E-9 then Ext := 1;
  Sc := (H - 130) / Ext;
  if Ceiling then RefY := 40 else RefY := H - 60;
  X0 := 280; X1 := 470;
  TX0 := 210; TX1 := 545;
  { the reference: a heavy line with hatching on its far side }
  C.Pen.Color := INKG;
  C.Pen.Width := 4;
  C.Line(20, RefY, W - 20, RefY);
  C.Pen.Width := 1;
  C.Pen.Color := $00B0B0B0;
  if Ceiling then
  begin
    C.Brush.Color := $00E8E8E8; C.Brush.Style := bsSolid;
    C.FillRect(20, RefY - 14, W - 20, RefY - 2);
  end
  else
  begin
    C.Brush.Color := $00E8E8E8; C.Brush.Style := bsSolid;
    C.FillRect(20, RefY + 2, W - 20, RefY + 14);
  end;
  C.Brush.Style := bsClear;
  C.Font.Color := INKG;
  C.Font.Size := 10;
  if Ceiling then C.TextOut(24, RefY + 16, 'ceiling') else C.TextOut(24, RefY - 32, 'floor');
  Ya0 := YOf(A0); Yb0 := YOf(A0 + FSpec.H0);
  Ya1 := YOf(A1); Yb1 := YOf(A1 + FSpec.H1);
  { the duct, side on: the two openings and the body between }
  C.Pen.Color := $00A0A0A0;
  C.Brush.Color := $00F0ECE6; C.Brush.Style := bsSolid;
  C.Polygon([Point(X0, Ya0), Point(X1, Ya1), Point(X1, Yb1), Point(X0, Yb0)]);
  C.Brush.Style := bsClear;
  C.Pen.Color := clBlack; C.Pen.Width := 3;
  C.Line(X0, Ya0, X0, Yb0);
  C.Line(X1, Ya1, X1, Yb1);
  C.Pen.Width := 1;
  C.Font.Color := clGray;
  C.TextOut(X0 - 16, Min(Ya0, Yb0) - 20, 'entry');
  C.TextOut(X1 - 12, Min(Ya1, Yb1) - 20, 'exit');
  { the tapes: from the reference to the edge each reading was taken to }
  if FSpec.RefH0Top = Ceiling then Y0 := Ya0 else Y0 := Yb0;
  if FSpec.RefH1Top = Ceiling then Y1 := Ya1 else Y1 := Yb1;
  { from the floor: the near edge is the bottom (Ya); to the top means Yb }
  if not Ceiling then
  begin
    if FSpec.RefH0Top then Y0 := Yb0 else Y0 := Ya0;
    if FSpec.RefH1Top then Y1 := Yb1 else Y1 := Ya1;
  end
  else
  begin
    if FSpec.RefH0Top then Y0 := Ya0 else Y0 := Yb0;
    if FSpec.RefH1Top then Y1 := Ya1 else Y1 := Yb1;
  end;
  TapeLine(C, TX0, RefY, Y0);
  TapeLine(C, TX1, RefY, Y1);
  { the leaders from the tapes to their boxes }
  C.Pen.Color := TAPE;
  C.Line(TX0, (RefY + Y0) div 2, 190, 164);
  C.Line(TX1, (RefY + Y1) div 2, 572, 164);
  { and the one holding the tape }
  if Ceiling then Figure(C, 110, H - 20, TX0 - 8, RefY + 8)
  else Figure(C, 110, RefY, TX0 - 8, Y0);
end;

procedure TTapeWizard.PaintWidth(C: TCanvas; W, H: Integer);
var
  RefY, X0, X1, TX0, TX1, Ya0, Yb0, Ya1, Yb1, Y0, Y1: Integer;
  A0, A1, Ext, Sc: Double;
  LeftWall: Boolean;
  function YOf(V: Double): Integer;
  begin
    if LeftWall then Result := Round(RefY + V * Sc) else Result := Round(RefY - V * Sc);
  end;
begin
  C.Brush.Color := clWhite;
  C.FillRect(0, 0, W, H);
  LeftWall := FSpec.RefW = rwLeft;
  if LeftWall then
  begin
    if FSpec.RefW0Right then A0 := FSpec.RefW0 - FSpec.W0 else A0 := FSpec.RefW0;
    if FSpec.RefW1Right then A1 := FSpec.RefW1 - FSpec.W1 else A1 := FSpec.RefW1;
  end
  else
  begin
    if FSpec.RefW0Right then A0 := FSpec.RefW0 else A0 := FSpec.RefW0 - FSpec.W0;
    if FSpec.RefW1Right then A1 := FSpec.RefW1 else A1 := FSpec.RefW1 - FSpec.W1;
  end;
  Ext := Max(Max(A0 + FSpec.W0, A1 + FSpec.W1), Max(FSpec.RefW0, FSpec.RefW1));
  if Ext < 1E-9 then Ext := 1;
  Sc := (H - 130) / Ext;
  { seen from above, entry on the left: the left of the run is the top }
  if LeftWall then RefY := 40 else RefY := H - 60;
  X0 := 280; X1 := 470;
  TX0 := 210; TX1 := 545;
  C.Pen.Color := INKG;
  C.Pen.Width := 6;
  C.Line(20, RefY, W - 20, RefY);
  C.Pen.Width := 1;
  C.Font.Color := INKG;
  C.Font.Size := 10;
  if LeftWall then C.TextOut(24, RefY + 8, 'left wall  (looking from the entry to the exit)')
  else C.TextOut(24, RefY - 26, 'right wall  (looking from the entry to the exit)');
  Ya0 := YOf(A0); Yb0 := YOf(A0 + FSpec.W0);
  Ya1 := YOf(A1); Yb1 := YOf(A1 + FSpec.W1);
  C.Pen.Color := $00A0A0A0;
  C.Brush.Color := $00F0ECE6; C.Brush.Style := bsSolid;
  C.Polygon([Point(X0, Ya0), Point(X1, Ya1), Point(X1, Yb1), Point(X0, Yb0)]);
  C.Brush.Style := bsClear;
  C.Pen.Color := clBlack; C.Pen.Width := 3;
  C.Line(X0, Ya0, X0, Yb0);
  C.Line(X1, Ya1, X1, Yb1);
  C.Pen.Width := 1;
  C.Font.Color := clGray;
  C.TextOut(X0 - 16, Max(Ya0, Yb0) + 6, 'entry');
  C.TextOut(X1 - 12, Max(Ya1, Yb1) + 6, 'exit');
  C.TextOut(X0 + 60, (Ya0 + Yb0 + Ya1 + Yb1) div 4 - 8, 'plan - from above');
  if LeftWall then
  begin
    if FSpec.RefW0Right then Y0 := Yb0 else Y0 := Ya0;
    if FSpec.RefW1Right then Y1 := Yb1 else Y1 := Ya1;
  end
  else
  begin
    if FSpec.RefW0Right then Y0 := Ya0 else Y0 := Yb0;
    if FSpec.RefW1Right then Y1 := Ya1 else Y1 := Yb1;
  end;
  TapeLine(C, TX0, RefY, Y0);
  TapeLine(C, TX1, RefY, Y1);
  C.Pen.Color := TAPE;
  C.Line(TX0, (RefY + Y0) div 2, 190, 164);
  C.Line(TX1, (RefY + Y1) div 2, 572, 164);
  { the one with the tape, seen from above: a head and shoulders }
  C.Pen.Color := INKG;
  C.Pen.Width := 2;
  C.Brush.Style := bsClear;
  C.Ellipse(100, (RefY + Y0) div 2 - 10, 120, (RefY + Y0) div 2 + 10);
  C.Arc(88, (RefY + Y0) div 2 - 22, 132, (RefY + Y0) div 2 + 22, 132, (RefY + Y0) div 2, 88, (RefY + Y0) div 2);
  C.Line(120, (RefY + Y0) div 2, TX0 - 8, (RefY + Y0) div 2);
  C.Pen.Width := 1;
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
