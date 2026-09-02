#!/usr/bin/env bash
# Heckers Sketch build script — trunk FPC + Lazarus, GTK3 on Linux, win32
# widgetset for the Windows cross build.
#
#   ./build.sh            -> Linux, Debug. The dev loop. Range checks ON.
#   ./build.sh release    -> Linux, Release. -O3, smart linked, no debug info.
#   ./build.sh windows    -> Windows x86_64 .exe, Release. Zipped and uploaded.
#   ./build.sh windbg     -> Windows x86_64 .exe, DEBUG. Range checks on and
#                            line numbers in the crash log. Slower and fatter,
#                            and the one to test with while a crash is open.
#   ./build.sh all        -> Linux Debug + Windows.
#   ./build.sh run        -> Linux Debug, then run it on $DISPLAY.
#   ./build.sh clean      -> remove compiled units and both binaries.
#   ./build.sh fresh      -> clean, then build both. The gate before handing
#                            a build to anybody.
#   ./build.sh dist       -> Release both, stamped with the date and commit,
#                            into dist/, zipped and uploaded.
#   ./build.sh crossrtl   -> rebuild the FPC win64 cross RTL. Needed once, and
#                            again after every FPC update. See below.
#   ./build.sh upload F   -> put one file on a no-account file host and record
#                            the URL.
#   ./build.sh nozip      -> prefix: build without zipping or uploading, e.g.
#                            ./build.sh nozip windows
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
FPCROOT=/media/tony/storpart/fpctrunklaztrunk
LAZBUILD="$FPCROOT/lazarus/lazbuild"
FPC="$FPCROOT/fpc/bin/x86_64-linux/fpc.sh"
PROJ="$ROOT/etchasketch.lpi"
APP=etchasketch
DIST="$ROOT/dist"

# DEBUG IS THE DEV BUILD, AND IT IS THE ONE THAT CATCHES THINGS.
#
# The Debug mode compiles with -Cirot: I/O, range, overflow and stack checks.
# Two real bugs in the rasteriser only ever announced themselves as range
# check errors - a bounding box computed from a coordinate that did not fit an
# Integer, and a blend that produced 509 on its way into a Byte. With checks
# off, neither would have crashed; both would have quietly drawn nonsense.
# So build Debug while working, and only reach for Release to ship.
MODE_DEV=Debug
MODE_SHIP=Release

# Every Windows build gets zipped and put on catbox, because the exe has to
# reach a Windows machine somehow and a URL is the shortest path. NOZIP=1, or
# the nozip prefix, turns it off for a build you are only checking compiles.
NOZIP="${NOZIP:-0}"

# Windows will not run a .exe out of a browser download without a fight, and
# some setups strip the extension outright. A zip goes through untouched, and
# it also carries the readme next to the binary.
zip_and_upload() {
  local exe="$1" s zipname
  [ "$NOZIP" = "1" ] && return 0
  command -v zip >/dev/null || { say "no zip command - skipping"; return 0; }
  s="$(stamp)"
  mkdir -p "$DIST"
  zipname="$DIST/heckers-sketch-$s-win64.zip"
  local tmp; tmp="$(mktemp -d)"
  cp "$exe" "$tmp/heckers-sketch.exe"
  cat > "$tmp/README.txt" <<TXT
Heckers Sketch - $s

A drawing tool. No installer, no DLLs: unzip and run heckers-sketch.exe.

Windows will probably warn that the publisher is unknown - the binary is not
code signed. More info -> Run anyway.

If it crashes it writes heckers-sketch-crash.txt next to the exe. Send that
file; it names the line the crash came from.
TXT
  ( cd "$tmp" && zip -q -9 "$zipname" heckers-sketch.exe README.txt )
  rm -rf "$tmp"
  say "zipped $(du -h "$zipname" | cut -f1) -> $(basename "$zipname")"
  do_upload "$zipname"
}

