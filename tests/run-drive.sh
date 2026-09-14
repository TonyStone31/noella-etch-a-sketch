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
#
# Several scripts expect a particular drawing to be open.  A script named
# after its drawing gets it automatically; the rest are listed here, because
# running "the panel, seen from behind" against whatever happened to be open
# is a test that passes by accident.
set -u
cd "$(dirname "$0")/.."

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
         glass-revolve plan-slice plan-hidden command-list toy-command"
fi

BAD=0
for n in $NAMES; do
  [ -f "tests/drive/$n.txt" ] || { echo "$n: no such script"; BAD=1; continue; }
  d="$(drawing_for "$n")"
  if timeout 180 tools/xephyr.sh "tests/drive/$n.txt" $d >/dev/null 2>&1; then
    echo "$n ok"
  else
    echo "$n FAILED"
    BAD=1
  fi
done
exit $BAD
