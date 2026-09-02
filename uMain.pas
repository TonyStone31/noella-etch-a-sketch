unit uMain;

{
  Heckers Sketch - an Etch A Sketch that grew up.

  19 October 2021.  Noella Hazel Stone, age 7, decided she wanted to write a
  program.  She drew the screen, the two dials and the shake button on paper,
  picked the colours, and told her dad what each part had to do.  He typed
  while she directed.

  2026.  Same program, two personalities:

    TOY  - the original.  Two dials, five kinds of pen, a kaleidoscope, and a
           shake that dissolves the drawing into aluminium powder.

    PRO  - a small drawing board for quick, honest sketches.  Pick a scale,
           put the cursor on a point, and draw by typing: 12'6" and Enter.
           It is not a CAD program and does not want to be.  It exists so you
           can rough out two things and get a real measurement between them,
           down to the sixteenth of an inch.

  The command bar under the screen always says what it wants next, so there
  is nothing to memorise.

  Copyright (c) 2021-2026 Noella Stone

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to
  deal in the Software without restriction, including without limitation the
  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
  sell copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
  IN THE SOFTWARE.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Math, StrUtils, IniFiles, Forms, Controls, Graphics,
  Dialogs, ExtCtrls, StdCtrls, LCLType, LCLIntf, Printers, PrintersDlgs,
  uSurface, uSkin, uWork;

type
  TAppMode = (mdToy, mdPro);

  TProTool = (ptSelect, ptLine, ptArc, ptCircle, ptPush, ptText, ptErase, ptMeasure);

  TPenStyle = (psClassic, psNeon, psRainbow, psSparkle, psChalk);

  { One pro-mode sheet.  Everything that belongs to a drawing rather than to
    the program lives here, so tabs are just a list of these. }
  TDrawing = class
    Doc: TWorkDoc;
    Name: string;
    ViewX, ViewY: Double;      // screen position of world 0,0
    Zoom: Double;              // magnification; the print scale is ScaleIdx
                               // and is deliberately unaffected by it
    ScaleIdx: Integer;
    SnapIdx: Integer;
    Units: TUnitSystem;
    ShowDims: Boolean;
    View: TViewKind;        // PLAN, ISO or free 3D
    Plane: TPlane;          // which plane new arcs and mouse picks land on
    Az, El: Double;         // 3D camera, radians
    Undo, Redo: array of TWorkEntArray;
    UndoTop, RedoTop: Integer;
    constructor Create(const AName: string);
    destructor Destroy; override;
  end;

  TDeckKind = (dkNone, dkSegment, dkSwatch, dkIcon, dkSlider);

  TDeckItem = record
    Kind: TDeckKind;
    Bounds: TRect;
    Group: Integer;
    Value: Integer;
    Caption: string;
    Hint: string;
    Icon: TIconKind;
    Swatch: TPix;
  end;

  { TMainForm }

  TMainForm = class(TForm)
    dlgColor: TColorDialog;
    dlgPrint: TPrintDialog;
    dlgOpen: TOpenDialog;
    dlgSave: TSaveDialog;
    pbCmd: TPaintBox;
    pbTabs: TPaintBox;
    pbView: TPaintBox;
    pbDeck: TPaintBox;
    pbKnobL: TPaintBox;
    pbKnobR: TPaintBox;
    pbMode: TPaintBox;
    pbScreen: TPaintBox;
    tmrTick: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure FormKeyPress(Sender: TObject; var Key: char);
    procedure FormKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure FormPaint(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure pbCmdPaint(Sender: TObject);
    procedure pbTabsMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pbTabsMouseLeave(Sender: TObject);
    procedure pbTabsMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbTabsPaint(Sender: TObject);
    procedure pbViewMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pbViewMouseLeave(Sender: TObject);
    procedure pbViewMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbViewPaint(Sender: TObject);
    procedure pbDeckMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pbDeckMouseLeave(Sender: TObject);
    procedure pbDeckMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbDeckMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pbDeckPaint(Sender: TObject);
    procedure pbKnobMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pbKnobMouseLeave(Sender: TObject);
    procedure pbKnobMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbKnobMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pbKnobMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure pbKnobPaint(Sender: TObject);
    procedure pbModeMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pbModeMouseLeave(Sender: TObject);
    procedure pbModeMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbModePaint(Sender: TObject);
    procedure pbScreenMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pbScreenMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbScreenMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pbScreenMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure pbScreenPaint(Sender: TObject);
    procedure tmrTickTimer(Sender: TObject);
  private
    { --- surfaces ------------------------------------------------------- }
    FPaper: TArtSurface;         // paper, grain, grid
    FInkToy: TArtSurface;        // toy ink, keeps its own alpha
    FInkPro: TArtSurface;        // pro ink, rendered from the document
    FArt: TArtSurface;           // paper + active ink; what you see and save
    FShell: TArtSurface;
    FDeckSkin: TArtSurface;
    FModeSkin: TArtSurface;
    FCmdSkin: TArtSurface;
    FKnobSkin: array[0..1] of TArtSurface;
    FOverlay: TArtSurface;

    { --- shared --------------------------------------------------------- }
    FMode: TAppMode;
    FUIScale: Single;
    FThemeIdx: Integer;
    FPenSize: Integer;
    FInkColor: TColor;
    FInkPix: TPix;
    FInkAuto: Boolean;
    FShowGrid: Boolean;
    FBooted: Boolean;
    FHint: string;
    FLastStatus: QWord;

    { --- toy ------------------------------------------------------------ }
    FPenX, FPenY: Single;
    FStyle: TPenStyle;
    FHue: Single;
    FSym: Integer;
    FMirror: Boolean;
    FAuto: Boolean;
    FAutoT: Single;
    FAutoKind: Integer;
    FAutoP: array[0..4] of Single;

    { --- pro ------------------------------------------------------------ }
    FDrawings: array of TDrawing;
    FTabIdx: Integer;
    FD: TDrawing;                // the sheet on the active tab
    FTool: TProTool;
    FProDials: Boolean;          // the dials are optional over here
    FTabRects: array of TRect;
    FHotTab: Integer;
    FCur: TP3;                   // snapped cursor, world units
    FSnapKind: TSnapKind;
    FStage: Integer;             // where we are in the current tool
    FP1, FP2: TP3;
    FDirLock: Integer;           // -1 none, else an index into AxisDir
    FInput: string;              // what has been typed into the command bar
    FCmdMsg: string;             // last result / error shown in the bar
    FDimFont: TFont;

    { --- input ---------------------------------------------------------- }
    FKeyLeft, FKeyRight, FKeyUp, FKeyDown: Boolean;
    FBoost, FPrecise, FPenUp: Boolean;
    FDragKnob: Integer;
    FDragAngle: Single;
    FKnobAngle: array[0..1] of Single;
    FHotKnob: Integer;
    FFreehand: Boolean;
    FPanning: Boolean;
    FOrbiting: Boolean;
    FPushFace: Integer;
    FPanRefX, FPanRefY: Integer;
    FMouseSX, FMouseSY: Integer;   // raw pointer, before snapping

    { Motion is recorded here and nowhere else.  Under a virtual display
      every repaint has to be encoded and shipped to the client, so a
      handler that painted would cost tens of milliseconds - and GDK
      coalesces motion until the handler returns, which throttled the
      event stream down to a trickle.  The work now happens once per
      tick instead, off the back of the newest position. }
    FMoveX, FMoveY: Integer;
    FMovePending: Boolean;
    FScreenDirty: Boolean;
    FHotMode: Integer;
    FHotView: Integer;
    FViewSkin: TArtSurface;
    FHoverEnt: Integer;          // what the eraser is about to delete
    FDocPath: string;            // where this set of sheets came from
    FGuide: Boolean;             // an alignment guide is active
    FGuideFrom: TP3;

    { --- deck ----------------------------------------------------------- }
    FDeck: array of TDeckItem;
    FHotItem: Integer;
    FSliderGrab: Boolean;

    { --- history -------------------------------------------------------- }
    FUndoToy, FRedoToy: array of TBytes;
    FUndoToyTop, FRedoToyTop: Integer;
    FStrokeOpen: Boolean;

    { --- erase animation ------------------------------------------------ }
    FErasing: Boolean;
    FEraseT: Single;
    FJitterX, FJitterY: Integer;

    { helpers }
    function Theme: TTheme;
    function ActiveInk: TArtSurface;
    function Ppu: Double;
    function CurScale: TDrawScale;
    function SnapStep: Double;
    function Proj: TProjector;
    function ScreenOf(const P: TP3): TPointF;
    function WorldAt(SX, SY: Double): TP3;
    function SnapToGrid(const P: TP3): TP3;
    function ResolveSnapAt(SX, SY: Double): TP3;
    function AnnotColor: TPix;
    function DialsVisible: Boolean;

    procedure Relayout;
    procedure RebuildShell;
    procedure RebuildDeck;
    procedure RebuildKnobs;
    procedure RefreshChrome;
    procedure ResizeSurfaces(AW, AH: Integer);
    procedure RepaintPaper;
    procedure Recompose;
    procedure RecomposeAll;
    procedure FreshScreen;
    procedure RenderPro;
    procedure InvalidateStatus;
    procedure ServiceMotion;

    procedure UIFont(C: TCanvas; Size: Integer; Bold: Boolean; const Col: TPix;
      Mono: Boolean = False);
    procedure TrackedText(C: TCanvas; X, Y: Integer; const S: string; Tracking: Integer);

    { history }
    procedure BeginStroke;
    procedure EndStroke;
    procedure PushUndo;
    procedure DoUndo;
    procedure DoRedo;
    function CanUndo: Boolean;
    function CanRedo: Boolean;
    procedure ClearHistory;

    { toy }
    procedure StampSegment(X0, Y0, X1, Y1: Single);
    procedure EmitSegment(X0, Y0, X1, Y1: Single);
    procedure PenTo(NX, NY: Single; Drawing: Boolean);
    procedure ToggleAuto;
    procedure StepAuto(Dt: Single);

    { pro }
    function ToolName(T: TProTool): string;
    function Prompt: string;
    function PreviewTarget: TP3;
    procedure SetTool(T: TProTool);
    procedure ResetTool;
    procedure ProClick;
    procedure ProCommit;
    procedure CommandEnter;
    function RunCommand(const S: string): Boolean;
    procedure NudgeCursor(DX, DY: Double);
    procedure JumpSnap(DX, DY: Integer);
    function SnapLabel: string;
    procedure SetOriginHere;
    procedure ZoomAt(Factor: Double; AnchorSX, AnchorSY: Double);
    procedure SetScaleIdx(I: Integer);
    procedure PanBy(DX, DY: Double);
    procedure FitView;
    procedure NewDrawing;
    procedure CloseDrawing(I: Integer);
    procedure SelectDrawing(I: Integer);
    procedure LayoutTabs;

    { commands }
    procedure StartErase;
    procedure StepErase(Dt: Single);
    procedure DoSave;
    procedure DoSaveAs;
    procedure DoOpen;
    function LoadDocument(const FileName: string): Boolean;
    procedure DoExport;
    procedure DoPrint;
    procedure DoPickColor;
    procedure CycleTheme(Step: Integer);
    procedure SetMode(M: TAppMode);
    procedure SetPenSize(V: Integer);
    procedure SetStyle(V: TPenStyle);
    procedure SetInk(C: TColor; Auto: Boolean = False);
    procedure SetSymmetry(V: Integer);
    procedure SetUnits(U: TUnitSystem);
    procedure SetView(V: TViewKind);

    { deck }
    function DeckHit(X, Y: Integer): Integer;
    procedure DeckActivate(Index: Integer);
    function IconLit(Value: Integer): Boolean;
    function IconEnabled(Value: Integer): Boolean;
    function SliderValueAt(const Item: TDeckItem; X: Integer): Integer;
    function IndexOfSym(V: Integer): Integer;
    function InPalette(C: TColor): Boolean;

    function StatusLine: string;
    procedure PaintProOverlay(C: TCanvas);

    procedure LoadSettings;
    procedure SaveSettings;
    procedure ShowAbout;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

function SketchAppName: string;
begin
  Result := 'heckers-sketch';
end;

const
  APP_NAME = 'Heckers Sketch';

  { deck groups }
  GRP_STYLE = 0;
  GRP_SYM   = 1;
  GRP_INK   = 2;
  GRP_ICON  = 3;
  GRP_SIZE  = 4;
  GRP_SCALE = 5;
  GRP_SNAP  = 6;
  GRP_TOOL  = 7;

  { icon actions }
  ACT_UNDO    = 0;
  ACT_REDO    = 1;
  ACT_SHAKE   = 2;
  ACT_SAVE    = 3;
  ACT_PRINT   = 4;
  ACT_AUTO    = 5;
  ACT_THEME   = 6;
  ACT_GRID    = 7;
  ACT_HELP    = 8;
  ACT_MIRROR  = 9;
  ACT_PICK    = 10;
  ACT_UNITS   = 11;
  ACT_DIM     = 12;
  ACT_ORIGIN  = 13;
  ACT_FIT     = 14;
  ACT_OPEN    = 15;
  ACT_EXPORT  = 16;

  UNDO_LEVELS     = 16;
  KNOB_PX_PER_RAD = 58.0;
  BASE_SPEED      = 210.0;
  TICK_MS         = 16;
  MIN_PEN         = 1;
  MAX_PEN         = 40;
  SNAP_PX         = 12.0;   // pulling onto a point on the drawing
  INFER_PX        = 7.0;    // lining up with one that is somewhere else
  PRINT_DPI       = 150;

  SYM_VALUES: array[0..4] of Integer = (1, 2, 4, 6, 8);

  STYLE_NAMES: array[TPenStyle] of string =
    ('CLASSIC', 'NEON', 'RAINBOW', 'SPARKLE', 'CHALK');

  STYLE_HINTS: array[TPenStyle] of string = (
    'Classic - a clean, solid line, just like the real toy.',
    'Neon - a glowing tube of light.  Try it on the Midnight theme.',
    'Rainbow - the colour drifts through the spectrum as you draw.',
    'Sparkle - a thin trail that throws off glitter.',
    'Chalk - a soft, dusty, hand-drawn stroke.');

  TOOL_NAMES: array[TProTool] of string =
    ('POINT', 'LINE', 'ARC', 'CIRCLE', 'PUSH/PULL', 'TEXT', 'ERASE', 'MEASURE');

  TOOL_HINTS: array[TProTool] of string = (
    'Point - move the cursor around and read where it is.  Nothing gets drawn.',
    'Line - click a start point, then click the end or just type a length.',
    'Arc - pick two points, then pull the middle out.  Joins two loose ends.',
    'Circle - pick the centre, then type or drag the radius.',
    'Push/pull - click a face and type how far to lift it.  Close a loop of ' +
      'lines to make a face.',
    'Text - click where the note goes and type it.',
    'Erase - click anything to delete it.',
    'Measure - click two points and read the distance between them.');

  TOY_HINT = 'Arrow keys or the dials draw.  Shift to go fast, Ctrl to creep.';

  { TColor is $00BBGGRR }
  PALETTE: array[0..11] of TColor = (
    $1A1A1A, $FFFFFF, $A8A4A0, $2A2AE2, $1A7AFF, $1AC6FF,
    $3CDC7A, $5AB422, $C8C81E, $F06034, $EB5096, $AA3CEB);

{ ======================================================================== }
{ small helpers                                                             }
{ ======================================================================== }

function TMainForm.Theme: TTheme;
begin
  Result := Themes[FThemeIdx];
end;

function TMainForm.ActiveInk: TArtSurface;
begin
  if FMode = mdPro then Result := FInkPro else Result := FInkToy;
end;

function TMainForm.CurScale: TDrawScale;
begin
  Result := ScaleTable(FD.Units, FD.ScaleIdx);
end;

{ Pixels per world unit on screen.  The drawing scale sets the true size;
  FD.Zoom is only ever a magnifying glass over it, so what prints does not
  change when you zoom in to place something. }
function TMainForm.Ppu: Double;
begin
  Result := PixelsPerUnit(FD.Units, CurScale, Screen.PixelsPerInch) * FD.Zoom;
end;

function TMainForm.SnapStep: Double;
begin
  Result := SnapValue(FD.Units, FD.SnapIdx);
end;

function TMainForm.Proj: TProjector;
begin
  Result.Kind := FD.View;
  Result.Ppu := Ppu;
  Result.OX := FD.ViewX;
  Result.OY := FD.ViewY;
  Result.Az := FD.Az;
  Result.El := FD.El;
end;

function TMainForm.ScreenOf(const P: TP3): TPointF;
begin
  Result := Project(Proj, P);
end;

function TMainForm.WorldAt(SX, SY: Double): TP3;
begin
  Result := Unproject(Proj, SX, SY, FD.Plane, FCur);
end;

function TMainForm.SnapToGrid(const P: TP3): TP3;
var
  S: Double;
begin
  S := SnapStep;
  if S <= 0 then
    Result := P
  else
    Result := P3(Round(P.X / S) * S, Round(P.Y / S) * S, Round(P.Z / S) * S);
end;

{ Points on the drawing beat the grid, the way they do in SketchUp.  Failing
  a direct hit, the cursor is pulled onto line with any point that shares one
  of its coordinates, and a guide is shown back to whatever it lined up with. }
function TMainForm.ResolveSnapAt(SX, SY: Double): TP3;
var
  Hit: TSnapHit;
  Pts: TP3Array;
  I, BestAxis: Integer;
  Tol, D, Best: Double;
  W: TP3;

  { An alignment is only worth showing when the point is off in exactly one
    direction - then the guide is a clean line parallel to an axis.  If it
    differs in two directions the guide would be a meaningless diagonal, and
    in plan every point shares Z, which is what used to drag the guide back
    to the first corner of the drawing every time. }
  procedure Consider(const C: TP3);
  var
    DX, DY, DZ, Score: Double;
    Big: Integer;
  begin
    DX := Abs(W.X - C.X);
    DY := Abs(W.Y - C.Y);
    DZ := Abs(W.Z - C.Z);

    Big := 0;
    if DX > Tol then Inc(Big);
    if DY > Tol then Inc(Big);
    if DZ > Tol then Inc(Big);
    if Big <> 1 then Exit;

    { and only when it is far enough away to be a visible guide }
    if Dist(W, C) * Ppu < 18 then Exit;

    Score := DX + DY + DZ;
    if DX > Tol then Score := Score - DX
    else if DY > Tol then Score := Score - DY
    else Score := Score - DZ;

    if Score < Best then
    begin
      Best := Score;
      BestAxis := 1;          // marks "found"; the axes are snapped below
      FGuideFrom := C;
    end;
  end;

begin
  FGuide := False;

  { SNAP OFF means off: no grid, no points, no guides.  Holding Alt suspends
    all of it for one move, which is the usual way out of a sticky snap. }
  if (SnapStep <= 0) or FPenUp then
  begin
    FSnapKind := snNone;
    Exit(WorldAt(SX, SY));
  end;

  if FD.Doc.BestSnap(Proj, SX, SY, SNAP_PX, Hit) then
  begin
    FSnapKind := Hit.Kind;
    Exit(Hit.P);
  end;

  W := SnapToGrid(WorldAt(SX, SY));
  FSnapKind := snGrid;

  { A locked direction is already a constraint; inferring another one on top
    of it is what made the cursor feel glued to the start point. }
  if FDirLock >= 0 then
    Exit(W);

  Tol := INFER_PX / Max(1E-9, Ppu);
  Best := 1E30;
  BestAxis := -1;
  FD.Doc.SnapPoints(Pts);
  for I := 0 to High(Pts) do
    Consider(Pts[I]);
  if FStage > 0 then
    Consider(FP1);

  if BestAxis >= 0 then
  begin
    { pull the matching axes onto the point; the odd one out is the guide }
    if Abs(W.X - FGuideFrom.X) <= Tol then W.X := FGuideFrom.X;
    if Abs(W.Y - FGuideFrom.Y) <= Tol then W.Y := FGuideFrom.Y;
    if Abs(W.Z - FGuideFrom.Z) <= Tol then W.Z := FGuideFrom.Z;
    FGuide := True;
  end;

  Result := W;
end;

function TMainForm.AnnotColor: TPix;
begin
  if Theme.DarkScreen then
    Result := Pix($C8, $D4, $E4)
  else
    Result := Pix($44, $48, $52);
end;

function TMainForm.DialsVisible: Boolean;
begin
  { the dials belong to the toy; over in pro they were never precise enough
    to be worth the space }
  Result := FMode = mdToy;
end;

procedure TMainForm.UIFont(C: TCanvas; Size: Integer; Bold: Boolean;
  const Col: TPix; Mono: Boolean);
begin
  {$IFDEF WINDOWS}
  if Mono then C.Font.Name := 'Consolas' else C.Font.Name := 'Segoe UI';
  {$ELSE}
    {$IFDEF DARWIN}
    if Mono then C.Font.Name := 'Menlo' else C.Font.Name := 'Helvetica Neue';
    {$ELSE}
    if Mono then C.Font.Name := 'Monospace' else C.Font.Name := 'Sans';
    {$ENDIF}
  {$ENDIF}
  C.Font.Height := -Round(Size * FUIScale);
  if Bold then C.Font.Style := [fsBold] else C.Font.Style := [];
  C.Font.Color := PixToColor(Col);
  C.Brush.Style := bsClear;
end;

procedure TMainForm.TrackedText(C: TCanvas; X, Y: Integer; const S: string;
  Tracking: Integer);
var
  I: Integer;
begin
  for I := 1 to Length(S) do
  begin
    C.TextOut(X, Y, S[I]);
    Inc(X, C.TextWidth(S[I]) + Tracking);
  end;
end;

function TMainForm.ToolName(T: TProTool): string;
begin
  Result := TOOL_NAMES[T];
end;

{ ======================================================================== }
{ lifecycle                                                                 }
{ ======================================================================== }

procedure TMainForm.FormCreate(Sender: TObject);
var
  I: Integer;
begin
  Randomize;
  Caption := APP_NAME;
  FUIScale := EnsureRange(Screen.PixelsPerInch / 96, 1.0, 3.0);
  DoubleBuffered := True;

  FPaper := TArtSurface.Create(16, 16);
  FArt := TArtSurface.Create(16, 16);
  FInkToy := TArtSurface.Create(16, 16);
  FInkPro := TArtSurface.Create(16, 16);
  FInkToy.PreserveAlpha := True;
  FInkPro.PreserveAlpha := True;
  FShell := TArtSurface.Create(16, 16);
  FDeckSkin := TArtSurface.Create(16, 16);
  FModeSkin := TArtSurface.Create(16, 16);
  FCmdSkin := TArtSurface.Create(16, 16);
  FViewSkin := TArtSurface.Create(16, 16);
  for I := 0 to 1 do
    FKnobSkin[I] := TArtSurface.Create(16, 16);
  FOverlay := TArtSurface.Create(16, 16);

  NewDrawing;
  FDimFont := TFont.Create;
  {$IFDEF WINDOWS}
  FDimFont.Name := 'Segoe UI';
  {$ELSE}
  FDimFont.Name := 'Sans';
  {$ENDIF}
  FDimFont.Height := -Round(11 * FUIScale);

  FMode := mdToy;
  FThemeIdx := 0;
  FStyle := psClassic;
  FPenSize := 4;
  FSym := 1;
  FHotItem := -1;
  FHotMode := -1;
  FHotView := -1;
  FHoverEnt := -1;
  FDragKnob := -1;
  FHotKnob := -1;
  FProDials := False;
  FTool := ptSelect;
  FDirLock := -1;
  FPushFace := -1;
  FHint := TOY_HINT;

  LoadSettings;
  SetInk(FInkColor, FInkAuto);

  SetLength(FUndoToy, UNDO_LEVELS);
  SetLength(FRedoToy, UNDO_LEVELS);

  dlgSave.Filter := 'PNG image|*.png';
  dlgSave.DefaultExt := '.png';

  pbScreen.Cursor := crCross;
  pbKnobL.Cursor := crHandPoint;
  pbKnobR.Cursor := crHandPoint;
  pbDeck.Cursor := crHandPoint;
  pbMode.Cursor := crHandPoint;

  tmrTick.Interval := TICK_MS;
  tmrTick.Enabled := True;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
var
  I: Integer;
begin
  SaveSettings;
  FDimFont.Free;
  for I := High(FDrawings) downto 0 do
    FDrawings[I].Free;
  FOverlay.Free;
  for I := 0 to 1 do
    FKnobSkin[I].Free;
  FViewSkin.Free;
  FCmdSkin.Free;
  FModeSkin.Free;
  FDeckSkin.Free;
  FShell.Free;
  FInkPro.Free;
  FInkToy.Free;
  FArt.Free;
  FPaper.Free;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  if FBooted then Exit;
  FBooted := True;
  Relayout;
  FD.ViewX := Round(FArt.Width * 0.10);
  FD.ViewY := Round(FArt.Height * 0.88);
  FCur := P3(0, 0, 0);
  LayoutTabs;
  FPenX := FArt.Width / 2;
  FPenY := FArt.Height / 2;
  FreshScreen;

  { heckers-sketch drawing.hsk opens it straight away }
  if (ParamCount >= 1) and FileExists(ParamStr(1)) then
    LoadDocument(ParamStr(1));
end;

{ ======================================================================== }
{ layout                                                                    }
{ ======================================================================== }

procedure TMainForm.Relayout;
var
  M, TitleH, DeckH, Bezel, KnobSz, Gap, ModeW, ModeH, CmdH, TabsH: Integer;
  BezelR, DeckR: TRect;
  DeckL, DeckRt: Integer;
  I: Integer;
begin
  if not FBooted then Exit;

  M := Round(22 * FUIScale);
  TitleH := Round(84 * FUIScale);
  DeckH := Round(172 * FUIScale);
  Bezel := Round(16 * FUIScale);
  Gap := Round(16 * FUIScale);
  ModeW := Round(186 * FUIScale);
  ModeH := Round(32 * FUIScale);
  CmdH := Round(44 * FUIScale);
  TabsH := Round(30 * FUIScale);

  pbMode.SetBounds(ClientWidth - M - ModeW, Round(10 * FUIScale), ModeW, ModeH);

  DeckR := Rect(M, ClientHeight - M - DeckH, ClientWidth - M, ClientHeight - M);

  pbCmd.Visible := FMode = mdPro;
  pbTabs.Visible := FMode = mdPro;
  pbView.Visible := FMode = mdPro;
  if FMode = mdPro then
  begin
    pbView.SetBounds(ClientWidth - M - Round(228 * FUIScale), TitleH,
      Round(228 * FUIScale), TabsH);
    pbTabs.SetBounds(M, TitleH,
      Max(120, pbView.Left - M - Round(16 * FUIScale)), TabsH);
    pbCmd.SetBounds(M, DeckR.Top - Gap - CmdH, ClientWidth - 2 * M, CmdH);
    BezelR := Rect(M, TitleH + TabsH + Round(4 * FUIScale), ClientWidth - M,
      pbCmd.Top - Round(10 * FUIScale));
  end
  else
    BezelR := Rect(M, TitleH, ClientWidth - M, DeckR.Top - Gap);

  KnobSz := Min(Round(136 * FUIScale), DeckH - Round(18 * FUIScale));
  pbKnobL.Visible := DialsVisible;
  pbKnobR.Visible := DialsVisible;

  if DialsVisible then
  begin
    pbKnobL.SetBounds(DeckR.Left + Round(6 * FUIScale),
      DeckR.Top + (DeckH - KnobSz) div 2, KnobSz, KnobSz);
    pbKnobR.SetBounds(DeckR.Right - Round(6 * FUIScale) - KnobSz,
      DeckR.Top + (DeckH - KnobSz) div 2, KnobSz, KnobSz);
    DeckL := pbKnobL.Left + KnobSz + Gap;
    DeckRt := pbKnobR.Left - Gap;
  end
  else
  begin
    DeckL := DeckR.Left;
    DeckRt := DeckR.Right;
  end;

  pbDeck.SetBounds(DeckL, DeckR.Top, Max(120, DeckRt - DeckL), DeckH);

  pbScreen.SetBounds(BezelR.Left + Bezel, BezelR.Top + Bezel,
    Max(32, (BezelR.Right - BezelR.Left) - 2 * Bezel),
    Max(32, (BezelR.Bottom - BezelR.Top) - 2 * Bezel));

  ResizeSurfaces(pbScreen.Width, pbScreen.Height);

  FShell.SetSize(Max(1, ClientWidth), Max(1, ClientHeight));
  RebuildShell;

  FDeckSkin.SetSize(pbDeck.Width, pbDeck.Height);
  RebuildDeck;

  FModeSkin.SetSize(pbMode.Width, pbMode.Height);
  FCmdSkin.SetSize(Max(1, pbCmd.Width), Max(1, pbCmd.Height));
  FViewSkin.SetSize(Max(1, pbView.Width), Max(1, pbView.Height));
  LayoutTabs;

  for I := 0 to 1 do
    FKnobSkin[I].SetSize(KnobSz, KnobSz);
  RebuildKnobs;

  Invalidate;
end;

procedure TMainForm.RebuildShell;
var
  M, TitleH, DeckH, Bezel, Gap, CmdH, TabsH: Integer;
  BezelR: TRect;
begin
  M := Round(22 * FUIScale);
  TitleH := Round(84 * FUIScale);
  DeckH := Round(172 * FUIScale);
  Bezel := Round(16 * FUIScale);
  Gap := Round(16 * FUIScale);
  CmdH := Round(44 * FUIScale);
  TabsH := Round(30 * FUIScale);

  if FMode = mdPro then
    BezelR := Rect(M, TitleH + TabsH + Round(4 * FUIScale), ClientWidth - M,
      ClientHeight - M - DeckH - Gap - CmdH - Round(10 * FUIScale))
  else
    BezelR := Rect(M, TitleH, ClientWidth - M, ClientHeight - M - DeckH - Gap);

  PaintShell(FShell, Theme);
  PaintBezel(FShell, BezelR, Theme);
  PaintScreenWell(FShell, Rect(BezelR.Left + Bezel, BezelR.Top + Bezel,
    BezelR.Right - Bezel, BezelR.Bottom - Bezel), Round(3 * FUIScale));

  FShell.RoundRectV(Rect(BezelR.Right - Round(150 * FUIScale),
                         BezelR.Bottom - Bezel + Round(2 * FUIScale),
                         BezelR.Right - Round(18 * FUIScale),
                         BezelR.Bottom - Round(3 * FUIScale)),
    Round(5 * FUIScale), ShadePix(Theme.Bezel1, 1.25), Theme.Bezel2, 0.9);
  FShell.Touch;
end;

procedure TMainForm.ResizeSurfaces(AW, AH: Integer);
var
  Keep: TArtSurface;
begin
  AW := Max(1, AW);
  AH := Max(1, AH);
  if (FArt.Width = AW) and (FArt.Height = AH) then Exit;

  Keep := TArtSurface.Create(FInkToy.Width, FInkToy.Height);
  try
    Keep.PreserveAlpha := True;
    Keep.CopyFrom(FInkToy, 0, 0);

    FPaper.SetSize(AW, AH);
    FArt.SetSize(AW, AH);
    FInkToy.SetSize(AW, AH);
    FInkPro.SetSize(AW, AH);
    FInkToy.ClearTransparent;
    FInkPro.ClearTransparent;
    FInkToy.CopyRegion(Keep, 0, 0, 0, 0, Keep.Width, Keep.Height);
  finally
    Keep.Free;
  end;

  FPenX := EnsureRange(FPenX, 0, AW - 1);
  FPenY := EnsureRange(FPenY, 0, AH - 1);

  RepaintPaper;
  RenderPro;
  RecomposeAll;

  { raster undo snapshots no longer match the buffer size }
  FUndoToyTop := 0;
  FRedoToyTop := 0;
end;

procedure TMainForm.RepaintPaper;
begin
  if FMode = mdPro then
  begin
    PaintScreenPaper(FPaper, Theme, False);
    if FShowGrid then
      case FD.View of
        vkIso: PaintIsoGrid(FPaper, Theme, Ppu, FD.ViewX, FD.ViewY, 5);
        vkPlan: PaintMeasuredGrid(FPaper, Theme, Ppu, FD.ViewX, FD.ViewY, 5);
        vkOrbit: ;   // a fixed lattice is more noise than help when orbiting
      end;
  end
  else
    PaintScreenPaper(FPaper, Theme, FShowGrid);
end;

procedure TMainForm.Recompose;
var
  R: TRect;
begin
  R := ActiveInk.TakeDirty;
  if (R.Right <= R.Left) or (R.Bottom <= R.Top) then Exit;
  InflateRect(R, 1, 1);
  FArt.CompositeOver(FPaper, ActiveInk, R);
  FScreenDirty := True;
end;

procedure TMainForm.RecomposeAll;
begin
  FArt.CompositeOver(FPaper, ActiveInk, Rect(0, 0, FArt.Width, FArt.Height));
  ActiveInk.ResetDirty;
  FScreenDirty := True;
end;

procedure TMainForm.FreshScreen;
begin
  RepaintPaper;
  RecomposeAll;
end;

{ Re-draw the entire pro document.  Because everything is stored as real
  geometry, zooming, panning, changing scale or switching units all come down
  to calling this again - nothing is ever resampled. }
procedure TMainForm.RenderPro;
begin
  FInkPro.ClearTransparent;
  if FD.Doc.Live > 0 then
    FD.Doc.Render(FInkPro, Proj, FD.ShowDims, FD.Units, FDimFont, AnnotColor);
  FInkPro.MarkAllDirty;
end;

procedure TMainForm.RefreshChrome;
begin
  RebuildShell;
  RebuildDeck;
  RebuildKnobs;
  Invalidate;
  pbDeck.Invalidate;
  pbMode.Invalidate;
  pbCmd.Invalidate;
  pbKnobL.Invalidate;
  pbKnobR.Invalidate;
end;

procedure TMainForm.InvalidateStatus;
var
  R: TRect;
  Now64: QWord;
begin
  Now64 := GetTickCount64;
  if Now64 - FLastStatus < 60 then Exit;
  FLastStatus := Now64;
  R := Rect(ClientWidth div 3, Round(38 * FUIScale), ClientWidth,
    Round(84 * FUIScale));
  LCLIntf.InvalidateRect(Handle, @R, False);
  if FMode = mdPro then
    pbCmd.Invalidate;
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  Relayout;
end;

{ ======================================================================== }
{ view: zoom, pan, origin                                                   }
{ ======================================================================== }

procedure TMainForm.ZoomAt(Factor: Double; AnchorSX, AnchorSY: Double);
var
  W: TP3;
  P: TPointF;
  NewZoom: Double;
begin
  NewZoom := EnsureRange(FD.Zoom * Factor, 0.05, 40.0);
  if NewZoom = FD.Zoom then Exit;
  { keep whatever is under the anchor point exactly where it is }
  W := WorldAt(AnchorSX, AnchorSY);
  FD.Zoom := NewZoom;
  P := Project(Proj, W);
  FD.ViewX := FD.ViewX + (AnchorSX - P.X);
  FD.ViewY := FD.ViewY + (AnchorSY - P.Y);
  RepaintPaper;
  RenderPro;
  RecomposeAll;
  Invalidate;
end;

procedure TMainForm.SetScaleIdx(I: Integer);
var
  CX, CY: Double;
  W: TP3;
  P: TPointF;
begin
  I := EnsureRange(I, 0, SCALE_COUNT - 1);
  if I = FD.ScaleIdx then Exit;
  CX := FArt.Width / 2;
  CY := FArt.Height / 2;
  W := WorldAt(CX, CY);
  FD.ScaleIdx := I;
  P := Project(Proj, W);
  FD.ViewX := FD.ViewX + (CX - P.X);
  FD.ViewY := FD.ViewY + (CY - P.Y);
  RepaintPaper;
  RenderPro;
  RecomposeAll;
  RebuildDeck;
  pbDeck.Invalidate;
  Invalidate;
end;

procedure TMainForm.PanBy(DX, DY: Double);
begin
  FD.ViewX := FD.ViewX + DX;
  FD.ViewY := FD.ViewY + DY;
  RepaintPaper;
  RenderPro;
  RecomposeAll;
end;

{ Re-centre the coordinate readout on the picked point without moving
  anything that has been drawn. }
procedure TMainForm.SetOriginHere;
var
  P: TPointF;
begin
  P := ScreenOf(FCur);
  FD.ViewX := P.X;
  FD.ViewY := P.Y;
  FCur := P3(0, 0, 0);
  RepaintPaper;
  RenderPro;
  RecomposeAll;
  FCmdMsg := 'Origin moved.';
  Invalidate;
end;

{ Frame the whole drawing, or reset to a sensible empty sheet. }
procedure TMainForm.FitView;
var
  Lo, Hi, Mid: TP3;
  P: TPointF;
  BaseP, W, H, Z: Double;
begin
  if not FD.Doc.Bounds(Lo, Hi) then
  begin
    FD.Zoom := 1.0;
    FD.ViewX := Round(FArt.Width * 0.10);
    FD.ViewY := Round(FArt.Height * 0.88);
  end
  else
  begin
    { measure the drawing in projected pixels at zoom 1, then fit }
    BaseP := PixelsPerUnit(FD.Units, CurScale, Screen.PixelsPerInch);
    case FD.View of
      vkIso:
        begin
          W := Max((Abs(Hi.X - Lo.X) + Abs(Hi.Y - Lo.Y)) * ISO_COS, 1E-6);
          H := Max((Hi.X - Lo.X + Hi.Y - Lo.Y) * ISO_SIN + (Hi.Z - Lo.Z), 1E-6);
        end;
      vkOrbit:
        begin
          { the diagonal is a safe bound from any camera angle }
          W := Max(Sqrt(Sqr(Hi.X - Lo.X) + Sqr(Hi.Y - Lo.Y) + Sqr(Hi.Z - Lo.Z)), 1E-6);
          H := W;
        end;
    else
      begin
        W := Max(Hi.X - Lo.X, 1E-6);
        H := Max(Hi.Y - Lo.Y, 1E-6);
      end;
    end;
    Z := Min((FArt.Width * 0.80) / (W * BaseP), (FArt.Height * 0.80) / (H * BaseP));
    FD.Zoom := EnsureRange(Z, 0.05, 40.0);
    Mid := P3((Lo.X + Hi.X) / 2, (Lo.Y + Hi.Y) / 2, (Lo.Z + Hi.Z) / 2);
    FD.ViewX := 0;
    FD.ViewY := 0;
    P := Project(Proj, Mid);
    FD.ViewX := FArt.Width / 2 - P.X;
    FD.ViewY := FArt.Height / 2 - P.Y;
  end;
  RepaintPaper;
  RenderPro;
  RecomposeAll;
  Invalidate;
end;

{ ======================================================================== }
{ drawings and tabs                                                         }
{ ======================================================================== }

constructor TDrawing.Create(const AName: string);
begin
  inherited Create;
  Doc := TWorkDoc.Create;
  Name := AName;
  Zoom := 1.0;
  ScaleIdx := 2;          // 1/4" = 1'-0"
  SnapIdx := 5;           // one foot
  Units := usImperial;
  ShowDims := True;
  View := vkPlan;
  Plane := plXY;
  Az := -Pi / 4;
  El := 35.264 * Pi / 180;   // start on the isometric corner
  SetLength(Undo, UNDO_LEVELS);
  SetLength(Redo, UNDO_LEVELS);
end;

destructor TDrawing.Destroy;
begin
  Doc.Free;
  inherited Destroy;
end;

procedure TMainForm.NewDrawing;
var
  N: Integer;
begin
  N := Length(FDrawings);
  SetLength(FDrawings, N + 1);
  FDrawings[N] := TDrawing.Create(Format('Sheet %d', [N + 1]));
  if N > 0 then
  begin
    { a new sheet inherits how you were working }
    FDrawings[N].ScaleIdx := FD.ScaleIdx;
    FDrawings[N].SnapIdx := FD.SnapIdx;
    FDrawings[N].Units := FD.Units;
    FDrawings[N].ShowDims := FD.ShowDims;
    FDrawings[N].View := FD.View;
  end;
  FTabIdx := N;
  FD := FDrawings[N];
  FD.ViewX := Round(FArt.Width * 0.10);
  FD.ViewY := Round(FArt.Height * 0.88);
  if FBooted then
  begin
    ResetTool;
    LayoutTabs;
    RepaintPaper;
    RenderPro;
    RecomposeAll;
    RefreshChrome;
  end;
end;

procedure TMainForm.SelectDrawing(I: Integer);
begin
  if (I < 0) or (I > High(FDrawings)) or (I = FTabIdx) then Exit;
  FTabIdx := I;
  FD := FDrawings[I];
  ResetTool;
  RepaintPaper;
  RenderPro;
  RecomposeAll;
  RebuildDeck;
  pbDeck.Invalidate;
  pbTabs.Invalidate;
  Invalidate;
end;

procedure TMainForm.CloseDrawing(I: Integer);
var
  K: Integer;
begin
  if Length(FDrawings) <= 1 then
  begin
    FCmdMsg := 'That is the only sheet - nothing to close.';
    pbCmd.Invalidate;
    Exit;
  end;
  if (I < 0) or (I > High(FDrawings)) then Exit;

  FDrawings[I].Free;
  for K := I to High(FDrawings) - 1 do
    FDrawings[K] := FDrawings[K + 1];
  SetLength(FDrawings, Length(FDrawings) - 1);

  FTabIdx := EnsureRange(FTabIdx, 0, High(FDrawings));
  FD := FDrawings[FTabIdx];
  ResetTool;
  LayoutTabs;
  RepaintPaper;
  RenderPro;
  RecomposeAll;
  RefreshChrome;
end;

procedure TMainForm.LayoutTabs;
var
  I, X, W, TabH, Pad: Integer;
begin
  SetLength(FTabRects, Length(FDrawings) + 1);   // one extra for the + button
  if not pbTabs.Visible then Exit;
  TabH := pbTabs.Height;
  Pad := Round(4 * FUIScale);
  X := 0;
  W := Round(132 * FUIScale);
  for I := 0 to High(FDrawings) do
  begin
    FTabRects[I] := Rect(X, 0, X + W, TabH);
    Inc(X, W + Pad);
  end;
  FTabRects[High(FTabRects)] := Rect(X, 0, X + Round(30 * FUIScale), TabH);
  pbTabs.Invalidate;
end;

procedure TMainForm.pbTabsPaint(Sender: TObject);
var
  I, TW: Integer;
  R: TRect;
  IsCur, Hot: Boolean;
  C1, C2, Edge: TPix;
  S: string;
begin
  if Length(FTabRects) <> Length(FDrawings) + 1 then LayoutTabs;

  FCmdSkin.SetSize(pbTabs.Width, pbTabs.Height);
  FCmdSkin.Clear(Pix(0, 0, 0));
  FCmdSkin.CopyRegion(FShell, pbTabs.Left, pbTabs.Top, 0, 0,
    pbTabs.Width, pbTabs.Height);

  for I := 0 to High(FDrawings) do
  begin
    R := FTabRects[I];
    IsCur := I = FTabIdx;
    Hot := I = FHotTab;
    if IsCur then
    begin
      C1 := MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.14);
      C2 := Theme.Panel;
      Edge := ShadePix(Theme.Accent, 0.9);
    end
    else if Hot then
    begin
      C1 := MixPix(Theme.Panel, Pix(255, 255, 255), 0.10);
      C2 := MixPix(Theme.Panel, Pix(0, 0, 0), 0.10);
      Edge := MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.20);
    end
    else
    begin
      C1 := MixPix(Theme.Panel, Pix(0, 0, 0), 0.15);
      C2 := MixPix(Theme.Panel, Pix(0, 0, 0), 0.30);
      Edge := MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.08);
    end;
    { square off the bottom so the active tab reads as joined to the sheet }
    FCmdSkin.RoundRectV(Rect(R.Left, R.Top, R.Right, R.Bottom + Round(10 * FUIScale)),
      Round(9 * FUIScale), C1, C2);
    FCmdSkin.RoundFrame(Rect(R.Left, R.Top, R.Right, R.Bottom + Round(10 * FUIScale)),
      Round(9 * FUIScale), 1.0, Edge, 0.9);
    if IsCur then
      FCmdSkin.RoundRect(Rect(R.Left + Round(10 * FUIScale), R.Top + Round(3 * FUIScale),
        R.Right - Round(10 * FUIScale), R.Top + Round(6 * FUIScale)),
        1.5, Theme.Accent, 0.95);
    { close cross }
    if IsCur and (Length(FDrawings) > 1) then
    begin
      FCmdSkin.Line(R.Right - Round(20 * FUIScale), R.Top + Round(12 * FUIScale),
        R.Right - Round(12 * FUIScale), R.Top + Round(20 * FUIScale), 1.5, Theme.TextDim, 0.9);
      FCmdSkin.Line(R.Right - Round(12 * FUIScale), R.Top + Round(12 * FUIScale),
        R.Right - Round(20 * FUIScale), R.Top + Round(20 * FUIScale), 1.5, Theme.TextDim, 0.9);
    end;
  end;

  { the + button }
  R := FTabRects[High(FTabRects)];
  Hot := FHotTab = High(FTabRects);
  if Hot then
    FCmdSkin.RoundRect(R, Round(8 * FUIScale),
      MixPix(Theme.Panel, Pix(255, 255, 255), 0.12))
  else
    FCmdSkin.RoundRect(R, Round(8 * FUIScale),
      MixPix(Theme.Panel, Pix(0, 0, 0), 0.20));
  FCmdSkin.Line((R.Left + R.Right) / 2, R.Top + Round(9 * FUIScale),
    (R.Left + R.Right) / 2, R.Bottom - Round(9 * FUIScale), 1.6, Theme.Text, 0.85);
  FCmdSkin.Line(R.Left + Round(9 * FUIScale), (R.Top + R.Bottom) / 2,
    R.Right - Round(9 * FUIScale), (R.Top + R.Bottom) / 2, 1.6, Theme.Text, 0.85);

  FCmdSkin.DrawTo(pbTabs.Canvas, 0, 0);

  for I := 0 to High(FDrawings) do
  begin
    R := FTabRects[I];
    if I = FTabIdx then
      UIFont(pbTabs.Canvas, 10, True, Theme.Text)
    else
      UIFont(pbTabs.Canvas, 10, False, Theme.TextDim);
    S := FDrawings[I].Name;
    TW := pbTabs.Canvas.TextWidth(S);
    pbTabs.Canvas.TextOut(R.Left + Round(12 * FUIScale),
      (R.Top + R.Bottom - pbTabs.Canvas.TextHeight(S)) div 2, S);
    if TW = 0 then ;
  end;
