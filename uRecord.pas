unit uRecord;

{ Recording a camera move by making it.

  Setting a start and an end covers a spin and a push-in, but it cannot cover
  "go round this way, pause on the front, then drop down onto the roof" - and
  that is the shot somebody actually wants when they are showing their
  drawing to a friend.  So: a window with nothing in it but the model, a
  countdown to get your hand ready, and then it simply watches where you
  point the camera until you press Escape.

  What is recorded is where the camera was, not what was on the screen.  That
  matters twice over.  The film is rendered afterwards, so it comes out at
  whatever size is asked for rather than the size of this window; and none of
  the cursor, the snapping lines, the hover marks or anything else that was
  on the glass at the time goes anywhere near it.  The axes stay, because
  they are the one piece of furniture that says which way up the thing is.

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Types, Graphics, Controls, Forms, ExtCtrls,
  LCLType, BCPanel, BCLabel, BCButton,
  uSurface, uWork, uSkin, uDlgSkin, uShoot;

{ Open the recording window.  True if a move was recorded and kept. }
function RecordMove(Doc: TWorkDoc; const Start: TProjector; U: TUnitSystem;
  AFont: TFont; const LabelCol: TPix; EdgeW: Single; SrcW, SrcH: Integer;
  Axes: Boolean; out Cam: TCamPath): Boolean;

implementation

const
  { how often the camera is written down.  Faster than any GIF will be, so
    the film is sampled from a path rather than the other way round and the
    frame rate can be chosen afterwards. }
  SAMPLE_HZ = 30;
  READY_FOR = 3;          { seconds of counting down }

type
  TRecordWin = class(TForm)
  private
    FDoc: TWorkDoc;
    FUnits: TUnitSystem;
    FFont: TFont;
    FLabelCol: TPix;
    FEdgeW: Single;
    FSrcW, FSrcH: Integer;
    FAxes: Boolean;
    FView: TProjector;
    FCam: TCamPath;
    FN: Integer;
    FKept: Boolean;
    FRolling: Boolean;
    FCount: Double;         { seconds left of the countdown }
    FElapsed: Double;
    FTick: TTimer;
    FBox: TPaintBox;
    FTitle, FTell: TBCLabel;
    FStop: TBCButton;
    FDrag, FPan: Boolean;
    FDX, FDY: Integer;
    procedure Build;
    procedure Paint(Sender: TObject);
    procedure Tick(Sender: TObject);
    procedure Down(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure Move_(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure Up(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure Wheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint; var Handled: Boolean);
    procedure KeyDownH(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure StopIt(Sender: TObject);
    procedure Grab;
  end;

procedure TRecordWin.Build;
begin
  Caption := 'Recording';
  BorderStyle := bsNone;
  Position := poScreenCenter;
  ClientWidth := 960;
  ClientHeight := 660;
  KeyPreview := True;
  OnKeyDown := @KeyDownH;
  uDlgSkin.SkinForm(Self);

  FTitle := TBCLabel.Create(Self);
  FTitle.Parent := Self;
  FTitle.SetBounds(18, 14, 500, 24);
  FTitle.Caption := 'Point the camera where you want it';
  uDlgSkin.SkinLabel(FTitle, False, -18, True);

  FTell := TBCLabel.Create(Self);
  FTell.Parent := Self;
  FTell.SetBounds(18, 40, 700, 20);
  FTell.Caption := 'Middle-drag turns it, right-drag slides it, wheel zooms' +
    ' - the same as the drawing.  Escape when you are done.';
  uDlgSkin.SkinLabel(FTell, True, -13);

  FStop := TBCButton.Create(Self);
  FStop.Parent := Self;
  FStop.SetBounds(830, 16, 112, 32);
  FStop.Caption := 'Done';
  FStop.OnClick := @StopIt;
  uDlgSkin.SkinButton(FStop, bkGo);

  FBox := TPaintBox.Create(Self);
  FBox.Parent := Self;
  FBox.SetBounds(14, 70, 932, 576);
  FBox.OnPaint := @Paint;
  FBox.OnMouseDown := @Down;
  FBox.OnMouseMove := @Move_;
  FBox.OnMouseUp := @Up;
  FBox.OnMouseWheel := @Wheel;

  FTick := TTimer.Create(Self);
  FTick.Interval := Round(1000 / SAMPLE_HZ);
  FTick.OnTimer := @Tick;
  FTick.Enabled := True;
  FCount := READY_FOR;
end;

procedure TRecordWin.Grab;
begin
  if FN >= Length(FCam) then SetLength(FCam, Max(64, FN * 2));
  FCam[FN].T := FElapsed;
  FCam[FN].V := FView;
  Inc(FN);
end;

procedure TRecordWin.Tick(Sender: TObject);
var
  Left_: Double;
begin
  if FCount > 0 then
  begin
    Left_ := FCount - 1 / SAMPLE_HZ;      { a local first - see OrbitBy }
    FCount := Left_;
    if FCount <= 0 then
    begin
      FRolling := True;
      FElapsed := 0;
      FTitle.Caption := 'Recording';
      FTell.Caption := 'Middle-drag turns it, right-drag slides it, wheel ' +
        'zooms.  Escape when you are done.';
      Grab;
    end;
    FBox.Invalidate;
    Exit;
  end;

  if not FRolling then Exit;
  Left_ := FElapsed + 1 / SAMPLE_HZ;      { a local first - see OrbitBy }
  FElapsed := Left_;
  Grab;
  { it stops itself rather than letting somebody record four minutes and then
    find out a GIF will not hold it }
  if FElapsed >= GIF_MAX_SECONDS then StopIt(nil);
  FBox.Invalidate;
end;

procedure TRecordWin.Paint(Sender: TObject);
var
  S: TArtSurface;
  V: TProjector;
  C: TCanvas;
  Txt: string;
  TW: Integer;
begin
  V := Fitted(FView, FSrcW, FSrcH, FBox.Width, FBox.Height);
  S := ShootFrame(FDoc, V, FBox.Width, FBox.Height, FUnits, FFont, FLabelCol,
    FEdgeW, Pix(255, 255, 255), FDrag or FPan);
  try
    if FAxes then PaintAxesOn(S, V);
    FBox.Canvas.Draw(0, 0, S.AsBitmap);
  finally
    S.Free;
  end;

  C := FBox.Canvas;
  C.Brush.Style := bsClear;
  if FCount > 0 then
  begin
    { the countdown, big in the middle, so it is read without looking for it }
    C.Font.Height := -150;
    C.Font.Color := clRed;
    Txt := IntToStr(Max(1, Ceil(FCount)));
    TW := C.TextWidth(Txt);
    C.TextOut((FBox.Width - TW) div 2, (FBox.Height - 170) div 2, Txt);
    C.Font.Height := -22;
    C.Font.Color := clBlack;
    Txt := 'get ready';
    C.TextOut((FBox.Width - C.TextWidth(Txt)) div 2,
      (FBox.Height + 40) div 2, Txt);
  end
  else if FRolling then
  begin
    C.Brush.Style := bsSolid;
    C.Brush.Color := clRed;
    C.Pen.Color := clRed;
    C.Ellipse(16, 16, 34, 34);
    C.Brush.Style := bsClear;
    C.Font.Height := -20;
    C.Font.Color := clRed;
    C.TextOut(44, 16, Format('REC   %.1fs  of  %ds', [FElapsed,
      GIF_MAX_SECONDS]));
  end;
end;

procedure TRecordWin.Down(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  { the same buttons as the drawing area: middle turns, right slides, and
    the left button does nothing, because there is nothing here to pick }
  FDrag := Button in [mbMiddle, mbRight];
  FPan := Button = mbRight;
  FDX := X;
  FDY := Y;
end;

procedure TRecordWin.Move_(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  K: Double;
begin
  if not FDrag then Exit;
  K := ViewScale(FSrcW, FSrcH, FBox.Width, FBox.Height);
  { Shift is tested every move, not only when the button went down, so it can
    be grabbed part way through a turn - the same as the drawing area }
  if FPan or (ssShift in Shift) then
    PanBy(FView, (X - FDX) / K, (Y - FDY) / K)
  else
    OrbitBy(FView, X - FDX, Y - FDY);
  FDX := X;
  FDY := Y;
  FBox.Invalidate;
end;

procedure TRecordWin.Up(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FDrag := False;
  FPan := False;
  FBox.Invalidate;
end;

procedure TRecordWin.Wheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
var
  P: TPoint;
  K, AX, AY: Double;
begin
  { 1.15 and anchored on the cursor, the same as the drawing area }
  P := FBox.ScreenToClient(MousePos);
  K := ViewScale(FSrcW, FSrcH, FBox.Width, FBox.Height);
  AX := FSrcW / 2 + (P.X - FBox.Width / 2) / K;
  AY := FSrcH / 2 + (P.Y - FBox.Height / 2) / K;
  if WheelDelta > 0 then ZoomAt(FView, 1.15, AX, AY)
  else ZoomAt(FView, 1 / 1.15, AX, AY);
  FBox.Invalidate;
  Handled := True;
end;

procedure TRecordWin.KeyDownH(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    Key := 0;
    StopIt(nil);
  end;
end;

procedure TRecordWin.StopIt(Sender: TObject);
begin
  FTick.Enabled := False;
  { a recording that never started, or one over in a blink, is somebody
    changing their mind rather than a shot }
  FKept := FRolling and (FElapsed >= 0.4) and (FN >= 2);
  SetLength(FCam, FN);
  if FKept then ModalResult := mrOk else ModalResult := mrCancel;
end;

function RecordMove(Doc: TWorkDoc; const Start: TProjector; U: TUnitSystem;
  AFont: TFont; const LabelCol: TPix; EdgeW: Single; SrcW, SrcH: Integer;
  Axes: Boolean; out Cam: TCamPath): Boolean;
var
  W: TRecordWin;
begin
  Cam := nil;
  W := TRecordWin.CreateNew(nil);
  try
    W.FDoc := Doc;
    W.FUnits := U;
    W.FFont := AFont;
    W.FLabelCol := LabelCol;
    W.FEdgeW := EdgeW;
    W.FSrcW := SrcW;
    W.FSrcH := SrcH;
    W.FAxes := Axes;
    W.FView := Start;
    W.Build;
    W.ShowModal;
    Result := W.FKept;
    if Result then Cam := W.FCam;
  finally
    W.Free;
  end;
end;

end.
