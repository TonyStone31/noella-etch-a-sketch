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
  { where one file of the report has got to }
  TSendState = (ssWaiting, ssEncrypting, ssSending, ssSent, ssFailed, ssNone);

  TSendFile = record
    What, Name_, Size, Encrypted, Why: string;
    State: TSendState;
  end;

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
    FFailed, FDone: Boolean;
    FFiles: array of TSendFile;
    FFacts: TStringList;      { section TAB key TAB value, in the order given }
    FBanner, FBannerSub, FClosing: string;
    procedure PauseFor(Milliseconds: QWord);
    procedure Repaint_;
    function PageHTML: string;
  public
    constructor CreateSending(AOwner: TComponent; const Title: string);
    destructor Destroy; override;
    { the next step, shown for at least a moment - longer where there is
      something worth reading, such as the encrypting }
    procedure Stage(const AStage, ADetail: string; Percent: Integer;
      Hold: Integer = 450);
    { The table of files at the top of the page.  Every file that will go is
      listed before the first one does, as "waiting", and its row changes as
      it is encrypted, sent, and arrives or does not - the page is drawn
      again on each change, which is a handful of times for a whole report. }
    function AddFile(const What, Name_, Size: string;
      State: TSendState = ssWaiting): Integer;
    procedure FileState(Idx: Integer; State: TSendState;
      const Encrypted: string = ''; const Why: string = '');
    { A line of the summary under the files: which card it belongs on, what
      it is, and its value.  The first two sections named sit side by side;
      any after that run the full width, which is where long values go. }
    procedure Fact(const Section, Key, Value: string);
    { The end.  It used to close itself after a beat on success, which read
      as the window vanishing before anybody could see what had gone.  Now
      it stays, under a banner that says how it went, until Close. }
    procedure Finish(const Msg, Detail, ClosingHTML: string; OK: Boolean);
  end;

{ text made safe to put inside the page }
function Esc(const S: string): string;

implementation

{$R *.lfm}

const
  { The page's own dress.  It is HTML rather than Markdown so that it can
    have this: color that says how each file fared, a small fixed face so a
    long file name fits its cell, and cards side by side. }
  PAGE_CSS =
    'body { background: #ffffff; color: #0f172a; font-size: 14px; ' +
    '       line-height: 1.45; margin: 0; padding: 18px 22px } ' +
    'h3 { font-size: 12px; color: #64748b; text-transform: uppercase; ' +
    '     margin-top: 18px; margin-bottom: 6px } ' +
    'table { width: 100%; border-collapse: collapse } ' +
    'th { text-align: left; background: #f1f5f9; color: #475569; ' +
    '     font-size: 12px; padding: 7px 10px; border: 1px solid #e2e8f0 } ' +
    'td { padding: 7px 10px; border: 1px solid #e2e8f0 } ' +
    'td.file { font-size: 12px; color: #1e293b } ' +
    'td.num { text-align: right; color: #334155 } ' +
    'td.key { background: #f8fafc; color: #475569; font-size: 13px } ' +
    'td.val { font-size: 13px } ' +
    'td.wait { background: #f1f5f9; color: #64748b; font-weight: bold } ' +
    'td.busy { background: #fef3c7; color: #92400e; font-weight: bold } ' +
    'td.send { background: #dbeafe; color: #1d4ed8; font-weight: bold } ' +
    'td.ok   { background: #dcfce7; color: #15803d; font-weight: bold } ' +
    'td.bad  { background: #fee2e2; color: #b91c1c; font-weight: bold } ' +
    'td.big { border: 0; font-size: 21px; padding: 14px 18px 2px 18px } ' +
    'td.sub { border: 0; font-size: 14px; padding: 0 18px 14px 18px } ' +
    'td.b-ok  { background: #15803d; color: #ffffff } ' +
    'td.b-bad { background: #b91c1c; color: #ffffff } ' +
    'td.b-run { background: #1d4ed8; color: #ffffff } ' +
    'td.cap { border: 0; font-size: 12px; color: #64748b; ' +
    '         text-transform: uppercase; font-weight: bold; ' +
    '         padding: 18px 0 6px 0 } ' +
    'td.gap { border: 0; padding: 0; width: 14px } ' +
    'li { margin-bottom: 4px; font-size: 13px } ' +
    'code { font-size: 12px } ' +
    'small { color: #64748b }';

