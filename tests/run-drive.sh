#!/usr/bin/env bash
# Drive the program through a nested X server and say whether each script ran.
#
# These are not assertions - each script leaves screenshots behind for a
# person to look at.  What this proves is narrower and still worth having:
# the program starts, takes the whole script without falling over, and comes
# back.  A crash halfway through is the thing it catches.
#
#   tests/run-drive.sh              # all of them
#   tests/run-drive.sh gable        # one
#   tests/run-drive.sh tools        # one chain (see below)
#   JOBS=1 tests/run-drive.sh       # one at a time, the old way
#   SOLO=1 tests/run-drive.sh       # no chains, every script its own program
#
# Several scripts expect a particular drawing to be open.  A script named
# after its drawing gets it automatically; the rest are listed here, because
# running "the panel, seen from behind" against whatever happened to be open
# is a test that passes by accident.
#
# Several at once
# ---------------
# Each script is a program start, a drawing read and half a minute or so of
# driving, and there are thirty-odd of them: one at a time that is ten
# minutes, which is long enough that the suite stops being run.  They do not
# share anything - every one gets a display, a copy of the program and a
# folder of its own - so they go several at a time.  JOBS says how many; ten
# by default, and the whole suite comes back in a little over a minute.
#
# The risk is that the scripts wait in wall-clock milliseconds, so a lane
# starved of processor could miss a wait that would have been long enough.
# Measured, that is not what is happening here: ten lanes use about two
# minutes of processor across one minute of clock, on a machine with
# thirty-two cores - they are asleep almost the whole time.  The flakiness
# this suite has always had predates the lanes.  Still, if a run starts
# failing in scattered places, JOBS=1 is the first thing to try.
#
# Every script says how long it took.  That line is what keeps the suite
# honest: it used to take three and a half minutes, and the reason was
# visible the moment the numbers were printed - one chain of seven was
# nearly three of them while nine lanes sat idle.
#
# A failure is retried once, on its own, because that is what a person does
# with this suite by hand.  The retry says so rather than hiding it, and
# what the program itself printed is left behind for reading.
#
# Chains
# ------
# Some scripts run one after another in a single program, on a new sheet
# each time but with everything else carried over.
#
# From a note: "some of the tests we could conduct together in a single test
# instance rather than always starting a new instance as that will also
# sometimes reveal additional bugs".
#
# That is the point of them, and it is a better reason than the few seconds
# of start-up they save.  Every script here has only ever run against a
# program that just started: no tool used before it, no undo behind it, no
# other sheet open, nothing on the clipboard, every setting as it came.  A
# chain is the only thing in the suite that asks whether the fourth thing
# you do still works - which is the way the program is actually used, and
# not a state any single script can reach.
#
# When a chain fails its members are run again one at a time.  A member that
# then passes alone is the interesting case, not a flake: something before
# it left state behind that it could not cope with.  That is the bug the
# chain exists to find, and it is reported in those words.
#
# Scripts that put a dialog up, measure frame times, or record for half a
# minute stay on their own - the first would take its neighbors with it,
# and the other two would be measuring the chain rather than themselves.
set -u
cd "$(dirname "$0")/.."

JOBS="${JOBS:-10}"
SOLO="${SOLO:-}"

# What runs with what.  Grouped by the part of the program they lean on, so
# that a chain failing says something - "the drawing tools after each other"
# rather than "scripts 4, 11 and 19".
#
# Short chains, and that is a decision rather than an accident.  A chain
# runs its members one after another, so a chain is as slow as all of it
# added up while everything else in the suite is running beside it: with
# four long chains the whole suite waited on the longest one, which was
# nearly three minutes of the three and a half the run took.  Measured
# member by member, chaining saves about four seconds of start-up across a
# whole chain - so the length was buying nothing but time.
#
# What the length WAS buying is the thing chains are for: whether the fourth
# thing you do still works.  Two or three in a row still asks that, of the
# scripts most likely to tread on each other, and the suite comes back in a
# third of the time.  If a pair here ever stops being worth running
# together, split it; if two want joining, join them - but keep an eye on
# the numbers the run prints, and keep the longest chain near the longest
# single script.
chain_members() {
  case "$1" in
    commands) echo "command-list cmd-example cmd-wheel whatsnew-drag" ;;
    views)    echo "plan-slice plan-hidden view-cube" ;;
    cube)     echo "cube-corners cube-keys round-corner" ;;
    tools)    echo "dim-face-edge dim-needs-something tape-finishes" ;;
    picking)  echo "guide-picking alt-tools" ;;
    shapes)   echo "round-corners line-length" ;;
    offsets)  echo "offset-rounded inference-alt" ;;
    edits)    echo "move-edge bulk-color" ;;
    *)        echo "" ;;
  esac
}
CHAINS="offsets shapes edits cube commands tools picking views"

