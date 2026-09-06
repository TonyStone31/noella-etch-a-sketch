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