end;

procedure TMainForm.pbTabsMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  I, H: Integer;
begin
  H := -1;
  for I := 0 to High(FTabRects) do
    if PtInRect(FTabRects[I], Point(X, Y)) then
    begin
      H := I;
      Break;
    end;
  if H <> FHotTab then
  begin
    FHotTab := H;
    pbTabs.Invalidate;
  end;
end;

procedure TMainForm.pbTabsMouseLeave(Sender: TObject);
begin
  if FHotTab <> -1 then
  begin
    FHotTab := -1;
    pbTabs.Invalidate;
  end;
end;

procedure TMainForm.pbTabsMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
  R: TRect;
begin
  if Button <> mbLeft then Exit;
  for I := 0 to High(FDrawings) do
  begin
    R := FTabRects[I];
    if not PtInRect(R, Point(X, Y)) then Continue;
    if (I = FTabIdx) and (Length(FDrawings) > 1) and
       (X > R.Right - Round(26 * FUIScale)) then
      CloseDrawing(I)
    else
      SelectDrawing(I);
    Exit;
  end;
  if PtInRect(FTabRects[High(FTabRects)], Point(X, Y)) then
    NewDrawing;
end;

{ ======================================================================== }
{ control deck                                                              }
{ ======================================================================== }

procedure TMainForm.RebuildDeck;
var
  W, H, Pad, LabW, RowH, RowGap, IconW, IconGap, RightW: Integer;
  Y0, RowY, X, Avail, SegW, SwSz, SwGap, I, N: Integer;
  Blank: TPix;

  procedure Add(K: TDeckKind; const B: TRect; G, V: Integer;
    const Cap, Hnt: string; Ic: TIconKind);
  var
    M: Integer;
  begin
    M := Length(FDeck);
    SetLength(FDeck, M + 1);
    FDeck[M].Kind := K;
    FDeck[M].Bounds := B;
    FDeck[M].Group := G;
    FDeck[M].Value := V;
    FDeck[M].Caption := Cap;
    FDeck[M].Hint := Hnt;
    FDeck[M].Icon := Ic;
    FDeck[M].Swatch := Blank;
  end;

  procedure AddIconRow(RY: Integer; A1, A2, A3: Integer;
    I1, I2, I3: TIconKind; const H1, H2, H3: string);
  var
    IX: Integer;
  begin
    IX := W - Pad - RightW;
    Add(dkIcon, Rect(IX, RY, IX + IconW, RY + RowH), GRP_ICON, A1, '', H1, I1);
    Inc(IX, IconW + IconGap);
    Add(dkIcon, Rect(IX, RY, IX + IconW, RY + RowH), GRP_ICON, A2, '', H2, I2);
    Inc(IX, IconW + IconGap);
    Add(dkIcon, Rect(IX, RY, IX + IconW, RY + RowH), GRP_ICON, A3, '', H3, I3);
  end;

  { Lay a segmented control across the free width, leaving room for Extras
    trailing icon slots. }
  procedure Segments(RY, Group, Count, Extras: Integer);
  var
    K, SW: Integer;
  begin
    SW := (Avail - Extras * (IconW + RowGap)) div Count;
    for K := 0 to Count - 1 do
      Add(dkSegment, Rect(X + K * SW + 2, RY, X + (K + 1) * SW - 2, RY + RowH),
        Group, K, '', '', ikDroplet);
    SegW := SW;
  end;

