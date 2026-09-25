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
    cbGiveUp: TComboBox;
    edBusyCover: TEdit;
    edBusyEven: TEdit;
    lblBusyCover: TLabel;
    lblBusyEven: TLabel;
    lblDetail: TLabel;
    lblFound: TLabel;
    lblGiveUp: TLabel;
    lblGoals: TLabel;
    lblStage: TLabel;
    lbFound: TListBox;
    pbProgress: TProgressBar;
    tmrStart: TTimer;
    procedure btnStopClick(Sender: TObject);
    procedure btnStopAllClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure lbFoundClick(Sender: TObject);
    procedure lbFoundDblClick(Sender: TObject);
    procedure tmrStartTimer(Sender: TObject);
  private
    { the line picked, by its words - the list is laid again, reordered,
      every time the search finds another, and the pick follows it }
    FPicked: string;
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
    { The solutions found so far, best first, one line each - the owner,
      25 September: "we sort of need a selection list in the progress
      dialog showing what it has found with the best at the top".  The
      line picked stays picked while the list changes under it. }
    procedure ShowFound(const Lines: array of string);
    { the line picked, '' for none - the caller matches it to what it
      kept }
    function Picked: string;
    { The goals as typed now, and how long a zone may go on - the owner,
      25 September: "the user should be able to adjust it during its
      search and have a drop down that says give up in 1 minute 5
      minutes etc maybe up to one hour".  A goal box that does not hold a
      number leaves the goal as it was. }
    procedure SetGoals(CoverPct, EvenPct: Double);
    procedure ReadGoals(var CoverPct, EvenPct: Double);
    { seconds a zone is searched before it gives up with its best, 0 for
      never }
    function GiveUpSecs: Integer;
    { pump messages this long, so what was just put up is painted }
    procedure Settle(Milliseconds: QWord);
  end;

implementation

{$R *.lfm}

constructor TRadiantBusyForm.CreateBusy(AOwner: TCustomForm);
begin
  inherited Create(AOwner);
  Stopping := False; StoppingAll := False;
  FPicked := '';
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
  FPicked := '';
  lbFound.Items.Clear;
end;

procedure TRadiantBusyForm.ShowFound(const Lines: array of string);
var
  I: Integer;
  Same: Boolean;
begin
  Same := lbFound.Items.Count = Length(Lines);
  if Same then
    for I := 0 to High(Lines) do
      if lbFound.Items[I] <> Lines[I] then begin Same := False; Break; end;
  if Same then Exit;
  lbFound.Items.BeginUpdate;
  try
    lbFound.Items.Clear;
    for I := 0 to High(Lines) do lbFound.Items.Add(Lines[I]);
    lbFound.ItemIndex := lbFound.Items.IndexOf(FPicked);
  finally
    lbFound.Items.EndUpdate;
  end;
end;

function TRadiantBusyForm.Picked: string;
begin
  Result := FPicked;
end;

procedure TRadiantBusyForm.SetGoals(CoverPct, EvenPct: Double);
begin
  edBusyCover.Text := FormatFloat('0.#', CoverPct);
  edBusyEven.Text := FormatFloat('0.#', EvenPct);
end;

procedure TRadiantBusyForm.ReadGoals(var CoverPct, EvenPct: Double);
var
  V: Double;
begin
  if TryStrToFloat(Trim(edBusyCover.Text), V) and (V >= 0) and (V <= 100) then CoverPct := V;
  if TryStrToFloat(Trim(edBusyEven.Text), V) and (V >= 0) and (V <= 100) then EvenPct := V;
end;

function TRadiantBusyForm.GiveUpSecs: Integer;
const
  SECS: array[0..5] of Integer = (0, 60, 300, 900, 1800, 3600);
begin
  if (cbGiveUp.ItemIndex >= 0) and (cbGiveUp.ItemIndex <= High(SECS)) then Result := SECS[cbGiveUp.ItemIndex]
  else Result := 0;
end;

procedure TRadiantBusyForm.lbFoundClick(Sender: TObject);
begin
  if lbFound.ItemIndex >= 0 then FPicked := lbFound.Items[lbFound.ItemIndex]
  else FPicked := '';
end;

{ this one, and no more searching this zone }
procedure TRadiantBusyForm.lbFoundDblClick(Sender: TObject);
begin
  lbFoundClick(Sender);
  if FPicked <> '' then btnStopClick(Sender);
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
