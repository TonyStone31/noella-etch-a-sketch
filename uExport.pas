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
  TExportKind = (exPng, exJpeg, exGif, exSvg, exDxfView, exDxfModel, exStl,
    exScad);

type
  { how the dialog asks the main window to send a bug report - it cannot do
    it itself, the report wants a picture of the screen and the whole state }
  TReportProc = procedure(const Where, Fields: string) of object;

{ Run the whole thing.  Returns True if something was written, and puts a
  line about it in Msg either way. }
{ Where a file of this kind went last time, and somewhere to say where it
  went this time.  The dialog owns neither - it asks, because people keep
  their STLs in one place and their pictures for a forum in another, and
  which is which is the program's business to remember. }
type
  TDirFor = function(const Ext: string): string of object;
  TDirKeep = procedure(const Ext, Dir: string) of object;

function RunExport(Doc: TWorkDoc; const V: TProjector; U: TUnitSystem;
  AFont: TFont; const LabelCol: TPix; EdgeW: Single; SrcW, SrcH: Integer;
  const Suggest: string; const T: TTheme; const Pivot: TP3;
  OnReport: TReportProc; DirFor: TDirFor; DirKeep: TDirKeep;
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
    { the name to offer, without a folder or an extension, and the two hooks
      that know where each kind of file belongs }
    FStem: string;
    FDirFor: TDirFor;
    FDirKeep: TDirKeep;

    { the camera in the preview }
    FView: TProjector;
    FPivot: TP3;
    FDragging, FPanning: Boolean;
    FDragX, FDragY: Integer;
    FPlaying: Boolean;
    FPlayT: Double;

    { chrome }
    FKindBtn: array[TExportKind] of TBCButton;
    FPrev: TPaintBox;
    FHint: TLabel;
    FOptTitle: TBCLabel;
    FPath: TEdit;
    FBrowse, FGo, FCancel: TBCButton;

    { options - all built, shown as the format needs }
    FSizeLbl, FQualLbl, FByLbl, FSaveLbl: TBCLabel;
    FNoteLbl, FShotLbl, FClipLbl: TLabel;
    FHead: TBCPanel;
    FTitle: TBCLabel;
    FShut: TBCButton;
    FHeadDrag: Boolean;
    FHeadX, FHeadY: Integer;
    FSize: TComboBox;
    FWEdit, FHEdit: TEdit;
    FTransp, FLoop, FAxes, FMid: TBCButton;
    FTranspOn, FLoopOn, FAxesOn, FMidOn: Boolean;
    FQual: TTrackBar;
    FPlay, FRec, FSay: TBCButton;
    FTellBad: TLabel;
    FCam: TCamPath;
    FDxfWhat: TComboBox;
    FTimer: TTimer;
    FPrevS: TArtSurface;
    { how far along an export is, and what it is doing }
    FBar: TPaintBox;
    FBusy: Boolean;
    FDone, FTotal: Integer;
    FDoing: string;

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
    procedure DoPlay(Sender: TObject);
    procedure DoRecord(Sender: TObject);
    procedure HeadDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure HeadMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure HeadUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FilmSays(const S: string);
    procedure FilmStep(Done, Total: Integer; const What: string);
    procedure BarPaint(Sender: TObject);
    procedure Working(On_: Boolean);
    procedure DoSay(Sender: TObject);
    procedure DoCancel(Sender: TObject);
    procedure AskClose(Sender: TObject; var CanClose: Boolean);
    procedure DoBrowse(Sender: TObject);
    procedure DoGo(Sender: TObject);
    procedure SizeChanged(Sender: TObject);
    procedure Ticked(Sender: TObject);
    procedure ShowTick(B: TBCButton; On_: Boolean; const Cap: string);
    function Ext: string;
    { the whole path to offer for a format: the folder that kind of file went
      to last time, and whatever name is in the box now }
    function PathFor(K: TExportKind): string;
    function Weigh(Frames, W, H: Integer): string;
    function OutSize(out W, H: Integer): Boolean;
    function Tween(T: Double): TProjector;
    procedure WriteIt;
  public
    destructor Destroy; override;
    constructor Make(Doc: TWorkDoc; const V: TProjector; U: TUnitSystem;
      AFont: TFont; const LabelCol: TPix; EdgeW: Single;
      SrcW, SrcH: Integer; const Suggest: string; DirFor: TDirFor; DirKeep: TDirKeep); reintroduce;
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
    ('PNG', 'JPEG', 'GIF', 'SVG', 'DXF view', 'DXF model', 'STL', 'OpenSCAD');
  KIND_EXT: array[TExportKind] of string =
    ('.png', '.jpg', '.gif', '.svg', '.dxf', '.dxf', '.stl', '.scad');
  KIND_BLURB: array[TExportKind] of string =
    ('A picture, with the paper behind it or nothing at all.',
     'A picture, smaller and slightly softened.  No transparency.',
     'A little film of a move you record yourself.',
     'The lines of this view, as vectors, for a drawing program.',
     'This view, flat, as entities somebody can measure in their own CAD.',
     'The model itself, in three dimensions, faces and all.',
     'Triangles in millimetres, which is what a 3D printer wants.',
     'A polyhedron per solid, to cut and union in OpenSCAD.');

{ ------------------------------------------------------------------------ }

destructor TExportDlg.Destroy;
begin
  FPrevS.Free;
  inherited Destroy;
end;

constructor TExportDlg.Make(Doc: TWorkDoc; const V: TProjector;
  U: TUnitSystem; AFont: TFont; const LabelCol: TPix; EdgeW: Single;
  SrcW, SrcH: Integer; const Suggest: string;
  DirFor: TDirFor; DirKeep: TDirKeep);
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
  FKind := exPng;
  FWrote := False;
  FStem := Suggest;
  FDirFor := DirFor;
  FDirKeep := DirKeep;
  BuildChrome;
  FPath.Text := PathFor(FKind);
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

  { A paragraph rather than a caption.  The drawn label centres one line and
    lets it run off both ends - which is how the STL note lost its first
    letter and its last - so anything that is a sentence gets a plain label
    that wraps inside the width it was given. }
  function MkPara(Parent: TWinControl; const Cap: string;
    L, T, W, H: Integer): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := Parent;
    Result.SetBounds(L, T, W, H);
    Result.Caption := Cap;
    Result.AutoSize := False;
    Result.WordWrap := True;
    Result.Transparent := True;
    Result.Font.Height := -12;
    Result.Font.Color := uSurface.PixToColor(uDlgSkin.DlgTheme.TextDim);
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

  FHint := MkPara(Mid, 'Middle-drag turns it, right-drag slides it, wheel '
    + 'zooms - the same as the drawing.  This is the shot.',
    10, 412, 420, 34);

  { --- what this format needs to be asked, on the right ------------- }
  Opt := TBCPanel.Create(Self);
  Opt.Parent := Self;
  Opt.SetBounds(608, 56, 260, 452);
  uDlgSkin.SkinPanel(Opt, False, 12);

  FOptTitle := MkLbl(Opt, 'PNG', 14, 12, 232, False, True, -17);
  FNoteLbl := MkPara(Opt, '', 14, 38, 232, 52);

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

  { The film is whatever was recorded, and nothing else.  There used to be a
    pair of views here with a full turn between them, and a seconds box and a
    frame rate box to describe it with - a way of saying what a move should
    be without making one.  The recording room says it better, so the two
    ends and the boxes are gone: record a move, then this plays it back. }
  FLoopOn := True;
  FLoop := MkBtn(Opt, '', 14, 212, 232, 26, bkPlain);
  FLoop.Tag := 2;
  FLoop.OnClick := @Ticked;
  ShowTick(FLoop, True, 'Go round for ever');

  FRec := MkBtn(Opt, 'Record a move...', 14, 248, 232, 32, bkGo);
  FRec.OnClick := @DoRecord;

  FPlay := MkBtn(Opt, 'Play it', 14, 314, 232, 30, bkPlain);
  FPlay.OnClick := @DoPlay;

  FMidOn := True;
  FMid := MkBtn(Opt, '', 14, 116, 232, 26, bkPlain);
  FMid.Tag := 4;
  FMid.OnClick := @Ticked;
  ShowTick(FMid, True, 'Centre it on the origin');

  FAxesOn := True;
  FAxes := MkBtn(Opt, '', 14, 180, 232, 26, bkPlain);
  FAxes.Tag := 3;
  FAxes.OnClick := @Ticked;
  ShowTick(FAxes, True, 'Show the axes');

  FClipLbl := MkPara(Opt, '', 14, 286, 232, 24);
  FShotLbl := MkPara(Opt, '', 14, 398, 232, 46);

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

  FSaveLbl := MkLbl(Foot, 'Save it as', 14, 10, 120, True, False, -12);
  FPath := TEdit.Create(Self);
  FPath.Parent := Foot;
  FPath.SetBounds(14, 32, 560, 28);
  uDlgSkin.SkinEdit(FPath);

  FTellBad := MkPara(Foot, '', 14, 2, 700, 34);
  FTellBad.Visible := False;
  FSay := MkBtn(Foot, 'Send a bug report about this', 584, 4, 268, 22, bkPlain);
  FSay.OnClick := @DoSay;
  FSay.Visible := False;

  FBrowse := MkBtn(Foot, 'Choose...', 584, 32, 96, 28, bkPlain);
  FBrowse.OnClick := @DoBrowse;
  FCancel := MkBtn(Foot, 'Cancel', 690, 32, 76, 28, bkPlain);
  FCancel.OnClick := @DoCancel;
  { and the window manager's own close, which does not go through a button }
  OnCloseQuery := @AskClose;
  FGo := MkBtn(Foot, 'Export', 776, 32, 76, 28, bkGo);
  FGo.OnClick := @DoGo;

  { The bar sits where the path is, because while an export is running the
    path is settled and what somebody wants to know is how much longer. }
  FBar := TPaintBox.Create(Self);
  FBar.Parent := Foot;
  FBar.SetBounds(14, 10, 560, 52);
  FBar.OnPaint := @BarPaint;
  FBar.Visible := False;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 40;
  FTimer.Enabled := False;
  FTimer.OnTimer := @Tick;
end;

{ What the export is up to, drawn rather than guessed at.  A twelve second
  film is three hundred drawings of the model, which is a real wait on a
  drawing of any size - and a window that stops answering for that long is a
  window somebody force-quits. }
procedure TExportDlg.BarPaint(Sender: TObject);
var
  C: TCanvas;
  T: TTheme;
  W, Y: Integer;
begin
  C := FBar.Canvas;
  T := uDlgSkin.DlgTheme;
  C.Brush.Color := uSurface.PixToColor(T.Panel);
  C.Brush.Style := bsSolid;
  C.FillRect(0, 0, FBar.Width, FBar.Height);

  Y := 30;
  C.Brush.Color := uDlgSkin.Shade(uSurface.PixToColor(T.Panel), -0.30);
  C.FillRect(0, Y, FBar.Width, Y + 10);
  if FTotal > 0 then
  begin
    W := Round(FBar.Width * EnsureRange(FDone / FTotal, 0, 1));
    C.Brush.Color := uSurface.PixToColor(T.Accent);
    C.FillRect(0, Y, W, Y + 10);
  end;
  C.Brush.Style := bsClear;

  C.Font.Height := -13;
  C.Font.Style := [];
  C.Font.Color := uSurface.PixToColor(T.Text);
  C.TextOut(0, 6, FDoing);
end;

{ Everything that says an export is running: the cursor, the bar, and the
  buttons that must not be pressed twice while one is. }
procedure TExportDlg.Working(On_: Boolean);
begin
  FBusy := On_;
  FBar.Visible := On_;
  FPath.Visible := not On_;
  FSaveLbl.Visible := not On_;
  FBrowse.Enabled := not On_;
  FGo.Enabled := not On_;
  { Cancel and the close cross go with them.  Letting the queue drain between
    frames is what makes the bar move, and it also means a click can arrive
    while the export is still running - and closing this window out from
    under the code writing the file is a crash, not a cancel.  Stopping it
    part way through would leave half a GIF anyway. }
  FCancel.Enabled := not On_;
  FShut.Enabled := not On_;
  if On_ then Screen.Cursor := crHourGlass else Screen.Cursor := crDefault;
  if On_ then
  begin
    FDone := 0;
    FTotal := 0;
    FDoing := 'Working...';
  end;
  FBar.Invalidate;
  Application.ProcessMessages;
end;

procedure TExportDlg.FilmStep(Done, Total: Integer; const What: string);
begin
  FDone := Done;
  FTotal := Total;
  FDoing := What;
  FBar.Invalidate;
  { So it actually paints.  The export runs on the same thread as the window,
    which is what made the program look hung; letting the queue drain between
    frames is what turns that into a bar that moves. }
  Application.ProcessMessages;
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
  { the name follows, the folder does not: an STL belongs wherever the last
    STL went, not wherever the last PNG went }
  FPath.Text := PathFor(FKind);
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

  FLoop.Visible := Anim;
  FPlay.Visible := Anim and (Length(FCam) >= 2);
  FShotLbl.Visible := Raster;
  if Anim then
  begin
    if Length(FCam) >= 2 then
      FClipLbl.Caption := Format('%.1f seconds recorded.',
        [CamPathLength(FCam)])
    else
      FClipLbl.Caption := 'Nothing recorded yet.';
  end;
  FClipLbl.Visible := Anim;
  FAxes.Visible := Raster;
  FRec.Visible := Anim;
  FDxfWhat.Visible := FKind in [exDxfView, exDxfModel];
  FMid.Visible := FKind in [exStl, exScad];

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
      if Length(FCam) >= 2 then
        Secs := Max(0.2, Min(GIF_MAX_SECONDS, CamPathLength(FCam)))
      else
        Secs := 0;
      FilmPlan(Secs, GIF_FPS, W, H, NF, Rate);
      { A big picture buys fewer frames - the whole film has to be held in
        memory at once - so say so here rather than let somebody wait for it
        and wonder why it came out jerky. }
      { say what it will weigh, because that is the question behind the size
        and nobody should have to export one to find out }
      if Secs <= 0 then
        FShotLbl.Caption := Format('%d x %d - record a move first', [W, H])
      else if Rate < GIF_FPS then
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
    4: begin
         FMidOn := not FMidOn;
         ShowTick(FMid, FMidOn, 'Centre it on the origin');
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

function TExportDlg.PathFor(K: TExportKind): string;
var
  Dir, Name_: string;
begin
  Name_ := '';
  if Assigned(FPath) then
    Name_ := ExtractFileName(Trim(FPath.Text));
  if Name_ = '' then Name_ := FStem;
  Name_ := ChangeFileExt(Name_, '');
  if Name_ = '' then Name_ := FStem;

  Dir := '';
  if Assigned(FDirFor) then Dir := FDirFor(KIND_EXT[K]);
  if Dir = '' then Result := Name_ + KIND_EXT[K]
  else Result := IncludeTrailingPathDelimiter(Dir) + Name_ + KIND_EXT[K];
end;

{ Where the camera is, T seconds into the recording. }
function TExportDlg.Tween(T: Double): TProjector;
begin
  Result := SampleCamPath(FCam, T);
end;

procedure TExportDlg.PrevPaint(Sender: TObject);
var
  S: TArtSurface;
  V: TProjector;
  Bg: TPix;
begin
  { Playing means playing the recording.  With nothing recorded there is
    nothing to play and the preview is simply the shot, held still - it never
    wanders off round the model on its own. }
  if FPlaying and (Length(FCam) >= 2) then V := Tween(FPlayT) else V := FView;
  if (FKind = exPng) and FTranspOn then Bg := Pix(255, 255, 255, 0)
  else Bg := Pix(255, 255, 255);
  { One surface, kept, rather than a new one every repaint.  While a clip is
    playing this runs twenty-five times a second, and building and throwing
    away a picture the size of the preview that often is work the machine can
    feel. }
  if (FPrevS <> nil) and ((FPrevS.Width <> FPrev.Width) or
     (FPrevS.Height <> FPrev.Height)) then FreeAndNil(FPrevS);
  if FPrevS = nil then
    FPrevS := TArtSurface.Create(Max(1, FPrev.Width), Max(1, FPrev.Height));
  S := FPrevS;
  ShootInto(S, FDoc, Fitted(V, FSrcW, FSrcH, FPrev.Width, FPrev.Height),
    FUnits, FFont, FLabelCol, FEdgeW, Bg, FDragging or FPlaying);
  FPrev.Canvas.Draw(0, 0, S.AsBitmap);
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
  T, Len: Double;
begin
  Len := CamPathLength(FCam);
  if Len <= 0 then
  begin
    FPlaying := False;
    FTimer.Enabled := False;
    Exit;
  end;
  { the clock runs in seconds of the recording, so what plays here runs at
    the speed it was made at }
  T := FPlayT + FTimer.Interval / 1000;   { a local first - see OrbitBy }
  FPlayT := T;
  if FPlayT > Len then FPlayT := 0;
  FPrev.Invalidate;
end;

procedure TExportDlg.DoPlay(Sender: TObject);
begin
  if Length(FCam) < 2 then Exit;
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
    'gif=%d a second, loop=%s, recorded=%.1fs, axes=%s' + LineEnding +
    'what it said: %s' + LineEnding +
    'path=%s',
    [KIND_NAME[FKind], FStage, W, H, FSrcW, FSrcH, FSize.ItemIndex,
     GIF_FPS, BoolToStr(FLoopOn, 'yes', 'no'),
     CamPathLength(FCam), BoolToStr(FAxesOn, 'yes', 'no'),
     FMsg, ExtractFileName(FPath.Text)]);
  ModalResult := mrCancel;
  { the report wants a picture of the screen and this window is in front of
    it, so it goes first and the main window raises the report }
  FOnReport('the export dialog', Fields);
end;

{ Nothing closes this window while it is writing a file. }
procedure TExportDlg.AskClose(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := not FBusy;
end;

procedure TExportDlg.DoCancel(Sender: TObject);
begin
  { belt as well as braces: the buttons are disabled while an export runs,
    and Escape does not close it either }
  if FBusy then Exit;
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
         FSrcW, FSrcH, FAxesOn, FPivot, Got) then
    begin
      FCam := Got;
      FPlayT := 0;
      FHint.Caption := Format('Recorded %.1f seconds.  That is the shot now - ' +
        'press Play it to watch, or Record again to do it over.',
        [CamPathLength(FCam)]);
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
    D.InitialDir := ExtractFileDir(FPath.Text);
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
  uShoot.OnFilmStep := @FilmStep;
  Working(True);
  try
    try
      WriteIt;
      FWrote := True;
      { and that is where this kind of file goes from now on }
      if Assigned(FDirKeep) then
        FDirKeep(Ext, ExtractFileDir(ChangeFileExt(Trim(FPath.Text), Ext)));
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
  finally
    { Down before the window is asked to close, and not after: nothing shuts
      this while it is working, so saying it is done has to come first. }
    Working(False);
    uShoot.OnFilmStage := nil;
    uShoot.OnFilmStep := nil;
  end;
  if FWrote then ModalResult := mrOk;
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
  { A folder somebody typed or browsed to may not be there yet - and a
    portable program's own exports folder will not be, the first time. }
  if ExtractFileDir(Fn) <> '' then
    ForceDirectories(ExtractFileDir(Fn));
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

    exScad:
      begin
        FStage := 'writing the OpenSCAD script';
        L := TStringList.Create;
        try
          N := FDoc.WriteSCAD(L, FUnits, NTri, FMidOn);
          L.SaveToFile(Fn);
        finally
          L.Free;
        end;
        if N = 0 then
          FMsg := 'Nothing to describe - an OpenSCAD shape is made of faces, ' +
            'and this drawing has none.'
        else
          FMsg := Format('%d triangles in %d %s, in millimetres.',
            [N, NTri, specialize IfThen<string>(NTri = 1, 'piece', 'pieces')]);
      end;

    exStl:
      begin
        FStage := 'writing the STL';
        FS := TFileStream.Create(Fn, fmCreate);
        try
          NTri := FDoc.WriteSTL(FS, FUnits, Shut, FMidOn);
        finally
          FS.Free;
        end;
        if NTri = 0 then
          FMsg := 'Nothing to print - an STL is made of faces, and this ' +
            'drawing has none.'
        else if not Shut then
          FMsg := Format('%d triangles, in millimetres - but this is not a ' +
            'closed solid, so a slicer will have to guess at the inside.  ' +
            'Type /holes on the drawing to see where.',
            [NTri])
        else
          FMsg := Format('%d triangles, in millimetres, closed and ready to ' +
            'slice.', [NTri]);
      end;

    exGif:
      begin
        FStage := 'working out the size';
        if Length(FCam) < 2 then
          raise Exception.Create('there is no clip yet - press Record a move');
        if not OutSize(W, H) then raise Exception.Create('that size will not do');
        FStage := Format('drawing the frames at %dx%d', [W, H]);
        N := SavePathGif(FDoc, FCam, FSrcW, FSrcH, W, H, FUnits, FFont,
          FLabelCol, FEdgeW, GIF_FPS, FLoopOn, FAxesOn, Fn);
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
  const Suggest: string; const T: TTheme; const Pivot: TP3;
  OnReport: TReportProc; DirFor: TDirFor; DirKeep: TDirKeep;
  out Msg: string): Boolean;
var
  Dlg: TExportDlg;
begin
  uDlgSkin.UseTheme(T);
  Dlg := TExportDlg.Make(Doc, V, U, AFont, LabelCol, EdgeW, SrcW, SrcH,
    Suggest, DirFor, DirKeep);
  Dlg.FOnReport := OnReport;
  Dlg.FPivot := Pivot;
  try
    Dlg.ShowModal;
    Result := Dlg.FWrote;
    Msg := Dlg.FMsg;
  finally
    Dlg.Free;
  end;
end;

end.
