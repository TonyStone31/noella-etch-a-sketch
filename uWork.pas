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
  Contnrs,
  Classes, SysUtils, Types, Math, StrUtils, Graphics, uSurface, uTri, uDxf;

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
  { ekPart is a group - what SketchUp calls a group and this program calls
    one too.  Not a thing on the screen: it is the record of a group, kept
    as an entity for the reason ekBore is, so that undo, save, load and copy
    carry it for nothing.  Grp holds its id, Txt its name, Solid whether it
    is locked, and Part the group it sits inside.  Its members are every
    entity whose Part is its id. }
  TEntKind = (ekLine, ekArc, ekText, ekDim, ekFace, ekGuide, ekBore, ekPart);

  TIntArrayW = array of Integer;
  TIntArrayWArray = array of TIntArrayW;

  { Long work says how far it is through this, and stops if told to.  Set
    by the program; the tests and tools leave it nil. }
  TProgressHook = function(const What: string; Frac: Double): Boolean of object;

var
  Progress: TProgressHook = nil;
  { what a new document's Threads starts as; off, so that the tests and the
    command line tools never start a thread.  The program turns it on. }
  DefaultThreads: Boolean = False;

type

  { One thing on the drawing.  World coordinates, Y up, in feet or meters.

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
    { Which group this belongs to, or 0 for the drawing itself.  Not the
      same question as Grp: a group can hold six solids, and a solid cut in
      half becomes two.  Geometry in different groups does not join, does
      not split each other, and does not stretch each other - SketchUp's
      rule, "objects don't stick to other entities", and the whole reason
      groups exist. }
    Part: Integer;
    Txt: string;
    Ink: TColor;
    { ekFace: the material painted on the front of it.  MatSet is what says
      whether it has one, because a color has no spare value to mean "none"
      and an entity is born by being zeroed - so black had to stay a color
      you can paint with.

      This is kept apart from Ink, and the two used to be one field.  That is
      what made a face painted red come out gray: the pen color and the
      material were the same thing, so a face had to take a mere eight
      percent of it or every face drawn with a red pen would have been red.
      SketchUp keeps them apart - an edge has a color, a face has a material
      - and a face painted red is red. }
    MatSet: Boolean;
    Mat: TColor;
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
    snSubMid, snOnEdge, snOnAxis, snOrigin, snOnFace, snQuadrant);

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

  { A corner rounded off: the two loose lines that met there, where the arc
    touches each of them, and the arc itself.  See TWorkDoc.FilletAt. }
  TFillet = record
    Corner, S, E: TP3;       { the corner, and the two tangent points }
    LineA, LineB: Integer;   { S lies on LineA, E on LineB }
    R, T: Double;            { radius; corner to each tangent point }
    Pl: TPlane;
    Nm: TP3;                 { the plane's facing, for a free one }
    ArcC: TP3;
    A0, Sweep, Bulge: Double;
  end;

  TWorkDoc = class
  private
    FEnts: array of TWorkEnt;
    FLive: Integer;      // entities in play; anything past this is redo space
    FSnapCache: array of TSnapHit;
    FSnapScreen: array of TPointF;
    FSnapScreenV: TProjector;
    FSnapScreenOK: Boolean;
    FSnapDirty: Boolean;
    { The last answer FaceUnder gave, and everything that could make it a
      different answer.  See the note over FaceUnder: one mouse move asks it
      two or three times for the same pixel, and it walks every face in the
      drawing casting a ray. }
    FFaceMemoOK: Boolean;
    FFaceMemoSeq: Int64;
    FFaceMemoX, FFaceMemoY: Double;
    FFaceMemoV: TProjector;
    FFaceMemoFace: Integer;
    FFaceMemoPt: TP3;
    FFaceMemoSlice: Boolean;
    FFaceMemoLo, FFaceMemoHi: Double;
    FGuidesHidden: Boolean;
    FNextGrp: Integer;
    { Groups.  FNextPart numbers them; FContext is the group open for
      editing, or 0 for the drawing itself; FStamp is the group new geometry
      is born into - the context, except while a rebuild is working out one
      group's faces or a file is being read.  See the ekPart note. }
    FNextPart: Integer;
    FContext: Integer;
    FStamp: Integer;
    { The slice a plan view is cut out of - see SetSlice. }
    FSliceOn: Boolean;
    { which solids are closed, and the edit it was worked out at }
    FClosedSeq: Integer;
    FClosedGrp: array of Boolean;
    { every face cut into triangles, and the edit each cut was made at - see
      FaceCut }
    FCut: array of record
      Seq: Integer;
      Tris: TTriList;
    end;
    FSliceLo, FSliceHi: Double;
    FLastBore: Integer;
    function GetEnt(I: Integer): TWorkEnt;
    procedure RebuildSnapCache;
    procedure ArcSnaps(var N: Integer);
  public
    procedure AddLine(const A, B: TP3; Ink: TColor; Weight: Single; Dim: Boolean);
    { True when a line with these ends is already there, either way round. }
    function HasLine(const A, B: TP3): Boolean;
    { Add a line, splitting it and whatever it lies along where they share.

      An edge landing exactly on one already there was skipped, and one
      landing halfway along it was laid on top - two lines covering the same
      run of the drawing, which is a seam the region finder has to reason
      about twice and a person cannot see at all.  SketchUp splits both where
      they overlap so that the shared piece is one edge, and so does this.

      Only loose lines are touched: a line that belongs to a solid is part of
      something that was built, and cutting it up underneath the solid is a
      different and much worse idea.  Returns how many pieces the run came
      out as, or 0 when nothing overlapped and it was simply added. }
    function AddLineSplit(const A, B: TP3; Ink: TColor; Weight: Single): Integer;
    { Cut every loose edge that something drawn since FirstNew crosses, and
      cut that new edge where they cross it, so each piece is its own line
      or arc and can be rubbed out on its own.  Returns how many edges were
      broken up. }
    function SplitCrossings(FirstNew: Integer): Integer;
    { Rounding a corner, SketchUp's way - see the bodies. }
    function FarEnd(I: Integer; const P: TP3): TP3;
    function ArcFromChordFor(var F: TFillet): Boolean;
    function CornerLines(const Corner: TP3; out LA, LB: Integer): Boolean;
    function FilletAt(const Corner: TP3; R: Double; out F: TFillet): Boolean;
    function FilletFromEnds(const S, E: TP3; out F: TFillet): Boolean;
    function NearestCorner(const V: TProjector; SX, SY, TolPx: Double;
      out Corner: TP3): Boolean;
    function ApplyFillet(const F: TFillet; Sides: Integer; Ink: TColor;
      Weight: Single; Trim: Boolean): Boolean;
    function TrimFillet(const F: TFillet): Integer;
    { A line's length, typed.  See the body for which end gives. }
    function LineEndJoined(I: Integer; AtB: Boolean): Boolean;
    function LineLengthEnd(I: Integer; out MoveB: Boolean): Boolean;
    function SetLineLength(I: Integer; NewLen: Double): Boolean;
    procedure AddArc(const C: TP3; R, A0, Sweep: Double; Pl: TPlane;
      Ink: TColor; Weight: Single);
    procedure SetArcSides(Index, N: Integer);
    { Follow Me, the turning half: spin the face Face about the axis through
      AxisP along AxisDir by Angle, in Steps gores, into one solid.  Returns
      the index of the first thing made, or -1.  A full turn consumes the
      profile face; a part turn keeps it as one cap and makes the other. }
    function Revolve(Face: Integer; const AxisP, AxisDir: TP3; Angle: Double;
      Steps: Integer): Integer;
    { Follow Me, the path half: push the face Face along Path, a chain of
      points, mitring it at every corner, into one solid.  Closed says the
      path comes back to its start, in which case there are no caps and the
      profile is consumed.  Returns the index of the first thing made, or
      -1. }
    function Sweep(Face: Integer; const Path: TP3Array; Closed: Boolean;
      Caps: Boolean = True): Integer;
    { the points of an arc or a line, in order, for building a path }
    procedure EdgePoints(I: Integer; out Pts: TP3Array);
    procedure MarkProfileArcs(const Poly: TP3Array; G: Integer);
    { where a dimension's line sits: the offset from what it measures }
    procedure SetDimOffset(Index: Integer; const Off: TP3);
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
    { Putting the guides away has to reach the snap cache, which is built
      once and kept: a guide point left in it is a place the cursor jumps to
      with nothing on the screen to explain why. }
    procedure SetGuidesHidden(On_: Boolean);
    { Guides can be put away without being thrown away - they are aids, and a
      drawing being looked at rather than laid out does not want them.  Held
      the negative way round so that a document with nothing said about it
      shows them, which is what a field left alone gives. }
    property GuidesHidden: Boolean read FGuidesHidden write SetGuidesHidden;
    { A plan drawing is a horizontal section, not a photograph taken from
      above, and this is the section.  Everything between Lo and Hi is in the
      drawing and everything else is not - not drawn, not snapped to, not
      picked.  Off by default, and off means the whole model.

      One rule and no exceptions: what is in the slice and what can be
      touched are the same set.  Geometry that is hidden but still grabs the
      cursor is the worst failure this program has had, twice. }
    procedure SetSlice(AOn: Boolean; ALo, AHi: Double);
    property SliceOn: Boolean read FSliceOn;
    property SliceLo: Double read FSliceLo;
    property SliceHi: Double read FSliceHi;
    { Is this entity in the slice?  True for everything when it is off. }
    function InSlice(Index: Integer): Boolean;
    { How many things the slice is keeping out, so the program can say so
      rather than leave somebody hunting for their drawing. }
    function OutsideSlice: Integer;
    { Is this solid closed - every edge of it shared by exactly two faces,
      run opposite ways?  On one that is, a face turned away from the camera
      can never be seen, so it need not be drawn at all. }
    function GroupClosed(G: Integer): Boolean;
    { The edges of a group that are not shared by exactly two faces run
      opposite ways - which is to say, the places where a solid is not
      closed.

      GroupClosed answers yes or no; this says WHERE, which is the answer
      somebody actually needs when a slicer has refused their model.  Points
      come back in pairs, each pair one bad edge, so a caller can simply draw
      them.  The same T-junction resolution GroupClosed uses is applied
      first, so a seam that is merely divided unevenly is not reported as a
      hole - it is not one.

      Nothing draws these yet.  It is here because the analyzis is the hard
      part and it already existed, scattered across a scratch program used to
      find what was wrong with the robot; putting it where it belongs cost
      nothing and means the day somebody wants it highlighted on screen, the
      work is a paint routine and not an investigation. }
    function OpenEdges(G: Integer): TP3Array;

    { This face cut into triangles, as triples of indices into FaceCorners -
      which is the outline followed by each hole, in order.

      Cut in the face's own plane, not on the screen, so the answer does not
      depend on where the camera is and can be kept: it is worked out once
      per face per edit and handed back as often as it is asked for.  The
      renderer asks every frame for every face that is not flat, and STL
      export asks once for every face there is.

      Cutting in the face's own plane is also the more robust of the two.  A
      face that is not flat can, seen from the wrong angle, project to an
      outline that crosses itself, and no ear clipper has an answer for one
      of those; flattened along its own normal it is far less likely to, and
      a flat face cannot at all.

      Empty if the face has fewer than three corners or is degenerate. }
    function FaceCut(Index: Integer): TTriList;
    { The corners FaceCut indexes: the outline, then each hole in order. }
    function FaceCorners(Index: Integer): TP3Array;
    { The Z range of everything, for setting a slice that holds the lot. }
    function ZRange(out Lo, Hi: Double): Boolean;
    function ClearGuides: Integer;
    procedure AddFace(const Pts: array of TP3; Ink: TColor; Solid: Boolean = False);
    procedure AddFaceRaw(const Pts: array of TP3; Ink: TColor; Solid: Boolean);
    { Turns a face over, so what was its back becomes its front.  The last
      word on which way a face points, for when the rule that wound it
      guessed wrong. }
    function ReverseFace(Index: Integer): Boolean;
    { Make loose faces agree with their neighbors about which way is out.

      A face worked out from lines is wound by OrientFace, which looks at that
      face and nothing else and points it along whichever axis it faces most.
      That is the best a single face can do and it is wrong about half the
      time in company: the two slopes of a roof both come out pointing the
      same way in y, when out for one of them is the opposite of out for the
      other, and so do the two ends of a gable in x.  A face pointing inwards
      is drawn in the back-face color, which is how this reaches anybody -
      as blue patches on a house that has nothing wrong with it.

      Faces that share an edge and disagree about which way along it they run
      agree about which way is out; that is the whole rule, and it settles a
      whole connected sheet of them from any one starting face.  Which way
      round the settled sheet as a whole should go is a separate question,
      answered by its own volume if it encloses one and otherwise by pointing
      its faces away from the middle of it.

      Only loose faces, and only across edges where exactly two faces meet.
      A pushed solid is left alone - it is wound correctly when it is made and
      its backs are culled anyway - and an edge with three faces on it has no
      consistent answer, so nothing is carried across it.

      Returns how many faces it turned over. }
    { the loose faces of one group at a time: faces in different groups are
      not neighbors, whatever edges they happen to share }
    function OrientLooseShells(Part: Integer = 0): Integer;
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
    { a fresh solid identity, for something built rather than pulled }
    function NewGroup: Integer;
    procedure SetSoft(Index: Integer; Soft: Boolean);
    { What an entity is drawn with, changed after the fact - the entity
      panel's color and width rows. }
    procedure SetInk(Index: Integer; Ink: TColor);
    procedure SetWeight(Index: Integer; Weight: Single);
    { The material on the front of a face.  Painting is per face, so a box
      can have a red top and a white side the way it does in SketchUp.
      Material returns False for a face that has never been painted, which
      is the near-white all faces start as. }
    procedure SetMaterial(Index: Integer; C: TColor);
    procedure ClearMaterial(Index: Integer);
    function Material(Index: Integer; out C: TColor): Boolean;
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
    { How far this face has to travel along its own normal to come out the
      far side of the solid it is on.  Want gives the direction, and comes
      back unchanged when there is nothing to come out of. }
    function ThroughDistance(Face: Integer; Want: Double): Double;
    { Slide a face along a vector, dragging everything joined to it. }
    procedure MoveFaceWith(Index: Integer; const D: TP3);
    { A pushed patch whose far end lands on another face of the same solid
      that contains it.  Opens that face, walls the tunnel, removes the patch
      and its edges' claim.  False when the push lands anywhere else. }
    function TunnelThrough(Index: Integer; const Top: TP3Array;
      const Nm: TP3; Dist: Double): Boolean;
    { Every corner of these entities, for moving or for stretching. }
    procedure VertsOf(const Idx: array of Integer; out Pts: TP3Array);
    { Which faces these edges hold up: any face with a side, or the side of
      an opening, running along one of them.  Erasing an edge has to take
      them with it - a face is what a closed run of edges encloses, not a
      thing that stands on its own. }
    function FacesOnEdges(const Idx: array of Integer;
      out Faces: TIntArrayW): Integer;
    { The guide points sitting on these guide lines.  The tape lays the two
      together - a dashed line saying where, and a point saying where along
      it - so rubbing out the line has to take the point with it. }
    function PointsOnGuides(const Idx: array of Integer;
      out Pts: TIntArrayW): Integer;
    { Shift every vertex in the drawing that sits on one of these points.
      Geometry joined to what moves comes along, which is what makes moving
      one edge of a shape stretch the rest of it. }
    procedure MoveVerts(const Pts: TP3Array; const D: TP3);
    { What else will stretch when those corners move D: for every edge that
      is not itself moving but has an end where one of them is, the pair of
      points it will run between afterwards.  The move has always dragged
      these along; this is so the picture can say so while the mouse is
      still down. }
    procedure StretchPreview(const Pts: TP3Array; const D: TP3;
      const Skip: array of Integer; out Segs: TP3Array);
    { Every stored point at or past the plane through Base facing Dir.  What
      a dimension pushes when it is given a new length. }
    procedure VertsBeyond(const Base, Dir: TP3; out Pts: TP3Array);
    { Give a dimension a new length and let the drawing follow.  MoveB moves
      the end it was drawn to; False moves the end it was drawn from. }
    function ResizeDim(Index: Integer; NewLen: Double; MoveB: Boolean): Boolean;
    { What an axis will do to an outline, before it does it.  True when the
      axis runs through the outline rather than beside it; RLo and RHi are
      the inside and outside radius of what would come off the lathe. }
    function AxisSplitsFace(Face: Integer; const AxisP, AxisDir: TP3;
      out RLo, RHi: Double): Boolean;
    procedure RotateEnt(I: Integer; const Pts: TP3Array; const C, Axis: TP3;
      Ang: Double; All: Boolean);
    { Every corner on the set turns about the axis; whatever shares a corner
      stretches to follow, the same rule as MoveVerts.  An arc turns whole. }
    procedure RotateVerts(const Pts: TP3Array; const C, Axis: TP3; Ang: Double);
    { These entities turn whole, whatever they touch - for a copy. }
    procedure RotateEnts(const Idx: array of Integer; const C, Axis: TP3; Ang: Double);
    { These entities shift whole, whatever they touch - a built part being
      put down, which must not drag the corner it happened to be built on. }
    procedure TranslateEnts(const Idx: array of Integer; const D: TP3);
    { The middle of a few things, or of everything if none are named.  What
      "center this on the origin" has to know before it can do it. }
    function MiddleOf(const Idx: array of Integer; out Mid: TP3): Boolean;
    { The box these things sit in - the same walk MiddleOf does, and the
      middle is only the halfway point of it.  Wanted whole for putting a
      selection into the corner at the origin rather than centerd on it. }
    function SpanOf(const Idx: array of Integer; out Lo, Hi: TP3): Boolean;
    { SketchUp's arrays.  N copies of Src along D - at D, 2D, 3D when
      Divide is off (3x), at D/N, 2D/N ... D when it is on (/3) - or turned
      about the axis by Ang, 2Ang ... likewise.  Made is every entity the
      copies are, in order, all appended at the end. }
    procedure ArrayMove(const Src: array of Integer; const D: TP3; N: Integer;
      Divide: Boolean; out Made: TIntArrayW);
    procedure ArrayRotate(const Src: array of Integer; const C, Axis: TP3;
      Ang: Double; N: Integer; Divide: Boolean; out Made: TIntArrayW);
    { The points Outline projects, before projection - for drawing a ghost
      of the thing somewhere other than where it is. }
    function OutlineWorld(I: Integer): TP3Array;
    { --- groups -----------------------------------------------------------
      A group is an ekPart entity; its members are the entities whose Part is
      its id.  Context is the group open for editing (0: the drawing), and
      everything drawn while it is open belongs to it. }
    function NewPart(const Name: string; Parent: Integer): Integer;
    { the ekPart entity carrying this id, or -1 }
    function PartEnt(Id: Integer): Integer;
    function PartName(Id: Integer): string;
    function PartLocked(Id: Integer): Boolean;
    function PartParent(Id: Integer): Integer;
    procedure SetPartName(Id: Integer; const Name: string);
    procedure SetPartLocked(Id: Integer; Locked: Boolean);
    procedure SetPartParent(Id, Parent: Integer);
    { which group an entity is in, and putting it in one }
    procedure SetPart(Index, Id: Integer);
    { Is this entity inside the open context - in it, or in a group inside
      it, however deep?  With nothing open, everything is. }
    function InsideContext(I: Integer): Boolean;
    { The group you would take hold of by clicking this entity: the outermost
      group between it and the open context.  0 when the entity lies loose
      in the context; -1 when it is outside the context altogether. }
    function TopPartIn(I: Integer): Integer;
    { Is that group, or any group between it and the context, locked? }
    function PartLockedUp(Id: Integer): Boolean;
    { every entity in the group, groups inside it and all, and its own
      record last if asked for }
    function PartMembers(Id: Integer; WithRecord: Boolean): TIntArrayW;
    function PartBounds(Id: Integer; out Lo, Hi: TP3): Boolean;
    { walk the ids again after a load or an undo, so the next one is new }
    procedure RecountParts;
    { the group's box as snap points - see the body }
    procedure CrateSnaps(var N: Integer);
    procedure SetContext(Id: Integer);
    function DimIf(I: Integer; const C: TPix): TPix;
    function InkPix(I: Integer): TPix;
    property Context: Integer read FContext write SetContext;
    property Stamp: Integer read FStamp write FStamp;
    property NextPart: Integer read FNextPart;
    { Copy these entities, offset.  A copy stretches nothing. }
    procedure Duplicate(const Idx: array of Integer; const D: TP3);
    { Copy a selection out of the document, deep and with nothing pointing
      back at it, so it survives a switch to another sheet.  PasteIn puts a
      copy back - into this document or a different one - offset by D, with
      the group ids remapped so a pasted solid is its own solid. }
    function CopyOut(const Idx: array of Integer): TWorkEntArray;
    function PasteIn(const Ents: TWorkEntArray; const D: TP3;
      out First, Last: Integer): Integer;
    { Where an entity lands on screen, for a selection box to test against. }
    { Does a box dragged over the screen take this?  See the body - it is
      the geometry that is asked, not the box around it. }
    function BoxTakes(const V: TProjector; I: Integer;
      X0, Y0, X1, Y1: Double; Crossing: Boolean): Boolean;
    { everything a box takes, with guides only if it caught nothing else }
    function BoxPick(const V: TProjector; X0, Y0, X1, Y1: Double;
      Crossing: Boolean): TIntArrayW;
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
    { every entity marked True goes, in one pass; the rest keep their order }
    procedure DeleteMarked(const Doomed: array of Boolean);
    procedure Room;
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
    { GuideTolPx is how close the cursor has to be to a guide, which is not
      the same question as how close to an edge: a guide is construction, it
      runs the width of the drawing, and picking one by accident while
      aiming at something else is what SketchUp avoids by making you be
      right on it.  Left out, it is the same as TolPx. }
    function HitEdge(const V: TProjector; SX, SY, TolPx: Double;
      GuideTolPx: Double = -1): Integer;
    { Does the run from A to B lie along an edge that passes through A?

      The tape leaves a point and no line when it is measured along an edge -
      and "the edge" is not always the one the cursor was over when it
      started: at a corner two edges meet, and a run in from the corner is
      along one of them whichever the click found.  So every edge through A
      is asked, not only that one. }
    function RunsAlongEdge(const A, B: TP3): Boolean;
    { The guide point nearest the cursor, or -1.  Asked before anything else
      the select tool asks, because a guide point is usually sitting on the
      very line it was measured along - and a line passing through a point
      wins on distance from two pixels away. }
    function HitGuidePoint(const V: TProjector; SX, SY, TolPx: Double): Integer;
    { The pen weight of the line running between these two points, or 0 when
      there is not one.  A solid's new edges copy it, so everything drawn
      from the same pen looks like it. }
    function EdgeWeight(const A, B: TP3): Single;
    { The color of the pen that drew this face's outline, or Default when no
      edge of it can be found.  A solid's new edges are drawn with it. }
    function OutlineInk(Face: Integer; Default: TColor): TColor;
    { The nearest point lying *on* a line or an arc, within TolPx of the
      pointer.  This is SketchUp's On Edge inference: hovering an edge should
      give you a point on that edge, not the nearest corner of it. }
    { how many points the cursor is choosing between - for measuring with }
    function SnapCacheCount: Integer;
    function EdgeSnap(const V: TProjector; SX, SY, TolPx: Double;
      out P: TP3; out Ent: Integer): Boolean;
    { The same search, handing back the whole segment under the cursor rather
      than only the point on it - A and B are its two ends.

      The dimension tool needs this and could not have it.  Picking "the body
      of an edge for all of it" went through HitEdge, which looks at lines,
      arcs, dimensions and guides and never at the outline of a face, and
      then read the entity's own A and B - which a face has not got.  So on
      anything built of faces the cursor said ON EDGE, because the snap could
      see it, while the pick could not.

      For a line or an arc the ends are the entity's own, which is what makes
      "all of it" mean the whole line and not the piece under the cursor.  For
      a face it is the one side of the outline being pointed at. }
    function EdgeUnder(const V: TProjector; SX, SY, TolPx: Double;
      out P, A, B: TP3; out Ent: Integer): Boolean;

    { A new drawing has a snap cache to build like any other.

      There was no constructor at all, so the dirty flag started false and
      the cache was not built until the first edit marked it dirty.  That was
      invisible for as long as the cache only held things the drawing
      contained - an empty drawing has no corners to miss - and stopped being
      invisible the moment the origin went in, because the origin is there
      before anything is drawn. }
    constructor Create;
    destructor Destroy; override;

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
    { AtOrigin moves the model so its middle sits on 0,0,0 - the same option
      the STL and the OpenSCAD have, and wanted here for the same reason:
      geometry imported into a Revit family, or any other CAD, arrives
      wherever it was drawn, and a thing drawn forty feet from the origin
      turns up forty feet from where the family wants it. }
    procedure WriteDXF(L: TStrings; const V: TProjector; U: TUnitSystem;
      ThreeD: Boolean; AtOrigin: Boolean = False);
    { The model as an STL, which is the file a 3D printer's slicer wants.

      An STL is nothing but triangles, so this is the same cut the renderer
      uses - FaceCut - written out in the face's own coordinates instead of
      the screen's.  Binary, because ASCII STL is five times the size for the
      same triangles and every slicer reads both.

      In millimeters.  STL carries no units and every slicer in the world
      assumes millimeters, so a drawing in feet is multiplied by 304.8 and one
      in meters by 1000 - which is the difference between a part that prints
      and a part that is three hundred times too small.

      Returns how many triangles went out, and says through Closed whether
      every solid in the drawing was closed.  A slicer can usually patch up
      an open shell, but it is guessing when it does, so it is worth being
      able to tell somebody their model has holes in it before they wait an
      hour for it to print wrong. }
    { AtOrigin moves the middle of the model to 0,0,0 on the way out.  A
      slicer opens a part where the drawing put it, which for a drawing made
      at building coordinates is a long way off the plate, and re-centring it
      by hand in another program is a chore nobody should inherit from us. }
    function WriteSTL(St: TStream; U: TUnitSystem; out Closed: Boolean;
      AtOrigin: Boolean = True): Integer;
    { The model as an OpenSCAD script.

      A polyhedron, which is the only honest answer: OpenSCAD is a language
      for describing shapes by construction and this drawing is not built
      that way, so what goes out is the surface itself - the same triangles
      STL gets, written as points and faces.  It is not parametric and
      pretending otherwise would be a lie in a file somebody then has to
      work with.  What it IS good for is the thing it was asked for: having
      the shape in OpenSCAD so it can be cut, unioned and fitted to
      something else.

      One module per closed solid, so the parts stay separable, plus a module
      that unions them and a call to it.  Millimeters, like the STL.

      Note the winding.  OpenSCAD wants each face's points listed CLOCKWISE
      seen from outside, which is the opposite of STL's rule, and getting it
      backwards gives a shape that looks right in preview and is inside out
      the moment anything is subtracted from it.

      Returns the triangle count, and says how many solids through Solids. }
    function WriteSCAD(L: TStrings; U: TUnitSystem; out Solids: Integer;
      out Closed: Boolean; AtOrigin: Boolean = True): Integer;
    procedure WriteSVG(L: TStrings; const V: TProjector; U: TUnitSystem;
      EdgeW: Single);

  public
    { Where a frame's time went, ms, added up until cleared:

        0  setup, the edge index, and the edges drawn whole
        1  the faces gathered and their depths taken
        2  sorted, and every visible one painted
        3  the lines that live on a face, put back on the visible stretches
        4  guide points, and the tidying up

      The list used to be one out of step with the code, which sent a
      profiling session after the wrong pass. }
    ProfMs: array[0..5] of Double;
    { The surface and the projector of the last render.  Its depth buffer
      answers "is this point hidden" in one lookup for anything asked with
      the same projector - the selection outline, the hover, the snap - where
      walking every face was the cube of the drawing on a big part. }
    LastSurf: TArtSurface;
    LastV: TProjector;
    { True once a borrowed surface has been freed out from under us.  Only
      there so a report can say it happened; the pointer is nil either way. }
    LastSurfDied: Boolean;
    { Which faces each line, arc, dimension or note lies in the plane of,
      over the face's own extent.  The render asks this for every such
      thing against every face, every frame; it depends on the geometry
      alone, so it is worked out once when the drawing changes. }
    FOnFace: array of TIntArrayW;
    FOnFaceOK: Boolean;
    OnFaceBuilds: Integer;
    { The first thing done on a worker thread, and the pattern for the rest
      (docs/render-acceleration.md).  With Threads on, the cache is built
      from a deep copy of the entities on a worker and queued back; the
      main thread takes it only if the drawing has not changed since (the
      edit sequence).  Until it arrives the renderer searches every face,
      as it did before the cache existed - the worker only ever speeds
      things up, and nothing is wrong when it is late, discarded or off. }
    Threads: Boolean;
    FEditSeq: Integer;
    FOnFaceWorker: TThread;
    { the last build of the cache: how long, and where it ran }
    OnFaceWorkerMs: Double;
    OnFaceBuiltOn: string;
    { how long the finished result waited in the queue before the main
      thread took it, and how much a frame without the cache spent on the
      lines-on-faces pass - the two numbers that say whether a worker is
      worth it }
    OnFaceLagMs: Double;
    OnFaceFallbackMs: Double;
    OnFaceDiscarded, OnFaceFailed, OnFaceFallbacks: Integer;
    { The quick frame: while the camera is moving, lines on faces are
      sampled a quarter as often and the cover edge is not bisected.  The
      picture is complete, only rougher at the ends of hidden runs; the
      full frame comes when the camera stops. }
    Quick: Boolean;
    procedure EnsureOnFace;
    procedure OnFaceArrived;
    { the cache is there and current }
    function OnFaceReady: Boolean;
    { the one-lookup form of HiddenAt; only valid straight after a render
      with the same projector }
    function DepthHidden(const P: TP3): Boolean;
    { the nearest drawn thing within Radius pixels of a screen point, as a
      world point, from the last frame's depth buffer - what the eye is
      looking at, whether or not a face is exactly under the cursor }
    function DepthPointNear(SX, SY, Radius: Integer; out P: TP3): Boolean;
  public
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

  { snap increments, in world units (feet / meters); 0 means no snapping }
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
{ the point T of the way from A to B }
function Lerp3(const A, B: TP3; T: Double): TP3;
function SamePt(const A, B: TP3; Tol: Double): Boolean; inline;
{ Do these two segments lie on each other over a run, rather than merely
  touch at a point or cross?  That is the question "is this edge part of that
  edge", which is what decides whether a face is held up by an edge and
  whether a line has been traced over one already there. }
function SharesRun(const P1, Q1, P2, Q2: TP3): Boolean;

{ --- projection ---------------------------------------------------------- }
function SameProjector(const A, B: TProjector): Boolean;
function Project(const V: TProjector; const P: TP3): TPointF;

{ The same projection with the camera worked out once.

  Project recomputes ViewRight and ViewUp on every call, and in an orbit view
  each of those is a pair of sines and cosines - so projecting one point
  costs four transcendental calls, and anything that projects a few thousand
  points pays for the camera a few thousand times over.  That is most of what
  a snap search spends its time on.

  BeginProject does the trigonometry once; ProjectAt is then two dot products
  and a pair of multiplies.  The answer is identical - it is the same
  arithmetic with the constants lifted out of the loop. }
type
  TProjCache = record
    Kind: TViewKind;
    Ppu, OX, OY: Double;
    R, U: TP3;
  end;

procedure BeginProject(const V: TProjector; out C: TProjCache);
function ProjectAt(const C: TProjCache; const P: TP3): TPointF; inline;

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
  to read.  So the box has to be cleared rather than the center moved: the
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
{ What the tape leaves behind, which depends on where it was pulled from.

  SketchUp's rule, and the one What was asked for was on 17 September: "when i draw a
  point in from the corner staying in the line it drops a point only... but
  if i used the tape measure from the line and set it up into the face of the
  rectangle then it does the guide line".

  * Started on an edge and pulled off it - a guide line parallel to that
    edge, through where the measurement landed.  Their help: "click a point
    on an entity parallel to where the guide should go, move the cursor
    perpendicular to that point."
  * Along an edge - a point, and no line.  A guide lying on top of the edge
    it was measured along marks nothing.
  * Neither - the line across the run, which is ours: from a corner, or in
    mid air, there is no edge to be parallel to, and a line crosswise to the
    measurement is the one that marks the distance. }
type
  TTapeGuide = (tgPointOnly, tgAlongEdge, tgAcrossRun);

function TapeGuide(HaveEdge: Boolean; const EdgeDir, A, B, PlaneNm: TP3;
  out Dir: TP3): TTapeGuide;

{ How far the middle of an arc stands off the middle of its chord - the
  sagitta, which this program calls the bulge - for the arc that leaves A
  along Dir and ends at B.

  SketchUp's tangent arc, which Alt locks: "hover the edge you want it
  tangent to before the first click".  For a circular arc the angle between
  the chord and the tangent at an end is half the arc's own angle, so the
  sagitta is (chord / 2) * tan(that angle / 2).  The sign says which side of
  the chord it bulges towards.

  False when there is no arc to be had: the tangent runs straight along the
  chord, straight back down it, or out of the plane being drawn on. }
function TangentSagitta(const A, B, Dir: TP3; Pl: TPlane;
  out Bulge: Double): Boolean;


function OffsetLoop(const Loop: TP3Array; const Normal: TP3; D: Double;
  Tidy: Boolean = True): TP3Array;

{ The two in-plane coordinates of a model point. }
procedure PlaneCoords(Pl: TPlane; const P: TP3; out U, W: Double);

{ The stretch of an infinite line that crosses a rectangle.

  Given a point on the line and a direction along it, both in screen terms,
  come back with the two parameters where it enters and leaves the box.
  False when it misses the box altogether.

  This is what lets a line that is infinite in the model be drawn as what it
  is.  The axes were drawn a fixed number of world units out from the origin,
  which is fine while the origin is on screen and wrong the moment you pan
  away from it: they stopped in mid air, and in a program where the red line
  IS the X axis, an axis with an end is a lie about the model. }
function ClipToBox(PX, PY, DX, DY, W, H: Double; out T0, T1: Double): Boolean;

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
    much later.  Coloring the back is how that is caught on sight, and it is
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
    { Sc.Paper is paper meters per meter }
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
  Metric:    3.5   3.5m   350cm   3500mm   (bare number is meters) }
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

{ A round length that comes out between MinPx and MaxPx on the glass.

  The tables run further at both ends than they used to.  They began at half
  a foot, so once the view could be wound in past a few hundred percent there
  was no length short enough and the scale bar simply ran the width of the
  window with "0'-6"" on it; and they stopped at two hundred feet, so far
  enough out the bar stopped growing.  The zoom range is a million to one
  now and the bar has to be able to say so.

  Both keep the shape they had - the imperial one in the 1-2-5 steps that
  land on sixteenths and inches and feet, the metric one in its own - and
  simply carry on in both directions. }
function NiceBarLength(Ppu: Double; MinPx, MaxPx: Double; U: TUnitSystem): Double;
const
  N_STEP = 16;
  { Feet, and at the short end exact inch fractions rather than round
    decimals - a sixteenth, an eighth, a quarter, a half, an inch.  A bar of
    0.002 feet is a perfectly good length and reads 0'-0" on the label,
    which is a bar that cannot say what it is. }
  IMP: array[0..N_STEP] of Double =
    (1/192, 1/96, 1/48, 1/24, 1/12, 0.25, 0.5,
     1, 2, 5, 10, 20, 50, 100, 200, 500, 1000);
  MET: array[0..N_STEP] of Double =
    (0.0005, 0.001, 0.0025, 0.005, 0.01, 0.025, 0.05,
     0.1, 0.25, 0.5, 1, 2, 5, 10, 20, 50, 100);
var
  I: Integer;
  V: Double;
begin
  Result := 1;
  for I := 0 to N_STEP do
  begin
    if U = usImperial then V := IMP[I] else V := MET[I];
    Result := V;
    if V * Ppu >= MinPx then Exit;
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
function ClipToBox(PX, PY, DX, DY, W, H: Double; out T0, T1: Double): Boolean;

  { Liang-Barsky, one edge at a time: the line runs P + T*D, and each edge
    says either "no T at all" or trims one end of the range. }
  function Edge(Num, Den: Double): Boolean;
  var
    T: Double;
  begin
    Result := True;
    if Abs(Den) < 1E-12 then
    begin
      { Parallel to this edge.  Num is how far inside it the line sits, so
        it is on the paper when that is not negative. }
      Result := Num >= 0;
      Exit;
    end;
    T := Num / Den;
    if Den < 0 then
    begin
      if T > T1 then Exit(False);
      if T > T0 then T0 := T;
    end
    else
    begin
      if T < T0 then Exit(False);
      if T < T1 then T1 := T;
    end;
  end;

begin
  T0 := -1E30;
  T1 := 1E30;
  { Num is the distance inside the edge, Den the rate the line crosses it:
    negative Den is coming in, positive is going out.  Getting the pair the
    wrong way round leaves T right and swaps entering for leaving, which
    clips every line to nothing - and looks exactly like the axes being
    switched off. }
  Result := Edge(PX, -DX) and Edge(W - PX, DX) and
            Edge(PY, -DY) and Edge(H - PY, DY) and (T0 <= T1);
end;

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
function SameProjector(const A, B: TProjector): Boolean;
begin
  Result := (A.Kind = B.Kind) and (A.Ppu = B.Ppu) and (A.OX = B.OX) and
            (A.OY = B.OY) and (A.Az = B.Az) and (A.El = B.El);
end;

procedure BeginProject(const V: TProjector; out C: TProjCache);
begin
  C.Kind := V.Kind;
  C.Ppu := V.Ppu;
  C.OX := V.OX;
  C.OY := V.OY;
  C.R := ViewRight(V);
  C.U := ViewUp(V);
end;

function ProjectAt(const C: TProjCache; const P: TP3): TPointF;
begin
  if C.Kind = vkOrbit then
  begin
    Result.X := C.OX + (P.X * C.R.X + P.Y * C.R.Y + P.Z * C.R.Z) * C.Ppu;
    Result.Y := C.OY - (P.X * C.U.X + P.Y * C.U.Y + P.Z * C.U.Z) * C.Ppu;
    Exit;
  end;
  if C.Kind = vkIso then
  begin
    Result.X := C.OX + (P.X + P.Y) * ISO_COS * C.Ppu;
    Result.Y := C.OY - ((P.Y - P.X) * ISO_SIN + P.Z) * C.Ppu;
  end
  else
  begin
    Result.X := C.OX + P.X * C.Ppu;
    Result.Y := C.OY - P.Y * C.Ppu;
  end;
end;

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

function TangentSagitta(const A, B, Dir: TP3; Pl: TPlane;
  out Bulge: Double): Boolean;
var
  U1, V1, U2, V2, DU, DV, Ln, TU, TV, TL, Cs, Sn, Ang: Double;
  AU, AV: TP3;
begin
  Result := False;
  Bulge := 0;
  PlaneCoords(Pl, A, U1, V1);
  PlaneCoords(Pl, B, U2, V2);
  DU := U2 - U1;
  DV := V2 - V1;
  Ln := Sqrt(Sqr(DU) + Sqr(DV));
  if Ln < 1E-9 then Exit;
  PlaneAxes(Pl, AU, AV);
  TU := Dot3(Dir, AU);
  TV := Dot3(Dir, AV);
  TL := Sqrt(Sqr(TU) + Sqr(TV));
  if TL < 1E-9 then Exit;              { the edge stands out of the plane }
  TU := TU / TL;
  TV := TV / TL;
  DU := DU / Ln;
  DV := DV / Ln;
  { the tangent runs both ways along the edge; take the way that leaves A
    heading towards B }
  if TU * DU + TV * DV < 0 then
  begin
    TU := -TU;
    TV := -TV;
  end;
  Cs := TU * DU + TV * DV;
  Sn := TU * DV - TV * DU;             { signed: which side it leans }
  Ang := ArcTan2(Sn, Cs);
  if Abs(Ang) < 1E-6 then Exit;        { straight on: no arc, no tangent }
  if Abs(Abs(Ang) - Pi) < 1E-6 then Exit;
  Bulge := -(Ln / 2) * Tan(Ang / 2);
  Result := True;
end;

function TapeGuide(HaveEdge: Boolean; const EdgeDir, A, B, PlaneNm: TP3;
  out Dir: TP3): TTapeGuide;
var
  Run, E, X: TP3;
  L: Double;
begin
  Dir := P3(0, 0, 0);
  Run := P3(B.X - A.X, B.Y - A.Y, B.Z - A.Z);
  L := Sqrt(Sqr(Run.X) + Sqr(Run.Y) + Sqr(Run.Z));
  if L < 1E-9 then Exit(tgPointOnly);
  Run := P3(Run.X / L, Run.Y / L, Run.Z / L);

  if HaveEdge then
  begin
    L := Sqrt(Sqr(EdgeDir.X) + Sqr(EdgeDir.Y) + Sqr(EdgeDir.Z));
    if L > 1E-9 then
    begin
      E := P3(EdgeDir.X / L, EdgeDir.Y / L, EdgeDir.Z / L);
      X := Cross3(E, Run);
      { measured along the edge it started on: a point, nothing else }
      if Sqrt(Sqr(X.X) + Sqr(X.Y) + Sqr(X.Z)) < 1E-6 then Exit(tgPointOnly);
      Dir := E;
      Exit(tgAlongEdge);
    end;
  end;

  { across the run, in the working plane }
  X := Cross3(PlaneNm, Run);
  L := Sqrt(Sqr(X.X) + Sqr(X.Y) + Sqr(X.Z));
  if L < 1E-9 then
  begin
    { measured straight out of the working plane, so there is no crosswise
      direction in it - fall back to the run itself rather than to nothing }
    Dir := Run;
    Exit(tgAcrossRun);
  end;
  Dir := P3(X.X / L, X.Y / L, X.Z / L);
  Result := tgAcrossRun;
end;

function OffsetLoop(const Loop: TP3Array; const Normal: TP3; D: Double;
  Tidy: Boolean = True): TP3Array;
const
  EPS = 1E-9;
var
  N, Ax, Bx: TP3;
  Cnt, I, J, K: Integer;
  PU, PV: array of Double;         // the loop, in plane coordinates
  DU, DV: array of Double;         // each edge's unit direction
  NU, NV: array of Double;         // each edge's outward normal
  RU, RV: array of Double;         // the answer, in plane coordinates
  Act: array of Integer;           // the edges still in it
  Keep: array of Boolean;
  M, Q, Turned: Integer;
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
        its neighbors span the gap }
      DU[I] := 0; DV[I] := 0; NU[I] := 0; NV[I] := 0;
      Continue;
    end;
    DU[I] := DU[I] / L;
    DV[I] := DV[I] / L;
    { to the right of the way it is going, for a loop wound the positive way }
    NU[I] := DV[I] * Sgn;
    NV[I] := -DU[I] * Sgn;
  end;

  { The edges still in the answer.  One with no length has no direction to
    offset along, so it is left out from the start and its neighbors meet
    across it. }
  SetLength(Act, Cnt);
  M := 0;
  for I := 0 to Cnt - 1 do
    if (DU[I] <> 0) or (DV[I] <> 0) then
    begin
      Act[M] := I;
      Inc(M);
    end;

  { Corners, then the edges that came out backwards, then again without them.

    Each corner is where the offsets of two neighboring edges meet.  That is
    exact for a corner - but an edge shorter than the offset can come out
    pointing the wrong way, its two corners having crossed over.  An arc is a
    run of exactly such edges: taken in further than its radius, every piece
    of a rounded corner turned round, and the corner came out as a little
    loop the wrong way about.  From a note, 17 September: "if i tried to offset it
    inside it looked like it was flipping the inner rounded corners the wrong
    way".  SketchUp's answer is the one geometry gives: the rounding is used
    up and the corner is sharp.  So a piece that has turned round is taken
    out, and the edges either side of it meet directly.  Taking one out moves
    the corners either side, which can turn another, so it goes round until
    nothing has. }
  SetLength(RU, Cnt); SetLength(RV, Cnt);
  repeat
    if M < 3 then Exit(nil);
    for Q := 0 to M - 1 do
    begin
      I := Act[Q];
      K := Act[(Q + M - 1) mod M];
      { corner Q is where the offset of the edge before meets this one's }
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
      RU[Q] := AU;
      RV[Q] := AV;
    end;
    { which of them now run backwards along their own edge }
    Turned := 0;
    SetLength(Keep, M);
    for Q := 0 to M - 1 do
    begin
      I := Act[Q];
      J := (Q + 1) mod M;
      Keep[Q] := (RU[J] - RU[Q]) * DU[I] + (RV[J] - RV[Q]) * DV[I] > EPS;
      if not Keep[Q] then Inc(Turned);
    end;
    if Turned = 0 then Break;
    if Turned = M then Exit(nil);          { the whole thing turned inside out }
    { Alt on the offset tool says leave them: SketchUp keeps the overlaps
      when it is held, and a fitter who wants to see what the corner really
      did is entitled to.  The loops are geometry, they are just not tidy. }
    if not Tidy then Break;
    J := 0;
    for Q := 0 to M - 1 do
      if Keep[Q] then
      begin
        Act[J] := Act[Q];
        Inc(J);
      end;
    M := J;
  until False;

  SetLength(Result, M);
  for Q := 0 to M - 1 do
    { Back into the model, and out to the plane the loop is actually on.

      Ax and Bx span the plane through the origin parallel to the face, and
      a corner rebuilt from them alone lands on that one.  A face on the
      ground is that plane, so an offset there always came out where it should;
      the top of a four foot box is the same plane four feet up, and its
      offset came back on the ground - the side of the box at x = 6 got its
      offset at x = 0.  A mile away, when the face is a long way from the
      origin.  The plane's own height along its normal is the missing part,
      and it is the same for every corner. }
    Result[Q] := P3(Ax.X * RU[Q] + Bx.X * RV[Q] + N.X * Lift,
                    Ax.Y * RU[Q] + Bx.Y * RV[Q] + N.Y * Lift,
                    Ax.Z * RU[Q] + Bx.Z * RV[Q] + N.Z * Lift);

  { An offset inward that goes further than the shape can take turns it
    inside out - a 10 x 6 box taken in by 4 comes back as a line, and by 5 as
    a box wound the other way.  Neither is an offset of anything, so say so
    by returning nothing rather than laying down a sliver that looks like
    geometry and measures wrong. }
  T := 0;
  for Q := 0 to M - 1 do
  begin
    J := (Q + 1) mod M;
    T := T + (RU[Q] * RV[J] - RU[J] * RV[Q]);
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

    The two in-plane axes put the center on a plane through the origin, so it
    has to be moved out to the one the chord is actually on - which is what
    the third coordinate did for the axis-square planes: pin Z for a flat
    one, Y for XZ, X for YZ.

    Said once instead of three times, because there is a fourth.  A free
    plane - a roof, the sloping side of a transition - has no third
    coordinate to pin, and it was falling through the case with none of them
    applied: the center came out on a plane through the origin parallel to
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
{ How far along a segment its nearest point to P lies, 0 at A and 1 at B.
  The same arithmetic DistToSeg does; kept apart because the pick wants the
  place as well as the distance - what is under the cursor is decided at the
  spot you are pointing at, not somewhere else along the edge. }
function SegParam(PX, PY, AX, AY, BX, BY: Double): Double;
var
  DX, DY, L2: Double;
begin
  DX := BX - AX;
  DY := BY - AY;
  L2 := DX * DX + DY * DY;
  if L2 < 1E-12 then Exit(0);
  Result := EnsureRange(((PX - AX) * DX + (PY - AY) * DY) / L2, 0, 1);
end;

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
  Result := FLive;
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

function TWorkDoc.AddLineSplit(const A, B: TP3; Ink: TColor;
  Weight: Single): Integer;
const
  TOL = 1E-7;
var
  U: TP3;
  L, T0, T1, Mid: Double;
  I, J, N, NC: Integer;
  Hits: array of Integer;
  HA, HB: array of Double;    { each hit's run, as a distance along U }
  { and the pen each was drawn with, read before anything is deleted:
    deleting moves every index above it down }
  HInk: array of TColor;
  HW: array of Single;
  Cuts: array of Double;
  Doom: array of Boolean;
  Src: Integer;
  PieceA, PieceB: TP3;

  { how far along the line from A this point is, and how far off it }
  function Along(const Q: TP3; out Off: Double): Double;
  var
    W, F: TP3;
  begin
    W := P3(Q.X - A.X, Q.Y - A.Y, Q.Z - A.Z);
    Result := Dot3(W, U);
    F := P3(W.X - U.X * Result, W.Y - U.Y * Result, W.Z - U.Z * Result);
    Off := Sqrt(F.X * F.X + F.Y * F.Y + F.Z * F.Z);
  end;

  procedure Cut(T: Double);
  var
    K: Integer;
  begin
    for K := 0 to NC - 1 do
      if Abs(Cuts[K] - T) < TOL then Exit;
    if NC >= Length(Cuts) then SetLength(Cuts, Max(16, NC * 2));
    Cuts[NC] := T;
    Inc(NC);
  end;

  { which hit covers the middle of this piece, or -1 for the new line only }
  function Owner(M: Double): Integer;
  var
    K: Integer;
  begin
    Result := -1;
    for K := 0 to High(Hits) do
      if (M > Min(HA[K], HB[K]) + TOL) and (M < Max(HA[K], HB[K]) - TOL) then
        Exit(K);
  end;

begin
  Result := 0;
  L := Dist(A, B);
  if L < TOL then Exit;
  U := P3((B.X - A.X) / L, (B.Y - A.Y) / L, (B.Z - A.Z) / L);

  { everything loose that lies along this line and shares more than a point }
  SetLength(Hits, 0);
  SetLength(HA, 0);
  SetLength(HB, 0);
  for I := 0 to FLive - 1 do
  begin
    if FEnts[I].Kind <> ekLine then Continue;
    if FEnts[I].Dim or (FEnts[I].Grp <> 0) or (FEnts[I].Part <> FStamp) then Continue;
    T0 := Along(FEnts[I].A, Mid);
    if Mid > TOL then Continue;
    T1 := Along(FEnts[I].B, Mid);
    if Mid > TOL then Continue;
    { sharing a run, not merely a corner }
    if Min(T0, T1) > L - TOL then Continue;
    if Max(T0, T1) < TOL then Continue;
    N := Length(Hits);
    SetLength(Hits, N + 1); Hits[N] := I;
    SetLength(HA, N + 1);   HA[N] := T0;
    SetLength(HB, N + 1);   HB[N] := T1;
    SetLength(HInk, N + 1); HInk[N] := FEnts[I].Ink;
    SetLength(HW, N + 1);   HW[N] := FEnts[I].Weight;
  end;

  if Length(Hits) = 0 then
  begin
    AddLine(A, B, Ink, Weight, False);
    Exit;
  end;

  { every end anybody has, as a distance along the line }
  NC := 0;
  SetLength(Cuts, 16);
  Cut(0);
  Cut(L);
  for I := 0 to High(Hits) do
  begin
    Cut(HA[I]);
    Cut(HB[I]);
  end;
  for I := 0 to NC - 2 do
    for J := 0 to NC - 2 - I do
      if Cuts[J] > Cuts[J + 1] then
      begin
        Mid := Cuts[J]; Cuts[J] := Cuts[J + 1]; Cuts[J + 1] := Mid;
      end;

  { the old ones go; the run is laid again in pieces }
  SetLength(Doom, FLive);
  for I := 0 to FLive - 1 do Doom[I] := False;
  for I := 0 to High(Hits) do Doom[Hits[I]] := True;

  SetLength(Cuts, NC);
  DeleteMarked(Doom);

  for I := 0 to NC - 2 do
  begin
    T0 := Cuts[I];
    T1 := Cuts[I + 1];
    if T1 - T0 < TOL then Continue;
    Mid := (T0 + T1) / 2;
    Src := Owner(Mid);
    if (Src < 0) and ((Mid < TOL) or (Mid > L - TOL)) then Continue;
    PieceA := P3(A.X + U.X * T0, A.Y + U.Y * T0, A.Z + U.Z * T0);
    PieceB := P3(A.X + U.X * T1, A.Y + U.Y * T1, A.Z + U.Z * T1);
    { a piece that was already drawn keeps the pen it was drawn with }
    if Src >= 0 then
      AddLine(PieceA, PieceB, HInk[Src], HW[Src], False)
    else
      AddLine(PieceA, PieceB, Ink, Weight, False);
    Inc(Result);
  end;
end;

procedure TWorkDoc.AddLine(const A, B: TP3; Ink: TColor; Weight: Single;
  Dim: Boolean);
begin
  Room;
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FEnts[FLive].Kind := ekLine;
  FEnts[FLive].Part := FStamp;
  FEnts[FLive].A := A;
  FEnts[FLive].B := B;
  FEnts[FLive].Ink := Ink;
  FEnts[FLive].Weight := Weight;
  FEnts[FLive].Dim := Dim;
  Inc(FLive);
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
end;

procedure TWorkDoc.AddArc(const C: TP3; R, A0, Sweep: Double; Pl: TPlane;
  Ink: TColor; Weight: Single);
var
  FreeO, FreeU, FreeV: TP3;
begin
  Room;
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FEnts[FLive].Kind := ekArc;
  FEnts[FLive].Part := FStamp;
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
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
end;

procedure TWorkDoc.AddText(const A: TP3; const S: string; Ink: TColor);
begin
  AddNote(A, A, S, Ink);
end;

procedure TWorkDoc.AddNote(const A, Target: TP3; const S: string; Ink: TColor);
begin
  Room;
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FEnts[FLive].Kind := ekText;
  FEnts[FLive].Part := FStamp;
  FEnts[FLive].A := A;
  FEnts[FLive].B := Target;
  FEnts[FLive].Txt := S;
  FEnts[FLive].Ink := Ink;
  FEnts[FLive].Weight := 1;
  Inc(FLive);
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
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
  Room;
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FEnts[FLive].Kind := ekBore;
  FEnts[FLive].Part := FStamp;
  FEnts[FLive].Poly := Own;
  FEnts[FLive].A := Own[0];
  FEnts[FLive].B := Far;
  FEnts[FLive].Grp := G;
  FEnts[FLive].Solid := True;
  Inc(FLive);
end;

procedure TWorkDoc.AddGuide(const A, B: TP3);
begin
  Room;
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FEnts[FLive].Kind := ekGuide;
  FEnts[FLive].Part := FStamp;
  FEnts[FLive].A := A;
  FEnts[FLive].B := B;
  FEnts[FLive].Weight := 1;
  Inc(FLive);
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
end;

{ Guides away, and the pickers told.

  Hiding them used to change only what was drawn.  Everything that answers
  "what is under the cursor" carried on finding them: the snap jumped to a
  guide point and to guide crossings, the cursor ran along a guide line, and
  the select tool and the eraser both took guides you could not see.  Two of
  the six pickers had the check and the rest had never been asked.

  The snap cache is the reason this is a setter rather than a field.  It is
  built once and kept until an edit, so a guide point put into it stays there
  however the switch moves afterwards. }
procedure TWorkDoc.SetGuidesHidden(On_: Boolean);
begin
  if On_ = FGuidesHidden then Exit;
  FGuidesHidden := On_;
  FSnapDirty := True;
  FSnapScreenOK := False;
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
  Room;
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FEnts[FLive].Kind := ekDim;
  FEnts[FLive].Part := FStamp;
  FEnts[FLive].A := A;
  FEnts[FLive].B := B;
  FEnts[FLive].C := Off;
  FEnts[FLive].Ink := Ink;
  FEnts[FLive].Weight := 1;
  FEnts[FLive].Dim := True;
  FEnts[FLive].Txt := Note;
  Inc(FLive);
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
end;

{ FEnts is capacity and FLive the count: adding one no longer reallocates
  the whole array, and deleting one no longer shrinks it.  Fifteen thousand
  faces added one at a time to fifty thousand things used to be fifteen
  thousand copies of the lot. }
procedure TWorkDoc.Room;
begin
  if FLive >= Length(FEnts) then SetLength(FEnts, Max(16, Length(FEnts) * 2));
end;

procedure TWorkDoc.Delete(I: Integer);
var
  K: Integer;
begin
  if (I < 0) or (I >= FLive) then Exit;
  for K := I to FLive - 2 do
    FEnts[K] := FEnts[K + 1];
  Dec(FLive);
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
end;

procedure TWorkDoc.DeleteMarked(const Doomed: array of Boolean);
var
  K, W: Integer;
begin
  W := 0;
  for K := 0 to FLive - 1 do
    if (K > High(Doomed)) or not Doomed[K] then
    begin
      if W <> K then FEnts[W] := FEnts[K];
      Inc(W);
    end;
  for K := W to FLive - 1 do
  begin
    Finalize(FEnts[K]);
    FillChar(FEnts[K], SizeOf(TWorkEnt), 0);
  end;
  FLive := W;
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
end;

procedure TWorkDoc.Clear;
begin
  SetLength(FEnts, 0);
  FLive := 0;
  FNextPart := 0;
  FContext := 0;
  FStamp := 0;
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
end;


{ A face carries its outline in a dynamic array, and plain record assignment
  would only share the reference - so a later push/pull that rewrites those
  points in place would reach back and corrupt the undo snapshot with it.
  Every copy has to be a deep one. }
function CopyEnt(const Src: TWorkEnt): TWorkEnt;
var
  I, H: Integer;
begin
  Result := Src;
  Result.Poly := nil;
  SetLength(Result.Poly, Length(Src.Poly));
  for I := 0 to High(Src.Poly) do
    Result.Poly[I] := Src.Poly[I];
  { And the openings, which this did not copy for as long as it existed.

    The note above says every copy has to be a deep one and then only made
    the outline deep.  Holes is an array of arrays, so both the outer one and
    every loop in it were shared with the entity being copied - and a move
    writes those loops in place.  So moving a face with a window in it wrote
    through the undo snapshot into the past: the outline went back where it
    came from and the window stayed where it had been dragged to.

    From a note, 15 September: "notice i moved the heckers sketch block words and
    then hit undo and it left behind something where i had moved it to before
    undoing.  it is like it brought faces with it and left them behind."  The
    block words are exactly the faces with windows in them - the counters
    inside the E, the A, the S. }
  Result.Holes := nil;
  SetLength(Result.Holes, Length(Src.Holes));
  for H := 0 to High(Src.Holes) do
  begin
    SetLength(Result.Holes[H], Length(Src.Holes[H]));
    for I := 0 to High(Src.Holes[H]) do
      Result.Holes[H][I] := Src.Holes[H][I];
  end;
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
  { the groups came back with the entities; the numbering has to catch up,
    and a context that was undone out of existence is nobody's to keep }
  RecountParts;
  if (FContext <> 0) and (PartEnt(FContext) < 0) then SetContext(0);
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
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

procedure TWorkDoc.SetSlice(AOn: Boolean; ALo, AHi: Double);
var
  T: Double;
begin
  if AHi < ALo then begin T := ALo; ALo := AHi; AHi := T; end;
  if (FSliceOn = AOn) and (FSliceLo = ALo) and (FSliceHi = AHi) then Exit;
  FSliceOn := AOn;
  FSliceLo := ALo;
  FSliceHi := AHi;
  { The snap cache is a list of points that are there to be snapped to, and
    the slice decides which points those are.  Changing one without the other
    is how you get a cursor sticking to something you cannot see. }
  FSnapDirty := True;
  FSnapScreenOK := False;
  FOnFaceOK := False;
end;

function TWorkDoc.InSlice(Index: Integer): Boolean;
const
  EPS = 1E-7;
var
  Lo, Hi: Double;
  K: Integer;

  procedure Grow(V: Double);
  begin
    if V < Lo then Lo := V;
    if V > Hi then Hi := V;
  end;

begin
  Result := True;
  if not FSliceOn then Exit;
  if (Index < 0) or (Index >= FLive) then Exit;
  Lo := 1E300;
  Hi := -1E300;
  case FEnts[Index].Kind of
    ekFace:
      begin
        for K := 0 to High(FEnts[Index].Poly) do Grow(FEnts[Index].Poly[K].Z);
        if Length(FEnts[Index].Poly) = 0 then Grow(FEnts[Index].A.Z);
      end;
    ekArc:
      begin
        { the whole circle it is cut from, because a tilted arc reaches above
          and below its own ends }
        Grow(FEnts[Index].C.Z - FEnts[Index].R);
        Grow(FEnts[Index].C.Z + FEnts[Index].R);
      end;
    ekText:
      Grow(FEnts[Index].A.Z);
  else
    begin
      Grow(FEnts[Index].A.Z);
      Grow(FEnts[Index].B.Z);
    end;
  end;
  { any overlap at all counts.  A wall that starts below the slice and
    carries on above it is in the drawing - that is what a cut is. }
  Result := (Hi >= FSliceLo - EPS) and (Lo <= FSliceHi + EPS);
end;

function TWorkDoc.OutsideSlice: Integer;
var
  I: Integer;
begin
  Result := 0;
  if not FSliceOn then Exit;
  for I := 0 to FLive - 1 do
    if not InSlice(I) then Inc(Result);
end;

{ Is this solid closed?

  Every edge of it used by exactly two of its faces, and run the opposite way
  round by each - the paper-folding test.  A shape that passes cannot show
  you the back of any of its faces, ever: to see one you would have to be
  inside it.

  Which is why this exists.  Back faces were culled by the sign of their
  normal once, and that was taken out for a good reason - a duct transition
  is an open shell with an end at each end, their normals point opposite
  ways, and culling by sign made one of them unreachable from any given
  place to stand.  So it was left to the depth buffer instead, and the depth
  buffer cannot always get it right: a face that is not flat has no true
  depth, only a fitted one, and where the fit is off the far side of a solid
  wins and paints its inside over the near side in pale blue.

  Both rules are right in their own case, and the two cases can be told
  apart.  Closed: cull, because a back face is unseeable and drawing one can
  only ever be wrong.  Open: draw it, because there the back really can be
  looked at.

  Worked out once per edit and kept, because it walks every face of every
  solid and the camera moves far more often than the drawing changes. }
function TWorkDoc.FaceCorners(Index: Integer): TP3Array;
var
  I, J, N: Integer;
begin
  Result := nil;
  if (Index < 0) or (Index >= FLive) then Exit;
  if FEnts[Index].Kind <> ekFace then Exit;
  N := Length(FEnts[Index].Poly);
  for I := 0 to High(FEnts[Index].Holes) do
    Inc(N, Length(FEnts[Index].Holes[I]));
  SetLength(Result, N);
  N := 0;
  for I := 0 to High(FEnts[Index].Poly) do
  begin
    Result[N] := FEnts[Index].Poly[I];
    Inc(N);
  end;
  for I := 0 to High(FEnts[Index].Holes) do
    for J := 0 to High(FEnts[Index].Holes[I]) do
    begin
      Result[N] := FEnts[Index].Holes[I][J];
      Inc(N);
    end;
end;

function TWorkDoc.FaceCut(Index: Integer): TTriList;
var
  Nm, U, W: TP3;
  Corners: TP3Array;
  Flat2: array of TPointF;
  Ring: TIndexRing;
  Holes: TIndexRings;
  I, J, N, Base, Was, Fresh: Integer;
begin
  Result := nil;
  if (Index < 0) or (Index >= FLive) then Exit;
  if FEnts[Index].Kind <> ekFace then Exit;
  if Length(FEnts[Index].Poly) < 3 then Exit;

  if Length(FCut) < FLive then
  begin
    Was := Length(FCut);
    SetLength(FCut, FLive);
    { the edit sequence starts at zero, so zero cannot also be how a fresh
      entry says it has never been cut }
    for Fresh := Was to FLive - 1 do FCut[Fresh].Seq := -1;
  end;
  { the edit sequence is bumped by every change to the drawing, so an entry
    left over from before one - at an index that may now hold something else
    entirely - can never be mistaken for a current answer }
  if FCut[Index].Seq = FEditSeq then
  begin
    Result := FCut[Index].Tris;
    Exit;
  end;

  Corners := FaceCorners(Index);
  Nm := FaceNormal(Index);

  { two axes across the face, to flatten it into its own plane.  Any pair
    perpendicular to the normal will do - which way round they land only
    decides which way the flattened outline winds, and the cutting does not
    care about that. }
  U := P3(1, 0, 0);
  if Abs(Nm.X) > 0.9 then U := P3(0, 1, 0);
  U := Norm3(Cross3(Nm, U));
  W := Norm3(Cross3(Nm, U));

  SetLength(Flat2, Length(Corners));
  for I := 0 to High(Corners) do
  begin
    Flat2[I].X := Dot3(Corners[I], U);
    Flat2[I].Y := Dot3(Corners[I], W);
  end;

  N := Length(FEnts[Index].Poly);
  SetLength(Ring, N);
  for I := 0 to N - 1 do Ring[I] := I;
  SetLength(Holes, Length(FEnts[Index].Holes));
  Base := N;
  for I := 0 to High(FEnts[Index].Holes) do
  begin
    SetLength(Holes[I], Length(FEnts[Index].Holes[I]));
    for J := 0 to High(FEnts[Index].Holes[I]) do
    begin
      Holes[I][J] := Base;
      Inc(Base);
    end;
  end;

  if not Triangulate(Flat2, Ring, Holes, Result) then Result := nil;
  FCut[Index].Seq := FEditSeq;
  FCut[Index].Tris := Result;
end;

{ defined further down, beside OrientFace, and wanted up here }
function EdgeKeyOf(const A, B: TP3; out Way: PtrInt): string; forward;
function PointKeyOf(const P: TP3): string; forward;

function TWorkDoc.OpenEdges(G: Integer): TP3Array;
var
  Ix, Jx: TFPHashList;
  I, J, N, NV, NOut, C1, C2, NCut: Integer;
  Key: string;
  Way: PtrInt;
  PA, PB, CutA, CutB: TP3;
  Verts: array of TP3;
  Loops: array of TP3Array;
  LI: Integer;
  Cuts: array of Double;
  T, TSwap: Double;
  Ends: array of TP3;

  { the same test GroupClosed uses - a corner lying along an edge, strictly
    between its ends }
  function Between(const A, B, P: TP3; out U: Double): Boolean;
  var
    DX, DY, DZ, L2, CX, CY, CZ: Double;
  begin
    Result := False;
    DX := B.X - A.X; DY := B.Y - A.Y; DZ := B.Z - A.Z;
    L2 := DX * DX + DY * DY + DZ * DZ;
    if L2 < 1E-18 then Exit;
    U := ((P.X - A.X) * DX + (P.Y - A.Y) * DY + (P.Z - A.Z) * DZ) / L2;
    if (U <= 1E-9) or (U >= 1 - 1E-9) then Exit;
    CX := (P.Y - A.Y) * DZ - (P.Z - A.Z) * DY;
    CY := (P.Z - A.Z) * DX - (P.X - A.X) * DZ;
    CZ := (P.X - A.X) * DY - (P.Y - A.Y) * DX;
    Result := (CX * CX + CY * CY + CZ * CZ) <= 1E-10 * L2;
  end;

begin
  Result := nil;
  if G <= 0 then Exit;

  { the group's own corners, which is what an edge can be interrupted at }
  NV := 0;
  Jx := TFPHashList.Create;
  try
    for I := 0 to FLive - 1 do
    begin
      if (FEnts[I].Kind <> ekFace) or not FEnts[I].Solid then Continue;
      if FEnts[I].Grp <> G then Continue;
      SetLength(Loops, 1 + Length(FEnts[I].Holes));
      Loops[0] := FEnts[I].Poly;
      for J := 0 to High(FEnts[I].Holes) do Loops[J + 1] := FEnts[I].Holes[J];
      for LI := 0 to High(Loops) do
        for J := 0 to High(Loops[LI]) do
        begin
          Key := Format('%d,%d,%d', [Round(Loops[LI][J].X * 1E6),
            Round(Loops[LI][J].Y * 1E6), Round(Loops[LI][J].Z * 1E6)]);
          if Jx.FindIndexOf(Key) >= 0 then Continue;
          Jx.Add(Key, Pointer(1));
          if NV >= Length(Verts) then SetLength(Verts, Max(64, NV * 2));
          Verts[NV] := Loops[LI][J];
          Inc(NV);
        end;
    end;
  finally
    Jx.Free;
  end;
  if NV = 0 then Exit;

  { every edge, cut at any corner lying along it, tallied by direction }
  Ix := TFPHashList.Create;
  SetLength(Ends, 0);
  try
    for I := 0 to FLive - 1 do
    begin
      if (FEnts[I].Kind <> ekFace) or not FEnts[I].Solid then Continue;
      if FEnts[I].Grp <> G then Continue;
      SetLength(Loops, 1 + Length(FEnts[I].Holes));
      Loops[0] := FEnts[I].Poly;
      for J := 0 to High(FEnts[I].Holes) do Loops[J + 1] := FEnts[I].Holes[J];
      for LI := 0 to High(Loops) do
      begin
      N := Length(Loops[LI]);
      if N < 3 then Continue;
      for J := 0 to N - 1 do
      begin
        PA := Loops[LI][J];
        PB := Loops[LI][(J + 1) mod N];
        NCut := 0;
        for C2 := 0 to NV - 1 do
          if Between(PA, PB, Verts[C2], T) then
          begin
            if NCut >= Length(Cuts) then SetLength(Cuts, Max(8, NCut * 2));
            Cuts[NCut] := T;
            Inc(NCut);
          end;
        for C1 := 1 to NCut - 1 do
        begin
          TSwap := Cuts[C1];
          C2 := C1 - 1;
          while (C2 >= 0) and (Cuts[C2] > TSwap) do
          begin
            Cuts[C2 + 1] := Cuts[C2];
            Dec(C2);
          end;
          Cuts[C2 + 1] := TSwap;
        end;
        CutA := PA;
        for C1 := 0 to NCut do
        begin
          if C1 = NCut then CutB := PB
          else
          begin
            T := Cuts[C1];
            CutB := P3(PA.X + (PB.X - PA.X) * T, PA.Y + (PB.Y - PA.Y) * T,
                       PA.Z + (PB.Z - PA.Z) * T);
          end;
          Key := EdgeKeyOf(CutA, CutB, Way);
          C2 := Ix.FindIndexOf(Key);
          if C2 < 0 then
          begin
            Ix.Add(Key, Pointer(Way + 8));
            SetLength(Ends, Ix.Count * 2);
            Ends[(Ix.Count - 1) * 2] := CutA;
            Ends[(Ix.Count - 1) * 2 + 1] := CutB;
          end
          else
            Ix.Items[C2] := Pointer(PtrInt(Ix.Items[C2]) + Way);
          CutA := CutB;
        end;
      end;
      end;
    end;

    { an edge used once each way leaves its tally back at eight }
    NOut := 0;
    for I := 0 to Ix.Count - 1 do
      if PtrInt(Ix.Items[I]) <> 8 then
      begin
        SetLength(Result, NOut + 2);
        Result[NOut] := Ends[I * 2];
        Result[NOut + 1] := Ends[I * 2 + 1];
        Inc(NOut, 2);
      end;
  finally
    Ix.Free;
  end;
end;

function TWorkDoc.GroupClosed(G: Integer): Boolean;

  { the two ends to a millionth, smaller end first so either way round makes
    the same key, and a sign saying which way round this use ran }
  function EKey(const A, B: TP3; out Way: PtrInt): string;
  var
    P, Q: array[0..2] of Int64;
    I: Integer;
    Swap: Boolean;
  begin
    P[0] := Round(A.X * 1E6); P[1] := Round(A.Y * 1E6); P[2] := Round(A.Z * 1E6);
    Q[0] := Round(B.X * 1E6); Q[1] := Round(B.Y * 1E6); Q[2] := Round(B.Z * 1E6);
    Swap := False;
    for I := 0 to 2 do
      if P[I] <> Q[I] then
      begin
        Swap := P[I] > Q[I];
        Break;
      end;
    if Swap then Way := -1 else Way := 1;
    if Swap then
      Result := Format('%d,%d,%d|%d,%d,%d', [Q[0], Q[1], Q[2], P[0], P[1], P[2]])
    else
      Result := Format('%d,%d,%d|%d,%d,%d', [P[0], P[1], P[2], Q[0], Q[1], Q[2]]);
  end;

  { Is P on the segment A-B, strictly between the ends?

    A tenth of a thousandth of a foot off the line - a good deal finer than
    anything anybody draws, and coarser than the millionths the edge keys are
    rounded to, so a point that keys as being on the line is never rejected
    here for being a rounding off it. }
  function Between(const A, B, P: TP3; out T: Double): Boolean;
  var
    DX, DY, DZ, L2, CX, CY, CZ: Double;
  begin
    Result := False;
    DX := B.X - A.X; DY := B.Y - A.Y; DZ := B.Z - A.Z;
    L2 := DX * DX + DY * DY + DZ * DZ;
    if L2 < 1E-18 then Exit;
    T := ((P.X - A.X) * DX + (P.Y - A.Y) * DY + (P.Z - A.Z) * DZ) / L2;
    if (T <= 1E-9) or (T >= 1 - 1E-9) then Exit;
    CX := (P.Y - A.Y) * DZ - (P.Z - A.Z) * DY;
    CY := (P.Z - A.Z) * DX - (P.X - A.X) * DZ;
    CZ := (P.X - A.X) * DY - (P.Y - A.Y) * DX;
    Result := (CX * CX + CY * CY + CZ * CZ) <= 1E-10 * L2;
  end;

var
  I, J, N, K, Top: Integer;
  Ix: TFPHashList;
  Key: string;
  Way: PtrInt;
  Seen: array of Integer;
  { the endpoints behind each entry in the hash, so an edge that did not
    match can be looked at again rather than only counted }
  EdgeA, EdgeB: array of TP3;
  EdgeG: array of Integer;
  { the second chance, for groups the plain count says are open }
  Suspect: array of Boolean;
  Loops: array of TP3Array;
  LI: Integer;
  Verts: array of TP3;
  NV, NU, Budget: Integer;
  Cuts: array of Double;
  NCut, C1, C2: Integer;
  T, TSwap: Double;
  PA, PB, CutA, CutB: TP3;
  Jx: TFPHashList;
  Shut: Boolean;
begin
  Result := False;
  if G <= 0 then Exit;
  if FClosedSeq <> FEditSeq then
  begin
    FClosedSeq := FEditSeq;
    Top := 0;
    for I := 0 to FLive - 1 do
      if (FEnts[I].Kind = ekFace) and FEnts[I].Solid and (FEnts[I].Grp > Top) then
        Top := FEnts[I].Grp;
    SetLength(FClosedGrp, Top + 1);
    for I := 0 to High(FClosedGrp) do FClosedGrp[I] := (I > 0);

    { One pass over every face of every solid, not one pass per solid: the
      group goes into the key.  A drawing of two and a half thousand boxes
      would otherwise walk fifteen thousand faces two and a half thousand
      times over, which is the sort of thing that turns a frame into a
      second. }
    Ix := TFPHashList.Create;
    try
      for I := 0 to FLive - 1 do
      begin
        if (FEnts[I].Kind <> ekFace) or not FEnts[I].Solid then Continue;
        if FEnts[I].Grp <= 0 then Continue;
        N := Length(FEnts[I].Poly);
        if N < 3 then Continue;
        { The outline AND everything cut out of it.

          A hole's edge is every bit as much a boundary of the solid as the
          outline is - on a picture frame it is the inside of the frame, and
          the wall of the rebate meets it there.  Walking only the outline
          left every hole edge used once by that wall and never by the face,
          so a frame with a hole in it read as open however well it was
          built, and the STL said a slicer would have to guess.  Found
          modeling the example etch-a-sketch, whose screen surround is
          exactly that shape. }
        SetLength(Loops, 1 + Length(FEnts[I].Holes));
        Loops[0] := FEnts[I].Poly;
        for J := 0 to High(FEnts[I].Holes) do Loops[J + 1] := FEnts[I].Holes[J];
        for LI := 0 to High(Loops) do
        begin
        N := Length(Loops[LI]);
        if N < 3 then Continue;
        for J := 0 to N - 1 do
        begin
          Key := IntToStr(FEnts[I].Grp) + '@' +
                 EKey(Loops[LI][J], Loops[LI][(J + 1) mod N], Way);
          K := Ix.FindIndexOf(Key);
          if K < 0 then
          begin
            Ix.Add(Key, Pointer(Way + 8));
            { in step with the hash, which appends, so entry n of one is
              entry n of the other }
            if Length(EdgeA) < Ix.Count then
            begin
              SetLength(EdgeA, Ix.Count * 2);
              SetLength(EdgeB, Ix.Count * 2);
              SetLength(EdgeG, Ix.Count * 2);
            end;
            EdgeA[Ix.Count - 1] := Loops[LI][J];
            EdgeB[Ix.Count - 1] := Loops[LI][(J + 1) mod N];
            EdgeG[Ix.Count - 1] := FEnts[I].Grp;
          end
          else Ix.Items[K] := Pointer(PtrInt(Ix.Items[K]) + Way);
        end;
        end;
      end;
      { an edge used once each way leaves its tally back at eight; anything
        else - used once, used twice the same way round, used three times -
        belongs to a shape that is not closed }
      SetLength(Suspect, Top + 1);
      for I := 0 to Top do Suspect[I] := False;
      for I := 0 to Ix.Count - 1 do
        if PtrInt(Ix.Items[I]) <> 8 then
        begin
          K := EdgeG[I];
          if (K > 0) and (K <= Top) then
          begin
            FClosedGrp[K] := False;
            Suspect[K] := True;
          end;
        end;

      { --- second chance: the same edge, cut into different lengths ------

        A wall meets a roof along one line.  If the roof is one face, both
        sides of that line are one edge and they match.  If the roof has
        since been divided - a line drawn across it, a piece pushed up out of
        it - the roof side of the line is now two or three shorter edges
        while the wall side is still one long one, and matching whole edges
        against whole edges sees four strangers rather than a seam.  A
        T-junction, and the shape is every bit as watertight as it looks.

        the robot, 13 September: thirteen faces, and fourteen edges the
        plain count could not pair off - every one of them a long edge on a
        side wall against the two or three pieces of it on the top.  The
        solid was closed and had always been closed; being told it was not is
        what left its backs undrawn-over and showing blue, and no amount of
        rebuilding helped because there was nothing wrong to rebuild.

        So: for a group that failed, cut its unmatched edges at any corner of
        that same group lying along them, and count again.  If the pieces pair
        off now, the seam was only ever divided unevenly.  Groups that passed
        do not come in here at all, which is what keeps this off the cost of
        an ordinary drawing. }
      for K := 1 to Top do
      begin
        if not Suspect[K] then Continue;

        { the group's own corners }
        NV := 0;
        Jx := TFPHashList.Create;
        try
          for I := 0 to FLive - 1 do
          begin
            if (FEnts[I].Kind <> ekFace) or not FEnts[I].Solid then Continue;
            if FEnts[I].Grp <> K then Continue;
            SetLength(Loops, 1 + Length(FEnts[I].Holes));
            Loops[0] := FEnts[I].Poly;
            for J := 0 to High(FEnts[I].Holes) do Loops[J + 1] := FEnts[I].Holes[J];
            for LI := 0 to High(Loops) do
              for J := 0 to High(Loops[LI]) do
              begin
                Key := Format('%d,%d,%d', [Round(Loops[LI][J].X * 1E6),
                  Round(Loops[LI][J].Y * 1E6), Round(Loops[LI][J].Z * 1E6)]);
                if Jx.FindIndexOf(Key) >= 0 then Continue;
                Jx.Add(Key, Pointer(1));
                if NV >= Length(Verts) then SetLength(Verts, Max(64, NV * 2));
                Verts[NV] := Loops[LI][J];
                Inc(NV);
              end;
          end;
        finally
          Jx.Free;
        end;

        { how much work a second look would be: every edge of the group
          against every corner of it }
        NU := 0;
        for I := 0 to FLive - 1 do
          if (FEnts[I].Kind = ekFace) and FEnts[I].Solid and (FEnts[I].Grp = K) then
            Inc(NU, Length(FEnts[I].Poly));

        { a ceiling on it, so a big genuinely-broken shape cannot turn a
          frame into a minute proving what the first count already said }
        Budget := 4000000;
        if (NU = 0) or (NV = 0) or (Int64(NU) * NV > Budget) then Continue;

        { Count the group again from the beginning, with every edge cut at
          any corner of the group that lies along it.  Doing it from scratch
          rather than patching up the first count is the whole reason this is
          simple: each piece is a real run from one point to the next, told
          apart and counted exactly as a whole edge would be, and there is no
          question of what sense to give it. }
        Jx := TFPHashList.Create;
        try
          for I := 0 to FLive - 1 do
          begin
            if (FEnts[I].Kind <> ekFace) or not FEnts[I].Solid then Continue;
            if FEnts[I].Grp <> K then Continue;
            SetLength(Loops, 1 + Length(FEnts[I].Holes));
            Loops[0] := FEnts[I].Poly;
            for J := 0 to High(FEnts[I].Holes) do Loops[J + 1] := FEnts[I].Holes[J];
            for LI := 0 to High(Loops) do
            begin
            N := Length(Loops[LI]);
            if N < 3 then Continue;
            for J := 0 to N - 1 do
            begin
              PA := Loops[LI][J];
              PB := Loops[LI][(J + 1) mod N];
              NCut := 0;
              for C2 := 0 to NV - 1 do
                if Between(PA, PB, Verts[C2], T) then
                begin
                  if NCut >= Length(Cuts) then SetLength(Cuts, Max(8, NCut * 2));
                  Cuts[NCut] := T;
                  Inc(NCut);
                end;
              for C1 := 1 to NCut - 1 do
              begin
                TSwap := Cuts[C1];
                C2 := C1 - 1;
                while (C2 >= 0) and (Cuts[C2] > TSwap) do
                begin
                  Cuts[C2 + 1] := Cuts[C2];
                  Dec(C2);
                end;
                Cuts[C2 + 1] := TSwap;
              end;

              CutA := PA;
              for C1 := 0 to NCut do
              begin
                if C1 = NCut then CutB := PB
                else
                begin
                  T := Cuts[C1];
                  CutB := P3(PA.X + (PB.X - PA.X) * T,
                             PA.Y + (PB.Y - PA.Y) * T,
                             PA.Z + (PB.Z - PA.Z) * T);
                end;
                Key := EKey(CutA, CutB, Way);
                C2 := Jx.FindIndexOf(Key);
                if C2 < 0 then Jx.Add(Key, Pointer(Way + 8))
                else Jx.Items[C2] := Pointer(PtrInt(Jx.Items[C2]) + Way);
                CutA := CutB;
              end;
            end;
            end;
          end;

          Shut := Jx.Count > 0;
          for I := 0 to Jx.Count - 1 do
            if PtrInt(Jx.Items[I]) <> 8 then
            begin
              Shut := False;
              Break;
            end;
          if Shut then FClosedGrp[K] := True;
        finally
          Jx.Free;
        end;
      end;
    finally
      Ix.Free;
    end;
    { a group with no faces at all is not a closed solid either }
    SetLength(Seen, Top + 1);
    for I := 0 to High(Seen) do Seen[I] := 0;
    for I := 0 to FLive - 1 do
      if (FEnts[I].Kind = ekFace) and FEnts[I].Solid and (FEnts[I].Grp > 0) then
        Seen[FEnts[I].Grp] := 1;
    for I := 1 to Top do
      if Seen[I] = 0 then FClosedGrp[I] := False;
  end;
    Result := (G > 0) and (G < Length(FClosedGrp)) and FClosedGrp[G];
end;

function TWorkDoc.ZRange(out Lo, Hi: Double): Boolean;
var
  A, B: TP3;
begin
  Result := Bounds(A, B);
  if Result then
  begin
    Lo := A.Z;
    Hi := B.Z;
  end
  else
  begin
    Lo := 0;
    Hi := 0;
  end;
end;

{ The winding of a face decides which way its normal points, and for a flat
  one drawn on the screen that came out of which way the cursor was dragged -
  a rectangle pulled down-right in plan faced down, one pulled up-left faced
  up.  Nothing cared until push/pull built a solid from it: the face that
  should have ended up on the outside faced inwards, was culled as a back
  face, and could then neither be seen nor clicked.

  So a drawing face is wound to face along whichever axis it is squarest to,
  positively.  Solids are left alone - their windings are built deliberately
  and mean something.

  The faces the region finder works out did not come through here, and it
  took a report to notice.  They were added exactly as walked, and for
  two areas either side of one line the walker runs the shared line the same
  way round for both - so a barn roof built as two slopes off a ridge came
  out with one slope facing the sky and the other facing the ground.  Gray on
  one side, pale blue on the other, which is the drawing saying it is inside
  out, and it was right.

  The tidy answer would be to make every face agree with its neighbors
  across shared edges, and that answer is wrong here: a house has edges where
  three faces meet - the top of a wall, the end wall under it and the gable
  standing on it - and no winding of the lot can make all three agree.  This
  rule needs no neighbors and gives the same answer every time.  Its limit
  is worth knowing: two slopes of a roof steeper than 45 degrees are squarest
  to the ground axes rather than to blue, and then it is back to picking one
  of each. }
{ A name for the edge between two points that comes out the same whichever
  end you start from, and a sign saying which way round this use ran.

  Rounded to a millionth of a unit, which is far finer than anything anybody
  draws and coarse enough that two points meant to be the same one always
  key alike. }
{ One point, quantized, as a key.  A millionth of a unit, the same grid
  EdgeKeyOf uses, so two corners that arrived at the same place by different
  arithmetic name the same key. }
function PointKeyOf(const P: TP3): string;
begin
  Result := Format('%d|%d|%d', [Round(P.X * 1E6), Round(P.Y * 1E6),
                                Round(P.Z * 1E6)]);
end;

function EdgeKeyOf(const A, B: TP3; out Way: PtrInt): string;
var
  P, Q: array[0..2] of Int64;
  I: Integer;
  Swap: Boolean;
begin
  P[0] := Round(A.X * 1E6); P[1] := Round(A.Y * 1E6); P[2] := Round(A.Z * 1E6);
  Q[0] := Round(B.X * 1E6); Q[1] := Round(B.Y * 1E6); Q[2] := Round(B.Z * 1E6);
  Swap := False;
  for I := 0 to 2 do
    if P[I] <> Q[I] then
    begin
      Swap := P[I] > Q[I];
      Break;
    end;
  if Swap then Way := -1 else Way := 1;
  if Swap then
    Result := Format('%d,%d,%d|%d,%d,%d', [Q[0], Q[1], Q[2], P[0], P[1], P[2]])
  else
    Result := Format('%d,%d,%d|%d,%d,%d', [P[0], P[1], P[2], Q[0], Q[1], Q[2]]);
end;

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

{ Turns a face over.

  Every rule for which way a loose face should point is a guess - the best
  one available, and still a guess.  A face squarest to red is wound to face
  the positive way along red, which gets a roof right and cannot get the two
  ends of a barn right, because they are back to back and the rule has no
  way to know which side of either one is outside.  SketchUp has the same
  problem and the same answer: let the person looking at it say.

  The holes go round with the outline.  Nothing reads their winding - every
  fill in the program is even-odd, and so is the one in the SVG - but a face
  turned over should be turned over, not turned over in part. }
function TWorkDoc.OrientLooseShells(Part: Integer): Integer;
type
  TUse = record
    Face: Integer;   { slot in Cand, not an entity index }
    Dir: PtrInt;     { +1 if it ran the way the key is written, -1 if not }
  end;
var
  Cand: array of Integer;         { entity index of each slot }
  Slot: array of Integer;         { slot of each entity, -1 if not a candidate }
  Flip: array of Boolean;
  Comp: array of Integer;
  UseA, UseB: array of TUse;      { the one or two faces on each edge }
  NUse: array of Integer;
  Ix: TFPHashList;
  Queue: array of Integer;
  Members: array of Integer;
  I, J, K, N, NC, E, Head, Tail, NComp, NMem, Other: Integer;
  Key: string;
  Way: PtrInt;
  Nm, Cen, Acc, Mid: TP3;
  Vol, Sgn, Ar, W: Double;

  { twice the vector area, by Newell - the same sum OrientFace uses, which
    points along the face's normal and is as long as twice its area }
  function Newell(const Pts: TP3Array): TP3;
  var
    M, Cnt: Integer;
    Q: TP3;
  begin
    Result := P3(0, 0, 0);
    Cnt := Length(Pts);
    for M := 0 to Cnt - 1 do
    begin
      Q := Pts[(M + 1) mod Cnt];
      Result.X := Result.X + (Pts[M].Y - Q.Y) * (Pts[M].Z + Q.Z);
      Result.Y := Result.Y + (Pts[M].Z - Q.Z) * (Pts[M].X + Q.X);
      Result.Z := Result.Z + (Pts[M].X - Q.X) * (Pts[M].Y + Q.Y);
    end;
  end;

  function Middle(const Pts: TP3Array): TP3;
  var
    M, Cnt: Integer;
  begin
    Result := P3(0, 0, 0);
    Cnt := Length(Pts);
    if Cnt = 0 then Exit;
    for M := 0 to Cnt - 1 do
    begin
      Result.X := Result.X + Pts[M].X;
      Result.Y := Result.Y + Pts[M].Y;
      Result.Z := Result.Z + Pts[M].Z;
    end;
    Result.X := Result.X / Cnt;
    Result.Y := Result.Y / Cnt;
    Result.Z := Result.Z / Cnt;
  end;

  { which way this face runs along that edge, allowing for a pending turn }
  function DirOf(const U: TUse): Integer;
  begin
    if Flip[U.Face] then Result := -U.Dir else Result := U.Dir;
  end;

begin
  Result := 0;
  SetLength(Slot, FLive);
  for I := 0 to FLive - 1 do Slot[I] := -1;
  NC := 0;
  for I := 0 to FLive - 1 do
  begin
    if FEnts[I].Kind <> ekFace then Continue;
    if FEnts[I].Solid then Continue;          { a made solid winds itself }
    if FEnts[I].Part <> Part then Continue;   { another group's faces are not neighbors }
    if Length(FEnts[I].Poly) < 3 then Continue;
    if NC >= Length(Cand) then SetLength(Cand, Max(32, NC * 2));
    Cand[NC] := I;
    Slot[I] := NC;
    Inc(NC);
  end;
  if NC < 2 then Exit;
  SetLength(Cand, NC);
  SetLength(Flip, NC);
  SetLength(Comp, NC);
  for I := 0 to NC - 1 do
  begin
    Flip[I] := False;
    Comp[I] := -1;
  end;

  { every edge, and the one or two candidate faces along it }
  Ix := TFPHashList.Create;
  try
    SetLength(UseA, 0);
    for I := 0 to NC - 1 do
    begin
      N := Length(FEnts[Cand[I]].Poly);
      for J := 0 to N - 1 do
      begin
        Key := EdgeKeyOf(FEnts[Cand[I]].Poly[J],
                         FEnts[Cand[I]].Poly[(J + 1) mod N], Way);
        K := Ix.FindIndexOf(Key);
        if K < 0 then
        begin
          Ix.Add(Key, Pointer(PtrInt(Ix.Count) + 1));
          E := Ix.Count - 1;
          if E >= Length(UseA) then
          begin
            SetLength(UseA, Max(64, (E + 1) * 2));
            SetLength(UseB, Length(UseA));
            SetLength(NUse, Length(UseA));
          end;
          NUse[E] := 1;
          UseA[E].Face := I;
          UseA[E].Dir := Way;
        end
        else
        begin
          E := PtrInt(Ix.Items[K]) - 1;
          if NUse[E] = 1 then
          begin
            UseB[E].Face := I;
            UseB[E].Dir := Way;
          end;
          Inc(NUse[E]);
        end;
      end;
    end;

    { settle each connected sheet from one face outwards }
    SetLength(Queue, NC);
    SetLength(Members, NC);
    NComp := 0;
    for I := 0 to NC - 1 do
    begin
      if Comp[I] >= 0 then Continue;
      Inc(NComp);
      Head := 0; Tail := 0;
      Queue[Tail] := I; Inc(Tail);
      Comp[I] := NComp;
      NMem := 0;
      while Head < Tail do
      begin
        K := Queue[Head]; Inc(Head);
        Members[NMem] := K; Inc(NMem);
        N := Length(FEnts[Cand[K]].Poly);
        for J := 0 to N - 1 do
        begin
          Key := EdgeKeyOf(FEnts[Cand[K]].Poly[J],
                           FEnts[Cand[K]].Poly[(J + 1) mod N], Way);
          E := Ix.FindIndexOf(Key);
          if E < 0 then Continue;
          E := PtrInt(Ix.Items[E]) - 1;
          { only where exactly two faces meet - three has no answer }
          if NUse[E] <> 2 then Continue;
          if UseA[E].Face = K then Other := UseB[E].Face
          else Other := UseA[E].Face;
          if Other = K then Continue;
          if Comp[Other] >= 0 then Continue;
          { neighbors agree about out when they run the shared edge
            opposite ways }
          if UseA[E].Face = K then
            Flip[Other] := (DirOf(UseA[E]) = UseB[E].Dir)
          else
            Flip[Other] := (DirOf(UseB[E]) = UseA[E].Dir);
          Comp[Other] := NComp;
          Queue[Tail] := Other; Inc(Tail);
        end;
      end;

      if NMem < 2 then Continue;

      { and which way round the settled sheet goes.  If it holds a volume,
        that decides it; if it does not - a roof with no underside - point
        its faces away from the middle of it, weighted by how big they are so
        a scrap of a face cannot outvote a wall. }
      Cen := P3(0, 0, 0);
      for J := 0 to NMem - 1 do
      begin
        Mid := Middle(FEnts[Cand[Members[J]]].Poly);
        Cen.X := Cen.X + Mid.X / NMem;
        Cen.Y := Cen.Y + Mid.Y / NMem;
        Cen.Z := Cen.Z + Mid.Z / NMem;
      end;
      Vol := 0;
      W := 0;
      for J := 0 to NMem - 1 do
      begin
        K := Members[J];
        Acc := Newell(FEnts[Cand[K]].Poly);
        if Flip[K] then Acc := P3(-Acc.X, -Acc.Y, -Acc.Z);
        Mid := Middle(FEnts[Cand[K]].Poly);
        Vol := Vol + (Mid.X * Acc.X + Mid.Y * Acc.Y + Mid.Z * Acc.Z) / 6;
        Ar := Sqrt(Acc.X * Acc.X + Acc.Y * Acc.Y + Acc.Z * Acc.Z) / 2;
        Nm := P3(Mid.X - Cen.X, Mid.Y - Cen.Y, Mid.Z - Cen.Z);
        W := W + Ar * (Nm.X * Acc.X + Nm.Y * Acc.Y + Nm.Z * Acc.Z);
      end;
      if Abs(Vol) > 1E-6 then Sgn := Vol else Sgn := W;
      if Sgn < 0 then
        for J := 0 to NMem - 1 do
          Flip[Members[J]] := not Flip[Members[J]];
    end;
  finally
    Ix.Free;
  end;

  for I := 0 to NC - 1 do
    if Flip[I] then
    begin
      ReverseFace(Cand[I]);
      Inc(Result);
    end;
end;

function TWorkDoc.ReverseFace(Index: Integer): Boolean;

  procedure Flip(var Loop: array of TP3);
  var
    I, N: Integer;
    T: TP3;
  begin
    N := Length(Loop);
    for I := 0 to N div 2 - 1 do
    begin
      T := Loop[I];
      Loop[I] := Loop[N - 1 - I];
      Loop[N - 1 - I] := T;
    end;
  end;

var
  K: Integer;
begin
  Result := False;
  if (Index < 0) or (Index >= FLive) then Exit;
  if FEnts[Index].Kind <> ekFace then Exit;
  if Length(FEnts[Index].Poly) < 3 then Exit;
  Flip(FEnts[Index].Poly);
  for K := 0 to High(FEnts[Index].Holes) do
    Flip(FEnts[Index].Holes[K]);
  FEnts[Index].A := FEnts[Index].Poly[0];
  FEnts[Index].B := FEnts[Index].Poly[High(FEnts[Index].Poly)];
  FOnFaceOK := False;
  Inc(FEditSeq);
  Result := True;
end;

{ Adds the polygon exactly as given.  Solids build their windings on purpose,
  so they come this way round. }
procedure TWorkDoc.AddFaceRaw(const Pts: array of TP3; Ink: TColor; Solid: Boolean);
var
  I: Integer;
begin
  if Length(Pts) < 3 then Exit;
  Room;
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FEnts[FLive].Kind := ekFace;
  FEnts[FLive].Part := FStamp;
  SetLength(FEnts[FLive].Poly, Length(Pts));
  for I := 0 to High(Pts) do
    FEnts[FLive].Poly[I] := Pts[I];
  FEnts[FLive].A := Pts[0];
  FEnts[FLive].B := Pts[High(Pts)];
  FEnts[FLive].Ink := Ink;
  FEnts[FLive].Weight := 1;
  FEnts[FLive].Solid := Solid;
  Inc(FLive);
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
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
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
end;

procedure TWorkDoc.SetSoft(Index: Integer; Soft: Boolean);
begin
  if (Index < 0) or (Index >= FLive) then Exit;
  FEnts[Index].Soft := Soft;
end;

procedure TWorkDoc.SetInk(Index: Integer; Ink: TColor);
begin
  if (Index < 0) or (Index >= FLive) then Exit;
  FEnts[Index].Ink := Ink;
end;

procedure TWorkDoc.SetWeight(Index: Integer; Weight: Single);
begin
  if (Index < 0) or (Index >= FLive) then Exit;
  FEnts[Index].Weight := Weight;
end;

procedure TWorkDoc.SetMaterial(Index: Integer; C: TColor);
begin
  if (Index < 0) or (Index >= FLive) then Exit;
  if FEnts[Index].Kind <> ekFace then Exit;
  FEnts[Index].MatSet := True;
  FEnts[Index].Mat := C;
end;

procedure TWorkDoc.ClearMaterial(Index: Integer);
begin
  if (Index < 0) or (Index >= FLive) then Exit;
  FEnts[Index].MatSet := False;
  FEnts[Index].Mat := 0;
end;

function TWorkDoc.Material(Index: Integer; out C: TColor): Boolean;
begin
  C := 0;
  Result := (Index >= 0) and (Index < FLive) and (FEnts[Index].Kind = ekFace)
    and FEnts[Index].MatSet;
  if Result then C := FEnts[Index].Mat;
end;

procedure TWorkDoc.SetDimOffset(Index: Integer; const Off: TP3);
begin
  if (Index < 0) or (Index >= FLive) or (FEnts[Index].Kind <> ekDim) then Exit;
  FEnts[Index].C := Off;
end;

{ A set of points that answers "is P one of these, to within a hair" in
  one hash lookup instead of a walk down the list.  The hash is on a coarse
  grid, and the cells round P's are looked in as well, so a point a hair
  over a cell edge is still found.  Moving and turning ask this for every
  corner of every thing in the drawing, times every moving corner; with a
  thousand of each that walk was most of a second. }
type
  TPointSet = class
  private
    FMap: TFPHashList;
    FLists: array of TP3Array;
    function KeyAt(X, Y, Z: Int64): shortstring;
  public
    constructor Create(const Pts: TP3Array);
    destructor Destroy; override;
    function Has(const P: TP3; Tol: Double): Boolean;
  end;

const
  PSET_CELL = 1E-5;

function TPointSet.KeyAt(X, Y, Z: Int64): shortstring;
var
  Q: array[0..2] of Int64;
begin
  Q[0] := X; Q[1] := Y; Q[2] := Z;
  SetLength(Result, 24);
  Move(Q[0], Result[1], 24);
end;

constructor TPointSet.Create(const Pts: TP3Array);
var
  I, Ix: Integer;
  K: shortstring;
begin
  FMap := TFPHashList.Create;
  for I := 0 to High(Pts) do
  begin
    K := KeyAt(Floor(Pts[I].X / PSET_CELL), Floor(Pts[I].Y / PSET_CELL), Floor(Pts[I].Z / PSET_CELL));
    { the item is the list's index plus one: TFPHashList takes a nil item
      for an empty slot and will not find it again }
    Ix := FMap.FindIndexOf(K);
    if Ix < 0 then
    begin
      SetLength(FLists, Length(FLists) + 1);
      Ix := High(FLists);
      FMap.Add(K, Pointer(PtrInt(Ix + 1)));
    end
    else
      Ix := PtrInt(FMap.Items[Ix]) - 1;
    SetLength(FLists[Ix], Length(FLists[Ix]) + 1);
    FLists[Ix][High(FLists[Ix])] := Pts[I];
  end;
end;

destructor TPointSet.Destroy;
begin
  FMap.Free;
  inherited;
end;

function TPointSet.Has(const P: TP3; Tol: Double): Boolean;
var
  X, Y, Z, DX, DY, DZ: Int64;
  Ix, J: Integer;
begin
  Result := False;
  X := Floor(P.X / PSET_CELL); Y := Floor(P.Y / PSET_CELL); Z := Floor(P.Z / PSET_CELL);
  for DX := -1 to 1 do
    for DY := -1 to 1 do
      for DZ := -1 to 1 do
      begin
        Ix := FMap.FindIndexOf(KeyAt(X + DX, Y + DY, Z + DZ));
        if Ix < 0 then Continue;
        Ix := PtrInt(FMap.Items[Ix]) - 1;
        for J := 0 to High(FLists[Ix]) do
          if Dist(P, FLists[Ix][J]) < Tol then Exit(True);
      end;
end;

{ The arcs whose points are all corners of the profile - a circle drawn
  with the circle tool that became the face - are the profile's own edges:
  when the face is consumed by a full turn or a closed path they become
  soft seams of the surface and members of the solid, or they would stay
  drawn as a hard black ring across it. }
procedure TWorkDoc.MarkProfileArcs(const Poly: TP3Array; G: Integer);
var
  I, K: Integer;
  Pts: TP3Array;
  Corners: TPointSet;
  All: Boolean;
begin
  Corners := TPointSet.Create(Poly);
  try
    for I := 0 to FLive - 1 do
      if FEnts[I].Kind = ekArc then
      begin
        EdgePoints(I, Pts);
        if Length(Pts) < 2 then Continue;
        All := True;
        for K := 0 to High(Pts) do
          if not Corners.Has(Pts[K], 1E-6) then
          begin
            All := False;
            Break;
          end;
        if All then
        begin
          SetSoft(I, True);
          SetGroup(I, G);
        end;
      end;
  finally
    Corners.Free;
  end;
end;

function TWorkDoc.Revolve(Face: Integer; const AxisP, AxisDir: TP3; Angle: Double;
  Steps: Integer): Integer;
const
  { the turn in the profile at a vertex below which the ring it sweeps is a
    soft edge - the creases of a curve rather than a corner }
  SOFT_TURN = 30 * Pi / 180;
var
  Poly: TP3Array;
  N, S, K, K2, G, I, First: Integer;
  Full: Boolean;
  Ax, Nf, Cen, Side, E, Mid, Out, Tang, PrevE: TP3;
  Rings: array of array of TP3;
  Quad: array of TP3;
  OnAxis: array of Boolean;
  Turn: Double;
  Q: array[0..3] of TP3;

  function Rot(const P: TP3; S: Integer): TP3;
  begin
    Result := RotP(P, AxisP, Ax, Angle * S / Steps);
  end;

  function Near(const A, B: TP3): Boolean;
  begin
    Result := Dist(A, B) < 1E-9;
  end;

  procedure FaceOut(const Pts: array of TP3; const Want: TP3);
  begin
    AddFaceRaw(Pts, FEnts[Face].Ink, True);
    { the sweep is made of the profile, so it is made of what the profile is
      painted with - the pen came across already }
    if FEnts[Face].MatSet then SetMaterial(FLive - 1, FEnts[Face].Mat);
    SetFaceGroup(FLive - 1, G);
    if Dot3(FaceNormal(FLive - 1), Want) < 0 then FlipFace(FLive - 1);
  end;

  procedure Edge(const A, B: TP3; Soft: Boolean);
  begin
    if Near(A, B) then Exit;
    AddLine(A, B, FEnts[Face].Ink, FEnts[Face].Weight, False);
    SetGroup(FLive - 1, G);
    SetSoft(FLive - 1, Soft);
  end;

  { the line already in the drawing between two points, if there is one }
  function LineAt(const A, B: TP3): Integer;
  var
    J: Integer;
  begin
    Result := -1;
    for J := 0 to FLive - 1 do
      if (FEnts[J].Kind = ekLine) and
         ((Near(FEnts[J].A, A) and Near(FEnts[J].B, B)) or
          (Near(FEnts[J].A, B) and Near(FEnts[J].B, A))) then Exit(J);
  end;

begin
  Result := -1;
  if (Face < 0) or (Face >= FLive) or (FEnts[Face].Kind <> ekFace) then Exit;
  if (Steps < 1) or (Abs(Angle) < 1E-9) then Exit;
  Ax := Norm3(AxisDir);
  if Dist(Ax, P3(0, 0, 0)) < 1E-9 then Exit;
  Poly := Copy(FEnts[Face].Poly);
  N := Length(Poly);
  if N < 3 then Exit;
  Full := Abs(Angle) >= 2 * Pi - 1E-9;
  Nf := FaceNormal(Face);
  Cen := P3(0, 0, 0);
  for K := 0 to N - 1 do Cen := P3(Cen.X + Poly[K].X / N, Cen.Y + Poly[K].Y / N, Cen.Z + Poly[K].Z / N);
  { which way the sweep moves off the profile: along the tangent of the
    turn at the profile's middle }
  Tang := Cross3(Ax, P3(Cen.X - AxisP.X, Cen.Y - AxisP.Y, Cen.Z - AxisP.Z));
  if Angle < 0 then Tang := P3(-Tang.X, -Tang.Y, -Tang.Z);
  First := FLive;
  G := NewGroup;
  { every profile point at every step }
  SetLength(Rings, Steps + 1);
  SetLength(OnAxis, N);
  for K := 0 to N - 1 do
  begin
    E := P3(Poly[K].X - AxisP.X, Poly[K].Y - AxisP.Y, Poly[K].Z - AxisP.Z);
    E := P3(E.X - Ax.X * Dot3(E, Ax), E.Y - Ax.Y * Dot3(E, Ax), E.Z - Ax.Z * Dot3(E, Ax));
    OnAxis[K] := Dist(E, P3(0, 0, 0)) < 1E-9;
  end;
  for S := 0 to Steps do
  begin
    SetLength(Rings[S], N);
    for K := 0 to N - 1 do Rings[S][K] := Rot(Poly[K], S);
  end;
  { the surface: one strip of gores per profile edge, wound to face the way
    the profile's edge faces - away from the inside of the profile }
  for K := 0 to N - 1 do
  begin
    K2 := (K + 1) mod N;
    if OnAxis[K] and OnAxis[K2] then Continue;
    E := P3(Poly[K2].X - Poly[K].X, Poly[K2].Y - Poly[K].Y, Poly[K2].Z - Poly[K].Z);
    { Which way is out of the profile at this edge.

      It used to be worked out by pointing away from the middle of the
      profile, and that is only right for a fat one.  A wine glass is a thin
      C - up the outside, over the rim, back down the inside, out along the
      foot - and the middle of a C is in the hollow, not in the material, so
      every edge on the far side of it was turned inside out.  The result
      came off the lathe with its bowl in pale blue.

      The polygon already knows.  FaceNormal is its Newell normal, which is
      tied to the winding, and for any simple polygon - concave as readily as
      convex - the outward side of an edge is the edge crossed into that
      normal.  No middle, no guess, and it does not care what shape the
      profile is. }
    Side := Norm3(Cross3(E, Nf));
    for S := 0 to Steps - 1 do
    begin
      Q[0] := Rings[S][K]; Q[1] := Rings[S][K2]; Q[2] := Rings[S + 1][K2]; Q[3] := Rings[S + 1][K];
      { a point on the axis stays put, so the gore there is a triangle }
      SetLength(Quad, 0);
      for I := 0 to 3 do
        if (Length(Quad) = 0) or not Near(Quad[High(Quad)], Q[I]) then
        begin
          SetLength(Quad, Length(Quad) + 1);
          Quad[High(Quad)] := Q[I];
        end;
      if (Length(Quad) > 1) and Near(Quad[0], Quad[High(Quad)]) then SetLength(Quad, Length(Quad) - 1);
      if Length(Quad) < 3 then Continue;
      Out := RotV(Side, Ax, Angle * (S + 0.5) / Steps);
      FaceOut(Quad, Out);
      { the seam between this gore and the next, soft: a crease of the curve }
      if (S > 0) or Full then
        Edge(Rings[S][K], Rings[S][K2], True);
    end;
  end;
  { the rings each profile point sweeps: hard where the profile has a corner
    there, soft where it only bends a little }
  for K := 0 to N - 1 do
  begin
    if OnAxis[K] then Continue;
    K2 := (K + 1) mod N;
    PrevE := Norm3(P3(Poly[K].X - Poly[(K + N - 1) mod N].X, Poly[K].Y - Poly[(K + N - 1) mod N].Y,
                      Poly[K].Z - Poly[(K + N - 1) mod N].Z));
    E := Norm3(P3(Poly[K2].X - Poly[K].X, Poly[K2].Y - Poly[K].Y, Poly[K2].Z - Poly[K].Z));
    Turn := ArcCos(EnsureRange(Dot3(PrevE, E), -1.0, 1.0));
    for S := 0 to Steps - 1 do
      Edge(Rings[S][K], Rings[S + 1][K], Turn < SOFT_TURN);
  end;
  if Full then
  begin
    { the profile's own edges are now a seam of the surface }
    for K := 0 to N - 1 do
    begin
      I := LineAt(Poly[K], Poly[(K + 1) mod N]);
      if I >= 0 then
      begin
        SetGroup(I, G);
        SetSoft(I, True);
      end;
    end;
    MarkProfileArcs(Poly, G);
    Delete(Face);
    if Face < First then Dec(First);
  end
  else
  begin
    { the profile is one cap, facing back against the sweep; the far end is
      the other, facing on }
    FEnts[Face].Solid := True;
    SetFaceGroup(Face, G);
    if Dot3(FaceNormal(Face), Tang) > 0 then FlipFace(Face);
    FaceOut(Rings[Steps], RotV(Tang, Ax, Angle));
    for K := 0 to N - 1 do
      Edge(Rings[Steps][K], Rings[Steps][(K + 1) mod N], False);
    for K := 0 to N - 1 do
    begin
      I := LineAt(Poly[K], Poly[(K + 1) mod N]);
      if I >= 0 then SetGroup(I, G);
    end;
  end;
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
  Result := First;
end;

procedure TWorkDoc.EdgePoints(I: Integer; out Pts: TP3Array);
var
  K, N: Integer;
begin
  Pts := nil;
  if (I < 0) or (I >= FLive) then Exit;
  case FEnts[I].Kind of
    ekLine:
      begin
        SetLength(Pts, 2);
        Pts[0] := FEnts[I].A;
        Pts[1] := FEnts[I].B;
      end;
    ekArc:
      begin
        N := ArcSteps(FEnts[I]);
        SetLength(Pts, N + 1);
        for K := 0 to N do
          if FEnts[I].Plane = plFree then
            Pts[K] := ArcPoint(FEnts[I].C, FEnts[I].R, FEnts[I].A0 + FEnts[I].Sweep * K / N,
              FEnts[I].Plane, FEnts[I].Nm)
          else
            Pts[K] := ArcPoint(FEnts[I].C, FEnts[I].R, FEnts[I].A0 + FEnts[I].Sweep * K / N,
              FEnts[I].Plane);
      end;
  end;
end;

function TWorkDoc.Sweep(Face: Integer; const Path: TP3Array; Closed: Boolean;
  Caps: Boolean): Integer;
const
  SOFT_TURN = 30 * Pi / 180;
var
  Poly: TP3Array;
  Pts: TP3Array;
  N, M, S, K, K2, G, I, First: Integer;
  Rings: array of array of TP3;
  DirIn, DirOut, B, Q, Cen, E, PrevE, Out, RingCen: TP3;
  T, Turn: Double;
  Hard: array of Boolean;

  function Near(const A, C: TP3): Boolean;
  begin
    Result := Dist(A, C) < 1E-9;
  end;

  function Sub(const A, C: TP3): TP3;
  begin
    Result := P3(A.X - C.X, A.Y - C.Y, A.Z - C.Z);
  end;

  procedure FaceOut(const P: array of TP3; const Want: TP3);
  begin
    AddFaceRaw(P, FEnts[Face].Ink, True);
    if FEnts[Face].MatSet then SetMaterial(FLive - 1, FEnts[Face].Mat);
    SetFaceGroup(FLive - 1, G);
    if Dot3(FaceNormal(FLive - 1), Want) < 0 then FlipFace(FLive - 1);
  end;

  procedure Edge(const A, C: TP3; Soft: Boolean);
  begin
    if Near(A, C) then Exit;
    AddLine(A, C, FEnts[Face].Ink, FEnts[Face].Weight, False);
    SetGroup(FLive - 1, G);
    SetSoft(FLive - 1, Soft);
  end;

  function LineAt(const A, C: TP3): Integer;
  var
    J: Integer;
  begin
    Result := -1;
    for J := 0 to FLive - 1 do
      if (FEnts[J].Kind = ekLine) and
         ((Near(FEnts[J].A, A) and Near(FEnts[J].B, C)) or
          (Near(FEnts[J].A, C) and Near(FEnts[J].B, A))) then Exit(J);
  end;

  { where the line through P along D meets the plane through O with normal Nm }
  function Meet(const P, D, O, Nm: TP3): TP3;
  var
    Den: Double;
  begin
    Den := Dot3(D, Nm);
    if Abs(Den) < 1E-12 then Exit(P);
    T := Dot3(Sub(O, P), Nm) / Den;
    Result := P3(P.X + D.X * T, P.Y + D.Y * T, P.Z + D.Z * T);
  end;

begin
  Result := -1;
  if (Face < 0) or (Face >= FLive) or (FEnts[Face].Kind <> ekFace) then Exit;
  { the path without repeated points }
  Pts := nil;
  for I := 0 to High(Path) do
    if (Length(Pts) = 0) or not Near(Pts[High(Pts)], Path[I]) then
    begin
      SetLength(Pts, Length(Pts) + 1);
      Pts[High(Pts)] := Path[I];
    end;
  M := Length(Pts);
  if Closed and (M > 1) and Near(Pts[0], Pts[M - 1]) then
  begin
    SetLength(Pts, M - 1);
    M := M - 1;
  end;
  if (M < 2) or (Closed and (M < 3)) then Exit;
  Poly := Copy(FEnts[Face].Poly);
  N := Length(Poly);
  if N < 3 then Exit;
  First := FLive;
  G := NewGroup;
  { The profile at every path point.  Along each leg the points travel with
    the leg; at a corner they are cut off on the plane that halves the
    corner, which is the mitre - so the ring there is the same ring seen
    from either leg.  A closed path has a mitre at its start too. }
  if Closed then SetLength(Rings, M + 1) else SetLength(Rings, M);
  SetLength(Hard, Length(Rings));
  Rings[0] := Copy(Poly);
  Hard[0] := True;
  for S := 1 to High(Rings) do
  begin
    SetLength(Rings[S], N);
    DirIn := Norm3(Sub(Pts[S mod M], Pts[(S - 1) mod M]));
    if Closed or (S < M - 1) then
    begin
      DirOut := Norm3(Sub(Pts[(S + 1) mod M], Pts[S mod M]));
      B := P3(DirIn.X + DirOut.X, DirIn.Y + DirOut.Y, DirIn.Z + DirOut.Z);
      if Dist(B, P3(0, 0, 0)) < 1E-9 then B := DirIn else B := Norm3(B);
      Turn := ArcCos(EnsureRange(Dot3(DirIn, DirOut), -1.0, 1.0));
    end
    else
    begin
      B := DirIn;
      Turn := Pi;
    end;
    Hard[S] := Turn >= SOFT_TURN;
    for K := 0 to N - 1 do
      Rings[S][K] := Meet(Rings[S - 1][K], DirIn, Pts[S mod M], B);
  end;
  if Closed then
  begin
    { the ring at the start, mitred like the rest, replaces the profile as
      drawn - which sat square to nothing in particular }
    Rings[0] := Copy(Rings[M]);
    Hard[0] := Hard[M];
  end;
  { the surface: a strip of quads per profile edge, each facing away from
    the middle of its own ring }
  for S := 0 to High(Rings) - 1 do
  begin
    RingCen := P3(0, 0, 0);
    for K := 0 to N - 1 do
      RingCen := P3(RingCen.X + (Rings[S][K].X + Rings[S + 1][K].X) / (2 * N),
                    RingCen.Y + (Rings[S][K].Y + Rings[S + 1][K].Y) / (2 * N),
                    RingCen.Z + (Rings[S][K].Z + Rings[S + 1][K].Z) / (2 * N));
    for K := 0 to N - 1 do
    begin
      K2 := (K + 1) mod N;
      Q := P3((Rings[S][K].X + Rings[S][K2].X + Rings[S + 1][K2].X + Rings[S + 1][K].X) / 4,
              (Rings[S][K].Y + Rings[S][K2].Y + Rings[S + 1][K2].Y + Rings[S + 1][K].Y) / 4,
              (Rings[S][K].Z + Rings[S][K2].Z + Rings[S + 1][K2].Z + Rings[S + 1][K].Z) / 4);
      Out := Sub(Q, RingCen);
      FaceOut([Rings[S][K], Rings[S][K2], Rings[S + 1][K2], Rings[S + 1][K]], Out);
    end;
    { the seam at the far ring: hard at a corner, soft along a curve }
    if (S + 1 <= High(Rings)) and (Closed or (S + 1 < High(Rings))) then
      for K := 0 to N - 1 do
        Edge(Rings[S + 1][K], Rings[S + 1][(K + 1) mod N], not Hard[S + 1]);
  end;
  { the lines each profile corner draws along the path: hard where the
    profile has a corner, soft where it only bends }
  for K := 0 to N - 1 do
  begin
    K2 := (K + 1) mod N;
    PrevE := Norm3(Sub(Poly[K], Poly[(K + N - 1) mod N]));
    E := Norm3(Sub(Poly[K2], Poly[K]));
    Turn := ArcCos(EnsureRange(Dot3(PrevE, E), -1.0, 1.0));
    for S := 0 to High(Rings) - 1 do
      Edge(Rings[S][K], Rings[S + 1][K], Turn < SOFT_TURN);
  end;
  if Closed then
  begin
    for K := 0 to N - 1 do
    begin
      I := LineAt(Poly[K], Poly[(K + 1) mod N]);
      if I >= 0 then Delete(I);
    end;
    { the profile's own edges and face are gone; the start ring, mitred, is
      drawn in their place }
    for K := 0 to N - 1 do
      Edge(Rings[0][K], Rings[0][(K + 1) mod N], not Hard[0]);
    MarkProfileArcs(Poly, G);
    for I := FLive - 1 downto 0 do
      if (FEnts[I].Kind = ekFace) and (I = Face) then Delete(I);
    First := -1;
    for I := 0 to FLive - 1 do
      if (FEnts[I].Kind = ekFace) and FEnts[I].Solid and (FEnts[I].Grp = G) then
      begin
        First := I;
        Break;
      end;
  end
  else if Caps then
  begin
    { the profile is the near cap; the far cap is the last ring }
    FEnts[Face].Solid := True;
    SetFaceGroup(Face, G);
    DirIn := Norm3(Sub(Pts[1], Pts[0]));
    if Dot3(FaceNormal(Face), DirIn) > 0 then FlipFace(Face);
    FaceOut(Rings[High(Rings)], Norm3(Sub(Pts[M - 1], Pts[M - 2])));
    for K := 0 to N - 1 do
      Edge(Rings[High(Rings)][K], Rings[High(Rings)][(K + 1) mod N], False);
    for K := 0 to N - 1 do
    begin
      I := LineAt(Poly[K], Poly[(K + 1) mod N]);
      if I >= 0 then SetGroup(I, G);
    end;
  end
  else
  begin
    { open at both ends, like a pipe: the rings at the ends are hard edges
      and the profile face goes, its edges staying as the near ring }
    for K := 0 to N - 1 do
      Edge(Rings[High(Rings)][K], Rings[High(Rings)][(K + 1) mod N], False);
    for K := 0 to N - 1 do
    begin
      I := LineAt(Poly[K], Poly[(K + 1) mod N]);
      if I >= 0 then SetGroup(I, G)
      else Edge(Poly[K], Poly[(K + 1) mod N], False);
    end;
    MarkProfileArcs(Poly, G);
    Delete(Face);
    if Face < First then Dec(First);
  end;
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
  Result := First;
end;

procedure TWorkDoc.SetArcSides(Index, N: Integer);
begin
  if (Index < 0) or (Index >= FLive) or (FEnts[Index].Kind <> ekArc) then Exit;
  if (N < 3) or (N > 360) then N := 0;
  FEnts[Index].Sides := N;
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
end;

{ --- groups ------------------------------------------------------------- }

procedure TWorkDoc.SetContext(Id: Integer);
begin
  if (Id <> 0) and (PartEnt(Id) < 0) then Id := 0;
  FContext := Id;
  FStamp := Id;
  { which crates are offered to snap to depends on where you are }
  FSnapDirty := True;
  FOnFaceOK := False;
  Inc(FEditSeq);
end;

function TWorkDoc.NewPart(const Name: string; Parent: Integer): Integer;
begin
  Inc(FNextPart);
  Result := FNextPart;
  Room;
  Finalize(FEnts[FLive]);
  FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
  FEnts[FLive].Kind := ekPart;
  FEnts[FLive].Grp := Result;
  FEnts[FLive].Txt := Name;
  FEnts[FLive].Solid := False;
  FEnts[FLive].Part := Parent;
  Inc(FLive);
  Inc(FEditSeq);
end;

function TWorkDoc.PartEnt(Id: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  if Id <= 0 then Exit;
  for I := 0 to FLive - 1 do
    if (FEnts[I].Kind = ekPart) and (FEnts[I].Grp = Id) then Exit(I);
end;

function TWorkDoc.PartName(Id: Integer): string;
var
  E: Integer;
begin
  E := PartEnt(Id);
  if E < 0 then Result := '' else Result := FEnts[E].Txt;
  if Result = '' then Result := 'Group ' + IntToStr(Id);
end;

function TWorkDoc.PartLocked(Id: Integer): Boolean;
var
  E: Integer;
begin
  E := PartEnt(Id);
  Result := (E >= 0) and FEnts[E].Solid;
end;

function TWorkDoc.PartParent(Id: Integer): Integer;
var
  E: Integer;
begin
  E := PartEnt(Id);
  if E < 0 then Result := 0 else Result := FEnts[E].Part;
end;

procedure TWorkDoc.SetPartName(Id: Integer; const Name: string);
var
  E: Integer;
begin
  E := PartEnt(Id);
  if E < 0 then Exit;
  FEnts[E].Txt := Name;
  Inc(FEditSeq);
end;

procedure TWorkDoc.SetPartLocked(Id: Integer; Locked: Boolean);
var
  E: Integer;
begin
  E := PartEnt(Id);
  if E < 0 then Exit;
  FEnts[E].Solid := Locked;
  Inc(FEditSeq);
end;

procedure TWorkDoc.SetPartParent(Id, Parent: Integer);
var
  E: Integer;
begin
  E := PartEnt(Id);
  if (E < 0) or (Id = Parent) then Exit;
  FEnts[E].Part := Parent;
  Inc(FEditSeq);
end;

procedure TWorkDoc.SetPart(Index, Id: Integer);
begin
  if (Index < 0) or (Index >= FLive) then Exit;
  if FEnts[Index].Kind = ekPart then Exit;      { a record moves by SetPartParent }
  FEnts[Index].Part := Id;
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
end;

function TWorkDoc.InsideContext(I: Integer): Boolean;
var
  P, Guard: Integer;
begin
  Result := True;
  if FContext = 0 then Exit;
  if (I < 0) or (I >= FLive) then Exit(False);
  { a group's own record stands for the group }
  if FEnts[I].Kind = ekPart then P := FEnts[I].Grp else P := FEnts[I].Part;
  Guard := 0;
  while (P <> 0) and (Guard < 1000) do
  begin
    if P = FContext then Exit(True);
    P := PartParent(P);
    Inc(Guard);
  end;
  Result := False;
end;

function TWorkDoc.TopPartIn(I: Integer): Integer;
var
  P, Up, Guard: Integer;
begin
  if (I < 0) or (I >= FLive) then Exit(-1);
  { a group's own record stands for the group, so a selection holding the
    record and every member reads as one group and not as one thing more }
  if FEnts[I].Kind = ekPart then P := FEnts[I].Grp else P := FEnts[I].Part;
  if P = FContext then Exit(0);
  Guard := 0;
  while (P <> 0) and (Guard < 1000) do
  begin
    Up := PartParent(P);
    if Up = FContext then Exit(P);
    P := Up;
    Inc(Guard);
  end;
  Result := -1;
end;

function TWorkDoc.PartLockedUp(Id: Integer): Boolean;
var
  Guard: Integer;
begin
  Result := False;
  Guard := 0;
  while (Id <> 0) and (Id <> FContext) and (Guard < 1000) do
  begin
    if PartLocked(Id) then Exit(True);
    Id := PartParent(Id);
    Inc(Guard);
  end;
end;

function TWorkDoc.PartMembers(Id: Integer; WithRecord: Boolean): TIntArrayW;
var
  I, N, P, Guard: Integer;
  In_: Boolean;
begin
  Result := nil;
  N := 0;
  if Id <= 0 then Exit;
  for I := 0 to FLive - 1 do
  begin
    if (FEnts[I].Kind = ekPart) and (FEnts[I].Grp = Id) then Continue;
    { in it, or in a group inside it }
    P := FEnts[I].Part;
    In_ := False;
    Guard := 0;
    while (P <> 0) and (Guard < 1000) do
    begin
      if P = Id then begin In_ := True; Break; end;
      P := PartParent(P);
      Inc(Guard);
    end;
    if not In_ then Continue;
    if N >= Length(Result) then SetLength(Result, Max(16, N * 2));
    Result[N] := I;
    Inc(N);
  end;
  if WithRecord then
  begin
    I := PartEnt(Id);
    if I >= 0 then
    begin
      if N >= Length(Result) then SetLength(Result, Max(16, N * 2));
      Result[N] := I;
      Inc(N);
    end;
  end;
  SetLength(Result, N);
end;

function TWorkDoc.PartBounds(Id: Integer; out Lo, Hi: TP3): Boolean;
var
  M: TIntArrayW;
  J, I, K, H: Integer;
  Steps: Integer;
  P: TP3;

  procedure Take(const Q: TP3);
  begin
    if not Result then
    begin
      Lo := Q; Hi := Q; Result := True;
      Exit;
    end;
    Lo := P3(Min(Lo.X, Q.X), Min(Lo.Y, Q.Y), Min(Lo.Z, Q.Z));
    Hi := P3(Max(Hi.X, Q.X), Max(Hi.Y, Q.Y), Max(Hi.Z, Q.Z));
  end;

begin
  Result := False;
  Lo := P3(0, 0, 0);
  Hi := Lo;
  M := PartMembers(Id, False);
  for J := 0 to High(M) do
  begin
    I := M[J];
    case FEnts[I].Kind of
      ekLine, ekGuide:
        begin
          Take(FEnts[I].A);
          Take(FEnts[I].B);
        end;
      ekArc:
        begin
          Steps := ArcSteps(FEnts[I]);
          for K := 0 to Steps do
          begin
            P := ArcPoint(FEnts[I].C, FEnts[I].R,
              FEnts[I].A0 + FEnts[I].Sweep * K / Steps, FEnts[I].Plane, FEnts[I].Nm);
            Take(P);
          end;
        end;
      ekFace:
        begin
          for K := 0 to High(FEnts[I].Poly) do Take(FEnts[I].Poly[K]);
          for H := 0 to High(FEnts[I].Holes) do
            for K := 0 to High(FEnts[I].Holes[H]) do Take(FEnts[I].Holes[H][K]);
        end;
      ekText, ekDim:
        begin
          Take(FEnts[I].A);
          if FEnts[I].Kind = ekDim then Take(FEnts[I].B);
        end;
    end;
  end;
end;

procedure TWorkDoc.RecountParts;
var
  I: Integer;
begin
  FNextPart := 0;
  for I := 0 to FLive - 1 do
    if (FEnts[I].Kind = ekPart) and (FEnts[I].Grp > FNextPart) then
      FNextPart := FEnts[I].Grp;
end;

{ A pen or a fill, faded when it lies outside the group that is open.
  SketchUp greys the rest of the model while you are inside an object, so
  what you can change and what you cannot is one look apart. }
function TWorkDoc.DimIf(I: Integer; const C: TPix): TPix;
begin
  if (FContext <> 0) and not InsideContext(I) then
    Result := MixPix(C, Pix(255, 255, 255), 0.62)
  else
    Result := C;
end;

function TWorkDoc.InkPix(I: Integer): TPix;
begin
  Result := DimIf(I, ColorToPix(FEnts[I].Ink));
end;

function TWorkDoc.NewGroup: Integer;
begin
  Inc(FNextGrp);
  Result := FNextGrp;
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
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
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
{ Which face is under that pixel, and where on it.

  The answer is remembered for the pixel it was asked about, because it is
  asked more than once for the same one.  A single mouse move over a drawing
  with push/pull in hand asks it for the stipple, and the snap asks it again
  for an on-face point, and on some tools the commit asks a third time - all
  with the same X and Y, the same camera and nothing edited in between.  This
  walks every face in the drawing casting a ray, so it is not a cheap thing
  to do three times for one answer.

  Thrown away the moment anything could change it: an edit, a different
  camera, a different slice.  Nothing else can. }
function TWorkDoc.FaceUnder(const V: TProjector; SX, SY: Double;
  out Face: Integer; out Pt: TP3): Boolean;
var
  I, J, K, N, M, HK: Integer;
  Inside: Boolean;
  P, HP: array of TPointF;
  Look, Org, U, W, Hit: TP3;
  P0, P1, P2: TPointF;
  AX, AY, BX, BY, Det, SS, TT, D, Best, Eps: Double;
  PC: TProjCache;
begin
  if FFaceMemoOK and (FFaceMemoSeq = FEditSeq) and
     (FFaceMemoX = SX) and (FFaceMemoY = SY) and
     SameProjector(V, FFaceMemoV) and
     (FFaceMemoSlice = FSliceOn) and (FFaceMemoLo = FSliceLo) and
     (FFaceMemoHi = FSliceHi) then
  begin
    Face := FFaceMemoFace;
    Pt := FFaceMemoPt;
    Exit(Face >= 0);
  end;

  Result := False;
  Face := -1;
  Pt := P3(0, 0, 0);
  Best := -1E300;
  Look := ViewDir(V);
  { the camera once for the whole walk - this projects every corner of every
    face in the drawing, and Project rebuilds the view basis each time }
  BeginProject(V, PC);

  for I := 0 to FLive - 1 do
  begin
    if FEnts[I].Kind <> ekFace then Continue;
    if not InSlice(I) then Continue;
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
      P[K] := ProjectAt(PC, FEnts[I].Poly[K]);

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
        for K := 0 to M - 1 do HP[K] := ProjectAt(PC, FEnts[I].Holes[HK][K]);
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
    P0 := ProjectAt(PC, Org);
    P1 := ProjectAt(PC, P3(Org.X + U.X, Org.Y + U.Y, Org.Z + U.Z));
    P2 := ProjectAt(PC, P3(Org.X + W.X, Org.Y + W.Y, Org.Z + W.Z));
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
  FFaceMemoOK := True;
  FFaceMemoSeq := FEditSeq;
  FFaceMemoX := SX;
  FFaceMemoY := SY;
  FFaceMemoV := V;
  FFaceMemoFace := Face;
  FFaceMemoPt := Pt;
  FFaceMemoSlice := FSliceOn;
  FFaceMemoLo := FSliceLo;
  FFaceMemoHi := FSliceHi;
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
{ Where two edges cross, both should end there.

  Somebody rounding off a corner draws a circle over it, rubs out three
  quarters of the circle and the square corner behind it, and is left with
  the fillet.  That only works if the crossings are real ends: if the
  rectangle's side is still one long line from corner to corner there is
  nothing to rub out but the whole of it, and if the circle is still one
  closed loop the three quarters cannot go without the quarter he wants.
  SketchUp cuts both at every crossing as the new edge lands, and this is
  that.

  Only loose drawing takes part - nothing belonging to a solid, no guides,
  no dimensions - and a pair is only looked at when one of the two was drawn
  since FirstNew, so the rest of the drawing is never quietly rewritten
  underneath somebody.

  An arc is walked as the segments it is really drawn with, so what counts
  as a crossing is what the eye sees crossing.  A piece of one keeps its
  share of the sides, which lands the pieces' corners back on the whole
  one's whenever the cut fell on a corner - as a tangent always does. }
{ ---------------------------------------------------------------------- }
{ rounding a corner                                                       }
{ ---------------------------------------------------------------------- }

{ From a note, 16 September: "i was trying to make a rectangle have rounded corners
  using the arc tool in its corners but it seemed like i was always getting
  like a bubbled out corner unless i got the dimension just right.  sketchup
  seems to handle it much better... there arc shows up with a hint about
  tangent on edge."

  SketchUp's two-point arc, read against their help and their forum: click a
  point on each of the two edges near a corner and pull the bulge out; when
  the arc runs tangent into both edges it turns magenta; a radius typed then
  sets the size; a double-click finishes it AND trims the square corner away;
  and a double-click near any other corner repeats the same fillet there.

  A plain click leaves the square corner in place, cut at the touching
  points.  From a note, from using SketchUp: "you have to erase the sharp left over
  90 degree lines after you put the arc there... maybe you just want an arc
  inside the pointed corner... so keep it just like sketchup!"  So the trim
  is only ever the double-click's, never the click's or the Enter's.

  Ours had none of it.  The bulge was whatever the mouse said, so an arc that
  met the edges smoothly was a matter of luck - and every other bulge is the
  bubble he was getting.  These are the geometry for all of it, kept here
  rather than in the tool so the tests can ask them directly.

  Only loose lines take part - the same rule SplitCrossings has.  A corner
  of a built solid is part of something made on purpose, and rounding it
  from underneath would tear the solid. }

{ The two loose lines that meet at Corner - exactly two, not parallel.  A
  corner with three lines into it has no single fillet, and saying no is
  better than guessing which pair was meant. }
function TWorkDoc.CornerLines(const Corner: TP3; out LA, LB: Integer): Boolean;
const
  TOL = 1E-6;
var
  I, N: Integer;
  DA, DB: TP3;
begin
  Result := False;
  LA := -1;
  LB := -1;
  N := 0;
  for I := 0 to FLive - 1 do
  begin
    if FEnts[I].Kind <> ekLine then Continue;
    if FEnts[I].Dim or (FEnts[I].Grp <> 0) or (FEnts[I].Part <> FStamp) then Continue;
    if not (SamePt(FEnts[I].A, Corner, TOL) or SamePt(FEnts[I].B, Corner, TOL)) then
      Continue;
    if Dist(FEnts[I].A, FEnts[I].B) < TOL then Continue;
    Inc(N);
    if N = 1 then LA := I
    else if N = 2 then LB := I;
  end;
  if N <> 2 then Exit;
  DA := Norm3(P3(FarEnd(LA, Corner).X - Corner.X, FarEnd(LA, Corner).Y - Corner.Y,
                 FarEnd(LA, Corner).Z - Corner.Z));
  DB := Norm3(P3(FarEnd(LB, Corner).X - Corner.X, FarEnd(LB, Corner).Y - Corner.Y,
                 FarEnd(LB, Corner).Z - Corner.Z));
  { straight on through, or doubled back: no corner to round }
  Result := Abs(Dot3(DA, DB)) < 1 - 1E-6;
end;

{ The other end of a line from P. }
function TWorkDoc.FarEnd(I: Integer; const P: TP3): TP3;
begin
  if Dist(FEnts[I].A, P) < Dist(FEnts[I].B, P) then Result := FEnts[I].B
  else Result := FEnts[I].A;
end;

{ Everything about a fillet of radius R at Corner, without doing it.

  The tangent points sit T from the corner along each line, where T is
  R / tan(half the angle between them) - for a square corner, T is R.  A
  radius too big for the shorter of the two lines is refused rather than
  run off its end: the fillet would have to eat the next corner too, and
  that is not what anybody typed a radius to get. }
function TWorkDoc.FilletAt(const Corner: TP3; R: Double; out F: TFillet): Boolean;
const
  TOL = 1E-6;
var
  UA, UB, N, Mid, Dir: TP3;
  Th, LenA, LenB, U1, V1, U2, V2, UC, VC, Ln, NU, NV, Sag: Double;
  FO, FU, FV: TP3;
begin
  Result := False;
  FillChar(F, SizeOf(F), 0);
  if R <= TOL then Exit;
  if not CornerLines(Corner, F.LineA, F.LineB) then Exit;
  F.Corner := Corner;
  UA := FarEnd(F.LineA, Corner);
  UB := FarEnd(F.LineB, Corner);
  LenA := Dist(UA, Corner);
  LenB := Dist(UB, Corner);
  UA := Norm3(P3(UA.X - Corner.X, UA.Y - Corner.Y, UA.Z - Corner.Z));
  UB := Norm3(P3(UB.X - Corner.X, UB.Y - Corner.Y, UB.Z - Corner.Z));
  Th := ArcCos(EnsureRange(Dot3(UA, UB), -1, 1));
  if (Th < 1E-6) or (Th > Pi - 1E-6) then Exit;
  F.R := R;
  F.T := R / Tan(Th / 2);
  if (F.T > LenA + TOL) or (F.T > LenB + TOL) then Exit;
  F.S := P3(Corner.X + UA.X * F.T, Corner.Y + UA.Y * F.T, Corner.Z + UA.Z * F.T);
  F.E := P3(Corner.X + UB.X * F.T, Corner.Y + UB.Y * F.T, Corner.Z + UB.Z * F.T);

  { the plane the two lines lie in, named when it is one of the three }
  N := Norm3(Cross3(UA, UB));
  F.Nm := N;
  if Abs(N.Z) > 1 - 1E-9 then F.Pl := plXY
  else if Abs(N.Y) > 1 - 1E-9 then F.Pl := plXZ
  else if Abs(N.X) > 1 - 1E-9 then F.Pl := plYZ
  else
  begin
    { keep whatever free plane the window had, and put it back after -
      this is a question, not a change of working plane }
    GetFreePlane(FO, FU, FV, Dir);
    SetFreePlane(Corner, N);
    F.Pl := plFree;
  end;

  { The bulge, signed the way ArcFromChord reads it: towards the corner.
    The arc turns through the outside angle, pi less the corner's, so its
    middle stands R(1 - cos(half of that)) off the chord. }
  PlaneCoords(F.Pl, F.S, U1, V1);
  PlaneCoords(F.Pl, F.E, U2, V2);
  PlaneCoords(F.Pl, Corner, UC, VC);
  Ln := Sqrt(Sqr(U2 - U1) + Sqr(V2 - V1));
  if Ln < TOL then
  begin
    if F.Pl = plFree then SetFreePlane(FO, Dir);
    Exit;
  end;
  NU := -(V2 - V1) / Ln;
  NV := (U2 - U1) / Ln;
  Sag := R * (1 - Cos((Pi - Th) / 2));
  Mid := P3((U1 + U2) / 2, (V1 + V2) / 2, 0);
  if (UC - Mid.X) * NU + (VC - Mid.Y) * NV >= 0 then F.Bulge := Sag
  else F.Bulge := -Sag;
  Result := ArcFromChord(F.S, F.E, F.Bulge, F.Pl, F.ArcC, R, F.A0, F.Sweep);
  if F.Pl = plFree then
  begin
    { AddArc reads the free plane when it is called, so ApplyFillet sets it
      again from F.Nm; the window's own is put back here }
    SetFreePlane(FO, Dir);
  end;
end;

{ The fillet a pair of picks is aiming at: S on one line near a corner, E on
  the other.  The radius is taken from how far S is from the corner, so the
  first click is where the arc starts, as it was clicked - E is moved to
  match, because an arc can only run tangent into both lines when it touches
  both at the same distance.  That is the magenta state. }
function TWorkDoc.FilletFromEnds(const S, E: TP3; out F: TFillet): Boolean;
const
  TOL = 1E-6;
var
  I, J, Swap, LA, LB, Other: Integer;
  Ends: array[0..1] of TP3;
  Corner, UA, UB: TP3;
  T, Th: Double;

  function OnLine(K: Integer; const P: TP3): Boolean;
  var
    L, D1, D2: Double;
  begin
    L := Dist(FEnts[K].A, FEnts[K].B);
    D1 := Dist(FEnts[K].A, P);
    D2 := Dist(FEnts[K].B, P);
    { strictly inside it: a pick on the corner itself is no fillet }
    Result := (D1 > TOL) and (D2 > TOL) and (Abs(D1 + D2 - L) < 1E-6 * (1 + L));
  end;

begin
  Result := False;
  FillChar(F, SizeOf(F), 0);
  for I := 0 to FLive - 1 do
  begin
    if (FEnts[I].Kind <> ekLine) or FEnts[I].Dim or (FEnts[I].Grp <> 0) or (FEnts[I].Part <> FStamp) then
      Continue;
    if not OnLine(I, S) then Continue;
    Ends[0] := FEnts[I].A;
    Ends[1] := FEnts[I].B;
    for J := 0 to 1 do
    begin
      Corner := Ends[J];
      T := Dist(S, Corner);
      { the line E sits on has to be the other line at this corner }
      if not CornerLines(Corner, LA, LB) then Continue;
      if LA = I then Other := LB
      else if LB = I then Other := LA
      else Continue;
      if not OnLine(Other, E) then Continue;
      { the radius whose tangent points are T from the corner }
      UA := Norm3(P3(FarEnd(LA, Corner).X - Corner.X,
                     FarEnd(LA, Corner).Y - Corner.Y,
                     FarEnd(LA, Corner).Z - Corner.Z));
      UB := Norm3(P3(FarEnd(LB, Corner).X - Corner.X,
                     FarEnd(LB, Corner).Y - Corner.Y,
                     FarEnd(LB, Corner).Z - Corner.Z));
      Th := ArcCos(EnsureRange(Dot3(UA, UB), -1, 1));
      if not FilletAt(Corner, T * Tan(Th / 2), F) then Continue;
      { S should come back as the S that was clicked, on whichever side }
      if Dist(F.E, S) < Dist(F.S, S) then
      begin
        F.E := F.S;
        F.S := S;
        Swap := F.LineA; F.LineA := F.LineB; F.LineB := Swap;
        { the arc was built S to E; built the other way round the bulge
          changes side }
        F.Bulge := -F.Bulge;
        Exit(ArcFromChordFor(F));
      end;
      Exit(True);
    end;
  end;
end;

{ Is anything else joined to this end of line I - another line or an arc
  with an end in the same place? }
function TWorkDoc.LineEndJoined(I: Integer; AtB: Boolean): Boolean;
const
  TOL = 1E-6;
var
  K: Integer;
  P: TP3;
begin
  Result := False;
  if AtB then P := FEnts[I].B else P := FEnts[I].A;
  for K := 0 to FLive - 1 do
  begin
    if K = I then Continue;
    if not (FEnts[K].Kind in [ekLine, ekArc]) then Continue;
    if FEnts[K].Dim then Continue;
    if SamePt(FEnts[K].A, P, TOL) or SamePt(FEnts[K].B, P, TOL) then Exit(True);
  end;
end;

{ Which end of a line gives when its length is typed - SketchUp's rule, as
  their forum's DaveR puts it:

    "the edge is not connected to any other edges, the length change is made
    relative to the last endpoint.  The edge is connected to another edge at
    only one end, the length change is made relative to the free end.  The
    edge is connected to an edge at each of its ends, the length cannot be
    edited."

  From a note, 16 September, on which end should move: "maybe the user could
  indicate which way they want it to move some how... with an extra key.
  idk... i dont want to stray from sketchup too much."  SketchUp's rule
  needs no key, because in every case it allows there is only one end that
  can move without tearing something - so this is that rule and nothing
  more.  False when both ends are held. }
function TWorkDoc.LineLengthEnd(I: Integer; out MoveB: Boolean): Boolean;
var
  JA, JB: Boolean;
begin
  Result := False;
  MoveB := True;
  if (I < 0) or (I >= FLive) or (FEnts[I].Kind <> ekLine) or FEnts[I].Dim then
    Exit;
  JA := LineEndJoined(I, False);
  JB := LineEndJoined(I, True);
  if JA and JB then Exit;
  { loose, or held at A: the end it was drawn to moves.  Held at B: A does. }
  MoveB := not JB;
  Result := True;
end;

{ Make line I NewLen long, moving the end LineLengthEnd names along the line's
  own direction. }
function TWorkDoc.SetLineLength(I: Integer; NewLen: Double): Boolean;
var
  MoveB: Boolean;
  L: Double;
  D: TP3;
begin
  Result := False;
  if NewLen <= 1E-9 then Exit;
  if not LineLengthEnd(I, MoveB) then Exit;
  L := Dist(FEnts[I].A, FEnts[I].B);
  if L < 1E-9 then Exit;
  if MoveB then
  begin
    D := P3((FEnts[I].B.X - FEnts[I].A.X) / L, (FEnts[I].B.Y - FEnts[I].A.Y) / L,
            (FEnts[I].B.Z - FEnts[I].A.Z) / L);
    FEnts[I].B := P3(FEnts[I].A.X + D.X * NewLen, FEnts[I].A.Y + D.Y * NewLen,
                     FEnts[I].A.Z + D.Z * NewLen);
  end
  else
  begin
    D := P3((FEnts[I].A.X - FEnts[I].B.X) / L, (FEnts[I].A.Y - FEnts[I].B.Y) / L,
            (FEnts[I].A.Z - FEnts[I].B.Z) / L);
    FEnts[I].A := P3(FEnts[I].B.X + D.X * NewLen, FEnts[I].B.Y + D.Y * NewLen,
                     FEnts[I].B.Z + D.Z * NewLen);
  end;
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
  Result := True;
end;

{ Take the square corner off a fillet that is already in: every loose line
  running between the corner and one of the two touching points.  Its own
  step because SketchUp's double-click is two clicks - the first puts the
  arc in, the second trims - and the second has to find what the first
  left.  Answers how many went. }
function TWorkDoc.TrimFillet(const F: TFillet): Integer;
const
  TOL = 1E-6;
var
  Doomed: array of Boolean;
  K: Integer;
begin
  Result := 0;
  SetLength(Doomed, FLive);
  for K := 0 to FLive - 1 do
  begin
    Doomed[K] := False;
    if (FEnts[K].Kind <> ekLine) or FEnts[K].Dim or (FEnts[K].Grp <> 0) or (FEnts[K].Part <> FStamp) then
      Continue;
    if (SamePt(FEnts[K].A, F.Corner, TOL) and
        (SamePt(FEnts[K].B, F.S, TOL) or SamePt(FEnts[K].B, F.E, TOL))) or
       (SamePt(FEnts[K].B, F.Corner, TOL) and
        (SamePt(FEnts[K].A, F.S, TOL) or SamePt(FEnts[K].A, F.E, TOL))) then
    begin
      Doomed[K] := True;
      Inc(Result);
    end;
  end;
  if Result > 0 then DeleteMarked(Doomed);
end;

{ ArcFromChord for a fillet whose ends have been swapped, in its own plane. }
function TWorkDoc.ArcFromChordFor(var F: TFillet): Boolean;
var
  FO, FU, FV, Dir: TP3;
  R: Double;
begin
  if F.Pl = plFree then
  begin
    GetFreePlane(FO, FU, FV, Dir);
    SetFreePlane(F.Corner, F.Nm);
  end;
  Result := ArcFromChord(F.S, F.E, F.Bulge, F.Pl, F.ArcC, R, F.A0, F.Sweep);
  if F.Pl = plFree then SetFreePlane(FO, Dir);
end;

{ The roundable corner nearest a screen point - a point where exactly two
  loose lines meet at an angle.  This is what a double-click reaches for
  when it repeats the last fillet: SketchUp's "move your cursor close to
  another corner and double-click". }
function TWorkDoc.NearestCorner(const V: TProjector; SX, SY, TolPx: Double;
  out Corner: TP3): Boolean;
var
  I, K, LA, LB: Integer;
  P: TP3;
  Q: TPointF;
  D, Best: Double;
  PC: TProjCache;
begin
  Result := False;
  Corner := P3(0, 0, 0);
  Best := TolPx;
  BeginProject(V, PC);
  for I := 0 to FLive - 1 do
  begin
    if (FEnts[I].Kind <> ekLine) or FEnts[I].Dim or (FEnts[I].Grp <> 0) or (FEnts[I].Part <> FStamp) then
      Continue;
    if not InSlice(I) then Continue;
    for K := 0 to 1 do
    begin
      if K = 0 then P := FEnts[I].A else P := FEnts[I].B;
      Q := ProjectAt(PC, P);
      D := Sqrt(Sqr(SX - Q.X) + Sqr(SY - Q.Y));
      if D >= Best then Continue;
      if HiddenAt(V, P) then Continue;
      if not CornerLines(P, LA, LB) then Continue;
      Best := D;
      Corner := P;
      Result := True;
    end;
  end;
end;

{ Round the corner.

  The arc goes in; each line is cut at its tangent point; and with Trim, the
  two short pieces between the tangent points and the corner go - which is
  SketchUp's double-click, "the face and edges on the outside of your arc
  disappear".  The face is not touched here: faces come from the edges that
  close them, so once the corner's edges are gone the next rebuild draws the
  rounded face on its own.

  Without Trim the corner stays and the lines are still cut, so the pieces
  can be rubbed out one at a time - the same arrangement as an arc drawn
  across any other edge. }
function TWorkDoc.ApplyFillet(const F: TFillet; Sides: Integer; Ink: TColor;
  Weight: Single; Trim: Boolean): Boolean;
const
  TOL = 1E-6;
var
  FO, FU, FV, Dir, FarA, FarB: TP3;
  LA, LB, Arc, K: Integer;
  R: Double;

  { cut line K at P, keeping the piece away from the corner in place and
    adding the corner piece; true when a corner piece was made }
  function Cut(K: Integer; const P, FarP: TP3): Boolean;
  begin
    Result := False;
    if Dist(P, FarP) < TOL then
    begin
      { the fillet takes the whole of this line }
      FEnts[K].A := F.Corner;
      FEnts[K].B := P;
      Exit(True);
    end;
    FEnts[K].A := FarP;
    FEnts[K].B := P;
    AddLine(P, F.Corner, FEnts[K].Ink, FEnts[K].Weight, False);
    Result := True;
  end;

begin
  Result := False;
  LA := F.LineA;
  LB := F.LineB;
  if (LA < 0) or (LB < 0) or (LA >= FLive) or (LB >= FLive) then Exit;
  R := Dist(F.ArcC, F.S);
  if R <= TOL then Exit;
  FarA := FarEnd(LA, F.Corner);
  FarB := FarEnd(LB, F.Corner);

  { A corner rounded before with a plain click still has its square corner,
  so it is still a corner - and a double-click there has to mean "trim it",
  not "put a second arc on top of the first".  If an arc already runs
  between the two touching points, the lines are already cut there too, and
  all that is left to do is the trim. }
  for K := 0 to FLive - 1 do
    if (FEnts[K].Kind = ekArc) and
       ((SamePt(FEnts[K].A, F.S, 1E-6) and SamePt(FEnts[K].B, F.E, 1E-6)) or
        (SamePt(FEnts[K].A, F.E, 1E-6) and SamePt(FEnts[K].B, F.S, 1E-6))) then
    begin
      if Trim then TrimFillet(F);
      Exit(True);
    end;

  { the corner pieces, cut off each line }
  Cut(LA, F.S, FarA);
  Cut(LB, F.E, FarB);

  if F.Pl = plFree then
  begin
    GetFreePlane(FO, FU, FV, Dir);
    SetFreePlane(F.Corner, F.Nm);
  end;
  AddArc(F.ArcC, R, F.A0, F.Sweep, F.Pl, Ink, Weight);
  Arc := FLive - 1;
  if F.Pl = plFree then SetFreePlane(FO, Dir);
  if Sides > 0 then SetArcSides(Arc, Sides);

  if Trim then TrimFillet(F);
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
  Result := True;
end;


function TWorkDoc.SplitCrossings(FirstNew: Integer): Integer;
const
  TOL = 1E-6;      { how close two edges pass before they count as meeting }
type
  TWalk = record
    Ent: Integer;
    Fresh: Boolean;
    Len: Double;
    Pts: TP3Array;
    Cut: array of Double;
  end;
var
  W: array of TWalk;
  Made: array of TWorkEnt;
  Doom: array of Boolean;
  NW, NMade: Integer;
  I, J, K, A, B, Steps: Integer;
  S, T, D, Tmp, LA, LB: Double;

  { the nearest approach of two segments, and where along each it happens.
    Near-parallel is left alone: two runs lying on each other are
    AddLineSplit's business, and a crossing worked out from a vanishing
    denominator is noise. }
  procedure Nearest(const P1, P2, Q1, Q2: TP3; out SS, TT, DD: Double);
  var
    D1, D2, R, C1, C2: TP3;
    Aa, Bb, Cc, Ee, Ff, Den: Double;
  begin
    SS := 0; TT := 0; DD := 1E30;
    D1 := P3(P2.X - P1.X, P2.Y - P1.Y, P2.Z - P1.Z);
    D2 := P3(Q2.X - Q1.X, Q2.Y - Q1.Y, Q2.Z - Q1.Z);
    R := P3(P1.X - Q1.X, P1.Y - Q1.Y, P1.Z - Q1.Z);
    Aa := Dot3(D1, D1);
    Ee := Dot3(D2, D2);
    if (Aa < 1E-24) or (Ee < 1E-24) then Exit;
    Bb := Dot3(D1, D2);
    Cc := Dot3(D1, R);
    Ff := Dot3(D2, R);
    Den := Aa * Ee - Bb * Bb;
    if Den <= 1E-12 * Aa * Ee then Exit;
    SS := (Bb * Ff - Cc * Ee) / Den;
    if SS < 0 then SS := 0 else if SS > 1 then SS := 1;
    TT := (Bb * SS + Ff) / Ee;
    if TT < 0 then
    begin
      TT := 0;
      SS := -Cc / Aa;
    end
    else if TT > 1 then
    begin
      TT := 1;
      SS := (Bb - Cc) / Aa;
    end;
    if SS < 0 then SS := 0 else if SS > 1 then SS := 1;
    C1 := P3(P1.X + D1.X * SS, P1.Y + D1.Y * SS, P1.Z + D1.Z * SS);
    C2 := P3(Q1.X + D2.X * TT, Q1.Y + D2.Y * TT, Q1.Z + D2.Z * TT);
    DD := Dist(C1, C2);
  end;

  { A cut at either end is no cut at all - the edge already ends there.
    Measured along the edge and not in its parameter: an inch either side of
    the end is an inch whether the edge is a foot long or a hundred, and a
    cut let through a hair from the end leaves a hair of an edge behind,
    which is worse than the crossing it came from. }
  procedure Note(Which: Integer; U: Double);
  var
    Q, N: Integer;
    L: Double;
  begin
    L := W[Which].Len;
    if L < TOL then Exit;
    if (U * L < TOL) or ((1 - U) * L < TOL) then Exit;
    for Q := 0 to High(W[Which].Cut) do
      if Abs(W[Which].Cut[Q] - U) * L < TOL then Exit;
    N := Length(W[Which].Cut);
    SetLength(W[Which].Cut, N + 1);
    W[Which].Cut[N] := U;
  end;

  procedure Piece(const E: TWorkEnt; U0, U1: Double);
  var
    N: TWorkEnt;
    Sd: Integer;
  begin
    if U1 <= U0 then Exit;
    N := E;
    if E.Kind = ekLine then
    begin
      N.A := P3(E.A.X + (E.B.X - E.A.X) * U0,
                E.A.Y + (E.B.Y - E.A.Y) * U0,
                E.A.Z + (E.B.Z - E.A.Z) * U0);
      N.B := P3(E.A.X + (E.B.X - E.A.X) * U1,
                E.A.Y + (E.B.Y - E.A.Y) * U1,
                E.A.Z + (E.B.Z - E.A.Z) * U1);
      if Dist(N.A, N.B) < TOL then Exit;
    end
    else
    begin
      N.A0 := E.A0 + E.Sweep * U0;
      N.Sweep := E.Sweep * (U1 - U0);
      if Abs(N.Sweep) < 1E-9 then Exit;
      Sd := Round(ArcSteps(E) * (U1 - U0));
      if Sd < 3 then Sd := 3;
      N.Sides := Sd;
      N.A := ArcPoint(N.C, N.R, N.A0, N.Plane, N.Nm);
      N.B := ArcPoint(N.C, N.R, N.A0 + N.Sweep, N.Plane, N.Nm);
    end;
    if NMade >= Length(Made) then SetLength(Made, Max(8, NMade * 2));
    Made[NMade] := N;
    Inc(NMade);
  end;

begin
  Result := 0;
  NMade := 0;
  NW := 0;
  SetLength(W, FLive);
  for I := 0 to FLive - 1 do
  begin
    if not (FEnts[I].Kind in [ekLine, ekArc]) then Continue;
    if FEnts[I].Dim or (FEnts[I].Grp <> 0) or (FEnts[I].Part <> FStamp) then Continue;
    W[NW].Ent := I;
    W[NW].Fresh := I >= FirstNew;
    W[NW].Cut := nil;
    if FEnts[I].Kind = ekArc then
    begin
      Steps := ArcSteps(FEnts[I]);
      SetLength(W[NW].Pts, Steps + 1);
      for K := 0 to Steps do
        W[NW].Pts[K] := ArcPoint(FEnts[I].C, FEnts[I].R,
          FEnts[I].A0 + FEnts[I].Sweep * K / Steps,
          FEnts[I].Plane, FEnts[I].Nm);
    end
    else
    begin
      SetLength(W[NW].Pts, 2);
      W[NW].Pts[0] := FEnts[I].A;
      W[NW].Pts[1] := FEnts[I].B;
    end;
    W[NW].Len := 0;
    for K := 0 to High(W[NW].Pts) - 1 do
      W[NW].Len := W[NW].Len + Dist(W[NW].Pts[K], W[NW].Pts[K + 1]);
    Inc(NW);
  end;

  for I := 0 to NW - 1 do
    for J := I + 1 to NW - 1 do
    begin
      if not (W[I].Fresh or W[J].Fresh) then Continue;
      for A := 0 to High(W[I].Pts) - 1 do
        for B := 0 to High(W[J].Pts) - 1 do
        begin
          Nearest(W[I].Pts[A], W[I].Pts[A + 1],
                  W[J].Pts[B], W[J].Pts[B + 1], S, T, D);
          if D > TOL then Continue;
          { A tangent touches at a corner of the arc as it is drawn, and the
            hit comes back a whisker either side of it.  Pulled onto the
            corner it lands the cut exactly where the arc already has a
            point, so the pieces sit on the whole one and a second look at
            the same drawing finds nothing left to do. }
          LA := Dist(W[I].Pts[A], W[I].Pts[A + 1]);
          LB := Dist(W[J].Pts[B], W[J].Pts[B + 1]);
          if S * LA < TOL then S := 0
          else if (1 - S) * LA < TOL then S := 1;
          if T * LB < TOL then T := 0
          else if (1 - T) * LB < TOL then T := 1;
          Note(I, (A + S) / High(W[I].Pts));
          Note(J, (B + T) / High(W[J].Pts));
        end;
    end;

  SetLength(Doom, FLive);
  for I := 0 to FLive - 1 do Doom[I] := False;

  for I := 0 to NW - 1 do
  begin
    if Length(W[I].Cut) = 0 then Continue;
    for J := 1 to High(W[I].Cut) do
    begin
      Tmp := W[I].Cut[J];
      K := J - 1;
      while (K >= 0) and (W[I].Cut[K] > Tmp) do
      begin
        W[I].Cut[K + 1] := W[I].Cut[K];
        Dec(K);
      end;
      W[I].Cut[K + 1] := Tmp;
    end;
    Piece(FEnts[W[I].Ent], 0, W[I].Cut[0]);
    for J := 0 to High(W[I].Cut) - 1 do
      Piece(FEnts[W[I].Ent], W[I].Cut[J], W[I].Cut[J + 1]);
    Piece(FEnts[W[I].Ent], W[I].Cut[High(W[I].Cut)], 1);
    Doom[W[I].Ent] := True;
    Inc(Result);
  end;

  if Result = 0 then Exit;

  DeleteMarked(Doom);
  for I := 0 to NMade - 1 do
  begin
    Room;
    Finalize(FEnts[FLive]);
    FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
    FEnts[FLive] := CopyEnt(Made[I]);
    Inc(FLive);
  end;
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
end;

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
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
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
  I, Q, K, N, M, RB: Integer;
  Nm: TP3;
  PlaneD: Double;
  A, B: TP3Array;
begin
  Result := False;
  if (Index < 0) or (Index >= FLive) or (FEnts[Index].Kind <> ekFace) then Exit;
  if Length(FEnts[Index].Poly) < 3 then Exit;
  Nm := FaceNormal(Index);
  PlaneD := Dot3(Nm, FEnts[Index].Poly[0]);

  for I := 0 to FLive - 1 do
  begin
    if I = Index then Continue;
    if FEnts[I].Kind <> ekFace then Continue;
    if Length(FEnts[I].Poly) < 3 then Continue;
    { in the same plane?  the normals may point opposite ways }
    if Abs(Abs(Dot3(FaceNormal(I), Nm)) - 1) > TOL then Continue;
    if Abs(Dot3(Nm, FEnts[I].Poly[0]) - PlaneD) > TOL then Continue;
    { Sharing an edge with it?

      The neighbor's openings count.  A letter sitting in a hole cut out of
      the panel under it touches that panel along the hole and nowhere else,
      never along the panel's outline - so reading outlines only made an
      island look like the whole flat side of a solid, and pushing one slid
      the whole toy instead of raising the letter.

      This face's own openings do not count, though, and that is the other
      half of it: a patch is a piece of somebody else's surface.  What has
      been cut out of this one belongs to it, and the plugs filling those
      cutouts are its tenants rather than its neighbors.  The screen of the
      toy has the whole robot cut into it and is still the entire floor of
      its recess. }
    A := FEnts[Index].Poly;
    N := Length(A);
    for RB := 0 to Length(FEnts[I].Holes) do
    begin
      if RB = 0 then B := FEnts[I].Poly else B := FEnts[I].Holes[RB - 1];
      M := Length(B);
      if M < 3 then Continue;
      for Q := 0 to N - 1 do
        for K := 0 to M - 1 do
          if ((Dist(A[Q], B[K]) < TOL) and
              (Dist(A[(Q + 1) mod N], B[(K + 1) mod M]) < TOL)) or
             ((Dist(A[Q], B[(K + 1) mod M]) < TOL) and
              (Dist(A[(Q + 1) mod N], B[K]) < TOL)) then
            Exit(True);
    end;
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
  I, J, K, N, G: Integer;
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
    { What is cut out of a face travels with it.  The logo is holes in the
      top of the toy with the letters plugged into them; sliding the top
      moved the panel and left all fourteen openings behind at the old
      height, which tore the solid open along every letter. }
    for J := 0 to High(FEnts[I].Holes) do
      for K := 0 to High(FEnts[I].Holes[J]) do
        Shift(FEnts[I].Holes[J][K]);
  end;
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
end;

{ Which faces are held up by these edges.

  SketchUp's rule, and the one somebody rubbing out lines is relying on:
  "the Eraser tool doesn't allow you to erase faces.  Technically, faces are
  erased when you erase their bounding edges, opening and reshaping your
  geometry."  A face is not a thing that sits there; it is what a closed run
  of edges encloses, and taking one of those edges away takes it with them.

  Loose faces got this for free - they are thrown away and worked out again
  from the edges every time anything changes - and a built solid's faces
  never did, because a solid's faces are kept as they were made.  So rubbing
  an edge off a box left the box's six sides standing with nothing holding
  one of them up.

  From a note, 15 September: "in SketchUp I don't think you can even have a filled
  face unless it is enclosed by lines.  So when I am erasing lines on a cube
  it will leave behind faces and I think that is wrong."

  Asked of the edges being rubbed out rather than of every face in the
  drawing, and that is deliberate.  A face that never had edges under it -
  the lettering in the old example is a hundred of them - is not using the
  edge you just rubbed out, so it is not in this.  Auditing the whole
  drawing instead would take those with it the first time anybody erased
  anything, which is a different program's answer to a different question. }
function SharesRun(const P1, Q1, P2, Q2: TP3): Boolean;
const
  TOL = 1E-6;
var
  U, W, F: TP3;
  L, TA, TB, Off, Lo, Hi: Double;
begin
  Result := False;
  L := Dist(P1, Q1);
  if L < TOL then Exit;
  U := P3((Q1.X - P1.X) / L, (Q1.Y - P1.Y) / L, (Q1.Z - P1.Z) / L);

  W := P3(P2.X - P1.X, P2.Y - P1.Y, P2.Z - P1.Z);
  TA := Dot3(W, U);
  F := P3(W.X - U.X * TA, W.Y - U.Y * TA, W.Z - U.Z * TA);
  Off := Sqrt(F.X * F.X + F.Y * F.Y + F.Z * F.Z);
  if Off > TOL then Exit;

  W := P3(Q2.X - P1.X, Q2.Y - P1.Y, Q2.Z - P1.Z);
  TB := Dot3(W, U);
  F := P3(W.X - U.X * TB, W.Y - U.Y * TB, W.Z - U.Z * TB);
  Off := Sqrt(F.X * F.X + F.Y * F.Y + F.Z * F.Z);
  if Off > TOL then Exit;

  Lo := Max(0, Min(TA, TB));
  Hi := Min(L, Max(TA, TB));
  Result := Hi - Lo > TOL;
end;

{ A guide point belongs to the guide line it was laid with.

  The tape leaves both in one gesture, and they answer two halves of one
  question: the dashed line says where the offset is, the point says where
  along it the measurement actually landed.  Rubbing out the line and leaving
  the point behind leaves a mark nobody can read.

  From a note, 15 September: "i was erasing the dashed guidlines and it would leave
  behind the yellow guide points... those yellow guide points should have
  erased with their related guidelines anyway."

  Worked out from where they are rather than from a note made when they were
  laid, so it is right for drawings made before this and for a point that has
  found its way onto a line some other way.  A point on two lines goes with
  whichever is rubbed out first, which is the answer somebody would expect
  and not worth a field in the file to improve on. }
function TWorkDoc.PointsOnGuides(const Idx: array of Integer;
  out Pts: TIntArrayW): Integer;
const
  TOL = 1E-6;
var
  I, J, K, N: Integer;
  Marked: array of Boolean;
  Lines: array of Integer;

  function OnOne(const P: TP3): Boolean;
  var
    M: Integer;
    A, B, W, U, F: TP3;
    L, T, Off: Double;
  begin
    Result := True;
    for M := 0 to N - 1 do
    begin
      A := FEnts[Lines[M]].A;
      B := FEnts[Lines[M]].B;
      L := Dist(A, B);
      if L < TOL then Continue;
      U := P3((B.X - A.X) / L, (B.Y - A.Y) / L, (B.Z - A.Z) / L);
      W := P3(P.X - A.X, P.Y - A.Y, P.Z - A.Z);
      T := Dot3(W, U);
      if (T < -TOL) or (T > L + TOL) then Continue;
      F := P3(W.X - U.X * T, W.Y - U.Y * T, W.Z - U.Z * T);
      Off := Sqrt(F.X * F.X + F.Y * F.Y + F.Z * F.Z);
      if Off <= TOL then Exit;
    end;
    Result := False;
  end;

begin
  Pts := nil;
  Result := 0;
  N := 0;
  SetLength(Lines, Length(Idx));
  for I := 0 to High(Idx) do
  begin
    J := Idx[I];
    if (J < 0) or (J >= FLive) then Continue;
    if (FEnts[J].Kind = ekGuide) and (Dist(FEnts[J].A, FEnts[J].B) > TOL) then
    begin
      Lines[N] := J;
      Inc(N);
    end;
  end;
  if N = 0 then Exit;

  SetLength(Marked, FLive);
  for I := 0 to FLive - 1 do Marked[I] := False;
  for I := 0 to High(Idx) do
    if (Idx[I] >= 0) and (Idx[I] < FLive) then Marked[Idx[I]] := True;

  for K := 0 to FLive - 1 do
  begin
    if Marked[K] or (FEnts[K].Kind <> ekGuide) then Continue;
    if Dist(FEnts[K].A, FEnts[K].B) > TOL then Continue;
    if not OnOne(FEnts[K].A) then Continue;
    SetLength(Pts, Result + 1);
    Pts[Result] := K;
    Inc(Result);
  end;
end;

function TWorkDoc.FacesOnEdges(const Idx: array of Integer;
  out Faces: TIntArrayW): Integer;
const
  TOL = 1E-6;
type
  TRun = record A, B: TP3; end;
var
  Runs: array of TRun;
  NR, I, J, K, H, Steps: Integer;
  Ang: Double;
  P, Q: TP3;
  Marked: array of Boolean;

  procedure PutRun(const A, B: TP3);
  begin
    if Dist(A, B) < TOL then Exit;
    if NR >= Length(Runs) then SetLength(Runs, Max(16, NR * 2));
    Runs[NR].A := A; Runs[NR].B := B;
    Inc(NR);
  end;

  function UsesARun(const A, B: TP3): Boolean;
  var
    M: Integer;
  begin
    Result := True;
    for M := 0 to NR - 1 do
      if SharesRun(A, B, Runs[M].A, Runs[M].B) then Exit;
    Result := False;
  end;

begin
  Faces := nil;
  Result := 0;
  NR := 0;

  { every run that is about to go, arcs walked as they are drawn }
  for I := 0 to High(Idx) do
  begin
    J := Idx[I];
    if (J < 0) or (J >= FLive) then Continue;
    case FEnts[J].Kind of
      ekLine: if not FEnts[J].Dim then PutRun(FEnts[J].A, FEnts[J].B);
      ekArc:
        begin
          Steps := ArcSteps(FEnts[J]);
          for K := 0 to Steps - 1 do
          begin
            Ang := FEnts[J].A0 + FEnts[J].Sweep * K / Steps;
            P := ArcPoint(FEnts[J].C, FEnts[J].R, Ang, FEnts[J].Plane, FEnts[J].Nm);
            Ang := FEnts[J].A0 + FEnts[J].Sweep * (K + 1) / Steps;
            Q := ArcPoint(FEnts[J].C, FEnts[J].R, Ang, FEnts[J].Plane, FEnts[J].Nm);
            PutRun(P, Q);
          end;
        end;
    end;
  end;
  if NR = 0 then Exit;

  SetLength(Marked, FLive);
  for I := 0 to FLive - 1 do Marked[I] := False;
  for I := 0 to High(Idx) do
    if (Idx[I] >= 0) and (Idx[I] < FLive) then Marked[Idx[I]] := True;

  for I := 0 to FLive - 1 do
  begin
    if Marked[I] or (FEnts[I].Kind <> ekFace) then Continue;
    if Length(FEnts[I].Poly) < 3 then Continue;
    for K := 0 to High(FEnts[I].Poly) do
    begin
      P := FEnts[I].Poly[K];
      Q := FEnts[I].Poly[(K + 1) mod Length(FEnts[I].Poly)];
      if UsesARun(P, Q) then
      begin
        Marked[I] := True;
        Break;
      end;
    end;
    { the edge round an opening holds the face up just as much as the edge
      round the outside: rub out one side of a window and the wall it is cut
      in is no longer a closed shape either }
    if not Marked[I] then
      for H := 0 to High(FEnts[I].Holes) do
      begin
        for K := 0 to High(FEnts[I].Holes[H]) do
        begin
          P := FEnts[I].Holes[H][K];
          Q := FEnts[I].Holes[H][(K + 1) mod Length(FEnts[I].Holes[H])];
          if UsesARun(P, Q) then
          begin
            Marked[I] := True;
            Break;
          end;
        end;
        if Marked[I] then Break;
      end;
    if Marked[I] then
    begin
      SetLength(Faces, Result + 1);
      Faces[Result] := I;
      Inc(Result);
    end;
  end;
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

{ The edges that lean over to follow a move, worked out the same way the
  move itself works them out: a corner that sits where a moving corner sits
  is a moving corner.

  From a note, 15 September, moving one side of a rectangle drawn inside another:
  "the issue is that line of the smaller inner rectangle is not staying
  snapped".  It was staying snapped - the two sides it joins shrank to
  follow, which is what SketchUp does and what MoveVerts has always done.
  What did not stay snapped was the picture: the ghost showed the one side
  flying off on its own and said nothing about the two that were coming with
  it, so the tool looked like it was tearing the rectangle open. }
procedure TWorkDoc.StretchPreview(const Pts: TP3Array; const D: TP3;
  const Skip: array of Integer; out Segs: TP3Array);
const
  TOL = 1E-7;
var
  Moving: TPointSet;
  I, J, N: Integer;
  Held, MA, MB: Boolean;
  A, B: TP3;

  function Shifted(const P: TP3; out Moved: Boolean): TP3;
  begin
    Moved := Moving.Has(P, TOL);
    if Moved then
      Result := P3(P.X + D.X, P.Y + D.Y, P.Z + D.Z)
    else
      Result := P;
  end;

begin
  Segs := nil;
  N := 0;
  if Length(Pts) = 0 then Exit;
  Moving := TPointSet.Create(Pts);
  try
    for I := 0 to FLive - 1 do
    begin
      if not (FEnts[I].Kind in [ekLine, ekGuide]) then Continue;
      if FEnts[I].Dim then Continue;
      Held := False;
      for J := 0 to High(Skip) do
        if Skip[J] = I then
        begin
          Held := True;
          Break;
        end;
      if Held then Continue;
      A := Shifted(FEnts[I].A, MA);
      B := Shifted(FEnts[I].B, MB);
      { one end moving and one staying is a stretch, and that is the whole
        of what wants showing.  Both ends moving means the edge travels
        whole - the ghost of the selection already draws that - and neither
        means it is not in this at all. }
      if MA = MB then Continue;
      if N + 2 > Length(Segs) then SetLength(Segs, Max(16, (N + 2) * 2));
      Segs[N] := A; Segs[N + 1] := B;
      Inc(N, 2);
    end;
  finally
    Moving.Free;
  end;
  SetLength(Segs, N);
end;

procedure TWorkDoc.MoveVerts(const Pts: TP3Array; const D: TP3);
const
  TOL = 1E-7;
var
  I, J, K, H, NR: Integer;
  Moving: TPointSet;
  Ride: array of Integer;
  RideA: array of Boolean;

  procedure Shift(var P: TP3);
  begin
    if Moving.Has(P, TOL) then P := P3(P.X + D.X, P.Y + D.Y, P.Z + D.Z);
  end;

  procedure Bump(var P: TP3);
  begin
    P := P3(P.X + D.X, P.Y + D.Y, P.Z + D.Z);
  end;

  { is Q on the segment from E to F, within a hair }
  function OnSeg(const Q, E, F: TP3): Boolean;
  var
    L2, T: Double;
    R: TP3;
  begin
    L2 := Sqr(F.X - E.X) + Sqr(F.Y - E.Y) + Sqr(F.Z - E.Z);
    if L2 < 1E-18 then Exit(Dist(Q, E) < 1E-6);
    T := ((Q.X - E.X) * (F.X - E.X) + (Q.Y - E.Y) * (F.Y - E.Y) +
          (Q.Z - E.Z) * (F.Z - E.Z)) / L2;
    if (T < -1E-6) or (T > 1 + 1E-6) then Exit(False);
    R := P3(E.X + (F.X - E.X) * T, E.Y + (F.Y - E.Y) * T,
            E.Z + (F.Z - E.Z) * T);
    Result := Dist(Q, R) < 1E-6;
  end;

begin
  if Length(Pts) = 0 then Exit;
  Moving := TPointSet.Create(Pts);
  try
  { A note points at a place rather than at a thing, so moving the edge it
    points at used to leave the leader behind, aimed at where the edge used
    to be.  Remembering which entity a note is tied to is the thorough answer
    and wants a field in the file; this is the cheap nine-tenths of it - if
    the whole of a line is moving, whatever sits on that line is moving too.

    Worked out before anything shifts, because afterwards the note and the
    line have both changed and there is no telling what was on what. }
  NR := 0;
  SetLength(Ride, 0);
  SetLength(RideA, 0);
  for I := 0 to FLive - 1 do
  begin
    if FEnts[I].Part <> FContext then Continue;
    if FEnts[I].Kind <> ekText then Continue;
    if Moving.Has(FEnts[I].B, TOL) then Continue;      { going anyway }
    if Dist(FEnts[I].A, FEnts[I].B) < 1E-9 then Continue;  { no leader }
    for J := 0 to FLive - 1 do
    begin
      if not (FEnts[J].Kind in [ekLine, ekArc]) then Continue;
      if FEnts[J].Part <> FContext then Continue;
      if not (Moving.Has(FEnts[J].A, TOL) and
              Moving.Has(FEnts[J].B, TOL)) then Continue;
      if OnSeg(FEnts[I].B, FEnts[J].A, FEnts[J].B) then
      begin
        SetLength(Ride, NR + 1);
        SetLength(RideA, NR + 1);
        Ride[NR] := I;
        { the words travel with the arrow unless they are already on
          something that is moving, which would carry them twice }
        RideA[NR] := not Moving.Has(FEnts[I].A, TOL);
        Inc(NR);
        Break;
      end;
    end;
  end;

  for I := 0 to FLive - 1 do
  begin
    if FEnts[I].Part <> FContext then Continue;
    Shift(FEnts[I].A);
    Shift(FEnts[I].B);
    if FEnts[I].Kind = ekArc then Shift(FEnts[I].C);
    for K := 0 to High(FEnts[I].Poly) do
      Shift(FEnts[I].Poly[K]);
    for H := 0 to High(FEnts[I].Holes) do
      for K := 0 to High(FEnts[I].Holes[H]) do
        Shift(FEnts[I].Holes[H][K]);
  end;

  for I := 0 to NR - 1 do
  begin
    Bump(FEnts[Ride[I]].B);
    if RideA[I] then Bump(FEnts[Ride[I]].A);
  end;
  finally
    Moving.Free;
  end;
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
end;

procedure TWorkDoc.VertsBeyond(const Base, Dir: TP3; out Pts: TP3Array);
const
  TOL = 1E-7;
var
  I, K, H, N: Integer;

  procedure Put(const P: TP3);
  begin
    if Dot3(P3(P.X - Base.X, P.Y - Base.Y, P.Z - Base.Z), Dir) < -TOL then Exit;
    if N >= Length(Pts) then SetLength(Pts, Max(16, N * 2));
    Pts[N] := P;
    Inc(N);
  end;

begin
  Pts := nil;
  N := 0;
  for I := 0 to FLive - 1 do
  begin
    Put(FEnts[I].A);
    Put(FEnts[I].B);
    if FEnts[I].Kind = ekArc then Put(FEnts[I].C);
    for K := 0 to High(FEnts[I].Poly) do Put(FEnts[I].Poly[K]);
    for H := 0 to High(FEnts[I].Holes) do
      for K := 0 to High(FEnts[I].Holes[H]) do Put(FEnts[I].Holes[H][K]);
  end;
  SetLength(Pts, N);
end;

{ What an axis will do to an outline, before it does it.

  A solid of revolution is an outline spun about a line **beside** it.  Put
  the line through the middle of the outline and the two halves sweep into
  each other, and what comes out is a knot with no outside.  That is what
  went wrong for the owner on 13 September: his outline ran from Y 2094 to Y 2249
  and he put the axis at Y 2206, seventy per cent of the way up it, and the
  only way to find out was to do it and look at the result.

  So: which side of the axis each corner falls, measured in the outline's own
  plane, and how far out the nearest and furthest corners are.  Corners on
  both sides means the axis splits it.  Corners exactly on it count for
  neither, which is the ordinary case - one side of a glass outline is the
  axis. }
function TWorkDoc.AxisSplitsFace(Face: Integer; const AxisP, AxisDir: TP3;
  out RLo, RHi: Double): Boolean;
var
  K: Integer;
  Nf, D, E, Perp: TP3;
  S, R: Double;
  Pos, Neg: Boolean;
begin
  Result := False;
  RLo := 0;
  RHi := 0;
  if (Face < 0) or (Face >= FLive) or (FEnts[Face].Kind <> ekFace) then Exit;
  if Length(FEnts[Face].Poly) < 3 then Exit;
  D := Norm3(AxisDir);
  if Dist(D, P3(0, 0, 0)) < 1E-9 then Exit;
  Nf := Norm3(FaceNormal(Face));
  Pos := False;
  Neg := False;
  RLo := 1E30;
  RHi := 0;
  for K := 0 to High(FEnts[Face].Poly) do
  begin
    E := P3(FEnts[Face].Poly[K].X - AxisP.X, FEnts[Face].Poly[K].Y - AxisP.Y,
            FEnts[Face].Poly[K].Z - AxisP.Z);
    { how far off the axis, square to it - the radius this corner sweeps }
    Perp := P3(E.X - D.X * Dot3(E, D), E.Y - D.Y * Dot3(E, D),
               E.Z - D.Z * Dot3(E, D));
    R := Dist(Perp, P3(0, 0, 0));
    if R < RLo then RLo := R;
    if R > RHi then RHi := R;
    { and which side of it, in the plane the outline lies in }
    S := Dot3(Cross3(D, E), Nf);
    if S > 1E-6 then Pos := True
    else if S < -1E-6 then Neg := True;
  end;
  if RLo > RHi then RLo := RHi;
  Result := Pos and Neg;
end;

{ A dimension told what it ought to read, and the drawing moved to suit.

  This is the thing people ask SketchUp for and never get: over there you
  measure after you draw, and a wrong number means drawing it again.  It is
  what FreeCAD spends a constraint solver on, and the solver is the reason
  people bounce off FreeCAD - along with the topological naming problem that
  comes with remembering relationships between things that get renumbered.

  So this remembers nothing.  It is not a constraint, it is **an edit**: work
  out how much longer the dimension has to be, move that much, and forget.
  Nothing can end up over-constrained because nothing is constrained; nothing
  can go stale because nothing is stored; the same rule works on a drawing
  read out of a file that has never been seen before.  It gives up the part
  of parametric modeling that keeps a shape correct while you change
  something else, and keeps the part people actually asked for, which is
  typing a number and having the size be that number.

  What moves: everything from that end of the dimension outwards - every
  point at or past the plane through the end, square to the run.  Draw a
  rectangle, dimension the bottom, type a bigger number and both right-hand
  corners go, so it is still a rectangle.  Anything between the two ends
  stays where it is, which is what you want for a window in a wall and is
  worth knowing before you resize something with a lot in the middle.

  An arc whose center and both ends are all past the plane travels whole.
  One with only some of its points past it will come out wrong - the same
  limit the move tool has always had when a selection cuts an arc in half. }
function TWorkDoc.ResizeDim(Index: Integer; NewLen: Double;
  MoveB: Boolean): Boolean;
var
  A, B, D, Delta: TP3;
  L, Grow: Double;
  Pts: TP3Array;
begin
  Result := False;
  if (Index < 0) or (Index >= FLive) then Exit;
  if FEnts[Index].Kind <> ekDim then Exit;
  if NewLen <= 0 then Exit;
  A := FEnts[Index].A;
  B := FEnts[Index].B;
  L := Dist(A, B);
  { a dimension of no length has no direction to grow along }
  if L < 1E-9 then Exit;
  Grow := NewLen - L;
  if Abs(Grow) < 1E-9 then Exit;
  D := P3((B.X - A.X) / L, (B.Y - A.Y) / L, (B.Z - A.Z) / L);

  if MoveB then
  begin
    VertsBeyond(B, D, Pts);
    Delta := P3(D.X * Grow, D.Y * Grow, D.Z * Grow);
  end
  else
  begin
    VertsBeyond(A, P3(-D.X, -D.Y, -D.Z), Pts);
    Delta := P3(-D.X * Grow, -D.Y * Grow, -D.Z * Grow);
  end;
  if Length(Pts) = 0 then Exit;
  MoveVerts(Pts, Delta);
  Result := True;
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
  { a dimension's C is the offset from what it measures to where its line
    sits - a direction, not a place - so it turns with the dimension but is
    not swung round the center }
  if (FEnts[I].Kind = ekDim) and (OnSet(FEnts[I].A) or OnSet(FEnts[I].B)) then
    FEnts[I].C := RotV(FEnts[I].C, Axis, Ang);
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
    if FEnts[I].Part = FContext then       { another group's corners stay put }
      RotateEnt(I, Pts, C, Axis, Ang, False);
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
end;

procedure TWorkDoc.ArrayMove(const Src: array of Integer; const D: TP3; N: Integer;
  Divide: Boolean; out Made: TIntArrayW);
var
  K, I, Base, M: Integer;
  F: Double;
begin
  Made := nil;
  if (N < 1) or (Length(Src) = 0) then Exit;
  for K := 1 to N do
  begin
    if Divide then F := K / N else F := K;
    Base := FLive;
    Duplicate(Src, P3(D.X * F, D.Y * F, D.Z * F));
    M := Length(Made);
    SetLength(Made, M + (FLive - Base));
    for I := Base to FLive - 1 do Made[M + I - Base] := I;
  end;
end;

procedure TWorkDoc.ArrayRotate(const Src: array of Integer; const C, Axis: TP3;
  Ang: Double; N: Integer; Divide: Boolean; out Made: TIntArrayW);
var
  K, I, Base, M: Integer;
  F: Double;
  Fresh: TIntArrayW;
begin
  Made := nil;
  if (N < 1) or (Length(Src) = 0) then Exit;
  for K := 1 to N do
  begin
    if Divide then F := K / N else F := K;
    Base := FLive;
    Duplicate(Src, P3(0, 0, 0));
    SetLength(Fresh, FLive - Base);
    for I := 0 to High(Fresh) do Fresh[I] := Base + I;
    RotateEnts(Fresh, C, Axis, Ang * F);
    M := Length(Made);
    SetLength(Made, M + Length(Fresh));
    for I := 0 to High(Fresh) do Made[M + I] := Fresh[I];
  end;
end;

function TWorkDoc.MiddleOf(const Idx: array of Integer; out Mid: TP3): Boolean;
var
  Lo, Hi: TP3;
begin
  Result := SpanOf(Idx, Lo, Hi);
  if Result then
    Mid := P3((Lo.X + Hi.X) / 2, (Lo.Y + Hi.Y) / 2, (Lo.Z + Hi.Z) / 2)
  else
    Mid := P3(0, 0, 0);
end;

function TWorkDoc.SpanOf(const Idx: array of Integer; out Lo, Hi: TP3): Boolean;
var
  I, J, K: Integer;
  Any: Boolean;

  procedure Grow(const P: TP3);
  begin
    if not Any then
    begin
      Lo := P;
      Hi := P;
      Any := True;
      Exit;
    end;
    Lo.X := Min(Lo.X, P.X); Lo.Y := Min(Lo.Y, P.Y); Lo.Z := Min(Lo.Z, P.Z);
    Hi.X := Max(Hi.X, P.X); Hi.Y := Max(Hi.Y, P.Y); Hi.Z := Max(Hi.Z, P.Z);
  end;

  procedure Take(I: Integer);
  var
    M: Integer;
  begin
    if (I < 0) or (I >= FLive) then Exit;
    case FEnts[I].Kind of
      ekArc:
        begin
          Grow(P3(FEnts[I].C.X - FEnts[I].R, FEnts[I].C.Y - FEnts[I].R,
                  FEnts[I].C.Z - FEnts[I].R));
          Grow(P3(FEnts[I].C.X + FEnts[I].R, FEnts[I].C.Y + FEnts[I].R,
                  FEnts[I].C.Z + FEnts[I].R));
        end;
      ekFace:
        for M := 0 to High(FEnts[I].Poly) do Grow(FEnts[I].Poly[M]);
    else
      Grow(FEnts[I].A);
      Grow(FEnts[I].B);
    end;
  end;

begin
  Any := False;
  Lo := P3(0, 0, 0);
  Hi := P3(0, 0, 0);
  if Length(Idx) > 0 then
    for J := 0 to High(Idx) do Take(Idx[J])
  else
    for K := 0 to FLive - 1 do Take(K);
  Result := Any;
end;

procedure TWorkDoc.TranslateEnts(const Idx: array of Integer; const D: TP3);
var
  J, I, K, H: Integer;

  function Sh(const P: TP3): TP3;
  begin
    Result := P3(P.X + D.X, P.Y + D.Y, P.Z + D.Z);
  end;

begin
  for J := 0 to High(Idx) do
  begin
    I := Idx[J];
    if (I < 0) or (I >= FLive) then Continue;
    FEnts[I].A := Sh(FEnts[I].A);
    FEnts[I].B := Sh(FEnts[I].B);
    { an arc's C is its center, a point; a dimension's C is the offset from
      what it measures to where its line sits, a vector, which a move must
      leave alone or the line runs off by the whole distance moved }
    if FEnts[I].Kind = ekArc then FEnts[I].C := Sh(FEnts[I].C);
    for K := 0 to High(FEnts[I].Poly) do FEnts[I].Poly[K] := Sh(FEnts[I].Poly[K]);
    for H := 0 to High(FEnts[I].Holes) do
      for K := 0 to High(FEnts[I].Holes[H]) do FEnts[I].Holes[H][K] := Sh(FEnts[I].Holes[H][K]);
  end;
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
end;

procedure TWorkDoc.RotateEnts(const Idx: array of Integer; const C, Axis: TP3; Ang: Double);
var
  J: Integer;
begin
  for J := 0 to High(Idx) do
    if (Idx[J] >= 0) and (Idx[J] < FLive) then
      RotateEnt(Idx[J], nil, C, Axis, Ang, True);
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
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
  J, I, K, H, Base, G: Integer;
  Src, Dst: array of Integer;    { old group id -> the new one it becomes }
  PSrc, PDst, Copied: array of Integer;   { the same for groups }

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

  { And the groups, the same way and for the same reason: a copy of a group
    is a group of its own.  Only groups whose record is among what is being
    copied get a new id - a member copied without its record stays in the
    group it was in, beside the original. }
  function RemapPart(Old: Integer): Integer;
  var
    N: Integer;
    Known: Boolean;
  begin
    if Old = 0 then Exit(0);
    for N := 0 to High(PSrc) do
      if PSrc[N] = Old then Exit(PDst[N]);
    Known := False;
    for N := 0 to High(Copied) do
      if Copied[N] = Old then Known := True;
    if not Known then Exit(Old);
    Inc(FNextPart);
    SetLength(PSrc, Length(PSrc) + 1);
    SetLength(PDst, Length(PDst) + 1);
    PSrc[High(PSrc)] := Old;
    PDst[High(PDst)] := FNextPart;
    Result := FNextPart;
  end;

begin
  Src := nil;
  Dst := nil;
  PSrc := nil;
  PDst := nil;
  Copied := nil;
  Base := FLive;
  for J := 0 to High(Idx) do
    if (Idx[J] >= 0) and (Idx[J] < Base) and (FEnts[Idx[J]].Kind = ekPart) then
    begin
      SetLength(Copied, Length(Copied) + 1);
      Copied[High(Copied)] := FEnts[Idx[J]].Grp;
    end;
  for J := 0 to High(Idx) do
  begin
    I := Idx[J];
    if (I < 0) or (I >= Base) then Continue;
    Room;
    Finalize(FEnts[FLive]);
    FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
    FEnts[FLive] := FEnts[I];
    SetLength(FEnts[FLive].Poly, Length(FEnts[I].Poly));
    for K := 0 to High(FEnts[I].Poly) do
      FEnts[FLive].Poly[K] := P3(FEnts[I].Poly[K].X + D.X,
        FEnts[I].Poly[K].Y + D.Y, FEnts[I].Poly[K].Z + D.Z);
    { And the openings, which this shared with the original and left where
      they were: a copy of a face with a window in it had the window at the
      first one's position, in the first one's array, so moving either moved
      both.  The same crack as the one CopyEnt had - see the note there. }
    FEnts[FLive].Holes := nil;
    SetLength(FEnts[FLive].Holes, Length(FEnts[I].Holes));
    for H := 0 to High(FEnts[I].Holes) do
    begin
      SetLength(FEnts[FLive].Holes[H], Length(FEnts[I].Holes[H]));
      for K := 0 to High(FEnts[I].Holes[H]) do
        FEnts[FLive].Holes[H][K] := P3(FEnts[I].Holes[H][K].X + D.X,
          FEnts[I].Holes[H][K].Y + D.Y, FEnts[I].Holes[H][K].Z + D.Z);
    end;
    FEnts[FLive].A := P3(FEnts[I].A.X + D.X, FEnts[I].A.Y + D.Y, FEnts[I].A.Z + D.Z);
    FEnts[FLive].B := P3(FEnts[I].B.X + D.X, FEnts[I].B.Y + D.Y, FEnts[I].B.Z + D.Z);
    FEnts[FLive].C := P3(FEnts[I].C.X + D.X, FEnts[I].C.Y + D.Y, FEnts[I].C.Z + D.Z);
    { a record's Grp is its group id, not a solid's }
    if FEnts[I].Kind = ekPart then G := RemapPart(FEnts[I].Grp)
    else G := Remap(FEnts[I].Grp);
    FEnts[FLive].Grp := G;
    FEnts[FLive].Part := RemapPart(FEnts[I].Part);
    Inc(FLive);
  end;
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
end;

{ Take a copy of these entities out of the document.

  Deep, and with nothing pointing back at the document it came from - which
  is the whole requirement, because the copy has to outlive a switch to
  another sheet and be pasted into a different TWorkDoc entirely.  CopyEnt is
  already the deep one; this is a list of them. }
function TWorkDoc.CopyOut(const Idx: array of Integer): TWorkEntArray;
var
  J, I, N: Integer;
begin
  Result := nil;
  SetLength(Result, Length(Idx));
  N := 0;
  for J := 0 to High(Idx) do
  begin
    I := Idx[J];
    if (I < 0) or (I >= FLive) then Continue;
    Result[N] := CopyEnt(FEnts[I]);
    Inc(N);
  end;
  SetLength(Result, N);
end;

{ Put a copy back in, offset by D, and say which ones went in.

  The group ids are remapped for the reason Duplicate remaps them: solids are
  told apart by their group, and a pasted box carrying the original's id
  would be the same solid as far as push/pull is concerned - pull a face on
  one and the other deforms.  Pasting into a different sheet needs it just as
  much, because the two sheets number their groups from one each.

  Bores are dropped.  An ekBore is the record of a tunnel through a
  particular solid, kept so the next tunnel knows where the last one went; it
  means nothing beside a copy of that solid and nothing at all on another
  sheet. }
function TWorkDoc.PasteIn(const Ents: TWorkEntArray; const D: TP3;
  out First, Last: Integer): Integer;
var
  J, K, H: Integer;
  Src, Dst: array of Integer;
  PSrc, PDst, Copied: array of Integer;   { the same for groups - see Duplicate }

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

  function RemapPart(Old: Integer): Integer;
  var
    N: Integer;
    Known: Boolean;
  begin
    if Old = 0 then Exit(0);
    for N := 0 to High(PSrc) do
      if PSrc[N] = Old then Exit(PDst[N]);
    Known := False;
    for N := 0 to High(Copied) do
      if Copied[N] = Old then Known := True;
    { pasted into a sheet that has no such group, a member goes in loose }
    if not Known then
      if PartEnt(Old) >= 0 then Exit(Old) else Exit(0);
    Inc(FNextPart);
    SetLength(PSrc, Length(PSrc) + 1);
    SetLength(PDst, Length(PDst) + 1);
    PSrc[High(PSrc)] := Old;
    PDst[High(PDst)] := FNextPart;
    Result := FNextPart;
  end;

  procedure Shift(var P: TP3);
  begin
    P := P3(P.X + D.X, P.Y + D.Y, P.Z + D.Z);
  end;

begin
  Result := 0;
  First := FLive;
  Last := FLive - 1;
  Src := nil;
  Dst := nil;
  PSrc := nil;
  PDst := nil;
  Copied := nil;
  for J := 0 to High(Ents) do
    if Ents[J].Kind = ekPart then
    begin
      SetLength(Copied, Length(Copied) + 1);
      Copied[High(Copied)] := Ents[J].Grp;
    end;
  for J := 0 to High(Ents) do
  begin
    if Ents[J].Kind = ekBore then Continue;
    Room;
    Finalize(FEnts[FLive]);
    FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
    FEnts[FLive] := CopyEnt(Ents[J]);
    Shift(FEnts[FLive].A);
    Shift(FEnts[FLive].B);
    Shift(FEnts[FLive].C);
    for K := 0 to High(FEnts[FLive].Poly) do Shift(FEnts[FLive].Poly[K]);
    for H := 0 to High(FEnts[FLive].Holes) do
      for K := 0 to High(FEnts[FLive].Holes[H]) do Shift(FEnts[FLive].Holes[H][K]);
    if Ents[J].Kind = ekPart then FEnts[FLive].Grp := RemapPart(Ents[J].Grp)
    else FEnts[FLive].Grp := Remap(Ents[J].Grp);
    { into the open group here, unless it came with a group of its own }
    if Ents[J].Part = 0 then FEnts[FLive].Part := FStamp
    else FEnts[FLive].Part := RemapPart(Ents[J].Part);
    Last := FLive;
    Inc(FLive);
    Inc(Result);
  end;
  if Result > 0 then
  begin
    FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
  end;
end;

{ Two screen segments, do they cross?  Used by the selection box. }
function SegsCross(AX, AY, BX, BY, CX, CY, DX_, DY_: Double): Boolean;
var
  R1, R2, R3, R4: Double;

  function Side(PX, PY, QX, QY, RX, RY: Double): Double;
  begin
    Result := (QX - PX) * (RY - PY) - (QY - PY) * (RX - PX);
  end;

begin
  R1 := Side(AX, AY, BX, BY, CX, CY);
  R2 := Side(AX, AY, BX, BY, DX_, DY_);
  R3 := Side(CX, CY, DX_, DY_, AX, AY);
  R4 := Side(CX, CY, DX_, DY_, BX, BY);
  Result := (((R1 > 0) <> (R2 > 0)) and ((R3 > 0) <> (R4 > 0)));
end;

{ Does this screen segment meet the box at all? }
function SegHitsRect(AX, AY, BX, BY, X0, Y0, X1, Y1: Double): Boolean;
begin
  { an end inside is the common case and answers without any arithmetic }
  if ((AX >= X0) and (AX <= X1) and (AY >= Y0) and (AY <= Y1)) or
     ((BX >= X0) and (BX <= X1) and (BY >= Y0) and (BY <= Y1)) then
    Exit(True);
  { wholly off one side }
  if (Max(AX, BX) < X0) or (Min(AX, BX) > X1) or
     (Max(AY, BY) < Y0) or (Min(AY, BY) > Y1) then
    Exit(False);
  Result := SegsCross(AX, AY, BX, BY, X0, Y0, X1, Y0) or
            SegsCross(AX, AY, BX, BY, X1, Y0, X1, Y1) or
            SegsCross(AX, AY, BX, BY, X1, Y1, X0, Y1) or
            SegsCross(AX, AY, BX, BY, X0, Y1, X0, Y0);
end;

{ Is this screen point inside the projected loop?  Even-odd, the same rule
  the face fill uses. }
function LoopHasPt(const Pts: array of TPointF; SX, SY: Double): Boolean;
var
  I, J: Integer;
begin
  Result := False;
  J := High(Pts);
  for I := 0 to High(Pts) do
  begin
    if ((Pts[I].Y > SY) <> (Pts[J].Y > SY)) and
       (SX < (Pts[J].X - Pts[I].X) * (SY - Pts[I].Y) /
             (Pts[J].Y - Pts[I].Y) + Pts[I].X) then
      Result := not Result;
    J := I;
  end;
end;

{ Guides come along only when the box caught nothing else.  A box dragged
  round a shape is after the shape, and a guide is not part of the drawing -
  but one runs through almost any box, so it was taken every time.  The owner, 16
  September: "THE GUIDES SHOULD NEVER BE SELECTED LIKE THIS! guides are not
  part of a drawing!"  A box round nothing but guides is plainly after them,
  so that still works. }
function TWorkDoc.BoxPick(const V: TProjector; X0, Y0, X1, Y1: Double;
  Crossing: Boolean): TIntArrayW;
var
  I, N, G: Integer;
  Guides: TIntArrayW;
begin
  Result := nil;
  Guides := nil;
  N := 0;
  G := 0;
  for I := 0 to FLive - 1 do
    if BoxTakes(V, I, X0, Y0, X1, Y1, Crossing) then
    begin
      if FEnts[I].Kind = ekGuide then
      begin
        if G >= Length(Guides) then SetLength(Guides, Max(16, G * 2));
        Guides[G] := I;
        Inc(G);
      end
      else
      begin
        if N >= Length(Result) then SetLength(Result, Max(64, N * 2));
        Result[N] := I;
        Inc(N);
      end;
    end;
  if N > 0 then
    SetLength(Result, N)
  else
  begin
    SetLength(Guides, G);
    Result := Guides;
  end;
end;

{ Does a box dragged over the screen take this thing?

  A containing box - dragged left to right - takes what lies wholly inside
  it, and for that the box around a thing is the same question as the thing
  itself, so the bounds are the right test and they stay.

  A crossing box - dragged right to left - takes whatever it touches, and
  there the bounds were wrong.  The bounds of a line from one corner of the
  screen to the other are the whole screen, so a small crossing box dragged
  in a clear patch of paper took the diagonal running past it, and the same
  for every arc and every face whose outline went round the area rather than
  through it.  What it touches means what it touches: the segments the thing
  is actually drawn with, and for a face, its inside as well.

  Guides are infinite, so "wholly inside" can never be true of one and a
  containing box would never take a guide at all.  What was asked for was the
  opposite - "our guide points are easy to see so should be easy to select"
  - so a guide line answers the crossing question either way round.

  A bore is the record of a tunnel through a solid, not a thing on the
  screen; it has never been drawable and it should not be selectable.

  What this deliberately does NOT do is ask whether you can see it.  A box is
  a sweep over an area rather than an aim at a point: dragging one round a
  model to take all of it and getting only the front faces would be the
  surprise, not the other way about.  Said out loud here because it was the
  open question in the audit and the answer is a choice, not an oversight. }
function TWorkDoc.BoxTakes(const V: TProjector; I: Integer;
  X0, Y0, X1, Y1: Double; Crossing: Boolean): Boolean;
var
  K, H, N: Integer;
  T: Double;
  BX0, BY0, BX1, BY1: Double;
  PA, PB: TPointF;
  QA, QB: TP3;
  Scr: array of TPointF;
  DG: TDimGeom;

  function Hits(const MA, MB: TP3): Boolean;
  var
    SA, SB: TPointF;
  begin
    SA := Project(V, MA);
    SB := Project(V, MB);
    Result := SegHitsRect(SA.X, SA.Y, SB.X, SB.Y, X0, Y0, X1, Y1);
  end;

begin
  Result := False;
  if (I < 0) or (I >= FLive) then Exit;
  if X1 < X0 then begin T := X0; X0 := X1; X1 := T; end;
  if Y1 < Y0 then begin T := Y0; Y0 := Y1; Y1 := T; end;
  if FEnts[I].Kind = ekBore then Exit;
  if not InSlice(I) then Exit;
  if (FEnts[I].Kind = ekGuide) and FGuidesHidden then Exit;

  { a guide line has no ends to be inside anything, so it answers the
    crossing question whichever way the box was dragged }
  if (FEnts[I].Kind = ekGuide) and (Dist(FEnts[I].A, FEnts[I].B) > 1E-9) then
  begin
    PA := Project(V, FEnts[I].A);
    PB := Project(V, FEnts[I].B);
    { out along its own direction, far enough to cross any view of it }
    QA := P3(FEnts[I].A.X + (FEnts[I].A.X - FEnts[I].B.X) * 5000,
             FEnts[I].A.Y + (FEnts[I].A.Y - FEnts[I].B.Y) * 5000,
             FEnts[I].A.Z + (FEnts[I].A.Z - FEnts[I].B.Z) * 5000);
    QB := P3(FEnts[I].B.X + (FEnts[I].B.X - FEnts[I].A.X) * 5000,
             FEnts[I].B.Y + (FEnts[I].B.Y - FEnts[I].A.Y) * 5000,
             FEnts[I].B.Z + (FEnts[I].B.Z - FEnts[I].A.Z) * 5000);
    Exit(Hits(QA, QB));
  end;

  ScreenBounds(V, I, BX0, BY0, BX1, BY1);
  if BX1 < BX0 then Exit;

  if not Crossing then
    Exit((BX0 >= X0) and (BX1 <= X1) and (BY0 >= Y0) and (BY1 <= Y1));

  { nowhere near, and none of the rest is worth doing }
  if (BX1 < X0) or (BX0 > X1) or (BY1 < Y0) or (BY0 > Y1) then Exit;

  case FEnts[I].Kind of
    ekArc:
      begin
        QA := ArcPoint(FEnts[I].C, FEnts[I].R, FEnts[I].A0,
                       FEnts[I].Plane, FEnts[I].Nm);
        for K := 1 to 24 do
        begin
          QB := ArcPoint(FEnts[I].C, FEnts[I].R,
                  FEnts[I].A0 + FEnts[I].Sweep * K / 24,
                  FEnts[I].Plane, FEnts[I].Nm);
          if Hits(QA, QB) then Exit(True);
          QA := QB;
        end;
      end;
    ekFace:
      begin
        N := Length(FEnts[I].Poly);
        if N < 3 then Exit;
        for K := 0 to N - 1 do
          if Hits(FEnts[I].Poly[K], FEnts[I].Poly[(K + 1) mod N]) then Exit(True);
        for H := 0 to High(FEnts[I].Holes) do
          if Length(FEnts[I].Holes[H]) >= 3 then
            for K := 0 to High(FEnts[I].Holes[H]) do
              if Hits(FEnts[I].Holes[H][K],
                      FEnts[I].Holes[H][(K + 1) mod Length(FEnts[I].Holes[H])]) then
                Exit(True);
        { a box wholly inside the face is on the face, which is as much a
          touch as crossing its edge }
        SetLength(Scr, N);
        for K := 0 to N - 1 do Scr[K] := Project(V, FEnts[I].Poly[K]);
        Result := LoopHasPt(Scr, (X0 + X1) / 2, (Y0 + Y1) / 2);
      end;
    ekText:
      { the words are the note - the same box the cursor is tested against }
      if FEnts[I].BoxR > FEnts[I].BoxL then
        Result := (FEnts[I].BoxR >= X0) and (FEnts[I].BoxL <= X1) and
                  (FEnts[I].BoxB >= Y0) and (FEnts[I].BoxT <= Y1)
      else
      begin
        PA := Project(V, FEnts[I].A);
        Result := (PA.X >= X0) and (PA.X <= X1) and (PA.Y >= Y0) and (PA.Y <= Y1);
      end;
    ekDim:
      { the drawn line and its witness lines, which is what a dimension looks
        like - not the chord through the geometry it measures }
      if DimGeometry(V, FEnts[I].A, FEnts[I].B, FEnts[I].C, usImperial, DG,
           FEnts[I].Txt) then
        Result := SegHitsRect(DG.LA.X, DG.LA.Y, DG.LB.X, DG.LB.Y, X0, Y0, X1, Y1) or
                  SegHitsRect(DG.A.X, DG.A.Y, DG.W1.X, DG.W1.Y, X0, Y0, X1, Y1) or
                  SegHitsRect(DG.B.X, DG.B.Y, DG.W2.X, DG.W2.Y, X0, Y0, X1, Y1);
  else
    { a line, and a guide point, which is a guide with no length }
    Result := Hits(FEnts[I].A, FEnts[I].B);
  end;
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

{ From a note, 14 September, raising a letter of the toy's logo: "they have red
  lines around the letters however i dont understand why the letters became
  red".  The letter's face carries the toy's red - a face only shows a hint
  of its ink - but its outline is drawn in the dark stylus ink, and the new
  edges were given the face's color.  So a raised letter came out outlined
  in red on a body outlined in black.  The edges follow the edges now, the
  same way EdgeWeight already made them follow the pen's width.

  An outline piece that matches exactly is asked first; failing that, any
  line or arc that ends on one of the corners - a side cut by a crossing no
  longer runs corner to corner. }
function TWorkDoc.OutlineInk(Face: Integer; Default: TColor): TColor;
const
  TOL = 1E-7;
var
  I, K, N: Integer;
  A, B: TP3;
begin
  Result := Default;
  if (Face < 0) or (Face >= FLive) then Exit;
  N := Length(FEnts[Face].Poly);
  for K := 0 to N - 1 do
  begin
    A := FEnts[Face].Poly[K];
    B := FEnts[Face].Poly[(K + 1) mod N];
    for I := 0 to FLive - 1 do
      if FEnts[I].Kind = ekLine then
        if (SamePt(FEnts[I].A, A, TOL) and SamePt(FEnts[I].B, B, TOL)) or
           (SamePt(FEnts[I].A, B, TOL) and SamePt(FEnts[I].B, A, TOL)) then
          Exit(FEnts[I].Ink);
  end;
  for K := 0 to N - 1 do
  begin
    A := FEnts[Face].Poly[K];
    for I := 0 to FLive - 1 do
      if FEnts[I].Kind in [ekLine, ekArc] then
        if SamePt(FEnts[I].A, A, TOL) or SamePt(FEnts[I].B, A, TOL) then
          Exit(FEnts[I].Ink);
  end;
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
  Ink, LineInk: TColor;
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
  LineInk := OutlineInk(Index, Ink);
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
    AddLine(FEnts[Index].Poly[I], Top[I], LineInk, Wt, False);
    FEnts[FLive - 1].Grp := G;
    FEnts[FLive - 1].Soft := N >= 9;
    AddLine(Top[I], Top[J], LineInk, Wt, False);
    FEnts[FLive - 1].Grp := G;
  end;

  { and the record of the tunnel, for the next one through this solid }
  AddBore(FEnts[Index].Poly, Top[0], G);
  FLastBore := FLive - 1;
  { and the pushed face is the hole now }
  Delete(Index);
  Dec(FLastBore);
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
  Result := True;
end;

{ How far to the far side of the solid.

  A drill has to land its far end exactly on the plane of the face it is
  coming out of.  Not nearly on it - exactly, to a millionth - because that
  is how Bore recognizes which face gets the hole, and if it recognizes none
  the whole thing silently becomes an ordinary extrusion instead: a solid
  plug pushed into the block rather than a tunnel through it, which is the
  "it built a magic wall".

  Nobody can drag to a millionth.  Reported 13 September, along with the
  reason he could not: "it is not letting me go to the other side and hover
  over the face to set the distance at the face".  Of course not - the far
  face is behind the near one and there is nothing there to hover.

  So the tool works it out.  A drill goes through; that is what the word
  means.  The rule is the one Bore itself uses to find the far face, so a
  distance returned here is one Bore is certain to accept. }
function TWorkDoc.ThroughDistance(Face: Integer; Want: Double): Double;
var
  F, I, N, G: Integer;
  Nm, FN, Mid, Q: TP3;
  D, Best, Sgn, Size, Tol: Double;
  All: Boolean;
begin
  Result := Want;
  if (Face < 0) or (Face >= FLive) or (FEnts[Face].Kind <> ekFace) then Exit;
  N := Length(FEnts[Face].Poly);
  if (N < 3) or (Abs(Want) < 1E-9) then Exit;
  Nm := FaceNormal(Face);
  if Want < 0 then Sgn := -1 else Sgn := 1;

  { which solid - the face's own group, or the one whose wall it sits on }
  G := FEnts[Face].Grp;
  Mid := P3(0, 0, 0);
  for I := 0 to N - 1 do
    Mid := P3(Mid.X + FEnts[Face].Poly[I].X / N,
              Mid.Y + FEnts[Face].Poly[I].Y / N,
              Mid.Z + FEnts[Face].Poly[I].Z / N);
  if G = 0 then
    for F := 0 to FLive - 1 do
    begin
      if (F = Face) or (FEnts[F].Kind <> ekFace) or not FEnts[F].Solid or
         (FEnts[F].Grp = 0) or (Length(FEnts[F].Poly) < 3) then Continue;
      FN := FaceNormal(F);
      if Abs(Abs(Dot3(FN, Nm)) - 1) > 1E-6 then Continue;
      if Abs(Dot3(FN, P3(Mid.X - FEnts[F].Poly[0].X, Mid.Y - FEnts[F].Poly[0].Y,
                         Mid.Z - FEnts[F].Poly[0].Z))) > 1E-6 then Continue;
      if LoopContains(Mid, FEnts[F].Poly, FN) then
      begin
        G := FEnts[F].Grp;
        Break;
      end;
    end;
  if G = 0 then Exit;

  Size := 0;
  for I := 0 to N - 1 do
    Size := Max(Size, Dist(FEnts[Face].Poly[I], FEnts[Face].Poly[0]));
  Tol := 1E-6 * (1 + Size);

  Best := 0;
  for F := 0 to FLive - 1 do
  begin
    if (F = Face) or (FEnts[F].Kind <> ekFace) or (FEnts[F].Grp <> G) then Continue;
    if Length(FEnts[F].Poly) < 3 then Continue;
    FN := FaceNormal(F);
    if Abs(Abs(Dot3(FN, Nm)) - 1) > 1E-6 then Continue;
    { how far along the push this face's plane is - it has to be ahead of
      us, in the direction we are going }
    D := Dot3(Nm, P3(FEnts[F].Poly[0].X - FEnts[Face].Poly[0].X,
                     FEnts[F].Poly[0].Y - FEnts[Face].Poly[0].Y,
                     FEnts[F].Poly[0].Z - FEnts[Face].Poly[0].Z));
    if D * Sgn <= Tol then Continue;
    { and big enough to take the whole opening, which is what Bore asks }
    All := True;
    for I := 0 to N - 1 do
    begin
      Q := P3(FEnts[Face].Poly[I].X + Nm.X * D, FEnts[Face].Poly[I].Y + Nm.Y * D,
              FEnts[Face].Poly[I].Z + Nm.Z * D);
      if not LoopContains(Q, FEnts[F].Poly, FN) then
      begin
        All := False;
        Break;
      end;
    end;
    if not All then Continue;
    Q := P3(Mid.X + Nm.X * D, Mid.Y + Nm.Y * D, Mid.Z + Nm.Z * D);
    if not LoopContains(Q, FEnts[F].Poly, FN) then Continue;
    { the nearest one wins - the first wall it comes out of }
    if (Best = 0) or (Abs(D) < Abs(Best)) then Best := D;
  end;
  if Best <> 0 then Result := Best;
end;

function TWorkDoc.PushPull(Index: Integer; Dist: Double): Boolean;
var
  I, J, N, G: Integer;
  Nm: TP3;
  Base, Top, Rev: TP3Array;
  HBase, HTop, RevH: array of TP3Array;
  H, M: Integer;
  Quad: array[0..3] of TP3;
  Ink, LineInk: TColor;
  Wt: Single;
  Plug, Same: Boolean;
  Turn: Double;
begin
  Result := False;
  FLastBore := -1;
  if (Index < 0) or (Index >= FLive) or (FEnts[Index].Kind <> ekFace) then Exit;
  if Abs(Dist) < 1E-9 then Exit;

  N := Length(FEnts[Index].Poly);
  if N < 3 then Exit;
  Nm := FaceNormal(Index);
  Ink := FEnts[Index].Ink;
  LineInk := OutlineInk(Index, Ink);

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
  Plug := FEnts[Index].Solid and IsPatch(Index);
  if FEnts[Index].Solid and not Plug then
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
    { which way round the opening turns, seen along the face's normal - the
      outline turns positively by definition, so an opening should not }
    Turn := 0;
    for I := 0 to M - 1 do
      Turn := Turn + Dot3(Nm, Cross3(FEnts[Index].Holes[H][I],
        FEnts[Index].Holes[H][(I + 1) mod M]));
    Same := Turn > 0;
    for I := 0 to M - 1 do
    begin
      if Same then
        HBase[H][I] := FEnts[Index].Holes[H][M - 1 - I]
      else
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
    { traveling along the face's own normal: the moved face already faces
      out of the new solid, and the copy left behind is reversed }
    for I := 0 to N - 1 do FEnts[Index].Poly[I] := Top[I];
    for I := 0 to N - 1 do Rev[I] := Base[N - 1 - I];
  end
  else
  begin
    { traveling against it, so the two swap round }
    for I := 0 to N - 1 do FEnts[Index].Poly[I] := Top[N - 1 - I];
    for I := 0 to N - 1 do Rev[I] := Base[I];
  end;
  FEnts[Index].Solid := True;
  { the face that traveled takes its openings with it }
  for H := 0 to High(HTop) do
  begin
    M := Length(HTop[H]);
    SetLength(FEnts[Index].Holes[H], M);
    if Dist >= 0 then
      for I := 0 to M - 1 do FEnts[Index].Holes[H][I] := HTop[H][I]
    else
      for I := 0 to M - 1 do FEnts[Index].Holes[H][I] := HTop[H][M - 1 - I];
  end;

  { A plug - a face sitting in the surface of a solid, like a letter in the
    panel cut out to hold it - has material under it already.  Capping the
    opening it leaves would lay a face inside the solid, and every edge round
    the plug would then be used three times: by the panel, by the cap, and by
    the wall standing on it.  That reads as open.  So the cap is only for a
    face with nothing but air below, which is the shape a box is pulled out
    of when you draw a rectangle and push it. }
  if not Plug then
  begin
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
    AddLine(Base[I], Top[I], LineInk, Wt, False);
    FEnts[FLive - 1].Grp := G;
    { Many sides means the outline was a curve to begin with, so the creases
      running down the extrusion are not real edges - they are how a round
      surface is stored.  Nine or more and they are softened. }
    FEnts[FLive - 1].Soft := N >= 9;
    AddLine(Top[I], Top[J], LineInk, Wt, False);
    FEnts[FLive - 1].Grp := G;
  end;

  { The lining of each opening: the same walls, wound the same way round as
    the ones outside.

    That reads wrong at first - the material is outside a hole rather than
    inside it, so the lining has to look inward at the space the hole leaves,
    which sounds like the opposite winding.  But an opening is already stored
    turning the opposite way to the outline it is cut in, so walking it in
    the same direction is already walking the other way round, and reversing
    it a second time put the lining in inside out.

    What decides it is what the ring meets at the bottom.  Either a cap was
    laid to close what the face left behind, and the cap's copy of the ring
    is the ring reversed; or nothing was, because the face was a plug and the
    material under it goes on - and then the ring meets whatever was plugged
    into the opening, which had to run opposite to it or the solid was never
    closed to begin with.  Both ways the lining runs along the ring, not
    against it.

    "Already stored turning the opposite way" is what the drawing tools make,
    and not a promise: a ring worked out by the region finder can carry its
    opening wound the same way as its outline.  Its lining then came out
    inside out, every wall of the pit facing into the material - so the pit's
    walls were taken for backs and not drawn, and the edges under the ring
    showed through them.  From a note, 17 September: "i see many more lines behind
    faces while orbiting that used to be hidden".  So the winding is measured
    rather than assumed - see where HBase is filled - and an opening that turns
    the same way as the outline is turned round before anything is built on
    it, so the top, the cap and the lining all agree. }
  for H := 0 to High(HBase) do
  begin
    M := Length(HBase[H]);
    for I := 0 to M - 1 do
    begin
      J := (I + 1) mod M;
      if Dist >= 0 then
      begin
        Quad[0] := HBase[H][I]; Quad[1] := HBase[H][J];
        Quad[2] := HTop[H][J];  Quad[3] := HTop[H][I];
      end
      else
      begin
        Quad[0] := HBase[H][J]; Quad[1] := HBase[H][I];
        Quad[2] := HTop[H][I];  Quad[3] := HTop[H][J];
      end;
      AddFaceRaw(Quad, Ink, True);
      FEnts[FLive - 1].Grp := G;
      AddLine(HBase[H][I], HTop[H][I], LineInk, Wt, False);
      FEnts[FLive - 1].Grp := G;
      FEnts[FLive - 1].Soft := M >= 9;
      AddLine(HTop[H][I], HTop[H][J], LineInk, Wt, False);
      FEnts[FLive - 1].Grp := G;
    end;
  end;

  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
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
  GLo, GHi: array of TP3;
  BLo, BHi, GDir: TP3;
  Reach: Double;
  I, J, N, LineCount, NGuide: Integer;
  P: TP3;
  TA, TB: Double;
  Cuts: array of array of Double;
  Idx, GIdx: array of Integer;
  Tmp: Double;
  K, M, H: Integer;
  MidKind: TSnapKind;
  Seen: TFPHashList;
  Key: string;

  procedure Put(const Q: TP3; Kind: TSnapKind);
  begin
    { A point outside the slice is not in the drawing, so it is not something
      to snap to.  Tested on the point rather than on the entity it came
      from, and deliberately: a wall that stands from the floor to the roof
      is in a ground-floor plan, but the corner at the top of it is not, and
      snapping to a corner twelve feet above the drawing you are looking at
      is exactly the fault this is here to prevent. }
    if FSliceOn and ((Q.Z < FSliceLo - 1E-7) or (Q.Z > FSliceHi + 1E-7)) then
      Exit;
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
  FSnapScreenOK := False;

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

      { a guide point is exactly the kind of thing you put down to aim at -
        unless the guides have been put away, in which case it is a place the
        cursor jumps to with nothing on the screen to explain why }
      ekGuide:
        if (not FGuidesHidden) and (Dist(FEnts[I].A, FEnts[I].B) < 1E-9) then
          Put(FEnts[I].A, snEndpoint);

      { Nothing snaps to a dimension or a note.  They are annotation sitting
        beside the drawing, and having the cursor jump to one while drawing a
        line is only ever in the way. }
      ekDim, ekText: ;
    end;

  { The corners of a face, where no line already put one there.

    A face drawn the ordinary way is bounded by lines and its corners are
    already in this list twice over.  A face that arrived some other way -
    a revolve, an import, the example generator - has no lines at all, and
    without this there was nothing whatever to land on along its boundary.
    That is why the dimension tool could not take the corners of the
    etch-a-sketch case while working perfectly on the robot inside it.

    Deduplicated, because most faces DO have their lines and doubling every
    corner of every face would multiply this list by the number of faces
    that share each one - which BestSnap then walks on every mouse move. }
  Seen := TFPHashList.Create;
  try
    for I := 0 to N - 1 do
    begin
      Key := PointKeyOf(FSnapCache[I].P);
      if Seen.Find(Key) = nil then Seen.Add(Key, Pointer(1));
    end;
    for I := 0 to FLive - 1 do
      if FEnts[I].Kind = ekFace then
      begin
        for K := 0 to High(FEnts[I].Poly) do
        begin
          Key := PointKeyOf(FEnts[I].Poly[K]);
          if Seen.Find(Key) <> nil then Continue;
          Seen.Add(Key, Pointer(1));
          Put(FEnts[I].Poly[K], snEndpoint);
        end;
        for H := 0 to High(FEnts[I].Holes) do
          for K := 0 to High(FEnts[I].Holes[H]) do
          begin
            Key := PointKeyOf(FEnts[I].Holes[H][K]);
            if Seen.Find(Key) <> nil then Continue;
            Seen.Add(Key, Pointer(1));
            Put(FEnts[I].Holes[H][K], snEndpoint);
          end;
      end;
  finally
    Seen.Free;
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

  { Where a guide crosses something, which is the whole reason for laying one.

    You set a guide an inch in from the end of a rectangle so you can put
    something an inch in from the end of the rectangle - and the place you
    are aiming at is where that guide meets the edge.  Nothing was offering
    it: this pass only ever walked lines, and a guide was not one, so the
    one point the guide existed to create was the one point the cursor could
    not find.

    From a note, 15 September, in capitals: "THIS SHOULD BE SNAPPING TO THAT GUIDE
    I SET AT THE OTHER END OF THE RECTANGLE AT 1"!!!"

    The crossing only, and no cuts: a guide is construction, and it does not
    divide the edge it lies across the way a drawn line does.  A guide's own
    two ends are left out too - where a guide stops is an accident of how it
    was laid, and SketchUp's have no ends at all.  A guide POINT, which is a
    guide with no length, is already in above and is a real target. }
  SetLength(GIdx, FLive);
  NGuide := 0;
  if not FGuidesHidden then
    for I := 0 to FLive - 1 do
      if (FEnts[I].Kind = ekGuide) and
         (Dist(FEnts[I].A, FEnts[I].B) > 1E-9) then
      begin
        GIdx[NGuide] := I;
        Inc(NGuide);
      end;
  { A guide is stored as a stub - where it was laid, and a point a foot
    along it that records its direction - but it stands for the whole
    infinite line.  This used the stub as it was, so it found crossings
    within a foot of where the guide was laid and nothing further along.

    From a note, 16 September, with a guide laid an inch up from the left-hand
    side of a rectangle: "i should have been able to easily snap to the
    guide on the right hand side of this square at the 1 inch up mark...
    that guide line should have let me snap anywhere it intersected other
    lines!"  The right-hand side was the other side of the stub's start.
    The test that covered this used a guide ten feet long, which is not
    what the tape lays.

    So each guide is run out past the whole drawing both ways first. }
  if (NGuide > 0) and (LineCount + NGuide <= MAX_LINES) then
  begin
    SetLength(GLo, NGuide);
    SetLength(GHi, NGuide);
    if not Bounds(BLo, BHi) then
    begin
      BLo := P3(0, 0, 0);
      BHi := P3(0, 0, 0);
    end;
    Reach := Dist(BLo, BHi) + 1;
    for I := 0 to NGuide - 1 do
    begin
      GDir := Norm3(P3(FEnts[GIdx[I]].B.X - FEnts[GIdx[I]].A.X,
                       FEnts[GIdx[I]].B.Y - FEnts[GIdx[I]].A.Y,
                       FEnts[GIdx[I]].B.Z - FEnts[GIdx[I]].A.Z));
      GLo[I] := P3(FEnts[GIdx[I]].A.X - GDir.X * Reach,
                   FEnts[GIdx[I]].A.Y - GDir.Y * Reach,
                   FEnts[GIdx[I]].A.Z - GDir.Z * Reach);
      GHi[I] := P3(FEnts[GIdx[I]].A.X + GDir.X * Reach,
                   FEnts[GIdx[I]].A.Y + GDir.Y * Reach,
                   FEnts[GIdx[I]].A.Z + GDir.Z * Reach);
    end;
    for I := 0 to NGuide - 1 do
    begin
      for J := 0 to LineCount - 1 do
        if SegCross(GLo[I], GHi[I],
                    FEnts[Idx[J]].A, FEnts[Idx[J]].B, P, TA, TB) then
          Put(P, snCross);
      for J := I + 1 to NGuide - 1 do
        if SegCross(GLo[I], GHi[I], GLo[J], GHi[J], P, TA, TB) then
          Put(P, snCross);
    end;
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

  { Circles and arcs.  A circle's quadrant points - where it crosses the two
    axes of its own plane through its center - are where the next circle is
    started from when a ball or a pipe crossing is built up out of circles,
    so they are points.  Where two arcs cross, in one plane or across two,
    the crossing is a point and the pieces either side of it get middles,
    as the pieces of a cut line do.  An open arc that nothing crosses has a
    middle of its own. }
  ArcSnaps(N);
  CrateSnaps(N);
  SetLength(FSnapCache, N);
  FSnapDirty := False;
end;

{ A group's crate - the box round it - as things to snap to: its eight
  corners, the middles of its twelve edges, the centers of its six sides
  and the center of the whole.  SketchUp puts inference grips on exactly
  those when a group is hovered or picked, and cycles them with Alt; ours
  are simply there.  Only the groups you could take hold of from where you
  are - the ones sitting directly in the open context - and locked ones
  most of all, since a locked group is what you draw against.  From a
  note, 20 September: "I should be able to set guides to its constraining
  crate surface and snap to its virtual crate... the centers of the crate
  should be the snap points." }
procedure TWorkDoc.CrateSnaps(var N: Integer);
var
  I: Integer;
  Lo, Hi, C: TP3;
  X: array[0..2] of Double;
  Y: array[0..2] of Double;
  Z: array[0..2] of Double;
  IX, IY, IZ, NX, NY, NZ, Odd: Integer;

  procedure Put(const Q: TP3; Kind: TSnapKind);
  begin
    if FSliceOn and ((Q.Z < FSliceLo - 1E-7) or (Q.Z > FSliceHi + 1E-7)) then
      Exit;
    if N >= Length(FSnapCache) then SetLength(FSnapCache, Max(32, N * 2));
    FSnapCache[N].P := Q;
    FSnapCache[N].Kind := Kind;
    Inc(N);
  end;

begin
  for I := 0 to FLive - 1 do
  begin
    if FEnts[I].Kind <> ekPart then Continue;
    if FEnts[I].Part <> FContext then Continue;
    if not PartBounds(FEnts[I].Grp, Lo, Hi) then Continue;
    { a flat group has a box with no height; its points are still its
      points, so nothing below minds }
    X[0] := Lo.X; X[1] := (Lo.X + Hi.X) / 2; X[2] := Hi.X;
    Y[0] := Lo.Y; Y[1] := (Lo.Y + Hi.Y) / 2; Y[2] := Hi.Y;
    Z[0] := Lo.Z; Z[1] := (Lo.Z + Hi.Z) / 2; Z[2] := Hi.Z;
    { an axis the box has no extent along - a flat group - has one
      coordinate, not three: walked once, and its middle is not a middle }
    NX := 2; NY := 2; NZ := 2;
    if Hi.X - Lo.X < 1E-7 then NX := 0;
    if Hi.Y - Lo.Y < 1E-7 then NY := 0;
    if Hi.Z - Lo.Z < 1E-7 then NZ := 0;
    { the 27 lattice points of the box: how many middle coordinates a point
      has says what it is - none is a corner, one an edge's middle, two a
      side's center, three the center }
    for IX := 0 to NX do
      for IY := 0 to NY do
        for IZ := 0 to NZ do
        begin
          Odd := Ord(IX = 1) + Ord(IY = 1) + Ord(IZ = 1);
          C := P3(X[IX], Y[IY], Z[IZ]);
          case Odd of
            0: Put(C, snEndpoint);
            1: Put(C, snMidpoint);
          else
            Put(C, snCenter);
          end;
        end;
  end;
end;

{ Everything about an arc's own geometry that the snap cache wants: its
  quadrant points, its crossings with other arcs, and the middles of the
  pieces those crossings leave.  Angles are measured the arc's own way, from
  A0 along its sweep, so a clockwise arc reads the same as an anticlockwise
  one. }
procedure TWorkDoc.ArcSnaps(var N: Integer);
const
  MAX_ARCS = 300;
var
  I, J, K, Q, G, ArcCount: Integer;
  Idx: array of Integer;
  Cuts: array of array of Double;
  AU, AV, Nm, P, U, Wv, GDir: TP3;
  Ang, Tmp: Double;

  procedure Put(const Pt: TP3; Kind: TSnapKind);
  begin
    if N >= Length(FSnapCache) then SetLength(FSnapCache, Max(32, N * 2));
    FSnapCache[N].P := Pt;
    FSnapCache[N].Kind := Kind;
    Inc(N);
  end;

  procedure Axes(const E: TWorkEnt; out U, V, Nrm: TP3);
  begin
    if E.Plane = plFree then
    begin
      Nrm := Norm3(E.Nm);
      AxesFromNormal(Nrm, U, V);
    end
    else
    begin
      PlaneAxes(E.Plane, U, V);
      Nrm := Norm3(Cross3(U, V));
    end;
  end;

  { the point at absolute angle A on the arc's circle }
  function At(const E: TWorkEnt; A: Double): TP3;
  begin
    if E.Plane = plFree then Result := ArcPoint(E.C, E.R, A, E.Plane, E.Nm)
    else Result := ArcPoint(E.C, E.R, A, E.Plane);
  end;

  { how far along the arc, from A0 in the direction of the sweep, an
    absolute angle sits: 0 .. 2pi }
  function Along(const E: TWorkEnt; A: Double): Double;
  begin
    if E.Sweep >= 0 then Result := A - E.A0 else Result := E.A0 - A;
    Result := Result - 2 * Pi * Floor(Result / (2 * Pi));
  end;

  function OnArc(const E: TWorkEnt; A: Double): Boolean;
  var
    L: Double;
  begin
    if Abs(E.Sweep) >= 2 * Pi - 1E-9 then Exit(True);
    L := Along(E, A);
    Result := (L <= Abs(E.Sweep) + 1E-7) or (L >= 2 * Pi - 1E-7);
  end;

  { the absolute angle of a point on (or near) the arc's circle }
  function AngleOf(const E: TWorkEnt; const Pt: TP3): Double;
  var
    U, V, Nrm, D: TP3;
  begin
    Axes(E, U, V, Nrm);
    D := P3(Pt.X - E.C.X, Pt.Y - E.C.Y, Pt.Z - E.C.Z);
    Result := ArcTan2(Dot3(D, V), Dot3(D, U));
  end;

  procedure AddCut(Which: Integer; Rel: Double);
  var
    M: Integer;
  begin
    for M := 0 to High(Cuts[Which]) do
      if Abs(Cuts[Which][M] - Rel) < 1E-7 then Exit;
    SetLength(Cuts[Which], Length(Cuts[Which]) + 1);
    Cuts[Which][High(Cuts[Which])] := Rel;
  end;

  { a point that is on both arcs is a crossing: noted once, cut into both }
  procedure Crossing(const Pt: TP3; AI, AJ: Integer);
  var
    A1, A2: Double;
  begin
    A1 := AngleOf(FEnts[Idx[AI]], Pt);
    A2 := AngleOf(FEnts[Idx[AJ]], Pt);
    if not (OnArc(FEnts[Idx[AI]], A1) and OnArc(FEnts[Idx[AJ]], A2)) then Exit;
    Put(Pt, snCross);
    AddCut(AI, Along(FEnts[Idx[AI]], A1));
    AddCut(AJ, Along(FEnts[Idx[AJ]], A2));
  end;

  { where the circle of arc J meets the plane of arc I: solve for the angles
    on J where the point lies in I's plane, then keep those on I's circle }
  procedure CrossPlane(AI, AJ: Integer);
  var
    UI, VI, NI, UJ, VJ, NJ, Pt: TP3;
    A, B, Cc, Rr, Phi, Th: Double;
    S: Integer;
  begin
    Axes(FEnts[Idx[AI]], UI, VI, NI);
    Axes(FEnts[Idx[AJ]], UJ, VJ, NJ);
    A := FEnts[Idx[AJ]].R * Dot3(NI, UJ);
    B := FEnts[Idx[AJ]].R * Dot3(NI, VJ);
    Cc := Dot3(NI, P3(FEnts[Idx[AI]].C.X - FEnts[Idx[AJ]].C.X,
                      FEnts[Idx[AI]].C.Y - FEnts[Idx[AJ]].C.Y,
                      FEnts[Idx[AI]].C.Z - FEnts[Idx[AJ]].C.Z));
    Rr := Sqrt(A * A + B * B);
    if (Rr < 1E-12) or (Abs(Cc) > Rr) then Exit;
    Phi := ArcTan2(B, A);
    for S := -1 to 1 do
    begin
      if S = 0 then Continue;
      Th := Phi + S * ArcCos(EnsureRange(Cc / Rr, -1.0, 1.0));
      Pt := At(FEnts[Idx[AJ]], Th);
      if Abs(Dist(Pt, FEnts[Idx[AI]].C) - FEnts[Idx[AI]].R) > 1E-6 then Continue;
      Crossing(Pt, AI, AJ);
    end;
  end;

  { two arcs in one plane: the two points where their circles meet }
  procedure CrossCoplanar(AI, AJ: Integer);
  var
    UI, VI, NI, Pt: TP3;
    D, A, H, RI, RJ: Double;
    S: Integer;
  begin
    Axes(FEnts[Idx[AI]], UI, VI, NI);
    RI := FEnts[Idx[AI]].R; RJ := FEnts[Idx[AJ]].R;
    D := Dist(FEnts[Idx[AI]].C, FEnts[Idx[AJ]].C);
    if (D < 1E-9) or (D > RI + RJ + 1E-9) or (D < Abs(RI - RJ) - 1E-9) then Exit;
    U := Norm3(P3(FEnts[Idx[AJ]].C.X - FEnts[Idx[AI]].C.X,
                  FEnts[Idx[AJ]].C.Y - FEnts[Idx[AI]].C.Y,
                  FEnts[Idx[AJ]].C.Z - FEnts[Idx[AI]].C.Z));
    Wv := Norm3(Cross3(NI, U));
    A := (RI * RI - RJ * RJ + D * D) / (2 * D);
    H := Sqrt(Max(0, RI * RI - A * A));
    for S := -1 to 1 do
    begin
      if (S = 0) and (H > 1E-9) then Continue;
      if (S <> 0) and (H <= 1E-9) then Continue;
      Pt := P3(FEnts[Idx[AI]].C.X + U.X * A + Wv.X * H * S,
               FEnts[Idx[AI]].C.Y + U.Y * A + Wv.Y * H * S,
               FEnts[Idx[AI]].C.Z + U.Z * A + Wv.Z * H * S);
      Crossing(Pt, AI, AJ);
    end;
  end;

  { an infinite line through LA along LD, against arc AI }
  procedure GuideMeetsArc(const LA, LD: TP3; AI: Integer);
  var
    U, V, Nrm, W, Pt: TP3;
    E: TWorkEnt;
    Dn, Off, Bq, Cq, Disc, T, Tol: Double;
    S: Integer;

    procedure Offer(const Q: TP3);
    begin
      if OnArc(E, AngleOf(E, Q)) then Put(Q, snCross);
    end;

  begin
    E := FEnts[Idx[AI]];
    Axes(E, U, V, Nrm);
    Tol := 1E-6 * (1 + E.R);
    W := P3(LA.X - E.C.X, LA.Y - E.C.Y, LA.Z - E.C.Z);
    Dn := Dot3(LD, Nrm);
    Off := Dot3(W, Nrm);
    if Abs(Dn) < 1E-9 then
    begin
      { along the arc's plane: in it, or nowhere }
      if Abs(Off) > Tol then Exit;
      Bq := Dot3(W, LD);
      Cq := Dot3(W, W) - E.R * E.R;
      Disc := Bq * Bq - Cq;
      if Disc < -Tol then Exit;
      Disc := Sqrt(Max(0, Disc));
      for S := -1 to 1 do
      begin
        if S = 0 then Continue;
        if (S = 1) and (Disc < 1E-12) then Continue;   { a tangent, once }
        T := -Bq + S * Disc;
        Offer(P3(LA.X + LD.X * T, LA.Y + LD.Y * T, LA.Z + LD.Z * T));
      end;
    end
    else
    begin
      { through the plane at one point, which has to be on the circle }
      T := -Off / Dn;
      Pt := P3(LA.X + LD.X * T, LA.Y + LD.Y * T, LA.Z + LD.Z * T);
      if Abs(Dist(Pt, E.C) - E.R) <= Tol then Offer(Pt);
    end;
  end;

  function Coplanar(AI, AJ: Integer): Boolean;
  var
    UI, VI, NI, UJ, VJ, NJ: TP3;
  begin
    Axes(FEnts[Idx[AI]], UI, VI, NI);
    Axes(FEnts[Idx[AJ]], UJ, VJ, NJ);
    Result := (Abs(Abs(Dot3(NI, NJ)) - 1) < 1E-9) and
      (Abs(Dot3(NI, P3(FEnts[Idx[AJ]].C.X - FEnts[Idx[AI]].C.X,
                       FEnts[Idx[AJ]].C.Y - FEnts[Idx[AI]].C.Y,
                       FEnts[Idx[AJ]].C.Z - FEnts[Idx[AI]].C.Z))) < 1E-9);
  end;

begin
  SetLength(Idx, FLive);
  ArcCount := 0;
  for I := 0 to FLive - 1 do
    if (FEnts[I].Kind = ekArc) and (FEnts[I].R > 1E-9) then
    begin
      Idx[ArcCount] := I;
      Inc(ArcCount);
    end;
  if ArcCount = 0 then Exit;
  SetLength(Cuts, ArcCount);
  { the quadrant points }
  for I := 0 to ArcCount - 1 do
    for Q := 0 to 3 do
    begin
      Ang := Q * Pi / 2;
      if OnArc(FEnts[Idx[I]], Ang) then Put(At(FEnts[Idx[I]], Ang), snQuadrant);
    end;
  { the crossings }
  if ArcCount <= MAX_ARCS then
    for I := 0 to ArcCount - 2 do
      for J := I + 1 to ArcCount - 1 do
        if Coplanar(I, J) then CrossCoplanar(I, J)
        else
        begin
          CrossPlane(I, J);
          CrossPlane(J, I);
        end;
  { Where a guide crosses an arc - a guide laid an inch up from the side of
    a rounded rectangle meets the rounded corner, not the straight side.
    The guide is a line without end; it does not cut the arc (a guide is
    construction), it only offers the point. }
  if (not FGuidesHidden) and (ArcCount <= MAX_ARCS) then
    for G := 0 to FLive - 1 do
    begin
      if (FEnts[G].Kind <> ekGuide) or
         (Dist(FEnts[G].A, FEnts[G].B) < 1E-9) then Continue;
      GDir := Norm3(P3(FEnts[G].B.X - FEnts[G].A.X, FEnts[G].B.Y - FEnts[G].A.Y,
                       FEnts[G].B.Z - FEnts[G].A.Z));
      for I := 0 to ArcCount - 1 do
        GuideMeetsArc(FEnts[G].A, GDir, I);
    end;

  { the middles of the pieces }
  for I := 0 to ArcCount - 1 do
  begin
    if Length(Cuts[I]) = 0 then
    begin
      { an open arc nothing crosses still has a middle; a whole circle does
        not have one anywhere in particular }
      if Abs(FEnts[Idx[I]].Sweep) < 2 * Pi - 1E-9 then
        Put(At(FEnts[Idx[I]], FEnts[Idx[I]].A0 + FEnts[Idx[I]].Sweep / 2), snMidpoint);
      Continue;
    end;
    { the ends are cuts too, unless it is a whole circle, where the pieces
      run round from the last cut to the first }
    if Abs(FEnts[Idx[I]].Sweep) < 2 * Pi - 1E-9 then
    begin
      AddCut(I, 0);
      AddCut(I, Abs(FEnts[Idx[I]].Sweep));
    end;
    for K := 0 to High(Cuts[I]) - 1 do
      for Q := 0 to High(Cuts[I]) - 1 - K do
        if Cuts[I][Q] > Cuts[I][Q + 1] then
        begin
          Tmp := Cuts[I][Q]; Cuts[I][Q] := Cuts[I][Q + 1]; Cuts[I][Q + 1] := Tmp;
        end;
    for K := 0 to High(Cuts[I]) do
    begin
      if K < High(Cuts[I]) then Tmp := (Cuts[I][K] + Cuts[I][K + 1]) / 2
      else if Abs(FEnts[Idx[I]].Sweep) >= 2 * Pi - 1E-9 then
        Tmp := (Cuts[I][K] + Cuts[I][0] + 2 * Pi) / 2
      else
        Continue;
      if Tmp >= 2 * Pi then Tmp := Tmp - 2 * Pi;
      if FEnts[Idx[I]].Sweep >= 0 then Ang := FEnts[Idx[I]].A0 + Tmp
      else Ang := FEnts[Idx[I]].A0 - Tmp;
      Put(At(FEnts[Idx[I]], Ang), snSubMid);
    end;
  end;
end;

{ Every live document, so that a surface being freed can find the ones that
  borrowed it.  There are never more than a handful - one per sheet. }
var
  GDocs: array of TWorkDoc;

procedure NoteDoc(D: TWorkDoc);
begin
  SetLength(GDocs, Length(GDocs) + 1);
  GDocs[High(GDocs)] := D;
end;

procedure ForgetDoc(D: TWorkDoc);
var
  I, J: Integer;
begin
  for I := 0 to High(GDocs) do
    if GDocs[I] = D then
    begin
      for J := I to High(GDocs) - 1 do GDocs[J] := GDocs[J + 1];
      SetLength(GDocs, Length(GDocs) - 1);
      Exit;
    end;
end;

{ A surface is going: any document still pointing at it as the last one it
  rendered into must let go, or the next "is this hidden" reads freed memory.

  From a note, 16 September: "the exception happened after i exported the gif then
  click in the canvas".  The GIF export makes its own surface, renders every
  frame into it and frees it; LastSurf was left pointing into that.  The
  export could clear it on the way out instead, and that would work until
  somebody writes a third exporter and does not. }
procedure SurfaceGone(S: TArtSurface);
var
  I: Integer;
begin
  for I := 0 to High(GDocs) do
    if GDocs[I].LastSurf = S then
    begin
      GDocs[I].LastSurf := nil;
      GDocs[I].LastSurfDied := True;
    end;
end;

constructor TWorkDoc.Create;
begin
  inherited Create;
  Threads := DefaultThreads;
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
  NoteDoc(Self);
end;

destructor TWorkDoc.Destroy;
begin
  ForgetDoc(Self);
  { a worker still running would queue a call into a freed object }
  if FOnFaceWorker <> nil then
  begin
    FOnFaceWorker.WaitFor;
    TThread.RemoveQueuedEvents(FOnFaceWorker);
    FOnFaceWorker.Free;
    FOnFaceWorker := nil;
  end;
  inherited Destroy;
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
{ How far the cursor is from an arc, measured against the chords it is really
  drawn with - see HitEdge for why that rather than the circle.

  Taking the camera ready-made matters more here than anywhere: this walks
  twenty-five points for one arc, and a sheet of circles is a common enough
  drawing.  The bounding circle is asked first - an orthographic projection
  never moves a point further from the center than its own distance times
  Ppu, so a cursor outside that cannot be near the arc - which drops every
  circle but the one being pointed at before any of the chords are walked. }
function ArcNearestAt(const PC: TProjCache; const E: TWorkEnt;
  SX, SY: Double; out P: TP3; TolPx: Double = 1E30): Double;
var
  STEPS: Integer;
  K: Integer;
  Ang, RPx, D: Double;
  PA, PB, PCen: TPointF;
  A3, B3: TP3;
begin
  Result := 1E30;
  P := E.C;
  PCen := ProjectAt(PC, E.C);
  RPx := E.R * PC.Ppu;
  if (Abs(SX - PCen.X) > RPx + TolPx) or (Abs(SY - PCen.Y) > RPx + TolPx) then
    Exit;
  STEPS := ArcSteps(E);
  A3 := ArcPoint(E.C, E.R, E.A0, E.Plane, E.Nm);
  PA := ProjectAt(PC, A3);
  for K := 1 to STEPS do
  begin
    Ang := E.A0 + E.Sweep * K / STEPS;
    B3 := ArcPoint(E.C, E.R, Ang, E.Plane, E.Nm);
    PB := ProjectAt(PC, B3);
    D := DistToSeg(SX, SY, PA.X, PA.Y, PB.X, PB.Y);
    if D < Result then
    begin
      Result := D;
      P := Lerp3(A3, B3, SegParam(SX, SY, PA.X, PA.Y, PB.X, PB.Y));
    end;
    PA := PB;
    A3 := B3;
  end;
end;

function ArcScreenDistAt(const PC: TProjCache; const E: TWorkEnt;
  SX, SY: Double; TolPx: Double = 1E30): Double;
var
  Ignored: TP3;
begin
  Result := ArcNearestAt(PC, E, SX, SY, Ignored, TolPx);
end;

function ArcScreenDist(const V: TProjector; const E: TWorkEnt;
  SX, SY: Double): Double;
var
  PC: TProjCache;
begin
  BeginProject(V, PC);
  Result := ArcScreenDistAt(PC, E, SX, SY);
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

function TWorkDoc.SnapCacheCount: Integer;
begin
  if FSnapDirty then RebuildSnapCache;
  Result := Length(FSnapCache);
end;

function TWorkDoc.EdgeSnap(const V: TProjector; SX, SY, TolPx: Double;
  out P: TP3; out Ent: Integer): Boolean;
var
  A, B: TP3;
begin
  Result := EdgeUnder(V, SX, SY, TolPx, P, A, B, Ent);
end;

function TWorkDoc.EdgeUnder(const V: TProjector; SX, SY, TolPx: Double;
  out P, A, B: TP3; out Ent: Integer): Boolean;
const
  { how close on screen counts as "the same place", for preferring the one
    nearer the eye }
  TIE_PX = 1.0;
var
  I, K, H: Integer;
  Best, BestZ: Double;
  QA, QB, Look: TP3;
  PC: TProjCache;

  { Project the segment, find the nearest point along it on screen, then read
    the same fraction back off the model segment.  The projection is affine,
    so the two fractions are the same number. }
  procedure Try_(const MA, MB: TP3);
  var
    PA, PB: TPointF;
    DX, DY, L2, T, D, QZ: Double;
    Q: TP3;
  begin
    PA := ProjectAt(PC, MA);
    PB := ProjectAt(PC, MB);
    DX := PB.X - PA.X;
    DY := PB.Y - PA.Y;
    L2 := DX * DX + DY * DY;
    if L2 < 1E-12 then Exit;
    T := EnsureRange(((SX - PA.X) * DX + (SY - PA.Y) * DY) / L2, 0, 1);
    D := Sqrt(Sqr(SX - (PA.X + DX * T)) + Sqr(SY - (PA.Y + DY * T)));
    Q := P3(MA.X + (MB.X - MA.X) * T, MA.Y + (MB.Y - MA.Y) * T,
            MA.Z + (MB.Z - MA.Z) * T);
    QZ := Dot3(Q, Look);

    { Nearer on screen wins; as near, and nearer the eye, wins too.

      Two edges a hair apart in depth land on the same pixel, and with no
      rule for that the answer was whichever came first in the entity list -
      which is an answer about the order things were drawn in, not about
      what is under the cursor.  The etch-a-sketch is made of exactly this:
      the lip of the case and the screen recess sit an eighth of an inch
      apart, so measuring along the top of it flipped between the two.

      A tenth of a pixel would be too tight to help and ten would take edges
      that are plainly further away.  One pixel is the width of the line you
      are pointing at. }
    { Within reach at all, then: nearer wins, and a tie inside a pixel goes
      to whatever is nearer the eye.

      The gate is separate from the contest for a reason.  With Best starting
      at the tolerance and the first candidate having to beat it by a whole
      pixel, an edge alone in an empty view at TolPx minus a half was not
      found at all - the reach was quietly a pixel shorter than the one asked
      for, and only for the first thing considered. }
    if D > TolPx then Exit;
    if (Ent < 0) or (D < Best - TIE_PX) or
       ((D < Best + TIE_PX) and (QZ > BestZ + 1E-9)) then
    begin
      { An edge behind a solid is not one anybody is aiming at.

        BestSnap has asked this of its points since the day somebody got
        pulled onto the corner of a tunnel through the wall they were
        drawing on.  This did not ask it at all: it took whichever segment
        came nearest ON SCREEN, so measuring along the front edge of a box
        would jump to the back edge wherever that happened to project a
        pixel closer - and on anything with a curve in it, where the far
        side is a hand's breadth of nearly-parallel lines, it jumped
        constantly.

        A face the point lies in cannot hide it, so an edge lying on the
        face it bounds is safe; see HiddenAt.  Only a candidate that would
        win is asked, so this costs nothing when the view is clear. }
      if HiddenAt(V, Q) then Exit;
      if D < Best then Best := D;
      BestZ := QZ;
      P := Q;
      A := MA;
      B := MB;
      Ent := I;
    end;
  end;

  { Is this loop nowhere near the cursor?

    Walking a face means two projections for every side of it, and the case
    of the etch-a-sketch has thirty-two.  Its eight box corners cost eight -
    and an affine projection maps the box onto a shape that contains the
    projected outline, so a cursor outside the projected box cannot be on the
    outline either.  Worth it only for loops with enough sides to pay for the
    eight; below that, projecting the sides directly is cheaper. }
  function LoopFar(const Pts: TP3Array): Boolean;
  var
    J: Integer;
    Lo, Hi: TP3;
    Q: TPointF;
    MnX, MnY, MxX, MxY: Double;
    CX, CY, CZ: Integer;
  begin
    Result := False;
    if Length(Pts) < 7 then Exit;
    Lo := Pts[0];
    Hi := Pts[0];
    for J := 1 to High(Pts) do
    begin
      Lo.X := Min(Lo.X, Pts[J].X); Hi.X := Max(Hi.X, Pts[J].X);
      Lo.Y := Min(Lo.Y, Pts[J].Y); Hi.Y := Max(Hi.Y, Pts[J].Y);
      Lo.Z := Min(Lo.Z, Pts[J].Z); Hi.Z := Max(Hi.Z, Pts[J].Z);
    end;
    MnX := 1E30; MnY := 1E30; MxX := -1E30; MxY := -1E30;
    for CX := 0 to 1 do
      for CY := 0 to 1 do
        for CZ := 0 to 1 do
        begin
          Q := ProjectAt(PC, P3(specialize IfThen<Double>(CX = 0, Lo.X, Hi.X),
                                specialize IfThen<Double>(CY = 0, Lo.Y, Hi.Y),
                                specialize IfThen<Double>(CZ = 0, Lo.Z, Hi.Z)));
          MnX := Min(MnX, Q.X); MxX := Max(MxX, Q.X);
          MnY := Min(MnY, Q.Y); MxY := Max(MxY, Q.Y);
        end;
    Result := (SX < MnX - TolPx) or (SX > MxX + TolPx) or
              (SY < MnY - TolPx) or (SY > MxY + TolPx);
  end;

begin
  P := P3(0, 0, 0);
  A := P3(0, 0, 0);
  B := P3(0, 0, 0);
  Ent := -1;
  Best := 1E30;
  BestZ := -1E30;
  { the camera, once, instead of once per projected point - see BeginProject }
  BeginProject(V, PC);
  { points from the drawing towards the camera, so a bigger dot is nearer }
  Look := ViewDir(V);
  for I := 0 to FLive - 1 do
  begin
    if not InSlice(I) then Continue;
    case FEnts[I].Kind of
      ekLine: Try_(FEnts[I].A, FEnts[I].B);
      { a point on a guide line counts - that is what guides are for, until
        they are put away, and then it does not }
      ekGuide:
        if (not FGuidesHidden) and (Dist(FEnts[I].A, FEnts[I].B) > 1E-9) then
          Try_(P3(FEnts[I].A.X + (FEnts[I].A.X - FEnts[I].B.X) * 2000,
                  FEnts[I].A.Y + (FEnts[I].A.Y - FEnts[I].B.Y) * 2000,
                  FEnts[I].A.Z + (FEnts[I].A.Z - FEnts[I].B.Z) * 2000),
               P3(FEnts[I].B.X + (FEnts[I].B.X - FEnts[I].A.X) * 2000,
                  FEnts[I].B.Y + (FEnts[I].B.Y - FEnts[I].A.Y) * 2000,
                  FEnts[I].B.Z + (FEnts[I].B.Z - FEnts[I].A.Z) * 2000));
      { The outline of a face is geometry you can see, so it is geometry the
        cursor can run along.

        It was not, and that is why the dimension tool would not take the
        long edges of the etch-a-sketch: the body of the toy is one face of
        thirty-two corners whose longest edge is ten and a half inches, and
        it has no line entities at all.  The robot and the lettering DO -
        they are drawn with lines - which is exactly why those cooperated and
        the case of the toy fought back.

        Anything that arrives as faces rather than as drawn lines is in the
        same position: a revolve, an imported model, this example.  A face
        that also has lines along it simply gets found twice, at the same
        place, for the same answer. }
      ekFace:
        begin
          if not LoopFar(FEnts[I].Poly) then
            for K := 0 to High(FEnts[I].Poly) do
              Try_(FEnts[I].Poly[K],
                   FEnts[I].Poly[(K + 1) mod Length(FEnts[I].Poly)]);
          { and what is cut out of it, which is just as much an edge }
          for H := 0 to High(FEnts[I].Holes) do
            if (Length(FEnts[I].Holes[H]) >= 3) and
               not LoopFar(FEnts[I].Holes[H]) then
              for K := 0 to High(FEnts[I].Holes[H]) do
                Try_(FEnts[I].Holes[H][K],
                     FEnts[I].Holes[H][(K + 1) mod Length(FEnts[I].Holes[H])]);
        end;
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
  end;
  { A line or an arc reports its OWN two ends, so that "the whole of it"
    means the whole line and not the piece the cursor happened to be over -
    an arc is walked as a fan of chords and a line may be crossed by others.
    A face reports the side of its outline being pointed at, which is the
    whole of that edge already. }
  if (Ent >= 0) and (FEnts[Ent].Kind in [ekLine, ekArc]) then
  begin
    A := FEnts[Ent].A;
    B := FEnts[Ent].B;
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

{ A guide point is put down to be come back to, so it has to be easy to get
  hold of again.

  From a note, 15 September, after trying it in SketchUp: "I have to admit trying to
  click it and select it to delete was very difficult and it took me 20 times
  to get it so that is a SketchUp problem... Don't let it be our problem.
  Ours should make sure the select tool is what manages and deletes guide
  lines and guide points and our guide points are easy to see so should be
  easy to select!"

  Two things make it hard, and neither is the tolerance.  The first is that a
  guide point is nearly always sitting **on** a line - it marks a distance
  along one - so the line under it is at the same distance from the cursor
  and wins the moment the aim is a pixel off.  The second is that the point
  is drawn bigger than the reach it was picked at, so it looks like a target
  larger than it is.  Asked first, and with a reach that matches what is
  drawn, both go away. }
function TWorkDoc.HitGuidePoint(const V: TProjector; SX, SY,
  TolPx: Double): Integer;
var
  I: Integer;
  D, Best: Double;
  PA: TPointF;
begin
  Result := -1;
  if FGuidesHidden then Exit;
  Best := TolPx;
  for I := FLive - 1 downto 0 do
  begin
    if FEnts[I].Kind <> ekGuide then Continue;
    if Dist(FEnts[I].A, FEnts[I].B) > 1E-9 then Continue;
    if not InSlice(I) then Continue;
    PA := Project(V, FEnts[I].A);
    D := Sqrt(Sqr(SX - PA.X) + Sqr(SY - PA.Y));
    if D <= Best then
    begin
      Best := D;
      Result := I;
    end;
  end;
end;

function TWorkDoc.RunsAlongEdge(const A, B: TP3): Boolean;
const
  TOL = 1E-6;
var
  I: Integer;
  Run, E, X: TP3;
  L, T: Double;

  { A is on this line, at an end or along it }
  function Touches(const P, Q: TP3): Boolean;
  var
    D: TP3;
    LL: Double;
  begin
    if (Dist(A, P) < TOL) or (Dist(A, Q) < TOL) then Exit(True);
    D := P3(Q.X - P.X, Q.Y - P.Y, Q.Z - P.Z);
    LL := Sqr(D.X) + Sqr(D.Y) + Sqr(D.Z);
    if LL < 1E-18 then Exit(False);
    T := ((A.X - P.X) * D.X + (A.Y - P.Y) * D.Y + (A.Z - P.Z) * D.Z) / LL;
    if (T < -TOL) or (T > 1 + TOL) then Exit(False);
    Result := Dist(A, P3(P.X + D.X * T, P.Y + D.Y * T, P.Z + D.Z * T)) < TOL;
  end;

begin
  Result := False;
  Run := P3(B.X - A.X, B.Y - A.Y, B.Z - A.Z);
  L := Sqrt(Sqr(Run.X) + Sqr(Run.Y) + Sqr(Run.Z));
  if L < 1E-9 then Exit;
  Run := P3(Run.X / L, Run.Y / L, Run.Z / L);
  for I := 0 to FLive - 1 do
  begin
    if FEnts[I].Kind <> ekLine then Continue;
    if FEnts[I].Dim then Continue;
    if not Touches(FEnts[I].A, FEnts[I].B) then Continue;
    E := P3(FEnts[I].B.X - FEnts[I].A.X, FEnts[I].B.Y - FEnts[I].A.Y,
            FEnts[I].B.Z - FEnts[I].A.Z);
    L := Sqrt(Sqr(E.X) + Sqr(E.Y) + Sqr(E.Z));
    if L < 1E-9 then Continue;
    E := P3(E.X / L, E.Y / L, E.Z / L);
    X := Cross3(E, Run);
    if Sqrt(Sqr(X.X) + Sqr(X.Y) + Sqr(X.Z)) < 1E-6 then Exit(True);
  end;
end;

function TWorkDoc.HitEdge(const V: TProjector; SX, SY, TolPx: Double;
  GuideTolPx: Double): Integer;
var
  I: Integer;
  D, Best: Double;
  PA, PB: TPointF;
  DG: TDimGeom;
  PC: TProjCache;
  NearPt: TP3;
  VisHere, BestVis, Take: Boolean;
begin
  Result := -1;
  Best := TolPx;
  BestVis := False;
  NearPt := P3(0, 0, 0);
  { the camera worked out once for the whole walk rather than once per point.
    Project rebuilds the view basis every call - four trig calls in the orbit
    view - and this walks every line in the drawing twice, every mouse move. }
  BeginProject(V, PC);
  for I := FLive - 1 downto 0 do
  begin
    if not (FEnts[I].Kind in [ekLine, ekArc, ekDim, ekGuide]) then Continue;
    if not InSlice(I) then Continue;
    { a guide that has been put away is not on the screen, so it is not
      under the cursor either - picking or erasing one you cannot see is the
      same surprise as snapping to one }
    if (FEnts[I].Kind = ekGuide) and FGuidesHidden then Continue;
    if FEnts[I].Kind = ekGuide then
    begin
      D := GuideScreenDist(V, FEnts[I], SX, SY);
      { a guide answers on its own reach, which may be shorter than an
        edge's - see the note on GuideTolPx }
      if (GuideTolPx >= 0) and (D > GuideTolPx) then Continue;
    end
    else if FEnts[I].Kind = ekArc then
      { A circle in the model is an ellipse on screen once its plane is tilted
        away from the camera, and a part arc is not a whole circle either.
        Measuring against the drawn segments is the only test that holds up in
        ISO and orbit. }
      D := ArcNearestAt(PC, FEnts[I], SX, SY, NearPt, TolPx)
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
      PA := ProjectAt(PC, FEnts[I].A);
      PB := ProjectAt(PC, FEnts[I].B);
      D := DistToSeg(SX, SY, PA.X, PA.Y, PB.X, PB.Y);
      NearPt := Lerp3(FEnts[I].A, FEnts[I].B,
        SegParam(SX, SY, PA.X, PA.Y, PB.X, PB.Y));
    end;
    if not (D < TolPx) then Continue;

    { --- what is in front, where you are pointing ----------------------

      From a note, by report: "trying to erase the black ring on the top of the
      knobs... but it ends up selecting some of its walls underneath it."

      This kept whichever edge came nearest the cursor on the screen, and
      let depth do nothing but disqualify: an edge was dropped only when it
      was hidden at all three of the places sampled along it.  The wall of a
      knob is a silhouette - visible down its whole length - so it was never
      dropped, and where it ran within a pixel of the rim it simply won on
      flat distance.  Nothing preferred what was in front.

      So an edge is now asked whether it can be seen AT THE POINT NEAREST
      THE CURSOR, and one that can beats one that cannot however close the
      other is.  That is what "in front wins" means when you are pointing at
      a spot rather than at a whole edge.  Among edges of the same kind the
      nearest still wins, so nothing else about the feel changes.

      The three-sample rule stays underneath it, unchanged: an edge hidden
      all the way along is not pickable at all, because out of sight behind
      a panel is not what anybody meant to click.  It is only asked when the
      cheap question has already said the edge is hidden here - an edge
      visible under the cursor is plainly not hidden everywhere. }
    VisHere := True;
    if FEnts[I].Kind in [ekLine, ekArc] then
    begin
      VisHere := not HiddenAt(V, NearPt);
      if (not VisHere) and
         HiddenAt(V, Lerp3(FEnts[I].A, FEnts[I].B, 0.5)) and
         HiddenAt(V, Lerp3(FEnts[I].A, FEnts[I].B, 0.2)) and
         HiddenAt(V, Lerp3(FEnts[I].A, FEnts[I].B, 0.8)) then Continue;
    end;

    Take := Result < 0;
    if not Take then
      if VisHere and not BestVis then Take := True
      else if (VisHere = BestVis) and (D < Best) then Take := True;
    if Take then
    begin
      Best := D;
      BestVis := VisHere;
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
{ Which faces each line, arc, dimension or note lies in the plane of, over
  the face's own extent.  Pure: reads the entities it is given, writes the
  lists, touches nothing else - which is what lets it run on a worker. }
procedure ComputeOnFace(const Ents: array of TWorkEnt; Count: Integer; out Lists: TIntArrayWArray);
const
  SLACK = 1E-3;
var
  F, I, K: Integer;
  N, P0, Lo, Hi, A, B: TP3;
  D: Double;
  ELo, EHi: array of TP3;

  procedure Grow(var L, H: TP3; const P: TP3);
  begin
    if P.X < L.X then L.X := P.X; if P.Y < L.Y then L.Y := P.Y; if P.Z < L.Z then L.Z := P.Z;
    if P.X > H.X then H.X := P.X; if P.Y > H.Y then H.Y := P.Y; if P.Z > H.Z then H.Z := P.Z;
  end;

  function OnPlane(const P: TP3): Boolean;
  begin
    Result := Abs(Dot3(N, P) - D) < 1E-6;
  end;

  { Newell's normal of the outline; the same reading FaceNormal gives }
  function NormalOf(const E: TWorkEnt): TP3;
  var
    I, J, M: Integer;
    Acc: TP3;
  begin
    M := Length(E.Poly);
    Acc := P3(0, 0, 0);
    for I := 0 to M - 1 do
    begin
      J := (I + 1) mod M;
      Acc.X := Acc.X + (E.Poly[I].Y - E.Poly[J].Y) * (E.Poly[I].Z + E.Poly[J].Z);
      Acc.Y := Acc.Y + (E.Poly[I].Z - E.Poly[J].Z) * (E.Poly[I].X + E.Poly[J].X);
      Acc.Z := Acc.Z + (E.Poly[I].X - E.Poly[J].X) * (E.Poly[I].Y + E.Poly[J].Y);
    end;
    Result := Norm3(Acc);
  end;

begin
  SetLength(Lists, Count);
  SetLength(ELo, Count);
  SetLength(EHi, Count);
  for I := 0 to Count - 1 do
  begin
    SetLength(Lists[I], 0);
    { the extent of each thing that could lie on a face }
    case Ents[I].Kind of
      ekLine, ekDim, ekText:
        begin
          ELo[I] := Ents[I].A; EHi[I] := Ents[I].A;
          Grow(ELo[I], EHi[I], Ents[I].B);
        end;
      ekArc:
        begin
          ELo[I] := P3(Ents[I].C.X - Ents[I].R, Ents[I].C.Y - Ents[I].R, Ents[I].C.Z - Ents[I].R);
          EHi[I] := P3(Ents[I].C.X + Ents[I].R, Ents[I].C.Y + Ents[I].R, Ents[I].C.Z + Ents[I].R);
        end;
    end;
  end;
  for F := 0 to Count - 1 do
  begin
    if (Ents[F].Kind <> ekFace) or (Length(Ents[F].Poly) < 3) then Continue;
    N := NormalOf(Ents[F]);
    P0 := Ents[F].Poly[0];
    D := Dot3(N, P0);
    Lo := P0; Hi := P0;
    for K := 1 to High(Ents[F].Poly) do Grow(Lo, Hi, Ents[F].Poly[K]);
    Lo := P3(Lo.X - SLACK, Lo.Y - SLACK, Lo.Z - SLACK);
    Hi := P3(Hi.X + SLACK, Hi.Y + SLACK, Hi.Z + SLACK);
    for I := 0 to Count - 1 do
    begin
      if not (Ents[I].Kind in [ekLine, ekArc, ekDim, ekText]) then Continue;
      { only what reaches over the face at all }
      if (EHi[I].X < Lo.X) or (ELo[I].X > Hi.X) or (EHi[I].Y < Lo.Y) or (ELo[I].Y > Hi.Y) or
         (EHi[I].Z < Lo.Z) or (ELo[I].Z > Hi.Z) then Continue;
      if Ents[I].Kind = ekArc then
      begin
        A := Ents[I].C;
        B := ArcPoint(Ents[I].C, Ents[I].R, Ents[I].A0, Ents[I].Plane, Ents[I].Nm);
      end
      else
      begin
        A := Ents[I].A;
        B := Ents[I].B;
      end;
      if OnPlane(A) and OnPlane(B) then
      begin
        SetLength(Lists[I], Length(Lists[I]) + 1);
        Lists[I][High(Lists[I])] := F;
      end;
    end;
  end;
end;

type
  { The worker.  It owns a deep copy of the entities - the polygons copied,
    not shared, since the main thread edits them in place - computes on
    that, and queues one method back to the main thread.  It touches no
    part of the document, the surface or the screen.  It catches everything
    and says so through Failed; a worker never puts up a dialog. }
  TOnFaceWorker = class(TThread)
  public
    Doc: TWorkDoc;
    Seq: Integer;
    Ents: array of TWorkEnt;
    Lists: TIntArrayWArray;
    Ms: Double;
    DoneAt: QWord;
    Failed: Boolean;
    procedure Execute; override;
  end;

procedure TOnFaceWorker.Execute;
var
  T0: QWord;
begin
  try
    T0 := GetTickCount64;
    ComputeOnFace(Ents, Length(Ents), Lists);
    Ms := GetTickCount64 - T0;
  except
    Failed := True;
  end;
  DoneAt := GetTickCount64;
  { back on the main thread, when it next looks at its messages }
  Queue(@Doc.OnFaceArrived);
end;

{ Main thread only: the worker's result, taken if the drawing is still the
  one it was made from. }
procedure TWorkDoc.OnFaceArrived;
var
  W: TOnFaceWorker;
begin
  W := TOnFaceWorker(FOnFaceWorker);
  if W = nil then Exit;
  W.WaitFor;
  if W.Failed then Inc(OnFaceFailed)
  else if W.Seq <> FEditSeq then Inc(OnFaceDiscarded)
  else
  begin
    FOnFace := W.Lists;
    FOnFaceOK := True;
    OnFaceWorkerMs := W.Ms;
    OnFaceBuiltOn := 'a worker';
    OnFaceLagMs := GetTickCount64 - W.DoneAt;
    Inc(OnFaceBuilds);
  end;
  FOnFaceWorker := nil;
  W.Free;
end;

function TWorkDoc.OnFaceReady: Boolean;
begin
  Result := FOnFaceOK and (Length(FOnFace) = FLive);
end;

procedure TWorkDoc.EnsureOnFace;
var
  W: TOnFaceWorker;
  I: Integer;
  T0: QWord;
begin
  if OnFaceReady then Exit;
  if not Threads then
  begin
    Inc(OnFaceBuilds);
    T0 := GetTickCount64;
    ComputeOnFace(FEnts, FLive, FOnFace);
    OnFaceWorkerMs := GetTickCount64 - T0;
    OnFaceBuiltOn := 'the main thread';
    FOnFaceOK := True;
    Exit;
  end;
  { A queued result is only delivered when the main loop is idle, and a
    main thread painting frame after frame is never idle: measured on a
    drawing of fifty thousand things, a result that took 0.9 s to build
    waited 2.6 s more to be taken.  So look at the queue here, on the main
    thread, before deciding there is no cache. }
  if FOnFaceWorker <> nil then
  begin
    CheckSynchronize(0);
    if OnFaceReady then Exit;
  end;
  { one worker at a time; a change while it runs is caught by the sequence
    and the next call starts another }
  if FOnFaceWorker <> nil then Exit;
  W := TOnFaceWorker.Create(True);
  W.Doc := Self;
  W.Seq := FEditSeq;
  W.FreeOnTerminate := False;
  SetLength(W.Ents, FLive);
  for I := 0 to FLive - 1 do
  begin
    W.Ents[I] := FEnts[I];
    W.Ents[I].Poly := Copy(FEnts[I].Poly);
    W.Ents[I].Holes := nil;
    W.Ents[I].Txt := '';
  end;
  FOnFaceWorker := W;
  W.Start;
end;

function TWorkDoc.DepthPointNear(SX, SY, Radius: Integer; out P: TP3): Boolean;
var
  R, DX, DY, BX, BY: Integer;
  Z, Best, D2: Double;
  Q0, Look: TP3;
begin
  Result := False;
  P := P3(0, 0, 0);
  if (LastSurf = nil) or not LastSurf.DepthOn then Exit;
  Best := 1E30;
  BX := 0; BY := 0;
  { the nearest drawn pixel to the point, within Radius - a straight scan
    of the frame, a few milliseconds, once per press }
  for DY := Max(0, SY - Radius) to Min(LastSurf.Height - 1, SY + Radius) do
    for DX := Max(0, SX - Radius) to Min(LastSurf.Width - 1, SX + Radius) do
    begin
      D2 := Sqr(DX - SX) + Sqr(DY - SY);
      if D2 >= Best then Continue;
      Z := LastSurf.DepthAt(DX, DY);
      if Z < -1E29 then Continue;
      Best := D2; BX := DX; BY := DY;
    end;
  if Best >= 1E29 then Exit;
  R := 0;
  Z := LastSurf.DepthAt(BX, BY);
  { the depth is the distance along the view direction; a point on the
    ray through that pixel, slid to that depth, is the surface }
  Look := ViewDir(LastV);
  Q0 := Unproject(LastV, BX, BY, plXY, P3(0, 0, 0));
  if IsNan(Q0.X) or IsNan(Q0.Y) or IsNan(Q0.Z) then Exit;
  P := P3(Q0.X + Look.X * (Z - Dot3(Q0, Look)),
          Q0.Y + Look.Y * (Z - Dot3(Q0, Look)),
          Q0.Z + Look.Z * (Z - Dot3(Q0, Look)));
  Result := True;
end;

function TWorkDoc.DepthHidden(const P: TP3): Boolean;
var
  SP: TPointF;
  D, Zb, Zx, Zy, Grad: Double;
  Look: TP3;
begin
  Result := False;
  if (LastSurf = nil) or not LastSurf.DepthOn then Exit;
  SP := Project(LastV, P);
  Zb := LastSurf.DepthAt(Round(SP.X), Round(SP.Y));
  if Zb < -1E29 then Exit;
  Look := ViewDir(LastV);
  D := Dot3(P, Look);
  { the same reading as the renderer's own Covered: half the local slope of
    depth either way, capped, plus a little for the precision of the buffer }
  Zx := LastSurf.DepthAt(Round(SP.X) + 1, Round(SP.Y));
  if Zx < -1E29 then Zx := LastSurf.DepthAt(Round(SP.X) - 1, Round(SP.Y));
  Zy := LastSurf.DepthAt(Round(SP.X), Round(SP.Y) + 1);
  if Zy < -1E29 then Zy := LastSurf.DepthAt(Round(SP.X), Round(SP.Y) - 1);
  Grad := 0;
  if Zx > -1E29 then Grad := Grad + 0.5 * Abs(Zx - Zb) else Grad := Grad + 0.5 / Max(1E-9, LastV.Ppu);
  if Zy > -1E29 then Grad := Grad + 0.5 * Abs(Zy - Zb) else Grad := Grad + 0.5 / Max(1E-9, LastV.Ppu);
  Grad := Min(Grad, 6 / Max(1E-9, LastV.Ppu));
  Result := Zb > D + Grad + 2E-4 * (1 + Abs(D)) + 0.02 / Max(1E-9, LastV.Ppu);
end;

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
  { the depth buffer of the last render answers this in one lookup when the
    question is asked the way the render was made; anything else - another
    projector, no render yet - walks the faces as before }
  { field by field: the record has padding after its first byte that no
    two copies need agree on, so a byte compare said "different" every time
    and the fast path was never taken }
  if (LastSurf <> nil) and LastSurf.DepthOn and SameProjector(V, LastV) then
    Exit(DepthHidden(P));
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
  FSnapDirty := True; FOnFaceOK := False; Inc(FEditSeq);
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

{ What is under the cursor, when it was not an edge and not a face.

  This used to take the first thing it met within reach, walking the list
  newest first - so with two things in reach it answered "the one drawn most
  recently", which is a fact about the order you happened to work in and not
  about where you are pointing.  A note put down last could be taken from
  eight pixels away while the dimension dead under the cursor was passed
  over.  It now takes the nearest, and settles a tie the way EdgeUnder does:
  within a pixel of each other, the one nearer the eye.

  It costs a full walk where it used to stop early.  That is affordable
  because of where it sits: PickAt asks it only after HitEdge and HitFace
  have both come back with nothing, and HitEdge already walks the whole list
  without stopping. }
function TWorkDoc.HitTest(const V: TProjector; SX, SY, TolPx: Double): Integer;
const
  TIE_PX = 1.0;
var
  I: Integer;
  D, Best, Z, BestZ: Double;
  PA, PB: TPointF;
  DG: TDimGeom;
  Look, Mid: TP3;
  PC: TProjCache;
begin
  Result := -1;
  Best := 1E30;
  BestZ := -1E30;
  Look := ViewDir(V);
  { see HitEdge: the camera once for the walk, not once for every point }
  BeginProject(V, PC);
  for I := FLive - 1 downto 0 do
  begin
    if not InSlice(I) then Continue;
    { a guide that has been put away is not on the screen, so it is not under
      the cursor either - the same answer HitEdge gives }
    if (FEnts[I].Kind = ekGuide) and FGuidesHidden then Continue;
    case FEnts[I].Kind of
      ekArc:
        D := ArcScreenDistAt(PC, FEnts[I], SX, SY, TolPx);
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
            PA := ProjectAt(PC, FEnts[I].A);
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
        PA := ProjectAt(PC, FEnts[I].A);
        PB := ProjectAt(PC, FEnts[I].B);
        D := DistToSeg(SX, SY, PA.X, PA.Y, PB.X, PB.Y);
      end;
    end;
    { Within reach at all, then the nearest wins; a tie inside a pixel goes
      to whatever is nearer the eye, because at that range the two are the
      same place on the glass and the order they were drawn in is not an
      answer.  Faces and bores set D above every tolerance and drop out here. }
    if D > TolPx then Continue;
    Mid := Lerp3(FEnts[I].A, FEnts[I].B, 0.5);
    Z := Dot3(Mid, Look);
    if (Result < 0) or (D < Best - TIE_PX) or
       ((D < Best + TIE_PX) and (Z > BestZ + 1E-9)) then
    begin
      { An edge behind a panel is out of sight, so it is not what was meant.
        Notes and dimensions are drawn over the top of everything and stay
        pickable wherever they are.  Asked only of a candidate that would
        win, so a clear view costs nothing. }
      if FEnts[I].Kind in [ekLine, ekArc] then
      begin
        { the distance was worked out above; it was being worked out again
          here into a variable nothing read, on every entity of every hit
          test - which is every time the mouse moves }
        if HiddenAt(V, Mid) and
           HiddenAt(V, Lerp3(FEnts[I].A, FEnts[I].B, 0.25)) and
           HiddenAt(V, Lerp3(FEnts[I].A, FEnts[I].B, 0.75)) then
          Continue;
      end;
      if D < Best then Best := D;
      BestZ := Z;
      Result := I;
    end;
  end;
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
    beat a midpoint or a center, but a corner somebody actually drew is more
    likely to be the thing being aimed at than the place the model happens to
    start - and near the origin is exactly where people draw corners. }
  BIAS: array[TSnapKind] of Double =
    (0, 0, 3.5, 1.0, 2.0, 1.5, 0.25, 0, 0, 3.0, 0, 2.0);   { snOnFace: found separately too }
var
  I: Integer;
  P: TPointF;
  D, Best: Double;
  PC: TProjCache;
begin
  if FSnapDirty then RebuildSnapCache;

  if (not FSnapScreenOK) or (Length(FSnapScreen) <> Length(FSnapCache)) or
     (not SameProjector(V, FSnapScreenV)) then
  begin
    SetLength(FSnapScreen, Length(FSnapCache));
    { thousands of points, and the camera worked out once for the lot }
    BeginProject(V, PC);
    for I := 0 to High(FSnapCache) do
      FSnapScreen[I] := ProjectAt(PC, FSnapCache[I].P);
    FSnapScreenV := V;
    FSnapScreenOK := True;
  end;

  Best := 1E30;
  Hit.Kind := snNone;
  Hit.P := P3(0, 0, 0);

  for I := 0 to High(FSnapCache) do
  begin
    P := FSnapScreen[I];
    if (Abs(SX - P.X) > TolPx) or (Abs(SY - P.Y) > TolPx) then Continue;
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
  I, J, K, Cur: Integer;
  Line: string;
begin
  { Groups.  A record is a GROUP line - id, locked, the group it sits in,
    then its name, which can have spaces and so goes last.  Membership is a
    PARTOF line written whenever it changes from one entity to the next,
    and it applies to everything after it: far fewer lines than one field
    more on every entity, and - the same trick as MATERIAL and HOLE - a
    reader that has never heard of either skips them and gets the drawing
    flattened, which is exactly what it should get. }
  Cur := 0;
  for I := 0 to FLive - 1 do
  begin
    if (FEnts[I].Kind <> ekPart) and (FEnts[I].Part <> Cur) then
    begin
      Cur := FEnts[I].Part;
      L.Add(Format('PARTOF %d', [Cur]));
    end;
    case FEnts[I].Kind of
      ekPart:
        L.Add(TrimRight(Format('GROUP %d %d %d %s',
          [FEnts[I].Grp, Ord(FEnts[I].Solid), FEnts[I].Part, EscapeNote(FEnts[I].Txt)])));
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
          { What it is painted with, on a line of its own - so a reader that
            has never heard of a material skips it and gets the face it
            always got, and a face nobody has painted writes nothing at all
            and its file is byte for byte what it was. }
          if FEnts[I].MatSet then
            L.Add(Format('MATERIAL %d', [FEnts[I].Mat]));
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
      if Assigned(Progress) and ((Idx and 1023) = 0) then
        if not Progress('Reading the drawing', Idx / L.Count) then Break;
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
      else if (Kind = 'MATERIAL') and (T.Count >= 2) and (LastFace >= 0) and
              (LastFace < FLive) then
        SetMaterial(LastFace, StrToIntDef(T[1], 0))
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
      else if (Kind = 'PARTOF') and (T.Count >= 2) then
        { everything from here on belongs to this group - the creators stamp
          it, so nothing per kind has to know }
        FStamp := StrToIntDef(T[1], 0)
      else if (Kind = 'GROUP') and (T.Count >= 4) then
      begin
        Room;
        Finalize(FEnts[FLive]);
        FillChar(FEnts[FLive], SizeOf(TWorkEnt), 0);
        FEnts[FLive].Kind := ekPart;
        FEnts[FLive].Grp := StrToIntDef(T[1], 0);
        FEnts[FLive].Solid := T[2] = '1';
        FEnts[FLive].Part := StrToIntDef(T[3], 0);
        FEnts[FLive].Txt := UnescapeNote(JoinFrom(T, 4));
        Inc(FLive);
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
  { the file is read; new geometry goes back to the drawing itself }
  FStamp := 0;
  FContext := 0;
  RecountParts;
end;

{ SVG export - real vectors, so it opens in Inkscape or a CAD package at the
  same size it prints. }
function TWorkDoc.WriteSCAD(L: TStrings; U: TUnitSystem;
  out Solids: Integer; out Closed: Boolean; AtOrigin: Boolean): Integer;
var
  FS: TFormatSettings;
  Scale: Double;
  Mid, BLo, BHi: TP3;
  Grp, Top, I, J, K, NPt, NTri, Slot: Integer;
  Tris: TTriList;
  Corners: TP3Array;
  Nm, A, B, C, Cr, E1, E2: TP3;
  Ix: TFPHashList;
  Key: string;
  Pts: TP3Array;
  Names: TStringList;
  Row: string;
  Open_: Boolean;
  Made: Boolean;

  { A point's slot in this solid's list, adding it if it is new.  Welding
    matters here in a way it does not for STL: STL repeats a corner for every
    triangle that touches it and nobody minds, but a polyhedron is points AND
    faces, and two copies of one corner leave a seam CGAL will refuse to
    close. }
  function SlotOf(const P: TP3): Integer;
  begin
    Key := Format('%d,%d,%d', [Round(P.X * 1E6), Round(P.Y * 1E6),
                               Round(P.Z * 1E6)]);
    Result := Ix.FindIndexOf(Key);
    if Result >= 0 then
    begin
      Result := PtrInt(Ix.Items[Result]) - 1;
      Exit;
    end;
    if NPt >= Length(Pts) then SetLength(Pts, Max(64, NPt * 2));
    Pts[NPt] := P;
    Ix.Add(Key, Pointer(PtrInt(NPt) + 1));
    Result := NPt;
    Inc(NPt);
  end;

begin
  Result := 0;
  Solids := 0;
  { the same question the STL answers on the way out, and for the same
    person: OpenSCAD will render a surface that is not closed and the printer
    will not }
  Closed := True;
  for I := 0 to FLive - 1 do
  begin
    if FEnts[I].Kind <> ekFace then Continue;
    if Length(FEnts[I].Poly) < 3 then Continue;
    if FEnts[I].Solid and (FEnts[I].Grp > 0) and
       not GroupClosed(FEnts[I].Grp) then Closed := False;
    if not FEnts[I].Solid then Closed := False;
  end;
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  if U = usMetric then Scale := 1000 else Scale := 304.8;
  { Centerd across the bed and standing ON it - not centerd in Z, which
    buries the bottom half of the thing in the build plate.  See WriteSTL. }
  Mid := P3(0, 0, 0);
  if AtOrigin and Bounds(BLo, BHi) then
    Mid := P3((BLo.X + BHi.X) / 2, (BLo.Y + BHi.Y) / 2, BLo.Z);

  Top := 0;
  for I := 0 to FLive - 1 do
    if (FEnts[I].Kind = ekFace) and (FEnts[I].Grp > Top) then Top := FEnts[I].Grp;

  Names := TStringList.Create;
  try
    L.Add('// Heckers Sketch - ' + FormatDateTime('yyyy-mm-dd hh:nn', Now));
    if AtOrigin then
      L.Add('// Millimeters, centered on the bed and standing on it.  A surface, not a')
    else
      L.Add('// Millimeters, where the drawing put it.  A surface, not a');
    L.Add('// construction - see the notes at');
    L.Add('// the bottom.');
    L.Add('');

    { Group 0 is everything loose, and it goes out too, in its own module, so
      nothing is silently dropped - but it is named for what it is. }
    for Grp := 0 to Top do
    begin
      Made := False;
      NPt := 0;
      NTri := 0;
      SetLength(Pts, 0);
      Ix := TFPHashList.Create;
      try
        Row := '';
        for I := 0 to FLive - 1 do
        begin
          if FEnts[I].Kind <> ekFace then Continue;
          if FEnts[I].Grp <> Grp then Continue;
          Tris := FaceCut(I);
          if Length(Tris) < 3 then Continue;
          Corners := FaceCorners(I);
          Nm := FaceNormal(I);
          for J := 0 to (Length(Tris) div 3) - 1 do
          begin
            if (Tris[J*3] >= Length(Corners)) or (Tris[J*3+1] >= Length(Corners))
              or (Tris[J*3+2] >= Length(Corners)) then Continue;
            A := Corners[Tris[J*3]];
            B := Corners[Tris[J*3+1]];
            C := Corners[Tris[J*3+2]];
            E1 := P3(B.X - A.X, B.Y - A.Y, B.Z - A.Z);
            E2 := P3(C.X - A.X, C.Y - A.Y, C.Z - A.Z);
            Cr := Cross3(E1, E2);
            if Sqrt(Sqr(Cr.X) + Sqr(Cr.Y) + Sqr(Cr.Z)) < 1E-12 then Continue;
            { turn it so the three run anticlockwise seen from outside, the
              same as STL does, and then write them out backwards, because
              that is what OpenSCAD asks for }
            if Dot3(Cr, Nm) < 0 then
            begin
              Cr := B;
              B := C;
              C := Cr;
            end;
            if Row <> '' then Row := Row + ', ';
            Row := Row + Format('[%d,%d,%d]',
              [SlotOf(C), SlotOf(B), SlotOf(A)]);
            Inc(NTri);
            if Length(Row) > 1200 then
            begin
              Names.Add('    ' + Row);
              Row := '';
            end;
          end;
        end;
        if Row <> '' then Names.Add('    ' + Row);
        Made := NTri > 0;

        if Made then
        begin
          Open_ := (Grp = 0) or not GroupClosed(Grp);
          if Grp = 0 then Key := 'hs_loose'
          else Key := Format('hs_solid_%d', [Grp]);
          if Open_ then
            L.Add(Format('// %s - %d triangles.  NOT a closed solid; OpenSCAD',
              [Key, NTri]))
          else
            L.Add(Format('// %s - %d triangles, closed.', [Key, NTri]));
          if Open_ then
            L.Add('// will render it but may refuse to cut with it.');
          L.Add('module ' + Key + '() {');
          L.Add('  polyhedron(');
          L.Add('    points=[');
          Row := '';
          for K := 0 to NPt - 1 do
          begin
            if Row <> '' then Row := Row + ', ';
            Row := Row + Format('[%.4f,%.4f,%.4f]',
              [(Pts[K].X - Mid.X) * Scale, (Pts[K].Y - Mid.Y) * Scale,
               (Pts[K].Z - Mid.Z) * Scale], FS);
            if Length(Row) > 1200 then
            begin
              L.Add('      ' + Row + ',');
              Row := '';
            end;
          end;
          if Row <> '' then L.Add('      ' + Row);
          L.Add('    ],');
          L.Add('    faces=[');
          for K := 0 to Names.Count - 1 do
            if K < Names.Count - 1 then L.Add('  ' + Names[K] + ',')
            else L.Add('  ' + Names[K]);
          L.Add('    ],');
          { concavity is not the word - convexity is a hint about how many
            times a ray can cross the surface, and the preview draws concave
            shapes wrongly without it }
          L.Add('    convexity=10);');
          L.Add('}');
          L.Add('');
          Names.Clear;
          Inc(Solids);
          Inc(Result, NTri);
          if Grp = 0 then Slot := 0 else Slot := Grp;
          if Slot >= 0 then ;
        end
        else
          Names.Clear;
      finally
        Ix.Free;
      end;
    end;

    if Solids = 0 then
    begin
      L.Add('// This drawing has no faces, so there is no shape to describe.');
      Exit;
    end;

    L.Add('module heckers_sketch() {');
    L.Add('  union() {');
    for Grp := 0 to Top do
    begin
      Made := False;
      for I := 0 to FLive - 1 do
        if (FEnts[I].Kind = ekFace) and (FEnts[I].Grp = Grp) and
           (Length(FaceCut(I)) >= 3) then
        begin
          Made := True;
          Break;
        end;
      if not Made then Continue;
      if Grp = 0 then L.Add('    hs_loose();')
      else L.Add(Format('    hs_solid_%d();', [Grp]));
    end;
    L.Add('  }');
    L.Add('}');
    L.Add('');
    L.Add('heckers_sketch();');
    L.Add('');
    L.Add('// Notes.');
    L.Add('// This is the surface of the drawing, written as points and');
    L.Add('// faces.  It is not built out of cubes and cylinders and cannot');
    L.Add('// be taken apart into them, so the sizes here are not parameters');
    L.Add('// to change - to change the shape, change it in Heckers Sketch');
    L.Add('// and export it again.');
    L.Add('// What it is good for is everything around it: cut holes in it,');
    L.Add('// union it onto something, fit it to a part you are describing.');
  finally
    Names.Free;
  end;
end;

function TWorkDoc.WriteSTL(St: TStream; U: TUnitSystem;
  out Closed: Boolean; AtOrigin: Boolean): Integer;
var
  I, J, N: Integer;
  Mid, BLo, BHi: TP3;
  Tris: TTriList;
  Corners: TP3Array;
  Nm, A, B, C, E1, E2, Cr, Tmp: TP3;
  Scale, L2: Double;
  Head: array[0..79] of Byte;
  Cnt: LongWord;
  Attr: Word;
  Lbl: AnsiString;

  { a corner, in millimeters, measured from the middle of the model }
  procedure PutP(const P: TP3);
  var
    F: array[0..2] of Single;
  begin
    F[0] := (P.X - Mid.X) * Scale;
    F[1] := (P.Y - Mid.Y) * Scale;
    F[2] := (P.Z - Mid.Z) * Scale;
    St.WriteBuffer(F, SizeOf(F));
  end;

  { a direction, which has no units and must NOT be scaled - a normal 304.8
    long is not a normal }
  procedure PutN(const P: TP3);
  var
    F: array[0..2] of Single;
  begin
    F[0] := P.X;
    F[1] := P.Y;
    F[2] := P.Z;
    St.WriteBuffer(F, SizeOf(F));
  end;

begin
  Result := 0;
  Closed := True;
  if U = usMetric then Scale := 1000 else Scale := 304.8;
  { Where a slicer expects to find it: centerd across the bed, and STANDING
    ON it.

    This used to center all three axes, which puts the bottom half of the
    thing under the build plate.  Most slicers quietly lift it back out, so
    nothing ever looked broken - but "center it" means center it on the bed,
    and a model half underground is exactly the sort of thing somebody opens
    another program to put right before printing.  Which is what was
    happening: the step this option exists to remove was being done by hand
    in OpenSCAD. }
  Mid := P3(0, 0, 0);
  if AtOrigin and Bounds(BLo, BHi) then
    Mid := P3((BLo.X + BHi.X) / 2, (BLo.Y + BHi.Y) / 2, BLo.Z);

  { The header is 80 bytes of anything at all, except that it must not begin
    with the word "solid" - a reader that sees that decides the file is the
    ASCII kind and makes nothing of what follows. }
  FillChar(Head, SizeOf(Head), 0);
  Lbl := 'Heckers Sketch - millimeters';
  if Length(Lbl) > 79 then SetLength(Lbl, 79);
  Move(Lbl[1], Head[0], Length(Lbl));
  St.WriteBuffer(Head, SizeOf(Head));

  { the count goes in now as a placeholder and is written again at the end,
    when it is known }
  Cnt := 0;
  St.WriteBuffer(Cnt, SizeOf(Cnt));

  Attr := 0;
  for I := 0 to FLive - 1 do
  begin
    if FEnts[I].Kind <> ekFace then Continue;
    if Length(FEnts[I].Poly) < 3 then Continue;
    if FEnts[I].Solid and (FEnts[I].Grp > 0) and not GroupClosed(FEnts[I].Grp) then
      Closed := False;
    if not FEnts[I].Solid then Closed := False;

    Tris := FaceCut(I);
    if Length(Tris) < 3 then Continue;
    Corners := FaceCorners(I);
    Nm := FaceNormal(I);
    N := Length(Corners);

    for J := 0 to (Length(Tris) div 3) - 1 do
    begin
      if (Tris[J*3] >= N) or (Tris[J*3+1] >= N) or (Tris[J*3+2] >= N) then Continue;
      A := Corners[Tris[J*3]];
      B := Corners[Tris[J*3+1]];
      C := Corners[Tris[J*3+2]];
      E1 := P3(B.X - A.X, B.Y - A.Y, B.Z - A.Z);
      E2 := P3(C.X - A.X, C.Y - A.Y, C.Z - A.Z);
      Cr := Cross3(E1, E2);
      L2 := Sqrt(Sqr(Cr.X) + Sqr(Cr.Y) + Sqr(Cr.Z));
      if L2 < 1E-12 then Continue;   { no area, nothing to print }

      { STL wants the corners going anticlockwise seen from outside, which is
        the same as saying the triangle's own normal agrees with the face's.
        Which way the cutting happened to wind them is not our business, so
        turn the ones that disagree rather than trusting either. }
      if Dot3(Cr, Nm) < 0 then
      begin
        Tmp := B;
        B := C;
        C := Tmp;
        E1 := P3(B.X - A.X, B.Y - A.Y, B.Z - A.Z);
        E2 := P3(C.X - A.X, C.Y - A.Y, C.Z - A.Z);
        Cr := Cross3(E1, E2);
        L2 := Sqrt(Sqr(Cr.X) + Sqr(Cr.Y) + Sqr(Cr.Z));
        if L2 < 1E-12 then Continue;
      end;

      PutN(P3(Cr.X / L2, Cr.Y / L2, Cr.Z / L2));
      PutP(A);
      PutP(B);
      PutP(C);
      St.WriteBuffer(Attr, SizeOf(Attr));
      Inc(Result);
    end;
  end;

  { a drawing with no faces in it is not a closed solid, whatever the loop
    above never got the chance to say }
  if Result = 0 then Closed := False;

  { back over the placeholder with the real count }
  St.Position := 80;
  Cnt := Result;
  St.WriteBuffer(Cnt, SizeOf(Cnt));
  St.Position := St.Size;
end;

procedure TWorkDoc.WriteDXF(L: TStrings; const V: TProjector; U: TUnitSystem;
  ThreeD: Boolean; AtOrigin: Boolean = False);
var
  W: TDxfWriter;
  I, K, Steps, N: Integer;
  Sc, TX, TY, TZ, AX1, AY1, BX1, BY1: Double;
  XS, YS, ZS: array of Double;
  G: TDimGeom;
  Mid, BLo, BHi: TP3;

  { one point, in the file's units, flat or not }
  procedure At(const P: TP3; out X, Y, Z: Double);
  var
    S: TPointF;
  begin
    if ThreeD then
    begin
      X := (P.X - Mid.X) * Sc;
      Y := (P.Y - Mid.Y) * Sc;
      Z := (P.Z - Mid.Z) * Sc;
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
  { only in three dimensions: a flat view is already framed on its own
    middle by the projection it came through }
  Mid := P3(0, 0, 0);
  if ThreeD and AtOrigin and Bounds(BLo, BHi) then
    Mid := P3((BLo.X + BHi.X) / 2, (BLo.Y + BHi.Y) / 2, (BLo.Z + BHi.Z) / 2);
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
  PW, PH, WUnit: Double;
  Un, D: string;

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

  { The size of the thing, written down.

    This said width="842" and nothing else, which is eight hundred and forty
    two of nothing: the numbers inside are screen pixels at whatever zoom the
    view happened to be at, so a six inch part arrived in Inkscape, or a
    cutting machine, or a print shop, at an arbitrary size to be scaled back
    by hand.  In a program whose whole argument is that things are the size
    they say they are, that was the one file that did not say.

    The fix is two attributes.  The numbers inside stay exactly as they were
    - the viewBox is still in those pixels - and width and height give the
    real size in real units, which is what maps one to the other.  Ppu is
    pixels per world unit and the world unit is the foot, so the picture is
    (MaxX - MinX) / Ppu feet across.

    True size means the size of this view.  Square-on - a plan - that is the
    size of the thing itself, which is what anybody cutting or printing
    wants.  Turned, it is the size that picture would be, which is the only
    honest answer for a picture of a solid seen at an angle. }
  if V.Ppu > 1E-9 then WUnit := V.Ppu else WUnit := 1;
  if U = usImperial then
  begin
    PW := (MaxX - MinX) / WUnit * 12;      { feet to inches }
    PH := (MaxY - MinY) / WUnit * 12;
    Un := 'in';
  end
  else
  begin
    PW := (MaxX - MinX) / WUnit * 304.8;   { feet to millimeters }
    PH := (MaxY - MinY) / WUnit * 304.8;
    Un := 'mm';
  end;

  L.Add('<?xml version="1.0" encoding="UTF-8"?>');
  L.Add(Format('<svg xmlns="http://www.w3.org/2000/svg" ' +
    'width="%.3f%s" height="%.3f%s" viewBox="%.2f %.2f %.2f %.2f">',
    [PW, Un, PH, Un, MinX, MinY, MaxX - MinX, MaxY - MinY], FS));

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

  Quantized, so two corners that arrived at the same place by different
  arithmetic still name the same edge, and put in a fixed order so an edge
  walked one way round one face and the other way round its neighbor is
  recognized as the one edge it is. }
function EdgeKey(const A, B: TP3): string;
{ The two ends to a millionth, packed as six whole numbers in a string, the
  smaller end first so either way round is the same key.  It used to be
  written out with Format, and building two thousand of those was a quarter
  of every frame on a drawing full of pipe; the bytes compare just as well
  and cost nothing to make. }
var
  P, Q: array[0..2] of Int64;
  Swap: Boolean;
  I: Integer;
begin
  P[0] := Round(A.X * 1E6); P[1] := Round(A.Y * 1E6); P[2] := Round(A.Z * 1E6);
  Q[0] := Round(B.X * 1E6); Q[1] := Round(B.Y * 1E6); Q[2] := Round(B.Z * 1E6);
  Swap := False;
  for I := 0 to 2 do
    if P[I] <> Q[I] then
    begin
      Swap := P[I] > Q[I];
      Break;
    end;
  SetLength(Result, 48);
  if Swap then
  begin
    Move(Q[0], Result[1], 24);
    Move(P[0], Result[25], 24);
  end
  else
  begin
    Move(P[0], Result[1], 24);
    Move(Q[0], Result[25], 24);
  end;
end;

{ Faces farthest first by depth, with faces level to within rounding
  ordered bigger first, so a small face on a big one lands on top of it. }
procedure SortFaces(var Order: array of Integer; var Depth, Area: array of Double; N: Integer);
var
  TmpO: array of Integer;
  TmpD, TmpA: array of Double;
  I, J, K, RunEnd: Integer;
  Sh: Double;

  procedure Merge(Lo, Mid, Hi: Integer);
  var
    A, B, C: Integer;
  begin
    A := Lo; B := Mid; C := Lo;
    while (A < Mid) and (B < Hi) do
    begin
      if Depth[B] > Depth[A] then
      begin
        TmpO[C] := Order[B]; TmpD[C] := Depth[B]; TmpA[C] := Area[B]; Inc(B);
      end
      else
      begin
        TmpO[C] := Order[A]; TmpD[C] := Depth[A]; TmpA[C] := Area[A]; Inc(A);
      end;
      Inc(C);
    end;
    while A < Mid do begin TmpO[C] := Order[A]; TmpD[C] := Depth[A]; TmpA[C] := Area[A]; Inc(A); Inc(C); end;
    while B < Hi do begin TmpO[C] := Order[B]; TmpD[C] := Depth[B]; TmpA[C] := Area[B]; Inc(B); Inc(C); end;
    for C := Lo to Hi - 1 do
    begin
      Order[C] := TmpO[C]; Depth[C] := TmpD[C]; Area[C] := TmpA[C];
    end;
  end;

  procedure Sort(Lo, Hi: Integer);
  var
    Mid: Integer;
  begin
    if Hi - Lo < 2 then Exit;
    Mid := (Lo + Hi) div 2;
    Sort(Lo, Mid);
    Sort(Mid, Hi);
    Merge(Lo, Mid, Hi);
  end;

begin
  if N < 2 then Exit;
  SetLength(TmpO, N); SetLength(TmpD, N); SetLength(TmpA, N);
  Sort(0, N);
  { within a run of level faces, bigger first: the runs are short, so an
    insertion sort inside each is the right tool }
  I := 0;
  while I < N do
  begin
    RunEnd := I;
    while (RunEnd + 1 < N) and (Abs(Depth[RunEnd + 1] - Depth[I]) <= 1E-4 * (1 + Abs(Depth[I]))) do
      Inc(RunEnd);
    for J := I + 1 to RunEnd do
    begin
      K := Order[J]; Sh := Depth[J];
      { area is the key; depth rides along }
      TmpD[0] := Area[J];
      TmpO[0] := J - 1;
      while (TmpO[0] >= I) and (Area[TmpO[0]] < TmpD[0]) do
      begin
        Order[TmpO[0] + 1] := Order[TmpO[0]]; Depth[TmpO[0] + 1] := Depth[TmpO[0]]; Area[TmpO[0] + 1] := Area[TmpO[0]];
        Dec(TmpO[0]);
      end;
      Order[TmpO[0] + 1] := K; Depth[TmpO[0] + 1] := Sh; Area[TmpO[0] + 1] := TmpD[0];
    end;
    I := RunEnd + 1;
  end;
end;

procedure TWorkDoc.Render(S: TArtSurface; const V: TProjector;
  U: TUnitSystem; AFont: TFont; const LabelCol: TPix; EdgeW: Single);
var
  LSteps, Bisect: Integer;
  DG: TDimGeom;
  DA, DB: TP3;
  DSz: TSize;
  DTP: TPoint;
  Cand, AllFaces: TIntArrayW;
  OnFaceOK: Boolean;
  SlotOf: array of Integer;
  JJ: Integer;
  PlaneN: array of TP3;
  PlaneD: array of Double;
  PT: QWord;
  ZA, ZB, ZC, ZD1, ZD2, ZD3, ZDet, ZD, ZBest, ZDen: Double;
  Sxx, Sxy, Syy, Sx, Sy, Sn, Sdx, Sdy, Sd: Double;
  ZI2, ZI3, ZJ: Integer;
  { cutting a face that is not flat into triangles, so its depth is exact }
  TriPts: array of TPointF;
  TriZ: array of Double;
  Tris: TTriList;
  TriRing: TIndexRing;
  TriHoles: TIndexRings;
  Mesh: TDepthTris;
  TriDev, TriSize, TriDet, TDx, TDy: Double;
  MN, MI: Integer;
  ZOK, Drew: Boolean;  I, J, K, N, Steps, NFace: Integer;
  PA, PB: TPointF;
  Ang, Sh: Double;
  Col, Face: TPix;
  Look, Lamp, Cen, Nm: TP3;
  Order: array of Integer;
  Depth, Area: array of Double;
  Ar: Double;
  Flat: array of TPointF;
  Loops: array of TPtFLoop;
  EdgeIx: TFPHashList;
  EK: string;
  HK, HJ: Integer;
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

      The buffer is sampled at pixel centers and the point being asked about
      is not at one, so the two disagree by up to half a step of whatever the
      depth is doing locally.  Seen edge-on that step is large, and a line
      lying exactly on the surface it belongs to then loses to its own face by
      a hair and comes out dashed.  Measuring the step from the neighbors
      makes the tolerance follow the angle instead of being a guess. }
    { The slope is read from a neighbor; at the edge of a face the one
      side may be off the face - a loose face is not in the buffer at all -
      and then the other side is asked, and failing both, a 45 degree slope
      is assumed rather than none.  Assuming none is what drew the rear top
      edges of a pulled octagon as dashes. }
    Zx := S.DepthAt(Round(SP.X) + 1, Round(SP.Y));
    if Zx < -1E29 then Zx := S.DepthAt(Round(SP.X) - 1, Round(SP.Y));
    Zy := S.DepthAt(Round(SP.X), Round(SP.Y) + 1);
    if Zy < -1E29 then Zy := S.DepthAt(Round(SP.X), Round(SP.Y) - 1);
    { half a step in each direction, since the point can be half a pixel
      from the center both ways at once }
    Grad := 0;
    if Zx > -1E29 then Grad := Grad + 0.5 * Abs(Zx - Zb) else Grad := Grad + 0.5 / Max(1E-9, V.Ppu);
    if Zy > -1E29 then Grad := Grad + 0.5 * Abs(Zy - Zb) else Grad := Grad + 0.5 / Max(1E-9, V.Ppu);

    { Half a step, not a whole one: the point is within half a pixel of the

      center the buffer was sampled at, so half the local slope is all the

      disagreement a line on its own face can have.  A whole step let a line

      behind a face seen nearly edge-on through for several pixels past the

      face's edge - the bleed at a tunnel's mouth.  And the slope is capped

      at about an eighty degree tilt; steeper than that the face is its own

      silhouette and a line on it is at the edge anyway. }

    Grad := Min(Grad, 6 / Max(1E-9, V.Ppu));

    { The last term is for floating point, and only that.  It used to be a

      thousandth of the distance from the origin - half an inch of depth on

      a model fifty feet out - which let a crease receding behind a wall

      show for a few pixels past its corner. }

    { The buffer is single precision and each face's depth is interpolated
      across it, so at a hundred feet from the origin it is only good to a
      few ten-thousandths - a slack that scales with the distance is needed
      for a line on its own face to pass.  A fifth of what it was: enough
      for the precision, not enough for a crease behind a wall to show. }
    Result := Zb > D + Grad + 2E-4 * (1 + Abs(D)) + 0.02 / Max(1E-9, V.Ppu);
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
    for N := 1 to Bisect do
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

  { A dimension line parallel to the projected segment, always labeled with
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
    Ix := EdgeIx.FindIndexOf(EdgeKey(A, B));
    if Ix < 0 then Result := 0 else Result := PtrInt(EdgeIx.Items[Ix]);
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

  { Wholly off the screen, by a margin wide enough for line width and
    anti-aliasing: nothing drawn from it can reach a pixel, so it is left
    out of the frame.  Zoomed in on a corner of a big drawing this is most
    of the drawing. }
  function OffScreen(const PA, PB: TPointF): Boolean;
  const
    M = 8;
  begin
    Result := ((PA.X < -M) and (PB.X < -M)) or ((PA.X > S.Width + M) and (PB.X > S.Width + M)) or
              ((PA.Y < -M) and (PB.Y < -M)) or ((PA.Y > S.Height + M) and (PB.Y > S.Height + M));
  end;

  function PolyOffScreen(const Poly: TP3Array): Boolean;
  const
    M = 8;
  var
    K: Integer;
    Q: TPointF;
    MinX, MaxX, MinY, MaxY: Double;
  begin
    MinX := 1E30; MaxX := -1E30; MinY := 1E30; MaxY := -1E30;
    for K := 0 to High(Poly) do
    begin
      Q := Project(V, Poly[K]);
      if Q.X < MinX then MinX := Q.X; if Q.X > MaxX then MaxX := Q.X;
      if Q.Y < MinY then MinY := Q.Y; if Q.Y > MaxY then MaxY := Q.Y;
    end;
    Result := (MaxX < -M) or (MinX > S.Width + M) or (MaxY < -M) or (MinY > S.Height + M);
  end;

  { The visible stretches of any world segment against face Slot - the
    sampling a line gets in the runs pass, for anything else that has to
    stop at a wall.  A dimension is three lines, and it used to come back
    whole once its middle was clear, so the parts behind a duct's walls
    showed through them. }
  procedure RunSeg(const WA, WB: TP3; W, Alpha: Single; const Col: TPix; Slot: Integer);
  var
    M, Run0: Integer;
    Vis: Boolean;
    RunT0, RunT1: Double;
    PA, PB: TPointF;
  begin
    Run0 := -1;
    RunT0 := 0;
    CurA := WA;
    CurB := WB;
    CurArc := -1;
    for M := 0 to LSteps do
    begin
      if M < LSteps then
        Vis := not Covered(Lerp3(WA, WB, (M + 0.5) / LSteps), Slot)
      else
        Vis := False;
      if Vis and (Run0 < 0) then
      begin
        Run0 := M;
        if M = 0 then RunT0 := 0
        else RunT0 := Boundary((M + 0.5) / LSteps, (M - 0.5) / LSteps, Slot);
      end;
      if (not Vis) and (Run0 >= 0) then
      begin
        if M = LSteps then RunT1 := 1
        else RunT1 := Boundary((M - 0.5) / LSteps, (M + 0.5) / LSteps, Slot);
        PA := Project(V, Lerp3(WA, WB, RunT0));
        PB := Project(V, Lerp3(WA, WB, RunT1));
        S.Line(PA.X, PA.Y, PB.X, PB.Y, W, Col, Alpha);
        Run0 := -1;
      end;
    end;
  end;

  procedure Mark(K: Integer);
  begin
    ProfMs[K] := ProfMs[K] + (GetTickCount64 - PT);
    PT := GetTickCount64;
  end;

begin
  S.BlendMode := bmNormal;
  GuideCol := MixPix(LabelCol, Pix(120, 90, 190), 0.55);

  if Quick then begin LSteps := 8; Bisect := 1; end
  else begin LSteps := LINE_STEPS; Bisect := 6; end;
  PT := GetTickCount64;
  { the edge index, once, before anything asks it a question }
  { a hash of edge keys to the number of visible faces along each: a sorted
    string list did this with a binary search and a memory move per insert,
    which on a drawing of pipe was a fifth of the frame }
  EdgeIx := TFPHashList.Create;
  try
    Look := ViewDir(V);
    for I := 0 to FLive - 1 do
    begin
      if FEnts[I].Kind <> ekFace then Continue;
      if not InSlice(I) then Continue;
      if FEnts[I].Solid and (Dot3(FaceNormal(I), Look) <= 0) then Continue;
      N := Length(FEnts[I].Poly);
      for J := 0 to N - 1 do
      begin
        EK := EdgeKey(FEnts[I].Poly[J], FEnts[I].Poly[(J + 1) mod N]);
        K := EdgeIx.FindIndexOf(EK);
        if K < 0 then EdgeIx.Add(EK, Pointer(PtrInt(1)))
        else EdgeIx.Items[K] := Pointer(PtrInt(EdgeIx.Items[K]) + 1);
      end;
    end;

  for I := 0 to FLive - 1 do
  begin
    { Out of the slice is out of the drawing.  Said in every pass, because
      each of them walks the entities for itself. }
    if not InSlice(I) then Continue;
    Col := InkPix(I);
    case FEnts[I].Kind of
      ekFace: ;   // already painted
      ekLine:
        begin
          if Hidden(I) then Continue;
          PA := Project(V, FEnts[I].A);
          PB := Project(V, FEnts[I].B);
          if OffScreen(PA, PB) then Continue;
          S.Line(PA.X, PA.Y, PB.X, PB.Y, LineW(I), Col);
        end;

      ekArc:
        begin
          if FEnts[I].Soft then Continue;   { a seam of a spun or swept surface }
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


  Mark(0);
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
    if (FEnts[I].Kind = ekFace) and (Length(FEnts[I].Poly) >= 3) and
       InSlice(I) and
       not (FEnts[I].Solid and GroupClosed(FEnts[I].Grp) and
            (Dot3(FaceNormal(I), Look) <= 0)) then
    begin
      { The back of a closed solid is not drawn, because it cannot be seen.

        Culling by the sign of the normal was taken out once, and rightly:
        a duct transition is an open shell with an end at each end whose
        normals point opposite ways, and the rule made one of them
        unreachable from wherever you happened to be standing.  So it was
        left to the depth buffer.

        But the depth buffer cannot always get it right.  A face that is not
        flat has no true depth, only a fitted one, and a revolve is full of
        warped quads - so where the fit is off the far side of the solid
        wins and paints its inside over the near side in pale blue.  Fitting
        every corner instead of three got the error down from five hundred
        feet to twelve, and twelve is still enough for a sliver of it in the
        crevices, which is what the owner photographed off his monitor.

        The two cases can be told apart, so tell them apart.  A closed solid
        cannot show you the back of any of its faces - to see one you would
        have to be inside it - so drawing one is always wrong, whatever the
        depth buffer thinks.  An open shell can, so it still does.

        Every face is drawn, and the depth buffer decides what shows.

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
      if PolyOffScreen(FEnts[I].Poly) then Continue;
      Order[NFace] := I;
      Depth[NFace] := Dot3(Cen, Look);
      Area[NFace] := FaceArea(I);
      Inc(NFace);
    end;

  Mark(1);
  { Farthest from the camera first.  Where two faces are level to within
    rounding - a circle drawn on a slab is exactly that - the bigger one goes
    first, so the small one lands on top of it rather than underneath. }
  { An insertion sort here was the square of the face count, which is
    nothing at fifty faces and most of a frame at five thousand.  Sort by
    depth properly, then walk the runs of faces that are level with each
    other and put the bigger ones first within each run. }
  SortFaces(Order, Depth, Area, NFace);

  { every face's plane, once.  The pass that puts lines back on visible
    faces asks every line against every face, and working the normal out
    afresh each time was most of a frame on a drawing full of pipe. }
  SetLength(PlaneN, NFace);
  SetLength(PlaneD, NFace);
  SetLength(SlotOf, FLive);
  for I := 0 to FLive - 1 do SlotOf[I] := -1;
  for I := 0 to NFace - 1 do
  begin
    PlaneN[I] := FaceNormal(Order[I]);
    PlaneD[I] := Dot3(PlaneN[I], FEnts[Order[I]].Poly[0]);
    SlotOf[Order[I]] := I;
  end;
  EnsureOnFace;
  OnFaceOK := OnFaceReady;
  if not OnFaceOK then
  begin
    SetLength(AllFaces, NFace);
    for I := 0 to NFace - 1 do AllFaces[I] := Order[I];
    Inc(OnFaceFallbacks);
  end;
  S.DepthBegin;
  for I := 0 to NFace - 1 do
  begin
    K := Order[I];
    SetLength(Flat, Length(FEnts[K].Poly));
    for J := 0 to High(FEnts[K].Poly) do
      Flat[J] := Project(V, FEnts[K].Poly[J]);
    Nm := FaceNormal(K);
    Col := InkPix(K);
    { What this face is made of.  A face that has been painted shows the
      material it was painted with, at full strength - SketchUp's way, and
      the whole point of keeping a material apart from the pen.  One that
      has never been painted keeps what faces have always looked like here:
      the near-white default carrying a hint of the pen that drew it. }
    if FEnts[K].MatSet then
      Face := ColorToPix(FEnts[K].Mat)
    else
      Face := MixPix(Col, FACE_MATERIAL, 0.92);
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
      { Three corners that actually make a triangle on the screen.

        It used to take the first three, whichever they were, and that is
        where a solid of revolution comes apart.  A revolve is made of long
        thin gores; take the first three corners of one and they are very
        nearly in a line, so ZDet - which is twice the area of the triangle
        they make, in square pixels - comes out a rounding error, and the
        gradients solved by dividing by it are nonsense.  A face with a
        nonsense depth plane hides things it is behind and fails to hide
        things it is in front of, so the far side of a closed solid shows
        through the near side - in the back-face color, because the far
        side of anything is its inside.

        the crown, 13 September: the geometry was perfect - closed,
        every edge shared once each way, and a positive volume - and only
        two of its hundred and sixty-eight back faces were genuinely
        visible.  All the rest of the blue was this.

        So: the corner furthest from the first, then the corner furthest
        from the line between them.  That is the best-conditioned triangle
        the polygon has, found in two passes, and the threshold can then be
        a real area rather than a number chosen to let anything through. }
      ZI2 := 0;
      ZBest := 0;
      for ZJ := 1 to High(Flat) do
      begin
        ZD := Sqr(Flat[ZJ].X - Flat[0].X) + Sqr(Flat[ZJ].Y - Flat[0].Y);
        if ZD > ZBest then begin ZBest := ZD; ZI2 := ZJ; end;
      end;
      ZI3 := 0;
      ZBest := 0;
      if ZI2 > 0 then
        for ZJ := 1 to High(Flat) do
          if ZJ <> ZI2 then
          begin
            ZD := Abs((Flat[ZI2].X - Flat[0].X) * (Flat[ZJ].Y - Flat[0].Y) -
                      (Flat[ZJ].X - Flat[0].X) * (Flat[ZI2].Y - Flat[0].Y));
            if ZD > ZBest then begin ZBest := ZD; ZI3 := ZJ; end;
          end;
      { Then fit the plane through ALL of them, not through those three.

        Three corners is only right if the face is flat, and a good many are
        not.  A revolve turns a sloped piece of the outline into a warped
        quad - four corners off a curved surface, which no plane passes
        through - and so does anything pushed out of one.  On the crown,
        48 of its 336 faces were out of flat, the worst by five feet, and
        fitting a plane through three corners of one of those left the other
        corner up to five hundred feet out in depth on a model two hundred
        feet across.  Far more than enough for the far side of the solid to
        win the depth test and paint over the near side, which is what he
        was seeing.

        And it is directional, which is the part he spotted and I did not:
        whether the badly fitted plane tilts toward the camera or away from
        it depends on which way the warp is turned, so the fault appeared on
        faces pointing one way round the shape and not the other.

        Least squares over every corner instead.  A warped face still has no
        true plane - nothing can give it one - but the error is spread thin
        and centerd rather than being zero at three corners and anything at
        all everywhere else.  The widest-triangle corners above are kept as
        the starting point and the fallback.

        This stayed after the faces started being cut into triangles, and on
        purpose.  It is the right answer outright for a flat face, which is
        most of them and which then skips the cutting entirely; it covers the
        band of faces too nearly flat to be worth cutting; and it is what a
        pixel falls back to in the sliver along an edge that no triangle
        quite reaches. }
      if (ZI2 > 0) and (ZI3 > 0) then
      begin
        ZDet := (Flat[ZI2].X - Flat[0].X) * (Flat[ZI3].Y - Flat[0].Y) -
                (Flat[ZI3].X - Flat[0].X) * (Flat[ZI2].Y - Flat[0].Y);
        { a hundredth of a square pixel: below that the face really is
          edge-on and has no depth of its own worth solving }
        if Abs(ZDet) > 1E-2 then
        begin
          { the normal equations for depth = A*x + B*y + C }
          Sxx := 0; Sxy := 0; Syy := 0; Sx := 0; Sy := 0; Sn := 0;
          Sdx := 0; Sdy := 0; Sd := 0;
          for ZJ := 0 to High(Flat) do
          begin
            ZD := Dot3(FEnts[K].Poly[ZJ], Look);
            Sxx := Sxx + Flat[ZJ].X * Flat[ZJ].X;
            Sxy := Sxy + Flat[ZJ].X * Flat[ZJ].Y;
            Syy := Syy + Flat[ZJ].Y * Flat[ZJ].Y;
            Sx  := Sx  + Flat[ZJ].X;
            Sy  := Sy  + Flat[ZJ].Y;
            Sdx := Sdx + ZD * Flat[ZJ].X;
            Sdy := Sdy + ZD * Flat[ZJ].Y;
            Sd  := Sd  + ZD;
            Sn  := Sn  + 1;
          end;
          ZDen := Sxx * (Syy * Sn - Sy * Sy) - Sxy * (Sxy * Sn - Sy * Sx) +
                  Sx * (Sxy * Sy - Syy * Sx);
          if Abs(ZDen) > 1E-9 * (1 + Abs(Sxx) + Abs(Syy)) then
          begin
            ZA := (Sdx * (Syy * Sn - Sy * Sy) - Sxy * (Sdy * Sn - Sy * Sd) +
                   Sx * (Sdy * Sy - Syy * Sd)) / ZDen;
            ZB := (Sxx * (Sdy * Sn - Sd * Sy) - Sdx * (Sxy * Sn - Sy * Sx) +
                   Sx * (Sxy * Sd - Sdy * Sx)) / ZDen;
            ZC := (Sxx * (Syy * Sd - Sy * Sdy) - Sxy * (Sxy * Sd - Sdy * Sx) +
                   Sdx * (Sxy * Sy - Syy * Sx)) / ZDen;
            ZOK := True;
          end;
          if not ZOK then
          begin
            { three corners, the well-conditioned ones, as before }
            ZD1 := Dot3(FEnts[K].Poly[0], Look);
            ZD2 := Dot3(FEnts[K].Poly[ZI2], Look);
            ZD3 := Dot3(FEnts[K].Poly[ZI3], Look);
            ZA := ((ZD2 - ZD1) * (Flat[ZI3].Y - Flat[0].Y) -
                   (ZD3 - ZD1) * (Flat[ZI2].Y - Flat[0].Y)) / ZDet;
            ZB := ((ZD3 - ZD1) * (Flat[ZI2].X - Flat[0].X) -
                   (ZD2 - ZD1) * (Flat[ZI3].X - Flat[0].X)) / ZDet;
            ZC := ZD1 - ZA * Flat[0].X - ZB * Flat[0].Y;
            ZOK := True;
          end;
        end;
      end;
    end;
    if ZOK then S.DepthPlane(ZA, ZB, ZC)
    else S.DepthPlane(0, 0, -1E30);

    Sh := Min(1, 0.62 + 0.50 * Abs(Dot3(Nm, Lamp)));
    { A plan is a drawing, not a photograph taken from above, so the light
      goes out.

      The shading is what makes a 3D view read as a solid object, and in a
      plan it is noise with an opinion: two slopes of a roof come out
      different grays because they are tilted differently to a lamp that has
      no business being in a drawing at all, and a report came in asking what
      the grays meant.  Nothing.  Flat fill in plan, and the drawing is made
      of its lines again, which is what a drawing is made of. }
    if V.Kind = vkPlan then Sh := 1;
    { Which side of it are we looking at?  The back of a face gets its own
      color rather than the material.  A closed solid never shows one - its
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
    { --- an exact depth for a face that is not flat --------------------

          Everything above fits ONE plane to the face, which is the truth if
          the face is flat and a guess if it is not.  A good many are not: a
          revolve sweeps a sloped piece of an outline into a warped quad -
          four corners off a curved surface, which no plane passes through -
          and so does anything pushed or pulled out of one.  On the crown,
          48 of its 336 faces were out of flat, the worst corner five feet
          off its own face's plane, and the best fit that could be had for
          one of those was still out by hundreds of feet in depth.  That is
          the far side of a solid beating the near side in the depth test and
          painting over it - the blue faces, and the last of them.

          Cut it into triangles instead.  A triangle has exactly one plane
          and always lies in it, so there is nothing left to fit.  The fill
          is untouched and still one call - see DepthMesh for why it must be
          - and this only says how deep each pixel of it is.

          Flat faces skip all of it and keep the single plane, which costs
          nothing and is exactly right; on the crown that is 288 faces of the
          336.  A triangle is flat by definition and never gets here. }
    if ZOK and (Length(FEnts[K].Poly) > 3) then
    begin
      TriDev := 0;
      TriSize := 1;
      for ZJ := 1 to High(FEnts[K].Poly) do
      begin
        TDx := Abs(Nm.X * (FEnts[K].Poly[ZJ].X - FEnts[K].Poly[0].X) +
                   Nm.Y * (FEnts[K].Poly[ZJ].Y - FEnts[K].Poly[0].Y) +
                   Nm.Z * (FEnts[K].Poly[ZJ].Z - FEnts[K].Poly[0].Z));
        if TDx > TriDev then TriDev := TDx;
        TDy := Sqrt(Sqr(FEnts[K].Poly[ZJ].X - FEnts[K].Poly[0].X) +
                    Sqr(FEnts[K].Poly[ZJ].Y - FEnts[K].Poly[0].Y) +
                    Sqr(FEnts[K].Poly[ZJ].Z - FEnts[K].Poly[0].Z));
        if TDy > TriSize then TriSize := TDy;
      end;
      { a millionth of the face's own size out of flat is rounding, not warp }
      if TriDev > 1E-6 * TriSize then
      begin
        { Cut against what the camera actually shows, every frame.

          Cutting once in the face's own plane and keeping it was built and
          measured, because it looks like the obvious saving and it is what
          STL wants.  It is not worth it here, for two reasons found by
          measuring rather than by thinking about it.

          It does not save anything.  Every face in this program that is out
          of flat is a quad - a revolve sweeps its outline into gores, and a
          push does the same - and cutting a quad is two triangles.  On the
          crown, which is the worst drawing there is for this, keeping the cut
          saved one part in a hundred of a frame: 0.99 seconds against 1.00
          over 96 views, where doing none of this at all is 0.92.

          And it is not free of risk.  A cut made in the face's own plane
          need not still be a cut once the camera has had its way with it: a
          flat face is safe, because its plane and the screen are two views of
          one plane, but a face that is NOT flat has no plane and the two
          views are of points that lie in none.  On the crown the kept cut
          still held 77 percent of the time and folded over the other 23, and
          catching that needs a check of its own.

          So: FaceCut stays, because STL is model-space by nature and wants
          exactly that; the renderer does the simple thing. }
        SetLength(TriRing, Length(Loops[0]));
        for HJ := 0 to High(Loops[0]) do TriRing[HJ] := HJ;
        SetLength(TriHoles, Length(Loops) - 1);
        MN := Length(Loops[0]);
        for HK := 0 to High(FEnts[K].Holes) do
        begin
          SetLength(TriHoles[HK], Length(FEnts[K].Holes[HK]));
          for HJ := 0 to High(FEnts[K].Holes[HK]) do
          begin
            TriHoles[HK][HJ] := MN;
            Inc(MN);
          end;
        end;

        SetLength(TriPts, MN);
        SetLength(TriZ, MN);
        MN := 0;
        for HJ := 0 to High(Loops[0]) do
        begin
          TriPts[MN] := Loops[0][HJ];
          TriZ[MN] := Dot3(FEnts[K].Poly[HJ], Look);
          Inc(MN);
        end;
        for HK := 0 to High(FEnts[K].Holes) do
          for HJ := 0 to High(FEnts[K].Holes[HK]) do
          begin
            TriPts[MN] := Loops[HK + 1][HJ];
            TriZ[MN] := Dot3(FEnts[K].Holes[HK][HJ], Look);
            Inc(MN);
          end;

        if Triangulate(TriPts, TriRing, TriHoles, Tris) then
        begin
          SetLength(Mesh, Length(Tris) div 3);
          MN := 0;
          for MI := 0 to (Length(Tris) div 3) - 1 do
          begin
            ZI2 := Tris[MI * 3];
            ZI3 := Tris[MI * 3 + 1];
            ZJ := Tris[MI * 3 + 2];
            if (ZI2 >= Length(TriPts)) or (ZI3 >= Length(TriPts)) or
               (ZJ >= Length(TriPts)) then Continue;
            TriDet := (Double(TriPts[ZI3].X) - TriPts[ZI2].X) *
                        (Double(TriPts[ZJ].Y) - TriPts[ZI2].Y) -
                      (Double(TriPts[ZJ].X) - TriPts[ZI2].X) *
                        (Double(TriPts[ZI3].Y) - TriPts[ZI2].Y);
            { a hundredth of a square pixel: below that it is an edge-on
              sliver with no depth of its own to give, and the fitted plane
              is left to cover the pixel or two it might have owned }
            if Abs(TriDet) < 1E-2 then Continue;
            Mesh[MN].AX := TriPts[ZI2].X;  Mesh[MN].AY := TriPts[ZI2].Y;
            Mesh[MN].BX := TriPts[ZI3].X;  Mesh[MN].BY := TriPts[ZI3].Y;
            Mesh[MN].CX := TriPts[ZJ].X;   Mesh[MN].CY := TriPts[ZJ].Y;
            Mesh[MN].ZA :=
              ((TriZ[ZI3] - TriZ[ZI2]) * (Double(TriPts[ZJ].Y) - TriPts[ZI2].Y) -
               (TriZ[ZJ] - TriZ[ZI2]) * (Double(TriPts[ZI3].Y) - TriPts[ZI2].Y)) / TriDet;
            Mesh[MN].ZB :=
              ((TriZ[ZJ] - TriZ[ZI2]) * (Double(TriPts[ZI3].X) - TriPts[ZI2].X) -
               (TriZ[ZI3] - TriZ[ZI2]) * (Double(TriPts[ZJ].X) - TriPts[ZI2].X)) / TriDet;
            Mesh[MN].ZC := TriZ[ZI2] - Mesh[MN].ZA * TriPts[ZI2].X -
                                       Mesh[MN].ZB * TriPts[ZI2].Y;
            Mesh[MN].ZLo := Min(TriZ[ZI2], Min(TriZ[ZI3], TriZ[ZJ]));
            Mesh[MN].ZHi := Max(TriZ[ZI2], Max(TriZ[ZI3], TriZ[ZJ]));
            Inc(MN);
          end;
          SetLength(Mesh, MN);
          if MN > 0 then S.DepthMesh(Mesh);
        end;
      end;
    end;

    if (Dot3(Nm, ViewDir(V)) < 0) and (V.Kind <> vkPlan) then
      S.FillLoops(Loops, DimIf(K, ShadePix(FACE_BACK, Sh)), 1.0)
    else if V.Kind = vkPlan then
      { Paler in plan than in the 3D view.  A fill is there to say "this is
        material, not a hole"; in a drawing it must not compete with the
        lines, which are the part that carries the information.  Front and
        back are the same color here on purpose - looking straight down, one
        of them is the underside of a floor, and a plan has nothing to say
        about that. }
      { A painted face is shown as painted even here: somebody chose that
        color on purpose, and washing it out would be second-guessing them.
        An unpainted one stays pale, so it cannot compete with the lines. }
      if FEnts[K].MatSet then
        S.FillLoops(Loops, DimIf(K, Face), 1.0)
      else
        S.FillLoops(Loops, DimIf(K, MixPix(Face, Pix(255, 255, 255), 0.55)), 1.0)
    else
      S.FillLoops(Loops, DimIf(K, ShadePix(Face, Sh)), 1.0);
    { No outline.  Every boundary of a face is a real edge and gets drawn as
      one, so stroking the polygon as well laid a second line over the first -
      which is most of why the edges of a solid looked heavier than the lines
      they were made of. }
  end;


  Mark(2);
  { --- lines that live on a visible face -------------------------------
        The face pass runs after the edges so that a solid hides whatever is
        behind it, but that also buries the lines drawn ON its surface.
        Those are put back here: a line counts if both ends sit in the plane
        of a face that survived the culling. }
  for I := 0 to FLive - 1 do
  begin
    if not (FEnts[I].Kind in [ekLine, ekArc, ekDim, ekText]) then Continue;
    if not InSlice(I) then Continue;
    { a softened crease that is not an outline stays hidden whatever face
      it lies on - said once here, not once per face }
    if (FEnts[I].Kind = ekLine) and Hidden(I) then Continue;
    if (FEnts[I].Kind in [ekLine, ekDim]) and
       OffScreen(Project(V, FEnts[I].A), Project(V, FEnts[I].B)) then Continue;
    { the faces this thing lies on, from the cache; every face while the
      cache is still being built on its worker }
    Drew := False;
    if OnFaceOK then Cand := FOnFace[I] else Cand := AllFaces;
    for JJ := 0 to High(Cand) do
    begin
      K := Cand[JJ];
      J := SlotOf[K];
      if J < 0 then Continue;
      Nm := PlaneN[J];
      Sh := PlaneD[J];
      if FEnts[I].Kind = ekArc then
      begin
        { an arc lies in a face when its middle and its rim do }
        if Abs(Dot3(Nm, FEnts[I].C) - Sh) >= 1E-6 then Continue;
        if Abs(Dot3(Nm, ArcPoint(FEnts[I].C, FEnts[I].R, FEnts[I].A0,
             FEnts[I].Plane, FEnts[I].Nm)) - Sh) >= 1E-6 then Continue;
      end
      else if (Abs(Dot3(Nm, FEnts[I].A) - Sh) >= 1E-6) or
              (Abs(Dot3(Nm, FEnts[I].B) - Sh) >= 1E-6) then Continue;
      Col := InkPix(I);
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
          for M := 0 to LSteps do
          begin
            if M < LSteps then
            begin
              T0 := M / LSteps;
              T1 := (M + 1) / LSteps;
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
              else RunT0 := Boundary((M + 0.5) / LSteps, (M - 0.5) / LSteps, J);
            end;
            if (not Vis) and (Run0 >= 0) then
            begin
              if M = LSteps then RunT1 := 1
              else RunT1 := Boundary((M - 0.5) / LSteps, (M + 0.5) / LSteps, J);
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
          if FEnts[I].Soft then Continue;   { a seam of a spun or swept surface }
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
          { like a line: the stretches of its three lines that nothing
            stands in front of, the ticks and the figure where their place
            is clear }
          if DimGeometry(V, FEnts[I].A, FEnts[I].B, FEnts[I].C, U, DG, FEnts[I].Txt) then
          begin
            DA := P3(FEnts[I].A.X + FEnts[I].C.X, FEnts[I].A.Y + FEnts[I].C.Y, FEnts[I].A.Z + FEnts[I].C.Z);
            DB := P3(FEnts[I].B.X + FEnts[I].C.X, FEnts[I].B.Y + FEnts[I].C.Y, FEnts[I].B.Z + FEnts[I].C.Z);
            RunSeg(FEnts[I].A, DA, 1.0, 0.5, LabelCol, J);
            RunSeg(FEnts[I].B, DB, 1.0, 0.5, LabelCol, J);
            RunSeg(DA, DB, 1.2, 0.85, LabelCol, J);
            if not Covered(DA, J) then
              S.Line(DG.S1A.X, DG.S1A.Y, DG.S1B.X, DG.S1B.Y, 1.4, LabelCol, 0.9);
            if not Covered(DB, J) then
              S.Line(DG.S2A.X, DG.S2A.Y, DG.S2B.X, DG.S2B.Y, 1.4, LabelCol, 0.9);
            if not Covered(Lerp3(DA, DB, 0.5), J) then
            begin
              DSz := S.TextExtent(DG.Txt, AFont);
              DTP := DimTextTopLeft(DG, DSz.cx, DSz.cy);
              S.TextOut(DTP.X, DTP.Y, DG.Txt, AFont, LabelCol);
            end;
          end;
        ekText:
          if not Covered(FEnts[I].A, J) then
            Note(I, FEnts[I].A, FEnts[I].B, FEnts[I].Txt, Col);
      end;
      Drew := True;
      Break;
    end;

    { --- and the ones that lie on no face at all ----------------------

      A line drawn in mid air - the ridge of a roof, a brace across a bay -
      is coplanar with nothing.  It was drawn in the pass before the faces
      and then painted over by them, and the loop above only puts back what
      lies *in* a face's plane, so it never came back.  On screen the line
      stopped dead at the edge of the nearest solid and carried on past the
      far side of it, which is exactly what two reports described while
      trying to draw a gable.

      It cannot be put back wholesale either: some of it really is behind
      the geometry.  The depth buffer the faces just filled already knows
      which, per pixel, so the line is drawn through that instead of
      through a coplanarity test it can never pass. }
    if not Drew then
    begin
      S.DepthTest(True);
      case FEnts[I].Kind of
        ekLine:
          begin
            PA := Project(V, FEnts[I].A);
            PB := Project(V, FEnts[I].B);
            S.DepthAlong(PA.X, PA.Y, Dot3(FEnts[I].A, Look),
                         PB.X, PB.Y, Dot3(FEnts[I].B, Look));
            S.Line(PA.X, PA.Y, PB.X, PB.Y, LineW(I), InkPix(I));
          end;
        ekArc:
          if not FEnts[I].Soft then
          begin
            if FEnts[I].Sides >= 3 then Steps := FEnts[I].Sides
            else Steps := Max(24, Min(180,
              Round(Abs(FEnts[I].Sweep) * FEnts[I].R * V.Ppu / 6)));
            DA := ArcPoint(FEnts[I].C, FEnts[I].R, FEnts[I].A0,
                           FEnts[I].Plane, FEnts[I].Nm);
            PA := Project(V, DA);
            for K := 1 to Steps do
            begin
              DB := ArcPoint(FEnts[I].C, FEnts[I].R,
                FEnts[I].A0 + FEnts[I].Sweep * K / Steps,
                FEnts[I].Plane, FEnts[I].Nm);
              PB := Project(V, DB);
              S.DepthAlong(PA.X, PA.Y, Dot3(DA, Look),
                           PB.X, PB.Y, Dot3(DB, Look));
              S.Line(PA.X, PA.Y, PB.X, PB.Y, LineW(I), InkPix(I));
              PA := PB;
              DA := DB;
            end;
          end;
      end;
      S.DepthTest(False);
    end;
  end;

  { --- and what a plan cannot see, dashed ------------------------------

    A drawing shows what is underneath.  A camera does not, and until now
    this was a camera: a line with a face over it was painted and then
    painted over, and the information went with it.  That is the last of the
    three things that made a plan of a model look like a photograph of one.

    Only in PLAN, and deliberately.  In a 3D view a hidden line is hidden
    because it is round the back of something solid, and dashing all of them
    would put the far side of every box on top of the near side.  In a plan
    it is a beam over a door or a footing under a wall, and showing it is the
    whole convention.

    The depth buffer is still standing from the face pass, so this is one
    more walk of the lines with the test turned round: only the stretches
    that fail it are drawn, dashed, and faint enough to sit behind the solid
    work rather than compete with it. }
  if (V.Kind = vkPlan) and S.DepthOn then
  begin
    S.DepthTest(True);
    S.DepthBehind(True);
    for I := 0 to FLive - 1 do
    begin
      if not InSlice(I) then Continue;
      case FEnts[I].Kind of
        ekLine:
          begin
            if Hidden(I) then Continue;
            PA := Project(V, FEnts[I].A);
            PB := Project(V, FEnts[I].B);
            if OffScreen(PA, PB) then Continue;
            S.DepthAlong(PA.X, PA.Y, Dot3(FEnts[I].A, Look),
                         PB.X, PB.Y, Dot3(FEnts[I].B, Look));
            S.Line(PA.X, PA.Y, PB.X, PB.Y, LineW(I),
                   MixPix(InkPix(I), Pix(255, 255, 255), 0.45));
          end;
        ekArc:
          begin
            if FEnts[I].Soft then Continue;
            if FEnts[I].Sides >= 3 then Steps := FEnts[I].Sides
            else Steps := Max(24, Min(180,
              Round(Abs(FEnts[I].Sweep) * FEnts[I].R * V.Ppu / 6)));
            DA := ArcPoint(FEnts[I].C, FEnts[I].R, FEnts[I].A0,
                           FEnts[I].Plane, FEnts[I].Nm);
            PA := Project(V, DA);
            for K := 1 to Steps do
            begin
              DB := ArcPoint(FEnts[I].C, FEnts[I].R,
                FEnts[I].A0 + FEnts[I].Sweep * K / Steps,
                FEnts[I].Plane, FEnts[I].Nm);
              PB := Project(V, DB);
              S.DepthAlong(PA.X, PA.Y, Dot3(DA, Look),
                           PB.X, PB.Y, Dot3(DB, Look));
              S.Line(PA.X, PA.Y, PB.X, PB.Y, LineW(I),
                     MixPix(InkPix(I), Pix(255, 255, 255), 0.45));
              PA := PB;
              DA := DB;
            end;
          end;
      end;
    end;
    S.DepthBehind(False);
    S.DepthTest(False);
  end;

  if not OnFaceOK then OnFaceFallbackMs := GetTickCount64 - PT;
  Mark(3);
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
  Mark(4);
  LastSurf := S;
  LastV := V;
end;


initialization
  { see SurfaceGone: a borrowed depth buffer must not outlive the surface it
    belongs to }
  WatchSurfaceGone(@SurfaceGone);

end.
