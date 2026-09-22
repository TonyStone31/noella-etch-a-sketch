unit uHello;

{ A postcard to the authors.

  Not telemetry.  The program asks once - on its second start, when there
  has been time to see whether it runs at all - whether it may send one
  note saying what sort of machine it is on, and, if the person cares to
  say, what they mean to use it for.  The whole of the text is on the
  screen before anything goes, No is as big a button as Yes, and whichever
  is pressed the question is never asked again.  There is no identifier in
  it: not a serial, not a generated number, nothing that would let two
  postcards be matched up.  It goes the way a bug report goes - encrypted
  to the authors' key, into the disposable postbox uReport describes - and
  the collector counts it as a machine, once.

  --offline means it is never asked at all.  /postcard brings it back for
  somebody who said no and changed their mind, or wants to write another
  line. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Dialogs;

type

  { THelloForm }

  THelloForm = class(TForm)
    { laid out in uHello.lfm }
    lblHead: TLabel;
    lblWhy: TLabel;
    lblWhat: TLabel;
    memText: TMemo;
    lblNote: TLabel;
    memNote: TMemo;
    lblHonest: TLabel;
    lblStage: TLabel;
    btnSave: TButton;
    btnNo: TButton;
    btnSend: TButton;
    procedure btnNoClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnSendClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormShow(Sender: TObject);
    procedure memNoteChange(Sender: TObject);
  private
    FVersion: string;
    FSent, FBusy, FAnswered: Boolean;
    procedure Refresh_;
    procedure Stage(const S: string);
  public
    Version: string;
    { true once a postcard has gone from this window }
    property Sent: Boolean read FSent;
  end;

{ The program has started: one more on the count that decides when to ask. }
procedure CountLaunch;

{ Is it time to ask?  Second start or later, never answered, and the
  network not switched off. }
function PostcardDue: Boolean;

{ What would be sent, exactly. }
function PostcardText(const Version, Note: string): string;

{ Show the window.  Records the answer whichever way it goes, so it is not
  asked again; Forced is /postcard, which asks regardless. }
procedure OfferPostcard(AOwner: TComponent; const Version: string; Forced: Boolean);

implementation

{$R *.lfm}

uses
  IniFiles, Graphics, uPaths, uSysInfo, uReport, uNet, uDlgSkin, uSurface;

const
  SECTION = 'postcard';
  { the first start is for seeing whether it runs at all }
  ASK_ON_LAUNCH = 2;

procedure CountLaunch;
var
  Ini: TIniFile;
  N: Integer;
begin
  try
    Ini := TIniFile.Create(ConfigFile);
    try
      N := Ini.ReadInteger(SECTION, 'launches', 0);
      if N < 1000 then Ini.WriteInteger(SECTION, 'launches', N + 1);
    finally
      Ini.Free;
    end;
  except
    { a config that cannot be written is not this unit's problem }
  end;
end;

function PostcardDue: Boolean;
var
  Ini: TIniFile;
begin
  Result := False;
  if NetOffline then Exit;
  try
    Ini := TIniFile.Create(ConfigFile);
    try
      Result := (Ini.ReadInteger(SECTION, 'launches', 0) >= ASK_ON_LAUNCH) and
                (Ini.ReadString(SECTION, 'answer', '') = '');
    finally
      Ini.Free;
    end;
  except
    Result := False;
  end;
end;

procedure RecordAnswer(const Answer: string);
var
  Ini: TIniFile;
begin
  try
    Ini := TIniFile.Create(ConfigFile);
    try
      Ini.WriteString(SECTION, 'answer', Answer);
      Ini.WriteString(SECTION, 'when', FormatDateTime('yyyy-mm-dd', Now));
    finally
      Ini.Free;
    end;
  except
  end;
end;

function PostcardText(const Version, Note: string): string;
var
  N: string;
begin
  { The first line is what the collector looks for; the rest is one fact a
    line, the same lines a bug report carries about the machine.  The date
    is the day only.  Nothing about the person - see uSysInfo for the rule. }
  Result := 'Heckers Sketch hello' + LineEnding +
    'version: ' + Version + LineEnding +
    'sent: ' + FormatDateTime('yyyy-mm-dd', Now) + LineEnding +
    SystemFacts;
  N := Trim(Note);
  if N = '' then
    Result := Result + 'they said: nothing' + LineEnding
  else
    Result := Result + 'they said:' + LineEnding + N + LineEnding;
end;

procedure OfferPostcard(AOwner: TComponent; const Version: string; Forced: Boolean);
var
  F: THelloForm;
begin
  if NetOffline and not Forced then Exit;
  F := THelloForm.Create(AOwner);
  try
    F.Version := Version;
    F.ShowModal;
  finally
    F.Free;
  end;
end;

{ THelloForm }

procedure THelloForm.FormShow(Sender: TObject);
begin
  FVersion := Version;
  uDlgSkin.SkinForm(Self);
  { the bold labels have a font of their own and so miss the form's color;
    the buttons are the toolkit's and keep its text color }
  lblHead.Font.Color := PixToColor(DlgTheme.Text);
  lblWhat.Font.Color := PixToColor(DlgTheme.Text);
  btnSave.Font.Color := clBtnText;
  btnNo.Font.Color := clBtnText;
  btnSend.Font.Color := clBtnText;
  memText.Color := PixToColor(DlgTheme.Shell2);
  memText.Font.Color := PixToColor(DlgTheme.Text);
  memNote.Color := PixToColor(DlgTheme.Shell2);
  memNote.Font.Color := PixToColor(DlgTheme.Text);
  lblWhy.Caption :=
    'Two people are making this, and we cannot tell whether anyone is ' +
    'trying it: GitHub counts downloads, and most of those are our own ' +
    'machines.  So the program asks, once, whether it may send us one ' +
    'note saying what sort of computer it is running on.  That is all it ' +
    'is - a postcard, not a subscription.';
  lblHonest.Caption :=
    'Plainly: nothing in it names you.  No user name, no machine name, no ' +
    'network address, no files, no drawing, and no number that would let ' +
    'two postcards be matched up.  It is encrypted before it leaves, to a ' +
    'key only we hold, and goes to a public postbox that throws files away ' +
    'after a few days - we never see where it came from, though the postbox ' +
    'does, briefly, as any website would.  It is sent once, now, and never ' +
    'again.  Whichever button you press you will not be asked again; ' +
    '/postcard in the command bar brings this back if you change your mind, ' +
    'and starting with --offline means it never asks at all.';
  Stage('');
  Refresh_;
  ActiveControl := memNote;
end;

procedure THelloForm.Refresh_;
var
  Top_: Integer;
begin
  Top_ := memText.VertScrollBar.Position;
  memText.Lines.Text := PostcardText(FVersion, memNote.Lines.Text);
  memText.VertScrollBar.Position := Top_;
end;

procedure THelloForm.Stage(const S: string);
begin
  lblStage.Caption := S;
  lblStage.Repaint;
  Application.ProcessMessages;
end;

procedure THelloForm.memNoteChange(Sender: TObject);
begin
  Refresh_;
end;

procedure THelloForm.btnNoClick(Sender: TObject);
begin
  Close;
end;

procedure THelloForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  { closed with the window button: the same as No thanks, and not asked
    again - a question that comes back after being shut is a nag }
  if not FAnswered then
  begin
    FAnswered := True;
    RecordAnswer('declined');
  end;
  CloseAction := caHide;
end;

procedure THelloForm.btnSaveClick(Sender: TObject);
var
  Dlg: TSaveDialog;
  L: TStringList;
begin
  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.Title := 'Save a copy of the postcard';
    Dlg.FileName := 'heckers-sketch-postcard.txt';
    Dlg.Filter := 'Text|*.txt';
    Dlg.Options := Dlg.Options + [ofOverwritePrompt];
    if Dlg.Execute then
    begin
      L := TStringList.Create;
      try
        L.Text := PostcardText(FVersion, memNote.Lines.Text);
        L.SaveToFile(Dlg.FileName);
      finally
        L.Free;
      end;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure THelloForm.btnSendClick(Sender: TObject);
var
  Body, Name_, Err: string;
begin
  if FBusy then Exit;
  FBusy := True;
  btnSend.Enabled := False;
  btnNo.Enabled := False;
  memNote.ReadOnly := True;
  try
    Body := PostcardText(FVersion, memNote.Lines.Text);
    Name_ := UniqueReportName('hello', FVersion);
    { the encrypting happens inside SendReport, the same as a bug report;
      the stage is shown so it can be seen to have happened }
    Stage('Encrypting...');
    Sleep(400);
    Stage('Sending...');
    if SendReport(Name_, Body, Err) then
    begin
      FSent := True;
      FAnswered := True;
      RecordAnswer('sent');
      Stage('Sent - thank you.');
      btnNo.Caption := 'Close';
      btnNo.Enabled := True;
    end
    else
    begin
      { it did not go; that is not worth a fuss, and not worth asking
        again either - the answer was yes, and it was tried }
      FAnswered := True;
      RecordAnswer('tried');
      Stage('It did not go: ' + Err);
      btnNo.Caption := 'Close';
      btnNo.Enabled := True;
      btnSend.Enabled := True;
      memNote.ReadOnly := False;
    end;
  finally
    FBusy := False;
  end;
end;

end.
