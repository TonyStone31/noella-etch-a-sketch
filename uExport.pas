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
  ExtCtrls, ComCtrls, Dialogs, LCLType,
  BCButton, BCPanel, BCLabel,
  uSurface, uWork, uSkin, uDlgSkin, uShoot, uRecord;

type
  TExportKind = (exPng, exJpeg, exGif, exSvg, exDxfView, exDxfModel, exStl);

type
  { how the dialog asks the main window to send a bug report - it cannot do
    it itself, the report wants a picture of the screen and the whole state }
  TReportProc = procedure(const Where, Fields: string) of object;

{ Run the whole thing.  Returns True if something was written, and puts a
  line about it in Msg either way. }
function RunExport(Doc: TWorkDoc; const V: TProjector; U: TUnitSystem;
  AFont: TFont; const LabelCol: TPix; EdgeW: Single; SrcW, SrcH: Integer;
  const Suggest: string; const T: TTheme; OnReport: TReportProc;
  out Msg: string): Boolean;

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
    { what the export was doing when it went wrong.  Windows sent back an
      access violation and no file, and there was no way to tell from here
      which of half a dozen steps it died in - so now it says. }
    FStage: string;
    FOnReport: TReportProc;

    { the camera in the preview, and the two the animation runs between }
    FView, FVA, FVB: TProjector;
    FDragging, FPanning: Boolean;
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
    FTransp, FLoop, FAxes: TBCButton;
    FTranspOn, FLoopOn, FAxesOn: Boolean;
    FQual: TTrackBar;
    FSec, FFps: TEdit;
    FSetA, FSetB, FSpin, FPlay, FRec, FSay: TBCButton;
    FTellBad: TBCLabel;
    FCam: TCamPath;
    FDxfWhat: TComboBox;
    FTimer: TTimer;

    procedure ComboDraw(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
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
    procedure DoRecord(Sender: TObject);
    procedure HeadDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure HeadMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure HeadUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FilmSays(const S: string);
    procedure DoSay(Sender: TObject);
    procedure DoCancel(Sender: TObject);
    procedure DoBrowse(Sender: TObject);
    procedure DoGo(Sender: TObject);
    procedure SizeChanged(Sender: TObject);
    procedure Ticked(Sender: TObject);
    procedure ShowTick(B: TBCButton; On_: Boolean; const Cap: string);
    function Ext: string;
    function Weigh(Frames, W, H: Integer): string;
    function OutSize(out W, H: Integer): Boolean;
    function Tween(T: Double): TProjector;
    procedure WriteIt;
  public
    constructor Make(Doc: TWorkDoc; const V: TProjector; U: TUnitSystem;
      AFont: TFont; const LabelCol: TPix; EdgeW: Single;
      SrcW, SrcH: Integer; const Suggest: string); reintroduce;
  end;

type
  TSizePick = record
    Name: string;
    W, H: Integer;      { 0,0 means work it out from the screen }
    Mul: Double;        { used when W and H are 0 }
  end;

const
  { The sizes people are actually going to want.  A picture of a drawing
    almost always ends up somewhere with an opinion about its shape, and
    hunting for "1080 x 1920" in a pair of edit boxes is a worse way to find
    that out than being offered it. }
  SIZES: array[0..10] of TSizePick = (
    (Name: 'As it is on screen';            W: 0;    H: 0;    Mul: 1),
    (Name: 'Twice the size';                W: 0;    H: 0;    Mul: 2),
    (Name: 'Four times the size';           W: 0;    H: 0;    Mul: 4),
    (Name: 'Square - 1080 x 1080';          W: 1080; H: 1080; Mul: 0),
    (Name: 'Tall - 1080 x 1920';            W: 1080; H: 1920; Mul: 0),
    (Name: 'Wide - 1200 x 675';             W: 1200; H: 675;  Mul: 0),
    (Name: 'Link card - 1200 x 630';        W: 1200; H: 630;  Mul: 0),
    (Name: '720p - 1280 x 720';             W: 1280; H: 720;  Mul: 0),
    (Name: '1080p - 1920 x 1080';           W: 1920; H: 1080; Mul: 0),
    (Name: 'Small, for an email - 800 x 600'; W: 800; H: 600; Mul: 0),
    (Name: 'A size of my own';              W: -1;   H: -1;   Mul: 0));
  SIZE_MINE = 10;

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

  FHint := MkLbl(Mid, 'Middle-drag turns it, right-drag slides it, wheel zooms - '
    + 'the same as the drawing.  This is the shot.',
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

  FSizeLbl := MkLbl(Opt, 'Size', 14, 96, 232, True, False, -12);
  FSize := TComboBox.Create(Self);
  FSize.Parent := Opt;
  FSize.SetBounds(14, 116, 232, 26);
  for Y := 0 to High(SIZES) do FSize.Items.Add(SIZES[Y].Name);
  FSize.ItemIndex := 0;
  FSize.OnChange := @SizeChanged;
  FSize.Style := csOwnerDrawFixed;
  FSize.ItemHeight := 22;
  FSize.OnDrawItem := @ComboDraw;
  FSize.Color := uSurface.PixToColor(uDlgSkin.DlgTheme.Shell2);
  FSize.Font.Color := uSurface.PixToColor(uDlgSkin.DlgTheme.Text);

  FWEdit := TEdit.Create(Self);
  FWEdit.Parent := Opt;
  FWEdit.SetBounds(14, 148, 100, 26);
  uDlgSkin.SkinEdit(FWEdit);
  FHEdit := TEdit.Create(Self);
  FHEdit.Parent := Opt;
  FHEdit.SetBounds(146, 148, 100, 26);
  uDlgSkin.SkinEdit(FHEdit);
  FByLbl := MkLbl(Opt, 'x', 122, 150, 16, True);

  FTransp := MkBtn(Opt, '', 14, 212, 232, 26, bkPlain);
  FTransp.Tag := 1;
  FTransp.OnClick := @Ticked;
  ShowTick(FTransp, False, 'Nothing behind it');

  FQualLbl := MkLbl(Opt, 'Quality 88', 14, 212, 232, True, False, -12);
  FQual := TTrackBar.Create(Self);
  FQual.Parent := Opt;
  FQual.SetBounds(10, 232, 240, 34);
  FQual.Min := 20;
  FQual.Max := 100;
  FQual.Position := 88;
  FQual.OnChange := @SizeChanged;
  uDlgSkin.SkinTrack(FQual);

  FSecLbl := MkLbl(Opt, 'Seconds', 14, 212, 110, True, False, -12);
  FSec := TEdit.Create(Self);
  FSec.Parent := Opt;
  FSec.SetBounds(14, 232, 100, 26);
  FSec.Text := '4';
  FSec.OnChange := @SizeChanged;
  uDlgSkin.SkinEdit(FSec);

  FFpsLbl := MkLbl(Opt, 'Frames a second', 146, 212, 110, True, False, -12);
  FFps := TEdit.Create(Self);
  FFps.Parent := Opt;
  FFps.SetBounds(146, 232, 100, 26);
  FFps.Text := '20';
  FFps.OnChange := @SizeChanged;
  uDlgSkin.SkinEdit(FFps);

  FLoopOn := True;
  FLoop := MkBtn(Opt, '', 14, 264, 232, 26, bkPlain);
  FLoop.Tag := 2;
  FLoop.OnClick := @Ticked;
  ShowTick(FLoop, True, 'Go round for ever');

  FSetA := MkBtn(Opt, 'Set start', 14, 296, 110, 30, bkPlain);
  FSetA.OnClick := @DoSetA;
  FSetB := MkBtn(Opt, 'Set end', 136, 296, 110, 30, bkPlain);
  FSetB.OnClick := @DoSetB;
  FSpin := MkBtn(Opt, 'Full spin from here', 14, 330, 232, 30, bkPlain);
  FSpin.OnClick := @DoSpin;
  FPlay := MkBtn(Opt, 'Play it', 14, 364, 232, 30, bkPlain);
  FPlay.OnClick := @DoPlay;
  FRec := MkBtn(Opt, 'Record a move instead', 14, 398, 232, 30, bkPlain);
  FRec.OnClick := @DoRecord;

  FAxesOn := True;
  FAxes := MkBtn(Opt, '', 14, 180, 232, 26, bkPlain);
  FAxes.Tag := 3;
  FAxes.OnClick := @Ticked;
  ShowTick(FAxes, True, 'Show the axes');

  FShotLbl := MkLbl(Opt, '', 14, 432, 232, True, False, -12);

  FDxfWhat := TComboBox.Create(Self);
  FDxfWhat.Parent := Opt;
  FDxfWhat.SetBounds(14, 116, 232, 26);
  FDxfWhat.Items.Add('This view, flat');
  FDxfWhat.Items.Add('The model, in three dimensions');
  FDxfWhat.ItemIndex := 0;
  FDxfWhat.Style := csOwnerDrawFixed;
  FDxfWhat.ItemHeight := 22;
  FDxfWhat.OnDrawItem := @ComboDraw;
  FDxfWhat.Color := uSurface.PixToColor(uDlgSkin.DlgTheme.Shell2);
  FDxfWhat.Font.Color := uSurface.PixToColor(uDlgSkin.DlgTheme.Text);

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

  FTellBad := MkLbl(Foot, '', 14, 4, 700, True, False, -12);
  FTellBad.Visible := False;
  FSay := MkBtn(Foot, 'Tell Tony about it', 584, 4, 268, 22, bkPlain);
  FSay.OnClick := @DoSay;
  FSay.Visible := False;

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

{ Windows paints a themed combo box itself and takes no notice of Font.Color,
  so on a dark dialog the writing comes out black on near-black.  Drawing the
  rows ourselves is the only way to be sure, and it costs almost nothing. }
procedure TExportDlg.ComboDraw(Control: TWinControl; Index: Integer;
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
  W, H, NF, Rate: Integer;
  Secs: Double;
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
  FWEdit.Visible := Raster and (FSize.ItemIndex = SIZE_MINE);
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
  FAxes.Visible := Raster;
  FRec.Visible := Anim;
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
    begin
      Secs := Max(0.2, Min(GIF_MAX_SECONDS, StrToFloatDef(FSec.Text, 4)));
      FilmPlan(Secs, StrToIntDef(FFps.Text, 20), W, H, NF, Rate);
      { A big picture buys fewer frames - the whole film has to be held in
        memory at once - so say so here rather than let somebody wait for it
        and wonder why it came out jerky. }
      { say what it will weigh, because that is the question behind the size
        and nobody should have to export one to find out }
      if Rate < StrToIntDef(FFps.Text, 20) then
        FShotLbl.Caption := Format('%d x %d, %.1fs at %d a second, about %s' +
          '  (a smaller size buys more frames)',
          [W, H, Secs, Rate, Weigh(NF, W, H)])
      else
        FShotLbl.Caption := Format('%d x %d, %.1fs, %d frames, about %s',
          [W, H, Secs, NF, Weigh(NF, W, H)]);
    end
    else
      FShotLbl.Caption := Format('%d x %d pixels', [W, H]);
  end
  else if Raster then
    FShotLbl.Caption := 'that size will not do';

  FPrev.Invalidate;
end;

{ A tick that is a button, for the same reason the combo draws itself: a
  themed check box writes its own caption in the system's text colour and
  will not be told otherwise. }
procedure TExportDlg.ShowTick(B: TBCButton; On_: Boolean; const Cap: string);
begin
  if On_ then
  begin
    B.Caption := '[x]  ' + Cap;
    uDlgSkin.SkinButton(B, bkGo);
  end
  else
  begin
    B.Caption := '[  ]  ' + Cap;
    uDlgSkin.SkinButton(B, bkPlain);
  end;
end;

procedure TExportDlg.Ticked(Sender: TObject);
begin
  case (Sender as TBCButton).Tag of
    1: begin
         FTranspOn := not FTranspOn;
         ShowTick(FTransp, FTranspOn, 'Nothing behind it');
       end;
    2: begin
         FLoopOn := not FLoopOn;
         ShowTick(FLoop, FLoopOn, 'Go round for ever');
       end;
    3: begin
         FAxesOn := not FAxesOn;
         ShowTick(FAxes, FAxesOn, 'Show the axes');
       end;
  end;
  FPrev.Invalidate;
  ShowOptions;
end;

procedure TExportDlg.SizeChanged(Sender: TObject);
begin
  if Sender = FQual then
    FQualLbl.Caption := Format('Quality %d', [FQual.Position]);
  ShowOptions;
end;

function TExportDlg.OutSize(out W, H: Integer): Boolean;
var
  I: Integer;
  K: Double;
begin
  I := FSize.ItemIndex;
  if (I < 0) or (I > High(SIZES)) then I := 0;
  if I = SIZE_MINE then
  begin
    W := StrToIntDef(FWEdit.Text, 0);
    H := StrToIntDef(FHEdit.Text, 0);
  end
  else if SIZES[I].W > 0 then
  begin
    W := SIZES[I].W;
    H := SIZES[I].H;
  end
  else
  begin
    W := Round(FSrcW * SIZES[I].Mul);
    H := Round(FSrcH * SIZES[I].Mul);
  end;

  { A GIF is frames times pixels, and both run away.  Rather than refuse a
    size somebody has chosen, it is brought down to something that will
    actually send, keeping its shape. }
  if (FKind = exGif) and (W > 900) then
  begin
    K := 900 / W;
    W := 900;
    H := Max(16, Round(H * K));
  end;

  { And nothing is refused for being too big when it can simply be made to
    fit - four times a big screen used to come out past the limit and give
    "that size will not do", which is a strange answer to a button that
    offered it. }
  if (W > 8000) or (H > 8000) then
  begin
    K := Min(8000 / Max(1, W), 8000 / Max(1, H));
    W := Max(16, Round(W * K));
    H := Max(16, Round(H * K));
  end;
  Result := (W >= 16) and (H >= 16);
end;

{ Roughly what the film will come to on disk, from a rate measured on the
  busiest drawing to hand.  Roughly is the useful amount of precision here -
  it is the difference between "fine" and "too big to send" that matters. }
function TExportDlg.Weigh(Frames, W, H: Integer): string;
var
  B: Double;
begin
  B := Frames * Double(W) * H * GIF_BYTES_PER_PIXEL;
  if B >= 1024 * 1024 then Result := Format('%.1f MB', [B / 1024 / 1024])
  else Result := Format('%.0f KB', [B / 1024]);
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
  if (FKind = exPng) and FTranspOn then Bg := Pix(255, 255, 255, 0)
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

{ The same buttons as the drawing area, because a preview that answers to
  different ones is a preview you have to think about.  Middle turns it,
  right slides it, and the left button does nothing at all - there is nothing
  here to pick. }
procedure TExportDlg.PrevDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FDragging := Button in [mbMiddle, mbRight];
  FPanning := Button = mbRight;
  FDragX := X;
  FDragY := Y;
end;

procedure TExportDlg.PrevMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
  K: Double;
begin
  if not FDragging then Exit;
  { Shift is tested every move rather than only when the button went down, so
    you can grab it part way through a turn and slide instead - which is what
    the drawing area does and what the hand expects. }
  K := ViewScale(FSrcW, FSrcH, FPrev.Width, FPrev.Height);
  if FPanning or (ssShift in Shift) then
    { the preview and the shot are different sizes, so a slide measured here
      goes back through the same scale the picture was fitted with, or it
      moves at the wrong speed - and by ONE scale, not a different one per
      axis, because that is what Fitted uses }
    PanBy(FView, (X - FDragX) / K, (Y - FDragY) / K)
  else
    OrbitBy(FView, X - FDragX, Y - FDragY);
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
  FPanning := False;
  FPrev.Invalidate;         { the sharp one, now the camera has stopped }
end;

procedure TExportDlg.PrevWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
var
  P: TPoint;
  K, AX, AY: Double;
begin
  { 1.15 and anchored on the cursor, both the same as the drawing area.
    MousePos is in screen terms, so it comes back to the preview and then
    through the fitting scale into the terms the view is kept in. }
  P := FPrev.ScreenToClient(MousePos);
  K := ViewScale(FSrcW, FSrcH, FPrev.Width, FPrev.Height);
  AX := FSrcW / 2 + (P.X - FPrev.Width / 2) / K;
  AY := FSrcH / 2 + (P.Y - FPrev.Height / 2) / K;
  if WheelDelta > 0 then ZoomAt(FView, 1.15, AX, AY)
  else ZoomAt(FView, 1 / 1.15, AX, AY);
  FPrev.Invalidate;
  Handled := True;
end;

procedure TExportDlg.Tick(Sender: TObject);
var
  T: Double;
begin
  T := FPlayT + 0.02;                     { a local first - see OrbitBy }
  FPlayT := T;
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

{ Hand the whole state of the export over to the report, so whatever went
  wrong arrives with the settings that caused it rather than a description of
  them from memory. }
procedure TExportDlg.FilmSays(const S: string);
begin
  FStage := S;
end;

procedure TExportDlg.DoSay(Sender: TObject);
var
  W, H: Integer;
  Fields: string;
begin
  if not Assigned(FOnReport) then Exit;
  if not OutSize(W, H) then begin W := 0; H := 0; end;
  Fields := Format(
    'export=%s stage=%s' + LineEnding +
    'asked for=%dx%d from a %dx%d screen, size choice %d' + LineEnding +
    'gif=%s seconds, %s a second, loop=%s, recorded=%.1fs, axes=%s' + LineEnding +
    'what it said: %s' + LineEnding +
    'path=%s',
    [KIND_NAME[FKind], FStage, W, H, FSrcW, FSrcH, FSize.ItemIndex,
     FSec.Text, FFps.Text, BoolToStr(FLoopOn, 'yes', 'no'),
     CamPathLength(FCam), BoolToStr(FAxesOn, 'yes', 'no'),
     FMsg, ExtractFileName(FPath.Text)]);
  ModalResult := mrCancel;
  { the report wants a picture of the screen and this window is in front of
    it, so it goes first and the main window raises the report }
  FOnReport('the export dialog', Fields);
end;

procedure TExportDlg.DoCancel(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

{ A recording beats the two ends: it is what somebody actually did, and the
  two ends were only ever a way of describing a move without making one. }
procedure TExportDlg.DoRecord(Sender: TObject);
var
  Got: TCamPath;
begin
  FPlaying := False;
  FTimer.Enabled := False;
  FPlay.Caption := 'Play it';
  Hide;
  try
    if RecordMove(FDoc, FView, FUnits, FFont, FLabelCol, FEdgeW,
         FSrcW, FSrcH, FAxesOn, Got) then
    begin
      FCam := Got;
      { and it goes in the box, because a recording that quietly overrode
        whatever the box said is how a four second export turned into three
        hundred frames }
      FSec.Text := Format('%.1f', [CamPathLength(FCam)]);
      FHint.Caption := Format('Recorded %.1f seconds.  That is the shot now - ' +
        'press Record again to do it over.', [CamPathLength(FCam)]);
    end;
  finally
    Show;
  end;
  ShowOptions;
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
  FStage := 'starting';
  uShoot.OnFilmStage := @FilmSays;
  try
    WriteIt;
    FWrote := True;
    ModalResult := mrOk;
  except
    on E: Exception do
    begin
      { the class as well as the message: an access violation carries no
        message worth reading, and its name is the whole of what it says }
      FMsg := Format('Could not export - %s while %s%s',
        [E.ClassName, FStage,
         specialize IfThen<string>(E.Message = '', '', ': ' + E.Message)]);
      FHint.Caption := FMsg;
      FTellBad.Caption := FMsg;
      FTellBad.Visible := True;
      FSay.Visible := Assigned(FOnReport);
    end;
  end;
  uShoot.OnFilmStage := nil;
end;

procedure TExportDlg.WriteIt;
var
  W, H, N, NTri: Integer;
  Fn: string;
  L: TStringList;
  FS: TFileStream;
  Shut: Boolean;
begin
  FStage := 'working out where to put it';
  Fn := ChangeFileExt(Trim(FPath.Text), Ext);
  case FKind of
    exSvg:
      begin
        FStage := 'writing the SVG';
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
        FStage := 'writing the DXF';
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
        FStage := 'writing the STL';
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
        FStage := 'working out the size';
        if not OutSize(W, H) then raise Exception.Create('that size will not do');
        FStage := Format('drawing the frames at %dx%d', [W, H]);
        if Length(FCam) >= 2 then
          N := SavePathGif(FDoc, FCam, FSrcW, FSrcH, W, H, FUnits, FFont,
            FLabelCol, FEdgeW, StrToIntDef(FFps.Text, 20), FLoopOn,
            FAxesOn, Fn)
        else
          N := SaveOrbitGif(FDoc, FVA, FVB, FSrcW, FSrcH, W, H, FUnits, FFont,
            FLabelCol, FEdgeW, StrToFloatDef(FSec.Text, 4),
            StrToIntDef(FFps.Text, 20), FLoopOn, FAxesOn, Fn);
        FMsg := Format('Wrote %s - %d frames, %d x %d.',
          [ExtractFileName(Fn), N, W, H]);
      end;

  else   { exPng, exJpeg }
    begin
      FStage := 'working out the size';
      if not OutSize(W, H) then raise Exception.Create('that size will not do');
      FStage := Format('drawing the picture at %dx%d', [W, H]);
      SaveStill(FDoc, FView, FSrcW, FSrcH, W, H, FUnits, FFont, FLabelCol,
        FEdgeW, Fn, FKind = exJpeg, FQual.Position,
        (FKind = exPng) and FTranspOn, FAxesOn);
      FMsg := Format('Wrote %s - %d x %d.', [ExtractFileName(Fn), W, H]);
    end;
  end;
end;

{ ------------------------------------------------------------------------ }

function RunExport(Doc: TWorkDoc; const V: TProjector; U: TUnitSystem;
  AFont: TFont; const LabelCol: TPix; EdgeW: Single; SrcW, SrcH: Integer;
  const Suggest: string; const T: TTheme; OnReport: TReportProc;
  out Msg: string): Boolean;
var
  Dlg: TExportDlg;
begin
  uDlgSkin.UseTheme(T);
  Dlg := TExportDlg.Make(Doc, V, U, AFont, LabelCol, EdgeW, SrcW, SrcH,
    Suggest);
  Dlg.FOnReport := OnReport;
  try
    Dlg.ShowModal;
    Result := Dlg.FWrote;
    Msg := Dlg.FMsg;
  finally
    Dlg.Free;
  end;
end;

end.