# THE WINDOWS CROSS RTL, AND WHY IT GOES STALE.
#
# Cross compiling to Windows needs no mingw and no external linker - FPC has
# its own assembler and linker for PE targets. What it does need is the RTL
# and packages compiled for x86_64-win64 by *this* compiler.
#
# The trap: PPU files carry a format version, and a trunk compiler bumps it.
# fpcup installed win64 units in Nov 2025 (PPU 30); the compiler was rebuilt in
# Aug 2026 (PPU 32) and every win64 build then died on
#     PPU Invalid Long Version 30 expecting 32
#     Fatal: Can't find unit system
# which reads like a missing cross compiler and is not. `./build.sh crossrtl`
# rebuilds them. Run it after any FPC update, or when you see that message.
#
# make crossinstall writes to the standard FPC layout under lib/fpc/$VER, while
# fpc.cfg searches fpc/units/$fpctarget, so the two are joined by a symlink.
FPC_UNITS="$FPCROOT/fpc/units/x86_64-win64"
FPC_CROSS_UNITS="$FPCROOT/fpc/lib/fpc/3.3.1/units/x86_64-win64"

say() { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }

need_tools() {
  [ -x "$LAZBUILD" ] || die "lazbuild not found at $LAZBUILD"
  [ -f "$PROJ" ]     || die "project not found at $PROJ"
}

build_linux() {
  local mode="$1"
  need_tools
  say "Linux x86_64, $mode"
  "$LAZBUILD" --build-mode="$mode" "$PROJ"
  ls -la "$ROOT/$APP"
}

# The win64 units must exist and be readable by this compiler before lazbuild
# is asked to build the LCL against them, otherwise the failure surfaces a few
# hundred lines into a package build and looks like an LCL problem.
check_cross_rtl() {
  local probe; probe="$(mktemp -d)"
  cat > "$probe/probe.pas" <<'EOF'
program probe;
begin
end.
EOF
  if ! "$FPC" -Twin64 -Px86_64 -FU"$probe" -o"$probe/probe.exe" "$probe/probe.pas" >"$probe/log" 2>&1; then
    sed -n '1,12p' "$probe/log" >&2
    rm -rf "$probe"
    die "the win64 cross RTL is missing or stale - run: ./build.sh crossrtl"
  fi
  rm -rf "$probe"
}

build_windows() {
  local mode="${1:-$MODE_SHIP}"
  need_tools
  check_cross_rtl
  say "Windows x86_64, $mode"
  # --build-all because the LCL and its packages have to exist for this target
  # too; without it lazbuild will happily try to link against the Linux units.
  "$LAZBUILD" --os=win64 --cpu=x86_64 --ws=win32 \
              --build-mode="$mode" --build-all "$PROJ"
  [ -f "$ROOT/$APP.exe" ] || die "no $APP.exe was produced"
  file "$ROOT/$APP.exe"
  # A single self-contained exe is the whole point - nothing to install
  # alongside it. If a non-system DLL ever appears here, something pulled in a
  # dependency that will have to be shipped, and that is worth knowing at build
  # time rather than from somebody who cannot start the program.
  if command -v objdump >/dev/null; then
    local extra
    extra="$(objdump -p "$ROOT/$APP.exe" | sed -n 's/.*DLL Name: //p' | sort -u |
      grep -viE '^(advapi32|comctl32|comdlg32|gdi32|kernel32|ole32|oleaut32|shell32|user32|version|winmm|winspool)\.(dll|drv)$' || true)"
    if [ -n "$extra" ]; then
      say "WARNING - this build needs DLLs that are not part of Windows:"
      printf '   %s\n' $extra
    fi
  fi
  zip_and_upload "$ROOT/$APP.exe"
}

do_clean() {
  say "clean"
  rm -rf "$ROOT/lib"
  rm -f "$ROOT/$APP" "$ROOT/$APP.exe" "$ROOT/$APP.dbg"
  echo "removed lib/, $APP, $APP.exe, $APP.dbg   (dist/ left alone)"
}

# Stamped so that a file host with no folders still tells you what you are
# looking at months later. -dirty means it was built from a tree with
# uncommitted changes, which is exactly when you most want to know.
stamp() {
  local sha dirty
  sha="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo nogit)"
  dirty=""
  git -C "$ROOT" diff --quiet 2>/dev/null || dirty="-dirty"
  echo "$(date +%Y%m%d)-$sha$dirty"
}