function Esc(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
end;

{ a short cell stays on one line: the file name is the long one, and left to
  itself the table gives it the room by folding "85 KB" in two }
function Whole(const S: string): string;
begin
  Result := StringReplace(Esc(S), ' ', #$C2#$A0, [rfReplaceAll]);
end;

constructor TSendForm.CreateSending(AOwner: TComponent; const Title: string);
begin
  inherited Create(AOwner);
  Caption := Title;
  FFailed := False;
  FDone := False;
  FFacts := TStringList.Create;
  { this is a plain window in the platform's own dress, not the dark chrome
    the release notes wear - the page brings its own colors }
  Page.Color := clWhite;
  Page.Font.Color := clBlack;
  Page.TextFormat := itfHTML;
  { This window is shown, not shown modal, and Finish waits in a loop for
    it to be closed.  Opened from inside a wizard - a report sent from the
    radiant layout's own button, 23 September - the wizard is modal, and
    on Windows a plain window shown while a modal one is up is disabled
    with everything else: Close and the X did nothing, the loop never
    ended, and the program looked hung.  A window that names the active
    form as its popup parent is that form's own and stays enabled, which
    is what the source window does to live beside the sheet. }
  PopupMode := pmExplicit;
  if Screen.ActiveForm <> nil then PopupParent := Screen.ActiveForm
  else if AOwner is TCustomForm then PopupParent := TCustomForm(AOwner);
  Repaint_;
  Show;
  Application.ProcessMessages;
end;

destructor TSendForm.Destroy;
begin
  FFacts.Free;
  inherited Destroy;
end;

function TSendForm.PageHTML: string;
const
  CELL: array[TSendState] of string = ('wait', 'busy', 'send', 'ok', 'bad', 'wait');
  WORD_: array[TSendState] of string = ('waiting', 'encrypting', 'sending',
    'sent', 'did not go', 'not included');
var
  H: TStringList;
  Sections: TStringList;
  I, J, P1, P2: Integer;
  Sec, Line, Verdict: string;

  procedure Card(const Name_: string);
  var
    K: Integer;
    L: string;
  begin
    H.Add('<h3>' + Esc(Name_) + '</h3><table>');
    for K := 0 to FFacts.Count - 1 do
    begin
      L := FFacts[K];
      P1 := Pos(#9, L);
      if Copy(L, 1, P1 - 1) <> Name_ then Continue;
      Delete(L, 1, P1);
      P2 := Pos(#9, L);
      H.Add('<tr><td class="key">' + Whole(Copy(L, 1, P2 - 1)) +
        '</td><td class="val">' + Esc(Copy(L, P2 + 1, MaxInt)) + '</td></tr>');
    end;
    H.Add('</table>');
  end;

  { Two sections side by side.  One table, five columns - key, value, a
    gap, key, value - and a row for each pair of facts.  A table in each
    half of a table would say the same thing, but LazInk draws a nested
    table without its cells' dress, and a grid as cards of plain text. }
  procedure Pair(const A, B: string);
  var
    KA, KB_: TStringList;
    K, N: Integer;
    L: string;

    function Cells(List: TStringList; At: Integer): string;
    var
      Q: Integer;
    begin
      if At >= List.Count then
        Exit('<td class="gap"></td><td class="gap"></td>');
      Q := Pos(#9, List[At]);
      Result := '<td class="key">' + Whole(Copy(List[At], 1, Q - 1)) +
        '</td><td class="val">' + Esc(Copy(List[At], Q + 1, MaxInt)) + '</td>';
    end;

  begin
    KA := TStringList.Create;
    KB_ := TStringList.Create;
    try
      for K := 0 to FFacts.Count - 1 do
      begin
        L := FFacts[K];
        P1 := Pos(#9, L);
        if Copy(L, 1, P1 - 1) = A then KA.Add(Copy(L, P1 + 1, MaxInt))
        else if Copy(L, 1, P1 - 1) = B then KB_.Add(Copy(L, P1 + 1, MaxInt));
      end;
      H.Add('<table><tr><td class="cap" colspan="2">' +
        '<b style="font-size: 12px">' + Esc(A) + '</b>' +
        '</td><td class="gap"></td><td class="cap" colspan="2">' +
        '<b style="font-size: 12px">' + Esc(B) + '</b></td></tr>');
      N := KA.Count;
      if KB_.Count > N then N := KB_.Count;
      for K := 0 to N - 1 do
        H.Add('<tr>' + Cells(KA, K) + '<td class="gap"></td>' +
          Cells(KB_, K) + '</tr>');
      H.Add('</table>');
    finally
      KA.Free;
      KB_.Free;
    end;
  end;

begin
  H := TStringList.Create;
  Sections := TStringList.Create;
  try
    H.Add('<html><head><meta charset="utf-8"><style>' + PAGE_CSS +
      '</style></head><body>');

    if FBanner <> '' then
    begin
      if not FDone then Sec := 'b-run'
      else if FFailed then Sec := 'b-bad' else Sec := 'b-ok';
      H.Add('<table class="banner"><tr><td class="' + Sec + ' big">' +
        '<b style="font-size: 22px">' + Esc(FBanner) + '</b></td></tr><tr><td class="' + Sec + ' sub">' +
        Esc(FBannerSub) + '</td></tr></table>');
    end;

    H.Add('<h3>Files</h3><table>');
    H.Add('<tr><th>Part</th><th>File</th><th>Size</th>' +
      '<th>Encrypted</th><th>Status</th></tr>');
    if Length(FFiles) = 0 then
      H.Add('<tr><td colspan="5"><small>getting ready</small></td></tr>');
    for I := 0 to High(FFiles) do
    begin
      Verdict := '<b>' + Whole(WORD_[FFiles[I].State]) + '</b>';
      if FFiles[I].Why <> '' then
        Verdict := Verdict + '<br><small>' + Esc(FFiles[I].Why) + '</small>';
      Line := FFiles[I].Encrypted;
      if Line = '' then Line := '-';
      H.Add('<tr><td><b>' + Whole(FFiles[I].What) + '</b></td>' +
        '<td class="file"><code>' + Esc(FFiles[I].Name_) + '</code></td>' +
        '<td class="num">' + Whole(FFiles[I].Size) + '</td>' +
        '<td class="num">' + Whole(Line) + '</td>' +
        '<td class="' + CELL[FFiles[I].State] + '">' + Verdict +
        '</td></tr>');
    end;
    H.Add('</table>');

    { the sections, in the order they were first named }
    for I := 0 to FFacts.Count - 1 do
    begin
      Sec := Copy(FFacts[I], 1, Pos(#9, FFacts[I]) - 1);
      if Sections.IndexOf(Sec) < 0 then Sections.Add(Sec);
    end;
    if Sections.Count >= 2 then
    begin
      { side by side: a table of two cells with a table in each - LazInk
        lays a grid out as cards of text, and a table in a card is not one }
      Pair(Sections[0], Sections[1]);
      J := 2;
    end
    else
      J := 0;
    for I := J to Sections.Count - 1 do Card(Sections[I]);

    H.Add(FClosing);
    H.Add('</body></html>');
    Result := H.Text;
  finally
    Sections.Free;
    H.Free;
  end;
end;

procedure TSendForm.Repaint_;
begin
  Page.Source := PageHTML;
  if not FDone then Page.ScrollTo(0);
  Application.ProcessMessages;
end;

function TSendForm.AddFile(const What, Name_, Size: string;
  State: TSendState): Integer;
begin
  Result := Length(FFiles);
  SetLength(FFiles, Result + 1);
  FFiles[Result].What := What;
  FFiles[Result].Name_ := Name_;
  FFiles[Result].Size := Size;
  FFiles[Result].State := State;
  Repaint_;
end;

procedure TSendForm.FileState(Idx: Integer; State: TSendState;
  const Encrypted: string; const Why: string);
begin
  if (Idx < 0) or (Idx > High(FFiles)) then Exit;
  FFiles[Idx].State := State;
  if Encrypted <> '' then FFiles[Idx].Encrypted := Encrypted;
  FFiles[Idx].Why := Why;
  Repaint_;
end;

procedure TSendForm.Fact(const Section, Key, Value: string);
begin
  if Trim(Value) = '' then Exit;
  FFacts.Add(Section + #9 + Key + #9 + Value);
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

procedure TSendForm.Finish(const Msg, Detail, ClosingHTML: string; OK: Boolean);
begin
  lblStage.Caption := Msg;
  lblDetail.Caption := Detail;
  FFailed := not OK;
  FDone := True;
  FBanner := Msg;
  FBannerSub := Detail;
  FClosing := ClosingHTML;
  if OK then pbProgress.Position := 100 else pbProgress.Position := 0;
  { the banner on the page says it from here, so the labels and the bar
    that said it on the way give their room to the page - wherever they
    have been put in the form }
  Page.SetBounds(Page.Left, lblStage.Top, Page.Width,
    Page.Top + Page.Height - lblStage.Top);
  lblStage.Visible := False;
  lblDetail.Visible := False;
  pbProgress.Visible := False;
  Repaint_;
  Page.ScrollTo(0);
  btnClose.Enabled := True;
  { From here the window is modal: its close is then the modal loop's
    own, which works inside another modal loop - a wizard's - where a
    plain shown window's does not.  Naming a popup parent was enough on
    Windows and not on GTK (23 September, still stuck at 21:59), so the
    loop that waited on Visible is gone. }
  Hide;
  ShowModal;
end;

procedure TSendForm.btnCloseClick(Sender: TObject);
begin
  ModalResult := mrOK;
end;

end.
