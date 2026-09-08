unit uTouch;

{ Native touch, from the toolkit to the drawing.

  The Lazarus GTK3 backend asks GDK for touch events on every window it
  makes and then does nothing with them - it only knows their names for
  its debug output.  Once a window asks for raw touch, GDK stops turning
  fingers into mouse events for it.  So the drawing got nothing from a
  touchscreen while the toolkit's own buttons and the window frame, which
  handle touch themselves, worked.

  This connects to the form's touch-event signal and hands each finger to
  the program as it is: a sequence that begins, moves, ends or is cancelled,
  with where it is on the screen.  What the fingers mean - a tap, a drag,
  two fingers panning, a pinch - is the program's business, in uMain.
  Nothing here on any other platform yet; the hook says so by returning
  False, and the mouse path is untouched either way. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms;

type
  TTouchKind = (tkBegin, tkUpdate, tkEnd, tkCancel);
  { Seq tells one finger from another while it is down; SX, SY are screen
    coordinates, so the program can ask any control where that is }
  TTouchHandler = procedure(Kind: TTouchKind; Seq: Pointer; SX, SY: Double) of object;

{ hook the toolkit's touch events on this form; True when the platform can }
function HookTouch(Form: TCustomForm; Handler: TTouchHandler): Boolean;

implementation

{$IFDEF LCLGTK3}
uses
  LazGLib2, LazGObject2, LazGdk3, LazGtk3, gtk3widgets;

var
  TheHandler: TTouchHandler = nil;

function TouchCb(w: PGtkWidget; ev: PGdkEventTouch; data: gpointer): gboolean; cdecl;
var
  K: TTouchKind;
begin
  Result := False;
  if (ev = nil) or not Assigned(TheHandler) then Exit;
  case ev^.type_ of
    GDK_TOUCH_BEGIN: K := tkBegin;
    GDK_TOUCH_UPDATE: K := tkUpdate;
    GDK_TOUCH_END: K := tkEnd;
    GDK_TOUCH_CANCEL: K := tkCancel;
  else
    Exit;
  end;
  try
    TheHandler(K, ev^.sequence, ev^.x_root, ev^.y_root);
  except
    { a fault in a finger's handling must not come back through the
      toolkit as a crash in its event loop }
  end;
  Result := True;
end;

function HookTouch(Form: TCustomForm; Handler: TTouchHandler): Boolean;
var
  W: PGtkWidget;
begin
  Result := False;
  if (Form = nil) or not Form.HandleAllocated then Exit;
  W := TGtk3Widget(Form.Handle).Widget;
  if W = nil then Exit;
  TheHandler := Handler;
  { on the window itself: a touch on the drawing area, which has no widget
    of its own, comes up through the form's container to here }
  g_signal_connect_data(PGObject(W), 'touch-event', TGCallback(@TouchCb), nil, nil, G_CONNECT_DEFAULT);
  Result := True;
end;
{$ELSE}
function HookTouch(Form: TCustomForm; Handler: TTouchHandler): Boolean;
begin
  Result := False;
end;
{$ENDIF}

end.
