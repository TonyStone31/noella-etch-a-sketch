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
# Everything in one zip: Windows and Linux, each built twice.  The fast build
# is what you run; the checked one has the range and overflow tests compiled
# in and prints a heap report when it closes, which is noise unless you are
# hunting something, so it lives in a folder of its own.
pack_all() {
  [ "$NOZIP" = "1" ] && return 0
  command -v zip >/dev/null || { say "no zip command - skipping"; return 0; }
  local s zipname tmp
  s="$(stamp)"
  mkdir -p "$DIST"
  zipname="$DIST/heckers-sketch-$s.zip"
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/checked"

  [ -f "$ROOT/$APP.exe" ] && cp "$ROOT/$APP.exe" "$tmp/heckers-sketch.exe"
  [ -f "$ROOT/$APP" ]     && cp "$ROOT/$APP"     "$tmp/heckers-sketch-linux"
  [ -f "$DIST/dbg/$APP.exe" ] && cp "$DIST/dbg/$APP.exe" "$tmp/checked/heckers-sketch.exe"
  [ -f "$DIST/dbg/$APP" ]     && cp "$DIST/dbg/$APP"     "$tmp/checked/heckers-sketch-linux"

  cat > "$tmp/README.txt" <<TXT
Heckers Sketch - $s

No installer, no DLLs.  Unzip and run.

  heckers-sketch.exe        Windows
  heckers-sketch-linux      Linux
  checked/                  the same two, built with every check switched on

Run the ones in the top folder.  The checked build is slower, and prints a
heap report to the console when it closes - that is normal for it, not a
fault.  It is there for when something goes wrong: it turns a silent wrong
answer into a message naming the line it came from, so if you hit a bug worth
chasing, reproduce it with that one and send what it says.

Windows will probably warn that the publisher is unknown - the binary is not
code signed.  More info -> Run anyway.

Either build writes heckers-sketch-crash.txt next to itself if it falls over.
TXT
  ( cd "$tmp" && zip -q -9 -r "$zipname" . )
  rm -rf "$tmp"
  if [ ! -s "$zipname" ]; then
    say "the zip came out empty - not uploading"
    return 1
  fi
  say "zipped $(du -h "$zipname" | cut -f1) -> $(basename "$zipname")"
  say "$(unzip -l "$zipname" | tail -n +4 | head -6)"
  # A GitHub release attaches the zip itself, so there is nothing to gain from
  # a paste-site upload on that path.
  [ "${NOUPLOAD:-0}" = "1" ] || do_upload "$zipname"
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
  gen_whatsnew
}

# WHATS_NEW.md is the one copy of the release notes.  The program shows it
# after an update, so it is turned into a Pascal string constant before every
# build - the words on screen are the words in the file, and nobody keeps two
# lists in step by hand.  The generated file is committed, so a build from the
# IDE without this script still has one; it just may be a build behind.
gen_whatsnew() {
  python3 - "$ROOT/WHATS_NEW.md" "$ROOT/whatsnew.inc" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
lines = open(src, encoding='utf-8').read().split('\n')
out = ['{ Generated from WHATS_NEW.md by build.sh - edit that, not this. }',
       'const', '  WHATS_NEW_MD =']
for i, l in enumerate(lines):
    q = "'" + l.replace("'", "''") + "'"
    sep = ' + LineEnding +' if i < len(lines) - 1 else ';'
    out.append('    ' + q + sep)
open(dst, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
PY
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
  #
  # ws2_32 and wsock32 are Winsock, which the update check needs; they have
  # shipped with every Windows since 98 and are not something to carry.
  if command -v objdump >/dev/null; then
    local extra
    extra="$(objdump -p "$ROOT/$APP.exe" | sed -n 's/.*DLL Name: //p' | sort -u |
      grep -viE '^(advapi32|comctl32|comdlg32|gdi32|kernel32|ole32|oleaut32|shell32|user32|version|winmm|winspool|ws2_32|wsock32|crypt32|iphlpapi)\.(dll|drv)$' || true)"
    if [ -n "$extra" ]; then
      say "WARNING - this build needs DLLs that are not part of Windows:"
      printf '   %s\n' $extra
    fi
  fi
  [ "$NOZIP" = "1" ] || pack_all
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
      # A zip with four binaries in it is twenty megabytes, and the upload
      # times out often enough to be worth retrying rather than failing the
      # build over.
      local try
      for try in 1 2 3; do
        url="$(curl -sS --connect-timeout 20 --max-time 900 \
               -F reqtype=fileupload -F "fileToUpload=@$f" \
               https://catbox.moe/user/api.php)" || url=""
        case "$url" in http*) break ;; esac
        say "upload attempt $try did not take - trying again"
        sleep 3
      done ;;
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

