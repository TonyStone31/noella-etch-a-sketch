unit uWork;

{
  uWork - the drafting side of Poopin Heckers Sketch.

  PRO mode is a small 2D drawing board with SketchUp's habits: pick a tool,
  click a point, and either move to the next one or just type the distance.
  Nothing here knows about dials or pen styles - that is the toy's half of
  the program.

  What lives here:
    * a document of entities - lines, arcs (a circle is a full-sweep arc),
      text notes and standalone dimensions - measured in real units and kept
      as geometry, so changing the drawing scale re-draws everything exactly
      instead of resampling pixels;
    * length parsing and formatting - 12'6", 12-6, 6 1/2", 3.5m, 350cm;
    * the drawing scale table and snap increments;
    * hit testing (for the eraser), snap-point gathering, and rendering.

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Math, StrUtils, Graphics, uSurface, uDxf;

type
  TUnitSystem = (usImperial, usMetric);

  { A point in the model.  Everything is stored in 3D from the start, so
    adding views later is a projection change rather than a rewrite: PLAN
    ignores Z, ISO folds all three axes onto the screen, and a perspective
    view would slot in beside them. }
  TP3 = record
    X, Y, Z: Double;
  end;

  { How the model is mapped onto the screen.

    vkPlan  - straight down the Z axis, the 2D drawing board.
    vkIso   - the 30 degree drafting isometric: axes at true length, which is
              what a dimensioned spool drawing needs.
    vkOrbit - a free orthographic 3D view you can spin.  This is the one that
              makes push/pull worth having. }
  TViewKind = (vkPlan, vkIso, vkOrbit);

  { The plane an arc or circle lies in. }
  { The three flat planes, and a fourth that is whatever face you are
    pointing at.  Without the fourth there is no way to say "the roof": a
    circle can only go on something square to an axis, which rules out every
    slope in the trade. }
  TPlane = (plXY, plXZ, plYZ, plFree);

  TProjector = record
    Kind: TViewKind;
    Ppu: Double;          // pixels per world unit
    OX, OY: Double;       // screen position of world 0,0,0
    Az, El: Double;       // vkOrbit only: turntable and tilt, in radians
  end;

  { A drawing scale.  Paper is the fraction of a paper unit that one world
    unit occupies - for 1/4" = 1'-0" that is 0.25 paper inches per foot. }
  TDrawScale = record
    Name: string;
    Paper: Double;
  end;

  { A guide is a construction line or point laid down with the tape measure.
    SketchUp's rule: "these lines do not interfere with regular geometry" -
    they are infinite, dashed, snappable, erasable, and never make a face or
    bound one.  A guide whose two points are the same is a guide point. }
  { ekBore is a tunnel pushed through a solid: not drawn, not picked, not
    snapped to.  Poly is the opening where it starts, B where Poly[0] comes
    out the far side, Grp the solid.  It is kept so that the next tunnel
    through the same solid knows what it is crossing.  An entity rather than
    a list of its own so that undo, save and load carry it for nothing. }
  TEntKind = (ekLine, ekArc, ekText, ekDim, ekFace, ekGuide, ekBore);

  { One thing on the drawing.  World coordinates, Y up, in feet or metres.

    ekLine  uses A and B.
    ekArc   uses C (center), R, A0 (start angle) and Sweep; a circle is just
            a sweep of 2*pi.  A and B are kept as the endpoints for snapping.
    ekText  uses A and Txt.
    ekDim   uses A and B and always draws its dimension line. }
  TWorkEnt = record
    Kind: TEntKind;
    A, B, C: TP3;
    R, A0, Sweep: Double;
    Plane: TPlane;
    { Where the note's box last landed on screen.  Not saved and not part of
      the drawing - it is written down as the note is drawn so that clicking
      the box can find it, which guessing at font metrics somewhere else
      could only ever approximate. }
    BoxL, BoxT, BoxR, BoxB: Single;
    { For an arc in plFree, the way its plane faces.  The plane itself is a
      name, and a name is only good while nothing has renamed it - so a circle
      on a roof has to carry its own or it lies back down flat the moment the
      cursor moves on to something else. }
    Nm: TP3;
    { how many straight pieces an arc is drawn and cut in; 0 is the old
      fixed 48, so drawings from before this read as they did }
    Sides: Integer;
    Poly: array of TP3;   // ekFace: the closed outline, in order
    { What is cut out of it.  A window in a wall, the opening a duct passes
      through, the inside of a ring left by an offset - all the same thing:
      an area whose outline is this face's and which is not filled where
      these loops say it is not.

      Empty for nearly every face, and everything that reads a face treats an
      empty list as the shape it always was, so this costs nothing where it
      is not used. }
    Holes: array of array of TP3;
    Solid: Boolean;       // ekFace: part of a solid, so its back is hidden
    { Which solid this belongs to, or 0 for loose drawing.  Push/pull drags
      the geometry attached to the face it moves, and without this it dragged
      anything that merely touched - a box beside another one deformed its
      neighbor through the corner they shared. }
    Grp: Integer;
    Txt: string;
    Ink: TColor;
    Weight: Single;
    { ekText: how big the words are, as a multiple of the drawing's normal
      note size.  Nought means normal, which is what every note made before
      this has and what a new one gets - so nothing that exists changes. }
    Size: Single;
    Dim: Boolean;
    { A soft edge is one of the many little creases that stand in for a curved
      surface - the facets down the side of a pulled circle.  SketchUp hides
      them, which is what makes a cylinder look like a pipe rather than a
      barrel of staves, and shows them only where the surface turns away from
      you and the crease is the outline. }
    Soft: Boolean;
  end;

  TWorkEntArray = array of TWorkEnt;
  TP3Array = array of TP3;
  TPointFArray = array of TPointF;

  { snSubMid is the midpoint of a piece of a line that something else has
    crossed, as opposed to snMidpoint, the middle of a whole uncrossed one.
    Splitting a rectangle in half puts one of these at the quarter point of
    every edge it touched, so they multiply fast and are worth much less
    than the point you actually aimed at. }
  { snOnEdge is a free point anywhere along a line or an arc - SketchUp's
    "On Edge" - as opposed to one of the named points along it. }
  { snOnAxis is a free point anywhere along one of the three model axes, and
    snOrigin is where they meet.  They are inference, not geometry, but they
    are the only thing an empty drawing has to offer - without them a new
    sheet snaps to nothing at all, the tape cannot be started off the red
    line, and the one point in the model everybody knows the coordinates of
    cannot be landed on. }
  TSnapKind = (snNone, snGrid, snEndpoint, snMidpoint, snCenter, snCross,
    snSubMid, snOnEdge, snOnAxis, snOrigin, snOnFace);

  { Everything a dimension is drawn out of, in screen coordinates.  One
    routine works it out so that the preview you drag around and the thing
    that ends up on the drawing cannot drift apart. }
  TDimGeom = record
    A, B: TPointF;          { the two points being measured }
    W1, W2: TPointF;        { where each witness line ends }
    LA, LB: TPointF;        { the dimension line itself }
    S1A, S1B, S2A, S2B: TPointF;   { the slashes at each end }
    Mid: TPointF;           { the middle of the dimension line itself }
    Nrm: TPointF;           { unit vector pointing away from the geometry }
    Txt: string;
  end;

  TSnapHit = record
    P: TP3;
    Kind: TSnapKind;
  end;

  { TWorkDoc }

  TWorkDoc = class
  private
    FEnts: array of TWorkEnt;
    FLive: Integer;      // entities in play; anything past this is redo space
    FSnapCache: array of TSnapHit;
    FSnapDirty: Boolean;
    FGuidesHidden: Boolean;
    FNextGrp: Integer;
    FLastBore: Integer;
    function GetEnt(I: Integer): TWorkEnt;
    procedure RebuildSnapCache;
  public
    procedure AddLine(const A, B: TP3; Ink: TColor; Weight: Single; Dim: Boolean);
    { True when a line with these ends is already there, either way round. }
    function HasLine(const A, B: TP3): Boolean;
    procedure AddArc(const C: TP3; R, A0, Sweep: Double; Pl: TPlane;
      Ink: TColor; Weight: Single);
    procedure SetArcSides(Index, N: Integer);
    procedure AddText(const A: TP3; const S: string; Ink: TColor);
    { A note with a leader out to Target.  Target = A means no leader, which
      is a plain label. }
    procedure AddNote(const A, Target: TP3; const S: string; Ink: TColor);
    { Off is the vector from what is measured to where the dimension line
      sits - a real displacement in the model, not a number of pixels. }
    procedure AddDim(const A, B: TP3; Ink: TColor; const Off: TP3;
      const Note: string = '');
    { Write over a dimension's figure, or hand it back to the measurement by
      passing an empty string.  False when that entity is not a dimension. }
    function SetDimNote(Index: Integer; const Note: string): Boolean;
    { A construction line through A running towards B, or - when the two are
      the same point - a construction point at A. }
    procedure AddGuide(const A, B: TP3);
    function GuideCount: Integer;
    { Guides can be put away without being thrown away - they are aids, and a
      drawing being looked at rather than laid out does not want them.  Held
      the negative way round so that a document with nothing said about it
      shows them, which is what a field left alone gives. }
    property GuidesHidden: Boolean read FGuidesHidden write FGuidesHidden;
    function ClearGuides: Integer;
    procedure AddFace(const Pts: array of TP3; Ink: TColor; Solid: Boolean = False);
    procedure AddFaceRaw(const Pts: array of TP3; Ink: TColor; Solid: Boolean);
    { The record of a tunnel: its opening, where the first corner of that
      opening comes out, and whose solid it is. }
    procedure AddBore(const Loop: TP3Array; const FarOfFirst: TP3; G: Integer);
    { Give a face the loops cut out of it - a window in a wall, the middle of
      a ring left by an offset. }
    procedure SetFaceHoles(Index: Integer; const H: array of TP3Array);
    { Make a face part of a solid - the one whose face it was cut from. }
    procedure SetFaceGroup(Index, G: Integer);
    { the same for anything - a line that belongs to a solid, say }
    procedure SetGroup(Index, G: Integer);
    procedure SetSoft(Index: Integer; Soft: Boolean);
    { Turn a face over: its outline and its openings run the other way round,
      so its normal points the other way. }
    procedure FlipFace(Index: Integer);
    { A note's text size, as a multiple of normal; 1 when it has never been
      set.  SketchUp changes the size of the words rather than the box, and
      that is the thing worth having - the box follows the words. }
    function NoteSize(Index: Integer): Single;
    procedure SetNoteSize(Index: Integer; Factor: Single);

    { push/pull: lift the face along its own normal and wall in the sides }
    { Hand the edges round a face to a solid's group, so they stop counting
      as loose lines that enclose a flat area. }
    procedure ClaimOutline(Face, G: Integer);
    function PushPull(Index: Integer; Dist: Double): Boolean;
    { Slide a face along a vector, dragging everything joined to it. }
    procedure MoveFaceWith(Index: Integer; const D: TP3);
    { A pushed patch whose far end lands on another face of the same solid
      that contains it.  Opens that face, walls the tunnel, removes the patch
      and its edges' claim.  False when the push lands anywhere else. }
    function TunnelThrough(Index: Integer; const Top: TP3Array;
      const Nm: TP3; Dist: Double): Boolean;
    { Every corner of these entities, for moving or for stretching. }
    procedure VertsOf(const Idx: array of Integer; out Pts: TP3Array);
    { Shift every vertex in the drawing that sits on one of these points.
      Geometry joined to what moves comes along, which is what makes moving
      one edge of a shape stretch the rest of it. }
    procedure MoveVerts(const Pts: TP3Array; const D: TP3);
    procedure RotateEnt(I: Integer; const Pts: TP3Array; const C, Axis: TP3;
      Ang: Double; All: Boolean);
    { Every corner on the set turns about the axis; whatever shares a corner
      stretches to follow, the same rule as MoveVerts.  An arc turns whole. }
    procedure RotateVerts(const Pts: TP3Array; const C, Axis: TP3; Ang: Double);
    { These entities turn whole, whatever they touch - for a copy. }
    procedure RotateEnts(const Idx: array of Integer; const C, Axis: TP3; Ang: Double);
    { The points Outline projects, before projection - for drawing a ghost
      of the thing somewhere other than where it is. }
    function OutlineWorld(I: Integer): TP3Array;
    { Copy these entities, offset.  A copy stretches nothing. }
    procedure Duplicate(const Idx: array of Integer; const D: TP3);
    { Where an entity lands on screen, for a selection box to test against. }
    procedure ScreenBounds(const V: TProjector; I: Integer;
      out X0, Y0, X1, Y1: Double);
    { Cut every flat face this segment crosses in two.  Returns how many were
      split.  This is what makes a line drawn across a shape divide it. }
    function SplitFacesWith(const A, B: TP3): Integer;
    { Is this face one piece of a larger flat area rather than the whole flat
      side of something?  True when another face lying in the same plane runs
      along one of its edges - which is exactly what a cut across a box top
      leaves behind.  Push decides what to do from this: a whole side slides
      and resizes the solid, a patch is lifted out of it. }
    function IsPatch(Index: Integer): Boolean;
    { The face a point lies on, or -1.  Used to work out which plane a new
      shape belongs in when the cursor has snapped to a corner. }
    function FaceThrough(const P: TP3): Integer;
    function SplitFace(Index: Integer; const A, B: TP3): Boolean;
    function HitFace(const V: TProjector; SX, SY: Double): Integer;
    { The same search, but also handing back the point on that face where the
      cursor meets it - which is where a new shape drawn there should sit. }
    function FaceUnder(const V: TProjector; SX, SY: Double;
      out Face: Integer; out Pt: TP3): Boolean;
    function FaceNormal(Index: Integer): TP3;
    function FaceArea(Index: Integer): Double;
    procedure Delete(I: Integer);
    procedure Clear;
    function Snapshot: TWorkEntArray;
    procedure RestoreSnap(const A: TWorkEntArray);
    function Stored: Integer;

    { the run of chained lines ending at the last entity }
    function FirstOfChain: Integer;
    function ChainLength: Double;
    function ChainClosed(Tol: Double): Boolean;
    function ChainArea: Double;

    { Hit testing and snapping are done in screen space so they behave the
      same in every view. }
    function HitTest(const V: TProjector; SX, SY, TolPx: Double): Integer;
    { Is this point of the model hidden behind a face, from where we look? }
    function HiddenAt(const V: TProjector; const P: TP3): Boolean;
    { The note whose box is under this point, or -1.  Uses where the box was
      last drawn, so it is exact rather than estimated. }
    function HitNote(SX, SY: Double): Integer;
    { Carry a note's box to a new place.  Only the box - what it points at is
      left where it is. }
    procedure MoveNote(Index: Integer; const From, ToPt, Grab: TP3);
    { The same search but only over edges - lines, arcs and dimensions.
      Erasing means erasing an edge; a face is what is left behind. }
    function HitEdge(const V: TProjector; SX, SY, TolPx: Double): Integer;
    { The pen weight of the line running between these two points, or 0 when
      there is not one.  A solid's new edges copy it, so everything drawn
      from the same pen looks like it. }
    function EdgeWeight(const A, B: TP3): Single;
    { The nearest point lying *on* a line or an arc, within TolPx of the
      pointer.  This is SketchUp's On Edge inference: hovering an edge should
      give you a point on that edge, not the nearest corner of it. }
    function EdgeSnap(const V: TProjector; SX, SY, TolPx: Double;
      out P: TP3; out Ent: Integer): Boolean;

    { A new drawing has a snap cache to build like any other.

      There was no constructor at all, so the dirty flag started false and
      the cache was not built until the first edit marked it dirty.  That was
      invisible for as long as the cache only held things the drawing
      contained - an empty drawing has no corners to miss - and stopped being
      invisible the moment the origin went in, because the origin is there
      before anything is drawn. }
    constructor Create;

    { Every point worth snapping or aligning to, including the places lines
      cross each other and the midpoints those crossings create. }
    procedure SnapPoints(out Pts: TP3Array);

    { An entity's outline in screen coordinates, for highlighting it. }
    function Outline(const V: TProjector; I: Integer): TPointFArray;
    function BestSnap(const V: TProjector; SX, SY, TolPx: Double;
      out Hit: TSnapHit): Boolean;
    function Bounds(out Lo, Hi: TP3): Boolean;

    { EdgeW is one weight for every edge in the drawing.  SketchUp has no
      per-edge thickness - it is a style setting for the whole model, with
      Profiles thickening the silhouette - and copying that removes a whole
      class of mismatch: geometry made by push/pull no longer has to guess
      what pen the outline it grew from was drawn with. }
    procedure Render(S: TArtSurface; const V: TProjector;
      U: TUnitSystem; AFont: TFont; const LabelCol: TPix; EdgeW: Single);

    { the document, as plain text - one line per entity }
    procedure SaveTo(L: TStrings);
    procedure LoadFrom(L: TStrings; var Idx: Integer);
    { The drawing as DXF.  ThreeD writes the model in its own coordinates,
      faces and all; otherwise it is this view, flat, the way the SVG is -
      but as entities somebody can snap to and measure in their own CAD. }
    procedure WriteDXF(L: TStrings; const V: TProjector; U: TUnitSystem;
      ThreeD: Boolean);
    procedure WriteSVG(L: TStrings; const V: TProjector; U: TUnitSystem;
      EdgeW: Single);

    property Live: Integer read FLive;
    { the bore the last PushPull made, or -1 - so the caller can cut it
      against the others }
    property LastBore: Integer read FLastBore;
    property Ent[I: Integer]: TWorkEnt read GetEnt; default;
  end;

const
  SCALE_COUNT = 5;

  IMPERIAL_SCALES: array[0..SCALE_COUNT - 1] of TDrawScale = (
    (Name: '1/16"'; Paper: 0.0625),
    (Name: '1/8"';  Paper: 0.125),
    (Name: '1/4"';  Paper: 0.25),
    (Name: '1/2"';  Paper: 0.5),
    (Name: '1"';    Paper: 1.0));

  METRIC_SCALES: array[0..SCALE_COUNT - 1] of TDrawScale = (
    (Name: '1:200'; Paper: 0.005),
    (Name: '1:100'; Paper: 0.01),
    (Name: '1:50';  Paper: 0.02),
    (Name: '1:20';  Paper: 0.05),
    (Name: '1:10';  Paper: 0.1));

  SNAP_COUNT = 10;

  { snap increments, in world units (feet / metres); 0 means no snapping }
  { in feet: a sixteenth is 1/192 of one }
  IMPERIAL_SNAPS: array[0..SNAP_COUNT - 1] of Double =
    (0, 1 / 192, 1 / 96, 1 / 48, 1 / 24, 1 / 12, 1 / 6, 0.25, 0.5, 1.0);
  IMPERIAL_SNAP_NAMES: array[0..SNAP_COUNT - 1] of string =
    ('OFF', '1/16"', '1/8"', '1/4"', '1/2"', '1"', '2"', '3"', '6"', '1''-0"');

  METRIC_SNAPS: array[0..SNAP_COUNT - 1] of Double =
    (0, 0.001, 0.002, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 1.0);
  METRIC_SNAP_NAMES: array[0..SNAP_COUNT - 1] of string =
    ('OFF', '1mm', '2mm', '5mm', '10mm', '25mm', '50mm', '100mm', '250mm', '1m');

function UnitName(U: TUnitSystem): string;
function ScaleTable(U: TUnitSystem; I: Integer): TDrawScale;
function SnapValue(U: TUnitSystem; I: Integer): Double;
function SnapName(U: TUnitSystem; I: Integer): string;

{ Pixels per world unit for a scale, given the display resolution in pixels
  per paper inch. }
function PixelsPerUnit(U: TUnitSystem; const Sc: TDrawScale; DPI: Double): Double;

{ How finely an imperial length is written, and what the last field of a
  dashed entry counts in.  A sixteenth unless the drawing says otherwise. }
procedure SetLenDenom(D: Integer);
function LenDenom: Integer;

function FormatLen(V: Double; U: TUnitSystem): string;
function FormatArea(V: Double; U: TUnitSystem): string;
function ParseLen(const S: string; U: TUnitSystem; out V: Double): Boolean;

{ An angle as typed for the rotate tool and the protractor: decimal degrees
  (34.1, -45, 90d), or a slope as rise:run (8:12).  Negative is the other way. }
function ParseAngle(const S: string; out Deg: Double): Boolean;
function FormatAngle(Deg: Double): string;

{ The number of straight pieces this arc is walked in, everywhere it is
  walked: drawn, picked, cut into regions, laid flat. }
function ArcSteps(const E: TWorkEnt): Integer;

{ SketchUp's way of saying how many sides: 24s, or s24.  Nothing else. }
function ParseSides(const S: string; out N: Integer): Boolean;

{ P turned about the line through C along the unit vector Axis, by Ang
  radians, right-handed.  RotV does the same to a direction. }
function RotP(const P, C, Axis: TP3; Ang: Double): TP3;
function RotV(const V, Axis: TP3; Ang: Double): TP3;
{ Reads "[3', 4', 5']" or "<3', 4', 5'>" - a point in the drawing, or an
  offset from where you are.  Returns how many of the three were given;
  any left out come back as zero. }
function ParseTriple(const S: string; U: TUnitSystem;
  out X, Y, Z: Double): Integer;

{ A "nice" round bar length that lands between MinPx and MaxPx on screen. }
function NiceBarLength(Ppu: Double; MinPx, MaxPx: Double; U: TUnitSystem): Double;

{ Build an arc through A and B that bulges Bulge units away from the chord.
  This is how two loose line ends get joined by a curve without any trimming:
  pick the two ends, then pull the middle out. }
function ArcFromChord(const A, B: TP3; Bulge: Double; Pl: TPlane;
  out C: TP3; out R, A0, Sweep: Double): Boolean;

function P3(X, Y, Z: Double): TP3; inline;
function Dist(const A, B: TP3): Double; inline;
function SamePt(const A, B: TP3; Tol: Double): Boolean; inline;

{ --- projection ---------------------------------------------------------- }
function Project(const V: TProjector; const P: TP3): TPointF;

{ Screen point back to the model, on the working plane through Base.  In PLAN
  that is simply the XY plane; in ISO the plane is picked by Pl. }
function Unproject(const V: TProjector; SX, SY: Double; Pl: TPlane;
  const Base: TP3): TP3;

{ Which plane is the mouse most honestly moving across?

  Draw a rectangle in mid air and something has to decide whether it lies
  flat or stands up.  SketchUp takes it from the way the mouse moves, and
  this is the rule that reproduces it: for the same movement on screen, a
  plane seen edge-on needs an enormous displacement in the model and one
  seen square-on needs a small one, so the plane that explains the drag with
  the least travel is the plane being drawn on.

  It falls out right with no view special cases.  Drag straight up in an
  isometric view and the upright planes need one unit where the ground needs
  1.41 - it has to go away along both X and Y to climb the screen - so the
  rectangle stands up.  Drag across and the ground needs 0.82 against the
  uprights' 1.29, so it lies flat.

  Keep is the plane in force now.  It wins ties, and wins anything closer
  than Bias, so a shape does not flip back and forth while the hand shakes. }
function PlaneByDrag(const V: TProjector; const Anchor: TP3;
  SX, SY: Double; Keep: TPlane; Bias: Double = 0.8): TPlane;

{ A point on one of the three model axes, if the cursor is near one.

  The axes are infinite lines through the origin, so this is the same
  question EdgeSnap asks of a segment, without the ends.  Axis comes back as
  0, 1 or 2 - X, Y or Z - and P is the point on it under the cursor. }
function AxisSnap(const V: TProjector; SX, SY, TolPx: Double;
  out P: TP3; out Axis: Integer): Boolean;

{ The six axis directions, and how they read on screen in the given view. }
function AxisDir(Index: Integer): TP3;
function AxisName(Index: Integer): string;

{ Lay out a dimension.  Off is a vector in the model, not a number of pixels:
  the dimension line is simply the measured edge shifted by it.  That is what
  lets it keep its distance as you zoom and stay where you put it as you
  orbit - a screen-space offset swings round the geometry instead.  False when
  the two points are too close together on screen to dimension. }
function DimGeometry(const V: TProjector; const A, B, Off: TP3;
  U: TUnitSystem; out G: TDimGeom; const Note: string = ''): Boolean;

{ Where the top-left of a dimension's text goes, given how big that text
  turned out to be.

  Pushing the text a fixed distance along the normal is not enough, because
  the point it lands on is the *middle* of the text: half the figure is still
  back over the line, and on an isometric - where the line runs at 30 degrees
  and the lettering does not - that half is exactly the half you are trying
  to read.  So the box has to be cleared rather than the centre moved: the
  run from the middle of a W x H box out to its edge along (nx, ny) is
  (|nx|W + |ny|H) / 2. }
function DimTextTopLeft(const G: TDimGeom; TW, TH: Integer;
  Gap: Double = 8): TPoint;

{ Where plFree lies: a point on it and the way it faces.  Set from the face
  under the cursor, read back by everything that draws in a plane. }
procedure SetFreePlane(const Org, Normal: TP3);
procedure GetFreePlane(out Org, U, V, N: TP3);
{ The two directions of a plane facing Nm, chosen the same way every time. }
procedure AxesFromNormal(const Nm: TP3; out AU, AV: TP3);
{ The two directions of one of the working planes. }
procedure PlaneAxes(Pl: TPlane; out AU, AV: TP3);

{ A point on a circle of radius R about C, at Ang radians, in plane Pl.  The
  second form is for a stored shape, which carries the way its plane faces
  rather than relying on whatever the working plane happens to be now. }
function ArcPoint(const C: TP3; R, Ang: Double; Pl: TPlane): TP3;
function ArcPoint(const C: TP3; R, Ang: Double; Pl: TPlane;
  const Nm: TP3): TP3;

{ Unit vectors of the view: screen right, screen up, and the direction the
  camera looks along (used to sort faces back to front). }
function ViewRight(const V: TProjector): TP3;
function ViewUp(const V: TProjector): TP3;
function ViewDir(const V: TProjector): TP3;

function Cross3(const A, B: TP3): TP3;
function Dot3(const A, B: TP3): Double; inline;
function Norm3(const A: TP3): TP3;

{ An equidistant copy of a closed loop, in the loop's own plane - the inside
  and outside lines of a duct wall, a flange, the wall of a vessel.

  Every edge is shifted sideways by D and the shifted edges are then extended
  until they meet again.  That is what keeps the corners sharp and the spacing
  exact: moving the corner *points* by D instead would pull every corner in by
  a factor of its angle, so a mitre would come out narrower than the sides.

  D is positive outward, and outward is worked out from the way the loop winds
  about Normal, so the caller does not have to know which way its own points
  go round.  Negative D offsets inward.

  A loop that eats itself is not cleaned up here, and does not need to be: the
  region engine splits every crossing and walks the cycles, so an offset that
  overshoots simply comes back as smaller regions. }
function OffsetLoop(const Loop: TP3Array; const Normal: TP3; D: Double): TP3Array;

{ The two in-plane coordinates of a model point. }
procedure PlaneCoords(Pl: TPlane; const P: TP3; out U, W: Double);

const
  ISO_COS = 0.86602540378443865;   // cos 30
  ISO_SIN = 0.5;                   // sin 30

implementation

const
  MM_PER_INCH = 25.4;
  { SketchUp's default front material, near enough.  Faces start here and
    take only a hint of the pen color. }
  FACE_MATERIAL: TPix = (B: $F6; G: $FA; R: $FA; A: 255);
  { The back of a face, in SketchUp's pale blue.  A face has a front and a
    back, and which you are looking at is not otherwise visible - so a solid
    built inside out looks perfectly ordinary until something behaves oddly
    much later.  Colouring the back is how that is caught on sight, and it is
    why their models read better than a drawing where every face is the same
    white. }
  FACE_BACK: TPix = (B: $DC; G: $C4; R: $A8; A: 255);
  { A guide point, in amber.  Deliberately placed and deliberately findable. }
  GUIDE_POINT: TPix = (B: $10; G: $B0; R: $F0; A: 255);
  { how finely a line lying on a face is chopped up when working out which
    stretches of it are hidden }
  LINE_STEPS = 32;

function UnitName(U: TUnitSystem): string;
begin
  if U = usImperial then Result := 'FEET' else Result := 'METRIC';
end;

function ScaleTable(U: TUnitSystem; I: Integer): TDrawScale;
begin
  I := EnsureRange(I, 0, SCALE_COUNT - 1);
  if U = usImperial then
    Result := IMPERIAL_SCALES[I]
  else
    Result := METRIC_SCALES[I];
end;

function SnapValue(U: TUnitSystem; I: Integer): Double;
begin
  I := EnsureRange(I, 0, SNAP_COUNT - 1);
  if U = usImperial then Result := IMPERIAL_SNAPS[I] else Result := METRIC_SNAPS[I];
end;

function SnapName(U: TUnitSystem; I: Integer): string;
begin
  I := EnsureRange(I, 0, SNAP_COUNT - 1);
  if U = usImperial then
    Result := IMPERIAL_SNAP_NAMES[I]
  else
    Result := METRIC_SNAP_NAMES[I];
end;

function PixelsPerUnit(U: TUnitSystem; const Sc: TDrawScale; DPI: Double): Double;
begin
  if U = usImperial then
    { Sc.Paper is paper inches per foot, DPI is pixels per paper inch }
    Result := Sc.Paper * DPI
  else
    { Sc.Paper is paper metres per metre }
    Result := Sc.Paper * (DPI / 0.0254);
  if Result < 0.5 then Result := 0.5;
end;

{ ---------------------------------------------------------------------- }
{ formatting                                                              }
{ ---------------------------------------------------------------------- }

{ How finely an imperial length is written down, and what the last field of
  a dashed entry counts in.

  One setting for both on purpose.  A drawing that prints sixteenths and
  accepts sixty-fourths would take a number and then show you a different
  one, which is the sort of thing you only notice after cutting.  SketchUp
  calls this Precision and uses it the same way - it governs how a length is
  written, never what the model holds, so typing finer than the display is
  allowed and the exact number survives. }
var
  GLenDenom: Integer = 16;

procedure SetLenDenom(D: Integer);
begin
  { powers of two up to a sixty-fourth, or hundredths for the shops that
    work that way }
  if D in [2, 4, 8, 16, 32, 64, 100] then GLenDenom := D;
end;

function LenDenom: Integer;
begin
  Result := GLenDenom;
end;

{ Reduce PARTS/LenDenom to the tidiest fraction, e.g. 8/16 -> 1/2. }
function FractionText(Parts: Integer): string;
var
  N, D: Integer;
begin
  N := Parts;
  D := GLenDenom;
  while (N > 0) and (N mod 2 = 0) and (D mod 2 = 0) do
  begin
    N := N div 2;
    D := D div 2;
  end;
  if N = 0 then
    Result := ''
  else
    Result := Format('%d/%d', [N, D]);
end;

function FormatLen(V: Double; U: TUnitSystem): string;
var
  Neg: Boolean;
  TotalSix, Ft, Inch, Six: Int64;
  Frac: string;
begin
  Neg := V < 0;
  V := Abs(V);

  if U = usMetric then
  begin
    if V < 1 then
      Result := Format('%.0f mm', [V * 1000])
    else
      Result := Format('%.3f m', [V]);
  end
  else
  begin
    { Rounded to whatever the drawing's precision is - a sixteenth unless
      somebody said otherwise.  The model keeps the exact number either way;
      this only decides how it is written down, which is what precision means
      in SketchUp too and is the reason you may type finer than you display. }
    TotalSix := Round(V * 12 * GLenDenom);
    Ft := TotalSix div (12 * GLenDenom);
    TotalSix := TotalSix - Ft * 12 * GLenDenom;
    Inch := TotalSix div GLenDenom;
    Six := TotalSix - Inch * GLenDenom;
    Frac := FractionText(Six);

    if Frac <> '' then
      Result := Format('%d''-%d %s"', [Ft, Inch, Frac])
    else
      Result := Format('%d''-%d"', [Ft, Inch]);
  end;

  if Neg then
    Result := '-' + Result;
end;

function FormatArea(V: Double; U: TUnitSystem): string;
begin
  if U = usMetric then
    Result := Format('%.2f m2', [V])
  else
    Result := Format('%.1f sq ft', [V]);
end;

{ ---------------------------------------------------------------------- }
{ parsing                                                                 }
{ ---------------------------------------------------------------------- }

{ Accepts a plain number, or a number with a fraction: 6, 6.5, 6 1/2, 6-1/2 }
function ParseMixed(S: string; out V: Double): Boolean;
var
  P, Q: Integer;
  Whole, Num, Den: Double;
  FracPart: string;
  FS: TFormatSettings;
begin
  Result := False;
  V := 0;
  S := Trim(S);
  if S = '' then Exit;
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';

  { split off a trailing fraction }
  FracPart := '';
  P := Pos('/', S);
  if P > 0 then
  begin
    Q := P - 1;
    while (Q > 0) and (S[Q] in ['0'..'9']) do Dec(Q);
    FracPart := Copy(S, Q + 1, MaxInt);
    S := Trim(Copy(S, 1, Q));
    while (S <> '') and (S[Length(S)] in [' ', '-']) do
      SetLength(S, Length(S) - 1);
  end;

  Whole := 0;
  if S <> '' then
    if not TryStrToFloat(S, Whole, FS) then Exit;

  if FracPart <> '' then
  begin
    P := Pos('/', FracPart);
    if not TryStrToFloat(Copy(FracPart, 1, P - 1), Num, FS) then Exit;
    if not TryStrToFloat(Copy(FracPart, P + 1, MaxInt), Den, FS) then Exit;
    if Den = 0 then Exit;
    Whole := Whole + Num / Den;
  end;

  V := Whole;
  Result := True;
end;

{ Turn what the user typed into a length in world units.

  Imperial:  12'6"   12' 6   12-6   12'   6"   150"   12   6 1/2"
             a bare number is feet; anything after a ' or ending in " is inches
  Metric:    3.5   3.5m   350cm   3500mm   (bare number is metres) }
function ParseLen(const S: string; U: TUnitSystem; out V: Double): Boolean;
var
  T, FtPart, InPart: string;
  Parts: array[0..2] of string;
  P, NDash: Integer;
  Neg: Boolean;
  A, B, C: Double;
begin
  Result := False;
  V := 0;
  T := Trim(S);
  if T = '' then Exit;

  if U = usMetric then
  begin
    T := LowerCase(T);
    if (Length(T) > 2) and (Copy(T, Length(T) - 1, 2) = 'mm') then
    begin
      if not ParseMixed(Copy(T, 1, Length(T) - 2), A) then Exit;
      V := A / 1000;
    end
    else if (Length(T) > 2) and (Copy(T, Length(T) - 1, 2) = 'cm') then
    begin
      if not ParseMixed(Copy(T, 1, Length(T) - 2), A) then Exit;
      V := A / 100;
    end
    else if (Length(T) > 1) and (T[Length(T)] = 'm') then
    begin
      if not ParseMixed(Copy(T, 1, Length(T) - 1), A) then Exit;
      V := A;
    end
    else
    begin
      if not ParseMixed(T, A) then Exit;
      V := A;
    end;
    Result := True;
    Exit;
  end;

  { imperial }
  if (T <> '') and (T[Length(T)] = '"') then
    SetLength(T, Length(T) - 1);
  T := Trim(T);
  if T = '' then Exit;

  P := Pos('''', T);
  if P > 0 then
  begin
    FtPart := Trim(Copy(T, 1, P - 1));
    InPart := Trim(Copy(T, P + 1, MaxInt));
    while (InPart <> '') and (InPart[1] = '-') do
      Delete(InPart, 1, 1);
    A := 0;
    B := 0;
    if (FtPart <> '') and not ParseMixed(FtPart, A) then Exit;
    if (InPart <> '') and not ParseMixed(InPart, B) then Exit;
    V := A + B / 12;
    Result := True;
    Exit;
  end;

  { it ended with a double-quote, so it was inches all along }
  if (Length(S) > 0) and (Trim(S)[Length(Trim(S))] = '"') then
  begin
    if not ParseMixed(T, A) then Exit;
    V := A / 12;
    Result := True;
    Exit;
  end;

  { Feet, inches and sixteenths: the way a truss drawing writes a length.

    6-8-15 is six foot eight and fifteen sixteenths; 0-8-8 is eight and a
    half inches, and that leading nought for the feet is how a truss sheet
    writes anything under a foot.  It comes off the component design software
    the shops run, and the reason it exists is the reason it is worth having
    here: every field is a whole number, there is no foot mark, inch mark or
    slash anywhere in it, and the whole thing goes in from the number pad
    with the minus key.

    Sixteenths unless the drawing's precision says otherwise, so the third
    field never needs a denominator written beside it.  A field at or above
    the denominator means the drawing is in some other fraction, and this
    reading would then be wrong - quietly wrong, by a hair, on a length
    somebody cuts metal from.  So it is refused rather than guessed at.

    Purely additional: 6-8-15 did not parse at all before, so nothing that
    already worked reads differently now. }
  if (Pos('/', T) = 0) and (Pos('''', T) = 0) then
  begin
    NDash := 0;
    Parts[0] := '';
    Parts[1] := '';
    Parts[2] := '';
    Neg := (T[1] = '-');
    for P := 1 + Ord(Neg) to Length(T) do
      if T[P] = '-' then
      begin
        Inc(NDash);
        if NDash > 2 then Break;
      end
      else
        Parts[NDash] := Parts[NDash] + T[P];

    if (NDash = 2) and (Parts[0] <> '') and (Parts[1] <> '') and
       (Parts[2] <> '') and ParseMixed(Parts[0], A) and
       ParseMixed(Parts[1], B) and ParseMixed(Parts[2], C) and
       (B >= 0) and (B < 12) and (C >= 0) and (C < GLenDenom) then
    begin
      V := Abs(A) + B / 12 + C / (GLenDenom * 12);
      if Neg then V := -V;
      Result := True;
      Exit;
    end;
  end;

  { "12-6" and "12 6" mean twelve foot six.

    A dash may carry a fraction after it - 6-8 1/2 is six foot eight and a
    half - because a dash says plainly where the feet stop.  A space cannot:
    "3 1/2" is three and a half feet, and splitting it at the space would
    make it three foot and half an inch.  So the slash only rules out the
    space form, which is the one that is ambiguous. }
  P := Pos('-', T);
  if P > 1 then
  begin
    if not ParseMixed(Copy(T, 1, P - 1), A) then Exit;
    if not ParseMixed(Copy(T, P + 1, MaxInt), B) then Exit;
    V := A + B / 12;
    Result := True;
    Exit;
  end;

  P := Pos(' ', T);
  if (P > 1) and (Pos('/', T) = 0) then
  begin
    if not ParseMixed(Copy(T, 1, P - 1), A) then Exit;
    if not ParseMixed(Copy(T, P + 1, MaxInt), B) then Exit;
    V := A + B / 12;
    Result := True;
    Exit;
  end;

  if not ParseMixed(T, A) then Exit;
  V := A;
  Result := True;
end;


function ParseTriple(const S: string; U: TUnitSystem;
  out X, Y, Z: Double): Integer;
var
  Body, Part: string;
  I, N: Integer;
  V: array[0..2] of Double;
begin
  X := 0; Y := 0; Z := 0;
  Result := 0;
  Body := Trim(S);
  if Length(Body) < 2 then Exit;
  if Body[1] in ['[', '<'] then Delete(Body, 1, 1);
  if (Body <> '') and (Body[Length(Body)] in [']', '>']) then
    Delete(Body, Length(Body), 1);

  N := 0;
  V[0] := 0; V[1] := 0; V[2] := 0;
  while (Body <> '') and (N < 3) do
  begin
    I := Pos(',', Body);
    if I = 0 then I := Pos(';', Body);
    if I = 0 then
    begin
      Part := Body;
      Body := '';
    end
    else
    begin
      Part := Copy(Body, 1, I - 1);
      Delete(Body, 1, I);
    end;
    Part := Trim(Part);
    if Part = '' then
      Inc(N)                           // an empty field leaves that axis alone
    else if ParseLen(Part, U, V[N]) then
      Inc(N)
    else
      Exit;                            // a field we cannot read spoils the lot
  end;
  X := V[0]; Y := V[1]; Z := V[2];
  Result := N;
end;

function NiceBarLength(Ppu: Double; MinPx, MaxPx: Double; U: TUnitSystem): Double;
const
  IMP: array[0..8] of Double = (0.5, 1, 2, 5, 10, 20, 50, 100, 200);
  MET: array[0..8] of Double = (0.1, 0.25, 0.5, 1, 2, 5, 10, 20, 50);
var
  I: Integer;
  V: Double;
begin
  Result := 1;
  for I := 0 to 8 do
  begin
    if U = usImperial then V := IMP[I] else V := MET[I];
    Result := V;
    if V * Ppu >= MinPx then
    begin
      if V * Ppu <= MaxPx then Exit;
      Exit;
    end;
  end;
end;

{ ---------------------------------------------------------------------- }
{ geometry and projection                                                  }
{ ---------------------------------------------------------------------- }

function P3(X, Y, Z: Double): TP3;
begin
  Result.X := X;
  Result.Y := Y;
  Result.Z := Z;
end;

function Dist(const A, B: TP3): Double;
begin
  Result := Sqrt(Sqr(B.X - A.X) + Sqr(B.Y - A.Y) + Sqr(B.Z - A.Z));
end;

function SamePt(const A, B: TP3; Tol: Double): Boolean;
begin
  Result := Dist(A, B) <= Tol;
end;

function Cross3(const A, B: TP3): TP3;
begin
  Result.X := A.Y * B.Z - A.Z * B.Y;
  Result.Y := A.Z * B.X - A.X * B.Z;
  Result.Z := A.X * B.Y - A.Y * B.X;
end;

function Dot3(const A, B: TP3): Double;
begin
  Result := A.X * B.X + A.Y * B.Y + A.Z * B.Z;
end;

function Norm3(const A: TP3): TP3;
var
  L: Double;
begin
  L := Sqrt(A.X * A.X + A.Y * A.Y + A.Z * A.Z);
  if L < 1E-12 then
    Result := P3(0, 0, 1)
  else
    Result := P3(A.X / L, A.Y / L, A.Z / L);
end;

{ A turntable camera: Az spins about the world Z axis, El tilts up from the
  horizon.  Z is up in the model, which is what push/pull assumes. }
function ViewRight(const V: TProjector): TP3;
begin
  case V.Kind of
    vkOrbit: Result := P3(-Sin(V.Az), Cos(V.Az), 0);
    vkIso:   Result := P3(ISO_COS, ISO_COS, 0);
  else
    Result := P3(1, 0, 0);
  end;
end;

function ViewUp(const V: TProjector): TP3;
begin
  case V.Kind of
    vkOrbit: Result := P3(-Sin(V.El) * Cos(V.Az), -Sin(V.El) * Sin(V.Az), Cos(V.El));
    vkIso:   Result := P3(-ISO_SIN, ISO_SIN, 1);
  else
    Result := P3(0, 1, 0);
  end;
end;

{ The direction out of the screen, toward the viewer.  For the drafting
  isometric this follows from the projection itself: right x up works out to
  (1,-1,1) - the same corner the free camera starts on, and the same corner
  SketchUp opens a new document on. }
function ViewDir(const V: TProjector): TP3;
begin
  case V.Kind of
    vkOrbit: Result := P3(Cos(V.El) * Cos(V.Az), Cos(V.El) * Sin(V.Az), Sin(V.El));
    vkIso:   Result := Norm3(P3(1, -1, 1));
  else
    Result := P3(0, 0, 1);
  end;
end;

{ PLAN looks straight down the Z axis.  ISO is the standard 30 degree
  isometric seen from the same corner as the free camera: +X runs down-right
  toward you, +Y up-right away from you, +Z straight up.

  It used to be taken from the opposite corner, with both ground axes rising
  from the origin.  That is the layout a pipe spool sheet uses and it was not
  wrong, but it left ISO ninety degrees round from our own 3D view - so
  flipping between two views of the same model spun the model, and anything
  said about which way red or green ran was only true in one of them.  They
  are one document seen three ways; they had better agree about which way is
  which. }
function Project(const V: TProjector; const P: TP3): TPointF;
var
  R, U: TP3;
begin
  if V.Kind = vkOrbit then
  begin
    R := ViewRight(V);
    U := ViewUp(V);
    Result.X := V.OX + Dot3(P, R) * V.Ppu;
    Result.Y := V.OY - Dot3(P, U) * V.Ppu;
    Exit;
  end;
  if V.Kind = vkIso then
  begin
    Result.X := V.OX + (P.X + P.Y) * ISO_COS * V.Ppu;
    Result.Y := V.OY - ((P.Y - P.X) * ISO_SIN + P.Z) * V.Ppu;
  end
  else
  begin
    Result.X := V.OX + P.X * V.Ppu;
    Result.Y := V.OY - P.Y * V.Ppu;
  end;
end;

{ Two screen equations, three unknowns, so the working plane pins one of
  them; the remaining 2x2 system is solved directly. }
procedure UnprojectOrbit(const V: TProjector; SX, SY: Double; Pl: TPlane;
  const Base: TP3; out Res: TP3);
var
  R, U: TP3;
  A11, A12, A21, A22, B1, B2, Det, S, T, Scale: Double;
begin
  Res := Base;
  R := ViewRight(V);
  U := ViewUp(V);
  B1 := (SX - V.OX) / V.Ppu;
  B2 := (V.OY - SY) / V.Ppu;

  case Pl of
    plXY:
      begin
        A11 := R.X; A12 := R.Y; B1 := B1 - R.Z * Base.Z;
        A21 := U.X; A22 := U.Y; B2 := B2 - U.Z * Base.Z;
      end;
    plXZ:
      begin
        A11 := R.X; A12 := R.Z; B1 := B1 - R.Y * Base.Y;
        A21 := U.X; A22 := U.Z; B2 := B2 - U.Y * Base.Y;
      end;
  else
    begin
      A11 := R.Y; A12 := R.Z; B1 := B1 - R.X * Base.X;
      A21 := U.Y; A22 := U.Z; B2 := B2 - U.X * Base.X;
    end;
  end;

  { How nearly edge-on is too nearly edge-on?

    The old test was against a fixed 1E-9, which only ever catches a camera
    exactly in the plane.  A degree off exactly is not exact, but it is still
    hopeless: the answer then comes out a billion feet away, which is worse
    than no answer because it looks like one.

    So the determinant is judged against the size of the matrix it came from.
    Below a thousandth of that, the two directions are for practical purposes
    the same direction, there is no honest crossing point, and Base - the
    point we were told to fall back to - stands. }
  Det := A11 * A22 - A12 * A21;
  Scale := Max(Abs(A11), Max(Abs(A12), Max(Abs(A21), Abs(A22))));
  if Abs(Det) < 1E-3 * Max(Scale * Scale, 1E-12) then Exit;
  S := (B1 * A22 - A12 * B2) / Det;
  T := (A11 * B2 - B1 * A21) / Det;

  case Pl of
    plXY: begin Res.X := S; Res.Y := T; end;
    plXZ: begin Res.X := S; Res.Z := T; end;
  else
    begin Res.Y := S; Res.Z := T; end;
  end;
end;

{ The free plane.  Held here rather than passed about, because TPlane goes
  through a dozen calls by value and every one of them would have had to grow
  three more arguments to carry a plane there is only ever one of. }
var
  GFreeOrg: TP3 = (X: 0; Y: 0; Z: 0);
  GFreeN: TP3 = (X: 0; Y: 0; Z: 1);
  GFreeU: TP3 = (X: 1; Y: 0; Z: 0);
  GFreeV: TP3 = (X: 0; Y: 1; Z: 0);

{ Where the cursor meets an arbitrary plane, for any view.

  The three flat planes each get their own arithmetic above, which is quick
  and unreadable and only works because one coordinate is known in advance.
  A sloped face knows none of them, so this does it the general way: the
  projection is linear, whatever the view, so measuring where the origin and
  the three unit vectors land on screen gives the two rows of it.  Add the
  plane itself as a third equation and there are three equations in three
  unknowns.

  Slower than the special cases, and it runs once per mouse move. }
function UnprojectPlane(const V: TProjector; SX, SY: Double;
  const Org, N: TP3; const Base: TP3): TP3;
var
  P0, PX, PY, PZ: TPointF;
  A: array[0..2, 0..2] of Double;
  B: array[0..2] of Double;
  Det, D0, D1, D2, Scale, R0, R1, R2: Double;
begin
  Result := Base;
  P0 := Project(V, P3(0, 0, 0));
  PX := Project(V, P3(1, 0, 0));
  PY := Project(V, P3(0, 1, 0));
  PZ := Project(V, P3(0, 0, 1));

  A[0, 0] := PX.X - P0.X;  A[0, 1] := PY.X - P0.X;  A[0, 2] := PZ.X - P0.X;
  A[1, 0] := PX.Y - P0.Y;  A[1, 1] := PY.Y - P0.Y;  A[1, 2] := PZ.Y - P0.Y;
  A[2, 0] := N.X;          A[2, 1] := N.Y;          A[2, 2] := N.Z;

  B[0] := SX - P0.X;
  B[1] := SY - P0.Y;
  B[2] := N.X * Org.X + N.Y * Org.Y + N.Z * Org.Z;

  Det := A[0,0] * (A[1,1] * A[2,2] - A[1,2] * A[2,1])
       - A[0,1] * (A[1,0] * A[2,2] - A[1,2] * A[2,0])
       + A[0,2] * (A[1,0] * A[2,1] - A[1,1] * A[2,0]);

  { Edge-on to the camera there is no crossing worth having - the same
    judgement the orbit unproject makes, and for the same reason.

    Judged against all three rows, not one of them.  The first two are in
    pixels per foot and the third is a unit normal, so measuring a
    three-row determinant against the first row squared compares it with
    something a thousand times too big and lets through a solve that is
    hopeless.  That is what made a circle on a roof leap to an absurd size
    from a pixel of movement, and leap worse the more the roof leaned away:
    the answer was the plane running off towards the horizon, faithfully
    computed. }
  R0 := Sqrt(Sqr(A[0,0]) + Sqr(A[0,1]) + Sqr(A[0,2]));
  R1 := Sqrt(Sqr(A[1,0]) + Sqr(A[1,1]) + Sqr(A[1,2]));
  R2 := Sqrt(Sqr(A[2,0]) + Sqr(A[2,1]) + Sqr(A[2,2]));
  Scale := R0 * R1 * R2;
  if (Scale < 1E-12) or (Abs(Det) < 1E-3 * Scale) then Exit;

  D0 := B[0]    * (A[1,1] * A[2,2] - A[1,2] * A[2,1])
      - A[0,1]  * (B[1]   * A[2,2] - A[1,2] * B[2])
      + A[0,2]  * (B[1]   * A[2,1] - A[1,1] * B[2]);
  D1 := A[0,0]  * (B[1]   * A[2,2] - A[1,2] * B[2])
      - B[0]    * (A[1,0] * A[2,2] - A[1,2] * A[2,0])
      + A[0,2]  * (A[1,0] * B[2]   - B[1]   * A[2,0]);
  D2 := A[0,0]  * (A[1,1] * B[2]   - B[1]   * A[2,1])
      - A[0,1]  * (A[1,0] * B[2]   - B[1]   * A[2,0])
      + B[0]    * (A[1,0] * A[2,1] - A[1,1] * A[2,0]);

  Result := P3(D0 / Det, D1 / Det, D2 / Det);
end;

function Unproject(const V: TProjector; SX, SY: Double; Pl: TPlane;
  const Base: TP3): TP3;
var
  U, W: Double;
begin
  Result := Base;
  if Pl = plFree then
    Exit(UnprojectPlane(V, SX, SY, GFreeOrg, GFreeN, Base));
  if V.Kind = vkPlan then
  begin
    Result.X := (SX - V.OX) / V.Ppu;
    Result.Y := (V.OY - SY) / V.Ppu;
    Exit;
  end;

  if V.Kind = vkOrbit then
  begin
    UnprojectOrbit(V, SX, SY, Pl, Base, Result);
    Exit;
  end;

  { ISO.  Two screen equations, so one of the three model axes has to be
    pinned - that is what the working plane is for. }
  U := (SX - V.OX) / (V.Ppu * ISO_COS);          // = X + Y
  W := (V.OY - SY) / V.Ppu;                      // = (Y-X)*sin + Z

  case Pl of
    plXY:
      begin
        Result.Z := Base.Z;
        Result.Y := (U + (W - Base.Z) / ISO_SIN) / 2;
        Result.X := (U - (W - Base.Z) / ISO_SIN) / 2;
      end;
    plXZ:
      begin
        Result.Y := Base.Y;
        Result.X := U - Base.Y;
        Result.Z := W - (Base.Y - Result.X) * ISO_SIN;
      end;
  else
    begin
      Result.X := Base.X;
      Result.Y := U - Base.X;
      Result.Z := W - (Result.Y - Base.X) * ISO_SIN;
    end;
  end;
end;

function PlaneByDrag(const V: TProjector; const Anchor: TP3;
  SX, SY: Double; Keep: TPlane; Bias: Double): TPlane;
var
  Pl: TPlane;
  D, Best: Double;
begin
  Result := Keep;
  Best := Dist(Anchor, Unproject(V, SX, SY, Keep, Anchor));
  { A plan view pins Z on its own and ignores the plane entirely, so every
    candidate answers the same and Keep stands - which is right there. }
  if not (Best > 0) or (Best > 1E12) then Exit;
  for Pl := Low(TPlane) to High(TPlane) do
  begin
    if Pl = Keep then Continue;
    D := Dist(Anchor, Unproject(V, SX, SY, Pl, Anchor));
    if not (D > 0) or (D > 1E12) then Continue;   // edge-on: no opinion
    if D < Best * Bias then
    begin
      Best := D;
      Result := Pl;
    end;
  end;
end;

function AxisDir(Index: Integer): TP3;
begin
  case Index of
    0: Result := P3(1, 0, 0);
    1: Result := P3(-1, 0, 0);
    2: Result := P3(0, 1, 0);
    3: Result := P3(0, -1, 0);
    4: Result := P3(0, 0, 1);
  else
    Result := P3(0, 0, -1);
  end;
end;

{ SketchUp talks about the axes by color, and so does everything on screen
  here, so a locked direction says the color rather than a sign.  A lock runs
  both ways along its axis; which way is the cursor's business. }
function DimGeometry(const V: TProjector; const A, B, Off: TP3;
  U: TUnitSystem; out G: TDimGeom; const Note: string): Boolean;
var
  PA, PB: TPointF;
  L, UX, UY, NX, NY, OL: Double;
begin
  Result := False;
  FillChar(G, SizeOf(G), 0);
  PA := Project(V, A);
  PB := Project(V, B);
  L := Sqrt(Sqr(PB.X - PA.X) + Sqr(PB.Y - PA.Y));
  if L < 14 then Exit;
  UX := (PB.X - PA.X) / L;
  UY := (PB.Y - PA.Y) / L;

  { the line, shifted bodily by the offset - everything else hangs off it }
  G.LA := Project(V, P3(A.X + Off.X, A.Y + Off.Y, A.Z + Off.Z));
  G.LB := Project(V, P3(B.X + Off.X, B.Y + Off.Y, B.Z + Off.Z));

  { which way the offset went on screen, so the ticks and the text can lean
    away from the geometry rather than into it }
  NX := G.LA.X - PA.X;
  NY := G.LA.Y - PA.Y;
  OL := Sqrt(NX * NX + NY * NY);
  if OL < 1E-6 then
  begin
    NX := -UY;
    NY := UX;
  end
  else
  begin
    NX := NX / OL;
    NY := NY / OL;
  end;

  { the witness lines stand off the geometry a little and run just past the
    dimension line, which is what makes a drawing readable }
  G.A := PtF(PA.X + NX * 4, PA.Y + NY * 4);
  G.B := PtF(PB.X + NX * 4, PB.Y + NY * 4);
  G.W1 := PtF(G.LA.X + NX * 5, G.LA.Y + NY * 5);
  G.W2 := PtF(G.LB.X + NX * 5, G.LB.Y + NY * 5);
  G.S1A := PtF(G.LA.X - UX * 4 - NX * 4, G.LA.Y - UY * 4 - NY * 4);
  G.S1B := PtF(G.LA.X + UX * 4 + NX * 4, G.LA.Y + UY * 4 + NY * 4);
  G.S2A := PtF(G.LB.X - UX * 4 - NX * 4, G.LB.Y - UY * 4 - NY * 4);
  G.S2B := PtF(G.LB.X + UX * 4 + NX * 4, G.LB.Y + UY * 4 + NY * 4);
  G.Mid := PtF((G.LA.X + G.LB.X) / 2, (G.LA.Y + G.LB.Y) / 2);
  G.Nrm := PtF(NX, NY);
  { A written-over label wins.  A dimension on a fabrication drawing often
    has to say something the geometry does not - a nominal size, a cut length
    allowing for a fitting, "FIELD VERIFY" - and on an isometric, which is not
    to scale in the first place, the written figure *is* the drawing. }
  if Note <> '' then G.Txt := Note
  else G.Txt := FormatLen(Dist(A, B), U);
  Result := True;
end;

function DimTextTopLeft(const G: TDimGeom; TW, TH: Integer;
  Gap: Double): TPoint;
var
  Reach, CX, CY: Double;
begin
  Reach := (Abs(G.Nrm.X) * TW + Abs(G.Nrm.Y) * TH) / 2;
  CX := G.Mid.X + G.Nrm.X * (Gap + Reach);
  CY := G.Mid.Y + G.Nrm.Y * (Gap + Reach);
  Result.X := Round(CX - TW / 2);
  Result.Y := Round(CY - TH / 2);
end;

function AxisName(Index: Integer): string;
begin
  case Index of
    0, 1: Result := 'red X';
    2, 3: Result := 'green Y';
  else
    Result := 'blue Z';
  end;
end;

{ The two directions of a plane that faces Nm, chosen the same way every
  time so a shape does not twist as the cursor moves. }
procedure AxesFromNormal(const Nm: TP3; out AU, AV: TP3);
var
  N, T: TP3;
  L: Double;
begin
  L := Sqrt(Sqr(Nm.X) + Sqr(Nm.Y) + Sqr(Nm.Z));
  if L < 1E-12 then
  begin
    AU := P3(1, 0, 0);
    AV := P3(0, 1, 0);
    Exit;
  end;
  N := P3(Nm.X / L, Nm.Y / L, Nm.Z / L);
  if (Abs(N.Z) <= Abs(N.X)) and (Abs(N.Z) <= Abs(N.Y)) then T := P3(0, 0, 1)
  else if Abs(N.Y) <= Abs(N.X) then T := P3(0, 1, 0)
  else T := P3(1, 0, 0);
  AU := Norm3(Cross3(T, N));
  AV := Norm3(Cross3(N, AU));
end;

procedure SetFreePlane(const Org, Normal: TP3);
var
  L: Double;
begin
  L := Sqrt(Sqr(Normal.X) + Sqr(Normal.Y) + Sqr(Normal.Z));
  if L < 1E-12 then Exit;
  GFreeOrg := Org;
  GFreeN := P3(Normal.X / L, Normal.Y / L, Normal.Z / L);
  { Any two directions in the plane would do, but they must not wander as the
    cursor moves or a rectangle would twist while it was being dragged.
    Taking the world axis least like the normal gives the same pair every
    time for a given face. }
  AxesFromNormal(GFreeN, GFreeU, GFreeV);
end;

procedure GetFreePlane(out Org, U, V, N: TP3);
begin
  Org := GFreeOrg;
  U := GFreeU;
  V := GFreeV;
  N := GFreeN;
end;

{ In-plane coordinates for an arc: (u, v) are the two axes of Pl. }
procedure PlaneAxes(Pl: TPlane; out AU, AV: TP3);
begin
  case Pl of
    plXY: begin AU := P3(1, 0, 0); AV := P3(0, 1, 0); end;
    plXZ: begin AU := P3(1, 0, 0); AV := P3(0, 0, 1); end;
    plFree: begin AU := GFreeU; AV := GFreeV; end;
  else
    begin AU := P3(0, 1, 0); AV := P3(0, 0, 1); end;
  end;
end;

function OffsetLoop(const Loop: TP3Array; const Normal: TP3; D: Double): TP3Array;
const
  EPS = 1E-9;
var
  N, Ax, Bx: TP3;
  Cnt, I, J, K: Integer;
  PU, PV: array of Double;         // the loop, in plane coordinates
  DU, DV: array of Double;         // each edge's unit direction
  NU, NV: array of Double;         // each edge's outward normal
  RU, RV: array of Double;         // the answer, in plane coordinates
  Area, L, Cr, T, Sgn, AU, AV, Lift: Double;
begin
  Result := nil;
  Cnt := Length(Loop);
  if Cnt < 3 then Exit;

  N := Norm3(Normal);
  Lift := Dot3(Loop[0], N);

  { Any two perpendicular directions in the plane will do.  Start from
    whichever axis the normal leans on least, so the cross product is never
    taken between two nearly parallel vectors. }
  if (Abs(N.X) <= Abs(N.Y)) and (Abs(N.X) <= Abs(N.Z)) then
    Ax := P3(1, 0, 0)
  else if Abs(N.Y) <= Abs(N.Z) then
    Ax := P3(0, 1, 0)
  else
    Ax := P3(0, 0, 1);
  Ax := Norm3(Cross3(N, Ax));
  Bx := Norm3(Cross3(N, Ax));

  SetLength(PU, Cnt); SetLength(PV, Cnt);
  for I := 0 to Cnt - 1 do
  begin
    PU[I] := Dot3(Loop[I], Ax);
    PV[I] := Dot3(Loop[I], Bx);
  end;

  { Which way round does it go?  The shoelace area in plane coordinates says
    so, and that is what fixes the meaning of "outward". }
  Area := 0;
  for I := 0 to Cnt - 1 do
  begin
    J := (I + 1) mod Cnt;
    Area := Area + (PU[I] * PV[J] - PU[J] * PV[I]);
  end;
  if Abs(Area) < EPS then Exit;
  if Area > 0 then Sgn := 1 else Sgn := -1;

  SetLength(DU, Cnt); SetLength(DV, Cnt);
  SetLength(NU, Cnt); SetLength(NV, Cnt);
  for I := 0 to Cnt - 1 do
  begin
    J := (I + 1) mod Cnt;
    DU[I] := PU[J] - PU[I];
    DV[I] := PV[J] - PV[I];
    L := Sqrt(DU[I] * DU[I] + DV[I] * DV[I]);
    if L < EPS then
    begin
      { a repeated point: the edge has no direction, so leave it flat and let
        its neighbours span the gap }
      DU[I] := 0; DV[I] := 0; NU[I] := 0; NV[I] := 0;
      Continue;
    end;
    DU[I] := DU[I] / L;
    DV[I] := DV[I] / L;
    { to the right of the way it is going, for a loop wound the positive way }
    NU[I] := DV[I] * Sgn;
    NV[I] := -DU[I] * Sgn;
  end;

  SetLength(Result, Cnt);
  SetLength(RU, Cnt); SetLength(RV, Cnt);
  for I := 0 to Cnt - 1 do
  begin
    { corner I is where the offset of edge I-1 meets the offset of edge I }
    K := (I + Cnt - 1) mod Cnt;
    Cr := DU[K] * DV[I] - DV[K] * DU[I];
    if Abs(Cr) < 1E-7 then
    begin
      { the two edges run the same way, so there is no corner to sharpen -
        step straight out along the normal }
      AU := PU[I] + NU[I] * D;
      AV := PV[I] + NV[I] * D;
    end
    else
    begin
      AU := (PU[I] + NU[I] * D) - (PU[K] + NU[K] * D);
      AV := (PV[I] + NV[I] * D) - (PV[K] + NV[K] * D);
      T := (AU * DV[I] - AV * DU[I]) / Cr;
      AU := PU[K] + NU[K] * D + DU[K] * T;
      AV := PV[K] + NV[K] * D + DV[K] * T;
    end;
    { Back into the model, and out to the plane the loop is actually on.

      Ax and Bx span the plane through the origin parallel to the face, and
      a corner rebuilt from them alone lands on that one.  A face on the
      ground is that plane, so an offset there always came out where it should;
      the top of a four foot box is the same plane four feet up, and its
      offset came back on the ground - the side of the box at x = 6 got its
      offset at x = 0.  A mile away, when the face is a long way from the
      origin.  The plane's own height along its normal is the missing part,
      and it is the same for every corner. }
    Result[I] := P3(Ax.X * AU + Bx.X * AV + N.X * Lift,
                    Ax.Y * AU + Bx.Y * AV + N.Y * Lift,
                    Ax.Z * AU + Bx.Z * AV + N.Z * Lift);
    { kept apart from PU/PV, which the next corner still needs to read }
    RU[I] := AU;
    RV[I] := AV;
  end;

  { An offset inward that goes further than the shape can take turns it
    inside out - a 10 x 6 box taken in by 4 comes back as a line, and by 5 as
    a box wound the other way.  Neither is an offset of anything, so say so
    by returning nothing rather than laying down a sliver that looks like
    geometry and measures wrong. }
  T := 0;
  for I := 0 to Cnt - 1 do
  begin
    J := (I + 1) mod Cnt;
    T := T + (RU[I] * RV[J] - RU[J] * RV[I]);
  end;
  if (T * Area <= 0) or (Abs(T) < Abs(Area) * 1E-6) then Result := nil;
end;

procedure PlaneCoords(Pl: TPlane; const P: TP3; out U, W: Double);
var
  AU, AV: TP3;
begin
  PlaneAxes(Pl, AU, AV);
  U := P.X * AU.X + P.Y * AU.Y + P.Z * AU.Z;
  W := P.X * AV.X + P.Y * AV.Y + P.Z * AV.Z;
end;

function ArcPoint(const C: TP3; R, Ang: Double; Pl: TPlane;
  const Nm: TP3): TP3;
var
  AU, AV: TP3;
begin
  if Pl = plFree then
    AxesFromNormal(Nm, AU, AV)
  else
    PlaneAxes(Pl, AU, AV);
  Result := P3(C.X + (AU.X * Cos(Ang) + AV.X * Sin(Ang)) * R,
               C.Y + (AU.Y * Cos(Ang) + AV.Y * Sin(Ang)) * R,
               C.Z + (AU.Z * Cos(Ang) + AV.Z * Sin(Ang)) * R);
end;

function ArcPoint(const C: TP3; R, Ang: Double; Pl: TPlane): TP3;
var
  AU, AV: TP3;
  Cs, Sn: Double;
begin
  PlaneAxes(Pl, AU, AV);
  Cs := Cos(Ang) * R;
  Sn := Sin(Ang) * R;
  Result.X := C.X + AU.X * Cs + AV.X * Sn;
  Result.Y := C.Y + AU.Y * Cs + AV.Y * Sn;
  Result.Z := C.Z + AU.Z * Cs + AV.Z * Sn;
end;

function ArcSteps(const E: TWorkEnt): Integer;
begin
  if E.Sides >= 3 then Result := E.Sides else Result := 48;
end;

function ParseSides(const S: string; out N: Integer): Boolean;
var
  T: string;
begin
  Result := False;
  N := 0;
  T := LowerCase(Trim(S));
  if Length(T) < 2 then Exit;
  if T[Length(T)] = 's' then Delete(T, Length(T), 1)
  else if T[1] = 's' then Delete(T, 1, 1)
  else Exit;
  if (T = '') or not TryStrToInt(T, N) then Exit;
  Result := (N >= 3) and (N <= 360);
end;

function ParseAngle(const S: string; out Deg: Double): Boolean;
var
  T: string;
  P: Integer;
  Rise, Run: Double;
  FS: TFormatSettings;
begin
  Result := False;
  Deg := 0;
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  T := Trim(S);
  if T = '' then Exit;
  { 8:12 - a slope, rise over run, which is how a roof pitch or a duct
    offset is written on the job }
  P := Pos(':', T);
  if P > 0 then
  begin
    if not TryStrToFloat(Trim(Copy(T, 1, P - 1)), Rise, FS) then Exit;
    if not TryStrToFloat(Trim(Copy(T, P + 1, MaxInt)), Run, FS) then Exit;
    if Abs(Run) < 1E-12 then Exit;
    Deg := RadToDeg(ArcTan2(Rise, Abs(Run)));
    if Run < 0 then Deg := -Deg;
    Exit(True);
  end;
  { a degree sign or a d after the number is allowed and ignored }
  if (Length(T) >= 2) and (Copy(T, Length(T) - 1, 2) = #$C2#$B0) then
    T := Trim(Copy(T, 1, Length(T) - 2))
  else if (T <> '') and (T[Length(T)] in ['d', 'D']) then
    T := Trim(Copy(T, 1, Length(T) - 1));
  Result := TryStrToFloat(T, Deg, FS);
end;

function FormatAngle(Deg: Double): string;
var
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  if Abs(Deg - Round(Deg)) < 0.005 then
    Result := IntToStr(Round(Deg)) + #$C2#$B0
  else
    Result := FormatFloat('0.0', Deg, FS) + #$C2#$B0;
end;

function RotV(const V, Axis: TP3; Ang: Double): TP3;
var
  K: TP3;
  Cs, Sn, D: Double;
begin
  { Rodrigues: V cos + (K x V) sin + K (K.V)(1 - cos) }
  K := Norm3(Axis);
  Cs := Cos(Ang);
  Sn := Sin(Ang);
  D := Dot3(K, V) * (1 - Cs);
  Result := P3(V.X * Cs + (K.Y * V.Z - K.Z * V.Y) * Sn + K.X * D,
               V.Y * Cs + (K.Z * V.X - K.X * V.Z) * Sn + K.Y * D,
               V.Z * Cs + (K.X * V.Y - K.Y * V.X) * Sn + K.Z * D);
end;

function RotP(const P, C, Axis: TP3; Ang: Double): TP3;
var
  V: TP3;
begin
  V := RotV(P3(P.X - C.X, P.Y - C.Y, P.Z - C.Z), Axis, Ang);
  Result := P3(C.X + V.X, C.Y + V.Y, C.Z + V.Z);
end;

function ArcFromChord(const A, B: TP3; Bulge: Double; Pl: TPlane;
  out C: TP3; out R, A0, Sweep: Double): Boolean;
var
  AU, AV, Nm: TP3;
  AUx, AUy, BUx, BUy, Ch, H, NX, NY, MX, MY, D, AngA, AngB: Double;

  procedure ToPlane(const P: TP3; out U, W: Double);
  begin
    U := P.X * AU.X + P.Y * AU.Y + P.Z * AU.Z;
    W := P.X * AV.X + P.Y * AV.Y + P.Z * AV.Z;
  end;

begin
  Result := False;
  C := A;
  R := 0;
  A0 := 0;
  Sweep := 0;
  PlaneAxes(Pl, AU, AV);
  ToPlane(A, AUx, AUy);
  ToPlane(B, BUx, BUy);

  Ch := Sqrt(Sqr(BUx - AUx) + Sqr(BUy - AUy));
  H := Bulge;
  if (Ch < 1E-9) or (Abs(H) < 1E-9) then Exit;

  NX := -(BUy - AUy) / Ch;
  NY := (BUx - AUx) / Ch;
  MX := (AUx + BUx) / 2;
  MY := (AUy + BUy) / 2;

  R := (Sqr(Ch / 2) + Sqr(H)) / (2 * Abs(H));
  D := R - Abs(H);
  if H >= 0 then
  begin
    MX := MX - NX * D;
    MY := MY - NY * D;
  end
  else
  begin
    MX := MX + NX * D;
    MY := MY + NY * D;
  end;

  { Back out of the plane into model space.

    The two in-plane axes put the centre on a plane through the origin, so it
    has to be moved out to the one the chord is actually on - which is what
    the third coordinate did for the axis-square planes: pin Z for a flat
    one, Y for XZ, X for YZ.

    Said once instead of three times, because there is a fourth.  A free
    plane - a roof, the sloping side of a transition - has no third
    coordinate to pin, and it was falling through the case with none of them
    applied: the centre came out on a plane through the origin parallel to
    the one the arc was drawn on, so an arc on a slope had its middle
    somewhere under the ground.  Sliding along the normal by however far the
    chord is along it is the same answer for all four, and it cannot miss one
    out. }
  Nm := Norm3(Cross3(AU, AV));
  D := Dot3(A, Nm);
  C.X := AU.X * MX + AV.X * MY + Nm.X * D;
  C.Y := AU.Y * MX + AV.Y * MY + Nm.Y * D;
  C.Z := AU.Z * MX + AV.Z * MY + Nm.Z * D;

  AngA := ArcTan2(AUy - MY, AUx - MX);
  AngB := ArcTan2(BUy - MY, BUx - MX);
  A0 := AngA;
  Sweep := AngB - AngA;
  while Sweep <= -Pi do Sweep := Sweep + 2 * Pi;
  while Sweep > Pi do Sweep := Sweep - 2 * Pi;
  if Abs(H) > Ch / 2 then
    if Sweep > 0 then Sweep := Sweep - 2 * Pi else Sweep := Sweep + 2 * Pi;
  if ((H > 0) and (Sweep > 0)) or ((H < 0) and (Sweep < 0)) then
    if Sweep > 0 then Sweep := Sweep - 2 * Pi else Sweep := Sweep + 2 * Pi;

  Result := True;
end;

{ Straight-line distance from a point to a segment.  Not squared, whatever
  the old name suggested - taking Sqrt of this turned a 9 pixel pick radius
  into 81. }
function DistToSeg(PX, PY, AX, AY, BX, BY: Double): Double;
var
  DX, DY, T, L2: Double;
begin
  DX := BX - AX;
  DY := BY - AY;
  L2 := DX * DX + DY * DY;
  if L2 < 1E-12 then
    Exit(Sqrt(Sqr(PX - AX) + Sqr(PY - AY)));
  T := EnsureRange(((PX - AX) * DX + (PY - AY) * DY) / L2, 0, 1);
  Result := Sqrt(Sqr(PX - (AX + DX * T)) + Sqr(PY - (AY + DY * T)));
end;

{ ---------------------------------------------------------------------- }
{ TWorkDoc                                                                }
{ ---------------------------------------------------------------------- }

function TWorkDoc.GetEnt(I: Integer): TWorkEnt;
begin
  Result := FEnts[I];
end;

function TWorkDoc.Stored: Integer;
begin
  Result := Length(FEnts);
end;

{ Anything in redo space is dropped the moment you draw again. }
function TWorkDoc.HasLine(const A, B: TP3): Boolean;
const
  TOL = 1E-7;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to FLive - 1 do
    if FEnts[I].Kind = ekLine then
      if ((Dist(FEnts[I].A, A) < TOL) and (Dist(FEnts[I].B, B) < TOL)) or
         ((Dist(FEnts[I].A, B) < TOL) and (Dist(FEnts[I].B, A) < TOL)) then
        Exit;
  Result := False;
end;

procedure TWorkDoc.AddLine(const A, B: TP3; Ink: TColor; Weight: Single;
  Dim: Boolean);
begin
  SetLength(FEnts, FLive + 1);
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FEnts[FLive].Kind := ekLine;
  FEnts[FLive].A := A;
  FEnts[FLive].B := B;
  FEnts[FLive].Ink := Ink;
  FEnts[FLive].Weight := Weight;
  FEnts[FLive].Dim := Dim;
  Inc(FLive);
  FSnapDirty := True;
end;

procedure TWorkDoc.AddArc(const C: TP3; R, A0, Sweep: Double; Pl: TPlane;
  Ink: TColor; Weight: Single);
var
  FreeO, FreeU, FreeV: TP3;
begin
  SetLength(FEnts, FLive + 1);
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FEnts[FLive].Kind := ekArc;
  FEnts[FLive].C := C;
  FEnts[FLive].R := R;
  FEnts[FLive].A0 := A0;
  FEnts[FLive].Sweep := Sweep;
  FEnts[FLive].Plane := Pl;
  { A free plane is only a name until the shape carries the direction with
    it.  Taken here, while the plane it was drawn in is still the current
    one. }
  if Pl = plFree then GetFreePlane(FreeO, FreeU, FreeV, FEnts[FLive].Nm);
  FEnts[FLive].A := ArcPoint(C, R, A0, Pl, FEnts[FLive].Nm);
  FEnts[FLive].B := ArcPoint(C, R, A0 + Sweep, Pl, FEnts[FLive].Nm);
  FEnts[FLive].Ink := Ink;
  FEnts[FLive].Weight := Weight;
  Inc(FLive);
  FSnapDirty := True;
end;

procedure TWorkDoc.AddText(const A: TP3; const S: string; Ink: TColor);
begin
  AddNote(A, A, S, Ink);
end;

procedure TWorkDoc.AddNote(const A, Target: TP3; const S: string; Ink: TColor);
begin
  SetLength(FEnts, FLive + 1);
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FEnts[FLive].Kind := ekText;
  FEnts[FLive].A := A;
  FEnts[FLive].B := Target;
  FEnts[FLive].Txt := S;
  FEnts[FLive].Ink := Ink;
  FEnts[FLive].Weight := 1;
  Inc(FLive);
  FSnapDirty := True;
end;

procedure TWorkDoc.AddBore(const Loop: TP3Array; const FarOfFirst: TP3; G: Integer);
var
  Own: TP3Array;
  Far: TP3;
begin
  if Length(Loop) < 3 then Exit;
  { Loop may be a face's own polygon inside FEnts, and growing FEnts moves
    it - so it is copied before anything else happens }
  Own := Copy(Loop, 0, Length(Loop));
  Far := FarOfFirst;
  SetLength(FEnts, FLive + 1);
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FEnts[FLive].Kind := ekBore;
  FEnts[FLive].Poly := Own;
  FEnts[FLive].A := Own[0];
  FEnts[FLive].B := Far;
  FEnts[FLive].Grp := G;
  FEnts[FLive].Solid := True;
  Inc(FLive);
end;

procedure TWorkDoc.AddGuide(const A, B: TP3);
begin
  SetLength(FEnts, FLive + 1);
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FEnts[FLive].Kind := ekGuide;
  FEnts[FLive].A := A;
  FEnts[FLive].B := B;
  FEnts[FLive].Weight := 1;
  Inc(FLive);
  FSnapDirty := True;
end;

function TWorkDoc.GuideCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FLive - 1 do
    if FEnts[I].Kind = ekGuide then Inc(Result);
end;

function TWorkDoc.ClearGuides: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := FLive - 1 downto 0 do
    if FEnts[I].Kind = ekGuide then
    begin
      Delete(I);
      Inc(Result);
    end;
end;

function TWorkDoc.SetDimNote(Index: Integer; const Note: string): Boolean;
begin
  Result := (Index >= 0) and (Index < FLive) and (FEnts[Index].Kind = ekDim);
  if Result then FEnts[Index].Txt := Trim(Note);
end;

procedure TWorkDoc.AddDim(const A, B: TP3; Ink: TColor; const Off: TP3;
  const Note: string);
begin
  SetLength(FEnts, FLive + 1);
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FEnts[FLive].Kind := ekDim;
  FEnts[FLive].A := A;
  FEnts[FLive].B := B;
  FEnts[FLive].C := Off;
  FEnts[FLive].Ink := Ink;
  FEnts[FLive].Weight := 1;
  FEnts[FLive].Dim := True;
  FEnts[FLive].Txt := Note;
  Inc(FLive);
  FSnapDirty := True;
end;

procedure TWorkDoc.Delete(I: Integer);
var
  K: Integer;
begin
  if (I < 0) or (I >= FLive) then Exit;
  for K := I to FLive - 2 do
    FEnts[K] := FEnts[K + 1];
  Dec(FLive);
  SetLength(FEnts, FLive);
  FSnapDirty := True;
end;

procedure TWorkDoc.Clear;
begin
  SetLength(FEnts, 0);
  FLive := 0;
  FSnapDirty := True;
end;


{ A face carries its outline in a dynamic array, and plain record assignment
  would only share the reference - so a later push/pull that rewrites those
  points in place would reach back and corrupt the undo snapshot with it.
  Every copy has to be a deep one. }
function CopyEnt(const Src: TWorkEnt): TWorkEnt;
var
  I: Integer;
begin
  Result := Src;
  Result.Poly := nil;
  SetLength(Result.Poly, Length(Src.Poly));
  for I := 0 to High(Src.Poly) do
    Result.Poly[I] := Src.Poly[I];
end;

{ Undo copies the whole document.  There are only ever a few hundred
  entities, so this is simpler and more correct than replaying edits. }
function TWorkDoc.Snapshot: TWorkEntArray;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, FLive);
  for I := 0 to FLive - 1 do
    Result[I] := CopyEnt(FEnts[I]);
end;

procedure TWorkDoc.RestoreSnap(const A: TWorkEntArray);
var
  I: Integer;
begin
  SetLength(FEnts, Length(A));
  for I := 0 to High(A) do
    FEnts[I] := CopyEnt(A[I]);
  FLive := Length(A);
  FSnapDirty := True;
end;

function TWorkDoc.FirstOfChain: Integer;
var
  I: Integer;
begin
  Result := FLive;
  for I := FLive - 1 downto 0 do
  begin
    if FEnts[I].Kind <> ekLine then Break;
    if (I < FLive - 1) and not SamePt(FEnts[I].B, FEnts[I + 1].A, 1E-6) then Break;
    Result := I;
  end;
end;

function TWorkDoc.ChainLength: Double;
var
  I: Integer;
begin
  Result := 0;
  for I := FirstOfChain to FLive - 1 do
    if FEnts[I].Kind = ekLine then
      Result := Result + Dist(FEnts[I].A, FEnts[I].B);
end;

function TWorkDoc.ChainClosed(Tol: Double): Boolean;
var
  First: Integer;
begin
  First := FirstOfChain;
  Result := (FLive - First >= 3) and
            SamePt(FEnts[FLive - 1].B, FEnts[First].A, Tol);
end;

{ Shoelace in the XY plane - only meaningful for a flat closed run. }
function TWorkDoc.ChainArea: Double;
var
  I: Integer;
  Acc: Double;
begin
  Acc := 0;
  for I := FirstOfChain to FLive - 1 do
    if FEnts[I].Kind = ekLine then
      Acc := Acc + (FEnts[I].A.X * FEnts[I].B.Y - FEnts[I].B.X * FEnts[I].A.Y);
  Result := Abs(Acc) / 2;
end;

{ ---------------------------------------------------------------------- }
{ faces and push/pull                                                      }
{ ---------------------------------------------------------------------- }

{ The winding of a face decides which way its normal points, and for a flat
  one drawn on the screen that came out of which way the cursor was dragged -
  a rectangle pulled down-right in plan faced down, one pulled up-left faced
  up.  Nothing cared until push/pull built a solid from it: the face that
  should have ended up on the outside faced inwards, was culled as a back
  face, and could then neither be seen nor clicked.

  So a drawing face is wound to face along whichever axis it is squarest to,
  positively.  Solids are left alone - their windings are built deliberately
  and mean something. }
procedure OrientFace(var Pts: TP3Array);
var
  I, N: Integer;
  Acc, Nm: TP3;
  Tmp: TP3;
  D: Double;
begin
  N := Length(Pts);
  if N < 3 then Exit;
  Acc := P3(0, 0, 0);
  for I := 0 to N - 1 do
  begin
    Nm := Pts[(I + 1) mod N];
    Acc.X := Acc.X + (Pts[I].Y - Nm.Y) * (Pts[I].Z + Nm.Z);
    Acc.Y := Acc.Y + (Pts[I].Z - Nm.Z) * (Pts[I].X + Nm.X);
    Acc.Z := Acc.Z + (Pts[I].X - Nm.X) * (Pts[I].Y + Nm.Y);
  end;
  if (Abs(Acc.Z) >= Abs(Acc.X)) and (Abs(Acc.Z) >= Abs(Acc.Y)) then D := Acc.Z
  else if Abs(Acc.Y) >= Abs(Acc.X) then D := Acc.Y
  else D := Acc.X;
  if D >= 0 then Exit;
  for I := 0 to N div 2 - 1 do
  begin
    Tmp := Pts[I];
    Pts[I] := Pts[N - 1 - I];
    Pts[N - 1 - I] := Tmp;
  end;
end;

{ Adds the polygon exactly as given.  Solids build their windings on purpose,
  so they come this way round. }
procedure TWorkDoc.AddFaceRaw(const Pts: array of TP3; Ink: TColor; Solid: Boolean);
var
  I: Integer;
begin
  if Length(Pts) < 3 then Exit;
  SetLength(FEnts, FLive + 1);
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FEnts[FLive].Kind := ekFace;
  SetLength(FEnts[FLive].Poly, Length(Pts));
  for I := 0 to High(Pts) do
    FEnts[FLive].Poly[I] := Pts[I];
  FEnts[FLive].A := Pts[0];
  FEnts[FLive].B := Pts[High(Pts)];
  FEnts[FLive].Ink := Ink;
  FEnts[FLive].Weight := 1;
  FEnts[FLive].Solid := Solid;
  Inc(FLive);
  FSnapDirty := True;
end;

procedure TWorkDoc.AddFace(const Pts: array of TP3; Ink: TColor; Solid: Boolean);
var
  I: Integer;
  Fixed: TP3Array;
begin
  if Length(Pts) < 3 then Exit;
  if Solid then
  begin
    AddFaceRaw(Pts, Ink, Solid);
    Exit;
  end;
  SetLength(Fixed, Length(Pts));
  for I := 0 to High(Pts) do Fixed[I] := Pts[I];
  OrientFace(Fixed);
  AddFaceRaw(Fixed, Ink, Solid);
end;

function TWorkDoc.NoteSize(Index: Integer): Single;
begin
  Result := 1;
  if (Index < 0) or (Index >= FLive) or (FEnts[Index].Kind <> ekText) then Exit;
  if FEnts[Index].Size > 0 then Result := FEnts[Index].Size;
end;

procedure TWorkDoc.SetNoteSize(Index: Integer; Factor: Single);
begin
  if (Index < 0) or (Index >= FLive) or (FEnts[Index].Kind <> ekText) then Exit;
  { half normal to four times it - smaller cannot be read and bigger is a
    poster, not a note }
  if Factor < 0.5 then Factor := 0.5;
  if Factor > 4 then Factor := 4;
  FEnts[Index].Size := Factor;
end;

procedure TWorkDoc.FlipFace(Index: Integer);
var
  I, H, N: Integer;
  T: TP3Array;
begin
  if (Index < 0) or (Index >= FLive) or (FEnts[Index].Kind <> ekFace) then Exit;
  N := Length(FEnts[Index].Poly);
  SetLength(T, N);
  for I := 0 to N - 1 do T[I] := FEnts[Index].Poly[N - 1 - I];
  FEnts[Index].Poly := T;
  for H := 0 to High(FEnts[Index].Holes) do
  begin
    N := Length(FEnts[Index].Holes[H]);
    SetLength(T, N);
    for I := 0 to N - 1 do T[I] := FEnts[Index].Holes[H][N - 1 - I];
    FEnts[Index].Holes[H] := T;
  end;
  FSnapDirty := True;
end;

procedure TWorkDoc.SetSoft(Index: Integer; Soft: Boolean);
begin
  if (Index < 0) or (Index >= FLive) then Exit;
  FEnts[Index].Soft := Soft;
end;

procedure TWorkDoc.SetArcSides(Index, N: Integer);
begin
  if (Index < 0) or (Index >= FLive) or (FEnts[Index].Kind <> ekArc) then Exit;
  if (N < 3) or (N > 360) then N := 0;
  FEnts[Index].Sides := N;
  FSnapDirty := True;
end;

procedure TWorkDoc.SetGroup(Index, G: Integer);
begin
  if (Index < 0) or (Index >= FLive) then Exit;
  FEnts[Index].Grp := G;
end;

procedure TWorkDoc.SetFaceGroup(Index, G: Integer);
begin
  if (Index < 0) or (Index >= FLive) or (FEnts[Index].Kind <> ekFace) then Exit;
  FEnts[Index].Grp := G;
  FEnts[Index].Solid := True;
end;

{ Give the face just added the loops cut out of it. }
procedure TWorkDoc.SetFaceHoles(Index: Integer; const H: array of TP3Array);
var
  I, K: Integer;
begin
  if (Index < 0) or (Index >= FLive) or (FEnts[Index].Kind <> ekFace) then Exit;
  SetLength(FEnts[Index].Holes, Length(H));
  for I := 0 to High(H) do
  begin
    SetLength(FEnts[Index].Holes[I], Length(H[I]));
    for K := 0 to High(H[I]) do
      FEnts[Index].Holes[I][K] := H[I][K];
  end;
  FSnapDirty := True;
end;

{ Newell's method, which copes with slightly non-planar loops. }
function TWorkDoc.FaceNormal(Index: Integer): TP3;
var
  I, J, N: Integer;
  Acc: TP3;
begin
  Result := P3(0, 0, 1);
  if (Index < 0) or (Index >= FLive) or (FEnts[Index].Kind <> ekFace) then Exit;
  N := Length(FEnts[Index].Poly);
  if N < 3 then Exit;
  Acc := P3(0, 0, 0);
  for I := 0 to N - 1 do
  begin
    J := (I + 1) mod N;
    Acc.X := Acc.X + (FEnts[Index].Poly[I].Y - FEnts[Index].Poly[J].Y) *
                     (FEnts[Index].Poly[I].Z + FEnts[Index].Poly[J].Z);
    Acc.Y := Acc.Y + (FEnts[Index].Poly[I].Z - FEnts[Index].Poly[J].Z) *
                     (FEnts[Index].Poly[I].X + FEnts[Index].Poly[J].X);
    Acc.Z := Acc.Z + (FEnts[Index].Poly[I].X - FEnts[Index].Poly[J].X) *
                     (FEnts[Index].Poly[I].Y + FEnts[Index].Poly[J].Y);
  end;
  Result := Norm3(Acc);
end;

function TWorkDoc.FaceArea(Index: Integer): Double;
var
  I, J, N, H: Integer;
  Acc: TP3;
begin
  Result := 0;
  if (Index < 0) or (Index >= FLive) or (FEnts[Index].Kind <> ekFace) then Exit;
  N := Length(FEnts[Index].Poly);
  if N < 3 then Exit;
  Acc := P3(0, 0, 0);
  for I := 0 to N - 1 do
  begin
    J := (I + 1) mod N;
    Acc.X := Acc.X + FEnts[Index].Poly[I].Y * FEnts[Index].Poly[J].Z -
                     FEnts[Index].Poly[I].Z * FEnts[Index].Poly[J].Y;
    Acc.Y := Acc.Y + FEnts[Index].Poly[I].Z * FEnts[Index].Poly[J].X -
                     FEnts[Index].Poly[I].X * FEnts[Index].Poly[J].Z;
    Acc.Z := Acc.Z + FEnts[Index].Poly[I].X * FEnts[Index].Poly[J].Y -
                     FEnts[Index].Poly[I].Y * FEnts[Index].Poly[J].X;
  end;
  Result := Sqrt(Acc.X * Acc.X + Acc.Y * Acc.Y + Acc.Z * Acc.Z) / 2;

  { less whatever is cut out of it - the area of a ring is the ring, not the
    rectangle it was cut from, and the number this returns is the number
    somebody is shown when they click on it }
  for H := 0 to High(FEnts[Index].Holes) do
  begin
    N := Length(FEnts[Index].Holes[H]);
    if N < 3 then Continue;
    Acc := P3(0, 0, 0);
    for I := 0 to N - 1 do
    begin
      J := (I + 1) mod N;
      Acc.X := Acc.X + FEnts[Index].Holes[H][I].Y * FEnts[Index].Holes[H][J].Z -
                       FEnts[Index].Holes[H][I].Z * FEnts[Index].Holes[H][J].Y;
      Acc.Y := Acc.Y + FEnts[Index].Holes[H][I].Z * FEnts[Index].Holes[H][J].X -
                       FEnts[Index].Holes[H][I].X * FEnts[Index].Holes[H][J].Z;
      Acc.Z := Acc.Z + FEnts[Index].Holes[H][I].X * FEnts[Index].Holes[H][J].Y -
                       FEnts[Index].Holes[H][I].Y * FEnts[Index].Holes[H][J].X;
    end;
    Result := Result - Sqrt(Acc.X * Acc.X + Acc.Y * Acc.Y + Acc.Z * Acc.Z) / 2;
  end;
  if Result < 0 then Result := 0;
end;

{ Topmost first, so a small face sitting on a big one wins the click. }
{ Which face is under the cursor.

  This has to agree with what is on the screen, or you pick up something you
  cannot see. It used to take the most recently added face, which meant a
  wall behind a block could be grabbed through it, and which square you got
  depended on the order they were drawn in.

  So: the same back-face test the renderer uses, and then the same depth key,
  picking the largest - the face the renderer draws last is the face on top.

  The depth is taken at the cursor, not at the face's center. Centers of two
  flat faces lying in the same plane sit at different depths, and that
  difference swamped the tiebreak: clicking a small square inside a big slab
  picked up the slab. Solving for the point on the face under the cursor puts
  coplanar faces at exactly the same depth, and then the area term does what
  it is there for and the smaller face wins.

  The point is found through Project itself rather than by inverting it:
  the projection is affine, so three points on the face plane fix the mapping
  and a 2x2 solve gives the rest. }
function TWorkDoc.FaceUnder(const V: TProjector; SX, SY: Double;
  out Face: Integer; out Pt: TP3): Boolean;
var
  I, J, K, N, M, HK: Integer;
  Inside: Boolean;
  P, HP: array of TPointF;
  Look, Org, U, W, Hit: TP3;
  P0, P1, P2: TPointF;
  AX, AY, BX, BY, Det, SS, TT, D, Best, Eps: Double;
begin
  Result := False;
  Face := -1;
  Pt := P3(0, 0, 0);
  Best := -1E300;
  Look := ViewDir(V);

  for I := 0 to FLive - 1 do
  begin
    if FEnts[I].Kind <> ekFace then Continue;
    N := Length(FEnts[I].Poly);
    if N < 3 then Continue;
    { A face is pickable from either side.

      This used to skip a solid's face whose normal pointed away, on the
      grounds that the back of a solid is not drawn.  That stopped being true
      when back faces got a color of their own, and it was always the wrong
      rule for the shape people actually build: a duct transition has an end
      at each end, their normals point opposite ways, so from any one place
      to stand one end could be erased and the other could not be touched at
      all - not even hovered.  Which end depended on where the camera was,
      which is why it read as the program being arbitrary.

      Nothing is needed in its place.  Every candidate is already compared by
      depth below and the nearest wins, so on a closed box the near face
      still takes the click and the far one still loses - on the strength of
      being further away, which is the honest reason. }

    SetLength(P, N);
    for K := 0 to N - 1 do
      P[K] := Project(V, FEnts[I].Poly[K]);

    Inside := False;
    J := N - 1;
    for K := 0 to N - 1 do
    begin
      if ((P[K].Y > SY) <> (P[J].Y > SY)) and
         (SX < (P[J].X - P[K].X) * (SY - P[K].Y) / (P[J].Y - P[K].Y) + P[K].X) then
        Inside := not Inside;
      J := K;
    end;
    { and out again through anything cut out of it.  A window is a hole in
      the wall, so the cursor in a window is not on the wall - which is what
      lets you reach whatever is behind it, and what stops the eraser
      offering you a wall you are looking through. }
    if Inside then
      for HK := 0 to High(FEnts[I].Holes) do
      begin
        M := Length(FEnts[I].Holes[HK]);
        if M < 3 then Continue;
        SetLength(HP, M);
        for K := 0 to M - 1 do HP[K] := Project(V, FEnts[I].Holes[HK][K]);
        J := M - 1;
        for K := 0 to M - 1 do
        begin
          if ((HP[K].Y > SY) <> (HP[J].Y > SY)) and
             (SX < (HP[J].X - HP[K].X) * (SY - HP[K].Y) /
                   (HP[J].Y - HP[K].Y) + HP[K].X) then
            Inside := not Inside;
          J := K;
        end;
      end;
    if not Inside then Continue;

    { Where the cursor meets this face's plane.  The basis is normalized
      first: a circle's polygon has very short sides, and solving against a
      one-foot-long axis instead of a thirteen-inch one is what keeps the
      answer accurate enough to compare against another face's. }
    Org := FEnts[I].Poly[0];
    U := Norm3(P3(FEnts[I].Poly[1].X - Org.X, FEnts[I].Poly[1].Y - Org.Y,
                  FEnts[I].Poly[1].Z - Org.Z));
    W := Norm3(Cross3(FaceNormal(I), U));
    P0 := Project(V, Org);
    P1 := Project(V, P3(Org.X + U.X, Org.Y + U.Y, Org.Z + U.Z));
    P2 := Project(V, P3(Org.X + W.X, Org.Y + W.Y, Org.Z + W.Z));
    AX := P1.X - P0.X; AY := P1.Y - P0.Y;
    BX := P2.X - P0.X; BY := P2.Y - P0.Y;
    Det := AX * BY - AY * BX;
    if Abs(Det) < 1E-12 then Continue;      // edge-on: nothing to click
    SS := ((SX - P0.X) * BY - (SY - P0.Y) * BX) / Det;
    TT := (AX * (SY - P0.Y) - AY * (SX - P0.X)) / Det;
    Hit := P3(Org.X + U.X * SS + W.X * TT,
              Org.Y + U.Y * SS + W.Y * TT,
              Org.Z + U.Z * SS + W.Z * TT);
    { Two faces lying in the same plane - a circle drawn on a slab, a
      rectangle inside a rectangle - come out with depths that differ only by
      rounding.  That difference used to be thousands of times larger than
      the nudge meant to prefer the smaller one, so the slab always won and a
      circle could never be pulled out of the face it was drawn on.  Compare
      with a tolerance instead, and inside it let the smaller face win: it is
      the one drawn on top, and the one you were aiming at. }
    D := Dot3(Hit, Look);
    Eps := 1E-4 * (1 + Abs(D));
    if (Face < 0) or (D > Best + Eps) or
       ((D > Best - Eps) and (FaceArea(I) < FaceArea(Face))) then
    begin
      Best := D;
      Face := I;
      Pt := Hit;
      Result := True;
    end;
  end;
end;

function TWorkDoc.HitFace(const V: TProjector; SX, SY: Double): Integer;
var
  Pt: TP3;
begin
  if not FaceUnder(V, SX, SY, Result, Pt) then Result := -1;
end;

{ Lift the face along its normal and wall in the sides.  The original outline
  stays behind as the base, so what you get is a closed box - which is all
  push/pull needs to be for roughing something out. }
{ Cut one face along a segment that crosses it.

  The face is flattened into its own plane, the segment is intersected with
  each edge in turn, and if it enters and leaves exactly once the boundary is
  walked from one crossing round to the other, and then the other way, to
  give the two halves.

  Anything else is left alone. A segment that only clips a corner, that lies
  along an edge, or that stops inside the face gives no clean pair of halves,
  and half a cut is worse than none. }
function TWorkDoc.SplitFace(Index: Integer; const A, B: TP3): Boolean;
const
  EPS = 1E-9;
var
  N, I, J, K, NHit, C1, C2: Integer;
  Nm, U, V, Org, W: TP3;
  PX, PY: array of Double;
  AX, AY, BX, BY: Double;
  EX, EY, RX, RY, Den, T, Q: Double;
  CutEdge: array[0..1] of Integer;
  HitP: array[0..1] of TP3;
  Src, H1, H2: TP3Array;
  Ink: TColor;
  WasSolid: Boolean;
  WasGrp: Integer;

  function Same(const P, R: TP3): Boolean;
  begin
    Result := Dist(P, R) < 1E-7;
  end;

begin
  Result := False;
  if (Index < 0) or (Index >= FLive) then Exit;
  if FEnts[Index].Kind <> ekFace then Exit;
  N := Length(FEnts[Index].Poly);
  if N < 3 then Exit;

  { work from a copy - the original is overwritten with one of the halves }
  SetLength(Src, N);
  for I := 0 to N - 1 do
    Src[I] := FEnts[Index].Poly[I];

  Nm := FaceNormal(Index);
  Org := Src[0];

  { the cut has to lie in the face's plane }
  W := P3(A.X - Org.X, A.Y - Org.Y, A.Z - Org.Z);
  if Abs(Dot3(W, Nm)) > 1E-6 then Exit;
  W := P3(B.X - Org.X, B.Y - Org.Y, B.Z - Org.Z);
  if Abs(Dot3(W, Nm)) > 1E-6 then Exit;

  { a basis in that plane }
  U := Norm3(P3(Src[1].X - Org.X, Src[1].Y - Org.Y, Src[1].Z - Org.Z));
  V := Cross3(Nm, U);

  SetLength(PX, N);
  SetLength(PY, N);
  for I := 0 to N - 1 do
  begin
    W := P3(Src[I].X - Org.X, Src[I].Y - Org.Y, Src[I].Z - Org.Z);
    PX[I] := Dot3(W, U);
    PY[I] := Dot3(W, V);
  end;
  W := P3(A.X - Org.X, A.Y - Org.Y, A.Z - Org.Z);
  AX := Dot3(W, U); AY := Dot3(W, V);
  W := P3(B.X - Org.X, B.Y - Org.Y, B.Z - Org.Z);
  BX := Dot3(W, U); BY := Dot3(W, V);

  RX := BX - AX;
  RY := BY - AY;
  if Sqrt(RX * RX + RY * RY) < 1E-9 then Exit;

  NHit := 0;
  for I := 0 to N - 1 do
  begin
    J := (I + 1) mod N;
    EX := PX[J] - PX[I];
    EY := PY[J] - PY[I];
    Den := RX * EY - RY * EX;
    if Abs(Den) < EPS then Continue;        // parallel, including along an edge
    T := ((PX[I] - AX) * EY - (PY[I] - AY) * EX) / Den;   // along the cut
    Q := ((PX[I] - AX) * RY - (PY[I] - AY) * RX) / Den;   // along this edge
    if (T < -1E-9) or (T > 1 + 1E-9) then Continue;
    { a crossing exactly on a vertex would be reported by both edges that
      meet there, so each edge owns its start and leaves its end to the next }
    if (Q < -1E-9) or (Q > 1 - 1E-9) then Continue;
    if NHit >= 2 then Exit;                 // more than a clean pair
    CutEdge[NHit] := I;
    HitP[NHit] := P3(Src[I].X + (Src[J].X - Src[I].X) * Q,
                     Src[I].Y + (Src[J].Y - Src[I].Y) * Q,
                     Src[I].Z + (Src[J].Z - Src[I].Z) * Q);
    Inc(NHit);
  end;

  if NHit <> 2 then Exit;
  if CutEdge[0] = CutEdge[1] then Exit;     // in and out through one edge
  if Same(HitP[0], HitP[1]) then Exit;

  Ink := FEnts[Index].Ink;

  { one half: crossing 0, round the boundary, crossing 1 }
  SetLength(H1, N + 4);
  C1 := 0;
  H1[C1] := HitP[0]; Inc(C1);
  I := CutEdge[0];
  repeat
    I := (I + 1) mod N;
    if not Same(Src[I], HitP[0]) and not Same(Src[I], HitP[1]) then
    begin
      H1[C1] := Src[I]; Inc(C1);
    end;
  until I = CutEdge[1];
  H1[C1] := HitP[1]; Inc(C1);
  SetLength(H1, C1);

  { the other half: crossing 1, round the rest, crossing 0 }
  SetLength(H2, N + 4);
  C2 := 0;
  H2[C2] := HitP[1]; Inc(C2);
  K := CutEdge[1];
  repeat
    K := (K + 1) mod N;
    if not Same(Src[K], HitP[0]) and not Same(Src[K], HitP[1]) then
    begin
      H2[C2] := Src[K]; Inc(C2);
    end;
  until K = CutEdge[0];
  H2[C2] := HitP[0]; Inc(C2);
  SetLength(H2, C2);

  if (C1 < 3) or (C2 < 3) then Exit;

  { both halves keep whatever the whole was - a side of a solid stays part of
    that solid, and both pieces answer to the same group }
  WasSolid := FEnts[Index].Solid;
  WasGrp := FEnts[Index].Grp;

  SetLength(FEnts[Index].Poly, C1);
  for I := 0 to C1 - 1 do
    FEnts[Index].Poly[I] := H1[I];
  FEnts[Index].A := H1[0];
  FEnts[Index].B := H1[C1 - 1];

  if WasSolid then
  begin
    { raw, because both halves were walked round in the original's order and
      already face the way it did - orienting them would turn one inside out }
    AddFaceRaw(H2, Ink, True);
    FEnts[FLive - 1].Grp := WasGrp;
  end
  else
    AddFace(H2, Ink, False);
  FSnapDirty := True;
  Result := True;
end;

{ Two faces that meet along an edge become one when that edge goes.

  A rectangle with an arc across its end is two regions while the straight
  line between them is there - lift either on its own - and one region once
  it is rubbed out. Nothing was rebuilding faces from the geometry, so the
  line could be deleted and the two faces would just sit there unchanged.

  The shared edge runs one way round in each face, which is what makes them
  separate regions rather than one folded over. Walk the first from B round
  to A, then the second from A round to B, and the seam is gone. }
function TWorkDoc.IsPatch(Index: Integer): Boolean;
const
  TOL = 1E-6;
var
  I, Q, K, N, M: Integer;
  Nm: TP3;
  PlaneD: Double;
begin
  Result := False;
  if (Index < 0) or (Index >= FLive) or (FEnts[Index].Kind <> ekFace) then Exit;
  N := Length(FEnts[Index].Poly);
  if N < 3 then Exit;
  Nm := FaceNormal(Index);
  PlaneD := Dot3(Nm, FEnts[Index].Poly[0]);

  for I := 0 to FLive - 1 do
  begin
    if I = Index then Continue;
    if FEnts[I].Kind <> ekFace then Continue;
    M := Length(FEnts[I].Poly);
    if M < 3 then Continue;
    { in the same plane?  the normals may point opposite ways }
    if Abs(Abs(Dot3(FaceNormal(I), Nm)) - 1) > TOL then Continue;
    if Abs(Dot3(Nm, FEnts[I].Poly[0]) - PlaneD) > TOL then Continue;
    { sharing an edge with it? }
    for Q := 0 to N - 1 do
      for K := 0 to M - 1 do
        if ((Dist(FEnts[Index].Poly[Q], FEnts[I].Poly[K]) < TOL) and
            (Dist(FEnts[Index].Poly[(Q + 1) mod N],
                  FEnts[I].Poly[(K + 1) mod M]) < TOL)) or
           ((Dist(FEnts[Index].Poly[Q], FEnts[I].Poly[(K + 1) mod M]) < TOL) and
            (Dist(FEnts[Index].Poly[(Q + 1) mod N], FEnts[I].Poly[K]) < TOL)) then
          Exit(True);
  end;
end;


{ A face is the inside of a closed run of edges.  Rub one of those edges out
  and there is no longer an inside, so the face should go with it - deleting
  three sides of a rectangle used to leave the fill hanging in mid air.

  Every straight run of a flat face's outline has to be backed by a real
  line; the curved runs an arc left behind are matched against arcs. }


{ Which flat face a point sits on.  A corner of a box belongs to three of
  them; the first found will do, since they are all planes a new shape could
  reasonably be drawn in. }
function TWorkDoc.FaceThrough(const P: TP3): Integer;
const
  TOL = 1E-6;
var
  I, K: Integer;
  Nm, W: TP3;
begin
  Result := -1;
  for I := FLive - 1 downto 0 do
  begin
    if FEnts[I].Kind <> ekFace then Continue;
    if Length(FEnts[I].Poly) < 3 then Continue;
    Nm := FaceNormal(I);
    W := P3(P.X - FEnts[I].Poly[0].X, P.Y - FEnts[I].Poly[0].Y,
            P.Z - FEnts[I].Poly[0].Z);
    if Abs(Dot3(W, Nm)) > TOL then Continue;
    for K := 0 to High(FEnts[I].Poly) do
      if Dist(P, FEnts[I].Poly[K]) < 1E-5 then Exit(I);
  end;
end;

function TWorkDoc.SplitFacesWith(const A, B: TP3): Integer;
var
  I, Was: Integer;
begin
  Result := 0;
  Was := FLive;                { only faces that were there before the cut }
  for I := Was - 1 downto 0 do
    if SplitFace(I, A, B) then Inc(Result);
end;

{ Move a face and take the geometry attached to it along.

  Pushing a face of a solid should make the solid bigger or smaller, not grow
  a second box inside the first - which is what extruding did, leaving a
  nest of lines inside a cube that looked unchanged from outside.

  Every vertex that sits on the face moves with it, wherever it lives: the
  walls that meet the face follow, the far cap does not, and the solid
  changes size.  Vertices are matched against where the face was before the
  move, so nothing is moved twice. }
procedure TWorkDoc.MoveFaceWith(Index: Integer; const D: TP3);
const
  TOL = 1E-6;
var
  Was: TP3Array;
  I, K, N, G: Integer;
  Nm, BU, BV: TP3;
  PlaneD: Double;

  { Does this point sit on the face - anywhere on it, edges included?

    It used to mean "is it one of the corners", which is why a line drawn
    across the top of a box to the middle of an edge stayed behind when the
    face under that edge was pushed: the line's end was on the moving face,
    just not at a corner of it. }
  function OnFace(const P: TP3): Boolean;
  var
    J, M: Integer;
    Inside: Boolean;
    PU, PV, AU, AV, BU2, BV2, DU, DV, L2, T: Double;

    procedure Flat(const R: TP3; out CU, CV: Double);
    var
      W: TP3;
    begin
      W := P3(R.X - Was[0].X, R.Y - Was[0].Y, R.Z - Was[0].Z);
      CU := Dot3(W, BU);
      CV := Dot3(W, BV);
    end;

  begin
    Result := False;
    { in the face's plane at all? }
    if Abs(Dot3(Nm, P) - PlaneD) > TOL then Exit;

    Flat(P, PU, PV);
    M := Length(Was);

    { on the outline counts, and has to be tested for on its own - a ray cast
      is unreliable exactly on a boundary }
    for J := 0 to M - 1 do
    begin
      Flat(Was[J], AU, AV);
      Flat(Was[(J + 1) mod M], BU2, BV2);
      DU := BU2 - AU;
      DV := BV2 - AV;
      L2 := DU * DU + DV * DV;
      if L2 < 1E-18 then Continue;
      T := EnsureRange(((PU - AU) * DU + (PV - AV) * DV) / L2, 0, 1);
      if Sqrt(Sqr(PU - (AU + DU * T)) + Sqr(PV - (AV + DV * T))) < TOL then
        Exit(True);
    end;

    { otherwise, inside the outline }
    Inside := False;
    Flat(Was[M - 1], AU, AV);
    for J := 0 to M - 1 do
    begin
      Flat(Was[J], BU2, BV2);
      if ((BV2 > PV) <> (AV > PV)) and
         (PU < (AU - BU2) * (PV - BV2) / (AV - BV2) + BU2) then
        Inside := not Inside;
      AU := BU2;
      AV := BV2;
    end;
    Result := Inside;
  end;

  procedure Shift(var P: TP3);
  begin
    if OnFace(P) then
      P := P3(P.X + D.X, P.Y + D.Y, P.Z + D.Z);
  end;

begin
  N := Length(FEnts[Index].Poly);
  if N < 3 then Exit;
  SetLength(Was, N);
  for I := 0 to N - 1 do
    Was[I] := FEnts[Index].Poly[I];
  G := FEnts[Index].Grp;

  Nm := FaceNormal(Index);
  PlaneD := Dot3(Nm, Was[0]);
  BU := Norm3(P3(Was[1].X - Was[0].X, Was[1].Y - Was[0].Y, Was[1].Z - Was[0].Z));
  BV := Cross3(Nm, BU);

  for I := 0 to FLive - 1 do
  begin
    { This solid, and anything loose lying on it.  Two boxes split from one
      rectangle share corners, and moving everything that touched meant
      pulling a face on one of them dragged the other out of shape - so
      another solid, which has a group of its own, is left alone.  A line or
      a note drawn on this one belongs to no group and comes along. }
    if (I <> Index) and (FEnts[I].Grp <> G) and (FEnts[I].Grp <> 0) then Continue;
    Shift(FEnts[I].A);
    Shift(FEnts[I].B);
    if FEnts[I].Kind = ekArc then Shift(FEnts[I].C);
    for K := 0 to High(FEnts[I].Poly) do
      Shift(FEnts[I].Poly[K]);
  end;
  FSnapDirty := True;
end;

procedure TWorkDoc.VertsOf(const Idx: array of Integer; out Pts: TP3Array);
var
  I, J, K, N: Integer;

  procedure Put(const P: TP3);
  begin
    if N >= Length(Pts) then SetLength(Pts, Max(16, N * 2));
    Pts[N] := P;
    Inc(N);
  end;

begin
  Pts := nil;
  N := 0;
  SetLength(Pts, 16);
  for J := 0 to High(Idx) do
  begin
    I := Idx[J];
    if (I < 0) or (I >= FLive) then Continue;
    Put(FEnts[I].A);
    Put(FEnts[I].B);
    if FEnts[I].Kind = ekArc then Put(FEnts[I].C);
    for K := 0 to High(FEnts[I].Poly) do
      Put(FEnts[I].Poly[K]);
  end;
  SetLength(Pts, N);
end;

procedure TWorkDoc.MoveVerts(const Pts: TP3Array; const D: TP3);
const
  TOL = 1E-7;
var
  I, K, H: Integer;

  function OnSet(const P: TP3): Boolean;
  var
    J: Integer;
  begin
    Result := True;
    for J := 0 to High(Pts) do
      if Dist(P, Pts[J]) < TOL then Exit;
    Result := False;
  end;

  procedure Shift(var P: TP3);
  begin
    if OnSet(P) then P := P3(P.X + D.X, P.Y + D.Y, P.Z + D.Z);
  end;

begin
  if Length(Pts) = 0 then Exit;
  for I := 0 to FLive - 1 do
  begin
    Shift(FEnts[I].A);
    Shift(FEnts[I].B);
    if FEnts[I].Kind = ekArc then Shift(FEnts[I].C);
    for K := 0 to High(FEnts[I].Poly) do
      Shift(FEnts[I].Poly[K]);
    for H := 0 to High(FEnts[I].Holes) do
      for K := 0 to High(FEnts[I].Holes[H]) do
        Shift(FEnts[I].Holes[H][K]);
  end;
  FSnapDirty := True;
end;

{ Rotation is the one change that has to know what an arc is.  A line is its
  two ends and a face its corners, and turning the points turns the thing;
  an arc is a center, a radius and two angles measured in a plane, and the
  plane turns with it.  So arcs go round whole, onto a free plane whose
  normal is the old one turned, and the start angle is measured again in the
  new plane's basis so the same point is still the start. }
procedure TWorkDoc.RotateEnt(I: Integer; const Pts: TP3Array;
  const C, Axis: TP3; Ang: Double; All: Boolean);
const
  TOL = 1E-7;
var
  K, H: Integer;
  AU, AV, N, D: TP3;

  function OnSet(const P: TP3): Boolean;
  var
    J: Integer;
  begin
    if All then Exit(True);
    Result := True;
    for J := 0 to High(Pts) do
      if Dist(P, Pts[J]) < TOL then Exit;
    Result := False;
  end;

  procedure Turn(var P: TP3);
  begin
    if OnSet(P) then P := RotP(P, C, Axis, Ang);
  end;

begin
  if FEnts[I].Kind = ekArc then
  begin
    if not (OnSet(FEnts[I].A) or OnSet(FEnts[I].B) or OnSet(FEnts[I].C)) then Exit;
    if FEnts[I].Plane = plFree then
      N := Norm3(FEnts[I].Nm)
    else
    begin
      PlaneAxes(FEnts[I].Plane, AU, AV);
      N := Norm3(Cross3(AU, AV));
    end;
    FEnts[I].A := RotP(FEnts[I].A, C, Axis, Ang);
    FEnts[I].B := RotP(FEnts[I].B, C, Axis, Ang);
    FEnts[I].C := RotP(FEnts[I].C, C, Axis, Ang);
    N := RotV(N, Axis, Ang);
    FEnts[I].Plane := plFree;
    FEnts[I].Nm := N;
    AxesFromNormal(N, AU, AV);
    D := P3(FEnts[I].A.X - FEnts[I].C.X, FEnts[I].A.Y - FEnts[I].C.Y,
            FEnts[I].A.Z - FEnts[I].C.Z);
    FEnts[I].A0 := ArcTan2(Dot3(D, AV), Dot3(D, AU));
    Exit;
  end;
  { a dimension's third point is where its line sits, and it goes where the
    dimension goes }
  if (FEnts[I].Kind = ekDim) and (OnSet(FEnts[I].A) or OnSet(FEnts[I].B)) then
    FEnts[I].C := RotP(FEnts[I].C, C, Axis, Ang);
  Turn(FEnts[I].A);
  Turn(FEnts[I].B);
  for K := 0 to High(FEnts[I].Poly) do
    Turn(FEnts[I].Poly[K]);
  for H := 0 to High(FEnts[I].Holes) do
    for K := 0 to High(FEnts[I].Holes[H]) do
      Turn(FEnts[I].Holes[H][K]);
end;

procedure TWorkDoc.RotateVerts(const Pts: TP3Array; const C, Axis: TP3; Ang: Double);
var
  I: Integer;
begin
  if (Length(Pts) = 0) or (Abs(Ang) < 1E-12) then Exit;
  for I := 0 to FLive - 1 do
    RotateEnt(I, Pts, C, Axis, Ang, False);
  FSnapDirty := True;
end;

procedure TWorkDoc.RotateEnts(const Idx: array of Integer; const C, Axis: TP3; Ang: Double);
var
  J: Integer;
begin
  for J := 0 to High(Idx) do
    if (Idx[J] >= 0) and (Idx[J] < FLive) then
      RotateEnt(Idx[J], nil, C, Axis, Ang, True);
  FSnapDirty := True;
end;

function TWorkDoc.OutlineWorld(I: Integer): TP3Array;
var
  K, Steps: Integer;
begin
  Result := nil;
  if (I < 0) or (I >= FLive) then Exit;
  case FEnts[I].Kind of
    ekArc:
      begin
        Steps := ArcSteps(FEnts[I]);
        SetLength(Result, Steps + 1);
        for K := 0 to Steps do
          Result[K] := ArcPoint(FEnts[I].C, FEnts[I].R,
            FEnts[I].A0 + FEnts[I].Sweep * K / Steps, FEnts[I].Plane, FEnts[I].Nm);
      end;
    ekFace:
      begin
        SetLength(Result, Length(FEnts[I].Poly) + 1);
        for K := 0 to High(FEnts[I].Poly) do
          Result[K] := FEnts[I].Poly[K];
        if Length(FEnts[I].Poly) > 0 then
          Result[High(Result)] := Result[0];
      end;
    ekText:
      begin
        SetLength(Result, 1);
        Result[0] := FEnts[I].A;
      end;
    ekBore: ;
  else
    SetLength(Result, 2);
    Result[0] := FEnts[I].A;
    Result[1] := FEnts[I].B;
  end;
end;

procedure TWorkDoc.Duplicate(const Idx: array of Integer; const D: TP3);
var
  J, I, K, Base, G: Integer;
  Src, Dst: array of Integer;    { old group id -> the new one it becomes }

  { Solids are told apart by their group id.  Carrying the original's id over
    to the copy would leave push/pull unable to tell them apart, and pulling a
    face on one would deform the other. }
  function Remap(Old: Integer): Integer;
  var
    N: Integer;
  begin
    if Old = 0 then Exit(0);
    for N := 0 to High(Src) do
      if Src[N] = Old then Exit(Dst[N]);
    Inc(FNextGrp);
    SetLength(Src, Length(Src) + 1);
    SetLength(Dst, Length(Dst) + 1);
    Src[High(Src)] := Old;
    Dst[High(Dst)] := FNextGrp;
    Result := FNextGrp;
  end;

begin
  Src := nil;
  Dst := nil;
  Base := FLive;
  for J := 0 to High(Idx) do
  begin
    I := Idx[J];
    if (I < 0) or (I >= Base) then Continue;
    SetLength(FEnts, FLive + 1);
    Finalize(FEnts[FLive]);
    FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
    FEnts[FLive] := FEnts[I];
    SetLength(FEnts[FLive].Poly, Length(FEnts[I].Poly));
    for K := 0 to High(FEnts[I].Poly) do
      FEnts[FLive].Poly[K] := P3(FEnts[I].Poly[K].X + D.X,
        FEnts[I].Poly[K].Y + D.Y, FEnts[I].Poly[K].Z + D.Z);
    FEnts[FLive].A := P3(FEnts[I].A.X + D.X, FEnts[I].A.Y + D.Y, FEnts[I].A.Z + D.Z);
    FEnts[FLive].B := P3(FEnts[I].B.X + D.X, FEnts[I].B.Y + D.Y, FEnts[I].B.Z + D.Z);
    FEnts[FLive].C := P3(FEnts[I].C.X + D.X, FEnts[I].C.Y + D.Y, FEnts[I].C.Z + D.Z);
    G := Remap(FEnts[I].Grp);
    FEnts[FLive].Grp := G;
    Inc(FLive);
  end;
  FSnapDirty := True;
end;

procedure TWorkDoc.ScreenBounds(const V: TProjector; I: Integer;
  out X0, Y0, X1, Y1: Double);
var
  K: Integer;
  P: TPointF;

  procedure Grow(const Q: TP3);
  var
    S: TPointF;
  begin
    S := Project(V, Q);
    X0 := Min(X0, S.X); X1 := Max(X1, S.X);
    Y0 := Min(Y0, S.Y); Y1 := Max(Y1, S.Y);
  end;

begin
  X0 := 1E30; Y0 := 1E30; X1 := -1E30; Y1 := -1E30;
  if (I < 0) or (I >= FLive) then Exit;
  Grow(FEnts[I].A);
  Grow(FEnts[I].B);
  if FEnts[I].Kind = ekArc then
  begin
    P := Project(V, FEnts[I].C);
    X0 := Min(X0, P.X - FEnts[I].R * V.Ppu);
    X1 := Max(X1, P.X + FEnts[I].R * V.Ppu);
    Y0 := Min(Y0, P.Y - FEnts[I].R * V.Ppu);
    Y1 := Max(Y1, P.Y + FEnts[I].R * V.Ppu);
  end;
  for K := 0 to High(FEnts[I].Poly) do
    Grow(FEnts[I].Poly[K]);
end;

function TWorkDoc.EdgeWeight(const A, B: TP3): Single;
const
  TOL = 1E-7;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FLive - 1 do
    if FEnts[I].Kind = ekLine then
      if (SamePt(FEnts[I].A, A, TOL) and SamePt(FEnts[I].B, B, TOL)) or
         (SamePt(FEnts[I].A, B, TOL) and SamePt(FEnts[I].B, A, TOL)) then
        Exit(FEnts[I].Weight);
end;

{ Hand every edge lying along this face's outline to the given group.  An
  edge counts when every point that defines it sits on the outline - both
  ends of a line, or a handful of samples round an arc. }
procedure TWorkDoc.ClaimOutline(Face, G: Integer);
const
  TOL = 1E-6;
  ARC_SAMPLES = 12;
var
  I, K, N, J: Integer;
  Poly: TP3Array;

  function OnOutline(const P: TP3): Boolean;
  var
    Q: Integer;
    T, Off: Double;
    A, B, D: TP3;
    L2: Double;
  begin
    Result := True;
    for Q := 0 to N - 1 do
    begin
      A := Poly[Q];
      B := Poly[(Q + 1) mod N];
      D := P3(B.X - A.X, B.Y - A.Y, B.Z - A.Z);
      L2 := D.X * D.X + D.Y * D.Y + D.Z * D.Z;
      if L2 < 1E-18 then Continue;
      T := ((P.X - A.X) * D.X + (P.Y - A.Y) * D.Y + (P.Z - A.Z) * D.Z) / L2;
      T := EnsureRange(T, 0, 1);
      Off := Dist(P, P3(A.X + D.X * T, A.Y + D.Y * T, A.Z + D.Z * T));
      if Off < TOL then Exit;
    end;
    Result := False;
  end;

begin
  Poly := FEnts[Face].Poly;
  N := Length(Poly);
  if N < 3 then Exit;
  for I := 0 to FLive - 1 do
  begin
    if FEnts[I].Grp <> 0 then Continue;
    case FEnts[I].Kind of
      ekLine:
        if OnOutline(FEnts[I].A) and OnOutline(FEnts[I].B) then
          FEnts[I].Grp := G;
      ekArc:
        begin
          J := 0;
          for K := 0 to ARC_SAMPLES do
            if OnOutline(ArcPoint(FEnts[I].C, FEnts[I].R,
                 FEnts[I].A0 + FEnts[I].Sweep * K / ARC_SAMPLES,
                 FEnts[I].Plane, FEnts[I].Nm)) then Inc(J);
          if J = ARC_SAMPLES + 1 then FEnts[I].Grp := G;
        end;
    end;
  end;
end;

{ Is P inside the flat loop, both taken in the loop's plane?  Even-odd, on
  the loop's own two axes.  uRegion has the general one; this unit cannot
  use uRegion, which uses it. }
function LoopContains(const P: TP3; const Loop: TP3Array; const N: TP3): Boolean;
var
  AU, AV: TP3;
  I, J: Integer;
  PX, PY, AX, AY, BX, BY: Double;
begin
  Result := False;
  AxesFromNormal(N, AU, AV);
  PX := Dot3(P, AU);
  PY := Dot3(P, AV);
  J := High(Loop);
  for I := 0 to High(Loop) do
  begin
    AX := Dot3(Loop[I], AU); AY := Dot3(Loop[I], AV);
    BX := Dot3(Loop[J], AU); BY := Dot3(Loop[J], AV);
    if ((AY > PY) <> (BY > PY)) and
       (PX < (BX - AX) * (PY - AY) / (BY - AY) + AX) then
      Result := not Result;
    J := I;
  end;
end;

function TWorkDoc.TunnelThrough(Index: Integer; const Top: TP3Array;
  const Nm: TP3; Dist: Double): Boolean;
var
  F, I, J, K, N, G, Far: Integer;
  FN, Mid: TP3;
  Size, Tol: Double;
  Quad: array[0..3] of TP3;
  Ink: TColor;
  Wt: Single;
  Holes: array of TP3Array;
  Near: Integer;
  Opened: Boolean;
begin
  Result := False;
  Near := -1;
  N := Length(Top);
  if N < 3 then Exit;
  { Whose solid is being pushed through?  A piece cut out of a wall carries
    the wall's group.  A window drawn in the middle of a wall is a loose face
    lying in the wall's opening, so the wall it lies on says. }
  G := 0;
  if FEnts[Index].Solid then G := FEnts[Index].Grp;
  if G = 0 then
  begin
    Mid := P3(0, 0, 0);
    for I := 0 to High(FEnts[Index].Poly) do
      Mid := P3(Mid.X + FEnts[Index].Poly[I].X, Mid.Y + FEnts[Index].Poly[I].Y,
                Mid.Z + FEnts[Index].Poly[I].Z);
    I := Length(FEnts[Index].Poly);
    Mid := P3(Mid.X / I, Mid.Y / I, Mid.Z / I);
    for F := 0 to FLive - 1 do
    begin
      if (F = Index) or (FEnts[F].Kind <> ekFace) or not FEnts[F].Solid or
         (FEnts[F].Grp = 0) or (Length(FEnts[F].Poly) < 3) then Continue;
      FN := FaceNormal(F);
      if Abs(Abs(Dot3(FN, Nm)) - 1) > 1E-6 then Continue;
      if Abs(Dot3(FN, P3(Mid.X - FEnts[F].Poly[0].X, Mid.Y - FEnts[F].Poly[0].Y,
                         Mid.Z - FEnts[F].Poly[0].Z))) > 1E-6 then Continue;
      if LoopContains(Mid, FEnts[F].Poly, FN) then
      begin
        G := FEnts[F].Grp;
        Near := F;
        Break;
      end;
    end;
  end;
  if G = 0 then Exit;
  Size := 0;
  { Dist is the push here, so the spread is worked out by hand }
  for I := 0 to N - 1 do
    Size := Max(Size, Sqrt(Sqr(Top[I].X - Top[0].X) + Sqr(Top[I].Y - Top[0].Y) +
                           Sqr(Top[I].Z - Top[0].Z)));
  Tol := 1E-6 * (1 + Size + Abs(Dist));

  { the face the push lands on: same solid, parallel, in the plane the far
    end has reached, and big enough to hold the whole opening }
  Mid := P3(0, 0, 0);
  for I := 0 to N - 1 do Mid := P3(Mid.X + Top[I].X, Mid.Y + Top[I].Y, Mid.Z + Top[I].Z);
  Mid := P3(Mid.X / N, Mid.Y / N, Mid.Z / N);
  Far := -1;
  for F := 0 to FLive - 1 do
  begin
    if (F = Index) or (FEnts[F].Kind <> ekFace) or (FEnts[F].Grp <> G) then Continue;
    if Length(FEnts[F].Poly) < 3 then Continue;
    FN := FaceNormal(F);
    if Abs(Abs(Dot3(FN, Nm)) - 1) > 1E-6 then Continue;
    if Abs(Dot3(FN, P3(Top[0].X - FEnts[F].Poly[0].X, Top[0].Y - FEnts[F].Poly[0].Y,
                       Top[0].Z - FEnts[F].Poly[0].Z))) > Tol then Continue;
    K := 0;
    for I := 0 to N - 1 do
      if LoopContains(Top[I], FEnts[F].Poly, FN) then Inc(K);
    if (K = N) and LoopContains(Mid, FEnts[F].Poly, FN) then
    begin
      Far := F;
      Break;
    end;
  end;
  if Far < 0 then Exit;

  Ink := FEnts[Index].Ink;
  Wt := EdgeWeight(FEnts[Index].Poly[0], FEnts[Index].Poly[1]);
  if Wt <= 0 then Wt := FEnts[Index].Weight;
  if Wt <= 0 then Wt := 1;

  { The near wall has to be open too.  When the window was drawn in the
    middle of it the wall already has the hole; when it was drawn touching
    an edge and the tiling did not divide the wall, it has not, and the wall
    would go on covering the mouth of the tunnel. }
  if Near >= 0 then
  begin
    Opened := False;
    Mid := P3(0, 0, 0);
    for I := 0 to High(FEnts[Index].Poly) do
      Mid := P3(Mid.X + FEnts[Index].Poly[I].X, Mid.Y + FEnts[Index].Poly[I].Y,
                Mid.Z + FEnts[Index].Poly[I].Z);
    I := Length(FEnts[Index].Poly);
    Mid := P3(Mid.X / I, Mid.Y / I, Mid.Z / I);
    FN := FaceNormal(Near);
    for I := 0 to High(FEnts[Near].Holes) do
      if LoopContains(Mid, FEnts[Near].Holes[I], FN) then Opened := True;
    if not Opened then
    begin
      SetLength(Holes, Length(FEnts[Near].Holes) + 1);
      for I := 0 to High(FEnts[Near].Holes) do Holes[I] := FEnts[Near].Holes[I];
      Holes[High(Holes)] := Copy(FEnts[Index].Poly, 0, Length(FEnts[Index].Poly));
      SetFaceHoles(Near, Holes);
    end;
  end;

  { the far face gets the opening }
  SetLength(Holes, Length(FEnts[Far].Holes) + 1);
  for I := 0 to High(FEnts[Far].Holes) do Holes[I] := FEnts[Far].Holes[I];
  Holes[High(Holes)] := Copy(Top, 0, N);
  SetFaceHoles(Far, Holes);

  { the walls line the tunnel, looking inward at the space it leaves; the
    edges at the far end and the creases along it are drawn, and a curved
    opening has its creases softened as an extrusion's are }
  { the opening's middle, so each wall can be turned to look at it }
  Mid := P3(0, 0, 0);
  for I := 0 to N - 1 do
    Mid := P3(Mid.X + FEnts[Index].Poly[I].X, Mid.Y + FEnts[Index].Poly[I].Y,
              Mid.Z + FEnts[Index].Poly[I].Z);
  Mid := P3(Mid.X / N, Mid.Y / N, Mid.Z / N);
  for I := 0 to N - 1 do
  begin
    J := (I + 1) mod N;
    Quad[0] := FEnts[Index].Poly[I]; Quad[1] := FEnts[Index].Poly[J];
    Quad[2] := Top[J];              Quad[3] := Top[I];
    { wound to look into the tunnel, whichever way the push went and
      whichever way round the opening was drawn - the winding of the pushed
      face and the sign of the push used to decide, and got it right only
      half the time }
    FN := Cross3(P3(Quad[1].X - Quad[0].X, Quad[1].Y - Quad[0].Y, Quad[1].Z - Quad[0].Z),
                 P3(Quad[3].X - Quad[0].X, Quad[3].Y - Quad[0].Y, Quad[3].Z - Quad[0].Z));
    if Dot3(FN, P3(Mid.X - Quad[0].X, Mid.Y - Quad[0].Y, Mid.Z - Quad[0].Z)) < 0 then
    begin
      Quad[1] := FEnts[Index].Poly[I]; Quad[0] := FEnts[Index].Poly[J];
      Quad[3] := Top[J];              Quad[2] := Top[I];
    end;
    AddFaceRaw(Quad, Ink, True);
    FEnts[FLive - 1].Grp := G;
    AddLine(FEnts[Index].Poly[I], Top[I], Ink, Wt, False);
    FEnts[FLive - 1].Grp := G;
    FEnts[FLive - 1].Soft := N >= 9;
    AddLine(Top[I], Top[J], Ink, Wt, False);
    FEnts[FLive - 1].Grp := G;
  end;

  { and the record of the tunnel, for the next one through this solid }
  AddBore(FEnts[Index].Poly, Top[0], G);
  FLastBore := FLive - 1;
  { and the pushed face is the hole now }
  Delete(Index);
  Dec(FLastBore);
  FSnapDirty := True;
  Result := True;
end;

function TWorkDoc.PushPull(Index: Integer; Dist: Double): Boolean;
var
  I, J, N, G: Integer;
  Nm: TP3;
  Base, Top, Rev: TP3Array;
  HBase, HTop, RevH: array of TP3Array;
  H, M: Integer;
  Quad: array[0..3] of TP3;
  Ink: TColor;
  Wt: Single;
begin
  Result := False;
  FLastBore := -1;
  if (Index < 0) or (Index >= FLive) or (FEnts[Index].Kind <> ekFace) then Exit;
  if Abs(Dist) < 1E-9 then Exit;

  N := Length(FEnts[Index].Poly);
  if N < 3 then Exit;
  Nm := FaceNormal(Index);
  Ink := FEnts[Index].Ink;

  { The sides and the top are drawn with the same pen as the outline they grew
    out of.  They used to be hardcoded to 1, so a box pulled from a rectangle
    drawn with a 4 pixel pen came out with four heavy lines round its base and
    hairlines everywhere else - which reads as something left behind. }
  Wt := EdgeWeight(FEnts[Index].Poly[0], FEnts[Index].Poly[1]);
  if Wt <= 0 then Wt := FEnts[Index].Weight;
  if Wt <= 0 then Wt := 1;

  { A face slides when it is the whole flat side of a solid; anything else
    has a block extruded out of it.

    This used to be "does it belong to a solid", which was right until you
    could cut a solid's face.  Half a box top still belongs to the solid, but
    pushing it has to lift that half out - sliding it would shear the box.
    Asking whether the face is a patch answers both cases with one question. }
  if FEnts[Index].Solid and not IsPatch(Index) then
  begin
    MoveFaceWith(Index, P3(Nm.X * Dist, Nm.Y * Dist, Nm.Z * Dist));
    Exit(True);
  end;

  SetLength(Base, N);
  SetLength(Top, N);
  for I := 0 to N - 1 do
  begin
    Base[I] := FEnts[Index].Poly[I];
    Top[I] := P3(Base[I].X + Nm.X * Dist,
                 Base[I].Y + Nm.Y * Dist,
                 Base[I].Z + Nm.Z * Dist);
  end;

  { Pushed clean through to the far side of its own solid, the shape is a
    hole, not a block: the far face gets the opening, the walls line the
    tunnel, and the pushed face itself is gone.  SketchUp does this when the
    push lands exactly on the opposite face, and it is the whole of how a
    duct gets a hole through a wall without drawing the hole twice and
    erasing two faces. }
  if TunnelThrough(Index, Top, Nm, Dist) then Exit(True);

  { Anything cut out of the face travels with it and gets walls of its own.

    A ring pushed up is a wall with a hole through the middle, and the hole
    needs a lining the same way the outside needs a face - otherwise you have
    a solid whose inside is open to the air, which reads as the push having
    swallowed the opening.  This is the offset-then-push case: draw a
    rectangle, offset it, push the border, and what should come up is a
    foundation wall rather than a filled block. }
  SetLength(HBase, Length(FEnts[Index].Holes));
  SetLength(HTop, Length(FEnts[Index].Holes));
  for H := 0 to High(FEnts[Index].Holes) do
  begin
    M := Length(FEnts[Index].Holes[H]);
    SetLength(HBase[H], M);
    SetLength(HTop[H], M);
    for I := 0 to M - 1 do
    begin
      HBase[H][I] := FEnts[Index].Holes[H][I];
      HTop[H][I] := P3(HBase[H][I].X + Nm.X * Dist,
                       HBase[H][I].Y + Nm.Y * Dist,
                       HBase[H][I].Z + Nm.Z * Dist);
    end;
  end;

  { The picked face travels to the new position and a copy stays behind, so
    the result is a closed solid rather than an open shell.  The copy is
    wound the other way round so its normal points out of the solid, which is
    what lets the renderer hide the inside. }
  { one identity for everything this push makes, so a later push on any of
    its faces moves this solid and nothing that merely touches it }
  if FEnts[Index].Grp = 0 then
  begin
    Inc(FNextGrp);
    FEnts[Index].Grp := FNextGrp;
  end;
  G := FEnts[Index].Grp;

  { The edges round the base belong to the solid now.  Without this they stay
    loose, and the next time the flat areas are worked out from the loose
    edges the base would come back as a face of its own, sitting inside the
    box it was pulled out of. }
  ClaimOutline(Index, G);

  SetLength(Rev, N);
  if Dist >= 0 then
  begin
    { travelling along the face's own normal: the moved face already faces
      out of the new solid, and the copy left behind is reversed }
    for I := 0 to N - 1 do FEnts[Index].Poly[I] := Top[I];
    for I := 0 to N - 1 do Rev[I] := Base[N - 1 - I];
  end
  else
  begin
    { travelling against it, so the two swap round }
    for I := 0 to N - 1 do FEnts[Index].Poly[I] := Top[N - 1 - I];
    for I := 0 to N - 1 do Rev[I] := Base[I];
  end;
  FEnts[Index].Solid := True;
  { the face that travelled takes its openings with it }
  for H := 0 to High(HTop) do
  begin
    M := Length(HTop[H]);
    SetLength(FEnts[Index].Holes[H], M);
    if Dist >= 0 then
      for I := 0 to M - 1 do FEnts[Index].Holes[H][I] := HTop[H][I]
    else
      for I := 0 to M - 1 do FEnts[Index].Holes[H][I] := HTop[H][M - 1 - I];
  end;

  AddFaceRaw(Rev, Ink, True);
  FEnts[FLive - 1].Grp := G;
  { and so does the one left behind, wound to match its own outline }
  if Length(HBase) > 0 then
  begin
    SetLength(RevH, Length(HBase));
    for H := 0 to High(HBase) do
    begin
      M := Length(HBase[H]);
      SetLength(RevH[H], M);
      if Dist >= 0 then
        for I := 0 to M - 1 do RevH[H][I] := HBase[H][M - 1 - I]
      else
        for I := 0 to M - 1 do RevH[H][I] := HBase[H][I];
    end;
    SetFaceHoles(FLive - 1, RevH);
  end;

  { walls, plus the edges so it reads as a solid in wireframe too }
  for I := 0 to N - 1 do
  begin
    J := (I + 1) mod N;
    { the walls turn the same way round as the caps }
    if Dist >= 0 then
    begin
      Quad[0] := Base[I]; Quad[1] := Base[J];
      Quad[2] := Top[J];  Quad[3] := Top[I];
    end
    else
    begin
      Quad[0] := Base[J]; Quad[1] := Base[I];
      Quad[2] := Top[I];  Quad[3] := Top[J];
    end;
    AddFaceRaw(Quad, Ink, True);
    FEnts[FLive - 1].Grp := G;
    AddLine(Base[I], Top[I], Ink, Wt, False);
    FEnts[FLive - 1].Grp := G;
    { Many sides means the outline was a curve to begin with, so the creases
      running down the extrusion are not real edges - they are how a round
      surface is stored.  Nine or more and they are softened. }
    FEnts[FLive - 1].Soft := N >= 9;
    AddLine(Top[I], Top[J], Ink, Wt, False);
    FEnts[FLive - 1].Grp := G;
  end;

  { The lining of each opening.  Same walls, wound the other way round,
    because the material is outside a hole rather than inside it - so its
    faces have to look inward, at the space the hole leaves. }
  for H := 0 to High(HBase) do
  begin
    M := Length(HBase[H]);
    for I := 0 to M - 1 do
    begin
      J := (I + 1) mod M;
      if Dist >= 0 then
      begin
        Quad[0] := HBase[H][J]; Quad[1] := HBase[H][I];
        Quad[2] := HTop[H][I];  Quad[3] := HTop[H][J];
      end
      else
      begin
        Quad[0] := HBase[H][I]; Quad[1] := HBase[H][J];
        Quad[2] := HTop[H][J];  Quad[3] := HTop[H][I];
      end;
      AddFaceRaw(Quad, Ink, True);
      FEnts[FLive - 1].Grp := G;
      AddLine(HBase[H][I], HTop[H][I], Ink, Wt, False);
      FEnts[FLive - 1].Grp := G;
      FEnts[FLive - 1].Soft := M >= 9;
      AddLine(HTop[H][I], HTop[H][J], Ink, Wt, False);
      FEnts[FLive - 1].Grp := G;
    end;
  end;

  FSnapDirty := True;
  Result := True;
end;

{ The loop of chained lines ending at the last entity, if it closes. }

{ Where two segments come closest.  They are treated as crossing only if
  that gap is negligible and the meeting point is properly inside both. }
{ Where a point sits along a segment, when it sits on it at all and not at
  either end.  A line drawn *from* the middle of another one makes a T, not a
  cross, and SegCross turns that down - rightly, because the meeting point is
  already an endpoint.  But the line being met is still cut in two by it, and
  each half wants a middle of its own. }
function Lerp3(const A, B: TP3; T: Double): TP3;
begin
  Result := P3(A.X + (B.X - A.X) * T, A.Y + (B.Y - A.Y) * T,
               A.Z + (B.Z - A.Z) * T);
end;

function PointOnSeg(const P, A, B: TP3; out T: Double): Boolean;
var
  DX, DY, DZ, L2: Double;
  Q: TP3;
begin
  Result := False;
  T := 0;
  DX := B.X - A.X;
  DY := B.Y - A.Y;
  DZ := B.Z - A.Z;
  L2 := DX * DX + DY * DY + DZ * DZ;
  if L2 < 1E-12 then Exit;
  T := ((P.X - A.X) * DX + (P.Y - A.Y) * DY + (P.Z - A.Z) * DZ) / L2;
  if (T <= 0.001) or (T >= 0.999) then Exit;
  Q := P3(A.X + DX * T, A.Y + DY * T, A.Z + DZ * T);
  Result := Dist(P, Q) <= Sqrt(L2) * 1E-6 + 1E-9;
end;

function SegCross(const A1, A2, B1, B2: TP3; out P: TP3;
  out TA, TB: Double): Boolean;
var
  UX, UY, UZ, VX, VY, VZ, WX, WY, WZ: Double;
  A, B, C, D, E, Den, Scale: Double;
  PA, PB: TP3;
begin
  Result := False;
  TA := 0;
  TB := 0;
  P := A1;

  UX := A2.X - A1.X; UY := A2.Y - A1.Y; UZ := A2.Z - A1.Z;
  VX := B2.X - B1.X; VY := B2.Y - B1.Y; VZ := B2.Z - B1.Z;
  WX := A1.X - B1.X; WY := A1.Y - B1.Y; WZ := A1.Z - B1.Z;

  A := UX * UX + UY * UY + UZ * UZ;
  B := UX * VX + UY * VY + UZ * VZ;
  C := VX * VX + VY * VY + VZ * VZ;
  D := UX * WX + UY * WY + UZ * WZ;
  E := VX * VX * 0 + VX * WX + VY * WY + VZ * WZ;

  Den := A * C - B * B;
  if (Den < 1E-12) or (A < 1E-12) or (C < 1E-12) then Exit;   // parallel

  TA := (B * E - C * D) / Den;
  TB := (A * E - B * D) / Den;
  { strictly inside, so touching endpoints do not count - those are already
    endpoint snaps }
  if (TA <= 0.001) or (TA >= 0.999) or (TB <= 0.001) or (TB >= 0.999) then Exit;

  PA := P3(A1.X + UX * TA, A1.Y + UY * TA, A1.Z + UZ * TA);
  PB := P3(B1.X + VX * TB, B1.Y + VY * TB, B1.Z + VZ * TB);
  Scale := Sqrt(A) + Sqrt(C);
  if Dist(PA, PB) > Scale * 1E-6 + 1E-9 then Exit;            // skew, not crossing

  P := PA;
  Result := True;
end;

{ Rebuilt only when the document changes, because it is quadratic in the
  number of lines and the cursor asks for it on every mouse move. }
procedure TWorkDoc.RebuildSnapCache;
const
  MAX_LINES = 500;
var
  I, J, N, LineCount: Integer;
  P: TP3;
  TA, TB: Double;
  Cuts: array of array of Double;
  Idx: array of Integer;
  Tmp: Double;
  K, M: Integer;
  MidKind: TSnapKind;

  procedure Put(const Q: TP3; Kind: TSnapKind);
  begin
    if N >= Length(FSnapCache) then SetLength(FSnapCache, Max(32, N * 2));
    FSnapCache[N].P := Q;
    FSnapCache[N].Kind := Kind;
    Inc(N);
  end;

  { Note that something crosses line Which at parameter T, once. }
  procedure AddCut(Which: Integer; T: Double);
  var
    Q: Integer;
  begin
    for Q := 0 to High(Cuts[Which]) do
      if Abs(Cuts[Which][Q] - T) < 1E-9 then Exit;
    SetLength(Cuts[Which], Length(Cuts[Which]) + 1);
    Cuts[Which][High(Cuts[Which])] := T;
  end;

begin
  N := 0;
  SetLength(FSnapCache, 128);

  { The origin is always there, drawing or no drawing.  Put in with everything
    else rather than tested for separately, so it wins and loses contests by
    the same rules as any other definite point. }
  Put(P3(0, 0, 0), snOrigin);

  for I := 0 to FLive - 1 do
    case FEnts[I].Kind of
      ekLine:
        begin
          Put(FEnts[I].A, snEndpoint);
          Put(FEnts[I].B, snEndpoint);
        end;
      ekArc:
        begin
          Put(FEnts[I].A, snEndpoint);
          Put(FEnts[I].B, snEndpoint);
          Put(FEnts[I].C, snCenter);
        end;
      { The middle of a face.  Drawing a circle from the center of a square is
        a thing you do constantly, and getting there otherwise means resting on
        two edge midpoints and crossing their guides.  One point per face, so
        it is not noise. }
      ekFace:
        if Length(FEnts[I].Poly) >= 3 then
        begin
          P := P3(0, 0, 0);
          for K := 0 to High(FEnts[I].Poly) do
          begin
            P.X := P.X + FEnts[I].Poly[K].X;
            P.Y := P.Y + FEnts[I].Poly[K].Y;
            P.Z := P.Z + FEnts[I].Poly[K].Z;
          end;
          K := Length(FEnts[I].Poly);
          Put(P3(P.X / K, P.Y / K, P.Z / K), snCenter);
        end;

      { a guide point is exactly the kind of thing you put down to aim at }
      ekGuide:
        if Dist(FEnts[I].A, FEnts[I].B) < 1E-9 then Put(FEnts[I].A, snEndpoint);

      { Nothing snaps to a dimension or a note.  They are annotation sitting
        beside the drawing, and having the cursor jump to one while drawing a
        line is only ever in the way. }
      ekDim, ekText: ;
    end;

  { every line gets a list of the parameters where something crosses it }
  SetLength(Idx, FLive);
  LineCount := 0;
  for I := 0 to FLive - 1 do
    if FEnts[I].Kind = ekLine then
    begin
      Idx[LineCount] := I;
      Inc(LineCount);
    end;

  SetLength(Cuts, LineCount);
  if LineCount <= MAX_LINES then
    for I := 0 to LineCount - 2 do
      for J := I + 1 to LineCount - 1 do
        if SegCross(FEnts[Idx[I]].A, FEnts[Idx[I]].B,
                    FEnts[Idx[J]].A, FEnts[Idx[J]].B, P, TA, TB) then
        begin
          Put(P, snCross);
          AddCut(I, TA);
          AddCut(J, TB);
        end
        else
        begin
          { A T-junction cuts too.  Draw a line from the middle of one side of
            a rectangle to the middle of the other and each half of the side
            you started from is a separate run - and wants its own middle to
            aim at.  Without this the whole tic-tac-toe way of dividing a
            shape gave nothing new to snap to. }
          if PointOnSeg(FEnts[Idx[J]].A, FEnts[Idx[I]].A, FEnts[Idx[I]].B, TA) then
            AddCut(I, TA);
          if PointOnSeg(FEnts[Idx[J]].B, FEnts[Idx[I]].A, FEnts[Idx[I]].B, TA) then
            AddCut(I, TA);
          if PointOnSeg(FEnts[Idx[I]].A, FEnts[Idx[J]].A, FEnts[Idx[J]].B, TB) then
            AddCut(J, TB);
          if PointOnSeg(FEnts[Idx[I]].B, FEnts[Idx[J]].A, FEnts[Idx[J]].B, TB) then
            AddCut(J, TB);
        end;

  { a crossed line is really several sub-segments, so give each of them a
    midpoint of its own }
  for I := 0 to LineCount - 1 do
  begin
    SetLength(Cuts[I], Length(Cuts[I]) + 2);
    Cuts[I][High(Cuts[I]) - 1] := 0;
    Cuts[I][High(Cuts[I])] := 1;
    for K := 1 to High(Cuts[I]) do
    begin
      Tmp := Cuts[I][K];
      M := K - 1;
      while (M >= 0) and (Cuts[I][M] > Tmp) do
      begin
        Cuts[I][M + 1] := Cuts[I][M];
        Dec(M);
      end;
      Cuts[I][M + 1] := Tmp;
    end;
    { an uncrossed line has one piece, and its middle is the real midpoint;
      anything else is a piece of a line and ranks well below it }
    if Length(Cuts[I]) > 2 then MidKind := snSubMid else MidKind := snMidpoint;
    for K := 0 to High(Cuts[I]) - 1 do
    begin
      Tmp := (Cuts[I][K] + Cuts[I][K + 1]) / 2;
      if Cuts[I][K + 1] - Cuts[I][K] < 1E-6 then Continue;
      Put(P3(FEnts[Idx[I]].A.X + (FEnts[Idx[I]].B.X - FEnts[Idx[I]].A.X) * Tmp,
             FEnts[Idx[I]].A.Y + (FEnts[Idx[I]].B.Y - FEnts[Idx[I]].A.Y) * Tmp,
             FEnts[Idx[I]].A.Z + (FEnts[Idx[I]].B.Z - FEnts[Idx[I]].A.Z) * Tmp),
          MidKind);
    end;
  end;

  SetLength(FSnapCache, N);
  FSnapDirty := False;
end;

constructor TWorkDoc.Create;
begin
  inherited Create;
  FSnapDirty := True;
end;

procedure TWorkDoc.SnapPoints(out Pts: TP3Array);
var
  I: Integer;
begin
  if FSnapDirty then RebuildSnapCache;
  SetLength(Pts, Length(FSnapCache));
  for I := 0 to High(FSnapCache) do
    Pts[I] := FSnapCache[I].P;
end;

function TWorkDoc.Outline(const V: TProjector; I: Integer): TPointFArray;
var
  K, Steps: Integer;
  Ang: Double;
  DG: TDimGeom;
begin
  Result := nil;
  if (I < 0) or (I >= FLive) then Exit;
  case FEnts[I].Kind of
    ekArc:
      begin
        Steps := ArcSteps(FEnts[I]);
        SetLength(Result, Steps + 1);
        for K := 0 to Steps do
        begin
          Ang := FEnts[I].A0 + FEnts[I].Sweep * K / Steps;
          Result[K] := Project(V, ArcPoint(FEnts[I].C, FEnts[I].R, Ang, FEnts[I].Plane, FEnts[I].Nm));
        end;
      end;
    ekFace:
      begin
        SetLength(Result, Length(FEnts[I].Poly) + 1);
        for K := 0 to High(FEnts[I].Poly) do
          Result[K] := Project(V, FEnts[I].Poly[K]);
        if Length(FEnts[I].Poly) > 0 then
          Result[High(Result)] := Result[0];
      end;
    ekBore: ;
    ekGuide:
      begin
        SetLength(Result, 2);
        if Dist(FEnts[I].A, FEnts[I].B) < 1E-9 then
        begin
          Result[0] := Project(V, FEnts[I].A);
          Result[1] := Result[0];
        end
        else
        begin
          DG.A := Project(V, FEnts[I].A);
          Result[0] := DG.A;
          Result[1] := Project(V, FEnts[I].B);
        end;
      end;
    ekDim:
      begin
        { the drawn line and its two witness lines, so highlighting a
          dimension marks where it actually is }
        if not DimGeometry(V, FEnts[I].A, FEnts[I].B, FEnts[I].C,
             usImperial, DG, FEnts[I].Txt) then Exit;
        SetLength(Result, 6);
        Result[0] := DG.A;   Result[1] := DG.W1;
        Result[2] := DG.LA;  Result[3] := DG.LB;
        Result[4] := DG.W2;  Result[5] := DG.B;
      end;
    ekText:
      begin
        SetLength(Result, 1);
        Result[0] := Project(V, FEnts[I].A);
      end;
  else
    begin
      SetLength(Result, 2);
      Result[0] := Project(V, FEnts[I].A);
      Result[1] := Project(V, FEnts[I].B);
    end;
  end;
end;

{ Erasing a line that divides two regions was deleting one of the regions
  instead: a face is hit-tested on the segment between its first and last
  points, and for a face closed along that very edge, that segment lies
  exactly on top of the line.  So the eraser looks for an edge first and
  only falls back to anything else. }
{ How far the pointer is from an arc as it is actually drawn: walk the same
  segments the renderer walks, over the real sweep. }
function ArcScreenDist(const V: TProjector; const E: TWorkEnt;
  SX, SY: Double): Double;
var
  STEPS: Integer;
  K: Integer;
  Ang: Double;
  PA, PB: TPointF;
begin
  STEPS := ArcSteps(E);
  Result := 1E30;
  PA := Project(V, ArcPoint(E.C, E.R, E.A0, E.Plane, E.Nm));
  for K := 1 to STEPS do
  begin
    Ang := E.A0 + E.Sweep * K / STEPS;
    PB := Project(V, ArcPoint(E.C, E.R, Ang, E.Plane, E.Nm));
    Result := Min(Result, DistToSeg(SX, SY, PA.X, PA.Y, PB.X, PB.Y));
    PA := PB;
  end;
end;

function AxisSnap(const V: TProjector; SX, SY, TolPx: Double;
  out P: TP3; out Axis: Integer): Boolean;
var
  K: Integer;
  O, U: TPointF;
  D, T, Len, Best: Double;
  Dir, Q: TP3;
begin
  Result := False;
  Axis := -1;
  P := P3(0, 0, 0);
  O := Project(V, P3(0, 0, 0));
  if IsNan(O.X) or IsNan(O.Y) or IsInfinite(O.X) or IsInfinite(O.Y) then Exit;
  Best := TolPx;

  for K := 0 to 2 do
  begin
    case K of
      0: Dir := P3(1, 0, 0);
      1: Dir := P3(0, 1, 0);
    else Dir := P3(0, 0, 1);
    end;
    U := Project(V, Dir);
    U := PtF(U.X - O.X, U.Y - O.Y);
    Len := Sqrt(U.X * U.X + U.Y * U.Y);
    { An axis pointing at the camera is a dot on the glass, and every point
      on it is under the cursor at once - PLAN looks down Z.  There is no
      honest answer, so it is not offered. }
    if Len < 1E-6 then Continue;

    { how far along it the cursor is, and how far off it - the projection is
      parallel, so one world unit is Len pixels wherever you are on the line }
    T := ((SX - O.X) * U.X + (SY - O.Y) * U.Y) / (Len * Len);
    D := Abs((SX - O.X) * U.Y - (SY - O.Y) * U.X) / Len;
    if D >= Best then Continue;

    Q := P3(Dir.X * T, Dir.Y * T, Dir.Z * T);
    Best := D;
    Axis := K;
    P := Q;
    Result := True;
  end;
end;

function TWorkDoc.EdgeSnap(const V: TProjector; SX, SY, TolPx: Double;
  out P: TP3; out Ent: Integer): Boolean;
var
  I, K: Integer;
  Best: Double;
  QA, QB: TP3;

  { Project the segment, find the nearest point along it on screen, then read
    the same fraction back off the model segment.  The projection is affine,
    so the two fractions are the same number. }
  procedure Try_(const MA, MB: TP3);
  var
    PA, PB: TPointF;
    DX, DY, L2, T, D: Double;
  begin
    PA := Project(V, MA);
    PB := Project(V, MB);
    DX := PB.X - PA.X;
    DY := PB.Y - PA.Y;
    L2 := DX * DX + DY * DY;
    if L2 < 1E-12 then Exit;
    T := EnsureRange(((SX - PA.X) * DX + (SY - PA.Y) * DY) / L2, 0, 1);
    D := Sqrt(Sqr(SX - (PA.X + DX * T)) + Sqr(SY - (PA.Y + DY * T)));
    if D < Best then
    begin
      Best := D;
      P := P3(MA.X + (MB.X - MA.X) * T, MA.Y + (MB.Y - MA.Y) * T,
              MA.Z + (MB.Z - MA.Z) * T);
      Ent := I;
    end;
  end;

begin
  P := P3(0, 0, 0);
  Ent := -1;
  Best := TolPx;
  for I := 0 to FLive - 1 do
    case FEnts[I].Kind of
      ekLine: Try_(FEnts[I].A, FEnts[I].B);
      { a point on a guide line counts - that is what guides are for }
      ekGuide:
        if Dist(FEnts[I].A, FEnts[I].B) > 1E-9 then
          Try_(P3(FEnts[I].A.X + (FEnts[I].A.X - FEnts[I].B.X) * 2000,
                  FEnts[I].A.Y + (FEnts[I].A.Y - FEnts[I].B.Y) * 2000,
                  FEnts[I].A.Z + (FEnts[I].A.Z - FEnts[I].B.Z) * 2000),
               P3(FEnts[I].B.X + (FEnts[I].B.X - FEnts[I].A.X) * 2000,
                  FEnts[I].B.Y + (FEnts[I].B.Y - FEnts[I].A.Y) * 2000,
                  FEnts[I].B.Z + (FEnts[I].B.Z - FEnts[I].A.Z) * 2000));
      ekArc:
        begin
          QA := ArcPoint(FEnts[I].C, FEnts[I].R, FEnts[I].A0, FEnts[I].Plane, FEnts[I].Nm);
          for K := 1 to 24 do
          begin
            QB := ArcPoint(FEnts[I].C, FEnts[I].R,
                    FEnts[I].A0 + FEnts[I].Sweep * K / 24, FEnts[I].Plane, FEnts[I].Nm);
            Try_(QA, QB);
            QA := QB;
          end;
        end;
    end;
  Result := Ent >= 0;
end;

{ How far the pointer is from a guide as it is drawn - the whole infinite
  line, not the one-unit stub that records its direction. }
function GuideScreenDist(const V: TProjector; const E: TWorkEnt;
  SX, SY: Double): Double;
var
  PA, PB: TPointF;
  D: TP3;
  L: Double;
begin
  PA := Project(V, E.A);
  if Dist(E.A, E.B) < 1E-9 then
  begin
    Result := Sqrt(Sqr(SX - PA.X) + Sqr(SY - PA.Y));
    Exit;
  end;
  D := P3(E.B.X - E.A.X, E.B.Y - E.A.Y, E.B.Z - E.A.Z);
  L := Sqrt(Sqr(D.X) + Sqr(D.Y) + Sqr(D.Z));
  if L < 1E-9 then Exit(1E30);
  PA := Project(V, P3(E.A.X - D.X / L * 5000, E.A.Y - D.Y / L * 5000,
                      E.A.Z - D.Z / L * 5000));
  PB := Project(V, P3(E.A.X + D.X / L * 5000, E.A.Y + D.Y / L * 5000,
                      E.A.Z + D.Z / L * 5000));
  Result := DistToSeg(SX, SY, PA.X, PA.Y, PB.X, PB.Y);
end;

function TWorkDoc.HitEdge(const V: TProjector; SX, SY, TolPx: Double): Integer;
var
  I: Integer;
  D, Best: Double;
  PA, PB: TPointF;
  DG: TDimGeom;
begin
  Result := -1;
  Best := TolPx;
  for I := FLive - 1 downto 0 do
  begin
    if not (FEnts[I].Kind in [ekLine, ekArc, ekDim, ekGuide]) then Continue;
    if FEnts[I].Kind = ekGuide then
      D := GuideScreenDist(V, FEnts[I], SX, SY)
    else if FEnts[I].Kind = ekArc then
      { A circle in the model is an ellipse on screen once its plane is tilted
        away from the camera, and a part arc is not a whole circle either.
        Measuring against the drawn segments is the only test that holds up in
        ISO and orbit. }
      D := ArcScreenDist(V, FEnts[I], SX, SY)
    else if FEnts[I].Kind = ekDim then
    begin
      { A dimension is drawn off to one side of what it measures.  Testing
        against the two measured points would mean clicking an invisible line
        through the geometry to erase it, which is not where anyone aims. }
      if not DimGeometry(V, FEnts[I].A, FEnts[I].B, FEnts[I].C, usImperial, DG,
           FEnts[I].Txt) then Continue;
      D := Min(DistToSeg(SX, SY, DG.LA.X, DG.LA.Y, DG.LB.X, DG.LB.Y),
           Min(DistToSeg(SX, SY, DG.A.X, DG.A.Y, DG.W1.X, DG.W1.Y),
               DistToSeg(SX, SY, DG.B.X, DG.B.Y, DG.W2.X, DG.W2.Y)));
    end
    else
    begin
      PA := Project(V, FEnts[I].A);
      PB := Project(V, FEnts[I].B);
      D := DistToSeg(SX, SY, PA.X, PA.Y, PB.X, PB.Y);
    end;
    if D < Best then
    begin
      { Out of sight behind a panel is not what anybody meant to click.
        Sampled at three places along it rather than one, so an edge that
        comes out from behind something is still there to be had by the part
        of it you can see. }
      if (FEnts[I].Kind in [ekLine, ekArc]) and
         HiddenAt(V, Lerp3(FEnts[I].A, FEnts[I].B, 0.5)) and
         HiddenAt(V, Lerp3(FEnts[I].A, FEnts[I].B, 0.2)) and
         HiddenAt(V, Lerp3(FEnts[I].A, FEnts[I].B, 0.8)) then Continue;
      Best := D;
      Result := I;
    end;
  end;
end;

{ Is this point of the model hidden behind a face?

  A filled panel is opaque.  You cannot see the back wall through the roof,
  so you should not be able to pick it through the roof either - and being
  able to was making it hard to put anything on a sloped face at all, because
  the thing under the cursor kept turning out to be something behind it.

  The renderer has known this all along and has its own version, working off
  the depth sort it has already done.  This is the same test standing on its
  own, for the times something needs asking outside a repaint. }
function TWorkDoc.HiddenAt(const V: TProjector; const P: TP3): Boolean;
var
  I, A, B, N, H, M: Integer;
  SP: TPointF;
  Inside: Boolean;
  Nm, Look: TP3;
  Den, T: Double;
  Poly, HP: array of TPointF;
begin
  Result := False;
  SP := Project(V, P);
  Look := ViewDir(V);
  for I := 0 to FLive - 1 do
  begin
    if FEnts[I].Kind <> ekFace then Continue;
    N := Length(FEnts[I].Poly);
    if N < 3 then Continue;
    Nm := FaceNormal(I);
    { A face the point lies in cannot hide it.  Every edge of a solid lies in
      the plane of the faces either side of it, and without this each one
      would hide itself. }
    if Abs(Dot3(Nm, P) - Dot3(Nm, FEnts[I].Poly[0])) < 1E-6 then Continue;
    Den := Dot3(Nm, Look);
    if Abs(Den) < 1E-12 then Continue;      { edge-on, hides nothing }
    { Where the line of sight through P meets this face's plane.  ViewDir
      points from the drawing towards the camera - the sense the face culling
      uses, where a face turned towards you has a positive dot with it - so a
      face in front of P is at a positive step along it. }
    T := (Dot3(Nm, FEnts[I].Poly[0]) - Dot3(Nm, P)) / Den;
    if T <= 1E-9 then Continue;
    SetLength(Poly, N);
    for A := 0 to N - 1 do Poly[A] := Project(V, FEnts[I].Poly[A]);
    Inside := False;
    B := N - 1;
    for A := 0 to N - 1 do
    begin
      if ((Poly[A].Y > SP.Y) <> (Poly[B].Y > SP.Y)) and
         (SP.X < (Poly[B].X - Poly[A].X) * (SP.Y - Poly[A].Y) /
                 (Poly[B].Y - Poly[A].Y) + Poly[A].X) then
        Inside := not Inside;
      B := A;
    end;
    { and out again through anything cut from it: a wall does not hide what
      is seen through its window }
    if Inside then
      for H := 0 to High(FEnts[I].Holes) do
      begin
        M := Length(FEnts[I].Holes[H]);
        if M < 3 then Continue;
        SetLength(HP, M);
        for A := 0 to M - 1 do HP[A] := Project(V, FEnts[I].Holes[H][A]);
        B := M - 1;
        for A := 0 to M - 1 do
        begin
          if ((HP[A].Y > SP.Y) <> (HP[B].Y > SP.Y)) and
             (SP.X < (HP[B].X - HP[A].X) * (SP.Y - HP[A].Y) /
                     (HP[B].Y - HP[A].Y) + HP[A].X) then
            Inside := not Inside;
          B := A;
        end;
      end;
    if Inside then Exit(True);
  end;
end;

procedure TWorkDoc.MoveNote(Index: Integer; const From, ToPt, Grab: TP3);
begin
  if (Index < 0) or (Index >= FLive) then Exit;
  if FEnts[Index].Kind <> ekText then Exit;
  FEnts[Index].A := P3(From.X + (ToPt.X - Grab.X),
                       From.Y + (ToPt.Y - Grab.Y),
                       From.Z + (ToPt.Z - Grab.Z));
  FSnapDirty := True;
end;

function TWorkDoc.HitNote(SX, SY: Double): Integer;
var
  I: Integer;
begin
  { Last drawn wins, which is the one on top. }
  for I := FLive - 1 downto 0 do
    if (FEnts[I].Kind = ekText) and (FEnts[I].BoxR > FEnts[I].BoxL) and
       (SX >= FEnts[I].BoxL) and (SX <= FEnts[I].BoxR) and
       (SY >= FEnts[I].BoxT) and (SY <= FEnts[I].BoxB) then
      Exit(I);
  Result := -1;
end;

function TWorkDoc.HitTest(const V: TProjector; SX, SY, TolPx: Double): Integer;
var
  I: Integer;
  D: Double;
  PA, PB: TPointF;
  DG: TDimGeom;
begin
  for I := FLive - 1 downto 0 do
  begin
    case FEnts[I].Kind of
      ekArc:
        D := ArcScreenDist(V, FEnts[I], SX, SY);
      ekText:
        begin
          { The words are the note.  It was measured to its anchor point,
            which is a dot at the corner of the box, so clicking on the text
            itself - the only part anybody thinks of as the note - picked
            nothing unless the box happened to be small.  Inside the box the
            note is under the cursor, full stop; outside it, the anchor still
            counts, for a note whose box has not been drawn yet. }
          if (SX >= FEnts[I].BoxL) and (SX <= FEnts[I].BoxR) and
             (SY >= FEnts[I].BoxT) and (SY <= FEnts[I].BoxB) and
             (FEnts[I].BoxR > FEnts[I].BoxL) then
            D := 0
          else
          begin
            PA := Project(V, FEnts[I].A);
            D := Sqrt(Sqr(SX - PA.X) + Sqr(SY - PA.Y));
          end;
        end;
      ekGuide:
        D := GuideScreenDist(V, FEnts[I], SX, SY);
      ekBore, ekFace:
        D := 1E30;   { not things to pick by their line }
      ekDim:
        { the drawn line and its witness lines, not the invisible chord
          through the geometry - that is where the eraser is aimed }
        if DimGeometry(V, FEnts[I].A, FEnts[I].B, FEnts[I].C, usImperial, DG,
             FEnts[I].Txt) then
          D := Min(DistToSeg(SX, SY, DG.LA.X, DG.LA.Y, DG.LB.X, DG.LB.Y),
               Min(DistToSeg(SX, SY, DG.A.X, DG.A.Y, DG.W1.X, DG.W1.Y),
                   DistToSeg(SX, SY, DG.B.X, DG.B.Y, DG.W2.X, DG.W2.Y)))
        else
          D := 1E30;
    else
      begin
        PA := Project(V, FEnts[I].A);
        PB := Project(V, FEnts[I].B);
        D := DistToSeg(SX, SY, PA.X, PA.Y, PB.X, PB.Y);
      end;
    end;
    if D <= TolPx then
    begin
      { An edge behind a panel is out of sight, so it is not what was meant.
        Notes and dimensions are drawn over the top of everything and stay
        pickable wherever they are. }
      if FEnts[I].Kind in [ekLine, ekArc] then
      begin
        { the distance was worked out above; it was being worked out again
          here into a variable nothing read, on every entity of every hit
          test - which is every time the mouse moves }
        if HiddenAt(V, Lerp3(FEnts[I].A, FEnts[I].B, 0.5)) and
           HiddenAt(V, Lerp3(FEnts[I].A, FEnts[I].B, 0.25)) and
           HiddenAt(V, Lerp3(FEnts[I].A, FEnts[I].B, 0.75)) then
          Continue;
      end;
      Exit(I);
    end;
  end;
  Result := -1;
end;

{ One list feeds both snapping and inference, so a crossing and the
  midpoints it creates are just as snappable as an original endpoint.  A
  small bias keeps the more definite kinds winning a close contest. }
function TWorkDoc.BestSnap(const V: TProjector; SX, SY, TolPx: Double;
  out Hit: TSnapHit): Boolean;
const
  { snOnEdge never comes out of this list - the cursor finds it separately -
    so its bias is only here to keep the array the right length }
  { The origin sits just under an endpoint.  It is a landmark and it should
    beat a midpoint or a centre, but a corner somebody actually drew is more
    likely to be the thing being aimed at than the place the model happens to
    start - and near the origin is exactly where people draw corners. }
  BIAS: array[TSnapKind] of Double =
    (0, 0, 3.5, 1.0, 2.0, 1.5, 0.25, 0, 0, 3.0, 0);   { snOnFace: found separately too }
var
  I: Integer;
  P: TPointF;
  D, Best: Double;
begin
  if FSnapDirty then RebuildSnapCache;

  Best := 1E30;
  Hit.Kind := snNone;
  Hit.P := P3(0, 0, 0);

  for I := 0 to High(FSnapCache) do
  begin
    P := Project(V, FSnapCache[I].P);
    D := Sqrt(Sqr(SX - P.X) + Sqr(SY - P.Y));
    if D > TolPx then Continue;
    D := D - BIAS[FSnapCache[I].Kind];
    if D < Best then
    begin
      { A point behind a panel is not one anybody is aiming at, and being
        pulled onto one - the corner of a tunnel through the wall you are
        drawing on - put the click inside the block.  Only the candidates
        that would win are asked, so this costs nothing when there is nothing
        in the way. }
      if HiddenAt(V, FSnapCache[I].P) then Continue;
      Best := D;
      Hit := FSnapCache[I];
    end;
  end;

  Result := Hit.Kind <> snNone;
end;

function TWorkDoc.Bounds(out Lo, Hi: TP3): Boolean;
var
  I, K: Integer;

  procedure Grow(const P: TP3);
  begin
    Lo.X := Min(Lo.X, P.X); Lo.Y := Min(Lo.Y, P.Y); Lo.Z := Min(Lo.Z, P.Z);
    Hi.X := Max(Hi.X, P.X); Hi.Y := Max(Hi.Y, P.Y); Hi.Z := Max(Hi.Z, P.Z);
  end;

begin
  Result := FLive > 0;
  Lo := P3(1E30, 1E30, 1E30);
  Hi := P3(-1E30, -1E30, -1E30);
  for I := 0 to FLive - 1 do
    case FEnts[I].Kind of
      ekArc:
        begin
          Grow(P3(FEnts[I].C.X - FEnts[I].R, FEnts[I].C.Y - FEnts[I].R,
                  FEnts[I].C.Z - FEnts[I].R));
          Grow(P3(FEnts[I].C.X + FEnts[I].R, FEnts[I].C.Y + FEnts[I].R,
                  FEnts[I].C.Z + FEnts[I].R));
        end;
      ekFace:
        for K := 0 to High(FEnts[I].Poly) do
          Grow(FEnts[I].Poly[K]);
    else
      begin
        Grow(FEnts[I].A);
        Grow(FEnts[I].B);
      end;
    end;
end;

{ ---------------------------------------------------------------------- }
{ persistence                                                              }
{ ---------------------------------------------------------------------- }

{ A plain text format, so a drawing stays readable and diffable, and an old
  file keeps opening after the program moves on. }

function FS: TFormatSettings;
begin
  Result := DefaultFormatSettings;
  Result.DecimalSeparator := '.';
end;

function N3(const P: TP3): string;
begin
  Result := Format('%.6f %.6f %.6f', [P.X, P.Y, P.Z], FS);
end;

function RdF(const S: string): Double;
begin
  if not TryStrToFloat(S, Result, FS) then Result := 0;
end;

{ Does this token read as a number?  Used to tell an old TEXT line, whose
  words start right after the ink, from a new one carrying a target first. }
function IsNum(const S: string): Boolean;
var
  D: Double;
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Result := (S <> '') and TryStrToFloat(S, D, FS);
end;

{ Notes may have several lines; a .hsk entity is one line.  Backslash first,
  so unescaping cannot turn a literal \n back into a break. }
function EscapeNote(const S: string): string;
begin
  Result := StringReplace(S, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, #13#10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\n', [rfReplaceAll]);
end;

function UnescapeNote(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if (S[I] = '\') and (I < Length(S)) then
    begin
      case S[I + 1] of
        'n': Result := Result + #10;
        '\': Result := Result + '\';
      else
        Result := Result + S[I + 1];
      end;
      Inc(I, 2);
    end
    else
    begin
      Result := Result + S[I];
      Inc(I);
    end;
  end;
end;

procedure TWorkDoc.SaveTo(L: TStrings);
var
  I, J, K: Integer;
  Line: string;
begin
  for I := 0 to FLive - 1 do
    case FEnts[I].Kind of
      ekLine:
        L.Add(Format('LINE %s %s %d %.3f %d %d %d',
          [N3(FEnts[I].A), N3(FEnts[I].B), FEnts[I].Ink, FEnts[I].Weight,
           Ord(FEnts[I].Dim), FEnts[I].Grp, Ord(FEnts[I].Soft)], FS));
      ekArc:
        begin
          { The normal goes on the end, so a file written before free planes
            existed still reads and one written now still opens in a build
            that has never heard of them.  The side count follows on a line
            of its own, for the same reason. }
          L.Add(Format('ARC %s %.6f %.6f %.6f %d %d %.3f %s',
            [N3(FEnts[I].C), FEnts[I].R, FEnts[I].A0, FEnts[I].Sweep,
             Ord(FEnts[I].Plane), FEnts[I].Ink, FEnts[I].Weight,
             N3(FEnts[I].Nm)], FS));
          if FEnts[I].Sides >= 3 then
            L.Add(Format('SIDES %d', [FEnts[I].Sides]));
        end;
      ekDim:
        { the written-over label goes last, so a file with none still reads
          and one written by an older build still loads }
        L.Add(TrimRight(Format('DIM %s %s %d %s %s',
          [N3(FEnts[I].A), N3(FEnts[I].B), FEnts[I].Ink,
           N3(FEnts[I].C), FEnts[I].Txt], FS)));
      ekGuide:
        L.Add(Format('GUIDE %s %s', [N3(FEnts[I].A), N3(FEnts[I].B)], FS));
      ekText:
        { A note is one line in the file but may be several on the drawing,
          so the breaks are escaped.  The target goes before the text, which
          is the only field that can contain spaces and so has to be last. }
        begin
          L.Add(Format('TEXT %s %d %s %s',
            [N3(FEnts[I].A), FEnts[I].Ink, N3(FEnts[I].B),
             EscapeNote(FEnts[I].Txt)], FS));
          { its size on a line of its own, after it, and only when it has
            one - a reader that has never heard of it skips the line and
            gets the note at the size it always was }
          if (FEnts[I].Size > 0) and (Abs(FEnts[I].Size - 1) > 1E-6) then
            L.Add(Format('TEXTSIZE %.3f', [FEnts[I].Size], FS));
        end;
      ekBore:
        begin
          Line := Format('BORE %d %s %d', [FEnts[I].Grp, N3(FEnts[I].B), Length(FEnts[I].Poly)]);
          for K := 0 to High(FEnts[I].Poly) do
            Line := Line + ' ' + N3(FEnts[I].Poly[K]);
          L.Add(Line);
        end;
      ekFace:
        begin
          Line := Format('FACE %d %d %d',
            [FEnts[I].Ink, Ord(FEnts[I].Solid), Length(FEnts[I].Poly)]);
          for K := 0 to High(FEnts[I].Poly) do
            Line := Line + ' ' + N3(FEnts[I].Poly[K]);
          Line := Line + ' ' + IntToStr(FEnts[I].Grp);
          L.Add(Line);
          { What is cut out of it, one line each, straight after the face
            they belong to.  Their own keyword rather than more fields on the
            end, so a reader that has never heard of a hole skips them and
            gets the face it would have got before. }
          for K := 0 to High(FEnts[I].Holes) do
            if Length(FEnts[I].Holes[K]) >= 3 then
            begin
              Line := Format('HOLE %d', [Length(FEnts[I].Holes[K])]);
              for J := 0 to High(FEnts[I].Holes[K]) do
                Line := Line + ' ' + N3(FEnts[I].Holes[K][J]);
              L.Add(Line);
            end;
        end;
    end;
end;

{ Everything from token N onwards, put back together with single spaces.
  For the tail of a line that is free text rather than numbers. }
{ Text safe to drop into SVG markup.  The label is typed by hand, and a
  stray & or < would make the file unopenable. }
function XmlText(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

function JoinFrom(T: TStrings; N: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := N to T.Count - 1 do
    if Result = '' then Result := T[I] else Result := Result + ' ' + T[I];
end;

procedure TWorkDoc.LoadFrom(L: TStrings; var Idx: Integer);
var
  T: TStringList;
  Line, Kind: string;
  I, N, K, LastFace, LastNote: Integer;
  Pts: TP3Array;
  P: Integer;
begin
  Clear;
  { which face a HOLE line belongs to - the one just before it }
  LastFace := -1;
  LastNote := -1;
  T := TStringList.Create;
  try
    T.Delimiter := ' ';
    T.StrictDelimiter := True;
    while Idx < L.Count do
    begin
      Line := Trim(L[Idx]);
      if (Line = 'ENDSHEET') or (Copy(Line, 1, 6) = 'SHEET ') then Break;
      Inc(Idx);
      if Line = '' then Continue;
      T.DelimitedText := Line;
      if T.Count < 1 then Continue;
      Kind := T[0];

      { the group id used to sit outside this block, so it ran as a statement
        of its own and took the whole else-if chain with it: no FACE record
        ever loaded, and the first one written wrote to FEnts[-1] }
      if (Kind = 'LINE') and (T.Count >= 10) then
      begin
        AddLine(P3(RdF(T[1]), RdF(T[2]), RdF(T[3])),
                P3(RdF(T[4]), RdF(T[5]), RdF(T[6])),
                StrToIntDef(T[7], 0), RdF(T[8]), T[9] = '1');
        if (FLive > 0) and (T.Count >= 11) then
          FEnts[FLive - 1].Grp := StrToIntDef(T[10], 0);
        { older files have no soft flag, and nothing in them was softened }
        if (FLive > 0) and (T.Count >= 12) then
          FEnts[FLive - 1].Soft := T[11] = '1';
      end
      else if (Kind = 'SIDES') and (T.Count >= 2) and (FLive > 0) and
              (FEnts[FLive - 1].Kind = ekArc) then
        SetArcSides(FLive - 1, StrToIntDef(T[1], 0))
      else if (Kind = 'ARC') and (T.Count >= 10) then
      begin
        AddArc(P3(RdF(T[1]), RdF(T[2]), RdF(T[3])), RdF(T[4]), RdF(T[5]),
               RdF(T[6]), TPlane(StrToIntDef(T[7], 0)),
               StrToIntDef(T[8], 0), RdF(T[9]));
        if (T.Count >= 13) and (FLive > 0) then
        begin
          FEnts[FLive - 1].Nm := P3(RdF(T[10]), RdF(T[11]), RdF(T[12]));
          { the two end points were worked out from the wrong plane a moment
            ago, when the normal was not yet known }
          FEnts[FLive - 1].A := ArcPoint(FEnts[FLive - 1].C, FEnts[FLive - 1].R,
            FEnts[FLive - 1].A0, FEnts[FLive - 1].Plane, FEnts[FLive - 1].Nm);
          FEnts[FLive - 1].B := ArcPoint(FEnts[FLive - 1].C, FEnts[FLive - 1].R,
            FEnts[FLive - 1].A0 + FEnts[FLive - 1].Sweep,
            FEnts[FLive - 1].Plane, FEnts[FLive - 1].Nm);
        end;
      end
      else if (Kind = 'DIM') and (T.Count >= 8) then
        { A file written before the offset became a vector has one number
          where three should be.  There is no view to turn it back into a
          direction, so those dimensions land on the line they measure and
          can be dragged off again. }
        if T.Count >= 11 then
          AddDim(P3(RdF(T[1]), RdF(T[2]), RdF(T[3])),
                 P3(RdF(T[4]), RdF(T[5]), RdF(T[6])), StrToIntDef(T[7], 0),
                 P3(RdF(T[8]), RdF(T[9]), RdF(T[10])),
                 { every token past the offset is the written-over label,
                   joined back up because it usually has spaces in it }
                 JoinFrom(T, 11))
        else
          AddDim(P3(RdF(T[1]), RdF(T[2]), RdF(T[3])),
                 P3(RdF(T[4]), RdF(T[5]), RdF(T[6])), StrToIntDef(T[7], 0),
                 P3(0, 0, 0))
      else if (Kind = 'GUIDE') and (T.Count >= 7) then
        AddGuide(P3(RdF(T[1]), RdF(T[2]), RdF(T[3])),
                 P3(RdF(T[4]), RdF(T[5]), RdF(T[6])))
      else if (Kind = 'TEXT') and (T.Count >= 6) then
      begin
        { the note itself is the rest of the line, spaces and all }
        { A file written before notes had leaders has the text straight
          after the ink; one written since has the three target numbers in
          between.  Telling them apart is a matter of whether those three
          read as numbers. }
        if (T.Count >= 8) and IsNum(T[5]) and IsNum(T[6]) and IsNum(T[7]) then
        begin
          AddNote(P3(RdF(T[1]), RdF(T[2]), RdF(T[3])),
                  P3(RdF(T[5]), RdF(T[6]), RdF(T[7])),
                  UnescapeNote(JoinFrom(T, 8)), StrToIntDef(T[4], 0));
          LastNote := FLive - 1;
        end
        else
        begin
          P := Pos(' ', Line);
          for I := 1 to 4 do
          begin
            P := PosEx(' ', Line, P + 1);
            if P = 0 then Break;
          end;
          if P > 0 then
          begin
            AddText(P3(RdF(T[1]), RdF(T[2]), RdF(T[3])),
                    Copy(Line, P + 1, MaxInt), StrToIntDef(T[4], 0));
            LastNote := FLive - 1;
          end;
        end;
      end
      else if (Kind = 'TEXTSIZE') and (T.Count >= 2) and (LastNote >= 0) and
              (LastNote < FLive) then
        SetNoteSize(LastNote, RdF(T[1]))
      else if (Kind = 'HOLE') and (T.Count >= 2) and (LastFace >= 0) then
      begin
        N := StrToIntDef(T[1], 0);
        if (N >= 3) and (T.Count >= 2 + N * 3) and (LastFace < FLive) then
        begin
          SetLength(Pts, N);
          for I := 0 to N - 1 do
            Pts[I] := P3(RdF(T[2 + I * 3]), RdF(T[3 + I * 3]),
                         RdF(T[4 + I * 3]));
          K := Length(FEnts[LastFace].Holes);
          SetLength(FEnts[LastFace].Holes, K + 1);
          SetLength(FEnts[LastFace].Holes[K], N);
          for I := 0 to N - 1 do FEnts[LastFace].Holes[K][I] := Pts[I];
        end;
      end
      else if (Kind = 'BORE') and (T.Count >= 6) then
      begin
        N := StrToIntDef(T[5], 0);
        if (N >= 3) and (T.Count >= 6 + N * 3) then
        begin
          SetLength(Pts, N);
          for I := 0 to N - 1 do
            Pts[I] := P3(RdF(T[6 + I * 3]), RdF(T[7 + I * 3]), RdF(T[8 + I * 3]));
          AddBore(Pts, P3(RdF(T[2]), RdF(T[3]), RdF(T[4])), StrToIntDef(T[1], 0));
        end;
      end
      else if (Kind = 'FACE') and (T.Count >= 4) then
      begin
        N := StrToIntDef(T[3], 0);
        if (N >= 3) and (T.Count >= 4 + N * 3) then
        begin
          SetLength(Pts, N);
          for I := 0 to N - 1 do
            Pts[I] := P3(RdF(T[4 + I * 3]), RdF(T[5 + I * 3]), RdF(T[6 + I * 3]));
          AddFace(Pts, StrToIntDef(T[1], 0), T[2] = '1');
          { the solid it belongs to, when the file records one }
          if (FLive > 0) and (T.Count >= 5 + N * 3) then
            FEnts[FLive - 1].Grp := StrToIntDef(T[4 + N * 3], 0);
          LastFace := FLive - 1;
        end;
      end;
    end;
  finally
    T.Free;
  end;
end;

{ SVG export - real vectors, so it opens in Inkscape or a CAD package at the
  same size it prints. }
procedure TWorkDoc.WriteDXF(L: TStrings; const V: TProjector; U: TUnitSystem;
  ThreeD: Boolean);
var
  W: TDxfWriter;
  I, K, Steps, N: Integer;
  Sc, TX, TY, TZ, AX1, AY1, BX1, BY1: Double;
  XS, YS, ZS: array of Double;
  G: TDimGeom;

  { one point, in the file's units, flat or not }
  procedure At(const P: TP3; out X, Y, Z: Double);
  var
    S: TPointF;
  begin
    if ThreeD then
    begin
      X := P.X * Sc; Y := P.Y * Sc; Z := P.Z * Sc;
    end
    else
    begin
      { the view is in screen pixels with Y downwards; a DXF has Y up and is
        in drawing units, so the picture is put back to true size and turned
        the right way over }
      S := Project(V, P);
      X := (S.X - V.OX) / V.Ppu * Sc;
      Y := -(S.Y - V.OY) / V.Ppu * Sc;
      Z := 0;
    end;
  end;

  procedure Seg(const Lay: string; const A, B: TP3);
  var
    X1, Y1, Z1, X2, Y2, Z2: Double;
  begin
    At(A, X1, Y1, Z1);
    At(B, X2, Y2, Z2);
    W.Line(Lay, X1, Y1, Z1, X2, Y2, Z2);
  end;

  { a screen point of a dimension, in the file's units }
  procedure Flat(const S: TPointF; out X, Y: Double);
  begin
    X := (S.X - V.OX) / V.Ppu * Sc;
    Y := -(S.Y - V.OY) / V.Ppu * Sc;
  end;

begin
  if U = usImperial then Sc := 12 else Sc := 1000;
  W := TDxfWriter.Create;
  try
    W.Layer('GEOMETRY', 7);
    W.Layer('FACES', 8);
    W.Layer('DIMENSIONS', 3);
    W.Layer('NOTES', 2);
    W.Layer('GUIDES', 9, True);

    for I := 0 to FLive - 1 do
      case FEnts[I].Kind of
        ekLine:
          Seg('GEOMETRY', FEnts[I].A, FEnts[I].B);
        ekArc:
          begin
            { an arc goes out as short lines.  A DXF ARC is only defined in
              its own plane with its own extrusion direction, and every table
              and CAD reads a chain of lines the same way; a spool drawing
              does not need the arc to be an arc to be cut right. }
            if FEnts[I].Sides >= 3 then Steps := FEnts[I].Sides
            else Steps := Max(12, Round(Abs(FEnts[I].Sweep) * FEnts[I].R * 24));
            Steps := Min(Steps, 360);
            for K := 0 to Steps - 1 do
              Seg('GEOMETRY',
                ArcPoint(FEnts[I].C, FEnts[I].R,
                  FEnts[I].A0 + FEnts[I].Sweep * K / Steps, FEnts[I].Plane, FEnts[I].Nm),
                ArcPoint(FEnts[I].C, FEnts[I].R,
                  FEnts[I].A0 + FEnts[I].Sweep * (K + 1) / Steps, FEnts[I].Plane, FEnts[I].Nm));
          end;
        ekFace:
          if ThreeD then
          begin
            { the model's faces, for handing over the thing itself; flat, the
              outline is already there as lines }
            N := Length(FEnts[I].Poly);
            SetLength(XS, N); SetLength(YS, N); SetLength(ZS, N);
            for K := 0 to N - 1 do At(FEnts[I].Poly[K], XS[K], YS[K], ZS[K]);
            W.Face3D('FACES', XS, YS, ZS);
          end;
        ekGuide:
          if Dist(FEnts[I].A, FEnts[I].B) > 1E-9 then
            Seg('GUIDES', FEnts[I].A, FEnts[I].B);
        ekText:
          begin
            At(FEnts[I].A, TX, TY, TZ);
            W.Text('NOTES', TX, TY, TZ, 0.25 * Sc * NoteSize(I), FEnts[I].Txt);
          end;
        ekDim:
          if not ThreeD then
            if DimGeometry(V, FEnts[I].A, FEnts[I].B, FEnts[I].C, U, G, FEnts[I].Txt) then
            begin
              { the drawn dimension - line, witness lines and figure - as it
                sits on this view }
              Flat(G.A, AX1, AY1);  Flat(G.W1, BX1, BY1);
              W.Line('DIMENSIONS', AX1, AY1, 0, BX1, BY1, 0);
              Flat(G.B, AX1, AY1);  Flat(G.W2, BX1, BY1);
              W.Line('DIMENSIONS', AX1, AY1, 0, BX1, BY1, 0);
              Flat(G.LA, AX1, AY1); Flat(G.LB, BX1, BY1);
              W.Line('DIMENSIONS', AX1, AY1, 0, BX1, BY1, 0);
              Flat(G.Mid, AX1, AY1);
              W.Text('DIMENSIONS', AX1, AY1 + 0.1 * Sc, 0, 0.25 * Sc, G.Txt);
            end;
      end;
    W.SaveTo(L, U = usImperial);
  finally
    W.Free;
  end;
end;

procedure TWorkDoc.WriteSVG(L: TStrings; const V: TProjector; U: TUnitSystem;
  EdgeW: Single);
var
  I, K, H, Steps: Integer;
  PA, PB: TPointF;
  Ang, MinX, MinY, MaxX, MaxY: Double;
  D: string;

  procedure Grow(const P: TPointF);
  begin
    MinX := Min(MinX, P.X); MinY := Min(MinY, P.Y);
    MaxX := Max(MaxX, P.X); MaxY := Max(MaxY, P.Y);
  end;

  function Col(C: TColor): string;
  begin
    Result := Format('#%.2x%.2x%.2x',
      [Byte(C), Byte(C shr 8), Byte(C shr 16)]);
  end;

begin
  MinX := 1E30; MinY := 1E30; MaxX := -1E30; MaxY := -1E30;
  for I := 0 to FLive - 1 do
    for K := 0 to 1 do
      if K = 0 then Grow(Project(V, FEnts[I].A)) else Grow(Project(V, FEnts[I].B));
  if MinX > MaxX then
  begin
    MinX := 0; MinY := 0; MaxX := 100; MaxY := 100;
  end;
  MinX := MinX - 30; MinY := MinY - 30; MaxX := MaxX + 30; MaxY := MaxY + 30;

  L.Add('<?xml version="1.0" encoding="UTF-8"?>');
  L.Add(Format('<svg xmlns="http://www.w3.org/2000/svg" width="%.0f" height="%.0f" ' +
    'viewBox="%.2f %.2f %.2f %.2f">',
    [MaxX - MinX, MaxY - MinY, MinX, MinY, MaxX - MinX, MaxY - MinY], FS));

  for I := 0 to FLive - 1 do
    case FEnts[I].Kind of
      ekFace:
        begin
          { A path rather than a polygon, because a polygon cannot have a
            hole in it and a face can.  Each loop is one subpath and the
            even-odd rule fills between them, which is the same rule the
            screen uses - so a wall exported with a window in it arrives with
            the window, and the sheet somebody cuts from this has the opening
            the drawing had. }
          D := '';
          for K := 0 to High(FEnts[I].Poly) do
          begin
            PA := Project(V, FEnts[I].Poly[K]);
            if K = 0 then D := D + 'M ' else D := D + 'L ';
            D := D + Format('%.2f %.2f ', [PA.X, PA.Y], FS);
          end;
          D := D + 'Z ';
          for H := 0 to High(FEnts[I].Holes) do
          begin
            for K := 0 to High(FEnts[I].Holes[H]) do
            begin
              PA := Project(V, FEnts[I].Holes[H][K]);
              if K = 0 then D := D + 'M ' else D := D + 'L ';
              D := D + Format('%.2f %.2f ', [PA.X, PA.Y], FS);
            end;
            D := D + 'Z ';
          end;
          L.Add(Format('<path d="%s" fill="#d8d8d8" fill-rule="evenodd" ' +
            'stroke="%s" stroke-width="1"/>', [Trim(D), Col(FEnts[I].Ink)]));
        end;
      ekArc:
        begin
          if FEnts[I].Sides >= 3 then Steps := FEnts[I].Sides else Steps := 64;
          D := '';
          for K := 0 to Steps do
          begin
            Ang := FEnts[I].A0 + FEnts[I].Sweep * K / Steps;
            PA := Project(V, ArcPoint(FEnts[I].C, FEnts[I].R, Ang, FEnts[I].Plane, FEnts[I].Nm));
            D := D + Format('%.2f,%.2f ', [PA.X, PA.Y], FS);
          end;
          L.Add(Format('<polyline points="%s" fill="none" stroke="%s" ' +
            'stroke-width="%.2f"/>', [Trim(D), Col(FEnts[I].Ink), EdgeW], FS));
        end;
      ekText:
        begin
          PA := Project(V, FEnts[I].A);
          L.Add(Format('<text x="%.2f" y="%.2f" font-family="sans-serif" ' +
            'font-size="12" fill="%s">%s</text>',
            [PA.X + 5, PA.Y - 4, Col(FEnts[I].Ink), FEnts[I].Txt], FS));
        end;
      ekLine, ekDim:
        begin
          PA := Project(V, FEnts[I].A);
          PB := Project(V, FEnts[I].B);
          L.Add(Format('<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" ' +
            'stroke="%s" stroke-width="%.2f"/>',
            [PA.X, PA.Y, PB.X, PB.Y, Col(FEnts[I].Ink), EdgeW], FS));
          if FEnts[I].Dim then
            { the written-over figure goes out too - an export that quietly
              put the measured length back would be worse than no export,
              because it is the file that gets sent }
            L.Add(Format('<text x="%.2f" y="%.2f" font-family="sans-serif" ' +
              'font-size="11" text-anchor="middle" fill="%s">%s</text>',
              [(PA.X + PB.X) / 2, (PA.Y + PB.Y) / 2 - 6, Col(FEnts[I].Ink),
               XmlText(IfThen(FEnts[I].Txt <> '', FEnts[I].Txt,
                 FormatLen(Dist(FEnts[I].A, FEnts[I].B), U)))], FS));
        end;
    end;

  L.Add('</svg>');
end;

{ A name for an edge that both ends agree on.

  Quantised, so two corners that arrived at the same place by different
  arithmetic still name the same edge, and put in a fixed order so an edge
  walked one way round one face and the other way round its neighbour is
  recognised as the one edge it is. }
function EdgeKey(const A, B: TP3): string;
var
  P, Q: string;
begin
  P := Format('%d,%d,%d', [Round(A.X * 1E6), Round(A.Y * 1E6),
                           Round(A.Z * 1E6)]);
  Q := Format('%d,%d,%d', [Round(B.X * 1E6), Round(B.Y * 1E6),
                           Round(B.Z * 1E6)]);
  if P <= Q then Result := P + '|' + Q else Result := Q + '|' + P;
end;

procedure TWorkDoc.Render(S: TArtSurface; const V: TProjector;
  U: TUnitSystem; AFont: TFont; const LabelCol: TPix; EdgeW: Single);
var
  ZA, ZB, ZC, ZD1, ZD2, ZD3, ZDet: Double;
  ZOK: Boolean;  I, J, K, N, Steps, NFace: Integer;
  PA, PB: TPointF;
  Ang, Sh: Double;
  Col: TPix;
  Look, Lamp, Cen, Nm: TP3;
  Order: array of Integer;
  Depth, Area: array of Double;
  Ar: Double;
  Flat: array of TPointF;
  Loops: array of TPtFLoop;
  EdgeIx: TStringList;
  EK: string;
  HK, HJ: Integer;
  Shape: array of TPointFArray;   { each drawn face, as it lands on screen }
  GuideCol: TPix;
  M, Run0: Integer;
  T0, T1: Double;
  { the stretch being tested for cover: a line's two ends, or an arc }
  CurA, CurB: TP3;
  CurArc: Integer;
  RunT0, RunT1: Double;
  Vis: Boolean;

  { Is this model point hidden by a face drawn after the one at Slot?  Later
    in the sorted order means nearer the camera, so anything there is in
    front of it. }
  { Is this point of the drawing hidden behind something?

    One lookup.  The faces have already been drawn, each writing a depth for
    every pixel it covered, so the question "is something in front of this"
    is answered by the pixel rather than by walking the faces and reasoning
    about their order.

    This replaces two things that were both wrong in their own way: walking
    the faces sorted after this one, which assumes an order that a wide flat
    panel beside a small object does not have, and then walking all of them
    with a plane test, which was right but is a loop per sample per edge.

    A point sitting exactly on the surface it belongs to reads its own depth
    back, so the tolerance has to be loose enough to call that visible. }
  function Covered(const P: TP3; Slot: Integer): Boolean;
  var
    SP: TPointF;
    D, Zb, Zx, Zy, Grad: Double;
  begin
    Result := False;
    if not S.DepthOn then Exit;
    SP := Project(V, P);
    Zb := S.DepthAt(Round(SP.X), Round(SP.Y));
    if Zb < -1E29 then Exit;             { nothing was drawn there }
    D := Dot3(P, Look);

    { How much depth changes across one pixel here.

      The buffer is sampled at pixel centres and the point being asked about
      is not at one, so the two disagree by up to half a step of whatever the
      depth is doing locally.  Seen edge-on that step is large, and a line
      lying exactly on the surface it belongs to then loses to its own face by
      a hair and comes out dashed.  Measuring the step from the neighbours
      makes the tolerance follow the angle instead of being a guess. }
    Zx := S.DepthAt(Round(SP.X) + 1, Round(SP.Y));
    Zy := S.DepthAt(Round(SP.X), Round(SP.Y) + 1);
    Grad := 0;
    if Zx > -1E29 then Grad := Max(Grad, Abs(Zx - Zb));
    if Zy > -1E29 then Grad := Max(Grad, Abs(Zy - Zb));

    Result := Zb > D + Grad + 1E-3 * (1 + Abs(D));
  end;

  { Where along a stretch the cover begins: TVis is a point that can be seen
    and TCov one that cannot, as fractions of the stretch, and the answer is
    the boundary between them to a sixty-fourth of the gap.  Sampling alone
    left visible runs ending a whole sample past the face that hides them -
    the lines of a plate ran a little way into the cylinders standing on it. }
  function PtAt(T: Double): TP3;
  begin
    if CurArc >= 0 then
      Result := ArcPoint(FEnts[CurArc].C, FEnts[CurArc].R,
        FEnts[CurArc].A0 + FEnts[CurArc].Sweep * T, FEnts[CurArc].Plane, FEnts[CurArc].Nm)
    else
      Result := Lerp3(CurA, CurB, T);
  end;

  function Boundary(TVis, TCov: Double; Slot: Integer): Double;
  var
    N: Integer;
    TM: Double;
  begin
    for N := 1 to 6 do
    begin
      TM := (TVis + TCov) / 2;
      if Covered(PtAt(TM), Slot) then TCov := TM else TVis := TM;
    end;
    Result := (TVis + TCov) / 2;
  end;

  { A note, with a box round it and a leader out to whatever it is about.

    This is the half of an annotation that makes it an annotation rather than
    a caption: on an isometric especially, "8in SCH 40" floating in space is
    a riddle, and the same words on the end of a line pointing at a run are a
    drawing.  A note whose anchor and target are the same point has no leader
    and is a plain label, which is what every note made before this was. }
  procedure Note(Which: Integer; const At, Target: TP3; const Txt: string;
    const Col: TPix);
  const
    PADX = 5;
    PADY = 3;
  var
    Lines: TStringList;
    PA, PB: TPointF;
    LH, W, H, BX, BY, K, WasH: Integer;
    AX, AY: Double;
    Sz: TSize;
  begin
    if Txt = '' then Exit;
    PA := Project(V, At);
    PB := Project(V, Target);

    { the font is shared with every other label on the drawing, so its size
      is changed for this note and put back afterwards }
    WasH := AFont.Height;
    if (Which >= 0) and (Which < FLive) and (FEnts[Which].Size > 0) and
       (Abs(FEnts[Which].Size - 1) > 1E-6) then
      AFont.Height := Round(WasH * FEnts[Which].Size);

    Lines := TStringList.Create;
    try
      Lines.Text := Txt;
      if Lines.Count = 0 then Lines.Add(Txt);
      LH := S.TextExtent('Xg', AFont).cy;
      W := 0;
      for K := 0 to Lines.Count - 1 do
      begin
        Sz := S.TextExtent(Lines[K], AFont);
        if Sz.cx > W then W := Sz.cx;
      end;
      H := Lines.Count * LH;

      { the box sits up and to the right of its anchor, the way a note
        written on a drawing sits beside the thing it is about }
      BX := Round(PA.X) + 5;
      BY := Round(PA.Y) - H - 2 * PADY - 3;

      if (Which >= 0) and (Which < FLive) then
      begin
        FEnts[Which].BoxL := BX;
        FEnts[Which].BoxT := BY;
        FEnts[Which].BoxR := BX + W + 2 * PADX;
        FEnts[Which].BoxB := BY + H + 2 * PADY;
      end;
      S.FillRect(Rect(BX, BY, BX + W + 2 * PADX, BY + H + 2 * PADY),
        Pix(255, 255, 255), 0.82);
      S.Poly([PtF(BX, BY), PtF(BX + W + 2 * PADX, BY),
              PtF(BX + W + 2 * PADX, BY + H + 2 * PADY),
              PtF(BX, BY + H + 2 * PADY)], 1.0, Col, True, 0.75);
      for K := 0 to Lines.Count - 1 do
        S.TextOut(BX + PADX, BY + PADY + K * LH, Lines[K], AFont, Col);

      { the leader, from the corner of the box nearest the target }
      if Dist(At, Target) > 1E-9 then
      begin
        AX := BX;
        if PB.X > BX + W then AX := BX + W + 2 * PADX;
        AY := BY + H + 2 * PADY;
        if PB.Y < BY then AY := BY;
        S.Line(AX, AY, PA.X, PA.Y, 1.0, Col, 0.8);
        S.Line(PA.X, PA.Y, PB.X, PB.Y, 1.0, Col, 0.8);
        S.Disc(PB.X, PB.Y, 2.4, Col, 0.95);
      end
      else
        S.Disc(PA.X, PA.Y, 2.2, Col, 0.9);
    finally
      Lines.Free;
      AFont.Height := WasH;
    end;
  end;

  { A dimension line parallel to the projected segment, always labelled with
    the true 3D length - which is what makes an isometric readable. }
  procedure Dimension(const A, B, Off: TP3; const Note: string);
  var
    G: TDimGeom;
    Sz: TSize;
    TP: TPoint;
  begin
    if not DimGeometry(V, A, B, Off, U, G, Note) then Exit;
    S.Line(G.A.X, G.A.Y, G.W1.X, G.W1.Y, 1.0, LabelCol, 0.5);
    S.Line(G.B.X, G.B.Y, G.W2.X, G.W2.Y, 1.0, LabelCol, 0.5);
    S.Line(G.LA.X, G.LA.Y, G.LB.X, G.LB.Y, 1.2, LabelCol, 0.85);
    S.Line(G.S1A.X, G.S1A.Y, G.S1B.X, G.S1B.Y, 1.4, LabelCol, 0.9);
    S.Line(G.S2A.X, G.S2A.Y, G.S2B.X, G.S2B.Y, 1.4, LabelCol, 0.9);
    Sz := S.TextExtent(G.Txt, AFont);
    TP := DimTextTopLeft(G, Sz.cx, Sz.cy);
    S.TextOut(TP.X, TP.Y, G.Txt, AFont, LabelCol);
  end;

  { SketchUp's Profiles: the outline of a shape is drawn heavier than the
    edges inside it, and that one difference is most of why a model reads as
    solid rather than as a wireframe with fill.  An edge is on the outline
    when only one of the faces you can see runs along it. }
  { How many faces you can see run along this edge - looked up rather than
    counted.

    It used to be counted, per line, by walking every face in the drawing and
    every corner of it, and working out each face's normal on the way past.
    That is the number of lines times the number of faces, every frame: on a
    drawing with six hundred lines and three hundred faces it is the better
    part of a million distance checks before anything is drawn, which is
    exactly the drawing that was reported as making orbiting sluggish.

    The answer only depends on the faces and which way the camera points, so
    it is worked out once for the whole render and read off.  Same number,
    same rule - a face turned away from us still does not count, because the
    silhouette of a solid is where a face you can see meets one you cannot. }
  function EdgeFaces(const A, B: TP3): Integer;
  var
    Ix: Integer;
  begin
    Ix := EdgeIx.IndexOf(EdgeKey(A, B));
    if Ix < 0 then Result := 0 else Result := PtrInt(EdgeIx.Objects[Ix]);
  end;

  { A soft crease shows only where it is the outline of the surface; anywhere
    else it is hidden, and the shading alone says the surface is curved. }
  function Hidden(Ent: Integer): Boolean;
  begin
    Result := FEnts[Ent].Soft and
      (EdgeFaces(FEnts[Ent].A, FEnts[Ent].B) <> 1);
  end;

  function LineW(Ent: Integer): Single;
  begin
    Result := EdgeW;
    { SketchUp draws edges at one pixel and profiles at two, so the profile is
      one pixel heavier, not twice as heavy.  Doubling a four pixel pen gave
      an eight pixel outline, which is a border rather than a drawing. }
    if EdgeFaces(FEnts[Ent].A, FEnts[Ent].B) = 1 then
      Result := EdgeW + Max(1, EdgeW * 0.35);
  end;

begin
  S.BlendMode := bmNormal;
  GuideCol := MixPix(LabelCol, Pix(120, 90, 190), 0.55);

  { the edge index, once, before anything asks it a question }
  EdgeIx := TStringList.Create;
  try
    EdgeIx.Sorted := True;
    EdgeIx.CaseSensitive := True;
    Look := ViewDir(V);
    for I := 0 to FLive - 1 do
    begin
      if FEnts[I].Kind <> ekFace then Continue;
      if FEnts[I].Solid and (Dot3(FaceNormal(I), Look) <= 0) then Continue;
      N := Length(FEnts[I].Poly);
      for J := 0 to N - 1 do
      begin
        EK := EdgeKey(FEnts[I].Poly[J], FEnts[I].Poly[(J + 1) mod N]);
        K := EdgeIx.IndexOf(EK);
        if K < 0 then EdgeIx.AddObject(EK, TObject(PtrInt(1)))
        else EdgeIx.Objects[K] := TObject(PtrInt(EdgeIx.Objects[K]) + 1);
      end;
    end;

  for I := 0 to FLive - 1 do
  begin
    Col := ColorToPix(FEnts[I].Ink);
    case FEnts[I].Kind of
      ekFace: ;   // already painted
      ekLine:
        begin
          if Hidden(I) then Continue;
          PA := Project(V, FEnts[I].A);
          PB := Project(V, FEnts[I].B);
          S.Line(PA.X, PA.Y, PB.X, PB.Y, LineW(I), Col);
        end;

      ekArc:
        begin
          if FEnts[I].Sides >= 3 then Steps := FEnts[I].Sides
          else Steps := Max(10, Round(Abs(FEnts[I].Sweep) * FEnts[I].R * V.Ppu / 4));
          Steps := Min(Steps, 1500);
          PA := Project(V, ArcPoint(FEnts[I].C, FEnts[I].R, FEnts[I].A0, FEnts[I].Plane, FEnts[I].Nm));
          for K := 1 to Steps do
          begin
            Ang := FEnts[I].A0 + FEnts[I].Sweep * K / Steps;
            PB := Project(V, ArcPoint(FEnts[I].C, FEnts[I].R, Ang, FEnts[I].Plane, FEnts[I].Nm));
            S.Line(PA.X, PA.Y, PB.X, PB.Y, EdgeW, Col);
            PA := PB;
          end;
        end;

      { Labels and dimensions are drawn here, before the faces, so that a
        solid in front of them hides them - which is what SketchUp does and
        what stops a base dimension floating over the top of a box.  Any
        that lie in the plane of a face still facing us are put back after
        the face pass. }
      ekText:
        Note(I, FEnts[I].A, FEnts[I].B, FEnts[I].Txt, Col);
      ekDim:
        Dimension(FEnts[I].A, FEnts[I].B, FEnts[I].C, FEnts[I].Txt);

      { Dashed, and a guide line is infinite - run out far enough each way to
        cross any view of the drawing.  Drawn with the other annotation, so a
        solid standing in front of one hides it. }
      ekGuide:
        if not FGuidesHidden then
        begin
          PA := Project(V, FEnts[I].A);
          if Dist(FEnts[I].A, FEnts[I].B) < 1E-9 then
          begin
            { A guide point is something somebody put there deliberately and
              will want to find again, so it is drawn to be found: amber,
              filled, and larger than the snap marks it sits among.
              SketchUp's are almost invisible, which is not a thing to copy. }
            { drawn again at the end, on top - see the last pass }
          end
          else
          begin
            PB := Project(V, FEnts[I].B);
            Ang := Sqrt(Sqr(PB.X - PA.X) + Sqr(PB.Y - PA.Y));
            if Ang > 1E-6 then
            begin
              Sh := (S.Width + S.Height) * 1.5;
              PB := PtF((PB.X - PA.X) / Ang, (PB.Y - PA.Y) / Ang);
              K := 0;
              while K * 12 < Sh do
              begin
                S.Line(PA.X + PB.X * (K * 12 - Sh / 2),
                       PA.Y + PB.Y * (K * 12 - Sh / 2),
                       PA.X + PB.X * (K * 12 + 6 - Sh / 2),
                       PA.Y + PB.Y * (K * 12 + 6 - Sh / 2),
                       1.0, GuideCol, 0.85);
                Inc(K);
              end;
            end;
          end;
        end;
    end;
  end;


  { --- solids go on top of the edges, which is what hides the lines that
        run behind them ------------------------------------------------- }
  { --- solid faces, painter's algorithm ------------------------------- }
  NFace := 0;
  SetLength(Order, FLive);
  SetLength(Depth, FLive);
  SetLength(Area, FLive);
  Look := ViewDir(V);
  Lamp := Norm3(P3(0.35, -0.55, 0.75));
  for I := 0 to FLive - 1 do
    if (FEnts[I].Kind = ekFace) and (Length(FEnts[I].Poly) >= 3) then
    begin
      { Every face is drawn, and the depth buffer decides what shows.

        A solid used to hide its own back faces by the sign of the normal.
        On a closed box that gives the right answer, and it gives it for the
        wrong reason: the far wall is not hidden because it faces away, it is
        hidden because the near wall is in front of it.  The two only agree
        while the box is closed.  Rub a face out to make a window and you
        should see the inside of the far wall through the hole - and instead
        the hole showed the background, because the far wall was still being
        skipped for facing away.

        The fill already tests depth per pixel, so this needs nothing in its
        place: a fragment behind what is already drawn is dropped, whatever
        order the faces came in.  What comes back is the inside of the solid,
        in the back-face color, which is the whole reason that color exists. }

      Cen := P3(0, 0, 0);
      for K := 0 to High(FEnts[I].Poly) do
      begin
        Cen.X := Cen.X + FEnts[I].Poly[K].X;
        Cen.Y := Cen.Y + FEnts[I].Poly[K].Y;
        Cen.Z := Cen.Z + FEnts[I].Poly[K].Z;
      end;
      K := Length(FEnts[I].Poly);
      Cen := P3(Cen.X / K, Cen.Y / K, Cen.Z / K);
      Order[NFace] := I;
      Depth[NFace] := Dot3(Cen, Look);
      Area[NFace] := FaceArea(I);
      Inc(NFace);
    end;

  { Farthest from the camera first.  Where two faces are level to within
    rounding - a circle drawn on a slab is exactly that - the bigger one goes
    first, so the small one lands on top of it rather than underneath. }
  for I := 1 to NFace - 1 do
  begin
    K := Order[I];
    Sh := Depth[I];
    Ar := Area[I];
    J := I - 1;
    while (J >= 0) and
          ((Depth[J] > Sh + 1E-4 * (1 + Abs(Sh))) or
           ((Depth[J] > Sh - 1E-4 * (1 + Abs(Sh))) and (Area[J] < Ar))) do
    begin
      Depth[J + 1] := Depth[J];
      Area[J + 1] := Area[J];
      Order[J + 1] := Order[J];
      Dec(J);
    end;
    Depth[J + 1] := Sh;
    Area[J + 1] := Ar;
    Order[J + 1] := K;
  end;

  SetLength(Shape, NFace);
  S.DepthBegin;
  for I := 0 to NFace - 1 do
  begin
    K := Order[I];
    SetLength(Flat, Length(FEnts[K].Poly));
    for J := 0 to High(FEnts[K].Poly) do
      Flat[J] := Project(V, FEnts[K].Poly[J]);
    Shape[I] := Copy(Flat, 0, Length(Flat));
    Nm := FaceNormal(K);
    Col := ColorToPix(FEnts[K].Ink);
    { A face is a surface with a material on it, not a stroke of ink.  It
      starts from SketchUp's near-white default and carries only a hint of
      the pen color, so a red-inked part still reads as red without the
      drawing turning into a paint chart.  Shading comes from how the face
      is turned relative to a fixed lamp, which is what makes a box look
      like a box.

      Opaque in every view.  It used to be a 16 percent tint in plan, on the
      grounds that there was nothing to hide - but there is: a face laid over
      another one, and every line and dimension underneath.  Filling it
      properly is what stops a solid looking like glass. }
    { A wider spread between the faces.  SketchUp leans on shading to tell one
      side of a box from another and keeps its edges to a hairline; ours had
      the faces within a few percent of each other and made the edges do all
      the work, which is why a box looked like it had been outlined in marker.
      Top, front and side now land near 1.0, 0.90 and 0.80 of the material -
      close to SketchUp's own default style. }
    { The plane this face lies in, in screen terms: depth as a flat function
      of x and y, which is all a parallel projection ever gives.  Three
      projected corners and their depths solve it. }
    ZOK := False;
    if Length(Flat) >= 3 then
    begin
      ZD1 := Dot3(FEnts[K].Poly[0], Look);
      ZD2 := Dot3(FEnts[K].Poly[1], Look);
      ZD3 := Dot3(FEnts[K].Poly[2], Look);
      ZDet := (Flat[1].X - Flat[0].X) * (Flat[2].Y - Flat[0].Y) -
              (Flat[2].X - Flat[0].X) * (Flat[1].Y - Flat[0].Y);
      if Abs(ZDet) > 1E-9 then
      begin
        ZA := ((ZD2 - ZD1) * (Flat[2].Y - Flat[0].Y) -
               (ZD3 - ZD1) * (Flat[1].Y - Flat[0].Y)) / ZDet;
        ZB := ((ZD3 - ZD1) * (Flat[1].X - Flat[0].X) -
               (ZD2 - ZD1) * (Flat[2].X - Flat[0].X)) / ZDet;
        ZC := ZD1 - ZA * Flat[0].X - ZB * Flat[0].Y;
        ZOK := True;
      end;
    end;
    if ZOK then S.DepthPlane(ZA, ZB, ZC)
    else S.DepthPlane(0, 0, -1E30);

    Sh := Min(1, 0.62 + 0.50 * Abs(Dot3(Nm, Lamp)));
    { Which side of it are we looking at?  The back of a face gets its own
      colour rather than the material.  A closed solid never shows one - its
      backs are culled - so this only ever appears on loose geometry, which is
      exactly where being inside out matters and cannot otherwise be seen.

      The sense of the test is the one FaceUnder already uses to decide what
      can be clicked: a face turned towards the camera has a positive dot with
      the view direction. }
    { The outline and anything cut out of it go to the fill together, so a
      window is a place the wall is not rather than a place something else is
      drawn over it.  That distinction is the whole difference between a
      window you can see through and a window that is a picture of one. }
    SetLength(Loops, 1 + Length(FEnts[K].Holes));
    SetLength(Loops[0], Length(Flat));
    for HJ := 0 to High(Flat) do Loops[0][HJ] := Flat[HJ];
    for HK := 0 to High(FEnts[K].Holes) do
    begin
      SetLength(Loops[HK + 1], Length(FEnts[K].Holes[HK]));
      for HJ := 0 to High(FEnts[K].Holes[HK]) do
        Loops[HK + 1][HJ] := Project(V, FEnts[K].Holes[HK][HJ]);
    end;
    if Dot3(Nm, ViewDir(V)) < 0 then
      S.FillLoops(Loops, ShadePix(FACE_BACK, Sh), 1.0)
    else
      S.FillLoops(Loops, ShadePix(MixPix(Col, FACE_MATERIAL, 0.92), Sh), 1.0);
    { No outline.  Every boundary of a face is a real edge and gets drawn as
      one, so stroking the polygon as well laid a second line over the first -
      which is most of why the edges of a solid looked heavier than the lines
      they were made of. }
  end;


  { --- lines that live on a visible face -------------------------------
        The face pass runs after the edges so that a solid hides whatever is
        behind it, but that also buries the lines drawn ON its surface.
        Those are put back here: a line counts if both ends sit in the plane
        of a face that survived the culling. }
  for I := 0 to FLive - 1 do
  begin
    if not (FEnts[I].Kind in [ekLine, ekArc, ekDim, ekText]) then Continue;
    for J := 0 to NFace - 1 do
    begin
      K := Order[J];
      Nm := FaceNormal(K);
      Sh := Dot3(Nm, FEnts[K].Poly[0]);
      if FEnts[I].Kind = ekArc then
      begin
        { an arc lies in a face when its middle and its rim do }
        if Abs(Dot3(Nm, FEnts[I].C) - Sh) >= 1E-6 then Continue;
        if Abs(Dot3(Nm, ArcPoint(FEnts[I].C, FEnts[I].R, FEnts[I].A0,
             FEnts[I].Plane, FEnts[I].Nm)) - Sh) >= 1E-6 then Continue;
      end
      else if (Abs(Dot3(Nm, FEnts[I].A) - Sh) >= 1E-6) or
              (Abs(Dot3(Nm, FEnts[I].B) - Sh) >= 1E-6) then Continue;
      Col := ColorToPix(FEnts[I].Ink);
      case FEnts[I].Kind of
        ekLine:
          if Hidden(I) then
            { a softened crease stays hidden here too }
          else
          { Only the stretches of it that nothing is standing in front of.
            Putting the whole line back is what let the lines of a flat grid
            run straight through the towers pushed up out of it - the solid
            was opaque, and then the lines were painted back on top of it.

            Consecutive visible pieces are drawn as one line rather than as
            thirty-two abutting ones: each short segment has its own ends, and
            at a heavy profile weight the joins showed as notches along it. }
          begin
          Run0 := -1;
          CurA := FEnts[I].A;
          CurB := FEnts[I].B;
          CurArc := -1;
          for M := 0 to LINE_STEPS do
          begin
            if M < LINE_STEPS then
            begin
              T0 := M / LINE_STEPS;
              T1 := (M + 1) / LINE_STEPS;
              Vis := not Covered(Lerp3(FEnts[I].A, FEnts[I].B,
                (T0 + T1) / 2), J);
            end
            else
              Vis := False;
            if Vis and (Run0 < 0) then
            begin
              Run0 := M;
              { the run starts where the cover ends, not at the sample }
              if M = 0 then RunT0 := 0
              else RunT0 := Boundary((M + 0.5) / LINE_STEPS, (M - 0.5) / LINE_STEPS, J);
            end;
            if (not Vis) and (Run0 >= 0) then
            begin
              if M = LINE_STEPS then RunT1 := 1
              else RunT1 := Boundary((M - 0.5) / LINE_STEPS, (M + 0.5) / LINE_STEPS, J);
              PA := Project(V, Lerp3(FEnts[I].A, FEnts[I].B, RunT0));
              PB := Project(V, Lerp3(FEnts[I].A, FEnts[I].B, RunT1));
              S.Line(PA.X, PA.Y, PB.X, PB.Y, LineW(I), Col);
              Run0 := -1;
            end;
          end;
          end;
        ekArc:
          { the same, walked round the curve - without this a circle drawn on
            the side of a box was painted over by the box and looked as though
            it had landed somewhere else entirely }
          begin
            if FEnts[I].Sides >= 3 then Steps := FEnts[I].Sides
            else Steps := Max(24, Min(180, Round(Abs(FEnts[I].Sweep) * FEnts[I].R * V.Ppu / 6)));
            Run0 := -1;
            CurArc := I;
            for M := 0 to Steps do
            begin
              if M < Steps then
              begin
                Ang := FEnts[I].A0 + FEnts[I].Sweep * (M + 0.5) / Steps;
                Vis := not Covered(ArcPoint(FEnts[I].C, FEnts[I].R, Ang,
                  FEnts[I].Plane, FEnts[I].Nm), J);
              end
              else
                Vis := False;
              if Vis and (Run0 < 0) then
              begin
                Run0 := M;
                if M = 0 then RunT0 := 0
                else RunT0 := Boundary((M + 0.5) / Steps, (M - 0.5) / Steps, J);
              end;
              if (not Vis) and (Run0 >= 0) then
              begin
                if M = Steps then RunT1 := 1
                else RunT1 := Boundary((M - 0.5) / Steps, (M + 0.5) / Steps, J);
                { from the refined start, through the corners between, to
                  the refined end - a faceted circle keeps its corners }
                PA := Project(V, PtAt(RunT0));
                for K := 1 to Steps - 1 do
                  if (K / Steps > RunT0 + 1E-9) and (K / Steps < RunT1 - 1E-9) then
                  begin
                    PB := Project(V, PtAt(K / Steps));
                    S.Line(PA.X, PA.Y, PB.X, PB.Y, LineW(I), Col);
                    PA := PB;
                  end;
                PB := Project(V, PtAt(RunT1));
                S.Line(PA.X, PA.Y, PB.X, PB.Y, LineW(I), Col);
                Run0 := -1;
              end;
            end;
          end;
        ekDim:
          if not Covered(Lerp3(FEnts[I].A, FEnts[I].B, 0.5), J) then
            Dimension(FEnts[I].A, FEnts[I].B, FEnts[I].C, FEnts[I].Txt);
        ekText:
          if not Covered(FEnts[I].A, J) then
            Note(I, FEnts[I].A, FEnts[I].B, FEnts[I].Txt, Col);
      end;
      Break;
    end;
  end;

  { --- guide points, last of all ---------------------------------------

    A guide point is put down deliberately, to be come back to, so it is no
    use buried under the panel it was placed on.  Everything else about a
    guide is drawn with the annotation before the faces, so that a solid
    standing in front of one hides it - and that is right for a line, which
    runs on past the geometry and can be seen either side of it.  A point has
    no length to be seen by.

    Still hidden when something really is in front of it, which is now a
    question that can be asked of every face rather than of the sort order. }
  for I := 0 to FLive - 1 do
    if (FEnts[I].Kind = ekGuide) and not FGuidesHidden and
       (Dist(FEnts[I].A, FEnts[I].B) < 1E-9) then
    begin
      if Covered(FEnts[I].A, -1) then Continue;
      PA := Project(V, FEnts[I].A);
      S.Disc(PA.X, PA.Y, 4.5, Pix(20, 20, 24), 0.55);
      S.Disc(PA.X, PA.Y, 3.4, GUIDE_POINT, 1.0);
      S.Line(PA.X - 8, PA.Y, PA.X + 8, PA.Y, 1.4, GUIDE_POINT, 0.95);
      S.Line(PA.X, PA.Y - 8, PA.X, PA.Y + 8, 1.4, GUIDE_POINT, 0.95);
    end;
  finally
    EdgeIx.Free;
  end;
end;

end.
