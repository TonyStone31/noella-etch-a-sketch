unit uShotView;

{ Showing somebody the picture that is about to leave their machine, before
  it leaves it.

  A bug report's picture is the most useful thing in it and the most personal
  thing in it, and those are the same fact: it is a photograph of what they
  were doing.  Sending one they have not seen is not on.  So it is put in
  front of them at the size it will go, with the three answers that are
  actually available - it is right, take it again, or send the report without
  it. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls;

type
  { what the person decided about the picture }
  TShotVerdict = (svUse, svRetry, svDrop);

{ Returns when they have chosen.  Closing the window is the same as dropping
  the picture: the safe reading of a shut window is that they did not want to
  send it. }
function ConfirmShot(Shot: TBitmap): TShotVerdict;

implementation

type
  TShotForm = class(TForm)
  public
    Pic: TBitmap;
    Verdict: TShotVerdict;
    procedure Paint; override;
    procedure UseClick(Sender: TObject);
    procedure RetryClick(Sender: TObject);
    procedure DropClick(Sender: TObject);
  end;

procedure TShotForm.Paint;
var
  Sc: Double;
  W, H, X, Y, HeadH: Integer;
  R: TRect;
begin
  HeadH := 64;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := $00201E1C;
  Canvas.FillRect(0, 0, ClientWidth, ClientHeight);

  Canvas.Font.Name := 'Sans';
  Canvas.Font.Size := 11;
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := $00F0F0F0;
  Canvas.TextOut(18, 14, 'This is the picture that will go with your report');
  Canvas.Font.Size := 9;
  Canvas.Font.Style := [];
  Canvas.Font.Color := $00B0B0B0;
  Canvas.TextOut(18, 38,
    'Only this program''s window - nothing else on your screen is in it.');

  if (Pic = nil) or (Pic.Width < 1) or (Pic.Height < 1) then Exit;

  { fitted, never enlarged - a picture shown bigger than it was taken invites
    somebody to judge detail that is not really there }
  Sc := Min((ClientWidth - 36) / Pic.Width,
            (ClientHeight - HeadH - 72) / Pic.Height);
  if Sc > 1 then Sc := 1;
  W := Max(1, Round(Pic.Width * Sc));
  H := Max(1, Round(Pic.Height * Sc));
  X := (ClientWidth - W) div 2;
  Y := HeadH + (ClientHeight - HeadH - 72 - H) div 2;

  Canvas.Brush.Color := $00000000;
  Canvas.FillRect(X - 1, Y - 1, X + W + 1, Y + H + 1);
  R := Rect(X, Y, X + W, Y + H);
  Canvas.StretchDraw(R, Pic);
end;

procedure TShotForm.UseClick(Sender: TObject);
begin
  Verdict := svUse;
  Close;
end;

procedure TShotForm.RetryClick(Sender: TObject);
begin
  Verdict := svRetry;
  Close;
end;

procedure TShotForm.DropClick(Sender: TObject);
begin
  Verdict := svDrop;
  Close;
end;

function ConfirmShot(Shot: TBitmap): TShotVerdict;
var
  F: TShotForm;
  B: TButton;
  BW, BH, Gap, Y: Integer;
begin
  F := TShotForm.CreateNew(nil);
  try
    F.Pic := Shot;
    { a shut window means no picture, so that is what it starts as }
    F.Verdict := svDrop;
    F.Caption := 'The picture for your report';
    F.Width := Min(1100, Max(700, Screen.Width - 200));
    F.Height := Min(820, Max(520, Screen.Height - 160));
    F.Position := poScreenCenter;
    F.DoubleBuffered := True;
    F.BorderStyle := bsSingle;

    BW := 190;
    BH := 34;
    Gap := 12;
    Y := F.ClientHeight - BH - 18;

    B := TButton.Create(F);
    B.Parent := F;
    B.SetBounds(F.ClientWidth - (BW + Gap) * 1 - 6, Y, BW, BH);
    B.Anchors := [akRight, akBottom];
    B.Caption := 'Send it with this picture';
    B.Default := True;
    B.OnClick := @F.UseClick;

    B := TButton.Create(F);
    B.Parent := F;
    B.SetBounds(F.ClientWidth - (BW + Gap) * 2 - 6, Y, BW, BH);
    B.Anchors := [akRight, akBottom];
    B.Caption := 'Take it again';
    B.OnClick := @F.RetryClick;

    B := TButton.Create(F);
    B.Parent := F;
    B.SetBounds(F.ClientWidth - (BW + Gap) * 3 - 6, Y, BW, BH);
    B.Anchors := [akRight, akBottom];
    B.Caption := 'Send without a picture';
    B.Cancel := True;
    B.OnClick := @F.DropClick;

    F.ShowModal;
    Result := F.Verdict;
  finally
    F.Free;
  end;
end;

end.
