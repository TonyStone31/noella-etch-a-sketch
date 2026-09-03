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
  are choosing. }
unit uSingle;

{$mode objfpc}{$H+}

interface

{ True when this process now holds the lock.  False when another copy has it,
  in which case the caller should say so and leave. }
function BecomeTheOnlyCopy: Boolean;

implementation

uses
  SysUtils, Classes
  {$IFDEF UNIX}, BaseUnix, Unix{$ENDIF}
  {$IFDEF WINDOWS}, Windows{$ENDIF};

{$IFDEF UNIX}
var
  LockFD: cint = -1;

function BecomeTheOnlyCopy: Boolean;
var
  Path: string;
begin
  Path := GetAppConfigDir(False);
  ForceDirectories(Path);
  Path := IncludeTrailingPathDelimiter(Path) + 'heckers-sketch.lock';
  LockFD := FpOpen(PChar(Path), O_RDWR or O_CREAT, &644);
  if LockFD < 0 then Exit(True);   { cannot lock: better to run than not }
  { A whole-file write lock.  It goes when the process does, however it goes. }
  Result := FpFlock(LockFD, LOCK_EX or LOCK_NB) = 0;
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

function BecomeTheOnlyCopy: Boolean;
begin
  { Local\ rather than Global\ - one copy per signed-in user, not one per
    machine, because two people on the same computer are two people. }
  Mutex := CreateMutex(nil, True, 'Local\HeckersSketchSingleInstance');
  if Mutex = 0 then Exit(True);
  Result := GetLastError <> ERROR_ALREADY_EXISTS;
end;
{$ENDIF}

end.
