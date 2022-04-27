unit Unit1;

{

  10/19/2021 08:22:13 PM
  Noella Hazel Sketch is a program my daughter Noella wanted to write so I can
  teach her some basics about programming.  Most of it is her design and I
  only helped write code that would implement how she described the desire
  behavior.  I kept it as simple as possible but functional.  I am currently
  a hobbyist and beginner programmer myself.  There may be plenty of room for
  improvement in the code, however it was coded with a 7 year old child who has
  never had any programming experience.  I am very proud of my daughters efforts
  here and her well thought out design.  I hope in several years she can look
  back at this and say "This is where i got my start and became a succesful and
  amazing programmer!"  Love you Noella!  :-*

  Copyright (c) 2021 Noella Stone

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to
  deal in the Software without restriction, including without limitation the
  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
  sell copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
  IN THE SOFTWARE.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Spin, LCLType, ComCtrls, Menus, PrintersDlgs;

type

  { TForm1 }

  TForm1 = class(TForm)
    btnErase: TButton;
    ColorButton1: TColorButton;
    ColorDialog1: TColorDialog;
    imgDrawingSpace: TImage;
    Label1: TLabel;
    Label2: TLabel;
    MenuItem1: TMenuItem;
    mnuSuperDuperFast: TMenuItem;
    mnuAbout: TMenuItem;
    mnuExtraFast: TMenuItem;
    mnuSlow: TMenuItem;
    mnuMedSlow: TMenuItem;
    mnuMedium: TMenuItem;
    mnuMedFast: TMenuItem;
    mnuFast: TMenuItem;
    pmnuSpeed: TPopupMenu;
    PrintDialog1: TPrintDialog;
    shpPointer: TShape;
    shpX: TShape;
    shpY: TShape;
    sedtX: TSpinEdit;
    sedtY: TSpinEdit;
    tmrDrawer: TTimer;
    TrackBar1: TTrackBar;
    procedure btnEraseClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure ColorDialog1Close(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);

    procedure FormKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure FormResize(Sender: TObject);
    procedure mnuAboutClick(Sender: TObject);
    procedure mnuExtraFastClick(Sender: TObject);
    procedure mnuSlowClick(Sender: TObject);
    procedure mnuMedSlowClick(Sender: TObject);
    procedure mnuMedFastClick(Sender: TObject);
    procedure mnuFastClick(Sender: TObject);
    procedure mnuMediumClick(Sender: TObject);
    procedure mnuSuperDuperFastClick(Sender: TObject);
    procedure sedtXChange(Sender: TObject);
    procedure sedtYChange(Sender: TObject);
    procedure tmrDrawerTimer(Sender: TObject);
    procedure TrackBar1Change(Sender: TObject);
  private

  public
    procedure DoDrawBlankBoard;
    procedure DoDrawPoint;

  end;

var
  Form1: TForm1;
  eraserUp, eraseLeft: boolean;
  drPntX, drPntY, tmpAr: integer;

  kbUp: boolean = False;
  kbDn: boolean = False;
  kbLt: boolean = False;
  kbRt: boolean = False;
  kbShft: boolean = False;
  kbAlt: boolean = False;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.btnEraseClick(Sender: TObject);
var
  shakeStart, startTop, StartLeft: integer;
begin
  Randomize;
  shakeStart := GetTickCount64;

  startTop := Form1.Top;
  StartLeft := form1.Left;

  while GetTickCount64 - shakeStart < 2000 do
  begin
    Form1.Left := StartLeft + Random(200) - 100;
    Form1.Top := startTop + Random(200) - 100;
    Application.ProcessMessages;
    sleep(75);
  end;

  Form1.Left := StartLeft;
  Form1.Top := startTop;
  DoDrawBlankBoard;
end;



procedure TForm1.ColorDialog1Close(Sender: TObject);
begin
  //shpPointer.Brush.Color:=ColorDialog1.Color;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  DoDrawBlankBoard;
  ColorDialog1.Color := clBlack;
  //shpPointer.Brush.Color:=ColorDialog1.Color;
  tmpAr := 0;
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  if key = VK_LEFT then kbLt := True;

  if key = VK_RIGHT then kbRt := True;

  if key = VK_UP then kbUp := True;

  if key = VK_DOWN then kbDn := True;

  if key = VK_SHIFT then kbShft := True;

  if Key = VK_MENU then kbAlt := True;

  key := 0;
  tmrDrawer.Enabled := True;
end;

procedure TForm1.FormKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  if key = VK_LEFT then kbLt := False;

  if key = VK_RIGHT then kbRt := False;

  if key = VK_UP then kbUp := False;

  if key = VK_DOWN then kbDn := False;

  if key = VK_SHIFT then kbShft := False;

  if Key = VK_MENU then kbAlt := False;

  if not kbDn and not kbUp and not kbLt and not kbRt then tmrDrawer.Enabled := False;

  key := 0;
end;

procedure TForm1.tmrDrawerTimer(Sender: TObject);
var
  fastloop: integer = 1;
  i: integer;
begin
  if mnuExtraFast.Checked then
    fastloop := 2
  else if mnuSuperDuperFast.Checked then
    fastloop := 7
  else if kbShft then
    fastloop := 40
  else
    fastloop := 1;

  for i := 0 to fastloop do
  begin

    if kbLt then sedtX.Value := sedtX.Value - 1;

    if kbRt then sedtX.Value := sedtX.Value + 1;

    if kbUp then sedtY.Value := sedtY.Value - 1;

    if kbDn then sedtY.Value := sedtY.Value + 1;

  end;
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  imgDrawingSpace.Picture.Bitmap.SetSize(imgDrawingSpace.Width, imgDrawingSpace.Height);
  sedtX.MaxValue := imgDrawingSpace.Width - 30;
  sedtY.MaxValue := imgDrawingSpace.Height - 30;
  DoDrawBlankBoard;
end;

procedure TForm1.mnuAboutClick(Sender: TObject);
begin
  ShowMessage('This Etch A Sketch program was designed by Noella Stone using Lazarus.' +
    sLineBreak + 'Code is also her design with her fathers assistance.' +
    sLineBreak + 'Not bad for a 7 year old!  Good job Noella!' +
    sLineBreak + '10/19/2021');
end;

procedure TForm1.mnuExtraFastClick(Sender: TObject);
begin
  tmrDrawer.Interval := 1;
end;

procedure TForm1.mnuSlowClick(Sender: TObject);
begin
  tmrDrawer.Interval := 75;
end;

procedure TForm1.mnuMedSlowClick(Sender: TObject);
begin
  tmrDrawer.Interval := 40;
end;

procedure TForm1.mnuMedFastClick(Sender: TObject);
begin
  tmrDrawer.Interval := 10;
end;

procedure TForm1.mnuFastClick(Sender: TObject);
begin
  tmrDrawer.Interval := 5;
end;

procedure TForm1.mnuMediumClick(Sender: TObject);
begin
  tmrDrawer.Interval := 20;

end;

procedure TForm1.mnuSuperDuperFastClick(Sender: TObject);
begin
  tmrDrawer.Interval := 1;
end;

procedure TForm1.sedtXChange(Sender: TObject);
begin
  drPntX := sedtX.Value;
  DoDrawPoint;
end;

procedure TForm1.sedtYChange(Sender: TObject);
begin
  drPntY := sedtY.Value;
  DoDrawPoint;
end;

procedure TForm1.TrackBar1Change(Sender: TObject);
begin
  shpPointer.Width := TrackBar1.Position * 2;
  shpPointer.Height := TrackBar1.Position * 2;
end;

procedure TForm1.DoDrawBlankBoard;
begin
  imgDrawingSpace.Canvas.Pen.Style := psInsideframe;
  imgDrawingSpace.Canvas.Pen.Color := clGray;
  imgDrawingSpace.Canvas.Pen.Width := 10;
  imgDrawingSpace.Canvas.Brush.Style := bsSolid;
  imgDrawingSpace.Canvas.Brush.Color := clWhite;
  imgDrawingSpace.Canvas.Rectangle(0, 0, imgDrawingSpace.Width, imgDrawingSpace.Height);
end;


procedure TForm1.DoDrawPoint;
begin
  imgDrawingSpace.Canvas.Pen.Color := ColorDialog1.Color;
  imgDrawingSpace.Canvas.Pen.Width := TrackBar1.Position;

  if not kbAlt then
  begin
    imgDrawingSpace.Canvas.MoveTo(drPntX + 15, drPntY + 15);
    imgDrawingSpace.Canvas.LineTo(drPntX + 15, drPntY + 15);
  end;


  shpPointer.Left := (drPntX + imgDrawingSpace.Left + 15) - (shpPointer.Width div 2);
  shpPointer.Top := (drPntY + imgDrawingSpace.Top + 15) - (shpPointer.Height div 2);

  //Memo1.Lines.Add('Points[' + IntToStr(tmpAr) + '] := Point(' + IntToStr(drPntX) + ',' +
  //  IntToStr(drPntY) + ');');
  //Inc(tmpAr, 1);
end;




end.