begin
  SetLength(FDeck, 0);
  Blank := Pix(0, 0, 0);
  W := FDeckSkin.Width;
  H := FDeckSkin.Height;
  if (W < 40) or (H < 40) then Exit;

  Pad := Round(14 * FUIScale);
  LabW := Round(74 * FUIScale);
  RowH := Round(30 * FUIScale);
  RowGap := Round(8 * FUIScale);
  IconW := Round(34 * FUIScale);
  IconGap := Round(6 * FUIScale);
  RightW := 3 * IconW + 2 * IconGap;

  Y0 := (H - (4 * RowH + 3 * RowGap)) div 2;
  X := Pad + LabW;
  Avail := Max(120, W - Pad - RightW - Round(18 * FUIScale) - X);

  if FMode = mdToy then
  begin
    { --- row 1: pen style ---------------------------------------------- }
    RowY := Y0;
    SegW := Avail div 5;
    for I := 0 to 4 do
      Add(dkSegment, Rect(X + I * SegW + 2, RowY, X + (I + 1) * SegW - 2, RowY + RowH),
        GRP_STYLE, I, STYLE_NAMES[TPenStyle(I)], STYLE_HINTS[TPenStyle(I)], ikDroplet);
    AddIconRow(RowY, ACT_UNDO, ACT_REDO, ACT_SHAKE, ikUndo, ikRedo, ikShake,
      'Undo  (Ctrl+Z)', 'Redo  (Ctrl+Y)', 'Shake the screen clean  (Delete)');

    { --- row 2: kaleidoscope -------------------------------------------- }
    RowY := Y0 + RowH + RowGap;
    SegW := (Avail - IconW - RowGap) div 5;
    for I := 0 to 4 do
      Add(dkSegment, Rect(X + I * SegW + 2, RowY, X + (I + 1) * SegW - 2, RowY + RowH),
        GRP_SYM, SYM_VALUES[I], IntToStr(SYM_VALUES[I]),
        Format('Kaleidoscope: repeat every stroke %d times around the centre.',
          [SYM_VALUES[I]]), ikDroplet);
    Add(dkIcon, Rect(X + 5 * SegW + RowGap, RowY, X + 5 * SegW + RowGap + IconW,
      RowY + RowH), GRP_ICON, ACT_MIRROR, '', 'Mirror left to right  (M)', ikMirror);
    AddIconRow(RowY, ACT_SAVE, ACT_PRINT, ACT_AUTO, ikSave, ikPrint, ikMagic,
      'Save as a PNG  (Ctrl+S)', 'Print  (Ctrl+P)',
      'Auto-draw: let the machine doodle  (A)');
  end
  else
  begin
    { --- row 1: tools --------------------------------------------------- }
    RowY := Y0;
    N := Ord(High(TProTool)) + 1;
    SegW := Avail div N;
    for I := 0 to N - 1 do
      Add(dkSegment, Rect(X + I * SegW + 2, RowY, X + (I + 1) * SegW - 2, RowY + RowH),
        GRP_TOOL, I, TOOL_NAMES[TProTool(I)], TOOL_HINTS[TProTool(I)], ikDroplet);
    AddIconRow(RowY, ACT_UNDO, ACT_REDO, ACT_FIT, ikUndo, ikRedo, ikFit,
      'Undo  (Ctrl+Z)', 'Redo  (Ctrl+Y)', 'Frame the whole drawing  (F)');

    { --- row 2: drawing scale ------------------------------------------- }
    RowY := Y0 + RowH + RowGap;
    SegW := (Avail - IconW - RowGap) div SCALE_COUNT;
    for I := 0 to SCALE_COUNT - 1 do
      Add(dkSegment, Rect(X + I * SegW + 2, RowY, X + (I + 1) * SegW - 2, RowY + RowH),
        GRP_SCALE, I, ScaleTable(FD.Units, I).Name,
        'Print scale ' + ScaleTable(FD.Units, I).Name +
          IfThen(FD.Units = usImperial, ' = 1''-0"', ''), ikDroplet);
    Add(dkIcon, Rect(X + SCALE_COUNT * SegW + RowGap, RowY,
      X + SCALE_COUNT * SegW + RowGap + IconW, RowY + RowH),
      GRP_ICON, ACT_UNITS, '', 'Feet-and-inches or metric  (U)', ikUnits);
    AddIconRow(RowY, ACT_OPEN, ACT_SAVE, ACT_EXPORT, ikOpen, ikSave, ikExport,
      'Open a drawing  (Ctrl+O)', 'Save this drawing  (Ctrl+S)',
      'Export a picture - PNG or SVG  (Ctrl+E)');

    { --- row 3: snap ---------------------------------------------------- }
    RowY := Y0 + 2 * (RowH + RowGap);
    SegW := Avail div SNAP_COUNT;
    for I := 0 to SNAP_COUNT - 1 do
      Add(dkSegment, Rect(X + I * SegW + 2, RowY, X + (I + 1) * SegW - 2, RowY + RowH),
        GRP_SNAP, I, SnapName(FD.Units, I),
        IfThen(I = 0, 'No snapping at all - free cursor  (or hold Alt)',
                      'Snap to ' + SnapName(FD.Units, I) +
                      ' steps, and to points on the drawing'), ikDroplet);
    AddIconRow(RowY, ACT_THEME, ACT_GRID, ACT_HELP, ikTheme, ikGrid, ikHelp,
      'Change the theme  (T)', 'Show or hide the measured grid  (G)',
      'About this program  (F1)');
  end;

  { --- ink row ---------------------------------------------------------- }
  if FMode = mdToy then
    RowY := Y0 + 2 * (RowH + RowGap)
  else
    RowY := Y0 + 3 * (RowH + RowGap);

  SwGap := Round(6 * FUIScale);
  SwSz := Min(RowH - Round(6 * FUIScale),
    (Avail div 2 - 11 * SwGap) div 12);
  SwSz := Max(9, SwSz);
  for I := 0 to High(PALETTE) do
  begin
    Add(dkSwatch, Rect(X + I * (SwSz + SwGap), RowY + (RowH - SwSz) div 2,
      X + I * (SwSz + SwGap) + SwSz, RowY + (RowH - SwSz) div 2 + SwSz),
      GRP_INK, I, '', 'Ink colour', ikDroplet);
    FDeck[High(FDeck)].Swatch := ColorToPix(PALETTE[I]);
  end;
  Add(dkIcon, Rect(X + 12 * (SwSz + SwGap) + RowGap, RowY,
    X + 12 * (SwSz + SwGap) + RowGap + IconW, RowY + RowH),
    GRP_ICON, ACT_PICK, '', 'Pick any colour you like...', ikDroplet);

  { size slider shares the ink row when there is space, otherwise its own }
  I := X + 12 * (SwSz + SwGap) + RowGap + IconW + Round(20 * FUIScale);
  if FMode = mdPro then
  begin
    Add(dkSlider, Rect(I, RowY + RowH div 2 - Round(9 * FUIScale),
      Max(I + 60, X + Avail - Round(56 * FUIScale)),
      RowY + RowH div 2 + Round(9 * FUIScale)), GRP_SIZE, 0, '',
      'Line weight  ( [ and ] )', ikDroplet);
    AddIconRow(RowY, ACT_PRINT, ACT_ORIGIN, ACT_DIM, ikPrint, ikOrigin, ikDim,
      'Print at true scale  (Ctrl+P)', 'Put 0,0 under the cursor  (O)',
      'Label every line with its length  (D)');
  end
  else
  begin
    RowY := Y0 + 3 * (RowH + RowGap);
    Add(dkSlider, Rect(X, RowY + RowH div 2 - Round(9 * FUIScale),
      X + Avail - Round(56 * FUIScale), RowY + RowH div 2 + Round(9 * FUIScale)),
      GRP_SIZE, 0, '', 'How thick the line is  ( [ and ] )', ikDroplet);
    AddIconRow(RowY, ACT_THEME, ACT_GRID, ACT_HELP, ikTheme, ikGrid, ikHelp,
      'Change the theme  (T)', 'Show or hide the guide grid  (G)',
      'About this program  (F1)');
  end;
end;

function TMainForm.DeckHit(X, Y: Integer): Integer;
var
  I: Integer;
  R: TRect;
begin
  for I := 0 to High(FDeck) do
  begin
    R := FDeck[I].Bounds;
    if FDeck[I].Kind = dkSwatch then
      InflateRect(R, 3, 3);
    if PtInRect(R, Point(X, Y)) then
      Exit(I);
  end;
  Result := -1;
end;

function TMainForm.IconLit(Value: Integer): Boolean;
begin
  case Value of
    ACT_AUTO: Result := FAuto;
    ACT_GRID: Result := FShowGrid;
    ACT_MIRROR: Result := FMirror;
    ACT_DIM: Result := FD.ShowDims;
    ACT_UNITS: Result := FD.Units = usMetric;
    ACT_PICK: Result := not InPalette(FInkColor);

  else
    Result := False;
  end;
end;

function TMainForm.IconEnabled(Value: Integer): Boolean;
begin
  case Value of
    ACT_UNDO: Result := CanUndo;
    ACT_REDO: Result := CanRedo;
  else
    Result := True;
  end;
end;

function TMainForm.SliderValueAt(const Item: TDeckItem; X: Integer): Integer;
var
  T: Single;
begin
  T := (X - Item.Bounds.Left) / Max(1, Item.Bounds.Right - Item.Bounds.Left);
  Result := Round(MIN_PEN + EnsureRange(T, 0, 1) * (MAX_PEN - MIN_PEN));
end;

function TMainForm.InPalette(C: TColor): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(PALETTE) do
    if PALETTE[I] = C then
      Exit(True);
  Result := False;
end;

