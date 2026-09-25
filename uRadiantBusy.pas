unit uRadiantBusy;

{ The window a radiant layout search shows while it works - the search
  takes seconds a zone on a real floor, and a wizard that sits frozen for
  that long reads as hung.  Built the way the send window is: a stage, a
  line of detail, a bar, and here a Stop, since a search is something a
  person may want back out of once they see which manifold it is on.

  Shown modal, over the wizard, and the search is run from inside it -
  handed in as OnWork and started a moment after the window is up, the
  window closing itself when the work returns.  It was shown plain at
  first, with the search run from the wizard, and on GTK a modal window
  (the wizard) takes every click from every other window: the bar moved
  and Stop could not be pressed, nor Escape.  A modal window over a
  modal one always has its own input. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ComCtrls, ExtCtrls;

type

  { TRadiantBusyForm }

  TRadiantBusyForm = class(TForm)
    btnStop: TButton;
    btnStopAll: TButton;
    lblDetail: TLabel;
    lblStage: TLabel;
    pbProgress: TProgressBar;
    tmrStart: TTimer;
    procedure btnStopClick(Sender: TObject);
    procedure btnStopAllClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure tmrStartTimer(Sender: TObject);
  public
    { Stop: the zone being searched keeps the best it has and the next zone
      starts - the search reads it between tries, and the caller clears it
      for the next zone.  Stop all: that, and no more zones. }
    Stopping, StoppingAll: Boolean;
    { the search, run once the window is up; the window closes when it
      returns }
    OnWork: TNotifyEvent;
    constructor CreateBusy(AOwner: TCustomForm);
    { ready for the next zone: Stop can be pressed again }
    procedure NextZone;
    procedure Stage(const AStage, ADetail: string; Percent: Integer);
    { pump messages this long, so what was just put up is painted }
    procedure Settle(Milliseconds: QWord);
  end;

implementation

{$R *.lfm}

constructor TRadiantBusyForm.CreateBusy(AOwner: TCustomForm);
begin
  inherited Create(AOwner);
  Stopping := False; StoppingAll := False;
  PopupMode := pmExplicit;
  PopupParent := AOwner;
end;

procedure TRadiantBusyForm.FormShow(Sender: TObject);
begin
  tmrStart.Enabled := True;
end;

procedure TRadiantBusyForm.tmrStartTimer(Sender: TObject);
begin
  tmrStart.Enabled := False;
  { a new window is mapped and painted over several turns of the loop,
    not one - pumped once, the first screenful of a search showed an
    empty frame }
  Settle(100);
  try
    if Assigned(OnWork) then OnWork(Self);
  finally
    ModalResult := mrOK;
  end;
end;

procedure TRadiantBusyForm.Settle(Milliseconds: QWord);
var
  UntilTick: QWord;
begin
  UntilTick := GetTickCount64 + Milliseconds;
  repeat
    Application.ProcessMessages;
    Sleep(5);
  until GetTickCount64 >= UntilTick;
end;

procedure TRadiantBusyForm.Stage(const AStage, ADetail: string; Percent: Integer);
begin
  lblStage.Caption := AStage;
  lblDetail.Caption := ADetail;
  pbProgress.Position := Percent;
  Repaint;
  Application.ProcessMessages;
end;

procedure TRadiantBusyForm.NextZone;
begin
  Stopping := StoppingAll;
  btnStop.Enabled := not StoppingAll;
end;

procedure TRadiantBusyForm.btnStopAllClick(Sender: TObject);
begin
  StoppingAll := True;
  btnStopAll.Enabled := False;
  btnStopClick(Sender);
end;

procedure TRadiantBusyForm.btnStopClick(Sender: TObject);
begin
  Stopping := True;
  btnStop.Enabled := False;
  lblDetail.Caption := 'Stopping after the layout it is on - the best so far is kept...';
end;

end.
