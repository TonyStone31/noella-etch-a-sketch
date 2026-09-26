{ Generated from WHATS_NEW.md by build.sh - edit that, not this. }
const
  WHATS_NEW_MD =
    '# What''s New in Heckers Sketch' + LineEnding +
    '' + LineEnding +
    '<!--' + LineEnding +
    '  This is what people see after an update, and under Help > What''s new.' + LineEnding +
    '  Plain words about what changed for the person drawing; nothing about the' + LineEnding +
    '  insides.  Write under "Next release" while working; build.sh renames that' + LineEnding +
    '  heading to the tag when it cuts a release.  Sections are shown newest' + LineEnding +
    '  first, and an update shows only the ones newer than the version it' + LineEnding +
    '  replaced.  Headings: "## v2026.09.05.25" or "## Next release", then' + LineEnding +
    '  "### New" and "### Fixed", then "- " bullets.  Keep the bullets short.' + LineEnding +
    '-->' + LineEnding +
    '' + LineEnding +
    '## Next release' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **How far apart the loops are, in feet as well** - beside the' + LineEnding +
    '  percentage in the search window, the solution arrows, the evenness bar' + LineEnding +
    '  and the ticket: the longest loop less the shortest.' + LineEnding +
    '- **Change the goals while it searches.**  The search window has the two' + LineEnding +
    '  goals in it - lower one and it takes the best layout that meets the new' + LineEnding +
    '  goals and stops.  And **Give up after** - never, a minute, five, up to' + LineEnding +
    '  an hour a zone - keeping the best it found.' + LineEnding +
    '- **The search moves the manifold when it is stuck.**  After a while with' + LineEnding +
    '  nothing better it slides the manifold along its wall, a few feet at' + LineEnding +
    '  first and further the longer it goes, and tries forcing a loop or two' + LineEnding +
    '  more or fewer.  The manifold on the plan goes where the layout has it,' + LineEnding +
    '  and the ticket says how far it moved.' + LineEnding +
    '- **Square the manifold** - right-click it for east - west, north -' + LineEnding +
    '  south, or either diagonal.  A manifold on a curved wall starts square' + LineEnding +
    '  to the sheet.' + LineEnding +
    '- **A tab for every zone** in the radiant wizard: the zone''s manifold,' + LineEnding +
    '  how its search went, the layouts it found (click one to use it), and' + LineEnding +
    '  its material list - and an All zones tab.  Click a zone on the plan to' + LineEnding +
    '  bring its tab up.  The arrows and Replay search are gone.' + LineEnding +
    '- **The search keeps a record** - when it ran, how many layouts, how' + LineEnding +
    '  long, and what happened: goals changed, met or not, a manifold moved,' + LineEnding +
    '  stopped by hand, given up on time.  It is on the material list.' + LineEnding +
    '- **Export the submittal** - the system in brief, a schedule of the zones' + LineEnding +
    '  and of every loop, each zone''s material list and notes, and the design' + LineEnding +
    '  record with the other layouts each search kept.  As text for now; as a' + LineEnding +
    '  PDF, a zone to a page, when the PDF export takes pages of text.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A problem report sent from inside a dialog took a picture of the' + LineEnding +
    '  whole screen** - every monitor and every other program on them.  Now it' + LineEnding +
    '  is only this program''s own windows.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.25.1' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A compass.**  With the grid on, a small compass sits in a top corner' + LineEnding +
    '  of the drawing - north up the green axis, east along the red - and' + LineEnding +
    '  turns with the view in iso and 3D, keeping out of the view cube''s' + LineEnding +
    '  corner.  Where the axes meet they are labeled X, Y and Z (and -X, -Y,' + LineEnding +
    '  -Z).  The radiant wizard''s plan has a compass too.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Faces with a curved side no longer vanish.**  After a drawing was' + LineEnding +
    '  opened again, the first edit - deleting a radiant layout, say - could' + LineEnding +
    '  take every face with an arc for a side with it.  A drawing that has' + LineEnding +
    '  already lost them gets them back at its next edit.' + LineEnding +
    '- **The radiant wizard''s plan is your plan** - north up, the way the' + LineEnding +
    '  drawing shows it.  It was turned to line up with the longest wall and,' + LineEnding +
    '  on some drawings, mirrored; now a manifold turned a quarter lines up' + LineEnding +
    '  square with the walls.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.25' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **See what the radiant search has found while it works.**  The search' + LineEnding +
    '  window lists every layout found so far, best first - how much of the' + LineEnding +
    '  floor it covers, how close the loops come in length, loops, bends and' + LineEnding +
    '  tube.  Click one to keep it, or double-click to stop and keep it.' + LineEnding +
    '- **The radiant wizard remembers your settings** - tube, spacing,' + LineEnding +
    '  maximum loop, waste, goals and labels come back as you left them.' + LineEnding +
    '- **The ticket gives each manifold''s wall space** - roughly how much' + LineEnding +
    '  wall it wants for its connections, valves and end caps.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Rows stay at the spacing you asked for.**  Closing up the rows at a' + LineEnding +
    '  far wall so every row has a partner is now something the search' + LineEnding +
    '  tries only when a layout falls short of the goals or leaves floor' + LineEnding +
    '  bare - the last row an inch nearer the wall and an inch off each gap' + LineEnding +
    '  there, as few gaps as it takes - and keeps only when it is better.' + LineEnding +
    '  The ticket says when it did.' + LineEnding +
    '- **Suggest keeps manifolds off curved walls** - a manifold hangs on a' + LineEnding +
    '  flat wall, so the pieces of an arc or a circle are passed over.' + LineEnding +
    '- **Rooms laid at an angle, and round ones, are covered far better.**' + LineEnding +
    '  Where the manifold''s wall ran at a slant, the hairpins that fill bare' + LineEnding +
    '  floor could run straight through the rows beside them, and every' + LineEnding +
    '  such layout was thrown away.' + LineEnding +
    '- **Faster on floors with curved walls.**' + LineEnding +
    '' + LineEnding +
    '## v2026.09.24.11' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout searches only when you ask.**  Opening the' + LineEnding +
    '  wizard, dragging a manifold or typing a spacing no longer sets it' + LineEnding +
    '  off.  Search one zone, or all of them, from the buttons or by' + LineEnding +
    '  right-clicking a manifold.  A window shows how it is going, with' + LineEnding +
    '  **Stop - keep the best** (that zone keeps the best layout found and' + LineEnding +
    '  the next zone starts) and **Stop all**.' + LineEnding +
    '- **Goals.**  Tell it how much of the floor to cover and how close the' + LineEnding +
    '  loops should be in length (97% and 10% to start with).  It keeps' + LineEnding +
    '  trying different layouts until it gets there or you stop it, and' + LineEnding +
    '  the ticket says if it fell short.' + LineEnding +
    '- **Step through the solutions.**  The arrows above the plan show each' + LineEnding +
    '  layout the search found that met your goals, best first; the one' + LineEnding +
    '  showing is the one that gets built.' + LineEnding +
    '- **Manifolds are boxes you can turn.**  Drag them on the plan and' + LineEnding +
    '  right-click to turn one a quarter turn - the rows follow the way it' + LineEnding +
    '  faces.' + LineEnding +
    '- **Every loop its own color**, on the plan and on the drawing, so one' + LineEnding +
    '  run can be followed from the manifold out and back.' + LineEnding +
    '- **A built layout is made of groups.**  Each zone is a group named for' + LineEnding +
    '  its tube, spacing, loops and footage; inside it every loop is its own' + LineEnding +
    '  group, and all the labels are in one more.  Open a zone and click a' + LineEnding +
    '  loop to see its whole length and size in the panel.' + LineEnding +
    '- **Groups can be put away.**  `/hide` puts the picked groups away,' + LineEnding +
    '  `/hide labels` every group with "labels" in its name, and `/show`' + LineEnding +
    '  brings them back.  Put away groups are saved with the drawing.  The' + LineEnding +
    '  panel also shows any group''s total line length and size.' + LineEnding +
    '- **The ticket tells the installer** how many bends there are and how' + LineEnding +
    '  much of the tube runs in long straights.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Radiant layouts cover far more of the floor.**  No more bare strip' + LineEnding +
    '  running up the middle from the manifold, no more single row left bare' + LineEnding +
    '  along a far wall (the row count is now always even - the last two rows' + LineEnding +
    '  at the wall sit a little closer), and loops reach the ends of the' + LineEnding +
    '  walls.' + LineEnding +
    '- **Much less zigzag.**  Loops now fill bare floor by running their rows' + LineEnding +
    '  further, not with combs of short hairpins, and fewer bends is' + LineEnding +
    '  preferred once the floor is covered.' + LineEnding +
    '- **Tube leaves the manifold square**, with no long diagonal fan - every' + LineEnding +
    '  tube is on the grid within a few feet, wider only when the floor' + LineEnding +
    '  needs it, and the ticket says how wide.' + LineEnding +
    '- **Suggest puts each manifold in the middle of the wall that covers' + LineEnding +
    '  its zone best**, clear of obstacles in front of it.' + LineEnding +
    '- **Searching is faster**, and building uses the layout you searched' + LineEnding +
    '  instead of searching again.' + LineEnding +
    '- **A built manifold''s box no longer turns into a face** - selecting' + LineEnding +
    '  the floor again gave it an extra tiny zone.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.24.10' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout: floor blocked off by an obstacle right next' + LineEnding +
    '  to the manifold could never get tube, even when there was room' + LineEnding +
    '  past it.** That floor is now reachable when the layout can safely' + LineEnding +
    '  route to it.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.24.9' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout: watch the search itself.** A "Replay search"' + LineEnding +
    '  button above the plan re-runs the currently selected zone and plays' + LineEnding +
    '  back every lane it tried getting there - red for one turned back' + LineEnding +
    '  because it crossed tube already laid, green for the one that' + LineEnding +
    '  settled it - so a hard floor''s routing can be watched candidate by' + LineEnding +
    '  candidate instead of only seeing what it ended up with.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.24.8' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout: a manifold routing around an obstacle could' + LineEnding +
    '  draw tube crossing itself.**  Every candidate loop is now checked' + LineEnding +
    '  against every loop already laid before it is kept, the same test' + LineEnding +
    '  the finished ticket''s own crossing warning already used - so a' + LineEnding +
    '  manifold reaching around a no-go zone, especially one dragged off' + LineEnding +
    '  its wall, no longer risks a run through itself to get there.' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout: dragging a manifold or obstacle is smoother.**' + LineEnding +
    '  It used to relay out the whole floor on every twitch of the mouse;' + LineEnding +
    '  now it waits for the drag to settle before it recalculates, so the' + LineEnding +
    '  drag itself does not stutter.  The manifold still moves with the' + LineEnding +
    '  pointer right away - only the tube layout catches up a moment later.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.24.7' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout: a manifold can finally leave the wall.**  It' + LineEnding +
    '  used to hang on the nearest wall no matter where it was dragged; now' + LineEnding +
    '  it stays wherever it is let go, and the rows run outward from it in' + LineEnding +
    '  every direction that has floor - both ways along the wall, same as' + LineEnding +
    '  always, and now both ways across the room too when it is out in the' + LineEnding +
    '  open.  A manifold nearer the middle of a zone routinely reaches more' + LineEnding +
    '  of the floor, and the two gauges above the plan make the difference' + LineEnding +
    '  visible while dragging.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.24.6' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout: two gauges above the plan, live while a' + LineEnding +
    '  manifold is dragged.**  Coverage says how much of the floor the' + LineEnding +
    '  layout actually reaches; evenness says how close the loop lengths' + LineEnding +
    '  come to each other.  Both are bars now, not a line of small print -' + LineEnding +
    '  colored green, amber or red, and each says its own number in plain' + LineEnding +
    '  words.' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout: wood floor - joists is gone for now.**  The' + LineEnding +
    '  engine is being built and proved out against a concrete slab alone;' + LineEnding +
    '  carrying a second floor type through every part of it added work' + LineEnding +
    '  without adding anything to test with.  It will come back once the' + LineEnding +
    '  slab case is solid.  The slab''s own thickness, tube depth and' + LineEnding +
    '  under-slab insulation are off the dialog the same way, for the same' + LineEnding +
    '  reason - concrete slab, ordinary defaults, while the layout itself is' + LineEnding +
    '  what is being worked on.' + LineEnding +
    '- The label checkbox and the two new gauges no longer sit under the' + LineEnding +
    '  plan preview, unreadable - a real layout bug, not a hidden setting.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.24.5' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout: an obstacle near the manifold no longer' + LineEnding +
    '  pushes every lane on that side out of the way.**  When a no-go zone' + LineEnding +
    '  sat close to the manifold, the whole set of lanes for that side used' + LineEnding +
    '  to jump past its far edge - not just the one or two lanes that' + LineEnding +
    '  actually needed to - wasting everything in between.  That push now' + LineEnding +
    '  only reaches the first lane or two, right at the manifold; an' + LineEnding +
    '  obstacle farther out is left to the ordinary routing around it.' + LineEnding +
    '  Confirmed against an owner-reported drawing that was leaving over' + LineEnding +
    '  half a zone bare: the same zone now covers noticeably more of the' + LineEnding +
    '  floor, with nothing crossed and nothing run through the obstacle.' + LineEnding +
    '  Coverage there is still not complete - real work remains, tracked in' + LineEnding +
    '  the project notes.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.24.4' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout: the fan by the manifold now dodges a no-go' + LineEnding +
    '  zone too.**  Every other piece of tube was already checked against' + LineEnding +
    '  every obstacle; the short fan from each port to its grid lane, right' + LineEnding +
    '  beside the manifold, was not, and an obstacle sitting close enough to' + LineEnding +
    '  the manifold could put a fan line through it.  It is checked now, the' + LineEnding +
    '  same as everything else, and there is a permanent test for it.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.24.3' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout: a round no-go zone wastes less floor.**  A row' + LineEnding +
    '  is cut by the obstacle''s own outline now, a hand''s width wider all' + LineEnding +
    '  round, instead of by its bounding box - so a circular no-go zone' + LineEnding +
    '  costs the floor its own shape, not a square around it.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.24.2' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout: a no-go zone beside the manifold.**  The' + LineEnding +
    '  lanes out of the fan begin past any obstacle that sits in their way,' + LineEnding +
    '  instead of running through it; and the rows on the far side of the' + LineEnding +
    '  manifold found their near pieces again (they were read the wrong way' + LineEnding +
    '  round, which left the floor past an obstacle on that side bare).' + LineEnding +
    '- **Slanting walls.**  A triangle, or any wall that leans away from' + LineEnding +
    '  the manifold, starts its rows at the floor''s own edge, and a lane is' + LineEnding +
    '  only used where it lies inside the floor the whole way up.  A' + LineEnding +
    '  manifold in an acute corner cannot feed the rows above it and the' + LineEnding +
    '  ticket says how much is bare - move the manifold to the middle of a' + LineEnding +
    '  wall.' + LineEnding +
    '- The whole of a home row''s near part is taken on the way home round' + LineEnding +
    '  an obstacle, so no row beside it is left bare for parity''s sake.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.24.1' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout: the manifold box is gone, and the fan is a' + LineEnding +
    '  foot.**  The manifold hangs on the wall above the slab; the fan of' + LineEnding +
    '  tube out of its ports says where it is, and that fan now opens out' + LineEnding +
    '  onto the grid lanes within about thirteen inches of the wall - the' + LineEnding +
    '  only tube anywhere closer together than the spacing.  A label marks' + LineEnding +
    '  the manifold when labels are asked for.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.24' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout: no more corridor at the manifold.**  The tube' + LineEnding +
    '  out of each port no longer runs as a bundle, two inches from the' + LineEnding +
    '  next, all the way to its rows.  It opens out across a short fan onto' + LineEnding +
    '  a grid lane of its own - the ports are two inches apart and the grid' + LineEnding +
    '  a spacing, so the fan makes up the difference over about half that' + LineEnding +
    '  width, thinning from the manifold out - and goes up its lane to its' + LineEnding +
    '  rows at the same spacing as everything else.  The fan is the only' + LineEnding +
    '  tube off the grid.  Nothing crosses; the count on the ticket is' + LineEnding +
    '  still zero.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.23.9' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout: every loop is a snake.**  Out of its port' + LineEnding +
    '  straight to its row, along the row to the far end of the floor, a' + LineEnding +
    '  turn into the next row and back, out again on the one after, as many' + LineEnding +
    '  pairs as the maximum allows, and home down its other port - loop after' + LineEnding +
    '  loop outward from the manifold''s wall, one side of the manifold then' + LineEnding +
    '  the other.  Every foot of it is heater on the grid; the only tube off' + LineEnding +
    '  the grid is the two-inch stub out of each port.  A row cut by an' + LineEnding +
    '  obstacle turns at it, and the far side of the obstacle is reached by' + LineEnding +
    '  one loop that goes out on the clear row before it, round the far' + LineEnding +
    '  pieces, and home on the clear row past it, taking the near pieces' + LineEnding +
    '  under the obstacle on the way.  Nothing crosses and nothing touches -' + LineEnding +
    '  the ticket now counts every meeting of two runs, and it is zero.' + LineEnding +
    '- The loop limit is tried from the maximum down and the layout kept is' + LineEnding +
    '  the cheapest: a loop costs the same as fifteen feet of spread between' + LineEnding +
    '  the longest and the shortest loop, or twenty feet of row left bare.' + LineEnding +
    '- A manifold cannot be dragged out of its own zone.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.23.8' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout: runs go the zone''s long way, straight out' + LineEnding +
    '  from the manifold''s wall.**  The manifold hangs on the shorter wall of' + LineEnding +
    '  its zone and every loop runs out along a column, turns into the next,' + LineEnding +
    '  and comes back - as many pairs as the maximum allows - nearest the' + LineEnding +
    '  manifold first, then outward, mirror image either side of it.  Fewer,' + LineEnding +
    '  longer loops, and half the fan of leads along the wall that the last' + LineEnding +
    '  release made with twenty short ones.  Every turn is level.  A column' + LineEnding +
    '  cut by an obstacle turns at it; the far side is reached by a loop out' + LineEnding +
    '  on a clear column past it and home on the next, where the pairing' + LineEnding +
    '  lets it - what is not reached is on the ticket.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.23.7' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout: ports and stubs, and labels by choice.**  Each' + LineEnding +
    '  loop leaves and returns by its own two connections on the manifold,' + LineEnding +
    '  two inches apart along its body, with a short stub at its own height -' + LineEnding +
    '  the one place tube is off the grid - so the connections can be' + LineEnding +
    '  followed by eye.  The loop and manifold notes are off unless *Label' + LineEnding +
    '  the loops and manifolds on the drawing* is ticked: they were landing' + LineEnding +
    '  over the runs while the paths were being measured by hand.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.23.6' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout: the tube is laid the way a fitter lays it.**' + LineEnding +
    '  The rows run parallel to the wall the manifold hangs on.  A loop runs' + LineEnding +
    '  out along the row nearest the manifold as far as it can, turns into' + LineEnding +
    '  the neighbor and comes back; while it can afford another out-and-back' + LineEnding +
    '  under the maximum it keeps going up, and when it cannot it comes' + LineEnding +
    '  home.  Loops fill one side of the manifold and then the other, from' + LineEnding +
    '  the wall outward; every loop starts and ends at the manifold, and the' + LineEnding +
    '  run out of the manifold is floor heat like the rest - the only tube' + LineEnding +
    '  off the grid is the short climb at the manifold''s column to a loop''s' + LineEnding +
    '  first row.  Nothing crosses, nothing shares a path, everything is at' + LineEnding +
    '  right angles.  A row cut short by an obstacle turns there; what is' + LineEnding +
    '  beyond an obstacle, or a lone row with no neighbor to come back on,' + LineEnding +
    '  is said on the ticket as not reached.  The corridors, lanes and' + LineEnding +
    '  leads of the last three releases are gone.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.23.5' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The report window really closes now, from inside a wizard, on' + LineEnding +
    '  Linux too.**  The earlier fix reached Windows and not GTK; the window' + LineEnding +
    '  is modal once the report has gone, so its Close is its own.' + LineEnding +
    '- **Radiant heat layout:** the leads near a manifold run bundled at' + LineEnding +
    '  half the spacing, as they do in a slab, so the strip they take is half' + LineEnding +
    '  what it was and a zone no longer looks to empty out as its manifold' + LineEnding +
    '  is dragged; the loops are one line weight - thick and thin by turns' + LineEnding +
    '  read as doubled tube; the manifold''s size is a result now, on the' + LineEnding +
    '  ticket and in the list, not a box to fill in; and the Manifolds line' + LineEnding +
    '  is a gauge - how close the loops of each zone are to one another,' + LineEnding +
    '  green when they are - to watch while a manifold is dragged.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.23.4' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout: zones.**  Draw the floor as one big rectangle,' + LineEnding +
    '  draw lines across it where the heat zones divide, take out the faces' + LineEnding +
    '  that are no-go - then select everything and run the wizard.  Every' + LineEnding +
    '  face is a zone with a manifold of its own, in its own color; every' + LineEnding +
    '  removed face is a no-go; the manifolds are suggested at each zone''s' + LineEnding +
    '  corner nearest the middle of the building, so they end up near each' + LineEnding +
    '  other and the boiler, and each can be dragged.  The ticket is per zone' + LineEnding +
    '  with a total at the end.  One manifold a zone - to have two, draw a' + LineEnding +
    '  line across the zone.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Leads on any floor, not only a rectangle.**  On a floor that was not' + LineEnding +
    '  four-cornered every lead was a straight line back to the manifold' + LineEnding +
    '  over the top of every run.  The corridor of lanes now works on any' + LineEnding +
    '  outline, and a lead that leaves the floor or clips an obstacle is' + LineEnding +
    '  counted on the ticket.' + LineEnding +
    '- **Loops on a manifold are balanced**: the cuts between them are walked' + LineEnding +
    '  back and forth until the longest and shortest are as close as the' + LineEnding +
    '  rows allow, never over the maximum.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.23.3' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout: adding a manifold raised an exception** - the' + LineEnding +
    '  new row was picked in the list before the list had it.  Fixed.' + LineEnding +
    '- **The corridor of leads ran through obstacles** when there was more' + LineEnding +
    '  than one in its way: it moved past the first and landed on the next.' + LineEnding +
    '  It now moves until it is clear of all of them, and a loop''s lead comes' + LineEnding +
    '  into its row only where the corridor can see the row without an' + LineEnding +
    '  obstacle between.' + LineEnding +
    '- **No more hundred-foot joins.**  Where the walk went from one part of' + LineEnding +
    '  the floor to another the long way round, the tube followed it - a' + LineEnding +
    '  join of a hundred feet linking two areas, which put loops over the' + LineEnding +
    '  maximum with nothing to cut.  A long join is now where one loop ends' + LineEnding +
    '  and the next begins, each with its own lead from the manifold, and a' + LineEnding +
    '  loop that still comes out over is split on its own.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.23.2' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A report sent from inside a wizard could not be closed.**  The' + LineEnding +
    '  "Sending your report" window, opened from the radiant layout''s own' + LineEnding +
    '  *Report a problem* button, would not take Close or the X on Windows and' + LineEnding +
    '  the program looked hung.  It was shown while the wizard was up, and a' + LineEnding +
    '  window shown while another is modal is disabled with everything else' + LineEnding +
    '  unless it is that window''s own - which it is now.  The duct fitting' + LineEnding +
    '  wizard had the same fault.' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout: manifolds where you want them, zones, and the' + LineEnding +
    '  leads the way a fitter runs them.**  The wizard now says, the moment' + LineEnding +
    '  the floor is selected, how many loops it wants and how many manifolds' + LineEnding +
    '  of what size (two to twelve loops, what every maker sells), and puts' + LineEnding +
    '  them along the long wall - *Suggest*.  Drag any of them on the plan to' + LineEnding +
    '  where the mechanical room really is; *Add* another; give each its' + LineEnding +
    '  size.  The floor is shared out between them by distance, so each is a' + LineEnding +
    '  zone in its own color, its loops thick and thin by turns so two side' + LineEnding +
    '  by side can be told apart, and each loop carries its number and its' + LineEnding +
    '  footage on the drawing.  Obstacles can be added in the wizard too - a' + LineEnding +
    '  column, a shaft - and dragged into place; on Build they go onto the' + LineEnding +
    '  floor as a ring the program reads as a hole.  The leads no longer stack' + LineEnding +
    '  along a wall: they run out from the manifold in a corridor of lanes at' + LineEnding +
    '  the grid spacing, the outer lanes serving the nearest rows, and the' + LineEnding +
    '  corridor keeps clear of any obstacle.  A loop the layout cannot bring' + LineEnding +
    '  under the maximum is said on the ticket.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.23.1' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout, gone over.**  The runs were invisible on the' + LineEnding +
    '  sheet - they are drawn now, in the tube''s red, as reference lines that' + LineEnding +
    '  never close a face.  A join from one part of the floor to another, and' + LineEnding +
    '  a lead to the manifold, used to be a straight line across the field,' + LineEnding +
    '  through a column if that was nearest; both now go the way a fitter' + LineEnding +
    '  runs them, out to the wall and along it.  Runs keep six inches off' + LineEnding +
    '  every wall and obstacle.  A spacing tighter than the tube can turn is' + LineEnding +
    '  laid as asked and the ticket says which PEX can make the turn, instead' + LineEnding +
    '  of the pitch being doubled without a word.  Each loop''s length counts' + LineEnding +
    '  both its leads, so none comes out over the maximum after the cut.  The' + LineEnding +
    '  manifold is drawn as a box with its loop count.  On a wood floor the' + LineEnding +
    '  spacing follows the joists - two runs a bay, or however many you say.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.23' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Radiant heat layout, a new shop tool.**  Select the floor - a' + LineEnding +
    '  rectangle, or any face with as many corners as the room has - and' + LineEnding +
    '  *Shop > Radiant heat layout...* (or `/radiant`) asks the standard' + LineEnding +
    '  things a design wants: concrete slab or wood floor, the tube size, the' + LineEnding +
    '  spacing, and which corner of the room the manifold sits in.  It fills' + LineEnding +
    '  the floor with a real coverage path - the same problem a lawnmower or' + LineEnding +
    '  a crop sprayer solves - routes around any obstacle already cut into' + LineEnding +
    '  the floor as a hole (an elevator shaft, a column), and cuts the run' + LineEnding +
    '  into loops that come in under the tube''s maximum length and close to' + LineEnding +
    '  even with each other, the way a real design keeps circuits balanced.' + LineEnding +
    '  The plan and a full material list - tube footage with waste, ties,' + LineEnding +
    '  manifold ports - are shown before anything is built.  First version:' + LineEnding +
    '  the manifold is placed by typing how far in from a corner it sits,' + LineEnding +
    '  not yet by clicking the spot on the sheet; denser spacing along' + LineEnding +
    '  marked exterior walls, and trying a different route around a spot' + LineEnding +
    '  that looks wrong, are next.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.22.8' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A mannequin, from a jig.**  A seventh example: a woman six foot tall' + LineEnding +
    '  and a hundred and fifty pounds, standing on the floor, arms at her' + LineEnding +
    '  sides, there to be dressed.  The whole of her is one group made by the' + LineEnding +
    '  new `body` jig from those two numbers - right-click her, change' + LineEnding +
    '  `Height`, `Weight`, or give `Bust`, `Waist` and `Hip` outright, and run' + LineEnding +
    '  the jig again for another body.  Every edge of her is soft, so what' + LineEnding +
    '  shows is the shape.  She is where drawing clothes will start.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.22.7' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The point picker says so.**  Pressing *Pick* left the sheet looking' + LineEnding +
    '  the same, and it was not clear a pick was on or what it was for.  Now' + LineEnding +
    '  the sheet''s chip reads *PICKING* and names the part it is waiting for -' + LineEnding +
    '  `click a point for <corner>` - and the sheet is not dragged in front of' + LineEnding +
    '  the source window any more, so both stay where they were.  The pick' + LineEnding +
    '  fills the `<part>` the caret is in, not always the first one; a' + LineEnding +
    '  double-click on a `<part>` starts picking for it; and Esc in the editor' + LineEnding +
    '  ends it, the same as Esc on the sheet.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.22.6' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Pick a point from the sheet for the text.**  *Pick* in the source' + LineEnding +
    '  window turns the sheet into a point picker: each click, snapped exactly' + LineEnding +
    '  as the line tool snaps, is typed into the line the caret is on - a' + LineEnding +
    '  place; then, for a line, `to` and a place; for a box, rect or pull, `;`' + LineEnding +
    '  and the step from the first; for a circle, `;` and the radius.  The' + LineEnding +
    '  word list now fills a statement in with its parts - `box = <corner>;' + LineEnding +
    '  <size>` - and each pick takes the next `<part>`.  Esc on the sheet, or' + LineEnding +
    '  *Picking* in the window, ends it.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.22.5' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Jigs in the source window.**  A group made by a jig shows as its' + LineEnding +
    '  header and its `jig = ...` line; what the jig printed folds shut under' + LineEnding +
    '  that line, opened with the fold mark when you want to see it.  A play' + LineEnding +
    '  mark in the gutter beside the line runs that one jig again - right-click' + LineEnding +
    '  *Run jig* does the same for the line under the caret - and *Run jigs*' + LineEnding +
    '  on the toolbar still runs them all.  Inside the quotes of a jig line the' + LineEnding +
    '  word list offers the jigs in your folder.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.22.4' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A solid''s top could go missing, or come back twice, on the way' + LineEnding +
    '  through the text** when the same ring of corners was closed by two' + LineEnding +
    '  things'' edges - a cylinder standing in a washer''s hole.  A face the' + LineEnding +
    '  text also calls `noface` is written out now, and the sheet''s default' + LineEnding +
    '  ink and width are counted over everything rather than the first few' + LineEnding +
    '  hundred things, so the second write is the first.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.22.3' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A circle drawn with the tool was not a circle to `/source`** - it was' + LineEnding +
    '  an arc of 359.9999824°, a hair short of the way round after the file''s' + LineEnding +
    '  six decimals - so it was a block, the hole it cut was twenty-four' + LineEnding +
    '  corners instead of `hole = c1`, and a disk pulled up was a hundred' + LineEnding +
    '  lines instead of `pull = c1; 4 5/8" up`.  A whole circle within a hair' + LineEnding +
    '  is a whole circle.' + LineEnding +
    '- **A box, rect or pull drawn with a wider pen** - `width = 4` on every' + LineEnding +
    '  edge - was written as its edges, four lines each.  The block form' + LineEnding +
    '  carries `ink` and `width` now, once for all of them.' + LineEnding +
    '- **A circle by name only ever meant the disk facing the circle''s way**,' + LineEnding +
    '  and the bottom of a pulled disk faces the other way; it came back turned' + LineEnding +
    '  round.  Circles are written at the level, before what stands on them.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.22.2' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A drawn rectangle is `rect = corner; size`** in `/source` - the one' + LineEnding +
    '  fold that was read but not yet written.  Its `noface`, `box`, `rect`' + LineEnding +
    '  and `pull` are colored as the other words are.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.22.1' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **On Windows the source window came back behind the main window**, and' + LineEnding +
    '  not where it had been left.  It is the main window''s own now, in front' + LineEnding +
    '  of it, and it keeps its place.' + LineEnding +
    '- **Typing into the source window went astray** when the window had just' + LineEnding +
    '  been clicked into: its keyboard focus was on a checkbox, so a space' + LineEnding +
    '  toggled *Only picked*.  The text takes the keys now.' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **`/source complete off`** - the list of words the source window offers' + LineEnding +
    '  as you type stays away, and comes only on Ctrl+Space; `/source complete' + LineEnding +
    '  on` brings it back.  Remembered.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.22' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Faces are what closed lines become - in the text too.**  `/source`' + LineEnding +
    '  no longer lists a plain face beside the lines that already say it.  The' + LineEnding +
    '  lines are written; a face is only written when something about it is' + LineEnding +
    '  not automatic - a paint, a hole the lines would not cut, turned the' + LineEnding +
    '  other way - and a loop of lines that is *not* a face (rubbed out) is' + LineEnding +
    '  written `noface`, so it stays that way.  Type four lines that close and' + LineEnding +
    '  you get the face, as with the tool.  A cube is its eight corners and' + LineEnding +
    '  twelve edges and nothing more; the cube with a circle on its top is two' + LineEnding +
    '  lines: `circle c1 = 2'' east, 2'' north, 4'' up; 1''` and' + LineEnding +
    '  `box = 0 east, 0 north, 0 up; 4'' east, 4'' north, 4'' up`.  Twenty-six' + LineEnding +
    '  lines yesterday.' + LineEnding +
    '- **A plain circle is one line** - `circle c1 = center; radius`, and' + LineEnding +
    '  `; north` when it does not face up.' + LineEnding +
    '- **`pull` - what push/pull makes, in one line.**  A solid that is a flat' + LineEnding +
    '  outline gone some way is written as that: `pull = c1; 2'' up` is a' + LineEnding +
    '  cylinder, an L-shaped room eight feet high is its six floor corners and' + LineEnding +
    '  `by = 8'' up`, and typing either draws the whole thing.  Thirty lines' + LineEnding +
    '  for the room this morning; five now.' + LineEnding +
    '- **A postcard, if you like.**  On its second start the program asks,' + LineEnding +
    '  once, whether it may send us one note saying what sort of computer it is' + LineEnding +
    '  running on - and, if you care to say, what you want to use it for.  The' + LineEnding +
    '  whole of the text is on the screen before you answer, *No* is as big a' + LineEnding +
    '  button as *Yes*, and whichever you press it never asks again.  There is' + LineEnding +
    '  no serial number or identifier in it, and it goes the same encrypted way' + LineEnding +
    '  a bug report goes.  `/postcard` brings it back; `--offline` means it is' + LineEnding +
    '  never asked at all.  We are two people, and we cannot otherwise tell' + LineEnding +
    '  whether anyone is trying this.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A circle read from the text came out facing the wrong way** when the' + LineEnding +
    '  same circle was also a hole in a face above it - `hole = c1` turned the' + LineEnding +
    '  circle''s own corners round, and `face = c1` after it got them turned.' + LineEnding +
    '  Big drawings read back from `/source` were coming out with hundreds of' + LineEnding +
    '  faces flipped for the same reason.' + LineEnding +
    '- **Reading a big drawing back from the text was slow** - thirteen seconds' + LineEnding +
    '  for thirty thousand things, spent looking corner names up one by one.' + LineEnding +
    '  Now a fifth of a second.' + LineEnding +
    '- **A step a hair from nought was written as nothing** - `+ 14" west,' + LineEnding +
    '  north` - and would not read back.  And a walk of steps no longer' + LineEnding +
    '  drifts: each corner reads back as its own rounded self.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.21.8' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Push/pull among taller neighbors.**  Cut a block''s top into pieces,' + LineEnding +
    '  pull them to different heights, then push one back down - and the' + LineEnding +
    '  taller pieces beside it leaned over, or the pushed top turned inside out.' + LineEnding +
    '  A piece with a taller neighbor''s wall on its edge is now lifted out on' + LineEnding +
    '  its own, and pushed down it cuts a pocket; a push past the bottom of the' + LineEnding +
    '  block goes through it.' + LineEnding +
    '- **The source window completes what you type.**  Start a word and a list' + LineEnding +
    '  comes up on its own: at the start of a line, the things that can go' + LineEnding +
    '  there - `face`, `line`, `solid`, `points`... - or, inside a block, its' + LineEnding +
    '  properties with a hint of what goes after the `=`; after `=` or `to`,' + LineEnding +
    '  the names of the points and circles in the drawing; after a number, the' + LineEnding +
    '  six directions.  Enter or Tab takes one, Escape puts it away, and' + LineEnding +
    '  Ctrl+Space opens it on demand.' + LineEnding +
    '- **With the source window open, the pointer shows the line.**  Rest on a' + LineEnding +
    '  face or an edge with the select tool and the chip beside the pointer' + LineEnding +
    '  names the line of Heck it is, and shows it.  Only while the source' + LineEnding +
    '  window is open: the text behind a drawing is there to be found, not to' + LineEnding +
    '  be met with.' + LineEnding +
    '- **Right-click in the source window puts the caret where you clicked' + LineEnding +
    '  first**, so Go to Definition and Center in View act on the word and the' + LineEnding +
    '  line under the pointer.  The caret''s line is shaded, the text sits a' + LineEnding +
    '  little off the gutter, and a jump lands on the word.' + LineEnding +
    '- **Right-click in the source window.**  **Center in View** picks the thing' + LineEnding +
    '  on that line - or everything in the block, on a `solid` or `group` line -' + LineEnding +
    '  and brings it to the middle of the sheet, sized, gliding there.  **Go to' + LineEnding +
    '  Definition** jumps to where a name is given its meaning, and on a `jig`' + LineEnding +
    '  line there is **Run the Jig Again**.' + LineEnding +
    '- **Orbit turns about the middle of the screen, and turns like a ball.**' + LineEnding +
    '  Set beside SketchUp: it turned about the point under the pointer, at' + LineEnding +
    '  one speed, and read as spinning.  It turns about what is under the' + LineEnding +
    '  middle of the view now, the way theirs does - and how fast depends on' + LineEnding +
    '  where you take hold.  Press near the middle and it turns slowly, for' + LineEnding +
    '  fine work; press out at the edge and the same mouse spins it round.' + LineEnding +
    '  Like turning a ball by its face or by its rim.' + LineEnding +
    '- **The ring on a held point is gone.**  Rest on a corner and the dotted' + LineEnding +
    '  guide still runs from it; the ring drawn on the corner itself, which' + LineEnding +
    '  read as a mark left behind, does not.' + LineEnding +
    '- **Green means green.**  A line drawn in an axis color is now exactly on' + LineEnding +
    '  that axis when you click - to the end, whatever it snapped to on the way.' + LineEnding +
    '  Start a line an inch in from one side of a square, run it across to the' + LineEnding +
    '  other side along the green, and the far end is an inch in too.  It used' + LineEnding +
    '  to be allowed a degree of slop, which over a foot is an eighth of an' + LineEnding +
    '  inch, and a rectangle drawn inside a rectangle would not come out' + LineEnding +
    '  square.  A corner or an edge near the far end sets how far along the' + LineEnding +
    '  axis you go, and never pulls you off it.' + LineEnding +
    '- **Replaying a report picks the right face.**  A replayed press found its' + LineEnding +
    '  face under the pixel, which in another window is a different face; it' + LineEnding +
    '  finds the face the press landed on now.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.21.7' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The source window on a dark theme.**  It came up with a white page and' + LineEnding +
    '  line numbers that could not be read.  On any theme with dark panels the' + LineEnding +
    '  page, the gutter, the fold marks, the picked-line wash and the status' + LineEnding +
    '  line are dark now, with the axis colors lifted to read on it.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.21.6' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The window opens where you left it.**  It came back the right size' + LineEnding +
    '  and in the middle of the screen, every time, on Windows.  It comes back' + LineEnding +
    '  where it was.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.21.5' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **`box` and `rect` in the drawing''s text.**  A block that is still' + LineEnding +
    '  exactly a block - square, unpushed, no hole, one paint or none - is' + LineEnding +
    '  written in `/source` as one line, `box = 0 east, 0 north, 0 up; 4'' east,' + LineEnding +
    '  3'' north, 2'' up`, instead of its twelve lines and six faces, and typing' + LineEnding +
    '  that line draws the block.  Nudge one corner and it is written as its' + LineEnding +
    '  faces again.  `rect = corner; 4'' east, 3'' north` draws a rectangle the' + LineEnding +
    '  same way.  Both come in a block form with `at`, `size` and `paint`, and' + LineEnding +
    '  the source window offers them.  See `docs/primitives.md` for the rest' + LineEnding +
    '  of the set.' + LineEnding +
    '- **Corners named by where they stand.**  In `/source` a box''s corners are' + LineEnding +
    '  `floor1` to `floor4` and `top1` to `top4`, so `line = floor1 to top1` is' + LineEnding +
    '  an upright and `face = floor1 floor2 top2 top1` is a wall, and the text' + LineEnding +
    '  reads without the picture.  A hole cut in the top is `topin1`...' + LineEnding +
    '- **The source window is a tool window that can stay on top.**  Smaller,' + LineEnding +
    '  out of the taskbar, with an **On top** tick that is remembered - and it' + LineEnding +
    '  takes the program''s theme: dark text colors on a dark theme, light on a' + LineEnding +
    '  light one, with the axes'' red, green and blue either way.' + LineEnding +
    '- **A block''s opening word and its `end` are outlined together.**  Put' + LineEnding +
    '  the caret on `solid`, `group`, `ring` or any word that opens a block, or' + LineEnding +
    '  on its `end`, and both are boxed - Lazarus''s begin-and-end outline, for' + LineEnding +
    '  finding the end of a long block.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.21.4' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **An update is offered the moment the program starts.**  It used to say' + LineEnding +
    '  in the bar that a newer version was out and leave you to type `/update`.' + LineEnding +
    '  Now it asks there and then - yes fetches it and restarts with your' + LineEnding +
    '  drawings as they were, no leaves everything alone, and a version you' + LineEnding +
    '  have said no to is not offered again until you ask with `/update`.' + LineEnding +
    '- **The source window comes back.**  If it was open when you shut the' + LineEnding +
    '  program it opens again, where you left it and the size you left it.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The source window took letters and not much else.**  The arrow keys,' + LineEnding +
    '  Backspace, Delete, Enter, Home, End, copy and paste did nothing in it.' + LineEnding +
    '  They all work now.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.21.3' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A crash on opening a drawing while something was picked.**  Pick a' + LineEnding +
    '  thing in a big drawing, open a smaller one over it, and the pick was' + LineEnding +
    '  left pointing past the end of the new drawing - the entity panel, or' + LineEnding +
    '  anything else that looked at it, fell over.  Opening a file now lets go' + LineEnding +
    '  of what was picked, hovered and marked, the way changing sheets always' + LineEnding +
    '  has.  Apply in the source window and running a jig do the same.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.21.2' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Type in the source window and the drawing changes.**  `/source` is no' + LineEnding +
    '  longer only for reading.  Change a number - or write `+ 8"` on the end' + LineEnding +
    '  of a point - and an **Apply** bar appears; nothing on the sheet moves' + LineEnding +
    '  until you press it.  If what you typed does not read, the line is marked' + LineEnding +
    '  and it says why, and **Revert** puts the text back.  Apply is one undo' + LineEnding +
    '  step.  Sums work wherever a length goes, and a `const` block gives' + LineEnding +
    '  numbers names.  You can type a whole drawing: lines and circles, and the' + LineEnding +
    '  program works out the faces.' + LineEnding +
    '- **JIGs - Just Include Geometry.**  A group can say `jig = ''star'' with' + LineEnding +
    '  Points = 5, Radius = 2''`, and a little program of your own, in your own' + LineEnding +
    '  jigs folder, fills it: *a JIG is any program that prints Heck*, in any' + LineEnding +
    '  language.  Right-click the group for **Run the Jig Again**, or `/jig`.' + LineEnding +
    '  Nothing ever runs because a drawing was opened - the drawing keeps what' + LineEnding +
    '  the jig made - and a drawing can only name a jig, never carry one.' + LineEnding +
    '  Four come with the program and are written out to your **jigs** folder,' + LineEnding +
    '  beside the examples: a star in Pascal, a balloon in Python, a fence in' + LineEnding +
    '  Perl, and a flight of steps in shell *and* PowerShell - the same jig' + LineEnding +
    '  twice, so it runs on Windows with nothing installed.  Change one and it' + LineEnding +
    '  is yours: it is never written over.  The new **jigs** example shows all' + LineEnding +
    '  four, and **Sample** in the source window types the same drawing in for' + LineEnding +
    '  you to Apply.  Ctrl+click a `jig` line opens its program.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.21.1' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Round things read as rings.**  In `/source`, corners spaced evenly' + LineEnding +
    '  round a circle are said once - `ring ra`, its center, radius and how' + LineEnding +
    '  many sides - and a face round them is `face = ra1..ra24`.  A cylinder is' + LineEnding +
    '  about forty-five lines with no ugly numbers in it, where it was a' + LineEnding +
    '  hundred and fifty.  A tilted one says which way it leans.' + LineEnding +
    '- **The source window works like a code editor.**  Everything folds, and' + LineEnding +
    '  **Fold all** and **Unfold all** do it at a stroke.  **Ctrl and a click**' + LineEnding +
    '  on a name - a corner `c`, a ring''s `rb23`, a circle `c1` - goes to the' + LineEnding +
    '  line that says what it is.  **Rest the pointer on a name** and it tells' + LineEnding +
    '  you what it is and where it is: `c is at 4'' east, 4'' north, 4'' up`.  Put' + LineEnding +
    '  the caret on a name and every other place it is used is outlined.' + LineEnding +
    '  **Ctrl+F** finds, **F3** and **Shift+F3** find the next and the one' + LineEnding +
    '  before.  **Ctrl and the wheel** makes the text bigger or smaller.  And' + LineEnding +
    '  it is called **Heck** now - the language a drawing is written in.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.21' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The proposed drawing format, as it now reads.**  In `/source` a place' + LineEnding +
    '  is `1" east, 1" north, 0 up` - all three, always, so you can see it is' + LineEnding +
    '  on the floor, and with a word for each way no number is negative.' + LineEnding +
    '  Colored red, green and blue like the axes.  A line is two points,' + LineEnding +
    '  `line = a to b`, and that is all it is; a solid''s edges are lines you' + LineEnding +
    '  can pick like any other.  True and false are `true` and `false`.' + LineEnding +
    '  Nothing is saved in this format yet - it is there to be read and argued' + LineEnding +
    '  with, and `docs/format2.md` says where it is going: sums, constants,' + LineEnding +
    '  and groups that a script of your own makes.' + LineEnding +
    '- **The source window behaves like a code editor.**  Put the caret on a' + LineEnding +
    '  name and every other place it is used is outlined; Ctrl and a click goes' + LineEnding +
    '  to the line that says what it is; rest the pointer on it and it tells' + LineEnding +
    '  you - and for a corner written as a step from another, where that comes' + LineEnding +
    '  to.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.20.18' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The proposed drawing format, second go - shorter and easier to type.**' + LineEnding +
    '  In `/source`: heights are just `up`; a plain box is one line,' + LineEnding +
    '  `box = 0; 4'' east, 4'' north, 4'' up`; a list of places is a walk, each' + LineEnding +
    '  `+` step from the one before, so a square reads as four moves; a face' + LineEnding +
    '  bounded by a circle is `face = c1` and a circle cut out of a face is' + LineEnding +
    '  `hole = c1`, where there used to be thirty-two corners; `paint` for' + LineEnding +
    '  material; and no line is wider than eighty characters - a long list' + LineEnding +
    '  wraps between brackets the way a Lazarus form file does.  A cube with a' + LineEnding +
    '  circle on its top is thirty-seven readable lines.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.20.17' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **`/source` shows the drawing in a new, readable form.**  A proposed' + LineEnding +
    '  second version of the drawing file, for looking at - nothing is saved in' + LineEnding +
    '  it yet.  A corner reads as `3 3/4" east, 2" north, 2 1/2" above the' + LineEnding +
    '  floor`, the next as `b = a + 5 1/2" east`; a box is eight named corners' + LineEnding +
    '  and six one-line faces.  Lengths are colored like the axes - east and' + LineEnding +
    '  west red, north and south green, up and down blue - and every solid and' + LineEnding +
    '  group folds.  Tick **Only what is picked** and everything folds shut but' + LineEnding +
    '  what you picked on the sheet.  Untick **Version 2** to see the file as' + LineEnding +
    '  it is saved today.  The grammar is in `docs/format2.md`.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.20.16' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **`/source`: the drawing as its text, beside the drawing.**  A drawing' + LineEnding +
    '  is saved as plain lines, one thing to a line, and this window shows' + LineEnding +
    '  them.  Pick something on the sheet and its lines light up and scroll' + LineEnding +
    '  into view; click a line, or drag over several, and those things are' + LineEnding +
    '  picked on the sheet - a line inside a group picks the group, as a click' + LineEnding +
    '  on the sheet would.  It follows the drawing as you work.  Tick **Only' + LineEnding +
    '  what is picked** to hide every other line.  Read only, for now: it is' + LineEnding +
    '  the first piece of something larger.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.20.15' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **"This program and the others" says a good deal more.**  The help page' + LineEnding +
    '  now sets this program beside fifteen others, with a plain table of what' + LineEnding +
    '  to use instead when this is the wrong tool - and a section on ZCAD, the' + LineEnding +
    '  other drawing program written in Free Pascal: what to go there for (DXF' + LineEnding +
    '  and DWG, layers and blocks, electrical work) and what to stay here for.' + LineEnding +
    '  The list of what we do not do is longer, and honest.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.20.14' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A painted face turning plain after push/pull.**  Pushing a small box' + LineEnding +
    '  back flush with what it stood on left a box with no thickness - two' + LineEnding +
    '  faces in the same place, and which one showed was luck, so one of two' + LineEnding +
    '  orange eyes went gray.  Pressed flat, a solid now goes back to the' + LineEnding +
    '  painted face it was pulled from, the way SketchUp leaves it.' + LineEnding +
    '- **Paint lost when the flat areas were worked out again.**  A loose' + LineEnding +
    '  painted face could come back unpainted, or showing its blue back, after' + LineEnding +
    '  an edit nearby.  It keeps its paint and the way it faced.' + LineEnding +
    '- **What push/pull makes is painted like the face you pushed** - walls,' + LineEnding +
    '  cap and the lining of any opening - as a revolve and a sweep already' + LineEnding +
    '  were.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.20.13' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The send window''s summary, in color and with the machine in it.**  The' + LineEnding +
    '  files are listed before anything goes and each row changes as it is' + LineEnding +
    '  encrypted, sent and arrives - amber, blue, then green, or red with the' + LineEnding +
    '  reason.  Under them: this machine (system, processor, memory, graphics,' + LineEnding +
    '  display) beside the program (version and build, toolkit, memory, mode' + LineEnding +
    '  and theme), then what was in the report, under a banner that says how it' + LineEnding +
    '  went.  Long file names are in a smaller face so they fit.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.20.12' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The send window is twice the size and says more.**  A table of what' + LineEnding +
    '  went - the file, its size, its size once encrypted, and whether it' + LineEnding +
    '  arrived - fills in as each part goes, with a second table of what was in' + LineEnding +
    '  the report and where the copy on your computer is.  It says' + LineEnding +
    '  "encrypting" now, which is the word for it.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.20.11' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **`/light` turns the new lighting off and on.**  `/light off` puts the' + LineEnding +
    '  lamp back where it used to hang, with the same grays from every angle;' + LineEnding +
    '  `/light on` has it follow the camera again.  The choice is remembered.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.20.10' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Light that follows your eye.**  The lamp used to hang in one place, so' + LineEnding +
    '  the top, front and side of a box were the same three grays from every' + LineEnding +
    '  angle.  It now rides with the camera, the way SketchUp''s does: the face' + LineEnding +
    '  you turn towards you brightens to white, the ones turned away fall off' + LineEnding +
    '  to a proper gray, and orbiting a model is what shows its shape.  Plans' + LineEnding +
    '  stay flat, as before.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.20.9' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Half resolution while the camera moves, when it pays.**  Zoomed in on' + LineEnding +
    '  a big drawing, most of a frame goes into painting the faces, pixel by' + LineEnding +
    '  pixel.  While you orbit, pan or zoom, the faces are now painted at half' + LineEnding +
    '  size and blown up - the lines on them still drawn at full size and' + LineEnding +
    '  crisp - whenever the first moving frame came in slow; the moment the' + LineEnding +
    '  camera settles the frame is drawn in full.  Measured at twice the speed' + LineEnding +
    '  zoomed in, and it stays out of the way when the drawing is small.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.20.8' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Crisper while orbiting.**  While the camera moves the program draws' + LineEnding +
    '  quick frames, and the quick frames used to sample the lines lying on' + LineEnding +
    '  faces coarsely - which is why lines behind a face could bleed through its' + LineEnding +
    '  edges as you turned the model.  Those lines are drawn at full quality' + LineEnding +
    '  now, moving or still; measured at three milliseconds a frame on a' + LineEnding +
    '  700-face drawing.  The faces'' edges are still drawn quick while moving;' + LineEnding +
    '  that is the next step.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.20.7' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Drill stops where you say.**  Type a depth and the drill makes a hole' + LineEnding +
    '  exactly that deep and no deeper - through any passage already in the' + LineEnding +
    '  block on the way, which push/pull will not do, since push/pull stops at' + LineEnding +
    '  the first passage it meets.  Say nothing and it goes through, as before.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.20.6' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The report window''s summary is a page of its own** - drawn by LazInk' + LineEnding +
    '  from a line of Markdown for each thing that went, the label and the' + LineEnding +
    '  verdict in bold, so a long file name wraps instead of running off.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.20.5' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The report window stays until you close it, and says what went.**  A' + LineEnding +
    '  line for the report and its size, whether the drawing was in it, how big' + LineEnding +
    '  it became once sealed, the picture, and whether each of them arrived - or' + LineEnding +
    '  why not - a small page of its own, drawn by LazInk, so the words that' + LineEnding +
    '  matter are bold.  It used to close itself the moment the report had gone.  The' + LineEnding +
    '  sealing stage also holds long enough to read: the report is encrypted to' + LineEnding +
    '  a key only we hold before it leaves your machine, and that is worth a' + LineEnding +
    '  moment on the screen.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.20.4' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A group''s crate snaps.**  The box round a group - its corners, the' + LineEnding +
    '  middles of its edges, the centers of its sides and its center - are snap' + LineEnding +
    '  points from outside, the same points SketchUp puts grips on, so a guide' + LineEnding +
    '  or a line can be set to a locked group''s crate.  A locked group shows its' + LineEnding +
    '  crate faintly all the time.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The move tool grabbed a guide point instead of the corner it marked.**' + LineEnding +
    '  It takes the drawing first now, and a guide only when it is on its own.' + LineEnding +
    '  A guide on its own still moves, as in SketchUp.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.20.3' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A drawing that opened showing nothing.**  A sheet handed over from the' + LineEnding +
    '  last version came back with its camera zoomed out to the smallest the' + LineEnding +
    '  program allows, so there was nothing on the paper until the view was' + LineEnding +
    '  changed.  A saved view that shows none of the drawing is framed instead' + LineEnding +
    '  now, and says so in a report.' + LineEnding +
    '- **Erasing a guide point took the points beside it.**  The eraser asked' + LineEnding +
    '  the guide line first, the point sits on its line, and rubbing out the' + LineEnding +
    '  line takes every point on it.  It asks the point first now, the way the' + LineEnding +
    '  select tool does.' + LineEnding +
    '- **The report window says the report is being sealed** - the pause was' + LineEnding +
    '  there, the words were not.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.20.2' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A rectangle traced round an opening heals it.**  Rub the top off a box' + LineEnding +
    '  and draw a rectangle over where it was, and the top is back - the way' + LineEnding +
    '  redrawing an edge with the line tool has put a face back since' + LineEnding +
    '  September 15.  Only the line tool knew the trick; the rectangle drew four' + LineEnding +
    '  lines onto edges that were already there and no face came.  From the' + LineEnding +
    '  report of 19 September.' + LineEnding +
    '- **A face healed back onto a box faced into it**, and showed blue.  It' + LineEnding +
    '  faces out now.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.20.1' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Groups.**  Pick something and press Ctrl+G (or `/group`, or the right' + LineEnding +
    '  button''s Make Group) and it becomes a thing of its own: nothing outside' + LineEnding +
    '  it joins onto it, cuts it, or stretches it when it moves, and a click on' + LineEnding +
    '  any part of it takes all of it.  Double-click to work inside one - the' + LineEnding +
    '  rest of the drawing fades and stays out of reach until Escape or a click' + LineEnding +
    '  on nothing brings you back out.  Groups nest, `/name` names them, `/lock`' + LineEnding +
    '  keeps one from being changed at all while still letting you snap to it,' + LineEnding +
    '  and `/explode` takes one apart.  It is SketchUp''s group, and behaves the' + LineEnding +
    '  way theirs does, from their own help pages.  There is a page in the' + LineEnding +
    '  manual.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.20' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Faces were quietly piling up in stacks, and Reverse looked broken' + LineEnding +
    '  because of it.**  Around a rounded corner - a fillet, or a notch with' + LineEnding +
    '  arcs in it - the program could find the same flat area twice, and then' + LineEnding +
    '  lay a fresh face over it on every edit.  One sheet reported on 19' + LineEnding +
    '  September had ninety-nine surplus faces, some five deep, and a face that' + LineEnding +
    '  "would not reverse" was the top of a stack: it turned over, and the copy' + LineEnding +
    '  underneath still showed its back.  It also made every edit on that sheet' + LineEnding +
    '  a little slower than the last.  Both causes are fixed; a drawing that' + LineEnding +
    '  already has stacks in it is cleaned up by its next edit, or by' + LineEnding +
    '  `/reface`.' + LineEnding +
    '- **A report now names the sheet it was sent from**, not just its number -' + LineEnding +
    '  a drawing with tabs called "Broom" and "Sheet 1" in that order was read' + LineEnding +
    '  on the wrong sheet for an hour.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.19.2' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The rectangle and line tools no longer blink out their own corner.**  A' + LineEnding +
    '  small square rides with the cursor so it can be drawn crisp against the' + LineEnding +
    '  drawing under it; pasting it back used to erase whatever the tool itself' + LineEnding +
    '  was drawing right there, which for a rectangle or a line is exactly its' + LineEnding +
    '  near corner - so it flickered out every time the pointer crossed it.' + LineEnding +
    '  Fixed at the source: the corner is drawn into the square now, not wiped' + LineEnding +
    '  by it.' + LineEnding +
    '- **A bug report is encrypted before it leaves your machine.**  Reports go' + LineEnding +
    '  to a public postbox with no lock on it - that was always true, it had to' + LineEnding +
    '  be, since the program has no server of its own to ask first.  What was' + LineEnding +
    '  not true is that a report sitting in it was readable by anyone who found' + LineEnding +
    '  the address.  Now it is sealed to a key only we hold before it is sent;' + LineEnding +
    '  what a screenshot or a drawing says is between you and us, whatever' + LineEnding +
    '  happens to the box it travels in.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.19.1' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Export a film as WebP.**  Beside GIF in the export, and lossless: every' + LineEnding +
    '  shade the drawing has, where a GIF keeps 256 of them.  Nothing extra is' + LineEnding +
    '  shipped or installed to make one - the encoder is Pascal, in the program.' + LineEnding +
    '- **The about box says who built what.**  It is a proper page now, with the' + LineEnding +
    '  people whose work is inside this program named and linked - including' + LineEnding +
    '  Xelitan, whose WebP encoder is why the export above needs nothing beside' + LineEnding +
    '  it.' + LineEnding +
    '- **A page about the other programs.**  What this is for, what the likes of' + LineEnding +
    '  SketchUp, FreeCAD and LibreCAD do better, and when you should go and use' + LineEnding +
    '  one of them instead.  In the manual, under the contents.' + LineEnding +
    '- **Light or dark in the manual, whichever you are in.**  The switch the' + LineEnding +
    '  website has is in the program''s manual now: a tap at the top of any page' + LineEnding +
    '  cycles Auto, Light and Dark, and it stays that way next time you open it.' + LineEnding +
    '  Auto is the program''s own theme, as before.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The help menu opens above its button again.**  With the entity panel' + LineEnding +
    '  open, the menu from the HELP button was pushed back to the edge of the' + LineEnding +
    '  drawing, a panel''s width away from the button it belongs to.  It stands' + LineEnding +
    '  over the panel now, where it was pointed.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.19' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A way back from the bottom of a page.**  Every manual page now ends with' + LineEnding +
    '  a link to the contents, and the pages themselves are laid out the way the' + LineEnding +
    '  website lays them out - the same spacing, and a proper heading band on the' + LineEnding +
    '  key and command sheets.' + LineEnding +
    '- **What is on this page, at the top of it.**  The longest manual pages -' + LineEnding +
    '  commands, the keyboard, sheets, units, faces, plan, select and revolve -' + LineEnding +
    '  open with a list of their own sections, and every heading is a place you' + LineEnding +
    '  can link to.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Clicking a picture in the manual shows the picture.**  Every animation' + LineEnding +
    '  in the manual is a link to itself, and since they became WebP, clicking' + LineEnding +
    '  one filled the window with the file read as text.  It opens large, and' + LineEnding +
    '  keeps playing, the way it always should have.' + LineEnding +
    '- **The manual stays in your colors.**  In a light theme the contents came' + LineEnding +
    '  up light and every page you clicked through to came up dark.  Now the' + LineEnding +
    '  whole manual follows the program''s theme, wherever you got to it from.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.18.8' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **No more "not taken yet" boxes.**  Five pages were showing a dashed' + LineEnding +
    '  placeholder where a picture had been planned; those pages simply have no' + LineEnding +
    '  picture now, which is tidier than a note meant for whoever writes the' + LineEnding +
    '  manual.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.18.7' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The manual''s pictures are sharp.**  Every animation has been recorded' + LineEnding +
    '  again at the size it is shown, in lossless WebP - the old ones were' + LineEnding +
    '  scaled down on the way out, which turned every one-pixel line into a' + LineEnding +
    '  two-pixel gray smear.  They are bigger pictures and a smaller manual:' + LineEnding +
    '  20.1 MB of GIF became 14.2 MB of WebP.' + LineEnding +
    '- **The manual reads better too.**  Sections have a rule above them so a' + LineEnding +
    '  long page has somewhere for the eye to stop, the page head is underlined' + LineEnding +
    '  in the accent color, and captions read as captions.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.18.6' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The manual is drawn by a new engine.**  LazInk, which draws the help' + LineEnding +
    '  window inside the program, has replaced the renderer it grew up with -' + LineEnding +
    '  so this build carries a manual that lays out through a proper box tree' + LineEnding +
    '  and hangs its text on baselines.  It should read the same and draw' + LineEnding +
    '  faster, and there is one fewer license riding along with the download:' + LineEnding +
    '  LazInk is MIT throughout now, where the old renderer was MPL and owed' + LineEnding +
    '  its source to anybody who was given a copy of this.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.18.5' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A fifth example: a soccer ball.**  Twelve pentagons and twenty hexagons,' + LineEnding +
    '  cut off the corners of an icosahedron the way the real one is - and the' + LineEnding +
    '  panels stand off a dark inner ball so the seams read as seams.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.18.4' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A fourth example: the robot.**  Six foot two, standing, with the' + LineEnding +
    '  etch-a-sketch set in his chest at the height your hands are - ball' + LineEnding +
    '  joints at the shoulders and two-fingered hands.  The toy in his chest' + LineEnding +
    '  is the toy example itself, stood on end, not a copy of it.' + LineEnding +
    '- **The logo on the etch-a-sketch is raised**, a sixteenth proud of the' + LineEnding +
    '  body, the way it is moulded into the real one.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.18.3' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Pipe is black or stainless, and rounder.**  The spool builder has a' + LineEnding +
    '  Material box: black carbon steel or stainless.  Pipe is drawn with 36' + LineEnding +
    '  facets round it instead of 24, and a bend is walked in seven and a half' + LineEnding +
    '  degree steps instead of fifteen, so an elbow reads as an elbow.' + LineEnding +
    '- **Big drawings of pipe draw twice as fast.**  Filling a long thin face' + LineEnding +
    '  on the diagonal - which is every facet of a pipe - was costing what its' + LineEnding +
    '  bounding box costs rather than what the face costs.  A two-inch spool' + LineEnding +
    '  went from 70 milliseconds a frame to 34.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.18.2' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Duct looks like duct.**  Everything the fitting builder makes is' + LineEnding +
    '  galvanised sheet now instead of paper-white, and the fabric of a flex' + LineEnding +
    '  connector is black canvas rather than metal.' + LineEnding +
    '- **Rolled beads are round and cross breaks are bent.**  A bead was three' + LineEnding +
    '  flat facets with a crease down each join - a box, not a bead; it is a' + LineEnding +
    '  half round now with only its outer two edges drawn.  A cross break was' + LineEnding +
    '  two narrow creases laid on the panel; the panel itself is now bent on' + LineEnding +
    '  both diagonals, so it dishes and shows the X, which is what a cross' + LineEnding +
    '  break is.' + LineEnding +
    '- **TDF corners have their bolt hole** - square, because the bolt through' + LineEnding +
    '  it is a carriage bolt and the square shoulder under its head is what' + LineEnding +
    '  stops the bolt turning while the nut goes on.' + LineEnding +
    '- **TDF flanges can be drawn with the corners in.**  The duct fitting' + LineEnding +
    '  builder offers *TDF flange with the corners in* beside the plain one.' + LineEnding +
    '  A TDF''s sides each stop short of the corner so the next can fold, which' + LineEnding +
    '  leaves a square gap at each of the four; pick the new one and those gaps' + LineEnding +
    '  are filled with the corner pieces that go in them in the shop, instead' + LineEnding +
    '  of being left open the way the flange comes off the machine.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.18.1' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A third example drawing: a kitchen broom.**  A hundred and seventy' + LineEnding +
    '  bristles banded in four colors, a blue moulded head and a wooden' + LineEnding +
    '  handle - every face of it painted.  The other two examples are' + LineEnding +
    '  near-white, so this is the one that shows what materials are for.  It is' + LineEnding +
    '  written out beside the program with the others.' + LineEnding +
    '- **The view cube still works when you are square on to a face.**  Looked' + LineEnding +
    '  at straight on it is a flat square, and the ring of eight targets round' + LineEnding +
    '  its border is now drawn - the four sides are the views either way off' + LineEnding +
    '  this face, the corners are corner views.  They light up as you pass' + LineEnding +
    '  over them, so the cube can bring you back out as well as take you in.' + LineEnding +
    '- **The view cube, the tape measure and rotate have animations** - the' + LineEnding +
    '  cube flying between views, a tape pulled off an edge leaving a guide' + LineEnding +
    '  line, and a rectangle turned by a typed angle.  Rotate''s two sections' + LineEnding +
    '  about which plane it turns in are now one, and the page about sending a' + LineEnding +
    '  report says what happens to it after you press send.' + LineEnding +
    '- **Solids and 3D printing** shows what `/holes` is for: an edge rubbed' + LineEnding +
    '  off a box, and every unmatched edge drawn in red round the opening.' + LineEnding +
    '  Units, sheets and the etch-a-sketch pages read better too.' + LineEnding +
    '- **The rubber band stops claiming an axis it is not holding.**  With the' + LineEnding +
    '  axis inferences switched off by Alt, a line that happened to drift onto' + LineEnding +
    '  red still turned red, which read as a snap coming and going.  It now' + LineEnding +
    '  takes an axis color only when it is really on one.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.18' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A light/dark switch on the manual''s website.**  Top right of every' + LineEnding +
    '  page: Auto follows your phone or desktop, Light and Dark override it,' + LineEnding +
    '  and the choice is remembered in that browser.  The manual opened inside' + LineEnding +
    '  the program has no button and still follows the program''s own theme.' + LineEnding +
    '- **The offset page has two animations** - offset the top of a box and' + LineEnding +
    '  push the middle down for a tray, or the border up for a rim - and the' + LineEnding +
    '  old picture, which showed the floor grid the way it used to be drawn,' + LineEnding +
    '  is gone.' + LineEnding +
    '- **Four more again**: snapping (the cursor walking one edge while the' + LineEnding +
    '  diamond keeps changing its name), the working plane, the drill, and' + LineEnding +
    '  dimensions.' + LineEnding +
    '- **Four more pages of the manual have pictures**: the select tool (one' + LineEnding +
    '  click, two, three, then a dragged box), the eraser, faces front and back' + LineEnding +
    '  - which now shows an edge rubbed out and drawn back in, faces going and' + LineEnding +
    '  coming with it - and the protractor.' + LineEnding +
    '- **A page about Parts**, which is not built yet: keeping one piece of a' + LineEnding +
    '  drawing to itself so it does not join onto everything it touches.  The' + LineEnding +
    '  page says plainly that it is planned, and why it waits.' + LineEnding +
    '- **Clicking takes what you can see.**  Where an edge on top of something' + LineEnding +
    '  ran close on screen to an edge buried under it, the buried one could win' + LineEnding +
    '  and be picked or erased instead - the rim of a knob against the wall' + LineEnding +
    '  below it.  What is in front at the spot you are pointing at now wins.' + LineEnding +
    '- **Big drawings draw faster.**  Filling the faces was half of every' + LineEnding +
    '  frame; it now looks only at the edges that reach each row instead of' + LineEnding +
    '  all of them.  Measured on three drawings sent in with reports: about a' + LineEnding +
    '  sixth off the time a frame takes, and more the more detailed the shapes.' + LineEnding +
    '- **Set a color on everything picked at once.**  With several things' + LineEnding +
    '  picked the entity panel now paints every picked face, or recolors every' + LineEnding +
    '  picked line, arc, note and dimension, in one trip through the color' + LineEnding +
    '  picker - and the buttons say how many they will land on.' + LineEnding +
    '- **Paint a face and it is that color.**  Faces have a material of their' + LineEnding +
    '  own now, separate from the pen that drew their edges - so red is red' + LineEnding +
    '  instead of the gray-pink it used to come out.  Paint it from the entity' + LineEnding +
    '  panel; with several faces picked, all of them are painted at once, and' + LineEnding +
    '  **Back to default** returns one to the near-white it started as.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.17.10' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Alt does what it does in SketchUp, on three more tools.**  Pulling an' + LineEnding +
    '  arc''s bulge, it runs the arc out of the edge it started on smoothly and' + LineEnding +
    '  holds it there.  With the offset tool it keeps the overlaps a tight' + LineEnding +
    '  corner makes, instead of squaring them off.  With rotate or the' + LineEnding +
    '  protractor it frees them from the face under the cursor, so they turn' + LineEnding +
    '  flat unless an arrow picks a plane.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.17.9' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Parallel and square to an edge, in magenta.**  While a line is under' + LineEnding +
    '  way the cursor offers directions along the edge it started on, or the' + LineEnding +
    '  piece just drawn, and square to it - SketchUp''s magenta pair, which we' + LineEnding +
    '  did not have.' + LineEnding +
    '- **Alt steps through what the cursor may infer**, part way along a line:' + LineEnding +
    '  all of them, then the directions off, then parallel and square only.' + LineEnding +
    '  That is SketchUp''s key and SketchUp''s cycle.  Corners, midpoints and' + LineEnding +
    '  crossings keep snapping on every stop.  Before a line is started, Alt' + LineEnding +
    '  still holds the working plane.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.17.8' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The manual follows the program''s theme.**  Open it while the program is' + LineEnding +
    '  in a light theme and the pages are light; in a dark one they stay dark.' + LineEnding +
    '  On the website the pages follow whatever your system asks for.' + LineEnding +
    '- **The manual has pictures where it was thin**: the revolve tool has a ball' + LineEnding +
    '  and a wine glass being spun, the move tool shows a side of a rectangle' + LineEnding +
    '  being stretched, and the plan view shows the cut traveling up through a' + LineEnding +
    '  model.  The revolve page is rewritten step by step, with a table of what' + LineEnding +
    '  to do when it will not spin.' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **The tape leaves what SketchUp leaves.**  Measured along an edge - a' + LineEnding +
    '  point in from a corner, say - it drops a guide point and no line.  Pulled' + LineEnding +
    '  off an edge into the face, it drops a guide line parallel to that edge.' + LineEnding +
    '  From anywhere else it still lays the line across the run.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.17.7' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **The grid in ISO and 3D is a floor.**  Squares lying in the red and' + LineEnding +
    '  green plane, turning with the camera, only in the quarter where both axes' + LineEnding +
    '  are drawn solid - a floor to judge a model against, not paper behind it.' + LineEnding +
    '  Darker than it was, and heavier every fifth line.  It starts off now;' + LineEnding +
    '  <kbd>G</kbd> or the GRID button turns it on.' + LineEnding +
    '- **The bottom bar says more while you work** - what the cursor is holding' + LineEnding +
    '  on to, then what to do, then the keys that would do something right now.' + LineEnding +
    '  The card beside the pointer carries the keys as well.' + LineEnding +
    '- **The select tool leaves guides alone** unless you are right on one, and a' + LineEnding +
    '  guide under the pointer says so by turning its own dashes blue rather' + LineEnding +
    '  than being outlined in a thick band.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Drawing with something selected is quicker.**  The picture, the' + LineEnding +
    '  selection over it and the wash on the face under the pointer are kept' + LineEnding +
    '  between frames instead of being rebuilt on every one.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.17.6' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **Updating keeps your drawings exactly as they are.**  No save question' + LineEnding +
    '  on the way out: every sheet, the file it came from, and anything not saved' + LineEnding +
    '  yet all come straight back in the new version, still marked unsaved.  If' + LineEnding +
    '  an older copy is ever slow to close, the new one asks you to keep waiting' + LineEnding +
    '  instead of giving up.' + LineEnding +
    '- **Orbiting and zooming with the grid on are quicker** - the paper and the' + LineEnding +
    '  ground grid behind the drawing now cost a fraction of what they did.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Offsetting a rounded shape inward** no longer flips its rounded corners' + LineEnding +
    '  inside out.  Taken in further than the corners are round, the corners' + LineEnding +
    '  come out square, and the ring and the middle are two clean faces' + LineEnding +
    '  push/pull can find.' + LineEnding +
    '- **Lines no longer show through the walls of a pit.**  Pushing up a ring' + LineEnding +
    '  sometimes lined its opening inside out, so the pit''s walls were not drawn' + LineEnding +
    '  and the edges behind them showed through.  New pushes are right; for one' + LineEnding +
    '  already in a drawing, pick the pit''s walls and use Reverse.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.17.5' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Color and width in the entity panel.**  Pick a line or an arc and step' + LineEnding +
    '  its width with - and +, or press Change... beside Color to recolor' + LineEnding +
    '  whatever is picked.  The LINE COLOR and LINE WIDTH buttons still set what' + LineEnding +
    '  you draw next.' + LineEnding +
    '- **Ctrl and the arrow keys walk round the view cube** in the 3D view -' + LineEnding +
    '  left and right go round the sides, up and down tip over the top or under' + LineEnding +
    '  the bottom.' + LineEnding +
    '- **A cube drag let go near a view clicks onto it**, and with Ctrl held it' + LineEnding +
    '  clicks onto the nearest view from anywhere.' + LineEnding +
    '- **Short command names show up in the list.**  Typing `/tape` finds' + LineEnding +
    '  `/measure`, and the row says which name found it.' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **`/rendertime` and `/timings` show their numbers in a box you can copy' + LineEnding +
    '  from**, instead of a line in the command bar that ran off the end.' + LineEnding +
    '  `/timings` on, do the slow thing, `/timings` again.' + LineEnding +
    '- **Examples you have changed are left alone.**  The example drawings' + LineEnding +
    '  beside the program used to be written over every time it started; one' + LineEnding +
    '  you have edited and saved now stays yours, and an untouched one still' + LineEnding +
    '  gets the newer version.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A raised letter or shape keeps its outline color.**  Push/pull gave the' + LineEnding +
    '  new edges the face''s color, so raising a letter of the toy''s logo' + LineEnding +
    '  outlined it in red.  The new edges now match the outline they came from,' + LineEnding +
    '  and a raised letter looks embossed.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.17.4' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **Problem reports say much more about how the program was set up** - how' + LineEnding +
    '  it was started, the window and screen, the theme and grid, the view' + LineEnding +
    '  cube, each tool''s settings, and every open sheet.  Nothing about you;' + LineEnding +
    '  type `/state` to see exactly what would go.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.17.3' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Guides are no longer picked up with your drawing.**  A double or triple' + LineEnding +
    '  click, or a box dragged round a shape, takes the shape and leaves the' + LineEnding +
    '  guides alone.  A box round nothing but guides still takes them, and a' + LineEnding +
    '  click on a guide still picks it.' + LineEnding +
    '- **A guide gives a point to snap to wherever it crosses something**, all' + LineEnding +
    '  the way along it - not only near where the tape laid it.  That includes' + LineEnding +
    '  where it crosses an arc or a rounded corner.' + LineEnding +
    '- **Smoother zooming, panning and orbiting on Windows.**  The drawing is' + LineEnding +
    '  redrawn once per frame however many wheel steps or mouse moves arrive,' + LineEnding +
    '  and the blue wash over the face under the pointer no longer slows every' + LineEnding +
    '  frame when you are zoomed in close.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.17.2' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Click a picture in the manual to see it larger.**  Every screenshot and' + LineEnding +
    '  animation opens in a window of its own, as big as the window you make' + LineEnding +
    '  it - drag the window bigger and the picture grows.  Esc closes it.  On' + LineEnding +
    '  the website, a click opens the picture full size in a new tab.' + LineEnding +
    '- **The animations are recorded at full size** now, so they are sharp when' + LineEnding +
    '  you open them larger.' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **The manual''s contents page looks like cards**, three to a row, the same' + LineEnding +
    '  in the program as on the website.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.17.1' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **The manual''s contents page is laid out in rows of three**, grouped by' + LineEnding +
    '  what you are doing - drawing, shaping, picking and moving, measuring,' + LineEnding +
    '  looking around, your drawing, and the shop - with a "Start here" row at' + LineEnding +
    '  the top.  It reads as a grid in the program''s help window as well as on' + LineEnding +
    '  the website.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.17' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The manual opens inside Heckers Sketch.**  Help > The manual, or' + LineEnding +
    '  `/manual`, now shows the help pages in their own window - with Back and' + LineEnding +
    '  Forward, a Contents button, Find (Ctrl+F), and text you can select and' + LineEnding +
    '  copy.  Drag the page with a finger to scroll it.  Links to other websites' + LineEnding +
    '  still open in your browser, and "Open on the web" shows the same page' + LineEnding +
    '  online.' + LineEnding +
    '- **The manual is kept beside the program.**  The first time it''s needed,' + LineEnding +
    '  Heckers Sketch downloads the help pages for its own version from GitHub' + LineEnding +
    '  and keeps them in a `help` folder next to itself - so a copy on a USB' + LineEnding +
    '  stick still has its manual somewhere with no internet.  After an update,' + LineEnding +
    '  the matching pages are fetched on their own in the background.  `/update' + LineEnding +
    '  never` turns that off along with the update check, and `--offline` stops' + LineEnding +
    '  it entirely.' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **The release notes window reads the notes file directly** now, so what' + LineEnding +
    '  you see is exactly what was written.  It still shows only what''s new' + LineEnding +
    '  since the version you had.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.16.9' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Updates no longer fail with a bare "403".**  GitHub only answers so many' + LineEnding +
    '  update checks an hour from one home or office network, and when that runs' + LineEnding +
    '  out the check was simply refused.  It now falls back to GitHub''s release' + LineEnding +
    '  page, which doesn''t have that limit, and if that fails too it says so in' + LineEnding +
    '  plain words instead of a number.  (Our own testing was what used it up on' + LineEnding +
    '  16 September - that is fixed as well.)' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **`--offline`** starts the program with the network switched off entirely:' + LineEnding +
    '  no update check and no reports.  `--help` lists it.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.16.8' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **`--blank`** starts the program on an empty sheet - no example, no' + LineEnding +
    '  draft.  Whatever draft was there is kept beside it as' + LineEnding +
    '  `heckers-sketch-draft-before-blank.hsk`, so nothing is lost.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The buttons along the bottom fit a smaller window.**  On a narrower' + LineEnding +
    '  screen their words ran out of the buttons and over each other.  The' + LineEnding +
    '  buttons on the right now shrink first, then turn into icons, and a label' + LineEnding +
    '  that still doesn''t fit is shortened instead of spilling.' + LineEnding +
    '- **The tool list on the left fits a shorter window.**  MORE TOOLS and SHOP' + LineEnding +
    '  no longer end up drawn on top of each other.' + LineEnding +
    '- **The blue highlight on a face no longer has a hole under the pointer.**' + LineEnding +
    '- **The release notes window has a scroll bar in the theme''s colors.**' + LineEnding +
    '' + LineEnding +
    '## v2026.09.16.7' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **This window is drawn by LazInk now**, our own text package, rather than' + LineEnding +
    '  by code of its own.  It looks much the same.  You can still drag the page' + LineEnding +
    '  with a finger to scroll it, and the arrow keys, Page Up and Page Down and' + LineEnding +
    '  the mouse wheel all work.  The scroll bar is a plain one for now.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.16.6' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Round the corners of a shape with the arc tool, like SketchUp.**  Click a' + LineEnding +
    '  point on each edge near a corner and pull the middle in towards the' + LineEnding +
    '  corner.  When the arc curves smoothly into both edges it turns magenta and' + LineEnding +
    '  says TANGENT TO EDGE.  Click to put it in and keep the square corner, or' + LineEnding +
    '  double-click to trim the corner away.  Type a radius while it''s magenta to' + LineEnding +
    '  set the size.  After that, double-click near any other corner for the same' + LineEnding +
    '  again.' + LineEnding +
    '- **Type a line''s length.**  Pick a line, type a new length, press Enter.' + LineEnding +
    '  A loose line moves the end it was drawn to, a line joined at one end moves' + LineEnding +
    '  its free end, and a line joined at both ends can''t be changed that way -' + LineEnding +
    '  the same rule as SketchUp''s Entity Info.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.16.5' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Hold Ctrl while orbiting and let go, and the view clicks into the' + LineEnding +
    '  nearest standard direction** - one of the twenty-six the view cube offers:' + LineEnding +
    '  six faces square on, twelve edges, eight corners.  It glides there the way' + LineEnding +
    '  clicking the cube does, so you keep track of what you are looking at.' + LineEnding +
    '  While Ctrl is held the status line names where you will land, and the cube' + LineEnding +
    '  lights the face it is about to go to.  Let go of Ctrl first and nothing' + LineEnding +
    '  happens.' + LineEnding +
    '- **`--no-splash`** starts the program without the start-up screen, for' + LineEnding +
    '  anything driving it from a script.  `--help` lists it with the rest.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Hiding the guides now hides them from the cursor too.**  Put away, they' + LineEnding +
    '  were still snapped to, still ran under the cursor, and could still be' + LineEnding +
    '  picked and rubbed out - all of it invisible, so the cursor jumped to' + LineEnding +
    '  places with nothing on the screen to explain why.' + LineEnding +
    '- **What you click is the nearest thing, not the last thing you drew.**' + LineEnding +
    '  With two things in reach the pick used to go to whichever was drawn more' + LineEnding +
    '  recently, even when the other was dead under the cursor.' + LineEnding +
    '- **A crossing selection box takes what it actually crosses.**  Dragged' + LineEnding +
    '  right to left in a clear patch of paper it used to take any line, arc or' + LineEnding +
    '  face whose *corner-to-corner extent* happened to cover the area - a long' + LineEnding +
    '  diagonal running past would come along with the selection.' + LineEnding +
    '- **Guide lines can be caught by a selection box** from either direction.' + LineEnding +
    '- **An edge just inside the snapping distance is found.**  The reach was' + LineEnding +
    '  quietly a pixel shorter than the one being asked for.' + LineEnding +
    '- **Picking is much faster on a big drawing** - about thirty times - so' + LineEnding +
    '  hovering over a crowded sheet no longer lags behind the mouse.' + LineEnding +
    '- **Orbiting is smoother, and the ground reads as a floor.**  The lattice on' + LineEnding +
    '  the ground was being ruled far finer than it could be seen - about two' + LineEnding +
    '  hundred and sixty lines a few pixels apart, which came out as a gray' + LineEnding +
    '  crosshatch and cost most of every frame to draw.  It is now spaced so you' + LineEnding +
    '  can read it, and tipping the view down near the ground gives you a coarse' + LineEnding +
    '  floor instead of none at all.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.16.4' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Exporting an animation and then clicking back in the drawing no longer' + LineEnding +
    '  throws an exception.**  An export makes a picture the size it is saving,' + LineEnding +
    '  which is not the size of the window, and the drawing kept using that one to' + LineEnding +
    '  work out what was in front of what long after the export had put it away.' + LineEnding +
    '  The first click afterwards landed on nothing.  Exports of every kind -' + LineEnding +
    '  animations, pictures, print previews, contact sheets - now hand the drawing' + LineEnding +
    '  back to the window as they finish.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.16.3' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Picking a lot of things no longer brings the program to a halt.**  With' + LineEnding +
    '  everything in a drawing selected, every frame was spending nearly two' + LineEnding +
    '  seconds drawing the blue outlines - one call to the system''s canvas per' + LineEnding +
    '  visible piece of every edge, and about a millisecond each.  The same' + LineEnding +
    '  outlines are drawn into a picture of our own instead and kept until' + LineEnding +
    '  something changes them: twenty milliseconds the first time, nothing after' + LineEnding +
    '  that.  Nothing about how it looks has changed.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.16.2' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The entity panel.**  `/info` puts it down the right-hand side: what is' + LineEnding +
    '  picked, and the few things you can change about it.  A line''s length and' + LineEnding +
    '  both ends; a circle''s radius, center and **how many sides** - with a minus' + LineEnding +
    '  and a plus beside the figure, so a circle drawn at 24 can be turned into 48' + LineEnding +
    '  after the fact, which was never possible before.  A face''s area and corner' + LineEnding +
    '  count with a Reverse button.  A note''s size.  With nothing picked it says' + LineEnding +
    '  what the sheet adds up to.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.16.1' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Copy and paste, including from one sheet to another.**' + LineEnding +
    '  Ctrl+C, Ctrl+X, Ctrl+V.  A paste arrives on the cursor and a click' + LineEnding +
    '  puts it down, the way a built fitting does.  A pasted solid is its own' + LineEnding +
    '  solid, so pushing a face on one does not deform the other.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Closing a sheet with work on it asks about it.**  It asked about the' + LineEnding +
    '  window rather than the sheet - and making a new sheet marked every other' + LineEnding +
    '  sheet saved, so drawing something, opening a second sheet and closing the' + LineEnding +
    '  first went without a word.  Closing the whole window now asks too, which it' + LineEnding +
    '  never did.' + LineEnding +
    '' + LineEnding +
    '- **The face under the cursor is worked out once.**  Push/pull, the drill and' + LineEnding +
    '  the offset asked for it, then the snapping asked for it again, and on some' + LineEnding +
    '  tools the click asked a third time - each one a ray cast at every face in' + LineEnding +
    '  the drawing, on every mouse move.' + LineEnding +
    '' + LineEnding +
    '- **The stipple under push/pull is drawn a row at a time.**  It used to ask' + LineEnding +
    '  "is this dot inside the face" for every other pixel of the face''s box -' + LineEnding +
    '  four million divides a mouse move on the toy''s case.  Same picture, about' + LineEnding +
    '  five hundred times less work.' + LineEnding +
    '' + LineEnding +
    '- **A copy of a face with a window in it gets its own window.**  Ctrl-copy' + LineEnding +
    '  with the move tool shared the opening with the original and left it at the' + LineEnding +
    '  original''s position, so moving either moved both.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.16' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The push/pull page has a moving picture.**  Nine seconds: pick the tool,' + LineEnding +
    '  click the circle, pull it up.  Recorded by driving the program rather than' + LineEnding +
    '  by anybody filming it, so the next one is a script away.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.15.8' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Ten more pages in the manual, and a way in from the command list.**' + LineEnding +
    '  Snapping, the working plane, units against scale against precision, faces' + LineEnding +
    '  front and back, sheets and files, the view cube, the fitting wizard, the' + LineEnding +
    '  pipe spool, laying a piece out flat, and the toy.  In the command list, a' + LineEnding +
    '  command with a page of its own is now a link to it.' + LineEnding +
    '' + LineEnding +
    '- **A bug report says how the frames have been going.**  Every frame is' + LineEnding +
    '  timed - the paper, the ink, the composite and the screen - and one that' + LineEnding +
    '  takes longer than a fortieth of a second writes a line into the log a' + LineEnding +
    '  report carries, saying which part of it was slow and what you were doing.' + LineEnding +
    '  The report also carries how many went over and what the worst one was.' + LineEnding +
    '  "It felt glitchy" now arrives with the numbers.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A picked guide is drawn where the guide is.**  A guide is kept as a point' + LineEnding +
    '  and one foot of direction, and drawn to the edges of the paper - and' + LineEnding +
    '  picking one highlighted the foot, so two blue lines appeared to stick out' + LineEnding +
    '  of a drawing with nothing at either end of them.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.15.7' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A guide point is easy to pick.**  It marks a distance along a line, so it' + LineEnding +
    '  sits on that line - and the line used to win the click from a pixel away.' + LineEnding +
    '  It is asked for before anything else now, with a reach the size it is' + LineEnding +
    '  drawn, so one attempt gets it.  Select it and press Delete, or right-click' + LineEnding +
    '  and Erase.  A guide that has been put away cannot be picked or erased at' + LineEnding +
    '  all, which it could before.' + LineEnding +
    '' + LineEnding +
    '- **Ctrl says what the tape leaves behind.**  Both the dashed guide and the' + LineEnding +
    '  amber point, the point on its own, the guide on its own, or nothing.  Both' + LineEnding +
    '  is still what you get unless you say otherwise, and the bar says which mode' + LineEnding +
    '  you are in each time you press it.  A 1" mark in from the end of a line' + LineEnding +
    '  rarely wants a dashed line across the whole drawing with it.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The tape measure finishes when it has measured.**  It used to sit waiting' + LineEnding +
    '  afterwards, drawing the run it had just taken until something else took the' + LineEnding +
    '  tool away - and a press of Enter, or of Space which everywhere else means' + LineEnding +
    '  "done", would land on that waiting tool and turn the run into a dimension' + LineEnding +
    '  minutes later.  Both were the same thing.  To keep a run, `/keep` writes' + LineEnding +
    '  the last one on the drawing as a dimension.' + LineEnding +
    '' + LineEnding +
    '- **Undo puts a face''s openings back.**  Move something with windows in it -' + LineEnding +
    '  the block letters of the title, say - and undo put the outlines back and' + LineEnding +
    '  left the windows where they had been dragged to.  The undo snapshot was' + LineEnding +
    '  sharing those loops with the drawing, so a move wrote through it into the' + LineEnding +
    '  past.' + LineEnding +
    '' + LineEnding +
    '- **A guide line takes its point with it.**  The tape lays both in one' + LineEnding +
    '  gesture; rubbing out the dashed line left the amber point behind, marking a' + LineEnding +
    '  spot nothing could explain.' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **Hide Guides and Clear Guides are on the right button now.**  They were' + LineEnding +
    '  two more buttons along the bottom that appeared the moment a drawing had a' + LineEnding +
    '  guide in it, and making room for them squeezed the settings until their' + LineEnding +
    '  words ran into each other.  Right-click anywhere on the drawing.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.15.6' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **The eraser takes edges, not faces.**  That is SketchUp''s rule - a face' + LineEnding +
    '  goes when the edges holding it up go - and ours used to take a bare face as' + LineEnding +
    '  well.  Click one now and nothing goes; the bar along the bottom says so and' + LineEnding +
    '  names the two ways that do work: right-click it, or pick it and press' + LineEnding +
    '  Delete.  Both leave every edge standing.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A line drawn along an edge already there now divides the face.**  Close a' + LineEnding +
    '  strip off along the bottom of a wall and the strip is its own area, which' + LineEnding +
    '  you can push out as a floor.  It used to come out as one loop with the' + LineEnding +
    '  divider traced up one side and down the other - no area cut off, and' + LineEnding +
    '  nothing to push.  Two identical edges written the opposite way round were' + LineEnding +
    '  not being welded into one.' + LineEnding +
    '' + LineEnding +
    '- **A face needs the edges that enclose it.**  Rub out an edge of a box and' + LineEnding +
    '  the sides that were standing on it go with it, the way SketchUp has always' + LineEnding +
    '  done it - "faces are erased when you erase their bounding edges".  Loose' + LineEnding +
    '  faces already worked this way; a built solid''s did not, so a box could end' + LineEnding +
    '  up with six sides and one of them held up by nothing.' + LineEnding +
    '' + LineEnding +
    '- **And you can put one back.**  Draw the line again, along where it was, and' + LineEnding +
    '  the faces come back with it - SketchUp''s healing.  A side traced back into' + LineEnding +
    '  a box rejoins the box, so the shape is closed again and `/holes` agrees.' + LineEnding +
    '' + LineEnding +
    '- **A guide makes a point where it crosses an edge.**  That is what a guide' + LineEnding +
    '  is for: set one an inch in from the end and the place you are aiming at is' + LineEnding +
    '  where it meets the edge.  Nothing was offering it - the pass that works out' + LineEnding +
    '  crossings only ever looked at drawn lines.  Two guides crossing each other' + LineEnding +
    '  count too.' + LineEnding +
    '' + LineEnding +
    '- **A rectangle says when you have given it one side.**  Type a length with' + LineEnding +
    '  no second side and it read it, ignored it, and took the corner from the' + LineEnding +
    '  cursor without a word.  It now says so, and what to type instead.' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Truss notation is in the manual.**  `6-8-15` is six foot eight and' + LineEnding +
    '  fifteen sixteenths, and it has always worked in every field that takes a' + LineEnding +
    '  length - it was just never written down anywhere.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.15.5' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A manual worth opening.**  Two new pages: every one of the sixty-nine' + LineEnding +
    '  slash commands, grouped by what you are trying to do and with the short' + LineEnding +
    '  names each answers to; and every key and every drag on one sheet, in both' + LineEnding +
    '  the drawing program and the toy.  `/manual` opens them.  The first real' + LineEnding +
    '  screenshots are in too - and they are taken by driving the program itself,' + LineEnding +
    '  so the rest can follow without anybody posing for them.' + LineEnding +
    '' + LineEnding +
    '- **Edges break where they cross.**  Draw a line, a rectangle, an arc or a' + LineEnding +
    '  circle over something already there and both are cut at the crossing, so' + LineEnding +
    '  every piece is its own edge.  That is what makes a rounded corner: drop a' + LineEnding +
    '  circle on the corner of a rectangle so it just touches both sides, then rub' + LineEnding +
    '  out three quarters of the circle and the short piece of each side, and the' + LineEnding +
    '  corner is rounded.  Before this the side was still one line from corner to' + LineEnding +
    '  corner and there was nothing to rub out but the whole of it.  Solids,' + LineEnding +
    '  guides and dimensions take no part - only loose drawing is cut.' + LineEnding +
    '' + LineEnding +
    '- **A move shows what is coming with it.**  Move one side of a rectangle and' + LineEnding +
    '  the two sides it joins stretch to follow - which has always happened, and' + LineEnding +
    '  which the ghost never showed, so it looked like the side was tearing away' + LineEnding +
    '  on its own.  Those edges are now drawn leaning over to where they are' + LineEnding +
    '  going while the mouse is still down.' + LineEnding +
    '' + LineEnding +
    '- **`/detach on` moves a line away on its own.**  The other way round:' + LineEnding +
    '  nothing stretches to follow and everything else stays where it is.  The' + LineEnding +
    '  ghost turns amber to say so.  `/detach off` puts it back.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Push/pull stipples only the part of the face that is there.**  A' + LineEnding +
    '  rectangle drawn inside another leaves a ring, and pointing at the ring lit' + LineEnding +
    '  up the whole rectangle, window and all.  It now stops at the window, and at' + LineEnding +
    '  anything standing in front of the face.' + LineEnding +
    '' + LineEnding +
    '- **The tape measure takes the middle of an edge it is on.**  Hovering the' + LineEnding +
    '  middle of a side of a face offers the midpoint, the way it does on a drawn' + LineEnding +
    '  line.' + LineEnding +
    '' + LineEnding +
    '- **The help pages say how to change the number of sides.**  With the circle' + LineEnding +
    '  or arc tool live, + and - step it, or type 24s.  It was in the program and' + LineEnding +
    '  nowhere in the manual.' + LineEnding +
    '' + LineEnding +
    '- **`/new` makes a new sheet.**  It opened the release notes instead: the' + LineEnding +
    '  branch that answers `/whatsnew` also answered `/new`, and it came first.' + LineEnding +
    '' + LineEnding +
    '- **US spellings throughout.**  Color, center, millimeters.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.15.4' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A dimension has to measure something.**  You could lay one across blank' + LineEnding +
    '  paper and drag it around - a number measuring nothing, which the drawing' + LineEnding +
    '  can never drive and which will never update when the drawing changes.  It' + LineEnding +
    '  now wants a corner, a midpoint, a center, or a point on an edge, and the' + LineEnding +
    '  cursor says so before you click rather than after.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.15.3' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The dimension tool takes the edges of the toy''s case.**  Hovering one' + LineEnding +
    '  said ON EDGE and lit nothing, and the click fell through to a' + LineEnding +
    '  point-to-point: the hover and the click looked at lines, arcs, dimensions' + LineEnding +
    '  and guides, never at the outline of a face, and then asked the edge for its' + LineEnding +
    '  two ends - which a face has not got.  They use the same search the snap' + LineEnding +
    '  does now, so the one edge under the cursor lights up and a click takes all' + LineEnding +
    '  of it.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.15.2' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A part for printing now arrives standing on the bed.**  "Center it on' + LineEnding +
    '  the origin" centerd all three directions, which buries the bottom half of' + LineEnding +
    '  the thing in the build plate; slicers quietly lift it back out, so nothing' + LineEnding +
    '  ever looked wrong, but it is the sort of thing you open another program to' + LineEnding +
    '  put right before printing.  It is centerd across the bed and standing on it' + LineEnding +
    '  now - the STL, the OpenSCAD, and `/center` itself.  `/tozero` is unchanged:' + LineEnding +
    '  the near bottom corner on the origin rather than the middle.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.15.1' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The view winds in and out a great deal further.**  It was a twentieth to' + LineEnding +
    '  forty times - which sounds generous until you try to work on a sixteenth of' + LineEnding +
    '  an inch.  It is a million to one now, so a site plan and a weld bead are' + LineEnding +
    '  both reachable, and the scale bar goes down to a sixteenth of an inch and' + LineEnding +
    '  up to a thousand feet to keep up.' + LineEnding +
    '' + LineEnding +
    '- **The axes go on for ever**, the way they should.  They were drawn a' + LineEnding +
    '  screenful out from the origin, so panning away from it left them stopping' + LineEnding +
    '  in mid air.  In a program where the red line IS the X axis, an axis with an' + LineEnding +
    '  end is a lie about the model.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The tape and the dimension tool now take the edges of a face.**  They' + LineEnding +
    '  only ever looked at lines, so on the etch-a-sketch you could measure the' + LineEnding +
    '  robot and the lettering - which are drawn with lines - and could not' + LineEnding +
    '  measure the case they sit on, which is one face of thirty-two corners with' + LineEnding +
    '  no lines in it at all.  Its corners are somewhere to land now too.' + LineEnding +
    '  Anything that arrives as faces rather than drawn lines was in the same' + LineEnding +
    '  position: a revolve, an imported model, a generated example.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.15' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The tape and the dimension tool stop grabbing edges behind the model.**' + LineEnding +
    '  They took whichever line came nearest on screen and asked nothing else, so' + LineEnding +
    '  measuring along the front of a box jumped to the back edge wherever that' + LineEnding +
    '  happened to project a pixel closer.  On a solid box, better than a quarter' + LineEnding +
    '  of the places you could put the cursor gave you an edge you could not see.' + LineEnding +
    '' + LineEnding +
    '- **And when two lines land on the same pixel, the nearer one wins.**  The' + LineEnding +
    '  etch-a-sketch is made of this: the lip of the case and the screen recess' + LineEnding +
    '  run parallel an eighth of an inch apart, so measuring along the top of the' + LineEnding +
    '  toy flipped between them depending on which had been drawn first.' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **What''s new scrolls under your finger.**  Drag the page and it follows -' + LineEnding +
    '  on a touch screen, or with the mouse button held down.  It could only be' + LineEnding +
    '  scrolled with the wheel or the keyboard before, which is no help on a' + LineEnding +
    '  laptop you are poking at.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.14.18' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Pick something, click the cube, and it comes to the middle sized to' + LineEnding +
    '  fit** - turning, sliding and zooming in one movement rather than a turn' + LineEnding +
    '  followed by a jump.  With nothing picked it goes to the view you asked for' + LineEnding +
    '  and leaves your framing alone.  `/cube fitselection off` if you would' + LineEnding +
    '  rather it never re-framed.' + LineEnding +
    '' + LineEnding +
    '- **The cube goes in whichever corner suits**: `/cube tl`, `tr`, `bl` or' + LineEnding +
    '  `br`, and `/cube on` or `off` to say so outright.  It remembers.' + LineEnding +
    '' + LineEnding +
    '- **FIT travels too.**  The FIT button and `/fit` ease the drawing into' + LineEnding +
    '  frame instead of snapping it there - as does the VIEW button and every' + LineEnding +
    '  named view.  Loading a drawing or changing sheet still arrives instantly,' + LineEnding +
    '  because there is no sense of place to keep hold of when the thing you were' + LineEnding +
    '  looking at has been replaced.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **"Send the drawing too" stayed unticked.**  Taking another picture, or' + LineEnding +
    '  discarding it, rebuilt the report dialog - and the tick came back on, so a' + LineEnding +
    '  report sent after that carried the drawing anyway.  What you typed always' + LineEnding +
    '  survived that rebuild; now your answer to this does too.  It is your work' + LineEnding +
    '  and the box exists so you get to say.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.14.17' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A view cube.**  `/cube` puts one in the top right of a 3D view.  Click a' + LineEnding +
    '  face to look square on, an edge for a half turn between two, a corner for' + LineEnding +
    '  the three-quarter view most drawings are read from; drag it to turn the' + LineEnding +
    '  model the way dragging the model does.  It also answers the question the' + LineEnding +
    '  VIEW button never could - which way am I facing - without being touched.' + LineEnding +
    '' + LineEnding +
    '  Off until you ask for it, and remembered after that.' + LineEnding +
    '' + LineEnding +
    '- **A turn turns about what you are looking at**, not about the origin.  The' + LineEnding +
    '  middle of what is selected, or the middle of the drawing when nothing is -' + LineEnding +
    '  which is the rule Revit uses, and the reason a building drawn half a mile' + LineEnding +
    '  from zero no longer swings out of the window when you change the view.' + LineEnding +
    '' + LineEnding +
    '- **The view rolls instead of jumping.**  Every change of view used to snap:' + LineEnding +
    '  the model was one way round and then it was another, and you worked out' + LineEnding +
    '  which way it had gone.  Now it rolls there, the short way round, in about a' + LineEnding +
    '  third of a second - and that goes for the VIEW button and `/front` and the' + LineEnding +
    '  rest as much as for the cube.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.14.16' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A film comes back to where it started.**  A move that ends somewhere' + LineEnding +
    '  else - a rise, a push in, or one you pointed by hand - used to jump every' + LineEnding +
    '  time the GIF came round.  It can now walk back to the start instead, inside' + LineEnding +
    '  the same running time, so it joins up.  The tick only appears when the move' + LineEnding +
    '  needs it: a turntable already ends where it began and is left alone.' + LineEnding +
    '' + LineEnding +
    '- **How long the film runs is yours to choose.**  A clip pointed by hand over' + LineEnding +
    '  eleven seconds plays perfectly well in five, and the length is the speed.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The axes no longer draw through the model in a picture or a film.**  They' + LineEnding +
    '  went on top of the finished picture, so a red line ran across the middle of' + LineEnding +
    '  a solid in every frame of a GIF - which happens nowhere on screen, because' + LineEnding +
    '  the drawing area rules them onto the paper and puts the model over them.' + LineEnding +
    '  Now they go underneath there too.' + LineEnding +
    '' + LineEnding +
    '- **A film that ends where it began no longer stutters once a loop.**  It was' + LineEnding +
    '  rendering the first pose twice - last frame and first frame, the same' + LineEnding +
    '  picture - so a turntable froze for a frame every time round.' + LineEnding +
    '' + LineEnding +
    '- **The recording room can be moved.**  It draws its own frame and nothing' + LineEnding +
    '  had ever been wired to drag it, so it sat in the middle of the screen over' + LineEnding +
    '  the thing you were about to film.  Nothing about a recording minds: what is' + LineEnding +
    '  written down is where the camera is pointing, not what is on the screen.' + LineEnding +
    '' + LineEnding +
    '- **An exported SVG now says how big it is.**  It used to carry a bare' + LineEnding +
    '  number - screen pixels at whatever zoom the view happened to be at - so a' + LineEnding +
    '  part three and a half inches across arrived in Inkscape, or a print shop,' + LineEnding +
    '  or a cutting machine, at some other size entirely, and at a different size' + LineEnding +
    '  again if you had zoomed in first.  The file now says `3.430in` (or' + LineEnding +
    '  millimeters, in a metric drawing) and opens at the size of the thing.' + LineEnding +
    '  Export from a plan and what comes out is the real thing, full size.' + LineEnding +
    '' + LineEnding +
    '- **Dragging a dialog no longer skips about.**  The windows that draw their' + LineEnding +
    '  own title bar - Export, What''s new - were moved by measuring the pointer' + LineEnding +
    '  against the window being moved, which on Linux feeds back on itself and' + LineEnding +
    '  makes the window fight the hand.  They now measure against the screen, and' + LineEnding +
    '  move once per twitch instead of twice.' + LineEnding +
    '' + LineEnding +
    '- **The program stops working while a dialog is up.**  It kept a sixty-a-' + LineEnding +
    '  second heartbeat running underneath every dialog, including the system' + LineEnding +
    '  print and color ones, servicing a pointer that was somewhere else.  On a' + LineEnding +
    '  machine with a compositor that is enough to make the dialog you are' + LineEnding +
    '  dragging stutter.  Measured with a drawing of twenty-four wine glasses: the' + LineEnding +
    '  window behind the export dialog went from 2.2% of a core to 0.2%.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.14.15' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The wheel scrolls the command list.**  It used to zoom the drawing' + LineEnding +
    '  behind it instead, which was true of every list in the program - the' + LineEnding +
    '  command list is just the first one long enough to make it obvious.  A list' + LineEnding +
    '  in front of the drawing now gets the wheel before the drawing does.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.14.14' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The command list called Revolve "/followme".**  The tool was renamed on' + LineEnding +
    '  the eighth and the command list never heard: it offered `/followme` as the' + LineEnding +
    '  name and no `/revolve` at all.  It is `/revolve` now, and `/followme`,' + LineEnding +
    '  `/follow` and `/lathe` still work for anybody coming from SketchUp.' + LineEnding +
    '' + LineEnding +
    '- **MORE TOOLS said what was not behind it.**  It promised "rotate, offset,' + LineEnding +
    '  follow me and drill" and held three tools, Revolve having moved out to the' + LineEnding +
    '  strip beside Push/Pull a week ago.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.14.13' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The command list shows you how to use a command, not just what it is.**' + LineEnding +
    '  Highlight a row - with the arrow keys or the pointer - and if that command' + LineEnding +
    '  takes something after it, the line beside it turns into a real example.' + LineEnding +
    '  `/scale` reads `/scale 1/4"`, `/cut` reads `/cut 0 9''`, `/plane` reads' + LineEnding +
    '  `/plane xz`.  The rest go on saying what they do.' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **The command list is half the height of the window** instead of all of' + LineEnding +
    '  it.  Sixty rows from the prompt to the title bar was a wall in front of' + LineEnding +
    '  the drawing you were about to do something to; the rest is a scroll away.' + LineEnding +
    '' + LineEnding +
    '- **The reading along the top goes to the corner now.**  X, Y, Z, the plane,' + LineEnding +
    '  the length and the area used to stop two hundred pixels short to clear the' + LineEnding +
    '  TOY/PRO switch.  The switch is gone, so the room is the reading''s.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.14.12' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The manual is on the web.**  Help > The manual opens the copy that came with' + LineEnding +
    '  the program if there is one and the website if not, and the website is now' + LineEnding +
    '  a real set of pages you can read in a browser rather than a folder of files' + LineEnding +
    '  on GitHub.' + LineEnding +
    '' + LineEnding +
    '- **The toy is a command.**  `/toy` takes you to the etch-a-sketch this' + LineEnding +
    '  program started as, and the one button in the corner there brings you back.' + LineEnding +
    '' + LineEnding +
    '- **A help page about the commands**, since there was one about typing' + LineEnding +
    '  measurements and nothing about typing a slash.' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **The TOY and PRO buttons are gone from the top right.**  They took up the' + LineEnding +
    '  corner of a drawing program to offer you a choice you had already made.' + LineEnding +
    '  Nothing is hidden - `/toy` is in the command list with everything else.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Seventeen pages of the manual were missing from the website.**  Every' + LineEnding +
    '  page about a tool - Line, Push/Pull, Offset, all of them - was in the copy' + LineEnding +
    '  that ships beside the program but had never been published.  They are' + LineEnding +
    '  there now.' + LineEnding +
    '' + LineEnding +
    '- **The eraser''s help page was a version behind.**  It now mentions dragging' + LineEnding +
    '  to gather several, and Ctrl to soften an edge rather than rub it out.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.14.11' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **You do not have to remember the commands any more.**  Type `/` and the' + LineEnding +
    '  whole list comes up with a word about what each one does.  Keep typing and' + LineEnding +
    '  it narrows, the way an editor''s autocomplete does - `/re` leaves you' + LineEnding +
    '  /rebuild, /rect, /redo, /reface and the rest.  Up and down walk it, Enter' + LineEnding +
    '  takes what is highlighted, Tab completes without running it, Escape puts it' + LineEnding +
    '  away, and clicking a row does the same as Enter on it.' + LineEnding +
    '' + LineEnding +
    '  The ones you have used lately sit at the top and the rest are alphabetical,' + LineEnding +
    '  so it works whether or not you know what the thing is called.  It remembers' + LineEnding +
    '  them between sessions.' + LineEnding +
    '' + LineEnding +
    '  There is a `/` button at the left of the command bar for anybody who has' + LineEnding +
    '  not found the keyboard yet.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.14.10' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **/tozero puts a selection in the corner at 0,0,0.**  /center puts the' + LineEnding +
    '  middle of a thing on the origin, which is what a slicer wants.  This puts' + LineEnding +
    '  its near bottom corner there instead, so it stands on the floor with its' + LineEnding +
    '  two near edges against zero - which is what you want when you are' + LineEnding +
    '  measuring, because every number read off it is then a distance from' + LineEnding +
    '  nothing rather than from half of itself.  It tells you how big the thing' + LineEnding +
    '  is from there.  Also **Into the Corner at 0,0,0** on the right button,' + LineEnding +
    '  beside Center on the Origin.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.14.9' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A wine glass, beside the toy.**  The examples folder has two drawings in' + LineEnding +
    '  it now, both written out beside the program every run.  The glass is eight' + LineEnding +
    '  and a half inches tall with a hollow bowl and a solid stem, and it is a' + LineEnding +
    '  closed solid - a slicer will take it.' + LineEnding +
    '' + LineEnding +
    '  It is built the way you would build it: the outline of half a glass, spun' + LineEnding +
    '  about the blue axis with Revolve.  So it is also the picture for that tool.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.14.8' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **An export that is not a closed solid marks itself.**  Send out an STL or' + LineEnding +
    '  an OpenSCAD script and the edges where it is open are already drawn in red' + LineEnding +
    '  on the drawing when the dialog closes.  Being told a slicer will have to' + LineEnding +
    '  guess is the half you knew; where is the half that helps.  OpenSCAD did not' + LineEnding +
    '  check at all before - it does now, because it goes to the same printer.' + LineEnding +
    '' + LineEnding +
    '- **/print all sends every sheet**, a page each.  /print still does the one on' + LineEnding +
    '  screen.' + LineEnding +
    '' + LineEnding +
    '- **Another color...** at the bottom of the line-color list, for a pen that' + LineEnding +
    '  is not one of the twelve.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Light mode is easier to read.**  The accent blue was too pale against' + LineEnding +
    '  light chrome - it makes 3.7 to one where the dark theme''s makes 8.4, and it' + LineEnding +
    '  is text as often as it is a fill.  It is a shade deeper now, and whatever' + LineEnding +
    '  goes on top of it when it is a fill is chosen to be readable rather than' + LineEnding +
    '  assumed to be dark, which is what put pale gray on mid blue.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.14.7' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The eraser softens as well as deletes.**  Hold Ctrl and it hides the edge' + LineEnding +
    '  instead of rubbing it out; Ctrl+Shift brings it back.  The creases down the' + LineEnding +
    '  side of a pulled circle are not edges anybody drew, and hiding them is what' + LineEnding +
    '  makes a cylinder look like a pipe rather than a barrel of staves.' + LineEnding +
    '' + LineEnding +
    '- **A line drawn along one already there splits both** where they share, so' + LineEnding +
    '  the overlap is one edge and the two tails are their own.  Before, an edge' + LineEnding +
    '  landing exactly on one was skipped and one landing halfway along it was' + LineEnding +
    '  laid on top - two lines covering the same run, which you cannot see and the' + LineEnding +
    '  program has to think about twice.' + LineEnding +
    '' + LineEnding +
    '- **A note follows the edge it points at.**  Move the edge and the leader goes' + LineEnding +
    '  with it, rather than staying aimed at where the edge used to be.' + LineEnding +
    '' + LineEnding +
    '- **The free camera has a floor.**  A faint grid on the ground, ruled at the' + LineEnding +
    '  same pitch as the paper and the scale bar, so a model stands on something' + LineEnding +
    '  and you can read how far across it a thing sits.  The GRID button turns it' + LineEnding +
    '  off with the rest.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.14.6' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **/holes shows you where a solid is not closed.**  Type it and every edge' + LineEnding +
    '  that nothing meets is drawn over the model in red.  It checks what you have' + LineEnding +
    '  selected, or every solid in the drawing if nothing is.  That is the answer' + LineEnding +
    '  a slicer will not give you when it refuses your model - the export could' + LineEnding +
    '  already say a shape was open, but not where.  The marks go the moment you' + LineEnding +
    '  change the drawing.' + LineEnding +
    '' + LineEnding +
    '- **The manual travels with the program.**  Help > The manual, or /manual,' + LineEnding +
    '  opens the copy in the `help` folder beside the executable; the release zip' + LineEnding +
    '  carries it now.  With no copy there it opens the website, as before.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.14.5' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **/reface no longer throws away a solid''s faces.**  It rebuilds faces from' + LineEnding +
    '  the lines, and a face pulled out of another face has no lines under it to' + LineEnding +
    '  be rebuilt from - so running it on a drawing of duct fittings took all 606' + LineEnding +
    '  faces off and brought none back, and on the example toy it stripped the' + LineEnding +
    '  body bare.  What cannot be remade is now left alone, and it says how many.' + LineEnding +
    '' + LineEnding +
    '- **An export cannot be closed while it is writing.**  The bar that was added' + LineEnding +
    '  last release works by letting the window paint between frames, which also' + LineEnding +
    '  let Cancel and the close cross be pressed - and closing the window out from' + LineEnding +
    '  under the code writing the file is a crash, not a cancel.' + LineEnding +
    '' + LineEnding +
    '- **The example opens with its faces already settled.**  Opening a file tells' + LineEnding +
    '  the program which areas are filled, including the ones somebody emptied on' + LineEnding +
    '  purpose; the example was skipping that step, so it did not quite look like' + LineEnding +
    '  itself until you asked for a rebuild by hand.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.14.4' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The What''s new screen is dressed like the rest of the program.**  It was' + LineEnding +
    '  a stock white box with one weight of one color and the bold markers of the' + LineEnding +
    '  file showing as asterisks.  Now the version, the headings and the lead-in' + LineEnding +
    '  of each note are told apart, and it scrolls with the wheel.' + LineEnding +
    '' + LineEnding +
    '- **An export says how far along it is.**  A twelve second film is three' + LineEnding +
    '  hundred drawings of the model, and the window used to stop answering for' + LineEnding +
    '  the whole of it.  There is a bar now, frame by frame, and an hourglass.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The splash screen fits its own window.**  On a Windows machine at a' + LineEnding +
    '  scaled display it was drawing the panel and the writing at one size inside' + LineEnding +
    '  a window at another, leaving them stranded in the corner.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.14.3' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The last tab can be closed.**  Its cross was hidden when only one sheet' + LineEnding +
    '  was left, which left you with a drawing you could not put down and nothing' + LineEnding +
    '  saying why.  Closing it closes the drawing and puts the example back up -' + LineEnding +
    '  which is what the program starts with anyway.' + LineEnding +
    '' + LineEnding +
    '- **A new tab starts with the example on it.**  Rubbing a drawing out is one' + LineEnding +
    '  gesture; drawing one from nothing is not.  Ctrl+N still gives a blank sheet,' + LineEnding +
    '  and now really does - it had been mentioned in the hints for a while without' + LineEnding +
    '  being wired to anything.' + LineEnding +
    '' + LineEnding +
    '- **Closing the last sheet puts the drawing down for good.**  It used to come' + LineEnding +
    '  back on the next launch, because the draft is written continuously and' + LineEnding +
    '  nothing ever told it the drawing had been closed on purpose.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Closing an untouched sheet asks nothing.**  The example arrives with 310' + LineEnding +
    '  things on it, so putting it down brought up "save the drawing first?" - a' + LineEnding +
    '  question about somebody else''s work.  It asks only when something has' + LineEnding +
    '  actually changed.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.14.2' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A portable program keeps its files with it.**  Drawings are offered a' + LineEnding +
    '  `drawings` folder beside the program and exports an `exports` folder, both' + LineEnding +
    '  made the first time they are needed.  Nothing is put in your home folder' + LineEnding +
    '  any more - carry the program on a stick and the work goes with it.' + LineEnding +
    '' + LineEnding +
    '- **It remembers where you put things.**  The last folder you saved a drawing' + LineEnding +
    '  to, the last one you opened from, and the last one you sent each kind of' + LineEnding +
    '  export to - so STLs go where the printer looks and pictures go where the' + LineEnding +
    '  forum post is being written, without being asked twice.  Open starts in the' + LineEnding +
    '  program''s own folder until you have opened something.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The GIF settings are the ones that matter now.**  The seconds box, the' + LineEnding +
    '  frame rate box and the spin they described are gone: record a move and that' + LineEnding +
    '  is the film.  Play plays back what you recorded rather than a turn of its' + LineEnding +
    '  own, and the line saying there was no clip yet is no longer printed across' + LineEnding +
    '  the button underneath it.' + LineEnding +
    '' + LineEnding +
    '- **A three second count-in takes three seconds.**  The recorder was counting' + LineEnding +
    '  timer ticks instead of looking at the clock, and every tick redraws the' + LineEnding +
    '  model - so on a drawing of any size the count-in stretched to eight.  Worse,' + LineEnding +
    '  it then wrote down three seconds of timestamps over eight seconds of' + LineEnding +
    '  movement, which is what made the film jumpy.' + LineEnding +
    '' + LineEnding +
    '- **The recorder no longer makes the whole program sticky.**  It was building' + LineEnding +
    '  and throwing away a picture the size of the preview thirty times a second.' + LineEnding +
    '  It keeps one and draws into it, and redraws only as often as the eye needs' + LineEnding +
    '  rather than as often as the camera is written down.  The export preview did' + LineEnding +
    '  the same thing and now does not.' + LineEnding +
    '' + LineEnding +
    '- **Notes that are whole sentences wrap instead of running off both ends.**' + LineEnding +
    '  The STL note was losing its first letter and its last.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.14.1' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Pushing a letter, or a piece of the robot, raises it with walls.**  It' + LineEnding +
    '  used to slide the whole toy instead.  A shape drawn inside another shape -' + LineEnding +
    '  a letter in a panel, a plaque on a wall, a window pane - only ever touches' + LineEnding +
    '  what it sits in along the opening cut to hold it, and push/pull was only' + LineEnding +
    '  looking at outlines, so it read the letter as the whole flat side of the' + LineEnding +
    '  toy and moved the toy.' + LineEnding +
    '' + LineEnding +
    '- **Push a whole side of a solid and whatever is cut out of it comes too.**' + LineEnding +
    '  The top of the toy has fourteen letter-shaped openings in it; sliding the' + LineEnding +
    '  top left all fourteen behind at the old height and tore the solid open' + LineEnding +
    '  along every letter.  Of the 133 faces on the example, 56 used to leave it' + LineEnding +
    '  open when pushed.  None do now.' + LineEnding +
    '' + LineEnding +
    '- **An opening pushed up is lined the right way out.**  A ring pushed into a' + LineEnding +
    '  foundation wall had the inside of the hole wound inside out, which is a' + LineEnding +
    '  solid no slicer can read.' + LineEnding +
    '' + LineEnding +
    '- **The robot''s eyes are drawn inside its head.**  They were cut out of the' + LineEnding +
    '  screen instead, so the head lay straight over the top of them - two faces' + LineEnding +
    '  fighting over the same pixels, and a solid that came apart as soon as' + LineEnding +
    '  either was pushed.' + LineEnding +
    '' + LineEnding +
    '- **The Report a problem box no longer cuts off the paragraph at the top.**' + LineEnding +
    '  It had room for four lines of text at the font it was written at, and not' + LineEnding +
    '  at a larger one.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.14' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The letters of the logo, and the robot, can be pushed now.**  They were' + LineEnding +
    '  lines with no faces under them, and a drawing read from a file never has its' + LineEnding +
    '  faces worked out - everything in a saved file is taken as settled, so a' + LineEnding +
    '  region with no face is one whose face was rubbed out on purpose.  Quite' + LineEnding +
    '  right for a file the program saved, and it meant the example, which was' + LineEnding +
    '  written by hand, could never grow them.  The faces are in the file now.' + LineEnding +
    '' + LineEnding +
    '- **The example opens framed, near the origin.**  It was written with no pan' + LineEnding +
    '  at all, which put the origin in the corner of the view and the toy away off' + LineEnding +
    '  to one side.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.27' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Each letter of the logo is one shape now.**  It was built out of separate' + LineEnding +
    '  bars, which left a line across every join and meant pushing an H up took' + LineEnding +
    '  three goes and came out with seams down it.  Click a letter once and push it' + LineEnding +
    '  once, and the whole letter stands up.' + LineEnding +
    '' + LineEnding +
    '- **The toy sits in the positive corner.**  Its near bottom left is on the' + LineEnding +
    '  origin, so the whole thing is inside the solid halves of the axes instead of' + LineEnding +
    '  straddling the dashed ones - nine inches along is nine inches, not minus' + LineEnding +
    '  four and a half.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.26' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The toy says HECKERS SKETCH on it**, in block capitals drawn the way the' + LineEnding +
    '  toy itself would draw them.  Each letter is one closed shape, so clicking it' + LineEnding +
    '  once and pushing lifts the whole letter - no seams, no doing it three times' + LineEnding +
    '  for an H.' + LineEnding +
    '' + LineEnding +
    '- **The toy sits in the positive corner** now, with its near bottom left on the' + LineEnding +
    '  origin, so the whole thing is inside the solid halves of the axes rather' + LineEnding +
    '  than straddling the dashed ones.' + LineEnding +
    '' + LineEnding +
    '- **A new program icon**, which is the toy.' + LineEnding +
    '' + LineEnding +
    '- **An `examples` folder beside the program.**  The toy is written out there' + LineEnding +
    '  every time it starts, over the top of whatever was there.  That is on' + LineEnding +
    '  purpose: an example is a thing to take apart, and having taken it apart you' + LineEnding +
    '  should find it whole again next time rather than meet your own' + LineEnding +
    '  half-dismantled version.  Keep your own by saving it under a name of your' + LineEnding +
    '  own.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The toy''s corners are rounded** - on the body and around the screen - the' + LineEnding +
    '  way a thing you would hand a child is.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.25' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **It opens with something on it now.**  A run with nothing to show - no' + LineEnding +
    '  drawing named, no draft to pick up - used to be an empty sheet, which tells' + LineEnding +
    '  you nothing about what this is for.  It opens a toy etch-a-sketch instead:' + LineEnding +
    '  a solid to orbit, a screen to look at, and a robot drawn on it in lines' + LineEnding +
    '  that is asking to be pushed.  **Ctrl+N** for an empty sheet, and once you' + LineEnding +
    '  have drawn anything you will never see it again.' + LineEnding +
    '' + LineEnding +
    '  It is carried inside the program, so a portable build is still one file.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A shape with a hole in it can be closed.**  A picture frame, or the' + LineEnding +
    '  surround of a recessed screen, is a face with a hole cut out of it - and' + LineEnding +
    '  the hole''s edge is as much the boundary of the solid as the outside is.' + LineEnding +
    '  It was only counting the outside, so anything shaped that way read as not' + LineEnding +
    '  closed however well it was built, and the STL said a slicer would have to' + LineEnding +
    '  guess.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.24' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The button on a failed export said "Tell us about it".**  It sends a' + LineEnding +
    '  bug report, so now it says so.' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Help pages.**  `docs/help/index.html` - one page for every tool and one' + LineEnding +
    '  for each of the things you do with a drawing.  They have no pictures in' + LineEnding +
    '  them yet; the words are there.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.23' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The GIF recorder is one room now.**  Setting a start and an end used to be' + LineEnding +
    '  in the export dialog while the recording was in a window of its own - two' + LineEnding +
    '  ways to do one thing, and no sign in the dialog which of them you had used.' + LineEnding +
    '  It is all in the one window, and the export dialog either has a clip or it' + LineEnding +
    '  does not.' + LineEnding +
    '' + LineEnding +
    '  In it: where to **start from** - front, back, left, right, top, or any of the' + LineEnding +
    '  four corners - **what move** to make, and **how long** it should last.  Then' + LineEnding +
    '  Record.' + LineEnding +
    '' + LineEnding +
    '  **A filmstrip along the bottom fills up as it records**, so you can see there' + LineEnding +
    '  is something there rather than take it on trust.  Play it, Clear it and go' + LineEnding +
    '  again, or Use this clip - which drops you back to the export dialog with it' + LineEnding +
    '  in hand.  There is deliberately nothing else you can do to the strip: for a' + LineEnding +
    '  clip this short, keeping it or doing it again are the only two things worth' + LineEnding +
    '  offering.' + LineEnding +
    '' + LineEnding +
    '- **Eight canned moves, so you need not fly it by hand.**' + LineEnding +
    '' + LineEnding +
    '  *Turntable* is one turn on the spot.  *Rise* turns while climbing, so a' + LineEnding +
    '  thing shows you its sides and then its lid.  *Underneath to over the top*' + LineEnding +
    '  starts below it looking up and finishes looking down.  *Nod* goes down to up' + LineEnding +
    '  and back without turning at all, for something with a front that turning' + LineEnding +
    '  would only hide.  *Half a turn and back* reads like somebody picking a thing' + LineEnding +
    '  up rather than a machine spinning it.  *Corner to corner* sweeps from one' + LineEnding +
    '  low corner to the opposite high one.  *The full look* goes over, under, back' + LineEnding +
    '  to level and round, so every face comes past the camera.  And *push in*' + LineEnding +
    '  closes slowly with a little drift, for a detail.' + LineEnding +
    '' + LineEnding +
    '  **The ones you use come to the top of the list**, and stay there between' + LineEnding +
    '  sessions - eight is a comfortable number to offer and a tiresome number to' + LineEnding +
    '  read every time, and most people settle on two or three.' + LineEnding +
    '' + LineEnding +
    '  All of them turn about **the middle of whatever you had selected** when you' + LineEnding +
    '  pressed Export, not about the drawing''s origin - so a building drawn half a' + LineEnding +
    '  mile from zero does not swing out of frame.  Set the zoom you want with the' + LineEnding +
    '  wheel first and the move starts from there.' + LineEnding +
    '' + LineEnding +
    '- **Center on the Origin is on the right button.**  Select something, right' + LineEnding +
    '  click, and it moves onto 0,0,0.  Same thing as `/center`.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.22' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **STL and OpenSCAD come out centerd on the origin.**  A part used to open in' + LineEnding +
    '  the slicer wherever the drawing happened to put it, which for something drawn' + LineEnding +
    '  at building coordinates is a long way off the plate - and then you re-center' + LineEnding +
    '  it by hand in another program.  It arrives centerd now.  There is a tick in' + LineEnding +
    '  the export options if you want it left where it is.' + LineEnding +
    '' + LineEnding +
    '- **`/center` moves things onto the origin.**  Type `/center` and whatever is' + LineEnding +
    '  selected moves so the middle of it sits at 0,0,0 - or the whole drawing, if' + LineEnding +
    '  nothing is selected.  Worth doing to the drawing itself and not only on the' + LineEnding +
    '  way out: a drawing that is centerd is one where the exports, the dimensions' + LineEnding +
    '  from the origin and the axis readings all agree.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.21' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Export to OpenSCAD.**  Export, then "OpenSCAD".  You get a `.scad` script' + LineEnding +
    '  with one `polyhedron` per solid in your drawing, each in its own named' + LineEnding +
    '  module, a module that unions them all, and a call to it - so a model in' + LineEnding +
    '  several pieces stays in several pieces and you can get at them separately.' + LineEnding +
    '  Millimeters, like the STL.' + LineEnding +
    '' + LineEnding +
    '  Be clear about what it is: the surface of your drawing, written out as' + LineEnding +
    '  points and faces.  It is not built from cubes and cylinders and cannot be' + LineEnding +
    '  taken apart into them, so the numbers in it are not parameters to tweak -' + LineEnding +
    '  to change the shape, change it here and export it again.  What it is good' + LineEnding +
    '  for is everything *around* it: cut holes in it, union it onto something,' + LineEnding +
    '  fit it to a part you are describing in OpenSCAD.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.20' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The preview and the recording window now handle like the drawing.**' + LineEnding +
    '  Middle-drag turns it, right-drag slides it, the left button does nothing,' + LineEnding +
    '  and the wheel zooms on the pointer rather than the middle of the picture -' + LineEnding +
    '  all the same as the drawing area, at the same speed.  They were all' + LineEnding +
    '  different before, which is why moving around in there felt odd.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.19' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The preview and the recording window now handle like the drawing.**' + LineEnding +
    '  Middle-drag turns it, right-drag slides it, the left button does nothing,' + LineEnding +
    '  and the wheel zooms on the pointer rather than the middle of the picture -' + LineEnding +
    '  all the same as the drawing area, at the same speed.  They were all' + LineEnding +
    '  different before, which is why moving around in there felt odd.' + LineEnding +
    '' + LineEnding +
    '- **The GIF export crash, properly this time - and a correction.**  The last' + LineEnding +
    '  release blamed memory and rationed the frames accordingly.  That was wrong.' + LineEnding +
    '' + LineEnding +
    '  It was one missing line.  A GIF holds 256 colors and something has to' + LineEnding +
    '  choose which 256; in BGRABitmap that chooser is pluggable, and naming its' + LineEnding +
    '  unit is not enough - the factory has to be handed over explicitly.  It never' + LineEnding +
    '  was.  So any frame with more than 256 colors in it reached nothing at all' + LineEnding +
    '  and the program fell over.' + LineEnding +
    '' + LineEnding +
    '  Which is exactly why it looked so strange: a plain line drawing exports' + LineEnding +
    '  fine, because white paper, gray faces and black lines fit inside 256' + LineEnding +
    '  colors easily.  Turn on the axes and three anti-aliased colored lines put' + LineEnding +
    '  it over, every time.  It had nothing to do with how long the film was.' + LineEnding +
    '' + LineEnding +
    '  Reproduced here on Linux in the end, tracked to the line, fixed, and there' + LineEnding +
    '  is now a test that exports a film **with the axes on** - which is the' + LineEnding +
    '  default, and which the old test did not do, which is how it got out.' + LineEnding +
    '' + LineEnding +
    '- **And the files were never big.**  A four second spin of a complicated' + LineEnding +
    '  model is 1.35 MB at 800 x 600, and the 15.9 second recording that started' + LineEnding +
    '  all this now comes out at 0.70 MB.  The dialog says roughly what it will' + LineEnding +
    '  weigh before you press the button.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.18' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The Windows access violation on exporting a GIF.**  Your report had it:' + LineEnding +
    '  a 15.9 second recording at 20 a second is 318 frames, and a GIF is built' + LineEnding +
    '  whole in memory - every frame held until the last one is in, and then the' + LineEnding +
    '  packing pass duplicates them all as it walks.  At 800 x 600 that is over' + LineEnding +
    '  half a gigabyte of frames before it even starts packing.' + LineEnding +
    '' + LineEnding +
    '  The number of frames now comes from the size as well as the length,' + LineEnding +
    '  whatever fits in a sensible budget, and the packing step is skipped when it' + LineEnding +
    '  would cost more than it saves - which on a turning model is most of the' + LineEnding +
    '  time, since every pixel changes between frames and there is nothing still' + LineEnding +
    '  to leave out.  **The film keeps its full length**: what gives is the frame' + LineEnding +
    '  rate, not the ending, because losing the end of your move is a worse answer' + LineEnding +
    '  than making it slightly choppier.' + LineEnding +
    '' + LineEnding +
    '  Your 15.9 seconds at 800 x 600 now comes out as 104 frames at 7 a second,' + LineEnding +
    '  still 15.9 seconds long.  The dialog says so before you press the button,' + LineEnding +
    '  and tells you a smaller size buys you more frames.' + LineEnding +
    '' + LineEnding +
    '- **A recording no longer quietly ignores the seconds box.**  It fills it in' + LineEnding +
    '  instead, so what it says is what you get - that mismatch is how four' + LineEnding +
    '  seconds turned into three hundred frames.' + LineEnding +
    '' + LineEnding +
    '- **A failed export now names the frame.**  It used to say "while drawing the' + LineEnding +
    '  frames", which covered the drawing, the packing and the writing all at' + LineEnding +
    '  once.  It now says which of the three, and which frame of how many.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.17' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Export could fail on Windows with an access violation and no file.**  I' + LineEnding +
    '  have not been able to reproduce it here and I am not going to pretend' + LineEnding +
    '  otherwise, so this release makes it tell us instead: when an export fails it' + LineEnding +
    '  now says which step it died in and what it was doing, and there is a' + LineEnding +
    '  **Tell us about it** button right there in the dialog that sends the whole' + LineEnding +
    '  thing - the format, the size, the settings, the lot.  One press and the next' + LineEnding +
    '  release can actually fix it.' + LineEnding +
    '' + LineEnding +
    '  Some real hardening went in alongside: a film now draws every frame into one' + LineEnding +
    '  picture instead of making and destroying one per frame, which on a long GIF' + LineEnding +
    '  was eighty allocations for no reason; and a picture that cannot be made at' + LineEnding +
    '  the size asked for now says so rather than carrying on with it.' + LineEnding +
    '' + LineEnding +
    '- **The export preview would turn but not slide.**  Right-drag or Shift-drag' + LineEnding +
    '  now slides it, the wheel zooms, and Shift is noticed part way through a turn' + LineEnding +
    '  the same as it is in the drawing area - so you can frame the shot properly' + LineEnding +
    '  instead of only spinning it.' + LineEnding +
    '' + LineEnding +
    '- **Black writing on the dark dialog.**  Windows paints its own drop-down' + LineEnding +
    '  lists and tick boxes and takes no notice of what color it has been asked' + LineEnding +
    '  for, so some of the export dialog came out black on near-black.  It draws' + LineEnding +
    '  its own now.' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Export sizes worth having.**  Square, tall, wide, link card, 720p, 1080p,' + LineEnding +
    '  small-for-an-email - or type your own.  And asking for something enormous' + LineEnding +
    '  now quietly brings it down to something that will actually save, instead of' + LineEnding +
    '  refusing with "that size will not do".' + LineEnding +
    '' + LineEnding +
    '- **Record a camera move instead of describing one.**  In the GIF panel,' + LineEnding +
    '  "Record a move instead" opens a window with nothing in it but your model.' + LineEnding +
    '  It counts you down from three, then simply watches where you point the' + LineEnding +
    '  camera - turn it, slide it, zoom in, pause on the good bit - and you press' + LineEnding +
    '  Escape when you are done.  What comes out is the move you made.' + LineEnding +
    '' + LineEnding +
    '  It records where the camera was, not what was on the screen, so none of the' + LineEnding +
    '  cursor, the snapping lines or the hover marks get anywhere near the film,' + LineEnding +
    '  and it can be saved at any size afterwards.  The red, green and blue axes do' + LineEnding +
    '  stay, because they are what tells you which way up the thing is - there is a' + LineEnding +
    '  tick to turn them off.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.16' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A proper export dialog.**  Press Export and you get a room with the' + LineEnding +
    '  formats down one side, a live view of your model in the middle, and the' + LineEnding +
    '  settings for that format on the right - instead of a save box with the file' + LineEnding +
    '  types hidden in a dropdown and nothing at all to set.' + LineEnding +
    '' + LineEnding +
    '  Turn the model with the mouse and zoom with the wheel: what you see in the' + LineEnding +
    '  middle is the shot.  Pictures can come out at twice or four times the size' + LineEnding +
    '  of the screen, or any size you type, and a PNG can have nothing behind it at' + LineEnding +
    '  all, for dropping onto a slide.' + LineEnding +
    '' + LineEnding +
    '- **Export an animated GIF.**  Frame where it should start, frame where it' + LineEnding +
    '  should end, and it swings between the two - a turntable spin, a slow push' + LineEnding +
    '  in, a tilt down onto a roof, or all three at once.  There is a button for a' + LineEnding +
    '  full spin from wherever you happen to be looking, and one to watch the whole' + LineEnding +
    '  thing before you commit to it.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.15' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Blue patches on shapes that had nothing wrong with them.**  Two separate' + LineEnding +
    '  causes, and neither was what the last two releases were chasing.' + LineEnding +
    '' + LineEnding +
    '  A shape whose top had been divided - by a line drawn across it, or a piece' + LineEnding +
    '  pushed up out of it - was being read as though it had a gap in it, because' + LineEnding +
    '  one long edge on a wall no longer matched the two shorter ones that had' + LineEnding +
    '  replaced it on top.  It was watertight all along, and is now recognized as' + LineEnding +
    '  such, so its far side stops showing through.' + LineEnding +
    '' + LineEnding +
    '  And faces worked out from lines were each wound on their own, which meant' + LineEnding +
    '  the two slopes of a roof could end up pointing opposite ways - one of them' + LineEnding +
    '  into the house.  Looking at it from outside, that one was blue.  They are' + LineEnding +
    '  now settled against their neighbors, so a roof points out of the building' + LineEnding +
    '  rather than into it, and `/rebuild` puts an old drawing right.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.14' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Export to STL, for a 3D printer.**  Export, then "STL - for a 3D' + LineEnding +
    '  printer".  It writes the model as triangles in millimeters, which is what' + LineEnding +
    '  every slicer expects, so a drawing in feet comes out the size you drew it' + LineEnding +
    '  rather than three hundred times too small.' + LineEnding +
    '' + LineEnding +
    '  It also tells you whether the shape is actually closed.  That part matters:' + LineEnding +
    '  a slicer will accept a model with holes in it and guess where the inside is,' + LineEnding +
    '  and an hour into a print is a bad time to find out it guessed wrong.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A correction to what the last release claimed.**  13 gave a number for how' + LineEnding +
    '  much the new depth handling improved things.  That number was measured' + LineEnding +
    '  against the wrong yardstick and was not real, and it has been taken out of' + LineEnding +
    '  the note above.  The change itself is sound and stays - a face''s depth is' + LineEnding +
    '  now exact at its corners instead of estimated - but it did not do what was' + LineEnding +
    '  claimed for it, and saying so is better than leaving it there.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.13' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Faces that are not flat are now drawn at the right depth.**  This is the' + LineEnding +
    '  end of the pale blue faces, and of a whole family of things that could go' + LineEnding +
    '  wrong with them.' + LineEnding +
    '' + LineEnding +
    '  Spinning or pushing a sloped edge makes a face with four corners that do' + LineEnding +
    '  not all lie in one plane - there is no such thing as the right flat sheet' + LineEnding +
    '  for one of those, and the drawing had been picking the best one it could' + LineEnding +
    '  and living with the error.  On the crown that error was up to fifteen feet,' + LineEnding +
    '  which is more than enough for the far side of a solid to be judged nearer' + LineEnding +
    '  than the near side and painted over it.' + LineEnding +
    '' + LineEnding +
    '  Every such face is now cut into triangles first.  A triangle has exactly' + LineEnding +
    '  one plane and always lies in it, so there is nothing left to estimate: the' + LineEnding +
    '  depth is right at every corner of the face, and in between it can never' + LineEnding +
    '  stray outside the corners it sits between.' + LineEnding +
    '' + LineEnding +
    '  Faces that really are flat are untouched and cost nothing extra - a drawing' + LineEnding +
    '  made only of flat faces comes out pixel for pixel as it did before.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.12' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The last of the pale blue on solids.**  13.11 got most of it; thin' + LineEnding +
    '  slivers were still showing in the crevices of a revolved shape.' + LineEnding +
    '' + LineEnding +
    '  Two things, and both are now right.  The first: faces that are not flat.' + LineEnding +
    '  Spinning a sloped piece of an outline gives a warped four-cornered face -' + LineEnding +
    '  one no flat sheet passes through - and the drawing worked out how far away' + LineEnding +
    '  each face is by fitting a sheet through three of its corners.  On one shape' + LineEnding +
    '  sent in, that fit was wrong by up to five hundred feet on a model two' + LineEnding +
    '  hundred feet across.  It fits every corner now, evenly, which brings it' + LineEnding +
    '  down to twelve.' + LineEnding +
    '' + LineEnding +
    '  The second, which finishes it: **the back of a closed solid is no longer' + LineEnding +
    '  drawn at all.**  It cannot be seen - to look at one you would have to be' + LineEnding +
    '  inside the thing - so however the depth works out, drawing it is wrong.' + LineEnding +
    '  An open shell still shows its back, because there you really can look at' + LineEnding +
    '  it, and that is what the pale blue is for.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.11' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Pale blue faces on a solid that is not inside out.**  A round shape - a' + LineEnding +
    '  revolve, or anything pushed out of one - could show patches of the' + LineEnding +
    '  back-face color on its near side.  Nothing was wrong with it: the far side' + LineEnding +
    '  of the object was showing through the near side, and the far side of' + LineEnding +
    '  anything is its inside.' + LineEnding +
    '' + LineEnding +
    '  Faces that are not flat were the cause.  Spinning a sloped piece of an' + LineEnding +
    '  outline gives a warped four-cornered face - one no flat sheet passes' + LineEnding +
    '  through - and the drawing worked out how far away each face is by fitting a' + LineEnding +
    '  flat sheet to three of its corners.  On one shape sent in, 48 of its 336' + LineEnding +
    '  faces were out of flat, and the fit was wrong by up to five hundred feet on' + LineEnding +
    '  a model two hundred feet across: enough for the back of the thing to be' + LineEnding +
    '  judged nearer than the front.' + LineEnding +
    '' + LineEnding +
    '  It fits every corner now, evenly, instead of three exactly and the rest not' + LineEnding +
    '  at all.  Which is also why it only ever showed on faces pointing certain' + LineEnding +
    '  ways round a shape - whether a badly fitted sheet leans toward you or away' + LineEnding +
    '  depends on which way the warp is turned.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.10' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The drill goes all the way through.**  It had to land its far end exactly' + LineEnding +
    '  on the plane of the wall it comes out of - to a millionth - or it quietly' + LineEnding +
    '  made a solid plug instead of a tunnel, and left what looked like a wall' + LineEnding +
    '  across the hole.  Nobody can drag to a millionth, and the far face is' + LineEnding +
    '  behind the near one so there is nothing to hover over either.  The tool' + LineEnding +
    '  works the distance out now: click the face, click roughly where you want' + LineEnding +
    '  it, and it comes out the far side.  Both mouths open, and where it crosses' + LineEnding +
    '  a tunnel already there the two are cut into each other.' + LineEnding +
    '' + LineEnding +
    '- **The program''s name has gone from the top of the window.**  The reading -' + LineEnding +
    '  X, Y, Z, the plane and the run - grows leftwards as it gets longer and was' + LineEnding +
    '  running over the top of it.  The version stays, over on the left where' + LineEnding +
    '  nothing reaches.' + LineEnding +
    '' + LineEnding +
    '- **No stray line flashing after a shape is thrown away.**  The two ends' + LineEnding +
    '  flying apart is a thing about a line snapping; a rectangle or a circle only' + LineEnding +
    '  gets the burst now.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.9' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A rectangle no longer vanishes when it is drawn nearly along an axis.**' + LineEnding +
    '  The alignments are built for a line, where being pulled level with the' + LineEnding +
    '  point you started from is the whole idea.  On a rectangle it means a side' + LineEnding +
    '  of no length, which is not a rectangle - so it was thrown away, with' + LineEnding +
    '  nothing on screen to say why, on and off depending on which way you' + LineEnding +
    '  happened to drag.  An alignment that would flatten a side is now ignored,' + LineEnding +
    '  and that side lands on the grid like everything else.' + LineEnding +
    '' + LineEnding +
    '- And when a rectangle really is too small in one direction to draw, it says' + LineEnding +
    '  so with the sizes and the snap setting instead of just "a rectangle needs' + LineEnding +
    '  two sides".' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **Push/pull, drill and offset can be called off by leaning on the button**,' + LineEnding +
    '  the way the drawing tools already could.  They used to happen the instant' + LineEnding +
    '  the button went down, so realizing it was wrong meant undo.  Now they wait' + LineEnding +
    '  for it to come up: let go and it happens, keep holding and the face you' + LineEnding +
    '  were about to build strains and goes back having built nothing.' + LineEnding +
    '' + LineEnding +
    '- The whole shape comes under tension while you hold, not one strand of it -' + LineEnding +
    '  a rectangle swells like a frame of elastic, a circle like a hoop, a' + LineEnding +
    '  push/pull shows the face where it would have landed.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.8' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **Lean on the button and the whole shape comes under tension**, not one' + LineEnding +
    '  strand of it.  A rectangle swells like a frame of elastic, a circle like a' + LineEnding +
    '  hoop, each side bowing outward and trembling harder the nearer it gets to' + LineEnding +
    '  letting go - then one burst at the middle.  It used to strain a single' + LineEnding +
    '  diagonal from the first corner to the cursor, which is not any part of the' + LineEnding +
    '  rectangle and read as though something else had appeared in order to be' + LineEnding +
    '  destroyed.' + LineEnding +
    '' + LineEnding +
    '- **Up and down both lock the ground plane now.**  They are one gesture and' + LineEnding +
    '  they mean one thing - flat, the way up and down mean flat on a table.  Left' + LineEnding +
    '  and right are still the two upright planes.  Esc lets go, as it always did' + LineEnding +
    '  and as every message says.' + LineEnding +
    '' + LineEnding +
    '- **The plane shows itself before the first corner too**, not just once you' + LineEnding +
    '  have started drawing - so flipping between planes tells you which one you' + LineEnding +
    '  are about to get while there is still nothing on the paper.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.7' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A locked plane shows itself while you draw.**  Lock a plane with the' + LineEnding +
    '  arrows and two short lines appear through the point, along the plane''s own' + LineEnding +
    '  two directions, in their axis colors.  Red and blue means you are drawing' + LineEnding +
    '  upright; red and green means flat.  You can see you are still on the plane' + LineEnding +
    '  without reading anything.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.6' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A plane you lock with the arrows now stays locked.**  Press L, then the' + LineEnding +
    '  left arrow to stand the plane up, and every point of the shape lands on' + LineEnding +
    '  that plane no matter what the cursor is pointed at.  It could not before:' + LineEnding +
    '  the plane''s position came from wherever the cursor had last settled, so a' + LineEnding +
    '  single inference a foot off the plane took the plane with it, and every' + LineEnding +
    '  corner after that was on a different one.  The outline never closed, no' + LineEnding +
    '  face was ever made, and there was nothing on screen to say why.' + LineEnding +
    '' + LineEnding +
    '  That is why drawing an upright outline in the 3D view was so hard, and why' + LineEnding +
    '  drawing it flat on the floor was the only thing that worked.' + LineEnding +
    '' + LineEnding +
    '  An axis lock still beats it - that is you saying something more recent.' + LineEnding +
    '  Nothing else does: an arrow lock is a statement, not a guess.' + LineEnding +
    '' + LineEnding +
    '- **And the line tool says so.**  In a 3D view it now reads *"pick a start' + LineEnding +
    '  point (arrows lock a flat plane: left upright, right side-on, up flat, down' + LineEnding +
    '  to let go)"*, and once locked, *"held on the XZ plane whatever you point' + LineEnding +
    '  at"*.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.5' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **Revolve: click the outline, then click its straight side.**  Two clicks.' + LineEnding +
    '  The straight side of a glass outline *is* the middle of the glass, and' + LineEnding +
    '  clicking it is what anybody does when asked for an axis - it used to mean' + LineEnding +
    '  "sweep the outline along this line", which cannot be done and quietly did' + LineEnding +
    '  nothing.  Now it means what it looks like it means.' + LineEnding +
    '' + LineEnding +
    '  Two loose points still work for an axis that is not an edge, and any other' + LineEnding +
    '  line is still a path to sweep along.' + LineEnding +
    '' + LineEnding +
    '- **It shows you what it is about to make.**  While you are placing the axis:' + LineEnding +
    '  the axis itself drawn as a long line rather than a stub between two clicks,' + LineEnding +
    '  and the two rings the nearest and furthest corners of the outline will' + LineEnding +
    '  sweep - which is the footprint of the result, before you commit to it.' + LineEnding +
    '' + LineEnding +
    '- **And it says when the axis is wrong.**  An axis through the middle of the' + LineEnding +
    '  outline sweeps the two halves into each other and makes a knot with no' + LineEnding +
    '  outside.  The preview goes red, and it refuses with an explanation instead' + LineEnding +
    '  of doing it: *"A glass is spun about a line down one side of its outline,' + LineEnding +
    '  not through it."*' + LineEnding +
    '' + LineEnding +
    '- After it spins, it says how big the thing is - *"Spun 360° in 24 gores,' + LineEnding +
    '  0''-1" to 0''-9 5/8" across."*' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **`/replay` and `/session` keep the capitals in a file name.**  The command' + LineEnding +
    '  bar folds what you type to lower case so that LINE and line are the same' + LineEnding +
    '  tool, and it was folding the path too - so replaying anything under a' + LineEnding +
    '  folder with a capital letter in it said the file did not exist.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.4' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **Follow Me is called REVOLVE now, and it is on the tool strip beside' + LineEnding +
    '  push/pull.**  Draw the outline of half of something - a glass, a bowl, a' + LineEnding +
    '  bollard, a pipe fitting - click it, then click two points for the axis, and' + LineEnding +
    '  it spins into a solid.  Type an angle first for a part turn.' + LineEnding +
    '' + LineEnding +
    '  It could always do this.  It was called Follow Me, which is SketchUp''s name' + LineEnding +
    '  for the other half of what it does (sweeping a face along a path, which it' + LineEnding +
    '  still does), and it was behind the MORE door - so the one thing everybody' + LineEnding +
    '  else calls a lathe was under a name nobody else uses, in a drawer.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A shape off the lathe comes out the right way round.**  Which way each' + LineEnding +
    '  strip faced was worked out by pointing away from the middle of the outline,' + LineEnding +
    '  and the middle of a thin C-shaped outline - the wall of a glass, say - is' + LineEnding +
    '  in the hollow rather than in the material, so half the shape came out' + LineEnding +
    '  inside out and pale blue.  It uses the outline''s own winding now, which' + LineEnding +
    '  does not care what shape it is.' + LineEnding +
    '' + LineEnding +
    '- **Replaying a session gets the tools that pick things.**  A recorded press' + LineEnding +
    '  carried the point in the model but not where that lands on the screen, so' + LineEnding +
    '  replaying one hit Revolve, Push/Pull and the eraser with wherever the mouse' + LineEnding +
    '  had last been left rather than where the click was.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.3' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **PLAN is on the VIEW menu again**, at the top, saying what it is - and TOP' + LineEnding +
    '  says what *it* is, which is the 3D camera pointed down and not a plan at' + LineEnding +
    '  all.  Plan had been taken off that menu back when it was a half-finished' + LineEnding +
    '  paper mode, so the only way into the cut and everything built on it was to' + LineEnding +
    '  know that `/plan` existed.' + LineEnding +
    '' + LineEnding +
    '- **The doors on the tool strip close when you click them again.**  MORE' + LineEnding +
    '  TOOLS and SHOP opened their lists and would not put them away.  Clicking a' + LineEnding +
    '  tool, or the bare strip, closes an open list too.' + LineEnding +
    '' + LineEnding +
    '- **The right-button menu always has the same rows**, with the ones that' + LineEnding +
    '  would do nothing grayed out instead of missing - and **Erase is last**.' + LineEnding +
    '  It was built the other way, so on a shape where the click landed on an' + LineEnding +
    '  edge rather than a face, Reverse Face was absent, Erase moved up into the' + LineEnding +
    '  row Reverse Face is normally in, and the same click in the same place' + LineEnding +
    '  erased the thing instead of turning it over.' + LineEnding +
    '' + LineEnding +
    '- **The right button can reach the faces of a round thing.**  A cylinder''s' + LineEnding +
    '  sides are about ten pixels wide on screen and the edge under the cursor' + LineEnding +
    '  was winning from nine pixels away, so a right-click on a curved surface' + LineEnding +
    '  always got an edge and never the face.  It takes an edge from four pixels' + LineEnding +
    '  now; aim at one and you still get it, be anywhere in the middle of a face' + LineEnding +
    '  and you get the face.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.2' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A plan shows what is underneath, dashed.**  A wall beneath a roof, a' + LineEnding +
    '  beam over a door, a footing under a slab - anything a plan cannot see is' + LineEnding +
    '  now drawn as a dashed gray line instead of being painted over and lost.' + LineEnding +
    '  That is what a drawing does and what a photograph from above does not.' + LineEnding +
    '' + LineEnding +
    '  Only in PLAN.  In the 3D view a hidden line is round the back of something' + LineEnding +
    '  solid, and dashing those would put the far side of every box on top of the' + LineEnding +
    '  near side.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13.1' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Hover anything and it tells you what it is.**  There were never any' + LineEnding +
    '  tooltips: the hover text went to a line at the top of the window, in the' + LineEnding +
    '  smallest type on it, seven hundred pixels from the pointer.  Now a card' + LineEnding +
    '  appears beside whatever you are pointing at, with the name and a sentence' + LineEnding +
    '  about what it does.' + LineEnding +
    '' + LineEnding +
    '- **Open, Save, Export, Print, Undo and Redo are at the top left**, with' + LineEnding +
    '  their names on them, where every other program keeps them.  They were in' + LineEnding +
    '  the bottom right corner among twelve identical squares.  The Heckers Sketch' + LineEnding +
    '  name has moved to the middle of that line to make room, and Undo and Redo' + LineEnding +
    '  gray out when there is nothing to undo.' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **The tools are in groups now**, with a line between them: pick, then the' + LineEnding +
    '  four shapes, then push/pull on its own, then move and erase, then measure,' + LineEnding +
    '  protractor, dimension and text, then orbit.  **Measure and the protractor' + LineEnding +
    '  have come back out of MORE** - measuring is most of why anybody opens this.' + LineEnding +
    '' + LineEnding +
    '- **SHOP is at the foot of the strip on its own, with a spanner on it.**  It' + LineEnding +
    '  is a door into the trade wizards, not a drawing tool, and it had the same' + LineEnding +
    '  arrow as MORE which made two quite different doors look like one thing.' + LineEnding +
    '  The duplicate SHOP button along the bottom has gone.' + LineEnding +
    '' + LineEnding +
    '- **The settings say what they are** - PRINT SCALE, SNAP TO, LINE COLOR,' + LineEnding +
    '  LINE WIDTH, ROUNDED TO.  "PREC" is gone; so is "SET".  The buttons beside' + LineEnding +
    '  them have names too: FIT, ORIGIN, GRID, UNITS, THEME, HELP.' + LineEnding +
    '' + LineEnding +
    '- **The row along the bottom is one row deep** instead of three.  All of that' + LineEnding +
    '  height is drawing now.' + LineEnding +
    '' + LineEnding +
    '- The collapse arrow says **COLLAPSE** and **EXPAND**, which is what it does.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.13' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The tools stand down the left, with their names on them.**  Screens are' + LineEnding +
    '  wide and short, and two rows of buttons along the bottom were spending the' + LineEnding +
    '  height of your drawing to save width there was plenty of.  A column costs' + LineEnding +
    '  width instead - and reads as a list rather than as a wall.' + LineEnding +
    '' + LineEnding +
    '  Ten tools are on it: select, line, rectangle, circle, arc, push/pull, move,' + LineEnding +
    '  erase, dimension and orbit.  The rest - rotate, offset, follow me, drill,' + LineEnding +
    '  measure, protractor and text - are one click away behind **MORE**, and the' + LineEnding +
    '  shop wizards behind **SHOP**, both on the same strip.  Nothing has been' + LineEnding +
    '  taken away.' + LineEnding +
    '' + LineEnding +
    '  The names show by default, because nobody can tell Offset from Follow Me by' + LineEnding +
    '  pictogram.  **< NAMES OFF** at the foot of the strip puts them away for a' + LineEnding +
    '  wider drawing, and it remembers which you chose.' + LineEnding +
    '' + LineEnding +
    '  The row of buttons along the bottom is a row shorter for it - what is left' + LineEnding +
    '  there is settings and the things that act on the program rather than on the' + LineEnding +
    '  drawing.' + LineEnding +
    '' + LineEnding +
    '- **A plan view is a slice through the model now, not a photograph from' + LineEnding +
    '  above.**  Switch to PLAN and a **CUT** strip appears beside the view' + LineEnding +
    '  button: a bottom and a top, in feet and inches.  Only what is between them' + LineEnding +
    '  is in the drawing - drawn, snapped to, and picked.  A barn whose roof used' + LineEnding +
    '  to cover the whole building cuts to just the walls.' + LineEnding +
    '' + LineEnding +
    '  **Ctrl and the wheel over the drawing travels up and down through the' + LineEnding +
    '  model**, carrying the slice with it, so you can scroll until the plan looks' + LineEnding +
    '  right without taking your eyes off it.  The wheel over either number moves' + LineEnding +
    '  just that end; clicking one lets you type it.  Right-click a floor and' + LineEnding +
    '  **Plan From Here** sets the whole thing in one go.' + LineEnding +
    '' + LineEnding +
    '  The bottom of the slice is also the height you draw at - which is what a' + LineEnding +
    '  floor plan means.  Set it to 9''-0" and you are drawing on the second' + LineEnding +
    '  story.' + LineEnding +
    '' + LineEnding +
    '  It is off until you turn it on, it says how many things it is keeping out' + LineEnding +
    '  so nothing goes missing quietly, and `/cut 0 9''`, `/cut all` and `/cut off`' + LineEnding +
    '  do the same from the command bar.' + LineEnding +
    '' + LineEnding +
    '- **A plan is drawn like a drawing.**  No more shading in PLAN: the light' + LineEnding +
    '  that makes a 3D view read as a solid object was turning two slopes of a' + LineEnding +
    '  roof into two different grays, which in a drawing means nothing at all.' + LineEnding +
    '  Faces fill pale so the lines carry the drawing, which is what lines are' + LineEnding +
    '  for.' + LineEnding +
    '' + LineEnding +
    '- **Type a size into a dimension and the drawing follows.**  Pick a dimension' + LineEnding +
    '  with the select tool, type what it ought to read - `14''`, `12''6`, `6-8-15`' + LineEnding +
    '  - and press Enter.  The end the dimension was drawn to moves out, and' + LineEnding +
    '  everything from that end outwards goes with it, so a rectangle stays a' + LineEnding +
    '  rectangle.  Anything between the two ends stays where you put it.' + LineEnding +
    '' + LineEnding +
    '  `/resize 14'' start` moves the other end instead.' + LineEnding +
    '' + LineEnding +
    '  It is an edit, not a rule that sticks: the drawing moves once and nothing' + LineEnding +
    '  is remembered, so nothing can go stale and nothing can end up fighting' + LineEnding +
    '  anything else.' + LineEnding +
    '' + LineEnding +
    '- **Print it full size, across as many sheets as it takes.**  `/print full`' + LineEnding +
    '  lays the drawing out at 1:1 and prints a page at a time.  Tape the sheets' + LineEnding +
    '  together, put the paper on the metal and scribe round it - which is what a' + LineEnding +
    '  flat pattern was always for.' + LineEnding +
    '' + LineEnding +
    '  Every sheet repeats the last half inch of the next one down its right side' + LineEnding +
    '  and along its bottom.  Trim on the marked line, butt the next sheet against' + LineEnding +
    '  it, and the drawing runs straight through.  The sheet number is printed' + LineEnding +
    '  inside that strip, so it goes in the bin with the trim.' + LineEnding +
    '' + LineEnding +
    '  It tells you how many sheets it will be and asks before it starts.  PLAN is' + LineEnding +
    '  the view to print a pattern from, and it says so if you are in another one.' + LineEnding +
    '' + LineEnding +
    '- **`/tiles <folder>`** writes the same pages as PNG pictures instead of' + LineEnding +
    '  printing them - for sending to a print shop, or for seeing what the paper' + LineEnding +
    '  would look like without using any.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.12.4' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A menu on the right button.**  With the select tool, right-click' + LineEnding +
    '  something in the drawing.  It picks what is under the cursor and offers' + LineEnding +
    '  what can be done to it - and the first thing on that list is **Reverse' + LineEnding +
    '  Face**.' + LineEnding +
    '' + LineEnding +
    '- **Reverse Face** turns a face over, so what was its pale blue back becomes' + LineEnding +
    '  its front.  The program guesses which way a new face should point and the' + LineEnding +
    '  guess is a good one, but two walls back to back are wound the same way and' + LineEnding +
    '  one of them therefore shows its back to whoever is standing outside.' + LineEnding +
    '  Nothing in a drawing of loose faces says which side of a wall is outside,' + LineEnding +
    '  so this is the way to say so.  Several faces selected turns them all over;' + LineEnding +
    '  `/reverse` does it from the command bar.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.12.2' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A corner you point at is the corner you get.**  Drawing on a face, the' + LineEnding +
    '  tool holds every point to that face - which is what drawing on it means.' + LineEnding +
    '  It was holding named points too, so aiming at the top of a rafter twelve' + LineEnding +
    '  feet up gave you the eave underneath it while the reading said ENDPOINT.' + LineEnding +
    '  Endpoints, midpoints, centers, crossings and the origin now beat the held' + LineEnding +
    '  face, the way an axis lock already did.  Everything the program is only' + LineEnding +
    '  guessing at - on an axis, on a face, on the grid - is still held.' + LineEnding +
    '' + LineEnding +
    '- **Both halves of a roof face the sky.**  A roof built as two slopes off a' + LineEnding +
    '  ridge came out with one slope gray and the other pale blue, because pale' + LineEnding +
    '  blue is the back of a face and one of them really was inside out.  Areas' + LineEnding +
    '  the program fills in for you are now turned the same way up as ones you' + LineEnding +
    '  draw yourself.' + LineEnding +
    '' + LineEnding +
    '  Two upright faces back to back - the two ends of a barn - can still show' + LineEnding +
    '  one of each.  There is no way to tell the outside of a loose wall from the' + LineEnding +
    '  inside without a solid around it - which is what Reverse Face is for.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.12.1' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A bug report now carries the session that caused it.**  Alongside the' + LineEnding +
    '  drawing, a report holds what you did to it - the tool you picked, the points' + LineEnding +
    '  you clicked, the lengths you typed - written so the program can read it back.' + LineEnding +
    '  Open the drawing, type `/replay report.txt`, and it happens again in front' + LineEnding +
    '  of you instead of being described.' + LineEnding +
    '' + LineEnding +
    '  It records only what this window was given.  There is no system-wide hook,' + LineEnding +
    '  it cannot see another program, and nothing typed anywhere else can reach it.' + LineEnding +
    '  Points are kept as real coordinates rather than pixels, so a session' + LineEnding +
    '  recorded on one screen replays on any other.' + LineEnding +
    '' + LineEnding +
    '- **`/session [file]`** writes what has been recorded so far to a file,' + LineEnding +
    '  without filing a report - for keeping a sequence you want to run again.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.12' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Lines drawn in mid air no longer disappear behind solids.**  Drawing the' + LineEnding +
    '  ridge of a roof, or any line that does not lie flat on a face, showed the' + LineEnding +
    '  parts of it over empty background and swallowed the parts crossing anything' + LineEnding +
    '  solid.  The line was being painted before the faces and only put back if it' + LineEnding +
    '  lay in the plane of one.  Lines are now tested against the depth of the' + LineEnding +
    '  solids per pixel, so a line in front of something shows and a line behind it' + LineEnding +
    '  is properly hidden.' + LineEnding +
    '' + LineEnding +
    '- **Drawing straight up off a face works again.**  Starting a line on a face' + LineEnding +
    '  and running it up the blue axis said LOCKED TO BLUE and then drew nothing -' + LineEnding +
    '  the point was being pulled back down onto the face as fast as the axis took' + LineEnding +
    '  it up, so the line had no length.  Picking the tool again was the only way' + LineEnding +
    '  out.  Running up an axis now leaves the face, which is what standing a gable' + LineEnding +
    '  up means.' + LineEnding +
    '' + LineEnding +
    '- **Bug report pictures show the mouse pointer.**  An arrow and a red ring are' + LineEnding +
    '  drawn where the cursor was, so a report about what was under the mouse can' + LineEnding +
    '  be read without guessing.' + LineEnding +
    '' + LineEnding +
    '### Better' + LineEnding +
    '' + LineEnding +
    '- **A wrong row stride can no longer wander into a wild pointer.**  Nine times' + LineEnding +
    '  in one session a drawing surface was found holding a stride that was really' + LineEnding +
    '  a floating point number - already caught and repaired, but caught after the' + LineEnding +
    '  fact.  The arithmetic that turns a row into an address now refuses a stride' + LineEnding +
    '  that could not be one, and a decoy field sits where the stray write keeps' + LineEnding +
    '  landing so the next report says plainly what is doing it.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.10.2' + LineEnding +
    '' + LineEnding +
    '### Faster' + LineEnding +
    '' + LineEnding +
    '- **Hover on a big drawing.**  Finding the snap point under the cursor' + LineEnding +
    '  used to project every snap point on the drawing to the screen on every' + LineEnding +
    '  mouse move - a hundred and twenty thousand of them on a fifty-thousand' + LineEnding +
    '  thing drawing, every time the mouse twitched.  The projected positions' + LineEnding +
    '  are kept now and reused while the camera is still, with a box round the' + LineEnding +
    '  cursor throwing out the far ones before the distance is worked out, so' + LineEnding +
    '  a hover while placing a point costs almost nothing after the first move.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.10.1' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A footing of concentric rings works right again with `/rebuildfaces`.**' + LineEnding +
    '  A drawing saved by an older build could hold its faces the wrong way -' + LineEnding +
    '  four concentric rectangles kept as four solid faces stacked on each' + LineEnding +
    '  other rather than three rings and a middle - and the ordinary rebuild' + LineEnding +
    '  keeps a drawing''s faces on purpose, so it did not repair them.  The new' + LineEnding +
    '  `/rebuildfaces` command throws every face away and works them all out' + LineEnding +
    '  fresh from the lines: the rings come back, each its own face to push,' + LineEnding +
    '  pull or delete.  It is for flat work and has undo.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.10' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Closing a sheet asks first.**  A sheet with anything on it now puts up' + LineEnding +
    '  a question when you close it: save the drawing, close without saving, or' + LineEnding +
    '  keep it open.  Close without saving discards it; keep it open leaves it.' + LineEnding +
    '  Nothing is thrown away silently.' + LineEnding +
    '- **The header says when a drawing has unsaved changes.**  A named drawing' + LineEnding +
    '  that has been edited since it was last written shows "unsaved changes' + LineEnding +
    '  (Ctrl+S)" next to its path.' + LineEnding +
    '- **Two new sheets no longer share a name.**  A drawing whose sheets were' + LineEnding +
    '  named out of order could get two "Sheet 2"s; a new sheet takes the' + LineEnding +
    '  lowest free number now.' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- `/saveas` from the command bar, and the save button''s tip mentions' + LineEnding +
    '  Shift+Ctrl+S for save-as.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.09.4' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **Beads and cross breaks look like the metal.**  A rolled bead is a' + LineEnding +
    '  ridge now, three quarters wide and standing a fat eighth proud, built' + LineEnding +
    '  in three facets so it shades the way rolled metal does, with its edges' + LineEnding +
    '  drawn along it and its profile at each end; it stops an inch short of' + LineEnding +
    '  the seams where the roll stops.  A cross break is the same ridge made' + LineEnding +
    '  shallower and narrower, the crease of the brake, stopping short of the' + LineEnding +
    '  corners.  They were single lines before.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.09.3' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Gauge and stiffening on the fitting builder.**  A Metal row: the' + LineEnding +
    '  gauge, left as "as needed" for what the size calls for - 26 to 12",' + LineEnding +
    '  24 to 30", 22 to 54", 20 to 84", 18 beyond, the usual low-pressure' + LineEnding +
    '  table - or picked outright, and how the big panels are stiffened: as' + LineEnding +
    '  needed, none, cross breaks, or beads every foot.  As needed means a' + LineEnding +
    '  panel over 18" wide and a foot long gets a cross break up to a yard' + LineEnding +
    '  long and beads beyond that.  The breaks and beads are drawn on the' + LineEnding +
    '  walls in a lighter line, the builder says what it chose under the row,' + LineEnding +
    '  and the ticket carries a Metal line naming the gauge and which walls' + LineEnding +
    '  are broken or beaded.  The thresholds are the common ones; a shop that' + LineEnding +
    '  runs lighter or heavier picks its own.' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **Two menus cleaned up.**  The VIEW menu no longer offers the plan and' + LineEnding +
    '  iso paper modes - this is a 3D model, and a flat layout tool is for' + LineEnding +
    '  another day - and the SHOP menu loses "Field sketch, on iso paper",' + LineEnding +
    '  which the Fitter''s scratchpad replaced.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.09.2' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Orbiting when zoomed in.**  With the cursor on paper rather than on a' + LineEnding +
    '  face, the view turned about the middle of the whole drawing - a point a' + LineEnding +
    '  hundred feet away when you are zoomed in on one fitting - and the' + LineEnding +
    '  fitting swung straight out of the view.  The pivot is now the nearest' + LineEnding +
    '  drawn thing to the cursor on screen, from the last frame''s depth buffer,' + LineEnding +
    '  then whatever is selected, and only then the drawing''s middle.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.09.1' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The tape wizard does a vertical run off a furnace.**  A button on the' + LineEnding +
    '  wizard switches between the hallway and a furnace room: the furnace on' + LineEnding +
    '  the floor against a brick wall, its collar on top as the entry, the' + LineEnding +
    '  trunk above with the opening the transition rises to as the exit, and' + LineEnding +
    '  the transition dashed between.  Two views: from the side for front to' + LineEnding +
    '  back, taped from the wall behind the furnace, and from the front for' + LineEnding +
    '  left to right, taped from a wall beside it.  The same four readings, the' + LineEnding +
    '  same shop words - the furnace laid on its back, so the builder''s top is' + LineEnding +
    '  the duct''s front and its bottom the back - and the ticket says so.' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- The duct in the hallway is galvanized gray now.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.09' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **The tape wizard''s pictures are a hallway.**  Both tape pages are one' + LineEnding +
    '  cartoon: a hallway seen from the entry end, a smooth ceiling with a' + LineEnding +
    '  light, a tile floor, brick walls either side, and the duct hanging a' + LineEnding +
    '  foot below the ceiling the way it would on the job, its exit end' + LineEnding +
    '  further down the hall and offset the way the readings say.  The tape' + LineEnding +
    '  lines run from the floor or the ceiling, or from a wall, to the edge' + LineEnding +
    '  each reading was taken to, with the reading on the line.  The exit' + LineEnding +
    '  shows dashed through the entry so the offset and the smaller size read.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.08.9' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **The tape readings are a wizard now.**  The builder''s form is back to' + LineEnding +
    '  the way the shop says a transition - centered, left side in by, bottom' + LineEnding +
    '  up by - and a button beside the length, *From the tape...*, opens three' + LineEnding +
    '  pictures: the duct against the floor or the ceiling with a figure' + LineEnding +
    '  holding the tape, the duct against a wall seen from above, and what it' + LineEnding +
    '  comes to.  A box sits on each tape line for the reading and a word' + LineEnding +
    '  under it for the edge the tape landed on; the reference flips with one' + LineEnding +
    '  button, and the picture follows.  *Use these* puts the offsets into the' + LineEnding +
    '  form in shop words, and the readings go on the ticket.  The tick box,' + LineEnding +
    '  the readings panel and the Tape tab from the last two releases are gone.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.08.8' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The tape can land on either edge.**  Each tape reading now says' + LineEnding +
    '  which edge it was taken to - the bottom or the top from the floor or' + LineEnding +
    '  ceiling, the left or the right side from the wall - so a duct measured' + LineEnding +
    '  to its bottom at one end and the equipment measured to its top at the' + LineEnding +
    '  other still gives the true offset.  A **Tape** tab in the builder shows' + LineEnding +
    '  where the tape went: the duct against the floor or ceiling above, and' + LineEnding +
    '  against the wall below, with a dimension line from the reference to the' + LineEnding +
    '  edge each reading landed on.  Change the edge and the line jumps.  The' + LineEnding +
    '  ticket says which edge each reading was to.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.08.7' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **The taped transition''s plan shows the result, not the tape.**  The' + LineEnding +
    '  wall and the two readings to it are gone from the plan; the wall was only' + LineEnding +
    '  where the tape was hooked.  What shows is the offset it comes to - right' + LineEnding +
    '  side in by 7, bottom up by 4 - the same as a transition entered the' + LineEnding +
    '  usual way.  The readings still print on the ticket.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.08.6' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **The notch is cut the way the snips cut it.**  The point is on the' + LineEnding +
    '  seam, the notch depth back from the end; the cut comes into it from' + LineEnding +
    '  about three quarters of that out along the opening edge.  The last' + LineEnding +
    '  release had the triangle the other way round.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.08.5' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Notches are cut on the angle.**  A notched or slip-and-drive end used' + LineEnding +
    '  to step in square at each corner.  The cut now runs from the notch depth' + LineEnding +
    '  along the opening edge back on the angle to an eighth of an inch from' + LineEnding +
    '  the corner along the seam, which is how the corner is actually cut, and' + LineEnding +
    '  leaves the tab a sharper corner.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.08.4' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A fitting comes in its crate.**  The builder''s 3D tab, and the ghost' + LineEnding +
    '  while a built fitting is being placed, draw the box the fitting fits in:' + LineEnding +
    '  the floor marked, IN at the entry end, OUT at the exit, TOP on the lid.' + LineEnding +
    '  A strange transition orbited or seen from below then still says which' + LineEnding +
    '  way is up and which end goes first.  The crate is drawn, not built -' + LineEnding +
    '  nothing of it goes into the drawing, so there is nothing to delete.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.08.3' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Flex connectors on a transition.**  Either end can carry a canvas' + LineEnding +
    '  flex connector - the Junior, 1 3/4-3-1 3/4; the 3-3-3; the 3-6-3 - with' + LineEnding +
    '  the end''s finish on the flex''s far strip, since that strip is what gets' + LineEnding +
    '  notched for an S-lock, bent for a drive or for a TDF flange.  The' + LineEnding +
    '  fabric is drawn squashed to half, the way it goes in, and the' + LineEnding +
    '  sheet-metal body is that much shorter: the length typed is the whole' + LineEnding +
    '  thing.  The ticket names the flex, what it takes out of the length, and' + LineEnding +
    '  the metal left flex to flex.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.08.2' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A transition taped from the floor and a wall.**  A tick on the' + LineEnding +
    '  builder swaps the side and height rules for four tape readings: from the' + LineEnding +
    '  floor to the bottom of the opening or from the ceiling to the top, and' + LineEnding +
    '  from the left wall to the left side or the right wall to the right side,' + LineEnding +
    '  one reading at each end, the entry usually 0.  The rules come out as' + LineEnding +
    '  differences - entry tight to the ceiling and the exit 4" down is top' + LineEnding +
    '  down by 4 - so nobody does the arithmetic in the field.  The plan shows' + LineEnding +
    '  the wall the tape was hooked on with both readings, and the ticket' + LineEnding +
    '  prints the readings under the rules.  An exit that runs past the wall' + LineEnding +
    '  or ceiling reads negative and prints as "out by".  Untick it and the' + LineEnding +
    '  builder is exactly as before.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- The builder''s plan said "bottom down" for a top-down or bottom-up rule.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.08.1' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **The fitting builder remembers the last fitting.**  It opens the way' + LineEnding +
    '  it was when the last one was built - sizes, rules, ends, angle, branch,' + LineEnding +
    '  all of it - since one fitting is usually much like the one before.  Only' + LineEnding +
    '  the tag starts blank.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.08' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Touch on Linux.**  The drawing now takes fingers from a touchscreen:' + LineEnding +
    '  a tap is a click, a finger dragged is the mouse, two fingers pan, and a' + LineEnding +
    '  pinch zooms about the point between them.  The toolkit was being given' + LineEnding +
    '  the touch events and throwing them away, which is why the drawing got' + LineEnding +
    '  nothing while the buttons and the window frame worked.  `/touch` says' + LineEnding +
    '  whether the hook is in.  Windows is unchanged for now: it turns a finger' + LineEnding +
    '  into a mouse by itself.  What comes next for touch, tablets and the' + LineEnding +
    '  remote desktop is written down in `docs/touch.md`.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.22' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **The report form takes the picture first.**  No question before the' + LineEnding +
    '  form: it opens with a picture of the window as it was, in view while' + LineEnding +
    '  you write.  On the form, `Snap now` takes it again with the form out of' + LineEnding +
    '  the way, `Snap in 10 s` gives time to set something up to show and' + LineEnding +
    '  brings the form straight back, and `Discard picture` sends the report' + LineEnding +
    '  without one.  Enter while writing no longer sends the report - one' + LineEnding +
    '  arrived cut off in the middle of a word that way.  `/report` opens the' + LineEnding +
    '  form from the command bar.' + LineEnding +
    '- **`/sysinfo` shows its facts in a box** in the program''s own style,' + LineEnding +
    '  instead of squeezing them into the command bar.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.21' + LineEnding +
    '' + LineEnding +
    '### Changed' + LineEnding +
    '' + LineEnding +
    '- **Everything stays with the program.**  The fitting and spool tickets' + LineEnding +
    '  used to be written under the user''s home folder; they go beside the' + LineEnding +
    '  program now, in a `fittings` folder next to the settings and the draft,' + LineEnding +
    '  so a copy on a USB stick leaves nothing behind.  And every bug report' + LineEnding +
    '  sent is kept there too, text and picture under the name it was sent as,' + LineEnding +
    '  in `reports-sent`.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.20' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Dimensions showing through a duct.**  A dimension lying in the plane' + LineEnding +
    '  of a face was put back whole once its middle was in the clear, so the' + LineEnding +
    '  parts of it behind the walls showed through them.  A dimension is drawn' + LineEnding +
    '  like a line now: only the stretches of its three lines that nothing' + LineEnding +
    '  stands in front of, and its ticks and figure only where their place is' + LineEnding +
    '  clear.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.19' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A crash after switching sheets.**  The selection was kept across a' + LineEnding +
    '  tab switch, still pointing at the things on the sheet just left, and a' + LineEnding +
    '  move on the new sheet then read past its end.  Switching, adding or' + LineEnding +
    '  closing a sheet now lets go of the selection and the hover, and a move' + LineEnding +
    '  drops anything selected that is not on the sheet.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.18' + LineEnding +
    '' + LineEnding +
    '### Faster' + LineEnding +
    '' + LineEnding +
    '- **Moving, selecting and deleting on a big drawing.**  Measured on fifty' + LineEnding +
    '  thousand things - 2,500 boxes with a line across two faces of each -' + LineEnding +
    '  everything selected: a move took 65 seconds to work the faces out' + LineEnding +
    '  afterwards; it takes 1.5 now.  Deleting the selection took a minute; it' + LineEnding +
    '  is instant.  Hovering with everything selected redrew fifty thousand' + LineEnding +
    '  outlines through the canvas on every mouse move, 117 ms a frame; the' + LineEnding +
    '  outlines are drawn once into a layer now, 23 ms.  Select-all and box' + LineEnding +
    '  select no longer walk the whole selection for every thing they add.' + LineEnding +
    '  The things fixed underneath: old faces were deleted one at a time, each' + LineEnding +
    '  shifting everything after it; every region asked every old face and' + LineEnding +
    '  every seen area instead of the ones in its own plane; the pass that' + LineEnding +
    '  divides a solid''s face asked every region on the plane instead of the' + LineEnding +
    '  ones inside the face; and the busy bar was repainting the whole window' + LineEnding +
    '  every few dozen regions, which was thirty of those seconds by itself.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.17' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Reports say what machine they came from.**  A bug report, and the' + LineEnding +
    '  crash file, now carry the operating system, the processor and how many' + LineEnding +
    '  cores, the RAM and how much of it is free, the graphics driver and' + LineEnding +
    '  whether an OpenGL library is there, the display size, the toolkit the' + LineEnding +
    '  program was built with, and how much memory the program itself is' + LineEnding +
    '  using.  Nothing about the person: no name, no path, no serial number,' + LineEnding +
    '  nothing that needs asking for, and no other program is run to find it' + LineEnding +
    '  out.  `/sysinfo` shows exactly what would be sent.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.16' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **A start-up screen.**  The program now puts up a card the moment it' + LineEnding +
    '  starts, with the version on it, and says what it is doing while a' + LineEnding +
    '  drawing comes in - reading it, sorting the lines by plane, finding the' + LineEnding +
    '  flat areas, working out the faces - with a progress bar.  A drawing that' + LineEnding +
    '  is taking too long can be skipped with the button on the card; the file' + LineEnding +
    '  is left untouched, and a skipped draft is kept beside the settings as' + LineEnding +
    '  `heckers-sketch-draft-skipped.hsk`.  The card stays up four seconds even' + LineEnding +
    '  when there was nothing to wait for, so it never just flashes.' + LineEnding +
    '- **A progress bar on the command bar.**  Long work on a big drawing -' + LineEnding +
    '  the faces being worked out after a move, say - now shows what it is' + LineEnding +
    '  doing and how far along it is, in place of the prompt, instead of the' + LineEnding +
    '  program looking hung.  Clicks and keys wait until it is done.' + LineEnding +
    '' + LineEnding +
    '### Faster' + LineEnding +
    '' + LineEnding +
    '- **Opening a big drawing.**  Sorting the lines by plane looked every end' + LineEnding +
    '  up against every other end, and every plane against every plane.  On a' + LineEnding +
    '  drawing of two hundred thousand things that was sixteen of the twenty' + LineEnding +
    '  seconds it took to open; it is well under a second now.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.15' + LineEnding +
    '' + LineEnding +
    '### Under the hood' + LineEnding +
    '' + LineEnding +
    '- **The worker''s result is taken as soon as it is done.**  A result' + LineEnding +
    '  queued back to the main thread was only delivered when the program was' + LineEnding +
    '  idle, and a program painting frame after frame never was: on a drawing' + LineEnding +
    '  of fifty thousand things a cache that took a second to build waited' + LineEnding +
    '  nearly three more before it was used.  The renderer now looks at the' + LineEnding +
    '  queue itself.  `/rendertime` also says how long the last cache build' + LineEnding +
    '  took and where it ran, how long its result waited, and what a frame' + LineEnding +
    '  without the cache spent on lines-on-faces.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.14' + LineEnding +
    '' + LineEnding +
    '### Under the hood' + LineEnding +
    '' + LineEnding +
    '- **The first worker thread.**  Working out which lines lie on which' + LineEnding +
    '  faces - a cache the renderer keeps - is now done off the main thread on' + LineEnding +
    '  a big drawing, from a copy of the drawing.  While it is being built the' + LineEnding +
    '  renderer searches every face as it did before, so nothing waits on it' + LineEnding +
    '  and nothing is wrong if it is late.  `/threads` turns the workers off,' + LineEnding +
    '  and `/rendertime` says how long the worker took and how many frames went' + LineEnding +
    '  without the cache.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.13' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **A crash while moving on a big drawing.**  Working the faces out after' + LineEnding +
    '  a move could read the wrong entity once a face had been divided, and on' + LineEnding +
    '  a drawing of thousands of things that was an access violation.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.12' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Selecting everything on a huge drawing no longer stalls every mouse' + LineEnding +
    '  move.**  Past a few thousand selected things the highlight is drawn' + LineEnding +
    '  plainly, edges only.  On a drawing of thirty thousand things with all of' + LineEnding +
    '  it selected, each repaint went from over half a second to a twenty-fifth.' + LineEnding +
    '- **What is off the screen is not drawn.**  Zoomed in on a corner of a big' + LineEnding +
    '  drawing, the faces and edges outside the window are skipped before any' + LineEnding +
    '  work is done on them.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.11' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Quicker frames while you orbit, pan or zoom.**  While the camera is' + LineEnding +
    '  moving the drawing is redrawn a cheaper way - the hidden-line work is' + LineEnding +
    '  sampled coarser and the faces are filled without anti-aliasing - and the' + LineEnding +
    '  full-quality frame is drawn the moment you let go, or a fifth of a second' + LineEnding +
    '  after the wheel stops.  The picture stays complete while it moves, just' + LineEnding +
    '  a touch rougher at the ends of hidden lines.  A big drawing orbits in' + LineEnding +
    '  about half the time.  If you would rather every frame were the full one,' + LineEnding +
    '  `/quick` turns it off and on.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.10' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Big drawings orbit faster again.**  Which faces each edge lies on is' + LineEnding +
    '  now worked out once when the drawing changes rather than for every frame,' + LineEnding +
    '  and a copy of every face the renderer made each frame and never used is' + LineEnding +
    '  gone.  On ten spools - five thousand faces - the edge pass halved.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.9' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Placing a built fitting or spool ends there.**  After the placing click' + LineEnding +
    '  the part was left selected under the move tool, so the next click picked' + LineEnding +
    '  it up again, which read as the click not having placed it.  It is let go' + LineEnding +
    '  of now and the select tool comes back.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.8' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Scratchpad: click, type, click.**  Type a leg''s length and the click' + LineEnding +
    '  that starts the next leg takes it - no Enter between legs, so a hand can' + LineEnding +
    '  stay on the number pad and work down the run.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.7' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **No more black ring on a ball or a donut.**  The circle a Follow Me was' + LineEnding +
    '  made from - the profile, or the circle followed round - stayed drawn as' + LineEnding +
    '  a hard line across the surface.  It becomes a seam of the surface now,' + LineEnding +
    '  soft and hidden like the seams between gores.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.6' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Moving a big fitting is quick again.**  The move itself asked every' + LineEnding +
    '  corner in the drawing whether it was one of the moving ones, one at a' + LineEnding +
    '  time, and working the faces out afterwards compared every area against' + LineEnding +
    '  every face twice over.  Both now look things up instead of walking for' + LineEnding +
    '  them.  Moving a whole spool went from a third of a second to a sixteenth.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.5' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Selecting and moving a big fitting no longer freezes the program.**' + LineEnding +
    '  Two things were wrong.  Taking everything joined to a click grew the' + LineEnding +
    '  selection a pass at a time, testing everything against everything, which' + LineEnding +
    '  on a spool of sixteen hundred pieces took the program away for a minute.' + LineEnding +
    '  And painting the selection asked "is this point hidden" by walking every' + LineEnding +
    '  face, a hundred times per selected piece per frame.  The first is a' + LineEnding +
    '  proper flood now; the second reads the depth the renderer already worked' + LineEnding +
    '  out.  A whole spool selects in a blink and its highlight paints in a' + LineEnding +
    '  fortieth of a second.' + LineEnding +
    '- `/all` selects everything on the sheet.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.4' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Built fittings stay hollow whatever you do to them.**  Moving, turning' + LineEnding +
    '  or copying a fitting after placing it capped its open ends - the program' + LineEnding +
    '  worked the flat areas out again and took the ends for newly closed' + LineEnding +
    '  areas.  An opening edged entirely by a solid''s own edges is now never' + LineEnding +
    '  given a face: a duct end, a pipe end, a hole rubbed out of a box.  Ends' + LineEnding +
    '  already capped in a drawing are ordinary faces; the eraser takes them.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.3' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Orbiting is three times faster on big drawings.**  The faces were' + LineEnding +
    '  being sorted by a method whose cost grows with the square of their' + LineEnding +
    '  number, and the edge index was kept in a sorted list that shuffled' + LineEnding +
    '  memory on every insert.  Both replaced.  A four-leg spool of 528 faces' + LineEnding +
    '  now draws in 8 milliseconds a frame in the ordinary build, from 29 at' + LineEnding +
    '  the start of the day.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.2' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Reducers and flanged joints** in the fitter''s scratchpad.  Under the' + LineEnding +
    '  measurement, say what sits at the far end of a leg: nothing, a reducer to' + LineEnding +
    '  another size, or a flanged joint.  The legs after a reducer are the new' + LineEnding +
    '  size, the cut lengths lose the fitting, the 3D shows the step down or the' + LineEnding +
    '  pair of flanges, and the ticket lists them with the reducer''s length.' + LineEnding +
    '- The scratchpad''s paper is dots again, with lined paper as the other' + LineEnding +
    '  choice, and the leg the cursor is about to make shows plainly on both.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- The deck''s tool buttons ran over the icons on the right once Follow Me' + LineEnding +
    '  joined them.  They share the width properly now.' + LineEnding +
    '- Orbiting a drawing full of pipe: two passes of the renderer did far more' + LineEnding +
    '  work than they needed - building the edge index, and testing every line' + LineEnding +
    '  against every face with a fresh normal each time.  A four-leg spool went' + LineEnding +
    '  from 29 to 21 milliseconds a frame in the ordinary build.  The checked' + LineEnding +
    '  build is slower by nature; see the notes on it below.' + LineEnding +
    '- The report picture taken "now" waited for nothing and caught the' + LineEnding +
    '  question box still on screen.  It gives the box a moment to go.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07.1' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The fitter''s scratchpad** is what the pipe spool wizard is called now,' + LineEnding +
    '  and it works the way a tape does.  Each leg says what its length was' + LineEnding +
    '  measured between: center to center, end to center, center to end, or' + LineEnding +
    '  end to end - an end being the pipe end, the flange face, or the weld at' + LineEnding +
    '  an elbow.  The ticket turns that into center-to-center and cut lengths' + LineEnding +
    '  with the elbows'' take-outs already off.  A leg can be drawn without a' + LineEnding +
    '  length and given one later by clicking it, and a sketch with lengths' + LineEnding +
    '  still to come can be emailed as it stands; the 3D view and Build it wait' + LineEnding +
    '  until every leg has its number.  The paper is ruled like iso paper, with' + LineEnding +
    '  dots as the other choice.' + LineEnding +
    '- Center, not center: the wizards'' words are American now.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Pipe spool.**  SHOP > Pipe spool..., or /spool: the pipe fitter''s iso' + LineEnding +
    '  as a form.  Iso paper you click the run onto, one leg at a time - each' + LineEnding +
    '  leg snaps to the three axes, or with Shift to a 45 - and type the' + LineEnding +
    '  center-to-center length on.  Pick the pipe size, long or short radius' + LineEnding +
    '  elbows, and what each end is: bevelled, a weld-neck flange, a cap, or' + LineEnding +
    '  threaded.  The ticket writes itself underneath with every leg''s cut' + LineEnding +
    '  length, the elbows'' take-outs already off, and the 3D tab shows the' + LineEnding +
    '  spool built from the same numbers.  Email it to the shop, or Build it' + LineEnding +
    '  into the drawing with the lengths on it.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.30' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Follow Me follows a path.**  Click the face, then click a line or an' + LineEnding +
    '  arc: the face is pushed along every edge joined to it, end to end, and' + LineEnding +
    '  mitred at each corner - a square along an L is an L of square tube, a' + LineEnding +
    '  circle along a line with a 90 arc in it is a round elbow with straight' + LineEnding +
    '  legs, a circle round a rectangle of lines is a rectangular ring of pipe.' + LineEnding +
    '  Or select the path first and then click the face, SketchUp''s own way.  A' + LineEnding +
    '  closed path has no caps; an open one keeps the profile as one cap and' + LineEnding +
    '  adds the other.  A whole circle clicked as the path still spins the face' + LineEnding +
    '  round its center.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.29' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Follow Me.**  A new tool with the drawing tools: spin a face round an' + LineEnding +
    '  axis into a solid.  Click the face, then two points on the axis - or' + LineEnding +
    '  click a circle to follow round, the way SketchUp does it.  Type an angle' + LineEnding +
    '  first, 90 or 180, for a part turn; a plain click goes all the way round.' + LineEnding +
    '  A half circle spun on its diameter is a ball; a rectangle spun beside an' + LineEnding +
    '  axis is a tube; a profile spun on its edge is a cone, a cap, a round' + LineEnding +
    '  reducer.  The gores follow the circle side count, so `24s` gives a' + LineEnding +
    '  24-gore turn.  Following a path of lines and arcs - round elbows and' + LineEnding +
    '  spools - is the next half of this tool.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.28' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Circles have points to aim at.**  The four quadrant points of a circle' + LineEnding +
    '  - where it crosses its own plane''s axes - snap, marked QUADRANT.  Where' + LineEnding +
    '  two arcs cross, in one plane or on two different planes, the crossing' + LineEnding +
    '  snaps, and the pieces either side of it get middles, as cut lines do.  An' + LineEnding +
    '  arc nothing crosses has a middle.  Building a ball or a pipe crossing out' + LineEnding +
    '  of circles now has something to land on.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.27' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Footings: nested rings are their own faces.**  Offset a rectangle' + LineEnding +
    '  twice and the outer ring was cut out all the way to the middle and the' + LineEnding +
    '  eraser took two faces for one.  A loop inside a loop is now a hole in the' + LineEnding +
    '  nearest ring only, so each ring is its own face and erases on its own.' + LineEnding +
    '  Drawings made before this need `/rebuild` (or any edit) to be worked out' + LineEnding +
    '  again.' + LineEnding +
    '- The eraser''s tip now says it sweeps: hold the button and drag across' + LineEnding +
    '  several things to take them all at once, the way SketchUp''s does.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.26' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- `/select` and `/move` in the command bar, alongside the other tools.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- **Offset lands on the guide.**  With the cursor snapped to a guide, a' + LineEnding +
    '  guide point, a corner or an edge, the offset is now measured to that' + LineEnding +
    '  point exactly.  It used to take where the mouse was and round it to the' + LineEnding +
    '  snap step, so a guide 8" in could give an offset of 9".  Put a guide where' + LineEnding +
    '  the footing edge goes and the offset goes there.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.25' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- The outside of an elbow, a tee''s walls, and some transition sides were' + LineEnding +
    '  painted in the inside color.  The builder wound those faces the wrong' + LineEnding +
    '  way round; every face a fitting is built from now faces out.  Fittings' + LineEnding +
    '  already in a drawing keep the winding they were built with - build them' + LineEnding +
    '  again to get the new one.' + LineEnding +
    '- A flange or a drive edge on a slanted side now lies in the plane of the' + LineEnding +
    '  end, the way the cleat goes on, rather than square to the wall.' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- `/rendertime` in the command bar times ten frames and says how long one' + LineEnding +
    '  takes, for chasing a slow orbit.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.24' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Reducing elbows.**  An elbow can be given an exit opening of a' + LineEnding +
    '  different size.  The size across the turn changes through the turn, the' + LineEnding +
    '  heel spiralling in; the other size changes in the exit leg, which is' + LineEnding +
    '  straight metal, so the exit leg needs a length when it does.  Blank exit' + LineEnding +
    '  sizes keep the entry size.' + LineEnding +
    '- **An elbow from field measurements.**  On the elbow page, "From field' + LineEnding +
    '  measurements..." takes what can be measured on the job: from the inside' + LineEnding +
    '  corner of the open end, straight ahead and across to the near inside' + LineEnding +
    '  corner of the duct it has to meet, and either the angle that duct runs' + LineEnding +
    '  at or a second point along its inside edge.  With the throat radius' + LineEnding +
    '  chosen it works out the angle and both legs so the elbow lands there,' + LineEnding +
    '  shows it, and puts the numbers into the elbow''s fields.' + LineEnding +
    '- **A tee''s branch centers itself.**  Leave "starts, from the entry" blank' + LineEnding +
    '  and the branch sits in the middle of the run, the way a blank height' + LineEnding +
    '  already centers it on the wall.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- A drawing that was nothing but built fittings came back from a save or' + LineEnding +
    '  a restart with every open end capped on the next edit.  The program took' + LineEnding +
    '  a drawing whose faces all belong to solids for an old file with no faces' + LineEnding +
    '  and worked its areas out again.  It now knows a solid''s faces are faces.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.22' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Elbows and tees.**  The fitting wizard - Build a fitting... under SHOP,' + LineEnding +
    '  or /elbow, /tee, /transition - has radio buttons at the top for a' + LineEnding +
    '  transition, an elbow or a tee.  An elbow takes its opening, the angle' + LineEnding +
    '  (22.5, 45, 90, or any other), which way it turns seen from the entry,' + LineEnding +
    '  the throat radius (0 for a square throat), a square or rolled heel, and' + LineEnding +
    '  the straight legs at each end; it is built gore by gore.  A tee takes the' + LineEnding +
    '  run, the branch opening, which wall it comes off, where it starts, and' + LineEnding +
    '  the branch length, and cuts the opening out of the wall.  Ends, the tag,' + LineEnding +
    '  the dimensions, the plan and 3D views, the email and the files all work' + LineEnding +
    '  the same for every kind.' + LineEnding +
    '- **Show the files.**  The same pictures and ticket, written and shown in' + LineEnding +
    '  the file manager with the plan picked out, for when they go somewhere' + LineEnding +
    '  other than an email.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.19' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Email the ticket from the builder.**  An "Email it..." button in the' + LineEnding +
    '  transition wizard opens a new message in your mail program with the plan,' + LineEnding +
    '  the corner view and every input as words, attached and ready to send to' + LineEnding +
    '  the office.  The files are also kept under Heckers Sketch/fittings in your' + LineEnding +
    '  home folder.  Nothing is sent by the program itself.' + LineEnding +
    '- **A tag on the fitting.**  Name it on the ticket - T-3, kitchen supply -' + LineEnding +
    '  and the name is written on the part when it drops into the drawing, on' + LineEnding +
    '  both pictures, and in the email subject.' + LineEnding +
    '- **Plan and 3D on tabs.**  The wizard''s two views sit on tabs, so the form' + LineEnding +
    '  takes less room and either can be watched while the numbers go in.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.18' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **The transition wizard finishes the ends.**  Each end can be raw, notched' + LineEnding +
    '  all round for a field slip, flange out, flange in, TDF flange, slip and' + LineEnding +
    '  drive, or drive and slip, each with its size, and the fitting is built' + LineEnding +
    '  with them - notches cut, flanges and drives bent out, the TDF fold back -' + LineEnding +
    '  so the 3D part shows the connection.' + LineEnding +
    '- **Height has all four moves.**  Top up by, top down by, bottom up by and' + LineEnding +
    '  bottom down by, for whichever edge could be measured in the space.' + LineEnding +
    '- **The sizes go on.**  A built fitting carries its dimensions: both' + LineEnding +
    '  openings and the run.  A tick box in the wizard turns that off.' + LineEnding +
    '- **A corner view in the wizard.**  Beside the plan sketch, the fitting as' + LineEnding +
    '  it will be built, ends and all, from in front of the entry.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- Moving or turning a dimension along with other things sent its line off' + LineEnding +
    '  by the whole distance moved.  The dimension''s offset now travels as a' + LineEnding +
    '  direction, and the line stays put against what it measures.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.17' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- A **Report a problem** button inside the transition wizard.  The picture' + LineEnding +
    '  is the whole screen with the wizard in it, and what was typed into the' + LineEnding +
    '  wizard goes into the report.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- A built transition is hollow again.  Placing it was capping both ends.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.16' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- The move tool taken to a dimension''s line repositions the line - further' + LineEnding +
    '  out, the other side, or standing up on another plane - while the two points' + LineEnding +
    '  it measures stay put.  The eraser takes a dimension by its line or its' + LineEnding +
    '  witness lines.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- With nothing selected, rotate now takes everything joined to what you' + LineEnding +
    '  click, so turning a box turns the box instead of twisting it.  To turn a' + LineEnding +
    '  part on its own, select it first: one click for one thing, a double click' + LineEnding +
    '  for a face and its edges, a triple click for all that is joined.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.14' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- Copy arrays, SketchUp''s way.  Ctrl-move something to leave a copy, then' + LineEnding +
    '  type 3x (or x3, *3) for three copies that far apart, or /3 to divide the' + LineEnding +
    '  run into three.  The same after a Ctrl-rotate: 6x for six round the' + LineEnding +
    '  circle, /6 to divide the turn.  Typing another count replaces the last.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.13' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- The view button has a drop-down arrow: click the name to step through the' + LineEnding +
    '  views, click the arrow to pick one from the list.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.12' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- Build a transition.  SHOP > Build a transition... (or /transition) takes' + LineEnding +
    '  the ticket - the two openings, the length, which side comes in and by how' + LineEnding +
    '  much, flat bottom or flat top or top up - draws the sketch beside the' + LineEnding +
    '  numbers as you type, and builds the four sides as one piece with its' + LineEnding +
    '  entry corner on the cursor; click to put it where it goes.  Sizes are' + LineEnding +
    '  inches unless you write a foot mark.' + LineEnding +
    '- One view button in place of PLAN / ISO / 3D.  It parks the camera on a' + LineEnding +
    '  named view - the four corners, the top, the four sides - left click steps' + LineEnding +
    '  forward, right click back, and it reads 3D as soon as you orbit off.  The' + LineEnding +
    '  paper modes are under SHOP as the field sketch, for the wizard that will' + LineEnding +
    '  be built on them.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.11' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- The dimension tool takes a corner as a point.  A corner is always on an' + LineEnding +
    '  edge, and a click near an edge took the whole edge, so a dimension from' + LineEnding +
    '  one corner to another - across the drawing, between things that are not' + LineEnding +
    '  connected - could not be started.  A point the cursor has snapped to is' + LineEnding +
    '  the point meant; the body of an edge still takes all of it.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.10' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- The cursor tip says it now: a dimension can run between any two points -' + LineEnding +
    '  a corner of the footing and the roof next door - with the dimension tool' + LineEnding +
    '  or by pressing Enter after a tape measurement.  Both already worked; the' + LineEnding +
    '  tip did not say so.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.9' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- The middle of a footing ring can be erased.  A rectangle offset out and' + LineEnding +
    '  in, with the middle lines removed, makes a ring with a hole; erasing the' + LineEnding +
    '  face in the hole gave it straight back, because the check for "was there' + LineEnding +
    '  a face here" looked only at the ring''s outline and not at its hole.' + LineEnding +
    '- The rear edges of a pulled circle and the top of a column drew dashed in' + LineEnding +
    '  the last build; the hidden-line test had been made too strict for the' + LineEnding +
    '  depth buffer''s precision on a model far from the origin.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.8' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- The last of the line bleed: the corners of a tunnel''s mouth and the' + LineEnding +
    '  creases of a cylinder no longer poke a pixel or two into the face beside' + LineEnding +
    '  them.  Heavier profile lines end exactly on their corners too.' + LineEnding +
    '- Hovering or selecting an edge lights only the part of it you can see, the' + LineEnding +
    '  way SketchUp does, instead of the whole line through every face.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.7' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- Drawing on the face of a box is steadier.  The "line up with that' + LineEnding +
    '  corner" nudges used to grab the cursor every few pixels as it swept' + LineEnding +
    '  across a face; they wait for the hand to slow down now, and one taken' + LineEnding +
    '  holds a little longer than it took to get, so it does not flicker.' + LineEnding +
    '  Snapping to points and edges is unchanged.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.6' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- A line hidden behind something no longer runs a little way into the face' + LineEnding +
    '  that hides it: the visible part ends exactly at the edge.  Same for arcs' + LineEnding +
    '  and circles.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.5' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- A circle drawn with few sides was still outlined smooth in some views' + LineEnding +
    '  while its face and anything pulled from it were faceted.  Every drawing' + LineEnding +
    '  pass uses the side count now.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.4' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- Sending a report shows what is going, stage by stage, in a window like' + LineEnding +
    '  the update''s - the text and its size, the report''s name, the picture -' + LineEnding +
    '  with a moment on each so it can be read.  If it does not go, the window' + LineEnding +
    '  says why and waits.' + LineEnding +
    '- When something goes wrong inside the program and it keeps running, it' + LineEnding +
    '  offers to send the report right then, not at the next start.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- Drilling a tunnel through another one could bring the program down after' + LineEnding +
    '  the cut, while it was trimming the edges: a bookkeeping slip after the' + LineEnding +
    '  walls were removed.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.3' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- A tunnel whose floor met a round tunnel exactly at one of its creases' + LineEnding +
    '  left that floor uncut; the crossing is found along the crease now.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.2' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- Round tunnels drill through square ones and square through round: the' + LineEnding +
    '  crossing is cut on every segment.  Twelve sides makes a clean job of it.' + LineEnding +
    '- How many sides a circle or an arc gets is yours: + and - while the tool is' + LineEnding +
    '  in hand, or type 24s (or s24), the way SketchUp takes it.  The cursor tip' + LineEnding +
    '  says the count and how to change it.  Circles start at 24, arcs at 12.' + LineEnding +
    '- The cursor tip gives an example of what to type for every tool - 12''6,' + LineEnding +
    '  6-8-15, 8x10, 45 or 8:12, [x,y,z] - not just "type a length".' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- Snapping no longer grabs points hidden behind a face.  Drawing on a wall' + LineEnding +
    '  used to catch the corner of a tunnel behind it and put the click inside' + LineEnding +
    '  the block.' + LineEnding +
    '- The update window pauses on each step long enough to be read.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06.1' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- Where two tunnels cross, the edges drawn along each tunnel no longer run' + LineEnding +
    '  on through the other one''s bore.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.06' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- DRILL (B): push a shape through a block that already has a tunnel in it' + LineEnding +
    '  and the two tunnels cut into each other - both walls opened where they' + LineEnding +
    '  cross, nothing left inside either bore.  SketchUp stops at the first' + LineEnding +
    '  tunnel and leaves you to Intersect Faces and erase by hand; this makes the' + LineEnding +
    '  manifold in one push.  Square openings for now; round ones next.' + LineEnding +
    '- Push/pull stops where it would run into a tunnel, the way SketchUp''s does,' + LineEnding +
    '  and says how far it got and that Drill goes on through.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- A plane held with an arrow key passes through the face under the cursor,' + LineEnding +
    '  instead of floating wherever the cursor last was.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.05.31' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- A tunnel pushed through a box opens both ends, whichever wall it starts' + LineEnding +
    '  from.  In one direction the wall it started from stayed filled, because' + LineEnding +
    '  the rule that divides a wall for a shape drawn on it gave up once anything' + LineEnding +
    '  else had split that wall''s edges.' + LineEnding +
    '- The far end of a tunnel no longer gets filled back in by the next thing' + LineEnding +
    '  you draw.' + LineEnding +
    '- A wall divided by a shape drawn on it no longer turns blue - a piece could' + LineEnding +
    '  come out facing into the box.' + LineEnding +
    '- The walls lining a tunnel face inward whichever way the push went.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.05.30' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- An arc''s pull only takes the arc onto a face that holds all three of its' + LineEnding +
    '  points.  A pull that snapped to some stray point behind the wall used to' + LineEnding +
    '  tilt the arc off the wall.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.05.29' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- Pushing or pulling a face stops at whatever point or edge the cursor is' + LineEnding +
    '  resting on - hover the far edge of a box and the push goes exactly that' + LineEnding +
    '  deep.  Faces already did this; points and edges do now.' + LineEnding +
    '- Push a shape on the side of a solid straight through to the far side and' + LineEnding +
    '  it makes a hole: both faces open, the tunnel walled, nothing to erase.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.05.28' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- The arc tool shows what it is doing: the two ends marked, the chord, the' + LineEnding +
    '  pull from the chord''s middle in the color of the axis it runs along - blue' + LineEnding +
    '  when it goes straight up a wall - and the arc itself where it will land.' + LineEnding +
    '  The bulge reads live in the bar.' + LineEnding +
    '- ON FACE: a point resting on a face says so, with a blue mark, the way' + LineEnding +
    '  SketchUp''s does.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- An arc drawn up the end of a box stands on the end of the box.  It used' + LineEnding +
    '  to drop onto the ground when the first click landed on an edge, because' + LineEnding +
    '  the arc was built in the working plane whatever the three points said.' + LineEnding +
    '  Three points make a plane, and the arc is built in theirs.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.05.27' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- Erasing an arc''s face on the end of a box works.  The face came straight' + LineEnding +
    '  back, because the check for "was there a face here" was matching a face on' + LineEnding +
    '  the far end of the box - same direction, different wall.' + LineEnding +
    '- A wall with a rounded bite out of it no longer grows a second, loose copy' + LineEnding +
    '  of itself over the top.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.05.26' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- Updating shows a proper progress window: download size and percentage,' + LineEnding +
    '  the checksum check, the install, and the restart.' + LineEnding +
    '- After an update, this window shows what changed.  It is also under the' + LineEnding +
    '  help button as "What''s new", any time.' + LineEnding +
    '- A typed distance on the tape measure lays the guide.  Click the first' + LineEnding +
    '  point, aim along an edge or an axis, type how far, and Enter puts down' + LineEnding +
    '  the guide line and its point exactly as a click would.' + LineEnding +
    '- The program opens in PRO now, not the toy, and a new sheet starts on the' + LineEnding +
    '  3D corner view instead of the flat plan.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- On Linux, the program restarts properly after an update.  It used to' + LineEnding +
    '  install the new version and then fail to come back up.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.05.25' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- Rotate: click the center, a point to measure from, then swing to the' + LineEnding +
    '  angle and click, or type it - 45, 22.5, or 8:12 for a slope.  The arrows' + LineEnding +
    '  pick the plane by axis color, Ctrl leaves a turned copy, and the angle' + LineEnding +
    '  snaps to the fifteens near them.  Q, or the ROTATE button.' + LineEnding +
    '- A protractor that lays guides at an angle, the same three clicks.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- Openings in a face now travel with it when it is moved.' + LineEnding +
    '- A move locked to blue drew its travel line gray instead of blue.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.05.24' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- Notes can be made bigger or smaller: pick one, then + or -.' + LineEnding +
    '- Clicking the words of a note picks it.  It used to grab the note for a' + LineEnding +
    '  drag and then let go without selecting it.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.05.23' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- DXF export: the flat pattern for a cutting table, and the whole drawing' + LineEnding +
    '  either flat or as a 3D model, with layers for cuts, bends and notches.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.05.22' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- The shop pattern marks brake notches at the ends of every bend line.' + LineEnding +
    '- A dimension can be placed outside a closed shape, not only inside it.' + LineEnding +
    '- Arcs drawn on a solid''s face split that face, the way lines do.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- Offset put its copy a long way from the face.  It stays on the face''s' + LineEnding +
    '  plane now.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.05.21' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- The flat pattern carries the openings cut through a piece.' + LineEnding +
    '' + LineEnding +
    '### Fixed' + LineEnding +
    '' + LineEnding +
    '- The eraser''s blue wash stopped at what was in front of the face being' + LineEnding +
    '  erased, instead of painting over it.' + LineEnding +
    '';