function TMainForm.IndexOfSym(V: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to High(SYM_VALUES) do
    if SYM_VALUES[I] = V then
      Exit(I);
  Result := 0;
end;

procedure TMainForm.pbDeckPaint(Sender: TObject);
var
  I, TW: Integer;
  It: TDeckItem;
  Sel, Hot, Ena: Boolean;
  C1, C2, Edge, Fg: TPix;
  R, IR: TRect;
  T: Single;
  Pad, RowH, RowGap, Y0: Integer;
  Lbl: string;

  function Selected(const A: TDeckItem): Boolean;
  begin
    Result := ((A.Group = GRP_STYLE) and (A.Value = Ord(FStyle))) or
              ((A.Group = GRP_SYM) and (A.Value = FSym)) or
              ((A.Group = GRP_TOOL) and (A.Value = Ord(FTool))) or
              ((A.Group = GRP_SCALE) and (A.Value = FD.ScaleIdx)) or
              ((A.Group = GRP_SNAP) and (A.Value = FD.SnapIdx));
  end;

  procedure Section(Row: Integer; const S: string);
  begin
    UIFont(pbDeck.Canvas, 10, True, Theme.TextDim);
    TrackedText(pbDeck.Canvas, Pad,
      Y0 + Row * (RowH + RowGap) + (RowH - pbDeck.Canvas.TextHeight('X')) div 2,
      S, Round(1.5 * FUIScale));
  end;

begin
  PaintPanel(FDeckSkin, Rect(0, 0, FDeckSkin.Width, FDeckSkin.Height), Theme,
    Round(16 * FUIScale));

  for I := 0 to High(FDeck) do
  begin
    It := FDeck[I];
    Hot := (I = FHotItem);
    R := It.Bounds;

    case It.Kind of
      dkSegment:
        begin
          Sel := Selected(It);
          if Sel then
          begin
            C1 := ShadePix(Theme.Accent, 1.10);
            C2 := ShadePix(Theme.Accent, 0.80);
            Edge := ShadePix(Theme.Accent, 0.55);
          end
          else if Hot then
          begin
            C1 := MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.22);
            C2 := MixPix(Theme.Panel, Pix(255, 255, 255), 0.10);
            Edge := MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.35);
          end
          else
          begin
            C1 := MixPix(Theme.PanelHi, Pix(0, 0, 0), 0.20);
            C2 := MixPix(Theme.Panel, Pix(0, 0, 0), 0.25);
            Edge := MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.12);
          end;
          PaintPill(FDeckSkin, R, Round(8 * FUIScale), C1, C2, Edge);
        end;

      dkSwatch:
        PaintSwatch(FDeckSkin, R, It.Swatch, PALETTE[It.Value] = FInkColor, Hot, Theme);

      dkIcon:
        begin
          Ena := IconEnabled(It.Value);
          Sel := IconLit(It.Value);
          if Sel then
          begin
            C1 := ShadePix(Theme.Accent, 1.10);
            C2 := ShadePix(Theme.Accent, 0.80);
            Edge := ShadePix(Theme.Accent, 0.55);
            Fg := Pix(20, 20, 24);
          end
          else
          begin
            if Hot and Ena then
            begin
              C1 := MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.22);
              C2 := MixPix(Theme.Panel, Pix(255, 255, 255), 0.10);
            end
            else
            begin
              C1 := MixPix(Theme.PanelHi, Pix(0, 0, 0), 0.20);
              C2 := MixPix(Theme.Panel, Pix(0, 0, 0), 0.25);
            end;
            Edge := MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.12);
            Fg := Theme.Text;
          end;
          PaintPill(FDeckSkin, R, Round(8 * FUIScale), C1, C2, Edge);
          IR := R;
          InflateRect(IR, -Round(6 * FUIScale), -Round(6 * FUIScale));
          if Ena then
            PaintIcon(FDeckSkin, It.Icon, IR, Fg, 0.95)
          else
            PaintIcon(FDeckSkin, It.Icon, IR, Theme.TextDim, 0.35);
        end;

      dkSlider:
        begin
          T := (FPenSize - MIN_PEN) / (MAX_PEN - MIN_PEN);
          FDeckSkin.RoundRect(R, (R.Bottom - R.Top) / 2,
            MixPix(Theme.Panel, Pix(0, 0, 0), 0.35));
          FDeckSkin.RoundRect(Rect(R.Left, R.Top,
            R.Left + Round((R.Right - R.Left) * T), R.Bottom),
            (R.Bottom - R.Top) / 2, Theme.Accent, 0.85);
          FDeckSkin.RoundFrame(R, (R.Bottom - R.Top) / 2, 1.0,
            MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.15));
          FDeckSkin.Disc(R.Left + (R.Right - R.Left) * T, (R.Top + R.Bottom) / 2,
            Round(10 * FUIScale), Pix(245, 245, 250));
          FDeckSkin.Ring(R.Left + (R.Right - R.Left) * T, (R.Top + R.Bottom) / 2,
            Round(10 * FUIScale), 1.2, Pix(0, 0, 0), 0.35);
          FDeckSkin.Disc(R.Left + (R.Right - R.Left) * T, (R.Top + R.Bottom) / 2,
            Max(1.0, FPenSize * 0.28 * FUIScale), FInkPix);
        end;
      dkNone: ;
    end;
  end;

  FDeckSkin.DrawTo(pbDeck.Canvas, 0, 0);

  Pad := Round(14 * FUIScale);
  RowH := Round(30 * FUIScale);
  RowGap := Round(8 * FUIScale);
  Y0 := (FDeckSkin.Height - (4 * RowH + 3 * RowGap)) div 2;

  if FMode = mdToy then
  begin
    Section(0, 'STYLE');
    Section(1, 'REPEAT');
    Section(2, 'INK');
    Section(3, 'SIZE');
  end
  else
  begin
    Section(0, 'TOOL');
    Section(1, 'SCALE');
    Section(2, 'SNAP');
    Section(3, 'INK');
  end;

  for I := 0 to High(FDeck) do
  begin
    It := FDeck[I];
    if It.Kind <> dkSegment then Continue;
    if Selected(It) then
      UIFont(pbDeck.Canvas, 10, True, Pix(22, 22, 26))
    else
      UIFont(pbDeck.Canvas, 10, False, Theme.Text);
    TW := pbDeck.Canvas.TextWidth(It.Caption);
    pbDeck.Canvas.TextOut(
      (It.Bounds.Left + It.Bounds.Right - TW) div 2,
      (It.Bounds.Top + It.Bounds.Bottom - pbDeck.Canvas.TextHeight(It.Caption)) div 2,
      It.Caption);
  end;

  for I := 0 to High(FDeck) do
    if FDeck[I].Kind = dkSlider then
    begin
      UIFont(pbDeck.Canvas, 11, True, Theme.Text, True);
      Lbl := Format('%d px', [FPenSize]);
      pbDeck.Canvas.TextOut(FDeck[I].Bounds.Right + Round(10 * FUIScale),
        (FDeck[I].Bounds.Top + FDeck[I].Bounds.Bottom -
         pbDeck.Canvas.TextHeight(Lbl)) div 2, Lbl);
      Break;
    end;
end;

procedure TMainForm.pbDeckMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  H: Integer;
begin
  if FSliderGrab then
  begin
    for H := 0 to High(FDeck) do
      if FDeck[H].Kind = dkSlider then
      begin
        SetPenSize(SliderValueAt(FDeck[H], X));
        Break;
      end;
    Exit;
  end;

  H := DeckHit(X, Y);
  if H <> FHotItem then
  begin
    FHotItem := H;
    if H >= 0 then
      FHint := FDeck[H].Hint
    else if FMode = mdPro then
      FHint := TOOL_HINTS[FTool]
    else
      FHint := TOY_HINT;
    pbDeck.Invalidate;
    Invalidate;
  end;
end;

procedure TMainForm.pbDeckMouseLeave(Sender: TObject);
begin
  if FHotItem <> -1 then
  begin
    FHotItem := -1;
    if FMode = mdPro then FHint := TOOL_HINTS[FTool] else FHint := TOY_HINT;
    pbDeck.Invalidate;
    Invalidate;
  end;
end;

procedure TMainForm.pbDeckMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  H: Integer;
begin
  if Button <> mbLeft then Exit;
  H := DeckHit(X, Y);
  if H < 0 then Exit;
  if FDeck[H].Kind = dkSlider then
  begin
    FSliderGrab := True;
    SetPenSize(SliderValueAt(FDeck[H], X));
  end
  else
    DeckActivate(H);
end;

procedure TMainForm.pbDeckMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FSliderGrab := False;
end;

procedure TMainForm.DeckActivate(Index: Integer);
var
  It: TDeckItem;
begin
  if (Index < 0) or (Index > High(FDeck)) then Exit;
  It := FDeck[Index];
  case It.Group of
    GRP_STYLE: SetStyle(TPenStyle(It.Value));
    GRP_SYM:   SetSymmetry(It.Value);
    GRP_TOOL:
      if TProTool(It.Value) = FTool then
        SetTool(ptSelect)          // clicking the lit tool puts it away
      else
        SetTool(TProTool(It.Value));
    GRP_INK:   SetInk(PALETTE[It.Value], False);
    GRP_SCALE: SetScaleIdx(It.Value);
    GRP_SNAP:  begin FD.SnapIdx := It.Value; pbDeck.Invalidate; pbCmd.Invalidate; end;
    GRP_ICON:
      case It.Value of
        ACT_UNDO:   DoUndo;
        ACT_REDO:   DoRedo;
        ACT_SHAKE:  StartErase;
        ACT_SAVE:   DoSave;
        ACT_PRINT:  DoPrint;
        ACT_AUTO:   ToggleAuto;
        ACT_THEME:  CycleTheme(1);
        ACT_GRID:   begin
                      FShowGrid := not FShowGrid;
                      RepaintPaper;
                      RecomposeAll;
                      pbDeck.Invalidate;
                    end;
        ACT_HELP:   ShowAbout;
        ACT_MIRROR: begin FMirror := not FMirror; pbDeck.Invalidate; end;
        ACT_PICK:   DoPickColor;
        ACT_UNITS:  SetUnits(TUnitSystem(1 - Ord(FD.Units)));
        ACT_DIM:    begin
                      FD.ShowDims := not FD.ShowDims;
                      RenderPro;
                      RecomposeAll;
                      pbDeck.Invalidate;
                    end;
        ACT_ORIGIN: SetOriginHere;
        ACT_FIT:    FitView;
        ACT_OPEN:   DoOpen;
        ACT_EXPORT: DoExport;
      end;
  end;
end;

{ ======================================================================== }
{ dials, mode switch, command bar                                           }
{ ======================================================================== }

procedure TMainForm.RebuildKnobs;
var
  I: Integer;
begin
  for I := 0 to 1 do
    PaintKnob(FKnobSkin[I], Rect(0, 0, FKnobSkin[I].Width, FKnobSkin[I].Height),
      FKnobAngle[I], Theme, FHotKnob = I);
end;

procedure TMainForm.pbKnobPaint(Sender: TObject);
var
  Idx: Integer;
  Pb: TPaintBox;
  Lbl: string;
begin
  Pb := TPaintBox(Sender);
  if Pb = pbKnobL then Idx := 0 else Idx := 1;

  FKnobSkin[Idx].Clear(Pix(0, 0, 0));
  FKnobSkin[Idx].CopyRegion(FShell, Pb.Left, Pb.Top, 0, 0, Pb.Width, Pb.Height);
  PaintKnob(FKnobSkin[Idx], Rect(0, 0, Pb.Width, Pb.Height - Round(16 * FUIScale)),
    FKnobAngle[Idx], Theme, FHotKnob = Idx);
  FKnobSkin[Idx].DrawTo(Pb.Canvas, 0, 0);

  if Idx = 0 then Lbl := 'LEFT / RIGHT' else Lbl := 'UP / DOWN';
  UIFont(Pb.Canvas, 9, True, Theme.TextDim);
  TrackedText(Pb.Canvas,
    (Pb.Width - (Pb.Canvas.TextWidth(Lbl) + Length(Lbl))) div 2,
    Pb.Height - Round(13 * FUIScale), Lbl, 1);
end;

procedure TMainForm.pbKnobMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Pb: TPaintBox;
begin
  if Button <> mbLeft then Exit;
  Pb := TPaintBox(Sender);
  if Pb = pbKnobL then FDragKnob := 0 else FDragKnob := 1;
  FDragAngle := ArcTan2(Y - Pb.Height / 2, X - Pb.Width / 2);
  if FMode = mdToy then BeginStroke;
end;

procedure TMainForm.pbKnobMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  Pb: TPaintBox;
  Idx: Integer;
  A, D, Step: Single;
begin
  Pb := TPaintBox(Sender);
  if Pb = pbKnobL then Idx := 0 else Idx := 1;

  if FHotKnob <> Idx then
  begin
    FHotKnob := Idx;
    Pb.Invalidate;
  end;
  if FDragKnob <> Idx then Exit;

  A := ArcTan2(Y - Pb.Height / 2, X - Pb.Width / 2);
  D := A - FDragAngle;
  while D > Pi do D := D - 2 * Pi;
  while D < -Pi do D := D + 2 * Pi;
  FDragAngle := A;
  FKnobAngle[Idx] := FKnobAngle[Idx] + D;

  if FMode = mdToy then
  begin
    if Idx = 0 then
      PenTo(FPenX + D * KNOB_PX_PER_RAD, FPenY, not FPenUp)
    else
      PenTo(FPenX, FPenY + D * KNOB_PX_PER_RAD, not FPenUp);
  end
  else
  begin
    { over here a full turn walks ten snap steps - fine positioning }
    Step := SnapStep;
    if Step <= 0 then Step := 1 / 12;
    if Idx = 0 then
      NudgeCursor(D / (2 * Pi) * 10 * Step, 0)
    else
      NudgeCursor(0, -D / (2 * Pi) * 10 * Step);
  end;
  Pb.Invalidate;
end;

procedure TMainForm.pbKnobMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FDragKnob := -1;
  EndStroke;
end;

procedure TMainForm.pbKnobMouseLeave(Sender: TObject);
begin
  if FHotKnob <> -1 then
  begin
    FHotKnob := -1;
    pbKnobL.Invalidate;
    pbKnobR.Invalidate;
  end;
end;

procedure TMainForm.pbKnobMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
var
  Idx: Integer;
  D: Single;
begin
  if TPaintBox(Sender) = pbKnobL then Idx := 0 else Idx := 1;
  D := (WheelDelta / 120) * 0.16;
  FKnobAngle[Idx] := FKnobAngle[Idx] + D;
  if FMode = mdToy then
  begin
    BeginStroke;
    if Idx = 0 then
      PenTo(FPenX + D * KNOB_PX_PER_RAD, FPenY, not FPenUp)
    else
      PenTo(FPenX, FPenY - D * KNOB_PX_PER_RAD, not FPenUp);
  end;
  TPaintBox(Sender).Invalidate;
  Handled := True;
end;


procedure TMainForm.SetView(V: TViewKind);
begin
  if V = FD.View then Exit;
  FD.View := V;
  if V <> vkOrbit then FD.Plane := plXY;
  FitView;
  RebuildDeck;
  pbDeck.Invalidate;
  pbView.Invalidate;
  case V of
    vkPlan: FCmdMsg := 'Plan view.';
    vkIso: FCmdMsg := 'Isometric view.';
  else
    FCmdMsg := '3D view - middle-drag to orbit.';
  end;
  pbCmd.Invalidate;
end;

procedure TMainForm.pbViewPaint(Sender: TObject);
const
  NAMES: array[TViewKind] of string = ('PLAN', 'ISO', '3D');
var
  W, H, I, SW: Integer;
  R: TRect;
  S: string;
begin
  W := pbView.Width;
  H := pbView.Height;
  SW := W div 3;
  FViewSkin.SetSize(W, H);
  FViewSkin.Clear(Pix(0, 0, 0));
  FViewSkin.CopyRegion(FShell, pbView.Left, pbView.Top, 0, 0, W, H);
  FViewSkin.RoundRectV(Rect(0, 0, W, H), H / 2,
    MixPix(Theme.Panel, Pix(0, 0, 0), 0.20), MixPix(Theme.Panel, Pix(0, 0, 0), 0.42));
  FViewSkin.RoundFrame(Rect(0, 0, W, H), H / 2, 1.0,
    MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.14));

  for I := 0 to 2 do
  begin
    R := Rect(I * SW + 3, 3, (I + 1) * SW - 3, H - 3);
    if Ord(FD.View) = I then
      FViewSkin.RoundRectV(R, (R.Bottom - R.Top) / 2,
        ShadePix(Theme.Accent, 1.10), ShadePix(Theme.Accent, 0.80))
    else if FHotView = I then
      FViewSkin.RoundRect(R, (R.Bottom - R.Top) / 2,
        MixPix(Theme.Panel, Pix(255, 255, 255), 0.10));
  end;
  FViewSkin.DrawTo(pbView.Canvas, 0, 0);

  for I := 0 to 2 do
  begin
    S := NAMES[TViewKind(I)];
    if Ord(FD.View) = I then
      UIFont(pbView.Canvas, 10, True, Pix(22, 22, 26))
    else
      UIFont(pbView.Canvas, 10, True, Theme.TextDim);
    pbView.Canvas.TextOut(I * SW + (SW - pbView.Canvas.TextWidth(S)) div 2,
      (H - pbView.Canvas.TextHeight(S)) div 2, S);
  end;
end;

procedure TMainForm.pbViewMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  H: Integer;
begin
  H := EnsureRange(X div Max(1, pbView.Width div 3), 0, 2);
  if H <> FHotView then
  begin
    FHotView := H;
    pbView.Invalidate;
  end;
end;

procedure TMainForm.pbViewMouseLeave(Sender: TObject);
begin
  FHotView := -1;
  pbView.Invalidate;
end;

procedure TMainForm.pbViewMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbLeft then Exit;
  SetView(TViewKind(EnsureRange(X div Max(1, pbView.Width div 3), 0, 2)));
end;

procedure TMainForm.pbModePaint(Sender: TObject);
var
  W, H, I: Integer;
  R: TRect;
  C1, C2: TPix;
  S: string;
begin
  W := pbMode.Width;
  H := pbMode.Height;
  FModeSkin.Clear(Pix(0, 0, 0));
  FModeSkin.CopyRegion(FShell, pbMode.Left, pbMode.Top, 0, 0, W, H);
  FModeSkin.RoundRectV(Rect(0, 0, W, H), H / 2,
    MixPix(Theme.Panel, Pix(0, 0, 0), 0.20), MixPix(Theme.Panel, Pix(0, 0, 0), 0.40));
  FModeSkin.RoundFrame(Rect(0, 0, W, H), H / 2, 1.0,
    MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.14));

  for I := 0 to 1 do
  begin
    R := Rect(I * (W div 2) + 3, 3, (I + 1) * (W div 2) - 3, H - 3);
    if Ord(FMode) = I then
    begin
      C1 := ShadePix(Theme.Accent, 1.10);
      C2 := ShadePix(Theme.Accent, 0.80);
      FModeSkin.RoundRectV(R, (R.Bottom - R.Top) / 2, C1, C2);
    end
    else if FHotMode = I then
      FModeSkin.RoundRect(R, (R.Bottom - R.Top) / 2,
        MixPix(Theme.Panel, Pix(255, 255, 255), 0.10));
  end;
  FModeSkin.DrawTo(pbMode.Canvas, 0, 0);

  for I := 0 to 1 do
  begin
    R := Rect(I * (W div 2), 0, (I + 1) * (W div 2), H);
    if I = 0 then S := 'TOY' else S := 'PRO';
    if Ord(FMode) = I then
      UIFont(pbMode.Canvas, 11, True, Pix(22, 22, 26))
    else
      UIFont(pbMode.Canvas, 11, True, Theme.TextDim);
    TrackedText(pbMode.Canvas,
      (R.Left + R.Right - (pbMode.Canvas.TextWidth(S) + 2 * Length(S))) div 2,
      (H - pbMode.Canvas.TextHeight(S)) div 2, S, 2);
  end;
end;

procedure TMainForm.pbModeMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  H: Integer;
begin
  if X < pbMode.Width div 2 then H := 0 else H := 1;
  if H <> FHotMode then
  begin
    FHotMode := H;
    pbMode.Invalidate;
  end;
end;

procedure TMainForm.pbModeMouseLeave(Sender: TObject);
begin
  FHotMode := -1;
  pbMode.Invalidate;
end;

procedure TMainForm.pbModeMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbLeft then Exit;
  if X < pbMode.Width div 2 then SetMode(mdToy) else SetMode(mdPro);
end;

{ The command bar always says what it wants next, so nothing has to be
  memorised.  It also takes typed lengths and typed commands. }
procedure TMainForm.pbCmdPaint(Sender: TObject);
var
  W, H, X, TW: Integer;
  S: string;
  Caret: string;
