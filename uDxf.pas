unit uDxf;

{ Writing DXF.

  A DXF is a text file of group codes: a number on one line saying what the
  next line is, then the value.  This writes the oldest dialect anything
  still reads - R12, "AC1009" - because a cutting table's software is where
  these files go, and that software is old, strict about little, and reads
  R12 without complaint.  Nothing here is parsed, so the failure mode is a
  file that will not open rather than one that opens and lies.

  Units: a DXF has none of its own.  Imperial drawings are written in inches
  and metric ones in millimetres, which is what a table expects to be handed,
  and the file says so twice - once as a comment a person can read, once as
  $INSUNITS for the programs that look. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TDxfWriter = class
  private
    FEnts: TStringList;
    FLayers: TStringList;
    FMinX, FMinY, FMinZ, FMaxX, FMaxY, FMaxZ: Double;
    FAny: Boolean;
    procedure Extend(X, Y, Z: Double);
    procedure Put(Code: Integer; const Value: string);
    procedure PutF(Code: Integer; V: Double);
  public
    constructor Create;
    destructor Destroy; override;
    { Layers are declared before use so a table sees them in the table of
      layers, not only on the entities.  Color is an AutoCAD color index;
      Dashed says the layer's lines are drawn broken. }
    procedure Layer(const Name: string; Color: Integer; Dashed: Boolean = False);
    procedure Line(const Lay: string; X1, Y1, Z1, X2, Y2, Z2: Double);
    procedure Face3D(const Lay: string; const X, Y, Z: array of Double);
    procedure Text(const Lay: string; X, Y, Z, Height: Double; const S: string);
    { The whole file.  Inches says which units the numbers were written in. }
    procedure SaveTo(L: TStrings; Inches: Boolean);
  end;

implementation

var
  FS: TFormatSettings;

constructor TDxfWriter.Create;
begin
  inherited Create;
  FEnts := TStringList.Create;
  FLayers := TStringList.Create;
  FAny := False;
end;

destructor TDxfWriter.Destroy;
begin
  FEnts.Free;
  FLayers.Free;
  inherited Destroy;
end;

procedure TDxfWriter.Extend(X, Y, Z: Double);
begin
  if not FAny then
  begin
    FMinX := X; FMaxX := X; FMinY := Y; FMaxY := Y; FMinZ := Z; FMaxZ := Z;
    FAny := True;
    Exit;
  end;
  if X < FMinX then FMinX := X; if X > FMaxX then FMaxX := X;
  if Y < FMinY then FMinY := Y; if Y > FMaxY then FMaxY := Y;
  if Z < FMinZ then FMinZ := Z; if Z > FMaxZ then FMaxZ := Z;
end;

procedure TDxfWriter.Put(Code: Integer; const Value: string);
begin
  FEnts.Add(Format('%3d', [Code]));
  FEnts.Add(Value);
end;

procedure TDxfWriter.PutF(Code: Integer; V: Double);
begin
  Put(Code, FormatFloat('0.######', V, FS));
end;

procedure TDxfWriter.Layer(const Name: string; Color: Integer; Dashed: Boolean);
begin
  if FLayers.IndexOfName(Name) >= 0 then Exit;
  FLayers.Values[Name] := Format('%d,%d', [Color, Ord(Dashed)]);
end;

procedure TDxfWriter.Line(const Lay: string; X1, Y1, Z1, X2, Y2, Z2: Double);
begin
  Put(0, 'LINE');
  Put(8, Lay);
  PutF(10, X1); PutF(20, Y1); PutF(30, Z1);
  PutF(11, X2); PutF(21, Y2); PutF(31, Z2);
  Extend(X1, Y1, Z1);
  Extend(X2, Y2, Z2);
end;

procedure TDxfWriter.Face3D(const Lay: string; const X, Y, Z: array of Double);
var
  I, N: Integer;
begin
  { a 3DFACE has three or four corners; a face with more is fanned into
    triangles from its first corner, which is exact for anything convex and
    close enough for a shop drawing on anything that is not }
  N := Length(X);
  if N < 3 then Exit;
  if N <= 4 then
  begin
    Put(0, '3DFACE');
    Put(8, Lay);
    for I := 0 to N - 1 do
    begin
      PutF(10 + I, X[I]); PutF(20 + I, Y[I]); PutF(30 + I, Z[I]);
      Extend(X[I], Y[I], Z[I]);
    end;
    if N = 3 then
    begin
      PutF(13, X[2]); PutF(23, Y[2]); PutF(33, Z[2]);
    end;
    Exit;
  end;
  for I := 1 to N - 2 do
  begin
    Put(0, '3DFACE');
    Put(8, Lay);
    PutF(10, X[0]);     PutF(20, Y[0]);     PutF(30, Z[0]);
    PutF(11, X[I]);     PutF(21, Y[I]);     PutF(31, Z[I]);
    PutF(12, X[I + 1]); PutF(22, Y[I + 1]); PutF(32, Z[I + 1]);
    PutF(13, X[I + 1]); PutF(23, Y[I + 1]); PutF(33, Z[I + 1]);
    Extend(X[I], Y[I], Z[I]);
  end;
  Extend(X[0], Y[0], Z[0]);
  Extend(X[N - 1], Y[N - 1], Z[N - 1]);
end;

procedure TDxfWriter.Text(const Lay: string; X, Y, Z, Height: Double;
  const S: string);
begin
  if Trim(S) = '' then Exit;
  Put(0, 'TEXT');
  Put(8, Lay);
  PutF(10, X); PutF(20, Y); PutF(30, Z);
  PutF(40, Height);
  Put(1, S);
  Extend(X, Y, Z);
end;

procedure TDxfWriter.SaveTo(L: TStrings; Inches: Boolean);
var
  I, Color, Dashed: Integer;
  Name, V: string;
begin
  L.Clear;
  L.Add('999');
  if Inches then L.Add('Heckers Sketch - units are inches')
  else L.Add('Heckers Sketch - units are millimetres');

  { --- header --- }
  L.Add('  0'); L.Add('SECTION');
  L.Add('  2'); L.Add('HEADER');
  L.Add('  9'); L.Add('$ACADVER');
  L.Add('  1'); L.Add('AC1009');
  L.Add('  9'); L.Add('$INSUNITS');
  L.Add(' 70'); if Inches then L.Add('1') else L.Add('4');
  if FAny then
  begin
    L.Add('  9'); L.Add('$EXTMIN');
    L.Add(' 10'); L.Add(FormatFloat('0.######', FMinX, FS));
    L.Add(' 20'); L.Add(FormatFloat('0.######', FMinY, FS));
    L.Add(' 30'); L.Add(FormatFloat('0.######', FMinZ, FS));
    L.Add('  9'); L.Add('$EXTMAX');
    L.Add(' 10'); L.Add(FormatFloat('0.######', FMaxX, FS));
    L.Add(' 20'); L.Add(FormatFloat('0.######', FMaxY, FS));
    L.Add(' 30'); L.Add(FormatFloat('0.######', FMaxZ, FS));
  end;
  L.Add('  0'); L.Add('ENDSEC');

  { --- tables: two line types and the layers --- }
  L.Add('  0'); L.Add('SECTION');
  L.Add('  2'); L.Add('TABLES');
  L.Add('  0'); L.Add('TABLE');
  L.Add('  2'); L.Add('LTYPE');
  L.Add(' 70'); L.Add('2');
  L.Add('  0'); L.Add('LTYPE');
  L.Add('  2'); L.Add('CONTINUOUS');
  L.Add(' 70'); L.Add('0');
  L.Add('  3'); L.Add('Solid line');
  L.Add(' 72'); L.Add('65');
  L.Add(' 73'); L.Add('0');
  L.Add(' 40'); L.Add('0');
  L.Add('  0'); L.Add('LTYPE');
  L.Add('  2'); L.Add('DASHED');
  L.Add(' 70'); L.Add('0');
  L.Add('  3'); L.Add('Dashed line');
  L.Add(' 72'); L.Add('65');
  L.Add(' 73'); L.Add('2');
  L.Add(' 40'); L.Add('0.75');
  L.Add(' 49'); L.Add('0.5');
  L.Add(' 49'); L.Add('-0.25');
  L.Add('  0'); L.Add('ENDTAB');
  L.Add('  0'); L.Add('TABLE');
  L.Add('  2'); L.Add('LAYER');
  L.Add(' 70'); L.Add(IntToStr(FLayers.Count));
  for I := 0 to FLayers.Count - 1 do
  begin
    Name := FLayers.Names[I];
    V := FLayers.ValueFromIndex[I];
    Color := StrToIntDef(Copy(V, 1, Pos(',', V) - 1), 7);
    Dashed := StrToIntDef(Copy(V, Pos(',', V) + 1, MaxInt), 0);
    L.Add('  0'); L.Add('LAYER');
    L.Add('  2'); L.Add(Name);
    L.Add(' 70'); L.Add('0');
    L.Add(' 62'); L.Add(IntToStr(Color));
    L.Add('  6'); if Dashed = 1 then L.Add('DASHED') else L.Add('CONTINUOUS');
  end;
  L.Add('  0'); L.Add('ENDTAB');
  L.Add('  0'); L.Add('ENDSEC');

  { --- the entities themselves --- }
  L.Add('  0'); L.Add('SECTION');
  L.Add('  2'); L.Add('ENTITIES');
  L.AddStrings(FEnts);
  L.Add('  0'); L.Add('ENDSEC');
  L.Add('  0'); L.Add('EOF');
end;

initialization
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';

end.
