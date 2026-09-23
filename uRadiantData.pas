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
  * Staple-up is built around 1/2" tube, because that is the size the
    aluminum transfer plates are made for; it needs insulation under it
    or the heat goes down into the joist bay instead of up through the
    floor.

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
  TRadiantFloor = (rfSlab, rfWood);

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

  { a coil's worth of waste - cutting losses and the length left on the
    spool that is never quite enough for one more run.  A trade rule, not
    a measured one. }
  WASTE_PCT_DEFAULT = 10.0;

  { slab defaults }
  SLAB_THICK_DEFAULT_IN = 4.0;
  SLAB_UNDER_R_DEFAULT = 15.0;

  { wood floor defaults }
  JOIST_SPACING_DEFAULT_IN = 16.0;
  SUBFLOOR_THICK_DEFAULT_IN = 0.75;
  WOOD_BELOW_R_DEFAULT = 19.0;

  { how a tie or a staple is spaced along a run - trade practice, not a
    printed spec; the ticket says so. }
  TIE_SPACING_IN = 15.0;

  { one manifold port, or fitting-adapter allowance, per loop plus the two
    for the feed and return mains - a placeholder count, not a substitute
    for the fitter's own parts list. }

function TubeOf(S: TTubeSize): TTubeFacts;

implementation

function TubeOf(S: TTubeSize): TTubeFacts;
begin
  Result := TUBE[S];
end;

end.