begin
  W := pbCmd.Width;
  H := pbCmd.Height;
  FCmdSkin.SetSize(W, H);
  FCmdSkin.Clear(Pix(0, 0, 0));
  FCmdSkin.CopyRegion(FShell, pbCmd.Left, pbCmd.Top, 0, 0, W, H);
  PaintPanel(FCmdSkin, Rect(0, 0, W, H), Theme, Round(10 * FUIScale));
  FCmdSkin.RoundRect(Rect(Round(6 * FUIScale), Round(6 * FUIScale),
    Round(10 * FUIScale), H - Round(6 * FUIScale)), 2, Theme.Accent, 0.9);
  FCmdSkin.DrawTo(pbCmd.Canvas, 0, 0);

  X := Round(22 * FUIScale);

  UIFont(pbCmd.Canvas, 11, True, Theme.Accent);
  S := ToolName(FTool);
  pbCmd.Canvas.TextOut(X, (H - pbCmd.Canvas.TextHeight(S)) div 2, S);
  Inc(X, pbCmd.Canvas.TextWidth(S) + Round(14 * FUIScale));

  UIFont(pbCmd.Canvas, 11, False, Theme.Text);
  S := Prompt;
  pbCmd.Canvas.TextOut(X, (H - pbCmd.Canvas.TextHeight(S)) div 2, S);
  Inc(X, pbCmd.Canvas.TextWidth(S) + Round(10 * FUIScale));

  if (GetTickCount64 div 500) mod 2 = 0 then Caret := '_' else Caret := ' ';
  UIFont(pbCmd.Canvas, 12, True, Theme.Accent, True);
  S := FInput + Caret;
  pbCmd.Canvas.TextOut(X, (H - pbCmd.Canvas.TextHeight(S)) div 2, S);

  { right hand side: the last message, then the live readout }
  if FCmdMsg <> '' then
  begin
    UIFont(pbCmd.Canvas, 10, False, Theme.TextDim);
    TW := pbCmd.Canvas.TextWidth(FCmdMsg);
    pbCmd.Canvas.TextOut(W - Round(18 * FUIScale) - TW,
      (H - pbCmd.Canvas.TextHeight(FCmdMsg)) div 2, FCmdMsg);
  end;
end;

{ ======================================================================== }
{ the screen                                                                }
{ ======================================================================== }

function TMainForm.SnapLabel: string;
begin
  case FSnapKind of
    snEndpoint: Result := 'ENDPOINT';
    snMidpoint: Result := 'MIDPOINT';
    snCentre:   Result := 'CENTRE';
    snCross:    Result := 'CROSSING';
    snGrid:     Result := 'GRID';
  else
    Result := '';
  end;
end;

{ Where the rubber band currently ends: a typed distance wins, then a locked
  direction, then the cursor itself. }
function TMainForm.PreviewTarget: TP3;
var
  L, Len: Double;
  Typed: Boolean;
  D: TP3;
begin
  Result := FCur;
  if FStage <> 1 then Exit;

  Typed := (FInput <> '') and ParseLen(FInput, FD.Units, L);

  if FDirLock >= 0 then
  begin
    D := AxisDir(FDirLock);
    if not Typed then
    begin
      { no number yet, so slide along the locked axis under the cursor }
      L := (FCur.X - FP1.X) * D.X + (FCur.Y - FP1.Y) * D.Y + (FCur.Z - FP1.Z) * D.Z;
      if L < 0 then L := 0;
    end;
    Result := P3(FP1.X + D.X * L, FP1.Y + D.Y * L, FP1.Z + D.Z * L);
    Exit;
  end;

  if Typed then
  begin
    D := P3(FCur.X - FP1.X, FCur.Y - FP1.Y, FCur.Z - FP1.Z);
    Len := Sqrt(D.X * D.X + D.Y * D.Y + D.Z * D.Z);
    if Len < 1E-9 then
    begin
      D := P3(1, 0, 0);
      Len := 1;
    end;
    Result := P3(FP1.X + D.X * L / Len, FP1.Y + D.Y * L / Len, FP1.Z + D.Z * L / Len);
  end;
end;

procedure TMainForm.PaintProOverlay(C: TCanvas);
var
  P: TPointF;
  SX, SY, AX, AY: Integer;
  BarLen, BarPx: Double;
  R: TRect;
  GP: TPointF;
  Hi: TPointFArray;
  S1, S2: string;
  W1, W2, BoxW, BoxH, LnH: Integer;

  procedure Rubber(const A, B: TP3);
  var
    PA, PB: TPointF;
  begin
    PA := ScreenOf(A);
    PB := ScreenOf(B);
    C.Pen.Style := psDash;
    C.Pen.Color := PixToColor(Theme.Accent);
    C.Pen.Width := 1;
    C.MoveTo(Round(PA.X), Round(PA.Y));
    C.LineTo(Round(PB.X), Round(PB.Y));
    C.Pen.Style := psSolid;
  end;

begin
  P := ScreenOf(FCur);
  SX := Round(P.X);
  SY := Round(P.Y);

  { --- live preview ---------------------------------------------------- }
  case FTool of
    ptLine:
      if FStage = 1 then Rubber(FP1, PreviewTarget);
    ptArc:
      begin
        if FStage >= 1 then Rubber(FP1, FCur);
        if FStage = 2 then Rubber(FP2, FCur);
      end;
    ptCircle:
      if FStage = 1 then
      begin
        C.Pen.Style := psDash;
        C.Pen.Color := PixToColor(Theme.Accent);
        C.Brush.Style := bsClear;
        AX := Round(Dist(FP1, FCur) * Ppu);
        P := ScreenOf(FP1);
        { in ISO a circle projects to an ellipse; the preview stays round,
          which is close enough for a rubber band }
        C.Ellipse(Round(P.X) - AX, Round(P.Y) - AX,
                  Round(P.X) + AX, Round(P.Y) + AX);
        C.Pen.Style := psSolid;
      end;
    ptMeasure:
      if FStage >= 1 then
      begin
        if FStage = 1 then Rubber(FP1, FCur) else Rubber(FP1, FP2);
      end;
    ptSelect, ptPush, ptText, ptErase: ;   // nothing to rubber-band
  end;

  { --- scale bar, bottom left ------------------------------------------ }
  BarLen := NiceBarLength(Ppu, 70 * FUIScale, 190 * FUIScale, FD.Units);
  BarPx := BarLen * Ppu;
  AX := Round(20 * FUIScale);
  AY := pbScreen.Height - Round(24 * FUIScale);
  C.Pen.Color := PixToColor(AnnotColor);
  C.Pen.Width := 2;
  C.MoveTo(AX, AY);
  C.LineTo(AX + Round(BarPx), AY);
  C.MoveTo(AX, AY - Round(5 * FUIScale));
  C.LineTo(AX, AY + Round(5 * FUIScale));
  C.MoveTo(AX + Round(BarPx), AY - Round(5 * FUIScale));
  C.LineTo(AX + Round(BarPx), AY + Round(5 * FUIScale));
  UIFont(C, 10, True, AnnotColor);
  C.TextOut(AX, AY - Round(20 * FUIScale), FormatLen(BarLen, FD.Units));
  S1 := CurScale.Name + IfThen(FD.Units = usImperial, ' = 1''-0"', '');
  C.TextOut(AX + Round(BarPx) + Round(12 * FUIScale), AY - Round(20 * FUIScale),
    Format('%s   (view %.0f%%)', [S1, FD.Zoom * 100]));

  { --- what the eraser is about to remove ------------------------------ }
  if (FTool = ptErase) and (FHoverEnt >= 0) then
  begin
    Hi := FD.Doc.Outline(Proj, FHoverEnt);
    if Length(Hi) >= 2 then
    begin
      C.Pen.Color := PixToColor(Pix(230, 70, 70));
      C.Pen.Width := Max(3, Round(3 * FUIScale));
      C.Pen.Style := psSolid;
      C.MoveTo(Round(Hi[0].X), Round(Hi[0].Y));
      for AY := 1 to High(Hi) do
        C.LineTo(Round(Hi[AY].X), Round(Hi[AY].Y));
      C.Pen.Width := 1;
    end
    else if Length(Hi) = 1 then
    begin
      C.Pen.Color := PixToColor(Pix(230, 70, 70));
      C.Brush.Style := bsClear;
      C.Ellipse(Round(Hi[0].X) - 7, Round(Hi[0].Y) - 7,
                Round(Hi[0].X) + 7, Round(Hi[0].Y) + 7);
    end;
  end;

  { --- alignment guide -------------------------------------------------- }
  if FGuide then
  begin
    GP := ScreenOf(FGuideFrom);
    C.Pen.Style := psDot;
    C.Pen.Color := PixToColor(Theme.Accent);
    C.Pen.Width := 1;
    C.MoveTo(Round(GP.X), Round(GP.Y));
    C.LineTo(SX, SY);
    C.Pen.Style := psSolid;
    C.Brush.Style := bsSolid;
    C.Brush.Color := PixToColor(Theme.Accent);
    C.FillRect(Round(GP.X) - 3, Round(GP.Y) - 3, Round(GP.X) + 4, Round(GP.Y) + 4);
    C.Brush.Style := bsClear;
  end;

  { --- what kind of point the cursor is sitting on ---------------------- }
  C.Pen.Width := 2;
  C.Pen.Color := PixToColor(Theme.Accent);
  C.Brush.Style := bsSolid;
  C.Brush.Color := PixToColor(Theme.Accent);
  case FSnapKind of
    snEndpoint:
      C.FillRect(SX - 5, SY - 5, SX + 6, SY + 6);
    snMidpoint:
      C.Polygon([Point(SX, SY - 6), Point(SX + 6, SY + 5), Point(SX - 6, SY + 5)]);
    snCentre:
      begin
        C.Brush.Style := bsClear;
        C.Ellipse(SX - 6, SY - 6, SX + 7, SY + 7);
      end;
    snCross:
      begin
        C.Pen.Width := 2;
        C.MoveTo(SX - 6, SY - 6); C.LineTo(SX + 7, SY + 7);
        C.MoveTo(SX + 6, SY - 6); C.LineTo(SX - 7, SY + 7);
      end;
    snGrid:
      C.FillRect(SX - 2, SY - 2, SX + 3, SY + 3);
    snNone: ;
  end;
  C.Brush.Style := bsClear;
  C.Pen.Width := 1;

  { --- the action chip beside the cursor -------------------------------- }
  if FErasing then Exit;
  S1 := SnapLabel;
  if FStage = 0 then
  begin
    if S1 = '' then S1 := 'FREE';
    case FTool of
      ptSelect: S2 := 'pick a tool below, or press L for a line';
      ptPush:  S2 := 'click a face to push or pull it';
      ptErase: S2 := 'click a line to delete it';
      ptText:  S2 := 'space or click - place a note here';
      ptMeasure: S2 := 'space or click - measure from here';
    else
      S2 := 'space or click - start here';
    end;
  end
  else
  begin
    if S1 = '' then S1 := 'DRAWING';
    case FTool of
      ptPush:   S2 := 'type how far, or move and click';
      ptCircle: S2 := 'type a radius, or click';
      ptArc:    S2 := 'pull the middle out, or type the bulge';
      ptText:   S2 := 'type the note, then Enter';
      ptMeasure: S2 := 'click the second point';
    else
      S2 := 'arrows set direction - type a length - Enter';
    end;
  end;

  UIFont(C, 9, True, Theme.Text);
  LnH := C.TextHeight('Xg');
  W1 := C.TextWidth(S1);
  UIFont(C, 9, False, Theme.Text);
  W2 := C.TextWidth(S2);
  BoxW := Max(W1, W2) + Round(18 * FUIScale);
  BoxH := 2 * LnH + Round(14 * FUIScale);

  AX := SX + Round(16 * FUIScale);
  AY := SY + Round(14 * FUIScale);
  if AX + BoxW > pbScreen.Width - 4 then AX := SX - BoxW - Round(16 * FUIScale);
  if AY + BoxH > pbScreen.Height - 4 then AY := SY - BoxH - Round(14 * FUIScale);
  R := Rect(AX, AY, AX + BoxW, AY + BoxH);

  C.Brush.Style := bsSolid;
  C.Brush.Color := PixToColor(MixPix(Theme.Panel, Pix(0, 0, 0), 0.15));
  C.Pen.Color := PixToColor(Theme.Accent);
  C.Pen.Width := 1;
  C.RoundRect(R.Left, R.Top, R.Right, R.Bottom, Round(8 * FUIScale),
    Round(8 * FUIScale));

  UIFont(C, 9, True, Theme.Accent);
  C.TextOut(R.Left + Round(9 * FUIScale), R.Top + Round(5 * FUIScale), S1);
  UIFont(C, 9, False, Theme.Text);
  C.TextOut(R.Left + Round(9 * FUIScale), R.Top + Round(5 * FUIScale) + LnH, S2);
end;

procedure TMainForm.pbScreenPaint(Sender: TObject);
var
  CR, Rad, SX, SY: Integer;
  Contrast: TPix;
  CP: TPointF;
begin
  if not FBooted then Exit;
  if FErasing then
  begin
    pbScreen.Canvas.Brush.Style := bsSolid;
    pbScreen.Canvas.Brush.Color := PixToColor(Theme.Bezel2);
    pbScreen.Canvas.FillRect(0, 0, pbScreen.Width, pbScreen.Height);
  end;

  FArt.DrawTo(pbScreen.Canvas, FJitterX, FJitterY);
  if FErasing then Exit;

  if FMode = mdPro then
  begin
    CP := ScreenOf(FCur);
    SX := Round(CP.X);
    SY := Round(CP.Y);
    PaintProOverlay(pbScreen.Canvas);
  end
  else
  begin
    SX := Round(FPenX);
    SY := Round(FPenY);
  end;

  { The pen cursor is composited through a scratch surface so it can be
    anti-aliased and still sit on top of the artwork. }
  if FMode = mdPro then
    Rad := Round(9 * FUIScale)
  else
    Rad := Max(4, FPenSize div 2) + Round(5 * FUIScale);
  CR := Rad + Round(8 * FUIScale);
  FOverlay.SetSize(CR * 2, CR * 2);
  FOverlay.CopyRegion(FArt, SX - CR, SY - CR, 0, 0, CR * 2, CR * 2);

  if Theme.DarkScreen then Contrast := Pix(255, 255, 255) else Contrast := Pix(20, 20, 24);
  FOverlay.BlendMode := bmNormal;
  FOverlay.Ring(CR, CR, Rad + 1.2, 2.6, MixPix(Contrast, Pix(128, 128, 128), 0.85), 0.35);
  FOverlay.Ring(CR, CR, Rad, 1.4, Contrast, 0.95);

  if FMode = mdPro then
  begin
    { crosshair arms make it easy to line up on a point }
    FOverlay.Line(CR - Rad - 5, CR, CR - Rad + 1, CR, 1.3, Contrast, 0.85);
    FOverlay.Line(CR + Rad - 1, CR, CR + Rad + 5, CR, 1.3, Contrast, 0.85);
    FOverlay.Line(CR, CR - Rad - 5, CR, CR - Rad + 1, 1.3, Contrast, 0.85);
    FOverlay.Line(CR, CR + Rad - 1, CR, CR + Rad + 5, 1.3, Contrast, 0.85);
    if FSnapKind in [snEndpoint, snMidpoint, snCentre, snCross] then
      FOverlay.Ring(CR, CR, Rad * 0.55, 2.0, Theme.Accent, 0.95);
  end
  else if FPenUp then
    FOverlay.Ring(CR, CR, Rad * 0.45, 1.2, Contrast, 0.7)
  else
    FOverlay.Disc(CR, CR, 1.6, Contrast, 0.9);

  FOverlay.DrawTo(pbScreen.Canvas, SX - CR, SY - CR);
end;

{ ======================================================================== }
{ pro mode: the tools                                                       }
{ ======================================================================== }

procedure TMainForm.SetTool(T: TProTool);
begin
  FTool := T;
  ResetTool;
  FHint := TOOL_HINTS[T];
  pbDeck.Invalidate;
  pbCmd.Invalidate;
  Invalidate;
end;

procedure TMainForm.ResetTool;
begin
  FStage := 0;
  FHoverEnt := -1;
  FGuide := False;
  FDirLock := -1;
  FInput := '';
  pbScreen.Invalidate;
  pbCmd.Invalidate;
end;

function TMainForm.Prompt: string;
begin
  case FTool of
    ptLine:
      if FStage = 0 then
        Result := 'pick a start point'
      else if FDirLock >= 0 then
        Result := 'going ' + AxisName(FDirLock) + ' - length?'
      else
        Result := 'to the next point, or type a length';
    ptArc:
      case FStage of
        0: Result := 'pick the first end';
        1: Result := 'pick the second end';
      else
        Result := 'pull the middle out, or type the bulge';
      end;
    ptCircle:
      if FStage = 0 then Result := 'pick the centre' else Result := 'radius?';
    ptText:
      if FStage = 0 then Result := 'where does the note go?' else Result := 'type the note';
    ptPush:
      if FStage = 0 then
        Result := 'click a face'
      else
        Result := 'how far?  type it, or move and click';
    ptSelect:
      Result := 'move the cursor - pick a tool to draw   (or /help)';
    ptErase:
      Result := 'click anything to delete it   (or /help)';
  else
    case FStage of
      0: Result := 'measure from...';
      1: Result := 'measure to...';
    else
      Result := 'Enter keeps it as a dimension';
    end;
  end;
end;

procedure TMainForm.NudgeCursor(DX, DY: Double);
begin
  FCur := P3(FCur.X + DX, FCur.Y + DY, FCur.Z);
  FSnapKind := snNone;
  pbScreen.Invalidate;
  InvalidateStatus;
end;

{ Shift + arrow hops to the next real point on the drawing in that direction,
  which is how you get around with only a keyboard or a touch screen. }
procedure TMainForm.JumpSnap(DX, DY: Integer);
var
  I: Integer;
  Here, P: TPointF;
  Best, D, Along, Across: Double;
  Target: TP3;
  Found: Boolean;

  procedure Try_(const Q: TP3);
  begin
    P := ScreenOf(Q);
    Along := (P.X - Here.X) * DX + (P.Y - Here.Y) * DY;
    Across := Abs((P.X - Here.X) * DY - (P.Y - Here.Y) * DX);
    if Along < 2 then Exit;
    D := Along + Across * 2.5;
    if D < Best then
    begin
      Best := D;
      Target := Q;
      Found := True;
    end;
  end;

begin
  Here := ScreenOf(FCur);
  Best := 1E30;
  Found := False;
  for I := 0 to FD.Doc.Live - 1 do
  begin
    Try_(FD.Doc[I].A);
    Try_(FD.Doc[I].B);
    if FD.Doc[I].Kind = ekArc then
      Try_(FD.Doc[I].C);
  end;
  if Found then
  begin
    FCur := Target;
    FSnapKind := snEndpoint;
    FCmdMsg := 'Snapped to a point.';
  end
  else
    FCmdMsg := 'Nothing that way.';
  pbScreen.Invalidate;
  InvalidateStatus;
end;

procedure TMainForm.ProClick;
var
  I: Integer;
  P: TPointF;