# Between one script and the next: drop whatever tool or dialog the last one
# left, and start a fresh sheet.  Not a fresh program - the settings, the
# clipboard, the other sheets and their undo all stay, which is the whole
# reason for running them together.
chain_break() {
  cat <<'BREAK'
key escape
key escape
key slash
type new
key return
wait 1500
BREAK
}

drawing_for() {
  case "$1" in
    reverse-face)    echo tests/drive/panel.hsk ;;
    held-endpoint)   echo tests/drive/post.hsk ;;
    glass-revolve)   echo tests/drive/glass-profile.hsk ;;
    revolve-edge)    echo tests/drive/tonys-glass.hsk ;;
    upright-outline) echo tests/drive/empty-3d.hsk ;;
    gable)           echo tests/drive/slab.hsk ;;
    *)               [ -f "tests/drive/$1.hsk" ] && echo "tests/drive/$1.hsk" ;;
  esac
}

# The ones that are nobody's chain.  Longest first, and so are the chains
# above: lanes are handed work in the order it is listed, and a long job
# picked up last is a long job everything else waits on.  Sorting by the
# times the run prints is most of the difference between three minutes and
# one.
SOLOISTS="groups copy-paste gif-loop entity-panel face-needs-edges close-asks
          frame-watchdog entity-style guide-select export-dialog help-window
          ring-hint orbit-snap orbit-grid help-picture revolve-edge
          glass-revolve dim-resize report-tick upright-outline reverse-face
          narrow-window held-endpoint blank-start"

if [ $# -gt 0 ]; then
  NAMES="$*"
else
  # the chains first, because they are the longest things here
  NAMES="$CHAINS $SOLOISTS"
  # SOLO=1 takes the chains apart again, for when a chain has failed and the
  # question is whether any of it was ever broken.  Written out of the chain
  # table rather than kept as a second list beside it: the second list went
  # stale the moment a script was added to a chain and not to it, and five
  # of them were being skipped in a SOLO run without anybody noticing.
  if [ -n "$SOLO" ]; then
    NAMES=""
    for c in $CHAINS; do NAMES="$NAMES $(chain_members "$c")"; done
    NAMES="$NAMES $SOLOISTS"
  fi
fi

OUT="$(mktemp -d /tmp/hsk-drive-XXXXXX)"
# kept when something failed, thrown away when everything passed - the
# combined chain scripts and what the program printed are the only things
# there are to go on afterwards
tidy() {
  if [ "${BAD:-0}" = 0 ]; then rm -rf "$OUT"
  else echo "-- what the program said is in $OUT"; fi
}
trap tidy EXIT

# A chain, written out as one script with a break between each member and a
# marker before it.  hidctl stops at the first thing that fails, so the last
# marker it echoed is the member that was running when it did.
build_chain() {
  local name="$1" m first=1
  : > "$OUT/$name.txt"
  for m in $(chain_members "$name"); do
    [ "$first" = 1 ] || chain_break >> "$OUT/$name.txt"
    first=0
    echo "echo == $m" >> "$OUT/$name.txt"
    cat "tests/drive/$m.txt" >> "$OUT/$name.txt"
    echo >> "$OUT/$name.txt"
  done
}

# Which member of a chain was running when it stopped.
died_on() {
  sed -n 's/^== //p' "$OUT/$1.said" 2>/dev/null | tail -1
}

# Scripts that want the program to start on an empty sheet - see --blank.
blank_for() {
  case "$1" in
    blank-start) echo 1 ;;
    groups)      echo 1 ;;
    *)           echo "" ;;
  esac
}

# Scripts that want files beside the program before it starts: a folder of
# their own, filled, and removed afterwards.  Echoes the folder, or nothing.
rundir_for() {
  local d
  case "$1" in
    help-window|help-picture)
      d="$(mktemp -d /tmp/hsk-rundir-XXXXXX)"
      mkdir -p "$d/help" && cp -r docs/help/. "$d/help/"
      echo "$d" ;;
    *) echo "" ;;
  esac
}

