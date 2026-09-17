#!/usr/bin/env bash
# Every command the list offers is a command the program answers to.
#
# The checking is tests/cmdcheck.pas, which reads the command table and the
# dispatcher out of uMain.pas and says where they disagree - see the note at
# the top of it.  It is a Pascal script: instantfpc, which comes with Free
# Pascal, compiles it the first time and runs it from a cache after that.
set -eu
cd "$(dirname "$0")/.."
if command -v instantfpc >/dev/null; then
  exec tests/cmdcheck.pas uMain.pas
fi
# not on PATH - the toolchain this project builds with has one
T=/media/tony/storpart/fpctrunklaztrunk/fpc/bin/x86_64-linux
exec "$T/instantfpc" --compiler="$T/fpc" tests/cmdcheck.pas uMain.pas
