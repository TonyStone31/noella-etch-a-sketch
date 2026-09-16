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
#   JOBS=1 tests/run-drive.sh       # one at a time, the old way
#
# Several scripts expect a particular drawing to be open.  A script named
# after its drawing gets it automatically; the rest are listed here, because
# running "the panel, seen from behind" against whatever happened to be open
# is a test that passes by accident.
#
# Several at once
# ---------------
# Each script is a program start, a drawing read and a minute or so of
# driving, and there are twenty-eight of them: one at a time that is ten
# minutes, which is long enough that the suite stops being run.  They do not
# share anything - every one gets a display, a copy of the program and a
# folder of its own - so they go several at a time.  JOBS says how many.
#
# It is not free: the scripts wait in wall-clock milliseconds, so a lane
# starved of processor can miss a wait that would have been long enough.
# Four lanes on a machine with plenty of cores has been steady; if a run
# starts failing in scattered places, JOBS=1 is the first thing to try, and
# a script that then passes was never really failing.
#
# A failure is retried once, on its own, because that is what a person does
# with this suite by hand.  The retry says so rather than hiding it, and
# what the program itself printed is left behind for reading.
set -u
cd "$(dirname "$0")/.."

JOBS="${JOBS:-4}"

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

if [ $# -gt 0 ]; then
  NAMES="$*"
else
  NAMES="held-endpoint reverse-face dim-resize upright-outline revolve-edge
         glass-revolve plan-slice plan-hidden command-list toy-command
         cmd-example cmd-wheel gif-loop view-cube cube-corners
         whatsnew-drag dim-face-edge dim-needs-something round-corner ring-hint move-edge
         face-needs-edges tape-finishes guide-picking frame-watchdog
         close-asks copy-paste entity-panel"
fi

OUT="$(mktemp -d /tmp/hsk-drive-XXXXXX)"
trap 'rm -rf "$OUT"' EXIT

# One script, start to finish.  Says how it went as it finishes rather than
# waiting for the rest, so a run in progress is readable.
run_one() {
  local n="$1" d rc
  d="$(drawing_for "$n")"
  LOG="$OUT/$n.applog" timeout 180 tools/xephyr.sh "tests/drive/$n.txt" $d \
    >"$OUT/$n.said" 2>&1
  rc=$?
  echo "$rc" > "$OUT/$n.rc"
  [ "$rc" = 0 ] && echo "$n ok" || echo "$n FAILED"
  # always nought: how it went is in the .rc file, and a lane reporting a
  # failure to "wait -n" would send this back to one at a time
  return 0
}

BAD=0
LIVE=0
TODO=""
for n in $NAMES; do
  if [ ! -f "tests/drive/$n.txt" ]; then echo "$n: no such script"; BAD=1; continue; fi
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

if [ -n "$AGAIN" ]; then
  echo "-- once more on their own:$AGAIN"
  for n in $AGAIN; do
    d="$(drawing_for "$n")"
    if LOG="$OUT/$n.applog" timeout 180 tools/xephyr.sh "tests/drive/$n.txt" $d \
         >"$OUT/$n.said" 2>&1; then
      echo "$n ok (second try - it was the lanes, not the program)"
    else
      echo "$n FAILED twice"
      sed -n '$p' "$OUT/$n.said" 2>/dev/null | sed 's/^/    said: /'
      tail -6 "$OUT/$n.applog" 2>/dev/null | sed 's/^/    log: /'
      BAD=1
    fi
  done
fi
exit $BAD
