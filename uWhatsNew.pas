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
  ExtCtrls, LCLType, LCLIntf, BCPanel, BCLabel, BCButton, InkPage,
  uUpdate, uSkin, uDlgSkin, uSurface;

type
  { What a line of the notes is.  Nothing else is read out of the file. }
  TNoteKind = (nkVersion, nkSection, nkBullet);

  TNote = record
    Kind: TNoteKind;
    { for a bullet: the bold part, and then the rest of it }
    Lead: string;
    Text: string;
  end;
  TNoteArray = array of TNote;

  TWhatsNewForm = class(TForm)
  private
    FNotes: TNoteArray;

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

{ The notes, broken up: every section newer than Since, or all of them when
  Since is empty.  A section headed "Next release" is the build being run and
  is listed under its own version. }
function ReleaseNotes(const Since: string): TNoteArray;
{ The same as flat text, for anything that only wants the words. }
function ReleaseNotesText(const Since: string): string;
{ The same as a page of HTML in the given colours - what the window shows. }
function ReleaseNotesHTML(const Notes: TNoteArray; const T: TTheme): string;

implementation

{$I whatsnew.inc}

const
  DLG_W = 760;
  DLG_H = 640;
  PAD   = 14;
  HEAD_H = 48;
  FOOT_H = 58;

{ --- reading the file -------------------------------------------------- }

function ReleaseNotes(const Since: string): TNoteArray;
var
  Lines: TStringList;
  I, N: Integer;
  L, Held: string;
  Keep: Boolean;

  procedure Put(K: TNoteKind; const Lead, Text: string);
  begin
    if N >= Length(Result) then SetLength(Result, Max(16, N * 2));
    Result[N].Kind := K;
    Result[N].Lead := Lead;
    Result[N].Text := Text;
    Inc(N);
  end;

  { This panel paints words, not HTML, and the notes file sits next door to a
    folder full of help pages - so sooner or later somebody writes <kbd>Ctrl
    </kbd> in it out of habit and a user reads the tags.  Somebody did, in
    the release of 16 September.

    Only the handful of inline tags that could plausibly turn up, by name.
    Not "anything between angle brackets": the notes already contain
    "/tiles <folder>", where the brackets are how a placeholder is written
    and eating them would be the worse bug of the two. }
  function Plain(const S: string): string;
  const
    TAGS: array[0..11] of string =
      ('<kbd>', '</kbd>', '<code>', '</code>', '<b>', '</b>',
       '<i>', '</i>', '<em>', '</em>', '<strong>', '</strong>');
  var
    K: Integer;
  begin
    Result := S;
    for K := 0 to High(TAGS) do
      Result := StringReplace(Result, TAGS[K], '', [rfReplaceAll, rfIgnoreCase]);
  end;

  { A bullet arrives as "**The lead in.**  And then the rest of it." - the
    lead is what the eye lands on, so it is kept apart from the rest rather
    than shown with its asterisks still on. }
  procedure Flush;
  var
    P: Integer;
    Lead, Rest: string;
  begin
    if Held = '' then Exit;
    Lead := '';
    Rest := Held;
    if Copy(Held, 1, 2) = '**' then
    begin
      P := Pos('**', Copy(Held, 3, MaxInt));
      if P > 0 then
      begin
        Lead := Copy(Held, 3, P - 1);
        Rest := Trim(Copy(Held, P + 4, MaxInt));
      end;
    end;
    Put(nkBullet, Plain(Lead), Plain(Rest));
    Held := '';
  end;

begin
  Result := nil;
  N := 0;
  Lines := TStringList.Create;
  try
    Lines.Text := WHATS_NEW_MD;
    Keep := False;
    Held := '';
    for I := 0 to Lines.Count - 1 do
    begin
      L := Lines[I];
      if Copy(L, 1, 3) = '## ' then
      begin
        Flush;
        L := Trim(Copy(L, 4, MaxInt));
        if SameText(L, 'Next release') then
        begin
          Keep := True;
          L := CurrentVersion;
        end
        else
          Keep := (Since = '') or NewerThan(L, Since);
        if Keep then Put(nkVersion, '', L);
        Continue;
      end;
      if not Keep then Continue;
      if Copy(L, 1, 4) = '### ' then
      begin
        Flush;
        Put(nkSection, '', Trim(Copy(L, 5, MaxInt)));
      end
      else if Copy(L, 1, 2) = '- ' then
      begin
        Flush;
        Held := Trim(Copy(L, 3, MaxInt));
      end
      else if (Held <> '') and (Trim(L) <> '') then
        { a bullet may wrap onto indented lines in the file; on screen it is
          one paragraph and the wrapping is worked out again }
        Held := Held + ' ' + Trim(L)
      else if Trim(L) = '' then
        Flush;
    end;
    Flush;
    SetLength(Result, N);
  finally
    Lines.Free;
  end;
end;

function ReleaseNotesText(const Since: string): string;
var
  Notes: TNoteArray;
  I: Integer;
  Out_: TStringList;
