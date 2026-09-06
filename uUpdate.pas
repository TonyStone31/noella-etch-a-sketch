{ Looking for a newer build, fetching it, and putting it in place - and
  offering to report a crash that happened last time.

  The program is given away and is not in anybody's package manager, so
  without this a fix reaches people only if they remember to go and look.
  The draft is what makes replacing the program underneath someone
  reasonable at all: a restart costs nothing, because the drawing comes
  back.

  Two things this deliberately does not do.  It does not install anything
  without being told to - it looks, it says what it found, and it waits.
  And it carries no credentials of any kind: a token with write access to
  the repository, sitting in a binary handed out to strangers, is a token
  handed out to strangers.  Reporting a crash therefore opens a filled-in
  issue in the browser for a person to read and send, which also means
  nobody's file paths leave their machine without them seeing them first. }
unit uUpdate;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uNet, fpjson, jsonparser,
  fpsha256, Process
  {$IFDEF UNIX}, BaseUnix{$ENDIF};

const
  UPDATE_REPO = 'TonyStone31/noella-etch-a-sketch';
  {$IFDEF WINDOWS}
  ASSET_NAME = 'heckers-sketch.exe';
  {$ELSE}
  ASSET_NAME = 'heckers-sketch-linux';
  {$ENDIF}

type
  TUpdateInfo = record
    Tag: string;
    AssetURL: string;
    SumsURL: string;
    Size: Int64;
  end;

  TDownloadProgress = procedure(BytesReceived, TotalBytes: Int64) of object;

function CurrentVersion: string;
{ Tags are dotted numbers - v2026.09.03.13 - compared piece by piece as
  numbers, so 13 lands after 9 rather than before it as it would as text. }
function NewerThan(const A, B: string): Boolean;
function FetchLatest(out Info: TUpdateInfo; out Err: string): Boolean;
function Download(const URL, Path: string; TotalBytes: Int64;
  OnProgress: TDownloadProgress; out Err: string): Boolean;
function Sha256Of(const Path: string): string;
function ExpectedSum(const SumsURL, AName: string): string;
{ Why replacing ourselves would be a bad idea, or '' if it is fine. }
function WhyNotUpdate: string;
function SwapInAndRestart(const NewFile: string; out Err: string): Boolean;
procedure ForgetPreviousBuild;
procedure OpenInBrowser(const URL: string);

implementation

{$I version.inc}

function CurrentVersion: string;
begin
  Result := APP_VERSION;
end;

function NewerThan(const A, B: string): Boolean;
var
  SA, SB: TStringList;
  I, NA, NB: Integer;

  procedure Split(const S: string; L: TStringList);
  var
    T: string;
  begin
    T := Trim(S);
    if (T <> '') and ((T[1] = 'v') or (T[1] = 'V')) then Delete(T, 1, 1);
    L.Delimiter := '.';
    L.StrictDelimiter := True;
    L.DelimitedText := T;
  end;

begin
  Result := False;
  SA := TStringList.Create;
  SB := TStringList.Create;
  try
    Split(A, SA);
    Split(B, SB);
    for I := 0 to 7 do
    begin
      if I < SA.Count then NA := StrToIntDef(SA[I], 0) else NA := 0;
      if I < SB.Count then NB := StrToIntDef(SB[I], 0) else NB := 0;
      if NA > NB then Exit(True);
      if NA < NB then Exit(False);
    end;
  finally
    SA.Free;
    SB.Free;
  end;
end;

function GetText(const URL: string; out Body: string; out Err: string): Boolean;
begin
  Result := NetGetText(URL, 'application/vnd.github+json', Body, Err);
end;

function FetchLatest(out Info: TUpdateInfo; out Err: string): Boolean;
var
  Body, N: string;
  J, A: TJSONData;
  Arr: TJSONArray;
  O: TJSONObject;
  I: Integer;
begin
  Result := False;
  Info.Tag := '';
  Info.AssetURL := '';
  Info.SumsURL := '';
  Info.Size := 0;

  if not GetText('https://api.github.com/repos/' + UPDATE_REPO +
       '/releases/latest', Body, Err) then Exit;

  J := nil;
  try
    try
      J := GetJSON(Body);
    except
      on E: Exception do
      begin
        Err := 'the answer was not readable';
        Exit;
      end;
    end;
    if not (J is TJSONObject) then
    begin
      Err := 'the answer was not what was expected';
      Exit;
    end;
    O := TJSONObject(J);
    Info.Tag := O.Get('tag_name', '');
    if Info.Tag = '' then
    begin
      Err := 'that release has no version on it';
      Exit;
    end;
    A := O.Find('assets');
    if not (A is TJSONArray) then
    begin
      Err := 'that release has no files on it';
      Exit;
    end;
    Arr := TJSONArray(A);
    for I := 0 to Arr.Count - 1 do
      if Arr.Items[I] is TJSONObject then
      begin
        N := TJSONObject(Arr.Items[I]).Get('name', '');
        if N = ASSET_NAME then
        begin
          Info.AssetURL := TJSONObject(Arr.Items[I]).Get('browser_download_url', '');
          Info.Size := TJSONObject(Arr.Items[I]).Get('size', Int64(0));
        end
        else if N = 'SHA256SUMS' then
          Info.SumsURL := TJSONObject(Arr.Items[I]).Get('browser_download_url', '');
      end;
    if Info.AssetURL = '' then
    begin
      Err := 'that release has nothing built for this machine (' + ASSET_NAME + ')';
      Exit;
    end;
    Result := True;
  finally
    J.Free;
  end;
end;

type
  TProgressStream = class(TStream)
  private
    FDest: TStream;
    FTotal: Int64;
    FOnProgress: TDownloadProgress;
  public
    constructor Create(ADest: TStream; ATotal: Int64;
      AOnProgress: TDownloadProgress);
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

constructor TProgressStream.Create(ADest: TStream; ATotal: Int64;
  AOnProgress: TDownloadProgress);
begin
  inherited Create;
  FDest := ADest;
  FTotal := ATotal;
  FOnProgress := AOnProgress;
end;

function TProgressStream.Read(var Buffer; Count: Longint): Longint;
begin
  Result := FDest.Read(Buffer, Count);
end;

function TProgressStream.Write(const Buffer; Count: Longint): Longint;
begin
  Result := FDest.Write(Buffer, Count);
  if Assigned(FOnProgress) then FOnProgress(FDest.Position, FTotal);
end;

function TProgressStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  Result := FDest.Seek(Offset, Origin);
end;

function Download(const URL, Path: string; TotalBytes: Int64;
  OnProgress: TDownloadProgress; out Err: string): Boolean;
var
  F: TFileStream;
  Progress: TProgressStream;
  Status: Integer;
begin
  Result := False;
  Err := '';
  F := nil;
  Progress := nil;
  try
    try
      F := TFileStream.Create(Path, fmCreate);
      Progress := TProgressStream.Create(F, TotalBytes, OnProgress);
      Result := NetGet(URL, '', Progress, Status, Err);
      if Result and (F.Size <= 0) then
      begin
        Result := False;
        Err := 'the download came back empty';
      end;
    except
      on E: Exception do Err := E.Message;
    end;
  finally
    Progress.Free;
    F.Free;
  end;
  if not Result then DeleteFile(Path);
end;

function Sha256Of(const Path: string): string;
var
  F: TFileStream;
  D: TSHA256Digest;
  I: Integer;
begin
  Result := '';
  try
    F := TFileStream.Create(Path, fmOpenRead or fmShareDenyNone);
    try
      D := TSHA256.Stream(F);
    finally
      F.Free;
    end;
    for I := Low(D) to High(D) do
      Result := Result + LowerCase(IntToHex(D[I], 2));
  except
    Result := '';
  end;
end;

function ExpectedSum(const SumsURL, AName: string): string;
var
  Body, Err, Line, Nm: string;
  L: TStringList;
  I, P: Integer;
begin
  Result := '';
  if SumsURL = '' then Exit;
  if not GetText(SumsURL, Body, Err) then Exit;
  L := TStringList.Create;
  try
    L.Text := Body;
    for I := 0 to L.Count - 1 do
    begin
      Line := Trim(L[I]);
      P := Pos(' ', Line);
      if P < 32 then Continue;
      { "<hash>  <name>", which is what sha256sum writes; the star in front
        of the name is its binary-mode marker }
      Nm := Trim(Copy(Line, P + 1, MaxInt));
      if (Nm <> '') and (Nm[1] = '*') then Delete(Nm, 1, 1);
      if Nm = AName then Exit(LowerCase(Trim(Copy(Line, 1, P - 1))));
    end;
  finally
    L.Free;
  end;
end;

function WhyNotUpdate: string;
var
  Dir: string;
  F: TFileStream;
begin
  Result := '';
  Dir := ExtractFilePath(ExpandFileName(ParamStr(0)));
  { A working copy is the one place this must never touch.  Somebody is
    building in there, and dropping a downloaded binary on it would throw
    away what they just compiled - and it is exactly where a developer runs
    the program from. }
  if FileExists(Dir + 'etchasketch.lpi') or FileExists(Dir + 'uMain.pas') then
    Exit('this copy runs from its own source folder, where an update would ' +
         'overwrite what you just built');
  if not DirectoryExists(Dir) then
    Exit('cannot tell where this program lives');
  try
    F := TFileStream.Create(Dir + '.hsk-write-test', fmCreate);
    F.Free;
    DeleteFile(Dir + '.hsk-write-test');
  except
    Exit('no permission to replace the program where it is installed');
  end;
end;

function SwapInAndRestart(const NewFile: string; out Err: string): Boolean;
var
  Me: string;
  {$IFDEF WINDOWS}
  Old: string;      { only Windows has to move the running file aside }
  {$ENDIF}
  P: TProcess;
begin
  Result := False;
  Err := '';
  Me := ExpandFileName(ParamStr(0));
  if not FileExists(NewFile) then
  begin
    Err := 'the download went missing';
    Exit;
  end;

  {$IFDEF WINDOWS}
  { Windows will not let a running program be written over, but it will let
    it be renamed out of the way.  The new copy clears the old one up the
    next time it starts. }
  Old := Me + '.old';
  if FileExists(Old) then DeleteFile(Old);
  if not RenameFile(Me, Old) then
  begin
    Err := 'could not move the running program aside';
    Exit;
  end;
  if not RenameFile(NewFile, Me) then
  begin
    RenameFile(Old, Me);            { put it back rather than leave nothing }
    Err := 'could not put the new one in place';
    Exit;
  end;
  {$ELSE}
  FpChmod(PChar(NewFile), &755);
  { On Unix a rename over a running program is fine: this process keeps the
    file it started from, and the name comes to mean the new one. }
  if not RenameFile(NewFile, Me) then
  begin
    Err := 'could not put the new one in place';
    Exit;
  end;
  {$ENDIF}

  P := TProcess.Create(nil);
  try
    P.Executable := Me;
    { Tells the new copy that the lock it is about to find held belongs to the
      copy that started it, and will be let go in a moment.  Without this it
      found the lock, quite correctly refused to be a second instance, and the
      update stopped the program without ever starting it again. }
    P.Parameters.Add('--updated');
    P.Parameters.Add('--updated-from=' + CurrentVersion);
    P.InheritHandles := False;
    try
      P.Execute;
      Result := True;
    except
      on E: Exception do Err := 'the new one would not start (' + E.Message + ')';
    end;
  finally
    P.Free;
  end;
end;

procedure ForgetPreviousBuild;
var
  Old: string;
begin
  Old := ExpandFileName(ParamStr(0)) + '.old';
  if FileExists(Old) then DeleteFile(Old);
end;


procedure OpenInBrowser(const URL: string);
var
  P: TProcess;
begin
  P := TProcess.Create(nil);
  try
    {$IFDEF WINDOWS}
    P.Executable := 'cmd';
    P.Parameters.Add('/c');
    P.Parameters.Add('start');
    P.Parameters.Add('');
    P.Parameters.Add(URL);
    {$ELSE}
    P.Executable := 'xdg-open';
    P.Parameters.Add(URL);
    {$ENDIF}
    P.InheritHandles := False;
    try
      P.Execute;
    except
      { no browser is not worth an error box }
    end;
  finally
    P.Free;
  end;
end;

end.
