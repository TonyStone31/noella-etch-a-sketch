unit uRadiantData;

{ What a hydronic radiant floor is built from, and the numbers a designer
  is expected to bring to the table.  Nothing here is this program's own
  opinion - it is what the tubing makers' install manuals and the Radiant
  Professionals Alliance's guidance agree on, gathered 23 September 2026 -
  and it is a starting point, not a substitute for a room-by-room heat
  loss calculation, which this unit does not attempt.

  Sourced facts, kept apart from the estimates below them:

  * Maximum loop length - the point past which the pump cannot push enough
    flow and the far end of the loop runs cold - is quoted close to the
    same figures everywhere it is written down: 3/8" 200-250 ft, 1/2"
    250-350 ft (300 ft is the number that keeps coming up), 5/8" 400-450
    ft, 3/4" 500-600 ft.  The low end of each band is kept here, because a
    plan is easier to shorten in the field than to explain why it ran long.
  * Minimum bend radius is eight times the tube's outer diameter for the
    stiffer PEX-B and PEX-C; PEX-A bends tighter, six times, but eight is
    the number that is safe whichever the job turns out to be carrying.
    3/8" (1/2" OD) 4", 1/2" (5/8" OD) 5", 5/8" (3/4" OD) 6", 3/4" (7/8" OD)
    7".
  * On-center spacing of 6" to 12" covers most residential slabs; 9" is
    the everyday default, tighter along outside walls and glass, looser
    over closets and low-loss interior floor.
  * A slab's tubing is centered in the pour; about 2" deep is as deep as
    is worth going before the floor's response to the thermostat gets
    sluggish.  A heated slab wants R-15 under it at least, commonly R-10
    to R-20 by climate, with the edge run at twice the field R-value.

  Estimates, not sourced the same way, and said so on the ticket: waste
  on the coil (10%), and how far apart a run is tied down or stapled.
  Both are ordinary trade knowledge, not a number printed in one place -
  the installer's own judgment on the day is worth more than this unit's
  guess, and the ticket says as much.

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE. }

{$mode objfpc}{$H+}

interface

type
  TTubeSize = (tsThreeEighth, tsHalf, tsFiveEighth, tsThreeQuarter);

  TTubeFacts = record
    Name: string;         { what the trade calls it - the nominal size }
    OdIn: Double;          { outer diameter, inches }
    MinBendIn: Double;     { the tightest a run can turn, inches - 8x OD }
    MaxLoopFt: Double;     { a safe everyday maximum circuit length, feet }
  end;

