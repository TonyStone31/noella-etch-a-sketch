#!/usr/bin/env bash
# The radiant layout measured on a corpus of floors, against the numbers kept in
# tests/radiant-baseline.txt - see tests/radiantbench.pas.  --save keeps this
# run's numbers as the new baseline.
set -e
cd "$(dirname "$0")/.."
LAZ=/media/tony/storpart/fpctrunklaztrunk/lazarus
FPC=/media/tony/storpart/fpctrunklaztrunk/fpc/bin/x86_64-linux/fpc
[ -x "$FPC" ] || FPC=fpc
WS=${LCL_WS:-gtk3}
"$FPC" -B -Mobjfpc -Sh -Cirot -O1 -FE/tmp -FU/tmp -Fu. -Fuwebp \
  -Fu"$LAZ/lcl/units/x86_64-linux" \
  -Fu"$LAZ/lcl/units/x86_64-linux/$WS" \
  -Fu"$LAZ/components/lazutils/lib/x86_64-linux" \
  -Fu"$LAZ/../config_lazarus/onlinepackagemanager/packages/BGRABitmap/bgrabitmap/lib/x86_64-linux-$WS-3.3.1" \
  -dLCL -dLCL$WS \
  -otests_radiantbench tests/radiantbench.pas >/tmp/radiantbench-build.log 2>&1 \
  || { tail -25 /tmp/radiantbench-build.log; exit 1; }
exec /tmp/tests_radiantbench "$@"
