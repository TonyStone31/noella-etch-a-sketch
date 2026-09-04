unit uNet;

{ One way out to the network, with a different floor under it on each system.

  Linux gets OpenSSL, which is there because the distribution put it there.
  Windows gets WinHTTP, which is Windows' own, and that is not a detail of
  taste: Windows ships no OpenSSL at all.  Asking for it there was asking for
  something that does not exist, so every update check and every bug report
  on that machine failed and could never have done anything else.

  Shipping the OpenSSL DLLs beside the program would also have worked, and it
  was the worse trade.  The system's own stack validates against the
  certificate store the machine already trusts and already keeps current, it
  follows the proxy the machine is already configured for - which is the
  difference between working and not working on a company network - and it is
  patched by whoever patches the machine.  The alternative was five megabytes
  that we would from then on owe security updates on, in a program whose
  whole delivery story is one file you can copy onto a stick. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

{ A GET, with the body written into Dest.  Status is the HTTP code when the
  exchange got far enough to have one.  Accept may be empty. }
function NetGet(const URL, Accept: string; Dest: TStream;
  out Status: Integer; out Err: string): Boolean;

{ The same, for an answer small enough to want as a string. }
function NetGetText(const URL, Accept: string; out Body, Err: string): Boolean;

{ A POST of Data.  The reply is read and dropped - every post this program
  makes is an upload, and all we want back is the code. }
function NetPost(const URL: string; Data: TStream; const ContentType: string;
  out Status: Integer; out Err: string): Boolean;

{ Which of the two is underneath, so a report can say. }
function NetBackend: string;

const
  USER_AGENT = 'heckers-sketch';

implementation

uses
  {$IFDEF WINDOWS}
  Windows
  {$ELSE}
  fphttpclient, opensslsockets
  {$ENDIF};

{ Host and path out of a URL.  WinHTTP has WinHttpCrackUrl for this, which
  wants a struct with eleven fields filled in exactly right; the four things
  we actually need are easier to read out by hand than to describe to it. }
function SplitURL(const URL: string; out Secure: Boolean; out Host: string;
  out Port: Word; out Path: string): Boolean;
var
  S: string;
  I: Integer;
begin
  Result := False;
  Secure := True;
  Port := 0;
  Host := '';
  Path := '/';
  S := URL;
  if CompareText(Copy(S, 1, 8), 'https://') = 0 then
  begin
    Secure := True;
    Delete(S, 1, 8);
  end
  else if CompareText(Copy(S, 1, 7), 'http://') = 0 then
  begin
    Secure := False;
    Delete(S, 1, 7);
  end
  else
    Exit;
  I := Pos('/', S);
  if I > 0 then
  begin
    Path := Copy(S, I, Length(S));
    S := Copy(S, 1, I - 1);
  end;
  I := Pos(':', S);
  if I > 0 then
  begin
    Port := StrToIntDef(Copy(S, I + 1, Length(S)), 0);
    S := Copy(S, 1, I - 1);
  end;
  Host := S;
  if Port = 0 then
  begin
    if Secure then Port := 443 else Port := 80;
  end;
  Result := Host <> '';
end;

{$IFDEF WINDOWS}

const
  WINHTTP = 'winhttp.dll';

  WINHTTP_ACCESS_TYPE_DEFAULT_PROXY   = 0;
  WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY = 4;   // Windows 8.1 and later
  WINHTTP_FLAG_SECURE                 = $00800000;
  WINHTTP_QUERY_STATUS_CODE           = 19;
  WINHTTP_QUERY_FLAG_NUMBER           = $20000000;

type
  HINTERNET = Pointer;

function WinHttpOpen(pszAgentW: PWideChar; dwAccessType: DWORD;
  pszProxyW, pszProxyBypassW: PWideChar; dwFlags: DWORD): HINTERNET; stdcall;
  external WINHTTP name 'WinHttpOpen';
function WinHttpConnect(hSession: HINTERNET; pswzServerName: PWideChar;
  nServerPort: Word; dwReserved: DWORD): HINTERNET; stdcall;
  external WINHTTP name 'WinHttpConnect';
function WinHttpOpenRequest(hConnect: HINTERNET;
  pwszVerb, pwszObjectName, pwszVersion, pwszReferrer: PWideChar;
  ppwszAcceptTypes: Pointer; dwFlags: DWORD): HINTERNET; stdcall;
  external WINHTTP name 'WinHttpOpenRequest';
function WinHttpSendRequest(hRequest: HINTERNET; pwszHeaders: PWideChar;
  dwHeadersLength: DWORD; lpOptional: Pointer;
  dwOptionalLength, dwTotalLength: DWORD; dwContext: PtrUInt): BOOL; stdcall;
  external WINHTTP name 'WinHttpSendRequest';
function WinHttpReceiveResponse(hRequest: HINTERNET;
  lpReserved: Pointer): BOOL; stdcall;
  external WINHTTP name 'WinHttpReceiveResponse';
function WinHttpQueryHeaders(hRequest: HINTERNET; dwInfoLevel: DWORD;
  pwszName: PWideChar; lpBuffer: Pointer; lpdwBufferLength: PDWORD;
  lpdwIndex: PDWORD): BOOL; stdcall;
  external WINHTTP name 'WinHttpQueryHeaders';
function WinHttpQueryDataAvailable(hRequest: HINTERNET;
  lpdwNumberOfBytesAvailable: PDWORD): BOOL; stdcall;
  external WINHTTP name 'WinHttpQueryDataAvailable';
function WinHttpReadData(hRequest: HINTERNET; lpBuffer: Pointer;
  dwNumberOfBytesToRead: DWORD; lpdwNumberOfBytesRead: PDWORD): BOOL; stdcall;
  external WINHTTP name 'WinHttpReadData';
function WinHttpSetTimeouts(hInternet: HINTERNET;
  nResolveTimeout, nConnectTimeout, nSendTimeout,
  nReceiveTimeout: Integer): BOOL; stdcall;
  external WINHTTP name 'WinHttpSetTimeouts';
function WinHttpCloseHandle(hInternet: HINTERNET): BOOL; stdcall;
  external WINHTTP name 'WinHttpCloseHandle';

function NetBackend: string;
begin
  Result := 'winhttp';
end;

{ WinHTTP's own numbers, which mean nothing to anybody, turned into the four
  or five things that actually go wrong. }
function WinHttpWhy(Code: DWORD): string;
begin
  case Code of
    12002: Result := 'the connection timed out';
    12007: Result := 'that address could not be looked up';
    12029: Result := 'the connection was refused';
    12030,
    12031: Result := 'the connection was closed part way';
    12057: Result := 'the certificate could not be checked';
    12157,
    12175: Result := 'the secure connection could not be set up';
    12186: Result := 'a proxy is in the way and would not let this through';
  else
    Result := 'the network said no (' + IntToStr(Code) + ')';
  end;
end;

{ One exchange, GET or POST.  Everything is opened, used and closed inside
  here, so there is no state between calls and nothing to leak if a step
  fails part way down. }
function Exchange(const Verb, URL, Headers: string; Body: TStream;
  Dest: TStream; RecvMs: Integer; out Status: Integer;
  out Err: string): Boolean;
var
  Secure: Boolean;
  Host, Path: string;
  Port: Word;
  Sess, Conn, Req: HINTERNET;
  Flags, Avail, Got, Code, CodeLen: DWORD;
  Buf: array[0..16383] of Byte;
  Payload: TBytes;
  PayloadPtr: Pointer;
  WHeaders: UnicodeString;
  HdrPtr: PWideChar;
begin
  Result := False;
  Status := 0;
  Err := '';
  SetLength(Payload, 0);

  if not SplitURL(URL, Secure, Host, Port, Path) then
  begin
    Err := 'that address could not be read';
    Exit;
  end;

  { Automatic proxy detection is what a desktop program wants and what every
    modern one uses; on anything older than 8.1 the call fails and the
    machine-wide setting is used instead. }
  Sess := WinHttpOpen(PWideChar(UnicodeString(USER_AGENT)),
    WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY, nil, nil, 0);
  if Sess = nil then
    Sess := WinHttpOpen(PWideChar(UnicodeString(USER_AGENT)),
      WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, nil, nil, 0);
  if Sess = nil then
  begin
    Err := WinHttpWhy(GetLastError);
    Exit;
  end;

  Conn := nil;
  Req := nil;
  try
    WinHttpSetTimeouts(Sess, 8000, 8000, 20000, RecvMs);

    Conn := WinHttpConnect(Sess, PWideChar(UnicodeString(Host)), Port, 0);
    if Conn = nil then
    begin
      Err := WinHttpWhy(GetLastError);
      Exit;
    end;

    Flags := 0;
    if Secure then Flags := WINHTTP_FLAG_SECURE;
    Req := WinHttpOpenRequest(Conn, PWideChar(UnicodeString(Verb)),
      PWideChar(UnicodeString(Path)), nil, nil, nil, Flags);
    if Req = nil then
    begin
      Err := WinHttpWhy(GetLastError);
      Exit;
    end;

    { Redirects are followed for us, and WinHTTP will not follow one from
      https down to plain http unless it is told to.  It is not told to. }

    if Body <> nil then
    begin
      Body.Position := 0;
      SetLength(Payload, Body.Size);
      if Length(Payload) > 0 then Body.ReadBuffer(Payload[0], Length(Payload));
    end;
    if Length(Payload) > 0 then PayloadPtr := @Payload[0] else PayloadPtr := nil;

    WHeaders := UnicodeString(Headers);
    if WHeaders <> '' then HdrPtr := PWideChar(WHeaders) else HdrPtr := nil;

    if not WinHttpSendRequest(Req, HdrPtr, Length(WHeaders), PayloadPtr,
         Length(Payload), Length(Payload), 0) then
    begin
      Err := WinHttpWhy(GetLastError);
      Exit;
    end;

    if not WinHttpReceiveResponse(Req, nil) then
    begin
      Err := WinHttpWhy(GetLastError);
      Exit;
    end;

    Code := 0;
    CodeLen := SizeOf(Code);
    if WinHttpQueryHeaders(Req,
         WINHTTP_QUERY_STATUS_CODE or WINHTTP_QUERY_FLAG_NUMBER,
         nil, @Code, @CodeLen, nil) then
      Status := Integer(Code);

    repeat
      Avail := 0;
      if not WinHttpQueryDataAvailable(Req, @Avail) then
      begin
        Err := WinHttpWhy(GetLastError);
        Exit;
      end;
      if Avail = 0 then Break;
      if Avail > DWORD(SizeOf(Buf)) then Avail := SizeOf(Buf);
      Got := 0;
      if not WinHttpReadData(Req, @Buf[0], Avail, @Got) then
      begin
        Err := WinHttpWhy(GetLastError);
        Exit;
      end;
      if Got = 0 then Break;
      if Dest <> nil then Dest.WriteBuffer(Buf[0], Got);
    until False;

    Result := (Status >= 200) and (Status < 300);
    if not Result and (Err = '') then
      Err := 'the server answered ' + IntToStr(Status);
  finally
    if Req <> nil then WinHttpCloseHandle(Req);
    if Conn <> nil then WinHttpCloseHandle(Conn);
    WinHttpCloseHandle(Sess);
  end;
end;

function NetGet(const URL, Accept: string; Dest: TStream;
  out Status: Integer; out Err: string): Boolean;
var
  H: string;
begin
  H := '';
  if Accept <> '' then H := 'Accept: ' + Accept;
  Result := Exchange('GET', URL, H, nil, Dest, 60000, Status, Err);
end;

function NetPost(const URL: string; Data: TStream; const ContentType: string;
  out Status: Integer; out Err: string): Boolean;
begin
  Result := Exchange('POST', URL, 'Content-Type: ' + ContentType, Data, nil,
    60000, Status, Err);
end;

{$ELSE}

function NetBackend: string;
begin
  Result := 'openssl';
end;

function NetGet(const URL, Accept: string; Dest: TStream;
  out Status: Integer; out Err: string): Boolean;
var
  C: TFPHTTPClient;
begin
  Result := False;
  Status := 0;
  Err := '';
  C := TFPHTTPClient.Create(nil);
  try
    C.AllowRedirect := True;
    C.ConnectTimeout := 8000;
    C.IOTimeout := 60000;
    C.AddHeader('User-Agent', USER_AGENT);
    if Accept <> '' then C.AddHeader('Accept', Accept);
    try
      C.Get(URL, Dest);
      Status := C.ResponseStatusCode;
      Result := (Status >= 200) and (Status < 300);
      if not Result then Err := 'the server answered ' + IntToStr(Status);
    except
      on E: Exception do
      begin
        Status := C.ResponseStatusCode;
        Err := E.Message;
      end;
    end;
  finally
    C.Free;
  end;
end;

function NetPost(const URL: string; Data: TStream; const ContentType: string;
  out Status: Integer; out Err: string): Boolean;
var
  C: TFPHTTPClient;
  Sink: TStringStream;
begin
  Result := False;
  Status := 0;
  Err := '';
  C := TFPHTTPClient.Create(nil);
  Sink := TStringStream.Create('');
  try
    Data.Position := 0;
    C.AllowRedirect := True;
    C.ConnectTimeout := 8000;
    C.IOTimeout := 60000;
    C.AddHeader('User-Agent', USER_AGENT);
    C.AddHeader('Content-Type', ContentType);
    C.RequestBody := Data;
    try
      C.Post(URL, Sink);
      Status := C.ResponseStatusCode;
      Result := (Status >= 200) and (Status < 300);
      if not Result then Err := 'the server answered ' + IntToStr(Status);
    except
      on E: Exception do
      begin
        Status := C.ResponseStatusCode;
        Err := E.Message;
      end;
    end;
  finally
    Sink.Free;
    C.Free;
  end;
end;

{$ENDIF}

function NetGetText(const URL, Accept: string; out Body, Err: string): Boolean;
var
  S: TStringStream;
  Status: Integer;
begin
  Body := '';
  S := TStringStream.Create('');
  try
    Result := NetGet(URL, Accept, S, Status, Err);
    Body := S.DataString;
  finally
    S.Free;
  end;
end;

end.
