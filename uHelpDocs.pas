unit uHelpDocs;

{ The manual, kept beside the program.

  The manual lives on GitHub - the pages in docs/help, published as the
  project's website - and every release carries the same pages as one zip,
  heckers-sketch-help.zip.  This unit fetches that zip, checks it against
  the release's SHA256SUMS, unpacks it into a folder called help beside the
  program, and says what version the pages in that folder are.

  Tony, 17 September: "i want them stored on github like it is... i dont
  want you to make a browser... we will going forward need to have a zip
  archive of the help docs in the releases and then we can have heckers
  sketch fetch it and unzip it and keep a copy locally next to the
  executable.  that way if you run off a usb drive and bring it to a place
  where you have no internet you might still have the files."

  One file, from the release - not the website crawled page by page, which
  is slow, fragile and the kind of traffic a site owner has every right to
  object to.  Release files are not API calls either, so this does not
  touch the hourly limit that stopped the update check on 16 September.

  The pages shown are the ones matching the running version where that
  release has them, so the manual describes the program in front of you.
  A build with no release of its own (a developer's) takes the latest.

  Nothing in here touches a window, which is what lets the tests run it. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

const
  HELP_ZIP = 'heckers-sketch-help.zip';
  { written into the zip by build.sh, holding the tag the pages came from }
  HELP_VERSION_FILE = 'VERSION';

type
  THelpProgress = procedure(BytesReceived, TotalBytes: Int64) of object;

{ The folder the pages go in: beside the program when it is portable, and in
  the user's own folder when the program's folder cannot be written to. }
function HelpFolder: string;
{ index.html of the local copy, or '' when there is none.  A copy running
  from the source tree reads docs/help directly. }
function LocalHelpIndex: string;
{ The release the local pages came from, '' when they came without saying
  (the all-builds zip, the source tree) or there are none. }
function LocalHelpVersion: string;
{ Where a release's zip and checksums are. }
function HelpZipURL(const Tag: string): string;
function HelpSumsURL(const Tag: string): string;

{ Unpack ZipPath and make it the help folder at Dest, replacing what was
  there only once the new copy is complete.  Refuses anything that would
  write outside Dest, anything implausibly large, and a zip with no
  index.html in it. }
function InstallHelpZip(const ZipPath, Dest: string; out Err: string): Boolean;

{ Fetch the pages for Tag (or the latest release when Tag is '' or has no
  zip of its own), check them, and install them in HelpFolder.  GotTag says
  which release they came from. }
function FetchHelp(const Tag: string; OnProgress: THelpProgress;
  out GotTag, Err: string): Boolean;

{ Do the local pages want fetching?  Missing, or from a different release
  than the program - which is exactly the state right after an update.
  Never for a copy running from the source tree, which reads docs/help. }
function HelpIsStale(const ProgramTag: string): Boolean;

type
  { FetchHelp on a thread of its own, so the program never waits on the
    network.  OnDone runs on the main thread when it finishes, and so does
    OnProgress; both may be nil.  Frees itself. }
  THelpFetch = class(TThread)
  private
    FTag, FGotTag, FErr: string;
    FOK: Boolean;
    FGot, FTotal: Int64;
    FOnProgress: THelpProgress;
    FOnDone: TNotifyEvent;
    procedure Progress(BytesReceived, TotalBytes: Int64);
    procedure SyncProgress;
    procedure SyncDone;
  protected
    procedure Execute; override;
  public
    constructor Create(const ATag: string; AOnProgress: THelpProgress;
      AOnDone: TNotifyEvent);
    property OK: Boolean read FOK;
    property GotTag: string read FGotTag;
    property Err: string read FErr;
  end;

var
  { the fetch under way, if there is one - there is only ever one }
  HelpFetching: THelpFetch = nil;

{ Start a background fetch unless one is already running.  False when one
  was already running. }
function StartHelpFetch(const Tag: string; AOnProgress: THelpProgress;
  AOnDone: TNotifyEvent): Boolean;

implementation

uses
  zipper, uPaths, uUpdate, uNet;

const
  { limits on what a zip may unpack to - the manual is a few megabytes }
  MAX_FILES = 5000;
  MAX_BYTES = 200 * 1024 * 1024;

function HelpFolder: string;
begin
  Result := AppDataDir + 'help' + PathDelim;
end;

function LocalHelpIndex: string;
begin
  Result := HelpPage;
end;

function LocalHelpVersion: string;
var
  L: TStringList;
  F: string;
begin
  Result := '';
  F := HelpFolder + HELP_VERSION_FILE;
  if not FileExists(F) then Exit;
  L := TStringList.Create;
  try
    try
      L.LoadFromFile(F);
      if L.Count > 0 then Result := Trim(L[0]);
    except
      Result := '';
    end;
  finally
    L.Free;
  end;
end;

function HelpZipURL(const Tag: string): string;
begin
  Result := 'https://github.com/' + UPDATE_REPO + '/releases/download/' +
    Tag + '/' + HELP_ZIP;
end;

function HelpSumsURL(const Tag: string): string;
begin
  Result := 'https://github.com/' + UPDATE_REPO + '/releases/download/' +
    Tag + '/SHA256SUMS';
end;

{ A name from inside the zip, made safe, or '' when it is not.

  The classic hole in an unzipper is a name like ../../.bashrc or
  /etc/passwd, which writes wherever it likes.  Every name is taken apart
  and anything that climbs, starts from a root or a drive, or is empty is
  refused - the whole zip, not just that entry. }
function SafeName(const Name: string): string;
var
  S, Part: string;
  Parts: TStringList;
  I: Integer;
begin
  Result := '';
  S := StringReplace(Name, '\', '/', [rfReplaceAll]);
  if (S = '') or (S[1] = '/') or (Pos(':', S) > 0) then Exit;
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := '/';
    Parts.DelimitedText := S;
    for I := 0 to Parts.Count - 1 do
    begin
      Part := Parts[I];
      if (Part = '..') then Exit('');
      if (Part = '') or (Part = '.') then Continue;
      if Result <> '' then Result := Result + PathDelim;
      Result := Result + Part;
    end;
  finally
    Parts.Free;
  end;
end;

function RemoveTree(const Dir: string): Boolean;
var
  SR: TSearchRec;
  D: string;
begin
  D := IncludeTrailingPathDelimiter(Dir);
  if FindFirst(D + '*', faAnyFile or faSymLink, SR) = 0 then
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then Continue;
      { a link is removed as a link - never followed into wherever it
        points, which is how a clear-out deletes things it had no business
        touching }
      if (SR.Attr and faSymLink) <> 0 then
        DeleteFile(D + SR.Name)
      else if (SR.Attr and faDirectory) <> 0 then
        RemoveTree(D + SR.Name)
      else
        DeleteFile(D + SR.Name);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
  Result := RemoveDir(Dir);
end;

function InstallHelpZip(const ZipPath, Dest: string; out Err: string): Boolean;
var
  Z: TUnZipper;
  I, N: Integer;
  Total: Int64;
  Target, Fresh, Old: string;
  Entry: TFullZipFileEntry;
begin
  Result := False;
  Err := '';
  Target := ExcludeTrailingPathDelimiter(Dest);
  Fresh := Target + '.new';
  Old := Target + '.old';
  if DirectoryExists(Fresh) then RemoveTree(Fresh);
  if DirectoryExists(Old) then RemoveTree(Old);

  Z := TUnZipper.Create;
  try
    try
      Z.FileName := ZipPath;
      Z.Examine;
      N := Z.Entries.Count;
      if N = 0 then
      begin
        Err := 'the help archive is empty';
        Exit;
      end;
      if N > MAX_FILES then
      begin
        Err := 'the help archive has too many files in it';
        Exit;
      end;
      Total := 0;
      for I := 0 to N - 1 do
      begin
        Entry := Z.Entries.FullEntries[I];
        if SafeName(Entry.ArchiveFileName) = '' then
        begin
          if Entry.IsDirectory and (Trim(Entry.ArchiveFileName) = '') then
            Continue;
          Err := 'the help archive has a file that would land outside ' +
            'its folder (' + Entry.ArchiveFileName + ')';
          Exit;
        end;
        Inc(Total, Entry.Size);
        if Total > MAX_BYTES then
        begin
          Err := 'the help archive unpacks to more than it should';
          Exit;
        end;
      end;

      ForceDirectories(Fresh);
      Z.OutputPath := Fresh;
      Z.UnZipAllFiles;
    except
      on E: Exception do
      begin
        Err := 'the help archive could not be unpacked: ' + E.Message;
        if DirectoryExists(Fresh) then RemoveTree(Fresh);
        Exit;
      end;
    end;
  finally
    Z.Free;
  end;

  if not FileExists(Fresh + PathDelim + 'index.html') then
  begin
    Err := 'the help archive has no index.html in it';
    RemoveTree(Fresh);
    Exit;
  end;

  { The swap.  The old copy is moved aside, not deleted, until the new one
    is in its place - a failure half way leaves one or the other, never
    neither. }
  if DirectoryExists(Target) and not RenameFile(Target, Old) then
  begin
    Err := 'the old help folder could not be moved aside';
    RemoveTree(Fresh);
    Exit;
  end;
  if not RenameFile(Fresh, Target) then
  begin
    Err := 'the new help folder could not be put in place';
    if DirectoryExists(Old) then RenameFile(Old, Target);
    RemoveTree(Fresh);
    Exit;
  end;
  if DirectoryExists(Old) then RemoveTree(Old);
  Result := True;
end;

function FetchHelp(const Tag: string; OnProgress: THelpProgress;
  out GotTag, Err: string): Boolean;
var
  Tried, Want, Tmp, Sum: string;
  Info: TUpdateInfo;
  LatestErr: string;

  function TryTag(const T: string): Boolean;
  begin
    Result := False;
    Want := ExpectedSum(HelpSumsURL(T), HELP_ZIP);
    { an older release with no help zip of its own, or a tag that is not a
      release at all - not an error yet, the latest may have it }
    if Want = '' then Exit;
    Tmp := GetTempFileName(GetTempDir(False), 'hskhelp');
    try
      if not Download(HelpZipURL(T), Tmp, 0, OnProgress, Err) then
      begin
        Err := 'the download failed: ' + NetFriendlyError(Err);
        Exit;
      end;
      Sum := Sha256Of(Tmp);
      if not SameText(Sum, Want) then
      begin
        Err := 'the downloaded help did not match its checksum, so it was ' +
          'not used';
        Exit;
      end;
      if not InstallHelpZip(Tmp, HelpFolder, Err) then Exit;
      GotTag := T;
      Result := True;
    finally
      if FileExists(Tmp) then DeleteFile(Tmp);
    end;
  end;

begin
  Result := False;
  GotTag := '';
  Err := '';
  Tried := '';
  if NetOffline then
  begin
    Err := 'offline (--offline)';
    Exit;
  end;

  { the pages for this version first, so the manual matches the program }
  if (Tag <> '') and (Tag[1] = 'v') and (Pos('dev', Tag) = 0) then
  begin
    Tried := Tag;
    if TryTag(Tag) then Exit(True);
    if Err <> '' then Exit;
  end;

  { and otherwise the newest release's }
  if not FetchLatest(Info, LatestErr) then
  begin
    Err := 'could not find the latest release - ' + LatestErr;
    Exit;
  end;
  if Info.Tag = Tried then
  begin
    Err := 'release ' + Tried + ' has no help pages attached';
    Exit;
  end;
  if TryTag(Info.Tag) then Exit(True);
  if Err = '' then
    Err := 'release ' + Info.Tag + ' has no help pages attached';
end;

function HelpIsStale(const ProgramTag: string): Boolean;
var
  Index: string;
begin
  Index := LocalHelpIndex;
  { the source tree's own pages are always the current ones }
  if Pos(PathDelim + 'docs' + PathDelim + 'help' + PathDelim, Index) > 0 then
    Exit(False);
  if Index = '' then Exit(True);
  { a build that is not a release cannot say which pages match it; whatever
    is there will do }
  if (ProgramTag = '') or (ProgramTag[1] <> 'v') or (Pos('dev', ProgramTag) > 0) then
    Exit(False);
  Result := LocalHelpVersion <> ProgramTag;
end;

constructor THelpFetch.Create(const ATag: string; AOnProgress: THelpProgress;
  AOnDone: TNotifyEvent);
begin
  FTag := ATag;
  FOnProgress := AOnProgress;
  FOnDone := AOnDone;
  FreeOnTerminate := True;
  inherited Create(False);
end;

procedure THelpFetch.Progress(BytesReceived, TotalBytes: Int64);
begin
  FGot := BytesReceived;
  FTotal := TotalBytes;
  if Assigned(FOnProgress) then Queue(@SyncProgress);
end;

procedure THelpFetch.SyncProgress;
begin
  if Assigned(FOnProgress) then FOnProgress(FGot, FTotal);
end;

procedure THelpFetch.SyncDone;
begin
  HelpFetching := nil;
  if Assigned(FOnDone) then FOnDone(Self);
end;

procedure THelpFetch.Execute;
begin
  try
    FOK := FetchHelp(FTag, @Progress, FGotTag, FErr);
  except
    on E: Exception do
    begin
      FOK := False;
      FErr := E.Message;
    end;
  end;
  Synchronize(@SyncDone);
end;

function StartHelpFetch(const Tag: string; AOnProgress: THelpProgress;
  AOnDone: TNotifyEvent): Boolean;
begin
  Result := HelpFetching = nil;
  if Result then HelpFetching := THelpFetch.Create(Tag, AOnProgress, AOnDone);
end;

end.
