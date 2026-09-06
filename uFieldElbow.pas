unit uFieldElbow;

{ An elbow from what can be measured on the job.

  Standing at the open end of the duct that is there, the fitter can
  measure to the duct it has to meet: straight ahead and across to its
  near inside corner, and either the angle it runs at or a second point
  along its inside edge.  With the throat radius chosen, that is enough
  to say the angle and the two straight legs, and the elbow lands where it
  has to.  This form takes the measurements, shows what it worked out with
  a sketch, and hands the angle and the legs back to the fitting wizard. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, StdCtrls, ExtCtrls, Graphics,
  uWork, uFittings;

type
  TFieldElbowForm = class(TForm)
    btnCancel: TButton;
    btnOK: TButton;
    edAngle: TEdit;
    edFwd: TEdit;
    edFwd2: TEdit;
    edOver: TEdit;
    edOver2: TEdit;
    lblAngle: TLabel;
    lblDeg: TLabel;
    lblFwd: TLabel;
    lblFwd2: TLabel;
    lblIntro: TLabel;
    lblNear: TLabel;
    lblOver: TLabel;
    lblOver2: TLabel;
    lblResult: TLabel;
    lblTitle: TLabel;
    pbSketch: TPaintBox;
    rgHow: TRadioGroup;
    procedure AnyChange(Sender: TObject);
    procedure pbSketchPaint(Sender: TObject);
  private
    FSpec: TTransitionSpec;    { the elbow so far: opening, throat, turn }
    FUnits: TUnitSystem;
    function InchesOf(const S: string; out V: Double): Boolean;
    { the measurements read and solved into FSpec; '' or what is wrong }
    function Solve: string;
  public
    { Spec comes in with the opening, the throat radius and the turn, and
      goes out with the angle and the legs.  True when OK was pressed with
      a solution. }
    class function Ask(Units: TUnitSystem; var Spec: TTransitionSpec): Boolean;
  end;

implementation

{$R *.lfm}

function TFieldElbowForm.InchesOf(const S: string; out V: Double): Boolean;
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

function TFieldElbowForm.Solve: string;
var
  Fwd, Over, Fwd2, Over2, Deg, Theta, L0, L1: Double;
begin
  if not (InchesOf(edFwd.Text, Fwd) and InchesOf(edOver.Text, Over)) then
    Exit('The near corner needs both numbers.');
  if rgHow.ItemIndex = 0 then
  begin
    if not TryStrToFloat(Trim(edAngle.Text), Deg) then Exit('The angle did not read.');
    Theta := DegToRad(Deg);
  end
  else
  begin
    if not (InchesOf(edFwd2.Text, Fwd2) and InchesOf(edOver2.Text, Over2)) then
      Exit('The second point needs both numbers.');
    if (Abs(Fwd2 - Fwd) < 1E-9) and (Abs(Over2 - Over) < 1E-9) then
      Exit('The second point has to be somewhere else along the edge.');
    Theta := FieldDirection(Fwd, Over, Fwd2, Over2);
  end;
  Result := SolveFieldElbow(FSpec.Throat, Fwd, Over, Theta, L0, L1);
  if Result <> '' then Exit;
  FSpec.Angle := Theta;
  FSpec.Leg0 := L0;
  FSpec.Leg1 := L1;
end;

procedure TFieldElbowForm.AnyChange(Sender: TObject);
var
  Err: string;
begin
  edAngle.Enabled := rgHow.ItemIndex = 0;
  edFwd2.Enabled := rgHow.ItemIndex = 1;
  edOver2.Enabled := rgHow.ItemIndex = 1;
  Err := Solve;
  if Err = '' then
  begin
    lblResult.Font.Color := clBlack;
    lblResult.Caption := Format('%s degrees.  Entry leg %s, exit leg %s.',
      [FormatFloat('0.#', RadToDeg(FSpec.Angle)), FormatLen(FSpec.Leg0, FUnits),
       FormatLen(FSpec.Leg1, FUnits)]);
  end
  else
  begin
    lblResult.Font.Color := clRed;
    lblResult.Caption := Err;
  end;
  btnOK.Enabled := Err = '';
  pbSketch.Invalidate;
end;

{ The plan: the elbow as worked out, the reference corner marked, the far
  duct's inside edge drawn through where it was measured. }
procedure TFieldElbowForm.pbSketchPaint(Sender: TObject);
var
  C: TCanvas;
  Pts: TP3Array;
  P: array of TPoint;
  I, W, H, Margin: Integer;
  MinX, MaxX, MinY, MaxY, Sc, A, Fwd, Over: Double;
  Dir: TP3;
  function SX(X: Double): Integer; begin Result := Round(Margin + (X - MinX) * Sc); end;
  function SY(Y: Double): Integer; begin Result := Round(H - Margin - (Y - MinY) * Sc); end;
begin
  C := pbSketch.Canvas;
  W := pbSketch.Width; H := pbSketch.Height;
  C.Brush.Color := clWhite;
  C.FillRect(0, 0, W, H);
  C.Pen.Color := clSilver;
  C.Rectangle(0, 0, W, H);
  if Solve <> '' then Exit;
  ElbowCheek(FSpec, Pts);
  if Length(Pts) < 3 then Exit;
  Margin := 40;
  MinX := 1E30; MaxX := -1E30; MinY := 1E30; MaxY := -1E30;
  for I := 0 to High(Pts) do
  begin
    MinX := Min(MinX, Pts[I].X); MaxX := Max(MaxX, Pts[I].X);
    MinY := Min(MinY, Pts[I].Y); MaxY := Max(MaxY, Pts[I].Y);
  end;
  Sc := Min((W - 2 * Margin) / Max(MaxX - MinX, 1E-9), (H - 2 * Margin) / Max(MaxY - MinY, 1E-9));
  SetLength(P, Length(Pts));
  for I := 0 to High(Pts) do P[I] := Point(SX(Pts[I].X), SY(Pts[I].Y));
  C.Pen.Color := clBlack;
  C.Pen.Width := 2;
  C.Brush.Style := bsClear;
  C.Polygon(P);
  C.Pen.Width := 1;
  { the far duct's inside edge, on through where the elbow lands }
  if FSpec.Turn in [tuUp, tuDown] then A := FSpec.H0 else A := FSpec.W0;
  InchesOf(edFwd.Text, Fwd); InchesOf(edOver.Text, Over);
  Dir := P3(Sin(FSpec.Angle), Cos(FSpec.Angle), 0);
  C.Pen.Color := $00A06030;
  C.Pen.Style := psDash;
  C.Line(SX(A + Over), SY(Fwd), SX(A + Over + Dir.X * A * 1.5), SY(Fwd + Dir.Y * A * 1.5));
  C.Pen.Style := psSolid;
  { the reference corner and the measured corner }
  C.Brush.Color := $00A06030;
  C.Brush.Style := bsSolid;
  C.Ellipse(SX(A) - 4, SY(0) - 4, SX(A) + 4, SY(0) + 4);
  C.Ellipse(SX(A + Over) - 4, SY(Fwd) - 4, SX(A + Over) + 4, SY(Fwd) + 4);
  C.Brush.Style := bsClear;
  C.Font.Color := $00A06030;
  C.TextOut(SX(A) + 6, SY(0) - 16, 'from here');
  C.TextOut(SX(A + Over) - C.TextWidth('to here') - 6, SY(Fwd) - 16, 'to here');
  C.Font.Color := clGray;
  C.TextOut(8, H - 20, 'seen from above, turning ' + LowerCase(TURN_NAMES[FSpec.Turn]));
end;

class function TFieldElbowForm.Ask(Units: TUnitSystem; var Spec: TTransitionSpec): Boolean;
var
  F: TFieldElbowForm;
begin
  Result := False;
  F := TFieldElbowForm.Create(nil);
  try
    F.FUnits := Units;
    F.FSpec := Spec;
    F.AnyChange(nil);
    if F.ShowModal <> mrOK then Exit;
    if F.Solve <> '' then Exit;
    Spec := F.FSpec;
    Result := True;
  finally
    F.Free;
  end;
end;

end.
