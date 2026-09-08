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
    '- Center, not centre: the wizards'' words are American now.' + LineEnding +
    '' + LineEnding +
    '## v2026.09.07' + LineEnding +
    '' + LineEnding +
    '### New' + LineEnding +
    '' + LineEnding +
    '- **Pipe spool.**  SHOP > Pipe spool..., or /spool: the pipe fitter''s iso' + LineEnding +
    '  as a form.  Iso paper you click the run onto, one leg at a time - each' + LineEnding +
    '  leg snaps to the three axes, or with Shift to a 45 - and type the' + LineEnding +
    '  centre-to-centre length on.  Pick the pipe size, long or short radius' + LineEnding +
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
    '  round its centre.' + LineEnding +
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
    '  painted in the inside colour.  The builder wound those faces the wrong' + LineEnding +
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
    '- **A tee''s branch centres itself.**  Leave "starts, from the entry" blank' + LineEnding +
    '  and the branch sits in the middle of the run, the way a blank height' + LineEnding +
    '  already centres it on the wall.' + LineEnding +
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
    '- A move locked to blue drew its travel line grey instead of blue.' + LineEnding +
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
