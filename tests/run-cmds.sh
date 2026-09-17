#!/usr/bin/env bash
# Every command the list offers is a command the program answers to.
#
# The checking is tests/cmdcheck.pas, which reads the command table and the
# dispatcher out of uMain.pas and says where they disagree - see the note at
# the top of it.  This compiles it and runs it.
set -eu
cd "$(dirname "$0")/.."
FPC=/media/tony/storpart/fpctrunklaztrunk/fpc/bin/x86_64-linux/fpc
[ -x "$FPC" ] || FPC=fpc
OUT="${TMPDIR:-/tmp}/hsk-cmdcheck"
mkdir -p "$OUT"
"$FPC" -Mobjfpc -Sh -O1 -FE"$OUT" -FU"$OUT" -ocmdcheck tests/cmdcheck.pas \
  >"$OUT/build.log" 2>&1 || { tail -25 "$OUT/build.log"; exit 1; }
exec "$OUT/cmdcheck" uMain.pas
