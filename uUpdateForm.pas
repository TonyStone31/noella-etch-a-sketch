unit uUpdateForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls,
  uUpdate;

type
  TUpdateForm = class(TForm)
    btnClose: TButton;
    lblDetail: TLabel;
    lblStage: TLabel;
    pbProgress: TProgressBar;
    tmrStart: TTimer;
    procedure btnCloseClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormShow(Sender: TObject);
    procedure tmrStartTimer(Sender: TObject);
  private
    FBusy: Boolean;
    FBytesReceived: Int64;
    FFinishing: Boolean;
    FInfo: TUpdateInfo;
    FLastPaint: QWord;
    FSucceeded: Boolean;
    FTmp: string;
    procedure DownloadProgress(BytesReceived, TotalBytes: Int64);
    procedure Fail(const Msg: string);
    procedure PauseFor(Milliseconds: QWord);
    procedure SetStage(const Stage, Detail: string; ProgressValue: Integer);
  public
    function Run(const Info: TUpdateInfo; const TempFile: string): Boolean;
  end;

implementation

{$R *.lfm}

function ByteSize(Value: Int64): string;
begin
  if Value >= 1024 * 1024 then
    Result := FormatFloat('0.0', Value / (1024 * 1024)) + ' MB'
  else if Value >= 1024 then
    Result := FormatFloat('0.0', Value / 1024) + ' KB'
  else
    Result := IntToStr(Value) + ' bytes';
end;

procedure TUpdateForm.SetStage(const Stage, Detail: string;
  ProgressValue: Integer);
begin
  lblStage.Caption := Stage;
  lblDetail.Caption := Detail;
  pbProgress.Position := ProgressValue;
  Application.ProcessMessages;
end;

procedure TUpdateForm.PauseFor(Milliseconds: QWord);
var
  UntilTick: QWord;
begin
  UntilTick := GetTickCount64 + Milliseconds;
  repeat
    Application.ProcessMessages;
    Sleep(10);
  until GetTickCount64 >= UntilTick;
end;

procedure TUpdateForm.DownloadProgress(BytesReceived, TotalBytes: Int64);
var
  Percent: Integer;
  NowTick: QWord;
begin
  FBytesReceived := BytesReceived;
  if TotalBytes > 0 then
  begin
    Percent := Round(BytesReceived * 100.0 / TotalBytes);
    if Percent < 0 then Percent := 0;
    if Percent > 100 then Percent := 100;
    pbProgress.Position := Percent;
    lblDetail.Caption := ByteSize(BytesReceived) + ' of ' + ByteSize(TotalBytes) +
      '  (' + IntToStr(Percent) + '%)';
  end
  else
    lblDetail.Caption := ByteSize(BytesReceived) + ' downloaded';

  NowTick := GetTickCount64;
  if (NowTick - FLastPaint >= 50) or
     ((TotalBytes > 0) and (BytesReceived >= TotalBytes)) then
  begin
    FLastPaint := NowTick;
    Application.ProcessMessages;
  end;
end;

procedure TUpdateForm.Fail(const Msg: string);
begin
  FBusy := False;
  lblStage.Caption := 'Update stopped';
  lblDetail.Caption := Msg;
  pbProgress.Position := 0;
  btnClose.Visible := True;
  btnClose.SetFocus;
  Application.ProcessMessages;
end;

procedure TUpdateForm.tmrStartTimer(Sender: TObject);
var
  Err, Want, Got: string;
begin
  tmrStart.Enabled := False;
  if FFinishing then
  begin
    ModalResult := mrOK;
    Exit;
  end;
  FBusy := True;

  SetStage('Downloading ' + FInfo.Tag, 'Connecting...', 0);
  PauseFor(450);
  FLastPaint := 0;
  if not Download(FInfo.AssetURL, FTmp, FInfo.Size, @DownloadProgress, Err) then
  begin
    Fail('The download failed: ' + Err);
    Exit;
  end;

  SetStage('Download complete', ByteSize(FBytesReceived) + ' received.', 100);
  PauseFor(650);
  SetStage('Verifying download', 'Checking the downloaded file...', 100);
  PauseFor(500);
  Want := ExpectedSum(FInfo.SumsURL, ASSET_NAME);
  if Want <> '' then
  begin
    Got := Sha256Of(FTmp);
    if Got <> Want then
    begin
      DeleteFile(FTmp);
      Fail('The file did not match its published checksum. Nothing was changed.');
      Exit;
    end;
  end;

  if Want <> '' then
    SetStage('Download verified', 'The checksum matches the published file.', 100)
  else
    SetStage('Download ready', 'The new version is ready to install.', 100);
  PauseFor(650);
  SetStage('Installing update',
    'Copying ' + FInfo.Tag + ' into place...', 100);
  PauseFor(650);
  if not SwapInAndRestart(FTmp, Err) then
  begin
    DeleteFile(FTmp);
    Fail('The update could not be installed: ' + Err);
    Exit;
  end;

  SetStage('Restarting Heckers Sketch',
    'The updated program is starting. Your drawing will come straight back.', 100);
  FBusy := False;
  FSucceeded := True;
  FFinishing := True;
  tmrStart.Interval := 1200;
  tmrStart.Enabled := True;
end;

procedure TUpdateForm.FormShow(Sender: TObject);
begin
  tmrStart.Enabled := True;
end;

procedure TUpdateForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := not FBusy;
end;

procedure TUpdateForm.btnCloseClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

function TUpdateForm.Run(const Info: TUpdateInfo;
  const TempFile: string): Boolean;
begin
  FInfo := Info;
  FTmp := TempFile;
  FBytesReceived := 0;
  FSucceeded := False;
  FBusy := False;
  FFinishing := False;
  tmrStart.Interval := 600;
  btnClose.Visible := False;
  lblStage.Caption := 'Preparing update';
  lblDetail.Caption := 'Getting ready to download ' + Info.Tag + '...';
  pbProgress.Position := 0;
  ShowModal;
  Result := FSucceeded;
end;

end.
