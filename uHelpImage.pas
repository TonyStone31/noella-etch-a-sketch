unit uHelpImage;

{ One picture from the manual, as large as the window lets it be.

  Tony, 17 September: "for the gif files... be able to click them and see a
  larger image... maybe we need to support open in new window hrefs and
  then we have a larger zoomable window for image or something."

  Every picture in the manual is a link to itself (target="_blank"), which
  a browser opens in a new tab.  In the program a click on one comes here:
  a window of its own, holding a LazInk TInkPage with nothing on it but that
  picture, fitted to the window (ImageFit = iifWindow) - so dragging the
  window bigger makes the picture bigger, and an animation keeps playing.
  The zoom is the window's size; LazInk stays as small as it was.

  Esc closes it.  It is one window, reused: the next picture replaces the
  last. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, LCLType, InkPage;

type
  THelpImageForm = class(TForm)
    Page: TInkPage;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure PageLinkClick(Sender: TObject; const URL: string);
  public
    procedure ShowPicture(const URL, Title: string);
  end;

var
  HelpImageForm: THelpImageForm = nil;

{ Open the picture window on URL (a file:// address or a local path). }
procedure OpenPictureWindow(const URL, Title: string);

implementation

{$R *.lfm}

uses
  uDlgSkin, uSurface;

procedure OpenPictureWindow(const URL, Title: string);
begin
  if HelpImageForm = nil then
    Application.CreateForm(THelpImageForm, HelpImageForm);
  HelpImageForm.ShowPicture(URL, Title);
end;

procedure THelpImageForm.FormCreate(Sender: TObject);
var
  Dark: string;
begin
  uDlgSkin.SkinForm(Self);
  Page.ImageFit := iifWindow;
  { a picture window is for looking, not selecting or dragging }
  Page.CopyMenu := False;
  Dark := Format('#%.2x%.2x%.2x', [DlgTheme.Shell1.R, DlgTheme.Shell1.G,
    DlgTheme.Shell1.B]);
  Page.StyleSheet.Text := 'body { background: ' + Dark +
    '; margin: 0; padding: 0 } html { scrollbar-width: none }';
  Page.Color := PixToColor(DlgTheme.Shell1);
end;

procedure THelpImageForm.FormDestroy(Sender: TObject);
begin
  if HelpImageForm = Self then HelpImageForm := nil;
end;

procedure THelpImageForm.FormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  CloseAction := caHide;
end;

procedure THelpImageForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    Close;
    Key := 0;
  end;
end;

{ nothing in here is a link; a click is just a look }
procedure THelpImageForm.PageLinkClick(Sender: TObject; const URL: string);
begin
end;

procedure THelpImageForm.ShowPicture(const URL, Title: string);
var
  R: TRect;
begin
  if not Visible then
  begin
    { most of the screen, the picture being the point }
    R := Screen.WorkAreaRect;
    Width := (R.Right - R.Left) * 85 div 100;
    Height := (R.Bottom - R.Top) * 85 div 100;
  end;
  if Title <> '' then Caption := 'Heckers Sketch - ' + Title
  else Caption := 'Heckers Sketch - Picture';
  { A page of our own with nothing in it but the picture, rather than
    pointing the renderer at the file and hoping.

    LoadFromURL on a picture makes that page itself - but only for the
    formats its list knows, and .webp is not one of them, so the day the
    manual's animations became WebP, clicking one showed the file read as
    text: a window full of binary gibberish.  Reported over in LazInk; this
    does not wait for it, and it is the honest way round anyway.  The window
    asks for one picture and knows which one, so it can say so rather than
    leaving the renderer to guess from the extension. }
  Page.LoadHTML('<html><head></head><body style="margin:0">' +
    '<img src="' + StringReplace(URL, '"', '&quot;', [rfReplaceAll]) +
    '" alt="' + StringReplace(Title, '"', '&quot;', [rfReplaceAll]) +
    '"></body></html>', URL);
  Page.ClearHistory;
  Show;
  BringToFront;
end;

end.