# Build all four and put them in one zip: the fast pair to run, and the
# checked pair beside them.  The checked ones are stashed under dist/dbg
# first, because both modes write to the same place in the tree.
# Keep the debug symbols for each target, under its own name.  The project
# writes them to etchasketch.dbg whatever it is building, so the Windows
# build was overwriting the Linux one - and a crash report from the Linux
# build then symbolized against Windows symbols, which is to say not at all.
save_syms() {
  [ -f "$ROOT/$APP.dbg" ] || return 0
  mkdir -p "$DIST/syms"
  cp "$ROOT/$APP.dbg" "$DIST/syms/$APP-$1.dbg"
  # Then take the symbols out of the binary people download.  They are kept
  # here, which is what lets a crash report's addresses be turned back into
  # line numbers later - but they double the size of the file and nobody
  # downloading it has any use for them.
  # Every branch ends in "or nothing", because the script runs under set -e
  # and a stripper that is not installed must not take the release down with
  # it - the symbols are already saved by this point, which was the part
  # that mattered.
  case "$1" in
    *release)
      case "$2" in
        win)  x86_64-w64-mingw32-strip --strip-debug "$ROOT/$APP.exe" \
                2>/dev/null || true ;;
        *)    strip --strip-debug "$ROOT/$APP" 2>/dev/null || true ;;
      esac
      ;;
  esac
  return 0
}

do_ship() {
  mkdir -p "$DIST/dbg"
  rm -f "$DIST/dbg/$APP" "$DIST/dbg/$APP.exe"
  # Both modes write to the same place in the tree, so the checked pair is
  # built first and stashed.  NOZIP throughout - the packing happens once, at
  # the end, when all four exist.
  NOZIP=1 build_linux   "$MODE_DEV"
  save_syms linux-checked
  cp "$ROOT/$APP"     "$DIST/dbg/$APP"
  NOZIP=1 build_windows "$MODE_DEV"
  cp "$ROOT/$APP.exe" "$DIST/dbg/$APP.exe"
  NOZIP=1 build_linux   "$MODE_SHIP"
  save_syms linux-release lin
  NOZIP=1 build_windows "$MODE_SHIP"
  save_syms win64-release win

  local f miss=0
  for f in "$ROOT/$APP" "$ROOT/$APP.exe" "$DIST/dbg/$APP" "$DIST/dbg/$APP.exe"; do
    [ -s "$f" ] || { say "MISSING: $f"; miss=1; }
  done
  [ "$miss" = 0 ] || die "not all four builds came out - not packing a short zip"
  pack_all
}