begin
  case FTool of
    ptSelect:
      FCmdMsg := 'Here: ' + FormatLen(FCur.X, FD.Units) + ', ' +
        FormatLen(FCur.Y, FD.Units);

    ptErase:
      begin
        { hit test where the pointer actually is - snapping to a nearby
          endpoint would otherwise make it miss the thing being clicked }
        P := PtF(FMouseSX, FMouseSY);
        I := FD.Doc.HitTest(Proj, P.X, P.Y, 9 * FUIScale);
        if I >= 0 then
        begin
          PushUndo;
          FD.Doc.Delete(I);
          RenderPro;
          RecomposeAll;
          FCmdMsg := 'Deleted.';
        end
        else
          FCmdMsg := 'Nothing under the cursor.';
      end;

    ptLine:
      if FStage = 0 then
      begin
        FP1 := FCur;
        FStage := 1;
        FDirLock := -1;
      end
      else
        ProCommit;

    ptArc:
      if FStage = 0 then
      begin
        FP1 := FCur;
        FStage := 1;
      end
      else if FStage = 1 then
      begin
        FP2 := FCur;
        FStage := 2;
      end
      else
        ProCommit;

    ptCircle:
      if FStage = 0 then
      begin
        FP1 := FCur;
        FStage := 1;
      end
      else
        ProCommit;

    ptText:
      if FStage = 0 then
      begin
        FP1 := FCur;
        FStage := 1;
        FInput := '';
      end
      else
        ProCommit;

    ptPush:
      if FStage = 0 then
      begin
        FPushFace := FD.Doc.HitFace(Proj, FMouseSX, FMouseSY);
        if FPushFace < 0 then
          FCmdMsg := 'No face there.  Close a loop of lines to make one.'
        else
        begin
          FP1 := FCur;
          FStage := 1;
          FCmdMsg := 'Type a distance, or move and click.';
        end;
      end
      else
        ProCommit;

    ptMeasure:
      if FStage = 0 then
      begin
        FP1 := FCur;
        FStage := 1;
      end
      else if FStage = 1 then
      begin
        FP2 := FCur;
        FStage := 2;
        FCmdMsg := Format('%s   (dX %s  dY %s  dZ %s)',
          [FormatLen(Dist(FP1, FP2), FD.Units),
           FormatLen(Abs(FP2.X - FP1.X), FD.Units),
           FormatLen(Abs(FP2.Y - FP1.Y), FD.Units),
           FormatLen(Abs(FP2.Z - FP1.Z), FD.Units)]);
      end
      else
      begin
        FP1 := FCur;
        FStage := 1;
      end;
  end;
  pbScreen.Invalidate;
  pbCmd.Invalidate;
  FLastStatus := 0;
  InvalidateStatus;
end;

procedure TMainForm.ProCommit;
var
  T, C: TP3;
  Loop: TP3Array;
  L, R, A0, Sweep, Bulge, U1, V1, U2, V2, UC, VC, NU, NV, Ln: Double;
  Ok: Boolean;
begin
  case FTool of
    ptLine:
      begin
        T := PreviewTarget;
        if Dist(FP1, T) > 1E-9 then
        begin
          PushUndo;
          FD.Doc.AddLine(FP1, T, FInkColor, FPenSize, FD.ShowDims);
          FCmdMsg := FormatLen(Dist(FP1, T), FD.Units);
          { closing a loop makes a face you can push/pull }
          if FD.Doc.ClosedChain(Max(SnapStep, 1E-6) * 0.51, Loop) then
          begin
            FD.Doc.AddFace(Loop, FInkColor);
            FCmdMsg := FCmdMsg + '   loop closed - face made';
          end;
          RenderPro;
          RecomposeAll;
          FP1 := T;
          FCur := T;
        end;
        FInput := '';
        FDirLock := -1;
      end;

    ptArc:
      begin
        { bulge is how far the middle is pulled off the chord }
        PlaneCoords(FD.Plane, FP1, U1, V1);
        PlaneCoords(FD.Plane, FP2, U2, V2);
        PlaneCoords(FD.Plane, FCur, UC, VC);
        Ln := Sqrt(Sqr(U2 - U1) + Sqr(V2 - V1));
        if Ln < 1E-9 then
        begin
          ResetTool;
          Exit;
        end;
        NU := -(V2 - V1) / Ln;
        NV := (U2 - U1) / Ln;
        Bulge := (UC - (U1 + U2) / 2) * NU + (VC - (V1 + V2) / 2) * NV;
        if (FInput <> '') and ParseLen(FInput, FD.Units, L) then
          Bulge := Sign(Bulge) * L;
        if Abs(Bulge) < 1E-9 then Bulge := Ln / 8;

        Ok := ArcFromChord(FP1, FP2, Bulge, FD.Plane, C, R, A0, Sweep);
        if Ok then
        begin
          PushUndo;
          FD.Doc.AddArc(C, R, A0, Sweep, FD.Plane, FInkColor, FPenSize);
          RenderPro;
          RecomposeAll;
          FCmdMsg := 'Arc radius ' + FormatLen(R, FD.Units);
        end;
        ResetTool;
      end;

    ptCircle:
      begin
        if (FInput <> '') and ParseLen(FInput, FD.Units, L) then
          R := L
        else
          R := Dist(FP1, FCur);
        if R > 1E-9 then
        begin
          PushUndo;
          FD.Doc.AddArc(FP1, R, 0, 2 * Pi, FD.Plane, FInkColor, FPenSize);
          RenderPro;
          RecomposeAll;
          FCmdMsg := 'Circle radius ' + FormatLen(R, FD.Units);
        end;
        ResetTool;
      end;

    ptPush:
      begin
        if (FInput <> '') and ParseLen(FInput, FD.Units, L) then
          R := L
        else
        begin
          { how far the cursor has moved along the face normal }
          C := FD.Doc.FaceNormal(FPushFace);
          R := (FCur.X - FP1.X) * C.X + (FCur.Y - FP1.Y) * C.Y +
               (FCur.Z - FP1.Z) * C.Z;
        end;
        if Abs(R) > 1E-9 then
        begin
          PushUndo;
          if FD.Doc.PushPull(FPushFace, R) then
          begin
            RenderPro;
            RecomposeAll;
            FCmdMsg := 'Pulled ' + FormatLen(Abs(R), FD.Units);
          end;
        end;
        FPushFace := -1;
        ResetTool;
      end;

    ptText:
      begin
        if Trim(FInput) <> '' then
        begin
          PushUndo;
          FD.Doc.AddText(FP1, Trim(FInput), FInkColor);
          RenderPro;
          RecomposeAll;
          FCmdMsg := 'Note added.';
        end;
        ResetTool;
      end;

    ptMeasure:
      begin
        if FStage = 2 then
        begin
          PushUndo;
          FD.Doc.AddDim(FP1, FP2, FInkColor);
          RenderPro;
          RecomposeAll;
          FCmdMsg := 'Kept as a dimension.';
        end;
        ResetTool;
      end;
    ptSelect, ptErase: ;   // these act on the click; nothing to commit
  end;
  pbScreen.Invalidate;
  pbCmd.Invalidate;
  pbDeck.Invalidate;
  FLastStatus := 0;
  InvalidateStatus;
end;

{ A handful of typed words, so the command bar is useful and not decorative. }
function TMainForm.RunCommand(const S: string): Boolean;
var
  W, Rest: string;
  P, I: Integer;
begin
  Result := True;
  W := LowerCase(Trim(S));
  Rest := '';
  P := Pos(' ', W);
  if P > 0 then
  begin
    Rest := Trim(Copy(W, P + 1, MaxInt));
    W := Copy(W, 1, P - 1);
  end;

  if (W = 'line') or (W = 'l') then SetTool(ptLine)
  else if (W = 'arc') or (W = 'a') then SetTool(ptArc)
  else if (W = 'circle') or (W = 'c') then SetTool(ptCircle)
  else if (W = 'text') or (W = 'note') or (W = 'n') then SetTool(ptText)
  else if (W = 'erase') or (W = 'e') or (W = 'del') then SetTool(ptErase)
  else if (W = 'measure') or (W = 'm') or (W = 'tape') then SetTool(ptMeasure)
  else if (W = 'push') or (W = 'pull') or (W = 'pushpull') or (W = 'p') then
    SetTool(ptPush)
  else if (W = 'undo') or (W = 'u') then DoUndo
  else if W = 'redo' then DoRedo
  else if (W = 'fit') or (W = 'zoom') then FitView
  else if W = 'iso' then SetView(vkIso)
  else if (W = '3d') or (W = 'orbit') then SetView(vkOrbit)
  else if (W = 'plan') or (W = '2d') or (W = 'flat') then SetView(vkPlan)
  else if W = 'plane' then
  begin
    if Rest = 'xz' then FD.Plane := plXZ
    else if Rest = 'yz' then FD.Plane := plYZ
    else if Rest = 'xy' then FD.Plane := plXY
    else FD.Plane := TPlane((Ord(FD.Plane) + 1) mod 3);
    FCmdMsg := 'Working plane: ' + Copy('XYXZYZ', Ord(FD.Plane) * 2 + 1, 2);
  end
  else if (W = 'origin') or (W = 'o') then SetOriginHere
  else if W = 'grid' then
  begin
    FShowGrid := not FShowGrid;
    RepaintPaper;
    RecomposeAll;
    pbDeck.Invalidate;
  end
  else if W = 'dim' then
  begin
    FD.ShowDims := not FD.ShowDims;
    RenderPro;
    RecomposeAll;
    pbDeck.Invalidate;
  end
  else if W = 'units' then SetUnits(TUnitSystem(1 - Ord(FD.Units)))
  else if (W = 'new') or (W = 'tab') then NewDrawing
  else if W = 'close' then CloseDrawing(FTabIdx)
  else if W = 'clear' then StartErase
  else if W = 'save' then DoSave
  else if W = 'print' then DoPrint
  else if W = 'scale' then
  begin
    for I := 0 to SCALE_COUNT - 1 do
      if LowerCase(ScaleTable(FD.Units, I).Name) = Rest then
      begin
        SetScaleIdx(I);
        Exit;
      end;
    FCmdMsg := 'Scales: 1/16" 1/8" 1/4" 1/2" 1"';
  end
  else if (W = 'help') or (W = '?') then ShowAbout
  else
    Result := False;
end;

procedure TMainForm.CommandEnter;
var
  L: Double;
begin
  if (FTool = ptText) and (FStage = 1) then
  begin
    ProCommit;
    Exit;
  end;

  if FInput = '' then
  begin
    if FStage > 0 then ProCommit else ProClick;
    Exit;
  end;

  if Copy(FInput, 1, 1) = '/' then
  begin
    if not RunCommand(Copy(FInput, 2, MaxInt)) then
      FCmdMsg := 'I do not know "' + Copy(FInput, 2, MaxInt) + '"';
    FInput := '';
    pbCmd.Invalidate;
    Exit;
  end;

  if ParseLen(FInput, FD.Units, L) then
  begin
    if FStage > 0 then
      ProCommit
    else
      FCmdMsg := FInput + ' = ' + FormatLen(L, FD.Units) + ' (pick a start point first)';
    FInput := '';
    pbCmd.Invalidate;
    Exit;
  end;

  if RunCommand(FInput) then
    FInput := ''
  else
    FCmdMsg := 'I do not know "' + FInput + '"';
  pbCmd.Invalidate;
end;

{ ======================================================================== }
{ mouse on the screen                                                       }
{ ======================================================================== }

procedure TMainForm.pbScreenMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  { a press supersedes whatever motion has not been serviced yet }
  FMoveX := X;
  FMoveY := Y;
  FMovePending := False;

  if Button in [mbMiddle, mbRight] then
  begin
    if FMode = mdPro then
    begin
      FOrbiting := (Button = mbMiddle) and (FD.View = vkOrbit);
      FPanning := not FOrbiting;
      FPanRefX := X;
      FPanRefY := Y;
      pbScreen.Cursor := crSizeAll;
    end
    else if Button = mbRight then
      FPenUp := True;
    Exit;
  end;
  if Button <> mbLeft then Exit;

  if FMode = mdPro then
  begin
    FMouseSX := X;
    FMouseSY := Y;
    FCur := ResolveSnapAt(X, Y);
    ProClick;
    Exit;
  end;

  FFreehand := True;
  BeginStroke;
  FPenX := EnsureRange(X, 0, FArt.Width - 1);
  FPenY := EnsureRange(Y, 0, FArt.Height - 1);
  FScreenDirty := True;
end;

{ Motion handler: record and return.  Nothing here may paint, allocate,
  hit-test or snap.  See ServiceMotion, which the tick calls. }
procedure TMainForm.pbScreenMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  FMoveX := X;
  FMoveY := Y;
  FMovePending := True;
end;

{ Everything the motion handler used to do, run at most once per tick off
  the newest pointer position.  Coalescing here is free: the intermediate
  positions only ever fed a repaint that was immediately overdrawn. }
procedure TMainForm.ServiceMotion;
var
  X, Y: Integer;
begin
  if not FMovePending then Exit;
  FMovePending := False;
  X := FMoveX;
  Y := FMoveY;

  if FOrbiting then
  begin
    FD.Az := FD.Az + (X - FPanRefX) * 0.010;
    FD.El := EnsureRange(FD.El + (Y - FPanRefY) * 0.010, -1.45, 1.45);
    FPanRefX := X;
    FPanRefY := Y;
    RepaintPaper;
    RenderPro;
    RecomposeAll;
    Invalidate;
    Exit;
  end;

  if FPanning then
  begin
    PanBy(X - FPanRefX, Y - FPanRefY);
    FPanRefX := X;
    FPanRefY := Y;
    Exit;
  end;

  if FMode = mdPro then
  begin
    FMouseSX := X;
    FMouseSY := Y;
    FCur := ResolveSnapAt(X, Y);
    if FTool = ptErase then
      FHoverEnt := FD.Doc.HitTest(Proj, X, Y, 9 * FUIScale)
    else
      FHoverEnt := -1;
    FScreenDirty := True;
    InvalidateStatus;
    Exit;
  end;

  if FFreehand then
    PenTo(X, Y, not FPenUp);
end;

procedure TMainForm.pbScreenMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  { the release position is the last thing the stroke saw }
  FMoveX := X;
  FMoveY := Y;
  FMovePending := True;
  ServiceMotion;

  if (FPanning or FOrbiting) and (Button in [mbMiddle, mbRight]) then
  begin
    FPanning := False;
    FOrbiting := False;
    pbScreen.Cursor := crCross;
    Exit;
  end;
  if Button = mbRight then FPenUp := False;
  if FFreehand then
  begin
    FFreehand := False;
    EndStroke;
  end;
end;

procedure TMainForm.pbScreenMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  if FMode <> mdPro then Exit;
  if WheelDelta > 0 then
    ZoomAt(1.15, MousePos.X, MousePos.Y)
  else
    ZoomAt(1 / 1.15, MousePos.X, MousePos.Y);
  Handled := True;
end;

{ ======================================================================== }
{ window painting                                                           }
{ ======================================================================== }

function TMainForm.StatusLine: string;
var
  L, A: Double;
begin
  if FMode = mdToy then
  begin
    Result := Format('X %4d   Y %4d   %s   %s',
      [Round(FPenX), Round(FPenY), Theme.Name, STYLE_NAMES[FStyle]]);
    Exit;
  end;

  if FD.View <> vkPlan then
    Result := Format('X %s   Y %s   Z %s',
      [FormatLen(FCur.X, FD.Units), FormatLen(FCur.Y, FD.Units),
       FormatLen(FCur.Z, FD.Units)])
  else
    Result := Format('X %s   Y %s',
      [FormatLen(FCur.X, FD.Units), FormatLen(FCur.Y, FD.Units)]);

  if (FStage = 1) and (FTool in [ptLine, ptMeasure]) then
    Result := Result + '   LEN ' + FormatLen(Dist(FP1, PreviewTarget), FD.Units);

  L := FD.Doc.ChainLength;
  if L > 0 then
  begin
    Result := Result + '   RUN ' + FormatLen(L, FD.Units);
    if FD.Doc.ChainClosed(Max(SnapStep, 1E-6)) then
    begin
      A := FD.Doc.ChainArea;
      if A > 0 then
        Result := Result + '   AREA ' + FormatArea(A, FD.Units);
    end;
  end;
end;

procedure TMainForm.FormPaint(Sender: TObject);
var
  M, TitleH, Y, TW: Integer;
  S: string;
begin
  if not FBooted then Exit;
  FShell.DrawTo(Canvas, 0, 0);

  M := Round(22 * FUIScale);
  TitleH := Round(84 * FUIScale);

  UIFont(Canvas, 20, True, Theme.Text);
  Y := Round(12 * FUIScale);
  TrackedText(Canvas, M + Round(4 * FUIScale), Y, UpperCase(APP_NAME),
    Round(3 * FUIScale));

  UIFont(Canvas, 9, False, Theme.TextDim);
  Canvas.TextOut(M + Round(5 * FUIScale), Y + Round(28 * FUIScale),
    'Noella Stone Software, Ltd.  -  est. 2021');

  UIFont(Canvas, 10, False, Theme.TextDim);
  S := FHint;
  TW := Canvas.TextWidth(S);
  if TW < ClientWidth - 2 * M - Round(220 * FUIScale) then
    Canvas.TextOut(ClientWidth - M - TW, Round(46 * FUIScale), S);

  UIFont(Canvas, 11, True, Theme.Text, True);
  S := StatusLine;
  Canvas.TextOut(ClientWidth - M - Canvas.TextWidth(S), Round(63 * FUIScale), S);

  UIFont(Canvas, 9, True, MixPix(Theme.Text, Theme.Bezel1, 0.35));
  S := 'MAGIC SCREEN';
  Canvas.TextOut(ClientWidth - M - Round(146 * FUIScale) +
    (Round(132 * FUIScale) - Canvas.TextWidth(S)) div 2,
    pbScreen.Top + pbScreen.Height + Round(4 * FUIScale), S);
  if TitleH = 0 then Exit;
end;

{ ======================================================================== }
{ toy mode drawing                                                          }
{ ======================================================================== }

procedure TMainForm.SetInk(C: TColor; Auto: Boolean);
begin
  FInkColor := C;
  FInkAuto := Auto;
  FInkPix := ColorToPix(C);
  dlgColor.Color := C;
  pbDeck.Invalidate;
end;

procedure TMainForm.SetStyle(V: TPenStyle);
begin
  FStyle := V;
  FHint := STYLE_HINTS[V];
  pbDeck.Invalidate;
  Invalidate;
end;

procedure TMainForm.SetSymmetry(V: Integer);
begin
  FSym := V;
  pbDeck.Invalidate;
end;

procedure TMainForm.SetPenSize(V: Integer);
begin
  V := EnsureRange(V, MIN_PEN, MAX_PEN);
  if V = FPenSize then Exit;
  FPenSize := V;
  pbDeck.Invalidate;
  pbScreen.Invalidate;
end;

procedure TMainForm.SetUnits(U: TUnitSystem);
begin
  FD.Units := U;
  RenderPro;
  RecomposeAll;
  RebuildDeck;
  pbDeck.Invalidate;
  pbCmd.Invalidate;
  Invalidate;
end;

procedure TMainForm.StampSegment(X0, Y0, X1, Y1: Single);
var
  W, D, T, PX, PY, RR: Single;
  I, N: Integer;
  C: TPix;
begin
  W := FPenSize;
  case FStyle of
    psClassic:
      begin
        FInkToy.BlendMode := bmNormal;
        FInkToy.Line(X0, Y0, X1, Y1, W, FInkPix);
      end;

    psNeon:
      begin
        { alpha-based glow, so it reads the same over any paper and survives
          a change of theme }
        FInkToy.BlendMode := bmMaxAlpha;
        FInkToy.Line(X0, Y0, X1, Y1, W * 5.0, FInkPix, 0.10);
        FInkToy.Line(X0, Y0, X1, Y1, W * 3.0, FInkPix, 0.22);
        FInkToy.Line(X0, Y0, X1, Y1, W * 1.8, FInkPix, 0.45);
        FInkToy.Line(X0, Y0, X1, Y1, Max(1.0, W * 0.8),
          MixPix(FInkPix, Pix(255, 255, 255), 0.45), 1.0);
        FInkToy.BlendMode := bmNormal;
      end;

    psRainbow:
      begin
        FInkToy.BlendMode := bmNormal;
        C := HSVPix(FHue, 0.88, 1.0);
        FInkToy.Line(X0, Y0, X1, Y1, W, C);
      end;

    psSparkle:
      begin
        FInkToy.BlendMode := bmNormal;
        FInkToy.Line(X0, Y0, X1, Y1, Max(1.2, W * 0.55), FInkPix, 1.0);
        D := Sqrt(Sqr(X1 - X0) + Sqr(Y1 - Y0));
        N := Max(1, Round(D * 0.9));
        for I := 1 to N do
        begin
          T := Random;
          PX := X0 + (X1 - X0) * T + (Random - 0.5) * W * 3.2;
          PY := Y0 + (Y1 - Y0) * T + (Random - 0.5) * W * 3.2;
          FInkToy.Disc(PX, PY, 0.6 + Random * W * 0.28,
            HSVPix(FHue + Random * 60 - 30, 0.35 + Random * 0.5, 1.0),
            0.35 + Random * 0.55);
        end;
      end;

    psChalk:
      begin
        FInkToy.BlendMode := bmNormal;
        FInkToy.Line(X0, Y0, X1, Y1, Max(1.0, W * 0.55), FInkPix, 0.30);
        D := Sqrt(Sqr(X1 - X0) + Sqr(Y1 - Y0));
        N := Max(2, Round(D * (2.0 + W * 0.9)));
        for I := 1 to N do
        begin
          T := Random;
          RR := (Random + Random - 1) * W * 0.65;
          PX := X0 + (X1 - X0) * T - (Y1 - Y0) / Max(0.001, D) * RR;
          PY := Y0 + (Y1 - Y0) * T + (X1 - X0) / Max(0.001, D) * RR;
          FInkToy.Disc(PX, PY, 0.35 + Random * 0.75, FInkPix, 0.12 + Random * 0.40);
        end;
      end;
  end;
  FInkToy.BlendMode := bmNormal;
