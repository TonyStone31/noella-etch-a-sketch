unit uSendForm;

{ A window that shows a report going out.

  The same shape as the update window - a bold line for the stage, a plain one
  for the detail, a bar - so the two read as one program.  Each stage stays
  on screen for a moment before the next, because a fast machine would
  otherwise send the whole thing before the first word could be read, and the
  point of the window is that the person can see what is leaving. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ComCtrls, Graphics,
  InkPage, InkMarkdown;

type
  TSendForm = class(TForm)
  private
    lblStage: TLabel;
    lblDetail: TLabel;
    pbProgress: TProgressBar;
    btnClose: TButton;
    FPage: TInkPage;
    FFailed: Boolean;
    FNotes: TStringList;
    procedure CloseClick(Sender: TObject);
    procedure PauseFor(Milliseconds: QWord);
  public
    constructor CreateSending(AOwner: TComponent; const Title: string);
    destructor Destroy; override;
    { the next step, shown for at least a moment - longer where there is
      something worth reading, such as the sealing }
    procedure Stage(const AStage, ADetail: string; Percent: Integer;
      Hold: Integer = 450);
    { a row of the summary at the end: what it was, what it was made of,
      and whether it went - drawn by LazInk from a line of Markdown each }
    procedure Note(const What, Detail, Went: string);
    { The end.  It used to close itself after a beat on success, which read
      as the window vanishing before anybody could see what had gone.  Now
      it stays, with the notes as a summary, until Close - success or not. }
    procedure Finish(const Msg, Detail: string; OK: Boolean);
  end;

implementation

constructor TSendForm.CreateSending(AOwner: TComponent; const Title: string);
begin
  inherited CreateNew(AOwner);
  Caption := Title;
  Width := 520;
  Height := 210;
  BorderStyle := bsDialog;
  Position := poMainFormCenter;
  FFailed := False;

  lblStage := TLabel.Create(Self);
  lblStage.Parent := Self;
  lblStage.SetBounds(28, 24, 464, 24);
  lblStage.Font.Height := -17;
  lblStage.Font.Style := [fsBold];
  lblStage.Caption := 'Getting ready';

  lblDetail := TLabel.Create(Self);
  lblDetail.Parent := Self;
  lblDetail.SetBounds(28, 56, 464, 66);
  { a label sizes itself to one long line unless told not to, and the line
    ran off the right of the window }
  lblDetail.AutoSize := False;
  lblDetail.WordWrap := True;
  lblDetail.Caption := '';

  pbProgress := TProgressBar.Create(Self);
  pbProgress.Parent := Self;
  pbProgress.SetBounds(28, 128, 464, 22);
  pbProgress.Min := 0;
  pbProgress.Max := 100;

  btnClose := TButton.Create(Self);
  btnClose.Parent := Self;
  btnClose.SetBounds(392, 166, 100, 32);
  btnClose.Anchors := [akRight, akBottom];
  btnClose.Caption := 'Close';
  btnClose.Visible := False;
  btnClose.OnClick := @CloseClick;

  FNotes := TStringList.Create;
  { the summary is a page, so it can be a table with the words that matter
    in bold - the same renderer and the same dress as the release notes }
  FPage := TInkPage.Create(Self);
  FPage.Parent := Self;
  FPage.SetBounds(28, 162, 464, 124);
  { this is a plain window in the platform's own dress, not the dark chrome
    the release notes wear - so the page is dressed to match it }
  FPage.Color := clWindow;
  FPage.Font.Color := clWindowText;
  FPage.StyleSheet.Text := 'body { background: #ffffff; color: #202020 } ' +
    'li { margin-bottom: 6px }';
  FPage.TextFormat := itfMarkdown;
  FPage.Visible := False;

  Show;
  Application.ProcessMessages;
end;

destructor TSendForm.Destroy;
begin
  FNotes.Free;
  inherited Destroy;
end;

procedure TSendForm.Note(const What, Detail, Went: string);
begin
  { one bullet each, the label and the verdict in bold, so a long file name
    wraps under its own line rather than fighting a column for room }
  if Went = '' then
    FNotes.Add(Format('- **%s** - %s', [What, Detail]))
  else
    FNotes.Add(Format('- **%s** - %s - **%s**', [What, Detail, Went]));
end;

procedure TSendForm.PauseFor(Milliseconds: QWord);
var
  UntilTick: QWord;
begin
  UntilTick := GetTickCount64 + Milliseconds;
  repeat
    Application.ProcessMessages;
    Sleep(10);
  until GetTickCount64 >= UntilTick;
end;

procedure TSendForm.Stage(const AStage, ADetail: string; Percent: Integer;
  Hold: Integer);
begin
  lblStage.Caption := AStage;
  lblDetail.Caption := ADetail;
  pbProgress.Position := Percent;
  Application.ProcessMessages;
  PauseFor(Hold);
end;

procedure TSendForm.Finish(const Msg, Detail: string; OK: Boolean);
begin
  lblStage.Caption := Msg;
  lblDetail.Caption := Detail;
  FFailed := not OK;
  if OK then pbProgress.Position := 100 else pbProgress.Position := 0;
  { the summary: what went, how big, and whether - read at the person's
    own pace, success or failure alike }
  Height := 344;
  FPage.Source := FNotes.Text;
  FPage.ScrollTo(0);
  FPage.Visible := True;
  btnClose.Top := Height - 44;
  btnClose.Visible := True;
  btnClose.SetFocus;
  Application.ProcessMessages;
  while Visible do
  begin
    Application.ProcessMessages;
    Sleep(10);
  end;
end;

procedure TSendForm.CloseClick(Sender: TObject);
begin
  Close;
end;

end.