const
  TUBE_NAMES: array[TTubeSize] of string = ('3/8"  PEX', '1/2"  PEX', '5/8"  PEX', '3/4"  PEX');

  TUBE: array[TTubeSize] of TTubeFacts = (
    (Name: '3/8"'; OdIn: 0.500; MinBendIn: 4.0; MaxLoopFt: 200),
    (Name: '1/2"'; OdIn: 0.625; MinBendIn: 5.0; MaxLoopFt: 300),
    (Name: '5/8"'; OdIn: 0.750; MinBendIn: 6.0; MaxLoopFt: 400),
    (Name: '3/4"'; OdIn: 0.875; MinBendIn: 7.0; MaxLoopFt: 500)
  );

  { the everyday default and the range worth warning outside of, inches }
  SPACING_DEFAULT_IN = 9.0;
  SPACING_MIN_IN = 4.0;
  SPACING_MAX_IN = 18.0;

  { how far the outermost run and the ends of every run stay off a wall,
    and off an obstacle - trade practice, a hand's width, so the tube is
    never under a sill plate or a column's base }
  EDGE_INSET_IN = 6.0;

  { a coil's worth of waste - cutting losses and the length left on the
    spool that is never quite enough for one more run.  A trade rule, not
    a measured one. }
  WASTE_PCT_DEFAULT = 10.0;

  { slab defaults }
  SLAB_THICK_DEFAULT_IN = 4.0;
  SLAB_UNDER_R_DEFAULT = 15.0;

  { how a tie or a staple is spaced along a run - trade practice, not a
    printed spec; the ticket says so. }
  TIE_SPACING_IN = 15.0;

  { A manifold is sold by how many loops it takes: two through twelve is
    the range every maker offers (MrPEX, Uponor, SharkBite, PEXworx all
    stop at twelve), so a floor that wants more loops than that wants
    more manifolds.  A loop covers about its maximum length times the
    spacing, less the turns and the two leads to the manifold - which
    can be forty feet each on a big floor - and LOOP_AREA_FACTOR is the
    share of the maximum that is left to cover floor with.  Measured
    against the layouts this program makes, 0.7 lands within one loop
    of what is laid; 0.85 guessed four where six were needed.  That is
    how many a floor wants before anything is placed, and a suggested
    manifold has a port to spare over it. }
  MANIFOLD_PORTS_MIN = 2;
  MANIFOLD_PORTS_MAX = 12;
  { how far apart the connections sit along a manifold's body, and the
    only place tube is allowed off the grid: the first foot out of the
    manifold, where every loop's stub takes its own height so the
    connections can be followed by eye }
  MANIFOLD_PORT_PITCH_IN = 2.0;
  { how far out from the manifold the tube may be closer together than
    the spacing - the fan from the ports onto the grid.  The owner's
    number: about a foot. }
  MANIFOLD_FAN_IN = 13.0;
  { How far round a manifold its tubes may run closer than the spacing -
    down to the port pitch - before every one of them has to be out on
    the grid: the owner's rule, 24 September.  Four feet; the tubes are
    to be on the grid within three feet of run. }
  MANIFOLD_BREAKOUT_FT = 4.0;
  { how much of the floor a breakout has to cover to be kept - short of
    it, the next two feet wider is tried.  On the owner's barn (3/4" at
    12") six feet covers 95.0% with six loops and eight 96.9% with eight:
    the closer breakout and the smaller manifold are worth the two
    percent, so the bar sits under the first. }
  BREAKOUT_COVER = 0.93;
  { how many breakouts the search climbs through, two feet apart from
    MANIFOLD_BREAKOUT_FT: four, six, eight, ten, twelve.  Only as far as
    the floor needs - each is tried only when the one before fell short -
    and the ticket says which. }
  BREAKOUT_LEVELS = 5;
  LOOP_AREA_FACTOR = 0.7;
  { how far apart in length the loops on one manifold may be before the
    layout is tried again - the owner's rule of thumb: loops within ten
    or fifteen feet of each other balance; a 300 ft loop beside a 50 ft
    one never will. }
  LOOP_EVEN_FT = 15.0;
  { Growing a loop into bare floor beside it (uRadiant, GrowLoops), for
    whoever has to lay it.  A turn - the end of a pair of rows - is pushed
    out no less than this part of a spacing at a time, since a nudge is
    not worth the fitter's trouble.  A finger - a hairpin out of a
    straight run - is laid no shorter than this many spacings: every one
    is four bends, and a comb of short ones is the zigzag nobody wants to
    lay. }
  PUSH_MIN = 0.25;
  FINGER_MIN_SPACINGS = 6;
  { What a bend costs a layout in the search's ranking, against coverage
    and even loops (uRadiant, RankOf): a fifth of a point, where a
    percentage point of coverage short of the goal is fifty and one of
    evenness five.  So under the coverage goal the floor wins - about two
    hundred and fifty bends to a point - and over it, a finger has to be
    about eight feet long to earn its four bends.  The owner: mostly
    straight runs, minimal zigzags, "but we gotta do what we gotta do
    sometimes". }
  BEND_WEIGHT = 0.2;
  { a straight this many spacings long or more counts as a long run on
    the ticket's installer line }
  STRAIGHT_RUN_SPACINGS = 6;
  { how many solutions a search keeps for the wizard to step through }
  SOLUTIONS_KEPT = 24;
  { and how many feet of row left bare weigh the same as one more loop,
    when the layout is scored - a guess, the owner's to move }
  UNFILLED_LOOP_FT = 20.0;

function TubeOf(S: TTubeSize): TTubeFacts;

implementation

function TubeOf(S: TTubeSize): TTubeFacts;
begin
  Result := TUBE[S];
end;

end.
