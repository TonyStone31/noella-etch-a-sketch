#!/usr/bin/env bash
# Every command the list offers is a command the program answers to.
#
# The autocomplete list in uMain is a hand-written table, and the dispatcher
# in RunCommand is a hand-written chain of comparisons.  Nothing ties them
# together, so a command can be added to one and not the other: offer a name
# that does nothing, or hide a name that works.  This reads both out of the
# source and says which names are in the list but not in the chain.
#
# It cannot go the other way round.  The chain is full of aliases and
# debugging words that are deliberately not offered, and a list that had to
# hold all of them would be worse than no list.
set -u
cd "$(dirname "$0")/.."

python3 - <<'PY'
import io, re, sys

src = io.open('uMain.pas', encoding='utf-8', errors='replace').read()

# the table: from its declaration to the closing of the array
m = re.search(r"CMD_LIST: array\[0\.\.(\d+)\] of TCmdItem = \(", src)
if not m:
    print('CMD_LIST not found - has it been renamed?'); sys.exit(1)
# the terminator belongs to the last row, so take it with it
end = src.index('Arg: False));', m.end()) + len('Arg: False))')
table = src[m.end():end]
names = re.findall(r"\(Name: '([a-z0-9]+)'", table)

bad = 0
bound = int(m.group(1))
if bound != len(names) - 1:
    print('CMD_LIST says [0..%d] but holds %d entries' % (bound, len(names)))
    bad = 1

if names != sorted(names):
    for a, b in zip(names, sorted(names)):
        if a != b:
            print('CMD_LIST is out of alphabetical order at %r' % a)
            break
    bad = 1

# the dispatcher: every quoted word it compares W against
i = src.index('function TMainForm.RunCommand')
tail = src[i + 10:]
nxt = re.search(r"\n(?:function|procedure) TMainForm\.", tail)
body = tail[:nxt.start()] if nxt else tail
known = set(re.findall(r"W = '([a-z0-9]+)'", body))
# a few are dispatched by prefix or by their own routine rather than by a
# plain comparison, so the source is read for those separately
known |= set(re.findall(r"Cmd = '([a-z0-9]+)'", body))
known |= set(re.findall(r"Copy\(W, 1, \d+\) = '([a-z0-9]+)'", body))

# the examples: one per row that wants something after it, each one a real
# use of that command.  A Pascal string doubles its apostrophes, so 4''6"
# in the source is 4'6" on the screen - undo that before reading it.
rows = re.findall(r"\(Name: '([a-z0-9]+)';.*?Arg: (True|False);?"
                  r"(?:\s*Eg:\s*'((?:[^']|'')*)')?\s*\)", table, re.S)
if len(rows) != len(names):
    print('could not read every row of CMD_LIST (%d of %d)' % (len(rows), len(names)))
    bad = 1
for nm, arg, eg in rows:
    eg = (eg or '').replace("''", "'")
    if arg == 'True' and not eg:
        print('/%s wants something after it and has no example' % nm)
        bad = 1
    if eg and not eg.startswith('/' + nm + ' '):
        print('/%s has the example %r, which is not that command with '
              'something after it' % (nm, eg))
        bad = 1

missing = [n for n in names if n not in known]
if missing:
    print('offered by the list, answered by nothing: ' + ', '.join(missing))
    bad = 1

# A word compared twice is a word answered once.  The chain runs top to
# bottom and the first branch that matches wins, so a later branch comparing
# the same word is unreachable - and if that later branch is the one the list
# is advertising, the command does something other than what it says.
#
# /new did exactly that: it was an alias on the /whatsnew branch and the
# branch that makes a new sheet sat below it, so /new opened the release
# notes and the list said "a new sheet".
seen = {}
for mm in re.finditer(r"W = '([a-z0-9]+)'", body):
    w = mm.group(1)
    if w in seen:
        print("'%s' is compared twice in RunCommand - the second is dead code, "
              "and the first is what /%s actually does" % (w, w))
        bad = 1
    seen[w] = 1

print('%d commands offered, %d words the dispatcher knows' % (len(names), len(known)))
print('command list ' + ('FAILED' if bad else 'ok'))
sys.exit(bad)
PY
