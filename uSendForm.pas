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
  { TSendForm }

  TSendForm = class(TForm)
    { laid out in uSendForm.lfm, so the window can be rearranged in Lazarus
      rather than by editing numbers here }
    lblStage: TLabel;
    lblDetail: TLabel;
    pbProgress: TProgressBar;
    Page: TInkPage;
    btnClose: TButton;
    procedure btnCloseClick(Sender: TObject);
  private
    FFailed: Boolean;
    FRows: TStringList;
    procedure PauseFor(Milliseconds: QWord);
    procedure ShowRows(const Closing: string);
  public
    constructor CreateSending(AOwner: TComponent; const Title: string);
    destructor Destroy; override;
    { the next step, shown for at least a moment - longer where there is
      something worth reading, such as the encrypting }
    procedure Stage(const AStage, ADetail: string; Percent: Integer;
      Hold: Integer = 450);
    { a row of the table: what it was, the name it went under, how big it
      was before and after encrypting, and whether it went.  The table is
      on the page from the start and grows a row as each thing goes. }
    procedure Note(const What, Name_, Size, Encrypted, Went: string);
    { The end.  It used to close itself after a beat on success, which read
      as the window vanishing before anybody could see what had gone.  Now
      it stays, with the table and a few lines under it, until Close -
      success or not. }
    procedure Finish(const Msg, Detail, Closing: string; OK: Boolean);
  end;

implementation

{$R *.lfm}

constructor TSendForm.CreateSending(AOwner: TComponent; const Title: string);
begin
  inherited Create(AOwner);
  Caption := Title;
  FFailed := False;
  FRows := TStringList.Create;
  { this is a plain window in the platform's own dress, not the dark chrome
    the release notes wear - so the page is dressed to match it }
  Page.Color := clWindow;
  Page.Font.Color := clWindowText;
  Page.StyleSheet.Text := 'body { background: #ffffff; color: #202020 } ' +
    'table { width: 100% } ' +
    'th { text-align: left; background: #eef1f4; padding: 6px 10px } ' +
    'td { padding: 6px 10px } ' +
    'li { margin-bottom: 4px }';
  Page.TextFormat := itfMarkdown;
  ShowRows('');
  Show;
  Application.ProcessMessages;
end;

destructor TSendForm.Destroy;
begin
  FRows.Free;
  inherited Destroy;
end;

procedure TSendForm.ShowRows(const Closing: string);
var
  Src: string;
begin
  Src := '### This report' + LineEnding + LineEnding +
    '| | File | Size | Encrypted | Result |' + LineEnding +
    '|---|---|---|---|---|' + LineEnding;
  if FRows.Count = 0 then
    Src := Src + '| *nothing yet* | | | | |' + LineEnding
  else
    Src := Src + FRows.Text;
  if Closing <> '' then Src := Src + LineEnding + Closing + LineEnding;
  Page.Source := Src;
  Page.ScrollTo(0);
end;

procedure TSendForm.Note(const What, Name_, Size, Encrypted, Went: string);

  { a short cell stays on one line: the file name is the long one, and
    left to itself the table gives it the room by folding "85 KB" in two }
  function Whole(const S: string): string;
  begin
    if Length(S) > 28 then Result := S
    else Result := StringReplace(S, ' ', #$C2#$A0, [rfReplaceAll]);
  end;

begin
  FRows.Add(Format('| **%s** | `%s` | %s | %s | **%s** |',
    [Whole(What), Name_, Whole(Size), Whole(Encrypted), Whole(Went)]));
  ShowRows('');
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

procedure TSendForm.Stage(const AStage, ADetail: string; Percent: Integer;
  Hold: Integer);
begin
  lblStage.Caption := AStage;
  lblDetail.Caption := ADetail;
  pbProgress.Position := Percent;
  Application.ProcessMessages;
  PauseFor(Hold);
end;

procedure TSendForm.Finish(const Msg, Detail, Closing: string; OK: Boolean);
begin
  lblStage.Caption := Msg;
  lblDetail.Caption := Detail;
  FFailed := not OK;
  if OK then pbProgress.Position := 100 else pbProgress.Position := 0;
  ShowRows(Closing);
  btnClose.Enabled := True;
  btnClose.SetFocus;
  Application.ProcessMessages;
  while Visible do
  begin
    Application.ProcessMessages;
    Sleep(10);
  end;
end;

procedure TSendForm.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