# One script or one chain, start to finish.  Says how it went as it finishes
# rather than waiting for the rest, so a run in progress is readable.
run_one() {
  local n="$1" d rc script began took
  began=$SECONDS
  if [ -n "$(chain_members "$n")" ]; then
    build_chain "$n"
    script="$OUT/$n.txt"
    d=""
  else
    script="tests/drive/$n.txt"
    d="$(drawing_for "$n")"
  fi
  local rd
  rd="$(rundir_for "$n")"
  BLANK="$(blank_for "$n")" RUNDIR="$rd" LOG="$OUT/$n.applog" timeout 300 \
    tools/xephyr.sh "$script" $d >"$OUT/$n.said" 2>&1
  rc=$?
  [ -n "$rd" ] && rm -rf "$rd"
  echo "$rc" > "$OUT/$n.rc"
  # How long it took, beside how it went.  A suite nobody can see the shape
  # of is a suite that quietly grows another minute every week; this is the
  # line that says which script to look at.
  took=$((SECONDS - began))
  echo "$took" > "$OUT/$n.secs"
  if [ "$rc" = 0 ]; then
    printf '%-16s ok   %3ds\n' "$n" "$took"
  elif [ -n "$(chain_members "$n")" ]; then
    printf '%-16s FAILED %3ds - stopped at %s\n' "$n" "$took" "$(died_on "$n")"
  else
    printf '%-16s FAILED %3ds\n' "$n" "$took"
  fi
  # always nought: how it went is in the .rc file, and a lane reporting a
  # failure to "wait -n" would send this back to one at a time
  return 0
}

BAD=0
LIVE=0
TODO=""
for n in $NAMES; do
  if [ ! -f "tests/drive/$n.txt" ] && [ -z "$(chain_members "$n")" ]; then
    echo "$n: no such script or chain"; BAD=1; continue
  fi
  TODO="$TODO $n"
  run_one "$n" &
  LIVE=$((LIVE + 1))
  if [ "$LIVE" -ge "$JOBS" ]; then wait -n 2>/dev/null || wait; LIVE=$((LIVE - 1)); fi
done
wait

# Whatever failed, once more on its own.  A script that passes alone was
# fighting for the processor, not broken; one that fails both ways is worth
# looking at, and what the program printed is sitting in $OUT.
AGAIN=""
for n in $TODO; do
  [ "$(cat "$OUT/$n.rc" 2>/dev/null)" = 0 ] || AGAIN="$AGAIN $n"
done

# One script, alone, in a program of its own.  Says ok or not; prints what
# the program said when it did not.
solo() {
  local n="$1" d
  d="$(drawing_for "$n")"
  local rd ok=1
  rd="$(rundir_for "$n")"
  BLANK="$(blank_for "$n")" RUNDIR="$rd" LOG="$OUT/$n.applog" timeout 180 \
    tools/xephyr.sh "tests/drive/$n.txt" $d >"$OUT/$n.solo" 2>&1 && ok=0
  [ -n "$rd" ] && rm -rf "$rd"
  [ "$ok" = 0 ] && return 0
  sed -n '$p' "$OUT/$n.solo" 2>/dev/null | sed 's/^/    said: /'
  tail -6 "$OUT/$n.applog" 2>/dev/null | sed 's/^/    log: /'
  return 1
}

if [ -n "$AGAIN" ]; then
  echo "-- once more on their own:$AGAIN"
  for n in $AGAIN; do
    MEMBERS="$(chain_members "$n")"
    if [ -n "$MEMBERS" ]; then
      # A chain.  Run every member by itself: the ones that pass alone were
      # broken by something that ran before them, which is the whole reason
      # the chain is there.
      STOPPED="$(died_on "$n")"
      LEAK=""
      for m in $MEMBERS; do
        if solo "$m"; then
          [ "$m" = "$STOPPED" ] && LEAK="$m"
        else
          echo "  $m FAILED on its own too"
          BAD=1
        fi
      done
      if [ -n "$LEAK" ]; then
        echo "  $LEAK passes alone and failed in the chain - something before"
        echo "  it left state it could not cope with.  That is a real finding,"
        echo "  not a flaky test: see $OUT/$n.txt and $OUT/$n.applog"
        BAD=1
      fi
    elif solo "$n"; then
      echo "$n ok (second try - it was the lanes, not the program)"
    else
      echo "$n FAILED twice"
      BAD=1
    fi
  done
fi
exit $BAD
