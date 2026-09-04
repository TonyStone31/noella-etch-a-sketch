{ Sending a report somewhere, without a server of our own.

  GitHub is the rendezvous and Filebin is the postbox.  A GitHub Action
  makes a fresh Filebin bin every so often and writes where it is into a
  file in the repository; the program only ever hardcodes the address of
  that file.  So the bin can expire, be locked, or be thrown away and
  replaced, and nothing has to be rebuilt or reinstalled - the next report
  simply reads where to go.

  Never hardcode a bin.  That is the whole design: the one fixed address is
  the config on GitHub, and everything else is looked up.

  Nothing in here may take the program down or get in its way.  A report
  that cannot be sent is a report that cannot be sent; it is not an error
  worth interrupting somebody's work over, and it is certainly not worth a
  crash - these are the paths that run *because* something already went
  wrong. }
unit uReport;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

const
  { The one address that is compiled in.  Everything else is looked up. }
  ENDPOINT_URL =
    'https://raw.githubusercontent.com/TonyStone31/noella-etch-a-sketch/' +
    'main/docs/bug-report-endpoint.json';

type
  { Where reports go at the moment.  Read from GitHub, remembered locally so
    a report can still be sent when GitHub cannot be reached but the bin is
    still alive. }
  TEndpoint = record
    UploadBase: string;   { https://filebin.net/<bin> }
    Bin: string;
    Updated: string;
    FromCache: Boolean;
  end;

{ Ask GitHub where reports go.  False, with a reason, if it cannot be
  reached or says something unreadable. }
function FetchEndpoint(out E: TEndpoint; out Err: string): Boolean;

{ The last endpoint that worked, or a blank one. }
function CachedEndpoint(out E: TEndpoint): Boolean;
procedure RememberEndpoint(const E: TEndpoint);

{ Send Body as FileName.

  Tries the cached endpoint first when there is one, since that is one
  fewer request and usually right.  A refusal that means the bin has gone -
  expired, locked, full, never existed - is worth exactly one more attempt
  after asking GitHub again, because that is precisely the case the whole
  arrangement exists to handle.  Anything else is taken at its word. }
function SendReport(const FileName, Body: string; out Err: string): Boolean;

{ The same, for something that is not text - a picture of the screen. }
function SendBinary(const FileName: string; Data: TStream;
  const ContentType: string; out Err: string): Boolean;

{ A name no other report will have. }
function UniqueReportName(const Prefix, Version: string): string;

implementation

uses
  fphttpclient, opensslsockets, fpjson, jsonparser, IniFiles, uPaths;

function HttpGet(const URL: string; out Body, Err: string): Boolean;
var
  C: TFPHTTPClient;
begin
  Result := False;
  Body := '';
  Err := '';
  C := TFPHTTPClient.Create(nil);
  try
    C.AllowRedirect := True;
    C.ConnectTimeout := 8000;
    C.IOTimeout := 20000;
    C.AddHeader('User-Agent', 'heckers-sketch');
    try
      Body := C.Get(URL);
      Result := True;
    except
      on Ex: Exception do Err := Ex.Message;
    end;
  finally
    C.Free;
  end;
end;

function FetchEndpoint(out E: TEndpoint; out Err: string): Boolean;
var
  Body: string;
  J: TJSONData;
  O: TJSONObject;
begin
  Result := False;
  E.UploadBase := '';
  E.Bin := '';
  E.Updated := '';
  E.FromCache := False;
  if not HttpGet(ENDPOINT_URL, Body, Err) then Exit;
  J := nil;
  try
    try
      J := GetJSON(Body);
    except
      on Ex: Exception do
      begin
        Err := 'the endpoint file could not be read';
        Exit;
      end;
    end;
    if not (J is TJSONObject) then
    begin
      Err := 'the endpoint file was not what was expected';
      Exit;
    end;
    O := TJSONObject(J);
    E.UploadBase := Trim(O.Get('upload_base', ''));
    E.Bin := Trim(O.Get('current_bin', ''));
    E.Updated := Trim(O.Get('updated_utc', ''));
    if E.UploadBase = '' then
    begin
      Err := 'the endpoint file names no place to upload to';
      Exit;
    end;
    while (E.UploadBase <> '') and
          (E.UploadBase[Length(E.UploadBase)] = '/') do
      SetLength(E.UploadBase, Length(E.UploadBase) - 1);
    Result := True;
  finally
    J.Free;
  end;
end;

function CachedEndpoint(out E: TEndpoint): Boolean;
var
  Ini: TIniFile;
begin
  E.UploadBase := '';
  E.Bin := '';
  E.Updated := '';
  E.FromCache := True;
  Result := False;
  try
    Ini := TIniFile.Create(ConfigFile);
    try
      E.UploadBase := Ini.ReadString('report', 'upload_base', '');
      E.Bin := Ini.ReadString('report', 'bin', '');
      E.Updated := Ini.ReadString('report', 'updated', '');
      Result := E.UploadBase <> '';
    finally
      Ini.Free;
    end;
  except
    Result := False;
  end;
end;

procedure RememberEndpoint(const E: TEndpoint);
var
  Ini: TIniFile;
begin
  try
    Ini := TIniFile.Create(ConfigFile);
    try
      Ini.WriteString('report', 'upload_base', E.UploadBase);
      Ini.WriteString('report', 'bin', E.Bin);
      Ini.WriteString('report', 'updated', E.Updated);
    finally
      Ini.Free;
    end;
  except
    { remembering is a convenience, not a requirement }
  end;
end;

{ Did this refusal mean "that bin has gone"?  Those are worth asking GitHub
  about and trying once more.  A refusal for any other reason is not: trying
  the same thing again would only fail the same way. }
function BinIsGone(Status: Integer): Boolean;
begin
  case Status of
    401, 403, 404, 405, 409, 410, 423: Result := True;
  else
    Result := False;
  end;
end;

function PostStream(const Base, FileName: string; Data: TStream;
  const ContentType: string; out Status: Integer; out Err: string): Boolean;
var
  C: TFPHTTPClient;
  Dst: TStringStream;
begin
  Result := False;
  Status := 0;
  Err := '';
  C := TFPHTTPClient.Create(nil);
  Dst := TStringStream.Create('');
  try
    Data.Position := 0;
    C.AllowRedirect := True;
    C.ConnectTimeout := 10000;
    C.IOTimeout := 60000;
    C.AddHeader('User-Agent', 'heckers-sketch');
    C.AddHeader('Content-Type', ContentType);
    C.RequestBody := Data;
    try
      C.Post(Base + '/' + FileName, Dst);
      Status := C.ResponseStatusCode;
      Result := (Status >= 200) and (Status < 300);
      if not Result then
        Err := 'the postbox answered ' + IntToStr(Status);
    except
      on Ex: Exception do
      begin
        Status := C.ResponseStatusCode;
        Err := Ex.Message;
      end;
    end;
  finally
    Dst.Free;
    C.Free;
  end;
end;

function PostTo(const Base, FileName, Body: string;
  out Status: Integer; out Err: string): Boolean;
var
  Src: TStringStream;
begin
  Src := TStringStream.Create(Body);
  try
    Result := PostStream(Base, FileName, Src, 'text/plain; charset=utf-8',
      Status, Err);
  finally
    Src.Free;
  end;
end;

function SendReport(const FileName, Body: string; out Err: string): Boolean;
var
  E: TEndpoint;
  Status: Integer;
  E2: TEndpoint;
  Err2: string;
begin
  Result := False;
  Err := '';
  try
    { The remembered bin first - one fewer request, and usually right. }
    if CachedEndpoint(E) then
    begin
      if PostTo(E.UploadBase, FileName, Body, Status, Err) then
      begin
        Result := True;
        Exit;
      end;
      { if it did not go because the bin has gone, that is what the config
        on GitHub is for }
      if not BinIsGone(Status) and (Status <> 0) then Exit;
    end;

    if not FetchEndpoint(E2, Err2) then
    begin
      if Err = '' then Err := Err2 else Err := Err + '; ' + Err2;
      Exit;
    end;
    RememberEndpoint(E2);
    Result := PostTo(E2.UploadBase, FileName, Body, Status, Err);
  except
    on Ex: Exception do
    begin
      Result := False;
      Err := Ex.Message;
    end;
  end;
end;

function SendBinary(const FileName: string; Data: TStream;
  const ContentType: string; out Err: string): Boolean;
var
  E, E2: TEndpoint;
  Status: Integer;
  Err2: string;
begin
  Result := False;
  Err := '';
  try
    if CachedEndpoint(E) then
    begin
      if PostStream(E.UploadBase, FileName, Data, ContentType, Status, Err) then
        Exit(True);
      if not BinIsGone(Status) and (Status <> 0) then Exit;
    end;
    if not FetchEndpoint(E2, Err2) then
    begin
      if Err = '' then Err := Err2 else Err := Err + '; ' + Err2;
      Exit;
    end;
    RememberEndpoint(E2);
    Result := PostStream(E2.UploadBase, FileName, Data, ContentType,
      Status, Err);
  except
    on Ex: Exception do
    begin
      Result := False;
      Err := Ex.Message;
    end;
  end;
end;

function UniqueReportName(const Prefix, Version: string): string;
var
  Tag, V: string;
  I: Integer;
begin
  Tag := IntToHex(Random($1000000), 6);
  V := '';
  for I := 1 to Length(Version) do
    if Version[I] in ['0'..'9', 'A'..'Z', 'a'..'z', '.', '-'] then
      V := V + Version[I];
  Result := Prefix + '-' + FormatDateTime('yyyymmdd-hhnnss', Now) +
    '-' + V + '-' + Tag + '.txt';
end;

end.
