unit uMailOut;

{ Handing a message and some files to whatever email program is set up.

  Nothing here sends anything itself: the message is opened in the person's
  own mail program, addressed by them, sent by them.  On Linux that is
  xdg-email, which knows the desktop's mail program and how to hand it
  attachments.  On Windows it is Simple MAPI, which Outlook and Thunderbird
  both answer, and which puts the compose window up with the files on it.
  When neither works the caller is told, and it still has the files on
  disk to attach by hand. }

{$mode objfpc}{$H+}

interface

{ Open a new message, with the files attached, in the mail program.  Returns
  False with Err when no mail program could be reached. }
function SendByEmail(const Subject, Body: string; const Files: array of string;
  out Err: string): Boolean;

implementation

uses
  SysUtils, Classes
  {$IFDEF WINDOWS}, Windows{$ELSE}, Process{$ENDIF};

{$IFDEF WINDOWS}
type
  { the Simple MAPI records, at their natural alignment: on x64 a pointer
    after a ULONG is padded, and packing these would put every field in the
    wrong place }
  TMapiFileDesc = record
    ulReserved: DWORD;
    flFlags: DWORD;
    nPosition: DWORD;
    lpszPathName: PAnsiChar;
    lpszFileName: PAnsiChar;
    lpFileType: Pointer;
  end;
  PMapiFileDesc = ^TMapiFileDesc;
  TMapiMessage = record
    ulReserved: DWORD;
    lpszSubject: PAnsiChar;
    lpszNoteText: PAnsiChar;
    lpszMessageType: PAnsiChar;
    lpszDateReceived: PAnsiChar;
    lpszConversationID: PAnsiChar;
    flFlags: DWORD;
    lpOriginator: Pointer;
    nRecipCount: DWORD;
    lpRecips: Pointer;
    nFileCount: DWORD;
    lpFiles: PMapiFileDesc;
  end;
  TMapiSendMail = function(Session: PtrUInt; UIParam: PtrUInt;
    var Msg: TMapiMessage; Flags: DWORD; Reserved: DWORD): DWORD; stdcall;

const
  MAPI_LOGON_UI = $00000001;
  MAPI_DIALOG = $00000008;
  SUCCESS_SUCCESS = 0;
  MAPI_E_USER_ABORT = 1;

function SendByEmail(const Subject, Body: string; const Files: array of string;
  out Err: string): Boolean;
var
  Lib: HMODULE;
  Send: TMapiSendMail;
  Msg: TMapiMessage;
  Desc: array of TMapiFileDesc;
  Paths, Names: array of AnsiString;
  SubjA, BodyA: AnsiString;
  I: Integer;
  R: DWORD;
begin
  Result := False;
  Err := '';
  Lib := LoadLibrary('mapi32.dll');
  if Lib = 0 then
  begin
    Err := 'No mail program answers here (mapi32.dll is missing).';
    Exit;
  end;
  try
    Pointer(Send) := GetProcAddress(Lib, 'MAPISendMail');
    if not Assigned(Send) then
    begin
      Err := 'No mail program answers here (MAPISendMail is missing).';
      Exit;
    end;
    SetLength(Desc, Length(Files));
    SetLength(Paths, Length(Files));
    SetLength(Names, Length(Files));
    for I := 0 to High(Files) do
    begin
      Paths[I] := AnsiString(Files[I]);
      Names[I] := AnsiString(ExtractFileName(Files[I]));
      FillChar(Desc[I], SizeOf(Desc[I]), 0);
      Desc[I].nPosition := DWORD(-1);
      Desc[I].lpszPathName := PAnsiChar(Paths[I]);
      Desc[I].lpszFileName := PAnsiChar(Names[I]);
    end;
    SubjA := AnsiString(Subject);
    BodyA := AnsiString(Body);
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.lpszSubject := PAnsiChar(SubjA);
    Msg.lpszNoteText := PAnsiChar(BodyA);
    Msg.nFileCount := Length(Desc);
    if Length(Desc) > 0 then Msg.lpFiles := @Desc[0];
    R := Send(0, 0, Msg, MAPI_DIALOG or MAPI_LOGON_UI, 0);
    Result := R in [SUCCESS_SUCCESS, MAPI_E_USER_ABORT];
    if not Result then
      Err := Format('The mail program would not take it (MAPI error %d).', [R]);
  finally
    FreeLibrary(Lib);
  end;
end;
{$ELSE}
function SendByEmail(const Subject, Body: string; const Files: array of string;
  out Err: string): Boolean;
var
  P: TProcess;
  I: Integer;
  Exe: string;
begin
  Result := False;
  Err := '';
  Exe := ExeSearch('xdg-email', GetEnvironmentVariable('PATH'));
  if Exe = '' then
  begin
    Err := 'xdg-email is not installed, so there is no way to reach the mail program from here.';
    Exit;
  end;
  P := TProcess.Create(nil);
  try
    P.Executable := Exe;
    P.Parameters.Add('--subject');
    P.Parameters.Add(Subject);
    P.Parameters.Add('--body');
    P.Parameters.Add(Body);
    for I := 0 to High(Files) do
    begin
      P.Parameters.Add('--attach');
      P.Parameters.Add(Files[I]);
    end;
    { not waited for: a mail program started fresh may not come back until
      its window closes, and the drawing should not sit frozen meanwhile }
    P.Options := [];
    try
      P.Execute;
      Result := True;
    except
      on E: Exception do Err := 'Could not start xdg-email: ' + E.Message;
    end;
  finally
    P.Free;
  end;
end;
{$ENDIF}

end.
