{ One copy at a time.

  Two copies open at once share the draft, and sharing the draft is what
  corrupted it and crashed the program - each was writing the other's file
  underneath it.  That particular fault is fixed, but the arrangement is
  wrong at the root: two windows editing one autosaved document will always
  end with one of them quietly losing what it did, and there is no version of
  that which is not a bug waiting to happen.

  So: one.  It is a lock held for as long as the program runs and released by
  the operating system whether it exits tidily or is killed, which matters -
  a lock file that has to be deleted on the way out is a lock file that gets
  left behind by the crash it was supposed to help with.

  --multi opens another anyway, for anyone who wants two and knows what they
  are choosing.

  An update is the one time a second copy is started on purpose while the
  first is still alive: the running program puts the new file in place, starts
  it, and then exits.  The new one arrived, found the lock held by the copy
  that had just launched it, and refused - so every update stopped the program
  and never started it again.

  It waits instead of refusing, which is not the same as ignoring the lock.
  Two copies sharing a draft is the thing this unit exists to prevent, and it
  still cannot happen: the new copy runs only once the old one has actually
  let go. }
unit uSingle;

{$mode objfpc}{$H+}

interface

{ True when this process now holds the lock.  False when another copy has it,
  in which case the caller should say so and leave.

  WaitSecs is how long to keep trying for.  Zero - the default - is the
  ordinary case: somebody has double clicked the icon twice and should be told
  so at once rather than made to watch a window that might never come.  An
  update passes a few seconds, because there a copy is known to be on its way
  out. }
function BecomeTheOnlyCopy(WaitSecs: Integer = 0): Boolean;
procedure DropInheritedUpdateLock;

implementation

uses
  SysUtils, Classes, uPaths
  {$IFDEF UNIX}, BaseUnix, Unix{$ENDIF}
  {$IFDEF WINDOWS}, Windows{$ENDIF};

{$IFDEF UNIX}
const
  CLOSE_ON_EXEC = 1;

var
  LockFD: cint = -1;

procedure DropInheritedUpdateLock;
var
  I: Integer;
  LockInfo, FDInfo: TStat;
begin
  if FpStat(AppDataDir + 'heckers-sketch.lock', LockInfo) <> 0 then Exit;
  for I := 3 to 1024 do
    if (FpFStat(I, FDInfo) = 0) and
       (FDInfo.st_dev = LockInfo.st_dev) and
       (FDInfo.st_ino = LockInfo.st_ino) then
      FpClose(I);
end;

function BecomeTheOnlyCopy(WaitSecs: Integer): Boolean;
var
  Path: string;
  Give: QWord;
begin
  Path := AppDataDir + 'heckers-sketch.lock';
  LockFD := FpOpen(PChar(Path), O_RDWR or O_CREAT, &644);
  if LockFD < 0 then Exit(True);   { cannot lock: better to run than not }
  FpFcntl(LockFD, F_SETFD, CLOSE_ON_EXEC);
  { A whole-file write lock.  It goes when the process does, however it goes. }
  Give := GetTickCount64 + QWord(WaitSecs) * 1000;
  repeat
    Result := FpFlock(LockFD, LOCK_EX or LOCK_NB) = 0;
    if Result or (GetTickCount64 >= Give) then Break;
    Sleep(100);
  until False;
  if not Result then
  begin
    FpClose(LockFD);
    LockFD := -1;
  end;
end;
{$ENDIF}

{$IFDEF WINDOWS}
var
  Mutex: HANDLE = 0;

procedure DropInheritedUpdateLock;
begin
end;

function BecomeTheOnlyCopy(WaitSecs: Integer): Boolean;
var
  R: DWORD;
begin
  { Local\ rather than Global\ - one copy per signed-in user, not one per
    machine, because two people on the same computer are two people. }
  { Created without asking to own it, then owned by waiting.  Asking at
    creation and reading ERROR_ALREADY_EXISTS can only ever answer "somebody
    has it"; waiting can also answer "somebody had it and has now gone", which
    is exactly what happens when the copy being replaced exits. }
  Mutex := CreateMutex(nil, False, 'Local\HeckersSketchSingleInstance');
  if Mutex = 0 then Exit(True);   { cannot lock: better to run than not }
  R := WaitForSingleObject(Mutex, DWORD(WaitSecs) * 1000);
  { WAIT_ABANDONED is the owner having died or exited without releasing it.
    That is the normal way this program lets go - there is nothing to tidy up
    behind it, so it counts as ours. }
  Result := (R = WAIT_OBJECT_0) or (R = WAIT_ABANDONED);
  if not Result then
  begin
    CloseHandle(Mutex);
    Mutex := 0;
  end;
end;
{$ENDIF}

end.
