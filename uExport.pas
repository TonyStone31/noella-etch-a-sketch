unit uExport;

{ Getting the drawing out of the program.

  Export used to be a save dialog with a list of file types in it, which is
  not an export dialog - it is a file picker with the settings hidden inside
  a combo box, and it cannot ask you anything.  How big?  How good?  Which
  way round?  None of that has anywhere to go.

  So this is a room of its own: the formats down one side, a live view of the
  model in the middle that you can turn and zoom to frame the shot, and
  whatever that format needs to be asked on the right.  What you see in the
  middle is what comes out of the other end, at whatever size you asked for.

  It also does the one thing a still picture cannot: an animated GIF that
  swings round the model.  You frame where it should start, frame where it
  should end, and it eases between the two - which covers a turntable spin, a
  slow push in, a tilt down onto a roof, or all three at once, without a
  timeline to learn.  There is a button for the common case.

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Types, Graphics, Controls, Forms, StdCtrls,
  ExtCtrls, ComCtrls, Dialogs,
  BCButton, BCPanel, BCLabel,
  uSurface, uWork, uSkin, uDlgSkin, uShoot;

type
  TExportKind = (exPng, exJpeg, exGif, exSvg, exDxfView, exDxfModel, exStl);

{ Run the whole thing.  Returns True if something was written, and puts a
  line about it in Msg either way. }
function RunExport(Doc: TWorkDoc; const V: TProjector; U: TUnitSystem;
  AFont: TFont; const LabelCol: TPix; EdgeW: Single; SrcW, SrcH: Integer;
  const Suggest: string; const T: TTheme; out Msg: string): Boolean;

implementation

{ ------------------------------------------------------------------------ }

type
  TExportDlg = class(TForm)
  private
    FDoc: TWorkDoc;
    FUnits: TUnitSystem;
    FFont: TFont;
    FLabelCol: TPix;
    FEdgeW: Single;
    FSrcW, FSrcH: Integer;
    FKind: TExportKind;
    FWrote: Boolean;
    FMsg: string;

    { the camera in the preview, and the two the animation runs between }
    FView, FVA, FVB: TProjector;
    FDragging: Boolean;
    FDragX, FDragY: Integer;
    FPlaying: Boolean;
    FPlayT: Double;

    { chrome }
    FKindBtn: array[TExportKind] of TBCButton;
    FPrev: TPaintBox;
    FHint: TBCLabel;
    FOptTitle: TBCLabel;
    FPath: TEdit;
    FBrowse, FGo, FCancel: TBCButton;

    { options - all built, shown as the format needs }
    FSizeLbl, FQualLbl, FSecLbl, FFpsLbl, FNoteLbl, FShotLbl, FByLbl: TBCLabel;
    FHead: TBCPanel;
    FTitle: TBCLabel;
    FShut: TBCButton;
    FHeadDrag: Boolean;
    FHeadX, FHeadY: Integer;
    FSize: TComboBox;
    FWEdit, FHEdit: TEdit;
    FTransp, FLoop: TCheckBox;
    FQual: TTrackBar;
    FSec, FFps: TEdit;
    FSetA, FSetB, FSpin, FPlay: TBCButton;
    FDxfWhat: TComboBox;
    FTimer: TTimer;

    procedure BuildChrome;
    procedure PickKind(Sender: TObject);
    procedure ShowOptions;
    procedure PrevPaint(Sender: TObject);
    procedure PrevDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PrevMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure PrevUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PrevWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure Tick(Sender: TObject);
    procedure DoSetA(Sender: TObject);
    procedure DoSetB(Sender: TObject);
    procedure DoSpin(Sender: TObject);
    procedure DoPlay(Sender: TObject);
    procedure HeadDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure HeadMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure HeadUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure DoCancel(Sender: TObject);
    procedure DoBrowse(Sender: TObject);
    procedure DoGo(Sender: TObject);
    procedure SizeChanged(Sender: TObject);
    function Ext: string;
    function OutSize(out W, H: Integer): Boolean;
    function Tween(T: Double): TProjector;
    procedure WriteIt;
  public
    constructor Make(Doc: TWorkDoc; const V: TProjector; U: TUnitSystem;
      AFont: TFont; const LabelCol: TPix; EdgeW: Single;
      SrcW, SrcH: Integer; const Suggest: string); reintroduce;
  end;

const
  KIND_NAME: array[TExportKind] of string =
    ('PNG', 'JPEG', 'GIF', 'SVG', 'DXF view', 'DXF model', 'STL');
  KIND_EXT: array[TExportKind] of string =
    ('.png', '.jpg', '.gif', '.svg', '.dxf', '.dxf', '.stl');
  KIND_BLURB: array[TExportKind] of string =
    ('A picture, with the paper behind it or nothing at all.',
     'A picture, smaller and slightly softened.  No transparency.',
     'A little film that swings round the model.',
     'The lines of this view, as vectors, for a drawing program.',
     'This view, flat, as entities somebody can measure in their own CAD.',
     'The model itself, in three dimensions, faces and all.',
     'Triangles in millimetres, which is what a 3D printer wants.');

{ ------------------------------------------------------------------------ }

constructor TExportDlg.Make(Doc: TWorkDoc; const V: TProjector;
  U: TUnitSystem; AFont: TFont; const LabelCol: TPix; EdgeW: Single;
  SrcW, SrcH: Integer; const Suggest: string);
begin
  inherited CreateNew(nil);
  FDoc := Doc;
  FUnits := U;
  FFont := AFont;
  FLabelCol := LabelCol;
  FEdgeW := EdgeW;
  FSrcW := SrcW;
  FSrcH := SrcH;
  FView := V;
  FVA := V;
  FVB := V;
  FVB.Az := V.Az + 2 * Pi;      { a full turn, which is what most people want }
  FKind := exPng;
  FWrote := False;
  BuildChrome;
  FPath.Text := Suggest + KIND_EXT[FKind];
  ShowOptions;
end;

procedure TExportDlg.BuildChrome;

  function MkBtn(Parent: TWinControl; const Cap: string; L, T, W, H: Integer;
    Kind: TBtnKind): TBCButton;
  begin
    Result := TBCButton.Create(Self);
    Result.Parent := Parent;
    Result.SetBounds(L, T, W, H);
    Result.Caption := Cap;
    uDlgSkin.SkinButton(Result, Kind);
  end;

  function MkLbl(Parent: TWinControl; const Cap: string; L, T, W: Integer;
    Dim: Boolean = False; Bold: Boolean = False; FH: Integer = 0): TBCLabel;
  begin
    Result := TBCLabel.Create(Self);
    Result.Parent := Parent;
    Result.SetBounds(L, T, W, 20);
    Result.Caption := Cap;
    uDlgSkin.SkinLabel(Result, Dim, FH, Bold);
  end;

var
  K: TExportKind;
  Y: Integer;
  Rail, Mid, Opt, Foot: TBCPanel;
begin
  Caption := 'Export';
  { No stock frame.  A window manager's title bar in the middle of this
    would be the one piece of it belonging to somebody else, which is the
    whole complaint that started this.  So the dialog draws its own, and
    carries the dragging that comes with it. }
  BorderStyle := bsNone;
  Position := poScreenCenter;
  ClientWidth := 880;
  ClientHeight := 604;
  uDlgSkin.SkinForm(Self);

  FHead := TBCPanel.Create(Self);
  FHead.Parent := Self;
  FHead.SetBounds(0, 0, 880, 44);
  uDlgSkin.SkinPanel(FHead, True, 0);
  FHead.OnMouseDown := @HeadDown;
  FHead.OnMouseMove := @HeadMove;
  FHead.OnMouseUp := @HeadUp;

  FTitle := MkLbl(FHead, 'Export', 16, 11, 300, False, True, -19);
  FTitle.OnMouseDown := @HeadDown;
  FTitle.OnMouseMove := @HeadMove;
  FTitle.OnMouseUp := @HeadUp;

  FShut := MkBtn(FHead, 'X', 836, 8, 28, 28, bkQuiet);
  FShut.OnClick := @DoCancel;

  { --- the formats, down the left ----------------------------------- }
  Rail := TBCPanel.Create(Self);
  Rail.Parent := Self;
  Rail.SetBounds(12, 56, 132, 452);
  uDlgSkin.SkinPanel(Rail, False, 12);

  Y := 10;
  for K := Low(TExportKind) to High(TExportKind) do
  begin
    if K = exSvg then Inc(Y, 12);      { a gap: pictures above, drawings below }
    FKindBtn[K] := MkBtn(Rail, KIND_NAME[K], 10, Y, 112, 34, bkPlain);
    FKindBtn[K].Tag := Ord(K);
    FKindBtn[K].OnClick := @PickKind;
    Inc(Y, 38);
  end;

  { --- the model, in the middle ------------------------------------- }
  Mid := TBCPanel.Create(Self);
  Mid.Parent := Self;
  Mid.SetBounds(156, 56, 440, 452);
  uDlgSkin.SkinPanel(Mid, False, 12);

  FPrev := TPaintBox.Create(Self);
  FPrev.Parent := Mid;
  FPrev.SetBounds(10, 10, 420, 396);
  FPrev.OnPaint := @PrevPaint;
  FPrev.OnMouseDown := @PrevDown;
  FPrev.OnMouseMove := @PrevMove;
  FPrev.OnMouseUp := @PrevUp;
  FPrev.OnMouseWheel := @PrevWheel;

  FHint := MkLbl(Mid, 'Drag to turn it.  Wheel to zoom.  This is the shot.',
    10, 414, 420, True, False, -12);

  { --- what this format needs to be asked, on the right ------------- }
  Opt := TBCPanel.Create(Self);
  Opt.Parent := Self;
  Opt.SetBounds(608, 56, 260, 452);
  uDlgSkin.SkinPanel(Opt, False, 12);

  FOptTitle := MkLbl(Opt, 'PNG', 14, 12, 232, False, True, -17);
  FNoteLbl := MkLbl(Opt, '', 14, 38, 232, True, False, -12);
  FNoteLbl.AutoSize := False;
  FNoteLbl.Height := 52;

  FSizeLbl := MkLbl(Opt, 'Size', 14, 100, 232, True, False, -12);
  FSize := TComboBox.Create(Self);
  FSize.Parent := Opt;
  FSize.SetBounds(14, 120, 232, 26);
  FSize.Items.Add('As it is on screen');
  FSize.Items.Add('Twice the size');
  FSize.Items.Add('Four times the size');
  FSize.Items.Add('A size of my own');
  FSize.ItemIndex := 0;
  FSize.OnChange := @SizeChanged;
  uDlgSkin.SkinCombo(FSize);

  FWEdit := TEdit.Create(Self);
  FWEdit.Parent := Opt;
  FWEdit.SetBounds(14, 152, 100, 26);
  uDlgSkin.SkinEdit(FWEdit);
  FHEdit := TEdit.Create(Self);
  FHEdit.Parent := Opt;
  FHEdit.SetBounds(146, 152, 100, 26);
  uDlgSkin.SkinEdit(FHEdit);
  FByLbl := MkLbl(Opt, 'x', 122, 154, 16, True);

  FTransp := TCheckBox.Create(Self);
  FTransp.Parent := Opt;
  FTransp.SetBounds(14, 188, 232, 22);
  FTransp.Caption := 'Nothing behind it (transparent)';
  uDlgSkin.SkinCheck(FTransp);

  FQualLbl := MkLbl(Opt, 'Quality 88', 14, 220, 232, True, False, -12);
  FQual := TTrackBar.Create(Self);
  FQual.Parent := Opt;
  FQual.SetBounds(10, 240, 240, 34);
  FQual.Min := 20;
  FQual.Max := 100;
  FQual.Position := 88;
  FQual.OnChange := @SizeChanged;
  uDlgSkin.SkinTrack(FQual);

  FSecLbl := MkLbl(Opt, 'Seconds', 14, 190, 110, True, False, -12);
  FSec := TEdit.Create(Self);
  FSec.Parent := Opt;
  FSec.SetBounds(14, 210, 100, 26);
  FSec.Text := '4';
  FSec.OnChange := @SizeChanged;
  uDlgSkin.SkinEdit(FSec);

  FFpsLbl := MkLbl(Opt, 'Frames a second', 146, 190, 110, True, False, -12);
  FFps := TEdit.Create(Self);
  FFps.Parent := Opt;
  FFps.SetBounds(146, 210, 100, 26);
  FFps.Text := '20';
  FFps.OnChange := @SizeChanged;
  uDlgSkin.SkinEdit(FFps);

  FLoop := TCheckBox.Create(Self);
  FLoop.Parent := Opt;
  FLoop.SetBounds(14, 246, 232, 22);
  FLoop.Caption := 'Go round for ever';
  FLoop.Checked := True;
  uDlgSkin.SkinCheck(FLoop);

  FSetA := MkBtn(Opt, 'Set start', 14, 288, 110, 30, bkPlain);
  FSetA.OnClick := @DoSetA;
  FSetB := MkBtn(Opt, 'Set end', 136, 288, 110, 30, bkPlain);
  FSetB.OnClick := @DoSetB;
  FSpin := MkBtn(Opt, 'Full spin from here', 14, 324, 232, 30, bkPlain);
  FSpin.OnClick := @DoSpin;
  FPlay := MkBtn(Opt, 'Play it', 14, 360, 232, 30, bkPlain);
  FPlay.OnClick := @DoPlay;

  FShotLbl := MkLbl(Opt, '', 14, 414, 232, True, False, -12);

  FDxfWhat := TComboBox.Create(Self);
  FDxfWhat.Parent := Opt;
  FDxfWhat.SetBounds(14, 120, 232, 26);
  FDxfWhat.Items.Add('This view, flat');
  FDxfWhat.Items.Add('The model, in three dimensions');
  FDxfWhat.ItemIndex := 0;
  uDlgSkin.SkinCombo(FDxfWhat);

  { --- where it goes ------------------------------------------------- }
  Foot := TBCPanel.Create(Self);
  Foot.Parent := Self;
  Foot.SetBounds(12, 520, 856, 72);
  uDlgSkin.SkinPanel(Foot, False, 12);

  MkLbl(Foot, 'Save it as', 14, 10, 120, True, False, -12);
  FPath := TEdit.Create(Self);
  FPath.Parent := Foot;
  FPath.SetBounds(14, 32, 560, 28);
  uDlgSkin.SkinEdit(FPath);

  FBrowse := MkBtn(Foot, 'Choose...', 584, 32, 96, 28, bkPlain);
  FBrowse.OnClick := @DoBrowse;
  FCancel := MkBtn(Foot, 'Cancel', 690, 32, 76, 28, bkPlain);
  FCancel.OnClick := @DoCancel;
  FGo := MkBtn(Foot, 'Export', 776, 32, 76, 28, bkGo);
  FGo.OnClick := @DoGo;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 40;
  FTimer.Enabled := False;
  FTimer.OnTimer := @Tick;
end;

procedure TExportDlg.PickKind(Sender: TObject);
begin
  FKind := TExportKind((Sender as TBCButton).Tag);
  FPath.Text := ChangeFileExt(FPath.Text, KIND_EXT[FKind]);
  ShowOptions;
end;

procedure TExportDlg.ShowOptions;
var
  K: TExportKind;
  Raster, Anim: Boolean;
  W, H: Integer;
begin
  for K := Low(TExportKind) to High(TExportKind) do
    if K = FKind then uDlgSkin.SkinButton(FKindBtn[K], bkGo)
    else uDlgSkin.SkinButton(FKindBtn[K], bkPlain);

  FOptTitle.Caption := KIND_NAME[FKind];
  FNoteLbl.Caption := KIND_BLURB[FKind];

  Raster := FKind in [exPng, exJpeg, exGif];
  Anim := FKind = exGif;

  FSizeLbl.Visible := Raster;
  FSize.Visible := Raster;
  FWEdit.Visible := Raster and (FSize.ItemIndex = 3);
  FHEdit.Visible := FWEdit.Visible;
  FByLbl.Visible := FWEdit.Visible;
  FTransp.Visible := FKind = exPng;
  FQualLbl.Visible := FKind = exJpeg;
  FQual.Visible := FKind = exJpeg;

  FSecLbl.Visible := Anim;
  FSec.Visible := Anim;
  FFpsLbl.Visible := Anim;
  FFps.Visible := Anim;
  FLoop.Visible := Anim;
  FSetA.Visible := Anim;
  FSetB.Visible := Anim;
  FSpin.Visible := Anim;
  FPlay.Visible := Anim;
  FShotLbl.Visible := Raster;
  FDxfWhat.Visible := FKind in [exDxfView, exDxfModel];

  if not Anim then
  begin
    FPlaying := False;
    FTimer.Enabled := False;
    FPlay.Caption := 'Play it';
  end;

  { say what it will come to, since that is the question behind every one of
    these settings }
  if Raster and OutSize(W, H) then
  begin
    if Anim then
      FShotLbl.Caption := Format('%d x %d, %d frames', [W, H,
        Max(1, Min(GIF_MAX_FRAMES,
          Round(StrToFloatDef(FSec.Text, 4) * StrToIntDef(FFps.Text, 20))))])
    else
      FShotLbl.Caption := Format('%d x %d pixels', [W, H]);
  end
  else if Raster then
    FShotLbl.Caption := 'that size will not do';

  FPrev.Invalidate;
end;

procedure TExportDlg.SizeChanged(Sender: TObject);
begin
  if Sender = FQual then
    FQualLbl.Caption := Format('Quality %d', [FQual.Position]);
  ShowOptions;
end;

function TExportDlg.OutSize(out W, H: Integer): Boolean;
begin
  case FSize.ItemIndex of
    1: begin W := FSrcW * 2; H := FSrcH * 2; end;
    2: begin W := FSrcW * 4; H := FSrcH * 4; end;
    3: begin
         W := StrToIntDef(FWEdit.Text, 0);
         H := StrToIntDef(FHEdit.Text, 0);
       end;
  else
    W := FSrcW; H := FSrcH;
  end;
  { a GIF at screen size and twenty a second is tens of megabytes, so it is
    held to something that will actually send }
  if (FKind = exGif) and (FSize.ItemIndex = 0) then
  begin
    W := Min(W, 720);
    H := Round(H * W / Max(1, FSrcW));
  end;
  Result := (W >= 16) and (H >= 16) and (W <= 8000) and (H <= 8000);
end;

function TExportDlg.Ext: string;
begin
  Result := KIND_EXT[FKind];
end;

function TExportDlg.Tween(T: Double): TProjector;
begin
  Result := TweenView(FVA, FVB, T);
end;

procedure TExportDlg.PrevPaint(Sender: TObject);
var
  S: TArtSurface;
  Bmp: TBitmap;
  V: TProjector;
  Bg: TPix;
begin
  if FPlaying then V := Tween(FPlayT) else V := FView;
  if (FKind = exPng) and FTransp.Checked then Bg := Pix(255, 255, 255, 0)
  else Bg := Pix(255, 255, 255);
  S := ShootFrame(FDoc, Fitted(V, FSrcW, FSrcH, FPrev.Width, FPrev.Height),
    FPrev.Width, FPrev.Height, FUnits, FFont, FLabelCol, FEdgeW, Bg,
    FDragging or FPlaying);
  try
    Bmp := S.AsBitmap;
    FPrev.Canvas.Draw(0, 0, Bmp);
  finally
    S.Free;
  end;
end;

procedure TExportDlg.PrevDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FDragging := True;
  FDragX := X;
  FDragY := Y;
end;

procedure TExportDlg.PrevMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
  if not FDragging then Exit;
  FView.Az := FView.Az - (X - FDragX) * 0.01;
  FView.El := Max(-1.5, Min(1.5, FView.El + (Y - FDragY) * 0.01));
  FDragX := X;
  FDragY := Y;
  FPlaying := False;
  FTimer.Enabled := False;
  FPlay.Caption := 'Play it';
  FPrev.Invalidate;
end;

procedure TExportDlg.PrevUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FDragging := False;
  FPrev.Invalidate;         { the sharp one, now the camera has stopped }
end;

procedure TExportDlg.PrevWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  if WheelDelta > 0 then FView.Ppu := FView.Ppu * 1.12
  else FView.Ppu := FView.Ppu / 1.12;
  FView.Ppu := Max(1E-4, Min(1E6, FView.Ppu));
  FPrev.Invalidate;
  Handled := True;
end;

procedure TExportDlg.Tick(Sender: TObject);
begin
  FPlayT := FPlayT + 0.02;
  if FPlayT > 1 then FPlayT := 0;
  FPrev.Invalidate;
end;

procedure TExportDlg.DoSetA(Sender: TObject);
begin
  FVA := FView;
  FHint.Caption := 'Start set.  Now frame where it should end.';
end;

procedure TExportDlg.DoSetB(Sender: TObject);
begin
  FVB := FView;
  FHint.Caption := 'End set.  Press Play it to see the move.';
end;

procedure TExportDlg.DoSpin(Sender: TObject);
begin
  FVA := FView;
  FVB := FView;
  FVB.Az := FView.Az + 2 * Pi;
  FHint.Caption := 'A full turn from where you are looking now.';
end;

procedure TExportDlg.DoPlay(Sender: TObject);
begin
  FPlaying := not FPlaying;
  FPlayT := 0;
  FTimer.Enabled := FPlaying;
  if FPlaying then FPlay.Caption := 'Stop' else FPlay.Caption := 'Play it';
  FPrev.Invalidate;
end;

procedure TExportDlg.HeadDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FHeadDrag := True;
  FHeadX := X;
  FHeadY := Y;
  if Sender is TControl then
  begin
    Inc(FHeadX, TControl(Sender).Left);
    Inc(FHeadY, TControl(Sender).Top);
  end;
end;

procedure TExportDlg.HeadMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
  DX, DY: Integer;
begin
  if not FHeadDrag then Exit;
  DX := X;
  DY := Y;
  if Sender is TControl then
  begin
    Inc(DX, TControl(Sender).Left);
    Inc(DY, TControl(Sender).Top);
  end;
  Left := Left + (DX - FHeadX);
  Top := Top + (DY - FHeadY);
end;

procedure TExportDlg.HeadUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FHeadDrag := False;
end;

procedure TExportDlg.DoCancel(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TExportDlg.DoBrowse(Sender: TObject);
var
  D: TSaveDialog;
begin
  D := TSaveDialog.Create(nil);
  try
    D.Filter := KIND_NAME[FKind] + '|*' + Ext;
    D.DefaultExt := Ext;
    D.FileName := FPath.Text;
    if D.Execute then FPath.Text := ChangeFileExt(D.FileName, Ext);
  finally
    D.Free;
  end;
end;

procedure TExportDlg.DoGo(Sender: TObject);
begin
  FPlaying := False;
  FTimer.Enabled := False;
  if Trim(FPath.Text) = '' then
  begin
    FHint.Caption := 'It needs somewhere to go - pick a file below.';
    Exit;
  end;
  try
    WriteIt;
    FWrote := True;
    ModalResult := mrOk;
  except
    on E: Exception do
    begin
      FMsg := 'Could not export: ' + E.Message;
      FHint.Caption := FMsg;
    end;
  end;
end;

procedure TExportDlg.WriteIt;
var
  W, H, N, NTri: Integer;
  Fn: string;
  L: TStringList;
  FS: TFileStream;
  Shut: Boolean;
begin
  Fn := ChangeFileExt(Trim(FPath.Text), Ext);
  case FKind of
    exSvg:
      begin
        L := TStringList.Create;
        try
          FDoc.WriteSVG(L, FView, FUnits, FEdgeW);
          L.SaveToFile(Fn);
        finally
          L.Free;
        end;
        FMsg := 'Wrote ' + ExtractFileName(Fn) + '.';
      end;

    exDxfView, exDxfModel:
      begin
        L := TStringList.Create;
        try
          FDoc.WriteDXF(L, FView, FUnits, FDxfWhat.ItemIndex = 1);
          L.SaveToFile(Fn);
        finally
          L.Free;
        end;
        FMsg := 'Wrote ' + ExtractFileName(Fn) + '.';
      end;

    exStl:
      begin
        FS := TFileStream.Create(Fn, fmCreate);
        try
          NTri := FDoc.WriteSTL(FS, FUnits, Shut);
        finally
          FS.Free;
        end;
        if NTri = 0 then
          FMsg := 'Nothing to print - an STL is made of faces, and this ' +
            'drawing has none.'
        else if not Shut then
          FMsg := Format('%d triangles, in millimetres - but this is not a ' +
            'closed solid, so a slicer will have to guess at the inside.',
            [NTri])
        else
          FMsg := Format('%d triangles, in millimetres, closed and ready to ' +
            'slice.', [NTri]);
      end;

    exGif:
      begin
        if not OutSize(W, H) then raise Exception.Create('that size will not do');
        N := SaveOrbitGif(FDoc, FVA, FVB, FSrcW, FSrcH, W, H, FUnits, FFont,
          FLabelCol, FEdgeW, StrToFloatDef(FSec.Text, 4),
          StrToIntDef(FFps.Text, 20), FLoop.Checked, Fn);
        FMsg := Format('Wrote %s - %d frames, %d x %d.',
          [ExtractFileName(Fn), N, W, H]);
      end;

  else   { exPng, exJpeg }
    begin
      if not OutSize(W, H) then raise Exception.Create('that size will not do');
      SaveStill(FDoc, FView, FSrcW, FSrcH, W, H, FUnits, FFont, FLabelCol,
        FEdgeW, Fn, FKind = exJpeg, FQual.Position,
        (FKind = exPng) and FTransp.Checked);
      FMsg := Format('Wrote %s - %d x %d.', [ExtractFileName(Fn), W, H]);
    end;
  end;
end;

{ ------------------------------------------------------------------------ }

function RunExport(Doc: TWorkDoc; const V: TProjector; U: TUnitSystem;
  AFont: TFont; const LabelCol: TPix; EdgeW: Single; SrcW, SrcH: Integer;
  const Suggest: string; const T: TTheme; out Msg: string): Boolean;
var
  Dlg: TExportDlg;
begin
  uDlgSkin.UseTheme(T);
  Dlg := TExportDlg.Make(Doc, V, U, AFont, LabelCol, EdgeW, SrcW, SrcH,
    Suggest);
  try
    Dlg.ShowModal;
    Result := Dlg.FWrote;
    Msg := Dlg.FMsg;
  finally
    Dlg.Free;
  end;
end;

end.
