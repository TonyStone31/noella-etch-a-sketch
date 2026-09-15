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

  Copyright (c) 2021-2026 Noella Stone - MIT, see LICENSE.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Math, Graphics, Forms, Controls, StdCtrls,
  ExtCtrls, LCLType, BCPanel, BCLabel, BCButton,
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
    FScroll, FTall: Integer;

    FHead, FBody, FFoot: TBCPanel;
    { Plain labels, transparent, rather than the drawn ones.  A drawn label
      fills its own rectangle with a colour it inherited from the parent -
      which on a skinned panel is not the colour the panel actually painted -
      so the title came out sitting in a pale box. }
    FTitle, FWhich: TLabel;
    FPage: TPaintBox;
    FShut, FGo: TBCButton;

    FDrag: uDlgSkin.TFormDrag;
    { a finger, or a mouse button, dragging the page up and down }
    FPageGrab: Boolean;
    FPageGrabY, FPageGrabAt: Integer;

    procedure Build;
    procedure PagePaint(Sender: TObject);
    { one pass over the notes: measures when Draw is false, sets them when it
      is, and either way comes back with how tall the whole thing is }
    function Run(C: TCanvas; Draw: Boolean): Integer;
    procedure PageWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    { Dragging the page, which is how a finger scrolls.

      A paint box has no scrolling of its own - the wheel works because it
      was wired up by hand, and a touch screen has no wheel to wire.  On
      Windows a finger drag arrives as a press, some moves and a release, so
      taking those and moving the page by how far the finger went is the
      whole of it, and it costs a mouse the same gesture for free. }
    procedure PageDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PageMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure PageUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure KeyDownH(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HeadDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure HeadMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure HeadUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure DoGo(Sender: TObject);
    procedure ScrollTo(V: Integer);
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
    Put(nkBullet, Lead, Rest);
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

  FPage := TPaintBox.Create(Self);
  FPage.Parent := FBody;
  FPage.SetBounds(10, 10, FBody.Width - 20, FBody.Height - 20);
  FPage.OnPaint := @PagePaint;
  FPage.OnMouseWheel := @PageWheel;
  FPage.OnMouseDown := @PageDown;
  FPage.OnMouseMove := @PageMove;
  FPage.OnMouseUp := @PageUp;

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

procedure TWhatsNewForm.ScrollTo(V: Integer);
var
  Most: Integer;
begin
  Most := Max(0, FTall - FPage.Height);
  V := EnsureRange(V, 0, Most);
  if V = FScroll then Exit;
  FScroll := V;
  FPage.Invalidate;
end;

procedure TWhatsNewForm.PageWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  if WheelDelta > 0 then ScrollTo(FScroll - 56)
  else ScrollTo(FScroll + 56);
  Handled := True;
end;

procedure TWhatsNewForm.PageDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbLeft then Exit;
  FPageGrab := True;
  FPageGrabY := Y;
  FPageGrabAt := FScroll;
end;

procedure TWhatsNewForm.PageMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
  if not FPageGrab then Exit;
  { the page follows the finger: drag down and the words come down with it,
    which is the way every touch screen in the world behaves }
  ScrollTo(FPageGrabAt - (Y - FPageGrabY));
end;

procedure TWhatsNewForm.PageUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FPageGrab := False;
end;

procedure TWhatsNewForm.KeyDownH(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_ESCAPE, VK_RETURN: ModalResult := mrOk;
    VK_DOWN:  ScrollTo(FScroll + 40);
    VK_UP:    ScrollTo(FScroll - 40);
    VK_NEXT:  ScrollTo(FScroll + FPage.Height - 40);
    VK_PRIOR: ScrollTo(FScroll - FPage.Height + 40);
    VK_HOME:  ScrollTo(0);
    VK_END:   ScrollTo(FTall);
  else
    Exit;
  end;
  Key := 0;
end;

{ One pass over the notes.  Measuring and drawing walk the same code so a
  line can never be laid out one way and drawn another - which is how a
  scrollbar ends up describing a page that is not there. }
function TWhatsNewForm.Run(C: TCanvas; Draw: Boolean): Integer;
const
  MARGIN = 20;
  BULLET = 22;       { how far a bullet's words are indented }
  GUTTER = 28;       { room for the scrollbar }
var
  I, Y, W: Integer;
  T: TTheme;

  { Lay a run of words out from X, wrapping at the right margin, and come
    back with where the next word after it would go.  Height comes out of
    the canvas font so a theme with a different size still stacks. }
  procedure Words(const S: string; var AX, AY: Integer; Indent: Integer;
    const Col: TColor; Bold: Boolean);
  var
    P, Q, Wid, LineH: Integer;
    Word_: string;
  begin
    if S = '' then Exit;
    if Bold then C.Font.Style := [fsBold] else C.Font.Style := [];
    C.Font.Color := Col;
    LineH := C.TextHeight('Xg') + 3;
    P := 1;
    while P <= Length(S) do
    begin
      Q := P;
      while (Q <= Length(S)) and (S[Q] <> ' ') do Inc(Q);
      Word_ := Copy(S, P, Q - P);
      Wid := C.TextWidth(Word_ + ' ');
      if (AX > Indent) and (AX + C.TextWidth(Word_) > W - GUTTER) then
      begin
        AX := Indent;
        Inc(AY, LineH);
      end;
      if Draw then C.TextOut(AX, AY, Word_);
      Inc(AX, Wid);
      P := Q + 1;
      { two spaces after a full stop are a sentence break in the file, not a
        word, so they are eaten rather than drawn as an empty one }
      while (P <= Length(S)) and (S[P] = ' ') do Inc(P);
    end;
  end;

var
  X: Integer;
begin
  T := uDlgSkin.DlgTheme;
  W := FPage.Width;
  Y := 6 - FScroll;

  for I := 0 to High(FNotes) do
    case FNotes[I].Kind of

      nkVersion:
        begin
          if I > 0 then Inc(Y, 22);
          C.Font.Height := -20;
          C.Font.Style := [fsBold];
          C.Font.Color := PixToColor(T.Accent);
          if Draw then C.TextOut(MARGIN, Y, FNotes[I].Text);
          Inc(Y, C.TextHeight('Xg') + 8);
          { a rule under it, so a long history reads as a stack of releases
            rather than one run of paragraphs }
          if Draw then
          begin
            C.Pen.Color := PixToColor(T.TextDim);
            C.Pen.Width := 1;
            C.Line(MARGIN, Y, W - GUTTER, Y);
          end;
          Inc(Y, 14);
        end;

      nkSection:
        begin
          Inc(Y, 6);
          C.Font.Height := -12;
          C.Font.Style := [fsBold];
          C.Font.Color := PixToColor(T.TextDim);
          if Draw then C.TextOut(MARGIN, Y, UpperCase(FNotes[I].Text));
          Inc(Y, C.TextHeight('Xg') + 10);
        end;

      nkBullet:
        begin
          C.Font.Height := -14;
          C.Font.Style := [];
          { the dot, level with the first line of the words }
          if Draw then
          begin
            C.Brush.Color := PixToColor(T.Accent);
            C.Brush.Style := bsSolid;
            C.Ellipse(MARGIN + 3, Y + 7, MARGIN + 9, Y + 13);
            C.Brush.Style := bsClear;
          end;
          X := MARGIN + BULLET;
          Words(FNotes[I].Lead, X, Y, MARGIN + BULLET, PixToColor(T.Text), True);
          if (FNotes[I].Lead <> '') and (FNotes[I].Text <> '') then
            Inc(X, C.TextWidth(' '));
          Words(FNotes[I].Text, X, Y, MARGIN + BULLET,
            PixToColor(T.TextDim), False);
          Inc(Y, C.TextHeight('Xg') + 18);
        end;
    end;

  Result := Y + FScroll + 10;
end;

procedure TWhatsNewForm.PagePaint(Sender: TObject);
var
  C: TCanvas;
  T: TTheme;
  Most, ThumbH, ThumbY, TrackH: Integer;
begin
  C := FPage.Canvas;
  T := uDlgSkin.DlgTheme;

  C.Brush.Color := PixToColor(T.Panel);
  C.Brush.Style := bsSolid;
  C.FillRect(0, 0, FPage.Width, FPage.Height);
  C.Brush.Style := bsClear;

  FTall := Run(C, True);

  { The scrollbar, drawn rather than bolted on: a stock one down the side of
    a themed panel is the one grey thing in the room. }
  Most := Max(0, FTall - FPage.Height);
  if Most > 0 then
  begin
    TrackH := FPage.Height - 8;
    C.Brush.Color := uDlgSkin.Shade(PixToColor(T.Panel), -0.25);
    C.Brush.Style := bsSolid;
    C.FillRect(FPage.Width - 12, 4, FPage.Width - 6, 4 + TrackH);
    ThumbH := Max(28, Round(TrackH * FPage.Height / FTall));
    ThumbY := 4 + Round((TrackH - ThumbH) * FScroll / Most);
    C.Brush.Color := PixToColor(T.Accent);
    C.FillRect(FPage.Width - 12, ThumbY, FPage.Width - 6, ThumbY + ThumbH);
    C.Brush.Style := bsClear;
  end;
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
  FScroll := 0;
  ShowModal;
end;

procedure TWhatsNewForm.ShowAll;
begin
  FTitle.Caption := 'What''s new in Heckers Sketch';
  FWhich.Caption := 'This is ' + CurrentVersion;
  FNotes := ReleaseNotes('');
  FScroll := 0;
  ShowModal;
end;

end.