end;

procedure TMainForm.EmitSegment(X0, Y0, X1, Y1: Single);
var
  I: Integer;
  A, Co, Si, CX, CY: Single;
  AX0, AY0, AX1, AY1: Single;
begin
  if FSym <= 1 then
  begin
    StampSegment(X0, Y0, X1, Y1);
    if FMirror then
      StampSegment(FArt.Width - X0, Y0, FArt.Width - X1, Y1);
    Exit;
  end;

  CX := FArt.Width / 2;
  CY := FArt.Height / 2;
  for I := 0 to FSym - 1 do
  begin
    A := I * 2 * Pi / FSym;
    Co := Cos(A);
    Si := Sin(A);
    AX0 := CX + (X0 - CX) * Co - (Y0 - CY) * Si;
    AY0 := CY + (X0 - CX) * Si + (Y0 - CY) * Co;
    AX1 := CX + (X1 - CX) * Co - (Y1 - CY) * Si;
    AY1 := CY + (X1 - CX) * Si + (Y1 - CY) * Co;
    StampSegment(AX0, AY0, AX1, AY1);
    if FMirror then
      StampSegment(2 * CX - AX0, AY0, 2 * CX - AX1, AY1);
  end;
end;

procedure TMainForm.PenTo(NX, NY: Single; Drawing: Boolean);
var
  OX, OY, D: Single;
begin
  NX := EnsureRange(NX, 0, FArt.Width - 1);
  NY := EnsureRange(NY, 0, FArt.Height - 1);
  OX := FPenX;
  OY := FPenY;
  if (Abs(NX - OX) < 0.01) and (Abs(NY - OY) < 0.01) then Exit;

  FPenX := NX;
  FPenY := NY;
  if Drawing and not FErasing then
  begin
    D := Sqrt(Sqr(NX - OX) + Sqr(NY - OY));
    FHue := FHue + D * 0.45;
    EmitSegment(OX, OY, NX, NY);
    Recompose;
  end;
  FScreenDirty := True;
  InvalidateStatus;
end;

procedure TMainForm.ToggleAuto;
var
  I: Integer;
begin
  if FMode <> mdToy then Exit;
  FAuto := not FAuto;
  if FAuto then
  begin
    BeginStroke;
    FAutoT := 0;
    for I := 0 to 4 do
      FAutoP[I] := 0;
    FAutoKind := Random(3);
    FAutoP[0] := 0.22 + Random * 0.20;
    FAutoP[1] := 0.08 + Random * 0.18;
    FAutoP[2] := 2 + Random(9);
    FAutoP[3] := 1.6 + Random * 2.2;
    FAutoP[4] := 0.4 + Random * 1.4;
    FHint := 'Auto-draw is running.  Press A or the wand again to stop.';
  end
  else
  begin
    EndStroke;
    FHint := TOY_HINT;
  end;
  pbDeck.Invalidate;
  Invalidate;
end;

procedure TMainForm.StepAuto(Dt: Single);
var
  CX, CY, S, T, R, NX, NY: Single;
begin
  CX := FArt.Width / 2;
  CY := FArt.Height / 2;
  S := Min(FArt.Width, FArt.Height);
  FAutoT := FAutoT + Dt * FAutoP[3];
  T := FAutoT;

  case FAutoKind of
    1:
      begin
        R := S * (FAutoP[0] + FAutoP[1]) * Cos(FAutoP[2] * T * 0.5);
        NX := CX + R * Cos(T);
        NY := CY + R * Sin(T);
      end;
    2:
      begin
        NX := CX + S * (FAutoP[0] + FAutoP[1]) * Sin(T * FAutoP[2] * 0.4);
        NY := CY + S * FAutoP[0] * Sin(T * 1.7 + FAutoP[4]);
      end;
  else
    begin
      NX := CX + S * FAutoP[0] * Cos(T) + S * FAutoP[1] * Cos(T * FAutoP[2]);
      NY := CY + S * FAutoP[0] * Sin(T) + S * FAutoP[1] * Sin(T * FAutoP[2]);
    end;
  end;

  NX := NX + S * 0.05 * Sin(FAutoT * FAutoP[4] * 0.11);
  NY := NY + S * 0.05 * Cos(FAutoT * FAutoP[4] * 0.09);
  PenTo(NX, NY, True);
end;

{ ======================================================================== }
{ history                                                                   }
{ ======================================================================== }

procedure TMainForm.ClearHistory;
begin
  FUndoToyTop := 0;
  FRedoToyTop := 0;
  FD.UndoTop := 0;
  FD.RedoTop := 0;
  pbDeck.Invalidate;
end;

procedure TMainForm.PushUndo;
var
  I: Integer;
begin
  if FMode = mdPro then
  begin
    if FD.UndoTop >= UNDO_LEVELS then
    begin
      for I := 0 to UNDO_LEVELS - 2 do
        FD.Undo[I] := FD.Undo[I + 1];
      FD.UndoTop := UNDO_LEVELS - 1;
    end;
    FD.Undo[FD.UndoTop] := FD.Doc.Snapshot;
    Inc(FD.UndoTop);
    FD.RedoTop := 0;
  end
  else
  begin
    if FUndoToyTop >= UNDO_LEVELS then
    begin
      for I := 0 to UNDO_LEVELS - 2 do
        FUndoToy[I] := FUndoToy[I + 1];
      FUndoToyTop := UNDO_LEVELS - 1;
    end;
    FInkToy.Snapshot(FUndoToy[FUndoToyTop]);
    Inc(FUndoToyTop);
    FRedoToyTop := 0;
  end;
  pbDeck.Invalidate;
end;

procedure TMainForm.BeginStroke;
begin
  if FStrokeOpen or FErasing then Exit;
  FStrokeOpen := True;
  PushUndo;
end;

procedure TMainForm.EndStroke;
begin
  FStrokeOpen := False;
end;

function TMainForm.CanUndo: Boolean;
begin
  if FMode = mdPro then Result := FD.UndoTop > 0 else Result := FUndoToyTop > 0;
end;

function TMainForm.CanRedo: Boolean;
begin
  if FMode = mdPro then Result := FD.RedoTop > 0 else Result := FRedoToyTop > 0;
end;

procedure TMainForm.DoUndo;
begin
  if not CanUndo then Exit;
  if FMode = mdPro then
  begin
    if FD.RedoTop < UNDO_LEVELS then
    begin
      FD.Redo[FD.RedoTop] := FD.Doc.Snapshot;
      Inc(FD.RedoTop);
    end;
    Dec(FD.UndoTop);
    FD.Doc.RestoreSnap(FD.Undo[FD.UndoTop]);
    ResetTool;
    RenderPro;
  end
  else
  begin
    if FRedoToyTop < UNDO_LEVELS then
    begin
      FInkToy.Snapshot(FRedoToy[FRedoToyTop]);
      Inc(FRedoToyTop);
    end;
    Dec(FUndoToyTop);
    FInkToy.Restore(FUndoToy[FUndoToyTop]);
  end;
  RecomposeAll;
  pbDeck.Invalidate;
end;

procedure TMainForm.DoRedo;
begin
  if not CanRedo then Exit;
  if FMode = mdPro then
  begin
    if FD.UndoTop < UNDO_LEVELS then
    begin
      FD.Undo[FD.UndoTop] := FD.Doc.Snapshot;
      Inc(FD.UndoTop);
    end;
    Dec(FD.RedoTop);
    FD.Doc.RestoreSnap(FD.Redo[FD.RedoTop]);
    ResetTool;
    RenderPro;
  end
  else
  begin
    if FUndoToyTop < UNDO_LEVELS then
    begin
      FInkToy.Snapshot(FUndoToy[FUndoToyTop]);
      Inc(FUndoToyTop);
    end;
    Dec(FRedoToyTop);
    FInkToy.Restore(FRedoToy[FRedoToyTop]);
  end;
  RecomposeAll;
  pbDeck.Invalidate;
end;

{ ======================================================================== }
{ shake to erase                                                            }
{ ======================================================================== }

procedure TMainForm.StartErase;
begin
  if FErasing then Exit;
  PushUndo;
  FErasing := True;
  FEraseT := 0;
  FAuto := False;
  if FMode = mdPro then
    FHint := 'Clearing the sheet...'
  else
    FHint := 'Shaking it clean...';
  Invalidate;
end;

procedure TMainForm.StepErase(Dt: Single);
var
  Amp: Single;
begin
  FEraseT := FEraseT + Dt / 0.7;
  if FEraseT >= 1 then
  begin
    FErasing := False;
    FJitterX := 0;
    FJitterY := 0;
    if FMode = mdPro then
    begin
      FD.Doc.Clear;
      RenderPro;
      ResetTool;
    end
    else
      FInkToy.ClearTransparent;
    RecomposeAll;
    if FMode = mdPro then FHint := TOOL_HINTS[FTool] else FHint := TOY_HINT;
    Invalidate;
    pbDeck.Invalidate;
    Exit;
  end;

  Amp := Round(9 * FUIScale) * (1 - FEraseT);
  FJitterX := Round((Random - 0.5) * 2 * Amp);
  FJitterY := Round((Random - 0.5) * 2 * Amp);

  ActiveInk.SmearDown(1 + Round(6 * FEraseT));
  ActiveInk.FadeAlpha(0.06 + 0.14 * FEraseT);
  RecomposeAll;
  if not Theme.DarkScreen then
    FArt.Grain(0.14 * (1 - FEraseT), 0.05);
  pbScreen.Invalidate;
end;

{ ======================================================================== }
{ the heartbeat                                                             }
{ ======================================================================== }

procedure TMainForm.tmrTickTimer(Sender: TObject);
var
  Dt, Speed, DX, DY: Single;
begin
  Dt := TICK_MS / 1000;

  ServiceMotion;
  try

  if FErasing then
  begin
    StepErase(Dt);
    Exit;
  end;

  if FMode = mdPro then
  begin
    { keep the command bar caret blinking }
    if (GetTickCount64 div 500) <> ((GetTickCount64 - TICK_MS) div 500) then
      pbCmd.Invalidate;
    Exit;
  end;

  if FAuto then
  begin
    StepAuto(Dt);
    Exit;
  end;

  if not (FKeyLeft or FKeyRight or FKeyUp or FKeyDown) then Exit;

  Speed := BASE_SPEED;
  if FBoost then Speed := Speed * 3.4;
  if FPrecise then Speed := Speed * 0.28;

  DX := 0;
  DY := 0;
  if FKeyLeft then DX := DX - Speed * Dt;
  if FKeyRight then DX := DX + Speed * Dt;
  if FKeyUp then DY := DY - Speed * Dt;
  if FKeyDown then DY := DY + Speed * Dt;

  FKnobAngle[0] := FKnobAngle[0] + DX / KNOB_PX_PER_RAD;
  FKnobAngle[1] := FKnobAngle[1] + DY / KNOB_PX_PER_RAD;

  PenTo(FPenX + DX, FPenY + DY, not FPenUp);
  if DX <> 0 then pbKnobL.Invalidate;
  if DY <> 0 then pbKnobR.Invalidate;

  finally
    { one repaint per tick at most, whatever asked for it }
    if FScreenDirty then
    begin
      FScreenDirty := False;
      pbScreen.Invalidate;
    end;
  end;
end;

{ ======================================================================== }
{ keyboard                                                                  }
{ ======================================================================== }