begin
  Notes := ReleaseNotes(Since);
  Out_ := TStringList.Create;
  try
    for I := 0 to High(Notes) do
      case Notes[I].Kind of
        nkVersion: begin
                     if Out_.Count > 0 then Out_.Add('');
                     Out_.Add(Notes[I].Text);
                   end;
        nkSection: begin
                     Out_.Add('');
                     Out_.Add(UpperCase(Notes[I].Text));
                   end;
        nkBullet:  Out_.Add('  ' + #$E2#$80#$A2 + ' ' +
                     Trim(Notes[I].Lead + ' ' + Notes[I].Text));
      end;
    Result := Out_.Text;
  finally
    Out_.Free;
  end;
end;

{ The notes as a page.  Everything the file says is text, so it is escaped
  first; then the two bits of markdown the notes use inside a bullet - a
  `backticked` command and a **bold** lead-in - are given their tags.  The
  colours come from the dialog's theme, through a style sheet at the top,
  so the page is the window's and not a white web page inside it. }
function ReleaseNotesHTML(const Notes: TNoteArray; const T: TTheme): string;
var
  I: Integer;
  B: TStringBuilder;
  InList: Boolean;

  function Hex(const P: TPix): string;
  begin
    Result := Format('#%.2x%.2x%.2x', [P.R, P.G, P.B]);
  end;

  function Esc(const S: string): string;
  begin
    Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
    Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
    Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  end;

  { `code` spans, in pairs; an odd one out is left as it was typed }
  function Inline(const S: string): string;
  var
    P, Q: Integer;
    Rest: string;
  begin
    Result := '';
    Rest := Esc(S);
    repeat
      P := Pos('`', Rest);
      if P = 0 then Break;
      Q := Pos('`', Copy(Rest, P + 1, MaxInt));
      if Q = 0 then Break;
      Result := Result + Copy(Rest, 1, P - 1) + '<code>' +
        Copy(Rest, P + 1, Q - 1) + '</code>';
      Rest := Copy(Rest, P + Q + 1, MaxInt);
    until False;
    Result := Result + Rest;
    Result := StringReplace(Result, '**', '', [rfReplaceAll]);
  end;

  procedure EndList;
  begin
    if InList then B.Append('</ul>');
    InList := False;
  end;

begin
  B := TStringBuilder.Create;
  try
    B.Append('<html><head><title>What''s new</title><style>');
    { the scrollbar in the theme's colours - thumb, then track - the way a
      browser reads it, which is how LazInk reads it too }
    B.Append('html { scrollbar-color: ' + Hex(T.Accent) + ' ' +
      Hex(MixPix(T.Panel, Pix(0, 0, 0), 0.25)) + '; scrollbar-width: thin }');
    B.Append('body { background: ' + Hex(T.Panel) + '; color: ' + Hex(T.TextDim) +
      '; font-size: 14px; padding: 6px }');
    B.Append('h2 { color: ' + Hex(T.Accent) + '; font-size: 20px; margin-top: 20px }');
    B.Append('h3 { color: ' + Hex(T.TextDim) + '; font-size: 12px; margin-top: 8px }');
    B.Append('li { color: ' + Hex(T.TextDim) + '; margin-bottom: 8px }');
    B.Append('code { background: ' + Hex(MixPix(T.Panel, T.Text, 0.12)) + ' }');
    B.Append('hr { color: ' + Hex(T.TextDim) + ' }');
    B.Append('</style></head><body>');
    InList := False;
    for I := 0 to High(Notes) do
      case Notes[I].Kind of
        nkVersion:
          begin
            EndList;
            B.Append('<h2>' + Esc(Notes[I].Text) + '</h2><hr>');
          end;
        nkSection:
          begin
            EndList;
            B.Append('<h3>' + Esc(UpperCase(Notes[I].Text)) + '</h3>');
          end;
        nkBullet:
          begin
            if not InList then B.Append('<ul>');
            InList := True;
            B.Append('<li>');
            if Notes[I].Lead <> '' then
              B.Append('<b><font color="' + Hex(T.Text) + '">' +
                Inline(Notes[I].Lead) + '</font></b> ');
            B.Append(Inline(Notes[I].Text) + '</li>');
          end;
      end;
    EndList;
    B.Append('</body></html>');
    Result := B.ToString;
  finally
    B.Free;
  end;
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
  FPage.LoadHTML(ReleaseNotesHTML(FNotes, uDlgSkin.DlgTheme));
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
  FNotes := ReleaseNotes(PreviousVersion);
  { an update from a version the notes do not go back to still gets the
    latest section rather than an empty page }
  if Length(FNotes) = 0 then FNotes := ReleaseNotes('');
  ShowNotes;
  ShowModal;
end;

procedure TWhatsNewForm.ShowAll;
begin
  FTitle.Caption := 'What''s new in Heckers Sketch';
  FWhich.Caption := 'This is ' + CurrentVersion;
  FNotes := ReleaseNotes('');
  ShowNotes;
  ShowModal;
end;

end.
