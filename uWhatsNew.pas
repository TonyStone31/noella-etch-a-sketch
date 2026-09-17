unit uWhatsNew;

{ The release notes, on screen.

  WHATS_NEW.md is the one copy of the notes.  build.sh turns it into
  whatsnew.inc, a string constant, before every build, so the words in the
  program are the words in the file.  This unit reads that markdown - the
  little of it that is used: "## version" sections, "### New" and "### Fixed"
  headings, "- " bullets with a bold lead-in - and shows the sections newer
  than the version an update replaced, or every section when asked from the
  menu.

  It used to put the lot in a memo, which meant one weight of one colour, the
  asterisks of the bold markers showing as asterisks, and a stock dialog
  round it.  So the notes are set rather than dumped: the version, the two
  headings and the lead-in of each bullet are all told apart, and the window
  is dressed in the same theme as everything else - see uDlgSkin.

  The setting is LazInk's now (https://github.com/TonyStone31/LazInk).  This
  unit used to lay the words out itself - measuring, wrapping, a scrollbar
  drawn by hand, and dragging the page for a finger - three hundred lines of
  a text renderer that belonged in a package.  It moved there: the notes are
  turned into a small page of HTML in the dialog's own colours and handed to
  a TInkPage, which wraps, scrolls by wheel, keys and drag, and is tested on
  its own.  What stays here is the part only this program knows - which
  releases to show.

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Math, Graphics, Forms, Controls, StdCtrls,
  ExtCtrls, LCLType, LCLIntf, BCPanel, BCLabel, BCButton, InkPage, InkMarkdown,
  uUpdate, uSkin, uDlgSkin, uSurface;

type
  TWhatsNewForm = class(TForm)
  private
    { the notes to show, as Markdown }
    FNotes: string;

    FHead, FBody, FFoot: TBCPanel;
    { Plain labels, transparent, rather than the drawn ones.  A drawn label
      fills its own rectangle with a colour it inherited from the parent -
      which on a skinned panel is not the colour the panel actually painted -
      so the title came out sitting in a pale box. }
    FTitle, FWhich: TLabel;
    FPage: TInkPage;
    FShut, FGo: TBCButton;

    FDrag: uDlgSkin.TFormDrag;

    procedure Build;
    { the notes as a page, and onto the screen }
    procedure ShowNotes;
    procedure PageLink(Sender: TObject; const URL: string);
    procedure KeyDownH(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HeadDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure HeadMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure HeadUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure DoGo(Sender: TObject);
  public
    constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); override;
    { after an update: what changed since PreviousVersion }
    procedure ShowRelease(const PreviousVersion, NewVersion: string);
    { from the menu: the whole history }
    procedure ShowAll;
  end;

{ The notes as Markdown: every release section newer than Since, or all of
  them when Since is empty.  A section headed "Next release" is the build
  being run and is listed under its own version.  '' when nothing is newer. }
function ReleaseNotesMarkdown(const Since: string): string;
{ The style sheet the window gives the page, in the dialog theme's colours. }
function ReleaseNotesStyle(const T: TTheme): string;

implementation

{$I whatsnew.inc}

const
  DLG_W = 760;
  DLG_H = 640;
  PAD   = 14;
  HEAD_H = 48;
  FOOT_H = 58;

{ --- reading the file -------------------------------------------------- }

{ The part of WHATS_NEW.md an update should show.

  Everything after the version the program was updated from, and nothing
  before it - the trick that makes the window after an update say what is
  new rather than repeat the whole history.  The file's own title and its
  comment for whoever edits it are left out; the window has a title.

  The rest goes to LazInk as it is written.  It used to be read line by
  line into headings and bullets and set by hand here, then turned into
  HTML for LazInk; LazInk reads Markdown itself now, including bullets that
  wrap onto indented lines.

  Two things are still done first.  Raw HTML in Markdown is shown as text,
  which is right - but the notes file sits beside a folder of HTML help
  pages, and a <kbd> written into it out of habit reached users as the tags
  on 16 September.  So the handful of inline tags that could plausibly turn
  up are removed by name.  Not "anything in angle brackets": the notes
  contain "/tiles <folder>", where the brackets are how a placeholder is
  written. }
function ReleaseNotesMarkdown(const Since: string): string;
const
  TAGS: array[0..11] of string =
    ('<kbd>', '</kbd>', '<code>', '</code>', '<b>', '</b>',
     '<i>', '</i>', '<em>', '</em>', '<strong>', '</strong>');
var
  Lines, Out_: TStringList;
  I, K: Integer;
  L, Title: string;
  Keep: Boolean;
begin
  Lines := TStringList.Create;
  Out_ := TStringList.Create;
  try
    Lines.Text := WHATS_NEW_MD;
    Keep := False;
    for I := 0 to Lines.Count - 1 do
    begin
      L := Lines[I];
      if Copy(L, 1, 3) = '## ' then
      begin
        Title := Trim(Copy(L, 4, MaxInt));
        if SameText(Title, 'Next release') then
        begin
          Keep := True;
          Title := CurrentVersion;
        end
        else
          Keep := (Since = '') or NewerThan(Title, Since);
        if Keep then
        begin
          if Out_.Count > 0 then Out_.Add('');
          Out_.Add('## ' + Title);
          Out_.Add('');
          Out_.Add('---');
        end;
        Continue;
      end;
      if not Keep then Continue;
      for K := 0 to High(TAGS) do
        L := StringReplace(L, TAGS[K], '', [rfReplaceAll, rfIgnoreCase]);
      Out_.Add(L);
    end;
    if Out_.Count = 0 then Result := ''
    else Result := Out_.Text;
  finally
    Out_.Free;
    Lines.Free;
  end;
end;

{ The window's look, as the page's style sheet: the dialog theme's colours,
  headings in the accent, and the scrollbar in the theme too. }
function ReleaseNotesStyle(const T: TTheme): string;

  function Hex(const P: TPix): string;
  begin
    Result := Format('#%.2x%.2x%.2x', [P.R, P.G, P.B]);
  end;

begin
  Result :=
    'html { scrollbar-color: ' + Hex(T.Accent) + ' ' +
      Hex(MixPix(T.Panel, Pix(0, 0, 0), 0.25)) + '; scrollbar-width: thin }' +
    ' body { background: ' + Hex(T.Panel) + '; color: ' + Hex(T.TextDim) +
      '; font-size: 14px; padding: 6px }' +
    ' h2 { color: ' + Hex(T.Accent) + '; font-size: 20px; margin-top: 20px }' +
    ' h3 { color: ' + Hex(T.TextDim) + '; font-size: 13px; margin-top: 8px }' +
    ' strong, b { color: ' + Hex(T.Text) + ' }' +
    ' li { margin-bottom: 6px }' +
    ' code { background: ' + Hex(MixPix(T.Panel, T.Text, 0.12)) + ' }' +
    ' hr { color: ' + Hex(T.TextDim) + ' }' +
    ' a { color: ' + Hex(T.Accent) + ' }';
end;

{ --- the window -------------------------------------------------------- }

constructor TWhatsNewForm.CreateNew(AOwner: TComponent; Dummy: Integer);
begin
  inherited CreateNew(AOwner, Dummy);
  Build;
end;

procedure TWhatsNewForm.Build;
var
  Y: Integer;
begin
  Caption := 'What''s new';
  { No stock frame, for the same reason the export dialog has none: a window
    manager's title bar in the middle of this is the one piece of it
    belonging to somebody else. }
  BorderStyle := bsNone;
  Position := poMainFormCenter;
  ClientWidth := DLG_W;
  ClientHeight := DLG_H;
  KeyPreview := True;
  OnKeyDown := @KeyDownH;
  uDlgSkin.SkinForm(Self);

  FHead := TBCPanel.Create(Self);
  FHead.Parent := Self;
  FHead.SetBounds(0, 0, DLG_W, HEAD_H);
  uDlgSkin.SkinPanel(FHead, True, 0);
  FHead.OnMouseDown := @HeadDown;
  FHead.OnMouseMove := @HeadMove;
  FHead.OnMouseUp := @HeadUp;

  FTitle := TLabel.Create(Self);
  FTitle.Parent := FHead;
  FTitle.SetBounds(18, 12, 460, 26);
  FTitle.AutoSize := False;
  FTitle.Transparent := True;
  FTitle.Caption := 'What''s new';
  FTitle.Font.Height := -19;
  FTitle.Font.Style := [fsBold];
  FTitle.Font.Color := uSurface.PixToColor(uDlgSkin.DlgTheme.Text);
  FTitle.OnMouseDown := @HeadDown;
  FTitle.OnMouseMove := @HeadMove;
  FTitle.OnMouseUp := @HeadUp;

  FShut := TBCButton.Create(Self);
  FShut.Parent := FHead;
  FShut.SetBounds(DLG_W - 44, 10, 30, 28);
  FShut.Caption := 'X';
  uDlgSkin.SkinButton(FShut, bkQuiet);
  FShut.OnClick := @DoGo;

  Y := HEAD_H + 12;
  FBody := TBCPanel.Create(Self);
  FBody.Parent := Self;
  FBody.SetBounds(PAD, Y, DLG_W - 2 * PAD, DLG_H - Y - FOOT_H);
  uDlgSkin.SkinPanel(FBody, False, 12);

  FPage := TInkPage.Create(Self);
  FPage.Parent := FBody;
  FPage.SetBounds(10, 10, FBody.Width - 20, FBody.Height - 20);
  FPage.Color := PixToColor(uDlgSkin.DlgTheme.Panel);
  FPage.Font.Color := PixToColor(uDlgSkin.DlgTheme.Text);
  { dragging the page is how a finger scrolls it - LazInk's own, on by
    default, and said here so nobody turns it off without knowing why }
  FPage.DragScroll := True;
  FPage.OnLinkClick := @PageLink;

  FFoot := TBCPanel.Create(Self);
  FFoot.Parent := Self;
  FFoot.SetBounds(PAD, DLG_H - FOOT_H + 4, DLG_W - 2 * PAD, FOOT_H - 14);
  uDlgSkin.SkinPanel(FFoot, False, 12);

  FWhich := TLabel.Create(Self);
  FWhich.Parent := FFoot;
  FWhich.SetBounds(14, 12, 420, 20);
  FWhich.AutoSize := False;
  FWhich.Transparent := True;
  FWhich.Caption := '';
  FWhich.Font.Height := -13;
  FWhich.Font.Color := uSurface.PixToColor(uDlgSkin.DlgTheme.TextDim);

  FGo := TBCButton.Create(Self);
  FGo.Parent := FFoot;
  FGo.SetBounds(FFoot.Width - 144, 6, 130, 32);
  FGo.Caption := 'Continue';
  uDlgSkin.SkinButton(FGo, bkGo);
  FGo.OnClick := @DoGo;
end;

procedure TWhatsNewForm.DoGo(Sender: TObject);
begin
  ModalResult := mrOk;
end;

{ Moved by uDlgSkin.DragBegin/DragTo, the same as every other window here
  that draws its own title bar. }
procedure TWhatsNewForm.HeadDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then uDlgSkin.DragBegin(FDrag, Self);
end;

procedure TWhatsNewForm.HeadMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
  uDlgSkin.DragTo(FDrag, Self);
end;

procedure TWhatsNewForm.HeadUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  uDlgSkin.DragEnd(FDrag);
end;

{ A link in the notes goes to the browser - the notes are not a place to
  wander off from. }
procedure TWhatsNewForm.PageLink(Sender: TObject; const URL: string);
begin
  if (Pos('http://', URL) = 1) or (Pos('https://', URL) = 1) then OpenURL(URL);
end;

procedure TWhatsNewForm.KeyDownH(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  { Esc and Enter put it away; everything else - the arrows, Page Up and
    Down, Home and End - is left for the page, which scrolls itself }
  { LazInk's note: with KeyPreview the form sees Esc and Enter before the
    page's find bar does, so while that bar is open they are the bar's }
  if FPage.FindBarVisible then Exit;
  case Key of
    VK_ESCAPE, VK_RETURN:
      begin
        ModalResult := mrOk;
        Key := 0;
      end;
  end;
end;

procedure TWhatsNewForm.ShowNotes;
begin
  FPage.TextFormat := itfMarkdown;
  FPage.StyleSheet.Text := ReleaseNotesStyle(uDlgSkin.DlgTheme);
  FPage.Source := FNotes;
  FPage.ScrollTo(0);
  ActiveControl := FPage;
end;

procedure TWhatsNewForm.ShowRelease(const PreviousVersion,
  NewVersion: string);
begin
  FTitle.Caption := 'Heckers Sketch has been updated';
  if PreviousVersion <> '' then
    FWhich.Caption := PreviousVersion + '  ' + #$E2#$86#$92 + '  ' + NewVersion
  else
    FWhich.Caption := NewVersion;
  FNotes := ReleaseNotesMarkdown(PreviousVersion);
  { an update from a version the notes do not go back to still gets the
    history rather than an empty page }
  if FNotes = '' then FNotes := ReleaseNotesMarkdown('');
  ShowNotes;
  ShowModal;
end;

procedure TWhatsNewForm.ShowAll;
begin
  FTitle.Caption := 'What''s new in Heckers Sketch';
  FWhich.Caption := 'This is ' + CurrentVersion;
  FNotes := ReleaseNotesMarkdown('');
  ShowNotes;
  ShowModal;
end;

end.
