unit uMain;

{
  Heckers Sketch - an Etch A Sketch that grew up.

  19 October 2021.  Noella Stone, age 7, decided she wanted to write a
  program.  She drew the screen, the two dials and the shake button on paper,
  picked the colors, and told her dad what each part had to do.  He typed
  while she directed.

  2026.  Same program, two personalities:

    TOY  - the original.  Two dials, five kinds of pen, a kaleidoscope, and a
           shake that dissolves the drawing into aluminum powder.

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
  Dialogs, ExtCtrls, StdCtrls, Menus, LCLType, LCLIntf, Printers, PrintersDlgs, Contnrs,
  uSurface, uSkin, uCube, uDlgSkin, uShoot, uRecord, uExport, uExample, uExamples, uWork, uSplash, uSysInfo, uTouch, uRegion, uUpdate, uUpdateForm, uWhatsNew, uPaths,
  uReport, uNet, uUnfold, uFlatView, uBore, uSendForm, uSourceView, uHello, uFormat2, uHeck, uJig, uJigFiles, uFittings, uTransition, uSpool, uPipe,
  uRadiantData, uRadiant, uRadiantDlg,
  InkPage;

type
  TAppMode = (mdToy, mdPro);

  { What the cursor is allowed to infer, and what Alt cycles through.

    SketchUp's line tool: after the first click, Alt steps from all
    inferences, to the linear ones off, to parallel and perpendicular only.
    Their help, in docs/sketchup/05-drawing-basics.md.  A linear inference is
    a direction being offered - on an axis, along an axis from a point,
    parallel or perpendicular to an edge.  The points - an endpoint, a
    midpoint, a crossing - are not linear and are never turned off by it. }
  TInferMode = (imAll, imNoLinear, imParPerp);

  TProTool = (ptSelect, ptMove, ptLine, ptRect, ptArc, ptCircle, ptPush,
    ptText, ptErase, ptMeasure, ptDim, ptOrbit, ptOffset, ptRotate,
    ptProtractor, ptDrill, ptFollow);

  TPenStyle = (psClassic, psNeon, psRainbow, psSparkle, psChalk);

  { One pro-mode sheet.  Everything that belongs to a drawing rather than to
    the program lives here, so tabs are just a list of these. }
  { Enough of a flat area to recognize it again at the next rebuild.

    Plane and area rather than the corners, because the corners are not a
    property of the shape: standing a post on a wall splits that wall's top
    edge and gives it another corner without the wall having changed.  The
    middle is carried too, so two identical windows in one wall are told
    apart. }
  TIntListsW = array of TIntArrayW;

  { a finger on the screen, in drawing-area coordinates }
  TTouchPt = record
    Seq: Pointer;
    X, Y, X0, Y0: Integer;
    T0: QWord;
  end;
  { what the fingers are doing: nothing; one finger down and not yet
    known to be a tap or a drag; one finger being the mouse; two fingers
    panning and pinching; a gesture over, the finger still down ignored }
  TTouchMode = (tmNone, tmPending, tmMouse, tmGesture, tmSpent);

  { One line of the entity panel: what it is called, what it says, and - when
    it is something that can be changed - the two little steppers that change
    it.  The painter is dumb and reads this; the mouse looks in the same
    place for what it hit. }
  TInfoAct = (iaNone, iaSides, iaSoft, iaNoteSize, iaReverse, iaWidth, iaColor,
    iaMaterial, iaUnpaint, iaPartOpen, iaPartLock, iaPartExplode, iaPartRename,
    iaPartHide);
  TInfoRow = record
    Caption: string;
    Value: string;
    Act: TInfoAct;
    Ent: Integer;
    Head: Boolean;          { a section heading rather than a value }
    Minus, Plus: TRect;     { empty unless Act says otherwise }
  end;

  TRegionSig = record
    Nm: TP3;
    D: Double;
    Area: Double;
    Mid: TP3;
    Part: Integer;      { the group the area was found in }
  end;

  { the region finder's cache, one per group - a plane shared by two groups
    must not hand one group's areas to the other }
  TPartCache = record
    Part: Integer;
    Cache: TRegionCache;
  end;

  { Everything the paper is a picture of.  If none of it has moved, neither
    has the paper - see TMainForm.RepaintPaper. }
  TPaperSig = packed record
    Mode, ThemeIdx, W, H: Integer;
    View: TViewKind;
    Units: TUnitSystem;
    Grid, Axes: Boolean;
    Ppu, ViewX, ViewY, Az, El, Zoom, Snap, UIScale: Double;
  end;

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
    { Has anybody done anything to THIS sheet since it was loaded or saved.

      It used to be asked of the window instead - FEditSeq against FSavedSeq,
      one pair for all the sheets - and that is wrong twice over.  Closing
      sheet two asked about whether sheet one had been touched; and worse,
      making a new sheet calls LoadExample, which ends by setting
      FSavedSeq := FEditSeq so the example's three hundred things do not
      count as your work - and that marked every OTHER sheet saved as well.

      So: draw something, make a second sheet, close the first, and it went
      without a word.  From a note, 15 September: "I recently had another modified
      drawing and I closed its tab sheet and was not asked to save it."

      One flag per sheet, set where every edit already funnels through. }
    Dirty: Boolean;
    { The slice a plan view is cut out of - a floor plan is a horizontal
      section, not a photograph from above.  Lives on the sheet because it is
      a property of how this sheet is being looked at, and it only ever bites
      in PLAN; see TMainForm.ApplySlice. }
    SliceOn: Boolean;
    SliceLo, SliceHi: Double;
    { The flat areas this sheet had at the last rebuild.

      What it is for: an area that was there before and has no face now is one
      whose face was rubbed out on purpose, and it must not be handed a new
      one.  Without this, erasing a face put it straight back - the four edges
      still closed a loop, the loop was still an area, and the area was still
      given a face.  You could not make a window in anything. }
    Seen: array of TRegionSig;
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
    pbSlice: TPaintBox;
    pbTools: TPaintBox;
    pbInfo: TPaintBox;
    pbQuick: TPaintBox;
    pmView: TPopupMenu;
    pmCanvas: TPopupMenu;
    pbDeck: TPaintBox;
    pbKnobL: TPaintBox;
    pbKnobR: TPaintBox;
    pbMode: TPaintBox;
    pbScreen: TPaintBox;
    tmrTick: TTimer;
    function ExportDirFor(const Ext: string): string;
    procedure KeepExportDir(const Ext, Dir: string);
    function SaveDirNow: string;
    function OpenDirNow: string;
    { the command list's order: used lately first, then alphabetical }
    procedure BuildCmdOrder;
    function CmdIndex(const W: string): Integer;
    procedure TimingLine(const S: string);
    procedure ShowTimingLog;
    function CmdAliasFor(Idx: Integer; const Want: string): string;
    procedure SyncCmdList;
    procedure TakeCmdHighlight;
    procedure MoveCmdHighlight(Key: word);
    { True when what is typed is already the whole name of a command }
    function ExactCmd(const S: string): Boolean;
    procedure NoteCmdUsed(const Cmd: string);
    procedure CornerSelection;
    procedure ShowOpenEdges;
    procedure OpenManual;
    procedure KeepHelpCurrent;
    procedure HelpFetchProgress(BytesReceived, TotalBytes: Int64);
    procedure HelpFetchDone(Sender: TObject);
    { the system color picker, for a pen that is not on the palette }
    procedure PickAnyColor;
    function AskColor(Was: TColor; out C: TColor): Boolean;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    function AnyDirty: Integer;
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
    procedure pbCmdMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pbCmdMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbCmdMouseLeave(Sender: TObject);
    procedure pbTabsMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pbTabsMouseLeave(Sender: TObject);
    procedure pbTabsMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbTabsPaint(Sender: TObject);
    procedure pbQuickPaint(Sender: TObject);
    procedure pbQuickMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pbQuickMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbQuickMouseLeave(Sender: TObject);
    procedure RebuildQuick;
    function QuickHit(X, Y: Integer): Integer;
    function QuickWidth: Integer;
    procedure pbToolsPaint(Sender: TObject);
    function InfoPanelWidth: Integer;
    procedure InfoChanged;
    { the source window - see uSourceView.  It asks; these answer. }
    procedure ShowSource;
    { the source window in the program's theme - at opening, and whenever
      the theme changes }
    procedure ThemeSourceWindow;
    procedure SourceAskState(out DocSeq, PickSeq: Int64);
    procedure SourceAskSource(Version: Integer; L, Hints, Names: TStrings;
      out First, Last, LineThing: TIntArrayW; out SheetName: string);
    procedure SourceAskPicked(out Picked: TIntArrayW);
    procedure SourcePickThings(const Things: TIntArrayW);
    function SourceApply(L: TStrings; out ErrLine: Integer; out Err: string): Boolean;
    { run the jig that makes this group again; 0 runs every jig on the sheet }
    function RunJigOf(PartId: Integer): Boolean;
    { the same, from the group's record - the source window's play button }
    function RunJigOfThing(Thing: Integer): Boolean;
    { the source window's Pick: clicks on the sheet type places into it }
    procedure SourcePick(On: Boolean);
    function RunAllJigs: Integer;
    procedure SourceCenter;
    procedure RebuildInfo;
    procedure PaintInfoStep(C: TCanvas; const R: TRect; const S: string;
      Hot: Boolean);
    function InfoHit(X, Y: Integer): Integer;
    procedure pbInfoPaint(Sender: TObject);
    procedure pbInfoMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pbInfoMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbInfoMouseLeave(Sender: TObject);
    procedure pbToolsMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pbToolsMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbToolsMouseLeave(Sender: TObject);
    procedure RebuildTools;
    function ToolsHit(X, Y: Integer): Integer;
    function ToolStripWidth: Integer;
    procedure PaintChromeTip(C: TCanvas);
    procedure pbSlicePaint(Sender: TObject);
    procedure pbSliceMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pbSliceMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbSliceMouseLeave(Sender: TObject);
    procedure pbSliceMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    { which part of the cut strip a point is over: -1 none, 0 the label,
      1 the bottom field, 2 the top field, 3/4 its up arrows, 5/6 its downs }
    function SliceZoneAt(X, Y: Integer): Integer;
    function SliceFieldRect(Which: Integer): TRect;
    procedure CommitSliceEdit;
    procedure pbViewMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pbViewMouseLeave(Sender: TObject);
    procedure pbViewMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbViewPaint(Sender: TObject);
    function ViewButtonName: string;
    procedure ViewMenuClick(Sender: TObject);
    procedure FillViewMenu;
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
  public
    { A report from inside a dialog - the transition wizard, say.  Where is
      the dialog's name and Fields what it held, so the report says what was
      typed; the picture is the screen, dialog and all. }
    procedure ReportFromDialog(const Where, Fields: string);
  private
    { --- surfaces ------------------------------------------------------- }
    FPaper: TArtSurface;         // paper, grain, grid
    { what the paper was last drawn for, and whether that is still true }
    FPaperSig: TPaperSig;
    FPaperOK: Boolean;
    FPaperPaints, FPaperSkips: Integer;
    FInkToy: TArtSurface;        // toy ink, keeps its own alpha
    FInkPro: TArtSurface;        // pro ink, rendered from the document
    FInkHalf: TArtSurface;       // half its size, for a frame while the camera moves
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
    { Where things were last put, so they go back to the same place.

      This is a portable program.  Left to itself a save dialog opens in the
      user's home folder, which for a program carried on a stick means
      somebody's work ends up scattered across a machine they may not own -
      and the next time they plug the stick in somewhere else, none of it is
      there.  So the first offer is a folder beside the program, and after
      that it is wherever they actually went.

      Exports are remembered per kind of file, because people keep STLs where
      the printer looks and pictures where the forum post is being written.
      The list is "ext=folder" lines. }
    { The edges where a solid is not closed, in pairs, and whether to show
      them.  Worked out by TWorkDoc.OpenEdges and kept until the drawing
      changes - an answer about geometry that has since been edited is worse
      than no answer. }
    FOpenEdges: TP3Array;
    FOpenSeq: Int64;
    FSaveDir, FOpenDir: string;
    FExportDirs: TStringList;
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
    FOrbitGain: Double;           { the trackball's leverage for this drag - see OrbitGainAt }
    FPushFace: Integer;
    FReplayFace: Integer;        { the face a replayed press is on, while it is pressed; -1 otherwise }
    { the face the offset tool is working on, or -1 }
    FOffFace: Integer;
    FHoverFace: Integer;   // the face push/pull would take, before you click

    { Held down, the eraser gathers everything the cursor is dragged over and
      shows it in red before any of it goes.  Deleting one line at a time is
      slow, and a click that turns out to have hit the wrong thing is worse. }
    FErasing2: Boolean;
    { What the eraser is doing this stroke, taken from the modifiers when the
      button went down: 0 rubs out, 1 softens, 2 un-softens.  SketchUp's Ctrl
      and Ctrl+Shift, and for the same reason - the creases down the side of
      a pulled circle are not edges anybody drew, and hiding them is what
      makes a cylinder look like a pipe rather than a barrel of staves. }
    FEraseMode: Integer;
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
    { whole groups being moved or turned: they go rigidly, and nothing
      loose that touches them is stretched after them }
    FMoveGroupEnts: TIntArrayW;
    FMoveCopy: Boolean;
    { The entity panel down the right-hand side: what is picked, and the few
      things about it that can be changed from there.

      From a note: "SketchUp has entities... And I think like for an arch you can
      get into it and edit the number of segments.  I think we were trying to
      avoid having all these various properties but I think it's a direction
      we may need to head... I also think the entity window should be docked
      to the right."

      Docked rather than a dialog because the point of it is watching the
      figures change as you pick different things, which a dialog you have to
      open cannot do.  The properties were all there already - Sides, Soft,
      Ink, Weight, Size, Plane, Grp - and so were the setters; what was
      missing was only the way in. }
    FInfoOn: Boolean;
    FInfoRows: array of TInfoRow;
    FInfoHot: Integer;
    FInfoSig: Int64;
    { What was copied, deep and detached from the document it came from, so
      it survives a switch to another sheet and can be pasted into a
      different one.  One clipboard for the window, which is what anybody
      means by a clipboard. }
    FClip: TWorkEntArray;
    { The frame watchdog.  Four running totals, cleared at the start of each
      paint and added to by the three things a frame is made of: working the
      ink out again, compositing it over the paper, and putting the result on
      the screen.  A frame that takes longer than a fortieth of a second
      writes one line into the session log, which is what every bug report
      carries - so "it felt glitchy" arrives with its own diagnosis.

      From a note: "we some times have clumsy things when moving around with tools
      selected at times where it seems the program is struggling or stuck in
      some loop for some reason and then you try to orbit and it glitches....
      Hard to pinpoint when and why." }
    FMsPaper, FMsRender, FMsComp: QWord;
    FSlowN: Integer;
    FSlowWorst: QWord;
    FSlowSaid: QWord;
    FSlowLast: string;
    { What the tape leaves behind: 0 both, 1 the point only, 2 the dashed
      line only, 3 neither.  Ctrl cycles it while the tape is in hand, which
      is SketchUp's key for the same choice - theirs toggles between guide
      line and guide point and the cursor icon says which.

      Both is the default and stays the default.  From a note: "I would like to be
      able to select our points with the select tool and right click to
      delete them and for our dashed lines as well... So I guess we want the
      control key back with both the dot and dash being dropped as default
      for ours.  I kind of like it." }
    FTapeDrop: Integer;
    { The last run the tape measured, kept after the tool has let go of it so
      that /keep can turn it into a dimension.  See the note on ptMeasure in
      ProCommit for why that is a command now and not a second press of
      Enter. }
    FRunOK: Boolean;
    FRunA, FRunB: TP3;
    { The edge just drawn over one already there.  SketchUp calls this
      healing: "Undo, or redraw the line that was removed - the face comes
      back on its own."  A face rubbed out leaves its edges behind and the
      area is remembered as one somebody did not want, so working the areas
      out again does not hand it back.  Tracing one of its edges says they
      do want it after all, and this is how that reaches the region loop.

      From a note, 15 September: deleting a face in SketchUp - in a cube,
      say - can be undone by drawing an edge back, awkwardly, and we need
      to be able to do the same thing. }
    FHealOn: Boolean;
    FHealA, FHealB: TP3;
    { /detach: a move takes what is selected away on its own instead of
      stretching what it is joined to.  Both were asked for ways; the
      stretching one is what SketchUp does and stays what you get by
      default.  It is a command rather than a held key because a move has
      no key left - Ctrl leaves a copy, Shift holds the axis, Alt holds the
      working plane, and every letter is a tool. }
    FDetachMove: Boolean;
    FLastPush: Double;         // what a double-click repeats
    { The tape measure lays down a guide by default, the way SketchUp's does;
      Ctrl turns that off and it only measures. }
    FMeasEdge: Integer;        // the edge the tape was started on, or -1
    { What the last rebuild worked out, so a plane whose edges have not moved
      is not worked out again.  Safe to keep across sheets: a plane is only
      reused when its segments hash the same, which means it is the same
      plane with the same edges in it. }
    { how many faces the last rebuild had to turn the right way out }
    FTurned: Integer;
    FRegionCaches: array of TPartCache;

    { how many clicks have landed in the same spot in quick succession: two
      takes what is attached, three takes everything joined on }
    FClickN: Integer;
    { the corner the last arc rounded, kept for the second click of a
      double-click to trim, and the radius a double-click elsewhere repeats -
      see ArcFillet }
    FLastFillet: TFillet;
    FFilletPending: Boolean;
    FFilletSeq: Int64;
    FFilletTick: QWord;
    FLastFilletR: Double;
    FClickT: QWord;
    FClickX, FClickY: Integer;

    { The working plane follows whatever face you are pointing at, so a shape
      drawn on top of a box lands on top of it.  Alt cycles through the three
      flat planes instead and latches, because sometimes you mean to draw in
      mid air; Esc, or a new tool, hands it back to the face. }
    FPlaneHeld: Boolean;
    { Alt's three stops on the line tool, and the edge the parallel and
      perpendicular offers are measured from - the segment just drawn, or
      the edge the line was started on. }
    FInferMode: TInferMode;
    FParHas: Boolean;
    FParDir: TP3;
    { 0 none, 1 parallel, 2 perpendicular - what the cursor is on now }
    FParPerp: Integer;
    { The arc's tangent lock: the edge its first point sits on, and whether
      Alt has pinned the bulge to run out of that edge smoothly.  SketchUp:
      "hover the edge you want it tangent to before the first click, and Alt
      locks the tangent inference". }
    FArcTanHas, FArcTanLock: Boolean;
    FArcTanDir: TP3;
    { The offset's Alt: leave the overlaps a tight corner makes instead of
      taking them out.  Theirs, and off unless asked for. }
    FOffsetRaw: Boolean;
    { The protractor's Alt: stop taking the plane from the face under the
      cursor.  Theirs: "Alt frees the protractor from the plane it
      inferred". }
    FRotFree: Boolean;
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
    { whether the note being carried has actually gone anywhere yet }
    FNoteMoved: Boolean;
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
    { the edit the named file was last written at; anything past it is
      unsaved, and the header says so }
    FSavedSeq: Int64;
    { unique to this run of the program, so two copies open at once cannot
      write the same temporary file over each other }
    FRunTag: string;
    FDraftAge: Integer;
    FRestored: Boolean;
    { closing because an update is taking over - nothing is asked }
    FHandingOver: Boolean;
    { Letting go of a run of lines by leaning on the button.

      Hold the left button still and the rubber band stops being a rubber
      band and becomes a stick under strain: it bows, thins, and a crack
      runs through it.  When it breaks, the run is released and no point is
      placed.  FHoldOn is a press waiting to see what it turns out to be,
      FHoldT how long it has been held, FSnapT the recoil afterwards. }
    FHoldOn: Boolean;
    FHoldT, FSnapT: Single;
    { a line snapping throws its two ends apart; a shape only bursts }
    FSnapEnds: Boolean;
    FHoldX, FHoldY: Integer;
    { How fast the pointer is moving, in pixels a second, smoothed.  The
      "line up with that point" nudges wait for the hand to slow down: a
      cursor swept across a cube crosses an alignment with one of its
      corners every few pixels, and taking each one as it passed made the
      cursor hunt sideways all the way over - what the owner called the mouse
      losing track of the rectangle. }
    FMoveSpeed: Double;
    FLastMoveTick: QWord;
    FLastMoveX, FLastMoveY: Integer;
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
    { an exception has been written up and the program is still standing:
      offer to send it on the next tick, not next start }
    FCrashToOffer: Boolean;
    FUpdatedFrom: string;
    FWhatsNewShown: Boolean;
    FPostcardOffered: Boolean;
    FTextPick: Boolean;           { the sheet is taking points for the source window }
    FSourceComplete: Boolean;     { the source window's list of words opens by itself }
    { The last few dozen things that happened, so a crash report says what
      was being done and not only where it landed.  A ring, so it costs
      nothing and never grows. }
    FTrail: array[0..63] of string;
    { The same session as the trail above, written so the program can read it
      back rather than so a person can.

      The trail says what happened in words and is for whoever opens the
      report.  This says it in coordinates and is for replaying: load the
      drawing that came with the report, run these, and the fault happens
      again in front of you.

      Recorded from inside the program, out of handlers it already has, so
      nothing is hooked and nothing outside this window is ever seen - it
      cannot record what it is not given.  And world coordinates rather than
      pixels, so a session from a 2142x844 window at 1.25 scaling replays on
      any screen at any size: 40'-2" means the same thing everywhere, and
      1432,311 does not. }
    FActs: array[0..511] of string;
    FActsN: Integer;
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
    { a built part being placed moves whole, on its own; nothing stretches }
    FMoveRigid: Boolean;
    { Follow Me: the face being spun, and the first point of its axis }
    FFollowFace: Integer;
    FAxisA: TP3;
    { what a dialog reported from inside itself, for the report body }
    FReportExtra: string;
    FTimings: Boolean;
    { what /timings has seen since it was turned on - the console is not
      there on Windows, so it is kept to be shown }
    FTimingLog: array of string;
    { The camera is moving - an orbit or pan in progress, or a wheel zoom
      within the last moment - so frames are drawn quick, and one full
      frame is drawn when it stops.  FQuickFrames turns the whole idea off. }
    FCameraMoving: Boolean;
    FQuickFrames: Boolean;
    { half resolution for the faces while the camera moves - switched on by
      a moving frame that came in slow, off again when the camera settles.
      See RenderPro and the note at the top of TWorkDoc.Render. }
    FMoveHalf: Boolean;
    { Long work in progress on the main thread: what and how far, shown on
      the command bar, and the input handlers stand down until it is over.
      FBusyAt is when it last reported; the tick clears a stale flag. }
    FBusy: Boolean;
    FBusyMsg: string;
    FBusyFrac: Double;
    FBusyAt, FBusyPaintMs: QWord;
    { a bulk select - all, or a box - marks what is in FSel once instead of
      asking IsSelected, which walks the whole selection, for every thing }
    FSelBulk: array of Boolean;
    FSelBulkOn: Boolean;
    { the outlines of a selection past a few thousand, drawn once into a
      layer and composited on every paint, rather than fifty thousand lines
      through the canvas each time the mouse moves }
    FSelLayer, FSelShot: TArtSurface;
    FSelLayerKey: string;
    { touch, from uTouch's hook: the fingers and what they are doing }
    FTouches: array of TTouchPt;
    FTouchMode: TTouchMode;
    FTouchDown: Boolean;
    FTouchOn: Boolean;
    FTouchCount: Integer;
    FGestMidX, FGestMidY, FGestDist: Double;
    { a document was being read and the splash screen's skip was pressed }
    FLoading, FLoadSkipped: Boolean;
    { worker threads for the caches (docs/render-acceleration.md); /threads }
    FThreads: Boolean;
    FStartedAt: QWord;
    FLastWheel: QWord;
    { the dimension the move tool has hold of by its line: only where the
      line sits changes, never what it measures }
    FDimMove: Integer;
    { The copy just made, so 3x or /3 typed next turns it into an array.
      Src is what was copied, Made every entity the copies are - all at the
      end of the list, so they can be taken back and made again at a new
      count.  Live until any other action. }
    FArray: record
      Live, Rotate: Boolean;
      Src: array of Integer;
      Made: TIntArrayW;
      D, C, Axis: TP3;
      Ang: Double;
    end;
    { Rotate and the protractor.  FP1 is the center; the axis is the plane's
      normal - an arrow key's axis, else the face under the cursor, else
      blue - and the reference arm is the second click. }
    FRotAxis: TP3;
    FRotAxisIx: Integer;
    FRotRef: TP3;
    { how many sides the next circle and the next arc get - SketchUp's
      defaults, changed with + and - or by typing 24s }
    FSidesCircle, FSidesArc: Integer;
    FMovePending: Boolean;
    FScreenDirty: Boolean;
    { the camera moved and the picture has not been redrawn for it yet - see
      ViewMoved }
    FViewDirty: Boolean;
    { the face whose blue wash is already in the picture being shown, so the
      overlay does not paint it again pixel by pixel - see pbScreenPaint }
    FHintInShot: Integer;
    { What was last put on the screen: the picture, the selection over it and
      the wash on the face under the pointer.  None of those change between
      one paint and the next unless something says so, and rebuilding it
      every paint cost a full-window composite and a full-window copy each
      time - 44 to 84 ms a frame on the report of 17 September, with
      nothing else happening at all. }
    FShotOK: Boolean;
    FShotHadSel: Boolean;
    { the paper's fill, made once per theme and size - see RepaintPaper }
    FPaperBase: TArtSurface;
    FPaperBaseKey: string;
    { 0 when the pointer is on the button out of the toy, -1 when it is not }
    FHotMode: Integer;
    FHotView: Integer;

    { The view cube, top left of the drawing.  Off unless asked for: a first
      drawing is a rectangle in plan, and a cube over it is an instrument for
      a question nobody has yet. }
    FCubeOn: Boolean;
    FSourceWasOpen: Boolean;      { the source window was open when the program was last shut }
    FSourceOnTop: Boolean;
    FSourceBounds: TRect;         { Left, Top, and Width and Height in Right and Bottom }
    { which corner of the drawing it sits in: 0 top left, 1 top right,
      2 bottom left, 3 bottom right }
    FCubeCorner: Integer;
    { whether a click brings what is picked into the middle and sizes it.
      With nothing picked it never does, whatever this says - there is
      nothing to center on, and re-fitting the whole drawing every time
      somebody looks at it from another side throws away the zoom they set. }
    FCubeFitSel: Boolean;
    FCubeSkin: TArtSurface;
    FCubeHot: TCubeTarget;
    FCubeHasHot: Boolean;
    { the view an orbit would click into if the button went up now - see
      OrbitSnapTarget }
    FSnapHot: TCubeTarget;
    FSnapHasHot: Boolean;
    FCubeDrag: Boolean;
    FCubeDragX, FCubeDragY: Integer;
    FCubePressX, FCubePressY: Integer;
    FCubeMoved: Boolean;
    FCubeCursor: Boolean;
    FCursorWasCube: TCursor;
    { Where a camera move is up to, 0 when it is not moving.  Every view
      change in this program used to snap, which is fine for a button and
      wrong for a cube: the tumble is how you keep track of which way the
      model went, and without it a click on a corner teleports you somewhere
      and leaves you to work out where. }
    FGlideT: Double;
    FGlideAz0, FGlideEl0, FGlideAz1, FGlideEl1: Double;
    { When it started, by the clock.  Counting ticks instead assumes the
      timer keeps up and it does not: every step of the move redraws the
      model, so on a drawing of any size the ticks come slower than the
      sixteen milliseconds they are asked for and a third of a second of
      animation takes a second and a half.  The recorder learned this the
      same way - see the note on FClock in uRecord. }
    FGlideAt: QWord;
    { the two places the camera stands, which is what the move interpolates }
    FGlideD0, FGlideD1: TP3;
    { what the turn turns about, and where it was on the screen when it
      started - held there for every frame of the move }
    FTurnPivot: TP3;
    FTurnAnchor: TPointF;
    FTurnAnchored: Boolean;
    { and the framing, when the move carries that too }
    FGlideFrame: Boolean;
    FGlideZ0, FGlideZ1, FGlideOX0, FGlideOX1, FGlideOY0, FGlideOY1: Double;
    FHotSlice: Integer;         // which zone of the cut strip is under the pointer
    FTools: array of TDeckItem; // the vertical tool strip down the left
    FToolSkin: TArtSurface;
    FInfoSkin: TArtSurface;
    FHotTool: Integer;
    { What is under the pointer on a strip, and where it is, so the note can
      be drawn beside the thing it is about.  FChromeTip is the title line,
      FChromeTipBody the sentence, FChromeTipY the middle of the button. }
    FChromeTip, FChromeTipBody: string;
    FChromeTipY, FChromeTipX: Integer;
    { where the lines go across the tool strip, and where the shop door sits }
    FToolRules: array of Integer;
    FShopTop: Integer;
    FQuick: array of TDeckItem;   // the file buttons in the title bar
    FQuickSkin: TArtSurface;
    FHotQuick: Integer;
    { Names beside the icons, or icons alone.  Kept in the settings, and it
      starts True on purpose - see pbToolsPaint. }
    FToolsWide: Boolean;
    FSliceSkin: TArtSurface;
    FSliceEdit: Integer;        // 0 none, 1 typing the bottom, 2 the top
    FViewSkin: TArtSurface;
    FGlyph: TArtSurface;    // the tool badge beside the cursor
    FHoverEnt: Integer;          // what the eraser is about to delete
    { The one edge the dimension tool would take, as its two ends.  An entity
      index is not enough any more: the edge may be one side of a face's
      outline, and a face has no A and B of its own. }
    FHoverEdgeOK: Boolean;
    FHoverEdgeA, FHoverEdgeB: TP3;
    FDocPath: string;            // where this set of sheets came from
    FGuide: Boolean;             // an alignment guide is active
    FGuideFrom: TP3;

    { A 90 degree relationship to a point you chose beats whatever else
      happens to be within snapping distance.  FAxisFrom is the point it is
      measured from - the start of the line, or one acquired by resting on
      it - and FAxisLock says which axis is free: 0 X, 1 Y, 2 Z. }
    FAxisLock: Integer;
    FSnapFromPt: Boolean;     { the distance along the axis came from a corner, not the grid }
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
    { The first row showing.  Only the command list is long enough to need
      it; everything else opens at nought and stays there. }
    FPopupTop: Integer;
    { the commands somebody has actually used, most recent first, as a comma
      list - kept in the settings so the list is in their order next time }
    FCmdRecent: string;
    FCmdWant: string;           { what the list is filtered by, after the slash }
    { the order the rows are in: recents, then the rest alphabetical }
    FCmdOrder: array of Integer;
    { where the arrow beside the prompt is, for hit testing }
    FCmdArrow: TRect;
    FCmdArrowHot: Boolean;
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
    procedure RightClickAt(X, Y: Integer);
    procedure FillCanvasMenu;
    procedure CanvasMenuClick(Sender: TObject);
    procedure CenterSelection;
    function ReverseSelectedFaces: Integer;
    { the material on a face, or on every picked face when the one being
      shown is one of them }
    function PaintSelectedFaces(Shown: Integer; C: TColor;
      Painting: Boolean): Integer;
    { the pen color of every picked line, arc, note and dimension }
    function InkSelectedThings(C: TColor): Integer;
    function SelectedDim: Integer;
    function SelectedLine: Integer;
    function ApplyLineLength(NewLen: Double): Boolean;
    procedure ApplySlice;
    procedure SetSlice(AOn: Boolean; ALo, AHi: Double; const Why: string = '');
    procedure NudgeSlice(Steps: Integer; Which: Integer);
    procedure PlanFromFace(Face: Integer);
    function SliceText: string;
    function ApplyDimResize(NewLen: Double; MoveB: Boolean): Boolean;
    procedure CommitDimNote;
    function DeckRowH: Integer;
    function DeckRows: Integer;
    function DeckHeight: Integer;
    function ChromeMargin: Integer;
    procedure RebuildShell;
    procedure RebuildDeck;
    procedure RebuildKnobs;
    procedure RefreshChrome;
    procedure NoteFrame(PaintMs: QWord);
    procedure ResizeSurfaces(AW, AH: Integer);
    function PaperSig: TPaperSig;
    procedure RepaintPaper;
    procedure PaintGroundGrid(Pitch: Double);
    procedure PaintAxes;
    procedure PaintPushPreview(C: TCanvas);
    procedure PaintFaceHint(C: TCanvas; Face: Integer; const Col: TPix;
      S: TArtSurface = nil; OX: Integer = 0; OY: Integer = 0);
    function HintFaceNow: Integer;
    procedure CheckForUpdate(Loud: Boolean);
    procedure DoUpdate;
    procedure ShowWhatsNew;
    procedure BuildTransitionWizard;
    procedure BuildSpoolWizard;
    procedure BuildRadiantWizard;
    function ArcNormal(I: Integer): TP3;
    procedure DoRevolve(const AxisP, AxisDir: TP3; PathArc: Integer = -1);
    function IsProfileEdge(I: Integer): Boolean;
    function AxisSplitsProfile(const AxisP, AxisDir: TP3;
      out RLo, RHi: Double): Boolean;
    procedure PaintRevolvePreview(C: TCanvas);
    { the chain of edges joined end to end through edge I, as points, and
      whether it closes on itself }
    function ChainFrom(I: Integer; out Closed: Boolean): TP3Array;
    procedure DoSweep(const Path: TP3Array; Closed: Boolean);
    { /rendertime: how long a frame takes, for chasing sluggish orbits }
    procedure RenderTiming;
    procedure Took(const What: string; T0: QWord);
    procedure ApplyArray(N: Integer; Divide: Boolean);
    function ArrayCommand(const S: string; out N: Integer; out Divide: Boolean): Boolean;
    { hand something just built to the move tool, so the next click places it }
    procedure CopySelection(Cut: Boolean);
    procedure PasteClip;
    procedure PlaceBuilt(First: Integer; const Ref: TP3);
    procedure StartUnfold;
    procedure UnfoldAt(SX, SY: Integer);
    procedure OfferCrashReport(JustNow: Boolean);
    function DocThings(const DocFile: string): Integer;
    procedure Quiesce;
    function WindowShot(out B: TBitmap): Boolean;
    procedure DrawPointerOn(B: TBitmap; ScreenCoords: Boolean; const Org: TPoint);
    function CaptureShot(Wait: Boolean; out Bmp: TBitmap): Boolean;
    procedure ShotCountdown(Seconds: Integer);
    procedure PaintShotOverlay(C: TCanvas);
    function ReportBug(const Preamble: string = '';
      const ShotFile: string = ''; const DocFile: string = ''): Boolean;
    { Note something worth knowing if this run ends badly. }
    procedure Trail(const S: string);
    procedure Act(const S: string);
    function ActsText: string;
    function ReplayActs(const Script: string): Integer;
    procedure DoReplayFile(const FileName: string);
    function TrailText: string;
    { How many of each kind are on the sheet - a crash that only happens with
      a face, or only with a note, says so here. }
    function KindCounts: string;
    { Everything worth knowing about the state of the program right now, as
      text.  One place, so a crash report and a report somebody writes by
      hand say the same things about the same program. }
    function DiagnosticText: string;
    function SettingsText: string;
    { The drawing as it stood, beside the report, so it can be opened here. }
    procedure SaveCrashDoc(const ReportPath: string);
    procedure ShakeWatch(X, Y: Integer);
    procedure PaintStrain(C: TCanvas; const A, B: TPointF; T: Single);
    function StrainOutline(out Pts: TPointFArray): Boolean;
    procedure PaintStrainPath(C: TCanvas; const Pts: TPointFArray; T: Single);
    procedure PaintStrainSeg(C: TCanvas; const A, B: TPointF; T: Single;
      Outward: Boolean; CX, CY: Double);
    procedure PaintStrainMark(C: TCanvas; CX, CY: Double; T: Single);
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
    function OutsideOf(const A, B, Off: TP3): TP3;
    function DimOffset3: TP3;
    procedure LayGuide;
    function TapeDropSays: string;
    { Every drawn edge as a plain segment, which is what the region engine
      eats.  Guides, dimensions and notes are not geometry and stay out; a
      solid's own faces are its boundary and are not derived either. }
    function EdgeSegments(Part: Integer): TSegArray;
    function CacheFor(Part: Integer): Integer;
    function AllPartIds: TIntArrayW;
    procedure ReportRegions;
    { The one call that keeps the drawn faces right.  Everything that changes
      an edge ends with this. }
    procedure SeedRegions;
    function RebuildFlatFaces: Integer;
    function FaceCount: Integer;
    function AnyFace: Boolean;
    function SolidFaceCount: Integer;
    procedure DoomAt(SX, SY: Integer);
    function PickAt(SX, SY: Integer): Integer;
    function PickForMenu(SX, SY: Integer): Integer;
    function IsSelected(I: Integer): Boolean;
    procedure LeaveSheet;
    procedure OnTouch(Kind: TTouchKind; Seq: Pointer; SX, SY: Double);
    procedure TouchTick;
    procedure TouchSendDown;
    procedure GestureStart;
    procedure GestureMove;
    procedure PruneSelection;
    procedure BeginBulkSelect;
    procedure EndBulkSelect;
    procedure EnsureSelLayer;
    procedure SelectOnly(I: Integer);
    procedure SelectToggle(I: Integer);
    procedure SelectAdd(I: Integer);
    procedure SelectRemove(I: Integer);
    procedure SelectNone;
    procedure FinishSelect(X, Y: Integer; Shift: TShiftState);
    function EntHasPoint(I: Integer; const P: TP3): Boolean;
    procedure SelectAttached(I: Integer);
    { --- groups --- }
    procedure SelectAddOne(I: Integer);
    procedure SelectRemoveOne(I: Integer);
    function PickAtRaw(SX, SY: Integer): Integer;
    function PickToGrab(SX, SY: Integer): Integer;
    function SelectedGroups: TIntArrayW;
    function SoleGroup: Integer;
    procedure MakeGroup;
    procedure ExplodeGroups;
    procedure OpenGroup(Id: Integer);
    procedure CloseGroup;
    procedure LockGroups(Locked: Boolean);
    procedure HideGroups(PutAway: Boolean; const Named: string);
    procedure RenameGroup(const NewName: string);
    function SplitMoveSelection: Boolean;
    function InContextFace(F: Integer): Integer;
    procedure PaintPartBox(C: TCanvas; Id: Integer; const Col: TPix;
      Dashed: Boolean; const Shift: TP3);
    function PromptForTool: string;
    procedure SelectConnected(I: Integer);
    procedure SelectInBox(X0, Y0, X1, Y1: Integer; Crossing, Add: Boolean);
    procedure DeleteSelection;
    function MoveDelta: TP3;
    function RunReading(const A, B: TP3): string;
    procedure PaintMoveGhost(C: TCanvas);
    procedure PaintRotateGhost(C: TCanvas);
    { The arc the picks describe: FP1 and FP2 the chord, B the point pulling
      its middle out.  Works out the plane too - the working plane, unless B
      is off it, in which case the three points make their own plane, which
      is how an arc drawn up the end of a box stands on the end of the box
      instead of lying on the ground under it. }
    function ArcPicks(const B: TP3; out Pl: TPlane; out C: TP3;
      out R, A0, Sweep, Bulge: Double): Boolean;
    function RotAngle: Double;
    function RotRefDir: TP3;
    function IsDoomed(I: Integer): Boolean;
    procedure BurnDoomed;
    { 0 rubs out, 1 softens, 2 un-softens - from the modifiers held }
    function EraseModeOf(Shift: TShiftState): Integer;
    { the gathered edges, softened or un-softened rather than deleted }
    procedure SoftenDoomed(On_: Boolean);
    function PopupMaxHeight(Which: Integer): Integer;
    procedure OpenPopup(Which: Integer);
    procedure ClosePopup;
    function PopupCount(Which: Integer): Integer;
    function PopupCaption(Which, I: Integer): string;
    procedure PopupChoose(Which, I: Integer);
    function PopupItemAt(SX, SY: Integer): Integer;
    function ScrollPopup(Lines, SX, SY: Integer): Boolean;
    procedure PaintPopup(C: TCanvas; DX: Integer = 0; DY: Integer = 0);
    procedure PaintToolGlyph(C: TCanvas; AX, AY: Integer);
    function PivotAt(SX, SY: Integer): TP3;
    function OrbitGainAt(SX, SY: Integer): Double;
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

    { toy }
    procedure StampSegment(X0, Y0, X1, Y1: Single);
    procedure EmitSegment(X0, Y0, X1, Y1: Single);
    procedure PenTo(NX, NY: Single; Drawing: Boolean);
    procedure ToggleAuto;
    procedure StepAuto(Dt: Single);

    { pro }
    function ToolName(T: TProTool): string;
    function Prompt: string;
    function SnapSays: string;
    function ModifierTip: string;
    function ShortKeys: string;
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
    function CameraShowsSomething: Boolean;
    procedure ZoomAt(Factor: Double; AnchorSX, AnchorSY: Double);
    procedure SetScaleIdx(I: Integer);
    procedure PanBy(DX, DY: Double);
    procedure ViewMoved;
    procedure FlushView;
    { Travel is False where there is nothing to keep your bearings with - a
      drawing just loaded, a different sheet, a change of projection.  The
      point of moving instead of jumping is to hold on to where things are,
      and when the things themselves have changed there is nothing to hold. }
    procedure FitView(Travel: Boolean = True);
    procedure NewDrawing(Seed: Boolean = True);
    procedure DropDraft;
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
    { every sheet of the drawing, a page each, rather than only this one }
    procedure DoPrintSheets(All: Boolean);
    procedure DoPrintFull(const PngDir: string);
    procedure PrintTileMarks(Col, Row, Cols, Rows, PitchW, PitchH,
      SW, SH: Integer; const ScaleName: string);
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
    procedure DoAction(A: Integer);
    function IconLit(Value: Integer): Boolean;
    function IconEnabled(Value: Integer): Boolean;
    function SliderValueAt(const Item: TDeckItem; X: Integer): Integer;
    function IndexOfSym(V: Integer): Integer;
    function InPalette(C: TColor): Boolean;

    { Is the cursor on something a dimension may be anchored to? }
    function DimAnchored: Boolean;
    function ZoomReading: string;
    function StatusLine: string;
    procedure WashFace(C: TCanvas; Face: Integer; const Col: TPix);
    procedure TraceOutlineVisible(C: TCanvas; Idx: Integer; const Col: TPix; PenW: Integer);
    procedure TraceOutlineInto(S: TArtSurface; Idx: Integer;
      const Col: TPix; PenW: Single);
    procedure TraceOutline(C: TCanvas; const Hi: TPointFArray;
      const Col: TPix);
    procedure PaintProOverlay(C: TCanvas);
    function TangentBulge(Pl: TPlane; out Bulge: Double): Boolean;
    procedure PaintGuideHover(C: TCanvas; I: Integer);
    { the cube: where it sits, what it draws, and the glide it starts }
    function CubeRect: TRect;
    function OverCube(X, Y: Integer): Boolean;
    function CubeZone(X, Y: Integer): Boolean;
    procedure PaintViewCube(C: TCanvas);
    procedure PaintCompass(C: TCanvas);
    function CubeMouse(X, Y: Integer; Down, Up: Boolean): Boolean;
    function TurnPivot: TP3;
    function FitTarget(OnSelection: Boolean; AzT, ElT: Double;
      out NewZoom, NewOX, NewOY: Double): Boolean;
    procedure GlideCamera(Az, El, Zoom, OX, OY: Double);
    procedure HoldTurn;
    procedure GlideTo(Az, El: Double);
    function OrbitSnapTarget(out T: TCubeTarget): Boolean;
    function ArcFillet(out F: TFillet; out Typed: Boolean): Boolean;
    function FilletCandidate(out F: TFillet): Boolean;
    function ArcDoubleClick(SX, SY: Integer): Boolean;
    procedure PaintUnderCursor(S: TArtSurface; OX, OY: Integer);
    procedure SnapOrbitToNearest;
    procedure StepCubeView(Key: Word);
    procedure StepGlide(Dt: Double);
    procedure PaintHeldPlane(C: TCanvas);

    procedure BuildSession(L: TStrings);
    procedure SaveDraft;
    function OnProgress(const What: string; Frac: Double): Boolean;
    function MachineText: string;
    procedure KeepReportCopy(const AName, Body: string; Shot: TStream);
    function LoadedWords: string;
    procedure EndBusy;
    function RestoreDraft: Boolean;
    procedure WriteHandoff;
    function RestoreHandoff: Boolean;
    function LoadExample: Boolean;
    procedure WriteExamples;
    procedure WriteJigs;
    procedure LoadSettings;
    procedure ApplyCommandLine;
    procedure FollowScreenSize;
    procedure SaveSettings;
    procedure ShowAbout;
    procedure ShowFacts(const Title, AText: string);
    procedure ShowLongText(const Title, AText: string);
  end;

var
  MainForm: TMainForm;

implementation

uses
  FileUtil, Clipbrd, uHelpDocs, uHelpView;

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
  { The rest of the tools, behind one door.  See MAIN_TOOLS. }
  POP_MORE   = 7;
  { Every typed command, with a word about each.  The command bar is the
    fastest way to work this program and the slowest to find out about -
    everything in it was something you had to already know.  This is the
    arrow beside the prompt, and it is the one list in the program that is
    too long to fit, so it scrolls. }
  POP_CMDS   = 8;

type
  { a typed command, as the list shows it }
  TCmdItem = record
    Name: string;      { what to type, without the slash }
    Hint: string;      { what it does, in a few words }
    Arg: Boolean;      { True when it wants something after it }
    { One made-up line showing the command with something after it, shown
      in place of the hint while the row is highlighted.  Only the ones
      that take something have one; the rest leave it empty and go on
      showing what they do, because "/undo" is not an example of anything.

      A trailing field may be left off a record constant in FPC and comes
      out empty, which is why sixty of the rows below say nothing about
      it. }
    Eg: string;
    { The other words that run it, space separated - /e for /erase, /tape
      for /measure.  Typing one finds the row, and using one counts as
      using the command, so it floats up the list like the name would.
      tests/cmdcheck.pas holds this to RunCommand: every word here has to
      be answered by the same branch as the name. }
    Also: string;
  end;

const
  { Alphabetical, because that is where a thing is when you do not know what
    it is called; the ones you have used lately float to the top, because
    that is where a thing is when you do.

    One row per action rather than one per word - /erase, /e and /del are the
    same thing and three rows of it would be a worse list.  The other words
    are in Also: typing one finds the row, and the row says so. }
  CMD_LIST: array[0..85] of TCmdItem = (
    (Name: 'all';        Hint: 'select everything on this sheet';      Arg: False; Eg: ''; Also: 'selectall'),
    (Name: 'arc';        Hint: 'the arc tool';                          Arg: False; Eg: ''; Also: 'a'),
    (Name: 'back';       Hint: 'look from behind';                      Arg: False),
    (Name: 'center';     Hint: 'center it on the floor at 0,0';         Arg: False; Eg: ''; Also: 'middle'),
    (Name: 'circle';     Hint: 'the circle tool';                       Arg: False; Eg: ''; Also: 'c'),
    (Name: 'clear';      Hint: 'empty this sheet';                      Arg: False),
    (Name: 'close';      Hint: 'close this sheet';                      Arg: False),
    (Name: 'corner';     Hint: 'look from a corner';                    Arg: False),
    (Name: 'cube';       Hint: 'the view cube: on, off, tl/tr/bl/br';    Arg: False;
                         Eg:   '/cube tr';
                         Also: 'viewcube'),
    (Name: 'cut';        Hint: 'the plan slice: two heights, or "all"'; Arg: True;
                         Eg:   '/cut 0 9''';
                         Also: 'slice'),
    (Name: 'detach';     Hint: 'move a line away on its own: on, off';  Arg: False;
                         Eg:   '/detach on';
                         Also: 'loose'),
    (Name: 'dimension';  Hint: 'the dimension tool';                    Arg: False; Eg: ''; Also: 'dim'),
    (Name: 'drill';      Hint: 'push a shape right through';            Arg: False; Eg: ''; Also: 'bore punch'),
    (Name: 'edit';       Hint: 'work inside the picked group';          Arg: False; Eg: ''; Also: 'opengroup'),
    (Name: 'erase';      Hint: 'the eraser';                            Arg: False; Eg: ''; Also: 'e del'),
    (Name: 'explode';    Hint: 'take the picked group apart';           Arg: False; Eg: ''; Also: 'ungroup'),
    (Name: 'fit';        Hint: 'zoom until it all shows';               Arg: False; Eg: ''; Also: 'zoom'),
    (Name: 'forget';     Hint: 'forget the areas seen, and work them out again'; Arg: False),
    (Name: 'front';      Hint: 'look from the front';                   Arg: False),
    (Name: 'grid';       Hint: 'the ruled paper, on or off';            Arg: False),
    (Name: 'group';      Hint: 'make what is picked a group';           Arg: False; Eg: ''; Also: 'makegroup'),
    (Name: 'guides';     Hint: 'clear the guide lines';                 Arg: False; Eg: ''; Also: 'noguides'),
    (Name: 'help';       Hint: 'about this program';                    Arg: False; Eg: ''; Also: '?'),
    (Name: 'hide';       Hint: 'put away the picked groups, or every group so named';  Arg: True;
                         Eg:   '/hide labels';
                         Also: 'putaway'),
    (Name: 'holes';      Hint: 'draw where a solid is not closed';      Arg: False; Eg: ''; Also: 'openedges notclosed'),
    (Name: 'info';       Hint: 'the entity panel: on, off';            Arg: False;
                         Eg:   '/info on';
                         Also: 'entity properties'),
    (Name: 'iso';        Hint: 'the isometric view';                    Arg: False),
    (Name: 'jig';        Hint: 'run the picked group''s jig again, or every jig';  Arg: False; Eg: ''; Also: 'jigs'),
    (Name: 'keep';       Hint: 'the last tape run, kept as a dimension';   Arg: False; Eg: ''; Also: 'keepdim'),
    (Name: 'leave';      Hint: 'close the open group';                  Arg: False; Eg: ''; Also: 'closegroup'),
    (Name: 'left';       Hint: 'look from the left';                    Arg: False),
    (Name: 'light';      Hint: 'light that follows the camera: on, off';  Arg: False;
                         Eg:   '/light off';
                         Also: 'lamp'),
    (Name: 'line';       Hint: 'the line tool';                         Arg: False; Eg: ''; Also: 'l'),
    (Name: 'lock';       Hint: 'lock the picked group';                 Arg: False),
    (Name: 'manual';     Hint: 'open the manual';                       Arg: False; Eg: ''; Also: 'docs'),
    (Name: 'measure';    Hint: 'the tape measure';                      Arg: False; Eg: ''; Also: 'm tape'),
    (Name: 'move';       Hint: 'the move tool';                         Arg: False; Eg: ''; Also: 'mv'),
    (Name: 'name';       Hint: 'call the picked group something';      Arg: True;
                         Eg:   '/name Left knob';
                         Also: 'rename'),
    (Name: 'new';        Hint: 'a new sheet';                           Arg: False; Eg: ''; Also: 'tab'),
    (Name: 'offset';     Hint: 'a parallel copy of a face''s edge';     Arg: False; Eg: ''; Also: 'f'),
    (Name: 'orbit';      Hint: 'the free camera';                       Arg: False; Eg: ''; Also: 'spin'),
    (Name: 'origin';     Hint: 'put the view back on 0,0,0';            Arg: False; Eg: ''; Also: 'o'),
    (Name: 'plan';       Hint: 'look straight down';                    Arg: False; Eg: ''; Also: '2d flat'),
    (Name: 'plane';      Hint: 'the working plane: xy, xz or yz';       Arg: True;
                         Eg:   '/plane xz'),
    (Name: 'postcard';   Hint: 'the once-only note to the authors, to send or read';  Arg: False; Eg: ''; Also: 'hello'),
    (Name: 'print';      Hint: 'this sheet - or "all", or "full"';      Arg: True;
                         Eg:   '/print all'),
    (Name: 'protractor'; Hint: 'lay a guide at an angle';               Arg: False; Eg: ''; Also: 'angle'),
    (Name: 'push';       Hint: 'push or pull a face';                   Arg: False; Eg: ''; Also: 'pull pushpull p'),
    (Name: 'quick';      Hint: 'quick frames while the camera moves';   Arg: False),
    (Name: 'radiant';    Hint: 'lay radiant tube out over the selected floor'; Arg: False; Eg: ''; Also: 'pex hydronic'),
    (Name: 'rebuild';    Hint: 'work the faces out again';              Arg: False),
    (Name: 'rect';       Hint: 'the rectangle tool';                    Arg: False; Eg: ''; Also: 'rectangle r'),
    (Name: 'redo';       Hint: 'put back what was undone';              Arg: False),
    (Name: 'reface';     Hint: 'throw the flat faces away and rebuild'; Arg: False; Eg: ''; Also: 'rebuildfaces'),
    (Name: 'regions';    Hint: 'report the flat areas found';           Arg: False),
    (Name: 'rendertime'; Hint: 'time a whole frame';                    Arg: False),
    (Name: 'replay';     Hint: 'play back a session from a report';     Arg: False;
                         Eg:   '/replay session.txt'),
    (Name: 'report';     Hint: 'send a bug report, with a picture';     Arg: False; Eg: ''; Also: 'bug'),
    (Name: 'resize';     Hint: 'retype a picked dimension';             Arg: True;
                         Eg:   '/resize 4''6"';
                         Also: 'size'),
    (Name: 'reverse';    Hint: 'turn the picked faces over';            Arg: False; Eg: ''; Also: 'rev flip'),
    (Name: 'revolve';    Hint: 'spin or sweep a face into a solid';     Arg: False; Eg: ''; Also: 'followme follow lathe'),
    (Name: 'right';      Hint: 'look from the right';                   Arg: False),
    (Name: 'rotate';     Hint: 'the rotate tool';                       Arg: False; Eg: ''; Also: 'q turn'),
    (Name: 'save';       Hint: 'save the drawing';                      Arg: False),
    (Name: 'saveas';     Hint: 'save it under a new name';              Arg: False),
    (Name: 'scale';      Hint: 'the print scale: 1/4", 1" and so on';   Arg: True;
                         Eg:   '/scale 1/4"'),
    (Name: 'select';     Hint: 'the select tool';                       Arg: False; Eg: ''; Also: 's'),
    (Name: 'session';    Hint: 'what has happened, most recent last';   Arg: False;
                         Eg:   '/session session.txt';
                         Also: 'acts'),
    (Name: 'show';       Hint: 'bring back what was put away - all, or the groups so named';  Arg: True;
                         Eg:   '/show labels';
                         Also: 'unhide'),
    (Name: 'source';     Hint: 'this sheet as its text, picked both ways';  Arg: False;
                         Eg:   '/source complete off';
                         Also: 'src text-view'),
    (Name: 'spool';      Hint: 'the pipe spool scratchpad';             Arg: False; Eg: ''; Also: 'pipe scratchpad'),
    (Name: 'state';      Hint: 'what a report says about the program right now'; Arg: False),
    (Name: 'sysinfo';    Hint: 'what a report says about this machine'; Arg: False; Eg: ''; Also: 'machine'),
    (Name: 'text';       Hint: 'a note on the drawing';                 Arg: False; Eg: ''; Also: 'note n'),
    (Name: 'threads';    Hint: 'background work, on or off';            Arg: False),
    (Name: 'timings';    Hint: 'time each step: on, then again to see them'; Arg: False;
                         Eg:   '/timings show'),
    (Name: 'top';        Hint: 'look from above';                       Arg: False; Eg: ''; Also: 'down'),
    (Name: 'toy';        Hint: 'the etch-a-sketch this program began as'; Arg: False; Eg: ''; Also: 'etch etchasketch'),
    (Name: 'tozero';     Hint: 'put its near bottom corner on 0,0,0';   Arg: False; Eg: ''; Also: 'zero tuck'),
    (Name: 'transition'; Hint: 'build a duct fitting';                  Arg: False; Eg: ''; Also: 'trans fitting elbow tee'),
    (Name: 'undo';       Hint: 'undo the last thing';                   Arg: False; Eg: ''; Also: 'u'),
    (Name: 'unfold';     Hint: 'lay a piece out flat';                  Arg: False; Eg: ''; Also: 'layout'),
    (Name: 'units';      Hint: 'feet and inches, or millimeters';       Arg: False),
    (Name: 'unlock';     Hint: 'unlock the picked group';               Arg: False),
    (Name: 'update';     Hint: 'look for a newer build';                Arg: False;
                         Eg:   '/update never';
                         Also: 'upgrade'),
    (Name: 'whatsnew';   Hint: 'the release notes';                     Arg: False; Eg: ''; Also: 'changes'));

const

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
  { Past this many picked, the selection overlay stops asking the depth
    buffer whether each run is visible and just outlines the edges.  An orbit
    with thirty thousand things picked rebuilds the layer every frame, and at
    that size the tracing is the cost again - in the rasteriser rather than
    in the canvas, but still the cost. }
  SEL_TRACE_MAX = 3000;

  ACT_GUIDES  = 17;
  ACT_NOGUIDE = 18;

  UNDO_LEVELS     = 16;
  KNOB_PX_PER_RAD = 58.0;
  BASE_SPEED      = 210.0;
  { where the cube can sit, in the words the command takes }
  CORNER_NAME: array[0..3] of string =
    ('top left', 'top right', 'bottom left', 'bottom right');

  { How far the view may be wound in and out.

    It was a twentieth to forty times - eight hundred to one, which sounds
    generous and is not.  SketchUp goes from a site to a screw thread and
    people expect that; at forty times, a sixteenth of an inch on a drawing
    at an inch to the foot is a couple of dozen pixels, which is enough to
    see and not enough to work on.

    Bounded rather than free, because every point on the screen is
    OX + dot * Ppu and the numbers have to stay in a range the rasteriser and
    the depth mesh can work in.  A million to one is room enough for a site
    plan at one end and a weld bead at the other. }
  ZOOM_MIN        = 0.002;
  ZOOM_MAX        = 2000.0;

  TICK_MS         = 16;
  { how long a camera move takes.  Long enough to follow, short enough that
    nobody waits for it - the same third of a second a window manager gives
    a maximise. }
  GLIDE_SECONDS   = 0.34;
  MIN_PEN         = 1;
  MAX_PEN         = 40;
  SNAP_PX         = 16.0;   // pulling onto a point on the drawing
  INFER_PX        = 7.0;    // lining up with one that is somewhere else
  FAST_PX_S       = 600.0;  // moving quicker than this, alignments wait
  KEEP_FACTOR     = 1.7;    // an alignment taken holds this much further out
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
  { How far the view turns for a pixel of drag, pressed halfway out from
    the middle of the view; OrbitGainAt scales it from half of this at the
    middle to twice at the edge.  It was a flat 0.010 - a half turn in 314
    pixels - and set beside SketchUp on 21 September that was about twice
    as fast as theirs for a press in the middle. }
  ORBIT_RAD_PX    = 0.006;
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
  { the first two presets are the paper modes; the button cycles from here }
  FIRST_CAMERA_PRESET = 2;
  VIEW_ARROW_W = 30;    // the drop-down arrow's share of the view button

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
     ikTText, ikTErase, ikTMeasure, ikDim, ikTOrbit, ikTOffset, ikTRotate,
     ikTProtractor, ikTDrill, ikTFollow);

  TOOL_NAMES: array[TProTool] of string =
    ('SELECT', 'MOVE', 'LINE', 'RECT', 'ARC', 'CIRCLE', 'PUSH/PULL', 'TEXT',
     'ERASE', 'MEASURE', 'DIMENSION', 'ORBIT', 'OFFSET', 'ROTATE',
     'PROTRACTOR', 'DRILL', 'REVOLVE');

  { The tools in three groups of four, laid out two rows deep, so a group
    reads as a group and every name has room to be read.  The grouping is
    SketchUp's: what you pick and change with, what you draw with, and what
    you measure and look with. }
  { Three groups: working on what is there, drawing new things, saying what
    they are.  The first has three across because it has five in it - orbit
    belongs with getting about rather than with drawing, and the deck is the
    only place a tool is discoverable at all. }
  { What a stranger meets, and what waits behind a door.

    The whole pitch is that somebody opens this and can draw something to
    scale without being taught.  Fourteen buttons at the same weight is not
    that: it is a wall, and a wall is what makes people close a CAD program
    in the first minute.  So the strip carries the ten a drawing is actually
    made of - pick, the five shapes, lift it, move it, rub it out, measure it
    - and the rest live behind MORE, which is a door rather than a hiding
    place.  Everything is still one click from where it was.

    Orbit is in the main set although it draws nothing, because getting round
    the back of the model is half of what makes the 3D worth having and a
    laptop without a middle button has no other way in. }
  MAIN_TOOLS: array[0..13] of TProTool =
    (ptSelect,
     ptLine, ptRect, ptCircle, ptArc,
     ptPush, ptFollow,
     ptMove, ptErase,
     ptMeasure, ptProtractor, ptDim, ptText,
     ptOrbit);
  { Where a line goes across the strip: after this many buttons.  The groups
    are what a tool is FOR - pick something, draw something, stand it up,
    change it, measure and say what it is, get about - and a line between
    them is what turns a column of thirteen into six short lists. }
  MAIN_BREAKS: array[0..4] of Integer = (1, 5, 7, 9, 13);
  { The three that are neither common nor obvious.  Two have come back out of
    here already.  Measure and the protractor went on the first day the strip
    existed - measuring is not a specializt act, it is most of why somebody
    opened the program.  Revolve went on the second, and for a worse reason:
    a friend showed the owner a lathe in another program and he came to ask why we
    did not have one.  We have had one since the sixth of September.  It was
    called FOLLOW ME, which is SketchUp's name for sweeping along a path and
    nobody else's name for anything, and it was behind this door.  Beside
    push/pull now, which is the other tool that turns a flat thing into a
    solid one, and called what everybody but SketchUp calls it. }
  MORE_TOOLS: array[0..2] of TProTool =
    (ptRotate, ptOffset, ptDrill);

  GRP_COLS: array[0..2] of Integer = (3, 3, 3);
  GRP_N:    array[0..2] of Integer = (6, 5, 6);
  TOOL_GROUPS: array[0..2, 0..5] of TProTool =
    ((ptSelect, ptMove, ptRotate, ptErase, ptPush, ptDrill),
     (ptLine, ptRect, ptCircle, ptArc, ptFollow, ptSelect),
     (ptMeasure, ptProtractor, ptDim, ptText, ptOffset, ptOrbit));

  TOOL_HINTS: array[TProTool] of string = (
    'Select - click to pick, drag a box for several.  Ctrl adds, Shift ' +
      'toggles, Ctrl+Shift takes away.  (Space)',
    'Move - pick a point on what is selected, then click where it goes.  ' +
      'Hold Ctrl to leave a copy behind.  (M)',
    'Line - click a start point, then click the end or just type a length.  In a 3D view the arrows lock the plane first: left or right for upright, up or down for flat, Esc to let go.  A locked plane holds every point of the shape to it.',
    'Rectangle - click two opposite corners, or type 12''x8''.  Makes a face.',
    'Arc - pick two points, then pull the middle out.  Joins two loose ends.',
    'Circle - pick the center, then type or drag the radius.',
    'Push/pull - click a face and type how far to lift it.  Close a loop of ' +
      'lines to make a face.',
    'Text - click where the note goes and type it.',
    'Erase - click an edge to delete it; a face goes when its edges do.',
    'Measure - click two points and read the distance between them.',
    'Dimension - click two points, then drag away to place the line.',
    'Orbit - drag to spin.  Shift pans, Ctrl clicks into the nearest view.  (O)',
    'Offset - click a face, then move in or out and click, or type a wall ' +
      'thickness.  (F)',
    'Rotate - click the center, a point to measure from, then swing to the ' +
      'angle or type it (34.1, or 8:12 for a slope).  Arrows pick the ' +
      'plane, Ctrl leaves a copy.  (Q)',
    'Protractor - click the vertex, a point to measure from, then the ' +
      'angle, or type it.  Lays a guide line at that angle.',
    'Drill - push a shape through everything.  Where the hole crosses a ' +
      'tunnel already there, both are cut open into each other.  (B)',
    'Revolve - spin a face round an axis into a solid.  Draw the outline of ' +
      'half of it, click the face, then click two points on the axis - or a ' +
      'circle to follow round.  Type an angle first for a part turn.  This ' +
      'is SketchUp''s Follow Me, and it will also sweep a face along a line.');

  { How close the cursor has to be to a guide before it is the thing being
    pointed at.  Tighter than an edge on purpose - see PickAt. }
  GUIDE_PICK_PX = 4;

  TOY_HINT = 'Arrow keys or the dials draw.  Shift to go fast, Ctrl to creep.';

  { TColor is $00BBGGRR }
  PALETTE: array[0..11] of TColor = (
    $1A1A1A, $FFFFFF, $A8A4A0, $2A2AE2, $1A7AFF, $1AC6FF,
    $3CDC7A, $5AB422, $C8C81E, $F06034, $EB5096, $AA3CEB);

{ ======================================================================== }
{ small helpers                                                             }
{ ======================================================================== }

{ A dot for a decimal point whatever the machine is set to - one report came
  from a comma locale, and a log it could not parse back would be no log. }
function ActFS: TFormatSettings;
begin
  Result := DefaultFormatSettings;
  Result.DecimalSeparator := '.';
end;

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
var
  Base: TP3;
begin
  Base := FCur;
  { A plane you locked on purpose is pinned to where the shape started, not
    to where the cursor has wandered to.

    The offset of the working plane came from FCur, which is the last point
    the cursor resolved to - so the plane traveled with the cursor.  Draw
    three sides of an outline, have one inference put a point a foot off the
    plane, and the plane goes with it: every corner after that is on a
    different plane, the outline never closes, and no face is ever made.
    That is what defeated the owner trying to draw a wine glass upright on
    13 September, and it is why he ended up drawing it flat on the floor
    where there is nothing to drift onto.

    Pinned to the first point of the shape instead, for as long as a shape is
    being drawn.  Nothing can move it while it matters. }
  if FPlaneHeld and (FStage > 0) then Base := FP1;
  { In a plan with a cut, the bottom of the slice is the drawing plane.

    One number doing both jobs, and that is not a shortcut - it is what a
    floor plan means.  The floor of what you can see is the floor you are
    drawing on, and things go up from it.  Set the bottom to 9'-0" and you
    are on the second story: seeing it, and drawing on it. }
  if (FD.View = vkPlan) and FD.SliceOn then Base.Z := FD.SliceLo;
  Result := Unproject(Proj, SX, SY, FD.Plane, Base);
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
  I, BestAxis, Near: Integer;
  Tol, Best, KeepTol: Double;
  PrevGuide: Boolean;
  PrevFrom: TP3;
  W, Wf, AxRef, AxPt, EdgeP, EdgeA, EdgeB, MidP, AxSnapP: TP3;
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
      { levelling with some other point waits for a slow hand; a point you
        rested on is asked for and does not }
      if FMoveSpeed <= FAST_PX_S then
      begin
        FD.Doc.SnapPoints(APts);
        for I := 0 to High(APts) do TryLevel(APts[I], INFER_PX);
        if FStage > 0 then TryLevel(FP1, INFER_PX);
      end;
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
  { One direction offered from a reference point.  Kind is 0, 1 or 2 for the
    three axes, 3 for parallel to the reference edge and 4 for perpendicular
    to it - all the same arithmetic, all measured on screen. }
  procedure DirTry(const R, AD0: TP3; Kind: Integer);
  var
    Off, Along, T, LenSq: Double;
    PR, PA: TPointF;
    AD: TP3;
    UX, UY, VX, VY: Double;
  begin
    AD := Norm3(AD0);
    if Sqr(AD.X) + Sqr(AD.Y) + Sqr(AD.Z) < 0.5 then Exit;
    PR := ScreenOf(R);
    begin
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
      if LenSq < Sqr(0.2 * Ppu) then Exit;

      VX := SX - PR.X;
      VY := SY - PR.Y;
      Along := (VX * UX + VY * UY) / LenSq;      // in axis units
      Off := Abs(VX * UY - VY * UX) / Sqrt(LenSq);

      if Abs(Along) * Sqrt(LenSq) < AXIS_MIN_PX then Exit;
      if Off < AxPx then
      begin
        { belt and braces: a point that is not a real number, or is further
          out than any drawing could be, is not an answer }
        T := Along;
        if IsNan(T) or IsInfinite(T) or (Abs(T) > 1E9) then Exit;
        AxPx := Off;
        AxIdx := Kind;
        AxRef := R;
        { the point on the axis nearest the cursor, in the model }
        AxPt := P3(R.X + AD.X * T, R.Y + AD.Y * T, R.Z + AD.Z * T);
      end;
    end;
  end;

  { the three axes, from a reference point }
  { Where the axis through R crosses the edge A-B, if the two pass within
    a hair of each other: the point on the edge. }
  function AxisMeetsEdge(const R: TP3; Axis: Integer; const A, B: TP3;
    out P: TP3): Boolean;
  var
    D, E, W: TP3;
    A2, B2, D2, DD, EE, DE, T, U, Den: Double;
  begin
    Result := False;
    case Axis of
      0: D := P3(1, 0, 0);
      1: D := P3(0, 1, 0);
    else D := P3(0, 0, 1);
    end;
    E := P3(B.X - A.X, B.Y - A.Y, B.Z - A.Z);
    W := P3(A.X - R.X, A.Y - R.Y, A.Z - R.Z);
    DD := Dot3(D, D); EE := Dot3(E, E); DE := Dot3(D, E);
    Den := DD * EE - DE * DE;
    if (EE < 1E-18) or (Abs(Den) < 1E-12 * DD * EE) then Exit;   { parallel }
    A2 := Dot3(D, W); B2 := Dot3(E, W);
    T := (A2 * EE - B2 * DE) / Den;         { along the axis }
    U := (A2 * DE - B2 * DD) / Den;         { along the edge, 0..1 }
    if (U < -1E-9) or (U > 1 + 1E-9) then Exit;
    P := P3(A.X + E.X * U, A.Y + E.Y * U, A.Z + E.Z * U);
    { the two lines have to actually meet, not just pass near }
    D2 := Sqr(R.X + D.X * T - P.X) + Sqr(R.Y + D.Y * T - P.Y) + Sqr(R.Z + D.Z * T - P.Z);
    Result := D2 < 1E-12;
  end;

  procedure AxisTry(const R: TP3);
  begin
    DirTry(R, P3(1, 0, 0), 0);
    DirTry(R, P3(0, 1, 0), 1);
    DirTry(R, P3(0, 0, 1), 2);
  end;

  { parallel to the reference edge, and square to it in the working plane -
    SketchUp's magenta pair }
  procedure ParPerpTry(const R: TP3);
  var
    AU, AV, Nm, Perp: TP3;
  begin
    if not FParHas then Exit;
    DirTry(R, FParDir, 3);
    PlaneAxes(FD.Plane, AU, AV);
    Nm := Cross3(AU, AV);
    Perp := Cross3(Nm, FParDir);
    if Sqr(Perp.X) + Sqr(Perp.Y) + Sqr(Perp.Z) > 1E-12 then
      DirTry(R, Perp, 4);
  end;

begin
  PrevGuide := FGuide;
  PrevFrom := FGuideFrom;
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
    something you use - which is what It was noticed against SketchUp, where a
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
     FD.Doc.EdgeUnder(Proj, SX, SY, EDGE_PX * FUIScale, EdgeP,
                      EdgeA, EdgeB, EdgeI) then
  begin
    { The middle of that edge, worked out here rather than kept in the snap
      cache.

      A drawn line has its midpoint in the cache like any other named point.
      One side of a face's outline has not, and could not cheaply: a drawing
      of a few hundred faces has thousands of sides, and every one of them in
      the cache is another point to project every time the camera moves.  But
      the edge under the cursor is already known by the time we get here, so
      its middle is two additions and a comparison - no cache, no cost when
      the cursor is not near one.

      This is why the tape measure would not find the center of a line on
      anything built of faces. }
    MidP := P3((EdgeA.X + EdgeB.X) / 2, (EdgeA.Y + EdgeB.Y) / 2,
               (EdgeA.Z + EdgeB.Z) / 2);
    SP := ScreenOf(MidP);
    if Sqr(SX - SP.X) + Sqr(SY - SP.Y) <= Sqr(LOCK_PX * FUIScale) then
    begin
      FSnapKind := snMidpoint;
      FStickOn := True;
      FStickPt := MidP;
      FStickKind := snMidpoint;
      Exit(MidP);
    end;
    { On the edge AND on an axis through the start: the point is where the
      axis crosses the edge - a definite place, exactly on both.

      21 September: a line started an inch and a half in from one side of a
      square, run across to the other side along the green, "and that point
      ends up not being exactly 1.5 inches like the other end".  On Edge
      took the point here, as the place on the far edge nearest the
      pointer, which slides along the edge with every pixel; the axis code
      below never ran, and the green came from a looser check drawn on top.
      Square means square: the axis is held, and the edge says how far. }
    if (FStage > 0) and (FDirLock < 0) and (FInferMode = imAll) then
    begin
      AxIdx := -1;
      AxPx := AXIS_PX;
      AxPt := Wf;
      AxRef := Wf;
      FParPerp := 0;
      AxisTry(FP1);
      if FLockOn then AxisTry(FLockPt);
      if (AxIdx >= 0) and (AxIdx <= 2) and
         AxisMeetsEdge(AxRef, AxIdx, EdgeA, EdgeB, MidP) then
      begin
        FAxisLock := AxIdx;
        FAxisFrom := AxRef;
        FSnapKind := snOnEdge;
        Exit(MidP);
      end;
    end;
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
  if (not PtOK) and (FInferMode = imAll) and
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
  FSnapFromPt := False;
  FParPerp := 0;
  if FDirLock < 0 then
  begin
    { Alt says which of these are on offer - see TInferMode }
    if FInferMode = imAll then
    begin
      if FStage > 0 then AxisTry(FP1);
      if FLockOn then AxisTry(FLockPt);
    end;
    if FInferMode in [imAll, imParPerp] then
    begin
      if FStage > 0 then ParPerpTry(FP1);
      if FLockOn then ParPerpTry(FLockPt);
    end;
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
  { And then a second report, 21 September: drawing a rectangle inside a
    rectangle, the line green, the far end resting on a corner of the
    outer one - and the corner took it clean off the axis, so the "square"
    line came out three-sixteenths out of true from end to end.  "If it
    snaps to be aligned with an axis it better only be able to draw it on
    that point and keep it parallel."

    So the corner no longer takes the point off the guide: it says how far
    ALONG the guide.  The point handed back is the place on the axis
    nearest the corner - SketchUp's own rule, which it draws as a dotted
    line from the corner to the axis.  A corner that lies on the axis, the
    dimensioning case the rule above was written for, projects to itself
    and is had exactly as before.  A corner off the axis gives the run its
    length and the axis keeps its direction, which is what square and
    plumb mean. }
  if PtOK and (AxIdx >= 0) and (AxIdx <= 2) and
     (Hit.Kind in [snEndpoint, snCross, snCenter, snMidpoint, snOrigin]) then
  begin
    AxPt := AxRef;
    case AxIdx of
      0: AxPt.X := Hit.P.X;
      1: AxPt.Y := Hit.P.Y;
    else AxPt.Z := Hit.P.Z;
    end;
    FSnapFromPt := True;
  end
  else if PtOK and (AxIdx >= 3) and
     (Hit.Kind in [snEndpoint, snCross, snCenter, snMidpoint, snOrigin]) then
    AxIdx := -1;

  if AxIdx >= 3 then
  begin
    { Parallel or square to an edge.  The point is taken straight off the
      ray - there are no other two coordinates to hold, since the direction
      is not an axis - and the distance along it still snaps. }
    W := AxPt;
    FParPerp := AxIdx - 2;
    FAxisLock := -1;
    FAxisFrom := AxRef;
    FSnapKind := snGrid;
    Exit(W);
  end;

  if AxIdx >= 0 then
  begin
    { The distance along the axis still snaps, so a riser lands on a round
      number; the other two coordinates come from the reference point, which
      is what puts the result exactly on the axis. }
    { the distance along the axis snaps to the grid - unless a corner set
      it, and then it is the corner's, to the inch and the fraction }
    if FSnapFromPt then W := AxPt else W := SnapToGrid(AxPt);
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
  { A hand moving fast is going somewhere, not lining up: no nudges until
    it slows.  One already taken is kept while the cursor stays near it -
    further out than it took to get it, so it does not flicker on and off
    along the boundary. }
  if PrevGuide then
  begin
    KeepTol := Tol * KEEP_FACTOR;
    Near := 0;
    if Abs(W.X - PrevFrom.X) <= KeepTol then Inc(Near);
    if Abs(W.Y - PrevFrom.Y) <= KeepTol then Inc(Near);
    if Abs(W.Z - PrevFrom.Z) <= KeepTol then Inc(Near);
    if (Near = 2) and (Dist(W, PrevFrom) * Ppu >= 18) then
    begin
      if Abs(W.X - PrevFrom.X) <= KeepTol then W.X := PrevFrom.X;
      if Abs(W.Y - PrevFrom.Y) <= KeepTol then W.Y := PrevFrom.Y;
      if Abs(W.Z - PrevFrom.Z) <= KeepTol then W.Z := PrevFrom.Z;
      FGuideFrom := PrevFrom;
      FGuide := True;
      Exit(W);
    end;
  end;
  if FMoveSpeed > FAST_PX_S then Exit(W);

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
var
  HF: Integer;
  HP, N, Raw: TP3;
  RU1, RV1, RU2, RV2: Double;
begin
  Result := ResolveSnapRaw(SX, SY);
  { Held to the face - unless the point got where it is by running up an
    axis, in which case the two constraints contradict each other and the
    axis is the one that was asked for.

    Being on a horizontal face and on the blue axis are not both possible,
    and flattening won: the point came back off the axis onto the face while
    FAxisLock still said it was on it.  The reading said LOCKED TO BLUE, the
    guide was drawn along the axis, and the line itself went nowhere - anchor
    and point landed on the same spot, which is the zero length one report
    came in carrying.  Picking the tool again cleared the held plane and it
    worked, which is exactly the shape of a fault that lives in tool state
    rather than in the axis code.

    Standing a gable up off the floor you just drew is the ordinary thing to
    want, and it is what SketchUp does: infer up the blue axis and you leave
    the face.  So the axis wins.  When the axis lies in the plane anyway the
    hold would have changed nothing, so nothing is lost by skipping it.

    A named point wins for the same reason, and it took a second report to
    see it.  Building a gable end on a barn, the cursor sat four pixels off
    the endpoint at the top of a rafter and the reading said ENDPOINT - and
    the point it handed back was seventy-five pixels lower, down on the eave,
    because the held plane was the top of the wall and flattening dropped
    twelve feet of Z on the way past.  The label is set before the flatten,
    so it named a point the answer was nowhere near, which is what made it
    read as a snapping fault rather than a plane one.

    An endpoint is a piece of geometry somebody drew and then aimed at.  It
    is the most definite thing the drawing has to say, and no plane the tool
    happens to still be holding is more definite than that.  The inferences
    that are only ever a guess about where the cursor is - on an axis, on a
    face, on the grid - still get held, which is the case the hold was
    written for. }
  if (FAxisLock < 0) and not (FSnapKind in [snEndpoint, snMidpoint, snCenter,
       snCross, snSubMid, snOrigin, snQuadrant]) then
    Result := HeldToFace(Result);
  { A plane locked with the arrows is not a guess, and nothing gets to
    overrule it.

    That is the whole difference between this and the hold above.  The hold
    comes of resting on a face - the program noticing something and offering
    it - so a corner somebody deliberately aimed at beats it.  This is
    somebody pressing left and being told "drawing upright, on the XZ
    plane".  There is nothing to beat: they said where they are drawing, and
    an endpoint somewhere off it is not a better answer, it is the thing that
    stops the outline ever closing.

    An axis lock still wins, because that is the same kind of statement made
    more recently. }
  if FPlaneHeld and (FStage > 0) and (FAxisLock < 0) then
    case FD.Plane of
      plXY: Result.Z := FP1.Z;
      plXZ: Result.Y := FP1.Y;
      plYZ: Result.X := FP1.X;
    end;
  { A rectangle may not have a side of no length, whatever any inference
    thinks.

    Every alignment in the program is built for a line, where being pulled
    level with the point you started from is the whole idea.  For a rectangle
    it is fatal: level with the first corner in one direction means a side of
    zero, which is not a rectangle, so the tool says "a rectangle needs two
    sides" and throws it away.  On screen there is nothing to see - the
    corner is a couple of inches off where the pointer is and the inference
    is doing what it was written to do - so it reads as the tool refusing to
    work for no reason, on and off, depending on which way you happened to
    drag.  Reported as "doesn't get it right all the time", which is exactly
    how it behaves.

    So: if an inference has flattened a side that the bare cursor had, that
    side goes back.  The other one keeps whatever it was given, which is what
    lets a rectangle still line up with something along one direction. }
  if (FTool = ptRect) and (FStage = 1) and (FD.Plane <> plFree) then
  begin
    { on the grid, like everything else - restoring the bare cursor would
      give a side of 2 11/16" where the drawing snaps to inches.  And if the
      grid itself flattens it, the side really is shorter than the drawing
      can express, and the message below says so. }
    Raw := SnapToGrid(WorldAt(SX, SY));
    RectSides(FP1, Result, FD.Plane, RU1, RV1);
    RectSides(FP1, Raw, FD.Plane, RU2, RV2);
    if (RU1 <= 1E-9) and (RU2 > 1E-9) then
      case FD.Plane of
        plYZ: Result.Y := Raw.Y;
      else    Result.X := Raw.X;
      end;
    if (RV1 <= 1E-9) and (RV2 > 1E-9) then
      case FD.Plane of
        plXY: Result.Y := Raw.Y;
      else    Result.Z := Raw.Z;
      end;
  end;

  { A free point that is resting on a face is On Face, and says so - the way
    SketchUp does.  Only when the point really is on that face's plane: a
    cursor drawing in mid air with a face somewhere behind it is not on it. }
  if (FSnapKind = snGrid) and FD.Doc.FaceUnder(Proj, SX, SY, HF, HP) then
  begin
    N := Norm3(FD.Doc.FaceNormal(HF));
    if Abs(Dot3(N, P3(Result.X - HP.X, Result.Y - HP.Y, Result.Z - HP.Z))) < 1E-6 then
      FSnapKind := snOnFace;
  end;
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
  { and out loud, for a hunt run under the harness - the trail is only ever
    read from a report }
  if GetEnvironmentVariable('HSK_TRACE') <> '' then
  begin
    WriteLn(StdErr, 'TRACE ', What);
    Flush(StdErr);
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  I: Integer;
  A: string;
begin
  Application.OnException := @ReportCrash;
  FExportDirs := TStringList.Create;
  Randomize;
  { one more start, for the postcard's sake - see uHello }
  CountLaunch;
  FRunTag := IntToHex(GetTickCount64 and $FFFFFF, 6) + IntToHex(Random($10000), 4);
  for I := 1 to ParamCount do
  begin
    A := ParamStr(I);
    if Pos('--updated-from=', LowerCase(A)) = 1 then
      FUpdatedFrom := Copy(A, Length('--updated-from=') + 1, MaxInt);
  end;
  FillViewMenu;
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
  FSidesCircle := 24;
  FQuickFrames := True;
  { the program uses workers; the tests and tools, which never render, do not }
  FStartedAt := GetTickCount64;
  FThreads := True;
  DefaultThreads := True;
  uWork.Progress := @OnProgress;
  FSidesArc := 12;
  FCursorWas := crCross;
  Caption := APP_NAME + '  ' + CurrentVersion;
  FUIScale := EnsureRange(Screen.PixelsPerInch / 96, 1.0, 3.0);
  DoubleBuffered := True;

  FHintInShot := -1;
  FPaper := TArtSurface.Create(16, 16);
  FArt := TArtSurface.Create(16, 16);
  FInkToy := TArtSurface.Create(16, 16);
  FInkPro := TArtSurface.Create(16, 16);
  FInkHalf := TArtSurface.Create(16, 16);
  FInkToy.PreserveAlpha := True;
  FInkPro.PreserveAlpha := True;
  FShell := TArtSurface.Create(16, 16);
  FDeckSkin := TArtSurface.Create(16, 16);
  FModeSkin := TArtSurface.Create(16, 16);
  FCmdSkin := TArtSurface.Create(16, 16);
  FViewSkin := TArtSurface.Create(16, 16);
  FSliceSkin := TArtSurface.Create(16, 16);
  FToolSkin := TArtSurface.Create(16, 16);
  FInfoSkin := TArtSurface.Create(16, 16);
  FQuickSkin := TArtSurface.Create(16, 16);
  FHotQuick := -1;
  FHotTool := -1;
  FToolsWide := True;
  FHotSlice := -1;
  FSliceEdit := 0;
  FGlyph := TArtSurface.Create(16, 16);
  FPopup := POP_NONE;
  for I := 0 to 1 do
    FKnobSkin[I] := TArtSurface.Create(16, 16);
  FOverlay := TArtSurface.Create(16, 16);

  NewDrawing(False);
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
  FReplayFace := -1;
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

{ Closing the window with work on a sheet asks, the way closing a sheet does.

  It never asked at all, which was survivable only because the draft written
  beside the program brings the work back on the next launch - and a safety
  net nobody can see is not the same as being asked.  Same three answers as
  closing a sheet, and the same rule about what counts as work: a sheet
  nobody has touched is not something to lose, and the example the program
  starts with arrives with three hundred things on it. }
function TMainForm.AnyDirty: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FDrawings) do
    if (FDrawings[I].Doc.Live > 0) and FDrawings[I].Dirty then Inc(Result);
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  N, Ans: Integer;
begin
  CanClose := True;
  if FMode <> mdPro then Exit;
  { an update is taking over, and has the drawings already - see DoUpdate }
  if FHandingOver then Exit;
  N := AnyDirty;
  if N = 0 then Exit;

  Ans := QuestionDlg('Close Heckers Sketch',
    Format('%d sheet%s %s work on %s that is not saved.  ' +
           'Save the drawing before closing?',
      [N, specialize IfThen<string>(N = 1, '', 's'),
       specialize IfThen<string>(N = 1, 'has', 'have'),
       specialize IfThen<string>(N = 1, 'it', 'them')]),
    mtConfirmation,
    [mrYes, 'Save the drawing', 'IsDefault',
     mrNo, 'Close without saving',
     mrCancel, 'Keep it open', 'IsCancel'], 0);

  if Ans = mrCancel then
  begin
    CanClose := False;
    Exit;
  end;
  if Ans = mrYes then
  begin
    DoSave;
    { save-as declined, or the write failed - either way there is still work
      to lose, so the window stays }
    if AnyDirty > 0 then CanClose := False;
  end;
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  RememberWindow;
  { The source window, while it is still a window.  The settings are
    written from FormDestroy, and by then every other form has been hidden
    - so it was always written down as closed, and never came back. }
  if SourceForm <> nil then
  begin
    FSourceWasOpen := SourceForm.Visible;
    FSourceOnTop := SourceForm.chkOnTop.Checked;
    if SourceForm.WindowState = wsNormal then
      FSourceBounds := Rect(SourceForm.Left, SourceForm.Top, SourceForm.Width, SourceForm.Height);
  end;
end;

{ --blank on the command line, and no drawing named - see where it is used. }
function AskedForBlank: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if LowerCase(ParamStr(I)) = '--blank' then Result := True;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
var
  I: Integer;
begin
  { Last thing before the sheets go: close the program with work on the
    screen and it is still there next time. }
  if FEditSeq <> FDraftSeq then SaveDraft;
  SaveSettings;
  FExportDirs.Free;
  FDimFont.Free;
  for I := High(FDrawings) downto 0 do
    FDrawings[I].Free;
  FOverlay.Free;
  FPaperBase.Free;
  FSelShot.Free;
  for I := 0 to 1 do
    FKnobSkin[I].Free;
  FViewSkin.Free;
  FSliceSkin.Free;
  FToolSkin.Free;
  FInfoSkin.Free;
  FQuickSkin.Free;
  FGlyph.Free;
  FCmdSkin.Free;
  FModeSkin.Free;
  FCubeSkin.Free;
  FDeckSkin.Free;
  FShell.Free;
  FInkPro.Free;
  FInkHalf.Free;
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
  { --blank: start on an empty sheet - no draft, no example.

    From a note: "we should also have a startup parameter like --blank so it
    automatically opens with a blank drawing and doesnt load anything not
    even the initial toy model... it will make some of our testing and
    scripts shorter so we dont have to clear them all the time."

    The one thing it must not do is lose somebody's work.  The draft is
    written again a few seconds after the first stroke, and that would be
    over whatever was there - so the old one is copied aside first, beside
    it, where the next person to wonder where it went can find it. }
  if AskedForBlank then
  begin
    if FileExists(DraftFile) then
      CopyFile(DraftFile, ChangeFileExt(DraftFile, '') + '-before-blank.hsk',
        [cffOverwriteFile]);
    Opened := True;
    Trail('started blank (--blank)');
  end;
  { Nothing named on the command line, so carry on from last time.  A file
    asked for by name always wins - it is a clear instruction, and the draft
    is only a safety net. }
  { After an update, the drawings the old copy handed over - every sheet, its
    file, and what is not saved.  Any other time a handoff is left over from
    an update that never got as far as starting this, and the draft beside
    it is at least as new, so it goes. }
  if not Opened and (FUpdatedFrom <> '') then Opened := RestoreHandoff;
  if FileExists(HandoffFile) then DeleteFile(HandoffFile);
  if not Opened then Opened := RestoreDraft;
  { Still nothing?  Then this is either somebody's first run or a fresh
    folder, and an empty sheet is a poor way to explain what a drawing
    program is for.  Put the example toy up instead - it has a solid to
    orbit, a screen to look at, and a robot drawn in lines that is asking to
    be pushed.  Only when there is genuinely nothing: a drawing named on the
    command line wins, and so does a draft. }
  WriteExamples;
  WriteJigs;
  if not Opened then Opened := LoadExample;
  SplashLoaded(LoadedWords);
  { fingers on the drawing, where the platform gives them to us }
  FTouchOn := HookTouch(Self, @OnTouch);
  Trail('touch hook: ' + BoolToStr(FTouchOn, True));

  { Housekeeping from last time.  Nothing here may put a dialog on screen:
    this runs before the window has painted, so a dialog would sit in front
    of a black rectangle with nothing behind it - which is a program that
    looks like it has hung, and gets force-quit, which writes another crash
    report, which shows another dialog next time.  Offering the report waits
    for the tick, once the window is actually up. }
  ForgetPreviousBuild;
  { The source window back, if it was open last time - now, with the main
    window, and not at the tick a second and a half on where the update
    check lives.  "It takes like 3 seconds to show when restarting." }
  if FSourceWasOpen and (FMode = mdPro) then
  begin
    ShowSource;
    BringToFront;
  end;
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
  { PRO: one row.  Settings on the left, six named buttons on the right.
    It was three deep when the tools lived here and two when the file
    buttons did; both have gone somewhere they belong better, and the two
    rows they cost the drawing have gone back to it. }
  if FMode = mdPro then Result := 1 else Result := 4;
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
  ToolW: Integer;
  BezelR, DeckR: TRect;
  DeckL, DeckRt, InfoW: Integer;
  I: Integer;
begin
  if not FBooted then Exit;

  M := ChromeMargin;
  TitleH := TitleHeight;
  DeckH := DeckHeight;
  Bezel := Round(16 * FUIScale);
  Gap := Round(16 * FUIScale);
  ModeW := Round(132 * FUIScale);
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

  { The mode button is the way out of the toy and nothing else.  In pro
    there is no button at all: /toy is the way in, and the top right of a
    drawing program is better spent on the drawing. }
  pbMode.Visible := FMode = mdToy;
  if pbMode.Visible then
    pbMode.SetBounds(ClientWidth - M - ModeW, Round(10 * FUIScale), ModeW, ModeH);

  { the file buttons, after the name and the version }
  pbQuick.Visible := FMode = mdPro;
  if pbQuick.Visible then
    pbQuick.SetBounds(M + Round(2 * FUIScale), Round(4 * FUIScale),
      QuickWidth, Round(24 * FUIScale));

  DeckR := Rect(M, ClientHeight - M - DeckH, ClientWidth - M, ClientHeight - M);
  ToolW := ToolStripWidth;
  pbTools.Visible := (FMode = mdPro) and (ToolW > 0);

  pbCmd.Visible := FMode = mdPro;
  pbTabs.Visible := FMode = mdPro;
  pbView.Visible := FMode = mdPro;
  { The cut only means something in a plan, so it is only there in one.  It
    sits beside the view button because it is a property of the view and
    nothing else, and because that corner is where somebody already looks to
    find out what they are looking at. }
  pbSlice.Visible := (FMode = mdPro) and (FD <> nil) and (FD.View = vkPlan);
  if FMode = mdPro then
  begin
    pbView.SetBounds(ClientWidth - M - Round(228 * FUIScale), TitleH,
      Round(228 * FUIScale), TabsH);
    if pbSlice.Visible then
    begin
      pbSlice.SetBounds(pbView.Left - Round(6 * FUIScale) - Round(250 * FUIScale),
        TitleH, Round(250 * FUIScale), TabsH);
      pbTabs.SetBounds(M, TitleH,
        Max(120, pbSlice.Left - M - Round(16 * FUIScale)), TabsH);
    end
    else
      pbTabs.SetBounds(M, TitleH,
        Max(120, pbView.Left - M - Round(16 * FUIScale)), TabsH);
    pbCmd.SetBounds(M, DeckR.Top - Gap - CmdH, ClientWidth - 2 * M, CmdH);
    BezelR := Rect(M, TitleH + TabsH + Round(4 * FUIScale), ClientWidth - M,
      pbCmd.Top - Round(10 * FUIScale));
  end
  else
    BezelR := Rect(M, TitleH, ClientWidth - M, DeckR.Top - Gap);

  { The strip stands in the space the bezel gives up, so the drawing is never
    underneath it - a tool that covers the thing you are drawing is the whole
    reason this is not a floating palette. }
  if pbTools.Visible then
  begin
    pbTools.SetBounds(BezelR.Left, BezelR.Top, ToolW,
      Max(60, BezelR.Bottom - BezelR.Top));
    BezelR.Left := BezelR.Left + ToolW + Round(6 * FUIScale);
  end;

  { And the entity panel takes the right, out of the same space and for the
    same reason: a panel that floats over the drawing covers the thing you
    are looking at, which is the whole argument against a palette. }
  InfoW := InfoPanelWidth;
  pbInfo.Visible := InfoW > 0;
  if pbInfo.Visible then
  begin
    BezelR.Right := BezelR.Right - InfoW - Round(6 * FUIScale);
    pbInfo.SetBounds(BezelR.Right + Round(6 * FUIScale), BezelR.Top, InfoW,
      Max(60, BezelR.Bottom - BezelR.Top));
  end;

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
  FSliceSkin.SetSize(Max(1, pbSlice.Width), Max(1, pbSlice.Height));
  FToolSkin.SetSize(Max(1, pbTools.Width), Max(1, pbTools.Height));
  RebuildTools;
  FQuickSkin.SetSize(Max(1, pbQuick.Width), Max(1, pbQuick.Height));
  RebuildQuick;
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
  { the same shift Relayout makes, or the frame is drawn round where the
    drawing used to be }
  if (FMode = mdPro) and (ToolStripWidth > 0) then
    BezelR.Left := BezelR.Left + ToolStripWidth + Round(6 * FUIScale);

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
    FShotOK := False;
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
  clipped to the polygon, and a bold outline.

  Clipped to the face, which is not the same thing as clipped to its outline,
  and this got that wrong for as long as it existed.

  From a note, 15 September, building the toy's case: "using the push/pull tool and
  when i am hovering over the outer ring face it highlights the face
  including the smaller rectangle face inside!  it should only be
  highlighting as much of the face as it can see!"  A rectangle drawn inside
  another leaves a ring - an outline with a window in it - and the window
  belongs to the face inside, not to this one.  The push itself has always
  known that; only the picture said otherwise.

  The second half of the report is the other rule: a dot goes down only
  where the face is really in front, asked of the depth buffer the render
  left behind.  Otherwise the wash spills over whatever stands between the
  eye and the face, and the picture says that is coming up too.

  Both rules were already written down and tested twenty lines away in
  WashFace, where the eraser uses them.  Neither had ever been asked of this
  one.  That is the third or fourth time the same shape of fault has turned
  up: a rule learned in one picker and never carried to its neighbor. }
{ With S given, the same wash drawn into that surface instead of onto the
  canvas, S's corner being at OX, OY on the screen, and only the part that
  falls inside it.  That is how the wash gets into the cursor's square - see
  PaintUnderCursor. }
procedure TMainForm.PaintFaceHint(C: TCanvas; Face: Integer; const Col: TPix;
  S: TArtSurface; OX, OY: Integer);
var
  Pts: TPointFArray;
  HPts: array of TPointFArray;
  Ink: TArtSurface;
  Look, Nm, AU, AV, O, W: TP3;
  SO, SU, SV: TPointF;
  Det, DU, DV, D0, PU, PV, Dp, Zb: Double;
  Deep: Boolean;
  I, H, K, N, X, Y, X0, Y0, X1, Y1, Step, NX, XEnd: Integer;
  Inside: Boolean;
  { one row never crosses more loops than this; a face with more windows than
    sixty-four is not a thing anybody points at }
  XS: array[0..255] of Double;
  Xt: Double;

  { Where this row crosses that loop, added to the list.  The same test the
    per-dot crossing count used to do, asked once for the row rather than
    once for every dot along it. }
  procedure Cross(const P: TPointFArray; PY: Integer;
    var Xs: array of Double; var NX: Integer);
  var
    K, L, M: Integer;
  begin
    M := Length(P);
    if M < 3 then Exit;
    L := M - 1;
    for K := 0 to M - 1 do
    begin
      if ((P[K].Y > PY) <> (P[L].Y > PY)) and (NX <= High(Xs)) then
      begin
        Xs[NX] := (P[L].X - P[K].X) * (PY - P[K].Y) /
                  (P[L].Y - P[K].Y) + P[K].X;
        Inc(NX);
      end;
      L := K;
    end;
  end;

begin
  if Face < 0 then Exit;
  { already in the picture that was put on the screen - see pbScreenPaint }
  if (S = nil) and (Face = FHintInShot) then Exit;
  Pts := FD.Doc.Outline(Proj, Face);
  N := Length(Pts);
  if N < 3 then Exit;

  SetLength(HPts, Length(FD.Doc[Face].Holes));
  for H := 0 to High(HPts) do
  begin
    SetLength(HPts[H], Length(FD.Doc[Face].Holes[H]));
    for I := 0 to High(HPts[H]) do
      HPts[H][I] := ScreenOf(FD.Doc[Face].Holes[H][I]);
  end;

  X0 := MaxInt; Y0 := MaxInt; X1 := -MaxInt; Y1 := -MaxInt;
  for I := 0 to N - 1 do
  begin
    X0 := Min(X0, Round(Pts[I].X)); X1 := Max(X1, Round(Pts[I].X));
    Y0 := Min(Y0, Round(Pts[I].Y)); Y1 := Max(Y1, Round(Pts[I].Y));
  end;
  X0 := Max(X0, 0); Y0 := Max(Y0, 0);
  X1 := Min(X1, pbScreen.Width - 1); Y1 := Min(Y1, pbScreen.Height - 1);
  if S <> nil then
  begin
    X0 := Max(X0, OX); Y0 := Max(Y0, OY);
    X1 := Min(X1, OX + S.Width - 1); Y1 := Min(Y1, OY + S.Height - 1);
  end;
  if (X1 <= X0) or (Y1 <= Y0) then Exit;

  { How deep the face is under any pixel of it.  The view is orthographic and
    the face is flat, so depth across it is affine in screen coordinates: two
    of the plane's own directions, projected, give the mapping, and one 2x2
    inverse turns a pixel back into a point on the face.  That is two
    multiplies a dot rather than a ray cast. }
  Ink := ActiveInk;
  Deep := (Ink <> nil) and Ink.DepthOn and (Length(FD.Doc[Face].Poly) >= 3);
  Det := 0; D0 := 0; DU := 0; DV := 0;
  SO := PtF(0, 0); SU := PtF(0, 0); SV := PtF(0, 0);
  if Deep then
  begin
    Look := ViewDir(Proj);
    Nm := Norm3(FD.Doc.FaceNormal(Face));
    AxesFromNormal(Nm, AU, AV);
    O := FD.Doc[Face].Poly[0];
    SO := ScreenOf(O);
    W := P3(O.X + AU.X, O.Y + AU.Y, O.Z + AU.Z);
    SU := ScreenOf(W); SU := PtF(SU.X - SO.X, SU.Y - SO.Y);
    W := P3(O.X + AV.X, O.Y + AV.Y, O.Z + AV.Z);
    SV := ScreenOf(W); SV := PtF(SV.X - SO.X, SV.Y - SO.Y);
    Det := SU.X * SV.Y - SU.Y * SV.X;
    Deep := Abs(Det) > 1E-6;
    D0 := Dot3(O, Look);
    DU := Dot3(AU, Look);
    DV := Dot3(AV, Look);
  end;

  { A dither, because the canvas has no alpha channel and a tint has to be
    made out of gaps.  Every other pixel reads as a solid wash at a glance,
    which is what SketchUp does: the face you are pointing at should be
    unmistakable rather than a hint.

    Filled a row at a time rather than a dot at a time, and that is not a
    micro-optimization.  Asking "is this dot inside" runs the crossing count
    over the whole outline, with a divide per edge - and the outline of the
    toy's case has thirty-two corners.  On a face covering most of a screen
    that is a hundred and twenty thousand dots times thirty-eight edges, four
    million divides, for EVERY MOUSE MOVE while push/pull or the drill is in
    hand.  Which is exactly the shape of the "it seems the program is
    struggling or stuck in some loop for some reason".

    A scanline asks the same question once per row instead: where does this
    row cross the outline?  Sort the crossings, fill between them in pairs.
    Two hundred and fifty rows times thirty-eight edges is nine thousand
    divides - about five hundred times less work for exactly the same picture.

    The windows come along for free.  Their edges go into the same list of
    crossings, and the even-odd rule that fills between pairs then leaves a
    hole wherever a window's two sides bracket the row.  No second test. }
  Step := 2;
  Y := Y0 - (Y0 mod Step);
  while Y <= Y1 do
  begin
    NX := 0;
    Cross(Pts, Y, XS, NX);
    for H := 0 to High(HPts) do Cross(HPts[H], Y, XS, NX);
    { insertion sort - a row crosses a face's outline twice as a rule, four
      times through a window, and never enough times for anything cleverer }
    for I := 1 to NX - 1 do
    begin
      Xt := XS[I];
      K := I - 1;
      while (K >= 0) and (XS[K] > Xt) do
      begin
        XS[K + 1] := XS[K];
        Dec(K);
      end;
      XS[K + 1] := Xt;
    end;

    I := 0;
    while I + 1 < NX do
    begin
      { on the dither's own grid, so the pattern does not crawl as the
        outline moves under it }
      X := Max(X0, Ceil(XS[I]));
      X := X + ((Step - (X mod Step)) mod Step);
      XEnd := Min(X1, Floor(XS[I + 1]));
      while X <= XEnd do
      begin
        Inside := True;
        if Deep then
        begin
          PU := ((X - SO.X) * SV.Y - (Y - SO.Y) * SV.X) / Det;
          PV := (SU.X * (Y - SO.Y) - SU.Y * (X - SO.X)) / Det;
          Dp := D0 + PU * DU + PV * DV;
          Zb := Ink.DepthAt(X, Y);
          if (Zb > -1E29) and (Zb > Dp + 1E-3 * (1 + Abs(Dp))) then
            Inside := False;
        end;
        if Inside then
          if S <> nil then S.BlendPixel(X - OX, Y - OY, Col, 1)
          else C.Pixels[X, Y] := PixToColor(Col);
        Inc(X, Step);
      end;
      Inc(I, 2);
    end;
    Inc(Y, Step);
  end;

  if S <> nil then
  begin
    { the bold edge, into the square too }
    for I := 0 to N - 1 do
      S.Line(Pts[(I + N - 1) mod N].X - OX, Pts[(I + N - 1) mod N].Y - OY,
        Pts[I].X - OX, Pts[I].Y - OY, Max(2, Round(2 * FUIScale)), Col, 1);
    for H := 0 to High(HPts) do
      for I := 0 to High(HPts[H]) do
        S.Line(HPts[H][(I + Length(HPts[H]) - 1) mod Length(HPts[H])].X - OX,
          HPts[H][(I + Length(HPts[H]) - 1) mod Length(HPts[H])].Y - OY,
          HPts[H][I].X - OX, HPts[H][I].Y - OY,
          Max(2, Round(2 * FUIScale)), Col, 1);
    Exit;
  end;

  C.Pen.Color := PixToColor(Col);
  C.Pen.Width := Max(2, Round(2 * FUIScale));
  C.Pen.Style := psSolid;
  C.MoveTo(Round(Pts[N - 1].X), Round(Pts[N - 1].Y));
  for I := 0 to N - 1 do
    C.LineTo(Round(Pts[I].X), Round(Pts[I].Y));
  { the windows get the same bold edge, so a ring reads as a ring }
  for H := 0 to High(HPts) do
    if Length(HPts[H]) >= 3 then
    begin
      C.MoveTo(Round(HPts[H][High(HPts[H])].X), Round(HPts[H][High(HPts[H])].Y));
      for I := 0 to High(HPts[H]) do
        C.LineTo(Round(HPts[H][I].X), Round(HPts[H][I].Y));
    end;
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
  Snapped: Boolean;
begin
  Result := 0;
  if (FOffFace < 0) or (FOffFace >= FD.Doc.Live) then Exit;
  Loop := FD.Doc[FOffFace].Poly;
  Cnt := Length(Loop);
  if Cnt < 3 then Exit;
  N := FD.Doc.FaceNormal(FOffFace);
  { Where the cursor is.  When it has snapped to something - a guide, a
    guide point, a corner, the middle of an edge - that point is what the
    offset is measured to, dropped onto the face's plane, and it is taken
    exactly: a fitter who put a guide 8" in wants the offset at 8", not at
    the nearest snap step of where the mouse happened to be - which is how
    a guide at 8" gave an offset of 9".  SketchUp's offset follows its
    inferences the same way. }
  Snapped := FSnapKind in [snEndpoint, snMidpoint, snCenter, snCross, snSubMid,
    snOnEdge, snOrigin];
  if Snapped then
  begin
    P := FCur;
    D := Dot3(N, P3(P.X - Loop[0].X, P.Y - Loop[0].Y, P.Z - Loop[0].Z));
    P := P3(P.X - N.X * D, P.Y - N.Y * D, P.Z - N.Z * D);
  end
  else
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
  if (not Snapped) and (SnapStep > 0) then Result := Round(Result / SnapStep) * SnapStep;

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
  Result := OffsetLoop(FD.Doc[FOffFace].Poly, FD.Doc.FaceNormal(FOffFace), D,
    not FOffsetRaw);
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

{ Turns over every face in the selection.

  A face has a front and a back and the program has to guess which way round
  a new one goes.  The guess is a good one - the same axis rule SketchUp
  falls back on - and it cannot always be right: two walls back to back are
  wound the same way and one of them therefore shows its pale blue back to
  whoever is standing outside.  Nothing in the drawing says which side of a
  loose wall is outside, so nothing can work it out.  This is the way to
  say so. }
{ Paint, and what gets painted.

  The panel is showing one face, but a face is rarely painted on its own -
  a box is six of them and nobody wants six trips through a color dialog.
  So: if the face the panel is showing is part of what is picked, every
  picked face takes the color, which is what SketchUp's bucket does with a
  selection.  If it is not part of the selection - the panel can show what
  the mouse is over - then it is the only one that changes.

  Painting says whether to paint or to strip back to the default. }
function TMainForm.PaintSelectedFaces(Shown: Integer; C: TColor;
  Painting: Boolean): Integer;
var
  I: Integer;
  InSel: Boolean;

  procedure One(K: Integer);
  begin
    if (K < 0) or (K >= FD.Doc.Live) then Exit;
    if FD.Doc[K].Kind <> ekFace then Exit;
    if Painting then FD.Doc.SetMaterial(K, C) else FD.Doc.ClearMaterial(K);
    Inc(Result);
  end;

begin
  Result := 0;
  { Shown < 0 is the panel asking for the whole selection - nothing in
    particular is being shown, because several things are }
  InSel := Shown < 0;
  for I := 0 to High(FSel) do
    if FSel[I] = Shown then InSel := True;
  if InSel then
    for I := 0 to High(FSel) do One(FSel[I])
  else
    One(Shown);
  if Result = 0 then Exit;
  RenderPro;
  RecomposeAll;
  Invalidate;
end;

{ The color of everything picked that is drawn with a pen.  Faces are not:
  they are painted, and PaintSelectedFaces does those.  Nor are guides -
  they are not part of the drawing and the panel has never offered it. }
function TMainForm.InkSelectedThings(C: TColor): Integer;
var
  I, K: Integer;
begin
  Result := 0;
  for I := 0 to High(FSel) do
  begin
    K := FSel[I];
    if (K < 0) or (K >= FD.Doc.Live) then Continue;
    if not (FD.Doc[K].Kind in [ekLine, ekArc, ekText, ekDim]) then Continue;
    FD.Doc.SetInk(K, C);
    Inc(Result);
  end;
  if Result = 0 then Exit;
  RenderPro;
  RecomposeAll;
  Invalidate;
end;

function TMainForm.ReverseSelectedFaces: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FSel) do
    if FD.Doc[FSel[I]].Kind = ekFace then
      if FD.Doc.ReverseFace(FSel[I]) then Inc(Result);
  if Result = 0 then Exit;
  RenderPro;
  RecomposeAll;
  Invalidate;
end;

{ The one dimension that is picked, or -1.  One, because a length typed at
  two of them would have to guess which. }
function TMainForm.SelectedDim: Integer;
begin
  Result := -1;
  if Length(FSel) <> 1 then Exit;
  if FD.Doc[FSel[0]].Kind <> ekDim then Exit;
  Result := FSel[0];
end;

{ The one line that is picked - a drawn edge, not a dimension - or -1. }
function TMainForm.SelectedLine: Integer;
begin
  Result := -1;
  if Length(FSel) <> 1 then Exit;
  if (FSel[0] < 0) or (FSel[0] >= FD.Doc.Live) then Exit;
  if (FD.Doc[FSel[0]].Kind <> ekLine) or FD.Doc[FSel[0]].Dim then Exit;
  Result := FSel[0];
end;

{ Pick a line, type a length, Enter: SketchUp's Entity Info length, done the
  way every other size in this program is given.  Which end moves is
  SketchUp's rule - see TWorkDoc.LineLengthEnd - and the message says which,
  because a rule nobody is told is a surprise. }
function TMainForm.ApplyLineLength(NewLen: Double): Boolean;
var
  I: Integer;
  Was: Double;
  MoveB: Boolean;
begin
  Result := False;
  I := SelectedLine;
  if I < 0 then Exit;
  Was := Dist(FD.Doc[I].A, FD.Doc[I].B);
  if not FD.Doc.LineLengthEnd(I, MoveB) then
  begin
    FCmdMsg := 'That line is joined at both ends, so its length cannot be ' +
      'typed - move one of its ends instead, the way SketchUp does.';
    Result := True;
    Exit;
  end;
  if NewLen <= 0 then
  begin
    FCmdMsg := 'A length has to be more than nothing.';
    Result := True;
    Exit;
  end;
  PushUndo;
  FD.Doc.SetLineLength(I, NewLen);
  RebuildFlatFaces;
  RenderPro;
  RecomposeAll;
  Invalidate;
  InvalidateStatus;
  FCmdMsg := Format('%s -> %s, the free end moved.',
    [FormatLen(Was, FD.Units), FormatLen(NewLen, FD.Units)]);
  Result := True;
end;

{ Pick a dimension, type what it ought to read, and the drawing moves.

  The whole interface is one already in the program: everywhere else in PRO
  you type a length and press Enter, so here you do the same.  Nothing new to
  learn, and nothing new on the screen.

  Which end gives is the only real question, and the answer is the end the
  dimension was drawn to - the second point you clicked, the one your hand
  was last on.  Said out loud in the message every time, with the way to have
  the other one instead, because a rule nobody is told is a surprise. }
function TMainForm.ApplyDimResize(NewLen: Double; MoveB: Boolean): Boolean;
var
  I: Integer;
  Was: Double;
begin
  Result := False;
  I := SelectedDim;
  if I < 0 then Exit;
  Was := Dist(FD.Doc[I].A, FD.Doc[I].B);
  if NewLen <= 0 then
  begin
    FCmdMsg := 'A size has to be more than nothing.';
    Exit;
  end;
  if Abs(NewLen - Was) < 1E-9 then
  begin
    FCmdMsg := 'It already reads ' + FormatLen(Was, FD.Units) + '.';
    Exit;
  end;
  { A dimension with its two ends in the same place has no direction to grow
    along.  Checked here rather than after the undo is pushed, so a refusal
    never leaves a step on the stack that undoes nothing. }
  if Was < 1E-9 then
  begin
    FCmdMsg := 'That dimension has no length to work from.';
    Exit;
  end;
  PushUndo;
  FD.Doc.ResizeDim(I, NewLen, MoveB);
  RenderPro;
  RecomposeAll;
  Invalidate;
  InvalidateStatus;
  if MoveB then
    FCmdMsg := Format('%s -> %s, from the end it was drawn to.  ' +
      '"/resize %s start" moves the other end instead.',
      [FormatLen(Was, FD.Units), FormatLen(NewLen, FD.Units),
       FormatLen(NewLen, FD.Units)])
  else
    FCmdMsg := Format('%s -> %s, from the end it was drawn from.',
      [FormatLen(Was, FD.Units), FormatLen(NewLen, FD.Units)]);
  Result := True;
end;

{ What the right button offers, worked out fresh every time it is pressed so
  that it only ever offers what would do something. }
procedure TMainForm.FillCanvasMenu;
var
  I, Faces: Integer;
  M: TMenuItem;

  procedure Add(const Caption: string; Tag: Integer);
  var
    It: TMenuItem;
  begin
    It := TMenuItem.Create(pmCanvas);
    It.Caption := Caption;
    It.Tag := Tag;
    It.OnClick := @CanvasMenuClick;
    pmCanvas.Items.Add(It);
  end;

begin
  pmCanvas.Items.Clear;
  Faces := 0;
  for I := 0 to High(FSel) do
    if FD.Doc[FSel[I]].Kind = ekFace then Inc(Faces);

  { The same rows every time, in the same order, and the ones that would do
    nothing grayed rather than missing.

    It was built the other way - only the rows that applied - and that is how
    a menu becomes a hazard.  On a tessellated cylinder the right button
    lands on an edge rather than a face, so Reverse Face was not there, so
    Erase moved up into the row Reverse Face is usually in, and the same
    click in the same place on the same object erased it instead.  A
    destructive row must not be able to arrive under a hand aiming at a
    harmless one, which means the shape of this menu cannot depend on what
    is selected.

    And Erase goes last, under a line, the way every context menu in every
    program puts delete last. }
  { Groups - the same five rows every time, for the reason above. }
  Add('Make Group', 10);
  pmCanvas.Items[pmCanvas.Items.Count - 1].Enabled := Length(FSel) > 0;
  Add('Open Group', 11);
  pmCanvas.Items[pmCanvas.Items.Count - 1].Enabled := SoleGroup > 0;
  Add('Close Group', 12);
  pmCanvas.Items[pmCanvas.Items.Count - 1].Enabled := FD.Doc.Context <> 0;
  if (SoleGroup > 0) and FD.Doc.PartLocked(SoleGroup) then Add('Unlock Group', 13)
  else Add('Lock Group', 13);
  pmCanvas.Items[pmCanvas.Items.Count - 1].Enabled := Length(SelectedGroups) > 0;
  Add('Explode Group', 14);
  pmCanvas.Items[pmCanvas.Items.Count - 1].Enabled := Length(SelectedGroups) > 0;
  if (SoleGroup > 0) and (FD.Doc.PartJig(SoleGroup) <> '') then
  begin
    Add('Run the Jig Again', 15);
    Add('Show It in the Source', 16);
  end;
  M := TMenuItem.Create(pmCanvas);
  M.Caption := '-';
  pmCanvas.Items.Add(M);

  if Faces > 1 then Add(Format('Reverse %d Faces', [Faces]), 1)
  else Add('Reverse Face', 1);
  pmCanvas.Items[pmCanvas.Items.Count - 1].Enabled := Faces > 0;

  { One click instead of two numbers.  Somebody who has just clicked a floor
    has said everything the slice needs to know. }
  Add('Plan From Here', 4);
  pmCanvas.Items[pmCanvas.Items.Count - 1].Enabled := Faces = 1;

  { Asked for by From a note: having centerd a selection is what makes an export
    arrive where a slicer expects it, and the right button is where you
    already are when you have just selected the thing. }
  Add('Center on the Origin', 5);
  pmCanvas.Items[pmCanvas.Items.Count - 1].Enabled := Length(FSel) > 0;

  { and the other half of the same want: not the middle on zero but the
    corner, which is what you reach for when you are measuring rather than
    printing }
  Add('Into the Corner at 0,0,0', 6);
  pmCanvas.Items[pmCanvas.Items.Count - 1].Enabled := Length(FSel) > 0;

  { The guides.  Always both rows, grayed when the drawing has none, for the
    reason written at the top of this routine: a menu whose shape depends on
    what is in the drawing puts a destructive row under a hand aiming at a
    harmless one. }
  M := TMenuItem.Create(pmCanvas);
  M.Caption := '-';
  pmCanvas.Items.Add(M);

  if FD.Doc.GuidesHidden then
    Add(Format('Show %d Guides', [FD.Doc.GuideCount]), 7)
  else
    Add(Format('Hide %d Guides', [FD.Doc.GuideCount]), 7);
  pmCanvas.Items[pmCanvas.Items.Count - 1].Enabled := FD.Doc.GuideCount > 0;

  Add('Clear Guides', 8);
  pmCanvas.Items[pmCanvas.Items.Count - 1].Enabled := FD.Doc.GuideCount > 0;

  M := TMenuItem.Create(pmCanvas);
  M.Caption := '-';
  pmCanvas.Items.Add(M);

  Add('Select None', 3);
  pmCanvas.Items[pmCanvas.Items.Count - 1].Enabled := Length(FSel) > 0;

  M := TMenuItem.Create(pmCanvas);
  M.Caption := '-';
  pmCanvas.Items.Add(M);

  if Length(FSel) > 1 then Add(Format('Erase %d Things', [Length(FSel)]), 2)
  else Add('Erase', 2);
  pmCanvas.Items[pmCanvas.Items.Count - 1].Enabled := Length(FSel) > 0;
end;

procedure TMainForm.CanvasMenuClick(Sender: TObject);
var
  N: Integer;
begin
  case (Sender as TMenuItem).Tag of
    1:
      begin
        PushUndo;
        N := ReverseSelectedFaces;
        if N = 1 then FCmdMsg := 'Face turned over.'
        else FCmdMsg := Format('%d faces turned over.', [N]);
        InvalidateStatus;
      end;
    2: DeleteSelection;
    10: MakeGroup;
    11: OpenGroup(SoleGroup);
    12: CloseGroup;
    13: LockGroups(not ((SoleGroup > 0) and FD.Doc.PartLocked(SoleGroup)));
    14: ExplodeGroups;
    15:
      begin
        if RunJigOf(SoleGroup) then
        begin
          RebuildFlatFaces;
          FCmdMsg := 'The jig was run again.';
        end;
        RenderPro;
        RecomposeAll;
        pbScreen.Invalidate;
        pbCmd.Invalidate;
      end;
    16: ShowSource;
    7:
      begin
        FD.Doc.GuidesHidden := not FD.Doc.GuidesHidden;
        FCmdMsg := IfThen(FD.Doc.GuidesHidden,
          'Guides put away.  They are still in the drawing.',
          'Guides back.');
        RenderPro;
        RecomposeAll;
      end;
    8:
      begin
        PushUndo;
        FCmdMsg := Format('Cleared %d guides.', [FD.Doc.ClearGuides]);
        RenderPro;
        RecomposeAll;
      end;
    4:
      for N := 0 to High(FSel) do
        if FD.Doc[FSel[N]].Kind = ekFace then
        begin
          PlanFromFace(FSel[N]);
          Break;
        end;
    3:
      begin
        SelectNone;
        FCmdMsg := 'Nothing selected.';
        FScreenDirty := True;
        InvalidateStatus;
      end;
    5: CenterSelection;
    6: CornerSelection;
  end;
end;

{ Move what is selected - or the whole drawing, when nothing is - so the
  middle of it sits on the origin.

  Worth having on the drawing and not only on the way out to an STL: a
  drawing that is centerd is one where the exports, the dimensions taken from
  the origin and the three axis readings all agree with each other. }
{ Center it on the bed - across X and Y, and standing on Z.

  It used to center all three axes, which puts the bottom half of the thing
  under the floor.  That is a reasonable reading of "center" and the wrong
  one here: this command exists because a 3D print has to arrive where the
  slicer expects it, and every slicer expects the bed at Z nought.  A model
  half underground is the sort of thing somebody opens another program to put
  right, which is precisely the step this is meant to remove.

  /tozero is still the other one: not the middle over the origin, but the
  near bottom corner ON it. }
procedure TMainForm.CenterSelection;
var
  Mid, Lo, Hi: TP3;
  Idx: array of Integer;
  I: Integer;
begin
  if not FD.Doc.SpanOf(FSel, Lo, Hi) then
  begin
    FCmdMsg := 'Nothing to center.';
    InvalidateStatus;
    Exit;
  end;
  Mid := P3((Lo.X + Hi.X) / 2, (Lo.Y + Hi.Y) / 2, Lo.Z);
  if (Abs(Mid.X) < 1E-9) and (Abs(Mid.Y) < 1E-9) and (Abs(Mid.Z) < 1E-9) then
  begin
    FCmdMsg := 'Already centered on the floor.';
    InvalidateStatus;
    Exit;
  end;
  PushUndo;
  if Length(FSel) > 0 then
  begin
    SetLength(Idx, Length(FSel));
    for I := 0 to High(FSel) do Idx[I] := FSel[I];
  end
  else
  begin
    SetLength(Idx, FD.Doc.Live);
    for I := 0 to FD.Doc.Live - 1 do Idx[I] := I;
  end;
  FD.Doc.TranslateEnts(Idx, P3(-Mid.X, -Mid.Y, -Mid.Z));
  RenderPro;
  RecomposeAll;
  FScreenDirty := True;
  if Length(FSel) > 0 then
    FCmdMsg := Format('Centered %d things on the floor.', [Length(FSel)])
  else
    FCmdMsg := 'Centered the whole drawing on the floor.';
  InvalidateStatus;
  Invalidate;
end;

{ Keep the list in step with what has been typed.

  Called from every place FInput changes while a command is being typed: the
  list opens on the slash, narrows as the letters arrive, and closes again
  when the slash is rubbed out.  The highlight sits on the first row, which
  is the one Enter will take. }
procedure TMainForm.SyncCmdList;
var
  H: Integer;
begin
  if FMode <> mdPro then Exit;
  if Copy(FInput, 1, 1) <> '/' then
  begin
    if FPopup = POP_CMDS then ClosePopup;
    Exit;
  end;
  if FPopup <> POP_CMDS then OpenPopup(POP_CMDS)
  else
    BuildCmdOrder;
  { OpenPopup counts the whole list; what is actually in it is whatever
    survived the filter }
  FPopupN := Length(FCmdOrder);
  { and the panel shrinks to what is left in it - a list of four rows in a
    box built for sixty is a box with a hole in it }
  H := Min(FPopupN * Round(22 * FUIScale) + Round(12 * FUIScale),
           PopupMaxHeight(POP_CMDS));
  FPopupR := Rect(FPopupR.Left, FPopupR.Bottom - H, FPopupR.Right,
                  FPopupR.Bottom);
  if FPopupR.Top < 4 then
    FPopupR := Rect(FPopupR.Left, 4, FPopupR.Right, 4 + H);
  FPopupTop := 0;
  if FPopupN > 0 then FPopupHot := 0 else FPopupHot := -1;
  FScreenDirty := True;
  pbScreen.Invalidate;
end;

{ Up and down the list, with the view following the highlight. }
procedure TMainForm.MoveCmdHighlight(Key: word);
var
  Rows, Step: Integer;
begin
  if Length(FCmdOrder) = 0 then Exit;
  Rows := Max(1, (FPopupR.Bottom - FPopupR.Top - Round(12 * FUIScale)) div
                 Max(1, Round(22 * FUIScale)));
  case Key of
    VK_UP:    Step := -1;
    VK_DOWN:  Step := 1;
    VK_PRIOR: Step := -Rows;
  else        Step := Rows;
  end;
  FPopupHot := EnsureRange(FPopupHot + Step, 0, High(FCmdOrder));
  if FPopupHot < FPopupTop then FPopupTop := FPopupHot;
  if FPopupHot > FPopupTop + Rows - 1 then FPopupTop := FPopupHot - Rows + 1;
  FPopupTop := EnsureRange(FPopupTop, 0, Max(0, Length(FCmdOrder) - Rows));
  FScreenDirty := True;
  pbScreen.Invalidate;
end;

function TMainForm.ExactCmd(const S: string): Boolean;
var
  W: string;
  I: Integer;
begin
  W := LowerCase(Trim(S));
  if Copy(W, 1, 1) = '/' then W := Copy(W, 2, MaxInt);
  { anything with an argument after it has been typed on purpose }
  if Pos(' ', W) > 0 then Exit(True);
  Result := CmdIndex(W) >= 0;
end;

{ The row a word runs, by its name or by any of its other words; -1 when it
  is not in the list at all. }
function TMainForm.CmdIndex(const W: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(CMD_LIST) do
    if (CMD_LIST[I].Name = W) or
       (Pos(' ' + W + ' ', ' ' + CMD_LIST[I].Also + ' ') > 0) then
      Exit(I);
  Result := -1;
end;

{ When the list was found by one of a row's other words rather than its
  name, that word - so the row can say why it is there.  Typing /tape and
  getting a row called /measure is otherwise a puzzle. }
function TMainForm.CmdAliasFor(Idx: Integer; const Want: string): string;
var
  Words: TStringList;
  K: Integer;
begin
  Result := '';
  if (Want = '') or (Idx < 0) or (Idx > High(CMD_LIST)) then Exit;
  if Pos(Want, CMD_LIST[Idx].Name) > 0 then Exit;
  Words := TStringList.Create;
  try
    Words.Delimiter := ' ';
    Words.StrictDelimiter := True;
    Words.DelimitedText := CMD_LIST[Idx].Also;
    { one that starts with it first, the same order the list is sorted by }
    for K := 0 to Words.Count - 1 do
      if Copy(Words[K], 1, Length(Want)) = Want then Exit(Words[K]);
    for K := 0 to Words.Count - 1 do
      if Pos(Want, Words[K]) > 0 then Exit(Words[K]);
  finally
    Words.Free;
  end;
end;

{ Take the highlighted row: complete it into the box, and run it when it
  wants nothing after it.  What a click on a row does, and what Enter does
  while the list is up. }
procedure TMainForm.TakeCmdHighlight;
var
  It: TCmdItem;
begin
  if (FPopupHot < 0) or (FPopupHot >= Length(FCmdOrder)) then Exit;
  It := CMD_LIST[FCmdOrder[FPopupHot]];
  NoteCmdUsed(It.Name);
  ClosePopup;
  if It.Arg then
  begin
    { one that wants something after it is completed and left waiting -
      running /scale with nothing after it is a question, not an answer }
    FInput := '/' + It.Name + ' ';
    FCmdMsg := It.Hint;
  end
  else
  begin
    FInput := '';
    RunCommand(It.Name);
  end;
  pbCmd.Invalidate;
  pbScreen.Invalidate;
end;

{ What is in the command list, and in what order.

  It works the way an editor's autocomplete does: type a slash and the whole
  list is there, keep typing and it narrows.  What is typed after the slash
  is the filter - the ones that start with it first, because that is what
  you were reaching for, then the ones that merely contain it, because
  sometimes you only remember the middle of a word.

  With nothing typed yet the order is the one that answers both kinds of
  not-knowing: the commands used lately on top, most recent first, and the
  rest alphabetical.  Alphabetical is where a thing is when you do not know
  what it is called; recent is where it is when you do. }
procedure TMainForm.BuildCmdOrder;
var
  I, N: Integer;
  Used: array of Boolean;
  Parts: TStringList;
  Want: string;

  { 0 no match, 1 it starts with it, 2 it is in there somewhere }
  function RankWord(const Name: string): Integer;
  begin
    if Copy(Name, 1, Length(Want)) = Want then Exit(1);
    if Pos(Want, Name) > 0 then Exit(2);
    Result := 0;
  end;

  { the best of the row's name and its other words }
  function Rank(M: Integer): Integer;
  var
    Words: TStringList;
    K, R: Integer;
  begin
    if Want = '' then Exit(1);
    Result := RankWord(CMD_LIST[M].Name);
    if (Result = 1) or (CMD_LIST[M].Also = '') then Exit;
    Words := TStringList.Create;
    try
      Words.Delimiter := ' ';
      Words.StrictDelimiter := True;
      Words.DelimitedText := CMD_LIST[M].Also;
      for K := 0 to Words.Count - 1 do
      begin
        R := RankWord(Words[K]);
        if (R > 0) and ((Result = 0) or (R < Result)) then Result := R;
      end;
    finally
      Words.Free;
    end;
  end;

  procedure Sweep(Pass: Integer);
  var
    K, M: Integer;
  begin
    { the ones used lately first, in the order they were used }
    Parts := TStringList.Create;
    try
      Parts.Delimiter := ',';
      Parts.StrictDelimiter := True;
      Parts.DelimitedText := FCmdRecent;
      for K := 0 to Parts.Count - 1 do
        for M := 0 to High(CMD_LIST) do
          if (not Used[M]) and (CMD_LIST[M].Name = Trim(Parts[K])) and
             (Rank(M) = Pass) then
          begin
            FCmdOrder[N] := M;
            Used[M] := True;
            Inc(N);
            Break;
          end;
    finally
      Parts.Free;
    end;
    { then the rest - CMD_LIST is written alphabetical, so as they come }
    for M := 0 to High(CMD_LIST) do
      if (not Used[M]) and (Rank(M) = Pass) then
      begin
        FCmdOrder[N] := M;
        Used[M] := True;
        Inc(N);
      end;
  end;

begin
  { whatever has been typed after the slash }
  Want := LowerCase(Trim(FInput));
  if Copy(Want, 1, 1) = '/' then Want := Copy(Want, 2, MaxInt);
  I := Pos(' ', Want);
  if I > 0 then Want := Copy(Want, 1, I - 1);
  FCmdWant := Want;

  SetLength(FCmdOrder, Length(CMD_LIST));
  SetLength(Used, Length(CMD_LIST));
  for I := 0 to High(Used) do Used[I] := False;
  N := 0;
  Sweep(1);
  Sweep(2);
  SetLength(FCmdOrder, N);
end;

{ Remember one, at the front, and keep the list short enough to be a list of
  what you use rather than a list of what you have ever used. }
procedure TMainForm.NoteCmdUsed(const Cmd: string);
const
  KEEP = 8;
var
  Parts: TStringList;
  I: Integer;
begin
  Parts := TStringList.Create;
  try
    Parts.Delimiter := ',';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := FCmdRecent;
    for I := Parts.Count - 1 downto 0 do
      if Trim(Parts[I]) = Cmd then Parts.Delete(I);
    Parts.Insert(0, Cmd);
    while Parts.Count > KEEP do Parts.Delete(Parts.Count - 1);
    FCmdRecent := Parts.DelimitedText;
  finally
    Parts.Free;
  end;
end;

{ Into the corner at the origin, rather than centerd on it.

  Centring is what a slicer wants - it puts the middle of the thing on the
  middle of the bed.  This is what a person wants when they are measuring:
  the model sits on the floor with its two near edges against the origin, so
  every number read off it is a distance from zero rather than a distance
  from half of itself.  It is also the corner of the world where all three
  axes are drawn solid, which is the quarter a drawing belongs in.

  It moves the box, not the shape: the lowest corner of what is selected goes
  to 0,0,0 and everything travels with it. }
procedure TMainForm.CornerSelection;
var
  Lo, Hi: TP3;
  Idx: array of Integer;
  I: Integer;
begin
  if not FD.Doc.SpanOf(FSel, Lo, Hi) then
  begin
    FCmdMsg := 'Nothing to move.';
    InvalidateStatus;
    Exit;
  end;
  if (Abs(Lo.X) < 1E-9) and (Abs(Lo.Y) < 1E-9) and (Abs(Lo.Z) < 1E-9) then
  begin
    FCmdMsg := 'Already in the corner.';
    InvalidateStatus;
    Exit;
  end;
  PushUndo;
  if Length(FSel) > 0 then
  begin
    SetLength(Idx, Length(FSel));
    for I := 0 to High(FSel) do Idx[I] := FSel[I];
  end
  else
  begin
    SetLength(Idx, FD.Doc.Live);
    for I := 0 to FD.Doc.Live - 1 do Idx[I] := I;
  end;
  FD.Doc.TranslateEnts(Idx, P3(-Lo.X, -Lo.Y, -Lo.Z));
  RenderPro;
  RecomposeAll;
  FScreenDirty := True;
  if Length(FSel) > 0 then
    FCmdMsg := Format('Moved %d things into the corner at 0,0,0 - %s by %s ' +
      'by %s from there.', [Length(FSel),
      FormatLen(Hi.X - Lo.X, FD.Units), FormatLen(Hi.Y - Lo.Y, FD.Units),
      FormatLen(Hi.Z - Lo.Z, FD.Units)])
  else
    FCmdMsg := Format('Moved the whole drawing into the corner at 0,0,0 - ' +
      '%s by %s by %s from there.',
      [FormatLen(Hi.X - Lo.X, FD.Units), FormatLen(Hi.Y - Lo.Y, FD.Units),
       FormatLen(Hi.Z - Lo.Z, FD.Units)]);
  InvalidateStatus;
  Invalidate;
end;

{ A right click that did not turn into a pan.

  A dimension takes it first, whatever tool is in hand, because clicking one
  to retype it is older than this menu and is what the right button on a
  dimension has always done.  Otherwise it belongs to the select tool: pick
  what is under the cursor, the way SketchUp does, so the menu has something
  to talk about, and then offer what can be done to it. }
procedure TMainForm.RightClickAt(X, Y: Integer);
var
  I: Integer;
  P: TPoint;
begin
  if FMode <> mdPro then Exit;
  I := FD.Doc.HitTest(Proj, X, Y, 10 * FUIScale);
  if (I >= 0) and (FD.Doc[I].Kind = ekDim) then
  begin
    EditDimUnder(X, Y);
    Exit;
  end;
  if FTool <> ptSelect then Exit;

  { Clicking something that is not in the selection makes it the selection -
    right-clicking one face while five others are picked and having it turn
    over the five would be a nasty surprise.  Clicking inside the selection
    leaves it alone, which is how a whole roof gets turned over at once. }
  I := PickForMenu(X, Y);
  if I >= 0 then
  begin
    if not IsSelected(I) then
    begin
      SelectOnly(I);
      FScreenDirty := True;
      InvalidateStatus;
      { drawn before the menu covers it, so what is about to be operated on
        is highlighted while the menu is being read }
      pbScreen.Invalidate;
      Application.ProcessMessages;
    end;
  end
  else if Length(FSel) = 0 then
  begin
    FCmdMsg := 'Nothing there - click something first.';
    InvalidateStatus;
    Exit;
  end;

  FillCanvasMenu;
  if pmCanvas.Items.Count = 0 then Exit;
  P := pbScreen.ClientToScreen(Point(X, Y));
  pmCanvas.PopUp(P.X, P.Y);
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

  { Rest on a point or an edge and the pull goes exactly as far as that
    point is from the face, measured along the normal.  This is the far edge
    of a box: hover it and the push stops flush with the far side, which is
    what SketchUp's inference does and what makes a tunnel possible without
    a number.  A point in the face's own plane says nothing and is ignored. }
  if FSnapKind in [snEndpoint, snMidpoint, snCenter, snCross, snSubMid,
                   snOnEdge, snOrigin] then
  begin
    Flush := (FCur.X - FP1.X) * Nm.X + (FCur.Y - FP1.Y) * Nm.Y + (FCur.Z - FP1.Z) * Nm.Z;
    if Abs(Flush) > 1E-6 then
    begin
      FPushFlush := True;
      Exit(Flush);
    end;
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
  HF := InContextFace(FD.Doc.HitFace(Proj, FMouseSX, FMouseSY));
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
  { the drill's preview shows it coming out the far side, because that is
    what it is about to do - a preview that stops where the cursor is would
    be telling you something the tool has no intention of doing }
  if (FTool = ptDrill) and (Abs(R) > 1E-9) then
    R := FD.Doc.ThroughDistance(FPushFace, R);
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
{ The ground, ruled, under a free camera.

  The three colored axes tell you which way is up and nothing else - there
  is no sense of the floor a model is standing on, and no way to read how far
  across it something sits.  A lattice on Z = 0 gives both, the way a
  horizon does.

  It follows the camera rather than being a fixed sheet: the four corners of
  the window are cast back onto the ground, and the lattice is ruled over
  whatever that covers.  Pitch is the same round number the paper grid and
  the scale bar use, so the crossings are places the cursor can land.

  Two guards.  A camera looking along the ground casts its corners to the
  horizon and beyond, so the count is capped and the whole thing dropped when
  the view is too flat to be worth ruling.  And it is drawn faint, under
  everything: it is the floor, not part of the drawing. }
procedure TMainForm.PaintGroundGrid(Pitch: Double);
const
  MAX_LINES = 160;
  { how far apart two lines of the lattice have to be before ruling both of
    them tells you anything }
  MIN_PX = 12;
var
  I, N, Drawn, Missed: Integer;
  Lo, Hi: TP3;
  C: array[0..3] of TP3;
  Fade, Heavy, A: Double;
  X0, X1, Y0, Y1, V, PitchX, PitchY, Area, LX, LY: Double;
  PA, PB, UX, UY, Org: TPointF;
  Col: TPix;

  { the next step up that keeps the crossings on round numbers: two, five,
    ten, twenty, fifty times the pitch the paper grid picked }
  function Coarser(Cur, Base: Double): Double;
  var
    K: Double;
  begin
    K := Cur / Base;
    if K < 1.5 then Result := Base * 2
    else if K < 3.5 then Result := Base * 5
    else Result := Cur * 2;
  end;

  { Both ends off the same edge of the window, so no part of it can be on
    the window.  The lattice is ruled over the box round the four corners of
    the window cast onto the ground, and that box is bigger than the window
    itself whenever the camera is turned - so a fair number of these lines
    run past the corners without ever crossing the glass. }
  function Offscreen(const A, B: TPointF): Boolean;
  begin
    Result := ((A.X < 0) and (B.X < 0)) or
              ((A.Y < 0) and (B.Y < 0)) or
              ((A.X > FPaper.Width) and (B.X > FPaper.Width)) or
              ((A.Y > FPaper.Height) and (B.Y > FPaper.Height));
  end;

  { the ground point under a screen point, or False when the camera is too
    flat for there to be one worth having }
  function Ground(SX, SY: Double; out P: TP3): Boolean;
  begin
    P := Unproject(Proj, SX, SY, plXY, P3(0, 0, 0));
    Result := not (IsNan(P.X) or IsNan(P.Y) or IsInfinite(P.X) or
                   IsInfinite(P.Y)) and
              (Abs(P.X) < 1E6) and (Abs(P.Y) < 1E6);
  end;

begin
  if Pitch <= 1E-9 then Exit;
  if not Ground(0, 0, C[0]) then Exit;
  if not Ground(FPaper.Width, 0, C[1]) then Exit;
  if not Ground(FPaper.Width, FPaper.Height, C[2]) then Exit;
  if not Ground(0, FPaper.Height, C[3]) then Exit;

  Lo := C[0];
  Hi := C[0];
  for I := 1 to 3 do
  begin
    Lo.X := Min(Lo.X, C[I].X);  Hi.X := Max(Hi.X, C[I].X);
    Lo.Y := Min(Lo.Y, C[I].Y);  Hi.Y := Max(Hi.Y, C[I].Y);
  end;

  { Only the quarter the drawing belongs in - where both axes are drawn
    solid.  From a note, 17 September: "that grid should only be visible between the
    green and red in the default view... not the dashed negative side".  The
    dashes mean the other way along an axis, and floor out there is floor
    nobody is drawing on. }
  Lo.X := Max(Lo.X, 0);
  Lo.Y := Max(Lo.Y, 0);
  if (Hi.X <= Lo.X) or (Hi.Y <= Lo.Y) then Exit;

  { a camera near the ground makes that box enormous; rule what is worth
    ruling and leave the rest }
  if ((Hi.X - Lo.X) / Pitch > MAX_LINES * 40) or
     ((Hi.Y - Lo.Y) / Pitch > MAX_LINES * 40) then Exit;

  { Rule it at a pitch you can actually see.

    The camera is orthographic, so parallel ground lines stay parallel and
    evenly spaced on the glass - but a tilted view squashes one family of
    them by the cosine of the tilt, and a low camera squashes it to nothing.
    The pitch is chosen in world units for the paper grid, which is square to
    the screen, so nobody had asked what it came to on the ground: at a
    working angle it came to about six pixels, and two hundred and sixty
    faint lines six pixels apart are not a lattice, they are a gray wash that
    costs twenty-seven milliseconds a frame to lay down.

    So each family is coarsened on its own until its lines are far enough
    apart to read, by two and five and ten - never by three or seven - so
    that every crossing left is still a round number the cursor can land on.

    This is a change to how it looks as much as to what it costs, and it
    looks better: the floor reads as a floor instead of a haze, and it is the
    near ground that gets the detail. }
  UX := ScreenOf(P3(1, 0, 0));
  UY := ScreenOf(P3(0, 1, 0));
  Org := ScreenOf(P3(0, 0, 0));
  UX := PtF(UX.X - Org.X, UX.Y - Org.Y);
  UY := PtF(UY.X - Org.X, UY.Y - Org.Y);
  { the area one square of the lattice covers on screen, per world unit }
  Area := Abs(UX.X * UY.Y - UX.Y * UY.X);
  LX := Sqrt(UX.X * UX.X + UX.Y * UX.Y);
  LY := Sqrt(UY.X * UY.X + UY.Y * UY.Y);

  { lines of constant X run along Y, so what separates them is the width of
    the square across the Y direction - and the other way about }
  PitchX := Pitch;
  if LY > 1E-9 then
    while (Area / LY) * PitchX < MIN_PX do PitchX := Coarser(PitchX, Pitch);
  PitchY := Pitch;
  if LX > 1E-9 then
    while (Area / LX) * PitchY < MIN_PX do PitchY := Coarser(PitchY, Pitch);

  { And coarse enough that the whole window gets ruled.

    It used to stop after MAX_LINES and leave the rest of the ground bare:
    the lines are laid from the low corner of the box the window casts onto
    the ground, so what ran out was the near half - the half the drawing is
    usually standing in.  From a note, 17 September: "i clicked the grid button and
    it didnt turn on.  i am not seeing it while i orbit."  It was on, and it
    was behind him.  Now the pitch is coarsened until the count fits, which
    is a wider lattice on a wide view rather than half a one. }
  while (Hi.X - Lo.X) / PitchX > MAX_LINES do PitchX := Coarser(PitchX, Pitch);
  while (Hi.Y - Lo.Y) / PitchY > MAX_LINES do PitchY := Coarser(PitchY, Pitch);

  X0 := Floor(Lo.X / PitchX) * PitchX;
  X1 := Ceil(Hi.X / PitchX) * PitchX;
  Y0 := Floor(Lo.Y / PitchY) * PitchY;
  Y1 := Ceil(Hi.Y / PitchY) * PitchY;

  Col := Theme.Grid;
  { As strong as the ruled paper in the flat views, and every fifth line
    heavier, so the floor reads as squared paper laid on the ground rather
    than a haze you have to look for.  From a note, 17 September: "i clicked the
    grid button and it didnt turn on" - it had, at a third of the weight the
    plan view uses, on a light screen. }
  Fade := 0.45;
  Heavy := 1.00;
  { Hairlines, not the general line.  The general one measures its distance
    from every pixel near it, which on a hundred and ninety faint lines was
    most of every orbiting frame on the machine - 17 September, "zooming
    and moving around is not as smooth as it used to be".  These are one
    pixel wide and faint, and the cheap antialiasing looks the same. }

  Drawn := 0;
  Missed := 0;

  V := X0;
  N := 0;
  { the cap is a guard now rather than the rule - the pitch above is what
    keeps the count sane }
  while (V <= X1 + 1E-9) and (N < MAX_LINES * 2) do
  begin
    PA := ScreenOf(P3(V, Y0, 0));
    PB := ScreenOf(P3(V, Y1, 0));
    if Offscreen(PA, PB) then Inc(Missed)
    else
    begin
      if Abs(V / PitchX - Round(V / PitchX / 5) * 5) < 1E-6 then A := Heavy
      else A := Fade;
      FPaper.HairLine(PA.X, PA.Y, PB.X, PB.Y, Col, A);
      Inc(Drawn);
    end;
    V := V + PitchX;
    Inc(N);
  end;

  V := Y0;
  N := 0;
  while (V <= Y1 + 1E-9) and (N < MAX_LINES * 2) do
  begin
    PA := ScreenOf(P3(X0, V, 0));
    PB := ScreenOf(P3(X1, V, 0));
    if Offscreen(PA, PB) then Inc(Missed)
    else
    begin
      if Abs(V / PitchY - Round(V / PitchY / 5) * 5) < 1E-6 then A := Heavy
      else A := Fade;
      FPaper.HairLine(PA.X, PA.Y, PB.X, PB.Y, Col, A);
      Inc(Drawn);
    end;
    V := V + PitchY;
    Inc(N);
  end;
  if FTimings then
  begin
    TimingLine(Format('ground grid: %d ruled, %d missed the window; x %.2f..%.2f pitch %.3f, y %.2f..%.2f pitch %.3f, fade %.2f',
      [Drawn, Missed, X0, X1, PitchX, Y0, Y1, PitchY, Fade]));
  end;
  FPaper.Touch;
end;

{ The three axes, drawn as what they are: infinite lines.

  They used to be drawn a fixed number of world units out from the origin -
  a screenful, more or less - which is fine while the origin is in view and
  wrong the moment you pan away from it or zoom out past it.  They stopped in
  mid air.  In a program where the red line IS the X axis, an axis with an
  end in the middle of the paper is a lie about the model, and SketchUp's go
  on for ever because that is the truth about them.

  So: find where the origin lands and which way the axis runs on the glass,
  then draw the stretch of that line which crosses the paper - the solid half
  forwards from the origin, the dashed half back the other way - whether or
  not the origin itself is anywhere near the window. }
procedure TMainForm.PaintAxes;
const
  { Which axis is which where the three meet, while the grid is on.  They
    said north, east and up at first (the owner, 25 September), but a
    direction is the same everywhere, and here it only showed while the
    origin was on the paper - he draws out in the positive quarter, away
    from it.  The directions went to a compass in the corner
    (PaintCompass); the axes say what they are: "x y and z on the lines...
    would be -z for down". }
  AXIS_TAGS: array[0..2, 0..1] of string = (('X', '-X'), ('Y', '-Y'), ('Z', '-Z'));
  { how far out from the origin, pixels, and how much further a word is
    moved while it would land on one already down }
  AXIS_TAG_OUT = 60;
  AXIS_TAG_STEP = 18;
var
  K, N, NPlaced: Integer;
  Len, T0, T1, Step, A, B2: Double;
  B: TP3;
  PO, PB, D: TPointF;
  Col: TPix;
  Placed: array[0..5] of TRect;

  { a word out along the axis from the origin, centered on the line itself
    and ringed in black so it reads over the line and the grid ("directly
    on the lines... maybe outline them in black").  Orbiting, two axes can
    come to point the same way on the glass, and the words at one
    distance sat on top of each other ("keep them all far enough away from
    the point so in 3d view they arent looking stacked") - so a word that
    would land on one already down moves further out along its own line
    until it is clear.  Left out where it would be off the paper. }
  procedure Tag(Sg: Integer; const S: string);
  var
    Sz: TSize;
    X, Y, Out_: Double;
    TX, TY, OX, OY, Try_, J: Integer;
    Box: TRect;
    Clear: Boolean;
  begin
    Sz := FPaper.TextExtent(S, FDimFont);
    Out_ := AXIS_TAG_OUT * FUIScale;
    for Try_ := 0 to 15 do
    begin
      X := PO.X + Sg * D.X * Out_;
      Y := PO.Y + Sg * D.Y * Out_;
      TX := Round(X - Sz.cx / 2); TY := Round(Y - Sz.cy / 2);
      Box := Rect(TX - 4, TY - 2, TX + Sz.cx + 4, TY + Sz.cy + 2);
      Clear := True;
      for J := 0 to NPlaced - 1 do
        if (Box.Left < Placed[J].Right) and (Placed[J].Left < Box.Right) and
           (Box.Top < Placed[J].Bottom) and (Placed[J].Top < Box.Bottom) then Clear := False;
      if Clear then Break;
      Out_ := Out_ + AXIS_TAG_STEP * FUIScale;
    end;
    if (X < Sz.cx) or (Y < Sz.cy) or (X > FPaper.Width - Sz.cx) or (Y > FPaper.Height - Sz.cy) then Exit;
    if NPlaced <= High(Placed) then
    begin
      Placed[NPlaced] := Box;
      Inc(NPlaced);
    end;
    for OX := -1 to 1 do
      for OY := -1 to 1 do
        if (OX <> 0) or (OY <> 0) then
          FPaper.TextOut(TX + OX, TY + OY, S, FDimFont, Pix(0, 0, 0));
    FPaper.TextOut(TX, TY, S, FDimFont, Col);
  end;

begin
  PO := ScreenOf(P3(0, 0, 0));
  if IsNan(PO.X) or IsNan(PO.Y) or IsInfinite(PO.X) or IsInfinite(PO.Y) then
    Exit;
  if (Abs(PO.X) > 1E7) or (Abs(PO.Y) > 1E7) then Exit;
  NPlaced := 0;

  for K := 0 to 2 do
  begin
    Col := AxisPix(K);

    { one world unit along this axis, to read its direction off the glass }
    B := P3(0, 0, 0);
    case K of
      0: B.X := 1;
      1: B.Y := 1;
    else B.Z := 1;
    end;
    PB := ScreenOf(B);
    Len := Sqrt(Sqr(PB.X - PO.X) + Sqr(PB.Y - PO.Y));
    { An axis pointing straight at the camera has no length on the glass -
      PLAN looks down Z - and drawing it puts a dot of color on the origin
      that means nothing.  Left out instead. }
    if Len < 1E-9 then Continue;
    D := PtF((PB.X - PO.X) / Len, (PB.Y - PO.Y) / Len);

    { the piece of the infinite line that is actually on the paper }
    if not ClipToBox(PO.X, PO.Y, D.X, D.Y, FPaper.Width, FPaper.Height,
                     T0, T1) then Continue;

    { forwards from the origin, solid }
    A := Max(T0, 0);
    if T1 > A then
      FPaper.Line(PO.X + D.X * A, PO.Y + D.Y * A,
                  PO.X + D.X * T1, PO.Y + D.Y * T1, 1.8, Col, 0.55);

    { backwards, dashed - drawn from the origin outwards so the dashes stay
      put as you pan rather than crawling along the line }
    B2 := Min(T1, 0);
    if T0 < B2 then
    begin
      Step := 11;
      N := Max(0, Trunc(-B2 / Step));
      while -N * Step > T0 do
      begin
        A := -N * Step;
        if A <= B2 then
          FPaper.Line(PO.X - D.X * (N * Step), PO.Y - D.Y * (N * Step),
                      PO.X - D.X * (N * Step + 6), PO.Y - D.Y * (N * Step + 6),
                      1.4, Col, 0.42);
        Inc(N);
        { a window a long way from the origin is a lot of dashes nobody
          sees; stop before it becomes the slowest thing on the screen }
        if N > 4000 then Break;
      end;
    end;

    if FShowGrid then
    begin
      Tag(1, AXIS_TAGS[K, 0]);
      Tag(-1, AXIS_TAGS[K, 1]);
    end;
  end;
  FPaper.Touch;
end;

{ Everything the paper is a picture of, gathered so it can be compared with
  what it was drawn for last time. }
function TMainForm.PaperSig: TPaperSig;
begin
  { zeroed whole, because it is compared whole - a packed record with a gap
    in it would compare unequal on whatever happened to be in the gap }
  FillChar(Result, SizeOf(Result), 0);
  Result.Mode := Ord(FMode);
  Result.ThemeIdx := FThemeIdx;
  Result.W := FPaper.Width;
  Result.H := FPaper.Height;
  Result.View := FD.View;
  Result.Units := FD.Units;
  Result.Grid := FShowGrid;
  Result.Axes := FMode = mdPro;
  Result.Ppu := Ppu;
  Result.ViewX := FD.ViewX;
  Result.ViewY := FD.ViewY;
  Result.Az := FD.Az;
  Result.El := FD.El;
  Result.Zoom := FD.Zoom;
  Result.Snap := SnapStep;
  Result.UIScale := FUIScale;
end;

{ The paper, the grid on it and the axes over it.

  Drawn again only when something it is a picture of has moved.  It used to
  be drawn every time anybody asked, and thirty-three places ask - so a mouse
  move that changed nothing but the rubber band still ruled the whole grid,
  cast the four corners of the window back onto the ground, and re-scattered
  the grain.

  The grain is the part worth naming: it is random noise over sixteen per
  cent of the pixels, which on a full window is two hundred thousand random
  numbers and two hundred thousand pixel writes, thrown away and done again
  the next frame.  It was also being re-rolled every frame, so the paper
  quietly crawled.  Now it is laid down once and stays put, which is both
  faster and what paper does.

  Three quarters of a frame was measured as paper and composite, neither of
  which depends on the model at all; this is the paper half of that.

  The signature has to name everything the picture depends on or the paper
  goes stale - so it carries the camera, the zoom, the pan, the theme, the
  units, the snap step (the grid is never ruled finer than you can land on),
  the interface scale and the size of the surface.  Nothing outside this
  procedure and the two it calls ever draws on FPaper, which is what makes
  one guard here enough. }
procedure TMainForm.RepaintPaper;
var
  Key: string;
  GridPitch: Double;
  T0, TBase, TGrid: QWord;
  Sig: TPaperSig;
begin
  Sig := PaperSig;
  if FPaperOK and CompareMem(@Sig, @FPaperSig, SizeOf(Sig)) then
  begin
    Inc(FPaperSkips);
    Exit;
  end;
  FPaperSig := Sig;
  FPaperOK := True;
  Inc(FPaperPaints);
  T0 := GetTickCount64;
  try
  if FMode = mdPro then
  begin
    { The fill does not move with the camera, so it is made once and copied.
      It was made fresh on every paint - a shaded fill of every pixel, and on
      a light theme a scatter of grain - which was five or six milliseconds
      of each orbiting frame at the window size, for the same picture
      every time.  Copied, the grain also stays where it was laid rather than
      crawling as the camera turns, which the note above already promised. }
    Key := Format('%d %d %d', [FThemeIdx, FPaper.Width, FPaper.Height]);
    if (FPaperBase = nil) or (Key <> FPaperBaseKey) then
    begin
      if FPaperBase = nil then
        FPaperBase := TArtSurface.Create(FPaper.Width, FPaper.Height)
      else
        FPaperBase.SetSize(FPaper.Width, FPaper.Height);
      PaintScreenPaper(FPaperBase, Theme, False);
      FPaperBaseKey := Key;
    end;
    FPaper.CopyRegion(FPaperBase, 0, 0, 0, 0, FPaper.Width, FPaper.Height);
    TBase := GetTickCount64;
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
        { The flat paper view is ruled like paper - it is a plan, and the
          paper is the ground seen square on.  Both views that show the model
          in three dimensions get the floor itself: squares lying in the red
          and green plane, turning with the camera.  From a note, 17 September: "in
          any 3d view that grid should only be visible between the green and
          red" - the isometric lattice climbed the two walls as well, which
          is paper, not a floor. }
        vkPlan: PaintMeasuredGrid(FPaper, Theme, GridPitch, FD.ViewX, FD.ViewY, 5);
        vkIso, vkOrbit: PaintGroundGrid(GridPitch / Ppu);
      end;
    end;
    TGrid := GetTickCount64;
    PaintAxes;
    { where the paper's time really goes.  It was assumed to be the fill and
      the grain; it is not, on any theme with a dark screen - see the numbers
      in TODO.md. }
    if FTimings then
    begin
      TimingLine(Format('paper: painted %d, skipped %d - base %d, grid %d, axes %d',
        [FPaperPaints, FPaperSkips, TBase - T0, TGrid - TBase,
         GetTickCount64 - TGrid]));
    end;
  end
  else
    PaintScreenPaper(FPaper, Theme, FShowGrid);
  finally
    FMsPaper := FMsPaper + (GetTickCount64 - T0);
  end;
end;

procedure TMainForm.Recompose;
var
  R: TRect;
begin
  R := ActiveInk.TakeDirty;
  if (R.Right <= R.Left) or (R.Bottom <= R.Top) then Exit;
  InflateRect(R, 1, 1);
  FArt.CompositeOver(FPaper, ActiveInk, R);
  FShotOK := False;
  FScreenDirty := True;
end;

procedure TMainForm.RecomposeAll;
var
  T0: QWord;
begin
  FShotOK := False;
  T0 := GetTickCount64;
  FArt.CompositeOver(FPaper, ActiveInk, Rect(0, 0, FArt.Width, FArt.Height));
  ActiveInk.ResetDirty;
  FScreenDirty := True;
  FMsComp := FMsComp + (GetTickCount64 - T0);
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
var
  T0: QWord;
  Half: TArtSurface;
begin
  T0 := GetTickCount64;
  try
  FD.Doc.Quick := FCameraMoving and FQuickFrames;
  { Half resolution pays only when the fill is what costs - zoomed in on a
    big drawing - and loses a millisecond or two to the blow-up when it is
    not.  Measured (tools/inkprof, the 712-face robot): whole model in the
    window, quick frame 9 ms, half 12; zoomed in four times, quick 9, half
    6, a still frame 13.  So it is not a setting: the first moving frame is
    drawn at full size, and if that came in slow the rest of the move is
    drawn at half.  A still frame puts it back. }
  if not FD.Doc.Quick then FMoveHalf := False;
  Half := nil;
  if FMoveHalf then Half := FInkHalf;
  FInkPro.QuickFill := FD.Doc.Quick;
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
      FD.Doc.Render(FInkPro, Proj, FD.Units, FDimFont, AnnotColor, FEdgeW, Half);
      if FD.Doc.Quick and not FMoveHalf and (GetTickCount64 - T0 > 25) then
        FMoveHalf := True;
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
  finally
    FMsRender := FMsRender + (GetTickCount64 - T0);
  end;
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

{ Would the camera as it stands show any of the drawing?  Asked of a camera
  read back from a file or a handoff before it is trusted: the drawing's
  bounds, projected, have to land somewhere near the paper and be more than
  a few pixels across.  An empty sheet shows everything there is. }
function TMainForm.CameraShowsSomething: Boolean;
var
  Lo, Hi, C: TP3;
  P: TPointF;
  K: Integer;
  MinX, MinY, MaxX, MaxY, Margin: Double;
begin
  Result := True;
  if FD.Zoom <= ZOOM_MIN * 1.01 then Exit(False);
  if not FD.Doc.Bounds(Lo, Hi) then Exit;
  MinX := 1E30; MinY := 1E30; MaxX := -1E30; MaxY := -1E30;
  for K := 0 to 7 do
  begin
    C := P3(IfThen(K and 1 = 0, Lo.X, Hi.X), IfThen(K and 2 = 0, Lo.Y, Hi.Y),
            IfThen(K and 4 = 0, Lo.Z, Hi.Z));
    P := Project(Proj, C);
    if IsNan(P.X) or IsNan(P.Y) or IsInfinite(P.X) or IsInfinite(P.Y) then Exit(False);
    MinX := Min(MinX, P.X); MaxX := Max(MaxX, P.X);
    MinY := Min(MinY, P.Y); MaxY := Max(MaxY, P.Y);
  end;
  { smaller than a fingertip: zoomed out to nothing }
  if Max(MaxX - MinX, MaxY - MinY) < 6 then Exit(False);
  { or panned right off - a few screens away is still findable by hand,
    further than that is not }
  Margin := 3 * Max(FArt.Width, FArt.Height);
  if (MaxX < -Margin) or (MaxY < -Margin) or
     (MinX > FArt.Width + Margin) or (MinY > FArt.Height + Margin) then Exit(False);
end;

procedure TMainForm.ZoomAt(Factor: Double; AnchorSX, AnchorSY: Double);
var
  W: TP3;
  P: TPointF;
  NewZoom: Double;
begin
  NewZoom := EnsureRange(FD.Zoom * Factor, ZOOM_MIN, ZOOM_MAX);
  if NewZoom = FD.Zoom then Exit;
  { keep whatever is under the anchor point exactly where it is }
  W := WorldAt(AnchorSX, AnchorSY);
  FD.Zoom := NewZoom;
  P := Project(Proj, W);
  FD.ViewX := FD.ViewX + (AnchorSX - P.X);
  FD.ViewY := FD.ViewY + (AnchorSY - P.Y);
  { a wheel zoom is a moving camera too: quick now, full when it settles }
  if FQuickFrames then
  begin
    FCameraMoving := True;
    FLastWheel := GetTickCount64;
  end;
  ViewMoved;
end;

procedure TMainForm.SetScaleIdx(I: Integer);
var
  CX, CY: Double;
  W: TP3;
  P: TPointF;
begin
  Act('scale ' + IntToStr(I));
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
  ViewMoved;
end;

{ The camera has moved: say so, and draw it once, on the next frame.

  From a note, 17 September, on Windows: "seems to be sluggish responding to my
  zoom in and zoom out and moving".  His report had frames of 400 to 600 ms
  with thirteen things in the drawing, nearly all of it "paper".  The paper
  is cheap - 3 to 16 ms here with his drawing - but a wheel zoom redrew it,
  the drawing and the composite at once for every wheel event, and a
  smooth wheel or a touchpad on Windows sends many more of those than the
  screen shows frames.  The frame watchdog adds up everything done between
  two paints, so twenty-five redraws nobody saw came out as one frame of
  four hundred milliseconds.

  It also invalidated the whole window each time - the tool strip, the
  deck, every panel - where only the drawing had changed.  That cost never
  appeared in the watchdog's numbers at all, because they only time the
  drawing's own paint.

  So a camera change only marks the view, and the tick draws it once,
  however many changes came in since the last frame; a paint that arrives
  first draws it itself.  The readouts along the top are refreshed on their
  own throttle, as they always were. }
procedure TMainForm.ViewMoved;
begin
  FViewDirty := True;
  FScreenDirty := True;
  InvalidateStatus;
end;

procedure TMainForm.FlushView;
begin
  if not FViewDirty then Exit;
  FViewDirty := False;
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
{ Frame the drawing.

  It moves there rather than arriving there, when there is a window up to
  watch it happen and the change is worth watching.  the rule, and it is
  the right one for every view change and not only the cube's: a drawing that
  jumps from one framing to another makes you work out what happened, and one
  that travels lets you keep hold of where things are.

  Not while loading, not before the window exists, and not in a paper mode -
  and not for a nudge, because a move nobody can see is a third of a second
  of nothing. }
procedure TMainForm.FitView(Travel: Boolean = True);
var
  Lo, Hi, Mid: TP3;
  P: TPointF;
  BaseP, W, H, Z, NewZoom: Double;
  FitZ, FitX, FitY: Double;
begin
  if Travel and FBooted and (FMode = mdPro) and (FD <> nil) and
     (FD.View = vkOrbit) and
     (FGlideT = 0) and FitTarget(False, FD.Az, FD.El, FitZ, FitX, FitY) and
     ((Abs(FitZ - FD.Zoom) > 0.02 * Max(1, FD.Zoom)) or
      (Abs(FitX - FD.ViewX) > 4) or (Abs(FitY - FD.ViewY) > 4)) then
  begin
    GlideCamera(FD.Az, FD.El, FitZ, FitX, FitY);
    if FGlideT > 0 then Exit;
  end;

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
    if NewZoom < ZOOM_MIN then NewZoom := ZOOM_MIN;
    if NewZoom > ZOOM_MAX then NewZoom := ZOOM_MAX;
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
  { A new sheet opens on the 3D corner view.  It began in PLAN, which is the
    right view for a floor plan and the wrong one for a duct: nothing drawn
    there has a height until you leave it, and the first thing everybody did
    was leave it. }
  View := vkOrbit;
  Plane := plXY;
  Az := -Pi / 4;
  El := 35.264 * Pi / 180;   // start on the isometric corner
  { Off, which means the whole model.  A feature that hides part of somebody's
    drawing before they have heard of it is a feature they will never
    forgive. }
  SliceOn := False;
  SliceLo := 0;
  SliceHi := 8;
  SetLength(Undo, UNDO_LEVELS);
  SetLength(Redo, UNDO_LEVELS);
end;

destructor TDrawing.Destroy;
begin
  Doc.Free;
  inherited Destroy;
end;

{ A new sheet.  Seeded with the example unless a blank one was asked for,
  because an empty sheet explains nothing and rubbing a drawing out is one
  gesture - which is not true the other way round. }
procedure TMainForm.NewDrawing(Seed: Boolean);
var
  N, K, Nm: Integer;
  Taken: Boolean;
  Was: string;
begin
  N := Length(FDrawings);
  SetLength(FDrawings, N + 1);
  { the lowest 'Sheet k' that no sheet already has, so a file whose sheets
    were named out of order does not get two of the same }
  Nm := 1;
  repeat
    Taken := False;
    for K := 0 to N - 1 do
      if FDrawings[K].Name = Format('Sheet %d', [Nm]) then Taken := True;
    if Taken then Inc(Nm);
  until not Taken;
  FDrawings[N] := TDrawing.Create(Format('Sheet %d', [Nm]));
  if N > 0 then
  begin
    { a new sheet inherits how you were working }
    FDrawings[N].ScaleIdx := FD.ScaleIdx;
    FDrawings[N].SnapIdx := FD.SnapIdx;
    FDrawings[N].Units := FD.Units;
    FDrawings[N].View := FD.View;
  end;
  FTabIdx := N;
  LeaveSheet;
  FD := FDrawings[N];
  FD.ViewX := Round(FArt.Width * 0.10);
  FD.ViewY := Round(FArt.Height * 0.88);
  if FBooted then
  begin
    { Boot fills the first sheet itself - from the command line, the draft,
      or the example - so this only runs for a sheet somebody asked for. }
    if Seed then
    begin
      Was := FD.Name;
      LoadExample;
      { the example's own name belongs to the first sheet of a drawing; a
        second one keeps the number it was given, or there are two tabs
        called the same thing }
      if N > 0 then FD.Name := Was;
    end;
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
  LeaveSheet;
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
  K, Ans: Integer;
  Last: Boolean;
begin
  if (I < 0) or (I > High(FDrawings)) then Exit;
  Last := Length(FDrawings) = 1;
  { A sheet with work on it is asked about, the way a document is.  Save
    writes the whole drawing - a sheet is part of one file - and asks for a
    name if it has none; declining that keeps the sheet.  Close without
    saving means exactly that: the sheet is gone from the drawing, and the
    draft follows the drawing.

    Work on it, though, not merely things on it.  Nothing changed since it
    was loaded or saved is nothing to lose, and the example the program
    starts with arrives with three hundred things on it - so putting it down
    brought up "save the drawing first?", which is a question about somebody
    else's drawing. }
  if (FDrawings[I].Doc.Live > 0) and FDrawings[I].Dirty then
  begin
    Ans := QuestionDlg('Close this sheet',
      Format('"%s" has %d things on it.  Save the drawing before closing it?',
        [FDrawings[I].Name, FDrawings[I].Doc.Live]),
      mtConfirmation,
      [mrYes, 'Save the drawing', 'IsDefault',
       mrNo, 'Close without saving',
       mrCancel, 'Keep it open', 'IsCancel'], 0);
    if Ans = mrCancel then Exit;
    if Ans = mrYes then
    begin
      DoSave;
      if (FDocPath = '') or FDrawings[I].Dirty then Exit;   { save as was declined, or failed }
    end;
  end;

  FDrawings[I].Free;
  for K := I to High(FDrawings) - 1 do
    FDrawings[K] := FDrawings[K + 1];
  SetLength(FDrawings, Length(FDrawings) - 1);

  { Closing the only sheet closes the drawing, and what is left is not
    nothing - a window with no sheet in it has no answer to "now what".  So
    the program comes back the way it starts: the example, with no file
    behind it, and the draft dropped, because putting a drawing down and
    having it follow you to the next launch is not putting it down. }
  if Last then
  begin
    LeaveSheet;
    NewDrawing(True);
    FDocPath := '';
    FSavedSeq := FEditSeq;
    DropDraft;
    FCmdMsg := 'Closed.  Here is the example again - draw over it, or ' +
      'press Ctrl+N for an empty sheet.';
    pbCmd.Invalidate;
    Exit;
  end;

  LeaveSheet;
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
    { The close cross, on whichever tab is current - including when it is the
      only one.  Hiding it there left somebody with a drawing they could not
      put down: no cross, and nothing that says why.  Closing the last sheet
      is a perfectly ordinary thing to want, and what comes up afterwards is
      the example, which is what the program starts with anyway. }
    if IsCur then
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
    if (I = FTabIdx) and (X > R.Right - Round(26 * FUIScale)) then
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
  Y0, RowY, X, Avail, SegW, SwSz, SwGap, I, G, GX, GrpGap: Integer;
  RightW6, GrpX, NSet, NamedW: Integer;
  NamedIcons: Boolean;
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

  { The same six, with a word each.  With the tools gone from the deck there
    is room for the labels, and a word beats a pictogram every time for
    somebody who has not learned the pictogram yet. }
  procedure AddNamed6(RY: Integer; const A: array of Integer;
    const K: array of TIconKind; const N: array of string;
    const H: array of string);
  var
    IX, J, BW: Integer;
  begin
    BW := NamedW;
    IX := W - Pad - Length(A) * BW - (Length(A) - 1) * RowGap;
    for J := 0 to High(A) do
    begin
      { narrow: the picture alone, with its name in the tooltip - see where
        NamedIcons is decided }
      if NamedIcons then
        Add(dkIcon, Rect(IX, RY, IX + BW, RY + RowH), GRP_ICON, A[J], '',
          N[J] + ' - ' + H[J], K[J])
      else
        Add(dkSegment, Rect(IX, RY, IX + BW, RY + RowH), GRP_ICON, A[J], N[J],
          H[J], K[J]);
      Inc(IX, BW + RowGap);
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
  { A guard against building a deck into nothing.  It was 40 tall, which was
    below anything the deck had ever been - until PRO went to a single row
    and came out 34, whereupon the whole settings row silently stopped being
    built and the panel painted empty.  A row plus its padding is the real
    floor. }
  if (W < 40) or (H < 24) then Exit;

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
    { --- the tools have gone to the strip down the left ------------------
      They were two rows of six here, and the deck was three rows deep for
      it.  Standing them up on the left costs width, of which a screen has
      plenty, and gives the height back to the drawing - and a column with
      the names beside it reads as a list rather than as a wall.  See
      RebuildTools.

      What is left down here is settings and the things that act on the
      program rather than on the drawing, which is a fair division: the left
      hand is what you draw with, the bottom is how. }
    FGrpDivY0 := 0;
    FGrpDivY1 := 0;
    FGrpDivX[0] := -1;
    FGrpDivX[1] := -1;

    { --- row 1: the settings, as buttons that open a list -----------------
      Scale, snap and the pen get set once and then left alone, so a row of
      choices each was drawing area spent on things nobody touches.  Each is
      one button showing what it is set to, and the list opens above it -
      which also means a list can be longer than a row ever was. }
    RowY := Y0;
    Avail := W - 2 * Pad - LabW - RightW6 - RowGap;
    { Two more slots when the drawing has guides in it, and the row divides
      by seven instead of five.  A button for something that does not exist is
      one more thing to read past every time you look at the screen, so they
      are not there until the tape leaves the first guide and are gone again
      when the last one is cleared. }
    { Words, not abbreviations.  "PREC" meant nothing to the person who owns
      the program, which settles it: a label somebody has to decode is a
      label that costs more than the space it saved.  The shop button has
      gone from here altogether - it is a door into the wizards, not a
      setting, and it opened the very same list the strip on the left does. }
    { Five, always.

      There used to be two more here the moment a drawing had a guide in it -
      hide them, and clear them - and making room for them squeezed the five
      settings until their words ran off the ends and over each other.  From a note:
      "those buttons scrunch the buttons up and make their text run off all
      the other buttons" - and it looked it.

      A row that changes width depending on what is in the drawing was the
      mistake.  Both are on the right button now, where SketchUp keeps them
      too - it puts them in Edit and in a docked tray, and the right button is
      nearer to hand than either. }
    NSet := 5;
    { Who gives way when the window is narrow.

      The six buttons on the right were a fixed 88 each, so every pixel a
      narrow window lost came out of the five settings - and at 1100 wide
      they were ninety pixels apiece for "PRINT SCALE 1\"", which needs a
      hundred and thirty.  The words ran out of the buttons and over each
      other; the owner saw it in the help animations.

      The settings say what is set, so they keep the room they need first,
      and the six - one short word each - shrink towards a floor that still
      holds "ORIGIN".  Whatever is still short after that is the painter's
      to handle: see FitCaption, which shortens a label rather than letting
      it run over. }
    Avail := W - 2 * Pad - LabW - Round(18 * FUIScale);
    NamedW := (Avail - (NSet * Round(128 * FUIScale) + (NSet - 1) * RowGap)
               - 5 * RowGap) div 6;
    NamedW := EnsureRange(NamedW, Round(60 * FUIScale), Round(88 * FUIScale));
    { Narrower still, and the six drop their words and keep their pictures.
      A settings button cut down to "1/16\"" no longer says what it sets,
      and FIT, GRID and HELP are pictures anybody can read - with the word
      still in the tooltip. }
    NamedIcons := (Avail - (6 * NamedW + 5 * RowGap) - (NSet - 1) * RowGap)
      div NSet < Round(112 * FUIScale);
    if NamedIcons then NamedW := IconW;
    Avail := Avail - (6 * NamedW + 5 * RowGap);
    SegW := (Avail - (NSet - 1) * RowGap) div NSet;
    Add(dkSegment, Rect(X + 4 * SegW, RowY, X + 5 * SegW - RowGap,
      RowY + RowH), GRP_POPUP, POP_PREC,
      IfThen(FLenDenom = 100,
        'ROUNDED TO  .01"', Format('ROUNDED TO  1/%d"', [FLenDenom])),
      'How finely a length is written down, and what the last field of a ' +
      'dashed entry counts in - 6-8-15 is feet, inches and sixteenths.  ' +
      'It never changes what the drawing holds.', ikDroplet);
    Add(dkSegment, Rect(X, RowY, X + SegW - RowGap, RowY + RowH),
      GRP_POPUP, POP_SCALE,
      'PRINT SCALE  ' + ScaleTable(FD.Units, FD.ScaleIdx).Name,
      'What one foot measures on the paper when this sheet is printed.',
      ikDroplet);
    Add(dkSegment, Rect(X + SegW, RowY, X + 2 * SegW - RowGap, RowY + RowH),
      GRP_POPUP, POP_SNAP, 'SNAP TO  ' + SnapName(FD.Units, FD.SnapIdx),
      'The step the cursor moves in when it is not on a point of the ' +
      'drawing.  It is also what the arrows on the cut fields step by.',
      ikDroplet);
    Add(dkSegment, Rect(X + 2 * SegW, RowY, X + 3 * SegW - RowGap, RowY + RowH),
      GRP_POPUP, POP_COLOR, 'LINE COLOR',
      'The color new lines are drawn in.', ikDroplet);
    Add(dkSegment, Rect(X + 3 * SegW, RowY, X + 4 * SegW - RowGap, RowY + RowH),
      GRP_POPUP, POP_WIDTH, Format('LINE WIDTH  %d px', [FEdgeW]),
      'How thick every edge in this drawing is drawn.  It is one setting for ' +
      'the whole sheet, the way SketchUp does it - not a property of the ' +
      'line you happen to be drawing.', ikDroplet);

    { Open, save, export, print, undo and redo have gone to the top left
      where every program keeps them - see RebuildQuick.  What is left here
      is about the view and the program, and there is room now to say what
      each one is in a word instead of leaving it to a pictogram. }
    AddNamed6(Y0,
      [ACT_FIT, ACT_ORIGIN, ACT_GRID, ACT_UNITS, ACT_THEME, ACT_HELP],
      [ikFit, ikOrigin, ikGrid, ikUnits, ikTheme, ikHelp],
      ['FIT', 'ORIGIN', 'GRID', 'UNITS', 'THEME', 'HELP'],
      ['Frame the whole drawing  (F)',
       'Put 0,0 under the cursor  (O)',
       'Show or hide the measured grid  (G)',
       'Feet-and-inches or metric  (U)',
       'Light chrome or dark  (T)',
       'Help, downloads and updates  (F1 for about)']);
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

{ A button's words, made to fit its width.

  In order: the whole caption; the caption with its long label cut to one
  word ("PRINT SCALE  1\"" to "SCALE  1\""); only the value after the double
  space ("1\""); and last, whatever is left cut short with an ellipsis.  A
  label that runs outside its button, over its neighbor, is the one outcome
  that is never acceptable, because then neither can be read. }
function FitCaption(C: TCanvas; const S: string; Room: Integer): string;
const
  SHORT: array[0..4, 0..1] of string = (
    ('PRINT SCALE', 'SCALE'), ('SNAP TO', 'SNAP'), ('LINE COLOR', 'COLOR'),
    ('LINE WIDTH', 'WIDTH'), ('ROUNDED TO', 'ROUND'));
var
  K, P: Integer;
begin
  Result := S;
  if (Room <= 0) or (C.TextWidth(Result) <= Room) then Exit;
  for K := 0 to High(SHORT) do
    if Pos(SHORT[K, 0], Result) = 1 then
    begin
      Result := SHORT[K, 1] + Copy(Result, Length(SHORT[K, 0]) + 1, MaxInt);
      Break;
    end;
  if C.TextWidth(Result) <= Room then Exit;
  P := Pos('  ', Result);
  if P > 0 then Result := Trim(Copy(Result, P + 2, MaxInt));
  if C.TextWidth(Result) <= Room then Exit;
  while (Length(Result) > 1) and (C.TextWidth(Result + '...') > Room) do
    Delete(Result, Length(Result), 1);
  Result := Result + '...';
end;

procedure TMainForm.pbDeckPaint(Sender: TObject);
var
  Room: Integer;
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
            if Sel then Fg := OnPix(Theme.Accent) else Fg := Theme.Text;
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
            if Sel then Fg := OnPix(Theme.Accent) else Fg := Theme.TextDim;
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
    { the tools are down the left now; what is left here is how, not what }
    Section(0, 'SETTINGS');
  end;

  for I := 0 to High(FDeck) do
  begin
    It := FDeck[I];
    if It.Kind <> dkSegment then Continue;
    if Selected(It) then
      UIFont(pbDeck.Canvas, 10, True, OnPix(Theme.Accent))
    else
      UIFont(pbDeck.Canvas, 10, False, Theme.Text);
    { the room the words have, after the swatch, the chevron and a margin }
    Room := It.Bounds.Right - It.Bounds.Left - Round(10 * FUIScale);
    if It.Group = GRP_POPUP then Dec(Room, Round(16 * FUIScale));
    if (It.Group = GRP_POPUP) and (It.Value = POP_COLOR) then
      Dec(Room, Round(24 * FUIScale));
    if (It.Group = GRP_TOOL) and (FMode = mdPro) then
      Dec(Room, Round(18 * FUIScale));
    It.Caption := FitCaption(pbDeck.Canvas, It.Caption, Room);
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
    GRP_SNAP:  begin
                 FD.SnapIdx := It.Value;
                 Act('snap ' + IntToStr(It.Value));
                 pbDeck.Invalidate;
                 pbCmd.Invalidate;
               end;
    GRP_ICON: DoAction(It.Value);
  end;
end;

{ One action, whichever button asked for it.

  This was the body of a case inside DeckActivate, reachable only from the
  deck.  The quick strip in the title bar needed the same twenty actions, and
  a second copy of them is a second place for Save to stop meaning save. }
procedure TMainForm.DoAction(A: Integer);
begin
  case A of
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
  Turn: Boolean;
  FitZ, FitX, FitY: Double;
begin
  N := Length(VIEW_PRESETS);
  Turn := (FD <> nil) and (FD.View = vkOrbit) and
          (VIEW_PRESETS[((I mod N) + N) mod N].View = vkOrbit) and FBooted;
  FViewPreset := ((I mod N) + N) mod N;
  FD.View := VIEW_PRESETS[FViewPreset].View;
  { One 3D view to another turns; anything that changes the kind of view -
    into or out of the paper modes - does not, because there is no turning
    from one projection into a different one and pretending otherwise would
    be a lie about what happened. }
  if Turn then
  begin
    { A preset re-frames, so the move is aimed at the framing it ends in
      rather than popping into it on arrival - which is what FitView on
      landing used to do. }
    if FitTarget(Length(FSel) > 0, VIEW_PRESETS[FViewPreset].Az,
         VIEW_PRESETS[FViewPreset].El, FitZ, FitX, FitY) then
      GlideCamera(VIEW_PRESETS[FViewPreset].Az, VIEW_PRESETS[FViewPreset].El,
        FitZ, FitX, FitY)
    else
      GlideTo(VIEW_PRESETS[FViewPreset].Az, VIEW_PRESETS[FViewPreset].El);
  end
  else
  begin
    FD.Az := VIEW_PRESETS[FViewPreset].Az;
    FD.El := VIEW_PRESETS[FViewPreset].El;
  end;
  if FD.View <> vkOrbit then FD.Plane := plXY;
  { this can reach PLAN now, so the cut has to come and go with it - and the
    top row has to be laid out again for the strip to appear }
  ApplySlice;
  Relayout;
  FCmdMsg := VIEW_PRESETS[FViewPreset].Name + ' view.';
  if FD.View = vkPlan then
    FCmdMsg := FCmdMsg + '  CUT, top right, slices it - Ctrl+wheel travels ' +
      'up and down.';
  { the turn carries the framing with it now, so there is nothing to do on
    arrival; a change of view kind still snaps into its fit }
  if FGlideT = 0 then FitView(False);
  RebuildDeck;
  pbDeck.Invalidate;
  pbView.Invalidate;
  pbSlice.Invalidate;
  pbCmd.Invalidate;
end;

procedure TMainForm.CycleViewPreset(Step: Integer);
var
  N, I: Integer;
begin
  { Off the rails - a paper mode, or orbited free - either direction goes to
    the first corner.  On them, step round the camera presets only. }
  N := High(VIEW_PRESETS) - FIRST_CAMERA_PRESET + 1;
  if (FViewPreset < FIRST_CAMERA_PRESET) or (FD.View <> vkOrbit) then
    I := FIRST_CAMERA_PRESET
  else
    I := FIRST_CAMERA_PRESET + (((FViewPreset - FIRST_CAMERA_PRESET + Step) mod N) + N) mod N;
  ApplyViewPreset(I);
end;

{ Push the sheet's slice into the document, or take it away.

  Two rules live here and nowhere else.  The first: **a slice only ever
  applies in PLAN.**  It is a horizontal section, which is a thing a plan
  drawing is and a 3D view is not, so leaving it switched on while somebody
  orbits round the model would hide half of it for no reason they could see.
  The second: the document is the only thing that knows about it, and it uses
  the same range for what it draws and for what it lets the cursor touch.

  Called from everywhere the answer could have changed - the view, the tab,
  the numbers themselves - because a slice that is on in the sheet and off in
  the document is exactly the disagreement that makes geometry invisible and
  still snappable. }
procedure TMainForm.ApplySlice;
begin
  if FD = nil then Exit;
  FD.Doc.SetSlice(FD.SliceOn and (FD.View = vkPlan), FD.SliceLo, FD.SliceHi);
end;

procedure TMainForm.SetSlice(AOn: Boolean; ALo, AHi: Double; const Why: string);
var
  T: Double;
  N: Integer;
begin
  if AHi < ALo then begin T := ALo; ALo := AHi; AHi := T; end;
  FD.SliceOn := AOn;
  FD.SliceLo := ALo;
  FD.SliceHi := AHi;
  ApplySlice;
  RenderPro;
  RecomposeAll;
  if Assigned(pbSlice) then pbSlice.Invalidate;
  Invalidate;
  if Why <> '' then FCmdMsg := Why
  else if not AOn then FCmdMsg := 'Cut off - the whole model is in the drawing.'
  else
  begin
    N := FD.Doc.OutsideSlice;
    { Say what is being kept out.  Somebody whose drawing has just gone
      missing must not have to guess where it went. }
    if N = 0 then
      FCmdMsg := Format('Cut %s to %s - everything is in it.',
        [FormatLen(ALo, FD.Units), FormatLen(AHi, FD.Units)])
    else
      FCmdMsg := Format('Cut %s to %s - %d thing%s outside it.',
        [FormatLen(ALo, FD.Units), FormatLen(AHi, FD.Units), N,
         IfThen(N = 1, '', 's')]);
  end;
  InvalidateStatus;
  pbCmd.Invalidate;
end;

{ Move the slice by whole snap steps.  Which: 0 slides the whole slice and
  keeps its thickness, 1 is the bottom on its own, 2 the top. }
procedure TMainForm.NudgeSlice(Steps: Integer; Which: Integer);
var
  D, Lo, Hi: Double;
begin
  if Steps = 0 then Exit;
  { The arrows step by whatever the drawing snaps to, so there is no second
    setting to find and the feel matches everything else. }
  D := SnapStep;
  if D <= 0 then D := 1 / 12;
  D := D * Steps;
  Lo := FD.SliceLo;
  Hi := FD.SliceHi;
  case Which of
    1: Lo := Lo + D;
    2: Hi := Hi + D;
  else
    begin Lo := Lo + D; Hi := Hi + D; end;
  end;
  { the bottom cannot pass the top, or the slice turns inside out under your
    hand and the numbers swap while you are still holding the wheel }
  if Which = 1 then Lo := Min(Lo, Hi);
  if Which = 2 then Hi := Max(Hi, Lo);
  SetSlice(True, Lo, Hi);
end;

{ "Plan from here" - the front door, for people who are not going to type two
  numbers.  The floor you clicked becomes the bottom of the slice and the top
  goes a story above it. }
procedure TMainForm.PlanFromFace(Face: Integer);
var
  Lo, Hi: Double;
  K: Integer;
  Poly: TP3Array;
begin
  if (Face < 0) or (Face >= FD.Doc.Live) then Exit;
  Poly := FD.Doc[Face].Poly;
  if Length(Poly) = 0 then Exit;
  Lo := Poly[0].Z;
  for K := 1 to High(Poly) do Lo := Min(Lo, Poly[K].Z);
  { Eight feet, or two and a half meters - a story.  Not the four feet a
    real cut plane uses, because this is also the drawing plane and drawing
    on a floor you can only see four feet of is worse than seeing the lot. }
  if FD.Units = usImperial then Hi := Lo + 8 else Hi := Lo + 2.5;
  if FD.View <> vkPlan then SetView(vkPlan);
  SetSlice(True, Lo, Hi,
    Format('Plan from %s, up to %s.  Ctrl+wheel travels up and down.',
      [FormatLen(Lo, FD.Units), FormatLen(Hi, FD.Units)]));
end;

function TMainForm.SliceText: string;
begin
  if not FD.SliceOn then Result := 'CUT  off'
  else Result := Format('CUT  %s - %s',
    [FormatLen(FD.SliceLo, FD.Units), FormatLen(FD.SliceHi, FD.Units)]);
end;

procedure TMainForm.SetView(V: TViewKind);
begin
  FViewPreset := -1;
  if V = FD.View then Exit;
  Trail('view ' + VIEW_NAMES[V]);
  Act('view ' + VIEW_NAMES[V]);
  FD.View := V;
  if V <> vkOrbit then FD.Plane := plXY;
  { the slice is a plan thing, so leaving or entering plan turns it on or off }
  ApplySlice;
  { the cut strip comes and goes with the view, so the top row is laid out
    again rather than repainted }
  Relayout;
  { the projection changed, so there is no turning of one into the other to
    watch }
  FitView(False);
  RebuildDeck;
  pbDeck.Invalidate;
  pbView.Invalidate;
  pbSlice.Invalidate;
  case V of
    vkPlan: FCmdMsg := 'Plan view.';
    vkIso: FCmdMsg := 'Isometric view.';
  else
    FCmdMsg := '3D view - middle-drag to orbit.';
  end;
  pbCmd.Invalidate;
end;

{ One button, not three modes.

  PLAN and ISO were built as drawing modes with rules of their own, and the
  three-way switch at the top made them look like three views of the same
  drawing.  They are not: there is one drawing and one camera, and what the
  button offers is where to park that camera - the four corners, the top,
  the four sides.  It reads the name of the view it is parked on, and the
  moment the view is orbited off it, it reads 3D.  The paper modes are still
  in the program, reached from the Create menu, for the field sketch that is
  going to be built on them. }
procedure TMainForm.pbViewPaint(Sender: TObject);
var
  W, H: Integer;
  R: TRect;
  S: string;
begin
  W := pbView.Width;
  H := pbView.Height;
  FViewSkin.SetSize(W, H);
  FViewSkin.Clear(Pix(0, 0, 0));
  FViewSkin.CopyRegion(FShell, pbView.Left, pbView.Top, 0, 0, W, H);
  FViewSkin.RoundRectV(Rect(0, 0, W, H), H / 2,
    MixPix(Theme.Panel, Pix(0, 0, 0), 0.20), MixPix(Theme.Panel, Pix(0, 0, 0), 0.42));
  FViewSkin.RoundFrame(Rect(0, 0, W, H), H / 2, 1.0,
    MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.14));
  { the name on the left, the arrow on the right; whichever is under the
    pointer lights up on its own }
  if FHotView = 0 then
    FViewSkin.RoundRect(Rect(3, 3, W - VIEW_ARROW_W, H - 3), (H - 6) / 2,
      MixPix(Theme.Panel, Pix(255, 255, 255), 0.10))
  else if FHotView = 1 then
    FViewSkin.RoundRect(Rect(W - VIEW_ARROW_W, 3, W - 3, H - 3), (H - 6) / 2,
      MixPix(Theme.Panel, Pix(255, 255, 255), 0.10));
  FViewSkin.Line(W - VIEW_ARROW_W, 6, W - VIEW_ARROW_W, H - 6, 1,
    MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.14), 1.0);
  FViewSkin.DrawTo(pbView.Canvas, 0, 0);

  S := ViewButtonName;
  UIFont(pbView.Canvas, 10, True, Theme.Text);
  pbView.Canvas.TextOut(((W - VIEW_ARROW_W) - pbView.Canvas.TextWidth(S)) div 2,
    (H - pbView.Canvas.TextHeight(S)) div 2, S);
  { the arrow: a small filled triangle }
  pbView.Canvas.Brush.Style := bsSolid;
  pbView.Canvas.Brush.Color := PixToColor(Theme.Text);
  pbView.Canvas.Pen.Color := PixToColor(Theme.Text);
  pbView.Canvas.Polygon([Point(W - VIEW_ARROW_W div 2 - 5, H div 2 - 3),
                         Point(W - VIEW_ARROW_W div 2 + 5, H div 2 - 3),
                         Point(W - VIEW_ARROW_W div 2, H div 2 + 3)]);
  pbView.Canvas.Brush.Style := bsClear;
end;

{ ---------------------------------------------------------------------- }
{ the file buttons, top left                                               }
{ ---------------------------------------------------------------------- }

{ Open, save, export, print, undo, redo - at the top left, where every
  program on either platform keeps them.

  They were in the bottom right corner among twelve identical squares, which
  is nowhere: the corner furthest from where anybody looks for them, in a
  cluster where Save and Units and Origin were the same size and the same
  color and told apart only by a sixteen pixel pictogram.  Putting them
  where the muscle memory already goes costs nothing and saves everybody one
  hunt per session.

  The tool hint used to be painted along this row and it has gone.  It said
  the same thing the status line at the bottom says, in smaller dimmer type,
  and it was the only place a hover was ever reported - which is why the
  program appeared to have no tooltips.  It has them now, beside what you are
  hovering; see PaintChromeTip. }
const
  QUICK_ACTS: array[0..5] of Integer =
    (ACT_OPEN, ACT_SAVE, ACT_EXPORT, ACT_PRINT, ACT_UNDO, ACT_REDO);
  QUICK_ICONS: array[0..5] of TIconKind =
    (ikOpen, ikSave, ikExport, ikPrint, ikUndo, ikRedo);
  QUICK_TIPS: array[0..5] of string = (
    'Open a drawing.  Ctrl+O',
    'Save this drawing.  Ctrl+S, or Shift+Ctrl+S to save it as something else',
    'Export a picture or a drawing file - PNG, SVG, DXF or STL.  Ctrl+E',
    'Print.  Ctrl+P, and /print full lays it out 1:1 across sheets',
    'Undo.  Ctrl+Z',
    'Redo.  Ctrl+Y');
  { a gap before undo and redo: they act on the drawing, the other four act
    on the file, and one space says so without a label }
  QUICK_GAP_BEFORE = 4;
  QUICK_NAMES: array[0..5] of string =
    ('OPEN', 'SAVE', 'EXPORT', 'PRINT', 'UNDO', 'REDO');

function TMainForm.QuickWidth: Integer;
begin
  if FMode <> mdPro then Exit(0);
  Result := Length(QUICK_ACTS) * Round(74 * FUIScale) +
            Round(12 * FUIScale);
end;

procedure TMainForm.RebuildQuick;
var
  I, BW, X, H: Integer;
begin
  SetLength(FQuick, 0);
  if FMode <> mdPro then Exit;
  BW := Round(74 * FUIScale);
  H := pbQuick.Height;
  X := 0;
  for I := 0 to High(QUICK_ACTS) do
  begin
    if I = QUICK_GAP_BEFORE then Inc(X, Round(12 * FUIScale));
    SetLength(FQuick, Length(FQuick) + 1);
    with FQuick[High(FQuick)] do
    begin
      Kind := dkSegment;
      Bounds := Rect(X + 1, 1, X + BW - 1, H - 1);
      Group := GRP_ICON;
      Value := QUICK_ACTS[I];
      Caption := QUICK_NAMES[I];
      Hint := QUICK_TIPS[I];
      Icon := QUICK_ICONS[I];
      Swatch := Pix(0, 0, 0);
    end;
    Inc(X, BW);
  end;
end;

function TMainForm.QuickHit(X, Y: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FQuick) do
    if PtInRect(FQuick[I].Bounds, Point(X, Y)) then Exit(I);
  Result := -1;
end;

procedure TMainForm.pbQuickPaint(Sender: TObject);
var
  I, W, H, IconSz: Integer;
  R, IR: TRect;
  Fg: TPix;
  Ena: Boolean;
begin
  W := pbQuick.Width;
  H := pbQuick.Height;
  if (W < 8) or (H < 8) then Exit;
  FQuickSkin.SetSize(W, H);
  FQuickSkin.Clear(Pix(0, 0, 0));
  FQuickSkin.CopyRegion(FShell, pbQuick.Left, pbQuick.Top, 0, 0, W, H);

  IconSz := Round(15 * FUIScale);
  for I := 0 to High(FQuick) do
  begin
    R := FQuick[I].Bounds;
    { grayed out when it would do nothing, so the row reports the state of
      the drawing as well as offering to change it }
    Ena := True;
    if FQuick[I].Value = ACT_UNDO then Ena := FD.UndoTop > 0
    else if FQuick[I].Value = ACT_REDO then Ena := FD.RedoTop > 0;
    if I = FHotQuick then
    begin
      FQuickSkin.RoundRect(R, Round(4 * FUIScale),
        MixPix(Theme.Panel, Pix(255, 255, 255), 0.16));
      FQuickSkin.RoundFrame(R, Round(4 * FUIScale), 1.0,
        MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.16));
    end;
    if Ena then Fg := Theme.Text
    else Fg := MixPix(Theme.TextDim, Theme.Shell1, 0.55);
    IR := Rect(R.Left + Round(6 * FUIScale),
               (R.Top + R.Bottom - IconSz) div 2,
               R.Left + Round(6 * FUIScale) + IconSz,
               (R.Top + R.Bottom + IconSz) div 2);
    PaintIcon(FQuickSkin, FQuick[I].Icon, IR, Fg);
  end;
  FQuickSkin.DrawTo(pbQuick.Canvas, 0, 0);

  { the word beside the picture.  A picture of a floppy disk means "save" to
    somebody who has seen a floppy disk. }
  for I := 0 to High(FQuick) do
  begin
    R := FQuick[I].Bounds;
    Ena := True;
    if FQuick[I].Value = ACT_UNDO then Ena := FD.UndoTop > 0
    else if FQuick[I].Value = ACT_REDO then Ena := FD.RedoTop > 0;
    if Ena then UIFont(pbQuick.Canvas, 9, False, Theme.Text)
    else UIFont(pbQuick.Canvas, 9, False,
                MixPix(Theme.TextDim, Theme.Shell1, 0.55));
    pbQuick.Canvas.TextOut(R.Left + Round(8 * FUIScale) + IconSz,
      (R.Top + R.Bottom - pbQuick.Canvas.TextHeight('X')) div 2,
      FQuick[I].Caption);
  end;
end;

procedure TMainForm.pbQuickMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
  H: Integer;
begin
  H := QuickHit(X, Y);
  if H <> FHotQuick then
  begin
    FHotQuick := H;
    pbQuick.Invalidate;
  end;
  if (H >= 0) and (H <= High(FQuick)) then
  begin
    FChromeTip := QUICK_NAMES[H];
    FChromeTipBody := FQuick[H].Hint;
    FChromeTipX := EnsureRange(pbQuick.Left + FQuick[H].Bounds.Left -
                     pbScreen.Left, 4, Max(4, pbScreen.Width - 40));
    FChromeTipY := Round(24 * FUIScale);
    FHint := FQuick[H].Hint;
  end
  else
  begin
    FChromeTip := '';
    FChromeTipBody := '';
    FHint := '';
  end;
  pbScreen.Invalidate;
end;

procedure TMainForm.pbQuickMouseLeave(Sender: TObject);
begin
  if FHotQuick <> -1 then
  begin
    FHotQuick := -1;
    pbQuick.Invalidate;
  end;
  FChromeTip := '';
  FChromeTipBody := '';
  FHint := '';
  pbScreen.Invalidate;
end;

procedure TMainForm.pbQuickMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  H: Integer;
begin
  if Button <> mbLeft then Exit;
  H := QuickHit(X, Y);
  if (H < 0) or (H > High(FQuick)) then Exit;
  DoAction(FQuick[H].Value);
  pbQuick.Invalidate;
end;

{ ---------------------------------------------------------------------- }
{ the tool strip down the left                                             }
{ ---------------------------------------------------------------------- }

{ Tools stand in a column on the left, with their names beside them.

  Two reasons, and the first is arithmetic: screens are wide and short.  The
  same buttons lying along the bottom spent the scarce dimension to save the
  abundant one, and two rows of them was thirteen per cent of the height of
  the drawing.  Standing up, a tool strip costs width, of which there is
  plenty, and it costs more of it on a small screen than a large one - which
  is the right way round.

  The second is that a column reads as a list and a grid reads as a wall.
  Left rather than right because that is where every drawing program a
  stranger has already used keeps its tools, and not floating, not dockable,
  not movable: a palette that can be lost behind the window, dragged off the
  edge or stranded on a monitor that got unplugged is a palette that needs a
  menu item to put it back, and needing that is an admission.

  **The names are on by default and that is deliberate.**  Most programs
  default the other way and they are wrong about it: nobody can tell Offset
  from Follow Me from Drill by pictogram, so a first-timer clicks nothing at
  all.  Words first; the arrow at the bottom collapses it to icons for
  somebody who has earned that, and the choice is remembered. }
function TMainForm.ToolStripWidth: Integer;
begin
  if FMode <> mdPro then Exit(0);
  if FToolsWide then Result := Round(126 * FUIScale)
  else Result := Round(42 * FUIScale);
end;

procedure TMainForm.RebuildTools;
var
  I, K, RowH, Gap, Y, W, Brk, BrkH, Need: Integer;

  procedure Add(AKind: TDeckKind; const R: TRect; AGroup, AValue: Integer;
    const ACap, AHint: string; AIcon: TIconKind);
  begin
    SetLength(FTools, Length(FTools) + 1);
    with FTools[High(FTools)] do
    begin
      Kind := AKind; Bounds := R; Group := AGroup; Value := AValue;
      Caption := ACap; Hint := AHint; Icon := AIcon; Swatch := Pix(0, 0, 0);
    end;
  end;

begin
  SetLength(FTools, 0);
  if FMode <> mdPro then Exit;
  W := pbTools.Width;
  if W < 8 then Exit;
  { And the shop, at the very foot - worked out first, because the tools have
    to stop above it. }
  FShopTop := pbTools.Height - Round(56 * FUIScale);

  { Rows as tall as they like to be, unless the window is too short for the
    column - and then tighter, down to a floor, rather than the list running
    on underneath MORE and SHOP.  It did, at 650 tall: MORE TOOLS, SHOP and
    COLLAPSE drawn over each other, which the owner saw in the help animations.
    Everything in the column scales together, so it still reads as one list. }
  Brk := 0;
  for I := 0 to High(MAIN_TOOLS) do
    for K := 0 to High(MAIN_BREAKS) do
      if MAIN_BREAKS[K] = I + 1 then Inc(Brk);
  RowH := Round(26 * FUIScale);
  Gap := Round(3 * FUIScale);
  BrkH := Round(8 * FUIScale);
  while RowH > Round(17 * FUIScale) do
  begin
    Need := Round(6 * FUIScale) + Length(MAIN_TOOLS) * (RowH + Gap) +
      Brk * BrkH + Round(4 * FUIScale) + RowH + Round(4 * FUIScale);
    if Need <= FShopTop then Break;
    Dec(RowH);
    if Gap > 1 then Dec(Gap);
    if BrkH > Round(4 * FUIScale) then Dec(BrkH);
  end;
  Y := Round(6 * FUIScale);

  SetLength(FToolRules, 0);
  for I := 0 to High(MAIN_TOOLS) do
  begin
    Add(dkSegment, Rect(Round(4 * FUIScale), Y, W - Round(4 * FUIScale), Y + RowH),
      GRP_TOOL, Ord(MAIN_TOOLS[I]), TOOL_NAMES[MAIN_TOOLS[I]],
      TOOL_HINTS[MAIN_TOOLS[I]], TOOL_ICONS[MAIN_TOOLS[I]]);
    Inc(Y, RowH + Gap);
    for K := 0 to High(MAIN_BREAKS) do
      if MAIN_BREAKS[K] = I + 1 then
      begin
        SetLength(FToolRules, Length(FToolRules) + 1);
        FToolRules[High(FToolRules)] := Y + BrkH div 2 - Round(1 * FUIScale);
        Inc(Y, BrkH);
        Break;
      end;
  end;

  { MORE, straight after the tools and looking like one, because that is what
    is behind it. }
  Inc(Y, Round(4 * FUIScale));
  Add(dkSegment, Rect(Round(4 * FUIScale), Y, W - Round(4 * FUIScale), Y + RowH),
    GRP_POPUP, POP_MORE, 'MORE TOOLS',
    'Rotate, offset and drill.', ikChevron);

  { And the shop, at the very foot, off on its own with a spanner on it.
    It is not a drawing tool and it never was - it is a door into the trade
    wizards, and standing it next to MORE with the same arrow on it made two
    quite different doors look like one thing in two halves. }
  Add(dkSegment, Rect(Round(4 * FUIScale), FShopTop,
    W - Round(4 * FUIScale), FShopTop + Round(26 * FUIScale)),
    GRP_POPUP, POP_SHOP, 'SHOP',
    'Sheet metal and pipe: laying a piece out flat, duct fittings, spools.',
    ikShop);
end;

function TMainForm.ToolsHit(X, Y: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FTools) do
    if PtInRect(FTools[I].Bounds, Point(X, Y)) then Exit(I);
  { the bottom strip is the collapse arrow }
  if Y > pbTools.Height - Round(26 * FUIScale) then Exit(-2);
  Result := -1;
end;

function TMainForm.InfoPanelWidth: Integer;
begin
  if (FMode <> mdPro) or not FInfoOn then Exit(0);
  Result := Round(212 * FUIScale);
end;

{ What the panel says about what is picked.

  Built fresh whenever the selection or the drawing changes, into a list the
  painter reads and the mouse searches.  Keeping the two apart is what stops
  a stepper drifting away from the row it belongs to. }
procedure TMainForm.RebuildInfo;
var
  InfoMoveB: Boolean;
  I, K, NL, NA, NF, NT, ND, NG, G: Integer;
  M: TIntArrayW;
  E: TWorkEnt;
  TotL, TotA: Double;
  Lo, Hi: TP3;
  MatCol: TColor;

  procedure Head(const S: string);
  begin
    SetLength(FInfoRows, Length(FInfoRows) + 1);
    with FInfoRows[High(FInfoRows)] do
    begin
      Caption := S; Value := ''; Act := iaNone; Ent := -1; Head := True;
      Minus := Rect(0, 0, 0, 0); Plus := Minus;
    end;
  end;

  procedure Row(const C, V: string; A: TInfoAct = iaNone; AEnt: Integer = -1);
  begin
    SetLength(FInfoRows, Length(FInfoRows) + 1);
    with FInfoRows[High(FInfoRows)] do
    begin
      Caption := C; Value := V; Act := A; Ent := AEnt; Head := False;
      Minus := Rect(0, 0, 0, 0); Plus := Minus;
    end;
  end;

  function PlaneWord(P: TPlane): string;
  begin
    case P of
      plXZ: Result := 'upright, XZ';
      plYZ: Result := 'on the side, YZ';
      plFree: Result := 'on a face';
    else
      Result := 'flat, XY';
    end;
  end;

  function Place(const P: TP3): string;
  begin
    Result := FormatLen(P.X, FD.Units) + ', ' + FormatLen(P.Y, FD.Units) +
      ', ' + FormatLen(P.Z, FD.Units);
  end;

begin
  SetLength(FInfoRows, 0);
  if (FMode <> mdPro) or (FD = nil) then Exit;

  { Nothing picked is not an empty panel.  It is the one moment there is room
    to say what the sheet adds up to, which is a question somebody asks of a
    drawing often enough. }
  if Length(FSel) = 0 then
  begin
    Head('THIS SHEET');
    Row('Things', IntToStr(FD.Doc.Live));
    NL := 0; NA := 0; NF := 0; NT := 0; ND := 0; NG := 0;
    TotL := 0;
    TotA := 0;
    for I := 0 to FD.Doc.Live - 1 do
      case FD.Doc[I].Kind of
        ekLine: if FD.Doc[I].Dim then Inc(ND) else
                begin Inc(NL); TotL := TotL + Dist(FD.Doc[I].A, FD.Doc[I].B); end;
        ekArc: Inc(NA);
        ekFace: begin Inc(NF); TotA := TotA + FD.Doc.FaceArea(I); end;
        ekText: Inc(NT);
        ekDim: Inc(ND);
        ekGuide: Inc(NG);
      end;
    if NL > 0 then Row('Lines', IntToStr(NL) + '   ' + FormatLen(TotL, FD.Units));
    if NA > 0 then Row('Arcs', IntToStr(NA));
    if NF > 0 then Row('Faces', IntToStr(NF) + '   ' + FormatArea(TotA, FD.Units));
    if ND > 0 then Row('Dimensions', IntToStr(ND));
    if NT > 0 then Row('Notes', IntToStr(NT));
    if NG > 0 then Row('Guides', IntToStr(NG));
    Head('');
    Row('Pick something', 'to see and change it');
    Exit;
  end;

  { A group picked: its name, what it holds, and what can be done to it.
    Before the count of things, because its members are all in the
    selection and would otherwise read as forty lines and six faces. }
  G := SoleGroup;
  if G > 0 then
  begin
    Head('GROUP');
    Row('Name', FD.Doc.PartName(G), iaPartRename, G);
    M := FD.Doc.PartMembers(G, False);
    Row('Holds', Format('%d thing%s', [Length(M), IfThen(Length(M) = 1, '', 's')]));
    if FD.Doc.PartParent(G) <> 0 then
      Row('Inside', FD.Doc.PartName(FD.Doc.PartParent(G)));
    { what it measures, groups inside it and all: its lines end to end,
      reference lines too - a radiant loop is all reference line, and its
      run from port to port is the number wanted - and the box it sits in }
    NL := 0; TotL := 0;
    for K := 0 to High(M) do
      if FD.Doc[M[K]].Kind = ekLine then
      begin
        Inc(NL); TotL := TotL + Dist(FD.Doc[M[K]].A, FD.Doc[M[K]].B);
      end;
    if NL > 0 then Row('Lines', IntToStr(NL) + '   ' + FormatLen(TotL, FD.Units));
    if FD.Doc.PartBounds(G, Lo, Hi) then
      if Abs(Hi.Z - Lo.Z) > 1E-6 then
        Row('Size', FormatLen(Hi.X - Lo.X, FD.Units) + ' x ' + FormatLen(Hi.Y - Lo.Y, FD.Units) +
          ' x ' + FormatLen(Hi.Z - Lo.Z, FD.Units))
      else
        Row('Size', FormatLen(Hi.X - Lo.X, FD.Units) + ' x ' + FormatLen(Hi.Y - Lo.Y, FD.Units));
    Head('');
    Row('Locked', IfThen(FD.Doc.PartLocked(G), 'Unlock', 'Lock'), iaPartLock, G);
    Row('Put away', 'Hide', iaPartHide, G);
    Row('Work inside it', 'Open', iaPartOpen, G);
    Row('Take it apart', 'Explode', iaPartExplode, G);
    Exit;
  end;

  { More than one: what they are between them, and nothing to edit - a
    stepper that acted on nine things at once is a way to lose nine things. }
  if Length(FSel) > 1 then
  begin
    Head(Format('%d THINGS PICKED', [Length(FSel)]));
    NL := 0; NA := 0; NF := 0; NT := 0; ND := 0; NG := 0;
    TotL := 0;
    TotA := 0;
    for K := 0 to High(FSel) do
    begin
      I := FSel[K];
      if (I < 0) or (I >= FD.Doc.Live) then Continue;
      case FD.Doc[I].Kind of
        ekLine: begin Inc(NL); TotL := TotL + Dist(FD.Doc[I].A, FD.Doc[I].B); end;
        ekArc: Inc(NA);
        ekFace: begin Inc(NF); TotA := TotA + FD.Doc.FaceArea(I); end;
        ekText: Inc(NT);
        ekDim: Inc(ND);
        ekGuide: Inc(NG);
      end;
    end;
    if NL > 0 then Row('Lines', IntToStr(NL));
    if NA > 0 then Row('Arcs', IntToStr(NA));
    if NF > 0 then Row('Faces', IntToStr(NF));
    if ND > 0 then Row('Dimensions', IntToStr(ND));
    if NT > 0 then Row('Notes', IntToStr(NT));
    if NG > 0 then Row('Guides', IntToStr(NG));
    if TotL > 0 then Row('Total length', FormatLen(TotL, FD.Units));
    if TotA > 0 then Row('Total area', FormatArea(TotA, FD.Units));
    { Changing all of them at once.  The rule the panel had - nothing to
      edit with several picked, because a stepper that moved nine things at
      once is a way to lose nine things - holds for steppers and not for a
      color: a color is one decision, it says on the button how many it
      lands on, and undo puts it back.  SketchUp paints a whole selection
      this way too. }
    if (NF > 0) or (NL + NA + NT + ND > 0) then Head('');
    if NF > 0 then
    begin
      Row('Material', Format('Paint %d face%s...',
        [NF, specialize IfThen<string>(NF = 1, '', 's')]), iaMaterial, -1);
      Row('', 'Back to default', iaUnpaint, -1);
    end;
    if NL + NA + NT + ND > 0 then
      Row('Color', Format('Change %d...', [NL + NA + NT + ND]), iaColor, -1);
    if NF > 0 then
    begin
      Head('');
      Row('Turn them over', 'Reverse', iaReverse, -1);
    end;
    Exit;
  end;

  I := FSel[0];
  if (I < 0) or (I >= FD.Doc.Live) then Exit;
  E := FD.Doc[I];

  case E.Kind of
    ekLine:
      begin
        Head(IfThen(E.Dim, 'DIMENSION', 'LINE'));
        Row('Length', FormatLen(Dist(E.A, E.B), FD.Units));
        { SketchUp grays the field when both ends are joined; this says it
          in words, and says how to change it when it can be }
        if not E.Dim then
          if FD.Doc.LineLengthEnd(I, InfoMoveB) then
            Row('', 'type a length, Enter')
          else
            Row('', 'joined at both ends - fixed');
        Row('From', Place(E.A));
        Row('To', Place(E.B));
        Row('Width', Format('%d px', [Round(Max(1, E.Weight))]), iaWidth, I);
        Row('Color', 'Change...', iaColor, I);
        Row('Crease', IfThen(E.Soft, 'Bring back', 'Soften'), iaSoft, I);
        if E.Grp <> 0 then Row('Part of', Format('solid %d', [E.Grp]))
        else Row('Part of', 'nothing - a loose edge');
      end;
    ekArc:
      begin
        if Abs(Abs(E.Sweep) - 2 * Pi) < 1E-9 then Head('CIRCLE') else Head('ARC');
        Row('Radius', FormatLen(E.R, FD.Units));
        Row('Center', Place(E.C));
        if Abs(Abs(E.Sweep) - 2 * Pi) > 1E-9 then
          Row('Sweep', FormatAngle(RadToDeg(Abs(E.Sweep))));
        { The one What was asked for was outright: get into a circle and change how
          many sides it is drawn with, after it has been drawn. }
        Row('Sides', IntToStr(ArcSteps(E)), iaSides, I);
        Row('Plane', PlaneWord(E.Plane));
        Row('Width', Format('%d px', [Round(Max(1, E.Weight))]), iaWidth, I);
        Row('Color', 'Change...', iaColor, I);
        Row('Crease', IfThen(E.Soft, 'Bring back', 'Soften'), iaSoft, I);
      end;
    ekFace:
      begin
        Head('FACE');
        Row('Area', FormatArea(FD.Doc.FaceArea(I), FD.Units));
        Row('Corners', IntToStr(Length(E.Poly)));
        if Length(E.Holes) > 0 then
          Row('Windows', IntToStr(Length(E.Holes)));
        if E.Solid then Row('Part of', Format('solid %d', [E.Grp]))
        else Row('Part of', 'nothing - a loose face');
        { A face is painted, not inked.  The material is its own thing and
          the row says which it has: the near-white everything starts as,
          or the color somebody chose. }
        if FD.Doc.Material(I, MatCol) then
        begin
          Row('Material', 'Change...', iaMaterial, I);
          Row('', 'Back to default', iaUnpaint, I);
        end
        else
          Row('Material', 'Paint...', iaMaterial, I);
        Head('');
        Row('Turn it over', 'Reverse', iaReverse, I);
      end;
    ekText:
      begin
        Head('NOTE');
        Row('Says', E.Txt);
        Row('At', Place(E.A));
        Row('Size', Format('%d%%', [Round(FD.Doc.NoteSize(I) * 100)]),
          iaNoteSize, I);
        Row('Color', 'Change...', iaColor, I);
      end;
    ekDim:
      begin
        Head('DIMENSION');
        Row('Measures', FormatLen(Dist(E.A, E.B), FD.Units));
        if E.Txt <> '' then Row('Written', E.Txt);
        Row('From', Place(E.A));
        Row('To', Place(E.B));
        Row('Color', 'Change...', iaColor, I);
      end;
    ekGuide:
      begin
        if Dist(E.A, E.B) < 1E-9 then
        begin
          Head('GUIDE POINT');
          Row('At', Place(E.A));
        end
        else
        begin
          Head('GUIDE LINE');
          Row('Through', Place(E.A));
        end;
        Head('');
        Row('Delete takes it', 'or /guides for all');
      end;
  else
    Head('SOMETHING');
  end;
end;

procedure TMainForm.pbInfoPaint(Sender: TObject);
var
  I, W, H, Y, RowH, Pad, StepW, VX: Integer;
  C: TCanvas;
  R: TRect;
  S: string;
  SwatchCol: TColor;
begin
  W := pbInfo.Width;
  H := pbInfo.Height;
  if (W < 8) or (H < 8) then Exit;
  FInfoSkin.SetSize(W, H);
  PaintPanel(FInfoSkin, Rect(0, 0, W, H), Theme, FUIScale);
  FInfoSkin.DrawTo(pbInfo.Canvas, 0, 0);

  C := pbInfo.Canvas;
  Pad := Round(10 * FUIScale);
  RowH := Round(19 * FUIScale);
  StepW := Round(18 * FUIScale);
  Y := Pad;

  for I := 0 to High(FInfoRows) do
  begin
    if Y > H - RowH then Break;
    if FInfoRows[I].Head then
    begin
      { a rule and a small heading, the way the settings row separates }
      if Y > Pad then Inc(Y, Round(6 * FUIScale));
      if FInfoRows[I].Caption <> '' then
      begin
        UIFont(C, 8, True, Theme.Accent);
        C.TextOut(Pad, Y, FInfoRows[I].Caption);
        Inc(Y, RowH);
      end;
      C.Pen.Color := PixToColor(MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.14));
      C.Pen.Width := 1;
      C.MoveTo(Pad, Y - Round(3 * FUIScale));
      C.LineTo(W - Pad, Y - Round(3 * FUIScale));
      Inc(Y, Round(4 * FUIScale));
      Continue;
    end;

    R := Rect(Pad, Y, W - Pad, Y + RowH);
    UIFont(C, 9, False, Theme.TextDim);
    C.TextOut(R.Left, Y + (RowH - C.TextHeight('X')) div 2,
      FInfoRows[I].Caption);

    VX := R.Left + Round(84 * FUIScale);
    if FInfoRows[I].Act in [iaSides, iaNoteSize, iaWidth] then
    begin
      { a number: two steppers hard against the right edge, and the figure to
        their left so it does not move as it changes width }
      FInfoRows[I].Plus := Rect(W - Pad - StepW, Y + Round(2 * FUIScale),
        W - Pad, Y + RowH - Round(2 * FUIScale));
      FInfoRows[I].Minus := Rect(FInfoRows[I].Plus.Left - StepW - Round(3 * FUIScale),
        FInfoRows[I].Plus.Top, FInfoRows[I].Plus.Left - Round(3 * FUIScale),
        FInfoRows[I].Plus.Bottom);
      PaintInfoStep(C, FInfoRows[I].Minus, '-', FInfoHot = I * 2);
      PaintInfoStep(C, FInfoRows[I].Plus, '+', FInfoHot = I * 2 + 1);
      UIFont(C, 9, True, Theme.Text);
      S := FInfoRows[I].Value;
      C.TextOut(FInfoRows[I].Minus.Left - Round(8 * FUIScale) - C.TextWidth(S),
        Y + (RowH - C.TextHeight('X')) div 2, S);
    end
    else if FInfoRows[I].Act <> iaNone then
    begin
      { a yes-or-no, or a do-it: one button with the word for what pressing
        it does.  Two steppers for "Softened: no" reads as a number you can
        turn down, which is not what it is. }
      S := FInfoRows[I].Value;
      UIFont(C, 9, True, Theme.Text);
      FInfoRows[I].Plus := Rect(W - Pad - C.TextWidth(S) - Round(14 * FUIScale),
        Y + Round(2 * FUIScale), W - Pad, Y + RowH - Round(2 * FUIScale));
      FInfoRows[I].Minus := Rect(0, 0, 0, 0);
      PaintInfoStep(C, FInfoRows[I].Plus, S, FInfoHot = I * 2 + 1);
      { the color it has now, as a swatch where the value would go }
      if (FInfoRows[I].Act in [iaColor, iaMaterial]) and
         (FInfoRows[I].Ent >= 0) and (FInfoRows[I].Ent < FD.Doc.Live) then
      begin
        C.Brush.Style := bsSolid;
        if FInfoRows[I].Act = iaMaterial then
        begin
          if not FD.Doc.Material(FInfoRows[I].Ent, SwatchCol) then
            SwatchCol := PixToColor(Pix($FA, $FA, $F6));
          C.Brush.Color := SwatchCol;
        end
        else
          C.Brush.Color := FD.Doc[FInfoRows[I].Ent].Ink;
        C.Pen.Color := PixToColor(MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.35));
        C.Pen.Width := 1;
        C.Rectangle(VX, Y + Round(3 * FUIScale),
          Min(VX + Round(36 * FUIScale), FInfoRows[I].Plus.Left - Round(6 * FUIScale)),
          Y + RowH - Round(3 * FUIScale));
        C.Brush.Style := bsClear;
      end;
    end
    else
    begin
      UIFont(C, 9, False, Theme.Text);
      S := FInfoRows[I].Value;
      { a long note is cut rather than allowed to run off the panel }
      while (S <> '') and (VX + C.TextWidth(S) > W - Pad) do
        S := Copy(S, 1, Length(S) - 1);
      if S <> FInfoRows[I].Value then S := Copy(S, 1, Max(0, Length(S) - 1)) + '...';
      C.TextOut(VX, Y + (RowH - C.TextHeight('X')) div 2, S);
    end;
    Inc(Y, RowH);
  end;

  { A list opened from the right of the deck stands over the panel as well
    as over the drawing, so the part that lands here is painted here.  The
    list is held in the drawing's coordinates - it is the drawing's list -
    and this moves it into the panel's. }
  if FPopup <> POP_NONE then
    PaintPopup(C, pbScreen.Left - pbInfo.Left, pbScreen.Top - pbInfo.Top);
end;

{ One of the little square buttons beside a figure that can be changed. }
procedure TMainForm.PaintInfoStep(C: TCanvas; const R: TRect;
  const S: string; Hot: Boolean);
var
  Bg: TPix;
begin
  if Hot then Bg := MixPix(Theme.PanelHi, Theme.Accent, 0.45)
  else Bg := MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.10);
  C.Brush.Style := bsSolid;
  C.Brush.Color := PixToColor(Bg);
  C.Pen.Color := PixToColor(MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.25));
  C.Pen.Width := 1;
  C.Rectangle(R);
  C.Brush.Style := bsClear;
  UIFont(C, 10, True, Theme.Text);
  C.TextOut((R.Left + R.Right - C.TextWidth(S)) div 2,
            (R.Top + R.Bottom - C.TextHeight(S)) div 2, S);
end;

{ Which stepper is under the cursor, as row*2 for minus and row*2+1 for plus,
  or -1.  The rectangles were worked out by the painter, which is why this
  only has to look them up. }
function TMainForm.InfoHit(X, Y: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FInfoRows) do
    if FInfoRows[I].Act <> iaNone then
    begin
      if PtInRect(FInfoRows[I].Minus, Point(X, Y)) then Exit(I * 2);
      if PtInRect(FInfoRows[I].Plus, Point(X, Y)) then Exit(I * 2 + 1);
    end;
end;

procedure TMainForm.pbInfoMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
  H: Integer;
begin
  { a list standing over the panel is still the list: the row under the
    pointer lights up here the same as it does over the drawing }
  if FPopup <> POP_NONE then
  begin
    H := PopupItemAt(X + pbInfo.Left - pbScreen.Left,
                     Y + pbInfo.Top - pbScreen.Top);
    if (H < 0) and (FPopup = POP_CMDS) then H := FPopupHot;
    if H <> FPopupHot then
    begin
      FPopupHot := H;
      FScreenDirty := True;
      pbScreen.Invalidate;
      pbInfo.Invalidate;
    end;
    Exit;
  end;
  H := InfoHit(X, Y);
  if H <> FInfoHot then
  begin
    FInfoHot := H;
    pbInfo.Invalidate;
  end;
end;

procedure TMainForm.pbInfoMouseLeave(Sender: TObject);
begin
  if FInfoHot >= 0 then
  begin
    FInfoHot := -1;
    pbInfo.Invalidate;
  end;
end;

procedure TMainForm.pbInfoMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  H, Row, N, K, Which: Integer;
  Up: Boolean;
  Picked: TColor;
begin
  { and a press on it picks a row, rather than reaching the panel
    underneath - the same rule the drawing follows }
  if FPopup <> POP_NONE then
  begin
    Which := FPopup;
    H := -1;
    if Button = mbLeft then
      H := PopupItemAt(X + pbInfo.Left - pbScreen.Left,
                       Y + pbInfo.Top - pbScreen.Top);
    ClosePopup;
    if H >= 0 then PopupChoose(Which, H);
    Exit;
  end;
  if Button <> mbLeft then Exit;
  H := InfoHit(X, Y);
  if H < 0 then Exit;
  Row := H div 2;
  Up := Odd(H);

  case FInfoRows[Row].Act of
    iaSides:
      begin
        if (FInfoRows[Row].Ent < 0) or (FInfoRows[Row].Ent >= FD.Doc.Live) then Exit;
        N := ArcSteps(FD.Doc[FInfoRows[Row].Ent]);
        { the same steps the + and - keys take while the tool is in hand, and
          the same limits }
        if Up then N := Min(360, N + 1) else N := Max(3, N - 1);
        PushUndo;
        FD.Doc.SetArcSides(FInfoRows[Row].Ent, N);
        RebuildFlatFaces;
        FCmdMsg := Format('%d sides.', [N]);
      end;
    iaSoft:
      begin
        if (FInfoRows[Row].Ent < 0) or (FInfoRows[Row].Ent >= FD.Doc.Live) then Exit;
        PushUndo;
        N := Ord(not FD.Doc[FInfoRows[Row].Ent].Soft);
        FD.Doc.SetSoft(FInfoRows[Row].Ent, N <> 0);
        FCmdMsg := specialize IfThen<string>(N <> 0, 'Edge softened.',
          'Edge brought back.');
      end;
    iaNoteSize:
      begin
        if (FInfoRows[Row].Ent < 0) or (FInfoRows[Row].Ent >= FD.Doc.Live) then Exit;
        PushUndo;
        if Up then
          FD.Doc.SetNoteSize(FInfoRows[Row].Ent,
            FD.Doc.NoteSize(FInfoRows[Row].Ent) * 1.25)
        else
          FD.Doc.SetNoteSize(FInfoRows[Row].Ent,
            FD.Doc.NoteSize(FInfoRows[Row].Ent) / 1.25);
        FCmdMsg := Format('Text at %d%% of normal.',
          [Round(FD.Doc.NoteSize(FInfoRows[Row].Ent) * 100)]);
      end;
    iaWidth:
      begin
        if (FInfoRows[Row].Ent < 0) or (FInfoRows[Row].Ent >= FD.Doc.Live) then Exit;
        { through the same widths the LINE WIDTH list offers }
        N := Round(Max(1, FD.Doc[FInfoRows[Row].Ent].Weight));
        K := 0;
        while (K < High(PEN_SIZES)) and (PEN_SIZES[K] < N) do Inc(K);
        if Up then
        begin
          if PEN_SIZES[K] <= N then K := Min(High(PEN_SIZES), K + 1);
        end
        else if K > 0 then
          Dec(K);
        PushUndo;
        FD.Doc.SetWeight(FInfoRows[Row].Ent, PEN_SIZES[K]);
        FCmdMsg := Format('%d px.', [PEN_SIZES[K]]);
      end;
    iaColor:
      begin
        { with several picked the row is for all of them, and there is no one
          color to start the dialog from - so it opens on the current pen }
        if FInfoRows[Row].Ent < 0 then
        begin
          if not AskColor(FInkColor, Picked) then Exit;
          PushUndo;
          K := InkSelectedThings(Picked);
          FCmdMsg := Format('%d thing%s recolored.',
            [K, specialize IfThen<string>(K = 1, '', 's')]);
          RenderPro;
          RecomposeAll;
          RebuildInfo;
          pbInfo.Invalidate;
          pbScreen.Invalidate;
          pbCmd.Invalidate;
          Exit;
        end;
        if FInfoRows[Row].Ent >= FD.Doc.Live then Exit;
        if not AskColor(FD.Doc[FInfoRows[Row].Ent].Ink, Picked) then Exit;
        PushUndo;
        FD.Doc.SetInk(FInfoRows[Row].Ent, Picked);
        FCmdMsg := 'Color changed.  The LINE COLOR button still sets what you draw next.';
      end;
    iaMaterial:
      begin
        if FInfoRows[Row].Ent >= FD.Doc.Live then Exit;
        { the color it has now to start from, or the default it looks like.
          With several picked there is no one material, so it opens on the
          default. }
        if (FInfoRows[Row].Ent < 0) or
           not FD.Doc.Material(FInfoRows[Row].Ent, Picked) then
          Picked := PixToColor(Pix($FA, $FA, $F6));
        if not AskColor(Picked, Picked) then Exit;
        PushUndo;
        K := PaintSelectedFaces(FInfoRows[Row].Ent, Picked, True);
        if K > 1 then
          FCmdMsg := Format('%d faces painted.', [K])
        else
          FCmdMsg := 'Face painted.  The LINE COLOR button still sets what you draw next.';
      end;
    iaUnpaint:
      begin
        if FInfoRows[Row].Ent >= FD.Doc.Live then Exit;
        PushUndo;
        K := PaintSelectedFaces(FInfoRows[Row].Ent, clNone, False);
        if K > 1 then
          FCmdMsg := Format('%d faces back to the default material.', [K])
        else
          FCmdMsg := 'Back to the default material.';
      end;
    { the group rows carry the group's id in Ent, not an entity }
    iaPartOpen: OpenGroup(FInfoRows[Row].Ent);
    iaPartLock:
      begin
        PushUndo;
        FD.Doc.SetPartLocked(FInfoRows[Row].Ent, not FD.Doc.PartLocked(FInfoRows[Row].Ent));
        if FD.Doc.PartLocked(FInfoRows[Row].Ent) then FCmdMsg := 'Locked.' else FCmdMsg := 'Unlocked.';
      end;
    iaPartExplode: ExplodeGroups;
    iaPartHide: HideGroups(True, '');
    iaPartRename:
      begin
        { the command bar, with the name ready to be typed over }
        FInput := '/name ' + FD.Doc.PartName(FInfoRows[Row].Ent);
        SyncCmdList;
        FCmdMsg := 'Type the name and press Enter.';
      end;
    iaReverse:
      begin
        PushUndo;
        K := ReverseSelectedFaces;
        FCmdMsg := Format('%d face%s turned over.',
          [K, specialize IfThen<string>(K = 1, '', 's')]);
      end;
  else
    Exit;
  end;

  RenderPro;
  RecomposeAll;
  RebuildInfo;
  pbInfo.Invalidate;
  pbScreen.Invalidate;
  pbCmd.Invalidate;
end;

procedure TMainForm.pbToolsPaint(Sender: TObject);
var
  I, W, H, IconSz, TxtX, ArrY: Integer;
  It: TDeckItem;
  Sel, Hot: Boolean;
  C1, C2, Edge, Fg: TPix;
  R, IR: TRect;
  S: string;
begin
  W := pbTools.Width;
  H := pbTools.Height;
  if (W < 8) or (H < 8) then Exit;
  FToolSkin.SetSize(W, H);
  PaintPanel(FToolSkin, Rect(0, 0, W, H), Theme, FUIScale);

  IconSz := Round(16 * FUIScale);
  for I := 0 to High(FTools) do
  begin
    It := FTools[I];
    R := It.Bounds;
    Sel := (It.Group = GRP_TOOL) and (It.Value = Ord(FTool));
    Hot := I = FHotTool;
    if Sel then
    begin
      C1 := Theme.Accent;
      C2 := ShadePix(Theme.Accent, 0.86);
      Fg := Pix(12, 16, 22);
      Edge := ShadePix(Theme.Accent, 1.18);
    end
    else
    begin
      C1 := MixPix(Theme.Panel, Pix(255, 255, 255), IfThen(Hot, 0.14, 0.05) / 1.0);
      C2 := MixPix(Theme.Panel, Pix(0, 0, 0), 0.16);
      Fg := Theme.Text;
      Edge := MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.10);
    end;
    FToolSkin.RoundRectV(R, Round(4 * FUIScale), C1, C2);
    FToolSkin.RoundFrame(R, Round(4 * FUIScale), 1.0, Edge);
    IR := Rect(R.Left + Round(6 * FUIScale),
               (R.Top + R.Bottom - IconSz) div 2,
               R.Left + Round(6 * FUIScale) + IconSz,
               (R.Top + R.Bottom + IconSz) div 2);
    PaintIcon(FToolSkin, It.Icon, IR, Fg);
  end;

  { the lines between the groups }
  for I := 0 to High(FToolRules) do
    FToolSkin.Line(Round(10 * FUIScale), FToolRules[I],
      W - Round(10 * FUIScale), FToolRules[I], 1,
      MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.16), 1.0);

  { the collapse arrow, at the foot }
  ArrY := H - Round(20 * FUIScale);
  FToolSkin.Line(Round(8 * FUIScale), ArrY - Round(8 * FUIScale),
    W - Round(8 * FUIScale), ArrY - Round(8 * FUIScale), 1,
    MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.10), 1.0);
  FToolSkin.DrawTo(pbTools.Canvas, 0, 0);

  if FToolsWide then
  begin
    TxtX := Round(6 * FUIScale) + IconSz + Round(7 * FUIScale);
    for I := 0 to High(FTools) do
    begin
      It := FTools[I];
      R := It.Bounds;
      if (It.Group = GRP_TOOL) and (It.Value = Ord(FTool)) then
        UIFont(pbTools.Canvas, 9, True, Pix(12, 16, 22))
      else if It.Group = GRP_POPUP then
        UIFont(pbTools.Canvas, 9, True, Theme.TextDim)
      else
        UIFont(pbTools.Canvas, 9, False, Theme.Text);
      S := It.Caption;
      if It.Group = GRP_POPUP then S := S + '  >';
      pbTools.Canvas.TextOut(R.Left + TxtX,
        (R.Top + R.Bottom - pbTools.Canvas.TextHeight(S)) div 2, S);
    end;
  end;

  { What it does, in the word for what it does.  It said "NAMES OFF", which
    is what it does to the names and not what it does to the strip, and
    reading it left you working out which state you were being offered. }
  UIFont(pbTools.Canvas, 9, False, Theme.TextDim);
  if FToolsWide then S := '<  COLLAPSE' else S := '>';
  pbTools.Canvas.TextOut(Round(8 * FUIScale),
    ArrY - pbTools.Canvas.TextHeight(S) div 2, S);
end;

procedure TMainForm.pbToolsMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
  H: Integer;
begin
  H := ToolsHit(X, Y);
  if H <> FHotTool then
  begin
    FHotTool := H;
    pbTools.Invalidate;
  end;
  { the note beside the button, level with it }
  FChromeTipX := Round(6 * FUIScale);
  if (H >= 0) and (H <= High(FTools)) then
  begin
    FChromeTip := FTools[H].Caption;
    FChromeTipBody := FTools[H].Hint;
    FChromeTipY := (FTools[H].Bounds.Top + FTools[H].Bounds.Bottom) div 2
                   + pbTools.Top - pbScreen.Top;
    FHint := FTools[H].Hint;
  end
  else if H = -2 then
  begin
    FChromeTip := IfThen(FToolsWide, 'COLLAPSE', 'EXPAND');
    FChromeTipBody := IfThen(FToolsWide,
      'Put the names away and give the width to the drawing.',
      'Show the tool names again.');
    FChromeTipY := pbTools.Height - Round(20 * FUIScale)
                   + pbTools.Top - pbScreen.Top;
    FHint := FChromeTipBody;
  end
  else
  begin
    FChromeTip := '';
    FChromeTipBody := '';
    FHint := '';
  end;
  pbScreen.Invalidate;
end;

procedure TMainForm.pbToolsMouseLeave(Sender: TObject);
begin
  if FHotTool <> -1 then
  begin
    FHotTool := -1;
    pbTools.Invalidate;
  end;
  FHint := '';
  FChromeTip := '';
  FChromeTipBody := '';
  pbScreen.Invalidate;
end;

procedure TMainForm.pbToolsMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  H: Integer;
begin
  if Button <> mbLeft then Exit;
  H := ToolsHit(X, Y);
  if H = -2 then
  begin
    FToolsWide := not FToolsWide;
    SaveSettings;
    Relayout;
    Exit;
  end;
  if (H < 0) or (H > High(FTools)) then
  begin
    { a click on the bare strip is still a click somewhere else, and an open
      list should not survive it }
    if FPopup <> POP_NONE then ClosePopup;
    Exit;
  end;
  if FTools[H].Group = GRP_TOOL then
  begin
    if FPopup <> POP_NONE then ClosePopup;
    SetTool(TProTool(FTools[H].Value));
  end
  else if FTools[H].Group = GRP_POPUP then
    { Clicking the open one shuts it, which is what a menu button does
      everywhere else in the program - the deck has done this all along and
      the strip was written without it, so MORE TOOLS and SHOP opened their
      lists and then would not put them away.  Reported 13 September. }
    if FPopup = FTools[H].Value then ClosePopup
    else OpenPopup(FTools[H].Value);
end;

{ ---------------------------------------------------------------------- }
{ the cut - the slice a plan view is taken out of                          }
{ ---------------------------------------------------------------------- }

{ Two length fields side by side, the bottom of the slice and the top.

  Not a spin edit with a number in it.  A drawing measured in feet and inches
  has to be told its heights in feet and inches, and the program already
  knows how: ParseLen reads anything anybody would type - 9', 9'6, 114",
  6-8-15 - and FormatLen writes it back at the drawing's own precision.  So
  the field is those two with arrows on it, and **the arrows step by whatever
  the drawing snaps to**, which means there is no second setting to find and
  it feels the same as everything else here.

  Typing goes to the command bar rather than into the box.  Every other value
  in PRO is typed there and committed with Enter, the caret and the key
  handling already exist, and a second place to type would be a second set of
  rules to learn - see EditDimUnder, which does the same for the text on a
  dimension. }
function TMainForm.SliceFieldRect(Which: Integer): TRect;
var
  LabW, Pad, FW: Integer;
begin
  Pad := Round(4 * FUIScale);
  LabW := Round(34 * FUIScale);
  FW := (pbSlice.Width - LabW - 3 * Pad) div 2;
  if Which = 1 then
    Result := Rect(LabW + Pad, 1, LabW + Pad + FW, pbSlice.Height - 1)
  else
    Result := Rect(LabW + 2 * Pad + FW, 1, LabW + 2 * Pad + 2 * FW,
                   pbSlice.Height - 1);
end;

function TMainForm.SliceZoneAt(X, Y: Integer): Integer;
var
  I, ArrW: Integer;
  R: TRect;
begin
  Result := -1;
  ArrW := Round(13 * FUIScale);
  for I := 1 to 2 do
  begin
    R := SliceFieldRect(I);
    if (X >= R.Left) and (X < R.Right) and (Y >= R.Top) and (Y < R.Bottom) then
    begin
      if X >= R.Right - ArrW then
      begin
        if Y < (R.Top + R.Bottom) div 2 then Exit(2 + I)   // 3 up-lo, 4 up-hi
        else Exit(4 + I);                                   // 5 dn-lo, 6 dn-hi
      end;
      Exit(I);
    end;
  end;
  if X < SliceFieldRect(1).Left then Result := 0;
end;

procedure TMainForm.pbSlicePaint(Sender: TObject);
var
  W, H, I, ArrW, MidY, CX: Integer;
  R: TRect;
  S: string;
  Body, Edge: TPix;
begin
  W := pbSlice.Width;
  H := pbSlice.Height;
  if (W < 8) or (H < 8) then Exit;
  FSliceSkin.SetSize(W, H);
  FSliceSkin.Clear(Pix(0, 0, 0));
  FSliceSkin.CopyRegion(FShell, pbSlice.Left, pbSlice.Top, 0, 0, W, H);
  FSliceSkin.RoundRectV(Rect(0, 0, W, H), H / 2,
    MixPix(Theme.Panel, Pix(0, 0, 0), 0.20), MixPix(Theme.Panel, Pix(0, 0, 0), 0.42));
  FSliceSkin.RoundFrame(Rect(0, 0, W, H), H / 2, 1.0,
    MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.14));

  ArrW := Round(13 * FUIScale);
  for I := 1 to 2 do
  begin
    R := SliceFieldRect(I);
    Body := MixPix(Theme.Panel, Pix(0, 0, 0), 0.45);
    { the one being typed into is lit, so it is obvious where the keys go }
    if FSliceEdit = I then Body := MixPix(Theme.Accent, Pix(0, 0, 0), 0.55)
    else if FHotSlice = I then Body := MixPix(Theme.Panel, Pix(255, 255, 255), 0.10);
    FSliceSkin.RoundRect(R, Round(3 * FUIScale), Body);
    Edge := MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.10);
    if FSliceEdit = I then Edge := Theme.Accent;
    FSliceSkin.RoundFrame(R, Round(3 * FUIScale), 1.0, Edge);
  end;
  FSliceSkin.DrawTo(pbSlice.Canvas, 0, 0);

  UIFont(pbSlice.Canvas, 9, True, Theme.TextDim);
  pbSlice.Canvas.TextOut(Round(8 * FUIScale),
    (H - pbSlice.Canvas.TextHeight('CUT')) div 2, 'CUT');

  for I := 1 to 2 do
  begin
    R := SliceFieldRect(I);
    if I = 1 then S := FormatLen(FD.SliceLo, FD.Units)
    else S := FormatLen(FD.SliceHi, FD.Units);
    if FSliceEdit = I then S := FInput + '_';
    if not FD.SliceOn then
      UIFont(pbSlice.Canvas, 9, False, Theme.TextDim)
    else
      UIFont(pbSlice.Canvas, 9, True, Theme.Text);
    pbSlice.Canvas.TextOut(R.Left + Round(6 * FUIScale),
      (H - pbSlice.Canvas.TextHeight(S)) div 2, S);

    { the two chevrons - the cue that says this is a thing you can turn }
    MidY := (R.Top + R.Bottom) div 2;
    CX := R.Right - ArrW div 2 - Round(2 * FUIScale);
    pbSlice.Canvas.Brush.Style := bsSolid;
    pbSlice.Canvas.Brush.Color := PixToColor(Theme.TextDim);
    pbSlice.Canvas.Pen.Color := PixToColor(Theme.TextDim);
    pbSlice.Canvas.Polygon([Point(CX - 4, MidY - 2), Point(CX + 4, MidY - 2),
                            Point(CX, MidY - 7)]);
    pbSlice.Canvas.Polygon([Point(CX - 4, MidY + 2), Point(CX + 4, MidY + 2),
                            Point(CX, MidY + 7)]);
    pbSlice.Canvas.Brush.Style := bsClear;
  end;
end;

procedure TMainForm.pbSliceMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
  Z: Integer;
begin
  Z := SliceZoneAt(X, Y);
  if Z <> FHotSlice then
  begin
    FHotSlice := Z;
    pbSlice.Invalidate;
  end;
  case Z of
    1: FHint := 'The bottom of the slice - and the height you draw at.  ' +
                'Click to type it, or roll the wheel.';
    2: FHint := 'The top of the slice.  Nothing above this is in the drawing.';
    0: FHint := 'The slice this plan is cut out of.  Ctrl+wheel over the ' +
                'drawing travels up and down through the model.';
  else
    FHint := 'Roll the wheel to move it.';
  end;
end;

procedure TMainForm.pbSliceMouseLeave(Sender: TObject);
begin
  if FHotSlice <> -1 then
  begin
    FHotSlice := -1;
    pbSlice.Invalidate;
  end;
end;

procedure TMainForm.pbSliceMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Z: Integer;
begin
  if Button <> mbLeft then Exit;
  Z := SliceZoneAt(X, Y);
  case Z of
    3: NudgeSlice(1, 1);
    4: NudgeSlice(1, 2);
    5: NudgeSlice(-1, 1);
    6: NudgeSlice(-1, 2);
    1, 2:
      begin
        { into the command bar, the way a dimension's text goes }
        FSliceEdit := Z;
        FInput := '';
        if Z = 1 then
          FCmdMsg := 'Type the bottom of the slice - the height you draw at.  Esc leaves it.'
        else
          FCmdMsg := 'Type the top of the slice.  Esc leaves it.';
        pbSlice.Invalidate;
        pbCmd.Invalidate;
      end;
    0:
      { the label is the switch - one click is the whole feature on or off }
      if FD.SliceOn then SetSlice(False, FD.SliceLo, FD.SliceHi)
      else SetSlice(True, FD.SliceLo, FD.SliceHi);
  end;
end;

procedure TMainForm.pbSliceMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
var
  Z, Steps: Integer;
begin
  Handled := True;
  if WheelDelta > 0 then Steps := 1 else Steps := -1;
  Z := SliceZoneAt(MousePos.X, MousePos.Y);
  case Z of
    1, 3, 5: NudgeSlice(Steps, 1);
    2, 4, 6: NudgeSlice(Steps, 2);
  else
    NudgeSlice(Steps, 0);
  end;
end;

{ Take what was typed into one of the two fields. }
procedure TMainForm.CommitSliceEdit;
var
  W: Integer;
  V: Double;
begin
  W := FSliceEdit;
  FSliceEdit := 0;
  if W = 0 then Exit;
  if Trim(FInput) = '' then
  begin
    FInput := '';
    FCmdMsg := 'Left as it was.';
    pbSlice.Invalidate;
    Exit;
  end;
  if not ParseLen(FInput, FD.Units, V) then
  begin
    FCmdMsg := 'I could not read "' + FInput + '" as a height.';
    FInput := '';
    pbSlice.Invalidate;
    Exit;
  end;
  FInput := '';
  if W = 1 then SetSlice(True, V, Max(V, FD.SliceHi))
  else SetSlice(True, Min(FD.SliceLo, V), V);
  pbSlice.Invalidate;
end;

{ The list behind the arrow: every camera preset, then the two paper modes
  below a line.  Built from the same table the button steps through, so the
  two can never disagree. }
procedure TMainForm.FillViewMenu;
var
  I: Integer;
  M: TMenuItem;
begin
  pmView.Items.Clear;

  { PLAN first, and it is back on this list.

    It was taken off on the grounds that this is a 3D model and a flat
    layout tool was a job for another day.  That day was yesterday: a plan
    is a slice through the model now, it draws like a drawing, and it is
    where the cut fields live.  Leaving it off meant the only way into the
    one genuinely new thing in the program was to know that /plan existed -
    and the owner clicked every row on this menu and never found
    it.  If the person who commissioned a feature cannot reach it with a
    mouse, nobody can.

    TOP is the trap that made it worse: it is the free camera pointed
    almost straight down, which looks like a plan and is not one - no cut,
    no drawing style, still a photograph.  So both say what they are. }
  M := TMenuItem.Create(pmView);
  M.Caption := 'PLAN - flat, with the cut';
  M.Tag := 0;
  M.OnClick := @ViewMenuClick;
  pmView.Items.Add(M);

  M := TMenuItem.Create(pmView);
  M.Caption := 'ISO - flat, on the paper axes';
  M.Tag := 1;
  M.OnClick := @ViewMenuClick;
  pmView.Items.Add(M);

  M := TMenuItem.Create(pmView);
  M.Caption := '-';
  pmView.Items.Add(M);

  for I := FIRST_CAMERA_PRESET to High(VIEW_PRESETS) do
  begin
    M := TMenuItem.Create(pmView);
    if I = High(VIEW_PRESETS) then M.Caption := 'TOP - 3D, from above'
    else M.Caption := VIEW_PRESETS[I].Name;
    M.Tag := I;
    M.OnClick := @ViewMenuClick;
    pmView.Items.Add(M);
  end;
end;

procedure TMainForm.ViewMenuClick(Sender: TObject);
begin
  ApplyViewPreset((Sender as TMenuItem).Tag);
end;

{ What the button says: the paper mode when one is on, the preset the
  camera is parked on, or 3D once it has been orbited anywhere else. }
function TMainForm.ViewButtonName: string;
begin
  if FD.View = vkPlan then Exit('PLAN PAPER');
  if FD.View = vkIso then Exit('ISO PAPER');
  if (FViewPreset >= FIRST_CAMERA_PRESET) and (FViewPreset <= High(VIEW_PRESETS)) then
    Result := 'VIEW: ' + VIEW_PRESETS[FViewPreset].Name
  else
    Result := 'VIEW: 3D';
end;

procedure TMainForm.pbViewMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  Z: Integer;
begin
  if X >= pbView.Width - VIEW_ARROW_W then Z := 1 else Z := 0;
  if FHotView <> Z then
  begin
    FHotView := Z;
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
  { the arrow opens the list; on the name, left steps forward through the
    camera presets and right steps back - from a paper mode or a free 3D
    view either goes to the first corner }
  if X >= pbView.Width - VIEW_ARROW_W then
  begin
    with pbView.ClientToScreen(Point(pbView.Width - VIEW_ARROW_W, pbView.Height)) do
      pmView.PopUp(X, Y);
    Exit;
  end;
  if Button = mbLeft then CycleViewPreset(1)
  else if Button = mbRight then CycleViewPreset(-1);
end;

{ One button, only in the toy, and it goes back to pro.  It was a pair of
  them once, TOY and PRO side by side, which made sense while the two halves
  of the program were equals; they are not, and a switch offering to put you
  where you already are is furniture. }
procedure TMainForm.pbModePaint(Sender: TObject);
var
  W, H: Integer;
  R: TRect;
  K: Single;
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

  { filled whether or not the pointer is on it, because it is the only way
    out of here and ought to look like the thing to press }
  if FHotMode = 0 then K := 1.12 else K := 1.0;
  R := Rect(3, 3, W - 3, H - 3);
  FModeSkin.RoundRectV(R, (R.Bottom - R.Top) / 2,
    ShadePix(Theme.Accent, 1.10 * K), ShadePix(Theme.Accent, 0.80 * K));
  FModeSkin.DrawTo(pbMode.Canvas, 0, 0);

  S := 'BACK TO PRO';
  UIFont(pbMode.Canvas, 11, True, OnPix(Theme.Accent));
  TrackedText(pbMode.Canvas,
    (W - (pbMode.Canvas.TextWidth(S) + 2 * Length(S))) div 2,
    (H - pbMode.Canvas.TextHeight(S)) div 2, S, 2);
end;

procedure TMainForm.pbModeMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if FHotMode <> 0 then
  begin
    FHotMode := 0;
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
  SetMode(mdPro);
end;

{ The command bar always says what it wants next, so nothing has to be
  memorised.  It also takes typed lengths and typed commands. }
{ The slash button: press it and you are typing a command, with the list up.
  Pressing it again puts the list away, the way every button that opens a
  list in this program does. }
procedure TMainForm.pbCmdMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbLeft then Exit;
  if FMode <> mdPro then Exit;
  if not PtInRect(FCmdArrow, Point(X, Y)) then Exit;
  if FPopup = POP_CMDS then
  begin
    ClosePopup;
    FInput := '';
  end
  else
  begin
    FInput := '/';
    SyncCmdList;
  end;
  pbCmd.Invalidate;
  pbScreen.Invalidate;
end;

procedure TMainForm.pbCmdMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
  Was: Boolean;
begin
  Was := FCmdArrowHot;
  FCmdArrowHot := (FMode = mdPro) and PtInRect(FCmdArrow, Point(X, Y));
  if FCmdArrowHot <> Was then pbCmd.Invalidate;
end;

procedure TMainForm.pbCmdMouseLeave(Sender: TObject);
begin
  if FCmdArrowHot then
  begin
    FCmdArrowHot := False;
    pbCmd.Invalidate;
  end;
end;

procedure TMainForm.pbCmdPaint(Sender: TObject);
var
  W, H, X, TW, I: Integer;
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

  { The way in to every typed command.  The command bar is the fastest part
    of this program to use and the slowest to find out about - everything in
    it was something you had to already know.  Pressing this types the slash
    and brings the list up, which is the same thing typing a slash does: one
    door, and a button on it for anybody who has not found the keyboard. }
  FCmdArrow := Rect(Round(16 * FUIScale), Round(5 * FUIScale),
                    Round(40 * FUIScale), H - Round(5 * FUIScale));
  pbCmd.Canvas.Brush.Style := bsSolid;
  if FCmdArrowHot or (FPopup = POP_CMDS) then
    pbCmd.Canvas.Brush.Color := PixToColor(Theme.Accent)
  else
    pbCmd.Canvas.Brush.Color := PixToColor(MixPix(Theme.Panel,
      Pix(255, 255, 255), 0.10));
  pbCmd.Canvas.Pen.Style := psClear;
  pbCmd.Canvas.RoundRect(FCmdArrow.Left, FCmdArrow.Top,
    FCmdArrow.Right, FCmdArrow.Bottom, Round(7 * FUIScale),
    Round(7 * FUIScale));
  pbCmd.Canvas.Pen.Style := psSolid;
  pbCmd.Canvas.Brush.Style := bsClear;
  if FCmdArrowHot or (FPopup = POP_CMDS) then
    UIFont(pbCmd.Canvas, 12, True, OnPix(Theme.Accent))
  else
    UIFont(pbCmd.Canvas, 12, True, Theme.TextDim);
  S := '/';
  pbCmd.Canvas.TextOut(
    (FCmdArrow.Left + FCmdArrow.Right - pbCmd.Canvas.TextWidth(S)) div 2,
    (FCmdArrow.Top + FCmdArrow.Bottom - pbCmd.Canvas.TextHeight(S)) div 2, S);

  X := Round(48 * FUIScale);
  if FBusy then
  begin
    { long work on the main thread: what it is and how far, in place of the
      prompt, so a drawing of fifty thousand things visibly gets on with it }
    UIFont(pbCmd.Canvas, 11, True, Theme.Accent);
    S := 'WORKING';
    pbCmd.Canvas.TextOut(X, (H - pbCmd.Canvas.TextHeight(S)) div 2, S);
    Inc(X, pbCmd.Canvas.TextWidth(S) + Round(14 * FUIScale));
    UIFont(pbCmd.Canvas, 11, False, Theme.Text);
    S := FBusyMsg;
    if FBusyFrac >= 0 then S := S + Format('  %d%%', [Round(EnsureRange(FBusyFrac, 0, 1) * 100)]);
    pbCmd.Canvas.TextOut(X, (H - pbCmd.Canvas.TextHeight(S)) div 2, S);
    Inc(X, pbCmd.Canvas.TextWidth(S) + Round(18 * FUIScale));
    TW := W - X - Round(24 * FUIScale);
    if TW > Round(80 * FUIScale) then
    begin
      pbCmd.Canvas.Pen.Style := psClear;
      pbCmd.Canvas.Brush.Style := bsSolid;
      pbCmd.Canvas.Brush.Color := PixToColor(Theme.Panel);
      pbCmd.Canvas.RoundRect(X, H div 2 - Round(4 * FUIScale), X + TW, H div 2 + Round(4 * FUIScale),
        Round(8 * FUIScale), Round(8 * FUIScale));
      pbCmd.Canvas.Brush.Color := PixToColor(Theme.Accent);
      if FBusyFrac >= 0 then
        pbCmd.Canvas.RoundRect(X, H div 2 - Round(4 * FUIScale),
          X + Max(Round(8 * FUIScale), Round(TW * EnsureRange(FBusyFrac, 0, 1))), H div 2 + Round(4 * FUIScale),
          Round(8 * FUIScale), Round(8 * FUIScale))
      else
      begin
        { no idea how far: a light running along the track }
        I := Round((TW - TW div 5) * (0.5 - 0.5 * Cos(((GetTickCount64 mod 1400) / 1400) * 2 * Pi)));
        pbCmd.Canvas.RoundRect(X + I, H div 2 - Round(4 * FUIScale), X + I + TW div 5, H div 2 + Round(4 * FUIScale),
          Round(8 * FUIScale), Round(8 * FUIScale));
      end;
      pbCmd.Canvas.Pen.Style := psSolid;
      pbCmd.Canvas.Brush.Style := bsClear;
    end;
    Exit;
  end;

  UIFont(pbCmd.Canvas, 11, True, Theme.Accent);
  S := ToolName(FTool);
  pbCmd.Canvas.TextOut(X, (H - pbCmd.Canvas.TextHeight(S)) div 2, S);
  Inc(X, pbCmd.Canvas.TextWidth(S) + Round(14 * FUIScale));

  UIFont(pbCmd.Canvas, 11, False, Theme.Text);
  S := Prompt;
  { What it is holding on to, ahead of what to do with it - the way the chip
    beside the cursor reads, and the way SketchUp's bottom line reads. }
  if (FMode = mdPro) and (SnapSays <> '') then S := SnapSays + '  -  ' + S;
  pbCmd.Canvas.TextOut(X, (H - pbCmd.Canvas.TextHeight(S)) div 2, S);
  Inc(X, pbCmd.Canvas.TextWidth(S) + Round(10 * FUIScale));
  { and the keys that would do something right now, quietly, after it }
  if (FMode = mdPro) and (FInput = '') and (ModifierTip <> '') then
  begin
    UIFont(pbCmd.Canvas, 10, False, Theme.TextDim);
    S := ModifierTip;
    if X + pbCmd.Canvas.TextWidth(S) < W - Round(220 * FUIScale) then
    begin
      pbCmd.Canvas.TextOut(X, (H - pbCmd.Canvas.TextHeight(S)) div 2, S);
      Inc(X, pbCmd.Canvas.TextWidth(S) + Round(10 * FUIScale));
    end;
    UIFont(pbCmd.Canvas, 11, False, Theme.Text);
  end;

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
  { SketchUp's magenta pair, named the way it names them }
  if FParPerp = 1 then Exit('PARALLEL TO EDGE');
  if FParPerp = 2 then Exit('PERPENDICULAR TO EDGE');
  case FSnapKind of
    snEndpoint: Result := 'ENDPOINT';
    snMidpoint: Result := 'MIDPOINT';
    snSubMid:   Result := 'ON SEGMENT';
    snCenter:   Result := 'CENTER';
    snCross:    Result := 'CROSSING';
    snOnEdge:   Result := 'ON EDGE';
    snOnFace:   Result := 'ON FACE';
    snQuadrant: Result := 'QUADRANT';
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

  { Green means green.  The band is drawn in an axis color when the run is
    within a hair of that axis - AxisAlong, 0.9999 of parallel, near
    enough a degree - and up to now that was all it was: a color.  The
    point underneath could sit that degree off, and over a foot that is an
    eighth of an inch: a line that showed green from end to end and was
    not square, and a rectangle drawn inside a rectangle that would not
    close (report 215257, 21 September; "there is no wiggle room when you
    are snapped on plane").  So the run is squared onto the axis it is
    shown on - the far end moved the hair sideways onto it, its distance
    along kept - and the color is true.  The color is not a guess at what
    you meant; it is a promise about the point, and now it is kept. }
  if FParPerp = 0 then
  begin
    { the axis the band is drawn in - the same test the painter makes, so
      the two cannot disagree: a lock the resolver set, or a run that lies
      along one }
    if FAxisLock in [0..2] then K := FAxisLock
    else if FInferMode = imAll then K := AxisAlong(FP1, Result)
    else K := -1;
    if K >= 0 then
    begin
      { K is an axis - 0 X, 1 Y, 2 Z - where AxisDir counts directions, two
        to an axis; asking it for axis 1 gave minus X and a Y run collapsed
        to nothing }
      D := AxisDir(K * 2);
      AlongL := (Result.X - FP1.X) * D.X + (Result.Y - FP1.Y) * D.Y + (Result.Z - FP1.Z) * D.Z;
      Result := P3(FP1.X + D.X * AlongL, FP1.Y + D.Y * AlongL, FP1.Z + D.Z * AlongL);
      FAxisLock := K;
      FAxisFrom := FP1;
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
  if not DimGeometry(Proj, FP1, FP2, OutsideOf(FP1, FP2, DimOffset3), FD.Units, G) then Exit;
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
  The middle of a face is the one What was asked for was by name: a circle struck
  from the center of a panel is most of what this program gets used for. }
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

  The owner, drawing a rectangle in the 3D view that kept standing up when he
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
    { Found at startup: offer it there and then, the same question /update
      asks - yes fetches it, no leaves everything alone.  Not where this
      copy cannot update itself, not for a build made from source, and not
      twice for a version that has been turned down: that one waits for
      /update. }
    if (not Loud) and (WhyNotUpdate = '') and (Pos('dev', LowerCase(CurrentVersion)) = 0) then
    begin
      Ini := TIniFile.Create(ConfigFile);
      try
        Last := Ini.ReadString('update', 'declined', '');
        if Last <> Info.Tag then Ini.WriteString('update', 'declined', Info.Tag);
      finally
        Ini.Free;
      end;
      if Last <> Info.Tag then
      begin
        pbCmd.Invalidate;
        DoUpdate;
        Exit;
      end;
    end;
  end
  else
  begin
    FUpdateTag := '';
    if Loud then FCmdMsg := 'Up to date - ' + CurrentVersion + '.';
  end;
  pbCmd.Invalidate;
end;

{ 3x, x3, *3: three copies at the spacing of the one just made.  /3, 3/:
  the run divided into three.  Nothing else. }
function TMainForm.ArrayCommand(const S: string; out N: Integer; out Divide: Boolean): Boolean;
var
  T: string;
begin
  Result := False;
  N := 0;
  Divide := False;
  T := LowerCase(Trim(S));
  if Length(T) < 2 then Exit;
  if T[1] in ['x', '*', '/'] then
  begin
    Divide := T[1] = '/';
    Delete(T, 1, 1);
  end
  else if T[Length(T)] in ['x', '*', '/'] then
  begin
    Divide := T[Length(T)] = '/';
    Delete(T, Length(T), 1);
  end
  else
    Exit;
  Result := TryStrToInt(Trim(T), N) and (N >= 2) and (N <= 500);
end;

{ Make the copy just placed into N of them.  The ones already made are
  taken back first, so a second count replaces the first rather than piling
  on top of it; they are the last things in the list, so that is a matter
  of deleting from the end. }
procedure TMainForm.ApplyArray(N: Integer; Divide: Boolean);
var
  I: Integer;
begin
  if not FArray.Live then Exit;
  PushUndo;
  for I := High(FArray.Made) downto 0 do
    FD.Doc.Delete(FArray.Made[I]);
  if FArray.Rotate then
    FD.Doc.ArrayRotate(FArray.Src, FArray.C, FArray.Axis, FArray.Ang, N, Divide, FArray.Made)
  else
    FD.Doc.ArrayMove(FArray.Src, FArray.D, N, Divide, FArray.Made);
  SelectNone;
  for I := 0 to High(FArray.Made) do SelectAdd(FArray.Made[I]);
  SeedRegions;
  RenderPro;
  RecomposeAll;
  if Divide then
    FCmdMsg := Format('Divided into %d.  Another count replaces it.', [N])
  else
    FCmdMsg := Format('%d copies.  Another count replaces it.', [N]);
  pbScreen.Invalidate;
  pbCmd.Invalidate;
end;

{ The wizards.  Each builds a real piece from numbers, at the origin, and
  then hands it to the move tool so the next click puts it where it goes -
  the same move anything else gets, with the same snaps. }
{ /timings: say on the console how long the steps of an edit took }
procedure TMainForm.Took(const What: string; T0: QWord);
begin
  if not FTimings then Exit;
  TimingLine(Format('took %d ms: %s', [GetTickCount64 - T0, What]));
end;

{ One line of /timings: to the console, where there is one, and kept for the
  box, because on Windows there is not.  The oldest go once it is long - it
  is for the last few things you did, not a record. }
procedure TMainForm.TimingLine(const S: string);
const
  KEEP = 400;
var
  N: Integer;
begin
  WriteLn(S);
  Flush(Output);
  N := Length(FTimingLog);
  if N >= KEEP then
  begin
    FTimingLog := Copy(FTimingLog, N - KEEP div 2, MaxInt);
    N := Length(FTimingLog);
  end;
  SetLength(FTimingLog, N + 1);
  FTimingLog[N] := FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + S;
end;

procedure TMainForm.ShowTimingLog;
var
  I: Integer;
  T: string;
begin
  if Length(FTimingLog) = 0 then
  begin
    FCmdMsg := 'No timings collected yet - /timings, do something, then /timings again.';
    Exit;
  end;
  T := '';
  for I := 0 to High(FTimingLog) do T := T + FTimingLog[I] + LineEnding;
  ShowLongText('Step timings, oldest first', T);
end;

procedure TMainForm.RenderTiming;
var
  T0: QWord;
  I, N: Integer;
  Ms, Ov, Qk, Bl, Gd: Double;
  Ph: array[0..5] of Double;
  WasMoving: Boolean;
  Box: string;
begin
  N := 10;
  for I := 0 to 5 do FD.Doc.ProfMs[I] := 0;
  { a whole frame as an orbit makes one: paper, the drawing, the composite }
  T0 := GetTickCount64;
  for I := 1 to N do
  begin
    FScreenDirty := True;
    RepaintPaper;
    RenderPro;
    RecomposeAll;
  end;
  Ms := (GetTickCount64 - T0) / N;
  for I := 0 to 5 do Ph[I] := FD.Doc.ProfMs[I] / N;
  { the same frame the quick way, as an orbit in progress draws it }
  WasMoving := FCameraMoving;
  FCameraMoving := FQuickFrames;
  T0 := GetTickCount64;
  for I := 1 to N do
  begin
    FScreenDirty := True;
    RepaintPaper;
    RenderPro;
    RecomposeAll;
  end;
  Qk := (GetTickCount64 - T0) / N;
  FCameraMoving := WasMoving;
  RepaintPaper; RenderPro; RecomposeAll;
  { and the overlay on top - the selection outlines above all }
  T0 := GetTickCount64;
  for I := 1 to N do pbScreen.Repaint;
  Ov := (GetTickCount64 - T0) / N;
  { The blit on its own, out of the middle of that.
 
    The figure above is the whole paint handler - getting the picture onto
    the widget, and then the cursor, the guides and the outlines drawn over
    it.  Those are two different problems with two different answers, and
    for a while nobody knew which of them the number belonged to: the
    question was whether a faster surface library would help, and it only
    would if the answer is the first one.  So it is measured apart.
 
    Just the picture, no overlay, straight at the canvas the same way the
    paint handler does it. }
  T0 := GetTickCount64;
  for I := 1 to N do FArt.DrawTo(pbScreen.Canvas, FJitterX, FJitterY);
  Bl := (GetTickCount64 - T0) / N;
  { and the guides, the rubber band and the readouts on their own, which is
    the other half of that number and the half nobody was looking at }
  Gd := 0;
  if FMode = mdPro then
  begin
    T0 := GetTickCount64;
    for I := 1 to N do PaintProOverlay(pbScreen.Canvas);
    Gd := (GetTickCount64 - T0) / N;
  end;
  FCmdMsg := Format('A frame takes %.0f ms (%d things: %d faces).  index and edges %.0f, faces sorted and painted %.0f, lines on faces %.0f, the rest %.0f',
    [Ms, FD.Doc.Live, FaceCount + SolidFaceCount, Ph[0], Ph[1] + Ph[2], Ph[3], Ph[4]]);
  FCmdMsg := FCmdMsg + Format('; quick frame %.0f ms; overlay %.0f ms (blit %.0f, guides %.0f) with %d selected',
    [Qk, Ov, Bl, Gd, Length(FSel)]);
  { A paragraph in a bar built for a sentence loses its end, so the whole of
    it goes in a box that can be read and copied, a figure a line. }
  Box := Format(
    'A whole frame (paper, drawing, composite):  %.1f ms' + LineEnding +
    '  things on the sheet:                     %d  (%d faces)' + LineEnding +
    '  index and edges:                         %.1f ms' + LineEnding +
    '  faces sorted and painted:                %.1f ms' + LineEnding +
    '  lines on faces:                          %.1f ms' + LineEnding +
    '  the rest:                                %.1f ms' + LineEnding +
    'A quick frame, as an orbit draws it:       %.1f ms' + LineEnding +
    'The paint on top:                          %.1f ms' + LineEnding +
    '  the picture onto the window:             %.1f ms' + LineEnding +
    '  guides, rubber band and readouts:        %.1f ms' + LineEnding +
    '  with this many picked:                   %d' + LineEnding + LineEnding +
    'Lines-on-faces cache: built %d times, threads %s, last build %.0f ms on %s,' + LineEnding +
    '  taken %.0f ms after it was done; frames that went without it: %d' + LineEnding +
    '  (%.0f ms on the last), discarded %d, failed %d' + LineEnding + LineEnding +
    'Window %dx%d at %.2f scaling, zoom %.3f, view %s.  Each figure is the average of %d.',
    [Ms, FD.Doc.Live, FaceCount + SolidFaceCount, Ph[0], Ph[1] + Ph[2], Ph[3], Ph[4],
     Qk, Ov, Bl, Gd, Length(FSel),
     FD.Doc.OnFaceBuilds, BoolToStr(FD.Doc.Threads, 'on', 'off'),
     FD.Doc.OnFaceWorkerMs, FD.Doc.OnFaceBuiltOn, FD.Doc.OnFaceLagMs,
     FD.Doc.OnFaceFallbacks, FD.Doc.OnFaceFallbackMs,
     FD.Doc.OnFaceDiscarded, FD.Doc.OnFaceFailed,
     pbScreen.Width, pbScreen.Height, FUIScale, FD.Zoom, VIEW_NAMES[FD.View], N]);
  WriteLn('rendertime ', Ms:0:1, ' ms/frame (paper+render+composite), ', FD.Doc.Live, ' things; index+edges ',
    Ph[0]:0:1, ' faces ', (Ph[1] + Ph[2]):0:1, ' lines-on-faces ',
    Ph[3]:0:1, ' rest ', Ph[4]:0:1, '; quick frame ', Qk:0:1, '; overlay ', Ov:0:1, ' ms of which blit ', Bl:0:1, ' guides ', Gd:0:1, ', with ', Length(FSel), ' selected; onface builds so far ', FD.Doc.OnFaceBuilds,
    '; threads ', FD.Doc.Threads, ' last cache build ', FD.Doc.OnFaceWorkerMs:0:0, ' ms on ', FD.Doc.OnFaceBuiltOn, ', taken ', FD.Doc.OnFaceLagMs:0:0, ' ms after done; a frame without the cache spent ', FD.Doc.OnFaceFallbackMs:0:0, ' ms on lines-on-faces; frames without cache ',
    FD.Doc.OnFaceFallbacks, ', discarded ', FD.Doc.OnFaceDiscarded, ', failed ', FD.Doc.OnFaceFailed);
  Flush(Output);
  Trail(FCmdMsg);
  FCmdMsg := Format('A frame takes %.0f ms - the rest is in the box.', [Ms]);
  pbCmd.Invalidate;
  ShowLongText('How long a frame takes', Box);
end;

{ the normal of an arc's plane }
function TMainForm.ArcNormal(I: Integer): TP3;
var
  AU, AV: TP3;
begin
  if FD.Doc[I].Plane = plFree then Result := Norm3(FD.Doc[I].Nm)
  else
  begin
    PlaneAxes(FD.Doc[I].Plane, AU, AV);
    Result := Norm3(Cross3(AU, AV));
  end;
end;

{ Follow Me round an axis: the angle typed in degrees, or all the way; the
  gores from the circle side count, so a full turn has as many as a circle
  does and a quarter turn a quarter of them. }
{ Is this line one of the outline's own sides?

  Both its ends are corners of the outline, and they are next to each other
  round it.  That is a side rather than something that merely touches. }
function TMainForm.IsProfileEdge(I: Integer): Boolean;
const
  TOL = 1E-6;
var
  K, N, A, B: Integer;
begin
  Result := False;
  if (I < 0) or (I >= FD.Doc.Live) or (FD.Doc[I].Kind <> ekLine) then Exit;
  if (FFollowFace < 0) or (FFollowFace >= FD.Doc.Live) then Exit;
  if FD.Doc[FFollowFace].Kind <> ekFace then Exit;
  N := Length(FD.Doc[FFollowFace].Poly);
  A := -1;
  B := -1;
  for K := 0 to N - 1 do
  begin
    if Dist(FD.Doc[FFollowFace].Poly[K], FD.Doc[I].A) < TOL then A := K;
    if Dist(FD.Doc[FFollowFace].Poly[K], FD.Doc[I].B) < TOL then B := K;
  end;
  if (A < 0) or (B < 0) then Exit;
  Result := (Abs(A - B) = 1) or (Abs(A - B) = N - 1);
end;

function TMainForm.AxisSplitsProfile(const AxisP, AxisDir: TP3;
  out RLo, RHi: Double): Boolean;
begin
  Result := FD.Doc.AxisSplitsFace(FFollowFace, AxisP, AxisDir, RLo, RHi);
end;

procedure TMainForm.PaintRevolvePreview(C: TCanvas);
const
  RING_N = 48;
var
  D, AP, Q: TP3;
  RLo, RHi, L: Double;
  Bad: Boolean;
  K, N: Integer;
  Col: TPix;
  U, W, Nf: TP3;
  PA, PB: TPointF;

  procedure Circle(R: Double);
  var
    J: Integer;
    A: Double;
    P0, P1: TPointF;
  begin
    if R < 1E-9 then Exit;
    P0 := ScreenOf(P3(AP.X + U.X * R, AP.Y + U.Y * R, AP.Z + U.Z * R));
    for J := 1 to RING_N do
    begin
      A := 2 * Pi * J / RING_N;
      P1 := ScreenOf(P3(AP.X + (U.X * Cos(A) + W.X * Sin(A)) * R,
                        AP.Y + (U.Y * Cos(A) + W.Y * Sin(A)) * R,
                        AP.Z + (U.Z * Cos(A) + W.Z * Sin(A)) * R));
      C.Line(Round(P0.X), Round(P0.Y), Round(P1.X), Round(P1.Y));
      P0 := P1;
    end;
  end;

begin
  D := P3(FCur.X - FAxisA.X, FCur.Y - FAxisA.Y, FCur.Z - FAxisA.Z);
  L := Dist(D, P3(0, 0, 0));
  if L < 1E-9 then Exit;
  D := P3(D.X / L, D.Y / L, D.Z / L);
  Bad := AxisSplitsProfile(FAxisA, D, RLo, RHi);

  if Bad then Col := Pix(220, 60, 60) else Col := Theme.Accent;
  C.Pen.Color := PixToColor(Col);
  C.Pen.Width := Max(1, Round(2 * FUIScale));
  C.Brush.Style := bsClear;

  { the axis, run well past both ends - it is a line, not a segment, and
    the whole shape turns about all of it }
  N := Round(Max(RHi * 3, L * 2));
  PA := ScreenOf(P3(FAxisA.X - D.X * N, FAxisA.Y - D.Y * N, FAxisA.Z - D.Z * N));
  PB := ScreenOf(P3(FAxisA.X + D.X * N, FAxisA.Y + D.Y * N, FAxisA.Z + D.Z * N));
  C.Line(Round(PA.X), Round(PA.Y), Round(PB.X), Round(PB.Y));

  { the rings the outline's nearest and furthest corners will sweep, drawn
    about the axis at the middle of the outline }
  Nf := Norm3(FD.Doc.FaceNormal(FFollowFace));
  U := Norm3(Cross3(D, Nf));
  W := Norm3(Cross3(D, U));
  Q := P3(0, 0, 0);
  N := Length(FD.Doc[FFollowFace].Poly);
  if N = 0 then Exit;
  for K := 0 to N - 1 do
    Q := P3(Q.X + FD.Doc[FFollowFace].Poly[K].X / N,
            Q.Y + FD.Doc[FFollowFace].Poly[K].Y / N,
            Q.Z + FD.Doc[FFollowFace].Poly[K].Z / N);
  { the middle of the outline, brought onto the axis }
  Q := P3(Q.X - FAxisA.X, Q.Y - FAxisA.Y, Q.Z - FAxisA.Z);
  AP := P3(FAxisA.X + D.X * Dot3(Q, D), FAxisA.Y + D.Y * Dot3(Q, D),
           FAxisA.Z + D.Z * Dot3(Q, D));
  C.Pen.Width := 1;
  Circle(RHi);
  Circle(RLo);
end;

procedure TMainForm.DoRevolve(const AxisP, AxisDir: TP3; PathArc: Integer);
var
  Deg, Ang: Double;
  Steps, First, Made: Integer;
var
  RLo, RHi: Double;
  Split: Boolean;
begin
  Ang := 2 * Pi;
  if (FInput <> '') and TryStrToFloat(Trim(FInput), Deg) and (Deg <> 0) then
    Ang := DegToRad(Deg);
  Steps := Max(1, Round(FSidesCircle * Abs(Ang) / (2 * Pi)));
  { Said before it happens, not after.  An axis through the middle of the
    outline sweeps the two halves of it into each other, and what comes out
    is a knot with no outside - which is not a thing anybody has ever wanted
    and is very hard to recognize once it is drawn. }
  Split := AxisSplitsProfile(AxisP, AxisDir, RLo, RHi);
  if Split then
  begin
    FCmdMsg := 'The axis runs through the middle of the outline, so the two ' +
      'halves would sweep into each other.  A glass is spun about a line ' +
      'down one side of its outline, not through it.  Nothing done - move ' +
      'the axis to the edge and click again.';
    Exit;
  end;
  PushUndo;
  Made := FD.Doc.Live;
  First := FD.Doc.Revolve(FFollowFace, AxisP, AxisDir, Ang, Steps);
  if First < 0 then
  begin
    FCmdMsg := 'That could not be spun - it needs a face and an axis of some length.';
    Exit;
  end;
  Made := FD.Doc.Live - Made;
  { the circle that was followed round lies on the surface it made: a seam
    of the solid now, not a hard ring drawn across it }
  if (PathArc >= 0) and (PathArc < FD.Doc.Live) and (First < FD.Doc.Live) then
  begin
    FD.Doc.SetSoft(PathArc, True);
    FD.Doc.SetGroup(PathArc, FD.Doc[First].Grp);
  end;
  SeedRegions;
  SelectNone;
  RenderPro;
  RecomposeAll;
  FCmdMsg := Format('Spun %s in %d gores, %s to %s across.',
    [FormatAngle(RadToDeg(Ang)), Steps,
     FormatLen(RLo * 2, FD.Units), FormatLen(RHi * 2, FD.Units)]);
  if Made > 0 then ;
  ResetTool;
  FInput := '';
end;

{ Follow the edges joined to edge I as far as they go each way, while there
  is exactly one edge to follow: a path drawn as a run of lines and arcs.
  The points come back in order from one end to the other, or round and back
  to the start when the chain closes. }
function TMainForm.ChainFrom(I: Integer; out Closed: Boolean): TP3Array;
var
  Used: array of Boolean;
  Pts, More: TP3Array;
  J, K, Found, Guard: Integer;
  Tail: TP3;
  Fwd: Boolean;

  function Tip(J: Integer; AtA: Boolean): TP3;
  begin
    if AtA then Result := FD.Doc[J].A else Result := FD.Doc[J].B;
  end;

  { the one unused edge whose end sits at P, or -1 when there is none or
    more than one }
  function NextAt(const P: TP3; out AtA: Boolean): Integer;
  var
    E, Count: Integer;
  begin
    Result := -1;
    Count := 0;
    AtA := True;
    for E := 0 to FD.Doc.Live - 1 do
      if (not Used[E]) and (FD.Doc[E].Kind in [ekLine, ekArc]) then
      begin
        if Dist(FD.Doc[E].A, P) < 1E-6 then begin Inc(Count); Result := E; AtA := True; end
        else if Dist(FD.Doc[E].B, P) < 1E-6 then begin Inc(Count); Result := E; AtA := False; end;
      end;
    if Count <> 1 then Result := -1;
  end;

  procedure Append(var L: TP3Array; const P: TP3Array; Reverse: Boolean);
  var
    Q: Integer;
  begin
    for Q := 0 to High(P) do
    begin
      if Reverse then K := High(P) - Q else K := Q;
      if (Length(L) > 0) and (Dist(L[High(L)], P[K]) < 1E-9) then Continue;
      SetLength(L, Length(L) + 1);
      L[High(L)] := P[K];
    end;
  end;

begin
  Result := nil;
  Closed := False;
  SetLength(Used, FD.Doc.Live);
  Used[I] := True;
  FD.Doc.EdgePoints(I, Pts);
  if Length(Pts) < 2 then Exit;
  { forward from the end of I }
  Guard := 0;
  repeat
    Tail := Pts[High(Pts)];
    if Dist(Tail, Pts[0]) < 1E-6 then
    begin
      Closed := True;
      Break;
    end;
    Found := NextAt(Tail, Fwd);
    if Found < 0 then Break;
    Used[Found] := True;
    FD.Doc.EdgePoints(Found, More);
    Append(Pts, More, not Fwd);
    Inc(Guard);
  until Guard > 10000;
  if not Closed then
  begin
    { and backward from the start of I }
    Guard := 0;
    repeat
      Found := NextAt(Pts[0], Fwd);
      if Found < 0 then Break;
      Used[Found] := True;
      FD.Doc.EdgePoints(Found, More);
      { reverse the whole chain, append, reverse back }
      for J := 0 to High(Pts) div 2 do
      begin
        Tail := Pts[J]; Pts[J] := Pts[High(Pts) - J]; Pts[High(Pts) - J] := Tail;
      end;
      Append(Pts, More, not Fwd);
      for J := 0 to High(Pts) div 2 do
      begin
        Tail := Pts[J]; Pts[J] := Pts[High(Pts) - J]; Pts[High(Pts) - J] := Tail;
      end;
      if Dist(Pts[0], Pts[High(Pts)]) < 1E-6 then
      begin
        Closed := True;
        Break;
      end;
      Inc(Guard);
    until Guard > 10000;
  end;
  Result := Pts;
end;

{ Follow Me along a path.  The profile rides from whichever end of the path
  is nearer to it, so a path can be drawn from either end. }
procedure TMainForm.DoSweep(const Path: TP3Array; Closed: Boolean);
var
  P: TP3Array;
  Cen: TP3;
  I, First: Integer;
  DA, DB: Double;
begin
  if Length(Path) < 2 then
  begin
    FCmdMsg := 'That path has nothing to follow.';
    Exit;
  end;
  P := Copy(Path);
  if not Closed then
  begin
    Cen := P3(0, 0, 0);
    for I := 0 to High(FD.Doc[FFollowFace].Poly) do
      Cen := P3(Cen.X + FD.Doc[FFollowFace].Poly[I].X / Length(FD.Doc[FFollowFace].Poly),
                Cen.Y + FD.Doc[FFollowFace].Poly[I].Y / Length(FD.Doc[FFollowFace].Poly),
                Cen.Z + FD.Doc[FFollowFace].Poly[I].Z / Length(FD.Doc[FFollowFace].Poly));
    DA := Dist(Cen, P[0]);
    DB := Dist(Cen, P[High(P)]);
    if DB < DA then
      for I := 0 to High(P) div 2 do
      begin
        Cen := P[I]; P[I] := P[High(P) - I]; P[High(P) - I] := Cen;
      end;
  end;
  PushUndo;
  First := FD.Doc.Sweep(FFollowFace, P, Closed);
  if First < 0 then
  begin
    FCmdMsg := 'That could not be followed - it needs a face and a path of some length.';
    Exit;
  end;
  SeedRegions;
  SelectNone;
  RenderPro;
  RecomposeAll;
  if Closed then FCmdMsg := 'Followed the path all the way round.'
  else FCmdMsg := Format('Followed the path, %d legs.', [Length(P) - 1]);
  ResetTool;
  FInput := '';
end;

{ The pipe fitter's iso: the spool drawn as legs with lengths, built as one
  solid and placed like a fitting. }
procedure TMainForm.BuildSpoolWizard;
var
  Spec: TSpoolSpec;
  First: Integer;
begin
  if not TSpoolForm.Ask(FD.Units, Spec) then Exit;
  if FD.View = vkPlan then EnterFreeCamera(True);
  PushUndo;
  First := BuildSpool(FD.Doc, Spec, FInkColor, FEdgeW);
  if First < 0 then
  begin
    FCmdMsg := 'The spool could not be built.';
    Exit;
  end;
  SeedRegions;
  RenderPro;
  RecomposeAll;
  PlaceBuilt(First, P3(0, 0, 0));
end;

procedure TMainForm.BuildTransitionWizard;
var
  Spec: TTransitionSpec;
  First: Integer;
begin
  if not TTransitionForm.Ask(FD.Units, Spec) then Exit;
  if FD.View = vkPlan then EnterFreeCamera(True);
  PushUndo;
  First := BuildFitting(FD.Doc, Spec, FInkColor, FEdgeW);
  SeedRegions;
  RenderPro;
  RecomposeAll;
  PlaceBuilt(First, P3(0, 0, 0));
end;

{ The radiant heat layout wizard.  Unlike a fitting or a spool it is not
  built at the origin and moved into place - it fills the floor that is
  already selected, exactly where that floor is, so nothing is placed
  afterward; the new lines are simply selected, the way a push or a pull
  leaves its own result selected. }
procedure TMainForm.BuildRadiantWizard;
var
  Zones: TRadiantZones;
  Holes: TRadiantHoles;
  I, J, First, Z: Integer;
  Spec: TRadiantSpec;
  Manifolds: TP3Array;
  Ports: TIntArray;
  Layouts: TRadiantResults;
  R: TRadiantResult;
  Loops: Integer;
  Ft: Double;
begin
  { every face in the selection is a zone with a manifold of its own -
    the barn drawn as one big rectangle with lines across it is four
    faces, four zones; a face taken out of it is a hole, and a hole is a
    no-go.  Ctrl+A and a drag both work: the lines come along and are
    ignored. }
  SetLength(Zones, 0);
  for I := 0 to High(FSel) do
    if (FSel[I] >= 0) and (FSel[I] < FD.Doc.Live) and (FD.Doc[FSel[I]].Kind = ekFace) then
    begin
      SetLength(Zones, Length(Zones) + 1);
      Zones[High(Zones)].Outline := FD.Doc[FSel[I]].Poly;
      SetLength(Zones[High(Zones)].Holes, Length(FD.Doc[FSel[I]].Holes));
      for J := 0 to High(FD.Doc[FSel[I]].Holes) do
        Zones[High(Zones)].Holes[J] := FD.Doc[FSel[I]].Holes[J];
    end;
  if Length(Zones) = 0 then
  begin
    FCmdMsg := 'Select the floor first - a face for each zone, or everything - then Radiant heat layout.';
    pbCmd.Invalidate;
    ShowMessage(FCmdMsg);
    Exit;
  end;
  if not TRadiantForm.Ask(FD.Units, Zones, Spec, Manifolds, Ports, Layouts) then Exit;
  PushUndo;
  First := FD.Doc.Live;
  Loops := 0; Ft := 0;
  for Z := 0 to High(Zones) do
  begin
    Holes := Copy(Zones[Z].Holes);
    for I := 0 to High(Spec.Extra) do
    begin
      SetLength(Holes, Length(Holes) + 1);
      Holes[High(Holes)] := Spec.Extra[I];
    end;
    SetLength(Spec.Manifolds, 1); SetLength(Spec.Ports, 1);
    Spec.Manifolds[0] := Manifolds[Z]; Spec.Ports[0] := Ports[Z];
    { the layout the wizard searched and showed - searching again here
      took as long a second time, with nothing on screen to say so }
    if Z > High(Layouts) then Continue;
    R := Layouts[Z];
    if not R.Ok then Continue;
    BuildRadiant(FD.Doc, Zones[Z].Outline, Zones[Z].Holes, R, Spec, RGBToColor(200, 48, 32),
      IfThen(Spec.Tag <> '', Spec.Tag + ' ', 'Radiant ') + 'zone ' + IntToStr(Z + 1), Z);
    Inc(Loops, Length(R.Loops));
    Ft := Ft + R.TotalFt;
  end;
  { the obstacles added in the wizard, once, not once a zone }
  RebuildFlatFaces;
  SeedRegions;
  RenderPro;
  RecomposeAll;
  SelectNone;
  for I := First to FD.Doc.Live - 1 do SelectAdd(I);
  FCmdMsg := Format('Radiant layout built: %d zone(s), %d loop(s), %s.',
    [Length(Zones), Loops, FormatLen(Ft, FD.Units)]);
  pbScreen.Invalidate;
  pbCmd.Invalidate;
end;

{ Copy, cut and paste.

  From a note: "we need to be able to copy and paste a selection and copy and paste
  from one sheet to another etc."

  The sheet-to-sheet half is why the clipboard holds a deep copy rather than
  a list of indices: the sheet it came from may not be the one in front by
  the time it is pasted, and it may not even still exist.

  Pasting hands straight over to the move tool, the way a built fitting is
  handed over - it arrives on the cursor and a click puts it down.  SketchUp
  does the same thing, and it saves inventing a rule for where a paste lands
  that would be wrong half the time. }
procedure TMainForm.CopySelection(Cut: Boolean);
begin
  if FMode <> mdPro then Exit;
  if Length(FSel) = 0 then
  begin
    FCmdMsg := 'Nothing picked.  Click something first, or drag a box round it.';
    Exit;
  end;
  FClip := FD.Doc.CopyOut(FSel);
  if Cut then
  begin
    FCmdMsg := Format('Cut %d thing%s.  Ctrl+V puts %s down - on this sheet ' +
      'or any other.', [Length(FClip), IfThen(Length(FClip) = 1, '', 's'),
      IfThen(Length(FClip) = 1, 'it', 'them')]);
    DeleteSelection;
  end
  else
    FCmdMsg := Format('Copied %d thing%s.  Ctrl+V puts %s down - on this ' +
      'sheet or any other.', [Length(FClip), IfThen(Length(FClip) = 1, '', 's'),
      IfThen(Length(FClip) = 1, 'it', 'them')]);
  pbCmd.Invalidate;
end;

procedure TMainForm.PasteClip;
var
  N, First, Last, I: Integer;
  Idx: array of Integer;
  Mid: TP3;
begin
  if FMode <> mdPro then Exit;
  if Length(FClip) = 0 then
  begin
    FCmdMsg := 'Nothing copied yet.  Pick something and press Ctrl+C.';
    Exit;
  end;
  PushUndo;
  N := FD.Doc.PasteIn(FClip, P3(0, 0, 0), First, Last);
  if N = 0 then
  begin
    FCmdMsg := 'Nothing in that worth pasting.';
    Exit;
  end;
  SetLength(Idx, Last - First + 1);
  for I := First to Last do Idx[I - First] := I;
  if not FD.Doc.MiddleOf(Idx, Mid) then Mid := P3(0, 0, 0);
  SeedRegions;
  RenderPro;
  RecomposeAll;
  { and into the move tool, holding it by its middle }
  PlaceBuilt(First, Mid);
  FCmdMsg := Format('%d thing%s on the cursor - click to put %s down, or ' +
    'Esc to leave %s where they came from.',
    [N, IfThen(N = 1, '', 's'), IfThen(N = 1, 'it', 'them'),
     IfThen(N = 1, 'it', 'them')]);
  pbCmd.Invalidate;
end;

procedure TMainForm.PlaceBuilt(First: Integer; const Ref: TP3);
var
  I: Integer;
begin
  SetTool(ptMove);
  SelectNone;
  for I := First to FD.Doc.Live - 1 do SelectAdd(I);
  FP1 := Ref;
  FD.Doc.VertsOf(FSel, FMoveVerts);
  FStage := 1;
  FDirLock := -1;
  FMoveCopy := False;
  FMoveRigid := True;
  FInput := '';
  FCmdMsg := 'Built.  Its entry corner is on the cursor - click where it goes, ' +
    'or type a point [x,y,z].';
  pbScreen.Invalidate;
  pbCmd.Invalidate;
end;

{ The release notes, the whole history, from the help menu or /whatsnew. }
procedure TMainForm.ShowWhatsNew;
var
  F: TWhatsNewForm;
begin
  { the dialogs read one palette and it is the one the window is wearing }
  uDlgSkin.UseTheme(Themes[FThemeIdx]);
  { built in code, not from a form resource - so CreateNew, not Create }
  F := TWhatsNewForm.CreateNew(Self);
  try
    F.ShowAll;
  finally
    F.Free;
  end;
end;

{ Fetch it, check it is what the release says it is, put it in place and
  start again.  Everything the drawing has is already in the draft, so the
  restart brings it straight back. }
procedure TMainForm.DoUpdate;
var
  Info: TUpdateInfo;
  Err, Why, Tmp: string;
  UpdateForm: TUpdateForm;
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
         'Your drawings are kept just as they are - every sheet, and ' +
         'anything not saved yet stays not saved - and come straight back.',
         [Info.Tag, CurrentVersion]),
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
  begin
    FCmdMsg := 'Left alone.';
    Exit;
  end;

  SaveDraft;                          { whatever happens next, this survives }

  { beside the program, not in the system temp - a portable copy keeps its
    scratch with it, and the download has to land on the same volume as the
    file it is about to replace or the rename cannot be atomic }
  Tmp := AppDataDir + 'heckers-sketch-' + Info.Tag + '.download';
  { Written before the update runs, because the update is what starts the
    new copy, and the new copy reads this as soon as it may.  Nothing can
    change the drawing while the update window is up. }
  WriteHandoff;
  UpdateForm := TUpdateForm.Create(Self);
  try
    if UpdateForm.Run(Info, Tmp) then
    begin
      { No question on the way out.  From a note, 17 September: the save question
        came up, he did not answer it straight away, and the new copy - which
        waits for this one to let go - gave up and said another copy was
        running.  Everything is in the handoff; asking only adds a way for
        the update to fail. }
      FHandingOver := True;
      Close;
    end
    else
    begin
      DeleteFile(HandoffFile);
      FCmdMsg := 'The update was not installed.';
    end;
  finally
    UpdateForm.Free;
  end;
end;

{ The drawings as they are, for the copy that replaces this one.

  The draft would bring the work back, but the way a crash recovery does:
  not knowing which file it came from, and with nothing marked unsaved.  An
  update is not a crash.  From a note: "bring back the unsaved flags ... keep your
  drawings just as [they are] and restart."  So this carries what the draft
  leaves out, in comment lines the reader skips - the file, the sheet in
  front, and which sheets have work that is not saved. }
procedure TMainForm.WriteHandoff;
var
  L: TStringList;
  I: Integer;
  Dirt: string;
begin
  try
    L := TStringList.Create;
    try
      L.Add('# handoff from ' + CurrentVersion);
      L.Add('# path ' + FDocPath);
      L.Add('# tab ' + IntToStr(FTabIdx));
      Dirt := '';
      for I := 0 to High(FDrawings) do
        if FDrawings[I].Dirty then Dirt := Dirt + ' ' + IntToStr(I);
      L.Add('# dirty' + Dirt);
      BuildSession(L);
      ForceDirectories(ExtractFilePath(HandoffFile));
      L.SaveToFile(HandoffFile);
    finally
      L.Free;
    end;
  except
    { the draft is already written; the handoff is the better copy, not
      the only one }
    on E: Exception do DeleteFile(HandoffFile);
  end;
end;

{ The other half, in the new copy: the drawings back exactly as they were
  left - the same file behind them, the same sheet in front, and unsaved
  work still unsaved, so closing later asks the question the update did
  not.  Only after an update; one found any other time is stale and goes. }
function TMainForm.RestoreHandoff: Boolean;
var
  L: TStringList;
  I, K, Tab, NDirty: Integer;
  Path, S: string;
  Dirty: array of Boolean;
  Words: TStringArray;
begin
  Result := False;
  if not FileExists(HandoffFile) then Exit;
  Path := '';
  Tab := 0;
  Dirty := nil;
  L := TStringList.Create;
  try
    try
      L.LoadFromFile(HandoffFile);
    except
      Exit;
    end;
    for I := 0 to L.Count - 1 do
    begin
      S := L[I];
      if Copy(S, 1, 1) <> '#' then Break;
      if Copy(S, 1, 7) = '# path ' then Path := Copy(S, 8, MaxInt)
      else if Copy(S, 1, 6) = '# tab ' then Tab := StrToIntDef(Trim(Copy(S, 7, MaxInt)), 0)
      else if Copy(S, 1, 7) = '# dirty' then
      begin
        Words := Trim(Copy(S, 8, MaxInt)).Split([' '], TStringSplitOptions.ExcludeEmpty);
        for K := 0 to High(Words) do
          if StrToIntDef(Words[K], -1) >= 0 then
          begin
            if StrToInt(Words[K]) >= Length(Dirty) then
              SetLength(Dirty, StrToInt(Words[K]) + 1);
            Dirty[StrToInt(Words[K])] := True;
          end;
      end;
    end;
  finally
    L.Free;
  end;

  { the same guard the draft has: a handoff that takes the program down on
    the way in is set aside next time rather than read again - and the draft
    beside it holds the same work }
  with TIniFile.Create(ConfigFile) do
  try
    WriteBool('startup', 'restoring', True);
  finally
    Free;
  end;
  try
    try
      Result := LoadDocument(HandoffFile);
    except
      Result := False;
    end;
  finally
    with TIniFile.Create(ConfigFile) do
    try
      WriteBool('startup', 'restoring', False);
    finally
      Free;
    end;
  end;
  DeleteFile(HandoffFile);
  if not Result or FLoadSkipped then Exit(False);

  FDocPath := Path;
  NDirty := 0;
  for I := 0 to High(FDrawings) do
  begin
    FDrawings[I].Dirty := (I < Length(Dirty)) and Dirty[I];
    if FDrawings[I].Dirty then Inc(NDirty);
  end;
  if NDirty > 0 then Inc(FEditSeq);       { so the draft is written again too }
  SelectDrawing(EnsureRange(Tab, 0, High(FDrawings)));
  LayoutTabs;
  RefreshChrome;
  if FDocPath <> '' then FHint := FDocPath
  else FHint := 'Not saved to a file yet  -  Ctrl+S';
  FRestored := True;
  FCmdMsg := 'Updated from ' + IfThen(FUpdatedFrom = '', 'the last version', FUpdatedFrom) +
    ' - your drawings are back just as you left them' +
    IfThen(NDirty = 0, '.',
      Format(', %d sheet%s not saved yet.', [NDirty, IfThen(NDirty = 1, '', 's')]));
  Trail(Format('picked up the handoff: %d sheets, %d not saved, from %s',
    [Length(FDrawings), NDirty, IfThen(Path = '', 'no file', ExtractFileName(Path))]));
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
var
  DC: HDC;
  Grabbed: Boolean;
  Org: TPoint;

  { The screen cut down to this program's own windows - the main one and
    whatever dialog is up over it, their title bars with them.  The screen
    is every monitor and everything else on them: on the owner's two
    screens a report from the radiant wizard went off with his cameras,
    his other programs and his chat in it (25 September - "it took a
    screen shot of the entire screen instead of just the program").  What
    else overlaps our windows is still in it; nothing beside them is. }
  procedure OursOnly;
  const
    FRAME = 8;
    TITLE = 40;
  var
    I: Integer;
    R, F: TRect;
    Cut: TBitmap;
    Any: Boolean;
  begin
    Any := False;
    R := Rect(0, 0, 0, 0);
    for I := 0 to Screen.FormCount - 1 do
    begin
      if not Screen.Forms[I].Visible or (Screen.Forms[I].Parent <> nil) then Continue;
      F := Screen.Forms[I].BoundsRect;
      F := Rect(F.Left - FRAME, F.Top - TITLE, F.Right + FRAME, F.Bottom + FRAME);
      if not Any then R := F
      else R := Rect(Min(R.Left, F.Left), Min(R.Top, F.Top), Max(R.Right, F.Right), Max(R.Bottom, F.Bottom));
      Any := True;
    end;
    if not Any then Exit;
    R := Rect(Max(0, R.Left), Max(0, R.Top), Min(B.Width, R.Right), Min(B.Height, R.Bottom));
    if (R.Right - R.Left < 8) or (R.Bottom - R.Top < 8) then Exit;
    Cut := TBitmap.Create;
    try
      Cut.SetSize(R.Right - R.Left, R.Bottom - R.Top);
      Cut.Canvas.CopyRect(Rect(0, 0, Cut.Width, Cut.Height), B.Canvas, R);
    except
      Cut.Free;
      Exit;
    end;
    B.Free;
    B := Cut;
    Org := R.TopLeft;
  end;

begin
  { From inside a dialog the picture is of the screen, because a picture of
    this window alone would leave out the one thing being reported - cut
    down to our own windows. }
  Grabbed := False;
  Org := Point(0, 0);
  if FReportExtra <> '' then
  begin
    B := TBitmap.Create;
    try
      DC := GetDC(0);
      try
        B.LoadFromDevice(DC);
      finally
        ReleaseDC(0, DC);
      end;
      Grabbed := True;
      OursOnly;
    except
      FreeAndNil(B);
    end;
    { the fallback is a picture of the window, not of the screen, and the
      pointer has to be placed in whichever of the two this turned out to be }
    if B = nil then B := GetFormImage;
  end
  else
    B := GetFormImage;
  Result := (B <> nil) and (B.Width >= 8) and (B.Height >= 8);
  if not Result then
  begin
    B.Free;
    B := nil;
  end
  else
    DrawPointerOn(B, Grabbed, Org);
end;

{ Neither a screen grab nor a form image brings the mouse pointer with it, and
  a report about what the cursor was doing is hard to read without it: "you
  can't tell where my mouse is in the picture" was the whole of one report.
  The state text carries the coordinates, so this only has to put an arrow
  where they say.

  Screen shots are in screen coordinates and a form image is in the window's,
  which is the one thing this has to get right. }
procedure TMainForm.DrawPointerOn(B: TBitmap; ScreenCoords: Boolean; const Org: TPoint);
var
  P: TPoint;
  Arrow: array[0..6] of TPoint;
  I: Integer;
begin
  if B = nil then Exit;
  try
    P := Mouse.CursorPos;
    { a screen shot cut down to our windows starts at Org on the screen }
    if ScreenCoords then P := Point(P.X - Org.X, P.Y - Org.Y)
    else P := ScreenToClient(P);
  except
    Exit;
  end;
  if (P.X < 0) or (P.Y < 0) or (P.X >= B.Width) or (P.Y >= B.Height) then Exit;

  { the ordinary pointer shape, at the size the system draws it }
  Arrow[0] := Point(0, 0);
  Arrow[1] := Point(0, 17);
  Arrow[2] := Point(4, 13);
  Arrow[3] := Point(7, 20);
  Arrow[4] := Point(10, 18);
  Arrow[5] := Point(7, 12);
  Arrow[6] := Point(12, 12);
  for I := 0 to High(Arrow) do
    Arrow[I] := Point(Arrow[I].X + P.X, Arrow[I].Y + P.Y);

  B.Canvas.Pen.Color := clWhite;
  B.Canvas.Pen.Width := 3;
  B.Canvas.Brush.Style := bsClear;
  B.Canvas.Polygon(Arrow);
  B.Canvas.Pen.Color := clBlack;
  B.Canvas.Pen.Width := 1;
  B.Canvas.Brush.Style := bsSolid;
  B.Canvas.Brush.Color := clBlack;
  B.Canvas.Polygon(Arrow);

  { a ring as well, because an arrow on a busy drawing is easy to lose }
  B.Canvas.Brush.Style := bsClear;
  B.Canvas.Pen.Color := clRed;
  B.Canvas.Pen.Width := 2;
  B.Canvas.Ellipse(P.X - 13, P.Y - 13, P.X + 14, P.Y + 14);
  B.Canvas.Pen.Width := 1;
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
{ Take the picture.  The countdown, the flash, and the shutter.

  No longer asks anything and no longer shows the result: the form the report
  is typed into shows it, which is where it belongs.  Somebody photographing a
  fault has the fault in their head, and being asked to approve a picture
  before writing a word about it means writing the word afterwards, from
  memory - which is exactly the complaint that led here. }
procedure TMainForm.ReportFromDialog(const Where, Fields: string);
begin
  FReportExtra := Where + LineEnding + Fields;
  try
    ReportBug;
  finally
    FReportExtra := '';
  end;
end;

function TMainForm.CaptureShot(Wait: Boolean; out Bmp: TBitmap): Boolean;
var
  WasMsg: string;
  Until_: QWord;
begin
  Result := False;
  Bmp := nil;
  if FShotBusy then Exit;
  FShotBusy := True;
  WasMsg := FCmdMsg;
  try
    Application.ProcessMessages;
    if Wait then
    begin
      FCmdMsg := 'Setting up the picture - it is taken when this reaches zero.';
      ShotCountdown(10);
      if Application.Terminated then Exit;
    end;

    { Nothing about the taking of the picture may be in the picture.  The
      number goes, and so does the line in the command bar that was counting
      it down - that bar is one of the most useful things in the shot and it
      should say what it would have said.  And the question box that asked
      for the picture has to be off the screen: it has been closed, but the
      window under it has not been painted yet, so give it a moment. }
    Until_ := GetTickCount64 + 350;
    while GetTickCount64 < Until_ do
    begin
      Application.ProcessMessages;
      Sleep(15);
    end;
    FShotCount := 0;
    FShotFlash := False;
    FCmdMsg := WasMsg;
    FScreenDirty := True;
    pbScreen.Invalidate;
    pbCmd.Invalidate;
    Application.ProcessMessages;

    if not WindowShot(Bmp) then Exit;

    { and the flash after it, not before }
    FShotFlash := True;
    pbScreen.Invalidate;
    Application.ProcessMessages;
    Sleep(110);
    FShotFlash := False;
    FScreenDirty := True;
    pbScreen.Invalidate;
    Application.ProcessMessages;
    Result := True;
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
  Sending: TSendForm;
  Dlg: TForm;
  Memo: TMemo;
  Lbl, Fine: TLabel;
  WithDoc: TCheckBox;
  BtnOK, BtnNo, BtnAgain, BtnLater, BtnDrop: TButton;
  NoPic: TLabel;
  Shown: TImage;
  ShotBmp: TBitmap;
  Png: TPortableNetworkGraphic;
  DocOn: Boolean;
  Res: Integer;
  Body, Name_, Err, Note, ShotErr: string;
  WantShot: Boolean;
  NThings, LblW, Grow: Integer;
  Shot: TMemoryStream;
  L: TStringList;
  HasDrawing: Boolean;
  SheetName_, MachineIs: string;
  FileRep, FilePic, NSent: Integer;
  Total: Int64;

  { a line of the report, by the word it starts with - "version", "when" }
  function LineOf(const Text, Key: string): string;
  var
    LL: TStringList;
    K: Integer;
  begin
    Result := '';
    LL := TStringList.Create;
    try
      LL.Text := Text;
      for K := 0 to LL.Count - 1 do
        if Copy(LL[K], 1, Length(Key) + 1) = Key + ':' then
        begin
          Result := Trim(Copy(LL[K], Length(Key) + 2, MaxInt));
          Exit;
        end;
    finally
      LL.Free;
    end;
  end;

  { one key=value out of the report's state lines - "mode=", "theme=" }
  function Tok(const Key: string): string;
  var
    K: Integer;
  begin
    Result := '';
    K := Pos(Key, Body);
    if K = 0 then Exit('-');
    Inc(K, Length(Key));
    while (K <= Length(Body)) and not (Body[K] in [' ', #10, #13]) do
    begin
      Result := Result + Body[K];
      Inc(K);
    end;
  end;

  function BodyLine(const Key: string): string;
  begin
    Result := LineOf(Body, Key);
  end;

  function MachineLine(const Key: string): string;
  begin
    Result := LineOf(MachineIs, Key);
  end;

  function KB(Bytes: Int64): string;
  begin
    if Bytes < 10 * 1024 then Result := FormatFloat('0.0', Bytes / 1024) + ' KB'
    else Result := FormatFloat('0', Bytes / 1024) + ' KB';
  end;

begin
  Result := False;

  { The picture comes first, and the form that the report is typed into shows
    it.

    It used to be the other way round: type the report, then be asked about a
    picture, then approve the picture.  Which meant writing the description
    of a fault before photographing it, and then photographing it from
    memory - and if the picture came out wrong there was no way back to it
    without losing what had been written.  Taking it first, and putting it in
    front of somebody while they write, means the words and the picture are
    about the same thing.  Taking another is a button on the form and costs
    nothing that was typed. }
  { The picture is taken straight away, of the window as it is, and the
    form opens with it in view - no question first.  From the form it can
    be taken again now, in ten seconds after something has been set up to
    show, or dropped. }
  Application.ProcessMessages;
  ShotBmp := nil;
  if (ShotFile <> '') and FileExists(ShotFile) then
  begin
    { for a crash, the picture saved when it happened; what is on screen
      now is the restart }
    try
      ShotBmp := TBitmap.Create;
      ShotBmp.LoadFromFile(ShotFile);
    except
      FreeAndNil(ShotBmp);
    end;
  end
  else
    CaptureShot(False, ShotBmp);
  WantShot := ShotBmp <> nil;

  Note := '';
  DocOn := True;
  try
  repeat
  Dlg := TForm.CreateNew(nil);
  try
    Dlg.Caption := 'Report a problem';
    Dlg.Position := poMainFormCenter;
    Dlg.BorderStyle := bsDialog;
    Dlg.ClientWidth := Round(600 * FUIScale);
    Dlg.ClientHeight := Round(560 * FUIScale);

    Lbl := TLabel.Create(Dlg);
    Lbl.Parent := Dlg;
    { Wrapped, and given the room to wrap into.  It was running off the
      right-hand side, which is what happens to a fixed height with a
      variable amount of text in it. }
    LblW := Dlg.ClientWidth - Round(24 * FUIScale);
    Lbl.SetBounds(Round(12 * FUIScale), Round(10 * FUIScale),
      LblW, Round(62 * FUIScale));
    Lbl.WordWrap := True;
    Lbl.AutoSize := False;
    if Preamble <> '' then
      Lbl.Caption := 'It crashed last time.  What were you doing when it ' +
        'went?  A line or two is plenty - the crash report itself is ' +
        'attached automatically, along with what the program was doing and ' +
        'what machine this is - RAM, processor, graphics, operating system; ' +
        'nothing about you.'
    else
      Lbl.Caption := 'What were you doing, and what happened?  A line or ' +
        'two is plenty.  Added automatically: what the program was doing ' +
        '- the tool, the view, the last few dozen things that happened - ' +
        'and what machine this is: RAM, processor, graphics, operating ' +
        'system.  Nothing about you.';

    { And then let it measure itself.  Four lines of room was enough for the
      words at the font this was written at and not at a larger one, so the
      last line was being cut off halfway down - the sentence explaining what
      goes in the report was the part you could not read.  Pinning the width
      and asking the label how tall it needs to be gets the true answer for
      whatever font and scaling this machine turned out to have, and the rest
      of the form drops by the difference. }
    Lbl.Constraints.MinWidth := LblW;
    Lbl.Constraints.MaxWidth := LblW;
    Lbl.AutoSize := True;
    Grow := Lbl.Height - Round(62 * FUIScale);
    if Grow < 0 then Grow := 0;
    Dlg.ClientHeight := Dlg.ClientHeight + Grow;

    Memo := TMemo.Create(Dlg);
    Memo.Parent := Dlg;
    Memo.SetBounds(Round(12 * FUIScale), Round(78 * FUIScale) + Grow,
      Dlg.ClientWidth - Round(24 * FUIScale), Round(180 * FUIScale));
    Memo.ScrollBars := ssAutoVertical;
    Memo.WordWrap := True;
    { whatever was typed before the picture was taken again }
    Memo.Text := Note;

    { The drawing file stays off, and the picture is not asked about here at
      all - it is asked about after this closes, so the question is about a
      picture that has actually been taken and so that the form is not in
      front of the thing being photographed. }
    WithDoc := TCheckBox.Create(Dlg);
    WithDoc.Parent := Dlg;
    { A check box will not wrap, so its words have to fit on one line and the
      rest of the thought goes underneath it. }
    WithDoc.SetBounds(Round(12 * FUIScale), Round(268 * FUIScale) + Grow,
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
      grays out rather than offering to send an empty sheet. }
    NThings := DocThings(DocFile);
    if NThings = 0 then
      WithDoc.Caption := 'Send the drawing too - nothing drawn yet'
    else
      WithDoc.Caption := Format('Send the drawing too - %d %s drawn so far',
        [NThings, specialize IfThen<string>(NThings = 1, 'thing', 'things')]);

    { On by default.  the, and he is right: it is the single most useful
      thing in a report and it was going unticked simply because it was
      unticked.  It stays a tick box, and it stays easy to see, because it is
      somebody's work and they get to say.

      DocOn, not True, and that is the whole of a bug worth remembering.
      This dialog is rebuilt from scratch every time the picture is retaken
      or dropped - the buttons for that come back as mrRetry, mrAll and
      mrIgnore, and the loop goes round again.  The note survives that, two
      dozen lines up, because Memo.Text is seeded from Note.  The tick did
      not: it was set from the thing count alone, so it came back ticked.

      So somebody who unticked "send the drawing" and then dropped the
      picture sent their drawing anyway, having been told twice that they
      get to say.  That is not a cosmetic fault - it is the program doing
      the one thing this box exists to prevent. }
    WithDoc.Checked := (NThings > 0) and DocOn;
    WithDoc.Enabled := NThings > 0;

    Fine := TLabel.Create(Dlg);
    Fine.Parent := Dlg;
    Fine.SetBounds(Round(30 * FUIScale), Round(290 * FUIScale) + Grow,
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

    { The picture, where it can be looked at while the words are written. }
    if WantShot then
    begin
      Shown := TImage.Create(Dlg);
      Shown.Parent := Dlg;
      Shown.SetBounds(Round(12 * FUIScale), Round(336 * FUIScale) + Grow,
        Dlg.ClientWidth - Round(24 * FUIScale), Round(170 * FUIScale));
      Shown.Stretch := True;
      Shown.Proportional := True;
      Shown.Center := True;
      Shown.Picture.Assign(ShotBmp);
    end
    else
    begin
      NoPic := TLabel.Create(Dlg);
      NoPic.Parent := Dlg;
      NoPic.Caption := 'No picture with this report.';
      NoPic.Alignment := taCenter;
      NoPic.AutoSize := False;
      NoPic.SetBounds(Round(12 * FUIScale), Round(410 * FUIScale) + Grow,
        Dlg.ClientWidth - Round(24 * FUIScale), Round(22 * FUIScale));
    end;

    { the picture: again now, in ten seconds so something can be set up to
      show, or not at all }
    BtnAgain := TButton.Create(Dlg);
    BtnAgain.Parent := Dlg;
    BtnAgain.Caption := 'Snap now';
    BtnAgain.ModalResult := mrRetry;
    BtnAgain.SetBounds(Round(12 * FUIScale), Dlg.ClientHeight -
      Round(42 * FUIScale), Round(100 * FUIScale), Round(30 * FUIScale));
    BtnLater := TButton.Create(Dlg);
    BtnLater.Parent := Dlg;
    BtnLater.Caption := 'Snap in 10 s';
    BtnLater.ModalResult := mrAll;
    BtnLater.SetBounds(Round(120 * FUIScale), Dlg.ClientHeight -
      Round(42 * FUIScale), Round(110 * FUIScale), Round(30 * FUIScale));
    BtnDrop := TButton.Create(Dlg);
    BtnDrop.Parent := Dlg;
    BtnDrop.Caption := 'Discard picture';
    BtnDrop.ModalResult := mrIgnore;
    BtnDrop.Enabled := WantShot;
    BtnDrop.SetBounds(Round(238 * FUIScale), Dlg.ClientHeight -
      Round(42 * FUIScale), Round(120 * FUIScale), Round(30 * FUIScale));

    BtnOK := TButton.Create(Dlg);
    BtnOK.Parent := Dlg;
    BtnOK.Caption := 'Send';
    BtnOK.ModalResult := mrOK;
    { not the default button: Enter while writing the note must not send
      it - a report arrived cut off in the middle of a word that way }
    BtnOK.SetBounds(Dlg.ClientWidth - Round(224 * FUIScale),
      Dlg.ClientHeight - Round(42 * FUIScale),
      Round(100 * FUIScale), Round(30 * FUIScale));

    BtnNo := TButton.Create(Dlg);
    BtnNo.Parent := Dlg;
    BtnNo.Caption := 'Cancel';
    BtnNo.ModalResult := mrCancel;
    BtnNo.Cancel := True;
    BtnNo.SetBounds(Dlg.ClientWidth - Round(112 * FUIScale),
      Dlg.ClientHeight - Round(42 * FUIScale),
      Round(100 * FUIScale), Round(30 * FUIScale));

    Res := Dlg.ShowModal;
    { kept whatever happens, so taking another picture costs nothing that was
      typed - which is the whole point of the button }
    Note := Trim(Memo.Text);
    DocOn := WithDoc.Checked and WithDoc.Enabled;
  finally
    Dlg.Free;
  end;

  if Res in [mrRetry, mrAll] then
  begin
    FreeAndNil(ShotBmp);
    CaptureShot(Res = mrAll, ShotBmp);
    WantShot := ShotBmp <> nil;
  end
  else if Res = mrIgnore then
  begin
    FreeAndNil(ShotBmp);
    WantShot := False;
  end;
  until not (Res in [mrRetry, mrAll, mrIgnore]);

  if Res <> mrOK then
  begin
    FCmdMsg := 'Report canceled.';
    Exit;
  end;

    Body := 'Heckers Sketch report' + LineEnding +
      specialize IfThen<string>(Preamble = '', '',
        'this one followed a crash' + LineEnding) +
      'version: ' + CurrentVersion + '  built ' + BUILD_STAMP + LineEnding +
      'when: ' + DateTimeToStr(Now) + LineEnding + LineEnding +
      'what they said:' + LineEnding +
      specialize IfThen<string>(Note = '', '(nothing written)', Note) +
      LineEnding + LineEnding +
      'state:' + LineEnding + DiagnosticText +
      LineEnding + 'settings and circumstances:' + LineEnding + SettingsText +
      LineEnding + 'machine:' + LineEnding + MachineText;
    if FReportExtra <> '' then
      Body := Body + LineEnding + 'in the dialog:' + LineEnding + FReportExtra;
    if Preamble <> '' then
      Body := Body + LineEnding + 'the crash it left behind:' + LineEnding +
        Preamble;
    if DocOn then
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

  { The picture goes as PNG bytes only now that it is being sent - the one
    nobody kept was never encoded. }
  Shot := TMemoryStream.Create;
  try
    if WantShot and (ShotBmp <> nil) then
    begin
      Png := TPortableNetworkGraphic.Create;
      try
        Png.Assign(ShotBmp);
        Png.SaveToStream(Shot);
      finally
        Png.Free;
      end;
    end;
    if Shot.Size = 0 then WantShot := False;
    KeepReportCopy(Name_, Body, Shot);

    FCmdMsg := 'Sending...';
  pbCmd.Invalidate;
  { Shown going out, stage by stage, the way an update is shown coming in -
    what is being sent and how big it is, with a moment on each so it can be
    read.  the ask: a report that vanishes in a blink is a report you
    cannot vouch for. }
  HasDrawing := Pos('the drawing, sent on purpose', Body) > 0;
  { the machine's lines are the ones after "machine:" in the report, so a
    "machine: Dell..." line there is not mistaken for the heading }
  MachineIs := Body;
  if Pos(LineEnding + 'machine:' + LineEnding, MachineIs) > 0 then
    Delete(MachineIs, 1, Pos(LineEnding + 'machine:' + LineEnding, MachineIs) +
      Length(LineEnding + 'machine:' + LineEnding) - 1);
  if Pos(LineEnding + 'the drawing, sent on purpose', MachineIs) > 0 then
    SetLength(MachineIs, Pos(LineEnding + 'the drawing, sent on purpose', MachineIs));
  if FD <> nil then SheetName_ := FD.Name else SheetName_ := '-';
  Sending := TSendForm.CreateSending(Self, 'Sending your report');
  try
    { Everything the summary says is put on the page before anything goes,
      and the files are listed as waiting - so the page is whole from the
      start and what changes is each file's row as it is encrypted, sent
      and arrives.  The facts are the report's own: they are read back out
      of the text that is about to be sent, so the summary cannot say
      something the report does not. }
    FileRep := Sending.AddFile(IfThen(HasDrawing, 'Report and drawing', 'Report'),
      Name_, KB(Length(Body)));
    if WantShot then
      FilePic := Sending.AddFile('Picture', ChangeFileExt(Name_, '.png'), KB(Shot.Size))
    else
      FilePic := Sending.AddFile('Picture', 'none', '-', ssNone);

    { the machine and the program first and side by side: on a bench of
      test machines that is the part looked for }
    Sending.Fact('This machine', 'System', MachineLine('os'));
    Sending.Fact('This machine', 'Computer', MachineLine('machine'));
    Sending.Fact('This machine', 'Processor', MachineLine('cpu'));
    Sending.Fact('This machine', 'Memory', MachineLine('ram'));
    Sending.Fact('This machine', 'Graphics', MachineLine('graphics'));
    Sending.Fact('This machine', 'Display', MachineLine('display'));
    Sending.Fact('This machine', 'Locale', MachineLine('locale'));

    Sending.Fact('The program', 'Version', BodyLine('version'));
    Sending.Fact('The program', 'Toolkit', MachineLine('toolkit'));
    Sending.Fact('The program', 'Memory', MachineLine('program memory'));
    Sending.Fact('The program', 'Running', MachineLine('program'));
    Sending.Fact('The program', 'Working in', Tok('mode=') + ' mode, ' +
      Tok('view=') + ' view, ' + Tok('units=') + ', ' + Tok('theme=') + ' theme');
    Sending.Fact('The program', 'Drawing area', Tok('screen=') +
      ' at scaling ' + Tok('scaling='));
    Sending.Fact('The program', 'Network', Tok('net='));

    Sending.Fact('The report', 'Your words', IfThen(Note = '', 'nothing written',
      Format('%d characters', [Length(Note)])));
    Sending.Fact('The report', 'The drawing', IfThen(HasDrawing,
      Format('included - %d things', [NThings]), 'not included'));
    Sending.Fact('The report', 'Sheet', SheetName_);
    Sending.Fact('The report', 'The picture', IfThen(WantShot,
      'the program window, ' + KB(Shot.Size), 'none'));
    Sending.Fact('The report', 'Also in it', 'the tool, the view, the last ' +
      'few dozen things that happened, and this machine.  Nothing about you.');
    Sending.Fact('The report', 'When', BodyLine('when'));

    Sending.Stage('Preparing the report',
      Format('%s of text: what you wrote, the state of the program%s.',
        [KB(Length(Body)),
         IfThen(HasDrawing, ', and the drawing', '')]), 15);
    { the pause on each stage is on purpose - see above - and this one is
      the stage nobody could see: the encrypting happens inside SendReport }
    Sending.FileState(FileRep, ssEncrypting);
    Sending.Stage('Encrypting the report',
      Format('Encrypting %s to a key only we hold - nothing in it can be ' +
        'read on the way, whatever happens to the postbox it travels through.',
        [KB(Length(Body))]), 28, 1600);
    Sending.FileState(FileRep, ssSending);
    Sending.Stage('Sending the report', Name_, 40);
    if SendReport(Name_, Body, Err) then
    begin
      Result := True;
      Sending.FileState(FileRep, ssSent, KB(LastSealedBytes));
      Total := LastSealedBytes;
      NSent := 1;
      FCmdMsg := 'Report sent - thank you.  (' + Name_ + ')';
      { The picture goes as its own file beside the report, sharing its name,
        so the two are obviously a pair.  If it will not go, the report has
        already gone and that is the part that mattered. }
      if WantShot then
        try
          Sending.FileState(FilePic, ssEncrypting);
          Sending.Stage('Encrypting and sending the picture',
            Format('%s of screenshot, as %s', [KB(Shot.Size),
              ChangeFileExt(Name_, '.png')]), 75);
          Sending.FileState(FilePic, ssSending);
          Shot.Position := 0;
          if not SendBinary(ChangeFileExt(Name_, '.png'), Shot, 'image/png',
               ShotErr) then
          begin
            FCmdMsg := FCmdMsg + '  (the picture did not go: ' + ShotErr + ')';
            Sending.FileState(FilePic, ssFailed, '', ShotErr);
          end
          else
          begin
            Sending.FileState(FilePic, ssSent, KB(LastSealedBytes));
            Total := Total + LastSealedBytes;
            Inc(NSent);
          end;
        except
          on Ex: Exception do
          begin
            FCmdMsg := FCmdMsg + '  (no picture: ' + Ex.ClassName + ')';
            Sending.FileState(FilePic, ssFailed, '', Ex.ClassName);
          end;
        end;
      Sending.Finish('Sent - thank you',
        Format('%d %s, %s, encrypted before leaving this computer.',
          [NSent, IfThen(NSent = 1, 'file', 'files'), KB(Total)]),
        '<h3>How it traveled</h3><ul>' +
        '<li><b>Encrypted on this computer</b>, before anything left it, to ' +
        'a key only the project holds.</li>' +
        '<li>The postbox it passes through sees a name and a size, and ' +
        'nothing that can be read.</li>' +
        '<li><b>A copy of what you sent</b> is kept on this computer, not ' +
        'encrypted, so you can see exactly what went:<br><code>' +
        Esc(AppDataDir + 'reports-sent') + '</code></li></ul>', True);
    end
    else
    begin
      FCmdMsg := 'The report could not be sent - ' + Err;
      Sending.FileState(FileRep, ssFailed, '', Err);
      if WantShot then Sending.FileState(FilePic, ssFailed, '', 'not tried');
      Sending.Finish('The report did not go', Err,
        '<h3>What happened</h3><ul>' +
        '<li>' + Esc(Err) + '</li>' +
        '<li><b>Nothing is lost and nothing is broken</b> - it just did not ' +
        'send.</li>' +
        '<li>A copy of the report is kept on this computer:<br><code>' +
        Esc(AppDataDir + 'reports-sent') + '</code></li>' +
        '<li>The help button has the project page if you would rather say ' +
        'it there.</li></ul>', False);
    end;
  finally
    Sending.Free;
  end;
  finally
    Shot.Free;
  end;
  finally
    ShotBmp.Free;
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

procedure TMainForm.OfferCrashReport(JustNow: Boolean);
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
    case MessageDlg(IfThen(JustNow, 'Something went wrong', 'It crashed last time'),
           IfThen(JustNow,
             'Something just went wrong inside the program.  It is still ' +
             'running, and a report has been written.',
             'There is a crash report from a previous run.') + #13#10#13#10 +
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
          same crash again.  Which is exactly what the owner saw, and only ever on
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

{ Everything that is being drawn, in screen points, so the whole of it can
  be leaned on rather than one strand of it.

  Holding the button to throw away what you are drawing was written for the
  line tool, where the thing in progress *is* one strand.  On a rectangle it
  strained a single diagonal from the first corner to the cursor - which is
  not any part of the rectangle, and read as though something else entirely
  had appeared to be destroyed.  the note: a rectangle should come under
  tension as a rectangle.  So each tool says what its outline is and the
  strain is laid along all of it. }
function TMainForm.StrainOutline(out Pts: TPointFArray): Boolean;
var
  RectPrev: TP3Array;
  K: Integer;
  R: Double;
  Nm: TP3;
  ArcPl: TPlane;
  ArcC: TP3;
  ArcR, ArcA0, ArcSw, ArcBulge: Double;
begin
  Pts := nil;
  Result := False;
  case FTool of
    ptRect:
      if FStage = 1 then
      begin
        RectPrev := RectCorners(FP1, RectTarget, FD.Plane);
        SetLength(Pts, 5);
        for K := 0 to 3 do Pts[K] := ScreenOf(RectPrev[K]);
        Pts[4] := Pts[0];
      end;
    ptCircle:
      if FStage = 1 then
      begin
        R := Dist(FP1, FCur);
        if R > 1E-9 then
        begin
          SetLength(Pts, FSidesCircle + 1);
          for K := 0 to FSidesCircle do
            Pts[K] := ScreenOf(ArcPoint(FP1, R,
              2 * Pi * K / FSidesCircle, FD.Plane));
        end;
      end;
    ptOffset:
      if FStage = 1 then
      begin
        RectPrev := OffsetPreview;
        if Length(RectPrev) >= 3 then
        begin
          SetLength(Pts, Length(RectPrev) + 1);
          for K := 0 to High(RectPrev) do Pts[K] := ScreenOf(RectPrev[K]);
          Pts[High(Pts)] := Pts[0];
        end;
      end;
    ptPush, ptDrill:
      { the face where it would have landed - the thing you were about to
        commit to, straining and going back }
      if (FStage = 1) and (FPushFace >= 0) and (FPushFace < FD.Doc.Live) then
      begin
        RectPrev := FD.Doc[FPushFace].Poly;
        if Length(RectPrev) >= 3 then
        begin
          R := PushDistance;
          Nm := FD.Doc.FaceNormal(FPushFace);
          SetLength(Pts, Length(RectPrev) + 1);
          for K := 0 to High(RectPrev) do
            Pts[K] := ScreenOf(P3(RectPrev[K].X + Nm.X * R,
                                  RectPrev[K].Y + Nm.Y * R,
                                  RectPrev[K].Z + Nm.Z * R));
          Pts[High(Pts)] := Pts[0];
        end;
      end;
    ptArc:
      { the curve itself, not the chord under it }
      if FStage = 2 then
      begin
        if ArcPicks(FCur, ArcPl, ArcC, ArcR, ArcA0, ArcSw, ArcBulge) then
        begin
          SetLength(Pts, FSidesArc + 1);
          for K := 0 to FSidesArc do
            Pts[K] := ScreenOf(ArcPoint(ArcC, ArcR,
              ArcA0 + ArcSw * K / FSidesArc, ArcPl));
        end;
      end;
  end;
  { anything else - a line, an arc still being aimed, a move - is the one
    strand it always was }
  if Length(Pts) < 2 then
  begin
    SetLength(Pts, 2);
    Pts[0] := ScreenOf(FP1);
    Pts[1] := PtF(FMouseSX, FMouseSY);
  end;
  Result := True;
end;

{ The whole outline under tension.

  Each side bows away from the middle of the shape and trembles harder the
  nearer it gets to letting go, so a rectangle swells like a frame of elastic
  and a circle like a hoop.  One burst of shards at the middle at the end,
  and one caption, because it is one gesture destroying one thing. }
procedure TMainForm.PaintStrainPath(C: TCanvas; const Pts: TPointFArray;
  T: Single);
var
  I: Integer;
  CX, CY: Double;
begin
  if Length(Pts) < 2 then Exit;
  CX := 0;
  CY := 0;
  for I := 0 to High(Pts) do
  begin
    CX := CX + Pts[I].X / Length(Pts);
    CY := CY + Pts[I].Y / Length(Pts);
  end;
  for I := 0 to High(Pts) - 1 do
    PaintStrainSeg(C, Pts[I], Pts[I + 1], T, Length(Pts) > 2, CX, CY);
  PaintStrainMark(C, CX, CY, T);
end;

procedure TMainForm.PaintStrain(C: TCanvas; const A, B: TPointF; T: Single);
var
  P: TPointFArray;
begin
  SetLength(P, 2);
  P[0] := A;
  P[1] := B;
  PaintStrainPath(C, P, T);
end;

{ One side of it.  Bows away from CX,CY when the shape has a middle to bow
  away from, and to one side when it is a single strand. }
procedure TMainForm.PaintStrainSeg(C: TCanvas; const A, B: TPointF; T: Single;
  Outward: Boolean; CX, CY: Double);
var
  I, N, W: Integer;
  MX, MY, DX, DY, L, NX, NY, Bow, Sh: Double;
  P0, P1: TPointF;
  Col: TPix;
begin
  T := EnsureRange(T, 0, 1);
  DX := B.X - A.X;
  DY := B.Y - A.Y;
  L := Sqrt(DX * DX + DY * DY);
  if L < 2 then Exit;
  NX := -DY / L;
  NY := DX / L;
  { away from the middle, so the whole shape swells rather than each side
    bowing whichever way its own math happened to point }
  if Outward and
     (NX * ((A.X + B.X) / 2 - CX) + NY * ((A.Y + B.Y) / 2 - CY) < 0) then
  begin
    NX := -NX;
    NY := -NY;
  end;

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

  C.Pen.Width := 1;
end;

{ The shards and the warning, once, at the middle of whatever is being
  destroyed - not once per side, which on a rectangle was four bursts and
  four copies of the same sentence. }
procedure TMainForm.PaintStrainMark(C: TCanvas; CX, CY: Double; T: Single);
var
  I: Integer;
  Ang, R: Double;
  Col: TPix;
  Cap: string;
  Sz: TSize;
begin
  T := EnsureRange(T, 0, 1);
  Col := MixPix(AnnotColor, Pix(230, 38, 28), Power(T, 0.7));
  C.Pen.Style := psSolid;
  C.Pen.Color := PixToColor(Col);

  { and at the very end it starts to come apart - shards off the middle }
  if T > 0.78 then
  begin
    C.Pen.Width := Max(1, Round(2 * FUIScale));
    R := (T - 0.78) / 0.22 * 13 * FUIScale;
    for I := 0 to 5 do
    begin
      Ang := I * Pi / 3 + T * 3;
      C.MoveTo(Round(CX + Cos(Ang) * R * 0.35), Round(CY + Sin(Ang) * R * 0.35));
      C.LineTo(Round(CX + Cos(Ang) * R), Round(CY + Sin(Ang) * R));
    end;
  end;

  { Say what is about to happen.  A gesture that destroys something has to
    announce itself before it does it, or the first time you meet it is by
    accident and it looks like a bug. }
  if T > 0.12 then
  begin
    { What it is about to do, in the words of the thing it is doing it to.
      Nothing is thrown away by a push/pull that never happened - what goes
      back is the face, and saying "thrown away" of a face that is still
      there reads as though the drawing is about to lose something. }
    if FTool = ptLine then
    begin
      if T > 0.7 then Cap := 'LETTING GO...'
      else Cap := 'keep holding to snap the line off';
    end
    else if FTool in [ptPush, ptDrill, ptOffset] then
    begin
      if T > 0.7 then Cap := 'PUTTING IT BACK...'
      else Cap := 'changed your mind?  keep holding';
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
    C.TextOut(Round(CX - Sz.cx / 2), Round(CY - Sz.cy - 14 * FUIScale), Cap);
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
  C.Pen.Style := psSolid;
  { The two ends recoiling is a thing about a line snapping.

    A rectangle or a circle does not have two ends, and drawing them anyway
    put a stray strand across the shape for the fifth of a second the recoil
    lasts - reported as "a split second where it shows the exploding line
    still".  It was the recoil, not the strain, and it was the one part of
    the gesture that had not been told the shape is not a line.  Only the
    burst for those. }
  if FSnapEnds then
  begin
    DX := FSnapB.X - FSnapA.X;
    DY := FSnapB.Y - FSnapA.Y;
    L := Sqrt(DX * DX + DY * DY);
    if L >= 2 then
    begin
      DX := DX / L;
      DY := DY / L;
      C.Pen.Width := Max(1, Round(2 * FUIScale * (1 - T)));
      C.Pen.Color := PixToColor(MixPix(AnnotColor, Theme.Screen1, T));
      L := L * 0.30 * (1 - T);
      C.MoveTo(Round(FSnapA.X), Round(FSnapA.Y));
      C.LineTo(Round(FSnapA.X + DX * L), Round(FSnapA.Y + DY * L));
      C.MoveTo(Round(FSnapB.X), Round(FSnapB.Y));
      C.LineTo(Round(FSnapB.X - DX * L), Round(FSnapB.Y - DY * L));
    end;
  end;
  C.Pen.Width := Max(1, Round(2 * FUIScale * (1 - T)));
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
    { SketchUp's On Face is blue, and the point sits on the surface }
    snOnFace:             MarkPix := Pix(70, 130, 240);
    { a circle's quadrant, in the endpoint's family }
    snQuadrant:           MarkPix := Pix(90, 235, 120);
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

{ Wash a face in a color without hiding what is on it.

  A solid fill over a panel would cover the lines and the notes that live on
  it, which is the opposite of helpful when the question being asked is "am I
  about to delete the right thing".  A diagonal hatch reads as marked out
  from across the room and leaves the drawing legible underneath. }
{ The eraser's warning across a face it has locked on to.

  Drawn as hatching laid in the face's own plane, in short pieces, and each
  piece is kept only where the face can actually be seen.  It used to be a
  hatched polygon on the canvas, which is on top of everything by
  construction - so with a column standing in front of the wall the eraser
  was about to take, the red spilled straight across the column, and the
  picture said the column was going too.

  Two questions decide whether a piece is drawn.  Is its middle inside the
  face - inside the outline and outside any window in it?  And is anything in
  front of that point?  The second is asked of the depth buffer the render
  left behind, one lookup per piece, which is what makes this cheap enough to
  run while the mouse hovers. }
procedure TMainForm.WashFace(C: TCanvas; Face: Integer; const Col: TPix);
const
  STEP_PX = 7;      // between hatch lines
  PIECE_PX = 6;     // along each one
var
  Nm, AU, AV, O, P, Look: TP3;
  Poly: TP3Array;
  UV: array of TPointF;
  HUV: array of array of TPointF;
  I, J, H, N, Steps, Pieces: Integer;
  MinU, MaxU, MinV, MaxV, Ppx, StepW, PieceW, Diag, T0, T1, A, B: Double;
  U0, V0, DU, DV, Len: Double;
  SA, SB: TPointF;
  Ink: TArtSurface;
  Zb, Dp: Double;

  function InFace(U, V: Double): Boolean;
  var
    Q, R, W: Integer;
    Inside: Boolean;
  begin
    Inside := False;
    R := N - 1;
    for Q := 0 to N - 1 do
    begin
      if ((UV[Q].Y > V) <> (UV[R].Y > V)) and
         (U < (UV[R].X - UV[Q].X) * (V - UV[Q].Y) / (UV[R].Y - UV[Q].Y) + UV[Q].X) then
        Inside := not Inside;
      R := Q;
    end;
    if Inside then
      for W := 0 to High(HUV) do
      begin
        R := High(HUV[W]);
        for Q := 0 to High(HUV[W]) do
        begin
          if ((HUV[W][Q].Y > V) <> (HUV[W][R].Y > V)) and
             (U < (HUV[W][R].X - HUV[W][Q].X) * (V - HUV[W][Q].Y) /
                  (HUV[W][R].Y - HUV[W][Q].Y) + HUV[W][Q].X) then
            Inside := not Inside;
          R := Q;
        end;
      end;
    Result := Inside;
  end;

  function Seen(const W: TP3): Boolean;
  var
    SP: TPointF;
  begin
    Result := True;
    if (Ink = nil) or not Ink.DepthOn then Exit;
    SP := ScreenOf(W);
    Zb := Ink.DepthAt(Round(SP.X), Round(SP.Y));
    if Zb < -1E29 then Exit;
    Dp := Dot3(W, Look);
    Result := Zb <= Dp + 1E-3 * (1 + Abs(Dp));
  end;

begin
  if (Face < 0) or (Face >= FD.Doc.Live) or (FD.Doc[Face].Kind <> ekFace) then
    Exit;
  Poly := FD.Doc[Face].Poly;
  N := Length(Poly);
  if N < 3 then Exit;
  Ink := ActiveInk;
  Look := ViewDir(Proj);
  Nm := Norm3(FD.Doc.FaceNormal(Face));
  AxesFromNormal(Nm, AU, AV);
  O := Poly[0];

  { the face and its windows in the plane's own coordinates }
  SetLength(UV, N);
  MinU := 1E30; MaxU := -1E30; MinV := 1E30; MaxV := -1E30;
  for I := 0 to N - 1 do
  begin
    P := P3(Poly[I].X - O.X, Poly[I].Y - O.Y, Poly[I].Z - O.Z);
    UV[I] := PtF(Dot3(P, AU), Dot3(P, AV));
    MinU := Min(MinU, UV[I].X); MaxU := Max(MaxU, UV[I].X);
    MinV := Min(MinV, UV[I].Y); MaxV := Max(MaxV, UV[I].Y);
  end;
  SetLength(HUV, Length(FD.Doc[Face].Holes));
  for H := 0 to High(HUV) do
  begin
    SetLength(HUV[H], Length(FD.Doc[Face].Holes[H]));
    for I := 0 to High(HUV[H]) do
    begin
      P := P3(FD.Doc[Face].Holes[H][I].X - O.X, FD.Doc[Face].Holes[H][I].Y - O.Y,
              FD.Doc[Face].Holes[H][I].Z - O.Z);
      HUV[H][I] := PtF(Dot3(P, AU), Dot3(P, AV));
    end;
  end;

  { how big a screen pixel is in the plane, so the hatch keeps its density
    whatever the zoom - a unit vector along AU projects to Ppx pixels }
  SA := ScreenOf(O);
  SB := ScreenOf(P3(O.X + AU.X, O.Y + AU.Y, O.Z + AU.Z));
  Ppx := Sqrt(Sqr(SB.X - SA.X) + Sqr(SB.Y - SA.Y));
  if Ppx < 1E-6 then Exit;
  StepW := STEP_PX * FUIScale / Ppx;
  PieceW := PIECE_PX * FUIScale / Ppx;

  C.Pen.Style := psSolid;
  C.Pen.Color := PixToColor(Col);
  C.Pen.Width := 1;

  { diagonals across the bounding box; each is walked in pieces }
  Diag := (MaxU - MinU) + (MaxV - MinV);
  Steps := Ceil(Diag / StepW);
  if Steps > 400 then Exit;          // a face the size of the screen at 1:1
  for I := 0 to Steps do
  begin
    { the line u + v = MinU + MinV + I*StepW, clipped to the box }
    T0 := MinU + MinV + I * StepW;
    U0 := Max(MinU, T0 - MaxV);  V0 := T0 - U0;
    T1 := Min(MaxU, T0 - MinV);
    if T1 <= U0 then Continue;
    DU := 1; DV := -1;
    Len := (T1 - U0) * Sqrt(2);
    Pieces := Max(1, Ceil(Len / PieceW));
    for J := 0 to Pieces - 1 do
    begin
      A := U0 + (T1 - U0) * J / Pieces;
      B := U0 + (T1 - U0) * (J + 1) / Pieces;
      { the middle of the piece decides for the whole piece }
      if not InFace((A + B) / 2, V0 - ((A + B) / 2 - U0)) then Continue;
      P := P3(O.X + AU.X * ((A + B) / 2) + AV.X * (V0 - ((A + B) / 2 - U0)),
              O.Y + AU.Y * ((A + B) / 2) + AV.Y * (V0 - ((A + B) / 2 - U0)),
              O.Z + AU.Z * ((A + B) / 2) + AV.Z * (V0 - ((A + B) / 2 - U0)));
      if not Seen(P) then Continue;
      SA := ScreenOf(P3(O.X + AU.X * A + AV.X * (V0 - (A - U0)),
                        O.Y + AU.Y * A + AV.Y * (V0 - (A - U0)),
                        O.Z + AU.Z * A + AV.Z * (V0 - (A - U0))));
      SB := ScreenOf(P3(O.X + AU.X * B + AV.X * (V0 - (B - U0)),
                        O.Y + AU.Y * B + AV.Y * (V0 - (B - U0)),
                        O.Z + AU.Z * B + AV.Z * (V0 - (B - U0))));
      C.MoveTo(Round(SA.X), Round(SA.Y));
      C.LineTo(Round(SB.X), Round(SB.Y));
    end;
  end;
end;

{ The plane you locked, drawn where you are working.

  What was asked for was the rubber band to take the color of the plane so you can
  see you are still drawing flat.  We tried that once and it is written down
  in Rubber why it came out: a plane is named by the axis it **faces**, and
  that is the one axis a line lying in it can never run along.  Stood up on
  XZ, an outline would be drawn green, when every side of it runs red or
  blue.  It is not a near miss, it is the one color the line has no claim
  to.

  But the thing he actually needs to see is real, and a single line cannot
  carry it: one segment tells you one direction, and a plane takes two.
  Which is exactly why a rectangle already reads correctly - its sides come
  out red and blue and you know at a glance you are on XZ.

  So the plane says it itself.  Two short lines through the point, along the
  plane's own two directions, in their own axis colors.  Red and blue means
  upright; red and green means flat.  The same color language as everything
  else, saying the thing the rubber band cannot. }
procedure TMainForm.PaintHeldPlane(C: TCanvas);
const
  ARM = 46;
var
  AU, AV, P: TP3;
  I: Integer;
  D: TP3;
  S0, S1: TPointF;
  Sc: Double;
begin
  if not FPlaneHeld then Exit;
  if FD.Plane = plFree then Exit;
  if FD.View <> vkOrbit then Exit;   { flat views say it by being flat }
  PlaneAxes(FD.Plane, AU, AV);
  if FStage > 0 then P := FP1 else P := FCur;
  { a fixed length on the screen rather than in the model, so it is the same
    cue at any zoom }
  Sc := ARM * FUIScale / Max(1E-6, Ppu);
  C.Pen.Style := psSolid;
  C.Pen.Width := 1;
  for I := 0 to 1 do
  begin
    if I = 0 then D := AU else D := AV;
    C.Pen.Color := PixToColor(AxisPix(AxisAlong(P3(0, 0, 0), D)));
    S0 := ScreenOf(P3(P.X - D.X * Sc, P.Y - D.Y * Sc, P.Z - D.Z * Sc));
    S1 := ScreenOf(P3(P.X + D.X * Sc, P.Y + D.Y * Sc, P.Z + D.Z * Sc));
    C.MoveTo(Round(S0.X), Round(S0.Y));
    C.LineTo(Round(S1.X), Round(S1.Y));
  end;
end;

{ An entity's outline, traced heavily in one color.

  Said four times over: the selection in blue, the edge the dimension tool
  would take, what the eraser has gathered, and what it is hovering.  They are
  the same drawing with a different color, and each copy carried its own pen
  width and its own loop - so a change to how a highlight looks meant finding
  all four. }
{ The outline of an entity, only where it can be seen.

  SketchUp's hover and selection do not show through faces, and neither do
  these now: each piece of the outline is sampled against the faces in front
  of it and drawn where nothing covers it.  The whole line used to be traced
  through everything, which lit up the far half of an edge behind a wall. }
{ The guide under the cursor, said in blue along its own dashes.

  A guide point is a small thing and takes a ring round it; a guide line
  runs off both edges of the window, so it is drawn as the line it is,
  clipped to the window, in the same dash pattern it already has. }
procedure TMainForm.PaintGuideHover(C: TCanvas; I: Integer);
var
  E: TWorkEnt;
  D: TP3;
  L: Double;
  PA, PB: TPointF;
  R: Integer;
begin
  if (I < 0) or (I >= FD.Doc.Live) or (FD.Doc[I].Kind <> ekGuide) then Exit;
  E := FD.Doc[I];
  C.Brush.Style := bsClear;
  C.Pen.Color := PixToColor(Pix(60, 120, 235));
  C.Pen.Width := Max(1, Round(FUIScale));
  if Dist(E.A, E.B) < 1E-9 then
  begin
    { a guide point: a ring round it, the size it is drawn }
    PA := ScreenOf(E.A);
    if IsNan(PA.X) or IsNan(PA.Y) then Exit;
    R := Max(4, Round(5 * FUIScale));
    C.Pen.Style := psSolid;
    C.Ellipse(Round(PA.X) - R, Round(PA.Y) - R, Round(PA.X) + R, Round(PA.Y) + R);
    Exit;
  end;
  D := P3(E.B.X - E.A.X, E.B.Y - E.A.Y, E.B.Z - E.A.Z);
  L := Sqrt(Sqr(D.X) + Sqr(D.Y) + Sqr(D.Z));
  if L < 1E-9 then Exit;
  PA := ScreenOf(P3(E.A.X - D.X / L * 5000, E.A.Y - D.Y / L * 5000,
                    E.A.Z - D.Z / L * 5000));
  PB := ScreenOf(P3(E.A.X + D.X / L * 5000, E.A.Y + D.Y / L * 5000,
                    E.A.Z + D.Z / L * 5000));
  if IsNan(PA.X) or IsNan(PA.Y) or IsNan(PB.X) or IsNan(PB.Y) or
     IsInfinite(PA.X) or IsInfinite(PA.Y) or IsInfinite(PB.X) or IsInfinite(PB.Y) then Exit;
  { the canvas is asked for whole numbers, and a coordinate five thousand
    feet away does not fit one }
  PA := PtF(EnsureRange(PA.X, -32000, 32000), EnsureRange(PA.Y, -32000, 32000));
  PB := PtF(EnsureRange(PB.X, -32000, 32000), EnsureRange(PB.Y, -32000, 32000));
  C.Pen.Style := psDash;
  C.MoveTo(Round(PA.X), Round(PA.Y));
  C.LineTo(Round(PB.X), Round(PB.Y));
  C.Pen.Style := psSolid;
end;

{ The same trace as TraceOutlineVisible, into one of our own surfaces rather
  than onto an LCL canvas.  See the note in EnsureSelLayer for why that is
  the difference between a frame and two seconds. }
procedure TMainForm.TraceOutlineInto(S: TArtSurface; Idx: Integer;
  const Col: TPix; PenW: Single);
const
  N = 24;
var
  W: TP3Array;
  I, K, Run0: Integer;
  A, B: TP3;
  PA, PB: TPointF;
  Vis: Boolean;
  T0, T1: Double;

  function Edge(TVis, TCov: Double): Double;
  var
    J: Integer;
    TM: Double;
  begin
    for J := 1 to 5 do
    begin
      TM := (TVis + TCov) / 2;
      if FD.Doc.HiddenAt(Proj, Lerp3(A, B, TM)) then TCov := TM else TVis := TM;
    end;
    Result := (TVis + TCov) / 2;
  end;

begin
  if (Idx < 0) or (Idx >= FD.Doc.Live) then Exit;
  { a guide runs to the edges of the paper, so it is drawn the way it is
    drawn rather than as the stub it is stored as - and never hidden }
  if (FD.Doc[Idx].Kind = ekGuide) and
     (Dist(FD.Doc[Idx].A, FD.Doc[Idx].B) > 1E-9) then
  begin
    PA := ScreenOf(FD.Doc[Idx].A);
    PB := ScreenOf(FD.Doc[Idx].B);
    if ClipToBox(PA.X, PA.Y, PB.X - PA.X, PB.Y - PA.Y,
                 S.Width, S.Height, T0, T1) then
      S.Line(PA.X + (PB.X - PA.X) * T0, PA.Y + (PB.Y - PA.Y) * T0,
             PA.X + (PB.X - PA.X) * T1, PA.Y + (PB.Y - PA.Y) * T1,
             PenW, Col, 1.0);
    Exit;
  end;

  W := FD.Doc.OutlineWorld(Idx);
  if Length(W) < 2 then Exit;
  T0 := 0;
  for I := 0 to High(W) - 1 do
  begin
    A := W[I];
    B := W[I + 1];
    Run0 := -1;
    for K := 0 to N do
    begin
      if K < N then Vis := not FD.Doc.HiddenAt(Proj, Lerp3(A, B, (K + 0.5) / N))
      else Vis := False;
      if Vis and (Run0 < 0) then
      begin
        Run0 := K;
        if K = 0 then T0 := 0 else T0 := Edge((K + 0.5) / N, (K - 0.5) / N);
      end;
      if (not Vis) and (Run0 >= 0) then
      begin
        if K = N then T1 := 1 else T1 := Edge((K - 0.5) / N, (K + 0.5) / N);
        PA := ScreenOf(Lerp3(A, B, T0));
        PB := ScreenOf(Lerp3(A, B, T1));
        S.Line(PA.X, PA.Y, PB.X, PB.Y, PenW, Col, 1.0);
        Run0 := -1;
      end;
    end;
  end;
end;

procedure TMainForm.TraceOutlineVisible(C: TCanvas; Idx: Integer; const Col: TPix;
  PenW: Integer);
const
  N = 24;
var
  W: TP3Array;
  I, K, Run0: Integer;
  A, B: TP3;
  PA, PB: TPointF;
  Vis: Boolean;
  T0, T1: Double;

  function Edge(TVis, TCov: Double): Double;
  var
    J: Integer;
    TM: Double;
  begin
    for J := 1 to 5 do
    begin
      TM := (TVis + TCov) / 2;
      if FD.Doc.HiddenAt(Proj, Lerp3(A, B, TM)) then TCov := TM else TVis := TM;
    end;
    Result := (TVis + TCov) / 2;
  end;

begin
  { A guide is drawn to the edges of the paper and stored as a stub.

    The renderer walks dashes out from the point in both directions until it
    has crossed the screen, so what you see is a line without ends.  What is
    kept in the drawing is the point and one unit of direction - and this
    traced that, so picking a guide drew a blue line one foot long, starting
    nowhere anybody could see and stopping nowhere either.

    From a note, 15 September, on a picture of two of them: "those lines are not
    actually there in this drawing... the 2 blue lines sticking out of the
    rectangle.. wtf."  They were there - they were the guides he had picked,
    highlighted at the length they are stored at rather than the length they
    are drawn at.  Four ways of extending a guide already existed in this
    program, at 2000x, 5000x, a screen and a half, and not at all; this is
    the fourth one agreeing with the first three.

    No hidden test on the way: the renderer draws guides with the annotation,
    before the faces, so a guide is never hidden by geometry and asking would
    only sample a ten-thousand-foot line twenty-four times for no answer. }
  if (FD.Doc[Idx].Kind = ekGuide) and
     (Dist(FD.Doc[Idx].A, FD.Doc[Idx].B) > 1E-9) then
  begin
    PA := ScreenOf(FD.Doc[Idx].A);
    PB := ScreenOf(FD.Doc[Idx].B);
    if ClipToBox(PA.X, PA.Y, PB.X - PA.X, PB.Y - PA.Y,
                 pbScreen.Width, pbScreen.Height, T0, T1) then
    begin
      C.Pen.Color := PixToColor(Col);
      C.Pen.Width := PenW;
      C.Pen.Style := psSolid;
      C.MoveTo(Round(PA.X + (PB.X - PA.X) * T0),
               Round(PA.Y + (PB.Y - PA.Y) * T0));
      C.LineTo(Round(PA.X + (PB.X - PA.X) * T1),
               Round(PA.Y + (PB.Y - PA.Y) * T1));
      C.Pen.Width := 1;
    end;
    Exit;
  end;

  W := FD.Doc.OutlineWorld(Idx);
  if Length(W) < 2 then Exit;
  C.Pen.Color := PixToColor(Col);
  C.Pen.Width := PenW;
  C.Pen.Style := psSolid;
  T0 := 0;
  for I := 0 to High(W) - 1 do
  begin
    A := W[I];
    B := W[I + 1];
    Run0 := -1;
    for K := 0 to N do
    begin
      if K < N then Vis := not FD.Doc.HiddenAt(Proj, Lerp3(A, B, (K + 0.5) / N))
      else Vis := False;
      if Vis and (Run0 < 0) then
      begin
        Run0 := K;
        if K = 0 then T0 := 0 else T0 := Edge((K + 0.5) / N, (K - 0.5) / N);
      end;
      if (not Vis) and (Run0 >= 0) then
      begin
        if K = N then T1 := 1 else T1 := Edge((K - 0.5) / N, (K + 0.5) / N);
        PA := ScreenOf(Lerp3(A, B, T0));
        PB := ScreenOf(Lerp3(A, B, T1));
        C.MoveTo(Round(PA.X), Round(PA.Y));
        C.LineTo(Round(PB.X), Round(PB.Y));
        Run0 := -1;
      end;
    end;
  end;
  C.Pen.Width := 1;
end;

procedure TMainForm.TraceOutline(C: TCanvas; const Hi: TPointFArray;
  const Col: TPix);
var
  I: Integer;
begin
  if Length(Hi) < 2 then Exit;
  C.Pen.Color := PixToColor(Col);
  C.Pen.Width := Max(3, Round(3 * FUIScale));
  C.Pen.Style := psSolid;
  C.MoveTo(Round(Hi[0].X), Round(Hi[0].Y));
  for I := 1 to High(Hi) do
    C.LineTo(Round(Hi[I].X), Round(Hi[I].Y));
  C.Pen.Width := 1;
end;

procedure TMainForm.PaintProOverlay(C: TCanvas);
var
  ArcFil: TFillet;
  ArcTyped: Boolean;
  ArcPl: TPlane;
  ArcC, ArcU, ArcV, ArcMid, ArcFoot: TP3;
  ArcR, ArcA0, ArcSw, ArcBulge, U1, V1, U2, V2, Ln: Double;
  PA, PB: TPointF;
  ArcK: Integer;
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
  S1, S2, S3, S4, HTx: string;
  W1, W2, W3, W4, BoxW, BoxH, LnH, HL, HLn: Integer;
  StrainPts: TPointFArray;
  GrpBoxes: TIntArrayW;
  GI, GrpId: Integer;

  { When the cursor is locked to an axis the band is drawn in that axis's
    color, so the direction you are committing to is readable without
    looking away at the chip. }
  { a small red square on a point that has been picked, SketchUp's mark }
  procedure EndMark(const P: TP3);
  var
    Q: TPointF;
    D: Integer;
  begin
    Q := ScreenOf(P);
    D := Round(3 * FUIScale);
    C.Pen.Width := 1;
    C.Pen.Color := PixToColor(Pix(235, 70, 70));
    C.Brush.Style := bsSolid;
    C.Brush.Color := PixToColor(Pix(255, 150, 150));
    C.Rectangle(Round(Q.X) - D, Round(Q.Y) - D, Round(Q.X) + D + 1, Round(Q.Y) + D + 1);
    C.Brush.Style := bsClear;
  end;

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
    { Only while an axis is something the cursor is actually allowed to
      infer.  From a note, by report, 18 September: "this red line seems to snap on
      the red axis which is fine but it seems to be snapping red in multiple
      positions so something may not be right" - and the bar in his picture
      said, at the same moment, "the points only - no axis, nothing
      parallel".  Alt had turned the axis inferences off and the band was
      still going red whenever the line happened to lie along red.

      The color IS the inference: red means "I am holding you on red".
      Saying it while holding nothing is a lie, and a convincing one - it
      reads as a snap that keeps coming and going.  An axis the arrows have
      locked is different; that one is held whatever Alt says. }
    if FAxisLock in [0..2] then Ax := FAxisLock
    else if FInferMode = imAll then Ax := AxisAlong(A, B)
    else Ax := -1;
    { Parallel or square to an edge is magenta, which is the color SketchUp
      gives that pair - and it is not an axis color, so it cannot be read
      as one. }
    if FParPerp > 0 then
      C.Pen.Color := PixToColor(Pix($C8, $3C, $C8))
    else if Ax >= 0 then
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
    tool that has something in progress, not only for a run of lines.  the
    observation, and it is the right one: you know you have made a mess the
    instant the button goes down, and the fix should be to keep leaning on it
    rather than to finish the shape, find the eraser, and pick it off again.

    While it is straining the shape's own preview is replaced by the strain,
    so there is one thing happening on screen rather than two. }
  if FHoldOn and (FHoldT > HOLD_STRAIN) and (FStage >= 1) then
  begin
    if StrainOutline(StrainPts) then
      PaintStrainPath(C, StrainPts,
        (FHoldT - HOLD_STRAIN) / (HOLD_BREAK - HOLD_STRAIN));
    PaintSnapRecoil(C);
    Exit;
  end;

  case FTool of
    ptLine:
      begin
        PaintHeldPlane(C);
        if FStage = 1 then Rubber(FP1, PreviewTarget);
      end;
    ptRect:
      begin
        { Before the first corner as well as after it.  Flipping between the
          planes and not being sure which one you were about to get is what
          It was reported; the two colored lines say it while there is still
          nothing drawn. }
        PaintHeldPlane(C);
        if FStage = 1 then
        begin
          RectPrev := RectCorners(FP1, RectTarget, FD.Plane);
          for RectI := 0 to 3 do
            Rubber(RectPrev[RectI], RectPrev[(RectI + 1) mod 4]);
        end;
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
        { What SketchUp shows, because it is what you need to see: the two
          ends marked, the chord, the pull from the chord's middle drawn in
          the color of the axis it runs along - blue when it goes straight up
          a wall - and the arc itself where it will land.  Before this it was
          two rubber bands to the cursor, which said nothing about the plane,
          so an arc that had dropped onto the ground looked the same as one
          standing on the wall until it was drawn. }
        if FStage = 1 then
        begin
          Rubber(FP1, FCur);
          EndMark(FP1);
        end
        else if (FStage = 2) and ArcFillet(ArcFil, ArcTyped) then
        begin
          { Magenta, SketchUp's color for "tangent to edge", and drawn where
            it will really land - the second end moved to match the first,
            which is why it can jump when it locks. }
          Rubber(ArcFil.Corner, ArcFil.S);
          Rubber(ArcFil.Corner, ArcFil.E);
          C.Pen.Style := psSolid;
          C.Pen.Width := Max(3, Round(3 * FUIScale));
          C.Pen.Color := PixToColor(Pix(225, 40, 225));
          PA := ScreenOf(ArcPoint(ArcFil.ArcC, ArcFil.R, ArcFil.A0,
            ArcFil.Pl, ArcFil.Nm));
          C.MoveTo(Round(PA.X), Round(PA.Y));
          for ArcK := 1 to FSidesArc do
          begin
            PB := ScreenOf(ArcPoint(ArcFil.ArcC, ArcFil.R,
              ArcFil.A0 + ArcFil.Sweep * ArcK / FSidesArc, ArcFil.Pl, ArcFil.Nm));
            C.LineTo(Round(PB.X), Round(PB.Y));
          end;
          C.Pen.Width := 1;
          EndMark(ArcFil.S);
          EndMark(ArcFil.E);
          { the words, below and to the right of the pointer - clear of the
            cursor's own square, which wipes whatever canvas text is inside
            it, and of the tool glyph above it }
          UIFont(C, 8, True, Pix(225, 40, 225));
          C.Brush.Style := bsClear;
          C.TextOut(FMouseSX + Round(24 * FUIScale), FMouseSY + Round(10 * FUIScale),
            'TANGENT TO EDGE');
        end
        else if FStage = 2 then
        begin
          if ArcPicks(FCur, ArcPl, ArcC, ArcR, ArcA0, ArcSw, ArcBulge) then
          begin
            PlaneAxes(ArcPl, ArcU, ArcV);
            PlaneCoords(ArcPl, FP1, U1, V1);
            PlaneCoords(ArcPl, FP2, U2, V2);
            Ln := Sqrt(Sqr(U2 - U1) + Sqr(V2 - V1));
            { the chord, thin }
            PA := ScreenOf(FP1);
            PB := ScreenOf(FP2);
            C.Pen.Style := psDash;
            C.Pen.Width := 1;
            C.Pen.Color := PixToColor(Theme.Accent);
            C.MoveTo(Round(PA.X), Round(PA.Y));
            C.LineTo(Round(PB.X), Round(PB.Y));
            C.Pen.Style := psSolid;
            { the pull, from the chord's middle, in its axis color }
            ArcMid := P3((FP1.X + FP2.X) / 2, (FP1.Y + FP2.Y) / 2, (FP1.Z + FP2.Z) / 2);
            ArcFoot := P3(
              ArcMid.X + (ArcU.X * (-(V2 - V1) / Ln) + ArcV.X * ((U2 - U1) / Ln)) * ArcBulge,
              ArcMid.Y + (ArcU.Y * (-(V2 - V1) / Ln) + ArcV.Y * ((U2 - U1) / Ln)) * ArcBulge,
              ArcMid.Z + (ArcU.Z * (-(V2 - V1) / Ln) + ArcV.Z * ((U2 - U1) / Ln)) * ArcBulge);
            Rubber(ArcMid, ArcFoot);
            { the arc, where it will land }
            C.Pen.Width := Max(2, Round(2 * FUIScale));
            C.Pen.Color := PixToColor(Theme.Accent);
            PA := ScreenOf(ArcPoint(ArcC, ArcR, ArcA0, ArcPl));
            C.MoveTo(Round(PA.X), Round(PA.Y));
            for ArcK := 1 to FSidesArc do
            begin
              PB := ScreenOf(ArcPoint(ArcC, ArcR, ArcA0 + ArcSw * ArcK / FSidesArc, ArcPl));
              C.LineTo(Round(PB.X), Round(PB.Y));
            end;
            C.Pen.Width := 1;
          end
          else
            Rubber(FP1, FP2);
          EndMark(FP1);
          EndMark(FP2);
        end;
      end;
    ptCircle:
      begin
        PaintHeldPlane(C);
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
          for CircI := 1 to FSidesCircle do
          begin
            P := ScreenOf(ArcPoint(FP1, CircR, CircI * 2 * Pi / FSidesCircle, FD.Plane));
            C.MoveTo(Round(PPrev.X), Round(PPrev.Y));
            C.LineTo(Round(P.X), Round(P.Y));
            PPrev := P;
          end;
        end;
        C.Pen.Width := 1;
      end;
      end;
    ptMeasure:
      if FStage = 1 then
      begin
        Rubber(FP1, FCur);
        { the whole reading follows the cursor, angles and all, so a run can
          be checked for level without letting go of it }
        FCmdMsg := RunReading(FP1, FCur);
        { the running length beside the cursor, far enough off it to read
          while you are dragging - a tape you have to look away from to read
          is no use for a quick check }
        S1 := FormatLen(Dist(FP1, FCur), FD.Units);
        UIFont(C, 11, True, AnnotColor);
        C.Brush.Style := bsSolid;
        C.Brush.Color := PixToColor(Theme.Screen1);
        C.TextOut(SX + Round(22 * FUIScale), SY - Round(30 * FUIScale), S1);
        C.Brush.Style := bsClear;
      end;
    ptDim:
      if FStage = 1 then Rubber(FP1, FCur)
      else if FStage = 2 then PaintDimPreview(C);

    ptPush, ptDrill:
      if FStage = 1 then
      begin
        PaintFaceHint(C, FPushFace, HINT_BLUE);
        PaintPushPreview(C);
      end
      else
        PaintFaceHint(C, FHoverFace, HINT_BLUE);
    ptFollow:
      if FStage = 0 then PaintFaceHint(C, FHoverFace, HINT_BLUE)
      else
      begin
        PaintFaceHint(C, FFollowFace, HINT_BLUE);
        if FStage = 2 then PaintRevolvePreview(C);
      end;
    ptMove:
      if FDimMove >= 0 then PaintDimPreview(C) else PaintMoveGhost(C);
    ptRotate, ptProtractor: PaintRotateGhost(C);
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
    HintFace := InContextFace(FD.Doc.HitFace(Proj, FMouseSX, FMouseSY));
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
    Format('%s   (view %s)', [S1, ZoomReading]));

  { --- where a solid is not closed ------------------------------------- }
  { Laid over everything, in the color of a warning, because the question
    somebody has when a slicer refuses their model is not "is it open" - the
    export already answers that - but "where".  Dropped the moment the
    drawing changes: an answer about geometry that has been edited since is
    worse than no answer at all. }
  if (Length(FOpenEdges) >= 2) and (FOpenSeq = FEditSeq) then
  begin
    C.Pen.Width := Max(3, Round(3 * FUIScale));
    C.Pen.Color := PixToColor(Pix(235, 60, 60));
    AY := 0;
    while AY + 1 <= High(FOpenEdges) do
    begin
      PA := ScreenOf(FOpenEdges[AY]);
      PB := ScreenOf(FOpenEdges[AY + 1]);
      C.MoveTo(Round(PA.X), Round(PA.Y));
      C.LineTo(Round(PB.X), Round(PB.Y));
      Inc(AY, 2);
    end;
    C.Pen.Width := 1;
  end;

  { --- what is selected ------------------------------------------------ }
  { Already on screen: pbScreenPaint composited the layer EnsureSelLayer
    drew it into.  Nothing to do here at all, which is the point. }

  { the edge the dimension tool would take }
  { The one edge a click would take.

    An arc is lit by its outline, because the thing being taken is a curve
    and a straight line across it would be a lie about what you are about to
    measure.  Everything else is lit as the segment itself - which for a line
    is the same thing its outline would give, and for one side of a face's
    outline is the only right answer: lighting the entity there would light
    the whole face. }
  if (FTool = ptDim) and (FStage = 0) and (FHoverEnt >= 0) then
  begin
    if FD.Doc[FHoverEnt].Kind = ekArc then
    begin
      Hi := FD.Doc.Outline(Proj, FHoverEnt);
      if Length(Hi) >= 2 then TraceOutline(C, Hi, HINT_BLUE);
    end
    else if FHoverEdgeOK then
    begin
      SetLength(Hi, 2);
      Hi[0] := ScreenOf(FHoverEdgeA);
      Hi[1] := ScreenOf(FHoverEdgeB);
      TraceOutline(C, Hi, HINT_BLUE);
    end;
  end;

  { what a click would take, so a pick can be aimed before committing }
  if (FTool in [ptSelect, ptMove, ptRotate]) and (FHoverEnt >= 0) and
     not IsSelected(FHoverEnt) then
  begin
    { A guide says so by changing color, not by being outlined.  The owner, 17
      September: "it just changes the color of the dash line to blue... not a
      thick blue highlight like we do".  It is construction, and a band of
      blue laid over the drawing to say the cursor is near a dashed line is
      louder than the thing it is pointing at. }
    if FD.Doc[FHoverEnt].Kind = ekGuide then
      PaintGuideHover(C, FHoverEnt)
    else if FD.Doc.TopPartIn(FHoverEnt) > 0 then
    begin
      { a group is its box - red when it is locked, SketchUp's cue for it }
      GrpId := FD.Doc.TopPartIn(FHoverEnt);
      if FD.Doc.PartLockedUp(GrpId) then
        PaintPartBox(C, GrpId, Pix(230, 80, 80), False, P3(0, 0, 0))
      else
        PaintPartBox(C, GrpId, Pix(150, 185, 245), False, P3(0, 0, 0));
    end
    else
      TraceOutlineVisible(C, FHoverEnt, Pix(150, 185, 245), Max(2, Round(2 * FUIScale)));
  end;

  { the groups picked, each as its box, and the one that is open as a dotted
    box round everything you are working inside }
  GrpBoxes := SelectedGroups;
  for GI := 0 to High(GrpBoxes) do
    if FD.Doc.PartLockedUp(GrpBoxes[GI]) then
      PaintPartBox(C, GrpBoxes[GI], Pix(230, 80, 80), False, P3(0, 0, 0))
    else
      PaintPartBox(C, GrpBoxes[GI], Pix(70, 130, 240), False, P3(0, 0, 0));
  if FD.Doc.Context <> 0 then
    PaintPartBox(C, FD.Doc.Context, Pix(130, 130, 140), True, P3(0, 0, 0));
  { and every locked group in reach shows its crate faintly all the time: a
    locked group is what you draw against, and the crate is what you snap
    to - its corners, edge middles and centers are in the snap points }
  for GI := 0 to FD.Doc.Live - 1 do
    if (FD.Doc[GI].Kind = ekPart) and (FD.Doc[GI].Part = FD.Doc.Context) and
       FD.Doc[GI].Solid and (FD.Doc.TopPartIn(GI) > 0) then
      PaintPartBox(C, FD.Doc[GI].Grp, Pix(240, 190, 190), True, P3(0, 0, 0));

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
      WashFace(C, FDoomed[AY], Pix(240, 60, 60));
    if Length(Hi) >= 2 then
    begin
      TraceOutline(C, Hi, Pix(240, 60, 60));
    end;
  end;

  if (FTool = ptErase) and (FHoverEnt >= 0) and not FErasing2 then
  begin
    Hi := FD.Doc.Outline(Proj, FHoverEnt);
    { A whole panel is a lot to lose to a click, so when the eraser has locked
      onto one it says so across the face rather than round its edge. }
    if (Length(Hi) >= 3) and (FD.Doc[FHoverEnt].Kind = ekFace) then
      WashFace(C, FHoverEnt, Pix(230, 70, 70));
    if Length(Hi) >= 2 then
    begin
      TraceOutline(C, Hi, Pix(230, 70, 70));
    end
    else if Length(Hi) = 1 then
    begin
      C.Pen.Color := PixToColor(Pix(230, 70, 70));
      C.Brush.Style := bsClear;
      C.Ellipse(Round(Hi[0].X) - 7, Round(Hi[0].Y) - 7,
                Round(Hi[0].X) + 7, Round(Hi[0].Y) + 7);
    end;
  end;

  { --- parallel or square to an edge, in magenta like SketchUp ---------- }
  if FParPerp > 0 then
  begin
    GP := ScreenOf(FAxisFrom);
    C.Pen.Style := psDot;
    C.Pen.Color := PixToColor(Pix($C8, $3C, $C8));
    C.Pen.Width := Max(1, Round(FUIScale));
    C.MoveTo(Round(GP.X), Round(GP.Y));
    C.LineTo(SX + Round((SX - GP.X) * 0.18), SY + Round((SY - GP.Y) * 0.18));
    C.Pen.Style := psSolid;
    C.Pen.Width := 1;
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

  { The point being held as a reference used to wear a ring here.  SketchUp
    draws nothing on the held point itself - only the dotted guide running
    from it, which is drawn above - and the ring read as a mark left
    behind.  Gone, 21 September. }


  { --- the view cube ---------------------------------------------------- }
  PaintViewCube(C);
  PaintCompass(C);

  { --- the action chip beside the cursor --------------------------------

    Not while the pointer is on the cube's patch.  The chip is drawn AT the
    cursor, so hovering the cube put a card of text over the thing being
    aimed at - worst exactly on the left-hand edges, where the chip opens to
    the right and lands squarely on the cube. }
  if CubeZone(FMouseSX, FMouseSY) then Exit;
  if FErasing then Exit;
  S1 := SnapLabel;
  { picking for the text: the chip says so, and which part of the line
    the next click is for }
  if FTextPick and (SourceForm <> nil) then
  begin
    if S1 = '' then S1 := 'FREE';
    S1 := 'PICKING  ' + S1;
    S2 := 'click a point for ' + SourceForm.PickWants +
      '.  Arrows lock red, green, blue for a height; Esc stops';
  end
  else
  if FStage = 0 then
  begin
    if S1 = '' then S1 := 'FREE';
    case FTool of
      ptSelect: S2 := 'pick a tool below, or press L for a line';
      ptLine:
        { In a 3D view, say the one thing that is not guessable and is the
          difference between an outline that closes and one that does not:
          the arrows lock the plane you are drawing on before you start. }
        if (FD.View = vkOrbit) and (FStage = 0) and not FPlaneHeld then
          S2 := 'click to start - arrows lock a flat plane first: left upright, right side-on'
        else
          S2 := 'click to start - then type 12, 12''6 or 6-8-15';
      ptRect:   S2 := 'click a corner - then drag, or type 8x10';
      ptCircle: S2 := Format('click the center - %d sides: + - or type 24s', [FSidesCircle]);
      ptArc:    S2 := Format('click one end - %d segments: + - or type 12s', [FSidesArc]);
      ptPush:   S2 := 'click a face - then type how far, or rest on an edge';
      ptDrill:  S2 := 'click a face - it goes through whatever it crosses; type a depth to stop short';
      ptFollow: S2 := 'click the outline to spin - the half of the shape, seen edge on';
      ptErase:  S2 := 'click an edge to delete it - or hold and drag across ' +
                      'several.  Ctrl softens instead, Ctrl+Shift brings back';
      ptText:   S2 := 'space or click - the note points here';
      ptMove:   S2 := 'grab a point on what you are moving - Ctrl leaves a copy';
      ptOffset: S2 := 'click a face - then type the offset, negative goes inward';
      ptMeasure:
        { short, because the line above it is narrow - the mode is said in
          full on every Ctrl and after every measurement, which is where
          somebody is actually looking }
        S2 := 'measure from here - Ctrl says what it leaves behind';
      ptDim:    S2 := 'click a corner, then another - or the body of an edge for all of it';
      ptRotate: S2 := 'click the center - nothing picked turns all that is joined; arrows pick the plane';
      ptProtractor: S2 := 'click the vertex - arrows pick the plane by color';
      ptOrbit:  S2 := 'drag to spin - Shift pans, Ctrl snaps to a view';
    else
      S2 := 'space or click - start here';
    end;
  end
  else
  begin
    if S1 = '' then S1 := 'DRAWING';
    case FTool of
      ptPush, ptDrill: S2 := 'type how far - 2, 6", 1-6 - or rest on an edge or a face';
      ptFollow:
        if FStage = 2 then
          S2 := 'the ring shows what it will sweep - red means the axis cuts the outline'
        else
          S2 := 'click the straight side that is the middle of the shape';
      ptCircle: S2 := Format('type a radius, or click - %d sides: + - or 24s', [FSidesCircle]);
      ptArc:    S2 := Format('pull the middle out, or type the bulge - %d segments: + - or 12s', [FSidesArc]);
      ptText:   S2 := 'type it, move away, then Enter - Shift+Enter for a new line';
      ptDim:    S2 := 'move away to place it - shake up and down to stand it up';
      ptMeasure:
        S2 := 'click the second point, or type a distance - 3, 2''6, 0-8-8';
      ptRect:   S2 := 'drag it, or type 8x10, 8/10 or 2''6x4 - a minus flips a side';
      ptMove:   S2 := 'type a length, [x,y,z] or <x,y,z> - Ctrl copies, then 3x or /3 for an array';
      ptOffset: S2 := 'type the offset - 6", 1-6 - negative goes inward';
      ptRotate, ptProtractor:
        if FStage = 1 then S2 := 'click a point to measure the angle from'
        else S2 := 'swing to the angle and click, or type it - 45, 22.5, or 8:12';
    else
      S2 := 'type a length - 12, 12''6, 6-8-15 - arrows lock an axis';
    end;
  end;

  { and the keys that would do something, under the two lines - the card
    beside the pointer is where somebody is looking, so it is where the
    modifiers belong as well as along the bottom }
  S3 := ShortKeys;
  { With the source window open, the thing under the pointer says which
    line of the text it is, and shows it - the drawing and its words as
    one thing.  Only then: the text behind a drawing is a thing to find
    later, not a thing to be met with. }
  S4 := '';
  if (SourceForm <> nil) and SourceForm.Visible and (FTool = ptSelect) then
  begin
    HL := FHoverEnt;
    if (HL < 0) and (FHoverFace >= 0) then HL := FHoverFace;
    if (HL >= 0) and SourceForm.LineOfThing(HL, HLn, HTx) then
    begin
      if Length(HTx) > 60 then HTx := Copy(HTx, 1, 57) + '...';
      S4 := Format('line %d:  %s', [HLn, HTx]);
    end;
  end;
  UIFont(C, 9, True, Theme.Text);
  LnH := C.TextHeight('Xg');
  W1 := C.TextWidth(S1);
  UIFont(C, 9, False, Theme.Text);
  W2 := C.TextWidth(S2);
  W3 := 0;
  if S3 <> '' then
  begin
    UIFont(C, 8, False, Theme.TextDim);
    W3 := C.TextWidth(S3);
  end;
  W4 := 0;
  if S4 <> '' then
  begin
    C.Font.Name := 'Courier New';
    C.Font.Pitch := fpFixed;
    UIFont(C, 8, False, Theme.Accent);
    C.Font.Name := 'Courier New';
    W4 := C.TextWidth(S4);
  end;
  BoxW := Max(Max(W1, W4), Max(W2, W3)) + Round(18 * FUIScale);
  BoxH := 2 * LnH + Round(14 * FUIScale);
  if S3 <> '' then Inc(BoxH, LnH);
  if S4 <> '' then Inc(BoxH, LnH);

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
  if S3 <> '' then
  begin
    UIFont(C, 8, False, Theme.TextDim);
    C.TextOut(R.Left + Round(9 * FUIScale),
      R.Top + Round(5 * FUIScale) + 2 * LnH, S3);
  end;
  if S4 <> '' then
  begin
    UIFont(C, 8, False, Theme.Accent);
    C.Font.Name := 'Courier New';
    C.Font.Pitch := fpFixed;
    HLn := 2;
    if S3 <> '' then HLn := 3;
    C.TextOut(R.Left + Round(9 * FUIScale),
      R.Top + Round(5 * FUIScale) + HLn * LnH, S4);
  end;
end;

{ A note beside the button the pointer is on.

  There have never been tooltips, and it took the owner hovering over the new tool
  strip to notice why: the hover text goes to `FHint`, which is painted in
  the **title bar**.  Seven hundred pixels from the pointer, in the smallest
  dim type on the window, and only when the form happens to repaint - so
  hovering a tool told you nothing, and looked like nothing was there,
  because nothing was.

  Drawn on the drawing canvas rather than as a window: the same black card
  with the accent title that the cursor already uses, so the two read as one
  idea, and no second widget to keep on top of anything.  Two lines - what it
  is, then what it does - because a name alone does not tell somebody who has
  never met Offset what Offset is, and telling them is the whole job. }
procedure TMainForm.PaintChromeTip(C: TCanvas);
var
  W1, W2, BoxW, BoxH, LnH, X, Y: Integer;
  R: TRect;
begin
  if FChromeTip = '' then Exit;
  UIFont(C, 9, True, Theme.Text);
  LnH := C.TextHeight('Xg');
  W1 := C.TextWidth(FChromeTip);
  UIFont(C, 9, False, Theme.Text);
  W2 := C.TextWidth(FChromeTipBody);
  BoxW := Max(W1, W2) + Round(18 * FUIScale);
  BoxH := 2 * LnH + Round(14 * FUIScale);

  { hard against the strip it came from, level with the button, and never off
    the bottom of the drawing }
  X := EnsureRange(FChromeTipX, 4, Max(4, pbScreen.Width - BoxW - 4));
  Y := EnsureRange(FChromeTipY - BoxH div 2, 4,
                   Max(4, pbScreen.Height - BoxH - 4));
  R := Rect(X, Y, X + BoxW, Y + BoxH);

  C.Brush.Style := bsSolid;
  C.Brush.Color := PixToColor(MixPix(Theme.Panel, Pix(0, 0, 0), 0.15));
  C.Pen.Color := PixToColor(Theme.Accent);
  C.Pen.Width := 1;
  C.RoundRect(R.Left, R.Top, R.Right, R.Bottom, Round(8 * FUIScale),
    Round(8 * FUIScale));
  UIFont(C, 9, True, Theme.Accent);
  C.TextOut(R.Left + Round(9 * FUIScale), R.Top + Round(5 * FUIScale), FChromeTip);
  UIFont(C, 9, False, Theme.Text);
  C.TextOut(R.Left + Round(9 * FUIScale), R.Top + Round(5 * FUIScale) + LnH,
    FChromeTipBody);
end;

procedure TMainForm.pbScreenPaint(Sender: TObject);
var
  Shown: TArtSurface;
  HF: Integer;
  HaveSel: Boolean;
  CR, Rad, SX, SY, Arm, Gap, I: Integer;
  Contrast, Halo, CPix: TPix;
  CW, CA: Double;
  CP: TPointF;
  TPaint, TAll: QWord;
begin
  if not FBooted then Exit;
  { a paint that comes before the tick draws the moved camera itself, so a
    frame is never shown for a view that is no longer the view }
  FlushView;
  TPaint := GetTickCount64;
  try
  if FErasing then
  begin
    pbScreen.Canvas.Brush.Style := bsSolid;
    pbScreen.Canvas.Brush.Color := PixToColor(Theme.Bezel2);
    pbScreen.Canvas.FillRect(0, 0, pbScreen.Width, pbScreen.Height);
  end;

  { What goes on the screen: the picture, with the selection over it and the
    wash on the face under the pointer, kept from the last paint unless one
    of the three has changed.  A paint that changes none of them - the window
    being uncovered, the cursor moving over the same face - is then the blit
    alone. }
  HF := -1;
  if (FMode = mdPro) and not FErasing and (FPopup = POP_NONE) then HF := HintFaceNow;
  HaveSel := (FMode = mdPro) and (Length(FSel) > 0) and not FErasing;
  if HaveSel then EnsureSelLayer;       { may say the shot is stale }
  if FShotOK and (HaveSel = FShotHadSel) and (HF = FHintInShot) then
  begin
    if HaveSel or (FHintInShot >= 0) then Shown := FSelShot else Shown := FArt;
  end
  else if not HaveSel and (HF < 0) then
  begin
    Shown := FArt;
    FHintInShot := -1;
    FShotHadSel := False;
    FShotOK := True;
  end
  else
  begin
    { one surface for both jobs: the selection composited over the picture,
      and the wash drawn into the same copy }
    if FSelShot = nil then FSelShot := TArtSurface.Create(FArt.Width, FArt.Height)
    else FSelShot.SetSize(FArt.Width, FArt.Height);
    if HaveSel then
      { The selection comes from its cached layer, composited over the
        picture - see EnsureSelLayer.  Every selection, not only a huge one:
        drawing it on the canvas instead cost the owner nearly two seconds a frame
        at twelve hundred things picked. }
      FSelShot.CompositeOver(FArt, FSelLayer, Rect(0, 0, FArt.Width, FArt.Height))
    else
      FSelShot.CopyRegion(FArt, 0, 0, 0, 0, FArt.Width, FArt.Height);
    if HF >= 0 then PaintFaceHint(nil, HF, HINT_BLUE, FSelShot, 0, 0);
    FHintInShot := HF;
    FShotHadSel := HaveSel;
    FShotOK := True;
    Shown := FSelShot;
  end;
  { The blue wash over the face being pointed at, drawn into the picture
    before it goes to the screen rather than onto the screen after it.

    It was written onto the canvas a dot at a time, and a dot on a canvas is
    a call into the platform each.  Zoomed in, the face is the whole window:
    measured at 25 ms a frame on a 919 x 471 window here, and the report
    from a 1694 x 769 Windows screen had frames of 60 to 94 ms standing
    still with the arc tool over a face.  Into a copy of the picture it is a
    row fill in memory, and the copy goes to the screen in the one blit it
    was going to have anyway. }
  Shown.DrawTo(pbScreen.Canvas, FJitterX, FJitterY);
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
  { from the picture actually shown, so the selection outline and the face
    wash are in the square too rather than wiped under the pointer }
  FOverlay.CopyRegion(Shown, SX - CR, SY - CR, 0, 0, CR * 2, CR * 2);
  { That square is the finished drawing, without the tool's preview in it -
    so pasting it back wipes whatever preview was within reach of the
    pointer.  Mostly that is the last few pixels of a rubber band, which
    nobody notices.  A fillet is different: the pointer sits right on the
    arc when it locks, and all that was left of it were two stubs at the
    ends.  So the fillet goes into the square first, under the crosshair. }
  if FMode = mdPro then PaintUnderCursor(FOverlay, SX - CR, SY - CR);

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
  { over the drawing, under nothing - a note about a button has to be
    readable whatever is behind it }
  PaintChromeTip(pbScreen.Canvas);
  PaintShotOverlay(pbScreen.Canvas);
  finally
    NoteFrame(GetTickCount64 - TPaint);
  end;
end;

{ The frame watchdog: one line in the session log for a frame that took too
  long, and a running count for the report to carry.

  What a frame is made of, and what each part is timed by: the paper
  (RepaintPaper), the ink (RenderPro), the composite of one over the other
  (RecomposeAll), and putting the result on the screen, which is the caller.
  The four are accumulated since the last paint, so a frame that rendered
  three times before it was shown counts all three - which is the frame the
  person actually waited for.

  Forty milliseconds is the line.  Twenty-five a second is where a drag stops
  feeling attached to the hand, and anything under it is not worth a line in
  a log thirty entries long.

  At most one line every two seconds, because a drag that is slow is slow for
  every frame of it and thirty identical lines would push everything else out
  of the log.  The count and the worst are kept whole and go into the report,
  so "it glitched for a while" arrives as a number. }
procedure TMainForm.NoteFrame(PaintMs: QWord);
const
  SLOW_MS = 40;
var
  Total, Now64: QWord;
begin
  Total := FMsPaper + FMsRender + FMsComp + PaintMs;
  if Total >= SLOW_MS then
  begin
    Inc(FSlowN);
    if Total > FSlowWorst then FSlowWorst := Total;
    FSlowLast := Format('%dms (paper %d, ink %d, over %d, screen %d) ' +
      '%s stage=%d sel=%d things=%d zoom=%.0f%%%s',
      [Total, FMsPaper, FMsRender, FMsComp, PaintMs,
       TOOL_NAMES[FTool], FStage, Length(FSel), FD.Doc.Live, FD.Zoom * 100,
       IfThen(FCameraMoving, ' moving', '')]);
    { and out loud with /timings on, so a slow frame can be chased at a
      terminal without sending a report to read it back }
    if FTimings then
    begin
      TimingLine('slow frame: ' + FSlowLast);
    end;
    Now64 := GetTickCount64;
    if Now64 - FSlowSaid >= 2000 then
    begin
      FSlowSaid := Now64;
      Trail('slow frame: ' + FSlowLast);
    end;
  end;
  FMsPaper := 0;
  FMsRender := 0;
  FMsComp := 0;
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
    is red, left is green, up is blue.  Left and right are the two upright
    planes; up is the ground.

    Down used to let go again, and the owner read the set as not quite intuitive.
    He is right about the shape of it: up and down are one gesture and they
    should mean one thing, which is flat - the way up and down mean flat on
    a table.  Esc has always let go as well, and says so in every message
    the plane puts up, so nothing is lost by giving down to the ground and
    everything is gained by the pair reading as a pair. }
  case Key of
    VK_RIGHT: FD.Plane := plYZ;     // normal is red, X
    VK_LEFT: FD.Plane := plXZ;      // normal is green, Y
  else
    FD.Plane := plXY;               // up or down: normal is blue, Z
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
  Act('tool ' + TOOL_NAMES[T]);
  FArray.Live := False;
  { Push/pull along a face normal that points at the camera can only move the
    face away from you, which plan cannot draw and you cannot judge. Rather
    than leave a tool that appears to do nothing, go and get a view where it
    means something. }
  if (T in [ptPush, ptDrill, ptFollow]) and (FD.View = vkPlan) then
  begin
    EnterFreeCamera(True);
    FCmdMsg := 'Push/pull needs to see the face - switched to the corner view.';
  end;
  if (T = ptOrbit) and (FD.View <> vkOrbit) then
  begin
    EnterFreeCamera;
    FCmdMsg := 'Orbit - drag to spin.  Shift pans; hold Ctrl and let go to click into the nearest view.';
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
  { Alt's inference cycle is for the run being drawn, not for the session }
  FInferMode := imAll;
  FParHas := False;
  FParPerp := 0;
  FArcTanHas := False;
  FArcTanLock := False;
  FOffsetRaw := False;
  FRotFree := False;
  FFollowFace := -1;
  FUnfoldPick := False;
  FNoteDrag := -1;
  FStickOn := False;
  FSliceEdit := 0;
  { Every path that changes sheets comes through here, and a sheet carries
    its own cut - so this is the one place that can guarantee the document is
    never left slicing by the last sheet's numbers. }
  ApplySlice;
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
  FRotAxisIx := -1;
  FInput := '';
  FBoxing := False;
  FMoveCopy := False;
  FMoveRigid := False;
  FDimMove := -1;
  SetLength(FMoveVerts, 0);
  SetLength(FMoveGroupEnts, 0);
  pbScreen.Invalidate;
  pbCmd.Invalidate;
end;

function TMainForm.PlanePix(Pl: TPlane): TPix;
begin
  case Pl of
    plXZ: Result := AxisPix(1);      { faces along Y, green }
    plYZ: Result := AxisPix(0);      { faces along X, red }
    { A sloped face points along no axis, so it gets no axis color.  Saying
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
  W, H, L, LBulge: Double;
  LPl: TPlane;
  LFil: TFillet;
  LTyped: Boolean;
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
    ptArc:
      if FStage = 1 then
        Result := FormatLen(Dist(FP1, FCur), FD.Units)
      else if FStage = 2 then
      begin
        if ArcFillet(LFil, LTyped) then
          Result := 'radius ' + FormatLen(LFil.R, FD.Units)
        else if ArcPicks(FCur, LPl, T, W, H, L, LBulge) then
          Result := 'bulge ' + FormatLen(Abs(LBulge), FD.Units);
      end;
    ptRotate, ptProtractor:
      if FStage >= 1 then
        Result := FormatAngle(RadToDeg(RotAngle));
    ptPush, ptDrill:
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

{ What the cursor is holding on to, in words rather than in capitals.

  The chip beside the pointer says ENDPOINT; this is the other half of what
  SketchUp puts along the bottom - the same fact, said as part of the
  sentence telling you what to do with it. }
function TMainForm.SnapSays: string;
begin
  if FAxisLock in [0..2] then
    Exit('held on the ' + AxisName(FAxisLock) + ' axis');
  if FParPerp = 1 then Exit('parallel to the last edge');
  if FParPerp = 2 then Exit('square to the last edge');
  case FSnapKind of
    snEndpoint: Result := 'on the end of an edge';
    snMidpoint: Result := 'on the middle of an edge';
    snSubMid:   Result := 'on the middle of a piece';
    snCenter:   Result := 'on a center';
    snCross:    Result := 'where two lines cross';
    snOnEdge:   Result := 'on an edge';
    snOnFace:   Result := 'on a face';
    snQuadrant: Result := 'on the quarter of a circle';
    snOrigin:   Result := 'on the origin';
    snOnAxis:
      case FSnapAxis of
        0: Result := 'on the red axis';
        1: Result := 'on the green axis';
      else Result := 'on the blue axis';
      end;
  else
    Result := '';
  end;
end;

{ The keys that do something right now, for the tool in hand and where it
  is up to.  From a note, 17 September: "there is some status helpers that pop up
  telling you to use alt or ctrl keys and why... SketchUp does it in the
  bottom of their status bar.  It gives lots of good info in their tools."

  Only what is true at this moment: a modifier named when it does nothing is
  worse than saying nothing, because it is tried once and never again. }
function TMainForm.ModifierTip: string;
begin
  Result := '';
  case FTool of
    ptSelect:
      if Length(FSel) = 0 then
        Result := 'Ctrl adds, Shift toggles, double-click takes what is ' +
                  'attached, three clicks take all of it'
      else
        Result := 'Ctrl adds, Shift toggles, Ctrl+Shift takes away';
    ptLine:
      if FStage = 0 then
        Result := 'arrows pick the plane, Alt holds it where it is'
      else
        case FInferMode of
          imNoLinear: Result := 'Alt: back to parallel and square, then to all - ' +
            'points still snap';
          imParPerp: Result := 'parallel and square only - Alt for all of them';
        else
          Result := 'arrows lock red, green or blue, Shift holds the one you ' +
                    'are on, Alt steps through the inferences';
        end;
    ptRect:
      if FStage = 0 then Result := 'arrows pick the plane, Alt holds it'
      else Result := 'type 8x10, or a minus to flip a side';
    ptCircle, ptArc:
      if FStage = 0 then
        Result := '+ and - change the sides, arrows pick the plane'
      else if (FTool = ptArc) and (FStage = 2) and FArcTanHas then
        Result := specialize IfThen<string>(FArcTanLock,
          'tangent to the edge it started on, held - Alt lets go',
          '+ and - change the sides, Alt runs it out of its edge smoothly')
      else
        Result := '+ and - change the sides, or type 24s';
    ptPush:
      if FLastPush <> 0 then
        Result := Format('double-click repeats the last push (%s)',
          [FormatLen(Abs(FLastPush), FD.Units)])
      else
        Result := 'type how far, or rest on an edge to go to it';
    ptOffset:
      if FOffsetRaw then Result := 'overlaps kept - Alt tidies them again'
      else Result := 'type the offset - a minus goes inward, Alt keeps the overlaps';
    ptMove:
      if FStage = 0 then Result := 'Ctrl leaves a copy behind'
      else Result := 'Ctrl copies, Shift holds the axis, then 3x or /3 for an array';
    ptErase: Result := 'Ctrl softens an edge instead, Ctrl+Shift brings it back';
    ptMeasure: Result := 'Ctrl changes what it leaves behind - ' + TapeDropSays;
    ptOrbit: Result := 'Shift pans, Ctrl clicks into the nearest view when you let go';
    ptRotate, ptProtractor:
      if FRotFree then
        Result := 'free of the face under the cursor - arrows pick the plane, ' +
                  'Alt follows faces again'
      else
        Result := 'arrows pick the plane by color, Alt frees it from the face';
    ptDim: Result := 'click the body of an edge for all of it';
    ptText: Result := 'Shift+Enter for a second line';
  end;
end;

{ The same thing as ModifierTip, short enough for the card beside the
  pointer - keys and what they do, nothing else. }
function TMainForm.ShortKeys: string;
begin
  Result := '';
  case FTool of
    ptSelect:   Result := 'Ctrl adds  Shift toggles  double-click takes more';
    ptLine:     if FStage = 0 then Result := 'arrows: the plane   Alt: hold it'
                else if FInferMode = imNoLinear then Result := 'Alt: inferences back on'
                else if FInferMode = imParPerp then Result := 'parallel and square only   Alt: all'
                else Result := 'arrows: lock an axis   Shift: hold it   Alt: what it infers';
    ptRect:     if FStage = 0 then Result := 'arrows: the plane   Alt: hold it';
    ptCircle, ptArc: Result := '+ and -: sides';
    ptPush:     if FLastPush <> 0 then Result := 'double-click: the last push again';
    ptMove:     Result := 'Ctrl: leave a copy   Shift: hold the axis';
    ptErase:    Result := 'Ctrl: soften   Ctrl+Shift: bring back';
    ptMeasure:  Result := 'Ctrl: what it leaves behind';
    ptOrbit:    Result := 'Shift: pan   Ctrl: click into a view';
    ptRotate, ptProtractor:
      if FRotFree then Result := 'free of the face   Alt: follow faces'
      else Result := 'arrows: the plane   Alt: free of the face';
  end;
end;

{ the tool's prompt, with where you are in front of it when a group is open }
function TMainForm.Prompt: string;
begin
  Result := PromptForTool;
  if (FD <> nil) and (FD.Doc.Context <> 0) then
    Result := 'in "' + FD.Doc.PartName(FD.Doc.Context) + '" (Esc leaves)   ' + Result;
end;

function TMainForm.PromptForTool: string;
var
  PromptAlong: Double;
  PMoveB: Boolean;
  PFil: TFillet;
  PTyped: Boolean;
begin
  case FTool of
    ptLine:
      if FStage = 0 then
      begin
        if (FD.View = vkOrbit) and not FPlaneHeld then
          Result := 'pick a start point   (arrows lock a flat plane: ' +
                    'left or right upright, up or down flat, Esc to let go)'
        else if FPlaneHeld then
          Result := 'pick a start point - locked to the ' + PlaneName +
                    ' plane, and it stays there'
        else
          Result := 'pick a start point';
      end
      else if FPlaneHeld and (FDirLock < 0) then
        Result := 'to the next point - held on the ' + PlaneName +
                  ' plane whatever you point at.  Double-click to finish'
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
        0:
          if FLastFilletR > 0 then
            Result := 'pick the first end - or double-click a corner to round it ' +
              FormatLen(FLastFilletR, FD.Units)
          else
            Result := 'pick the first end - on an edge near a corner to round it';
        1: Result := 'pick the second end';
      else
        if ArcFillet(PFil, PTyped) then
          Result := 'TANGENT TO EDGE - click, double-click to trim the corner, ' +
            'or type a radius'
        else if FilletCandidate(PFil) then
          Result := 'pull the middle towards the corner until it turns tangent, ' +
            'or type the bulge'
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
    ptPush, ptDrill:
      if FStage = 0 then
        Result := 'click a face'
      else
        Result := 'how far?  type it, or move and click';
    ptFollow:
      case FStage of
        0: Result := 'click the outline to spin - half of the shape, seen edge on';
        1: Result := 'the axis: click the straight side of the outline - ' +
                     'or two points down one side of it';
      else
        Result := 'the axis: a second point straight along it - type 90 ' +
                  'first for a quarter turn';
      end;
    ptDim:
      case FStage of
        0:
          if FHoverEnt >= 0 then
            Result := 'click the lit edge to dimension all of it'
          else if DimAnchored then
            Result := 'click an edge, or a first point to measure from'
          else
            { said before the click rather than after it: there is nothing
              here to measure from, and the cursor should say so while it is
              still a question }
            Result := 'nothing here to measure - find a corner, a midpoint, ' +
                      'a center, or an edge';
        1:
          if DimAnchored then
            Result := 'second point - on a corner, a midpoint, a center or an edge'
          else
            Result := 'the other end has to be on something too';
      else
        Result := 'move away to place the line, then click';
      end;
    ptOrbit:
      { With Ctrl down mid-orbit, say where letting go would take it.  The
        cube shows the same thing by lighting the face, but the cube is off
        until somebody turns it on, and a modifier whose effect you cannot
        see until after you have committed to it is a modifier nobody uses
        twice. }
      if FSnapHasHot and (FSnapHot.Name <> '') then
        Result := 'let go to click into ' + FSnapHot.Name
      else
        Result := 'drag to spin the view - Shift pans, Ctrl snaps to a view';
    ptSelect:
      if Length(FSel) = 0 then
        Result := 'click to pick, or drag a box   (Ctrl adds, Shift toggles)'
      else
        if (Length(FSel) = 1) and (FD.Doc[FSel[0]].Kind = ekText) then
          Result := '1 picked - M to move, + and - for the text size, Delete to remove'
        else if SelectedDim >= 0 then
          Result := 'dimension picked - type a size and the drawing follows'
        else if (SelectedLine >= 0) and FD.Doc.LineLengthEnd(SelectedLine, PMoveB) then
          Result := 'line picked - type a length and Enter; the free end moves'
        else
        Result := Format('%d picked - M to move, Delete to remove',
          [Length(FSel)]);
    ptMove:
      if FStage = 0 then
        Result := 'grab a point on what you are moving'
      else if FMoveCopy then
        Result := 'where does the copy go?  a length, [x,y,z] or <x,y,z>'
      else if FDetachMove then
        Result := 'where does it go, on its own?  a length, [x,y,z] or ' +
          '<x,y,z> - /detach off to join it back on'
      else
        Result := 'where does it go?  a length, [x,y,z] or <x,y,z>';
    ptErase:
      Result := 'click an edge to delete it - or hold and drag across ' +
        'several.  Ctrl softens instead, Ctrl+Shift brings it back';
    ptRotate, ptProtractor:
      case FStage of
        0: if FTool = ptRotate then
             Result := 'click the center to turn about   (arrows: red, green or blue plane)'
           else
             Result := 'click the vertex of the angle   (arrows: red, green or blue plane)';
        1: Result := 'click a point to measure the angle from, or type the angle';
      else
        Result := 'swing to the angle and click, or type it - 45, 22.5, or 8:12 ' +
          'for a slope.  Negative goes the other way.';
      end;
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
  T: TP3;
  U1, V1, U2, V2: Double;
  WasLine, Closed: Boolean;
begin
  { a click on anything is the end of the copy that could have become an
    array - except the copy's own placing click, which is what set it up }
  if FStage = 0 then FArray.Live := False;
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
        PruneSelection;
        if Length(FSel) = 0 then
        begin
          I := PickToGrab(FMouseSX, FMouseSY);
          if I < 0 then
          begin
            FCmdMsg := 'Nothing there to move.';
            Exit;
          end;
          SelectOnly(I);
        end;
        { A dimension taken by its line is repositioned, not moved: the two
          points it measures stay, the line goes where the cursor puts it -
          further out, the other side, or standing up on another plane.
          SketchUp's move does the same with a dimension. }
        if (Length(FSel) = 1) and (FD.Doc[FSel[0]].Kind = ekDim) then
        begin
          FDimMove := FSel[0];
          FP1 := FD.Doc[FDimMove].A;
          FP2 := FD.Doc[FDimMove].B;
          FStage := 1;
          FDirLock := -1;
          FInput := '';
          FCmdMsg := 'Moving the dimension line - click where it should sit.  ' +
            'Shake up and down to stand it on another plane.';
          Exit;
        end;
        FP1 := FCur;
        if not SplitMoveSelection then Exit;
        FStage := 1;
        FDirLock := -1;
        FInput := '';
        FCmdMsg := 'Click where it goes, or type a distance.  ' +
          'Arrows lock an axis, Ctrl leaves a copy.';
      end
      else
        ProCommit;

    ptRotate, ptProtractor:
      case FStage of
        0:
          begin
            if FTool = ptRotate then
            begin
              if Length(FSel) = 0 then
              begin
                I := PickToGrab(FMouseSX, FMouseSY);
                if I < 0 then
                begin
                  FCmdMsg := 'Nothing there to rotate - pick something first.';
                  Exit;
                end;
                { Everything joined to it, not the one face.  Turning one
                  face of a box twists the box - SketchUp does the same to a
                  partial selection - and nobody who has not selected
                  anything means that.  Pick first to turn a part on its
                  own: a click for one thing, double for a face and its
                  edges, triple for all that is joined. }
                if FD.Doc.TopPartIn(I) > 0 then SelectOnly(I) else SelectConnected(I);
              end;
              if not SplitMoveSelection then Exit;
            end;
            FP1 := FCur;
            { the plane: an arrow key's, else the face under the cursor's,
              else flat - which is the one a duct run turns in }
            if FRotAxisIx >= 0 then
              FRotAxis := AxisDir(FRotAxisIx)
            else if (not FRotFree) and
                    FD.Doc.FaceUnder(Proj, FMouseSX, FMouseSY, I, T) then
              FRotAxis := Norm3(FD.Doc.FaceNormal(I))
            else
              { Alt has freed it from the face, so it lies flat unless an
                arrow says otherwise - theirs frees it the same way }
              FRotAxis := P3(0, 0, 1);
            FStage := 1;
            FDirLock := -1;
            FInput := '';
            FCmdMsg := '';
          end;
        1:
          begin
            if Dist(FCur, FP1) < 1E-6 then
            begin
              FCmdMsg := 'Pick a point away from the center to measure from.';
              Exit;
            end;
            FRotRef := FCur;
            FStage := 2;
            FInput := '';
            FCmdMsg := '';
          end;
      else
        ProCommit;
      end;

    ptErase:
      begin
        { hit test where the pointer actually is - snapping to a nearby
          endpoint would otherwise make it miss the thing being clicked }
        P := PtF(FMouseSX, FMouseSY);
        I := FD.Doc.HitEdge(Proj, P.X, P.Y, 9 * FUIScale);
        if I < 0 then I := FD.Doc.HitTest(Proj, P.X, P.Y, 9 * FUIScale);
        { Ctrl softens rather than deletes, Ctrl+Shift brings it back. }
        if (I >= 0) and (FEraseMode <> 0) then
        begin
          SetLength(FDoomed, 1);
          FDoomed[0] := I;
          SoftenDoomed(FEraseMode = 1);
        end
        else if I >= 0 then
        begin
          PushUndo;
          { a line between two regions was holding them apart, so taking it
            away should leave one region rather than two that happen to touch }
          WasLine := FD.Doc[I].Kind in [ekLine, ekArc];
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
        { What parallel and square are offered from until a piece is drawn:
          the edge this line starts on, which is how SketchUp's magenta pair
          gets something to be parallel to.  Once a piece is drawn, that
          piece takes over - see ProCommit. }
        FInferMode := imAll;
        FParHas := False;
        I := FD.Doc.HitEdge(Proj, FMouseSX, FMouseSY, 9 * FUIScale,
          GUIDE_PICK_PX * FUIScale);
        if (I >= 0) and (FD.Doc[I].Kind = ekLine) and not FD.Doc[I].Dim then
        begin
          FParDir := P3(FD.Doc[I].B.X - FD.Doc[I].A.X,
                        FD.Doc[I].B.Y - FD.Doc[I].A.Y,
                        FD.Doc[I].B.Z - FD.Doc[I].A.Z);
          FParHas := Sqr(FParDir.X) + Sqr(FParDir.Y) + Sqr(FParDir.Z) > 1E-12;
        end;
      end
      else if FClickN >= 2 then
      begin
        { Double-click lets go of the run.

          SketchUp does *not* do this - the owner checked, and there a second
          click just drops another point; you press Esc.  This is one of the
          few places worth being deliberately unlike it: what was wanted was
          a way to let go with the mouse, and the keyboard was the only one.

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
        { the edge this arc is starting on, for Alt's tangent lock - see
          TangentBulge }
        FArcTanHas := False;
        FArcTanLock := False;
        I := FD.Doc.HitEdge(Proj, FMouseSX, FMouseSY, 9 * FUIScale,
          GUIDE_PICK_PX * FUIScale);
        if (I >= 0) and (FD.Doc[I].Kind = ekLine) and not FD.Doc[I].Dim then
        begin
          FArcTanDir := P3(FD.Doc[I].B.X - FD.Doc[I].A.X,
                           FD.Doc[I].B.Y - FD.Doc[I].A.Y,
                           FD.Doc[I].B.Z - FD.Doc[I].A.Z);
          FArcTanHas := Sqr(FArcTanDir.X) + Sqr(FArcTanDir.Y) +
                        Sqr(FArcTanDir.Z) > 1E-12;
        end;
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
          I := InContextFace(FD.Doc.HitFace(Proj, FMouseSX, FMouseSY));
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

    ptFollow:
      case FStage of
        0:
          begin
            I := InContextFace(FD.Doc.HitFace(Proj, FMouseSX, FMouseSY));
            if I < 0 then
            begin
              FCmdMsg := 'Click the face to follow - that is the profile.';
              Exit;
            end;
            FFollowFace := I;
            FStage := 1;
            FInput := '';
            { edges picked beforehand are the path, SketchUp's first way of
              using the tool }
            for J := 0 to High(FSel) do
              if FD.Doc[FSel[J]].Kind in [ekLine, ekArc] then
              begin
                DoSweep(ChainFrom(FSel[J], Closed), Closed);
                Exit;
              end;
            FCmdMsg := 'Now the path: click a line or arc to follow along, a circle to ' +
              'follow round, or two points for an axis to spin on.';
          end;
        1:
          begin
            { a circle under the cursor is a turn about its center - which is
              what following round it comes to; a line or an open arc is the
              start of a path }
            I := FD.Doc.HitEdge(Proj, FMouseSX, FMouseSY, 9 * FUIScale);
            if (I >= 0) and (FD.Doc[I].Kind = ekArc) and (I <> FFollowFace) and
               (Abs(FD.Doc[I].Sweep) >= 2 * Pi - 1E-9) then
            begin
              DoRevolve(FD.Doc[I].C, ArcNormal(I), I);
              Exit;
            end;
            { An edge of the outline itself is the axis, and this is the
              gesture the tool was missing.

              A wine glass is drawn with one side of it straight, because
              that side is the middle of the glass - and clicking that side
              is what anybody does when asked for the axis.  It used to mean
              "sweep the outline along this", which is meaningless: you
              cannot sweep a face along its own edge, and what came out was
              nothing at all.  The owner tried it repeatedly on 13 September and
              got nothing repeatedly.

              So it means what it looks like it means.  Sweeping along a
              path is still there for any other line. }
            if (I >= 0) and (FD.Doc[I].Kind = ekLine) and IsProfileEdge(I) then
            begin
              DoRevolve(FD.Doc[I].A,
                P3(FD.Doc[I].B.X - FD.Doc[I].A.X, FD.Doc[I].B.Y - FD.Doc[I].A.Y,
                   FD.Doc[I].B.Z - FD.Doc[I].A.Z));
              Exit;
            end;
            if (I >= 0) and (FD.Doc[I].Kind in [ekLine, ekArc]) then
            begin
              DoSweep(ChainFrom(I, Closed), Closed);
              Exit;
            end;
            FAxisA := FCur;
            FStage := 2;
            FCmdMsg := 'Second point on the axis.  Type 90 first for a quarter turn, or just click for all the way round.';
          end;
      else
        begin
          if Dist(FCur, FAxisA) < 1E-9 then
          begin
            FCmdMsg := 'The second point has to be somewhere else along the axis.';
            Exit;
          end;
          DoRevolve(FAxisA, P3(FCur.X - FAxisA.X, FCur.Y - FAxisA.Y, FCur.Z - FAxisA.Z));
        end;
      end;

    ptPush, ptDrill:
      if FStage = 0 then
      begin
        { A double-click on another face repeats the last pull, which is how
          SketchUp does a row of identical extrusions. }
        if (FClickN >= 2) and (Abs(FLastPush) > 1E-9) then
        begin
          I := InContextFace(FD.Doc.HitFace(Proj, FMouseSX, FMouseSY));
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
        if FReplayFace >= 0 then FPushFace := InContextFace(FReplayFace)
        else FPushFace := InContextFace(FD.Doc.HitFace(Proj, FMouseSX, FMouseSY));
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
        FOffFace := InContextFace(FD.Doc.HitFace(Proj, FMouseSX, FMouseSY));
        { as with push/pull, a face too crowded to click can be selected
          first and then worked on }
        if (FOffFace < 0) and (Length(FSel) = 1) and
           (FD.Doc[FSel[0]].Kind = ekFace) then
          FOffFace := FSel[0];
        if FOffFace < 0 then
          FCmdMsg := 'No face there.  Close a loop of lines to make one.'
        else
        begin
          { Offsetting is working on one face, so the cursor belongs to that
            face's plane until it is done.

            Without this the inferences are free to take it somewhere else -
            the model axes are infinite lines and the green one runs right
            through most drawings, so the cursor locked to it and went twenty
            feet below the square being offset.  The face was still the right
            face; the point being measured from it was in another county. }
          FFacePt := FD.Doc[FOffFace].Poly[0];
          FFaceNm := Norm3(FD.Doc.FaceNormal(FOffFace));
          FPlaneFromFace := True;
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
            { A corner is always on an edge, so "near an edge" alone made a
              point-to-point dimension impossible from any corner: the
              click took the whole edge every time.  A point the cursor has
              snapped to - a corner, a midpoint, a center - is the point
              meant; only a free cursor on the body of an edge takes the
              edge. }
            { What the hover lit up is what the click takes - worked out
              once, there, rather than a second time here with a different
              picker.  They used to disagree on anything built of faces. }
            if FHoverEdgeOK and (Dist(FHoverEdgeA, FHoverEdgeB) > 1E-9) then
            begin
              FP1 := FHoverEdgeA;
              FP2 := FHoverEdgeB;
              FStage := 2;
              FCmdMsg := 'The whole edge, ' +
                FormatLen(Dist(FP1, FP2), FD.Units) +
                ' - move away to place the line.';
            end
            else if not DimAnchored then
            begin
              { Nothing under the cursor to measure from.

                SketchUp's own rule, and their reason is the right one: a
                dimension "automatically updates as you modify your model",
                so one anchored to nothing can never update.  It is not a
                dimension, it is a decoration with a number in it - and a
                stale number that looks authoritative is worse than no
                number.  Their documentation lists exactly what a dimension
                may start and end on: end points, midpoints, on-edge points,
                intersections, and arc and circle centers. }
              FCmdMsg := 'A dimension has to measure something - a corner, ' +
                         'a midpoint, a center, or a point on an edge.';
              InvalidateStatus;
            end
            else
            begin
              FP1 := FCur;
              FStage := 1;
            end;
          end;
        1:
          { the far end has to be on something too, for the same reason }
          if DimAnchored then
          begin
            FP2 := FCur;
            FStage := 2;
          end
          else
          begin
            FCmdMsg := 'The other end has to be on something too - a corner, ' +
                       'a midpoint, a center, or a point on an edge.';
            InvalidateStatus;
          end;
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
        LayGuide;
        FRunOK := True;
        FRunA := FP1;
        FRunB := FP2;
        FCmdMsg := RunReading(FP1, FP2) + '   /keep makes it a dimension';
        ResetTool;
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

  { One length, where the rectangle wanted two.

    This reads perfectly well as a length, so nothing above it objects -
    and then RectTarget finds no separator, quietly gives up, and the corner
    comes from the cursor.  A rectangle of the wrong size and not a word
    said about why.

    From a note, 15 September: "uhm dude wtf happened to being able to enter
    dimensions like the truss guys do!?  that should have worked for my
    rectangle!"  The truss form works - 6-8-15x4-0-0 makes a rectangle six
    foot eight and fifteen sixteenths by four foot - and one on its own did
    nothing and said nothing, which is indistinguishable from the notation
    having stopped working. }
  if (FTool = ptRect) and (P = 0) and ParseLen(T, FD.Units, D) then
  begin
    Result := Format('%s reads fine - a rectangle wants both sides.  ' +
      'Type %s x 4-0-0, or %s/4-0-0 from the number pad.  A comma on the ' +
      'end instead sets that side and leaves the other on the cursor.',
      [T, T, T]);
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
  Fil: TFillet;
  FilTyped: Boolean;
  I, NPieces, NWas, NBroke: Integer;
  T, C: TP3;
  Loop: TP3Array;
  L, R, A0, Sweep, Bulge, U1, V1, U2, V2, UC, VC, NU, NV, Ln: Double;
  K: Integer;
  Ok: Boolean;
  Ang: Double;
  Base: Integer;
  Copies: array of Integer;
  ArcPl: TPlane;
  Stopped, DrillTyped: Boolean;
  Tk: QWord;
  WasRigid: Boolean;
begin
  Trail('commit ' + TOOL_NAMES[FTool] + ' stage=' + IntToStr(FStage));
  case FTool of
    ptRotate:
      begin
        if FStage < 1 then Exit;
        Ang := RotAngle;
        if Abs(Ang) < 1E-9 then
        begin
          FCmdMsg := 'Nothing turned - the angle was nought.';
          ResetTool;
          Exit;
        end;
        PushUndo;
        if FMoveCopy then
        begin
          { the copy stands on its own and turns whole; the original and
            whatever hangs off it stay put }
          FArray.Live := True;
          FArray.Rotate := True;
          FArray.C := FP1;
          FArray.Axis := FRotAxis;
          FArray.Ang := Ang;
          SetLength(FArray.Src, Length(FSel));
          for I := 0 to High(FSel) do FArray.Src[I] := FSel[I];
          FD.Doc.ArrayRotate(FArray.Src, FP1, FRotAxis, Ang, 1, False, FArray.Made);
          SetLength(Copies, Length(FArray.Made));
          for I := 0 to High(Copies) do Copies[I] := FArray.Made[I];
          SelectNone;
          for I := 0 to High(Copies) do SelectAdd(Copies[I]);
          FCmdMsg := 'Copied, turned ' + FormatAngle(RadToDeg(Ang)) +
            '.  Type 6x for six round, or /6 to divide the turn.';
        end
        else
        begin
          FD.Doc.RotateEnts(FMoveGroupEnts, FP1, FRotAxis, Ang);
          FD.Doc.RotateVerts(FMoveVerts, FP1, FRotAxis, Ang);
          FCmdMsg := 'Turned ' + FormatAngle(RadToDeg(Ang));
        end;
        RebuildFlatFaces;
        RenderPro;
        RecomposeAll;
        SetLength(FMoveVerts, 0);
        FMoveCopy := False;
              ResetTool;
        FInput := '';
      end;

    ptProtractor:
      begin
        if FStage < 1 then Exit;
        Ang := RotAngle;
        T := RotV(RotRefDir, FRotAxis, Ang);
        PushUndo;
        FD.Doc.AddGuide(FP1, P3(FP1.X + T.X, FP1.Y + T.Y, FP1.Z + T.Z));
        RenderPro;
        RecomposeAll;
        FCmdMsg := 'Guide laid at ' + FormatAngle(RadToDeg(Ang)) + '.';
        ResetTool;
        FInput := '';
      end;

    ptOffset:
      begin
        CommitOffset;
        Exit;
      end;
    ptFollow:
      begin
        if FStage = 2 then
          DoRevolve(FAxisA, P3(FCur.X - FAxisA.X, FCur.Y - FAxisA.Y, FCur.Z - FAxisA.Z));
        Exit;
      end;

    ptLine:
      begin
        T := PreviewTarget;
        if Dist(FP1, T) > 1E-9 then
        begin
          PushUndo;
          { Whether or not this line is new, it says the areas it bounds are
            wanted.  Drawn over one already there that is the only thing it
            can be saying, and it is how a face that was rubbed out comes
            back - SketchUp's healing.  See FHealOn. }
          FHealOn := True;
          FHealA := FP1;
          FHealB := T;
          if FD.Doc.HasLine(FP1, T) then
            FCmdMsg := FormatLen(Dist(FP1, T), FD.Units) + '   (already an edge)'
          else
          begin
            { Drawn along something already there, the two are cut where they
              share so the overlap is one edge rather than two lying on each
              other.  Nothing in the way and this is a plain add. }
            NPieces := FD.Doc.AddLineSplit(FP1, T, FInkColor, FEdgeW);
            if NPieces > 1 then
              FCmdMsg := FormatLen(Dist(FP1, T), FD.Units) +
                Format('   (split along an edge - %d pieces)', [NPieces])
            else
              FCmdMsg := FormatLen(Dist(FP1, T), FD.Units);
            { And where it crossed something, both are cut at the crossing.
              Not from the count taken before: laying the run down along
              something already there deletes what it overlapped and lays the
              pieces at the end, which moves every index above it.  The
              pieces are the last of them, however many there are. }
            NWas := FD.Doc.Live - Max(1, NPieces);
            NBroke := FD.Doc.SplitCrossings(NWas);
            if NBroke > 0 then
              FCmdMsg := FCmdMsg + Format('   (broke %d edge%s at the crossings)',
                [NBroke, IfThen(NBroke = 1, '', 's')]);
          end;
          { Whatever this line did to the flat areas - closed a loop, cut a
            face in two, cut one of the halves again - is worked out by asking
            what the edges enclose, rather than by a rule per case. }
          { what parallel and square are measured from, from here on: the
            piece just drawn - see TInferMode }
          FParDir := P3(T.X - FP1.X, T.Y - FP1.Y, T.Z - FP1.Z);
          FParHas := Sqr(FParDir.X) + Sqr(FParDir.Y) + Sqr(FParDir.Z) > 1E-12;
          I := FaceCount;
          K := RebuildFlatFaces;
          FHealOn := False;
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
          NWas := FD.Doc.Live;
          Loop := RectCorners(FP1, T, FD.Plane);
          { An edge that lands exactly on one already there is the same edge.
            Adding it again left two lines in the same place and two
            dimension labels on top of each other.

            And a side drawn over an edge already there says the area it
            bounds is wanted - the same healing the line tool does, see
            FHealOn.  Without this a rectangle traced round an opening in a
            box put four lines nowhere and no face came back, which is the
            report of 19 September: "i cant get this thing to heel the face
            by drawing a new rectangle inside".  One side is enough for the
            rebuild to know. }
          for I := 0 to 3 do
            if not FD.Doc.HasLine(Loop[I], Loop[(I + 1) mod 4]) then
              FD.Doc.AddLine(Loop[I], Loop[(I + 1) mod 4],
                FInkColor, FPenSize, False)
            else if not FHealOn then
            begin
              FHealOn := True;
              FHealA := Loop[I];
              FHealB := Loop[(I + 1) mod 4];
            end;
          FD.Doc.SplitCrossings(NWas);
          RebuildFlatFaces;
          FHealOn := False;
          RenderPro;
          RecomposeAll;
          Trail('rect made, ' + IntToStr(FaceCount) + ' faces now');
          FCmdMsg := Format('%s x %s   area %s',
            [FormatLen(U1, FD.Units), FormatLen(V1, FD.Units),
             FormatArea(U1 * V1, FD.Units)]);
        end
        else
        begin
          { Say why, because the commonest reason is invisible.

            A rectangle drawn nearly along one of the axes has one side
            shorter than half the snap step, that side rounds to nothing, and
            the whole rectangle is thrown away.  On a one foot snap that is
            anything within six inches of straight, which on screen is a good
            deal wider than it sounds - and the old message said only that
            two sides were needed, leaving somebody to conclude the tool was
            broken.  Caught while testing something else; the drive script
            landed two corners eight inches apart across and fourteen feet
            along, and the rectangle vanished. }
          RectSides(FP1, WorldAt(FMouseSX, FMouseSY), FD.Plane, U2, V2);
          FCmdMsg := Format('A rectangle needs two sides - that one is %s by %s.',
            [FormatLen(U2, FD.Units), FormatLen(V2, FD.Units)]);
          if (SnapStep > 0) and (Min(U2, V2) > 1E-9) and
             (Min(U2, V2) < SnapStep / 2) then
            FCmdMsg := FCmdMsg + Format('  The snap is %s, so the short side ' +
              'rounded away to nothing - a finer snap, or pull it further out.',
              [FormatLen(SnapStep, FD.Units)]);
        end;
        ResetTool;
        FInput := '';
      end;

    ptArc:
      begin
        { A corner being rounded: its own geometry, and the square corner
          left where it is.

          From a note: "in sketchup you have to erase the sharp left over 90 degree
          lines after you put the arc there... because in some situations...
          who knows maybe you just want an arc inside the pointed corner...
          so keep it just like sketchup!"

          So a click, or a radius typed and Enter, puts the arc in and cuts
          the two lines at the touching points - the corner pieces are then
          lines of their own, to rub out or to keep.  Only the second click
          of a double-click trims, which is the one place SketchUp's help
          says it "cleans out the excess waste". }
        if ArcFillet(Fil, FilTyped) then
        begin
          PushUndo;
          FD.Doc.ApplyFillet(Fil, FSidesArc, FInkColor, FEdgeW, False);
          FLastFilletR := Fil.R;
          RebuildFlatFaces;
          RenderPro;
          RecomposeAll;
          FCmdMsg := 'Arc tangent to both edges, radius ' +
            FormatLen(Fil.R, FD.Units) +
            '.  The corner is still there - erase it, or double-click to trim it.';
          FLastFillet := Fil;
          FFilletPending := True;
          FFilletSeq := FEditSeq;
          FFilletTick := GetTickCount64;
          ResetTool;
          Exit;
        end;
        Ok := ArcPicks(FCur, ArcPl, C, R, A0, Sweep, Bulge);
        if not Ok and (Dist(FP1, FP2) < 1E-9) then
        begin
          ResetTool;
          Exit;
        end;
        if Ok then
        begin
          PushUndo;
          NWas := FD.Doc.Live;
          FD.Doc.AddArc(C, R, A0, Sweep, ArcPl, FInkColor, FEdgeW);
          FD.Doc.SetArcSides(FD.Doc.Live - 1, FSidesArc);
          FCmdMsg := 'Arc radius ' + FormatLen(R, FD.Units);
          NBroke := FD.Doc.SplitCrossings(NWas);
          if NBroke > 0 then
            FCmdMsg := FCmdMsg + Format('   (broke %d edge%s at the crossings)',
              [NBroke, IfThen(NBroke = 1, '', 's')]);
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
          NWas := FD.Doc.Live;
          FD.Doc.AddArc(FP1, R, 0, 2 * Pi, FD.Plane, FInkColor, FEdgeW);
          FD.Doc.SetArcSides(FD.Doc.Live - 1, FSidesCircle);
          NBroke := FD.Doc.SplitCrossings(NWas);
          RebuildFlatFaces;
          RenderPro;
          RecomposeAll;
          FCmdMsg := Format('Circle radius %s   area %s',
            [FormatLen(R, FD.Units), FormatArea(Pi * R * R, FD.Units)]);
          if NBroke > 0 then
            FCmdMsg := FCmdMsg + Format('   (broke %d edge%s at the crossings)',
              [NBroke, IfThen(NBroke = 1, '', 's')]);
        end;
        ResetTool;
      end;

    ptMove:
      begin
        if FDimMove >= 0 then
        begin
          PushUndo;
          FD.Doc.SetDimOffset(FDimMove, OutsideOf(FP1, FP2, DimOffset3));
          RenderPro;
          RecomposeAll;
          FCmdMsg := 'Dimension moved.';
          ResetTool;
          Exit;
        end;
        T := MoveDelta;
        if (Abs(T.X) > 1E-9) or (Abs(T.Y) > 1E-9) or (Abs(T.Z) > 1E-9) then
        begin
          PushUndo;
          if FMoveCopy then
          begin
            { a copy stands on its own, so nothing gets stretched to reach it }
            FArray.Live := True;
            FArray.Rotate := False;
            FArray.D := T;
            SetLength(FArray.Src, Length(FSel));
            for I := 0 to High(FSel) do FArray.Src[I] := FSel[I];
            FD.Doc.ArrayMove(FArray.Src, T, 1, False, FArray.Made);
            FCmdMsg := 'Copied ' + FormatLen(
              Sqrt(Sqr(T.X) + Sqr(T.Y) + Sqr(T.Z)), FD.Units) +
              '.  Type 3x for three that far apart, or /3 to divide the run.';
          end
          else if FMoveRigid then
          begin
            { a part just built: it goes as one piece and nothing else comes
              along, however many corners it was sharing where it was made }
            FD.Doc.TranslateEnts(FSel, T);
            FCmdMsg := 'Placed.';
          end
          else if FDetachMove then
          begin
            { Alt: take it away on its own and leave what it was joined to
              where it is.  SketchUp has no such thing - it always stretches -
              but Both were asked for and there is a reason to want it: a
              line drawn as a guide to something else should not drag the
              something else along when it goes. }
            FD.Doc.TranslateEnts(FSel, T);
            FCmdMsg := 'Moved ' + FormatLen(
              Sqrt(Sqr(T.X) + Sqr(T.Y) + Sqr(T.Z)), FD.Units) +
              '   (on its own - nothing stretched to follow)';
          end
          else
          begin
            { every corner that sits where a moving one sat travels too, so
              whatever was joined on stretches to follow }
            Tk := GetTickCount64;
            { whole groups first, as one piece each; then the loose corners }
            FD.Doc.TranslateEnts(FMoveGroupEnts, T);
            FD.Doc.MoveVerts(FMoveVerts, T);
            Took('move the corners', Tk);
            FCmdMsg := 'Moved ' + FormatLen(
              Sqrt(Sqr(T.X) + Sqr(T.Y) + Sqr(T.Z)), FD.Units);
          end;
          { moving an edge changes what the edges enclose, so the flat areas
            are worked out again - which is also what stretches a face to
            follow the edge that moved.  A built part placed whole is the
            exception: its openings are the four edges of a duct end, and
            working the areas out again would cap them.  They are taken as
            seen where they now sit instead. }
          Tk := GetTickCount64;
          if FMoveRigid then SeedRegions else RebuildFlatFaces;
          Took('work the faces out', Tk);
          Tk := GetTickCount64;
          RenderPro;
          Took('render', Tk);
          Tk := GetTickCount64;
          RecomposeAll;
          Took('recompose', Tk);
        end;
        SetLength(FMoveVerts, 0);
        FMoveCopy := False;
              WasRigid := FMoveRigid;
        ResetTool;
        FInput := '';
        { A built part placed is done with: it is let go of and the select
          tool comes back.  Left selected under the move tool, the next click
          picked it up again, which read as the click not having placed it. }
        if WasRigid then
        begin
          SelectNone;
          SetTool(ptSelect);
          FCmdMsg := 'Placed.';
        end;
      end;

    ptPush, ptDrill:
      begin
        R := PushDistance;
        Stopped := False;
        FCmdMsg := '';
        { A drill goes through.  See TWorkDoc.ThroughDistance: the far end
          has to land exactly on the plane of the wall it comes out of or
          there is no tunnel, only a plug, and nobody can drag to that.

          Unless a depth was typed.  Then it is a blind hole exactly that
          deep - through any passage already in the block on the way, which
          is the one thing push/pull will not do, since push/pull stops at
          the first passage it meets and is right to.  From a note, 20
          September: "think about if you drilled into a 6 inch thick block
          through other passages... maybe I don't want to come all the way
          out the other side."  A passage the blind hole crosses is not cut
          open into it yet; that wants the crossing-cut a through-tunnel
          gets, done for a hole with a floor. }
        DrillTyped := (FTool = ptDrill) and (FInput <> '') and ParseLen(FInput, FD.Units, L);
        if (FTool = ptDrill) and (Abs(R) > 1E-9) and not DrillTyped then
          R := FD.Doc.ThroughDistance(FPushFace, R);
        { A drill goes in, never out, whichever way the mouse happened to
          drift before the number was typed: the way the block's far wall
          lies is the way in.  ThroughDistance hands back what it was given
          when there is no wall that way. }
        if DrillTyped and (Abs(R) > 1E-9) then
        begin
          if Abs(FD.Doc.ThroughDistance(FPushFace, -1E-3) + 1E-3) > 1E-9 then R := -Abs(R)
          else if Abs(FD.Doc.ThroughDistance(FPushFace, 1E-3) - 1E-3) > 1E-9 then R := Abs(R);
        end;
        { Push/pull stops where it would run into a tunnel already through
          the solid, the way SketchUp's does, and says so.  Drill is the tool
          that goes on through: where the new hole crosses the old one both
          are cut open into each other. }
        if (FTool = ptPush) and (Abs(R) > 1E-9) then
        begin
          L := BoreLimit(FD.Doc, FPushFace, R);
          if Abs(L) < Abs(R) - 1E-9 then
          begin
            R := L;
            Stopped := True;
          end;
        end;
        if Abs(R) > 1E-9 then
        begin
          PushUndo;
          if FD.Doc.PushPull(FPushFace, R) then
          begin
            FLastPush := R;      // so a double-click can repeat it
            if (FTool = ptDrill) and (FD.Doc.LastBore >= 0) then
              if CutCrossingBores(FD.Doc, FD.Doc.LastBore) > 0 then
                FCmdMsg := 'Drilled through - the tunnels cut into each other.';
            { Every area the push has just made is known now - the far end
              of a tunnel above all, which is an opening and not a place for
              a face.  Without this the next rebuild found it new, and
              closed it. }
            { pressed flat, the solid is a loose face again, lying on
              whatever it stood on - which has to be cut round it, the way
              it is when a shape is first drawn there, or the two share a
              plane and which one shows is luck }
            if FD.Doc.LastFlattened then RebuildFlatFaces;
            SeedRegions;
            SelectNone;
            RenderPro;
            RecomposeAll;
            if Stopped then
              FCmdMsg := 'Stopped at the tunnel, ' + FormatLen(Abs(R), FD.Units) +
                ' in.  Drill (B) goes on through.'
            else if FCmdMsg = '' then
            begin
              if (FTool = ptDrill) and DrillTyped then
                FCmdMsg := 'Drilled ' + FormatLen(Abs(R), FD.Units) +
                  ' in, and stopped there.'
              else if FTool = ptDrill then
                FCmdMsg := 'Drilled through, ' + FormatLen(Abs(R), FD.Units)
              else
                FCmdMsg := 'Pulled ' + FormatLen(Abs(R), FD.Units);
            end;
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
          FD.Doc.AddDim(FP1, FP2, FInkColor, OutsideOf(FP1, FP2, DimOffset3));
          RenderPro;
          RecomposeAll;
          FCmdMsg := 'Dimension ' + FormatLen(Dist(FP1, FP2), FD.Units);
        end;
        ResetTool;
      end;

    ptMeasure:
      begin
        if FStage = 1 then
        begin
          { A typed distance is the second click.  Enter here used to put the
            tool away and lose the measurement, so a guide could only be laid
            by pointing at the spot - which is the one thing a typed distance
            is for.  The point lands the typed length along the direction
            the run had, the same reading as the line tool takes, and the
            guide and its point go down exactly as a click leaves them. }
          FP2 := PreviewTarget;
          if Dist(FP1, FP2) < 1E-9 then
          begin
            FCmdMsg := 'Type how far, or click the second point.';
            Exit;
          end;
          FInput := '';
          LayGuide;
          FRunOK := True;
          FRunA := FP1;
          FRunB := FP2;
          FCmdMsg := RunReading(FP1, FP2) + '   /keep makes it a dimension';
          RenderPro;
          RecomposeAll;
        end;
        { And that is the whole of the tape.  There used to be a third stage
          it sat in afterwards, where another Enter turned the run into a
          dimension - and sitting in it is what made both of the faults the owner
          reported in one go.

          "the tape measure leaving phantom lines after a while... switching
          to the select tool and selecting something seems to clear it.  the
          stupid dimension appearing with using a tape measure tool."

          The phantom line was the tape's own rubber band: at that third
          stage it drew the run it had just measured, and went on drawing it
          until something else took the tool away.  And the dimension was
          Enter - or Space, which everywhere else in the program means "done"
          - landing on a stage that was still waiting, minutes after the
          measurement it belonged to.

          Keeping a run as a dimension is worth having and is now /keep,
          which cannot arrive by accident and which the command list will
          show anybody looking for it. }
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

{ Everything after the first word, exactly as it was typed - for the
  commands whose argument is a path rather than a word. }
function RawTail(const S: string): string;
var
  P: Integer;
begin
  P := Pos(' ', Trim(S));
  if P <= 0 then Result := ''
  else Result := Trim(Copy(Trim(S), P + 1, MaxInt));
end;

{ A handful of typed words, so the command bar is useful and not decorative. }
function TMainForm.RunCommand(const S: string): Boolean;
var
  ReDoomed: array of Boolean;
  W, Rest: string;
  P, I, N, J, K: Integer;
  RL, RL2: Double;
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

  { Whichever way it arrived - typed out in full, picked off the list, or
    taken from a menu - it counts as one you use, and the list puts it near
    the top next time.  Here rather than in the list, because a command
    typed from memory is the best evidence of all that you use it. }
  { by its name, so /e and /erase are one entry in what you use }
  I := CmdIndex(W);
  if I >= 0 then NoteCmdUsed(CMD_LIST[I].Name);

  if (W = 'line') or (W = 'l') then SetTool(ptLine)
  else if (W = 'select') or (W = 's') then SetTool(ptSelect)
  else if (W = 'move') or (W = 'mv') then SetTool(ptMove)
  else if (W = 'arc') or (W = 'a') then SetTool(ptArc)
  else if (W = 'circle') or (W = 'c') then SetTool(ptCircle)
  else if (W = 'text') or (W = 'note') or (W = 'n') then SetTool(ptText)
  else if (W = 'erase') or (W = 'e') or (W = 'del') then SetTool(ptErase)
  else if (W = 'orbit') or (W = 'spin') then SetTool(ptOrbit)
  { Typing a size into the dimension that is picked.  The bare length does
    this too; the command exists for the other end and for a script. }
  else if (W = 'resize') or (W = 'size') then
  begin
    if SelectedDim < 0 then
      FCmdMsg := 'Pick one dimension first, then say what it should read.'
    else
    begin
      { "14' start" or "14' other" moves the end it was drawn from }
      W := Trim(Rest);
      I := LastDelimiter(' ', W);
      N := 1;                            { 1 = the end it was drawn to }
      if I > 0 then
      begin
        Rest := Trim(Copy(W, I + 1, MaxInt));
        if (Rest = 'start') or (Rest = 'first') or (Rest = 'other') or
           (Rest = 'a') or (Rest = 'from') then
        begin
          N := 0;
          W := Trim(Copy(W, 1, I - 1));
        end;
      end;
      if not ParseLen(W, FD.Units, RL) then
        FCmdMsg := 'I could not read "' + W + '" as a size.'
      else
        ApplyDimResize(RL, N = 1);
    end;
  end
  { the same thing the right button offers, for a keyboard and for a script }
  else if (W = 'reverse') or (W = 'rev') or (W = 'flip') then
  begin
    N := 0;
    for I := 0 to High(FSel) do
      if FD.Doc[FSel[I]].Kind = ekFace then Inc(N);
    if N = 0 then
      FCmdMsg := 'Pick a face first - reverse turns over the faces you have selected.'
    else
    begin
      PushUndo;
      N := ReverseSelectedFaces;
      if N = 1 then FCmdMsg := 'Face turned over.'
      else FCmdMsg := Format('%d faces turned over.', [N]);
    end;
  end
  else if (W = 'group') or (W = 'makegroup') then MakeGroup
  else if (W = 'explode') or (W = 'ungroup') then ExplodeGroups
  else if (W = 'edit') or (W = 'opengroup') then
  begin
    if SoleGroup > 0 then OpenGroup(SoleGroup)
    else FCmdMsg := 'Pick one group first - or double-click it.';
  end
  else if (W = 'leave') or (W = 'closegroup') then
  begin
    if FD.Doc.Context <> 0 then CloseGroup
    else FCmdMsg := 'No group is open.';
  end
  else if (W = 'hide') or (W = 'putaway') then
    { the name as typed - a group is found by it however it is cased }
    if Rest = '' then HideGroups(True, '')
    else HideGroups(True, Copy(Trim(S), Pos(' ', Trim(S)) + 1, MaxInt))
  else if (W = 'show') or (W = 'unhide') then
    if Rest = '' then HideGroups(False, '')
    else HideGroups(False, Copy(Trim(S), Pos(' ', Trim(S)) + 1, MaxInt))
  else if W = 'lock' then LockGroups(True)
  else if W = 'unlock' then LockGroups(False)
  else if (W = 'name') or (W = 'rename') then
    { the name as typed, not lowercased with the rest of the command }
    if Rest = '' then RenameGroup('')
    else RenameGroup(Copy(Trim(S), Pos(' ', Trim(S)) + 1, MaxInt))
  else if (W = 'rect') or (W = 'rectangle') or (W = 'r') then SetTool(ptRect)
  else if (W = 'measure') or (W = 'm') or (W = 'tape') then SetTool(ptMeasure)
  else if (W = 'dimension') or (W = 'dim') then SetTool(ptDim)
  else if (W = 'offset') or (W = 'f') then SetTool(ptOffset)
  else if (W = 'rotate') or (W = 'q') or (W = 'turn') then SetTool(ptRotate)
  else if (W = 'protractor') or (W = 'angle') then SetTool(ptProtractor)
  else if (W = 'drill') or (W = 'bore') or (W = 'punch') then SetTool(ptDrill)
  { The tool is REVOLVE on the strip and in the manual.  It was Follow Me
    once, which is SketchUp's name for it, and those words still work -
    somebody coming from there will type what they know. }
  else if (W = 'revolve') or (W = 'followme') or (W = 'follow') or
          (W = 'lathe') then SetTool(ptFollow)
  { not /new.  That is offered in the list as "a new sheet" and there is a
    branch further down that makes one, which this was quietly eating: the
    first comparison that matches wins, and this one is above it.  A command
    the list advertises has to do what the list says. }
  else if (W = 'whatsnew') or (W = 'changes') then ShowWhatsNew
  else if (W = 'transition') or (W = 'trans') or (W = 'fitting') or (W = 'elbow') or (W = 'tee') then BuildTransitionWizard
  else if (W = 'spool') or (W = 'pipe') or (W = 'scratchpad') then BuildSpoolWizard
  else if (W = 'radiant') or (W = 'pex') or (W = 'hydronic') then BuildRadiantWizard
  else if W = 'rendertime' then RenderTiming
  else if W = 'quick' then
  begin
    FQuickFrames := not FQuickFrames;
    FCameraMoving := False;
    RepaintPaper; RenderPro; RecomposeAll; Invalidate;
    if FQuickFrames then FCmdMsg := 'Quick frames while the camera moves: on.'
    else FCmdMsg := 'Quick frames while the camera moves: off - every frame at full quality.';
  end
  else if W = 'threads' then
  begin
    FThreads := not FThreads;
    DefaultThreads := FThreads;
    for I := 0 to High(FDrawings) do FDrawings[I].Doc.Threads := FThreads;
    RenderPro; RecomposeAll; Invalidate;
    if FThreads then FCmdMsg := 'Worker threads: on - the lines-on-faces cache is built off the main thread.'
    else FCmdMsg := 'Worker threads: off - everything on the main thread.';
  end
  else if (W = 'report') or (W = 'bug') then ReportBug('', '', '')
  else if W = 'touch' then
    FCmdMsg := Format('Touch: hook %s, %d events so far, %d fingers down.',
      [BoolToStr(FTouchOn, True), FTouchCount, Length(FTouches)])
  else if (W = 'sysinfo') or (W = 'machine') then
  begin
    { what a report would say about this machine - so anyone can see it
      before sending one }
    FCmdMsg := 'That is what goes with a report about this machine.';
    WriteLn(MachineText);
    Flush(Output);
    Trail('machine:' + LineEnding + MachineText);
    ShowFacts('This machine, as a report says it', MachineText);
  end
  { for testing: what an update does at the end, without the update - the
    handoff written and the program closed without a question.  Start it
    again with --updated to see the drawings come back. }
  else if W = 'handoff' then
  begin
    SaveDraft;
    WriteHandoff;
    FHandingOver := True;
    Close;
  end
  else if W = 'state' then
  begin
    { the rest of a report - what the program was doing and how it was set }
    FCmdMsg := 'That is what goes with a report about the program right now.';
    WriteLn(DiagnosticText);
    WriteLn(SettingsText);
    Flush(Output);
    ShowLongText('The program, as a report says it',
      DiagnosticText + LineEnding + SettingsText);
  end
  else if W = 'timings' then
  begin
    { On, do the thing, off - and turning it off shows what it saw.
      "/timings show" looks without stopping. }
    if Rest = 'show' then
      ShowTimingLog
    else
    begin
      FTimings := not FTimings;
      if FTimings then
      begin
        FTimingLog := nil;
        FCmdMsg := 'Step timings on.  Do the slow thing, then /timings again to see them.';
      end
      else
      begin
        FCmdMsg := 'Step timings off.';
        ShowTimingLog;
      end;
    end;
  end
  else if (W = 'all') or (W = 'selectall') then
  begin
    SelectNone;
    BeginBulkSelect;
    for I := 0 to FD.Doc.Live - 1 do
      if FD.Doc[I].Kind in [ekLine, ekArc, ekFace, ekDim, ekText] then SelectAdd(I);
    EndBulkSelect;
    FCmdMsg := Format('%d things selected.', [Length(FSel)]);
    pbScreen.Invalidate;
  end
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
  { the shop tool by name, the way every other tool can be reached - the
    SHOP list is the discoverable way in, this is the fast one }
  else if (W = 'unfold') or (W = 'layout') then StartUnfold
  else if (W = 'fit') or (W = 'zoom') then FitView
  else if W = 'view' then CycleViewPreset(1)
  else if (W = 'top') or (W = 'down') then ApplyViewPreset(10)
  else if W = 'front' then ApplyViewPreset(6)
  else if W = 'right' then ApplyViewPreset(7)
  else if W = 'back' then ApplyViewPreset(8)
  else if W = 'left' then ApplyViewPreset(9)
  else if W = 'corner' then ApplyViewPreset(2)
  else if W = 'iso' then SetView(vkIso)
  { /orbit is the orbit tool, higher up; this is only reached by /3d.  Left
    written out because the two are the same idea from different ends and
    somebody reading the chain should see that it was meant. }
  else if W = '3d' then SetView(vkOrbit)
  else if (W = 'plan') or (W = '2d') or (W = 'flat') then SetView(vkPlan)
  { The slice, from the keyboard and for a script.  "/cut off", "/cut all",
    or "/cut 0 9'" for a bottom and a top. }
  else if (W = 'cut') or (W = 'slice') then
  begin
    if (Rest = 'off') or (Rest = 'none') then
      SetSlice(False, FD.SliceLo, FD.SliceHi)
    else if (Rest = 'all') or (Rest = 'whole') then
    begin
      if FD.Doc.ZRange(RL, RL2) then SetSlice(True, RL, RL2)
      else FCmdMsg := 'Nothing on this sheet to measure.';
    end
    else if Rest = '' then
      FCmdMsg := SliceText + '.  "/cut 0 9''" sets it, "/cut all" opens it ' +
                 'right up, "/cut off" turns it off.'
    else
    begin
      P := Pos(' ', Rest);
      if P <= 0 then
        FCmdMsg := 'Two heights, a bottom and a top - "/cut 0 9''".'
      else if not ParseLen(Trim(Copy(Rest, 1, P - 1)), FD.Units, RL) then
        FCmdMsg := 'I could not read "' + Trim(Copy(Rest, 1, P - 1)) + '" as a height.'
      else if not ParseLen(Trim(Copy(Rest, P + 1, MaxInt)), FD.Units, RL2) then
        FCmdMsg := 'I could not read "' + Trim(Copy(Rest, P + 1, MaxInt)) + '" as a height.'
      else
      begin
        if FD.View <> vkPlan then SetView(vkPlan);
        SetSlice(True, RL, RL2);
      end;
    end;
  end
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
  else if W = 'forget' then
  begin
    { for testing: forget every area ever seen, then work the faces out
      again - what a move or a turn of a built part used to amount to }
    PushUndo;
    SetLength(FD.Seen, 0);
    I := RebuildFlatFaces;
    RenderPro;
    RecomposeAll;
    FCmdMsg := Format('Forgot what was seen and worked the faces out again: %d.', [I]);
  end
  else if (W = 'center') or (W = 'middle') then
    CenterSelection
  { The other half of it: not the middle on the origin but the near bottom
    corner, so the thing stands on the floor with its edges against zero.

    Not /corner - that is already a view, the corner you look from rather
    than the corner you put a thing in.  /tozero says what it does and
    collides with nothing. }
  else if (W = 'tozero') or (W = 'zero') or (W = 'tuck') then
    CornerSelection
  { The way into the toy.  It used to be a button in the corner, next to the
    one for coming back, and the pair of them sat in the top right of a
    program that had got serious enough not to want them there.  The toy is
    not a secret and not hidden - it is in the command list with everything
    else - it just no longer takes up room in the chrome of a drawing
    program to say it exists. }
  { The cube.  Off by default and on by asking, because a first drawing is a
    rectangle in plan and an instrument for reading your bearings in three
    dimensions is an answer to a question nobody has yet.  Everything about
    it is remembered between sessions.

    Bare it toggles; "on" and "off" say so outright for anybody writing a
    script or a shortcut; tl, tr, bl and br move it to a corner; and
    "fitselection" decides whether a click brings what is picked into the
    middle and sizes it on the way round. }
  { Moving one side of a rectangle stretches the two it joins, which is what
    SketchUp does and what anybody drawing expects.  What was wanted was the other
    way as well - take the line away and leave the rest where it is - and a
    move has no key left to hold for it: Ctrl leaves a copy, Shift holds the
    axis, Alt holds the working plane, and every letter is a tool.  So it is
    a setting, and it says so loudly while it is on: the ghost goes amber,
    the hint line says "on its own", and so does the message after. }
  { The last run the tape measured, kept.

    This used to be a second press of Enter while the tape sat in a stage it
    had no other reason to be in, and that stage is what left a line on the
    screen and dropped dimensions on people minutes later.  As a command it
    cannot arrive by accident, and the list will show it to anybody looking
    for a way to keep a measurement. }
  else if (W = 'keep') or (W = 'keepdim') then
  begin
    if not FRunOK then
      FCmdMsg := 'Nothing measured yet.  Take the tape across something ' +
        'first, then /keep writes that run on the drawing.'
    else if Dist(FRunA, FRunB) < 1E-9 then
      FCmdMsg := 'That run was no length at all.'
    else
    begin
      PushUndo;
      FD.Doc.AddDim(FRunA, FRunB, FInkColor, DimOffset3);
      RenderPro;
      RecomposeAll;
      FCmdMsg := 'Kept as a dimension: ' + FormatLen(Dist(FRunA, FRunB), FD.Units) + '.';
    end;
  end
  { The entity panel down the right.  A command rather than a button because
    the row along the bottom is full and a row that changes width with what is
    in the drawing was already a mistake once - see the note in RebuildDeck
    about the guide buttons. }
  else if (W = 'info') or (W = 'entity') or (W = 'properties') then
  begin
    if Rest = 'on' then FInfoOn := True
    else if Rest = 'off' then FInfoOn := False
    else FInfoOn := not FInfoOn;
    FInfoSig := -1;
    Relayout;
    if FInfoOn then
    begin
      RebuildInfo;
      pbInfo.Invalidate;
      FCmdMsg := 'The entity panel is on the right.  Pick something to see ' +
        'what it is; a few of the figures can be changed from there.';
    end
    else
      FCmdMsg := 'Entity panel off.  /info brings it back.';
    Invalidate;
  end
  else if (W = 'detach') or (W = 'loose') then
  begin
    if Rest = 'on' then FDetachMove := True
    else if Rest = 'off' then FDetachMove := False
    else FDetachMove := not FDetachMove;
    if FDetachMove then
      FCmdMsg := 'A move takes what is picked away on its own now.  ' +
        'Nothing it is joined to will stretch to follow.  /detach off puts ' +
        'that back.'
    else
      FCmdMsg := 'A move stretches what it is joined to again, which is how ' +
        'SketchUp does it.';
  end
  else if (W = 'postcard') or (W = 'hello') then
  begin
    uDlgSkin.UseTheme(Themes[FThemeIdx]);
    OfferPostcard(Self, CurrentVersion, True);
  end
  else if (W = 'light') or (W = 'lamp') then
  begin
    if (Rest = 'on') or (Rest = 'off') then CameraLamp := Rest = 'on'
    else if Rest = '' then CameraLamp := not CameraLamp
    else FCmdMsg := 'The light takes on or off.';
    if FCmdMsg = '' then
    begin
      if CameraLamp then
        FCmdMsg := 'The light follows the camera: the face turned towards ' +
                   'you is the bright one.  /light off for the old fixed lamp.'
      else
        FCmdMsg := 'The light is fixed, as it used to be: the same grays ' +
                   'from every angle.  /light on has it follow the camera.';
    end;
    RenderPro;
    RecomposeAll;
    FScreenDirty := True;
    pbScreen.Invalidate;
  end
  else if (W = 'source') or (W = 'src') or (W = 'text-view') then
  begin
    ShowSource;
    { "/source sample" puts the sample in to be looked at; "/source apply"
      presses Apply - the same two buttons, for a keyboard or a test }
    if Rest = 'sample' then SourceForm.LoadSample
    else if Rest = 'apply' then SourceForm.ApplyNow
    { "/source complete off": the list of words stops popping up by itself
      and comes only on Ctrl+Space - remembered }
    else if (Rest = 'complete off') or (Rest = 'complete on') then
    begin
      FSourceComplete := Rest = 'complete on';
      SourceForm.SetAutoComplete(FSourceComplete);
      if FSourceComplete then
        FCmdMsg := 'The source window offers words as you type.  /source complete off stops it.'
      else
        FCmdMsg := 'The source window offers words only on Ctrl+Space.  /source complete on brings them back.';
    end
    else if Rest <> '' then FCmdMsg := '/source takes sample, apply, complete on or complete off.';
  end
  else if (W = 'jig') or (W = 'jigs') then
  begin
    if SoleGroup > 0 then
    begin
      if RunJigOf(SoleGroup) then
      begin
        RebuildFlatFaces;
        FCmdMsg := 'The jig was run again.';
      end;
      RenderPro;
      RecomposeAll;
    end
    else
      RunAllJigs;
    pbScreen.Invalidate;
  end
  else if (W = 'cube') or (W = 'viewcube') then
  begin
    FCubeHasHot := False;
    if (Rest = 'on') or (Rest = 'off') then
      FCubeOn := Rest = 'on'
    else if (Rest = 'tl') or (Rest = 'tr') or (Rest = 'bl') or (Rest = 'br') then
    begin
      if Rest = 'tl' then FCubeCorner := 0
      else if Rest = 'tr' then FCubeCorner := 1
      else if Rest = 'bl' then FCubeCorner := 2
      else FCubeCorner := 3;
      FCubeOn := True;
      FCmdMsg := 'The cube is ' + CORNER_NAME[FCubeCorner] + '.';
    end
    else if Copy(Rest, 1, 12) = 'fitselection' then
    begin
      N := Pos(' ', Rest);
      if N > 0 then Rest := Trim(Copy(Rest, N + 1, MaxInt)) else Rest := '';
      if Rest = 'off' then FCubeFitSel := False
      else if Rest = 'on' then FCubeFitSel := True
      else FCubeFitSel := not FCubeFitSel;
      if FCubeFitSel then
        FCmdMsg := 'A cube click brings what is picked into the middle and ' +
                   'sizes it.  With nothing picked it just goes to the view.'
      else
        FCmdMsg := 'A cube click goes to the view and leaves the framing alone.';
    end
    else if Rest <> '' then
      FCmdMsg := 'The cube takes on, off, tl, tr, bl, br, or ' +
                 'fitselection on/off.'
    else
      FCubeOn := not FCubeOn;

    if FCmdMsg = '' then
    begin
      if FCubeOn and (FD <> nil) and (FD.View <> vkOrbit) then
        FCmdMsg := 'The cube is on - it shows in a 3D view, and this is not ' +
                   'one.  /3d, or the VIEW button.'
      else if FCubeOn then
        FCmdMsg := 'The cube is on, ' + CORNER_NAME[FCubeCorner] +
                   '.  Click a face, an edge or a corner to look from there; ' +
                   'drag it to turn.'
      else
        FCmdMsg := 'The cube is off.';
    end;
    FScreenDirty := True;
    Relayout;
    pbScreen.Invalidate;
  end
  else if (W = 'toy') or (W = 'etch') or (W = 'etchasketch') then
  begin
    if FMode = mdToy then
      FCmdMsg := 'Already in the toy.  The button up there goes back to pro.'
    else
    begin
      SetMode(mdToy);
      FCmdMsg := 'Have fun.  The button in the corner brings you back.';
    end;
  end
  else if (W = 'pro') or (W = 'promode') then
  begin
    if FMode = mdPro then FCmdMsg := 'Already in pro.'
    else
    begin
      SetMode(mdPro);
      FCmdMsg := 'Back to work.';
    end;
  end
  else if (W = 'holes') or (W = 'openedges') or (W = 'notclosed') then
  begin
    ShowOpenEdges;
  end
  else if W = 'rebuild' then
  begin
    PushUndo;
    I := RebuildFlatFaces;
    RenderPro;
    RecomposeAll;
    if FTurned > 0 then
      FCmdMsg := Format('Worked the faces out again: %d, and turned %d of ' +
        'them the right way out.', [I, FTurned])
    else
      FCmdMsg := Format('Worked the faces out again: %d.', [I]);
  end
  else if (W = 'rebuildfaces') or (W = 'reface') then
  begin
    { Throw the flat faces away and work them out fresh from the lines, as
      if none had ever been drawn.  A file saved by an older build can hold
      faces that no longer match what the lines make of the area -
      concentric rings saved as stacked solids, say - and the ordinary
      rebuild keeps what is there on purpose.  This one does not.

      A solid's faces are left alone, and that is the whole of what this
      learned on 14 September.  It used to throw away every face there was.
      The walls of a duct, a fitting, a spool piece, the body of the example
      toy - none of them have a loop of lines under them to be worked out
      from again, because they were pulled out of a face rather than drawn.
      So they went, and nothing came back: 606 faces on the fittings
      drawing, all of them, and undo the only way home.  What cannot be
      remade is not thrown away. }
    PushUndo;
    SetLength(ReDoomed, FD.Doc.Live);
    J := 0;
    K := 0;
    for I := 0 to FD.Doc.Live - 1 do
    begin
      ReDoomed[I] := (FD.Doc[I].Kind = ekFace) and not FD.Doc[I].Solid;
      if ReDoomed[I] then Inc(J)
      else if FD.Doc[I].Kind = ekFace then Inc(K);
    end;
    FD.Doc.DeleteMarked(ReDoomed);
    SetLength(FD.Seen, 0);
    I := RebuildFlatFaces;
    RenderPro;
    RecomposeAll;
    if K > 0 then
      FCmdMsg := Format('Threw %d flat faces away and worked out %d from the ' +
        'lines.  Left %d alone that belong to a solid - there are no lines ' +
        'under those to work them out from.', [J, I, K])
    else
      FCmdMsg := Format('Threw the faces away and worked them out from the ' +
        'lines: %d.', [I]);
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
  else if (W = 'saveas') or (W = 'save-as') then DoSaveAs
  else if W = 'print' then
  begin
    if (Rest = 'full') or (Rest = '1:1') or (Rest = 'fullsize') or
       (Rest = 'full size') then DoPrintFull('')
    else if (Rest = 'all') or (Rest = 'sheets') then DoPrintSheets(True)
    else DoPrint;
  end
  { the same tiles as pictures, for a print shop - and for looking at what
    the paper would have been without using any }
  else if (W = 'tiles') and (Rest <> '') then DoPrintFull(RawTail(S))
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
  { A file name is not a word, and the command line is lowercased before it
    gets here so that "LINE" and "line" are the same tool.  That folded the
    path too, so /replay on anything under a folder with a capital in it -
    a GIT directory, a Documents folder, anybody's name - said the file did
    not exist.  Found trying to replay a bug report.  Take the tail off the
    line as it was typed, not off the lowercased copy. }
  else if W = 'replay' then
    DoReplayFile(RawTail(S))
  else if (W = 'session') or (W = 'acts') then
  begin
    { What has been recorded so far, without filing a report to see it.  The
      same lines a report carries, so a session can be kept, sent on its own,
      or handed straight back to /replay. }
    { the same as /replay: a path keeps the case it was typed in }
    Rest := RawTail(S);
    if Rest = '' then Rest := 'session.txt';
    try
      with TStringList.Create do
      try
        Text := ActsText;
        SaveToFile(Rest);
        FCmdMsg := Format('%d actions written to %s', [Count, Rest]);
      finally
        Free;
      end;
    except
      on E: Exception do FCmdMsg := 'Could not write it: ' + E.Message;
    end;
  end
  else if (W = 'manual') or (W = 'docs') then OpenManual
  else if (W = 'help') or (W = '?') then ShowAbout
  else
    Result := False;
end;

procedure TMainForm.CommandEnter;
var
  L: Double;
  Why: string;
  SidesN, ArrN: Integer;
  ArrDiv: Boolean;
begin
  { What was typed, and then the Enter - the two together are what turns a
    direction into a measured run, and a replay without them draws nothing.

    A /command is left out.  Whatever it changes - the tool, the view, the
    scale - is recorded by the setter it goes through, so logging the typing
    as well would replay it twice; and /session and /replay themselves have
    no business running again inside a replay. }
  if Copy(FInput, 1, 1) <> '/' then
  begin
    if FInput <> '' then Act('input ' + FInput);
    Act('enter');
  end;
  if FDimEdit >= 0 then
  begin
    CommitDimNote;
    pbCmd.Invalidate;
    Exit;
  end;
  { A cut field is open, so what was typed is a height and belongs to it. }
  if FSliceEdit <> 0 then
  begin
    CommitSliceEdit;
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

  if FArray.Live and ArrayCommand(FInput, ArrN, ArrDiv) then
  begin
    FInput := '';
    ApplyArray(ArrN, ArrDiv);
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

  { 24s or s24 on the circle or arc tool: how many sides, not how big }
  if (FTool in [ptCircle, ptArc]) and ParseSides(FInput, SidesN) then
  begin
    if FTool = ptCircle then FSidesCircle := SidesN else FSidesArc := SidesN;
    FCmdMsg := Format('%d sides from now on.', [SidesN]);
    FInput := '';
    pbCmd.Invalidate;
    pbScreen.Invalidate;
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
    { A dimension is picked and a length was typed: that is somebody saying
      what it ought to read.  It goes here rather than behind a command
      because typing a length and pressing Enter is already how every size in
      this program is given, and a size that has to be given a different way
      is a size people will not think to give. }
    else if (SelectedDim >= 0) and ApplyDimResize(L, True) then
      { said its piece already }
    else if SelectedDim >= 0 then
      { refused, and said why }
    else if (SelectedLine >= 0) and ApplyLineLength(L) then
      { a line picked: its length, SketchUp's Entity Info way }
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
  if FBusy then Exit;
  { a press supersedes whatever motion has not been serviced yet }
  FMoveX := X;
  FMoveY := Y;
  FMovePending := False;
  FMoveShift := Shift;

  { The cube is drawn over the drawing, so a press on it arrives here as a
    press on the drawing.  It takes it first, the same as an open list -
    and it takes EVERY button, not only the one it acts on.  A right press
    that falls through to the model is a context action aimed at a cube, and
    a middle press is an orbit started by somebody reaching for a view. }
  if CubeMouse(X, Y, Button = mbLeft, False) or CubeZone(X, Y) then
  begin
    pbScreen.Invalidate;
    Exit;
  end;

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
  { The source window's Pick: a left press is a point for the text - the
    snapped cursor, the same one every tool works from - and nothing else
    happens on the sheet. }
  if FTextPick and (Button = mbLeft) and (SourceForm <> nil) and (FD <> nil) then
  begin
    SourceForm.TakePoint(FCur, FD.Units);
    FCmdMsg := 'Typed in: ' + Place2(FCur, FD.Units, False) + '.  Next point, or Esc.';
    pbCmd.Invalidate;
    Exit;
  end;
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
    FOrbitGain := OrbitGainAt(X, Y);
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
      FOrbitGain := OrbitGainAt(X, Y);
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
      FEraseMode := EraseModeOf(Shift);
      SetLength(FDoomed, 0);
      DoomAt(X, Y);
      FScreenDirty := True;
      Exit;
    end;
    { the arrow starts a box; a press that never travels is read as a click
      when the button comes back up }
    if ((FTool = ptMove) and (FStage = 1)) or ((FTool = ptRotate) and (FStage = 2)) then
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
        { the undo step waits for the first real move - a press that turns
          out to be a click leaves nothing behind to undo }
        FNoteMoved := False;
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
    Act(Format('press %.6f %.6f %.6f', [FCur.X, FCur.Y, FCur.Z], ActFS));
    { A run of lines is the one case where the press does not decide.  It
      might be a click - another point - or it might be a hold, which lets go
      of the run and places nothing.  Which one it was is not known until the
      button comes up, or until it has been held long enough to break. }
    { The same for push/pull, drill and offset.

      From a note: somebody committed to a push/pull on the way down and knew
      it was wrong before letting the button go.  Those three commit on the press
      going down, so by the time you know it was wrong it is already done and
      the only way out is undo.  They wait for the button to come up now,
      like the drawing tools do: let go and it happens, keep leaning on it
      and the thing you were about to build strains and snaps back having
      built nothing. }
    if (FTool in [ptLine, ptRect, ptCircle, ptArc, ptPush, ptDrill,
                  ptOffset]) and (FStage >= 1) then
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

{ Numbers, not feet and inches: this is parsed back, and a rounded figure
  would replay somewhere slightly else every time. }
procedure TMainForm.Act(const S: string);
begin
  FActs[FActsN mod Length(FActs)] := S;
  Inc(FActsN);
end;

function TMainForm.ActsText: string;
var
  I, First, N: Integer;
begin
  Result := '';
  N := FActsN;
  if N > Length(FActs) then N := Length(FActs);
  First := FActsN - N;
  for I := First to FActsN - 1 do
    Result := Result + '  ' + FActs[I mod Length(FActs)] + LineEnding;
end;

{ Play a recorded session back into the program.

  Not by synthesising mouse events - by handing the same world points to the
  same entry points the mouse feeds.  That is what makes a session recorded on
  somebody else's screen replay here: nothing in it is measured in pixels, so
  nothing depends on the window being the size it was.

  It stops at the first line it does not understand rather than carrying on
  and producing a different drawing, because a replay that quietly diverges is
  worse than one that stops and says where. }
{ Replay a session out of a bug report.

  The whole report is handed over, not a trimmed-out fragment, because asking
  somebody to cut the right lines out of a text file is asking for the one
  mistake that makes it not work.  The section is found by its heading and
  read to the end of the indented block. }
procedure TMainForm.DoReplayFile(const FileName: string);
const
  MARK = 'to replay';
var
  L, Body: TStringList;
  I: Integer;
  Fn: string;
  Inside: Boolean;
begin
  Fn := Trim(FileName);
  if Fn = '' then Fn := 'replay.txt';
  if not FileExists(Fn) then Fn := ExtractFilePath(ParamStr(0)) + Fn;
  if not FileExists(Fn) then
  begin
    FCmdMsg := 'No such file: ' + Trim(FileName) +
      '  - /replay <a report .txt, or a file of session lines>';
    pbCmd.Invalidate;
    Exit;
  end;

  L := TStringList.Create;
  Body := TStringList.Create;
  try
    try
      L.LoadFromFile(Fn);
    except
      on E: Exception do
      begin
        FCmdMsg := 'Could not read it: ' + E.Message;
        pbCmd.Invalidate;
        Exit;
      end;
    end;

    Inside := False;
    for I := 0 to L.Count - 1 do
    begin
      if not Inside then
      begin
        if Pos(MARK, LowerCase(L[I])) > 0 then Inside := True;
        Continue;
      end;
      { the block runs while the lines stay indented; the next heading ends it }
      if (Trim(L[I]) <> '') and (Copy(L[I], 1, 1) <> ' ') then Break;
      if Trim(L[I]) <> '' then Body.Add(Trim(L[I]));
    end;

    { a bare file of session lines works too }
    if Body.Count = 0 then
      for I := 0 to L.Count - 1 do
        if Trim(L[I]) <> '' then Body.Add(Trim(L[I]));

    if Body.Count = 0 then
      FCmdMsg := 'Nothing in there that looks like a session.'
    else
      FCmdMsg := Format('replayed %d of %d', [ReplayActs(Body.Text), Body.Count]);
  finally
    Body.Free;
    L.Free;
  end;
  pbCmd.Invalidate;
end;

function TMainForm.ReplayActs(const Script: string): Integer;
var
  L: TStringList;
  P: TStringList;
  I: Integer;
  Cmd, Rest: string;
  T: TProTool;
  Fired: Boolean;
  SP: TPointF;

  function Num(K: Integer): Double;
  begin
    if not TryStrToFloat(P[K], Result, ActFS) then Result := 0;
  end;

begin
  Result := 0;
  L := TStringList.Create;
  P := TStringList.Create;
  try
    L.Text := Script;
    P.Delimiter := ' ';
    P.StrictDelimiter := True;

    for I := 0 to L.Count - 1 do
    begin
      P.DelimitedText := Trim(L[I]);
      if P.Count = 0 then Continue;
      Cmd := LowerCase(P[0]);
      Rest := Trim(Copy(Trim(L[I]), Length(P[0]) + 1, MaxInt));
      Fired := True;

      if (Cmd = 'press') and (P.Count >= 4) then
      begin
        FCur := P3(Num(1), Num(2), Num(3));
        { And where that lands on the screen.

          A press was replayed as a world point and nothing else, which is
          right for the tools that work in the model - line, rectangle,
          move - and silently wrong for every tool that asks what is under
          the pointer.  Revolve wants the face there, push/pull wants the
          face there, the eraser wants whatever is there, and all three were
          being asked about wherever the mouse happened to have been left.
          The point is known, the projection is to hand, so say it. }
        SP := ScreenOf(FCur);
        FMouseSX := Round(SP.X);
        FMouseSY := Round(SP.Y);
        FSnapKind := snGrid;
        { And which face.  The point is on the face that was pressed, so
          the face is the one that holds the point - found in the model,
          not under the pixel, where a different camera or window finds a
          different face behind the same pixel.  21 September: a report
          replayed in a smaller window pushed a neighbor's top instead. }
        FReplayFace := FD.Doc.FaceHolding(FCur);
        try
          ProClick;
        finally
          FReplayFace := -1;
        end;
      end
      else if Cmd = 'tool' then
      begin
        Fired := False;
        for T := Low(TProTool) to High(TProTool) do
          if SameText(TOOL_NAMES[T], Rest) then
          begin
            SetTool(T);
            Fired := True;
            Break;
          end;
      end
      else if Cmd = 'input' then
        FInput := Rest
      else if (Cmd = 'dir') and (P.Count >= 2) then
        FDirLock := StrToIntDef(P[1], -1)
      else if Cmd = 'enter' then
        CommandEnter
      else if Cmd = 'undo' then
        DoUndo
      else if Cmd = 'redo' then
        DoRedo
      else if Cmd = 'clear' then
        StartErase
      else if Cmd = 'view' then
      begin
        if SameText(Rest, 'PLAN') then SetView(vkPlan)
        else if SameText(Rest, 'ISO') then SetView(vkIso)
        else if SameText(Rest, '3D') then SetView(vkOrbit)
        else Fired := False;
      end
      else if (Cmd = 'scale') and (P.Count >= 2) then
        SetScaleIdx(StrToIntDef(P[1], FD.ScaleIdx))
      else if (Cmd = 'snap') and (P.Count >= 2) then
        FD.SnapIdx := EnsureRange(StrToIntDef(P[1], FD.SnapIdx), 0, SNAP_COUNT - 1)
      else if (Cmd = 'units') and (P.Count >= 2) then
        SetUnits(TUnitSystem(EnsureRange(StrToIntDef(P[1], 0), 0, 1)))
      else
        Fired := False;

      if not Fired then
      begin
        FCmdMsg := Format('replay stopped at line %d: %s', [I + 1, Trim(L[I])]);
        Break;
      end;
      Inc(Result);
    end;
  finally
    P.Free;
    L.Free;
  end;

  { the replay wrote its own actions into the log as it went; drop them so the
    next report carries the session, not the session played twice }
  FActsN := 0;
  RenderPro;
  RecomposeAll;
  RefreshChrome;
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
    ('lines', 'arcs', 'notes', 'dims', 'faces', 'guides', 'bore', 'groups');
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

{ The machine, for the report: what uSysInfo can tell without asking or
  running anything, and what the program itself is using.  No path, no
  name, nothing about the person - see the note at the top of uSysInfo. }
{ Every report that goes out is kept beside the program too, text and
  picture under the same name, so what was sent can be read back on the
  machine it came from. }
procedure TMainForm.KeepReportCopy(const AName, Body: string; Shot: TStream);
var
  Dir: string;
  L: TStringList;
  F: TFileStream;
begin
  try
    Dir := AppDataDir + 'reports-sent' + PathDelim;
    if not ForceDirectories(Dir) then Exit;
    L := TStringList.Create;
    try
      L.Text := Body;
      L.SaveToFile(Dir + AName);
    finally
      L.Free;
    end;
    if (Shot <> nil) and (Shot.Size > 0) then
    begin
      F := TFileStream.Create(Dir + ChangeFileExt(AName, '.png'), fmCreate);
      try
        Shot.Position := 0;
        F.CopyFrom(Shot, Shot.Size);
      finally
        F.Free;
      end;
    end;
  except
    { a copy that could not be written is not a reason to keep the report }
  end;
end;

function TMainForm.MachineText: string;
begin
  try
    Result := SystemFacts +
      'program memory: ' + ProgramMemory + LineEnding +
      Format('program: up %d s, threads=%s, quick frames=%s',
        [(GetTickCount64 - FStartedAt) div 1000, BoolToStr(FThreads, True),
         BoolToStr(FQuickFrames, True)]) + LineEnding;
  except
    on E: Exception do Result := 'machine facts failed: ' + E.ClassName + LineEnding;
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
      'repairs=%d%s',
      [FArt.Width, FArt.Height, FArt.Stride,
       FPaper.Width, FPaper.Height, FPaper.Stride,
       FInkPro.Width, FInkPro.Height, FInkPro.Stride,
       FInkToy.Width, FInkToy.Height, FInkToy.Stride,
       TArtSurface.Repairs,
       { the depth buffer this document was borrowing has been freed at some
         point - an export made its own surface and threw it away.  Harmless
         now, but it was an access violation until 16 September, so a report
         that mentions it is worth a second look. }
       specialize IfThen<string>(FD.Doc.LastSurfDied,
         ' borrowed-depth-was-freed', '')]) + LineEnding +
    { How the frames have been going.  A count of the ones that took longer
      than a fortieth of a second since the program started, the worst of
      them, and the breakdown of the last one - so a report that says it felt
      glitchy arrives with the numbers rather than needing them asked for.
      The individual lines are in the log below, at most one every two
      seconds. }
    IfThen(FSlowN = 0, 'frames: none over 40ms',
      Format('frames: %d over 40ms, worst %dms, last was %s',
        [FSlowN, FSlowWorst, FSlowLast])) + LineEnding +
    'what was happening, most recent last:' + LineEnding + TrailText +
    { The same session again, in world coordinates, so it can be played back
      rather than read.  With the drawing below it a report is self-contained:
      load one, run the other, and the fault happens here instead of being
      described.  Recorded only from this window's own handlers - it has never
      been able to see anything typed anywhere else. }
    LineEnding + 'the same session, to replay - /replay after loading the ' +
    'drawing below:' + LineEnding + ActsText;
end;

{ Everything else the program knows about how it was being used.

  From a note, 17 September, after a report about sluggishness that did not say the
  grid was off: "the reports need to include as much info as possible ...
  it could mean 10 hours tracing a bug or 10 minutes."  So this is the long
  list - how it was started, the window and the screen it is on, the view
  cube, what every tool is set to, every sheet that is open, and what was
  on the go - and it is cheap, because every line is a field already held.

  The rule from uSysInfo still holds: nothing about the person.  A file
  named on the command line is written as <file>, never as its path, and a
  sheet is numbered rather than named.  Each group is guarded on its own so
  one bad value costs a line, not the report. }
function TMainForm.SettingsText: string;
const
  FILL_NAMES: array[0..2] of string = ('normal', 'maximized', 'full screen');
  TOUCH_NAMES: array[TTouchMode] of string =
    ('none', 'pending', 'as mouse', 'gesture', 'spent');
  CORNER_NAMES: array[0..3] of string =
    ('top left', 'top right', 'bottom left', 'bottom right');
  ERASE_NAMES: array[0..2] of string = ('delete', 'soften', 'unsoften');
  PLANE_NAMES: array[TPlane] of string = ('XY', 'XZ', 'YZ', 'free');
  TAPE_NAMES: array[0..3] of string =
    ('line and point', 'point', 'line', 'nothing');
  KIND_NAMES: array[TEntKind] of string =
    ('line', 'arc', 'note', 'dim', 'face', 'guide', 'bore', 'group');
var
  R: string;

  procedure Add(const Line: string);
  begin
    R := R + Line + LineEnding;
  end;

  function YN(B: Boolean): string;
  begin
    if B then Result := 'on' else Result := 'off';
  end;

  function Args: string;
  var
    I, Eq: Integer;
    A: string;
  begin
    Result := '';
    for I := 1 to ParamCount do
    begin
      A := ParamStr(I);
      if (A = '') or (A[1] <> '-') then
        A := '<file>'
      else
      begin
        { a switch's value is kept unless it looks like a place on disk }
        Eq := Pos('=', A);
        if (Eq > 0) and ((Pos('/', A) > 0) or (Pos('\', A) > 0) or
           (Pos(':', Copy(A, Eq, MaxInt)) > 0)) then
          A := Copy(A, 1, Eq) + '<file>';
      end;
      Result := Result + ' ' + A;
    end;
    if Result = '' then Result := ' (none)';
  end;

  function SelKinds: string;
  var
    N: array[TEntKind] of Integer;
    K: TEntKind;
    I: Integer;
  begin
    for K := Low(TEntKind) to High(TEntKind) do N[K] := 0;
    for I := 0 to High(FSel) do
      if (FSel[I] >= 0) and (FSel[I] < FD.Doc.Live) then
        Inc(N[FD.Doc[FSel[I]].Kind]);
    Result := '';
    for K := Low(TEntKind) to High(TEntKind) do
      if N[K] > 0 then
        Result := Result + Format(' %s=%d', [KIND_NAMES[K], N[K]]);
    if Result = '' then Result := ' none';
  end;

  function Forms_: string;
  var
    I: Integer;
  begin
    Result := '';
    for I := 0 to Screen.CustomFormCount - 1 do
      if Screen.CustomForms[I].Visible then
        Result := Result + ' ' + Screen.CustomForms[I].ClassName;
    if Screen.ActiveCustomForm <> nil then
      Result := Result + '  (active ' + Screen.ActiveCustomForm.ClassName + ')';
    if Screen.ActiveControl <> nil then
      Result := Result + '  (focus ' + Screen.ActiveControl.ClassName + ')';
  end;

var
  I, J, Groups, G, Grps: Integer;
  Known: Boolean;
  D: TDrawing;
  M: TMonitor;
  Seen: array of Integer;
begin
  R := '';
  try
    Add('started with:' + Args);
    Add(Format('run tag=%s  updated from=%s  whats new shown=%s  ' +
      'draft restored=%s (age %d)  crash offered=%s  offline=%s',
      [FRunTag, specialize IfThen<string>(FUpdatedFrom = '', '-', FUpdatedFrom),
       YN(FWhatsNewShown), YN(FRestored), FDraftAge, YN(FCrashToOffer),
       YN(NetOffline)]));
    Add(Format('update seen=%s  help pages=%s%s  drawing file=%s  ' +
      'threads=%s  timings=%s',
      [specialize IfThen<string>(FUpdateTag = '', '-', FUpdateTag),
       specialize IfThen<string>(LocalHelpVersion = '', 'none', LocalHelpVersion),
       specialize IfThen<string>(HelpFetching <> nil, ' (fetching)', ''),
       specialize IfThen<string>(FDocPath = '', 'never saved', 'saved as ' +
         ExtractFileExt(FDocPath)),
       YN(FThreads), YN(FTimings)]));
  except
    on E: Exception do Add('start facts failed: ' + E.ClassName);
  end;

  try
    Add(Format('window: %s  %d,%d %dx%d  state=%d  client %dx%d  ' +
      'drawing area %dx%d  tools wide=%s  info panel=%s  dials=%s',
      [FILL_NAMES[Ord(FFill)], Left, Top, Width, Height, Ord(WindowState),
       ClientWidth, ClientHeight, pbScreen.Width, pbScreen.Height,
       YN(FToolsWide), YN(FInfoOn), YN(FProDials)]));
    M := Monitor;
    if M <> nil then
      Add(Format('on monitor %d of %d: %d,%d %dx%d at %d dpi (screen says %d)' +
        ', primary=%s',
        [M.MonitorNum + 1, Screen.MonitorCount, M.Left, M.Top, M.Width,
         M.Height, M.PixelsPerInch, Screen.PixelsPerInch, YN(M.Primary)]));
    Add('forms showing:' + Forms_);
  except
    on E: Exception do Add('window facts failed: ' + E.ClassName);
  end;

  try
    Add(Format('look: theme=%s grid=%s edge width=%d ink=%s%s ' +
      'rounded to 1/%d  circle sides=%d arc sides=%d',
      [Theme.Name, YN(FShowGrid), FEdgeW, IntToHex(ColorToRGB(FInkColor), 6),
       specialize IfThen<string>(FInkAuto, ' (auto)', ''),
       FLenDenom, FSidesCircle, FSidesArc]));
    Add(Format('view cube=%s corner=%s fit to selection=%s hot=%s ' +
      'dragging=%s  glide=%.2f  orbit snap target=%s  preset=%d',
      [YN(FCubeOn), CORNER_NAMES[FCubeCorner and 3], YN(FCubeFitSel),
       YN(FCubeHasHot), YN(FCubeDrag), FGlideT, YN(FSnapHasHot),
       FViewPreset]));
  except
    on E: Exception do Add('look facts failed: ' + E.ClassName);
  end;

  try
    Add(Format('tool options: tape leaves=%s erase=%s move copy=%s ' +
      'rigid=%s detach=%s dirlock=%d last push=%s last radius=%s ' +
      'fillet pending=%s',
      [TAPE_NAMES[Max(0, Min(3, FTapeDrop))], ERASE_NAMES[Max(0, Min(2, FEraseMode))], YN(FMoveCopy),
       YN(FMoveRigid), YN(FDetachMove), FDirLock,
       FormatLen(FLastPush, FD.Units), FormatLen(FLastFilletR, FD.Units),
       YN(FFilletPending)]));
    Add(Format('going on: typed="%s" popup=%d clicks=%d boxing=%s ' +
      'panning=%s orbiting=%s freehand=%s erasing=%s moving=%s busy=%s ' +
      'loading=%s dim edit=%d cut edit=%d camera moving=%s',
      [FInput, FPopup, FClickN, YN(FBoxing), YN(FPanning), YN(FOrbiting),
       YN(FFreehand), YN(FErasing2), YN(FMovePending), YN(FBusy),
       YN(FLoading), FDimEdit, FSliceEdit, YN(FCameraMoving)]));
    Add(Format('bar said: "%s"', [FCmdMsg]));
    Add(Format('touch: seen=%s mode=%s down=%s points=%d  keys: arrows=%s%s%s%s ' +
      'boost=%s precise=%s',
      [YN(FTouchOn), TOUCH_NAMES[FTouchMode], YN(FTouchDown), FTouchCount,
       specialize IfThen<string>(FKeyLeft, 'L', '-'),
       specialize IfThen<string>(FKeyRight, 'R', '-'),
       specialize IfThen<string>(FKeyUp, 'U', '-'),
       specialize IfThen<string>(FKeyDown, 'D', '-'),
       YN(FBoost), YN(FPrecise)]));
    Add('selected:' + SelKinds);
    if FMode = mdToy then
      Add(Format('toy: pen=%d style=%s hue=%.0f symmetry=%d mirror=%s auto=%s',
        [FPenSize, STYLE_NAMES[FStyle], FHue, FSym, YN(FMirror), YN(FAuto)]));
  except
    on E: Exception do Add('tool facts failed: ' + E.ClassName);
  end;

  try
    Add(Format('sheets open: %d', [Length(FDrawings)]));
    for I := 0 to High(FDrawings) do
    begin
      D := FDrawings[I];
      if D = nil then Continue;
      { solids, counted by their group numbers }
      Groups := 0;
      SetLength(Seen, 0);
      for G := 0 to D.Doc.Live - 1 do
      begin
        Grps := D.Doc[G].Grp;
        if Grps <= 0 then Continue;
        Known := False;
        for J := 0 to High(Seen) do
          if Seen[J] = Grps then Known := True;
        if not Known then
        begin
          SetLength(Seen, Length(Seen) + 1);
          Seen[High(Seen)] := Grps;
          Inc(Groups);
        end;
      end;
      { The name as well as the number.  A report came in with tabs called
        "Broom" and "Sheet 1", in that order - so "sheet 2 (showing)" was the
        one named "Sheet 1", and the first hour of reading it was spent on
        the wrong drawing.  The name is what the person sees on the tab, so
        it is what they mean when they say which sheet they were on. }
      Add(Format('  sheet %d%s "%s": things=%d solids=%d open group=%d modified=%s view=%s ' +
        'plane=%s units=%s scale=%s snap=%s zoom=%.3f az=%.1f el=%.1f ' +
        'cut=%s (%s to %s) guides=%s undo=%d redo=%d',
        [I + 1, specialize IfThen<string>(I = FTabIdx, ' (showing)', ''),
         D.Name, D.Doc.Live, Groups, D.Doc.Context, YN(D.Dirty), VIEW_NAMES[D.View], PLANE_NAMES[D.Plane],
         uWork.UnitName(D.Units), ScaleTable(D.Units, D.ScaleIdx).Name,
         SnapName(D.Units, D.SnapIdx), D.Zoom, RadToDeg(D.Az),
         RadToDeg(D.El), YN(D.SliceOn), FormatLen(D.SliceLo, D.Units),
         FormatLen(D.SliceHi, D.Units),
         specialize IfThen<string>(D.Doc.GuidesHidden, 'hidden', 'shown'),
         D.UndoTop, D.RedoTop]));
    end;
  except
    on E: Exception do Add('sheet facts failed: ' + E.ClassName);
  end;
  Result := R;
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
      Write(F, SettingsText);
      Write(F, MachineText);
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
  { Most exceptions do not take the program down - the handler catches them
    and the window carries on.  So the report used to sit unmentioned until
    the next start, by which time nobody remembered what they had been
    doing.  Offer it now, from the tick, once this handler has returned. }
  if FWoundCount < 3 then FCrashToOffer := True;
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
  if FBusy then Exit;
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
  HeldU, HeldV: TP3;
  SpeedNow: QWord;
  SpeedInst: Double;
  X, Y, HF: Integer;
  HP, HN, HoverP: TP3;
  OP: TPointF;
  NewAz, NewEl: Double;
begin
  if not FMovePending then Exit;
  FMovePending := False;
  X := FMoveX;
  Y := FMoveY;
  { the pointer's speed, for the alignment nudges to wait on }
  SpeedNow := GetTickCount64;
  if (FLastMoveTick > 0) and (SpeedNow > FLastMoveTick) then
  begin
    SpeedInst := Sqrt(Sqr(X - FLastMoveX) + Sqr(Y - FLastMoveY)) * 1000 / (SpeedNow - FLastMoveTick);
    FMoveSpeed := FMoveSpeed * 0.5 + SpeedInst * 0.5;
  end
  else if SpeedNow - FLastMoveTick > 150 then
    FMoveSpeed := 0;
  FLastMoveTick := SpeedNow;
  FLastMoveX := X;
  FLastMoveY := Y;

  { An open list takes the mouse, and nothing else gets it.

    The row under the cursor was never worked out - the field for it existed
    and the paint code knew how to light a row, but nothing ever set it, so
    no row ever lit.  Meanwhile the drawing carried on snapping and inferring
    underneath, which is what made a list opened over the drawing feel like
    two things fighting for the pointer.  A menu that will not say which row
    you are about to press is a menu you have to aim at twice. }
  { The cube, before the drawing and before the popup - a list opened over it
    would otherwise both light up.

    The cursor changes too.  A drawing crosshair hovering over a control is
    the program saying it is about to draw on it, which it is not: the same
    reason an open list swaps the cursor for an arrow. }
  if CubeMouse(X, Y, False, False) or CubeZone(X, Y) then
  begin
    FMouseSX := X;
    FMouseSY := Y;
    if not FCubeCursor then
    begin
      FCubeCursor := True;
      FCursorWasCube := pbScreen.Cursor;
    end;
    { a hand on the shape, a plain arrow in the margin round it }
    if FCubeHasHot then pbScreen.Cursor := crHandPoint
    else pbScreen.Cursor := crDefault;
    Exit;
  end;
  if FCubeCursor then
  begin
    FCubeCursor := False;
    pbScreen.Cursor := FCursorWasCube;
  end;

  if FPopup <> POP_NONE then
  begin
    FMouseSX := X;
    FMouseSY := Y;
    HF := PopupItemAt(X, Y);
    { The command list is being typed at, so the pointer wandering off it
      must not take the highlight with it - the row Enter would run has to
      stay put while somebody is looking at the keyboard.  Hovering a row
      still moves it; leaving the list simply leaves it where it was. }
    if (HF < 0) and (FPopup = POP_CMDS) then HF := FPopupHot;
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
    { Where letting go would take it, worked out every move so the cube can
      light the target and the status line can name it.  Showing it is what
      makes this feel considered rather than magic: you can see where it is
      going before you commit, and let Ctrl go if you would rather not. }
    FSnapHasHot := FOrbiting and (ssCtrl in FMoveShift) and
                   OrbitSnapTarget(FSnapHot);
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
      { The rate depends on where the press went down.  Set beside SketchUp
        on 21 September: pressed near the middle of the view, theirs turns
        slowly and wants a lot of mouse; pressed out at the edge, the same
        mouse turns it fast - and it turns about the middle either way.
        That is a trackball: a ball as wide as the view, its middle at the
        middle of the screen.  A push on its face turns it a little; a push
        on its rim spins it.  So the turn per pixel grows with the press's
        distance from the middle, from half the rate there to twice at the
        edge, and it is fixed for the whole drag - it is where you took
        hold that matters, not where the hand is now. }
      NewAz := FD.Az - (X - FPanRefX) * ORBIT_RAD_PX * FOrbitGain;
      NewEl := FD.El + (Y - FPanRefY) * ORBIT_RAD_PX * FOrbitGain;
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
      FCameraMoving := True;
      ViewMoved;
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
    if ((FTool = ptMove) and (FStage = 1)) or ((FTool = ptRotate) and (FStage = 2)) then
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
      if not FNoteMoved then
      begin
        PushUndo;
        FNoteMoved := True;
      end;
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
    { A plane held by an arrow keeps its direction, but it still passes
      through the face under the cursor when there is one facing the same
      way: the arrow says which way the shape lies, not that it should float
      at wherever the cursor last was. }
    if (FStage = 0) and FPlaneHeld and (FD.Plane <> plFree) and
       (FTool in [ptLine, ptRect, ptCircle, ptArc]) and
       FD.Doc.FaceUnder(Proj, X, Y, HF, HP) then
    begin
      HN := Norm3(FD.Doc.FaceNormal(HF));
      PlaneAxes(FD.Plane, HeldU, HeldV);
      if Abs(Abs(Dot3(Norm3(Cross3(HeldU, HeldV)), HN)) - 1) < 1E-3 then
        FCur := HP;
    end;
    if (FStage = 0) and not FPlaneHeld and
       (FTool in [ptLine, ptRect, ptCircle, ptArc]) and
       FD.Doc.FaceUnder(Proj, X, Y, HF, HP) then
    begin
      HN := FD.Doc.FaceNormal(HF);
      { A face square to an axis gets the matching flat plane, because those
        have their own quick arithmetic and their own color.  Anything else -
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
      { The same order the click uses, so what lights up is what goes - and
        no face, because the click will not take one.  It used to hover by
        HitTest alone, which cannot find the inside of a face, so sweeping
        across a panel showed nothing and then deleted it anyway; then it
        looked for the face as well, which was right while the click took
        faces and is a lie now that it does not.  A red wash over a face the
        eraser is not going to take is the same fault the other way round. }
      FHoverEnt := FD.Doc.HitNote(X, Y);
      if FHoverEnt < 0 then
        { the eraser keeps its full reach on a guide: rubbing one out is
          what the eraser is for, and nothing else is lost by taking it }
        FHoverEnt := FD.Doc.HitGuidePoint(Proj, X, Y, 10 * FUIScale);
      if FHoverEnt < 0 then
        FHoverEnt := FD.Doc.HitEdge(Proj, X, Y, 9 * FUIScale);
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
      { and it does not light up when the cursor is on a point of it: that
        click takes the point, not the edge }
      FHoverEdgeOK := False;
      if FSnapKind in [snEndpoint, snMidpoint, snCenter, snCross, snSubMid, snOrigin] then
        FHoverEnt := -1
      else
      begin
        { EdgeUnder rather than HitEdge, so the outline of a face counts.
          HitEdge looks at lines, arcs, dimensions and guides and nothing
          else - which is why the cursor would say ON EDGE on the case of
          the etch-a-sketch while this lit nothing up and the click fell
          through to a point-to-point. }
        FHoverEdgeOK := FD.Doc.EdgeUnder(Proj, X, Y, 9 * FUIScale,
          HoverP, FHoverEdgeA, FHoverEdgeB, FHoverEnt);
        if FHoverEdgeOK and (FD.Doc[FHoverEnt].Kind = ekGuide) then
        begin
          { a guide is a construction line; measuring "all of it" means
            measuring something infinite }
          FHoverEdgeOK := False;
          FHoverEnt := -1;
        end;
        if not FHoverEdgeOK then FHoverEnt := -1;
      end;
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
    if (FTool in [ptPush, ptDrill, ptOffset, ptFollow]) and (FStage = 0) then
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

  That is the crash It was reported: orbiting an empty drawing swings the
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
  what stays put there is the canvas center rather than the thing you
  grabbed.  The two only disagree once the drawing has been panned off
  center.  Pinning what you grabbed felt right in use and it is the smaller
  idea, so it stands; do not quietly convert this to a camera target because
  it is what SketchUp does internally.  If the canvas center is ever seen to
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

{ A fifth at the middle of the view, twice at its edge, and it grows with
  the distance squared - so the middle third of the view is slow all over,
  not only at the exact center, and the speed comes on out toward the rim.
  The first cut went straight from half to twice and a press an inch off
  the middle was already at the old rate, which is what "I put it down in
  the middle and it was just as fast" was. }
function TMainForm.OrbitGainAt(SX, SY: Integer): Double;
var
  R, RMax, T: Double;
begin
  R := Sqrt(Sqr(SX - pbScreen.Width / 2) + Sqr(SY - pbScreen.Height / 2));
  RMax := Min(pbScreen.Width, pbScreen.Height) / 2;
  if RMax < 1 then Exit(1);
  T := Min(1, R / RMax);
  Result := 0.2 + 1.8 * T * T;
end;

function TMainForm.PivotAt(SX, SY: Integer): TP3;
var
  F: Integer;
  P, Lo, Hi: TP3;
  Pts: TP3Array;

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
  { The thing under the cursor first; failing that, the nearest drawn thing
    to it, off the last frame's depth buffer - a fitting zoomed in on is
    mostly edges and hollow, and the cursor is seldom exactly on a face.
    Then what is selected, then the point under the middle of the screen.
    The middle of the whole drawing comes last: zoomed in on one fitting of
    a big drawing, turning about a point a hundred feet away swung the
    fitting straight out of the view, which is what orbiting at a zoom
    felt like. }
  { About the middle of the screen, not the point under the pointer.  It was
    the pointer's point, and it read as wrong both ways it was tried: the
    press felt like it grabbed the model there, and the model then turned
    about a point off to one side.  SketchUp turns about what is under the
    middle of the view, which is where you are looking - and set beside it
    on 21 September that was the difference.  So: the drawn thing under the
    middle, then the nearest drawn thing to the middle off the depth
    buffer, then what is picked, then the drawing's own middle. }
  SX := pbScreen.Width div 2;
  SY := pbScreen.Height div 2;
  if FD.Doc.FaceUnder(Proj, SX, SY, F, P) and Grabbable(P) then
    Exit(P);
  if FD.Doc.DepthPointNear(SX, SY, 4000, P) and Grabbable(P) then
    Exit(P);
  if Length(FSel) > 0 then
  begin
    FD.Doc.VertsOf(FSel, Pts);
    if Length(Pts) > 0 then
    begin
      P := P3(0, 0, 0);
      for F := 0 to High(Pts) do P := P3(P.X + Pts[F].X, P.Y + Pts[F].Y, P.Z + Pts[F].Z);
      P := P3(P.X / Length(Pts), P.Y / Length(Pts), P.Z / Length(Pts));
      if Grabbable(P) then Exit(P);
    end;
  end;
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
    { one row past the palette, for a color that is not on it.  A list can
      hold more than a row of swatches ever could, and twelve colors with
      no way to ask for a thirteenth is the row's limit brought along by
      accident. }
    POP_COLOR: Result := Length(PALETTE) + 1;
    POP_WIDTH: Result := PEN_STEPS;
    POP_HELP: Result := 7;
    POP_SHOP: Result := 4;
    POP_PREC: Result := Length(PREC_DENOMS);
    POP_MORE: Result := Length(MORE_TOOLS);
    POP_CMDS: Result := Length(CMD_LIST);
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
    POP_COLOR:
      if I = Length(PALETTE) then Result := 'Another color...' else Result := '';
    POP_WIDTH: Result := Format('%d px', [PEN_SIZES[I]]);
    POP_SHOP:
      case I of
        0: Result := 'Lay a selection out flat(incomplete)';
        1: Result := 'Build a duct fitting...';
        2: Result := 'Fitter''s ISO spool scratchpad';
        3: Result := 'Radiant heat layout...';
      else
        Result := '';
      end;
    POP_PREC:
      if PREC_DENOMS[I] = 100 then Result := 'hundredths of an inch'
      else Result := Format('1/%d"', [PREC_DENOMS[I]]);
    POP_MORE:
      if (I >= 0) and (I <= High(MORE_TOOLS)) then
        Result := TOOL_NAMES[MORE_TOOLS[I]]
      else
        Result := '';
    POP_CMDS:
      if (I >= 0) and (I < Length(FCmdOrder)) then
        Result := '/' + CMD_LIST[FCmdOrder[I]].Name
      else
        Result := '';
    POP_HELP:
      case I of
        0: Result := 'About  (F1)';
        1: Result := 'Check for updates';
        2: Result := 'What''s new';
        3: Result := 'Downloads';
        4: Result := 'The manual';
        5: Result := 'Report a problem';
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
    POP_COLOR:
      if I = Length(PALETTE) then PickAnyColor
      else SetInk(PALETTE[I], False);
    POP_WIDTH: SetPenSize(PEN_SIZES[I]);
    POP_SHOP:
      case I of
        0: StartUnfold;
        1: BuildTransitionWizard;
        2: BuildSpoolWizard;
        3: BuildRadiantWizard;
      end;
    POP_PREC: SetLenPrecision(PREC_DENOMS[EnsureRange(I, 0, High(PREC_DENOMS))]);
    POP_MORE:
      if (I >= 0) and (I <= High(MORE_TOOLS)) then SetTool(MORE_TOOLS[I]);
    POP_CMDS:
      if (I >= 0) and (I < Length(FCmdOrder)) then
      begin
        NoteCmdUsed(CMD_LIST[FCmdOrder[I]].Name);
        { One that wants something after it is typed into the box ready for
          it rather than run - running /scale with nothing after it is a
          question, not an answer.  One that does not is simply done: the
          whole point of picking it off a list is not having to type. }
        if CMD_LIST[FCmdOrder[I]].Arg then
        begin
          FInput := '/' + CMD_LIST[FCmdOrder[I]].Name + ' ';
          FCmdMsg := CMD_LIST[FCmdOrder[I]].Hint;
        end
        else
        begin
          FInput := '';
          RunCommand(CMD_LIST[FCmdOrder[I]].Name);
        end;
        pbCmd.Invalidate;
      end;
    POP_HELP:
      case I of
        0: ShowAbout;
        1: begin CheckForUpdate(True); DoUpdate; end;
        2: ShowWhatsNew;
        3: OpenInBrowser('https://github.com/' + UPDATE_REPO + '/releases/latest');
        4: OpenManual;
        5: ReportBug;
      else
        OpenInBrowser('https://github.com/' + UPDATE_REPO);
      end;
  end;
  RebuildDeck;
  pbDeck.Invalidate;
end;

{ How tall a list is allowed to get.

  Most of them are short enough that it never comes up.  The command list is
  not: sixty-odd rows at twenty-two pixels is taller than the window, and
  before this it simply ran the whole height of it - a wall of text from the
  prompt to the title bar, over the top of the drawing the command is about
  to act on.  Half the window is enough to choose from and leaves the model
  visible behind it, and the rest of the list is a scroll away. }
function TMainForm.PopupMaxHeight(Which: Integer): Integer;
begin
  Result := pbScreen.Height - 20;
  if Which = POP_CMDS then
    Result := Min(Result, Max(Round(180 * FUIScale), pbScreen.Height div 2));
end;

procedure TMainForm.OpenPopup(Which: Integer);
var
  N, I, W, H, RowH, LeftX, Bottom, TopY, RightMost: Integer;
  B: TRect;
begin
  N := PopupCount(Which);
  if N <= 0 then Exit;
  FPopup := Which;
  FPopupN := N;
  FPopupHot := -1;
  FPopupTop := 0;
  if Which = POP_CMDS then BuildCmdOrder;
  { An arrow over a menu, not a drawing crosshair.  The pointer is choosing a
    row, not a point on the paper. }
  FCursorWas := pbScreen.Cursor;
  pbScreen.Cursor := crDefault;

  { find the button it belongs to, and hang the list off it }
  LeftX := Round(20 * FUIScale);
  TopY := -1;
  { the strip first: a list opened from a button on the left belongs beside
    that button, not at the foot of the drawing thirty inches away from it }
  for I := 0 to High(FTools) do
    if (FTools[I].Group = GRP_POPUP) and (FTools[I].Value = Which) then
    begin
      B := FTools[I].Bounds;
      LeftX := Round(4 * FUIScale);
      TopY := pbTools.Top + B.Top - pbScreen.Top;
      Break;
    end;
  { the command list hangs off the arrow beside the prompt, at the foot }
  if Which = POP_CMDS then
  begin
    LeftX := Round(14 * FUIScale);
    TopY := -1;
  end
  else
  if TopY < 0 then
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
  { wide, because every row carries what the command does beside its name -
    a hint you have to hover for is a hint you have to already suspect }
  if Which = POP_CMDS then W := Round(430 * FUIScale);
  H := Min(N * RowH + Round(12 * FUIScale), PopupMaxHeight(Which));
  Bottom := pbScreen.Height - Round(6 * FUIScale);
  { How far right a list may go.

    It used to be the drawing's own right edge, which is right until the
    entity panel is open: the deck runs the whole width of the window, so
    with the panel taking the right of the drawing, the HELP button is
    further right than the drawing goes.  The list was then pushed back to
    the edge of the paper and stood there, a panel's width away from the
    button it belongs to.  From a note: "the help menu popup menu is not aligned
    above the button anymore it is aligning to the edge of the canvas paint
    area which is annoying".

    So the limit is the deck's right edge - the strip the buttons are
    actually on - and the part of the list that reaches past the drawing is
    painted onto the panel.  See PaintPopup and pbInfoPaint. }
  RightMost := pbScreen.Width;
  if pbInfo.Visible then
    RightMost := Max(RightMost,
      pbDeck.Left + pbDeck.Width - pbScreen.Left - Round(2 * FUIScale));
  LeftX := EnsureRange(LeftX, 4, Max(4, RightMost - W - 4));
  if TopY >= 0 then
  begin
    TopY := EnsureRange(TopY, 4, Max(4, pbScreen.Height - H - 4));
    FPopupR := Rect(LeftX, TopY, LeftX + W, TopY + H);
  end
  else
    FPopupR := Rect(LeftX, Max(4, Bottom - H), LeftX + W, Bottom);
  FScreenDirty := True;
  if pbInfo.Visible then pbInfo.Invalidate;
end;

procedure TMainForm.ClosePopup;
begin
  if FPopup = POP_NONE then Exit;
  FPopup := POP_NONE;
  FPopupHot := -1;
  pbScreen.Cursor := FCursorWas;
  FScreenDirty := True;
  pbScreen.Invalidate;
  { It may have been standing over the panel as well.
    Painted now rather than when the queue next gets a turn: a row that
    picks something can put a window up and not come back until it is shut,
    and an invalidate that has not been served yet leaves the list sitting
    on the panel for the whole time that window is open. }
  if pbInfo.Visible then
  begin
    pbInfo.Invalidate;
    pbInfo.Update;
  end;
  pbScreen.Update;
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
  Result := (SY - FPopupR.Top - Round(6 * FUIScale)) div RowH + FPopupTop;
  if (Result < FPopupTop) or (Result >= FPopupN) then Result := -1;
end;

{ The wheel, while a list is open.

  It belongs to whatever is in front.  Before this the wheel was zoom and
  only zoom, so turning it over an open menu zoomed the drawing behind the
  menu - which nobody has ever wanted, and which no list of ours was short
  enough to make obvious until the command list arrived with sixty rows in a
  box that holds fourteen.

  True means the wheel was ours, whether or not anything moved: a list with
  nothing to scroll still swallows it rather than letting it through to the
  model underneath.

  The highlight is left where it is - scrolling is looking, not choosing,
  and Enter must not start meaning something else because the view moved.
  The one exception is the row under the pointer, which really has changed. }
function TMainForm.ScrollPopup(Lines, SX, SY: Integer): Boolean;
var
  RowH, Rows, Was, Hot: Integer;
begin
  Result := FPopup <> POP_NONE;
  if not Result then Exit;
  RowH := Max(1, Round(22 * FUIScale));
  Rows := Max(1, (FPopupR.Bottom - FPopupR.Top - Round(12 * FUIScale)) div RowH);
  if FPopupN <= Rows then Exit;
  Was := FPopupTop;
  FPopupTop := EnsureRange(FPopupTop + Lines, 0, FPopupN - Rows);
  if FPopupTop = Was then Exit;
  Hot := PopupItemAt(SX, SY);
  if Hot >= 0 then FPopupHot := Hot;
  FScreenDirty := True;
  pbScreen.Invalidate;
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

{ A list, drawn wherever it has to be drawn.

  DX and DY move it out of the screen's coordinates and into the canvas it
  is being painted on.  They are nought for the screen itself and the
  distance between the two paint boxes for the entity panel, which is the
  other canvas a list can land on: with the panel open, a list hanging off a
  button at the right of the deck reaches past the drawing and over the
  panel, and the part over the panel is painted there.  See pbInfoPaint. }
procedure TMainForm.PaintPopup(C: TCanvas; DX: Integer = 0; DY: Integer = 0);
var
  I, RowH, Y, Cur: Integer;
  R, PR: TRect;
  Sel: Boolean;
  S: string;
begin
  if FPopup = POP_NONE then Exit;
  RowH := Round(22 * FUIScale);
  PR := FPopupR;
  OffsetRect(PR, DX, DY);

  C.Brush.Style := bsSolid;
  C.Brush.Color := PixToColor(MixPix(Theme.Panel, Pix(0, 0, 0), 0.15));
  C.Pen.Color := PixToColor(MixPix(Theme.PanelHi, Pix(255, 255, 255), 0.30));
  C.Pen.Width := Max(1, Round(FUIScale));
  C.Rectangle(PR);

  case FPopup of
    POP_SCALE: Cur := FD.ScaleIdx;
    POP_SNAP: Cur := FD.SnapIdx;
  else
    Cur := -1;
  end;

  for I := FPopupTop to FPopupN - 1 do
  begin
    Y := PR.Top + Round(6 * FUIScale) + (I - FPopupTop) * RowH;
    if Y + RowH > PR.Bottom then Break;
    R := Rect(PR.Left + Round(4 * FUIScale), Y,
      PR.Right - Round(4 * FUIScale), Y + RowH - 1);
    { the one in force is lit, which the combined list never managed }
    Sel := (I = Cur) or
      ((FPopup = POP_COLOR) and (I < Length(PALETTE)) and
       (PALETTE[I] = FInkColor)) or
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

    if (FPopup = POP_COLOR) and (I < Length(PALETTE)) then
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
    if Sel then UIFont(C, 10, True, OnPix(Theme.Accent))
    else UIFont(C, 10, False, Theme.Text);
    C.TextOut(R.Left + Round(8 * FUIScale),
      R.Top + (RowH - C.TextHeight('X')) div 2, S);

    { What it does, beside what it is called - and on the row under the
      pointer, for the ones that take something after them, what a real use
      of it looks like instead.  The hint says what /scale is for; it does
      not say that what goes after it is 1/4" rather than 4 or 1:48, and
      that is the thing somebody opens the manual to find out. }
    if (FPopup = POP_CMDS) and (I < Length(FCmdOrder)) then
    begin
      S := CMD_LIST[FCmdOrder[I]].Hint;
      { found by another of its words - say which, or the row is a puzzle }
      if CmdAliasFor(FCmdOrder[I], FCmdWant) <> '' then
        S := '/' + CmdAliasFor(FCmdOrder[I], FCmdWant) + ' - ' + S;
      if (I = FPopupHot) and (CMD_LIST[FCmdOrder[I]].Eg <> '') then
      begin
        S := CMD_LIST[FCmdOrder[I]].Eg;
        { in the typing face, because it is something to type }
        UIFont(C, 10, False, Theme.Accent, True);
      end
      else if Sel then UIFont(C, 10, False, OnPix(Theme.Accent))
      else UIFont(C, 10, False, Theme.TextDim);
      C.TextOut(R.Left + Round(120 * FUIScale),
        R.Top + (RowH - C.TextHeight('X')) div 2, S);
    end;
  end;

  { how far down a long list this is, drawn rather than counted out }
  if (FPopupN * RowH) > (PR.Bottom - PR.Top - Round(12 * FUIScale)) then
  begin
    I := (PR.Bottom - PR.Top - Round(12 * FUIScale)) div RowH;
    C.Brush.Style := bsSolid;
    C.Brush.Color := PixToColor(MixPix(Theme.Panel, Pix(0, 0, 0), 0.25));
    C.FillRect(Rect(PR.Right - Round(6 * FUIScale), PR.Top + 4,
                    PR.Right - Round(2 * FUIScale), PR.Bottom - 4));
    C.Brush.Color := PixToColor(Theme.Accent);
    Y := PR.Top + 4 +
      Round((PR.Bottom - PR.Top - 8) * FPopupTop / FPopupN);
    C.FillRect(Rect(PR.Right - Round(6 * FUIScale), Y,
                    PR.Right - Round(2 * FUIScale),
                    Y + Max(16, Round((PR.Bottom - PR.Top - 8) *
                                      I / FPopupN))));
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

{ The outlines of a big selection, drawn once into a transparent layer and
  kept while nothing they depend on has changed: the drawing, the selection,
  the camera, the screen size.  Tracing fifty thousand of them through the
  canvas was over a hundred milliseconds on every mouse move. }
procedure TMainForm.EnsureSelLayer;
var
  Key: string;
  AY, K: Integer;
  Hi: TPointFArray;
  W: Single;
  Sum, X: Int64;
  P: TProjector;
begin
  Sum := 0;
  X := 0;
  for K := 0 to High(FSel) do
  begin
    Sum := Sum + FSel[K];
    X := X xor (Int64(FSel[K]) * (K + 1));
  end;
  Key := Format('%p|%d|%d|%d|%d|%.6f|%.6f|%.6f|%.3f|%.3f|%d|%d|%d|%.3f',
    [Pointer(FD.Doc), FD.Doc.FEditSeq, Length(FSel), Sum, X, FD.Az, FD.El, FD.Zoom, FD.ViewX, FD.ViewY,
     Ord(FD.View), FArt.Width, FArt.Height, FUIScale]);
  if (FSelLayer <> nil) and (Key = FSelLayerKey) then Exit;
  FShotOK := False;                { the selection moved: the shot is stale }
  if FSelLayer = nil then FSelLayer := TArtSurface.Create(FArt.Width, FArt.Height)
  else FSelLayer.SetSize(FArt.Width, FArt.Height);
  FSelLayer.ClearTransparent;
  W := Max(3, Round(3 * FUIScale));
  P := Proj;

  { Traced against the depth buffer, so a selected edge round the back of a
    solid is not drawn over the front of it - and traced INTO THE LAYER,
    which is the whole of the fix.

    This used to be drawn straight onto the LCL canvas, one MoveTo and LineTo
    per visible run, one pen change per entity.  The arithmetic was never the
    problem: thirty-two thousand HiddenAt calls against a standing depth
    buffer measure ten milliseconds.  It was the canvas calls - thousands of
    them, each one a trip through gtk3 and cairo.

    From a note, 16 September, with everything in a revolved dome selected: "there
    is a glitching and freezing issue happening and i hope our logs capture
    it".  They did, and this is the first time they have:

      frames: 189 over 40ms, worst 1984ms, last was
      1890ms (paper 0, ink 0, over 0, screen 1890)
      RECT stage=1 sel=1291 things=1291 zoom=115%

    Paper nought, ink nought, composite nought.  All of it in the canvas
    paint, every frame, for minutes.  Drawn into the layer instead it is our
    own rasteriser, and the layer is cached on everything that could change
    it - so a still selection costs nothing at all after the first build. }
  for AY := 0 to High(FSel) do
  begin
    if (FSel[AY] < 0) or (FSel[AY] >= FD.Doc.Live) then Continue;
    { a group picked shows as its box, not as every edge in it lit up }
    if FD.Doc.TopPartIn(FSel[AY]) > 0 then Continue;
    if Length(FSel) > SEL_TRACE_MAX then
    begin
      { Past a few thousand the depth test is dropped and the edges are
        outlined plainly, which reads the same from any distance.  Kept
        because an orbit with thirty thousand things picked rebuilds this
        layer every frame, and at that size the tracing is the cost again -
        only in the rasteriser rather than in the canvas. }
      if FD.Doc[FSel[AY]].Kind in [ekLine, ekArc, ekDim] then
      begin
        Hi := FD.Doc.Outline(P, FSel[AY]);
        for K := 1 to High(Hi) do
          FSelLayer.Line(Hi[K - 1].X, Hi[K - 1].Y, Hi[K].X, Hi[K].Y, W,
            Pix(70, 130, 240), 1.0);
      end;
    end
    else
      TraceOutlineInto(FSelLayer, FSel[AY], Pix(70, 130, 240), W);
  end;
  FSelLayerKey := Key;
end;

{ ---- touch --------------------------------------------------------------

  One finger is the mouse, but not straight away: a finger that a second
  one joins within a moment was never a click, it was the start of a
  two-finger gesture, so the press waits until the finger moves, or has
  been held a moment, or lifts - a lift with no press sent is a tap, and
  gets a press and a release together.  Two fingers pan by their middle
  and zoom by their spread, through the same PanBy and ZoomAt the mouse
  uses, in quick frames while they move.  When one of the two lifts the
  gesture is over and the finger left behind is ignored until it lifts
  too, so a hand coming off the glass does not draw. }
procedure TMainForm.OnTouch(Kind: TTouchKind; Seq: Pointer; SX, SY: Double);
var
  P: TPoint;
  I, K, N: Integer;
begin
  if FBusy then Exit;
  Inc(FTouchCount);
  P := pbScreen.ScreenToClient(Point(Round(SX), Round(SY)));
  I := -1;
  for K := 0 to High(FTouches) do
    if FTouches[K].Seq = Seq then I := K;
  if FTimings then
    TimingLine(Format('touch %d at %.0f,%.0f finger %d of %d mode %d',
      [Ord(Kind), P.X, P.Y, I, Length(FTouches), Ord(FTouchMode)]));
  case Kind of
    tkBegin:
      begin
        if I < 0 then
        begin
          SetLength(FTouches, Length(FTouches) + 1);
          I := High(FTouches);
          FTouches[I].Seq := Seq;
          FTouches[I].X0 := P.X;
          FTouches[I].Y0 := P.Y;
          FTouches[I].T0 := GetTickCount64;
        end;
        FTouches[I].X := P.X;
        FTouches[I].Y := P.Y;
        N := Length(FTouches);
        if N = 1 then
        begin
          FTouchMode := tmPending;
          FTouchDown := False;
          { the hover first, so the snap and the readout are for this spot }
          pbScreenMouseMove(pbScreen, [], P.X, P.Y);
        end
        else if (N = 2) and (FTouchMode in [tmPending, tmMouse]) then
        begin
          if FTouchDown then
          begin
            pbScreenMouseUp(pbScreen, mbLeft, [ssLeft], FTouches[0].X, FTouches[0].Y);
            FTouchDown := False;
          end;
          FTouchMode := tmGesture;
          GestureStart;
        end;
      end;
    tkUpdate:
      if I >= 0 then
      begin
        FTouches[I].X := P.X;
        FTouches[I].Y := P.Y;
        case FTouchMode of
          tmPending:
            if (Abs(P.X - FTouches[0].X0) > 8) or (Abs(P.Y - FTouches[0].Y0) > 8) then
            begin
              TouchSendDown;
              pbScreenMouseMove(pbScreen, [ssLeft], P.X, P.Y);
            end;
          tmMouse:
            if I = 0 then pbScreenMouseMove(pbScreen, [ssLeft], P.X, P.Y);
          tmGesture:
            if Length(FTouches) >= 2 then GestureMove;
        end;
      end;
    tkEnd, tkCancel:
      if I >= 0 then
      begin
        FTouches[I].X := P.X;
        FTouches[I].Y := P.Y;
        case FTouchMode of
          tmPending:
            if (Kind = tkEnd) and (I = 0) then
            begin
              { a tap: the press and the release, here }
              TouchSendDown;
              pbScreenMouseUp(pbScreen, mbLeft, [ssLeft], P.X, P.Y);
              FTouchDown := False;
            end;
          tmMouse:
            if (I = 0) and FTouchDown then
            begin
              pbScreenMouseUp(pbScreen, mbLeft, [ssLeft], P.X, P.Y);
              FTouchDown := False;
            end;
          tmGesture:
            begin
              { the full frame comes when the camera settles }
              FLastWheel := GetTickCount64;
              FTouchMode := tmSpent;
            end;
        end;
        for K := I to High(FTouches) - 1 do FTouches[K] := FTouches[K + 1];
        SetLength(FTouches, Length(FTouches) - 1);
        if Length(FTouches) = 0 then
        begin
          FTouchMode := tmNone;
          FTouchDown := False;
        end;
      end;
  end;
end;

{ the press for the first finger, where it landed }
procedure TMainForm.TouchSendDown;
begin
  if FTouchDown or (Length(FTouches) = 0) then Exit;
  pbScreenMouseDown(pbScreen, mbLeft, [ssLeft], FTouches[0].X0, FTouches[0].Y0);
  FTouchDown := True;
  FTouchMode := tmMouse;
end;

{ from the tick: a finger held still long enough is a press, not a tap }
procedure TMainForm.TouchTick;
begin
  if (FTouchMode = tmPending) and (Length(FTouches) > 0) and
     (GetTickCount64 - FTouches[0].T0 > 180) then
    TouchSendDown;
end;

procedure TMainForm.GestureStart;
begin
  if Length(FTouches) < 2 then Exit;
  FGestMidX := (FTouches[0].X + FTouches[1].X) / 2;
  FGestMidY := (FTouches[0].Y + FTouches[1].Y) / 2;
  FGestDist := Sqrt(Sqr(FTouches[0].X - FTouches[1].X) + Sqr(FTouches[0].Y - FTouches[1].Y));
end;

procedure TMainForm.GestureMove;
var
  MX, MY, D: Double;
begin
  if Length(FTouches) < 2 then Exit;
  MX := (FTouches[0].X + FTouches[1].X) / 2;
  MY := (FTouches[0].Y + FTouches[1].Y) / 2;
  D := Sqrt(Sqr(FTouches[0].X - FTouches[1].X) + Sqr(FTouches[0].Y - FTouches[1].Y));
  if FQuickFrames then FCameraMoving := True;
  FLastWheel := GetTickCount64;
  if (Abs(MX - FGestMidX) >= 1) or (Abs(MY - FGestMidY) >= 1) then
    PanBy(MX - FGestMidX, MY - FGestMidY);
  { a pinch: the spread, about the middle - fingers too close together
    give a ratio that jumps about, so they only pan }
  if (FGestDist > 30) and (D > 30) and (Abs(D / FGestDist - 1) > 0.01) then
    ZoomAt(D / FGestDist, MX, MY);
  FGestMidX := MX;
  FGestMidY := MY;
  FGestDist := D;
  Invalidate;
end;

{ Whatever pointed into the sheet being left: the selection, the doomed
  list, the hover.  Kept across a tab switch, the selection indexed the
  other sheet's things - and a move on an empty sheet with a selection
  from a full one read past its end. }
procedure TMainForm.LeaveSheet;
begin
  SetLength(FSel, 0);
  SetLength(FDoomed, 0);
  { and the open-edge marks: they are points in this sheet's space and mean
    nothing over the next one }
  SetLength(FOpenEdges, 0);
  FHoverEnt := -1;
  FHoverFace := -1;
  FPushFace := -1;
  FOffFace := -1;
  FSelLayerKey := '';
  FScreenDirty := True;
end;

{ drop anything in the selection that is not in this sheet }
procedure TMainForm.PruneSelection;
var
  I, N: Integer;
begin
  N := 0;
  for I := 0 to High(FSel) do
    if (FSel[I] >= 0) and (FSel[I] < FD.Doc.Live) then
    begin
      FSel[N] := FSel[I];
      Inc(N);
    end;
  if N <> Length(FSel) then
  begin
    SetLength(FSel, N);
    FScreenDirty := True;
  end;
end;

procedure TMainForm.BeginBulkSelect;
var
  K: Integer;
begin
  SetLength(FSelBulk, FD.Doc.Live);
  for K := 0 to High(FSelBulk) do FSelBulk[K] := False;
  for K := 0 to High(FSel) do
    if (FSel[K] >= 0) and (FSel[K] < Length(FSelBulk)) then FSelBulk[FSel[K]] := True;
  FSelBulkOn := True;
end;

procedure TMainForm.EndBulkSelect;
begin
  FSelBulkOn := False;
  SetLength(FSelBulk, 0);
end;

procedure TMainForm.SelectAdd(I: Integer);
var
  T, K: Integer;
  M: TIntArrayW;
begin
  if (I < 0) or (I >= FD.Doc.Live) then Exit;
  if FD.Doc[I].Kind = ekPart then Exit;        { a record comes with its group }
  T := FD.Doc.TopPartIn(I);
  if T < 0 then Exit;                            { outside the open group }
  if T = 0 then
  begin
    SelectAddOne(I);
    Exit;
  end;
  { the whole group, its record included, so that moving, copying and
    deleting the selection carry the group along as one thing }
  M := FD.Doc.PartMembers(T, True);
  for K := 0 to High(M) do SelectAddOne(M[K]);
end;

procedure TMainForm.SelectAddOne(I: Integer);
begin
  if I < 0 then Exit;
  if FSelBulkOn and (I < Length(FSelBulk)) then
  begin
    if FSelBulk[I] then Exit;
    FSelBulk[I] := True;
  end
  else if IsSelected(I) then Exit;
  SetLength(FSel, Length(FSel) + 1);
  FSel[High(FSel)] := I;
  FScreenDirty := True;
end;

procedure TMainForm.SelectRemove(I: Integer);
var
  T, K: Integer;
  M: TIntArrayW;
begin
  if (I < 0) or (I >= FD.Doc.Live) then Exit;
  T := FD.Doc.TopPartIn(I);
  if T <= 0 then
  begin
    SelectRemoveOne(I);
    Exit;
  end;
  M := FD.Doc.PartMembers(T, True);
  for K := 0 to High(M) do SelectRemoveOne(M[K]);
end;

procedure TMainForm.SelectRemoveOne(I: Integer);
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

{ The panel is a reading of the selection, so it is rebuilt wherever the
  selection or the drawing changes.  One call in one place would be neater
  and would also be wrong: the selection is changed from a dozen places and
  a panel that is a frame behind is worse than no panel. }
procedure TMainForm.ThemeSourceWindow;
begin
  if SourceForm = nil then Exit;
  { dark when the theme's chrome is dark - the "Dark" theme has a white
    sheet and dark panels, and the window is chrome, not sheet }
  with Themes[FThemeIdx] do
    if Panel.R + Panel.G + Panel.B < 3 * 128 then
      SourceForm.UseDark(True, PixToColor(Panel), PixToColor(Text))
    else
      SourceForm.UseDark(False, clWhite, clBlack);
end;

{ The source window: the sheet as its text, picked both ways. }
procedure TMainForm.ShowSource;
begin
  if SourceForm = nil then
  begin
    Application.CreateForm(TSourceForm, SourceForm);
    SourceForm.OnAskState := @SourceAskState;
    SourceForm.OnAskSource := @SourceAskSource;
    SourceForm.OnAskPicked := @SourceAskPicked;
    SourceForm.OnPickThings := @SourcePickThings;
    SourceForm.OnApply := @SourceApply;
    SourceForm.OnRunJigs := @RunAllJigs;
    SourceForm.OnRunJig := @RunJigOfThing;
    SourceForm.OnPick := @SourcePick;
    SourceForm.OnCenter := @SourceCenter;
    { The main window's own, so that on Windows it stays in front of the
      main window instead of opening behind it - a report from a Windows
      machine, 22 September: the source window came back, but behind, and
      not to the right where it had been left. }
    SourceForm.PopupMode := pmExplicit;
    SourceForm.PopupParent := Self;
    { beside the main window if there is room on its right, over its right
      half if there is not }
    if (FSourceBounds.Right > 200) and (FSourceBounds.Bottom > 150) and
       (FSourceBounds.Left + FSourceBounds.Right > Screen.DesktopLeft + 40) and
       (FSourceBounds.Left < Screen.DesktopLeft + Screen.DesktopWidth - 40) and
       (FSourceBounds.Top < Screen.DesktopTop + Screen.DesktopHeight - 40) then
      { where it was left - so long as that is still somewhere on a screen }
      SourceForm.SetBounds(FSourceBounds.Left, FSourceBounds.Top, FSourceBounds.Right, FSourceBounds.Bottom)
    else
    begin
      SourceForm.Height := Height;
      SourceForm.Top := Top;
      if Left + Width + SourceForm.Width <= Screen.DesktopLeft + Screen.DesktopWidth then
        SourceForm.Left := Left + Width
      else
        SourceForm.Left := Left + Width - SourceForm.Width;
    end;
  end;
  { the page in the program's own theme: dark on a dark theme, light on a
    light one, and the picked-line wash to suit }
  ThemeSourceWindow;
  SourceForm.chkOnTop.Checked := FSourceOnTop;
  SourceForm.SetAutoComplete(FSourceComplete);
  SourceForm.Show;
  SourceForm.Refresh_;
end;

{ Two numbers that change when the drawing does and when the picking does.
  Cheap on purpose - the window asks several times a second.  A hash is
  meant to wrap round, and the checked build calls that an overflow. }
{$push}{$Q-}{$R-}
procedure TMainForm.SourceAskState(out DocSeq, PickSeq: Int64);
var
  I: Integer;
begin
  DocSeq := 0;
  PickSeq := 0;
  if FD = nil then Exit;
  DocSeq := Int64(PtrUInt(FD)) xor (Int64(FD.Doc.FEditSeq) shl 20) xor
            (Int64(FD.Doc.Live) shl 8) xor (Int64(FD.UndoTop) shl 40) xor
            (Int64(FD.RedoTop) shl 50) xor FD.Doc.Context;
  PickSeq := Length(FSel);
  for I := 0 to High(FSel) do
    PickSeq := (PickSeq * 1000003) xor FSel[I];
end;
{$pop}

procedure TMainForm.SourceAskSource(Version: Integer; L, Hints, Names: TStrings;
  out First, Last, LineThing: TIntArrayW; out SheetName: string);
begin
  SetLength(First, 0);
  SetLength(Last, 0);
  SetLength(LineThing, 0);
  SheetName := '';
  if FD = nil then Exit;
  SheetName := FD.Name;
  if Version = 2 then
    WriteFormat2(FD.Doc, FD.Name, FD.Units, L, First, Last, LineThing, Hints, Names)
  else
    FD.Doc.SaveTo(L, First, Last);
end;

procedure TMainForm.SourceAskPicked(out Picked: TIntArrayW);
var
  I: Integer;
begin
  SetLength(Picked, Length(FSel));
  for I := 0 to High(FSel) do Picked[I] := FSel[I];
end;

{ Lines were picked in the source window.  Through SelectAdd, so the rules
  are the sheet's own: a thing inside a closed group picks the group, and
  one outside the open group is not picked at all. }
procedure TMainForm.SourcePickThings(const Things: TIntArrayW);
var
  I: Integer;
  M: TIntArrayW;
begin
  if FD = nil then Exit;
  SelectNone;
  BeginBulkSelect;
  for I := 0 to High(Things) do
    if FD.Doc[Things[I]].Kind = ekPart then
    begin
      { a GROUP line is the group: any member of it picks the whole }
      M := FD.Doc.PartMembers(FD.Doc[Things[I]].Grp, False);
      if Length(M) > 0 then SelectAdd(M[0]);
    end
    else
      SelectAdd(Things[I]);
  EndBulkSelect;
  FScreenDirty := True;
  InfoChanged;
  pbScreen.Invalidate;
end;

{ The text in the source window, made the drawing.  Read into a scratch
  drawing first: a fault leaves this one exactly as it was. }
function TMainForm.SourceApply(L: TStrings; out ErrLine: Integer; out Err: string): Boolean;
var
  T: TWorkDoc;
begin
  Result := False;
  ErrLine := -1;
  Err := 'there is no sheet open';
  if FD = nil then Exit;
  T := TWorkDoc.Create;
  try
    Result := ReadHeck(L, T, FD.Units, ErrLine, Err);
  finally
    T.Free;
  end;
  if not Result then Exit;
  PushUndo;
  LeaveSheet;        { every number held - picked, hovered, marked - is about to mean something else }
  ResetTool;
  FD.Doc.Clear;
  ReadHeck(L, FD.Doc, FD.Units, ErrLine, Err);
  FD.Dirty := True;
  RebuildFlatFaces;
  RenderPro;
  RecomposeAll;
  FCmdMsg := Format('Applied: %d things.', [FD.Doc.Live]);
  pbScreen.Invalidate;
  pbCmd.Invalidate;
end;

{ Run a group's jig again.  What it prints is read into a scratch drawing
  first; only when that went well is what was in the group taken out and
  what the jig made put in - one undo step. }
function TMainForm.RunJigOf(PartId: Integer): Boolean;
var
  Spec, Err: string;
  Out_: TStringList;
  T: TWorkDoc;
  M: TIntArrayW;
  Doomed: array of Boolean;
  I, ErrLine, WasStamp, Rec: Integer;
begin
  Result := False;
  if FD = nil then Exit;
  Spec := FD.Doc.PartJig(PartId);
  if Spec = '' then
  begin
    FCmdMsg := 'That group is not made by a jig.';
    Exit;
  end;
  Out_ := TStringList.Create;
  try
    Screen.Cursor := crHourGlass;
    try
      if not RunJig(Spec, FD.Units, Out_, Err) then
      begin
        FCmdMsg := 'The jig did not run - ' + Err;
        Exit;
      end;
    finally
      Screen.Cursor := crDefault;
    end;
    T := TWorkDoc.Create;
    try
      if not ReadHeck(Out_, T, FD.Units, ErrLine, Err) then
      begin
        FCmdMsg := Format('Heck if I know - what the jig printed is not Heck.  Line %d: %s', [ErrLine + 1, Err]);
        Exit;
      end;
    finally
      T.Free;
    end;
    PushUndo;
    LeaveSheet;
    ResetTool;
    M := FD.Doc.PartMembers(PartId, False);
    Rec := FD.Doc.PartEnt(PartId);
    SetLength(Doomed, FD.Doc.Live);
    for I := 0 to High(Doomed) do Doomed[I] := False;
    for I := 0 to High(M) do
      if M[I] <> Rec then Doomed[M[I]] := True;
    FD.Doc.DeleteMarked(Doomed);
    WasStamp := FD.Doc.Stamp;
    FD.Doc.Stamp := PartId;
    try
      ReadHeck(Out_, FD.Doc, FD.Units, ErrLine, Err);
    finally
      FD.Doc.Stamp := WasStamp;
    end;
    FD.Dirty := True;
    Result := True;
  finally
    Out_.Free;
  end;
end;

{ what is picked, to the middle of the view and sized - gliding there in
  the 3D view, as a cube click does; straight there in plan and iso }
procedure TMainForm.SourceCenter;
var
  FitZ, FitX, FitY: Double;
begin
  if (FD = nil) or (Length(FSel) = 0) then Exit;
  if FitTarget(True, FD.Az, FD.El, FitZ, FitX, FitY) then
    GlideCamera(FD.Az, FD.El, FitZ, FitX, FitY);
end;

procedure TMainForm.SourcePick(On: Boolean);
begin
  FTextPick := On;
  if On then
  begin
    FCmdMsg := 'Picking for the text: click a point on the sheet, and it is typed in.  Esc stops.';
    { the sheet is not raised: the text being filled has to stay in view,
      and the first click on the sheet brings the keys with it }
    pbScreen.Invalidate;
  end
  else
    FCmdMsg := 'Picking for the text is over.';
  pbCmd.Invalidate;
end;

function TMainForm.RunJigOfThing(Thing: Integer): Boolean;
begin
  Result := False;
  if (FD = nil) or (Thing < 0) or (Thing >= FD.Doc.Live) then Exit;
  if (FD.Doc[Thing].Kind <> ekPart) or (FD.Doc[Thing].Jig = '') then Exit;
  Result := RunJigOf(FD.Doc[Thing].Grp);
  if Result then
  begin
    RebuildFlatFaces;
    RenderPro;
    RecomposeAll;
    pbScreen.Invalidate;
  end;
end;

function TMainForm.RunAllJigs: Integer;
var
  Ids: TIntArrayW;
  I, N: Integer;
begin
  Result := 0;
  if FD = nil then Exit;
  { the ids first: running one moves everything in the list }
  N := 0;
  SetLength(Ids, FD.Doc.Live);
  for I := 0 to FD.Doc.Live - 1 do
    if (FD.Doc[I].Kind = ekPart) and (FD.Doc[I].Jig <> '') then
    begin
      Ids[N] := FD.Doc[I].Grp;
      Inc(N);
    end;
  for I := 0 to N - 1 do
    if RunJigOf(Ids[I]) then Inc(Result);
  RebuildFlatFaces;
  RenderPro;
  RecomposeAll;
  if Result = N then FCmdMsg := Format('%d jigs run.', [Result]);
  pbScreen.Invalidate;
  pbCmd.Invalidate;
end;

procedure TMainForm.InfoChanged;
begin
  if not FInfoOn then Exit;
  RebuildInfo;
  pbInfo.Invalidate;
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
  if FD.Doc.TopPartIn(I) > 0 then Exit;    { a group is the whole of itself }
  { a guide is not part of the drawing, so it has nothing attached to it -
    and nothing attached has it; see SelectConnected }
  if FD.Doc[I].Kind = ekGuide then Exit;
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
{ A flood from I over shared corners.  It used to grow the set a pass at a
  time, testing every unselected thing against every corner of everything
  selected so far - the cube of the drawing's size on a part of a thousand
  edges, and the program went away for a minute.  Now every corner is put
  in a hash once, with the things that have it, and the flood walks that.
  A solid's own members come along in one step, since a built part is by
  definition all joined. }
var
  Have: array of Boolean;
  Queue: array of Integer;
  QHead, QTail, J, K, N, E: Integer;
  Pts: TP3Array;
  Map: TFPHashList;
  Key: shortstring;
  Lists: array of TIntArrayW;
  ListIx: Integer;

  function KeyOf(const P: TP3): shortstring;
  var
    Q: array[0..2] of Int64;
  begin
    Q[0] := Round(P.X * 1E7); Q[1] := Round(P.Y * 1E7); Q[2] := Round(P.Z * 1E7);
    SetLength(Result, 24);
    Move(Q[0], Result[1], 24);
  end;

  procedure Take(E: Integer);
  begin
    if (E < 0) or Have[E] then Exit;
    { A guide laid from a corner shares that corner, and the flood used to
      walk straight through it and bring every guide in the drawing along.
      From a note, 16 September: "THE GUIDES SHOULD NEVER BE SELECTED LIKE THIS!
      guides are not part of a drawing!" }
    if FD.Doc[E].Kind = ekGuide then Exit;
    Have[E] := True;
    if QTail >= Length(Queue) then SetLength(Queue, Max(64, QTail * 2));
    Queue[QTail] := E;
    Inc(QTail);
  end;

begin
  SelectOnly(I);
  if I < 0 then Exit;
  { three clicks on a guide is still just the guide }
  if FD.Doc[I].Kind = ekGuide then Exit;
  N := FD.Doc.Live;
  SetLength(Have, N);
  SetLength(Queue, 64);
  QHead := 0; QTail := 0;
  { every corner, once, with the list of things that have it }
  Map := TFPHashList.Create;
  try
    for J := 0 to N - 1 do
    begin
      FD.Doc.VertsOf([J], Pts);
      for K := 0 to High(Pts) do
      begin
        Key := KeyOf(Pts[K]);
        { one up: a nil item is an empty slot to TFPHashList }
        ListIx := Map.FindIndexOf(Key);
        if ListIx < 0 then
        begin
          SetLength(Lists, Length(Lists) + 1);
          ListIx := High(Lists);
          Map.Add(Key, Pointer(PtrInt(ListIx + 1)));
        end
        else
          ListIx := PtrInt(Map.Items[ListIx]) - 1;
        if (Length(Lists[ListIx]) = 0) or (Lists[ListIx][High(Lists[ListIx])] <> J) then
        begin
          SetLength(Lists[ListIx], Length(Lists[ListIx]) + 1);
          Lists[ListIx][High(Lists[ListIx])] := J;
        end;
      end;
    end;
    Take(I);
    while QHead < QTail do
    begin
      E := Queue[QHead];
      Inc(QHead);
      { the rest of its solid, in one go }
      if FD.Doc[E].Grp > 0 then
        for J := 0 to N - 1 do
          if (not Have[J]) and (FD.Doc[J].Grp = FD.Doc[E].Grp) then Take(J);
      { and whatever shares a corner with it }
      FD.Doc.VertsOf([E], Pts);
      for K := 0 to High(Pts) do
      begin
        ListIx := Map.FindIndexOf(KeyOf(Pts[K]));
        if ListIx < 0 then Continue;
        ListIx := PtrInt(Map.Items[ListIx]) - 1;
        for J := 0 to High(Lists[ListIx]) do Take(Lists[ListIx][J]);
      end;
    end;
  finally
    Map.Free;
  end;
  SetLength(FSel, QTail);
  for J := 0 to QTail - 1 do FSel[J] := Queue[J];
  FScreenDirty := True;
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
      { SketchUp: a click on nothing while a group is open is what closes it }
      if not (Add or Tog) then
        if FD.Doc.Context <> 0 then CloseGroup else SelectNone;
    end
    else if FD.Doc.TopPartIn(I) > 0 then
    begin
      { a group: double-click opens it, otherwise the whole of it is taken.
        Two or more, not two: GTK hands the second press of a double-click
        over twice, once plain and once as the double-click, so the count
        reads three by the time the button comes up - which is why every
        double-click test in this file reads >= 2 and the triple >= 3. }
      if FClickN >= 2 then OpenGroup(FD.Doc.TopPartIn(I))
      else if Sub then SelectRemove(I)
      else if Tog then SelectToggle(I)
      else if Add then SelectAdd(I)
      else SelectOnly(I);
    end
    else if FClickN >= 3 then SelectConnected(I)
    else if FClickN = 2 then SelectAttached(I)
    else if Sub then SelectRemove(I)
    else if Tog then SelectToggle(I)
    else if Add then SelectAdd(I)
    else SelectOnly(I);
  end;

  if Length(FSel) = 0 then
  begin
    if FCmdMsg = '' then FCmdMsg := 'Nothing selected.';
  end
  else if SoleGroup > 0 then
    FCmdMsg := Format('Group "%s"%s - double-click to work inside it.',
      [FD.Doc.PartName(SoleGroup),
       specialize IfThen<string>(FD.Doc.PartLocked(SoleGroup), ' (locked)', '')])
  { A dimension picked on its own is the one selection that can be told what
    to say, so it says so - nobody would guess otherwise. }
  else if SelectedDim >= 0 then
    FCmdMsg := 'Dimension picked - type what it should read and press Enter.'
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
  Picked: TIntArrayW;
  Tk: QWord;
  BX0, BY0, BX1, BY1: Double;
begin
  if X1 < X0 then begin T := X0; X0 := X1; X1 := T; end;
  if Y1 < Y0 then begin T := Y0; Y0 := Y1; Y1 := T; end;
  if not Add then SetLength(FSel, 0);
  Tk := GetTickCount64;
  BeginBulkSelect;
  { What the box takes is BoxTakes' question, not one asked here - see it for
    why a crossing box now has to touch the geometry rather than the box
    around it, and BoxPick for when it takes a guide. }
  Picked := FD.Doc.BoxPick(Proj, X0, Y0, X1, Y1, Crossing);
  for I := 0 to High(Picked) do SelectAdd(Picked[I]);
  EndBulkSelect;
  Took('box select', Tk);
  FScreenDirty := True;
end;

procedure TMainForm.DeleteSelection;
var
  I, N: Integer;
  Doomed: array of Boolean;
  Held: TIntArrayW;
  Tk: QWord;
begin
  N := Length(FSel);
  if N = 0 then Exit;
  PushUndo;
  Tk := GetTickCount64;
  { marked and taken out in one pass.  Sorting the selection by hand and
    deleting one at a time was two quadratic passes over fifty thousand
    things, and a full minute. }
  SetLength(Doomed, FD.Doc.Live);
  for I := 0 to High(Doomed) do Doomed[I] := False;
  for I := 0 to N - 1 do
    if (FSel[I] >= 0) and (FSel[I] < Length(Doomed)) and
       not FD.Doc.PartLockedUp(FD.Doc.TopPartIn(FSel[I])) then Doomed[FSel[I]] := True;
  { and the faces those edges were holding up - see FacesOnEdges }
  FD.Doc.FacesOnEdges(FSel, Held);
  for I := 0 to High(Held) do Doomed[Held[I]] := True;
  FD.Doc.PointsOnGuides(FSel, Held);
  for I := 0 to High(Held) do Doomed[Held[I]] := True;
  FD.Doc.DeleteMarked(Doomed);
  Took('delete selection', Tk);
  SetLength(FSel, 0);
  RebuildFlatFaces;
  FCmdMsg := Format('Deleted %d thing%s.', [N, IfThen(N = 1, '', 's')]);
  RenderPro;
  RecomposeAll;
end;

{ How far the move has traveled.  A typed value wins over the pointer: a
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
{ The arc's two ends are on the two lines of a corner, so it could round
  that corner off.  The fillet that keeps the first click where it was. }
function TMainForm.FilletCandidate(out F: TFillet): Boolean;
begin
  Result := (FTool = ptArc) and (FStage = 2) and
            FD.Doc.FilletFromEnds(FP1, FP2, F);
end;

{ Is the arc being placed a fillet, and which one?

  SketchUp turns the arc magenta when it runs tangent into both lines, and
  that is the moment a click rounds the corner.  Here it is the same moment,
  found the other way round: the fillet is worked out from the two ends, and
  the arc is taken as that fillet when the pull brings its middle within a
  finger's width of the fillet's middle.  Short of that the arc is whatever
  the pull says, as before - the bubble is still there if you want a bubble.

  A number typed while it is magenta is the radius, which is SketchUp's
  rule; a number with an r after it is the radius whatever the pull is
  doing.  Either way the arc is made to that radius, the touching points
  moved to suit.  Typed says a radius was typed. }
function TMainForm.ArcFillet(out F: TFillet; out Typed: Boolean): Boolean;
const
  LOCK_PX = 16;
var
  Txt: string;
  L: Double;
  RSuffix, Near_: Boolean;
  M: TPointF;
  F2: TFillet;
begin
  Result := False;
  Typed := False;
  if not FilletCandidate(F) then Exit;
  M := ScreenOf(ArcPoint(F.ArcC, F.R, F.A0 + F.Sweep / 2, F.Pl, F.Nm));
  Near_ := Sqrt(Sqr(M.X - FMouseSX) + Sqr(M.Y - FMouseSY)) <= LOCK_PX * FUIScale;
  Txt := Trim(FInput);
  RSuffix := (Length(Txt) > 1) and (Txt[Length(Txt)] in ['r', 'R']);
  if RSuffix then Delete(Txt, Length(Txt), 1);
  if (Txt <> '') and (RSuffix or Near_) then
  begin
    if not ParseLen(Txt, FD.Units, L) then Exit;
    if not FD.Doc.FilletAt(F.Corner, L, F2) then Exit;
    F := F2;
    Typed := True;
    Exit(True);
  end;
  Result := Near_;
end;

{ The part of a tool's preview that sits under the pointer, drawn into the
  cursor's own square - see where pbScreenPaint calls it.  OX, OY is where
  the square's corner is on the screen. }
{ The face the overlay is washing blue right now, or -1 - the same choices
  PaintProOverlay makes, asked once more for the cursor's square. }
function TMainForm.HintFaceNow: Integer;
begin
  Result := -1;
  case FTool of
    ptPush, ptDrill:
      if FStage = 1 then Result := FPushFace else Result := FHoverFace;
    ptFollow:
      if FStage = 0 then Result := FHoverFace else Result := FFollowFace;
    ptLine, ptRect, ptCircle, ptArc:
      if (FStage = 0) and not FPlaneHeld then
        Result := InContextFace(FD.Doc.HitFace(Proj, FMouseSX, FMouseSY));
  end;
end;

procedure TMainForm.PaintUnderCursor(S: TArtSurface; OX, OY: Integer);
var
  F: TFillet;
  Typed: Boolean;
  K, HF: Integer;
  PA, PB: TPointF;
  RectPts: TP3Array;
begin
  { The line or rectangle being dragged, same as the fillet arc below and
    for the same reason: the square pasted back over the cursor is a patch
    of the finished drawing, with no preview in it, and the preview's
    nearest corner is always sitting right where the cursor is.  Reported
    from the field: "the white square behind the cursor is cutting off the
    drawing behind it" - drawing a rectangle, the near corner blinked out
    every time the pointer crossed it.

    Not the full axis-color inference PaintProOverlay's Rubber does - this
    patch is a handful of pixels around the cursor, and Theme.Accent is
    close enough there that nobody will see the difference between it and
    whichever color the real preview line is using a few pixels further
    out, where the square does not reach. }
  if (FTool = ptLine) and (FStage = 1) then
  begin
    PA := ScreenOf(FP1);
    PB := ScreenOf(PreviewTarget);
    S.Line(PA.X - OX, PA.Y - OY, PB.X - OX, PB.Y - OY,
      Max(3, Round(3 * FUIScale)), Theme.Accent, 1);
  end
  else if (FTool = ptRect) and (FStage = 1) then
  begin
    RectPts := RectCorners(FP1, RectTarget, FD.Plane);
    for K := 0 to 3 do
    begin
      PA := ScreenOf(RectPts[K]);
      PB := ScreenOf(RectPts[(K + 1) mod 4]);
      S.Line(PA.X - OX, PA.Y - OY, PB.X - OX, PB.Y - OY,
        Max(3, Round(3 * FUIScale)), Theme.Accent, 1);
    end;
  end
  else if (FTool = ptOffset) and (FStage = 1) then
  begin
    { the offset's loop, for the same reason: the corner nearest the cursor
      is the one it is being dragged by }
    RectPts := OffsetPreview;
    for K := 0 to High(RectPts) do
    begin
      PA := ScreenOf(RectPts[K]);
      PB := ScreenOf(RectPts[(K + 1) mod Length(RectPts)]);
      S.Line(PA.X - OX, PA.Y - OY, PB.X - OX, PB.Y - OY,
        Max(3, Round(3 * FUIScale)), Theme.Accent, 1);
    end;
  end;

  { The blue wash over the face being pointed at.  Painted on the canvas, so
    the pasted square cut a clean hole of paper out of it right where the
    pointer was - on every face, with every tool that washes one.  Drawn
    into the square as well now, clipped to it. }
  HF := HintFaceNow;
  { the square is copied from the picture shown, which has the wash in it
    already when pbScreenPaint put it there }
  if (HF >= 0) and (HF <> FHintInShot) then
    PaintFaceHint(nil, HF, HINT_BLUE, S, OX, OY);
  if not ArcFillet(F, Typed) then Exit;
  S.BlendMode := bmNormal;
  PA := ScreenOf(ArcPoint(F.ArcC, F.R, F.A0, F.Pl, F.Nm));
  for K := 1 to FSidesArc do
  begin
    PB := ScreenOf(ArcPoint(F.ArcC, F.R, F.A0 + F.Sweep * K / FSidesArc,
      F.Pl, F.Nm));
    S.Line(PA.X - OX, PA.Y - OY, PB.X - OX, PB.Y - OY,
      Max(3, Round(3 * FUIScale)), Pix(225, 40, 225), 1);
    PA := PB;
  end;
end;

{ The second click of a double-click, with the arc tool in hand.

  Right after an arc went in as a fillet, it trims that corner: SketchUp's
  double-click, "the face and edges on the outside of your arc disappear".
  Otherwise, near a corner, it rounds that corner with the last radius -
  "move your cursor close to another corner and double-click". }
function TMainForm.ArcDoubleClick(SX, SY: Integer): Boolean;
var
  Corner: TP3;
  F: TFillet;
  N: Integer;
begin
  Result := False;
  if FTool <> ptArc then Exit;
  { Only the double-click whose first click put the arc in.  The drive test
    that took the help pictures caught it the other way: a plain click left
    the trim waiting, and the next double-click - on a different corner, a
    minute later - used it up on the old corner instead of rounding the new
    one.  The two clicks of one double-click are well inside a second apart;
    anything later is a new gesture. }
  if FFilletPending and (FFilletSeq = FEditSeq) and
     (GetTickCount64 - FFilletTick < 800) then
  begin
    FFilletPending := False;
    N := FD.Doc.TrimFillet(FLastFillet);
    if N > 0 then
    begin
      RebuildFlatFaces;
      RenderPro;
      RecomposeAll;
      FCmdMsg := 'Corner rounded to ' + FormatLen(FLastFillet.R, FD.Units) +
        ' and trimmed.  Double-click another corner for the same again.';
      ResetTool;
      Exit(True);
    end;
  end;
  FFilletPending := False;
  if FLastFilletR <= 0 then Exit;
  if not FD.Doc.NearestCorner(Proj, SX, SY, 18 * FUIScale, Corner) then Exit;
  ResetTool;
  if not FD.Doc.FilletAt(Corner, FLastFilletR, F) then
  begin
    FCmdMsg := 'A ' + FormatLen(FLastFilletR, FD.Units) +
      ' radius does not fit that corner.';
    Exit(True);
  end;
  PushUndo;
  FD.Doc.ApplyFillet(F, FSidesArc, FInkColor, FEdgeW, True);
  RebuildFlatFaces;
  RenderPro;
  RecomposeAll;
  FCmdMsg := 'Same again - corner rounded to ' + FormatLen(F.R, FD.Units) + '.';
  Result := True;
end;

{ Alt's tangent lock, in one line: the bulge that runs the arc out of the
  edge its first point sits on - see TangentSagitta in uWork. }
function TMainForm.TangentBulge(Pl: TPlane; out Bulge: Double): Boolean;
begin
  Result := FArcTanHas and
            TangentSagitta(FP1, FP2, FArcTanDir, Pl, Bulge);
end;

function TMainForm.ArcPicks(const B: TP3; out Pl: TPlane; out C: TP3;
  out R, A0, Sweep, Bulge: Double): Boolean;
var
  AU, AV, N, FN: TP3;
  U1, V1, U2, V2, UC, VC, Ln, NU, NV, L, Size, Tol: Double;
  F: Integer;

  function OnPlane(const P, Org, Nm: TP3): Boolean;
  begin
    Result := Abs(Dot3(Nm, P3(P.X - Org.X, P.Y - Org.Y, P.Z - Org.Z))) <= Tol;
  end;

begin
  Result := False;
  Bulge := 0;
  C := FP1; R := 0; A0 := 0; Sweep := 0;
  Pl := FD.Plane;
  Size := Max(Dist(FP2, FP1), Dist(B, FP1));
  if Size < 1E-9 then Exit;
  Tol := 1E-6 * (1 + Size);
  PlaneAxes(Pl, AU, AV);
  N := Norm3(Cross3(AU, AV));
  { The pull off the working plane, onto a face that holds all three points,
    says the arc is on that face: the chord along the bottom edge of a wall
    is in the ground plane and the wall's both, and the pull up the wall is
    what settles it.  Only a face's plane, though.  A pull that has snapped
    to some stray point in space - a crease inside the box behind the wall -
    stays projected onto the working plane, as any other point would; the
    first version of this let it tilt the arc off the wall. }
  if not OnPlane(B, FP1, N) then
    for F := 0 to FD.Doc.Live - 1 do
    begin
      if (FD.Doc[F].Kind <> ekFace) or (Length(FD.Doc[F].Poly) < 3) then Continue;
      FN := Norm3(FD.Doc.FaceNormal(F));
      if OnPlane(FP1, FD.Doc[F].Poly[0], FN) and OnPlane(FP2, FD.Doc[F].Poly[0], FN) and
         OnPlane(B, FD.Doc[F].Poly[0], FN) then
      begin
        if Abs(FN.Z) > 0.999 then Pl := plXY
        else if Abs(FN.Y) > 0.999 then Pl := plXZ
        else if Abs(FN.X) > 0.999 then Pl := plYZ
        else
        begin
          SetFreePlane(FP1, FN);
          Pl := plFree;
        end;
        Break;
      end;
    end;
  PlaneCoords(Pl, FP1, U1, V1);
  PlaneCoords(Pl, FP2, U2, V2);
  PlaneCoords(Pl, B, UC, VC);
  Ln := Sqrt(Sqr(U2 - U1) + Sqr(V2 - V1));
  if Ln < 1E-9 then Exit;
  { bulge is how far the middle is pulled off the chord }
  NU := -(V2 - V1) / Ln;
  NV := (U2 - U1) / Ln;
  Bulge := (UC - (U1 + U2) / 2) * NU + (VC - (V1 + V2) / 2) * NV;
  { Alt has pinned it to leave the edge smoothly, so the cursor no longer
    says how far it bulges - the two ends and the edge decide that between
    them.  A typed length still wins, the way a typed length always does. }
  if FArcTanLock and TangentBulge(Pl, L) then Bulge := L;
  if (FInput <> '') and ParseLen(FInput, FD.Units, L) then
    Bulge := Sign(IfThen(Bulge = 0, 1, Bulge)) * L;
  if Abs(Bulge) < 1E-9 then Bulge := Ln / 8;
  Result := ArcFromChord(FP1, FP2, Bulge, Pl, C, R, A0, Sweep);
end;

procedure TMainForm.PaintMoveGhost(C: TCanvas);
var
  I, K: Integer;
  D: TP3;
  Hi: TPointFArray;
  Lo, Hi3: TP3;
  Crate: array[0..7] of TP3;
  CS: array[0..7] of TPointF;
  PA, PB, SA, SB: TPointF;
  Lean: TP3Array;
begin
  if (FTool <> ptMove) or (FStage <> 1) then Exit;
  D := MoveDelta;

  { What comes with it.  A corner sitting where a moving corner sits moves
    too, so the edges joined on stretch to follow - which is what the click
    has always done and what the picture never said.

    From a note, 15 September, moving one side of a rectangle drawn inside another:
    "the issue is that line of the smaller inner rectangle is not staying
    snapped".  It was; the ghost showed the side flying off alone and said
    nothing about the two sides leaning over after it, so the tool read as
    tearing the rectangle open.  Drawn first and thin, so the thing actually
    being moved still reads as the thing being moved. }
  if not (FMoveRigid or FMoveCopy or FDetachMove) and (Length(FMoveVerts) > 0) then
  begin
    FD.Doc.StretchPreview(FMoveVerts, D, FSel, Lean);
    C.Pen.Style := psSolid;
    C.Pen.Width := 1;
    C.Pen.Color := PixToColor(Pix(150, 185, 245));
    I := 0;
    while I + 1 <= High(Lean) do
    begin
      SA := ScreenOf(Lean[I]);
      SB := ScreenOf(Lean[I + 1]);
      C.MoveTo(Round(SA.X), Round(SA.Y));
      C.LineTo(Round(SB.X), Round(SB.Y));
      Inc(I, 2);
    end;
  end;

  C.Pen.Style := psSolid;
  C.Pen.Width := Max(2, Round(2 * FUIScale));
  if FMoveCopy then C.Pen.Color := PixToColor(Pix(60, 180, 110))
  else if FDetachMove then C.Pen.Color := PixToColor(Pix(235, 150, 40))
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
  { A built part being placed comes in its crate: the box round it, the
    floor marked with its diagonals, IN at the entry end, OUT at the exit,
    TOP on the lid - so it can be set down the right way round.  Drawn
    only; nothing of it goes into the drawing. }
  if FMoveRigid and (Length(FMoveVerts) > 0) then
  begin
    Lo := FMoveVerts[0];
    Hi3 := FMoveVerts[0];
    for I := 1 to High(FMoveVerts) do
    begin
      Lo := P3(Min(Lo.X, FMoveVerts[I].X), Min(Lo.Y, FMoveVerts[I].Y), Min(Lo.Z, FMoveVerts[I].Z));
      Hi3 := P3(Max(Hi3.X, FMoveVerts[I].X), Max(Hi3.Y, FMoveVerts[I].Y), Max(Hi3.Z, FMoveVerts[I].Z));
    end;
    Lo := P3(Lo.X + D.X, Lo.Y + D.Y, Lo.Z + D.Z);
    Hi3 := P3(Hi3.X + D.X, Hi3.Y + D.Y, Hi3.Z + D.Z);
    Crate[0] := P3(Lo.X, Lo.Y, Lo.Z); Crate[1] := P3(Hi3.X, Lo.Y, Lo.Z);
    Crate[2] := P3(Hi3.X, Hi3.Y, Lo.Z); Crate[3] := P3(Lo.X, Hi3.Y, Lo.Z);
    for K := 0 to 3 do Crate[K + 4] := P3(Crate[K].X, Crate[K].Y, Hi3.Z);
    for K := 0 to 7 do CS[K] := ScreenOf(Crate[K]);
    C.Pen.Style := psDash;
    C.Pen.Width := 1;
    C.Pen.Color := PixToColor(Pix(150, 160, 150));
    for K := 0 to 3 do
    begin
      C.MoveTo(Round(CS[K].X), Round(CS[K].Y)); C.LineTo(Round(CS[(K + 1) mod 4].X), Round(CS[(K + 1) mod 4].Y));
      C.MoveTo(Round(CS[K + 4].X), Round(CS[K + 4].Y)); C.LineTo(Round(CS[(K + 1) mod 4 + 4].X), Round(CS[(K + 1) mod 4 + 4].Y));
      C.MoveTo(Round(CS[K].X), Round(CS[K].Y)); C.LineTo(Round(CS[K + 4].X), Round(CS[K + 4].Y));
    end;
    C.MoveTo(Round(CS[0].X), Round(CS[0].Y)); C.LineTo(Round(CS[2].X), Round(CS[2].Y));
    C.MoveTo(Round(CS[1].X), Round(CS[1].Y)); C.LineTo(Round(CS[3].X), Round(CS[3].Y));
    C.Pen.Style := psSolid;
    UIFont(C, 10, True, Pix(80, 110, 80));
    C.Brush.Style := bsClear;
    C.TextOut(Round((CS[0].X + CS[5].X) / 2) - C.TextWidth('IN') div 2, Round((CS[0].Y + CS[5].Y) / 2) - 7, 'IN');
    C.TextOut(Round((CS[3].X + CS[6].X) / 2) - C.TextWidth('OUT') div 2, Round((CS[3].Y + CS[6].Y) / 2) - 7, 'OUT');
    C.TextOut(Round((CS[4].X + CS[6].X) / 2) - C.TextWidth('TOP') div 2, Round((CS[4].Y + CS[6].Y) / 2) - 7, 'TOP');
  end;
  C.Pen.Width := 1;

  { the travel line itself, in the axis color when one is locked }
  PA := ScreenOf(FP1);
  PB := ScreenOf(P3(FP1.X + D.X, FP1.Y + D.Y, FP1.Z + D.Z));
  C.Pen.Style := psDash;
  { the lock is a direction code, two per axis; the color is per axis }
  if FDirLock >= 0 then
    C.Pen.Color := PixToColor(AxisPix(FDirLock div 2))
  else
    C.Pen.Color := PixToColor(Theme.Accent);
  C.MoveTo(Round(PA.X), Round(PA.Y));
  C.LineTo(Round(PB.X), Round(PB.Y));
  C.Pen.Style := psSolid;
end;

{ The arm the angle is measured from: the reference click when there has
  been one, else the plane's own first axis so a typed angle still means
  something before the second click. }
function TMainForm.RotRefDir: TP3;
var
  AU, AV, D: TP3;
  L: Double;
begin
  AxesFromNormal(FRotAxis, AU, AV);
  if FStage < 2 then Exit(AU);
  D := P3(FRotRef.X - FP1.X, FRotRef.Y - FP1.Y, FRotRef.Z - FP1.Z);
  { flattened into the plane, since the click may have been off it }
  L := Dot3(D, FRotAxis);
  D := P3(D.X - FRotAxis.X * L, D.Y - FRotAxis.Y * L, D.Z - FRotAxis.Z * L);
  if Dist(D, P3(0, 0, 0)) < 1E-9 then Exit(AU);
  Result := Norm3(D);
end;

{ How far round, in radians, right-handed about the axis.  Typed wins, and
  takes its direction from the way the cursor has swung - the same as a typed
  length on a move - so a 45 goes the way you were going, and a -45 back. }
function TMainForm.RotAngle: Double;
var
  Ref, D: TP3;
  L, Deg, Snap: Double;
begin
  Ref := RotRefDir;
  D := P3(FCur.X - FP1.X, FCur.Y - FP1.Y, FCur.Z - FP1.Z);
  L := Dot3(D, FRotAxis);
  D := P3(D.X - FRotAxis.X * L, D.Y - FRotAxis.Y * L, D.Z - FRotAxis.Z * L);
  if (FStage < 2) or (Dist(D, P3(0, 0, 0)) < 1E-9) then
    Result := 0
  else
    Result := ArcTan2(Dot3(Cross3(Ref, D), FRotAxis), Dot3(Ref, D));
  if ParseAngle(Trim(FInput), Deg) then
  begin
    if Result < 0 then Deg := -Deg;
    Exit(DegToRad(Deg));
  end;
  { near a multiple of fifteen degrees, that is what was meant }
  Snap := DegToRad(15) * Round(Result / DegToRad(15));
  if Abs(Result - Snap) < DegToRad(2.5) then Result := Snap;
end;

{ The protractor: a circle in the plane, ticked every fifteen degrees, the
  two arms of the angle, and the selection drawn where it would land. }
procedure TMainForm.PaintRotateGhost(C: TCanvas);
var
  I, K: Integer;
  AU, AV, P, Q, Ref: TP3;
  Rw, Ang, A: Double;
  PA, PB: TPointF;
  W: TP3Array;
  Col: TColor;

  function OnCircle(Th, Rad: Double): TP3;
  begin
    Result := P3(FP1.X + (AU.X * Cos(Th) + AV.X * Sin(Th)) * Rad,
                 FP1.Y + (AU.Y * Cos(Th) + AV.Y * Sin(Th)) * Rad,
                 FP1.Z + (AU.Z * Cos(Th) + AV.Z * Sin(Th)) * Rad);
  end;

  procedure Seg(const A, B: TP3);
  begin
    PA := ScreenOf(A);
    PB := ScreenOf(B);
    C.MoveTo(Round(PA.X), Round(PA.Y));
    C.LineTo(Round(PB.X), Round(PB.Y));
  end;

begin
  if FStage < 1 then Exit;
  if FRotAxisIx >= 0 then Col := PixToColor(AxisPix(FRotAxisIx div 2))
  else Col := PixToColor(Pix(200, 60, 200));
  AxesFromNormal(FRotAxis, AU, AV);
  Ref := RotRefDir;
  Ang := RotAngle;

  { the dial: as big as the reference arm, never smaller than a thumb }
  Rw := 60 * FUIScale / Proj.Ppu;
  if FStage >= 2 then Rw := Max(Rw, Dist(FRotRef, FP1));
  C.Pen.Style := psSolid;
  C.Pen.Width := 1;
  C.Pen.Color := Col;
  for K := 0 to 71 do
    Seg(OnCircle(K * Pi / 36, Rw), OnCircle((K + 1) * Pi / 36, Rw));
  { ticks are measured from the reference arm, so the 15s read as 15s }
  A := ArcTan2(Dot3(Ref, AV), Dot3(Ref, AU));
  for K := 0 to 23 do
    if K mod 6 = 0 then Seg(OnCircle(A + K * Pi / 12, Rw * 0.82), OnCircle(A + K * Pi / 12, Rw))
    else Seg(OnCircle(A + K * Pi / 12, Rw * 0.91), OnCircle(A + K * Pi / 12, Rw));

  C.Pen.Width := Max(2, Round(2 * FUIScale));
  { the reference arm, dashed }
  C.Pen.Style := psDash;
  P := P3(FP1.X + Ref.X * Rw, FP1.Y + Ref.Y * Rw, FP1.Z + Ref.Z * Rw);
  Seg(FP1, P);
  { the swung arm, solid, and the arc between them }
  if FStage >= 2 then
  begin
    C.Pen.Style := psSolid;
    Q := RotV(Ref, FRotAxis, Ang);
    Seg(FP1, P3(FP1.X + Q.X * Rw, FP1.Y + Q.Y * Rw, FP1.Z + Q.Z * Rw));
    K := Max(2, Round(Abs(Ang) / (Pi / 36)));
    for I := 0 to K - 1 do
      Seg(OnCircle(A + Ang * I / K, Rw * 0.55), OnCircle(A + Ang * (I + 1) / K, Rw * 0.55));
  end;

  { the selection, where it would come to rest }
  if (FTool = ptRotate) and (FStage >= 2) and (Abs(Ang) > 1E-9) then
  begin
    C.Pen.Style := psSolid;
    if FMoveCopy then C.Pen.Color := PixToColor(Pix(60, 180, 110))
    else if FDetachMove then C.Pen.Color := PixToColor(Pix(235, 150, 40))
    else C.Pen.Color := PixToColor(Pix(70, 130, 240));
    for I := 0 to High(FSel) do
    begin
      W := FD.Doc.OutlineWorld(FSel[I]);
      if Length(W) < 2 then Continue;
      PA := ScreenOf(RotP(W[0], FP1, FRotAxis, Ang));
      C.MoveTo(Round(PA.X), Round(PA.Y));
      for K := 1 to High(W) do
      begin
        PB := ScreenOf(RotP(W[K], FP1, FRotAxis, Ang));
        C.LineTo(Round(PB.X), Round(PB.Y));
      end;
    end;
  end;
  C.Pen.Width := 1;
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
{ What the right button is asking about, which is not quite what the left
  button picks.

  PickAt gives an edge within nine pixels before it will give a face, and for
  dragging a corner about that is right.  For a menu it is wrong, and a
  cylinder shows why: twenty-four sides at any ordinary zoom are ten pixels
  wide, so every point on one is within nine pixels of an edge and the faces
  of a round thing cannot be got at from the right button at all.  Reported
  13 September as "it keeps selecting the next face behind it".

  So the reach comes in to four pixels here.  Aim at an edge and you still
  get the edge; be anywhere in the middle of a face, however narrow, and you
  get the face.  The left button is untouched. }
function TMainForm.PickForMenu(SX, SY: Integer): Integer;
var
  E, F: Integer;
begin
  Result := FD.Doc.HitNote(SX, SY);
  if Result >= 0 then Exit;
  E := FD.Doc.HitEdge(Proj, SX, SY, 4 * FUIScale);
  if E >= 0 then Exit(E);
  F := FD.Doc.HitFace(Proj, SX, SY);
  if F >= 0 then Exit(F);
  Result := FD.Doc.HitTest(Proj, SX, SY, 9 * FUIScale);
end;

{ --- groups ----------------------------------------------------------------
  The rules are SketchUp's, from its help pages (docs/sketchup/15-groups.md):
  a click on anything in a group takes the whole group; double-click opens
  it, and inside it the rest of the drawing fades and cannot be picked; a
  click on nothing, or Escape, leaves it; a locked group can be picked and
  snapped to but not moved, edited or taken apart. }

{ every distinct group in the selection, by the entity you would click }
function TMainForm.SelectedGroups: TIntArrayW;
var
  K, T, J, N: Integer;
  Known: Boolean;
begin
  Result := nil;
  N := 0;
  for K := 0 to High(FSel) do
  begin
    T := FD.Doc.TopPartIn(FSel[K]);
    if T <= 0 then Continue;
    Known := False;
    for J := 0 to N - 1 do
      if Result[J] = T then Known := True;
    if Known then Continue;
    if N >= Length(Result) then SetLength(Result, Max(4, N * 2));
    Result[N] := T;
    Inc(N);
  end;
  SetLength(Result, N);
end;

{ the one group the selection is, or 0 when it is several, or loose things,
  or a mix }
function TMainForm.SoleGroup: Integer;
var
  Gs: TIntArrayW;
  K: Integer;
begin
  Result := 0;
  Gs := SelectedGroups;
  if Length(Gs) <> 1 then Exit;
  for K := 0 to High(FSel) do
    if FD.Doc.TopPartIn(FSel[K]) <> Gs[0] then Exit;
  Result := Gs[0];
end;

procedure TMainForm.MakeGroup;
var
  Id, K, T, I, J, First: Integer;
  Sel: TIntArrayW;
begin
  if Length(FSel) = 0 then
  begin
    FCmdMsg := 'Pick something first - a group is made of what is selected.';
    InvalidateStatus;
    Exit;
  end;
  for K := 0 to High(FSel) do
  begin
    T := FD.Doc.TopPartIn(FSel[K]);
    if (T > 0) and FD.Doc.PartLockedUp(T) then
    begin
      FCmdMsg := Format('"%s" is locked - unlock it before grouping it with anything.',
        [FD.Doc.PartName(T)]);
      InvalidateStatus;
      Exit;
    end;
  end;
  PushUndo;
  SetLength(Sel, Length(FSel));
  for K := 0 to High(FSel) do Sel[K] := FSel[K];
  Id := FD.Doc.NewPart('', FD.Doc.Context);
  First := -1;
  for K := 0 to High(Sel) do
  begin
    I := Sel[K];
    if (I < 0) or (I >= FD.Doc.Live) or (FD.Doc[I].Kind = ekPart) then Continue;
    T := FD.Doc.TopPartIn(I);
    { a group picked goes in whole and stays a group inside the new one }
    if T > 0 then FD.Doc.SetPartParent(T, Id)
    else if T = 0 then
    begin
      FD.Doc.SetPart(I, Id);
      { A face is what its edges enclose, and is worked out again from them
        on every rebuild - so a face taken into a group without its edges
        would be found loose again a moment later and the group left empty.
        Its edges come with it, the way SketchUp's Make Group takes a face's
        bounding edges along. }
      if FD.Doc[I].Kind = ekFace then
        for J := 0 to FD.Doc.Live - 1 do
          if (FD.Doc[J].Kind in [ekLine, ekArc]) and (FD.Doc[J].Part = FD.Doc.Context) and
             EntHasPoint(I, FD.Doc[J].A) and EntHasPoint(I, FD.Doc[J].B) then
            FD.Doc.SetPart(J, Id);
    end;
    if First < 0 then First := I;
  end;
  SetLength(FSel, 0);
  if First >= 0 then SelectAdd(First);
  { the faces are worked out again, group by group - which is where what was
    joined on to the outside comes apart from it }
  RebuildFlatFaces;
  RenderPro;
  RecomposeAll;
  InfoChanged;
  FCmdMsg := Format('Grouped as "%s".  Double-click it to work inside it; ' +
    '/name calls it something.', [FD.Doc.PartName(Id)]);
  InvalidateStatus;
  pbScreen.Invalidate;
end;

procedure TMainForm.ExplodeGroups;
var
  Gs: TIntArrayW;
  Doom: array of Boolean;
  K, G, Up, I, N: Integer;
begin
  Gs := SelectedGroups;
  if Length(Gs) = 0 then
  begin
    FCmdMsg := 'Pick a group first.';
    InvalidateStatus;
    Exit;
  end;
  for K := 0 to High(Gs) do
    if FD.Doc.PartLockedUp(Gs[K]) then
    begin
      FCmdMsg := Format('"%s" is locked - unlock it first.', [FD.Doc.PartName(Gs[K])]);
      InvalidateStatus;
      Exit;
    end;
  PushUndo;
  SetLength(Doom, FD.Doc.Live);
  for I := 0 to High(Doom) do Doom[I] := False;
  N := 0;
  for K := 0 to High(Gs) do
  begin
    G := Gs[K];
    Up := FD.Doc.PartParent(G);
    for I := 0 to FD.Doc.Live - 1 do
    begin
      if (FD.Doc[I].Kind = ekPart) and (FD.Doc[I].Grp = G) then Doom[I] := True
      else if FD.Doc[I].Part = G then
      begin
        { its members go up a level; a group inside it stays a group }
        if FD.Doc[I].Kind = ekPart then FD.Doc.SetPartParent(FD.Doc[I].Grp, Up)
        else FD.Doc.SetPart(I, Up);
        Inc(N);
      end;
    end;
  end;
  FD.Doc.DeleteMarked(Doom);
  SetLength(FSel, 0);
  RebuildFlatFaces;
  RenderPro;
  RecomposeAll;
  InfoChanged;
  if Length(Gs) = 1 then
    FCmdMsg := Format('Group taken apart - %d things are loose again.', [N])
  else
    FCmdMsg := Format('%d groups taken apart.', [Length(Gs)]);
  InvalidateStatus;
  pbScreen.Invalidate;
end;

procedure TMainForm.OpenGroup(Id: Integer);
begin
  if Id <= 0 then Exit;
  if FD.Doc.PartLockedUp(Id) then
  begin
    FCmdMsg := Format('"%s" is locked - unlock it to work inside it.', [FD.Doc.PartName(Id)]);
    InvalidateStatus;
    Exit;
  end;
  SetLength(FSel, 0);
  FD.Doc.Context := Id;
  FShotOK := False;
  RenderPro;
  RecomposeAll;
  InfoChanged;
  FCmdMsg := Format('Inside "%s".  What you draw now belongs to it; ' +
    'Esc or a click on nothing leaves it.', [FD.Doc.PartName(Id)]);
  InvalidateStatus;
  pbScreen.Invalidate;
end;

procedure TMainForm.CloseGroup;
var
  Was: Integer;
begin
  if FD.Doc.Context = 0 then Exit;
  Was := FD.Doc.Context;
  SetLength(FSel, 0);
  FD.Doc.Context := FD.Doc.PartParent(Was);
  FShotOK := False;
  RenderPro;
  RecomposeAll;
  InfoChanged;
  if FD.Doc.Context = 0 then FCmdMsg := Format('Left "%s".', [FD.Doc.PartName(Was)])
  else FCmdMsg := Format('Left "%s" - inside "%s" now.',
    [FD.Doc.PartName(Was), FD.Doc.PartName(FD.Doc.Context)]);
  InvalidateStatus;
  pbScreen.Invalidate;
end;

procedure TMainForm.LockGroups(Locked: Boolean);
var
  Gs: TIntArrayW;
  K: Integer;
begin
  Gs := SelectedGroups;
  if Length(Gs) = 0 then
  begin
    FCmdMsg := 'Pick a group first.';
    InvalidateStatus;
    Exit;
  end;
  PushUndo;
  for K := 0 to High(Gs) do FD.Doc.SetPartLocked(Gs[K], Locked);
  InfoChanged;
  if Locked then
    FCmdMsg := 'Locked.  It can still be snapped to, and picked - but not moved, ' +
      'changed or opened until it is unlocked.'
  else
    FCmdMsg := 'Unlocked.';
  InvalidateStatus;
  pbScreen.Invalidate;
end;

{ Put groups away, or bring them back.  Named: every group whose name has
  that in it, anywhere in the drawing - "/hide labels" puts away the labels
  of every radiant zone at once.  Not named: hiding takes the picked
  groups, and showing brings back everything put away.  The groups keep
  everything; only what is drawn, picked and snapped to changes. }
procedure TMainForm.HideGroups(PutAway: Boolean; const Named: string);
var
  Gs: TIntArrayW;
  I, K, N: Integer;
  Want: string;
begin
  SetLength(Gs, 0);
  Want := LowerCase(Trim(Named));
  for I := 0 to FD.Doc.Live - 1 do
    if (FD.Doc[I].Kind = ekPart) and (FD.Doc[I].Hidden <> PutAway) and
       (((Want <> '') and (Pos(Want, LowerCase(FD.Doc.PartName(FD.Doc[I].Grp))) > 0)) or
        ((Want = '') and not PutAway)) then
    begin
      SetLength(Gs, Length(Gs) + 1); Gs[High(Gs)] := FD.Doc[I].Grp;
    end;
  if (Want = '') and PutAway then Gs := SelectedGroups;
  if Length(Gs) = 0 then
  begin
    if Want <> '' then
      FCmdMsg := Format('No group %s has "%s" in its name.', [IfThen(PutAway, 'showing', 'put away'), Trim(Named)])
    else if PutAway then FCmdMsg := 'Pick a group first - or /hide labels puts away every group named so.'
    else FCmdMsg := 'Nothing is put away.';
    InvalidateStatus;
    Exit;
  end;
  PushUndo;
  N := 0;
  for K := 0 to High(Gs) do
    if FD.Doc.PartHidden(Gs[K]) <> PutAway then
    begin
      FD.Doc.SetPartHidden(Gs[K], PutAway);
      Inc(N);
    end;
  { what is put away cannot stay picked - it is not there to see }
  if PutAway then SetLength(FSel, 0);
  RenderPro;
  RecomposeAll;
  InfoChanged;
  if PutAway then
    FCmdMsg := Format('%d group%s put away - /show brings %s back.', [N, IfThen(N = 1, '', 's'),
      IfThen(N = 1, 'it', 'them')])
  else
    FCmdMsg := Format('%d group%s brought back.', [N, IfThen(N = 1, '', 's')]);
  InvalidateStatus;
  pbScreen.Invalidate;
end;

procedure TMainForm.RenameGroup(const NewName: string);
var
  G: Integer;
begin
  G := SoleGroup;
  if G = 0 then
  begin
    FCmdMsg := 'Pick one group, then /name what to call it.';
    InvalidateStatus;
    Exit;
  end;
  if Trim(NewName) = '' then
  begin
    FCmdMsg := Format('It is called "%s".  /name Left knob calls it that.', [FD.Doc.PartName(G)]);
    InvalidateStatus;
    Exit;
  end;
  PushUndo;
  FD.Doc.SetPartName(G, Trim(NewName));
  InfoChanged;
  FCmdMsg := Format('Called "%s".', [FD.Doc.PartName(G)]);
  InvalidateStatus;
end;

{ What a move or a turn takes hold of.  Whole groups go rigidly, as one
  piece each, and nothing loose that happens to touch them is stretched
  after them - that is the point of a group.  The loose things picked move
  the way they always have, corners and all.  A locked group stays put. }
function TMainForm.SplitMoveSelection: Boolean;
var
  Gs, M, Loose: TIntArrayW;
  K, J, I, N, NL, Skipped: Integer;
begin
  Result := True;
  SetLength(FMoveGroupEnts, 0);
  N := 0;
  Skipped := 0;
  Gs := SelectedGroups;
  for K := 0 to High(Gs) do
  begin
    if FD.Doc.PartLockedUp(Gs[K]) then begin Inc(Skipped); Continue; end;
    M := FD.Doc.PartMembers(Gs[K], True);
    SetLength(FMoveGroupEnts, N + Length(M));
    for J := 0 to High(M) do FMoveGroupEnts[N + J] := M[J];
    N := N + Length(M);
  end;
  Loose := nil;
  NL := 0;
  for K := 0 to High(FSel) do
  begin
    I := FSel[K];
    if (I < 0) or (I >= FD.Doc.Live) or (FD.Doc[I].Kind = ekPart) then Continue;
    if FD.Doc.TopPartIn(I) <> 0 then Continue;
    if NL >= Length(Loose) then SetLength(Loose, Max(16, NL * 2));
    Loose[NL] := I;
    Inc(NL);
  end;
  SetLength(Loose, NL);
  FD.Doc.VertsOf(Loose, FMoveVerts);
  { nothing movable at all: say so and do not start, rather than a move
    that reports a distance and shifts nothing }
  if (Skipped > 0) and (N = 0) and (NL = 0) then
  begin
    FCmdMsg := 'That group is locked - unlock it to move it.';
    Result := False;
  end
  else if Skipped > 0 then
    FCmdMsg := 'A locked group stays where it is - unlock it to move it.';
end;

{ A face a tool may act on: one in the open context.  A face inside a closed
  group is not - SketchUp will not push a group's face from outside either;
  you open the group first.  Drawing ON such a face is another matter and
  goes through FaceUnder, which is not filtered. }
function TMainForm.InContextFace(F: Integer): Integer;
begin
  Result := F;
  if (F >= 0) and (FD.Doc.TopPartIn(F) <> 0) then Result := -1;
end;

{ The box round a group, the way SketchUp draws one round an object: twelve
  edges of its bounds, projected.  Shift moves it, for a ghost. }
procedure TMainForm.PaintPartBox(C: TCanvas; Id: Integer; const Col: TPix;
  Dashed: Boolean; const Shift: TP3);
const
  E: array[0..11, 0..1] of Integer = ((0, 1), (1, 2), (2, 3), (3, 0),
    (4, 5), (5, 6), (6, 7), (7, 4), (0, 4), (1, 5), (2, 6), (3, 7));
var
  Lo, Hi: TP3;
  P: array[0..7] of TPointF;
  K: Integer;
begin
  if not FD.Doc.PartBounds(Id, Lo, Hi) then Exit;
  Lo := P3(Lo.X + Shift.X, Lo.Y + Shift.Y, Lo.Z + Shift.Z);
  Hi := P3(Hi.X + Shift.X, Hi.Y + Shift.Y, Hi.Z + Shift.Z);
  P[0] := ScreenOf(P3(Lo.X, Lo.Y, Lo.Z)); P[1] := ScreenOf(P3(Hi.X, Lo.Y, Lo.Z));
  P[2] := ScreenOf(P3(Hi.X, Hi.Y, Lo.Z)); P[3] := ScreenOf(P3(Lo.X, Hi.Y, Lo.Z));
  P[4] := ScreenOf(P3(Lo.X, Lo.Y, Hi.Z)); P[5] := ScreenOf(P3(Hi.X, Lo.Y, Hi.Z));
  P[6] := ScreenOf(P3(Hi.X, Hi.Y, Hi.Z)); P[7] := ScreenOf(P3(Lo.X, Hi.Y, Hi.Z));
  C.Brush.Style := bsClear;
  if Dashed then C.Pen.Style := psDash else C.Pen.Style := psSolid;
  C.Pen.Width := Max(1, Round(FUIScale));
  C.Pen.Color := PixToColor(Col);
  for K := 0 to 11 do
  begin
    C.MoveTo(Round(P[E[K, 0]].X), Round(P[E[K, 0]].Y));
    C.LineTo(Round(P[E[K, 1]].X), Round(P[E[K, 1]].Y));
  end;
  C.Pen.Style := psSolid;
end;

{ What the move and rotate tools take hold of when nothing is picked yet.
  PickAt asks the guide point first, and rightly - it sits on the line it
  measured along, and the select tool and the eraser want the point.  Move
  is the other way about: a guide point laid on a corner is a mark on that
  corner, and grabbing the mark instead of the corner is a surprise every
  time.  So the drawing first, and the point only when it is on its own.
  A guide on its own still moves - SketchUp: "they can be moved or rotated
  with the ordinary tools, like anything else". }
function TMainForm.PickToGrab(SX, SY: Integer): Integer;
begin
  Result := FD.Doc.HitNote(SX, SY);
  if Result < 0 then
    Result := FD.Doc.HitEdge(Proj, SX, SY, 9 * FUIScale, GUIDE_PICK_PX * FUIScale);
  if Result < 0 then Result := FD.Doc.HitFace(Proj, SX, SY);
  if Result < 0 then Result := FD.Doc.HitTest(Proj, SX, SY, 9 * FUIScale);
  if Result < 0 then Result := FD.Doc.HitGuidePoint(Proj, SX, SY, 10 * FUIScale);
  if (Result >= 0) and (FD.Doc.TopPartIn(Result) < 0) then Result := -1;
end;

{ What a click takes, with the group rules on top of the plain hit.  Inside
  an open group the rest of the drawing is not there to be picked - and the
  click on it is what closes the group, in FinishSelect. }
function TMainForm.PickAt(SX, SY: Integer): Integer;
begin
  Result := PickAtRaw(SX, SY);
  if (Result >= 0) and (FD.Doc.TopPartIn(Result) < 0) then Result := -1;
end;

function TMainForm.PickAtRaw(SX, SY: Integer): Integer;
begin
  { A note is drawn over the top of everything, so it is picked before
    everything - otherwise a note sitting on a panel could not be got at,
    because the panel underneath answered first. }
  Result := FD.Doc.HitNote(SX, SY);
  if Result >= 0 then Exit;
  { Then a guide point, for the reason written over HitGuidePoint: it is
    nearly always sitting on the line it measured along, and that line is the
    same distance from the cursor.  The reach matches what is drawn - the
    disc is 4.5 across with an eight-long cross through it - so the target is
    the size it looks. }
  Result := FD.Doc.HitGuidePoint(Proj, SX, SY, 10 * FUIScale);
  if Result >= 0 then Exit;
  { An edge, then the face behind it, then anything else.  Asked in that
    order and stopped at the first answer - it used to work all three out and
    then pick between them, which meant every mouse move over a drawing cast
    a ray at every face in it whether or not the cursor was sitting on an
    edge.  HitFace is the expensive one of the three and it is the one that
    was never needed when the answer was an edge. }
  { A guide has to be under the cursor, not merely near it.  The owner, 17
    September: "the select tool shouldnt easily snap to guides... sketchup
    makes it so the select tool needs to be right over it".  Nine pixels of
    reach on a line that runs the width of the drawing is how a guide ended
    up picked while aiming at the edge it was measured from. }
  Result := FD.Doc.HitEdge(Proj, SX, SY, 9 * FUIScale, GUIDE_PICK_PX * FUIScale);
  if Result >= 0 then Exit;
  Result := FD.Doc.HitFace(Proj, SX, SY);
  if Result >= 0 then Exit;
  Result := FD.Doc.HitTest(Proj, SX, SY, 9 * FUIScale);
end;

{ Add whatever is under the cursor to the list the eraser is holding. }
procedure TMainForm.DoomAt(SX, SY: Integer);
var
  I, T, K: Integer;
  M: TIntArrayW;
begin
  { Softening is about edges and nothing else - a face has no crease to
    hide.  So a soften stroke only ever looks for an edge, rather than
    gathering the face behind it and then quietly skipping it, which is how
    a sweep across a panel came back saying it had found nothing. }
  if FEraseMode <> 0 then
  begin
    I := FD.Doc.HitEdge(Proj, SX, SY, 9 * FUIScale);
    if I < 0 then Exit;
    if IsDoomed(I) then Exit;
    if FD.Doc.TopPartIn(I) <> 0 then Exit;    { softening stays in the open group }
    if not (FD.Doc[I].Kind in [ekLine, ekArc]) then Exit;
    SetLength(FDoomed, Length(FDoomed) + 1);
    FDoomed[High(FDoomed)] := I;
    FScreenDirty := True;
    Exit;
  end;
  { The eraser takes edges, and takes faces only by taking the edges that
    hold them up.  That is SketchUp's arrangement, checked against their help
    on 15 September 2026: "The Eraser tool doesn't allow you to erase faces.
    Technically, faces are erased when you erase their bounding edges."

    Ours used to take a bare face when the cursor was over one and not over
    an edge, and the difference was written down as deliberate.  The owner looked
    it up: "Ok I just checked and you are right the eraser will not erase a
    face in SketchUp so let's follow SketchUp convention here."  Erasing a
    face on its own is the right button's Erase, or picking it and pressing
    Delete - both of which we have.

    Saying so matters as much as doing it.  A tool that quietly does nothing
    where it used to do something reads as broken, so a click on a face says
    what the eraser is for and where the other way in is. }
  { The note first, for the same reason the selection takes it first: it is
    drawn over the top, so it is what the cursor is on.  Rubbing out a note
    used to take the panel behind it instead, which is a poor trade. }
  I := FD.Doc.HitNote(SX, SY);
  { A guide point before the edges, the way PickAt asks: a point nearly
    always sits on the guide line it was measured along, and asking the
    line first took the line - and with it, by the rule in PointsOnGuides,
    every point on it.  From a note, 19 September: "i placed three guide
    points... erased the first one.  it erased the second and third one." }
  if I < 0 then I := FD.Doc.HitGuidePoint(Proj, SX, SY, 10 * FUIScale);
  if I < 0 then I := FD.Doc.HitEdge(Proj, SX, SY, 9 * FUIScale);
  if I < 0 then I := FD.Doc.HitTest(Proj, SX, SY, 9 * FUIScale);
  if I < 0 then
  begin
    if FD.Doc.HitFace(Proj, SX, SY) >= 0 then
      FCmdMsg := 'The eraser takes edges - rub out the edges round a face ' +
        'and the face goes with them.  For the face on its own: right-click ' +
        'it, or pick it and press Delete.';
    Exit;
  end;
  { A group is rubbed out whole, the way SketchUp's eraser takes an object;
    a locked one is not rubbed out at all, and outside the open group there
    is nothing to rub. }
  T := FD.Doc.TopPartIn(I);
  if T < 0 then Exit;
  if T > 0 then
  begin
    if FD.Doc.PartLockedUp(T) then
    begin
      FCmdMsg := Format('"%s" is locked.', [FD.Doc.PartName(T)]);
      Exit;
    end;
    M := FD.Doc.PartMembers(T, True);
    for K := 0 to High(M) do
      if not IsDoomed(M[K]) then
      begin
        SetLength(FDoomed, Length(FDoomed) + 1);
        FDoomed[High(FDoomed)] := M[K];
      end;
    FScreenDirty := True;
    Exit;
  end;
  if IsDoomed(I) then Exit;
  SetLength(FDoomed, Length(FDoomed) + 1);
  FDoomed[High(FDoomed)] := I;
  FScreenDirty := True;
end;

{ Delete everything gathered, highest index first so the lower ones do not
  shift underneath, then see whether any regions should join up. }
function TMainForm.EraseModeOf(Shift: TShiftState): Integer;
begin
  if not (ssCtrl in Shift) then Result := 0
  else if ssShift in Shift then Result := 2
  else Result := 1;
end;

{ Soften what the eraser gathered, instead of rubbing it out.

  Only lines and arcs: a face has no crease to hide, and quietly doing
  nothing to one is better than refusing the whole stroke because a face
  happened to be under the cursor halfway across. }
procedure TMainForm.SoftenDoomed(On_: Boolean);
var
  I, N: Integer;
begin
  N := 0;
  for I := 0 to High(FDoomed) do
    if (FDoomed[I] >= 0) and (FDoomed[I] < FD.Doc.Live) and
       (FD.Doc[FDoomed[I]].Kind in [ekLine, ekArc]) and
       (FD.Doc[FDoomed[I]].Soft <> On_) then
    begin
      if N = 0 then PushUndo;
      FD.Doc.SetSoft(FDoomed[I], On_);
      Inc(N);
    end;
  SetLength(FDoomed, 0);
  if N = 0 then
    FCmdMsg := specialize IfThen<string>(On_,
      'Nothing there to soften.', 'Nothing there was softened.')
  else
  begin
    FCmdMsg := Format('%d %s %s.', [N,
      specialize IfThen<string>(N = 1, 'edge', 'edges'),
      specialize IfThen<string>(On_, 'softened', 'brought back')]);
    RenderPro;
    RecomposeAll;
  end;
  FScreenDirty := True;
end;

procedure TMainForm.BurnDoomed;
var
  I, J, T, N: Integer;
  EA, EB: array of TP3;
  Kinds: array of TEntKind;
  Held: TIntArrayW;
  Gone: array of Boolean;
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
  { The faces these edges were holding up go with them.  A loose face would
    have gone anyway - they are all thrown away and worked out again from
    what is left - but a built solid's faces are kept as they were made, so
    rubbing an edge off a box used to leave the box's six sides standing
    with nothing under one of them. }
  FD.Doc.FacesOnEdges(FDoomed, Held);
  SetLength(Gone, FD.Doc.Live);
  for I := 0 to High(Gone) do Gone[I] := False;
  for I := 0 to N - 1 do Gone[FDoomed[I]] := True;
  for I := 0 to High(Held) do Gone[Held[I]] := True;
  { and a guide line takes the point laid with it }
  FD.Doc.PointsOnGuides(FDoomed, Held);
  for I := 0 to High(Held) do Gone[Held[I]] := True;
  FD.Doc.DeleteMarked(Gone);
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
{ What the tape is set to leave behind, in words - said after a measurement
  and in the hint line, so the mode is never a thing you have to remember. }
function TMainForm.TapeDropSays: string;
begin
  case FTapeDrop of
    1: Result := 'a point where it landed - Ctrl for the dashed line too';
    2: Result := 'a guide across the run - Ctrl for the point too';
    3: Result := 'nothing left behind - Ctrl to leave a guide again';
  else
    Result := 'guide across the run, and a point where it landed - Ctrl changes it';
  end;
end;

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
  D, E, Nm, AU, AV: TP3;
  Have: Boolean;
  Kind: TTapeGuide;
begin
  if Dist(FP1, FP2) < 1E-9 then Exit;
  PushUndo;

  { Both, every time.

    A dashed line says where the offset is and a point says where along it
    the measurement actually landed.  They answer different questions and
    neither is much use alone: a line with no point leaves the one place you
    measured to as the one place you cannot see, and a point with no line
    marks a spot you cannot line anything else up with.

    Ctrl cycles between them and came back on 15 September, because there is
    a reason for it now: a 1" mark in from the end of a line does not want a
    dashed line running the width of the drawing with it.  SketchUp puts the
    same choice on the same key.  Both stays the default. }
  if FTapeDrop = 3 then
  begin
    FCmdMsg := RunReading(FP1, FP2) + '   (nothing left behind)';
    Exit;
  end;

  { What it leaves depends on where it was pulled from - see TapeGuide in
    uWork.  Off an edge: a line parallel to that edge.  Along an edge: a
    point and no line.  From anywhere else: the line across the run. }
  PlaneAxes(FD.Plane, AU, AV);
  Nm := Cross3(AU, AV);
  Have := (FMeasEdge >= 0) and (FMeasEdge < FD.Doc.Live) and
          (FD.Doc[FMeasEdge].Kind = ekLine);
  if Have then
    E := P3(FD.Doc[FMeasEdge].B.X - FD.Doc[FMeasEdge].A.X,
            FD.Doc[FMeasEdge].B.Y - FD.Doc[FMeasEdge].A.Y,
            FD.Doc[FMeasEdge].B.Z - FD.Doc[FMeasEdge].A.Z)
  else
    E := P3(0, 0, 0);
  Kind := TapeGuide(Have, E, FP1, FP2, Nm, D);
  { and at a corner the click may have found the other edge of the two, so
    the run is asked of every edge through where it started }
  if (Kind <> tgPointOnly) and FD.Doc.RunsAlongEdge(FP1, FP2) then
    Kind := tgPointOnly;

  { A line is laid unless the run was along the edge it started on - and even
    then, if the mode is line only, the parallel one is what it means. }
  if (FTapeDrop <> 1) and ((Kind <> tgPointOnly) or (FTapeDrop = 2)) and
     (Sqr(D.X) + Sqr(D.Y) + Sqr(D.Z) > 1E-18) then
    FD.Doc.AddGuide(FP2, P3(FP2.X + D.X, FP2.Y + D.Y, FP2.Z + D.Z));
  if FTapeDrop <> 2 then FD.Doc.AddGuide(FP2, FP2);

  if (Kind = tgPointOnly) and (FTapeDrop <> 2) then
    FCmdMsg := FormatLen(Dist(FP1, FP2), FD.Units) +
      '   a point where it landed - measured along the edge, so no line with it'
  else if Kind = tgAlongEdge then
    FCmdMsg := FormatLen(Dist(FP1, FP2), FD.Units) +
      '   a guide parallel to the edge it came off  -  ' + TapeDropSays
  else
    FCmdMsg := FormatLen(Dist(FP1, FP2), FD.Units) + '   ' + TapeDropSays;
  RenderPro;
  RecomposeAll;
end;

function TMainForm.EdgeSegments(Part: Integer): TSegArray;
var
  I, K, N, Steps: Integer;
  A: TP3;
begin
  N := 0;
  SetLength(Result, 64);
  for I := 0 to FD.Doc.Live - 1 do
  begin
    { one group at a time - see the note on Part in uWork }
    if FD.Doc[I].Part <> Part then Continue;
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
        { A reference line - a dimension's own, a radiant run - is drawn and
          not built: it closes no face, the same rule the edge passes in
          uWork keep.  This one let them in, and the box a radiant build
          draws for each manifold, a closed ring of reference lines, came
          back as a little face - a zone of its own the next time the
          floor was selected (24 September, the owner's barn). }
        if not FD.Doc[I].Dim then
        begin
          if N >= Length(Result) then SetLength(Result, N * 2);
          Result[N].A := FD.Doc[I].A;
          Result[N].B := FD.Doc[I].B;
          Inc(N);
        end;
      ekArc:
        begin
          A := ArcPoint(FD.Doc[I].C, FD.Doc[I].R, FD.Doc[I].A0, FD.Doc[I].Plane, FD.Doc[I].Nm);
          Steps := ArcSteps(FD.Doc[I]);
          for K := 1 to Steps do
          begin
            if N >= Length(Result) then SetLength(Result, N * 2);
            Result[N].A := A;
            A := ArcPoint(FD.Doc[I].C, FD.Doc[I].R,
              FD.Doc[I].A0 + FD.Doc[I].Sweep * K / Steps, FD.Doc[I].Plane, FD.Doc[I].Nm);
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
{ Whether the drawing carries any face at all, the solids' included.
  FaceCount leaves solids out, which is right for its other callers and
  wrong here: a drawing that is nothing but a built duct has faces, and
  taking it for a faceless old file worked its areas out again and capped
  every open end. }
function TMainForm.SolidFaceCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FD.Doc.Live - 1 do
    if (FD.Doc[I].Kind = ekFace) and FD.Doc[I].Solid then Inc(Result);
end;

function TMainForm.AnyFace: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FD.Doc.Live - 1 do
    if FD.Doc[I].Kind = ekFace then Exit(True);
end;

function TMainForm.FaceCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FD.Doc.Live - 1 do
    if (FD.Doc[I].Kind = ekFace) and not FD.Doc[I].Solid then Inc(Result);
end;

{ A flat area boiled down to something that can be matched next time. }
function RegionSig(const R: TRegion): TRegionSig;
var
  K, N: Integer;
begin
  { one of the two normals, chosen the same way every time, so a loop wound
    the other way is still recognized as the same area - and chosen by the
    one rule every plane key in the program now shares, see uRegion }
  Result.Nm := CanonicalNormal(R.Normal);
  N := Length(R.Outer);
  Result.Mid := P3(0, 0, 0);
  for K := 0 to N - 1 do
    Result.Mid := P3(Result.Mid.X + R.Outer[K].X, Result.Mid.Y + R.Outer[K].Y,
                     Result.Mid.Z + R.Outer[K].Z);
  if N > 0 then
    Result.Mid := P3(Result.Mid.X / N, Result.Mid.Y / N, Result.Mid.Z / N);
  Result.D := Dot3(Result.Mid, Result.Nm);
  Result.Area := Abs(LoopArea(R.Outer, R.Normal));
end;

function SameRegion(const A, B: TRegionSig): Boolean;
begin
  Result := (A.Part = B.Part) and (Abs(A.Nm.X - B.Nm.X) < 1E-6) and (Abs(A.Nm.Y - B.Nm.Y) < 1E-6) and
            (Abs(A.Nm.Z - B.Nm.Z) < 1E-6) and (Abs(A.D - B.D) < 1E-4) and
            (Abs(A.Area - B.Area) < 1E-3) and (Dist(A.Mid, B.Mid) < 1E-4);
end;

{ The flat areas as they stand, taken as read rather than acted on.

  Used on the way in from a file that already carries its faces: everything
  in it is then something this sheet has seen, so nothing counts as newly
  closed and no face is invented over the top of what was saved - including
  the ones somebody had rubbed out. }
procedure TMainForm.SeedRegions;
var
  R: TRegionArray;
  Parts: TIntArrayW;
  I, P, Base, CI: Integer;
begin
  SetLength(FD.Seen, 0);
  Parts := AllPartIds;
  for P := 0 to High(Parts) do
  begin
    { the slot first, on its own: taking the element and growing the array
      in one expression let the address be worked out before the growth }
    CI := CacheFor(Parts[P]);
    R := BuildRegionsCached(EdgeSegments(Parts[P]), FRegionCaches[CI].Cache);
    Base := Length(FD.Seen);
    SetLength(FD.Seen, Base + Length(R));
    for I := 0 to High(R) do
    begin
      if ((I and 63) = 0) and (Length(R) > 500) then
        if not OnProgress('Working out the faces', I / Length(R)) then Break;
      FD.Seen[Base + I] := RegionSig(R[I]);
      FD.Seen[Base + I].Part := Parts[P];
    end;
  end;
end;

{ Every group's id, with 0 - the drawing itself - first.  The rebuild works
  each one out on its own: that is the whole of what a group is. }
function TMainForm.AllPartIds: TIntArrayW;
var
  I, N: Integer;
begin
  SetLength(Result, 1);
  Result[0] := 0;
  N := 1;
  for I := 0 to FD.Doc.Live - 1 do
    if FD.Doc[I].Kind = ekPart then
    begin
      if N >= Length(Result) then SetLength(Result, N * 2);
      Result[N] := FD.Doc[I].Grp;
      Inc(N);
    end;
  SetLength(Result, N);
end;

{ the slot of this group's region cache, made if it has none yet }
function TMainForm.CacheFor(Part: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FRegionCaches) do
    if FRegionCaches[I].Part = Part then Exit(I);
  SetLength(FRegionCaches, Length(FRegionCaches) + 1);
  Result := High(FRegionCaches);
  FRegionCaches[Result].Part := Part;
  FRegionCaches[Result].Cache.Keys := nil;
  FRegionCaches[Result].Cache.Sig := nil;
  FRegionCaches[Result].Cache.Found := nil;
end;

function TMainForm.RebuildFlatFaces: Integer;
type
  TWas = record
    Mid: TP3;
    Poly: TP3Array;
    Holes: array of TP3Array;
    Nm: TP3;
    Ink: TColor;
    Part: Integer;
    { what it was painted with.  The ink came across from the start and the
      paint did not, so any edit that had the flat areas worked out again
      washed every loose painted face back to the default - 20 September,
      the Robot's eye }
    Mat: TColor;
    MatSet: Boolean;
  end;
var
  R: TRegionArray;
  Was: array of TWas;
  WasHit: Integer;
  NWas, I, J, K, M, G, Made, DupAt: Integer;
  RegArea, FArea, PiecesArea: Double;
  FN: TP3;
  Pieces: array of Integer;
  Shares: Boolean;
  Mid, Other: TP3;
  Ink: TColor;
  Dup, HadFace, Known: Boolean;
  Sig: TRegionSig;
  HealGrp: Integer;
  SolidIx: TIntArrayW;
  SolidN, SolidP0, SolidMid, RMid: array of TP3;
  SolidRad: array of Double;
  RMidOK: array of Boolean;
  FE: TWorkEnt;
  FLo, FHi: TP3;
  SolidArea: array of Double;
  SI: Integer;
  LineIx, PlaneIx, RegionIx: TFPHashList;
  LineLists, PlaneLists, RegionLists, WasLists, SeenLists: array of TIntArrayW;
  WasIx, SeenIx: TFPHashList;
  WasOn, SeenOn: TIntArrayW;
  Doomed: array of Boolean;
  Acc: array[0..5] of QWord;
  TL: QWord;
  Cands, RCands: TIntArrayW;
  CI, RC: Integer;
  Tk: QWord;
  { which group each area was found in, side by side with R }
  RPart, Parts: TIntArrayW;
  RP: TRegionArray;
  PP, RBase, CurPart: Integer;

  { is P on the segment AB, within a hair }
  function OnSegment(const P, A, B: TP3): Boolean;
  var
    L, T: Double;
    Q: TP3;
  begin
    L := Dist(A, B);
    if L < 1E-9 then Exit(Dist(P, A) < 1E-6);
    T := ((P.X - A.X) * (B.X - A.X) + (P.Y - A.Y) * (B.Y - A.Y) + (P.Z - A.Z) * (B.Z - A.Z)) / (L * L);
    if (T < -1E-6) or (T > 1 + 1E-6) then Exit(False);
    Q := P3(A.X + (B.X - A.X) * T, A.Y + (B.Y - A.Y) * T, A.Z + (B.Z - A.Z) * T);
    Result := Dist(P, Q) < 1E-6;
  end;

  { every edge round the region belongs to a solid: the run of lines that
    covers each side of the outline all carry a group, and one group }
  { an end, and the group it is in: a solid's line in another group is not
    an edge of anything found in this one }
  function EndKey(const P: TP3; Part: Integer): shortstring;
  var
    Q: array[0..3] of Int64;
  begin
    Q[0] := Round(P.X * 1E6); Q[1] := Round(P.Y * 1E6); Q[2] := Round(P.Z * 1E6);
    Q[3] := Part;
    SetLength(Result, 32);
    Move(Q[0], Result[1], 32);
  end;

  procedure NoteLine(const P: TP3; L: Integer);
  var
    Ix: Integer;
  begin
    Ix := LineIx.FindIndexOf(EndKey(P, FD.Doc[L].Part));
    if Ix < 0 then
    begin
      SetLength(LineLists, Length(LineLists) + 1);
      Ix := High(LineLists);
      LineIx.Add(EndKey(P, FD.Doc[L].Part), Pointer(PtrInt(Ix + 1)));
    end
    else
      Ix := PtrInt(LineIx.Items[Ix]) - 1;
    SetLength(LineLists[Ix], Length(LineLists[Ix]) + 1);
    LineLists[Ix][High(LineLists[Ix])] := L;
  end;

  { the solid line, if any, that runs along P-Q, looked up by either end -
    an opening's edges are whole lines of the solid, so one end of the line
    is one end of the edge }
  function GroupLineAlong(const P, Q: TP3): Integer;
  var
    Pass, Ix, K, L: Integer;
    Key: shortstring;
  begin
    Result := -1;
    for Pass := 0 to 1 do
    begin
      if Pass = 0 then Key := EndKey(P, CurPart) else Key := EndKey(Q, CurPart);
      Ix := LineIx.FindIndexOf(Key);
      if Ix < 0 then Continue;
      Ix := PtrInt(LineIx.Items[Ix]) - 1;
      for K := 0 to High(LineLists[Ix]) do
      begin
        L := LineLists[Ix][K];
        if OnSegment(P, FD.Doc[L].A, FD.Doc[L].B) and OnSegment(Q, FD.Doc[L].A, FD.Doc[L].B) then
          Exit(L);
      end;
    end;
  end;

  { a plane as a key: the normal made to point one way, both it and the
    offset rounded coarsely, so faces on one plane land on one key.  The
    fine test still runs on what comes back; this only says who to ask. }
  function PlaneKey(const N, P: TP3; Part: Integer): shortstring;
  var
    Nm: TP3;
    Q: array[0..4] of Int64;
  begin
    Nm := CanonicalNormal(N);
    Q[0] := Round(Nm.X * 1000); Q[1] := Round(Nm.Y * 1000); Q[2] := Round(Nm.Z * 1000);
    Q[3] := Round(Dot3(Nm, P) * 1000);
    { and the group: the same plane in two groups is two planes here }
    Q[4] := Part;
    SetLength(Result, 40);
    Move(Q[0], Result[1], 40);
  end;

  procedure NotePlane(const Key: shortstring; SI: Integer);
  var
    Ix: Integer;
  begin
    Ix := PlaneIx.FindIndexOf(Key);
    if Ix < 0 then
    begin
      SetLength(PlaneLists, Length(PlaneLists) + 1);
      Ix := High(PlaneLists);
      PlaneIx.Add(Key, Pointer(PtrInt(Ix + 1)));
    end
    else
      Ix := PtrInt(PlaneIx.Items[Ix]) - 1;
    SetLength(PlaneLists[Ix], Length(PlaneLists[Ix]) + 1);
    PlaneLists[Ix][High(PlaneLists[Ix])] := SI;
  end;

  procedure NoteRegion(const Key: shortstring; RI: Integer);
  var
    Ix: Integer;
  begin
    Ix := RegionIx.FindIndexOf(Key);
    if Ix < 0 then
    begin
      SetLength(RegionLists, Length(RegionLists) + 1);
      Ix := High(RegionLists);
      RegionIx.Add(Key, Pointer(PtrInt(Ix + 1)));
    end
    else
      Ix := PtrInt(RegionIx.Items[Ix]) - 1;
    SetLength(RegionLists[Ix], Length(RegionLists[Ix]) + 1);
    RegionLists[Ix][High(RegionLists[Ix])] := RI;
  end;

  { the regions on the plane through P with normal N, neighbors of the
    coarse offset included }
  { the same shape of index for anything filed by plane: a list per plane
    key, the entries of the three neighboring offsets returned together }
  procedure NoteInto(H: TFPHashList; var Lists: TIntListsW; const Key: shortstring; Ix: Integer);
  var
    At: Integer;
  begin
    At := H.FindIndexOf(Key);
    if At < 0 then
    begin
      SetLength(Lists, Length(Lists) + 1);
      At := High(Lists);
      H.Add(Key, Pointer(PtrInt(At + 1)));
    end
    else
      At := PtrInt(H.Items[At]) - 1;
    SetLength(Lists[At], Length(Lists[At]) + 1);
    Lists[At][High(Lists[At])] := Ix;
  end;

  function OnPlaneIn(H: TFPHashList; const Lists: TIntListsW; const N, P: TP3; Part: Integer): TIntArrayW;
  var
    Nm: TP3;
    Ix, K, D, Have: Integer;
    Key: shortstring;
    Q: array[0..4] of Int64;
  begin
    Result := nil;
    Have := 0;
    Nm := CanonicalNormal(N);
    Q[0] := Round(Nm.X * 1000); Q[1] := Round(Nm.Y * 1000); Q[2] := Round(Nm.Z * 1000);
    Q[4] := Part;
    for D := -1 to 1 do
    begin
      Q[3] := Round(Dot3(Nm, P) * 1000) + D;
      SetLength(Key, 40);
      Move(Q[0], Key[1], 40);
      Ix := H.FindIndexOf(Key);
      if Ix < 0 then Continue;
      Ix := PtrInt(H.Items[Ix]) - 1;
      SetLength(Result, Have + Length(Lists[Ix]));
      for K := 0 to High(Lists[Ix]) do
      begin
        Result[Have] := Lists[Ix][K];
        Inc(Have);
      end;
    end;
  end;

  procedure Lap(K: Integer);
  begin
    Acc[K] := Acc[K] + (GetTickCount64 - TL);
    TL := GetTickCount64;
  end;

  function RegionsOnPlane(const N, P: TP3; Part: Integer): TIntArrayW;
  var
    Nm: TP3;
    Ix, K, D: Integer;
    Key: shortstring;
    Q: array[0..4] of Int64;
  begin
    Result := nil;
    Nm := CanonicalNormal(N);
    Q[0] := Round(Nm.X * 1000); Q[1] := Round(Nm.Y * 1000); Q[2] := Round(Nm.Z * 1000);
    Q[4] := Part;
    for D := -1 to 1 do
    begin
      Q[3] := Round(Dot3(Nm, P) * 1000) + D;
      SetLength(Key, 40);
      Move(Q[0], Key[1], 40);
      Ix := RegionIx.FindIndexOf(Key);
      if Ix < 0 then Continue;
      Ix := PtrInt(RegionIx.Items[Ix]) - 1;
      for K := 0 to High(RegionLists[Ix]) do
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := RegionLists[Ix][K];
      end;
    end;
  end;

  { the solids on the plane through P with normal N - the key is coarse, so
    a plane a hair off lands on a neighboring key: the offset's neighbors
    are asked too }
  function SolidsOnPlane(const N, P: TP3; Part: Integer): TIntArrayW;
  var
    Nm: TP3;
    Ix, K, D: Integer;
    Key: shortstring;
    Q: array[0..4] of Int64;
  begin
    Result := nil;
    Nm := CanonicalNormal(N);
    Q[0] := Round(Nm.X * 1000); Q[1] := Round(Nm.Y * 1000); Q[2] := Round(Nm.Z * 1000);
    Q[4] := Part;
    for D := -1 to 1 do
    begin
      Q[3] := Round(Dot3(Nm, P) * 1000) + D;
      SetLength(Key, 40);
      Move(Q[0], Key[1], 40);
      Ix := PlaneIx.FindIndexOf(Key);
      if Ix < 0 then Continue;
      Ix := PtrInt(PlaneIx.Items[Ix]) - 1;
      for K := 0 to High(PlaneLists[Ix]) do
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := PlaneLists[Ix][K];
      end;
    end;
  end;

  function OpeningOfSolid(const Rg: TRegion; out Grp: Integer): Boolean;
  var
    E, L: Integer;
    P, Q: TP3;
  begin
    Result := False;
    Grp := 0;
    for E := 0 to High(Rg.Outer) do
    begin
      P := Rg.Outer[E];
      Q := Rg.Outer[(E + 1) mod Length(Rg.Outer)];
      L := GroupLineAlong(P, Q);
      if L < 0 then Exit(False);
      if (Grp > 0) and (FD.Doc[L].Grp <> Grp) then Exit(False);
      Grp := FD.Doc[L].Grp;
    end;
    Result := Grp > 0;
  end;

  { the middle of a built solid, for pointing a face away from it }
  function SolidMidOf(G: Integer): TP3;
  var
    E, K, N: Integer;
  begin
    Result := P3(0, 0, 0);
    N := 0;
    for E := 0 to FD.Doc.Live - 1 do
      if (FD.Doc[E].Kind = ekFace) and (FD.Doc[E].Grp = G) then
        for K := 0 to High(FD.Doc[E].Poly) do
        begin
          Result := P3(Result.X + FD.Doc[E].Poly[K].X,
                       Result.Y + FD.Doc[E].Poly[K].Y,
                       Result.Z + FD.Doc[E].Poly[K].Z);
          Inc(N);
        end;
    if N > 0 then Result := P3(Result.X / N, Result.Y / N, Result.Z / N);
  end;

  { Has the line just drawn been traced along one of this region's sides?

    That is SketchUp's healing gesture and the only way back to a face that
    was deliberately rubbed out: the area is remembered as one somebody did
    not want, and redrawing a bounding edge says otherwise.  It beats both
    that memory and the rule about a built solid's openings, because either
    way the person has just gone to the trouble of tracing an edge that was
    already there, and there is nothing else that gesture could mean. }
  function HealsThis(const Rg: TRegion): Boolean;
  var
    E: Integer;
    P, Q: TP3;
  begin
    Result := False;
    if not FHealOn then Exit;
    for E := 0 to High(Rg.Outer) do
    begin
      P := Rg.Outer[E];
      Q := Rg.Outer[(E + 1) mod Length(Rg.Outer)];
      if SharesRun(P, Q, FHealA, FHealB) then Exit(True);
    end;
  end;

  { whether the face that was here lies in the plane of the region being
    looked at - same normal, and the region's middle on its plane }
  function OnPlaneOf(W: Integer): Boolean;
  begin
    Result := (Abs(Abs(Dot3(Was[W].Nm, R[I].Normal)) - 1) < 1E-6) and
      (Abs(Dot3(Was[W].Nm, P3(Mid.X - Was[W].Poly[0].X, Mid.Y - Was[W].Poly[0].Y,
                              Mid.Z - Was[W].Poly[0].Z))) < 1E-4);
  end;

  { Did the face that was here actually cover this point - inside its
    outline and not inside one of its openings.  A footing ring with the
    middle rubbed out is a face with a hole; asking only about the outline
    said the middle "had a face", and gave it one back every rebuild. }
  function WasCovering(W: Integer): Boolean;
  var
    H: Integer;
  begin
    Result := OnPlaneOf(W) and PointInLoop(Mid, Was[W].Poly, Was[W].Nm);
    if not Result then Exit;
    for H := 0 to High(Was[W].Holes) do
      if PointInLoop(Mid, Was[W].Holes[H], Was[W].Nm) then Exit(False);
  end;

begin
  Tk := GetTickCount64;
  { One pass of the finder per group, each with only its own edges, and the
    areas put side by side with a note of which group each came from.  This
    is the line that makes a group a group: geometry in one does not close
    an area with geometry in another. }
  R := nil;
  RPart := nil;
  Parts := AllPartIds;
  for PP := 0 to High(Parts) do
  begin
    CI := CacheFor(Parts[PP]);      { the slot first - see SeedRegions }
    RP := BuildRegionsCached(EdgeSegments(Parts[PP]), FRegionCaches[CI].Cache);
    RBase := Length(R);
    SetLength(R, RBase + Length(RP));
    SetLength(RPart, RBase + Length(RP));
    for I := 0 to High(RP) do
    begin
      R[RBase + I] := RP[I];
      RPart[RBase + I] := Parts[PP];
    end;
  end;
  Took('  regions', Tk);
  Tk := GetTickCount64;
  Made := 0;
  { the regions by plane, for the pass below and the loop after it; the
    regions do not shift when faces are deleted, so this can be built now }
  RegionIx := TFPHashList.Create;
  SetLength(RegionLists, 0);
  for I := 0 to High(R) do
    if Length(R[I].Outer) >= 3 then
      NoteRegion(PlaneKey(R[I].Normal, R[I].Outer[0], RPart[I]), I);

  { A solid's face divided by what has been drawn on it.

    An arc whose chord is the top edge of a box closes a region of its own,
    and the region finder sees the top as two pieces: the bite and the rest.
    Neither piece is the face the solid has, so neither matched it, a loose
    face was laid over each piece, and the solid's own top stayed whole
    underneath - so the rounded-off end could not be pushed, because there was
    nothing solid there to push.  A box already pulled up could not have its
    end rounded off.

    When the pieces that lie on a solid's face add up to that face, and at
    least one of them shares an edge with its outline - which is what tells a
    cut from a window drawn in the middle - the face is replaced by the
    pieces, each one a face of the same solid.  Then push finds a piece and
    lifts it, which is the whole point. }
  SetLength(Doomed, FD.Doc.Live);
  for J := 0 to High(Doomed) do Doomed[J] := False;
  SetLength(RMid, Length(R));
  SetLength(RMidOK, Length(R));
  for J := 0 to High(RMidOK) do RMidOK[J] := False;
  for J := FD.Doc.Live - 1 downto 0 do
  begin
    if (FD.Doc[J].Kind <> ekFace) or not FD.Doc[J].Solid then Continue;
    if Length(FD.Doc[J].Holes) > 0 then Continue;
    { one copy of the face, not one per corner per candidate: the indexer
      hands back a copy of the whole record every time }
    FE := FD.Doc[J];
    FN := FD.Doc.FaceNormal(J);
    FArea := Abs(LoopArea(FE.Poly, FN));
    if FArea < 1E-9 then Continue;
    FLo := FE.Poly[0];
    FHi := FE.Poly[0];
    for K := 1 to High(FE.Poly) do
    begin
      FLo := P3(Min(FLo.X, FE.Poly[K].X), Min(FLo.Y, FE.Poly[K].Y), Min(FLo.Z, FE.Poly[K].Z));
      FHi := P3(Max(FHi.X, FE.Poly[K].X), Max(FHi.Y, FE.Poly[K].Y), Max(FHi.Z, FE.Poly[K].Z));
    end;
    SetLength(Pieces, 0);
    PiecesArea := 0;
    Shares := False;
    RCands := RegionsOnPlane(FN, FE.Poly[0], FE.Part);
    for RC := 0 to High(RCands) do
    begin
      I := RCands[RC];
      if Length(R[I].Holes) > 0 then Continue;
      { a region's middle, once - the plane has thousands of regions and
        every face on it asks about all of them }
      if not RMidOK[I] then
      begin
        RMid[I] := InnerPoint(R[I].Outer, R[I].Normal);
        RMidOK[I] := True;
      end;
      Mid := RMid[I];
      { outside the box round the face is not on it; this is what makes
        the pass cheap on a plane full of faces }
      if (Mid.X < FLo.X - 1E-4) or (Mid.X > FHi.X + 1E-4) or
         (Mid.Y < FLo.Y - 1E-4) or (Mid.Y > FHi.Y + 1E-4) or
         (Mid.Z < FLo.Z - 1E-4) or (Mid.Z > FHi.Z + 1E-4) then Continue;
      if Abs(Abs(Dot3(Norm3(R[I].Normal), FN)) - 1) > 1E-6 then Continue;
      if Abs(Dot3(FN, P3(Mid.X - FE.Poly[0].X,
                          Mid.Y - FE.Poly[0].Y,
                          Mid.Z - FE.Poly[0].Z))) > 1E-4 then Continue;
      if not PointInLoop(Mid, FE.Poly, FN) then Continue;
      { the whole face is itself a region; that is not a division }
      if Abs(Abs(LoopArea(R[I].Outer, R[I].Normal)) - FArea) < 1E-3 then
        Continue;
      SetLength(Pieces, Length(Pieces) + 1);
      Pieces[High(Pieces)] := I;
      PiecesArea := PiecesArea + Abs(LoopArea(R[I].Outer, R[I].Normal));
      { A piece shares the outline when one of its edges lies along one of
        the face's edges.  It used to want two consecutive corners of the
        piece to be two consecutive corners of the face, which stops being
        true the moment anything else has split the face's edge - a tunnel
        coming out beside it, say - and then the wall would not be divided
        for a bite drawn on it. }
      if not Shares then
        for K := 0 to High(R[I].Outer) do
          for M := 0 to High(FE.Poly) do
            if OnSegment(R[I].Outer[K], FE.Poly[M],
                         FE.Poly[(M + 1) mod Length(FE.Poly)]) and
               OnSegment(R[I].Outer[(K + 1) mod Length(R[I].Outer)], FE.Poly[M],
                         FE.Poly[(M + 1) mod Length(FE.Poly)]) then
              Shares := True;
    end;
    if (Length(Pieces) < 2) or not Shares then Continue;
    if Abs(PiecesArea - FArea) > 1E-3 * (1 + FArea) then Continue;

    { replace it: the pieces become faces of the same solid }
    G := FD.Doc[J].Grp;
    Ink := FD.Doc[J].Ink;
    Doomed[J] := True;
    FD.Doc.Stamp := FE.Part;       { the pieces are born into the solid's group }
    for I := 0 to High(Pieces) do
    begin
      FD.Doc.AddFaceRaw(R[Pieces[I]].Outer, Ink, True);
      FD.Doc.SetFaceGroup(FD.Doc.Live - 1, G);
      { facing the way the face it replaces faced - a region's outline runs
        whichever way the finder walked it, and a piece wound the other way
        is a back face, drawn blue as the inside of the box }
      if Dot3(FD.Doc.FaceNormal(FD.Doc.Live - 1), FN) < 0 then
        FD.Doc.FlipFace(FD.Doc.Live - 1);
    end;
  end;

  FD.Doc.Stamp := FD.Doc.Context;
  { the faces that were divided go now, in one pass - one at a time each
    shifted everything after it }
  FD.Doc.DeleteMarked(Doomed);
  Took('  tiling', Tk);
  Tk := GetTickCount64;
  { remember what was there, so the new faces can take their colors }
  NWas := 0;
  SetLength(Was, FD.Doc.Live);
  for I := 0 to FD.Doc.Live - 1 do
    if (FD.Doc[I].Kind = ekFace) and not FD.Doc[I].Solid and
       (Length(FD.Doc[I].Poly) >= 3) then
    begin
      Was[NWas].Poly := Copy(FD.Doc[I].Poly, 0, Length(FD.Doc[I].Poly));
      SetLength(Was[NWas].Holes, Length(FD.Doc[I].Holes));
      for J := 0 to High(FD.Doc[I].Holes) do
        Was[NWas].Holes[J] := Copy(FD.Doc[I].Holes[J], 0, Length(FD.Doc[I].Holes[J]));
      Was[NWas].Nm := FD.Doc.FaceNormal(I);
      Was[NWas].Ink := FD.Doc[I].Ink;
      Was[NWas].Part := FD.Doc[I].Part;
      Was[NWas].Mat := FD.Doc[I].Mat;
      Was[NWas].MatSet := FD.Doc[I].MatSet;
      Mid := P3(0, 0, 0);
      for K := 0 to High(Was[NWas].Poly) do
        Mid := P3(Mid.X + Was[NWas].Poly[K].X, Mid.Y + Was[NWas].Poly[K].Y,
                  Mid.Z + Was[NWas].Poly[K].Z);
      K := Length(Was[NWas].Poly);
      Was[NWas].Mid := P3(Mid.X / K, Mid.Y / K, Mid.Z / K);
      Inc(NWas);
    end;
  SetLength(Was, NWas);
  { the old faces by plane, so a region asks only the ones in its own plane
    - not all fifteen thousand of them, fifteen thousand times }
  WasIx := TFPHashList.Create;
  SetLength(WasLists, 0);
  for J := 0 to NWas - 1 do
    NoteInto(WasIx, WasLists, PlaneKey(Was[J].Nm, Was[J].Mid, Was[J].Part), J);
  { and what the sheet had seen, the same way }
  SeenIx := TFPHashList.Create;
  SetLength(SeenLists, 0);
  for J := 0 to High(FD.Seen) do
    NoteInto(SeenIx, SeenLists, PlaneKey(FD.Seen[J].Nm, FD.Seen[J].Mid, FD.Seen[J].Part), J);

  { out with the old, in one pass; one at a time each shifted everything
    after it, which on a big drawing was most of a minute }
  SetLength(Doomed, FD.Doc.Live);
  for I := 0 to FD.Doc.Live - 1 do
    Doomed[I] := (FD.Doc[I].Kind = ekFace) and not FD.Doc[I].Solid;
  FD.Doc.DeleteMarked(Doomed);
  Took('  old faces out', Tk);
  Tk := GetTickCount64;

  { The solids' faces, their planes and areas, and the solids' lines by
    their ends, once - the loop below asks every region against them.
    Built here, after the pass above, and not before it: that pass deletes
    faces and adds pieces, which shifts every index after the deleted one,
    and a table built earlier pointed at the wrong things - which on a big
    drawing was an access violation in the middle of a move. }
  SetLength(SolidIx, 0);
  for J := 0 to FD.Doc.Live - 1 do
    if (FD.Doc[J].Kind = ekFace) and FD.Doc[J].Solid and (Length(FD.Doc[J].Poly) >= 3) then
    begin
      SetLength(SolidIx, Length(SolidIx) + 1);
      SolidIx[High(SolidIx)] := J;
    end;
  SetLength(SolidN, Length(SolidIx));
  SetLength(SolidP0, Length(SolidIx));
  SetLength(SolidMid, Length(SolidIx));
  SetLength(SolidRad, Length(SolidIx));
  SetLength(SolidArea, Length(SolidIx));
  PlaneIx := TFPHashList.Create;
  SetLength(PlaneLists, 0);
  for J := 0 to High(SolidIx) do
  begin
    SolidN[J] := FD.Doc.FaceNormal(SolidIx[J]);
    FE := FD.Doc[SolidIx[J]];
    SolidP0[J] := FE.Poly[0];
    Mid := P3(0, 0, 0);
    for K := 0 to High(FE.Poly) do
      Mid := P3(Mid.X + FE.Poly[K].X, Mid.Y + FE.Poly[K].Y, Mid.Z + FE.Poly[K].Z);
    K := Length(FE.Poly);
    SolidMid[J] := P3(Mid.X / K, Mid.Y / K, Mid.Z / K);
    SolidRad[J] := 0;
    for K := 0 to High(FE.Poly) do
      SolidRad[J] := Max(SolidRad[J], Dist(SolidMid[J], FE.Poly[K]));
    SolidArea[J] := Abs(LoopArea(FD.Doc[SolidIx[J]].Poly, SolidN[J]));
    { by plane, so a region meets only the solids lying in its own plane
      rather than every solid in the drawing }
    NotePlane(PlaneKey(SolidN[J], FD.Doc[SolidIx[J]].Poly[0], FD.Doc[SolidIx[J]].Part), J);
  end;
  { and the solids' lines by their ends, for the opening test }
  LineIx := TFPHashList.Create;
  SetLength(LineLists, 0);
  for J := 0 to FD.Doc.Live - 1 do
    if (FD.Doc[J].Kind = ekLine) and (FD.Doc[J].Grp > 0) then
    begin
      NoteLine(FD.Doc[J].A, J);
      NoteLine(FD.Doc[J].B, J);
    end;

  Took('  tables', Tk);
  Tk := GetTickCount64;
  FillChar(Acc, SizeOf(Acc), 0);
  { a region with no outline is nothing to look at }
  for I := 0 to High(R) do
  begin
    if ((I and 63) = 0) and (Length(R) > 500) then
      if not OnProgress('Working out the faces', I / Length(R)) then Break;
    if Length(R[I].Outer) < 3 then Continue;
    TL := GetTickCount64;
    { this area's group: the tables answer for it alone, and the face it
      may become is born into it }
    CurPart := RPart[I];
    FD.Doc.Stamp := CurPart;
    Mid := InnerPointOf(R[I].Outer, R[I].Holes, R[I].Normal);
    Lap(0);

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
    DupAt := -1;
    RegArea := -1;
    Cands := SolidsOnPlane(R[I].Normal, R[I].Outer[0], RPart[I]);
    for CI := 0 to High(Cands) do
      begin
        SI := Cands[CI];
        J := SolidIx[SI];
        Other := SolidN[SI];
        if Abs(Abs(Dot3(Other, R[I].Normal)) - 1) > 1E-6 then Continue;
        { the same plane, not merely a parallel one }
        if Abs(Dot3(Other, P3(SolidP0[SI].X - R[I].Outer[0].X,
                              SolidP0[SI].Y - R[I].Outer[0].Y,
                              SolidP0[SI].Z - R[I].Outer[0].Z))) > 1E-4
          then Continue;
        { Outline against outline, with the openings left out of both.

          This is asking "is this the same face", and the outline is what
          makes it the same face; what has been cut out of it is what changes
          from one rebuild to the next.  Comparing net areas - the first
          version of this after faces learned about holes - meant a wall that
          had just had a window drawn on it was measured with the window and
          the solid's own face without it, 68 against 80, so they never
          matched, and the hand-off below that gives the solid's face its
          opening never ran.  The window drew, and the wall stayed solid. }
        { further from the solid's middle than any of its corners is not
          inside it - and on a plane of a thousand same-sized faces this is
          what keeps PointInLoop to the one that could be }
        if Dist(Mid, SolidMid[SI]) > SolidRad[SI] + 1E-4 then Continue;
        if RegArea < 0 then RegArea := Abs(LoopArea(R[I].Outer, R[I].Normal));
        if Abs(RegArea - SolidArea[SI]) > 1E-3 then
          Continue;
        if PointInLoop(Mid, FD.Doc[J].Poly, Other) then
        begin
          Dup := True;
          DupAt := J;
          Break;
        end;
      end;
    Lap(1);
    if Dup then
    begin
      { The solid already has this face, so no second one is made - but the
        area may have gained a hole since, and the solid's own face is the
        thing that has to know about it.

        This is what a window in a column is.  Drawing a rectangle on the
        side of a solid does not cut that side in two, because the rectangle
        is wholly inside it and crosses nothing.  The region finder sees the
        side as a shape with a hole in it, and that answer used to be thrown
        away in favor of the solid's own face - which had no hole, and so
        went on covering the window.  Handing the holes over keeps the
        solid's face and gives it the opening. }
      if DupAt >= 0 then FD.Doc.SetFaceHoles(DupAt, R[I].Holes);
      Continue;
    end;

    { Did this area have a face a moment ago, and had this sheet seen it
      before?

      An area that was here before and has no face now is one whose face was
      rubbed out on purpose, and it does not get another.  That is the whole
      of what "delete a face and see through it" needs: without it the four
      edges still closed a loop, the loop was still an area, and the area was
      handed a fresh face on the next rebuild - so a window could not be made
      in anything.

      An area nobody has seen before has just been closed by whatever edge
      was drawn, and that is exactly when a face should appear. }
    { In the same plane, not merely containing the point when it is dropped
      onto that plane.  PointInLoop projects along the normal, so a face on
      the far end of a box "contained" the middle of an area on the near end
      - the two ends are parallel - and an arc erased off one end was handed
      straight back because its twin on the other end was still there. }
    HadFace := False;
    WasOn := OnPlaneIn(WasIx, WasLists, R[I].Normal, Mid, RPart[I]);
    for J := 0 to High(WasOn) do
      if WasCovering(WasOn[J]) then
      begin
        HadFace := True;
        Break;
      end;
    if not HadFace and not HealsThis(R[I]) then
    begin
      { An opening of a built solid - a duct end, a pipe end, a hole rubbed
        out of a box - is edged entirely by that solid's own edges.  It is
        never a place for a face, however it got here: moved, turned, copied,
        or read back from a file, none of which leave a note that it was
        seen before.  Something drawn across it is a loose edge, and then it
        is a new area like any other. }
      Lap(2);
      if OpeningOfSolid(R[I], HealGrp) then begin Lap(3); Continue; end;
      Lap(3);
      Sig := RegionSig(R[I]);
      Sig.Part := RPart[I];
      Known := False;
      SeenOn := OnPlaneIn(SeenIx, SeenLists, Sig.Nm, Sig.Mid, RPart[I]);
      for J := 0 to High(SeenOn) do
        if SameRegion(Sig, FD.Seen[SeenOn[J]]) then
        begin
          Known := True;
          Break;
        end;
      Lap(4);
      if Known then Continue;
    end;

    Ink := FInkColor;
    WasHit := -1;
    for J := 0 to High(WasOn) do
      if WasCovering(WasOn[J]) then
      begin
        Ink := Was[WasOn[J]].Ink;
        WasHit := WasOn[J];
        Break;
      end;
    FD.Doc.AddFace(R[I].Outer, Ink, False);
    { the face it replaces was painted, and faced a way: both come across.
      A face that came back the other way round showed its back, in blue,
      where a moment before it had been the front of something. }
    if WasHit >= 0 then
    begin
      if Was[WasHit].MatSet then
        FD.Doc.SetMaterial(FD.Doc.Live - 1, Was[WasHit].Mat);
      if Dot3(FD.Doc.FaceNormal(FD.Doc.Live - 1), Was[WasHit].Nm) < 0 then
        FD.Doc.FlipFace(FD.Doc.Live - 1);
    end;
    { and whatever is cut out of it.  The region finder has worked these out
      all along; nothing was asking for them, so a wall with a window in it
      was filled in solid and the window could only be seen by its edges. }
    if Length(R[I].Holes) > 0 then
      FD.Doc.SetFaceHoles(FD.Doc.Live - 1, R[I].Holes);
    { A side of a box traced back in belongs to the box, not beside it.
      Left loose it would be thrown away and worked out again on the next
      rebuild - and refused, because the hole in a solid is not a place for
      a loose face - so the healing would last until the next edit.  Joined
      to the solid it stays, and /holes agrees the box is closed again. }
    if FHealOn and HealsThis(R[I]) and OpeningOfSolid(R[I], HealGrp) then
    begin
      FD.Doc.SetFaceGroup(FD.Doc.Live - 1, HealGrp);
      { facing out, like every other side of the solid: away from the middle
        of the thing it has just closed }
      { The area's own middle is worked out in the tiling pass above, and
        only for areas that pass has reason to look at - an opening being
        healed has no solid face on its plane, so it never was, and the
        test below read (0,0,0) for it.  A top traced back onto a box came
        back facing into the box, blue.  Worked out here when it is not. }
      if not RMidOK[I] then
      begin
        RMid[I] := InnerPoint(R[I].Outer, R[I].Normal);
        RMidOK[I] := True;
      end;
      Mid := SolidMidOf(HealGrp);
      if Dot3(FD.Doc.FaceNormal(FD.Doc.Live - 1),
              P3(RMid[I].X - Mid.X, RMid[I].Y - Mid.Y, RMid[I].Z - Mid.Z)) < 0 then
        FD.Doc.FlipFace(FD.Doc.Live - 1);
    end;
    Inc(Made);
    Lap(5);
  end;
  if FTimings then
    TimingLine(Format('region loop phases ms: inner %d dup %d was %d opening %d seen %d add %d',
      [Acc[0], Acc[1], Acc[2], Acc[3], Acc[4], Acc[5]]));
  LineIx.Free;
  PlaneIx.Free;
  RegionIx.Free;
  WasIx.Free;
  SeenIx.Free;
  if not FLoading then EndBusy;
  FD.Doc.Stamp := FD.Doc.Context;
  Took('  the region loop', Tk);
  Tk := GetTickCount64;
  { and this is what the sheet has seen, for the next rebuild to compare
    against }
  SetLength(FD.Seen, Length(R));
  for I := 0 to High(R) do
  begin
    FD.Seen[I] := RegionSig(R[I]);
    FD.Seen[I].Part := RPart[I];
  end;
  Took('  seen signatures', Tk);

  { Then make the loose faces agree with each other about which way is out.

    Every face here was wound by OrientFace, which looks at one face at a
    time and points it along whichever axis it faces most.  That is the best
    a single face can do, and in company it is wrong about half the time: the
    two slopes of a roof both come out pointing the same way, when out for
    one of them is the opposite of out for the other.  A face pointing into
    the shape it belongs to is drawn in the back-face color, and that is
    what reaches somebody - blue patches on a house, from the outside, where
    people stand.

    It belongs here rather than in the region finder because it is not a
    question any one region can answer; it needs the neighbors, and the
    neighbors only all exist once the loop above has finished. }
  FTurned := 0;
  for PP := 0 to High(Parts) do
    FTurned := FTurned + FD.Doc.OrientLooseShells(Parts[PP]);
  Took('  turning loose faces the right way out', Tk);

  Result := Made;
end;

{ A read-only look at what the region engine makes of this drawing, next to
  the faces actually stored.  It changes nothing - it is here so the new way
  can be checked against real drawings before anything depends on it. }
procedure TMainForm.ReportRegions;
var
  R: TRegionArray;
  Segs: TSegArray;
  I, Stored, Holes, CI: Integer;
  Area, StoredArea, T0: Double;
begin
  Segs := EdgeSegments(FD.Doc.Context);
  T0 := Now;
  CI := CacheFor(FD.Doc.Context);
  R := BuildRegionsCached(Segs, FRegionCaches[CI].Cache);
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

{ A dimension's offset, kept out of the shape it measures.

  A dimension on the edge of a closed shape can be dropped on the inside, and
  then its line and its figure sit across the face - which is where the next
  thing you draw is going, and where nobody reads a dimension from.  If the
  edge belongs to a face and the offset would put the dimension line inside
  that face, it is turned round to the other side.  An offset that already
  clears the face is left exactly where it was put. }
function TMainForm.OutsideOf(const A, B, Off: TP3): TP3;
var
  I, K, N: Integer;
  Mid, Nm: TP3;
begin
  Result := Off;
  for I := 0 to FD.Doc.Live - 1 do
  begin
    if FD.Doc[I].Kind <> ekFace then Continue;
    N := Length(FD.Doc[I].Poly);
    if N < 3 then Continue;
    for K := 0 to N - 1 do
      if ((Dist(FD.Doc[I].Poly[K], A) < 1E-6) and
          (Dist(FD.Doc[I].Poly[(K + 1) mod N], B) < 1E-6)) or
         ((Dist(FD.Doc[I].Poly[K], B) < 1E-6) and
          (Dist(FD.Doc[I].Poly[(K + 1) mod N], A) < 1E-6)) then
      begin
        Mid := P3((A.X + B.X) / 2 + Off.X, (A.Y + B.Y) / 2 + Off.Y,
                  (A.Z + B.Z) / 2 + Off.Z);
        Nm := FD.Doc.FaceNormal(I);
        if PointInLoop(Mid, FD.Doc[I].Poly, Nm) then
          Result := P3(-Off.X, -Off.Y, -Off.Z);
        Exit;
      end;
  end;
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
var
  NoteI: Integer;
begin
  if FBusy then Exit;
  { the cube, if it had the press }
  if FCubeDrag then
  begin
    CubeMouse(X, Y, False, True);
    pbScreen.Invalidate;
    Exit;
  end;
  { let go of a note being carried }
  if FNoteDrag >= 0 then
  begin
    NoteI := FNoteDrag;
    FNoteDrag := -1;
    if not FNoteMoved then
    begin
      { The press took hold of the note in case it was going to be carried,
        and it was not: the button came straight back up.  That is a click,
        and a click on a thing picks it - the same as everywhere else - so the
        note can be sized or deleted.  It used to fall through to nothing. }
      SelectOnly(NoteI);
      FCmdMsg := '';
      pbCmd.Invalidate;
      FScreenDirty := True;
      Exit;
    end;
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
    from the first click stays where it landed, which is the bit What was wanted was
    kept.  One click carries the line on as always. }
  if FHoldOn and (Button = mbLeft) then
  begin
    FHoldOn := False;
    FCur := ResolveSnapAt(X, Y);
    { A second click in quick succession lets go of a run of lines.  That is
      a thing about runs of lines and nothing else: on push/pull a double
      click repeats the last pull, which the tool handles itself. }
    { the arc's double-click is SketchUp's: trim the corner just rounded,
      or round the corner under the pointer with the same radius }
    if (FClickN >= 2) and (FTool = ptArc) and ArcDoubleClick(X, Y) then
    begin
      FScreenDirty := True;
      Exit;
    end;
    if (FClickN >= 2) and (FTool in [ptLine, ptRect, ptCircle, ptArc]) then
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
    if FEraseMode = 0 then BurnDoomed
    else SoftenDoomed(FEraseMode = 1);
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
    { Ctrl held as the button comes up: click into the nearest of the view
      cube's twenty-six, with the cube's own animation.

      Ctrl rather than Alt, and that is a practical choice rather than a
      taste one - every window manager worth the name takes Alt and a drag
      for itself to move the window, so an Alt-orbit is somebody else's
      gesture half the time.  Shift is already the pan.  Ctrl does nothing
      at all during an orbit, and is read here rather than at mouse-down so
      it can be grabbed part way through the turn - which is how the whole
      thing was described: orbit round to something you like, then hold it
      and let go. }
    if FOrbiting and (ssCtrl in Shift) then SnapOrbitToNearest;
    FSnapHasHot := False;
    FPanning := False;
    FOrbiting := False;
    if FTool = ptOrbit then pbScreen.Cursor := crSizeAll
    else pbScreen.Cursor := crCross;
    { the camera has stopped: one full frame over the quick ones }
    if FCameraMoving then
    begin
      FCameraMoving := False;
      RepaintPaper;
      RenderPro;
      RecomposeAll;
      Invalidate;
    end;
    { A right button that went down and came up in the same place was a
      click, not a pan, and a click opens the menu - or edits a dimension,
      which is what it did before there was a menu.  The pan still owns the
      right button everywhere else, which is why this has to wait for the
      release and check that nothing moved. }
    if (Button = mbRight) and (FMode = mdPro) and
       (Abs(X - FRightSX) <= 3) and (Abs(Y - FRightSY) <= 3) then
      RightClickAt(X, Y);
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
const
  WHEEL_ROWS = 3;      { rows per notch, the same as most lists }
begin
  if FBusy then Exit;
  if FMode <> mdPro then Exit;
  { a list in front of the drawing gets the wheel before the drawing does }
  if ScrollPopup(IfThen(WheelDelta > 0, -WHEEL_ROWS, WHEEL_ROWS),
                 MousePos.X, MousePos.Y) then
  begin
    Handled := True;
    Exit;
  end;
  { and so does the cube.  Zooming the model because the pointer happened to
    be resting on the cube is the same surprise, in miniature. }
  if OverCube(MousePos.X, MousePos.Y) or CubeZone(MousePos.X, MousePos.Y) then
  begin
    Handled := True;
    Exit;
  end;
  { Ctrl and the wheel travels up and down through the model, carrying the
    whole slice with it.

    Over the drawing rather than only over the two fields, because the thing
    people actually do is scroll until the plan looks right - and for that
    your eyes have to be on the plan, not on a widget in the corner.  Plain
    wheel stays zoom, which it has always been; Alt is taken (it suspends
    snapping for a move), so Ctrl is the one that was free. }
  if (ssCtrl in Shift) and (FD.View = vkPlan) then
  begin
    if not FD.SliceOn then
      SetSlice(True, FD.SliceLo, FD.SliceHi)
    else if WheelDelta > 0 then NudgeSlice(1, 0)
    else NudgeSlice(-1, 0);
    Handled := True;
    Exit;
  end;
  if WheelDelta > 0 then
    ZoomAt(1.15, MousePos.X, MousePos.Y)
  else
    ZoomAt(1 / 1.15, MousePos.X, MousePos.Y);
  Handled := True;
end;

{ ======================================================================== }
{ window painting                                                           }
{ ======================================================================== }

{ Is the cursor on something a dimension may be anchored to?

  SketchUp's list, from their own documentation: end points, midpoints,
  on-edge points, intersections, and arc and circle centers.  Ours adds the
  origin, which is a landmark of the model rather than a place the cursor
  happened to be, and a point on an axis for the same reason.

  What is left out is the grid and open air, and that is the whole point of
  the test: a dimension that measures from nothing to nothing cannot be
  driven by the drawing and will never update when the drawing changes. }
function TMainForm.DimAnchored: Boolean;
begin
  Result := FSnapKind in [snEndpoint, snMidpoint, snCenter, snCross,
                          snSubMid, snQuadrant, snOnEdge, snOnFace,
                          snOnAxis, snOrigin];
end;

{ The zoom, in words that survive the range it now has.

  It was one number and no decimals, which read "view 0%" as soon as the view
  could be wound out past a fiftieth - a readout that says nothing is worse
  than no readout, because it looks like an answer. }
function TMainForm.ZoomReading: string;
var
  Z: Double;
begin
  Z := FD.Zoom * 100;
  if Z >= 100 then Result := Format('%.0f%%', [Z])
  else if Z >= 10 then Result := Format('%.1f%%', [Z])
  else if Z >= 1 then Result := Format('%.2f%%', [Z])
  else Result := Format('%.3f%%', [Z]);
end;

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
  if (FStage = 0) and (FTool in [ptPush, ptDrill]) and (FHoverFace >= 0) then
    Result := Result + '   FACE ' +
      FormatArea(FD.Doc.FaceArea(FHoverFace), FD.Units);

  if (FStage = 1) and (FTool in [ptPush, ptDrill]) and (FPushFace >= 0) then
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
  M, TitleH, Y, TW, RightEdge, MidW: Integer;
  S: string;
begin
  if not FBooted then Exit;
  FShell.DrawTo(Canvas, 0, 0);

  M := ChromeMargin;
  TitleH := TitleHeight;

  if FMode = mdPro then
  begin
    { One line, and the left of it belongs to the buttons now.

      The name and the version sat here, pushing Open and Save into the far
      bottom corner among twelve identical squares.  A drafting board does
      not need its own name across the top - the window title says it, the
      About box says it - so the name moves to the middle where it is a
      quiet mark rather than a claim on the best real estate on the screen,
      and the buttons take the corner every program keeps them in.

      The middle is also only drawn when there is room between the buttons
      and the reading, and the version stays with it either way: it is the
      first thing anybody has to say when something goes wrong. }
    Y := Round(5 * FUIScale);

    { The reading goes hard against the right edge.

      It used to stop two hundred pixels short, because the TOY/PRO switch
      sat at the right of this same line and a reading that ran underneath
      it was unreadable.  The switch is gone and the room is the reading's:
      X, Y, Z, the plane, the length and the area all grow leftwards from
      here, and every one of them is a number somebody is reading while
      they drag.

      Hard against ClientWidth - M, which is exactly where the VIEW button
      on the row below ends, so the two right edges line up. }
    RightEdge := ClientWidth - M;
    UIFont(Canvas, 11, True, Theme.Text, True);
    S := StatusLine;
    TW := Canvas.TextWidth(S);
    Canvas.TextOut(RightEdge - TW, Round(6 * FUIScale), S);

    { The name has gone from this row.

      It was moved to the middle to give the corner to the file buttons, and
      the middle turned out to be where the reading grows into when a run
      gets long - X, Y, Z, the plane and the length are right-aligned and
      they lengthen leftwards, over the top of it.  A program's own name is
      not worth a collision: the window title says it, the About box says
      it, and nobody drawing needs reminding what they opened.

      The version stays, because it is the first thing anybody has to quote
      when something goes wrong, and so does the notice of a newer one.  Both
      go left, hard against the buttons, where nothing else ever reaches. }
    VerX := pbQuick.Left + pbQuick.Width + Round(16 * FUIScale);
    UIFont(Canvas, 9, False, Theme.TextDim);
    Canvas.TextOut(VerX, Y + Round(4 * FUIScale), CurrentVersion);
    VerX := VerX + Canvas.TextWidth(CurrentVersion) + Round(14 * FUIScale);
    { A newer build, said where it cannot be written over.  It stays until
      the update is taken, which is the point: an announcement that vanishes
      when the next thing happens has not announced anything. }
    if FUpdateTag <> '' then
    begin
      UIFont(Canvas, 9, True, Pix(90, 190, 255));
      S := '* ' + FUpdateTag + ' available - /update';
      if VerX + Canvas.TextWidth(S) < RightEdge - TW - Round(16 * FUIScale) then
        Canvas.TextOut(VerX, Y + Round(4 * FUIScale), S);
    end;

    { The hover text used to be painted along here, and it is gone.

      It was the only place a hover was ever reported, seven hundred pixels
      from the pointer in the dimmest type on the window, and it repeated
      what the status line at the bottom already says about the tool in
      hand.  Two faults in one line: it was not a tooltip, and the thing it
      did say was said better elsewhere.  The file buttons stand here now,
      and a hover draws a card beside whatever it is about - see
      PaintChromeTip. }

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
  Act('units ' + IntToStr(Ord(U)));
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


procedure TMainForm.PushUndo;
var
  I: Integer;
begin
  { the drawing changed, so whatever would not draw may be gone now }
  FRenderBroken := False;
  { Everything that changes the drawing comes through here, which makes it
    the one honest place to notice that there is something worth keeping. }
  Inc(FEditSeq);
  if FD <> nil then FD.Dirty := True;
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
  { the drawing is about to become a different one }
  SetLength(FOpenEdges, 0);
  Act('undo');
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
  { the drawing is about to become a different one }
  SetLength(FOpenEdges, 0);
  Act('redo');
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
  Act('clear');
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
  InfoSig: Int64;
  WhatsNewForm: TWhatsNewForm;
  BreakPts: TPointFArray;
  BreakI: Integer;
begin
  Dt := TICK_MS / 1000;

  { the start-up screen comes down once the loading is over and it has had
    its few seconds; while it is up nothing else here matters }
  if SplashUp then
  begin
    if SplashFinished and (SplashAge >= SPLASH_MIN_MS) then SplashHide
    else Exit;
  end;
  { long work lets the messages through to paint its progress, and this
    fires then too: stand down, unless the work is long over and forgot }
  if FBusy then
  begin
    if GetTickCount64 - FBusyAt > 600 then EndBusy;
    Exit;
  end;
  { A dialog has the screen, so this does not.

    Sixty times a second is right for a window somebody is drawing in.  It is
    not right underneath a dialog, where every one of them is the program
    waking up to service a pointer that is somewhere else entirely - and the
    window manager is trying to drag that dialog at the same time.  Dragging
    a dialog on a machine with a compositor was visibly skipping, and this is
    one of the two reasons why.

    ModalLevel counts the stock dialogs too, because TCommonDialog.Execute
    raises it: the print and color dialogs are somebody else's window and
    exactly the ones where this program has no business being busy.

    Nothing here is missed by waiting.  The hints, the draft, the settle
    after a camera move and the rest are all things that catch up on the
    first tick after the dialog goes; none of them is an animation anybody
    can see through a window that is covering them. }
  if Application.ModalLevel > 0 then Exit;

  { The entity panel, worked out again when what it is a reading of has
    changed.  On the tick rather than at every place the selection is
    touched: the selection is changed from a dozen places, two of them bulk
    loops over fifty thousand things, and a rebuild inside those would cost
    more than the panel is worth.  A sixteenth of a second behind is not
    behind. }
  if FInfoOn then
  begin
    InfoSig := FEditSeq * 131 + Length(FSel);
    if Length(FSel) > 0 then
      InfoSig := InfoSig * 131 + FSel[0] * 17 + FSel[High(FSel)];
    if InfoSig <> FInfoSig then
    begin
      FInfoSig := InfoSig;
      RebuildInfo;
      pbInfo.Invalidate;
    end;
  end;

  { a named drawing with changes since it was written says so in the
    header, so a closed window is never a surprise }
  if (FDocPath <> '') and (FEditSeq <> FSavedSeq) and (Pos('unsaved', FHint) = 0) and
     (GetTickCount64 - FLastWheel > 3000) then
    FHint := FDocPath + '   -   unsaved changes  (Ctrl+S)';
  if (FDocPath <> '') and (FEditSeq = FSavedSeq) and (Pos('unsaved', FHint) > 0) then
    FHint := FDocPath;

  if FCrashToOffer and (FPopup = POP_NONE) then
  begin
    FCrashToOffer := False;
    OfferCrashReport(True);
  end;
  TouchTick;

  FollowScreenSize;
  { the wheel has settled: the full frame }
  if FCameraMoving and not (FOrbiting or FPanning) and (GetTickCount64 - FLastWheel > 220) then
  begin
    FCameraMoving := False;
    RepaintPaper;
    RenderPro;
    RecomposeAll;
    Invalidate;
  end;
  ServiceMotion;
  ServiceHover;
  StepGlide(Dt);

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
    if (FUpdatedFrom <> '') and not FWhatsNewShown and (FUpTime > 0.5) then
    begin
      FWhatsNewShown := True;
      uDlgSkin.UseTheme(Themes[FThemeIdx]);
      WhatsNewForm := TWhatsNewForm.CreateNew(Self);
      try
        WhatsNewForm.ShowRelease(FUpdatedFrom, CurrentVersion);
      finally
        WhatsNewForm.Free;
      end;
    end;
    { and once there is a window to put it in front of, last time's crash can
      be offered - not before }
    if (FUpTime > 1.5) and not FAskedAboutCrash then
    begin
      FAskedAboutCrash := True;
      OfferCrashReport(False);
      { And only then look for a newer build.  Asking the network during
        startup meant the window could not appear until the answer came
        back, or the connection gave up - which on a bad line is a program
        that takes half a minute to start for no reason the user can see. }
      CheckForUpdate(False);
      { and the manual beside the program, in step with it }
      KeepHelpCurrent;
    end;
    { The postcard - uHello - once the update question has had its turn
      and nothing else is up.  Second start or later, and only ever once. }
    if (FUpTime > 3.0) and not FPostcardOffered and (Application.ModalLevel = 0) then
    begin
      FPostcardOffered := True;
      if PostcardDue then
      begin
        uDlgSkin.UseTheme(Themes[FThemeIdx]);
        OfferPostcard(Self, CurrentVersion, False);
      end;
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
        { the burst goes in the middle of whatever was destroyed, and only a
          line gets the two ends flying apart }
        FSnapEnds := FTool = ptLine;
        FSnapA := ScreenOf(FP1);
        FSnapB := PtF(FMouseSX, FMouseSY);
        if StrainOutline(BreakPts) and (Length(BreakPts) > 2) then
        begin
          FSnapM := PtF(0, 0);
          for BreakI := 0 to High(BreakPts) do
            FSnapM := PtF(FSnapM.X + BreakPts[BreakI].X / Length(BreakPts),
                          FSnapM.Y + BreakPts[BreakI].Y / Length(BreakPts));
        end
        else
          FSnapM := PtF((FSnapA.X + FSnapB.X) / 2, (FSnapA.Y + FSnapB.Y) / 2);
        FSnapT := SNAP_RECOIL;
        FHoldOn := False;
        ResetTool;
        FLockOn := False;
        FNoLockUntilMoved := True;
        FScreenDirty := True;
        if FWasLine then
          FCmdMsg := 'Snapped off.'
        else if FTool in [ptPush, ptDrill, ptOffset] then
          FCmdMsg := 'Let go - nothing was moved.'
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
    { one repaint per tick at most, whatever asked for it - and the camera
      drawn once for whatever moved it since the last one }
    FlushView;
    if FScreenDirty then
    begin
      FScreenDirty := False;
      pbScreen.Invalidate;
    end;
  end;
end;

{ ======================================================================== }
{ the view cube                                                             }
{ ======================================================================== }

{ Top right of the drawing, where Revit puts its own.

  The reading and the VIEW button are up there too, but they are in the
  chrome above this - the drawing area starts below them, and its own top
  right corner is empty paper.  So the cube sits under the button that does
  the same job in words, which is where somebody looking for either will
  look. }
function TMainForm.CubeRect: TRect;
var
  Sz, M, L, T: Integer;
begin
  Sz := CubeSize(FUIScale);
  M := Round(14 * FUIScale);
  { the bottom corners leave room for the scale bar and the chip that sits
    along the foot of the drawing }
  if FCubeCorner in [0, 2] then L := M else L := pbScreen.Width - M - Sz;
  if FCubeCorner in [0, 1] then T := M
  else T := pbScreen.Height - Round(46 * FUIScale) - Sz;
  Result := Rect(L, T, L + Sz, T + Sz);
end;

{ The cube's patch of the drawing: its square, and a margin round it.

  Wider than the cube itself on purpose.  The cube is a hexagon inside a
  square, so aiming at its left edge puts the pointer over the square but off
  the shape - and everything the drawing draws at the cursor, the crosshair,
  the snap mark, the chip that says what the tool will do, was appearing on
  top of the cube exactly while somebody was trying to click it.  A widget
  has to own the space around it, not only the pixels it covers. }
function TMainForm.CubeZone(X, Y: Integer): Boolean;
var
  R: TRect;
  M: Integer;
begin
  Result := False;
  if (not FCubeOn) or (FMode <> mdPro) or (FD = nil) or (FD.View <> vkOrbit) then
    Exit;
  R := CubeRect;
  M := Round(10 * FUIScale);
  { the name of the hot target is written under it, so the zone reaches down
    far enough to cover that too }
  Result := (X >= R.Left - M) and (X <= R.Right + M) and
            (Y >= R.Top - M) and (Y <= R.Bottom + M + Round(16 * FUIScale));
end;

{ Is the pointer on the cube at all?  Asked by the things that only need to
  stand aside - the wheel, the cursor - rather than to act. }
function TMainForm.OverCube(X, Y: Integer): Boolean;
var
  R: TRect;
  T: TCubeTarget;
begin
  Result := False;
  if (not FCubeOn) or (FMode <> mdPro) or (FD = nil) or (FD.View <> vkOrbit) then
    Exit;
  if FCubeDrag then Exit(True);
  R := CubeRect;
  Result := CubeAt(Proj, (R.Left + R.Right) / 2, (R.Top + R.Bottom) / 2,
    (R.Right - R.Left) / 2 / 1.75, X, Y, T);
end;

procedure TMainForm.PaintViewCube(C: TCanvas);
var
  R: TRect;
  Half: Double;
  Labels: TCubeLabels;
  I, TW: Integer;
  Col: TPix;
begin
  if not FCubeOn then Exit;
  if FMode <> mdPro then Exit;
  { A cube is a picture of where you are standing in three dimensions.  The
    paper modes are not three dimensions - PLAN looks down and ISO is a fixed
    drawing convention - so there is nothing for it to say. }
  if (FD = nil) or (FD.View <> vkOrbit) then Exit;

  R := CubeRect;
  if FCubeSkin = nil then FCubeSkin := TArtSurface.Create(16, 16);
  FCubeSkin.SetSize(R.Right - R.Left, R.Bottom - R.Top);
  FCubeSkin.ClearTransparent;
  FCubeSkin.PreserveAlpha := True;

  { room for the cube to turn in without its corners leaving the surface:
    the long diagonal of a cube is root three }
  Half := (R.Right - R.Left) / 2 / 1.75;
  { the pointer's target on the cube, or - while an orbit is being snapped -
    the one it is about to click into }
  if FSnapHasHot then
    PaintCube(FCubeSkin, Proj, Half, Theme, True, FSnapHot.Dir)
  else
    PaintCube(FCubeSkin, Proj, Half, Theme, FCubeHasHot, FCubeHot.Dir);
  FCubeSkin.DrawTo(C, R.Left, R.Top);

  { the names, on the canvas because they want a font }
  Labels := CubeLabels(Proj, Half);
  for I := 0 to High(Labels) do
  begin
    Col := OnPix(MixPix(Theme.Panel, Pix(255, 255, 255), 0.30));
    UIFont(C, 8, True, Col);
    TW := C.TextWidth(Labels[I].Name);
    { a face seen nearly edge-on has no room for a word }
    if Labels[I].Facing < 0.26 then Continue;
    C.TextOut(R.Left + Round((R.Right - R.Left) / 2 + Labels[I].X - TW / 2),
      R.Top + Round((R.Bottom - R.Top) / 2 + Labels[I].Y - C.TextHeight('X') / 2),
      Labels[I].Name);
  end;

  { what is under the pointer, said in words under the cube }
  if FSnapHasHot and (FSnapHot.Name <> '') then
  begin
    C.Font.Color := PixToColor(Theme.Accent);
    TW := C.TextWidth(FSnapHot.Name);
    C.TextOut(R.Left + (R.Right - R.Left - TW) div 2,
      R.Bottom + Round(2 * FUIScale), FSnapHot.Name);
  end
  else if FCubeHasHot and (FCubeHot.Name <> '') then
  begin
    UIFont(C, 9, True, Theme.Accent);
    TW := C.TextWidth(FCubeHot.Name);
    C.TextOut(R.Left + ((R.Right - R.Left) - TW) div 2,
      R.Bottom + Round(2 * FUIScale), FCubeHot.Name);
  end;
end;

{ Which way north is, in a corner of the drawing, while the grid is on.
  Letters at the origin said it first, and only while the origin was on
  the paper - the owner draws out in the positive quarter, away from it
  (25 September: "the compass would have solidified our previews are
  wrong in the radiant build wizard").  North is the drawing's green axis,
  east its red, up its blue, each drawn the way the view shows it - flat
  in plan, turning with the camera in iso and orbit - in the axis's own
  color.  It keeps to a top corner the view cube is not in. }
procedure TMainForm.PaintCompass(C: TCanvas);
const
  TAGS: array[0..4] of string = ('E', 'W', 'N', 'S', 'U');
var
  R, M, Pad, CX, CY, K, TX, TY, OX, OY: Integer;
  Rt, Up, Dir: TP3;
  DX, DY, L: Double;
  Col: TPix;
begin
  if not FShowGrid or (FMode <> mdPro) or (FD = nil) then Exit;
  R := Round(20 * FUIScale);
  M := Round(14 * FUIScale);
  Pad := Round(12 * FUIScale);
  { top right; top left when the cube is showing there }
  if FCubeOn and (FD.View = vkOrbit) and (FCubeCorner = 1) then CX := M + Pad + R
  else CX := pbScreen.Width - M - Pad - R;
  CY := M + Pad + R;
  Rt := ViewRight(Proj);
  Up := ViewUp(Proj);
  C.Brush.Style := bsClear;
  C.Pen.Width := 1;
  C.Pen.Color := PixToColor(Theme.Grid);
  C.Ellipse(CX - R, CY - R, CX + R + 1, CY + R + 1);
  UIFont(C, 9, True, Pix(0, 0, 0));
  for K := 0 to High(TAGS) do
  begin
    case K of
      0: Dir := P3(1, 0, 0);
      1: Dir := P3(-1, 0, 0);
      2: Dir := P3(0, 1, 0);
      3: Dir := P3(0, -1, 0);
    else Dir := P3(0, 0, 1);
    end;
    DX := Dot3(Dir, Rt); DY := -Dot3(Dir, Up);
    L := Hypot(DX, DY);
    { pointing at the eye - up, in plan - there is nothing to draw }
    if L < 0.2 then Continue;
    Col := AxisPix(K div 2);
    C.Pen.Color := PixToColor(Col);
    if K mod 2 = 0 then C.Pen.Width := Max(2, Round(2 * FUIScale)) else C.Pen.Width := 1;
    C.Line(CX, CY, CX + Round(DX * R), CY + Round(DY * R));
    { the letter just past the point, ringed in black like the axes' }
    TX := CX + Round(DX / L * (R * L + Pad * 0.75)) - C.TextWidth(TAGS[K]) div 2;
    TY := CY + Round(DY / L * (R * L + Pad * 0.75)) - C.TextHeight(TAGS[K]) div 2;
    C.Font.Color := clBlack;
    for OX := -1 to 1 do
      for OY := -1 to 1 do
        if (OX <> 0) or (OY <> 0) then C.TextOut(TX + OX, TY + OY, TAGS[K]);
    C.Font.Color := PixToColor(Col);
    C.TextOut(TX, TY, TAGS[K]);
  end;
  C.Pen.Width := 1;
end;

{ The pointer, over the cube.  True when the cube took it, so the drawing
  underneath does not also act on it.

  Down starts either a click or a drag and does not yet know which; Up
  decides.  A press that travels is an orbit - the same as dragging the model
  - and one that does not is a move to whatever was under it. }
function TMainForm.CubeMouse(X, Y: Integer; Down, Up: Boolean): Boolean;
var
  R: TRect;
  Half, Az, El, NewAz, NewEl, FitZ, FitX, FitY, Near_: Double;
  T: TCubeTarget;
  Was: Boolean;
begin
  Result := False;
  if (not FCubeOn) or (FMode <> mdPro) or (FD = nil) or (FD.View <> vkOrbit) then
  begin
    FCubeHasHot := False;
    Exit;
  end;

  R := CubeRect;
  Half := (R.Right - R.Left) / 2 / 1.75;

  { a drag that started on the cube keeps it until the button comes up, even
    once the pointer has left - letting go of it mid-turn is the one thing
    that would make it feel broken }
  if FCubeDrag and not Down then
  begin
    Result := True;
    if Up then
    begin
      FCubeDrag := False;
      { A drag let go close to one of the twenty-six clicks into it - within
        eight degrees, which is near enough that it reads as "that one" and
        far enough that an in-between view can still be kept.  Ctrl clicks
        into the nearest from anywhere, the same as Ctrl on the orbit tool. }
      if FCubeMoved then
      begin
        T := CubeNearest(ViewDir(Proj), Near_);
        if (ssCtrl in GetKeyShiftState) or (Near_ >= Cos(DegToRad(8))) then
        begin
          Az := FD.Az;
          CubeAzEl(T.Dir, Az, El);
          FViewPreset := -1;
          GlideTo(Az, El);
          FCmdMsg := T.Name + '.';
        end;
        Exit;
      end;
      { it never traveled, so it was a click after all }
      if not FCubeMoved and
         CubeAt(Proj, (R.Left + R.Right) / 2, (R.Top + R.Bottom) / 2,
                Half, X, Y, T) then
      begin
        Az := FD.Az;
        CubeAzEl(T.Dir, Az, El);
        FViewPreset := -1;
        { With something picked, the move brings it to the middle and sizes
          it on the way round - one movement, not a turn and then a jump.
          With nothing picked there is nothing to center on, so it turns
          about what is already in front of you and leaves the framing
          alone: re-fitting the whole drawing every time somebody looks at
          it from another side would throw away the zoom they set. }
        if FCubeFitSel and (Length(FSel) > 0) and
           FitTarget(True, Az, El, FitZ, FitX, FitY) then
          GlideCamera(Az, El, FitZ, FitX, FitY)
        else
          GlideTo(Az, El);
        FCmdMsg := T.Name + '.';
      end;
      Exit;
    end;
    { A press only becomes a drag once it has actually traveled.

      It used to count a single pixel, and a hand never presses a button
      without moving one - so a click on a face was read as a drag, nudged
      the camera by a hair and flew nowhere.  That is why it flew sometimes
      and not others: it depended on how steady you were.  Five pixels is
      the same slop the double-click test here already uses. }
    if (Abs(X - FCubePressX) > 4) or (Abs(Y - FCubePressY) > 4) then
      FCubeMoved := True;
    if FCubeMoved and ((X <> FCubeDragX) or (Y <> FCubeDragY)) then
    begin
      FGlideT := 0;                 { the hand wins over any glide }
      { locals first - see the long note in pbScreenMouseMove about what -O3
        does with "Field := Field + (X - Ref) * K" }
      NewAz := FD.Az - (X - FCubeDragX) * 0.010;
      NewEl := FD.El + (Y - FCubeDragY) * 0.010;
      if NewEl < -1.45 then NewEl := -1.45;
      if NewEl > 1.45 then NewEl := 1.45;
      FD.Az := NewAz;
      FD.El := NewEl;
      FViewPreset := -1;
      HoldTurn;
      FCubeDragX := X;
      FCubeDragY := Y;
      FCameraMoving := True;
      FLastWheel := GetTickCount64;
      { The paper as well as the model.  The axes and the ground grid are
        ruled onto the paper layer, not drawn with the model, so leaving it
        out turned the drawing and left the red, green and blue lines lying
        exactly where they were - which is what a middle-drag orbit has
        always known to do and this did not. }
      RepaintPaper;
      RenderPro;
      RecomposeAll;
      Invalidate;
    end;
    Exit;
  end;

  Was := FCubeHasHot;
  FCubeHasHot := CubeAt(Proj, (R.Left + R.Right) / 2,
    (R.Top + R.Bottom) / 2, Half, X, Y, T);
  if FCubeHasHot then FCubeHot := T;
  if FCubeHasHot <> Was then FScreenDirty := True
  else if FCubeHasHot then FScreenDirty := True;

  if not FCubeHasHot then Exit;
  Result := True;
  if Down then
  begin
    FCubeDrag := True;
    FCubeMoved := False;
    FCubeDragX := X;
    FCubeDragY := Y;
    FCubePressX := X;
    FCubePressY := Y;
    { dragging the cube turns about the same point a click flies about, and
      the same point the orbit tool would turn about if you grabbed the
      middle of the thing you are looking at }
    FTurnPivot := TurnPivot;
    FTurnAnchor := ScreenOf(FTurnPivot);
    FTurnAnchored := not (IsNan(FTurnAnchor.X) or IsNan(FTurnAnchor.Y) or
                          IsInfinite(FTurnAnchor.X) or IsInfinite(FTurnAnchor.Y)) and
                     (Abs(FTurnAnchor.X) < 1E6) and (Abs(FTurnAnchor.Y) < 1E6);
  end;
end;

{ What a turn turns about.

  Revit's rule, which is the one to match: the middle of what is selected,
  and the middle of what you are looking at when nothing is.  Not the world
  origin - a building drawn half a mile from zero would swing out of the
  window, and even a drawing near zero pivots about a corner of itself rather
  than about the thing being looked at.

  MiddleOf already does exactly this: given nothing, it spans the whole
  drawing.  The export turns about the same point for the same reason. }
function TMainForm.TurnPivot: TP3;
begin
  if (FD = nil) or not FD.Doc.MiddleOf(FSel, Result) then Result := P3(0, 0, 0);
end;

{ Put the pivot back where it was on the screen, after the angles have moved.

  A TProjector turns about the world origin - there is no pivot in it - so
  this is how every turn in the program gets one: ask where the point is now
  and slide the view by the difference.  The guard is the orbit drag's: a
  point that was reasonable a moment ago can project anywhere once the camera
  has moved, and adding a few million to where the drawing is held poisons
  every rounding after it. }
procedure TMainForm.HoldTurn;
var
  OP: TPointF;
begin
  if not FTurnAnchored then Exit;
  OP := ScreenOf(FTurnPivot);
  if IsNan(OP.X) or IsNan(OP.Y) or IsInfinite(OP.X) or IsInfinite(OP.Y) then Exit;
  if (Abs(OP.X) > 1E6) or (Abs(OP.Y) > 1E6) then Exit;
  FD.ViewX := FD.ViewX + (FTurnAnchor.X - OP.X);
  FD.ViewY := FD.ViewY + (FTurnAnchor.Y - OP.Y);
end;

{ What a fit would come out as, without doing it.

  Pulled out of FitView so a move can be aimed at the framing it will end in
  rather than snapping into it on arrival.  Worked out at the angles the move
  is going TO, not the ones it is leaving - which for an orbit makes no
  difference to the zoom, because the bound used there is the diagonal of the
  box and a diagonal is the same from every direction, but it decides where
  the middle lands on the screen and that is the half that matters. }
function TMainForm.FitTarget(OnSelection: Boolean; AzT, ElT: Double;
  out NewZoom, NewOX, NewOY: Double): Boolean;
var
  Lo, Hi, Mid: TP3;
  V: TProjector;
  P: TPointF;
  BaseP, W, H, Z: Double;
begin
  NewZoom := FD.Zoom;
  NewOX := FD.ViewX;
  NewOY := FD.ViewY;
  if OnSelection and (Length(FSel) > 0) then
    Result := FD.Doc.SpanOf(FSel, Lo, Hi)
  else
    Result := FD.Doc.Bounds(Lo, Hi);
  if not Result then Exit;

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
  if Z < ZOOM_MIN then Z := ZOOM_MIN;
  if Z > ZOOM_MAX then Z := ZOOM_MAX;
  NewZoom := Z;

  { where the middle of it would land, at that zoom and those angles }
  Mid := P3((Lo.X + Hi.X) / 2, (Lo.Y + Hi.Y) / 2, (Lo.Z + Hi.Z) / 2);
  V.Kind := FD.View;
  V.Ppu := BaseP * Z;
  V.OX := 0;
  V.OY := 0;
  V.Az := AzT;
  V.El := ElT;
  P := Project(V, Mid);
  NewOX := FArt.Width / 2 - P.X;
  NewOY := FArt.Height / 2 - P.Y;
end;

{ A move that carries the framing as well as the angles: it turns, and slides,
  and zooms, all in the one go.

  This is what "bring it into the middle and fit it, with the animation" asks
  for.  A turn on its own holds a pivot still; this one drives the pan and the
  zoom to a place worked out in advance, so the thing being looked at arrives
  centerd and sized without a jump at either end. }
procedure TMainForm.GlideCamera(Az, El, Zoom, OX, OY: Double);
begin
  if FD = nil then Exit;
  GlideTo(Az, El);
  FGlideZ0 := FD.Zoom;
  FGlideZ1 := Zoom;
  FGlideOX0 := FD.ViewX;
  FGlideOX1 := OX;
  FGlideOY0 := FD.ViewY;
  FGlideOY1 := OY;
  { worth moving for the framing alone, even when the angles do not change -
    which is what the FIT button asks for }
  if (FGlideT = 0) and
     ((Abs(FGlideZ1 - FGlideZ0) > 1E-4 * Max(1, FGlideZ0)) or
      (Abs(FGlideOX1 - FGlideOX0) > 0.5) or (Abs(FGlideOY1 - FGlideOY0) > 0.5)) then
  begin
    FGlideD0 := FGlideD1;
    FGlideT := 1E-6;
    FGlideAt := GetTickCount64;
    FCameraMoving := True;
  end;
  FGlideFrame := FGlideT > 0;
end;

{ Start a camera move.  Instant when there is nowhere to go. }
{ The view the camera would click into, if it let go now.

  From a note, having watched the cube do it: "I think I want to have a modifier key
  for the orbit tool that makes it snap to... the closest preprogrammed views
  we have.... I think it will be nice to do an orbit around and get it to
  snap itself at least so one of its planes are squared to the view."

  The twenty-six the cube already offers are the set - six faces square on,
  twelve edges half way between two, eight corners.  Nothing new had to be
  invented for it: the cube has known those directions all along, CubeAzEl
  turns one into a camera, and GlideTo animates the way there, which is
  exactly what a click on the cube does.

  Only in the free 3D view: PLAN and ISO are fixed cameras already, and
  there is nothing for an orbit to snap in them. }
function TMainForm.OrbitSnapTarget(out T: TCubeTarget): Boolean;
var
  Near_: Double;
begin
  Result := False;
  if (FD = nil) or (FD.View <> vkOrbit) then Exit;
  T := CubeNearest(ViewDir(Proj), Near_);
  { Every direction has a nearest of the twenty-six, and no camera anywhere
    is far from all of them: swept over the whole sphere, the worst case is
    27.4 degrees - see TestOrbitSnapFindsTheNearestView, which measures it
    rather than taking my word for it.  So there is no such thing as being
    too far away to snap and no limit is imposed.  A limit would mean the key
    sometimes silently did nothing, which is worse than going somewhere you
    can watch it go. }
  Result := Near_ > -1;
end;

{ Let go, and click into it.  The animation is the point as much as the
  destination: What was asked for was the cube's glide by name - "let it do the
  animation like the cube does because it looks nice and you don't lose track
  of what you're looking at when it animates." }
procedure TMainForm.SnapOrbitToNearest;
var
  T: TCubeTarget;
  Az, El: Double;
begin
  if not OrbitSnapTarget(T) then Exit;
  Az := FD.Az;
  { straight up or straight down says nothing about which way round to be,
    so CubeAzEl keeps the turn already in force - which is why Az goes in }
  CubeAzEl(T.Dir, Az, El);
  GlideTo(Az, El);
  FCmdMsg := 'Snapped to ' + T.Name + '.';
  Trail('orbit snapped to ' + T.Name);
end;

{ Ctrl and an arrow: one step round the twenty-six, gliding the way a click
  on the cube does.  In the 3D view only - PLAN and ISO are fixed cameras,
  and Ctrl and an arrow there are left to do what the arrow alone does. }
procedure TMainForm.StepCubeView(Key: Word);
var
  T: TCubeTarget;
  Near_, Az, El: Double;
  Dir: TP3;
  Step: TCubeStep;
begin
  if (FD = nil) or (FD.View <> vkOrbit) then Exit;
  case Key of
    VK_LEFT:  Step := csLeft;
    VK_RIGHT: Step := csRight;
    VK_UP:    Step := csUp;
  else
    Step := csDown;
  end;
  { from where a glide already under way is going, so a quick second press
    carries on from the first rather than from somewhere in between }
  if FGlideT > 0 then
    Az := FGlideAz1
  else
    Az := FD.Az;
  if FGlideT > 0 then
    T := CubeNearest(P3(Cos(FGlideEl1) * Cos(FGlideAz1),
      Cos(FGlideEl1) * Sin(FGlideAz1), Sin(FGlideEl1)), Near_)
  else
    T := CubeNearest(ViewDir(Proj), Near_);
  Dir := CubeStep(T.Dir, Az, Step);
  if (Dir.X = 0) and (Dir.Y = 0) and (Step in [csLeft, csRight]) then
  begin
    { looking straight down or up: turn the drawing a side's worth }
    if Step = csRight then Az := Az + Pi / 4 else Az := Az - Pi / 4;
    El := FD.El;
    if FGlideT > 0 then El := FGlideEl1;
  end
  else
    CubeAzEl(Dir, Az, El);
  T := CubeNearest(Dir, Near_);
  FViewPreset := -1;
  GlideTo(Az, El);
  FCmdMsg := T.Name + '  - Ctrl and the arrows walk round the view cube.';
  Trail('cube step to ' + T.Name);
end;

procedure TMainForm.GlideTo(Az, El: Double);
var
  D: Double;

  { where the camera stands, as a direction, for a turn and a tilt }
  function DirOf(A, E: Double): TP3;
  begin
    Result := P3(Cos(E) * Cos(A), Cos(E) * Sin(A), Sin(E));
  end;

begin
  if FD = nil then Exit;
  FGlideAz0 := FD.Az;
  FGlideEl0 := FD.El;
  { the short way round: a quarter turn left is not three quarters right }
  D := Az - FD.Az;
  while D > Pi do D := D - 2 * Pi;
  while D < -Pi do D := D + 2 * Pi;
  FGlideAz1 := FD.Az + D;
  FGlideEl1 := El;
  if (Abs(D) < 1E-4) and (Abs(El - FD.El) < 1E-4) then
  begin
    FGlideT := 0;
    Exit;
  end;
  { The two places the camera stands, which is what actually gets
    interpolated - see StepGlide. }
  FGlideD0 := DirOf(FGlideAz0, FGlideEl0);
  FGlideD1 := DirOf(FGlideAz1, FGlideEl1);
  { what it turns about, and where that is on the screen right now }
  FTurnPivot := TurnPivot;
  FTurnAnchor := ScreenOf(FTurnPivot);
  FTurnAnchored := not (IsNan(FTurnAnchor.X) or IsNan(FTurnAnchor.Y) or
                        IsInfinite(FTurnAnchor.X) or IsInfinite(FTurnAnchor.Y)) and
                   (Abs(FTurnAnchor.X) < 1E6) and (Abs(FTurnAnchor.Y) < 1E6);
  FGlideT := 1E-6;
  FGlideAt := GetTickCount64;
  FGlideFrame := False;
  FCameraMoving := True;
end;

{ Dt is not used: this runs on the clock, not on how often the timer got
  round to it. }
procedure TMainForm.StepGlide(Dt: Double);
var
  K, NewAz, NewEl, Dot, Ang, S0, S1, Flat: Double;
  NewZ, NewOX, NewOY: Double;
  D: TP3;
begin
  if FGlideT <= 0 then Exit;
  if FD = nil then
  begin
    FGlideT := 0;
    Exit;
  end;
  FGlideT := (GetTickCount64 - FGlideAt) / (GLIDE_SECONDS * 1000);
  if FGlideT >= 1 then FGlideT := 1;
  { ease in and out, which is what makes it read as the model turning rather
    than the numbers changing }
  K := FGlideT * FGlideT * (3 - 2 * FGlideT);

  { The camera rolls round the model rather than having its two angles wound
    separately.

    Turn and tilt are convenient to store and a poor thing to interpolate:
    winding them at the same time swings the camera out along a path neither
    angle describes, and from a corner to the far corner it wallows sideways
    before coming back.  What it should do is roll - travel the short way
    round the sphere it sits on, at one rate, the way a cube tipped on a
    table goes over its edge.

    So the two ends are turned into the directions the camera stands in and
    the path between them is the great circle joining the two: the arc, at a
    constant rate, which is the shortest way from one to the other and the
    only one that reads as the model turning under your hand. }
  Dot := FGlideD0.X * FGlideD1.X + FGlideD0.Y * FGlideD1.Y +
         FGlideD0.Z * FGlideD1.Z;
  if Dot > 1 then Dot := 1;
  if Dot < -1 then Dot := -1;
  Ang := ArcCos(Dot);
  if Ang < 1E-6 then
    D := FGlideD1
  else
  begin
    S0 := Sin((1 - K) * Ang) / Sin(Ang);
    S1 := Sin(K * Ang) / Sin(Ang);
    D := P3(FGlideD0.X * S0 + FGlideD1.X * S1,
            FGlideD0.Y * S0 + FGlideD1.Y * S1,
            FGlideD0.Z * S0 + FGlideD1.Z * S1);
  end;

  { and back into the turn and tilt the drawing keeps }
  Flat := Sqrt(D.X * D.X + D.Y * D.Y);
  if Flat > 1E-9 then NewAz := ArcTan2(D.Y, D.X) else NewAz := FD.Az;
  NewEl := ArcTan2(D.Z, Flat);
  if NewEl < -1.45 then NewEl := -1.45;
  if NewEl > 1.45 then NewEl := 1.45;
  { The arc is the short way round the sphere, but the turn it works out to
    can be the long way round the circle - the same quarter turn read as
    three quarters.  Keep it near where it was and the drawing never spins
    the wrong way at the last moment. }
  while NewAz - FD.Az > Pi do NewAz := NewAz - 2 * Pi;
  while NewAz - FD.Az < -Pi do NewAz := NewAz + 2 * Pi;
  { land exactly where it was aimed, whatever the arithmetic did on the way }
  if FGlideT >= 1 then
  begin
    NewAz := FGlideAz1;
    NewEl := FGlideEl1;
  end;
  FD.Az := NewAz;
  FD.El := NewEl;
  if FGlideFrame then
  begin
    { The zoom goes round in proportion rather than in steps of its own size.
      Half way between 1x and 4x is 2x, not 2.5x - anything else races at one
      end and crawls at the other. }
    NewZ := FGlideZ0 * Exp(Ln(Max(1E-9, FGlideZ1 / Max(1E-9, FGlideZ0))) * K);
    NewOX := FGlideOX0 + (FGlideOX1 - FGlideOX0) * K;
    NewOY := FGlideOY0 + (FGlideOY1 - FGlideOY0) * K;
    if FGlideT >= 1 then
    begin
      NewZ := FGlideZ1;
      NewOX := FGlideOX1;
      NewOY := FGlideOY1;
    end;
    { through a local and clamped by hand - see the notes on FitView and
      ServiceMotion about this field and -O3 }
    if NewZ < ZOOM_MIN then NewZ := ZOOM_MIN;
    if NewZ > ZOOM_MAX then NewZ := ZOOM_MAX;
    FD.Zoom := NewZ;
    FD.ViewX := NewOX;
    FD.ViewY := NewOY;
  end
  else
    HoldTurn;
  if FGlideT >= 1 then
  begin
    FGlideT := 0;
    FCameraMoving := False;
    { Nothing to do on arrival: a move that re-frames carries the framing
      with it now, worked out before it sets off. }
    RepaintPaper;
  end
  else
    FCameraMoving := True;
  { the axes and the grid live on the paper, and they have to turn with
    everything else - see the note in CubeMouse }
  RepaintPaper;
  RenderPro;
  RecomposeAll;

  { And put it on the screen NOW, rather than asking for it to be put there.

    This is the whole difference between a move that animates and one that
    appears to teleport, and it cost an afternoon.  Invalidate only marks the
    canvas dirty; the painting happens when the message loop next gets a turn.
    The move runs off the sixteen millisecond tick and every step of it
    repaints the paper and re-renders the model - so the loop never got a
    turn between one tick and the next, no frame was ever drawn, and the
    first paint anybody saw was the one after the move had finished.

    The camera really was easing round the whole time.  Logging it said so,
    which is why it took so long to find: the instrument was watching the
    angles and the complaint was about the screen. }
  pbScreen.Invalidate;
  pbScreen.Update;
end;

{ ======================================================================== }
{ keyboard                                                                  }
{ ======================================================================== }

procedure TMainForm.FormKeyPress(Sender: TObject; var Key: char);
begin
  if FBusy then Exit;
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

  { One note picked and nothing typed: + and - are its text size.

    SketchUp resizes the words, not the box, and the box follows - which is
    the thing that was asked for as "resize the caption box".  A quarter
    bigger or smaller each press, between half and four times normal. }
  if (FInput = '') and (FStage = 0) and (Length(FSel) = 1) and
     (FD.Doc[FSel[0]].Kind = ekText) and (Key in ['+', '=', '-']) then
  begin
    PushUndo;
    if Key = '-' then
      FD.Doc.SetNoteSize(FSel[0], FD.Doc.NoteSize(FSel[0]) / 1.25)
    else
      FD.Doc.SetNoteSize(FSel[0], FD.Doc.NoteSize(FSel[0]) * 1.25);
    FCmdMsg := Format('Text at %d%% of normal.  + and - change it.',
      [Round(FD.Doc.NoteSize(FSel[0]) * 100)]);
    RenderPro;
    RecomposeAll;
    pbCmd.Invalidate;
    Key := #0;
    Exit;
  end;

  { Right after a copy, 3x or /3 makes an array of it: the x, the star and
    the slash go in with the digits, and Enter does the rest. }
  if FArray.Live and (Key in ['x', 'X', '*', '/']) and
     ((FInput = '') or (FInput[1] in ['0'..'9'])) and
     (Pos('x', FInput) = 0) and (Pos('*', FInput) = 0) and (Pos('/', FInput) = 0) then
  begin
    if Key = 'X' then Key := 'x';
    FInput := FInput + Key;
    pbCmd.Invalidate;
    Key := #0;
    Exit;
  end;
  if FArray.Live and (Key in ['0'..'9']) and (FInput <> '') and (FInput[1] in ['x', '*', '/']) then
  begin
    FInput := FInput + Key;
    pbCmd.Invalidate;
    Key := #0;
    Exit;
  end;

  { The sides of a circle or an arc: + and - step the count while the tool
    is in hand, and s goes into the input for SketchUp's 24s (or s24). }
  if (FTool in [ptCircle, ptArc]) and (FInput = '') and (Key in ['+', '=', '-']) then
  begin
    if FTool = ptCircle then
    begin
      if Key = '-' then FSidesCircle := Max(3, FSidesCircle - 1)
      else FSidesCircle := Min(360, FSidesCircle + 1);
      FCmdMsg := Format('%d sides.  + and - change it, or type 24s.', [FSidesCircle]);
    end
    else
    begin
      if Key = '-' then FSidesArc := Max(2, FSidesArc - 1)
      else FSidesArc := Min(360, FSidesArc + 1);
      FCmdMsg := Format('%d segments.  + and - change it, or type 12s.', [FSidesArc]);
    end;
    pbScreen.Invalidate;
    pbCmd.Invalidate;
    Key := #0;
    Exit;
  end;
  if (FTool in [ptCircle, ptArc]) and (Key in ['s', 'S']) and
     ((FInput = '') or (FInput[1] in ['0'..'9'])) and (Pos('s', FInput) = 0) then
  begin
    FInput := FInput + 's';
    pbCmd.Invalidate;
    Key := #0;
    Exit;
  end;

  { A leading '/' starts a typed command; after that every character is
    text, otherwise letters stay as single-key tool shortcuts. }
  if (Copy(FInput, 1, 1) = '/') and (Key >= ' ') then
  begin
    FInput := FInput + Key;
    { and the list narrows with it, the way an editor's does }
    SyncCmdList;
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
             '[', ']', '<', '>', ':'] then
  begin
    FInput := FInput + Key;
    FCmdMsg := '';
    { a slash with nothing before it is the start of a command, and that is
      where the list comes up }
    if FInput = '/' then SyncCmdList;
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
      { half of "type twelve and press up" is the up; without it a replay
        knows the length and not the way it went }
      Act('dir ' + IntToStr(FDirLock));
      if FDirLock < 0 then FCmdMsg := 'Free again.'
      else FCmdMsg := 'Locked to ' + AxisName(FDirLock) + '.';
    end
    else if FTool in [ptRotate, ptProtractor] then
    begin
      { the arrow names the axis the protractor turns about - its plane is
        the one square to that axis, in that axis's color }
      FRotAxisIx := ArrowAxis(K);
      if FRotAxisIx < 0 then
        FCmdMsg := 'Plane from whatever is under the cursor again.'
      else
      begin
        FRotAxis := AxisDir(FRotAxisIx);
        FCmdMsg := 'Turning about ' + AxisName(FRotAxisIx) + '.';
      end;
      pbScreen.Invalidate;
      pbCmd.Invalidate;
      Exit;
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
  { the source window's Pick ends on Esc, before anything else sees it }
  if FTextPick and (Key = VK_ESCAPE) then
  begin
    SourcePick(False);
    if SourceForm <> nil then SourceForm.PickEnded;
    Key := 0;
    Exit;
  end;
  if FBusy then Exit;
  Handled := True;

  if ssCtrl in Shift then
  begin
    case Key of
      VK_Z: DoUndo;
      VK_Y: DoRedo;
      VK_G: if FMode = mdPro then MakeGroup;     { SketchUp's Ctrl+G }
      VK_C: CopySelection(False);
      VK_X: CopySelection(True);
      VK_V: PasteClip;
      VK_S: if ssShift in Shift then DoSaveAs else DoSave;
      VK_O: DoOpen;
      VK_E: DoExport;
      VK_P: DoPrint;
      VK_N: if FMode = mdPro then NewDrawing(False);
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
    { Ctrl, while the tape is in hand, cycles what it leaves behind.  Same key
      SketchUp uses for the same choice.  Only while the tape is the tool, so
      Ctrl+Z and the rest are untouched everywhere else - and the mode is said
      out loud each time, because a mode you cannot see is a mode that will
      surprise you later. }
    if (Key = VK_CONTROL) and (FTool = ptMeasure) then
    begin
      FTapeDrop := (FTapeDrop + 1) mod 4;
      FCmdMsg := 'The tape leaves ' + TapeDropSays + '.';
      pbCmd.Invalidate;
      Key := 0;
      Exit;
    end;

    if Key = VK_MENU then
    begin
      { Mid-line, Alt is SketchUp's: it steps through what the cursor is
        allowed to infer.  Their help says "after the first click", and that
        is exactly when it is wanted - before it, there is no direction to
        offer and Alt is ours, holding the working plane so you can draw in
        mid air.  See TInferMode. }
      { The arc's tangent lock, theirs: "hover the edge you want it tangent
        to before the first click, and Alt locks the tangent inference".
        Ours knows which edge the first click landed on, so the hovering is
        done for you. }
      if (FTool = ptArc) and (FStage = 2) then
      begin
        if not FArcTanHas then
          FCmdMsg := 'Nothing to be tangent to - start an arc on an edge and ' +
            'Alt runs it out of that edge smoothly.'
        else
        begin
          FArcTanLock := not FArcTanLock;
          if FArcTanLock then
            FCmdMsg := 'Tangent to the edge it starts on, held.  Alt again to ' +
              'pull the bulge by hand.'
          else
            FCmdMsg := 'The bulge follows the cursor again.';
        end;
        FCur := ResolveSnapAt(FMouseSX, FMouseSY);
        InvalidateStatus;
        pbCmd.Invalidate;
        pbScreen.Invalidate;
        Key := 0;
        Exit;
      end;

      { The protractor's, theirs: "Alt frees the protractor from the plane
        it inferred".  Ours takes that plane from the face under the cursor
        when the vertex is clicked, so this is what stops it. }
      if (FTool in [ptRotate, ptProtractor]) and (FStage = 0) then
      begin
        FRotFree := not FRotFree;
        if FRotFree then
          FCmdMsg := 'Free of the face under the cursor: it turns flat unless ' +
            'an arrow picks a plane.  Alt again to follow faces.'
        else
          FCmdMsg := 'Following the face under the cursor again.';
        pbCmd.Invalidate;
        pbScreen.Invalidate;
        Key := 0;
        Exit;
      end;

      { The offset's, theirs: Alt keeps the overlaps a tight corner makes,
        which are otherwise taken out.  Ours takes them out by rebuilding the
        corner square - see OffsetLoop - so this says "leave it raw". }
      if (FTool = ptOffset) and (FStage >= 1) then
      begin
        FOffsetRaw := not FOffsetRaw;
        if FOffsetRaw then
          FCmdMsg := 'Overlaps kept: a corner taken in further than it is ' +
            'round comes back as it falls, loops and all.  Alt again to tidy them.'
        else
          FCmdMsg := 'Overlaps tidied, which is the usual way.';
        pbCmd.Invalidate;
        pbScreen.Invalidate;
        Key := 0;
        Exit;
      end;

      if (FTool = ptLine) and (FStage >= 1) then
      begin
        if FInferMode = High(TInferMode) then FInferMode := Low(TInferMode)
        else Inc(FInferMode);
        case FInferMode of
          imNoLinear: FCmdMsg := 'Inferences: the points only - no axis, ' +
            'nothing parallel.  Alt again for parallel and square.';
          imParPerp: FCmdMsg := 'Inferences: parallel and square to the last ' +
            'edge only.  Alt again for all of them.';
        else
          FCmdMsg := 'Inferences: all of them.  Alt steps through them.';
        end;
        { work the cursor out again where it stands: the mode has changed
          under it, and waiting for the next twitch of the mouse to show
          that would read as the key having done nothing }
        FCur := ResolveSnapAt(FMouseSX, FMouseSY);
        InvalidateStatus;
        pbCmd.Invalidate;
        pbScreen.Invalidate;
        Key := 0;
        Exit;
      end;
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
        { Up and down walk the command list while it is open - that is what
          they are for in every list anybody has ever used - and Tab
          completes to the row without running it. }
        VK_UP, VK_DOWN, VK_PRIOR, VK_NEXT:
          if FPopup = POP_CMDS then MoveCmdHighlight(Key) else Exit;
        VK_TAB:
          if (FPopup = POP_CMDS) and (FPopupHot >= 0) then
          begin
            FInput := '/' + CMD_LIST[FCmdOrder[FPopupHot]].Name;
            SyncCmdList;
            pbCmd.Invalidate;
          end
          else
            Exit;
        VK_RETURN:
          { Shift+Enter is another line of the note, Enter finishes it.  A
            note on a fab drawing is rarely one line - a size, a spec and a
            remark stacked up is the normal shape of one. }
          if (ssShift in Shift) and (FTool = ptText) and (FStage = 1) then
          begin
            FInput := FInput + #10;
            pbCmd.Invalidate;
          end
          { and Enter takes what the list is pointing at, unless what has
            been typed is already the whole of a command - /line and Enter
            runs /line, not whatever happens to be highlighted }
          else if (FPopup = POP_CMDS) and (FPopupHot >= 0) and
                  not ExactCmd(FInput) then
            TakeCmdHighlight
          else
          begin
            if FPopup = POP_CMDS then ClosePopup;
            CommandEnter;
          end;
        VK_ESCAPE:
          if FDimEdit >= 0 then
          begin
            FDimEdit := -1;
            FInput := '';
            FCmdMsg := 'Left as it was.';
            pbCmd.Invalidate;
            pbScreen.Invalidate;
          end
          { the list first, then what was typed, then the tool - one press
            per thing, the way Escape works everywhere else here }
          else if FPopup = POP_CMDS then
          begin
            ClosePopup;
            FInput := '';
            pbCmd.Invalidate;
          end
          else
            ResetTool;
        VK_BACK:
          begin
            if FInput <> '' then SetLength(FInput, Length(FInput) - 1);
            { rubbing letters out widens the list again, and rubbing the
              slash out puts it away }
            SyncCmdList;
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
        { the command list takes the up and down arrows while it is open -
          that is what they are for in every list anybody has ever used }
        if (FPopup = POP_CMDS) and (Key in [VK_UP, VK_DOWN, VK_PRIOR, VK_NEXT]) then
          MoveCmdHighlight(Key)
        { Ctrl turns the view instead, a step round the cube at a time -
          only in 3D, and only between shapes, so an arrow lock mid-line is
          never taken from under anybody }
        else if (ssCtrl in Shift) and (FMode = mdPro) and (FD.View = vkOrbit) and
           (FStage = 0) and (Key in [VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN]) then
          StepCubeView(Key)
        { before a shape is under way the arrows pick the plane; after that
          they lock a direction, which is only meaningful for a line }
        else if (FTool in [ptRect, ptCircle, ptArc]) or
           ((FTool = ptLine) and (FStage = 0)) then
          PlaneByArrow(Key)
        else
          Arrow(Key);
      { Enter takes what the list is pointing at, when it is open and what is
        typed is not already the whole of a command.  Typing /line and
        pressing Enter still runs /line and not whatever is highlighted. }
      VK_RETURN:
        if (FPopup = POP_CMDS) and (FPopupHot >= 0) and
           not ExactCmd(FInput) then TakeCmdHighlight
        else
        begin
          if FPopup = POP_CMDS then ClosePopup;
          CommandEnter;
        end;
      { and Tab completes without running, which is the other half of what a
        list like this is for }
      VK_TAB: if (FPopup = POP_CMDS) and (FPopupHot >= 0) then
              begin
                FInput := '/' + CMD_LIST[FCmdOrder[FPopupHot]].Name;
                SyncCmdList;
                pbCmd.Invalidate;
              end
              else
                SetTool(TProTool((Ord(FTool) + 1) mod (Ord(High(TProTool)) + 1)));
      { Space is SketchUp's arrow.  Mid-shape it still finishes what is being
        drawn, because that is the older habit here and losing it would smart. }
      VK_SPACE:
        if (FStage = 0) and (FInput = '') then SetTool(ptSelect)
        else CommandEnter;
      VK_ESCAPE:
        begin
          if FSliceEdit <> 0 then
          begin
            FSliceEdit := 0;
            FInput := '';
            FCmdMsg := 'Left as it was.';
            pbSlice.Invalidate;
          end
          else if FPopup <> POP_NONE then
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
          else if FD.Doc.Context <> 0 then
            CloseGroup
          else
            SetTool(ptSelect);
          FCmdMsg := '';
          pbCmd.Invalidate;
          pbScreen.Invalidate;
        end;
      VK_BACK:
        begin
          if FInput <> '' then SetLength(FInput, Length(FInput) - 1);
          { rubbing letters out widens the list again, and rubbing the slash
            out puts it away }
          SyncCmdList;
          pbCmd.Invalidate;
          pbScreen.Invalidate;
        end;
      VK_Q: SetTool(ptRotate);      // SketchUp's key for it; Space is select
      VK_L: SetTool(ptLine);
      VK_R: SetTool(ptRect);
      VK_A: SetTool(ptArc);
      VK_C: SetTool(ptCircle);
      VK_P: SetTool(ptPush);
      VK_B: SetTool(ptDrill);       // bore
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
      { no bare W into the toy any more.  It was the button's twin and it
        went off under the hand of somebody reaching for something else;
        /toy is the way in now, and it is in the command list. }
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
    { W still leaves, which is where it always went from in here }
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
  ThemeSourceWindow;
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
  dlgOpen.InitialDir := OpenDirNow;
  if not dlgOpen.Execute then Exit;
  FOpenDir := ExtractFileDir(dlgOpen.FileName);
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
    FLoading := True;
    FLoadSkipped := False;
    SplashSkipReset;
    OnProgress('Reading ' + ExtractFileName(FileName), 0);

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
          else if Key = 'SLICE' then
          begin
            CamT := TStringList.Create;
            try
              CamT.Delimiter := ' ';
              CamT.DelimitedText := Rest;
              if CamT.Count >= 2 then
              begin
                D.SliceLo := RdF(CamT[0]);
                D.SliceHi := RdF(CamT[1]);
                D.SliceOn := True;
              end;
            finally
              CamT.Free;
            end;
          end
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
                if CamZ < ZOOM_MIN then CamZ := ZOOM_MIN;
                if CamZ > ZOOM_MAX then CamZ := ZOOM_MAX;
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
        if FLoadSkipped then Break;
      end;
    end;

    if Length(FDrawings) = 0 then
    begin
      SetLength(FDrawings, 1);
      FDrawings[0] := TDrawing.Create('Sheet 1');
    end;

    { What was picked, hovered or marked belonged to the drawing that has
      just gone, and the numbers mean nothing in this one.  Changing sheets
      has always let go of them; opening a file did not - 21 September, a
      thing picked on a drawing of twelve hundred and then a file of a
      hundred opened over it: the pick pointed past the end of the new
      drawing, and the first thing to look at it was a range error. }
    LeaveSheet;
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
      if FLoadSkipped then Break;
      if Length(FDrawings) > 1 then
        OnProgress(Format('Working out the faces on sheet %d of %d', [I + 1, Length(FDrawings)]), -1)
      else
        OnProgress('Working out the faces', -1);
      D := FD;
      FD := FDrawings[I];
      { A file that carries faces is telling us which areas are filled, and
        that includes the ones somebody emptied on purpose.  Taking its areas
        as already seen means nothing counts as newly closed, so no face is
        invented over the top of what was saved - a window rubbed out before
        saving is still a window on the way back in.

        A file with no faces in it at all predates their being written down,
        and still gets them worked out, which is what this loop was for. }
      if AnyFace then SeedRegions else RebuildFlatFaces;
      FD := D;
    end;
    if FLoadSkipped then
    begin
      { the skip button: whatever came in goes, and the file is untouched }
      for I := High(FDrawings) downto 0 do
        FDrawings[I].Free;
      SetLength(FDrawings, 1);
      FDrawings[0] := TDrawing.Create('Sheet 1');
      FTabIdx := 0;
      FD := FDrawings[0];
      FDocPath := '';
      Trail('skipped loading ' + FileName);
    end;
    FLoading := False;
    EndBusy;
    ResetTool;
    Relayout;
    { Frame the drawing only when the file could not say where the camera
      was.  It used to fit every time, which read the camera out of the file
      with some care and then immediately overwrote the zoom and the pan with
      a fresh fit - so a drawing always opened framed rather than where it
      was left, and the next save wrote the fit back as though that had been
      the view all along.  Older files carry no CAMERA line and still get
      framed, which is the right thing for them. }
    if FD.CamKnown and CameraShowsSomething then
    begin
      { the drawing still has to be put on the paper - framing it was doing
        that as a side effect, and skipping the framing skipped the render }
      FCameraMoving := True;
      RepaintPaper;
      RenderPro;
      RecomposeAll;
      Invalidate;
    end
    else
    begin
      { another sheet is another drawing - nothing to keep your place in.
        And a saved camera that shows none of the drawing is not a place
        worth keeping either: a report of 20 September opened on a sheet
        handed over from the last version zoomed out to the smallest the
        program allows - "nothing was visible in this drawing until i
        switched the view" - and rebuilding, refacing and everything short
        of changing the view left it that way. }
      if FD.CamKnown then
        Trail('the saved camera showed none of the drawing - framed instead');
      FitView(False);
    end;
    LayoutTabs;
    RefreshChrome;
    if FLoadSkipped then
      FCmdMsg := 'Loading ' + ExtractFileName(FileName) +
        ' was skipped.  The file is untouched, and can be opened.'
    else
      FCmdMsg := 'Opened ' + ExtractFileName(FDocPath) +
        Format(' - %d sheet(s)', [Length(FDrawings)]);
    FHint := FDocPath;
    FSavedSeq := FEditSeq;
    for I := 0 to High(FDrawings) do FDrawings[I].Dirty := False;
    Result := True;
  finally
    L.Free;
  end;
end;

procedure TMainForm.DoSaveAs;
begin
  dlgSave.Filter := 'Heckers Sketch drawing|*.hsk';
  dlgSave.DefaultExt := '.hsk';
  dlgSave.InitialDir := SaveDirNow;
  if FDocPath <> '' then
    dlgSave.FileName := FDocPath
  else
    dlgSave.FileName := IncludeTrailingPathDelimiter(dlgSave.InitialDir) +
      'drawing.hsk';
  if not dlgSave.Execute then Exit;
  FDocPath := dlgSave.FileName;
  FSaveDir := ExtractFileDir(FDocPath);
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
      FSavedSeq := FEditSeq;
      { a save writes the whole file, so every sheet in it is clean now -
        not only the one that happens to be in front }
      for I := 0 to High(FDrawings) do FDrawings[I].Dirty := False;
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

{ A color that is not one of the twelve.

  The palette is the twelve that get used, and it stays twelve - a wall of
  swatches is a worse list, not a better one.  This is the way past it when
  somebody wants a particular color, and it is the platform's own picker
  because that is the one with the eyedropper and the recent colors in it. }
procedure TMainForm.PickAnyColor;
var
  C: TColor;
begin
  if not AskColor(FInkColor, C) then Exit;
  SetInk(C, False);
  FCmdMsg := 'Pen color set.';
end;

{ The platform's own color picker, started on Was. }
function TMainForm.AskColor(Was: TColor; out C: TColor): Boolean;
var
  D: TColorDialog;
begin
  C := Was;
  D := TColorDialog.Create(nil);
  try
    D.Color := Was;
    Result := D.Execute;
    if Result then C := D.Color;
  finally
    D.Free;
  end;
end;

{ The manual, in its own window.

  It used to hand the copy beside the program to the browser, or the
  website when there was none.  Now the pages are shown here - see
  uHelpView - and fetched from the release when they are missing or
  belong to another version, so a copy carried on a stick has its manual
  wherever it goes, once it has been online once. }
procedure TMainForm.OpenManual;
begin
  uDlgSkin.UseTheme(Themes[FThemeIdx]);
  OpenHelpWindow('');
  FCmdMsg := 'Opened the manual.';
end;

{ Keep the manual beside the program in step with the program.

  Asked once, a few seconds after start, alongside the update check: when
  the pages are missing or came from a different release - which is exactly
  the state right after an update - the right ones are fetched in the
  background.  Nothing is shown unless the help window is open to show it.

  The same switch as the update check governs it (/update never turns both
  off), --offline stops it, and a failure is not retried for six hours, so a
  machine with no internet does not try on every start. }
procedure TMainForm.KeepHelpCurrent;
var
  Ini: TIniFile;
  Last: string;
begin
  if NetOffline then Exit;
  if not HelpIsStale(CurrentVersion) then Exit;
  Ini := TIniFile.Create(ConfigFile);
  try
    if not Ini.ReadBool('update', 'check', True) then Exit;
    Last := Ini.ReadString('help', 'tried', '');
    if (Last <> '') and (Now - StrToFloatDef(Last, 0) < 0.25) then Exit;
    Ini.WriteString('help', 'tried', FloatToStr(Now));
  finally
    Ini.Free;
  end;
  Trail('help pages: fetching for ' + CurrentVersion);
  StartHelpFetch(CurrentVersion, @HelpFetchProgress, @HelpFetchDone);
end;

procedure TMainForm.HelpFetchProgress(BytesReceived, TotalBytes: Int64);
begin
  if HelpForm <> nil then HelpForm.FetchProgress(BytesReceived, TotalBytes);
end;

procedure TMainForm.HelpFetchDone(Sender: TObject);
var
  F: THelpFetch;
  Ini: TIniFile;
begin
  F := Sender as THelpFetch;
  if F.OK then
  begin
    Trail('help pages: installed from ' + F.GotTag);
    { a success clears the six-hour wait, so the next update's pages are
      fetched as soon as that update lands }
    Ini := TIniFile.Create(ConfigFile);
    try
      Ini.DeleteKey('help', 'tried');
    finally
      Ini.Free;
    end;
  end
  else
    Trail('help pages: not fetched - ' + F.Err);
  if HelpForm <> nil then HelpForm.FetchDone(Sender);
end;

{ Every edge where a solid is not closed, drawn on the model.

  The export can already tell somebody their STL is not a closed solid,
  which is the half of the answer that does not help - a slicer said as
  much.  Where is the half that does.  TWorkDoc.OpenEdges does the work,
  with the same T-junction resolution GroupClosed uses so a seam merely
  divided unevenly is not reported as a hole.

  Whatever is selected is what gets checked, so a drawing full of fittings
  can be asked about one of them; with nothing selected it checks every
  solid there is. }
procedure TMainForm.ShowOpenEdges;
var
  I, J, G, NGrp, NBad: Integer;
  Grps: array of Integer;
  Edges: TP3Array;

  procedure Want(AG: Integer);
  var
    K: Integer;
  begin
    if AG = 0 then Exit;
    for K := 0 to NGrp - 1 do
      if Grps[K] = AG then Exit;
    if NGrp >= Length(Grps) then SetLength(Grps, Max(8, NGrp * 2));
    Grps[NGrp] := AG;
    Inc(NGrp);
  end;

begin
  SetLength(FOpenEdges, 0);
  FOpenSeq := FEditSeq;
  NGrp := 0;
  SetLength(Grps, 8);

  if Length(FSel) > 0 then
    for I := 0 to High(FSel) do
      if (FSel[I] >= 0) and (FSel[I] < FD.Doc.Live) then
        Want(FD.Doc[FSel[I]].Grp);
  if NGrp = 0 then
    for I := 0 to FD.Doc.Live - 1 do
      if (FD.Doc[I].Kind = ekFace) and FD.Doc[I].Solid then
        Want(FD.Doc[I].Grp);

  if NGrp = 0 then
  begin
    FCmdMsg := 'Nothing here is a solid - there is nothing to be open.';
    pbCmd.Invalidate;
    Exit;
  end;

  NBad := 0;
  for I := 0 to NGrp - 1 do
  begin
    G := Grps[I];
    if FD.Doc.GroupClosed(G) then Continue;
    Inc(NBad);
    Edges := FD.Doc.OpenEdges(G);
    for J := 0 to High(Edges) do
    begin
      SetLength(FOpenEdges, Length(FOpenEdges) + 1);
      FOpenEdges[High(FOpenEdges)] := Edges[J];
    end;
  end;

  if NBad = 0 then
    FCmdMsg := Format('%s closed - a slicer will take %s.',
      [specialize IfThen<string>(NGrp = 1, 'That solid is',
        Format('All %d solids are', [NGrp])),
       specialize IfThen<string>(NGrp = 1, 'it', 'them')])
  else if Length(FOpenEdges) = 0 then
    FCmdMsg := Format('%d of %d solids are open, but the edges could not be ' +
      'pinned down - send this drawing in.', [NBad, NGrp])
  else
  begin
    if NGrp = 1 then
      FCmdMsg := 'This solid is open.'
    else if NBad = 1 then
      FCmdMsg := Format('One of the %d solids is open.', [NGrp])
    else
      FCmdMsg := Format('%d of the %d solids are open.', [NBad, NGrp]);
    FCmdMsg := FCmdMsg + Format('  %d edges are drawn in red where nothing ' +
      'meets them - type /holes again once you have mended them.',
      [Length(FOpenEdges) div 2]);
  end;
  pbCmd.Invalidate;
  Invalidate;
end;

{ Where a file of this kind went last time.  Nothing remembered, or the
  folder has gone: the program's own exports folder, beside the executable.
  If even that cannot be made - a copy run off a read-only stick - the answer
  is empty and the dialog offers a bare file name, which lands wherever the
  file dialog thinks best. }
function TMainForm.ExportDirFor(const Ext: string): string;
begin
  Result := FExportDirs.Values[Ext];
  if (Result <> '') and DirectoryExists(Result) then Exit;
  Result := ExportsDir;
end;

procedure TMainForm.KeepExportDir(const Ext, Dir: string);
begin
  if (Ext = '') or (Dir = '') then Exit;
  FExportDirs.Values[Ext] := Dir;
end;

{ The same for drawings, which are all one kind. }
function TMainForm.SaveDirNow: string;
begin
  Result := FSaveDir;
  if (Result <> '') and DirectoryExists(Result) then Exit;
  Result := DrawingsDir;
  if Result = '' then Result := AppDataDir;
end;

{ And where to go looking.  Wherever a drawing was last opened from, and
  failing that the program's own folder - which is where the examples and the
  drawings folders are, so both are one click away. }
function TMainForm.OpenDirNow: string;
begin
  Result := FOpenDir;
  if (Result <> '') and DirectoryExists(Result) then Exit;
  Result := AppDataDir;
end;

procedure TMainForm.DoExport;
var
  Msg, Base: string;
  ExpPivot: TP3;
  Holes: Boolean;
begin
  { The toy has no vectors and no model - what it has is a picture of a
    screen, so that is what it exports.  A room full of settings for it would
    be a room full of settings about nothing. }
  if FMode <> mdPro then
  begin
    dlgSave.Filter := 'PNG image|*.png';
    dlgSave.DefaultExt := '.png';
    dlgSave.InitialDir := ExportDirFor('.png');
    dlgSave.FileName := IncludeTrailingPathDelimiter(dlgSave.InitialDir) +
      'heckers-sketch-' + FormatDateTime('yyyymmdd-hhnnss', Now) + '.png';
    if not dlgSave.Execute then Exit;
    try
      ForceDirectories(ExtractFileDir(dlgSave.FileName));
      FArt.SaveToPNG(ChangeFileExt(dlgSave.FileName, '.png'));
      KeepExportDir('.png', ExtractFileDir(dlgSave.FileName));
      FCmdMsg := 'Exported ' + ExtractFileName(dlgSave.FileName);
    except
      on E: Exception do
        MessageDlg('Could not export', E.Message, mtError, [mbOK], 0);
    end;
    Invalidate;
    Exit;
  end;

  { what the export turns about: the middle of what is selected, or of the
    whole drawing when nothing is - because that is what somebody was looking
    at when they pressed the button }
  if not FD.Doc.MiddleOf(FSel, ExpPivot) then ExpPivot := P3(0, 0, 0);
  { a name only - which folder it belongs in is a question per format, and
    the dialog asks }
  Base := 'heckers-sketch-' + FormatDateTime('yyyymmdd-hhnnss', Now);
  Msg := '';
  Holes := False;
  if RunExport(FD.Doc, Proj, FD.Units, FDimFont, AnnotColor, FEdgeW,
       FArt.Width, FArt.Height, Base, Themes[FThemeIdx], ExpPivot,
       @ReportFromDialog, @ExportDirFor, @KeepExportDir, Msg, Holes, FD.ScaleIdx) then
  begin
    FHint := Msg;
    FCmdMsg := Msg;
    { Told your STL is not closed, the next thing you want is where.  The
      dialog has gone by the time the message is read, so there is nowhere
      to put a button - the marks are simply already on the drawing when it
      closes, and they go the moment anything is changed. }
    if Holes then
    begin
      ShowOpenEdges;
      FCmdMsg := Msg;
    end;
  end
  else if Msg <> '' then
    FCmdMsg := Msg;
  Invalidate;
end;

{ Full size, across as many sheets as it takes.

  What a shop does with a flat pattern is print it 1:1, tape the sheets
  together, lay the paper on the metal and scribe round it.  That is the
  whole reason the unfolder exists, and until now the only way out of here
  was a DXF for somebody else's machine.

  The page is re-rendered from the geometry for every tile, at the printer's
  own resolution, so nothing is scaled up from a picture and a line stays a
  line at any size.

  How the sheets go together: each tile prints a whole page of drawing, but
  the next tile starts one LAP short of the page edge, so the last LAP inches
  down the right side and along the bottom of every sheet are a repeat of
  what is on the next one.  Trim each sheet on the marked line and butt the
  next against it.  The sheet label sits inside that strip on purpose - it is
  the part that gets cut off. }
procedure TMainForm.DoPrintFull(const PngDir: string);
const
  LAP_IN = 0.5;        // inches of overlap, and the width of the trim strip
  MARGIN_IN = 0.25;    // white left round the drawing before it is tiled
  MAX_SHEETS = 120;    // past this it is a mistake, not a plan
var
  Sheet: TArtSurface;
  V: TProjector;
  Full: TDrawScale;
  Lo, Hi: TP3;
  I, Col, Row, Cols, Rows, SW, SH, PitchW, PitchH, N: Integer;
  BX0, BY0, BX1, BY1, MinX, MinY, MaxX, MaxY: Double;
  PageWIn, PageHIn: Double;
  Any: Boolean;
  Msg: string;
begin
  if FMode <> mdPro then
  begin
    FCmdMsg := 'Full size printing is a PRO thing.';
    Exit;
  end;
  if FD.Doc.Live = 0 then
  begin
    FCmdMsg := 'Nothing on this sheet to print.';
    Exit;
  end;

  { 1:1.  Paper is paper inches per foot, so twelve of them is full size;
    metric measures paper meters per meter, so one is. }
  if FD.Units = usImperial then
  begin
    Full.Name := 'full size';
    Full.Paper := 12;
  end
  else
  begin
    Full.Name := '1:1';
    Full.Paper := 1;
  end;

  { Where the drawing lands on an unshifted page, in print pixels.  Measured
    through the view that is on screen: full size means something exact in
    PLAN, and in a 3D view it means the picture at full size, foreshortening
    and all - which is said out loud below before anything is printed. }
  V.Kind := FD.View;
  V.Ppu := PixelsPerUnit(FD.Units, Full, PRINT_DPI);
  V.OX := 0;
  V.OY := 0;
  V.Az := FD.Az;
  V.El := FD.El;

  Any := False;
  MinX := 0; MinY := 0; MaxX := 0; MaxY := 0;
  for I := 0 to FD.Doc.Live - 1 do
  begin
    FD.Doc.ScreenBounds(V, I, BX0, BY0, BX1, BY1);
    if BX1 < BX0 then Continue;
    if not Any then
    begin
      MinX := BX0; MinY := BY0; MaxX := BX1; MaxY := BY1;
      Any := True;
    end
    else
    begin
      MinX := Min(MinX, BX0); MinY := Min(MinY, BY0);
      MaxX := Max(MaxX, BX1); MaxY := Max(MaxY, BY1);
    end;
  end;
  if not Any then
  begin
    { nothing has a screen size - fall back to the model box }
    if not FD.Doc.Bounds(Lo, Hi) then Exit;
    MinX := 0; MinY := 0;
    MaxX := (Hi.X - Lo.X) * V.Ppu;
    MaxY := (Hi.Y - Lo.Y) * V.Ppu;
  end;
  MinX := MinX - MARGIN_IN * PRINT_DPI;
  MinY := MinY - MARGIN_IN * PRINT_DPI;
  MaxX := MaxX + MARGIN_IN * PRINT_DPI;
  MaxY := MaxY + MARGIN_IN * PRINT_DPI;

  { Straight to files, the dialog is not wanted - and neither is a printer,
    so a page that nobody has a queue for still comes out at letter size.
    Tiles as pictures are what a print shop asks for, and they are also how
    this gets looked at without putting paper through anything. }
  if PngDir = '' then
  begin
    if not dlgPrint.Execute then Exit;
    if (Printer.XDPI <= 0) or (Printer.YDPI <= 0) then
    begin
      FCmdMsg := 'The printer did not say what resolution it is.';
      Exit;
    end;
  end;

  if (Printer.XDPI > 0) and (Printer.YDPI > 0) then
  begin
    PageWIn := Printer.PageWidth / Printer.XDPI;
    PageHIn := Printer.PageHeight / Printer.YDPI;
  end
  else
  begin
    PageWIn := 8.5;
    PageHIn := 11;
  end;
  SW := Max(64, Round(PageWIn * PRINT_DPI));
  SH := Max(64, Round(PageHIn * PRINT_DPI));
  PitchW := Max(1, SW - Round(LAP_IN * PRINT_DPI));
  PitchH := Max(1, SH - Round(LAP_IN * PRINT_DPI));

  Cols := Max(1, Ceil((MaxX - MinX) / PitchW));
  Rows := Max(1, Ceil((MaxY - MinY) / PitchH));
  N := Cols * Rows;

  Msg := Format('%s, %d across by %d down = %d sheets of %.1f x %.1f in.',
    [Full.Name, Cols, Rows, N, PageWIn, PageHIn]);
  if FD.View <> vkPlan then
    Msg := Msg + LineEnding + LineEnding +
      'This is the ' + IfThen(FD.View = vkIso, 'ISO', '3D') +
      ' view, so what comes out is the picture at full size, not the part.' +
      LineEnding + 'PLAN is the one to print a pattern from.';
  if (N > MAX_SHEETS) and (PngDir <> '') then
  begin
    FCmdMsg := Format('%d tiles is past the %d limit.', [N, MAX_SHEETS]);
    Exit;
  end;
  if N > MAX_SHEETS then
  begin
    MessageDlg('Too many sheets',
      Msg + LineEnding + LineEnding +
      Format('That is past the %d sheet limit.  Print it at a scale, or ' +
        'print one piece at a time.', [MAX_SHEETS]), mtWarning, [mbOK], 0);
    Exit;
  end;
  if (PngDir = '') and (MessageDlg('Print full size?',
       Msg + LineEnding + LineEnding +
       Format('Every sheet is trimmed on the marked line - the last %.1f in ' +
         'down the right and along the bottom is a repeat of the next ' +
         'sheet.  The sheet number is printed inside that strip.',
         [LAP_IN]),
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then Exit;

  try
    if PngDir = '' then Printer.BeginDoc;
    try
      Sheet := TArtSurface.Create(SW, SH);
      try
        for Row := 0 to Rows - 1 do
          for Col := 0 to Cols - 1 do
          begin
            if (PngDir = '') and ((Row > 0) or (Col > 0)) then Printer.NewPage;
            Sheet.Clear(Pix(255, 255, 255));
            V.OX := -MinX - Col * PitchW;
            V.OY := -MinY - Row * PitchH;
            FD.Doc.Render(Sheet, V, FD.Units, FDimFont, Pix(20, 20, 20), FEdgeW);
            if PngDir <> '' then
              Sheet.SaveToPNG(IncludeTrailingPathDelimiter(PngDir) +
                Format('tile-r%dc%d.png', [Row + 1, Col + 1]))
            else
            begin
              Printer.Canvas.StretchDraw(
                Rect(0, 0, Printer.PageWidth, Printer.PageHeight), Sheet.AsBitmap);
              PrintTileMarks(Col, Row, Cols, Rows, PitchW, PitchH, SW, SH,
                             Full.Name);
            end;
          end;
      finally
        Sheet.Free;
      end;
    finally
      if PngDir = '' then Printer.EndDoc;
    end;
    if PngDir <> '' then
      FCmdMsg := Format('Wrote %d tiles at %s into %s', [N, Full.Name, PngDir])
    else
      FCmdMsg := Format('Sent %d sheets at %s.', [N, Full.Name]);
    FHint := FCmdMsg;
  except
    on E: Exception do
      if PngDir <> '' then FCmdMsg := 'Could not write the tiles: ' + E.Message
      else MessageDlg('Could not print', E.Message, mtError, [mbOK], 0);
  end;
  Invalidate;
end;

{ The trim line and the sheet number, drawn straight onto the page rather
  than into the picture - they belong to the paper, not to the drawing, and
  at print resolution a hairline drawn here is a hairline. }
procedure TMainForm.PrintTileMarks(Col, Row, Cols, Rows, PitchW, PitchH,
  SW, SH: Integer; const ScaleName: string);
var
  PX, PY: Integer;
  S: string;

  { print pixels across to printer pixels across }
  function AtX(V: Integer): Integer;
  begin
    Result := Round(V * (Printer.PageWidth / SW));
  end;

  function AtY(V: Integer): Integer;
  begin
    Result := Round(V * (Printer.PageHeight / SH));
  end;

begin
  Printer.Canvas.Pen.Color := clSilver;
  Printer.Canvas.Pen.Width := Max(1, Printer.XDPI div 300);
  Printer.Canvas.Brush.Style := bsClear;

  PX := AtX(PitchW);
  PY := AtY(PitchH);
  { a sheet with one to its right is trimmed down the line; the last column
    has nothing coming after it and is left whole }
  if Col < Cols - 1 then
  begin
    Printer.Canvas.Line(PX, 0, PX, Printer.PageHeight);
    Printer.Canvas.TextOut(PX + AtX(8), AtY(8), 'trim');
  end;
  if Row < Rows - 1 then
  begin
    Printer.Canvas.Line(0, PY, Printer.PageWidth, PY);
    Printer.Canvas.TextOut(AtX(8), PY + AtY(8), 'trim');
  end;

  Printer.Canvas.Font.Color := clGray;
  Printer.Canvas.Font.Height := -Round(Printer.YDPI / 8);   { about 9 point }
  S := Format('%s  -  sheet %d of %d   (row %d, column %d)   %s',
    [FD.Name, Row * Cols + Col + 1, Cols * Rows, Row + 1, Col + 1, ScaleName]);
  { inside the trim strip wherever there is one, so it is cut away with it }
  Printer.Canvas.TextOut(AtX(12),
    Printer.PageHeight - Round(Printer.YDPI / 5), S);
end;

{ In pro mode the page is re-rendered from the geometry at the printer's own
  resolution, so 1/4" = 1'-0" really does come out as a quarter inch on the
  paper.  Toy mode just fits the picture to the page. }
{ All: every sheet of the drawing, a page each, rather than the one on
  screen.  A drawing is one document with tabs across the top and printing
  only the tab you happen to be looking at is the wrong default for a set of
  shop drawings - but it is also the wrong thing to do without being asked,
  so it is /print all. }
procedure TMainForm.DoPrint;
begin
  DoPrintSheets(False);
end;

procedure TMainForm.DoPrintSheets(All: Boolean);
var
  Sheet: TArtSurface;
  V: TProjector;
  Lo, Hi, Mid: TP3;
  PageWIn, PageHIn: Double;
  SW, SH: Integer;
  P: TPointF;
  Scale: Double;
  R: TRect;
  Was, Page, NPages: Integer;
begin
  if not dlgPrint.Execute then Exit;
  Was := FTabIdx;
  if All then NPages := Length(FDrawings) else NPages := 1;
  try
    Printer.BeginDoc;
    try
      for Page := 0 to NPages - 1 do
      begin
      if All then
      begin
        { the renderer reads the current sheet, its scale and its units off
          FD, so the sheet being printed becomes the current one for as long
          as it takes to draw it }
        if Page > 0 then Printer.NewPage;
        FTabIdx := Page;
        FD := FDrawings[Page];
      end;
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
        if All then
          FCmdMsg := Format('Printed %d sheets at %s%s.',
            [NPages, CurScale.Name,
             IfThen(FD.Units = usImperial, ' = 1''-0"', '')])
        else
          FCmdMsg := 'Printed at ' + CurScale.Name +
            IfThen(FD.Units = usImperial, ' = 1''-0"', '') +
            '.  /print all does every sheet; /print full lays it out 1:1 ' +
            'across pages.';
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
      end;
    finally
      Printer.EndDoc;
    end;
    FHint := 'Sent to the printer.';
  except
    on E: Exception do
      MessageDlg('Could not print', E.Message, mtError, [mbOK], 0);
  end;
  { back to the sheet somebody was looking at }
  FTabIdx := EnsureRange(Was, 0, High(FDrawings));
  FD := FDrawings[FTabIdx];
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
    { The slice, when there is one.  Left out entirely when there is not, so
      a drawing that never used it reads exactly as it did before. }
    if FDrawings[I].SliceOn then
      L.Add(StringReplace(Format('SLICE %.6f %.6f',
        [FDrawings[I].SliceLo, FDrawings[I].SliceHi]),
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
{ Long work reports here.  While the splash screen is up it goes there,
  with the skip button; afterwards it is the command bar, painted by letting
  the messages through - which is why every input handler checks FBusy.
  False back means stop: the skip was pressed. }
function TMainForm.OnProgress(const What: string; Frac: Double): Boolean;
var
  T: QWord;
begin
  Result := True;
  if SplashUp then
  begin
    SplashStatus(What, Frac, FLoading);
    if SplashSkipAsked then
    begin
      FLoadSkipped := True;
      Result := False;
    end;
    Exit;
  end;
  T := GetTickCount64;
  { A paint of the whole window is not free - a hundred milliseconds and
    more with a big drawing on it - and the loop that reports here calls
    every few dozen regions.  Fifteen thousand regions once cost thirty
    seconds of painting the bar.  So: a quarter of a second between paints,
    and longer when the last one was dear. }
  if FBusy and (T - FBusyAt < Max(250, 4 * FBusyPaintMs)) then Exit;
  FBusy := True;
  FBusyAt := T;
  FBusyMsg := What;
  FBusyFrac := Frac;
  { Invalidate and ProcessMessages were not enough: GTK3 paints on its frame
    clock, which a busy main thread never reaches, so the bar never showed.
    Repaint on the window the bar sits in forces the paint through
    (gdk_window_process_updates), and the messages are let through for the
    rest - which is why every input handler checks FBusy. }
  Application.ProcessMessages;
  pbCmd.Invalidate;
  if pbCmd.Parent <> nil then pbCmd.Parent.Repaint;
  Application.ProcessMessages;
  FBusyPaintMs := GetTickCount64 - T;
  FBusyAt := GetTickCount64;
end;

{ what the start-up screen says when the loading is over }
function TMainForm.LoadedWords: string;
var
  I, N: Integer;
begin
  if FLoadSkipped then Exit('Skipped that drawing - starting with a clean sheet.');
  N := 0;
  for I := 0 to High(FDrawings) do N := N + FDrawings[I].Doc.Live;
  if N = 0 then Exit('Ready.');
  if Length(FDrawings) = 1 then
    Result := Format('Ready.  %d things on one sheet.', [N])
  else
    Result := Format('Ready.  %d things on %d sheets.', [N, Length(FDrawings)]);
end;

procedure TMainForm.EndBusy;
begin
  if not FBusy then Exit;
  FBusy := False;
  pbCmd.Invalidate;
end;

{ Throw the safety net away.

  The draft is written continuously so that pulling the plug out loses
  nothing, which is right.  But it is a net under work in progress, not a
  record of what somebody wants back - so a deliberate "I am done with this
  drawing" has to say so to the draft as well, or the next launch hands back
  the very thing that was put down. }
procedure TMainForm.DropDraft;
begin
  try
    if FileExists(DraftFile) then DeleteFile(DraftFile);
  except
    on E: Exception do ;
  end;
  FDraftSeq := FEditSeq;
end;

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
function TMainForm.RestoreDraft: Boolean;
var
  L: TStringList;
  Was, Aside: string;
  Ini: TIniFile;
begin
  Result := False;
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
  if FLoadSkipped then
  begin
    { Skipped on the start-up screen.  Left where it is, it would be back
      next time and, worse, written over by the first new line drawn; so it
      is kept beside the settings under a name that can be opened. }
    Aside := ChangeFileExt(DraftFile, '') + '-skipped.hsk';
    if FileExists(Aside) then DeleteFile(Aside);
    RenameFile(DraftFile, Aside);
    FCmdMsg := 'Skipped loading the last drawing.  It is kept beside the ' +
      'settings as ' + ExtractFileName(Aside) + ' and can be opened.';
    Exit;
  end;
  { LoadDocument quite reasonably puts the file it read in the title.  This
    is not a file anyone opened, so take it back out: showing the draft's
    own path would invite saving over the safety net. }
  FDocPath := '';
  if Was <> '' then FHint := 'Not saved since ' + Was
  else FHint := 'Not saved to a file yet  -  Ctrl+S';
  FRestored := True;
  Result := True;
  FDraftSeq := FEditSeq;
  Trail(Format('restored a draft: %d things (%s)', [FD.Doc.Live, KindCounts]));
  if Was <> '' then
    FCmdMsg := 'Picked up where you left off in ' + ExtractFileName(Was) +
      '.  Ctrl+S to write it back.'
  else
    FCmdMsg := 'Picked up where you left off.  Ctrl+S to give it a name.';
end;

{ Put the example drawings on disk, beside the program.

  Written out as well as carried inside, because the program being one file
  is no help to somebody who wants to open the example again after drawing
  over it, send it to a friend, or read it in a text editor.

  It used to write them over the top on every run, on the argument that an
  example is a thing to take apart and should be found whole again next
  time.  True of one somebody took apart and walked away from; not true of
  one they changed and saved, which was quietly thrown away the next time
  the program started.  Now each is checked against what was written last -
  see PutExample - and one that has been saved over since is left alone.
  An untouched one still gets the newer version when the program has one.
  Somebody who wants the original back deletes their copy. }
{ The jigs the program carries, put in the jigs folder by the examples' own
  rule: one that has been changed there is somebody's, and is left alone. }
procedure TMainForm.WriteJigs;
var
  Ini: TIniFile;
  L: TStringList;
  I: Integer;
  Rec: string;
begin
  try
    Ini := TIniFile.Create(ConfigFile);
    L := TStringList.Create;
    try
      for I := 0 to JigFileCount - 1 do
      begin
        L.Clear;
        JigFileLines(I, L);
        Rec := Ini.ReadString('jigs', JigFileName(I), '');
        case PutCarried(JigsDir + JigFileName(I), L, Rec) of
          ewWritten, ewUpToDate:
            Ini.WriteString('jigs', JigFileName(I), Rec);
          ewKeptTheirs:
            Trail('jig ' + JigFileName(I) + ' has been changed here - left alone');
        end;
      end;
    finally
      L.Free;
      Ini.Free;
    end;
  except
    on E: Exception do ;
  end;
end;

procedure TMainForm.WriteExamples;
var
  Ini: TIniFile;
  I: Integer;
  Rec: string;
begin
  try
    if not ForceDirectories(ExamplesDir) then Exit;
    Ini := TIniFile.Create(ConfigFile);
    try
      for I := 0 to ExampleCount - 1 do
      begin
        Rec := Ini.ReadString('examples', ExampleFile(I), '');
        case PutExample(I, ExamplesDir, Rec) of
          ewWritten, ewUpToDate:
            Ini.WriteString('examples', ExampleFile(I), Rec);
          ewKeptTheirs:
            Trail('example ' + ExampleFile(I) + ' has been changed here - left alone');
        end;
      end;
    finally
      Ini.Free;
    end;
  except
    { a read-only folder, a full disk, a stick pulled out halfway - none of
      it is worth a word to somebody who only wanted to draw }
    on E: Exception do ;
  end;
end;

{ The drawing somebody sees the first time they run this.

  An empty sheet explains nothing.  Most people open a drawing program and
  look for something to click, and a toy etch-a-sketch answers that in one
  glance: a solid to orbit, a screen that is clearly a face, and a robot
  drawn in lines that is asking to be pushed.

  It arrives as a drawing and not as a file - FDocPath stays empty - so
  Ctrl+S asks where to put it and nothing can be written over.  Anybody who
  wants a clean sheet presses Ctrl+N, and having done so will never see this
  again, because from then on there is a draft. }
function TMainForm.LoadExample: Boolean;
var
  L: TStringList;
  Idx: Integer;
begin
  Result := False;
  L := TStringList.Create;
  try
    try
      ExampleDrawing(L);
      Idx := 0;
      while (Idx < L.Count) and (Copy(Trim(L[Idx]), 1, 6) <> 'SHEET ') do
        Inc(Idx);
      if Idx >= L.Count then Exit;
      FD.Name := Trim(Copy(Trim(L[Idx]), 7, MaxInt));
      Inc(Idx);
      FD.Doc.LoadFrom(L, Idx);
    except
      { an example that will not load is not worth taking the program down
        for - a clean sheet is a perfectly good fallback }
      on E: Exception do Exit;
    end;
  finally
    L.Free;
  end;
  if FD.Doc.Live = 0 then Exit;
  FD.View := vkOrbit;
  FD.Az := -0.785398;
  FD.El := 0.700000;
  FD.ScaleIdx := 4;
  FD.SnapIdx := 1;
  { Only when this is the whole drawing.  A sheet added to a drawing that has
    a file behind it must not throw the file away - sheets are parts of one
    document, and forgetting where it lives because somebody opened a tab is
    how work gets saved over the top of something else. }
  if Length(FDrawings) <= 1 then FDocPath := '';
  { It is not somebody's work until they have changed it, so it does not
    count as unsaved and closing it asks nothing.

    THIS sheet, and no other.  Setting the window-wide FSavedSeq here is what
    made a new sheet mark every other sheet saved as well - see TDrawing.Dirty
    - so that stays for the title bar and the draft, and the question about
    closing is asked of the flag. }
  FSavedSeq := FEditSeq;
  FD.Dirty := False;
  { The same as opening a file, and for the same reason: a drawing that
    carries its faces is telling us which areas are filled, including the
    ones somebody emptied on purpose.  Without this the example arrived with
    nothing marked as seen, so the first rebuild after it went to work over
    the top of faces that were already right - which is why it did not quite
    look like itself until somebody asked for a rebuild by hand. }
  SeedRegions;
  Result := True;
  FitView(False);
  Trail(Format('opened the example: %d things', [FD.Doc.Live]));
  FHint := 'An example to poke at.  Ctrl+N for an empty sheet.';
  FCmdMsg := 'This is the example drawing - orbit it, push a face, or ' +
    'press Ctrl+N to start your own.';
end;

{ Is a window at this place actually reachable?

  The old test asked whether the corner was inside the primary screen, with
  the top at or below zero - which is right for one monitor and wrong the
  moment there are two.  Windows numbers a monitor placed above or to the
  left of the primary one with negative coordinates, so a window docked on
  the left-hand screen saved a perfectly good position that failed this test
  on the way back in and got recenterd every single time.  On a work laptop
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
      uRecord.RecentWalks := Ini.ReadString('export', 'recentwalks', '');
      { which commands get used, so the list offers them first next time }
      FCmdRecent := Ini.ReadString('cmd', 'recent', '');
      { Where things went last time.  Written as one "ext=folder" line per
        kind of file, because there is no telling in advance which kinds
        somebody uses. }
      FSaveDir := Ini.ReadString('paths', 'drawings', '');
      FOpenDir := Ini.ReadString('paths', 'open', '');
      FExportDirs.Clear;
      Ini.ReadSectionValues('exportpaths', FExportDirs);
      FCubeOn := Ini.ReadBool('look', 'cube', False);
      CameraLamp := Ini.ReadBool('look', 'cameralamp', True);
      FSourceWasOpen := Ini.ReadBool('source', 'open', False);
      FSourceOnTop := Ini.ReadBool('source', 'ontop', False);
      FSourceComplete := Ini.ReadBool('source', 'complete', True);
      FSourceBounds := Rect(Ini.ReadInteger('source', 'left', 0), Ini.ReadInteger('source', 'top', 0),
        Ini.ReadInteger('source', 'width', 0), Ini.ReadInteger('source', 'height', 0));
      FInfoOn := Ini.ReadBool('look', 'info', False);
      FCubeCorner := EnsureRange(Ini.ReadInteger('look', 'cubecorner', 1), 0, 3);
      FCubeFitSel := Ini.ReadBool('look', 'cubefit', True);
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
      { Off until somebody asks for it.  From a note, 17 September: "sketchup
        doesnt do grid paper like we do at all... it should be off by
        default".  A setting already saved is untouched - this is only what
        a fresh copy starts with. }
      FShowGrid := Ini.ReadBool('look', 'grid', False);
      { PRO unless the toy was the last thing used - the drawing side is
        what the program is for; the toy is where it came from }
      FMode := TAppMode(EnsureRange(Ini.ReadInteger('look', 'mode', 1), 0, 1));
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
      { Names on, for somebody who has never seen it before.  A program that
        starts as a column of pictograms is a program a first-timer clicks
        nothing in. }
      FToolsWide := Ini.ReadBool('pro', 'toolnames', True);
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
      begin
        { The form is designed to open in the middle of the screen, and
          that setting outlives SetBounds: the widget set puts the window
          where the bounds say and then, at first show, centers it anyway.
          So the size came back and the place did not - "the right size but
          it starts in the center of the screen", 21 September, on Windows.
          Designed means: where the bounds say, and nowhere else. }
        Position := poDesigned;
        SetBounds(WL, WT, WW, WH);
      end
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
  I: Integer;
begin
  try
    ForceDirectories(ExtractFilePath(ConfigFile));
    Ini := TIniFile.Create(ConfigFile);
    try
      Ini.WriteBool('look', 'cube', FCubeOn);
      Ini.WriteBool('look', 'cameralamp', CameraLamp);
      { the source window: whether it was open, and where it had been put }
      Ini.WriteBool('source', 'open', FSourceWasOpen);
      Ini.WriteBool('source', 'ontop', FSourceOnTop);
      Ini.WriteBool('source', 'complete', FSourceComplete);
      if FSourceBounds.Right > 0 then
      begin
        Ini.WriteInteger('source', 'left', FSourceBounds.Left);
        Ini.WriteInteger('source', 'top', FSourceBounds.Top);
        Ini.WriteInteger('source', 'width', FSourceBounds.Right);
        Ini.WriteInteger('source', 'height', FSourceBounds.Bottom);
      end;
      Ini.WriteBool('look', 'info', FInfoOn);
      Ini.WriteInteger('look', 'cubecorner', FCubeCorner);
      Ini.WriteBool('look', 'cubefit', FCubeFitSel);
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
      Ini.WriteBool('pro', 'toolnames', FToolsWide);
      Ini.WriteInteger('pro', 'scale', FD.ScaleIdx);
      { which camera moves get used, so the list offers them first next time }
      Ini.WriteString('export', 'recentwalks', uRecord.RecentWalks);
      Ini.WriteString('cmd', 'recent', FCmdRecent);
      Ini.WriteString('paths', 'drawings', FSaveDir);
      Ini.WriteString('paths', 'open', FOpenDir);
      Ini.EraseSection('exportpaths');
      for I := 0 to FExportDirs.Count - 1 do
        if FExportDirs.Names[I] <> '' then
          Ini.WriteString('exportpaths', FExportDirs.Names[I],
            FExportDirs.ValueFromIndex[I]);
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
  { The about box, which is a page now.

    It used to be lines of text placed by hand with TextOut, which is fine
    until it has to say more than it did - and it does: who wrote the
    program, and whose work is inside it.  A credit with no link is not
    much of a credit, and a link is not a thing TextOut can offer.

    So the inside is LazInk drawing HTML, dressed in the program's own
    theme, and the frame round it is the same painted shell as before. }
  TAboutBox = class(TForm)
  private
    FSkin: TArtSurface;
    FTheme: TTheme;
    FScale: Single;
    FPage: TInkPage;
    procedure BoxPaint(Sender: TObject);
    procedure BoxKey(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure PageLink(Sender: TObject; const URL: string);
    function PageHTML: string;
    function PageStyle: string;
  public
    constructor CreateStyled(AOwner: TComponent; const ATheme: TTheme; AScale: Single);
    destructor Destroy; override;
  end;

constructor TAboutBox.CreateStyled(AOwner: TComponent; const ATheme: TTheme;
  AScale: Single);
var
  Pad: Integer;
begin
  inherited CreateNew(AOwner);
  FTheme := ATheme;
  FScale := AScale;
  BorderStyle := bsNone;
  Position := poMainFormCenter;
  ClientWidth := Round(700 * FScale);
  ClientHeight := Round(770 * FScale);
  { never taller than the screen it opens on - the designed size is for a
    desktop and the program runs on smaller ones }
  with Screen.WorkAreaRect do
  begin
    if ClientWidth > (Right - Left) * 9 div 10 then
      ClientWidth := (Right - Left) * 9 div 10;
    if ClientHeight > (Bottom - Top) * 9 div 10 then
      ClientHeight := (Bottom - Top) * 9 div 10;
  end;
  Color := PixToColor(FTheme.Shell2);
  KeyPreview := True;
  DoubleBuffered := True;
  FSkin := TArtSurface.Create(ClientWidth, ClientHeight);
  OnPaint := @BoxPaint;
  OnKeyDown := @BoxKey;

  { the page sits inside the painted frame, with the shell showing round it }
  Pad := Round(26 * FScale);
  FPage := TInkPage.Create(Self);
  FPage.Parent := Self;
  FPage.SetBounds(Pad, Pad, ClientWidth - 2 * Pad, ClientHeight - 2 * Pad);
  FPage.Anchors := [akLeft, akTop, akRight, akBottom];
  FPage.Color := PixToColor(FTheme.Panel);
  FPage.Font.Color := PixToColor(FTheme.Text);
  FPage.DragScroll := True;
  FPage.OnLinkClick := @PageLink;
  FPage.StyleSheet.Text := PageStyle;
  FPage.LoadHTML(PageHTML);
end;

destructor TAboutBox.Destroy;
begin
  FSkin.Free;
  inherited Destroy;
end;

{ The page's look, out of the program's theme, so the box is the same
  object as the window behind it. }
function TAboutBox.PageStyle: string;

  function Hex(const P: TPix): string;
  begin
    Result := Format('#%.2x%.2x%.2x', [P.R, P.G, P.B]);
  end;

var
  Base: Integer;
begin
  Base := Max(11, Round(14 * FScale));
  Result :=
    'html { scrollbar-color: ' + Hex(FTheme.Accent) + ' ' +
      Hex(MixPix(FTheme.Panel, Pix(0, 0, 0), 0.25)) + '; scrollbar-width: thin }' +
    ' body { background: ' + Hex(FTheme.Panel) + '; color: ' +
      Hex(FTheme.TextDim) + '; font-size: ' + IntToStr(Base) +
      'px; line-height: 1.55; padding: ' + IntToStr(Round(18 * FScale)) + 'px }' +
    ' h1 { color: ' + Hex(FTheme.Text) + '; font-size: ' +
      IntToStr(Round(Base * 1.9)) + 'px; margin-top: 0; margin-bottom: 2px }' +
    ' h2 { color: ' + Hex(FTheme.Accent) + '; font-size: ' +
      IntToStr(Round(Base * 1.15)) + 'px; margin-top: ' +
      IntToStr(Round(22 * FScale)) + 'px; margin-bottom: 6px;' +
      ' text-transform: uppercase }' +
    ' p { margin-top: 0; margin-bottom: ' + IntToStr(Round(10 * FScale)) + 'px }' +
    ' .lede { color: ' + Hex(FTheme.Accent) + '; margin-bottom: ' +
      IntToStr(Round(16 * FScale)) + 'px }' +
    ' strong, b { color: ' + Hex(FTheme.Text) + ' }' +
    ' a { color: ' + Hex(FTheme.Accent) + ' }' +
    ' .signed { color: ' + Hex(FTheme.TextDim) + '; font-style: italic;' +
      ' text-align: right; margin-top: ' + IntToStr(Round(18 * FScale)) + 'px }' +
    ' table.credits { width: 100%; border-collapse: separate;' +
      ' border-spacing: ' + IntToStr(Round(6 * FScale)) + 'px }' +
    ' table.credits td { background: ' +
      Hex(MixPix(FTheme.Panel, FTheme.PanelHi, 0.55)) + '; color: ' +
      Hex(FTheme.TextDim) + '; border: 1px solid ' +
      Hex(MixPix(FTheme.Panel, FTheme.Text, 0.18)) + '; border-radius: 8px;' +
      ' padding: ' + IntToStr(Round(9 * FScale)) + 'px; width: 50%;' +
      ' valign: top }' +
    ' table.credits a { font-weight: bold; text-decoration: none }';
end;

{ What it says.  The story first, because that is what the program is; then
  what it is made of, because none of that was ours and all of it is worth
  naming. }
function TAboutBox.PageHTML: string;
begin
  Result :=
    '<h1>' + APP_NAME + '</h1>' +
    '<p class="lede">NozelFab Incorporated &middot; ' + CurrentVersion + '</p>' +

    '<p><b>Noella Stone was seven years old</b> when she decided she wanted ' +
    'to write a program.  She drew the screen, the two dials and the shake ' +
    'button on paper, picked the colors, and told her dad what each part ' +
    'was supposed to do.  He typed while she directed.  19 October 2021.</p>' +

    '<h2>Toy</h2>' +
    '<p>The program she designed.  Two dials, five kinds of pen, a ' +
    'kaleidoscope, and a shake that dissolves the drawing into powder.</p>' +

    '<h2>Pro</h2>' +
    '<p>The same idea taken seriously.  Pick a scale, put the cursor on a ' +
    'point, and type 12&#39;6&quot; to draw exactly that.  Lines, arcs, ' +
    'circles, notes and a tape measure, in plan or isometric, and it prints ' +
    'at true scale.</p>' +

    '<h2>Standing on</h2>' +
    '<table class="credits">' +
    '<tr>' +
    '<td><a href="https://www.freepascal.org/">Free Pascal</a> and ' +
    '<a href="https://www.lazarus-ide.org/">Lazarus</a><br>' +
    'One source, every desktop.</td>' +
    '<td><a href="https://github.com/bgrabitmap/bgrabitmap">BGRABitmap</a> ' +
    'and BGRAControls<br>' +
    'The bitmaps, and the buttons round them.</td>' +
    '</tr><tr>' +
    '<td><a href="https://github.com/TonyStone31/LazInk">LazInk</a><br>' +
    'Ours.  It draws this page and the manual - HTML in a native control, ' +
    'no browser near it.</td>' +
    '<td><a href="https://github.com/Xelitan/Pure-Pascal-Webp-for-Delphi-Lazarus-Free-Pascal">' +
    'Xelitan&#39;s WebP encoder</a><br>' +
    'Pure Pascal, MIT.  It is why a film exports as a WebP with nothing ' +
    'shipped beside the program.  Thank you.</td>' +
    '</tr></table>' +

    '<p class="signed">Good job, Noella.  Love you.  &mdash; Dad</p>' +
    '<p class="signed">Esc closes this.</p>';
end;

{ A credit with a link in it is only a credit if the link goes somewhere. }
procedure TAboutBox.PageLink(Sender: TObject; const URL: string);
begin
  if (Pos('http://', URL) = 1) or (Pos('https://', URL) = 1) then
    OpenURL(URL);
end;

procedure TAboutBox.BoxPaint(Sender: TObject);
begin
  PaintShell(FSkin, FTheme);
  FSkin.RoundFrame(Rect(1, 1, ClientWidth - 1, ClientHeight - 1),
    Round(14 * FScale), 2.0, FTheme.Accent, 0.85);
  FSkin.DrawTo(Canvas, 0, 0);
end;

procedure TAboutBox.BoxKey(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) or (Key = VK_RETURN) or (Key = VK_F1) then
  begin
    Close;
    Key := 0;
  end;
end;

{ ======================================================================== }
{ a box of plain lines in the same style - what /sysinfo shows             }
{ ======================================================================== }

type
  TFactsBox = class(TForm)
  private
    FSkin: TArtSurface;
    FTheme: TTheme;
    FScale: Single;
    FTitle: string;
    FLines: TStringList;
    procedure BoxPaint(Sender: TObject);
    procedure BoxClick(Sender: TObject);
    procedure BoxKey(Sender: TObject; var Key: word; Shift: TShiftState);
  public
    constructor CreateStyled(AOwner: TComponent; const ATheme: TTheme; AScale: Single;
      const ATitle, AText: string);
    destructor Destroy; override;
  end;

constructor TFactsBox.CreateStyled(AOwner: TComponent; const ATheme: TTheme;
  AScale: Single; const ATitle, AText: string);
begin
  inherited CreateNew(AOwner);
  FTheme := ATheme;
  FScale := AScale;
  FTitle := ATitle;
  FLines := TStringList.Create;
  FLines.Text := AText;
  while (FLines.Count > 0) and (Trim(FLines[FLines.Count - 1]) = '') do
    FLines.Delete(FLines.Count - 1);
  BorderStyle := bsNone;
  Position := poMainFormCenter;
  ClientWidth := Round(760 * FScale);
  ClientHeight := Round((124 + 22 * FLines.Count) * FScale);
  Color := PixToColor(FTheme.Shell2);
  KeyPreview := True;
  DoubleBuffered := True;
  FSkin := TArtSurface.Create(ClientWidth, ClientHeight);
  OnPaint := @BoxPaint;
  OnClick := @BoxClick;
  OnKeyDown := @BoxKey;
end;

destructor TFactsBox.Destroy;
begin
  FLines.Free;
  FSkin.Free;
  inherited Destroy;
end;

procedure TFactsBox.BoxPaint(Sender: TObject);
var
  I, Y, Pad, Colon: Integer;
  S, K: string;
begin
  Pad := Round(30 * FScale);
  PaintShell(FSkin, FTheme);
  FSkin.RoundFrame(Rect(1, 1, ClientWidth - 1, ClientHeight - 1),
    Round(14 * FScale), 2.0, FTheme.Accent, 0.85);
  FSkin.Line(Pad, Round(58 * FScale), ClientWidth - Pad, Round(58 * FScale),
    1.4, FTheme.Accent, 0.6);
  FSkin.DrawTo(Canvas, 0, 0);

  Canvas.Brush.Style := bsClear;
  Canvas.Font.Name := {$IFDEF WINDOWS}'Segoe UI'{$ELSE}'Sans'{$ENDIF};
  Canvas.Font.Height := -Round(18 * FScale);
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := PixToColor(FTheme.Text);
  Canvas.TextOut(Pad, Round(22 * FScale), FTitle);

  Canvas.Font.Height := -Round(13 * FScale);
  Canvas.Font.Style := [];
  Y := Round(74 * FScale);
  for I := 0 to FLines.Count - 1 do
  begin
    S := FLines[I];
    Colon := Pos(': ', S);
    if Colon > 0 then
    begin
      { the name in the accent, the value in plain text }
      K := Copy(S, 1, Colon);
      Canvas.Font.Color := PixToColor(FTheme.Accent);
      Canvas.TextOut(Pad, Y, K);
      Canvas.Font.Color := PixToColor(FTheme.Text);
      Canvas.TextOut(Pad + Round(150 * FScale), Y, Trim(Copy(S, Colon + 1, MaxInt)));
    end
    else
    begin
      Canvas.Font.Color := PixToColor(FTheme.Text);
      Canvas.TextOut(Pad, Y, S);
    end;
    Inc(Y, Round(22 * FScale));
  end;

  Canvas.Font.Height := -Round(12 * FScale);
  Canvas.Font.Color := PixToColor(FTheme.TextDim);
  S := 'this goes with every report - click anywhere, or press Esc, to close';
  Canvas.TextOut((ClientWidth - Canvas.TextWidth(S)) div 2,
    ClientHeight - Round(28 * FScale), S);
end;

procedure TFactsBox.BoxClick(Sender: TObject);
begin
  Close;
end;

procedure TFactsBox.BoxKey(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  Close;
  Key := 0;
end;

procedure TMainForm.ShowFacts(const Title, AText: string);
var
  Box: TFactsBox;
begin
  Box := TFactsBox.CreateStyled(Self, Theme, FUIScale, Title, AText);
  try
    Box.ShowModal;
  finally
    Box.Free;
  end;
end;

{ A long report section, to read and copy.  The facts box above paints a
  line a row and fits /sysinfo; /state is sixty lines, some of them wider
  than any window, with times in them that the box took for "name: value".
  So a plain text box that scrolls, and a button to copy it all. }
procedure TMainForm.ShowLongText(const Title, AText: string);
var
  Dlg: TForm;
  Memo: TMemo;
  Bar: TPanel;
  BtnCopy, BtnClose: TButton;
begin
  Dlg := TForm.CreateNew(nil);
  try
    Dlg.Caption := Title;
    Dlg.Position := poMainFormCenter;
    Dlg.BorderStyle := bsSizeable;
    Dlg.ClientWidth := Min(Round(1000 * FUIScale), Screen.WorkAreaWidth - 80);
    Dlg.ClientHeight := Min(Round(640 * FUIScale), Screen.WorkAreaHeight - 80);
    Dlg.KeyPreview := True;
    Bar := TPanel.Create(Dlg);
    Bar.Parent := Dlg;
    Bar.Align := alBottom;
    Bar.Height := Round(48 * FUIScale);
    Bar.BevelOuter := bvNone;
    BtnClose := TButton.Create(Dlg);
    BtnClose.Parent := Bar;
    BtnClose.Caption := 'Close';
    BtnClose.ModalResult := mrOK;
    BtnClose.Cancel := True;
    BtnClose.Default := True;
    BtnClose.SetBounds(Bar.Width - Round(120 * FUIScale), Round(8 * FUIScale),
      Round(110 * FUIScale), Round(32 * FUIScale));
    BtnClose.Anchors := [akTop, akRight];
    BtnCopy := TButton.Create(Dlg);
    BtnCopy.Parent := Bar;
    BtnCopy.Caption := 'Copy it all';
    BtnCopy.ModalResult := mrYes;
    BtnCopy.SetBounds(Bar.Width - Round(250 * FUIScale), Round(8 * FUIScale),
      Round(122 * FUIScale), Round(32 * FUIScale));
    BtnCopy.Anchors := [akTop, akRight];
    Memo := TMemo.Create(Dlg);
    Memo.Parent := Dlg;
    Memo.Align := alClient;
    Memo.ReadOnly := True;
    Memo.WordWrap := False;
    Memo.ScrollBars := ssBoth;
    Memo.Font.Name := {$IFDEF WINDOWS}'Consolas'{$ELSE}'Monospace'{$ENDIF};
    Memo.Font.Height := -Round(13 * FUIScale);
    Memo.Lines.Text := AText;
    if Dlg.ShowModal = mrYes then
    begin
      Clipboard.AsText := AText;
      FCmdMsg := 'Copied.';
    end;
  finally
    Dlg.Free;
  end;
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