do_dist() {
  local s; s="$(stamp)"
  build_linux "$MODE_SHIP"
  build_windows "$MODE_SHIP"
  mkdir -p "$DIST"
  cp "$ROOT/$APP"     "$DIST/heckers-sketch-$s-linux-x86_64"
  cp "$ROOT/$APP.exe" "$DIST/heckers-sketch-$s-win64.exe"
  ( cd "$DIST" && sha256sum "heckers-sketch-$s-linux-x86_64" \
      "heckers-sketch-$s-win64.exe" > "heckers-sketch-$s.sha256" )
  say "staged in dist/"
  ls -la "$DIST" | grep "$s" || true
}

do_crossrtl() {
  say "rebuilding the FPC win64 cross RTL (several minutes)"
  [ -d "$FPCROOT/fpcsrc" ] || die "no fpcsrc at $FPCROOT/fpcsrc"
  ( cd "$FPCROOT/fpcsrc" && make crossall crossinstall \
      CPU_TARGET=x86_64 OS_TARGET=win64 \
      FPC="$FPCROOT/fpc/bin/x86_64-linux/ppcx64" \
      INSTALL_PREFIX="$FPCROOT/fpc" )
  # Join the install layout to the one fpc.cfg searches. The old directory is
  # kept rather than deleted - if this ever goes wrong, the way back is one mv.
  if [ ! -L "$FPC_UNITS" ]; then
    [ -d "$FPC_UNITS" ] && mv "$FPC_UNITS" "$FPC_UNITS.stale-$(date +%Y%m%d)"
    ln -s "$FPC_CROSS_UNITS" "$FPC_UNITS"
  fi
  check_cross_rtl
  say "win64 cross RTL is good"
}

# NO-ACCOUNT FILE HOSTS.
#
# catbox keeps a file until it is deleted and takes 200 MB, which is the only
# one of these that matches "keeps each file". 0x0.st keeps smaller files for
# something close to a year and is the fallback. Neither has folders, so the
# record of what was uploaded lives in dist/uploads.txt here rather than there.
#
# Anyone with the URL can download it. That is the deal with every host of this
# kind, and it is why this is never part of a build.
do_upload() {
  local f="$1" host="${UPLOAD_HOST:-catbox}" url
  [ -n "$f" ] || die "usage: ./build.sh upload <file>"
  [ -f "$f" ] || die "no such file: $f"
  command -v curl >/dev/null || die "curl is needed to upload"
  say "uploading $(basename "$f") ($(du -h "$f" | cut -f1)) to $host"
  case "$host" in
    catbox)
      url="$(curl -sS -F reqtype=fileupload -F "fileToUpload=@$f" \
             https://catbox.moe/user/api.php)" ;;
    0x0)
      url="$(curl -sS -F "file=@$f" https://0x0.st)" ;;
    *) die "unknown UPLOAD_HOST: $host   (catbox, 0x0)" ;;
  esac
  case "$url" in
    http*) ;;
    *) die "upload failed: $url" ;;
  esac
  mkdir -p "$DIST"
  printf '%s  %s  %s\n' "$(date -Is)" "$(basename "$f")" "$url" \
    >> "$DIST/uploads.txt"
  say "$url"
  echo "recorded in dist/uploads.txt"
}

case "${1:-}" in
  nozip)          shift; NOZIP=1 exec "$0" "$@" ;;
  ""|linux|debug) build_linux "$MODE_DEV" ;;
  release)        build_linux "$MODE_SHIP" ;;
  windows|win)    build_windows "$MODE_SHIP" ;;
  windbg)         build_windows "$MODE_DEV" ;;
  all)            build_linux "$MODE_DEV"; build_windows "$MODE_SHIP" ;;
  run)            build_linux "$MODE_DEV"; say "running"; exec "$ROOT/$APP" ;;
  clean)          do_clean ;;
  fresh)          do_clean; build_linux "$MODE_DEV"; build_windows "$MODE_SHIP" ;;
  dist)           do_dist ;;
  crossrtl)       do_crossrtl ;;
  upload)         do_upload "${2:-}" ;;
  *)              sed -n '2,20p' "$0"; exit 1 ;;
esac
