unit uHelpView;

{ The manual, inside the program.

  The pages are the same ones the website shows, kept in a folder beside the
  program (see uHelpDocs), and drawn by LazInk's TInkPage - headings, tables,
  screenshots and animations, links between pages, Back and Forward, find,
  selecting and copying, and a finger to scroll.  It is a page viewer, not a
  browser: a link to anywhere else goes to the real browser.

  Tony, 17 September: "i dont want you to make a browser", and later, "build
  the help form with a real lfm!"  So the window is laid out in
  uHelpView.lfm and dressed in the program's theme here.

  With no pages on this computer, or pages from a different release than
  the program, it fetches the right ones from the release on GitHub - in
  the background, with the progress on screen - and shows them when they
  arrive.  Whatever is already there is shown in the meantime. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ComCtrls, ExtCtrls,
  LCLType, LCLIntf, BCPanel, BCButton, InkPage;

type
  { The three the switch cycles through, the website's own three: Auto
    follows the program's theme, the other two say so regardless. }
  THelpTheme = (htAuto, htLight, htDark);

  THelpForm = class(TForm)
    btnBack: TBCButton;
    btnForward: TBCButton;
    btnContents: TBCButton;
    btnFind: TBCButton;
    btnRefresh: TBCButton;
    btnWeb: TBCButton;
    btnEmptyGet: TBCButton;
    btnEmptyWeb: TBCButton;
    lblTitle: TLabel;
    lblNotice: TLabel;
    lblEmptyTitle: TLabel;
    lblEmptyText: TLabel;
    pbNotice: TProgressBar;
    pbEmpty: TProgressBar;
    pnlBar: TBCPanel;
    pnlNotice: TBCPanel;
    pnlEmpty: TBCPanel;
    Page: TInkPage;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure btnBackClick(Sender: TObject);
    procedure btnForwardClick(Sender: TObject);
    procedure btnContentsClick(Sender: TObject);
    procedure btnFindClick(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);
    procedure btnWebClick(Sender: TObject);
    procedure PageLinkClick(Sender: TObject; const URL: string);
    procedure PageNavigate(Sender: TObject);
  public
    { the window is kept between opens; the theme may change while it is
      hidden, so whoever opens it dresses it again }
    procedure Dress;
  private
    function PageIsLight: Boolean;
    function ThemeWord: string;
    procedure LoadThemeChoice;
    procedure SaveThemeChoice;
    procedure CycleTheme;
    function PageWithMode(const HTML: string): string;
    procedure GoToPage(const PathOrURI: string);
  private
    FWanted: string;        { the page asked for, relative to the folder }
    FFetching: Boolean;
    { what the switch at the top of every page was last set to }
    FThemeChoice: THelpTheme;
    procedure ShowPages(const Rel: string);
    procedure ShowEmpty(const Why: string);
    procedure Notice(const S: string; Busy: Boolean);
    procedure Fetch(Loud: Boolean);
    procedure UpdateButtons;
    function PageRelative: string;
    function LocalFileForWeb(const URL: string): string;
  public
    { A fetch has moved on, or finished - this window's own, or one the
      program started by itself, which it passes on here. }
    procedure FetchProgress(BytesReceived, TotalBytes: Int64);
    procedure FetchDone(Sender: TObject);
    { Show the manual at Rel - a page like 'tools/arc.html', with an
      optional #anchor - or at the contents when Rel is empty. }
    procedure OpenAt(const Rel: string);
  end;

var
  HelpForm: THelpForm = nil;

{ The one help window, made the first time it is asked for and shown at Rel. }
procedure OpenHelpWindow(const Rel: string = '');

implementation

{$R *.lfm}

uses
  uHelpDocs, uUpdate, uNet, uDlgSkin, uSurface, uHelpImage, uPaths,
  IniFiles, URIParser;

procedure OpenHelpWindow(const Rel: string);
begin
  if HelpForm = nil then
    Application.CreateForm(THelpForm, HelpForm)
  else
    { the window is kept between opens, so the theme may have changed under
      it since - dress it again rather than showing last week's colours }
    HelpForm.Dress;
  HelpForm.OpenAt(Rel);
end;

procedure THelpForm.FormCreate(Sender: TObject);
begin
  LoadThemeChoice;
  Dress;
  { a finger scrolls, a mouse selects - LazInk tells them apart }
  Page.DragScroll := True;
  Page.CopyMenu := True;
end;

procedure THelpForm.FormDestroy(Sender: TObject);
begin
  if HelpForm = Self then HelpForm := nil;
end;

procedure THelpForm.FormShow(Sender: TObject);
begin
  UpdateButtons;
end;

{ Closing hides it rather than throwing it away, so the next open comes
  back to the page that was being read. }
procedure THelpForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction := caHide;
end;

procedure THelpForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  { Escape closes the window, unless the page's find bar has it - LazInk's
    note: a form with KeyPreview sees Esc before the bar does }
  if (Key = VK_ESCAPE) and not Page.FindBarVisible then
  begin
    Close;
    Key := 0;
  end
  else if (Key = VK_HOME) and (ssAlt in Shift) then
  begin
    btnContentsClick(nil);
    Key := 0;
  end;
end;

{ The window in the program's colours: the same theme the dialogs wear, and
  the page itself left to the manual's own stylesheet, which is already the
  program's dark look. }
procedure THelpForm.Dress;
begin
  uDlgSkin.SkinForm(Self);
  { the bar in the panel colour, so the buttons - drawn a shade lighter -
    stand out from it rather than showing only as their outlines }
  uDlgSkin.SkinPanel(pnlBar, False, 0);
  uDlgSkin.SkinPanel(pnlNotice, False, 0);
  uDlgSkin.SkinPanel(pnlEmpty, False, 0);
  uDlgSkin.SkinButton(btnBack, bkPlain);
  uDlgSkin.SkinButton(btnForward, bkPlain);
  uDlgSkin.SkinButton(btnContents, bkPlain);
  uDlgSkin.SkinButton(btnFind, bkPlain);
  uDlgSkin.SkinButton(btnRefresh, bkQuiet);
  uDlgSkin.SkinButton(btnWeb, bkQuiet);
  uDlgSkin.SkinButton(btnEmptyGet, bkGo);
  uDlgSkin.SkinButton(btnEmptyWeb, bkPlain);
  { a rounded button shows its parent's colour in its corners; the bar's is
    the one it should show, not the form's }
  btnBack.Color := pnlBar.Color;
  btnForward.Color := pnlBar.Color;
  btnContents.Color := pnlBar.Color;
  btnFind.Color := pnlBar.Color;
  btnRefresh.Color := pnlBar.Color;
  btnWeb.Color := pnlBar.Color;
  btnEmptyGet.Color := pnlEmpty.Color;
  btnEmptyWeb.Color := pnlEmpty.Color;
  lblTitle.Font.Color := PixToColor(DlgTheme.Text);
  lblNotice.Font.Color := PixToColor(DlgTheme.Text);
  lblEmptyTitle.Font.Color := PixToColor(DlgTheme.Text);
  lblEmptyText.Font.Color := PixToColor(DlgTheme.TextDim);
  Page.Color := PixToColor(DlgTheme.Panel);
  Page.Font.Color := PixToColor(DlgTheme.Text);
end;

{ The manual is written in the program's dark colours, and a reader in a
  browser gets the light ones from a media query the renderer here cannot
  judge.  The program's own theme is the better answer anyway - Tony, 17
  September: "there should be a way to pass the etch sketches current mode
  to the help docs so they can render the same way".

  A stylesheet of our own was the obvious way and does not work: the page's
  own rules win over it, and its palette is a set of custom properties set
  on :root, which cannot be overridden from outside.  So the mode is put
  where the page itself reads it - a class on the body, which style.css
  answers with the light palette - and the page is handed over as text
  rather than as a file.  See body.light in docs/help/style.css.

  Since 19 September the reader can also say, which is what the switch at
  the top of every page does - Tony: "even the local copy should have the
  light/dark mode button toggles in the help browsers html like we do in
  the online version".  Auto is this rule; Light and Dark are the reader
  overruling it, and the choice is kept between sessions the way the
  website keeps its own. }
function THelpForm.PageIsLight: Boolean;
begin
  case FThemeChoice of
    htLight: Result := True;
    htDark: Result := False;
  else
    Result := not DlgTheme.DarkScreen and
      (DlgTheme.Panel.R + DlgTheme.Panel.G + DlgTheme.Panel.B >= 3 * 128);
  end;
end;

{ What the switch says it will give you if you press it - the state it is
  in, in the same three words the website uses. }
function THelpForm.ThemeWord: string;
begin
  case FThemeChoice of
    htLight: Result := 'Light';
    htDark: Result := 'Dark';
  else Result := 'Auto';
  end;
end;

{ The reader's choice outlives the window, which is thrown away and remade
  with the program; it lives beside the program's own settings. }
procedure THelpForm.LoadThemeChoice;
var
  Ini: TIniFile;
begin
  FThemeChoice := htAuto;
  if not FileExists(ConfigFile) then Exit;
  Ini := TIniFile.Create(ConfigFile);
  try
    case LowerCase(Ini.ReadString('look', 'helptheme', 'auto')) of
      'light': FThemeChoice := htLight;
      'dark': FThemeChoice := htDark;
    end;
  finally
    Ini.Free;
  end;
end;

procedure THelpForm.SaveThemeChoice;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(ConfigFile);
  try
    Ini.WriteString('look', 'helptheme', LowerCase(ThemeWord));
  finally
    Ini.Free;
  end;
end;

{ The page, with the light palette linked into it when the program is
  wearing a light theme.

  Not a class on the body and not a stylesheet of our own: LazInk reads
  custom properties from :root only, and a page's own rules beat one handed
  in from outside.  A second stylesheet linked after the page's own is
  plain CSS - later rules win - and it is what a browser does with the
  media query at the foot of style.css. }
function THelpForm.PageWithMode(const HTML: string): string;
var
  Low, Prefix: string;
  P, Q: Integer;
begin
  Result := HTML;
  { The switch says which of the three it is on.  In a browser theme.js
    writes that word in; here nothing runs, so it is written in on the way
    past - the same substitution, done by whoever is showing the page. }
  Result := StringReplace(Result, '#theme" title="Light or dark">Theme</a>',
    '#theme" title="Light or dark">Theme: ' + ThemeWord + '</a>',
    [rfReplaceAll, rfIgnoreCase]);
  if not PageIsLight then Exit;
  Low := LowerCase(Result);
  P := Pos('style.css"', Low);
  if P <= 0 then Exit;
  { the same folder the page reached style.css through - pages under tools/
    say ../style.css }
  Q := P;
  while (Q > 1) and (Low[Q - 1] <> '"') do Dec(Q);
  Prefix := Copy(Result, Q, P - Q);
  P := Pos('>', Low, P);
  if P <= 0 then Exit;
  Insert(LineEnding + '<link rel="stylesheet" href="' + Prefix +
    'style-light.css">', Result, P + 1);
end;

{ Every page this window shows goes through here, so every one carries the
  mode - the contents, a link inside a page, and Back and Forward, which
  replay what was loaded rather than reading the file again. }
procedure THelpForm.GoToPage(const PathOrURI: string);
var
  Path, Anchor, Src, Local: string;

  L: TStringList;
  P: Integer;
begin
  Path := PathOrURI;
  Anchor := '';
  P := Pos('#', Path);
  if P > 0 then
  begin
    Anchor := Copy(Path, P + 1, MaxInt);
    Delete(Path, P, MaxInt);
  end;
  { Two variables, and they have to be two.  URIToFilename's second
    parameter is an "out", which FPC clears on the way in - so handing it
    the same string twice wipes the URI before it is read, the call fails,
    and every page reached by a link took the branch below instead: loaded
    raw, without the light palette this window links in.  That is what made
    the manual dark in a light theme once you clicked anything. }
  if LowerCase(Copy(Path, 1, 7)) = 'file://' then
    if URIToFilename(Path, Local) then Path := Local else Path := '';
  if (Path = '') or not FileExists(Path) or
     (LowerCase(ExtractFileExt(Path)) <> '.html') then
  begin
    { not one of ours - hand it to the renderer as it is }
    if FileExists(Path) then Page.LoadFromFile(Path)
    else Page.LoadFromURL(PathOrURI);
    if Anchor <> '' then Page.JumpToAnchor(Anchor);
    Exit;
  end;
  L := TStringList.Create;
  try
    L.LoadFromFile(Path);
    Src := L.Text;
  finally
    L.Free;
  end;
  Page.LoadHTML(PageWithMode(Src), FilenameToURI(ExpandFileName(Path)));
  if Anchor <> '' then Page.JumpToAnchor(Anchor);
end;

procedure THelpForm.OpenAt(const Rel: string);
var
  R: TRect;
begin
  FWanted := Rel;
  { never bigger than the screen it opens on - the designed size is for a
    desktop, and the program runs on smaller ones }
  if not Visible then
  begin
    R := Screen.WorkAreaRect;
    if Width > (R.Right - R.Left) * 9 div 10 then
      Width := (R.Right - R.Left) * 9 div 10;
    if Height > (R.Bottom - R.Top) * 9 div 10 then
      Height := (R.Bottom - R.Top) * 9 div 10;
  end;
  if LocalHelpIndex <> '' then ShowPages(Rel)
  else ShowEmpty('');
  Show;
  BringToFront;
  { Pages missing, or from another release: fetch the right ones.  Opening
    the manual is somebody asking for it, so this goes whatever the
    automatic-update setting says - but never with --offline. }
  if HelpIsStale(CurrentVersion) and not NetOffline then Fetch(False);
end;

procedure THelpForm.ShowPages(const Rel: string);
var
  Index, Folder, Target, Anchor: string;
  P: Integer;
begin
  Index := LocalHelpIndex;
  if Index = '' then
  begin
    ShowEmpty('');
    Exit;
  end;
  Folder := ExtractFilePath(Index);
  Target := Rel;
  Anchor := '';
  P := Pos('#', Target);
  if P > 0 then
  begin
    Anchor := Copy(Target, P, MaxInt);
    Delete(Target, P, MaxInt);
  end;
  if (Target = '') or not FileExists(Folder + SetDirSeparators(Target)) then
    Target := 'index.html';
  pnlEmpty.Visible := False;
  Page.Visible := True;
  try
    GoToPage(Folder + SetDirSeparators(Target) + Anchor);
  except
    on E: Exception do
      ShowEmpty('The page could not be read: ' + E.Message);
  end;
  UpdateButtons;
end;

procedure THelpForm.ShowEmpty(const Why: string);
begin
  Page.Visible := False;
  pnlEmpty.Visible := True;
  if Why <> '' then
    lblEmptyText.Caption := Why
  else if NetOffline then
    lblEmptyText.Caption := 'This copy was started with --offline, so it ' +
      'will not download them.  They are on the web too.'
  else
    lblEmptyText.Caption := 'They come from this version''s release on ' +
      'GitHub, a few megabytes, and are kept in a folder called help beside ' +
      'the program - so they are still here next time, with or without the ' +
      'internet.';
  pbEmpty.Visible := FFetching;
  btnEmptyGet.Enabled := not FFetching and not NetOffline;
  UpdateButtons;
end;

procedure THelpForm.Notice(const S: string; Busy: Boolean);
begin
  lblNotice.Caption := S;
  pbNotice.Visible := Busy;
  pnlNotice.Visible := S <> '';
end;

procedure THelpForm.Fetch(Loud: Boolean);
begin
  if NetOffline then
  begin
    Notice('Started with --offline - nothing was downloaded.', False);
    Exit;
  end;
  if FFetching then Exit;
  FFetching := True;
  pbNotice.Position := 0;
  pbEmpty.Position := 0;
  if LocalHelpIndex = '' then
    ShowEmpty('Downloading the help pages...')
  else
    Notice('Getting the help pages for ' + CurrentVersion + '...', True);
  { a fetch the program started on its own may already be running - this
    window then just waits for it, and hears about it from the program }
  if not StartHelpFetch(CurrentVersion, @FetchProgress, @FetchDone) then
    Notice('The help pages are already being downloaded...', True);
  if Loud then btnRefresh.Enabled := False;
end;

procedure THelpForm.FetchProgress(BytesReceived, TotalBytes: Int64);
var
  Pct: Integer;
begin
  { the size is not always known in advance; a moving bar still says
    something is happening }
  if TotalBytes > 0 then
    Pct := Round(BytesReceived * 100.0 / TotalBytes)
  else
    Pct := (BytesReceived div (256 * 1024)) mod 100;
  pbNotice.Position := Pct;
  pbEmpty.Position := Pct;
end;

procedure THelpForm.FetchDone(Sender: TObject);
var
  F: THelpFetch;
  Rel: string;
begin
  FFetching := False;
  btnRefresh.Enabled := True;
  F := Sender as THelpFetch;
  if F.OK then
  begin
    { back to the page that was showing, in the new copy }
    Rel := PageRelative;
    if Rel = '' then Rel := FWanted;
    ShowPages(Rel);
    Notice('', False);
  end
  else if LocalHelpIndex = '' then
    ShowEmpty('The help pages could not be downloaded - ' + F.Err + '.')
  else
    Notice('Could not get newer help pages - ' + F.Err +
      '.  Showing the ones already here.', False);
end;

{ The showing page, relative to the help folder - so it can be found again
  in a fresh copy, or on the website. }
function THelpForm.PageRelative: string;
var
  Loc, Folder: string;
begin
  Result := '';
  Loc := Page.Location;
  if Pos('file://', Loc) = 1 then Delete(Loc, 1, 7);
  if LocalHelpIndex = '' then Exit;
  Folder := ExtractFilePath(LocalHelpIndex);
  if Pos(Folder, Loc) = 1 then
    Result := StringReplace(Copy(Loc, Length(Folder) + 1, MaxInt), PathDelim,
      '/', [rfReplaceAll]);
end;

{ A link to the manual's own website, turned back into the local file it is
  a copy of - so a page that links "on the web" still stays in the window. }
function THelpForm.LocalFileForWeb(const URL: string): string;
var
  Rel: string;
begin
  Result := '';
  if (LocalHelpIndex = '') or (Pos(MANUAL_URL, URL) <> 1) then Exit;
  Rel := Copy(URL, Length(MANUAL_URL) + 1, MaxInt);
  if Pos('#', Rel) > 0 then Rel := Copy(Rel, 1, Pos('#', Rel) - 1);
  if Rel = '' then Rel := 'index.html';
  Result := ExtractFilePath(LocalHelpIndex) + SetDirSeparators(Rel);
  if not FileExists(Result) then Result := '';
end;

{ Round the three, and show the page again wearing the new one.

  The page is loaded again rather than restyled in place: the palette is a
  stylesheet linked into the text as it goes to the renderer, so a different
  palette is a different page.  It comes back at the top, which the reader
  will forgive because the switch is at the top. }
procedure THelpForm.CycleTheme;
var
  Rel: string;
begin
  case FThemeChoice of
    htAuto: FThemeChoice := htLight;
    htLight: FThemeChoice := htDark;
  else FThemeChoice := htAuto;
  end;
  SaveThemeChoice;
  Rel := PageRelative;
  if Rel = '' then Rel := 'index.html';
  ShowPages(Rel);
end;

procedure THelpForm.PageLinkClick(Sender: TObject; const URL: string);
var
  Local, Ext: string;
begin
  { The switch at the top of every page.  It is an ordinary link so that
    both readers can act on it - see the note at the top of theme.js - and
    this is the program acting on it. }
  if (Length(URL) >= 6) and (LowerCase(Copy(URL, Length(URL) - 5, 6)) = '#theme') then
  begin
    CycleTheme;
    Exit;
  end;
  { A picture - clicked, or a link straight to one - opens larger in the
    picture window rather than replacing the page being read.

    The list has to hold every kind the manual actually uses.  It did not
    hold .webp, and the day the animations became WebP every one of them
    became a link this did not recognise: it fell through to the page loader
    below, which handed a binary file to the renderer as if it were text, and
    what came up was the file itself as gibberish.  A picture window that
    knows a format the page's link test does not is a trap; if another format
    is ever added, it is added here as well. }
  Ext := LowerCase(ExtractFileExt(URL));
  if (Page.ClickedLink.Image <> '') or (Ext = '.png') or (Ext = '.gif') or
     (Ext = '.jpg') or (Ext = '.jpeg') or (Ext = '.webp') or
     (Ext = '.bmp') then
  begin
    if Page.ClickedLink.Image <> '' then
      OpenPictureWindow(Page.ClickedLink.Image, lblTitle.Caption)
    else
      OpenPictureWindow(URL, lblTitle.Caption);
    Exit;
  end;
  Local := LocalFileForWeb(URL);
  if Local <> '' then
  begin
    GoToPage(Local + Copy(URL, Pos('#', URL + '#'), MaxInt));
    Exit;
  end;
  { anywhere else on the internet, or an e-mail address: the real browser }
  if (Pos('http://', URL) = 1) or (Pos('https://', URL) = 1) or
     (Pos('mailto:', URL) = 1) then
  begin
    OpenURL(URL);
    Exit;
  end;
  try
    GoToPage(URL);
  except
    on E: Exception do
      Notice('That page could not be opened - ' + E.Message, False);
  end;
end;

procedure THelpForm.PageNavigate(Sender: TObject);
begin
  UpdateButtons;
end;

{ A button that cannot do anything right now.  Its words are dimmed rather
  than the button disabled: BGRA's disabled look is a flat light grey that
  sits on a dark bar like a hole.  The click handlers check for themselves. }
procedure Available(B: TBCButton; On_: Boolean);
var
  C: TColor;
begin
  if On_ then C := PixToColor(DlgTheme.Text)
  else C := Shade(PixToColor(DlgTheme.Panel), 0.35);
  B.StateNormal.FontEx.Color := C;
  B.StateHover.FontEx.Color := C;
  B.StateClicked.FontEx.Color := C;
  B.Tag := Ord(On_);
end;

procedure THelpForm.UpdateButtons;
var
  OnPage: Boolean;
  Ver: string;
begin
  OnPage := Page.Visible;
  Available(btnBack, OnPage and Page.CanGoBack);
  Available(btnForward, OnPage and Page.CanGoForward);
  Available(btnContents, OnPage);
  Available(btnFind, OnPage);
  btnRefresh.Enabled := not FFetching and not NetOffline;
  if OnPage and (Page.DocumentTitle <> '') then
    lblTitle.Caption := StringReplace(Page.DocumentTitle, ' - Heckers Sketch',
      '', [])
  else
    lblTitle.Caption := 'Help';
  Ver := LocalHelpVersion;
  if Ver <> '' then
    Caption := 'Heckers Sketch - Help  (pages from ' + Ver + ')'
  else
    Caption := 'Heckers Sketch - Help';
end;

procedure THelpForm.btnBackClick(Sender: TObject);
begin
  if Page.Visible and Page.CanGoBack then Page.Back;
end;

procedure THelpForm.btnForwardClick(Sender: TObject);
begin
  if Page.Visible and Page.CanGoForward then Page.Forward;
end;

procedure THelpForm.btnContentsClick(Sender: TObject);
begin
  if LocalHelpIndex <> '' then ShowPages('');
end;

procedure THelpForm.btnFindClick(Sender: TObject);
begin
  if Page.Visible then Page.ShowFindBar;
end;

procedure THelpForm.btnRefreshClick(Sender: TObject);
begin
  Fetch(True);
end;

procedure THelpForm.btnWebClick(Sender: TObject);
begin
  OpenURL(MANUAL_URL + PageRelative);
end;

end.
