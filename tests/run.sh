#!/usr/bin/env bash
# Headless geometry checks.  No window is opened - this links the LCL only for
# the TColor and TStrings types uWork happens to use.
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
  -otests_geomtest tests/geomtest.pas >/tmp/geomtest-build.log 2>&1 \
  || { tail -25 /tmp/geomtest-build.log; exit 1; }
exec /tmp/tests_geomtest
