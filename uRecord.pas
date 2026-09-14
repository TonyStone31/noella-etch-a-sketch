unit uRecord;

{ Making the little film.

  One room for it, which is the whole point of this being rewritten: setting a
  start and an end used to live in the export dialog while the recording lived
  here, so there were two ways to do one thing and the dialog gave no sign
  which of them you had used.  Everything is here now, and the export dialog
  either has a clip or it does not.

  What comes out is where the camera was, moment by moment - not pictures.
  The film is rendered afterwards, so it can be any size, and none of the
  cursor, the snapping lines or the hover marks go anywhere near it.

  Two ways to make the move.  Point the camera yourself and it writes down
  what you did; or pick one of the canned walks, which are the shots somebody
  would choose if they were showing you the thing - see TWalk in uShoot.
  Either way it turns about the middle of what you had selected, because that
  is what you were looking at when you pressed Export.

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Types, Graphics, Controls, Forms, ExtCtrls,
  StdCtrls, LCLType, BCPanel, BCLabel, BCButton,
  uSurface, uWork, uSkin, uDlgSkin, uShoot;

{ The moves somebody has actually used, most recent first, as a comma list of
  ordinals.  The caller keeps it between sessions - see LoadSettings - because
  a list of eight where three get used is a list that should reorder itself. }
var
  RecentWalks: string = '';

{ Open the recording room.  True if a clip was made and kept. }
function RecordMove(Doc: TWorkDoc; const Start: TProjector; U: TUnitSystem;
  AFont: TFont; const LabelCol: TPix; EdgeW: Single; SrcW, SrcH: Integer;
  Axes: Boolean; const Pivot: TP3; out Cam: TCamPath): Boolean;

implementation

const
  SAMPLE_HZ = 30;         { how often the camera is written down }
  READY_FOR = 3;          { seconds of counting you in }
  STRIP_N   = 16;         { snapshots along the bottom }
  STRIP_W   = 96;
  STRIP_H   = 72;

type
  { where the camera starts, before any move }
  TStartView = (svHere, svFront, svBack, svLeft, svRight, svTop,
                svIsoFL, svIsoFR, svIsoBL, svIsoBR);

const
  START_NAME: array[TStartView] of string =
    ('Where I am now', 'Front', 'Back', 'Left', 'Right', 'Top',
     'Corner - front left', 'Corner - front right',
     'Corner - back left', 'Corner - back right');
  { azimuth and elevation for each, in radians }
  START_AZ: array[TStartView] of Double =
    (0, 0, Pi, -Pi/2, Pi/2, 0, -Pi/4, Pi/4, -3*Pi/4, 3*Pi/4);
  START_EL: array[TStartView] of Double =
    (0, 0.08, 0.08, 0.08, 0.08, 1.45, 0.62, 0.62, 0.62, 0.62);

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
    FPivot: TP3;
    FHome: TProjector;        { what the drawing was showing when we opened }

    FView: TProjector;
    FCam: TCamPath;
    FN: Integer;
    FKept: Boolean;

    { rolling }
    FRolling: Boolean;
    FCount: Double;
    FElapsed: Double;
    FPlaying: Boolean;
    FPlayT: Double;

    { the strip along the bottom }
    FStrip: array[0..STRIP_N - 1] of TBitmap;
    FStripN: Integer;
    { what each row of the walk list means: -1 free hand, -2 the divider,
      otherwise the ordinal of a TWalk }
    FWalkOf: array of Integer;

    FDrag, FPan: Boolean;
    FDX, FDY: Integer;

    FTick: TTimer;
    FBox, FFilm: TPaintBox;
    FTitle, FTell, FClip: TBCLabel;
    FStart, FWalkBox, FLen: TComboBox;
    FGo, FStop, FPlay, FClear, FTake, FDrop: TBCButton;

    procedure Build;
    procedure PaintView(Sender: TObject);
    procedure PaintFilm(Sender: TObject);
    procedure Tick(Sender: TObject);
    procedure Down(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure Move_(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure Up(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure Wheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint; var Handled: Boolean);
    procedure KeyDownH(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure StartPicked(Sender: TObject);
    procedure DoGo(Sender: TObject);
    procedure DoStop(Sender: TObject);
    procedure DoPlay(Sender: TObject);
    procedure DoClear(Sender: TObject);
    procedure DoTake(Sender: TObject);
    procedure DoDrop(Sender: TObject);
    procedure ComboDraw(Control: TWinControl; Index: Integer; ARect: TRect;
      State: TOwnerDrawState);
    procedure FillWalks;
    function ChosenWalk(out K: TWalk): Boolean;
    procedure Remember(K: TWalk);
    procedure Grab;
    procedure Shelve;
    procedure Refresh_;
    function Seconds: Double;
    function FreeHand: Boolean;
    function Frame(W, H: Integer): TProjector;
  public
    destructor Destroy; override;
  end;

destructor TRecordWin.Destroy;
var
  I: Integer;
begin
  for I := 0 to STRIP_N - 1 do FStrip[I].Free;
  inherited Destroy;
end;

function TRecordWin.Seconds: Double;
begin
  case FLen.ItemIndex of
    0: Result := 3;
    1: Result := 5;
    2: Result := 8;
  else Result := 12;
  end;
end;

function TRecordWin.FreeHand: Boolean;
var
  K: TWalk;
begin
  Result := not ChosenWalk(K);
end;

{ The view for a picture W by H, which is what both the window and the film
  are: the stored view is kept in the drawing's terms and fitted on the way
  out, so there is one camera and not two. }
function TRecordWin.Frame(W, H: Integer): TProjector;
begin
  Result := Fitted(FView, FSrcW, FSrcH, W, H);
end;

procedure TRecordWin.Build;

  function MkLbl(P: TWinControl; const C: string; L, T, W: Integer;
    Dim: Boolean = False; Bold: Boolean = False; FH: Integer = 0): TBCLabel;
  begin
    Result := TBCLabel.Create(Self);
    Result.Parent := P;
    Result.SetBounds(L, T, W, 20);
    Result.Caption := C;
    uDlgSkin.SkinLabel(Result, Dim, FH, Bold);
  end;

  function MkBtn(P: TWinControl; const C: string; L, T, W, H: Integer;
    K: TBtnKind): TBCButton;
  begin
    Result := TBCButton.Create(Self);
    Result.Parent := P;
    Result.SetBounds(L, T, W, H);
    Result.Caption := C;
    uDlgSkin.SkinButton(Result, K);
  end;

  function MkCombo(P: TWinControl; L, T, W: Integer): TComboBox;
  begin
    Result := TComboBox.Create(Self);
    Result.Parent := P;
    Result.SetBounds(L, T, W, 26);
    Result.Style := csOwnerDrawFixed;
    Result.ItemHeight := 22;
    Result.OnDrawItem := @ComboDraw;
    Result.Color := uSurface.PixToColor(uDlgSkin.DlgTheme.Shell2);
    Result.Font.Color := uSurface.PixToColor(uDlgSkin.DlgTheme.Text);
  end;

var
  K: TWalk;
  V: TStartView;
  Bar, Foot: TBCPanel;
begin
  Caption := 'Record a move';
  BorderStyle := bsNone;
  Position := poScreenCenter;
  ClientWidth := 1000;
  ClientHeight := 760;
  KeyPreview := True;
  OnKeyDown := @KeyDownH;
  uDlgSkin.SkinForm(Self);

  { --- what the move is, along the top ------------------------------- }
  Bar := TBCPanel.Create(Self);
  Bar.Parent := Self;
  Bar.SetBounds(12, 12, 976, 96);
  uDlgSkin.SkinPanel(Bar, True, 12);

  FTitle := MkLbl(Bar, 'Record a move', 16, 8, 300, False, True, -19);

  MkLbl(Bar, 'Start from', 16, 38, 120, True, False, -12);
  FStart := MkCombo(Bar, 16, 58, 200);
  for V := Low(TStartView) to High(TStartView) do
    FStart.Items.Add(START_NAME[V]);
  FStart.ItemIndex := 0;
  FStart.OnChange := @StartPicked;

  MkLbl(Bar, 'The move', 232, 38, 200, True, False, -12);
  FWalkBox := MkCombo(Bar, 232, 58, 300);
  FillWalks;
  FWalkBox.OnChange := @StartPicked;

  MkLbl(Bar, 'How long', 548, 38, 120, True, False, -12);
  FLen := MkCombo(Bar, 548, 58, 120);
  FLen.Items.Add('3 seconds');
  FLen.Items.Add('5 seconds');
  FLen.Items.Add('8 seconds');
  FLen.Items.Add('12 seconds');
  FLen.ItemIndex := 1;
  FLen.OnChange := @StartPicked;

  FGo := MkBtn(Bar, 'Record', 692, 54, 130, 34, bkGo);
  FGo.OnClick := @DoGo;
  FStop := MkBtn(Bar, 'Stop', 692, 54, 130, 34, bkPlain);
  FStop.OnClick := @DoStop;
  FStop.Visible := False;

  FTell := MkLbl(Bar, '', 836, 62, 130, True, False, -12);

  { --- the model ------------------------------------------------------ }
  FBox := TPaintBox.Create(Self);
  FBox.Parent := Self;
  FBox.SetBounds(12, 118, 976, 500);
  FBox.OnPaint := @PaintView;
  FBox.OnMouseDown := @Down;
  FBox.OnMouseMove := @Move_;
  FBox.OnMouseUp := @Up;
  FBox.OnMouseWheel := @Wheel;

  { --- the clip, along the bottom ------------------------------------- }
  Foot := TBCPanel.Create(Self);
  Foot.Parent := Self;
  Foot.SetBounds(12, 628, 976, 120);
  uDlgSkin.SkinPanel(Foot, False, 12);

  FFilm := TPaintBox.Create(Self);
  FFilm.Parent := Foot;
  FFilm.SetBounds(12, 10, 660, STRIP_H + 4);
  FFilm.OnPaint := @PaintFilm;

  FClip := MkLbl(Foot, 'No clip yet.', 12, 90, 660, True, False, -12);

  FPlay := MkBtn(Foot, 'Play', 686, 12, 88, 32, bkPlain);
  FPlay.OnClick := @DoPlay;
  FClear := MkBtn(Foot, 'Clear', 782, 12, 88, 32, bkPlain);
  FClear.OnClick := @DoClear;
  FTake := MkBtn(Foot, 'Use this clip', 686, 52, 184, 32, bkGo);
  FTake.OnClick := @DoTake;
  FDrop := MkBtn(Foot, 'Close', 878, 52, 86, 32, bkPlain);
  FDrop.OnClick := @DoDrop;

  FTick := TTimer.Create(Self);
  FTick.Interval := Round(1000 / SAMPLE_HZ);
  FTick.OnTimer := @Tick;
  FTick.Enabled := True;
  StartPicked(nil);
end;

procedure TRecordWin.ComboDraw(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
var
  C: TComboBox;
  Cv: TCanvas;
begin
  C := Control as TComboBox;
  Cv := C.Canvas;
  if odSelected in State then
    Cv.Brush.Color := uSurface.PixToColor(uDlgSkin.DlgTheme.Accent)
  else
    Cv.Brush.Color := uSurface.PixToColor(uDlgSkin.DlgTheme.Shell2);
  Cv.FillRect(ARect);
  if odSelected in State then
    Cv.Font.Color := uSurface.PixToColor(uDlgSkin.DlgTheme.Shell2)
  else
    Cv.Font.Color := uSurface.PixToColor(uDlgSkin.DlgTheme.Text);
  Cv.Brush.Style := bsClear;
  if (Index >= 0) and (Index < C.Items.Count) then
    Cv.TextOut(ARect.Left + 6, ARect.Top + 3, C.Items[Index]);
end;

{ The list of moves, with the ones actually used at the top.

  Eight is a comfortable number to offer and an uncomfortable number to read
  every time, and people settle on two or three.  So the recent ones go first,
  then a line, then the whole lot in their own order - which means the list is
  short for somebody who knows what they want and complete for somebody who
  does not. }
procedure TRecordWin.FillWalks;
var
  K: TWalk;
  L: TStringList;
  I, N: Integer;

  procedure Row(const Cap: string; Means: Integer);
  begin
    FWalkBox.Items.Add(Cap);
    SetLength(FWalkOf, Length(FWalkOf) + 1);
    FWalkOf[High(FWalkOf)] := Means;
  end;

begin
  FWalkBox.Items.Clear;
  SetLength(FWalkOf, 0);
  Row('I will point it myself', -1);

  L := TStringList.Create;
  try
    L.CommaText := RecentWalks;
    N := 0;
    for I := 0 to L.Count - 1 do
    begin
      if N >= 3 then Break;
      if (StrToIntDef(L[I], -1) < 0) or
         (StrToIntDef(L[I], -1) > Ord(High(TWalk))) then Continue;
      Row(WALK_NAME[TWalk(StrToInt(L[I]))], StrToInt(L[I]));
      Inc(N);
    end;
    if N > 0 then Row('- - - - - - - - - - - - -', -2);
  finally
    L.Free;
  end;

  for K := Low(TWalk) to High(TWalk) do Row(WALK_NAME[K], Ord(K));
  { the first real move, which is the most recent one where there is one }
  if Length(FWalkOf) > 1 then FWalkBox.ItemIndex := 1
  else FWalkBox.ItemIndex := 0;
end;

function TRecordWin.ChosenWalk(out K: TWalk): Boolean;
var
  I, M: Integer;
begin
  Result := False;
  I := FWalkBox.ItemIndex;
  if (I < 0) or (I > High(FWalkOf)) then Exit;
  M := FWalkOf[I];
  if M < 0 then Exit;
  K := TWalk(M);
  Result := True;
end;

{ Put this one at the front of the recent list, keeping the rest in order and
  dropping any repeat of it. }
procedure TRecordWin.Remember(K: TWalk);
var
  L, Out_: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  Out_ := TStringList.Create;
  try
    Out_.Add(IntToStr(Ord(K)));
    L.CommaText := RecentWalks;
    for I := 0 to L.Count - 1 do
      if (StrToIntDef(L[I], -1) <> Ord(K)) and (Out_.Count < 6) and
         (StrToIntDef(L[I], -1) >= 0) and
         (StrToIntDef(L[I], -1) <= Ord(High(TWalk))) then
        Out_.Add(L[I]);
    RecentWalks := Out_.CommaText;
  finally
    Out_.Free;
    L.Free;
  end;
end;

{ Put the camera where the start view says, aimed at the middle of what was
  selected and pulled back far enough to hold it. }
procedure TRecordWin.StartPicked(Sender: TObject);
var
  V: TStartView;
begin
  { the line between the recent ones and the rest is not a move }
  if (Sender = FWalkBox) and (FWalkBox.ItemIndex >= 0) and
     (FWalkBox.ItemIndex <= High(FWalkOf)) and
     (FWalkOf[FWalkBox.ItemIndex] = -2) then
  begin
    FWalkBox.ItemIndex := FWalkBox.ItemIndex + 1;
    if FWalkBox.ItemIndex > High(FWalkOf) then FWalkBox.ItemIndex := 0;
  end;
  V := TStartView(Max(0, Min(Ord(High(TStartView)), FStart.ItemIndex)));
  if V = svHere then
    FView := FHome
  else
  begin
    FView := FHome;
    FView.Kind := vkOrbit;
    FView.Az := START_AZ[V];
    FView.El := START_EL[V];
  end;
  { whatever the angle, the thing being looked at sits in the middle }
  HoldAt(FView, FPivot, FSrcW / 2, FSrcH / 2);
  Refresh_;
end;

procedure TRecordWin.Refresh_;
begin
  if FreeHand then
    FTell.Caption := 'Point it yourself'
  else
    FTell.Caption := Format('%.0f seconds', [Seconds]);
  if FN >= 2 then
    FClip.Caption := Format('A clip of %.1f seconds.  Play it, or use it.',
      [CamPathLength(FCam)])
  else if FRolling then
    FClip.Caption := 'Recording...'
  else
    FClip.Caption := 'No clip yet.  Pick a move and press Record.';
  FPlay.Visible := FN >= 2;
  FClear.Visible := FN >= 2;
  FTake.Visible := FN >= 2;
  FBox.Invalidate;
  FFilm.Invalidate;
end;

procedure TRecordWin.Grab;
begin
  if FN >= Length(FCam) then SetLength(FCam, Max(64, FN * 2));
  FCam[FN].T := FElapsed;
  FCam[FN].V := FView;
  Inc(FN);
end;

{ A snapshot for the strip, so the clip is visibly filling up rather than
  being taken on trust. }
procedure TRecordWin.Shelve;
var
  S: TArtSurface;
  Slot: Integer;
begin
  Slot := Min(STRIP_N - 1, Trunc(FElapsed / Max(0.001, Seconds) * STRIP_N));
  if Slot < FStripN then Exit;
  S := ShootFrame(FDoc, Fitted(FView, FSrcW, FSrcH, STRIP_W, STRIP_H),
    STRIP_W, STRIP_H, FUnits, FFont, FLabelCol, FEdgeW, Pix(255, 255, 255),
    True);
  try
    if FStrip[Slot] = nil then FStrip[Slot] := TBitmap.Create;
    FStrip[Slot].Assign(S.AsBitmap);
  finally
    S.Free;
  end;
  FStripN := Slot + 1;
  FFilm.Invalidate;
end;

procedure TRecordWin.Tick(Sender: TObject);
var
  Step: Double;
  Kind: TWalk;
begin
  if FPlaying then
  begin
    Step := FPlayT + (1 / SAMPLE_HZ) / Max(0.2, CamPathLength(FCam));
    FPlayT := Step;
    if FPlayT > 1 then FPlayT := 0;
    FBox.Invalidate;
    Exit;
  end;

  if FCount > 0 then
  begin
    Step := FCount - 1 / SAMPLE_HZ;
    FCount := Step;
    if FCount <= 0 then
    begin
      FRolling := True;
      FElapsed := 0;
      FTitle.Caption := 'Recording';
      Grab;
      Shelve;
      Refresh_;
    end;
    FBox.Invalidate;
    Exit;
  end;

  if not FRolling then Exit;
  Step := FElapsed + 1 / SAMPLE_HZ;
  FElapsed := Step;
  { a canned walk drives the camera; a free hand has already moved it }
  if ChosenWalk(Kind) then
    FView := WalkAt(Kind, FHome, FPivot, FSrcW / 2, FSrcH / 2,
      FElapsed / Max(0.2, Seconds));
  Grab;
  Shelve;
  if FElapsed >= Min(Seconds, GIF_MAX_SECONDS) then
  begin
    DoStop(nil);
    Exit;
  end;
  FBox.Invalidate;
end;

procedure TRecordWin.PaintView(Sender: TObject);
var
  S: TArtSurface;
  V: TProjector;
  C: TCanvas;
  Txt: string;
begin
  if FPlaying and (FN >= 2) then
    V := Fitted(SampleCamPath(FCam, FPlayT * CamPathLength(FCam)),
      FSrcW, FSrcH, FBox.Width, FBox.Height)
  else
    V := Frame(FBox.Width, FBox.Height);
  S := ShootFrame(FDoc, V, FBox.Width, FBox.Height, FUnits, FFont, FLabelCol,
    FEdgeW, Pix(255, 255, 255), FDrag or FPan or FRolling or FPlaying);
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
    C.Font.Height := -150;
    C.Font.Color := clRed;
    Txt := IntToStr(Max(1, Ceil(FCount)));
    C.TextOut((FBox.Width - C.TextWidth(Txt)) div 2,
      (FBox.Height - 170) div 2, Txt);
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
    C.TextOut(44, 16, Format('REC   %.1f of %.0f seconds',
      [FElapsed, Seconds]));
  end;
end;

{ The strip.  Deliberately not an editor: there is nothing to drag and no
  handles to trim with, because the only two things worth doing to a clip
  this short are keeping it and doing it again. }
procedure TRecordWin.PaintFilm(Sender: TObject);
var
  I, X: Integer;
  C: TCanvas;
begin
  C := FFilm.Canvas;
  C.Brush.Style := bsSolid;
  C.Brush.Color := uSurface.PixToColor(uDlgSkin.DlgTheme.Shell2);
  C.FillRect(0, 0, FFilm.Width, FFilm.Height);
  for I := 0 to STRIP_N - 1 do
  begin
    X := 2 + I * (STRIP_W div 2 + 2);
    if X + STRIP_W div 2 > FFilm.Width then Break;
    if (FStrip[I] <> nil) and (I < FStripN) then
      C.StretchDraw(Rect(X, 2, X + STRIP_W div 2, 2 + STRIP_H div 2),
        FStrip[I])
    else
    begin
      C.Brush.Color := uSurface.PixToColor(uDlgSkin.DlgTheme.Panel);
      C.FillRect(X, 2, X + STRIP_W div 2, 2 + STRIP_H div 2);
      C.Brush.Color := uSurface.PixToColor(uDlgSkin.DlgTheme.Shell2);
    end;
  end;
end;

procedure TRecordWin.Down(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
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
  if FPan or (ssShift in Shift) then
    PanBy(FView, (X - FDX) / K, (Y - FDY) / K)
  else
  begin
    OrbitBy(FView, X - FDX, Y - FDY);
    { turning about what you are looking at, not about the world's zero }
    HoldAt(FView, FPivot, FSrcW / 2, FSrcH / 2);
  end;
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
  P := FBox.ScreenToClient(MousePos);
  K := ViewScale(FSrcW, FSrcH, FBox.Width, FBox.Height);
  AX := FSrcW / 2 + (P.X - FBox.Width / 2) / K;
  AY := FSrcH / 2 + (P.Y - FBox.Height / 2) / K;
  if WheelDelta > 0 then ZoomAt(FView, 1.15, AX, AY)
  else ZoomAt(FView, 1 / 1.15, AX, AY);
  { the zoom you leave it at is the zoom a canned walk starts from }
  FHome.Ppu := FView.Ppu;
  FHome.OX := FView.OX;
  FHome.OY := FView.OY;
  FBox.Invalidate;
  Handled := True;
end;

procedure TRecordWin.KeyDownH(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key <> VK_ESCAPE then Exit;
  Key := 0;
  if FRolling or (FCount > 0) then DoStop(nil)
  else if FPlaying then DoPlay(nil)
  else DoDrop(nil);
end;

procedure TRecordWin.DoGo(Sender: TObject);
var
  K: TWalk;
begin
  if ChosenWalk(K) then Remember(K);
  DoClear(nil);
  FHome := FView;
  FCount := READY_FOR;
  FRolling := False;
  FPlaying := False;
  FGo.Visible := False;
  FStop.Visible := True;
  FTitle.Caption := 'Get ready';
  Refresh_;
end;

procedure TRecordWin.DoStop(Sender: TObject);
begin
  FCount := 0;
  FRolling := False;
  FGo.Visible := True;
  FStop.Visible := False;
  FTitle.Caption := 'Record a move';
  SetLength(FCam, FN);
  { a recording over in a blink is somebody changing their mind }
  if (FN < 2) or (FElapsed < 0.4) then
  begin
    FN := 0;
    SetLength(FCam, 0);
    FStripN := 0;
  end;
  Refresh_;
end;

procedure TRecordWin.DoPlay(Sender: TObject);
begin
  if FN < 2 then Exit;
  FPlaying := not FPlaying;
  FPlayT := 0;
  if FPlaying then FPlay.Caption := 'Stop' else FPlay.Caption := 'Play';
  FBox.Invalidate;
end;

procedure TRecordWin.DoClear(Sender: TObject);
var
  I: Integer;
begin
  FN := 0;
  SetLength(FCam, 0);
  FStripN := 0;
  for I := 0 to STRIP_N - 1 do
    if FStrip[I] <> nil then
    begin
      FStrip[I].Free;
      FStrip[I] := nil;
    end;
  FPlaying := False;
  FPlay.Caption := 'Play';
  FElapsed := 0;
  Refresh_;
end;

procedure TRecordWin.DoTake(Sender: TObject);
begin
  FKept := FN >= 2;
  FTick.Enabled := False;
  ModalResult := mrOk;
end;

procedure TRecordWin.DoDrop(Sender: TObject);
begin
  FKept := False;
  FTick.Enabled := False;
  ModalResult := mrCancel;
end;

function RecordMove(Doc: TWorkDoc; const Start: TProjector; U: TUnitSystem;
  AFont: TFont; const LabelCol: TPix; EdgeW: Single; SrcW, SrcH: Integer;
  Axes: Boolean; const Pivot: TP3; out Cam: TCamPath): Boolean;
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
    W.FPivot := Pivot;
    W.FHome := Start;
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
