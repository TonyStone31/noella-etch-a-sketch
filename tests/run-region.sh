#!/usr/bin/env bash
# The planar region engine on its own - no window, no document.
set -e
cd "$(dirname "$0")/.."
LAZ=/media/tony/storpart/fpctrunklaztrunk/lazarus
FPC=/media/tony/storpart/fpctrunklaztrunk/fpc/bin/x86_64-linux/fpc
[ -x "$FPC" ] || FPC=fpc
WS=${LCL_WS:-gtk3}
"$FPC" -B -Mobjfpc -Sh -Cirot -O1 -FE/tmp -FU/tmp -Fu. \
  -Fu"$LAZ/lcl/units/x86_64-linux" \
  -Fu"$LAZ/lcl/units/x86_64-linux/$WS" \
  -Fu"$LAZ/components/lazutils/lib/x86_64-linux" \
  -dLCL -dLCL$WS \
  -otests_regiontest tests/regiontest.pas >/tmp/regiontest-build.log 2>&1 \
  || { tail -25 /tmp/regiontest-build.log; exit 1; }
exec /tmp/tests_regiontest