procedure TMainForm.FormKeyPress(Sender: TObject; var Key: char);
begin
  if FMode <> mdPro then Exit;

  { while a note is being typed, everything is text }
  if (FTool = ptText) and (FStage = 1) then
  begin
    if Key >= ' ' then
    begin
      FInput := FInput + Key;
      pbCmd.Invalidate;
      Key := #0;
    end;
    Exit;
  end;

  { A leading '/' starts a typed command; after that every character is
    text, otherwise letters stay as single-key tool shortcuts. }
  if (Copy(FInput, 1, 1) = '/') and (Key >= ' ') then
  begin
    FInput := FInput + Key;
    pbCmd.Invalidate;
    Key := #0;
    Exit;
  end;

  if Key in ['0'..'9', '.', '/', '''', '"', ' ', '-'] then
  begin
    FInput := FInput + Key;
    FCmdMsg := '';
    pbCmd.Invalidate;
    pbScreen.Invalidate;
    Key := #0;
  end;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
var
  Handled: Boolean;
  Step: Double;

  { Which model axis an arrow means depends on the view. }
  function ArrowAxis(K: word): Integer;
  begin
    if FD.View = vkIso then
      case K of
        VK_RIGHT: Result := 0;
        VK_LEFT: Result := 1;
        VK_PRIOR: Result := 2;
        VK_NEXT: Result := 3;
        VK_UP: Result := 4;
      else
        Result := 5;
      end
    else
      case K of
        VK_RIGHT: Result := 0;
        VK_LEFT: Result := 1;
        VK_UP: Result := 2;
      else
        Result := 3;
      end;
  end;

  procedure Arrow(K: word);
  var
    D: TP3;
  begin
    if (FTool = ptLine) and (FStage = 1) then
    begin
      FDirLock := ArrowAxis(K);
      FCmdMsg := '';
    end
    else
    begin
      D := AxisDir(ArrowAxis(K));
      Step := SnapStep;
      if Step <= 0 then Step := 1 / 12;
      if ssShift in Shift then
      begin
        JumpSnap(Round(Sign(ScreenOf(P3(FCur.X + D.X, FCur.Y + D.Y, FCur.Z + D.Z)).X
                             - ScreenOf(FCur).X)),
                 Round(Sign(ScreenOf(P3(FCur.X + D.X, FCur.Y + D.Y, FCur.Z + D.Z)).Y
                             - ScreenOf(FCur).Y)));
        Exit;
      end;
      if ssCtrl in Shift then Step := Step / 4;
      FCur := P3(FCur.X + D.X * Step, FCur.Y + D.Y * Step, FCur.Z + D.Z * Step);
      FSnapKind := snNone;
      FMouseSX := Round(ScreenOf(FCur).X);
      FMouseSY := Round(ScreenOf(FCur).Y);
    end;
    pbScreen.Invalidate;
    pbCmd.Invalidate;
    InvalidateStatus;
  end;

begin
  Handled := True;

  if ssCtrl in Shift then
  begin
    case Key of
      VK_Z: DoUndo;
      VK_Y: DoRedo;
      VK_S: if ssShift in Shift then DoSaveAs else DoSave;
      VK_O: DoOpen;
      VK_E: DoExport;
      VK_P: DoPrint;
      VK_T: if FMode = mdPro then NewDrawing;
      VK_W: if FMode = mdPro then CloseDrawing(FTabIdx);
      VK_TAB: if FMode = mdPro then
                SelectDrawing((FTabIdx + 1) mod Length(FDrawings));
    else
      Handled := False;
    end;
    if Handled then
    begin
      Key := 0;
      Exit;
    end;
  end;

  { --- keys shared by both modes -------------------------------------- }
  case Key of
    VK_F1: begin ShowAbout; Key := 0; Exit; end;
    VK_DELETE: begin StartErase; Key := 0; Exit; end;
  end;

  if FMode = mdPro then
  begin
    if Key = VK_MENU then
    begin
      FPenUp := True;      // Alt: suspend snapping while it is held
      Key := 0;
      Exit;
    end;

    { While a note or a /command is being typed, letters are letters - not
      shortcuts.  Only the keys that finish or edit it are handled here. }
    if ((FTool = ptText) and (FStage = 1)) or (Copy(FInput, 1, 1) = '/') then
    begin
      case Key of
        VK_RETURN: CommandEnter;
        VK_ESCAPE: ResetTool;
        VK_BACK:
          begin
            if FInput <> '' then SetLength(FInput, Length(FInput) - 1);
            pbCmd.Invalidate;
            pbScreen.Invalidate;
          end;
      else
        Exit;      // let OnKeyPress see it
      end;
      Key := 0;
      Exit;
    end;

    case Key of
      VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN, VK_PRIOR, VK_NEXT: Arrow(Key);
      VK_SPACE, VK_RETURN: CommandEnter;
      VK_ESCAPE:
        begin
          if FInput <> '' then
            FInput := ''
          else if FStage > 0 then
            ResetTool
          else
            SetTool(ptSelect);
          FCmdMsg := '';
          pbCmd.Invalidate;
          pbScreen.Invalidate;
        end;
      VK_BACK:
        begin
          if FInput <> '' then SetLength(FInput, Length(FInput) - 1);
          pbCmd.Invalidate;
          pbScreen.Invalidate;
        end;
      VK_TAB: SetTool(TProTool((Ord(FTool) + 1) mod (Ord(High(TProTool)) + 1)));
      VK_Q: SetTool(ptSelect);
      VK_L: SetTool(ptLine);
      VK_A: SetTool(ptArc);
      VK_C: SetTool(ptCircle);
      VK_P: SetTool(ptPush);
      VK_N: SetTool(ptText);
      VK_E: SetTool(ptErase);
      VK_M: SetTool(ptMeasure);
      VK_V:
        case FD.View of
          vkPlan: RunCommand('iso');
          vkIso: RunCommand('3d');
        else
          RunCommand('plan');
        end;
      VK_I: RunCommand(IfThen(FD.View = vkIso, 'plan', 'iso'));
      VK_K: RunCommand('plane');
      VK_F: FitView;
      VK_O: SetOriginHere;
      VK_D: RunCommand('dim');
      VK_G: RunCommand('grid');
      VK_U: RunCommand('units');
      VK_T: CycleTheme(1);
      VK_W: SetMode(mdToy);
      VK_OEM_4: SetPenSize(FPenSize - 1);
      VK_OEM_6: SetPenSize(FPenSize + 1);
    else
      Handled := False;
    end;
    if Handled then Key := 0;
    Exit;
  end;

  { --- toy mode -------------------------------------------------------- }
  case Key of
    VK_LEFT:  begin BeginStroke; FKeyLeft := True; end;
    VK_RIGHT: begin BeginStroke; FKeyRight := True; end;
    VK_UP:    begin BeginStroke; FKeyUp := True; end;
    VK_DOWN:  begin BeginStroke; FKeyDown := True; end;
    VK_SHIFT: FBoost := True;
    VK_CONTROL: FPrecise := True;
    VK_SPACE, VK_MENU: FPenUp := True;
    VK_BACK: StartErase;
    VK_A: ToggleAuto;
    VK_T: CycleTheme(1);
    VK_W: SetMode(mdPro);
    VK_G: begin
            FShowGrid := not FShowGrid;
            RepaintPaper;
            RecomposeAll;
            pbDeck.Invalidate;
          end;
    VK_M: begin FMirror := not FMirror; pbDeck.Invalidate; end;
    VK_S: SetSymmetry(SYM_VALUES[(IndexOfSym(FSym) + 1) mod Length(SYM_VALUES)]);
    VK_1: SetStyle(psClassic);
    VK_2: SetStyle(psNeon);
    VK_3: SetStyle(psRainbow);
    VK_4: SetStyle(psSparkle);
    VK_5: SetStyle(psChalk);
    VK_OEM_4, VK_SUBTRACT, VK_OEM_MINUS: SetPenSize(FPenSize - 1);
    VK_OEM_6, VK_ADD, VK_OEM_PLUS: SetPenSize(FPenSize + 1);
    VK_ESCAPE: if FAuto then ToggleAuto;
  else
    Handled := False;
  end;

  if Handled then Key := 0;
end;

procedure TMainForm.FormKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  if FMode = mdPro then
  begin
    if Key = VK_MENU then
    begin
      FPenUp := False;
      Key := 0;
    end;
    Exit;
  end;
  case Key of
    VK_LEFT:  FKeyLeft := False;
    VK_RIGHT: FKeyRight := False;
    VK_UP:    FKeyUp := False;
    VK_DOWN:  FKeyDown := False;
    VK_SHIFT: FBoost := False;
    VK_CONTROL: FPrecise := False;
    VK_SPACE, VK_MENU: FPenUp := False;
  else
    Exit;
  end;
  if not (FKeyLeft or FKeyRight or FKeyUp or FKeyDown) then
    EndStroke;
  Key := 0;
end;

{ ======================================================================== }
{ commands                                                                  }
{ ======================================================================== }

procedure TMainForm.SetMode(M: TAppMode);
begin
  if M = FMode then Exit;
  FMode := M;
  ResetTool;
  if FMode = mdPro then
    FHint := TOOL_HINTS[FTool]
  else
    FHint := TOY_HINT;
  Relayout;
  RepaintPaper;
  RenderPro;
  RecomposeAll;
  RefreshChrome;
end;

procedure TMainForm.CycleTheme(Step: Integer);
begin
  FThemeIdx := (FThemeIdx + Step + THEME_COUNT) mod THEME_COUNT;
  { Only the ink you have not deliberately chosen follows the theme. }
  if FInkAuto then
    SetInk(PixToColor(Theme.Ink), True);
  { The ink lives on its own layer, so a new theme re-papers the screen
    underneath the drawing and leaves the drawing alone. }
  RepaintPaper;
  RenderPro;
  RecomposeAll;
  RefreshChrome;
  FHint := 'Theme: ' + Theme.Name;
end;

procedure TMainForm.DoPickColor;
begin
  dlgColor.Color := FInkColor;
  if dlgColor.Execute then
    SetInk(dlgColor.Color, False);
end;

{ ======================================================================== }
{ documents: open, save, export                                             }
{ ======================================================================== }

const
  DOC_MAGIC = 'HECKERS-SKETCH';
  DOC_VERSION = 1;

procedure TMainForm.DoOpen;
begin
  dlgOpen.Filter := 'Heckers Sketch drawing|*.hsk|All files|*.*';
  dlgOpen.DefaultExt := '.hsk';
  if dlgOpen.InitialDir = '' then dlgOpen.InitialDir := GetUserDir;
  if not dlgOpen.Execute then Exit;
  LoadDocument(dlgOpen.FileName);
end;

function TMainForm.LoadDocument(const FileName: string): Boolean;
var
  L: TStringList;
  I, Idx, NSheet: Integer;
  Line, Key, Rest: string;
  D: TDrawing;
begin
  Result := False;
  L := TStringList.Create;
  try
    try
      L.LoadFromFile(FileName);
    except
      on E: Exception do
      begin
        MessageDlg('Could not open', E.Message, mtError, [mbOK], 0);
        Exit;
      end;
    end;

    if (L.Count = 0) or (Copy(Trim(L[0]), 1, Length(DOC_MAGIC)) <> DOC_MAGIC) then
    begin
      MessageDlg('Could not open',
        'That does not look like a Heckers Sketch drawing.', mtError, [mbOK], 0);
      Exit;
    end;

    { out with the old sheets }
    for I := High(FDrawings) downto 0 do
      FDrawings[I].Free;
    SetLength(FDrawings, 0);
    NSheet := 0;

    Idx := 1;
    while Idx < L.Count do
    begin
      Line := Trim(L[Idx]);
      Inc(Idx);
      if Line = '' then Continue;
      I := Pos(' ', Line);
      if I > 0 then
      begin
        Key := Copy(Line, 1, I - 1);
        Rest := Trim(Copy(Line, I + 1, MaxInt));
      end
      else
      begin
        Key := Line;
        Rest := '';
      end;

      if Key = 'SHEET' then
      begin
        SetLength(FDrawings, NSheet + 1);
        FDrawings[NSheet] := TDrawing.Create(Rest);
        D := FDrawings[NSheet];
        Inc(NSheet);
        { the header lines that follow belong to this sheet }
        while Idx < L.Count do
        begin
          Line := Trim(L[Idx]);
          I := Pos(' ', Line);
          if I <= 0 then Break;
          Key := Copy(Line, 1, I - 1);
          Rest := Trim(Copy(Line, I + 1, MaxInt));
          if Key = 'UNITS' then D.Units := TUnitSystem(StrToIntDef(Rest, 0))
          else if Key = 'SCALE' then D.ScaleIdx := EnsureRange(StrToIntDef(Rest, 2), 0, SCALE_COUNT - 1)
          else if Key = 'SNAP' then D.SnapIdx := EnsureRange(StrToIntDef(Rest, 5), 0, SNAP_COUNT - 1)
          else if Key = 'VIEW' then D.View := TViewKind(EnsureRange(StrToIntDef(Rest, 0), 0, 2))
          else if Key = 'DIMS' then D.ShowDims := Rest = '1'
          else Break;
          Inc(Idx);
        end;
        D.Doc.LoadFrom(L, Idx);
      end;
    end;

    if Length(FDrawings) = 0 then
    begin
      SetLength(FDrawings, 1);
      FDrawings[0] := TDrawing.Create('Sheet 1');
    end;

    FDocPath := FileName;
    FTabIdx := 0;
    FD := FDrawings[0];
    FMode := mdPro;
    ResetTool;
    Relayout;
    FitView;
    LayoutTabs;
    RefreshChrome;
    FCmdMsg := 'Opened ' + ExtractFileName(FDocPath) +
      Format(' - %d sheet(s)', [Length(FDrawings)]);
    FHint := FDocPath;
    Result := True;
  finally
    L.Free;
  end;
end;

procedure TMainForm.DoSaveAs;
begin
  dlgSave.Filter := 'Heckers Sketch drawing|*.hsk';
  dlgSave.DefaultExt := '.hsk';
  if dlgSave.InitialDir = '' then dlgSave.InitialDir := GetUserDir;
  if FDocPath <> '' then
    dlgSave.FileName := FDocPath
  else
    dlgSave.FileName := 'drawing.hsk';
  if not dlgSave.Execute then Exit;
  FDocPath := dlgSave.FileName;
  DoSave;
end;

procedure TMainForm.DoSave;
var
  L: TStringList;
  I: Integer;
begin
  if FMode <> mdPro then
  begin
    { the toy has no document, only a picture }
    DoExport;
    Exit;
  end;

  if FDocPath = '' then
  begin
    DoSaveAs;
    Exit;
  end;

  L := TStringList.Create;
  try
    L.Add(Format('%s %d', [DOC_MAGIC, DOC_VERSION]));
    for I := 0 to High(FDrawings) do
    begin
      L.Add('SHEET ' + FDrawings[I].Name);
      L.Add('UNITS ' + IntToStr(Ord(FDrawings[I].Units)));
      L.Add('SCALE ' + IntToStr(FDrawings[I].ScaleIdx));
      L.Add('SNAP ' + IntToStr(FDrawings[I].SnapIdx));
      L.Add('VIEW ' + IntToStr(Ord(FDrawings[I].View)));
      L.Add('DIMS ' + IntToStr(Ord(FDrawings[I].ShowDims)));
      FDrawings[I].Doc.SaveTo(L);
      L.Add('ENDSHEET');
    end;
    try
      L.SaveToFile(FDocPath);
      FCmdMsg := 'Saved ' + ExtractFileName(FDocPath);
      FHint := 'Saved to ' + FDocPath;
    except
      on E: Exception do
        MessageDlg('Could not save', E.Message, mtError, [mbOK], 0);
    end;
  finally
    L.Free;
  end;
  Invalidate;
  pbCmd.Invalidate;
end;

procedure TMainForm.DoExport;
var
  L: TStringList;
  Fn, Ext, E: string;
begin
  dlgSave.Filter := 'PNG image|*.png|SVG drawing|*.svg';
  dlgSave.DefaultExt := '';
  if dlgSave.InitialDir = '' then dlgSave.InitialDir := GetUserDir;
  dlgSave.FileName := 'heckers-sketch-' + FormatDateTime('yyyymmdd-hhnnss', Now);
  if not dlgSave.Execute then Exit;

  { the chosen filter decides the format, and any extension the dialog or the
    user tacked on is normalised away so nothing ends up as .svg.png }
  if dlgSave.FilterIndex = 2 then Ext := '.svg' else Ext := '.png';
  if (Ext = '.svg') and (FMode <> mdPro) then
  begin
    Ext := '.png';
    FCmdMsg := 'The toy has no vectors to export, so that is a PNG.';
  end;

  Fn := dlgSave.FileName;
  repeat
    E := LowerCase(ExtractFileExt(Fn));
    if (E = '.png') or (E = '.svg') then
      Fn := ChangeFileExt(Fn, '')
    else
      Break;
  until False;
  Fn := Fn + Ext;

  try
    if Ext = '.svg' then
    begin
      L := TStringList.Create;
      try
        FD.Doc.WriteSVG(L, Proj, FD.Units);
        L.SaveToFile(Fn);
      finally
        L.Free;
      end;
    end
    else
      FArt.SaveToPNG(Fn);
    FHint := 'Exported ' + ExtractFileName(Fn);
    if FCmdMsg = '' then FCmdMsg := 'Exported ' + ExtractFileName(Fn);
  except
    on E2: Exception do
      MessageDlg('Could not export', E2.Message, mtError, [mbOK], 0);
  end;
  Invalidate;
  pbCmd.Invalidate;
end;

{ In pro mode the page is re-rendered from the geometry at the printer's own
  resolution, so 1/4" = 1'-0" really does come out as a quarter inch on the
  paper.  Toy mode just fits the picture to the page. }
procedure TMainForm.DoPrint;
var
  Sheet: TArtSurface;
  V: TProjector;
  Lo, Hi, Mid: TP3;
  PageWIn, PageHIn: Double;
  SW, SH: Integer;
  P: TPointF;
  Scale: Double;
  R: TRect;
begin
  if not dlgPrint.Execute then Exit;
  try
    Printer.BeginDoc;
    try
      if (FMode = mdPro) and (Printer.XDPI > 0) and (Printer.YDPI > 0) then
      begin
        PageWIn := Printer.PageWidth / Printer.XDPI;
        PageHIn := Printer.PageHeight / Printer.YDPI;
        SW := Max(64, Round(PageWIn * PRINT_DPI));
        SH := Max(64, Round(PageHIn * PRINT_DPI));

        Sheet := TArtSurface.Create(SW, SH);
        try
          Sheet.Clear(Pix(255, 255, 255));
          V.Kind := FD.View;
          V.Ppu := PixelsPerUnit(FD.Units, CurScale, PRINT_DPI);
          V.OX := 0;
          V.OY := 0;
          if FD.Doc.Bounds(Lo, Hi) then
          begin
            Mid := P3((Lo.X + Hi.X) / 2, (Lo.Y + Hi.Y) / 2, (Lo.Z + Hi.Z) / 2);
            P := Project(V, Mid);
            V.OX := SW / 2 - P.X;
            V.OY := SH / 2 - P.Y;
          end;
          FD.Doc.Render(Sheet, V, FD.ShowDims, FD.Units, FDimFont, Pix(20, 20, 20));
          Printer.Canvas.StretchDraw(
            Rect(0, 0, Printer.PageWidth, Printer.PageHeight), Sheet.AsBitmap);
        finally
          Sheet.Free;
        end;
        FCmdMsg := 'Printed at ' + CurScale.Name +
          IfThen(FD.Units = usImperial, ' = 1''-0"', '');
      end
      else
      begin
        Scale := Min(Printer.PageWidth / FArt.Width,
                     Printer.PageHeight / FArt.Height) * 0.92;
        R := Bounds(Round((Printer.PageWidth - FArt.Width * Scale) / 2),
                    Round((Printer.PageHeight - FArt.Height * Scale) / 2),
                    Round(FArt.Width * Scale), Round(FArt.Height * Scale));
        Printer.Canvas.StretchDraw(R, FArt.AsBitmap);
      end;
    finally
      Printer.EndDoc;
    end;
    FHint := 'Sent to the printer.';
  except
    on E: Exception do
      MessageDlg('Could not print', E.Message, mtError, [mbOK], 0);
  end;
  Invalidate;
end;

{ ======================================================================== }
{ settings                                                                  }
{ ======================================================================== }

procedure TMainForm.LoadSettings;
var
  Ini: TIniFile;
begin
  FInkColor := PALETTE[0];
  FInkAuto := True;
  try
    Ini := TIniFile.Create(GetAppConfigFile(False));
    try
      FThemeIdx := EnsureRange(Ini.ReadInteger('look', 'theme', 0), 0, THEME_COUNT - 1);
      FShowGrid := Ini.ReadBool('look', 'grid', False);
      FMode := TAppMode(EnsureRange(Ini.ReadInteger('look', 'mode', 0), 0, 1));
      FStyle := TPenStyle(EnsureRange(Ini.ReadInteger('pen', 'style', 0), 0, 4));
      FPenSize := EnsureRange(Ini.ReadInteger('pen', 'size', 4), MIN_PEN, MAX_PEN);
      FInkColor := TColor(Ini.ReadInteger('pen', 'ink', PALETTE[0]));
      FInkAuto := Ini.ReadBool('pen', 'inkauto', True);
      FSym := EnsureRange(Ini.ReadInteger('pen', 'symmetry', 1), 1, 8);
      FMirror := Ini.ReadBool('pen', 'mirror', False);
      FProDials := Ini.ReadBool('pro', 'dials', False);
      FD.ScaleIdx := EnsureRange(Ini.ReadInteger('pro', 'scale', 2), 0, SCALE_COUNT - 1);
      FD.SnapIdx := EnsureRange(Ini.ReadInteger('pro', 'snap', 5), 0, SNAP_COUNT - 1);
      FD.Units := TUnitSystem(EnsureRange(Ini.ReadInteger('pro', 'units', 0), 0, 1));
      FD.ShowDims := Ini.ReadBool('pro', 'dims', True);
      FD.View := TViewKind(EnsureRange(Ini.ReadInteger('pro', 'view', 0), 0, 1));
    finally
      Ini.Free;
    end;
  except
    { first run, or a read-only config dir - the defaults are fine }
  end;
end;

procedure TMainForm.SaveSettings;
var
  Ini: TIniFile;
begin
  try
    ForceDirectories(ExtractFilePath(GetAppConfigFile(False)));
    Ini := TIniFile.Create(GetAppConfigFile(False));
    try
      Ini.WriteInteger('look', 'theme', FThemeIdx);
      Ini.WriteBool('look', 'grid', FShowGrid);
      Ini.WriteInteger('look', 'mode', Ord(FMode));
      Ini.WriteInteger('pen', 'style', Ord(FStyle));
      Ini.WriteInteger('pen', 'size', FPenSize);
      Ini.WriteInteger('pen', 'ink', FInkColor);
      Ini.WriteBool('pen', 'inkauto', FInkAuto);
      Ini.WriteInteger('pen', 'symmetry', FSym);
      Ini.WriteBool('pen', 'mirror', FMirror);
      Ini.WriteBool('pro', 'dials', FProDials);
      Ini.WriteInteger('pro', 'scale', FD.ScaleIdx);
      Ini.WriteInteger('pro', 'snap', FD.SnapIdx);
      Ini.WriteInteger('pro', 'units', Ord(FD.Units));
      Ini.WriteBool('pro', 'dims', FD.ShowDims);
      Ini.WriteInteger('pro', 'view', Ord(FD.View));
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
  except
    { never let a settings problem stop the program from closing }
  end;
end;

{ ======================================================================== }
{ about                                                                     }
{ ======================================================================== }

type
  TAboutBox = class(TForm)
  private
    FSkin: TArtSurface;
    FTheme: TTheme;
    FScale: Single;
    procedure BoxPaint(Sender: TObject);
    procedure BoxClick(Sender: TObject);
    procedure BoxKey(Sender: TObject; var Key: word; Shift: TShiftState);
  public
    constructor CreateStyled(AOwner: TComponent; const ATheme: TTheme; AScale: Single);
    destructor Destroy; override;
  end;

const
  ABOUT_LINES: array[0..12] of string = (
    'Noella Hazel Stone was seven years old when she decided she wanted to',
    'write a program.  She drew the screen, the two dials and the shake',
    'button on paper, picked the colours, and told her dad what each part',
    'was supposed to do.  He typed while she directed.  19 October 2021.',
    '',
    'TOY  -  the program she designed.  Two dials, five kinds of pen, a',
    'kaleidoscope, and a shake that dissolves the drawing into powder.',
    '',
    'PRO  -  the same idea taken seriously.  Pick a scale, put the cursor on',
    'a point, and type 12''6" to draw exactly that.  Lines, arcs, circles,',
    'notes and a tape measure, in plan or isometric, on as many sheets as',
    'you like.  It prints at true scale.  The command bar always tells you',
    'what it wants next.');

constructor TAboutBox.CreateStyled(AOwner: TComponent; const ATheme: TTheme;
  AScale: Single);
begin
  inherited CreateNew(AOwner);
  FTheme := ATheme;
  FScale := AScale;
  BorderStyle := bsNone;
  Position := poMainFormCenter;
  ClientWidth := Round(660 * FScale);
  ClientHeight := Round(452 * FScale);
  Color := PixToColor(FTheme.Shell2);
  KeyPreview := True;
  DoubleBuffered := True;
  FSkin := TArtSurface.Create(ClientWidth, ClientHeight);
  OnPaint := @BoxPaint;
  OnClick := @BoxClick;
  OnKeyDown := @BoxKey;
end;

destructor TAboutBox.Destroy;
begin
  FSkin.Free;
  inherited Destroy;
end;

procedure TAboutBox.BoxPaint(Sender: TObject);
var
  I, Y, Pad: Integer;
  S: string;
begin
  Pad := Round(34 * FScale);
  PaintShell(FSkin, FTheme);
  FSkin.RoundFrame(Rect(1, 1, ClientWidth - 1, ClientHeight - 1),
    Round(14 * FScale), 2.0, FTheme.Accent, 0.85);
  FSkin.Line(Pad, Round(104 * FScale), ClientWidth - Pad, Round(104 * FScale),
    1.4, FTheme.Accent, 0.6);
  FSkin.DrawTo(Canvas, 0, 0);

  Canvas.Brush.Style := bsClear;
  Canvas.Font.Name := {$IFDEF WINDOWS}'Segoe UI'{$ELSE}'Sans'{$ENDIF};

  Canvas.Font.Height := -Round(24 * FScale);
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := PixToColor(FTheme.Text);
  Canvas.TextOut(Pad, Round(40 * FScale), APP_NAME);

  Canvas.Font.Height := -Round(12 * FScale);
  Canvas.Font.Style := [];
  Canvas.Font.Color := PixToColor(FTheme.Accent);
  Canvas.TextOut(Pad, Round(76 * FScale), 'Noella Stone Software, Ltd.');

  Canvas.Font.Height := -Round(13 * FScale);
  Canvas.Font.Color := PixToColor(FTheme.Text);
  Y := Round(122 * FScale);
  for I := 0 to High(ABOUT_LINES) do
  begin
    Canvas.TextOut(Pad, Y, ABOUT_LINES[I]);
    Inc(Y, Round(20 * FScale));
  end;

  Canvas.Font.Height := -Round(12 * FScale);
  Canvas.Font.Style := [fsItalic];
  Canvas.Font.Color := PixToColor(FTheme.TextDim);
  S := 'Good job, Noella.  Love you.  - Dad';
  Canvas.TextOut(ClientWidth - Pad - Canvas.TextWidth(S), Y + Round(8 * FScale), S);

  Canvas.Font.Style := [];
  S := 'click anywhere, or press Esc, to close';
  Canvas.TextOut((ClientWidth - Canvas.TextWidth(S)) div 2,
    ClientHeight - Round(28 * FScale), S);
end;

procedure TAboutBox.BoxClick(Sender: TObject);
begin
  Close;
end;

procedure TAboutBox.BoxKey(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  Close;
  Key := 0;
end;

procedure TMainForm.ShowAbout;
var
  Box: TAboutBox;
begin
  Box := TAboutBox.CreateStyled(Self, Theme, FUIScale);
  try
    Box.ShowModal;
  finally
    Box.Free;
  end;
end;

initialization
  OnGetApplicationName := @SketchAppName;

end.
