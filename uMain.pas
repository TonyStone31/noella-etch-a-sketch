unit uMain;

{
  Heckers Sketch - an Etch A Sketch that grew up.

  19 October 2021.  Noella Stone, age 7, decided she wanted to write a
  program.  She drew the screen, the two dials and the shake button on paper,
  picked the colors, and told her dad what each part had to do.  He typed
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
  uSurface, uSkin, uWork, uRegion, uUpdate, uPaths, uReport, uNet, uUnfold, uFlatView, uShotView;

type
  TAppMode = (mdToy, mdPro);

  TProTool = (ptSelect, ptMove, ptLine, ptRect, ptArc, ptCircle, ptPush,
    ptText, ptErase, ptMeasure, ptDim, ptOrbit, ptOffset);

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
    View: TViewKind;        // PLAN, ISO or free 3D
    Plane: TPlane;          // which plane new arcs and mouse picks land on
    Az, El: Double;         // 3D camera, radians
    { Whether the camera above was read from a file or is just where a new
      sheet starts.  A drawing that remembers where it was looked at from
      must not then be framed over the top of it. }
    CamKnown: Boolean;
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
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormDestroy(Sender: TObject);
    procedure RememberWindow;
    function OnAScreen(L, T, W, H: Integer): Boolean;
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
    FToyTheme: Integer;         // the playful one to go back to
    FProTheme: Integer;         // Light or Dark, remembered across a switch
    FPenSize: Integer;
    { PRO's edge weight is its own setting.  It used to share the toy's pen,
      which meant a pen thick enough to draw with on the magic screen was also
      the weight of every edge in a drawing - four times what SketchUp uses. }
    FEdgeW: Integer;
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
    { which of the three the cursor is on, when FSnapKind is snOnAxis }
    FSnapAxis: Integer;
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
    { the face the offset tool is working on, or -1 }
    FOffFace: Integer;
    FHoverFace: Integer;   // the face push/pull would take, before you click

    { Held down, the eraser gathers everything the cursor is dragged over and
      shows it in red before any of it goes.  Deleting one line at a time is
      slow, and a click that turns out to have hit the wrong thing is worse. }
    FErasing2: Boolean;
    FDoomed: array of Integer;

    { What is picked, and the box being dragged to pick it.  Dragging left to
      right takes only what is wholly inside; right to left takes anything it
      touches, which is SketchUp's rule and worth keeping. }
    FSel: array of Integer;
    FBoxing: Boolean;
    FBoxX, FBoxY: Integer;

    { asked for on the command line: keep filling the screen even if the
      screen changes size under us }
    FFill: (flNone, flMaximized, flFull);
    FScrW, FScrH: Integer;

    { the two gaps between the three tool groups, so the deck can rule a line
      down each one }
    FGrpDivX: array[0..1] of Integer;
    FGrpDivY0, FGrpDivY1: Integer;

    { the move in progress: where it was grabbed, and every corner that will
      travel - gathered once at the grab so the drag stays cheap }
    FMoveVerts: TP3Array;
    FMoveCopy: Boolean;
    FLastPush: Double;         // what a double-click repeats
    { The tape measure lays down a guide by default, the way SketchUp's does;
      Ctrl turns that off and it only measures. }
    FMeasEdge: Integer;        // the edge the tape was started on, or -1
    { What the last rebuild worked out, so a plane whose edges have not moved
      is not worked out again.  Safe to keep across sheets: a plane is only
      reused when its segments hash the same, which means it is the same
      plane with the same edges in it. }
    FRegionCache: TRegionCache;

    { how many clicks have landed in the same spot in quick succession: two
      takes what is attached, three takes everything joined on }
    FClickN: Integer;
    FClickT: QWord;
    FClickX, FClickY: Integer;

    { The working plane follows whatever face you are pointing at, so a shape
      drawn on top of a box lands on top of it.  Alt cycles through the three
      flat planes instead and latches, because sometimes you mean to draw in
      mid air; Esc, or a new tool, hands it back to the face. }
    FPlaneHeld: Boolean;
    { the face the shape is being drawn on, so a point can be held to it }
    FFacePt, FFaceNm: TP3;
    { true while a push is lining itself up with another face }
    FPushFlush: Boolean;
    { waiting for a click to say which piece to lay out }
    FUnfoldPick: Boolean;
    { which side of the cursor the chip is sitting on, kept so it does not
      swap sides every time the mouse twitches }
    FTipCorner: Integer;
    { what the precision list is showing as chosen }
    FLenDenom: Integer;
    { Taking the picture for a report.  FShotCount is the seconds left and is
      drawn on the canvas; FShotFlash whites the screen for a moment at the
      instant it is taken; FShotBusy keeps a second capture from starting
      inside the first, because the countdown deliberately leaves the program
      usable and the help menu is one of the things it leaves usable. }
    FShotCount: Integer;
    FShotFlash: Boolean;
    FShotBusy: Boolean;
    { what the settings row was last built believing, so the guide buttons
      appear and vanish however the count changed - laid, cleared, erased,
      undone }
    FDeckGuides: Integer;
    { the note being dragged by its box, where it started, and where it was
      taken hold of }
    FNoteDrag: Integer;
    FNoteFrom, FNoteGrab: TP3;
    { the point the cursor is holding on to, and whether it has one }
    FStickOn: Boolean;
    FStickPt: TP3;
    FStickKind: TSnapKind;
    { how many times it has fallen over lately, and when the last one was }
    FWoundCount: Integer;
    FWoundAt: QWord;
    { where the window was, taken while it still existed }
    FWinSaved, FWinMax: Boolean;
    FWinL, FWinT, FWinW, FWinH: Integer;
    { True when the point the shape starts from sits on a face, so that face
      decides the plane and dragging must not overrule it.  False when it
      started in mid air, which is when the drag gets to choose. }
    FPlaneFromFace: Boolean;
    { Nothing is ever lost.  Every change bumps FEditSeq; a few seconds later
      the tick writes the whole session - all sheets - to a draft beside the
      settings, and the next launch picks it back up.  FDraftSeq is what was
      last written, FDraftAge counts ticks since the last change. }
    FEditSeq, FDraftSeq: Int64;
    { unique to this run of the program, so two copies open at once cannot
      write the same temporary file over each other }
    FRunTag: string;
    FDraftAge: Integer;
    FRestored: Boolean;
    { Letting go of a run of lines by leaning on the button.

      Hold the left button still and the rubber band stops being a rubber
      band and becomes a stick under strain: it bows, thins, and a crack
      runs through it.  When it breaks, the run is released and no point is
      placed.  FHoldOn is a press waiting to see what it turns out to be,
      FHoldT how long it has been held, FSnapT the recoil afterwards. }
    FHoldOn: Boolean;
    FHoldT, FSnapT: Single;
    FHoldX, FHoldY: Integer;
    FSnapA, FSnapB, FSnapM: TPointF;
    { After a run is snapped off, the cursor is still sitting on the point it
      was joined to, and the dwell would quietly take it up again as a
      reference - leaving its marker on screen, which reads as still being
      attached.  Refuse to until the hand has actually moved. }
    FNoLockUntilMoved: Boolean;
    FWasLine: Boolean;
    { latched when drawing the document threw, so it is not retried forty
      times a second }
    FRenderBroken: Boolean;
    { how long this run has been up, and whether it has been up long enough
      to say the startup worked }
    FUpTime: Single;
    FStartupDone, FAskedAboutCrash: Boolean;
    { The last few dozen things that happened, so a crash report says what
      was being done and not only where it landed.  A ring, so it costs
      nothing and never grows. }
    FTrail: array[0..63] of string;
    FTrailN: Integer;
    { The newer version there is, if there is one.  Kept rather than
      announced: a line in the status bar is written over by the next thing
      that happens - the offer to report a crash did exactly that - and then
      nobody ever hears about it again. }
    FUpdateTag: string;
    { Shaking the mouse to say which way you meant.  A count of direction
      reversals on each screen axis, and when they were, so a shake decays
      back to nothing if you stop. }
    FShX, FShY: Integer;
    FShDirX, FShDirY, FShNX, FShNY: Integer;
    FShTX, FShTY: QWord;
    { the dimension whose figure is being typed over, or -1.  While this is
      set the command bar is a text box for that label. }
    FDimEdit: Integer;
    { where the right button went down, so a click can be told from a pan }
    FRightSX, FRightSY: Integer;
    FPushSX, FPushSY: Integer;   // where the drag started, on screen
    FPanRefX, FPanRefY: Integer;
    { What the orbit turns about.  Spinning around the world origin sends
      whatever you were looking at off the screen; SketchUp turns about the
      thing under the cursor, so that is what this holds. }
    FOrbitPivot: TP3;
    { Where the pivot sat on the glass when the drag began.  The orbit holds
      it at this spot, not under the cursor - see ServiceMotion. }
    FOrbitAnchor: TPointF;
    FOrbitAnchored: Boolean;
    FMouseSX, FMouseSY: Integer;   // raw pointer, before snapping

    { Motion is recorded here and nowhere else.  Under a virtual display
      every repaint has to be encoded and shipped to the client, so a
      handler that painted would cost tens of milliseconds - and GDK
      coalesces motion until the handler returns, which throttled the
      event stream down to a trickle.  The work now happens once per
      tick instead, off the back of the newest position. }
    FMoveX, FMoveY: Integer;
    FMoveShift: TShiftState;
    FMovePending: Boolean;
    FScreenDirty: Boolean;
    FHotMode: Integer;
    FHotView: Integer;
    FViewSkin: TArtSurface;
    FGlyph: TArtSurface;    // the tool badge beside the cursor
    FHoverEnt: Integer;          // what the eraser is about to delete
    FDocPath: string;            // where this set of sheets came from
    FGuide: Boolean;             // an alignment guide is active
    FGuideFrom: TP3;

    { A 90 degree relationship to a point you chose beats whatever else
      happens to be within snapping distance.  FAxisFrom is the point it is
      measured from - the start of the line, or one acquired by resting on
      it - and FAxisLock says which axis is free: 0 X, 1 Y, 2 Z. }
    FAxisLock: Integer;
    FAxisFrom: TP3;

    { which standard view we are parked on, or -1 after a free orbit }
    FViewPreset: Integer;

    { rest the cursor on a point and it is kept as a reference }
    FLockOn: Boolean;
    FLockPt: TP3;
    FLockKind: TSnapKind;
    FDwellSX, FDwellSY: Integer;
    FDwellSince: QWord;

    { --- deck ----------------------------------------------------------- }
    FDeck: array of TDeckItem;
    FHotItem: Integer;
    { The open settings list.  It is drawn on the canvas rather than in a
      window of its own, so it needs no extra control and cannot fall behind
      anything: the canvas is already above the deck. }
    FPopup: Integer;
    FPopupR: TRect;
    FPopupN: Integer;
    FPopupHot: Integer;
    FCursorWas: TCursor;
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
    function ResolveSnapRaw(SX, SY: Double): TP3;
    function ResolveSnapAt(SX, SY: Double): TP3;
    function HeldToFace(const P: TP3): TP3;
    function AnnotColor: TPix;
    function DialsVisible: Boolean;

    procedure Relayout;
    function TitleHeight: Integer;
    function CursorOnPlane(const N, P0: TP3): TP3;
    function OffsetDistance: Double;
    function OffsetPreview: TP3Array;
    procedure CommitOffset;
    procedure EditDimUnder(X, Y: Integer);
    procedure CommitDimNote;
    function DeckRowH: Integer;
    function DeckRows: Integer;
    function DeckHeight: Integer;
    function ChromeMargin: Integer;
    procedure RebuildShell;
    procedure RebuildDeck;
    procedure RebuildKnobs;
    procedure RefreshChrome;
    procedure ResizeSurfaces(AW, AH: Integer);
    procedure RepaintPaper;
    procedure PaintAxes;
    procedure PaintPushPreview(C: TCanvas);
    procedure PaintFaceHint(C: TCanvas; Face: Integer; const Col: TPix);
    procedure CheckForUpdate(Loud: Boolean);
    procedure DoUpdate;
    procedure StartUnfold;
    procedure UnfoldAt(SX, SY: Integer);
    procedure OfferCrashReport;
    function DocThings(const DocFile: string): Integer;
    procedure Quiesce;
    function WindowShot(out B: TBitmap): Boolean;
    function TakeReportShot(St: TStream; Wait: Boolean): Boolean;
    procedure ShotCountdown(Seconds: Integer);
    procedure PaintShotOverlay(C: TCanvas);
    function ReportBug(const Preamble: string = '';
      const ShotFile: string = ''; const DocFile: string = ''): Boolean;
    { Note something worth knowing if this run ends badly. }
    procedure Trail(const S: string);
    function TrailText: string;
    { How many of each kind are on the sheet - a crash that only happens with
      a face, or only with a note, says so here. }
    function KindCounts: string;
    { Everything worth knowing about the state of the program right now, as
      text.  One place, so a crash report and a report somebody writes by
      hand say the same things about the same program. }
    function DiagnosticText: string;
    { The drawing as it stood, beside the report, so it can be opened here. }
    procedure SaveCrashDoc(const ReportPath: string);
    procedure ShakeWatch(X, Y: Integer);
    procedure PaintStrain(C: TCanvas; const A, B: TPointF; T: Single);
    procedure PaintSnapRecoil(C: TCanvas);
    procedure PaintFacePoints(C: TCanvas; Face: Integer);
    procedure PaintSnapMarker(C: TCanvas; SX, SY: Integer);
    procedure PaintDimPreview(C: TCanvas);
    function PushDistance: Double;
    procedure Recompose;
    procedure RecomposeAll;
    procedure FreshScreen;
    procedure RenderPro;
    procedure InvalidateStatus;
    procedure ServiceMotion;
    procedure ServiceHover;
    function DimOffset3: TP3;
    procedure LayGuide;
    { Every drawn edge as a plain segment, which is what the region engine
      eats.  Guides, dimensions and notes are not geometry and stay out; a
      solid's own faces are its boundary and are not derived either. }
    function EdgeSegments: TSegArray;
    procedure ReportRegions;
    { The one call that keeps the drawn faces right.  Everything that changes
      an edge ends with this. }
    function RebuildFlatFaces: Integer;
    function FaceCount: Integer;
    procedure DoomAt(SX, SY: Integer);
    function PickAt(SX, SY: Integer): Integer;
    function IsSelected(I: Integer): Boolean;
    procedure SelectOnly(I: Integer);
    procedure SelectToggle(I: Integer);
    procedure SelectAdd(I: Integer);
    procedure SelectRemove(I: Integer);
    procedure SelectNone;
    procedure FinishSelect(X, Y: Integer; Shift: TShiftState);
    function EntHasPoint(I: Integer; const P: TP3): Boolean;
    procedure SelectAttached(I: Integer);
    procedure SelectConnected(I: Integer);
    procedure SelectInBox(X0, Y0, X1, Y1: Integer; Crossing, Add: Boolean);
    procedure DeleteSelection;
    function MoveDelta: TP3;
    function RunReading(const A, B: TP3): string;
    procedure PaintMoveGhost(C: TCanvas);
    function IsDoomed(I: Integer): Boolean;
    procedure BurnDoomed;
    procedure OpenPopup(Which: Integer);
    procedure ClosePopup;
    function PopupCount(Which: Integer): Integer;
    function PopupCaption(Which, I: Integer): string;
    procedure PopupChoose(Which, I: Integer);
    function PopupItemAt(SX, SY: Integer): Integer;
    procedure PaintPopup(C: TCanvas);
    procedure PaintToolGlyph(C: TCanvas; AX, AY: Integer);
    function PivotAt(SX, SY: Integer): TP3;
    procedure AnchorOrbit(SX, SY: Integer);
    function RectTarget: TP3;
    procedure ReportCrash(Sender: TObject; E: Exception);
    function GuideColor: TPix;

    procedure UIFont(C: TCanvas; Size: Integer; Bold: Boolean; const Col: TPix;
      Mono: Boolean = False);
    { Draws the string letter by letter with Tracking pixels between, and
      answers how wide it came out, so something can be put after it. }
    function TrackedText(C: TCanvas; X, Y: Integer; const S: string;
      Tracking: Integer): Integer;

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
    { The size being pulled right now, in the same words it would be typed
      in, or empty when nothing is being pulled. }
    function LiveMeasure: string;
    { The color of a working plane: the axis its face points along, which is
      how SketchUp names a plane - right is red, left green, up blue. }
    function PlanePix(Pl: TPlane): TPix;
    function AxisAlong(const A, B: TP3): Integer;
    function IsoRunAxis(const From: TP3; out Along: Double): Integer;
    function PreviewTarget: TP3;
    procedure SetTool(T: TProTool);
    function PlaneName: string;
    procedure PlaneByArrow(Key: Word);
    procedure ResetTool;
    procedure ProClick;
    function WhyNotAMeasurement(const S: string): string;
    procedure ProCommit;
    procedure CommandEnter;
    function RunCommand(const S: string): Boolean;
    procedure NudgeCursor(DX, DY: Double);
    procedure JumpSnap(DX, DY: Integer);
    function SnapLabel: string;
    function InkUnder(const R: TRect): Integer;
    function TipSpot(SX, SY, BoxW, BoxH: Integer): TRect;
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
    procedure ApplyModeTheme;
    procedure SetMode(M: TAppMode);
    procedure SetLenPrecision(D: Integer);
    procedure SetPenSize(V: Integer);
    procedure SetStyle(V: TPenStyle);
    procedure SetInk(C: TColor; Auto: Boolean = False);
    procedure SetSymmetry(V: Integer);
    procedure SetUnits(U: TUnitSystem);
    procedure SetView(V: TViewKind);
    procedure ApplyViewPreset(I: Integer);
    procedure EnterFreeCamera(AtCorner: Boolean = False);
    procedure CycleViewPreset(Step: Integer);

    { deck }
    function DeckHit(X, Y: Integer): Integer;
    procedure DeckActivate(Index: Integer);
    function FindDeck(Group, Value: Integer): Integer;
    function IconLit(Value: Integer): Boolean;
    function IconEnabled(Value: Integer): Boolean;
    function SliderValueAt(const Item: TDeckItem; X: Integer): Integer;
    function IndexOfSym(V: Integer): Integer;
    function InPalette(C: TColor): Boolean;

    function StatusLine: string;
    procedure WashFace(C: TCanvas; const Poly: TPointFArray;
      const Col: TPix);
    procedure PaintProOverlay(C: TCanvas);

    procedure BuildSession(L: TStrings);
    procedure SaveDraft;
    procedure RestoreDraft;
    procedure LoadSettings;
    procedure ApplyCommandLine;
    procedure FollowScreenSize;
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
  VIEW_NAMES: array[TViewKind] of string = ('PLAN', 'ISO', '3D');
  CRASH_LOG = 'heckers-sketch-crash.txt';
  { so a crash report says which build it came from }
  BUILD_STAMP = {$I %DATE%} + ' ' + {$I %TIME%};

  { deck groups }
  GRP_STYLE = 0;
  GRP_SYM   = 1;
  GRP_INK   = 2;
  GRP_ICON  = 3;
  GRP_SIZE  = 4;
  GRP_SCALE = 5;
  GRP_SNAP  = 6;
  GRP_TOOL  = 7;
  GRP_POPUP = 8;   { a button that opens a list rather than setting a value }
  GRP_TOGGLE = 9;  { a button that is simply on or off, and says which }

  { the lists those buttons open }
  POP_NONE  = -1;
  POP_SCALE = 0;
  POP_SNAP  = 1;
  POP_COLOR = 2;
  POP_WIDTH  = 3;
  { The help button opens a list rather than the About box.  Everything that
    lives on the web - the page, the manual, the downloads, somewhere to
    report a problem - had no way in from the program at all, and neither did
    the update check unless you knew to type /update. }
  POP_HELP   = 4;
  { The shop tools: the things that are about making the thing rather than
    drawing it.  Laying a piece out flat is the first; the fitting builders
    go here beside it. }
  POP_SHOP   = 5;
  POP_PREC   = 6;

  { How finely a length is written down, and what the last field of a dashed
    entry counts in.  A truss shop works in sixteenths, which is the default;
    the rest are here because other trades do not. }
  PREC_DENOMS: array[0..6] of Integer = (2, 4, 8, 16, 32, 64, 100);

  { the pen widths the list offers - a few honest steps rather than a slider
    nobody can land on a number with }
  PEN_STEPS = 6;
  PEN_SIZES: array[0..PEN_STEPS - 1] of Integer = (1, 2, 4, 6, 10, 16);

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
  ACT_ORIGIN  = 13;
  ACT_FIT     = 14;
  ACT_OPEN    = 15;
  ACT_EXPORT  = 16;
  { Buttons that come and go with the drawing rather than sitting there
    always.  They live on the settings row so that nothing is ever painted
    over the drawing itself. }
  ACT_GUIDES  = 17;
  ACT_NOGUIDE = 18;

  UNDO_LEVELS     = 16;
  KNOB_PX_PER_RAD = 58.0;
  BASE_SPEED      = 210.0;
  TICK_MS         = 16;
  MIN_PEN         = 1;
  MAX_PEN         = 40;
  SNAP_PX         = 16.0;   // pulling onto a point on the drawing
  INFER_PX        = 7.0;    // lining up with one that is somewhere else
  HOLD_PX         = 18.0;   // ...or with one you deliberately rested on
  { how long the button is leaned on before the line snaps off, and how long
    the two ends recoil afterwards }
  HOLD_STRAIN     = 0.20;   // before this it is just a click being made
  HOLD_BREAK      = 0.70;   // and this long to break.  It was 1.45, set by
                            // guessing at how long a warning needs to be
                            // readable; with the gesture in daily use the
                            // answer came back that it is the wait, not the
                            // warning, that gets noticed.  Three quarters of
                            // a second of strain still says plainly what is
                            // about to happen and still leaves room to let go
  SNAP_RECOIL     = 0.30;
  AXIS_PX         = 8.0;    // how near the axis through a reference counts
  LOCK_PX         = 7.5;    // this close and the point is what you meant
  { and once it has been taken, this far before it is let go again.  Coming
    onto a point is a decision; sliding a couple of pixels off it is not, and
    a snap that lets go the moment you twitch is one you have to fight. }
  STICK_PX        = 20.0;
  PIECE_PX        = 5.0;    // ...and this close for the middle of a piece
  EDGE_PX         = 11.0;   // hovering a line means a point on that line
  { the face under the cursor, tinted the way SketchUp tints one }
  HINT_BLUE: TPix = (B: $F2; G: $B4; R: $76; A: 255);
  AXIS_MIN_PX     = 14.0;   // nearer than this an axis lock says nothing
  DWELL_MS        = 450;    // rest on a point this long to keep it
  { SketchUp's default, and the same reasoning: round enough to read as a
    circle, few enough that extruding one does not bury the drawing in
    entities - a push turns every segment into a wall. }
  CIRCLE_SEGS     = 24;
  { an arc that becomes part of a face's outline needs enough points to read
    as a curve, but every one of them becomes a wall if the face is pulled }
  ARC_SEGS        = 16;

type
  TViewPreset = record
    Name: string;
    View: TViewKind;
    Az, El: Double;
  end;

const
  ISO_EL = 35.264 * Pi / 180;   // the true isometric tilt

  { One key steps through the views worth having.  The four corners come
    first because that is what you actually draw from; the flat elevations
    and the top are there for reading a dimension off. }
  VIEW_PRESETS: array[0..10] of TViewPreset = (
    (Name: 'PLAN';              View: vkPlan;  Az: 0;           El: 0),
    (Name: 'ISO';               View: vkIso;   Az: 0;           El: 0),
    (Name: 'CORNER FRONT-LEFT'; View: vkOrbit; Az: -Pi / 4;     El: ISO_EL),
    (Name: 'CORNER FRONT-RIGHT';View: vkOrbit; Az: Pi / 4;      El: ISO_EL),
    (Name: 'CORNER BACK-RIGHT'; View: vkOrbit; Az: 3 * Pi / 4;  El: ISO_EL),
    (Name: 'CORNER BACK-LEFT';  View: vkOrbit; Az: -3 * Pi / 4; El: ISO_EL),
    (Name: 'FRONT';             View: vkOrbit; Az: 0;           El: 0),
    (Name: 'RIGHT';             View: vkOrbit; Az: Pi / 2;      El: 0),
    (Name: 'BACK';              View: vkOrbit; Az: Pi;          El: 0),
    (Name: 'LEFT';              View: vkOrbit; Az: -Pi / 2;     El: 0),
    (Name: 'TOP';               View: vkOrbit; Az: 0;           El: 1.45));
  PRINT_DPI       = 150;

  SYM_VALUES: array[0..4] of Integer = (1, 2, 4, 6, 8);

  STYLE_NAMES: array[TPenStyle] of string =
    ('CLASSIC', 'NEON', 'RAINBOW', 'SPARKLE', 'CHALK');

  STYLE_HINTS: array[TPenStyle] of string = (
    'Classic - a clean, solid line, just like the real toy.',
    'Neon - a glowing tube of light.  Try it on the Midnight theme.',
    'Rainbow - the color drifts through the spectrum as you draw.',
    'Sparkle - a thin trail that throws off glitter.',
    'Chalk - a soft, dusty, hand-drawn stroke.');

  { one glyph per tool, for the button and for the cursor }
  TOOL_ICONS: array[TProTool] of TIconKind =
    (ikTSelect, ikTMove, ikTLine, ikTRect, ikTArc, ikTCircle, ikTPush,
     ikTText, ikTErase, ikTMeasure, ikDim, ikTOrbit, ikTOffset);

  TOOL_NAMES: array[TProTool] of string =
    ('SELECT', 'MOVE', 'LINE', 'RECT', 'ARC', 'CIRCLE', 'PUSH/PULL', 'TEXT',
     'ERASE', 'MEASURE', 'DIMENSION', 'ORBIT', 'OFFSET');

  { The tools in three groups of four, laid out two rows deep, so a group
    reads as a group and every name has room to be read.  The grouping is
    SketchUp's: what you pick and change with, what you draw with, and what
    you measure and look with. }
  { Three groups: working on what is there, drawing new things, saying what
    they are.  The first has three across because it has five in it - orbit
    belongs with getting about rather than with drawing, and the deck is the
    only place a tool is discoverable at all. }
  GRP_COLS: array[0..2] of Integer = (3, 2, 2);
  GRP_N:    array[0..2] of Integer = (5, 4, 4);
  TOOL_GROUPS: array[0..2, 0..5] of TProTool =
    ((ptSelect, ptMove, ptOrbit, ptErase, ptPush, ptSelect),
     (ptLine, ptRect, ptCircle, ptArc, ptSelect, ptSelect),
     (ptMeasure, ptDim, ptText, ptOffset, ptSelect, ptSelect));

  TOOL_HINTS: array[TProTool] of string = (
    'Select - click to pick, drag a box for several.  Ctrl adds, Shift ' +
      'toggles, Ctrl+Shift takes away.  (Space)',
    'Move - pick a point on what is selected, then click where it goes.  ' +
      'Hold Ctrl to leave a copy behind.  (M)',
    'Line - click a start point, then click the end or just type a length.',
    'Rectangle - click two opposite corners, or type 12''x8''.  Makes a face.',
    'Arc - pick two points, then pull the middle out.  Joins two loose ends.',
    'Circle - pick the center, then type or drag the radius.',
    'Push/pull - click a face and type how far to lift it.  Close a loop of ' +
      'lines to make a face.',
    'Text - click where the note goes and type it.',
    'Erase - click anything to delete it.',
    'Measure - click two points and read the distance between them.',
    'Dimension - click two points, then drag away to place the line.',
    'Orbit - drag to spin the view.  Hold Shift to pan instead.  (O)',
    'Offset - click a face, then move in or out and click, or type a wall ' +
      'thickness.  (F)');

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

{ The four corners of the rectangle with A and B at opposite ends, lying in
  the working plane.  The plane decides which pair of coordinates varies; the
  third stays at A's, which is what keeps the rectangle flat and gives the
  face it makes a normal worth pushing along. }
function RectCorners(const A, B: TP3; Pl: TPlane): TP3Array;
var
  FO, FU, FV, FN, D: TP3;
  Du, Dv: Double;
begin
  Result := nil;
  SetLength(Result, 4);
  if Pl = plFree then
  begin
    { The corners are laid out along the plane's own two directions rather
      than along a pair of world axes, which is the whole of what makes a
      rectangle possible on a roof. }
    GetFreePlane(FO, FU, FV, FN);
    D := P3(B.X - A.X, B.Y - A.Y, B.Z - A.Z);
    Du := D.X * FU.X + D.Y * FU.Y + D.Z * FU.Z;
    Dv := D.X * FV.X + D.Y * FV.Y + D.Z * FV.Z;
    Result[0] := A;
    Result[1] := P3(A.X + FU.X * Du, A.Y + FU.Y * Du, A.Z + FU.Z * Du);
    Result[2] := P3(Result[1].X + FV.X * Dv, Result[1].Y + FV.Y * Dv,
                    Result[1].Z + FV.Z * Dv);
    Result[3] := P3(A.X + FV.X * Dv, A.Y + FV.Y * Dv, A.Z + FV.Z * Dv);
    Exit;
  end;
  case Pl of
    plXZ:
      begin
        Result[0] := P3(A.X, A.Y, A.Z);
        Result[1] := P3(B.X, A.Y, A.Z);
        Result[2] := P3(B.X, A.Y, B.Z);
        Result[3] := P3(A.X, A.Y, B.Z);
      end;
    plYZ:
      begin
        Result[0] := P3(A.X, A.Y, A.Z);
        Result[1] := P3(A.X, B.Y, A.Z);
        Result[2] := P3(A.X, B.Y, B.Z);
        Result[3] := P3(A.X, A.Y, B.Z);
      end;
  else
    begin
      Result[0] := P3(A.X, A.Y, A.Z);
      Result[1] := P3(B.X, A.Y, A.Z);
      Result[2] := P3(B.X, B.Y, A.Z);
      Result[3] := P3(A.X, B.Y, A.Z);
    end;
  end;
end;

{ The two side lengths of that rectangle, in the plane's own order. }
procedure RectSides(const A, B: TP3; Pl: TPlane; out W, H: Double);
var
  FO, FU, FV, FN, D: TP3;
begin
  if Pl = plFree then
  begin
    GetFreePlane(FO, FU, FV, FN);
    D := P3(B.X - A.X, B.Y - A.Y, B.Z - A.Z);
    W := Abs(D.X * FU.X + D.Y * FU.Y + D.Z * FU.Z);
    H := Abs(D.X * FV.X + D.Y * FV.Y + D.Z * FV.Z);
    Exit;
  end;
  case Pl of
    plXZ: begin W := Abs(B.X - A.X); H := Abs(B.Z - A.Z); end;
    plYZ: begin W := Abs(B.Y - A.Y); H := Abs(B.Z - A.Z); end;
  else    begin W := Abs(B.X - A.X); H := Abs(B.Y - A.Y); end;
  end;
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
function TMainForm.ResolveSnapRaw(SX, SY: Double): TP3;
var
  Hit: TSnapHit;
  Pts: TP3Array;
  I, BestAxis: Integer;
  Tol, D, Best: Double;
  W, Wf, AxRef, AxPt, EdgeP, AxSnapP: TP3;
  SP: TPointF;
  PtOK: Boolean;
  PtPx, AxPx: Double;
  AxIdx, EdgeI, AxSnapK: Integer;

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

  { The second half of a compound inference.

    Once an axis has pinned two of the three coordinates, the third is still
    free, and it can be pulled level with a point we are holding.  That is
    the whole trick behind closing a rectangle square: run left along the red
    axis from the top corner, and the free coordinate lands on the X of the
    bottom-left corner you rested on a moment ago.

    Before this the axis fired and the function returned there and then, so
    the alignment guide you had just charged up was thrown away the instant
    the line snapped to an axis - which is exactly when you need it. }
  procedure AlignFree(var Q: TP3; FreeAxis: Integer);
  var
    I: Integer;
    APts: TP3Array;
    Cur, BestOff: Double;
    BestPt: TP3;
    Got: Boolean;

    function Coord(const C: TP3): Double;
    begin
      case FreeAxis of
        0: Result := C.X;
        1: Result := C.Y;
      else Result := C.Z;
      end;
    end;

    function TryLevel(const C: TP3; Tol: Double): Boolean;
    var
      Off: Double;
    begin
      Result := False;
      Off := Abs(Coord(C) - Cur) * Ppu;
      if Off > Tol then Exit;
      { it has to be somewhere else, or the guide is a dot on the cursor }
      if Dist(Q, C) * Ppu < 18 then Exit;
      if Off >= BestOff then Exit;
      BestOff := Off;
      BestPt := C;
      Got := True;
      Result := True;
    end;

  begin
    Cur := Coord(Q);
    BestOff := 1E30;
    Got := False;

    { a point you rested on is the one you meant, so it goes first and wins
      outright if it is anywhere near }
    { A point you rested on was asked for, so it holds from much further out
      than one the engine merely noticed.  Seven pixels either side is nothing
      when you are coming back across the drawing to close a rectangle. }
    if not (FLockOn and TryLevel(FLockPt, HOLD_PX)) then
    begin
      FD.Doc.SnapPoints(APts);
      for I := 0 to High(APts) do TryLevel(APts[I], INFER_PX);
      if FStage > 0 then TryLevel(FP1, INFER_PX);
    end;
    if not Got then Exit;

    case FreeAxis of
      0: Q.X := BestPt.X;
      1: Q.Y := BestPt.Y;
    else Q.Z := BestPt.Z;
    end;
    FGuide := True;
    FGuideFrom := BestPt;
  end;

  { The cursor is on an axis through R when it differs from R along one
    direction only.  The error - how far off that line it is - is what
    competes with the point snaps, so it is measured in pixels like they
    are.  A lock only means something once you are some way along it;
    right next to R every axis matches and the cursor would stick. }
  { Is the cursor sitting on one of the three axes through R?

    Measured on the screen, against the axis as it is drawn, rather than in
    the model.  That matters in an isometric or 3D view, where the cursor is
    only ever a ray: unprojecting it pins one model coordinate to the working
    plane, so comparing model coordinates could never see the pinned one move.
    With the plane flat that made DZ permanently zero, and the blue axis
    impossible to infer - you could not click out a riser at all.  You got a
    diagonal run across the ground that looked exactly like a riser and
    measured 1.41 times what it should, which for a fab drawing is cut pipe in
    the bin.

    Working on screen, the answer comes back as a point on the axis itself,
    so the working plane has no say in it. }
  procedure AxisTry(const R: TP3);
  var
    K: Integer;
    Off, Along, T, LenSq: Double;
    PR, PA: TPointF;
    AD: TP3;
    UX, UY, VX, VY: Double;
  begin
    PR := ScreenOf(R);
    for K := 0 to 2 do
    begin
      { one unit along the axis, as it reads on screen }
      case K of
        0: AD := P3(1, 0, 0);
        1: AD := P3(0, 1, 0);
      else AD := P3(0, 0, 1);
      end;
      PA := ScreenOf(P3(R.X + AD.X, R.Y + AD.Y, R.Z + AD.Z));
      UX := PA.X - PR.X;
      UY := PA.Y - PR.Y;
      LenSq := UX * UX + UY * UY;

      { An axis pointing near enough at the camera projects to a stub, and a
        stub is not something you can aim along: every cursor position is
        "on" that line, so the off-axis error comes out near zero and it wins
        every contest - while the distance *along* it comes out astronomical,
        because a pixel of movement is worth a mile in the model.  The point
        that fell out of that was somewhere past 1E12, and drawing a rubber
        band to it is what crashed the program.

        One world unit has to project to at least a fifth of what a unit
        square-on to the screen would, so an axis more than about 78 degrees
        out of the screen plane simply has no opinion.  In plan and isometric
        no axis is ever that steep; only the free camera can do it, which is
        why this only ever went wrong in the 3D view. }
      if LenSq < Sqr(0.2 * Ppu) then Continue;

      VX := SX - PR.X;
      VY := SY - PR.Y;
      Along := (VX * UX + VY * UY) / LenSq;      // in axis units
      Off := Abs(VX * UY - VY * UX) / Sqrt(LenSq);

      if Abs(Along) * Sqrt(LenSq) < AXIS_MIN_PX then Continue;
      if Off < AxPx then
      begin
        { belt and braces: a point that is not a real number, or is further
          out than any drawing could be, is not an answer }
        T := Along;
        if IsNan(T) or IsInfinite(T) or (Abs(T) > 1E9) then Continue;
        AxPx := Off;
        AxIdx := K;
        AxRef := R;
        { the point on the axis nearest the cursor, in the model }
        AxPt := P3(R.X + AD.X * T, R.Y + AD.Y * T, R.Z + AD.Z * T);
      end;
    end;
  end;

begin
  FGuide := False;
  FAxisLock := -1;

  { SNAP OFF means off: no grid, no points, no guides.  Holding Alt suspends
    all of it for one move, which is the usual way out of a sticky snap. }
  if (SnapStep <= 0) or FPenUp then
  begin
    FSnapKind := snNone;
    Exit(WorldAt(SX, SY));
  end;

  Wf := WorldAt(SX, SY);

  { Still holding the point it took last time?

    Coming onto a point is a decision.  Sliding two pixels off it is not, and
    letting go that easily makes a snap something you fight rather than
    something you use - which is what Tony noticed against SketchUp, where a
    point holds until you clearly mean to leave.  So it is taken from close
    in and released from much further out, and the gap between the two is the
    whole feel of it.

    Only for points that are really there.  A grid intersection is everywhere
    and has nothing to stick to. }
  if FStickOn and (FStickKind in [snEndpoint, snMidpoint, snCenter, snCross,
                                  snSubMid]) then
  begin
    SP := ScreenOf(FStickPt);
    if Sqr(SX - SP.X) + Sqr(SY - SP.Y) <= Sqr(STICK_PX * FUIScale) then
    begin
      FSnapKind := FStickKind;
      Exit(FStickPt);
    end;
    FStickOn := False;
  end;

  PtOK := FD.Doc.BestSnap(Proj, SX, SY, SNAP_PX, Hit);
  PtPx := 1E30;
  if PtOK then
  begin
    SP := ScreenOf(Hit.P);
    PtPx := Sqrt(Sqr(SX - SP.X) + Sqr(SY - SP.Y));
  end;

  { A definite point right under the cursor is what you were aiming at, so
    it still wins outright.  A piece-midpoint does not count as definite -
    those are the ones that turn up at the quarter points of everything you
    have already split, and they are exactly what used to steal the cursor. }
  if PtOK and (PtPx <= LOCK_PX) and
     (Hit.Kind in [snEndpoint, snCross, snCenter, snMidpoint, snOrigin]) then
  begin
    FSnapKind := Hit.Kind;
    FStickOn := True;
    FStickPt := Hit.P;
    FStickKind := Hit.Kind;
    Exit(Hit.P);
  end;

  { The middle of a piece of a line gets a shorter reach of its own.  These
    are the ones that turn up at every quarter point of a shape you have
    divided, so they should not grab from as far away as a corner - but they
    are also exactly what you are aiming at when you divide something up, and
    before this they could only be had by beating the axis guides. }
  if PtOK and (PtPx <= PIECE_PX) and (Hit.Kind = snSubMid) then
  begin
    FSnapKind := Hit.Kind;
    Exit(Hit.P);
  end;

  { A line under the pointer means a point on that line.  SketchUp calls this
    On Edge, and without it running along an edge gave you nothing to hold on
    to: the axis guide from some distant corner would win and drag the point
    off the edge into open space.  It sits above the guides because a real
    piece of geometry under the pointer is a more definite answer than an
    alignment to something far away.

    But it comes second to any named point within reach.  "Somewhere along
    this line" is the weakest thing the drawing can tell you, and letting it
    win made the middle of a line almost impossible to hit: outside the four
    and a half pixels where a midpoint is taken outright, On Edge grabbed the
    cursor and put it a fraction to one side. }
  if (not PtOK) and
     FD.Doc.EdgeSnap(Proj, SX, SY, EDGE_PX * FUIScale, EdgeP, EdgeI) then
  begin
    FSnapKind := snOnEdge;
    Exit(EdgeP);
  end;

  { And the same for the three axes, which are lines like any other as far as
    the cursor is concerned - SketchUp's On Red Axis and its two friends.

    Under real geometry, because a line somebody drew is a more definite
    answer than one the program is offering; over the alignment guides,
    because "on the red axis" is a statement about where the point is and a
    guide is a statement about some other point.  It is also all a brand new
    sheet has: before this an empty drawing snapped to nothing whatever, so
    the tape could not be started off an axis and the origin - the one point
    in any model whose coordinates everybody knows - could not be landed on.

    It is what makes the Z readout move, too.  The cursor is unprojected onto
    the working plane, which pins Z to that plane's height, so Z could only
    ever read the same number.  A point on the blue axis is a point with a
    real Z, and the readout follows it up. }
  if (not PtOK) and
     AxisSnap(Proj, SX, SY, EDGE_PX * FUIScale, AxSnapP, AxSnapK) then
  begin
    FSnapKind := snOnAxis;
    FSnapAxis := AxSnapK;
    Exit(AxSnapP);
  end;

  { Otherwise a 90 degree relationship to a point you chose - the start of
    the line, or one you rested on - beats whatever else is nearby.  Going
    straight up from the corner you started at is nearly always the answer
    you wanted, and before this it could not win against any stray point
    within snapping distance. }
  AxIdx := -1;
  AxPx := AXIS_PX;
  AxPt := Wf;
  AxRef := Wf;              { only read once AxisTry has set it; keeps the
                              compiler from having to take that on trust }
  if FDirLock < 0 then
  begin
    if FStage > 0 then AxisTry(FP1);
    if FLockOn then AxisTry(FLockPt);
  end;

  { A corner beats a guide it is nearer than.

    The guide was put in front of every other point because a stray one
    within snapping distance could steal a deliberate axis run.  That is
    true of the strays - a piece-midpoint, a point somewhere along an edge -
    and it is not true of a corner.  A corner is a place somebody built, it
    is drawn on the screen, and it is almost always the thing being aimed
    at: dimensioning the corner of one building to the corner of another,
    the guide running out of the first corner lies near the second one
    practically by construction, and it took the point every time.  The
    corner could not be had at all.

    So a definite point within snapping distance takes it from the guide.
    Everything else still loses to the guide, which is what the rule was
    protecting in the first place.

    Not by comparing the two distances, which was the first thing tried and
    is not a fair contest: a guide is a line, so its distance is small
    whenever you are anywhere near it, and a corner eight pixels off could
    never beat a line one pixel off.  A point is a stronger statement than a
    line and wins on being one. }
  if PtOK and (AxIdx >= 0) and
     (Hit.Kind in [snEndpoint, snCross, snCenter, snMidpoint, snOrigin]) then
    AxIdx := -1;

  if AxIdx >= 0 then
  begin
    { The distance along the axis still snaps, so a riser lands on a round
      number; the other two coordinates come from the reference point, which
      is what puts the result exactly on the axis. }
    W := SnapToGrid(AxPt);
    case AxIdx of
      0: begin W.Y := AxRef.Y; W.Z := AxRef.Z; end;
      1: begin W.X := AxRef.X; W.Z := AxRef.Z; end;
    else begin W.X := AxRef.X; W.Y := AxRef.Y; end;
    end;
    FAxisLock := AxIdx;
    FAxisFrom := AxRef;
    FSnapKind := snGrid;
    { and the third coordinate can still line up with something }
    AlignFree(W, AxIdx);
    Exit(W);
  end;

  if PtOK then
  begin
    FSnapKind := Hit.Kind;
    Exit(Hit.P);
  end;

  W := SnapToGrid(Wf);
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

{ A point pulled back onto the face it is being drawn on.

  Drawing on a face means every point of the shape is on that face - that is
  what drawing on it means.  Not every inference knows it.  The model axes
  are infinite lines through the origin, so they run along the base of
  anything standing on the ground: drawing a window low on a column, the
  green axis lies right along the bottom of the face and takes the cursor
  straight off it, sideways into open space.  The reading said ON FACE while
  the point was somewhere else, and the shape went where the point was.

  Held to the plane instead.  It costs nothing when the snap was already in
  the plane, which is nearly always, and the rest of the time it is the
  difference between an inference that helps and one that quietly moves your
  work somewhere you did not ask for. }
function TMainForm.HeldToFace(const P: TP3): TP3;
var
  D: Double;
begin
  Result := P;
  if not FPlaneFromFace then Exit;
  D := (P.X - FFacePt.X) * FFaceNm.X + (P.Y - FFacePt.Y) * FFaceNm.Y +
       (P.Z - FFacePt.Z) * FFaceNm.Z;
  Result := P3(P.X - FFaceNm.X * D, P.Y - FFaceNm.Y * D, P.Z - FFaceNm.Z * D);
end;

function TMainForm.ResolveSnapAt(SX, SY: Double): TP3;
begin
  Result := HeldToFace(ResolveSnapRaw(SX, SY));
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

function TMainForm.TrackedText(C: TCanvas; X, Y: Integer; const S: string;
  Tracking: Integer): Integer;
var
  I, X0: Integer;
begin
  X0 := X;
  for I := 1 to Length(S) do
  begin
    C.TextOut(X, Y, S[I]);
    Inc(X, C.TextWidth(S[I]) + Tracking);
  end;
  Result := X - X0;
end;

function TMainForm.ToolName(T: TProTool): string;
begin
  Result := TOOL_NAMES[T];
end;

{ ======================================================================== }
{ lifecycle                                                                 }
{ ======================================================================== }

{ Handed to uSurface so a repair lands in the trail beside the tool that was
  in hand when it happened. }
procedure SurfaceRepaired(const What: string);
begin
  if MainForm <> nil then MainForm.Trail(What);
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  I: Integer;
begin
  Application.OnException := @ReportCrash;
  Randomize;
  FRunTag := IntToHex(GetTickCount64 and $FFFFFF, 6) + IntToHex(Random($10000), 4);
  { real hover tooltips on the deck, not just the hint line }
  pbDeck.ShowHint := True;
  Application.ShowHint := True;
  Application.HintPause := 450;
  Application.HintHidePause := 6000;
  Randomize;
  uSurface.OnSurfaceRepair := @SurfaceRepaired;
  { Said before anything can be typed.  Zero is a real entity index, so a
    field left at its default reads as "editing the label on the first
    thing in the drawing". }
  FDimEdit := -1;
  FLenDenom := LenDenom;
  FNoteDrag := -1;
  FCursorWas := crCross;
  Caption := APP_NAME + '  ' + CurrentVersion;
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
  FGlyph := TArtSurface.Create(16, 16);
  FPopup := POP_NONE;
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
  { Dimensions carry the drawing on an isometric - the geometry is only there
    to hang them off - so they are set a size up from the rest of the labels. }
  FDimFont.Height := -Round(13 * FUIScale);

  FMode := mdToy;
  FThemeIdx := THEME_PRO_DARK;
  FToyTheme := 0;
  FProTheme := THEME_PRO_DARK;
  FStyle := psClassic;
  FPenSize := 4;
  FEdgeW := 1;
  FMeasEdge := -1;
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
  FOffFace := -1;
  FHoverFace := -1;
  FHint := TOY_HINT;

  LoadSettings;
  ApplyCommandLine;
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

{ Where the window is, written down while there is still a window to ask.

  This used to be read in OnDestroy along with everything else, which works
  on GTK and does not work on Windows: by the time the form is being
  destroyed there the handle is gone, and RestoredLeft and the rest answer
  with whatever they have left rather than with where the window was.  So the
  position was saved faithfully on Linux and saved as rubbish on Windows,
  which is exactly the shape of the complaint - it remembers here, it never
  remembers there. }
procedure TMainForm.RememberWindow;
begin
  if not HandleAllocated then Exit;
  FWinMax := WindowState = wsMaximized;
  if WindowState = wsNormal then
  begin
    { An ordinary window knows where it is.  Restored* is the LCL's memory of
      where it was before it got maximised, and it is a beat behind after the
      window has just been moved - which showed up here as one save in three
      writing down the position the window had opened at rather than the one
      it was closed at. }
    FWinL := Left;
    FWinT := Top;
    FWinW := Width;
    FWinH := Height;
  end
  else
  begin
    { Maximised or full screen, ask what it will go back to.  Left and Width
      here would be the size of the screen, and it would come back filling it
      with no way to make it smaller. }
    FWinL := RestoredLeft;
    FWinT := RestoredTop;
    FWinW := RestoredWidth;
    FWinH := RestoredHeight;
  end;
  FWinSaved := (FWinW > 200) and (FWinH > 200);
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  RememberWindow;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
var
  I: Integer;
begin
  { Last thing before the sheets go: close the program with work on the
    screen and it is still there next time. }
  if FEditSeq <> FDraftSeq then SaveDraft;
  SaveSettings;
  FDimFont.Free;
  for I := High(FDrawings) downto 0 do
    FDrawings[I].Free;
  FOverlay.Free;
  for I := 0 to 1 do
    FKnobSkin[I].Free;
  FViewSkin.Free;
  FGlyph.Free;
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
var
  I: Integer;
  Opened: Boolean;
begin
  if FBooted then Exit;
  FBooted := True;
  ApplyModeTheme;
  Relayout;
  FD.ViewX := Round(FArt.Width * 0.10);
  FD.ViewY := Round(FArt.Height * 0.88);
  FCur := P3(0, 0, 0);
  LayoutTabs;
  FPenX := FArt.Width / 2;
  FPenY := FArt.Height / 2;
  FreshScreen;

  { heckers-sketch drawing.hsk opens it straight away.  Scan for it rather
    than taking the first argument, so a switch in front of the filename does
    not hide it. }
  Opened := False;
  for I := 1 to ParamCount do
    if (Copy(ParamStr(I), 1, 1) <> '-') and FileExists(ParamStr(I)) then
    begin
      Opened := LoadDocument(ParamStr(I));
      Break;
    end;
  { Nothing named on the command line, so carry on from last time.  A file
    asked for by name always wins - it is a clear instruction, and the draft
    is only a safety net. }
  if not Opened then RestoreDraft;

  { Housekeeping from last time.  Nothing here may put a dialog on screen:
    this runs before the window has painted, so a dialog would sit in front
    of a black rectangle with nothing behind it - which is a program that
    looks like it has hung, and gets force-quit, which writes another crash
    report, which shows another dialog next time.  Offering the report waits
    for the tick, once the window is actually up. }
  ForgetPreviousBuild;
end;

{ The command line, for a launcher that wants the window a particular way.
  A switch here beats whatever was saved last time, which is the point: the
  remembered size is a convenience for a person, and a launcher is not one.
  Anything we do not recognize is ignored rather than fatal - a program that
  refuses to start because of a stray argument is no use to anybody. }
procedure TMainForm.ApplyCommandLine;
var
  I, X: Integer;
  A, V: string;
  W, H: Integer;
begin
  for I := 1 to ParamCount do
  begin
    A := LowerCase(ParamStr(I));
    if (A = '--maximized') or (A = '--maximised') or (A = '-max') then
    begin
      FFill := flMaximized;
      WindowState := wsMaximized;
    end
    else if (A = '--fullscreen') or (A = '-full') then
    begin
      { Deliberately not BorderStyle := bsNone.  A borderless window is a
        window GTK marks as not resizable, and it says so in the X size hints
        - minimum, maximum and base all pinned to whatever size it opened at.
        A remote display that later changes size then cannot resize it, which
        is exactly what happens when KasmVNC follows the browser window.

        Ask the window manager for full screen, which drops the frame and
        keeps the window resizable, and set the bounds ourselves as well for
        the case where there is no window manager at all. }
      FFill := flFull;
      WindowState := wsFullScreen;
      SetBounds(Monitor.Left, Monitor.Top, Monitor.Width, Monitor.Height);
    end
    else if Copy(A, 1, 7) = '--size=' then
    begin
      { --size=1600x1000 }
      V := Copy(A, 8, MaxInt);
      X := Pos('x', V);
      if X > 1 then
      begin
        W := StrToIntDef(Copy(V, 1, X - 1), 0);
        H := StrToIntDef(Copy(V, X + 1, MaxInt), 0);
        if (W > 320) and (H > 240) then
        begin
          FFill := flNone;
          WindowState := wsNormal;
          SetBounds(Left, Top, W, H);
          Position := poScreenCenter;
        end;
      end;
    end
    { --help is answered in the program file, before any of this exists }
  end;
end;

{ ======================================================================== }
{ layout                                                                    }
{ ======================================================================== }

{ TOY earns its big friendly header - it is half the character of the thing.
  PRO does not: it is a drawing board, and every pixel of chrome is a pixel
  off the drawing. The two modes get their own sizes rather than one
  compromise that suits neither.

  Relayout, RebuildShell, pbDeckPaint and FormPaint all have to agree about
  these, and before this they agreed by having the same numbers typed into
  each of them. }
function TMainForm.TitleHeight: Integer;
begin
  if FMode = mdPro then
    Result := Round(34 * FUIScale)
  else
    Result := Round(84 * FUIScale);
end;

function TMainForm.ChromeMargin: Integer;
begin
  if FMode = mdPro then
    Result := Round(8 * FUIScale)
  else
    Result := Round(22 * FUIScale);
end;

function TMainForm.DeckRowH: Integer;
begin
  { 20 was too tight: the longer tool names were being clipped and the icons
    had nothing to sit in. }
  if FMode = mdPro then
    Result := Round(24 * FUIScale)
  else
    Result := Round(30 * FUIScale);
end;

{ Derived from the rows rather than fixed, so adding a fifth row of tools is
  a change in one place instead of a constant nobody remembers to update. }
{ PRO puts scale and snap on one row, so it needs three; TOY still has four.
  Derived either way, so another row is a change here and nowhere else. }
function TMainForm.DeckRows: Integer;
begin
  { two rows of tools, in three groups, and one row for the settings }
  if FMode = mdPro then Result := 3 else Result := 4;
end;

function TMainForm.DeckHeight: Integer;
begin
  if FMode = mdPro then
    Result := DeckRows * DeckRowH + (DeckRows - 1) * Round(4 * FUIScale) +
      Round(10 * FUIScale)
  else
    Result := DeckRows * DeckRowH + (DeckRows - 1) * Round(8 * FUIScale) +
      Round(28 * FUIScale);
end;

procedure TMainForm.Relayout;
var
  M, TitleH, DeckH, Bezel, KnobSz, Gap, ModeW, ModeH, CmdH, TabsH: Integer;
  BezelR, DeckR: TRect;
  DeckL, DeckRt: Integer;
  I: Integer;
begin
  if not FBooted then Exit;

  M := ChromeMargin;
  TitleH := TitleHeight;
  DeckH := DeckHeight;
  Bezel := Round(16 * FUIScale);
  Gap := Round(16 * FUIScale);
  ModeW := Round(186 * FUIScale);
  ModeH := Round(32 * FUIScale);
  if FMode = mdPro then
  begin
    CmdH := Round(28 * FUIScale);
    TabsH := Round(22 * FUIScale);
    Gap := Round(6 * FUIScale);
  end
  else
  begin
    CmdH := Round(44 * FUIScale);
    TabsH := Round(30 * FUIScale);
  end;

  if FMode = mdPro then
    pbMode.SetBounds(ClientWidth - M - ModeW, Round(3 * FUIScale),
      ModeW, Round(22 * FUIScale))
  else
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
  M := ChromeMargin;
  TitleH := TitleHeight;
  DeckH := DeckHeight;
  Bezel := Round(16 * FUIScale);
  if FMode = mdPro then
  begin
    Gap := Round(6 * FUIScale);
    CmdH := Round(28 * FUIScale);
    TabsH := Round(22 * FUIScale);
  end
  else
  begin
    Gap := Round(16 * FUIScale);
    CmdH := Round(44 * FUIScale);
    TabsH := Round(30 * FUIScale);
  end;

  if FMode = mdPro then
    BezelR := Rect(M, TitleH + TabsH + Round(4 * FUIScale), ClientWidth - M,
      ClientHeight - M - DeckH - Gap - CmdH - Round(10 * FUIScale))
  else
    BezelR := Rect(M, TitleH, ClientWidth - M, ClientHeight - M - DeckH - Gap);

  PaintShell(FShell, Theme);
  if FMode = mdPro then
    PaintBezel(FShell, BezelR, Theme, Round(5 * FUIScale))
  else
    PaintBezel(FShell, BezelR, Theme, 22);
  PaintScreenWell(FShell, Rect(BezelR.Left + Bezel, BezelR.Top + Bezel,
    BezelR.Right - Bezel, BezelR.Bottom - Bezel), Round(3 * FUIScale));

  if FMode = mdToy then
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
  { Every surface, not just the picture.  Asking only FArt meant that if the
    four ever came apart - a resize that gave up part way through, a surface
    built at some other size - then the one check that could have put them
    back together again was the one that said there was nothing to do, and
    they stayed apart for the rest of the run. }
  if (FArt.Width = AW) and (FArt.Height = AH) and
     (FPaper.Width = AW) and (FPaper.Height = AH) and
     (FInkToy.Width = AW) and (FInkToy.Height = AH) and
     (FInkPro.Width = AW) and (FInkPro.Height = AH) then Exit;

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

{ Orbiting has no lattice - a fixed grid looks wrong from an arbitrary angle
  - so the three model axes are the only thing telling you which way is
  which.  Positive solid, negative faint, each in its own color, and the
  same colors the rubber band picks up when you lock onto one. }
{ SketchUp stipples the face under the cursor so you can see there is
  something to grab before committing to it.  Same idea: a field of dots
  clipped to the polygon, and a bold outline. }
procedure TMainForm.PaintFaceHint(C: TCanvas; Face: Integer; const Col: TPix);
var
  Pts: TPointFArray;
  I, J, N, X, Y, X0, Y0, X1, Y1, Step: Integer;
  Inside: Boolean;
begin
  if Face < 0 then Exit;
  Pts := FD.Doc.Outline(Proj, Face);
  N := Length(Pts);
  if N < 3 then Exit;

  X0 := MaxInt; Y0 := MaxInt; X1 := -MaxInt; Y1 := -MaxInt;
  for I := 0 to N - 1 do
  begin
    X0 := Min(X0, Round(Pts[I].X)); X1 := Max(X1, Round(Pts[I].X));
    Y0 := Min(Y0, Round(Pts[I].Y)); Y1 := Max(Y1, Round(Pts[I].Y));
  end;
  X0 := Max(X0, 0); Y0 := Max(Y0, 0);
  X1 := Min(X1, pbScreen.Width - 1); Y1 := Min(Y1, pbScreen.Height - 1);
  if (X1 <= X0) or (Y1 <= Y0) then Exit;

  { A dither, because the canvas has no alpha channel and a tint has to be
    made out of gaps.  Every other pixel reads as a solid wash at a glance,
    which is what SketchUp does: the face you are pointing at should be
    unmistakable rather than a hint. }
  Step := 2;
  Y := Y0 - (Y0 mod Step);
  while Y <= Y1 do
  begin
    X := X0 - (X0 mod Step);
    while X <= X1 do
    begin
      Inside := False;
      J := N - 1;
      for I := 0 to N - 1 do
      begin
        if ((Pts[I].Y > Y) <> (Pts[J].Y > Y)) and
           (X < (Pts[J].X - Pts[I].X) * (Y - Pts[I].Y) /
                (Pts[J].Y - Pts[I].Y) + Pts[I].X) then
          Inside := not Inside;
        J := I;
      end;
      if Inside and (X >= X0) and (Y >= Y0) then
        C.Pixels[X, Y] := PixToColor(Col);
      Inc(X, Step);
    end;
    Inc(Y, Step);
  end;

  C.Pen.Color := PixToColor(Col);
  C.Pen.Width := Max(2, Round(2 * FUIScale));
  C.Pen.Style := psSolid;
  C.MoveTo(Round(Pts[N - 1].X), Round(Pts[N - 1].Y));
  for I := 0 to N - 1 do
    C.LineTo(Round(Pts[I].X), Round(Pts[I].Y));
  C.Pen.Width := 1;
end;

{ How far the push would go.  The cursor always says which way along the
  face normal; a typed number only says how far, so typing 6" after moving
  inwards pushes in rather than jumping back out. }
{ Where the cursor lands on a plane that is not the working plane.

  The working plane turns the cursor into a point for drawing, but the offset
  tool has to answer about the face under it, which may lie anywhere.  In an
  orthographic view every pixel is a ray along the view direction, so this is
  just where that ray crosses the face's own plane. }
function TMainForm.CursorOnPlane(const N, P0: TP3): TP3;
var
  O, Dir: TP3;
  Den, T: Double;
begin
  O := WorldAt(FMouseSX, FMouseSY);
  Result := O;
  Dir := ViewDir(Proj);
  Den := Dot3(N, Dir);
  if Abs(Den) < 1E-9 then Exit;          // looking along the face, edge on
  T := (N.X * (P0.X - O.X) + N.Y * (P0.Y - O.Y) + N.Z * (P0.Z - O.Z)) / Den;
  Result := P3(O.X + Dir.X * T, O.Y + Dir.Y * T, O.Z + Dir.Z * T);
end;

{ How far in or out the cursor is from the face's outline, in the face's own
  plane.  Outside is positive and grows the shape; inside is negative and is
  the one you want for a duct wall.  A typed number sets the size and the
  cursor keeps saying which way. }
function TMainForm.OffsetDistance: Double;
var
  Loop: TP3Array;
  N, P, A, B, W, V: TP3;
  I, J, Cnt: Integer;
  Best, D, T, L2: Double;
begin
  Result := 0;
  if (FOffFace < 0) or (FOffFace >= FD.Doc.Live) then Exit;
  Loop := FD.Doc[FOffFace].Poly;
  Cnt := Length(Loop);
  if Cnt < 3 then Exit;
  N := FD.Doc.FaceNormal(FOffFace);
  P := CursorOnPlane(N, Loop[0]);

  Best := 1E30;
  for I := 0 to Cnt - 1 do
  begin
    J := (I + 1) mod Cnt;
    A := Loop[I];
    B := Loop[J];
    V := P3(B.X - A.X, B.Y - A.Y, B.Z - A.Z);
    W := P3(P.X - A.X, P.Y - A.Y, P.Z - A.Z);
    L2 := V.X * V.X + V.Y * V.Y + V.Z * V.Z;
    if L2 < 1E-18 then T := 0
    else T := EnsureRange((W.X * V.X + W.Y * V.Y + W.Z * V.Z) / L2, 0, 1);
    D := Dist(P, P3(A.X + V.X * T, A.Y + V.Y * T, A.Z + V.Z * T));
    if D < Best then Best := D;
  end;

  if PointInLoop(P, Loop, N) then Result := -Best else Result := Best;
  if SnapStep > 0 then Result := Round(Result / SnapStep) * SnapStep;

  { a typed thickness wins on size; the cursor still says in or out }
  if (FInput <> '') and ParseLen(FInput, FD.Units, D) then
  begin
    if Result < 0 then Result := -Abs(D) else Result := Abs(D);
  end;
end;

{ The loop the offset would lay down, for the rubber-band preview. }
function TMainForm.OffsetPreview: TP3Array;
var
  D: Double;
begin
  Result := nil;
  if (FOffFace < 0) or (FOffFace >= FD.Doc.Live) then Exit;
  D := OffsetDistance;
  if Abs(D) < 1E-9 then Exit;
  Result := OffsetLoop(FD.Doc[FOffFace].Poly, FD.Doc.FaceNormal(FOffFace), D);
end;

procedure TMainForm.CommitOffset;
var
  R: TP3Array;
  I, Cnt, Was: Integer;
  D: Double;
begin
  D := OffsetDistance;
  R := OffsetPreview;
  Cnt := Length(R);
  if Cnt < 3 then
  begin
    if Abs(D) > 1E-9 then
      FCmdMsg := 'That takes it in further than it will go - ' +
        FormatLen(Abs(D), FD.Units) + ' turns the face inside out.'
    else
      FCmdMsg := 'Move in or out from the face first, or type a thickness.';
    Exit;
  end;
  PushUndo;
  Was := FaceCount;
  for I := 0 to Cnt - 1 do
    if not FD.Doc.HasLine(R[I], R[(I + 1) mod Cnt]) then
      FD.Doc.AddLine(R[I], R[(I + 1) mod Cnt], FInkColor, FEdgeW, False);
  RebuildFlatFaces;
  RenderPro;
  RecomposeAll;
  FCmdMsg := Format('Offset %s %s   %d face%s now',
    [FormatLen(Abs(D), FD.Units),
     specialize IfThen<string>(D < 0, 'in', 'out'),
     FaceCount, specialize IfThen<string>(FaceCount = 1, '', 's')]);
  if FaceCount = Was then
    FCmdMsg := FCmdMsg + ' - nothing new closed';
  FOffFace := -1;
  ResetTool;
  FInput := '';
end;

{ Right-click a dimension and write over its figure.

  A dimension on a fabrication drawing often has to say something the geometry
  does not: a nominal size, a cut length that allows for a fitting, or FIELD
  VERIFY.  On an isometric, which is not to scale to begin with, the written
  figure is the drawing.  Clearing the box hands it back to the measurement. }
procedure TMainForm.EditDimUnder(X, Y: Integer);
var
  I: Integer;
  Was, Now_: string;
begin
  if FMode <> mdPro then Exit;
  I := FD.Doc.HitTest(Proj, X, Y, 10 * FUIScale);
  if (I < 0) or (FD.Doc[I].Kind <> ekDim) then Exit;
  { Into the command bar rather than a dialog.  Everything else in PRO is
    typed there and committed with Enter, and a modal box stops the drawing
    being looked at while the label is being written - which is the one
    moment you want to see it. }
  FDimEdit := I;
  FInput := FD.Doc[I].Txt;
  FCmdMsg := 'Type what this dimension should say, then Enter.  ' +
    'Empty goes back to the measured length;  Esc leaves it alone.';
  pbCmd.Invalidate;
  pbScreen.Invalidate;
end;

{ Take what was typed and put it on the dimension.  Called from Enter. }
procedure TMainForm.CommitDimNote;
var
  I: Integer;
  Note: string;
begin
  I := FDimEdit;
  FDimEdit := -1;
  Note := Trim(FInput);
  FInput := '';
  if (I < 0) or (I >= FD.Doc.Live) or (FD.Doc[I].Kind <> ekDim) then Exit;
  if Note = Trim(FD.Doc[I].Txt) then
  begin
    FCmdMsg := 'Left as it was.';
    Exit;
  end;
  PushUndo;
  FD.Doc.SetDimNote(I, Note);
  RenderPro;
  RecomposeAll;
  Invalidate;
  if Note = '' then FCmdMsg := 'Back to the measured length.'
  else FCmdMsg := 'Dimension reads "' + Note + '".';
end;

function TMainForm.PushDistance: Double;
var
  L, Move, Len2, DirX, DirY, Flush: Double;
  Nm, Other, A, B: TP3;
  PA, PN: TPointF;
  HF: Integer;
begin
  Result := 0;
  if FPushFace < 0 then Exit;
  Nm := FD.Doc.FaceNormal(FPushFace);

  { The cursor is unprojected onto the working plane, so it can never say
    anything about Z - which is why dragging a horizontal face used to
    report a move of zero however far you pulled, and only a typed number
    did anything.  Measure the drag against the normal as it appears on
    screen instead: the normal projected from the anchor gives pixels per
    world unit, and the drag along it gives the distance. }
  PA := ScreenOf(FP1);
  PN := ScreenOf(P3(FP1.X + Nm.X, FP1.Y + Nm.Y, FP1.Z + Nm.Z));
  DirX := PN.X - PA.X;
  DirY := PN.Y - PA.Y;
  Len2 := DirX * DirX + DirY * DirY;
  if Len2 < 1E-9 then
    Move := 0                 // the normal points straight at the camera
  else
  begin
    Move := ((FMouseSX - FPushSX) * DirX + (FMouseSY - FPushSY) * DirY) / Len2;
    if SnapStep > 0 then Move := Round(Move / SnapStep) * SnapStep;
  end;

  if (FInput <> '') and ParseLen(FInput, FD.Units, L) then
  begin
    { the number says how far, the drag still says which way }
    if Move < 0 then Result := -L else Result := L;
    Exit;
  end;

  { Rest on another face that is parallel to this one and the pull goes
    exactly as far as it needs to to line the two of them up.

    This is the one that makes a row of windows possible.  Pull the first one
    out however far looks right; for the second, start the pull and then put
    the cursor on the face of the first, and it comes out to meet it.  No
    number to read off and type in, and no way to be an eighth of an inch
    out.  SketchUp infers to whatever is under the cursor; this is the part
    of that which earns its keep on a fabrication drawing, where things being
    flush matters and being nearly flush is a fault. }
  HF := FD.Doc.HitFace(Proj, FMouseSX, FMouseSY);
  if (HF >= 0) and (HF <> FPushFace) and (Length(FD.Doc[HF].Poly) > 0) and
     (Length(FD.Doc[FPushFace].Poly) > 0) then
  begin
    Other := FD.Doc.FaceNormal(HF);
    if Abs(Nm.X * Other.X + Nm.Y * Other.Y + Nm.Z * Other.Z) > 0.9995 then
    begin
      A := FD.Doc[FPushFace].Poly[0];
      B := FD.Doc[HF].Poly[0];
      Flush := (B.X - A.X) * Nm.X + (B.Y - A.Y) * Nm.Y + (B.Z - A.Z) * Nm.Z;
      { Either way along the normal.  Requiring it to agree with the way the
        drag was already going sounds tidy and is wrong: half the time you
        come at the face you are aiming for from the other side, and SketchUp
        lets you.  What is still refused is a face already in the same plane
        as the one being pushed - the distance there is nothing, and snapping
        a pull shut because the cursor wandered over the floor is not help. }
      if Abs(Flush) > 1E-6 then
      begin
        FPushFlush := True;
        Exit(Flush);
      end;
    end;
  end;
  FPushFlush := False;
  Result := Move;
end;

{ Push/pull was blind: click a face, type a number, hope it went the way
  you meant.  Now the face is drawn where it would land, joined to where it
  is now by the walls that would be built, so the direction is settled
  before you commit to it.  The walls run along the face normal, so they
  take that axis's color when the normal is one. }
procedure TMainForm.PaintPushPreview(C: TCanvas);
var
  E: TWorkEnt;
  I, N, Ax: Integer;
  R: Double;
  Nm, Q: TP3;
  PA, PB: TPointF;
  Col: TPix;
begin
  if FPushFace < 0 then Exit;
  E := FD.Doc[FPushFace];
  N := Length(E.Poly);
  if N < 3 then Exit;

  R := PushDistance;
  if Abs(R) < 1E-9 then Exit;

  Nm := FD.Doc.FaceNormal(FPushFace);
  Ax := -1;
  if Abs(Nm.X) > 0.9 then Ax := 0
  else if Abs(Nm.Y) > 0.9 then Ax := 1
  else if Abs(Nm.Z) > 0.9 then Ax := 2;
  if Ax >= 0 then Col := AxisPix(Ax) else Col := Theme.Accent;

  { the walls that would be built }
  C.Pen.Style := psDot;
  C.Pen.Width := 1;
  C.Pen.Color := PixToColor(Col);
  for I := 0 to N - 1 do
  begin
    PA := ScreenOf(E.Poly[I]);
    PB := ScreenOf(P3(E.Poly[I].X + Nm.X * R, E.Poly[I].Y + Nm.Y * R,
                      E.Poly[I].Z + Nm.Z * R));
    C.MoveTo(Round(PA.X), Round(PA.Y));
    C.LineTo(Round(PB.X), Round(PB.Y));
  end;

  { the face where it would land }
  C.Pen.Style := psSolid;
  C.Pen.Width := Max(2, Round(2 * FUIScale));
  Q := P3(E.Poly[N - 1].X + Nm.X * R, E.Poly[N - 1].Y + Nm.Y * R,
          E.Poly[N - 1].Z + Nm.Z * R);
  PA := ScreenOf(Q);
  C.MoveTo(Round(PA.X), Round(PA.Y));
  for I := 0 to N - 1 do
  begin
    Q := P3(E.Poly[I].X + Nm.X * R, E.Poly[I].Y + Nm.Y * R,
            E.Poly[I].Z + Nm.Z * R);
    PB := ScreenOf(Q);
    C.LineTo(Round(PB.X), Round(PB.Y));
  end;
  C.Pen.Width := 1;
end;

{ The model axes: X red, Y green, Z blue, solid the way the numbers grow and
  dashed the way they shrink.

  The dashes are the half of this that carries information.  A solid line and
  a fainter line of the same color say "one of these is more important"; a
  solid line and a dashed one say which way is positive, and that is a thing
  you need to know before you draw rather than after you have measured
  something and found it negative.  It is what SketchUp does and it is worth
  copying exactly.

  Drawn in every PRO view now.  They used to appear only in 3D, so the two
  views where you do most of the drawing had no color telling you which way
  was which - and PLAN in particular is where you first put something down. }
procedure TMainForm.PaintAxes;
var
  K, N: Integer;
  L, Len: Double;
  B: TP3;
  PO, PB, D: TPointF;
  Col: TPix;
begin
  L := (FPaper.Width + FPaper.Height) / Max(1E-9, Ppu);
  PO := ScreenOf(P3(0, 0, 0));
  if IsNan(PO.X) or IsNan(PO.Y) or IsInfinite(PO.X) or IsInfinite(PO.Y) then
    Exit;
  for K := 0 to 2 do
  begin
    Col := AxisPix(K);

    B := P3(0, 0, 0);
    case K of
      0: B.X := L;
      1: B.Y := L;
    else B.Z := L;
    end;
    PB := ScreenOf(B);
    Len := Sqrt(Sqr(PB.X - PO.X) + Sqr(PB.Y - PO.Y));
    { An axis pointing straight at the camera has no length on the glass -
      PLAN looks down Z - and drawing it puts a dot of color on the origin
      that means nothing.  Left out instead. }
    if Len < 1 then Continue;
    FPaper.Line(PO.X, PO.Y, PB.X, PB.Y, 1.8, Col, 0.55);

    { the negative half, dashed away from the origin }
    D := PtF((PO.X - PB.X) / Len, (PO.Y - PB.Y) / Len);
    N := 0;
    while N * 11 < Len do
    begin
      FPaper.Line(PO.X + D.X * (N * 11), PO.Y + D.Y * (N * 11),
                  PO.X + D.X * (N * 11 + 6), PO.Y + D.Y * (N * 11 + 6),
                  1.4, Col, 0.42);
      Inc(N);
    end;
  end;
  FPaper.Touch;
end;

procedure TMainForm.RepaintPaper;
var
  GridPitch: Double;
begin
  if FMode = mdPro then
  begin
    PaintScreenPaper(FPaper, Theme, False);
    if FShowGrid then
    begin
      { The lattice only reads as paper if the spacing stays in a comfortable
        band, so the pitch steps through the same round numbers the scale bar
        picks from - an inch, three, six, a foot, five feet - rather than
        being stuck at one world unit however far you have zoomed.  At a
        working zoom that lands on a foot, which is what isometric paper is
        ruled at, and it is always a number you would snap to. }
      GridPitch := NiceBarLength(Ppu, 14 * FUIScale, 60 * FUIScale, FD.Units);
      { Never rule the paper finer than you can land on it.  The pitch is
        picked by zoom, the snap by the SNAP box, and when the snap was the
        coarser of the two half the crossings were places the cursor could
        not reach - which is worse than no grid, because you aim at them.
        Every snap on the list divides a foot exactly, so any pitch at or
        above the snap step keeps the crossings snappable. }
      if GridPitch < SnapStep then GridPitch := SnapStep;
      GridPitch := GridPitch * Ppu;
      case FD.View of
        vkIso: PaintIsoGrid(FPaper, Theme, GridPitch, FD.ViewX, FD.ViewY, 5);
        vkPlan: PaintMeasuredGrid(FPaper, Theme, GridPitch, FD.ViewX, FD.ViewY, 5);
        vkOrbit: ;   // handled below - the axes show whether the grid is on
      end;
    end;
    PaintAxes;
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
  { A fault while drawing used to take the program down, and since the
    drawing is drawn again every frame it took it down again the moment it
    came back - which is a program that cannot be started, not a program with
    a bug in it.  Now the picture stops and says so, and everything else
    still works: the drawing can be saved, undone, or picked apart to find
    what is wrong with it. }
  if FRenderBroken then Exit;
  try
    if FD.Doc.Live > 0 then
      FD.Doc.Render(FInkPro, Proj, FD.Units, FDimFont, AnnotColor, FEdgeW);
  except
    on E: Exception do
    begin
      FRenderBroken := True;
      FCmdMsg := 'Something in this drawing will not draw (' + E.ClassName +
        ').  Ctrl+Z, or save it and send it in - nothing is lost.';
      FHint := 'Drawing stopped - the document is still here and still saves.';
    end;
  end;
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
  { The whole title strip, whichever mode is up.  This used to be a fixed
    38..84, which is where TOY's tall header keeps its readout - PRO's is 34
    pixels high altogether, so the rectangle sat entirely below the numbers
    it was meant to refresh and they simply stopped moving. }
  R := Rect(ClientWidth div 3, 0, ClientWidth, TitleHeight + Round(2 * FUIScale));
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

{ Re-center the coordinate readout on the picked point without moving
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
  BaseP, W, H, Z, NewZoom: Double;
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
    { Through a local and clamped by hand, for the same reason FD.El is - see
      the note in ServiceMotion.  This is the other Double field on FD
      assigned straight out of EnsureRange, which is the shape that got
      miscompiled at -O3.  This one reads correctly in the build in front of
      me; it is written this way so that stays true. }
    NewZoom := Z;
    if NewZoom < 0.05 then NewZoom := 0.05;
    if NewZoom > 40.0 then NewZoom := 40.0;
    FD.Zoom := NewZoom;
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
  Y0, RowY, X, Avail, SegW, SwSz, SwGap, I, N, G, GX, GrpGap: Integer;
  HalfW, SnapX, RightW6, GrpX, NSet: Integer;
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

  { PRO has two rows for what used to take three, so the icons go six across
    rather than three - dropping a row of them is how the theme and the grid
    went missing. }
  procedure AddIconRow6(RY: Integer; const A: array of Integer;
    const K: array of TIconKind; const H: array of string);
  var
    IX, J: Integer;
  begin
    IX := W - Pad - RightW6;
    for J := 0 to High(A) do
    begin
      Add(dkIcon, Rect(IX, RY, IX + IconW, RY + RowH), GRP_ICON, A[J], '',
        H[J], K[J]);
      Inc(IX, IconW + IconGap);
    end;
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
  RowH := DeckRowH;
  if FMode = mdPro then RowGap := Round(4 * FUIScale)
  else RowGap := Round(8 * FUIScale);
  IconW := Round(34 * FUIScale);
  IconGap := Round(6 * FUIScale);
  RightW := 3 * IconW + 2 * IconGap;
  RightW6 := 6 * IconW + 5 * IconGap;

  Y0 := (H - (DeckRows * RowH + (DeckRows - 1) * RowGap)) div 2;
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
        Format('Kaleidoscope: repeat every stroke %d times around the center.',
          [SYM_VALUES[I]]), ikDroplet);
    Add(dkIcon, Rect(X + 5 * SegW + RowGap, RowY, X + 5 * SegW + RowGap + IconW,
      RowY + RowH), GRP_ICON, ACT_MIRROR, '', 'Mirror left to right  (M)', ikMirror);
    AddIconRow(RowY, ACT_SAVE, ACT_PRINT, ACT_AUTO, ikSave, ikPrint, ikMagic,
      'Save as a PNG  (Ctrl+S)', 'Print  (Ctrl+P)',
      'Auto-draw: let the machine doodle  (A)');
  end
  else
  begin
    { --- rows 1 and 2: the tools, in three groups ------------------------
      Six across instead of twelve, so the names fit, with a gap between the
      groups wide enough to read as a break rather than as spacing. }
    Avail := W - 2 * Pad - LabW - RightW6 - RowGap;
    GrpGap := Round(20 * FUIScale);
    { seven columns across the three groups now, not six }
    SegW := (Avail - 2 * GrpGap) div 7;
    FGrpDivY0 := Y0 + Round(2 * FUIScale);
    FGrpDivY1 := Y0 + 2 * RowH + RowGap - Round(2 * FUIScale);
    GrpX := X;
    for G := 0 to 2 do
    begin
      for I := 0 to GRP_N[G] - 1 do
      begin
        GX := GrpX + (I mod GRP_COLS[G]) * SegW;
        RowY := Y0 + (I div GRP_COLS[G]) * (RowH + RowGap);
        Add(dkSegment, Rect(GX + 2, RowY, GX + SegW - 2, RowY + RowH),
          GRP_TOOL, Ord(TOOL_GROUPS[G, I]),
          TOOL_NAMES[TOOL_GROUPS[G, I]], TOOL_HINTS[TOOL_GROUPS[G, I]],
          TOOL_ICONS[TOOL_GROUPS[G, I]]);
      end;
      Inc(GrpX, GRP_COLS[G] * SegW + GrpGap);
      if G < 2 then FGrpDivX[G] := GrpX - GrpGap div 2;
    end;

    { --- row 2: the settings, as buttons that open a list -----------------
      Scale, snap and the pen get set once and then left alone, so a row of
      choices each was drawing area spent on things nobody touches.  Each is
      one button showing what it is set to, and the list opens above it -
      which also means a list can be longer than a row ever was. }
    RowY := Y0 + 2 * (RowH + RowGap);
    Avail := W - 2 * Pad - LabW - RightW6 - RowGap;
    { Two more slots when the drawing has guides in it, and the row divides
      by seven instead of five.  A button for something that does not exist is
      one more thing to read past every time you look at the screen, so they
      are not there until the tape leaves the first guide and are gone again
      when the last one is cleared. }
    if (FMode = mdPro) and (FD.Doc.GuideCount > 0) then NSet := 8 else NSet := 6;
    SegW := (Avail - (NSet - 1) * RowGap) div NSet;
    if NSet = 8 then
    begin
      Add(dkSegment, Rect(X + 6 * SegW, RowY, X + 7 * SegW - RowGap,
        RowY + RowH), GRP_ICON, ACT_GUIDES,
        IfThen(FD.Doc.GuidesHidden,
          Format('SHOW %d', [FD.Doc.GuideCount]),
          Format('HIDE %d', [FD.Doc.GuideCount])),
        'Put the guides away, or bring them back.  They stay in the drawing '
        + 'either way.', ikDroplet);
      Add(dkSegment, Rect(X + 7 * SegW, RowY, X + 8 * SegW - RowGap,
        RowY + RowH), GRP_ICON, ACT_NOGUIDE, 'CLEAR GUIDES',
        'Throw all the guides away.  Undo brings them back.', ikDroplet);
    end;
    Add(dkSegment, Rect(X + 4 * SegW, RowY, X + 5 * SegW - RowGap,
      RowY + RowH), GRP_POPUP, POP_PREC,
      IfThen(FLenDenom = 100, 'PREC  .01"', Format('PREC  1/%d"', [FLenDenom])),
      'How finely a length is written down, and what the last field of a ' +
      'dashed entry counts in - 6-8-15 is feet, inches and sixteenths.  ' +
      'It never changes what the drawing holds.', ikDroplet);
    Add(dkSegment, Rect(X + 5 * SegW, RowY, X + 6 * SegW - RowGap,
      RowY + RowH), GRP_POPUP, POP_SHOP, 'SHOP',
      'Shop tools - laying a piece out flat, and the fittings', ikDroplet);
    Add(dkSegment, Rect(X, RowY, X + SegW - RowGap, RowY + RowH),
      GRP_POPUP, POP_SCALE, 'SCALE  ' + ScaleTable(FD.Units, FD.ScaleIdx).Name,
      'Print scale - click for the list', ikDroplet);
    Add(dkSegment, Rect(X + SegW, RowY, X + 2 * SegW - RowGap, RowY + RowH),
      GRP_POPUP, POP_SNAP, 'SNAP  ' + SnapName(FD.Units, FD.SnapIdx),
      'What the cursor snaps to - click for the list', ikDroplet);
    Add(dkSegment, Rect(X + 2 * SegW, RowY, X + 3 * SegW - RowGap, RowY + RowH),
      GRP_POPUP, POP_COLOR, 'COLOR',
      'Line color - click for the list', ikDroplet);
    Add(dkSegment, Rect(X + 3 * SegW, RowY, X + 4 * SegW - RowGap, RowY + RowH),
      GRP_POPUP, POP_WIDTH, Format('LINES  %d px', [FEdgeW]),
      'How thick every edge in this drawing is drawn.  It is one setting for ' +
      'the whole sheet, the way SketchUp does it - not a property of the ' +
      'line you happen to be drawing.', ikDroplet);

    AddIconRow6(Y0,
      [ACT_UNDO, ACT_REDO, ACT_FIT, ACT_THEME, ACT_GRID, ACT_HELP],
      [ikUndo, ikRedo, ikFit, ikTheme, ikGrid, ikHelp],
      ['Undo  (Ctrl+Z)', 'Redo  (Ctrl+Y)', 'Frame the whole drawing  (F)',
       'Change the theme  (T)', 'Show or hide the measured grid  (G)',
       'Help, downloads and updates  (F1 for about)']);
    AddIconRow6(Y0 + RowH + RowGap,
      [ACT_OPEN, ACT_SAVE, ACT_EXPORT, ACT_UNITS, ACT_PRINT, ACT_ORIGIN],
      [ikOpen, ikSave, ikExport, ikUnits, ikPrint, ikOrigin],
      ['Open a drawing  (Ctrl+O)', 'Save this drawing  (Ctrl+S)',
       'Export a picture - PNG or SVG  (Ctrl+E)',
       'Feet-and-inches or metric  (U)',
       'Print  (Ctrl+P)',
       'Move the origin here  (/origin)']);
    Exit;
  end;

  { --- ink row ---------------------------------------------------------- }
  RowY := Y0 + 2 * (RowH + RowGap);

  SwGap := Round(6 * FUIScale);
  SwSz := Min(RowH - Round(6 * FUIScale),
    (Avail div 2 - 11 * SwGap) div 12);
  SwSz := Max(9, SwSz);
  for I := 0 to High(PALETTE) do
  begin
    Add(dkSwatch, Rect(X + I * (SwSz + SwGap), RowY + (RowH - SwSz) div 2,
      X + I * (SwSz + SwGap) + SwSz, RowY + (RowH - SwSz) div 2 + SwSz),
      GRP_INK, I, '', 'Ink color', ikDroplet);
    FDeck[High(FDeck)].Swatch := ColorToPix(PALETTE[I]);
  end;
  Add(dkIcon, Rect(X + 12 * (SwSz + SwGap) + RowGap, RowY,
    X + 12 * (SwSz + SwGap) + RowGap + IconW, RowY + RowH),
    GRP_ICON, ACT_PICK, '', 'Pick any color you like...', ikDroplet);

  { size slider shares the ink row when there is space, otherwise its own }
  I := X + 12 * (SwSz + SwGap) + RowGap + IconW + Round(20 * FUIScale);
  if FMode = mdPro then
  begin
    Add(dkSlider, Rect(I, RowY + RowH div 2 - Round(9 * FUIScale),
      Max(I + 60, X + Avail - Round(56 * FUIScale)),
      RowY + RowH div 2 + Round(9 * FUIScale)), GRP_SIZE, 0, '',
      'Line weight  ( [ and ] )', ikDroplet);
    AddIconRow(RowY, ACT_PRINT, ACT_ORIGIN, ACT_FIT, ikPrint, ikOrigin, ikFit,
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
      'Help, downloads and updates  (F1 for about)');
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

  { a hairline down each gap, so the three groups of tools read as three
    groups rather than as six buttons that happen to be spaced oddly }
  if (FMode = mdPro) and (FGrpDivY1 > FGrpDivY0) then
    for I := 0 to 1 do
      FDeckSkin.Line(FGrpDivX[I], FGrpDivY0, FGrpDivX[I], FGrpDivY1,
        Max(1.0, FUIScale), MixPix(Theme.Panel, Theme.TextDim, 0.9), 0.9);

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
          if (It.Group = GRP_TOOL) and (FMode = mdPro) then
          begin
            if Sel then Fg := Pix(22, 22, 26) else Fg := Theme.Text;
            IR := Rect(R.Left + Round(5 * FUIScale),
              R.Top + Round(3 * FUIScale),
              R.Left + Round(5 * FUIScale) + (R.Bottom - R.Top) - Round(6 * FUIScale),
              R.Bottom - Round(3 * FUIScale));
            PaintIcon(FDeckSkin, It.Icon, IR, Fg, 0.95);
          end;
          { the color button wears the color, so the row reads as a
            summary of what is set rather than a row of words }
          if (It.Group = GRP_POPUP) and (It.Value = POP_COLOR) then
            PaintSwatch(FDeckSkin,
              Rect(R.Left + Round(7 * FUIScale), R.Top + Round(4 * FUIScale),
                   R.Left + Round(29 * FUIScale), R.Bottom - Round(4 * FUIScale)),
              ColorToPix(FInkColor), False, False, Theme);

          { a settings button says there is more behind it }
          if It.Group = GRP_POPUP then
          begin
            if Sel then Fg := Pix(22, 22, 26) else Fg := Theme.TextDim;
            IR := Rect(R.Right - Round(16 * FUIScale), R.Top,
              R.Right - Round(3 * FUIScale), R.Bottom);
            PaintIcon(FDeckSkin, ikChevron, IR, Fg, 0.9);
          end;
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
  RowH := DeckRowH;
  if FMode = mdPro then RowGap := Round(4 * FUIScale)
  else RowGap := Round(8 * FUIScale);
  Y0 := (FDeckSkin.Height - (DeckRows * RowH + (DeckRows - 1) * RowGap)) div 2;

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
    Section(2, 'SET');
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
    { a tool wears its own glyph, so the buttons are told apart at a glance
      and the same drawing follows the cursor }
    if (It.Group = GRP_POPUP) and (It.Value = POP_COLOR) then
      pbDeck.Canvas.TextOut(
        It.Bounds.Left + (It.Bounds.Right - It.Bounds.Left - TW +
          Round(24 * FUIScale)) div 2,
        (It.Bounds.Top + It.Bounds.Bottom - pbDeck.Canvas.TextHeight(It.Caption)) div 2,
        It.Caption)
    else if (It.Group = GRP_TOOL) and (FMode = mdPro) then
      pbDeck.Canvas.TextOut(
        It.Bounds.Left + (It.Bounds.Right - It.Bounds.Left - TW +
          Round(18 * FUIScale)) div 2,
        (It.Bounds.Top + It.Bounds.Bottom - pbDeck.Canvas.TextHeight(It.Caption)) div 2,
        It.Caption)
    else
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
    { An ordinary hover tooltip as well as the hint line.  The icons on the
      right say nothing about themselves otherwise - you have to already know
      what the little pictures mean. }
    if H >= 0 then pbDeck.Hint := FDeck[H].Hint else pbDeck.Hint := '';
    Application.CancelHint;
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
    pbDeck.Hint := '';
    Application.CancelHint;
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

{ Where a given control ended up in the deck, so a key can press it. }
function TMainForm.FindDeck(Group, Value: Integer): Integer;
begin
  for Result := 0 to High(FDeck) do
    if (FDeck[Result].Group = Group) and (FDeck[Result].Value = Value) then Exit;
  Result := -1;
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
    GRP_POPUP:
      { clicking the open one shuts it, which is what a menu button does }
      if FPopup = It.Value then ClosePopup else OpenPopup(It.Value);
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
        ACT_HELP:   if FPopup = POP_HELP then ClosePopup else OpenPopup(POP_HELP);
        ACT_MIRROR: begin FMirror := not FMirror; pbDeck.Invalidate; end;
        ACT_PICK:   DoPickColor;
        ACT_UNITS:  SetUnits(TUnitSystem(1 - Ord(FD.Units)));
        ACT_ORIGIN: SetOriginHere;
        ACT_FIT:    FitView;
        ACT_OPEN:   DoOpen;
        ACT_EXPORT: DoExport;
        ACT_GUIDES:
          begin
            FD.Doc.GuidesHidden := not FD.Doc.GuidesHidden;
            FCmdMsg := IfThen(FD.Doc.GuidesHidden,
              'Guides put away.  They are still in the drawing.',
              'Guides back.');
            RenderPro;
            RecomposeAll;
          end;
        ACT_NOGUIDE:
          begin
            PushUndo;
            FCmdMsg := Format('Cleared %d guides.', [FD.Doc.ClearGuides]);
            RenderPro;
            RecomposeAll;
          end;
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


{ Parking on a named camera rather than spinning to it by hand.  Free
  orbiting sets FViewPreset to -1, so the next press puts you back on the
  rails at the corner view instead of resuming a cycle you left long ago. }
procedure TMainForm.ApplyViewPreset(I: Integer);
var
  N: Integer;
begin
  N := Length(VIEW_PRESETS);
  FViewPreset := ((I mod N) + N) mod N;
  FD.View := VIEW_PRESETS[FViewPreset].View;
  FD.Az := VIEW_PRESETS[FViewPreset].Az;
  FD.El := VIEW_PRESETS[FViewPreset].El;
  if FD.View <> vkOrbit then FD.Plane := plXY;
  FCmdMsg := VIEW_PRESETS[FViewPreset].Name + ' view.';
  FitView;
  RebuildDeck;
  pbDeck.Invalidate;
  pbView.Invalidate;
  pbCmd.Invalidate;
end;

procedure TMainForm.CycleViewPreset(Step: Integer);
begin
  if FViewPreset < 0 then
  begin
    if FD.View = vkOrbit then ApplyViewPreset(2) else ApplyViewPreset(0);
    Exit;
  end;
  ApplyViewPreset(FViewPreset + Step);
end;

procedure TMainForm.SetView(V: TViewKind);
begin
  FViewPreset := -1;
  if V = FD.View then Exit;
  Trail('view ' + VIEW_NAMES[V]);
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
  { What SketchUp's measurements box does: while you drag, it shows the size
    you are pulling, and the moment you type anything your figure takes its
    place.  Two readings in two corners is one too many - the number belongs
    where the typing goes, because they are the same number. }
  if FInput <> '' then
  begin
    UIFont(pbCmd.Canvas, 12, True, Theme.Accent, True);
    S := FInput + Caret;
  end
  else
  begin
    S := LiveMeasure;
    if S = '' then
    begin
      UIFont(pbCmd.Canvas, 12, True, Theme.Accent, True);
      S := Caret;
    end
    else
    begin
      { dimmer than typed text, because it is a reading rather than a
        decision - it says what you would get, not what you have asked for }
      UIFont(pbCmd.Canvas, 12, False, Theme.TextDim, True);
      S := S + Caret;
    end;
  end;
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

{ How much of the drawing a rectangle would hide.

  Sampled every fourth pixel each way rather than counted.  This runs on
  every mouse move and a sixteenth of the work is plenty to tell a box lying
  over a wall from one lying on empty paper.

  The ink surface rather than the finished picture, deliberately: ink is only
  what has been drawn, so the paper's grid does not count as something worth
  avoiding.  It would score the same everywhere and drown the signal. }
function TMainForm.InkUnder(const R: TRect): Integer;
var
  X, Y, X0, X1, Y1: Integer;
  P: PPix;
  Ink: TArtSurface;
begin
  Result := 0;
  Ink := ActiveInk;
  if Ink = nil then Exit;
  X0 := Max(0, R.Left);
  X1 := Min(R.Right, Ink.Width);
  Y1 := Min(R.Bottom, Ink.Height);
  Y := Max(0, R.Top);
  while Y < Y1 do
  begin
    P := Ink.ScanLine(Y);
    X := X0;
    while X < X1 do
    begin
      if (P + X)^.A > 8 then Inc(Result);
      Inc(X, 4);
    end;
    Inc(Y, 4);
  end;
end;

{ Where to put the chip beside the cursor.

  It used to hang down and to the right always, flipping only when it would
  have gone off the edge - so on a drawing where the work is down and to the
  right, which is most of them, it sat squarely on the thing being worked on
  and hid the reading you were setting.

  Now all four corners are tried and the one covering least of the drawing
  wins.  Every candidate is pushed inside the canvas before it is judged, so
  none of them can be off screen - the clamping is not a fallback, it is what
  makes the choice fair.

  The corner it is already in has to be beaten by a clear margin to lose.
  Without that it swaps sides on a one pixel move whenever two corners are
  close, which is worse than any placement. }
function TMainForm.TipSpot(SX, SY, BoxW, BoxH: Integer): TRect;
var
  K, Gap, AX, AY, Sc, Best, BestK, Cur: Integer;
  Cand: array[0..7] of TRect;
begin
  { Four corners at arm's length, and the same four further out.

    Close is right when there is nothing in the way - the chip belongs to the
    cursor and should look like it.  But when the work is crowded every near
    corner is on top of something, and then what is wanted is distance: the
    far ring is there so it has somewhere to go rather than picking the least
    bad of four placements that are all in the way.

    Near first, and a strictly-better test, so a far corner only wins by
    actually covering less. }
  for K := 0 to 7 do
  begin
    if K < 4 then Gap := Round(16 * FUIScale)
    else Gap := Round(96 * FUIScale);
    if (K and 1) = 0 then AX := SX + Gap else AX := SX - Gap - BoxW;
    if (K and 2) = 0 then AY := SY + Gap else AY := SY - Gap - BoxH;
    AX := EnsureRange(AX, 4, Max(4, pbScreen.Width - BoxW - 4));
    AY := EnsureRange(AY, 4, Max(4, pbScreen.Height - BoxH - 4));
    Cand[K] := Rect(AX, AY, AX + BoxW, AY + BoxH);
  end;

  FTipCorner := EnsureRange(FTipCorner, 0, 7);
  Cur := InkUnder(Cand[FTipCorner]);
  Best := Cur;
  BestK := FTipCorner;
  for K := 0 to 7 do
  begin
    if K = FTipCorner then Continue;
    Sc := InkUnder(Cand[K]);
    if Sc < Best then
    begin
      Best := Sc;
      BestK := K;
    end;
  end;
  { a third less covered, and enough of a difference to be worth the jump }
  if (BestK <> FTipCorner) and (Best * 3 < Cur * 2) and (Cur - Best > 12) then
    FTipCorner := BestK;
  Result := Cand[FTipCorner];
end;

function TMainForm.SnapLabel: string;
const
  { Named by color, like everything else about the axes.  It said ON X while
    the inference beside it said ON RED AXIS, which is two names for one
    thing in the same corner of the screen. }
  AXIS_LABEL: array[0..2] of string =
    ('LOCKED TO RED', 'LOCKED TO GREEN', 'LOCKED TO BLUE');
begin
  if FAxisLock in [0..2] then Exit(AXIS_LABEL[FAxisLock]);
  case FSnapKind of
    snEndpoint: Result := 'ENDPOINT';
    snMidpoint: Result := 'MIDPOINT';
    snSubMid:   Result := 'ON SEGMENT';
    snCenter:   Result := 'CENTER';
    snCross:    Result := 'CROSSING';
    snOnEdge:   Result := 'ON EDGE';
    snOrigin:   Result := 'ORIGIN';
    snOnAxis:   case FSnapAxis of
                  0: Result := 'ON RED AXIS';
                  1: Result := 'ON GREEN AXIS';
                else Result := 'ON BLUE AXIS';
                end;
    snGrid:     Result := 'GRID';
  else
    Result := '';
  end;
end;

{ Where the far corner of the rectangle is.  Typing 12'x8' sets both sides at
  once; the cursor still decides which way each one goes, so the rectangle
  grows towards you rather than always up and to the right. }
function TMainForm.RectTarget: TP3;
var
  I: Integer;
  Txt, LW, LH: string;
  W, H, SX, SY: Double;
begin
  Result := FCur;
  if FStage <> 1 then Exit;

  Txt := LowerCase(Trim(FInput));
  I := Pos('x', Txt);
  if I = 0 then I := Pos(',', Txt);
  if I = 0 then Exit;

  { SketchUp takes a side on its own: "3'," sets the first and leaves the
    second under the cursor, ",3'" the other way about.  Either side may be
    negative, which runs it the opposite way whatever the cursor is doing. }
  LW := Trim(Copy(Txt, 1, I - 1));
  LH := Trim(Copy(Txt, I + 1, MaxInt));
  RectSides(FP1, FCur, FD.Plane, W, H);
  if (LW <> '') and not ParseLen(LW, FD.Units, W) then Exit;
  if (LH <> '') and not ParseLen(LH, FD.Units, H) then Exit;
  if (LW = '') and (LH = '') then Exit;

  { sign from wherever the cursor is now }
  case FD.Plane of
    plXZ:
      begin
        if FCur.X < FP1.X then SX := -1 else SX := 1;
        if FCur.Z < FP1.Z then SY := -1 else SY := 1;
        if W < 0 then begin SX := -SX; W := -W; end;
        if H < 0 then begin SY := -SY; H := -H; end;
        Result := P3(FP1.X + W * SX, FP1.Y, FP1.Z + H * SY);
      end;
    plYZ:
      begin
        if FCur.Y < FP1.Y then SX := -1 else SX := 1;
        if FCur.Z < FP1.Z then SY := -1 else SY := 1;
        if W < 0 then begin SX := -SX; W := -W; end;
        if H < 0 then begin SY := -SY; H := -H; end;
        Result := P3(FP1.X, FP1.Y + W * SX, FP1.Z + H * SY);
      end;
  else
    begin
      if FCur.X < FP1.X then SX := -1 else SX := 1;
      if FCur.Y < FP1.Y then SY := -1 else SY := 1;
      if W < 0 then begin SX := -SX; W := -W; end;
      if H < 0 then begin SY := -SY; H := -H; end;
      Result := P3(FP1.X + W * SX, FP1.Y + H * SY, FP1.Z);
    end;
  end;
end;

{ Where the rubber band currently ends: a typed distance wins, then a locked
  direction, then the cursor itself. }
function TMainForm.PreviewTarget: TP3;
var
  L, Len, CX, CY, CZ: Double;
  Typed: Boolean;
  D: TP3;
  Txt: string;
  K: Integer;
  AlongL: Double;
begin
  Result := FCur;
  if FStage <> 1 then Exit;

  { a point in the drawing, or an offset from where the line started }
  Txt := Trim(FInput);
  if (Length(Txt) >= 2) and (Txt[1] in ['[', '<']) then
  begin
    if ParseTriple(Txt, FD.Units, CX, CY, CZ) > 0 then
    begin
      if Txt[1] = '[' then Result := P3(CX, CY, CZ)
      else Result := P3(FP1.X + CX, FP1.Y + CY, FP1.Z + CZ);
    end;
    Exit;
  end;

  Typed := (FInput <> '') and ParseLen(FInput, FD.Units, L);

  if FDirLock >= 0 then
  begin
    D := AxisDir(FDirLock);
    if not Typed then
      { no number yet, so slide along the locked axis under the cursor.  A
        lock is on the axis, not on one direction along it, so drawing back
        the other way is allowed. }
      L := (FCur.X - FP1.X) * D.X + (FCur.Y - FP1.Y) * D.Y + (FCur.Z - FP1.Z) * D.Z;
    Result := P3(FP1.X + D.X * L, FP1.Y + D.Y * L, FP1.Z + D.Z * L);
    Exit;
  end;

  { On the paper grid, unless Alt says otherwise.

    A leg drawn at some angle that is not one of the three is not a diagonal
    on an iso sheet, it is a slip of the hand, so the lock is hard rather than
    a nudge.  Shift lets go of it for the case that is not a slip: a forty-five
    in a principal plane, or a rolling offset, both of which really are drawn
    off the grid and called out with an angle.

    Shift rather than Alt, which would have been the nicer key, because Alt
    already cycles the working plane and holding it to draw a forty-five
    would have quietly changed the plane underneath the line. }
  if (FD.View = vkIso) and (FTool = ptLine) and
     not (ssShift in FMoveShift) then
  begin
    K := IsoRunAxis(FP1, AlongL);
    if K >= 0 then
    begin
      D := AxisDir(K);
      if not Typed then L := AlongL;
      Result := P3(FP1.X + D.X * L, FP1.Y + D.Y * L, FP1.Z + D.Z * L);
      Exit;
    end;
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

{ The dimension as it will be, drawn where the cursor is putting it - the
  witness lines, the slashes and the reading, not just a rubber band between
  the two points.  It comes out of the same routine the renderer uses, so
  what you drag around is what you get. }
procedure TMainForm.PaintDimPreview(C: TCanvas);
var
  G: TDimGeom;
  Sz: TSize;
  TP: TPoint;
begin
  if not DimGeometry(Proj, FP1, FP2, DimOffset3, FD.Units, G) then Exit;
  C.Pen.Style := psSolid;
  C.Pen.Color := PixToColor(AnnotColor);
  C.Pen.Width := 1;
  C.MoveTo(Round(G.A.X), Round(G.A.Y));   C.LineTo(Round(G.W1.X), Round(G.W1.Y));
  C.MoveTo(Round(G.B.X), Round(G.B.Y));   C.LineTo(Round(G.W2.X), Round(G.W2.Y));
  C.Pen.Width := Max(1, Round(1.5 * FUIScale));
  C.MoveTo(Round(G.LA.X), Round(G.LA.Y));  C.LineTo(Round(G.LB.X), Round(G.LB.Y));
  C.MoveTo(Round(G.S1A.X), Round(G.S1A.Y)); C.LineTo(Round(G.S1B.X), Round(G.S1B.Y));
  C.MoveTo(Round(G.S2A.X), Round(G.S2A.Y)); C.LineTo(Round(G.S2B.X), Round(G.S2B.Y));
  C.Pen.Width := 1;
  C.Brush.Style := bsClear;
  UIFont(C, 9, False, AnnotColor);
  Sz := C.TextExtent(G.Txt);
  TP := DimTextTopLeft(G, Sz.cx, Sz.cy);
  C.TextOut(TP.X, TP.Y, G.Txt);
end;

{ The mark that says what the cursor found.

  This has to be painted after the cursor overlay, not before: the overlay
  copies a square of the artwork and blits it back over the canvas, so
  anything drawn here first was wiped out.  That is why only the ring ever
  showed. }
{ The places worth aiming at on the face under the cursor: its corners, the
  middle of each edge, and the middle of the face itself.

  Drawn small and pale, because they are an offer rather than a
  confirmation - the cursor marker still says what actually got snapped.
  The middle of a face is the one Tony asked for by name: a circle struck
  from the centre of a panel is most of what this program gets used for. }
{ The rubber band, leaned on until it breaks.

  A line under your hand is elastic - it follows you about, and letting go of
  it needs the keyboard.  Hold the button still and it stops being elastic:
  it stiffens into a stick, bows under the load, thins in the middle and
  cracks, and then it goes.  The gesture teaches itself, which a keyboard
  shortcut never does.

  T runs 0 to 1 from the moment the press stops looking like a click to the
  moment it breaks. }
{ A point along a bent stick: the quadratic through A, the bowed middle M,
  and B.  Straight when M is halfway, which is what makes the bow read. }
function QuadAt(const A, M, B: TPointF; T: Double): TPointF;
var
  U: Double;
begin
  U := 1 - T;
  Result.X := U * U * A.X + 2 * U * T * M.X + T * T * B.X;
  Result.Y := U * U * A.Y + 2 * U * T * M.Y + T * T * B.Y;
end;

{ Shaking the mouse to say which way you meant it.

  Tony, drawing a rectangle in the 3D view that kept standing up when he
  wanted it flat: "I was getting frustrated and did a sideways jerk back and
  forth with the mouse and I thought, hey, that should have said I want the
  left-right axis."

  He is right, and it is a good gesture precisely because it is what people
  already do when a program will not take the hint.  Shake sideways and the
  shape lies down; shake up and down and it stands up.  The plane latches, so
  the shake is an instruction rather than a suggestion, and Esc hands it back
  to following the faces.

  Four reversals of at least a dozen pixels, within about three quarters of a
  second, on one axis more than the other.  Ordinary drawing does not do that
  - a hand moving to a point goes one way. }
{ Is there a newer build?  Quiet unless there is, and at most once a day,
  because a drawing program has no business pinging a server every time
  somebody opens it - and none at all on a phone tether at a job site. }
procedure TMainForm.CheckForUpdate(Loud: Boolean);
var
  Info: TUpdateInfo;
  Err, Last: string;
  Ini: TIniFile;
  Today: string;
begin
  if not Loud then
  begin
    Ini := TIniFile.Create(ConfigFile);
    try
      { Some people rightly dislike software that talks to the internet
        without being asked.  This asks GitHub one question - what is the
        newest release - and sends nothing about the machine or the drawing,
        but the way to be trusted about that is to make it switchable and
        say so.  /update never in the command bar turns it off for good. }
      if not Ini.ReadBool('update', 'check', True) then Exit;
      Last := Ini.ReadString('update', 'checked', '');
    finally
      Ini.Free;
    end;
    { Six hours, not once a calendar day.  A day's throttle means that having
      looked once you hear nothing more until tomorrow however many builds go
      out - which is exactly what happened to Nikki's copy sitting one version
      behind and saying nothing about it. }
    if (Last <> '') and (Now - StrToFloatDef(Last, 0) < 0.25) then Exit;
  end;

  if not FetchLatest(Info, Err) then
  begin
    if Loud then FCmdMsg := 'Could not check for an update - ' + Err;
    Exit;
  end;

  Ini := TIniFile.Create(ConfigFile);
  try
    Ini.WriteString('update', 'checked', FloatToStr(Now));
    Ini.WriteString('update', 'latest', Info.Tag);
  finally
    Ini.Free;
  end;

  if NewerThan(Info.Tag, CurrentVersion) then
  begin
    FUpdateTag := Info.Tag;
    FCmdMsg := Info.Tag + ' is out - you have ' + CurrentVersion +
      '.  Type /update, or use the help button.';
    Invalidate;
  end
  else
  begin
    FUpdateTag := '';
    if Loud then FCmdMsg := 'Up to date - ' + CurrentVersion + '.';
  end;
  pbCmd.Invalidate;
end;

{ Fetch it, check it is what the release says it is, put it in place and
  start again.  Everything the drawing has is already in the draft, so the
  restart brings it straight back. }
procedure TMainForm.DoUpdate;
var
  Info: TUpdateInfo;
  Err, Why, Tmp, Want, Got: string;
begin
  Why := WhyNotUpdate;
  if Why <> '' then
  begin
    MessageDlg('Cannot update here', Why + '.' + #13#10#13#10 +
      'Download it yourself from the Releases page instead.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  FCmdMsg := 'Looking...';
  pbCmd.Invalidate;
  Application.ProcessMessages;
  if not FetchLatest(Info, Err) then
  begin
    FCmdMsg := 'Could not check for an update - ' + Err;
    Exit;
  end;
  if not NewerThan(Info.Tag, CurrentVersion) then
  begin
    FCmdMsg := 'Already up to date - ' + CurrentVersion + '.';
    Exit;
  end;
  if MessageDlg('Update available',
       Format('%s is out, and this is %s.'#13#10#13#10 +
         'It will be fetched, put in place, and the program restarted.  ' +
         'Your drawing is kept and comes straight back.',
         [Info.Tag, CurrentVersion]),
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
  begin
    FCmdMsg := 'Left alone.';
    Exit;
  end;

  SaveDraft;                          { whatever happens next, this survives }
  FCmdMsg := 'Fetching ' + Info.Tag + '...';
  pbCmd.Invalidate;
  Application.ProcessMessages;

  { beside the program, not in the system temp - a portable copy keeps its
    scratch with it, and the download has to land on the same volume as the
    file it is about to replace or the rename cannot be atomic }
  Tmp := AppDataDir + 'heckers-sketch-' + Info.Tag + '.download';
  if not Download(Info.AssetURL, Tmp, Err) then
  begin
    FCmdMsg := 'The download failed - ' + Err;
    Exit;
  end;

  { If the release published hashes, the download has to match one.  It does
    not protect against a bad release, only against a bad download - but a
    half-fetched binary put in place of a working one is exactly the failure
    worth ruling out. }
  Want := ExpectedSum(Info.SumsURL, ASSET_NAME);
  if Want <> '' then
  begin
    Got := Sha256Of(Tmp);
    if Got <> Want then
    begin
      DeleteFile(Tmp);
      FCmdMsg := 'That download did not match its checksum - nothing changed.';
      MessageDlg('Update stopped',
        'What came down does not match what the release says it should be, ' +
        'so it has been thrown away and nothing was changed.',
        mtWarning, [mbOK], 0);
      Exit;
    end;
  end;

  if not SwapInAndRestart(Tmp, Err) then
  begin
    DeleteFile(Tmp);
    FCmdMsg := 'Could not install it - ' + Err;
    Exit;
  end;
  Close;
end;

{ A crash last time leaves a note behind.  Offer to send it, and open it
  filled in so it can be read first - it carries file paths, and nobody
  should have those leave their machine without seeing them go. }
{ Tell us what went wrong, in your own words.

  Built here rather than as a designed form because it is one box and three
  buttons, and because the state it sends has to be gathered at the moment
  the person presses the button rather than whenever a form was made.

  The drawing is offered, not assumed.  It is the single most useful thing
  for finding a fault - it is what found the last one - but it is also
  somebody's work, possibly with a customer's name on it, and it does not
  leave the machine without being asked for. }
{ --- the picture that goes with a report --------------------------------

  It used to be the drawing surface on its own, taken the moment the person
  finished typing their description.  That is the wrong picture twice over.
  It leaves out the tool row, the settings and the command bar, which is
  where a good deal of what goes wrong actually shows - "the eraser was
  selected and the snap was off" is in the window, not in the drawing.  And
  it is taken at the one moment the fault is guaranteed not to be on screen,
  because they had to stop and open a form to describe it.

  So the whole window, and not until they say the screen looks the way it did
  when it went wrong.  The countdown is what gives them their hands back:
  ten seconds is enough to pick a tool, open a menu, and get the thing back
  in front of them.  The flash is what a camera does, and it is there for the
  same reason - so there is no doubt afterwards about which moment was
  taken. }

{ The window as it stands.  The caller owns what comes back.

  Handed over as a bitmap rather than as PNG bytes because the next thing
  that happens to it is being shown to somebody, and a picture that has been
  encoded has to be decoded again to be looked at.  Going through PNG in
  between is how the first version of this managed to hand a PNG to
  TBitmap.LoadFromStream, which reads BMP, and take the program down inside
  the bug reporter. }
function TMainForm.WindowShot(out B: TBitmap): Boolean;
begin
  B := GetFormImage;
  Result := (B <> nil) and (B.Width >= 8) and (B.Height >= 8);
  if not Result then
  begin
    B.Free;
    B := nil;
  end;
end;

{ Ten down to one, with the program still usable throughout.

  Deliberately not a dialog.  The whole point is that they can work the
  program while it runs - pick the tool, open the menu, put the drawing back
  the way it was - and a modal box would be the one thing that stopped them.
  So the wait is spent pumping messages rather than blocking, and the number
  is painted on the canvas by the ordinary paint path. }
procedure TMainForm.ShotCountdown(Seconds: Integer);
var
  Until_: QWord;
begin
  FShotCount := Seconds;
  while FShotCount > 0 do
  begin
    FCmdMsg := Format(
      'Set the screen up the way it went wrong - picture in %d.', [FShotCount]);
    FScreenDirty := True;
    pbScreen.Invalidate;
    pbCmd.Invalidate;
    Until_ := GetTickCount64 + 1000;
    while GetTickCount64 < Until_ do
    begin
      Application.ProcessMessages;
      if Application.Terminated then
      begin
        FShotCount := 0;
        Exit;
      end;
      Sleep(15);
    end;
    Dec(FShotCount);
  end;
end;

{ The countdown number, and the flash. }
procedure TMainForm.PaintShotOverlay(C: TCanvas);
var
  R: TRect;
  S: string;
  Sz: TSize;
  Pad: Integer;
begin
  if FShotFlash then
  begin
    C.Brush.Style := bsSolid;
    C.Brush.Color := clWhite;
    C.FillRect(0, 0, pbScreen.Width, pbScreen.Height);
    Exit;
  end;
  if FShotCount <= 0 then Exit;

  Pad := Round(14 * FUIScale);
  C.Font.Name := 'Sans';
  C.Font.Size := Round(30 * FUIScale);
  C.Font.Style := [fsBold];
  S := IntToStr(FShotCount);
  Sz := C.TextExtent(S);

  R := Rect(pbScreen.Width - Sz.cx - Pad * 3, Pad,
            pbScreen.Width - Pad, Pad * 2 + Sz.cy);
  C.Brush.Style := bsSolid;
  C.Brush.Color := $001A1A1A;
  C.Pen.Color := $0060C0FF;
  C.Pen.Width := Max(1, Round(2 * FUIScale));
  C.RoundRect(R.Left, R.Top, R.Right, R.Bottom, Pad, Pad);

  C.Brush.Style := bsClear;
  C.Font.Color := $00FFFFFF;
  C.TextOut(R.Left + (R.Right - R.Left - Sz.cx) div 2,
            R.Top + (R.Bottom - R.Top - Sz.cy) div 2, S);

  C.Font.Size := Round(9 * FUIScale);
  C.Font.Style := [];
  C.Font.Color := $00D0D0D0;
  S := 'set the screen up - picture in';
  Sz := C.TextExtent(S);
  C.Brush.Style := bsSolid;
  C.Brush.Color := $001A1A1A;
  C.TextOut(R.Left - Sz.cx - Pad, R.Top + (R.Bottom - R.Top - Sz.cy) div 2, S);
end;

{ Ask, count down, take it, show them, and take it again for as long as they
  want it taken again.  True when there is a picture in St to send. }
function TMainForm.TakeReportShot(St: TStream; Wait: Boolean): Boolean;
var
  B: TBitmap;
  Png: TPortableNetworkGraphic;
  V: TShotVerdict;
  WasMsg: string;
begin
  Result := False;
  if FShotBusy then Exit;
  FShotBusy := True;
  WasMsg := FCmdMsg;
  try
    repeat
      Application.ProcessMessages;
      if Wait then
      begin
        FCmdMsg := 'Setting up the picture - it is taken when this reaches zero.';
        ShotCountdown(10);
        if Application.Terminated then Exit;
      end;

      { Nothing about the taking of the picture may be in the picture.  The
        number goes, and so does the line in the command bar that was
        counting it down - that bar is one of the most useful things in the
        shot and it should say what it would have said. }
      FShotCount := 0;
      FShotFlash := False;
      FCmdMsg := WasMsg;
      FScreenDirty := True;
      pbScreen.Invalidate;
      pbCmd.Invalidate;
      Application.ProcessMessages;

      St.Size := 0;
      if not WindowShot(B) then
      begin
        FCmdMsg := 'The picture could not be taken - sending without one.';
        Exit;
      end;

      { and the flash after it, not before }
      FShotFlash := True;
      pbScreen.Invalidate;
      Application.ProcessMessages;
      Sleep(110);
      FShotFlash := False;
      FScreenDirty := True;
      pbScreen.Invalidate;
      Application.ProcessMessages;

      try
        V := ConfirmShot(B);
        { encoded only once it is wanted - the picture nobody keeps costs
          nothing }
        if V = svUse then
        begin
          Png := TPortableNetworkGraphic.Create;
          try
            Png.Assign(B);
            Png.SaveToStream(St);
          finally
            Png.Free;
          end;
        end;
      finally
        FreeAndNil(B);
      end;

      { They have seen it and want it done again.  Second time round they get
        the countdown whether or not they took it the first time - asking for
        another go almost always means the first one caught the wrong moment. }
      if V = svRetry then Wait := True;
    until V <> svRetry;

    Result := (V = svUse) and (St.Size > 0);
    if not Result then St.Size := 0;
  finally
    FShotBusy := False;
    FShotCount := 0;
    FShotFlash := False;
    FCmdMsg := WasMsg;
    FScreenDirty := True;
    pbScreen.Invalidate;
    pbCmd.Invalidate;
  end;
end;

function TMainForm.ReportBug(const Preamble, ShotFile, DocFile: string): Boolean;
var
  Dlg: TForm;
  Memo: TMemo;
  Lbl, Fine: TLabel;
  WithDoc: TCheckBox;
  BtnOK, BtnNo: TButton;
  Body, Name_, Err, Note, ShotErr: string;
  WantShot: Boolean;
  ShotWay, NThings: Integer;
  Shot: TMemoryStream;
  L: TStringList;
begin
  Result := False;
  Dlg := TForm.CreateNew(nil);
  try
    Dlg.Caption := 'Report a problem';
    Dlg.Position := poMainFormCenter;
    Dlg.BorderStyle := bsDialog;
    Dlg.ClientWidth := Round(600 * FUIScale);
    Dlg.ClientHeight := Round(384 * FUIScale);

    Lbl := TLabel.Create(Dlg);
    Lbl.Parent := Dlg;
    { Wrapped, and given the room to wrap into.  It was running off the
      right-hand side, which is what happens to a fixed height with a
      variable amount of text in it. }
    Lbl.SetBounds(Round(12 * FUIScale), Round(10 * FUIScale),
      Dlg.ClientWidth - Round(24 * FUIScale), Round(62 * FUIScale));
    Lbl.WordWrap := True;
    Lbl.AutoSize := False;
    if Preamble <> '' then
      Lbl.Caption := 'It crashed last time.  What were you doing when it ' +
        'went?  A line or two is plenty - the crash report itself is ' +
        'attached automatically, along with what the program was doing.'
    else
      Lbl.Caption := 'What were you doing, and what happened?  A line or ' +
        'two is plenty.  What the program was doing is added automatically ' +
        '- the tool, the view, and the last few dozen things that happened.';

    Memo := TMemo.Create(Dlg);
    Memo.Parent := Dlg;
    Memo.SetBounds(Round(12 * FUIScale), Round(78 * FUIScale),
      Dlg.ClientWidth - Round(24 * FUIScale), Round(180 * FUIScale));
    Memo.ScrollBars := ssAutoVertical;
    Memo.WordWrap := True;

    { The drawing file stays off, and the picture is not asked about here at
      all - it is asked about after this closes, so the question is about a
      picture that has actually been taken and so that the form is not in
      front of the thing being photographed. }
    WithDoc := TCheckBox.Create(Dlg);
    WithDoc.Parent := Dlg;
    { A check box will not wrap, so its words have to fit on one line and the
      rest of the thought goes underneath it. }
    WithDoc.SetBounds(Round(12 * FUIScale), Round(268 * FUIScale),
      Dlg.ClientWidth - Round(24 * FUIScale), Round(22 * FUIScale));
    { The count is of the drawing that will actually go, which for a crash is
      the one saved when it happened rather than whatever is on screen now -
      the two are rarely the same, since the program has restarted in
      between, and quoting the wrong one is how you end up sending an empty
      sheet believing you sent your work. }
    { What the number counts, said in the label.

      It read "(0 things)" next to the word "file", which invites reading it
      as a count of files - nought files, or nought of something else, and no
      way to tell which from the box.  The number is there to say how much of
      somebody's work they are about to send, so it says that.

      And with nothing drawn there is nothing to decide: the box goes off and
      greys out rather than offering to send an empty sheet. }
    NThings := DocThings(DocFile);
    if NThings = 0 then
      WithDoc.Caption := 'Send the drawing too - nothing drawn yet'
    else
      WithDoc.Caption := Format('Send the drawing too - %d %s drawn so far',
        [NThings, specialize IfThen<string>(NThings = 1, 'thing', 'things')]);

    { On by default.  Tony's, and he is right: it is the single most useful
      thing in a report and it was going unticked simply because it was
      unticked.  It stays a tick box, and it stays easy to see, because it is
      somebody's work and they get to say. }
    WithDoc.Checked := NThings > 0;
    WithDoc.Enabled := NThings > 0;

    Fine := TLabel.Create(Dlg);
    Fine.Parent := Dlg;
    Fine.SetBounds(Round(30 * FUIScale), Round(290 * FUIScale),
      Dlg.ClientWidth - Round(42 * FUIScale), Round(40 * FUIScale));
    Fine.WordWrap := True;
    Fine.AutoSize := False;
    { It said "off unless you say otherwise" while sitting ticked, which is
      the box contradicting the sentence under it. }
    if NThings = 0 then
      Fine.Caption := ''
    else
      Fine.Caption := 'The surest way to find a fault.  Untick it if you ' +
        'would rather not send your work.';

    BtnOK := TButton.Create(Dlg);
    BtnOK.Parent := Dlg;
    BtnOK.Caption := 'Send';
    BtnOK.ModalResult := mrOK;
    BtnOK.Default := True;
    BtnOK.SetBounds(Dlg.ClientWidth - Round(224 * FUIScale),
      Round(342 * FUIScale), Round(100 * FUIScale), Round(30 * FUIScale));

    BtnNo := TButton.Create(Dlg);
    BtnNo.Parent := Dlg;
    BtnNo.Caption := 'Cancel';
    BtnNo.ModalResult := mrCancel;
    BtnNo.Cancel := True;
    BtnNo.SetBounds(Dlg.ClientWidth - Round(112 * FUIScale),
      Round(342 * FUIScale), Round(100 * FUIScale), Round(30 * FUIScale));

    if Dlg.ShowModal <> mrOK then
    begin
      FCmdMsg := 'Report cancelled.';
      Exit;
    end;
    Note := Trim(Memo.Text);
    Body := 'Heckers Sketch report' + LineEnding +
      specialize IfThen<string>(Preamble = '', '',
        'this one followed a crash' + LineEnding) +
      'version: ' + CurrentVersion + '  built ' + BUILD_STAMP + LineEnding +
      'when: ' + DateTimeToStr(Now) + LineEnding + LineEnding +
      'what they said:' + LineEnding +
      specialize IfThen<string>(Note = '', '(nothing written)', Note) +
      LineEnding + LineEnding +
      'state:' + LineEnding + DiagnosticText;
    if Preamble <> '' then
      Body := Body + LineEnding + 'the crash it left behind:' + LineEnding +
        Preamble;
    if WithDoc.Checked then
    begin
      L := TStringList.Create;
      try
        { For a crash, the drawing that matters is the one saved when it
          happened - the same reasoning as the picture.  By the time anyone
          is looking at this dialog the program has restarted, and what is on
          screen is an empty sheet or a draft read back off the disk, neither
          of which is the thing that went wrong.  Ticking the box and sending
          an empty drawing is worse than not offering it. }
        if (DocFile <> '') and FileExists(DocFile) then
        begin
          try
            L.LoadFromFile(DocFile);
          except
            L.Clear;
            BuildSession(L);
          end;
        end
        else
          BuildSession(L);
        Body := Body + LineEnding + 'the drawing, sent on purpose:' +
          LineEnding + L.Text;
      finally
        L.Free;
      end;
    end;
    Name_ := UniqueReportName('bug', CurrentVersion);
  finally
    Dlg.Free;
  end;

  { Now that the form has gone and the drawing is on screen again, ask about
    the picture.  Encouraged, because a report with one is worth several
    without; never assumed, because somebody may be drawing something they
    would rather not send a picture of. }
  { One question, and the buttons say what they do.

    This was two - include a picture, then set it up first - each with three
    paragraphs under a Yes and a No.  Two questions to answer one, and by the
    second one neither Yes nor No obviously meant what it did.  Naming the
    buttons says the whole thing without a paragraph explaining which word
    means what, and folds the two into one.

    There is no need to ask whether to keep it either: the picture is shown
    before anything is sent, and dropping it is one of the buttons there. }
  Application.ProcessMessages;
  ShotWay := QuestionDlg('A picture?',
    'A picture of this window shows which tool was in hand and what the ' +
    'settings were.  You see it before it is sent.',
    mtConfirmation,
    [mrYes, 'Give me 10 seconds', 'IsDefault',
     mrAll, 'Take it now',
     mrNo,  'No picture'], 0);
  WantShot := ShotWay in [mrYes, mrAll];

  { Taken now, before the report is sent, because taking it needs the window
    to itself and the person reporting has to be able to look at it and say
    no.  A crash brings its own picture, from when it happened - a fresh one
    then would only show whatever is on screen after the restart. }
  Shot := TMemoryStream.Create;
  try
    if (ShotFile <> '') and FileExists(ShotFile) then
    begin
      if WantShot then
        try
          Shot.LoadFromFile(ShotFile);
        except
          Shot.Size := 0;
        end;
    end
    else if WantShot then
      WantShot := TakeReportShot(Shot, ShotWay = mrYes);
    if Shot.Size = 0 then WantShot := False;

    FCmdMsg := 'Sending...';
  pbCmd.Invalidate;
  Application.ProcessMessages;
  if SendReport(Name_, Body, Err) then
  begin
    Result := True;
    FCmdMsg := 'Report sent - thank you.  (' + Name_ + ')';
    { The picture goes as its own file beside the report, sharing its name,
      so the two are obviously a pair.  If it will not go, the report has
      already gone and that is the part that mattered. }
    if WantShot then
      try
        Shot.Position := 0;
        if not SendBinary(ChangeFileExt(Name_, '.png'), Shot, 'image/png',
             ShotErr) then
          FCmdMsg := FCmdMsg + '  (the picture did not go: ' + ShotErr + ')';
      except
        on Ex: Exception do
          FCmdMsg := FCmdMsg + '  (no picture: ' + Ex.ClassName + ')';
      end;
  end
  else
  begin
    FCmdMsg := 'The report could not be sent - ' + Err;
    MessageDlg('Could not send it',
      'The report did not go: ' + Err + LineEnding + LineEnding +
      'Nothing is lost and nothing is broken - it just did not send.  ' +
      'The help button has the project page if you would rather say it ' +
        'there.', mtInformation, [mbOK], 0);
    end;
  finally
    Shot.Free;
  end;
  pbCmd.Invalidate;
end;

{ How many things are in the drawing that a report would actually carry. }
function TMainForm.DocThings(const DocFile: string): Integer;
var
  L: TStringList;
  I: Integer;
begin
  Result := FD.Doc.Live;
  if (DocFile = '') or not FileExists(DocFile) then Exit;
  L := TStringList.Create;
  try
    try
      L.LoadFromFile(DocFile);
      Result := 0;
      for I := 0 to L.Count - 1 do
        if (Copy(L[I], 1, 5) = 'LINE ') or (Copy(L[I], 1, 5) = 'FACE ') or
           (Copy(L[I], 1, 4) = 'ARC ') or (Copy(L[I], 1, 5) = 'TEXT ') or
           (Copy(L[I], 1, 4) = 'DIM ') or (Copy(L[I], 1, 6) = 'GUIDE ') then
          Inc(Result);
    except
      Result := FD.Doc.Live;
    end;
  finally
    L.Free;
  end;
end;

{ Laying a piece out flat.

  It takes a click rather than the selection, because a piece is a lot of
  faces and nobody wants to select them all first: click any part of it and
  the whole solid goes. }
procedure TMainForm.StartUnfold;
begin
  if FMode <> mdPro then Exit;
  FUnfoldPick := True;
  pbScreen.Cursor := crCross;
  FCmdMsg := 'Click any face of the piece to lay it out flat.  Esc to stop.';
  pbCmd.Invalidate;
end;

procedure TMainForm.UnfoldAt(SX, SY: Integer);
var
  F: Integer;
  Faces: TIntArray;
  Pat: TFlatPattern;
begin
  FUnfoldPick := False;
  F := FD.Doc.HitFace(Proj, SX, SY);
  if F < 0 then
  begin
    FCmdMsg := 'Nothing there to lay out - click a face of the piece.';
    pbCmd.Invalidate;
    Exit;
  end;
  Faces := SolidFaces(FD.Doc, F);
  if Length(Faces) = 0 then
  begin
    FCmdMsg := 'That face is not part of anything to lay out.';
    pbCmd.Invalidate;
    Exit;
  end;
  Pat := Unfold(FD.Doc, Faces);
  if not Pat.Ok then
  begin
    FCmdMsg := 'It could not be laid out - ' + Pat.Why;
    pbCmd.Invalidate;
    Exit;
  end;
  Trail(Format('unfolded %d panels', [Pat.Laid]));
  FCmdMsg := Format('Laid out: %d panels, sheet %s x %s',
    [Pat.Laid, FormatLen(Pat.MaxX - Pat.MinX, FD.Units),
     FormatLen(Pat.MaxY - Pat.MinY, FD.Units)]);
  pbCmd.Invalidate;
  ShowFlatPattern(Pat, FD.Units, 'Flat pattern');
end;

procedure TMainForm.OfferCrashReport;
var
  Fn: string;
  L: TStringList;

  { Put a crash report away under a name that cannot already be taken.

    A fixed name works once.  The second time, on Windows, the rename fails
    because the name is in use, the report stays where it was, and it gets
    offered again on every single start until somebody deletes it by hand.
    A timestamp cannot collide with the one before it. }
  procedure KeepAside(const Base: string);
  var
    Dst: string;
  begin
    Dst := Base + '.' + FormatDateTime('yyyymmdd-hhnnss', Now) + '.kept';
    if FileExists(Dst) then DeleteFile(Dst);
    if RenameFile(Base, Dst) then
      FCmdMsg := 'Kept it: ' + ExtractFileName(Dst)
    else
    begin
      { Could not even be moved aside.  Rather than ask about it forever,
        let it go - it has already been offered once and turned down. }
      DeleteFile(Base);
      FCmdMsg := 'That crash report could not be kept, so it was cleared.';
    end;
  end;

begin
  Fn := ExtractFilePath(ExpandFileName(ParamStr(0))) + 'heckers-sketch-crash.txt';
  if not FileExists(Fn) then Exit;
  L := TStringList.Create;
  try
    try
      L.LoadFromFile(Fn);
    except
      Exit;
    end;
    if L.Count = 0 then Exit;
    { Reporting it on GitHub wants a GitHub account, which the people this is
      built for have no reason to have.  So it is offered rather than assumed,
      and saying no still leaves the report sitting there with its path on
      screen, which is enough to send it on however suits. }
    { The same door as a report written by hand - one transport, one shape of
      report, and no GitHub account needed to use it. }
    case MessageDlg('It crashed last time',
           'There is a crash report from a previous run.'#13#10#13#10 +
           'Send it?  You get to say what you were doing first, and to see ' +
           'what is being sent.  Nothing goes anywhere until you press Send.',
           mtConfirmation, [mbYes, mbNo], 0) of
      mrYes:
        { Sent, so the copies here have done their job and go.  This used to
          rename the file aside first and send afterwards, which had it
          backwards twice over: it threw away the chance to try again if the
          sending failed, and the rename itself does not do what it looks
          like it does.  Windows will not rename a file onto a name that is
          already taken - so the second crash found heckers-sketch-crash.txt
          .sent already sitting there, the rename quietly failed, the report
          stayed where it was, and every start after that asked about the
          same crash again.  Which is exactly what Tony saw, and only ever on
          Windows. }
        if ReportBug(L.Text, Fn + '.png', Fn + '.hsk') then
        begin
          DeleteFile(Fn);
          DeleteFile(Fn + '.png');
          DeleteFile(Fn + '.hsk');
          FCmdMsg := FCmdMsg + '  It will not ask about this one again.';
        end
        else
          KeepAside(Fn);
    else
      KeepAside(Fn);
    end;
  finally
    L.Free;
  end;
end;

procedure TMainForm.ShakeWatch(X, Y: Integer);
const
  JERK_PX  = 12;
  JERK_N   = 4;
  JERK_MS  = 750;
var
  Now64: QWord;
  D, Sg: Integer;
  Was: TPlane;
begin
  if FMode <> mdPro then Exit;
  { The dimension tool is in this list because placing a dimension is the
    same question as drawing one: which plane is the thing going in.  Its
    offset comes from the cursor on the working plane, so on the flat plane a
    dimension can only be pushed in and out - and on the corner of a tall
    roof what you want is to push it down the face, or up clear of it.
    Standing the plane up is what allows that, and the shake is already how
    this program stands a plane up. }
  if not (FTool in [ptLine, ptRect, ptCircle, ptArc, ptDim]) then Exit;
  if FD.View = vkPlan then Exit;        // only one plane makes sense there

  Now64 := GetTickCount64;
  if Now64 - FShTX > JERK_MS then FShNX := 0;
  if Now64 - FShTY > JERK_MS then FShNY := 0;

  D := X - FShX;
  if Abs(D) >= JERK_PX then
  begin
    if D > 0 then Sg := 1 else Sg := -1;
    if (FShDirX <> 0) and (Sg <> FShDirX) then
    begin
      Inc(FShNX);
      FShTX := Now64;
    end;
    FShDirX := Sg;
    FShX := X;
  end;

  D := Y - FShY;
  if Abs(D) >= JERK_PX then
  begin
    if D > 0 then Sg := 1 else Sg := -1;
    if (FShDirY <> 0) and (Sg <> FShDirY) then
    begin
      Inc(FShNY);
      FShTY := Now64;
    end;
    FShDirY := Sg;
    FShY := Y;
  end;

  if (FShNX < JERK_N) and (FShNY < JERK_N) then Exit;

  Was := FD.Plane;
  if FShNY >= FShNX then
  begin
    { up and down: stand it up.  Which of the two upright planes is the one
      the same rule uses for a drag straight up the screen, so the answer
      agrees with what dragging would have done. }
    FD.Plane := PlaneByDrag(Proj, FCur, FMouseSX, FMouseSY - 200, plXZ, 1.0);
    if FD.Plane = plXY then FD.Plane := plXZ;
    FCmdMsg := 'Standing it up - ' + PlaneName + '.  Shake sideways to lay ' +
      'it flat, Esc to follow faces again.';
  end
  else
  begin
    FD.Plane := plXY;
    FCmdMsg := 'Laying it flat.  Shake up and down to stand it up, Esc to ' +
      'follow faces again.';
  end;
  FPlaneHeld := True;
  FShNX := 0;
  FShNY := 0;

  if FD.Plane <> Was then
  begin
    RepaintPaper;
    RenderPro;
    RecomposeAll;
  end;
  FScreenDirty := True;
  pbCmd.Invalidate;
end;

procedure TMainForm.PaintStrain(C: TCanvas; const A, B: TPointF; T: Single);
var
  I, N, W: Integer;
  MX, MY, DX, DY, L, NX, NY, Bow, Sh, Ang, R: Double;
  P0, P1: TPointF;
  Col: TPix;
  Cap: string;
  Sz: TSize;
begin
  T := EnsureRange(T, 0, 1);
  DX := B.X - A.X;
  DY := B.Y - A.Y;
  L := Sqrt(DX * DX + DY * DY);
  if L < 2 then Exit;
  NX := -DY / L;
  NY := DX / L;

  { it bows away from the pull and trembles harder the nearer it gets }
  Bow := 8 * FUIScale * Sin(T * Pi) * 0.9;
  Sh := 2.4 * FUIScale * T * T;
  MX := (A.X + B.X) / 2 + NX * Bow + (Random - 0.5) * 2 * Sh;
  MY := (A.Y + B.Y) / 2 + NY * Bow + (Random - 0.5) * 2 * Sh;

  { From the ink color to a hot red, and there early enough to be a warning
    rather than a surprise.  It gets *bolder* as it loads, not thinner - a
    thing about to let go looks strained, not frail. }
  Col := MixPix(AnnotColor, Pix(230, 38, 28), Power(T, 0.7));
  C.Pen.Style := psSolid;
  C.Pen.Color := PixToColor(Col);

  N := 12;
  for I := 0 to N - 1 do
  begin
    P0 := QuadAt(A, PtF(MX, MY), B, I / N);
    P1 := QuadAt(A, PtF(MX, MY), B, (I + 1) / N);
    { bold all over, and only right at the end does the middle give }
    W := Round((1.6 + 4.2 * T) * FUIScale);
    if T > 0.7 then
      W := Round(W * (1 - 0.75 * ((T - 0.7) / 0.3) * Sin((I + 0.5) / N * Pi)));
    C.Pen.Width := Max(1, W);
    C.MoveTo(Round(P0.X), Round(P0.Y));
    C.LineTo(Round(P1.X), Round(P1.Y));
  end;

  { and at the very end it starts to come apart - shards off the middle }
  if T > 0.78 then
  begin
    C.Pen.Width := Max(1, Round(2 * FUIScale));
    R := (T - 0.78) / 0.22 * 13 * FUIScale;
    for I := 0 to 5 do
    begin
      Ang := I * Pi / 3 + T * 3;
      C.MoveTo(Round(MX + Cos(Ang) * R * 0.35), Round(MY + Sin(Ang) * R * 0.35));
      C.LineTo(Round(MX + Cos(Ang) * R), Round(MY + Sin(Ang) * R));
    end;
  end;

  { Say what is about to happen.  A gesture that destroys something has to
    announce itself before it does it, or the first time you meet it is by
    accident and it looks like a bug. }
  if T > 0.12 then
  begin
    if FTool = ptLine then
    begin
      if T > 0.7 then Cap := 'LETTING GO...'
      else Cap := 'keep holding to snap the line off';
    end
    else
    begin
      if T > 0.7 then Cap := 'THROWING IT AWAY...'
      else Cap := 'made a mess?  keep holding';
    end;
    UIFont(C, 9, T > 0.7, Col);
    C.Brush.Style := bsSolid;
    C.Brush.Color := PixToColor(Theme.Screen1);
    Sz := C.TextExtent(Cap);
    C.TextOut(Round(MX - Sz.cx / 2), Round(MY - Sz.cy - 14 * FUIScale), Cap);
    C.Brush.Style := bsClear;
  end;
  C.Pen.Width := 1;
end;

{ The two ends recoiling after it lets go - brief, and the only thing that
  says the release was a break rather than a misclick. }
procedure TMainForm.PaintSnapRecoil(C: TCanvas);
var
  I: Integer;
  T, DX, DY, L, Ang, R: Double;
begin
  if FSnapT <= 0 then Exit;
  T := 1 - FSnapT / SNAP_RECOIL;          // 0 at the break, 1 at the end
  DX := FSnapB.X - FSnapA.X;
  DY := FSnapB.Y - FSnapA.Y;
  L := Sqrt(DX * DX + DY * DY);
  if L < 2 then Exit;
  DX := DX / L;
  DY := DY / L;
  C.Pen.Style := psSolid;
  C.Pen.Width := Max(1, Round(2 * FUIScale * (1 - T)));
  C.Pen.Color := PixToColor(MixPix(AnnotColor, Theme.Screen1, T));
  L := L * 0.30 * (1 - T);
  C.MoveTo(Round(FSnapA.X), Round(FSnapA.Y));
  C.LineTo(Round(FSnapA.X + DX * L), Round(FSnapA.Y + DY * L));
  C.MoveTo(Round(FSnapB.X), Round(FSnapB.Y));
  C.LineTo(Round(FSnapB.X - DX * L), Round(FSnapB.Y - DY * L));
  { the burst where it went, thrown outward and fading }
  C.Pen.Color := PixToColor(MixPix(Pix(230, 38, 28), Theme.Screen1, T));
  for I := 0 to 5 do
  begin
    Ang := I * Pi / 3 + 0.4;
    R := (10 + 26 * T) * FUIScale;
    C.MoveTo(Round(FSnapM.X + Cos(Ang) * R * 0.5),
             Round(FSnapM.Y + Sin(Ang) * R * 0.5));
    C.LineTo(Round(FSnapM.X + Cos(Ang) * R), Round(FSnapM.Y + Sin(Ang) * R));
  end;
  C.Pen.Width := 1;
end;

procedure TMainForm.PaintFacePoints(C: TCanvas; Face: Integer);
var
  Pts: TPointFArray;
  I, J, N, R: Integer;
  CX, CY: Double;

  procedure Dot(X, Y: Double; Big: Boolean);
  var
    D: Integer;
  begin
    if Big then D := R + 1 else D := R;
    if (X < -20) or (Y < -20) or
       (X > pbScreen.Width + 20) or (Y > pbScreen.Height + 20) then Exit;
    C.Ellipse(Round(X) - D, Round(Y) - D, Round(X) + D + 1, Round(Y) + D + 1);
  end;

begin
  if Face < 0 then Exit;
  Pts := FD.Doc.Outline(Proj, Face);
  N := Length(Pts);
  if N < 3 then Exit;
  { A pulled circle has 48 sides; peppering it with dots would be noise. }
  if N > 16 then Exit;

  R := Max(2, Round(2.5 * FUIScale));
  C.Pen.Style := psSolid;
  C.Pen.Width := 1;
  C.Pen.Color := PixToColor(Pix(90, 120, 160));
  C.Brush.Style := bsSolid;
  C.Brush.Color := PixToColor(Pix(210, 228, 245));

  CX := 0; CY := 0;
  for I := 0 to N - 1 do
  begin
    J := (I + 1) mod N;
    Dot(Pts[I].X, Pts[I].Y, False);                              // corner
    Dot((Pts[I].X + Pts[J].X) / 2, (Pts[I].Y + Pts[J].Y) / 2, False);  // middle
    CX := CX + Pts[I].X;
    CY := CY + Pts[I].Y;
  end;
  { the middle of the whole face, a size up so it reads as the special one }
  C.Brush.Color := PixToColor(Pix(255, 246, 210));
  Dot(CX / N, CY / N, True);

  C.Brush.Style := bsClear;
  C.Pen.Width := 1;
end;

procedure TMainForm.PaintSnapMarker(C: TCanvas; SX, SY: Integer);
var
  MarkPix: TPix;
  MarkD: Integer;
begin
  { SketchUp marks it with one small solid diamond and lets the color say
    what it found: green a corner, cyan a middle, red a point lying on an
    edge, violet a crossing.  One shape reads faster than five, and after a
    while you stop reading the label at all. }
  case FSnapKind of
    snEndpoint, snCenter: MarkPix := Pix(60, 210, 90);
    snMidpoint, snSubMid: MarkPix := Pix(90, 220, 235);
    snOnEdge:             MarkPix := Pix(235, 70, 70);
    { the mark takes the color of the axis it is on, which is the whole point
      of the axes being colored }
    snOnAxis:             MarkPix := AxisPix(FSnapAxis);
    snOrigin:             MarkPix := Pix(250, 210, 60);
    snCross:              MarkPix := Pix(215, 120, 240);
  else
    MarkPix := Theme.Accent;
  end;

  C.Pen.Width := 1;
  C.Brush.Style := bsSolid;
  C.Brush.Color := PixToColor(MarkPix);
  if FSnapKind = snGrid then
  begin
    { the grid is ours, not SketchUp's, and it is everywhere - a full diamond
      on every move would be noise, so it gets a dot }
    C.Pen.Color := PixToColor(MarkPix);
    C.FillRect(SX - 2, SY - 2, SX + 3, SY + 3);
  end
  else if FSnapKind <> snNone then
  begin
    MarkD := Round(5 * FUIScale);
    { a thin dark rim so the diamond still reads over pale artwork }
    C.Pen.Color := PixToColor(Pix(24, 24, 28));
    C.Polygon([Point(SX, SY - MarkD), Point(SX + MarkD, SY),
               Point(SX, SY + MarkD), Point(SX - MarkD, SY)]);
    { hollow the middle of a sub-midpoint, which is the middle of a piece of
      a line rather than of the whole one }
    if FSnapKind = snSubMid then
    begin
      C.Brush.Color := PixToColor(Theme.Screen1);
      C.Pen.Color := PixToColor(Theme.Screen1);
      C.Polygon([Point(SX, SY - MarkD + 2), Point(SX + MarkD - 2, SY),
                 Point(SX, SY + MarkD - 2), Point(SX - MarkD + 2, SY)]);
    end;
  end;
  C.Brush.Style := bsClear;
  C.Pen.Width := 1;
end;

{ Wash a face in a colour without hiding what is on it.

  A solid fill over a panel would cover the lines and the notes that live on
  it, which is the opposite of helpful when the question being asked is "am I
  about to delete the right thing".  A diagonal hatch reads as marked out
  from across the room and leaves the drawing legible underneath. }
procedure TMainForm.WashFace(C: TCanvas; const Poly: TPointFArray;
  const Col: TPix);
var
  Pts: array of TPoint;
  I: Integer;
begin
  if Length(Poly) < 3 then Exit;
  SetLength(Pts, Length(Poly));
  for I := 0 to High(Poly) do
    Pts[I] := Point(Round(Poly[I].X), Round(Poly[I].Y));
  C.Brush.Style := bsDiagCross;
  C.Brush.Color := PixToColor(Col);
  C.Pen.Style := psClear;
  C.Polygon(Pts);
  C.Brush.Style := bsClear;
  C.Pen.Style := psSolid;
end;

procedure TMainForm.PaintProOverlay(C: TCanvas);
var
  HintFace: Integer;
  CircI: Integer;
  CircR: Double;
  P, PPrev: TPointF;
  SX, SY, AX, AY: Integer;
  BarLen, BarPx: Double;
  R: TRect;
  GP: TPointF;
  Hi: TPointFArray;
  RectPrev: TP3Array;
  RectI: Integer;
  S1, S2: string;
  W1, W2, BoxW, BoxH, LnH: Integer;

  { When the cursor is locked to an axis the band is drawn in that axis's
    color, so the direction you are committing to is readable without
    looking away at the chip. }
  procedure Rubber(const A, B: TP3);
  var
    PA, PB: TPointF;
    Ax: Integer;
  begin
    PA := ScreenOf(A);
    PB := ScreenOf(B);
    { Solid, and heavy enough to be unmistakable.  SketchUp keeps the shape
      you are placing solid, and it is right to: a dashed hairline reads as
      something faint and provisional when it is in fact the thing you are
      about to commit.  Heavier again when it is locked to an axis, because
      then the line is also telling you which way you are going. }
    C.Pen.Style := psSolid;
    C.Pen.Width := Max(3, Round(3 * FUIScale));
    { A line's color is the direction it runs in.  It was briefly the color
      of the plane it lay in, which sounds close and is not: a plane's color
      names the axis it *faces*, and that is the one axis a shape lying in it
      can have no edge along.  Stood up on XZ a rectangle came out green,
      when its four sides run red and blue - the one color it had no claim
      to.  An edge that runs off on its own gets no axis color, the same way
      it gets none once it is drawn. }
    if FAxisLock in [0..2] then Ax := FAxisLock else Ax := AxisAlong(A, B);
    if Ax >= 0 then
      C.Pen.Color := PixToColor(AxisPix(Ax))
    else
      C.Pen.Color := PixToColor(Theme.Accent);
    C.MoveTo(Round(PA.X), Round(PA.Y));
    C.LineTo(Round(PB.X), Round(PB.Y));
    C.Pen.Style := psSolid;
    C.Pen.Width := 1;
  end;

begin
  P := ScreenOf(FCur);
  SX := Round(P.X);
  SY := Round(P.Y);

  { --- live preview ---------------------------------------------------- }

  { Leaning on the button to throw away what is being drawn works for every
    tool that has something in progress, not only for a run of lines.  Tony's
    observation, and it is the right one: you know you have made a mess the
    instant the button goes down, and the fix should be to keep leaning on it
    rather than to finish the shape, find the eraser, and pick it off again.

    While it is straining the shape's own preview is replaced by the strain,
    so there is one thing happening on screen rather than two. }
  if FHoldOn and (FHoldT > HOLD_STRAIN) and (FStage >= 1) then
  begin
    PaintStrain(C, ScreenOf(FP1), PtF(FMouseSX, FMouseSY),
      (FHoldT - HOLD_STRAIN) / (HOLD_BREAK - HOLD_STRAIN));
    PaintSnapRecoil(C);
    Exit;
  end;

  case FTool of
    ptLine:
      if FStage = 1 then Rubber(FP1, PreviewTarget);
    ptRect:
      if FStage = 1 then
      begin
        RectPrev := RectCorners(FP1, RectTarget, FD.Plane);
        for RectI := 0 to 3 do
          Rubber(RectPrev[RectI], RectPrev[(RectI + 1) mod 4]);
      end;
    ptOffset:
      if FStage = 1 then
      begin
        RectPrev := OffsetPreview;
        for RectI := 0 to High(RectPrev) do
          Rubber(RectPrev[RectI], RectPrev[(RectI + 1) mod Length(RectPrev)]);
      end;
    ptArc:
      begin
        if FStage >= 1 then Rubber(FP1, FCur);
        if FStage = 2 then Rubber(FP2, FCur);
      end;
    ptCircle:
      if FStage = 1 then
      begin
        { Drawn in the plane it is going to land in, rather than as a round
          ring on the glass.  It used to be a screen circle - "close enough
          for a rubber band" - and the cost of that was the one thing you
          most need to see: change the plane under a circle and nothing on
          screen moved, so it looked as though the plane had not changed.

          A circle is the one shape that keeps the plane's color, and it is
          the one shape entitled to it: it runs in every direction at once,
          so there is no direction of its own for it to be colored by, and
          the axis its plane faces is the only thing left to say. }
        C.Pen.Style := psSolid;
        C.Pen.Color := PixToColor(PlanePix(FD.Plane));
        C.Pen.Width := Max(3, Round(3 * FUIScale));
        C.Brush.Style := bsClear;
        CircR := Dist(FP1, FCur);
        if CircR > 1E-9 then
        begin
          PPrev := ScreenOf(ArcPoint(FP1, CircR, 0, FD.Plane));
          for CircI := 1 to 48 do
          begin
            P := ScreenOf(ArcPoint(FP1, CircR, CircI * 2 * Pi / 48, FD.Plane));
            C.MoveTo(Round(PPrev.X), Round(PPrev.Y));
            C.LineTo(Round(P.X), Round(P.Y));
            PPrev := P;
          end;
        end;
        C.Pen.Width := 1;
      end;
    ptMeasure:
      if FStage >= 1 then
      begin
        if FStage = 1 then Rubber(FP1, FCur) else Rubber(FP1, FP2);
        { the whole reading follows the cursor, angles and all, so a run can
          be checked for level without letting go of it }
        if FStage = 1 then FCmdMsg := RunReading(FP1, FCur);
        { the running length beside the cursor, far enough off it to read
          while you are dragging - a tape you have to look away from to read
          is no use for a quick check }
        if FStage = 1 then S1 := FormatLen(Dist(FP1, FCur), FD.Units)
        else S1 := FormatLen(Dist(FP1, FP2), FD.Units);
        UIFont(C, 11, True, AnnotColor);
        C.Brush.Style := bsSolid;
        C.Brush.Color := PixToColor(Theme.Screen1);
        C.TextOut(SX + Round(22 * FUIScale), SY - Round(30 * FUIScale), S1);
        C.Brush.Style := bsClear;
      end;
    ptDim:
      if FStage = 1 then Rubber(FP1, FCur)
      else if FStage = 2 then PaintDimPreview(C);

    ptPush:
      if FStage = 1 then
      begin
        PaintFaceHint(C, FPushFace, HINT_BLUE);
        PaintPushPreview(C);
      end
      else
        PaintFaceHint(C, FHoverFace, HINT_BLUE);
    ptMove: PaintMoveGhost(C);
    ptSelect, ptText, ptErase, ptOrbit: ;   // nothing to rubber-band
  end;

  PaintSnapRecoil(C);

  { The face a new shape is about to land on, washed over and with its own
    points marked, so there is no doubt which surface you are drawing on.
    Only before the first click - once the shape is under way the plane is
    settled and the wash would just be in the way. }
  if (FStage = 0) and (FTool in [ptLine, ptRect, ptCircle, ptArc]) and
     not FPlaneHeld then
  begin
    { Asked here rather than read from what the motion handler cached.  The
      cache is a tick behind and is cleared by things that have nothing to do
      with where the cursor is, and the result was a face that lit up only
      sometimes.  A point-in-polygon test over a handful of faces costs
      nothing at paint time. }
    HintFace := FD.Doc.HitFace(Proj, FMouseSX, FMouseSY);
    if HintFace >= 0 then
    begin
      PaintFaceHint(C, HintFace, HINT_BLUE);
      PaintFacePoints(C, HintFace);
    end;
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

  { --- what is selected ------------------------------------------------ }
  for AY := 0 to High(FSel) do
  begin
    Hi := FD.Doc.Outline(Proj, FSel[AY]);
    if Length(Hi) >= 2 then
    begin
      C.Pen.Color := PixToColor(Pix(70, 130, 240));
      C.Pen.Width := Max(3, Round(3 * FUIScale));
      C.Pen.Style := psSolid;
      C.MoveTo(Round(Hi[0].X), Round(Hi[0].Y));
      for AX := 1 to High(Hi) do
        C.LineTo(Round(Hi[AX].X), Round(Hi[AX].Y));
      C.Pen.Width := 1;
    end;
  end;

  { the edge the dimension tool would take }
  if (FTool = ptDim) and (FStage = 0) and (FHoverEnt >= 0) then
  begin
    Hi := FD.Doc.Outline(Proj, FHoverEnt);
    if Length(Hi) >= 2 then
    begin
      C.Pen.Color := PixToColor(HINT_BLUE);
      C.Pen.Width := Max(3, Round(3 * FUIScale));
      C.Pen.Style := psSolid;
      C.MoveTo(Round(Hi[0].X), Round(Hi[0].Y));
      for AX := 1 to High(Hi) do
        C.LineTo(Round(Hi[AX].X), Round(Hi[AX].Y));
      C.Pen.Width := 1;
    end;
  end;

  { what a click would take, so a pick can be aimed before committing }
  if (FTool in [ptSelect, ptMove]) and (FHoverEnt >= 0) and
     not IsSelected(FHoverEnt) then
  begin
    Hi := FD.Doc.Outline(Proj, FHoverEnt);
    if Length(Hi) >= 2 then
    begin
      C.Pen.Color := PixToColor(Pix(150, 185, 245));
      C.Pen.Width := Max(2, Round(2 * FUIScale));
      C.Pen.Style := psSolid;
      C.MoveTo(Round(Hi[0].X), Round(Hi[0].Y));
      for AX := 1 to High(Hi) do
        C.LineTo(Round(Hi[AX].X), Round(Hi[AX].Y));
      C.Pen.Width := 1;
    end;
  end;

  { the box itself.  Dashed for a crossing box, solid for a containing one,
    which is the only cue telling you which rule is in force. }
  if FBoxing then
  begin
    C.Brush.Style := bsClear;
    C.Pen.Color := PixToColor(Pix(70, 130, 240));
    C.Pen.Width := Max(1, Round(FUIScale));
    if FMouseSX < FBoxX then C.Pen.Style := psDash else C.Pen.Style := psSolid;
    C.Rectangle(Min(FBoxX, FMouseSX), Min(FBoxY, FMouseSY),
                Max(FBoxX, FMouseSX), Max(FBoxY, FMouseSY));
    C.Pen.Style := psSolid;
  end;

  { --- what the eraser is about to remove ------------------------------ }
  { everything gathered so far, in red, so a sweep can be seen before it
    happens and a wrong one abandoned by never letting go over anything }
  for AY := 0 to High(FDoomed) do
  begin
    Hi := FD.Doc.Outline(Proj, FDoomed[AY]);
    if (Length(Hi) >= 3) and (FD.Doc[FDoomed[AY]].Kind = ekFace) then
      WashFace(C, Hi, Pix(240, 60, 60));
    if Length(Hi) >= 2 then
    begin
      C.Pen.Color := PixToColor(Pix(240, 60, 60));
      C.Pen.Width := Max(3, Round(3 * FUIScale));
      C.Pen.Style := psSolid;
      C.MoveTo(Round(Hi[0].X), Round(Hi[0].Y));
      for AX := 1 to High(Hi) do
        C.LineTo(Round(Hi[AX].X), Round(Hi[AX].Y));
      C.Pen.Width := 1;
    end;
  end;

  if (FTool = ptErase) and (FHoverEnt >= 0) and not FErasing2 then
  begin
    Hi := FD.Doc.Outline(Proj, FHoverEnt);
    { A whole panel is a lot to lose to a click, so when the eraser has locked
      onto one it says so across the face rather than round its edge. }
    if (Length(Hi) >= 3) and (FD.Doc[FHoverEnt].Kind = ekFace) then
      WashFace(C, Hi, Pix(230, 70, 70));
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

  { --- the axis you are locked to --------------------------------------- }
  if FAxisLock in [0..2] then
  begin
    GP := ScreenOf(FAxisFrom);
    C.Pen.Style := psDot;
    C.Pen.Color := PixToColor(AxisPix(FAxisLock));
    C.Pen.Width := Max(1, Round(FUIScale));
    { run it past the cursor as well, so it reads as a line you are on
      rather than a measurement between two points }
    C.MoveTo(Round(GP.X), Round(GP.Y));
    C.LineTo(SX + Round((SX - GP.X) * 0.18), SY + Round((SY - GP.Y) * 0.18));
    C.Pen.Style := psSolid;
    C.Pen.Width := 1;
  end;

  { --- lined up with a point somewhere else ----------------------------- }
  if FGuide then
  begin
    GP := ScreenOf(FGuideFrom);
    C.Pen.Style := psDot;
    C.Pen.Color := PixToColor(GuideColor);
    C.Pen.Width := 1;
    C.MoveTo(Round(GP.X), Round(GP.Y));
    C.LineTo(SX, SY);
    C.Pen.Style := psSolid;
    C.Brush.Style := bsClear;
    C.Pen.Color := PixToColor(GuideColor);
    C.Rectangle(Round(GP.X) - 3, Round(GP.Y) - 3, Round(GP.X) + 4, Round(GP.Y) + 4);
  end;

  { --- the point being held as a reference ------------------------------ }
  if FLockOn then
  begin
    GP := ScreenOf(FLockPt);
    C.Pen.Style := psSolid;
    C.Pen.Width := Max(2, Round(2 * FUIScale));
    C.Pen.Color := PixToColor(GuideColor);
    C.Brush.Style := bsClear;
    C.Ellipse(Round(GP.X) - 7, Round(GP.Y) - 7, Round(GP.X) + 8, Round(GP.Y) + 8);
    C.Pen.Width := 1;
  end;


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
      ptText:  S2 := 'space or click - the note points here';
      ptMeasure:
        S2 := 'measure from here - it leaves a guide and a point';
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
      ptText:   S2 := 'type it, move away, then Enter';
      ptDim:    S2 := 'move away to place it - shake up and down to stand it up';
      ptMeasure: S2 := 'click the second point';
      ptRect:   S2 := 'drag it, or type 8x10 - the pad''s slash works too';
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

  R := TipSpot(SX, SY, BoxW, BoxH);

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
  CR, Rad, SX, SY, Arm, Gap, I: Integer;
  Contrast, Halo, CPix: TPix;
  CW, CA: Double;
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
    { And the same at this end.  A cursor that projects to somewhere absurd -
      an orbit camera looking almost along an axis will do it - used to be
      rounded into an integer that had wrapped, and the overlay then asked
      for a square of artwork starting there. }
    if IsNan(CP.X) or IsNan(CP.Y) or IsInfinite(CP.X) or IsInfinite(CP.Y) then
      CP := PtF(FMouseSX, FMouseSY);
    SX := EnsureRange(Round(EnsureRange(CP.X, -1E6, 1E6)),
      -20000, pbScreen.Width + 20000);
    SY := EnsureRange(Round(EnsureRange(CP.Y, -1E6, 1E6)),
      -20000, pbScreen.Height + 20000);
    PaintProOverlay(pbScreen.Canvas);
  end
  else
  begin
    { The same clamp the PRO side has.  The toy's pen is driven by two knobs
      and has never gone anywhere strange, but Round of a number that is not
      one produces an integer that has wrapped rather than an error, and
      every guard downstream is written in terms of how big that integer is. }
    SX := EnsureRange(Round(EnsureRange(FPenX, -1E6, 1E6)),
      -20000, pbScreen.Width + 20000);
    SY := EnsureRange(Round(EnsureRange(FPenY, -1E6, 1E6)),
      -20000, pbScreen.Height + 20000);
  end;

  { While a list is open the drawing's cursor is not drawn at all.  It is
    tracking a point on the paper that the mouse is no longer choosing, so it
    sits somewhere unrelated to the pointer and reads as a second cursor
    disagreeing with the first.  The list has the mouse; let it have it
    plainly. }
  if FPopup <> POP_NONE then
  begin
    PaintPopup(pbScreen.Canvas);
    { and whatever else belongs on top of everything - a list being open is
      no reason for the shutter countdown to disappear, and it did }
    PaintShotOverlay(pbScreen.Canvas);
    Exit;
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

  if FMode = mdPro then
  begin
    { A fine target, not a ring.  The old ring was nine pixels of solid line
      sitting on the drawing, which hid the very corner you were aiming at.
      Four short arms with a gap in the middle and a single dot say exactly
      where the point will land and cover almost nothing.  The dark pass
      underneath keeps it readable over pale artwork. }
    Arm := Round(7 * FUIScale);
    Gap := Round(2 * FUIScale);
    Halo := MixPix(Contrast, Pix(128, 128, 128), 0.9);
    for I := 0 to 1 do
    begin
      if I = 0 then begin CW := 2.6; CA := 0.30; CPix := Halo; end
      else begin CW := 1.2; CA := 0.95; CPix := Contrast; end;
      FOverlay.Line(CR - Arm, CR, CR - Gap, CR, CW, CPix, CA);
      FOverlay.Line(CR + Gap, CR, CR + Arm, CR, CW, CPix, CA);
      FOverlay.Line(CR, CR - Arm, CR, CR - Gap, CW, CPix, CA);
      FOverlay.Line(CR, CR + Gap, CR, CR + Arm, CW, CPix, CA);
    end;
    FOverlay.Disc(CR, CR, 1.1, Contrast, 0.95);
  end
  else
  begin
    FOverlay.Ring(CR, CR, Rad + 1.2, 2.6,
      MixPix(Contrast, Pix(128, 128, 128), 0.85), 0.35);
    FOverlay.Ring(CR, CR, Rad, 1.4, Contrast, 0.95);
  end;

  if FMode = mdToy then
  begin
    if FPenUp then
      FOverlay.Ring(CR, CR, Rad * 0.45, 1.2, Contrast, 0.7)
    else
      FOverlay.Disc(CR, CR, 1.6, Contrast, 0.9);
  end;

  FOverlay.DrawTo(pbScreen.Canvas, SX - CR, SY - CR);

  if FMode = mdPro then
    PaintSnapMarker(pbScreen.Canvas, SX, SY);

  { the tool's own glyph rides beside the cursor, so which tool is in hand is
    never a matter of remembering which button is lit }
  if (FMode = mdPro) and (FTool <> ptSelect) then
    PaintToolGlyph(pbScreen.Canvas, SX + CR - Round(2 * FUIScale),
      SY - CR - Round(2 * FUIScale));

  PaintPopup(pbScreen.Canvas);
  PaintShotOverlay(pbScreen.Canvas);
end;

{ ======================================================================== }
{ pro mode: the tools                                                       }
{ ======================================================================== }

function TMainForm.PlaneName: string;
begin
  if FD.Plane = plFree then Exit('on the face');
  Result := Copy('XYXZYZ', Ord(FD.Plane) * 2 + 1, 2);
end;

{ Drawing in 3D always landed flat, because the working plane only changed
  from the K key or a typed command and nothing said so. The arrows pick it
  now, before a shape is started: up or down for the upright plane, left or
  right for the side one, Page Up or Down back to flat. Once a line is under
  way the arrows go back to locking its direction, which is what they are
  for at that point. }
procedure TMainForm.PlaneByArrow(Key: Word);
var
  Was: TPlane;
begin
  Was := FD.Plane;
  { SketchUp locks a plane by naming its normal with the axis colors: right
    is red, left is green, up is blue.  Down lets go again. }
  if Key = VK_DOWN then
  begin
    FPlaneHeld := False;
    FCmdMsg := 'Following the face under the cursor again.';
    pbCmd.Invalidate;
    FScreenDirty := True;
    Exit;
  end;
  case Key of
    VK_RIGHT: FD.Plane := plYZ;     // normal is red, X
    VK_LEFT: FD.Plane := plXZ;      // normal is green, Y
  else
    FD.Plane := plXY;               // normal is blue, Z
  end;
  FPlaneHeld := True;
  if FD.Plane <> Was then
  begin
    RepaintPaper;
    RenderPro;
    RecomposeAll;
  end;
  case FD.Plane of
    plXZ: FCmdMsg := 'Drawing upright, on the XZ plane.';
    plYZ: FCmdMsg := 'Drawing on the side, the YZ plane.';
  else
    FCmdMsg := 'Drawing flat, on the XY plane.';
  end;
  FCmdMsg := FCmdMsg + '  Esc to follow faces again.';
  pbCmd.Invalidate;
  FScreenDirty := True;
end;

{ Leave a standard view for the free camera, aimed where you were already
  looking.

  The zoom and the pan are kept.  Picking the orbit tool used to park on the
  corner preset, which frames the whole drawing - so reaching for orbit while
  zoomed into one fitting threw the drawing away and gave you the lot from a
  standard angle.  A middle-drag out of the same view has always kept its
  place; there is no reason the tool button should not. }
procedure TMainForm.EnterFreeCamera(AtCorner: Boolean);
begin
  if FD.View = vkOrbit then Exit;
  if AtCorner then
  begin
    { asked for by push/pull, which needs to see the face it is about to
      move and cannot from straight above }
    FD.Az := -Pi / 4;
    FD.El := ISO_EL;
  end
  else if FD.View = vkIso then
  begin
    FD.Az := -Pi / 4;
    FD.El := ISO_EL;
  end
  else
  begin
    FD.Az := 0;
    FD.El := 1.45;                  // as near straight down as it tilts
  end;
  FD.View := vkOrbit;
  FViewPreset := -1;
  RebuildDeck;
  pbDeck.Invalidate;
  pbView.Invalidate;
  RepaintPaper;
  RenderPro;
  RecomposeAll;
end;

procedure TMainForm.SetTool(T: TProTool);
begin
  Trail('tool ' + TOOL_NAMES[T]);
  { Push/pull along a face normal that points at the camera can only move the
    face away from you, which plan cannot draw and you cannot judge. Rather
    than leave a tool that appears to do nothing, go and get a view where it
    means something. }
  if (T = ptPush) and (FD.View = vkPlan) then
  begin
    EnterFreeCamera(True);
    FCmdMsg := 'Push/pull needs to see the face - switched to the corner view.';
  end;
  if (T = ptOrbit) and (FD.View <> vkOrbit) then
  begin
    EnterFreeCamera;
    FCmdMsg := 'Orbit - drag to spin.  Shift drags to pan.';
  end;
  if T = ptOrbit then pbScreen.Cursor := crSizeAll
  else pbScreen.Cursor := crCross;
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
  FUnfoldPick := False;
  FNoteDrag := -1;
  FStickOn := False;
  { Minus one is "no dimension being edited", and it has to be said out loud.
    A field starts at zero, zero is a valid entity index, and the test for
    whether a label is being typed is FDimEdit >= 0 - so a fresh program
    believed you were editing the label on entity nought and put every letter
    you pressed into the command bar instead of treating it as a shortcut.
    Every run, from the first keystroke. }
  FDimEdit := -1;
  FHoverEnt := -1;
  FHoverFace := -1;
  FPlaneHeld := False;
  FGuide := False;
  FAxisLock := -1;
  FLockOn := False;
  FDirLock := -1;
  FInput := '';
  FBoxing := False;
  FMoveCopy := False;
  SetLength(FMoveVerts, 0);
  pbScreen.Invalidate;
  pbCmd.Invalidate;
end;

function TMainForm.PlanePix(Pl: TPlane): TPix;
begin
  case Pl of
    plXZ: Result := AxisPix(1);      { faces along Y, green }
    plYZ: Result := AxisPix(0);      { faces along X, red }
    { A sloped face points along no axis, so it gets no axis colour.  Saying
      "some of red and some of blue" with a blend would read as a third axis
      that does not exist. }
    plFree: Result := Theme.Accent;
  else
    Result := AxisPix(2);            { flat, faces up Z, blue }
  end;
end;

{ Which of the three paper axes a line being drawn in ISO is meant to run
  along, as an index into AxisDir - or -1 before the drag says anything.

  This is what drawing on iso paper *is*.  The three directions on the sheet
  are the three model axes, and a fitter sketching a run puts every leg on one
  of them; a leg at some other angle on iso paper does not mean a diagonal, it
  means a mistake.  So the line is locked to the nearest of the three rather
  than merely nudged towards it, and the plane the working plane happens to be
  on does not come into it.

  All three, deliberately, not the two in the current isoplane.  A run chains:
  twelve feet across, then a drop.  Making that a keystroke between legs would
  be exactly the friction the whole exercise is meant to remove.  The isoplane
  still decides where a rectangle or a circle lies, because those need a
  plane; a line only needs a direction.

  Measured on screen and not in the model, for the same reason the snap
  inference is - see AxisTry.  What "nearest" means to a person drawing is
  nearest on the paper in front of them. }
function TMainForm.IsoRunAxis(const From: TP3; out Along: Double): Integer;
var
  K: Integer;
  PR, PA: TPointF;
  UX, UY, VX, VY, LenSq, Off, Best, Step: Double;
  AD: TP3;
begin
  Result := -1;
  Along := 0;
  PR := ScreenOf(From);
  VX := FMouseSX - PR.X;
  VY := FMouseSY - PR.Y;
  { Nothing to read yet.  Under a few pixels the drag has no direction in it
    and picking one would make the line jump about under the cursor. }
  if VX * VX + VY * VY < Sqr(6 * FUIScale) then Exit;
  Best := 1E30;
  for K := 0 to 2 do
  begin
    AD := AxisDir(K * 2);
    PA := ScreenOf(P3(From.X + AD.X, From.Y + AD.Y, From.Z + AD.Z));
    UX := PA.X - PR.X;
    UY := PA.Y - PR.Y;
    LenSq := UX * UX + UY * UY;
    if LenSq < Sqr(0.2 * Ppu) then Continue;
    { how far off this axis the cursor sits, in pixels }
    Off := Abs(VX * UY - VY * UX) / Sqrt(LenSq);
    if Off < Best then
    begin
      Best := Off;
      Result := K * 2;
      { And how far along it, from the same screen measurement that chose it.

        This has to come from here rather than from the snapped cursor, and
        that is not tidiness.  The axis is picked from where the mouse is;
        the cursor has by then been pulled onto whatever the snapping thought
        best, which can be a different axis entirely.  Reading the length off
        that gave a leg that agreed with the mouse about its direction and
        with the snap about its length - two hundred and fifty pixels along
        the red axis came out as two inches.  One source for both, and they
        cannot disagree.

        PA is one world unit away, so this is already in world units. }
      Along := (VX * UX + VY * UY) / LenSq;
    end;
  end;
  if Result < 0 then Exit;
  { Land on the ruling.  A leg off a grid multiple is not what anyone drawing
    on squared paper means, and the length is now ours to round rather than
    something inherited from an already-snapped point. }
  Step := SnapStep;
  if Step > 1E-9 then Along := Round(Along / Step) * Step;
end;

{ Which axis a segment runs along, or -1 for one that runs off on its own.
  Nearly exact, because an edge either lies on an axis or it does not - a
  rectangle's sides are dead on two of them and a line you dragged out by
  hand is dead on none. }
function TMainForm.AxisAlong(const A, B: TP3): Integer;
var
  DX, DY, DZ, L: Double;
begin
  Result := -1;
  DX := B.X - A.X;
  DY := B.Y - A.Y;
  DZ := B.Z - A.Z;
  L := Sqrt(DX * DX + DY * DY + DZ * DZ);
  if L < 1E-9 then Exit;
  if Abs(DX) / L > 0.9999 then Result := 0
  else if Abs(DY) / L > 0.9999 then Result := 1
  else if Abs(DZ) / L > 0.9999 then Result := 2;
end;

function TMainForm.LiveMeasure: string;
var
  T: TP3;
  W, H, L: Double;
begin
  Result := '';
  if FMode <> mdPro then Exit;
  case FTool of
    ptLine:
      if FStage = 1 then
        Result := FormatLen(Dist(FP1, PreviewTarget), FD.Units);
    ptRect:
      if FStage = 1 then
      begin
        RectSides(FP1, RectTarget, FD.Plane, W, H);
        { the comma is how SketchUp takes two sides, and how we take them }
        Result := FormatLen(W, FD.Units) + ', ' + FormatLen(H, FD.Units);
      end;
    ptCircle:
      if FStage = 1 then
        Result := FormatLen(Dist(FP1, FCur), FD.Units);
    ptPush:
      if (FStage = 1) and (FPushFace >= 0) then
      begin
        L := PushDistance;
        if Abs(L) > 1E-9 then Result := FormatLen(Abs(L), FD.Units);
        if FPushFlush then Result := Result + '  flush';
      end;
    ptOffset:
      if FStage = 1 then
      begin
        L := OffsetDistance;
        if Abs(L) > 1E-9 then Result := FormatLen(Abs(L), FD.Units);
      end;
    ptMeasure, ptDim:
      if FStage >= 1 then
      begin
        T := PreviewTarget;
        if Dist(FP1, T) > 1E-9 then Result := FormatLen(Dist(FP1, T), FD.Units);
      end;
  end;
end;

function TMainForm.Prompt: string;
var
  PromptAlong: Double;
begin
  case FTool of
    ptLine:
      if FStage = 0 then
        Result := 'pick a start point'
      else if FDirLock >= 0 then
        Result := 'going ' + AxisName(FDirLock) + ' - length?'
      else if (FD.View = vkIso) and (ssShift in FMoveShift) then
        Result := 'off the grid - Shift held.  Let go to snap back to it'
      else if (FD.View = vkIso) and (IsoRunAxis(FP1, PromptAlong) >= 0) then
        Result := 'going ' + AxisName(IsoRunAxis(FP1, PromptAlong)) +
          ' on the grid - length?  Shift to come off it'
      else
        Result := 'to the next point, or type a length  -  double-click to finish';
    ptArc:
      case FStage of
        0: Result := 'pick the first end';
        1: Result := 'pick the second end';
      else
        Result := 'pull the middle out, or type the bulge';
      end;
    ptRect:
      if FStage = 0 then Result := 'pick a corner'
      else Result := 'opposite corner, or type 12''x8''';
    ptCircle:
      if FStage = 0 then Result := 'pick the center' else Result := 'radius?';
    ptText:
      if FStage = 0 then
        Result := 'click what the note is about'
      else
        Result := 'type it - Shift+Enter for another line - then move away and Enter';
    ptPush:
      if FStage = 0 then
        Result := 'click a face'
      else
        Result := 'how far?  type it, or move and click';
    ptDim:
      case FStage of
        0:
          if FHoverEnt >= 0 then
            Result := 'click the lit edge to dimension all of it'
          else
            Result := 'click an edge, or a first point to measure from';
        1: Result := 'second point';
      else
        Result := 'move away to place the line, then click';
      end;
    ptOrbit:
      Result := 'drag to spin the view - Shift drags to pan';
    ptSelect:
      if Length(FSel) = 0 then
        Result := 'click to pick, or drag a box   (Ctrl adds, Shift toggles)'
      else
        Result := Format('%d picked - M to move, Delete to remove',
          [Length(FSel)]);
    ptMove:
      if FStage = 0 then
        Result := 'grab a point on what you are moving'
      else if FMoveCopy then
        Result := 'where does the copy go?  a length, [x,y,z] or <x,y,z>'
      else
        Result := 'where does it go?  a length, [x,y,z] or <x,y,z>';
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
  I, J: Integer;
  P: TPointF;
  WasLine: Boolean;
  EA, EB: TP3;
begin
  case FTool of
    ptOrbit: ;   // the drag does the work

    ptSelect: ;   // the press and release do the work

    { Grab a point, then say where it goes.  Clicking on nothing with an
      empty selection picks up whatever is under the cursor first, so the
      tool works on its own without a trip to the arrow. }
    ptMove:
      if FStage = 0 then
      begin
        { Nothing picked and the cursor is sitting on a corner: take just that
          corner.  SketchUp calls this stretching, and it is how a box is
          pulled out of square without selecting anything first. }
        if (Length(FSel) = 0) and (FSnapKind = snEndpoint) then
        begin
          SetLength(FMoveVerts, 1);
          FMoveVerts[0] := FCur;
          FP1 := FCur;
          FStage := 1;
          FDirLock := -1;
          FInput := '';
          FCmdMsg := 'Stretching from that corner.  ' +
            'Click where it goes, or type a distance.';
          Exit;
        end;
        if Length(FSel) = 0 then
        begin
          I := PickAt(FMouseSX, FMouseSY);
          if I < 0 then
          begin
            FCmdMsg := 'Nothing there to move.';
            Exit;
          end;
          SelectOnly(I);
        end;
        FP1 := FCur;
        FD.Doc.VertsOf(FSel, FMoveVerts);
        FStage := 1;
        FDirLock := -1;
        FInput := '';
        FCmdMsg := 'Click where it goes, or type a distance.  ' +
          'Arrows lock an axis, Ctrl leaves a copy.';
      end
      else
        ProCommit;

    ptErase:
      begin
        { hit test where the pointer actually is - snapping to a nearby
          endpoint would otherwise make it miss the thing being clicked }
        P := PtF(FMouseSX, FMouseSY);
        I := FD.Doc.HitEdge(Proj, P.X, P.Y, 9 * FUIScale);
        if I < 0 then I := FD.Doc.HitTest(Proj, P.X, P.Y, 9 * FUIScale);
        if I >= 0 then
        begin
          PushUndo;
          { a line between two regions was holding them apart, so taking it
            away should leave one region rather than two that happen to touch }
          WasLine := FD.Doc[I].Kind in [ekLine, ekArc];
          EA := FD.Doc[I].A;
          EB := FD.Doc[I].B;
          FD.Doc.Delete(I);
          { taking a line away can join two areas into one, or leave a shape
            that no longer closes - both fall out of working the faces out
            again, so neither needs a rule of its own }
          J := FaceCount;
          if WasLine and (RebuildFlatFaces < J) then
            FCmdMsg := 'Deleted - the faces either side are one now.'
          else
            FCmdMsg := 'Deleted.';
          SelectNone;
          RenderPro;
          RecomposeAll;
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
      else if FClickN >= 2 then
      begin
        { Double-click lets go of the run.

          SketchUp does *not* do this - Tony checked, and there a second
          click just drops another point; you press Esc.  This is one of the
          few places worth being deliberately unlike it, because he asked for
          a way to let go with the mouse and the keyboard was the only one.

          The second click must not also place a point.  It lands in the same
          spot as the first, so committing it would leave a line of zero
          length on the drawing - geometry you cannot see, cannot click, and
          would find later as a stray snap point. }
        ResetTool;
        FCmdMsg := 'Line finished.  Esc does the same.';
      end
      else
        ProCommit;

    ptRect:
      if FStage = 0 then
      begin
        FP1 := FCur;
        FStage := 1;
        FInput := '';
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
        { "Double-click on any face, while in the Text tool, to display the
          area of the face as a Text entity." - and knowing the area of a
          panel is half the reason to draw one. }
        if FClickN >= 2 then
        begin
          I := FD.Doc.HitFace(Proj, FMouseSX, FMouseSY);
          if I >= 0 then
          begin
            PushUndo;
            FD.Doc.AddText(FCur,
              FormatArea(FD.Doc.FaceArea(I), FD.Units), FInkColor);
            RenderPro;
            RecomposeAll;
            FCmdMsg := 'Area ' + FormatArea(FD.Doc.FaceArea(I), FD.Units);
            Exit;
          end;
        end;
        FP1 := FCur;
        FStage := 1;
        FInput := '';
      end
      else
        ProCommit;

    ptPush:
      if FStage = 0 then
      begin
        { A double-click on another face repeats the last pull, which is how
          SketchUp does a row of identical extrusions. }
        if (FClickN >= 2) and (Abs(FLastPush) > 1E-9) then
        begin
          I := FD.Doc.HitFace(Proj, FMouseSX, FMouseSY);
          if I >= 0 then
          begin
            PushUndo;
            if FD.Doc.PushPull(I, FLastPush) then
            begin
              RenderPro;
              RecomposeAll;
              FCmdMsg := 'Same again - ' + FormatLen(Abs(FLastPush), FD.Units);
            end;
            Exit;
          end;
        end;
        FPushFace := FD.Doc.HitFace(Proj, FMouseSX, FMouseSY);
        { A face too small or too crowded to click can be picked with the
          arrow first and pushed afterwards, which the docs recommend. }
        if (FPushFace < 0) and (Length(FSel) = 1) and
           (FD.Doc[FSel[0]].Kind = ekFace) then
          FPushFace := FSel[0];
        if FPushFace < 0 then
          FCmdMsg := 'No face there.  Close a loop of lines to make one.'
        else
        begin
          FP1 := FCur;
          FPushSX := FMouseSX;
          FPushSY := FMouseSY;
          FStage := 1;
          if Abs(Dot3(FD.Doc.FaceNormal(FPushFace), ViewDir(Proj))) > 0.98 then
            FCmdMsg := 'Type a distance, or move and click.  ' +
              'Press V for a 3D view to watch it move.'
          else
            FCmdMsg := 'Type a distance, or move and click.';
        end;
      end
      else
        ProCommit;

    ptOffset:
      if FStage = 0 then
      begin
        FOffFace := FD.Doc.HitFace(Proj, FMouseSX, FMouseSY);
        { as with push/pull, a face too crowded to click can be selected
          first and then worked on }
        if (FOffFace < 0) and (Length(FSel) = 1) and
           (FD.Doc[FSel[0]].Kind = ekFace) then
          FOffFace := FSel[0];
        if FOffFace < 0 then
          FCmdMsg := 'No face there.  Close a loop of lines to make one.'
        else
        begin
          FStage := 1;
          FInput := '';
          FCmdMsg := 'Move in or out, or type a wall thickness.';
        end;
      end
      else
        CommitOffset;

    ptDim:
      case FStage of
        0:
          begin
            { "To take a dimension of a single line, simply click the line and
              move the cursor." - straight from their docs, and the thing you
              want nine times out of ten. }
            I := FD.Doc.HitEdge(Proj, FMouseSX, FMouseSY, 9 * FUIScale);
            if (I >= 0) and (FD.Doc[I].Kind in [ekLine, ekArc]) then
            begin
              FP1 := FD.Doc[I].A;
              FP2 := FD.Doc[I].B;
              FStage := 2;
              FCmdMsg := 'The whole edge, ' +
                FormatLen(Dist(FP1, FP2), FD.Units) +
                ' - move away to place the line.';
            end
            else
            begin
              FP1 := FCur;
              FStage := 1;
            end;
          end;
        1: begin FP2 := FCur; FStage := 2; end;
      else
        ProCommit;
      end;

    ptMeasure:
      if FStage = 0 then
      begin
        FP1 := FCur;
        { what the tape was started from decides which kind of guide the
          second click leaves: an edge gives a line parallel to it, anything
          else gives a point.  SketchUp's own rule. }
        FMeasEdge := FD.Doc.HitEdge(Proj, FMouseSX, FMouseSY, 9 * FUIScale);
        if (FMeasEdge >= 0) and
           not (FD.Doc[FMeasEdge].Kind in [ekLine, ekArc]) then
          FMeasEdge := -1;
        FStage := 1;
      end
      else if FStage = 1 then
      begin
        FP2 := FCur;
        FStage := 2;
        LayGuide;
        FCmdMsg := RunReading(FP1, FP2);
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

{ Why a typed measurement was not taken, in words worth reading, or '' when
  there is nothing wrong with it. }
function TMainForm.WhyNotAMeasurement(const S: string): string;
var
  T, LW, LH: string;
  P, NDash, Ix: Integer;
  D, CX, CY, CZ: Double;
  Fields: array[0..2] of string;
begin
  Result := '';
  T := Trim(S);
  if T = '' then Exit;

  { a place or an offset - the move and line tools read these }
  if (T[1] = '[') or (T[1] = '<') then
  begin
    if ParseTriple(T, FD.Units, CX, CY, CZ) > 0 then Exit;
    Result := 'That is not a place.  [4,0,8] is a point in the drawing, ' +
      '<4,0,8> is that far from here.';
    Exit;
  end;

  { two sides at once, which only the rectangle asks for }
  P := Pos('x', LowerCase(T));
  if P = 0 then P := Pos(',', T);
  if (P > 0) and (FTool = ptRect) then
  begin
    LW := Trim(Copy(T, 1, P - 1));
    LH := Trim(Copy(T, P + 1, MaxInt));
    if ((LW = '') or ParseLen(LW, FD.Units, D)) and
       ((LH = '') or ParseLen(LH, FD.Units, D)) and
       ((LW <> '') or (LH <> '')) then Exit;
    Result := 'Two sides, like 8x10 - or 8/10 from the number pad.';
    Exit;
  end;

  if ParseLen(T, FD.Units, D) then Exit;

  { The dashed form, wrong in the one way it is usually wrong: a last field
    that does not fit the precision the drawing is set to.  Saying which
    number is out of range, and what the drawing is counting in, is the
    difference between a refusal somebody can act on and one they cannot. }
  NDash := 0;
  Fields[0] := '';
  Fields[1] := '';
  Fields[2] := '';
  for Ix := 1 + Ord(T[1] = '-') to Length(T) do
    if T[Ix] = '-' then
    begin
      Inc(NDash);
      if NDash > 2 then Break;
    end
    else
      Fields[NDash] := Fields[NDash] + T[Ix];

  if (NDash = 2) and (Fields[2] <> '') and TryStrToFloat(Fields[2], D) and
     (D >= LenDenom) then
  begin
    Result := Format('The last number counts in 1/%d of an inch, so it has ' +
      'to be under %d - you typed %s.  Change PREC if this drawing is in ' +
      'something else.', [LenDenom, LenDenom, Fields[2]]);
    Exit;
  end;
  if (NDash = 2) and (Fields[1] <> '') and TryStrToFloat(Fields[1], D) and
     (D >= 12) then
  begin
    Result := 'The middle number is inches, so it has to be under 12.';
    Exit;
  end;

  Result := Format('I cannot read "%s" as a length.  Try 12, or 12''6", or ' +
    '3 1/2 - or feet-inches-1/%d like 6-8-15, which is six foot eight and ' +
    'fifteen %dths.', [T, LenDenom, LenDenom]);
end;

procedure TMainForm.ProCommit;
var
  I: Integer;
  T, C: TP3;
  Loop: TP3Array;
  L, R, A0, Sweep, Bulge, U1, V1, U2, V2, UC, VC, NU, NV, Ln: Double;
  Segs, K: Integer;
  Ok: Boolean;
begin
  Trail('commit ' + TOOL_NAMES[FTool] + ' stage=' + IntToStr(FStage));
  case FTool of
    ptOffset:
      begin
        CommitOffset;
        Exit;
      end;

    ptLine:
      begin
        T := PreviewTarget;
        if Dist(FP1, T) > 1E-9 then
        begin
          PushUndo;
          if FD.Doc.HasLine(FP1, T) then
            FCmdMsg := FormatLen(Dist(FP1, T), FD.Units) + '   (already an edge)'
          else
          begin
            FD.Doc.AddLine(FP1, T, FInkColor, FEdgeW, False);
            FCmdMsg := FormatLen(Dist(FP1, T), FD.Units);
          end;
          { Whatever this line did to the flat areas - closed a loop, cut a
            face in two, cut one of the halves again - is worked out by asking
            what the edges enclose, rather than by a rule per case. }
          I := FaceCount;
          K := RebuildFlatFaces;
          if K > I then
            FCmdMsg := FCmdMsg + Format('   %d face%s now',
              [K, IfThen(K = 1, '', 's')]);
          RenderPro;
          RecomposeAll;
          FP1 := T;
          FCur := T;
        end;
        FInput := '';
        FDirLock := -1;
      end;

    ptRect:
      begin
        T := RectTarget;
        RectSides(FP1, T, FD.Plane, U1, V1);
        if (U1 > 1E-9) and (V1 > 1E-9) then
        begin
          PushUndo;
          Loop := RectCorners(FP1, T, FD.Plane);
          { An edge that lands exactly on one already there is the same edge.
            Adding it again left two lines in the same place and two
            dimension labels on top of each other. }
          for I := 0 to 3 do
            if not FD.Doc.HasLine(Loop[I], Loop[(I + 1) mod 4]) then
              FD.Doc.AddLine(Loop[I], Loop[(I + 1) mod 4],
                FInkColor, FPenSize, False);
          RebuildFlatFaces;
          RenderPro;
          RecomposeAll;
          Trail('rect made, ' + IntToStr(FaceCount) + ' faces now');
          FCmdMsg := Format('%s x %s   area %s',
            [FormatLen(U1, FD.Units), FormatLen(V1, FD.Units),
             FormatArea(U1 * V1, FD.Units)]);
        end
        else
          FCmdMsg := 'A rectangle needs two sides.';
        ResetTool;
        FInput := '';
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
          FD.Doc.AddArc(C, R, A0, Sweep, FD.Plane, FInkColor, FEdgeW);
          FCmdMsg := 'Arc radius ' + FormatLen(R, FD.Units);
          I := FaceCount;
          if RebuildFlatFaces > I then
            FCmdMsg := FCmdMsg + '   closed a face';
          RenderPro;
          RecomposeAll;
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
          FD.Doc.AddArc(FP1, R, 0, 2 * Pi, FD.Plane, FInkColor, FEdgeW);
          RebuildFlatFaces;
          RenderPro;
          RecomposeAll;
          FCmdMsg := Format('Circle radius %s   area %s',
            [FormatLen(R, FD.Units), FormatArea(Pi * R * R, FD.Units)]);
        end;
        ResetTool;
      end;

    ptMove:
      begin
        T := MoveDelta;
        if (Abs(T.X) > 1E-9) or (Abs(T.Y) > 1E-9) or (Abs(T.Z) > 1E-9) then
        begin
          PushUndo;
          if FMoveCopy then
          begin
            { a copy stands on its own, so nothing gets stretched to reach it }
            FD.Doc.Duplicate(FSel, T);
            FCmdMsg := 'Copied ' + FormatLen(
              Sqrt(Sqr(T.X) + Sqr(T.Y) + Sqr(T.Z)), FD.Units);
          end
          else
          begin
            { every corner that sits where a moving one sat travels too, so
              whatever was joined on stretches to follow }
            FD.Doc.MoveVerts(FMoveVerts, T);
            FCmdMsg := 'Moved ' + FormatLen(
              Sqrt(Sqr(T.X) + Sqr(T.Y) + Sqr(T.Z)), FD.Units);
          end;
          { moving an edge changes what the edges enclose, so the flat areas
            are worked out again - which is also what stretches a face to
            follow the edge that moved }
          RebuildFlatFaces;
          RenderPro;
          RecomposeAll;
        end;
        SetLength(FMoveVerts, 0);
        FMoveCopy := False;
        ResetTool;
        FInput := '';
      end;

    ptPush:
      begin
        R := PushDistance;
        if Abs(R) > 1E-9 then
        begin
          PushUndo;
          if FD.Doc.PushPull(FPushFace, R) then
          begin
            FLastPush := R;      // so a double-click can repeat it
            SelectNone;
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
        { Nothing typed yet is not a note to add, and it is not a reason to
          put the tool away either.

          It used to reset regardless, and resetting goes back to stage nought
          - where the tool is waiting to be told what the note is about, and
          every letter is a tool shortcut again.  So one stray second click,
          or a mouse that bounced, or Enter pressed a moment early, and typing
          the note started picking tools instead.  Which is exactly what it
          looked like: the keyboard had gone mad, when in fact the note had
          been quietly finished before it began. }
        if Trim(FInput) = '' then
        begin
          FCmdMsg := 'Type the note first, then move away and press Enter.';
          Exit;
        end;
        begin
          PushUndo;
          { FP1 is what the note is about; the cursor is where the note goes.
            Leave the cursor where you clicked and the two are the same point,
            which is a plain label with no leader - what a note has always
            been.  Move away first and you get the leader. }
          FD.Doc.AddNote(FCur, FP1, Trim(FInput), FInkColor);
          RenderPro;
          RecomposeAll;
          if Dist(FCur, FP1) > 1E-9 then
            FCmdMsg := 'Note added, pointing at where you started.'
          else
            FCmdMsg := 'Note added.  Next time, move away before Enter for ' +
              'a leader line.';
        end;
        ResetTool;
      end;

    ptDim:
      begin
        if Dist(FP1, FP2) > 1E-9 then
        begin
          PushUndo;
          FD.Doc.AddDim(FP1, FP2, FInkColor, DimOffset3);
          RenderPro;
          RecomposeAll;
          FCmdMsg := 'Dimension ' + FormatLen(Dist(FP1, FP2), FD.Units);
        end;
        ResetTool;
      end;

    ptMeasure:
      begin
        if FStage = 2 then
        begin
          PushUndo;
          FD.Doc.AddDim(FP1, FP2, FInkColor, DimOffset3);
          RenderPro;
          RecomposeAll;
          FCmdMsg := 'Kept as a dimension.';
        end;
        ResetTool;
      end;
    ptSelect, ptErase, ptOrbit: ;   // these act on the drag; nothing to commit
  end;
  pbScreen.Invalidate;
  pbCmd.Invalidate;
  pbDeck.Invalidate;
  FLastStatus := 0;
  InvalidateStatus;
end;

{ What a run measures, in the terms the trade uses.

  Length and the three components were already there.  The two angles are the
  ones a fitter needs and neither can be read off the components in the head:

  * the **fall** - how far off horizontal the run is.  Nought is dead level,
    ninety is a riser.  This is the one that says whether a run is truly
    level, and reading 44.98 rather than 45 is the difference between a
    fitting that goes in and one that comes back.
  * the **swing** - which way it heads in plan, measured round from the red
    axis.  For a rolling offset the two together are the whole description.

  Both to two decimals, because 45 and 22.5 are the numbers the trade is cut
  to and rounding to the nearest degree hides exactly the error worth seeing. }
function TMainForm.RunReading(const A, B: TP3): string;
var
  DX, DY, DZ, Flat, Fall, Swing: Double;
begin
  DX := B.X - A.X;
  DY := B.Y - A.Y;
  DZ := B.Z - A.Z;
  Result := Format('%s   (dX %s  dY %s  dZ %s)',
    [FormatLen(Dist(A, B), FD.Units), FormatLen(Abs(DX), FD.Units),
     FormatLen(Abs(DY), FD.Units), FormatLen(Abs(DZ), FD.Units)]);

  Flat := Sqrt(DX * DX + DY * DY);
  if (Flat < 1E-9) and (Abs(DZ) < 1E-9) then Exit;

  if Flat < 1E-9 then
    Result := Result + '   straight up'
  else
  begin
    Fall := RadToDeg(ArcTan2(DZ, Flat));
    Swing := RadToDeg(ArcTan2(DY, DX));
    if Swing < 0 then Swing := Swing + 360;
    if Abs(Fall) < 1E-4 then
      Result := Result + '   level'
    else
      Result := Result + Format('   %.2f' + #176 + ' off level',
        [Abs(Fall)]);
    Result := Result + Format(',  %.2f' + #176 + ' round', [Swing]);
  end;
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
  else if (W = 'orbit') or (W = 'spin') then SetTool(ptOrbit)
  else if (W = 'rect') or (W = 'rectangle') or (W = 'r') then SetTool(ptRect)
  else if (W = 'measure') or (W = 'm') or (W = 'tape') then SetTool(ptMeasure)
  else if (W = 'dimension') or (W = 'dim') then SetTool(ptDim)
  else if (W = 'offset') or (W = 'f') then SetTool(ptOffset)
  else if (W = 'update') or (W = 'upgrade') then
  begin
    if Rest = 'never' then
    begin
      with TIniFile.Create(ConfigFile) do
      try
        WriteBool('update', 'check', False);
      finally
        Free;
      end;
      FCmdMsg := 'It will not look for updates again.  /update still works ' +
        'when you ask it to.';
    end
    else if Rest = 'always' then
    begin
      with TIniFile.Create(ConfigFile) do
      try
        WriteBool('update', 'check', True);
      finally
        Free;
      end;
      FCmdMsg := 'It will look once a day again.';
    end
    else
      DoUpdate;
  end
  else if W = 'version' then FCmdMsg := 'Heckers Sketch ' + CurrentVersion
  else if (W = 'push') or (W = 'pull') or (W = 'pushpull') or (W = 'p') then
    SetTool(ptPush)
  else if (W = 'undo') or (W = 'u') then DoUndo
  else if W = 'redo' then DoRedo
  else if (W = 'fit') or (W = 'zoom') then FitView
  else if W = 'view' then CycleViewPreset(1)
  else if (W = 'top') or (W = 'down') then ApplyViewPreset(10)
  else if W = 'front' then ApplyViewPreset(6)
  else if W = 'right' then ApplyViewPreset(7)
  else if W = 'back' then ApplyViewPreset(8)
  else if W = 'left' then ApplyViewPreset(9)
  else if W = 'corner' then ApplyViewPreset(2)
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
  else if W = 'regions' then ReportRegions
  else if W = 'rebuild' then
  begin
    PushUndo;
    I := RebuildFlatFaces;
    RenderPro;
    RecomposeAll;
    FCmdMsg := Format('Worked the faces out again: %d.', [I]);
  end
  else if (W = 'guides') or (W = 'noguides') then
  begin
    { SketchUp's Edit > Delete Guides.  They are aids, and a drawing that has
      been laid out collects a lot of them. }
    I := FD.Doc.GuideCount;
    if I = 0 then
      FCmdMsg := 'No guides to clear.'
    else
    begin
      PushUndo;
      FD.Doc.ClearGuides;
      RenderPro;
      RecomposeAll;
      FCmdMsg := Format('Cleared %d guide%s.', [I, IfThen(I = 1, '', 's')]);
    end;
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
  Why: string;
begin
  if FDimEdit >= 0 then
  begin
    CommitDimNote;
    pbCmd.Invalidate;
    Exit;
  end;

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

  { Not every entry is a plain length: a rectangle takes 8',20' or 6',, and
    move and line take [x,y,z] and <x,y,z>.  Anything that starts like a
    measurement belongs to the tool, which knows what to make of it.  Bare
    words still fall through to the command list below. }
  if (FStage > 0) and (FInput <> '') and
     (FInput[1] in ['0'..'9', '-', '.', '[', '<', ',', 'x', 'X']) then
  begin
    { A number that could not be read is not the same as no number.

      It used to be the same: an entry that would not parse simply left the
      cursor where it was and the tool committed there, so a mistyped length
      quietly became a shape of the wrong size and nothing was said about it.

      It is also the one moment where the dashed form can explain itself.
      Most people have never met truss notation, and the place to learn that
      6-8-15 exists is when your own number has just been turned down. }
    Why := WhyNotAMeasurement(FInput);
    if Why <> '' then
    begin
      FCmdMsg := Why;
      pbCmd.Invalidate;
      pbScreen.Invalidate;
      Exit;
    end;
    ProCommit;
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
var
  I, Which: Integer;
begin
  { a press supersedes whatever motion has not been serviced yet }
  FMoveX := X;
  FMoveY := Y;
  FMovePending := False;
  FMoveShift := Shift;

  { An open list has the canvas, and has it before anything else does.

    A list is drawn over the drawing, so a press on one of its rows arrives
    here as a press on the drawing, and whichever branch below claimed it
    first got it.  The orbit tool claims a plain left press so that laptops
    without a middle button can still spin the model - and it claimed it
    ahead of this, so with orbit in hand every row of the help list started
    an orbit instead: About, the manual, report a problem, none of them could
    be clicked at all.  Middle and right did the same.

    The rule is the one the motion handler already follows - while a list is
    open the canvas is not the canvas - and it belongs at the top where no
    tool can get in front of it.  Any button dismisses the list; only a left
    press on a row chooses it, so a right-click to get out cannot pick
    something on the way. }
  if FPopup <> POP_NONE then
  begin
    Which := FPopup;
    I := -1;
    if Button = mbLeft then I := PopupItemAt(X, Y);
    { Shut before acting, not after.  Some of these rows put a panel up and
      do not return until it is dismissed, and the list was still open the
      whole time it was showing - so About came up with the help menu still
      painted over the corner of it.  A list has done its job the moment a
      row is picked. }
    ClosePopup;
    if I >= 0 then PopupChoose(Which, I);
    Exit;
  end;

  { Laptops without a middle button need a way in, so the tool turns a plain
    left drag into the same thing. }
  if (Button = mbLeft) and (FMode = mdPro) and (FTool = ptOrbit) then
  begin
    FOrbiting := FD.View = vkOrbit;
    FPanning := not FOrbiting;
    FPanRefX := X;
    FPanRefY := Y;
    FOrbitPivot := PivotAt(X, Y);
    AnchorOrbit(X, Y);
    FMoveShift := Shift;
    pbScreen.Cursor := crSizeAll;
    Exit;
  end;

  if Button in [mbMiddle, mbRight] then
  begin
    if FMode = mdPro then
    begin
      { Middle-drag orbits, whatever tool is in hand and whatever view you
        are in - SketchUp lets you spin the model round mid-line and so does
        this, because that is exactly when you need to see round the back of
        something.  Nothing about the operation in progress is touched.

        From PLAN or ISO it drops into the free camera first, aimed where you
        were already looking so the model does not jump.  That is SketchUp's
        behavior too: orbiting out of a standard view leaves it. }
      if Button = mbMiddle then
      begin
        EnterFreeCamera;
        FCmdMsg := '3D view - drag to spin.  V goes back.';
      end;
      FOrbiting := (Button = mbMiddle) and (FD.View = vkOrbit);
      FPanning := not FOrbiting;
      FPanRefX := X;
      FPanRefY := Y;
      FRightSX := X;
      FRightSY := Y;
      FOrbitPivot := PivotAt(X, Y);
      AnchorOrbit(X, Y);
      FMoveShift := Shift;
      pbScreen.Cursor := crSizeAll;
    end
    else if Button = mbRight then
      FPenUp := True;
    Exit;
  end;
  if Button <> mbLeft then Exit;

  { a click on the drawing dismisses an open list, and is taken by it if it
    landed on one of the rows }
  if FMode = mdPro then
  begin
    FMouseSX := X;
    FMouseSY := Y;
    { waiting to be told which piece to lay out - that click, and no other }
    if FUnfoldPick then
    begin
      UnfoldAt(X, Y);
      Exit;
    end;
    { the eraser gathers while the button is held and deletes on release }
    if FTool = ptErase then
    begin
      FErasing2 := True;
      SetLength(FDoomed, 0);
      DoomAt(X, Y);
      FScreenDirty := True;
      Exit;
    end;
    { the arrow starts a box; a press that never travels is read as a click
      when the button comes back up }
    if (FTool = ptMove) and (FStage = 1) then
      FMoveCopy := ssCtrl in Shift;

    if (GetTickCount64 - FClickT < 450) and (Abs(X - FClickX) < 5) and
       (Abs(Y - FClickY) < 5) then
      Inc(FClickN)
    else
      FClickN := 1;
    FClickT := GetTickCount64;
    FClickX := X;
    FClickY := Y;

    if FTool = ptSelect then
    begin
      { Press on a note's box and you are moving the note, not starting a
        box-select.  Only the box moves; what it points at stays where it is,
        which is the whole use of a leader - you drag the words out of the
        way of the drawing without losing what they are about. }
      FNoteDrag := FD.Doc.HitNote(X, Y);
      if FNoteDrag >= 0 then
      begin
        PushUndo;
        FNoteFrom := FD.Doc[FNoteDrag].A;
        FNoteGrab := WorldAt(X, Y);
        FCmdMsg := 'Moving the note.  Let go to drop it.';
        pbCmd.Invalidate;
        Exit;
      end;
      FBoxing := True;
      FBoxX := X;
      FBoxY := Y;
      FScreenDirty := True;
      Exit;
    end;
    FCur := ResolveSnapAt(X, Y);
    Trail(Format('press %s stage=%d at %d,%d  world %s,%s,%s  snap=%d',
      [TOOL_NAMES[FTool], FStage, X, Y,
       FormatLen(FCur.X, FD.Units), FormatLen(FCur.Y, FD.Units),
       FormatLen(FCur.Z, FD.Units), Ord(FSnapKind)]));
    { A run of lines is the one case where the press does not decide.  It
      might be a click - another point - or it might be a hold, which lets go
      of the run and places nothing.  Which one it was is not known until the
      button comes up, or until it has been held long enough to break. }
    if (FTool in [ptLine, ptRect, ptCircle, ptArc]) and (FStage >= 1) then
    begin
      FHoldOn := True;
      FHoldT := 0;
      FHoldX := X;
      FHoldY := Y;
      Exit;
    end;
    ProClick;
    Exit;
  end;

  FFreehand := True;
  BeginStroke;
  FPenX := EnsureRange(X, 0, FArt.Width - 1);
  FPenY := EnsureRange(Y, 0, FArt.Height - 1);
  FScreenDirty := True;
end;

{ An unhandled exception used to be a message box saying "Access violation"
  and nothing else, which is unactionable from the other end of a phone.  The
  class, the message and the call stack go next to the executable instead, so
  a crash can be reported by sending one small text file.  Written before the
  dialog is shown, in case the dialog is what fails. }
procedure TMainForm.Trail(const S: string);
begin
  FTrail[FTrailN mod Length(FTrail)] :=
    FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + S;
  Inc(FTrailN);
end;

function TMainForm.TrailText: string;
var
  I, First, N: Integer;
begin
  Result := '';
  N := FTrailN;
  if N > Length(FTrail) then N := Length(FTrail);
  First := FTrailN - N;
  for I := First to FTrailN - 1 do
    Result := Result + '  ' + FTrail[I mod Length(FTrail)] + LineEnding;
end;

function TMainForm.KindCounts: string;
const
  NAMES: array[TEntKind] of string =
    ('lines', 'arcs', 'notes', 'dims', 'faces', 'guides');
var
  N: array[TEntKind] of Integer;
  K: TEntKind;
  I: Integer;
begin
  for K := Low(TEntKind) to High(TEntKind) do N[K] := 0;
  for I := 0 to FD.Doc.Live - 1 do
    Inc(N[FD.Doc[I].Kind]);
  Result := '';
  for K := Low(TEntKind) to High(TEntKind) do
    if N[K] > 0 then
    begin
      if Result <> '' then Result := Result + ', ';
      Result := Result + IntToStr(N[K]) + ' ' + NAMES[K];
    end;
  if Result = '' then Result := 'empty';
end;

procedure TMainForm.SaveCrashDoc(const ReportPath: string);
var
  L: TStringList;
begin
  try
    L := TStringList.Create;
    try
      BuildSession(L);
      L.SaveToFile(ReportPath + '.hsk');
    finally
      L.Free;
    end;
  except
    { the drawing could not be written out; the report still stands }
  end;
end;

function TMainForm.DiagnosticText: string;
begin
  { Names, not numbers.  A report that says tool=8 needs the source open to
    read it; one that says ERASE does not.  Nothing here is about the person
    or the machine - it is what the program was doing. }
  Result :=
    Format('tool=%s stage=%d view=%s plane=%s mode=%s', [TOOL_NAMES[FTool],
      FStage, VIEW_NAMES[FD.View], PlaneName,
      specialize IfThen<string>(FMode = mdPro, 'PRO', 'TOY')]) + LineEnding +
    Format('mouse=%d,%d  cursor=%s,%s,%s  snap=%d axislock=%d held=%d',
      [FMouseSX, FMouseSY, FormatLen(FCur.X, FD.Units),
       FormatLen(FCur.Y, FD.Units), FormatLen(FCur.Z, FD.Units),
       Ord(FSnapKind), FAxisLock, Ord(FPlaneHeld)]) + LineEnding +
    Format('entities=%d (%s)  sheets=%d tab=%d  selected=%d doomed=%d',
      [FD.Doc.Live, KindCounts, Length(FDrawings), FTabIdx,
       Length(FSel), Length(FDoomed)]) + LineEnding +
    Format('pushface=%d offface=%d hoverent=%d hoverface=%d lock=%d ' +
      'holding=%d scale=%s snapstep=%s zoom=%s',
      [FPushFace, FOffFace, FHoverEnt, FHoverFace, Ord(FLockOn),
       Ord(FHoldOn), CurScale.Name, FormatLen(SnapStep, FD.Units),
       FormatFloat('0.00', FD.Zoom)]) + LineEnding +
    Format('units=%s screen=%dx%d scaling=%s portable=%s net=%s',
      [uWork.UnitName(FD.Units), pbScreen.Width, pbScreen.Height,
       FormatFloat('0.00', FUIScale),
       specialize IfThen<string>(IsPortable, 'yes', 'no'),
       NetBackend]) + LineEnding +
    { Where the camera was standing.  A report that says a drawing looks wrong
      at this angle is only reproducible if the angle comes with it - and
      several have now turned on exactly that. }
    Format('camera az=%.2f el=%.2f zoom=%.3f at %.1f,%.1f',
      [RadToDeg(FD.Az), RadToDeg(FD.El), FD.Zoom, FD.ViewX, FD.ViewY]) +
      LineEnding +
    { The surfaces, because two crashes running have been in the compositor
      and the question both times was whether these four still agree with
      each other and with the window.  Cheap to carry, and it turns the next
      report of this into an answer instead of another round of guessing. }
    Format('art=%dx%d/%d paper=%dx%d/%d inkpro=%dx%d/%d inktoy=%dx%d/%d ' +
      'repairs=%d',
      [FArt.Width, FArt.Height, FArt.Stride,
       FPaper.Width, FPaper.Height, FPaper.Stride,
       FInkPro.Width, FInkPro.Height, FInkPro.Stride,
       FInkToy.Width, FInkToy.Height, FInkToy.Stride,
       TArtSurface.Repairs]) + LineEnding +
    'what was happening, most recent last:' + LineEnding + TrailText;
end;

{ Put everything down.

  Whatever threw was almost certainly reached from a tool part way through
  something, or from a hover index pointing at something that is no longer
  there.  Reporting the fault and then leaving all of that exactly as it was
  is why one exception turned into a wall of them: the box is dismissed,
  control goes back to the message loop, the mouse moves a pixel, and the
  very same code runs again on the very same state.  You could dismiss it all
  afternoon.

  So the tool is put down, the run in progress abandoned, and everything
  transient cleared, before anybody is asked anything.  The drawing is not
  touched - only the business of the moment, which is the part that has just
  been shown not to work. }
procedure TMainForm.Quiesce;
begin
  try
    FMovePending := False;
    FOrbiting := False;
    FPanning := False;
    FErasing2 := False;
    FFreehand := False;
    FHoldOn := False;
    FHoldT := 0;
    FPushFace := -1;
    FOffFace := -1;
    SetLength(FSel, 0);
    SetLength(FDoomed, 0);
    ResetTool;
    if pbScreen <> nil then pbScreen.Cursor := crCross;
  except
    { it is already having a bad day }
  end;
end;

procedure TMainForm.ReportCrash(Sender: TObject; E: Exception);
var
  F: TextFile;
  Path: string;
  I: Integer;
  Now64: QWord;
begin
  Quiesce;

  { Three in half a minute and it is not an incident, it is a state.  Past
    that, stop writing files and stop putting a box in the way: each report
    costs a screenshot and a disk write, and each box is one more thing
    between the person and the Ctrl+S they actually need.  The count forgets
    itself after a quiet half minute. }
  Now64 := GetTickCount64;
  if (FWoundCount > 0) and (Now64 - FWoundAt > 30000) then FWoundCount := 0;
  FWoundAt := Now64;
  Inc(FWoundCount);
  if FWoundCount > 3 then
  begin
    FCmdMsg := 'Still failing.  Save with Ctrl+S and restart - the reports ' +
      'are already written.';
    if pbCmd <> nil then pbCmd.Invalidate;
    Exit;
  end;

  Path := ExtractFilePath(ParamStr(0)) + CRASH_LOG;
  try
    AssignFile(F, Path);
    if FileExists(Path) then Append(F) else Rewrite(F);
    try
      WriteLn(F, '---- ', DateTimeToStr(Now), ' ', APP_NAME, ' ',
    CurrentVersion, ' built ', BUILD_STAMP);
      WriteLn(F, E.ClassName, ': ', E.Message);
      Write(F, DiagnosticText);
      WriteLn(F, BackTraceStrFunc(ExceptAddr));
      if ExceptFrameCount > 0 then
        for I := 0 to ExceptFrameCount - 1 do
          WriteLn(F, BackTraceStrFunc(ExceptFrames[I]));
      WriteLn(F);
    finally
      CloseFile(F);
    end;
    { And the drawing itself, beside the report.  Nikki's crash is the same
      drawing every time, and no amount of addresses and state will find it
      as fast as having the thing that does it.  Written under its own name
      so one crash does not overwrite the last one's evidence. }
      SaveCrashDoc(Path);
    { and what the drawing area looked like when it went.  Kept here only -
      whether any of it is sent is asked next time the program starts. }
    try
      FArt.SaveToPNG(Path + '.png');
    except
    end;
    { One more than last time.  A single crash says nothing about the drawing
      - it can be anything - but a second one straight after it, having
      opened the same drawing again, says the drawing is at least involved,
      and a third says stop.  Cleared on any clean exit, so this only ever
      counts crashes with nothing good in between. }
    try
      with TIniFile.Create(ConfigFile) do
      try
        WriteInteger('startup', 'crashes',
          ReadInteger('startup', 'crashes', 0) + 1);
      finally
        Free;
      end;
    except
    end;
  except
    { a crash reporter that crashes helps nobody }
  end;
  if FWoundCount >= 3 then
    MessageDlg(APP_NAME,
      'That is the third time in a minute.' + LineEnding + LineEnding +
      'Something is wrong that dismissing this will not fix.  Save what you ' +
      'have with Ctrl+S and start the program again - it will offer to send ' +
      'the reports, and they are what gets this mended.' + LineEnding +
      LineEnding +
      'It will stop interrupting you now.  Everything it has been asked to ' +
      'write is already written.',
      mtError, [mbOK], 0)
  else
    MessageDlg(APP_NAME,
      E.ClassName + ': ' + E.Message + LineEnding + LineEnding +
      'Written next to the program:' + LineEnding +
      '  ' + ExtractFileName(Path) + '   - what happened' + LineEnding +
      '  ' + ExtractFileName(Path) + '.hsk   - the drawing it happened to' +
      LineEnding + LineEnding +
      'Both together say exactly where this went wrong.  The drawing is ' +
      'your own work, so have a look before sending it anywhere.',
      mtError, [mbOK], 0);
end;

{ Motion handler: record and return.  Nothing here may paint, allocate,
  hit-test or snap.  See ServiceMotion, which the tick calls. }
procedure TMainForm.pbScreenMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  FMoveX := X;
  FMoveY := Y;
  FMoveShift := Shift;
  FMovePending := True;
end;

{ Everything the motion handler used to do, run at most once per tick off
  the newest pointer position.  Coalescing here is free: the intermediate
  positions only ever fed a repaint that was immediately overdrawn. }
procedure TMainForm.ServiceMotion;
var
  X, Y, HF: Integer;
  HP, HN: TP3;
  OP: TPointF;
  NewAz, NewEl: Double;
begin
  if not FMovePending then Exit;
  FMovePending := False;
  X := FMoveX;
  Y := FMoveY;

  { An open list takes the mouse, and nothing else gets it.

    The row under the cursor was never worked out - the field for it existed
    and the paint code knew how to light a row, but nothing ever set it, so
    no row ever lit.  Meanwhile the drawing carried on snapping and inferring
    underneath, which is what made a list opened over the drawing feel like
    two things fighting for the pointer.  A menu that will not say which row
    you are about to press is a menu you have to aim at twice. }
  if FPopup <> POP_NONE then
  begin
    FMouseSX := X;
    FMouseSY := Y;
    HF := PopupItemAt(X, Y);
    if HF <> FPopupHot then
    begin
      FPopupHot := HF;
      FScreenDirty := True;
      pbScreen.Invalidate;
    end;
    Exit;
  end;

  { a held eraser collects whatever it is dragged across }
  if FErasing2 then
  begin
    FMouseSX := X;
    FMouseSY := Y;
    DoomAt(X, Y);
    InvalidateStatus;
    Exit;
  end;

  { Middle drag orbits, and holding Shift pans instead - tested every move
    rather than only when the button went down, so you can grab Shift part
    way through an orbit the way you would in SketchUp. }
  if FOrbiting or FPanning then
  begin
    if FOrbiting and not (ssShift in FMoveShift) then
    begin
      { Drag right and the model follows the cursor round, the way it does
        when you push something on a turntable - the azimuth goes the other
        way to the drag.  It used to follow the drag, which reads as the
        model running away from you. }
      { DO NOT fold these back into
          FD.El := EnsureRange(FD.El + (Y - FPanRefY) * 0.010, -1.45, 1.45);
        however much it wants to be written that way.

        At -O3 this compiler generates that statement with the read of FD.El
        through the register holding the drawing and the write through the
        register holding (Y - FPanRefY), so the new angle is stored at an
        address near zero and the program faults.  Every time, on any orbit
        at all.  The debug build does not optimize and never showed it, which
        is what said compiler rather than program.

        The store went out through the register holding (Y - FPanRefY)
        while the read came in through the register holding the drawing, so
        the angle was written to an address near zero.  Correct at -O2 and
        below, wrong at -O3 and -O4, on 3.3.1-20630-gd1530435e2.  Reported
        upstream with a reproducer.

        Working the angles out into locals first is the workaround.  It costs
        nothing and it is the only thing standing between this line and the
        fault. }
      NewAz := FD.Az - (X - FPanRefX) * 0.010;
      NewEl := FD.El + (Y - FPanRefY) * 0.010;
      if NewEl < -1.45 then NewEl := -1.45;
      if NewEl > 1.45 then NewEl := 1.45;
      FD.Az := NewAz;
      FD.El := NewEl;
      FViewPreset := -1;
      { Hold the grabbed point still, so the view turns about it rather than
        about the origin.

        The pivot was worked out when the button went down, at the old angle,
        and it is asked for its screen position here at the new one - so a
        point that was reasonable a moment ago can project anywhere once the
        camera has moved.  If it comes back as something that is not a screen
        position, the view keeps the offset it had and turns about the origin
        for that frame, which is a worse orbit and a perfectly good one.  The
        alternative is adding a few million to where the drawing is held, and
        every rounding from there to the screen inherits it. }
      if FOrbitAnchored then
      begin
        OP := ScreenOf(FOrbitPivot);
        if (not (IsNan(OP.X) or IsNan(OP.Y) or
                 IsInfinite(OP.X) or IsInfinite(OP.Y))) and
           (Abs(OP.X) < 1E6) and (Abs(OP.Y) < 1E6) then
        begin
          FD.ViewX := FD.ViewX + (FOrbitAnchor.X - OP.X);
          FD.ViewY := FD.ViewY + (FOrbitAnchor.Y - OP.Y);
        end;
      end;
      RepaintPaper;
      RenderPro;
      RecomposeAll;
      Invalidate;
    end
    else
      PanBy(X - FPanRefX, Y - FPanRefY);
    FPanRefX := X;
    FPanRefY := Y;
    Exit;
  end;

  if FMode = mdPro then
  begin
    FMouseSX := X;
    FMouseSY := Y;
    { holding Ctrl part way through a move turns it into a copy, and the
      ghost changes color to say so }
    if (FTool = ptMove) and (FStage = 1) then
      FMoveCopy := ssCtrl in FMoveShift;
    { Point at a face and draw on it.  Before this the plane came only from a
      key, so a square drawn on the top of a box was really being drawn on
      the ground and merely looked right - and push/pull then took the box's
      whole top, because that is what was actually under the cursor. }
    { In the 3D view a new shape started in mid air begins flat, every time.
      The plane used to be left wherever the last shape put it, so after
      standing one rectangle up the next one stood up too - which is the
      "sometimes it draws flat, sometimes up and down" that made this
      unpredictable.  Now the ground is always the default and the drag is
      what lifts it.

      Isometric is left alone deliberately.  It is a drafting view - iso
      paper for a pipe spool - where the plane is something you choose with
      K or the arrow keys and then keep, not something the mouse guesses at.
      Guessing there would fight the drawing rather than help it. }
    ShakeWatch(X, Y);

    { carrying a note by its box }
    if FNoteDrag >= 0 then
    begin
      FMouseSX := X;
      FMouseSY := Y;
      FD.Doc.MoveNote(FNoteDrag, FNoteFrom, WorldAt(X, Y), FNoteGrab);
      RenderPro;
      RecomposeAll;
      FScreenDirty := True;
      InvalidateStatus;
      Exit;
    end;

    { a hand that has moved has let go of whatever it was resting on }
    if FNoLockUntilMoved and
       ((Abs(X - FHoldX) > 6) or (Abs(Y - FHoldY) > 6)) then
      FNoLockUntilMoved := False;

    if FStage = 0 then FPlaneFromFace := False;
    if (FStage = 0) and not FPlaneHeld and (FD.View = vkOrbit) then
      FD.Plane := plXY;
    if (FStage = 0) and not FPlaneHeld and
       (FTool in [ptLine, ptRect, ptCircle, ptArc]) and
       FD.Doc.FaceUnder(Proj, X, Y, HF, HP) then
    begin
      HN := FD.Doc.FaceNormal(HF);
      { A face square to an axis gets the matching flat plane, because those
        have their own quick arithmetic and their own colour.  Anything else -
        a roof, a hopper side, a transition - gets a plane of its own, taken
        from the face itself.  Without that last line a circle could only be
        put on something square to an axis, and every slope in the trade was
        out of reach. }
      if Abs(HN.Z) > 0.999 then FD.Plane := plXY
      else if Abs(HN.Y) > 0.999 then FD.Plane := plXZ
      else if Abs(HN.X) > 0.999 then FD.Plane := plYZ
      else
      begin
        SetFreePlane(HP, HN);
        FD.Plane := plFree;
      end;
      { the plane passes through where the cursor meets the face, so the
        shape sits on the surface rather than at the old height }
      FCur := HP;
      FFacePt := HP;
      FFaceNm := Norm3(HN);
      FPlaneFromFace := True;
    end;

    { Drawing in mid air, with the first point already down: let the way the
      mouse moves decide whether the shape lies flat or stands up, which is
      what SketchUp appears to do and what makes a rectangle in space usable
      at all.  It has to run before the snap resolves, because the plane is
      what turns the cursor into a model point.

      Three things hold it back from being annoying.  A face under the first
      point wins outright.  An arrow-key lock wins outright.  And nothing is
      decided until the drag is worth reading - under about a sixth of an
      inch it is a twitch, not a direction. }
    if (FStage >= 1) and not FPlaneHeld and not FPlaneFromFace and
       (FD.View = vkOrbit) and
       (FTool in [ptLine, ptRect, ptCircle, ptArc]) then
    begin
      OP := ScreenOf(FP1);
      if Sqr(X - OP.X) + Sqr(Y - OP.Y) >= Sqr(14 * FUIScale) then
        FD.Plane := PlaneByDrag(Proj, FP1, X, Y, FD.Plane);
    end;

    FCur := ResolveSnapAt(X, Y);

    { Snapping to a corner is not the same as being inside a face, so the
      plane used to stay at whatever it was and the shape landed somewhere
      else entirely - which is how arcs ended up behind the box.  A snapped
      point that belongs to a face adopts that face's plane too. }
    if (FStage = 0) and not FPlaneHeld and
       (FTool in [ptLine, ptRect, ptCircle, ptArc]) and
       (FSnapKind in [snEndpoint, snCross, snMidpoint, snSubMid]) then
    begin
      HF := FD.Doc.FaceThrough(FCur);
      if HF >= 0 then
      begin
        HN := FD.Doc.FaceNormal(HF);
        if Abs(HN.Z) > 0.999 then FD.Plane := plXY
        else if Abs(HN.Y) > 0.999 then FD.Plane := plXZ
        else if Abs(HN.X) > 0.999 then FD.Plane := plYZ
        else
        begin
          SetFreePlane(FCur, HN);
          FD.Plane := plFree;
        end;
        FPlaneFromFace := True;
      end;
    end;

    if FTool = ptErase then
    begin
      { The same order the click uses, so what lights up is what goes.  It
        used to hover by HitTest alone, which cannot find the inside of a
        face - so sweeping across a panel showed nothing and then deleted it
        anyway, which is the wrong way round for a tool that destroys things. }
      FHoverEnt := FD.Doc.HitNote(X, Y);
      if FHoverEnt < 0 then
        FHoverEnt := FD.Doc.HitEdge(Proj, X, Y, 9 * FUIScale);
      if FHoverEnt < 0 then FHoverEnt := FD.Doc.HitFace(Proj, X, Y);
      if FHoverEnt < 0 then
        FHoverEnt := FD.Doc.HitTest(Proj, X, Y, 9 * FUIScale);
    end
    else if (FTool = ptSelect) and not FBoxing then
      FHoverEnt := PickAt(X, Y)
    else if (FTool = ptDim) and (FStage = 0) then
    begin
      { Hover an edge and it lights up; one click then dimensions the whole
        of it.  This is the half of SketchUp's dimension tool that makes the
        rest of it make sense - without it there is no way to tell whether
        the click is going to take the edge or start a point-to-point. }
      FHoverEnt := FD.Doc.HitEdge(Proj, X, Y, 9 * FUIScale);
      if (FHoverEnt >= 0) and
         not (FD.Doc[FHoverEnt].Kind in [ekLine, ekArc]) then
        FHoverEnt := -1;
    end
    else
      FHoverEnt := -1;
    { what push/pull would pick up if you clicked now.  Without this the tool
      looks broken: the click works, but nothing ever says a face was under
      the cursor, so there is no telling a hit from a miss. }
    { Push/pull and offset want to know which face they would take.  So do
      the drawing tools, for a different reason: a circle or a rectangle
      about to be laid on the top of a box needs to say *which* face it is
      going onto, before the click, or you find out afterwards that it went
      on the ground.  SketchUp washes the face over and shows its points;
      this does the same. }
    if (FTool in [ptPush, ptOffset]) and (FStage = 0) then
      FHoverFace := FD.Doc.HitFace(Proj, X, Y)
    else if (FTool in [ptLine, ptRect, ptCircle, ptArc]) and (FStage = 0) and
            not FPlaneHeld then
      FHoverFace := FD.Doc.HitFace(Proj, X, Y)
    else
      FHoverFace := -1;
    FScreenDirty := True;
    InvalidateStatus;
    Exit;
  end;

  if FFreehand then
    PenTo(X, Y, not FPenUp);
end;

{ What an orbit should turn about: whatever is under the cursor.  A face if
  there is one, otherwise the working plane, and failing that the middle of
  the drawing so an empty view still behaves. }
{ What the view should turn about.

  A face under the cursor is the thing you grabbed, and the middle of the
  drawing is the next best answer.  With an empty sheet there is neither, and
  the fallback is wherever the cursor lands on the working plane - which is
  fine looking down at it and meaningless looking along it, because there is
  no crossing point to find.

  That is the crash Tony reported: orbiting an empty drawing swings the
  camera through level, the pivot came back a billion feet away, and
  everything drawn afterwards was drawn relative to it.  An empty sheet turns
  about the origin instead, which is the only point on it that means
  anything. }
{ Note where the pivot is on screen, so the orbit can hold it there.

  This is the whole of what was wrong with orbiting.  The turn is about
  FOrbitPivot, and each frame the view is nudged so that point stays put -
  but it was being held under the *cursor* rather than at its own place on
  the glass.  Grab a face and the two are the same thing, so that case looked
  right and hid the rest.  Grab empty space and they are not: the pivot falls
  back to the middle of the drawing, and holding the middle of the drawing
  under the cursor drags the whole model across the screen to meet the mouse.
  The further away you started the drag, the further it had to jump - which
  is exactly what it looked like.

  Held at its own screen position instead, a grabbed face still turns under
  the finger that grabbed it, and an orbit started out in space turns the
  model where it already is.

  Tried against SketchUp on 5 September 2026 and kept.  SketchUp does it a
  different way underneath - its camera has a target, orbit swings the eye
  about that target, and the target sits at the middle of the canvas, so
  what stays put there is the canvas centre rather than the thing you
  grabbed.  The two only disagree once the drawing has been panned off
  centre.  Pinning what you grabbed felt right in use and it is the smaller
  idea, so it stands; do not quietly convert this to a camera target because
  it is what SketchUp does internally.  If the canvas centre is ever seen to
  drift, that is the change to make, and it replaces this rather than being
  added to it. }
procedure TMainForm.AnchorOrbit(SX, SY: Integer);
var
  P: TPointF;
begin
  P := ScreenOf(FOrbitPivot);
  FOrbitAnchored := not (IsNan(P.X) or IsNan(P.Y) or
                         IsInfinite(P.X) or IsInfinite(P.Y)) and
                    (Abs(P.X) < 1E6) and (Abs(P.Y) < 1E6);
  if FOrbitAnchored then FOrbitAnchor := P
  else FOrbitAnchor := PtF(SX, SY);
end;

function TMainForm.PivotAt(SX, SY: Integer): TP3;
var
  F: Integer;
  P, Lo, Hi: TP3;

  function Sane(const Q: TP3): Boolean;
  begin
    Result := not (IsNan(Q.X) or IsNan(Q.Y) or IsNan(Q.Z) or
                   IsInfinite(Q.X) or IsInfinite(Q.Y) or IsInfinite(Q.Z)) and
              (Abs(Q.X) < 1E7) and (Abs(Q.Y) < 1E7) and (Abs(Q.Z) < 1E7);
  end;

  { A number that is not absurd is not the same as a point you could have
    grabbed, and only the second one is any use as a pivot.

    Whatever it came from, the point has to be somewhere near the glass: it
    is meant to be the thing under the cursor, and the view is about to be
    held still against it.  A crossing that comes back a few million feet
    away passes every test for being a number and is still not a place on
    the drawing - it is the working plane running away from a camera nearly
    edge-on to it, and the arithmetic reporting that with a straight face.

    Empty drawings are where this bites, because they are the only ones with
    nothing better to offer.  With a face under the cursor the pivot is that
    face; with anything drawn at all it is the middle of it; with nothing, it
    is this crossing and nothing else, so this is the one case where a bad
    answer had no competition. }
  function Grabbable(const Q: TP3): Boolean;
  var
    S: TPointF;
  begin
    Result := False;
    if not Sane(Q) then Exit;
    S := ScreenOf(Q);
    if IsNan(S.X) or IsNan(S.Y) or IsInfinite(S.X) or IsInfinite(S.Y) then
      Exit;
    Result := (Abs(S.X) < 8 * pbScreen.Width) and
              (Abs(S.Y) < 8 * pbScreen.Height);
  end;

begin
  if FD.Doc.FaceUnder(Proj, SX, SY, F, P) and Grabbable(P) then
    Exit(P);
  if FD.Doc.Bounds(Lo, Hi) then
  begin
    Result := P3((Lo.X + Hi.X) / 2, (Lo.Y + Hi.Y) / 2, (Lo.Z + Hi.Z) / 2);
    if Grabbable(Result) then Exit;
  end;
  Result := WorldAt(SX, SY);
  if not Grabbable(Result) then Result := P3(0, 0, 0);
end;

{ --- the settings lists -------------------------------------------------
  Scale, snap and the pen each get a button showing what they are set to and
  a list that opens above it.  The list is as long as it needs to be, which
  is the point: a row could only ever hold five or six choices. }

function TMainForm.PopupCount(Which: Integer): Integer;
begin
  case Which of
    POP_SCALE: Result := SCALE_COUNT;
    POP_SNAP: Result := SNAP_COUNT;
    POP_COLOR: Result := Length(PALETTE);
    POP_WIDTH: Result := PEN_STEPS;
    POP_HELP: Result := 6;
    POP_SHOP: Result := 1;
    POP_PREC: Result := Length(PREC_DENOMS);
  else
    Result := 0;
  end;
end;

function TMainForm.PopupCaption(Which, I: Integer): string;
begin
  case Which of
    POP_SCALE: Result := ScaleTable(FD.Units, I).Name +
      IfThen(FD.Units = usImperial, '  =  1''-0"', '');
    POP_SNAP: Result := IfThen(I = 0, 'No snapping', SnapName(FD.Units, I));
    POP_COLOR: Result := '';
    POP_WIDTH: Result := Format('%d px', [PEN_SIZES[I]]);
    POP_SHOP:
      Result := 'Lay a piece out flat';
    POP_PREC:
      if PREC_DENOMS[I] = 100 then Result := 'hundredths of an inch'
      else Result := Format('1/%d"', [PREC_DENOMS[I]]);
    POP_HELP:
      case I of
        0: Result := 'About  (F1)';
        1: Result := 'Check for updates';
        2: Result := 'Downloads';
        3: Result := 'The manual';
        4: Result := 'Report a problem';
      else
        Result := 'Project page';
      end;
  else
    Result := '';
  end;
end;

procedure TMainForm.PopupChoose(Which, I: Integer);
begin
  case Which of
    POP_SCALE: SetScaleIdx(I);
    POP_SNAP:
      begin
        FD.SnapIdx := EnsureRange(I, 0, SNAP_COUNT - 1);
        FCmdMsg := 'Snap: ' + SnapName(FD.Units, FD.SnapIdx);
      end;
    POP_COLOR: SetInk(PALETTE[I], False);
    POP_WIDTH: SetPenSize(PEN_SIZES[I]);
    POP_SHOP: StartUnfold;
    POP_PREC: SetLenPrecision(PREC_DENOMS[EnsureRange(I, 0, High(PREC_DENOMS))]);
    POP_HELP:
      case I of
        0: ShowAbout;
        1: begin CheckForUpdate(True); DoUpdate; end;
        2: OpenInBrowser('https://github.com/' + UPDATE_REPO + '/releases/latest');
        3: OpenInBrowser('https://github.com/' + UPDATE_REPO + '#readme');
        4: ReportBug;
      else
        OpenInBrowser('https://github.com/' + UPDATE_REPO);
      end;
  end;
  RebuildDeck;
  pbDeck.Invalidate;
end;

procedure TMainForm.OpenPopup(Which: Integer);
var
  N, I, W, H, RowH, LeftX, Bottom: Integer;
  B: TRect;
begin
  N := PopupCount(Which);
  if N <= 0 then Exit;
  FPopup := Which;
  FPopupN := N;
  FPopupHot := -1;
  { An arrow over a menu, not a drawing crosshair.  The pointer is choosing a
    row, not a point on the paper. }
  FCursorWas := pbScreen.Cursor;
  pbScreen.Cursor := crDefault;

  { find the button it belongs to, and hang the list off its left edge }
  LeftX := Round(20 * FUIScale);
  for I := 0 to High(FDeck) do
    if ((FDeck[I].Group = GRP_POPUP) and (FDeck[I].Value = Which)) or
       ((Which = POP_HELP) and (FDeck[I].Group = GRP_ICON) and
        (FDeck[I].Value = ACT_HELP)) then
    begin
      B := FDeck[I].Bounds;
      LeftX := pbDeck.Left + B.Left - pbScreen.Left;
      Break;
    end;

  RowH := Round(22 * FUIScale);
  W := Round(190 * FUIScale);
  if Which = POP_COLOR then W := Round(150 * FUIScale);
  if Which = POP_HELP then W := Round(210 * FUIScale);
  H := N * RowH + Round(12 * FUIScale);
  Bottom := pbScreen.Height - Round(6 * FUIScale);
  if H > pbScreen.Height - 20 then H := pbScreen.Height - 20;
  LeftX := EnsureRange(LeftX, 4, Max(4, pbScreen.Width - W - 4));
  FPopupR := Rect(LeftX, Max(4, Bottom - H), LeftX + W, Bottom);
  FScreenDirty := True;
end;

procedure TMainForm.ClosePopup;
begin
  if FPopup = POP_NONE then Exit;
  FPopup := POP_NONE;
  FPopupHot := -1;
  pbScreen.Cursor := FCursorWas;
  FScreenDirty := True;
  pbScreen.Invalidate;
end;

function TMainForm.PopupItemAt(SX, SY: Integer): Integer;
var
  RowH: Integer;
begin
  Result := -1;
  if FPopup = POP_NONE then Exit;
  if (SX < FPopupR.Left) or (SX > FPopupR.Right) or
     (SY < FPopupR.Top) or (SY > FPopupR.Bottom) then Exit;
  RowH := Round(22 * FUIScale);
  Result := (SY - FPopupR.Top - Round(6 * FUIScale)) div RowH;
  if (Result < 0) or (Result >= FPopupN) then Result := -1;
end;

{ A small badge of the current tool, drawn through a scratch surface so it
  gets the same anti-aliasing as everything else on the canvas. }
procedure TMainForm.PaintToolGlyph(C: TCanvas; AX, AY: Integer);
var
  Sz: Integer;
  Col: TPix;
begin
  Sz := Round(18 * FUIScale);
  if Theme.DarkScreen then Col := Pix(235, 240, 250) else Col := Pix(30, 30, 36);
  FGlyph.SetSize(Sz, Sz);
  FGlyph.ClearTransparent;
  PaintIcon(FGlyph, TOOL_ICONS[FTool], Rect(0, 0, Sz, Sz), Col, 0.95);
  FGlyph.DrawTo(C, AX, AY);
end;

procedure TMainForm.PaintPopup(C: TCanvas);
var
  I, RowH, Y, Cur: Integer;
  R: TRect;
  Sel: Boolean;
  S: string;
begin
  if FPopup = POP_NONE then Exit;
  RowH := Round(22 * FUIScale);

  C.Brush.Style := bsSolid;
  C.Brush.Color := PixToColor(MixPix(Theme.Panel, Pix(0, 0, 0), 0.15));
  C.Pen.Color := PixToColor(MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.30));
  C.Pen.Width := Max(1, Round(FUIScale));
  C.Rectangle(FPopupR);

  case FPopup of
    POP_SCALE: Cur := FD.ScaleIdx;
    POP_SNAP: Cur := FD.SnapIdx;
  else
    Cur := -1;
  end;

  for I := 0 to FPopupN - 1 do
  begin
    Y := FPopupR.Top + Round(6 * FUIScale) + I * RowH;
    if Y + RowH > FPopupR.Bottom then Break;
    R := Rect(FPopupR.Left + Round(4 * FUIScale), Y,
      FPopupR.Right - Round(4 * FUIScale), Y + RowH - 1);
    { the one in force is lit, which the combined list never managed }
    Sel := (I = Cur) or
      ((FPopup = POP_COLOR) and (PALETTE[I] = FInkColor)) or
      ((FPopup = POP_WIDTH) and
       (PEN_SIZES[I] = IfThen(FMode = mdPro, FEdgeW, FPenSize)));
    if Sel then
    begin
      C.Brush.Color := PixToColor(ShadePix(Theme.Accent, 0.95));
      C.FillRect(R);
    end
    else if I = FPopupHot then
    begin
      C.Brush.Color := PixToColor(MixPix(Theme.Panel, Pix(255, 255, 255), 0.12));
      C.FillRect(R);
    end;

    if FPopup = POP_COLOR then
    begin
      C.Brush.Color := PALETTE[I];
      if Sel then
        C.Pen.Color := PixToColor(Pix(255, 255, 255))
      else
        C.Pen.Color := PixToColor(MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.4));
      C.Pen.Width := IfThen(Sel, Max(2, Round(2 * FUIScale)), 1);
      C.Rectangle(R.Left + Round(6 * FUIScale), R.Top + Round(3 * FUIScale),
        R.Right - Round(6 * FUIScale), R.Bottom - Round(3 * FUIScale));
      C.Pen.Width := 1;
      C.Brush.Style := bsSolid;
      Continue;
    end;

    S := PopupCaption(FPopup, I);
    if Sel then UIFont(C, 10, True, Pix(22, 22, 26))
    else UIFont(C, 10, False, Theme.Text);
    C.TextOut(R.Left + Round(8 * FUIScale),
      R.Top + (RowH - C.TextHeight('X')) div 2, S);
  end;
  C.Brush.Style := bsClear;
  C.Pen.Width := 1;
end;

function TMainForm.IsSelected(I: Integer): Boolean;
var
  K: Integer;
begin
  Result := True;
  for K := 0 to High(FSel) do
    if FSel[K] = I then Exit;
  Result := False;
end;

procedure TMainForm.SelectAdd(I: Integer);
begin
  if (I < 0) or IsSelected(I) then Exit;
  SetLength(FSel, Length(FSel) + 1);
  FSel[High(FSel)] := I;
  FScreenDirty := True;
end;

procedure TMainForm.SelectRemove(I: Integer);
var
  K, J: Integer;
begin
  for K := 0 to High(FSel) do
    if FSel[K] = I then
    begin
      for J := K to High(FSel) - 1 do FSel[J] := FSel[J + 1];
      SetLength(FSel, Length(FSel) - 1);
      FScreenDirty := True;
      Exit;
    end;
end;

procedure TMainForm.SelectToggle(I: Integer);
begin
  if IsSelected(I) then SelectRemove(I) else SelectAdd(I);
end;

procedure TMainForm.SelectOnly(I: Integer);
begin
  SetLength(FSel, 0);
  SelectAdd(I);
end;

procedure TMainForm.SelectNone;
begin
  if Length(FSel) = 0 then Exit;
  SetLength(FSel, 0);
  FScreenDirty := True;
end;

{ Does this entity have a corner at that point? }
function TMainForm.EntHasPoint(I: Integer; const P: TP3): Boolean;
const
  TOL = 1E-7;
var
  K: Integer;
begin
  Result := True;
  if Dist(FD.Doc[I].A, P) < TOL then Exit;
  if Dist(FD.Doc[I].B, P) < TOL then Exit;
  for K := 0 to High(FD.Doc[I].Poly) do
    if Dist(FD.Doc[I].Poly[K], P) < TOL then Exit;
  Result := False;
end;

{ Double click: a face takes the edges around it, an edge takes the faces it
  bounds.  SketchUp's rule, and it saves a lot of shift-clicking. }
procedure TMainForm.SelectAttached(I: Integer);
var
  J: Integer;
begin
  SelectOnly(I);
  if I < 0 then Exit;
  if FD.Doc[I].Kind = ekFace then
  begin
    for J := 0 to FD.Doc.Live - 1 do
      if (J <> I) and (FD.Doc[J].Kind in [ekLine, ekArc]) and
         EntHasPoint(I, FD.Doc[J].A) and EntHasPoint(I, FD.Doc[J].B) then
        SelectAdd(J);
  end
  else
    for J := 0 to FD.Doc.Live - 1 do
      if (J <> I) and (FD.Doc[J].Kind = ekFace) and
         EntHasPoint(J, FD.Doc[I].A) and EntHasPoint(J, FD.Doc[I].B) then
        SelectAdd(J);
end;

{ Triple click: everything joined on, however far it runs.  Grows the set a
  corner at a time until nothing new turns up. }
procedure TMainForm.SelectConnected(I: Integer);
var
  J, N, Before: Integer;
  Pts: TP3Array;
begin
  SelectOnly(I);
  if I < 0 then Exit;
  repeat
    Before := Length(FSel);
    FD.Doc.VertsOf(FSel, Pts);
    for J := 0 to FD.Doc.Live - 1 do
      if not IsSelected(J) then
        for N := 0 to High(Pts) do
          if EntHasPoint(J, Pts[N]) then
          begin
            SelectAdd(J);
            Break;
          end;
  until Length(FSel) = Before;
end;

{ SketchUp's modifiers: Ctrl adds, Shift toggles, both together takes away,
  and nothing held starts over.  Dragging right to left takes anything the
  box touches; left to right takes only what fits inside it. }
procedure TMainForm.FinishSelect(X, Y: Integer; Shift: TShiftState);
var
  I: Integer;
  Add, Sub, Tog: Boolean;
begin
  Add := ssCtrl in Shift;
  Tog := ssShift in Shift;
  Sub := Add and Tog;

  if (Abs(X - FBoxX) > 3) or (Abs(Y - FBoxY) > 3) then
  begin
    SelectInBox(FBoxX, FBoxY, X, Y, X < FBoxX, Add or Tog);
  end
  else
  begin
    I := PickAt(X, Y);
    if I < 0 then
    begin
      if not (Add or Tog) then SelectNone;
    end
    else if FClickN >= 3 then SelectConnected(I)
    else if FClickN = 2 then SelectAttached(I)
    else if Sub then SelectRemove(I)
    else if Tog then SelectToggle(I)
    else if Add then SelectAdd(I)
    else SelectOnly(I);
  end;

  if Length(FSel) = 0 then FCmdMsg := 'Nothing selected.'
  else if Length(FSel) = 1 then FCmdMsg := '1 thing selected.'
  else FCmdMsg := Format('%d things selected.', [Length(FSel)]);
  FScreenDirty := True;
  InvalidateStatus;
end;

{ Crossing takes anything the box touches, otherwise only what is wholly
  inside it. }
procedure TMainForm.SelectInBox(X0, Y0, X1, Y1: Integer; Crossing, Add: Boolean);
var
  I, T: Integer;
  BX0, BY0, BX1, BY1: Double;
begin
  if X1 < X0 then begin T := X0; X0 := X1; X1 := T; end;
  if Y1 < Y0 then begin T := Y0; Y0 := Y1; Y1 := T; end;
  if not Add then SetLength(FSel, 0);
  for I := 0 to FD.Doc.Live - 1 do
  begin
    FD.Doc.ScreenBounds(Proj, I, BX0, BY0, BX1, BY1);
    if BX1 < BX0 then Continue;
    if Crossing then
    begin
      if (BX1 >= X0) and (BX0 <= X1) and (BY1 >= Y0) and (BY0 <= Y1) then
        SelectAdd(I);
    end
    else if (BX0 >= X0) and (BX1 <= X1) and (BY0 >= Y0) and (BY1 <= Y1) then
      SelectAdd(I);
  end;
  FScreenDirty := True;
end;

procedure TMainForm.DeleteSelection;
var
  I, J, T, N: Integer;
begin
  N := Length(FSel);
  if N = 0 then Exit;
  PushUndo;
  for I := 0 to N - 2 do
    for J := 0 to N - 2 - I do
      if FSel[J] < FSel[J + 1] then
      begin
        T := FSel[J]; FSel[J] := FSel[J + 1]; FSel[J + 1] := T;
      end;
  for I := 0 to N - 1 do
    FD.Doc.Delete(FSel[I]);
  SetLength(FSel, 0);
  RebuildFlatFaces;
  FCmdMsg := Format('Deleted %d thing%s.', [N, IfThen(N = 1, '', 's')]);
  RenderPro;
  RecomposeAll;
end;

{ How far the move has travelled.  A typed value wins over the pointer: a
  bare length runs along whichever direction is in force, [x,y,z] names a
  point in the drawing outright, and <x,y,z> is an offset from the grab. }
function TMainForm.MoveDelta: TP3;
var
  D: TP3;
  L, Len: Double;
  Txt: string;
  Abs_, Rel: Boolean;
  N: Integer;
  V: array[0..2] of Double;
begin
  Result := P3(FCur.X - FP1.X, FCur.Y - FP1.Y, FCur.Z - FP1.Z);

  Txt := Trim(FInput);
  Abs_ := (Length(Txt) >= 2) and (Txt[1] = '[');
  Rel := (Length(Txt) >= 2) and (Txt[1] = '<');
  if Abs_ or Rel then
  begin
    N := ParseTriple(Txt, FD.Units, V[0], V[1], V[2]);
    if N > 0 then
    begin
      if Abs_ then
        Result := P3(V[0] - FP1.X, V[1] - FP1.Y, V[2] - FP1.Z)
      else
        Result := P3(V[0], V[1], V[2]);
    end;
    Exit;
  end;

  if FDirLock >= 0 then
  begin
    D := AxisDir(FDirLock);
    L := Result.X * D.X + Result.Y * D.Y + Result.Z * D.Z;
    if (Txt <> '') and ParseLen(Txt, FD.Units, Len) then
      L := Sign(IfThen(L = 0, 1, L)) * Len;
    Result := P3(D.X * L, D.Y * L, D.Z * L);
    Exit;
  end;

  { Shift keeps the axis the move has already drifted onto, the way holding it
    in SketchUp locks whichever inference is showing at the time. }
  if ssShift in FMoveShift then
  begin
    if (Abs(Result.X) >= Abs(Result.Y)) and (Abs(Result.X) >= Abs(Result.Z)) then
      Result := P3(Result.X, 0, 0)
    else if Abs(Result.Y) >= Abs(Result.Z) then
      Result := P3(0, Result.Y, 0)
    else
      Result := P3(0, 0, Result.Z);
  end;

  if (Txt <> '') and ParseLen(Txt, FD.Units, L) then
  begin
    Len := Sqrt(Sqr(Result.X) + Sqr(Result.Y) + Sqr(Result.Z));
    if Len < 1E-9 then Exit;
    Result := P3(Result.X * L / Len, Result.Y * L / Len, Result.Z * L / Len);
  end;
end;

{ The selection drawn again where it would land, plus the line back to where
  it was grabbed. }
procedure TMainForm.PaintMoveGhost(C: TCanvas);
var
  I, K: Integer;
  D: TP3;
  Hi: TPointFArray;
  PA, PB: TPointF;
begin
  if (FTool <> ptMove) or (FStage <> 1) then Exit;
  D := MoveDelta;

  C.Pen.Style := psSolid;
  C.Pen.Width := Max(2, Round(2 * FUIScale));
  if FMoveCopy then C.Pen.Color := PixToColor(Pix(60, 180, 110))
  else C.Pen.Color := PixToColor(Pix(70, 130, 240));
  { the projection is affine, so one world offset is one screen offset for
    every point in the drawing - worked out once, then applied }
  PA := ScreenOf(P3(D.X, D.Y, D.Z));
  PB := ScreenOf(P3(0, 0, 0));
  for I := 0 to High(FSel) do
  begin
    Hi := FD.Doc.Outline(Proj, FSel[I]);
    if Length(Hi) < 2 then Continue;
    C.MoveTo(Round(Hi[0].X + PA.X - PB.X), Round(Hi[0].Y + PA.Y - PB.Y));
    for K := 1 to High(Hi) do
      C.LineTo(Round(Hi[K].X + PA.X - PB.X), Round(Hi[K].Y + PA.Y - PB.Y));
  end;
  C.Pen.Width := 1;

  { the travel line itself, in the axis color when one is locked }
  PA := ScreenOf(FP1);
  PB := ScreenOf(P3(FP1.X + D.X, FP1.Y + D.Y, FP1.Z + D.Z));
  C.Pen.Style := psDash;
  if FDirLock in [0..2] then
    C.Pen.Color := PixToColor(AxisPix(FDirLock))
  else
    C.Pen.Color := PixToColor(Theme.Accent);
  C.MoveTo(Round(PA.X), Round(PA.Y));
  C.LineTo(Round(PB.X), Round(PB.Y));
  C.Pen.Style := psSolid;
end;

function TMainForm.IsDoomed(I: Integer): Boolean;
var
  K: Integer;
begin
  Result := True;
  for K := 0 to High(FDoomed) do
    if FDoomed[K] = I then Exit;
  Result := False;
end;

{ Whatever the pointer is over: an edge first, then a face, then anything
  else within reach.  The same order the eraser picks in, so what lights up
  under one tool is what the other would take. }
function TMainForm.PickAt(SX, SY: Integer): Integer;
var
  E, F, T: Integer;
begin
  { A note is drawn over the top of everything, so it is picked before
    everything - otherwise a note sitting on a panel could not be got at,
    because the panel underneath answered first. }
  Result := FD.Doc.HitNote(SX, SY);
  if Result >= 0 then Exit;
  E := FD.Doc.HitEdge(Proj, SX, SY, 9 * FUIScale);
  F := FD.Doc.HitFace(Proj, SX, SY);
  T := FD.Doc.HitTest(Proj, SX, SY, 9 * FUIScale);
  Result := E;
  if Result < 0 then Result := F;
  if Result < 0 then Result := T;
end;

{ Add whatever is under the cursor to the list the eraser is holding. }
procedure TMainForm.DoomAt(SX, SY: Integer);
var
  I: Integer;
begin
  { An edge under the cursor is what you meant; away from any edge, the face
    itself is - which is how a box is hollowed out, leaving its wireframe. }
  { The note first, for the same reason the selection takes it first: it is
    drawn over the top, so it is what the cursor is on.  Rubbing out a note
    used to take the panel behind it instead, which is a poor trade. }
  I := FD.Doc.HitNote(SX, SY);
  if I < 0 then I := FD.Doc.HitEdge(Proj, SX, SY, 9 * FUIScale);
  if I < 0 then I := FD.Doc.HitFace(Proj, SX, SY);
  if I < 0 then I := FD.Doc.HitTest(Proj, SX, SY, 9 * FUIScale);
  if (I < 0) or IsDoomed(I) then Exit;
  SetLength(FDoomed, Length(FDoomed) + 1);
  FDoomed[High(FDoomed)] := I;
  FScreenDirty := True;
end;

{ Delete everything gathered, highest index first so the lower ones do not
  shift underneath, then see whether any regions should join up. }
procedure TMainForm.BurnDoomed;
var
  I, J, T, N: Integer;
  EA, EB: array of TP3;
  Kinds: array of TEntKind;
begin
  N := Length(FDoomed);
  if N = 0 then Exit;
  for I := 0 to N - 2 do
    for J := 0 to N - 2 - I do
      if FDoomed[J] < FDoomed[J + 1] then
      begin
        T := FDoomed[J];
        FDoomed[J] := FDoomed[J + 1];
        FDoomed[J + 1] := T;
      end;

  SetLength(EA, N);
  SetLength(EB, N);
  SetLength(Kinds, N);
  for I := 0 to N - 1 do
  begin
    EA[I] := FD.Doc[FDoomed[I]].A;
    EB[I] := FD.Doc[FDoomed[I]].B;
    Kinds[I] := FD.Doc[FDoomed[I]].Kind;
  end;

  PushUndo;
  J := FaceCount;
  for I := 0 to N - 1 do
    FD.Doc.Delete(FDoomed[I]);
  { Faces joining up where a line went, and faces disappearing because their
    outline is no longer closed, both come out of working the areas out again
    from what is left. }
  J := J - RebuildFlatFaces;

  if N = 1 then FCmdMsg := 'Deleted.'
  else FCmdMsg := Format('Deleted %d things.', [N]);
  if J > 0 then
    FCmdMsg := FCmdMsg + Format('  %d face%s gone with them.',
      [J, IfThen(J = 1, '', 's')]);
  SetLength(FDoomed, 0);
  SelectNone;
  RenderPro;
  RecomposeAll;
end;

{ How far the dimension line sits from what it measures: the perpendicular
  distance from the chord to the cursor, in screen pixels, signed so that
  dragging to either side puts it on that side.  SketchUp asks the same
  question the same way - click the two ends, then move away and click. }
{ Where the dimension line should sit, as a displacement in the model rather
  than a number of pixels.  The cursor is dropped onto the working plane and
  the part of it along the measured edge is taken out, which leaves a
  perpendicular in that plane - so the dimension goes where you pull it, stays
  there as you zoom, and does not swing round the geometry when you orbit.

  It used to be a signed screen distance, and the sign disagreed with the one
  the renderer worked out, which is why pulling the line down put it above the
  edge - inside the shape it was measuring. }
{ What the tape measure leaves behind.

  Which of the three it is comes from the mode rather than from what happened
  to be under the first click, which is SketchUp's arrangement and the better
  one: a guide point on an edge and a guide line off one are both things
  somebody wants, and deciding for them means one of the two cannot be had.

  A guide line runs parallel to the edge the measurement started on - that is
  how a wall thickness or a row of hangers gets set out.  Started away from
  any edge there is nothing to be parallel to, so it takes the direction of
  the run just measured, which is the only direction the gesture named. }
procedure TMainForm.LayGuide;
var
  D, Nm, AU, AV: TP3;
  L: Double;
begin
  if Dist(FP1, FP2) < 1E-9 then Exit;
  PushUndo;

  { Both, every time.

    A dashed line says where the offset is and a point says where along it
    the measurement actually landed.  They answer different questions and
    neither is much use alone: a line with no point leaves the one place you
    measured to as the one place you cannot see, and a point with no line
    marks a spot you cannot line anything else up with.

    There was a Ctrl that cycled between them.  Choosing is not the useful
    part - having both is - so it is gone until there is a reason for it. }

  { The line runs across the measurement, not along it.  The point of a guide
    is to mark a distance: measure three feet off a wall and the useful line
    is the one three feet out, running crosswise, snappable anywhere along
    its length.  A guide laid along the run lies on top of it and marks
    nothing.

    SketchUp reaches the same place from the other side - click an edge, drag
    away from it, get a line parallel to that edge - because dragging away
    from an edge is dragging across it.  Taken from the drag it also answers
    sensibly from a corner, where there is no single edge to be parallel
    to. }
  PlaneAxes(FD.Plane, AU, AV);
  Nm := Cross3(AU, AV);
  D := P3(FP2.X - FP1.X, FP2.Y - FP1.Y, FP2.Z - FP1.Z);
  D := Cross3(Nm, D);
  L := Sqrt(Sqr(D.X) + Sqr(D.Y) + Sqr(D.Z));
  if L < 1E-9 then
  begin
    { measured straight out of the working plane, so there is no crosswise
      direction in it - fall back to the run itself rather than to nothing }
    D := P3(FP2.X - FP1.X, FP2.Y - FP1.Y, FP2.Z - FP1.Z);
    L := Sqrt(Sqr(D.X) + Sqr(D.Y) + Sqr(D.Z));
  end;

  if L > 1E-9 then
    FD.Doc.AddGuide(FP2,
      P3(FP2.X + D.X / L, FP2.Y + D.Y / L, FP2.Z + D.Z / L));
  FD.Doc.AddGuide(FP2, FP2);

  FCmdMsg := FormatLen(Dist(FP1, FP2), FD.Units) +
    '   guide across the run, and a point where it landed';
  RenderPro;
  RecomposeAll;
end;

function TMainForm.EdgeSegments: TSegArray;
const
  ARC_STEPS = 48;
var
  I, K, N: Integer;
  A: TP3;
begin
  N := 0;
  SetLength(Result, 64);
  for I := 0 to FD.Doc.Live - 1 do
  begin
    { A solid's own edges used to be left out entirely, so that every face of
      every box was not found twice - once as itself and once as a region.

      But leaving them out means they cannot close anything either, and that
      is exactly what a roof needs them for: draw a ridge and two rafters on
      top of a box and the fourth side of each slope is the top of a wall,
      which belongs to the box.  The loop was never closed because one of its
      four sides had been hidden from the search.

      So they go in, and the duplicates are dealt with afterwards, where the
      question can actually be asked: a region that lands exactly on a face
      the solid already has is that face, and is dropped. }
    case FD.Doc[I].Kind of
      ekLine:
        begin
          if N >= Length(Result) then SetLength(Result, N * 2);
          Result[N].A := FD.Doc[I].A;
          Result[N].B := FD.Doc[I].B;
          Inc(N);
        end;
      ekArc:
        begin
          A := ArcPoint(FD.Doc[I].C, FD.Doc[I].R, FD.Doc[I].A0, FD.Doc[I].Plane, FD.Doc[I].Nm);
          for K := 1 to ARC_STEPS do
          begin
            if N >= Length(Result) then SetLength(Result, N * 2);
            Result[N].A := A;
            A := ArcPoint(FD.Doc[I].C, FD.Doc[I].R,
              FD.Doc[I].A0 + FD.Doc[I].Sweep * K / ARC_STEPS, FD.Doc[I].Plane, FD.Doc[I].Nm);
            Result[N].B := A;
            Inc(N);
          end;
        end;
    end;
  end;
  SetLength(Result, N);
end;

{ Work the drawn faces out again from the edges.

  This replaces a rule per situation - a chain that closes itself, a line that
  cuts a face in two, two faces merging when the line between them goes, a
  face dropped when its outline stops being backed by real edges - with one
  question asked after every edit: given these edges, what areas do they
  enclose?

  A solid's faces are left alone.  They are the boundary of something in three
  dimensions, not an area on a flat sheet, and a solid keeps its own topology;
  its edges are kept out of the calculation for the same reason.  That is the
  line Codex drew and it is the right one.

  The color of a face survives because a new region inherits it from whichever
  old face its middle fell inside. }
{ How many flat faces there are, for saying what an edit changed. }
function TMainForm.FaceCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FD.Doc.Live - 1 do
    if (FD.Doc[I].Kind = ekFace) and not FD.Doc[I].Solid then Inc(Result);
end;

function TMainForm.RebuildFlatFaces: Integer;
type
  TWas = record
    Mid: TP3;
    Poly: TP3Array;
    Nm: TP3;
    Ink: TColor;
  end;
var
  R: TRegionArray;
  Was: array of TWas;
  NWas, I, J, K, Made: Integer;
  Mid, Other: TP3;
  Ink: TColor;
  Dup: Boolean;
begin
  R := BuildRegionsCached(EdgeSegments, FRegionCache);
  Made := 0;

  { remember what was there, so the new faces can take their colors }
  NWas := 0;
  SetLength(Was, FD.Doc.Live);
  for I := 0 to FD.Doc.Live - 1 do
    if (FD.Doc[I].Kind = ekFace) and not FD.Doc[I].Solid and
       (Length(FD.Doc[I].Poly) >= 3) then
    begin
      Was[NWas].Poly := Copy(FD.Doc[I].Poly, 0, Length(FD.Doc[I].Poly));
      Was[NWas].Nm := FD.Doc.FaceNormal(I);
      Was[NWas].Ink := FD.Doc[I].Ink;
      Mid := P3(0, 0, 0);
      for K := 0 to High(Was[NWas].Poly) do
        Mid := P3(Mid.X + Was[NWas].Poly[K].X, Mid.Y + Was[NWas].Poly[K].Y,
                  Mid.Z + Was[NWas].Poly[K].Z);
      K := Length(Was[NWas].Poly);
      Was[NWas].Mid := P3(Mid.X / K, Mid.Y / K, Mid.Z / K);
      Inc(NWas);
    end;
  SetLength(Was, NWas);

  { out with the old, highest first so the numbers below do not shift }
  for I := FD.Doc.Live - 1 downto 0 do
    if (FD.Doc[I].Kind = ekFace) and not FD.Doc[I].Solid then
      FD.Doc.Delete(I);

  for I := 0 to High(R) do
  begin
    Mid := P3(0, 0, 0);
    for K := 0 to High(R[I].Outer) do
      Mid := P3(Mid.X + R[I].Outer[K].X, Mid.Y + R[I].Outer[K].Y,
                Mid.Z + R[I].Outer[K].Z);
    K := Length(R[I].Outer);
    Mid := P3(Mid.X / K, Mid.Y / K, Mid.Z / K);

    { Is this one a face the solid already has?  Same middle, same size, so
      it is the same face arrived at from the other direction.  Drawing it
      again would put a second face in the same place, and two faces in one
      place is how a drawing starts flickering. }
    { Same plane, same size, and a point of one lands inside the other.

      Not the average of the corners, which was the first thing I tried and
      is not a property of the shape at all: a gable post standing on a wall
      splits that wall's top edge and gives it a fifth corner, and the
      average moves even though the wall has not.  Those two walls came back
      twice.  Area and containment do not care how many corners a shape has
      been divided into. }
    Dup := False;
    for J := 0 to FD.Doc.Live - 1 do
      if (FD.Doc[J].Kind = ekFace) and FD.Doc[J].Solid and
         (Length(FD.Doc[J].Poly) >= 3) then
      begin
        Other := FD.Doc.FaceNormal(J);
        if Abs(Abs(Dot3(Other, R[I].Normal)) - 1) > 1E-6 then Continue;
        { the same plane, not merely a parallel one }
        if Abs(Dot3(Other, P3(FD.Doc[J].Poly[0].X - R[I].Outer[0].X,
                              FD.Doc[J].Poly[0].Y - R[I].Outer[0].Y,
                              FD.Doc[J].Poly[0].Z - R[I].Outer[0].Z))) > 1E-4
          then Continue;
        if Abs(Abs(LoopArea(R[I].Outer, R[I].Normal)) -
               FD.Doc.FaceArea(J)) > 1E-3 then Continue;
        if PointInLoop(Mid, FD.Doc[J].Poly, Other) then
        begin
          Dup := True;
          Break;
        end;
      end;
    if Dup then Continue;

    Ink := FInkColor;
    for J := 0 to NWas - 1 do
      if PointInLoop(Mid, Was[J].Poly, Was[J].Nm) then
      begin
        Ink := Was[J].Ink;
        Break;
      end;
    FD.Doc.AddFaceRaw(R[I].Outer, Ink, False);
    Inc(Made);
  end;
  Result := Made;
end;

{ A read-only look at what the region engine makes of this drawing, next to
  the faces actually stored.  It changes nothing - it is here so the new way
  can be checked against real drawings before anything depends on it. }
procedure TMainForm.ReportRegions;
var
  R: TRegionArray;
  Segs: TSegArray;
  I, Stored, Holes: Integer;
  Area, StoredArea, T0: Double;
begin
  Segs := EdgeSegments;
  T0 := Now;
  R := BuildRegionsCached(Segs, FRegionCache);
  T0 := (Now - T0) * 24 * 60 * 60 * 1000;

  Stored := 0;
  StoredArea := 0;
  for I := 0 to FD.Doc.Live - 1 do
    if (FD.Doc[I].Kind = ekFace) and not FD.Doc[I].Solid then
    begin
      Inc(Stored);
      StoredArea := StoredArea + FD.Doc.FaceArea(I);
    end;

  Area := 0;
  Holes := 0;
  for I := 0 to High(R) do
  begin
    Area := Area + Abs(LoopArea(R[I].Outer, R[I].Normal));
    Inc(Holes, Length(R[I].Holes));
  end;

  FCmdMsg := Format('%d edges -> %d regions (%s, %d holes) in %.0f ms.  ' +
    'Stored flat faces: %d (%s)',
    [Length(Segs), Length(R), FormatArea(Area, FD.Units), Holes, T0,
     Stored, FormatArea(StoredArea, FD.Units)]);
  pbCmd.Invalidate;
end;

function TMainForm.DimOffset3: TP3;
var
  W, D, Perp, Ax, BestAx: TP3;
  L, Along, Best: Double;
  K: Integer;
  Got: Boolean;
begin
  Result := P3(0, 0, 0);
  D := P3(FP2.X - FP1.X, FP2.Y - FP1.Y, FP2.Z - FP1.Z);
  L := Sqrt(D.X * D.X + D.Y * D.Y + D.Z * D.Z);
  if L < 1E-9 then Exit;
  D := P3(D.X / L, D.Y / L, D.Z / L);

  W := WorldAt(FMouseSX, FMouseSY);
  Perp := P3(W.X - FP1.X, W.Y - FP1.Y, W.Z - FP1.Z);
  Along := Perp.X * D.X + Perp.Y * D.Y + Perp.Z * D.Z;
  Result := P3(Perp.X - D.X * Along, Perp.Y - D.Y * Along, Perp.Z - D.Z * Along);

  { Pull it out along an axis rather than at whatever angle the cursor happens
    to be at.  A dimension on a vertical line can go out along red or green,
    and either way its witness lines run square with the drawing; free-angle
    made them lean, which is what makes a drawing look wrong even when the
    number on it is right.

    Only axes square to what is being measured are offered.  A line that does
    not run along an axis has none, and keeps the free perpendicular - which
    is what an aligned dimension on a diagonal wants anyway. }
  Best := 0;
  Got := False;
  for K := 0 to 2 do
  begin
    case K of
      0: Ax := P3(1, 0, 0);
      1: Ax := P3(0, 1, 0);
    else Ax := P3(0, 0, 1);
    end;
    if Abs(Ax.X * D.X + Ax.Y * D.Y + Ax.Z * D.Z) > 1E-6 then Continue;
    Along := Result.X * Ax.X + Result.Y * Ax.Y + Result.Z * Ax.Z;
    if Abs(Along) > Abs(Best) then
    begin
      Best := Along;
      BestAx := Ax;
      Got := True;
    end;
  end;
  if Got then
    Result := P3(BestAx.X * Best, BestAx.Y * Best, BestAx.Z * Best);

  { never let it sit right on top of what it measures }
  L := Sqrt(Sqr(Result.X) + Sqr(Result.Y) + Sqr(Result.Z));
  if L * Ppu < 8 then
  begin
    if L < 1E-9 then Exit;
    Result := P3(Result.X / L * 8 / Ppu, Result.Y / L * 8 / Ppu,
                 Result.Z / L * 8 / Ppu);
  end;
end;

{ SketchUp's trick: rest on a point for a moment and it is remembered, so
  you can move away and still line up with it.  Without it the only thing
  you can align to is wherever the line already started, which is no help
  when the point that matters is across the drawing. }
procedure TMainForm.ServiceHover;
var
  Now64: QWord;
begin
  if FMode <> mdPro then Exit;

  { any real movement restarts the clock }
  if (Abs(FMoveX - FDwellSX) > 3) or (Abs(FMoveY - FDwellSY) > 3) then
  begin
    FDwellSX := FMoveX;
    FDwellSY := FMoveY;
    FDwellSince := GetTickCount64;
    Exit;
  end;

  { only a point worth referencing is worth keeping }
  if not (FSnapKind in [snEndpoint, snMidpoint, snCenter, snCross, snSubMid]) then
    Exit;

  Now64 := GetTickCount64;
  if Now64 - FDwellSince < DWELL_MS then Exit;

  if FNoLockUntilMoved then Exit;         // just snapped off from here
  if FLockOn and (Dist(FLockPt, FCur) < 1E-9) then Exit;   // already this one
  FLockOn := True;
  FLockPt := FCur;
  FLockKind := FSnapKind;
  FScreenDirty := True;
  InvalidateStatus;
end;

{ Guides are not ink.  An axis lock takes that axis's color, the way the
  model axes are drawn; lining up with some other point on the drawing gets
  this instead, so nothing that is only telling you where you are can be
  mistaken for something about to be drawn. }
function TMainForm.GuideColor: TPix;
begin
  if Theme.DarkScreen then
    Result := Pix($E8, $7C, $F0)
  else
    Result := Pix($A8, $2A, $BA);
end;

procedure TMainForm.pbScreenMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  { let go of a note being carried }
  if FNoteDrag >= 0 then
  begin
    FNoteDrag := -1;
    FCmdMsg := 'Note moved.  What it points at has not.';
    pbCmd.Invalidate;
    Exit;
  end;
  { the release position is the last thing the stroke saw }
  FMoveX := X;
  FMoveY := Y;
  FMovePending := True;
  ServiceMotion;

  { A press on a run of lines that never became a hold.  Two clicks in quick
    succession let go of the run without placing anything more - the point
    from the first click stays where it landed, which is the bit Tony wanted
    kept.  One click carries the line on as always. }
  if FHoldOn and (Button = mbLeft) then
  begin
    FHoldOn := False;
    FCur := ResolveSnapAt(X, Y);
    if FClickN >= 2 then
    begin
      ResetTool;
      FCmdMsg := 'Line finished.  Hold the button to snap it off instead.';
    end
    else
      ProClick;
    FScreenDirty := True;
    Exit;
  end;

  if FErasing2 then
  begin
    FErasing2 := False;
    BurnDoomed;
    Exit;
  end;

  if FBoxing then
  begin
    FBoxing := False;
    FinishSelect(X, Y, Shift);
    Exit;
  end;

  if FPanning or FOrbiting then
  begin
    FPanning := False;
    FOrbiting := False;
    if FTool = ptOrbit then pbScreen.Cursor := crSizeAll
    else pbScreen.Cursor := crCross;
    { A right button that went down and came up in the same place was a
      click, not a pan, and a click on a dimension edits its text.  The pan
      still owns the right button everywhere else, which is why this has to
      wait for the release and check that nothing moved. }
    if (Button = mbRight) and (FMode = mdPro) and
       (Abs(X - FRightSX) <= 3) and (Abs(Y - FRightSY) <= 3) then
      EditDimUnder(X, Y);
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
  L, A, RW, RH: Double;
  Mv: TP3;
  Ai: Integer;
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

  { Which way the face is actually going.  Saying "in" or "out" would only
    describe the sign against the face's own normal, and which way that
    points depends on how the loop happened to be wound - so it read "in"
    while the face visibly went up. }
  if (FStage = 1) and (FTool = ptOffset) then
  begin
    L := OffsetDistance;
    if Abs(L) > 1E-9 then
      Result := Result + '   OFFSET ' + FormatLen(Abs(L), FD.Units) +
        specialize IfThen<string>(L < 0, ' IN', ' OUT');
  end;

  if (FStage = 1) and (FTool = ptRect) then
  begin
    RectSides(FP1, RectTarget, FD.Plane, RW, RH);
    Result := Result + Format('   %s x %s   AREA %s',
      [FormatLen(RW, FD.Units), FormatLen(RH, FD.Units),
       FormatArea(RW * RH, FD.Units)]);
  end;

  if (FMode = mdPro) and (FD.View <> vkPlan) then
  begin
    Result := Result + '   PLANE ' + PlaneName;
    { Say where the plane came from.  Without this there is no telling a
      plane that is following the drag from one pinned by a face under the
      first point, and the two behave completely differently. }
    if FPlaneHeld then Result := Result + ' HELD'
    else if FPlaneFromFace then Result := Result + ' ON FACE'
    else if FStage >= 1 then Result := Result + ' FROM DRAG';

  end;

  { the face push/pull is offered, and how big it is - the same reading
    SketchUp gives you, and it says which of several stacked faces you have }
  if (FStage = 0) and (FTool = ptPush) and (FHoverFace >= 0) then
    Result := Result + '   FACE ' +
      FormatArea(FD.Doc.FaceArea(FHoverFace), FD.Units);

  if (FStage = 1) and (FTool = ptPush) and (FPushFace >= 0) then
  begin
    L := PushDistance;
    if Abs(L) > 1E-9 then
    begin
      Mv := FD.Doc.FaceNormal(FPushFace);
      Mv := P3(Mv.X * L, Mv.Y * L, Mv.Z * L);
      if (Abs(Mv.X) >= Abs(Mv.Y)) and (Abs(Mv.X) >= Abs(Mv.Z)) then
        Ai := 0
      else if Abs(Mv.Y) >= Abs(Mv.Z) then
        Ai := 2
      else
        Ai := 4;
      case Ai of
        0: if Mv.X < 0 then Ai := 1;
        2: if Mv.Y < 0 then Ai := 3;
      else
        if Mv.Z < 0 then Ai := 5;
      end;
      Result := Result + '   PUSH ' + FormatLen(Abs(L), FD.Units) +
        ' ' + AxisName(Ai);
    end;
  end;

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
  VerX: Integer;
  M, TitleH, Y, TW, RightEdge: Integer;
  S: string;
begin
  if not FBooted then Exit;
  FShell.DrawTo(Canvas, 0, 0);

  M := ChromeMargin;
  TitleH := TitleHeight;

  if FMode = mdPro then
  begin
    { one line: the name small on the left, the reading that matters on the
      right, and the hint between them only when it fits }
    UIFont(Canvas, 12, True, Theme.Text);
    Y := Round(5 * FUIScale);
    TW := TrackedText(Canvas, M + Round(2 * FUIScale), Y, UpperCase(APP_NAME),
      Round(2 * FUIScale));
    { The version, quietly, after the name.  Worth having on screen now that
      the program can replace itself: it is the first thing anybody needs to
      say when something goes wrong, and the first thing to check after an
      update claims to have worked. }
    UIFont(Canvas, 9, False, Theme.TextDim);
    VerX := M + Round(2 * FUIScale) + TW + Round(9 * FUIScale);
    Canvas.TextOut(VerX, Y + Round(4 * FUIScale), CurrentVersion);
    VerX := VerX + Canvas.TextWidth(CurrentVersion) + Round(8 * FUIScale);
    { A newer build, said where it cannot be written over.  It stays until
      the update is taken, which is the point: an announcement that vanishes
      when the next thing happens has not announced anything. }
    if FUpdateTag <> '' then
    begin
      UIFont(Canvas, 9, True, Pix(90, 190, 255));
      S := '* ' + FUpdateTag + ' available - /update';
      Canvas.TextOut(VerX, Y + Round(4 * FUIScale), S);
      VerX := VerX + Canvas.TextWidth(S) + Round(14 * FUIScale);
      UIFont(Canvas, 9, False, Theme.TextDim);
    end
    else
      VerX := VerX + Round(6 * FUIScale);

    { the TOY/PRO switch lives at the right of this same line, so the reading
      stops short of it rather than running underneath }
    RightEdge := ClientWidth - M - Round(186 * FUIScale) - Round(14 * FUIScale);
    UIFont(Canvas, 11, True, Theme.Text, True);
    S := StatusLine;
    TW := Canvas.TextWidth(S);
    Canvas.TextOut(RightEdge - TW, Round(6 * FUIScale), S);

    { the hint starts after the version rather than at a fixed place, or the
      two sit on top of each other }
    UIFont(Canvas, 9, False, Theme.TextDim);
    S := FHint;
    if Canvas.TextWidth(S) < RightEdge - TW - VerX then
      Canvas.TextOut(VerX, Round(8 * FUIScale), S);

    Exit;
  end;

  UIFont(Canvas, 20, True, Theme.Text);
  Y := Round(12 * FUIScale);
  TrackedText(Canvas, M + Round(4 * FUIScale), Y, UpperCase(APP_NAME),
    Round(3 * FUIScale));

  UIFont(Canvas, 9, False, Theme.TextDim);
  Canvas.TextOut(M + Round(5 * FUIScale), Y + Round(28 * FUIScale),
    'NozelFab Incorporated  -  est. 2021  -  ' + CurrentVersion);

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

{ How finely lengths are written, and read.

  One setting for both, because a drawing that prints sixteenths while
  accepting sixty-fourths would take a number and show a different one - the
  sort of thing you find out after cutting.  It never changes what the model
  holds: a length typed finer than the display keeps every digit and is only
  written down rounded, which is what precision means in SketchUp too. }
procedure TMainForm.SetLenPrecision(D: Integer);
begin
  SetLenDenom(D);
  FLenDenom := LenDenom;
  if FLenDenom = 100 then
    FCmdMsg := 'Lengths to hundredths of an inch.'
  else
    FCmdMsg := Format('Lengths to the nearest 1/%d of an inch.', [FLenDenom]);
  SaveSettings;
  RebuildDeck;
  pbDeck.Invalidate;
  RenderPro;
  RecomposeAll;
  InvalidateStatus;
  pbCmd.Invalidate;
end;

procedure TMainForm.SetPenSize(V: Integer);
begin
  V := EnsureRange(V, MIN_PEN, MAX_PEN);
  if FMode = mdPro then
  begin
    if V = FEdgeW then Exit;
    FEdgeW := V;
    RenderPro;
    RecomposeAll;
    pbDeck.Invalidate;
    pbScreen.Invalidate;
    Exit;
  end;
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
  { the drawing changed, so whatever would not draw may be gone now }
  FRenderBroken := False;
  { Everything that changes the drawing comes through here, which makes it
    the one honest place to notice that there is something worth keeping. }
  Inc(FEditSeq);
  FDraftAge := 0;
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
  Trail('undo');
  SelectNone;   // the numbers it held mean something else now
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
  Trail('redo');
  SelectNone;
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

{ A remote display can change size underneath us: KasmVNC resizes the virtual
  screen to follow the browser window.  A window that was told on the command
  line to fill the screen has to go on filling it, and there is no reliable
  notification for the change, so it is watched on the tick.  Two integer
  comparisons a frame. }
procedure TMainForm.FollowScreenSize;
var
  W, H: Integer;
begin
  if FFill = flNone then Exit;
  Screen.UpdateMonitors;
  W := Screen.Width;
  H := Screen.Height;
  if (W < 320) or (H < 240) then Exit;
  if (W = FScrW) and (H = FScrH) then Exit;
  FScrW := W;
  FScrH := H;
  if FFill = flFull then
  begin
    WindowState := wsNormal;
    SetBounds(0, 0, W, H);
    WindowState := wsFullScreen;
  end
  else
  begin
    WindowState := wsNormal;
    SetBounds(0, 0, W, H);
    WindowState := wsMaximized;
  end;
end;

procedure TMainForm.tmrTickTimer(Sender: TObject);
var
  Dt, Speed, DX, DY: Single;
begin
  Dt := TICK_MS / 1000;

  FollowScreenSize;
  ServiceMotion;
  ServiceHover;

  { The guide buttons come and go with the guides.  Watched here rather than
    poked at from each place that adds or removes one - laying, clearing,
    erasing and undoing all change the count, and one of them is always the
    one that gets forgotten. }
  if (FMode = mdPro) and (FD.Doc.GuideCount <> FDeckGuides) then
  begin
    FDeckGuides := FD.Doc.GuideCount;
    RebuildDeck;
    pbDeck.Invalidate;
  end;

  { Survived long enough to call the startup a success, so the draft that was
    restored is not the thing that kills it.  Four seconds is well past every
    load, render and first paint. }
  if not FStartupDone then
  begin
    FUpTime := FUpTime + Dt;
    { and once there is a window to put it in front of, last time's crash can
      be offered - not before }
    if (FUpTime > 1.5) and not FAskedAboutCrash then
    begin
      FAskedAboutCrash := True;
      OfferCrashReport;
      { And only then look for a newer build.  Asking the network during
        startup meant the window could not appear until the answer came
        back, or the connection gave up - which on a bad line is a program
        that takes half a minute to start for no reason the user can see. }
      CheckForUpdate(False);
    end;
    if FUpTime > 4.0 then
      FStartupDone := True;
  end;

  { The stick under strain.  Held still, it winds up; moved, it goes slack
    again, because a drag is someone changing their mind about where the
    point goes rather than someone leaning on the button. }
  if FHoldOn then
  begin
    if (Abs(FMouseSX - FHoldX) > 5) or (Abs(FMouseSY - FHoldY) > 5) then
      FHoldT := 0
    else
    begin
      FHoldT := FHoldT + Dt;
      if FHoldT >= HOLD_BREAK then
      begin
        { It broke.  Let go of the run and place nothing - that is the whole
          point of the gesture, and what a double-click cannot do. }
        FWasLine := FTool = ptLine;
        FSnapA := ScreenOf(FP1);
        FSnapB := PtF(FMouseSX, FMouseSY);
        FSnapM := PtF((FSnapA.X + FSnapB.X) / 2, (FSnapA.Y + FSnapB.Y) / 2);
        FSnapT := SNAP_RECOIL;
        FHoldOn := False;
        ResetTool;
        FLockOn := False;
        FNoLockUntilMoved := True;
        FScreenDirty := True;
        if FWasLine then
          FCmdMsg := 'Snapped off.'
        else
          FCmdMsg := 'Thrown away - nothing was drawn.';
      end;
      FScreenDirty := True;
    end;
  end;
  if FSnapT > 0 then
  begin
    FSnapT := FSnapT - Dt;
    if FSnapT < 0 then FSnapT := 0;
    FScreenDirty := True;
  end;

  { A draft a couple of seconds after the drawing stops changing, so a busy
    hand is never writing files and a put-down pen always is. }
  if FEditSeq <> FDraftSeq then
  begin
    Inc(FDraftAge);
    if FDraftAge > (2000 div TICK_MS) then SaveDraft;
  end;
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

  { while a note or a dimension's label is being typed, everything is text }
  if ((FTool = ptText) and (FStage = 1)) or (FDimEdit >= 0) then
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

  { 'x' is only text while a rectangle is waiting for its size - everywhere
    else letters stay as tool shortcuts.

    The slash is there for the number pad.  Typing a rectangle should not
    mean reaching across the keyboard for an x or a comma, and the pad has a
    slash on it - so 2/2 is a two foot square, the way SketchUp's semicolon
    would be if a semicolon were somewhere useful.

    It is only the *first* slash, because the second one is a fraction:
    2/2 1/2 is two foot by two and a half.  Taking the first and leaving the
    rest is a rule you can hold in your head, which matters more here than
    cleverness would.  And it has to look like a measurement already - a
    slash with nothing typed is the start of /help, not a rectangle. }
  if ((Key in ['x', 'X', ',', ';']) or
      ((Key = '/') and (FInput <> '') and (FInput[1] in ['0'..'9']) and
       (Pos('x', FInput) = 0))) and
     (FTool = ptRect) and (FStage = 1) then
  begin
    FInput := FInput + 'x';
    FCmdMsg := '';
    pbCmd.Invalidate;
    pbScreen.Invalidate;
    Key := #0;
    Exit;
  end;

  { the brackets and commas are here for the Move tool's coordinate entry:
    [x,y,z] is a point in the drawing, <x,y,z> an offset from where you are }
  if Key in ['0'..'9', '.', '/', '''', '"', ' ', '-', ',', ';',
             '[', ']', '<', '>'] then
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

  { SketchUp's arrows name an axis by its color, the same in every view:
    right locks red, left locks green, up locks blue.  A lock is on the axis,
    not on a direction along it, so the cursor still says which way. }
  function ArrowAxis(K: word): Integer;
  begin
    case K of
      VK_RIGHT: Result := 0;      // red, X
      VK_LEFT: Result := 2;       // green, Y
      VK_UP: Result := 4;         // blue, Z
      VK_PRIOR: Result := 4;
      VK_NEXT: Result := 5;
    else
      Result := -1;               // down lets go, our stand-in for magenta
    end;
  end;

  { Nudging the cursor with the arrows still wants a screen direction, which
    is a different question from which axis a lock means. }
  function ArrowStep(K: word): Integer;
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
    if (FTool in [ptLine, ptMove]) and (FStage = 1) then
    begin
      FDirLock := ArrowAxis(K);
      if FDirLock < 0 then FCmdMsg := 'Free again.'
      else FCmdMsg := 'Locked to ' + AxisName(FDirLock) + '.';
    end
    else
    begin
      D := AxisDir(ArrowStep(K));
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
    VK_DELETE:
      begin
        { In the toy, Delete is the shake - that is the whole point of it.

          In PRO it used to fall through to the same shake when nothing was
          selected, which threw the entire drawing away without asking.  It
          is the one key next to the one that deletes what you picked, so it
          is easy to hit, and there was nothing between it and losing the
          lot.  Now it deletes the selection, and clearing the sheet is a
          question. }
        if FMode <> mdPro then
          StartErase
        else if Length(FSel) > 0 then
          DeleteSelection
        else if FD.Doc.Live = 0 then
          FCmdMsg := 'Nothing selected, and nothing to clear.'
        else if MessageDlg('Clear the sheet?',
             Format('Throw away all %d things on "%s"?'#13#10#13#10 +
               'Ctrl+Z will bring them back.',
               [FD.Doc.Live, FD.Name]),
             mtConfirmation, [mbYes, mbNo], 0) = mrYes then
        begin
          PushUndo;
          StartErase;          { the shake, as the discard }
        end
        else
          FCmdMsg := 'Left alone.';
        Key := 0;
        Exit;
      end;
  end;

  if FMode = mdPro then
  begin
    if Key = VK_MENU then
    begin
      { Alt steps through the flat planes and latches, so you can draw in mid
        air.  It used to only suspend snapping, which it still does while
        held. }
      if FD.View = vkPlan then
      begin
        { Straight down, the two upright planes are edge-on: a rectangle
          drawn in either is a line and a circle is a line, so the plane can
          be changed but nothing can be seen to have changed.  Plan draws on
          the ground, and says so rather than letting you wander off it and
          wonder where the shape went. }
        FD.Plane := plXY;
        FPlaneHeld := False;
        FCmdMsg := 'Plan draws flat on the ground.  ISO or 3D to work upright.';
        pbCmd.Invalidate;
        Key := 0;
        Exit;
      end;
      FD.Plane := TPlane((Ord(FD.Plane) + 1) mod 3);
      FPlaneHeld := True;
      case FD.Plane of
        plXZ: FCmdMsg := 'Plane held upright, XZ.  Alt again to change, Esc to follow faces.';
        plYZ: FCmdMsg := 'Plane held on the side, YZ.  Alt again to change, Esc to follow faces.';
      else
        FCmdMsg := 'Plane held flat, XY.  Alt again to change, Esc to follow faces.';
      end;
      RepaintPaper;
      RenderPro;
      RecomposeAll;
      pbCmd.Invalidate;
      Key := 0;
      Exit;
    end;

    { While a note or a /command is being typed, letters are letters - not
      shortcuts.  Only the keys that finish or edit it are handled here. }
    if ((FTool = ptText) and (FStage = 1)) or (Copy(FInput, 1, 1) = '/') or
       (FDimEdit >= 0) then
    begin
      case Key of
        VK_RETURN:
          { Shift+Enter is another line of the note, Enter finishes it.  A
            note on a fab drawing is rarely one line - a size, a spec and a
            remark stacked up is the normal shape of one. }
          if (ssShift in Shift) and (FTool = ptText) and (FStage = 1) then
          begin
            FInput := FInput + #10;
            pbCmd.Invalidate;
          end
          else
            CommandEnter;
        VK_ESCAPE:
          if FDimEdit >= 0 then
          begin
            FDimEdit := -1;
            FInput := '';
            FCmdMsg := 'Left as it was.';
            pbCmd.Invalidate;
            pbScreen.Invalidate;
          end
          else
            ResetTool;
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
      VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN, VK_PRIOR, VK_NEXT:
        { before a shape is under way the arrows pick the plane; after that
          they lock a direction, which is only meaningful for a line }
        if (FTool in [ptRect, ptCircle, ptArc]) or
           ((FTool = ptLine) and (FStage = 0)) then
          PlaneByArrow(Key)
        else
          Arrow(Key);
      VK_RETURN: CommandEnter;
      { Space is SketchUp's arrow.  Mid-shape it still finishes what is being
        drawn, because that is the older habit here and losing it would smart. }
      VK_SPACE:
        if (FStage = 0) and (FInput = '') then SetTool(ptSelect)
        else CommandEnter;
      VK_ESCAPE:
        begin
          if FPopup <> POP_NONE then
            ClosePopup
          else if FPlaneHeld then
          begin
            FPlaneHeld := False;
            FCmdMsg := 'Following the face under the cursor again.';
          end
          else if FInput <> '' then
            FInput := ''
          else if FStage > 0 then
            ResetTool
          else if Length(FSel) > 0 then
            SelectNone
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
      VK_R: SetTool(ptRect);
      VK_A: SetTool(ptArc);
      VK_C: SetTool(ptCircle);
      VK_P: SetTool(ptPush);
      VK_N: SetTool(ptText);
      VK_E: SetTool(ptErase);
      VK_M: SetTool(ptMove);
      VK_T: SetTool(ptMeasure);
      VK_D: SetTool(ptDim);
      VK_V:
        if ssShift in Shift then CycleViewPreset(-1) else CycleViewPreset(1);
      VK_I: RunCommand(IfThen(FD.View = vkIso, 'plan', 'iso'));
      VK_K: RunCommand('plane');
      { SketchUp puts Offset on F, and that is the muscle memory worth
        matching.  Zoom-to-fit keeps the key with Shift, and /fit as well. }
      VK_F:
        if ssShift in Shift then FitView else SetTool(ptOffset);
      VK_O: SetTool(ptOrbit);
      VK_G: RunCommand('grid');
      VK_U: RunCommand('units');
      VK_H: CycleTheme(1);
      VK_W: SetMode(mdToy);
      VK_OEM_4: SetPenSize(FEdgeW - 1);
      VK_OEM_6: SetPenSize(FEdgeW + 1);
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
  { each mode keeps its own look and gets it back on the way in }
  if FMode = mdPro then FProTheme := FThemeIdx else FToyTheme := FThemeIdx;
  FMode := M;
  ApplyModeTheme;
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

{ Each mode has its own set of looks and they do not overlap, so whichever
  was last saved, coming into a mode picks that mode's own. }
procedure TMainForm.ApplyModeTheme;
begin
  if FMode = mdPro then
  begin
    if (FProTheme < THEME_PRO_LIGHT) or (FProTheme > THEME_COUNT - 1) then
      FProTheme := THEME_PRO_DARK;
    FThemeIdx := FProTheme;
  end
  else
  begin
    if (FToyTheme < 0) or (FToyTheme >= THEME_PRO_LIGHT) then FToyTheme := 0;
    FThemeIdx := FToyTheme;
  end;
  if FInkAuto then SetInk(PixToColor(Theme.Ink), True);
end;

procedure TMainForm.CycleTheme(Step: Integer);
begin
  { PRO has two looks and they differ only in the chrome - the paper stays
    white, because that is what a drawing is.  TOY keeps the four playful
    ones, where the screen color is half the fun. }
  if FMode = mdPro then
  begin
    if FThemeIdx = THEME_PRO_LIGHT then FThemeIdx := THEME_PRO_DARK
    else FThemeIdx := THEME_PRO_LIGHT;
    FProTheme := FThemeIdx;
  end
  else
  begin
    FThemeIdx := (FThemeIdx + Step + THEME_PRO_LIGHT) mod THEME_PRO_LIGHT;
    FToyTheme := FThemeIdx;
  end;
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
  L, CamT: TStringList;
  I, Idx, NSheet, Head: Integer;
  CamV, CamZ: Double;
  Line, Key, Rest: string;
  D: TDrawing;

  { the file's own decimal point, whatever the machine's happens to be }
  function RdF(const T: string): Double;
  var
    FS2: TFormatSettings;
  begin
    FS2 := DefaultFormatSettings;
    FS2.DecimalSeparator := '.';
    Result := StrToFloatDef(Trim(T), 0, FS2);
  end;

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

    { The magic line, which is not always the first line.

      A draft saved from a file that had a name is written with a '# from
      <path>' comment on top, so the restore can say what it was.  The magic
      was then looked for on line zero, found a comment, and declared the
      file not to be a drawing - so opening a named file, letting it save a
      draft and starting again told you your own work was not a drawing and
      dropped it.  Only named files had the comment, which is why an
      unsaved sketch always came back and a saved one did not.

      Skipping comments and blank lines here rather than teaching the draft
      writer not to write them: a leading comment is a reasonable thing for a
      text format to carry, and a reader that trips over one is the thing
      that is wrong. }
    Head := 0;
    while (Head < L.Count) and
          ((Trim(L[Head]) = '') or (Copy(Trim(L[Head]), 1, 1) = '#')) do
      Inc(Head);

    if (Head >= L.Count) or
       (Copy(Trim(L[Head]), 1, Length(DOC_MAGIC)) <> DOC_MAGIC) then
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

    Idx := Head + 1;
    while Idx < L.Count do
    begin
      Line := Trim(L[Idx]);
      Inc(Idx);
      if (Line = '') or (Copy(Line, 1, 1) = '#') then Continue;
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
          else if Key = 'CAMERA' then
          begin
            { A file written before this has no camera line and keeps
              whatever the view would have given it. }
            CamT := TStringList.Create;
            try
              CamT.Delimiter := ' ';
              CamT.DelimitedText := Rest;
              if CamT.Count >= 5 then
              begin
                { Clamped through locals, and written out by hand.  Assigning
                  EnsureRange straight into a Double field of an object is the
                  shape this compiler miscompiles at -O3 - the read goes
                  through the register holding the object and the write
                  through one holding something else - and El on a drawing is
                  the very field it was found on the first time.  See the note
                  in ServiceMotion.  It cost a draft that would not open. }
                CamV := RdF(CamT[1]);
                if CamV < -1.45 then CamV := -1.45;
                if CamV > 1.45 then CamV := 1.45;
                CamZ := RdF(CamT[2]);
                if CamZ < 0.05 then CamZ := 0.05;
                if CamZ > 40.0 then CamZ := 40.0;
                D.Az := RdF(CamT[0]);
                D.El := CamV;
                D.Zoom := CamZ;
                D.ViewX := RdF(CamT[3]);
                D.ViewY := RdF(CamT[4]);
                D.CamKnown := True;
              end;
            finally
              CamT.Free;
            end;
          end
          else if Key = 'DIMS' then      { no longer used; older files have it }
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
    { Work the flat areas out for every sheet as it comes in.  A file holds
      the lines and the solids; the areas those lines close between them are
      derived, and nothing had been deriving them on the way in - so a roof
      drawn in one session opened as bare lines in the next, and stayed that
      way until something else happened to trigger a rebuild. }
    for I := 0 to High(FDrawings) do
    begin
      D := FD;
      FD := FDrawings[I];
      RebuildFlatFaces;
      FD := D;
    end;
    ResetTool;
    Relayout;
    { Frame the drawing only when the file could not say where the camera
      was.  It used to fit every time, which read the camera out of the file
      with some care and then immediately overwrote the zoom and the pan with
      a fresh fit - so a drawing always opened framed rather than where it
      was left, and the next save wrote the fit back as though that had been
      the view all along.  Older files carry no CAMERA line and still get
      framed, which is the right thing for them. }
    if FD.CamKnown then
    begin
      { the drawing still has to be put on the paper - framing it was doing
        that as a side effect, and skipping the framing skipped the render }
      RepaintPaper;
      RenderPro;
      RecomposeAll;
      Invalidate;
    end
    else
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
    BuildSession(L);
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
    user tacked on is normalized away so nothing ends up as .svg.png }
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
        FD.Doc.WriteSVG(L, Proj, FD.Units, FEdgeW);
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
          FD.Doc.Render(Sheet, V, FD.Units, FDimFont, Pix(20, 20, 20), FEdgeW);
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

{ Beside the settings, so it travels with them and needs no permission. }
{ The whole session - every sheet, with its own units, scale, snap and view -
  as the lines of a .hsk file.  Saving to a real file and writing the draft
  are then the same job done twice to different places. }
procedure TMainForm.BuildSession(L: TStrings);
var
  I: Integer;
begin
  L.Add(Format('%s %d', [DOC_MAGIC, DOC_VERSION]));
  for I := 0 to High(FDrawings) do
  begin
    L.Add('SHEET ' + FDrawings[I].Name);
    L.Add('UNITS ' + IntToStr(Ord(FDrawings[I].Units)));
    L.Add('SCALE ' + IntToStr(FDrawings[I].ScaleIdx));
    L.Add('SNAP ' + IntToStr(FDrawings[I].SnapIdx));
    L.Add('VIEW ' + IntToStr(Ord(FDrawings[I].View)));
    { Where the camera was standing.  A drawing that opens at some other angle
      than the one it was left at is a drawing you have to find your way back
      into, and it also means a drawing attached to a report cannot be looked
      at from where the person reporting it was looking. }
    L.Add(StringReplace(Format('CAMERA %.6f %.6f %.6f %.3f %.3f',
      [FDrawings[I].Az, FDrawings[I].El, FDrawings[I].Zoom,
       FDrawings[I].ViewX, FDrawings[I].ViewY]),
      DefaultFormatSettings.DecimalSeparator, '.', [rfReplaceAll]));
    FDrawings[I].Doc.SaveTo(L);
    L.Add('ENDSHEET');
  end;
end;

{ Keep what is on screen, whether or not it has ever been given a name.

  This is the Notepad bargain: you should not have to think about saving to
  be safe.  A drawing that has a file still gets its draft written, because
  the crash you want protecting from is the one between two saves.  Written
  to a temporary and renamed, so a crash mid-write cannot leave a half a
  draft where the good one was. }
procedure TMainForm.SaveDraft;
var
  L: TStringList;
  Tmp: string;
begin
  if Length(FDrawings) = 0 then Exit;
  { The whole of it is wrapped, not just the write.  An autosave runs on the
    tick, behind everything, and is the last thing that should ever be able
    to take the program down with it - a background convenience that kills
    the foreground work is worse than no autosave at all.  Whatever goes
    wrong, the seq is marked done so it does not sit there failing forty
    times a second. }
  try
    L := TStringList.Create;
    try
      if FDocPath <> '' then L.Add('# from ' + FDocPath);
      BuildSession(L);
      { Two copies of the program open at once used to write the same
        temporary file, one over the other, and rename the interleaved
        result into place.  Whatever read it next - the other copy, or the
        next launch - walked off the end of a half-written drawing.  That
        was the crash.

        A temporary of our own fixes it.  The rename is tried straight over
        the target first, which on Unix replaces it in one indivisible step
        so a reader sees the old file or the new one and never neither; only
        if that fails is the target removed first, which is what Windows
        needs. }
      Tmp := DraftFile + '.' + FRunTag + '.tmp';
      ForceDirectories(ExtractFilePath(DraftFile));
      L.SaveToFile(Tmp);
      if not RenameFile(Tmp, DraftFile) then
      begin
        if FileExists(DraftFile) then DeleteFile(DraftFile);
        if not RenameFile(Tmp, DraftFile) then DeleteFile(Tmp);
      end;
    finally
      L.Free;
    end;
  except
    on E: Exception do
      FHint := 'Could not keep a draft just now (' + E.ClassName + ')';
  end;
  FDraftSeq := FEditSeq;
end;

{ Pick the draft back up at startup.

  It comes back as the drawing but not as the file: FDocPath is cleared, so
  Ctrl+S asks where to put it.  Anything else would have the program quietly
  writing over a file the drawing only half came from. }
procedure TMainForm.RestoreDraft;
var
  L: TStringList;
  Was, Aside: string;
  Ini: TIniFile;
begin
  if not FileExists(DraftFile) then Exit;
  { an empty draft is not worth restoring }
  L := TStringList.Create;
  try
    try
      L.LoadFromFile(DraftFile);
    except
      Exit;
    end;
    if L.Count < 3 then Exit;
    Was := '';
    if (L.Count > 0) and (Copy(L[0], 1, 7) = '# from ') then
      Was := Trim(Copy(L[0], 8, MaxInt));
  finally
    L.Free;
  end;

  { Did the last run die while doing exactly this?  If the flag is still set
    from last time, the draft took the program down with it, and restoring it
    again would do the same forever - which is what a crash loop is.  Put it
    aside, keep it, and start clean.  Nobody's work is thrown away; it just
    stops being the thing that runs on startup. }
  Ini := TIniFile.Create(ConfigFile);
  try
    if Ini.ReadBool('startup', 'restoring', False) then
    begin
      { Kept under a name that can actually be opened again.  It used to end
        in .would-not-open, which the Open dialog filters out - so the file
        was there, and named on screen, and could not be reached by the one
        obvious means of reaching it. }
      Aside := ChangeFileExt(DraftFile, '') + '-would-not-open.hsk';
      if FileExists(Aside) then DeleteFile(Aside);
      RenameFile(DraftFile, Aside);
      Ini.WriteBool('startup', 'restoring', False);
      Ini.WriteInteger('startup', 'crashes', 0);
      FCmdMsg := 'The last drawing would not open - it is kept beside the ' +
        'settings as ' + ExtractFileName(Aside) + ' and can be opened.';
      Exit;
    end;

    { Two crashes in a row with this drawing opening each time.

      The test above only catches a draft that kills the program while it is
      being read, which is the loud case and the rare one.  The quiet one is
      a drawing that opens perfectly and then goes down five minutes later
      when you do the thing that breaks it - and since it opened, nothing
      stopped it opening again next time, and again after that.  That is the
      loop: the program comes back up holding the very thing that just killed
      it, waits for you to do the same thing, and dies.

      So the drawing is stood down after the second one rather than reloaded
      a third time.  It is kept, and named on screen, and it is one file
      open away.  Deciding that for somebody is worth it here: the state they
      are in is a program that will not stay running. }
    if Ini.ReadInteger('startup', 'crashes', 0) >= 2 then
    begin
      Aside := ChangeFileExt(DraftFile, '') + '-crashed.hsk';
      if FileExists(Aside) then DeleteFile(Aside);
      RenameFile(DraftFile, Aside);
      Ini.WriteInteger('startup', 'crashes', 0);
      FCmdMsg := 'It crashed twice with the last drawing open, so this run ' +
        'starts empty.  The drawing is kept as ' + ExtractFileName(Aside) +
        ' - open it when you want it.';
      Exit;
    end;
    Ini.WriteBool('startup', 'restoring', True);
  finally
    Ini.Free;
  end;

  { A draft is read before anything else has happened, so a bad one would
    take the program down on the way up - which is the worst possible time
    and looks like the program simply being broken. }
  try
    try
      if not LoadDocument(DraftFile) then Exit;
    except
      on E: Exception do
      begin
        FCmdMsg := 'The last draft would not load (' + E.ClassName +
          ') - starting empty.';
        Exit;
      end;
    end;
  finally
    { The flag says "in the middle of reading a draft", and that stops being
      true the moment the read returns - whether it worked, failed politely,
      or threw.  It used to be cleared four seconds after startup instead,
      which made closing the program inside four seconds indistinguishable
      from dying while reading: the next run would set a perfectly good draft
      aside and open empty.  Anything that goes wrong *after* the read is
      what the crash counter below is for, and it is the right instrument
      for it. }
    with TIniFile.Create(ConfigFile) do
    try
      WriteBool('startup', 'restoring', False);
    finally
      Free;
    end;
  end;
  { LoadDocument quite reasonably puts the file it read in the title.  This
    is not a file anyone opened, so take it back out: showing the draft's
    own path would invite saving over the safety net. }
  FDocPath := '';
  if Was <> '' then FHint := 'Not saved since ' + Was
  else FHint := 'Not saved to a file yet  -  Ctrl+S';
  FRestored := True;
  FDraftSeq := FEditSeq;
  Trail(Format('restored a draft: %d things (%s)', [FD.Doc.Live, KindCounts]));
  if Was <> '' then
    FCmdMsg := 'Picked up where you left off in ' + ExtractFileName(Was) +
      '.  Ctrl+S to write it back.'
  else
    FCmdMsg := 'Picked up where you left off.  Ctrl+S to give it a name.';
end;

{ Is a window at this place actually reachable?

  The old test asked whether the corner was inside the primary screen, with
  the top at or below zero - which is right for one monitor and wrong the
  moment there are two.  Windows numbers a monitor placed above or to the
  left of the primary one with negative coordinates, so a window docked on
  the left-hand screen saved a perfectly good position that failed this test
  on the way back in and got recentred every single time.  On a work laptop
  that lives in a docking station that is the normal case, not the odd one.

  So: ask every monitor, and accept the position if a usable piece of the
  window lands on one of them.  Enough of it to grab and drag - a sliver
  hanging off an edge is the case this is here to prevent. }
function TMainForm.OnAScreen(L, T, W, H: Integer): Boolean;
var
  I: Integer;
  R, X: TRect;
begin
  Result := False;
  R := Rect(L, T, L + W, T + H);
  for I := 0 to Screen.MonitorCount - 1 do
    if IntersectRect(X, R, Screen.Monitors[I].WorkareaRect) and
       (X.Right - X.Left >= 160) and (X.Bottom - X.Top >= 80) then
      Exit(True);
end;

procedure TMainForm.LoadSettings;
var
  Ini: TIniFile;
  WW, WH, WL, WT: Integer;
begin
  FInkColor := PALETTE[0];
  FInkAuto := True;
  try
    Ini := TIniFile.Create(ConfigFile);
    try
      FThemeIdx := EnsureRange(Ini.ReadInteger('look', 'theme', THEME_PRO_DARK),
        0, THEME_COUNT - 1);
      FToyTheme := EnsureRange(Ini.ReadInteger('look', 'toytheme', 0),
        0, THEME_PRO_LIGHT - 1);
      FProTheme := EnsureRange(Ini.ReadInteger('look', 'protheme', THEME_PRO_DARK),
        THEME_PRO_LIGHT, THEME_COUNT - 1);
      { On unless it has been turned off.  Asked for in the first report that
        came through the new postbox, and right: this is a program for
        measuring things, and a measured grid is how a drawing says how big
        it is before anything has been drawn on it. }
      FShowGrid := Ini.ReadBool('look', 'grid', True);
      FMode := TAppMode(EnsureRange(Ini.ReadInteger('look', 'mode', 0), 0, 1));
      FStyle := TPenStyle(EnsureRange(Ini.ReadInteger('pen', 'style', 0), 0, 4));
      FPenSize := EnsureRange(Ini.ReadInteger('pen', 'size', 4), MIN_PEN, MAX_PEN);
      { a new key, so a pen size saved when the two were one thing does not
        come back as a four pixel edge }
      FEdgeW := EnsureRange(Ini.ReadInteger('pro', 'linew', 1), MIN_PEN, MAX_PEN);
      FInkColor := TColor(Ini.ReadInteger('pen', 'ink', PALETTE[0]));
      FInkAuto := Ini.ReadBool('pen', 'inkauto', True);
      FSym := EnsureRange(Ini.ReadInteger('pen', 'symmetry', 1), 1, 8);
      FMirror := Ini.ReadBool('pen', 'mirror', False);
      FProDials := Ini.ReadBool('pro', 'dials', False);
      FD.ScaleIdx := EnsureRange(Ini.ReadInteger('pro', 'scale', 2), 0, SCALE_COUNT - 1);
      FD.SnapIdx := EnsureRange(Ini.ReadInteger('pro', 'snap', 5), 0, SNAP_COUNT - 1);
      SetLenDenom(Ini.ReadInteger('pro', 'precision', 16));
      FLenDenom := LenDenom;
      FD.Units := TUnitSystem(EnsureRange(Ini.ReadInteger('pro', 'units', 0), 0, 1));
      { the view is deliberately not restored - a drawing session starts
        flat, and 3D is somewhere you go on purpose }

      { Where the window was last time.  Only honored if it still lands on a
        screen - monitors get unplugged, and a window restored onto one that
        is no longer there is a window you cannot reach.  Size is clamped to
        what the screen can actually show, which is the case that started
        this: a default built on a big monitor arrived off the bottom of a
        1920x1080 laptop. }
      WW := Ini.ReadInteger('win', 'w', 0);
      WH := Ini.ReadInteger('win', 'h', 0);
      WL := Ini.ReadInteger('win', 'x', MaxInt);
      WT := Ini.ReadInteger('win', 'y', MaxInt);
      if (WW > 200) and (WH > 200) then
      begin
        WW := Min(WW, Screen.DesktopWidth);
        WH := Min(WH, Screen.DesktopHeight);
      end
      else
      begin
        { No size remembered, so this is the first run on this machine and
          the design size is in 96 dpi pixels.  Scaled up here, once, because
          the chrome scales itself - a deck drawn at 125% inside a window
          sized at 100% does not fit.

          Once, and only here.  The widget set used to do this on every
          create, which multiplied the *saved* size by the same factor every
          time: open, close, open, and the window was 25% wider again.  That
          is the window that kept growing.  Scaled is off on the form now, so
          a size that was written down comes back meaning exactly what it
          said. }
        WW := Round(Width * FUIScale);
        WH := Round(Height * FUIScale);
        WW := Min(WW, Screen.DesktopWidth);
        WH := Min(WH, Screen.DesktopHeight);
      end;
      if (WL <> MaxInt) and (WT <> MaxInt) and OnAScreen(WL, WT, WW, WH) then
        SetBounds(WL, WT, WW, WH)
      else
      begin
        SetBounds(Left, Top, WW, WH);
        Position := poScreenCenter;
      end;
      if Ini.ReadBool('win', 'max', False) then
        WindowState := wsMaximized;
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
    ForceDirectories(ExtractFilePath(ConfigFile));
    Ini := TIniFile.Create(ConfigFile);
    try
      Ini.WriteInteger('look', 'theme', FThemeIdx);
      Ini.WriteInteger('look', 'toytheme', FToyTheme);
      Ini.WriteInteger('look', 'protheme', FProTheme);
      Ini.WriteBool('look', 'grid', FShowGrid);
      Ini.WriteInteger('look', 'mode', Ord(FMode));
      Ini.WriteInteger('pen', 'style', Ord(FStyle));
      Ini.WriteInteger('pen', 'size', FPenSize);
      Ini.WriteInteger('pro', 'linew', FEdgeW);
      Ini.WriteInteger('pen', 'ink', FInkColor);
      Ini.WriteBool('pen', 'inkauto', FInkAuto);
      Ini.WriteInteger('pen', 'symmetry', FSym);
      Ini.WriteBool('pen', 'mirror', FMirror);
      Ini.WriteBool('pro', 'dials', FProDials);
      Ini.WriteInteger('pro', 'scale', FD.ScaleIdx);
      Ini.WriteInteger('pro', 'snap', FD.SnapIdx);
      Ini.WriteInteger('pro', 'precision', FLenDenom);
      Ini.WriteInteger('pro', 'units', Ord(FD.Units));

      { Taken in OnClose, while the window was still a window.  If the
        program came down some way that never closed the form, this is the
        last chance to ask and it may well answer with nothing - in which
        case the previous position stays in the file rather than being
        overwritten with rubbish. }
      { A run that got as far as writing its settings out is a run that did
        not crash, so the tally starts again. }
      Ini.WriteInteger('startup', 'crashes', 0);

      if not FWinSaved then RememberWindow;
      if FWinSaved then
      begin
        Ini.WriteBool('win', 'max', FWinMax);
        Ini.WriteInteger('win', 'x', FWinL);
        Ini.WriteInteger('win', 'y', FWinT);
        Ini.WriteInteger('win', 'w', FWinW);
        Ini.WriteInteger('win', 'h', FWinH);
      end;
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
    'Noella Stone was seven years old when she decided she wanted to',
    'write a program.  She drew the screen, the two dials and the shake',
    'button on paper, picked the colors, and told her dad what each part',
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
  Canvas.TextOut(Pad, Round(76 * FScale), 'NozelFab Incorporated');

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