# Publish a release on GitHub.  Builds all four binaries, pushes whatever is
# committed, tags it, and attaches the binaries and the zip to a release so
# they can be downloaded from the repository page.
#
#   ./build.sh github            tag as vYYYY.MM.DD (or .1, .2 if taken)
#   ./build.sh github v1.0       tag explicitly
do_github() {
  local tag="${1:-}"
  command -v gh >/dev/null 2>&1 || die \
    "no gh command.  Install the GitHub CLI and run 'gh auth login' first."
  gh auth status >/dev/null 2>&1 || die \
    "gh is not logged in.  Run 'gh auth login' first."

  [ -z "$(git -C "$ROOT" status --porcelain)" ] || die \
    "working tree is dirty - commit or stash before releasing"

  # Date-stamped tag, with a suffix if that date already went out today.
  # The tags have to come down from the remote first: gh creates the tag on
  # GitHub's side, so a release made from here leaves nothing local to see
  # and the next one picks the same name and is refused.
  git -C "$ROOT" fetch --tags --quiet origin 2>/dev/null || true
  if [ -z "$tag" ]; then
    local base n
    base="v$(date +%Y.%m.%d)"
    tag="$base"; n=1
    while git -C "$ROOT" rev-parse -q --verify "refs/tags/$tag" >/dev/null; do
      tag="$base.$n"; n=$((n + 1))
    done
  fi

  # Stamp the version into the binary so it knows what it is, then put the
  # file back afterwards - the tree has to stay clean for the next release.
  # On a trap as well as on the way out, or a release that falls over half
  # way leaves the tree dirty and the next one refuses to start.
  trap 'git -C "$ROOT" checkout -- version.inc 2>/dev/null || true' RETURN
  printf '%s\n' \
    '{ Written by build.sh at release time.  A hand-built copy keeps the' \
    '  dev value, which is older than any real tag so it never claims to be' \
    '  up to date when it is not. }' \
    'const' \
    "  APP_VERSION = '$tag';" > "$ROOT/version.inc"

  NOUPLOAD=1 do_ship

  local s zipfile stage
  s="$(stamp)"
  zipfile="$DIST/heckers-sketch-$s.zip"
  [ -s "$zipfile" ] || die "no zip at $zipfile"

  # gh uploads by basename, so stage the binaries under the names people
  # should see on the release page.
  stage="$(mktemp -d)"
  cp "$ROOT/$APP.exe"         "$stage/heckers-sketch.exe"
  cp "$ROOT/$APP"             "$stage/heckers-sketch-linux"
  cp "$DIST/dbg/$APP.exe"     "$stage/heckers-sketch-checked.exe"
  cp "$DIST/dbg/$APP"         "$stage/heckers-sketch-linux-checked"
  cp "$zipfile"               "$stage/heckers-sketch-all-builds.zip"

  ( cd "$stage" && sha256sum * > SHA256SUMS ) 2>/dev/null || \
    ( cd "$stage" && shasum -a 256 * > SHA256SUMS )

  git -C "$ROOT" checkout -- version.inc 2>/dev/null || true

  # The bin-rotating Action commits to main on its own schedule, so origin
  # can easily have moved since this branch was last level with it.  Catch up
  # first rather than failing the release over somebody else's commit.
  say "catching up with origin"
  git -C "$ROOT" pull --rebase --quiet origin main || \
    die "could not rebase onto origin/main - sort that out and try again"

  say "pushing $(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
  git -C "$ROOT" push origin HEAD || die "push failed"

  # Release notes: the commit subjects since the last release.
  local prev notes
  prev="$(git -C "$ROOT" describe --tags --abbrev=0 2>/dev/null || true)"
  notes="$(mktemp)"
  {
    echo "No installer and nothing to set up - download, and run it."
    echo
    echo "| File | For |"
    echo "| --- | --- |"
    echo "| \`heckers-sketch.exe\` | Windows |"
    echo "| \`heckers-sketch-linux\` | Linux (\`chmod +x\` it first) |"
    echo "| \`*-checked\` | the same builds with range, overflow and heap checking on - slower, but they name the line when something goes wrong |"
    echo "| \`heckers-sketch-all-builds.zip\` | all four together |"
    echo
    echo "Windows will warn that the publisher is unknown; the binary is not"
    echo "code signed.  More info -> Run anyway."
    echo
    echo "## What changed"
    echo
    if [ -n "$prev" ]; then
      git -C "$ROOT" log --no-merges --format='* %s' "$prev..HEAD"
    else
      git -C "$ROOT" log --no-merges --format='* %s' -20
    fi
  } > "$notes"

  say "tagging $tag and creating the release"
  gh release create "$tag" \
    --repo "$(git -C "$ROOT" remote get-url origin | sed -E 's#.*github\.com[:/]##; s#\.git$##')" \
    --title "Heckers Sketch $tag" \
    --notes-file "$notes" \
    "$stage"/* || die "gh release create failed"

  rm -rf "$stage" "$notes"
  # The notes written under "Next release" were this release.  Name them, so
  # the next build knows they are behind it and an update from here shows
  # only what comes after.  One commit, by this script, right after the tag.
  if grep -q '^## Next release$' "$ROOT/WHATS_NEW.md"; then
    sed -i "s/^## Next release\$/## $tag/" "$ROOT/WHATS_NEW.md"
    gen_whatsnew
    git -C "$ROOT" add WHATS_NEW.md whatsnew.inc
    git -C "$ROOT" commit -q -m "Release notes: $tag" && \
      git -C "$ROOT" push -q origin HEAD || say "WARNING - could not commit the renamed release notes"
  fi

  say "released $tag"
}

case "${1:-}" in
  nozip)          shift; NOZIP=1 exec "$0" "$@" ;;
  ""|linux|debug) build_linux "$MODE_DEV" ;;
  release)        build_linux "$MODE_SHIP" ;;
  windows|win)    build_windows "$MODE_SHIP" ;;
  windbg)         build_windows "$MODE_DEV" ;;
  all)            build_linux "$MODE_DEV"; build_windows "$MODE_SHIP" ;;
  ship)           do_ship ;;
  run)            build_linux "$MODE_DEV"; say "running"; exec "$ROOT/$APP" ;;
  clean)          do_clean ;;
  fresh)          do_clean; build_linux "$MODE_DEV"; build_windows "$MODE_SHIP" ;;
  dist)           do_dist ;;
  crossrtl)       do_crossrtl ;;
  upload)         do_upload "${2:-}" ;;
  github|gh)      do_github "${2:-}" ;;
  *)              sed -n '2,20p' "$0"; exit 1 ;;
esac
