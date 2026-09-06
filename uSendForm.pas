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
  Classes, SysUtils, Forms, Controls, StdCtrls, ComCtrls, Graphics;

type
  TSendForm = class(TForm)
  private
    lblStage: TLabel;
    lblDetail: TLabel;
    pbProgress: TProgressBar;
    btnClose: TButton;
    FFailed: Boolean;
    procedure CloseClick(Sender: TObject);
    procedure PauseFor(Milliseconds: QWord);
  public
    constructor CreateSending(AOwner: TComponent; const Title: string);
    { the next step, shown for at least a moment }
    procedure Stage(const AStage, ADetail: string; Percent: Integer);
    { the end: a success closes itself after a beat, a failure waits to be read }
    procedure Finish(const Msg, Detail: string; OK: Boolean);
  end;

implementation

constructor TSendForm.CreateSending(AOwner: TComponent; const Title: string);
begin
  inherited CreateNew(AOwner);
  Caption := Title;
  Width := 520;
  Height := 190;
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
  lblDetail.SetBounds(28, 56, 464, 40);
  lblDetail.WordWrap := True;
  lblDetail.Caption := '';

  pbProgress := TProgressBar.Create(Self);
  pbProgress.Parent := Self;
  pbProgress.SetBounds(28, 108, 464, 22);
  pbProgress.Min := 0;
  pbProgress.Max := 100;

  btnClose := TButton.Create(Self);
  btnClose.Parent := Self;
  btnClose.SetBounds(392, 146, 100, 32);
  btnClose.Anchors := [akRight, akBottom];
  btnClose.Caption := 'Close';
  btnClose.Visible := False;
  btnClose.OnClick := @CloseClick;

  Show;
  Application.ProcessMessages;
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

procedure TSendForm.Stage(const AStage, ADetail: string; Percent: Integer);
begin
  lblStage.Caption := AStage;
  lblDetail.Caption := ADetail;
  pbProgress.Position := Percent;
  Application.ProcessMessages;
  PauseFor(450);
end;

procedure TSendForm.Finish(const Msg, Detail: string; OK: Boolean);
begin
  lblStage.Caption := Msg;
  lblDetail.Caption := Detail;
  FFailed := not OK;
  if OK then
  begin
    pbProgress.Position := 100;
    Application.ProcessMessages;
    PauseFor(900);
    Close;
  end
  else
  begin
    pbProgress.Position := 0;
    btnClose.Visible := True;
    btnClose.SetFocus;
    Application.ProcessMessages;
    { a failure is read at the person's own pace }
    while Visible do
    begin
      Application.ProcessMessages;
      Sleep(10);
    end;
  end;
end;

procedure TSendForm.CloseClick(Sender: TObject);
begin
  Close;
end;

end.
