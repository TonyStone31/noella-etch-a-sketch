# Groups

Source: SketchUp Help, *Grouping Geometry*
(help.sketchup.com/en/sketchup/grouping-geometry), *Organizing a Model*,
*Selecting Geometry* and *Working with Hierarchies in Outliner*, read
20 September 2026.  The pages render their text in the browser, so this is
the reference copy; the wording quoted is theirs.

## What a group is

* "Objects don't stick to other entities.  Each Object can be edited
  independently of other Objects, even if the Objects are stacked on top
  of each other."  That single sentence is the feature.
* SketchUp calls groups and components together *Objects*.  A component is
  a definition with instances; a group is one-off.  See *Where we differ*.

## Making one

* "Select all the geometry you want to include in the Object", then
  **Edit > Make Group**, or context-click the selection and **Make Group**.
* "A bounding box appears around the selection designating it as a Group."
* "You can nest Objects within Objects."

## Editing one

* "Double-click the Object with the Select tool" to open its context.
* "The dotted box indicates the Object's context is open."  The rest of
  the model is greyed while an object is open.
* To leave: click "an empty part of the drawing area", or **Edit > Close
  Group/Component**; the *Organizing a Model* page adds **Esc**.

## Locking

* Context-click and **Lock**; "after you lock an Object, the menu item
  changes to Unlock."
* A locked object "can't be moved or edited" - "Lock an Object to prevent
  it from being edited accidentally."
* Locked objects serve as "boundaries for convenient snapping without
  accidentally modifying your geometry."

## Exploding

* Select it and **Edit > Group > Explode**.  The contents become ordinary
  geometry again and join whatever they touch.

## Naming

* Entity Info has a name field; in the Outliner "context-click or
  triple-click the group name, select Rename, type a name, and press
  Enter."  A component is renamed by renaming its definition.

## Selecting (from *Selecting Geometry*)

* "Double-clicking a face selects the face and all bounding edges";
  "double-clicking an edge selects that edge and each connected face";
  "triple-clicking anywhere on an entity selects all connected entities."
* Drag right: "only what's completely inside the box."  Drag left:
  "anything completely or partially inside the box."
* Ctrl adds, Shift toggles, Shift+Ctrl subtracts.

---

## What we have, 20 September 2026

**Built**, and named *group* in the program (`/group`, Ctrl+G, and the
right button's *Make Group*):

* a click on anything in a group takes the whole group, drawn as its
  bounding box; double-click opens it; inside, the rest of the drawing
  fades and cannot be picked; a click on nothing, Escape, `/leave` or the
  menu's *Close Group* comes back out one level;
* geometry in a group does not join, split or stretch geometry outside it
  - the region finder runs once per group, splitting and welding stay
  inside the group being drawn in, and a whole group moves rigidly;
* nesting, with the outermost group between the entity and the open
  context being what a click takes;
* lock and unlock, from the menu, `/lock`, `/unlock`, or the entity panel;
  a locked group shows red, can be picked and snapped to, and cannot be
  moved, opened, changed, erased or grouped;
* explode, `/explode` or the menu; a group inside stays a group;
* names, `/name ...` and the entity panel; the default is *Group n*;
* snapping to a closed group from outside, and drawing on its face from
  outside without joining it;
* a copy of a group (Ctrl-move, arrays, copy and paste) is a group of its
  own;
* saved as `GROUP` and `PARTOF` lines an older build skips, so a file with
  groups opens flattened there.

**Where we differ, on purpose:**

* No components.  A copy is its own group and edits do not propagate.  The
  plan in `docs/groupplan.md` keeps room for a "copy of" link if that ever
  matters; it is not built and nothing asks for it yet.
* A face grouped without its edges takes its edges along.  SketchUp does
  the same in practice, since a face cannot exist without them; here it is
  a rule rather than a side effect, because faces are worked out from edges
  on every rebuild.
* Pushing, pulling, drilling, offsetting or turning over a face inside a
  closed group is refused from outside, as in SketchUp; a dimension across
  a group's edge from outside is allowed.

* the crate's grips (*Moving Entities*: "inference icons at the corners of
  the component/group's bounding box", Alt cycling "corners, midpoints,
  side centers, or the center") are snap points here, all of them at
  once, for every group directly in the open context; a locked group's
  crate is drawn faintly all the time.

**Not built:** the Outliner; hiding a group; SketchUp's inference
"On Face in Group" wording (ours says On Face); scaling a group as a whole;
Alt cycling which grips show - all of them are offered.
