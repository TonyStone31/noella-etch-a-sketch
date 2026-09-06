unit uWhatsNew;

{ The release notes, on screen.

  WHATS_NEW.md is the one copy of the notes.  build.sh turns it into
  whatsnew.inc, a string constant, before every build, so the words in the
  program are the words in the file.  This unit reads that markdown - the
  little of it that is used: "## version" sections, "### New" and "### Fixed"
  headings, "- " bullets - and shows the sections newer than the version an
  update replaced, or every section when asked from the menu. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, uUpdate;

type
  TWhatsNewForm = class(TForm)
    btnContinue: TButton;
    lblHeading: TLabel;
    lblVersion: TLabel;
    memChanges: TMemo;
  public
    { after an update: what changed since PreviousVersion }
    procedure ShowRelease(const PreviousVersion, NewVersion: string);
    { from the menu: the whole history }
    procedure ShowAll;
  end;

{ The notes as text for the memo: every section newer than Since, or all of
  them when Since is empty.  A section headed "Next release" is the build
  being run and is shown under its own version. }
function ReleaseNotesText(const Since: string): string;

implementation

{$R *.lfm}

{$I whatsnew.inc}

function ReleaseNotesText(const Since: string): string;
var
  Lines: TStringList;
  I: Integer;
  L, Heading: string;
  Keep: Boolean;
  Out: TStringList;

  { a bullet may wrap onto indented lines in the file; on screen it is one }
  procedure Flush;
  begin
    if Heading <> '' then
    begin
      Out.Add('  ' + #$E2#$80#$A2 + ' ' + Heading);
      Heading := '';
    end;
  end;

begin
  Result := '';
  Lines := TStringList.Create;
  Out := TStringList.Create;
  try
    Lines.Text := WHATS_NEW_MD;
    Keep := False;
    Heading := '';
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
        if Keep then
        begin
          if Out.Count > 0 then Out.Add('');
          Out.Add(L);
        end;
        Continue;
      end;
      if not Keep then Continue;
      if Copy(L, 1, 4) = '### ' then
      begin
        Flush;
        Out.Add('');
        Out.Add(UpperCase(Trim(Copy(L, 5, MaxInt))));
      end
      else if Copy(L, 1, 2) = '- ' then
      begin
        Flush;
        Heading := Trim(Copy(L, 3, MaxInt));
      end
      else if (Heading <> '') and (Trim(L) <> '') then
        Heading := Heading + ' ' + Trim(L)
      else if Trim(L) = '' then
        Flush;
    end;
    Flush;
    Result := Out.Text;
  finally
    Out.Free;
    Lines.Free;
  end;
end;

procedure TWhatsNewForm.ShowRelease(const PreviousVersion,
  NewVersion: string);
var
  S: string;
begin
  lblHeading.Caption := 'Heckers Sketch has been updated';
  if PreviousVersion <> '' then
    lblVersion.Caption := PreviousVersion + '  ' + #$E2#$86#$92 + '  ' + NewVersion
  else
    lblVersion.Caption := NewVersion;
  S := ReleaseNotesText(PreviousVersion);
  { an update from a version the notes do not go back to still gets the
    latest section rather than an empty box }
  if Trim(S) = '' then S := ReleaseNotesText('');
  memChanges.Text := S;
  memChanges.SelStart := 0;
  ShowModal;
end;

procedure TWhatsNewForm.ShowAll;
begin
  lblHeading.Caption := 'What''s new in Heckers Sketch';
  lblVersion.Caption := 'This is ' + CurrentVersion;
  memChanges.Text := ReleaseNotesText('');
  memChanges.SelStart := 0;
  ShowModal;
end;

end.
